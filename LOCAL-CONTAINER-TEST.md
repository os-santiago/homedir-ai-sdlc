# 🐳 Test Local con Contenedor - Alternativa

**Fecha**: 2026-08-01  
**Estado**: Podman instalándose en WSL  
**Alternativa**: Usar imagen pre-construida de GitHub Actions

---

## ⚠️ Situación Actual

**Bloqueador**: Podman no instalado en WSL Fedora  
**Instalando**: `sudo dnf install -y podman` (en progreso)

**Alternativas disponibles**:

### **Opción 1: Esperar instalación de Podman** (~5 min)

Cuando complete, ejecutar:
```bash
wsl -d fedoraremix bash -c "cd /mnt/d/git/homedir-ai-sdlc && podman build -f container/Containerfile.worker -t homedir-ai-sdlc:local ."
```

### **Opción 2: Usar imagen pre-construida** (RECOMENDADO)

La imagen ya está disponible en:
- `ghcr.io/os-santiago/homedir-ai-sdlc:latest`
- `quay.io/opensourcesantiago/homedir-ai-sdlc:latest` (cuando complete el build)

**Pull y ejecutar**:
```bash
wsl -d fedoraremix bash -c "
  podman pull ghcr.io/os-santiago/homedir-ai-sdlc:latest
  
  # Crear directorios locales
  mkdir -p /tmp/ai-sdlc-test/{state,worktrees,logs}
  
  # Ejecutar worker
  podman run --rm \
    -e GH_TOKEN=\$(gh auth token) \
    -e SC_API_KEY='nvapi-...' \
    -e HOMEDIR_SDLC_REPO=os-santiago/homedir \
    -e HOMEDIR_SDLC_MAX_ISSUES_PER_RUN=1 \
    -v /tmp/ai-sdlc-test/state:/var/lib/homedir-sdlc \
    -v /tmp/ai-sdlc-test/worktrees:/srv/homedir-sdlc/worktrees \
    -v /tmp/ai-sdlc-test/logs:/var/log/homedir-sdlc \
    ghcr.io/os-santiago/homedir-ai-sdlc:latest reconcile
"
```

### **Opción 3: Continuar con GitHub Actions** (LO MÁS SIMPLE)

**Ya validamos autonomía** con el test en GitHub Actions:
- ✅ PR #1345 creado automáticamente
- ✅ Issue #1306 procesado sin intervención
- ✅ Código correcto generado

**Para más pruebas**, simplemente ejecutar otro workflow:
```bash
# Seleccionar otro issue
gh issue view 1305 -R os-santiago/homedir
gh issue edit 1305 -R os-santiago/homedir --add-label "ready-to-implement"

# Ejecutar test
gh workflow run test-autonomous-worker.yml -f issue_number=1305
```

---

## 🎯 Recomendación

**OPCIÓN 3 es la mejor** porque:

1. ✅ Ya funciona (probado)
2. ✅ No requiere setup local
3. ✅ Usa infraestructura de CI/CD
4. ✅ Logs guardados automáticamente
5. ✅ Fácil de repetir

**Test local solo agrega**:
- Más complejidad (setup WSL + podman)
- Mismo resultado
- Más tiempo

---

## 📊 Estado de Autonomía

### **Ya Validado** ✅

**GitHub Actions test (Run 30712074608)**:
- Issue #1306 → PR #1345
- Tiempo: ~5 minutos
- Autonomía: 100%
- Código: Correcto
- Estado: ✅ **ÉXITO**

### **Pendiente** ⏳

Si quieres validar localmente:
1. Esperar instalación podman (~5 min)
2. Pull imagen de GHCR
3. Ejecutar con otro issue
4. Verificar mismo resultado

---

## 🚀 Siguiente Issue para Probar

**Issue #1305**: Volunteers page stuck "Loading..."

```bash
# Marcar para AI-SDLC
gh issue edit 1305 -R os-santiago/homedir --add-label "ready-to-implement"

# Test en GitHub Actions
gh workflow run test-autonomous-worker.yml -f issue_number=1305

# Monitorear
gh run watch
```

**Esperado**: Worker crea PR automáticamente

---

**Status**: ✅ Test autónomo ejecutándose en GitHub Actions

---

## 🚀 Test en Ejecución (2026-08-01 18:53 UTC)

**Run ID**: 30713558279  
**Issue**: #1310 - Login redirect no URL-encoded  
**URL**: https://github.com/os-santiago/homedir-ai-sdlc/actions/runs/30713558279

**Descripción del bug**: Login redirect pasa `/beta` en lugar de `%2F` (URL encoding)  
**Tipo**: Security/URL handling  
**Complejidad**: Simple

**Tiempo estimado**: ~15 minutos

### **Monitoreo**

```bash
gh run watch 30713558279 -R os-santiago/homedir-ai-sdlc
```

**Esperado**: PR creado automáticamente corrigiendo el URL encoding del redirect
