# Summarize shadow SurfaceRuntimeManager telemetry.
param(
    [string]$RepoRoot = "",
    [int]$Tail = 80
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
} else {
    $RepoRoot = (Resolve-Path $RepoRoot).Path
}

$debugDir = Join-Path $RepoRoot "Cache\debug"
$logPath = Join-Path $debugDir "surface_runtime.ndjson"
$snapshotPath = Join-Path $debugDir "surface_registry_snapshot.json"

function Read-NdjsonRows($path) {
    if (-not (Test-Path $path)) { return @() }
    $rows = @()
    foreach ($line in @(Get-Content $path -Encoding UTF8 | Where-Object { $_.Trim() })) {
        try { $rows += ($line | ConvertFrom-Json) } catch { }
    }
    return @($rows)
}

function Read-JsonFile($path) {
    if (-not (Test-Path $path)) { return $null }
    try { return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

$rows = Read-NdjsonRows $logPath
$snapshot = Read-JsonFile $snapshotPath

if ($rows.Count -eq 0) {
    Write-Host "surface runtime log missing or empty: $logPath"
    exit 0
}

$bootstrapRows = @($rows | Where-Object { $_.type -eq "bootstrap" -and $_.traceSession })
$activeSession = $null
if ($bootstrapRows.Count -gt 0) {
    $activeSession = [string]($bootstrapRows | Select-Object -Last 1).traceSession
    $rows = @($rows | Where-Object { $_.traceSession -eq $activeSession })
}

$tailRows = @($rows | Select-Object -Last $Tail)
$modeRows = @($rows | Where-Object { $_.type -eq "mode_transition" })
$requestRows = @($rows | Where-Object { $_.type -eq "request" })
$coalescedRows = @($rows | Where-Object { $_.type -eq "request_coalesced" })
$openPlanRows = @($rows | Where-Object { $_.type -eq "open_plan" })
$budgetPlanRows = @($rows | Where-Object { $_.type -eq "budget_plan" })
$surfaceRows = @($rows | Where-Object { $_.surface -and $_.surface -ne "" })

$surfaceSummary = @{}
foreach ($row in $surfaceRows) {
    $sid = [string]$row.surface
    if (-not $surfaceSummary.ContainsKey($sid)) {
        $surfaceSummary[$sid] = [ordered]@{
            surface = $sid
            events = 0
            lastType = $null
            lastTs = $null
            lastMode = $null
            lastState = $null
        }
    }
    $item = $surfaceSummary[$sid]
    $item.events += 1
    $item.lastType = $row.type
    $item.lastTs = $row.ts
    $item.lastMode = $row.mode
    if ($row.type -eq "state" -and $row.meta -and $row.meta.state) {
        $item.lastState = [string]$row.meta.state
    }
}

$surfaceTable = @($surfaceSummary.Values | Sort-Object surface)
$requestBySurface = @($requestRows | Group-Object surface | Sort-Object Name | ForEach-Object {
    [ordered]@{
        surface = [string]$_.Name
        count = $_.Count
        actions = @($_.Group | Group-Object { [string]$_.meta.action } | Sort-Object Name | ForEach-Object {
            [ordered]@{
                action = [string]$_.Name
                count = $_.Count
            }
        })
    }
})
$modeTail = @($modeRows | Select-Object -Last 20 | ForEach-Object {
    [ordered]@{
        ts = $_.ts
        stage = $_.meta.stage
        targetMode = $_.meta.targetMode
        token = if ($_.meta.token) { $_.meta.token } else { $null }
    }
})

$warmup = @($rows | Where-Object { $_.type -in @("warmup_start", "warmup_queue", "warmup_step") })
$intentOpenRows = @($rows | Where-Object { $_.type -eq "intent_open" })
$intentCloseRows = @($rows | Where-Object { $_.type -eq "intent_close" })
$intentDisposeRows = @($rows | Where-Object { $_.type -eq "intent_dispose" })
$intentOpenRequests = @($requestRows | Where-Object { $_.meta.source -eq "SurfaceIntent_Open" })
$intentCloseRequests = @($requestRows | Where-Object { $_.meta.source -eq "SurfaceIntent_Close" })
$intentDisposeRequests = @($requestRows | Where-Object { $_.meta.source -eq "SurfaceIntent_Dispose" })
$legacyCloseRequests = @($requestRows | Where-Object {
    $_.meta.action -eq "close" -and $_.meta.source -notin @("SurfaceIntent_Close", "SurfaceIntent_Dispose")
})
$s2GatePass = ($intentOpenRows.Count -gt 0) -and ($intentDisposeRows.Count -gt 0) -and ($intentCloseRows.Count -gt 0)
$txnBeginRows = @($rows | Where-Object { $_.type -eq "transaction_begin" })
$txnCommitRows = @($rows | Where-Object { $_.type -eq "transaction_commit" })
$txnAbortRows = @($rows | Where-Object { $_.type -eq "transaction_abort" })
$txnStaleRows = @($rows | Where-Object { $_.type -eq "transaction_stale" })
$intentOpenWithGen = @($intentOpenRows | Where-Object { $_.meta -and $_.meta.generationId })
$s3GatePass = ($txnBeginRows.Count -gt 0) -and ($txnCommitRows.Count -gt 0) -and ($intentOpenWithGen.Count -gt 0)

$warmupSteps = @($rows | Where-Object { $_.type -eq "warmup_step" })
$bootstrapIncludesReady = @($rows | Where-Object { $_.type -eq "bootstrap" -and $_.meta -and $_.meta.phase -eq "includes_ready" } | Select-Object -Last 1)
$managerEnabledFlag = $null
$interceptWarmupFlag = $null
$enforceBudgetFlag = $null
if ($bootstrapIncludesReady) {
    if ($bootstrapIncludesReady.meta.PSObject.Properties.Name -contains "managerEnabled") {
        $managerEnabledFlag = [string]$bootstrapIncludesReady.meta.managerEnabled
    }
    if ($bootstrapIncludesReady.meta.PSObject.Properties.Name -contains "interceptWarmup") {
        $interceptWarmupFlag = [string]$bootstrapIncludesReady.meta.interceptWarmup
    }
    if ($bootstrapIncludesReady.meta.PSObject.Properties.Name -contains "enforceBudget") {
        $enforceBudgetFlag = [string]$bootstrapIncludesReady.meta.enforceBudget
    }
}
$flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"
if (Test-Path $flagsPath) {
    try {
        $sm = (Get-Content $flagsPath -Raw -Encoding UTF8 | ConvertFrom-Json).surfaceManager
        if ($null -eq $managerEnabledFlag -and $sm) { $managerEnabledFlag = if ($sm.enabled) { "1" } else { "0" } }
        if ($null -eq $interceptWarmupFlag -and $sm) { $interceptWarmupFlag = if ($sm.interceptWarmup) { "1" } else { "0" } }
        if ($null -eq $enforceBudgetFlag -and $sm) { $enforceBudgetFlag = if ($sm.enforceBudget) { "1" } else { "0" } }
    } catch { }
}
function Test-SurfaceRuntimeFlagOn($val) {
    if ($null -eq $val) { return $false }
    $s = [string]$val
    return ($s -eq "1" -or $s -ieq "true")
}
$absentSurfaces = @()
if ($snapshot) {
    $absentSurfaces = @($snapshot | Where-Object { [string]$_.state -eq "ABSENT" } | Select-Object -ExpandProperty id -Unique)
}
$memoryBaselinePath = Join-Path $debugDir "a2ui_memory_baseline.json"
$memoryBaseline = Read-JsonFile $memoryBaselinePath
$currentEmptyMiB = if ($memoryBaseline -and $memoryBaseline.emptyLoadPrivateMiB) { [double]$memoryBaseline.emptyLoadPrivateMiB } else { $null }
$s4GatePass = $s2GatePass -and $s3GatePass `
    -and (Test-SurfaceRuntimeFlagOn $managerEnabledFlag) `
    -and (Test-SurfaceRuntimeFlagOn $interceptWarmupFlag) `
    -and (-not (Test-SurfaceRuntimeFlagOn $enforceBudgetFlag)) `
    -and ($warmupSteps.Count -eq 0) `
    -and ($intentDisposeRows.Count -gt 0) `
    -and ($absentSurfaces.Count -gt 0) `
    -and ($currentEmptyMiB -gt 0)

$out = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    traceSession = $activeSession
    logPath = $logPath
    snapshotPath = $snapshotPath
    totalEvents = $rows.Count
    bootstrapEvents = @($rows | Where-Object { $_.type -eq "bootstrap" }).Count
    warmupEvents = $warmup.Count
    modeTransitionEvents = $modeRows.Count
    requestEvents = $requestRows.Count
    coalescedRequestEvents = $coalescedRows.Count
    openPlanEvents = $openPlanRows.Count
    budgetPlanEvents = $budgetPlanRows.Count
    s2Intent = [ordered]@{
        gatePass = $s2GatePass
        intentOpen = $intentOpenRows.Count
        intentClose = $intentCloseRows.Count
        intentDispose = $intentDisposeRows.Count
        requestSurfaceIntentOpen = $intentOpenRequests.Count
        requestSurfaceIntentClose = $intentCloseRequests.Count
        requestSurfaceIntentDispose = $intentDisposeRequests.Count
        requestCloseLegacyExecutor = $legacyCloseRequests.Count
    }
    s3Transaction = [ordered]@{
        gatePass = $s3GatePass
        transactionBegin = $txnBeginRows.Count
        transactionCommit = $txnCommitRows.Count
        transactionAbort = $txnAbortRows.Count
        transactionStale = $txnStaleRows.Count
        intentOpenWithGenerationId = $intentOpenWithGen.Count
    }
    s4P1Gate = [ordered]@{
        gatePass = $s4GatePass
        managerEnabled = $managerEnabledFlag
        interceptWarmup = $interceptWarmupFlag
        enforceBudget = $enforceBudgetFlag
        warmupSteps = $warmupSteps.Count
        intentDispose = $intentDisposeRows.Count
        registryAbsent = $absentSurfaces.Count
        emptyLoadPrivateMiB = $currentEmptyMiB
    }
    requestBySurface = $requestBySurface
    surfaces = $surfaceTable
    modeTail = $modeTail
    registrySnapshot = $snapshot
    recentEvents = $tailRows
}

$outPath = Join-Path $debugDir "surface_runtime_summary.json"
$out | ConvertTo-Json -Depth 8 | Set-Content -Path $outPath -Encoding UTF8

Write-Host "surface runtime summary -> $outPath"
Write-Host "events=$($rows.Count) surfaces=$($surfaceTable.Count) modeTransitions=$($modeRows.Count) warmup=$($warmup.Count)"
Write-Host "s2 intent_open=$($intentOpenRows.Count) intent_close=$($intentCloseRows.Count) intent_dispose=$($intentDisposeRows.Count) gatePass=$s2GatePass"
Write-Host "s3 transaction_begin=$($txnBeginRows.Count) transaction_commit=$($txnCommitRows.Count) gatePass=$s3GatePass"
Write-Host "s4 managerEnabled=$managerEnabledFlag warmupSteps=$($warmupSteps.Count) emptyLoadMiB=$currentEmptyMiB gatePass=$s4GatePass"
$budgetEnforceRows = @($rows | Where-Object { $_.type -eq "budget_enforce" })
$budgetPressureDispose = @($rows | Where-Object {
    ($_.type -eq "dispose" -or $_.type -eq "intent_dispose") -and $_.meta -and [string]$_.meta.reason -eq "budget_pressure"
})
$s5GatePass = $s4GatePass -and (Test-SurfaceRuntimeFlagOn $enforceBudgetFlag) `
    -and ($budgetPlanRows.Count -gt 0) `
    -and ($budgetEnforceRows.Count -gt 0 -or $budgetPressureDispose.Count -gt 0)
Write-Host "s5 enforceBudget=$enforceBudgetFlag budget_enforce=$($budgetEnforceRows.Count) budget_pressure_dispose=$($budgetPressureDispose.Count) gatePass=$s5GatePass"
exit 0
