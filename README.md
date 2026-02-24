# BMI Health Tracker - Production Deployment Guide

> **Complete Infrastructure-as-Code solution for deploying a 3-tier BMI Health Tracker application on AWS using modular Terraform**

## 📖 Table of Contents

- [Project Overview](#-project-overview)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start-30-minutes)
- [Detailed Setup](#-detailed-setup)
- [Development Workflow](#-development-workflow)
- [Deployment Procedures](#-deployment-procedures)
- [Operations & Monitoring](#-operations--monitoring)
- [Troubleshooting](#-troubleshooting)
- [Making Changes](#-making-changes-safely)
- [Cost Management](#-cost-management)
- [Reference Documentation](#-reference-documentation)
- [Author](#-author)

---

## 🎯 Project Overview

### What This Repository Does

This repository contains:
1. **3-Tier Web Application** - BMI Health Tracker with React frontend, Node.js backend, PostgreSQL database
2. **Infrastructure as Code** - Complete AWS infrastructure using modular Terraform
3. **Automated Deployment** - Full automation from infrastructure creation to application deployment
4. **Production Patterns** - Security, monitoring, backup, and operational best practices

### Technology Stack

**Application Layer:**
- **Frontend**: React 18 + Vite 5.0 + Chart.js (SPA)
- **Backend**: Node.js 24 LTS + Express 4.18 (REST API)
- **Database**: PostgreSQL 14
- **Web Server**: Nginx 1.18 (reverse proxy + static hosting)
- **Process Manager**: PM2 for Node.js service management

**Infrastructure Layer:**
- **IaC Tool**: Terraform >= 1.0
- **Cloud Provider**: AWS (ap-south-1 Mumbai region)
- **Compute**: EC2 t3.medium (2 vCPU, 4GB RAM)
- **Storage**: EBS gp3 30GB encrypted
- **Networking**: Custom VPC with public subnets
- **Security**: Security Groups, IAM roles, IMDSv2
- **Observability**: CloudWatch Logs, systemd logging

### Design Decisions

**Why Single EC2 Instance?**
- Development/staging environment optimized for cost
- Simple operational model for learning
- All services on one instance (dev use case)
- Clear upgrade path to HA architecture (see [ARCHITECTURE.md](terraform/ARCHITECTURE.md))

**Why Terraform Modules?**
- Reusability across environments (dev/staging/prod)
- Separation of concerns (network/security/compute)
- Team collaboration with clear boundaries
- Easy to test and validate independently

**Why S3 Backend (No DynamoDB Locking)?**
- Simple state management for single operator
- Reduced cost (no DynamoDB charges)
- S3 versioning provides rollback capability
- Suitable for learning and dev environments

**Why User-Data Bootstrap?**
- Infrastructure and application deployment in one step
- No additional orchestration tools required
- Idempotent and repeatable
- All logs captured in CloudWatch

---

## 🏗️ Architecture

### High-Level Architecture

```
Internet
    │
    ▼
┌─────────────────────────────────────────────┐
│           AWS Cloud (ap-south-1)            │
│  ┌───────────────────────────────────────┐  │
│  │  VPC (10.0.0.0/16)                    │  │
│  │  ┌─────────────────────────────────┐  │  │
│  │  │  Public Subnet (10.0.1.0/24)    │  │  │
│  │  │  ┌───────────────────────────┐  │  │  │
│  │  │  │  EC2 Instance (t3.medium) │  │  │  │
│  │  │  │  ┌──────────────────────┐ │  │  │  │
│  │  │  │  │ Nginx (:80)          │ │  │  │  │
│  │  │  │  │   ├─> React SPA      │ │  │  │  │
│  │  │  │  │   └─> Proxy to 3000  │ │  │  │  │
│  │  │  │  ├──────────────────────┤ │  │  │  │
│  │  │  │  │ Node.js API (:3000)  │ │  │  │  │
│  │  │  │  │   └─> Express + PM2  │ │  │  │  │
│  │  │  │  ├──────────────────────┤ │  │  │  │
│  │  │  │  │ PostgreSQL (:5432)   │ │  │  │  │
│  │  │  │  │   └─> BMI Data       │ │  │  │  │
│  │  │  │  └──────────────────────┘ │  │  │  │
│  │  │  └───────────────────────────┘  │  │  │
│  │  └─────────────────────────────────┘  │  │
│  │                                        │  │
│  │  Internet Gateway                      │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
         │
         ▼
    CloudWatch Logs
    S3 (Terraform State)
```

### Network Flow

1. **HTTP Request** → User browser → `http://INSTANCE_IP`
2. **Nginx** → Receives on port 80 → Routes based on path:
   - `/` → Serves React static files from `/var/www/bmi-health-tracker`
   - `/api/*` → Proxies to `http://localhost:3000`
3. **Backend API** → Express on port 3000 → Processes business logic
4. **Database** → PostgreSQL on localhost:5432 → Stores measurements
5. **Response** → Backend → Nginx → User browser

### Security Model

- **Network Isolation**: Custom VPC with controlled ingress/egress
- **Public Access**: Only ports 22 (SSH) and 80 (HTTP) exposed
- **Database**: Internal only (localhost), not exposed to internet
- **API**: Internal only, accessed via Nginx reverse proxy
- **Encryption**: EBS volumes encrypted, S3 state encrypted
- **IAM**: Least-privilege roles for EC2 (CloudWatch, SSM only)
- **Metadata**: IMDSv2 enforced (prevents SSRF attacks)

### State Management

```
Terraform State → S3 Bucket (versioned, encrypted)
    ├─ Backend: S3 only (no DynamoDB locking)
    ├─ Versioning: Enabled (rollback capability)
    ├─ Encryption: AES-256
    └─ Access: Via AWS named profile (sarowar-ostad)
```

**Read more**: [ARCHITECTURE.md](terraform/ARCHITECTURE.md)

---

## ✅ Prerequisites

### Required Software

| Tool | Version | Purpose | Installation |
|------|---------|---------|--------------|
| **Terraform** | >= 1.0 | Infrastructure provisioning | [terraform.io/downloads](https://www.terraform.io/downloads) |
| **AWS CLI** | >= 2.0 | AWS credential management | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| **Git** | Any recent | Version control | [git-scm.com](https://git-scm.com/) |
| **SSH Client** | OpenSSH | Remote instance access | Built into Windows/Linux/Mac |

### Verify Installations

```powershell
# Check Terraform
terraform version
# Expected: Terraform v1.x.x

# Check AWS CLI
aws --version
# Expected: aws-cli/2.x.x

# Check Git
git --version
# Expected: git version 2.x.x
```

### AWS Account Requirements

**Access Needed:**
- AWS account with admin-level permissions
- Named AWS profile configured (`sarowar-ostad` or similar)
- Access to ap-south-1 (Mumbai) region

**AWS Resources Required:**
- EC2 key pair in ap-south-1
- S3 bucket for Terraform state (globally unique name)
- Available VPC limit (creates 1 VPC)
- Available EIP limit (optional)

**Verify AWS Access:**
```powershell
# Test your AWS profile
aws sts get-caller-identity --profile sarowar-ostad
# Should show your account ID and user ARN

# Check available key pairs in ap-south-1
aws ec2 describe-key-pairs --profile sarowar-ostad --region ap-south-1
```

### Infrastructure Costs

**Estimated Monthly Costs** (running 24/7 in ap-south-1):

| Resource | Specification | Monthly Cost (USD) |
|----------|--------------|-------------------|
| EC2 t3.medium | 2 vCPU, 4GB RAM | ~$30 |
| EBS gp3 Volume | 30GB, encrypted | ~$3 |
| Data Transfer | First 1GB free, then $0.09/GB | ~$2-5 |
| CloudWatch Logs | 5GB ingestion, 7-day retention | ~$0-1 |
| **Total** | | **~$35-40/month** |

**Cost Optimization Tips:**
- Stop instance when not in use (saves 70%)
- Use t3.small for lighter loads (saves 50%)
- Destroy resources after testing (`terraform destroy`)

---

## 🚀 Quick Start (30 Minutes)

**For experienced engineers - minimal steps to deployment:**

```powershell
# 1. Clone repository
git clone https://github.com/md-sarowar-alam/terraform-3-tier.git
cd terraform-3-tier

# 2. Create S3 bucket for state
aws s3 mb s3://YOUR-UNIQUE-BUCKET-NAME --profile sarowar-ostad --region ap-south-1
aws s3api put-bucket-versioning --bucket YOUR-UNIQUE-BUCKET-NAME --versioning-configuration Status=Enabled --profile sarowar-ostad

# 3. Configure Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set key_pair_name, db_password, allowed_ssh_cidr

# 4. Initialize Terraform
terraform init -backend-config="bucket=YOUR-UNIQUE-BUCKET-NAME" -backend-config="key=bmi-health-tracker/terraform.tfstate" -backend-config="region=ap-south-1" -backend-config="profile=sarowar-ostad"

# 5. Deploy infrastructure
terraform plan
terraform apply

# 6. Wait 10-15 minutes for automated deployment
# Application automatically clones from GitHub and deploys

# 7. Access application
terraform output application_url
# Open URL in browser: http://INSTANCE_IP
```

**For detailed instructions, see [Quick Start Guide](#-detailed-setup)**

---

## 📚 Detailed Setup

### Step 1: Clone Repository

```powershell
# Clone from GitHub
git clone https://github.com/md-sarowar-alam/terraform-3-tier.git
cd terraform-3-tier

# Inspect project structure
ls -la
```

**Expected structure:**
```
terraform-3-tier/
├── backend/                    # Node.js Express API
│   ├── src/
│   │   ├── server.js          # Main entry point
│   │   ├── routes.js          # API endpoints
│   │   ├── db.js              # PostgreSQL connection
│   │   ├── calculations.js    # BMI/BMR logic
│   │   └── metrics.js         # Health calculations
│   ├── migrations/            # Database migrations
│   ├── package.json
│   └── ecosystem.config.js    # PM2 configuration
├── frontend/                   # React + Vite SPA
│   ├── src/
│   │   ├── main.jsx           # Entry point
│   │   ├── App.jsx            # Main component
│   │   └── components/        # Form, Chart components
│   ├── index.html
│   ├── package.json
│   └── vite.config.js
├── database/                   # Database setup scripts
│   └── setup-database.sh
├── terraform/                  # Infrastructure as Code
│   ├── main.tf                # Root configuration
│   ├── variables.tf           # Input variables
│   ├── outputs.tf             # Output values
│   ├── provider.tf            # AWS provider
│   ├── backend.tf             # S3 backend config
│   ├── modules/               # Reusable modules
│   │   ├── vpc/              # VPC, subnets, IGW
│   │   ├── security/         # Security groups
│   │   └── ec2/              # EC2, IAM, user-data
│   └── terraform.tfvars       # Your configuration
├── IMPLEMENTATION_AUTO.sh      # Application deployment script
└── README.md                   # This file
```

### Step 2: Prepare AWS Resources

#### 2.1 Create EC2 Key Pair

**Check existing keys:**
```powershell
aws ec2 describe-key-pairs --profile sarowar-ostad --region ap-south-1 --query 'KeyPairs[*].KeyName' --output table
```

**Create new key (if needed):**
```powershell
# Generate key pair
aws ec2 create-key-pair `
  --key-name bmi-health-tracker-mumbai `
  --profile sarowar-ostad `
  --region ap-south-1 `
  --query 'KeyMaterial' `
  --output text | Out-File -Encoding ascii -FilePath $env:USERPROFILE\.ssh\bmi-health-tracker-mumbai.pem

# Verify key was created
Test-Path $env:USERPROFILE\.ssh\bmi-health-tracker-mumbai.pem
# Should return: True

# Important: Save this key name for terraform.tfvars!
```

#### 2.2 Create S3 Bucket for Terraform State

```powershell
# Set a globally unique bucket name
$BUCKET_NAME = "terraform-state-sarowar-bmi-$(Get-Random -Maximum 9999)"
Write-Host "Bucket name: $BUCKET_NAME" -ForegroundColor Green

# Create bucket
aws s3 mb s3://$BUCKET_NAME --profile sarowar-ostad --region ap-south-1

# Enable versioning (critical for state rollback)
aws s3api put-bucket-versioning `
  --bucket $BUCKET_NAME `
  --versioning-configuration Status=Enabled `
  --profile sarowar-ostad

# Enable server-side encryption
aws s3api put-bucket-encryption `
  --bucket $BUCKET_NAME `
  --server-side-encryption-configuration '{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"AES256\"}}]}' `
  --profile sarowar-ostad

# Verify bucket
aws s3 ls s3://$BUCKET_NAME --profile sarowar-ostad

# CRITICAL: Save this bucket name for terraform init!
Write-Host "`nIMPORTANT: Use this bucket name in terraform init:" -ForegroundColor Yellow
Write-Host $BUCKET_NAME -ForegroundColor Cyan
```

#### 2.3 Get Your Public IP for SSH Access

```powershell
# Get your current public IP
$MY_IP = (Invoke-WebRequest -Uri "https://api.ipify.org").Content
Write-Host "Your Public IP: $MY_IP/32" -ForegroundColor Green

# Save this for terraform.tfvars: allowed_ssh_cidr = ["YOUR_IP/32"]
```

### Step 3: Configure Terraform

#### 3.1 Create terraform.tfvars

```powershell
cd terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Open in editor
code terraform.tfvars
```

#### 3.2 Edit Required Variables

**Edit `terraform.tfvars` with your values:**

```hcl
################################################################################
# AWS Configuration
################################################################################
aws_region  = "ap-south-1"
aws_profile = "sarowar-ostad"  # YOUR AWS PROFILE NAME

################################################################################
# EC2 Configuration
################################################################################
key_pair_name = "YOUR-KEY-PAIR-NAME"  # From Step 2.1

################################################################################
# Database Configuration
################################################################################
db_password = "YourStrongPassword123!"  # CHANGE THIS!

################################################################################
# Security Configuration
################################################################################
allowed_ssh_cidr = ["YOUR_IP/32"]  # From Step 2.3
# Example: ["42.123.45.67/32"]

# Leave other values as defaults or customize as needed
```

**Security Note**: Never commit `terraform.tfvars` to git - it's already in `.gitignore`.

### Step 4: Initialize Terraform

```powershell
# Navigate to terraform directory
cd terraform

# Initialize with S3 backend
# REPLACE 'YOUR-BUCKET-NAME' with your bucket from Step 2.2
terraform init `
  -backend-config="bucket=YOUR-BUCKET-NAME" `
  -backend-config="key=bmi-health-tracker/terraform.tfstate" `
  -backend-config="region=ap-south-1" `
  -backend-config="profile=sarowar-ostad"
```

**Expected output:**
```
Initializing modules...
- ec2 in modules/ec2
- security in modules/security
- vpc in modules/vpc

Initializing the backend...
Successfully configured the backend "s3"!

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...

Terraform has been successfully initialized!
```

### Step 5: Validate Configuration

```powershell
# Format code (optional)
terraform fmt -recursive

# Validate syntax
terraform validate
# Expected: Success! The configuration is valid.

# Check what will be created
terraform plan
# Review: Should show ~15 resources to be added
```

### Step 6: Deploy Infrastructure

```powershell
# Deploy all resources
terraform apply

# Review plan, then type: yes

# Deployment takes 5-10 minutes
```

**What gets created:**
1. VPC with 2 public subnets
2. Internet Gateway + route tables
3. Security groups (SSH, HTTP)
4. IAM role + instance profile
5. CloudWatch log group
6. EC2 instance with automated setup

### Step 7: Monitor Bootstrap Process

```powershell
# Get instance IP
$INSTANCE_IP = terraform output -raw instance_public_ip
Write-Host "Instance IP: $INSTANCE_IP" -ForegroundColor Green

# Wait 2-3 minutes, then SSH
ssh -i $env:USERPROFILE\.ssh\YOUR-KEY-NAME.pem ubuntu@$INSTANCE_IP

# On EC2 instance, monitor deployment
sudo tail -f /var/log/user-data.log
```

**Bootstrap process (automatic):**
1. ✅ System updates
2. ✅ Install PostgreSQL 14
3. ✅ Install Node.js 24 LTS via NVM
4. ✅ Install Nginx
5. ✅ Install CloudWatch Agent
6. ✅ Clone application from GitHub
7. ✅ Run IMPLEMENTATION_AUTO.sh:
   - Setup PostgreSQL database and user
   - Install backend dependencies (`npm install`)
   - Run database migrations
   - Build frontend (`npm run build`)
   - Deploy frontend to Nginx
   - Configure Nginx reverse proxy
   - Setup systemd service for backend
   - Start all services

**Total time**: 10-15 minutes for complete deployment

### Step 8: Verify Deployment

**From your local machine:**

```powershell
# Get application URL
terraform output application_url

# Check all outputs
terraform output
```

**SSH into instance and verify services:**

```bash
# Check backend service
sudo systemctl status bmi-backend
# Expected: Active: active (running)

# Check Nginx
sudo systemctl status nginx
# Expected: Active: active (running)

# Check PostgreSQL
sudo systemctl status postgresql
# Expected: Active: active (exited)

# Test API endpoint
curl http://localhost:3000/api/measurements
# Expected: [] or [{"id":1,...}]

# Test frontend
curl http://localhost | head -10
# Expected: HTML content with <!DOCTYPE html>
```

### Step 9: Access Application

1. Open browser
2. Navigate to: `http://YOUR_INSTANCE_IP` (from terraform output)
3. You should see the BMI Health Tracker interface
4. Test the calculator:
   - Enter weight: 70 kg
   - Enter height: 175 cm
   - Select activity level
   - Click "Calculate BMI"
   - Verify results display and save

**✅ Deployment Complete!**

---

## 💻 Development Workflow

### Local Development

**Backend (API):**
```bash
cd backend

# Install dependencies
npm install

# Create .env file
cat > .env <<EOF
DB_HOST=localhost
DB_PORT=5432
DB_NAME=bmidb
DB_USER=bmi_user
DB_PASSWORD=yourpassword
PORT=3000
EOF

# Run development server
npm run dev
# API runs on http://localhost:3000
```

**Frontend (React):**
```bash
cd frontend

# Install dependencies
npm install

# Run development server
npm run dev
# Opens on http://localhost:5173
```

**Database (PostgreSQL):**
```bash
# Install PostgreSQL locally
# On Ubuntu/WSL:
sudo apt install postgresql postgresql-contrib

# Create database
sudo -u postgres createuser -s bmi_user
sudo -u postgres createdb -O bmi_user bmidb

# Run migrations
cd backend
# Migrations in migrations/ folder run automatically by backend
```

### Testing Changes

**Test Backend API:**
```bash
cd backend

# Run linting (if configured)
npm run lint

# Test specific endpoint
curl http://localhost:3000/api/measurements
curl -X POST http://localhost:3000/api/measurements \
  -H "Content-Type: application/json" \
  -d '{"weight":70,"height":175,"age":30,"sex":"male","activityLevel":"moderate"}'
```

**Test Frontend Build:**
```bash
cd frontend

# Production build
npm run build
# Output in dist/

# Preview production build
npm run preview
# Opens on http://localhost:4173
```

### Code Structure

**Backend API Structure:**
```javascript
backend/src/
├── server.js        // Express app setup, middleware, port binding
├── routes.js        // API route definitions (/api/measurements)
├── db.js            // PostgreSQL pool configuration
├── calculations.js  // BMI, BMR calculation logic
└── metrics.js       // Health metrics (Body Fat %, Lean Mass)

Key functions:
- calculateBMI(weight, height)
- calculateBMR(weight, height, age, sex)
- calculateBodyFat(bmi, age, sex)
- calculateDailyCalories(bmr, activityLevel)
```

**Frontend Component Structure:**
```javascript
frontend/src/
├── main.jsx             // React app entry point
├── App.jsx              // Main app component, state management
├── api.js               // Axios HTTP client for backend
└── components/
    ├── MeasurementForm.jsx  // Input form component
    └── TrendChart.jsx       // Chart.js visualization

Key state:
- measurements[] - All saved BMI measurements
- currentResult - Latest calculation result
```

**Terraform Module Structure:**
```hcl
terraform/modules/
├── vpc/
│   ├── main.tf       // VPC, subnets, IGW, route tables
│   ├── variables.tf  // vpc_cidr, subnet_cidrs, tags
│   └── outputs.tf    // vpc_id, subnet_ids, igw_id
├── security/
│   ├── main.tf       // Security groups, rules (SSH, HTTP)
│   ├── variables.tf  // allowed_ssh_cidr, allowed_http_cidr
│   └── outputs.tf    // security_group_id
└── ec2/
    ├── main.tf       // EC2 instance, IAM, CloudWatch, user-data
    ├── user-data.sh  // Bootstrap script template
    ├── variables.tf  // instance_type, ami_id, db credentials
    └── outputs.tf    // instance_id, public_ip, private_ip

Root terraform/:
├── main.tf           // Orchestrates all modules
├── variables.tf      // All input variables (30+)
├── outputs.tf        // All outputs (deployment_summary)
├── provider.tf       // AWS provider configuration
├── backend.tf        // S3 backend configuration
└── terraform.tfvars  // Your specific values (not in git)
```

---

## 🚢 Deployment Procedures

### Standard Deployment

**Full infrastructure + application deployment:**

```powershell
cd terraform

# 1. Plan changes
terraform plan -out=tfplan

# 2. Review plan carefully
# Check: resource counts, CIDR ranges, instance types

# 3. Apply changes
terraform apply tfplan

# 4. Save outputs
terraform output -json > ../deployment-outputs.json

# 5. Verify application
$APP_URL = terraform output -raw application_url
Start-Process $APP_URL  # Opens in browser
```

### Infrastructure-Only Changes

**Modify infrastructure without application redeployment:**

```powershell
# 1. Edit terraform files (e.g., increase instance size)
code terraform/terraform.tfvars
# Change: instance_type = "t3.large"

# 2. Plan changes
terraform plan

# 3. Apply (EC2 will be recreated!)
terraform apply

# Note: When EC2 is recreated, user-data runs again → full redeployment
```

### Application-Only Updates

**Update application without recreating infrastructure:**

**Option A: Manual deployment (recommended for code changes):**
```powershell
# 1. SSH into instance
ssh -i ~/.ssh/YOUR-KEY.pem ubuntu@$INSTANCE_IP

# 2. Pull latest code
cd /home/ubuntu/bmi-health-tracker
git pull origin main

# 3. Redeploy application
export DB_NAME='bmidb' DB_USER='bmi_user' DB_PASSWORD='YOURPASSWORD' AUTO_CONFIRM='yes'
./IMPLEMENTATION_AUTO.sh
```

**Option B: Terraform taint (recreates EC2):**
```powershell
# This destroys and recreates the instance
terraform taint module.ec2.aws_instance.app
terraform apply
# Warning: Downtime ~2-3 minutes
```

### Automated Deployment (CI/CD Ready)

The infrastructure supports automated deployments:

1. **GitHub Actions** (example workflow):
```yaml
name: Deploy Infrastructure
on:
  push:
    branches: [main]
    paths: ['terraform/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::ACCOUNT:role/github-actions
          aws-region: ap-south-1
      
      - name: Terraform Init
        run: terraform init -backend-config=...
        working-directory: terraform
      
      - name: Terraform Apply
        run: terraform apply -auto-approve
        working-directory: terraform
```

2. **Application auto-deploys** when EC2 instance starts (git clone + IMPLEMENTATION_AUTO.sh)

### Blue-Green Deployment Pattern

**For zero-downtime updates:**

1. Deploy new infrastructure with different environment tag
2. Test new instance
3. Update DNS to point to new instance
4. Destroy old infrastructure

```powershell
# Create new environment
cd terraform
# Edit terraform.tfvars: environment = "blue"
terraform workspace new blue
terraform apply

# Test: http://NEW_INSTANCE_IP

# Switch traffic (update DNS/load balancer)

# Destroy old
terraform workspace select default
terraform destroy
```

---

## 📊 Operations & Monitoring

### Health Checks

```powershell
# Quick health check
$INSTANCE_IP = terraform output -raw instance_public_ip

# Test HTTP endpoint
Invoke-WebRequest -Uri "http://${INSTANCE_IP}" -UseBasicParsing | Select-Object StatusCode
# Expected: 200

# Test API endpoint
Invoke-WebRequest -Uri "http://${INSTANCE_IP}/api/measurements" -UseBasicParsing | Select-Object Content
# Expected: JSON array
```

### Log Locations

**On EC2 Instance:**
```bash
# User-data bootstrap log (initial setup)
sudo tail -f /var/log/user-data.log

# Backend application logs
sudo tail -f /var/log/bmi-backend.log

# Nginx access logs
sudo tail -f /var/log/nginx/bmi-access.log

# Nginx error logs
sudo tail -f /var/log/nginx/bmi-error.log

# PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-14-main.log

# System logs
sudo journalctl -u bmi-backend -f
sudo journalctl -u nginx -f
```

**From CloudWatch (local machine):**
```powershell
# View all logs for this instance
$LOG_GROUP = terraform output -raw cloudwatch_log_group
aws logs tail $LOG_GROUP --follow --profile sarowar-ostad

# View specific log stream
aws logs tail $LOG_GROUP --follow --filter-pattern "ERROR" --profile sarowar-ostad

# Get last 100 lines
aws logs tail $LOG_GROUP --since 1h --profile sarowar-ostad
```

### Service Management

**Restart services:**
```bash
# Restart backend API
sudo systemctl restart bmi-backend

# Restart Nginx
sudo systemctl restart nginx

# Restart PostgreSQL
sudo systemctl restart postgresql
```

**Check status:**
```bash
# View service status
sudo systemctl status bmi-backend
sudo systemctl status nginx
sudo systemctl status postgresql

# Check processes
ps aux | grep -E 'node|nginx|postgres'

# Check listening ports
sudo netstat -tlnp | grep -E ':(80|3000|5432)'
```

### Backup Procedures

**Database Backup:**
```bash
# SSH into instance
ssh -i ~/.ssh/YOUR-KEY.pem ubuntu@$INSTANCE_IP

# Create backup
sudo -u postgres pg_dump bmidb > ~/bmi-backup-$(date +%Y%m%d-%H%M%S).sql

# Download backup to local machine
# Exit SSH first, then:
scp -i ~/.ssh/YOUR-KEY.pem ubuntu@$INSTANCE_IP:~/bmi-backup-*.sql ./backups/
```

**Infrastructure State Backup:**
```powershell
# State is automatically versioned in S3
# List state versions
aws s3api list-object-versions --bucket YOUR-BUCKET-NAME --prefix bmi-health-tracker/ --profile sarowar-ostad

# Restore previous state version (if needed)
terraform state pull > backup.tfstate
# Then manually restore from S3 version
```

### Scaling Considerations

**Vertical Scaling (Larger Instance):**
```hcl
# Edit terraform.tfvars
instance_type = "t3.large"  # 2 vCPU → 4 vCPU, 4GB → 8GB
```

**Horizontal Scaling (Future Enhancement):**
- Add Application Load Balancer
- Multiple EC2 instances in Auto Scaling Group
- RDS PostgreSQL (managed database)
- ElastiCache Redis (session storage)
- CloudFront + S3 (frontend hosting)

See [ARCHITECTURE.md](terraform/ARCHITECTURE.md) for HA design patterns.

---

## 🔧 Troubleshooting

### Common Issues

#### Issue 1: Cannot SSH into Instance

**Symptom:** `Connection timed out` or `Connection refused`

**Diagnosis:**
```powershell
# 1. Check instance is running
$INSTANCE_ID = terraform output -raw instance_id
aws ec2 describe-instances --instance-ids $INSTANCE_ID --profile sarowar-ostad --query 'Reservations[0].Instances[0].State.Name'
# Should return: "running"

# 2. Check security group allows your current IP
$MY_IP = (Invoke-WebRequest -Uri "https://api.ipify.org").Content
Write-Host "Current IP: $MY_IP"
# Compare with allowed_ssh_cidr in terraform.tfvars
```

**Solutions:**
```powershell
# A. Your IP changed - update terraform.tfvars
# Edit allowed_ssh_cidr = ["NEW_IP/32"]
terraform apply

# B. Check security group rules
aws ec2 describe-security-groups --group-ids $(terraform output -raw security_group_id) --profile sarowar-ostad
```

#### Issue 2: Application Not Accessible (HTTP)

**Symptom:** Browser shows "Unable to connect" at `http://INSTANCE_IP`

**Diagnosis:**
```bash
# SSH into instance
ssh -i ~/.ssh/YOUR-KEY.pem ubuntu@$INSTANCE_IP

# 1. Check Nginx is running
sudo systemctl status nginx

# 2. Check Nginx configuration
sudo nginx -t

# 3. Check backend is running
sudo systemctl status bmi-backend
curl http://localhost:3000/api/measurements

# 4. Check ports are listening
sudo netstat -tlnp | grep -E ':(80|3000)'
# Expected: 
#   0.0.0.0:80 (nginx)
#   127.0.0.1:3000 (node)
```

**Solutions:**
```bash
# A. Restart services
sudo systemctl restart bmi-backend nginx

# B. Check logs for errors
sudo tail -50 /var/log/bmi-backend.log
sudo tail -50 /var/log/nginx/bmi-error.log

# C. Verify frontend files exist
ls -la /var/www/bmi-health-tracker
# Should contain: index.html, assets/

# D. Re-run deployment
cd /home/ubuntu/bmi-health-tracker
export DB_NAME='bmidb' DB_USER='bmi_user' DB_PASSWORD='YOURPASS' AUTO_CONFIRM='yes'
./IMPLEMENTATION_AUTO.sh
```

#### Issue 3: Database Connection Failed

**Symptom:** Backend logs show `connection refused` or `authentication failed`

**Diagnosis:**
```bash
# 1. Check PostgreSQL is running
sudo systemctl status postgresql

# 2. Verify database exists
sudo -u postgres psql -l | grep bmidb

# 3. Test connection
psql -U bmi_user -d bmidb -h localhost -c "SELECT 1"
# Enter password when prompted

# 4. Check backend .env file
cat /home/ubuntu/bmi-health-tracker/backend/.env
```

**Solutions:**
```bash
# A. Recreate database user/database
sudo -u postgres psql <<EOF
DROP DATABASE IF EXISTS bmidb;
DROP USER IF EXISTS bmi_user;
CREATE USER bmi_user WITH PASSWORD 'YOURPASSWORD';
CREATE DATABASE bmidb OWNER bmi_user;
EOF

# B Run migrations
cd /home/ubuntu/bmi-health-tracker/backend
cat migrations/*.sql | psql -U bmi_user -d bmidb -h localhost

# C. Restart backend
sudo systemctl restart bmi-backend
```

#### Issue 4: Terraform Errors

**Error: `InvalidKeyPair.NotFound`**
```powershell
# Key pair doesn't exist in ap-south-1
aws ec2 describe-key-pairs --profile sarowar-ostad --region ap-south-1
# Update terraform.tfvars with correct key name
```

**Error: `BucketAlreadyExists` or `AccessDenied` (S3)**
```powershell
# Bucket name not unique or no access
aws s3 ls s3://YOUR-BUCKET --profile sarowar-ostad
# Use different bucket name in terraform init
```

**Error: `CredentialsError: Unable to locate credentials`**
```powershell
# AWS profile not configured
aws configure list-profiles
aws configure --profile sarowar-ostad
```

**Error: State locking (if DynamoDB was added)**
```powershell
# Force unlock (use carefully!)
terraform force-unlock LOCK_ID
```

### Getting Support

1. **Check logs** - Most issues show in `/var/log/user-data.log` or service logs
2. **Review documentation** - See [terraform/ARCHITECTURE.md](terraform/ARCHITECTURE.md)
3. **Verify prerequisites** - Ensure all tools installed correctly
4. **Check AWS Console** - EC2, VPC, CloudWatch for resource status
5. **Search issues** - Check GitHub issues for similar problems

---

## 🔒 Making Changes Safely

### Before Making Infrastructure Changes

```powershell
# 1. Create backup of current state
terraform state pull > backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').tfstate

# 2. Create a plan file
terraform plan -out=proposed-changes.tfplan

# 3. Review plan carefully
# Look for: destroy, replace, in-place updates

# 4. Test in separate workspace (optional)
terraform workspace new test
terraform apply
# Test thoroughly
terraform workspace select default
terraform workspace delete test
```

### Safe Change Workflow

1. **Create feature branch:**
   ```powershell
   git checkout -b feature/my-change
   ```

2. **Make changes** in isolated copy

3. **Validate:**
   ```powershell
   terraform fmt -check
   terraform validate
   terraform plan
   ```

4. **Test in separate environment** (different AWS account or workspace)

5. **Review** with team member

6. **Merge** to main branch

7. **Deploy** to production with approval

### Rollback Procedure

**If deployment fails:**

```powershell
# Method 1: Terraform state rollback
# Download previous state version from S3
aws s3api list-object-versions --bucket YOUR-BUCKET --prefix bmi-health-tracker/terraform.tfstate --profile sarowar-ostad

# Download specific version
aws s3api get-object --bucket YOUR-BUCKET --key bmi-health-tracker/terraform.tfstate --version-id VERSION_ID backup.tfstate --profile sarowar-ostad

# Method 2: Destroy and recreate
terraform destroy -target=module.ec2.aws_instance.app
terraform apply

# Method 3: Full destroy
terraform destroy
# Re-run terraform apply
```

### Drift Detection

**Check if infrastructure changed outside Terraform:**

```powershell
# Compare actual state vs desired state
terraform plan -refresh-only

# If drift detected, review and either:
# A. Accept drift: terraform apply -refresh-only
# B. Fix drift: terraform apply (forces back to desired state)
```

---

## 💡 Best Practices

### Security Best Practices

**Implemented:**
- ✅ Encrypted EBS volumes
- ✅ IMDSv2 enforced (prevents SSRF)
- ✅ IAM roles with least privilege
- ✅ Security groups with minimal ingress
- ✅ SSH key-based authentication only
- ✅ Database not exposed to internet
- ✅ S3 state encryption

**Recommended Improvements for Production:**
- 🔒 Enable VPC Flow Logs
- 🔒 Restrict SSH to bastion host or VPN
- 🔒 Use AWS Secrets Manager for DB password
- 🔒 Enable AWS GuardDuty
- 🔒 Add WAF for public endpoints
- 🔒 Implement backup automation
- 🔒 Use RDS instead of PostgreSQL on EC2
- 🔒 Enable MFA for AWS account

### Terraform Best Practices

**Implemented:**
- ✅ Modular structure (reusable components)
- ✅ DRY principle (no code duplication)
- ✅ Remote state in S3
- ✅ State versioning enabled
- ✅ Named AWS profiles (no hardcoded credentials)
- ✅ Variable validation
- ✅ Comprehensive outputs
- ✅ Tagged resources for cost allocation

**Recommended:**
- 📝 Use Terraform workspaces for multiple environments
- 📝 Implement pre-commit hooks (`terraform fmt`, `tflint`)
- 📝 Add `terraform-docs` for automatic documentation
- 📝 Use `checkov` or `tfsec` for security scanning
- 📝 Implement remote backend locking with DynamoDB (multi-user)

### Application Best Practices

**Implemented:**
- ✅ Environment-based configuration (.env)
- ✅ Database migrations
- ✅ Graceful error handling
- ✅ Process management (PM2)
- ✅ Reverse proxy (Nginx)
- ✅ Production build optimization (Vite)
- ✅ Systemd integration (auto-restart)

**Recommended for Production:**
- 📝 Add comprehensive test suite (Jest, React Testing Library)
- 📝 Implement health check endpoints (`/health`, `/ready`)
- 📝 Add API rate limiting
- 📝 Implement CORS properly
- 📝 Add authentication/authorization (JWT)
- 📝 Use connection pooling for PostgreSQL
- 📝 Add Redis for caching
- 📝 Implement structured logging (Winston/Pino)

---

## 🧪 Testing

### Infrastructure Tests

```powershell
# Validate Terraform syntax
terraform validate

# Format check
terraform fmt -check -recursive

# Static analysis (requires tflint)
tflint --recursive

# Security scanning (requires checkov)
checkov -d terraform/

# Plan without applying
terraform plan -out=test.tfplan
```

### Application Tests

**Backend tests:**
```bash
cd backend

# Unit tests (add Jest)
npm test

# Integration tests (add Supertest)
npm run test:integration

# Manual API tests
curl -X POST http://localhost:3000/api/measurements \
  -H "Content-Type: application/json" \
  -d @test-data.json
```

**Frontend tests:**
```bash
cd frontend

# Unit tests
npm test

# E2E tests (add Playwright/Cypress)
npm run test:e2e

# Build test
npm run build
```

### Load Testing

```bash
# Install Apache Bench
sudo apt install apache2-utils

# Test API endpoint
ab -n 1000 -c 10 http://INSTANCE_IP/api/measurements

# Test static content
ab -n 1000 -c 10 http://INSTANCE_IP/
```

---

## 🗂️ Repository Structure

```
terraform-3-tier/
│
├── 📱 Application Code
│   ├── backend/                      # Node.js Express API
│   │   ├── src/                     # Source code
│   │   │   ├── server.js           # Main entry point (Express app)
│   │   │   ├── routes.js           # API routes (/api/measurements)
│   │   │   ├── db.js               # PostgreSQL connection pool
│   │   │   ├── calculations.js     # BMI/BMR formulas
│   │   │   └── metrics.js          # Body composition calculations
│   │   ├── migrations/              # Database migrations
│   │   │   ├── 001_create_measurements.sql
│   │   │   └── 002_add_measurement_date.sql
│   │   ├── package.json            # Dependencies: express, pg, cors, dotenv
│   │   └── ecosystem.config.js     # PM2 process configuration
│   │
│   ├── frontend/                    # React + Vite SPA
│   │   ├── src/
│   │   │   ├── main.jsx            # React app entry
│   │   │   ├── App.jsx             # Main component (state management)
│   │   │   ├── api.js              # Axios HTTP client
│   │   │   ├── index.css           # Global styles
│   │   │   └── components/
│   │   │       ├── MeasurementForm.jsx  # Input form
│   │   │       └── TrendChart.jsx       # Chart.js visualization
│   │   ├── index.html              # HTML template
│   │   ├── package.json            # Dependencies: react, axios, chart.js
│   │   └── vite.config.js          # Vite configuration (port 5173)
│   │
│   ├── database/                    # Database setup scripts
│   │   └── setup-database.sh       # PostgreSQL initialization
│   │
│   └── IMPLEMENTATION_AUTO.sh       # Application deployment automation
│       └── Functions: DB setup, npm install, build, deploy, systemd
│
├── 🌍 Infrastructure as Code (Terraform)
│   └── terraform/
│       ├── main.tf                 # Root module - orchestrates all modules
│       ├── variables.tf            # Input variables (30+ configurable params)
│       ├── outputs.tf              # Output values (IPs, URLs, connection info)
│       ├── provider.tf             # AWS provider configuration
│       ├── backend.tf              # S3 backend for remote state
│       ├── terraform.tfvars        # YOUR configuration (not in git)
│       ├── terraform.tfvars.example # Template for configuration
│       ├── deploy.sh               # Helper script for deployment
│       │
│       └── modules/                # Reusable Terraform modules
│           ├── vpc/                # Networking module
│           │   ├── main.tf        # VPC, subnets, IGW, route tables
│           │   ├── variables.tf   # VPC CIDR, subnet CIDRs
│           │   └── outputs.tf     # vpc_id, subnet_ids
│           │
│           ├── security/           # Security module
│           │   ├── main.tf        # Security groups, ingress/egress rules
│           │   ├── variables.tf   # Allowed CIDRs for SSH/HTTP
│           │   └── outputs.tf     # security_group_id
│           │
│           └── ec2/                # Compute module
│               ├── main.tf        # EC2, IAM role, CloudWatch
│               ├── user-data.sh   # Bootstrap script template
│               ├── variables.tf   # Instance type, AMI, DB config
│               └── outputs.tf     # instance_id, IPs, SSH command
│
└── 📚 Documentation
    ├── README.md                   # This file (onboarding guide)
    ├── IMPLEMENTATION_GUIDE.md     # Detailed step-by-step deployment
    └── terraform/
        ├── ARCHITECTURE.md         # Architecture deep-dive
        ├── QUICK_START.md          # Fast-track deployment
        ├── PROJECT_SUMMARY.md      # High-level project overview
        ├── INDEX.md                # Documentation index
        ├── COMPLETE_STRUCTURE.md   # Full code breakdown
        └── FIXES_APPLIED.md        # Historical fixes and solutions
```

### Key Files Explained

**Application Files:**

| File | Purpose | Key Details |
|------|---------|-------------|
| `backend/src/server.js` | Express server entry point | Port 3000, CORS enabled, routes mounted at `/api` |
| `backend/src/routes.js` | API route handlers | `POST /api/measurements` (create), `GET /api/measurements` (list) |
| `backend/src/calculations.js` | BMI/BMR formulas | WHO standards, Mifflin-St Jeor equation |
| `frontend/src/App.jsx` | React main component | State management, API calls via axios |
| `frontend/src/components/MeasurementForm.jsx` | Input form | Controlled inputs, validation |
| `IMPLEMENTATION_AUTO.sh` | Application deployer | Non-interactive mode via env vars |

**Terraform Files:**

| File | Purpose | Key Details |
|------|---------|-------------|
| `terraform/main.tf` | Root orchestration | Calls all modules, defines data sources |
| `terraform/variables.tf` | Variable definitions | 30+ variables with defaults, validation |
| `terraform/outputs.tf` | Export values | IPs, URLs, SSH commands, deployment summary |
| `terraform/backend.tf` | State configuration | S3 backend, configured via CLI args |
| `terraform/provider.tf` | AWS provider | Region, profile, default tags |
| `terraform/modules/vpc/main.tf` | Network infrastructure | VPC, 2 subnets, IGW, routes |
| `terraform/modules/security/main.tf` | Firewall rules | SSH (22), HTTP (80), egress (all) |
| `terraform/modules/ec2/main.tf` | Compute resources | EC2, IAM, CloudWatch, user-data |
| `terraform/modules/ec2/user-data.sh` | Bootstrap script | System setup + app deployment |

---

## 🔐 Security Considerations

### Secrets Management

**Current Implementation:**
- Database password stored in `terraform.tfvars` (gitignored)
- Passed to EC2 via user-data (base64 encoded by Terraform)
- Written to `.env` file on instance

**Production Recommendations:**
```hcl
# Use AWS Secrets Manager
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "bmi-health-tracker/db-password"
}

# Or use Parameter Store
data "aws_ssm_parameter" "db_password" {
  name = "/bmi-health-tracker/db-password"
}
```

### Network Security

**Current Setup:**
- SSH: Restricted by `allowed_ssh_cidr` variable
- HTTP: Open to `0.0.0.0/0` (required for public web app)
- PostgreSQL: Localhost only (not in security group)
- Backend API: Localhost only (accessed via Nginx proxy)

**Production Hardening:**
- Use Application Load Balancer with SSL/TLS
- Add AWS Certificate Manager for HTTPS
- Implement AWS WAF rules
- Use VPN or SSM Session Manager instead of SSH
- Add DDoS protection (AWS Shield)

### Compliance

**Data Privacy:**
- No personally identifiable information (PII) stored beyond email (if added)
- BMI measurements are health data - consider HIPAA/GDPR if storing personal info
- Implement data retention policies
- Add user consent and privacy policy

**Audit Trail:**
- CloudWatch logs capture all API requests
- Terraform state changes tracked in S3 versions
- Enable AWS CloudTrail for API auditing

---

## 📦 Disaster Recovery

### Backup Strategy

**What to backup:**
1. **Database** - PostgreSQL dumps (daily recommended)
2. **Terraform State** - S3 versioning (automatic)
3. **Application Config** - `.env` files, Nginx configs

**Automated backup script:**
```bash
#!/bin/bash
# Save as: /home/ubuntu/backup-daily.sh

DATE=$(date +%Y%m%d)
BACKUP_DIR="/home/ubuntu/backups"
mkdir -p $BACKUP_DIR

# Database backup
sudo -u postgres pg_dump bmidb > $BACKUP_DIR/bmidb-$DATE.sql

# Config backup
tar -czf $BACKUP_DIR/configs-$DATE.tar.gz \
  /home/ubuntu/bmi-health-tracker/backend/.env \
  /etc/nginx/sites-available/bmi-health-tracker \
  /etc/systemd/system/bmi-backend.service

# Upload to S3 (optional)
aws s3 cp $BACKUP_DIR/ s3://YOUR-BACKUP-BUCKET/backups/ --recursive --profile sarowar-ostad

# Cleanup old backups (keep 30 days)
find $BACKUP_DIR -type f -mtime +30 -delete
```

**Schedule with cron:**
```bash
# Add to crontab
crontab -e
# Add line:
0 2 * * * /home/ubuntu/backup-daily.sh
```

### Recovery Procedure

**Scenario: Complete infrastructure loss**

```powershell
# 1. Clone repository
git clone https://github.com/md-sarowar-alam/terraform-3-tier.git
cd terraform-3-tier/terraform

# 2. Configure terraform.tfvars (same values as before)

# 3. Initialize with SAME state bucket
terraform init -backend-config=...

# 4. Restore infrastructure
terraform apply
# Terraform recreates infrastructure from state

# 5. Restore database (if needed)
# SSH into new instance
scp -i ~/.ssh/KEY.pem backup.sql ubuntu@NEW_IP:/tmp/
ssh -i ~/.ssh/KEY.pem ubuntu@NEW_IP
psql -U bmi_user -d bmidb -h localhost < /tmp/backup.sql
```

---

## 🛠️ Advanced Operations

### Multi-Environment Setup

**Create separate environments (dev, staging, prod):**

```powershell
# Method 1: Terraform Workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

terraform workspace select dev
terraform apply  # Deploys to dev

terraform workspace select prod
terraform apply  # Deploys to prod

# Method 2: Separate directories
terraform-3-tier/
├── environments/
│   ├── dev/
│   │   └── terraform.tfvars
│   ├── staging/
│   │   └── terraform.tfvars
│   └── prod/
│       └── terraform.tfvars
```

### Infrastructure Automation

**Automated deployment script:**

```powershell
# Save as: deploy-infrastructure.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev"
)

Set-Location terraform

# Initialize
terraform init `
  -backend-config="bucket=$BucketName" `
  -backend-config="key=bmi-health-tracker/$Environment/terraform.tfstate" `
  -backend-config="region=ap-south-1" `
  -backend-config="profile=sarowar-ostad"

# Validate
terraform validate
if ($LASTEXITCODE -ne 0) { exit 1 }

# Plan
terraform plan -out=tfplan
if ($LASTEXITCODE -ne 0) { exit 1 }

# Apply (with approval)
Read-Host "Apply changes? (Press Enter to continue, Ctrl+C to cancel)"
terraform apply tfplan

# Output results
terraform output -json | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Out-File "../deployment-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

Write-Host "`n✅ Deployment complete!" -ForegroundColor Green
terraform output
```

### Monitoring Setup

**CloudWatch Dashboard (manual):**

1. Go to AWS CloudWatch Console
2. Create Dashboard: "BMI-Health-Tracker"
3. Add widgets:
   - EC2 CPU Utilization
   - EC2 Network In/Out
   - Log Insights queries for errors
   - Custom metric: API response times

**CloudWatch Alarms:**

```hcl
# Add to terraform/main.tf or modules/ec2/main.tf
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors EC2 CPU utilization"
  
  dimensions = {
    InstanceId = aws_instance.app.id
  }
}
```

---

## 📖 Reference Documentation

### Essential Reading

1. **[IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)**
   - Complete 17-step deployment walkthrough
   - PowerShell commands for Windows
   - Troubleshooting for each step
   - Perfect for first-time deployers

2. **[terraform/ARCHITECTURE.md](terraform/ARCHITECTURE.md)**
   - Deep-dive into architecture decisions
   - Component interaction diagrams
   - Scaling considerations
   - Security model explanation

3. **[terraform/QUICK_START.md](terraform/QUICK_START.md)**
   - Fast-track guide (5 minutes)
   - Minimum commands to deploy
   - For experienced Terraform users

4. **[terraform/PROJECT_SUMMARY.md](terraform/PROJECT_SUMMARY.md)**
   - High-level project overview
   - What was created and why
   - Key features and capabilities

### Configuration Reference

**terraform.tfvars Variables:**

| Variable | Type | Default | Required | Description |
|----------|------|---------|----------|-------------|
| `aws_region` | string | ap-south-1 | Yes | AWS region for deployment |
| `aws_profile` | string | - | Yes | AWS CLI profile name |
| `project_name` | string | bmi-health-tracker | No | Project identifier |
| `environment` | string | dev | No | Environment name (dev/staging/prod) |
| `vpc_cidr` | string | 10.0.0.0/16 | No | VPC CIDR block |
| `public_subnet_cidrs` | list(string) | See default | No | Public subnet CIDRs |
| `instance_type` | string | t3.medium | No | EC2 instance type |
| `key_pair_name` | string | - | **YES** | EC2 key pair name |
| `db_name` | string | bmidb | No | PostgreSQL database name |
| `db_user` | string | bmi_user | No | PostgreSQL username |
| `db_password` | string | - | **YES** | PostgreSQL password |
| `allowed_ssh_cidr` | list(string) | - | **YES** | CIDR blocks for SSH access |
| `allowed_http_cidr` | list(string) | ["0.0.0.0/0"] | No | CIDR blocks for HTTP access |
| `enable_auto_deployment` | bool | true | No | Auto-deploy app on boot |

**See [terraform/variables.tf](terraform/variables.tf) for complete list with descriptions**

### Terraform Outputs

After deployment, access these outputs:

```powershell
# All outputs
terraform output

# Specific output
terraform output instance_public_ip
terraform output application_url
terraform output ssh_command

# JSON format (for scripting)
terraform output -json > outputs.json
```

**Available outputs:**
- `application_url` - Full HTTP URL to access app
- `instance_public_ip` - EC2 public IP
- `instance_id` - EC2 instance ID
- `ssh_command` - Ready-to-use SSH command
- `deployment_summary` - Complete deployment info object
- `cloudwatch_log_group` - CloudWatch log group name
- `vpc_id`, `security_group_id` - Infrastructure IDs

---

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/deploy.yml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'
      - '.github/workflows/deploy.yml'
  workflow_dispatch:

env:
  AWS_REGION: ap-south-1
  TF_VERSION: 1.6.0

jobs:
  terraform:
    name: Terraform Apply
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ${{ env.TF_VERSION }}
      
      - name: Terraform Init
        working-directory: terraform
        run: |
          terraform init \
            -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}" \
            -backend-config="key=bmi-health-tracker/terraform.tfstate" \
            -backend-config="region=${{ env.AWS_REGION }}"
      
      - name: Terraform Validate
        working-directory: terraform
        run: terraform validate
      
      - name: Terraform Plan
        working-directory: terraform
        run: terraform plan -out=tfplan
      
      - name: Terraform Apply
        working-directory: terraform
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve tfplan
```

**Required GitHub Secrets:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `TF_STATE_BUCKET`

---

## 🧹 Cleanup & Resource Deletion

### Destroy All Resources

```powershell
cd terraform

# Preview what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy
# Type: yes

# Takes 5-10 minutes
```

**Resources destroyed:**
- ✅ EC2 instance
- ✅ Security groups
- ✅ Subnets
- ✅ Internet Gateway
- ✅ VPC
- ✅ IAM role/profile
- ✅ CloudWatch log group

**NOT destroyed automatically:**
- ❌ S3 bucket (contains state)
- ❌ CloudWatch logs (retention policy)
- ❌ EC2 key pair

**Manual cleanup:**
```powershell
# Delete S3 bucket contents
aws s3 rm s3://YOUR-BUCKET-NAME --recursive --profile sarowar-ostad

# Delete S3 bucket
aws s3 rb s3://YOUR-BUCKET-NAME --profile sarowar-ostad

# Delete key pair (if no longer needed)
aws ec2 delete-key-pair --key-name YOUR-KEY-NAME --profile sarowar-ostad --region ap-south-1
```

---

## 🎓 Learning Resources

### Understanding the Code

**For Terraform beginners:**
- Start with [terraform/QUICK_START.md](terraform/QUICK_START.md)
- Read through module code in order: `vpc/` → `security/` → `ec2/`
- Official docs: [terraform.io/docs](https://www.terraform.io/docs)

**For application developers:**
- Backend API: Review `backend/src/routes.js` for endpoints
- Frontend: Start with `frontend/src/App.jsx` for state flow
- Database: Check `backend/migrations/` for schema

### Architecture Patterns

**Implemented Patterns:**
1. **Three-Tier Architecture** - Separation of presentation/business/data layers
2. **Infrastructure as Code** - Version-controlled infrastructure
3. **Modular Design** - Reusable Terraform modules
4. **Reverse Proxy Pattern** - Nginx fronting backend API
5. **Process Management** - SystemD + PM2 for reliability
6. **Immutable Infrastructure** - Replace, don't modify (via user-data.sh)
7. **Configuration Management** - Environment variables for config

**Next Steps to Learn:**
- High Availability (HA) architecture
- Auto Scaling Groups
- Load Balancers
- Multi-AZ RDS
- CloudFront CDN
- Container orchestration (ECS/EKS)

---

## 🤝 Contributing

### Making Changes to Infrastructure

1. **Fork/branch:**
   ```powershell
   git checkout -b feature/my-infrastructure-change
   ```

2. **Make changes** to Terraform code

3. **Validate:**
   ```powershell
   terraform fmt -recursive
   terraform validate
   terraform plan
   ```

4. **Test** in separate AWS account or workspace

5. **Document** changes in commit message:
   ```powershell
   git add terraform/
   git commit -m "feat(terraform): add CloudWatch alarms for CPU monitoring"
   git push origin feature/my-infrastructure-change
   ```

6. **Create Pull Request** with:
   - Description of changes
   - `terraform plan` output
   - Testing evidence
   - Impact analysis

### Making Changes to Application

1. **Branch:**
   ```powershell
   git checkout -b feature/my-app-change
   ```

2. **Develop locally** (see Development Workflow)

3. **Test changes** thoroughly

4. **Commit:**
   ```powershell
   git add backend/ frontend/
   git commit -m "feat(backend): add user authentication endpoint"
   git push
   ```

5. **Deploy:**
   - Push to GitHub → triggers auto-deployment on next EC2 boot
   - Or manually: SSH into instance → `git pull` → restart services

### Code Review Checklist

**For infrastructure changes:**
- [ ] `terraform fmt` applied
- [ ] `terraform validate` passes
- [ ] No hardcoded secrets
- [ ] Outputs documented
- [ ] Backward compatible with existing deployments
- [ ] Cost impact assessed
- [ ] State migration plan (if needed)

**For application changes:**
- [ ] Code follows existing patterns
- [ ] No breaking API changes (or versioned)
- [ ] Database migrations provided (if schema changes)
- [ ] Environment variables documented
- [ ] Tested locally before deployment
- [ ] Logs added for debugging

---

## 📞 Support & Contact

### Getting Help

1. **Documentation**
   - Review this README
   - Check [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)
   - Read module-specific docs in `terraform/modules/*/README.md`

2. **Logs & Diagnostics**
   ```bash
   # Application logs
   sudo tail -100 /var/log/user-data.log
   sudo tail -100 /var/log/bmi-backend.log
   
   # Service status
   sudo systemctl status bmi-backend nginx postgresql
   
   # System diagnostics
   df -h  # Disk space
   free -h  # Memory usage
   top  # Process monitoring
   ```

3. **Common Commands Quick Reference**
   ```bash
   # Restart all services
   sudo systemctl restart bmi-backend nginx
   
   # Check backend process
   pm2 list
   pm2 logs bmi-backend
   
   # Database access
   psql -U bmi_user -d bmidb -h localhost
   
   # Redeploy application
   cd /home/ubuntu/bmi-health-tracker
   git pull
   export DB_NAME='bmidb' DB_USER='bmi_user' DB_PASSWORD='XXX' AUTO_CONFIRM='yes'
   ./IMPLEMENTATION_AUTO.sh
   ```

### Useful Links

- **Repository**: https://github.com/md-sarowar-alam/terraform-3-tier
- **Terraform Docs**: https://www.terraform.io/docs
- **AWS EC2 Docs**: https://docs.aws.amazon.com/ec2
- **Node.js Docs**: https://nodejs.org/docs
- **React Docs**: https://react.dev
- **PostgreSQL Docs**: https://www.postgresql.org/docs

---

## 🎯 Project Status & Roadmap

### Current Status

✅ **Production-Ready for Single-Instance Deployment**

- All core features implemented
- Automated deployment working
- Documentation complete
- Security best practices applied
- Monitoring configured

### Known Limitations

- Single point of failure (one EC2 instance)
- No auto-scaling
- No load balancing
- Database on same instance (not managed service)
- HTTP only (no HTTPS/SSL)
- No CDN for static assets
- Manual backup required

### Roadmap

**Phase 1: High Availability** (Next)
- [ ] Add Application Load Balancer
- [ ] Implement Auto Scaling Group
- [ ] Migrate to RDS PostgreSQL
- [ ] Multi-AZ deployment
- [ ] Add health checks

**Phase 2: Security Enhancements**
- [ ] Implement SSL/TLS (HTTPS)
- [ ] Add AWS Certificate Manager
- [ ] Implement AWS WAF
- [ ] Use AWS Secrets Manager
- [ ] Add authentication (Cognito/JWT)

**Phase 3: Performance**
- [ ] Add Redis caching layer
- [ ] Implement CloudFront CDN
- [ ] Optimize database indexes
- [ ] Add API rate limiting
- [ ] Implement connection pooling

**Phase 4: Observability**
- [ ] Add AWS X-Ray tracing
- [ ] Implement custom CloudWatch metrics
- [ ] Add Prometheus + Grafana
- [ ] Implement alerting (SNS/PagerDuty)
- [ ] Add APM monitoring

---

## 📋 Deployment Checklist

### Pre-Deployment

- [ ] Terraform installed and verified
- [ ] AWS CLI configured with profile
- [ ] EC2 key pair created in ap-south-1
- [ ] S3 bucket created for state
- [ ] terraform.tfvars configured with all required values
- [ ] Public IP obtained for SSH restriction
- [ ] Strong database password chosen

### Deployment

- [ ] `terraform init` completed successfully
- [ ] `terraform validate` passed
- [ ] `terraform plan` reviewed (no unexpected changes)
- [ ] `terraform apply` completed (~15 resources created)
- [ ] Outputs saved (`terraform output`)
- [ ] Instance bootstrap monitored (user-data.log)
- [ ] Application cloned from GitHub
- [ ] IMPLEMENTATION_AUTO.sh executed successfully

### Post-Deployment Verification

- [ ] Can SSH into instance
- [ ] Nginx is running (`systemctl status nginx`)
- [ ] Backend is running (`systemctl status bmi-backend`)
- [ ] PostgreSQL is running (`systemctl status postgresql`)
- [ ] Can access application in browser (http://INSTANCE_IP)
- [ ] Can submit BMI calculation successfully
- [ ] Data persists in database (refresh page, data still there)
- [ ] CloudWatch logs receiving data
- [ ] No errors in application logs

### Production Readiness (Additional)

- [ ] SSH restricted to specific IPs (not 0.0.0.0/0)
- [ ] Database password is strong (16+ chars, mixed case, symbols)
- [ ] Backup strategy implemented
- [ ] Monitoring dashboard created
- [ ] CloudWatch alarms configured
- [ ] Disaster recovery procedure documented
- [ ] Team members have access to AWS/repository
- [ ] Cost alerts configured
- [ ] Security scan completed (checkov/tfsec)

---

## 🏆 Success Criteria

**Deployment is successful when:**

1. ✅ Infrastructure deploys without errors (`terraform apply`)
2. ✅ EC2 instance is running and accessible via SSH
3. ✅ All services start automatically:
   - PostgreSQL database created and configured
   - Backend API running on port 3000 (via PM2)
   - Nginx serving on port 80
4. ✅ Application accessible in browser at `http://INSTANCE_IP`
5. ✅ BMI calculator functions correctly:
   - Can input measurements
   - BMI calculates accurately
   - Results display properly
   - Data saves to database
   - Trend chart updates
6. ✅ Logs flowing to CloudWatch
7. ✅ All services survive reboot (systemd enabled)

---

## 🆘 Emergency Procedures

### Instance Unresponsive

```powershell
# 1. Check instance status
aws ec2 describe-instance-status --instance-ids $(terraform output -raw instance_id) --profile sarowar-ostad

# 2. Check system logs
aws ec2 get-console-output --instance-id $(terraform output -raw instance_id) --profile sarowar-ostad

# 3. Reboot instance
aws ec2 reboot-instances --instance-ids $(terraform output -raw instance_id) --profile sarowar-ostad

# 4. If still failing, recreate
terraform taint module.ec2.aws_instance.app
terraform apply
```

### Database Corruption

```bash
# 1. SSH into instance
# 2. Stop backend
sudo systemctl stop bmi-backend

# 3. Backup current database
sudo -u postgres pg_dump bmidb > /tmp/bmidb-corrupt.sql

# 4. Restore from last good backup
psql -U bmi_user -d bmidb -h localhost < /path/to/backup.sql

# 5. Start backend
sudo systemctl start bmi-backend
```

### State File Issues

```powershell
# If state file corrupted or locked

# 1. Download current state
terraform state pull > emergency-backup.tfstate

# 2. Force unlock (if locked)
terraform force-unlock LOCK_ID

# 3. If state lost, import resources
terraform import module.vpc.aws_vpc.main vpc-XXXXX
terraform import module.ec2.aws_instance.app i-XXXXX
# Continue for all resources

# 4. Last resort: destroy and recreate from code
terraform destroy
terraform apply
```

---

## 📈 Metrics & KPIs

### Application Metrics

Monitor these in CloudWatch or application logs:

- **API Response Time** - Target: <200ms avg
- **Error Rate** - Target: <1%
- **Request Rate** - Baseline: 10-100 req/min
- **Database Query Time** - Target: <50ms
- **Frontend Load Time** - Target: <2s

### Infrastructure Metrics

Monitor in AWS CloudWatch:

- **CPU Utilization** - Alert if >80% for 10 min
- **Memory Utilization** - Alert if >85%
- **Disk Usage** - Alert if >80% full
- **Network Traffic** - Monitor for anomalies
- **Status Checks** - System + instance checks

### Cost Metrics

Track in AWS Cost Explorer:

- Daily cost trends
- Service-level costs (EC2, EBS, data transfer)
- Compare to budget ($40/month baseline)
- Optimize based on usage patterns

---

## 🔍 FAQ

### General Questions

**Q: Can I deploy this in a different AWS region?**
A: Yes, change `aws_region` in terraform.tfvars and ensure you have a key pair in that region.

**Q: Can I use this for production?**
A: The current setup is dev/staging optimized. For production, implement HA architecture (ALB, ASG, RDS, multi-AZ).

**Q: How do I add HTTPS?**
A: Add AWS Certificate Manager certificate, configure ALB with HTTPS listener, update Nginx config.

**Q: Can multiple people work on this simultaneously?**
A: Add DynamoDB table for state locking in backend.tf for concurrent operations.

### Technical Questions

**Q: Why is the backend on port 3000 not exposed?**
A: Security - Nginx reverse proxy provides a single ingress point, SSL termination (future), and protects backend from direct access.

**Q: Can I use a different database?**
A: Yes, modify backend/src/db.js for MySQL/MongoDB. Update terraform/modules/ec2/user-data.sh to install different DB.

**Q: How do I add more EC2 instances?**
A: Change modules/ec2/main.tf to use count or for_each. Add ALB to distribute traffic. Consider using Auto Scaling Groups.

**Q: Why PM2 instead of systemd directly?**
A: PM2 provides process monitoring, auto-restart, log management, and cluster mode (for future scaling).

---

## 📝 Changelog

### Version 1.0.0 (Current)

**Added:**
- Complete modular Terraform infrastructure
- Automated application deployment via user-data
- Non-interactive deployment mode
- CloudWatch logging integration
- Comprehensive documentation

**Fixed:**
- Backend configuration (removed DynamoDB requirement)
- AWS profile handling (named profile support)
- Cloud-init circular dependency in user-data
- Region standardization (ap-south-1)
- Environment variable preservation in IMPLEMENTATION_AUTO.sh

---
## 🧑‍💻 Author
*Md. Sarowar Alam*  
Lead DevOps Engineer, Hogarth Worldwide  
📧 Email: sarowar@hotmail.com  
🔗 LinkedIn: https://www.linkedin.com/in/sarowar/
---
