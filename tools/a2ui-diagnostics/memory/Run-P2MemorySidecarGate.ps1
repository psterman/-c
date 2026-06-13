# P2 memory + sidecar gate (post CP release): hub private / 30min slope / 10-round recovery
param(
    [string]$RepoRoot = "",
    [int]$SoakMinutes = 30,
    [int]$QuickSoakMinutes = 0,
    [int]$RecoveryRounds = 10,
    [double]$RecoveryLimitPct = 10,
    [switch]$SkipSoak,
    [switch]$SkipRecovery,
    [switch]$PauseIndexerForSoak,
    [switch]$JsonOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
if (-not $RepoRoot) { $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot }

$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
$outPath = Join-Path $debugDir "p2_memory_sidecar_gate.json"

function Write-Phase([string]$title) {
    if (-not $JsonOnly) { Write-Host ""; Write-Host $title -ForegroundColor Cyan }
}

Write-Phase "== P2 Memory + Sidecar Gate =="
if (-not $JsonOnly) { Write-Host "  repo: $RepoRoot" -ForegroundColor DarkGray }

# --- hub private (instant) ---
Write-Phase "1/3 Hub private"
if (-not (Ensure-DiagNmerHub -RepoRoot $RepoRoot -WarmupSec 2)) {
    throw "nmer-hub not running"
}
$hubNow = Get-DiagHubPrivateMiB
$hubGate = Test-P2HubPrivateGate $hubNow
if (-not $JsonOnly) {
    $color = switch ($hubGate.status) { "PASS" { "Green" } "WARN" { "Yellow" } default { "Red" } }
    Write-Host ("  hubPrivateMiB={0} -> {1}" -f $hubGate.value, $hubGate.status) -ForegroundColor $color
}

# --- 30min slope ---
$soakPhase = [ordered]@{ pass = $null; skipped = [bool]$SkipSoak; artifact = "Cache/debug/p2_hub_ui_soak.json" }
if (-not $SkipSoak) {
    Write-Phase "2/3 Hub/UI 30min slope soak"
    $soakArgs = @{ RepoRoot = $RepoRoot; DurationMinutes = $SoakMinutes }
    if ($QuickSoakMinutes -gt 0) { $soakArgs["QuickMinutes"] = $QuickSoakMinutes }
    if ($PauseIndexerForSoak) { $soakArgs["PauseIndexer"] = $true }
    & (Join-Path $here "Run-P2HubUiSoak.ps1") @soakArgs
    $soakExit = $LASTEXITCODE
    $soakPhase.exitCode = $soakExit
} elseif (-not $JsonOnly) {
    Write-Host "  skipped (-SkipSoak)" -ForegroundColor DarkGray
}
$soakJson = Read-DiagJson (Join-Path $debugDir "p2_hub_ui_soak.json")
if ($soakJson) {
    $soakPhase.pass = [bool]$soakJson.overallPass
    $soakPhase.gates = $soakJson.gates
} elseif (-not $SkipSoak) {
    $soakPhase.pass = $false
    $soakPhase.detail = "p2_hub_ui_soak.json missing"
}

# --- 10-round recovery ---
$recoveryPhase = [ordered]@{
    pass     = $null
    skipped  = [bool]$SkipRecovery
    artifact = "Cache/debug/hybrid_cycle_recovery.json"
}
if (-not $SkipRecovery) {
    Write-Phase "3/3 10-round hub recovery"
    & (Join-Path (Join-Path $here "..\hybrid") "Run-HybridCycleRecovery.ps1") -RepoRoot $RepoRoot -Rounds $RecoveryRounds -RecoveryLimitPct $RecoveryLimitPct
    $recoveryPhase.exitCode = $LASTEXITCODE
} elseif (-not $JsonOnly) {
    Write-Host "  skipped (-SkipRecovery)" -ForegroundColor DarkGray
}
$recoveryJson = Read-DiagJson (Join-Path $debugDir "hybrid_cycle_recovery.json")
if ($recoveryJson) {
    $recoveryPhase.pass = [bool]$recoveryJson.pass
    $recoveryPhase.endWithinBudget = $recoveryJson.endWithinBudget
    $recoveryPhase.hubStartMiB = $recoveryJson.hubStartMiB
    $recoveryPhase.hubEndMiB = $recoveryJson.hubEndMiB
} elseif (-not $SkipRecovery) {
    $recoveryPhase.pass = $false
    $recoveryPhase.detail = "hybrid_cycle_recovery.json missing"
}

$hardFails = @()
if (-not $hubGate.pass) { $hardFails += "hub_private" }
if ($soakPhase.pass -eq $false) { $hardFails += "hub_ui_slope" }
if ($recoveryPhase.pass -eq $false) { $hardFails += "ten_round_recovery" }

$warnings = @()
if ($hubGate.warn) { $warnings += "hub_private_warn_band" }

$overallPass = ($hardFails.Count -eq 0)
$overallStatus = if (-not $overallPass) { "FAIL" } elseif ($warnings.Count -gt 0) { "PASS_WITH_WARNINGS" } else { "PASS" }

$release = [ordered]@{
    p2Pass              = $overallPass
    p2Status            = $overallStatus
    hubPrivateGate      = $hubGate
    soakPass            = $soakPhase.pass
    recoveryPass        = $recoveryPhase.pass
    warnings            = $warnings
    hardFailures        = $hardFails
}

$report = [ordered]@{
    capturedAt  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    repoRoot    = $RepoRoot
    gate        = "p2_memory_sidecar"
    overallPass = $overallPass
    overallStatus = $overallStatus
    release     = $release
    phases      = [ordered]@{
        hubPrivate = $hubGate
        soak       = $soakPhase
        recovery   = $recoveryPhase
    }
    thresholds  = [ordered]@{
        hubPrivatePassMiB   = 50
        hubPrivateWarnMiB   = 55
        hubSlopeMiBPerHour  = 1
        uiSlopeMiBPerHour   = 5
        uiAbsDeltaMiB       = 30
        recoveryEndPct      = $RecoveryLimitPct
    }
    artifacts   = @(
        "Cache/debug/p2_memory_sidecar_gate.json",
        "Cache/debug/p2_hub_ui_soak.json",
        "Cache/debug/hybrid_cycle_recovery.json"
    )
    commands    = [ordered]@{
        fullGate    = ".\tools\a2ui-diagnostics\Run-P2MemorySidecarGate.ps1"
        soakOnly    = ".\tools\a2ui-diagnostics\memory\Run-P2HubUiSoak.ps1 -PauseIndexer"
        recoveryOnly = ".\tools\a2ui-diagnostics\Run-HybridCycleRecovery.ps1"
        quickGate   = ".\tools\a2ui-diagnostics\Run-P2MemorySidecarGate.ps1 -QuickSoakMinutes 3 -PauseIndexerForSoak"
    }
}
Write-DiagJson $report $outPath

Write-Phase "Summary"
if (-not $JsonOnly) {
    Write-Host ("p2_memory_sidecar_gate -> {0} status={1} pass={2}" -f $outPath, $overallStatus, $overallPass) -ForegroundColor $(if ($overallPass) { if ($warnings.Count) { "Yellow" } else { "Green" } } else { "Red" })
    Write-Host ("  hub={0} soak={1} recovery={2} warnings={3}" -f $hubGate.status, $soakPhase.pass, $recoveryPhase.pass, ($warnings -join ",")) -ForegroundColor DarkGray
}
exit $(if ($overallPass) { 0 } else { 1 })
