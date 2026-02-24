# BMI Health Tracker - Implementation Guide

**Complete step-by-step guide to deploy the 3-tier application on AWS using Terraform**

---

## 🎯 What You'll Deploy

A complete web application running on a single AWS EC2 instance:
- **Frontend**: React + Vite (served by Nginx on port 80)
- **Backend**: Node.js + Express API (port 3000)
- **Database**: PostgreSQL 14 (port 5432)

**Infrastructure**: VPC, Subnets, Security Groups, IAM Roles, CloudWatch Logs

**Cost**: ~$40/month | **Time**: 30-45 minutes total

---

## ✅ Pre-Deployment Checklist

Before starting, ensure you have:

- [ ] **Terraform** installed (v1.0+)
- [ ] **AWS CLI** configured
- [ ] **AWS Profile** ready (`sarowar-ostad` or `sarowar-sp`)
- [ ] **EC2 Key Pair** created (or will create one)
- [ ] **Your Public IP** address (for SSH security)
- [ ] **S3 Bucket name** chosen (globally unique)

---

## 📋 Step-by-Step Implementation

### STEP 1: Verify Prerequisites

```powershell
# Check Terraform
terraform version
# Should show: Terraform v1.x.x

# Check AWS CLI
aws --version
# Should show: aws-cli/2.x.x

# Check your AWS profiles
aws configure list-profiles
# Should show: sarowar-ostad, sarowar-sp

# Test AWS access
aws sts get-caller-identity --profile sarowar-ostad
# Should show your AWS account details
```

✅ **If all commands work, proceed to Step 2**

---

### STEP 2: Create EC2 Key Pair

**Check existing key pairs:**
```powershell
aws ec2 describe-key-pairs --profile sarowar-ostad --region ap-south-1 --query 'KeyPairs[*].KeyName' --output table
```

**Option A: Use existing key**
- If you see a key you want to use, note its name
- Make sure you have the .pem file saved

**Option B: Create new key**
```powershell
# Create new key pair
aws ec2 create-key-pair `
  --key-name bmi-health-tracker-key `
  --profile sarowar-ostad `
  --region ap-south-1 `
  --query 'KeyMaterial' `
  --output text | Out-File -Encoding ascii -FilePath $env:USERPROFILE\.ssh\bmi-health-tracker-key.pem

# Verify key file was created
Test-Path $env:USERPROFILE\.ssh\bmi-health-tracker-key.pem
# Should return: True
```

💾 **Save this key name - you'll need it in terraform.tfvars**

---

### STEP 3: Create S3 Bucket for Terraform State

```powershell
# Choose a globally unique name (add random numbers if needed)
$BUCKET_NAME = "terraform-state-sarowar-bmi-2026"

# Create bucket
aws s3 mb s3://$BUCKET_NAME --profile sarowar-ostad --region ap-south-1

# Enable versioning (important for state history)
aws s3api put-bucket-versioning `
  --bucket $BUCKET_NAME `
  --versioning-configuration Status=Enabled `
  --profile sarowar-ostad

# Enable encryption (security best practice)
aws s3api put-bucket-encryption `
  --bucket $BUCKET_NAME `
  --server-side-encryption-configuration '{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"AES256\"}}]}' `
  --profile sarowar-ostad

# Verify bucket was created
aws s3 ls s3://$BUCKET_NAME --profile sarowar-ostad

# IMPORTANT: Save this bucket name!
Write-Host "S3 Bucket Created: $BUCKET_NAME" -ForegroundColor Green
```

📝 **Write down your bucket name - you'll need it for terraform init**

---

### STEP 4: Get Your Public IP (for SSH security)

```powershell
# Get your current public IP
$MY_IP = (Invoke-WebRequest -Uri "https://api.ipify.org").Content
Write-Host "Your Public IP: $MY_IP" -ForegroundColor Green

# Or visit: https://www.whatismyip.com
```

📝 **Save your IP address - you'll use it in terraform.tfvars as: `["YOUR_IP/32"]`**

---

### STEP 5: Configure terraform.tfvars

```powershell
# Navigate to terraform directory
cd terraform

