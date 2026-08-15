# AI-SDLC Events Service - Deployment Automatizado Completo
# Instala Docker si no existe y despliega todo el stack

param(
    [switch]$SkipDockerInstall = $false,
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AI-SDLC Events Service - Auto Deploy" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verificar/Instalar Docker
Write-Host "Step 1: Verificando Docker..." -ForegroundColor Yellow

$dockerInstalled = $false
try {
    $dockerVersion = docker --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Docker ya está instalado: $dockerVersion" -ForegroundColor Green
        $dockerInstalled = $true
    }
} catch {
    Write-Host "Docker no encontrado" -ForegroundColor Gray
}

if (-not $dockerInstalled -and -not $SkipDockerInstall) {
    Write-Host "Instalando Docker Desktop..." -ForegroundColor Yellow
    Write-Host "Esto puede tardar varios minutos..." -ForegroundColor Gray

    try {
        # Intentar con winget
        winget install Docker.DockerDesktop --accept-package-agreements --accept-source-agreements

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Docker Desktop instalado" -ForegroundColor Green
            Write-Host "" -ForegroundColor Yellow
            Write-Host "IMPORTANTE: Necesitas reiniciar Windows para completar la instalación de Docker" -ForegroundColor Yellow
            Write-Host "Después de reiniciar, ejecuta este script nuevamente:" -ForegroundColor Yellow
            Write-Host "  .\deploy.ps1" -ForegroundColor Cyan
            Write-Host ""

            $restart = Read-Host "¿Deseas reiniciar ahora? (s/n)"
            if ($restart -eq 's' -or $restart -eq 'S') {
                Write-Host "Reiniciando sistema..." -ForegroundColor Yellow
                Restart-Computer -Force
            }
            exit 0
        }
    } catch {
        Write-Host "Error instalando Docker: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Instala Docker Desktop manualmente desde:" -ForegroundColor Yellow
        Write-Host "  https://www.docker.com/products/docker-desktop/" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "O ejecuta:" -ForegroundColor Yellow
        Write-Host "  winget install Docker.DockerDesktop" -ForegroundColor Cyan
        exit 1
    }
}

if (-not $dockerInstalled) {
    Write-Host "Docker no está disponible. Ejecuta:" -ForegroundColor Red
    Write-Host "  .\deploy.ps1" -ForegroundColor Cyan
    Write-Host "El script instalará Docker automáticamente." -ForegroundColor Gray
    exit 1
}

# Step 2: Verificar que Docker daemon esté corriendo
Write-Host ""
Write-Host "Step 2: Verificando Docker daemon..." -ForegroundColor Yellow

$maxRetries = 30
$retry = 0
while ($retry -lt $maxRetries) {
    try {
        docker ps 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Docker daemon está corriendo" -ForegroundColor Green
            break
        }
    } catch {}

    $retry++
    if ($retry -eq 1) {
        Write-Host "Esperando a que Docker daemon inicie..." -ForegroundColor Gray
        Write-Host "Si Docker Desktop no está abierto, ábrelo manualmente" -ForegroundColor Yellow
    }
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 2
}

if ($retry -ge $maxRetries) {
    Write-Host ""
    Write-Host "Docker daemon no está corriendo" -ForegroundColor Red
    Write-Host "Abre Docker Desktop y espera que inicie completamente" -ForegroundColor Yellow
    Write-Host "Luego ejecuta este script nuevamente" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Step 3: Detener contenedores existentes
Write-Host "Step 3: Limpiando deployment anterior..." -ForegroundColor Yellow

docker-compose down 2>&1 | Out-Null
Write-Host "✓ Limpieza completada" -ForegroundColor Green
Write-Host ""

# Step 4: Compilar aplicación
Write-Host "Step 4: Compilando aplicación..." -ForegroundColor Yellow

$buildOutput = .\mvnw.cmd clean package -DskipTests 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error compilando aplicación:" -ForegroundColor Red
    Write-Host $buildOutput
    exit 1
}

Write-Host "✓ Aplicación compilada exitosamente" -ForegroundColor Green
Write-Host ""

