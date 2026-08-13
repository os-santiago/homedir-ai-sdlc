# AI-SDLC Events Service - Deployment Guide

**Version**: 1.0.0  
**Target Environments**: Docker Compose, Kubernetes

---

## 📋 Prerequisites

### All Environments
- PostgreSQL 16+
- Java 21+ (for building)
- Maven 3.9+ (for building)

### Docker
- Docker 24+
- Docker Compose 2.20+

### Kubernetes
- Kubernetes 1.28+
- kubectl configured
- Helm 3+ (optional)
- Cert-manager (for TLS)
- Nginx Ingress Controller

---

## 🐳 Docker Compose Deployment

### Development

```bash
cd events-service

# Start with default settings
docker-compose up -d

# Access
# - Dashboard: http://localhost:8080/dashboard/
# - API: http://localhost:8080/api/events/recent
# - Health: http://localhost:8080/api/health/status
```

### Production

```bash
# Set database password
export DB_PASSWORD="your-strong-password-here"

# Start production stack
docker-compose -f deployment/docker-compose.prod.yml up -d

# Verify services
docker-compose -f deployment/docker-compose.prod.yml ps

# Check logs
docker-compose -f deployment/docker-compose.prod.yml logs -f ai-sdlc-events

# Health check
curl http://localhost:8080/api/health/status
```

### Building Custom Image

```bash
# Build from source
cd events-service
docker build -f deployment/docker/Dockerfile -t ai-sdlc-events:1.0.0 .

# Push to registry
docker tag ai-sdlc-events:1.0.0 ghcr.io/os-santiago/ai-sdlc-events:1.0.0
docker push ghcr.io/os-santiago/ai-sdlc-events:1.0.0
```

---

## ☸️ Kubernetes Deployment

### 1. Prepare Namespace

```bash
kubectl create namespace ai-sdlc
kubectl config set-context --current --namespace=ai-sdlc
```

### 2. Create Database Secret

```bash
kubectl create secret generic ai-sdlc-db-secret \
  --from-literal=host=postgres-service.database.svc.cluster.local \
  --from-literal=username=aisdlc \
  --from-literal=password=YOUR_STRONG_PASSWORD \
  -n ai-sdlc
```

Or use template:

```bash
# Edit secret-template.yaml with your values
vi deployment/kubernetes/secret-template.yaml

# Apply
kubectl apply -f deployment/kubernetes/secret-template.yaml -n ai-sdlc
```

### 3. Deploy Application

```bash
kubectl apply -f deployment/kubernetes/deployment.yaml -n ai-sdlc
```

### 4. Verify Deployment

```bash
# Check pods
kubectl get pods -n ai-sdlc

# Check services
kubectl get svc -n ai-sdlc

# Check ingress
kubectl get ingress -n ai-sdlc

# Logs
kubectl logs -f deployment/ai-sdlc-events -n ai-sdlc

# Port-forward for testing
kubectl port-forward svc/ai-sdlc-events 8080:8080 -n ai-sdlc
```

### 5. Access Application

**Via Ingress**:
```
https://ai-sdlc.example.com/dashboard/
```

**Via Port-Forward**:
```
http://localhost:8080/dashboard/
```

---

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `QUARKUS_PROFILE` | Profile (dev/prod) | dev | No |
| `DB_HOST` | PostgreSQL host | localhost | Yes |
| `DB_PORT` | PostgreSQL port | 5432 | No |
| `DB_NAME` | Database name | aisdlc | No |
| `DB_USERNAME` | Database user | aisdlc | Yes |
| `DB_PASSWORD` | Database password | - | Yes |
| `JAVA_OPTS` | JVM options | - | No |

### Production Configuration

**application-prod.properties**:
- JSON logging enabled
- CORS restricted to domain
- Swagger UI disabled
- Health checks on `/q/health`
- Metrics on `/q/metrics`
- Graceful shutdown: 30s

### Database Migration

Flyway migrations run automatically on startup:

```bash
# Verify migrations
kubectl exec -it deployment/ai-sdlc-events -n ai-sdlc -- \
  psql -h $DB_HOST -U $DB_USERNAME -d $DB_NAME -c \
  "SELECT version, description FROM flyway_schema_history ORDER BY installed_rank;"
```

Expected migrations:
- `0.1.0` - create_event_store
- `0.3.0` - create_projections

---

## 📊 Monitoring

### Health Checks

```bash
# Liveness (is app alive?)
curl http://localhost:8080/api/health/live

# Readiness (can app handle traffic?)
curl http://localhost:8080/api/health/ready

# Full status
curl http://localhost:8080/api/health/status
```

### Metrics (Prometheus)

```bash
# Prometheus metrics
curl http://localhost:8080/q/metrics

# Custom metrics
curl http://localhost:8080/q/metrics | grep events_published
curl http://localhost:8080/q/metrics | grep projections_created
curl http://localhost:8080/q/metrics | grep sse_connections
```

### Kubernetes Metrics

