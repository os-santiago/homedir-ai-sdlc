# AI-SDLC Monitoring Tools

Scripts para monitorear y visualizar el progreso de issues procesados por AI-SDLC.

## 🎯 Scripts Disponibles

### 1. `watch-workflow.ps1` - Visualizador de Workflow

**Interfaz visual en tiempo real** del estado de un issue.

```powershell
# Ver estado actual de un issue
.\watch-workflow.ps1 -IssueNumber 1360

# Modo continuo (auto-refresh cada 15s)
.\watch-workflow.ps1 -IssueNumber 1360 -Continuous
```

**Muestra**:
```
╔════════════════════════════════════════════════════════════════════════════════╗
║              AI-SDLC WORKFLOW MONITOR - Issue #1360                            ║
╚════════════════════════════════════════════════════════════════════════════════╝

  ▶ [Bug] notifications_center_empty_cta_board: texto dice 'Reputation Hub'

┌────────────┬────────────┬────────────┬────────────┬────────────┬────────────┐
│  PENDING   │   READY    │  CLAIMED   │IMPLEMENTING│IMPLEMENTED │   MERGED   │
│     ○      │     ○      │     ●      │     ○      │     ○      │     ○      │
│Issue creat.│Marked AI   │Worker clai.│SCC generat.│ PR created │  Deployed  │
└────────────┴────────────┴────────────┴────────────┴────────────┴────────────┘

  Overall Progress
  ▶███████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 50%

  ┌────────────────────────────────────────────────────────────────────────┐
  │ CURRENT STATUS                                                          │
  ├────────────────────────────────────────────────────────────────────────┤
  │ Current Stage: CLAIMED - Worker processing                             │
  │ Issue State: OPEN                                                      │
  │ Last Updated: 2026-08-09 14:32:15                                      │
  └────────────────────────────────────────────────────────────────────────┘

  TIMELINE
  │
  ├───▶ Issue created (2026-08-02 10:15)
  │   │
  ├───▶ Marked ready-to-implement
  │   │
  ├───▶ Worker claimed issue
  │

  ACTIVE LABELS
    ● bug
    ● ready-to-implement
    ● scc-claimed
```

---

### 2. `monitor-e2e.ps1` - Monitor Completo E2E

**Ejecuta y monitorea** un test completo end-to-end.

```powershell
.\monitor-e2e.ps1
```

**Hace**:
1. Selecciona issue apropiado
2. Lo marca para AI-SDLC
3. Dispara workflow
4. Monitorea ejecución
5. Verifica labels y PR creado
6. Muestra resumen final

---

### 3. `run-e2e-test.ps1` - Test E2E Simplificado

Versión simplificada del monitor E2E.

```powershell
# Con issue específico
.\run-e2e-test.ps1 -IssueNumber 1360

# Auto-selección de issue
.\run-e2e-test.ps1
```

---

## 📊 Flujo de Labels

El sistema AI-SDLC usa labels para tracking:

| Label | Etapa | Descripción |
|-------|-------|-------------|
| `ready-to-implement` | Inicio | Issue marcado para AI-SDLC |
| `scc-claimed` | Claimed | Worker tomó el issue |
| `scc-implementing` | Processing | SCC generando código |
| `scc-implemented` | PR Created | Pull Request creado |
| `scc-merged` | Complete | PR merged y deployed |

---

## 🎨 Interpretación de Colores

**Pipeline Visual**:
- 🟢 **Verde + ✓**: Etapa completada
- 🟡 **Amarillo + ▶**: Etapa actual (en progreso)
- ⚪ **Gris + ○**: Etapa pendiente

**Progress Bar**:
- 🟢 Verde: 100% completado
- 🟡 Amarillo: 50-99% progreso
- ⚪ Gris: 0-49% progreso

---

## 📋 Ejemplos de Uso

### Caso 1: Marcar un issue y monitorearlo

```powershell
# 1. Buscar issues disponibles
gh issue list -R os-santiago/homedir --label bug --state open --limit 5

# 2. Marcar issue
gh issue edit 1360 -R os-santiago/homedir --add-label "ready-to-implement"

# 3. Monitorear en tiempo real
.\watch-workflow.ps1 -IssueNumber 1360 -Continuous
```

### Caso 2: Test E2E completo

```powershell
# Ejecutar test completo con monitoreo
.\monitor-e2e.ps1
```

### Caso 3: Verificar estado de issue en proceso

```powershell
# Ver snapshot actual
.\watch-workflow.ps1 -IssueNumber 1360

# Ver issue en GitHub
gh issue view 1360 -R os-santiago/homedir

# Ver PR asociado
gh pr list -R os-santiago/homedir --search "1360"
```

---

## 🔧 Troubleshooting

### Issue no se procesa

**Verificar**:
```powershell
# 1. Ver labels actuales
gh issue view 1360 -R os-santiago/homedir --json labels

# 2. Verificar que tiene ready-to-implement
# 3. Esperar 3 minutos (worker timer interval)

# 4. Ver workflow runs
gh run list --workflow=test-autonomous-worker.yml --limit 5
```

### Worker no responde

**Verificar VPS**:
```powershell
# Heartbeat
curl http://vps:8081/api/sdlc/heartbeat

# Dashboard
Start-Process "http://vps:8081/sdlc/dashboard/"
```

### PR no se crea

**Causas comunes**:
- Issue rechazado en admission review (ver logs)
- SCC implementation falló
- Permisos de GitHub insuficientes

**Ver logs**:
```powershell
# Logs de último workflow
gh run list --workflow=test-autonomous-worker.yml --limit 1
gh run view <run-id> --log
```

---

## 📈 Métricas Esperadas

**Tiempos normales**:
- Detección de issue: **< 3 min** (timer interval)
- Admission review: **< 30 seg**
- SCC implementation: **5-10 min**
- PR creation: **< 1 min**
- **Total E2E: 16-20 minutos**

**Autonomía**:
- Target: **99%**
- Mínimo aceptable: **95%**

---

## 🚀 Dashboard Web

Si el VPS está accesible, el dashboard web ofrece visualización completa:

```
http://vps:8081/sdlc/dashboard/
```

**Features**:
- Pipeline visual en tiempo real
- Gráficos de métricas
- Historial de issues/PRs
- Detección de anomalías
- Audit trail completo

---

## 📚 Referencias

- Workflow original: `.github/workflows/test-autonomous-worker.yml`
- Documentación: `docs/HOMEDIR-AI-SDLC-FLOW.md`
- Policies: `platform/config/autonomous-decision-policy.yaml`
- Worker script: `platform/scripts/homedir-sdlc-worker.sh`

---

**Última actualización**: 2026-08-09
