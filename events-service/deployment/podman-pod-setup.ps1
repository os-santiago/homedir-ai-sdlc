# AI-SDLC Events Service - Podman Pod Setup (PowerShell)
# Creates a pod with PostgreSQL and AI-SDLC containers

# Podman path
$PODMAN = "C:\Users\sergi\AppData\Local\Programs\Podman\podman.exe"

# Configuration
$POD_NAME = "ai-sdlc-events-pod"
$POSTGRES_CONTAINER = "ai-sdlc-postgres"
$APP_CONTAINER = "ai-sdlc-app"
$DB_NAME = "aisdlc"
$DB_USER = "aisdlc"
$DB_PASSWORD = "aisdlc"
$APP_PORT = 8080

Write-Host "========================================" -ForegroundColor Blue
Write-Host "AI-SDLC Events Service - Pod Setup" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# Step 1: Stop and remove existing pod if exists
Write-Host "Step 1: Cleaning up existing pod..." -ForegroundColor Yellow
& $PODMAN pod exists $POD_NAME
if ($LASTEXITCODE -eq 0) {
    & $PODMAN pod rm -f $POD_NAME
    Write-Host "Removed existing pod" -ForegroundColor Green
} else {
    Write-Host "No existing pod found" -ForegroundColor Gray
}
Write-Host ""

# Step 2: Create pod
Write-Host "Step 2: Creating pod '$POD_NAME'..." -ForegroundColor Yellow
& $PODMAN pod create `
  --name $POD_NAME `
  --publish "${APP_PORT}:8080"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to create pod" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Pod created" -ForegroundColor Green
Write-Host ""

# Step 3: Start PostgreSQL container
Write-Host "Step 3: Starting PostgreSQL container..." -ForegroundColor Yellow
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
Write-Host "✓ PostgreSQL container started" -ForegroundColor Green
Write-Host ""

# Step 4: Wait for PostgreSQL to be ready
Write-Host "Step 4: Waiting for PostgreSQL to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
$ready = $false
for ($i = 1; $i -le 30; $i++) {
    & $PODMAN exec $POSTGRES_CONTAINER pg_isready -U $DB_USER 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ PostgreSQL is ready" -ForegroundColor Green
        $ready = $true
        break
    }
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 1
}
Write-Host ""

if (-not $ready) {
    Write-Host "PostgreSQL failed to start" -ForegroundColor Red
    & $PODMAN pod rm -f $POD_NAME
    exit 1
}

# Step 5: Build AI-SDLC application image
Write-Host "Step 5: Building AI-SDLC application image..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\.."

# Package application
Write-Host "Packaging application..." -ForegroundColor Gray
.\mvnw.cmd clean package -DskipTests

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to package application" -ForegroundColor Red
    Pop-Location
    & $PODMAN pod rm -f $POD_NAME
    exit 1
}

# Build container image
Write-Host "Building container image..." -ForegroundColor Gray
& $PODMAN build -f deployment\docker\Containerfile -t ai-sdlc-events:latest .

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build image" -ForegroundColor Red
    Pop-Location
    & $PODMAN pod rm -f $POD_NAME
    exit 1
}

Pop-Location
Write-Host "✓ Application image built" -ForegroundColor Green
Write-Host ""

# Step 6: Start AI-SDLC application container
Write-Host "Step 6: Starting AI-SDLC application container..." -ForegroundColor Yellow
& $PODMAN run -d `
  --pod $POD_NAME `
  --name $APP_CONTAINER `
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
Write-Host "✓ Application container started" -ForegroundColor Green
Write-Host ""

# Step 7: Wait for application to be ready
Write-Host "Step 7: Waiting for application to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10
$ready = $false
for ($i = 1; $i -le 60; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$APP_PORT/api/health/live" -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "✓ Application is ready" -ForegroundColor Green
            $ready = $true
            break
        }
    } catch {
        # Continue waiting
    }
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 1
}
Write-Host ""

if (-not $ready) {
    Write-Host "Warning: Application may not be ready yet" -ForegroundColor Yellow
}

# Step 8: Verify deployment
Write-Host "Step 8: Verifying deployment..." -ForegroundColor Yellow
Write-Host ""

# Check pod status
Write-Host "Pod status:" -ForegroundColor Cyan
& $PODMAN pod ps --filter name=$POD_NAME
Write-Host ""

# Check containers
Write-Host "Containers in pod:" -ForegroundColor Cyan
& $PODMAN ps --filter pod=$POD_NAME
Write-Host ""

# Check health
Write-Host "Application health:" -ForegroundColor Cyan
try {
    $health = Invoke-RestMethod -Uri "http://localhost:$APP_PORT/api/health/status" -UseBasicParsing
    $health | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Health endpoint not ready yet" -ForegroundColor Yellow
}
Write-Host ""

# Success message
Write-Host "========================================" -ForegroundColor Green
Write-Host "✓ Pod deployment completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Access the application:" -ForegroundColor Cyan
Write-Host "  Dashboard:    http://localhost:$APP_PORT/dashboard/" -ForegroundColor White
Write-Host "  API Docs:     http://localhost:$APP_PORT/q/swagger-ui" -ForegroundColor White
Write-Host "  Health:       http://localhost:$APP_PORT/api/health/status" -ForegroundColor White
Write-Host "  Metrics:      http://localhost:$APP_PORT/q/metrics" -ForegroundColor White
Write-Host ""
Write-Host "Manage the pod:" -ForegroundColor Cyan
Write-Host "  View logs:    podman logs -f $APP_CONTAINER" -ForegroundColor White
Write-Host "  Stop pod:     podman pod stop $POD_NAME" -ForegroundColor White
Write-Host "  Start pod:    podman pod start $POD_NAME" -ForegroundColor White
Write-Host "  Remove pod:   podman pod rm -f $POD_NAME" -ForegroundColor White
Write-Host ""
Write-Host "Test the API:" -ForegroundColor Cyan
Write-Host @"
  curl -X POST http://localhost:$APP_PORT/internal/events/issue-detected \
    -H "Content-Type: application/json" \
    -d '{"issueNumber": 1000, "metadata": {"title": "Test"}}' | jq
"@ -ForegroundColor White
Write-Host ""
