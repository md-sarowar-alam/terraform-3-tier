################################################################################
# General Variables
################################################################################

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name to use for authentication"
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "bmi-health-tracker"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "DevOps Team"
}

################################################################################
# Backend Configuration Variables
# Note: Backend configuration is done via terraform init command line arguments
################################################################################

################################################################################
# VPC Variables
################################################################################

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = []  # Will use first 2 AZs in the region if not specified
}

################################################################################
# EC2 Variables
################################################################################

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "AMI ID for Ubuntu 22.04 LTS (leave empty to use latest Ubuntu 22.04)"
  type        = string
  default     = ""  # Will auto-detect latest Ubuntu 22.04 LTS if empty
}

variable "key_pair_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
}

variable "root_volume_size" {
  description = "Size of root EBS volume in GB"
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "Type of root EBS volume"
  type        = string
  default     = "gp3"
}

################################################################################
# Database Configuration Variables
################################################################################

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "bmidb"
}

variable "db_user" {
  description = "PostgreSQL database user"
  type        = string
  default     = "bmi_user"
}

variable "db_password" {
  description = "PostgreSQL database password (should be stored securely)"
  type        = string
  sensitive   = true
}

################################################################################
# Security Variables
################################################################################

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH into the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # WARNING: Restrict this in production!
}

variable "allowed_http_cidr" {
  description = "CIDR blocks allowed to access HTTP"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

################################################################################
# Application Variables
################################################################################

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for EC2"
  type        = bool
  default     = false
}

variable "associate_public_ip" {
  description = "Associate a public IP address with the instance"
  type        = bool
  default     = true
}

variable "enable_auto_deployment" {
  description = "Automatically run deployment script on instance launch"
  type        = bool
  default     = true
}
