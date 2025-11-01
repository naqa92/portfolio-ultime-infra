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

  values = [
    yamlencode({
      configs = {
        cm = {
          # Health checks personnalisés pour CNPG et Atlas
          "resource.customizations.health.postgresql.cnpg.io_Cluster" = <<-EOT
            hs = {}
            if obj.status == nil then
              hs.status = "Progressing"
              hs.message = "Waiting for cluster status..."
              return hs
            end

            if obj.status.conditions ~= nil then
              for i, condition in ipairs(obj.status.conditions) do
                if condition.type == "Ready" and condition.status == "True" then
                  hs.status = "Healthy"
                  hs.message = condition.message
                  return hs
                end
                if condition.type == "Ready" and condition.status == "False" then
                  hs.status = "Degraded"
                  hs.message = condition.message
                  return hs
                end
              end
            end

            hs.status = "Progressing"
            hs.message = "Waiting for cluster reconciliation..."
            return hs
          EOT

          "resource.customizations.health.db.atlasgo.io_AtlasSchema" = <<-EOT
            hs = {}
            if obj.status == nil or obj.status.conditions == nil then
              hs.status = "Progressing"
              hs.message = "Waiting for schema reconciliation..."
              return hs
            end

            for i, condition in ipairs(obj.status.conditions) do
              if condition.type == "Ready" then
                if condition.status == "True" then
                  hs.status = "Healthy"
                  hs.message = condition.message
                  return hs
                elseif condition.status == "False" then
                  hs.status = "Degraded"
                  hs.message = condition.message
                  return hs
                end
              end
            end

            hs.status = "Progressing"
            hs.message = "Schema migration in progress..."
            return hs
          EOT
        }
      }
    })
  ]

  depends_on = [module.eks]
}

################################################################################
# App-of-Apps : Infrastructure & Applications
################################################################################

resource "helm_release" "argocd_apps" { # Déploiement des applications ArgoCD (2 apps principales)
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  version    = "2.0.2"
  chart      = "argocd-apps"
  namespace  = "argocd"

  values = [
    yamlencode({
      applications = {
        infrastructure = { # App-of-Apps pour infrastructure
          namespace = "argocd"
          project   = "default"
          source = {
            path           = "infrastructure"
            repoURL        = "https://github.com/naqa92/portfolio-ultime-config.git"
            targetRevision = "main"
            directory = {
              recurse = true
              include = "**/*.yaml"
              exclude = "**/manifests/**"
            }
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "argocd"
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
        applications = { # App-of-Apps pour applications
          namespace = "argocd"
          project   = "default"
          source = {
            path           = "applications"
            repoURL        = "https://github.com/naqa92/portfolio-ultime-config.git"
            targetRevision = "main"
            directory = {
              recurse = true
              include = "**/*.yaml"
              exclude = "**/manifests/**"
            }
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "argocd"
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
