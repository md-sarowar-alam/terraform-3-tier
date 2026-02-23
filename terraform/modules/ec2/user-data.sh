#!/bin/bash
################################################################################
# BMI Health Tracker - EC2 User Data Script
# 
# This script runs on first boot and:
# 1. Updates the system
# 2. Installs prerequisites
# 3. Clones/copies the application code
# 4. Runs the deployment script
################################################################################

set -e

# Logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=========================================="
echo "Starting BMI Health Tracker Deployment"
echo "=========================================="
echo "Timestamp: $(date)"
echo ""

# Variables from Terraform
DB_NAME="${db_name}"
DB_USER="${db_user}"
DB_PASSWORD="${db_password}"
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"
ENABLE_AUTO_DEPLOYMENT="${enable_auto_deployment}"

# Paths
APP_DIR="/home/ubuntu/bmi-health-tracker"
DEPLOY_SCRIPT="$APP_DIR/IMPLEMENTATION_AUTO.sh"

################################################################################
# System Updates
################################################################################

echo "[INFO] Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
echo "[SUCCESS] System updated"

################################################################################
# Install Prerequisites
################################################################################

echo "[INFO] Installing prerequisites..."

# Install basic tools
apt-get install -y -qq \
    curl \
    wget \
    git \
    unzip \
    jq \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install PostgreSQL
echo "[INFO] Installing PostgreSQL..."
apt-get install -y -qq postgresql postgresql-contrib

# Start and enable PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# Install Nginx
echo "[INFO] Installing Nginx..."
apt-get install -y -qq nginx
systemctl start nginx
systemctl enable nginx

echo "[SUCCESS] Prerequisites installed"

################################################################################
# Install Node.js via NVM (as ubuntu user)
################################################################################

echo "[INFO] Installing Node.js via NVM..."
sudo -u ubuntu bash <<'EOFU'
set -e

# Install NVM
export HOME=/home/ubuntu
cd $HOME

