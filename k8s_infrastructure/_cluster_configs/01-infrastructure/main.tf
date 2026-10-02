# ==============================================================================
# ZONE 2 & 3: AWS EKS CLUSTER (THE COMPUTE MUSCLE) + KARPENTER FINOPS
# ==============================================================================

# 1. Network Foundation (VPC for EKS)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "emarket-killer-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-north-1a", "eu-north-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  
  # WAJIB BUAT KARPENTER: Tagging subnet biar Karpenter tau harus naruh mesin di mana
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1, "karpenter.sh/discovery" = "uds-eks-cluster" }

  tags = { Environment = "Production", Project = "eMarket-BigData" }
}

# 2. EKS Cluster Provisioning
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "uds-eks-cluster"
  cluster_version = "1.30"

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  enable_cluster_creator_admin_permissions = true

  # NODE GROUP INTI (On-Demand): Khusus buat jalanin Karpenter & CoreDNS biar kaga mati
  eks_managed_node_groups = {
    system_core = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2
      capacity_type  = "ON_DEMAND"
      labels         = { "node-role.kubernetes.io/system" = "true" }
    }
  }
}

# ==============================================================================
# THE FINOPS ENGINE: KARPENTER (AUTO-SCALING SPOT INSTANCES)
# ==============================================================================

# 3. IAM Roles & SQS Queue for Spot Interruption
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = module.eks.cluster_name

  # Setup IRSA (IAM Roles for Service Accounts)
  enable_pod_identity             = true
  create_pod_identity_association = true

  # IAM Node Role buat mesin-mesin Spot yang bakal diciptakan Karpenter
  create_node_iam_role = true
  node_iam_role_name   = "karpenter-node-role-${module.eks.cluster_name}"

  tags = { Environment = "Production", Project = "eMarket-BigData" }
}

# 4. Install Karpenter via Helm
resource "helm_release" "karpenter" {
  namespace        = "kube-system"
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "0.36.0"
  create_namespace = true
  wait             = false

  values = [
    yamlencode({
      settings = {
        clusterName       = module.eks.cluster_name
        interruptionQueue = module.karpenter.queue_name
      }
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = module.karpenter.iam_role_arn
        }
      }
      # Karpenter HARUS jalan di Node Group Inti (On-Demand) biar kaga kena interupsi
      nodeSelector = {
        "node-role.kubernetes.io/system" = "true"
      }
    })
  ]

  depends_on = [module.eks]
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "karpenter_sqs_queue" {
  value = module.karpenter.queue_name
}