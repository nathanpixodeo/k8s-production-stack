# Chi tiết từng tầng

## 1. Tầng Cluster

**Vai trò:** Cung cấp Kubernetes control plane và worker nodes cùng hạ tầng mạng.

**Các lựa chọn cấp phát:**
- **AWS EKS** (khuyến nghị cho AWS): eksctl manifest + CloudFormation
- **Kubeadm** (on-prem / bare-metal): Playbooks Ansible
- **K3s** (nhẹ / edge): Binary đơn + file cấu hình

**Các bước (EKS):**
1. Tạo VPC với CIDR `10.0.0.0/16`
   - 2 Public Subnet (`10.0.0.0/24`, `10.0.1.0/24`) cho load balancer
   - 2 Private Subnet (`10.0.2.0/24`, `10.0.3.0/24`) cho workloads
   - Internet Gateway + NAT Gateway mỗi AZ
2. Tạo EKS Control Plane (Fargate / managed)
   - Control plane trong VPC, đa AZ, private endpoint
   - OIDC provider cho IRSA
   - Mã hoá cluster với KMS
3. Tạo Managed Node Groups:
   - **On-Demand group** (workloads quan trọng, 1-5 nodes)
   - **Spot group** (stateless workloads, 1-20 nodes, dùng `topologySpreadConstraints`)
   - Launch template: AL2023 EKS-optimized AMI, gp3 root volume, IMDSv2

**IAM:**
- Cluster role (EKS service)
- Node role (EC2 → ECR, CloudWatch, EBS CSI)
- IRSA roles cho từng workload (S3, DynamoDB, etc.)

**Outputs:** VPCId, PublicSubnets, PrivateSubnets, ClusterEndpoint, OIDCProvider, NodeGroupARNs

---

## 2. Tầng Mạng

**Vai trò:** Quản lý định tuyến traffic, TLS termination, và DNS nội bộ trong cluster.

### 2.1 Ingress-NGINX Controller

**Mục đích:** Điểm vào cho tất cả traffic HTTP/HTTPS từ bên ngoài vào cluster.

**Cài đặt:** Helm chart từ ingress-nginx repo.

**Cấu hình:**
```yaml
controller:
  kind: DaemonSet          # mỗi node một pod, dùng hostNetwork
  service:
    type: LoadBalancer     # tạo AWS NLB
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
      service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
  config:
    ssl-redirect: "true"
    use-proxy-protocol: "true"
    hsts: "true"
    hsts-max-age: "31536000"
```

**Luồng:** Internet → NLB (Layer 4) → NGINX (Layer 7, TLS) → Service → Pods

### 2.2 cert-manager

**Mục đích:** Tự động cấp phát và gia hạn chứng chỉ TLS.

**Cài đặt:** Helm chart từ jetstack repo.

