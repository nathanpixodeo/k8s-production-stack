# Step-by-Step Guide: From Zero to Running Application

This guide walks through everything you need to know to deploy applications using this project. No prior Kubernetes knowledge required — we explain every command.

## Before You Start: Tools You Need

Install these tools on your laptop/computer. You only need to do this once.

### 1. Git

Git is how you download (clone) this project.

**Check if already installed:**
```bash
git --version
```
If you see something like `git version 2.x.x`, you already have it.

**Install:**
- **Ubuntu/Debian**: `sudo apt install git -y`
- **macOS**: `brew install git` or download from https://git-scm.com
- **Windows**: Download from https://git-scm.com

### 2. AWS CLI

This lets your computer talk to Amazon Web Services (AWS).

**Install:**
```bash
# Linux:
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# macOS:
brew install awscli

# Windows: Download from https://aws.amazon.com/cli/
```

**Configure with your AWS account:**
```bash
aws configure
```
You'll need your AWS Access Key ID and Secret Access Key from the AWS Console (IAM > Users > Your User > Security Credentials).

### 3. eksctl

This tool creates Kubernetes clusters on AWS.

**Install:**
```bash
# Linux (x86_64):
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz"
tar -xzf eksctl_Linux_amd64.tar.gz
sudo mv eksctl /usr/local/bin/

# macOS:
brew install eksctl

# Windows: Download from eksctl.io
```

**Verify:**
```bash
eksctl version
```

### 4. kubectl

This is the main tool for controlling Kubernetes. You'll use it a lot.

**Install:**
```bash
# Linux:
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# macOS:
brew install kubectl

# Windows: Download from https://kubernetes.io/docs/tasks/tools/
```

**Verify:**
```bash
kubectl version --client
```

### 5. Helm

Helm is a "package manager" for Kubernetes — it helps install complex software easily.

**Install:**
```bash
# Linux:
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod +x get_helm.sh
./get_helm.sh

# macOS:
brew install helm

# Windows: choco install kubernetes-helm
```

**Verify:**
```bash
helm version
```

### 6. kustomize

Kustomize helps customize Kubernetes configurations (already built into kubectl).

**Verify:**
```bash
kubectl kustomize --help
```
If this works, you're all set.

---

## Step 1: Clone This Project

Download the project files to your computer.

```bash
git clone https://github.com/nathanpixodeo/k8s-production-stack.git
cd k8s-production-stack
```

**What just happened?**
- `git clone` downloaded all files to a folder called `k8s-production-stack`
- `cd` moves you into that folder

**Check what you downloaded:**
```bash
ls -la
```
You should see folders like `clusters/`, `database/`, `application/`, etc.

---

## Step 2: Create the Kubernetes Cluster

This is the biggest step. It creates the actual servers (called nodes) on AWS.

```bash
eksctl create cluster -f clusters/eksctl-cluster.yaml
```

**What this does:**
- Reads the file `clusters/eksctl-cluster.yaml` — our blueprint
- Creates a VPC (private network) with public and private subnets
- Creates a Kubernetes control plane (the "brain" of the cluster)
- Creates server instances (EC2) — 2 on-demand + spot instances
- Configures networking so everything can talk to each other

**This takes 15-25 minutes.** Go grab a coffee.

**How to check progress:**
```bash
eksctl get cluster
```

**After it finishes, verify:**
```bash
kubectl get nodes
```
You should see something like:
```
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-0-2-xxx.ec2.internal   Ready    <none>   5m   v1.31
ip-10-0-3-xxx.ec2.internal   Ready    <none>   5m   v1.31
```

**Understanding this output:**
- `NAME`: The internal name of each server
- `STATUS: Ready`: The server is ready to run applications
- You have 2 servers (nodes) in different availability zones

**What is kubectl doing?**
`kubectl` (say "kube-control") is like a remote control for your cluster. Every time you run `kubectl`, it:
1. Reads from `~/.kube/config` (created by eksctl) to find your cluster
2. Sends commands to the cluster's control plane
3. Returns the result

