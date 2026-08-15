# 🚀 Plan: AI-SDLC Local Funcional en Contenedores

**Fecha**: 2026-08-08  
**Objetivo**: Setup local completo end-to-end (issue → PR → producción)  
**Target**: WSL2 Fedora con Podman

---

## 🎯 Objetivo

Ejecutar worker AI-SDLC **completamente en local** para:
1. Seleccionar issue en GitHub
2. Worker lo procesa (SCC genera código)
3. Crea PR automáticamente
4. Validar sin depender de GitHub Actions

---

## 📊 Estado Actual

### **Bloqueadores Conocidos** (7 intentos previos)

❌ **Problema git clone en container**:
```
/srv/homedir-sdlc/worktrees/homedir/.git: Permission denied
```

**Root cause**: git clone intenta crear subdirectorio `.git` dentro de volume montado

---

## 🔧 Solución: Enfoque Alternativo

### **Cambio de Estrategia: NO usar volumes para worktrees**

**Problema actual**:
```yaml
# ACTUAL (falla)
podman run -v ./worktrees:/srv/homedir-sdlc/worktrees
# git clone dentro de volume → Permission denied
```

**Solución nueva**:
```yaml
# NUEVO (evita volumes para git)
podman run -v ./state:/var/lib/homedir-sdlc
# git clone DENTRO del container (no en volume)
# Solo state persiste entre runs
```

### **Arquitectura Nueva**

```
Host:
  ./local-state/           # Mounted volume
    ├── issues/
    ├── prs/
    ├── run-summaries/
    └── autonomous-decisions/

Container (ephemeral):
  /srv/homedir-sdlc/worktrees/homedir/  # Git clone aquí (NO mounted)
  /var/lib/homedir-sdlc/                # Mounted (state only)
  /var/log/homedir-sdlc/                # Mounted (logs)
```

**Ventajas**:
- ✅ git clone en filesystem del container (no permission issues)
- ✅ State persiste en volume
- ✅ Logs accesibles desde host
- ✅ Worktree ephemeral (se recrea cada run)

---

## 📋 Plan de Implementación

### **Fase 1: Preparar Environment Local**

#### **1.1 Instalar Podman en WSL2**

```bash
wsl -d fedoraremix

# Si no está instalado:
sudo dnf install -y podman

# Verificar
podman --version
```

#### **1.2 Crear Estructura Local**

```bash
cd /mnt/d/git/homedir-ai-sdlc

# Crear directorios de estado
mkdir -p local-state/{issues,prs,run-summaries,autonomous-decisions}
mkdir -p local-logs

# Crear config
cat > local-state/config.env <<'EOF'
HOMEDIR_SDLC_REPO=os-santiago/homedir
HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc
HOMEDIR_SDLC_WORKDIR=/srv/homedir-sdlc/worktrees/homedir
HOMEDIR_SDLC_LOGFILE=/var/log/homedir-sdlc/worker.log
HOMEDIR_SDLC_MAX_ISSUES_PER_RUN=1
GH_TOKEN=${GH_TOKEN}
SC_API_KEY=${SC_API_KEY}
EOF
```

---

### **Fase 2: Build Worker Image**

```bash
# En WSL2
cd /mnt/d/git/homedir-ai-sdlc

podman build \
  -f container/Containerfile.worker \
  -t homedir-ai-sdlc:local \
  .
```

**Containerfile ya está rootless-compatible** ✅:
- No USER directive
- chmod 777 en state dirs
- chmod 755 en /app

---

### **Fase 3: Crear Script de Ejecución Local**

**Archivo**: `local-run-worker.sh`

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== AI-SDLC Local Worker ===${NC}"

# Check environment
if [[ -z "${GH_TOKEN}" ]]; then
  echo -e "${RED}ERROR: GH_TOKEN not set${NC}"
  exit 1
fi

if [[ -z "${SC_API_KEY}" ]]; then
  echo -e "${YELLOW}WARNING: SC_API_KEY not set (SCC won't work)${NC}"
fi

# Prepare state
mkdir -p "${SCRIPT_DIR}/local-state"/{issues,prs,run-summaries,autonomous-decisions}
mkdir -p "${SCRIPT_DIR}/local-logs"

# Create env file
cat > "${SCRIPT_DIR}/local-state/runtime.env" <<EOF
HOMEDIR_SDLC_REPO=os-santiago/homedir
HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc
HOMEDIR_SDLC_WORKDIR=/srv/homedir-sdlc/worktrees/homedir
HOMEDIR_SDLC_LOGFILE=/var/log/homedir-sdlc/worker.log
HOMEDIR_SDLC_MAX_ISSUES_PER_RUN=1
HOMEDIR_SDLC_WORKER_VERSION=local-dev
GH_TOKEN=${GH_TOKEN}
SC_API_KEY=${SC_API_KEY:-}
PLATFORM_DIR=/app
EOF

echo -e "${GREEN}Running worker container...${NC}"

# Run container
podman run --rm \
  --user $(id -u):$(id -g) \
  -e HOME=/tmp \
  --env-file "${SCRIPT_DIR}/local-state/runtime.env" \
  -v "${SCRIPT_DIR}/local-state:/var/lib/homedir-sdlc:Z" \
  -v "${SCRIPT_DIR}/local-logs:/var/log/homedir-sdlc:Z" \
  homedir-ai-sdlc:local \
  reconcile

EXIT_CODE=$?

echo ""
echo -e "${GREEN}=== Worker Complete ===${NC}"
echo "Exit code: ${EXIT_CODE}"

