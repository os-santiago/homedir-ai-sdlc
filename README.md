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
# 1. Configure GitHub Secrets (one-time)
# Go to: Settings → Secrets → Actions
# Add: VPS_HOST, VPS_USER, VPS_SSH_KEY
# See: docs/deployment/github-secrets-setup.md

# 2. One-time VPS setup (run as root on VPS)
curl -fsSL https://raw.githubusercontent.com/os-santiago/homedir-ai-sdlc/main/scripts/vps-initial-setup.sh | bash

# 3. Configure worker secrets in VPS
vim /etc/homedir-sdlc/worker.env
# Add: GH_TOKEN, SC_API_KEY

# 4. Deploy: Push to main branch
git push origin main
# → Automatic build → Push to ghcr.io → Deploy to VPS ✨
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

## 📚 Cómo Usar el Sistema

### Crear Issues para el Flujo Autónomo

**[→ Getting Started: Crear Issues](docs/GETTING-STARTED.md)**

Esta guía completa explica:
- ✅ Formato requerido del issue (Description, Current state, Desired state, Acceptance Criteria)
- ✅ Labels obligatorios: `ready-to-implement` + `priority:P3` (o P1/P2)
- ✅ Ejemplos de issues (bug fix simple, feature request, documentación)
- ✅ Timeline del flujo (0 min → issue creado → 20 min → PR merged)
- ✅ Mejores prácticas (principio ADEV, criterios verificables, atomicidad)
- ✅ Troubleshooting (issue no procesado, worker marcó needs-human, etc.)

**Flujo end-to-end típico:**
```
00:00  Creas issue con labels correctos
00:03  Worker detecta y acepta
00:06  SCC genera código
00:15  PR creado
00:19  CI checks pasan
00:20  Auto-merge → Deployed a producción ✓
```

**Tiempo total**: 10-30 minutos sin intervención humana

## 🤝 Contributing

### Branch Protection & PR Workflow

The `main` branch is protected to ensure code quality and stability:

**Protection Rules:**
- ✅ **Pull Requests Required**: Direct pushes to `main` are blocked
- ✅ **CI Checks Required**: `CI / events-service` must pass before merge
- ✅ **Applies to Admins**: Everyone follows the same workflow
- ✅ **No Force Pushes**: History integrity is enforced

**Contribution Workflow (ADEV):**

```bash
# 1. Create an issue first
gh issue create --title "feat: add new feature" --body "Description..."

# 2. Create branch from issue
git checkout -b feat/issue-N-feature-name

# 3. Make changes and commit
git add .
git commit -m "feat: add new feature

Closes #N"

# 4. Push and create PR
git push origin feat/issue-N-feature-name
gh pr create --title "feat: add new feature" --body "Closes #N"

# 5. Wait for CI to pass
# CI runs automatically on PR creation
# Check status: gh pr checks

# 6. Merge when green
gh pr merge --merge --delete-branch
```

**CI Requirements:**
- All PRs must pass `CI / events-service` check
- Build and tests must complete successfully
- Cannot merge with failing CI

**Quality Standards:**
- Follow conventional commits: `feat:`, `fix:`, `docs:`, `ci:`, etc.
- Link PRs to issues with `Closes #N`
- One feature/fix per PR
- Update documentation for user-facing changes

### Running Tests Locally

```bash
# Events Service (Java/Quarkus)
cd events-service
./mvnw clean test

# Worker (Bash)
cd platform/scripts
./run-tests.sh
```

### Development Setup

See [docs/development/](docs/development/) for detailed development guides.

## Historia

Este sistema fue desarrollado originalmente en el monorepo [os-santiago/homedir](https://github.com/os-santiago/homedir) y migrado a repositorio independiente el **2026-07-31** para evitar acoplamientos con la aplicación principal.

Ver [docs/history/](docs/history/) para reportes detallados de sesiones y evolución del sistema.
