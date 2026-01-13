################################################################################
# Security Group Module
#
# Creates security groups for the 3-tier application
################################################################################

resource "aws_security_group" "app" {
  name_prefix = "${var.project_name}-${var.environment}-app-sg"
  description = "Security group for BMI Health Tracker application"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-app-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Ingress Rules
################################################################################

# SSH Access
resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_cidr
  security_group_id = aws_security_group.app.id
  description       = "Allow SSH access"
}

# HTTP Access (Frontend - Nginx)
resource "aws_security_group_rule" "http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_http_cidr
  security_group_id = aws_security_group.app.id
  description       = "Allow HTTP access for frontend"
}

# HTTPS Access (Optional - for future SSL setup)
resource "aws_security_group_rule" "https" {
  count             = var.enable_https ? 1 : 0
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_http_cidr
  security_group_id = aws_security_group.app.id
  description       = "Allow HTTPS access"
}

# Backend API (Node.js - Internal only, proxied by Nginx)
# Not exposing port 3000 externally for security
# Backend is accessed via Nginx reverse proxy on port 80

# PostgreSQL (Internal only - localhost connections)
# Not exposing port 5432 externally for security
# Database is accessed locally on the instance

################################################################################
# Egress Rules
################################################################################

# Allow all outbound traffic
resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
  description       = "Allow all outbound traffic"
}

################################################################################
# Additional Security Group for RDS (if migrating to managed DB in future)
################################################################################

resource "aws_security_group" "database" {
  count = var.create_database_sg ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-db-sg"
  description = "Security group for PostgreSQL database (future use)"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-db-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "database_ingress" {
  count = var.create_database_sg ? 1 : 0

  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.database[0].id
  description              = "Allow PostgreSQL from application"
}
