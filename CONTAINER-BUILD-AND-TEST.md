# 🐳 Build y Test del Worker en Contenedor

**Fecha**: 2026-08-01  
**Objetivo**: Ejecutar worker AI-SDLC en contenedor para test autónomo real  
**Bloqueador actual**: No hay Docker/Podman instalado en este sistema

---

## ⚠️ Prerequisito: Instalar Container Runtime

### **Opción 1: Docker Desktop (Recomendado para Windows)**

```powershell
# Descargar desde: https://www.docker.com/products/docker-desktop/
# O con winget:
winget install Docker.DockerDesktop
```

### **Opción 2: Podman Desktop**

```powershell
# Descargar desde: https://podman-desktop.io/
# O con winget:
winget install RedHat.Podman-Desktop
```

**Después de instalar, reiniciar terminal y verificar**:
```bash
docker --version
# O
podman --version
```

---

## 🔨 Build de la Imagen

### **Con Docker**

```bash
cd /d/git/homedir-ai-sdlc

# Build
docker build -f container/Containerfile.worker -t homedir-ai-sdlc:latest .

# Verificar
docker images | grep homedir-ai-sdlc
```

### **Con Podman**

```bash
cd /d/git/homedir-ai-sdlc

# Build
podman build -f container/Containerfile.worker -t homedir-ai-sdlc:latest .

# Verificar
podman images | grep homedir-ai-sdlc
```

**Tiempo estimado**: 5-10 minutos (primera vez)

---

## 🧪 Test del Worker en Contenedor

### **Setup de Variables**

```bash
# GitHub token (usa tu token actual)
export GH_TOKEN=$(gh auth token)

# SCC API key (desde config)
export SC_API_KEY="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"
```

### **Ejecutar Worker (One-shot)**

```bash
docker run --rm \
  -e GH_TOKEN="${GH_TOKEN}" \
  -e SC_API_KEY="${SC_API_KEY}" \
  -e HOMEDIR_SDLC_REPO=os-santiago/homedir \
  -e HOMEDIR_SDLC_MAX_ISSUES_PER_RUN=1 \
  -v "$(pwd)/.container-test/state:/var/lib/homedir-sdlc" \
  -v "$(pwd)/.container-test/worktrees:/srv/homedir-sdlc/worktrees" \
  -v "$(pwd)/.container-test/logs:/var/log/homedir-sdlc" \
  homedir-ai-sdlc:latest reconcile
```

**El worker debe**:
1. ✅ Detectar issue #1306 (marcado con `ready-to-implement`)
2. ✅ Ejecutar admission review
3. ✅ **Generar código con SCC** (AUTÓNOMO)
4. ✅ Crear PR
5. ✅ Push a GitHub

### **Monitorear Logs**

```bash
# En otra terminal
tail -f .container-test/logs/worker.log

# Heartbeat
watch -n 5 'cat .container-test/state/heartbeat.json | jq'
```

---

## 🎯 Test de Autonomía Completa

### **Issue Seleccionado: #1306**

**Título**: Footer linkea solo versiones inglesas de privacy/terms

**Tipo**: Bug P3  
**Complejidad**: Simple (cambiar links en footer)  
**Archivos afectados**: Templates de footer

### **Protocolo**

1. ✅ **Issue ya marcado** con `ready-to-implement`
2. ⏳ **Ejecutar worker en contenedor**
3. ⏳ **NO INTERVENIR** - Solo monitorear
4. ⏳ **Documentar resultado**

### **Criterio de Éxito**

✅ Worker completa todo el ciclo sin intervención:
- Detecta issue
- Genera código
- Crea PR
- CI checks pasan
- (Auto-merge pendiente de configurar)

### **Si Falla**

❌ Documentar el error como mejora en AI-SDLC:
- ¿En qué fase falló?
- ¿Cuál fue el error?
- ¿Qué componente necesita mejora?
- Crear issue en homedir-ai-sdlc con el fix

---

## 📦 Push a Quay.io

### **Setup de Quay.io**

```bash
# Login
docker login quay.io
# Usuario: (tu usuario de quay.io)
# Password: (tu token)

# Tag
docker tag homedir-ai-sdlc:latest quay.io/opensourcesantiago/homedir-ai-sdlc:latest

# Push
docker push quay.io/opensourcesantiago/homedir-ai-sdlc:latest
```

### **Configurar Repositorio en Quay.io**

1. Ir a https://quay.io
2. Crear repositorio: `opensourcesantiago/homedir-ai-sdlc`
3. Marcar como **público**
4. Configurar descripción:
   ```
   AI-SDLC Worker - Autonomous software development lifecycle
   
   Processes GitHub issues end-to-end:
   - Admission review
   - Code generation with SCC
   - PR creation
   - CI monitoring
   - Auto-merge
   
   Repository: https://github.com/os-santiago/homedir-ai-sdlc
   ```

