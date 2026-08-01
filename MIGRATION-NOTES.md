# Notas de Migración - AI-SDLC

**Fecha**: 2026-07-31  
**Repo origen**: [os-santiago/homedir](https://github.com/os-santiago/homedir)  
**Repo destino**: [os-santiago/homedir-ai-sdlc](https://github.com/os-santiago/homedir-ai-sdlc)

## Resumen

Migración completa de componentes ai-sdlc desde el monorepo homedir a repositorio independiente para evitar acoplamientos y permitir evolución independiente.

## Componentes Migrados

### 1. Worker Bash (Platform Scripts)

**Ubicación original**: `homedir/platform/scripts/`  
**Ubicación nueva**: `platform/scripts/`  
**Archivos**: 10 scripts

- `homedir-sdlc-worker.sh` (2,476 líneas - CORE)
- `homedir-sdlc-bootstrap.sh`
- `homedir-sdlc-doctor.sh`
- `homedir-sdlc-labels.sh`
- `homedir-sdlc-openclaw-listener.sh`
- `homedir-sdlc-status.sh`
- `homedir-sdlc-user-bootstrap.sh`
- `sdlc-log-autonomous-decision.sh`
- `policy-loader.sh`
- `policy-matcher.sh`

**Cambios**: Ninguno - copiados sin modificaciones

### 2. Configuración

**Ubicación nueva**: `platform/config/` y `platform/`

- `autonomous-decision-policy.yaml` (723 líneas)
- `env.sdlc.example`

**Ubicación nueva**: `platform/systemd/user/`

- `homedir-sdlc-worker.service`
- `homedir-sdlc-worker.timer`

**Ubicación nueva**: `platform/ansible/playbooks/`

- `sdlc-runner.yml`

**Cambios**: Ninguno - copiados sin modificaciones

### 3. Dashboard Quarkus

**Ubicación original**: `homedir/quarkus-app/src/main/java/com/scanales/homedir/sdlc/`  
**Ubicación nueva**: `dashboard/quarkus-app/src/main/java/io/opensourcesantiago/aisdlc/observability/`

**Archivos Java** (7 archivos):
- `SdlcObservabilityService.java`
- `SdlcDashboardSnapshot.java`
- `SdlcApiResource.java`
- `SdlcDashboardResource.java`
- `SdlcObservabilityServiceTest.java`
- `SdlcDashboardSnapshotTest.java`
- `SdlcApiResourceTest.java`

**Cambios críticos**:
- Package renombrado: `com.scanales.homedir.sdlc` → `io.opensourcesantiago.aisdlc.observability`
- Imports actualizados en todos los archivos

**Frontend** (5 archivos):
- `dashboard.js`
- `dashboard-v2.js`
- `dashboard.css`
- `index.html`
- `index.qute.html` (template)

**Cambios**: Ninguno - copiados sin modificaciones

**Archivos nuevos creados**:
- `pom.xml` - Maven POM standalone (sin dependencias de homedir)
- `application.properties` - Configuración Quarkus (puerto 8081)

### 4. Container

**Ubicación original**: `homedir/container/`  
**Ubicación nueva**: `container/`

**Archivos**:
- `Containerfile.sdlc-worker` → `Containerfile.worker`
- `worker-entrypoint.sh`

**Cambios en Containerfile.worker**:
```diff
- LABEL org.opencontainers.image.source="https://github.com/os-santiago/homedir"
+ LABEL org.opencontainers.image.source="https://github.com/os-santiago/homedir-ai-sdlc"

- LABEL org.opencontainers.image.description="HomeDir AI SDLC Worker - Autonomous software factory"
+ LABEL org.opencontainers.image.description="AI-SDLC Worker - Autonomous software factory"

- # Build:  podman build -f container/Containerfile.sdlc-worker -t homedir-sdlc:latest .
+ # Build:  podman build -f container/Containerfile.worker -t homedir-ai-sdlc:latest .
```

### 5. CI/CD Workflows

**Ubicación original**: `homedir/.github/workflows/`  
**Ubicación nueva**: `.github/workflows/`

**Archivos**:
- `build-sdlc-worker-image.yml` → `build-worker-image.yml`
- `deploy-worker.yml`

**Cambios en build-worker-image.yml**:
```diff
env:
  REGISTRY: ghcr.io
- IMAGE_NAME: ${{ github.repository }}-sdlc
+ IMAGE_NAME: ${{ github.repository }}

paths:
- - 'container/Containerfile.sdlc-worker'
+ - 'container/Containerfile.worker'
+ - 'dashboard/**'
  
- podman build -f container/Containerfile.sdlc-worker
+ podman build -f container/Containerfile.worker
```

**Imagen resultante**: `ghcr.io/os-santiago/homedir-ai-sdlc:latest` (era `homedir-sdlc`)

### 6. Documentación

**Ubicación nueva**: `docs/` y `docs/history/`

**Documentación principal** (4 archivos):
- `HOMEDIR-AI-SDLC-FLOW.md`
- `autonomous-sdlc.md`
- `ai-driven-sdlc-vision-and-implementation.md`
- `ai-sdlc-observability-dashboard.md`

**Documentación específica**:
- `platform/docs/ai-sdlc-ci-check-handling.md`

**Reportes históricos** (14 archivos en `docs/history/`):
- Session summaries (SESSION-*.md)
- E2E test reports (E2E-*.md)
- Fix summaries (FIX-*.md)
- Deployment reports (DEPLOYMENT-*.md)
- Dashboard prompts (DASHBOARD-*.md)
- Status reports (SDLC-*.md)

**Cambios**: Ninguno - copiados sin modificaciones

### 7. Prototipo Go

**Ubicación original**: `homedir/.tmp/homedir-ai-sdlc/`  
**Ubicación nueva**: `future-go/`

**Contenido completo**:
- 4 componentes (admission-controller, orchestrator, worker, release-manager)
- Contracts versionados (commands/events)
- Deploy GitOps (Kustomize)
- Políticas por defecto
- Documentación de arquitectura

**Cambios**: Movido de raíz a subdirectorio `future-go/`

### 8. Archivos Nuevos Creados

**README.md** - Documentación principal del repositorio  
**.gitignore** - Ya existía, se mantuvo  
**MIGRATION-NOTES.md** - Este archivo

## Nombres Importantes que NO CAMBIAR

Según el plan, estos nombres deben mantenerse para compatibilidad con deployment VPS:

**NO CAMBIAR**:
- Directorio state: `/var/lib/homedir-sdlc/` (NO `homedir-ai-sdlc`)
- Usuario: `homedir-sdlc` (NO `ai-sdlc`)
- Variables de entorno: `HOMEDIR_SDLC_*` (NO `AI_SDLC_*`)
- Nombre del worker script: `homedir-sdlc-worker.sh`

**Razón**: El worker AI-SDLC trabaja SOBRE el repo `os-santiago/homedir`, independiente de dónde viva el código del worker.

**SÍ SE CAMBIÓ** (separación correcta):
- Imagen container: `ghcr.io/os-santiago/homedir-ai-sdlc` (era `homedir-sdlc`)
- Package Java: `io.opensourcesantiago.aisdlc.observability` (era `com.scanales.homedir.sdlc`)
- Repo GitHub: `os-santiago/homedir-ai-sdlc` (era parte de `homedir`)

## Estado Actual

✅ **COMPLETADO - Fase 1 y 2 del Plan**

Todas las tareas de migración de código completadas:
1. ✅ Estructura de directorios creada
2. ✅ Scripts Bash copiados (10 archivos)
3. ✅ Dashboard Quarkus migrado con cambio de package (7 archivos Java)
4. ✅ Container y CI/CD adaptados
5. ✅ Documentación migrada (18 archivos)
6. ✅ Prototipo Go movido a future-go/
7. ✅ Archivos de configuración nuevos creados (pom.xml, application.properties)
8. ✅ Commit inicial realizado

**Commit**: `951eff7` - "Initial migration from homedir monorepo"  
**Archivos cambiados**: 101 files  
**Inserciones**: 13,104 líneas

## Próximos Pasos (Según Plan)

### Pendiente - Fase 2.7: Build y Test Local

```bash
# Test dashboard
cd dashboard/quarkus-app
./mvnw clean test
./mvnw quarkus:dev
# Verificar: http://localhost:8081/sdlc/api/status

# Build container
cd ../..
podman build -f container/Containerfile.worker -t homedir-ai-sdlc:test .

# Test container startup
podman run --rm homedir-ai-sdlc:test --help
```

### Pendiente - Fase 3: Deployment Paralelo

1. Configurar GitHub Actions secrets
2. Push a GitHub origin
3. Trigger build automático
4. Deployment paralelo en VPS (dual deployment 24-48h)
5. Monitoreo y comparación de métricas
6. Cutover final si métricas OK

### Pendiente - Fase 5: Actualizar Referencias en Homedir

1. Marcar código deprecated en homedir
2. Actualizar README de homedir
3. Documentar en CLAUDE.md de homedir
4. Crear workflow de cleanup automático (2 semanas después)

## Verificación de Migración

### Archivos críticos verificados:

```bash
# Scripts worker
✅ platform/scripts/homedir-sdlc-worker.sh (94,864 bytes)
✅ platform/config/autonomous-decision-policy.yaml (23KB)

# Dashboard
✅ dashboard/quarkus-app/src/main/java/.../SdlcObservabilityService.java
✅ dashboard/quarkus-app/src/main/java/.../SdlcApiResource.java
✅ dashboard/quarkus-app/pom.xml
✅ dashboard/quarkus-app/src/main/resources/application.properties

# Container
✅ container/Containerfile.worker
✅ container/worker-entrypoint.sh

# CI/CD
✅ .github/workflows/build-worker-image.yml
✅ .github/workflows/deploy-worker.yml

# Docs
✅ docs/HOMEDIR-AI-SDLC-FLOW.md
✅ docs/autonomous-sdlc.md
✅ 14 archivos en docs/history/

# Prototipo Go
✅ future-go/components/ (4 componentes)
✅ future-go/contracts/ (schemas versionados)
✅ future-go/deploy/gitops/ (manifests K8s)
```

### Conteos finales:

- **Scripts Bash**: 10 archivos
- **Configuración**: 2 archivos principales + systemd units
- **Java files**: 7 archivos (4 main + 3 test)
- **Frontend**: 5 archivos (JS/CSS/HTML/Qute)
- **Documentación**: 18+ archivos
- **Workflows**: 2 archivos

## Notas Importantes

1. **Package Java**: Todos los archivos Java fueron actualizados correctamente de `com.scanales.homedir.sdlc` a `io.opensourcesantiago.aisdlc.observability`

2. **Containerfile**: Actualizado para usar `Containerfile.worker` y generar imagen `ghcr.io/os-santiago/homedir-ai-sdlc`

3. **Workflows**: Paths actualizados para incluir `dashboard/**` y referenciar `Containerfile.worker`

4. **Prototipo Go**: Movido a `future-go/` para mantener separación clara entre implementación actual (Bash) y futura (Go)

5. **Estado compartido**: Durante deployment paralelo, ambos workers compartirán `/var/lib/homedir-sdlc/worker.lock` para prevenir duplicados

6. **Timeline estimado**: 
   - Semana 1: ✅ Migración código (COMPLETADO)
   - Semana 2: Deployment paralelo y monitoreo
   - Semana 3: Cutover y validación
   - Semana 4+: Post-migración
   - Día 42 (2026-08-14): Cleanup automático en homedir

## Referencias

- **Plan completo**: `C:\Users\sergi\.claude\plans\purrfect-tumbling-tarjan.md`
- **Repo original**: https://github.com/os-santiago/homedir
- **Issue relacionado**: Problema en producción por cambios ai-sdlc afectando app principal
- **Métricas baseline**: Autonomía 99%, E2E 16-20 min, 5-10 issues/día
