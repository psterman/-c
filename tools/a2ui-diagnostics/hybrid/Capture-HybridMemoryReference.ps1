# Save memory baseline as hybrid signoff reference (ahk | hybrid mode tag)
param(
    [string]$RepoRoot = "",
    [ValidateSet("ahk", "hybrid")]
    [string]$Mode = "hybrid",
    [string]$OutPath = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
if (-not $OutPath) {
    $OutPath = Join-Path $debugDir "hybrid_signoff_reference_$Mode.json"
}

& (Join-DiagScript -RelativePath "memory/capture-memory-baseline.ps1") -RepoRoot $RepoRoot | Out-Host
$baselinePath = Join-Path $debugDir "a2ui_memory_baseline.json"
if (-not (Test-Path $baselinePath)) { throw "missing baseline: $baselinePath" }

$bl = Get-Content $baselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
$ref = [ordered]@{
    capturedAt         = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    mode               = $Mode
    repoRoot           = $RepoRoot
    totalPrivateMiB    = [double]$bl.processes.totalPrivateMiB
    emptyLoadPrivateMiB = [double]$bl.processes.emptyLoadPrivateMiB
    hubPrivateMiB      = $null
    wailsPrivateMiB    = $null
    ahkPrivateMiB      = $null
    webview2_count     = [int]$bl.processes.webview2_count
    webview2_host_roots = [int]$bl.processes.webview2_host_root_count
    baseline           = $bl
}
$hub = Get-Process -Name "nmer-hub" -ErrorAction SilentlyContinue | Select-Object -First 1
$wails = Get-Process -Name "nmer-wails" -ErrorAction SilentlyContinue | Select-Object -First 1
$ahk = Get-Process -Name "AutoHotkey64","AutoHotkey32" -ErrorAction SilentlyContinue | Where-Object {
    try {
        $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
        return ($cmd -like "*$RepoRoot*" -or $cmd -like "*牛马.ahk*")
    } catch { return $false }
} | Select-Object -First 1
if ($hub) { $hub.Refresh(); $ref.hubPrivateMiB = [math]::Round($hub.PrivateMemorySize64 / 1MB, 2) }
if ($wails) { $wails.Refresh(); $ref.wailsPrivateMiB = [math]::Round($wails.PrivateMemorySize64 / 1MB, 2) }
if ($ahk) { $ahk.Refresh(); $ref.ahkPrivateMiB = [math]::Round($ahk.PrivateMemorySize64 / 1MB, 2) }

$scSnap = Get-SearchCoreSignoffSnapshot
$ref.searchCore = $scSnap.searchCore
$ref.fulltextReady = $scSnap.fulltextReady
$ref.indexLifecycle = $scSnap.indexLifecycle

$ref | ConvertTo-Json -Depth 8 | Set-Content -Path $OutPath -Encoding UTF8
Write-Host "hybrid memory reference ($Mode) -> $OutPath totalPrivateMiB=$($ref.totalPrivateMiB) hub=$($ref.hubPrivateMiB) scanPhase=$($scSnap.searchCore.scanPhase)"
