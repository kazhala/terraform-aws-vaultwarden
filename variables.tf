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

variable "domain_name" {
  type        = string
  description = "Domain name to use for SSL cert."
}

variable "domain_name_prefix" {
  type        = string
  default     = ""
  description = "Prefix to add to the domain name."
}
