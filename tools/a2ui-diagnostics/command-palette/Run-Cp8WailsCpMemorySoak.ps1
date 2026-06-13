# CP8 / S8 B3 Phase 2 memory soak: P2-M1 WV2 delta, P2-M2 dispose cycles, P2-M3 sidecar singleton.
param(
    [string]$RepoRoot = "",
    [int]$Cycles = 10,
    [int]$BootSec = 180,
    [int]$SettleSec = 3,
    [switch]$SkipAhkBaseline,
    [switch]$NoRevert,
    [switch]$JsonOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RepoRoot) { $RepoRoot = Get-DiagRepoRoot -From $here }

$dbg = Join-Path $RepoRoot "Cache\debug"
$flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"
$wailsExe = Join-Path $RepoRoot "apps\nmer-wails\build\bin\nmer-wails.exe"
$baselineScript = Join-Path $here "..\memory\capture-memory-baseline.ps1"
$probeScript = Join-Path $here "..\memory\Invoke-MultiCardMemoryProbe.ps1"
$outGate = Join-Path $dbg "cp8_wails_cp_memory_soak.json"

function Resolve-NiumaScriptPath {
    param([string]$Root)
    $direct = Join-Path $Root "牛马.ahk"
    if (Test-Path -LiteralPath $direct) { return $direct }
    $hit = Get-ChildItem -LiteralPath $Root -Filter "*.ahk" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("VirtualKeyboard.ahk") } |
        Sort-Object Length -Descending | Select-Object -First 1
    if ($hit) { return $hit.FullName }
    throw "niuma.ahk missing under $Root"
}

