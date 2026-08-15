# AI-SDLC Enterprise Architecture

**Versión**: 2.0  
**Fecha**: 2026-08-09  
**Tipo**: Cloud-Native Event-Driven Architecture

---

## 🎯 Visión

**AI-SDLC** es un sistema empresarial para orquestar AI agents en pipelines automatizados con governance, transformando agentes inconsistentes manejados por prompts irregulares hacia flujos estandarizados con:

- **Policies & Guardrails** - Reglas consistentes
- **Best Practices** - Patrones probados
- **Hardness** - Robustez empresarial
- **Observability** - Trazabilidad completa

---

## 🏗️ Principios Arquitectónicos

### 1. Event-Driven Architecture
- **Event Bus central** (Kafka, NATS, RabbitMQ)
- **Productores/Consumidores desacoplados**
- **Event Sourcing** para audit trail
- **CQRS** para reads/writes separados

### 2. Cloud Native
- **Microservicios** en containers
- **Stateless** donde sea posible
- **12-Factor App** compliance
- **Kubernetes-ready**

### 3. Resiliencia
- **Retry policies** con exponential backoff
- **Circuit breakers** para dependencias
- **Dead Letter Queues** para eventos fallidos
- **Graceful degradation**

### 4. Observabilidad
- **Distributed tracing** (OpenTelemetry)
- **Structured logging** (JSON)
- **Metrics** (Prometheus)
- **Dashboards** (Grafana)

### 5. Evolucionabilidad
- **API versioning** (v1, v2)
- **Schema evolution** (Avro, Protobuf)
- **Feature flags** para rollout gradual
- **Backward compatibility**

---

## 📐 Arquitectura de Referencia

```
┌─────────────────────────────────────────────────────────────────┐
│                     Ingress / API Gateway                        │
│                   (Kong, Traefik, Envoy)                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
         ▼                               ▼
┌──────────────────┐          ┌──────────────────┐
│  Worker Service  │          │  Dashboard API   │
│   (Quarkus)      │          │   (Quarkus)      │
│  - Reconcile     │          │  - Query Events  │
│  - Execute SCC   │          │  - Metrics       │
│  - Emit Events   │          │  - Timeline      │
└────────┬─────────┘          └────────┬─────────┘
         │ publishes                   │ subscribes
         │                             │
         ▼                             │
┌─────────────────────────────────────┴────────────────────────┐
│                    Event Bus (Kafka/NATS)                     │
│  Topics:                                                      │
│    - ai-sdlc.events.detection                                │
│    - ai-sdlc.events.admission                                │
│    - ai-sdlc.events.implementation                           │
│    - ai-sdlc.events.pr                                       │
│    - ai-sdlc.events.ci                                       │
│    - ai-sdlc.events.deployment                               │
│    - ai-sdlc.events.errors                                   │
└────────────────────────┬──────────────────────────────────────┘
                         │
         ┌───────────────┴────────────────┐
         │                                │
         ▼                                ▼
┌──────────────────┐          ┌──────────────────┐
│ Event Processor  │          │  Event Store     │
│   (Consumer)     │          │  (PostgreSQL)    │
│  - Aggregate     │          │  - Event Log     │
│  - Enrich        │          │  - Projections   │
│  - Transform     │          │  - Snapshots     │
└──────────────────┘          └──────────────────┘
         │                                │
         └────────────────┬───────────────┘
                          │
                          ▼
                 ┌──────────────────┐
                 │  Read Models     │
                 │  (PostgreSQL)    │
                 │  - Timelines     │
                 │  - Statistics    │
                 │  - Active Issues │
                 └──────────────────┘
```

---

## 🔧 Stack Tecnológico

### Backend
- **Quarkus 3.x** - Framework cloud-native Java
- **GraalVM** - Native compilation para startup rápido
- **SmallRye Reactive** - Reactive streams
- **Hibernate Reactive** - ORM asíncrono

### Event Bus
**Opción A - Kafka** (Recomendado para alta escala):
- **Apache Kafka** - Event streaming platform
- **Schema Registry** - Avro schema evolution
- **Kafka Streams** - Stream processing

**Opción B - NATS** (Recomendado para simplicidad):
- **NATS JetStream** - Persistence + streaming
- **NATS KV** - Key-value store
- **Ligero y fácil de operar**

### Database
- **PostgreSQL 16** - RDBMS para eventos y read models
- **TimescaleDB extension** - Time-series optimization
- **Connection pooling** (PgBouncer)

### Observability
- **OpenTelemetry** - Distributed tracing
- **Loki** - Log aggregation
- **Prometheus** - Metrics
- **Grafana** - Visualización