You don't need to worry about how this works — just remember that `kubectl` is how you talk to your cluster.

---

## Step 3: Configure Storage

Your applications need hard drives. This step sets up the hard drive system.

```bash
kubectl apply -k storage/
```

**What this does:**
- `kubectl apply` means "create or update these resources"
- `-k storage/` means "read the kustomization.yaml in the storage folder"

**What gets created:**
- A **StorageClass** called `gp3` — this is the "type of hard drive" (fast SSD)
- It becomes the default, so any app that asks for storage automatically gets this fast SSD
- A **VolumeSnapshotClass** — this allows creating point-in-time backups of volumes

**Verify:**
```bash
kubectl get storageclass
```
You should see:
```
NAME   PROVISIONER       RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION
gp3    ebs.csi.aws.com   Delete          WaitForFirstConsumer true
```

---

## Step 4: Install Networking (The Front Door)

This installs the system that handles internet traffic to your applications.

```bash
kubectl apply -k networking/
```

**What gets created:**

### Ingress-NGINX (The Main Door)
- An **Ingress Controller** — think of it as a smart router that sits at the front of your cluster
- It creates an **AWS Network Load Balancer (NLB)** — a real AWS load balancer
- All internet traffic comes through this load balancer first
- It handles: HTTPS encryption, routing traffic to the right service, rate limiting

### cert-manager (The Automatic Key Maker)
- Automatically gets free **TLS/SSL certificates** from Let's Encrypt
- These certificates enable HTTPS (the green padlock in browsers)
- It automatically renews certificates before they expire (every 90 days)

**Verify:**
```bash
# Check if the ingress controller pod is running
kubectl get pods -n ingress-nginx

# Should show something like:
# NAME                                       READY   STATUS    RESTARTS   AGE
# ingress-nginx-controller-xxxxx            1/1     Running   0          2m

# Check if cert-manager pods are running
kubectl get pods -n cert-manager
```

**Finding your load balancer URL:**
```bash
kubectl get svc -n ingress-nginx
```
Look for the `EXTERNAL-IP` column. This is the DNS name of your load balancer. You'll need this later to create a custom domain.

---

## Step 5: Install Monitoring (The Dashboard)

This installs Prometheus (metrics collector) and Grafana (visual dashboards).

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -k monitoring/
```

**What gets created:**
- **Prometheus**: Collects metrics from every pod, service, and node
- **Grafana**: Shows beautiful dashboards (CPU, memory, request rates, etc.)
- **AlertManager**: Sends alerts if something goes wrong
- **Loki + Promtail**: Collects and stores logs from all containers
- **kube-state-metrics**: Gets information about Kubernetes objects
- **node-exporter**: Gets metrics from each server (disk, network, etc.)

**Access Grafana:**
```bash
kubectl get ingress -n monitoring
```
Look for the Grafana ingress host, or:
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```
Then open http://localhost:3000 in your browser.

**Default login:** admin / prom-operator (unless you changed it)

**Wait for everything to be ready:**
```bash
kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=300s
```

---

## Step 6: Install Security (Firewalls + Access Control)

This sets up network firewalls and access controls.

```bash
kubectl apply -k security/
```

**What gets created:**

### Network Policies (Firewalls)
- **Default-deny**: By default, nothing can talk to anything. It's like locking all doors.
- **Allow rules**: Specific doors are unlocked for specific traffic:
  - Ingress controller can talk to application pods
  - Application pods can talk to the database
  - Application pods can access DNS (to resolve domain names)

### RBAC (Access Control)
- A **ServiceAccount** named `myapp-sa` — like a "service badge" for your app
- A **Role** that gives limited permissions (read configmaps, secrets)
- A **RoleBinding** that attaches the role to the service account

### Sealed Secrets
- Installs the Sealed Secrets controller
- Allows you to encrypt secrets so they can be safely stored in Git

