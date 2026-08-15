# AI-SDLC Event Traceability System

Sistema completo de trazabilidad punto-a-punto con eventos estructurados, colas por etapas y dashboard web.

---

## 📊 Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────────────┐
│                     AI-SDLC Worker                                   │
│  (platform/scripts/homedir-sdlc-worker.sh)                          │
└──────────────────┬───────────────────────────────────────────────────┘
                   │ emits events
                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│              Event Emitter (event-emitter.sh)                       │
│  • Genera IDs (event_id, tracking_id, action_id)                   │
│  • Valida contra schema JSON                                        │
│  • Escribe a colas específicas por etapa                           │
└──────────────────┬───────────────────────────────────────────────────┘
                   │ writes to
                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│              Event Queue System                                      │
│  /var/lib/homedir-sdlc/events/                                      │
│  ├── all-events.jsonl           (stream completo)                  │
│  ├── tracking-state.json        (mapeo issue → tracking_id)        │
│  ├── detection/                 (eventos de detección)              │
│  ├── admission/                 (decisiones de admisión)            │
│  ├── implementation/            (ejecución SCC)                     │
│  ├── pr/                        (gestión de PRs)                    │
│  ├── ci/                        (CI checks)                         │
│  ├── remediation/               (correcciones)                      │
│  ├── deployment/                (deployments)                       │
│  └── errors/                    (errores)                           │
└──────────────────┬───────────────────────────────────────────────────┘
                   │ queries
                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│         Event Query Service (Java)                                   │
│  io.opensourcesantiago.aisdlc.events.EventQueryService              │
│  • Lee eventos de colas                                             │
│  • Construye timelines                                              │
│  • Calcula métricas                                                 │
│  • Detecta issues activos                                           │
└──────────────────┬───────────────────────────────────────────────────┘
                   │ serves
                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│            Event API (REST)                                          │
│  /api/sdlc/events/                                                   │
│  ├── /track/{trackingId}        GET events por tracking ID          │
│  ├── /issue/{issueNumber}       GET events por issue                │
│  ├── /latest                    GET últimos N events                │
│  ├── /stage/{stage}             GET events por etapa                │
│  ├── /timeline/{issueNumber}    GET timeline formateado             │
│  ├── /stats                     GET estadísticas                    │
│  └── /active                    GET issues activos                  │
└──────────────────┬───────────────────────────────────────────────────┘
                   │ consumed by
                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│          Web Dashboard (HTML + JS)                                   │
│  http://vps:8081/sdlc/events/                                       │
│  • Timeline visual de eventos                                       │
│  • Pipeline de etapas                                               │
│  • Issues activos                                                   │
│  • Estadísticas en tiempo real                                     │
│  • Auto-refresh cada 15s                                            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔑 Identificadores

### Event ID
```
evt_<uuid-v4>
Ejemplo: evt_a1b2c3d4-1234-5678-90ab-cdef12345678
```
- **Único por evento**
- UUID v4 generado al emitir
- Permite referenciar un evento específico

### Tracking ID
```
track_<issue_number>_<timestamp>
Ejemplo: track_1360_20260809143052
```
- **Único por issue**
- Se genera al detectar el issue
- Persiste durante todo el ciclo de vida
- Permite agrupar todos los eventos de un issue

### Action ID
```
act_<action_type>_<timestamp>
Ejemplo: act_pr_created_20260809143215
```
- **Único por acción**
- Identifica una acción específica en un momento
- Útil para debugging y replay

---

## 📋 Tipos de Eventos

### Detection
- `issue.detected` - Issue encontrado y marcado para procesamiento

### Admission
- `admission.started` - Inicio de admission review
- `admission.completed` - Review completado (ACCEPT o REJECT)

### Implementation
- `implementation.started` - SCC inicia generación de código
- `implementation.completed` - Código generado exitosamente

### PR Management
- `pr.created` - Pull Request creado
- `pr.updated` - PR actualizado (commits adicionales)
- `pr.merged` - PR merged a main

### CI Checks
- `ci.check.started` - CI checks iniciados
- `ci.check.failed` - Check falló
- `ci.check.passed` - Check pasó

### Remediation
- `remediation.started` - Corrección de CI failures iniciada
- `remediation.completed` - Corrección completada

