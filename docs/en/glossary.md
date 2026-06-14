# Kubernetes Glossary

A simple dictionary of terms used in this project.

## A

**ArgoCD** — A GitOps tool that syncs your Git repository with your Kubernetes cluster. Changes go to Git first, ArgoCD applies them automatically.

**AWS (Amazon Web Services)** — A cloud computing platform. This project runs Kubernetes on AWS using EKS.

**AWS CLI** — Command-line tool to control AWS services from your terminal.

## C

**cert-manager** — A tool that automatically gets and renews TLS/SSL certificates for HTTPS.

**Cluster** — The entire Kubernetes system: all the servers (nodes), the control plane (brain), and everything running on them.

**ClusterIP** — The default type of Service. It gives a private IP that only works inside the cluster.

**ConfigMap** — Stores configuration data (settings) that your application can read. Not for secrets (passwords).

**Container** — A lightweight, standalone package that includes everything needed to run a piece of software.

**Container Registry** — A place where container images are stored (like Docker Hub or Amazon ECR).

**CPU (Central Processing Unit)** — The "brain" of a computer that processes instructions. In K8s, you allocate CPU to containers.

**CRD (Custom Resource Definition)** — An extension to the Kubernetes API that lets you define your own resource types.

**CronJob** — Runs a task on a schedule (like `* * * * *` for every minute).

## D

**DaemonSet** — Ensures that a copy of a pod runs on every node. Used for things like log collectors or network proxies.

**Deployment** — A Kubernetes resource that manages a set of identical pods. It handles updates, scaling, and restarts.

**DNS (Domain Name System)** — The "phonebook" of the internet. It translates domain names (like google.com) to IP addresses.

## E

**EC2 (Elastic Compute Cloud)** — AWS's virtual server service. Each K8s node is an EC2 instance.

**EFS (Elastic File System)** — AWS's shared file storage that multiple servers can access at the same time.

**EKS (Elastic Kubernetes Service)** — AWS's managed Kubernetes service. It runs the control plane for you, so you don't have to.

**eksctl** — A command-line tool for creating and managing EKS clusters.

## G

**Git** — A version control system that tracks changes to files. This entire project is stored in Git.

**GitOps** — A way of managing infrastructure where Git is the single source of truth. Your cluster always matches what's in Git.

**Grafana** — A dashboard tool that visualizes metrics (CPU, memory, request rates) in pretty charts.

## H

**Helm** — A "package manager" for Kubernetes. It bundles related K8s resources into a chart that can be installed with one command.

**HPA (Horizontal Pod Autoscaler)** — Automatically increases or decreases the number of pod replicas based on CPU/memory usage or custom metrics.

**HTTPS** — Encrypted web traffic. The green padlock in your browser.

## I

**Ingress** — A Kubernetes resource that manages external access to services, typically HTTP/HTTPS.

**Ingress Controller** — The actual software (like NGINX) that implements the Ingress rules and handles traffic.

**IRSA (IAM Roles for Service Accounts)** — Allows pods to assume AWS IAM roles to access AWS services (S3, DynamoDB, etc.).

## K

**kubectl** (kube-control) — The main command-line tool to control a Kubernetes cluster.

**Kubernetes (K8s)** — An open-source system for automating deployment, scaling, and management of containerized applications.

**kustomize** — A tool to customize Kubernetes configurations without editing raw YAML files.

## L

**Label** — A key-value pair attached to Kubernetes resources used for selection and organization.

**Liveness Probe** — A health check that tells K8s if a container is alive. If it fails, K8s restarts the container.

**Load Balancer** — Distributes incoming traffic across multiple servers or pods.

**Loki** — A log aggregation system. It collects and stores logs from all containers, searchable through Grafana.

## M

**Manifest** — A YAML file that describes a Kubernetes resource (like a deployment, service, etc.).

**Memory (RAM)** — Short-term memory of a computer. In K8s, you allocate memory to containers.

**Metric** — A measurement value (like CPU usage percentage, request count per second).

**Multi-AZ** — Running resources across multiple Availability Zones (data centers) for high availability.

## N

**Namespace** — A virtual cluster within a physical cluster. Used to organize resources, like folders on your computer.

**Network Policy** — A firewall rule that controls traffic between pods, services, and external endpoints.

**NGINX** — A web server that can also act as a reverse proxy, load balancer, and HTTP cache.

**NLB (Network Load Balancer)** — An AWS load balancer that operates at Layer 4 (TCP/UDP).

**Node** — A worker machine (server) in Kubernetes. Each node runs pods.

## O

**OIDC (OpenID Connect)** — An authentication protocol used by EKS to allow AWS IAM roles to be assumed by Kubernetes service accounts.

## P

**PDB (Pod Disruption Budget)** — A rule that specifies the minimum number of pods that must be available during voluntary disruptions (like node maintenance).

**PersistentVolume (PV)** — A piece of storage in the cluster that has been provisioned by an administrator or dynamically provisioned using StorageClass.

**PersistentVolumeClaim (PVC)** — A request for storage by a pod. Like saying "I need 10GB of fast storage."

**Pod** — The smallest deployable unit in Kubernetes. Contains one or more containers.

**Prometheus** — A monitoring system that collects and stores metrics from applications and infrastructure.

**Promtail** — A log collector that sends logs from nodes to Loki.

## R

**RBAC (Role-Based Access Control)** — A method of regulating access to resources based on the roles of individual users or service accounts.

**Readiness Probe** — A health check that tells K8s if a container is ready to serve traffic.

**Replica** — One copy of a pod. Multiple replicas provide redundancy and handle more traffic.

**Rolling Update** — Gradually replacing old pods with new ones, ensuring zero downtime.

## S

**Sealed Secret** — An encrypted Kubernetes Secret that can be safely stored in Git. Only the Sealed Secrets controller can decrypt it.

**Secret** — Stores sensitive data (passwords, API keys, certificates) in Kubernetes.

**Service** — An abstraction that defines a stable network endpoint for one or more pods.

**ServiceAccount** — An identity for processes running in a pod, used for authentication to the Kubernetes API.

**SPA (Single Page Application)** — A web application that loads a single HTML page and dynamically updates it as the user interacts with it.

**StatefulSet** — Like a Deployment but for stateful applications. Each pod gets a stable identity and persistent storage.

**StorageClass** — Defines different types of storage (e.g., fast SSD, slow HDD) and how they should be provisioned.

## T

**TLS/SSL** — Encryption protocols that secure web traffic (HTTPS). cert-manager manages these certificates.

**Topology Spread Constraints** — Rules that control how pods are spread across your cluster (e.g., across different servers or data centers).

## V

**Velero** — A backup tool for Kubernetes that backs up both resources and persistent volumes to cloud storage.

**Volume** — A directory in a pod that is accessible to containers. It can be backed by different storage types.

**VPC (Virtual Private Cloud)** — A private network in AWS where your resources live.

## Y

**YAML** — A human-readable data format used to define Kubernetes resources. Everything in K8s is defined in YAML files.
