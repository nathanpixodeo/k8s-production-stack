# Detailed Layer Walkthrough

## 1. Cluster Layer

**Role:** Provisions the Kubernetes control plane and worker nodes with networking infrastructure.

**Provisioning options:**
- **AWS EKS** (recommended for AWS): eksctl manifest + CloudFormation
- **Kubeadm** (on-prem / bare-metal): Ansible playbooks
- **K3s** (lightweight / edge): Single binary + config file

**Steps (EKS):**
1. Create VPC with CIDR `10.0.0.0/16`
   - 2 Public Subnets (`10.0.0.0/24`, `10.0.1.0/24`) for load balancers
   - 2 Private Subnets (`10.0.2.0/24`, `10.0.3.0/24`) for workloads
   - Internet Gateway + NAT Gateways per AZ
2. Create EKS Control Plane (Fargate / managed)
   - Control plane in VPC, multi-AZ, private endpoint enabled
   - OIDC provider for IRSA
   - Cluster encryption with KMS
3. Create Managed Node Groups:
   - **On-Demand group** (critical workloads, 1-5 nodes)
   - **Spot group** (stateless workloads, 1-20 nodes, with `topologySpreadConstraints`)
   - Launch template: AL2023 EKS-optimized AMI, gp3 root volume, IMDSv2

**IAM:**
- Cluster role (EKS service)
- Node role (EC2 → ECR, CloudWatch, EBS CSI)
- IRSA roles per workload (S3, DynamoDB, etc.)

**Outputs:** VPCId, PublicSubnets, PrivateSubnets, ClusterEndpoint, OIDCProvider, NodeGroupARNs

---

## 2. Networking Layer

**Role:** Manages traffic routing, TLS termination, and DNS resolution inside the cluster.

### 2.1 Ingress-NGINX Controller

**Purpose:** Acts as the entry point for all HTTP/HTTPS traffic from outside the cluster.

**Installation:** Helm chart from ingress-nginx repo.

**Configuration:**
```yaml
controller:
  kind: DaemonSet          # one per node for hostNetwork
  service:
    type: LoadBalancer     # provision AWS NLB
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
      service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
  config:
    ssl-redirect: "true"
    use-proxy-protocol: "true"
    hsts: "true"
    hsts-max-age: "31536000"
```

**Flow:** Internet → NLB (Layer 4) → NGINX (Layer 7, TLS) → Service → Pods

### 2.2 cert-manager

**Purpose:** Automates TLS certificate provisioning and renewal.

**Installation:** Helm chart from jetstack repo.

