################################################################################
# EC2 Module
#
# Creates EC2 instance with auto-deployment of 3-tier BMI Health Tracker app
################################################################################

################################################################################
# IAM Role for EC2 Instance (for CloudWatch, Systems Manager, etc.)
################################################################################

resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = var.tags
}

################################################################################
# CloudWatch Log Group for Application Logs
################################################################################

resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ec2/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = var.tags
}

################################################################################
# User Data Script
################################################################################

locals {
  user_data = templatefile("${path.module}/user-data.sh", {
    db_name               = var.db_name
    db_user               = var.db_user
    db_password           = var.db_password
    project_name          = var.project_name
    environment           = var.environment
    enable_auto_deployment = var.enable_auto_deployment
    cloudwatch_log_group  = aws_cloudwatch_log_group.app.name
  })
}

################################################################################
# EC2 Instance
################################################################################

resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_pair_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = var.associate_public_ip
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  monitoring                  = var.enable_detailed_monitoring

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = true
    encrypted             = true

    tags = merge(
      var.tags,
      {
        Name = "${var.project_name}-${var.environment}-root-volume"
      }
    )
  }

  user_data                   = local.user_data
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 required
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-app-server"
    }
  )

  lifecycle {
    ignore_changes = [ami]
  }
}

################################################################################
# Elastic IP (Optional - for static IP)
################################################################################

resource "aws_eip" "app" {
  count    = var.allocate_elastic_ip ? 1 : 0
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-eip"
    }
  )

  depends_on = [aws_instance.app]
}
