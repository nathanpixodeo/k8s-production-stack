# Framework Overlays

This directory contains framework-specific deployment overlays.

## Available Frameworks

| Framework | Description | Components |
|-----------|-------------|------------|
| [Laravel](laravel/) | PHP API backend | PHP-FPM + Nginx sidecar + Horizon + Scheduler |
| [React](react/) | Frontend SPA | Nginx static file serving |
| [Fullstack](fullstack/) | Laravel API + React FE + PostgreSQL | Combined ingress routing `/api/*` → Laravel, `/*` → React |

---

## Laravel (`frameworks/laravel/`)

PHP-FPM backend with Nginx reverse proxy, queue worker, and scheduler.

**Components:**
- **PHP-FPM** container running Laravel
- **Nginx** sidecar with Laravel-optimised config (try_files, fastcgi, 100m upload)
- **Horizon** dedicated deployment for Redis queue monitoring
- **Scheduler** CronJob `* * * * *` for `php artisan schedule:run`
- **Service:** `laravel-svc:80`
- **Ingress:** `laravel-ingress` (TLS via cert-manager)

**Usage with MySQL:**
```bash
kubectl apply -k database/mysql/
kubectl apply -k frameworks/laravel/
```

**Usage with PostgreSQL:**
```bash
kubectl apply -k database/postgresql/
# Update DB_CONNECTION=pgsql and DB_PORT=5432 in env-configmap.yaml
kubectl apply -k frameworks/laravel/
```

---

## React (`frameworks/react/`)

Single Page Application served by Nginx with static file optimisation.

**Components:**
- **Nginx** serving built React assets (gzip, immutable cache for static files)
- SPA fallback routing (`try_files $uri $uri/ /index.html`)
- **Service:** `react-svc:80`
- No Ingress (use alongside Laravel or standalone)

**Usage:**
```bash
kubectl apply -k frameworks/react/
```

**Dockerfile for your React app:**
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
```

---

## Fullstack (`frameworks/fullstack/`)

Combined deployment: Laravel API + React frontend + PostgreSQL database with unified ingress routing.

**Architecture:**
```
Internet → Ingress-NGINX
  ├── /api/*       → Laravel API   → PostgreSQL
  ├── /storage/*   → Laravel API
  ├── /telescope/* → Laravel API
  ├── /horizon/*   → Laravel API
  └── /*           → React SPA
```

**Components:**
- **PostgreSQL** 16 StatefulSet (3 replicas, 10Gi gp3)
- **Laravel** API backend (PHP-FPM + Nginx + Horizon + Scheduler)
- **React** frontend (Nginx static SPA)
- **Unified Ingress** routing paths by prefix
- Optimised for Laravel Sanctum SPA authentication with `SANCTUM_STATEFUL_DOMAINS` and `SESSION_DOMAIN`

**One-command deploy:**
```bash
kubectl apply -k frameworks/fullstack/
```

**Env vars configured for fullstack:**
| Variable | Value | Purpose |
|----------|-------|---------|
| `DB_CONNECTION` | `pgsql` | PostgreSQL driver |
| `FRONTEND_URL` | `https://myapp.example.com` | CORS/CSRF |
| `SANCTUM_STATEFUL_DOMAINS` | `myapp.example.com` | Sanctum SPA auth |
| `SESSION_DOMAIN` | `.myapp.example.com` | Shared session cookie |

---

## Architecture Diagrams

### Laravel + MySQL
```
Ingress → laravel-svc → Nginx sidecar → PHP-FPM → MySQL (3306)
                                            ├── Horizon (Redis queue)
                                            └── Scheduler (CronJob)
```

### React standalone
```
Ingress → react-svc → Nginx (static SPA)
```

### Fullstack (Laravel API + React FE + PostgreSQL)
```
Ingress
  ├── /api/* → laravel-svc → Nginx → PHP-FPM → PostgreSQL (5432)
  ├── /horizon/* → laravel-svc                     ├── Horizon
  └── /* → react-svc → Nginx (SPA)                 └── Scheduler
```

---

## Adding a New Framework

1. Create a directory `frameworks/<name>/`
2. Add Kubernetes manifests (deployment, service, configmap, hpa, pdb, network-policy)
3. Create `kustomization.yaml` with namespace `myapp`
4. Update this README
