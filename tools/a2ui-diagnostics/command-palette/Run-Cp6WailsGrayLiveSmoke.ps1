# CP6 live smoke: flip CP host to wails, reload niuma, IPC show_cp, verify fresh cp_host_show.
param(
    [string]$RepoRoot = "",
    [int]$PollSec = 35,
    [int]$BootSec = 180,
    [switch]$Revert,
    [switch]$NoRevert,
    [switch]$UseCapsLock
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RepoRoot) { $RepoRoot = Get-DiagRepoRoot -From $here }

$flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"
$logPath = Join-Path $RepoRoot "Cache\debug\surface_runtime.ndjson"
$wailsExe = Join-Path $RepoRoot "apps\nmer-wails\build\bin\nmer-wails.exe"
$outPath = Join-Path $RepoRoot "Cache\debug\cp6_wails_gray_live_smoke.json"
$scriptPath = Join-Path $RepoRoot "牛马.ahk"

function Resolve-NiumaScriptPath {
    param([string]$Root)
    $direct = Join-Path $Root "牛马.ahk"
    if (Test-Path -LiteralPath $direct) { return $direct }
    $hit = Get-ChildItem -LiteralPath $Root -Filter "*.ahk" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("VirtualKeyboard.ahk") } |
        Sort-Object Length -Descending |
        Select-Object -First 1
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

