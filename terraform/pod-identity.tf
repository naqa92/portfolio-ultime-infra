################################################################################
# EKS Pod Identity Module
################################################################################

module "ebs_csi_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "aws-ebs-csi"

  attach_aws_ebs_csi_policy = true

  # associations gérées dans le module EKS (voir addons)

  tags = var.tags
}

module "aws_lb_controller_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "aws-lbc"

  attach_aws_lb_controller_policy = true

  associations = {
    lbc = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-alb"
      service_account = "aws-load-balancer-controller"
    }
  }

  tags = var.tags
}
