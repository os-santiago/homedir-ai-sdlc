# AI-SDLC Events Service - Demo sin PostgreSQL

**Fecha**: 2026-08-09  
**Situación**: No hay Docker/Podman instalado para PostgreSQL  
**Solución**: Demo del dashboard estático + instrucciones para instalación futura

---

## Problema Encontrado

Al intentar ejecutar la instalación local:

```bash
podman compose up -d
# Error: podman no está instalado o no en PATH

docker compose up -d  
# Error: docker no está instalado
```

**Root cause**: No hay runtime de contenedores (Docker/Podman) disponible en el sistema.

---

## Demo Disponible Ahora

### Opción 1: Dashboard Estático (Sin Backend)

El dashboard HTML puede verse sin backend:

```bash
# Abrir en navegador
explorer.exe D:\git\homedir-ai-sdlc\events-service\src\main\resources\META-INF\resources\dashboard\index.html
```

**Qué verás**:
- ✅ UI completa del dashboard
- ✅ Layout responsive
- ✅ Dark theme
- ✅ Estructura de secciones (Stage Stats, Active Issues, Recent Events, Metrics)
- ❌ Estado: "Disconnected" (sin datos reales)
- ❌ No hay conexión SSE al backend

**Propósito**: Ver el diseño y estructura del dashboard.

### Opción 2: Revisar Código del Dashboard

**Frontend** (JavaScript):
```bash
cat src/main/resources/META-INF/resources/dashboard/app.js
```

**Componentes principales**:
- `DashboardApp` class
- SSE client con auto-reconnect
- `formatTimestamp()`, `formatDuration()` helpers
- `updateStageStatistics()`, `updateActiveIssues()`, etc.

**Estilos** (CSS):
```bash
cat src/main/resources/META-INF/resources/dashboard/styles.css
```

**Características**:
- Dark theme con CSS variables
- Responsive grid layout
- Connection status indicator
- Card-based design

---

## Instalación Real - Requisitos Previos

Para ejecutar el sistema completo necesitas:

### 1. Instalar Docker Desktop (Recomendado)

**Windows**:
```powershell
# Descargar desde:
https://www.docker.com/products/docker-desktop/

# O con winget:
winget install Docker.DockerDesktop
```

**Después de instalar**:
1. Reiniciar sistema
2. Abrir Docker Desktop
3. Esperar que inicie el daemon

### 2. Alternativa: Instalar Podman

```powershell
# Con winget:
winget install RedHat.Podman

# Después de instalar, reiniciar PowerShell
```

---

## Pasos de Instalación (Una vez tengas Docker)

### Paso 1: Iniciar PostgreSQL

```powershell
cd D:\git\homedir-ai-sdlc\events-service

# Con Docker:
docker compose up -d

# Con Podman:
podman compose up -d
```

**Verificar**:
```powershell
docker ps
# Deberías ver: ai-sdlc-postgres running
```

### Paso 2: Iniciar Aplicación Quarkus

```bash
cd /d/git/homedir-ai-sdlc/events-service

# Iniciar en modo desarrollo
./mvnw quarkus:dev
```

**Esperar mensaje**:
```
Listening on: http://localhost:8080
```

### Paso 3: Acceder al Dashboard

Abrir en navegador:
- **Dashboard**: http://localhost:8080/dashboard/
- **API Docs**: http://localhost:8080/q/swagger-ui
- **Health**: http://localhost:8080/api/health/status
- **Metrics**: http://localhost:8080/q/metrics

### Paso 4: Publicar Evento de Prueba

```bash
# En otra terminal
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

Ir a http://localhost:8080/dashboard/ y ver:
1. **Connection Status**: Connected (verde)
2. **Stage Statistics**: DETECTION = 1
3. **Active Issues**: Issue #1000 listado
4. **Recent Events**: Evento "issue.detected" visible
5. **SSE stream**: Auto-updating cada 15s

---

## Demo Completo - Flujo de Prueba

Una vez tengas PostgreSQL corriendo, ejecuta este flujo:

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
      "reason": "Valid bug report"
    }
  }'

# 5. Implementation started
curl -X POST http://localhost:8080/internal/events/implementation-started \
  -H "Content-Type: application/json" \
  -d '{"issueNumber": 5000, "metadata": {}}'

# Esperar 3 segundos
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

**En el dashboard verás**:
- Issue #5000 moviéndose por los stages
- Estadísticas actualizándose en tiempo real
- Timeline completo del issue
- Métricas de duración por stage

---

## Alternativa 3: PostgreSQL Local (Sin Docker)

Si no quieres instalar Docker, puedes instalar PostgreSQL localmente:

### Windows con Chocolatey:
```powershell
choco install postgresql16
```

### Windows Manual:
1. Descargar desde: https://www.postgresql.org/download/windows/
2. Instalar PostgreSQL 16
3. Durante instalación, configurar:
   - Puerto: 5432
   - Password: aisdlc

### Crear Database:
```bash
# En PowerShell como administrador
psql -U postgres

