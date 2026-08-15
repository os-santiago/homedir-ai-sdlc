# Worker Deployment Fixes Required

## Problems Found (2026-08-15)

### 1. Worker Cannot Execute Without GitHub CLI in PATH

**Symptom:**
```
GitHub CLI is not authenticated on this server
missing required command: gh
```

**Root Cause:**
The systemd user service doesn't have `/home/homedir-sdlc/.local/bin` in PATH where `gh` binary is located.

**Current Service Location:**
- `/home/homedir-sdlc/.config/systemd/user/homedir-sdlc-worker.service`
- Timer: `/home/homedir-sdlc/.config/systemd/user/homedir-sdlc-worker.timer`

**Fix Required:**
Update systemd service to include correct PATH:

```ini
[Service]
Type=oneshot
ExecStart=/home/homedir-sdlc/.local/bin/homedir-sdlc-worker.sh reconcile
EnvironmentFile=/home/homedir-sdlc/.config/homedir-sdlc/env
Environment=PATH=/home/homedir-sdlc/.local/bin:/usr/local/bin:/usr/bin:/bin
StandardOutput=append:/var/lib/homedir-sdlc/logs/worker.log
StandardError=append:/var/lib/homedir-sdlc/logs/worker.log
```

### 2. STATE_DIR Configuration Mismatch

**Symptom:**
Dashboard cannot read worker state because files are in wrong location.

**Root Cause:**
Worker default: `/var/lib/homedir-sdlc`  
Actual location: `/home/homedir-sdlc/.local/state/homedir-sdlc`

**Fix Required:**
Standardize on `/var/lib/homedir-sdlc` via environment file:

```bash
# /home/homedir-sdlc/.config/homedir-sdlc/env
export HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc
export HOMEDIR_SDLC_LOGFILE=/var/lib/homedir-sdlc/logs/worker.log
export HOMEDIR_SDLC_HEARTBEAT_FILE=/var/lib/homedir-sdlc/heartbeat.json
```

**Directory Setup:**
```bash
sudo mkdir -p /var/lib/homedir-sdlc/{logs,issues,prs,run-summaries}
sudo chown -R homedir-sdlc:homedir-sdlc /var/lib/homedir-sdlc
sudo chmod 755 /var/lib/homedir-sdlc
sudo chmod 755 /var/lib/homedir-sdlc/{logs,issues,prs,run-summaries}
sudo chmod 644 /var/lib/homedir-sdlc/heartbeat.json
```

### 3. Dashboard Not Deployed

**Symptom:**
https://homedir-ai-sdlc.opensourcesantiago.io/dashboard/ returns 404

**Root Cause:**
Dashboard application was never compiled or deployed. Only source code exists.

**Fix Required:**

1. **Create GitHub Actions Workflow** (`.github/workflows/build-dashboard.yml`):
```yaml
name: Build and Deploy Dashboard

on:
  push:
    branches: [main]
    paths:
      - 'dashboard/**'
      - '.github/workflows/build-dashboard.yml'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
      
      - name: Build dashboard
        run: |
          cd dashboard/quarkus-app
          ./mvnw package -DskipTests
      
      - name: Build container
        run: |
          podman build -f container/Containerfile.dashboard \
            -t ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:latest \
            -t ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:${{ github.sha }} .
      
      - name: Push to registry
        run: |
          echo ${{ secrets.GITHUB_TOKEN }} | podman login ghcr.io -u ${{ github.actor }} --password-stdin
          podman push ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:latest
          podman push ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:${{ github.sha }}
  
  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to VPS
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.VPS_HOST }}
          username: ${{ secrets.VPS_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            podman pull ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:latest
            podman stop ai-sdlc-dashboard || true
            podman rm ai-sdlc-dashboard || true
            podman run -d \
              --name ai-sdlc-dashboard \
              --restart unless-stopped \
              -p 8081:8080 \
              -v /var/lib/homedir-sdlc:/var/lib/homedir-sdlc:ro \
              -e HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc \
              ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:latest
```

2. **Create Containerfile** (`container/Containerfile.dashboard`):
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

3. **Update nginx config** to proxy `/dashboard` to port 8081

## Deployment Process

### Current Manual Deployment (WRONG ❌)
```bash
ssh vps
# Manual edits to systemd service
# Manual configuration changes
```

### Correct Deployment Process (RIGHT ✅)

1. Create PR with fixes:
   - Updated systemd service template
   - Updated environment file template
   - New GitHub Actions workflow
   - New Containerfile

2. Merge PR → main

3. CI/CD automatically:
   - Builds dashboard container
   - Pushes to ghcr.io
   - Deploys to VPS
   - Restarts services

4. Manual VPS setup (ONE TIME):
   ```bash
   # Create state directory
   sudo mkdir -p /var/lib/homedir-sdlc/{logs,issues,prs,run-summaries}
   sudo chown -R homedir-sdlc:homedir-sdlc /var/lib/homedir-sdlc
   sudo chmod 755 /var/lib/homedir-sdlc
   
   # Copy systemd service from repo
   sudo -u homedir-sdlc cp platform/systemd/user/homedir-sdlc-worker.service \
     ~/.config/systemd/user/
   
   # Copy environment config from repo
   sudo -u homedir-sdlc cp platform/env.sdlc.example \
     ~/.config/homedir-sdlc/env
   # Edit env file to add secrets (GH_TOKEN, API keys)
   
   # Reload systemd
   sudo -u homedir-sdlc systemctl --user daemon-reload
   sudo -u homedir-sdlc systemctl --user enable --now homedir-sdlc-worker.timer
   ```

## Files to Create/Update in PR

1. `platform/systemd/user/homedir-sdlc-worker.service` - Update with correct PATH
2. `platform/env.sdlc.example` - Update with STATE_DIR variables
3. `container/Containerfile.dashboard` - New file
4. `.github/workflows/build-dashboard.yml` - New file
5. `docs/deployment/dashboard-deployment.md` - New documentation
6. `docs/deployment/vps-setup.md` - One-time setup instructions

## Testing Plan

After PR merge:

1. Verify CI/CD builds dashboard container
2. Verify container is pushed to ghcr.io
3. Verify deployment to VPS
4. Verify dashboard accessible at https://homedir-ai-sdlc.opensourcesantiago.io/
5. Verify dashboard shows worker heartbeat and metrics
6. Verify worker processes issues correctly

## Success Criteria

- [ ] Dashboard web UI loads and shows data
- [ ] Worker executes without "missing gh" errors
- [ ] Worker writes to /var/lib/homedir-sdlc/
- [ ] Dashboard reads from /var/lib/homedir-sdlc/
- [ ] All changes deployed via CI/CD (no manual edits)

## References

- Worker prompt fix: PR #7 (already merged)
- Containerization proposal: `docs/proposals/containerization-architecture.md`
