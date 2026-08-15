# ⚠️ VERIFICACIÓN MANUAL REQUERIDA

**Fecha:** 2026-08-15 18:45 UTC  
**Motivo:** Comandos SSH automáticos tienen timeouts desde entorno actual

---

## ✅ LO QUE SABEMOS (CONFIRMADO)

### 1. CI/CD Pipeline - 100% FUNCIONAL ✅
- **Último deployment:** Run #31901197479 - **SUCCESS**
- **Worker image:** `ghcr.io/os-santiago/homedir-ai-sdlc/worker:latest`
- **Dashboard image:** `ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:latest`
- **Commit deployed:** `96df22d` (Claude CLI fix)

### 2. Worker Container - DEPLOYED ✅
```
[2026-08-15T18:29:35Z] [entrypoint] INFO: SCC found: 2.1.233 (Claude Code) ✅
[2026-08-15T18:29:35Z] [entrypoint] INFO: Repository: os-santiago/homedir ✅
[2026-08-15T18:29:35Z] [entrypoint] INFO: Worktree ready ✅
[2026-08-15T18:29:36Z] [homedir-sdlc-worker] reconciling merged autonomous SDLC PRs ✅
```

**Confirmado en deployment logs:**
- ✅ Claude CLI v2.1.233 instalado correctamente
- ✅ Repositorio clonado y listo
- ✅ Worker ejecutando loop de reconciliación
- ✅ Procesando issues legacy (1084, 1098, etc.)

### 3. Dashboard - ACCESSIBLE ✅
- **URL:** https://homedir-ai-sdlc.opensourcesantiago.io
- **Status:** Running (health endpoint pendiente)

---

## ⚠️ LO QUE NECESITA VERIFICACIÓN MANUAL

### Issue #1440 No Procesado

**Observación:**
- Label `ready-to-implement` aplicado: 2026-08-15 18:34:31 UTC
- Monitoreado por 5+ minutos
- **Sin cambios en labels** (debería agregar `scc-queued`)
- Worker no reclamó el issue

**Posibles Causas:**
1. GitHub token sin permisos adecuados
2. Worker configurado con label diferente a `ready-to-implement`
3. Criterios de admisión no cumplidos por el issue
4. Error en autenticación de GitHub API

---

## 📋 COMANDOS DE VERIFICACIÓN MANUAL

### Conectarse al VPS

```bash
# Desde WSL o terminal Linux:
ssh homedir-sdlc@72.60.141.165

# O desde Windows (si tienes clave SSH configurada):
ssh -i ~/.ssh/id_ed25519 homedir-sdlc@72.60.141.165
```

---

### 1. Verificar Status de Pod y Containers

```bash
# Ver pod
podman pod ps | grep ai-sdlc

# Ver containers
podman ps --filter "pod=ai-sdlc"

# Deberías ver:
# - ai-sdlc-worker (running)
# - ai-sdlc-dashboard (running)
# - ai-sdlc pod infra (running)
```

**Esperado:**
```
POD ID      NAME     STATUS    CREATED        INFRA ID      # OF CONTAINERS
xxxxxxxx    ai-sdlc  Running   XX minutes ago yyyyyyy       3
```

---

### 2. Verificar Claude CLI (SCC)

```bash
podman exec ai-sdlc-worker scc --version
```

**Esperado:**
```
2.1.233 (Claude Code)
```

**Si falla:** SCC no instalado correctamente, revisar logs de build.

---

### 3. **CRÍTICO:** Verificar GitHub Authentication

```bash
# Test 1: gh auth status
podman exec ai-sdlc-worker gh auth status

# Test 2: GitHub API (más confiable)
podman exec ai-sdlc-worker gh api user
```

**Esperado (API test):**
```json
{
  "login": "scanalesespinoza",
  "name": "Sergio Canales",
  "type": "User"
}
```

