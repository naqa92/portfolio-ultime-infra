################################################################################
# EFS Module
################################################################################

module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "~> 1.6"

  name           = "${var.cluster_name}-efs"
  creation_token = "${var.cluster_name}-efs-token"

  performance_mode = "generalPurpose"
  throughput_mode  = "elastic" # Elastic mode pour auto-scaling des performances

  security_group_vpc_id = module.vpc.vpc_id # le module EFS crée son propre groupe de sécurité dans le bon VPC

  # Mount targets for each AZ (multi-AZ support)
  mount_targets = {
    for idx in range(length(var.availability_zones)) : idx => {
      subnet_id = module.vpc.private_subnets[idx]
    }
  }

  tags = var.tags

  depends_on = [module.vpc, module.node_sg]
}

################################################################################
# EFS Security Group Rules
################################################################################

resource "aws_security_group_rule" "efs_nfs_from_nodes" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = module.eks.node_security_group_id
  security_group_id        = module.efs.security_group_id
  description              = "Allow NFS (port 2049) from EKS node security group"
}

################################################################################
# EFS Backup Policy (AWS Backup integration)
################################################################################

resource "aws_efs_backup_policy" "example" {
  file_system_id = module.efs.id

  backup_policy {
    status = "ENABLED"
  }
}

################################################################################
# EFS Access Points (for improved isolation and security)
################################################################################

resource "aws_efs_access_point" "k8s" {
  file_system_id = module.efs.id

  root_directory {
    path = "/kubernetes"

    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  posix_user {
    gid = 1000
    uid = 1000
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-k8s-ap"
    }
  )

  depends_on = [module.efs]
}
