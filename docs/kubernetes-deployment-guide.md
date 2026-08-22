# Kubernetes Deployment Guide - AI-SDLC

Complete guide for deploying AI-SDLC on Kubernetes using Helm Charts and GitOps.

## Overview

This deployment replaces the Podman-based VPS deployment with a production-ready Kubernetes setup featuring:

- **Helm Charts**: Declarative infrastructure
- **GitOps**: ArgoCD for continuous deployment
- **Monitoring**: Prometheus + Grafana integration
- **Security**: Network policies, RBAC, secrets management
- **High Availability**: PVC for state persistence

---

## Migration from Podman to Kubernetes

### Current State (Podman on VPS)

```bash
# VPS deployment
podman pod: ai-sdlc
  ├─ Container: ai-sdlc-worker
  └─ Container: ai-sdlc-dashboard

# Volumes
/var/lib/homedir-sdlc          # State
/srv/homedir-sdlc/worktrees    # Git worktrees
```

### Future State (Kubernetes)

```yaml
# Kubernetes deployment
Namespace: homedir-ai-sdlc
  ├─ Deployment: ai-sdlc-worker
  ├─ Deployment: ai-sdlc-dashboard
  ├─ PVC: worker-state (10Gi)
  ├─ PVC: worker-worktrees (20Gi)
  └─ Ingress: homedir-ai-sdlc.opensourcesantiago.io
```

---

## Prerequisites

### Kubernetes Cluster

Minimum requirements:
- **Kubernetes**: 1.28+
- **Storage**: Dynamic PV provisioning (Longhorn, Rook-Ceph, etc.)
- **Ingress Controller**: nginx-ingress or similar
- **Cert Manager**: For TLS certificates

### Tools

```bash
# Install required tools
brew install helm kubectl argocd

# Or on Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Access

- Kubectl configured with cluster admin access
- GitHub token with repo access
- Nvidia API key for SCC

---

## Deployment Options

### Option 1: Helm (Direct - For Testing)

Quick deployment for development/testing:

```bash
# Clone repository
git clone https://github.com/os-santiago/homedir-ai-sdlc.git
cd homedir-ai-sdlc

# Create namespace
kubectl create namespace homedir-ai-sdlc

# Create secrets
kubectl create secret generic ai-sdlc-secrets \
  --namespace homedir-ai-sdlc \
  --from-literal=gh-token=$GH_TOKEN \
  --from-literal=nvidia-api-key=$NVIDIA_API_KEY

# Install with Helm
helm install ai-sdlc ./deploy/helm/ai-sdlc \
  --namespace homedir-ai-sdlc \
  --create-namespace \
  --values ./deploy/gitops/values.yaml

# Monitor deployment
kubectl get pods -n homedir-ai-sdlc -w
```

**Advantages:**
- Fast deployment
- Direct control
- Good for testing

**Disadvantages:**
- Manual updates
- No GitOps workflow
- Configuration drift

---

### Option 2: ArgoCD (GitOps - Production Recommended)

Production-ready deployment with GitOps:

#### Step 1: Install ArgoCD

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login
argocd login localhost:8080 --username admin --password <password-from-above>
```

#### Step 2: Configure Secrets

**Option A: Kubernetes Secret (Simple)**

```bash
kubectl create secret generic ai-sdlc-secrets \
  --namespace homedir-ai-sdlc \
  --from-literal=gh-token=$GH_TOKEN \
  --from-literal=nvidia-api-key=$NVIDIA_API_KEY
```

**Option B: External Secrets Operator (Recommended)**

```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace

# Configure Vault backend (example)
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "ai-sdlc"
EOF
```

#### Step 3: Deploy AI-SDLC Application

```bash
# Apply ArgoCD Application
kubectl apply -f deploy/argocd/application.yaml

# Sync application
argocd app sync ai-sdlc

# Monitor deployment
argocd app get ai-sdlc
kubectl get pods -n homedir-ai-sdlc -w
```

#### Step 4: Verify Deployment