# Step 5: Construir imagen Docker
Write-Host "Step 5: Construyendo imagen Docker..." -ForegroundColor Yellow

docker build -f deployment/docker/Containerfile -t ai-sdlc-events:latest . 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error construyendo imagen Docker" -ForegroundColor Red
    docker build -f deployment/docker/Containerfile -t ai-sdlc-events:latest .
    exit 1
}

Write-Host "✓ Imagen Docker construida" -ForegroundColor Green
Write-Host ""

# Step 6: Iniciar servicios con Docker Compose
Write-Host "Step 6: Iniciando servicios..." -ForegroundColor Yellow

docker-compose up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error iniciando servicios" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Servicios iniciados" -ForegroundColor Green
Write-Host ""

# Step 7: Esperar a que PostgreSQL esté listo
Write-Host "Step 7: Esperando a PostgreSQL..." -ForegroundColor Yellow

$retry = 0
$maxRetries = 30
while ($retry -lt $maxRetries) {
    try {
        docker exec ai-sdlc-postgres pg_isready -U aisdlc 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ PostgreSQL está listo" -ForegroundColor Green
            break
        }
    } catch {}

    Write-Host "." -NoNewline
    Start-Sleep -Seconds 1
    $retry++
}
Write-Host ""

if ($retry -ge $maxRetries) {
    Write-Host "PostgreSQL no respondió a tiempo" -ForegroundColor Red
    docker logs ai-sdlc-postgres
    exit 1
}

# Step 8: Esperar a que la aplicación esté lista
Write-Host "Step 8: Esperando a la aplicación..." -ForegroundColor Yellow

$retry = 0
$maxRetries = 60
while ($retry -lt $maxRetries) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080/api/health/live" -UseBasicParsing -TimeoutSec 1 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "✓ Aplicación está lista" -ForegroundColor Green
            break
        }
    } catch {}

    if ($retry % 10 -eq 0) {
        Write-Host "." -NoNewline
    }
    Start-Sleep -Seconds 1
    $retry++
}
Write-Host ""

if ($retry -ge $maxRetries) {
    Write-Host "Aplicación no respondió a tiempo" -ForegroundColor Yellow
    Write-Host "Verificando logs..." -ForegroundColor Gray
    docker logs --tail 50 ai-sdlc-app
}

# Step 9: Verificar deployment
Write-Host "Step 9: Verificando deployment..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Contenedores corriendo:" -ForegroundColor Cyan
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
Write-Host ""

Write-Host "Estado de salud:" -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8080/api/health/status" -UseBasicParsing
    $health | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Aplicación aún iniciando..." -ForegroundColor Yellow
}
Write-Host ""

# Success!
Write-Host "========================================" -ForegroundColor Green
Write-Host "✓ Deployment completado exitosamente!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Accede a la aplicación:" -ForegroundColor Cyan
Write-Host "  Dashboard:    http://localhost:8080/dashboard/" -ForegroundColor White
Write-Host "  API Docs:     http://localhost:8080/q/swagger-ui" -ForegroundColor White
Write-Host "  Health:       http://localhost:8080/api/health/status" -ForegroundColor White
Write-Host "  Metrics:      http://localhost:8080/q/metrics" -ForegroundColor White
Write-Host ""

Write-Host "Gestión:" -ForegroundColor Cyan
Write-Host "  Ver logs:     docker logs -f ai-sdlc-app" -ForegroundColor White
Write-Host "  Detener:      docker-compose down" -ForegroundColor White
Write-Host "  Reiniciar:    docker-compose restart" -ForegroundColor White
Write-Host ""

Write-Host "Test rápido:" -ForegroundColor Cyan
Write-Host @"
  curl -X POST http://localhost:8080/internal/events/issue-detected \
    -H "Content-Type: application/json" \
    -d '{"issueNumber": 1000, "metadata": {"title": "Test"}}'
"@ -ForegroundColor White
Write-Host ""

# Abrir dashboard en navegador
$openBrowser = Read-Host "¿Abrir dashboard en navegador? (s/n)"
if ($openBrowser -eq 's' -or $openBrowser -eq 'S') {
    Start-Process "http://localhost:8080/dashboard/"
}
