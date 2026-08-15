# Run All Phases - Complete Event System Setup
# Executes all phases sequentially

param(
    [switch]$SkipPhase2,
    [switch]$SkipPhase3,
    [switch]$BuildOnly
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║     AI-SDLC Event System - Complete Setup                 ║" -ForegroundColor Blue
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

$phases = @()

if (-not $SkipPhase2) {
    $phases += @{
        Number = 2
        Name = "Event Infrastructure"
        Script = ".\scripts\phase2-setup.ps1"
        Description = "Test event system standalone"
    }
}

if (-not $SkipPhase3) {
    $phases += @{
        Number = 3
        Name = "Worker Integration"
        Script = ".\scripts\phase3-integrate.ps1"
        Description = "Integrate events into worker"
    }
}

$phases += @{
    Number = 5
    Name = "API Layer"
    Script = ".\scripts\phase5-deploy-api.ps1"
    Description = "Build Java REST API"
}

if (-not $BuildOnly) {
    $phases += @{
        Number = 6
        Name = "Dashboard UI"
        Script = ".\scripts\phase6-deploy-dashboard.ps1"
        Description = "Deploy web dashboard"
    }
}

Write-Host "Execution Plan:" -ForegroundColor Cyan
foreach ($phase in $phases) {
    Write-Host "  Phase $($phase.Number): $($phase.Name)" -ForegroundColor White
    Write-Host "    → $($phase.Description)" -ForegroundColor Gray
}
Write-Host ""

$response = Read-Host "Continue with execution? (Y/n)"
if ($response -eq 'n') {
    Write-Host "Aborted by user." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Execute phases
$completedPhases = @()
$failedPhase = $null

foreach ($phase in $phases) {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "  PHASE $($phase.Number): $($phase.Name)" -ForegroundColor Blue
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""

    try {
        & $phase.Script

        if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
            $completedPhases += $phase
            Write-Host ""
            Write-Host "✓ Phase $($phase.Number) completed successfully" -ForegroundColor Green

            # Pause before next phase (except for last)
            if ($phase -ne $phases[-1]) {
                Write-Host ""
                Write-Host "Press Enter to continue to next phase..." -ForegroundColor Yellow
                Read-Host
            }
        } else {
            throw "Phase $($phase.Number) failed with exit code $LASTEXITCODE"
        }
    } catch {
        $failedPhase = $phase
        Write-Host ""
        Write-Host "✗ Phase $($phase.Number) failed: $_" -ForegroundColor Red
        break
    }
}

# Summary
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║                    Execution Summary                       ║" -ForegroundColor Blue
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

Write-Host "Completed Phases:" -ForegroundColor Green
foreach ($phase in $completedPhases) {
    Write-Host "  ✓ Phase $($phase.Number): $($phase.Name)" -ForegroundColor Green
}

if ($failedPhase) {
    Write-Host ""
    Write-Host "Failed Phase:" -ForegroundColor Red
    Write-Host "  ✗ Phase $($failedPhase.Number): $($failedPhase.Name)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Review errors above and re-run individual phase:" -ForegroundColor Yellow
    Write-Host "  $($failedPhase.Script)" -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Host "All phases completed successfully! 🎉" -ForegroundColor Green
Write-Host ""

if ($BuildOnly) {
    Write-Host "Build-only mode: Dashboard not started" -ForegroundColor Yellow
    Write-Host "To start dashboard:" -ForegroundColor Cyan
    Write-Host "  cd dashboard\quarkus-app" -ForegroundColor Gray
    Write-Host "  ./mvnw quarkus:dev" -ForegroundColor Gray
} else {
    Write-Host "Dashboard should now be running at:" -ForegroundColor Cyan
    Write-Host "  http://localhost:8081/sdlc/events/" -ForegroundColor White
}
