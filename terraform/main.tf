################################################################################
# BMI Health Tracker - Main Terraform Configuration
#
# This configuration deploys a 3-tier application (Frontend/Backend/Database)
# on a single EC2 instance in AWS
################################################################################

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

################################################################################
# Data Sources
################################################################################

# Get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Get latest Ubuntu 22.04 LTS AMI if not specified
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  availability_zones  = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
  
  tags = local.common_tags
}

################################################################################
# Security Module
################################################################################

module "security" {
  source = "./modules/security"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id           = module.vpc.vpc_id
  allowed_ssh_cidr = var.allowed_ssh_cidr
  allowed_http_cidr = var.allowed_http_cidr
  
  tags = local.common_tags
}

################################################################################
# EC2 Module
################################################################################

module "ec2" {
  source = "./modules/ec2"

  project_name              = var.project_name
  environment               = var.environment
  ami_id                   = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type            = var.instance_type
  key_pair_name            = var.key_pair_name
  subnet_id                = module.vpc.public_subnet_ids[0]
  security_group_ids       = [module.security.security_group_id]
  associate_public_ip      = var.associate_public_ip
  root_volume_size         = var.root_volume_size
  root_volume_type         = var.root_volume_type
  enable_detailed_monitoring = var.enable_detailed_monitoring
  
  # Application configuration
  db_name               = var.db_name
  db_user               = var.db_user
  db_password           = var.db_password
  enable_auto_deployment = var.enable_auto_deployment
  
  tags = local.common_tags
}
