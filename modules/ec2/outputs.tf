output "instance_id" {
  value = aws_instance.main.id
}

output "public_ip" {
  value = var.create_eip ? aws_eip.main[0].public_ip : aws_instance.main.public_ip
}

output "private_ip" {
  value = aws_instance.main.private_ip
}

output "public_dns" {
  value = aws_instance.main.public_dns
}

output "iam_role_name" {
  value = aws_iam_role.ec2.name
}

output "availability_zone" {
  value = aws_instance.main.availability_zone
}
