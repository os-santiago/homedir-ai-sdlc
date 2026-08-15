# Local Testing Guide - AI-SDLC

Guía para probar el AI-SDLC localmente antes del deployment en VPS.

## Prerequisitos

### Requeridos
- ✅ JDK 21 (para dashboard)
- ✅ Maven 3.9+ (incluido mvnw)
- ✅ Bash (Git Bash en Windows)
- ✅ Git

### Opcionales
- GitHub CLI (`gh`) - Para testing completo del worker
- jq - Para manipulación JSON
- Podman/Docker - Para testing de container
- SCC - Para testing E2E completo

## Test 1: Dashboard Quarkus (Local Dev Mode)

### Objetivo
Verificar que el dashboard compila e inicia correctamente.

### Pasos

```bash
cd D:\git\homedir-ai-sdlc\dashboard\quarkus-app

# Iniciar en modo dev
./mvnw quarkus:dev
```

### Verificación

1. **Compilación**: Debe completar sin errores
2. **Startup**: Debe mostrar:
   ```
   Listening on: http://localhost:8081
   ```
3. **Acceso**: Abrir http://localhost:8081

**Endpoints a probar**:
- `http://localhost:8081/q/health` - Health check
- `http://localhost:8081/q/health/live` - Liveness
- `http://localhost:8081/q/health/ready` - Readiness

**Nota**: Los endpoints `/api/sdlc/*` requieren autenticación, por lo que retornarán 401 en local.

### Resultado Esperado

```
✅ Compilation: SUCCESS
✅ Startup: SUCCESS (puerto 8081)
✅ Health endpoints: Responding
⚠️  API endpoints: 401 Unauthorized (esperado)
```

**Tiempo estimado**: 2-3 minutos

---

## Test 2: Worker Script Validation

### Objetivo
Verificar que el worker script no tiene errores de sintaxis.

### Pasos

```bash
cd D:\git\homedir-ai-sdlc

# Verificar sintaxis con --help
bash platform/scripts/homedir-sdlc-worker.sh --help

# Verificar con shellcheck (si disponible)
shellcheck platform/scripts/homedir-sdlc-worker.sh || echo "shellcheck not installed"
```

### Verificación

El script debe mostrar ayuda sin errores:

```
Usage: homedir-sdlc-worker.sh [command]

Commands:
  reconcile    - Run full reconciliation cycle
  status       - Show worker status
  help         - Show this help message
```

### Resultado Esperado

```
✅ Script sintaxis: OK
✅ --help funciona: OK
```

**Tiempo estimado**: 30 segundos

---

## Test 3: Doctor Script

### Objetivo
Diagnosticar dependencias y configuración local.

### Pasos

```bash
cd D:\git\homedir-ai-sdlc

# Ejecutar doctor script
bash platform/scripts/homedir-sdlc-doctor.sh
```

### Verificación

El script verificará:
- ✅ Bash version
- ✅ Git disponible
- ⚠️ GitHub CLI (puede faltar)
- ⚠️ jq (puede faltar)
- ⚠️ SCC (puede faltar)
- ❌ State directories (no existen aún)

### Resultado Esperado

```
✅ Core dependencies: OK
⚠️  Optional dependencies: Some missing (esperado en local)
❌ State directories: Not configured (esperado)
```

**Tiempo estimado**: 1 minuto

---

## Test 4: Entorno Local Mínimo

### Objetivo
Crear estructura mínima para testing local del worker.

### Pasos

```bash
cd D:\git\homedir-ai-sdlc

# Crear directorios de estado locales
mkdir -p .local-test/state/{issues,prs,run-summaries,autonomous-decisions,logs}
mkdir -p .local-test/worktrees

# Crear configuración mínima
cat > .local-test/env << 'EOF'
# Local Testing Configuration
HOMEDIR_SDLC_REPO=os-santiago/homedir
HOMEDIR_SDLC_STATE_DIR=$(pwd)/.local-test/state
HOMEDIR_SDLC_WORKDIR=$(pwd)/.local-test/worktrees/homedir
HOMEDIR_SDLC_LOGFILE=$(pwd)/.local-test/state/logs/worker.log
HOMEDIR_SDLC_MAX_ISSUES_PER_RUN=1
SCC_BIN=/usr/local/bin/scc
GH_TOKEN=YOUR_TOKEN_HERE
EOF

echo "✅ Local test environment created in .local-test/"
```

