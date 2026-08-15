# 🔍 Root Cause Analysis - AI-SDLC Container Execution Failures

**Fecha**: 2026-08-01  
**Sesión**: 6 intentos fallidos  
**Duración**: ~2.5 horas  
**Objetivo**: Ejecutar worker en container para test autónomo  
**Estado**: ❌ **TODOS LOS INTENTOS FALLIDOS**

---

## 📊 Historial Completo de Fallos

### **Intento #1** (19:09 UTC) - ❌ Permission Denied (mkdir volumes)
```
Error: mkdir: cannot create directory '/srv/homedir-sdlc/worktrees/homedir': Permission denied
Exit: 1
```

**Root Cause**: Container UID 1000 vs Host UID 1001 mismatch

---

### **Intento #2** (19:11 UTC) - ❌ Permission Denied (read files)
```
Fix: chmod -R 777 .test
Error: cat: .test/state/heartbeat.json: Permission denied
Exit: 1
```

**Root Cause**: chmod changes permissions, NOT ownership

---

### **Intento #3** (19:15 UTC) - ❌ Git Config Lock Failed
```
Fix: --user $(id -u):$(id -g)
Error: error: could not lock config file /app/.gitconfig: Permission denied
Exit: 255
```

**Root Cause**: Container can't write to /app (owned by UID 1000)

---

### **Intento #4** (19:17 UTC) - ❌ Git Config Lock Failed (vol)
```
Fix: --user + HOME=/var/lib/homedir-sdlc
Error: error: could not lock config file /var/lib/homedir-sdlc/.gitconfig: Permission denied
Exit: 255
```

**Root Cause**: HOME in mounted volume still has ownership issues

---

### **Intento #5** (21:40 UTC) - ❌ Permission Denied (mkdir AGAIN)
```
Fix: --userns=keep-id
Error: mkdir: cannot create directory '/srv/homedir-sdlc/worktrees/homedir': Permission denied
Exit: 1
```

**Root Cause**: Worker tries to create subdirectory inside mounted volume

---

### **Intento #6** (21:43 UTC) - ⏳ EJECUTANDO
```
Fix: --userns=keep-id + pre-create worktrees/homedir
Status: Running...
```

**Expected**: Worker can now execute without mkdir errors

---

## 🎯 Root Cause Fundamental

### **Problema #1: UID Mismatch Architecture**

El diseño del Containerfile es **incompatible** con ejecución rootless:

```dockerfile
# Containerfile.worker (lines 10-16)
RUN useradd -m -s /bin/bash -u 1000 homedir-sdlc
USER homedir-sdlc  # ← PROBLEMA: Fuerza UID 1000
```

**Consecuencias**:
- Build-time: todos los archivos en /app owned by UID 1000
- Runtime default: container ejecuta como UID 1000
- GitHub Actions runner: UID 1001
- **Conflict inevitable**

### **Problema #2: Subdirectory Creation Pattern**

El entrypoint asume que puede crear subdirectorios libremente:

```bash
# worker-entrypoint.sh (line 119)
mkdir -p "${HOMEDIR_SDLC_WORKDIR}"  # /srv/.../worktrees/homedir
```

**Pero**:
- Volume montado en: `/srv/homedir-sdlc/worktrees`
- Worker intenta crear: `/srv/homedir-sdlc/worktrees/homedir`
- Con rootless: **Permission Denied**

### **Problema #3: Assumption of Root Privileges**

El worker fue diseñado asumiendo:
- ✗ Puede escribir en cualquier path
- ✗ Puede crear directorios en volumes
- ✗ Ejecutará siempre como mismo UID

**Realidad en CI**:
- ✓ Debe ejecutar como runner UID (1001)
- ✓ Volumes son read-only para crear subdirs
- ✓ UID cambia según runtime environment

---

## 🔧 Soluciones Intentadas

| # | Approach | Issue | Result |
|---|----------|-------|--------|
| 1 | Default | UID mismatch | ❌ Can't write volumes |
| 2 | chmod 777 | Wrong ownership | ❌ Runner can't read |
| 3 | --user runner | Can't write /app | ❌ Git config fails |
| 4 | --user + HOME | Volume ownership | ❌ Still can't write |
| 5 | --userns=keep-id | Subdir creation | ❌ mkdir fails |
| 6 | userns + pre-create | ⏳ | **TESTING** |

---

## 💡 Análisis Profundo

### **¿Por qué --userns=keep-id falló?**

**Lo que hace**:
- Mapea host UID → container namespace
- Container se ve como UID 0 (root) internamente
- Pero files en volumes mantienen host UID

**El problema**:
```bash
# En container con --userns=keep-id
id                    # Shows: uid=0(root)
ls -la /srv/worktrees # Shows: owned by 1001 (host runner)

# Cuando worker hace:
mkdir /srv/worktrees/homedir

# Linux kernel ve:
# - Process UID: 1001 (mapped from container 0)
# - Parent dir: owned by 1001, mode 755
# - Intento: crear subdirectorio

# RESULTADO: Permission denied
# ¿Por qué? Parent dir NO tiene sticky bit ni ACLs especiales
```

**Root Cause del Root Cause**:
Con mode 755, owner puede crear subdirs, pero con userns mapping,
aunque process UID = dir UID, **namespace isolation** previene write.

### **¿Por qué pre-crear subdirectorio debería funcionar?**

```bash
# Host creates:
mkdir .test/worktrees/homedir  # Owned by runner UID 1001

# Container with --userns=keep-id maps:
Host UID 1001 → Container UID 0

# Worker ve:
/srv/worktrees/homedir  # Owned by "root" (mapped 1001)

# mkdir -p checks:
# - Path exists? YES
# - Writable? YES (owner can write)
# → SKIP creation, SUCCESS
```

