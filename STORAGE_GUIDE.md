# Guide Stockage EBS + EFS

## Vue d'ensemble

Cette configuration fournit deux StorageClass Kubernetes pour couvrir différents use cases :

### 📊 Comparaison

| Critère            | EBS (gp3)                                   | EFS                                     |
| ------------------ | ------------------------------------------- | --------------------------------------- |
| **Type de volume** | Block Storage                               | File System (NFS)                       |
| **Mode d'accès**   | RWO (1 lecteur/writer)                      | RWX (N lecteurs/writers)                |
| **Disponibilité**  | Zonal (1 AZ)                                | Multi-AZ natif                          |
| **Binding**        | WaitForFirstConsumer                        | WaitForFirstConsumer                    |
| **Performance**    | Très haute latence basse                    | Bonne, latence réseau                   |
| **Use cases**      | DB, Cache, Applications stateful unireplica | Partage données, HPA, données partagées |

---

## 🗄️ StorageClass EBS (gp3)

### Configuration

```yaml
Name: gp3 (défaut)
Provisioner: ebs.csi.aws.com
Mode: RWO - ReadWriteOnce
IOPS: 3000
Throughput: 125 MB/s
Encryption: Enabled
```

### Utilisation

**Use cases :**

- ✅ Base de données (PostgreSQL, MySQL)
- ✅ Cache (Redis, Memcached)
- ✅ Applications haute performance
- ✅ Volumes techniques (logs, données temporaires)

**Exemple PVC :**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: db-storage
spec:
  storageClassName: gp3
  accessModes:
    - ReadWriteOnce
  resources:
    storage: 50Gi
```

**Déploiement avec volume :**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql
spec:
  replicas: 1 # ⚠️ EBS = 1 seul replica
  template:
    spec:
      containers:
        - name: postgres
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: db-storage
```

### Avantages ⭐

- Très haute performance
- Coûts prévisibles
- Parfait pour charges intensives

### Limites ⚠️

- **Une seule zone** : pas de multi-AZ automatique
- **Un seul reader/writer** : pas de montage multi-pod
- Reschedule sur autre AZ = Pending (mitigé par `WaitForFirstConsumer`)

---

## 📁 StorageClass EFS

### Configuration

```yaml
Name: efs
Provisioner: efs.csi.aws.com
Mode: RWX - ReadWriteMany
Type: Network File System (NFS)
Encryption: Enabled
Throughput: Elastic (auto-scaling)
Backup: Enabled
Lifecycle: Transition to IA après 30 jours
```

### Architecture

```
EKS Cluster (Multi-AZ)
├── eu-west-3a
│   ├── Node 1
│   │   └── Pod 1 (mount /data)
│   └── EFS Mount Target (eu-west-3a)
│       └── NFS protocol (port 2049)
│
├── eu-west-3b
│   ├── Node 2
│   │   └── Pod 2 (mount /data)
│   └── EFS Mount Target (eu-west-3b)
│       └── NFS protocol (port 2049)
│
└── EFS File System (shared across AZ)
    └── Single namespace pour tous les pods
```

### Utilisation

**Use cases :**

- ✅ Applications avec HPA et persistance
- ✅ Données partagées entre plusieurs replicas
- ✅ Uploads/assets utilisateurs
- ✅ Logs centralisées
- ✅ Datasets pour ML
- ✅ Partage fichiers inter-pods

**Exemple PVC :**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-storage
spec:
  storageClassName: efs
  accessModes:
    - ReadWriteMany # ✅ Multi-pod access
  resources:
    storage: 100Gi
```

**Déploiement avec HPA :**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: app
          volumeMounts:
            - name: data
              mountPath: /app/data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: shared-storage
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 1
  maxReplicas: 10 # ✅ Fonctionne à 100%
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

### Avantages ⭐

- **Accès multi-AZ natif** : tous les pods accèdent au même storage
- **RWX (ReadWriteMany)** : N pods peuvent lire/écrire simultanément
- **HPA ready** : scale horizontalement sans problème
- **Backup intégré** : AWS Backup support
- **Lifecycle intelligent** : transition auto vers IA après 30 jours

### Limites ⚠️

- Latence légèrement plus élevée (réseau NFS)
- Coûts potentiellement plus élevés (paiement à l'usage)
- Pas ideal pour I/O ultra-intensives

---

## 🔒 Sécurité

### EBS

- ✅ Chiffrement activé par défaut
- ✅ Isolation par volume
- ✅ Permissions IAM via Pod Identity

### EFS

- ✅ Chiffrement activé
- ✅ Security Group dédiée (NFS port 2049)
- ✅ Access Points avec POSIX users/perms
- ✅ File System Policy restreignant l'accès
- ✅ Multi-AZ redundancy

---

## 📊 Coûts estimés (eu-west-3)

### EBS gp3

- Stockage : ~0.10 $/Gi/mois
- IOPS supplémentaires : gratuit (3000 inclus)
- Throughput supplémentaire : gratuit (125 MB/s inclus)

**100 Gi = ~$10/mois**

### EFS

- Stockage : ~0.30 $/Gi/mois
- Stockage IA : ~0.025 $/Gi/mois
- Requêtes : facturation à l'usage

**100 Gi = ~$30/mois (Standard) ou moins avec Lifecycle**

---

## ✅ Checklist Migration

Si vous passez d'EBS à EFS :

- [ ] Vérifier `accessModes: ReadWriteMany` dans les PVC
- [ ] Adapter les permissions fichiers (EFS = NFS)
- [ ] Tester les chemins de montage
- [ ] Configurer les NetworkPolicies si nécessaire
- [ ] Valider les performances applicatives
- [ ] Planifier la migration des données existantes

---

## 🚀 Prochaines étapes

1. **Déployer les ressources** :

   ```bash
   terraform apply
   ```

2. **Vérifier l'installation** :

   ```bash
   kubectl get storageclass
   kubectl get pvc
   kubectl describe efs
   ```

3. **Tester EFS** :

   ```bash
   kubectl apply -f - <<EOF
   apiVersion: v1
   kind: Pod
   metadata:
     name: efs-test
   spec:
     containers:
     - name: test
       image: busybox
       command: ["/bin/sh"]
       args: ["-c", "touch /mnt/test-file && sleep 3600"]
       volumeMounts:
       - name: efs
         mountPath: /mnt
     volumes:
     - name: efs
       persistentVolumeClaim:
         claimName: test-efs-pvc
   EOF
   ```

4. **Monitorer EFS** dans CloudWatch :
   - Métriques : DataReadIOBytes, DataWriteIOBytes, ClientConnections
   - Alertes : SumPeriodicDataAccessCount

---

## 📚 Références

- [AWS EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
- [AWS EFS CSI Driver](https://github.com/kubernetes-sigs/aws-efs-csi-driver)
- [EFS Best Practices](https://docs.aws.amazon.com/efs/latest/ug/performance.html)
- [Terraform AWS EFS Module](https://registry.terraform.io/modules/terraform-aws-modules/efs/aws/latest)
