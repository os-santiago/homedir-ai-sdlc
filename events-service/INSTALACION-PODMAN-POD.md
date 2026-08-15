# Instalación con Podman Pod - Quick Start

## ⚡ Instalación Rápida (1 comando)

### Windows PowerShell

```powershell
cd D:\git\homedir-ai-sdlc\events-service
.\deployment\podman-pod-setup.ps1
```

### Linux/Mac/Git Bash

```bash
cd /d/git/homedir-ai-sdlc/events-service
chmod +x deployment/podman-pod-setup.sh
./deployment/podman-pod-setup.sh
```

**Tiempo**: 2-3 minutos (primera vez)

---

## ¿Qué hace el script?

1. ✅ Crea pod `ai-sdlc-events-pod`
2. ✅ Inicia PostgreSQL 16 (localhost:5432)
3. ✅ Compila la aplicación Java
4. ✅ Construye imagen Podman
5. ✅ Inicia AI-SDLC Events Service
6. ✅ Verifica deployment completo

---

## Acceso Rápido

Una vez completado el script:

**Dashboard**: http://localhost:8080/dashboard/  
**API Docs**: http://localhost:8080/q/swagger-ui  
**Health**: http://localhost:8080/api/health/status

---

## Test Rápido

```bash
# Publicar evento de prueba
curl -X POST http://localhost:8080/internal/events/issue-detected \
  -H "Content-Type: application/json" \
  -d '{"issueNumber": 1000, "metadata": {"title": "Test Issue"}}' | jq

# Ver en dashboard
# http://localhost:8080/dashboard/
# Deberías ver el evento en "Recent Events"
```

---

## Gestión del Pod

```bash
# Ver logs
podman logs -f ai-sdlc-app

# Detener
podman pod stop ai-sdlc-events-pod

# Iniciar
podman pod start ai-sdlc-events-pod

# Remover
podman pod rm -f ai-sdlc-events-pod
```

---

## Troubleshooting

### Si podman no se encuentra

```powershell
# Verificar instalación
podman --version

# Si no está instalado:
winget install RedHat.Podman
# Reiniciar PowerShell después
```

### Si el puerto 8080 está ocupado

Editar `deployment/podman-pod-setup.ps1`:
```powershell
$APP_PORT = 8081  # Cambiar de 8080 a 8081
```

Luego acceder en: http://localhost:8081/dashboard/

### Ver errores

```bash
# Logs de la aplicación
podman logs ai-sdlc-app

# Logs de PostgreSQL
podman logs ai-sdlc-postgres

# Estado del pod
podman pod ps
```

---

## Documentación Completa

Ver: `POD-DEPLOYMENT.md` para:
- Manual paso a paso
- Opciones de configuración
- Persistencia de datos
- Deployment en producción
- Troubleshooting completo

---

## Arquitectura

```
Pod: ai-sdlc-events-pod (localhost:8080)
├── PostgreSQL 16      (localhost:5432)
└── AI-SDLC Service    (puerto 8080)
```

**Ventaja**: Contenedores comparten localhost, no necesitan network bridge.

---

**Creado**: 2026-08-09  
**Versión**: 1.0.0  
**Status**: Listo para ejecutar
