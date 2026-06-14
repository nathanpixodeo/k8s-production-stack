# Architecture Overview (For Beginners)

This document explains the architecture of this project in plain language. If you have never used Kubernetes before, start here.

## What is Kubernetes? (30-Second Analogy)

Imagine you are running a restaurant:

- **Your application** is the recipe for a dish
- **A Pod** is one cook making that dish
- **A Deployment** is the head chef who ensures there are always enough cooks
- **A Service** is the waiter who knows which cook to take orders to
- **An Ingress** is the restaurant door — all customers enter through it
- **A Node** is the kitchen itself (a physical/virtual machine)
- **The Cluster** is the entire restaurant building with all kitchens

Kubernetes (K8s for short) is a system that manages all of this automatically. You tell it what you want (e.g., "run 3 copies of my app"), and it makes sure that stays true — even if a machine crashes.

## What Does This Project Give You?

This project is a **pre-made blueprint** for running web applications on Kubernetes. Instead of researching and configuring everything yourself, you get:

- A production-ready Kubernetes cluster on AWS
- Automatic HTTPS via Let's Encrypt
- A database (MySQL, MariaDB, or PostgreSQL — your choice)
- Auto-scaling (add more copies when traffic is high)
- Monitoring (visual dashboards and alerts)
- Backups (automatic daily snapshots)
- Security (firewall rules, encrypted secrets)

## The Big Picture

```
                    ┌─────────────────────┐
                    │     INTERNET         │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │   INGRESS-NGINX     │  ← The "front door" (handles HTTPS)
                    │   (TLS termination)  │
                    └──────────┬──────────┘
                               │
           ┌───────────────────┼───────────────────┐
           │                   │                   │
           ▼                   ▼                   ▼
    ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
    │  REACT SPA   │   │  LARAVEL API │   │  DATABASE    │
    │  (Frontend)  │   │  (Backend)   │   │  (PostgreSQL)│
    │  Nginx       │   │  PHP-FPM     │   │  StatefulSet │
    │  Static files│   │  + Horizon   │   │  3 replicas  │
    └──────────────┘   └──────────────┘   └──────────────┘
```

## The Layers (from Bottom to Top)

Think of this like building a house — you start with the foundation and work your way up.

### 1. Cluster Layer (The Land + Foundation)

**What it is:** The actual servers (computers) and network that everything runs on.

**Real-world analogy:** You buy a piece of land, pour a concrete foundation, and run electricity and water pipes to the site.

**What this stack creates:**
- **VPC**: A private network (like a fenced property)
- **Subnets**: Sections of the network (like front yard vs backyard)
- **EC2 instances**: The actual computers (servers)
- **EKS**: Amazon's managed Kubernetes service

**You don't need to understand all of this — just know that `clusters/eksctl-cluster.yaml` defines the blueprint.**

### 2. Networking Layer (The Doors + Locks)

**What it is:** Controls who can enter your application and how traffic flows.

**Real-world analogy:** The front door, security cameras, and doorbell.

**Components:**
- **Ingress-NGINX**: The main entrance door. All internet traffic comes through here. It handles HTTPS encryption automatically.
- **cert-manager**: An automatic key maker. It gets free HTTPS certificates from Let's Encrypt so your site has "padlock" in the browser.
- **CoreDNS**: The internal phonebook. When one service needs to talk to another, it looks up the address here.

### 3. Storage Layer (The Pantry + Fridge)

**What it is:** Where your application saves files permanently.

**Real-world analogy:** The pantry shelves and refrigerator where you store ingredients.

**Key concept — PVC (PersistentVolumeClaim):**
A PVC is like a reserved shelf space. Your app says "I need 10GB of storage," and Kubernetes carves out that space automatically. Even if the app restarts, the data stays.

**What this stack creates:**
- **StorageClass `gp3`**: Fast SSD storage on AWS (like having a high-end fridge)
- **VolumeSnapshot**: Point-in-time backups of your data

### 4. Data Layer (The Database — MySQL/PostgreSQL)

**What it is:** Where structured data (user accounts, orders, posts) lives.

**Real-world analogy:** A file cabinet with labeled folders.

**Why 3 copies?** The database runs with 3 copies (called replicas):
- **1 Primary**: The "main" copy. All writes go here.
- **2 Replicas**: Copies that are kept in sync. Reads can go here to spread the load.

If the primary fails, one of the replicas automatically becomes the new primary. This is called **high availability**.

**Which engine should you choose?**
- **MySQL**: Most common, works with everything. Default choice.
- **MariaDB**: Drop-in replacement for MySQL, slightly faster.
- **PostgreSQL**: Best for geospatial data, JSON, and advanced features. Used by the "Fullstack" setup.

### 5. Application Layer (The Actual Restaurant)

**What it is:** Your code running in containers.

**Real-world analogy:** The chefs, waiters, and kitchen equipment.

