# AI-SDLC Event System - Implementation Roadmap

Camino incremental desde componentes base hasta interfaz de usuario.

---

## 🎯 Fases de Implementación

```
Phase 1: Baseline Verification
    ↓
Phase 2: Event Infrastructure
    ↓
Phase 3: Worker Integration
    ↓
Phase 4: Testing & Validation
    ↓
Phase 5: API Layer (Java)
    ↓
Phase 6: Dashboard UI
    ↓
Phase 7: Production Deployment
```

---

## Phase 1: Baseline Verification ✓

**Objetivo**: Verificar componentes existentes funcionando.

### Checklist
- [x] Worker script existe: `platform/scripts/homedir-sdlc-worker.sh`
- [x] Dashboard Quarkus funciona: puerto 8081
- [x] State directory existe: `/var/lib/homedir-sdlc/`
- [x] GitHub Actions workflow funciona
- [x] VPS deployment activo (systemd timer)

### Validación
```bash
# Ver worker actual
ls -lh platform/scripts/homedir-sdlc-worker.sh

# Ver dashboard
ls -lh dashboard/quarkus-app/src/main/java/io/opensourcesantiago/aisdlc/

# Ver state
ls -lh /var/lib/homedir-sdlc/  # (en VPS)
```

**Status**: ✅ Completado (componentes existen)

---

## Phase 2: Event Infrastructure

**Objetivo**: Crear infraestructura de eventos sin modificar worker.

### 2.1 Deploy Event Schema
```bash
# Ya creado
platform/config/event-schema.json
```

### 2.2 Deploy Event Emitter
```bash
# Ya creado
platform/scripts/event-emitter.sh

# Hacer ejecutable
chmod +x platform/scripts/event-emitter.sh
```

### 2.3 Test Event System Standalone
```bash
# Test manual del event emitter
cd /d/git/homedir-ai-sdlc

# Source el script
source platform/scripts/event-emitter.sh

# Inicializar
init_event_system

# Emitir evento de prueba
emit_heartbeat

# Verificar que se creó
ls -lh local-state/events/  # (si ejecutas local)
cat local-state/events/all-events.jsonl
```

### 2.4 Validation Script
```bash
# Crear script de validación
./test-event-system.sh

# Expected output:
# ✓ Event system initialized
# ✓ Event emitted: evt_...
# ✓ Queue created: heartbeat/
# ✓ All-events stream updated
```

**Deliverable**: Event system funciona standalone

---

## Phase 3: Worker Integration

**Objetivo**: Integrar eventos al worker sin romper funcionalidad.

### 3.1 Backup Worker Actual
```bash
cp platform/scripts/homedir-sdlc-worker.sh \
   platform/scripts/homedir-sdlc-worker.sh.backup-$(date +%Y%m%d)
```

### 3.2 Add Event Emitter Source

**File**: `platform/scripts/homedir-sdlc-worker.sh`

**Location**: Después de cargar configuración, antes de funciones

```bash
# ============================================================================
# Event System Integration
# ============================================================================

# Source event emitter
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/event-emitter.sh"

# Initialize event system
init_event_system

log "INFO: Event system initialized"
```

### 3.3 Add Key Emission Points

**Emission Points** (según `integrate-events-to-worker.sh`):

#### Point 1: Worker Heartbeat
```bash
# En función reconcile(), al inicio
reconcile() {
  emit_heartbeat
  
  # ... existing code ...
}
```

#### Point 2: Issue Detection
```bash
# Después de encontrar ready-to-implement issues
for issue in "${READY_ISSUES[@]}"; do
  issue_number=$(echo "$issue" | jq -r '.number')
  
  emit_issue_detected "$issue_number" "$issue"
  
  # ... existing code ...
done
```

#### Point 3: Issue Claimed
```bash
# Después de agregar label scc-claimed
gh issue edit "$issue_number" --add-label "scc-claimed"

emit_issue_claimed "$issue_number"
```