# terraform.tfvars already exists (we created it earlier)
# Open it for editing
code terraform.tfvars
```

**Edit these REQUIRED values:**

```hcl
# 1. AWS Configuration (should already be set)
aws_profile = "sarowar-ostad"  # or "sarowar-sp"

# 2. EC2 Key Pair - CHANGE THIS!
key_pair_name = "bmi-health-tracker-key"  # Use YOUR key name from Step 2

# 3. Database Password - CHANGE THIS!
db_password = "MySecurePassword2026!"  # Must be strong!

# 4. SSH Security - CHANGE THIS!
allowed_ssh_cidr = ["203.0.113.25/32"]  # Use YOUR IP from Step 4
# Example: If your IP is 42.123.45.67, use: ["42.123.45.67/32"]
```

**Optional changes:**
```hcl
# Change region if needed
aws_region = "ap-south-1"

# Use smaller/larger instance
instance_type = "t3.medium"  # or "t3.small" (cheaper) or "t3.large" (more power)
```

💾 **Save the file (Ctrl+S)**

**Verify your configuration:**
```powershell
# Check key values are set
Get-Content terraform.tfvars | Select-String -Pattern "key_pair_name|db_password|allowed_ssh_cidr"
```

---

### STEP 6: Initialize Terraform

```powershell
# Make sure you're in terraform directory
cd terraform

# Initialize Terraform with S3 backend
# REPLACE 'terraform-state-sarowar-bmi-2026' with YOUR bucket name from Step 3
terraform init `
  -backend-config="bucket=terraform-state-sarowar-bmi-2026" `
  -backend-config="key=bmi-health-tracker/terraform.tfstate" `
  -backend-config="region=ap-south-1" `
  -backend-config="profile=sarowar-ostad"
```

**Expected output:**
```
Initializing modules...
Initializing the backend...
Successfully configured the backend "s3"!
Initializing provider plugins...
Terraform has been successfully initialized!
```

✅ **If you see "successfully initialized", proceed to Step 7**

❌ **If you see errors:**
- Check S3 bucket name is correct
- Verify AWS profile works: `aws s3 ls --profile sarowar-ostad`
- Check bucket exists: `aws s3 ls s3://YOUR_BUCKET_NAME --profile sarowar-ostad`

---

### STEP 7: Validate Configuration

```powershell
# Format code (optional but recommended)
terraform fmt

# Validate syntax
terraform validate
```

**Expected output:**
```
Success! The configuration is valid.
```

✅ **If valid, proceed to Step 8**

---

### STEP 8: Review Deployment Plan

```powershell
# Generate execution plan
terraform plan

# Review the output carefully
# You should see approximately 15 resources to be created:
# - VPC
# - 2 Subnets
# - Internet Gateway
# - Route Table
# - Security Group
# - IAM Role
# - IAM Instance Profile
# - EC2 Instance
# - CloudWatch Log Group
# - etc.
```

**Look for:**
- `Plan: 15 to add, 0 to change, 0 to destroy`
- No errors in red
- Resources look correct

✅ **If plan looks good, proceed to Step 9**

---

### STEP 9: Deploy Infrastructure

```powershell
# Deploy all resources
terraform apply

# Terraform will show the plan again
# Type: yes
# Press Enter
```

**Deployment takes 5-10 minutes**

Watch the output - you'll see resources being created:
```
module.vpc.aws_vpc.main: Creating...
module.vpc.aws_vpc.main: Creation complete after 2s
module.vpc.aws_subnet.public[0]: Creating...
module.security.aws_security_group.app: Creating...
...
module.ec2.aws_instance.app: Still creating... [10s elapsed]
...
Apply complete! Resources: 15 added, 0 changed, 0 destroyed.
```

**Expected output at end:**
```
Apply complete! Resources: 15 added, 0 changed, 0 destroyed.

Outputs:

application_url = "http://54.123.45.67"
instance_public_ip = "54.123.45.67"
ssh_command = "ssh -i ~/.ssh/bmi-health-tracker-key.pem ubuntu@54.123.45.67"
...
```

