# Kiến trúc tổng quan

## Mục tiêu

Triển khai ứng dụng production-grade lên Kubernetes với khả năng:
- **Chịu tải** - HPA (Horizontal Pod Autoscaler) + Cluster Autoscaler
- **Sẵn sàng cao** - Node groups đa AZ, pod anti-affinity, rolling updates
- **Bảo mật** - Network Policies, RBAC, Sealed Secrets, OPA/Gatekeeper
- **Quan sát** - Prometheus + Grafana (metrics), Loki (logs), AlertManager
- **Phục hồi thảm hoạ** - Velero backup (PV + tài nguyên cluster), etcd snapshots

## Kiến trúc phân tầng

```
┌──────────────────────────────────────────────────────────────┐
│                   GitOps (ArgoCD / Flux)                      │
│            Khai báo, phiên bản hoá, tự phục hồi               │
├──────────────────────────────────────────────────────────────┤
│                   Tầng Bảo mật                                │
│   Network Policies · RBAC · Sealed Secrets · OPA/Gatekeeper  │
├──────────────────────────────────────────────────────────────┤
│                   Tầng Ứng dụng                               │
│   Deployments · Services · Ingresses · HPAs · ConfigMaps     │
├──────────────────────────────────────────────────────────────┤
│                   Tầng Dữ liệu                                │
│   MySQL (StatefulSet) · Redis (StatefulSet) · PVC + CSI      │
├──────────────────────────────────────────────────────────────┤
│                   Tầng Lưu trữ                                │
│   StorageClass (gp3 / EBS CSI) · PVC tự động cấp phát        │
├──────────────────────────────────────────────────────────────┤
│                   Tầng Mạng                                   │
│   Ingress-NGINX · cert-manager · CoreDNS · MetalLB (on-prem) │
├──────────────────────────────────────────────────────────────┤
│                   Tầng Cluster                                │
│   EKS / Kubeadm / K3s · Managed Node Groups · VPC · Subnets  │
├──────────────────────────────────────────────────────────────┤
│                   Tầng Hạ tầng                                │
│   AWS Account / On-Prem · IAM · Route53 · ACM · S3 backend   │
└──────────────────────────────────────────────────────────────┘
```

## Luồng request

### 1. User truy cập ứng dụng

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
    ├─ App container xử lý request
    ├─ Đọc/ghi session → Redis (nếu có)
    ├─ Đọc/ghi dữ liệu → MySQL (StatefulSet)
    ├─ Đọc/ghi file → PVC (EBS / EFS CSI)
    └─ Logs → stdout → Loki → Grafana
```

### 2. Luồng deploy stack

```
Admin apply Kustomize / Helm / ArgoCD
    │
    ▼
