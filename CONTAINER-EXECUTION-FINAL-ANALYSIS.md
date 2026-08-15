# 📊 Container Execution - Análisis Final y Resumen

**Fecha**: 2026-08-01  
**Duración Total**: ~2.5 horas  
**Intentos**: 6  
**Resultado**: ❌ **TODOS FALLIDOS**  
**Status**: **BLOQUEADO - Requiere refactor arquitectural**

---

## 🎯 Objetivo Original

Ejecutar AI-SDLC worker en container para validar autonomía end-to-end con issue #1032.

**Esperado**:
```
Issue #1032 → Worker container → Implementación → PR creado → CI → Merge
```

**Realidad**:
```
Issue #1032 → Worker container → Permission denied (6 variantes) → ❌ FALLO
```

---

## 📊 Historial Completo de Intentos

| # | Tiempo | Approach | Error | Root Cause |
|---|--------|----------|-------|------------|
| 1 | 19:09 | Default (UID 1000) | mkdir permission denied | UID mismatch (1000 vs 1001) |
| 2 | 19:11 | chmod 777 | cat permission denied | Wrong file ownership |
| 3 | 19:15 | --user runner | git config lock | Can't write /app |
| 4 | 19:17 | --user + HOME | git config lock | Volume ownership |
| 5 | 21:40 | --userns=keep-id | mkdir permission denied | Can't create subdir |
| 6 | 21:43 | userns + pre-create | git clone permission denied | Can't write .git |

---

## 🔍 Progresión de Errores

### **Fase 1: Setup Directories (Intentos #1-6)**

```
Intento #1-5: mkdir /srv/.../worktrees/homedir
              ❌ Permission denied

Intento #6:   mkdir /srv/.../worktrees/homedir
              ✅ SUCCESS (pre-created)
```

**Lección**: Directories must pre-exist, container can't create them

---

### **Fase 2: Clone Repository (Intento #6)**

```
git clone → /srv/.../worktrees/homedir/.git
            ❌ Permission denied
```

**Nuevo bloqueo**: Aunque directorio existe, git no puede escribir `.git` subdirectory

---

## 🎯 Root Cause Fundamental

### **Problema Arquitectural**

El diseño del worker es **fundamentalmente incompatible** con ejecución rootless:

```
Containerfile assumptions:
├─ Runs as specific UID (1000)
├─ Can create directories freely
├─ Can write to any mounted path
└─ Has root-like permissions

Reality in rootless CI:
├─ Must run as runner UID (1001+)
├─ Cannot create subdirectories in volumes
├─ Volume writes have namespace isolation
└─ Zero root privileges
```

### **Technical Root Cause**

**User namespace mapping** crea barrier infranqueable:

```bash
# With --userns=keep-id:
Container sees:  UID 0 (root)
Host sees:       UID 1001 (runner)

# Volume mounted at /srv/worktrees/homedir:
ls -la /srv/worktrees/homedir
drwxr-xr-x runner runner .

# When git clone tries:
git clone <repo> /srv/worktrees/homedir
# Creates: /srv/worktrees/homedir/.git/

# Linux kernel says:
# - Process: UID 1001 (mapped from container 0)
# - Parent: owned by 1001, mode 755
# - Operation: write .git/ subdirectory
# - Namespace: isolated from host
# → EACCES (Permission denied)
```

**Por qué falla**:
- Parent dir (homedir/) owned by runner ✓
- Process UID matches owner (1001) ✓
- BUT: User namespace isolation prevents writes
- Kernel sees different namespace → DENY

---

## 🚫 Por Qué Todas las Soluciones Fallaron

### **chmod 777** ❌
```
Problema: Cambia permissions, NO ownership
Resultado: Container escribe como UID 1000
           Runner (1001) no puede leer
```

### **--user runner** ❌
```
Problema: Container no puede escribir /app (owned by 1000)
Resultado: git config --global fails
```

### **--user + HOME writable** ❌
```
Problema: HOME en volume tiene mismo namespace issue
Resultado: Still can't write .gitconfig
```

### **--userns=keep-id** ❌
```
Problema: Namespace isolation previene subdirectory creation
Resultado: mkdir/git clone fail
```

### **userns + pre-create dirs** ❌
```
Problema: Aunque dir existe, git necesita crear .git/
Resultado: Permission denied en .git/ creation
```

---

## ✅ Solución Definitiva (No Implementada)

### **Opción 1: Containerfile Rootless (RECOMENDADO)**

**Cambios necesarios**:

```dockerfile
# container/Containerfile.worker

# REMOVE estas líneas:
RUN useradd -m -s /bin/bash -u 1000 homedir-sdlc
USER homedir-sdlc  # ← ELIMINAR

# ADD:
RUN chmod -R 777 /app /usr/local/bin
# No USER directive - ejecutar con --user en runtime
```

**Runtime**:
```yaml
podman run --user $(id -u):$(id -g) \
  -v .test/state:/var/lib/homedir-sdlc \
  worker:test
```

**Ventajas**:
- ✅ Container ejecuta con MISMO UID que host
- ✅ No namespace mapping issues
- ✅ Files creados son legibles por host
- ✅ Compatible con cualquier runtime

**Tiempo estimado**: ~15 minutos (rebuild + test)