### Verificación

```bash
ls -la .local-test/
tree .local-test/ || find .local-test/ -type d
```

### Resultado Esperado

```
.local-test/
├── env
├── state/
│   ├── issues/
│   ├── prs/
│   ├── run-summaries/
│   ├── autonomous-decisions/
│   └── logs/
└── worktrees/
```

**Tiempo estimado**: 1 minuto

---

## Test 5: Worker Dry-Run (Requiere GH_TOKEN)

### Objetivo
Ejecutar worker en modo "status" sin procesar issues.

### Prerequisitos

- GitHub CLI instalado: `gh --version`
- Token configurado: `gh auth status`

### Pasos

```bash
cd D:\git\homedir-ai-sdlc

# Configurar token en env local
# Editar .local-test/env y agregar tu GH_TOKEN

# Source environment
source .local-test/env

# Ejecutar status check
bash platform/scripts/homedir-sdlc-status.sh
```

### Verificación

El script debe:
1. Conectarse a GitHub
2. Listar issues con label `ready-to-implement`
3. Mostrar estado actual (sin procesar nada)

### Resultado Esperado

```json
{
  "status": "ok",
  "eligible_issues": 5,
  "worker_version": "unknown",
  "timestamp": "2026-08-01T..."
}
```

**Tiempo estimado**: 1-2 minutos

---

## Test 6: Container Build (Requiere Podman/Docker)

### Objetivo
Verificar que el container se construye correctamente.

### Prerequisitos

```bash
podman --version || docker --version
```

### Pasos

```bash
cd D:\git\homedir-ai-sdlc

# Build con podman
podman build -f container/Containerfile.worker -t homedir-ai-sdlc:test .

# O con docker
docker build -f container/Containerfile.worker -t homedir-ai-sdlc:test .
```

### Verificación

```bash
# Test que imagen inicia
podman run --rm homedir-ai-sdlc:test --help

# Verificar layers
podman images homedir-ai-sdlc:test
```

### Resultado Esperado

```
✅ Build: SUCCESS
✅ Image size: ~500MB-1GB
✅ Container starts: OK
```

**Tiempo estimado**: 5-10 minutos (primera vez, por downloads)

---

## Test 7: Policies Validation

### Objetivo
Verificar que el archivo de políticas es YAML válido.

### Pasos

```bash
cd D:\git\homedir-ai-sdlc

# Validar YAML con Python
python3 -c "import yaml; yaml.safe_load(open('platform/config/autonomous-decision-policy.yaml'))" && echo "✅ YAML válido"

# O con yq si está disponible
yq eval '.' platform/config/autonomous-decision-policy.yaml > /dev/null && echo "✅ YAML válido"
```

### Resultado Esperado

```
✅ YAML syntax: Valid
✅ Policies loaded: 723 lines
```

**Tiempo estimado**: 30 segundos

---

## Test 8: End-to-End Simulation (Avanzado)

### Objetivo
Simular ciclo completo sin SCC.

### Prerequisitos

- GitHub CLI autenticado
- GH_TOKEN configurado
- Permisos en repo de prueba

### Pasos

```bash
cd D:\git\homedir-ai-sdlc

# Source environment
source .local-test/env

# Ejecutar admission review (no ejecuta SCC)
HOMEDIR_SDLC_ENV_FILE=.local-test/env \
bash platform/scripts/homedir-sdlc-worker.sh reconcile --dry-run
```

### Verificación

