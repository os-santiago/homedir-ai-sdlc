# Changelog

All notable changes to AI-SDLC Events Service will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-08-09

### Added - Event Bus Integration
- Event bus publisher (`EventBusPublisher`)
- Event message DTO for serialization (`EventMessage`)
- NATS reactive messaging integration
- Kafka alternative configuration (commented)
- Async fire-and-forget event publishing to message broker
- Integration with EventPublisher (non-blocking)
- Example external consumer (`EventBusConsumer`)
- Event bus feature flag (`eventbus.enabled`)
- NATS configuration profile (`application-eventbus.properties`)
- Docker Compose with NATS message broker
- Kubernetes NATS StatefulSet (3 replicas for HA)
- Event replay capability from event store
- Queue groups for consumer load balancing

### Changed
- EventPublisher now publishes to event bus if enabled
- Version bumped to 2.0.0
- Event bus failures don't fail transactions (fire-and-forget)

### Dependencies
- Added `quarkus-messaging-nats` for NATS integration
- SmallRye Reactive Messaging connector

### Features
- Horizontal scaling with message broker
- External event consumers
- Real-time analytics pipelines
- Webhook integrations
- Audit trail streaming

## [1.0.0] - 2026-08-09

### Added - Production Ready
- Custom Micrometer metrics (`EventMetrics`)
- Event publish counters by type/stage/status
- Projection creation metrics
- SSE connection/disconnection tracking
- Query duration timers
- Advanced health checks (`DatabaseHealthCheck`, `ProjectionHealthCheck`)
- Database connectivity validation
- Projection sync lag monitoring
- Graceful startup service with materialized view refresh
- Graceful shutdown service with 2s grace period
- Production configuration profile (`application-prod.properties`)
- Environment variable configuration
- JSON logging for production
- CORS domain restriction
- Swagger UI disabled in prod mode
- Kubernetes deployment manifests (Deployment, Service, Ingress)
- Database secret template
- Multi-stage Dockerfile for optimized images
- Production docker-compose configuration
- Comprehensive deployment guide
- Health check integration tests (4 tests)

### Changed
- Version bumped to 1.0.0
- Application version updated in properties
- Metrics integrated into EventPublisher
- Connection pool settings optimized for production

### Security
- Non-root container user (UID 1000)
- Secrets externalized to Kubernetes Secrets
- CORS restricted to specific domains
- Resource limits enforced
- Graceful shutdown timeout (30s)

## [0.5.0] - 2026-08-09

### Added - Dashboard with SSE
- Server-Sent Events endpoints (`EventStreamResource`)
- Real-time event streaming (5s interval)
- Active issues stream (10s interval)
- Stage statistics stream (30s interval)
- Combined dashboard snapshot stream (15s interval)
- Dashboard SPA (HTML + CSS + JavaScript)
- Auto-reconnecting SSE client
- Dark theme UI
- Connection status indicator
- Real-time metrics visualization
- Root redirect to dashboard
- SSE endpoint tests (6 tests)

## [0.4.0] - 2026-08-09

### Added - REST API
- Public query endpoints (`EventsResource`)
- Recent events endpoint with pagination
- Issue timeline endpoint
- Events by stage filtering
- Failed events endpoint
- Active issues endpoint
- Stage statistics endpoint
- Admission decisions summary
- Error rate by stage
- Issue throughput metrics
- Health resource with status/ready/live probes
- OpenAPI documentation
- Limit capping (max 500 results)
- API integration tests (13 tests)

## [0.3.0] - 2026-08-09

### Added - Projections & Read Models
- CQRS read model (`EventProjection`)
- Denormalized event projections table
- Stage statistics aggregation table
- Materialized views (issue_timeline, active_issues)
- Projection updater service
- Event query service with optimized queries
- Projection refresh scheduler (every 5 minutes)
- Metadata extraction to columns
- Timeline queries
- Rebuild projection capability
- Database migration V0.3.0
- Projection and query tests (11 tests)

## [0.2.0] - 2026-08-09

### Added - Event Publisher
- Tracking service for ID generation
- Event publisher with transactional management
- Internal events REST API for worker integration
- Specific endpoints per event type
- Generic publish endpoint
- PublishEventRequest DTO with validation
- Automatic tracking state updates
- Error counting
- PR number tracking
- Event publisher tests (6 tests)

## [0.1.0] - 2026-08-09

### Added - Event Store Foundation
- PostgreSQL database schema
- Event store table (ai_sdlc_events)
- Tracking state table
- AISDLCEvent entity with Builder pattern
- TrackingState entity
- EventStage and EventStatus enums
- Event repository with Reactive Panache
- Tracking state repository
- Flyway migration V0.1.0
- Docker Compose for local development
- Repository integration tests (6 tests)
- Initial documentation

---

**Total Releases**: 7 (0.1.0 → 2.0.0)  
**Production Ready**: ✅ YES  
**Event Bus**: ✅ Integrated (NATS/Kafka)  
**Roadmap**: 🎉 COMPLETADO
