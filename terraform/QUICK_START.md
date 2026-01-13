# BMI Health Tracker - Quick Start Guide

## 🚀 Quick Deployment (5 Steps)

### Prerequisites
- AWS CLI configured with a named profile
- Terraform installed
- SSH key pair created in AWS

### Step 1: Create S3 Backend Bucket

```bash
export AWS_PROFILE=your-profile-name
export BUCKET_NAME=your-unique-bucket-name

# Create S3 bucket
aws s3 mb s3://$BUCKET_NAME --region us-east-1

# Enable versioning (recommended)
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled
```

### Step 2: Configure Variables

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars

# Edit these required values:
# - aws_profile
# - key_pair_name
# - db_password
# - allowed_ssh_cidr (your IP for security)
nano terraform.tfvars
```

### Step 3: Deploy Infrastructure

```bash
# Initialize Terraform with your S3 bucket
terraform init \
  -backend-config="bucket=$BUCKET_NAME" \
  -backend-config="key=bmi-health-tracker/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="profile=$AWS_PROFILE"

# Apply configuration
terraform apply
```

### Step 4: Upload Application Code

```bash
# Get instance IP
INSTANCE_IP=$(terraform output -raw instance_public_ip)
KEY_FILE=~/.ssh/your-key-pair.pem

# Upload application files
scp -i $KEY_FILE -r \
  ../backend \
  ../frontend \
  ../database \
  ../IMPLEMENTATION_AUTO.sh \
  ubuntu@$INSTANCE_IP:/home/ubuntu/bmi-health-tracker/
```

### Step 5: Deploy Application

```bash
# SSH into instance
ssh -i $KEY_FILE ubuntu@$INSTANCE_IP

# Run deployment script
cd /home/ubuntu/bmi-health-tracker
chmod +x IMPLEMENTATION_AUTO.sh
./IMPLEMENTATION_AUTO.sh
```

### Step 6: Access Application

Open browser to: `http://<instance-ip>`

---

## 📋 Essential Commands

### View Outputs
```bash
terraform output                      # All outputs
terraform output application_url      # Application URL
terraform output ssh_command          # SSH command
```

### View Logs (on EC2 instance)
```bash
sudo tail -f /var/log/user-data.log       # Bootstrap log
sudo tail -f /var/log/bmi-backend.log     # Backend log
sudo tail -f /var/log/nginx/bmi-error.log # Nginx errors
```

### Manage Services (on EC2 instance)
```bash
sudo systemctl status bmi-backend    # Check backend
sudo systemctl restart bmi-backend   # Restart backend
sudo systemctl status nginx          # Check Nginx
sudo systemctl restart nginx         # Restart Nginx
```

### Update Application Code
```bash
# On your local machine
INSTANCE_IP=$(terraform output -raw instance_public_ip)
rsync -avz -e "ssh -i ~/.ssh/your-key.pem" \
  --exclude 'node_modules' \
  ../backend ubuntu@$INSTANCE_IP:/home/ubuntu/bmi-health-tracker/

# On EC2 instance
cd /home/ubuntu/bmi-health-tracker/backend
npm install
sudo systemctl restart bmi-backend
```

### Destroy Everything
```bash
terraform destroy
```

---

## 🔐 Security Checklist

- [ ] Changed `db_password` in terraform.tfvars
- [ ] Restricted `allowed_ssh_cidr` to your IP only
- [ ] Using a strong SSH key pair
- [ ] S3 bucket has versioning enabled
- [ ] Reviewed security group rules

---

## 📊 Resource Summary

| Resource | Purpose |
|----------|---------|
| VPC | Network isolation |
| 2 Public Subnets | High availability across AZs |
| Internet Gateway | Internet access |
| Security Group | Firewall rules (SSH, HTTP) |
| EC2 t3.medium | Application server |
| IAM Role | CloudWatch and SSM access |
| CloudWatch Logs | Application logging |
| S3 Bucket | Terraform state storage |

---

## 💰 Cost Estimate

| Item | Monthly Cost (USD) |
|------|-------------------|
| EC2 t3.medium | $35 |
| EBS 30GB gp3 | $2.40 |
| S3 State | < $1 |
| Data Transfer | Variable |
| **Total** | **~$40** |

---

## 🆘 Quick Troubleshooting

| Problem | Quick Fix |
|---------|-----------|
| Can't SSH | Check security group allows your IP |
| App not loading | Check `sudo systemctl status nginx bmi-backend` |
| DB connection failed | Check `.env` file and PostgreSQL status |
| Port 80 blocked | Check AWS security group rules |

---

## 📞 Need Help?

1. Check full [README.md](README.md) for detailed documentation
2. View logs: `sudo tail -f /var/log/user-data.log`
3. Check service status: `sudo systemctl status bmi-backend nginx postgresql`
