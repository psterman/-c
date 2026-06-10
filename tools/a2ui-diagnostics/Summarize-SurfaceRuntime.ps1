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
exit 0
