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

module "efs_csi_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "aws-efs-csi"

  attach_aws_efs_csi_policy = true

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
      namespace       = "alb-system"
      service_account = "aws-load-balancer-controller"
    }
  }

  tags = var.tags
}

module "external_dns_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "external-dns"

  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = ["arn:aws:route53:::hostedzone/Z075458018F27SBDB41PA"]

  associations = {
    externaldns = {
      cluster_name    = module.eks.cluster_name
      namespace       = "external-dns"
      service_account = "external-dns"
    }
  }

  tags = var.tags
}

module "cert_manager_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "cert-manager"

  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = ["arn:aws:route53:::hostedzone/Z075458018F27SBDB41PA"]

  associations = {
    cert_manager = {
      cluster_name    = module.eks.cluster_name
      namespace       = "certmanager-system"
      service_account = "cert-manager"
    }
  }

  tags = var.tags
}

module "cert_manager_sync_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "cert-manager-sync"

  attach_custom_policy = true # ACM n'est pas couvert par défaut

  policy_statements = [
    {
      sid    = "ACMFullAccess"
      effect = "Allow"
      actions = [
        "acm:*"
      ]
      resources = ["*"]
    }
  ]

  associations = {
    cert_manager_sync = {
      cluster_name    = module.eks.cluster_name
      namespace       = "certmanager-system"
      service_account = "cert-manager-sync"
    }
  }

  tags = var.tags
}

module "securecodebox_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "securecodebox"

  attach_custom_policy = true # S3 n'est pas couvert par défaut

  policy_statements = [
    {
      sid    = "AllowPutObjectsToBucket"
      effect = "Allow"
      actions = [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:PutObjectTagging"
      ]
      resources = [
        "arn:aws:s3:::portfolio-ultime-securecodebox/*"
      ]
    },
    {
      sid    = "AllowListBucketOnPortfolioUltime"
      effect = "Allow"
      actions = [
        "s3:ListBucket"
      ]
      resources = [
        "arn:aws:s3:::portfolio-ultime-securecodebox/*"
      ]
    },
    {
      sid    = "AllowGetObjectsFromBucket"
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:GetObjectAcl",
        "s3:HeadObject"
      ]
      resources = [
        "arn:aws:s3:::portfolio-ultime-securecodebox/*"
      ]
    }
  ]

  associations = {
    securecodebox = {
      cluster_name    = module.eks.cluster_name
      namespace       = "securecodebox-system"
      service_account = "securecodebox-operator"
    }
  }

  tags = var.tags
}

module "external_secrets_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"

  name = "external-secrets"

  attach_external_secrets_policy        = true
  external_secrets_secrets_manager_arns = ["arn:aws:secretsmanager:eu-west-3:*"] # Liste des ARNs contenant les secrets à monter via ESO
  external_secrets_create_permission    = true # Permet à ESO de créer/supprimer des secrets dans Kubernetes

  associations = {
    eso = {
      cluster_name    = module.eks.cluster_name
      namespace       = "external-secrets"
      service_account = "external-secrets"
    }
  }

  tags = var.tags
}