✅ **Infrastructure is now deployed!**

---

### STEP 10: Save Instance Information

```powershell
# Get instance IP
$INSTANCE_IP = terraform output -raw instance_public_ip
Write-Host "Instance IP: $INSTANCE_IP" -ForegroundColor Green

# View all outputs
terraform output

# Get SSH command
terraform output ssh_command
```

📝 **Save the instance IP - you'll need it next**

---

### STEP 11: Wait for Instance Bootstrap

The EC2 instance is now running, but it's installing software automatically (user-data script).

**Wait 2-3 minutes** for:
- System updates
- PostgreSQL installation
- Node.js installation via NVM
- Nginx installation
- CloudWatch agent setup

**Check bootstrap status:**
```powershell
# Check if instance is ready
aws ec2 describe-instance-status `
  --instance-ids $(terraform output -raw instance_id) `
  --profile sarowar-ostad `
  --region ap-south-1 `
  --query 'InstanceStatuses[0].InstanceStatus.Status' `
  --output text

# Should return: ok
```

---

### STEP 12: Upload Application Code

```powershell
# Set variables
$INSTANCE_IP = terraform output -raw instance_public_ip
$KEY_FILE = "$env:USERPROFILE\.ssh\bmi-health-tracker-key.pem"

# Navigate to project root (parent of terraform directory)
cd ..

# Upload application files using SCP
scp -i $KEY_FILE -r backend frontend database IMPLEMENTATION_AUTO.sh ubuntu@${INSTANCE_IP}:/home/ubuntu/bmi-health-tracker/
```

**Expected output:**
```
backend/package.json                100%  ...
backend/src/server.js              100%  ...
frontend/package.json              100%  ...
...
IMPLEMENTATION_AUTO.sh             100%  ...
```

✅ **Files uploaded successfully!**

**Alternative method using rsync (if available):**
```powershell
rsync -avz -e "ssh -i $KEY_FILE" `
  --exclude 'node_modules' `
  --exclude '.git' `
  --exclude 'terraform' `
  backend frontend database IMPLEMENTATION_AUTO.sh `
  ubuntu@${INSTANCE_IP}:/home/ubuntu/bmi-health-tracker/
```

---

### STEP 13: SSH into Instance

```powershell
# Connect to EC2 instance
ssh -i $KEY_FILE ubuntu@$INSTANCE_IP

# You should see Ubuntu welcome message and prompt:
# ubuntu@ip-10-0-1-123:~$
```

✅ **You're now on the EC2 instance!**

---

### STEP 14: Deploy Application (on EC2 instance)

**Now on the EC2 instance, run these commands:**

```bash
# Navigate to application directory
cd /home/ubuntu/bmi-health-tracker

# Verify files are uploaded
ls -la
# Should see: backend/  frontend/  database/  IMPLEMENTATION_AUTO.sh

# Make deployment script executable
chmod +x IMPLEMENTATION_AUTO.sh

# Run deployment script
./IMPLEMENTATION_AUTO.sh
```

**The script will prompt you:**

1. **Database name** (default: bmidb)
   - Press Enter to use default

2. **Database user** (default: bmi_user)
   - Press Enter to use default

3. **Database password**
   - Enter the SAME password you set in terraform.tfvars
   - Example: `MySecurePassword2026!`

4. **Confirm password**
   - Enter the password again

5. **Continue with deployment? (y/n)**
   - Type: `y`
   - Press Enter

**Deployment takes 10-15 minutes** and will:
1. ✅ Install NVM and Node.js
2. ✅ Setup PostgreSQL database and user
3. ✅ Install backend dependencies (npm install)
4. ✅ Run database migrations
5. ✅ Build frontend with Vite
6. ✅ Deploy frontend to /var/www/bmi-health-tracker
7. ✅ Configure Nginx reverse proxy
8. ✅ Setup systemd service for backend
9. ✅ Start all services

