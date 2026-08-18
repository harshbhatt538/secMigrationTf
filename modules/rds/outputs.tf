output "endpoint" {
  description = "RDS SQL Server endpoint (hostname:port)"
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "RDS SQL Server hostname"
  value       = aws_db_instance.main.address
}

output "port" {
  description = "RDS SQL Server port"
  value       = aws_db_instance.main.port
}

output "master_username" {
  description = "Master username for the RDS SQL Server instance"
  value       = aws_db_instance.main.username
}

output "master_password" {
  description = "Master password for the RDS SQL Server instance"
  value       = local.master_password
  sensitive   = true
}

output "db_subnet_group_name" {
  description = "Name of the RDS DB subnet group"
  value       = aws_db_subnet_group.main.name
}

output "parameter_group_name" {
  description = "Name of the RDS parameter group"
  value       = aws_db_parameter_group.main.name
}

output "option_group_name" {
  description = "Name of the RDS option group"
  value       = aws_db_option_group.main.name
}