```bash
# Check application status
argocd app get ai-sdlc

# Check pods
kubectl get pods -n homedir-ai-sdlc

# Check logs
kubectl logs -n homedir-ai-sdlc -l app.kubernetes.io/component=worker -f

# Check heartbeat
kubectl exec -n homedir-ai-sdlc -l app.kubernetes.io/component=worker -- \
  cat /var/lib/homedir-sdlc/heartbeat.json | jq .

# Access dashboard
kubectl port-forward -n homedir-ai-sdlc svc/ai-sdlc-dashboard 8080:8080
open http://localhost:8080
```

**Advantages:**
- GitOps workflow
- Automatic sync
- Configuration as code
- Rollback support
- Audit trail

---

## Configuration

### Customize Values

Edit `deploy/gitops/values.yaml`:

```yaml
worker:
  # Resource allocation
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: "4"
      memory: 4Gi

  # Storage
  persistence:
    state:
      size: 10Gi
      storageClass: "longhorn"  # Your storage class
    worktrees:
      size: 20Gi
      storageClass: "longhorn"

  # Worker config
  config:
    reconcileInterval: 180  # seconds
    autoMerge:
      enabled: true
    codeRabbit:
      enabled: true

dashboard:
  # Ingress configuration
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: ai-sdlc.your-domain.com  # Your domain
    tls:
      - secretName: ai-sdlc-tls
        hosts:
          - ai-sdlc.your-domain.com
```

### Storage Classes

Different providers:

**Longhorn** (Recommended):
```yaml
persistence:
  state:
    storageClass: "longhorn"
```

**Rook-Ceph**:
```yaml
persistence:
  state:
    storageClass: "rook-ceph-block"
```

**Cloud Providers**:
```yaml
# AWS EBS
storageClass: "gp3"

# GCP Persistent Disk
storageClass: "standard-rwo"

# Azure Disk
storageClass: "managed-premium"
```

---

## Monitoring

### Prometheus + Grafana

The charts include ServiceMonitor resources for Prometheus:

```bash
# Install Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Enable monitoring in AI-SDLC
helm upgrade ai-sdlc ./deploy/helm/ai-sdlc \
  --set monitoring.enabled=true \
  --set monitoring.serviceMonitor.enabled=true
```

### Grafana Dashboards

Import dashboards from `deploy/monitoring/dashboards/`:

1. Open Grafana UI
2. Go to Dashboards → Import
3. Upload JSON files:
   - `worker-dashboard.json`
   - `dashboard-dashboard.json`

### Alerts

PrometheusRules included:

- `WorkerNotProcessingIssues` - No issues processed in 30 min
- `WorkerHighFailureRate` - Failure rate > 50%
- `DashboardDown` - Dashboard unavailable

---

## Upgrade

### Helm Upgrade

```bash
# Pull latest changes
git pull origin main

# Upgrade release
helm upgrade ai-sdlc ./deploy/helm/ai-sdlc \
  --namespace homedir-ai-sdlc \
  --values ./deploy/gitops/values.yaml
```

### ArgoCD Sync

```bash
# Automatic sync (if enabled)
# ArgoCD will detect changes and sync automatically

# Manual sync
argocd app sync ai-sdlc

# Hard refresh
argocd app sync ai-sdlc --force
```

---

## Rollback

### Helm Rollback

```bash
# List releases
helm history ai-sdlc -n homedir-ai-sdlc

# Rollback to previous
helm rollback ai-sdlc -n homedir-ai-sdlc

# Rollback to specific revision
helm rollback ai-sdlc 3 -n homedir-ai-sdlc
```

### ArgoCD Rollback

```bash
# List history
argocd app history ai-sdlc

# Rollback to previous
argocd app rollback ai-sdlc

# Rollback to specific revision
argocd app rollback ai-sdlc 5
```

---

## Troubleshooting

### Worker Stuck / Not Processing