El worker debe:
1. ✅ Conectar a GitHub
2. ✅ Buscar issues elegibles
3. ✅ Ejecutar admission review
4. ⚠️ Fallar en SCC (esperado si no está instalado)
5. ✅ Generar logs en `.local-test/state/logs/`

### Resultado Esperado

```
✅ GitHub connection: OK
✅ Admission review: OK
⚠️  SCC execution: SKIPPED (not installed)
✅ Logs generated: OK
```

**Tiempo estimado**: 2-3 minutos

---

## Checklist de Testing Local

### Básico (Sin dependencias externas)

- [ ] Dashboard compila (Test 1)
- [ ] Dashboard inicia en :8081
- [ ] Health endpoints responden
- [ ] Worker script --help funciona (Test 2)
- [ ] Scripts no tienen errores de sintaxis
- [ ] Policies YAML es válido (Test 7)

**Tiempo total**: ~5 minutos

### Intermedio (Con GitHub CLI)

- [ ] Doctor script ejecuta (Test 3)
- [ ] Dependencias verificadas
- [ ] Entorno local creado (Test 4)
- [ ] Worker status conecta a GitHub (Test 5)
- [ ] Issues elegibles listados

**Tiempo total**: ~10 minutos

### Avanzado (Con Podman/Docker)

- [ ] Container build exitoso (Test 6)
- [ ] Container inicia correctamente
- [ ] Worker ejecuta en container

**Tiempo total**: ~15-20 minutos

### Completo (E2E)

- [ ] Admission review funciona (Test 8)
- [ ] Estado persistido en archivos
- [ ] Logs generados correctamente

**Tiempo total**: ~25-30 minutos

---

## Resultados Esperados por Test

| Test | Tiempo | Resultado Esperado |
|------|--------|-------------------|
| Dashboard | 2-3 min | ✅ Compila + inicia en :8081 |
| Worker syntax | 30 seg | ✅ Sin errores |
| Doctor | 1 min | ⚠️ Algunas deps faltantes (OK) |
| Local env | 1 min | ✅ Directorios creados |
| Worker status | 1-2 min | ✅ Conecta a GitHub |
| Container | 5-10 min | ✅ Build exitoso |
| Policies | 30 seg | ✅ YAML válido |
| E2E | 2-3 min | ⚠️ SCC skip (esperado) |

---

## Troubleshooting

### Dashboard no inicia

**Error**: `Port 8081 already in use`

**Solución**:
```bash
# Cambiar puerto en application.properties
quarkus.http.port=8082
```

### Worker no encuentra gh

**Error**: `gh: command not found`

**Solución**:
```bash
# Instalar GitHub CLI
# Windows: https://cli.github.com/
# O skip test 5 y 8 (no críticos para validación)
```

### Container build falla

**Error**: `podman/docker not found`

**Solución**:
```bash
# Skip test 6 si no tienes podman/docker
# No es crítico para validación local
```

### SCC no instalado

**Solución**:
```bash
# Es esperado - SCC es opcional para testing local
# El worker ejecutará admission review sin problema
```

---

## Cleanup

Después de testing:

```bash
cd D:\git\homedir-ai-sdlc

# Detener dashboard (Ctrl+C)

# Limpiar entorno local
rm -rf .local-test/

# Limpiar imagen container (opcional)
podman rmi homedir-ai-sdlc:test
```

---

## Conclusión

Con los **tests básicos** (5 min) puedes verificar que:
- ✅ Dashboard compila y funciona
- ✅ Scripts no tienen errores
- ✅ Configuración es válida

Con los **tests intermedios** (10 min) puedes verificar que:
- ✅ Worker puede conectar a GitHub
- ✅ Admission review funciona

Con los **tests completos** (30 min) puedes verificar:
- ✅ Todo el flujo funciona end-to-end
- ✅ Container deployment viable
- ✅ Sistema listo para VPS

**Recomendación**: Ejecutar al menos tests básicos antes de deployment en VPS.
