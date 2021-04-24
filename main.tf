terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws",
      version = ">= 3.0"
    }
  }
}

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
      "environment" : [],
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