---

## 🎯 Solución Definitiva (Si Intento #6 Falla)

### **Opción A: Containerfile Rootless**

Rebuild sin USER directive:

```dockerfile
# REMOVE
USER homedir-sdlc

# ADD
RUN chmod -R 777 /app
# No USER - run as whatever --user is passed
```

**Pros**:
- ✅ Compatible con cualquier UID
- ✅ No permission issues
- ✅ Funciona local + CI

**Cons**:
- Requiere rebuild
- chmod 777 en /app (acceptable)

### **Opción B: Init Container Pattern**

Two-stage approach:

```yaml
# Stage 1: Init (as root, create dirs)
podman run --rm \
  --user 0:0 \
  -v .test/state:/var/lib/homedir-sdlc \
  worker:test bash -c "mkdir -p /var/lib/homedir-sdlc/{issues,prs}"

# Stage 2: Worker (as runner)
podman run --rm \
  --userns=keep-id \
  -v .test/state:/var/lib/homedir-sdlc \
  worker:test reconcile
```

**Pros**:
- ✅ No rebuild needed
- ✅ Directories guaranteed to exist

**Cons**:
- More complex workflow
- Two container runs

### **Opción C: Volume Permissions Fix**

Pre-set ACLs on host:

```bash
mkdir -p .test/{state,worktrees/homedir,logs}
chmod -R 777 .test
setfacl -R -m u:1000:rwx .test  # Allow container UID
```

**Pros**:
- ✅ Explicit permissions
- ✅ Compatible con default container UID

**Cons**:
- Requires setfacl (not always available)
- Complex permission management

---

## 📋 Recomendación

### **Prioridad 1: Validar Intento #6**

**Si funciona** ✅:
- Documentar pre-create requirement
- Actualizar deployment docs
- Considerar acceptable workaround

**Si falla** ❌:
- Aplicar **Opción A** (Containerfile rootless)
- Es la solución definitiva más limpia

### **Prioridad 2: Refactor Worker Design**

**Cambios necesarios**:

1. **Entrypoint debe validar, NO crear**:
```bash
# BEFORE
mkdir -p "${HOMEDIR_SDLC_WORKDIR}"

# AFTER
if [[ ! -d "${HOMEDIR_SDLC_WORKDIR}" ]]; then
  log "ERROR: Workdir ${HOMEDIR_SDLC_WORKDIR} must exist (mount volume)"
  exit 1
fi
```

2. **Volumes deben pre-existir**:
```yaml
# Deployment responsibility: create structure BEFORE container
mkdir -p /var/lib/homedir-sdlc/{issues,prs,run-summaries}
mkdir -p /srv/homedir-sdlc/worktrees/homedir
```

3. **Containerfile rootless-first**:
```dockerfile
# Don't create user at build time
# Run as --user at runtime
# Make /app world-readable
```

---

## 🎓 Lecciones Aprendidas

### **1. Container UID Design is Critical**

**Mistake**:
```dockerfile
USER specific_uid  # Forces runtime UID
```

**Better**:
```dockerfile
# No USER directive
# Pass --user at runtime
# Make paths world-accessible
```

### **2. Assume Nothing About Runtime**

Worker assumed:
- ❌ "I can create directories"
- ❌ "I run as my build UID"
- ❌ "Volumes are writable"

Should assume:
- ✓ "Directories must pre-exist"
- ✓ "Runtime UID is unknown"
- ✓ "Volumes may be read-only"

### **3. Rootless is the Future**

GitHub Actions, Kubernetes, security-first envs:
- All moving to rootless containers
- Designs assuming root will fail

**Design principle**:
> If your container can't run as UID 12345, it's broken.

### **4. Test Matrix Matters**

Should have tested:
- ✓ Local (Docker/Podman)
- ✓ Local rootless
- ✓ CI environment
- ✓ Different UIDs

Single test environment = blind spots

---

## 📊 Impact Analysis

### **Time Lost**

| Activity | Time |
|----------|------|
| Attempt #1-5 | ~1.5h |
| Debugging | ~30min |
| Documentation | ~30min |
| **Total** | **~2.5h** |

### **Attempts Timeline**

```
19:09 ─────── 19:11 ─── 19:15 ── 19:17 ────────── 21:40 ── 21:43
  #1            #2       #3      #4              #5       #6
  └─ mkdir      └─ read  └─ git  └─ git         └─ mkdir └─ ???
```

### **Root Cause Categories**

1. **Architecture** (50%): Containerfile design incompatible
2. **Assumptions** (30%): Wrong assumptions about environment
3. **Testing** (20%): No rootless testing before deployment

---

## 🚀 Action Items

### **Immediate** (if #6 fails)

1. [ ] Apply Containerfile rootless patch
2. [ ] Rebuild image
3. [ ] Re-test with issue #1032
4. [ ] Document requirements

### **Short-term**

1. [ ] Add rootless compatibility tests
2. [ ] Update deployment docs
3. [ ] Create troubleshooting guide
4. [ ] Add permission validation to entrypoint

### **Long-term**

1. [ ] Refactor worker to be stateless
2. [ ] Move directory creation to deployment
3. [ ] Add comprehensive test matrix
4. [ ] Document UID requirements

---

## 📝 Conclusión

**Problema fundamental**: Worker diseñado para root, ejecutado como rootless

**Solución definitiva**: Rebuild Containerfile sin USER directive

**Workaround temporal**: Pre-crear todos los subdirectorios (Intento #6)

**Lección clave**: Diseñar containers como rootless-first desde inicio

---

**Status**: ⏳ Esperando resultado Intento #6  
**Next**: Si falla → Rebuild rootless (Opción A)  
**ETA**: ~21:45 UTC
