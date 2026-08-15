# AI-SDLC Implementation Plan v2.0
## Enterprise Event-Driven Architecture

**Enfoque**: Construcción incremental de arquitectura cloud-native  
**Principio**: De menos a más, pero con fundamentos sólidos desde el inicio

---

## 🎯 Estrategia: Evolutionary Architecture

No big-bang. Iteraciones que agregan valor mientras robustecen el sistema.

### Releases

```
v0.1 → Event Schema + PostgreSQL Event Store
v0.2 → Event Publisher (Quarkus worker)
v0.3 → Event Processor + Read Models
v0.4 → REST API con queries optimizados
v0.5 → Dashboard con SSE (Server-Sent Events)
v1.0 → Production-ready con observability completa
v2.0 → Event Bus (NATS/Kafka) + Horizontal scaling
```

Cada release es **deployable y funcional**.

---

## 📦 Release 0.1: Event Store Foundation

**Timeline**: 3-4 días  
**Objetivo**: Event persistence con PostgreSQL

### Deliverables

1. **Database Schema**
```sql
-- Event Store (single source of truth)
CREATE TABLE ai_sdlc_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tracking_id VARCHAR(100) NOT NULL,
    action_id VARCHAR(100) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    issue_number INTEGER NOT NULL,
    pr_number INTEGER,
    status VARCHAR(20) NOT NULL,
    stage VARCHAR(30) NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    parent_event_id UUID REFERENCES ai_sdlc_events(event_id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_events_tracking ON ai_sdlc_events(tracking_id, timestamp DESC);
CREATE INDEX idx_events_issue ON ai_sdlc_events(issue_number);
CREATE INDEX idx_events_timestamp ON ai_sdlc_events(timestamp DESC);
CREATE INDEX idx_events_type_stage ON ai_sdlc_events(event_type, stage);

-- Tracking state (projection)
CREATE TABLE tracking_state (
    issue_number INTEGER PRIMARY KEY,
    tracking_id VARCHAR(100) UNIQUE NOT NULL,
    current_stage VARCHAR(30) NOT NULL,
    status VARCHAR(20) NOT NULL,
    first_event_at TIMESTAMPTZ NOT NULL,
    last_event_at TIMESTAMPTZ NOT NULL,
    pr_number INTEGER,
    event_count INTEGER DEFAULT 0,
    metadata JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

2. **Java Entities (Hibernate Reactive)**

```java
@Entity
@Table(name = "ai_sdlc_events")
public class AISDLCEvent {
    @Id
    @GeneratedValue
    private UUID eventId;
    
    @Column(nullable = false)
    private String trackingId;
    
    @Column(nullable = false)
    private String actionId;
    
    @Column(nullable = false)
    private String eventType;
    
    @Column(nullable = false)
    private Instant timestamp;
    
    @Column(nullable = false)
    private Integer issueNumber;
    
    private Integer prNumber;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private EventStatus status;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private EventStage stage;
    
    @Type(JsonBinaryType.class)
    @Column(columnDefinition = "jsonb")
    private Map<String, Object> metadata;
    
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_event_id")
    private AISDLCEvent parentEvent;
    
    private Instant createdAt;
    
    // Getters, setters, builder
}
```

3. **Repository Pattern**

```java
@ApplicationScoped
public class EventRepository implements PanacheRepositoryBase<AISDLCEvent, UUID> {
    
    public Uni<AISDLCEvent> persist(AISDLCEvent event) {
        return persistAndFlush(event);
    }
    
    public Uni<List<AISDLCEvent>> findByTrackingId(String trackingId) {
        return find("trackingId = ?1 ORDER BY timestamp ASC", trackingId).list();
    }
    
    public Uni<List<AISDLCEvent>> findByIssueNumber(Integer issueNumber) {
        return find("issueNumber = ?1 ORDER BY timestamp DESC", issueNumber).list();
    }
    
    public Uni<List<AISDLCEvent>> findLatest(int limit) {
        return find("ORDER BY timestamp DESC").page(0, limit).list();
    }
}
```

4. **Integration Tests**

```java
@QuarkusTest
public class EventRepositoryTest {
    
    @Inject
    EventRepository repo;
    
