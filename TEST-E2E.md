# Prueba End-to-End AI-SDLC Local

## Prerequisitos

1. **Podman** o **Docker** instalado
2. **GitHub CLI** (`gh`) instalado y autenticado
3. Variables de entorno:
   ```powershell
   $env:GH_TOKEN = "ghp_xxxxx"
   $env:SC_API_KEY = "nvapi-xxxxx"  # Opcional para test de infra
   ```

## Pasos para Ejecutar

### 1. Setup Inicial

```powershell
cd D:\git\homedir-ai-sdlc
.\local-setup.ps1
```

Esto:
- ✅ Verifica Podman/Docker
- ✅ Crea directorios local-state/ y local-logs/
- ✅ Build imagen `homedir-ai-sdlc:local`

### 2. Seleccionar Issue

Buscar issue para test:
```powershell
gh issue list -R os-santiago/homedir --label bug --state open --limit 5
```

Ejemplo output:
```
1360: [Bug] notifications_center_empty_cta_board: texto dice 'Reputation Hub'
1309: [Bug] Community picks: "Curated picks: 0"
1304: [Bug] Reputation Hub /how: contenido duplicado
```

### 3. Marcar Issue

```powershell
.\local-mark-issue.ps1 1360
```

Esto agrega label `ready-to-implement` al issue.

### 4. Ejecutar Worker

```powershell
.\local-run-worker.ps1
```

**Expected flow**:
1. Container inicia
2. Worker carga policies
3. Busca issues con `ready-to-implement`
4. Encuentra #1360
5. Admission review → ACCEPT/REJECT
6. Si ACCEPT:
   - git clone `os-santiago/homedir`
   - Ejecuta SCC (si `SC_API_KEY` disponible)
   - Genera código
   - Crea commit
   - Push a GitHub
   - Crea PR

**Timeline esperado**: 16-20 minutos

### 5. Verificar Resultado

Ver logs:
```powershell
Get-Content .\local-logs\worker.log -Tail 50
```

Buscar PR creado:
```powershell
gh pr list -R os-santiago/homedir --search "1360" --limit 3
```

Ver estado:
```powershell
Get-Content .\local-state\heartbeat.json | ConvertFrom-Json
```

## Troubleshooting

### Error: Image not found

Rebuild:
```powershell
.\local-setup.ps1 -SkipBuild:$false
```

### Error: Permission denied en git clone

El container intenta crear `/srv/homedir-sdlc/worktrees/homedir/.git` y puede fallar.

**Solución actual**: Usar GitHub Actions en lugar de local:
```powershell
gh workflow run test-autonomous-worker.yml --ref main
gh run watch
```

### Error: GH_TOKEN not set

```powershell
$env:GH_TOKEN = "ghp_your_token_here"
```

O autenticar con:
```powershell
gh auth login
```

### Error: Container runtime not found

Instalar Podman Desktop o Docker Desktop y reiniciar PowerShell.

## Alternative: GitHub Actions

Si el setup local falla, usar GitHub Actions que ya funciona:

```powershell
# Ver workflow
gh workflow view test-autonomous-worker.yml

# Ejecutar
gh workflow run test-autonomous-worker.yml --ref main

# Monitorear
gh run watch

# Ver resultado
gh run view --log
```

## Métricas de Éxito

- ✅ Worker ejecuta sin errores fatales
- ✅ Issue procesado (claimed)
- ✅ PR creado en GitHub
- ✅ Logs muestran ciclo completo
- ✅ Tiempo E2E: 16-20 minutos
- ✅ Estado en `heartbeat.json` actualizado

## Limitaciones Conocidas

### Local Container (7 intentos fallidos)

Problema persistente con permisos en git clone dentro de volumes montados:
```
/srv/homedir-sdlc/worktrees/homedir/.git: Permission denied
```

**Root cause**: Mount permissions Windows ↔ Linux container

**Workaround**: Usar GitHub Actions hasta resolver permisos

### GitHub Actions (funciona)

✅ PR #1345 creado exitosamente por workflow
✅ Worker ejecuta sin permission errors
✅ Autonomía validada

**Recomendación**: Usar GitHub Actions para tests E2E hasta resolver setup local.
