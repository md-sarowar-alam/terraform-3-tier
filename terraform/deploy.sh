#!/bin/bash
################################################################################
# BMI Health Tracker - Terraform Deployment Helper Script
#
# This script helps automate the Terraform deployment process
# Usage: ./deploy.sh [init|plan|apply|destroy|output]
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if terraform.tfvars exists
check_tfvars() {
    if [ ! -f terraform.tfvars ]; then
        print_error "terraform.tfvars not found!"
        print_info "Copying terraform.tfvars.example to terraform.tfvars..."
        cp terraform.tfvars.example terraform.tfvars
        print_warning "Please edit terraform.tfvars with your values before proceeding"
        print_info "Required values:"
        echo "  - aws_profile"
        echo "  - s3_bucket_name"
        echo "  - key_pair_name"
        echo "  - db_password"
        echo "  - allowed_ssh_cidr"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform not found. Please install Terraform first."
        exit 1
    fi
    print_success "Terraform $(terraform version -json | jq -r .terraform_version) found"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install AWS CLI first."
        exit 1
    fi
    print_success "AWS CLI found"
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_warning "jq not found. Install jq for better output formatting (optional)"
    fi
}

# Extract values from terraform.tfvars
get_tfvar() {
    local key=$1
    grep "^$key" terraform.tfvars 2>/dev/null | sed 's/.*=\s*"\(.*\)".*/\1/' | tr -d ' '
}

# Initialize Terraform
terraform_init() {
    print_header "Initializing Terraform"
    
    check_tfvars
    
    # Get backend configuration from terraform.tfvars or prompt user
    REGION=$(get_tfvar "aws_region")
    PROFILE=$(get_tfvar "aws_profile")
    
    # Prompt for S3 bucket name
    echo ""
    print_info "Backend Configuration Required"
    echo "You need an S3 bucket for Terraform state storage."
    echo ""
    read -p "Enter S3 bucket name (must be globally unique): " BUCKET
    
    if [ -z "$BUCKET" ]; then
        print_error "S3 bucket name cannot be empty"
        exit 1
    fi
    
    print_info "Backend Configuration:"
    echo "  Bucket: $BUCKET"
    echo "  Region: ${REGION:-us-east-1}"
    echo "  Profile: ${PROFILE:-default}"
    echo ""
    
    # Check if bucket exists
    if aws s3 ls "s3://$BUCKET" --profile "${PROFILE:-default}" &> /dev/null; then
        print_success "S3 bucket exists"
    else
        print_warning "S3 bucket does not exist. Creating..."
        aws s3 mb "s3://$BUCKET" --region "${REGION:-us-east-1}" --profile "${PROFILE:-default}"
        aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled --profile "${PROFILE:-default}"
        print_success "S3 bucket created and versioning enabled"
    fi
    
    # Initialize Terraform
    terraform init \
        -backend-config="bucket=$BUCKET" \
        -backend-config="key=bmi-health-tracker/terraform.tfstate" \
        -backend-config="region=${REGION:-us-east-1}" \
        -backend-config="profile=${PROFILE:-default}"
    
    print_success "Terraform initialized successfully"
}

# Plan Terraform changes
terraform_plan() {
    print_header "Planning Terraform Changes"
    check_tfvars
    terraform plan
}

# Apply Terraform configuration
terraform_apply() {
    print_header "Applying Terraform Configuration"
    check_tfvars
    
    print_warning "This will create AWS resources. You will be charged for them."
    read -p "Continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi
    
    terraform apply
    
    if [ $? -eq 0 ]; then
        print_success "Infrastructure deployed successfully!"
        echo ""
        show_outputs
    fi
}

# Destroy Terraform resources
terraform_destroy() {
    print_header "Destroying Terraform Resources"
    
    print_warning "This will DESTROY all resources!"
    print_warning "This action cannot be undone!"
    read -p "Are you sure? Type 'destroy' to confirm: " -r
    if [[ ! $REPLY == "destroy" ]]; then
        print_info "Destruction cancelled"
        exit 0
    fi
    
    terraform destroy
}

