# P0A root policy runtime gate
param(
    [string]$RepoRoot = "",
    [switch]$SkipSetupTest
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Continue"
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
$outPath = Join-Path $debugDir "p0a_root_policy_gate.json"
$configPath = Join-Path $RepoRoot "Data\search\fulltext_config.json"
$coreExe = Join-Path $RepoRoot "tools\search\SearchCenterCore.exe"

function Test-IsVolumeRoot([string]$path) {
    if (-not $path) { return $false }
    return ($path -match '^[A-Za-z]:\\?$')
}

function Wait-CoreHealth([int]$sec = 30) {
    $deadline = (Get-Date).AddSeconds($sec)
    while ((Get-Date) -lt $deadline) {
        try {
            $r = Invoke-WebRequest -Uri "http://127.0.0.1:8080/health" -UseBasicParsing -TimeoutSec 3
            if ($r.StatusCode -eq 200) { return $true }
        } catch {}
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Invoke-CoreStatus([int]$retries = 6, [int]$retryDelaySec = 3) {
    $lastErr = $null
    for ($i = 0; $i -lt $retries; $i++) {
        try {
            return Invoke-RestMethod "http://127.0.0.1:8080/v1/fulltext/status" -TimeoutSec 15
        } catch {
            $lastErr = $_
            if ($i -lt ($retries - 1)) {
                Start-Sleep -Seconds $retryDelaySec
            }
        }
    }
    throw $lastErr
}

function Restart-SearchCenterCore {
    Get-Process -Name "SearchCenterCore" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    if (-not (Test-Path $coreExe)) { return $false }
    # Walk-only during gate restarts: rapid Everything re-init after setup_required can AV-crash the DLL.
    $env:SEARCHCENTER_FT_USE_EVERYTHING = "0"
    $env:SEARCHCENTER_FT_USE_MFT = "0"
    $env:SEARCHCENTER_FT_USE_USN = "0"
    $env:SEARCHCENTER_FT_MAX_FILE_MB = "16"
    $env:SEARCHCENTER_IDLE_EXIT = "0"
    Start-Process -FilePath $coreExe -ArgumentList @("-base", $RepoRoot) -WorkingDirectory $RepoRoot -WindowStyle Hidden | Out-Null
    if (-not (Wait-CoreHealth 45)) { return $false }
    try {
        [void](Invoke-CoreStatus -Retries 8 -RetryDelaySec 2)
    } catch {
        return $false
    }
    return $true
}

$report = [ordered]@{
    capturedAt  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    repoRoot    = $RepoRoot
    gates       = @()
    overallPass = $false
}

if (-not (Wait-CoreHealth 45)) {
    $report.gates += [ordered]@{
        id     = "Z_core_health"
        pass   = $false
        detail = "SearchCenterCore /health not ready within 45s"
    }
    $report | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding UTF8
    Write-Host "p0a_root_policy_gate -> $outPath overallPass=False"
    Write-Host "  [FAIL] Z_core_health: core not ready"
    exit 1
}

# Gate A: knowledgeRoots 不扩成 C/D/E
$gateA = [ordered]@{ id = "A_no_volume_expand"; pass = $false; detail = "" }
try {
    $status = Invoke-RestMethod "http://127.0.0.1:8080/v1/fulltext/status" -TimeoutSec 10
    $cfg = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $apiRoots = @($status.roots | ForEach-Object { [string]$_ })
    $cfgRoots = @($cfg.knowledgeRoots | ForEach-Object { [string]$_ })
    $bad = @()
    foreach ($r in $apiRoots) {
        if (Test-IsVolumeRoot $r) { $bad += $r }
    }
    if ($bad.Count -gt 0) {
        $gateA.detail = "volume roots in status: $($bad -join ', ')"
    } elseif ([string]$status.rootLifecycleState -eq "configured") {
        $gateA.pass = $true
        $gateA.detail = "roots=$($apiRoots.Count) lifecycle=configured"
    } else {
        $gateA.detail = "rootLifecycleState=$($status.rootLifecycleState)"
    }
} catch {
    $gateA.detail = $_.Exception.Message
}
$report.gates += $gateA

# Gate B: setup_required 不扫描
$gateB = [ordered]@{ id = "B_setup_no_scan"; pass = $false; detail = "" }
if (-not $SkipSetupTest -and (Test-Path $configPath)) {
    $backup = Join-Path $debugDir "fulltext_config.p0a.bak.json"
    Copy-Item $configPath $backup -Force
    try {
        $before = Invoke-RestMethod "http://127.0.0.1:8080/v1/fulltext/status" -TimeoutSec 10
        $beforeIndexed = [int64]$before.indexedFiles
        $emptyCfg = @{
            maxScanSizeBytes  = 8388608
            knowledgeRoots    = @()
            autoDiscoverRoots = $false
            idleIndexAfterSec = 0
        }
        $emptyCfg | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8
        if (-not (Restart-SearchCenterCore)) {
            throw "SearchCenterCore restart failed (health timeout)"
        }
        Start-Sleep -Seconds 5
        $st2 = Invoke-RestMethod "http://127.0.0.1:8080/v1/fulltext/status" -TimeoutSec 15
        $afterIndexed = [int64]$st2.indexedFiles
        $phaseOk = ([string]$st2.rootLifecycleState -eq "setup_required" -or [string]$st2.scanPhase -eq "setup_required")
        $noGrow = ($afterIndexed -le $beforeIndexed)
        $startFailed = $false
        try {
            $body = @{ action = "start" } | ConvertTo-Json
            Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8080/v1/fulltext/control" -Body $body -ContentType "application/json" -TimeoutSec 10 | Out-Null
        } catch {
            $startFailed = $true
        }
        if ($phaseOk -and $noGrow) {
            $gateB.pass = $true
            $gateB.detail = "setup_required; indexed $beforeIndexed->$afterIndexed; startBlocked=$startFailed"
        } else {
            $gateB.detail = "phaseOk=$phaseOk noGrow=$noGrow lifecycle=$($st2.rootLifecycleState) phase=$($st2.scanPhase)"
        }
    } catch {
        $gateB.detail = $_.Exception.Message
    } finally {
        if (Test-Path $backup) {
            Copy-Item $backup $configPath -Force
            Start-Sleep -Seconds 2
            $cfgRestore = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $confirmBody = @{ roots = @($cfgRestore.knowledgeRoots); remember = $true } | ConvertTo-Json
            try {
                Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8080/v1/fulltext/roots/confirm" -Body $confirmBody -ContentType "application/json; charset=utf-8" -TimeoutSec 60 | Out-Null
            } catch {
                Write-Warning "Gate B restore confirm: $_"
            }
            Start-Sleep -Seconds 5
        }
    }
} else {
    $gateB.detail = "skipped"
    $gateB.pass = $true
}
$report.gates += $gateB
if (-not (Wait-CoreHealth 30)) {
    Write-Warning "core not healthy after gate B; waiting extra 10s"
    Start-Sleep -Seconds 10
}

# Gate C: rootsConfirmedAt + rootPolicyVersion 重启保持
$gateC = [ordered]@{ id = "C_persist_after_restart"; pass = $false; detail = "" }
try {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $cfg = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $testRoots = @($cfg.knowledgeRoots)
    if ($testRoots.Count -eq 0) { $testRoots = @($RepoRoot) }
    $body = @{ roots = $testRoots; remember = $true } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8080/v1/fulltext/roots/confirm" -Body $body -ContentType "application/json; charset=utf-8" -TimeoutSec 15 | Out-Null
    if (-not (Restart-SearchCenterCore)) {
        throw "SearchCenterCore restart failed (health timeout)"
    }
    Start-Sleep -Seconds 5
    $st3 = Invoke-CoreStatus
    $cfg2 = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $hasTs = [string]$cfg2.rootsConfirmedAt -ne ""
    $hasVer = ([int]$cfg2.rootPolicyVersion -ge 1)
    $lifecycle = [string]$st3.rootLifecycleState -eq "configured"
    if ($hasTs -and $hasVer -and $lifecycle) {
        $gateC.pass = $true
        $gateC.detail = "confirmedAt=$($cfg2.rootsConfirmedAt) version=$($cfg2.rootPolicyVersion)"
    } else {
        $gateC.detail = "hasTs=$hasTs hasVer=$hasVer lifecycle=$($st3.rootLifecycleState)"
    }
} catch {
    $gateC.detail = $_.Exception.Message
}
$report.gates += $gateC

# Gate D: discovery 三态 API 字段存在
$gateD = [ordered]@{ id = "D_discovery_fields"; pass = $false; detail = "" }
try {
    if (-not (Wait-CoreHealth 30)) {
        throw "SearchCenterCore /health not ready before gate D"
    }
    $rootsApi = Invoke-RestMethod "http://127.0.0.1:8080/v1/fulltext/roots" -TimeoutSec 15
    $hasSummary = $null -ne $rootsApi.discoverySummary
    $hasDiscovery = $null -ne $rootsApi.rootDiscovery
    if ($hasSummary -and $hasDiscovery) {
        $gateD.pass = $true
        $gateD.detail = "discoverySummary.mode=$($rootsApi.discoverySummary.mode)"
    } else {
        $gateD.detail = "hasSummary=$hasSummary hasDiscovery=$hasDiscovery"
    }
} catch {
    $gateD.detail = $_.Exception.Message
}
$report.gates += $gateD

$report.overallPass = -not @($report.gates | Where-Object { -not $_.pass }).Count
$report | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "p0a_root_policy_gate -> $outPath overallPass=$($report.overallPass)"
foreach ($g in $report.gates) {
    $mark = if ($g.pass) { "PASS" } else { "FAIL" }
    Write-Host "  [$mark] $($g.id): $($g.detail)"
}
if (-not $report.overallPass) { exit 1 }
exit 0
