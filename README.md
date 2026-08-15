# AI-SDLC: Autonomous Software Development Lifecycle

Sistema autónomo de desarrollo que gestiona el ciclo completo de issues en GitHub desde admission hasta deployment:

**admission** → **planning** → **implementation (SCC)** → **PR creation** → **CI remediation** → **auto-merge** → **deployment verification**

## Estado Actual

- **Autonomía**: 99% (post-fixes 2026-07-12)
- **Tiempo E2E**: 16-20 minutos (issue → merged → deployed)
- **Deployment**: ✅ **Fully Containerized** (Podman) + CI/CD automático
- **Worker**: Bash script (2,476 líneas) + política-driven decision making
- **CI/CD**: Push to main → Build containers → Deploy to production (zero manual steps)

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

### 🚀 Production Deployment (Recommended)

**Fully automated containerized deployment via CI/CD:**

```bash
# 1. One-time VPS setup (run as root)
curl -fsSL https://raw.githubusercontent.com/os-santiago/homedir-ai-sdlc/main/scripts/vps-initial-setup.sh | bash

# 2. Configure secrets in /etc/homedir-sdlc/worker.env

# 3. Deploy: Push to main branch
git push origin main
# → Automatic build → Push to ghcr.io → Deploy to VPS
```

**Key benefits:**
- ✅ Immutable deployments (Git commit = Container version)
- ✅ Instant rollback (pull previous image)
- ✅ Zero manual steps after initial setup
- ✅ All dependencies bundled in container

See complete guide: **[docs/deployment/containerized-deployment.md](docs/deployment/containerized-deployment.md)**

### 🧪 Local Development

```bash
# Build containers locally
podman build -f container/Containerfile.worker -t ai-sdlc-worker:dev .

# Run worker container
podman run --rm \
  -e GH_TOKEN=your_token \
  -e HOMEDIR_SDLC_REPO=os-santiago/homedir \
  -v $(pwd)/state:/var/lib/homedir-sdlc \
  ai-sdlc-worker:dev

# Run dashboard
cd dashboard/quarkus-app
./mvnw quarkus:dev
# Access: http://localhost:8081
```

### 📜 Legacy Deployment (Systemd)

**Note:** This method is deprecated. Use containerized deployment above.

<details>
<summary>Click to see legacy systemd deployment</summary>

```bash
# Bootstrap automático (requiere sudo)
curl -fsSL https://raw.githubusercontent.com/os-santiago/homedir-ai-sdlc/main/platform/scripts/homedir-sdlc-bootstrap.sh | sudo bash
```

See: [docs/deployment/vps-systemd.md](docs/deployment/vps-systemd.md) (deprecated)
</details>

### Dashboard Development

```bash
cd dashboard/quarkus-app
./mvnw quarkus:dev
# Access: http://localhost:8081/sdlc/dashboard/
```

## Historia

Este sistema fue desarrollado originalmente en el monorepo [os-santiago/homedir](https://github.com/os-santiago/homedir) y migrado a repositorio independiente el **2026-07-31** para evitar acoplamientos con la aplicación principal.

Ver [docs/history/](docs/history/) para reportes detallados de sesiones y evolución del sistema.
