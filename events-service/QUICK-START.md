# AI-SDLC Events Service - Quick Start Guide

## Opción 1: Instalación Local con PostgreSQL (Recomendado)

### Prerequisitos
- Java 21+
- Maven 3.9+
- PostgreSQL 16+ corriendo localmente
- Podman/Docker (opcional)

### Paso 1: Configurar PostgreSQL

#### Opción A: Con Podman/Docker
```powershell
# En PowerShell (si podman está instalado)
cd D:\git\homedir-ai-sdlc\events-service
podman compose up -d

# Verificar
podman ps
```

#### Opción B: PostgreSQL Local
```sql
-- Conectar a PostgreSQL y crear database
CREATE DATABASE aisdlc;
CREATE USER aisdlc WITH PASSWORD 'aisdlc';
GRANT ALL PRIVILEGES ON DATABASE aisdlc TO aisdlc;
```

### Paso 2: Iniciar Aplicación

```bash
cd /d/git/homedir-ai-sdlc/events-service

# Compilar (opcional)
./mvnw clean compile

# Iniciar en modo desarrollo
./mvnw quarkus:dev
```

### Paso 3: Acceder al Dashboard

Abrir navegador en:
- **Dashboard**: http://localhost:8080/dashboard/
- **API Docs**: http://localhost:8080/q/swagger-ui
- **Health**: http://localhost:8080/api/health/status
- **Metrics**: http://localhost:8080/q/metrics

### Paso 4: Publicar Evento de Prueba

```bash
# Publicar evento
curl -X POST http://localhost:8080/internal/events/issue-detected \
  -H "Content-Type: application/json" \
  -d '{
    "issueNumber": 1000,
    "metadata": {
      "title": "Test Issue",
      "labels": ["bug", "high-priority"]
    }
  }'
```

**Respuesta esperada**:
```json
{
  "event_id": "uuid...",
  "tracking_id": "track_1000_...",
  "event_type": "issue.detected",
  "issue_number": 1000,
  "status": "COMPLETED"
}
```

### Paso 5: Verificar en Dashboard

1. Ir a http://localhost:8080/dashboard/
2. Ver en "Recent Events" el evento publicado
3. Ver en "Active Issues" el issue #1000
4. Ver en "Stage Statistics" el incremento en DETECTION

---

## Opción 2: Demo sin Base de Datos (Solo Visualización)

Si no tienes PostgreSQL, puedes ver el dashboard estático:

```bash
cd /d/git/homedir-ai-sdlc/events-service

# Abrir dashboard HTML directamente
explorer.exe src/main/resources/META-INF/resources/dashboard/index.html
```

**Nota**: Dashboard mostrará "Disconnected" sin backend.

---

## Opción 3: Instalación con Event Bus (NATS)

### Prerequisitos Adicionales
- Podman/Docker instalado

### Paso 1: Iniciar Stack Completo

```powershell
cd D:\git\homedir-ai-sdlc\events-service\deployment
podman compose -f docker-compose.eventbus.yml up -d
```

Esto inicia:
- PostgreSQL (puerto 5432)
- NATS (puertos 4222, 8222)
- AI-SDLC Events Service (puerto 8080)
- Consumer Example

### Paso 2: Verificar Servicios

```bash
# Ver contenedores
podman ps

# Logs del servicio
podman logs -f ai-sdlc-events-eventbus

# Logs del consumer
podman logs -f ai-sdlc-consumer-example
```

### Paso 3: Monitorear NATS

- **NATS Monitoring**: http://localhost:8222

### Paso 4: Publicar Evento y Ver Streaming

```bash
# Terminal 1: Subscribir a NATS
podman exec -it ai-sdlc-nats nats sub ai-sdlc.events

# Terminal 2: Publicar evento
curl -X POST http://localhost:8080/internal/events/issue-detected \
  -H "Content-Type: application/json" \
  -d '{"issueNumber": 2000, "metadata": {"title": "Event Bus Test"}}'
```

**Resultado**: Verás el evento en Terminal 1 (NATS subscriber)

---

## Verificación de Instalación

### 1. Health Checks

```bash
# Liveness
curl http://localhost:8080/api/health/live

# Readiness
curl http://localhost:8080/api/health/ready

# Full status
curl http://localhost:8080/api/health/status | jq
```

**Respuesta esperada**: `"status": "UP"`

### 2. Recent Events

```bash
curl http://localhost:8080/api/events/recent?limit=5 | jq
```

### 3. Stage Statistics

```bash
curl http://localhost:8080/api/events/statistics/stages | jq
```

