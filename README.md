# terraform_bitwardenrs

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vpc"></a> [vpc](#module\_vpc) | github.com/kazhala/terraform_aws_vpc?ref=v0.1.0 |  |

## Resources

| Name | Type |
|------|------|
| [aws_ssm_parameter.ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | CIDR block for the ECS cluster VPC. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_enable_vpc_flowlog"></a> [enable\_vpc\_flowlog](#input\_enable\_vpc\_flowlog) | Enable ECS cluster VPC flowlog. | `bool` | `true` | no |
| <a name="input_vpc_flowlog_loggroup"></a> [vpc\_flowlog\_loggroup](#input\_vpc\_flowlog\_loggroup) | Name of the new CloudWatch Log group for VPC flowlog. | `string` | `"/aws/vpc/flowlogs/"` | no |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name of the ECS cluster VPC. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ami"></a> [ami](#output\_ami) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
