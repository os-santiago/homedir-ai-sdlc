# AI-SDLC E2E Test Monitor - Complete Verification and Tracking
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor Gray
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║         AI-SDLC E2E Test - Complete Monitoring            ║" -ForegroundColor Blue
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Blue

# ============================================================================
# STEP 1: Verify Prerequisites
# ============================================================================
Write-Step "Step 1: Verify Prerequisites"

if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI not found"
    exit 1
}
Write-Success "GitHub CLI available"

if (!$env:GH_TOKEN) {
    Write-Warning "GH_TOKEN not set, checking gh auth status"
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Not authenticated with GitHub"
        Write-Info "Run: gh auth login"
        exit 1
    }
}
Write-Success "GitHub authentication OK"

# ============================================================================
# STEP 2: Check Worker Status (if VPS accessible)
# ============================================================================
Write-Step "Step 2: Check Current Worker Status"

# Try to get heartbeat from VPS API
try {
    Write-Info "Checking VPS worker heartbeat..."
    $heartbeat = Invoke-RestMethod -Uri "http://vps:8081/api/sdlc/heartbeat" -TimeoutSec 3 -ErrorAction Stop
    Write-Success "Worker is alive"
    Write-Info "Last beat: $($heartbeat.last_beat)"
    Write-Info "Version: $($heartbeat.version)"

    $lastBeat = [DateTime]::Parse($heartbeat.last_beat)
    $age = (Get-Date) - $lastBeat
    if ($age.TotalMinutes -lt 5) {
        Write-Success "Heartbeat fresh (${age.TotalMinutes:N1} minutes old)"
    } else {
        Write-Warning "Heartbeat stale (${age.TotalMinutes:N1} minutes old)"
    }
} catch {
    Write-Warning "VPS not accessible (will use GitHub Actions)"
    Write-Info "Error: $($_.Exception.Message)"
}

# ============================================================================
# STEP 3: Select Issue for Test
# ============================================================================
Write-Step "Step 3: Select Test Issue"

Write-Info "Searching for suitable bug issues..."
$issues = gh issue list -R os-santiago/homedir `
    --label bug `
    --state open `
    --limit 10 `
    --json number,title,labels,createdAt,updatedAt |
    ConvertFrom-Json

if ($issues.Count -eq 0) {
    Write-Error "No open bug issues found"
    exit 1
}

Write-Info "Found $($issues.Count) open bug issues"

# Filter out already claimed/implementing issues
$availableIssues = $issues | Where-Object {
    $labels = $_.labels.name
    -not ($labels -contains "scc-claimed" -or
          $labels -contains "scc-implementing" -or
          $labels -contains "ready-to-implement")
}

if ($availableIssues.Count -eq 0) {
    Write-Warning "No unclaimed issues, using first available"
    $selectedIssue = $issues[0]
} else {
    # Pick oldest unclaimed issue
    $selectedIssue = $availableIssues | Sort-Object createdAt | Select-Object -First 1
}

Write-Success "Selected issue #$($selectedIssue.number)"
Write-Info "Title: $($selectedIssue.title)"
Write-Info "Created: $($selectedIssue.createdAt.Substring(0,10))"
Write-Info "Current labels: $($selectedIssue.labels.name -join ', ')"

$issueNumber = $selectedIssue.number

# ============================================================================
# STEP 4: Mark Issue for AI-SDLC
# ============================================================================
Write-Step "Step 4: Mark Issue for Processing"

Write-Info "Adding 'ready-to-implement' label..."
gh issue edit $issueNumber -R os-santiago/homedir --add-label "ready-to-implement" | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Success "Issue #$issueNumber marked for AI-SDLC"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Info "Marked at: $timestamp"
} else {
    Write-Error "Failed to mark issue"
    exit 1
}

# ============================================================================
# STEP 5: Trigger Workflow
# ============================================================================
Write-Step "Step 5: Trigger Autonomous Worker"

Write-Info "Starting GitHub Actions workflow..."
gh workflow run test-autonomous-worker.yml --ref main 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Success "Workflow triggered"
} else {
    Write-Error "Failed to trigger workflow"
    exit 1
}

Write-Info "Waiting for workflow to appear..."
Start-Sleep -Seconds 8

# Get the workflow run
$runs = gh run list --workflow=test-autonomous-worker.yml --limit 3 --json databaseId,status,createdAt,url | ConvertFrom-Json
$latestRun = $runs | Sort-Object createdAt -Descending | Select-Object -First 1

