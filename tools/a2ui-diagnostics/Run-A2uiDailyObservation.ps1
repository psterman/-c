# A2UI daily observation: memory + flags + sidecar + probe snapshots
param(
    [string]$RepoRoot = "",
    [int]$CardCount = 0
)

$ErrorActionPreference = "Continue"

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }

function Read-JsonFile($path) {
    if (-not (Test-Path $path)) { return $null }
    try {
        return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $null
    }
}

$addr = $env:NMER_A2UI_BRIDGE_ADDR
if (-not $addr) { $addr = "127.0.0.1:18791" }
$healthOk = $false
$healthBody = $null
try {
    $health = Invoke-WebRequest -Uri "http://$addr/agent/health" -UseBasicParsing -TimeoutSec 3
    $healthOk = ($health.StatusCode -eq 200)
    $healthBody = $health.Content
} catch {
    $healthOk = $false
}

& (Join-Path $PSScriptRoot "capture-gray-flags-snapshot.ps1") -RepoRoot $RepoRoot -Context daily | Out-Null
$memArgs = @{ RepoRoot = $RepoRoot; PreserveEmptyWhenCpLoaded = $true }
if ($CardCount -gt 0) { $memArgs["CardCount"] = $CardCount }
& (Join-Path $PSScriptRoot "capture-memory-baseline.ps1") @memArgs | Out-Null

$grayFlags = Read-JsonFile (Join-Path $debugDir "gray_flags_baseline.json")
$memory = Read-JsonFile (Join-Path $debugDir "a2ui_memory_baseline.json")
$probes = @{
    oc5  = Read-JsonFile (Join-Path $debugDir "oc5_probe_last.json")
    gray = Read-JsonFile (Join-Path $debugDir "gray_probe_last.json")
    adp  = Read-JsonFile (Join-Path $debugDir "adp_probe_last.json")
}

$wave0 = Read-JsonFile (Join-Path $debugDir "wave0_baseline_last.json")
$wave2 = Read-JsonFile (Join-Path $debugDir "wave2_gray_baseline_last.json")

$obs = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    sidecar    = [ordered]@{
        addr    = $addr
        healthy = $healthOk
        health  = $healthBody
    }
    routeMode  = if ($grayFlags) { $grayFlags.routeMode } else { $null }
    grayFlags  = $grayFlags
    memory     = $memory
    probes     = $probes
    automation = [ordered]@{
        wave0Pass = if ($wave0) { $wave0.wave0Pass } else { $null }
        wave2Pass = if ($wave2) { $wave2.wave2Pass } else { $null }
    }
    manualHints = @(
        "Ctrl+Shift+O -> oc5_probe_last.json",
        "Ctrl+Shift+G -> gray_probe_last.json (needs local/nmer-flags.json)",
        "Ctrl+Shift+U -> adp_probe_last.json (after ingest demo JSONL)"
    )
}

$dailyPath = Join-Path $debugDir "a2ui_observation_daily.json"
$obs | ConvertTo-Json -Depth 10 | Set-Content -Path $dailyPath -Encoding UTF8

$historyPath = Join-Path $debugDir "a2ui_observation_history.jsonl"
$line = ($obs | ConvertTo-Json -Depth 10 -Compress)
$dailyRows = @{}
if (Test-Path $historyPath) {
    foreach ($existingLine in @(Get-Content $historyPath -Encoding UTF8 | Where-Object { $_.Trim() })) {
        try {
            $existing = $existingLine | ConvertFrom-Json
            $dateKey = ([datetime]$existing.capturedAt).ToUniversalTime().ToString("yyyy-MM-dd")
            $dailyRows[$dateKey] = $existingLine
        } catch { }
    }
}
$todayKey = ([datetime]$obs.capturedAt).ToUniversalTime().ToString("yyyy-MM-dd")
$dailyRows[$todayKey] = $line
@($dailyRows.Keys | Sort-Object | ForEach-Object { $dailyRows[$_] }) |
    Set-Content -Path $historyPath -Encoding UTF8

Write-Host "a2ui_observation_daily -> $dailyPath"
Write-Host "routeMode=$($obs.routeMode) sidecarHealthy=$healthOk emptyLoadMiB=$($memory.emptyLoadPrivateMiB) observationDays=$($dailyRows.Count)"

$evalScript = Join-Path $PSScriptRoot "Evaluate-A2uiObservation.ps1"
if (Test-Path $evalScript) {
    & $evalScript -RepoRoot $RepoRoot -DailyPath $dailyPath | Out-Null
}

exit 0
