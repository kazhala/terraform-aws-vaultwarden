terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws",
      version = ">= 3.0"
    }
  }
}

locals {
  subnet_count = max(min(var.subnet_count, 1), 3)
}

module "vpc" {
  source               = "github.com/kazhala/terraform_aws_vpc?ref=v0.1.1"
  vpc_name             = var.vpc_name
  cidr_block           = var.cidr_block
  subnet_count         = local.subnet_count
  enable_vpc_flowlog   = var.enable_vpc_flowlog
  vpc_flowlog_loggroup = var.vpc_flowlog_loggroup
}

resource "aws_acm_certificate" "cert" {
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"
}

data "aws_route53_zone" "domain_hosted_zone" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
      zone_id = data.aws_route53_zone.domain_hosted_zone.zone_id
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.validation_record : record.fqdn]
}

resource "aws_security_group" "ecs_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
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
    "Name" = "${var.vpc_name}-bitwardenrs-ecs-sg"
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
    "Name" = "${var.vpc_name}-bitwardenrs-alb-sg"
  }
}

data "aws_iam_policy_document" "ecs_agent" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_agent" {
  name_prefix        = "bitwardenrs-ecs-agent-"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
}

resource "aws_iam_role_policy_attachment" "ecs_agent" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_agent" {
  name = "bitwardenrs-ecs-agent-"
  role = aws_iam_role.ecs_agent.name
}

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}

resource "aws_launch_configuration" "ecs_launch_config" {
  image_id             = jsondecode(data.aws_ssm_parameter.ecs_ami.value).image_id
  name_prefix          = "bitwardenrs-launch-config-"
  iam_instance_profile = aws_iam_instance_profile.ecs_agent.name
  security_groups      = [aws_security_group.ecs_sg.id]
  user_data            = "#!/bin/bash\necho ECS_CLUSTER=${var.ecs_cluster_name} >> /etc/ecs/ecs.config"
  instance_type        = var.ec2_instance_type
}

resource "aws_alb" "ecs_alb" {
  name_prefix        = "bw-"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets
  load_balancer_type = "application"
}

resource "aws_alb_listener" "ecs_listener" {
  load_balancer_arn = aws_alb.ecs_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.cert_validation.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.ecs_target.arn
  }
}

resource "aws_alb_target_group" "ecs_target" {
  name_prefix = "bw-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"
}

resource "aws_autoscaling_group" "ecs_asg" {
  name_prefix               = "bitwardenrs-ecs-asg-"
  vpc_zone_identifier       = module.vpc.public_subnets
  launch_configuration      = aws_launch_configuration.ecs_launch_config.name
  max_size                  = 1
  min_size                  = 1
  desired_capacity          = 1
  health_check_type         = "ELB"
  target_group_arns         = [aws_alb_target_group.ecs_target.arn]
  health_check_grace_period = 600
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.ecs_cluster_name
}

resource "aws_ecs_task_definition" "bitwardenrs_task" {
  family = "bitwardenrs_task"

  container_definitions = jsonencode([
    {
      "essential" : true,
      "memory" : 512,
      "name" : "bitwardenrs",
      "cpu" : 1024,
      "image" : "bitwardenrs/server:latest",
      "environment" : [],
      "networkMode" : "awsvpc",
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
  name                  = "${var.ecs_cluster_name}-bitwardenrs"
  cluster               = aws_ecs_cluster.ecs_cluster.id
  task_definition       = aws_ecs_task_definition.bitwardenrs_task.arn
  desired_count         = 1
  wait_for_steady_state = true
}

resource "aws_route53_record" "bitwardenrs" {
  name    = var.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.domain_hosted_zone.zone_id

  alias {
    name                   = aws_alb.ecs_alb.dns_name
    zone_id                = aws_alb.ecs_alb.zone_id
    evaluate_target_health = false
  }
}
