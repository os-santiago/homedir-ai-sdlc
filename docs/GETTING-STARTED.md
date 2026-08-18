# Getting Started - Crear Issues para AI-SDLC

Esta guía explica cómo crear issues que serán procesados automáticamente por el sistema homedir-ai-sdlc desde la creación hasta el deployment en producción.

## 🎯 Requisitos Mínimos

### Labels Requeridos

Para que un issue entre al flujo autónomo, debe tener **ambos** labels:

1. **`ready-to-implement`** - Indica que el issue está listo para ser procesado
2. **`priority:P3`** (o P1, P2) - Indica la prioridad

**Sin estos labels, el worker NO procesará el issue.**

### Formato del Issue

```markdown
**Description:**
[Descripción clara y específica del problema o feature]

**Current state:**
[Estado actual del código/comportamiento]

**Desired state:**
[Estado deseado después de la implementación]

**Acceptance Criteria:**
- [ ] Criterio 1 específico y verificable
- [ ] Criterio 2 específico y verificable
- [ ] Criterio 3 específico y verificable (opcional)

**Complexity:** [simple|medium|complex]
**Priority:** [P1|P2|P3]
**Type:** [bug|feature|enhancement|test]
```

## 📝 Ejemplos

### Ejemplo 1: Bug Fix Simple

```markdown
**Description:**
Fix typo in homepage title - "Welcom" should be "Welcome"

**Current state:**
Homepage displays "Welcom to Homedir" in the H1 tag

**Desired state:**
Homepage should display "Welcome to Homedir" correctly

**Acceptance Criteria:**
- [ ] H1 tag contains "Welcome to Homedir" with correct spelling
- [ ] No other text changes on the homepage
- [ ] PR passes all CI checks

**Complexity:** simple
**Priority:** P3
**Type:** bug
```

**Labels**: `ready-to-implement`, `priority:P3`, `bug`

**Tiempo estimado**: 10-15 minutos

---

### Ejemplo 2: Feature Request Medium

```markdown
**Description:**
Add dark mode toggle button to navigation bar

**Current state:**
Application has no dark mode support

**Desired state:**
Users can toggle between light and dark mode via a button in the top navigation bar

**Acceptance Criteria:**
- [ ] Toggle button added to navigation bar
- [ ] Clicking button switches between light/dark themes
- [ ] User preference persisted in localStorage
- [ ] All pages respect the selected theme

**Complexity:** medium
**Priority:** P2
**Type:** feature
```

**Labels**: `ready-to-implement`, `priority:P2`, `feature-request`

**Tiempo estimado**: 20-30 minutos

---

### Ejemplo 3: Documentation Update

```markdown
**Description:**
Add API authentication section to README.md

**Current state:**
README.md has no documentation about API authentication

**Desired state:**
README.md section 5 should document how to authenticate with the API

**Acceptance Criteria:**
- [ ] New section "API Authentication" added after "Installation" section
- [ ] Documents both token and OAuth methods
- [ ] Includes code examples for both methods
- [ ] PR passes markdown linting checks

**Complexity:** simple
**Priority:** P3
**Type:** documentation
```

**Labels**: `ready-to-implement`, `priority:P3`, `documentation`

**Tiempo estimado**: 10-15 minutos

---

## 🚀 Cómo Crear el Issue

### Vía GitHub Web UI

1. Ir a https://github.com/os-santiago/homedir/issues/new
2. Copiar el formato del template
3. Llenar los detalles específicos
4. Añadir labels: `ready-to-implement` + prioridad (P1/P2/P3)
5. Click "Submit new issue"

### Vía GitHub CLI