**Verify:**
```bash
kubectl get networkpolicies -n myapp
kubectl get serviceaccount -n myapp
```

---

## Step 7: Install Database

Choose your database engine. The default is MySQL.

```bash
# For MySQL (default):
kubectl apply -k database/

# For PostgreSQL (needed for fullstack setup):
# First edit database/kustomization.yaml, then:
# kubectl apply -k database/postgresql/
```

**What gets created:**
- A **StatefulSet** with 3 database replicas (1 primary + 2 replicas)
- The primary handles all writes
- Replicas handle reads (spreading the load)
- Each replica gets its own **PersistentVolumeClaim** (10GB SSD)
- A **Headless Service** for stable network identities
- A **ConfigMap** with the tuned database configuration
- A **Secret** with the database password

**What is a StatefulSet?**
Unlike a regular Deployment (where pods are interchangeable), a StatefulSet gives each pod a stable identity. Database pods need this because:
- `mysql-0` is always the primary (writes go here)
- `mysql-1` and `mysql-2` are always replicas
- When they restart, they keep the same identity and the same storage

**Verify:**
```bash
# Check the pods are starting
kubectl get pods -n myapp -w

# Eventually you should see:
# NAME        READY   STATUS    RESTARTS   AGE
# mysql-0     1/1     Running   0          3m
# mysql-1     1/1     Running   0          2m
# mysql-2     1/1     Running   0          1m

# Check the services
kubectl get svc -n myapp
# You should see: database-svc, database-svc-read, database-headless
```

---

## Step 8: Deploy Your Application

Choose how you want to deploy:

### Option A: Generic Application

```bash
kubectl apply -k application/
```

Creates a simple web application deployment.

### Option B: Laravel API

```bash
kubectl apply -k frameworks/laravel/
```

Creates:
- PHP-FPM container running Laravel
- Nginx container as reverse proxy
- Horizon queue worker
- Schedule runner CronJob

### Option C: React Frontend

```bash
kubectl apply -k frameworks/react/
```

Creates:
- Nginx container serving built React files
- An HPA to handle variable traffic

### Option D: Fullstack (Laravel + React + PostgreSQL) — Recommended

```bash
# First make sure PostgreSQL is deployed:
kubectl apply -k database/postgresql/

# Then deploy the fullstack:
kubectl apply -k frameworks/fullstack/
```

Creates everything in one go:
- PostgreSQL database
- Laravel API backend with Horizon
- React frontend with Nginx
- A unified Ingress that routes:
  - `/api/*` → Laravel
  - `/storage/*` → Laravel
  - `/horizon/*` → Laravel
  - `/*` → React SPA

**Important: You must build your Docker images first.**

This project expects you to have built and pushed your application images to a container registry (like Docker Hub or Amazon ECR).

For Laravel, build your image:
```dockerfile
# Example Dockerfile for Laravel
FROM php:8.3-fpm-alpine
RUN docker-php-ext-install pdo pdo_pgsql
COPY . /var/www/html
WORKDIR /var/www/html
```

For React, build your image:
```dockerfile
# Example Dockerfile for React
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=builder /app/build /usr/share/nginx/html
```

Then update the image name in the deployment files.

**Verify:**
```bash
kubectl get pods -n myapp -w
kubectl get ingress -n myapp
kubectl get svc -n myapp
```

---

## Step 9: Install Backups

```bash
kubectl apply -k backup/
```

This installs **Velero** — a backup tool that:
- Takes daily snapshots of your database and application data
- Stores them in AWS S3 cloud storage
- Keeps daily backups for 30 days
- Keeps monthly backups for 90 days

**Important:** Before running this, edit `backup/velero/values.yaml` and set:
- Your AWS S3 bucket name
- Your AWS access key and secret key (for backup storage)

---

## Step 10: Install GitOps (Optional)

```bash
kubectl apply -k gitops/
```

This installs **ArgoCD** — a tool that:
- Watches your Git repository for changes
- Automatically applies those changes to your cluster
- Shows you a nice UI with all your applications
- Rolls back changes if something goes wrong

