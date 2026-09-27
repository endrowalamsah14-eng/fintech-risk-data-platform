terraform {
  required_providers {
    # Hetzner Provider
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    # AWS Provider (Pengganti GCP)
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Kubernetes Provider
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    # Helm Provider
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

# Region Stockholm sesuai console lu
provider "aws" {
  region = "eu-north-1" 
  
  # 🔥 FIX: Bypass validasi kredensial saat Terraform Plan
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

provider "kubernetes" {
  # 🔥 FIX: Komen dulu config_path, pakai dummy host buat CI/CD Plan
  # config_path = "~/.kube/config"
  host = "https://127.0.0.1:6443"
}

provider "helm" {
  kubernetes {
    # 🔥 FIX: Komen dulu config_path, pakai dummy host buat CI/CD Plan
    # config_path = "~/.kube/config"
    host = "https://127.0.0.1:6443"
  }
}