**Components:**
- **Deployment**: The head chef who says "I need 3 cooks making this dish at all times"
- **Pod**: An individual cook (one running instance of your app)
- **Service**: The waiter who knows which cook to send orders to
- **HPA**: The manager who watches the crowd and hires more cooks when it gets busy
- **PDB**: The rule that says "never let it drop below 2 cooks, even during renovations"

### 6. Security Layer (Locks + Guards + Safe)

**What it is:** Controls who can access what.

**Real-world analogy:** Locks on doors, security badges, and a safe for valuables.

**Components:**
- **Network Policies**: Firewall rules. "Only the front door can talk to the kitchen."
- **RBAC**: Security badges. "Only managers can enter the office."
- **Sealed Secrets**: An encrypted safe. You can store passwords in your code repository without anyone being able to read them.

### 7. Monitoring Layer (Security Cameras + Dashboards)

**What it is:** Watches everything to make sure it's running smoothly.

**Real-world analogy:** Security cameras, temperature gauges, and a control room.

**Components:**
- **Prometheus**: Collects measurements (CPU, memory, request counts)
- **Grafana**: Shows pretty dashboards (visual charts)
- **Loki**: Stores logs (like a searchable diary of everything that happened)
- **AlertManager**: Sends alerts to Slack or email if something is wrong

### 8. Backup Layer (Insurance)

**What it is:** Automatic backups so you don't lose data.

**Real-world analogy:** An insurance policy with daily photo documentation.

**What this stack creates:**
- **Daily backups**: Every night at 2 AM, a snapshot is taken and saved to S3 (cloud storage).
- **30-day retention**: You can restore from any backup within the last 30 days.
- **Monthly backups**: Kept for 90 days for long-term safety.

### 9. GitOps Layer (The Automated Manager)

**What it is:** A system that watches your Git repository and automatically applies changes to the cluster.

**Real-world analogy:** An automated restaurant manager who reads the recipe book and makes sure the kitchen follows it exactly.

**How it works:**
1. You edit configuration files in Git (GitHub)
2. ArgoCD notices the change
3. ArgoCD automatically applies the change to your cluster
4. If someone manually changes something in the cluster, ArgoCD changes it back to match Git

This is called **"Git as the single source of truth."**

## Request Flow: What Happens When Someone Visits Your Site

Let's trace what happens when a user types `https://myapp.example.com` in their browser:

```
Step 1: Browser looks up DNS → finds the IP of your Ingress Controller
Step 2: Browser connects to Ingress-NGINX (your front door)
Step 3: Ingress checks the URL path:
  - /api/* → forwards to Laravel backend
  - /* → forwards to React frontend
Step 4a (Laravel): PHP-FPM processes the request, talks to PostgreSQL if needed
Step 4b (React): Nginx serves the static HTML/CSS/JavaScript files
Step 5: The response travels back through the same path to the browser
```

## Request Flow Diagram

```
User's Browser
      │
      ▼  (1) DNS lookup
  myapp.example.com
      │
      ▼  (2) HTTPS connection
  ┌────────────────────┐
  │  Ingress-NGINX     │  ← One entry point for everything
  │  (TLS termination) │
  └────┬──────────┬────┘
       │          │
  /api/*          │ /*
       │          │
       ▼          ▼
  ┌────────┐ ┌────────┐
  │Laravel │ │ React  │
  │API     │ │ SPA    │
  │PHP-FPM │ │ Nginx  │
  └───┬────┘ └────────┘
      │
      ▼
  ┌────────┐
  │PostgreSQL│
  │Database │
  └────────┘
```

## Auto Scaling: How It Handles Traffic Spikes

When traffic increases, the system automatically adds more resources:

```
Traffic spike happens
      │
      ▼
Pods use more CPU (>75%)
      │
      ▼
HPA detects high CPU
      │
      ├─ Adds more Pod replicas (up to 20)
      │
      ▼
If cluster is full, Cluster Autoscaler adds more servers (nodes)
```

When traffic drops, it scales back down to save money.

## Summary

| Layer | What it does | Analogy |
|-------|-------------|---------|
| Cluster | The servers and network | The land + building |
| Networking | HTTPS, DNS, routing | The doors + phone system |
| Storage | Hard drives for data | The pantry |
| Data | MySQL/PostgreSQL database | The file cabinet |
| Application | Your actual code | The chefs + waiters |
| Security | Firewalls, passwords, encryption | Locks + guards + safe |
| Monitoring | Dashboards, alerts, logs | Security cameras |
| Backup | Automatic data insurance | Insurance policy |
| GitOps | Git-powered automation | The automated manager |

## Next Steps

Ready to deploy? Read the [Stack Flow Guide](stack-flow.md) which walks through how to install everything step by step.

Need to understand basic Kubernetes concepts first? Read [Concepts & Glossary](glossary.md).
