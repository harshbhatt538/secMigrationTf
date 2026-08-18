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