```bash
# Pod metrics
kubectl top pods -n ai-sdlc

# Resource usage
kubectl describe pod -n ai-sdlc -l app=ai-sdlc-events
```

---

## 🔄 Rolling Updates

### Kubernetes

```bash
# Update image
kubectl set image deployment/ai-sdlc-events \
  ai-sdlc-events=ghcr.io/os-santiago/ai-sdlc-events:1.1.0 \
  -n ai-sdlc

# Watch rollout
kubectl rollout status deployment/ai-sdlc-events -n ai-sdlc

# Rollback if needed
kubectl rollout undo deployment/ai-sdlc-events -n ai-sdlc
```

### Docker Compose

```bash
# Pull new image
docker-compose -f deployment/docker-compose.prod.yml pull

# Restart with new image
docker-compose -f deployment/docker-compose.prod.yml up -d

# Zero-downtime: scale up, then down
docker-compose -f deployment/docker-compose.prod.yml up -d --scale ai-sdlc-events=2
docker-compose -f deployment/docker-compose.prod.yml up -d --scale ai-sdlc-events=1
```

---

## 🔒 Security Considerations

### Database

- ✅ Use strong passwords (min 20 chars, random)
- ✅ Store credentials in Kubernetes Secrets
- ✅ Rotate passwords regularly
- ✅ Enable SSL/TLS for database connections

### Application

- ✅ Disable Swagger UI in production
- ✅ Restrict CORS to specific domains
- ✅ Use HTTPS only (via Ingress)
- ✅ Run as non-root user (UID 1000)
- ✅ Read-only filesystem (except /tmp)

### Network

- ✅ Use ClusterIP service (not NodePort/LoadBalancer)
- ✅ Enable TLS on Ingress
- ✅ Use Network Policies to restrict traffic
- ✅ Long timeout for SSE connections (1 hour)

---

## 🐛 Troubleshooting

### Database Connection Issues

```bash
# Check database pod
kubectl get pods -n database

# Test connectivity from app pod
kubectl exec -it deployment/ai-sdlc-events -n ai-sdlc -- \
  nc -zv postgres-service.database.svc.cluster.local 5432

# Check credentials
kubectl get secret ai-sdlc-db-secret -n ai-sdlc -o yaml
```

### Migration Failures

```bash
# Check logs
kubectl logs deployment/ai-sdlc-events -n ai-sdlc | grep Flyway

# Manual migration check
psql -h DB_HOST -U DB_USER -d aisdlc \
  -c "SELECT * FROM flyway_schema_history;"

# Repair if needed (CAUTION)
# Only if migration failed mid-execution
psql -h DB_HOST -U DB_USER -d aisdlc \
  -c "DELETE FROM flyway_schema_history WHERE success = false;"
```

### SSE Connection Drops

Check Ingress timeout:

```bash
kubectl describe ingress ai-sdlc-events -n ai-sdlc | grep timeout
```

Should show:
```
nginx.ingress.kubernetes.io/proxy-read-timeout: 3600
nginx.ingress.kubernetes.io/proxy-send-timeout: 3600
```

### Memory Issues

```bash
# Check memory usage
kubectl top pod -n ai-sdlc

# Adjust limits if needed
kubectl edit deployment ai-sdlc-events -n ai-sdlc
# Update resources.limits.memory

# Restart
kubectl rollout restart deployment/ai-sdlc-events -n ai-sdlc
```

---

## 📈 Scaling

### Horizontal Scaling (Kubernetes)

```bash
# Scale to 3 replicas
kubectl scale deployment ai-sdlc-events --replicas=3 -n ai-sdlc

# Auto-scaling (HPA)
kubectl autoscale deployment ai-sdlc-events \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  -n ai-sdlc
```

**Note**: SSE connections will reconnect on pod restart (auto-reconnect in client).

### Vertical Scaling

```bash
# Increase resources
kubectl edit deployment ai-sdlc-events -n ai-sdlc

# Update:
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "2000m"
```

---

## 🔄 Backup & Recovery

### Database Backup

```bash
# Backup
pg_dump -h DB_HOST -U DB_USER -d aisdlc -F c -f aisdlc-backup-$(date +%Y%m%d).dump

# Restore
pg_restore -h DB_HOST -U DB_USER -d aisdlc -c aisdlc-backup-20260809.dump
```

### Event Store Replication

Event store (`ai_sdlc_events`) is append-only:

```sql
-- Backup events from last 30 days
COPY (
  SELECT * FROM ai_sdlc_events 
  WHERE timestamp > NOW() - INTERVAL '30 days'
) TO '/backup/events-30d.csv' CSV HEADER;
```

---

## 📚 Additional Resources

- [Quarkus Kubernetes Guide](https://quarkus.io/guides/deploying-to-kubernetes)
- [PostgreSQL High Availability](https://www.postgresql.org/docs/16/high-availability.html)
- [Prometheus Monitoring](https://prometheus.io/docs/introduction/overview/)

---

**Deployment Status**: ✅ Production Ready  
**Version**: 1.0.0