```bash
# Crear issue desde archivo
cat > /tmp/my-issue.md << 'EOF'
**Description:**
Add validation for email field in contact form

**Current state:**
Contact form accepts invalid email addresses

**Desired state:**
Contact form validates email format before submission

**Acceptance Criteria:**
- [ ] Email field validates format (user@domain.com)
- [ ] Shows error message for invalid emails
- [ ] Prevents form submission with invalid email

**Complexity:** simple
**Priority:** P3
**Type:** bug
EOF

gh issue create \
  --title "Add email validation to contact form" \
  --body-file /tmp/my-issue.md \
  --label "ready-to-implement,priority:P3,bug" \
  --repo os-santiago/homedir
```

### Vía API

```bash
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  https://api.github.com/repos/os-santiago/homedir/issues \
  -d '{
    "title": "Add email validation to contact form",
    "body": "**Description:**\nAdd validation for email field...",
    "labels": ["ready-to-implement", "priority:P3", "bug"]
  }'
```

---

## ⏱️ Qué Esperar - Timeline

### Flujo Completo Automatizado

```
0:00  - Creas el issue con labels correctos
        ↓
0:00  - Worker detecta issue en próximo ciclo (máx 3 min)
        ↓
0:01  - Admission review (automática vía políticas)
        ↓
0:01  - Issue aprobado → Label scc-accepted añadido
        ↓
0:01  - Issue claimed → Label scc-queued añadido
        ↓
0:02  - SCC ejecuta (NVIDIA Nemotron 550B AI)
        ↓ (Duración: 5-25 min según complejidad)
0:15  - Código generado → Branch creado
        ↓
0:15  - PR creado automáticamente
        ↓
0:15  - CI checks ejecutados (20 checks)
        ↓ (~3-4 minutos)
0:19  - CI checks passed ✓
        ↓
0:20  - Worker verifica coverage
        ↓
0:20  - Auto-merge habilitado ✓
        ↓
0:20  - PR merged a main ✓
        ↓
0:20  - Issue auto-closed ✓
        ↓
0:20  - Deployed a producción ✓
```

**Tiempo total**: 10-30 minutos (simple), 20-40 minutos (medium), 30-60 minutos (complex)

### Labels Durante el Proceso

Puedes seguir el progreso del issue observando los labels:

```
ready-to-implement           → Issue creado, esperando
    ↓
scc-admission-review         → En revisión de admission
    ↓
scc-accepted                 → Aprobado para procesamiento
    ↓
scc-queued                   → En cola, será procesado pronto
    ↓
scc-running                  → SCC ejecutando código
    ↓
scc-pr-created               → PR creado
    ↓
scc-waiting-checks           → Esperando CI checks
    ↓
scc-approved                 → CI passed, listo para merge
    ↓
scc-merged                   → PR merged, issue closed ✓
```

**Labels de error**:
- `needs-human` - Requiere intervención humana
- `scc-failed` - Procesamiento falló
- `scc-coverage-gap` - Coverage incompleto (se auto-remedia)

---

## ✅ Mejores Prácticas

### 1. **Sea Específico**

❌ **Malo**: "Fix the login"
```markdown
**Description:** Fix the login
**Acceptance Criteria:**
- [ ] Login works
```

✅ **Bueno**: "Fix login button not responding on mobile"
```markdown
**Description:**
Login button on mobile devices (viewport < 768px) doesn't respond to clicks

**Current state:**
On mobile browsers, clicking login button has no effect

**Desired state:**
Login button triggers authentication on mobile devices

**Acceptance Criteria:**
- [ ] Login button clickable on mobile (< 768px viewport)
- [ ] Authentication flow completes on mobile Safari
- [ ] Authentication flow completes on mobile Chrome
```

### 2. **Un Solo Problema por Issue** (Principio ADEV)

❌ **Malo**: Multiple problemas en un issue
```markdown
**Description:**
Fix login, add dark mode, and update documentation
```

✅ **Bueno**: Un issue por problema
```markdown
Issue #1: Fix login button on mobile
Issue #2: Add dark mode toggle
Issue #3: Update authentication docs
```

**Razón**: Worker usa principio ADEV (Atomic Development). Issues multi-criterio serán rechazados o auto-splitteados.

