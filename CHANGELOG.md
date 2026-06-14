# Changelog

## v1.0.0 (2026-06-14)

### Initial Release

#### Core
- Complete layered Kubernetes architecture with 9 layers (Cluster → GitOps)
- Bilingual documentation (Vietnamese + English) for architecture and stack flow
- Production-grade manifests with security, scalability, and observability by default

#### Cluster
- EKS cluster definition with managed node groups (on-demand + spot)
- Multi-AZ deployment across 2 availability zones
- OIDC provider + IRSA for fine-grained IAM
- Cluster Autoscaler integration
- VPC with public/private subnets, NAT gateways

#### Networking
- Ingress-NGINX controller (DaemonSet, hostNetwork, NLB)
- cert-manager with Let's Encrypt ClusterIssuers (production + staging)
- HTTP/2, HSTS, proxy protocol enabled
- Auto-scaling for ingress controller

#### Storage
- gp3 StorageClass (default) with encryption, 3000 IOPS, 125 MB/s throughput
- gp3-retain StorageClass for data that must persist after PVC deletion
- EFS StorageClass for ReadWriteMany workloads
- VolumeSnapshotClass for CSI snapshots

#### Data Layer
- MySQL 8.4 StatefulSet (3 replicas) with tuned my.cnf
- Read/write primary service + read-only replica service
- Headless service for stable DNS
- PVC auto-provisioning (10Gi gp3 each)
- Resource limits, liveness/readiness probes

#### Application
- Deployment with rolling updates, anti-affinity, topology spread
- Resource requests/limits with guaranteed QoS
- Liveness + readiness probes with proper thresholds
- Graceful shutdown via preStop hook (10s drain)
- Security context: non-root, read-only root fs, drop all capabilities
- ClusterIP Service with metrics port
- TLS Ingress with cert-manager auto-certificate
- HPA (CPU 75% + memory 80%) with stabilization window
- PodDisruptionBudget (min 2 available)

#### Security
- Default-deny NetworkPolicy (ingress + egress)
- Selective allow rules for ingress controller, DNS, MySQL, monitoring
- ServiceAccount with dedicated Role + RoleBinding
- Sealed Secrets controller for git-safe encrypted secrets
- Pod Security Standards compatible

#### Monitoring
- kube-prometheus-stack (Prometheus + Grafana + AlertManager)
- Prometheus with 50GB persistent storage, 15-day retention
- AlertManager with Slack integration (default + critical channels)
- Grafana with ingress, TLS, persistence, preloaded dashboards
- Loki + Promtail for log aggregation
- ServiceMonitor/PodMonitor support for app metrics

#### Backup
- Velero with AWS S3 plugin
- Daily backup (30-day retention) + Monthly backup (90-day retention)
- CSI snapshot support for PVs
- Scheduled backup for application namespace resources

#### GitOps
- ArgoCD with HA configuration (2 server + 2 repo server replicas)
- ApplicationSet support for multi-env/multi-cluster
- TLS ingress with cert-manager
- RBAC with admin + read-only roles
