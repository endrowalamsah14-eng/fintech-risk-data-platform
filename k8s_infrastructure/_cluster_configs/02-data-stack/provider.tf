# ==============================================================================
# FASE 2: DATA STACK & CLOUD INTEGRATION (K8s, Helm, GCP)
# ==============================================================================
terraform {
  backend "s3" {
    bucket = "uds-enterprise-datalake-2026"
    # PENTING: Nama 'key' harus beda dari Fase 1 biar state-nya kaga tabrakan!
    key    = "v3.0-datastack/terraform.tfstate" 
    region = "eu-north-1"
  }

  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    google     = { source = "hashicorp/google", version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.23.0" }
    helm       = { source = "hashicorp/helm", version = "~> 2.17" }
  }
}

# ------------------------------------------------------------------------------
# 1. AWS & EKS DISCOVERY (Mencari cluster yang udah dibangun di Fase 1)
# ------------------------------------------------------------------------------
provider "aws" {
  region = "eu-north-1"
}

# Terraform otomatis nyari cluster bernama "uds-eks-cluster" di akun AWS lu
data "aws_eks_cluster" "eks" {
  name = "uds-eks-cluster"
}
data "aws_eks_cluster_auth" "eks_auth" {
  name = "uds-eks-cluster"
}

# ------------------------------------------------------------------------------
# 2. GCP PROVIDER (Brankas Data Lakehouse)
# ------------------------------------------------------------------------------
provider "google" {
  # Nanti pas CI/CD nyala, otentikasi pakai GOOGLE_CREDENTIALS dari GitHub Secrets
  project = "GANTI_SAMA_PROJECT_ID_GCP_LU_NANTI"
  region  = "asia-southeast1"
}

# ------------------------------------------------------------------------------
# 3. KUBERNETES & HELM (Otomatis login pakai token EKS dari block Data di atas)
# ------------------------------------------------------------------------------
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_auth.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks_auth.token
  }
}