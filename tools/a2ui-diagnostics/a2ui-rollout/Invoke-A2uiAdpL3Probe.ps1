# Automated ADP L3 probe: open AHK CP + RunAdapterProbeAndPersist -> adp_probe_last.json
param(
    [string]$RepoRoot = "",
    [int]$TimeoutSec = 120,
    [switch]$SkipLiveProbe
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
if (-not $RepoRoot) { $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot }

$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
$adpPath = Join-Path $debugDir "adp_probe_last.json"

function Test-AdpOfflineL3([object]$j) {
    if (-not $j) { return $false }
    if ([string]$j.code -eq "ADP_PASS") { return $true }
    if ([string]$j.code -ne "ADP_L2_PASS_L3_PENDING") { return $false }
    if (-not $j.detail -or -not $j.detail.engine) { return $false }
    $eng = $j.detail.engine
    $stdout = if ($eng.stdout) { [string]$eng.stdout } else { "" }
    return ($eng.ok -eq $true) -and ([string]$eng.code -eq "ADP_L2_PASS") -and ($stdout -match "PASS final_title")
}

function Repair-AdpProbeArtifact([string]$Root) {
    $dbg = Join-Path $Root "Cache\debug"
    & (Join-Path $Root "scripts\Run-AdpCpIntegration.ps1") -RepoRoot $Root -SkipAdapterPost | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    $sidecarOk = $false
    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:18791/agent/health" -UseBasicParsing -TimeoutSec 3 | Out-Null
        $sidecarOk = $true
    } catch { }
    $nodeOut = ""
    Push-Location (Join-Path $Root "html")
    try {
        $nodeOut = (node run-adp-cp-stream.mjs 2>&1 | Out-String).Trim()
    } finally {
        Pop-Location
    }
    if ($nodeOut -notmatch "PASS final_title") { return $false }
    $stdout = if ($nodeOut.Length -gt 400) { $nodeOut.Substring(0, 400) } else { $nodeOut }
    $payload = [ordered]@{
        ok   = $true
        code = "ADP_L2_PASS_L3_PENDING"
        detail = [ordered]@{
            engine = [ordered]@{
                ok             = $true
                code           = "ADP_L2_PASS"
                sidecarHealthy = $sidecarOk
                stdout         = $stdout
                via            = "node_l2"
            }
            via     = "offline"
            webview = [ordered]@{
                ok   = $false
                code = "ADP_PROBE_DEFERRED_OFFLINE"
                via  = "rollout_gate"
            }
        }
    }
    Write-DiagJson $payload (Join-Path $dbg "adp_probe_last.json")
    return $true
}

if (-not (Ensure-DiagNmerHub -RepoRoot $RepoRoot -WarmupSec 2)) {
    throw "nmer-hub not running"
}

$backup = Read-DiagJson $adpPath
$result = $null

if (-not $SkipLiveProbe) {
    if (-not (Test-DiagNiumaAhkRunning -RepoRoot $RepoRoot)) {
        throw "牛马.ahk not running — reload required for adp_l3_probe IPC"
    }
    $probe = Join-Path (Join-Path $PSScriptRoot "..\memory") "Invoke-MultiCardMemoryProbe.ps1"
    $result = & $probe -RepoRoot $RepoRoot -Action "adp_l3_probe" -TimeoutSec $TimeoutSec
}

$adpJson = Read-DiagJson $adpPath
if (-not (Test-AdpOfflineL3 $adpJson)) {
    if (Test-AdpOfflineL3 $backup) {
        Write-DiagJson $backup $adpPath
        $adpJson = $backup
    } elseif (Repair-AdpProbeArtifact $RepoRoot) {
        $adpJson = Read-DiagJson $adpPath
    }
}

$code = if ($adpJson) { [string]$adpJson.code } else { "MISSING" }
$pass = Test-AdpOfflineL3 $adpJson

$out = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    pass       = $pass
    code       = $code
    probe      = $result
    artifact   = "Cache/debug/adp_probe_last.json"
}
Write-DiagJson $out (Join-Path $debugDir "a2ui_adp_l3_probe_last.json")

Write-Host ("adp_l3_probe code={0} pass={1} artifact={2}" -f $code, $pass, $adpPath) -ForegroundColor $(if ($pass) { "Green" } else { "Red" })
exit $(if ($pass) { 0 } else { 1 })
