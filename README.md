# k8s-production-stack

Triển khai ứng dụng production-grade lên Kubernetes với kiến trúc phân tầng, bảo mật, và khả năng mở rộng.

Deploy production-grade applications on Kubernetes with a layered architecture, security, and scalability.

## Documentation

| Language | |
|----------|-|
| 🇻🇳 Tiếng Việt | [Kiến trúc](docs/vi/architecture.md) · [Chi tiết các tầng](docs/vi/stack-flow.md) |
| 🇬🇧 English | [Architecture](docs/en/architecture.md) · [Stack Flow](docs/en/stack-flow.md) |

## Architecture

The stack provisions the following Kubernetes layers:

| Layer | Components | Details |
|-------|-----------|---------|
| **Cluster** | EKS / Kubeadm | VPC, multi-AZ node groups, OIDC + IRSA |
| **Networking** | Ingress-NGINX, cert-manager, CoreDNS | TLS termination, auto certificate renewal |
| **Storage** | CSI Drivers, StorageClass | gp3 encrypted volumes, dynamic provisioning, snapshots |
| **Data** | MySQL StatefulSet, Redis | HA database, persistent PVC, tuned config |
| **Application** | Deployments, Services, Ingresses, HPAs | Resource limits, probes, anti-affinity, auto-scaling |
| **Security** | Network Policies, RBAC, Sealed Secrets | Default-deny, least privilege, encrypted secrets in git |
| **Monitoring** | Prometheus, Grafana, Loki, AlertManager | Metrics, logs, alerts (Slack/PagerDuty) |
| **Backup** | Velero | Daily/monthly PV + resource backups to S3 |
| **GitOps** | ArgoCD | Declarative, versioned, self-healing deployments |

## Directory Structure

```
k8s-production-stack/
├── clusters/                  # Cluster provisioning (eksctl, kubeadm)
│   └── eksctl-cluster.yaml    # EKS cluster with managed node groups
├── networking/                # Ingress, TLS, DNS
│   ├── issuer.yaml            # Let's Encrypt ClusterIssuer
│   ├── ingress-nginx/         # Ingress-NGINX Helm values
│   └── cert-manager/          # cert-manager Helm values
├── storage/                   # CSI + StorageClass
│   └── storage-class.yaml     # gp3 default, retain, EFS
├── database/                  # Stateful workloads
│   └── mysql/                 # MySQL StatefulSet, Services, ConfigMap
├── application/               # App manifests
│   ├── deployment.yaml        # Production-grade Deployment config
│   ├── service.yaml           # ClusterIP service
│   ├── ingress.yaml           # TLS ingress with cert-manager
│   ├── hpa.yaml               # CPU + memory autoscaling
│   └── pdb.yaml               # Pod Disruption Budget
├── security/                  # Security controls
│   ├── network-policies.yaml  # Default-deny + selective allow
│   ├── rbac.yaml              # ServiceAccount, Role, RoleBinding
│   └── sealed-secrets/        # Sealed Secrets controller
├── monitoring/                # Observability
│   ├── prometheus/            # kube-prometheus-stack values
│   └── loki/                  # Loki + Promtail values
├── gitops/                    # GitOps delivery
│   └── argocd/                # ArgoCD HA config
├── backup/                    # Disaster recovery
│   └── velero/                # Velero with S3 backups
├── scripts/                   # Automation
│   ├── deploy.sh              # Full stack deploy
│   └── destroy.sh             # Full stack destroy
└── docs/                      # Documentation (EN + VI)
    ├── en/
    │   ├── architecture.md    # Architecture overview
    │   └── stack-flow.md      # Detailed layer walkthrough
    └── vi/
        ├── architecture.md
        └── stack-flow.md
```

## Deployment

### Prerequisites

- AWS account (or bare-metal servers)
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- [eksctl](https://eksctl.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [helm](https://helm.sh/docs/intro/install/)
- [kustomize](https://kustomize.io/)

### Step-by-step

```bash
# 1. Clone repo
git clone https://github.com/nathanpixodeo/k8s-production-stack.git
cd k8s-production-stack

# 2. Create EKS cluster
eksctl create cluster -f clusters/eksctl-cluster.yaml

# 3. Install StorageClass
kubectl apply -k storage/

# 4. Install Networking (Ingress-NGINX + cert-manager)
kubectl apply -k networking/

# 5. Install Monitoring
kubectl apply -k monitoring/

# 6. Install Security (NetworkPolicies, RBAC, Sealed Secrets)
kubectl apply -k security/

# 7. Install Database (MySQL)
kubectl apply -k database/

# 8. Deploy Application
kubectl apply -k application/

# 9. Install Backup (Velero)
kubectl apply -k backup/

# 10. Install GitOps (ArgoCD)
kubectl apply -k gitops/
```

### One-command deploy

```bash
./scripts/deploy.sh
```

### Parameters

| Layer | Parameter | Default | Description |
|-------|-----------|---------|-------------|
| **Cluster** | `region` | `ca-central-1` | AWS region |
| **Cluster** | `node-type` | `t3.medium` | EC2 instance type |
| **Cluster** | `minSize` | `2` | Min on-demand nodes |
| **Cluster** | `maxSize` | `10` | Max on-demand nodes |
| **Application** | `replicas` | `3` | Initial pod count |
| **Application** | `minReplicas` | `3` | Min pods (HPA) |
| **Application** | `maxReplicas` | `20` | Max pods (HPA) |
| **Application** | `cpu.target` | `75` | HPA CPU target % |
| **Application** | `memory.target` | `80` | HPA memory target % |
| **Storage** | `storage` | `10Gi` | MySQL PVC size |
| **Storage** | `storageClass` | `gp3` | Storage class |
| **Backup** | `retention` | `30` | Backup retention (days) |

## Version

Current: **v1.0.0** — See [CHANGELOG](CHANGELOG.md) for full history.

## License

MIT