#### Point 4: Admission Review
```bash
# Antes de admission
emit_admission_started "$issue_number"

# ... run admission logic ...

# Después de decisión
emit_admission_completed "$issue_number" "$DECISION" "$REASON"
```

#### Point 5: Implementation
```bash
# Antes de SCC
START_TIME=$(date +%s%3N)
emit_implementation_started "$issue_number"

# ... run SCC ...

END_TIME=$(date +%s%3N)
DURATION=$((END_TIME - START_TIME))
FILES_CHANGED=$(git diff --name-only | wc -l)

emit_implementation_completed "$issue_number" "$DURATION" "$FILES_CHANGED"
```

#### Point 6: PR Created
```bash
# Después de crear PR
PR_NUMBER=$(echo "$PR_RESPONSE" | jq -r '.number')
PR_URL=$(echo "$PR_RESPONSE" | jq -r '.html_url')

emit_pr_created "$issue_number" "$PR_NUMBER" "$PR_URL"
```

#### Point 7: Error Handling
```bash
# En catch blocks
handle_error() {
  local error_msg="$1"
  
  emit_error "$issue_number" "$error_msg"
  
  # ... existing error handling ...
}
```

### 3.4 Integration Checklist

- [ ] Event emitter sourced at top
- [ ] `init_event_system` called
- [ ] Heartbeat emitted per reconcile cycle
- [ ] Issue detection emits event
- [ ] Claim emits event
- [ ] Admission start/complete emit events
- [ ] Implementation start/complete emit events
- [ ] PR creation emits event
- [ ] Errors emit events

**Deliverable**: Worker emite eventos durante ejecución

---

## Phase 4: Testing & Validation

**Objetivo**: Verificar que eventos se generan correctamente.

### 4.1 Local Test (Dry Run)

```bash
# Ejecutar worker en modo dry-run (si existe)
# O ejecutar contra issue de prueba

# Verificar eventos generados
ls -lh local-state/events/
cat local-state/events/all-events.jsonl | jq .
```

### 4.2 GitHub Actions Test

```bash
# Trigger workflow
gh workflow run test-autonomous-worker.yml --ref main

# Esperar completado
gh run watch

# Ver logs - deben mostrar [EVENT] lines
gh run view --log | grep "\[EVENT\]"
```

### 4.3 Validation Checks

```bash
# Check 1: Events stream exists
test -f /var/lib/homedir-sdlc/events/all-events.jsonl

# Check 2: Multiple event types
jq -r '.event_type' /var/lib/homedir-sdlc/events/all-events.jsonl | sort | uniq

# Check 3: Tracking IDs assigned
jq -r '.tracking_id' /var/lib/homedir-sdlc/events/all-events.jsonl | sort | uniq

# Check 4: Event schema valid
jq 'select(.event_id == null or .tracking_id == null)' \
  /var/lib/homedir-sdlc/events/all-events.jsonl
# Should return empty
```

### 4.4 Rollback Plan

Si algo falla:
```bash
# Restore backup
cp platform/scripts/homedir-sdlc-worker.sh.backup-YYYYMMDD \
   platform/scripts/homedir-sdlc-worker.sh

# Restart worker
systemctl --user restart homedir-sdlc-worker
```

**Deliverable**: Eventos válidos generándose en producción

---

## Phase 5: API Layer (Java)

**Objetivo**: Exponer eventos via REST API.

### 5.1 Add Java Classes

Ya creados:
```
dashboard/quarkus-app/src/main/java/io/opensourcesantiago/aisdlc/events/
├── EventApiResource.java       (REST endpoints)
└── EventQueryService.java      (Query logic)
```

### 5.2 Update pom.xml

Verificar dependencies en `dashboard/quarkus-app/pom.xml`:
```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-rest</artifactId>
</dependency>
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-rest-jackson</artifactId>
</dependency>
```

### 5.3 Build & Test

