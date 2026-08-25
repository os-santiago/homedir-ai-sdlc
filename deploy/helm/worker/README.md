# AI-SDLC Worker Helm Chart

Helm chart for deploying the AI-SDLC autonomous worker to Kubernetes.

## Prerequisites

- Kubernetes 1.28+
- Helm 3.13+
- PersistentVolume provisioner support
- GitHub Personal Access Token
- Nvidia API Key

## Installing the Chart

### Quick Start (Development)

```bash
# Create namespace
kubectl create namespace homedir-ai-sdlc

# Create secrets manually
kubectl create secret generic ai-sdlc-worker-secrets \
  --from-literal=GH_TOKEN="your_github_token" \
  --from-literal=NVIDIA_API_KEY="your_nvidia_api_key" \
  -n homedir-ai-sdlc

# Install chart
helm install ai-sdlc-worker ./deploy/helm/worker \
  --namespace homedir-ai-sdlc \
  --set secrets.existingSecret=ai-sdlc-worker-secrets
```

### Production Installation

```bash
# Install with custom values
helm install ai-sdlc-worker ./deploy/helm/worker \
  --namespace homedir-ai-sdlc \
  --values production-values.yaml
```

Example `production-values.yaml`:

```yaml
image:
  tag: "v1.2.3"

secrets:
  existingSecret: "ai-sdlc-worker-secrets"

config:
  repo: "os-santiago/homedir"
  reconcileInterval: 180
  scc:
    timeoutSeconds: 600

persistence:
  state:
    size: 20Gi
    storageClass: "longhorn"
  worktrees:
    size: 50Gi
    storageClass: "longhorn"

resources:
  requests:
    cpu: 1000m
    memory: 2Gi
  limits:
    cpu: "8"
    memory: 8Gi
```

## Configuration

### Secrets

The chart supports two modes for secrets:

#### 1. External Secret (Recommended)

Create secret manually and reference it:

```bash
kubectl create secret generic my-secrets \
  --from-literal=GH_TOKEN="..." \
  --from-literal=NVIDIA_API_KEY="..." \
  -n homedir-ai-sdlc

helm install ai-sdlc-worker ./deploy/helm/worker \
  --set secrets.existingSecret=my-secrets
```

#### 2. Helm-Managed Secret (Development Only)

**WARNING**: Never commit secrets to git!

```bash
helm install ai-sdlc-worker ./deploy/helm/worker \
  --set secrets.create=true \
  --set secrets.ghToken="$GH_TOKEN" \
  --set secrets.nvidiaApiKey="$NVIDIA_API_KEY"
```

### Worker Configuration

Key configuration parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.repo` | Target GitHub repository | `os-santiago/homedir` |
| `config.triggerLabel` | Label to trigger processing | `ready-to-implement` |
| `config.reconcileInterval` | Seconds between reconciliation | `180` |
| `config.scc.timeoutSeconds` | SCC execution timeout | `600` |
| `config.autoMerge.enabled` | Enable automatic PR merging | `true` |
| `config.enhancedAdmission.enabled` | Enable enhanced admission | `true` |

### Persistence

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.state.enabled` | Enable state persistence | `true` |
| `persistence.state.size` | State PVC size | `10Gi` |
| `persistence.worktrees.enabled` | Enable worktrees persistence | `true` |
| `persistence.worktrees.size` | Worktrees PVC size | `20Gi` |

### Resources

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.requests.cpu` | CPU request | `500m` |
| `resources.requests.memory` | Memory request | `512Mi` |
| `resources.limits.cpu` | CPU limit | `4` |
| `resources.limits.memory` | Memory limit | `4Gi` |

## Upgrading the Chart

```bash
helm upgrade ai-sdlc-worker ./deploy/helm/worker \
  --namespace homedir-ai-sdlc \
  --reuse-values
```

## Uninstalling the Chart

```bash
helm uninstall ai-sdlc-worker --namespace homedir-ai-sdlc
```

**Note**: PVCs are not deleted automatically. To delete them:

```bash
kubectl delete pvc -n homedir-ai-sdlc -l app.kubernetes.io/name=worker
```

## Monitoring

### Check Pod Status

```bash
kubectl get pods -n homedir-ai-sdlc
```

### View Logs

```bash
kubectl logs -f deployment/ai-sdlc-worker -n homedir-ai-sdlc
```

### Check Heartbeat

```bash
kubectl exec deployment/ai-sdlc-worker -n homedir-ai-sdlc -- \
  cat /var/lib/homedir-sdlc/heartbeat.json | jq .
```

### Port Forward Dashboard (if deployed)

```bash
kubectl port-forward deployment/ai-sdlc-dashboard 8080:8080 -n homedir-ai-sdlc
```

## Troubleshooting

### Pod Not Starting

Check pod events:

```bash
kubectl describe pod -n homedir-ai-sdlc -l app.kubernetes.io/name=worker
```

### Secret Not Found

Verify secret exists:

```bash
kubectl get secret -n homedir-ai-sdlc
```

### PVC Pending

Check PVC status:

```bash
kubectl describe pvc -n homedir-ai-sdlc
```

Ensure your cluster has a storage provisioner:

```bash
kubectl get storageclass
```

### Worker Not Processing Issues

Check worker logs for errors:

```bash
kubectl logs deployment/ai-sdlc-worker -n homedir-ai-sdlc --tail=100
```

Verify secrets are correct:

```bash
kubectl get secret ai-sdlc-worker-secrets -n homedir-ai-sdlc -o yaml
```

## Development

### Testing Locally

```bash
# Lint chart
helm lint ./deploy/helm/worker

# Dry run
helm install ai-sdlc-worker ./deploy/helm/worker --dry-run --debug

# Template rendering
helm template ai-sdlc-worker ./deploy/helm/worker
```

### Updating Dependencies

This chart has no external dependencies.

## License

MIT
