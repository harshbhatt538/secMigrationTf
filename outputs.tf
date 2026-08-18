output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the created VPC"
  value       = module.vpc.vpc_cidr_block
}

output "igw_id" {
  description = "ID of the Internet Gateway"
  value       = module.igw.igw_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.subnets.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.subnets.private_subnet_ids
}

output "public_subnet_azs" {
  description = "Availability zones of the public subnets"
  value       = module.subnets.public_subnet_azs
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways"
  value       = module.nat.nat_gateway_ids
}

output "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer"
  value       = module.security_groups.alb_security_group_id
}

output "windows_security_group_id" {
  description = "Security group ID for the Windows EC2 application server"
  value       = module.security_groups.windows_security_group_id
}

output "rds_security_group_id" {
  description = "Security group ID for the RDS SQL Server"
  value       = module.security_groups.rds_security_group_id
}

output "ec2_instance_id" {
  description = "ID of the Windows EC2 instance"
  value       = module.ec2.instance_id
}

output "ec2_public_ip" {
  description = "Public IP address of the Windows EC2 instance"
  value       = module.ec2.public_ip
}

output "ec2_private_ip" {
  description = "Private IP address of the Windows EC2 instance"
  value       = module.ec2.private_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of the Windows EC2 instance"
  value       = module.ec2.public_dns
}

output "ec2_iam_role_name" {
  description = "IAM role name attached to the Windows EC2 instance"
  value       = module.ec2.iam_role_name
}

output "rds_endpoint" {
  description = "RDS SQL Server endpoint (hostname:port)"
  value       = module.rds.endpoint
}

output "rds_address" {
  description = "RDS SQL Server hostname"
  value       = module.rds.address
}

output "rds_port" {
  description = "RDS SQL Server port"
  value       = module.rds.port
}

output "rds_master_username" {
  description = "RDS SQL Server master username"
  value       = module.rds.master_username
}

output "rds_master_password" {
  description = "RDS SQL Server master password"
  value       = module.rds.master_password
  sensitive   = true
}
