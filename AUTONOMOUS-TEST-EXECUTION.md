# 🚀 Ejecución del Test Autónomo

**Fecha**: 2026-08-01  
**Método**: GitHub Actions (no requiere Docker local)  
**Issue**: #1306  
**Estado**: ⏳ Listo para ejecutar

---

## ✅ Preparación Completada

1. ✅ Issue #1306 marcado con `ready-to-implement`
2. ✅ Workflow `test-autonomous-worker.yml` creado
3. ✅ Código pusheado a GitHub
4. ⏳ Falta: Configurar secret `SC_API_KEY`

---

## 🔐 Configurar Secret en GitHub

### **Paso 1: Ir a Settings**

```
https://github.com/os-santiago/homedir-ai-sdlc/settings/secrets/actions
```

### **Paso 2: Agregar Secret**

Click en **"New repository secret"**

**Name**: `SC_API_KEY`  
**Value**: `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`

(Este es el API key de NVIDIA que está en tu `~/.sc-agent/config.json`)

### **Paso 3: Verificar**

Debe aparecer en la lista de secrets:
- `SC_API_KEY` ✅

---

## ▶️ Ejecutar Test Autónomo

### **Opción 1: Desde CLI**

```bash
cd /d/git/homedir-ai-sdlc

gh workflow run test-autonomous-worker.yml -f issue_number=1306
```

### **Opción 2: Desde GitHub UI**

1. Ir a https://github.com/os-santiago/homedir-ai-sdlc/actions
2. Click en "Test Autonomous Worker"
3. Click en "Run workflow"
4. Issue number: `1306`
5. Click "Run workflow"

---

## 📊 Monitorear Ejecución

### **Ver en tiempo real**

```bash
# Ver workflow running
gh run watch

# O listar runs
gh run list --workflow=test-autonomous-worker.yml
```

### **Ver logs**

```bash
# Cuando complete, ver logs
gh run view --log
```

---

## 🎯 Qué Esperar

### **Si TODO Funciona** ✅

**Workflow debe**:
1. ✅ Build de imagen worker (5-7 min)
2. ✅ Ejecutar worker en contenedor
3. ✅ Worker detecta issue #1306
4. ✅ Admission review (policy match)
5. ✅ **SCC genera código** (5-10 min)
6. ✅ Worker crea PR automáticamente
7. ✅ Workflow reporta PR number

**Resultado esperado**:
```
✅ PR Created: #XXXX
```

**Luego tú solo monitoreas**:
```bash
gh pr view XXXX -R os-santiago/homedir
gh pr checks XXXX -R os-santiago/homedir --watch
```

**Si CI pasa → merge manual** (auto-merge aún no configurado)

### **Si Falla** ❌

**Workflow reportará**:
- ❌ Exit code del worker
- ❌ No PR created
- 📝 Logs subidos como artifact

**Entonces tú**:
1. Descargas logs del artifact
2. Analizas en qué fase falló
3. Documentas el problema
4. Creas issue de mejora en homedir-ai-sdlc
5. Implementas el fix
6. Repites el test

---

## 🔄 Ciclo de Mejora

### **Protocolo de Mejora Continua**

```
1. Ejecutar test autónomo
   ↓
2. ¿Funcionó?
   ├─ SÍ → ✅ ÉXITO - Autonomía validada
   └─ NO → Analizar logs
           ↓
3. Identificar fase que falló
   ↓
4. Crear issue de mejora
   ↓
5. Implementar fix
   ↓
6. Volver a paso 1
```

**Repetir hasta que**: Issue → PR → Merge **SIN INTERVENCIÓN**

---

## 📋 Checklist de Ejecución

### **Pre-ejecución**

- [x] Issue #1306 marcado `ready-to-implement`
- [x] Workflow creado y pusheado
- [ ] Secret `SC_API_KEY` configurado en GitHub
- [ ] Workflow ejecutado

### **Durante ejecución**

- [ ] Workflow inicia correctamente
- [ ] Build de imagen exitoso
- [ ] Worker ejecuta sin errores
- [ ] Logs muestran progreso

### **Post-ejecución**

- [ ] PR creado automáticamente
- [ ] PR tiene código correcto
- [ ] CI checks ejecutándose
- [ ] (Manual) Merge del PR

### **Validación final**

- [ ] Issue cerrado automáticamente
- [ ] Fix visible en producción
- [ ] Tiempo E2E documentado
- [ ] Autonomía confirmada

---

## 🎯 Métricas del Test

**Registrar**:
- ⏱️ Tiempo total (inicio workflow → PR creado)
- 🤖 Autonomía (% sin intervención)
- ✅ Success rate (pasó/falló)
- 📝 Fases completadas
- ❌ Fases que fallaron (si aplica)

---

## 🚀 Estado Actual

**Listo para ejecutar**: ✅

**Falta solo**:
1. Configurar `SC_API_KEY` secret en GitHub
2. Ejecutar: `gh workflow run test-autonomous-worker.yml -f issue_number=1306`
3. Monitorear y documentar resultado

---

**Próximo comando**:

```bash
# Una vez SC_API_KEY configurado
gh workflow run test-autonomous-worker.yml -f issue_number=1306

# Luego monitorear
gh run watch
```

**Criterio de éxito**: PR creado automáticamente para issue #1306 sin intervención humana.
