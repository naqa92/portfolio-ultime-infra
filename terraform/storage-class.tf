################################################################################
# Storage Class
################################################################################

# Storage Class gp3 par défaut
resource "kubernetes_storage_class" "gp3_default" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy        = "Delete"

  parameters = {
    type       = "gp3"
    fsType     = "ext4"
    encrypted  = "true"
    iops       = "3000"    # IOPS de base pour gp3 (jusqu'à 16000 max)
    throughput = "125"     # MB/s de base pour gp3 (jusqu'à 1000 max)
  }

  depends_on = [
    module.eks.cluster_name,
    module.eks.cluster_addons
  ]
}