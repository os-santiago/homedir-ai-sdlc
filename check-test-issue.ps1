# Check Test Issue Status
$ErrorActionPreference = "Stop"

Write-Host "Checking AI-SDLC test issue status..." -ForegroundColor Cyan
Write-Host ""

# Check latest workflow run
Write-Host "Latest workflow runs:" -ForegroundColor Green
$runs = gh run list --workflow=test-autonomous-worker.yml --limit 3 --json databaseId,createdAt,conclusion,displayTitle | ConvertFrom-Json

foreach ($run in $runs) {
    $created = ([DateTime]::Parse($run.createdAt)).ToString('yyyy-MM-dd HH:mm')
    Write-Host "  • Run $($run.databaseId): $($run.conclusion) - $created" -ForegroundColor $(if ($run.conclusion -eq "success") {"Green"} else {"Yellow"})
    Write-Host "    Title: $($run.displayTitle)" -ForegroundColor Gray
}

Write-Host ""

# Check for issues with SCC labels
Write-Host "Issues processed by AI-SDLC:" -ForegroundColor Green
$sccIssues = gh issue list -R os-santiago/homedir --label scc-claimed --limit 10 --json number,title,labels,state,createdAt | ConvertFrom-Json

if ($sccIssues.Count -eq 0) {
    Write-Host "  No issues with scc-claimed label found" -ForegroundColor Yellow

    # Check for ready-to-implement
    Write-Host ""
    Write-Host "Issues marked ready-to-implement:" -ForegroundColor Green
    $readyIssues = gh issue list -R os-santiago/homedir --label ready-to-implement --limit 5 --json number,title,labels,state | ConvertFrom-Json

    foreach ($issue in $readyIssues) {
        Write-Host "  • #$($issue.number): $($issue.title)" -ForegroundColor Cyan
        Write-Host "    Labels: $($issue.labels.name -join ', ')" -ForegroundColor Gray
        Write-Host "    State: $($issue.state)" -ForegroundColor Gray
    }
} else {
    foreach ($issue in $sccIssues) {
        $labelNames = $issue.labels.name
        $hasMerged = $labelNames -contains "scc-merged"
        $hasImplemented = $labelNames -contains "scc-implemented"

        $status = if ($hasMerged) {
            "MERGED (Prod)"
        } elseif ($hasImplemented) {
            "IMPLEMENTED (PR created)"
        } else {
            "IN PROGRESS"
        }

        $color = if ($hasMerged) {"Green"} elseif ($hasImplemented) {"Cyan"} else {"Yellow"}

        $created = ([DateTime]::Parse($issue.createdAt)).ToString('yyyy-MM-dd')
        Write-Host "  • #$($issue.number): $($issue.title)" -ForegroundColor $color
        Write-Host "    Status: $status" -ForegroundColor $color
        Write-Host "    Created: $created" -ForegroundColor Gray
        Write-Host "    Labels: $($labelNames -join ', ')" -ForegroundColor Gray

        # Check for PR
        $prs = gh pr list -R os-santiago/homedir --search "$($issue.number)" --limit 1 --json number,state,url | ConvertFrom-Json
        if ($prs.Count -gt 0) {
            Write-Host "    PR: #$($prs[0].number) - $($prs[0].state)" -ForegroundColor Gray
            Write-Host "    URL: $($prs[0].url)" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

# Check specific test issues mentioned in docs
Write-Host ""
Write-Host "Checking specific test issues:" -ForegroundColor Green

$testIssues = @(1032, 1306)

foreach ($issueNum in $testIssues) {
    try {
        $issue = gh issue view $issueNum -R os-santiago/homedir --json number,title,labels,state,closedAt | ConvertFrom-Json

        $labelNames = $issue.labels.name
        $hasSCC = ($labelNames | Where-Object { $_ -like "scc-*" }).Count -gt 0

        if ($hasSCC) {
            Write-Host "  #$issueNum`: $($issue.title)" -ForegroundColor Cyan
            Write-Host "    State: $($issue.state)" -ForegroundColor Gray
            Write-Host "    SCC Labels: $($labelNames | Where-Object { $_ -like 'scc-*' } | Join-String -Separator ', ')" -ForegroundColor Yellow

            # Check PR
            $prs = gh pr list -R os-santiago/homedir --search "$issueNum" --limit 1 --json number,state,url,mergedAt | ConvertFrom-Json
            if ($prs.Count -gt 0) {
                Write-Host "    PR #$($prs[0].number): $($prs[0].state)" -ForegroundColor $(if ($prs[0].state -eq "MERGED") {"Green"} else {"Yellow"})
                if ($prs[0].mergedAt) {
                    $merged = ([DateTime]::Parse($prs[0].mergedAt)).ToString('yyyy-MM-dd HH:mm')
                    Write-Host "    Merged: $merged" -ForegroundColor Green
                }
                Write-Host "    URL: $($prs[0].url)" -ForegroundColor Gray
            }
            Write-Host ""
        }
    } catch {
        # Issue doesn't exist or not accessible
    }
}

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  To see full workflow history:" -ForegroundColor Gray
Write-Host "    gh run list --workflow=test-autonomous-worker.yml" -ForegroundColor Gray
Write-Host "  To watch a specific issue:" -ForegroundColor Gray
Write-Host "    .\watch-workflow.ps1 -IssueNumber <number>" -ForegroundColor Gray