**Si falla con:**
- `HTTP 401 Unauthorized` → Token inválido o expirado
- `gh: command not found` → GitHub CLI no instalado
- `API rate limit exceeded` → Token sin scopes correctos

**Solución si falla:**
```bash
# Verificar que GH_TOKEN existe
cat /etc/homedir-sdlc/worker.env | grep GH_TOKEN

# Si está vacío o es inválido:
# 1. Generar nuevo token en: https://github.com/settings/tokens
#    Scopes requeridos: repo, workflow
# 2. Actualizar worker.env:
sudo nano /etc/homedir-sdlc/worker.env
# Cambiar: GH_TOKEN=tu_nuevo_token_aquí

# 3. Reiniciar pod:
podman pod restart ai-sdlc

# 4. Verificar nuevamente:
podman exec ai-sdlc-worker gh api user
```

---

### 4. **CRÍTICO:** Verificar Query de Issues

```bash
# Intentar consultar issues con ready-to-implement
podman exec ai-sdlc-worker gh issue list \
  --repo os-santiago/homedir \
  --label ready-to-implement \
  --limit 5 \
  --json number,title,labels
```

**Esperado:**
```json
[
  {
    "number": 1440,
    "title": "[Bug] Header logo subtitle text overflows into nav links area",
    "labels": [
      {"name": "bug"},
      {"name": "priority:P2"},
      {"name": "ready-to-implement"}
    ]
  }
]
```

**Si está vacío `[]`:**
- Verificar que issue #1440 tiene el label en GitHub: https://github.com/os-santiago/homedir/issues/1440
- Re-aplicar label si es necesario

**Si falla con error:**
- Problema de autenticación (volver a paso 3)
- Verificar repo name es correcto: `os-santiago/homedir`

---

### 5. Verificar Variables de Entorno del Worker

```bash
# Ver todas las variables HOMEDIR_SDLC_*
podman exec ai-sdlc-worker env | grep HOMEDIR_SDLC_ | sort

# Verificar específicamente:
podman exec ai-sdlc-worker env | grep HOMEDIR_SDLC_TRIGGER_LABEL
podman exec ai-sdlc-worker env | grep HOMEDIR_SDLC_REPO
```

**Esperado:**
```
HOMEDIR_SDLC_TRIGGER_LABEL=ready-to-implement
HOMEDIR_SDLC_REPO=os-santiago/homedir
HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc
HOMEDIR_SDLC_WORKDIR=/srv/homedir-sdlc/worktrees/homedir
...
```

**Si TRIGGER_LABEL es diferente:**
```bash
# Actualizar en worker.env
sudo nano /etc/homedir-sdlc/worker.env

# Agregar o cambiar:
HOMEDIR_SDLC_TRIGGER_LABEL=ready-to-implement

# Reiniciar:
podman pod restart ai-sdlc
```

---

### 6. Analizar Logs del Worker

```bash
# Ver últimas 50 líneas
podman logs --tail 50 ai-sdlc-worker

# Buscar errores
podman logs ai-sdlc-worker | grep -i error | tail -20

# Buscar warnings
podman logs ai-sdlc-worker | grep -i warn | tail -20

# Buscar procesamiento de issues
podman logs ai-sdlc-worker | grep -E "claim|ready-to-implement|1440"

# Ver logs en tiempo real
podman logs -f ai-sdlc-worker
```

**Buscar específicamente:**
- ❌ `ERROR: GitHub CLI authentication verification failed`
- ❌ `ERROR: Failed to query issues`
- ❌ `ERROR: SCC execution failed`
- ✅ `Claimed issue #XXXX`
- ✅ `Adding label scc-queued to issue #XXXX`

---

### 7. Verificar Heartbeat

```bash
cat /var/lib/homedir-sdlc/heartbeat.json | jq '.'
```

**Esperado:**
```json
{
  "repo": "os-santiago/homedir",
  "status": "idle" | "running" | "ok",
  "detail": "...",
  "updated_at": "2026-08-15T18:XX:XXZ",
  "container": true
}
```