# Show outputs
show_outputs() {
    print_header "Deployment Information"
    
    if [ -f terraform.tfstate ] || [ -f .terraform/terraform.tfstate ]; then
        INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "N/A")
        APP_URL=$(terraform output -raw application_url 2>/dev/null || echo "N/A")
        
        echo ""
        echo -e "${GREEN}Application URL:${NC} $APP_URL"
        echo -e "${GREEN}Instance IP:${NC} $INSTANCE_IP"
        echo ""
        
        print_info "Next Steps:"
        echo "  1. Upload application code:"
        echo "     scp -i ~/.ssh/YOUR_KEY.pem -r ../backend ../frontend ../database ../IMPLEMENTATION_AUTO.sh ubuntu@$INSTANCE_IP:/home/ubuntu/bmi-health-tracker/"
        echo ""
        echo "  2. SSH into instance:"
        echo "     ssh -i ~/.ssh/YOUR_KEY.pem ubuntu@$INSTANCE_IP"
        echo ""
        echo "  3. Deploy application:"
        echo "     cd /home/ubuntu/bmi-health-tracker"
        echo "     ./IMPLEMENTATION_AUTO.sh"
        echo ""
        
        print_info "Useful Commands:"
        echo "  terraform output              # Show all outputs"
        echo "  terraform output ssh_command  # Get SSH command"
        echo "  terraform show               # Show current state"
        echo ""
    else
        print_warning "No Terraform state found. Run 'terraform apply' first."
    fi
}

# Upload application code
upload_code() {
    print_header "Uploading Application Code"
    
    INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null)
    if [ -z "$INSTANCE_IP" ] || [ "$INSTANCE_IP" == "N/A" ]; then
        print_error "Could not get instance IP. Has Terraform been applied?"
        exit 1
    fi
    
    KEY_FILE=$(get_tfvar "key_pair_name")
    KEY_PATH="$HOME/.ssh/${KEY_FILE}.pem"
    
    if [ ! -f "$KEY_PATH" ]; then
        print_error "Key file not found: $KEY_PATH"
        print_info "Please provide the path to your SSH key:"
        read -p "Key path: " KEY_PATH
    fi
    
    if [ ! -f "$KEY_PATH" ]; then
        print_error "Key file not found: $KEY_PATH"
        exit 1
    fi
    
    print_info "Uploading application code to $INSTANCE_IP..."
    
    # Wait for instance to be ready
    print_info "Waiting for instance to be ready..."
    for i in {1..30}; do
        if ssh -i "$KEY_PATH" -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$INSTANCE_IP "echo 'ready'" &> /dev/null; then
            print_success "Instance is ready"
            break
        fi
        sleep 10
        echo -n "."
    done
    echo ""
    
    # Upload files
    rsync -avz -e "ssh -i $KEY_PATH -o StrictHostKeyChecking=no" \
        --exclude 'node_modules' \
        --exclude '.git' \
        --exclude 'dist' \
        --exclude 'terraform' \
        ../ ubuntu@$INSTANCE_IP:/home/ubuntu/bmi-health-tracker/
    
    print_success "Application code uploaded"
    print_info "Next: SSH into the instance and run ./IMPLEMENTATION_AUTO.sh"
}

# Main script
main() {
    check_prerequisites
    
    case "${1:-help}" in
        init)
            terraform_init
            ;;
        plan)
            terraform_plan
            ;;
        apply)
            terraform_apply
            ;;
        destroy)
            terraform_destroy
            ;;
        output)
            show_outputs
            ;;
        upload)
            upload_code
            ;;
        help|*)
            echo "BMI Health Tracker - Terraform Deployment Helper"
            echo ""
            echo "Usage: ./deploy.sh [command]"
            echo ""
            echo "Commands:"
            echo "  init     - Initialize Terraform backend"
            echo "  plan     - Show Terraform execution plan"
            echo "  apply    - Create AWS infrastructure"
            echo "  destroy  - Destroy all AWS resources"
            echo "  output   - Show deployment information"
            echo "  upload   - Upload application code to EC2 (after apply)"
            echo "  help     - Show this help message"
            echo ""
            echo "Example workflow:"
            echo "  1. ./deploy.sh init"
            echo "  2. ./deploy.sh plan"
            echo "  3. ./deploy.sh apply"
            echo "  4. ./deploy.sh upload"
            echo "  5. SSH and run ./IMPLEMENTATION_AUTO.sh"
            ;;
    esac
}

main "$@"
