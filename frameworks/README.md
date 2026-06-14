# Framework Overlays

This directory contains framework-specific deployment overlays that extend the base application resources.

## Available Frameworks

| Framework | Components | Services | Ingress |
|-----------|-----------|----------|---------|
| [Laravel](laravel/) | PHP-FPM + Nginx + Horizon + Scheduler | `laravel-svc` | `laravel-ingress` |

## Laravel

The Laravel overlay deploys:

- **PHP-FPM** container running the Laravel application
- **Nginx** sidecar proxying to PHP-FPM, optimised for Laravel (try_files, fastcgi, 100m upload)
- **Horizon** dedicated deployment for Redis queue monitoring
- **Scheduler** CronJob running `php artisan schedule:run` every minute
- **HPA** scaling on CPU (75%) and memory (80%)
- **PDB** ensuring minimum 2 pods during disruptions

### Usage

```bash
# Deploy Laravel with MySQL
kubectl apply -k database/mysql/
kubectl apply -k frameworks/laravel/

# Deploy Laravel with PostgreSQL
# Edit database/kustomization.yaml: uncomment postgresql
kubectl apply -k database/postgresql/
kubectl apply -k frameworks/laravel/
```

### Laravel .env mapping

| ConfigMap key | Laravel .env | Description |
|---------------|-------------|-------------|
| `APP_ENV` | `APP_ENV` | Application environment |
| `APP_DEBUG` | `APP_DEBUG` | Debug mode |
| `DB_CONNECTION` | `DB_CONNECTION` | Database driver (mysql/pgsql/sqlite) |
| `DB_HOST` | `DB_HOST` | Database hostname (uses `database-svc`) |
| `DB_PORT` | `DB_PORT` | Database port |
| `DB_DATABASE` | `DB_DATABASE` | Database name |
| `DB_USERNAME` | `DB_USERNAME` | Database user |
| `DB_PASSWORD` | `DB_PASSWORD` | Database password (from Secret) |
| `REDIS_HOST` | `REDIS_HOST` | Redis host |
| `QUEUE_CONNECTION` | `QUEUE_CONNECTION` | Queue driver (redis) |
| `SESSION_DRIVER` | `SESSION_DRIVER` | Session driver (redis) |
| `CACHE_DRIVER` | `CACHE_DRIVER` | Cache driver (redis) |