### Deployment
- **Docker** - Containerization
- **Kubernetes** - Orchestration
- **Helm** - Package management
- **ArgoCD** - GitOps

---

## 📊 Event Schema (Avro)

```json
{
  "type": "record",
  "name": "AISDLCEvent",
  "namespace": "io.opensourcesantiago.aisdlc.events",
  "fields": [
    {"name": "event_id", "type": "string"},
    {"name": "tracking_id", "type": "string"},
    {"name": "action_id", "type": "string"},
    {"name": "event_type", "type": "string"},
    {"name": "timestamp", "type": "long", "logicalType": "timestamp-millis"},
    {"name": "issue_number", "type": "int"},
    {"name": "pr_number", "type": ["null", "int"], "default": null},
    {"name": "status", "type": {"type": "enum", "name": "Status", "symbols": ["PENDING", "IN_PROGRESS", "COMPLETED", "FAILED", "SKIPPED"]}},
    {"name": "stage", "type": {"type": "enum", "name": "Stage", "symbols": ["DETECTION", "ADMISSION", "IMPLEMENTATION", "PR_MANAGEMENT", "CI_CHECKS", "REMEDIATION", "DEPLOYMENT"]}},
    {"name": "metadata", "type": {"type": "map", "values": "string"}},
    {"name": "parent_event_id", "type": ["null", "string"], "default": null}
  ]
}
```

---

## 🗄️ Data Model (PostgreSQL)

### Events Table (Event Store)
```sql
CREATE TABLE ai_sdlc_events (
    event_id UUID PRIMARY KEY,
    tracking_id VARCHAR(100) NOT NULL,
    action_id VARCHAR(100) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    issue_number INTEGER NOT NULL,
    pr_number INTEGER,
    status VARCHAR(20) NOT NULL,
    stage VARCHAR(30) NOT NULL,
    metadata JSONB,
    parent_event_id UUID REFERENCES ai_sdlc_events(event_id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_events_tracking_id ON ai_sdlc_events(tracking_id);
CREATE INDEX idx_events_issue_number ON ai_sdlc_events(issue_number);
CREATE INDEX idx_events_timestamp ON ai_sdlc_events(timestamp DESC);
CREATE INDEX idx_events_stage ON ai_sdlc_events(stage);
```

### Tracking State (Read Model)
```sql
CREATE TABLE tracking_state (
    issue_number INTEGER PRIMARY KEY,
    tracking_id VARCHAR(100) UNIQUE NOT NULL,
    current_stage VARCHAR(30) NOT NULL,
    status VARCHAR(20) NOT NULL,
    first_event_at TIMESTAMPTZ NOT NULL,
    last_event_at TIMESTAMPTZ NOT NULL,
    pr_number INTEGER,
    event_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    metadata JSONB,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Timeline Projection (Read Model)
```sql
CREATE TABLE timeline_projections (
    id UUID PRIMARY KEY,
    tracking_id VARCHAR(100) NOT NULL,
    issue_number INTEGER NOT NULL,
    total_events INTEGER,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    total_duration_ms BIGINT,
    stages JSONB, -- Array de stage info con duraciones
    created_at TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (issue_number) REFERENCES tracking_state(issue_number)
);
```

---

## 🔄 Event Flow

### 1. Event Publication (Worker)

```java
@ApplicationScoped
public class EventPublisher {
    
    @Inject
    @Channel("ai-sdlc-events-out")
    Emitter<AISDLCEvent> eventEmitter;
    
    public void publishIssueDetected(int issueNumber, JsonObject metadata) {
        AISDLCEvent event = AISDLCEvent.newBuilder()
            .setEventId(UUID.randomUUID().toString())
            .setTrackingId(generateTrackingId(issueNumber))
            .setActionId(generateActionId("issue_detected"))
            .setEventType("issue.detected")
            .setTimestamp(Instant.now().toEpochMilli())
            .setIssueNumber(issueNumber)
            .setStatus(Status.COMPLETED)
            .setStage(Stage.DETECTION)
            .setMetadata(metadata.getMap())
            .build();
        
        eventEmitter.send(event)
            .whenComplete((success, throwable) -> {
                if (throwable != null) {
                    LOG.error("Failed to publish event", throwable);
                    // Fallback: write to local DLQ
                    writeToDeadLetterQueue(event, throwable);
                }
            });
    }
}
```

### 2. Event Consumption (Processor)

```java
@ApplicationScoped
public class EventProcessor {
    
    @Inject
    EventStore eventStore;
    
    @Inject
    ProjectionUpdater projectionUpdater;
    