### Deployment
- `deployment.started` - Deployment a producción iniciado
- `deployment.completed` - Deployed exitosamente

### System
- `worker.heartbeat` - Heartbeat del worker (health check)
- `error.occurred` - Error general

---

## 🎯 Schema de Evento

```json
{
  "event_id": "evt_a1b2c3d4-1234-5678-90ab-cdef12345678",
  "tracking_id": "track_1360_20260809143052",
  "action_id": "act_pr_created_20260809143215",
  "event_type": "pr.created",
  "timestamp": "2026-08-09T14:32:15+00:00",
  "issue_number": 1360,
  "pr_number": 1450,
  "status": "completed",
  "stage": "pr_management",
  "metadata": {
    "worker_version": "v2.5.0",
    "repository": "os-santiago/homedir",
    "pr_url": "https://github.com/os-santiago/homedir/pull/1450",
    "files_changed": 3,
    "lines_added": 45,
    "lines_removed": 12
  }
}
```

### Campos Requeridos

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `event_id` | string | Identificador único del evento |
| `tracking_id` | string | ID de seguimiento del issue |
| `action_id` | string | ID de la acción específica |
| `event_type` | enum | Tipo de evento (ver tipos arriba) |
| `timestamp` | ISO-8601 | Timestamp con timezone |
| `issue_number` | integer | Número del issue de GitHub |
| `status` | enum | pending, in_progress, completed, failed, skipped |
| `stage` | enum | Etapa del pipeline |
| `metadata` | object | Metadatos adicionales |

### Campos Opcionales

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `pr_number` | integer | Número de PR (si aplica) |
| `parent_event_id` | string | ID del evento padre (causalidad) |
| `correlation_id` | string | ID para correlacionar entre sistemas |

---

## 🔧 Uso del Event Emitter

### Inicialización

```bash
# En el worker script
source "${PLATFORM_DIR}/scripts/event-emitter.sh"
init_event_system
```

### Emitir Eventos

```bash
# Issue detectado
emit_issue_detected "$issue_number" "$(jq -n --arg title "$TITLE" '{title: $title}')"

# Claim issue
emit_issue_claimed "$issue_number"

# Admission review
emit_admission_started "$issue_number"
emit_admission_completed "$issue_number" "ACCEPT" "Meets all criteria"

# Implementation
START_TIME=$(date +%s%3N)
emit_implementation_started "$issue_number"

# ... SCC execution ...

END_TIME=$(date +%s%3N)
DURATION=$((END_TIME - START_TIME))
FILES_CHANGED=$(git diff --name-only | wc -l)
emit_implementation_completed "$issue_number" "$DURATION" "$FILES_CHANGED"

# PR created
emit_pr_created "$issue_number" "$PR_NUMBER" "$PR_URL"

# CI check failed
emit_ci_check_failed "$issue_number" "$PR_NUMBER" "test-suite" "3 tests failed"

# Error
emit_error "$issue_number" "SCC execution timeout"

# Heartbeat
emit_heartbeat
```

### Queries

```bash
# Get tracking ID para un issue
TRACKING_ID=$(get_tracking_id_for_issue "$issue_number")

# Get todos los eventos de un tracking ID
get_events_by_tracking_id "$TRACKING_ID"

# Get últimos 100 eventos
get_latest_events 100

# Get eventos de una etapa
get_events_by_stage "implementation" 50
```

---

## 🌐 API REST

### Base URL
```
http://vps:8081/api/sdlc/events
```

### Endpoints

#### GET /track/{trackingId}
Obtiene todos los eventos para un tracking ID.

**Response**:
```json
[
  {
    "event_id": "evt_...",
    "tracking_id": "track_1360_...",
    "event_type": "issue.detected",
    "timestamp": "2026-08-09T14:30:00Z",
    "status": "completed",
    ...
  },
  ...
]
```

#### GET /issue/{issueNumber}
Obtiene eventos para un issue específico.

**Response**:
```json
{
  "issue_number": 1360,
  "tracking_id": "track_1360_...",
  "events": [...]
}
```

#### GET /latest?limit=100
Obtiene los últimos N eventos.

**Query Params**:
- `limit` (default: 100) - Cantidad de eventos

#### GET /stage/{stage}?limit=100
Obtiene eventos de una etapa específica.

