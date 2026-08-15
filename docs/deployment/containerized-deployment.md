# Containerized Deployment Guide

## Architecture Overview

AI-SDLC is fully containerized using Podman. All components run in OCI containers:

- **Worker Container**: Executes AI-SDLC worker loop (issue processing)
- **Dashboard Container**: Quarkus application for observability

### Why Containerized?

✅ **Immutable deployments** - Every update = rebuild + redeploy containers  
✅ **Version control** - Git commit SHA = Container tag  
✅ **Rollback** - `podman pull :previous-sha && restart`  
✅ **Reproducibility** - Dev = Staging = Production  
✅ **No host dependencies** - Everything bundled in containers  
✅ **CI/CD automated** - PR → Merge → Build → Deploy (zero manual steps)

---

## Quick Start

### Prerequisites

1. VPS with:
   - Podman installed
   - User with podman permissions
   - Ports 8081 available

2. GitHub Secrets configured:
   - `VPS_HOST`: VPS IP address
   - `VPS_USER`: SSH username (recommend `root` for deployment)
   - `VPS_SSH_KEY`: Private SSH key
   - `GH_TOKEN`: GitHub token for worker
   - `NVIDIA_API_KEY`: API key for SCC

### Initial VPS Setup

```bash
# 1. SSH to VPS
ssh root@your-vps-ip

# 2. Install Podman (if not installed)
apt-get update && apt-get install -y podman

# 3. Create required directories
mkdir -p /var/lib/homedir-sdlc/{logs,issues,prs,run-summaries}
mkdir -p /srv/homedir-sdlc/worktrees
mkdir -p /etc/homedir-sdlc

# 4. Set permissions
chmod 755 /var/lib/homedir-sdlc
chmod 755 /srv/homedir-sdlc

# 5. Create worker environment file
cat > /etc/homedir-sdlc/worker.env << 'EOF'
# GitHub Configuration
GH_TOKEN=your_github_token_here
HOMEDIR_SDLC_REPO=os-santiago/homedir

# SCC Configuration
HOMEDIR_SDLC_SCC_PROFILE=nvidia
SC_MAX_ITERATIONS=10
SC_API_KEY=your_nvidia_api_key_here
HOMEDIR_SDLC_SCC_PERMISSIONS=unlimited
HOMEDIR_SDLC_SCC_CLEAR_HISTORY=true

# State Configuration
HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc
HOMEDIR_SDLC_LOGFILE=/var/lib/homedir-sdlc/logs/worker.log
HOMEDIR_SDLC_HEARTBEAT_FILE=/var/lib/homedir-sdlc/heartbeat.json

# Worker Configuration
HOMEDIR_SDLC_WORKDIR=/srv/homedir-sdlc/worktrees/homedir
HOMEDIR_SDLC_MAX_ISSUES_PER_RUN=1
HOMEDIR_SDLC_MAX_REMEDIATION_ATTEMPTS=5

# Logging
HOMEDIR_SDLC_LOG_LEVEL=INFO
EOF

# 6. Secure the env file
chmod 600 /etc/homedir-sdlc/worker.env
```

### Deploy via GitHub Actions

1. **Push to main branch** - Deployment is automatic:

```bash
git push origin main
```

2. **Monitor deployment** in GitHub Actions:
   - Go to: https://github.com/os-santiago/homedir-ai-sdlc/actions
   - Watch "Build and Deploy to Production" workflow

3. **Verify deployment** on VPS:

```bash
# Check pod status
podman pod ps

# Check containers
podman ps

# View worker logs
podman logs -f ai-sdlc-worker

# View dashboard logs
podman logs -f ai-sdlc-dashboard

# Check heartbeat
cat /var/lib/homedir-sdlc/heartbeat.json
```

---

## CI/CD Pipeline

### Automatic Deployment Flow

