# Phase 3: Worker Integration
# Integrates event emitter into worker script

$ErrorActionPreference = "Stop"

Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Phase 3: Worker Integration" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

$workerScript = "platform\scripts\homedir-sdlc-worker.sh"

# Check worker exists
if (-not (Test-Path $workerScript)) {
    Write-Host "ERROR: Worker script not found: $workerScript" -ForegroundColor Red
    exit 1
}

# Backup worker
$backupName = "$workerScript.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Host "Creating backup: $backupName" -ForegroundColor Yellow
Copy-Item $workerScript $backupName

Write-Host "✓ Backup created" -ForegroundColor Green
Write-Host ""

# Read current worker
$workerContent = Get-Content $workerScript -Raw

# Check if already integrated
if ($workerContent -match "event-emitter\.sh") {
    Write-Host "Event emitter already integrated in worker." -ForegroundColor Yellow
    Write-Host "Skipping integration step." -ForegroundColor Yellow
    Write-Host ""

    $response = Read-Host "Re-integrate anyway? (y/N)"
    if ($response -ne 'y') {
        Write-Host "Integration skipped." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Integrating event emitter..." -ForegroundColor Green

# Integration patch
$eventIntegration = @'

# ============================================================================
# Event System Integration
# ============================================================================

# Source event emitter
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/event-emitter.sh" ]]; then
  source "${SCRIPT_DIR}/event-emitter.sh"
  init_event_system
  log "INFO: Event system initialized"
else
  log "WARN: Event emitter not found, events disabled"
fi

# Helper function to safely emit events
safe_emit() {
  if type -t "$1" &>/dev/null; then
    "$@"
  fi
}

'@

# Find insertion point (after initial config, before main functions)
# Look for a good insertion point - typically after sourcing other scripts
$insertionMarker = "# Main worker functions"
if ($workerContent -notmatch [regex]::Escape($insertionMarker)) {
    # Try alternative markers
    $insertionMarker = "# Functions"
    if ($workerContent -notmatch [regex]::Escape($insertionMarker)) {
        $insertionMarker = "log()" # Insert before log function definition
    }
}

if ($workerContent -match [regex]::Escape($insertionMarker)) {
    $workerContent = $workerContent -replace [regex]::Escape($insertionMarker), "$eventIntegration`n$insertionMarker"
    Write-Host "✓ Event system integration added" -ForegroundColor Green
} else {
    Write-Host "⚠ Could not find insertion point, adding at top" -ForegroundColor Yellow
    # Add after shebang and initial comments
    $lines = $workerContent -split "`n"
    $insertIndex = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^#!/" -or $lines[$i] -match "^#[^!]" -or $lines[$i] -match "^$") {
            $insertIndex = $i + 1
        } else {
            break
        }
    }

    $newLines = $lines[0..$insertIndex] + $eventIntegration + $lines[($insertIndex + 1)..($lines.Count - 1)]
    $workerContent = $newLines -join "`n"
    Write-Host "✓ Event system integration added at line $insertIndex" -ForegroundColor Green
}

# Save modified worker
Set-Content -Path $workerScript -Value $workerContent -NoNewline

Write-Host ""
Write-Host "Worker script updated successfully." -ForegroundColor Green
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Review changes: git diff $workerScript" -ForegroundColor Gray
Write-Host "  2. Test locally: bash $workerScript --help" -ForegroundColor Gray
Write-Host "  3. If issues, restore: Copy-Item $backupName $workerScript" -ForegroundColor Gray
Write-Host ""

Write-Host "Note: This is minimal integration (initialization only)." -ForegroundColor Yellow
Write-Host "For full event emission, manually add emit_* calls per IMPLEMENTATION-ROADMAP.md" -ForegroundColor Yellow
Write-Host ""

Write-Host "=================================" -ForegroundColor Green
Write-Host "Phase 3: COMPLETED ✓" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
