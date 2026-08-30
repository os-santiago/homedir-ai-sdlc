# Implementation Service Deployment

Deployment guide for Implementation Service following the actual Podman-based architecture.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Push to main → GitHub Actions                       │   │
│  │  1. Build OCI images                                 │   │
│  │  2. Push to quay.io                                  │   │
│  │  3. SSH deploy to VPS                                │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│           quay.io (GitHub Container Registry)               │
│  - quay.io/os-santiago/homedir-ai-sdlc/worker:latest        │
│  - quay.io/os-santiago/homedir-ai-sdlc/dashboard:latest     │
│  - quay.io/os-santiago/homedir-ai-sdlc/implementation:latest│
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                VPS Production Server                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Podman Pod: ai-sdlc (port 8081:8080)               │   │
│  │  ┌────────────────────────────────────────────────┐ │   │
│  │  │  Container: ai-sdlc-worker (internal)          │ │   │
│  │  │  - Autonomous issue processing                 │ │   │
│  │  │  - Calls implementation service at localhost   │ │   │
│  │  └────────────────────────────────────────────────┘ │   │
│  │  ┌────────────────────────────────────────────────┐ │   │
│  │  │  Container: ai-sdlc-dashboard (8080)           │ │   │
│  │  │  - Exposed as pod port 8081                    │ │   │
│  │  └────────────────────────────────────────────────┘ │   │
│  │  ┌────────────────────────────────────────────────┐ │   │
│  │  │  Container: ai-sdlc-implementation (8082)      │ │   │
│  │  │  - Multi-pass code generation                  │ │   │
│  │  │  - Quality feedback loops                      │ │   │
│  │  │  - Internal service (not exposed)              │ │   │
│  │  └────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Flow

### Automatic Deployment (Production)

```bash
# 1. Developer pushes to main
git push origin main

# 2. GitHub Actions automatically:
#    - Builds worker, dashboard, implementation images
#    - Pushes to quay.io
#    - SSH to VPS
#    - Stops existing pod
#    - Creates new pod with all 3 containers
#    - Verifies health
```

**Zero manual steps required!**

### Service Discovery

Containers in the same pod share `localhost`:

```bash
# Worker → Implementation Service
curl http://localhost:8082/api/implementation/generate

# Worker → Dashboard
curl http://localhost:8080/q/health

# Implementation → (no outbound calls)
```

**External access:**
- Dashboard: `https://homedir-ai-sdlc.opensourcesantiago.io` (nginx → pod:8081 → dashboard:8080)
- Worker: Internal only
- Implementation: Internal only

## Configuration

### Environment Variables (VPS)

Implementation service configured via podman run:

```bash
podman run -d \
  --pod ai-sdlc \
  --name ai-sdlc-implementation \
  --restart unless-stopped \
  -e PORT=8082 \
  -e SC_PROFILE=nvidia \
  -e SC_AGENT_PATH=/usr/local/bin/scc \
  -e MAX_IMPLEMENTATION_ITERATIONS=3 \
  -e QUALITY_THRESHOLD=8.0 \
  -e NVIDIA_API_KEY="${NVIDIA_API_KEY}" \
  quay.io/os-santiago/homedir-ai-sdlc/implementation:latest
```

### sc-agent-cli Configuration

Bundled in container at `/.sc-agent/config.json`:

```json
{
  "model": {
    "provider": "openai-compatible",
    "baseUrl": "https://integrate.api.nvidia.com/v1",
    "model": "nvidia/nemotron-3-ultra-550b-a55b",
    "temperature": 1,
    "maxTokens": 16384
  },
  "profiles": {
    "nvidia": {
      "baseUrl": "https://integrate.api.nvidia.com/v1",
      "model": "nvidia/nemotron-3-ultra-550b-a55b"
    }
  },
  "activeProfile": "nvidia"
}
```

## Monitoring

### Health Checks

```bash
# From VPS
podman exec ai-sdlc-implementation curl http://localhost:8082/health

# Expected response:
{"status":"ok","service":"implementation"}
```

### Logs

```bash
# Follow logs
podman logs -f ai-sdlc-implementation

# Last 100 lines
podman logs --tail 100 ai-sdlc-implementation

# Check all containers in pod
podman pod logs ai-sdlc
```

### Container Status

```bash
# Pod status
podman pod ps | grep ai-sdlc

# Container status
podman ps --filter "pod=ai-sdlc"

# Detailed inspection
podman inspect ai-sdlc-implementation
```

## Troubleshooting

### Container Not Starting

```bash
# Check logs
podman logs ai-sdlc-implementation

# Check container status
podman inspect ai-sdlc-implementation --format='{{.State.Status}}'

# Verify image pulled
podman images | grep implementation

# Manual restart
podman restart ai-sdlc-implementation
```

### Service Not Responding

```bash
# Test health endpoint
curl -v http://localhost:8082/health

# Check if port is listening
podman exec ai-sdlc-implementation netstat -tuln | grep 8082

# Verify environment variables
podman inspect ai-sdlc-implementation --format='{{.Config.Env}}'
```

### High Memory Usage

```bash
# Check resource usage
podman stats ai-sdlc-implementation

# Check Go heap
podman exec ai-sdlc-implementation ps aux

# Restart if needed
podman restart ai-sdlc-implementation
```