```bash
# Check logs
kubectl logs -n homedir-ai-sdlc -l app.kubernetes.io/component=worker --tail=100

# Check heartbeat
kubectl exec -n homedir-ai-sdlc deploy/ai-sdlc-worker -- \
  cat /var/lib/homedir-sdlc/heartbeat.json

# Check secrets
kubectl get secret ai-sdlc-secrets -n homedir-ai-sdlc -o yaml

# Restart worker
kubectl rollout restart deployment/ai-sdlc-worker -n homedir-ai-sdlc
```

### PVC Not Binding

```bash
# Check PVC status
kubectl get pvc -n homedir-ai-sdlc

# Describe PVC
kubectl describe pvc ai-sdlc-worker-state -n homedir-ai-sdlc

# Check storage class
kubectl get storageclass

# Check PV
kubectl get pv | grep homedir-ai-sdlc
```

### Dashboard Not Accessible

```bash
# Check ingress
kubectl get ingress -n homedir-ai-sdlc

# Describe ingress
kubectl describe ingress ai-sdlc-dashboard -n homedir-ai-sdlc

# Check certificate
kubectl get certificate -n homedir-ai-sdlc

# Port-forward for testing
kubectl port-forward -n homedir-ai-sdlc svc/ai-sdlc-dashboard 8080:8080
```

### CodeRabbit Integration Not Working

```bash
# Check worker logs
kubectl logs -n homedir-ai-sdlc -l app.kubernetes.io/component=worker | grep -i coderabbit

# Verify integration enabled
kubectl exec -n homedir-ai-sdlc deploy/ai-sdlc-worker -- env | grep CODERABBIT

# Check worker config
kubectl get configmap -n homedir-ai-sdlc ai-sdlc-worker -o yaml
```

---

## Migration Plan (Podman → Kubernetes)

### Phase 1: Parallel Deployment (Week 1)

Run both Podman and Kubernetes deployments in parallel:

1. **Deploy to Kubernetes** (new cluster)
2. **Keep Podman running** (VPS)
3. **Monitor both** for 48 hours
4. **Compare metrics**:
   - Issues processed
   - Success rate
   - Response time

### Phase 2: Traffic Split (Week 2)

Use labels to split traffic:

```yaml
# Label subset of issues for K8s worker
labels:
  - ready-to-implement
  - k8s-worker-test
```

### Phase 3: Full Cutover (Week 3)

1. **Stop Podman worker**
2. **Point DNS to K8s ingress**
3. **Monitor for 24 hours**
4. **Decommission VPS if successful**

### Phase 4: Cleanup (Week 4)

1. **Remove Podman deployment**
2. **Archive VPS data**
3. **Update documentation**

---

## Performance Tuning

### Worker Resources

High-throughput configuration:

```yaml
worker:
  replicaCount: 2  # Parallel processing
  resources:
    requests:
      cpu: "2"
      memory: 2Gi
    limits:
      cpu: "8"
      memory: 8Gi
```

### Dashboard Resources

High-traffic configuration:

```yaml
dashboard:
  replicaCount: 3
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
    targetCPUUtilizationPercentage: 70
```

---

## Security Hardening

### Network Policies

```yaml
networkPolicies:
  enabled: true
```

### Pod Security Standards

```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
```

### RBAC

Service accounts with minimal permissions:

```yaml
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/ai-sdlc-worker
```

---

## Cost Optimization

### Resource Requests

Optimized for cost:

```yaml
worker:
  resources:
    requests:
      cpu: 250m      # Reduced from 500m
      memory: 256Mi  # Reduced from 512Mi
```

### Spot Instances

Use spot/preemptible nodes:

```yaml
nodeSelector:
  node.kubernetes.io/instance-type: spot

tolerations:
  - key: spot
    operator: Exists
```

---

## References

- **Helm Charts**: `/deploy/helm/`
- **GitOps Manifests**: `/deploy/gitops/`
- **ArgoCD App**: `/deploy/argocd/`
- **Monitoring**: `/deploy/monitoring/`

---

**Status**: ✅ **Ready for Deployment**  
**Recommended**: ArgoCD GitOps approach  
**Next**: Deploy to staging cluster for validation
