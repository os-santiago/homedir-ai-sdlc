# AI-SDLC Kubernetes Deployment

Complete Kubernetes deployment infrastructure for AI-SDLC using Helm Charts and GitOps with ArgoCD.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                      │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │              Namespace: homedir-ai-sdlc               │ │
│  │                                                       │ │
│  │  ┌──────────────────┐      ┌──────────────────┐     │ │
│  │  │   Worker Pod     │      │  Dashboard Pod   │     │ │
│  │  │                  │      │                  │     │ │
│  │  │  - SCC Engine    │      │  - Quarkus       │     │ │
│  │  │  - Git Worktrees │◄─────┤  - REST API      │     │ │
│  │  │  - CodeRabbit    │      │  - Web UI        │     │ │
│  │  └──────────────────┘      └──────────────────┘     │ │
│  │           │                          │              │ │
│  │           │                          │              │ │
│  │  ┌────────▼────────┐      ┌─────────▼──────┐       │ │
│  │  │  PVC: State     │      │   Ingress      │       │ │
│  │  │  (10Gi)         │      │   (HTTPS)      │       │ │
│  │  └─────────────────┘      └────────────────┘       │ │
│  │           │                                         │ │
│  │  ┌────────▼────────┐                               │ │
│  │  │ PVC: Worktrees  │                               │ │
│  │  │  (20Gi)         │                               │ │
│  │  └─────────────────┘                               │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. Helm Charts

Located in `deploy/helm/`:

- **`ai-sdlc/`** - Umbrella chart that includes worker + dashboard
- **`worker/`** - Worker deployment with SCC engine
- **`dashboard/`** - Quarkus dashboard for observability

### 2. GitOps Manifests

Located in `deploy/gitops/`:

- **`kustomization.yaml`** - Kustomize configuration
- **`values.yaml`** - Production values for Helm chart
- **`secrets.yaml`** - Secret management (encrypted)
- **`namespace.yaml`** - Namespace definition

### 3. ArgoCD Configuration

Located in `deploy/argocd/`:

- **`application.yaml`** - ArgoCD Application for continuous deployment

## Quick Start

### Prerequisites

- Kubernetes cluster (1.28+)
- kubectl configured
- Helm 3.12+
- ArgoCD installed (optional, for GitOps)

### Option 1: Helm Install (Manual)

```bash
# 1. Create namespace
kubectl create namespace homedir-ai-sdlc

# 2. Create secrets
kubectl create secret generic ai-sdlc-secrets \
  --namespace homedir-ai-sdlc \
  --from-literal=gh-token=YOUR_GITHUB_TOKEN \
  --from-literal=nvidia-api-key=YOUR_NVIDIA_API_KEY

# 3. Install chart
helm install ai-sdlc ./deploy/helm/ai-sdlc \
  --namespace homedir-ai-sdlc \
  --values ./deploy/gitops/values.yaml

# 4. Verify deployment
kubectl get pods -n homedir-ai-sdlc
kubectl logs -n homedir-ai-sdlc -l app.kubernetes.io/component=worker -f
```

### Option 2: ArgoCD Install (GitOps - Recommended)

```bash
# 1. Apply ArgoCD Application
kubectl apply -f deploy/argocd/application.yaml

# 2. Sync application
argocd app sync ai-sdlc

# 3. Monitor deployment
argocd app get ai-sdlc
kubectl get pods -n homedir-ai-sdlc -w
```

## Configuration

### Values Customization

Edit `deploy/gitops/values.yaml`:

```yaml
worker:
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: "4"
      memory: 4Gi

  persistence:
    state:
      size: 10Gi
      storageClass: "your-storage-class"

dashboard:
  ingress:
    hosts:
      - host: your-domain.com
```

### Secrets Management

**Option 1: Kubernetes Secret (Simple)**
```bash
kubectl create secret generic ai-sdlc-secrets \
  --namespace homedir-ai-sdlc \
  --from-literal=gh-token=ghp_xxxx \
  --from-literal=nvidia-api-key=nvapi-xxxx
```

**Option 2: External Secrets Operator (Recommended)**

Edit `deploy/gitops/secrets.yaml`:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ai-sdlc-secrets
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: vault-backend
  data:
    - secretKey: gh-token
      remoteRef:
        key: secret/data/ai-sdlc/github
        property: token
