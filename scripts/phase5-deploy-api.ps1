# Phase 5: API Layer Deployment
# Builds and deploys Java REST API for events

$ErrorActionPreference = "Stop"

Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Phase 5: API Layer Deployment" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

$dashboardDir = "dashboard\quarkus-app"

# Check dashboard directory exists
if (-not (Test-Path $dashboardDir)) {
    Write-Host "ERROR: Dashboard directory not found: $dashboardDir" -ForegroundColor Red
    exit 1
}

# Check Java classes exist
$eventClasses = @(
    "$dashboardDir\src\main\java\io\opensourcesantiago\aisdlc\events\EventApiResource.java",
    "$dashboardDir\src\main\java\io\opensourcesantiago\aisdlc\events\EventQueryService.java"
)

Write-Host "Verifying event classes..." -ForegroundColor Green
foreach ($class in $eventClasses) {
    if (Test-Path $class) {
        Write-Host "  ✓ $(Split-Path $class -Leaf)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $(Split-Path $class -Leaf) MISSING" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# Check Maven wrapper exists
$mvnw = "$dashboardDir\mvnw"
if (-not (Test-Path $mvnw)) {
    Write-Host "ERROR: Maven wrapper not found: $mvnw" -ForegroundColor Red
    Write-Host "Run 'mvn wrapper:wrapper' in $dashboardDir first" -ForegroundColor Yellow
    exit 1
}

# Build
Write-Host "Building Quarkus application..." -ForegroundColor Green
Write-Host ""

Push-Location $dashboardDir

try {
    # Clean build
    Write-Host "Running: ./mvnw clean package -DskipTests" -ForegroundColor Cyan
    & bash mvnw clean package -DskipTests

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Build failed!" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "✓ Build completed successfully" -ForegroundColor Green
    Write-Host ""

    # Check JAR exists
    $jarPath = "target\quarkus-app\quarkus-run.jar"
    if (Test-Path $jarPath) {
        $jarSize = (Get-Item $jarPath).Length / 1MB
        Write-Host "  JAR created: $jarPath ($($jarSize.ToString('0.0')) MB)" -ForegroundColor Green
    }

} finally {
    Pop-Location
}

Write-Host ""
Write-Host "=================================" -ForegroundColor Green
Write-Host "Phase 5: BUILD COMPLETED ✓" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host ""

Write-Host "To test locally:" -ForegroundColor Cyan
Write-Host "  cd $dashboardDir" -ForegroundColor Gray
Write-Host "  ./mvnw quarkus:dev" -ForegroundColor Gray
Write-Host ""
Write-Host "Then visit:" -ForegroundColor Cyan
Write-Host "  http://localhost:8081/api/sdlc/events/latest" -ForegroundColor Gray
Write-Host "  http://localhost:8081/api/sdlc/events/stats" -ForegroundColor Gray
Write-Host ""

Write-Host "Next step: Phase 6 - Dashboard UI" -ForegroundColor Cyan
Write-Host "  Run: .\scripts\phase6-deploy-dashboard.ps1" -ForegroundColor Gray
