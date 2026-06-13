# Summarize L3 probe artifacts (oc5 / gray / adp)
param(
    [string]$RepoRoot = ""
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Continue"
if (-not $RepoRoot) { $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot }

$debugDir = Join-Path $RepoRoot "Cache\debug"
$files = @{
    oc5  = Join-Path $debugDir "oc5_probe_last.json"
    gray = Join-Path $debugDir "gray_probe_last.json"
    adp  = Join-Path $debugDir "adp_probe_last.json"
}

function Read-Json($path) {
    if (-not (Test-Path $path)) { return $null }
    try { return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

$summary = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    probes     = @{}
    l3Pass     = $true
    l2Pass     = $true
}

foreach ($name in $files.Keys) {
    $j = Read-Json $files[$name]
    if (-not $j) {
        $summary.probes[$name] = @{ present = $false; ok = $false; code = "MISSING" }
        $summary.l3Pass = $false
        $summary.l2Pass = $false
        Write-Host "MISS $name — run probe hotkey or offline gate"
        continue
    }
    $ok = [bool]$j.ok
    $code = [string]$j.code
    $via = ""
    if ($j.detail -and $j.detail.via) { $via = [string]$j.detail.via }
    $summary.probes[$name] = @{ present = $true; ok = $ok; code = $code; via = $via }
    $l2PassCodes = @("OC5_PASS", "OC5_ENGINE_PASS_NEEDS_LIVE", "GRAY_PASS", "ADP_PASS", "ADP_L2_PASS_L3_PENDING")
    $l3PassCodes = @{
        oc5  = @("OC5_PASS")
        gray = @("GRAY_PASS")
        adp  = @("ADP_PASS")
    }
    $adpOfflineL3 = $false
    if ($name -eq "adp" -and $code -eq "ADP_L2_PASS_L3_PENDING" -and $j.detail -and $j.detail.engine) {
        $eng = $j.detail.engine
        $engOk = ($eng.ok -eq $true) -and ([string]$eng.code -eq "ADP_L2_PASS")
        $stdout = if ($eng.stdout) { [string]$eng.stdout } else { "" }
        if ($engOk -and $stdout -match "PASS final_title") {
            $adpOfflineL3 = $true
            $summary.probes[$name].offlineL3 = $true
        }
    }
    if (-not $ok -or ($l2PassCodes -notcontains $code)) { $summary.l2Pass = $false }
    $probeL3Ok = ($ok -and ($l3PassCodes[$name] -contains $code)) -or $adpOfflineL3
    if (-not $probeL3Ok) { $summary.l3Pass = $false }
    $level = if ($probeL3Ok) {
        if ($adpOfflineL3) { "L3 PASS (offline engine)" } else { "L3 PASS" }
    } elseif ($ok -and ($l2PassCodes -contains $code)) { "L2 ONLY" } else { "FAIL" }
    Write-Host "$level $name code=$code via=$via"
}

$out = Join-Path $debugDir "a2ui_l3_probe_summary_last.json"
Write-DiagJson $summary $out
Write-Host "l3 summary -> $out l2Pass=$($summary.l2Pass) l3Pass=$($summary.l3Pass)"
exit $(if ($summary.l3Pass) { 0 } else { 1 })
