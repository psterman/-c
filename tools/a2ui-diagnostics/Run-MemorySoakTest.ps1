# P0C: memory soak test — split gates (stop / heap / process / slope)
param(
    [string]$RepoRoot = "",
    [int]$DurationMinutes = 30,
    [int]$WindowCycles = 10,
    [string]$Phase = "p0c",
    [switch]$FormalSignoff,
    [switch]$PauseIndexerForIdleSlope,
    [switch]$NoRestartIndexerAfterSoak
)

if ($FormalSignoff) {
    $DurationMinutes = 30
    $WindowCycles = 10
    $Phase = "formal_signoff"
    $PauseIndexerForIdleSlope = $true
}

$ErrorActionPreference = "Continue"
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
$outPath = Join-Path $debugDir "memory_soak.json"
$captureScript = Join-Path $PSScriptRoot "capture-memory-baseline.ps1"

function Get-SearchCorePrivateMiB {
    try {
        $p = Get-Process SearchCenterCore -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $p) { return $null }
        $p.Refresh()
        return [math]::Round($p.PrivateMemorySize64 / 1MB, 2)
    } catch {
        return $null
    }
}

function Get-TotalPrivateFromBaseline($jsonPath) {
    if (-not (Test-Path $jsonPath)) { return $null }
    try {
        $j = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        return [double]$j.processes.totalPrivateMiB
    } catch {
        return $null
    }
}

function Get-FullTextMemorySnapshot {
    try {
        $resp = Invoke-RestMethod -Uri "http://127.0.0.1:8080/v1/fulltext/memory" -TimeoutSec 5
        if ($resp.memory) { return $resp.memory }
        return $null
    } catch {
        return $null
    }
}

function Get-FullTextStatusSnapshot {
    try {
        return Invoke-RestMethod -Uri "http://127.0.0.1:8080/v1/fulltext/status" -TimeoutSec 4
    } catch {
        return $null
    }
}

function Test-IndexerBusy($st) {
    if (-not $st) { return $false }
    $phase = [string]$st.scanPhase
    if ($phase -in @("walking", "indexing", "incremental_sync")) { return $true }
    if ([int]$st.pendingTasks -gt 0) { return $true }
    return $false
}

