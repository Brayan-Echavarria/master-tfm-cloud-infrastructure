terraform {
  backend "s3" {
    bucket = "tfm-twcam-backend-terraform"
    key    = "backend_serverless/terraform-core.tfstate" 
    region = "eu-west-1" 
  }
}