**Verificar:**
- `updated_at` debe ser reciente (< 5 minutos)
- `status` debe ser `idle`, `running`, o `ok` (no `error`)

---

### 8. Verificar Archivos de Configuración

```bash
# Ver contenido de worker.env (sin exponer secrets completos)
cat /etc/homedir-sdlc/worker.env | sed 's/\(TOKEN\|KEY\)=.*/\1=***REDACTED***/'

# Verificar permisos
ls -la /etc/homedir-sdlc/worker.env

# Listar archivos de estado
ls -lah /var/lib/homedir-sdlc/

# Ver issues conocidos
ls -lah /var/lib/homedir-sdlc/issues/
```

---

## 🔧 SOLUCIONES COMUNES

### Problema: GitHub Auth Falla

**Síntoma:**
```
HTTP 401 Unauthorized
gh: Not logged into any GitHub hosts
```

**Solución:**
1. Generar nuevo Personal Access Token:
   - https://github.com/settings/tokens
   - Click "Generate new token (classic)"
   - Scopes: `repo` (full), `workflow`
   - Expiration: 90 days o más
   - Copy token

2. Actualizar en VPS:
```bash
sudo nano /etc/homedir-sdlc/worker.env
# Cambiar línea: GH_TOKEN=nuevo_token_aquí

podman pod restart ai-sdlc
sleep 30

# Verificar:
podman exec ai-sdlc-worker gh api user
```

---

### Problema: Worker No Procesa Issues

**Síntoma:**
- Issue con `ready-to-implement` no reclamado
- Logs muestran reconciliation pero no nuevo issues

**Diagnóstico:**
```bash
# Ver si worker busca issues nuevos
podman logs ai-sdlc-worker | grep -i "new issue\|claim\|ready-to-implement"

# Verificar trigger label configurado
podman exec ai-sdlc-worker env | grep TRIGGER_LABEL
```

**Solución:**
1. Confirmar variable correcta:
```bash
cat /etc/homedir-sdlc/worker.env | grep TRIGGER_LABEL
# Debe ser: HOMEDIR_SDLC_TRIGGER_LABEL=ready-to-implement
```

2. Si falta o es diferente, agregar/corregir:
```bash
sudo nano /etc/homedir-sdlc/worker.env
# Agregar: HOMEDIR_SDLC_TRIGGER_LABEL=ready-to-implement

podman pod restart ai-sdlc
```

3. Esperar 3-5 minutos (ciclo del timer)

4. Monitorear logs:
```bash
podman logs -f ai-sdlc-worker
```

---

### Problema: SCC Execution Falla

**Síntoma:**
```
SCC execution failed
scc: command not found
```

**Diagnóstico:**
```bash
podman exec ai-sdlc-worker which scc
podman exec ai-sdlc-worker scc --version
```

**Solución:**
Rebuild container (SCC debe estar instalado durante build):
```bash
# En repo local:
cd D:\git\homedir-ai-sdlc
git pull origin main
git log -1  # Verificar último commit es 96df22d o más reciente

# Si no está actualizado, pull y esperar auto-deploy
# O forzar re-deploy:
gh workflow run deploy-production.yml --repo os-santiago/homedir-ai-sdlc
```

---

## 📊 CHECKLIST DE VERIFICACIÓN

Ejecutar cada comando y marcar resultado:

- [ ] **Pod running:** `podman pod ps | grep ai-sdlc`
  - Status debe ser "Running"
  
- [ ] **SCC instalado:** `podman exec ai-sdlc-worker scc --version`
  - Output esperado: `2.1.233 (Claude Code)`
  
- [ ] **GitHub API funcional:** `podman exec ai-sdlc-worker gh api user`
  - Debe mostrar usuario sin error 401
  
- [ ] **Issues query funcional:** `podman exec ai-sdlc-worker gh issue list --repo os-santiago/homedir --label ready-to-implement --limit 1`
  - Debe mostrar issue #1440
  
