# AI-SDLC Events Service - Podman Pod Deployment

**Fecha**: 2026-08-09  
**Componentes**: PostgreSQL 16 + AI-SDLC Events Service  
**Arquitectura**: Single Pod con 2 contenedores

---

## Arquitectura del Pod

```
┌─────────────────────────────────────────────────────┐
│  Pod: ai-sdlc-events-pod                            │
│  Port: 8080 → 8080                                  │
│                                                     │
│  ┌───────────────────┐    ┌───────────────────┐   │
│  │  PostgreSQL 16    │    │  AI-SDLC Events   │   │
│  │  (alpine)         │◄───┤  Service          │   │
│  │                   │    │  (Quarkus)        │   │
│  │  Port: 5432       │    │  Port: 8080       │   │
│  │  localhost        │    │                   │   │
│  └───────────────────┘    └───────────────────┘   │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Ventajas de usar un Pod**:
- Contenedores comparten localhost (no network bridge)
- PostgreSQL en `localhost:5432` (no IP externa)
- Deployment/teardown atómico
- Gestión simplificada

---

## Opción 1: Script Automatizado (Recomendado)

### PowerShell (Windows)

```powershell
cd D:\git\homedir-ai-sdlc\events-service

# Ejecutar script de setup
.\deployment\podman-pod-setup.ps1
```

### Bash (Linux/WSL/Git Bash)

```bash
cd /d/git/homedir-ai-sdlc/events-service

# Dar permisos de ejecución
chmod +x deployment/podman-pod-setup.sh

# Ejecutar script
./deployment/podman-pod-setup.sh
```

**Qué hace el script**:
1. ✓ Limpia pod existente (si existe)
2. ✓ Crea pod `ai-sdlc-events-pod`
3. ✓ Inicia PostgreSQL container
4. ✓ Espera a que PostgreSQL esté listo
5. ✓ Compila la aplicación (`./mvnw package`)
6. ✓ Construye imagen Podman
7. ✓ Inicia aplicación container
8. ✓ Espera a que la app esté lista
9. ✓ Verifica deployment completo

**Tiempo estimado**: 2-3 minutos (primera vez)

---

## Opción 2: Manual Paso a Paso

### Paso 1: Crear Pod

```bash
podman pod create \
  --name ai-sdlc-events-pod \
  --publish 8080:8080
```

### Paso 2: Iniciar PostgreSQL

```bash
podman run -d \
  --pod ai-sdlc-events-pod \
  --name ai-sdlc-postgres \
  -e POSTGRES_DB=aisdlc \
  -e POSTGRES_USER=aisdlc \
  -e POSTGRES_PASSWORD=aisdlc \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  docker.io/library/postgres:16-alpine
```

### Paso 3: Verificar PostgreSQL

```bash
# Esperar 5 segundos
sleep 5

# Verificar que esté listo
podman exec ai-sdlc-postgres pg_isready -U aisdlc
```

### Paso 4: Compilar Aplicación

```bash
cd /d/git/homedir-ai-sdlc/events-service
./mvnw clean package -DskipTests
```

### Paso 5: Construir Imagen

```bash
podman build -f deployment/docker/Containerfile -t ai-sdlc-events:latest .
```

### Paso 6: Iniciar Aplicación

```bash
podman run -d \
  --pod ai-sdlc-events-pod \
  --name ai-sdlc-app \
  -e QUARKUS_DATASOURCE_REACTIVE_URL=postgresql://localhost:5432/aisdlc \
  -e QUARKUS_DATASOURCE_USERNAME=aisdlc \
  -e QUARKUS_DATASOURCE_PASSWORD=aisdlc \
  -e QUARKUS_DATASOURCE_JDBC_URL=jdbc:postgresql://localhost:5432/aisdlc \
  ai-sdlc-events:latest
```

### Paso 7: Verificar Deployment

```bash
# Ver estado del pod
podman pod ps

# Ver contenedores en el pod
podman ps --filter pod=ai-sdlc-events-pod

# Verificar logs de la app
podman logs ai-sdlc-app

# Verificar health
curl http://localhost:8080/api/health/status | jq
```

---

## Acceso a la Aplicación

Una vez desplegado:

### Dashboard
```
http://localhost:8080/dashboard/
```

### API Swagger
```
http://localhost:8080/q/swagger-ui
```

### Health Checks
```bash
# Liveness
curl http://localhost:8080/api/health/live

# Readiness
curl http://localhost:8080/api/health/ready

# Full status
curl http://localhost:8080/api/health/status | jq
```

### Métricas Prometheus
```
http://localhost:8080/q/metrics
```

---

## Testing del Sistema

### Test 1: Health Check

```bash
curl http://localhost:8080/api/health/status | jq
```

**Respuesta esperada**:
```json
{
  "status": "UP",
  "checks": [
    {
      "name": "Database connectivity",
      "status": "UP",
      "data": {
        "event_count": 0,
        "query_time_ms": "<5000"
      }
    }
  ]
}
```

### Test 2: Publicar Evento

```bash
curl -X POST http://localhost:8080/internal/events/issue-detected \
  -H "Content-Type: application/json" \
  -d '{
    "issueNumber": 1000,
    "metadata": {
      "title": "Test Issue",
      "labels": ["bug", "priority-high"]
    }
  }' | jq
