# AI-SDLC Workflow Visualizer - Live Status Monitor
param(
    [Parameter(Mandatory=$true)]
    [int]$IssueNumber,

    [switch]$Continuous
)

$ErrorActionPreference = "Stop"

# Box drawing characters
$box = @{
    TL = "╔"; TR = "╗"; BL = "╚"; BR = "╝"
    H = "═"; V = "║"; VR = "╠"; VL = "╣"
    HU = "╩"; HD = "╦"; CROSS = "╬"
    TLR = "┌"; TRR = "┐"; BLR = "└"; BRR = "┘"
    HR = "─"; VR2 = "│"; VRR = "├"; VLR = "┤"
    HUR = "┴"; HDR = "┬"; CROSSR = "┼"
    ARROW = "▶"; CHECK = "✓"; CROSS_X = "✗"; DOT = "●"; CIRCLE = "○"
}

function Get-IssueData {
    param([int]$Number)

    $data = gh issue view $Number -R os-santiago/homedir --json number,title,state,labels,createdAt,updatedAt,comments | ConvertFrom-Json
    return $data
}

function Get-PRData {
    param([int]$IssueNumber)

    $prs = gh pr list -R os-santiago/homedir --search "$IssueNumber" --limit 5 --json number,title,url,state,labels,createdAt,updatedAt,mergeable,mergedAt | ConvertFrom-Json
    return $prs
}

function Get-WorkflowStage {
    param([array]$Labels)

    $labelNames = $Labels.name

    if ($labelNames -contains "scc-merged") {
        return @{
            Stage = 6
            Name = "MERGED"
            Description = "Deployed to production"
            Color = "Green"
            Icon = $box.CHECK
        }
    } elseif ($labelNames -contains "scc-implemented") {
        return @{
            Stage = 5
            Name = "IMPLEMENTED"
            Description = "PR created, awaiting merge"
            Color = "Cyan"
            Icon = $box.ARROW
        }
    } elseif ($labelNames -contains "scc-implementing") {
        return @{
            Stage = 4
            Name = "IMPLEMENTING"
            Description = "SCC generating code"
            Color = "Yellow"
            Icon = $box.DOT
        }
    } elseif ($labelNames -contains "scc-claimed") {
        return @{
            Stage = 3
            Name = "CLAIMED"
            Description = "Worker processing"
            Color = "Yellow"
            Icon = $box.DOT
        }
    } elseif ($labelNames -contains "ready-to-implement") {
        return @{
            Stage = 2
            Name = "READY"
            Description = "Queued for processing"
            Color = "White"
            Icon = $box.CIRCLE
        }
    } else {
        return @{
            Stage = 1
            Name = "PENDING"
            Description = "Not yet marked"
            Color = "Gray"
            Icon = $box.CIRCLE
        }
    }
}

function Draw-Header {
    param([string]$Title)

    $width = 80
    $padding = [math]::Floor(($width - $Title.Length - 2) / 2)
    $line = $box.H * $width

    Write-Host ""
    Write-Host "$($box.TL)$line$($box.TR)" -ForegroundColor Blue
    Write-Host "$($box.V)$(' ' * $padding)$Title$(' ' * ($width - $padding - $Title.Length))$($box.V)" -ForegroundColor Blue
    Write-Host "$($box.BL)$line$($box.BR)" -ForegroundColor Blue
    Write-Host ""
}

