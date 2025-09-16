# Cluster EKS avec Terraform

Ce projet utilise GitHub Actions pour automatiser le déploiement d'une infrastructure via Terraform avec :

- Cluster EKS complet via plusieurs modules
- ArgoCD avec boostrap d'applications

---

# Pré-requis

- Terraform >= 1.12.0
- AWS CLI configuré
- Configurer la variable `allowed_ips` : Adresse IP en /32
- Repo git dédié pour ArgoCD : `portfolio-ultime-config`
- Bucket S3 backend : `portfolio-ultime-infra`

```bash
aws s3api create-bucket \
  --bucket portfolio-ultime-infra \
  --region eu-west-3 \
  --create-bucket-configuration LocationConstraint=eu-west-3
```

> _Pour supprimer le bucket S3 : `aws s3 rb s3://portfolio-ultime-infra --force`_

- Définir les secrets du repo

| Secret                  | Description     |
| ----------------------- | --------------- |
| `AWS_ACCESS_KEY_ID`     | Clé d'accès AWS |
| `AWS_SECRET_ACCESS_KEY` | Clé secrète AWS |

---

# 📁 Structure du projet

```
portfolio-ultime-infra/
├── .github/workflows/
│   └── terraform.yml           # Pipeline CI/CD
├── terraform/
│   ├── eks.tf                  # Configuration EKS
│   ├── helm-charts.tf          # Charts Helm
│   ├── pod-identity.tf         # Pod Identity
│   ├── providers.tf            # Providers Terraform
│   ├── variables.tf            # Variables
│   ├── vpc.tf                  # Configuration VPC
└── README.md
```

---

# Cluster EKS complet

## Kubeconfig

```bash
aws eks --region eu-west-3 update-kubeconfig --name eks-cluster
```

## Backend S3

Bucket S3 `portfolio-ultime-infra` avec `use_lockfile = true` (plus besoin de DynamoDB pour le verrouillage)

![s3](images/s3.png)

## Infrastructure réseau (modules terraform-aws-vpc et terraform-aws-security-group)

- VPC (10.0.0.0/16) avec support DNS : Emplacement logique pour créer les réseaux
- Subnets multi-AZ (eu-west-3a et 3b) :
  - 2 privés : 10.0.0.0/19, 10.0.32.0/19
  - 2 publics : 10.0.64.0/19, 10.0.96.0/19
- NAT Gateway et Internet Gateway (création automatique via enable_nat_gateway)
  - NAT : Permet aux instances dans les réseaux privés d'accéder au réseau public
  - Internet : Permet au réseau public d'accéder à Internet
- Tables de routage
  - Pour les subnets publics : Une route vers l'Internet Gateway est automatiquement ajoutée.
  - Pour les subnets privés : Une route vers le NAT Gateway est automatiquement ajoutée.
- 3 Groupes de sécurité : cluster, nodes et load balancer

![Networking](images/networking.png)

## Cluster EKS (module terraform-aws-eks)

- Version : 1.33
- Add-ons managés :
  - CoreDNS
  - kube-proxy
  - vpc-cni
  - eks-pod-identity-agent
  - aws-ebs-csi-driver

![Add-ons](images/addons.png)

## EKS Pod Identity (module terraform-aws-eks-pod-identity)

Mapping IAM ↔️ Pod via un agent natif pour l'accès aux services AWS depuis un pod (remplacement moderne de IRSA, plus besoin de gérer l'OIDC / trust policy)

- AWS EBS CSI Driver (sans KMS car optionnel)
- AWS Load Balancer Controller

![Pod Identity](images/pod-identity.png)

## Composants additionnels

- AWS Load Balancer Controller (via Helm)

![ALB](images/alb.png)

### AWS Load Balancer Controller - Architecture de flux

Internet → ALB (L7) → Target groups (pod IPs) → Réseau VPC / Node ENI → Pods

### AWS Load Balancer Controller - Values helm

- `defaultTargetType = "ip"` : Instance par défaut. Avec IP, Le trafic est directement routé vers les adresses IP des pods. La valeur IP est recommandée pour une meilleure intégration et performance avec la CNI Amazon VPC.
- `deregistration_delay = 120s` : Valeur fixe pour synchroniser la durée avec `terminationGracePeriodSeconds` du pod pour éviter les coupures de sessions pendant les déploiements

> à configurer côté pod : terminationGracePeriodSeconds + ReadinessProbes

# Bootstrap ArgoCD

## Déploiement

- Installation d'ArgoCD via chart Helm
- Déploiement des applications ArgoCD via la stratégie App-of-apps

![ArgoCD UI](images/argocd.png)

---

# Pipeline dédiée à Terraform

## Fonctionnement du Workflow Dispatch

| Action                          | Format check | Init | Validate | Plan | Apply | Destroy |
| ------------------------------- | :----------: | :--: | :------: | :--: | :---: | :-----: |
| **Push**                        |      ✅      |  ✅  |    ✅    |  ✅  |  ✅   |   ❌    |
| **Workflow dispatch - plan**    |      ✅      |  ✅  |    ✅    |  ✅  |  ❌   |   ❌    |
| **Workflow dispatch - apply**   |      ✅      |  ✅  |    ✅    |  ✅  |  ✅   |   ❌    |
| **Workflow dispatch - destroy** |      ✅      |  ✅  |    ✅    |  ❌  |  ❌   |   ✅    |

---

## TODO

- Destroy terraform : Gérer le load balancer + les security groups attachés à celui-ci

- ArgoCD :

  - Repo config privé : Secret pour la synchronisation du repo "portfolio-ultime-config"
  - Rendered manifests pattern
  - Déploiements : Argo Rollouts et Observabilité (avec Metrics server)

- EKS Production ready :

  - Au moins 3 nodes
  - Au moins 3 AZ
  - Access Entries : Mapping IAM ↔️ utilisateurs Kubernetes automatisé pour gérer plus finement les permissions d'accès au cluster (remplacement moderne de aws-auth / actuellement `enable_cluster_creator_admin_permissions = true`)
  - Chiffrement EBS via `encryption_config` (KMS)
  - Logging control plane (CloudWatch)
  - Backups : Cluster et Database
  - Branch Protection pour pipeline avec :
    - Distinction entre plan (PR) et apply (merge)
    - Approbation manuelle via environment production
