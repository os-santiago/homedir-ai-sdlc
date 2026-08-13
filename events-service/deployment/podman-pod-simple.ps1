# AI-SDLC Events Service - Simple Pod Deployment
# Skips Maven build, uses existing JAR or dev mode

$PODMAN = "C:\Users\sergi\AppData\Local\Programs\Podman\podman.exe"
$POD_NAME = "ai-sdlc-events-pod"
$POSTGRES_CONTAINER = "ai-sdlc-postgres"
$APP_CONTAINER = "ai-sdlc-app"
$DB_NAME = "aisdlc"
$DB_USER = "aisdlc"
$DB_PASSWORD = "aisdlc"
$APP_PORT = 8080

Write-Host "========================================" -ForegroundColor Blue
Write-Host "AI-SDLC Events Service - Simple Deployment" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# Step 1: Clean up
Write-Host "Step 1: Cleaning up..." -ForegroundColor Yellow
& $PODMAN pod exists $POD_NAME 2>$null
if ($LASTEXITCODE -eq 0) {
    & $PODMAN pod rm -f $POD_NAME
}
Write-Host "✓ Cleanup complete" -ForegroundColor Green
Write-Host ""

# Step 2: Create pod
Write-Host "Step 2: Creating pod..." -ForegroundColor Yellow
& $PODMAN pod create --name $POD_NAME --publish "${APP_PORT}:8080"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to create pod" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Pod created" -ForegroundColor Green
Write-Host ""

# Step 3: PostgreSQL
Write-Host "Step 3: Starting PostgreSQL..." -ForegroundColor Yellow
& $PODMAN run -d `
  --pod $POD_NAME `
  --name $POSTGRES_CONTAINER `
  -e POSTGRES_DB=$DB_NAME `
  -e POSTGRES_USER=$DB_USER `
  -e POSTGRES_PASSWORD=$DB_PASSWORD `
  -e POSTGRES_HOST_AUTH_METHOD=trust `
  docker.io/library/postgres:16-alpine

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to start PostgreSQL" -ForegroundColor Red
    & $PODMAN pod rm -f $POD_NAME
    exit 1
}
Write-Host "✓ PostgreSQL started" -ForegroundColor Green
Write-Host ""

# Step 4: Wait for DB
Write-Host "Step 4: Waiting for PostgreSQL..." -ForegroundColor Yellow
Start-Sleep -Seconds 10
for ($i = 1; $i -le 30; $i++) {
    & $PODMAN exec $POSTGRES_CONTAINER pg_isready -U $DB_USER 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ PostgreSQL ready" -ForegroundColor Green
        break
    }
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 1
}
Write-Host ""
Write-Host ""

# Step 5: Build image using existing code
Write-Host "Step 5: Building application image with nginx proxy..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\.."

# Use Containerfile.fixed with nginx reverse proxy
& $PODMAN build -f deployment\docker\Containerfile.fixed -t ai-sdlc-events:latest .

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build image" -ForegroundColor Red
    Pop-Location
    & $PODMAN pod rm -f $POD_NAME
    exit 1
}

Pop-Location
Write-Host "✓ Image built" -ForegroundColor Green
Write-Host ""

# Step 6: Start app in PRODUCTION mode
Write-Host "Step 6: Starting application in PRODUCTION mode..." -ForegroundColor Yellow
& $PODMAN run -d `
  --pod $POD_NAME `
  --name $APP_CONTAINER `
  -e QUARKUS_PROFILE=prod `
  -e QUARKUS_LAUNCH_DEVMODE=false `
  -e QUARKUS_LIVE_RELOAD_ENABLED=false `
  -e QUARKUS_DATASOURCE_REACTIVE_URL="postgresql://localhost:5432/$DB_NAME" `
  -e QUARKUS_DATASOURCE_USERNAME=$DB_USER `
  -e QUARKUS_DATASOURCE_PASSWORD=$DB_PASSWORD `
  -e QUARKUS_DATASOURCE_JDBC_URL="jdbc:postgresql://localhost:5432/$DB_NAME" `
  ai-sdlc-events:latest

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to start application" -ForegroundColor Red
    & $PODMAN pod rm -f $POD_NAME
    exit 1
}
Write-Host "✓ Application started" -ForegroundColor Green
Write-Host ""

# Step 7: Wait
Write-Host "Step 7: Waiting for startup..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✓ Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Pod status:" -ForegroundColor Cyan
& $PODMAN pod ps --filter name=$POD_NAME
Write-Host ""
Write-Host "Access the application:" -ForegroundColor Cyan
Write-Host "  Dashboard:    http://localhost:$APP_PORT/dashboard/" -ForegroundColor White
Write-Host "  API Docs:     http://localhost:$APP_PORT/q/swagger-ui" -ForegroundColor White
Write-Host "  Health:       http://localhost:$APP_PORT/api/health/status" -ForegroundColor White
Write-Host ""
Write-Host "View logs: podman logs -f $APP_CONTAINER" -ForegroundColor Cyan
Write-Host ""