    @Test
    @Transactional
    public void testPersistEvent() {
        AISDLCEvent event = AISDLCEvent.builder()
            .trackingId("track_1360_20260809")
            .actionId("act_issue_detected_20260809")
            .eventType("issue.detected")
            .timestamp(Instant.now())
            .issueNumber(1360)
            .status(EventStatus.COMPLETED)
            .stage(EventStage.DETECTION)
            .build();
        
        AISDLCEvent persisted = repo.persist(event).await().indefinitely();
        
        assertNotNull(persisted.getEventId());
        assertEquals("track_1360_20260809", persisted.getTrackingId());
    }
}
```

### Acceptance Criteria

- ✅ PostgreSQL schema deployed
- ✅ Hibernate entities mapeadas
- ✅ CRUD operations funcionando
- ✅ Tests de integración passing
- ✅ Flyway migrations versionadas

---

## 📦 Release 0.2: Event Publisher

**Timeline**: 2-3 días  
**Objetivo**: Worker emite eventos a PostgreSQL directamente

### Deliverables

1. **Event Publisher Service**

```java
@ApplicationScoped
public class EventPublisher {
    
    @Inject
    EventRepository eventRepo;
    
    @Inject
    TrackingStateService trackingService;
    
    @Transactional
    public Uni<AISDLCEvent> publishIssueDetected(int issueNumber, Map<String, Object> metadata) {
        String trackingId = trackingService.getOrCreateTrackingId(issueNumber);
        
        AISDLCEvent event = AISDLCEvent.builder()
            .trackingId(trackingId)
            .actionId(generateActionId("issue_detected"))
            .eventType("issue.detected")
            .timestamp(Instant.now())
            .issueNumber(issueNumber)
            .status(EventStatus.COMPLETED)
            .stage(EventStage.DETECTION)
            .metadata(metadata)
            .build();
        
        return eventRepo.persist(event)
            .chain(e -> trackingService.updateState(e))
            .map(v -> event);
    }
    
    // Similar methods for other event types
}
```

2. **Worker Integration**

```bash
# Worker script calls Java service via REST
emit_issue_detected() {
  local issue_number="$1"
  local metadata="$2"
  
  curl -X POST http://localhost:8080/internal/events/publish \
    -H "Content-Type: application/json" \
    -d "{
      \"event_type\": \"issue.detected\",
      \"issue_number\": $issue_number,
      \"metadata\": $metadata
    }"
}
```

O mejor, worker en Java desde el inicio:

```java
@ApplicationScoped
public class WorkerService {
    
    @Inject
    EventPublisher eventPublisher;
    
    @Inject
    GitHubClient githubClient;
    
    public Uni<Void> reconcile() {
        return githubClient.findReadyToImplementIssues()
            .onItem().transformToMulti(issues -> Multi.createFrom().iterable(issues))
            .onItem().transformToUniAndMerge(issue -> processIssue(issue))
            .collect().asList()
            .replaceWithVoid();
    }
    
    private Uni<Void> processIssue(Issue issue) {
        return eventPublisher.publishIssueDetected(issue.getNumber(), issue.getMetadata())
            .chain(() -> claimIssue(issue))
            .chain(() -> runAdmission(issue))
            .chain(() -> implement(issue))
            // etc.
            .replaceWithVoid();
    }
}
```

### Acceptance Criteria

- ✅ Worker emite eventos a PostgreSQL
- ✅ Tracking IDs generados consistentemente
- ✅ Transacciones ACID garantizadas
- ✅ Latencia < 50ms por evento
- ✅ Error handling con retry

---

## 📦 Release 0.3: Read Models + Projections

**Timeline**: 3-4 días  
**Objetivo**: Queries optimizados con CQRS

### Deliverables

1. **Projection Updater**

```java
@ApplicationScoped
public class ProjectionUpdater {
    
    @Inject
    TrackingStateRepository trackingRepo;
    
    @ConsumeEvent("event-persisted") // CDI event
    @Transactional
    public Uni<Void> onEventPersisted(AISDLCEvent event) {
        return trackingRepo.findByIssueNumber(event.getIssueNumber())
            .onItem().ifNull().continueWith(() -> createTracking(event))
            .chain(tracking -> updateTracking(tracking, event))
            .replaceWithVoid();
    }
    
    private TrackingState updateTracking(TrackingState tracking, AISDLCEvent event) {
        tracking.setCurrentStage(event.getStage());
        tracking.setStatus(event.getStatus());
        tracking.setLastEventAt(event.getTimestamp());
        tracking.setEventCount(tracking.getEventCount() + 1);
        
        if (event.getPrNumber() != null) {
            tracking.setPrNumber(event.getPrNumber());
        }
        
        return tracking;
    }
}
```

2. **Query Service**

```java
@ApplicationScoped
public class EventQueryService {
    
