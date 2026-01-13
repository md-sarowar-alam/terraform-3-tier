################################################################################
# VPC Outputs
################################################################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

################################################################################
# Security Group Outputs
################################################################################

output "security_group_id" {
  description = "ID of the application security group"
  value       = module.security.security_group_id
}

################################################################################
# EC2 Outputs
################################################################################

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = module.ec2.instance_id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.ec2.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = module.ec2.public_dns
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = module.ec2.private_ip
}

################################################################################
# Application Access Information
################################################################################

output "application_url" {
  description = "URL to access the BMI Health Tracker application"
  value       = "http://${module.ec2.public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${module.ec2.public_ip}"
}

################################################################################
# Monitoring and Logs
################################################################################

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = module.ec2.cloudwatch_log_group
}

################################################################################
# Summary Output
################################################################################

output "deployment_summary" {
  description = "Summary of the deployment"
  value = {
    project_name       = var.project_name
    environment        = var.environment
    region             = var.aws_region
    instance_type      = var.instance_type
    public_ip          = module.ec2.public_ip
    application_url    = "http://${module.ec2.public_ip}"
    database_name      = var.db_name
    database_user      = var.db_user
  }
}
