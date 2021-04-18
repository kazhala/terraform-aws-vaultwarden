variable "cidr_block" {
  default     = "10.0.0.0/16"
  type        = string
  description = "CIDR block for the ECS cluster VPC."
}

variable "vpc_name" {
  type        = string
  description = "Name of the ECS cluster VPC."
}

variable "subnet_count" {
  default     = 3
  type        = number
  description = "Number of subnet to create, maximum 3."
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

variable "ecs_cluster_name" {
  type        = string
  description = "Name of the ECS cluster."
}

variable "ec2_instance_type" {
  default     = "t3.micro"
  type        = string
  description = "EC2 instance type."
}

variable "domain_name" {
  type        = string
  description = "Domain name to use for SSL cert."
}