### 4. SSE Stream (Server-Sent Events)

```bash
# Ver stream en tiempo real
curl -N http://localhost:8080/api/stream/dashboard
```

**Ctrl+C para detener**

---

## Troubleshooting

### Error: Connection Refused

**Causa**: PostgreSQL no está corriendo

**Solución**:
```bash
# Verificar PostgreSQL
podman ps | grep postgres

# Si no está corriendo
cd /d/git/homedir-ai-sdlc/events-service
podman compose up -d
```

### Error: Database "aisdlc" does not exist

**Solución**:
```sql
-- Conectar a PostgreSQL
psql -U postgres -h localhost

-- Crear database
CREATE DATABASE aisdlc;
CREATE USER aisdlc WITH PASSWORD 'aisdlc';
GRANT ALL PRIVILEGES ON DATABASE aisdlc TO aisdlc;
```

### Error: Port 8080 already in use

**Solución**: Cambiar puerto
```bash
./mvnw quarkus:dev -Dquarkus.http.port=8081
```

Acceder en http://localhost:8081

### Dashboard muestra "Disconnected"

**Causa**: Backend no está corriendo o puerto incorrecto

**Solución**:
1. Verificar que Quarkus esté corriendo: `curl http://localhost:8080/api/health/live`
2. Ver logs: `./mvnw quarkus:dev` (ver output en consola)

---

## Flujo de Prueba Completo

### Escenario: Simulación de Pipeline AI-SDLC

```bash
# 1. Issue detectado
curl -X POST http://localhost:8080/internal/events/issue-detected \
  -H "Content-Type: application/json" \
  -d '{"issueNumber": 5000, "metadata": {"title": "Fix login bug"}}'

# 2. Issue claimed
curl -X POST http://localhost:8080/internal/events/issue-claimed \
  -H "Content-Type: application/json" \
  -d '{"issueNumber": 5000, "metadata": {}}'

# 3. Admission started
curl -X POST http://localhost:8080/internal/events/admission-started \
  -H "Content-Type: application/json" \
  -d '{"issueNumber": 5000, "metadata": {}}'

# 4. Admission completed
curl -X POST http://localhost:8080/internal/events/admission-completed \
  -H "Content-Type: application/json" \
  -d '{
    "issueNumber": 5000,
    "metadata": {
      "decision": "ACCEPT",
      "reason": "Valid bug report with reproduction steps"
    }
  }'

# 5. Implementation started
curl -X POST http://localhost:8080/internal/events/implementation-started \
  -H "Content-Type: application/json" \
  -d '{"issueNumber": 5000, "metadata": {}}'

# Esperar 3 segundos (simular trabajo)
sleep 3

# 6. Implementation completed
curl -X POST http://localhost:8080/internal/events/implementation-completed \
  -H "Content-Type: application/json" \
  -d '{
    "issueNumber": 5000,
    "metadata": {
      "duration_ms": 3000,
      "files_changed": 2
    }
  }'

# 7. PR created
curl -X POST http://localhost:8080/internal/events/pr-created \
  -H "Content-Type: application/json" \
  -d '{
    "issueNumber": 5000,
    "prNumber": 1234,
    "metadata": {
      "pr_url": "https://github.com/org/repo/pull/1234"
    }
  }'

# 8. Ver timeline completo
curl http://localhost:8080/api/events/timeline/5000 | jq
```

### Verificar en Dashboard

1. Ir a http://localhost:8080/dashboard/
2. Ver timeline completo de issue #5000
3. Ver métricas actualizadas en Stage Statistics
4. Ver issue #5000 en Recent Events

---

## Detener Servicios

### Opción 1: Quarkus Dev Mode
```
Ctrl + C en la terminal donde corre ./mvnw quarkus:dev
```

### Opción 2: Docker Compose
```bash
cd /d/git/homedir-ai-sdlc/events-service
podman compose down

# Con Event Bus
cd /d/git/homedir-ai-sdlc/events-service/deployment
podman compose -f docker-compose.eventbus.yml down
```

---

## Próximos Pasos

1. **Explorar API**: http://localhost:8080/q/swagger-ui
2. **Ver Métricas**: http://localhost:8080/q/metrics
3. **Revisar Logs**: Ver salida de `./mvnw quarkus:dev`
4. **Deployment**: Ver `deployment/DEPLOYMENT.md`
5. **Event Bus**: Ver `RELEASE-2.0-COMPLETE.md`

---

**Versión**: 2.0.0  
**Status**: Production Ready  
**Soporte**: Ver README.md para documentación completa
