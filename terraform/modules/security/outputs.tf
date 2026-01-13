output "security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.app.id
}

output "security_group_name" {
  description = "Name of the application security group"
  value       = aws_security_group.app.name
}

output "database_security_group_id" {
  description = "ID of the database security group (if created)"
  value       = var.create_database_sg ? aws_security_group.database[0].id : null
}
