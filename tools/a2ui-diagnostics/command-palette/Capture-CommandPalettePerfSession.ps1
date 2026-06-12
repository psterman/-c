# Capture CP perf session: guided manual scenarios, then run PerfGate
param(
    [ValidateSet("all", "local-type", "action-type", "layout-toggle", "stream-type", "quick")]
    [string]$Scenario = "all",
    [int]$WaitSeconds = 0,
    [switch]$ClearLog,
    [switch]$Strict,
    [switch]$NoGate
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Get-DiagRepoRoot -From $here
$logPath = Join-Path $repo "Cache\debug\command_palette_perf.ndjson"

$scenarioDefs = [ordered]@{
    "local-type" = @{
        title = "Local intent: type 20 chars"
        wait = 35
        steps = @(
            "Reload niuma.ahk if AHK/HTML changed"
            "CapsLock double-tap open CommandPalette (do NOT use Ctrl+Shift+Q — reloads AHK)"
            "Stay on Local intent (default)"
            "Type at least 20 characters in the input box"
            "Esc to close CP (optional)"
        )
    }
    "action-type" = @{
        title = "Action intent: type 20 chars after >"
        wait = 40
        steps = @(
            "Open CP, switch to Action intent"
            "Type > then command keywords (~20 chars total)"
            "Confirm command list updates without full-page flash"
            "Clear input or Esc close"
        )
    }
    "layout-toggle" = @{
        title = "Compact / List toggle"
        wait = 45
        steps = @(
            "Open CP (discreteLayout should be true)"
            "Empty input: observe Compact height"
            "Type to enter List, clear to Compact, repeat ~10 times"
            "Each mode change should resize once (no continuous jitter)"
        )
    }
    "stream-type" = @{
        title = "Type while Agent streams (optional)"
        wait = 90
        steps = @(
            "Submit an Agent task that streams a reply"
            "While streaming, type 10+ chars in CP (or command search)"
            "Input should stay responsive"
            "Wait for task end or stop manually"
        )
    }
}

function Show-ScenarioBanner([string]$key, [hashtable]$def) {
    Write-Host ""
    Write-Host ("--- Scenario: {0} ---" -f $def.title) -ForegroundColor Cyan
    $i = 1
    foreach ($s in $def.steps) {
        Write-Host ("  {0}. {1}" -f $i, $s)
        $i++
    }
    Write-Host ""
}

function Wait-ScenarioTimer([int]$seconds) {
    if ($seconds -le 0) { return }
    Write-Host ("Timer {0}s - follow steps above..." -f $seconds) -ForegroundColor Yellow
    Start-Sleep -Seconds $seconds
}

$keys = @()
switch ($Scenario) {
    "quick" { $keys = @("local-type") }
    "all" { $keys = @("local-type", "action-type", "layout-toggle", "stream-type") }
    default { $keys = @($Scenario) }
}

Write-Host ""
Write-Host "=== CommandPalette Perf Capture ===" -ForegroundColor Cyan
Write-Host "After FormalSignoff deploy done; reload niuma.ahk before capture." -ForegroundColor DarkYellow
Write-Host ("Log: {0}" -f $logPath) -ForegroundColor DarkGray
Write-Host ""

if ($ClearLog -and (Test-Path $logPath)) {
    Remove-Item $logPath -Force
    Write-Host "Log cleared." -ForegroundColor DarkGray
}

Read-Host "Press Enter when ready to start"

foreach ($key in $keys) {
    if (-not $scenarioDefs.Contains($key)) { continue }
    $def = $scenarioDefs[$key]
    Show-ScenarioBanner $key $def
    $wait = if ($WaitSeconds -gt 0) { $WaitSeconds } else { [int]$def.wait }
    Read-Host "Press Enter to start scenario timer"
    Wait-ScenarioTimer $wait
}

if ($NoGate) {
    Write-Host "Capture done (PerfGate skipped)." -ForegroundColor DarkGray
    exit 0
}

Write-Host ""
Write-Host "Running pipeline self-check (Stage 1)..." -ForegroundColor Cyan
& (Join-Path $here "Test-CpPerfPipeline.ps1")
if ($LASTEXITCODE -ne 0) {
    Write-Host "Pipeline check failed — fix sampling before performance thresholds." -ForegroundColor Yellow
    if ($Strict) { exit 1 }
}

$gateArgs = @{}
if ($Strict) { $gateArgs["Strict"] = $true }
& (Join-Path $here "Run-CommandPalettePerfGate.ps1") @gateArgs
exit $LASTEXITCODE
