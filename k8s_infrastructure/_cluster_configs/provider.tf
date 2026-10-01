# ==============================================================================
# TERRAFORM STATE & PROVIDERS CONFIGURATION
# ==============================================================================
terraform {
  backend "s3" {
    bucket = "uds-enterprise-datalake-2026"
    key    = "state/terraform.tfstate"
    region = "eu-north-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

# AWS Provider (Compute & EKS)
provider "aws" {
  region                      = "eu-north-1" 
  skip_credentials_validation = true
  skip_metadata_api_check     = true
}

# GCP Provider (Storage & BigQuery)
# NOTE: Replace 'your-gcp-project-id' with your actual GCP Project ID
provider "google" {
  project = "your-gcp-project-id"
  region  = "asia-southeast1"
}

# K8s & Helm Providers (Will authenticate to EKS once provisioned)
provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}