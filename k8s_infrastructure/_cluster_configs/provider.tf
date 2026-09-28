terraform {
  # 🔥 Pindah memori Terraform ke AWS S3 (Remote State)
  backend "s3" {
    bucket = "uds-enterprise-datalake-2026"
    key    = "state/terraform.tfstate"
    region = "eu-north-1"
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    aws = {
      source  = "hashicorp/aws"
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

variable "hcloud_token" {
  type      = string
  sensitive = true
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "aws" {
  region = "eu-north-1" 
  
  # Baris skip_requesting_account_id sudah dibuang biar ID AWS lu bisa masuk ke ARN
  skip_credentials_validation = true
  skip_metadata_api_check     = true
}

provider "kubernetes" {
  # Dibiarkan kosong, otomatis mendeteksi ~/.kube/config
}

provider "helm" {
  # Dibiarkan kosong, otomatis mendeteksi ~/.kube/config
}