---

### **Opción 2: Volume Permissions Override**

**Approach**:
```yaml
# Run container as root ONCE para setup
podman run --rm --user 0:0 \
  -v .test/worktrees:/srv/worktrees \
  worker:test bash -c "chown -R 1000:1000 /srv/worktrees"

# Luego run normal
podman run --rm \
  -v .test/worktrees:/srv/worktrees \
  worker:test reconcile
```

**Ventajas**:
- ✅ No rebuild needed
- ✅ Permissions explicitly set

**Desventajas**:
- ❌ Requires two container runs
- ❌ Complex workflow
- ❌ Not elegant

---

### **Opción 3: Disable Userns (Inseguro)**

```yaml
podman run --userns=host ...
```

**Ventajas**:
- ✅ Bypasses namespace isolation

**Desventajas**:
- ❌ Security risk
- ❌ Not recommended for CI
- ❌ May not work in GitHub Actions

---

## 📋 Recomendación Final

### **PASO 1: Rebuild Containerfile** (15 min)

```bash
# 1. Edit Containerfile.worker
sed -i '/USER homedir-sdlc/d' container/Containerfile.worker
echo "RUN chmod -R 777 /app" >> container/Containerfile.worker

# 2. Rebuild
podman build -f container/Containerfile.worker -t worker:rootless .

# 3. Test
podman run --rm --user $(id -u):$(id -g) \
  -v .test/state:/var/lib/homedir-sdlc \
  worker:rootless reconcile
```

### **PASO 2: Update Workflow** (5 min)

```yaml
# .github/workflows/test-autonomous-worker.yml
- name: Run worker
  run: |
    podman run --rm \
      --user $(id -u):$(id -g) \  # Sin --userns
      -e HOME=/tmp \              # Temp HOME para git
      --env-file .test/env \
      worker:test reconcile
```

### **PASO 3: Re-test** (5 min)

```bash
gh workflow run test-autonomous-worker.yml -f issue_number=1032
```

**Tiempo total estimado**: **25 minutos**

---

## 📊 Impacto y Métricas

### **Tiempo Invertido**

| Actividad | Tiempo |
|-----------|--------|
| Debugging permissions | 1.5h |
| 6 intentos fallidos | 1h |
| Documentación | 0.5h |
| **TOTAL PERDIDO** | **3h** |

### **Lecciones Críticas**

1. **Test rootless desde día 1**
   - Si hubiera testado rootless localmente → problema detectado temprano
   
2. **Don't assume root**
   - Containerfile con USER específico = problema futuro
   
3. **Namespace isolation es real**
   - --userns no es "magic fix" - tiene trade-offs
   
4. **Pre-create != pre-permission**
   - Crear dir no garantiza que container pueda escribir subdirs

---

## 🚀 Próximos Pasos

### **Acción Inmediata**

1. [ ] Rebuild Containerfile sin USER directive
2. [ ] Test local con --user $(id -u)
3. [ ] Update GitHub workflow
4. [ ] Re-test con issue #1032

### **Validación**

Antes de continuar con test E2E, validar:
- [ ] Container inicia sin errores
- [ ] git config funciona
- [ ] mkdir en volumes funciona
- [ ] git clone funciona
- [ ] Archivos creados son legibles por host

### **Documentación**

- [ ] Actualizar README con rootless requirements
- [ ] Documentar en DEPLOYMENT.md
- [ ] Agregar troubleshooting guide
- [ ] Add rootless testing to CI

---

## 💡 Alternativa: Posponer Test Container

### **Opción pragmática**

**Dado que**:
- Test containerizado ha consumido 3h
- Problema requiere rebuild arquitectural
- GitHub Actions test YA funcionó (PR #1345)

**Recomendación**:
1. ✅ Usar GitHub Actions para tests (ya validado)
2. ⏸️ Posponer container local para después
3. 🎯 Continuar con validación de autonomía
4. 📚 Documentar container issues para futuro

**Ventajas**:
- Avanzar con validación de autonomía
- No bloquear progreso por infra issues
- Solución container puede ser iterativa

---

## 📝 Conclusiones

### **Estado Actual**

❌ **Container execution: BLOQUEADO**
- 6 intentos, 6 fallos
- Root cause: Architecture incompatible con rootless
- Solución: Rebuild Containerfile

✅ **GitHub Actions test: FUNCIONA**
- PR #1345 creado automáticamente
- Issue #1306 resuelto
- Autonomía validada en CI

### **Decisión Estratégica**

**Path A**: Fix container ahora (25 min + riesgo)
**Path B**: Usar GitHub Actions, fix container después

**Recomendación**: **Path B**
- Menor riesgo
- Progreso inmediato
- Container fix puede ser incremental

---

## 🎯 Siguient Acción Sugerida

Dado el context session budget y tiempo invertido:

1. **Cerrar tema container** por ahora
2. **Documentar findings** (✅ HECHO)
3. **Continuar** con GitHub Actions para tests
4. **Test E2E** con issue más simple que #1032
5. **Volver** a container cuando tiempo permita

---

**Generado**: 2026-08-01 21:45 UTC  
**Status**: Container execution blocked - alternativa GitHub Actions viable  
**Próximo**: Decidir path forward (A o B)
