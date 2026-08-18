output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "windows_security_group_id" {
  value = aws_security_group.windows.id
}

output "rds_security_group_id" {
  value = aws_security_group.rds.id
}
