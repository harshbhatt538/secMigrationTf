variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "instance_type" {
  description = "EC2 instance type for the Windows application server"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "Optional AMI ID. Leave empty to use the latest Windows Server 2022 Base AMI."
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Optional EC2 key pair name for RDP access. Leave empty to use SSM only."
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet ID to launch the EC2 instance into"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID to attach to the EC2 instance"
  type        = string
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 50
}

variable "data_volume_size" {
  description = "Optional data EBS volume size in GB. Set to 0 to disable."
  type        = number
  default     = 0
}

variable "create_eip" {
  description = "If true, create and attach an Elastic IP to the EC2 instance"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