function Draw-WorkflowPipeline {
    param(
        [int]$CurrentStage,
        [object]$IssueData,
        [array]$PRData
    )

    $stages = @(
        @{Name="PENDING"; Desc="Issue created"; Stage=1},
        @{Name="READY"; Desc="Marked for AI-SDLC"; Stage=2},
        @{Name="CLAIMED"; Desc="Worker claimed"; Stage=3},
        @{Name="IMPLEMENTING"; Desc="SCC generating"; Stage=4},
        @{Name="IMPLEMENTED"; Desc="PR created"; Stage=5},
        @{Name="MERGED"; Desc="Deployed"; Stage=6}
    )

    # Draw top border
    $topBorder = "$($box.TLR)" + ($box.HR * 12)
    for ($i = 1; $i -lt $stages.Count; $i++) {
        $topBorder += "$($box.HDR)" + ($box.HR * 12)
    }
    $topBorder += "$($box.TRR)"
    Write-Host $topBorder -ForegroundColor DarkGray

    # Draw stage names
    $stageLine = ""
    foreach ($stage in $stages) {
        $padding = [math]::Floor((12 - $stage.Name.Length) / 2)
        $name = (' ' * $padding) + $stage.Name + (' ' * (12 - $padding - $stage.Name.Length))

        if ($stage.Stage -eq $CurrentStage) {
            $stageLine += "$($box.VR2)" + "$name"
        } elseif ($stage.Stage -lt $CurrentStage) {
            $stageLine += "$($box.VR2)" + "$name"
        } else {
            $stageLine += "$($box.VR2)" + "$name"
        }
    }
    $stageLine += "$($box.VR2)"

    # Color code by stage
    for ($i = 0; $i -lt $stages.Count; $i++) {
        $start = 1 + ($i * 13)
        $len = 12
        $color = "Gray"
        $char = $box.CIRCLE

        if ($stages[$i].Stage -lt $CurrentStage) {
            $color = "Green"
            $char = $box.CHECK
        } elseif ($stages[$i].Stage -eq $CurrentStage) {
            $color = "Yellow"
            $char = $box.ARROW
        }

        $prefix = $stageLine.Substring(0, $start)
        $content = $stageLine.Substring($start, $len)
        $suffix = $stageLine.Substring($start + $len)

        Write-Host $prefix -NoNewline -ForegroundColor DarkGray
        Write-Host $content -NoNewline -ForegroundColor $color
        $stageLine = $suffix
    }
    Write-Host $stageLine -ForegroundColor DarkGray

    # Draw icons row
    $iconLine = ""
    foreach ($stage in $stages) {
        $icon = if ($stage.Stage -lt $CurrentStage) {
            $box.CHECK
        } elseif ($stage.Stage -eq $CurrentStage) {
            $box.ARROW
        } else {
            $box.CIRCLE
        }

        $padding = [math]::Floor((12 - 1) / 2)
        $iconLine += "$($box.VR2)" + (' ' * $padding) + $icon + (' ' * (12 - $padding - 1))
    }
    $iconLine += "$($box.VR2)"

    for ($i = 0; $i -lt $stages.Count; $i++) {
        $start = 1 + ($i * 13)
        $len = 12
        $color = "Gray"

        if ($stages[$i].Stage -lt $CurrentStage) {
            $color = "Green"
        } elseif ($stages[$i].Stage -eq $CurrentStage) {
            $color = "Yellow"
        }

        $prefix = $iconLine.Substring(0, $start)
        $content = $iconLine.Substring($start, $len)
        $suffix = $iconLine.Substring($start + $len)

        Write-Host $prefix -NoNewline -ForegroundColor DarkGray
        Write-Host $content -NoNewline -ForegroundColor $color
        $iconLine = $suffix
    }
    Write-Host $iconLine -ForegroundColor DarkGray

    # Draw descriptions
    $descLine = ""
    foreach ($stage in $stages) {
        $padding = [math]::Floor((12 - $stage.Desc.Length) / 2)
        $desc = (' ' * $padding) + $stage.Desc + (' ' * (12 - $padding - $stage.Desc.Length))
        $descLine += "$($box.VR2)" + $desc
    }
    $descLine += "$($box.VR2)"
    Write-Host $descLine -ForegroundColor DarkGray

    # Draw bottom border
    $bottomBorder = "$($box.BLR)" + ($box.HR * 12)
    for ($i = 1; $i -lt $stages.Count; $i++) {
        $bottomBorder += "$($box.HUR)" + ($box.HR * 12)
    }
    $bottomBorder += "$($box.BRR)"
    Write-Host $bottomBorder -ForegroundColor DarkGray
}

