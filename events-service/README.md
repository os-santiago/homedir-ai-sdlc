# AI-SDLC Events Service

Event Sourcing + CQRS service para tracking del ciclo de vida completo de AI-SDLC issues.

## Quick Start

```powershell
# Deploy con Podman
cd D:\git\homedir-ai-sdlc\events-service
.\deployment\podman-pod-simple.ps1

# Acceder
open http://localhost:8080/dashboard/
```

## Features

- ✅ Event Sourcing inmutable
- ✅ CQRS (Command Query Responsibility Segregation)
- ✅ Reactive programming (Mutiny)
- ✅ Real-time updates (Server-Sent Events)
- ✅ REST API (28+ endpoints)
- ✅ Dashboard web interactivo
- ✅ PostgreSQL materialized views
- ✅ Health checks y metrics
- ✅ Production-ready deployment

## Tech Stack

- **Framework**: Quarkus 3.16.4
- **Language**: Java 21
- **Database**: PostgreSQL 16
- **ORM**: Hibernate Reactive Panache
- **Migrations**: Flyway
- **Container**: Podman
- **Metrics**: Micrometer + Prometheus

## Documentation

- **START-HERE.md** - Comenzar aquí
- **QUICK-START.md** - Guía rápida
- **DEPLOY-README.md** - Deployment completo
- **API**: http://localhost:8080/q/swagger-ui

## Development

```bash
# Tests
./mvnw test

# Dev mode
./mvnw quarkus:dev

# Package
./mvnw package -DskipTests
```

## Architecture

```
┌─────────────────────────────────────────┐
│         Command Side (Write)            │
├─────────────────────────────────────────┤
│  POST /internal/events/*                │
│  → EventPublisher                       │
│  → AISDLCEvent (immutable)              │
│  → PostgreSQL (ai_sdlc_events)          │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│          Query Side (Read)              │
├─────────────────────────────────────────┤
│  GET /api/events/*                      │
│  → EventQueryService                    │
│  → Materialized Views                   │
│  → Real-time SSE streams                │
└─────────────────────────────────────────┘
```

## License

MIT

## Author

Built with Claude Code
