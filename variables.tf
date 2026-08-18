variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Project name used in resource naming and tagging"
  type        = string
  default     = "mcloud"
}

variable "environment" {
  description = "Environment name (poc, dev, staging, prod)"
  type        = string
  default     = "poc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "enable_nat_gateway" {
  description = "Set to true to create NAT gateway(s) for private subnet outbound access"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "If true, create one NAT gateway in the first public subnet to save cost. If false, create one per AZ for high availability."
  type        = bool
  default     = true
}

variable "admin_cidr_blocks" {
  description = "Trusted CIDR blocks allowed to reach the Windows EC2 on RDP (3389), HTTP (80) and HTTPS (443). Leave empty if you only use AWS Systems Manager Session Manager."
  type        = list(string)
  default     = []
}

variable "device_cidr_blocks" {
  description = "CIDR blocks allowed to reach the legacy device port (9040/TCP) on the Windows EC2. Current-generation devices use HTTPS/443 and do not need this."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
