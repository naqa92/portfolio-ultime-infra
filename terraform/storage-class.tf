################################################################################
# Storage Class EBS (RWO - Single pod access)
################################################################################

resource "kubernetes_storage_class" "gp3_default" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = false # Permet d'avoir le contrôle sur la taille des volumes
  reclaim_policy         = "Delete"

  parameters = {
    type       = "gp3"
    fsType     = "ext4"
    encrypted  = "true"
    iops       = "3000" # IOPS de base pour gp3 (jusqu'à 16000 max)
    throughput = "125"  # MB/s de base pour gp3 (jusqu'à 1000 max)
  }

  depends_on = [
    module.eks.cluster_name,
    module.eks.cluster_addons
  ]
}

################################################################################
# Storage Class EFS (RWX - Multi-pod access)
################################################################################

resource "kubernetes_storage_class" "efs" {
  metadata {
    name = "efs"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }

  storage_provisioner    = "efs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"

  parameters = {
    provisioningMode = "efs-ap" # Elastic Provisioning mode
    fileSystemId     = module.efs.id
    directoryPerms   = "700"
  }

  depends_on = [
    module.eks.cluster_name,
    module.eks.cluster_addons
  ]
}