    @Inject
    EventRepository eventRepo;
    
    @Inject
    TrackingStateRepository trackingRepo;
    
    public Uni<Timeline> getTimeline(int issueNumber) {
        return Uni.combine().all()
            .unis(
                eventRepo.findByIssueNumber(issueNumber),
                trackingRepo.findByIssueNumber(issueNumber)
            )
            .asTuple()
            .map(tuple -> buildTimeline(tuple.getItem1(), tuple.getItem2()));
    }
    
    public Uni<Statistics> getStatistics() {
        return eventRepo.find(
            "SELECT " +
            "  COUNT(*) as totalEvents, " +
            "  COUNT(DISTINCT issue_number) as totalIssues, " +
            "  COUNT(CASE WHEN status = 'FAILED' THEN 1 END) as errorCount " +
            "FROM AISDLCEvent"
        ).project(Statistics.class).firstResult();
    }
}
```

### Acceptance Criteria

- ✅ Projections actualizan automáticamente
- ✅ Timeline query < 100ms
- ✅ Statistics query < 50ms
- ✅ Eventual consistency garantizada

---

## 📦 Release 0.4: REST API

**Timeline**: 2 días  
**Objetivo**: API pública para consultas

```java
@Path("/api/v1/events")
@Produces(MediaType.APPLICATION_JSON)
public class EventsResource {
    
    @Inject
    EventQueryService queryService;
    
    @GET
    @Path("/timeline/{issueNumber}")
    public Uni<Timeline> getTimeline(@PathParam("issueNumber") int issueNumber) {
        return queryService.getTimeline(issueNumber);
    }
    
    @GET
    @Path("/latest")
    public Uni<List<AISDLCEvent>> getLatest(
        @QueryParam("limit") @DefaultValue("50") int limit
    ) {
        return queryService.getLatestEvents(limit);
    }
    
    @GET
    @Path("/stats")
    public Uni<Statistics> getStats() {
        return queryService.getStatistics();
    }
}
```

### Acceptance Criteria

- ✅ OpenAPI spec generado
- ✅ API versionada (/api/v1/)
- ✅ Rate limiting implementado
- ✅ CORS configurado
- ✅ Docs en Swagger UI

---

## 📦 Release 0.5: Dashboard con SSE

**Timeline**: 3-4 días  
**Objetivo**: UI real-time con Server-Sent Events

```java
@Path("/api/v1/events/stream")
public class EventStreamResource {
    
    @Inject
    @Channel("event-stream")
    Multi<AISDLCEvent> eventStream;
    
    @GET
    @Produces(MediaType.SERVER_SENT_EVENTS)
    public Multi<AISDLCEvent> streamEvents() {
        return eventStream;
    }
}
```

Dashboard consume SSE y actualiza en tiempo real.

---

## 📦 Release 1.0: Production Ready

**Timeline**: 1 semana  
**Objetivo**: Observability + resilience

### Agregados

- ✅ OpenTelemetry tracing
- ✅ Prometheus metrics
- ✅ Grafana dashboards
- ✅ Health checks (/health)
- ✅ Readiness/liveness probes
- ✅ Graceful shutdown
- ✅ Docker multi-stage build
- ✅ Kubernetes manifests
- ✅ CI/CD pipeline

---

## 📦 Release 2.0: Event Bus

**Timeline**: 1-2 semanas  
**Objetivo**: Escalabilidad horizontal

Introduce NATS JetStream:
- Worker publica a NATS
- Event Processor consume de NATS
- PostgreSQL solo para persistence
- Horizontal scaling de procesadores

---

## 🎯 Próximo Paso Inmediato

**Comenzar Release 0.1**:

```bash
cd D:\git\homedir-ai-sdlc

# 1. Setup PostgreSQL (Docker local)
docker run -d \
  --name ai-sdlc-postgres \
  -e POSTGRES_DB=aisdlc \
  -e POSTGRES_USER=aisdlc \
  -e POSTGRES_PASSWORD=aisdlc \
  -p 5432:5432 \
  postgres:16-alpine

# 2. Crear proyecto Quarkus
mvn io.quarkus:quarkus-maven-plugin:3.16.4:create \
  -DprojectGroupId=io.opensourcesantiago \
  -DprojectArtifactId=ai-sdlc-events \
  -Dextensions="resteasy-reactive-jackson,hibernate-reactive-panache,reactive-pg-client,flyway"

# 3. Implementar schema + entities
# 4. Tests de integración
# 5. Deploy local y validar
```

¿Procedemos con Release 0.1?