**Watch for successful completion:**
```
[SUCCESS] BMI Backend service started successfully
[SUCCESS] Frontend deployed to /var/www/bmi-health-tracker
[SUCCESS] Nginx configuration is valid
[SUCCESS] Nginx is running
[SUCCESS] Deployment completed successfully!

========================================
Deployment Complete!
========================================

Application Access:
  URL: http://54.123.45.67

Useful Commands:
  View backend logs:       sudo tail -f /var/log/bmi-backend.log
  Restart backend:         sudo systemctl restart bmi-backend
  Check backend status:    sudo systemctl status bmi-backend
  ...
```

✅ **Application is now deployed!**

---

### STEP 15: Verify Services

**Still on EC2 instance, check all services are running:**

```bash
# Check backend service
sudo systemctl status bmi-backend
# Should show: Active: active (running)

# Check Nginx
sudo systemctl status nginx
# Should show: Active: active (running)

# Check PostgreSQL
sudo systemctl status postgresql
# Should show: Active: active (exited)

# Test backend API
curl http://localhost:3000/api/measurements
# Should return: [] (empty array) or measurement data

# Test frontend
curl http://localhost | head -n 5
# Should return: HTML content

# Check database
psql -U bmi_user -d bmidb -h localhost -c "SELECT COUNT(*) FROM measurements;"
# Enter database password when prompted
# Should return: count
```

✅ **All services are running!**

---

### STEP 16: Access Application

**On your local computer:**

1. Get the application URL:
```powershell
terraform output application_url
# Example: http://54.123.45.67
```

2. Open your web browser

3. Navigate to: `http://YOUR_INSTANCE_IP`

4. You should see the **BMI Health Tracker** interface!

---

### STEP 17: Test Application

**Test the BMI Calculator:**

1. Fill in the form:
   - **Weight (kg)**: 70
   - **Height (cm)**: 175
   - **Age**: 30
   - **Sex**: Male
   - **Activity Level**: Moderate

2. Click **"Calculate BMI"**

3. You should see:
   - ✅ BMI result (22.9)
   - ✅ BMI category (Normal Weight)
   - ✅ BMR calculation
   - ✅ Daily calorie needs
   - ✅ Measurement saved to database

4. Add more measurements and see the trend chart!

✅ **Application is fully functional!**

---

## 📊 Monitoring & Logs

### View Application Logs

**On EC2 instance:**
```bash
# Backend application log
sudo tail -f /var/log/bmi-backend.log

# Nginx access log
sudo tail -f /var/log/nginx/bmi-access.log

# Nginx error log
sudo tail -f /var/log/nginx/bmi-error.log

# User data bootstrap log
sudo tail -f /var/log/user-data.log

# PostgreSQL log
sudo tail -f /var/log/postgresql/postgresql-14-main.log
```

### CloudWatch Logs (from local machine)

```powershell
# View CloudWatch logs
aws logs tail /aws/ec2/bmi-health-tracker-dev --follow --profile sarowar-ostad

# View specific log stream
aws logs tail /aws/ec2/bmi-health-tracker-dev --follow --filter-pattern "ERROR" --profile sarowar-ostad
```

---

## 🔧 Common Issues & Solutions

### Issue 1: Can't SSH into instance

**Problem**: Connection timeout or "Connection refused"

**Solutions:**
```powershell
# 1. Check your current IP (it may have changed)
$MY_IP = (Invoke-WebRequest -Uri "https://api.ipify.org").Content
Write-Host "Current IP: $MY_IP"

# 2. If IP changed, update terraform.tfvars
# Edit allowed_ssh_cidr = ["NEW_IP/32"]

# 3. Apply changes
terraform apply

# 4. Verify instance is running
aws ec2 describe-instances `
  --instance-ids $(terraform output -raw instance_id) `
  --profile sarowar-ostad `
  --query 'Reservations[0].Instances[0].State.Name'
# Should return: "running"
```

### Issue 2: Application not accessible in browser

**Problem**: Can't access http://instance-ip

**Solutions:**
```bash
# SSH into instance and check:

# 1. Check Nginx is running
sudo systemctl status nginx
sudo nginx -t

# 2. Check backend is running
sudo systemctl status bmi-backend
curl http://localhost:3000/api/measurements

