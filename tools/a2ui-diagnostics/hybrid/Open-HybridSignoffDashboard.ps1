# Hybrid signoff dashboard: collect + inject JSON + open browser
param(
    [string]$RepoRoot = "",
    [ValidateSet("formal", "formal-cold", "warm-session", "relaxed", "live", "smoke", "dev")]
    [string]$SignoffMode = "live",
    [switch]$SkipBaselineCapture,
    [switch]$SkipHubChain,
    [switch]$SkipCycle,
    [switch]$SkipS11Static,
    [switch]$RunOpenClawSmoke,
    [switch]$CollectOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}

$collectArgs = @{ RepoRoot = $RepoRoot; SignoffMode = $SignoffMode }
if ($SkipBaselineCapture) { $collectArgs["SkipBaselineCapture"] = $true }
if ($SkipHubChain) { $collectArgs["SkipHubChain"] = $true }
if ($SkipCycle) { $collectArgs["SkipCycle"] = $true }
if ($SkipS11Static) { $collectArgs["SkipS11Static"] = $true }
if ($RunOpenClawSmoke) { $collectArgs["RunOpenClawSmoke"] = $true }

& (Join-Path $here "Collect-HybridSignoffDashboard.ps1") @collectArgs
$collectExit = $LASTEXITCODE

$jsonPath = Join-Path $RepoRoot "Cache\debug\hybrid_signoff_dashboard.json"
$template = Join-DiagScript -RelativePath "dashboards/hybrid-signoff-dashboard.html"
$livePath = Join-DiagScript -RelativePath "dashboards/hybrid-signoff-dashboard-live.html"

if (-not (Test-Path $jsonPath)) { Write-Error "Missing $jsonPath" }
$jsonRaw = (Get-Content $jsonPath -Raw -Encoding UTF8).Trim()
$htmlRaw = Get-Content $template -Raw -Encoding UTF8
$inject = '<script>window.__HYBRID_SIGNOFF_DATA__ = ' + $jsonRaw + ';</script>'
$marker = '<!-- HYBRID_SIGNOFF_INJECT -->'
if ($htmlRaw -notlike "*$marker*") {
    Write-Error "Template missing HYBRID_SIGNOFF_INJECT marker"
}
$liveHtml = $htmlRaw.Replace($marker, $inject)
$liveHtml | Set-Content -Path $livePath -Encoding UTF8

Write-Host ""
Write-Host "Hybrid Dashboard: $livePath" -ForegroundColor Cyan
try {
    $d = $jsonRaw | ConvertFrom-Json
    $color = if ($d.readyForHybridSignoff) { "Green" } else { "Yellow" }
    Write-Host ("readyForHybridSignoff: " + $d.readyForHybridSignoff) -ForegroundColor $color
} catch {}

if (-not $CollectOnly) {
    Start-Process $livePath
}

exit $collectExit