**Resources created:**
- `ClusterIssuer` (Let's Encrypt production)
- `Certificate` for each ingress (auto-renewal 30 days before expiry)

**Annotations used by Ingress:**
```yaml
cert-manager.io/cluster-issuer: letsencrypt-prod
kubernetes.io/tls-acme: "true"
```

**Flow:** cert-manager → ACME challenge (HTTP-01 / DNS-01) → Let's Encrypt → Secret (tls) → Ingress

### 2.3 CoreDNS

**Purpose:** Provides internal DNS resolution for Services (built-in with most clusters).

**Configuration:**
- Custom domain: `cluster.local`
- Forward external queries to VPC DNS resolver
- Autoscaling based on cluster size

---

## 3. Storage Layer

**Role:** Provides dynamic persistent volume provisioning with proper performance and encryption.

**Components:**
1. **CSI Driver** (EBS CSI / EFS CSI / Rook-Ceph)
2. **StorageClass** definitions
3. **VolumeSnapshotClass** (for backup)

### 3.1 StorageClass Configuration

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer  # schedule pod first, then provision in same AZ
parameters:
  type: gp3
  encrypted: "true"
  iops: "3000"            # baseline gp3 IOPS
  throughput: "125"       # baseline gp3 throughput (MB/s)
reclaimPolicy: Delete     # auto-delete PV on PVC deletion
allowVolumeExpansion: true
```

**Usage:**
- **Stateful workloads** (MySQL, Redis): `spec.storageClassName: gp3` with `ReadWriteOnce`
- **Shared files** (CMS uploads, logs): EFS CSI with `ReadWriteMany`
- **Temporary data** (CI artifacts): `ephemeral` volumes or `EmptyDir`

---

## 4. Data Layer

**Role:** Runs stateful workloads with high availability and data persistence.

### 4.1 MySQL StatefulSet

**Purpose:** Relational database for application data.

**Architecture:**
- 3 pods: 1 Primary (read/write) + 2 Replicas (read-only)
- Headless Service for stable DNS names
- Each pod has its own PVC (10Gi gp3)
- Semi-sync replication (orchestrated via ConfigMap scripts)

**Tuning (ConfigMap):**
```ini
[mysqld]
innodb_buffer_pool_size = 70% of RAM
innodb_log_file_size = 512M
max_connections = 200
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
```

**Flow:**
```
App → mysql-svc:3306 → Primary (write) → PVC
                      → Replicas (read) → PVC
```

### 4.2 Redis (Optional)

**Purpose:** Caching, session store, rate limiting.

**Architecture:**
- 3-pod Redis Sentinel (or Redis Cluster for HA)
- Headless Service
- PVC with small gp3 volume (1Gi)
- AOF persistence enabled

### 4.3 External Database Service

**Purpose:** Connect to managed database (RDS, Cloud SQL, etc.) instead of in-cluster MySQL.

**Configuration:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-external
spec:
  type: ExternalName
  externalName: myapp.xxxxxxxxxxxx.region.rds.amazonaws.com
---
kind: EndpointSlice
# ... points to RDS endpoint IP
```

---

## 5. Application Layer

**Role:** Runs the actual application workload with proper configuration, scaling, and health management.

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
# Secrets should be stored as SealedSecrets (see Security Layer)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: myapp-secrets
  namespace: myapp
spec:
  encryptedData:
    DB_PASSWORD: <encrypted-with-kubeseal>
```

### 5.3 Deployment

**Key configurations:**
- **Resource requests/limits** - Guarantee QoS class, avoid resource starvation
- **Readiness + Liveness probes** - Traffic routing + self-healing
- **Pod Anti-Affinity** - Spread pods across nodes/AZs
- **Topology Spread Constraints** - Even distribution
- **Pod Disruption Budget** - Minimum available during voluntary disruptions
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

## 6. Security Layer

**Role:** Enforces security boundaries, least privilege access, and secret management.

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

**Purpose:** Encrypt Kubernetes Secrets so they can be safely stored in git.

**Workflow:**
1. Developer creates a Secret yaml
2. Runs `kubeseal` → produces SealedSecret (encrypted, safe for git)
3. Commits SealedSecret to repo
4. ArgoCD applies SealedSecret → controller decrypts → creates regular Secret

---

## 7. Monitoring Layer

**Role:** Provides observability into cluster health, application metrics, and logs.

### 7.1 Prometheus + Grafana

**Installation:** kube-prometheus-stack Helm chart.

**Components:**
- **Prometheus** - Metrics storage, alert evaluation
- **Grafana** - Dashboards + alerting UI
- **AlertManager** - Alert routing (Slack, PagerDuty, email)
- **kube-state-metrics** - Cluster object metrics
- **node-exporter** - Node-level metrics (CPU, memory, disk, network)

**Application monitoring:**
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
  - port: metrics       # must match Service port name
    interval: 15s
    path: /metrics
```

### 7.2 Loki (Logging)

**Installation:** Loki Helm chart with Grafana datasource.

**Components:**
- **Loki** - Log aggregation (similar to Prometheus but for logs)
- **Promtail** - DaemonSet, collects logs from `/var/log/pods/*`
- **Grafana** - Explore logs UI

---

## 8. Backup Layer (Velero)

**Role:** Backup and restore Kubernetes resources and persistent volumes.

**Installation:** Velero Helm chart with AWS S3 plugin.

**Configuration:**
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
      ttl: 720h   # 30 days
      includedNamespaces:
      - myapp
```

---

## 9. GitOps Layer (ArgoCD)

**Role:** Declarative, version-controlled application deployment with automated sync and self-healing.

**Installation:** ArgoCD Helm chart with HA configuration.

**Key Features:**
- **Auto-sync** - Automatically apply changes from git
- **Self-heal** - Revert manual changes to match git state
- **Prune** - Delete resources removed from git
- **ApplicationSet** - Generate apps per environment/cluster
- **Sync waves** - Order resource creation (CRDs first, then workloads)

**ApplicationSet example:**
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

## Deployment order summary

```
1. Cluster + VPC (eksctl / kubeadm)
2. StorageClass (CSI driver)
3. Ingress-NGINX + cert-manager
4. Monitoring (Prometheus, Grafana, Loki)
5. Security (Sealed Secrets, NetworkPolicies, RBAC)
6. Data Layer (MySQL, Redis)
7. Application (Namespace, ConfigMap, Deployment, Service, Ingress, HPA)
8. Backup (Velero)
9. GitOps (ArgoCD)
```

## Zero-downtime deployment flow

```
1. HPA scales up new replica
2. RollingUpdate starts new pod
3. Readiness probe passes → new pod added to Service
4. Old pod continues serving until new pod is Ready
5. Old pod receives SIGTERM → preStop hook drains connections
6. Old pod terminates
7. Repeat until all pods replaced
```

## Disaster recovery flow

```
1. velero backup create --include-namespaces myapp --ttl 720h
2. (Disaster occurs)
3. Deploy new cluster (eksctl)
4. velero restore create --from-backup <backup-name>
5. Restore includes: PVs (snapshots), Deployments, Services, Ingresses, ConfigMaps, Secrets
6. Verify application health
7. Update DNS to new Ingress LB
```
