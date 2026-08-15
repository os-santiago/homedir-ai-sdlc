# Phase 6: Dashboard UI Deployment
# Deploys and tests web dashboard

$ErrorActionPreference = "Stop"

Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Phase 6: Dashboard UI Deployment" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

$dashboardDir = "dashboard\quarkus-app"
$resourcesDir = "$dashboardDir\src\main\resources\META-INF\resources\sdlc\events"

# Check dashboard files exist
Write-Host "Verifying dashboard files..." -ForegroundColor Green

$dashboardFiles = @(
    "$resourcesDir\index.html",
    "$resourcesDir\events-dashboard.js"
)

foreach ($file in $dashboardFiles) {
    if (Test-Path $file) {
        Write-Host "  ✓ $(Split-Path $file -Leaf)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $(Split-Path $file -Leaf) MISSING" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Start Quarkus in dev mode
Write-Host "Starting Quarkus in dev mode..." -ForegroundColor Green
Write-Host "This will:" -ForegroundColor Yellow
Write-Host "  • Start API on port 8081" -ForegroundColor Yellow
Write-Host "  • Serve dashboard at /sdlc/events/" -ForegroundColor Yellow
Write-Host "  • Enable hot-reload for changes" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop when done testing" -ForegroundColor Yellow
Write-Host ""

Push-Location $dashboardDir

try {
    Write-Host "Running: ./mvnw quarkus:dev" -ForegroundColor Cyan
    Write-Host ""

    # Start Quarkus dev mode
    & bash mvnw quarkus:dev

} finally {
    Pop-Location
}

Write-Host ""
Write-Host "=================================" -ForegroundColor Green
Write-Host "Phase 6: DEPLOYMENT READY ✓" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host ""

Write-Host "Dashboard URLs:" -ForegroundColor Cyan
Write-Host "  Main Dashboard: http://localhost:8081/sdlc/events/" -ForegroundColor Gray
Write-Host "  API Latest:     http://localhost:8081/api/sdlc/events/latest" -ForegroundColor Gray
Write-Host "  API Stats:      http://localhost:8081/api/sdlc/events/stats" -ForegroundColor Gray
Write-Host ""

Write-Host "Testing checklist:" -ForegroundColor Cyan
Write-Host "  [ ] Dashboard loads" -ForegroundColor Gray
Write-Host "  [ ] Statistics show" -ForegroundColor Gray
Write-Host "  [ ] Pipeline renders" -ForegroundColor Gray
Write-Host "  [ ] Timeline shows events" -ForegroundColor Gray
Write-Host "  [ ] Search works" -ForegroundColor Gray
Write-Host "  [ ] Auto-refresh toggles" -ForegroundColor Gray
