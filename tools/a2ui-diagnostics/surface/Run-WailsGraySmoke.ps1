# Wails gray smoke: verify cp_host_show / sc_host_show / config_host_show in current session
param(
    [string]$RepoRoot = "",
    [switch]$SkipPrompt,
    [switch]$Revert
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}

$flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"
$logPath = Join-Path $RepoRoot "Cache\debug\surface_runtime.ndjson"
$wailsExe = Join-Path $RepoRoot "apps\nmer-wails\build\bin\nmer-wails.exe"
$outPath = Join-Path $RepoRoot "Cache\debug\wails_gray_smoke.json"

function Read-Flags($path) {
    if (-not (Test-Path $path)) { return $null }
    return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-GrayFlags($path, [bool]$wailsMode) {
    $obj = Read-Flags $path
    if (-not $obj) { throw "Missing $path" }
    if (-not $obj.wailsBridge) { $obj | Add-Member -NotePropertyName wailsBridge -NotePropertyValue (@{}) -Force }
    if (-not $obj.rollback) { $obj | Add-Member -NotePropertyName rollback -NotePropertyValue (@{}) -Force }
    if ($wailsMode) {
        $obj.wailsBridge.enabled = $true
        $obj.wailsBridge | Add-Member -NotePropertyName commandPaletteHost -NotePropertyValue "wails" -Force
        $obj.wailsBridge | Add-Member -NotePropertyName searchCenterHost -NotePropertyValue "wails" -Force
        $obj.wailsBridge | Add-Member -NotePropertyName configWebviewHost -NotePropertyValue "wails" -Force
        $obj.rollback | Add-Member -NotePropertyName legacySurfaceLifecycle -NotePropertyValue $false -Force
    } else {
        $obj.wailsBridge | Add-Member -NotePropertyName commandPaletteHost -NotePropertyValue "ahk" -Force
        $obj.wailsBridge | Add-Member -NotePropertyName searchCenterHost -NotePropertyValue "ahk" -Force
        $obj.wailsBridge | Add-Member -NotePropertyName configWebviewHost -NotePropertyValue "ahk" -Force
        $obj.rollback | Add-Member -NotePropertyName legacySurfaceLifecycle -NotePropertyValue $true -Force
    }
    ($obj | ConvertTo-Json -Depth 8) | Set-Content -Path $path -Encoding UTF8
}

function Get-LatestSessionRows($path) {
    if (-not (Test-Path $path)) { return @(), "" }
    $rows = @(Get-Content $path -Encoding UTF8 | ForEach-Object {
        try { $_ | ConvertFrom-Json } catch { $null }
    } | Where-Object { $_ })
    if (-not $rows.Count) { return @(), "" }
    $session = [string]$rows[-1].traceSession
    if (-not $session) { return $rows, "" }
    return @($rows | Where-Object { [string]$_.traceSession -eq $session }), $session
}

if ($Revert) {
    Write-GrayFlags $flagsPath $false
    Write-Host "Reverted local/nmer-flags.json to ahk + legacySurfaceLifecycle:true"
    Write-Host "Reload niuma to apply."
    exit 0
}

Write-Host ""
Write-Host "=== Wails gray smoke ===" -ForegroundColor Cyan
Write-Host ""

$flags = Read-Flags $flagsPath
$needsGray = $true
if ($flags) {
    $wb = $flags.wailsBridge
    $rb = $flags.rollback
    $cp = if ($wb.commandPaletteHost) { [string]$wb.commandPaletteHost } else { "ahk" }
    $sc = if ($wb.searchCenterHost) { [string]$wb.searchCenterHost } else { "ahk" }
    $cfg = if ($wb.configWebviewHost) { [string]$wb.configWebviewHost } else { "ahk" }
    $legacy = if ($null -ne $rb.legacySurfaceLifecycle) { [bool]$rb.legacySurfaceLifecycle } else { $true }
    if ($cp -eq "wails" -and $sc -eq "wails" -and $cfg -eq "wails" -and -not $legacy) {
        $needsGray = $false
        Write-Host "Flags already in wails gray mode." -ForegroundColor DarkGray
    }
}
if ($needsGray) {
    Write-GrayFlags $flagsPath $true
    Write-Host "Updated local/nmer-flags.json -> all hosts=wails, legacySurfaceLifecycle=false" -ForegroundColor Yellow
}

if (-not (Test-Path $wailsExe)) {
    Write-Host "FAIL: nmer-wails.exe not built. Run wails build in apps/nmer-wails first." -ForegroundColor Red
    exit 1
}
Write-Host "wails exe: OK ($wailsExe)" -ForegroundColor Green

Write-Host ""
Write-Host "1) Fully reload niuma (exit tray + restart 牛马.ahk)" -ForegroundColor Yellow
Write-Host "2) Double-tap CapsLock          -> expect cp_host_show"
Write-Host "3) Hold CapsLock + F            -> expect sc_host_show"
Write-Host "4) Tray open Settings/Config    -> expect config_host_show"
Write-Host ""
Write-Host "All three in ONE session after reload. Wails window should flash to front each time."
Write-Host ""

if (-not $SkipPrompt) {
    Read-Host "Press Enter after steps 1-4 to analyze ndjson"
}

$rows, $session = Get-LatestSessionRows $logPath
$cpEvents = @($rows | Where-Object { $_.type -eq "cp_host_show" })
$scEvents = @($rows | Where-Object { $_.type -eq "sc_host_show" })
$cfgEvents = @($rows | Where-Object { $_.type -eq "config_host_show" })

$pass = ($cpEvents.Count -gt 0) -and ($scEvents.Count -gt 0) -and ($cfgEvents.Count -gt 0)
$failures = @()
if ($cpEvents.Count -le 0) { $failures += "missing_cp_host_show" }
if ($scEvents.Count -le 0) { $failures += "missing_sc_host_show" }
if ($cfgEvents.Count -le 0) { $failures += "missing_config_host_show" }

$result = @{
    capturedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    traceSession = $session
    wails_gray_pass = [bool]$pass
    failures = @($failures)
    counts = @{
        cp_host_show = $cpEvents.Count
        sc_host_show = $scEvents.Count
        config_host_show = $cfgEvents.Count
    }
}
$result | ConvertTo-Json -Depth 5 | Set-Content -Path $outPath -Encoding UTF8

Write-Host ""
Write-Host "=== Result (session: $session) ===" -ForegroundColor Cyan
Write-Host ("  cp_host_show      {0}" -f $(if ($cpEvents.Count) { "PASS ($($cpEvents.Count))" } else { "FAIL" })) -ForegroundColor $(if ($cpEvents.Count) { "Green" } else { "Red" })
Write-Host ("  sc_host_show      {0}" -f $(if ($scEvents.Count) { "PASS ($($scEvents.Count))" } else { "FAIL" })) -ForegroundColor $(if ($scEvents.Count) { "Green" } else { "Red" })
Write-Host ("  config_host_show  {0}" -f $(if ($cfgEvents.Count) { "PASS ($($cfgEvents.Count))" } else { "FAIL" })) -ForegroundColor $(if ($cfgEvents.Count) { "Green" } else { "Red" })
Write-Host ""
Write-Host "Report: $outPath"

if ($pass) {
    Write-Host ""
    Write-Host "Wails gray smoke PASSED." -ForegroundColor Green
    Write-Host "Revert flags: .\tools\a2ui-diagnostics\Run-WailsGraySmoke.ps1 -Revert"
} else {
    Write-Host ""
    Write-Host "Wails gray smoke FAILED. Check:" -ForegroundColor Yellow
    Write-Host "  - Did you fully reload after flag change?"
    Write-Host "  - Is nmer-wails.exe running? (bridge should autostart)"
    Write-Host "  - If wails hwnd missing, routers fall back to ahk (no host_show events)"
}

exit $(if ($pass) { 0 } else { 1 })
