# Phase 2: Event Infrastructure Setup
# PowerShell script to setup and test event infrastructure

$ErrorActionPreference = "Stop"

Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Phase 2: Event Infrastructure" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify files exist
Write-Host "Step 1: Verifying event system files..." -ForegroundColor Green

$requiredFiles = @(
    "platform\config\event-schema.json",
    "platform\scripts\event-emitter.sh",
    "test-event-system.sh"
)

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file MISSING" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Step 2: Make scripts executable (Git Bash)
Write-Host "Step 2: Making scripts executable..." -ForegroundColor Green

# In PowerShell, we'll verify they can be sourced by bash later
Write-Host "  Note: Scripts will be executed in Git Bash environment" -ForegroundColor Yellow
Write-Host ""

# Step 3: Run event system test
Write-Host "Step 3: Testing event system (Git Bash required)..." -ForegroundColor Green
Write-Host ""

$testScript = "bash test-event-system.sh"
Write-Host "  Running: $testScript" -ForegroundColor Cyan

$result = & bash test-event-system.sh 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=================================" -ForegroundColor Green
    Write-Host "Phase 2: COMPLETED ✓" -ForegroundColor Green
    Write-Host "=================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Event system is ready for worker integration." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next step: Phase 3 - Worker Integration" -ForegroundColor Cyan
    Write-Host "  Run: .\scripts\phase3-integrate.ps1" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "=================================" -ForegroundColor Red
    Write-Host "Phase 2: FAILED ✗" -ForegroundColor Red
    Write-Host "=================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Event system tests failed." -ForegroundColor Red
    Write-Host "Check test output above for errors." -ForegroundColor Red
    exit 1
}

# Show test output
Write-Host ""
Write-Host "Test output:" -ForegroundColor Cyan
Write-Host $result