**Stages**: `detection`, `admission`, `implementation`, `pr_management`, `ci_checks`, `remediation`, `deployment`

#### GET /timeline/{issueNumber}
Obtiene timeline formateado para visualización.

**Response**:
```json
{
  "issue_number": 1360,
  "tracking_id": "track_1360_...",
  "total_events": 15,
  "started_at": "2026-08-09T14:30:00Z",
  "last_event_at": "2026-08-09T14:48:00Z",
  "total_duration_ms": 1080000,
  "stages": [
    {
      "stage": "detection",
      "event_count": 2,
      "started_at": "2026-08-09T14:30:00Z",
      "completed_at": "2026-08-09T14:30:15Z",
      "duration_ms": 15000,
      "events": [...]
    },
    ...
  ]
}
```

#### GET /stats
Obtiene estadísticas globales.

**Response**:
```json
{
  "total_events": 1523,
  "by_type": {
    "issue.detected": 45,
    "pr.created": 42,
    "pr.merged": 38,
    ...
  },
  "by_stage": {
    "detection": 90,
    "admission": 88,
    ...
  },
  "by_status": {
    "completed": 1400,
    "failed": 23,
    "in_progress": 5
  },
  "error_count": 23
}
```

#### GET /active
Obtiene issues actualmente en el pipeline.

**Response**:
```json
[
  {
    "issue_number": 1360,
    "tracking_id": "track_1360_...",
    "current_stage": "implementation",
    "last_event_type": "implementation.started",
    "last_event_time": "2026-08-09T14:35:00Z",
    "event_count": 8
  },
  ...
]
```

---

## 🎨 Dashboard Web

### URL
```
http://vps:8081/sdlc/events/
```

### Features

#### 1. Pipeline Visual
```
┌─────────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┐
│Detection│Admission│Implement│  PR Mgmt│CI Checks│Remediate│ Deploy  │
│    ✓    │    ✓    │    ▶    │    ○    │    ○    │    ○    │    ○    │
└─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┘
```
- ✓ Verde = Completado
- ▶ Amarillo = En progreso
- ○ Gris = Pendiente

#### 2. Timeline de Eventos
Muestra cronológicamente todos los eventos con:
- Tipo de evento
- Timestamp relativo
- Estado (badges de color)
- Metadata relevante
- IDs de trazabilidad

#### 3. Issues Activos
Grid de cards mostrando:
- Número de issue
- Etapa actual
- Última actividad

#### 4. Estadísticas
- Total de eventos
- Conteo de errores
- Issues activos

#### 5. Búsqueda
Input para ingresar número de issue y ver su timeline específico.

#### 6. Auto-Refresh
Toggle para habilitar/deshabilitar refresh automático cada 15 segundos.

---

## 📂 Estructura de Archivos

```
/var/lib/homedir-sdlc/events/
├── all-events.jsonl              # Stream completo (append-only)
├── tracking-state.json           # Mapeo issue → tracking_id
├── detection/
│   ├── track_1360_*.jsonl
│   └── track_1361_*.jsonl
├── admission/
│   └── track_1360_*.jsonl
├── implementation/
│   └── track_1360_*.jsonl
├── pr/
│   └── track_1360_*.jsonl
├── ci/
│   └── track_1360_*.jsonl
├── remediation/
├── deployment/
├── errors/
└── heartbeat/
```

Cada issue tiene sus propios archivos por etapa, facilitando:
- **Query rápido** por etapa específica
- **Aislamiento** de eventos por issue
- **Append-only** para audit trail
- **Compresión** o archivado por issue completado

---

## 🔍 Casos de Uso

### 1. Debugging: ¿Por qué falló este issue?

```bash
# Via API
curl http://vps:8081/api/sdlc/events/issue/1360 | jq '.events[] | select(.status=="failed")'

# Via dashboard
# Buscar issue #1360
# Ver eventos con badge rojo
# Expandir metadata para ver error_message
```

### 2. Métricas: ¿Cuánto demora cada etapa?

```bash
curl http://vps:8081/api/sdlc/events/timeline/1360 | jq '.stages[] | {stage, duration_ms}'
```

### 3. Monitoring: ¿Qué issues están trabados?

```bash
curl http://vps:8081/api/sdlc/events/active | jq '.[] | select(.event_count > 20)'
```