```bash
cd dashboard/quarkus-app

# Build
./mvnw clean package

# Run in dev mode
./mvnw quarkus:dev

# Test endpoints
curl http://localhost:8081/api/sdlc/events/latest?limit=10
curl http://localhost:8081/api/sdlc/events/stats
```

### 5.4 Integration Tests

```bash
# Test con issue real
ISSUE_NUM=1360

# Get timeline
curl http://localhost:8081/api/sdlc/events/issue/$ISSUE_NUM | jq .

# Expected response:
# {
#   "issue_number": 1360,
#   "tracking_id": "track_1360_...",
#   "events": [...]
# }
```

### 5.5 API Validation Checklist

- [ ] `/latest` returns events
- [ ] `/stats` returns statistics
- [ ] `/active` returns active issues
- [ ] `/issue/{number}` returns timeline
- [ ] `/timeline/{number}` returns formatted data
- [ ] All responses are valid JSON
- [ ] Error handling works (404 for missing issues)

**Deliverable**: API REST funcional en puerto 8081

---

## Phase 6: Dashboard UI

**Objetivo**: Interfaz web para visualizar eventos.

### 6.1 Deploy Frontend Files

Ya creados:
```
dashboard/quarkus-app/src/main/resources/META-INF/resources/sdlc/events/
├── index.html
└── events-dashboard.js
```

### 6.2 Test Dashboard Locally

```bash
# Con Quarkus en dev mode
./mvnw quarkus:dev

# Abrir browser
# http://localhost:8081/sdlc/events/
```

### 6.3 Functional Tests

**Manual testing checklist**:

- [ ] Dashboard loads without errors
- [ ] Statistics box shows data
- [ ] Active issues grid populates
- [ ] Pipeline stages render
- [ ] Timeline shows events
- [ ] Search by issue works
- [ ] Auto-refresh toggle works
- [ ] Click on active issue loads timeline
- [ ] Events show correct metadata
- [ ] Timestamps are relative (e.g., "5m ago")

### 6.4 UI/UX Validation

- [ ] Responsive design (desktop/tablet)
- [ ] Colors are readable
- [ ] Icons load correctly
- [ ] No console errors
- [ ] Loading states show
- [ ] Error states show gracefully

**Deliverable**: Dashboard web funcional y usable

---

## Phase 7: Production Deployment

**Objetivo**: Deploy completo en VPS.

### 7.1 Deploy Updated Worker

```bash
# SSH al VPS
ssh homedir-sdlc@vps

# Pull latest code
cd ~/homedir-ai-sdlc
git pull origin main

# Restart worker
systemctl --user restart homedir-sdlc-worker

# Verify events generating
tail -f /var/lib/homedir-sdlc/events/all-events.jsonl
```

### 7.2 Deploy Dashboard

```bash
# Build en local
cd dashboard/quarkus-app
./mvnw clean package -DskipTests

# Copy JAR al VPS
scp target/quarkus-app/quarkus-run.jar homedir-sdlc@vps:~/

# En VPS, restart dashboard
systemctl --user restart homedir-dashboard
```

### 7.3 Smoke Tests

```bash
# Test 1: Worker emite heartbeat
curl http://vps:8081/api/sdlc/events/latest?limit=1 | \
  jq 'select(.[0].event_type == "worker.heartbeat")'

# Test 2: Active issues
curl http://vps:8081/api/sdlc/events/active

# Test 3: Dashboard loads
curl -I http://vps:8081/sdlc/events/
# Should return 200 OK
```

### 7.4 End-to-End Test

```bash
# 1. Mark issue
gh issue edit 1360 -R os-santiago/homedir --add-label "ready-to-implement"

# 2. Wait for worker cycle (max 3 min)
sleep 180

# 3. Check events generated
curl http://vps:8081/api/sdlc/events/issue/1360 | jq '.events | length'
# Should be > 0

# 4. View in dashboard
# http://vps:8081/sdlc/events/
# Search for issue 1360
```

### 7.5 Monitoring Setup