```

**Respuesta esperada**:
```json
{
  "event_id": "a1b2c3d4-...",
  "tracking_id": "track_1000_...",
  "event_type": "issue.detected",
  "issue_number": 1000,
  "status": "COMPLETED",
  "stage": "DETECTION",
  "timestamp": "2026-08-09T18:15:00Z"
}
```

### Test 3: Verificar Evento en API

```bash
# Recent events
curl http://localhost:8080/api/events/recent?limit=5 | jq

# Timeline del issue
curl http://localhost:8080/api/events/timeline/1000 | jq

# Estadísticas por stage
curl http://localhost:8080/api/events/statistics/stages | jq
```

### Test 4: Verificar Dashboard

1. Abrir: http://localhost:8080/dashboard/
2. Verificar connection status: **Connected** (verde)
3. Ver en "Stage Statistics": DETECTION = 1
4. Ver en "Recent Events": evento publicado
5. Ver en "Active Issues": Issue #1000

### Test 5: SSE Stream (Real-time)

```bash
# Conectar al stream
curl -N http://localhost:8080/api/stream/dashboard

# Verás updates cada 15s:
data: {"stageStatistics":[...], "activeIssues":[...], "recentEvents":[...], "metrics":{...}}
```

**Ctrl+C** para detener

---

## Gestión del Pod

### Ver Logs

```bash
# Logs de la aplicación
podman logs -f ai-sdlc-app

# Logs de PostgreSQL
podman logs -f ai-sdlc-postgres

# Logs del pod completo
podman pod logs ai-sdlc-events-pod
```

### Detener Pod

```bash
podman pod stop ai-sdlc-events-pod
```

### Iniciar Pod

```bash
podman pod start ai-sdlc-events-pod
```

### Reiniciar Pod

```bash
podman pod restart ai-sdlc-events-pod
```

### Remover Pod

```bash
# Para y elimina el pod completo
podman pod rm -f ai-sdlc-events-pod
```

### Ver Estado

```bash
# Estado del pod
podman pod ps

# Estado de contenedores
podman ps --filter pod=ai-sdlc-events-pod

# Inspeccionar pod
podman pod inspect ai-sdlc-events-pod
```

---

## Troubleshooting

### Error: Cannot connect to PostgreSQL

**Síntomas**:
```
WARN  [io.vertx.pgclient] Connection refused: localhost/127.0.0.1:5432
```

**Solución**:
```bash
# Verificar que PostgreSQL esté corriendo
podman exec ai-sdlc-postgres pg_isready -U aisdlc

# Ver logs de PostgreSQL
podman logs ai-sdlc-postgres

# Reiniciar contenedor PostgreSQL si necesario
podman restart ai-sdlc-postgres
```

### Error: Port 8080 already in use

**Solución**:
```bash
# Opción 1: Detener proceso que usa el puerto
netstat -ano | findstr :8080  # Windows
lsof -i :8080                 # Linux

# Opción 2: Usar otro puerto
podman pod create --name ai-sdlc-events-pod --publish 8081:8080
# Acceder en: http://localhost:8081
```

### Error: Image build failed

**Solución**:
```bash
# Verificar que Maven compile correctamente
./mvnw clean package -DskipTests

# Ver detalles del error
podman build -f deployment/docker/Containerfile -t ai-sdlc-events:latest . --no-cache
```

### Error: Flyway migration failed

**Causa**: Database schema ya existe de ejecución anterior

**Solución**:
```bash
# Opción 1: Remover pod y empezar limpio
podman pod rm -f ai-sdlc-events-pod

# Opción 2: Limpiar base de datos manualmente
podman exec -it ai-sdlc-postgres psql -U aisdlc -d aisdlc
# En psql:
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
\q
```

### Aplicación no responde

**Pasos de diagnóstico**:
```bash
# 1. Verificar que el contenedor esté corriendo
podman ps --filter pod=ai-sdlc-events-pod

# 2. Ver logs de la aplicación
podman logs --tail 50 ai-sdlc-app

# 3. Verificar health del pod
podman healthcheck run ai-sdlc-app

# 4. Reiniciar aplicación
podman restart ai-sdlc-app

# 5. Si persiste, reconstruir
podman pod rm -f ai-sdlc-events-pod
./deployment/podman-pod-setup.sh  # o .ps1 en Windows
```

---

## Persistencia de Datos

**IMPORTANTE**: El pod actual **no persiste datos** entre reinicios.

Para agregar persistencia:

### Opción 1: Volume Named

```bash
# Crear volume
podman volume create ai-sdlc-postgres-data

