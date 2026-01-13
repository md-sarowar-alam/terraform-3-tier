output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app.id
}

output "instance_arn" {
  description = "ARN of the EC2 instance"
  value       = aws_instance.app.arn
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = var.allocate_elastic_ip ? aws_eip.app[0].public_ip : aws_instance.app.public_ip
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.app.private_ip
}

output "public_dns" {
  description = "Public DNS name of the instance"
  value       = aws_instance.app.public_dns
}

output "instance_state" {
  description = "State of the instance"
  value       = aws_instance.app.instance_state
}

output "availability_zone" {
  description = "Availability zone of the instance"
  value       = aws_instance.app.availability_zone
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.app.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.ec2.arn
}