if (!$latestRun) {
    Write-Error "Could not find workflow run"
    exit 1
}

Write-Success "Workflow started"
Write-Info "Run ID: $($latestRun.databaseId)"
Write-Info "URL: $($latestRun.url)"

# ============================================================================
# STEP 6: Monitor Workflow Progress
# ============================================================================
Write-Step "Step 6: Monitor Workflow Execution"

Write-Info "Starting real-time monitoring..."
Write-Host ""

$startTime = Get-Date
$maxWaitMinutes = 25

while ($true) {
    $run = gh run view $latestRun.databaseId --json status,conclusion,createdAt,updatedAt | ConvertFrom-Json

    $elapsed = ((Get-Date) - $startTime).TotalMinutes

    Write-Host "`r  Status: $($run.status.PadRight(15)) | Elapsed: $($elapsed.ToString('0.0'))m / ${maxWaitMinutes}m " -NoNewline

    if ($run.status -eq "completed") {
        Write-Host ""
        Write-Host ""
        if ($run.conclusion -eq "success") {
            Write-Success "Workflow completed successfully"
        } elseif ($run.conclusion -eq "failure") {
            Write-Error "Workflow failed"
        } else {
            Write-Warning "Workflow completed with: $($run.conclusion)"
        }
        break
    }

    if ($elapsed -gt $maxWaitMinutes) {
        Write-Host ""
        Write-Warning "Timeout reached (${maxWaitMinutes}m), workflow still running"
        Write-Info "Continue watching: gh run watch $($latestRun.databaseId)"
        break
    }

    Start-Sleep -Seconds 10
}

# ============================================================================
# STEP 7: Verify Issue Labels Updated
# ============================================================================
Write-Step "Step 7: Verify Issue Label Changes"

Start-Sleep -Seconds 3

$updatedIssue = gh issue view $issueNumber -R os-santiago/homedir --json number,labels,updatedAt | ConvertFrom-Json
$currentLabels = $updatedIssue.labels.name

Write-Info "Current labels on issue #${issueNumber}:"
foreach ($label in $currentLabels) {
    if ($label -like "scc-*" -or $label -eq "ready-to-implement") {
        Write-Host "  • $label" -ForegroundColor Yellow
    } else {
        Write-Host "  • $label" -ForegroundColor Gray
    }
}

# Check expected label progression
$expectedFlow = @(
    @{Label="ready-to-implement"; Description="Issue marked for processing"},
    @{Label="scc-claimed"; Description="Worker claimed the issue"},
    @{Label="scc-implementing"; Description="SCC generating code"},
    @{Label="scc-implemented"; Description="PR created"},
    @{Label="scc-merged"; Description="PR merged to production"}
)

Write-Host ""
Write-Info "Expected label flow:"
foreach ($step in $expectedFlow) {
    $hasLabel = $currentLabels -contains $step.Label
    if ($hasLabel) {
        Write-Host "  ✓ $($step.Label) - $($step.Description)" -ForegroundColor Green
    } else {
        Write-Host "  ○ $($step.Label) - $($step.Description)" -ForegroundColor Gray
    }
}

# ============================================================================
# STEP 8: Check for PR Created
# ============================================================================
Write-Step "Step 8: Check for Pull Request"

Write-Info "Searching for PR related to issue #${issueNumber}..."
$prs = gh pr list -R os-santiago/homedir --search "$issueNumber" --limit 5 --json number,title,url,state,labels | ConvertFrom-Json

if ($prs.Count -gt 0) {
    Write-Success "Found $($prs.Count) PR(s)"
    foreach ($pr in $prs) {
        Write-Host ""
        Write-Host "  PR #$($pr.number): $($pr.title)" -ForegroundColor Cyan
        Write-Host "  State: $($pr.state)" -ForegroundColor $(if ($pr.state -eq "MERGED") {"Green"} elseif ($pr.state -eq "OPEN") {"Yellow"} else {"Gray"})
        Write-Host "  URL: $($pr.url)" -ForegroundColor Gray

        $prLabels = $pr.labels.name
        if ($prLabels -contains "scc-merged") {
            Write-Success "  Status: Merged and deployed"
        } elseif ($prLabels -contains "scc-implemented") {
            Write-Info "  Status: Implemented, awaiting merge"
        }
    }
} else {
    Write-Warning "No PR found yet"
    Write-Info "This could mean:"
    Write-Info "  • Worker is still processing"
    Write-Info "  • Issue was rejected in admission review"
    Write-Info "  • SCC implementation failed"
}