```bash
# Add cron to check event system health
crontab -e

# Add:
# */15 * * * * curl -s http://localhost:8081/api/sdlc/events/stats > /dev/null || \
#   echo "Event API down" | mail -s "AI-SDLC Alert" admin@example.com
```

### 7.6 Production Checklist

- [ ] Worker emitiendo eventos
- [ ] Event queues poblándose
- [ ] API respondiendo en VPS
- [ ] Dashboard accesible públicamente
- [ ] Auto-refresh funcionando
- [ ] No memory leaks (check con `top`)
- [ ] Logs limpios (no errors en stderr)
- [ ] Backups configurados para `/var/lib/homedir-sdlc/events/`

**Deliverable**: Sistema completo en producción

---

## 📊 Success Metrics

### Phase 2-3: Infrastructure
- ✅ Event system no rompe worker existente
- ✅ Al menos 1 evento por reconcile cycle
- ✅ Zero errores en worker logs

### Phase 4: Validation
- ✅ Todos los event types generándose
- ✅ Tracking IDs únicos por issue
- ✅ Event schema válido (100% compliance)

### Phase 5: API
- ✅ 7/7 endpoints respondiendo
- ✅ Response time < 100ms para latest/stats
- ✅ Response time < 500ms para timeline

### Phase 6: Dashboard
- ✅ Page load < 2s
- ✅ Auto-refresh sin memory leaks
- ✅ Search response < 1s
- ✅ Zero console errors

### Phase 7: Production
- ✅ Uptime > 99.9%
- ✅ Events generados 24/7
- ✅ Dashboard accesible sin downtime
- ✅ E2E test passing: issue → PR → merged con full traceability

---

## 🚨 Rollback Strategy

### Per Phase

**Phase 3**: 
```bash
cp platform/scripts/homedir-sdlc-worker.sh.backup \
   platform/scripts/homedir-sdlc-worker.sh
```

**Phase 5**:
```bash
# Remove event classes
git revert <commit-hash>
./mvnw clean package
```

**Phase 6**:
```bash
# Remove dashboard route
rm -rf dashboard/.../resources/sdlc/events/
```

**Phase 7**:
```bash
# Revert to previous deployment
systemctl --user stop homedir-sdlc-worker
git checkout <previous-commit>
systemctl --user start homedir-sdlc-worker
```

### Emergency Rollback
```bash
# Complete rollback to pre-events state
git checkout <baseline-commit>
./deploy-worker.sh  # Your existing deployment script
```

---

## 📅 Timeline Estimate

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1 | 30 min | None |
| Phase 2 | 1 hour | Phase 1 |
| Phase 3 | 2-3 hours | Phase 2 |
| Phase 4 | 1-2 hours | Phase 3 |
| Phase 5 | 2 hours | Phase 4 |
| Phase 6 | 1 hour | Phase 5 |
| Phase 7 | 2 hours | Phase 6 |
| **Total** | **10-12 hours** | Sequential |

**Recommendation**: 
- Days 1-2: Phases 1-4 (worker integration + validation)
- Day 3: Phases 5-6 (API + dashboard)
- Day 4: Phase 7 (production deployment + monitoring)

---

## 🎯 Current Status

**Phase 1**: ✅ COMPLETED  
**Phase 2**: 🟡 IN PROGRESS (files created, need testing)  
**Phase 3**: ⚪ PENDING  
**Phase 4**: ⚪ PENDING  
**Phase 5**: 🟡 IN PROGRESS (code written, need build)  
**Phase 6**: 🟡 IN PROGRESS (HTML/JS created, need deployment)  
**Phase 7**: ⚪ PENDING  

---

## Next Step

**Start Phase 2.3**: Test event system standalone

```bash
cd D:\git\homedir-ai-sdlc
source platform/scripts/event-emitter.sh
init_event_system
emit_heartbeat
```

Expected output:
```
[EVENT] worker.heartbeat | Issue #0 | Status: completed | Event ID: evt_...
```

Then verify:
```bash
cat local-state/events/all-events.jsonl | jq .
```