```
┌──────────────┐
│  Git Push    │
│  to main     │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  GitHub      │
│  Actions     │
│  Triggered   │
└──────┬───────┘
       │
       ├─────────────────────┬────────────────────┐
       ▼                     ▼                    ▼
┌──────────────┐      ┌──────────────┐    ┌──────────────┐
│ Build Worker │      │Build Dashboard│    │              │
│ Container    │      │  Container    │    │              │
└──────┬───────┘      └──────┬────────┘    │              │
       │                     │              │              │
       ▼                     ▼              │              │
┌──────────────┐      ┌──────────────┐    │              │
│ Push to      │      │  Push to     │    │              │
│ ghcr.io      │      │  ghcr.io     │    │              │
└──────┬───────┘      └──────┬────────┘    │              │
       │                     │              │              │
       └─────────┬───────────┘              │              │
                 ▼                          ▼              ▼
          ┌──────────────┐          ┌──────────────────────┐
          │              │          │   Deploy to VPS      │
          │              ├─────────►│   - Pull images      │
          │              │          │   - Stop old pod     │
          │              │          │   - Start new pod    │
          │              │          │   - Verify health    │
          └──────────────┘          └──────────────────────┘
                                             │
                                             ▼
                                    ┌──────────────────┐
                                    │   Production     │
                                    │   Running        │
                                    └──────────────────┘
```

### Workflow Steps

1. **Build Worker** (`build-worker` job)
   - Builds `container/Containerfile.worker`
   - Tags: `latest`, `main-<sha>`, `YYYYMMDD-HHmmss`
   - Tests basic execution
   - Pushes to `ghcr.io/os-santiago/homedir-ai-sdlc/worker`

2. **Build Dashboard** (`build-dashboard` job)
   - Builds Quarkus application
   - Multi-stage build (Maven → JRE)
   - Pushes to `ghcr.io/os-santiago/homedir-ai-sdlc/dashboard`

3. **Deploy to VPS** (`deploy-vps` job)
   - SSH to VPS
   - Pull latest container images
   - Stop existing pod
   - Create new pod with containers
   - Verify health checks
   - Generate deployment summary

---

## Manual Deployment

If you need to deploy manually (bypass CI/CD):

```bash
# 1. SSH to VPS
ssh root@your-vps-ip

# 2. Pull latest images
podman pull ghcr.io/os-santiago/homedir-ai-sdlc/worker:latest
podman pull ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:latest

# 3. Stop existing pod
podman pod stop ai-sdlc
podman pod rm ai-sdlc

# 4. Create new pod
podman pod create --name ai-sdlc -p 8081:8080

# 5. Start worker
podman run -d \
  --pod ai-sdlc \
  --name ai-sdlc-worker \
  --restart unless-stopped \
  --env-file /etc/homedir-sdlc/worker.env \
  -v /var/lib/homedir-sdlc:/var/lib/homedir-sdlc \
  -v /srv/homedir-sdlc/worktrees:/srv/homedir-sdlc/worktrees \
  ghcr.io/os-santiago/homedir-ai-sdlc/worker:latest

# 6. Start dashboard
podman run -d \
  --pod ai-sdlc \
  --name ai-sdlc-dashboard \
  --restart unless-stopped \
  -e HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc \
  -v /var/lib/homedir-sdlc:/var/lib/homedir-sdlc:ro \
  ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:latest

# 7. Verify
podman pod ps
podman ps
podman logs ai-sdlc-worker
```

---

## Rollback

To rollback to a previous version:

```bash
# 1. Find previous image SHA
# Go to: https://github.com/os-santiago/homedir-ai-sdlc/actions
# Copy SHA from successful previous deployment

# 2. Pull specific version
podman pull ghcr.io/os-santiago/homedir-ai-sdlc/worker:main-<previous-sha>
podman pull ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:main-<previous-sha>

# 3. Stop current pod
podman pod stop ai-sdlc && podman pod rm ai-sdlc

# 4. Start with old version
podman pod create --name ai-sdlc -p 8081:8080

podman run -d --pod ai-sdlc --name ai-sdlc-worker \
  --restart unless-stopped \
  --env-file /etc/homedir-sdlc/worker.env \
  -v /var/lib/homedir-sdlc:/var/lib/homedir-sdlc \
  -v /srv/homedir-sdlc/worktrees:/srv/homedir-sdlc/worktrees \
  ghcr.io/os-santiago/homedir-ai-sdlc/worker:main-<previous-sha>

podman run -d --pod ai-sdlc --name ai-sdlc-dashboard \
  --restart unless-stopped \
  -e HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc \
  -v /var/lib/homedir-sdlc:/var/lib/homedir-sdlc:ro \
  ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:main-<previous-sha>
```

