# P3 A2UI rollout signoff aggregation (independent from CP/Wails default)
param(
    [string]$RepoRoot = "",
    [switch]$SkipRolloutGate,
    [switch]$SkipDailyObservation,
    [switch]$SkipDay4,
    [int]$MinObservationDays = 7,
    [switch]$JsonOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
if (-not $RepoRoot) { $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot }

$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
$outPath = Join-Path $debugDir "p3_a2ui_signoff_pipeline.json"

function Write-Phase([string]$title) {
    if (-not $JsonOnly) { Write-Host ""; Write-Host $title -ForegroundColor Cyan }
}

Write-Phase "== P3 A2UI Rollout Signoff Pipeline =="

$rolloutPhase = [ordered]@{ pass = $null; skipped = [bool]$SkipRolloutGate; artifact = "Cache/debug/a2ui_rollout_gate_last.json" }
if (-not $SkipRolloutGate) {
    Write-Phase "1/3 RolloutGate"
    & (Join-Path $here "Run-A2uiRolloutGate.ps1") -RepoRoot $RepoRoot -SkipBuild
    $rolloutPhase.exitCode = $LASTEXITCODE
}
$rollout = Read-DiagJson (Join-Path $debugDir "a2ui_rollout_gate_last.json")
if ($rollout) {
    $rolloutPhase.pass = [bool]$rollout.rolloutGatePass
} elseif (-not $SkipRolloutGate) {
    $rolloutPhase.pass = $false
}

$dailyPhase = [ordered]@{ pass = $null; skipped = [bool]$SkipDailyObservation; artifact = "Cache/debug/a2ui_observation_eval_last.json" }
if (-not $SkipDailyObservation) {
    Write-Phase "2/3 Daily observation"
    & (Join-Path $here "Run-A2uiDailyObservation.ps1") -RepoRoot $RepoRoot | Out-Null
    $eval = Read-DiagJson (Join-Path $debugDir "a2ui_observation_eval_last.json")
    if ($eval) { $dailyPhase.pass = [bool]$eval.evaluatePass }
}

$obsDays = 0
$histPath = Join-Path $debugDir "a2ui_observation_history.jsonl"
if (Test-Path $histPath) {
    $days = @(
        Get-Content $histPath -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object {
            try {
                $row = $_ | ConvertFrom-Json
                ([datetime]$row.capturedAt).ToUniversalTime().ToString("yyyy-MM-dd")
            } catch { }
        } | Where-Object { $_ } | Sort-Object -Unique
    )
    $obsDays = @($days).Count
}

$day4Phase = [ordered]@{ pass = $null; skipped = [bool]$SkipDay4; artifact = "Cache/debug/a2ui_day4_decision_last.json" }
$recommendation = "maintain_b_granularity"
if (-not $SkipDay4) {
    Write-Phase "3/3 Day4 decision"
    & (Join-Path $here "Run-A2uiDay4Decision.ps1") -RepoRoot $RepoRoot -MinObservationDays $MinObservationDays
    $day4Phase.exitCode = $LASTEXITCODE
    $day4 = Read-DiagJson (Join-Path $debugDir "a2ui_day4_decision_last.json")
    if ($day4) {
        $day4Phase.pass = [bool]$day4.day4Pass
        $recommendation = [string]$day4.recommendation
    }
}

$rolloutGatePass = ($rolloutPhase.pass -eq $true)
$day4Pass = ($day4Phase.pass -eq $true)
$observationEvalPass = ($dailyPhase.pass -eq $true)

$release = [ordered]@{
    rolloutGatePass       = $rolloutGatePass
    observationEvalPass   = $observationEvalPass
    observationDays       = $obsDays
    observationDaysRequired = $MinObservationDays
    day4Pass              = $day4Pass
    recommendation        = $recommendation
    p3RolloutGatePass     = $rolloutGatePass
    p3ExpandGrayPass      = $day4Pass
    commandPaletteHostUnchanged = $true
    wailsDefaultEligibleUnchanged = $true
    blockedReason         = if ($day4Pass) { $null } elseif ($obsDays -lt $MinObservationDays) { "observation_days_${obsDays}_of_${MinObservationDays}" } else { "day4_checks_failed" }
    note                  = "rolloutGatePass does not change commandPaletteHost or wailsDefaultEligible"
}

$report = [ordered]@{
    capturedAt  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    repoRoot    = $RepoRoot
    pass        = $rolloutGatePass
    p3ExpandGrayPass = $day4Pass
    exitCode    = if (-not $rolloutGatePass) { 1 } elseif (-not $day4Pass) { 2 } else { 0 }
    release     = $release
    phases      = [ordered]@{
        rolloutGate = $rolloutPhase
        daily       = $dailyPhase
        day4        = $day4Phase
    }
    artifacts   = @(
        "Cache/debug/p3_a2ui_signoff_pipeline.json",
        "Cache/debug/a2ui_rollout_gate_last.json",
        "Cache/debug/a2ui_observation_eval_last.json",
        "Cache/debug/a2ui_observation_history.jsonl",
        "Cache/debug/a2ui_day4_decision_last.json"
    )
    commands    = [ordered]@{
        fullPipeline   = ".\tools\a2ui-diagnostics\Run-A2uiP3SignoffPipeline.ps1"
        dailyOnly      = ".\tools\a2ui-diagnostics\Run-A2uiDailyObservation.ps1"
        rolloutOnly    = ".\tools\a2ui-diagnostics\Run-A2uiRolloutGate.ps1 -SkipBuild"
        day4Only       = ".\tools\a2ui-diagnostics\Run-A2uiDay4Decision.ps1"
    }
}
Write-DiagJson $report $outPath

Write-Phase "Summary"
if (-not $JsonOnly) {
    Write-Host ("p3_a2ui_signoff_pipeline -> {0}" -f $outPath) -ForegroundColor $(if ($rolloutGatePass) { "Green" } else { "Red" })
    Write-Host ("  rolloutGatePass={0} observationEval={1} obsDays={2}/{3} day4Pass={4} recommendation={5}" -f `
        $rolloutGatePass, $observationEvalPass, $obsDays, $MinObservationDays, $day4Pass, $recommendation) -ForegroundColor DarkGray
    if ($rolloutGatePass -and -not $day4Pass) {
        Write-Host "Next: daily Run-A2uiDailyObservation.ps1 until observationDays>=7, then re-run pipeline" -ForegroundColor Yellow
    }
}
exit $report.exitCode
