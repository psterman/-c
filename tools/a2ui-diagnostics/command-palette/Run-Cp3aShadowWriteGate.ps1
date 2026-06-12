# CP3a shadow write gate: hub PaletteStateShadowStore receives mirror writes.
# Default: shadow endpoint checks only (does NOT reload AHK / re-run full PerfGate).
param(
    [switch]$WithPerfRecheck,
    [switch]$SkipPerfRecheck,
    [switch]$JsonOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Get-DiagRepoRoot -From $here
$dbg = Join-Path $repo "Cache\debug"
$gatePath = Join-Path $dbg "cp3a_shadow_write_gate.json"
$perfGatePath = Join-Path $dbg "command_palette_perf_gate.json"
$hubAddr = "127.0.0.1:18791"
$shadowUrl = "http://${hubAddr}/v1/palette/state/shadow"
$statusUrl = "http://${hubAddr}/v1/palette/state/shadow/status"

function Get-JsonFile([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    return Get-Content $path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Invoke-HubShadowStatus {
    try {
        return Invoke-RestMethod -Method Get -Uri $statusUrl -TimeoutSec 5
    } catch {
        return $null
    }
}

function Invoke-HubShadowWrite([object]$body) {
    $json = $body | ConvertTo-Json -Depth 12 -Compress
    return Invoke-RestMethod -Method Post -Uri $shadowUrl -Body $json -ContentType "application/json; charset=utf-8" -TimeoutSec 8
}

$doPerfRecheck = $WithPerfRecheck -and -not $SkipPerfRecheck

Write-Host ""
Write-Host "=== CP3a Shadow Write Gate ===" -ForegroundColor Cyan

$checks = @()
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

$perf = Get-JsonFile $perfGatePath
$perfPass = $perf -and [bool]$perf.overallPass
$checks += @{ name = "phase_e_perf_gate"; pass = $perfPass; value = $(if ($perfPass) { "overallPass=true" } else { "missing_or_fail" }) }
if (-not $perfPass) {
    [void]$failures.Add("phase_e_perf_gate: command_palette_perf_gate.json overallPass!=true")
}

if (-not (Ensure-DiagNmerHub -RepoRoot $repo -WarmupSec 2)) {
    [void]$failures.Add("nmer-hub not running and could not auto-start (build apps/nmer-hub first)")
    $checks += @{ name = "hub_running"; pass = $false; value = $false }
} else {
    $checks += @{ name = "hub_running"; pass = $true; value = $true }
}

$flagsPath = Join-Path $repo "local\nmer-flags.json"
$flags = Get-JsonFile $flagsPath
$shadowFlag = $false
if ($flags -and $flags.palette) {
    $shadowFlag = [bool]$flags.palette.stateStoreShadow
}
$checks += @{ name = "stateStoreShadow_flag"; pass = $shadowFlag; value = $shadowFlag }
if (-not $shadowFlag) {
    [void]$failures.Add("palette.stateStoreShadow!=true in local/nmer-flags.json")
}

$before = Invoke-HubShadowStatus
$endpointReady = $null -ne $before -and ([string]$before.mode -eq "shadow_write_only" -or [string]$before.mode -eq "summary_shadow_write")
$checks += @{ name = "shadow_endpoint"; pass = $endpointReady; value = $(if ($before) { $before.mode } else { "unreachable" }) }
if (-not $endpointReady) {
    [void]$failures.Add("GET /v1/palette/state/shadow/status failed (rebuild + restart nmer-hub with CP3a routes)")
}

$writeOk = $false
$after = $before
if ($endpointReady) {
    $probeSeq = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
    try {
        $after = Invoke-HubShadowWrite @{
            source   = "cp3a_gate_probe"
            writeSeq = $probeSeq
            cards    = @(@{ cardId = "cp3a_probe"; title = "CP3a gate probe"; summaryOnly = $false })
        }
        $writeOk = $null -ne $after -and [int64]$after.writeSeq -ge $probeSeq
    } catch {
        [void]$failures.Add("POST shadow write failed: $($_.Exception.Message)")
    }
}
$checks += @{ name = "shadow_write_probe"; pass = $writeOk; value = $(if ($after) { $after.writeSeq } else { 0 }) }
if (-not $writeOk) {
    [void]$failures.Add("shadow_write_probe failed")
}

$shadowFile = if ($after -and $after.shadowFile) { [string]$after.shadowFile } else { Join-Path $dbg "palette_state_shadow.jsonl" }
$fileExists = Test-Path $shadowFile
$checks += @{ name = "shadow_jsonl_exists"; pass = $fileExists; value = $shadowFile }
if (-not $fileExists) {
    [void]$failures.Add("shadow jsonl missing: $shadowFile")
}

$ahkMirrorPass = $null
if ($endpointReady -and $after -and [int64]$after.writeSeq -gt 0) {
    $lines = @()
    if (Test-Path $shadowFile) {
        $lines = @(Get-Content $shadowFile -Encoding UTF8 | Where-Object { $_.Trim() })
    }
    $hasAhkSource = $false
    foreach ($line in $lines) {
        try {
            $row = $line | ConvertFrom-Json
            if ([string]$row.source -eq "ahk") { $hasAhkSource = $true; break }
        } catch { }
    }
    $checks += @{
        name  = "ahk_mirror_seen"
        pass  = $true
        value = $(if ($hasAhkSource) { "ahk" } else { "pending (optional)" })
    }
    if (-not $hasAhkSource) {
        [void]$warnings.Add("no ahk source line in shadow jsonl yet (open CP / trigger agent persist after 牛马.ahk reload)")
    }
}

$perfRecheckPass = $true
$perfRecheckNote = "skipped (default; use -WithPerfRecheck for full PerfGate regression)"
if ($doPerfRecheck) {
    $perfRecheckNote = ""
    if (-not $perfPass) {
        $perfRecheckPass = $false
        $perfRecheckNote = "skipped: phase_e_perf_gate not pass"
    } else {
        Write-Host "  Optional PerfGate regression (-WithPerfRecheck)..." -ForegroundColor DarkGray
        try {
            if (-not (Get-Process -Name "AutoHotkey64" -ErrorAction SilentlyContinue)) {
                [void]$warnings.Add("AutoHotkey64 not running; perf recheck may start 牛马.ahk")
            }
            & (Join-Path $here "Run-CommandPalettePerfAutomated.ps1") -NoArchive -SkipReload
            if ($LASTEXITCODE -ne 0) { $perfRecheckPass = $false }
            $perf2 = Get-JsonFile $perfGatePath
            $perfRecheckPass = $perf2 -and [bool]$perf2.overallPass
            if (-not $perfRecheckPass) { $perfRecheckNote = "overallPass regressed" }
        } catch {
            $perfRecheckPass = $false
            $perfRecheckNote = $_.Exception.Message
        }
    }
    $checks += @{ name = "perf_gate_recheck"; pass = $perfRecheckPass; value = $(if ($perfRecheckPass) { "pass" } else { $perfRecheckNote }) }
    if (-not $perfRecheckPass) {
        [void]$failures.Add("perf_gate_recheck: $perfRecheckNote")
    }
} else {
    $checks += @{ name = "perf_gate_recheck"; pass = $true; value = "deferred" }
}

$overallPass = ($failures.Count -eq 0)
$report = [ordered]@{
    generatedAt    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    phase          = "CP3a"
    mode           = "shadow_write_only"
    overallPass    = $overallPass
    failReason     = if ($overallPass) { "" } else { ($failures -join "; ") }
    warnings       = @($warnings)
    checks         = $checks
    shadowStatus   = $after
    perfGatePath   = $perfGatePath
    shadowFile     = $shadowFile
    perfRecheck    = $perfRecheckNote
    nextStep       = if ($overallPass) { "CP3b: summary DTO write to Go store" } else { "fix failures then re-run Run-Cp3aShadowWriteGate.ps1" }
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
    foreach ($w in $warnings) {
        Write-Host ("  WARN: {0}" -f $w) -ForegroundColor Yellow
    }
}
Write-Host ""
Write-Host ("overall: {0}" -f $(if ($overallPass) { "PASS" } else { "FAIL" })) -ForegroundColor $(if ($overallPass) { "Green" } else { "Red" })
Write-Host ("report: {0}" -f $gatePath) -ForegroundColor DarkGray
if (-not $doPerfRecheck) {
    Write-Host "PerfGate regression deferred (add -WithPerfRecheck to run full capture)" -ForegroundColor DarkGray
}
if ($overallPass) {
    Write-Host "Next: CP3b summary DTO -> Go store" -ForegroundColor Green
}
exit $(if ($overallPass) { 0 } else { 1 })
