# CP3b: AHK summary DTO -> Go shadow store (max 20, no blockStore).
param(
    [switch]$JsonOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Get-DiagRepoRoot -From $here
$dbg = Join-Path $repo "Cache\debug"
$gatePath = Join-Path $dbg "cp3b_summary_store_gate.json"
$cp3aGatePath = Join-Path $dbg "cp3a_shadow_write_gate.json"
$hubAddr = "127.0.0.1:18791"
$shadowUrl = "http://${hubAddr}/v1/palette/state/shadow"
$statusUrl = "http://${hubAddr}/v1/palette/state/shadow/status"

function Get-JsonFile([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    return Get-Content $path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Invoke-HubShadowStatus {
    try { return Invoke-RestMethod -Method Get -Uri $statusUrl -TimeoutSec 5 } catch { return $null }
}

function Invoke-HubShadowWrite([object]$body) {
    $json = $body | ConvertTo-Json -Depth 12 -Compress
    return Invoke-RestMethod -Method Post -Uri $shadowUrl -Body $json -ContentType "application/json; charset=utf-8" -TimeoutSec 8
}

function Invoke-HubShadowWriteExpectFail([object]$body) {
    $json = $body | ConvertTo-Json -Depth 12 -Compress
    try {
        Invoke-RestMethod -Method Post -Uri $shadowUrl -Body $json -ContentType "application/json; charset=utf-8" -TimeoutSec 8 | Out-Null
        return $false
    } catch {
        return $true
    }
}

Write-Host ""
Write-Host "=== CP3b Summary Store Gate ===" -ForegroundColor Cyan

$checks = @()
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

$cp3a = Get-JsonFile $cp3aGatePath
$cp3aPass = $cp3a -and [bool]$cp3a.overallPass
$checks += @{ name = "cp3a_prerequisite"; pass = $cp3aPass; value = $(if ($cp3aPass) { "pass" } else { "missing_or_fail" }) }
if (-not $cp3aPass) {
    [void]$failures.Add("cp3a_shadow_write_gate.json overallPass!=true")
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

$probeSeq = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
$summaryOk = $false
$after = $null
try {
    $after = Invoke-HubShadowWrite @{
        source    = "cp3b_gate_probe"
        writeSeq  = $probeSeq
        writeKind = "summary"
        summary   = $true
        cards     = @(@{ cardId = "cp3b_probe"; title = "CP3b summary probe"; summaryOnly = $true; rawAnswer = "short" })
    }
    $summaryOk = $null -ne $after -and [string]$after.writeKind -eq "summary" -and [bool]$after.summaryOnly
} catch {
    [void]$failures.Add("summary write probe failed: $($_.Exception.Message)")
}
$checks += @{ name = "summary_write_probe"; pass = $summaryOk; value = $(if ($after) { $after.writeKind } else { "fail" }) }
if (-not $summaryOk) { [void]$failures.Add("summary_write_probe failed") }

$rejectOk = Invoke-HubShadowWriteExpectFail @{
    source    = "cp3b_gate_bad"
    writeSeq  = ($probeSeq + 1)
    writeKind = "summary"
    summary   = $true
    cards     = @(@{ cardId = "bad"; summaryOnly = $true; blockStore = @{ blocks = @() } })
}
$checks += @{ name = "summary_rejects_blockStore"; pass = $rejectOk; value = $rejectOk }
if (-not $rejectOk) { [void]$failures.Add("hub must reject summary payload containing blockStore") }

$shadowFile = if ($after -and $after.shadowFile) { [string]$after.shadowFile } else { Join-Path $dbg "palette_state_shadow.jsonl" }
$hasSummaryLine = $false
$hasAhkSummary = $false
if (Test-Path $shadowFile) {
    foreach ($line in (Get-Content $shadowFile -Encoding UTF8 | Where-Object { $_.Trim() })) {
        try {
            $row = $line | ConvertFrom-Json
            if ([string]$row.writeKind -eq "summary" -or [bool]$row.summary) { $hasSummaryLine = $true }
            if ([string]$row.source -eq "ahk" -and ([string]$row.writeKind -eq "summary" -or [bool]$row.summary)) { $hasAhkSummary = $true }
        } catch { }
    }
}
$checks += @{ name = "summary_jsonl_seen"; pass = $hasSummaryLine; value = $hasSummaryLine }
if (-not $hasSummaryLine) { [void]$failures.Add("no summary writeKind line in shadow jsonl") }

$checks += @{ name = "ahk_summary_mirror"; pass = $true; value = $(if ($hasAhkSummary) { "ahk" } else { "pending (optional)" }) }
if (-not $hasAhkSummary) {
    [void]$warnings.Add("no ahk summary mirror yet — reload 牛马.ahk and trigger agent persist")
}

$overallPass = ($failures.Count -eq 0)
$report = [ordered]@{
    generatedAt  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    phase        = "CP3b"
    mode         = "summary_shadow_write"
    overallPass  = $overallPass
    failReason   = if ($overallPass) { "" } else { ($failures -join "; ") }
    warnings     = @($warnings)
    checks       = $checks
    shadowStatus = $after
    shadowFile   = $shadowFile
    nextStep     = if ($overallPass) { "CP3c: frontend pull recent 20 summaries only" } else { "fix failures then re-run Run-Cp3bSummaryStoreGate.ps1" }
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
if ($overallPass) { Write-Host "Next: CP3c frontend summary-only pull" -ForegroundColor Green }
exit $(if ($overallPass) { 0 } else { 1 })