**Tài nguyên được tạo:**
- `ClusterIssuer` (Let's Encrypt production)
- `Certificate` cho mỗi ingress (tự gia hạn 30 ngày trước hết hạn)

**Annotations Ingress sử dụng:**
```yaml
cert-manager.io/cluster-issuer: letsencrypt-prod
kubernetes.io/tls-acme: "true"
```

**Luồng:** cert-manager → ACME challenge (HTTP-01 / DNS-01) → Let's Encrypt → Secret (tls) → Ingress

### 2.3 CoreDNS

**Mục đích:** Phân giải DNS nội bộ cho Services (được tích hợp sẵn trong cluster).

**Cấu hình:**
- Domain: `cluster.local`
- Forward truy vấn ngoài đến VPC DNS resolver
- Tự động scale theo kích thước cluster

---

## 3. Tầng Lưu trữ

**Vai trò:** Cung cấp persistent volume động với hiệu năng và mã hoá phù hợp.

**Thành phần:**
1. **CSI Driver** (EBS CSI / EFS CSI / Rook-Ceph)
2. **StorageClass** definitions
3. **VolumeSnapshotClass** (cho backup)

### 3.1 Cấu hình StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer  # schedule pod trước, cấp PV trong cùng AZ
parameters:
  type: gp3
  encrypted: "true"
  iops: "3000"
  throughput: "125"
reclaimPolicy: Delete
allowVolumeExpansion: true
```

**Sử dụng:**
- **Stateful workloads** (MySQL, Redis): `storageClassName: gp3` với `ReadWriteOnce`
- **File chia sẻ** (upload CMS, logs): EFS CSI với `ReadWriteMany`
- **Dữ liệu tạm** (CI artifacts): `ephemeral` volumes hoặc `EmptyDir`

---

## 4. Tầng Dữ liệu

**Vai trò:** Chạy workloads có trạng thái với tính sẵn sàng cao và dữ liệu bền vững.

### 4.1 MySQL StatefulSet

**Mục đích:** Cơ sở dữ liệu quan hệ cho ứng dụng.

**Kiến trúc:**
- 3 pods: 1 Primary (read/write) + 2 Replicas (read-only)
- Headless Service cho DNS ổn định
- Mỗi pod có PVC riêng (10Gi gp3)
- Semi-sync replication

**Tinh chỉnh (ConfigMap):**
```ini
[mysqld]
innodb_buffer_pool_size = 70% RAM
innodb_log_file_size = 512M
max_connections = 200
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
```

**Luồng:**
```
App → mysql-svc:3306 → Primary (write) → PVC
                      → Replicas (read) → PVC
```

### 4.2 Redis (Tuỳ chọn)

**Mục đích:** Cache, session store, rate limiting.

**Kiến trúc:**
- 3-pod Redis Sentinel (hoặc Redis Cluster cho HA)
- Headless Service
- PVC gp3 nhỏ (1Gi)
- Bật AOF persistence

### 4.3 External Database Service

**Mục đích:** Kết nối managed database (RDS, Cloud SQL, v.v.) thay vì MySQL trong cluster.

**Cấu hình:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-external
spec:
  type: ExternalName
  externalName: myapp.xxxxxxxxxxxx.region.rds.amazonaws.com
```

---

## 5. Tầng Ứng dụng

**Vai trò:** Chạy ứng dụng thực tế với cấu hình, scaling, và quản lý health đúng chuẩn.

### 5.1 Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: myapp
```

### 5.2 ConfigMap / Secret

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: myapp
data:
  APP_ENV: production
  APP_DEBUG: "false"
  DB_HOST: mysql-svc
  DB_PORT: "3306"
  DB_NAME: myapp
---
# Secrets được lưu dưới dạng SealedSecret
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: myapp-secrets
  namespace: myapp
spec:
  encryptedData:
    DB_PASSWORD: <mã-hoá-bằng-kubeseal>
```

### 5.3 Deployment

**Cấu hình chính:**
- **Resource requests/limits** - QoS class, tránh thiếu tài nguyên
- **Readiness + Liveness probes** - Định tuyến traffic + tự phục hồi
- **Pod Anti-Affinity** - Trải pod khắp các node/AZ
- **Topology Spread Constraints** - Phân phối đều
- **Pod Disruption Budget** - Đảm bảo số pod tối thiểu
- **Graceful shutdown** - `preStop` hook + `terminationGracePeriodSeconds`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: myapp
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: myapp
              topologyKey: topology.kubernetes.io/zone
      containers:
      - name: app
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

### 5.4 Service & Ingress

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-svc
  namespace: myapp
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: myapp
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-svc
            port:
              number: 80
```

### 5.5 HPA (Horizontal Pod Autoscaler)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
  namespace: myapp
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 75
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

## 6. Tầng Bảo mật

**Vai trò:** Thiết lập ranh giới bảo mật, truy cập tối thiểu, và quản lý secret.

### 6.1 Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: myapp
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-controller
  namespace: myapp
spec:
  podSelector:
    matchLabels:
      app: myapp
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
    ports:
    - port: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress-mysql
  namespace: myapp
spec:
  podSelector:
    matchLabels:
      app: myapp
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: mysql
    ports:
    - port: 3306
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - port: 53
```

### 6.2 RBAC

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp-sa
  namespace: myapp
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: myapp
  name: myapp-role
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: myapp-binding
  namespace: myapp
subjects:
- kind: ServiceAccount
  name: myapp-sa
  namespace: myapp
roleRef:
  kind: Role
  name: myapp-role
  apiGroup: rbac.authorization.k8s.io
```

### 6.3 Sealed Secrets

**Mục đích:** Mã hoá Kubernetes Secrets để lưu an toàn trong git.

**Quy trình:**
1. Developer tạo Secret yaml
2. Chạy `kubeseal` → tạo SealedSecret (đã mã hoá, an toàn cho git)
3. Commit SealedSecret lên repo
4. ArgoCD apply SealedSecret → controller giải mã → tạo Secret thường

---

## 7. Tầng Giám sát

**Vai trò:** Cung cấp khả năng quan sát sức khoẻ cluster, metrics ứng dụng, và logs.

### 7.1 Prometheus + Grafana

**Cài đặt:** kube-prometheus-stack Helm chart.

**Thành phần:**
- **Prometheus** - Lưu metrics, đánh giá alert
- **Grafana** - Dashboard + UI cảnh báo
- **AlertManager** - Định tuyến cảnh báo (Slack, PagerDuty, email)
- **kube-state-metrics** - Metrics object cluster
- **node-exporter** - Metrics node (CPU, memory, disk, network)

**Giám sát ứng dụng:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-monitor
  namespace: myapp
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
```

### 7.2 Loki (Logging)

**Cài đặt:** Loki Helm chart với Grafana datasource.

**Thành phần:**
- **Loki** - Tổng hợp log (giống Prometheus nhưng cho log)
- **Promtail** - DaemonSet, thu thập log từ `/var/log/pods/*`
- **Grafana** - Giao diện tra cứu log

---

## 8. Tầng Backup (Velero)

**Vai trò:** Sao lưu và phục hồi tài nguyên Kubernetes và persistent volumes.

**Cài đặt:** Velero Helm chart với AWS S3 plugin.

**Cấu hình:**
```yaml
configuration:
  backupStorageLocation:
  - name: default
    provider: aws
    bucket: myapp-velero-backups
    config:
      region: ca-central-1
  volumeSnapshotLocation:
  - name: default
    provider: aws
    config:
      region: ca-central-1
schedules:
  daily-backup:
    schedule: "0 2 * * *"
    template:
      ttl: 720h   # 30 ngày
      includedNamespaces:
      - myapp
```

---

## 9. Tầng GitOps (ArgoCD)

**Vai trò:** Triển khai ứng dụng theo khai báo, phiên bản hoá, đồng bộ tự động và tự phục hồi.

**Cài đặt:** ArgoCD Helm chart với HA configuration.

**Tính năng chính:**
- **Auto-sync** - Tự động áp dụng thay đổi từ git
- **Self-heal** - Hoàn tác thay đổi thủ công để khớp git
- **Prune** - Xoá tài nguyên đã bị xoá khỏi git
- **ApplicationSet** - Tạo app theo môi trường/cluster
- **Sync waves** - Thứ tự tạo tài nguyên (CRDs trước, workloads sau)

**Ví dụ ApplicationSet:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp
spec:
  generators:
  - list:
      elements:
      - env: staging
        cluster: https://staging-cluster:6443
      - env: production
        cluster: https://production-cluster:6443
  template:
    metadata:
      name: '{{env}}-myapp'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/myapp.git
        targetRevision: HEAD
        path: 'kustomize/overlays/{{env}}'
      destination:
        server: '{{cluster}}'
        namespace: myapp-{{env}}
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
```

---

## Thứ tự triển khai

```
1. Cluster + VPC (eksctl / kubeadm)
2. StorageClass (CSI driver)
3. Ingress-NGINX + cert-manager
4. Giám sát (Prometheus, Grafana, Loki)
5. Bảo mật (Sealed Secrets, NetworkPolicies, RBAC)
6. Tầng Dữ liệu (MySQL, Redis)
7. Ứng dụng (Namespace, ConfigMap, Deployment, Service, Ingress, HPA)
8. Backup (Velero)
9. GitOps (ArgoCD)
```

## Luồng deploy zero-downtime

```
1. HPA scale lên replica mới
2. RollingUpdate tạo pod mới
3. Readiness probe thành công → pod mới vào Service
4. Pod cũ tiếp tục phục vụ đến khi pod mới Ready
5. Pod cũ nhận SIGTERM → preStop hook drain connections
6. Pod cũ kết thúc
7. Lặp lại đến khi tất cả pod được thay thế
```

## Luồng phục hồi thảm hoạ

```
1. velero backup create --include-namespaces myapp --ttl 720h
2. (Thảm hoạ xảy ra)
3. Deploy cluster mới (eksctl)
4. velero restore create --from-backup <tên-backup>
5. Phục hồi gồm: PVs (snapshots), Deployments, Services, Ingresses, ConfigMaps, Secrets
6. Kiểm tra ứng dụng
7. Cập nhật DNS đến Ingress LB mới
```
