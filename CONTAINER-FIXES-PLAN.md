# 🔧 Plan de Correcciones: AI-SDLC Container Execution

**Fecha**: 2026-08-01  
**Problema**: Fallos de permisos al ejecutar worker en container  
**Root Cause**: UID mismatch entre container user y host runner

---

## 📊 Análisis de Fallos

### **Intento #1** - Permission Denied (mkdir)

```
Error: mkdir: cannot create directory '/srv/homedir-sdlc/worktrees/homedir': Permission denied
Exit: 1
```

**Causa**:
- Container: Runs as UID 1000 (`homedir-sdlc` user)
- Host: Volumes owned by UID 1001 (GitHub Actions runner)
- Container UID 1000 no puede escribir en volumes owned by UID 1001

---

### **Intento #2** - Permission Denied (read)

```
Fix aplicado: chmod -R 777 .test
Error: cat: .test/state/heartbeat.json: Permission denied
Exit: 1
```

**Causa**:
- chmod 777 permitió al container (UID 1000) crear archivos
- Archivos creados son owned by UID 1000
- Runner (UID 1001) no puede leer archivos owned by UID 1000
- **Problema**: chmod 777 no cambia ownership

---

### **Intento #3** - Git Config Lock Failed

```
Fix aplicado: --user $(id -u):$(id -g)
Error: error: could not lock config file /app/.gitconfig: Permission denied
Exit: 255
```

**Causa**:
- Container ejecuta como runner UID 1001
- Git intenta escribir a `/app/.gitconfig`
- `/app` es owned by UID 1000 (homedir-sdlc user)
- Runner UID 1001 no puede escribir en `/app`

---

### **Intento #4** - En Ejecución ⏳

```
Fix aplicado: --user $(id -u):$(id -g) + HOME=/var/lib/homedir-sdlc
Status: Running...
```

**Esperado**: Git config escribe a `$HOME/.gitconfig` (mounted volume)

---

## 🎯 Root Cause Analysis

### **Problema Fundamental**: UID Mismatch

