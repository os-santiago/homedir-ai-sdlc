# Proposal: AI-SDLC Full Containerization Architecture

## Current State (Non-Containerized)

### Components
1. **Worker Script** (`homedir-sdlc-worker.sh`)
   - Location: `/home/homedir-sdlc/.local/bin/`
   - Execution: systemd timer (every 3 minutes)
   - Dependencies: `gh`, `git`, `python3`, `jq`, `scc`

2. **SCC Binary**
   - Location: `/home/homedir-sdlc/.local/bin/scc`
   - Version: 0.4.2
   - Distribution: Direct binary download

3. **Dashboard** (Quarkus app)
   - Partially containerized (Containerfile exists)
   - Status: Not fully deployed in container

### Problems with Current Approach

❌ **No version consistency** - SCC updated manually, can drift between environments  
❌ **Manual deployment** - Copy scripts from repo to VPS  
❌ **Configuration drift** - VPS has 2516 lines, repo has 2476 lines  
❌ **No rollback mechanism** - Can't easily revert to previous version  
❌ **Dependency hell** - System packages must match across environments  
❌ **No reproducibility** - Can't guarantee same behavior in dev/staging/prod  

## Proposed Architecture: Fully Containerized

### Design Principles

1. **Single Source of Truth:** All code in Git repository (`os-santiago/homedir-ai-sdlc`)
2. **Immutable Deployments:** Containers built from specific commits, tagged with version
3. **Configuration via Environment:** No hardcoded values in containers
4. **Dependency Bundling:** Each container includes ALL its dependencies
5. **GitOps Workflow:** Deployment triggered by merge to `main`

---

## Container Structure

### 1. Worker Container (`worker:latest`)

**Purpose:** Execute the AI-SDLC worker loop  
**Base Image:** `ubuntu:24.04` or `debian:bookworm-slim`

#### Containerfile
```dockerfile
FROM ubuntu:24.04

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    gh \
    jq \
    python3 \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and install SCC
ARG SCC_VERSION=0.4.2
RUN curl -L "https://github.com/anthropics/claude-code/releases/download/v${SCC_VERSION}/scc-linux-amd64" \
    -o /usr/local/bin/scc && \
    chmod +x /usr/local/bin/scc

# Create non-root user
RUN useradd -m -s /bin/bash homedir-sdlc

# Copy worker scripts
COPY platform/scripts/*.sh /app/scripts/
COPY platform/config/*.yaml /app/config/
RUN chmod +x /app/scripts/*.sh

# Set working directory
WORKDIR /app
USER homedir-sdlc

# Health check
HEALTHCHECK --interval=3m --timeout=10s --start-period=30s \
    CMD /app/scripts/homedir-sdlc-doctor.sh || exit 1

# Entry point
ENTRYPOINT ["/app/scripts/homedir-sdlc-worker.sh"]
CMD ["reconcile"]
```

#### Environment Variables
```bash
# Git configuration
HOMEDIR_SDLC_REPO=os-santiago/homedir
HOMEDIR_SDLC_WORKDIR=/app/worktrees/homedir

# GitHub authentication
GH_TOKEN=${GH_TOKEN}

# SCC configuration
SCC_PROFILE=nvidia
SC_MAX_ITERATIONS=10
SC_API_KEY=${NVIDIA_API_KEY}
HOMEDIR_SDLC_SCC_PERMISSIONS=unlimited
HOMEDIR_SDLC_SCC_CLEAR_HISTORY=true

# State persistence
HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc

# Logging
HOMEDIR_SDLC_LOG_LEVEL=INFO
```

#### Volumes
```yaml
volumes:
  - /var/lib/homedir-sdlc:/var/lib/homedir-sdlc  # State (heartbeat, locks, queue)
  - /srv/homedir-sdlc/worktrees:/app/worktrees   # Git worktrees
  - /home/homedir-sdlc/.config/gh:/home/homedir-sdlc/.config/gh:ro  # GH CLI config
```

---

### 2. SCC Sidecar Container (`scc:latest`)

**Purpose:** Provide SCC as a service (optional architecture)  
**Alternative:** Bundle SCC in worker container (simpler, recommended)

If using sidecar pattern:

```dockerfile
FROM anthropics/claude-code:0.4.2

# Expose SCC as HTTP service (requires wrapper)
COPY tools/scc-http-wrapper.py /app/
EXPOSE 8000

CMD ["python3", "/app/scc-http-wrapper.py"]
```

