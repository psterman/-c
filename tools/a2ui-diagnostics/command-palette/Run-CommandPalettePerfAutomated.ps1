# Phase E automated PerfGate (no keyboard). Default: manual_equivalent sync command-index path.
param(
    [ValidateSet("manual_equivalent", "synthetic_turbo")]
    [string]$Mode = "manual_equivalent",
    [switch]$SkipReload,
    [switch]$NoArchive,
    [switch]$Force
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$repo = Get-DiagRepoRoot -From $here
$gatePath = Join-Path $repo "Cache\debug\command_palette_perf_gate.json"
$baselineDir = Join-Path $repo "Cache\debug\perf-baselines"
$scriptPath = Join-Path $repo "牛马.ahk"
$ahkExe = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Phase E — Automated PerfGate ($Mode)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "1/5 SearchCore stop + idle check" -ForegroundColor Cyan
$scOk = $false
try {
    Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8080/v1/fulltext/control" `
        -Body '{"action":"stop"}' -ContentType "application/json" -TimeoutSec 8 | Out-Null
    Start-Sleep -Seconds 2
    $st = Invoke-RestMethod -Uri "http://127.0.0.1:8080/v1/fulltext/status" -TimeoutSec 8
    $scOk = $true
    Write-Host ("  scanPhase={0} running={1}" -f $st.scanPhase, $st.running) -ForegroundColor DarkGray
    if ($st.running -eq $true -and $Mode -eq "manual_equivalent" -and -not $Force) {
        throw "SearchCore still running; stop before manual_equivalent PerfGate or use -Force."
    }
} catch {
    if ($Mode -eq "synthetic_turbo" -and -not $Force) { throw $_ }
    Write-Host ("  WARN: SearchCore unavailable or not idle ({0})" -f $_.Exception.Message) -ForegroundColor Yellow
}
if (-not $scOk -and $Mode -eq "manual_equivalent") {
    Write-Host "  manual_equivalent does not require SearchCore HTTP turbo" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "2/5 Ensure niuma.ahk + hub inject" -ForegroundColor Cyan
if (-not (Ensure-DiagNmerHub -RepoRoot $repo -WarmupSec 2)) {
    throw "nmer-hub not running and auto-start failed. Run: go build in apps/nmer-hub, or start nmer-hub.exe manually."
}
if (-not (Get-Process -Name "AutoHotkey64" -ErrorAction SilentlyContinue)) {
    Write-Host "  Starting 牛马.ahk" -ForegroundColor Yellow
    if (-not (Test-Path $ahkExe)) { throw "AutoHotkey64 not found at $ahkExe" }
    Start-Process -FilePath $ahkExe -ArgumentList @("`"$scriptPath`"")
    Start-Sleep -Seconds 40
}

$capArgs = @{
    Mode       = $Mode
    ClearLog   = $true
    TimeoutSec = if ($Mode -eq "synthetic_turbo") { 180 } else { 120 }
}
if ($SkipReload) { $capArgs["SkipReload"] = $true }

Write-Host ""
Write-Host "3/5 Hub capture inject" -ForegroundColor Cyan
& (Join-Path $here "Invoke-CpPerfCapture.ps1") @capArgs
$capExit = $LASTEXITCODE

Write-Host ""
Write-Host "4/5 P95 split diagnostic" -ForegroundColor Cyan
& (Join-Path $here "Split-CpPerfP95Diagnostic.ps1")

Write-Host ""
Write-Host "5/5 Archive" -ForegroundColor Cyan
if (-not $NoArchive -and (Test-Path $gatePath)) {
    if (-not (Test-Path $baselineDir)) { New-Item -ItemType Directory -Path $baselineDir -Force | Out-Null }
    $stamp = (Get-Date -Format "yyyyMMdd_HHmmss") + "_" + $Mode
    $dest = Join-Path $baselineDir $stamp
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    foreach ($f in @("command_palette_perf_gate.json", "command_palette_perf_pipeline.json", "command_palette_perf.ndjson", "command_palette_perf_p95_split.json")) {
        $src = Join-Path $repo "Cache\debug\$f"
        if (Test-Path $src) { Copy-Item $src (Join-Path $dest $f) -Force }
    }
    Write-Host ("  {0}" -f $dest) -ForegroundColor Green
}

Write-Host ""
if ($capExit -eq 0) {
    Write-Host "Phase E automated PASS (overallPass=true)" -ForegroundColor Green
    Write-Host "Next: CP3a shadow write" -ForegroundColor Green
} else {
    if ($Mode -eq "manual_equivalent") {
        Write-Host "Phase E automated FAIL — see command_palette_perf_gate.json + command_palette_perf_p95_split.json" -ForegroundColor Red
    } else {
        Write-Host "Synthetic turbo run — Stage1 may pass; performance fail is expected (synthetic_turbo_performance_fail)" -ForegroundColor Yellow
    }
}
Write-Host ""
exit $capExit