function Draw-ProgressBar {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Label
    )

    $percentage = [math]::Floor(($Current / $Total) * 100)
    $barWidth = 50
    $filled = [math]::Floor(($Current / $Total) * $barWidth)
    $empty = $barWidth - $filled

    $bar = "$($box.ARROW)" + ("█" * $filled) + ("░" * $empty)

    Write-Host ""
    Write-Host "  $Label" -ForegroundColor White
    Write-Host "  $bar $percentage%" -ForegroundColor $(if ($percentage -eq 100) {"Green"} elseif ($percentage -gt 50) {"Yellow"} else {"Gray"})
}

function Draw-InfoBox {
    param(
        [string]$Title,
        [hashtable]$Data
    )

    Write-Host ""
    Write-Host "  $($box.TLR)$($box.HR * 76)$($box.TRR)" -ForegroundColor DarkCyan
    Write-Host "  $($box.VR2) $Title$(' ' * (75 - $Title.Length))$($box.VR2)" -ForegroundColor DarkCyan
    Write-Host "  $($box.VRR)$($box.HR * 76)$($box.VLR)" -ForegroundColor DarkCyan

    foreach ($key in $Data.Keys) {
        $value = $Data[$key]
        $line = "  $($box.VR2) $key`: $value"
        $padding = 78 - $line.Length
        Write-Host "$line$(' ' * $padding)$($box.VR2)" -ForegroundColor Gray
    }

    Write-Host "  $($box.BLR)$($box.HR * 76)$($box.BRR)" -ForegroundColor DarkCyan
}

function Draw-Timeline {
    param(
        [object]$IssueData,
        [array]$PRData
    )

    Write-Host ""
    Write-Host "  TIMELINE" -ForegroundColor White
    Write-Host "  $($box.VR2)" -ForegroundColor DarkGray

    # Issue created
    $created = [DateTime]::Parse($IssueData.createdAt)
    Write-Host "  $($box.VRR)$($box.HR * 3)$($box.ARROW) " -NoNewline -ForegroundColor Green
    Write-Host "Issue created " -NoNewline -ForegroundColor Green
    Write-Host "($($created.ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor DarkGray

    # Label changes
    $labels = $IssueData.labels.name
    if ($labels -contains "ready-to-implement") {
        Write-Host "  $($box.VR2)   $($box.VR2)" -ForegroundColor DarkGray
        Write-Host "  $($box.VRR)$($box.HR * 3)$($box.ARROW) " -NoNewline -ForegroundColor Yellow
        Write-Host "Marked ready-to-implement" -ForegroundColor Yellow
    }

    if ($labels -contains "scc-claimed") {
        Write-Host "  $($box.VR2)   $($box.VR2)" -ForegroundColor DarkGray
        Write-Host "  $($box.VRR)$($box.HR * 3)$($box.ARROW) " -NoNewline -ForegroundColor Yellow
        Write-Host "Worker claimed issue" -ForegroundColor Yellow
    }

    if ($labels -contains "scc-implementing") {
        Write-Host "  $($box.VR2)   $($box.VR2)" -ForegroundColor DarkGray
        Write-Host "  $($box.VRR)$($box.HR * 3)$($box.ARROW) " -NoNewline -ForegroundColor Yellow
        Write-Host "SCC implementation started" -ForegroundColor Yellow
    }

    # PR created
    if ($PRData -and $PRData.Count -gt 0) {
        $pr = $PRData[0]
        $prCreated = [DateTime]::Parse($pr.createdAt)
        Write-Host "  $($box.VR2)   $($box.VR2)" -ForegroundColor DarkGray
        Write-Host "  $($box.VRR)$($box.HR * 3)$($box.ARROW) " -NoNewline -ForegroundColor Cyan
        Write-Host "PR #$($pr.number) created " -NoNewline -ForegroundColor Cyan
        Write-Host "($($prCreated.ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor DarkGray

        # PR merged
        if ($pr.state -eq "MERGED" -and $pr.mergedAt) {
            $merged = [DateTime]::Parse($pr.mergedAt)
            Write-Host "  $($box.VR2)   $($box.VR2)" -ForegroundColor DarkGray
            Write-Host "  $($box.VRR)$($box.HR * 3)$($box.CHECK) " -NoNewline -ForegroundColor Green
            Write-Host "PR merged " -NoNewline -ForegroundColor Green
            Write-Host "($($merged.ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor DarkGray

            # Calculate total time
            $totalTime = $merged - $created
            Write-Host "  $($box.VR2)   $($box.VR2)" -ForegroundColor DarkGray
            Write-Host "  $($box.BLR)$($box.HR * 3)$($box.ARROW) " -NoNewline -ForegroundColor Green
            Write-Host "Total time: $($totalTime.TotalMinutes.ToString('0.0')) minutes" -ForegroundColor Green
        }
    }

    if (-not ($labels -contains "scc-merged")) {
        Write-Host "  $($box.VR2)" -ForegroundColor DarkGray
    }
}

