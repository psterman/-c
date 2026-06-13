# P2: 30min hub + UI aggregate idle slope (hybrid sidecar)
param(
    [string]$RepoRoot = "",
    [int]$DurationMinutes = 30,
    [int]$IntervalSec = 60,
    [int]$QuickMinutes = 0,
    [switch]$PauseIndexer,
    [switch]$NoRestartIndexerAfterSoak,
    [switch]$JsonOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Continue"
if (-not $RepoRoot) { $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot }

$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
$outPath = Join-Path $debugDir "p2_hub_ui_soak.json"
$captureScript = Join-Path $PSScriptRoot "capture-memory-baseline.ps1"
$baselinePath = Join-Path $debugDir "a2ui_memory_baseline.json"

$hubSlopeLimit = 1.0
$uiSlopeLimit = 5.0
$uiAbsDeltaLimit = 30.0
$dur = if ($QuickMinutes -gt 0) { $QuickMinutes } else { $DurationMinutes }

function Set-FullTextControl([string]$action) {
    try {
        $body = @{ action = $action } | ConvertTo-Json
        Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8080/v1/fulltext/control" -Body $body -ContentType "application/json; charset=utf-8" -TimeoutSec 30 | Out-Null
        return $true
    } catch { return $false }
}

function Get-FullTextStatusSnapshot {
    try { return Invoke-RestMethod -Uri "http://127.0.0.1:8080/v1/fulltext/status" -TimeoutSec 4 } catch { return $null }
}

function Test-IndexerPausedIdle($st) {
    if (-not $st) { return $false }
    if ([bool]$st.running) { return $false }
    if ([string]$st.scanPhase -ne "idle") { return $false }
    if ([int]$st.pendingTasks -gt 0) { return $false }
    return $true
}

function Get-UiPrivateFromBaseline([string]$path) {
    $j = Read-DiagJson $path
    if (-not $j) { return $null }
    if ($j.processes -and $null -ne $j.processes.uiPrivateMiB) { return [double]$j.processes.uiPrivateMiB }
    return $null
}

if (-not $JsonOnly) {
    Write-Host "== P2 hub/UI soak (${dur}m, interval=${IntervalSec}s) ==" -ForegroundColor Cyan
}

$indexerPaused = $false
if ($PauseIndexer) {
    if (Set-FullTextControl "stop") {
        $indexerPaused = $true
        Start-Sleep -Seconds 5
    }
}

if (-not (Ensure-DiagNmerHub -RepoRoot $RepoRoot -WarmupSec 2)) {
    throw "nmer-hub not running"
}

$samples = @()
$startedAt = Get-Date
$endAt = $startedAt.AddMinutes($dur)

while ((Get-Date) -lt $endAt) {
    & $captureScript -RepoRoot $RepoRoot -OutPath $baselinePath | Out-Null
    $elapsedMin = [math]::Round(((Get-Date) - $startedAt).TotalMinutes, 2)
    $ft = Get-FullTextStatusSnapshot
    $samples += [ordered]@{
        tMin           = $elapsedMin
        hubPrivateMiB  = (Get-DiagHubPrivateMiB)
        uiPrivateMiB   = (Get-UiPrivateFromBaseline $baselinePath)
        indexerIdle    = (Test-IndexerPausedIdle $ft)
        scanPhase      = if ($ft) { [string]$ft.scanPhase } else { "" }
    }
    if (-not $JsonOnly) {
        $last = $samples[-1]
        Write-Host ("  t={0}m hub={1} ui={2}" -f $last.tMin, $last.hubPrivateMiB, $last.uiPrivateMiB) -ForegroundColor DarkGray
    }
    Start-Sleep -Seconds $IntervalSec
}

$hubSlope = Get-DiagMemorySlopeMiBPerHour -SampleRows $samples -FieldName "hubPrivateMiB" -TimeField "tMin"
$uiSlope = Get-DiagMemorySlopeMiBPerHour -SampleRows $samples -FieldName "uiPrivateMiB" -TimeField "tMin"

$hubSlopePass = ($hubSlope.slopeMiBPerHour -le $hubSlopeLimit)
$uiSlopePass = ($uiSlope.slopeMiBPerHour -le $uiSlopeLimit) -or ($uiSlope.absDeltaMiB -le $uiAbsDeltaLimit)

$gates = [ordered]@{
    hubSlope = [ordered]@{
        pass              = $hubSlopePass
        slopeMiBPerHour   = $hubSlope.slopeMiBPerHour
        limitMiBPerHour   = $hubSlopeLimit
        firstMiB          = $hubSlope.firstMiB
        lastMiB           = $hubSlope.lastMiB
        absDeltaMiB       = $hubSlope.absDeltaMiB
        sampleCount       = $hubSlope.sampleCount
        detail            = "hub private slope <= $hubSlopeLimit MiB/hour"
    }
    uiSlope = [ordered]@{
        pass              = $uiSlopePass
        slopeMiBPerHour   = $uiSlope.slopeMiBPerHour
        limitMiBPerHour   = $uiSlopeLimit
        absDeltaMiB       = $uiSlope.absDeltaMiB
        absDeltaLimitMiB  = $uiAbsDeltaLimit
        firstMiB          = $uiSlope.firstMiB
        lastMiB           = $uiSlope.lastMiB
        sampleCount       = $uiSlope.sampleCount
        detail            = "UI aggregate slope <= $uiSlopeLimit MiB/hour OR abs delta <= $uiAbsDeltaLimit MiB"
    }
}

$overallPass = $hubSlopePass -and $uiSlopePass

$report = [ordered]@{
    capturedAt         = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    gate                 = "p2_hub_ui_soak"
    durationMinutes      = $dur
    intervalSec          = $IntervalSec
    indexerPausedForSoak = $indexerPaused
    hubSlopeLimitMiBPerHour = $hubSlopeLimit
    uiSlopeLimitMiBPerHour  = $uiSlopeLimit
    uiAbsDeltaLimitMiB      = $uiAbsDeltaLimit
    gates                = $gates
    samples              = $samples
    overallPass          = $overallPass
    note                 = "uiPrivateMiB from capture-memory-baseline (total - SearchCore)"
}
Write-DiagJson $report $outPath

if ($indexerPaused -and -not $NoRestartIndexerAfterSoak) {
    Set-FullTextControl "start" | Out-Null
}

if (-not $JsonOnly) {
    Write-Host ("p2_hub_ui_soak -> {0} hubSlope={1} uiSlope={2} overallPass={3}" -f $outPath, $hubSlope.slopeMiBPerHour, $uiSlope.slopeMiBPerHour, $overallPass) -ForegroundColor $(if ($overallPass) { "Green" } else { "Red" })
}
exit $(if ($overallPass) { 0 } else { 1 })
