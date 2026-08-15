# 📊 View Dashboard - Standalone Version

El dashboard funciona **sin servidor** - solo abre el archivo HTML en tu navegador.

## 🚀 Pasos (2 minutos)

### 1. Generar Eventos de Prueba

```powershell
cd D:\git\homedir-ai-sdlc
bash scripts/generate-sample-events.sh
```

Esto crea: `local-state/events/all-events.jsonl`

### 2. Abrir Dashboard

**Opción A - Doble click**:
1. Abre el explorador de archivos
2. Navega a `D:\git\homedir-ai-sdlc\`
3. Doble click en `dashboard-standalone.html`

**Opción B - PowerShell**:
```powershell
Start-Process "D:\git\homedir-ai-sdlc\dashboard-standalone.html"
```

### 3. Cargar Eventos

1. En el dashboard, click en **"📂 Load Events File"**
2. Selecciona el archivo:
   ```
   D:\git\homedir-ai-sdlc\local-state\events\all-events.jsonl
   ```
3. El dashboard se poblará automáticamente

## ✅ Qué Verás

### Statistics
```
Total Events: 52
Errors: 1
Issues Tracked: 5
```

### Pipeline
```
Detection → Admission → Implementation → PR Mgmt → CI Checks → Remediation → Deploy
   ✓           ✓             ✓            ✓          ✓            ✓          ✓
```
(Etapas en verde = tienen eventos)

### Timeline
Lista de últimos 20 eventos con:
- Tipo de evento
- Timestamp relativo ("5m ago")
- Status badges
- Metadata (decision, duration, etc.)
- IDs de trazabilidad

## 📋 Issues de Ejemplo

Los eventos generados incluyen:
- **#1360** - Ciclo completo (detection → deploy) ✅
- **#1361** - En progreso (implementing) ⏳
- **#1362** - CI failed ⚠️
- **#1363** - Rejected ❌
- **#1364** - Just detected ⚪

## 🎨 Features

✅ **Sin servidor** - Solo HTML/JS  
✅ **Datos reales** - Lee eventos generados  
✅ **Pipeline visual** - 7 etapas  
✅ **Timeline** - Últimos 20 eventos  
✅ **Estadísticas** - Totales y errores  
✅ **IDs de trazabilidad** - Event, tracking, action  

## 🔧 Troubleshooting

### "No events file found"
```powershell
# Genera eventos primero
bash scripts/generate-sample-events.sh
```

### "Error parsing file"
- Asegúrate de seleccionar `all-events.jsonl`
- No selecciones archivos individuales de las carpetas de etapas

### Dashboard no carga
- Usa un browser moderno (Chrome, Edge, Firefox)
- Asegúrate de tener JavaScript habilitado

## 📊 Próximos Pasos

### Para más eventos:
```bash
# Modifica el script para agregar más issues
nano scripts/generate-sample-events.sh
```

### Para eventos reales:
Integra el event emitter al worker siguiendo:
- `IMPLEMENTATION-ROADMAP.md` (Phase 3)
- `platform/scripts/integrate-events-to-worker.sh`

### Para dashboard con servidor:
Cuando tengas Java 21 + Maven configurado, usa el dashboard Quarkus completo.

---

**Ventajas de esta versión**:
- ❌ No requiere Java
- ❌ No requiere Maven
- ❌ No requiere servidor
- ❌ No requiere build
- ✅ Solo abre HTML y carga JSON
- ✅ Perfecto para demos y desarrollo

**Limitaciones**:
- No auto-refresh
- No búsqueda por issue individual
- No APIs dinámicas

Para ver **eventos en tiempo real**, usa:
```powershell
.\scripts\watch-workflow.ps1 -IssueNumber 1360 -Continuous
```
