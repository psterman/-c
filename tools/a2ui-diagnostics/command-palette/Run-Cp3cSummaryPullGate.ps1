# CP3c: frontend first-pull recent 20 summaries from hub GET /v1/palette/state/summary.
param(
    [switch]$JsonOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Get-DiagRepoRoot -From $here
$dbg = Join-Path $repo "Cache\debug"
$gatePath = Join-Path $dbg "cp3c_summary_pull_gate.json"
$cp3bGatePath = Join-Path $dbg "cp3b_summary_store_gate.json"
$hubAddr = "127.0.0.1:18791"
$shadowUrl = "http://${hubAddr}/v1/palette/state/shadow"
$summaryUrl = "http://${hubAddr}/v1/palette/state/summary"
$cpHtml = Join-Path $repo "html\CommandPalette.html"
$syncJs = Join-Path $repo "html\palette\agent\agent-card-sync.js"

function Get-SourceText([string]$path) {
    if (-not (Test-Path $path)) { return "" }
    return Get-Content $path -Encoding UTF8 -Raw
}

function Get-JsonFile([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    return Get-Content $path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Invoke-HubShadowWrite([object]$body) {
    $json = $body | ConvertTo-Json -Depth 12 -Compress
    return Invoke-RestMethod -Method Post -Uri $shadowUrl -Body $json -ContentType "application/json; charset=utf-8" -TimeoutSec 8
}

function Invoke-HubSummaryRead {
    try { return Invoke-RestMethod -Method Get -Uri $summaryUrl -TimeoutSec 5 } catch { return $null }
}

Write-Host ""
Write-Host "=== CP3c Summary Pull Gate ===" -ForegroundColor Cyan

$checks = @()
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

$cp3b = Get-JsonFile $cp3bGatePath
$cp3bPass = $cp3b -and [bool]$cp3b.overallPass
$checks += @{ name = "cp3b_prerequisite"; pass = $cp3bPass; value = $(if ($cp3bPass) { "pass" } else { "missing_or_fail" }) }
if (-not $cp3bPass) {
    [void]$failures.Add("cp3b_summary_store_gate.json overallPass!=true")
}

if (-not (Ensure-DiagNmerHub -RepoRoot $repo -WarmupSec 2)) {
    [void]$failures.Add("nmer-hub not running")
    $checks += @{ name = "hub_running"; pass = $false; value = $false }
} else {
    $checks += @{ name = "hub_running"; pass = $true; value = $true }
}

$flags = Get-JsonFile (Join-Path $repo "local\nmer-flags.json")
$stateStore = $false
$shadowFlag = $false
if ($flags -and $flags.palette) {
    $stateStore = [bool]$flags.palette.stateStore
    $shadowFlag = [bool]$flags.palette.stateStoreShadow
}
$checks += @{ name = "stateStore_flag"; pass = $stateStore; value = $stateStore }
$checks += @{ name = "stateStoreShadow_flag"; pass = $shadowFlag; value = $shadowFlag }
if (-not $stateStore) { [void]$failures.Add("palette.stateStore!=true") }
if (-not $shadowFlag) { [void]$failures.Add("palette.stateStoreShadow!=true") }

$htmlOk = $false
$htmlHubPull = $false
if (Test-Path $cpHtml) {
    $htmlText = Get-SourceText $cpHtml
    $syncText = Get-SourceText $syncJs
    $combined = $htmlText + "`n" + $syncText
    $htmlHubPull = $combined -match "fetchAgentSummaryFromHub"
    $htmlOk = $combined -match "/v1/palette/state/summary" `
        -and $combined -match "paletteStateStoreShadowEnabled" `
        -and $combined -match "hub_summary_pull" `
        -and $htmlHubPull
}
$checks += @{ name = "html_summary_pull_wired"; pass = $htmlOk; value = $htmlOk }
$checks += @{ name = "html_hub_fetch_helper"; pass = $htmlHubPull; value = $htmlHubPull }
if (-not $htmlOk) { [void]$failures.Add("CommandPalette.html / agent-card-sync.js missing CP3c hub summary pull wiring") }

$probeSeq = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
$probeCards = @()
for ($i = 0; $i -lt 25; $i++) {
    $probeCards += @{ cardId = ("cp3c_probe_{0:D2}" -f $i); title = "CP3c probe"; summaryOnly = $true; rawAnswer = "short" }
}
$writeOk = $false
try {
    $null = Invoke-HubShadowWrite @{
        source    = "cp3c_gate_probe"
        writeSeq  = $probeSeq
        writeKind = "summary"
        summary   = $true
        cards     = $probeCards
    }
    $writeOk = $true
} catch {
    [void]$failures.Add("summary write probe failed: $($_.Exception.Message)")
}
$checks += @{ name = "summary_write_probe"; pass = $writeOk; value = $writeOk }
if (-not $writeOk) { [void]$failures.Add("summary_write_probe failed") }

$summary = Invoke-HubSummaryRead
$summaryEnvelopeOk = $null -ne $summary -and [bool]$summary.summary -and [bool]$summary.ready
$summaryCount = if ($summary -and $summary.cards) { @($summary.cards).Count } else { 0 }
$summaryLimitOk = $summaryCount -le 20 -and $summaryCount -eq 20
$checks += @{
    name  = "summary_get_envelope"
    pass  = $summaryEnvelopeOk
    value = $(if ($summaryEnvelopeOk) { "summary+ready" } else { "fail" })
}
$checks += @{
    name  = "summary_get_caps_20"
    pass  = $summaryLimitOk
    value = $summaryCount
}
if (-not $summaryEnvelopeOk) { [void]$failures.Add("GET /v1/palette/state/summary missing summary/ready") }
if (-not $summaryLimitOk) { [void]$failures.Add("summary pull must return exactly 20 cards when 25 written") }

$hasAhkSummary = $false
$shadowFile = Join-Path $dbg "palette_state_shadow.jsonl"
if (Test-Path $shadowFile) {
    foreach ($line in (Get-Content $shadowFile -Encoding UTF8 | Where-Object { $_.Trim() })) {
        try {
            $row = $line | ConvertFrom-Json
            if ([string]$row.source -eq "ahk" -and ([string]$row.writeKind -eq "summary" -or [bool]$row.summary)) {
                $hasAhkSummary = $true
                break
            }
        } catch { }
    }
}
$checks += @{ name = "ahk_summary_mirror"; pass = $true; value = $(if ($hasAhkSummary) { "ahk" } else { "pending (optional)" }) }
if (-not $hasAhkSummary) {
    [void]$warnings.Add("no ahk summary mirror yet — reload 牛马.ahk and open CP action tab")
}

$overallPass = ($failures.Count -eq 0)
$report = [ordered]@{
    generatedAt  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    phase        = "CP3c"
    mode         = "summary_pull_first"
    overallPass  = $overallPass
    failReason   = if ($overallPass) { "" } else { ($failures -join "; ") }
    warnings     = @($warnings)
    checks       = $checks
    summaryRead  = $summary
    summaryUrl   = $summaryUrl
    nextStep     = if ($overallPass) { "CP3d: detail lazy-load by cardId" } else { "fix failures then re-run Run-Cp3cSummaryPullGate.ps1" }
}

$report | ConvertTo-Json -Depth 8 | Set-Content -Path $gatePath -Encoding UTF8
if ($JsonOnly) {
    $report | ConvertTo-Json -Depth 8
    exit $(if ($overallPass) { 0 } else { 1 })
}

foreach ($c in $checks) {
    $color = if ($c.pass) { "Green" } else { "Red" }
    Write-Host ("  {0}: {1} -> {2}" -f $c.name, $c.value, $(if ($c.pass) { "PASS" } else { "FAIL" })) -ForegroundColor $color
}
if ($warnings.Count -gt 0) {
    Write-Host ""
    foreach ($w in $warnings) { Write-Host ("  WARN: {0}" -f $w) -ForegroundColor Yellow }
}
Write-Host ""
Write-Host ("overall: {0}" -f $(if ($overallPass) { "PASS" } else { "FAIL" })) -ForegroundColor $(if ($overallPass) { "Green" } else { "Red" })
Write-Host ("report: {0}" -f $gatePath) -ForegroundColor DarkGray
if ($overallPass) { Write-Host "Next: CP3d detail lazy-load by cardId" -ForegroundColor Green }
exit $(if ($overallPass) { 0 } else { 1 })