## Manual Deployment

### Build Image Locally

```bash
cd /path/to/homedir-ai-sdlc

# Build
podman build -f future-go/components/implementation/Containerfile \
  -t implementation:local .

# Test
podman run --rm \
  -e PORT=8082 \
  -e NVIDIA_API_KEY=test \
  implementation:local
```

### Deploy to VPS Manually

```bash
# SSH to VPS
ssh user@vps

# Pull latest image
podman pull quay.io/os-santiago/homedir-ai-sdlc/implementation:latest

# Stop existing container (if running)
podman stop ai-sdlc-implementation
podman rm ai-sdlc-implementation

# Start new container in pod
podman run -d \
  --pod ai-sdlc \
  --name ai-sdlc-implementation \
  --restart unless-stopped \
  -e PORT=8082 \
  -e SC_PROFILE=nvidia \
  -e NVIDIA_API_KEY="your-key" \
  quay.io/os-santiago/homedir-ai-sdlc/implementation:latest

# Verify
podman logs --tail 20 ai-sdlc-implementation
curl http://localhost:8082/health
```

## Integration with Worker

Worker can call implementation service for multi-pass generation:

```bash
# In worker reconcile_implementing_issues()

# Check if implementation service available
if curl -sf http://localhost:8082/health > /dev/null 2>&1; then
  # Use implementation service (multi-pass)
  response=$(curl -X POST http://localhost:8082/api/implementation/generate \
    -H "Content-Type: application/json" \
    -d "{
      \"issue_number\": ${issue_number},
      \"issue_body\": \"${issue_body}\",
      \"acceptance_criteria\": ${criteria_json},
      \"max_iterations\": 3,
      \"quality_threshold\": 8.0
    }")
  
  code=$(echo "$response" | jq -r '.code')
  quality_score=$(echo "$response" | jq -r '.quality_score')
  
  log "Generated with quality ${quality_score}/10"
else
  # Fallback to direct SCC (single-shot)
  code=$(scc_generate_code "${issue_number}")
fi

# Create PR with code
create_pr "${issue_number}" "${code}"
```

## Rollback

### To Previous Version

```bash
# SSH to VPS
ssh user@vps

# Check available tags
podman search quay.io/os-santiago/homedir-ai-sdlc/implementation --list-tags

# Pull specific version (by commit SHA)
podman pull quay.io/os-santiago/homedir-ai-sdlc/implementation:main-abc1234

# Stop current
podman stop ai-sdlc-implementation
podman rm ai-sdlc-implementation

# Start with old version
podman run -d \
  --pod ai-sdlc \
  --name ai-sdlc-implementation \
  --restart unless-stopped \
  -e PORT=8082 \
  -e SC_PROFILE=nvidia \
  -e NVIDIA_API_KEY="your-key" \
  quay.io/os-santiago/homedir-ai-sdlc/implementation:main-abc1234
```

### Via Git Revert

```bash
# Revert commit
git revert <bad-commit-sha>
git push origin main

# GitHub Actions automatically redeploys previous version
```

## Performance

### Resource Usage

Typical per container:
- **CPU:** 100-500m (idle), 1-2 cores (under load)
- **Memory:** 200-400Mi (idle), 500Mi-1Gi (under load)
- **Disk:** ~500Mi (image)

### Scaling

Implementation service doesn't scale horizontally in current architecture (single pod).

For high load:
1. **Vertical scaling:** Increase VPS resources
2. **Optimize iterations:** Reduce MAX_IMPLEMENTATION_ITERATIONS from 3 to 2
3. **Faster model:** Use lighter model (trade quality for speed)

## Security

### Container Security

```dockerfile
# Non-root user (rootless compatible)
# No USER directive - runs with --user at runtime

# Capabilities dropped (inherited from pod)
# Read-only root filesystem: false (needs /tmp)

# Secrets via environment variables (not in image)
ENV NVIDIA_API_KEY passed at runtime
```

### Network Isolation

- Implementation service only accessible from within pod
- No external ports exposed
- Communicates only with worker via localhost

## CI/CD Pipeline

### GitHub Actions Workflow

Located in `.github/workflows/deploy-production.yml`:

```yaml
jobs:
  build-implementation:
    # Build container image
    # Push to quay.io
  
  deploy-vps:
    needs: [build-worker, build-dashboard, build-implementation]
    # SSH to VPS
    # podman pod stop/rm ai-sdlc
    # podman pod create ai-sdlc
    # podman run worker
    # podman run dashboard
    # podman run implementation
```

**Triggers:**
- Push to main (paths: `future-go/components/implementation/**`)
- Manual workflow dispatch

## References

- **Container:** [future-go/components/implementation/Containerfile](Containerfile)
- **Service Code:** [future-go/components/implementation/](.)
- **CI/CD:** [.github/workflows/deploy-production.yml](../../../.github/workflows/deploy-production.yml)
- **Architecture:** [ARCHITECTURE-ANALYSIS.md](../../../ARCHITECTURE-ANALYSIS.md)

---

**Last Updated:** 2026-08-29  
**Deployment Model:** Podman Pods on VPS  
**Registry:** quay.io  
**Status:** Production