# 3. Check ports are listening
sudo netstat -tlnp | grep -E ':(80|3000)'

# 4. Restart services
sudo systemctl restart bmi-backend nginx

# 5. Check logs for errors
sudo tail -50 /var/log/bmi-backend.log
sudo tail -50 /var/log/nginx/bmi-error.log
```

### Issue 3: Database connection failed

**Problem**: Backend can't connect to PostgreSQL

**Solutions:**
```bash
# 1. Check PostgreSQL is running
sudo systemctl status postgresql

# 2. Check database exists
sudo -u postgres psql -l | grep bmidb

# 3. Test connection with correct password
psql -U bmi_user -d bmidb -h localhost

# 4. Check .env file has correct password
cat /home/ubuntu/bmi-health-tracker/backend/.env

# 5. Restart backend after fixing password
sudo systemctl restart bmi-backend
```

### Issue 4: Terraform apply fails

**Error: "InvalidKeyPair.NotFound"**
```powershell
# Key pair doesn't exist - check name is correct
aws ec2 describe-key-pairs --profile sarowar-ostad --region ap-south-1
# Update key_pair_name in terraform.tfvars
```

**Error: "VpcLimitExceeded"**
```powershell
# Delete unused VPCs or request limit increase
aws ec2 describe-vpcs --profile sarowar-ostad --region ap-south-1
```

---

## 🗑️ Cleanup / Destroy Resources

**When you're done testing, destroy all resources to avoid charges:**

```powershell
cd terraform

# Preview what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Type: yes
# Press Enter

# Takes 5-10 minutes
```

**Expected output:**
```
Destroy complete! Resources: 15 destroyed.
```

**Note:** S3 bucket is NOT deleted. Delete manually if needed:
```powershell
# Delete bucket contents first
aws s3 rm s3://YOUR_BUCKET_NAME --recursive --profile sarowar-ostad

# Delete bucket
aws s3 rb s3://YOUR_BUCKET_NAME --profile sarowar-ostad
```

---

## 📝 Summary Checklist

After completing all steps, you should have:

- ✅ EC2 instance running in AWS
- ✅ PostgreSQL database configured
- ✅ Backend API running (systemd service)
- ✅ Frontend deployed to Nginx
- ✅ Application accessible via browser
- ✅ BMI calculator working
- ✅ Data persisting in database
- ✅ All services auto-start on reboot
- ✅ Logs available in CloudWatch
- ✅ Infrastructure as code in Terraform

---

## 💰 Cost Information

**Monthly costs (running 24/7):**
- EC2 t3.medium: ~$30
- EBS 30GB gp3: ~$2.40
- Data transfer: ~$1-2
- **Total: ~$35-40/month**

**Cost saving tips:**
- Stop instance when not in use (saves 70%)
- Use t3.small instead (saves 50%)
- Delete resources after testing (terraform destroy)

---

## 🎓 What You Learned

Through this implementation, you:

✅ Created infrastructure as code with Terraform  
✅ Deployed a 3-tier application on AWS  
✅ Configured VPC, subnets, security groups  
✅ Managed AWS credentials securely with named profiles  
✅ Used S3 remote state with encryption  
✅ Automated server bootstrapping with user-data  
✅ Configured systemd services  
✅ Setup Nginx as reverse proxy  
✅ Deployed a full-stack application  

---

## 📞 Need Help?

**Check logs:**
```bash
sudo tail -f /var/log/bmi-backend.log
sudo tail -f /var/log/nginx/bmi-error.log
```

**Restart services:**
```bash
sudo systemctl restart bmi-backend nginx
```

**Re-run deployment:**
```bash
cd /home/ubuntu/bmi-health-tracker
./IMPLEMENTATION_AUTO.sh
```

---

**🎉 Congratulations! You've successfully deployed a 3-tier application on AWS using Terraform!**

---
## 🧑‍💻 Author
*Md. Sarowar Alam*  
Lead DevOps Engineer, Hogarth Worldwide  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: https://www.linkedin.com/in/sarowar/
---
