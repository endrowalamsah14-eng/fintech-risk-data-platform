terraform {
  required_providers {
    # Hetzner Provider
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    # 🔥 NEW: AWS Provider (Pengganti GCP)
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

# Region Stockholm sesuai console lu, biar deket sama Hetzner EU
provider "aws" {
  region = "eu-north-1" 
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}