# AI-SDLC: Autonomous Software Development Lifecycle

Sistema autónomo de desarrollo que gestiona el ciclo completo de issues en GitHub desde admission hasta deployment:

**admission** → **planning** → **implementation (SCC)** → **PR creation** → **CI remediation** → **auto-merge** → **deployment verification**

## Estado Actual

- **Autonomía**: 99% (post-fixes 2026-07-12)
- **Tiempo E2E**: 16-20 minutos (issue → merged → deployed)
- **Deployment**: VPS con systemd timer (cada 3 minutos)
- **Worker**: Bash script (2,476 líneas) + política-driven decision making

## Componentes

### 1. Worker Bash (Producción)

Worker autónomo que implementa el ciclo completo:

- **Script principal**: [`platform/scripts/homedir-sdlc-worker.sh`](platform/scripts/homedir-sdlc-worker.sh) (2,476 líneas)
- **Políticas**: [`platform/config/autonomous-decision-policy.yaml`](platform/config/autonomous-decision-policy.yaml) (723 líneas)
- **Deployment**: VPS con systemd timer
- **State**: Filesystem-based JSON + event journal JSONL
- **Integración**: GitHub CLI + SCC (Software Construction Copilot)

### 2. Dashboard Observabilidad

Aplicación Quarkus standalone para monitoreo en tiempo real (puerto 8081)

### 3. Arquitectura Futura (Go)

Prototipo de microservicios en [`future-go/`](future-go/) con 4 componentes: admission-controller, orchestrator, worker, release-manager.

## Quick Start

### Deployment Options

**Option 1: VPS with Systemd** (Recommended for production)

```bash
# Bootstrap automático (requiere sudo)
curl -fsSL https://raw.githubusercontent.com/os-santiago/homedir-ai-sdlc/main/platform/scripts/homedir-sdlc-bootstrap.sh | sudo bash

# O bootstrap sin sudo (user-owned)
curl -fsSL https://raw.githubusercontent.com/os-santiago/homedir-ai-sdlc/main/platform/scripts/homedir-sdlc-user-bootstrap.sh | bash
```

See complete guide: [docs/deployment/vps-systemd.md](docs/deployment/vps-systemd.md)

**Option 2: Container (Podman/Docker)**

```bash
# Build
podman build -f container/Containerfile.worker -t homedir-ai-sdlc:latest .

# Run
podman run -d \
  --name ai-sdlc-worker \
  -e GH_TOKEN=${GH_TOKEN} \
  -e HOMEDIR_SDLC_REPO=os-santiago/homedir \
  -v /var/lib/homedir-sdlc:/var/lib/homedir-sdlc \
  -v /srv/homedir-sdlc/worktrees:/srv/homedir-sdlc/worktrees \
  homedir-ai-sdlc:latest
```

**Option 3: GitHub Actions Auto-Deploy**

Configure secrets and push to main triggers automatic deployment.  
See: [docs/deployment/github-actions-secrets.md](docs/deployment/github-actions-secrets.md)

### Dashboard Development

```bash
cd dashboard/quarkus-app
./mvnw quarkus:dev
# Access: http://localhost:8081/sdlc/dashboard/
```

## Historia

Este sistema fue desarrollado originalmente en el monorepo [os-santiago/homedir](https://github.com/os-santiago/homedir) y migrado a repositorio independiente el **2026-07-31** para evitar acoplamientos con la aplicación principal.

Ver [docs/history/](docs/history/) para reportes detallados de sesiones y evolución del sistema.