| Componente | UID | Owner |
|------------|-----|-------|
| Container build time | 1000 | homedir-sdlc user |
| Container run time (default) | 1000 | homedir-sdlc user |
| GitHub Actions runner | 1001 | runner user |
| Test directories (.test/*) | 1001 | runner user |
| Container /app/* | 1000 | homedir-sdlc user |

**Conflicto**:
- Si container runs as UID 1000 → no puede escribir volumes (owned by 1001)
- Si container runs as UID 1001 → no puede escribir /app (owned by 1000)

---

## 🔧 Soluciones Evaluadas

### **❌ Solución 1: chmod 777**

```yaml
chmod -R 777 .test
```

**Pros**: Container puede escribir  
**Cons**: Runner no puede leer archivos creados  
**Resultado**: ❌ FALLA

---

### **❌ Solución 2: --user runner**

```yaml
podman run --user $(id -u):$(id -g)
```

**Pros**: Archivos creados legibles por runner  
**Cons**: Container no puede escribir /app  
**Resultado**: ❌ FALLA (git config)

---

### **⏳ Solución 3: --user runner + HOME writable**

```yaml
podman run --user $(id -u):$(id -g) -e HOME=/var/lib/homedir-sdlc
```

**Pros**: 
- Archivos legibles por runner
- Git config escribe a mounted volume

**Cons**: 
- Container aún no puede escribir archivos en /app si necesita
- Depende de que scripts NO escriban a /app

**Resultado**: ⏳ TESTING (Intento #4)

---

### **✅ Solución 4: Containerfile rootless + --user**

**Cambios en Containerfile**:
1. No crear usuario específico (o crear pero no usar USER)
2. Hacer /app writable por cualquier UID
3. Scripts deben escribir solo a volumes montados

```dockerfile
# BEFORE
USER homedir-sdlc  # UID 1000

# AFTER
# No USER directive - run as whatever UID is passed via --user
RUN chmod -R 777 /app  # Allow any UID to read/write
```

**Runtime**:
```yaml
podman run --user $(id -u):$(id -g)
```

**Pros**:
- ✅ Archivos creados legibles por host
- ✅ Container puede leer /app
- ✅ Compatible con cualquier UID

**Cons**:
- Requiere rebuild de imagen
- chmod 777 en /app (solo build-time artifact, OK)

---

### **✅ Solución 5: Podman userns mapping**

```yaml
podman run --userns=keep-id
```

**Qué hace**: Mapea host UID al container UID automáticamente

**Pros**:
- ✅ Sin cambios en Containerfile
- ✅ Archivos creados con ownership correcto

**Cons**:
- Requiere Podman >= 2.0
- No funciona con Docker (GitHub Actions usa Podman ✓)

---

## 📋 Plan de Corrección (Implementación)

### **Fase 1: Solución Inmediata (Sin rebuild)**

**Objetivo**: Hacer funcionar test actual con mínimo cambio

**Acción**: Esperar resultado Intento #4

**Si falla Intento #4**:
→ Aplicar Solución 5 (--userns=keep-id)

```yaml
podman run --rm \
  --userns=keep-id \
  --env-file .test/env \
  -v "$(pwd)/.test/state:/var/lib/homedir-sdlc" \
  worker:test reconcile
```

---

### **Fase 2: Solución Definitiva (Con rebuild)**

**Objetivo**: Containerfile compatible con ejecución rootless

#### **Cambio 1: Containerfile.worker**

```dockerfile
# BEFORE (línea 16)
USER homedir-sdlc

# AFTER
# Allow running as any UID (rootless-compatible)
RUN chmod -R 777 /app && \
    chmod -R 777 /usr/local/bin
# No USER directive - run as whatever --user is passed
```

#### **Cambio 2: worker-entrypoint.sh**

Verificar que NO escribe a paths no montados:
- ✅ `/var/lib/homedir-sdlc/*` - mounted volume
- ✅ `/var/log/homedir-sdlc/*` - mounted volume  
- ✅ `/srv/homedir-sdlc/worktrees/*` - mounted volume
- ❌ `/app/*` - EVITAR escribir aquí

#### **Cambio 3: Workflow**

```yaml
podman run --rm \
  --user $(id -u):$(id -g) \
  -e HOME=/var/lib/homedir-sdlc \
  --env-file .test/env \
  -v "$(pwd)/.test/state:/var/lib/homedir-sdlc" \
  worker:test reconcile
```

---

### **Fase 3: Testing**

**Test 1: Permisos básicos**
```bash
podman run --rm --user $(id -u):$(id -g) worker:test --version
```

**Test 2: Git config**
```bash
podman run --rm --user $(id -u):$(id -g) \
  -e HOME=/tmp \
  worker:test bash -c "git config --global user.name test"
```

**Test 3: Volume write**
```bash
mkdir -p /tmp/test-vol
podman run --rm --user $(id -u):$(id -g) \
  -v /tmp/test-vol:/data \
  worker:test bash -c "echo test > /data/test.txt"
ls -la /tmp/test-vol/test.txt
```

---

## 🚀 Ejecución del Plan

### **PASO 1**: Esperar Intento #4 (ya en ejecución)

**Run ID**: 30714442770  
**ETA**: ~19:20 UTC

---

### **PASO 2**: Si Intento #4 falla → Aplicar --userns=keep-id

**Archivo**: `.github/workflows/test-autonomous-worker.yml`

```diff
- podman run --rm \
-   --user $(id -u):$(id -g) \
-   -e HOME=/var/lib/homedir-sdlc \
+ podman run --rm \
+   --userns=keep-id \
```

**Commit**: `fix(ci): use podman userns mapping for UID compatibility`

---

### **PASO 3**: Rebuild Containerfile (solución definitiva)

**Archivo**: `container/Containerfile.worker`

```diff
  USER homedir-sdlc
+ # Allow rootless execution with any UID
+ RUN chmod -R 777 /app
+ # Remove USER directive for rootless compatibility
- USER homedir-sdlc
```

**Commit**: `fix(container): make rootless-compatible (no USER directive)`

---

### **PASO 4**: Re-test con imagen rebuilt

**Comando**:
```bash
podman build -f container/Containerfile.worker -t worker:rootless .
podman run --rm --user $(id -u):$(id -g) \
  -e HOME=/var/lib/homedir-sdlc \
  worker:rootless reconcile
```

---

## 📊 Decisión Tree

```
Intento #4 completa
    ↓
¿Exitoso?
    ├─ SÍ → ✅ DONE (usar Solución 3)
    │         Documentar: Requiere HOME writable
    │
    └─ NO → Aplicar PASO 2 (--userns=keep-id)
              ↓
          ¿Exitoso?
              ├─ SÍ → ✅ DONE (usar Solución 5)
              │         Documentar: Requiere Podman
              │
              └─ NO → Aplicar PASO 3 (rebuild rootless)
                        ↓
                    ✅ DEFINITIVO (Solución 4)
                       Compatible con cualquier runtime
```

---

## 🎯 Métricas de Éxito

**Test pasa cuando**:
- ✅ Worker completa sin exit code > 0
- ✅ Archivos en `.test/state` son legibles por runner
- ✅ Git operations funcionan
- ✅ PR creado (si admission review acepta)

**Indicadores de fallo**:
- ❌ Permission denied (cualquier tipo)
- ❌ Exit code 1 o 255
- ❌ No PR created + exit 0 (silent fail)

---

## 📝 Próximos Pasos

1. ⏳ **Monitorear Run 30714442770** (~2 min)
2. ✅ **Analizar resultado** 
3. 🔧 **Aplicar siguiente fix** según Decision Tree
4. 🔄 **Repetir hasta éxito**
5. 📚 **Documentar solución** en README

---

**Status**: ⏳ Esperando resultado Intento #4  
**Siguiente acción**: Si falla → PASO 2 (--userns=keep-id)
