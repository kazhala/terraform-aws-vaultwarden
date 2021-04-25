locals {
  domain_name = "${var.domain_name_prefix}${var.domain_name_prefix != "" ? "." : ""}${var.domain_name}"
}

module "vpc" {
  source                   = "github.com/kazhala/terraform_aws_vpc"
  vpc_name                 = var.name
  cidr_block               = var.cidr_block
  subnet_count             = 2
  enable_vpc_flowlog       = var.enable_vpc_flowlog
  flowlog_log_group_prefix = var.vpc_flowlog_loggroup
}

module "ecs_cluster" {
  source                    = "github.com/kazhala/terraform_aws_ecs_ec2_cluster"
  vpc_id                    = module.vpc.vpc_id
  subnets                   = module.vpc.public_subnets
  cluster_name              = var.name
  security_groups           = [aws_security_group.ecs_sg.id]
  instance_type             = "t3.micro"
  target_group_arns         = [aws_alb_target_group.ecs_target.arn]
  health_check_grace_period = 600
}

data "aws_route53_zone" "domain_hosted_zone" {
  name         = var.domain_name
  private_zone = false
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> v2.0"

  domain_name = local.domain_name
  zone_id     = data.aws_route53_zone.domain_hosted_zone.zone_id

  subject_alternative_names = ["www.${local.domain_name}"]
}

resource "aws_security_group" "ecs_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "${var.name}-ecs-sg"
  }
}

resource "aws_security_group" "alb_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "${var.name}-alb-sg"
  }
}

resource "aws_security_group" "rds_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "${var.name}-rds-sg"
  }
}

data "aws_iam_policy_document" "enhanced_monitoring" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "enhanced_monitoring" {
  name_prefix        = "${var.name}-rds-monitoring-"
  assume_role_policy = data.aws_iam_policy_document.enhanced_monitoring.json
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  role       = aws_iam_role.enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_subnet_group" "rds" {
  name_prefix = "${var.name}-"
  subnet_ids  = module.vpc.private_subnets
}

resource "random_password" "rds_master" {
  length  = 12
  special = false
}

resource "random_id" "rds_final_snapshot" {
  byte_length = 4

  keepers = {
    snapshot_identifier = var.rds_snapshot_identifier
  }
}

resource "aws_db_instance" "rds" {
  identifier_prefix         = "${var.name}-"
  snapshot_identifier       = var.rds_snapshot_identifier
  final_snapshot_identifier = "${var.name}-${random_id.rds_final_snapshot.hex}"

  instance_class = "db.t2.micro"
  engine         = "postgres"
  engine_version = "12.6"

  username = var.rds_username
  password = random_password.rds_master.result
  name     = "bitwardenrs"
  port     = 5432

  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage

  db_subnet_group_name   = aws_db_subnet_group.rds.id
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.enhanced_monitoring.arn
  performance_insights_enabled    = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    "Name" = var.name
  }
}

resource "aws_alb" "ecs_alb" {
  name_prefix        = "bw-"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets
  load_balancer_type = "application"
}

resource "aws_alb_listener" "ecs_https_listener" {
  load_balancer_arn = aws_alb.ecs_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = module.acm.this_acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.ecs_target.arn
  }
}

resource "aws_alb_listener" "ecs_http_listener" {
  load_balancer_arn = aws_alb.ecs_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb_target_group" "ecs_target" {
  name_prefix = "bw-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"
}

resource "aws_ecs_task_definition" "bitwardenrs_task" {
  family       = "bitwardenrs_task"
  network_mode = "bridge"

  container_definitions = jsonencode([
    {
      "essential" : true,
      "memory" : 478,
      "name" : "bitwardenrs",
      "cpu" : 1024,
      "image" : "bitwardenrs/server:latest",
      "environment" : concat(
        var.bitwardenrs_env,
        [
          {
            "name" : "DATABASE_URL",
            "value" : "postgresql://${aws_db_instance.rds.username}:${aws_db_instance.rds.password}@${aws_db_instance.rds.endpoint}/${aws_db_instance.rds.name}"
          }
        ]
      ),
      "portMappings" : [
        {
          "containerPort" : 80,
          "hostPort" : 80,
          "protocol" : "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "bitwardenrs_service" {
  name            = var.name
  cluster         = module.ecs_cluster.cluster_id
  task_definition = aws_ecs_task_definition.bitwardenrs_task.arn
  desired_count   = 1
}

resource "aws_route53_record" "bitwardenrs" {
  name    = local.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.domain_hosted_zone.zone_id

  alias {
    name                   = aws_alb.ecs_alb.dns_name
    zone_id                = aws_alb.ecs_alb.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_bitwardenrs" {
  name    = "www.${local.domain_name}"
  type    = "A"
  zone_id = data.aws_route53_zone.domain_hosted_zone.zone_id

  alias {
    name                   = aws_alb.ecs_alb.dns_name
    zone_id                = aws_alb.ecs_alb.zone_id
    evaluate_target_health = false
  }
}
