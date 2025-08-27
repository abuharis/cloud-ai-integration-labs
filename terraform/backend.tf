terraform {
  backend "s3" {
    bucket         = "demo-tfstate-bucket-xyz"   # create this in Terraform bootstrap or manually
    key            = "cloud-ai-integration/demo.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "demo-terraform-lock"
    encrypt        = true
  }
}