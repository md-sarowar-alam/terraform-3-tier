terraform {
  backend "s3" {
    # Configure these values in terraform init command:
    # terraform init -backend-config="bucket=YOUR_BUCKET_NAME" -backend-config="key=bmi-health-tracker/terraform.tfstate" -backend-config="region=YOUR_REGION" -backend-config="profile=YOUR_PROFILE"
    
    # Alternatively, uncomment and set these values directly:
    # bucket  = "your-terraform-state-bucket"
    # key     = "bmi-health-tracker/terraform.tfstate"
    # region  = "us-east-1"
    # profile = "your-aws-profile"
    
    encrypt = true
  }
}
