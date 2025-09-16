################################################################################
# AWS Load Balancer Controller
################################################################################

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.13.4"

  values = [
    yamlencode({
      clusterName = module.eks.cluster_name
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
      }
      region = var.region
      vpcId  = module.vpc.vpc_id
    })
  ]

  depends_on = [module.eks, module.aws_lb_controller_pod_identity]
}

################################################################################
# Bootstrap ArgoCD
################################################################################

resource "helm_release" "argocd" { # Installation d'ArgoCD
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  version          = "8.3.7"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  depends_on = [module.eks]
}

resource "helm_release" "argocd_apps" { # Déploiement des applications ArgoCD
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  version    = "2.0.2"
  chart      = "argocd-apps"
  namespace  = "argocd"

  values = [
    yamlencode({
      applications = {
        root-app = { # Stratégie App of Apps
          namespace = "argocd"
          project   = "default"
          source = {
            path           = "apps"
            repoURL        = "https://github.com/naqa92/portfolio-ultime-config.git"
            targetRevision = "main"
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "" # Namespace défini dans chaque application
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
            syncOptions = [
              "CreateNamespace=true"
            ]
          }
        }
      }
    })
  ]

  depends_on = [helm_release.argocd]
}