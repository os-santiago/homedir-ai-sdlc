# Run AI-SDLC E2E Test via GitHub Actions
param(
    [int]$IssueNumber
)

$ErrorActionPreference = "Stop"

Write-Host "=== AI-SDLC E2E Test ===" -ForegroundColor Blue
Write-Host ""

# Find a suitable issue if not provided
if (!$IssueNumber) {
    Write-Host "Searching for open bug issues..." -ForegroundColor Green
    $issues = gh issue list -R os-santiago/homedir --label bug --state open --limit 5 --json number,title,createdAt | ConvertFrom-Json

    if ($issues.Count -eq 0) {
        Write-Host "No open bug issues found" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "Available issues:" -ForegroundColor Cyan
    foreach ($issue in $issues) {
        $created = $issue.createdAt.Substring(0, 10)
        Write-Host "  $($issue.number): $($issue.title) (created: $created)"
    }

    $IssueNumber = $issues[0].number
    Write-Host ""
    Write-Host "Using issue #$IssueNumber" -ForegroundColor Green
}

# Mark issue for AI-SDLC
Write-Host ""
Write-Host "Marking issue #$IssueNumber for AI-SDLC..." -ForegroundColor Green
gh issue edit $IssueNumber -R os-santiago/homedir --add-label "ready-to-implement"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to mark issue" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Issue marked" -ForegroundColor Green

# Trigger workflow
Write-Host ""
Write-Host "Triggering autonomous worker test..." -ForegroundColor Green
$runUrl = gh workflow run test-autonomous-worker.yml --ref main 2>&1 | Out-String

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to trigger workflow" -ForegroundColor Red
    Write-Host $runUrl
    exit 1
}

Write-Host "✓ Workflow triggered" -ForegroundColor Green

# Wait a moment for run to appear
Write-Host ""
Write-Host "Waiting for workflow to start..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

# Get latest run
$run = gh run list --workflow=test-autonomous-worker.yml --limit 1 --json databaseId,status,conclusion,url | ConvertFrom-Json | Select-Object -First 1

if (!$run) {
    Write-Host "ERROR: Could not find workflow run" -ForegroundColor Red
    exit 1
}

Write-Host "Workflow started: $($run.url)" -ForegroundColor Green
Write-Host ""
Write-Host "Watching workflow..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop watching (workflow will continue running)"
Write-Host ""

# Watch the run
gh run watch $run.databaseId

# Get final status
$finalRun = gh run view $run.databaseId --json status,conclusion,url | ConvertFrom-Json

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Blue
Write-Host "Status: $($finalRun.status)" -ForegroundColor $(if ($finalRun.conclusion -eq "success") { "Green" } else { "Red" })
Write-Host "URL: $($finalRun.url)"

# Check for PR created
Write-Host ""
Write-Host "Checking for PR created..." -ForegroundColor Green
Start-Sleep -Seconds 3

$prs = gh pr list -R os-santiago/homedir --search "$IssueNumber" --limit 3 --json number,title,url | ConvertFrom-Json

if ($prs.Count -gt 0) {
    Write-Host "✓ PR(s) found:" -ForegroundColor Green
    foreach ($pr in $prs) {
        Write-Host "  #$($pr.number): $($pr.title)"
        Write-Host "  $($pr.url)"
    }
} else {
    Write-Host "No PR found yet (may still be in progress)" -ForegroundColor Yellow
}

# Show logs
Write-Host ""
Write-Host "View full logs:" -ForegroundColor Cyan
Write-Host "  gh run view $($run.databaseId) --log"

if ($finalRun.conclusion -eq "success") {
    exit 0
} else {
    exit 1
}
