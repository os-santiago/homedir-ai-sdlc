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

Ver documentación en [docs/](docs/)

## Historia

Este sistema fue desarrollado originalmente en el monorepo [os-santiago/homedir](https://github.com/os-santiago/homedir) y migrado a repositorio independiente el **2026-07-31** para evitar acoplamientos con la aplicación principal.

Ver [docs/history/](docs/history/) para reportes detallados de sesiones y evolución del sistema.
