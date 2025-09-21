################################################################################
# EKS Module
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  endpoint_private_access      = true            # Accès API Kubernetes privé depuis le VPC
  endpoint_public_access       = true            # Accès API Kubernetes public depuis Internet
  endpoint_public_access_cidrs = var.allowed_ips # Restreindre l'accès API Kubernetes public

  enable_cluster_creator_admin_permissions = true

  service_ipv4_cidr = "10.100.0.0/16"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  additional_security_group_ids = [module.cluster_sg.security_group_id, module.node_sg.security_group_id]

  addons = {
    eks-pod-identity-agent = { before_compute = true }
    vpc-cni                = { before_compute = true }
    aws-ebs-csi-driver = {
      pod_identity_association = [{
        role_arn        = module.ebs_csi_pod_identity.iam_role_arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
    coredns    = {}
    kube-proxy = {}
  }

  eks_managed_node_groups = {
    default = {
      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = var.tags
}
