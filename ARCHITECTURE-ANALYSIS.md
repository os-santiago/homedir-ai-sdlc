# Arquitectura Actual - homedir-ai-sdlc

## Estado Detectado

### Registry
✅ **ghcr.io** (GitHub Container Registry)
- Worker: `ghcr.io/os-santiago/homedir-ai-sdlc/worker:latest`
- Dashboard: `ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:latest`
- Authentication: `${{ secrets.GITHUB_TOKEN }}`

### Deployment Platform
✅ **Podman Pods en VPS**
- Host: `${{ secrets.VPS_HOST }}`
- User: `${{ secrets.VPS_USER }}`
- SSH Key: `${{ secrets.VPS_SSH_KEY }}`

### Pod Structure
```bash
podman pod create \
  --name ai-sdlc \
  -p 8081:8080  # Dashboard port

# Worker (no exposed port - internal only)
podman run -d \
  --pod ai-sdlc \
  --name ai-sdlc-worker \
  --env-file /etc/homedir-sdlc/worker.env \
  -v /var/lib/homedir-sdlc:/var/lib/homedir-sdlc \
  -v /srv/homedir-sdlc/worktrees:/srv/homedir-sdlc/worktrees

# Dashboard (exposes :8080 → pod :8081)
podman run -d \
  --pod ai-sdlc \
  --name ai-sdlc-dashboard \
  -e HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc \
  -v /var/lib/homedir-sdlc:/var/lib/homedir-sdlc:ro
```

### CI/CD Pipeline
```
1. GitHub Actions triggered on push to main
2. Build Worker + Dashboard containers
3. Push to ghcr.io
4. SSH to VPS
5. Stop/remove existing pod
6. Create new pod
7. Pull images from ghcr.io
8. Run containers in pod
9. Verify deployment
```

### Service Discovery
**Dentro del pod:** Containers comparten localhost
```bash
# Worker llama a Implementation:
curl http://localhost:8082/api/implementation/generate

# Worker llama a Dashboard:
curl http://localhost:8080/q/health
```

**Externo:** Solo Dashboard expuesto
```
https://homedir-ai-sdlc.opensourcesantiago.io → nginx → pod:8081 → dashboard:8080
```

---

## Integración Implementation Service

### Opción 1: Agregar al Pod Actual ✅ RECOMENDADO

**Modificar deploy-production.yml:**
```yaml
jobs:
  build-implementation:  # Nuevo job
    name: Build Implementation Container
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        with:
          context: .
          file: future-go/components/implementation/Containerfile
          push: true
          tags: ghcr.io/${{ github.repository }}/implementation:latest

  deploy-vps:
    needs: [build-worker, build-dashboard, build-implementation]  # Agregar dependency
    steps:
      # ... existing worker + dashboard deployment ...
      
      # Agregar después de dashboard:
      - name: Deploy implementation
        script: |
          podman run -d \
            --pod ai-sdlc \
            --name ai-sdlc-implementation \
            --restart unless-stopped \
            -e PORT=8082 \
            -e SC_PROFILE=nvidia \
            -e QUALITY_THRESHOLD=8.0 \
            -e MAX_IMPLEMENTATION_ITERATIONS=3 \
            ghcr.io/os-santiago/homedir-ai-sdlc/implementation:latest
```

**Pod final:**
```
ai-sdlc (pod)
├── ai-sdlc-worker (interno)
├── ai-sdlc-dashboard (puerto 8080 → pod 8081)
└── ai-sdlc-implementation (puerto 8082, interno)
```

**Service discovery:**
```bash
# Worker → Implementation
curl http://localhost:8082/api/implementation/generate
```

### Opción 2: Pod Separado (NO recomendado)

Requeriría:
- Nuevo pod con puerto expuesto
- Networking entre pods (más complejo)
- Worker necesita conocer IP del pod implementation

---

## Cambios Necesarios

### 1. Actualizar Containerfile
❌ **Actual:** Asume sc-agent-cli disponible como binary
✅ **Correcto:** Instalar desde source (como worker)

### 2. Actualizar deploy-production.yml
✅ Agregar job `build-implementation`
✅ Agregar container al pod en `deploy-vps`
✅ Verificar health check

### 3. Remover K8s/Helm (no aplica)
❌ `deploy/helm/implementation/` - NO NECESARIO
❌ `deploy/argocd/` - NO NECESARIO  
❌ `deploy/gitops/` - NO NECESARIO

### 4. Mantener
✅ Go service code (`future-go/components/implementation/`)
✅ README.md con docs
✅ Tests

---

## Workflow Correcto

```
Push to main (paths: future-go/components/implementation/**)
  ↓
GitHub Actions: build-implementation
  ├─ Build Containerfile
  └─ Push to ghcr.io/os-santiago/homedir-ai-sdlc/implementation:latest
  ↓
GitHub Actions: deploy-vps
  ├─ SSH to VPS
  ├─ podman pod stop ai-sdlc
  ├─ podman pod rm ai-sdlc
  ├─ podman pod create ai-sdlc -p 8081:8080
  ├─ podman run worker (inside pod)
  ├─ podman run dashboard (inside pod)
  └─ podman run implementation (inside pod)  ← NUEVO
  ↓
Verification
  └─ curl http://localhost:8082/health
```

---

## Registry Note

**Usuario mencionó quay.io** pero proyecto usa **ghcr.io**

Referencias a quay.io encontradas son del proyecto **homedir** (main app), NO homedir-ai-sdlc:
- `.local-test/worktrees/homedir/` contiene referencias a quay.io
- Proyecto AI-SDLC usa exclusivamente ghcr.io

---

## Next Steps

1. ✅ Corregir Containerfile para instalar sc-agent-cli
2. ✅ Actualizar deploy-production.yml para agregar implementation
3. ❌ Remover Helm/ArgoCD (no aplica a esta arquitectura)
4. ✅ Documentar deployment con Podman
5. ✅ Integrar worker para llamar implementation service
