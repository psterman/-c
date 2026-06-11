# CP0 Phase 0: PerfGate baseline (capture + gate + archive)
param(
    [switch]$SkipCapture,
    [switch]$Quick,
    [switch]$NoArchive,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = (Resolve-Path (Join-Path $here "..\..")).Path
$logPath = Join-Path $repo "Cache\debug\command_palette_perf.ndjson"
$gatePath = Join-Path $repo "Cache\debug\command_palette_perf_gate.json"
$flagsPath = Join-Path $repo "local\nmer-flags.json"
$baselineDir = Join-Path $repo "Cache\debug\perf-baselines"

function Write-Step([string]$msg) {
    Write-Host ""
    Write-Host $msg -ForegroundColor Cyan
}

function Get-PaletteFlagState([string]$path) {
    if (-not (Test-Path $path)) {
        return @{ ok = $false; reason = "missing nmer-flags.json" }
    }
    try {
        $j = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return @{ ok = $false; reason = "invalid json: $($_.Exception.Message)" }
    }
    $p = $j.palette
    if (-not $p) {
        return @{ ok = $false; reason = "palette section missing" }
    }
    return @{
        ok = $true
        fastInput = [bool]$p.fastInput
        discreteLayout = [bool]$p.discreteLayout
        streamBatching = [bool]$p.streamBatching
        stateStore = [bool]$p.stateStore
        agentTransport = [string]$p.agentTransport
        commandPaletteHost = [string]$j.wailsBridge.commandPaletteHost
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " CommandPalette Phase 0 - PerfGate" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Step "1/4 Preflight"
$flagState = Get-PaletteFlagState $flagsPath
if (-not $flagState.ok) {
    Write-Host ("  FAIL: {0}" -f $flagState.reason) -ForegroundColor Red
    exit 1
}
Write-Host ("  commandPaletteHost: {0}" -f $flagState.commandPaletteHost) -ForegroundColor DarkGray
Write-Host ("  fastInput:          {0}" -f $flagState.fastInput)
Write-Host ("  discreteLayout:     {0}" -f $flagState.discreteLayout)
Write-Host ("  streamBatching:     {0}" -f $flagState.streamBatching)
Write-Host ("  stateStore:         {0}" -f $flagState.stateStore)
Write-Host ("  agentTransport:     {0}" -f $flagState.agentTransport)

if (-not $flagState.fastInput -or -not $flagState.discreteLayout) {
    Write-Host ""
    Write-Host "  WARN: enable palette.fastInput + discreteLayout in local/nmer-flags.json" -ForegroundColor Yellow
}
if ($flagState.commandPaletteHost -ne "ahk") {
    Write-Host "  WARN: phase 0 expects commandPaletteHost=ahk" -ForegroundColor Yellow
}

$signoffPath = Join-Path $repo "Cache\debug\v4_signoff_dashboard.json"
if ((Test-Path $signoffPath) -and -not $Force) {
    try {
        $dash = Get-Content $signoffPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $deployDone = $false
        if ($dash.deploy -and $dash.deploy.status) {
            $deployDone = ([string]$dash.deploy.status).ToLower() -eq "done"
        }
        if (-not $deployDone) {
            Write-Host ""
            Write-Host "  WARN: v4 signoff deploy not done yet." -ForegroundColor Yellow
            Write-Host "        Capture PerfGate after FormalSignoff deploy done." -ForegroundColor Yellow
            $ans = Read-Host "Continue anyway? (y/N)"
            if ($ans -notmatch '^[yY]') { exit 2 }
        }
    } catch {
    }
} elseif (-not $Force) {
    Write-Host ""
    Write-Host "  INFO: v4_signoff_dashboard.json not found." -ForegroundColor DarkYellow
    $ans = Read-Host "Continue capture? (y/N)"
    if ($ans -notmatch '^[yY]') { exit 2 }
}

Write-Step "2/4 Clear log and reload"
Write-Host "  Reload niuma.ahk if AHK/HTML changed (full exit then restart)." -ForegroundColor Yellow
Write-Host ("  Will clear: {0}" -f $logPath) -ForegroundColor DarkGray
if (-not $Force) {
    Read-Host "Press Enter after reload"
}

if (-not $SkipCapture) {
    Write-Step "3/4 Guided capture"
    $capArgs = @{
        ClearLog = $true
        Strict   = $true
        Scenario = if ($Quick) { "quick" } else { "all" }
    }
    & (Join-Path $here "Capture-CommandPalettePerfSession.ps1") @capArgs
    $capExit = $LASTEXITCODE
} else {
    Write-Step "3/4 Skip capture, run PerfGate only"
    & (Join-Path $here "Run-CommandPalettePerfGate.ps1") -Strict -ExpectDiscreteLayout
    $capExit = $LASTEXITCODE
}

Write-Step "4/4 Archive baseline"
if (-not $NoArchive -and (Test-Path $gatePath)) {
    if (-not (Test-Path $baselineDir)) {
        New-Item -ItemType Directory -Path $baselineDir -Force | Out-Null
    }
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $archiveGate = Join-Path $baselineDir ("phase0_gate_{0}.json" -f $stamp)
    $archiveLog = Join-Path $baselineDir ("phase0_ndjson_{0}.ndjson" -f $stamp)
    Copy-Item $gatePath $archiveGate -Force
    if (Test-Path $logPath) {
        Copy-Item $logPath $archiveLog -Force
    }
    Write-Host ("  gate:   {0}" -f $archiveGate) -ForegroundColor Green
    Write-Host ("  ndjson: {0}" -f $archiveLog) -ForegroundColor Green
}

Write-Host ""
if ($capExit -eq 0) {
    Write-Host "Phase 0 PASS" -ForegroundColor Green
} else {
    Write-Host "Phase 0 FAIL - see command_palette_perf_gate.json failures" -ForegroundColor Red
    $gateScript = Join-Path $here "Run-CommandPalettePerfGate.ps1"
    Write-Host ("  Re-run gate: {0} -Strict" -f $gateScript) -ForegroundColor DarkGray
}
Write-Host ""

exit $capExit
