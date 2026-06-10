param(
    [string]$RepoRoot = ""
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
$outPath = Join-Path $debugDir "surface_runtime_diagnosis.txt"

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

$lines = @()
$lines += "Surface Runtime Diagnosis"
$lines += "capturedAt=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$lines += "logPath=$logPath"

if ($rows.Count -eq 0) {
    $lines += "status=no_events"
    $lines | Set-Content -Path $outPath -Encoding UTF8
    Write-Host "surface runtime diagnosis -> $outPath"
    exit 0
}

$bootstrapRows = @($rows | Where-Object { $_.type -eq "bootstrap" -and $_.traceSession })
$activeSession = $null
if ($bootstrapRows.Count -gt 0) {
    $activeSession = [string]($bootstrapRows | Select-Object -Last 1).traceSession
    $rows = @($rows | Where-Object { $_.traceSession -eq $activeSession })
}

$warmupSteps = @($rows | Where-Object { $_.type -eq "warmup_step" })
$modeRows = @($rows | Where-Object { $_.type -eq "mode_transition" })
$requestRows = @($rows | Where-Object { $_.type -eq "request" })
$coalescedRows = @($rows | Where-Object { $_.type -eq "request_coalesced" })
$openPlanRows = @($rows | Where-Object { $_.type -eq "open_plan" })
$budgetPlanRows = @($rows | Where-Object { $_.type -eq "budget_plan" })
$activeStates = @($rows | Where-Object { $_.type -eq "state" -and $_.meta -and $_.meta.state -eq "ACTIVE" })
$creatingStates = @($rows | Where-Object { $_.type -eq "state" -and $_.meta -and $_.meta.state -eq "CREATING" })
$surfacesTouched = @($rows | Where-Object { $_.surface -and $_.surface -ne "" } | Select-Object -ExpandProperty surface -Unique | Sort-Object)
$activeTouched = @($activeStates | Select-Object -ExpandProperty surface -Unique | Sort-Object)
$creatingTouched = @($creatingStates | Select-Object -ExpandProperty surface -Unique | Sort-Object)
$requestTouched = @($requestRows | Select-Object -ExpandProperty surface -Unique | Sort-Object)

$lines += "totalEvents=$($rows.Count)"
$lines += "traceSession=$activeSession"
$lines += "warmupSteps=$($warmupSteps.Count)"
$lines += "modeTransitions=$($modeRows.Count)"
$lines += "requestEvents=$($requestRows.Count)"
$lines += "coalescedRequestEvents=$($coalescedRows.Count)"
$lines += "openPlanEvents=$($openPlanRows.Count)"
$lines += "budgetPlanEvents=$($budgetPlanRows.Count)"
$lines += "requestSurfaces=$($requestTouched -join ',')"
$lines += "surfacesTouched=$($surfacesTouched -join ',')"
$lines += "activeSurfaces=$($activeTouched -join ',')"
$lines += "creatingSurfaces=$($creatingTouched -join ',')"

$warmupOrder = @($warmupSteps | ForEach-Object {
    if ($_.meta.callable) { [string]$_.meta.callable } else { "<unknown>" }
})
$lines += "warmupOrder=$($warmupOrder -join ' -> ')"

if ($snapshot) {
    $lines += ""
    $lines += "registrySnapshot:"
    foreach ($item in @($snapshot | Sort-Object id)) {
        $lines += "surface=$($item.id) state=$($item.state) role=$($item.role) runtime=$($item.runtime)"
    }
}

$lines += ""
$lines += "recentBudgetPlans:"
foreach ($row in @($budgetPlanRows | Select-Object -Last 12)) {
    $overages = @($row.meta.overages | ForEach-Object { "$($_.bucket):$($_.used)/$($_.limit)" }) -join ','
    $candidates = @($row.meta.candidates | ForEach-Object { "$($_.surface):$($_.bucket)" }) -join ','
    $lines += "$($row.ts) mode=$($row.meta.mode) reason=$($row.meta.reason) target=$($row.meta.targetSurface) enforceBudget=$($row.meta.enforceBudget) overages=$overages candidates=$candidates"
}

$lines += ""
$lines += "recentOpenPlans:"
foreach ($row in @($openPlanRows | Select-Object -Last 12)) {
    $conflicts = @($row.meta.conflicts | ForEach-Object { "$($_.surface):$($_.state)" }) -join ','
    $lines += "$($row.ts) surface=$($row.surface) source=$($row.meta.source) context=$($row.meta.context) group=$($row.meta.group) enforceSlots=$($row.meta.enforceSlots) shouldEnforce=$($row.meta.shouldEnforce) conflicts=$conflicts"
}

$lines += ""
$lines += "recentRequests:"
foreach ($row in @($requestRows | Select-Object -Last 12)) {
    $lines += "$($row.ts) surface=$($row.surface) action=$($row.meta.action) source=$($row.meta.source) requestId=$($row.meta.requestId)"
}

$lines += ""
$lines += "recentCoalescedRequests:"
foreach ($row in @($coalescedRows | Select-Object -Last 12)) {
    $lines += "$($row.ts) surface=$($row.surface) action=$($row.meta.action) source=$($row.meta.source) requestId=$($row.meta.requestId) elapsedMs=$($row.meta.elapsedMs) state=$($row.meta.state)"
}

$lines += ""
$lines += "recentModeTransitions:"
foreach ($row in @($modeRows | Select-Object -Last 12)) {
    $lines += "$($row.ts) stage=$($row.meta.stage) target=$($row.meta.targetMode) token=$($row.meta.token)"
}

$intentOpenRows = @($rows | Where-Object { $_.type -eq "intent_open" })
$intentCloseRows = @($rows | Where-Object { $_.type -eq "intent_close" })
$intentDisposeRows = @($rows | Where-Object { $_.type -eq "intent_dispose" })
$intentOpenErrRows = @($rows | Where-Object { $_.type -eq "intent_open_error" })
$intentCloseErrRows = @($rows | Where-Object { $_.type -eq "intent_close_error" })
$intentDisposeErrRows = @($rows | Where-Object { $_.type -eq "intent_dispose_error" })
$intentOpenRequests = @($requestRows | Where-Object { $_.meta.source -eq "SurfaceIntent_Open" })
$intentCloseRequests = @($requestRows | Where-Object { $_.meta.source -eq "SurfaceIntent_Close" })
$intentDisposeRequests = @($requestRows | Where-Object { $_.meta.source -eq "SurfaceIntent_Dispose" })
$legacyCloseRequests = @($requestRows | Where-Object {
    $_.meta.action -eq "close" -and $_.meta.source -notin @("SurfaceIntent_Close", "SurfaceIntent_Dispose")
})

$bootstrapRows = @($rows | Where-Object { $_.type -eq "bootstrap" })
$bootstrapIncludesReady = @($bootstrapRows | Where-Object { $_.meta.phase -eq "includes_ready" } | Select-Object -Last 1)
$routeIntentsFlag = $null
$interceptOpenCloseFlag = $null
if ($bootstrapIncludesReady) {
    if ($bootstrapIncludesReady.meta.PSObject.Properties.Name -contains "routeIntents") {
        $routeIntentsFlag = [string]$bootstrapIncludesReady.meta.routeIntents
    }
    if ($bootstrapIncludesReady.meta.PSObject.Properties.Name -contains "interceptOpenClose") {
        $interceptOpenCloseFlag = [string]$bootstrapIncludesReady.meta.interceptOpenClose
    }
}

$lines += ""
$lines += "runtimeFlags:"
$lines += "routeIntents=$routeIntentsFlag"
$lines += "interceptOpenClose=$interceptOpenCloseFlag"

$lines += ""
$lines += "s2IntentGate:"
$lines += "intent_open=$($intentOpenRows.Count)"
$lines += "intent_close=$($intentCloseRows.Count)"
$lines += "intent_dispose=$($intentDisposeRows.Count)"
$lines += "intent_open_error=$($intentOpenErrRows.Count)"
$lines += "intent_close_error=$($intentCloseErrRows.Count)"
$lines += "intent_dispose_error=$($intentDisposeErrRows.Count)"
$lines += "request_source_SurfaceIntent_Open=$($intentOpenRequests.Count)"
$lines += "request_source_SurfaceIntent_Close=$($intentCloseRequests.Count)"
$lines += "request_source_SurfaceIntent_Dispose=$($intentDisposeRequests.Count)"
$lines += "request_close_legacy_executor=$($legacyCloseRequests.Count)"

$s2Pass = ($intentOpenRows.Count -gt 0) -and ($intentDisposeRows.Count -gt 0) -and ($intentCloseRows.Count -gt 0) -and ($intentOpenErrRows.Count -eq 0) -and ($intentCloseErrRows.Count -eq 0)
$lines += "s2_gate_pass=$s2Pass"

$lines += ""
$lines += "recentIntentEvents:"
foreach ($row in @($rows | Where-Object { $_.type -like "intent_*" } | Select-Object -Last 12)) {
    $reqId = if ($row.meta.requestId) { [string]$row.meta.requestId } else { "" }
    $lines += "$($row.ts) type=$($row.type) surface=$($row.surface) requestId=$reqId"
}

$lines += ""
$lines += "recentLegacyCloseRequests:"
foreach ($row in @($legacyCloseRequests | Select-Object -Last 8)) {
    $lines += "$($row.ts) surface=$($row.surface) source=$($row.meta.source) requestId=$($row.meta.requestId)"
}

$lines += ""
$lines += "diagnosis:"
if (($routeIntentsFlag -eq $null -or $routeIntentsFlag -eq "0") -and $intentOpenRows.Count -eq 0) {
    $lines += "S2: routeIntents off or bootstrap flag missing — check local/nmer-flags.json and fully reload 牛马.ahk after code updates."
}
if ($routeIntentsFlag -eq "1" -and $intentOpenRows.Count -eq 0 -and ($requestRows | Where-Object { $_.meta.source -eq "ShowFloatingToolbar" }).Count -gt 0) {
    $lines += "S2: routeIntents=1 but requests still source=ShowFloatingToolbar — reload script to pick up SurfaceIntent_RouteExternal* executor hooks."
}
if ($intentOpenRows.Count -eq 0 -and $intentCloseRows.Count -eq 0 -and $requestRows.Count -gt 0) {
    $lines += "S2: session only exercised startup/resident open; run interactive close tests (Esc CP, hide VK, >dispose ftb)."
}
if ($intentOpenRows.Count -gt 0 -and $intentCloseRows.Count -eq 0) {
    $lines += "S2: intent_open present but intent_close missing — close paths still use executor *_Hide (CommandPalette_Hide/VK_Hide/HideFloatingToolbar). Exercise SurfaceIntent_Close entry points: appearance mode switch, tray hide FTB, FTB panel close."
}
if ($intentCloseRows.Count -gt 0 -and $intentCloseRequests.Count -eq 0) {
    $lines += "S2: intent_close events exist without SurfaceIntent_Close requests — check duplicate instrumentation."
}
if ($legacyCloseRequests.Count -gt 0 -and $intentCloseRows.Count -eq 0) {
    $lines += "S2: $($legacyCloseRequests.Count) close request(s) via legacy executor; expected until GUI/Esc paths are routed or补测 covers P0 Close intents."
}
if ($creatingTouched.Count -gt 3 -and $activeTouched.Count -le 1) {
    $lines += "startup eagerly creates multiple hidden surfaces before user intent."
}
if ($warmupOrder.Count -ge 4) {
    $lines += "warmup queue still preloads CP/PQP/SCWV/VK under legacy_default policy."
}
if ($requestRows.Count -eq 0) {
    $lines += "open/close shadow router not exercised yet in this session."
}
if ($requestRows.Count -gt 0 -and -not ($requestTouched -contains "floating_toolbar")) {
    $lines += "resident toolbar is still outside request routing, so global arbitration remains incomplete."
}
if ($coalescedRows.Count -gt 0) {
    $lines += "duplicate open/close bursts are now being detected at the global request layer."
}
if ($openPlanRows.Count -gt 0) {
    $lines += "slot-based arbitration planning is active; enforcement still depends on enforceSlots."
}
if ($budgetPlanRows.Count -gt 0) {
    $lines += "mode-specific budget planning is active; enforcement still depends on enforceBudget."
}
if ($activeTouched -contains "floating_toolbar" -and $creatingTouched -contains "search_center") {
    $lines += "toolbar becomes active while search center remains pre-created but hidden, confirming idle preload overhead."
}

$lines | Set-Content -Path $outPath -Encoding UTF8
Write-Host "surface runtime diagnosis -> $outPath"
exit 0
