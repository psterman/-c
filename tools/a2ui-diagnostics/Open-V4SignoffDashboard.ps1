# v4 signoff dashboard: collect prereqs + open browser
param(
    [string]$RepoRoot = "",
    [switch]$SkipBaselineCapture,
    [switch]$RunP0AQuick,
    [switch]$SkipP0A,
    [switch]$LaunchFormalSignoff
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $here "..\..")).Path
}

$collectArgs = @{ RepoRoot = $RepoRoot }
if ($SkipBaselineCapture) { $collectArgs["SkipBaselineCapture"] = $true }
if ($RunP0AQuick) { $collectArgs["RunP0AQuick"] = $true }
if ($SkipP0A) { $collectArgs["SkipP0A"] = $true }

& (Join-Path $here "Collect-V4SignoffDashboard.ps1") @collectArgs
$collectExit = $LASTEXITCODE

$jsonPath = Join-Path $RepoRoot "Cache\debug\v4_signoff_dashboard.json"
$template = Join-Path $here "v4-signoff-dashboard.html"
$livePath = Join-Path $here "v4-signoff-dashboard-live.html"

if (-not (Test-Path $jsonPath)) {
    Write-Error "Missing $jsonPath"
}
$jsonRaw = (Get-Content $jsonPath -Raw -Encoding UTF8).Trim()
$htmlRaw = Get-Content $template -Raw -Encoding UTF8
$scriptTagOpen = '<script>window.__V4_SIGNOFF_DATA__ = '
$scriptTagClose = ';</script>'
$inject = $scriptTagOpen + $jsonRaw + $scriptTagClose
$bodyClose = '</body>'
$liveHtml = $htmlRaw.Replace($bodyClose, ($inject + "`r`n" + $bodyClose))
$liveHtml | Set-Content -Path $livePath -Encoding UTF8

Write-Host ""
Write-Host "Dashboard: $livePath" -ForegroundColor Cyan
try {
    $d = $jsonRaw | ConvertFrom-Json
    $color = if ($d.readyForFormalSignoff) { "Green" } else { "Yellow" }
    Write-Host ("readyForFormalSignoff: " + $d.readyForFormalSignoff) -ForegroundColor $color
} catch {}

Start-Process $livePath

if ($LaunchFormalSignoff) {
    if ($collectExit -ne 0) {
        Write-Host "Prereqs not ready; skipped -FormalSignoff. Fix red gates and rerun." -ForegroundColor Red
        exit 2
    }
    Write-Host "Starting formal signoff (~30 min)..." -ForegroundColor Magenta
    $deployScript = Join-Path $here "Deploy-MemoryIndexBaseline.ps1"
    & $deployScript -FormalSignoff -RepoRoot $RepoRoot
    exit $LASTEXITCODE
}

exit $collectExit