```

**Option 3: Sealed Secrets**

```bash
# Create sealed secret
kubectl create secret generic ai-sdlc-secrets \
  --dry-run=client \
  --from-literal=gh-token=ghp_xxxx \
  -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

kubectl apply -f sealed-secret.yaml
```

## Deployment Scenarios

### Development

```bash
helm install ai-sdlc ./deploy/helm/ai-sdlc \
  --namespace homedir-ai-sdlc-dev \
  --create-namespace \
  --set worker.image.tag=dev \
  --set worker.config.reconcileInterval=60 \
  --set dashboard.ingress.enabled=false
```

### Staging

```bash
helm install ai-sdlc ./deploy/helm/ai-sdlc \
  --namespace homedir-ai-sdlc-staging \
  --create-namespace \
  --values ./deploy/environments/staging-values.yaml
```

### Production

Use ArgoCD for production (see Option 2 above).

## Monitoring

### Prometheus + Grafana

The charts include ServiceMonitor and PrometheusRule resources:

```bash
# Enable monitoring
helm upgrade ai-sdlc ./deploy/helm/ai-sdlc \
  --set monitoring.enabled=true \
  --set monitoring.serviceMonitor.enabled=true \
  --set monitoring.prometheusRule.enabled=true
```

### Metrics Endpoints

- Worker: `http://worker-pod:8080/metrics`
- Dashboard: `http://dashboard-pod:8080/q/metrics`

### Dashboards

Grafana dashboards available in `deploy/monitoring/dashboards/`:
- `worker-dashboard.json` - Worker metrics
- `dashboard-dashboard.json` - Dashboard metrics

## Troubleshooting

### Worker Not Processing Issues

```bash
# Check logs
kubectl logs -n homedir-ai-sdlc -l app.kubernetes.io/component=worker

# Check heartbeat
kubectl exec -n homedir-ai-sdlc -l app.kubernetes.io/component=worker -- \
  cat /var/lib/homedir-sdlc/heartbeat.json

# Check secrets
kubectl get secret ai-sdlc-secrets -n homedir-ai-sdlc -o yaml
```

### Dashboard Not Accessible

```bash
# Check ingress
kubectl get ingress -n homedir-ai-sdlc

# Check certificate
kubectl get certificate -n homedir-ai-sdlc

# Port-forward for testing
kubectl port-forward -n homedir-ai-sdlc svc/ai-sdlc-dashboard 8080:8080
```

### Persistent Volume Issues

```bash
# Check PVCs
kubectl get pvc -n homedir-ai-sdlc

# Check PV binding
kubectl get pv | grep homedir-ai-sdlc

# Describe PVC for details
kubectl describe pvc -n homedir-ai-sdlc ai-sdlc-worker-state
```

## Upgrade

### Helm Upgrade

```bash
# Pull latest chart
git pull origin main

# Upgrade release
helm upgrade ai-sdlc ./deploy/helm/ai-sdlc \
  --namespace homedir-ai-sdlc \
  --values ./deploy/gitops/values.yaml
```

### ArgoCD Sync

```bash
# Manual sync
argocd app sync ai-sdlc

# Enable auto-sync
argocd app set ai-sdlc --sync-policy automated
```

## Rollback

```bash
# Helm rollback
helm rollback ai-sdlc -n homedir-ai-sdlc

# ArgoCD rollback
argocd app rollback ai-sdlc
```

## Uninstall

```bash
# Helm uninstall
helm uninstall ai-sdlc -n homedir-ai-sdlc

# Delete namespace
kubectl delete namespace homedir-ai-sdlc

# ArgoCD delete
argocd app delete ai-sdlc
```

## CI/CD Integration

### GitHub Actions

Workflow in `.github/workflows/helm-publish.yml`:

```yaml
- name: Package Helm Chart
  run: |
    helm package ./deploy/helm/ai-sdlc
    helm package ./deploy/helm/worker
    helm package ./deploy/helm/dashboard

- name: Push to OCI Registry
  run: |
    helm push ai-sdlc-*.tgz oci://ghcr.io/os-santiago/helm-charts
```

## Resources

- **Helm Charts**: `deploy/helm/`
- **GitOps**: `deploy/gitops/`
- **ArgoCD**: `deploy/argocd/`
- **Documentation**: This README

---

**Version**: 1.0.0  
**Last Updated**: 2026-08-22  
**Maintained By**: os-santiago team