# Show logs
if [[ -f "${SCRIPT_DIR}/local-logs/worker.log" ]]; then
  echo ""
  echo -e "${GREEN}=== Last 30 Lines of Log ===${NC}"
  tail -30 "${SCRIPT_DIR}/local-logs/worker.log"
fi

# Show state
echo ""
echo -e "${GREEN}=== State Directory ===${NC}"
find "${SCRIPT_DIR}/local-state" -type f -mmin -5 2>/dev/null | head -10

exit ${EXIT_CODE}
```

**Características**:
- ✅ Verifica GH_TOKEN
- ✅ Crea directorios automáticamente
- ✅ Monta solo state y logs (NO worktrees)
- ✅ Usa `:Z` para SELinux relabeling
- ✅ Muestra logs al terminar

---

### **Fase 4: Script Helper para Issues**

**Archivo**: `local-mark-issue.sh`

```bash
#!/bin/bash
set -e

ISSUE_NUMBER=$1

if [[ -z "${ISSUE_NUMBER}" ]]; then
  echo "Usage: $0 <issue-number>"
  exit 1
fi

if [[ -z "${GH_TOKEN}" ]]; then
  echo "ERROR: GH_TOKEN not set"
  exit 1
fi

echo "Marking issue #${ISSUE_NUMBER} for AI-SDLC..."

gh issue edit ${ISSUE_NUMBER} \
  -R os-santiago/homedir \
  --add-label "ready-to-implement"

echo "✅ Issue #${ISSUE_NUMBER} marked"
echo ""
echo "Now run: ./local-run-worker.sh"
```

---

### **Fase 5: Test End-to-End Local**

#### **5.1 Seleccionar Issue Simple**

```bash
# Buscar issue sin PR
gh issue list -R os-santiago/homedir \
  --label bug \
  --state open \
  --limit 10

# Seleccionar uno (ejemplo: #1305)
```

#### **5.2 Marcar para AI-SDLC**

```bash
./local-mark-issue.sh 1305
```

#### **5.3 Ejecutar Worker**

```bash
./local-run-worker.sh
```

#### **5.4 Verificar Resultado**

```bash
# Ver logs
tail -100 local-logs/worker.log

# Buscar PR creado
gh pr list -R os-santiago/homedir \
  --search "1305" \
  --limit 3

# Ver estado
cat local-state/heartbeat.json | jq .
```

---

## 🔧 Troubleshooting

### **Error: Permission Denied en git clone**

**Si aún falla**, el problema puede ser que el entrypoint intenta crear
`/srv/homedir-sdlc/worktrees/homedir` y no puede.

**Fix**: Modificar entrypoint para crear dir con permisos correctos

```bash
# En worker-entrypoint.sh (línea ~119)
# ANTES:
mkdir -p "${HOMEDIR_SDLC_WORKDIR}"

# DESPUÉS:
mkdir -p "${HOMEDIR_SDLC_WORKDIR}" || {
  log "WARN: Cannot create ${HOMEDIR_SDLC_WORKDIR}"
  log "INFO: Creating with sudo..."
  sudo mkdir -p "${HOMEDIR_SDLC_WORKDIR}"
  sudo chown $(id -u):$(id -g) "${HOMEDIR_SDLC_WORKDIR}"
}
```

**Mejor**: Pre-crear en container build

```dockerfile
# En Containerfile.worker
RUN mkdir -p /srv/homedir-sdlc/worktrees && \
    chmod -R 777 /srv/homedir-sdlc
```

---

### **Error: SCC Not Found**

```bash
# Verificar SCC en container
podman run --rm homedir-ai-sdlc:local which scc

# Si no existe, descargar manual
curl -L https://github.com/anthropics/scc/releases/latest/download/scc-linux-amd64 \
  -o /tmp/scc
chmod +x /tmp/scc
```

---

## 📊 Checklist de Setup

### **Pre-requisitos**

- [ ] WSL2 instalado
- [ ] Fedora distribution en WSL2
- [ ] Podman instalado en WSL2
- [ ] GH_TOKEN configurado
- [ ] SC_API_KEY configurado (NVIDIA)

### **Build**

- [ ] Containerfile.worker actualizado
- [ ] Image built: `homedir-ai-sdlc:local`
- [ ] Image verified: `podman run --rm homedir-ai-sdlc:local --version`

### **Scripts**

- [ ] `local-run-worker.sh` creado y executable
- [ ] `local-mark-issue.sh` creado y executable
- [ ] Directorios `local-state/` y `local-logs/` creados

### **Test**

- [ ] Issue marcado con `ready-to-implement`
- [ ] Worker ejecutado sin errores
- [ ] PR creado en GitHub
- [ ] Logs muestran ejecución completa

---

## 🎯 Expected Flow

```
1. Usuario:
   ./local-mark-issue.sh 1305

2. Worker container starts:
   - Valida environment ✓
   - Configura git ✓
   - Carga policies ✓
   - Inicializa state dirs ✓

3. Reconcile cycle:
   - Busca issues ready-to-implement
   - Encuentra #1305
   - Admission review → ACCEPT
   - git clone homedir (DENTRO container)
   - Ejecuta SCC
   - Genera código
   - Commit changes
   - Push to GitHub
   - Crea PR

4. Output:
   - Logs en local-logs/worker.log
   - State en local-state/
   - PR visible en GitHub
```

---

## 🚀 Next Steps

1. **Immediate**: Setup WSL2 environment
2. **Build**: Container image
3. **Create**: Helper scripts
4. **Test**: Con issue simple
5. **Iterate**: Fix any issues
6. **Document**: Working setup

---

**Tiempo estimado**: 1-2 horas  
**Complejidad**: Media  
**Bloqueadores conocidos**: git clone permissions (solucionable)
