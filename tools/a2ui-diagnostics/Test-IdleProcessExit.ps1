# P2: SearchCenterCore idle process exit + cold relaunch gate
param(
    [string]$RepoRoot = "",
    [switch]$Quick,
    [switch]$SkipRelaunch,
    [int]$StopIndexerSec = 0,
    [int]$ExitAfterStopSec = 0,
    [int]$PollIntervalSec = 10,
    [int]$WaitBufferSec = 20
)

$ErrorActionPreference = "Continue"
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
$outPath = Join-Path $debugDir "p2_idle_process_exit.json"
$coreExe = Join-Path $RepoRoot "tools\search\SearchCenterCore.exe"

if ($Quick) {
    if ($StopIndexerSec -le 0) { $StopIndexerSec = 60 }
    if ($ExitAfterStopSec -le 0) { $ExitAfterStopSec = 60 }
} else {
    if ($StopIndexerSec -le 0) { $StopIndexerSec = 300 }
    if ($ExitAfterStopSec -le 0) { $ExitAfterStopSec = 600 }
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

function Get-SearchCorePid {
    $p = Get-Process -Name "SearchCenterCore" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p) { return [int]$p.Id }
    return $null
}

function Start-SearchCoreWithIdleEnv {
    Get-Process -Name "SearchCenterCore" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Test-Path $coreExe)) { return $false }
    $env:SEARCHCENTER_IDLE_EXIT = "1"
    $env:SEARCHCENTER_FT_USE_EVERYTHING = "1"
    $env:SEARCHCENTER_FT_USE_MFT = "0"
    $env:SEARCHCENTER_FT_USE_USN = "1"
    $env:SEARCHCENTER_FT_MAX_FILE_MB = "16"
    $env:SEARCHCENTER_IDLE_STOP_INDEXER_SEC = [string]$StopIndexerSec
    $env:SEARCHCENTER_IDLE_EXIT_SEC = [string]$ExitAfterStopSec
    Start-Process -FilePath $coreExe -ArgumentList @("-base", $RepoRoot) -WorkingDirectory $RepoRoot -WindowStyle Hidden | Out-Null
    return (Wait-CoreHealth 35)
}

$report = [ordered]@{
    capturedAt       = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    phase            = if ($Quick) { "p2_quick" } else { "p2_formal" }
    repoRoot         = $RepoRoot
    stopIndexerSec   = $StopIndexerSec
    exitAfterStopSec = $ExitAfterStopSec
    gates            = @()
    overallPass      = $false
    note             = "Do not poll :8080 during exit wait except one stop POST; AHK/SSE clients cancel countdown"
}

$gateA = [ordered]@{ id = "A_stop_correctness"; pass = $false; detail = "" }
if (-not (Test-Path $coreExe)) {
    $gateA.detail = "missing $coreExe"
} elseif (-not (Start-SearchCoreWithIdleEnv)) {
    $gateA.detail = "SearchCenterCore health timeout"
} else {
    try {
        $stopResp = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8080/v1/fulltext/control" -Body '{"action":"stop"}' -ContentType "application/json; charset=utf-8" -TimeoutSec 30
        $running = [bool]$stopResp.status.running
        $phase = [string]$stopResp.status.scanPhase
        $gateA.pass = (-not $running) -and ($phase -eq "idle")
        $gateA.detail = "running=$running phase=$phase pid=$(Get-SearchCorePid)"
        $script:stopMarkUtc = (Get-Date).ToUniversalTime()
        $gateA.stoppedAt = $script:stopMarkUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    } catch {
        $gateA.detail = $_.Exception.Message
    }
}
$report.gates += $gateA

$gateB = [ordered]@{
    id              = "B_process_exit"
    pass            = $false
    detail          = ""
    waitDeadlineSec = $ExitAfterStopSec + $WaitBufferSec
    samples         = @()
}
if ($gateA.pass) {
    $deadline = (Get-Date).AddSeconds($gateB.waitDeadlineSec)
    $exitedAt = $null
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $PollIntervalSec
        $corePid = Get-SearchCorePid
        $elapsed = [math]::Round(((Get-Date).ToUniversalTime() - $script:stopMarkUtc).TotalSeconds, 1)
        $gateB.samples += @{ tSec = $elapsed; pid = $corePid }
        if (-not $corePid) {
            $exitedAt = $elapsed
            $gateB.pass = $true
            $gateB.detail = "exited after ${exitedAt}s (limit=${ExitAfterStopSec}s+buffer=${WaitBufferSec}s)"
            break
        }
    }
    if (-not $gateB.pass) {
        $gateB.detail = "still running pid=$(Get-SearchCorePid) after $($gateB.waitDeadlineSec)s; close AHK/SSE clients and retry"
    }
} else {
    $gateB.detail = "skipped: stop gate failed"
}
$report.gates += $gateB

$gateC = [ordered]@{ id = "C_cold_relaunch"; pass = $false; detail = "" }
if ($SkipRelaunch) {
    $gateC.detail = "skipped"
    $gateC.pass = $null
} elseif (-not $gateB.pass) {
    $gateC.detail = "skipped: process did not exit"
} else {
    if (Start-SearchCoreWithIdleEnv) {
        $corePid = Get-SearchCorePid
        $gateC.pass = ($null -ne $corePid)
        if ($gateC.pass) {
            $gateC.detail = "health ok pid=$corePid"
        } else {
            $gateC.detail = "relaunch failed"
        }
    } else {
        $gateC.detail = "health timeout after relaunch"
    }
    Get-Process -Name "SearchCenterCore" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
$report.gates += $gateC

$passValues = @($gateA.pass, $gateB.pass)
if ($null -ne $gateC.pass) { $passValues += $gateC.pass }
$passValues = @($passValues | Where-Object { $_ -ne $null })
$report.overallPass = ($passValues.Count -gt 0) -and -not ($passValues -contains $false)

$report | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "p2_idle_process_exit -> $outPath overallPass=$($report.overallPass)"
foreach ($g in $report.gates) {
    Write-Host ("  [" + $g.id + "] pass=" + $g.pass + " " + $g.detail)
}

if (-not $report.overallPass) { exit 1 }
exit 0