### 3. **Acceptance Criteria Verificables**

❌ **Malo**: Criterios vagos
```markdown
**Acceptance Criteria:**
- [ ] Make it better
- [ ] Improve performance
- [ ] Fix all bugs
```

✅ **Bueno**: Criterios específicos y verificables
```markdown
**Acceptance Criteria:**
- [ ] Login response time < 500ms (measured via Network tab)
- [ ] Error message displays when credentials invalid
- [ ] Success redirect to /dashboard after login
```

### 4. **Incluir Contexto de Archivos**

Si sabes qué archivo modificar, inclúyelo:

```markdown
**Description:**
Update copyright year in footer

**Current state:**
Footer shows "© 2025 Homedir"
File: `quarkus-app/src/main/resources/templates/footer.html` line 23

**Desired state:**
Footer shows "© 2026 Homedir"

**Acceptance Criteria:**
- [ ] Footer displays "© 2026 Homedir"
- [ ] Change only in footer.html, no other files modified
```

### 5. **Complejidad Apropiada**

**Simple** (5-25 min):
- Typo fixes
- Single line changes
- Comment additions
- Simple label changes

**Medium** (20-40 min):
- Small feature additions
- Multi-file refactors
- Configuration changes
- Simple API additions

**Complex** (30-60 min):
- New components
- Database migrations
- Authentication changes
- Multi-system integrations

---

## 🚫 Qué NO Hacer

### ❌ Issues que Serán Rechazados

1. **Sin labels correctos**
   ```
   Issue sin ready-to-implement → No será procesado
   ```

2. **Demasiado vago**
   ```markdown
   **Description:** Make the app better
   ```

3. **Multiple problemas** (violación ADEV)
   ```markdown
   **Description:** Fix login, signup, and password reset
   ```

4. **Sin acceptance criteria**
   ```markdown
   **Description:** Add feature X
   (no criteria defined)
   ```

5. **Requiere decisiones de producto**
   ```markdown
   **Description:** Design new homepage
   (requiere diseño UX, no es implementación directa)
   ```

6. **Cambios que requieren aprobación legal/compliance**
   ```markdown
   **Description:** Change data retention policy
   (automáticamente marcado legal-review)
   ```

---

## 🔍 Troubleshooting

### Issue No Procesado Después de 10 Minutos

**Verificar**:
1. ¿Tiene label `ready-to-implement`? → Añadir si falta
2. ¿Tiene label de prioridad (P1/P2/P3)? → Añadir si falta
3. ¿Tiene label `needs-human`? → Revisar comentarios del worker
4. ¿Issue cerrado prematuramente? → Verificar duplicados

**Comando de diagnóstico**:
```bash
gh issue view <number> --json labels,comments
```

### Worker Marcó `needs-human`

El worker añade este label cuando:
- SCC no pudo generar código (descripción muy vaga)
- Requiere contexto adicional
- Coverage gap no pudo remediarse
- Error en CI checks irremediable

**Solución**: Leer último comentario del worker y actualizar issue con información solicitada.

### PR Creado Pero No Merged

**Posibles causas**:
1. CI checks fallando → Worker intentará remediar (máx 5 intentos)
2. Coverage gap detectado → Worker ejecutará SCC remediation
3. Requiere human review → Revisar branch protection rules

**Ver estado**:
```bash
gh pr view <number> --json autoMergeRequest,statusCheckRollup
```

---

## 📚 Recursos Adicionales

- **Políticas de Auto-Approval**: `platform/config/autonomous-decision-policy.yaml` (241 políticas)
- **Worker Script**: `platform/scripts/homedir-sdlc-worker.sh`
- **Documentación Completa**: `docs/AUTONOMY-ACHIEVEMENT.md`
- **Configuración CLAUDE.md**: `CLAUDE.md`

---

## 💡 Tips Pro

### Acelerar Procesamiento

