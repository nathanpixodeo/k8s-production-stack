# Architecture Overview

## Objectives

Deploy production-grade workloads on Kubernetes with:
- **Scalability** - HPA (Horizontal Pod Autoscaler) + Cluster Autoscaler
- **High Availability** - Multi-AZ node groups, pod anti-affinity, rolling updates
- **Security** - Network Policies, RBAC, Sealed Secrets, OPA/Gatekeeper
- **Observability** - Prometheus + Grafana (metrics), Loki (logs), AlertManager
- **Disaster Recovery** - Velero backup (PV + cluster resources), etcd snapshots

## Layered Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     GitOps (ArgoCD / Flux)                    │
│              Declarative, versioned, self-healing             │
├──────────────────────────────────────────────────────────────┤
│                     Security Layer                            │
│   Network Policies · RBAC · Sealed Secrets · OPA/Gatekeeper  │
├──────────────────────────────────────────────────────────────┤
│                     Application Layer                         │
│   Deployments · Services · Ingresses · HPAs · ConfigMaps     │
├──────────────────────────────────────────────────────────────┤
│                     Data Layer                                │
│   MySQL (StatefulSet) · Redis (StatefulSet) · PVC + CSI      │
├──────────────────────────────────────────────────────────────┤
│                     Storage Layer                             │
│   StorageClass (gp3 / EBS CSI) · PVC auto-provisioning       │
├──────────────────────────────────────────────────────────────┤
│                     Networking Layer                          │
│   Ingress-NGINX · cert-manager · CoreDNS · MetalLB (on-prem) │
├──────────────────────────────────────────────────────────────┤
│                     Cluster Layer                             │
│   EKS / Kubeadm / K3s · Managed Node Groups · VPC · Subnets  │
├──────────────────────────────────────────────────────────────┤
│                     Infrastructure Layer                      │
│   AWS Account / On-Prem · IAM · Route53 · ACM · S3 backend   │
└──────────────────────────────────────────────────────────────┘
```

## Request Flow

### 1. User accesses the application

```
User browser
    │
    ▼ DNS
Domain (CNAME → Ingress LB / ALB)
    │
    ▼
Ingress Controller (nginx / AWS ALB Ingress Controller)
    │
    ├─ TLS termination (cert-manager / ACM)
    │
    ▼
Kubernetes Service (ClusterIP / NodePort)
    │
    ▼
Kubernetes Deployment (Pods)
    │
    ├─ App container processes request
    ├─ Read/write session → Redis (if configured)
    ├─ Read/write data → MySQL (StatefulSet)
    ├─ Read/write files → PVC (EBS / EFS CSI)
    └─ Logs → stdout/sdout → Loki → Grafana
```

### 2. Stack deployment flow

```
Admin applies Kustomize / Helm / ArgoCD
    │
    ▼