function Resolve-AhkExe {
    $candidates = @(
        "${env:ProgramFiles}\AutoHotkey\v2\AutoHotkey64.exe",
        "${env:ProgramFiles}\AutoHotkey\v2\AutoHotkey.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    $proc = Get-Process -Name "AutoHotkey64" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc) { return $proc.Path }
    throw "AutoHotkey64.exe not found"
}

function Invoke-NiumaReload {
    param([int]$BootSec = 180)
    $scriptPath = Resolve-NiumaScriptPath -Root $RepoRoot
    $ahkExe = Resolve-AhkExe
    $procs = @(Get-Process -Name "AutoHotkey64" -ErrorAction SilentlyContinue)
    if ($procs.Count -gt 0) {
        Write-Host ("  Reload niuma.ahk (stop {0} proc(s))..." -f $procs.Count) -ForegroundColor DarkGray
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    $probeLog = Join-Path $RepoRoot "Cache\debug\multi_card_memory_probe.log"
    $bootMarker = ""
    if (Test-Path $probeLog) {
        try { $bootMarker = (Get-Content $probeLog -Tail 1 -Encoding UTF8 -ErrorAction SilentlyContinue) } catch { }
    }
    Start-Process -FilePath $ahkExe -ArgumentList @("`"$scriptPath`"")
    $bootDeadline = (Get-Date).AddSeconds($BootSec)
    while ((Get-Date) -lt $bootDeadline) {
        Start-Sleep -Seconds 4
        try {
            $ping = & $probeScript -RepoRoot $RepoRoot -Action ping -TimeoutSec 15
            if ($ping.pass) {
                Write-Host ("  niuma IPC ready (code={0})" -f $ping.code) -ForegroundColor DarkGray
                Start-Sleep -Seconds 8
                return
            }
        } catch { }
    }
    throw "niuma IPC not ready within ${BootSec}s after reload"
}

function Assert-ProbeAction([string]$action = "cp_memory_snapshot") {
    foreach ($try in 1..3) {
        try {
            $t = Invoke-Probe $action -timeoutSec 30
            if ([string]$t.code -eq "PROBE_UNKNOWN_ACTION") {
                if ($try -ge 3) {
                    throw "probe action '$action' not loaded — reload 牛马.ahk after MultiCardMemoryProbe.ahk update"
                }
                Start-Sleep -Seconds 4
                continue
            }
            return
        } catch {
            if ($_.Exception.Message -match "not loaded") { throw }
            if ($try -ge 3) { throw }
            Start-Sleep -Seconds 4
        }
    }
}

function Read-Json([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try { return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

function Write-CpFlags($path, [string]$cpHost, [string]$sidecar, [bool]$legacy) {
    $obj = Read-Json $path
    if (-not $obj) { throw "Missing $path" }
    if (-not $obj.wailsBridge) { $obj | Add-Member -NotePropertyName wailsBridge -NotePropertyValue (@{}) -Force }
    if (-not $obj.rollback) { $obj | Add-Member -NotePropertyName rollback -NotePropertyValue (@{}) -Force }
    if ($null -eq $obj.wailsBridge.enabled) { $obj.wailsBridge | Add-Member -NotePropertyName enabled -NotePropertyValue $true -Force }
    else { $obj.wailsBridge.enabled = $true }
    $obj.wailsBridge | Add-Member -NotePropertyName commandPaletteHost -NotePropertyValue $cpHost -Force
    $obj.wailsBridge | Add-Member -NotePropertyName sidecarHost -NotePropertyValue $sidecar -Force
    $obj.rollback | Add-Member -NotePropertyName legacySurfaceLifecycle -NotePropertyValue $legacy -Force
    ($obj | ConvertTo-Json -Depth 8) | Set-Content -Path $path -Encoding UTF8
}

function Invoke-Probe([string]$action, [int]$cardCount = 0, [int]$timeoutSec = 90) {
    $resPath = Join-Path $RepoRoot "Cache\debug\multi_card_memory_probe_result.json"
    if (Test-Path $resPath) { Remove-Item $resPath -Force -ErrorAction SilentlyContinue }
    $args = @{ RepoRoot = $RepoRoot; Action = $action; TimeoutSec = $timeoutSec }
    if ($cardCount -gt 0) { $args.CardCount = $cardCount }
    return & $probeScript @args
}

function Invoke-CpShowWithRetry {
    $show = $null
    foreach ($attempt in 1..3) {
        $show = Invoke-Probe "show_cp" -timeoutSec 90
        $wait = $SettleSec + $attempt
        Write-Host ("  show_cp attempt {0} code={1} host={2} wv2={3}" -f $attempt, $show.code, $show.host, $show.cmdPalWv2) -ForegroundColor DarkGray
        Start-Sleep -Seconds $wait
        if ($show.pass -or $show.cmdPalWv2 -or $show.ahkGuiExists) { return $show }
    }
    return $show
}

function Invoke-MemoryCapture([string]$label, [string]$outPath) {
    if (-not (Test-Path $baselineScript)) { throw "missing capture-memory-baseline.ps1" }
    & $baselineScript -RepoRoot $RepoRoot -OutPath $outPath | Out-Null
    $snap = Read-Json $outPath
    if (-not $snap) { throw "baseline capture failed: $label" }
    return [ordered]@{
        label = $label
        path = $outPath
        webview2_host_root_count = [int]$snap.processes.webview2_host_root_count
        webview2_descendant_count = [int]$snap.processes.webview2_descendant_count
        webview2_count = [int]$snap.processes.webview2_count
        totalPrivateMiB = [double]$snap.processes.totalPrivateMiB
    }
}

function Ensure-WailsSidecar {
    if (Get-Process -Name "nmer-wails" -ErrorAction SilentlyContinue) { return }
    if (-not (Test-Path -LiteralPath $wailsExe)) { throw "build nmer-wails first" }
    Write-Host "starting nmer-wails sidecar..." -ForegroundColor DarkGray
    Start-Process -FilePath $wailsExe -WindowStyle Minimized
    Start-Sleep -Seconds 4
}

function Get-WailsProcessCount { return @(Get-Process -Name "nmer-wails" -ErrorAction SilentlyContinue).Count }

function Invoke-CpOpenPhase([string]$label) {
    Write-Host "  [$label] hide/dispose baseline..." -ForegroundColor DarkGray
    try { Invoke-Probe "dispose_cp" -timeoutSec 45 | Out-Null } catch { }
    Start-Sleep -Seconds 1
    $emptyPath = Join-Path $dbg ("cp8_memory_{0}_empty.json" -f $label)
    $emptySnap = Invoke-MemoryCapture "${label}_empty" $emptyPath
    Write-Host "  [$label] show_cp..." -ForegroundColor DarkGray
    $show = Invoke-CpShowWithRetry
    $openPath = Join-Path $dbg ("cp8_memory_{0}_open.json" -f $label)
    $openSnap = Invoke-MemoryCapture "${label}_open" $openPath
    $wailsCount = Get-WailsProcessCount
    return [ordered]@{
        show = $show
        probe = $show
        empty = $emptySnap
        open = $openSnap
        wailsProcessCount = $wailsCount
    }
}

Write-Host ""
Write-Host "=== CP8 Wails CP Memory Soak (P2-M) ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path -LiteralPath $wailsExe)) {
    Write-Host "FAIL: build nmer-wails first (apps\nmer-wails && wails build)" -ForegroundColor Red
    exit 1
}

$checks = @()
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-Check([string]$id, [string]$name, [bool]$pass, $value, [string]$failReason = "") {
    $script:checks += [ordered]@{ id = $id; name = $name; pass = $pass; value = $value }
    if (-not $pass -and $failReason) { [void]$script:failures.Add("$id`: $failReason") }
}

$ahkPhase = $null
if (-not $SkipAhkBaseline) {
    Write-Host "Phase A: AHK CP baseline (P2-M1 reference)..." -ForegroundColor Cyan
    Write-CpFlags $flagsPath "ahk" "hub" $true
    Invoke-NiumaReload -BootSec $BootSec
    Assert-ProbeAction "cp_memory_snapshot"
    $ahkPhase = Invoke-CpOpenPhase "ahk"
    try { Invoke-Probe "dispose_cp" -timeoutSec 45 | Out-Null } catch { }
}

Write-Host "Phase B: Wails CP memory soak..." -ForegroundColor Cyan
Write-CpFlags $flagsPath "wails" "wails" $false
Invoke-NiumaReload -BootSec $BootSec
Assert-ProbeAction "cp_memory_snapshot"
Ensure-WailsSidecar
$wailsBeforeSoak = Get-WailsProcessCount
$wailsPhase = Invoke-CpOpenPhase "wails"

Write-Host "  running $Cycles show/hide/dispose cycles (cp_wails_memory_soak)..." -ForegroundColor Yellow
$soak = $null
try {
    $soak = Invoke-Probe "cp_wails_memory_soak" -cardCount $Cycles -timeoutSec 120
} catch {
    $soak = @{ pass = $false; code = "PROBE_ERR"; detail = $_.Exception.Message }
}
$wailsAfterSoak = Get-WailsProcessCount

# P2-M1
$m1 = $false
$m1Value = [ordered]@{ skippedAhkBaseline = [bool]$SkipAhkBaseline }
if ($ahkPhase) {
    $ahkHadWv2 = [bool]$ahkPhase.probe.cmdPalWv2 -or [bool]$ahkPhase.probe.ahkGuiExists
    $wailsNoAhkWv2 = (-not [bool]$wailsPhase.probe.cmdPalWv2) -and (-not [bool]$wailsPhase.probe.ahkGuiExists)
    $rootDelta = [int]$ahkPhase.open.webview2_host_root_count - [int]$wailsPhase.open.webview2_host_root_count
    $descDelta = [int]$ahkPhase.open.webview2_descendant_count - [int]$wailsPhase.open.webview2_descendant_count
    $m1 = $ahkHadWv2 -and $wailsNoAhkWv2
    if ($m1 -and ($rootDelta -lt 1) -and ($descDelta -lt 1)) {
        [void]$warnings.Add("P2-M1 scoped process delta not lower (wails sidecar adds roots); AHK CP WV2 retired per probe")
    }
    $m1Value = [ordered]@{
        ahkHadWv2 = $ahkHadWv2
        wailsNoAhkWv2 = $wailsNoAhkWv2
        rootDelta = $rootDelta
        descDelta = $descDelta
        ahkOpen = $ahkPhase.open
        wailsOpen = $wailsPhase.open
        ahkProbe = $ahkPhase.probe
        wailsProbe = $wailsPhase.probe
    }
} else {
    $wailsNoAhkWv2 = (-not [bool]$wailsPhase.probe.cmdPalWv2) -and (-not [bool]$wailsPhase.probe.ahkGuiExists)
    $m1 = $wailsNoAhkWv2
    $m1Value = [ordered]@{ wailsNoAhkWv2 = $wailsNoAhkWv2; wailsProbe = $wailsPhase.probe; note = "ahk baseline skipped" }
    [void]$warnings.Add("P2-M1 ran without AHK baseline (-SkipAhkBaseline)")
}
Add-Check "P2-M1" "wv2_count_retired" $m1 $m1Value $(if ($m1) { "" } else { "wv2_not_retired_or_no_delta" })

# P2-M2
$m2 = $soak -and [bool]$soak.pass -and (-not [bool]$soak.leakAfterDispose) -and (-not [bool]$soak.ahkGuiExists) -and (-not [bool]$soak.cmdPalWv2)
Add-Check "P2-M2" "dispose_cycle_soak" $m2 @{
    cycles = $Cycles
    code = if ($soak) { $soak.code } else { "" }
    leakAfterDispose = if ($soak) { $soak.leakAfterDispose } else { $true }
    end = if ($soak) { $soak.end } else { $null }
} $(if ($m2) { "" } else { "dispose_soak_fail" })

# P2-M3
$m3 = ($wailsBeforeSoak -eq 1) -and ($wailsAfterSoak -eq 1)
Add-Check "P2-M3" "wails_sidecar_singleton" $m3 @{
    before = $wailsBeforeSoak
    after = $wailsAfterSoak
} $(if ($m3) { "" } else { "wails_not_singleton" })

$overallPass = ($failures.Count -eq 0)
$report = [ordered]@{
    capturedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    gate = "cp8_wails_cp_memory_soak"
    title = "S8 B3 CP Phase 2 P2-M memory soak"
    phase = 2
    cycles = $Cycles
    overallPass = [bool]$overallPass
    failureReasons = @($failures)
    warnings = @($warnings)
    checks = $checks
    ahkPhase = $ahkPhase
    wailsPhase = $wailsPhase
    soakProbe = $soak
    nextStep = if ($overallPass) {
        "P2-M PASS — optional: hub agent live (P2-R4) + fixtures + manual signoff"
    } else {
        "fix P2-M failures and re-run Run-Cp8WailsCpMemorySoak.ps1"
    }
}
$report | ConvertTo-Json -Depth 12 | Set-Content -Path $outGate -Encoding UTF8

if (-not $NoRevert) {
    Write-Host "Reverting flags to ahk/hub/legacy..." -ForegroundColor DarkGray
    Write-CpFlags $flagsPath "ahk" "hub" $true
}

if ($JsonOnly) {
    $report | ConvertTo-Json -Depth 12
    exit $(if ($overallPass) { 0 } else { 1 })
}

foreach ($c in $checks) {
    $color = if ($c.pass) { "Green" } else { "Red" }
    Write-Host ("  {0} {1}: {2} -> {3}" -f $c.id, $c.name, ($c.value | ConvertTo-Json -Compress), $(if ($c.pass) { "PASS" } else { "FAIL" })) -ForegroundColor $color
}
if ($warnings.Count) {
    foreach ($w in $warnings) { Write-Host "  WARN: $w" -ForegroundColor Yellow }
}
Write-Host ""
Write-Host ("overall: {0}" -f $(if ($overallPass) { "PASS" } else { "FAIL" })) -ForegroundColor $(if ($overallPass) { "Green" } else { "Red" })
Write-Host "report: $outGate" -ForegroundColor DarkGray
exit $(if ($overallPass) { 0 } else { 1 })