# Modificar comando run de PostgreSQL:
podman run -d \
  --pod ai-sdlc-events-pod \
  --name ai-sdlc-postgres \
  -v ai-sdlc-postgres-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=aisdlc \
  -e POSTGRES_USER=aisdlc \
  -e POSTGRES_PASSWORD=aisdlc \
  docker.io/library/postgres:16-alpine
```

### Opción 2: Bind Mount

```bash
# Crear directorio local
mkdir -p D:/git/homedir-ai-sdlc/data/postgres

# Modificar comando run:
podman run -d \
  --pod ai-sdlc-events-pod \
  --name ai-sdlc-postgres \
  -v D:/git/homedir-ai-sdlc/data/postgres:/var/lib/postgresql/data \
  -e POSTGRES_DB=aisdlc \
  -e POSTGRES_USER=aisdlc \
  -e POSTGRES_PASSWORD=aisdlc \
  docker.io/library/postgres:16-alpine
```

---

## Flujo de Desarrollo

### Rebuild tras cambios en código

```bash
# 1. Detener aplicación (mantener PostgreSQL)
podman stop ai-sdlc-app
podman rm ai-sdlc-app

# 2. Recompilar
./mvnw clean package -DskipTests

# 3. Rebuild imagen
podman build -f deployment/docker/Containerfile -t ai-sdlc-events:latest .

# 4. Reiniciar aplicación
podman run -d \
  --pod ai-sdlc-events-pod \
  --name ai-sdlc-app \
  -e QUARKUS_DATASOURCE_REACTIVE_URL=postgresql://localhost:5432/aisdlc \
  -e QUARKUS_DATASOURCE_USERNAME=aisdlc \
  -e QUARKUS_DATASOURCE_PASSWORD=aisdlc \
  -e QUARKUS_DATASOURCE_JDBC_URL=jdbc:postgresql://localhost:5432/aisdlc \
  ai-sdlc-events:latest
```

---

## Producción

Para deployment en producción:

### Recomendaciones

1. **Secrets Management**: No usar passwords hardcoded
   ```bash
   podman secret create db_password ./db_password.txt
   # Usar: --secret db_password
   ```

2. **Resource Limits**:
   ```bash
   --memory 1g \
   --cpus 2
   ```

3. **Restart Policy**:
   ```bash
   --restart unless-stopped
   ```

4. **Logging**:
   ```bash
   --log-driver journald \
   --log-opt tag=ai-sdlc-events
   ```

5. **Health Checks**: Ya incluidos en Containerfile

### Ejemplo Producción

```bash
podman run -d \
  --pod ai-sdlc-events-pod \
  --name ai-sdlc-app \
  --restart unless-stopped \
  --memory 1g \
  --cpus 2 \
  --log-driver journald \
  -e QUARKUS_DATASOURCE_REACTIVE_URL=postgresql://localhost:5432/aisdlc \
  -e QUARKUS_DATASOURCE_USERNAME=aisdlc \
  -e QUARKUS_DATASOURCE_PASSWORD="${DB_PASSWORD}" \
  -e QUARKUS_DATASOURCE_JDBC_URL=jdbc:postgresql://localhost:5432/aisdlc \
  -e QUARKUS_LOG_CONSOLE_JSON=true \
  ai-sdlc-events:latest
```

---

## Systemd Integration (Linux)

Para auto-start del pod con systemd:

```bash
# Generar unit file
podman generate systemd --new --name ai-sdlc-events-pod > ~/.config/systemd/user/ai-sdlc-pod.service

# Reload systemd
systemctl --user daemon-reload

# Enable auto-start
systemctl --user enable ai-sdlc-pod.service

# Start now
systemctl --user start ai-sdlc-pod.service

# Status
systemctl --user status ai-sdlc-pod.service
```

---

## Comandos Útiles

```bash
# Ver espacio usado
podman system df

# Limpiar recursos no usados
podman system prune -a

# Exportar pod a archivo
podman pod export ai-sdlc-events-pod -o ai-sdlc-pod.tar

# Importar pod
podman pod import ai-sdlc-pod.tar

# Ver métricas en vivo
podman stats --pod ai-sdlc-events-pod

# Shell en contenedor
podman exec -it ai-sdlc-app sh
podman exec -it ai-sdlc-postgres psql -U aisdlc
```

---

## Resumen

**Setup rápido**:
```powershell
cd D:\git\homedir-ai-sdlc\events-service
.\deployment\podman-pod-setup.ps1
```

**Acceso**:
- Dashboard: http://localhost:8080/dashboard/
- API: http://localhost:8080/q/swagger-ui

**Gestión**:
```bash
podman pod stop ai-sdlc-events-pod    # Detener
podman pod start ai-sdlc-events-pod   # Iniciar
podman pod rm -f ai-sdlc-events-pod   # Remover
```

**Logs**:
```bash
podman logs -f ai-sdlc-app
```

---

**Fecha**: 2026-08-09 18:20  
**Por**: Claude Sonnet 4.5  
**Status**: Scripts listos para ejecución
