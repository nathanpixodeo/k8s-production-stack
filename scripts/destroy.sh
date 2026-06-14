#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NAMESPACE="${NAMESPACE:-myapp}"

echo "==> k8s-production-stack destroy"
echo ""
echo "WARNING: This will delete ALL resources in namespace '${NAMESPACE}' and the EKS cluster."
read -p "Are you sure? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 1
fi

# 1. Delete ArgoCD applications first
echo "[1/6] Deleting ArgoCD applications..."
kubectl delete applications.argoproj.io --all -n argocd 2>/dev/null || true

# 2. Delete monitoring resources
echo "[2/6] Deleting monitoring resources..."
kubectl delete -k "${ROOT_DIR}/monitoring/" 2>/dev/null || true

# 3. Delete application resources
echo "[3/6] Deleting application resources..."
kubectl delete ns "${NAMESPACE}" 2>/dev/null || true

# 4. Delete cluster-wide resources (StorageClass, NetworkPolicies)
echo "[4/6] Deleting cluster-wide resources..."
kubectl delete -k "${ROOT_DIR}/storage/" 2>/dev/null || true
kubectl delete -k "${ROOT_DIR}/networking/" 2>/dev/null || true
kubectl delete -k "${ROOT_DIR}/security/" 2>/dev/null || true
kubectl delete -k "${ROOT_DIR}/backup/" 2>/dev/null || true
kubectl delete -k "${ROOT_DIR}/gitops/" 2>/dev/null || true

# 5. Delete EBS volumes (PVCs might be left behind)
echo "[5/6] Cleaning up PVs..."
kubectl delete pvc --all -n "${NAMESPACE}" 2>/dev/null || true
kubectl delete pv --all 2>/dev/null || true

# 6. Delete cluster
echo "[6/6] Deleting EKS cluster..."
eksctl delete cluster -f "${ROOT_DIR}/clusters/eksctl-cluster.yaml"

echo ""
echo "==> Cleanup complete!"
