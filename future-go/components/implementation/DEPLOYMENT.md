# Implementation Service Deployment

Complete GitOps deployment guide for the Implementation Service following project standards.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                        │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  Push to main → CI/CD Pipeline                             │ │
│  │  1. Build OCI image (GitHub Actions)                       │ │
│  │  2. Push to ghcr.io                                        │ │
│  │  3. ArgoCD auto-sync                                       │ │
│  │  4. Deploy to K3s                                          │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              GitHub Container Registry (ghcr.io)                │
│  ghcr.io/os-santiago/homedir-ai-sdlc/implementation:latest      │
│  ghcr.io/os-santiago/homedir-ai-sdlc/implementation:<sha>       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   ArgoCD (GitOps Controller)                    │
│  Application: ai-sdlc-implementation                            │
│  Sync Policy: Automated (prune + self-heal)                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│          K3s Cluster (namespace: homedir-ai-sdlc)               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Deployment: ai-sdlc-implementation                      │  │
│  │  - Replicas: 2 (autoscaling 2-10)                       │  │
│  │  - Resources: 500m CPU / 512Mi RAM (request)            │  │
│  │  - Image: ghcr.io/.../implementation:latest             │  │
│  │  - Health checks: /health endpoint                      │  │
│  │  - ConfigMap: sc-agent profile                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Service: ai-sdlc-implementation                         │  │
│  │  - Type: ClusterIP                                       │  │
│  │  - Port: 8082                                            │  │
│  │  - DNS: implementation.homedir-ai-sdlc.svc.cluster.local │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  HorizontalPodAutoscaler                                 │  │
│  │  - Min: 2, Max: 10                                       │  │
│  │  - Target: 75% CPU / 80% Memory                          │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↑
┌─────────────────────────────────────────────────────────────────┐
│                   Worker (Client Consumer)                      │
│  curl -X POST \                                                 │
│    http://ai-sdlc-implementation:8082/api/implementation/generate│
└─────────────────────────────────────────────────────────────────┘
```

## Deployment Methods

### Method 1: GitOps with ArgoCD (Production - Recommended)

**Fully automated, zero-touch deployment:**

```bash
# 1. Apply ArgoCD Application (one-time)
kubectl apply -f deploy/argocd/implementation-app.yaml

# 2. ArgoCD auto-syncs on every push to main
# No manual intervention required!

# 3. Monitor deployment
argocd app get ai-sdlc-implementation
argocd app sync ai-sdlc-implementation  # Manual sync if needed
```

**Benefits:**
- ✅ Automatic deployment on git push
- ✅ Self-healing (reverts manual changes)
- ✅ Automatic pruning of deleted resources
- ✅ Rollback to any previous version
- ✅ Audit trail in Git

### Method 2: Helm Install (Manual)

**For testing/development:**

```bash
# 1. Install Helm chart
helm install ai-sdlc-implementation ./deploy/helm/implementation \
  --namespace homedir-ai-sdlc \
  --create-namespace \
  --values ./deploy/gitops/implementation-values.yaml

# 2. Verify deployment
kubectl get pods -n homedir-ai-sdlc -l app.kubernetes.io/component=implementation

# 3. Upgrade
helm upgrade ai-sdlc-implementation ./deploy/helm/implementation \
  --namespace homedir-ai-sdlc \
  --values ./deploy/gitops/implementation-values.yaml
```

### Method 3: GitHub Actions Workflow (CI/CD)

**Triggered automatically on push to main:**

```yaml
# .github/workflows/deploy-implementation.yml
on:
  push:
    branches: [main]
    paths:
      - 'future-go/components/implementation/**'
      - 'deploy/helm/implementation/**'
```

**Manual trigger:**

```bash
gh workflow run deploy-implementation.yml
```

## Configuration

### Environment Variables

Set via Helm values (`deploy/gitops/implementation-values.yaml`):

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8082` | HTTP server port |
| `SC_AGENT_PATH` | `/usr/local/bin/scc` | Path to sc-agent-cli binary |
| `SC_PROFILE` | `qwen3.6` | sc-agent-cli profile name |
| `MAX_IMPLEMENTATION_ITERATIONS` | `3` | Max generation attempts |
| `QUALITY_THRESHOLD` | `8.0` | Min score to accept (0-10) |

### LLM Provider Configuration

ConfigMap mounted at `/home/appuser/.config/sc-agent/profiles.json`:

```json
[
  {
    "name": "qwen3.6",
    "baseUrl": "http://ollama.homedir-ai-sdlc.svc.cluster.local:11434/v1",
    "model": "qwen3.6:latest"
  }
]
```

**Prerequisites:**
- Ollama deployed in same namespace
- qwen3.6 model pulled: `kubectl exec deployment/ollama -- ollama pull qwen3.6`

### Resource Limits

**Production (deploy/gitops/implementation-values.yaml):**

```yaml
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: "4"
    memory: 4Gi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 75
```

## Service Discovery

Worker calls implementation service via Kubernetes DNS:

```bash
# Full FQDN
http://ai-sdlc-implementation.homedir-ai-sdlc.svc.cluster.local:8082

# Short form (same namespace)
http://ai-sdlc-implementation:8082

# Example worker integration
IMPLEMENTATION_SERVICE_URL="http://ai-sdlc-implementation:8082"
response=$(curl -X POST ${IMPLEMENTATION_SERVICE_URL}/api/implementation/generate \
  -H "Content-Type: application/json" \
  -d '{"issue_number": 123, ...}')
```

## Monitoring

### Health Checks

```bash
# Liveness probe
kubectl exec -n homedir-ai-sdlc deployment/ai-sdlc-implementation -- \
  curl -f http://localhost:8082/health

# Expected response:
# {"status":"ok","service":"implementation"}
```

