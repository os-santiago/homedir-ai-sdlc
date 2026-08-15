# Quick Start Wrapper - Ejecuta el setup completo
# Este wrapper maneja la ejecución y muestra el progreso

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Starting AI-SDLC Event Dashboard Setup..." -ForegroundColor Cyan
Write-Host ""

# Verify we're in the right directory
if (-not (Test-Path "scripts\quick-start.ps1")) {
    Write-Host "ERROR: Must run from D:\git\homedir-ai-sdlc\" -ForegroundColor Red
    exit 1
}

# Step 1: Generate sample events
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host "STEP 1: Generating Sample Events" -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host ""

if (Test-Path "scripts\generate-sample-events.sh") {
    bash scripts/generate-sample-events.sh

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✓ Sample events generated successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to generate events" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✗ generate-sample-events.sh not found" -ForegroundColor Red
    exit 1
}

# Step 2: Verify events created
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host "STEP 2: Verifying Events" -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host ""

if (Test-Path "local-state\events\all-events.jsonl") {
    $eventCount = (Get-Content "local-state\events\all-events.jsonl" | Measure-Object -Line).Lines
    Write-Host "✓ Events file created: $eventCount events" -ForegroundColor Green

    # Show sample event
    Write-Host ""
    Write-Host "Sample event:" -ForegroundColor Cyan
    Get-Content "local-state\events\all-events.jsonl" -Head 1 | ConvertFrom-Json | ConvertTo-Json -Depth 5
} else {
    Write-Host "✗ Events file not found" -ForegroundColor Red
    exit 1
}

# Step 3: Build dashboard
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host "STEP 3: Building Dashboard" -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host ""

Push-Location dashboard\quarkus-app

try {
    Write-Host "Running Maven build (this may take a few minutes)..." -ForegroundColor Yellow
    Write-Host ""

    & bash mvnw clean package -DskipTests -q

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✓ Dashboard built successfully" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "✗ Build failed" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}

# Step 4: Show URLs and start
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host "STEP 4: Starting Dashboard" -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host ""

Write-Host "Dashboard will be available at:" -ForegroundColor Green
Write-Host ""
Write-Host "  🌐 Dashboard: http://localhost:8081/sdlc/events/" -ForegroundColor Cyan
Write-Host "  📊 API Stats: http://localhost:8081/api/sdlc/events/stats" -ForegroundColor Cyan
Write-Host "  📝 API Latest: http://localhost:8081/api/sdlc/events/latest" -ForegroundColor Cyan
Write-Host ""

Write-Host "Sample issues to search:" -ForegroundColor Yellow
Write-Host "  1360 - Completed ✓" -ForegroundColor Green
Write-Host "  1361 - In Progress ⏳" -ForegroundColor Yellow
Write-Host "  1362 - CI Failed ⚠" -ForegroundColor Yellow
Write-Host "  1363 - Rejected ✗" -ForegroundColor Red
Write-Host "  1364 - Queued ○" -ForegroundColor Gray
Write-Host ""

Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""
Write-Host "Starting in 3 seconds..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

Push-Location dashboard\quarkus-app

try {
    & bash mvnw quarkus:dev
} finally {
    Pop-Location
}