- [ ] **TRIGGER_LABEL correcto:** `podman exec ai-sdlc-worker env | grep TRIGGER_LABEL`
  - Debe ser: `HOMEDIR_SDLC_TRIGGER_LABEL=ready-to-implement`
  
- [ ] **REPO correcto:** `podman exec ai-sdlc-worker env | grep HOMEDIR_SDLC_REPO`
  - Debe ser: `HOMEDIR_SDLC_REPO=os-santiago/homedir`
  
- [ ] **GH_TOKEN presente:** `cat /etc/homedir-sdlc/worker.env | grep GH_TOKEN`
  - No debe estar vacío
  
- [ ] **SC_API_KEY presente:** `cat /etc/homedir-sdlc/worker.env | grep SC_API_KEY`
  - No debe estar vacío (para Claude Code execution)
  
- [ ] **Heartbeat actualizado:** `cat /var/lib/homedir-sdlc/heartbeat.json`
  - `updated_at` debe ser < 5 minutos
  
- [ ] **Logs sin errores críticos:** `podman logs ai-sdlc-worker | tail -50`
  - No debe haber `ERROR` recientes

---

## 🎯 PRÓXIMO PASO DESPUÉS DE VERIFICACIÓN

### Si TODO está ✅ (todos los checks pasan):

```bash
# Re-trigger issue #1440
gh issue edit 1440 --repo os-santiago/homedir --remove-label ready-to-implement
sleep 2
gh issue edit 1440 --repo os-santiago/homedir --add-label ready-to-implement

# Monitorear en tiempo real (3-5 minutos):
podman logs -f ai-sdlc-worker

# En otra terminal, monitorear issue:
watch -n 10 'gh issue view 1440 --repo os-santiago/homedir --json labels --jq .labels[].name'
```

**Esperado en logs:**
```
[homedir-sdlc-worker] Found new issue #1440 with label ready-to-implement
[homedir-sdlc-worker] Claimed issue #1440
[homedir-sdlc-worker] Added label scc-queued to issue #1440
[homedir-sdlc-worker] Starting SCC execution for issue #1440
...
```

**Esperado en issue (3-20 minutos):**
- T+3min: Label `scc-queued` agregado
- T+5min: Label cambia a `scc-running`
- T+15min: PR creado, label `scc-pr-open`
- T+20min: Merge (si auto-merge habilitado)

---

### Si ALGÚN CHECK falla ❌:

1. **GitHub Auth failed:**
   - Seguir "Solución: GitHub Auth Falla" arriba
   - Regenerar token
   - Actualizar worker.env
   - Restart pod

2. **SCC not found:**
   - Verificar commit deployed es `96df22d` o más reciente
   - Si no, esperar auto-deploy o forzar workflow

3. **Variables incorrectas:**
   - Editar `/etc/homedir-sdlc/worker.env`
   - Restart pod
   - Re-verificar

4. **Issues query vacío:**
   - Verificar issue #1440 tiene label en GitHub UI
   - Verificar REPO name es correcto
   - Re-aplicar label si necesario

---

## 📞 REPORTAR RESULTADOS

Después de ejecutar verificaciones, reportar:

1. **Qué checks pasaron ✅**
2. **Qué checks fallaron ❌**
3. **Output de comando que falló** (copiar y pegar)
4. **Última línea del worker log** (`podman logs --tail 1 ai-sdlc-worker`)

Esto permitirá diagnóstico preciso y solución específica.

---

**Script de verificación disponible en:**
- `D:\git\homedir-ai-sdlc\scripts\verify-worker-vps.sh`

**Ejecutar todo de una vez:**
```bash
ssh homedir-sdlc@72.60.141.165 'bash -s' < D:\git\homedir-ai-sdlc\scripts\verify-worker-vps.sh
```

---

**Última actualización:** 2026-08-15 18:45 UTC