**Recommendation:** **Don't use sidecar.** Bundle SCC directly in worker container for simplicity.

---

### 3. Dashboard Container (`dashboard:latest`)

**Purpose:** Observability UI for AI-SDLC  
**Current Status:** Containerfile exists, needs refinement

#### Containerfile (Already Exists)
```dockerfile
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY dashboard/quarkus-app/pom.xml .
RUN mvn dependency:go-offline
COPY dashboard/quarkus-app/src ./src
RUN mvn package -DskipTests

FROM eclipse-temurin:21-jre-jammy
COPY --from=build /app/target/quarkus-app /app
EXPOSE 8080
CMD ["java", "-jar", "/app/quarkus-run.jar"]
```

#### Environment Variables
```bash
QUARKUS_HTTP_PORT=8080
HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc
HOMEDIR_SDLC_DASHBOARD_SNAPSHOT_INTERVAL=30s
```

---

## Deployment Architecture

### Pod Composition (Podman)

```yaml
# pod-ai-sdlc.yaml
apiVersion: v1
kind: Pod
metadata:
  name: ai-sdlc
spec:
  containers:
  
  # Worker (main process)
  - name: worker
    image: ghcr.io/os-santiago/homedir-ai-sdlc/worker:latest
    env:
    - name: GH_TOKEN
      valueFrom:
        secretKeyRef:
          name: github-credentials
          key: token
    - name: NVIDIA_API_KEY
      valueFrom:
        secretKeyRef:
          name: nvidia-credentials
          key: api-key
    volumeMounts:
    - name: state
      mountPath: /var/lib/homedir-sdlc
    - name: worktrees
      mountPath: /app/worktrees
    restartPolicy: Always
  
  # Dashboard (observability)
  - name: dashboard
    image: ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:latest
    ports:
    - containerPort: 8080
    volumeMounts:
    - name: state
      mountPath: /var/lib/homedir-sdlc
      readOnly: true
    restartPolicy: Always
  
  volumes:
  - name: state
    hostPath:
      path: /var/lib/homedir-sdlc
      type: Directory
  - name: worktrees
    hostPath:
      path: /srv/homedir-sdlc/worktrees
      type: Directory
```

### Systemd Service (Container Orchestration)

```ini
# /etc/systemd/system/ai-sdlc-pod.service
[Unit]
Description=AI-SDLC Pod
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStartPre=-/usr/bin/podman pod rm -f ai-sdlc
ExecStart=/usr/bin/podman pod create --name ai-sdlc -p 8081:8080
ExecStart=/usr/bin/podman run \
  --pod ai-sdlc \
  --name worker \
  --restart unless-stopped \
  --env-file /etc/ai-sdlc/worker.env \
  -v /var/lib/homedir-sdlc:/var/lib/homedir-sdlc \
  -v /srv/homedir-sdlc/worktrees:/app/worktrees \
  ghcr.io/os-santiago/homedir-ai-sdlc/worker:latest

ExecStart=/usr/bin/podman run \
  --pod ai-sdlc \
  --name dashboard \
  --restart unless-stopped \
  --env-file /etc/ai-sdlc/dashboard.env \
  -v /var/lib/homedir-sdlc:/var/lib/homedir-sdlc:ro \
  ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:latest

ExecStop=/usr/bin/podman pod stop -t 10 ai-sdlc
ExecStopPost=/usr/bin/podman pod rm -f ai-sdlc

Restart=on-failure
RestartSec=30s

[Install]
WantedBy=multi-user.target
```

---

## CI/CD Pipeline

### GitHub Actions Workflow