---

## Monitoring

### Health Checks

```bash
# Worker health
podman healthcheck run ai-sdlc-worker

# Dashboard health
curl http://localhost:8081/q/health/live
```

### Logs

```bash
# Follow worker logs
podman logs -f ai-sdlc-worker

# Follow dashboard logs
podman logs -f ai-sdlc-dashboard

# Last 100 lines
podman logs --tail 100 ai-sdlc-worker
```

### Heartbeat

```bash
# Worker heartbeat (updated every 3 min)
cat /var/lib/homedir-sdlc/heartbeat.json | jq '.'

# Check heartbeat age
python3 << 'EOF'
import json, time
h = json.load(open('/var/lib/homedir-sdlc/heartbeat.json'))
age = time.time() - time.mktime(time.strptime(h['updated_at'], '%Y-%m-%dT%H:%M:%SZ'))
print(f"Heartbeat age: {age:.0f} seconds")
if age > 300:
    print("⚠️  WARNING: Heartbeat is stale!")
else:
    print("✅ Heartbeat is fresh")
EOF
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
podman logs ai-sdlc-worker

# Check environment
podman exec ai-sdlc-worker env | grep HOMEDIR

# Verify volumes
podman inspect ai-sdlc-worker | jq '.[0].Mounts'
```

### Worker Not Processing Issues

```bash
# Check GitHub token
podman exec ai-sdlc-worker gh auth status

# Check SCC
podman exec ai-sdlc-worker scc --version

# Manual test
podman exec -it ai-sdlc-worker bash
cd /app
./scripts/homedir-sdlc-worker.sh reconcile
```

### Dashboard Not Accessible

```bash
# Check port mapping
podman pod ps
podman port ai-sdlc-dashboard

# Check logs
podman logs ai-sdlc-dashboard

# Test from inside VPS
curl http://localhost:8081/q/health
```

---

## Advantages Over Previous Approach

### Before (systemd + bash scripts)
- ❌ Manual script copies to VPS
- ❌ Configuration drift (VPS ≠ repo)
- ❌ No rollback mechanism
- ❌ Dependency hell (gh, scc versions)
- ❌ Manual env file edits
- ❌ No reproducibility

### After (Containerized)
- ✅ Automatic deployment via CI/CD
- ✅ Git commit = Container version
- ✅ Instant rollback (pull previous image)
- ✅ All dependencies bundled
- ✅ Configuration via environment
- ✅ 100% reproducible

---

## Security

### Secrets Management

```bash
# NEVER commit secrets to Git
# Store in /etc/homedir-sdlc/worker.env with mode 600

# Verify permissions
ls -la /etc/homedir-sdlc/worker.env
# Should show: -rw------- (600)

# Rotate secrets
vi /etc/homedir-sdlc/worker.env
podman pod restart ai-sdlc
```

### Container Security

```bash
# Containers run as non-root
podman exec ai-sdlc-worker whoami
# Output: homedir-sdlc

# No privileged containers
podman inspect ai-sdlc-worker | jq '.[0].HostConfig.Privileged'
# Output: false
```

---

## References

- Container Registry: https://github.com/orgs/os-santiago/packages?repo_name=homedir-ai-sdlc
- GitHub Actions: https://github.com/os-santiago/homedir-ai-sdlc/actions
- Podman Docs: https://docs.podman.io/
- Dashboard: https://homedir-ai-sdlc.opensourcesantiago.io
