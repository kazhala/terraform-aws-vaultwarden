terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws",
      version = ">= 3.0"
    }
  }
}

module "vpc" {
  source               = "github.com/kazhala/terraform_aws_vpc?ref=v0.1.0"
  vpc_name             = var.vpc_name
  cidr_block           = var.cidr_block
  subnet_count         = 2
  enable_vpc_flowlog   = var.enable_vpc_flowlog
  vpc_flowlog_loggroup = var.vpc_flowlog_loggroup
}

data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}

output "ami" {
  value = jsondecode(data.aws_ssm_parameter.ami.value).image_id
}