function Read-Flags($path) {
    if (-not (Test-Path $path)) { return $null }
    return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-Cp6GrayFlagsLocal($path, [bool]$wailsMode) {
    $obj = Read-Flags $path
    if (-not $obj) { throw "Missing $path" }
    if (-not $obj.wailsBridge) { $obj | Add-Member -NotePropertyName wailsBridge -NotePropertyValue (@{}) -Force }
    if (-not $obj.rollback) { $obj | Add-Member -NotePropertyName rollback -NotePropertyValue (@{}) -Force }
    if ($wailsMode) {
        if ($null -eq $obj.wailsBridge.enabled) { $obj.wailsBridge | Add-Member -NotePropertyName enabled -NotePropertyValue $true -Force }
        else { $obj.wailsBridge.enabled = $true }
        $obj.wailsBridge | Add-Member -NotePropertyName commandPaletteHost -NotePropertyValue "wails" -Force
        $obj.wailsBridge | Add-Member -NotePropertyName sidecarHost -NotePropertyValue "wails" -Force
        $obj.rollback | Add-Member -NotePropertyName legacySurfaceLifecycle -NotePropertyValue $false -Force
    } else {
        $obj.wailsBridge | Add-Member -NotePropertyName commandPaletteHost -NotePropertyValue "ahk" -Force
        $obj.wailsBridge | Add-Member -NotePropertyName sidecarHost -NotePropertyValue "hub" -Force
        $obj.rollback | Add-Member -NotePropertyName legacySurfaceLifecycle -NotePropertyValue $true -Force
    }
    ($obj | ConvertTo-Json -Depth 8) | Set-Content -Path $path -Encoding UTF8
}

function Get-CpHostShowRows($path) {
    if (-not (Test-Path $path)) { return @() }
    return @(Get-Content $path -Encoding UTF8 | ForEach-Object {
        try { $_ | ConvertFrom-Json } catch { $null }
    } | Where-Object { $_ -and $_.type -eq "cp_host_show" })
}

function Get-LatestSession($rows) {
    if (-not $rows.Count) { return "" }
    return [string]$rows[-1].traceSession
}

function Invoke-NiumaReloadLocal {
    param([int]$BootSec = 180)
    $scriptPath = Resolve-NiumaScriptPath -Root $RepoRoot
    $ahkExe = Resolve-AhkExe
    $procs = @(Get-Process -Name "AutoHotkey64" -ErrorAction SilentlyContinue)
    if ($procs.Count -gt 0) {
        Write-Host ("  Reload niuma.ahk (stop {0} proc(s))..." -f $procs.Count) -ForegroundColor DarkGray
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    } else {
        Write-Host "  Starting niuma.ahk..." -ForegroundColor Yellow
    }
    $probeLog = Join-Path $RepoRoot "Cache\debug\multi_card_memory_probe.log"
    $bootMarker = ""
    if (Test-Path $probeLog) {
        try { $bootMarker = (Get-Content $probeLog -Tail 1 -Encoding UTF8 -ErrorAction SilentlyContinue) } catch { }
    }
    Start-Process -FilePath $ahkExe -ArgumentList @("`"$scriptPath`"")
    $probeScript = Join-Path $here "..\memory\Invoke-MultiCardMemoryProbe.ps1"
    $bootDeadline = (Get-Date).AddSeconds($BootSec)
    while ((Get-Date) -lt $bootDeadline) {
        Start-Sleep -Seconds 4
        $probeFresh = $false
        if (Test-Path $probeLog) {
            try {
                $tail = Get-Content $probeLog -Tail 1 -Encoding UTF8 -ErrorAction SilentlyContinue
                if ($tail -and $tail -ne $bootMarker -and $tail -match "probe_timer_on") { $probeFresh = $true }
            } catch { }
        }
        try {
            $ping = & $probeScript -RepoRoot $RepoRoot -Action ping -TimeoutSec 15
            if ($ping.pass) {
                Write-Host ("  niuma IPC ready (code={0}, probeFresh={1})" -f $ping.code, $probeFresh) -ForegroundColor DarkGray
                Start-Sleep -Seconds 4
                return
            }
        } catch {
            if ($probeFresh) {
                Write-Host "  probe timer on, retry ping..." -ForegroundColor DarkGray
            }
        }
    }
    throw "niuma IPC not ready within ${BootSec}s after reload"
}

function Wait-CpShellReady {
    param(
        [string]$Addr = "127.0.0.1:18791",
        [int]$PollSec = 35
    )
    $deadline = (Get-Date).AddSeconds($PollSec)
    $ready = $false
    $mounted = $false
    $htmlUrl = ""
    $phase = 0
    while ((Get-Date) -lt $deadline) {
        try {
            $st = Invoke-RestMethod -Uri "http://$Addr/shell/cp/status" -TimeoutSec 5
            if ($st -and $st.status) {
                $mounted = [bool]$st.status.mounted
                $ready = [bool]$st.status.ready
                $htmlUrl = [string]$st.status.htmlUrl
                if ($st.status.phase) { $phase = [int]$st.status.phase }
                if ($mounted -and $ready) { return @{ mounted = $mounted; ready = $ready; htmlUrl = $htmlUrl; phase = $phase } }
            }
        } catch { }
        Start-Sleep -Milliseconds 500
    }
    return @{ mounted = $mounted; ready = $ready; htmlUrl = $htmlUrl; phase = $phase }
}

function Send-CapsDoubleTap {
    $typeName = "NmerCp6LiveKeys"
    if (-not ([System.Management.Automation.PSTypeName]$typeName).Type) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;
public class NmerCp6LiveKeys {
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    const byte VK_CAPITAL = 0x14;
    const uint KEYEVENTF_KEYUP = 0x0002;
    public static void Tap(byte vk, int holdMs = 45) {
        keybd_event(vk, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(holdMs);
        keybd_event(vk, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }
    public static void CapsDoubleTap(int gapMs = 150) {
        Tap(VK_CAPITAL, 40);
        System.Threading.Thread.Sleep(gapMs);
        Tap(VK_CAPITAL, 40);
    }
}
"@
    }
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue | Out-Null
    try { [System.Windows.Forms.SendKeys]::SendWait("%{TAB}") } catch { }
    Start-Sleep -Milliseconds 400
    [NmerCp6LiveKeys]::CapsDoubleTap(160)
}

if ($Revert) {
    Write-Cp6GrayFlagsLocal $flagsPath $false
    Write-Host "Reverted commandPaletteHost=ahk"
    exit 0
}

Write-Host ""
Write-Host "=== CP6 Wails live smoke ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $wailsExe)) {
    Write-Host "FAIL: build nmer-wails first (apps\nmer-wails && wails build)" -ForegroundColor Red
    exit 1
}

$beforeRows = Get-CpHostShowRows $logPath
$beforeCount = $beforeRows.Count
$beforeSession = Get-LatestSession $beforeRows
Write-Host ("baseline: cp_host_show={0} lastSession={1}" -f $beforeCount, $(if ($beforeSession) { $beforeSession } else { "(none)" })) -ForegroundColor DarkGray

Write-Cp6GrayFlagsLocal $flagsPath $true
Write-Host "flags -> commandPaletteHost=wails, legacySurfaceLifecycle=false, sidecarHost=wails" -ForegroundColor Yellow

Invoke-NiumaReloadLocal -BootSec $BootSec

if (-not (Get-Process -Name "nmer-wails" -ErrorAction SilentlyContinue)) {
    Write-Host "starting nmer-wails sidecar..." -ForegroundColor DarkGray
    Start-Process -FilePath $wailsExe -WindowStyle Minimized
    Start-Sleep -Seconds 4
}

$probeScript = Join-Path $here "..\memory\Invoke-MultiCardMemoryProbe.ps1"
$probe = $null
if ($UseCapsLock) {
    Write-Host "sending CapsLock double-tap (focus desktop first)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    Send-CapsDoubleTap
    Start-Sleep -Milliseconds 800
    Send-CapsDoubleTap
} else {
    Write-Host "IPC probe -> show_cp (CommandPaletteRouter_Show)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    foreach ($attempt in 1..2) {
        try {
            if (Test-Path (Join-Path $RepoRoot "Cache\debug\multi_card_memory_probe_result.json")) {
                Remove-Item (Join-Path $RepoRoot "Cache\debug\multi_card_memory_probe_result.json") -Force -ErrorAction SilentlyContinue
            }
            $probe = & $probeScript -RepoRoot $RepoRoot -Action show_cp -TimeoutSec 45
            if ($probe.pass -or [string]$probe.code -eq "CP_SHOWN") { break }
            Write-Host ("WARN: show_cp attempt {0} code={1}" -f $attempt, $probe.code) -ForegroundColor Yellow
        } catch {
            Write-Host ("WARN: show_cp attempt {0} err={1}" -f $attempt, $_.Exception.Message) -ForegroundColor Yellow
            if ($attempt -ge 2) { throw }
        }
        Start-Sleep -Seconds 2
    }
    if ($probe -and -not $probe.pass) {
        Write-Host ("WARN: probe pass=false code={0}" -f $probe.code) -ForegroundColor Yellow
    }
}

$newEvent = $null
$deadline = (Get-Date).AddSeconds($PollSec)
while ((Get-Date) -lt $deadline) {
    $rows = Get-CpHostShowRows $logPath
    if ($rows.Count -gt $beforeCount) {
        $newEvent = $rows[-1]
        break
    }
    $session = Get-LatestSession $rows
    if ($session -and $session -ne $beforeSession) {
        $sessRows = @($rows | Where-Object { [string]$_.traceSession -eq $session })
        if ($sessRows.Count -gt 0) {
            $newEvent = $sessRows[-1]
            break
        }
    }
    Start-Sleep -Milliseconds 500
}

$hostTag = ""
$shellPhase = 0
if ($newEvent) {
    if ($newEvent.meta -and $newEvent.meta.host) { $hostTag = [string]$newEvent.meta.host }
    elseif ($newEvent.host) { $hostTag = [string]$newEvent.host }
    if ($newEvent.meta -and $null -ne $newEvent.meta.shellPhase) { $shellPhase = [int]$newEvent.meta.shellPhase }
}

$addr = if ($env:NMER_A2UI_BRIDGE_ADDR) { $env:NMER_A2UI_BRIDGE_ADDR } else { "127.0.0.1:18791" }
$cpShellMounted = $false
$cpShellReady = $false
$cpHtmlUrl = ""
$cpHtmlOk = $false
$shellWait = Wait-CpShellReady -Addr $addr -PollSec 40
$cpShellMounted = [bool]$shellWait.mounted
$cpShellReady = [bool]$shellWait.ready
$cpHtmlUrl = [string]$shellWait.htmlUrl
if ($shellPhase -lt 2 -and $shellWait.phase) { $shellPhase = [int]$shellWait.phase }
if ($cpHtmlUrl) {
    try {
        $htmlRes = Invoke-WebRequest -Uri $cpHtmlUrl -UseBasicParsing -TimeoutSec 8
        $cpHtmlOk = ($htmlRes.StatusCode -eq 200) -and ($htmlRes.Content -match "CommandPalette|palette")
    } catch { }
}

$pass = $null -ne $newEvent -and ($hostTag -eq "wails") -and ($shellPhase -ge 2) -and $cpShellMounted -and $cpHtmlOk
$afterRows = Get-CpHostShowRows $logPath
$probeCode = ""
$probePass = $null
if (-not $UseCapsLock -and $probe) {
    $probeCode = [string]$probe.code
    $probePass = [bool]$probe.pass
}
$result = @{
    capturedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    overallPass = [bool]$pass
    failReason = if ($pass) { "" } elseif (-not $newEvent) { "no_fresh_cp_host_show" } elseif ($hostTag -ne "wails") { "fresh_host_not_wails" } elseif ($shellPhase -lt 2) { "shell_phase_lt_2" } elseif (-not $cpShellMounted) { "cp_shell_not_mounted" } elseif (-not $cpHtmlOk) { "cp_html_iframe_url_fail" } else { "unknown" }
    beforeCount = $beforeCount
    afterCount = $afterRows.Count
    beforeSession = $beforeSession
    afterSession = Get-LatestSession $afterRows
    freshEvent = $newEvent
    freshHost = $hostTag
    shellPhase = $shellPhase
    cpShellMounted = $cpShellMounted
    cpShellReady = $cpShellReady
    cpHtmlUrl = $cpHtmlUrl
    cpHtmlOk = $cpHtmlOk
    probeCode = $probeCode
    probePass = $probePass
    wailsProcess = [bool](Get-Process -Name "nmer-wails" -ErrorAction SilentlyContinue)
}
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding UTF8

Write-Host ""
if ($pass) {
    Write-Host ("PASS: fresh cp_host_show (host={0}, shellPhase={1}, mounted={2}, session={3})" -f $(if ($hostTag) { $hostTag } else { "?" }), $shellPhase, $cpShellMounted, $result.afterSession) -ForegroundColor Green
} else {
    Write-Host "FAIL: no fresh cp_host_show within ${PollSec}s" -ForegroundColor Red
    Write-Host "  Try: reload niuma, rerun without -UseCapsLock (IPC show_cp), ensure nmer-wails running" -ForegroundColor Yellow
}
Write-Host "Report: $outPath"

if (-not $NoRevert) {
    Write-Cp6GrayFlagsLocal $flagsPath $false
    Write-Host "Reverted flags to ahk (use -NoRevert to keep wails gray)" -ForegroundColor DarkGray
}

exit $(if ($pass) { 0 } else { 1 })
