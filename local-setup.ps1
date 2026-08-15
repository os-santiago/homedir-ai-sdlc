# AI-SDLC Local Setup (PowerShell)
param(
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

Write-Host "=== AI-SDLC Local Setup ===" -ForegroundColor Blue
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Green

# Check container runtime
$ContainerCmd = $null
if (Get-Command podman -ErrorAction SilentlyContinue) {
    $ContainerCmd = "podman"
    Write-Host "✓ Podman: $(podman --version)" -ForegroundColor Green
} elseif (Get-Command docker -ErrorAction SilentlyContinue) {
    $ContainerCmd = "docker"
    Write-Host "✓ Docker: $(docker --version)" -ForegroundColor Green
} else {
    Write-Host "ERROR: Neither podman nor docker found" -ForegroundColor Red
    Write-Host "Install Podman Desktop or Docker Desktop first"
    exit 1
}

# Check gh CLI
if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "WARNING: GitHub CLI not found" -ForegroundColor Yellow
    Write-Host "Install from: https://cli.github.com/"
} else {
    Write-Host "✓ GitHub CLI: $(gh --version | Select-Object -First 1)" -ForegroundColor Green
}

# Check environment variables
Write-Host ""
Write-Host "Checking environment variables..." -ForegroundColor Green

if (!$env:GH_TOKEN) {
    Write-Host "WARNING: GH_TOKEN not set" -ForegroundColor Yellow
    Write-Host "Set it with: `$env:GH_TOKEN='your-token'"
} else {
    Write-Host "✓ GH_TOKEN set" -ForegroundColor Green
}

if (!$env:SC_API_KEY) {
    Write-Host "WARNING: SC_API_KEY not set" -ForegroundColor Yellow
    Write-Host "Without it, SCC won't work but you can test infrastructure"
} else {
    Write-Host "✓ SC_API_KEY set" -ForegroundColor Green
}

# Create directory structure
Write-Host ""
Write-Host "Creating local directories..." -ForegroundColor Green

$StateDir = ".\local-state"
$LogsDir = ".\local-logs"

@("issues", "prs", "run-summaries", "autonomous-decisions") | ForEach-Object {
    New-Item -ItemType Directory -Force -Path "$StateDir\$_" | Out-Null
}
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null

Write-Host "✓ Created: $StateDir" -ForegroundColor Green
Write-Host "✓ Created: $LogsDir" -ForegroundColor Green

# Build image
if (!$SkipBuild) {
    Write-Host ""
    Write-Host "Building worker image..." -ForegroundColor Green

    & $ContainerCmd build -f container/Containerfile.worker -t homedir-ai-sdlc:local .

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Image build failed" -ForegroundColor Red
        exit 1
    }

    Write-Host "✓ Image built successfully" -ForegroundColor Green
}

# Verify image
Write-Host ""
Write-Host "Verifying image..." -ForegroundColor Green
& $ContainerCmd images | Select-String "homedir-ai-sdlc"

# Summary
Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Blue
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Mark an issue: .\local-mark-issue.ps1 <issue-number>"
Write-Host "  2. Run worker: .\local-run-worker.ps1"
Write-Host ""
Write-Host "Examples:"
Write-Host "  .\local-mark-issue.ps1 1360"
Write-Host "  .\local-run-worker.ps1"
Write-Host ""
Write-Host "Logs will be in: $LogsDir\worker.log"
Write-Host "State will be in: $StateDir\"
