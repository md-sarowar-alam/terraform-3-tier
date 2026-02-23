# BMI Health Tracker - Terraform Deployment Guide

Complete guide to deploy the 3-tier BMI Health Tracker application on AWS EC2 using Terraform.

## 📋 What This Will Deploy

**Single EC2 Instance Running:**
- **Frontend**: React + Vite app served by Nginx (Port 80)
- **Backend**: Node.js Express API (Port 3000)
- **Database**: PostgreSQL 14 (Port 5432)

**AWS Infrastructure:**
- Custom VPC with 2 public subnets
- Internet Gateway and routing
- Security Groups (SSH + HTTP)
- EC2 Instance (Ubuntu 22.04, t3.medium)
- IAM roles for CloudWatch
- S3 backend for Terraform state

**Estimated Cost**: ~$40/month

---

## 🚀 Quick Start (5 Steps)

### Prerequisites Checklist
- [ ] Terraform installed
- [ ] AWS CLI configured with profile
- [ ] EC2 key pair created
- [ ] S3 bucket name chosen

### Step 1: Create EC2 Key Pair

```powershell
# Check existing key pairs
aws ec2 describe-key-pairs --profile sarowar-ostad --region ap-south-1 --query 'KeyPairs[*].KeyName'

# Create new key pair (if needed)
aws ec2 create-key-pair --key-name bmi-health-tracker-key --profile sarowar-ostad --region ap-south-1 --query 'KeyMaterial' --output text | Out-File -Encoding ascii -FilePath $env:USERPROFILE\.ssh\bmi-health-tracker-key.pem
```

### Step 2: Create S3 Bucket for State

```powershell
# Choose a globally unique bucket name
$BUCKET_NAME = "terraform-state-sarowar-bmi-tracker"

# Create bucket
aws s3 mb s3://$BUCKET_NAME --profile sarowar-ostad --region ap-south-1

# Enable versioning
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled --profile sarowar-ostad
```

### Step 3: Configure terraform.tfvars

Edit `terraform.tfvars` and update:

```hcl
# Required changes:
key_pair_name = "bmi-health-tracker-key"  # Your key pair name
db_password   = "YourSecurePassword123!"  # Strong password
allowed_ssh_cidr = ["YOUR_IP/32"]         # Your IP only (get it from ipify.org)
```

### Step 4: Initialize and Deploy

```powershell
# Navigate to terraform directory
cd terraform

# Initialize Terraform with S3 backend
terraform init `
  -backend-config="bucket=$BUCKET_NAME" `
  -backend-config="key=bmi-health-tracker/terraform.tfstate" `
  -backend-config="region=ap-south-1" `
  -backend-config="profile=sarowar-ostad"

# Review what will be created
terraform plan

# Deploy infrastructure
terraform apply
```

### Step 5: Upload and Deploy Application

```powershell
# Get instance IP
$INSTANCE_IP = terraform output -raw instance_public_ip

# Upload application files
scp -i $env:USERPROFILE\.ssh\bmi-health-tracker-key.pem -r ../backend ../frontend ../database ../IMPLEMENTATION_AUTO.sh ubuntu@${INSTANCE_IP}:/home/ubuntu/bmi-health-tracker/

# SSH into instance
ssh -i $env:USERPROFILE\.ssh\bmi-health-tracker-key.pem ubuntu@$INSTANCE_IP

# On the EC2 instance, run:
cd /home/ubuntu/bmi-health-tracker
chmod +x IMPLEMENTATION_AUTO.sh
./IMPLEMENTATION_AUTO.sh
```

---

## 📁 Project Structure

This Terraform configuration deploys a **3-tier application** on a **single EC2 instance**:

- **Frontend Tier**: React application built with Vite, served by Nginx (port 80)
- **Backend Tier**: Node.js Express API (port 3000, proxied by Nginx)
- **Database Tier**: PostgreSQL 14 (localhost, port 5432)

### AWS Resources Created

- **VPC**: Custom VPC with public subnets across 2 AZs
- **Security Groups**: Configured for SSH (22), HTTP (80)
- **EC2 Instance**: Ubuntu 22.04 LTS with auto-deployment
- **IAM Role**: For CloudWatch and Systems Manager access
- **CloudWatch Log Groups**: For application logging
- **S3 Backend**: Remote state storage with encryption

## 📦 Prerequisites

### Required Tools