### Logs

```bash
# Follow logs
kubectl logs -f -n homedir-ai-sdlc -l app.kubernetes.io/component=implementation

# Last 100 lines
kubectl logs -n homedir-ai-sdlc -l app.kubernetes.io/component=implementation --tail=100

# Specific pod
POD=$(kubectl get pod -n homedir-ai-sdlc -l app.kubernetes.io/component=implementation -o jsonpath='{.items[0].metadata.name}')
kubectl logs -f $POD -n homedir-ai-sdlc
```

### Metrics

**Prometheus ServiceMonitor** (when `monitoring.enabled: true`):

```yaml
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
```

**Metrics endpoint:** `http://ai-sdlc-implementation:8082/metrics`

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl get pods -n homedir-ai-sdlc -l app.kubernetes.io/component=implementation

# Describe pod for events
kubectl describe pod -n homedir-ai-sdlc -l app.kubernetes.io/component=implementation

# Check logs
kubectl logs -n homedir-ai-sdlc -l app.kubernetes.io/component=implementation
```

### Service Not Reachable

```bash
# Verify service exists
kubectl get svc -n homedir-ai-sdlc ai-sdlc-implementation

# Check endpoints
kubectl get endpoints -n homedir-ai-sdlc ai-sdlc-implementation

# Test from worker pod
kubectl exec -n homedir-ai-sdlc deployment/ai-sdlc-worker -- \
  curl -f http://ai-sdlc-implementation:8082/health
```

### Image Pull Failures

```bash
# Verify image exists
docker pull ghcr.io/os-santiago/homedir-ai-sdlc/implementation:latest

# Check imagePullSecrets (if private registry)
kubectl get secret -n homedir-ai-sdlc

# Check pod events
kubectl describe pod -n homedir-ai-sdlc -l app.kubernetes.io/component=implementation | grep -A5 Events
```

### ArgoCD Sync Issues

```bash
# Check sync status
argocd app get ai-sdlc-implementation

# View sync diff
argocd app diff ai-sdlc-implementation

# Force sync
argocd app sync ai-sdlc-implementation --force

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

## Rollback

### Helm Rollback

```bash
# List releases
helm history ai-sdlc-implementation -n homedir-ai-sdlc

# Rollback to previous
helm rollback ai-sdlc-implementation -n homedir-ai-sdlc

# Rollback to specific revision
helm rollback ai-sdlc-implementation 3 -n homedir-ai-sdlc
```

### ArgoCD Rollback

```bash
# Rollback to previous sync
argocd app rollback ai-sdlc-implementation

# Rollback to specific revision
argocd app rollback ai-sdlc-implementation 5
```

### Git Rollback

```bash
# Revert commit
git revert <commit-sha>
git push origin main
# ArgoCD auto-syncs to reverted state
```

## Scaling

### Manual Scaling

```bash
# Scale replicas
kubectl scale deployment ai-sdlc-implementation \
  --replicas=5 \
  -n homedir-ai-sdlc

# Verify scaling
kubectl get pods -n homedir-ai-sdlc -l app.kubernetes.io/component=implementation
```

### Autoscaling

HPA automatically scales based on CPU/memory:

```bash
# Check HPA status
kubectl get hpa -n homedir-ai-sdlc

# Describe HPA for metrics
kubectl describe hpa -n homedir-ai-sdlc ai-sdlc-implementation
```

## Updating

### Code Changes

```bash
# 1. Push changes to main
git push origin main

# 2. GitHub Actions builds new image
# → ghcr.io/os-santiago/homedir-ai-sdlc/implementation:latest

# 3. ArgoCD detects image change and redeploys
# (automatic within 3 minutes)

# 4. Verify new version
kubectl get pods -n homedir-ai-sdlc -l app.kubernetes.io/component=implementation
kubectl logs -f deployment/ai-sdlc-implementation -n homedir-ai-sdlc
```

### Configuration Changes

```bash
# 1. Edit values
vim deploy/gitops/implementation-values.yaml

# 2. Commit and push
git add deploy/gitops/implementation-values.yaml
git commit -m "feat: increase implementation resources"
git push origin main

# 3. ArgoCD auto-syncs new values
# No pod restart needed for config changes (unless resource limits changed)
```

## Security

### Pod Security

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
    drop:
      - ALL
  readOnlyRootFilesystem: false
```

### Network Policies

```bash
# Allow worker → implementation
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-worker-to-implementation
  namespace: homedir-ai-sdlc
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: implementation
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/component: worker
      ports:
        - protocol: TCP
          port: 8082
EOF
```

## Performance

### Resource Usage

**Typical per replica:**
- CPU: 200-800m (under load)
- Memory: 300-600Mi (under load)
- Requests/sec: ~10-20 (multi-pass generation is slow)

**Scaling recommendations:**
- < 50 issues/hour: 2 replicas
- 50-200 issues/hour: 3-5 replicas
- > 200 issues/hour: 5-10 replicas + faster model

## References

- **Helm Chart:** [deploy/helm/implementation/](../../../deploy/helm/implementation/)
- **GitOps Values:** [deploy/gitops/implementation-values.yaml](../../../deploy/gitops/implementation-values.yaml)
- **ArgoCD App:** [deploy/argocd/implementation-app.yaml](../../../deploy/argocd/implementation-app.yaml)
- **CI/CD Pipeline:** [.github/workflows/deploy-implementation.yml](../../../.github/workflows/deploy-implementation.yml)
- **Service README:** [README.md](README.md)

---

**Last Updated:** 2026-08-29  
**Version:** 1.0.0  
**Deployment Model:** GitOps with ArgoCD
