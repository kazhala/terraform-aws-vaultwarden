variable "domain_name" {
  type        = string
  description = "Domain name to use for SSL cert."
}

variable "domain_name_prefix" {
  type        = string
  default     = ""
  description = "Prefix to add to the domain name."
}

variable "cidr_block" {
  default     = "10.0.0.0/16"
  type        = string
  description = "CIDR block for the ECS cluster VPC."
}

variable "name" {
  default     = "bitwardenrs"
  type        = string
  description = "Name for the VPC and ECS cluster."
}

variable "enable_vpc_flowlog" {
  default     = true
  type        = bool
  description = "Enable ECS cluster VPC flowlog."
}

variable "vpc_flowlog_loggroup" {
  default     = "/aws/vpc/flowlogs/"
  type        = string
  description = "Name of the new CloudWatch Log group for VPC flowlog."
}

variable "rds_username" {
  default     = "postgres"
  type        = string
  description = "Master username for the RDS database."
}

variable "rds_db_name" {
  default     = "bitwardenrs"
  type        = string
  description = "Default DB name for the RDS database."
}

variable "rds_snapshot_identifier" {
  default     = ""
  type        = string
  description = "Create RDS instance using the provided snapshot ID."
}

variable "rds_allocated_storage" {
  default     = 20
  type        = number
  description = "Default RDS storage size."
}

variable "rds_max_allocated_storage" {
  default     = 30
  type        = number
  description = "Maximum scaling for RDS storage."
}

variable "bitwardenrs_env" {
  default     = []
  type        = list(map(string))
  description = "List of bitwardenrs environment variable mappings. [{name = \"name\", value = \"value\"}]."
}

# variable "enable_cloudfront" {
#   default     = false
#   type        = bool
#   description = "Setup CloudFront distribution infront of the ALB."
# }

# variable "acm_arn" {
#   default     = ""
#   type        = string
#   description = "Provide us-east-1 region ACM certificate if enable_cloudfront equals true."
# }