    @Incoming("ai-sdlc-events-in")
    @Outgoing("ai-sdlc-events-processed")
    @Retry(maxRetries = 3, delay = 1000)
    @CircuitBreaker(requestVolumeThreshold = 4, failureRatio = 0.5)
    public Uni<AISDLCEvent> processEvent(AISDLCEvent event) {
        return eventStore.persist(event)
            .chain(() -> projectionUpdater.update(event))
            .map(v -> event)
            .onFailure().invoke(throwable -> 
                LOG.error("Failed to process event: " + event.getEventId(), throwable)
            );
    }
}
```

### 3. Projection Update

```java
@ApplicationScoped
public class ProjectionUpdater {
    
    @Inject
    TrackingStateRepository trackingRepo;
    
    @Inject
    TimelineProjectionRepository timelineRepo;
    
    @Transactional
    public Uni<Void> update(AISDLCEvent event) {
        return trackingRepo.findByIssueNumber(event.getIssueNumber())
            .onItem().ifNull().continueWith(() -> createNewTracking(event))
            .chain(tracking -> updateTracking(tracking, event))
            .chain(tracking -> timelineRepo.updateProjection(tracking))
            .replaceWithVoid();
    }
}
```

---

## 🚀 Roadmap de Implementación

### Phase 1: Foundation (Semana 1-2)
**Objetivo**: Infrastructure as Code + Event Bus

- [ ] Setup Kubernetes cluster (Minikube local, GKE/EKS prod)
- [ ] Deploy PostgreSQL con Helm
- [ ] Deploy NATS JetStream
- [ ] Setup monitoring stack (Prometheus + Grafana)
- [ ] CI/CD pipeline (GitHub Actions)

**Entregable**: Infraestructura operativa con observabilidad

---

### Phase 2: Event Store (Semana 3)
**Objetivo**: Sistema de eventos funcional

- [ ] Schema Avro definido y versionado
- [ ] Event Store implementation (PostgreSQL)
- [ ] Event Publisher service (Quarkus)
- [ ] Event Processor service (Quarkus)
- [ ] Tests de integración

**Entregable**: Eventos se publican, persisten y procesan

---

### Phase 3: Worker Integration (Semana 4)
**Objetivo**: Worker emite eventos reales

- [ ] Refactor worker para usar Event Publisher
- [ ] Emission points integrados (10 puntos)
- [ ] Error handling con DLQ
- [ ] Performance testing (1000 eventos/min)

**Entregable**: Worker en producción emitiendo eventos

---

### Phase 4: Read Models (Semana 5)
**Objetivo**: Queries eficientes

- [ ] Tracking State projection
- [ ] Timeline projection
- [ ] Statistics aggregation
- [ ] Read API (REST + GraphQL)

**Entregable**: API consulta eventos en <100ms

---

### Phase 5: Dashboard (Semana 6)
**Objetivo**: Interfaz de usuario

- [ ] Dashboard SPA (React/Vue/Svelte)
- [ ] WebSocket para updates real-time
- [ ] Search y filters avanzados
- [ ] Export reports (PDF, CSV)

**Entregable**: Dashboard production-ready

---

### Phase 6: Advanced Features (Semana 7+)
**Objetivo**: Features empresariales

- [ ] Alerting (PagerDuty, Slack)
- [ ] SLA tracking y reporting
- [ ] ML para anomaly detection
- [ ] Multi-tenancy support

---

## 📏 Métricas de Calidad

### Performance
- **Event ingestion**: >1000 eventos/segundo
- **Query latency**: P95 < 100ms
- **End-to-end latency**: < 1 segundo (publish → query)

### Reliability
- **Uptime**: 99.9%
- **Data durability**: 99.999%
- **Event ordering**: Garantizado por partition key

### Scalability
- **Horizontal scaling**: Worker y processor stateless
- **Partition strategy**: Por issue_number
- **Storage**: TimescaleDB para retention eficiente

---

## 🔐 Seguridad

### Transport
- **TLS/SSL** everywhere
- **mTLS** para service-to-service

### Authentication/Authorization
- **OAuth 2.0** para API
- **RBAC** para permisos granulares
- **API Keys** con rate limiting

### Data
- **Encryption at rest** (PostgreSQL TDE)
- **PII scrubbing** en eventos
- **Audit log** inmutable

---

## 📚 Referencias

### Patterns
- **Event Sourcing**: Martin Fowler
- **CQRS**: Greg Young
- **Microservices**: Sam Newman
- **Cloud Native**: CNCF

### Technologies
- **Quarkus**: https://quarkus.io
- **NATS**: https://nats.io
- **Kafka**: https://kafka.apache.org
- **OpenTelemetry**: https://opentelemetry.io

---

**Esta es la arquitectura real que necesitamos implementar.**

No más HTML standalone, no más file-based queues, no más experimentos.

**Cloud-native, event-driven, production-ready desde día 1.**