```yaml
# .github/workflows/build-and-deploy.yml
name: Build and Deploy AI-SDLC

on:
  push:
    branches: [main]
    paths:
      - 'platform/scripts/**'
      - 'dashboard/**'
      - 'container/**'

jobs:
  build-worker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build worker container
        run: |
          podman build -f container/Containerfile.worker \
            -t ghcr.io/os-santiago/homedir-ai-sdlc/worker:${{ github.sha }} \
            -t ghcr.io/os-santiago/homedir-ai-sdlc/worker:latest .
      
      - name: Push to registry
        run: |
          echo ${{ secrets.GITHUB_TOKEN }} | podman login ghcr.io -u ${{ github.actor }} --password-stdin
          podman push ghcr.io/os-santiago/homedir-ai-sdlc/worker:${{ github.sha }}
          podman push ghcr.io/os-santiago/homedir-ai-sdlc/worker:latest
  
  build-dashboard:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build dashboard container
        run: |
          podman build -f container/Containerfile.dashboard \
            -t ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:${{ github.sha }} \
            -t ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:latest .
      
      - name: Push to registry
        run: |
          echo ${{ secrets.GITHUB_TOKEN }} | podman login ghcr.io -u ${{ github.actor }} --password-stdin
          podman push ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:${{ github.sha }}
          podman push ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:latest
  
  deploy:
    needs: [build-worker, build-dashboard]
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to VPS
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.VPS_HOST }}
          username: root
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            # Pull latest images
            podman pull ghcr.io/os-santiago/homedir-ai-sdlc/worker:latest
            podman pull ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:latest
            
            # Restart pod (systemd handles the orchestration)
            systemctl restart ai-sdlc-pod.service
            
            # Verify health
            sleep 30
            systemctl status ai-sdlc-pod.service
            podman healthcheck run worker || exit 1
```

---

## Migration Plan

### Phase 1: Containerize Worker (Week 1)
1. Create `container/Containerfile.worker`
2. Test locally with Podman
3. Set up GitHub Actions to build image
4. Deploy to staging VPS
5. Run parallel with existing systemd service for 48h
6. Cutover to container if metrics stable

### Phase 2: Containerize Dashboard (Week 2)
1. Refine existing `container/Containerfile.dashboard`
2. Build and push to registry
3. Deploy alongside worker in same pod
4. Verify observability works

### Phase 3: Cleanup Legacy (Week 3)
1. Remove systemd timer for bash worker
2. Remove manual script copies in `/home/homedir-sdlc/.local/bin/`
3. Document new deployment process
4. Update runbooks

---

## Benefits of Containerization

### 1. Version Control
- **Before:** Manual sync, drift between VPS and repo
- **After:** Git SHA = Container tag, reproducible deployments

### 2. Rollback
- **Before:** Copy old script back, restart service
- **After:** `podman pull :previous-sha && systemctl restart`

### 3. Testing
- **Before:** Can't test without VPS access
- **After:** `podman run` locally, identical to prod

### 4. Dependencies
- **Before:** System packages, manual SCC install
- **After:** Bundled in container, consistent

### 5. Configuration
- **Before:** Files in home directory, mixed with user data
- **After:** Environment variables, secrets via Podman secrets

### 6. Observability
- **Before:** Log files, manual inspection
- **After:** Podman logs, health checks, metrics

---

## Security Considerations

### Secrets Management
- ✅ Use Podman secrets or Kubernetes secrets (not env vars in Containerfile)
- ✅ Mount GitHub token as read-only volume
- ✅ Rotate secrets without rebuilding containers

### Least Privilege
- ✅ Run as non-root user inside container
- ✅ Read-only filesystem where possible
- ✅ Drop unnecessary capabilities

### Network Isolation
- ✅ Worker only needs outbound to GitHub API
- ✅ Dashboard only exposes port 8080
- ✅ No inter-pod communication needed

---

## Alternatives Considered

### Option 1: Docker Compose
**Pros:** Familiar, declarative  
**Cons:** Requires Docker daemon, not rootless-friendly  
**Decision:** Use Podman (rootless, daemonless)

### Option 2: Kubernetes
**Pros:** Industry standard, scalable  
**Cons:** Overkill for single-pod deployment  
**Decision:** Podman + systemd (simpler)

### Option 3: Keep Bash Scripts
**Pros:** No changes needed  
**Cons:** Continues drift, no version control  
**Decision:** Reject (violates "all changes via PR" principle)

---

## Success Metrics

After containerization (measure 30 days):

- **Deployment time:** < 5 minutes (vs 30+ min manual)
- **Drift incidents:** 0 (vs 2-3 per month)
- **Rollback time:** < 2 minutes (vs 15+ min)
- **Config errors:** < 1 per month (vs 5+ per month)
- **Reproducibility:** 100% (dev = staging = prod)

---

## Next Steps

1. **This PR:** Fix SCC batch mode prompt
2. **Next PR:** Create `container/Containerfile.worker`
3. **Following PR:** Update CI/CD workflow
4. **Final PR:** Update deployment documentation

## References

- Podman: https://podman.io/
- SCC: https://github.com/anthropics/claude-code
- Current worker: `platform/scripts/homedir-sdlc-worker.sh`
