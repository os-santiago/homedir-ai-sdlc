# Mark issue for AI-SDLC (PowerShell)
param(
    [Parameter(Mandatory=$true)]
    [int]$IssueNumber
)

$ErrorActionPreference = "Stop"

if (!$env:GH_TOKEN) {
    Write-Host "ERROR: GH_TOKEN not set" -ForegroundColor Red
    exit 1
}

Write-Host "Marking issue #$IssueNumber for AI-SDLC..." -ForegroundColor Green

gh issue edit $IssueNumber `
  -R os-santiago/homedir `
  --add-label "ready-to-implement"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Issue #$IssueNumber marked" -ForegroundColor Green
    Write-Host ""
    Write-Host "Now run: .\local-run-worker.ps1"
} else {
    Write-Host "ERROR: Failed to mark issue" -ForegroundColor Red
    exit 1
}
