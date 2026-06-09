# 灰度 flags 快照 — Wave 0.4 / 与 Nmer_WailsBridgeReadFlags 默认对齐
param(
    [string]$RepoRoot = "",
    [string]$OutPath = "",
    [ValidateSet("wave0", "daily", "auto")]
    [string]$Context = "auto"
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
if (-not $OutPath) {
    $debugDir = Join-Path $RepoRoot "Cache\debug"
    if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
    $OutPath = Join-Path $debugDir "gray_flags_baseline.json"
}

function Read-BoolFlag($val, [bool]$default) {
    if ($null -eq $val) { return $default }
    if ($val -is [bool]) { return $val }
    $s = [string]$val
    if ($s -eq "1" -or $s -ieq "true") { return $true }
    if ($s -eq "0" -or $s -ieq "false") { return $false }
    return $default
}

function Normalize-Whitelist($list) {
    $out = @()
    if ($null -eq $list) { return $out }
    foreach ($item in @($list)) {
        $s = [string]$item
        if ([string]::IsNullOrWhiteSpace($s)) { continue }
        $s = $s.Trim().ToLower()
        if (-not $s.StartsWith("/")) { $s = "/" + $s }
        if ($out -notcontains $s) { $out += $s }
    }
    return $out
}

function Get-RouteMode($flags) {
    $force = Read-BoolFlag $flags.rollback.forceNmerOnly $false
    if ($force) { return "force_nmer_only" }
    $official = Read-BoolFlag $flags.officialA2ui.enabled $false
    if (-not $official) { return "r1r2_only" }
    return "r3_gray"
}

$flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"
$flagsFileExists = Test-Path $flagsPath

$flags = @{
    wailsBridge       = @{ enabled = $true }
    officialA2ui      = @{ enabled = $false; commandWhitelist = @() }
    rollback          = @{ forceNmerOnly = $false }
}

if ($flagsFileExists) {
    try {
        $raw = Get-Content -Path $flagsPath -Raw -Encoding UTF8
        $data = $raw | ConvertFrom-Json
        if ($data.wailsBridge) {
            $flags.wailsBridge.enabled = Read-BoolFlag $data.wailsBridge.enabled $true
        }
        if ($data.officialA2ui) {
            $flags.officialA2ui.enabled = Read-BoolFlag $data.officialA2ui.enabled $false
            $flags.officialA2ui.commandWhitelist = Normalize-Whitelist $data.officialA2ui.commandWhitelist
        }
        if ($data.rollback) {
            $flags.rollback.forceNmerOnly = Read-BoolFlag $data.rollback.forceNmerOnly $false
        }
    } catch {
        Write-Warning "解析 nmer-flags.json 失败，使用默认: $_"
    }
}

$bridgeAddr = $env:NMER_A2UI_BRIDGE_ADDR
if ([string]::IsNullOrWhiteSpace($bridgeAddr)) { $bridgeAddr = "127.0.0.1:18791" }
$bridgeHealthy = $false
try {
    $resp = Invoke-WebRequest -Uri "http://$bridgeAddr/agent/health" -UseBasicParsing -TimeoutSec 2
    $bridgeHealthy = ($resp.StatusCode -eq 200)
} catch {
    $bridgeHealthy = $false
}

$routeMode = Get-RouteMode $flags
$sampleCmd = "/search"
$whitelisted = $flags.officialA2ui.commandWhitelist -contains $sampleCmd

$snapshot = @{
    capturedAt          = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    flagsPath           = $flagsPath
    flagsFileExists     = $flagsFileExists
    wailsBridge         = @{
        enabled = $flags.wailsBridge.enabled
        addr    = $bridgeAddr
        healthy = $bridgeHealthy
    }
    officialA2ui        = @{
        enabled          = $flags.officialA2ui.enabled
        commandWhitelist = @($flags.officialA2ui.commandWhitelist)
    }
    rollback            = @{
        forceNmerOnly = $flags.rollback.forceNmerOnly
    }
    routeMode           = $routeMode
    probeSample         = @{
        command           = $sampleCmd
        wouldRouteR3      = ($routeMode -eq "r3_gray") -and $whitelisted -and $bridgeHealthy
        whitelisted       = $whitelisted
        bridgeHealthy     = $bridgeHealthy
    }
    expectedWave0Mode   = "r1r2_only"
    context             = $Context
    wave0CheckPass      = ($routeMode -eq "r1r2_only")
    grayPhaseCheckPass  = ($routeMode -eq "r3_gray") -or ($routeMode -eq "r1r2_only")
}

$json = $snapshot | ConvertTo-Json -Depth 6
Set-Content -Path $OutPath -Value $json -Encoding UTF8
Write-Host "gray_flags_baseline -> $OutPath"
$checkPass = if ($Context -eq "daily") { $snapshot.grayPhaseCheckPass } else { $snapshot.wave0CheckPass }
Write-Host "routeMode=$routeMode context=$Context wave0CheckPass=$($snapshot.wave0CheckPass) grayPhaseCheckPass=$($snapshot.grayPhaseCheckPass)"
if (-not $checkPass) {
    if ($routeMode -eq "force_nmer_only") {
        Write-Warning "routeMode=force_nmer_only (rollback.forceNmerOnly=true). Normal during R2 rollback drill; else run scripts\Restore-GrayFlagsBaseline.ps1"
    } elseif ($routeMode -eq "r3_gray" -and $Context -eq "wave0") {
        Write-Warning "routeMode=r3_gray during Wave0 baseline. Use -Context daily for gray observation, or Restore-GrayFlagsBaseline.ps1 for Wave0 rerun."
    } else {
        Write-Warning "routeMode=$routeMode — check local/nmer-flags.json"
    }
    exit 2
}
if ($routeMode -eq "r3_gray" -and $Context -eq "daily") {
    Write-Host "gray phase OK (r3_gray intentional)"
}
exit 0
