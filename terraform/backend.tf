terraform {
  backend "s3" {
    # Configure these values in terraform init command:
    # terraform init -backend-config="bucket=YOUR_BUCKET_NAME" -backend-config="key=bmi-health-tracker/terraform.tfstate" -backend-config="region=YOUR_REGION" -backend-config="profile=YOUR_PROFILE"
    
    # Alternatively, uncomment and set these values directly:
    bucket  = "batch09-ostad"
    key     = "bmi-health-tracker/terraform.tfstate"
    region  = "ap-south-1"
    profile = "sarowar-ostad"  # Using your AWS profile
    
    encrypt = true
  }
}
