# k8s-production-stack Makefile

export NAMESPACE ?= myapp

.PHONY: help deploy destroy install-storage install-networking install-security install-monitoring install-database install-app install-backup install-gitops status logs

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

deploy: ## Deploy the full stack
	@scripts/deploy.sh

destroy: ## Destroy the full stack
	@scripts/destroy.sh

install-storage: ## Install StorageClass only
	kubectl apply -k storage/

install-networking: ## Install Ingress-NGINX + cert-manager
	kubectl apply -k networking/

install-security: ## Install NetworkPolicies, RBAC, Sealed Secrets
	kubectl apply -k security/

install-monitoring: ## Install Prometheus + Grafana + Loki
	kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -k monitoring/

install-database: ## Install MySQL
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -k database/

install-app: ## Deploy application
	kubectl apply -k application/

install-backup: ## Install Velero
	kubectl apply -k backup/

install-gitops: ## Install ArgoCD
	kubectl apply -k gitops/

status: ## Show deployment status
	@echo "=== Cluster ==="
	@kubectl cluster-info --short 2>/dev/null
	@echo ""
	@echo "=== Nodes ==="
	@kubectl get nodes -o wide
	@echo ""
	@echo "=== Pods ==="
	@kubectl get pods --all-namespaces
	@echo ""
	@echo "=== Services ==="
	@kubectl get svc --all-namespaces

logs: ## Tail app logs
	kubectl logs -n $(NAMESPACE) -l app=myapp --tail=100 -f
