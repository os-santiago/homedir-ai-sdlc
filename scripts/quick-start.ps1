# Quick Start - Get dashboard running with sample data
# One-command setup for development

param(
    [switch]$SkipBuild,
    [switch]$SkipEvents
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║     AI-SDLC Event Dashboard - Quick Start                 ║" -ForegroundColor Magenta
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

# Step 1: Generate sample events
if (-not $SkipEvents) {
    Write-Host "Step 1: Generating sample events..." -ForegroundColor Cyan
    Write-Host ""

    & bash scripts/generate-sample-events.sh

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Failed to generate events!" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "✓ Sample events generated" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "Step 1: Skipping event generation" -ForegroundColor Yellow
    Write-Host ""
}

# Step 2: Build dashboard (if needed)
if (-not $SkipBuild) {
    Write-Host "Step 2: Building dashboard..." -ForegroundColor Cyan
    Write-Host ""

    Push-Location dashboard\quarkus-app

    try {
        Write-Host "Running: ./mvnw clean package -DskipTests" -ForegroundColor Gray
        & bash mvnw clean package -DskipTests

        if ($LASTEXITCODE -ne 0) {
            throw "Build failed"
        }

        Write-Host ""
        Write-Host "✓ Build completed" -ForegroundColor Green
        Write-Host ""
    } finally {
        Pop-Location
    }
} else {
    Write-Host "Step 2: Skipping build" -ForegroundColor Yellow
    Write-Host ""
}

# Step 3: Start dashboard
Write-Host "Step 3: Starting dashboard..." -ForegroundColor Cyan
Write-Host ""

Write-Host "Dashboard will start on port 8081" -ForegroundColor Green
Write-Host ""
Write-Host "URLs:" -ForegroundColor Cyan
Write-Host "  Dashboard: http://localhost:8081/sdlc/events/" -ForegroundColor White
Write-Host "  API:       http://localhost:8081/api/sdlc/events/latest" -ForegroundColor White
Write-Host ""

Write-Host "Sample issues to search:" -ForegroundColor Cyan
Write-Host "  1360 - Completed (merged to prod)" -ForegroundColor Green
Write-Host "  1361 - In progress (implementing)" -ForegroundColor Yellow
Write-Host "  1362 - CI failed (remediation)" -ForegroundColor Yellow
Write-Host "  1363 - Rejected (admission)" -ForegroundColor Red
Write-Host "  1364 - Just detected" -ForegroundColor Gray
Write-Host ""

Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

Start-Sleep -Seconds 2

Push-Location dashboard\quarkus-app

try {
    & bash mvnw quarkus:dev
} finally {
    Pop-Location
}