── Tầng Cluster
│     ├─ VPC + Subnets + Internet/NAT Gateways
│     ├─ EKS Control Plane (hoặc kubeadm control plane)
│     ├─ Managed Node Groups (đa AZ, on-demand + spot)
│     └─ OIDC Provider + IAM Roles for Service Accounts (IRSA)
│
── Tầng Mạng (phụ thuộc Cluster)
│     ├─ Ingress-NGINX Controller (DaemonSet / Deployment)
│     ├─ cert-manager (Issuers, Certificates)
│     └─ CoreDNS (DNS nội bộ)
│
── Tầng Lưu trữ (phụ thuộc Cluster)
│     ├─ CSI Driver (EBS / EFS / RBD)
│     ├─ StorageClass (gp3, mã hoá, reclaim: Delete)
│     └─ Default PVC template
│
── Tầng Dữ liệu (phụ thuộc Storage)
│     ├─ MySQL StatefulSet (3 bản sao, sync replication)
│     │   ├─ Headless Service
│     │   ├─ PVC template (10Gi mỗi pod)
│     │   └─ ConfigMap (my.cnf tinh chỉnh)
│     ├─ Redis StatefulSet (HA với sentinel / cluster)
│     └── External Service (nếu dùng managed DB như RDS)
│
── Tầng Ứng dụng (phụ thuộc Mạng, Dữ liệu)
│     ├─ Namespace
│     ├─ ConfigMap / Secret (SealedSecret)
│     ├─ Deployment (có resource limits, probes, anti-affinity)
│     ├─ Service (ClusterIP)
│     ├─ Ingress (với cert-manager annotation)
│     └─ HPA (scale theo CPU + memory)
│
── Tầng Bảo mật (xuyên suốt)
│     ├─ NetworkPolicy (default-deny, allow-app-ingress)
│     ├─ RBAC (Roles, RoleBindings, ServiceAccounts)
│     └─ Sealed Secrets / External Secrets Operator
│
── Tầng Giám sát (phụ thuộc Cluster)
│     ├─ kube-prometheus-stack (Prometheus + Grafana)
│     │   ├─ ServiceMonitor cho app metrics
│     │   ├─ PodMonitor cho custom metrics
│     │   └─ AlertManager (Slack, PagerDuty)
│     └─ Loki Stack (Loki + Promtail + Grafana)
│
── Tầng Backup (phụ thuộc Storage)
│     ├─ Velero (backup PVs + tài nguyên lên S3)
│     ├─ Lịch trình (hàng ngày, giữ 30 ngày)
│     └─ Restore演练
│
── Tầng GitOps (xuyên suốt)
      ├─ ArgoCD / Flux
      ├─ ApplicationSet (đa môi trường, đa cluster)
      └─ Sync policies (auto-sync, prune, self-heal)
```

## Luồng Auto Scaling

```
CPU cao (>75% trong 3 phút)
    │
    ├─ HPA
    │     └─ Deployment replicas +1 (tối đa maxReplicas)
    │
    └─ Cluster Autoscaler (nếu có pod pending)
          └─ Node Group +1 (tối đa maxSize)

CPU thấp (<30% trong 5 phút)
    │
    ├─ HPA
    │     └─ Deployment replicas -1 (tối thiểu minReplicas)
    │
    └─ Cluster Autoscaler (nếu node dùng ít tài nguyên)
          └─ Node Group -1 (tối thiểu minSize)
```

## Luồng dữ liệu

### Database (MySQL StatefulSet)
- App → Service (mysql-svc) → MySQL Primary (read/write) → PVC (EBS gp3, 10Gi)
- App → Service (mysql-svc-read) → MySQL Replicas (read-only) → PVC (EBS gp3, 10Gi)
- Thông số tinh chỉnh: innodb_buffer_pool_size (70% RAM), max_connections (200), query_cache_type (0)

### File storage (PVC + CSI)
- PVC được cấp phát động qua StorageClass (EBS CSI / EFS CSI)
- Access modes: ReadWriteOnce (EBS) hoặc ReadWriteMany (EFS)
- Backup: Velero scheduled backup lên S3 (hàng ngày + hàng tháng)

### Logging
- Container stdout/stderr → Promtail (DaemonSet) → Loki
- Retention: 7 ngày (hot) / 30 ngày (cold qua S3)
- Dashboard Grafana để tra cứu log

### Metrics
- kube-state-metrics + node-exporter → Prometheus
- Application custom metrics → Prometheus (qua Prometheus client lib)
- Grafana dashboards: Kubernetes cluster, Node, Pod, Application

## Bảo mật

| Thành phần | Biện pháp |
|------------|-----------|
| **Cluster** | EKS private endpoint (hoặc kubeadm RBAC), OIDC + IRSA |
| **Mạng** | Default-deny NetworkPolicy, chỉ cho phép ingress/egress cụ thể |
| **Secrets** | Sealed Secrets (mã hoá trong git), External Secrets Operator |
| **Container** | Non-root user, read-only root filesystem, resource limits |
| **Image** | Signed images (cosign), quét lỗ hổng (trivy) |
| **RBAC** | Least privilege, ServiceAccount riêng cho từng app |
| **Pod Security** | Pod Security Standards (restricted profile) hoặc OPA/Gatekeeper |
| **TLS** | cert-manager với Let's Encrypt / internal CA, tự động gia hạn |
