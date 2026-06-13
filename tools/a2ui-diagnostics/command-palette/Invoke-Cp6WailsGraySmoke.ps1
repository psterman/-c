# CP6: Wails command-palette host smoke (cp_host_show only).
param(
    [string]$RepoRoot = "",
    [switch]$SkipPrompt,
    [switch]$AnalyzeOnly,
    [switch]$Revert
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $here
}

$flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"
$logPath = Join-Path $RepoRoot "Cache\debug\surface_runtime.ndjson"
$wailsExe = Join-Path $RepoRoot "apps\nmer-wails\build\bin\nmer-wails.exe"
$outPath = Join-Path $RepoRoot "Cache\debug\cp6_wails_gray_smoke.json"

function Read-Flags($path) {
    if (-not (Test-Path $path)) { return $null }
    return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-Cp6GrayFlags($path, [bool]$wailsMode) {
    $obj = Read-Flags $path
    if (-not $obj) { throw "Missing $path" }
    if (-not $obj.wailsBridge) { $obj | Add-Member -NotePropertyName wailsBridge -NotePropertyValue (@{}) -Force }
    if (-not $obj.rollback) { $obj | Add-Member -NotePropertyName rollback -NotePropertyValue (@{}) -Force }
    if ($wailsMode) {
        if ($null -eq $obj.wailsBridge.enabled) { $obj.wailsBridge | Add-Member -NotePropertyName enabled -NotePropertyValue $true -Force }
        else { $obj.wailsBridge.enabled = $true }
        $obj.wailsBridge | Add-Member -NotePropertyName commandPaletteHost -NotePropertyValue "wails" -Force
        $obj.rollback | Add-Member -NotePropertyName legacySurfaceLifecycle -NotePropertyValue $false -Force
    } else {
        $obj.wailsBridge | Add-Member -NotePropertyName commandPaletteHost -NotePropertyValue "ahk" -Force
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
    Write-Cp6GrayFlags $flagsPath $false
    Write-Host "Reverted commandPaletteHost=ahk, legacySurfaceLifecycle=true"
    Write-Host "Reload niuma to apply."
    exit 0
}

Write-Host ""
Write-Host "=== CP6 Wails CP smoke ===" -ForegroundColor Cyan
Write-Host ""

if (-not $AnalyzeOnly) {
    $flags = Read-Flags $flagsPath
    $needsGray = $true
    if ($flags) {
        $wb = $flags.wailsBridge
        $rb = $flags.rollback
        $cp = if ($wb.commandPaletteHost) { [string]$wb.commandPaletteHost } else { "ahk" }
        $legacy = if ($null -ne $rb.legacySurfaceLifecycle) { [bool]$rb.legacySurfaceLifecycle } else { $true }
        if ($cp -eq "wails" -and -not $legacy) { $needsGray = $false }
    }
    if ($needsGray) {
        Write-Cp6GrayFlags $flagsPath $true
        Write-Host "Updated local/nmer-flags.json -> commandPaletteHost=wails, legacySurfaceLifecycle=false" -ForegroundColor Yellow
        Write-Host "(searchCenter/config hosts unchanged — CP6 scope is command palette only)" -ForegroundColor DarkGray
    } else {
        Write-Host "Flags already CP6 gray (commandPaletteHost=wails)." -ForegroundColor DarkGray
    }
}

if (-not (Test-Path $wailsExe)) {
    Write-Host "FAIL: nmer-wails.exe not built." -ForegroundColor Red
    Write-Host "  cd apps\nmer-wails && wails build"
    @{
        capturedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        overallPass = $false
        failReason = "nmer_wails_exe_missing"
        wailsExe = $wailsExe
    } | ConvertTo-Json -Depth 4 | Set-Content -Path $outPath -Encoding UTF8
    exit 1
}
Write-Host "wails exe: OK" -ForegroundColor Green

if (-not $AnalyzeOnly -and -not $SkipPrompt) {
    Write-Host ""
    Write-Host "1) Fully reload niuma (exit tray + restart 牛马.ahk)" -ForegroundColor Yellow
    Write-Host "2) Double-tap CapsLock -> command palette via Wails (expect cp_host_show)"
    Write-Host "3) Optional: action mode submit one short task -> hub reply still works"
    Write-Host ""
    Read-Host "Press Enter after step 1-2 to analyze ndjson"
} elseif ($AnalyzeOnly) {
    Write-Host "AnalyzeOnly: reading existing surface_runtime.ndjson (no flag change prompt)." -ForegroundColor DarkGray
}

$rows, $session = Get-LatestSessionRows $logPath
$scopeRows = if ($AnalyzeOnly) {
    if (-not (Test-Path $logPath)) { @() } else {
        @(Get-Content $logPath -Encoding UTF8 | ForEach-Object {
            try { $_ | ConvertFrom-Json } catch { $null }
        } | Where-Object { $_ })
    }
} else {
    $rows
}
$cpEvents = @($scopeRows | Where-Object { $_.type -eq "cp_host_show" })
$cpWailsEvents = @($cpEvents | Where-Object {
    $_.host -eq "wails" -or ($_.meta -and $_.meta.host -eq "wails") -or ($_.payload -and $_.payload.host -eq "wails")
})

$pass = $cpWailsEvents.Count -gt 0
$failures = @()
if ($cpWailsEvents.Count -le 0) {
    if ($cpEvents.Count -le 0) { $failures += "missing_cp_host_show" }
    else { $failures += "missing_cp_host_show_wails" }
}

$result = @{
    capturedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    traceSession = $session
    overallPass = [bool]$pass
    failReason = if ($pass) { "" } else { ($failures -join "; ") }
    counts = @{
        cp_host_show = $cpEvents.Count
        cp_host_show_wails = $cpWailsEvents.Count
    }
    analyzeOnly = [bool]$AnalyzeOnly
    scope = if ($AnalyzeOnly) { "all_sessions" } else { "latest_session" }
}
$result | ConvertTo-Json -Depth 5 | Set-Content -Path $outPath -Encoding UTF8

Write-Host ""
Write-Host ("  cp_host_show: {0}" -f $(if ($cpEvents.Count) { "$($cpEvents.Count)" } else { "0" })) -ForegroundColor $(if ($cpEvents.Count) { "DarkGray" } else { "Yellow" })
Write-Host ("  cp_host_show_wails: {0}" -f $(if ($pass) { "PASS ($($cpWailsEvents.Count))" } else { "FAIL" })) -ForegroundColor $(if ($pass) { "Green" } else { "Red" })
Write-Host "Report: $outPath"

if ($pass) {
    Write-Host ""
    Write-Host "CP6 smoke PASSED." -ForegroundColor Green
    Write-Host "Revert: .\Invoke-Cp6WailsGraySmoke.ps1 -Revert"
} else {
    Write-Host ""
    Write-Host "CP6 smoke FAILED." -ForegroundColor Yellow
    Write-Host "  - Fully reload after flag change?"
    Write-Host "  - Is nmer-wails.exe running?"
    Write-Host "  - Router falls back to ahk if wails hwnd missing (no cp_host_show)"
}

exit $(if ($pass) { 0 } else { 1 })
