# CP3d: lazy-load full card detail (blockStore) by cardId via hub GET /v1/palette/state/detail.
param(
    [switch]$JsonOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Get-DiagRepoRoot -From $here
$dbg = Join-Path $repo "Cache\debug"
$gatePath = Join-Path $dbg "cp3d_detail_lazy_load_gate.json"
$cp3cGatePath = Join-Path $dbg "cp3c_summary_pull_gate.json"
$hubAddr = "127.0.0.1:18791"
$detailUrl = "http://${hubAddr}/v1/palette/state/detail"
$cpHtml = Join-Path $repo "html\CommandPalette.html"

function Get-JsonFile([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    return Get-Content $path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Invoke-HubDetailWrite([object]$body) {
    $json = $body | ConvertTo-Json -Depth 16 -Compress
    return Invoke-RestMethod -Method Post -Uri $detailUrl -Body $json -ContentType "application/json; charset=utf-8" -TimeoutSec 8
}

function Invoke-HubDetailWriteExpectFail([object]$body) {
    $json = $body | ConvertTo-Json -Depth 12 -Compress
    try {
        Invoke-RestMethod -Method Post -Uri $detailUrl -Body $json -ContentType "application/json; charset=utf-8" -TimeoutSec 8 | Out-Null
        return $false
    } catch {
        return $true
    }
}

function Invoke-HubDetailRead([string]$cardId) {
    try {
        return Invoke-RestMethod -Method Get -Uri ($detailUrl + "?cardId=" + [uri]::EscapeDataString($cardId)) -TimeoutSec 5
    } catch {
        return $null
    }
}

Write-Host ""
Write-Host "=== CP3d Detail Lazy-Load Gate ===" -ForegroundColor Cyan

$checks = @()
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

$cp3c = Get-JsonFile $cp3cGatePath
$cp3cPass = $cp3c -and [bool]$cp3c.overallPass
$checks += @{ name = "cp3c_prerequisite"; pass = $cp3cPass; value = $(if ($cp3cPass) { "pass" } else { "missing_or_fail" }) }
if (-not $cp3cPass) {
    [void]$failures.Add("cp3c_summary_pull_gate.json overallPass!=true")
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
$htmlDetailPull = $false
if (Test-Path $cpHtml) {
    $htmlText = Get-Content $cpHtml -Encoding UTF8 -Raw
    $htmlOk = $htmlText -match "/v1/palette/state/detail" -and $htmlText -match "requestAgentCardDetail" -and $htmlText -match "hub_detail_pull"
    $htmlDetailPull = $htmlText -match "applyAgentCardDetailDto"
}
$checks += @{ name = "html_detail_pull_wired"; pass = $htmlOk; value = $htmlOk }
$checks += @{ name = "html_detail_apply_helper"; pass = $htmlDetailPull; value = $htmlDetailPull }
if (-not $htmlOk) { [void]$failures.Add("CommandPalette.html missing CP3d hub detail pull wiring") }

$probeId = "cp3d_gate_probe"
$detailCard = @{
    cardId      = $probeId
    title       = "CP3d detail probe"
    summaryOnly = $false
    blockStore  = @{
        blocks           = @(@{ id = "b1"; kind = "reply"; text = "hello from cp3d gate" })
        blockVersion     = 1
        normalizerVersion = "2026-06-06"
    }
}

$writeOk = $false
$afterWrite = $null
try {
    $afterWrite = Invoke-HubDetailWrite @{
        source = "cp3d_gate_probe"
        cardId = $probeId
        card   = $detailCard
    }
    $writeOk = $null -ne $afterWrite -and [bool]$afterWrite.ready -and [bool]$afterWrite.hasBlocks
} catch {
    [void]$failures.Add("detail write probe failed: $($_.Exception.Message)")
}
$checks += @{ name = "detail_write_probe"; pass = $writeOk; value = $writeOk }
if (-not $writeOk) { [void]$failures.Add("detail_write_probe failed") }

$rejectOk = Invoke-HubDetailWriteExpectFail @{
    source = "cp3d_gate_bad"
    cardId = "bad_summary"
    card   = @{ cardId = "bad_summary"; summaryOnly = $true; rawAnswer = "short" }
}
$checks += @{ name = "detail_rejects_summary_only"; pass = $rejectOk; value = $rejectOk }
if (-not $rejectOk) { [void]$failures.Add("hub must reject summaryOnly detail without blockStore") }

$read = Invoke-HubDetailRead $probeId
$readOk = $null -ne $read -and [bool]$read.ready -and [bool]$read.hasBlocks -and [string]$read.cardId -eq $probeId
$blockCount = 0
if ($readOk -and $read.card -and $read.card.blockStore -and $read.card.blockStore.blocks) {
    $blockCount = @($read.card.blockStore.blocks).Count
}
$checks += @{
    name  = "detail_get_by_cardId"
    pass  = $readOk
    value = $(if ($readOk) { "ready+blocks=$blockCount" } else { "fail" })
}
if (-not $readOk) { [void]$failures.Add("GET detail by cardId failed") }
if ($readOk -and $blockCount -lt 1) { [void]$failures.Add("detail read missing blockStore.blocks") }

$missing = Invoke-HubDetailRead "cp3d_missing_card"
$missingOk = $null -ne $missing -and -not [bool]$missing.ready
$checks += @{ name = "detail_missing_not_ready"; pass = $missingOk; value = $missingOk }
if (-not $missingOk) { [void]$failures.Add("missing cardId should return ready=false") }

$overallPass = ($failures.Count -eq 0)
$report = [ordered]@{
    generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    phase       = "CP3d"
    mode        = "detail_lazy_load_by_cardId"
    overallPass = $overallPass
    failReason  = if ($overallPass) { "" } else { ($failures -join "; ") }
    warnings    = @($warnings)
    checks      = $checks
    detailRead  = $read
    detailUrl   = $detailUrl
    nextStep    = if ($overallPass) { "CP4: palette.agentTransport=hub gray rollout" } else { "fix failures then re-run Run-Cp3dDetailLazyLoadGate.ps1" }
}

$report | ConvertTo-Json -Depth 10 | Set-Content -Path $gatePath -Encoding UTF8
if ($JsonOnly) {
    $report | ConvertTo-Json -Depth 10
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
if ($overallPass) { Write-Host "Next: CP4 agentTransport=hub gray" -ForegroundColor Green }
exit $(if ($overallPass) { 0 } else { 1 })
