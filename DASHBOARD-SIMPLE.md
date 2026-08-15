# Dashboard Simple - Sin Quarkus

Dado que el proyecto Quarkus completo requiere más setup, he creado una versión simplificada usando Python HTTP server.

## 🚀 Start Rápido

```powershell
cd D:\git\homedir-ai-sdlc

# Generar eventos de prueba
bash scripts/generate-sample-events.sh

# Iniciar servidor simple
.\scripts\start-simple-server.ps1
```

Abre: http://localhost:8081/sdlc/events/

## ✅ Lo que Funciona

- ✅ Dashboard UI completo
- ✅ API mock con datos reales de eventos
- ✅ Timeline de eventos
- ✅ Estadísticas
- ✅ Pipeline visual
- ✅ Sin necesidad de Java/Maven

## 📊 APIs Disponibles

- `/api/sdlc/events/latest` - Últimos 50 eventos
- `/api/sdlc/events/stats` - Estadísticas
- `/api/sdlc/events/active` - Issues activos (mock)

## ⚠️ Limitaciones

- **Sin búsqueda por issue** (requiere backend completo)
- **Sin auto-refresh** de datos (solo UI)
- **APIs mockeadas** parcialmente

## 🔧 Para Producción

Eventualmente necesitarás el backend Java completo:

1. Crear proyecto Quarkus desde cero
2. Agregar clases EventApiResource y EventQueryService
3. Build con Maven
4. Deploy

Pero para **desarrollo y demo**, este servidor simple es suficiente.