1. **Usar complejidad correcta**: Simple issues se procesan con timeout 15min vs 25min complex
2. **Archivos específicos**: Mencionar archivos exactos en descripción
3. **Criterios claros**: Acceptance criteria verificables acelera validation
4. **Evitar ambigüedad**: Menos iteraciones de remediation

### Batch Processing

Puedes crear múltiples issues a la vez. Worker procesará **uno a la vez (FIFO)** por el principio de atomicidad.

```bash
# Crear 3 issues simples
for i in {1..3}; do
  gh issue create \
    --title "Task $i" \
    --body "..." \
    --label "ready-to-implement,priority:P3"
done
```

Worker procesará: Issue 1 → complete → Issue 2 → complete → Issue 3

### Monitorear Progreso

**Dashboard** (cuando disponible):
```
https://homedir-ai-sdlc.opensourcesantiago.io
```

**Via CLI**:
```bash
# Ver issues en proceso
gh issue list --label "scc-running" --state open

# Ver PRs pendientes
gh pr list --label "scc-waiting-checks"

# Ver completados hoy
gh issue list --label "scc-merged" --search "closed:>=$(date -I)"
```

**Worker Heartbeat**:
```bash
# Si tienes acceso VPS
ssh root@72.60.141.165 cat /var/lib/homedir-sdlc/heartbeat.json
```

---

## 🎓 Ejemplo Completo End-to-End

### Paso a Paso Real

**1. Crear issue** (14:07 UTC):
```bash
gh issue create \
  --title "[E2E-TEST] Add timestamp to README" \
  --body-file issue-template.md \
  --label "ready-to-implement,priority:P3"
```

**2. Worker detecta** (14:11 UTC - 4 min después):
```
Label scc-accepted añadido
Label scc-queued añadido
```

**3. SCC ejecuta** (14:17 UTC - 6 min después):
```
Branch creado: scc/issue-1499-add-timestamp-to-readme
Cambios committed
Label scc-running añadido
```

**4. PR creado** (14:17 UTC - mismo momento):
```
PR #1500 creado
CI checks iniciados
Label scc-pr-created añadido
```

**5. CI completa** (14:22 UTC - 5 min después):
```
20/20 checks passed ✓
```

**6. Auto-merge** (14:45 UTC - 23 min después):
```
Worker verificó coverage
Worker habilitó auto-merge
PR merged a main ✓
Issue auto-closed ✓
```

**Tiempo total**: 38 minutos sin intervención humana ✓

---

## ⚙️ Configuración Avanzada

### Custom Labels

Puedes añadir labels adicionales (además de los requeridos):

- `bug`, `feature-request`, `enhancement`
- `documentation`, `test`, `refactor`
- `frontend`, `backend`, `devops`

Estos labels NO afectan el procesamiento, solo categorizan.

### Mencionar Usuarios

```markdown
**Description:**
Fix login validation

cc @scanales-stack for review after merge

**Acceptance Criteria:**
- [ ] Email validation added
```

El worker ignorará las menciones, pero servirán para notificaciones post-merge.

### Issues de Test

Para testing del sistema:

```markdown
**Type:** E2E Test - Auto-merge validation
```

Worker procesará normalmente, útil para validar cambios al sistema.

---

## 📞 Support

Si tienes problemas:

1. **Revisar heartbeat**: Worker debe actualizarse cada 180s
2. **Verificar labels**: ready-to-implement + priority requeridos
3. **Leer comentarios**: Worker comenta cada paso
4. **Check logs**: Via VPS o GitHub Actions

**Crear issue en homedir-ai-sdlc repo**:
```bash
gh issue create \
  --repo os-santiago/homedir-ai-sdlc \
  --title "Worker not processing issue #1234" \
  --label "sdlc-infrastructure"
```

---

**Última actualización**: 2026-08-18  
**Sistema validado**: 100% autonomía E2E  
**Worker version**: 6c5044a