### **Tags Sugeridos**

```bash
# Latest
docker tag homedir-ai-sdlc:latest quay.io/opensourcesantiago/homedir-ai-sdlc:latest

# Version
docker tag homedir-ai-sdlc:latest quay.io/opensourcesantiago/homedir-ai-sdlc:v1.0.0

# Date
docker tag homedir-ai-sdlc:latest quay.io/opensourcesantiago/homedir-ai-sdlc:2026-08-01

# Push all
docker push quay.io/opensourcesantiago/homedir-ai-sdlc:latest
docker push quay.io/opensourcesantiago/homedir-ai-sdlc:v1.0.0
docker push quay.io/opensourcesantiago/homedir-ai-sdlc:2026-08-01
```

---

## 🔄 GitHub Actions para Auto-Build

### **Workflow ya existe**: `.github/workflows/build-worker-image.yml`

**Actualizar para Quay.io**:

```yaml
name: Build Worker Image

on:
  push:
    branches: [main]
    paths:
      - 'platform/**'
      - 'container/Containerfile.worker'
      - 'container/worker-entrypoint.sh'
      - 'dashboard/**'

env:
  IMAGE_NAME: quay.io/opensourcesantiago/homedir-ai-sdlc
  
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build image
        run: |
          podman build -f container/Containerfile.worker \
            -t ${{ env.IMAGE_NAME }}:latest \
            -t ${{ env.IMAGE_NAME }}:${{ github.sha }} .
      
      - name: Login to Quay.io
        run: |
          echo "${{ secrets.QUAY_TOKEN }}" | \
          podman login quay.io -u "${{ secrets.QUAY_USERNAME }}" --password-stdin
      
      - name: Push images
        run: |
          podman push ${{ env.IMAGE_NAME }}:latest
          podman push ${{ env.IMAGE_NAME }}:${{ github.sha }}
```

**Secrets necesarios**:
- `QUAY_USERNAME`: Tu usuario de Quay.io
- `QUAY_TOKEN`: Token de Quay.io (Settings → Robot Accounts)

---

## 📊 Estado Actual

### **Completado** ✅

1. ✅ Containerfile.worker validado
2. ✅ Issue #1306 marcado con `ready-to-implement`
3. ✅ Plan de test documentado
4. ✅ SCC local disponible (sc-agent-cli)

### **Bloqueado** ❌

- ❌ Docker/Podman no instalado en este sistema
- ❌ No se puede construir imagen sin container runtime
- ❌ No se puede ejecutar test autónomo

### **Próximos Pasos**

1. **Instalar Docker o Podman** (prerequisito)
2. **Build imagen**: `docker build -f container/Containerfile.worker -t homedir-ai-sdlc:latest .`
3. **Ejecutar worker**: Con variables de entorno correctas
4. **Monitorear**: Logs y estado
5. **Documentar**: Resultado del test autónomo

---

## 🎯 Alternativa: GitHub Actions como Test Environment

Si no quieres instalar Docker localmente, puedes usar GitHub Actions:

### **Crear workflow de test**:

`.github/workflows/test-autonomous.yml`:

```yaml
name: Test Autonomous Worker

on:
  workflow_dispatch:
    inputs:
      issue_number:
        description: 'Issue number to process'
        required: true
        type: string

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build worker image
        run: |
          podman build -f container/Containerfile.worker -t worker:test .
      
      - name: Run worker
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SC_API_KEY: ${{ secrets.SC_API_KEY }}
        run: |
          mkdir -p .test/{state,worktrees,logs}
          
          podman run --rm \
            -e GH_TOKEN \
            -e SC_API_KEY \
            -e HOMEDIR_SDLC_REPO=os-santiago/homedir \
            -e HOMEDIR_SDLC_MAX_ISSUES_PER_RUN=1 \
            -v "$(pwd)/.test/state:/var/lib/homedir-sdlc" \
            -v "$(pwd)/.test/worktrees:/srv/homedir-sdlc/worktrees" \
            -v "$(pwd)/.test/logs:/var/log/homedir-sdlc" \
            worker:test reconcile
      
      - name: Upload logs
        uses: actions/upload-artifact@v4
        with:
          name: worker-logs
          path: .test/logs/
```

**Ejecutar**:
```bash
gh workflow run test-autonomous.yml -f issue_number=1306
```

---

**Estado**: ⏳ **ESPERANDO INSTALACIÓN DE CONTAINER RUNTIME**

Una vez instalado Docker/Podman, continuar con el build y test.