### 4. Audit: ¿Quién/cuándo se hizo X?

```bash
# Buscar evento específico
jq 'select(.event_type=="pr.merged" and .issue_number==1360)' \
  /var/lib/homedir-sdlc/events/all-events.jsonl
```

### 5. Analytics: ¿Cuál es la tasa de éxito?

```bash
curl http://vps:8081/api/sdlc/events/stats | jq '
  (.by_type."deployment.completed" / .by_type."issue.detected" * 100)
'
```

---

## 🚀 Deployment

### 1. Integrar en Worker Actual

```bash
# Editar platform/scripts/homedir-sdlc-worker.sh
# Agregar source del event-emitter
source "${PLATFORM_DIR}/scripts/event-emitter.sh"
init_event_system

# Agregar calls a emit_* según integrate-events-to-worker.sh
```

### 2. Deploy Dashboard

El dashboard Quarkus incluye:
- `EventApiResource.java` - REST API
- `EventQueryService.java` - Query service
- `/sdlc/events/index.html` - Frontend
- `/sdlc/events/events-dashboard.js` - Logic

```bash
# Build
cd dashboard/quarkus-app
./mvnw clean package

# Deploy
# El dashboard corre en puerto 8081
# Acceder a http://vps:8081/sdlc/events/
```

### 3. Verificar

```bash
# Emitir evento de prueba
emit_heartbeat

# Ver en API
curl http://localhost:8081/api/sdlc/events/latest?limit=1

# Ver en dashboard
# http://localhost:8081/sdlc/events/
```

---

## 📊 Métricas y KPIs

El sistema de eventos permite medir:

### Tiempo por Etapa
- Detection → Admission: < 30s
- Admission → Implementation: < 1min
- Implementation → PR Created: 5-10min
- PR Created → Merged: Variable
- **Total E2E**: 16-20min

### Tasas de Éxito
- Admission acceptance rate: ~90%
- Implementation success rate: ~95%
- CI pass rate (first attempt): ~85%
- PR merge rate: ~99%

### Errores
- Error rate by stage
- Most common error types
- Mean time to recovery (MTTR)

### Throughput
- Issues processed per hour
- Average concurrency
- Queue depth by stage

---

## 🔐 Consideraciones de Seguridad

### Datos Sensibles en Metadata

⚠️ **NO incluir** en metadata:
- Tokens o API keys
- Contraseñas
- Datos personales (PII)
- Secrets de ningún tipo

✅ **SÍ incluir**:
- URLs públicas
- Nombres de archivos
- Commit SHAs
- Durations, counts, sizes

### Retención

- **all-events.jsonl**: Rotar cada 30 días (gzip y archivar)
- **Por etapa**: Limpiar issues completados después de 7 días
- **tracking-state.json**: Limpiar issues cerrados después de 30 días

### Audit Trail

Los eventos son **inmutables** (append-only). Para corregir:
- Emitir nuevo evento con corrección
- Mantener referencia al evento original en `parent_event_id`

---

## 🧪 Testing

### Unit Tests

```bash
# Test event emission
./platform/scripts/event-emitter.sh
init_event_system
EVENT_ID=$(emit_issue_detected 999 '{"test": true}')
echo "Event ID: $EVENT_ID"

# Verify in queue
cat /var/lib/homedir-sdlc/events/detection/track_999_*.jsonl
```

### Integration Tests

```bash
# Full cycle test
emit_issue_detected 999
emit_issue_claimed 999
emit_admission_started 999
emit_admission_completed 999 "ACCEPT" "Test approved"
emit_implementation_started 999

# Query via API
curl http://localhost:8081/api/sdlc/events/issue/999 | jq '.events | length'
# Should return 5
```

---

## 📚 Referencias

- **Schema**: `platform/config/event-schema.json`
- **Emitter**: `platform/scripts/event-emitter.sh`
- **Integration Guide**: `platform/scripts/integrate-events-to-worker.sh`
- **API**: `dashboard/.../EventApiResource.java`
- **Query Service**: `dashboard/.../EventQueryService.java`
- **Frontend**: `dashboard/.../resources/sdlc/events/`

---

**Versión**: 1.0.0  
**Fecha**: 2026-08-09  
**Autor**: AI-SDLC Team
