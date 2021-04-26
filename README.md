# terraform-aws-bitwardenrs

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Requirements

| Name                                                            | Version |
| --------------------------------------------------------------- | ------- |
| <a name="requirement_aws"></a> [aws](#requirement_aws)          | >= 3.0  |
| <a name="requirement_random"></a> [random](#requirement_random) | >= 3.1  |

## Providers

| Name                                                      | Version |
| --------------------------------------------------------- | ------- |
| <a name="provider_aws"></a> [aws](#provider_aws)          | >= 3.0  |
| <a name="provider_random"></a> [random](#provider_random) | >= 3.1  |

## Modules

| Name                                                                 | Source                                           | Version |
| -------------------------------------------------------------------- | ------------------------------------------------ | ------- |
| <a name="module_acm"></a> [acm](#module_acm)                         | terraform-aws-modules/acm/aws                    | ~> v2.0 |
| <a name="module_ecs_cluster"></a> [ecs_cluster](#module_ecs_cluster) | github.com/kazhala/terraform_aws_ecs_ec2_cluster |         |
| <a name="module_vpc"></a> [vpc](#module_vpc)                         | github.com/kazhala/terraform_aws_vpc             |         |

## Resources

| Name                                                                                                                                                         | Type        |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------- |
| [aws_alb.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb)                                                               | resource    |
| [aws_alb_listener.ecs_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_listener)                                        | resource    |
| [aws_alb_listener.ecs_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_listener)                                       | resource    |
| [aws_alb_target_group.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_target_group)                                     | resource    |
| [aws_db_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)                                              | resource    |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group)                                      | resource    |
| [aws_ecs_service.bitwardenrs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)                                       | resource    |
| [aws_ecs_task_definition.bitwardenrs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition)                       | resource    |
| [aws_iam_role.enhanced_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                     | resource    |
| [aws_iam_role_policy_attachment.enhanced_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource    |
| [aws_route53_record.bitwardenrs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)                                 | resource    |
| [aws_route53_record.www_bitwardenrs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)                             | resource    |
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                                         | resource    |
| [aws_security_group.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                                         | resource    |
| [aws_security_group.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                                         | resource    |
| [random_id.rds_final_snapshot](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id)                                            | resource    |
| [random_password.rds_master](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password)                                        | resource    |
| [aws_iam_policy_document.enhanced_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)            | data source |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone)                                         | data source |

## Inputs

| Name                                                                                                         | Description                                                                                                                                                         | Type                | Default                 | Required |
| ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- | ----------------------- | :------: |
| <a name="input_bitwardenrs_env"></a> [bitwardenrs_env](#input_bitwardenrs_env)                               | List of bitwardenrs environment variable mappings. [{name = "name", value = "value"}].                                                                              | `list(map(string))` | `[]`                    |    no    |
| <a name="input_cidr_block"></a> [cidr_block](#input_cidr_block)                                              | CIDR block for the ECS cluster VPC.                                                                                                                                 | `string`            | `"10.0.0.0/16"`         |    no    |
| <a name="input_domain_name"></a> [domain_name](#input_domain_name)                                           | Domain name to use for SSL cert.                                                                                                                                    | `string`            | n/a                     |   yes    |
| <a name="input_domain_name_prefix"></a> [domain_name_prefix](#input_domain_name_prefix)                      | Prefix to add to the domain name.                                                                                                                                   | `string`            | `""`                    |    no    |
| <a name="input_enable_vpc_flowlog"></a> [enable_vpc_flowlog](#input_enable_vpc_flowlog)                      | Enable ECS cluster VPC flowlog.                                                                                                                                     | `bool`              | `true`                  |    no    |
| <a name="input_name"></a> [name](#input_name)                                                                | Name for the VPC and ECS cluster.                                                                                                                                   | `string`            | `"bitwardenrs"`         |    no    |
| <a name="input_rds_allocated_storage"></a> [rds_allocated_storage](#input_rds_allocated_storage)             | Default RDS storage size.                                                                                                                                           | `number`            | `20`                    |    no    |
| <a name="input_rds_backup_window"></a> [rds_backup_window](#input_rds_backup_window)                         | The daily time range (in UTC) during which automated backups are created if they are enabled. Example: "09:46-10:16". Must not overlap with rds_maintenance_window. | `string`            | `"04:00-04:30"`         |    no    |
| <a name="input_rds_db_name"></a> [rds_db_name](#input_rds_db_name)                                           | Default DB name for the RDS database.                                                                                                                               | `string`            | `"bitwardenrs"`         |    no    |
| <a name="input_rds_maintenance_window"></a> [rds_maintenance_window](#input_rds_maintenance_window)          | The window to perform maintenance in. Syntax: "ddd:hh24:mi-ddd:hh24:mi". Eg: "Mon:00:00-Mon:03:00".                                                                 | `string`            | `"Sun:05:00-Sun:05:30"` |    no    |
| <a name="input_rds_max_allocated_storage"></a> [rds_max_allocated_storage](#input_rds_max_allocated_storage) | Maximum scaling for RDS storage.                                                                                                                                    | `number`            | `30`                    |    no    |
| <a name="input_rds_snapshot_identifier"></a> [rds_snapshot_identifier](#input_rds_snapshot_identifier)       | Create RDS instance using the provided snapshot ID.                                                                                                                 | `string`            | `null`                  |    no    |
| <a name="input_rds_username"></a> [rds_username](#input_rds_username)                                        | Master username for the RDS database.                                                                                                                               | `string`            | `"postgres"`            |    no    |
| <a name="input_tags"></a> [tags](#input_tags)                                                                | Additional resource tags to apply to applicable resources. Format: {"key" = "value"}                                                                                | `map(string)`       | `{}`                    |    no    |
| <a name="input_vpc_flowlog_loggroup"></a> [vpc_flowlog_loggroup](#input_vpc_flowlog_loggroup)                | Name of the new CloudWatch Log group for VPC flowlog.                                                                                                               | `string`            | `"/aws/vpc/flowlogs/"`  |    no    |

## Outputs

No outputs.

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