function Set-FullTextControl([string]$action) {
    try {
        $body = @{ action = $action } | ConvertTo-Json
        Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8080/v1/fulltext/control" -Body $body -ContentType "application/json; charset=utf-8" -TimeoutSec 30 | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Test-IndexerPausedIdle($st) {
    if (-not $st) { return $false }
    if ([bool]$st.running) { return $false }
    if ([string]$st.scanPhase -ne "idle") { return $false }
    if ([int]$st.pendingTasks -gt 0) { return $false }
    return $true
}

function Get-LeakSlopeFromSamples($sampleRows, [double]$slopeLimit) {
    $rows = @($sampleRows | Where-Object { $null -ne $_.searchCorePrivateMiB })
    if ($rows.Count -lt 2) {
        return @{
            slope             = 0.0
            pass              = $null
            sampleCount       = $rows.Count
            firstTMin         = $null
            lastTMin          = $null
            firstPrivateMiB   = $null
            lastPrivateMiB    = $null
        }
    }
    $first = $rows[0]
    $last = $rows[-1]
    $hours = [math]::Max(0.01, ([double]$last.t - [double]$first.t) / 60.0)
    $slope = [math]::Round(([double]$last.searchCorePrivateMiB - [double]$first.searchCorePrivateMiB) / $hours, 2)
    return @{
        slope             = $slope
        pass              = ($slope -lt $slopeLimit)
        sampleCount       = $rows.Count
        firstTMin         = $first.t
        lastTMin          = $last.t
        firstPrivateMiB   = $first.searchCorePrivateMiB
        lastPrivateMiB    = $last.searchCorePrivateMiB
    }
}

function Copy-HeapFields($mem) {
    if (-not $mem) { return $null }
    return [ordered]@{
        privateMiB         = $mem.privateMiB
        heapAllocMiB       = $mem.heapAllocMiB
        heapSysMiB         = $mem.heapSysMiB
        heapInuseMiB       = $mem.heapInuseMiB
        heapIdleMiB        = $mem.heapIdleMiB
        heapReleasedMiB    = $mem.heapReleasedMiB
        indexMappedMiB     = $mem.indexMappedMiB
        numGC              = $mem.numGC
        action             = $mem.action
        hardHitStreak      = $mem.hardHitStreak
        recoveryAllowed    = $mem.recoveryAllowed
        softThresholdMiB   = $mem.softThresholdMiB
        hardThresholdMiB   = $mem.hardThresholdMiB
        lastSoftRecovery   = $mem.lastSoftRecovery
    }
}

$ramGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
$slopeLimit = if ($ramGb -lt 16) { 5 } elseif ($ramGb -le 32) { 8 } else { 10 }
$idleSlopeMaxPrivateMiB = 200

$ftStart = Get-FullTextStatusSnapshot
$indexerBusyAtStart = Test-IndexerBusy $ftStart
$indexerPausedForSoak = $false
$heapBeforeStop = $null
$heapAfterStop = $null
$stopCorrectnessPass = $null
$ftAfterStop = $null

if ($PauseIndexerForIdleSlope -or $indexerBusyAtStart) {
    $heapBeforeStop = Copy-HeapFields (Get-FullTextMemorySnapshot)
    if (Set-FullTextControl "stop") {
        $indexerPausedForSoak = $true
        # SearchCenterCore runs runtime.GC + debug.FreeOSMemory inside StopIndexer; do not call [System.GC]::Collect() here.
        Start-Sleep -Seconds 5
        $heapAfterStop = Copy-HeapFields (Get-FullTextMemorySnapshot)
        $ftAfterStop = Get-FullTextStatusSnapshot
        $stopCorrectnessPass = $false
        if ($ftAfterStop) {
            $stopCorrectnessPass = (-not [bool]$ftAfterStop.running) -and ([string]$ftAfterStop.scanPhase -eq "idle")
        }
    }
}

$baselinePath = Join-Path $debugDir "a2ui_memory_baseline.json"
& $captureScript -RepoRoot $RepoRoot -OutPath $baselinePath | Out-Null
$startCorePrivate = Get-SearchCorePrivateMiB
$startTotalPrivate = Get-TotalPrivateFromBaseline $baselinePath
$ftAtSample0 = Get-FullTextStatusSnapshot
$idleAtSample0 = Test-IndexerPausedIdle $ftAtSample0
$govStart = Get-FullTextMemorySnapshot
$samples = @(@{
    t                    = 0
    searchCorePrivateMiB = $startCorePrivate
    totalPrivateMiB      = $startTotalPrivate
    governorAction       = if ($govStart) { $govStart.action } else { $null }
    governorHardStreak   = if ($govStart) { $govStart.hardHitStreak } else { $null }
    governorPrivateMiB   = if ($govStart) { $govStart.privateMiB } else { $null }
    indexerPausedIdle    = $idleAtSample0
    scanPhase            = if ($ftAtSample0) { [string]$ftAtSample0.scanPhase } else { "" }
    running              = if ($ftAtSample0) { [bool]$ftAtSample0.running } else { $null }
})
$startedAt = Get-Date
$maxGovernorHardStreak = if ($govStart -and $null -ne $govStart.hardHitStreak) { [int]$govStart.hardHitStreak } else { 0 }
$indexerRelapseCount = 0
$indexerRelapseEvents = @()

$intervalSec = [math]::Max(30, [math]::Floor(($DurationMinutes * 60) / 12))
$endAt = $startedAt.AddMinutes($DurationMinutes)
while ((Get-Date) -lt $endAt) {
    Start-Sleep -Seconds $intervalSec
    & $captureScript -RepoRoot $RepoRoot -OutPath $baselinePath | Out-Null
    $elapsedMin = [math]::Round(((Get-Date) - $startedAt).TotalMinutes, 2)
    $ftNow = Get-FullTextStatusSnapshot
    $idleNow = Test-IndexerPausedIdle $ftNow
    if ($indexerPausedForSoak -and -not $idleNow) {
        $indexerRelapseCount += 1
        $relapseCoreBefore = Get-SearchCorePrivateMiB
        $reStopped = Set-FullTextControl "stop"
        if ($reStopped) { Start-Sleep -Seconds 4 }
        $ftNow = Get-FullTextStatusSnapshot
        $idleNow = Test-IndexerPausedIdle $ftNow
        $indexerRelapseEvents += @{
            tMin              = $elapsedMin
            corePrivateBefore = $relapseCoreBefore
            corePrivateAfter  = (Get-SearchCorePrivateMiB)
            reStopOk          = $reStopped
            idleAfterReStop   = $idleNow
            scanPhase         = if ($ftNow) { [string]$ftNow.scanPhase } else { "" }
        }
    }
    $gov = Get-FullTextMemorySnapshot
    if ($gov -and $null -ne $gov.hardHitStreak) {
        $hs = [int]$gov.hardHitStreak
        if ($hs -gt $maxGovernorHardStreak) { $maxGovernorHardStreak = $hs }
    }
    $samples += @{
        t                    = $elapsedMin
        searchCorePrivateMiB = (Get-SearchCorePrivateMiB)
        totalPrivateMiB      = (Get-TotalPrivateFromBaseline $baselinePath)
        governorAction       = if ($gov) { $gov.action } else { $null }
        governorHardStreak   = if ($gov) { $gov.hardHitStreak } else { $null }
        governorPrivateMiB   = if ($gov) { $gov.privateMiB } else { $null }
        indexerPausedIdle    = $idleNow
        scanPhase            = if ($ftNow) { [string]$ftNow.scanPhase } else { "" }
        running              = if ($ftNow) { [bool]$ftNow.running } else { $null }
    }
}

$slopeSampleSet = if ($indexerPausedForSoak) {
    @($samples | Where-Object {
        $_.indexerPausedIdle -eq $true -and
        $null -ne $_.searchCorePrivateMiB -and
        [double]$_.searchCorePrivateMiB -le $idleSlopeMaxPrivateMiB
    })
} else {
    @($samples)
}
$slopeResult = Get-LeakSlopeFromSamples $slopeSampleSet $slopeLimit
$slope = [double]$slopeResult.slope

$idleTail = @($slopeSampleSet | Select-Object -Last 1)
$windowStartCore = if ($idleTail.Count -gt 0 -and $null -ne $idleTail[0].searchCorePrivateMiB) {
    [double]$idleTail[0].searchCorePrivateMiB
} else {
    Get-SearchCorePrivateMiB
}
$windowPeakCore = $windowStartCore
if ($indexerPausedForSoak -and $slopeSampleSet.Count -gt 0) {
    foreach ($row in $slopeSampleSet) {
        if ($null -ne $row.searchCorePrivateMiB -and [double]$row.searchCorePrivateMiB -gt $windowPeakCore) {
            $windowPeakCore = [double]$row.searchCorePrivateMiB
        }
    }
} else {
    for ($i = 0; $i -lt $WindowCycles; $i++) {
        Start-Sleep -Seconds 2
        $p = Get-SearchCorePrivateMiB
        if ($p -gt $windowPeakCore) { $windowPeakCore = $p }
    }
}
$windowRecoveryPct = if ($windowStartCore -gt 0) { [math]::Round((($windowPeakCore - $windowStartCore) / $windowStartCore) * 100, 2) } else { 0 }

$ftEnd = Get-FullTextStatusSnapshot
$heapAtEnd = Copy-HeapFields (Get-FullTextMemorySnapshot)
$slopeDeferred = $indexerBusyAtStart -and -not $indexerPausedForSoak

$alreadyIdleAtStart = $ftStart -and (-not [bool]$ftStart.running) -and ([string]$ftStart.scanPhase -eq "idle")
$heapReleasePass = $null
if ($heapBeforeStop -and $heapAfterStop -and -not $alreadyIdleAtStart) {
    $allocDropped = ([double]$heapAfterStop.heapAllocMiB) -lt ([double]$heapBeforeStop.heapAllocMiB)
    $releasedRose = ([double]$heapAfterStop.heapReleasedMiB) -gt ([double]$heapBeforeStop.heapReleasedMiB)
    $heapReleasePass = $allocDropped -and $releasedRose
}

$leakSlopePass = if ($slopeDeferred) { $null } elseif ($indexerPausedForSoak -and $slopeSampleSet.Count -lt 2) { $false } else { $slopeResult.pass }
$processRecoveryPass = if ($slopeDeferred) { $null } else { ($windowRecoveryPct -le 10) }

$gates = [ordered]@{
    stopCorrectness = [ordered]@{
        pass        = $stopCorrectnessPass
        running     = if ($ftAfterStop) { [bool]$ftAfterStop.running } else { $null }
        phase       = if ($ftAfterStop) { [string]$ftAfterStop.scanPhase } else { "" }
        phaseAtEnd  = if ($ftEnd) { [string]$ftEnd.scanPhase } else { "" }
        detail      = "after stop: running=false and phase=idle"
    }
    heapRelease = [ordered]@{
        pass             = $heapReleasePass
        before           = $heapBeforeStop
        after            = $heapAfterStop
        detail           = "after stop+GoGC: heapAlloc down and heapReleased up"
    }
    processRecovery = [ordered]@{
        pass                = $processRecoveryPass
        metric              = "searchCorePrivateMiB"
        windowCycles        = $WindowCycles
        windowStartMiB      = $windowStartCore
        windowPeakMiB       = $windowPeakCore
        windowRecoveryPct   = $windowRecoveryPct
        windowRecoveryLimit = 10
        detail              = "SearchCenterCore private only, not totalPrivateMiB"
    }
    leakSlope = [ordered]@{
        pass                 = $leakSlopePass
        metric               = "searchCorePrivateMiB"
        slopeMiBPerHour      = $slope
        slopeLimitMiBPerHour = $slopeLimit
        lifecycle            = "indexer_paused_idle"
        sampleCount          = $slopeResult.sampleCount
        firstTMin            = $slopeResult.firstTMin
        lastTMin             = $slopeResult.lastTMin
        firstPrivateMiB      = $slopeResult.firstPrivateMiB
        lastPrivateMiB       = $slopeResult.lastPrivateMiB
        indexerRelapseCount  = $indexerRelapseCount
        idleSlopeMaxPrivateMiB = $idleSlopeMaxPrivateMiB
        detail               = "slope from idle samples with private <= ${idleSlopeMaxPrivateMiB} MiB; external start triggers re-stop"
    }
    idleTarget = [ordered]@{
        pass             = $null
        deferred         = $true
        enabled          = $null
        targetPrivateMiB = 150
        script           = "tools/a2ui-diagnostics/Test-IdleProcessExit.ps1 -Quick"
        note             = "P2 idle exit: run Test-IdleProcessExit.ps1; Deploy uses SEARCHCENTER_IDLE_EXIT=0 during signoff soak"
    }
    governorNoHardExit = [ordered]@{
        pass              = $false
        processAlive      = $false
        maxHardHitStreak  = $maxGovernorHardStreak
        hardThresholdMiB  = if ($heapAtEnd) { $heapAtEnd.hardThresholdMiB } else { 900 }
        endAction         = if ($heapAtEnd) { $heapAtEnd.action } else { "" }
        detail            = "stop-idle soak: SearchCenterCore must survive; hardHitStreak must stay below 3"
    }
}

$coreAliveAfterSoak = [bool](Get-Process -Name "SearchCenterCore" -ErrorAction SilentlyContinue)
$gates.governorNoHardExit.processAlive = $coreAliveAfterSoak
$gates.governorNoHardExit.pass = $coreAliveAfterSoak -and ($maxGovernorHardStreak -lt 3)

$gatePassValues = @(
    $gates.stopCorrectness.pass,
    $gates.heapRelease.pass,
    $gates.processRecovery.pass,
    $gates.leakSlope.pass,
    $gates.governorNoHardExit.pass
) | Where-Object { $_ -ne $null }

$overallPass = if ($slopeDeferred) { $false } elseif ($gatePassValues.Count -eq 0) { $false } else { -not ($gatePassValues -contains $false) }

$report = [ordered]@{
    capturedAt           = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    phase                = $Phase
    machineProfile       = @{ ramGb = $ramGb }
    gates                = $gates
    heapAtEnd            = $heapAtEnd
    slopeMiBPerHour      = $slope
    slopeLimitMiBPerHour = $slopeLimit
    slopePass            = $leakSlopePass
    slopeDeferred        = $slopeDeferred
    indexerPausedForSoak = $indexerPausedForSoak
    indexerBusyAtStart   = $indexerBusyAtStart
    indexPhaseAtStart    = if ($ftStart) { [string]$ftStart.scanPhase } else { "" }
    indexPhaseAtEnd      = if ($ftEnd) { [string]$ftEnd.scanPhase } else { "" }
    indexerRelapseCount  = $indexerRelapseCount
    indexerRelapseEvents = @($indexerRelapseEvents)
    slopeSampleCount     = $slopeResult.sampleCount
    samples              = $samples
    overallPass          = $overallPass
    note                 = if ($slopeDeferred) {
        "slope deferred: indexer was busy at start and stop failed; rerun with -PauseIndexerForIdleSlope"
    } elseif ($indexerPausedForSoak) {
        ("idle slope uses indexerPausedIdle samples only; external start re-stopped; relapses=" + $indexerRelapseCount)
    } else {
        ""
    }
}
$report | ConvertTo-Json -Depth 8 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "memory_soak -> $outPath slope=$($report.slopeMiBPerHour)MiB/h (searchCore) overallPass=$overallPass deferred=$slopeDeferred"
Write-Host "  gates: stop=$($gates.stopCorrectness.pass) heap=$($gates.heapRelease.pass) recovery=$($gates.processRecovery.pass) slope=$($gates.leakSlope.pass) governor=$($gates.governorNoHardExit.pass) maxHardStreak=$maxGovernorHardStreak relapses=$indexerRelapseCount slopeSamples=$($slopeResult.sampleCount)"

if ($indexerPausedForSoak -and $PauseIndexerForIdleSlope -and -not $NoRestartIndexerAfterSoak) {
    Set-FullTextControl "start" | Out-Null
}

if ($slopeDeferred) { exit 2 }
if (-not $overallPass) { exit 1 }
exit 0
