# Evaluación de Autonomía - homedir-ai-sdlc
**Fecha:** 2026-08-16 23:52 UTC  
**Pregunta:** ¿Permite el sistema un ciclo totalmente autónomo donde basta crear un issue para que sea resuelto e implementado end-to-end?

---

## 📊 RESPUESTA: NO (Actualmente ~40% autónomo)

El sistema **NO es completamente autónomo** en su estado actual. Requiere múltiples intervenciones manuales.

---

## 🔍 EVALUACIÓN DETALLADA POR ETAPA

### ✅ Etapa 1: Detección de Issues (100% autónomo)
**Estado:** ✅ COMPLETAMENTE AUTÓNOMO

El worker detecta automáticamente issues con el label `ready-to-implement`:
```
2026-08-16T22:19:56Z [worker] reconcile_admission_requests: evaluating issue #1440
```

**Resultado:** ✅ Sin intervención manual necesaria

---

### ⚠️ Etapa 2: Admission (Atomicity Check) (50% autónomo)

**Estado:** ⚠️ REQUIERE INTERVENCIÓN MANUAL

El worker verifica que el issue tenga 1-2 acceptance criteria (ADEV Rule #1):

**Caso A - Issue Simple (1-2 criteria):**
- ✅ Pasa automáticamente

**Caso B - Issue Complejo (>2 criteria):**
- ❌ Worker solicita split o "batch delivery"
- ❌ **REQUIERE INTERVENCIÓN:** Usuario debe agregar "batch delivery" al body del issue

**Evidencia:**
```
2026-08-16T22:22:21Z [worker] Auto-splitting issue #1440 into 4 atomic issues
2026-08-16T22:22:21Z [worker] WARN: split-multi-criteria-issue.sh not found
2026-08-16T22:29:13Z [worker] Issue #1440 atomicity check failed; not admitting to queue
```

**Intervención requerida:**
```
[MANUAL] Usuario agregó "batch delivery" al issue body
```

**Resultado:** ⚠️ **50% autónomo** (solo issues simples pasan automáticamente)

---

### ❌ Etapa 3: Acceptance (0% autónomo)

**Estado:** ❌ **REQUIERE INTERVENCIÓN MANUAL OBLIGATORIA**

El worker NO admite issues a la cola sin el label `scc-accepted`:

```
2026-08-16T22:29:13Z [worker] Issue #1440 atomicity check failed; not admitting to queue
```

**¿Por qué?**
El sistema de **auto-approval por políticas NO está funcionando**:
```
/app/scripts/policy-loader.sh: line 54: _load_policies_fallback: command not found
[WARN] Running without policy system
```

**Intervención requerida:**
```bash
[MANUAL] gh issue edit 1440 --add-label scc-accepted
```

**Resultado:** ❌ **0% autónomo** - SIEMPRE requiere aprobación manual

---

### ⚠️ Etapa 4: Queue & Claim (100% autónomo)

**Estado:** ✅ COMPLETAMENTE AUTÓNOMO

Una vez que el issue tiene `scc-accepted` y `scc-queued`, el worker lo procesa:

```
2026-08-16T22:38:42Z [worker] admitted issue #1440 to scc-queued
2026-08-16T22:41:01Z [worker] claiming issue #1440
2026-08-16T22:41:04Z [comment] Autonomous SDLC claimed this issue. Branch: scc/issue-1440-...
```

**Resultado:** ✅ Sin intervención manual necesaria

---

### ❌ Etapa 5: Code Generation (0% autónomo actualmente)

**Estado:** ❌ **BLOQUEADO - sc-agent-cli no ejecuta herramientas**

**Problema identificado:**
sc-agent-cli RESPONDE al prompt pero NO EJECUTA las tool calls (edit_file, write_file):

**Evidencia del problema:**
```
[LOG] Let me search for the specific CSS rules...
[LOG] Now I understand the issue...
[LOG] Let me fix this by adding proper text truncation to the logo subtitle...
[COMMENT] Autonomous SDLC paused: SCC completed without producing any branch changes
[COMMENT] Agent responded with intent ("Now I'll...") but did not execute tools in batch mode
```

**Causa raíz:**
A pesar de usar flags `-y` (auto-approve) y `--permissions unlimited`, sc-agent-cli no está ejecutando las herramientas automáticamente.

**Configuración actual:**
```bash
scc chat -m nvidia -y -q --permissions unlimited --throttle auto "${prompt}"
```

**Intentos realizados:**
- ✅ Primer intento: Falló (perfil ollama incorrecto)
- ✅ Segundo intento: Falló (perfil nvidia correcto, pero no ejecuta tools)

**Resultado:** ❌ **0% autónomo** - sc-agent-cli NO genera código

---

### ⏸️ Etapa 6: PR Creation (No alcanzada)

**Estado:** ⏸️ NO VERIFICADO (bloqueado por Etapa 5)

El worker tiene lógica para crear PRs automáticamente, pero no ha sido probada porque sc-agent-cli no genera código.

**Código relevante:**
```bash
# En homedir-sdlc-worker.sh
create_pr_for_issue() {
  local issue="$1"
  local branch="$2"
  # ... crear PR con gh pr create
}
```

**Resultado:** ⏸️ No evaluable aún

---

### ⏸️ Etapa 7: CI/CD & Auto-merge (No alcanzada)

**Estado:** ⏸️ NO VERIFICADO (bloqueado por Etapa 5)

El sistema tiene workflows de CI/CD configurados, pero no han sido probados en el contexto de un PR creado por el worker.

**Resultado:** ⏸️ No evaluable aún

---

## 📊 SCORE DE AUTONOMÍA ACTUAL

| Etapa | Autonomía | Bloqueador |
|-------|-----------|------------|
| 1. Detección issues | 100% ✅ | - |
| 2. Atomicity check | 50% ⚠️ | Requiere "batch delivery" manual |
| 3. Acceptance | 0% ❌ | Requiere label `scc-accepted` manual |
| 4. Queue & Claim | 100% ✅ | - |
| 5. Code generation | 0% ❌ | sc-agent-cli no ejecuta tools |
| 6. PR creation | N/A ⏸️ | Bloqueado por (5) |
| 7. CI/CD & merge | N/A ⏸️ | Bloqueado por (5) |

**AUTONOMÍA GLOBAL:** ~40% (considerando solo etapas alcanzables)

**AUTONOMÍA E2E:** 0% (ningún issue puede completarse sin intervención manual)

---

## 🚧 BLOQUEADORES CRÍTICOS

### 🔴 Bloqueador #1: Policy System No Funcional
**Impacto:** ALTO - Elimina auto-approval

**Síntoma:**
```
/app/scripts/policy-loader.sh: line 54: _load_policies_fallback: command not found
[WARN] Running without policy system
```

**Consecuencia:**
- Todos los issues requieren label `scc-accepted` manual
- El sistema de auto-approval por políticas no funciona
- Documentación menciona "policy-driven auto-approval" pero no está activo

**Solución requerida:**
Debuggear y corregir el script `policy-loader.sh` línea 54.

---

### 🔴 Bloqueador #2: sc-agent-cli No Ejecuta Herramientas
**Impacto:** CRÍTICO - Bloquea code generation completamente

**Síntoma:**
```
Agent responded with intent ("Now I'll...") but did not execute tools in batch mode
```

**Causas posibles:**
1. Flag `-y` no funciona como esperado en sc-agent-cli
2. Permissions mode `ask_once` requiere interacción (a pesar de `-y`)
3. sc-agent-cli necesita configuración adicional para batch mode
4. Bug en sc-agent-cli con profile nvidia

**Configuración actual del worker:**
```bash
scc chat -m nvidia -y -q --permissions unlimited --throttle auto "${prompt}"
```

**Configuración actual de sc-agent-cli:**
```
Permission mode: ask_once
Auto-approved: read_file, list_dir, search_text, web_fetch, memory_read
Denied: write_file, edit_file, run_shell (requires permission)
```

**Problema:** A pesar de `--permissions unlimited` en CLI, el config muestra `ask_once`.

**Solución requerida:**
1. Crear archivo `~/.sc-agent/config.json` con permissions unlimited
2. O usar variable de entorno para forzar permissions
3. O modificar worker para usar modo diferente de sc-agent-cli

---

### 🟡 Bloqueador #3: Atomicity Check Muy Restrictivo
**Impacto:** MEDIO - Rechaza issues complejos

**Síntoma:**
Issues con >2 acceptance criteria son rechazados automáticamente.

**Workaround actual:**
Agregar "batch delivery" manualmente al issue body.

**Solución requerida:**
- Implementar el script `split-multi-criteria-issue.sh` para auto-split
- O relajar la regla de 2 criteria
- O hacer auto-approval de "batch delivery" para ciertos tipos de issues

---

## 🔧 PASOS PARA LOGRAR 100% AUTONOMÍA

### Paso 1: Arreglar Policy System ⚠️ ALTA PRIORIDAD
```bash
# Debuggear policy-loader.sh
vim platform/scripts/policy-loader.sh +54
# Implementar _load_policies_fallback function
```

**Resultado esperado:**
- Auto-approval funcional para issues que cumplan políticas
- Eliminar necesidad de label `scc-accepted` manual

---

### Paso 2: Arreglar sc-agent-cli Permissions 🔴 CRÍTICO
```bash
# Opción A: Crear config global
cat > ~/.sc-agent/config.json << EOF
{
  "activeProfile": "nvidia",
  "permissions": {
    "mode": "unlimited",
    "profile": "unlimited"
  }
}
EOF

# Opción B: Variable de entorno
export SC_PERMISSIONS_MODE=unlimited

# Opción C: Usar comando diferente
scc chat --profile nvidia --yes --quiet --batch-mode "${prompt}"
```

**Resultado esperado:**
- sc-agent-cli ejecuta write_file, edit_file, git automáticamente
- Worker obtiene commits con cambios de código

---

### Paso 3: Implementar Auto-split de Issues ⚠️ MEDIA PRIORIDAD
```bash
# Crear script faltante
vim platform/scripts/split-multi-criteria-issue.sh
```

**Resultado esperado:**
- Issues complejos se dividen automáticamente
- Eliminar necesidad de agregar "batch delivery" manual

---

### Paso 4: Verificar PR Creation & Auto-merge ⏸️ BAJA PRIORIDAD
Una vez que sc-agent-cli genere código, verificar:
- Worker crea PR correctamente
- CI/CD procesa el PR
- Auto-merge funciona si los checks pasan

---

## 📋 WORKFLOW ACTUAL vs ESPERADO

### Workflow Actual (Requiere 3 intervenciones manuales)
```
┌─────────────────────────┐
│ Usuario crea issue      │
│ con ready-to-implement  │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Worker detecta issue    │ ✅ Automático
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Atomicity check         │
│ - Simple: ✅ pasa       │
│ - Complejo: ❌ rechaza  │
└───────────┬─────────────┘
            │
            ▼ [MANUAL #1]
┌─────────────────────────┐
│ Usuario agrega          │ ❌ Manual si >2 criteria
│ "batch delivery"        │
└───────────┬─────────────┘
            │
            ▼ [MANUAL #2]
┌─────────────────────────┐
│ Usuario agrega          │ ❌ Manual SIEMPRE
│ label scc-accepted      │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Worker admite a queue   │ ✅ Automático
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Worker claims issue     │ ✅ Automático
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ SCC genera código       │ ❌ BLOQUEADO
│ (sc-agent-cli)          │    (no ejecuta tools)
└───────────┬─────────────┘
            │
            ▼ [MANUAL #3]
┌─────────────────────────┐
│ Usuario implementa      │ ❌ Manual porque
│ el issue manualmente    │    sc-agent-cli falló
└─────────────────────────┘
```

### Workflow Esperado (100% autónomo)
```
┌─────────────────────────┐
│ Usuario crea issue      │
│ con ready-to-implement  │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Worker detecta + evalúa │ ✅ Automático
│ Políticas auto-aprueban │ ✅ Automático
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Worker admite a queue   │ ✅ Automático
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Worker claims + genera  │ ✅ Automático
│ código con sc-agent-cli │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Worker crea PR          │ ✅ Automático
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ CI/CD ejecuta tests     │ ✅ Automático
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Auto-merge si tests ✅  │ ✅ Automático
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Issue cerrado           │ ✅ Automático
│ Código en producción    │
└─────────────────────────┘
```

---

## 📝 CONCLUSIÓN

### Estado Actual
**El sistema homedir-ai-sdlc NO permite un ciclo totalmente autónomo.**

**Requiere mínimo 2 intervenciones manuales obligatorias:**
1. ❌ Agregar label `scc-accepted` (policy system no funciona)
2. ❌ Implementar código manualmente (sc-agent-cli no genera código)

**Y potencialmente 1 intervención adicional:**
3. ⚠️ Agregar "batch delivery" si issue tiene >2 acceptance criteria

### Autonomía Alcanzable
Con los fixes de Policy System y sc-agent-cli, el sistema podría alcanzar:
- **90-95% autonomía** para issues simples (1-2 criteria)
- **75-85% autonomía** para issues complejos (>2 criteria, requieren "batch delivery")

### Bloqueador Crítico
**sc-agent-cli no ejecuta herramientas** es el bloqueador más crítico porque:
- Bloquea code generation completamente
- Sin código → sin PRs → sin integración E2E
- Todo el flujo downstream no puede ser verificado

### Próxima Acción Recomendada
**PRIORIDAD MÁXIMA:** Debuggear y corregir sc-agent-cli permissions/batch-mode para que ejecute herramientas automáticamente.

---

**Fecha de evaluación:** 2026-08-16 23:52 UTC  
**Versión worker:** ghcr.io/os-santiago/homedir-ai-sdlc/worker:latest (commit 3db1b1a)  
**Versión sc-agent-cli:** 0.4.2