# En psql:
CREATE DATABASE aisdlc;
CREATE USER aisdlc WITH PASSWORD 'aisdlc';
GRANT ALL PRIVILEGES ON DATABASE aisdlc TO aisdlc;
\q
```

### Iniciar Aplicación:
```bash
cd /d/git/homedir-ai-sdlc/events-service
./mvnw quarkus:dev
```

---

## Verificación del Sistema

### Health Checks

```bash
# Liveness (¿está vivo?)
curl http://localhost:8080/api/health/live

# Readiness (¿está listo?)
curl http://localhost:8080/api/health/ready

# Status completo
curl http://localhost:8080/api/health/status | jq
```

**Respuesta esperada**:
```json
{
  "status": "UP",
  "database": {
    "status": "UP",
    "event_count": 7,
    "query_time_ms": "<5000"
  },
  "projection_sync": {
    "status": "UP",
    "lag": 0
  }
}
```

### API Endpoints

```bash
# Recent events
curl http://localhost:8080/api/events/recent?limit=5 | jq

# Stage statistics
curl http://localhost:8080/api/events/statistics/stages | jq

# Active issues
curl http://localhost:8080/api/events/active | jq
```

### SSE Stream (Real-time)

```bash
# Conectar al stream de dashboard
curl -N http://localhost:8080/api/stream/dashboard

# Verás updates cada 15 segundos:
data: {"stageStatistics":[...], "activeIssues":[...], "recentEvents":[...]}
```

---

## Troubleshooting

### Error: Connection Refused

**Causa**: PostgreSQL no está corriendo

**Solución**:
```bash
# Docker:
docker compose up -d

# Local:
sudo systemctl start postgresql  # Linux
net start postgresql-x64-16      # Windows
```

### Error: Database "aisdlc" does not exist

**Solución**:
```bash
docker exec -it ai-sdlc-postgres psql -U postgres
CREATE DATABASE aisdlc;
```

### Error: Port 8080 already in use

**Solución**:
```bash
# Cambiar puerto
./mvnw quarkus:dev -Dquarkus.http.port=8081

# Acceder en:
http://localhost:8081/dashboard/
```

### Dashboard muestra "Disconnected"

**Causas posibles**:
1. Quarkus no está corriendo
2. Puerto incorrecto
3. Firewall bloqueando

**Solución**:
```bash
# Verificar que Quarkus esté corriendo
curl http://localhost:8080/api/health/live

# Ver logs
# (en la terminal donde corre ./mvnw quarkus:dev)
```

---

## Estado Actual del Proyecto

### ✅ Completado
- Código compilable (22 files)
- Arquitectura Event Sourcing + CQRS
- REST API completa (28+ endpoints)
- Dashboard con SSE
- Documentación exhaustiva
- Deployment manifests (Docker + K8s)

### ⚠️ Pendiente
- Instalar Docker/Podman para PostgreSQL
- Configurar tests (H2 database)
- Ejecutar demo E2E completo

### 📝 Próximos Pasos
1. Instalar Docker Desktop
2. Ejecutar `docker compose up -d`
3. Ejecutar `./mvnw quarkus:dev`
4. Abrir http://localhost:8080/dashboard/
5. Publicar eventos de prueba
6. Verificar SSE updates en tiempo real

---

## Recursos Disponibles

### Documentación
- `README.md` - Overview completo
- `QUICK-START.md` - Guía de instalación
- `README-FINAL.md` - Resumen de sesión
- `RELEASE-1.0-COMPLETE.md` - Release actual
- `deployment/DEPLOYMENT.md` - Deployment guide

### Código Dashboard
- **HTML**: `src/main/resources/META-INF/resources/dashboard/index.html`
- **JS**: `src/main/resources/META-INF/resources/dashboard/app.js`
- **CSS**: `src/main/resources/META-INF/resources/dashboard/styles.css`

### API Endpoints
Ver Swagger UI una vez corriendo:
- http://localhost:8080/q/swagger-ui

---

**Última actualización**: 2026-08-09 18:10  
**Por**: Claude Sonnet 4.5  
**Status**: Sistema listo, esperando PostgreSQL  
**Acción requerida**: Instalar Docker/Podman o PostgreSQL local
