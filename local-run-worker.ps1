# AI-SDLC Local Worker Runner (PowerShell)

$ErrorActionPreference = "Stop"

Write-Host "=== AI-SDLC Local Worker ===" -ForegroundColor Green

# Check environment
if (!$env:GH_TOKEN) {
    Write-Host "ERROR: GH_TOKEN not set" -ForegroundColor Red
    exit 1
}

if (!$env:SC_API_KEY) {
    Write-Host "WARNING: SC_API_KEY not set (SCC won't work)" -ForegroundColor Yellow
}

# Detect container runtime
$ContainerCmd = $null
$SelinuxOpt = ""
if (Get-Command podman -ErrorAction SilentlyContinue) {
    $ContainerCmd = "podman"
    $SelinuxOpt = ":Z"
} elseif (Get-Command docker -ErrorAction SilentlyContinue) {
    $ContainerCmd = "docker"
} else {
    Write-Host "ERROR: Neither podman nor docker found" -ForegroundColor Red
    exit 1
}

# Prepare state
$StateDir = ".\local-state"
$LogsDir = ".\local-logs"

@("issues", "prs", "run-summaries", "autonomous-decisions") | ForEach-Object {
    New-Item -ItemType Directory -Force -Path "$StateDir\$_" | Out-Null
}
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null

# Create env file
$EnvContent = @"
HOMEDIR_SDLC_REPO=os-santiago/homedir
HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc
HOMEDIR_SDLC_WORKDIR=/srv/homedir-sdlc/worktrees/homedir
HOMEDIR_SDLC_LOGFILE=/var/log/homedir-sdlc/worker.log
HOMEDIR_SDLC_MAX_ISSUES_PER_RUN=1
HOMEDIR_SDLC_WORKER_VERSION=local-dev
GH_TOKEN=$env:GH_TOKEN
SC_API_KEY=$($env:SC_API_KEY)
PLATFORM_DIR=/app
"@

$EnvContent | Out-File -FilePath "$StateDir\runtime.env" -Encoding utf8

Write-Host "Running worker container..." -ForegroundColor Green

# Get absolute paths
$StatePath = (Resolve-Path $StateDir).Path
$LogsPath = (Resolve-Path $LogsDir).Path

# Run container
& $ContainerCmd run --rm `
  --user "1000:1000" `
  -e HOME=/tmp `
  --env-file "$StateDir\runtime.env" `
  -v "${StatePath}:/var/lib/homedir-sdlc${SelinuxOpt}" `
  -v "${LogsPath}:/var/log/homedir-sdlc${SelinuxOpt}" `
  homedir-ai-sdlc:local `
  reconcile

$ExitCode = $LASTEXITCODE

Write-Host ""
Write-Host "=== Worker Complete ===" -ForegroundColor Green
Write-Host "Exit code: $ExitCode"

# Show logs
$LogFile = "$LogsDir\worker.log"
if (Test-Path $LogFile) {
    Write-Host ""
    Write-Host "=== Last 30 Lines of Log ===" -ForegroundColor Green
    Get-Content $LogFile -Tail 30
}

# Show state
Write-Host ""
Write-Host "=== State Directory ===" -ForegroundColor Green
Get-ChildItem -Path $StateDir -Recurse -File |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-5) } |
    Select-Object -First 10 -ExpandProperty FullName

exit $ExitCode