1. **Terraform** >= 1.0
   ```bash
   # Install Terraform
   # Windows (with Chocolatey)
   choco install terraform
   
   # macOS (with Homebrew)
   brew install terraform
   
   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

2. **AWS CLI** configured with named profile
   ```bash
   # Install AWS CLI
   # https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
   
   # Configure AWS profile
   aws configure --profile your-profile-name
   ```

3. **SSH Key Pair** created in AWS
   ```bash
   # Create a new key pair
   aws ec2 create-key-pair \
     --key-name bmi-health-tracker-key \
     --query 'KeyMaterial' \
     --output text \
     --profile your-profile-name > ~/.ssh/bmi-health-tracker-key.pem
   
   # Set permissions
   chmod 400 ~/.ssh/bmi-health-tracker-key.pem
   ```

### AWS Requirements

- AWS Account with appropriate permissions
- VPC quota for creating resources
- EC2 key pair in the target region

## 📁 Project Structure

```
terraform/
├── main.tf                          # Main configuration
├── variables.tf                     # Input variables
├── outputs.tf                       # Output values
├── provider.tf                      # AWS provider configuration
├── backend.tf                       # S3 backend configuration
├── terraform.tfvars.example         # Example variables file
├── README.md                        # This file
│
├── modules/
│   ├── vpc/                        # VPC module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── security/                   # Security groups module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── ec2/                        # EC2 instance module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── user-data.sh            # Bootstrap script
│
└── DEPLOYMENT_GUIDE.md             # Detailed deployment guide
```

## 🚀 Setup Instructions

### Step 1: Prepare S3 Backend

Create an S3 bucket for Terraform state storage:

```bash
# Set your AWS profile
export AWS_PROFILE=your-profile-name

# Create S3 bucket (replace with your unique name)
aws s3 mb s3://your-terraform-state-bucket-name --region ap-south-1

# Enable versioning (recommended for state history)
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket-name \
  --versioning-configuration Status=Enabled

# Enable encryption (recommended for security)
aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket-name \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### Step 2: Upload Application Code

The application code needs to be available on the EC2 instance. You have several options:

**Option A: Git Repository (Recommended)**
1. Push your application code to a Git repository
2. Modify `user-data.sh` to clone from your repository

**Option B: S3 Upload**
1. Create an S3 bucket for application code
2. Upload the application files
3. Modify `user-data.sh` to download from S3

**Option C: Manual Upload After Deployment**
1. Deploy infrastructure first
2. SCP files to the instance after it's running

For this guide, we'll assume **Option C** for simplicity.

### Step 3: Configure Variables

```bash
cd terraform/

# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
nano terraform.tfvars
```

**Required values in terraform.tfvars:**

```hcl
# AWS Configuration
aws_region  = "ap-south-1"
aws_profile = "your-aws-profile-name"

# S3 Backend
s3_bucket_name = "your-terraform-state-bucket"

# EC2 Configuration
key_pair_name = "your-key-pair-name"  # IMPORTANT!

# Database Configuration
db_password = "YourSecurePassword123!"  # CHANGE THIS!

# Security (IMPORTANT: Restrict in production!)
allowed_ssh_cidr = ["YOUR_IP_ADDRESS/32"]  # Your IP only
```

## 🚀 Deployment

### Step 1: Initialize Terraform

```bash
cd terraform/

# Initialize with backend configuration
terraform init \
  -backend-config="bucket=your-terraform-state-bucket" \
  -backend-config="key=bmi-health-tracker/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="profile=your-aws-profile"
```

### Step 2: Review Plan

```bash
terraform plan
```

Review the resources that will be created. You should see:
- VPC and networking resources
- Security groups
- EC2 instance
- IAM roles and policies
- CloudWatch log groups

### Step 3: Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted.

**Deployment Time**: 5-10 minutes

### Step 4: Get Instance Information

```bash
# Get all outputs
terraform output

# Get specific outputs
terraform output application_url
terraform output ssh_command
terraform output instance_public_ip
```

## 📤 Upload Application Code

After the instance is running, upload your application code:

```bash
# Get the instance public IP
INSTANCE_IP=$(terraform output -raw instance_public_ip)

# Upload application files
scp -i ~/.ssh/your-key-pair.pem -r ../backend ../frontend ../database ../IMPLEMENTATION_AUTO.sh ubuntu@$INSTANCE_IP:/home/ubuntu/bmi-health-tracker/

# Or use rsync for better performance
rsync -avz -e "ssh -i ~/.ssh/your-key-pair.pem" \
  --exclude 'node_modules' \
  --exclude '.git' \
  ../backend ../frontend ../database ../IMPLEMENTATION_AUTO.sh \
  ubuntu@$INSTANCE_IP:/home/ubuntu/bmi-health-tracker/
```

## 🎯 Post-Deployment

### Step 1: SSH into Instance

```bash
# Use the SSH command from outputs
terraform output ssh_command

# Or manually
ssh -i ~/.ssh/your-key-pair.pem ubuntu@$(terraform output -raw instance_public_ip)
```

### Step 2: Run Deployment Script

```bash
# On the EC2 instance
cd /home/ubuntu/bmi-health-tracker

# Make script executable
chmod +x IMPLEMENTATION_AUTO.sh

# Run deployment
./IMPLEMENTATION_AUTO.sh
```

The script will:
1. Install Node.js and dependencies
2. Setup PostgreSQL database
3. Configure backend with environment variables
4. Build and deploy frontend
5. Setup systemd service for backend
6. Configure Nginx

**Deployment time**: 10-15 minutes

### Step 3: Verify Deployment

```bash
# Check backend service
sudo systemctl status bmi-backend

# Check Nginx
sudo systemctl status nginx

# View logs
sudo tail -f /var/log/bmi-backend.log
sudo tail -f /var/log/nginx/bmi-access.log
```

