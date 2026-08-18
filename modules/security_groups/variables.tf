variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "admin_cidr_blocks" {
  type    = list(string)
  default = []
}

variable "device_cidr_blocks" {
  type    = list(string)
  default = []
}

variable "windows_web_cidr_blocks" {
  description = "CIDR blocks allowed to reach the Windows EC2 directly on HTTP/HTTPS. Use 0.0.0.0/0 only for POC when no ALB is used."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
