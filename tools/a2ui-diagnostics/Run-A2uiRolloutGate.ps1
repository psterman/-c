# Rollout gate: Wave 0 + Wave 2 + ADP L1/L2 when sidecar is up
param(
    [string]$RepoRoot = "",
    [switch]$SkipBuild,
    [switch]$SkipAdpIntegration
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }

$buildOk = $true
if (-not $SkipBuild) {
    Write-Host "=== build nmer-wails ==="
    & (Join-Path $RepoRoot "scripts\Build-NmerWails.ps1") -RepoRoot $RepoRoot -SkipBindings
    $buildOk = ($LASTEXITCODE -eq 0)
}

Write-Host "=== wave 0 baseline ==="
$flagsContext = "wave0"
$flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"
if (Test-Path $flagsPath) {
    try {
        $flags = Get-Content $flagsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $officialEnabled = $flags.officialA2ui.enabled -eq $true
        $forceNmerOnly = $flags.rollback.forceNmerOnly -eq $true
        if ($officialEnabled -and -not $forceNmerOnly) { $flagsContext = "daily" }
    } catch { }
}
Write-Host "flagsContext=$flagsContext"
& (Join-Path $PSScriptRoot "Run-Wave0Baseline.ps1") -RepoRoot $RepoRoot -FlagsContext $flagsContext
$w0Ok = ($LASTEXITCODE -eq 0)

Write-Host "=== wave 2 gray baseline ==="
$w2Args = @{ RepoRoot = $RepoRoot }
if ($SkipAdpIntegration) { $w2Args["SkipAdpIntegration"] = $true }
& (Join-Path $PSScriptRoot "Run-Wave2GrayBaseline.ps1") @w2Args
$w2Ok = ($LASTEXITCODE -eq 0)

Write-Host "=== daily observation ==="
& (Join-Path $PSScriptRoot "Run-A2uiDailyObservation.ps1") -RepoRoot $RepoRoot | Out-Null
$obsEvalOk = $true
$evalPath = Join-Path $debugDir "a2ui_observation_eval_last.json"
if (Test-Path $evalPath) {
    try {
        $eval = Get-Content $evalPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $obsEvalOk = ($eval.evaluatePass -eq $true)
    } catch {
        $obsEvalOk = $false
    }
}

Write-Host "=== ws replay stress ==="
& (Join-Path $RepoRoot "scripts\Run-A2uiWsReplayStress.ps1") -RepoRoot $RepoRoot
$replayOk = ($LASTEXITCODE -eq 0)

Write-Host "=== hermes provider contract ==="
& (Join-Path $RepoRoot "scripts\Run-HermesProviderContract.ps1") -RepoRoot $RepoRoot
$hermesOk = ($LASTEXITCODE -eq 0)

Write-Host "=== l3 probe summary ==="
& (Join-Path $RepoRoot "scripts\Run-A2uiL3ProbeSummary.ps1") -RepoRoot $RepoRoot
$l3Ok = ($LASTEXITCODE -eq 0)

$summary = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    buildOk    = $buildOk
    wave0Pass  = $w0Ok
    wave2Pass  = $w2Ok
    observationEval = @{ ok = $obsEvalOk }
    wsReplayStress = @{ ok = $replayOk }
    hermesContract = @{ ok = $hermesOk }
    l3Probes = @{ ok = $l3Ok }
    rolloutGatePass = ($buildOk -and $w0Ok -and $w2Ok -and $obsEvalOk -and $replayOk -and $hermesOk -and $l3Ok)
}

$path = Join-Path $debugDir "a2ui_rollout_gate_last.json"
$summary | ConvertTo-Json -Depth 4 | Set-Content -Path $path -Encoding UTF8
Write-Host "rollout_gate -> $path pass=$($summary.rolloutGatePass)"

if (-not $summary.rolloutGatePass) { exit 1 }
exit 0