# ============================================================================
# STEP 9: Show Workflow Logs
# ============================================================================
Write-Step "Step 9: Workflow Execution Logs"

Write-Info "Fetching workflow logs..."
$logs = gh run view $latestRun.databaseId --log 2>&1 | Out-String

# Extract key events
$keyEvents = @()
if ($logs -match "Claimed issue") { $keyEvents += "✓ Issue claimed" }
if ($logs -match "Admission review.*ACCEPT") { $keyEvents += "✓ Admission review: ACCEPTED" }
if ($logs -match "Admission review.*REJECT") { $keyEvents += "✗ Admission review: REJECTED" }
if ($logs -match "Cloning repository") { $keyEvents += "✓ Repository cloned" }
if ($logs -match "Created PR") { $keyEvents += "✓ PR created" }
if ($logs -match "ERROR") { $keyEvents += "✗ Errors encountered" }

if ($keyEvents.Count -gt 0) {
    Write-Info "Key events detected:"
    foreach ($event in $keyEvents) {
        Write-Host "  $event"
    }
} else {
    Write-Warning "No key events found in logs"
}

Write-Host ""
Write-Info "View full logs:"
Write-Host "  gh run view $($latestRun.databaseId) --log" -ForegroundColor Gray

# ============================================================================
# STEP 10: Check Dashboard Metrics (if available)
# ============================================================================
Write-Step "Step 10: Dashboard Metrics"

try {
    Write-Info "Fetching dashboard snapshot..."
    $snapshot = Invoke-RestMethod -Uri "http://vps:8081/api/sdlc/snapshot" -TimeoutSec 5 -ErrorAction Stop

    Write-Success "Dashboard accessible"
    Write-Info "Active issues: $($snapshot.active_issues_count)"
    Write-Info "Active PRs: $($snapshot.active_prs_count)"
    Write-Info "Autonomy rate: $($snapshot.autonomy_percentage)%"

    if ($snapshot.anomalies -and $snapshot.anomalies.Count -gt 0) {
        Write-Warning "Anomalies detected: $($snapshot.anomalies.Count)"
        foreach ($anomaly in $snapshot.anomalies | Select-Object -First 3) {
            Write-Host "  • $($anomaly.type): $($anomaly.description)" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Warning "Dashboard not accessible"
    Write-Info "Dashboard URL: http://vps:8081/sdlc/dashboard/"
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║                    E2E Test Summary                        ║" -ForegroundColor Blue
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Blue

Write-Host ""
Write-Host "Issue: #$issueNumber - $($selectedIssue.title)" -ForegroundColor Cyan
Write-Host "Workflow: $($latestRun.url)" -ForegroundColor Cyan

Write-Host ""
Write-Host "Current State:" -ForegroundColor White
$hasClaimed = $currentLabels -contains "scc-claimed"
$hasImplemented = $currentLabels -contains "scc-implemented"
$hasMerged = $currentLabels -contains "scc-merged"
$hasPR = $prs.Count -gt 0

if ($hasMerged) {
    Write-Success "COMPLETE: Issue processed, PR merged, deployed to production"
} elseif ($hasImplemented -and $hasPR) {
    Write-Success "IMPLEMENTED: PR created, awaiting merge"
} elseif ($hasClaimed) {
    Write-Info "IN PROGRESS: Worker is processing the issue"
} else {
    Write-Warning "PENDING: Issue marked but not yet claimed"
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor White
Write-Host "  • Monitor issue: gh issue view $issueNumber -R os-santiago/homedir" -ForegroundColor Gray
Write-Host "  • View workflow: $($latestRun.url)" -ForegroundColor Gray
if ($hasPR) {
    Write-Host "  • Review PR: $($prs[0].url)" -ForegroundColor Gray
}
Write-Host "  • Dashboard: http://vps:8081/sdlc/dashboard/" -ForegroundColor Gray

$totalMinutes = ((Get-Date) - $startTime).TotalMinutes
Write-Host ""
Write-Host "Total execution time: $($totalMinutes.ToString('0.0')) minutes" -ForegroundColor Gray
Write-Host ""