── Cluster Layer
│     ├─ VPC + Subnets + Internet/NAT Gateways
│     ├─ EKS Control Plane (or kubeadm control plane)
│     ├─ Managed Node Groups (multi-AZ, on-demand + spot)
│     └─ OIDC Provider + IAM Roles for Service Accounts (IRSA)
│
── Networking Layer (depends on Cluster)
│     ├─ Ingress-NGINX Controller (DaemonSet / Deployment)
│     ├─ cert-manager (Issuers, Certificates)
│     └─ CoreDNS (cluster DNS)
│
── Storage Layer (depends on Cluster)
│     ├─ CSI Driver (EBS / EFS / RBD)
│     ├─ StorageClass (gp3, encrypted, reclaim: Delete)
│     └─ Default PVC template
│
── Data Layer (depends on Storage)
│     ├─ MySQL StatefulSet (3 replicas, sync replication)
│     │   ├─ Headless Service
│     │   ├─ PVC template (10Gi each)
│     │   └─ ConfigMap (my.cnf tuned)
│     ├─ Redis StatefulSet (HA with sentinel / cluster)
│     └── External Service (if using managed DB like RDS)
│
── Application Layer (depends on Networking, Data)
│     ├─ Namespace
│     ├─ ConfigMap / Secret (SealedSecret)
│     ├─ Deployment (with resource limits, probes, anti-affinity)
│     ├─ Service (ClusterIP)
│     ├─ Ingress (with cert-manager annotation)
│     └─ HPA (CPU + memory based scaling)
│
── Security Layer (cross-cutting)
│     ├─ NetworkPolicy (default-deny, allow-app-ingress)
│     ├─ RBAC (Roles, RoleBindings, ServiceAccounts)
│     └─ Sealed Secrets / External Secrets Operator
│
── Monitoring Layer (depends on Cluster)
│     ├─ kube-prometheus-stack (Prometheus + Grafana)
│     │   ├─ ServiceMonitor for app metrics
│     │   ├─ PodMonitor for custom metrics
│     │   └─ AlertManager (Slack, PagerDuty)
│     └─ Loki Stack (Loki + Promtail + Grafana)
│
── Backup Layer (depends on Storage)
│     ├─ Velero (backup PVs + cluster resources to S3)
│     ├─ Schedule (daily, 30-day retention)
│     └─ Restore演练
│
── GitOps Layer (cross-cutting)
      ├─ ArgoCD / Flux
      ├─ ApplicationSet (multi-env, multi-cluster)
      └─ Sync policies (auto-sync, prune, self-heal)
```

## Auto Scaling Flow

```
High CPU (>75% for 3 minutes)
    │
    ├─ HPA
    │     └─ Deployment replicas +1 (up to maxReplicas)
    │
    └─ Cluster Autoscaler (if pending pods)
          └─ Node Group +1 (up to maxSize)

Low CPU (<30% for 5 minutes)
    │
    ├─ HPA
    │     └─ Deployment replicas -1 (down to minReplicas)
    │
    └─ Cluster Autoscaler (if underutilized nodes)
          └─ Node Group -1 (down to minSize)
```

## Data Flow

### Database (MySQL StatefulSet)
- App → Service (mysql-svc) → MySQL Primary (read/write) → PVC (EBS gp3, 10Gi)
- App → Service (mysql-svc-read) → MySQL Replicas (read-only) → PVC (EBS gp3, 10Gi)
- Tuned parameters: innodb_buffer_pool_size (70% RAM), max_connections (200), query_cache_type (0)

### File Storage (PVC + CSI)
- PVC dynamically provisioned via StorageClass (EBS CSI / EFS CSI)
- Access modes: ReadWriteOnce (EBS) or ReadWriteMany (EFS)
- Backup: Velero scheduled backup to S3 (daily + monthly)

### Logging
- Container stdout/stderr → Promtail (DaemonSet) → Loki
- Retention: 7 days (hot) / 30 days (cold via S3)
- Grafana dashboard for log exploration

### Metrics
- kube-state-metrics + node-exporter → Prometheus
- Application custom metrics → Prometheus (via Prometheus client lib)
- Grafana dashboards: Kubernetes cluster, Node, Pod, Application

## Security

| Component | Measure |
|-----------|---------|
| **Cluster** | EKS with private endpoint (or kubeadm with RBAC), OIDC + IRSA |
| **Network** | Default-deny NetworkPolicy, allow specific ingress/egress |
| **Secrets** | Sealed Secrets (encrypted at rest in git), External Secrets Operator |
| **Container** | Non-root user, read-only root filesystem, resource limits |
| **Image** | Signed images (cosign), vulnerability scanning (trivy) |
| **RBAC** | Least privilege, dedicated ServiceAccount per app, RoleBindings |
| **Pod Security** | Pod Security Standards (restricted profile) or OPA/Gatekeeper |
| **TLS** | cert-manager with Let's Encrypt / internal CA, auto-renewal |