### Step 4: Access Application

Open your browser and navigate to:
```
http://<instance-public-ip>
```

## 🔍 Monitoring

### CloudWatch Logs

View logs in AWS CloudWatch:
```bash
aws logs tail /aws/ec2/bmi-health-tracker-dev --follow --profile your-profile
```

### Local Logs

```bash
# User data log (bootstrap)
sudo tail -f /var/log/user-data.log

# Backend application
sudo tail -f /var/log/bmi-backend.log

# Nginx access logs
sudo tail -f /var/log/nginx/bmi-access.log

# Nginx error logs
sudo tail -f /var/log/nginx/bmi-error.log
```

## 🗑️ Cleanup

To destroy all resources:

```bash
cd terraform/

# Preview what will be destroyed
terraform plan -destroy

# Destroy resources
terraform destroy

# Type 'yes' when prompted
```

**Important**: This will delete:
- EC2 instance (and all data on it)
- VPC and networking
- Security groups
- CloudWatch logs (based on retention policy)

The S3 backend bucket will NOT be deleted (manual deletion required).

## 🔧 Troubleshooting

### Issue: Terraform Init Fails

**Problem**: Backend configuration error

**Solution**:
```bash
# Verify S3 bucket exists
aws s3 ls s3://your-terraform-state-bucket --profile your-profile

# Re-run init with correct parameters
terraform init -reconfigure \
  -backend-config="bucket=your-terraform-state-bucket" \
  -backend-config="key=bmi-health-tracker/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="profile=your-aws-profile"
```

### Issue: Cannot SSH into Instance

**Problem**: Connection timeout or permission denied

**Solution**:
```bash
# 1. Check security group allows your IP
terraform output security_group_id
aws ec2 describe-security-groups --group-ids <sg-id> --profile your-profile

# 2. Verify key permissions
chmod 400 ~/.ssh/your-key-pair.pem

# 3. Check instance is running
terraform output instance_id
aws ec2 describe-instances --instance-ids <instance-id> --profile your-profile

# 4. Update security group if needed (edit terraform.tfvars)
allowed_ssh_cidr = ["YOUR_CURRENT_IP/32"]
terraform apply
```

### Issue: Application Not Accessible

**Problem**: Cannot access application on port 80

**Solution**:
```bash
# 1. SSH into instance
ssh -i ~/.ssh/your-key-pair.pem ubuntu@<instance-ip>

# 2. Check Nginx status
sudo systemctl status nginx
sudo nginx -t

# 3. Check backend status
sudo systemctl status bmi-backend

# 4. Check ports
sudo netstat -tlnp | grep -E ':(80|3000|5432)'

# 5. View logs
sudo tail -f /var/log/bmi-backend.log
sudo tail -f /var/log/nginx/bmi-error.log

# 6. Restart services
sudo systemctl restart bmi-backend
sudo systemctl restart nginx
```

### Issue: Database Connection Failed

**Problem**: Backend cannot connect to PostgreSQL

**Solution**:
```bash
# 1. Check PostgreSQL is running
sudo systemctl status postgresql

# 2. Test database connection
psql -U bmi_user -d bmidb -h localhost

# 3. Check pg_hba.conf
sudo cat /etc/postgresql/*/main/pg_hba.conf | grep bmidb

# 4. Verify .env file
cat /home/ubuntu/bmi-health-tracker/backend/.env

# 5. Restart PostgreSQL
sudo systemctl restart postgresql
```

## 📝 Additional Notes

### Cost Estimation

- **EC2 t3.medium**: ~$30-35/month (On-Demand)
- **EBS gp3 30GB**: ~$2.40/month
- **Data Transfer**: Variable based on usage
- **S3 State Storage**: < $1/month

**Total Estimated Cost**: ~$35-40/month

### Security Recommendations

1. **Restrict SSH Access**: Change `allowed_ssh_cidr` to your IP only
2. **Use Elastic IP**: Set `allocate_elastic_ip = true` for static IP
3. **Enable HTTPS**: Setup SSL/TLS with Let's Encrypt
4. **Database Security**: Consider migrating to RDS with encryption
5. **Secrets Management**: Use AWS Secrets Manager for passwords
6. **VPC Endpoints**: Add S3 VPC endpoints to avoid data transfer costs

### Scaling Considerations

For production workloads, consider:
- **Application Load Balancer**: For multiple instances
- **Auto Scaling Group**: For automatic scaling
- **RDS PostgreSQL**: Managed database with backups
- **ElastiCache**: For session storage and caching
- **CloudFront**: For CDN and SSL termination
- **Route53**: For custom domain management

## 📚 References

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EC2 User Guide](https://docs.aws.amazon.com/ec2/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

## 📧 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review AWS CloudWatch logs
3. Check `/var/log/user-data.log` on the instance
4. Review the IMPLEMENTATION_AUTO.sh script

---

## 🧑‍💻 Author

*Md. Sarowar Alam*  
Lead DevOps Engineer, Hogarth Worldwide  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: https://www.linkedin.com/in/sarowar/