---

## How to Access Your Application

### 1. Find the Load Balancer URL

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

This gives you a DNS name like `xxxxxxxxxxxxx-xxxx.elb.amazonaws.com`.

### 2. Set Up a Custom Domain (Optional but Recommended)

In your DNS provider (Route53, Cloudflare, etc.):
1. Create a CNAME record pointing `myapp.example.com` → the load balancer URL above
2. The cert-manager will automatically get an HTTPS certificate for your domain

### 3. Check the Application

```bash
# Get all ingress URLs
kubectl get ingress -A
```

---

## How to Destroy Everything

**WARNING:** This deletes everything permanently, including the database.

```bash
# Option 1: Using the script
./scripts/destroy.sh

# Option 2: Manual
kubectl delete -k frameworks/fullstack/
kubectl delete -k database/
kubectl delete pv --all
eksctl delete cluster -f clusters/eksctl-cluster.yaml
```

---

## Common Commands Cheat Sheet

| If you want to... | Run this command |
|-------------------|------------------|
| See all running pods | `kubectl get pods -A` |
| See pod details | `kubectl describe pod <name> -n <namespace>` |
| See app logs | `kubectl logs -n myapp -l app=laravel` |
| Follow logs live | `kubectl logs -n myapp -l app=laravel -f` |
| Run a command in a pod | `kubectl exec -n myapp deploy/laravel -- php artisan list` |
| See services | `kubectl get svc -A` |
| See ingresses | `kubectl get ingress -A` |
| See all resources | `kubectl get all -n myapp` |
| Edit a deployment | `kubectl edit deployment laravel -n myapp` |
| Restart a deployment | `kubectl rollout restart deployment laravel -n myapp` |
| See deployment status | `kubectl rollout status deployment laravel -n myapp` |
| Port-forward to a service | `kubectl port-forward -n myapp svc/laravel-svc 8080:80` |
| Open a shell in a pod | `kubectl exec -n myapp -it deploy/laravel -- /bin/sh` |

---

## Troubleshooting

### Pod stuck in "Pending" state
This usually means there aren't enough resources. Check:
```bash
kubectl describe pod <name> -n <namespace>
```
Look for "Insufficient CPU" or "Insufficient memory" messages.

### Pod stuck in "CrashLoopBackOff"
The app keeps crashing. Check the logs:
```bash
kubectl logs -n myapp <pod-name> --previous
```

### Can't connect to the app
Make sure the ingress is configured:
```bash
kubectl get ingress -A
kubectl describe ingress -n myapp
```

### Database won't start
Check if the PVC is created:
```bash
kubectl get pvc -n myapp
```

If it's stuck in "Pending", there might be a StorageClass issue:
```bash
kubectl describe pvc -n myapp
```

## Glossary of Terms

| Term | Meaning | Analogy |
|------|---------|---------|
| **Cluster** | The entire Kubernetes system (servers + control plane) | The restaurant building |
| **Node** | One server machine in the cluster | One kitchen |
| **Pod** | The smallest unit in K8s — one or more containers | One chef |
| **Deployment** | Manages a group of identical pods | The head chef |
| **Service** | A stable network endpoint for a set of pods | The waiter |
| **Ingress** | The entry point for external traffic | The front door |
| **Namespace** | A way to organize resources (like folders) | A section of the restaurant |
| **ConfigMap** | Stores configuration (not secret) | A recipe card |
| **Secret** | Stores sensitive data (passwords, keys) | A safe combination |
| **PVC** | Request for storage | Ordering a new shelf |
| **PV** | The actual storage allocated | The shelf itself |
| **StatefulSet** | Like Deployment but with stable identities | Assigned seating |
| **HPA** | Auto-scaling based on CPU/memory | Hiring temps during rush hour |
| **PDB** | Minimum pods during disruptions | Minimum staff rule |
| **RBAC** | Access control system | Security badges |
| **NetworkPolicy** | Firewall rules | Door locks |
