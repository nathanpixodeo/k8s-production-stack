#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NAMESPACE="${NAMESPACE:-myapp}"

echo "==> k8s-production-stack deploy"
echo ""

# 1. Cluster (skip if already exists)
if ! eksctl get cluster --name production-cluster &>/dev/null; then
  echo "[1/9] Creating EKS cluster..."
  eksctl create cluster -f "${ROOT_DIR}/clusters/eksctl-cluster.yaml"
else
  echo "[1/9] EKS cluster already exists, skipping..."
fi

# 2. Storage
echo "[2/9] Installing StorageClass..."
kubectl apply -k "${ROOT_DIR}/storage/"

# 3. Networking
echo "[3/9] Installing Networking (Ingress-NGINX + cert-manager)..."
kubectl apply -k "${ROOT_DIR}/networking/"

# 4. Security
echo "[4/9] Installing Security (NetworkPolicies, RBAC, Sealed Secrets)..."
kubectl apply -k "${ROOT_DIR}/security/"

# 5. Monitoring
echo "[5/9] Installing Monitoring (Prometheus + Grafana + Loki)..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -k "${ROOT_DIR}/monitoring/"

# 6. Database
echo "[6/9] Installing Database (MySQL)..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -k "${ROOT_DIR}/database/"

# 7. Application
echo "[7/9] Deploying Application..."
kubectl apply -k "${ROOT_DIR}/application/"

# 8. Backup
echo "[8/9] Installing Backup (Velero)..."
kubectl apply -k "${ROOT_DIR}/backup/"

# 9. GitOps
echo "[9/9] Installing GitOps (ArgoCD)..."
kubectl apply -k "${ROOT_DIR}/gitops/"

echo ""
echo "==> Deployment complete!"
echo ""
echo "Application:    https://myapp.example.com"
echo "Grafana:        https://grafana.example.com"
echo "ArgoCD:         https://argocd.example.com"
echo ""
echo "Monitor rollout: kubectl rollout status -n ${NAMESPACE} deployment/myapp"
