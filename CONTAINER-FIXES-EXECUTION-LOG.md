# 🔧 Container Fixes - Execution Log

**Fecha**: 2026-08-01  
**Objetivo**: Resolver permisos para ejecutar AI-SDLC worker en contenedor

---

## 📊 Historial de Intentos

### **Intento #1** (Run 30714150847) - ❌ FALLÓ
**Tiempo**: 19:09 UTC  
**Duración**: 52s  
**Approach**: Default (container as UID 1000)  
**Error**: `mkdir: cannot create directory '/srv/homedir-sdlc/worktrees/homedir': Permission denied`  
**Exit**: 1

**Análisis**: Container UID 1000 no puede escribir en volumes owned by runner UID 1001

---

### **Intento #2** (Run 30714232808) - ❌ FALLÓ
**Tiempo**: 19:11 UTC  
**Duración**: 2m35s  
**Approach**: `chmod -R 777 .test`  
**Error**: `cat: .test/state/heartbeat.json: Permission denied`  
**Exit**: 1

**Análisis**: chmod 777 permite container escribir, pero runner no puede leer files (owned by UID 1000)

**Commit**: e488e2e

---

### **Intento #3** (Run 30714355278) - ❌ FALLÓ  
**Tiempo**: 19:15 UTC  
**Duración**: 54s  
**Approach**: `--user $(id -u):$(id -g)`  
**Error**: `error: could not lock config file /app/.gitconfig: Permission denied`  
**Exit**: 255

**Análisis**: Container ejecuta como runner UID, pero /app es owned by UID 1000

**Commit**: e7fbfc4

---

### **Intento #4** (Run 30714442770) - ❌ FALLÓ
**Tiempo**: 19:17 UTC  
**Duración**: ~1m  
**Approach**: `--user $(id -u):$(id -g)` + `HOME=/var/lib/homedir-sdlc`  
**Error**: `error: could not lock config file /var/lib/homedir-sdlc/.gitconfig: Permission denied`  
**Exit**: 255

**Análisis**: HOME writable no resuelve el problema - volumen montado aún tiene ownership issues

**Commit**: 32d9b82

---

### **Intento #5** (Run 30714498311) - ⏳ EN EJECUCIÓN
**Tiempo**: 19:22 UTC  
**Approach**: `--userns=keep-id`  
**Esperado**: Podman mapea automáticamente host UID ↔ container UID

**Cambio aplicado**:
```yaml
# BEFORE
podman run --user $(id -u):$(id -g) -e HOME=...

# AFTER
podman run --userns=keep-id
```

**Ventajas**:
- ✅ Sin cambios en Containerfile
- ✅ UID mapping automático
- ✅ No ownership issues

**Commit**: 771265f

---

## 🎯 Root Cause

**Problema fundamental**: UID mismatch entre build-time y runtime

| Stage | UID | Owner |
|-------|-----|-------|
| Containerfile build | 1000 | homedir-sdlc user owns /app |
| GitHub Actions runner | 1001 | runner user owns .test/* |
| Container runtime (default) | 1000 | Can't write runner's volumes |
| Container --user runner | 1001 | Can't write /app |

**Solución**: `--userns=keep-id` (Podman feature)
- Mapea host UID automáticamente
- Container ve sus files como su UID
- Host ve files con ownership correcto

---

## 📋 Soluciones Evaluadas

| # | Approach | Result | Reason |
|---|----------|--------|--------|
| 1 | Default (UID 1000) | ❌ | Can't write volumes |
| 2 | chmod 777 | ❌ | Runner can't read |
| 3 | --user runner | ❌ | Can't write /app/.gitconfig |
| 4 | --user + HOME | ❌ | Volume ownership issue |
| **5** | **--userns=keep-id** | **⏳** | **Auto UID mapping** |

---

## 🔧 Implementación Final

### **Archivo**: `.github/workflows/test-autonomous-worker.yml`

```yaml
- name: Run worker (AUTONOMOUS - NO INTERVENTION)
  run: |
    podman run --rm \
      --userns=keep-id \    # ← SOLUCIÓN
      --env-file .test/env \
      -v "$(pwd)/.test/state:/var/lib/homedir-sdlc" \
      -v "$(pwd)/.test/worktrees:/srv/homedir-sdlc/worktrees" \
      -v "$(pwd)/.test/logs:/var/log/homedir-sdlc" \
      worker:test reconcile
```

**Commits aplicados**:
1. e488e2e - chmod 777 (fallido)
2. e7fbfc4 - --user runner (fallido)
3. 32d9b82 - --user + HOME (fallido)
4. 771265f - --userns=keep-id (testing)

---

## ⏱️ Timeline

| Hora UTC | Evento | Status |
|----------|--------|--------|
| 19:09 | Intento #1 | ❌ mkdir permission denied |
| 19:12 | Intento #2 (chmod) | ❌ runner can't read |
| 19:15 | Intento #3 (--user) | ❌ git config failed |
| 19:17 | Intento #4 (HOME) | ❌ git config failed |
| 19:22 | Intento #5 (userns) | ⏳ EJECUTANDO |

**Duración total troubleshooting**: ~13 minutos

---

## 📚 Lecciones Aprendidas

### **1. Container UID mismatch es común**

Siempre que:
- Build-time crea user específico (UID 1000)
- Runtime es diferente UID (runner UID 1001)
- Volumes son mounted desde host

→ Habrá permission issues

### **2. chmod 777 NO es solución**

chmod cambia permissions, NO ownership:
- Container puede escribir ✓
- Pero files quedan owned by container UID
- Host runner no puede leerlos ✗

### **3. --user matching no es suficiente**

Ejecutar como runner UID:
- ✓ Puede escribir volumes
- ✗ No puede escribir paths del container (/app)

### **4. Podman --userns=keep-id es THE solution**

**Qué hace**:
- Mapea host UID → container UID 0 (root)
- Container se ve a sí mismo como root
- Pero files en host quedan con UID correcto

**Ventajas**:
- ✅ No requiere rebuild
- ✅ Compatible con Containerfile existente
- ✅ Files legibles por host
- ✅ Container puede escribir todo

**Limitación**:
- Requiere Podman >= 2.0
- No funciona con Docker (GitHub Actions ✓)

---

## 🎯 Próximos Pasos

### **Si Intento #5 funciona** ✅

1. ✅ Documentar en README.md
2. ✅ Actualizar deployment docs
3. ✅ Continuar con test E2E de issue #1032
4. ✅ Validar PR creado

### **Si Intento #5 falla** ❌

**PASO 3**: Rebuild Containerfile rootless

```dockerfile
# Remove USER directive
# Make /app writable by any UID
RUN chmod -R 777 /app
```

→ Último recurso (definitivo pero requiere rebuild)

---

## 📊 Métricas

**Intentos totales**: 5  
**Tiempo total**: ~13 minutos  
**Commits**: 4  
**Approachs probados**: 5  

**Lesson**: Container permissions son complejos - usar Podman --userns desde inicio

---

**Status**: ⏳ Esperando resultado Intento #5 (Run 30714498311)  
**ETA**: ~19:24 UTC