if [ ! -d "$HOME/.nvm" ]; then
    echo "[INFO] Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    
    # Load NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    # Install Node.js LTS
    echo "[INFO] Installing Node.js LTS..."
    nvm install --lts
    nvm use --lts
    nvm alias default lts/*
    
    echo "[SUCCESS] Node.js $(node -v) installed"
else
    echo "[INFO] NVM already installed"
fi

# Install PM2 globally
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
npm install -g pm2
echo "[SUCCESS] PM2 installed"

EOFU

echo "[SUCCESS] Node.js environment configured"

################################################################################
# Setup Application Directory
################################################################################

echo "[INFO] Setting up application directory..."

# Clone application from GitHub repository
GIT_REPO="https://github.com/md-sarowar-alam/terraform-3-tier.git"

if [ -d "$APP_DIR/.git" ]; then
    echo "[INFO] Repository already exists, pulling latest changes..."
    sudo -u ubuntu bash -c "cd $APP_DIR && git pull"
else
    echo "[INFO] Cloning application from GitHub: $GIT_REPO"
    sudo -u ubuntu git clone $GIT_REPO $APP_DIR
    
    if [ $? -eq 0 ]; then
        echo "[SUCCESS] Application cloned successfully"
        chown -R ubuntu:ubuntu $APP_DIR
    else
        echo "[ERROR] Failed to clone repository"
        echo "[WARNING] Manual deployment will be required"
    fi
fi

# Make deployment script executable
if [ -f "$DEPLOY_SCRIPT" ]; then
    chmod +x $DEPLOY_SCRIPT
    chown ubuntu:ubuntu $DEPLOY_SCRIPT
    echo "[SUCCESS] Deployment script found and made executable"
else
    echo "[WARNING] Deployment script not found at $DEPLOY_SCRIPT"
fi

################################################################################
# Check if deployment script exists
################################################################################

if [ "$ENABLE_AUTO_DEPLOYMENT" = "true" ]; then
    echo "[INFO] Auto-deployment is enabled"
    
    if [ -f "$DEPLOY_SCRIPT" ]; then
        echo "[INFO] Found deployment script at $DEPLOY_SCRIPT"
        
        # Make script executable
        chmod +x $DEPLOY_SCRIPT
        chown ubuntu:ubuntu $DEPLOY_SCRIPT
        
        # Run deployment script as ubuntu user with database credentials
        echo "[INFO] Running deployment script non-interactively..."
        sudo -u ubuntu bash -c "
            set -e
            cd $APP_DIR
            
            # Export database credentials for non-interactive deployment
            export DB_NAME='$DB_NAME'
            export DB_USER='$DB_USER'
            export DB_PASSWORD='$DB_PASSWORD'
            export AUTO_CONFIRM='yes'
            
            # Run the deployment script
            echo '[INFO] Starting IMPLEMENTATION_AUTO.sh...'
            bash $DEPLOY_SCRIPT 2>&1 | tee -a /var/log/user-data.log
            
            echo '[SUCCESS] Deployment script completed'
        "
        
        echo "[SUCCESS] Deployment script executed"
        echo "[INFO] Check /var/log/user-data.log for details"
    else
        echo "[WARNING] Deployment script not found at $DEPLOY_SCRIPT"
        echo "[INFO] Manual deployment will be required"
        echo ""
        echo "To deploy manually, SSH into the instance and run:"
        echo "  cd $APP_DIR"
        echo "  export DB_NAME='$DB_NAME'"
        echo "  export DB_USER='$DB_USER'"
        echo "  export DB_PASSWORD='$DB_PASSWORD'"
        echo "  ./IMPLEMENTATION_AUTO.sh"
    fi
else
    echo "[INFO] Auto-deployment is disabled"
    echo "[INFO] To deploy manually, SSH into the instance and run:"
    echo "  cd $APP_DIR"
    echo "  export DB_NAME='$DB_NAME'"
    echo "  export DB_USER='$DB_USER'"
    echo "  export DB_PASSWORD='$DB_PASSWORD'"
    echo "  ./IMPLEMENTATION_AUTO.sh"
fi

################################################################################
# Create deployment info file
################################################################################

cat > /home/ubuntu/DEPLOYMENT_INFO.txt <<EOF
========================================
BMI Health Tracker - Deployment Info
========================================

Instance Details:
- Project: $PROJECT_NAME
- Environment: $ENVIRONMENT
- Deployment Date: $(date)

Application Directory: $APP_DIR

Database Configuration:
- Database Name: $DB_NAME
- Database User: $DB_USER
- Database Host: localhost
- Database Port: 5432

Application URLs:
- Frontend: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
- Backend API: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/api

Useful Commands:
- View deployment logs: sudo tail -f /var/log/user-data.log
- View backend logs: sudo tail -f /var/log/bmi-backend.log
- Restart backend: sudo systemctl restart bmi-backend
- Restart Nginx: sudo systemctl restart nginx
- Check PostgreSQL: sudo systemctl status postgresql

Manual Deployment:
If auto-deployment was not enabled, run:
  cd $APP_DIR
  ./IMPLEMENTATION_AUTO.sh

========================================
EOF

chown ubuntu:ubuntu /home/ubuntu/DEPLOYMENT_INFO.txt

################################################################################
# Install CloudWatch Agent (Optional)
################################################################################

echo "[INFO] Installing CloudWatch Agent..."
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
dpkg -i /tmp/amazon-cloudwatch-agent.deb
rm /tmp/amazon-cloudwatch-agent.deb

# Create CloudWatch Agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'EOFCW'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/user-data"
          },
          {
            "file_path": "/var/log/bmi-backend.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/backend"
          },
          {
            "file_path": "/var/log/nginx/bmi-access.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/nginx-access"
          },
          {
            "file_path": "/var/log/nginx/bmi-error.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/nginx-error"
          }
        ]
      }
    }
  }
}
EOFCW

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

echo "[SUCCESS] CloudWatch Agent configured and started"

################################################################################
# Final Status
################################################################################

echo ""
echo "=========================================="
echo "User Data Script Completed"
echo "=========================================="
echo "Timestamp: $(date)"
echo ""
echo "View deployment info: cat /home/ubuntu/DEPLOYMENT_INFO.txt"
echo "View this log: cat /var/log/user-data.log"
echo ""

# Signal completion
touch /var/lib/cloud/instance/deployed
