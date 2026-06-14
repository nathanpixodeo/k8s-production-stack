# Database Engine Selection

The database layer supports three engines out of the box. All engines expose identical Service names for seamless switching.

## Service Names (same across all engines)

| Service | Purpose | Port |
|---------|---------|------|
| `database-svc` | Primary read/write endpoint | 3306 (mysql/mariadb) / 5432 (postgresql) |
| `database-svc-read` | Replica read-only endpoint | 3306 / 5432 |
| `database-headless` | Stable DNS for StatefulSet | 3306 / 5432 |

## Available Engines

### MySQL 8.4

Default engine. Recommended for Laravel, WordPress, Magento.

```bash
kubectl apply -k database/mysql/
```

**Image:** `mysql:8.4`
**Replicas:** 3 (1 primary + 2 replicas)
**Storage:** 10Gi gp3 per pod
**Config:** Tuned my.cnf (innodb_buffer_pool_size=2G, max_connections=200, utf8mb4)

### MariaDB 11.4

Drop-in replacement for MySQL. Better performance, more storage engines.

```bash
# Edit database/kustomization.yaml: comment mysql, uncomment mariadb
kubectl apply -k database/mariadb/
```

**Image:** `mariadb:11.4`
**Replicas:** 3
**Storage:** 10Gi gp3 per pod

### PostgreSQL 16

Recommended for geospatial data, advanced analytics, or when JSONB is needed.

```bash
# Edit database/kustomization.yaml: comment mysql, uncomment postgresql
kubectl apply -k database/postgresql/
```

**Image:** `postgres:16`
**Replicas:** 3
**Storage:** 10Gi gp3 per pod
**Config:** Tuned postgresql.conf (shared_buffers=1GB, effective_cache_size=3GB)

## Switching Engines

1. Edit `database/kustomization.yaml` and uncomment the desired engine
2. Update `DB_CONNECTION` and `DB_PORT` in `application/configmap.yaml` (or `frameworks/laravel/env-configmap.yaml`):
   - MySQL: `DB_CONNECTION=mysql`, `DB_PORT=3306`
   - MariaDB: `DB_CONNECTION=mysql`, `DB_PORT=3306`
   - PostgreSQL: `DB_CONNECTION=pgsql`, `DB_PORT=5432`
3. Delete old StatefulSet: `kubectl delete sts -n myapp mysql`
4. Apply new engine: `kubectl apply -k database/`

```bash
# Example: switch from MySQL to PostgreSQL
sed -i 's/DB_CONNECTION=mysql/DB_CONNECTION=pgsql/' application/configmap.yaml
sed -i 's/DB_PORT=3306/DB_PORT=5432/' application/configmap.yaml
kubectl delete sts -n myapp mysql
kubectl apply -k database/postgresql/
kubectl apply -k application/
```

## External/Managed Database

To use a managed database (RDS, Cloud SQL, etc.) instead of an in-cluster StatefulSet:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: database-svc
  namespace: myapp
spec:
  type: ExternalName
  externalName: myapp.xxxxxxxxxxxx.region.rds.amazonaws.com
```

This allows switching between in-cluster and managed databases without changing application config.
