# Deployment Automatizado - TODO COMO CÓDIGO

## 🚀 Deployment en 1 Comando

### Windows (PowerShell)

```powershell
cd D:\git\homedir-ai-sdlc\events-service
.\deploy.ps1
```

### Linux/Mac (Bash)

```bash
cd /d/git/homedir-ai-sdlc/events-service
chmod +x deploy.sh
./deploy.sh
```

---

## ✨ Qué Hace el Script

### Deployment Completo Automatizado

1. ✅ **Verifica Docker** - Instala si no existe (Windows)
2. ✅ **Verifica Docker daemon** - Espera que inicie
3. ✅ **Limpia deployment anterior** - docker-compose down
4. ✅ **Compila aplicación** - ./mvnw package
5. ✅ **Construye imagen** - docker build
6. ✅ **Inicia servicios** - docker-compose up
   - PostgreSQL 16 (puerto 5432)
   - AI-SDLC App (puerto 8080)
7. ✅ **Espera a PostgreSQL** - Verifica pg_isready
8. ✅ **Espera a la aplicación** - Verifica health endpoint
9. ✅ **Verifica deployment** - Muestra estado

**Tiempo total**: 3-5 minutos (primera vez)

---

## 📦 Stack Completo

```
Docker Compose Stack
├── PostgreSQL 16 (alpine)
│   ├── Puerto: 5432
│   ├── Database: aisdlc
│   ├── User: aisdlc
│   ├── Volume: postgres-data (persistente)
│   └── Health check: pg_isready
│
└── AI-SDLC Events Service
    ├── Puerto: 8080
    ├── Image: ai-sdlc-events:latest
    ├── Depends on: PostgreSQL (healthy)
    ├── Health check: /api/health/live
    ├── Restart: unless-stopped
    └── Features:
        ├── Event Sourcing + CQRS
        ├── REST API (28+ endpoints)
        ├── Dashboard SSE real-time
        ├── Metrics (Prometheus)
        └── Health checks (K8s-ready)
```

---

## 🎯 Acceso a la Aplicación

Una vez completado:

- **Dashboard**: http://localhost:8080/dashboard/
- **API Docs**: http://localhost:8080/q/swagger-ui
- **Health**: http://localhost:8080/api/health/status
- **Metrics**: http://localhost:8080/q/metrics

---

## 🧪 Test Rápido

```bash
# Publicar evento
curl -X POST http://localhost:8080/internal/events/issue-detected \
  -H "Content-Type: application/json" \
  -d '{"issueNumber": 1000, "metadata": {"title": "Test Issue"}}'

# Ver en dashboard
# http://localhost:8080/dashboard/

# Ver eventos
curl http://localhost:8080/api/events/recent?limit=5 | jq
```

---

## 🔧 Gestión

```bash
# Ver logs
docker logs -f ai-sdlc-app
docker logs -f ai-sdlc-postgres

# Ver estado
docker ps
docker-compose ps

# Detener
docker-compose down

# Reiniciar
docker-compose restart

# Reconstruir
./deploy.ps1  # o ./deploy.sh
```

---

## 🐛 Troubleshooting

### Docker no está instalado

**Windows**:
```powershell
# El script lo instalará automáticamente
.\deploy.ps1
```

**Linux**:
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### Docker daemon no está corriendo

**Windows**: Abre Docker Desktop

**Linux**:
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### Puerto 8080 ocupado

Edita `docker-compose.yml`:
```yaml
ports:
  - "8081:8080"  # Cambiar 8080 a 8081
```

### Ver errores detallados

```bash
# Logs completos
docker-compose logs

# Solo aplicación
docker logs ai-sdlc-app

# Solo PostgreSQL
docker logs ai-sdlc-postgres
```

---

## 📋 Archivos del Deployment

```
events-service/
├── deploy.ps1                    ⭐ Script PowerShell
├── deploy.sh                     ⭐ Script Bash
├── docker-compose.yml            ⭐ Stack completo
└── deployment/docker/
    └── Containerfile             ⭐ Multi-stage build
```

**TODO está como código** - No hay pasos manuales.

---

## ✅ Características del Deployment

### Infraestructura como Código

- ✅ PostgreSQL incluido (no requiere instalación manual)
- ✅ Aplicación se construye automáticamente
- ✅ Health checks automáticos
- ✅ Restart policy configurado
- ✅ Network isolation
- ✅ Volume persistence
- ✅ Todo versionado en git

### Zero Manual Steps

1. Ejecutar script
2. Esperar 3-5 minutos
3. Acceder a http://localhost:8080/dashboard/

**Eso es todo** 🎉

---

## 🔄 Actualizar el Sistema

```bash
# 1. Detener
docker-compose down

# 2. Pull últimos cambios (si aplica)
git pull

# 3. Redesplegar
.\deploy.ps1  # o ./deploy.sh
```

---

## 🗑️ Remover Completamente

```bash
# Detener y remover contenedores
docker-compose down

# Remover también volumes (borra datos)
docker-compose down -v

# Remover imagen
docker rmi ai-sdlc-events:latest
```

---

## 💡 Ventajas de Este Approach

1. ✅ **Todo como código** - docker-compose.yml define toda la infra
2. ✅ **Reproducible** - Mismo resultado en cualquier máquina
3. ✅ **Portable** - Windows, Linux, Mac
4. ✅ **Aislado** - No contamina el sistema host
5. ✅ **Rápido** - 1 comando para deploy completo
6. ✅ **Fácil rollback** - docker-compose down + redeploy
7. ✅ **Production-like** - Mismo stack que producción

---

**Creado**: 2026-08-09  
**Por**: Claude Sonnet 4.5  
**Estado**: ✅ TODO COMO CÓDIGO
