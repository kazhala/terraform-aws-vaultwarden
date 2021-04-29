locals {
  domain_name       = "${var.domain_name_prefix}${var.domain_name_prefix != "" ? "." : ""}${var.domain_name}"
  cloudfront_enable = var.cloudfront_enable == true && var.cloudfront_acm_arn != null ? true : false
}

module "vpc" {
  source = "github.com/kazhala/terraform_aws_vpc"

  name                     = var.name
  cidr_block               = var.cidr_block
  subnet_count             = 2
  vpc_flowlog_enable       = var.vpc_flowlog_enable
  flowlog_log_group_prefix = var.vpc_flowlog_loggroup
  tags                     = var.tags
}

module "ecs_cluster" {
  source = "github.com/kazhala/terraform_aws_ecs_ec2_cluster"

  vpc_id                    = module.vpc.vpc_id
  subnets                   = module.vpc.public_subnets
  name                      = var.name
  security_groups           = [aws_security_group.ecs.id]
  instance_type             = "t3.micro"
  target_group_arns         = [aws_alb_target_group.ecs.arn]
  health_check_grace_period = 600
  tags                      = var.tags
}

data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> v3.0"

  domain_name               = local.domain_name
  zone_id                   = data.aws_route53_zone.this.zone_id
  subject_alternative_names = ["www.${local.domain_name}"]
  tags                      = var.tags
}

resource "aws_security_group" "ecs" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      "Name" = "ecs-${var.name}"
    },
    var.tags
  )
}

resource "aws_security_group" "alb" {
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

  tags = merge(
    {
      "Name" = "alb-${var.name}"
    },
    var.tags
  )
}

resource "aws_security_group" "rds" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      "Name" = "rds-${var.name}"
    },
    var.tags
  )
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
  name_prefix        = "rds-monitoring-${var.name}-"
  assume_role_policy = data.aws_iam_policy_document.enhanced_monitoring.json

  tags = merge(
    {
      "Name" = "rds-monitoring-${var.name}"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  role       = aws_iam_role.enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_subnet_group" "this" {
  name_prefix = "${var.name}-"
  subnet_ids  = module.vpc.private_subnets

  tags = merge(
    {
      "Name" = var.name
    },
    var.tags
  )
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

resource "aws_db_instance" "this" {
  identifier_prefix = "${var.name}-"

  instance_class            = "db.t2.micro"
  engine                    = "postgres"
  engine_version            = "12.6"
  snapshot_identifier       = var.rds_snapshot_identifier
  final_snapshot_identifier = "${var.name}-${random_id.rds_final_snapshot.hex}"

  backup_window           = var.rds_backup_window
  maintenance_window      = var.rds_maintenance_window
  backup_retention_period = 7

  username = var.rds_username
  password = random_password.rds_master.result
  name     = var.rds_db_name
  port     = 5432

  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage

  db_subnet_group_name   = aws_db_subnet_group.this.id
  vpc_security_group_ids = [aws_security_group.rds.id]

  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.enhanced_monitoring.arn
  performance_insights_enabled    = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(
    {
      "Name" = var.name
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_alb" "ecs" {
  name_prefix = "${substr(var.name, 0, 5)}-"

  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets
  load_balancer_type = "application"

  tags = merge(
    {
      "Name" = "ecs-${var.name}"
    },
    var.tags
  )
}

resource "aws_alb_listener" "ecs_https" {
  load_balancer_arn = aws_alb.ecs.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = module.acm.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.ecs.arn
  }
}

resource "aws_alb_listener" "ecs_http" {
  load_balancer_arn = aws_alb.ecs.arn
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

resource "aws_alb_target_group" "ecs" {
  name_prefix = "${substr(var.name, 0, 5)}-"

  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  tags = merge(
    {
      "Name" = "ecs-${var.name}"
    },
    var.tags
  )
}

resource "aws_ecs_task_definition" "vaultwarden" {
  family       = var.name
  network_mode = "bridge"

  container_definitions = jsonencode([
    {
      "essential" : true,
      "memory" : 478,
      "name" : "vaultwarden",
      "cpu" : 1024,
      "image" : "vaultwarden/server:latest",
      "environment" : concat(
        var.vaultwarden_env,
        [
          {
            "name" : "DATABASE_URL",
            "value" : "postgresql://${aws_db_instance.this.username}:${aws_db_instance.this.password}@${aws_db_instance.this.endpoint}/${aws_db_instance.this.name}"
          },
          {
            "name" : "DOMAIN",
            "value" : "https://${local.domain_name}"
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

  tags = merge(
    {
      "Name" = var.name
    },
    var.tags
  )
}

resource "aws_ecs_service" "vaultwarden" {
  name = var.name

  cluster         = module.ecs_cluster.cluster_id
  task_definition = aws_ecs_task_definition.vaultwarden.arn
  desired_count   = 1

  tags = merge(
    {
      "Name" = var.name
    },
    var.tags
  )
}

data "aws_cloudfront_cache_policy" "this" {
  name = "Managed-CachingDisabled"
}

resource "aws_cloudfront_distribution" "this" {
  count = local.cloudfront_enable == true ? 1 : 0

  aliases     = [local.domain_name, "www.${local.domain_name}"]
  comment     = "CDN for ${var.name}"
  price_class = var.cloudfront_price_class
  enabled     = true

  origin {
    origin_id   = aws_alb.ecs.name
    domain_name = aws_alb.ecs.dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2", "SSLv3"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    target_origin_id       = aws_alb.ecs.name
    min_ttl                = 0
    max_ttl                = 0
    default_ttl            = 0

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.cloudfront_acm_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2019"
  }

  tags = merge(
    {
      "Name" = var.name
    },
    var.tags
  )
}

resource "aws_route53_record" "default" {
  name = local.domain_name

  type    = "A"
  zone_id = data.aws_route53_zone.this.zone_id

  alias {
    name                   = local.cloudfront_enable == true ? aws_cloudfront_distribution.this[0].domain_name : aws_alb.ecs.dns_name
    zone_id                = local.cloudfront_enable == true ? aws_cloudfront_distribution.this[0].hosted_zone_id : aws_alb.ecs.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  name = "www.${local.domain_name}"

  type    = "A"
  zone_id = data.aws_route53_zone.this.zone_id

  alias {
    name                   = local.cloudfront_enable == true ? aws_cloudfront_distribution.this[0].domain_name : aws_alb.ecs.dns_name
    zone_id                = local.cloudfront_enable == true ? aws_cloudfront_distribution.this[0].hosted_zone_id : aws_alb.ecs.zone_id
    evaluate_target_health = false
  }
}
