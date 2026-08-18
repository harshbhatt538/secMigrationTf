variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs for the RDS DB subnet group"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID to attach to the RDS instance"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class for SQL Server Express"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB for the RDS instance"
  type        = number
  default     = 20
}

variable "engine_version" {
  description = "SQL Server Express 2022 major version"
  type        = string
  default     = "16.00"
}

variable "master_username" {
  description = "Master username for the RDS SQL Server instance"
  type        = string
  default     = "admin"
}

variable "master_password" {
  description = "Master password. Leave empty to generate a random password."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
