# Evaluate daily observation against gray-cutover thresholds (heuristic)
param(
    [string]$RepoRoot = "",
    [string]$DailyPath = "",
    [double]$MaxTotalPrivateMiB = 4096,
    [double]$MaxLargestRendererPrivateMiB = 2048
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Continue"

if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not $DailyPath) {
    $DailyPath = Join-Path $debugDir "a2ui_observation_daily.json"
}

function Read-JsonFile($path) {
    if (-not (Test-Path $path)) { return $null }
    try {
        return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $null
    }
}

$daily = Read-JsonFile $DailyPath
$baseline = Read-JsonFile (Join-Path $debugDir "wave0_baseline_last.json")
$memory = Read-JsonFile (Join-Path $debugDir "a2ui_memory_baseline.json")

$checks = @()
$pass = $true

function Add-Check($id, $ok, $detail, [switch]$Hard) {
    $script:checks += @{ id = $id; ok = $ok; hard = [bool]$Hard; detail = $detail }
    if ($Hard -and -not $ok) { $script:pass = $false }
    $flag = if ($ok) { "PASS" } else { if ($Hard) { "FAIL" } else { "WARN" } }
    Write-Host "$flag $id — $detail"
}

if (-not $daily) {
    Add-Check "daily_exists" $false "missing $DailyPath — run Run-A2uiDailyObservation.ps1" -Hard
} else {
    Add-Check "daily_exists" $true "loaded"
    Add-Check "sidecar_healthy" ([bool]$daily.sidecar.healthy) "healthy=$($daily.sidecar.healthy)" -Hard
    $mode = [string]$daily.routeMode
    $forceConflict = ($mode -eq "r3_gray") -and ($daily.grayFlags.rollback.forceNmerOnly -eq $true)
    Add-Check "route_mutex" (-not $forceConflict) "routeMode=$mode forceNmerOnly=$($daily.grayFlags.rollback.forceNmerOnly)" -Hard

    $oc5 = $daily.probes.oc5
    if ($oc5) {
        Add-Check "oc5_probe_present" $true "code=$($oc5.code) ok=$($oc5.ok)"
    } else {
        Add-Check "oc5_probe_present" $false "no oc5_probe_last.json yet (Ctrl+Shift+O)"
    }

    $gray = $daily.probes.gray
    if ($gray -and $mode -eq "r3_gray") {
        $grayOk = [bool]$gray.ok
        Add-Check "gray_probe_r3" $grayOk "code=$($gray.code)"
    }

    if ($memory -and $memory.processes) {
        $totalPrivate = [double]$memory.processes.totalPrivateMiB
        $largestPrivate = [double]$memory.processes.webview2_largest.privateMiB
        Add-Check "memory_total_private" ($totalPrivate -gt 0 -and $totalPrivate -le $MaxTotalPrivateMiB) "totalPrivateMiB=$totalPrivate limit=$MaxTotalPrivateMiB" -Hard
        Add-Check "memory_largest_renderer" ($largestPrivate -ge 0 -and $largestPrivate -le $MaxLargestRendererPrivateMiB) "largestRendererPrivateMiB=$largestPrivate limit=$MaxLargestRendererPrivateMiB" -Hard
    } else {
        Add-Check "memory_snapshot" $false "missing process memory snapshot" -Hard
    }
}

if ($baseline -and $baseline.wave0Pass -ne $true) {
    Add-Check "wave0_baseline" $false "wave0Pass=$($baseline.wave0Pass)"
} elseif ($baseline) {
    Add-Check "wave0_baseline" $true "wave0Pass=true"
}

$out = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    source     = $DailyPath
    checks     = $checks
    evaluatePass = $pass
}

$outPath = Join-Path $debugDir "a2ui_observation_eval_last.json"
$out | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "evaluation -> $outPath pass=$pass"
if (-not $pass) { exit 1 }
exit 0
