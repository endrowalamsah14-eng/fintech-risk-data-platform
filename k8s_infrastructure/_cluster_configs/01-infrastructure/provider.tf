# ==============================================================================
# FASE 1: INFRASTRUCTURE (AWS EKS & EC2)
# ==============================================================================
terraform {
  backend "s3" {
    bucket = "uds-enterprise-datalake-2026"
    key    = "v3.0-infra/terraform.tfstate"
    region = "eu-north-1"
  }
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region                      = "eu-north-1" 
  skip_credentials_validation = false
  skip_metadata_api_check     = false
}