function Show-Workflow {
    param([int]$IssueNumber)

    Clear-Host

    # Fetch data
    $issue = Get-IssueData -Number $IssueNumber
    $prs = Get-PRData -IssueNumber $IssueNumber
    $stage = Get-WorkflowStage -Labels $issue.labels

    # Header
    Draw-Header "AI-SDLC WORKFLOW MONITOR - Issue #$IssueNumber"

    # Issue info
    Write-Host "  $($box.ARROW) " -NoNewline -ForegroundColor Cyan
    Write-Host $issue.title -ForegroundColor White
    Write-Host ""

    # Workflow pipeline
    Draw-WorkflowPipeline -CurrentStage $stage.Stage -IssueData $issue -PRData $prs

    # Progress bar
    Draw-ProgressBar -Current $stage.Stage -Total 6 -Label "Overall Progress"

    # Current stage info
    $stageInfo = @{
        "Current Stage" = "$($stage.Name) - $($stage.Description)"
        "Issue State" = $issue.state
        "Last Updated" = ([DateTime]::Parse($issue.updatedAt)).ToString('yyyy-MM-dd HH:mm:ss')
    }

    if ($prs -and $prs.Count -gt 0) {
        $stageInfo["Pull Request"] = "#$($prs[0].number) - $($prs[0].state)"
        $stageInfo["PR URL"] = $prs[0].url
    }

    Draw-InfoBox -Title "CURRENT STATUS" -Data $stageInfo

    # Timeline
    Draw-Timeline -IssueData $issue -PRData $prs

    # Labels
    Write-Host ""
    Write-Host "  ACTIVE LABELS" -ForegroundColor White
    foreach ($label in $issue.labels) {
        $color = if ($label.name -like "scc-*") {"Yellow"} else {"Gray"}
        Write-Host "    $($box.DOT) $($label.name)" -ForegroundColor $color
    }

    # Footer
    Write-Host ""
    Write-Host "  Last refresh: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray

    if ($Continuous) {
        Write-Host "  Auto-refresh in 15s... (Press Ctrl+C to stop)" -ForegroundColor DarkGray
    } else {
        Write-Host "  Run with -Continuous to auto-refresh" -ForegroundColor DarkGray
    }

    Write-Host ""
}

# Main execution
if ($Continuous) {
    while ($true) {
        Show-Workflow -IssueNumber $IssueNumber
        Start-Sleep -Seconds 15
    }
} else {
    Show-Workflow -IssueNumber $IssueNumber
}
