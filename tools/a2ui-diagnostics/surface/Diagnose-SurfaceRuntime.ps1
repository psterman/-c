param(
    [string]$RepoRoot = ""
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
} else {
    $RepoRoot = (Resolve-Path $RepoRoot).Path
}

$debugDir = Join-Path $RepoRoot "Cache\debug"
$logPath = Join-Path $debugDir "surface_runtime.ndjson"
$snapshotPath = Join-Path $debugDir "surface_registry_snapshot.json"
$outPath = Join-Path $debugDir "surface_runtime_diagnosis.txt"
$jsonPath = Join-Path $debugDir "surface_runtime_diagnosis.json"

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

function Test-SurfaceRuntimeFlagOn($val) {
    if ($null -eq $val) { return $false }
    $s = [string]$val
    return ($s -eq "1" -or $s -ieq "true")
}

function Read-SurfaceManagerFlags($repoRoot) {
    $path = Join-Path $repoRoot "local\nmer-flags.json"
    if (-not (Test-Path $path)) { return $null }
    try {
        $root = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        $sm = $root.surfaceManager
        if ($sm) { return $sm }
    } catch { }
    return $null
}

function Test-MemoryBaselineLooksCpLoaded($memoryBaseline, $currentWv2Count, $memoryImproved) {
    if (-not $memoryBaseline) { return $true }
    $kind = ""
    if ($memoryBaseline.PSObject.Properties.Name -contains "snapshotKind") {
        $kind = [string]$memoryBaseline.snapshotKind
    }
    if ($kind -eq "cp_loaded") { return $true }
    $cpLoadedMiB = $null
    if ($memoryBaseline.PSObject.Properties.Name -contains "cpLoadedPrivateMiB") {
        $cpLoadedMiB = $memoryBaseline.cpLoadedPrivateMiB
    }
    if ($null -ne $cpLoadedMiB -and [double]$cpLoadedMiB -gt 0) { return $true }
    # Wails sidecar era: empty load may have webview2_count>8; trust capture snapshotKind=empty
    if ($kind -eq "empty" -and $memoryImproved) { return $false }
    if ($currentWv2Count -ne $null -and $currentWv2Count -ge 8) { return $true }
    if ($currentWv2Count -ne $null -and $currentWv2Count -le 8 -and $memoryImproved) {
        return $false
    }
    return $false
}

function Get-S0MemoryReference($debugDir) {
    $out = @{
        emptyLoadPrivateMiB = $null
        webview2_count = $null
        source = "none"
    }
    $manifestPath = Join-Path $debugDir "pre-p1\manifest.json"
    if (Test-Path $manifestPath) {
        try {
            $m = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($m.PSObject.Properties.Name -contains "emptyLoadPrivateMiB") {
                $out.emptyLoadPrivateMiB = [double]$m.emptyLoadPrivateMiB
                $out.source = "pre-p1/manifest.json"
            } elseif ($m.memoryBaseline -and $m.memoryBaseline.emptyLoadPrivateMiB) {
                $out.emptyLoadPrivateMiB = [double]$m.memoryBaseline.emptyLoadPrivateMiB
                $out.source = "pre-p1/manifest.json#memoryBaseline"
            }
            if ($m.PSObject.Properties.Name -contains "webview2_count") {
                $out.webview2_count = [int]$m.webview2_count
            } elseif ($m.processes -and $m.processes.webview2_count) {
                $out.webview2_count = [int]$m.processes.webview2_count
            }
        } catch { }
    }
    # 勿用 a2ui_memory_empty_archive.json 作 S0：日常空载 capture 会覆盖，导致 current==s0 永远失败
    if ($null -eq $out.emptyLoadPrivateMiB) {
        $out.emptyLoadPrivateMiB = 1493.29
        $out.webview2_count = if ($null -eq $out.webview2_count) { 24 } else { $out.webview2_count }
        $out.source = "docs/a2ui-rollout-baseline-20260608.md"
    }
    return $out
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
    @{
        capturedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        status = "no_events"
        s2_gate_pass = $false
        s3_gate_pass = $false
        s4_gate_pass = $false
        s5_gate_pass = $false
        diagnosis = @("no surface_runtime events yet; reload niuma and open/close a panel first")
    } | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Host "surface runtime diagnosis -> $outPath"
    Write-Host "surface runtime dashboard json -> $jsonPath"
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
$useTransactionsFlag = $null
$interceptOpenCloseFlag = $null
$managerEnabledFlag = $null
$interceptWarmupFlag = $null
$enforceBudgetFlag = $null
$enforceSlotsFlag = $null
if ($bootstrapIncludesReady) {
    if ($bootstrapIncludesReady.meta.PSObject.Properties.Name -contains "routeIntents") {
        $routeIntentsFlag = [string]$bootstrapIncludesReady.meta.routeIntents
    }
    if ($bootstrapIncludesReady.meta.PSObject.Properties.Name -contains "useTransactions") {
        $useTransactionsFlag = [string]$bootstrapIncludesReady.meta.useTransactions
    }
    if ($bootstrapIncludesReady.meta.PSObject.Properties.Name -contains "interceptOpenClose") {
        $interceptOpenCloseFlag = [string]$bootstrapIncludesReady.meta.interceptOpenClose
    }
    if ($bootstrapIncludesReady.meta.PSObject.Properties.Name -contains "managerEnabled") {
        $managerEnabledFlag = [string]$bootstrapIncludesReady.meta.managerEnabled
    }
    if ($bootstrapIncludesReady.meta.PSObject.Properties.Name -contains "interceptWarmup") {
        $interceptWarmupFlag = [string]$bootstrapIncludesReady.meta.interceptWarmup
    }
    if ($bootstrapIncludesReady.meta.PSObject.Properties.Name -contains "enforceBudget") {
        $enforceBudgetFlag = [string]$bootstrapIncludesReady.meta.enforceBudget
    }
    if ($bootstrapIncludesReady.meta.PSObject.Properties.Name -contains "enforceSlots") {
        $enforceSlotsFlag = [string]$bootstrapIncludesReady.meta.enforceSlots
    }
}

$smFlagsFile = Read-SurfaceManagerFlags $RepoRoot
if ($smFlagsFile) {
    if ($null -eq $managerEnabledFlag) { $managerEnabledFlag = if ($smFlagsFile.enabled) { "1" } else { "0" } }
    if ($null -eq $interceptWarmupFlag) { $interceptWarmupFlag = if ($smFlagsFile.interceptWarmup) { "1" } else { "0" } }
    if ($null -eq $enforceBudgetFlag) { $enforceBudgetFlag = if ($smFlagsFile.enforceBudget) { "1" } else { "0" } }
    if ($null -eq $enforceSlotsFlag) { $enforceSlotsFlag = if ($smFlagsFile.enforceSlots) { "1" } else { "0" } }
    if ($null -eq $routeIntentsFlag) { $routeIntentsFlag = if ($smFlagsFile.routeIntents) { "1" } else { "0" } }
    if ($null -eq $useTransactionsFlag) { $useTransactionsFlag = if ($smFlagsFile.useTransactions) { "1" } else { "0" } }
}

$lines += ""
$lines += "runtimeFlags:"
$lines += "managerEnabled=$managerEnabledFlag"
$lines += "routeIntents=$routeIntentsFlag"
$lines += "useTransactions=$useTransactionsFlag"
$lines += "interceptOpenClose=$interceptOpenCloseFlag"
$lines += "interceptWarmup=$interceptWarmupFlag"
$lines += "enforceBudget=$enforceBudgetFlag"
$lines += "enforceSlots=$enforceSlotsFlag"

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

$nonFtbIntentOpens = @($intentOpenRows | Where-Object { $_.surface -ne "floating_toolbar" })
$cpIntentOpens = @($intentOpenRows | Where-Object { $_.surface -eq "command_palette" })
$startupOnlySession = ($intentOpenRows.Count -gt 0) -and ($intentCloseRows.Count -eq 0) -and ($intentDisposeRows.Count -eq 0) -and ($nonFtbIntentOpens.Count -eq 0)

$s2Pass = ($intentOpenRows.Count -gt 0) -and ($intentDisposeRows.Count -gt 0) -and ($intentCloseRows.Count -gt 0) -and ($intentOpenErrRows.Count -eq 0) -and ($intentCloseErrRows.Count -eq 0)
$s2FailureReasons = @()
if ($intentOpenRows.Count -le 0) { $s2FailureReasons += "missing_intent_open" }
if ($intentCloseRows.Count -le 0) { $s2FailureReasons += "missing_intent_close" }
if ($intentDisposeRows.Count -le 0) { $s2FailureReasons += "missing_intent_dispose" }
if ($startupOnlySession) { $s2FailureReasons += "startup_only_session" }
if ($intentOpenErrRows.Count -gt 0) { $s2FailureReasons += "intent_open_error" }
if ($intentCloseErrRows.Count -gt 0) { $s2FailureReasons += "intent_close_error" }
$lines += "s2_gate_pass=$s2Pass"

$txnBeginRows = @($rows | Where-Object { $_.type -eq "transaction_begin" })
$txnCommitRows = @($rows | Where-Object { $_.type -eq "transaction_commit" })
$txnAbortRows = @($rows | Where-Object { $_.type -eq "transaction_abort" })
$txnStaleRows = @($rows | Where-Object { $_.type -eq "transaction_stale" })
$intentOpenWithGen = @($intentOpenRows | Where-Object { $_.meta -and $_.meta.generationId })
$requestOpenWithGen = @($intentOpenRequests | Where-Object { $_.meta -and $_.meta.generationId })

$lines += ""
$lines += "s3TransactionGate:"
$lines += "transaction_begin=$($txnBeginRows.Count)"
$lines += "transaction_commit=$($txnCommitRows.Count)"
$lines += "transaction_abort=$($txnAbortRows.Count)"
$lines += "transaction_stale=$($txnStaleRows.Count)"
$lines += "intent_open_with_generationId=$($intentOpenWithGen.Count)"
$lines += "request_open_with_generationId=$($requestOpenWithGen.Count)"

$s3Pass = (Test-SurfaceRuntimeFlagOn $useTransactionsFlag) -and ($txnBeginRows.Count -gt 0) -and ($txnCommitRows.Count -gt 0) -and ($intentOpenWithGen.Count -gt 0)
$lines += "s3_gate_pass=$s3Pass"

$warmupPlanRows = @($rows | Where-Object { $_.type -eq "warmup_plan" })
$lazyWarmupPlan = @($warmupPlanRows | Where-Object { $_.meta -and $_.meta.policy -eq "lazy_all" })
$absentAfterDispose = @()
if ($snapshot) {
    $absentAfterDispose = @($snapshot | Where-Object { [string]$_.state -eq "ABSENT" } | Select-Object -ExpandProperty id -Unique)
}

$memoryBaselinePath = Join-Path $debugDir "a2ui_memory_baseline.json"
$memoryBaseline = Read-JsonFile $memoryBaselinePath
$s0Ref = Get-S0MemoryReference $debugDir
$currentEmptyMiB = $null
$currentWv2Count = $null
if ($memoryBaseline) {
    if ($memoryBaseline.PSObject.Properties.Name -contains "emptyLoadPrivateMiB") {
        $currentEmptyMiB = [double]$memoryBaseline.emptyLoadPrivateMiB
    }
    if ($memoryBaseline.processes -and $memoryBaseline.processes.webview2_count -ne $null) {
        $currentWv2Count = [int]$memoryBaseline.processes.webview2_count
    }
}

$memoryImproved = $false
$memoryStatus = "missing_baseline"
if ($currentEmptyMiB -gt 0 -and $s0Ref.emptyLoadPrivateMiB -gt 0) {
    $memoryImproved = ($currentEmptyMiB -lt $s0Ref.emptyLoadPrivateMiB)
    $memoryStatus = if ($memoryImproved) { "improved_vs_s0" } else { "not_improved_vs_s0" }
}
$wv2Improved = $false
if ($currentWv2Count -ne $null -and $s0Ref.webview2_count -ne $null) {
    $wv2Improved = ($currentWv2Count -lt $s0Ref.webview2_count)
}

$warmupOk = (Test-SurfaceRuntimeFlagOn $interceptWarmupFlag) -and ($warmupSteps.Count -eq 0)
$bootstrapHasS4Fields = $false
if ($bootstrapIncludesReady) {
    $bootstrapHasS4Fields = ($bootstrapIncludesReady.meta.PSObject.Properties.Name -contains "managerEnabled") `
        -and ($bootstrapIncludesReady.meta.PSObject.Properties.Name -contains "interceptWarmup")
}
$managerOn = Test-SurfaceRuntimeFlagOn $managerEnabledFlag
$budgetOff = -not (Test-SurfaceRuntimeFlagOn $enforceBudgetFlag)
$disposeAbsentOk = ($intentDisposeRows.Count -gt 0) -and ($absentAfterDispose.Count -gt 0)
$memoryLooksCpLoaded = Test-MemoryBaselineLooksCpLoaded $memoryBaseline $currentWv2Count $memoryImproved

$s4FailureReasons = @()
if (-not $s2Pass) { $s4FailureReasons += "s2_prereq_failed" }
if (-not $s3Pass) { $s4FailureReasons += "s3_prereq_failed" }
if (-not $bootstrapHasS4Fields) { $s4FailureReasons += "bootstrap_stale_reload_required" }
if (-not $managerOn) { $s4FailureReasons += "manager_not_enabled" }
if (-not (Test-SurfaceRuntimeFlagOn $interceptWarmupFlag)) { $s4FailureReasons += "intercept_warmup_off" }
if ($warmupSteps.Count -ge 4) { $s4FailureReasons += "legacy_warmup_four_chain" }
if (-not $warmupOk -and $warmupSteps.Count -gt 0) { $s4FailureReasons += "warmup_steps_present" }
if ($memoryStatus -eq "missing_baseline") { $s4FailureReasons += "memory_baseline_missing" }
elseif ($memoryLooksCpLoaded) { $s4FailureReasons += "memory_captured_while_cp_loaded" }
elseif (-not $memoryImproved) { $s4FailureReasons += "memory_not_improved_vs_s0" }
if (-not $disposeAbsentOk) { $s4FailureReasons += "dispose_absent_not_observed" }

$s4Pass = ($s4FailureReasons.Count -eq 0)

$lines += ""
$lines += "s4P1Gate:"
$lines += "managerEnabled=$managerEnabledFlag"
$lines += "interceptWarmup=$interceptWarmupFlag"
$lines += "enforceBudget=$enforceBudgetFlag"
$lines += "warmupSteps=$($warmupSteps.Count)"
$lines += "warmup_plan_lazy_all=$($lazyWarmupPlan.Count)"
$lines += "s0_emptyLoadPrivateMiB=$($s0Ref.emptyLoadPrivateMiB)"
$lines += "s0_webview2_count=$($s0Ref.webview2_count)"
$lines += "s0_reference_source=$($s0Ref.source)"
$lines += "current_emptyLoadPrivateMiB=$currentEmptyMiB"
$lines += "current_webview2_count=$currentWv2Count"
$lines += "memory_status=$memoryStatus"
$lines += "memory_improved_vs_s0=$memoryImproved"
$lines += "webview2_improved_vs_s0=$wv2Improved"
$lines += "registry_absent_surfaces=$($absentAfterDispose -join ',')"
$lines += "s4_gate_pass=$s4Pass"

$budgetEnforceRows = @($rows | Where-Object { $_.type -eq "budget_enforce" })
$budgetHandoffRows = @($rows | Where-Object {
    $_.type -eq "budget_enforce" -and $_.meta -and [string]$_.meta.reason -eq "primary_handoff"
})
$searchPreemptCloseRows = @($rows | Where-Object {
    ($_.type -eq "intent_close") -and $_.surface -eq "command_palette" -and $_.meta -and [string]$_.meta.reason -eq "search_preempt"
})
$budgetPressureDisposeRows = @($rows | Where-Object {
    ($_.type -eq "dispose" -or $_.type -eq "intent_dispose") -and $_.meta -and [string]$_.meta.reason -eq "budget_pressure"
})
$budgetConflictResolved = ($budgetEnforceRows.Count -gt 0) -or ($budgetPressureDisposeRows.Count -gt 0) -or ($budgetHandoffRows.Count -gt 0) -or ($searchPreemptCloseRows.Count -gt 0)
$budgetPlanWithBaseline = @($budgetPlanRows | Where-Object {
    $_.meta -and $_.meta.policy -and (
        $_.meta.policy.baselineRef -or $_.meta.policy.baselineSource -or $_.meta.policy.emptyLoadWv2
    )
})
$budgetPlanEnforced = @($budgetPlanRows | Where-Object { $_.meta -and (Test-SurfaceRuntimeFlagOn $_.meta.enforceBudget) })
$budgetOn = Test-SurfaceRuntimeFlagOn $enforceBudgetFlag

$s5FailureReasons = @()
if (-not $s4Pass) { $s5FailureReasons += "s4_prereq_failed" }
if (-not $budgetOn) { $s5FailureReasons += "enforce_budget_off" }
if ($budgetPlanRows.Count -le 0) { $s5FailureReasons += "missing_budget_plan" }
if ($budgetPlanWithBaseline.Count -le 0) { $s5FailureReasons += "policy_missing_baseline_ref" }
if (-not $budgetConflictResolved) {
    $s5FailureReasons += "missing_budget_conflict_resolution"
}
$s5Pass = ($s5FailureReasons.Count -eq 0)

$lines += ""
$lines += "s5BudgetGate:"
$lines += "enforceBudget=$enforceBudgetFlag"
$lines += "budget_plan=$($budgetPlanRows.Count)"
$lines += "budget_plan_with_baseline=$($budgetPlanWithBaseline.Count)"
$lines += "budget_plan_enforced=$($budgetPlanEnforced.Count)"
$lines += "budget_enforce=$($budgetEnforceRows.Count)"
$lines += "budget_handoff=$($budgetHandoffRows.Count)"
$lines += "search_preempt_close=$($searchPreemptCloseRows.Count)"
$lines += "budget_pressure_dispose=$($budgetPressureDisposeRows.Count)"
$lines += "s5_gate_pass=$s5Pass"

$slotSuspendRows = @($rows | Where-Object {
    $_.type -eq "suspend" -and $_.meta -and [string]$_.meta.reason -eq "slot_conflict"
})
$hotkeyEnforcePlans = @($openPlanRows | Where-Object {
    $_.surface -eq "search_center" -and $_.meta -and [string]$_.meta.context -eq "external_hotkey" -and (Test-SurfaceRuntimeFlagOn $_.meta.shouldEnforce)
})
$toolbarEnforcePlans = @($openPlanRows | Where-Object {
    $_.surface -eq "search_center" -and $_.meta -and [string]$_.meta.context -eq "internal_toolbar" -and (Test-SurfaceRuntimeFlagOn $_.meta.shouldEnforce)
})
$primaryConflictResolved = ($slotSuspendRows.Count -gt 0) -or $budgetConflictResolved
$overlayActiveWithPrimary = $false
if ($snapshot) {
    $primaryActive = @($snapshot | Where-Object { $_.role -eq "primary" -and $_.state -eq "ACTIVE" })
    $overlayActive = @($snapshot | Where-Object { $_.role -eq "overlay" -and $_.state -eq "ACTIVE" })
    if ($primaryActive.Count -gt 0 -and $overlayActive.Count -gt 0) {
        $overlayActiveWithPrimary = $true
    }
}
$slotsOn = Test-SurfaceRuntimeFlagOn $enforceSlotsFlag

$s6FailureReasons = @()
if (-not $s5Pass) { $s6FailureReasons += "s5_prereq_failed" }
if (-not $slotsOn) { $s6FailureReasons += "enforce_slots_off" }
if ($hotkeyEnforcePlans.Count -le 0) { $s6FailureReasons += "missing_hotkey_should_enforce" }
if (-not $primaryConflictResolved) { $s6FailureReasons += "missing_primary_conflict_resolution" }
if ($overlayActiveWithPrimary) { $s6FailureReasons += "overlay_coexists_with_primary" }
$s6Pass = ($s6FailureReasons.Count -eq 0)

$lines += ""
$lines += "s6SlotsGate:"
$lines += "enforceSlots=$enforceSlotsFlag"
$lines += "slot_suspend_conflict=$($slotSuspendRows.Count)"
$lines += "hotkey_should_enforce_plans=$($hotkeyEnforcePlans.Count)"
$lines += "toolbar_should_enforce_plans=$($toolbarEnforcePlans.Count)"
$lines += "primary_conflict_resolved=$primaryConflictResolved"
$lines += "overlay_active_with_primary=$overlayActiveWithPrimary"
$lines += "s6_gate_pass=$s6Pass"

$lines += ""
$lines += "recentTransactionEvents:"
foreach ($row in @($rows | Where-Object { $_.type -like "transaction_*" } | Select-Object -Last 12)) {
    $genId = if ($row.meta.generationId) { [string]$row.meta.generationId } else { "" }
    $reason = if ($row.meta.reason) { [string]$row.meta.reason } else { "" }
    $lines += "$($row.ts) type=$($row.type) surface=$($row.surface) generationId=$genId reason=$reason"
}

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
    $lines += "S2: session only exercised startup/resident open; run interactive close tests (Esc CP, hide VK, dispose ftb)."
}
if ($startupOnlySession) {
    $lines += "S2: startup_only_session — only floating_toolbar intent_open ($($intentOpenRows.Count)x) from mode/bootstrap; no CP/SC interaction. Run STEP 1-5 in ONE session BEFORE opening dashboard (double-tap CapsLock, Esc, >dispose ftb, CP open, CapsLock+F)."
}
if ($intentOpenRows.Count -gt 0 -and $intentCloseRows.Count -eq 0 -and -not $startupOnlySession) {
    $lines += "S2: intent_open present but intent_close missing — close paths still use executor *_Hide (CommandPalette_Hide/VK_Hide/HideFloatingToolbar). Exercise SurfaceIntent_Close entry points: appearance mode switch, tray hide FTB, FTB panel close."
}
if ($cpIntentOpens.Count -eq 0 -and $intentOpenRows.Count -gt 0 -and -not $startupOnlySession) {
    $lines += "S3: no command_palette intent_open — double-tap CapsLock to open CP (S3 txn only begins for non-FTB surfaces)."
}
if ($intentCloseRows.Count -gt 0 -and $intentCloseRequests.Count -eq 0) {
    $lines += "S2: intent_close events exist without SurfaceIntent_Close requests — check duplicate instrumentation."
}
if ($legacyCloseRequests.Count -gt 0 -and $intentCloseRows.Count -eq 0) {
    $lines += "S2: $($legacyCloseRequests.Count) close request(s) via legacy executor; expected until GUI/Esc paths are routed or补测 covers P0 Close intents."
}
if ((Test-SurfaceRuntimeFlagOn $useTransactionsFlag) -and $txnBeginRows.Count -eq 0 -and $intentOpenRows.Count -gt 0) {
    $lines += "S3: useTransactions=1 but no transaction_begin — reload 牛马.ahk after SurfaceTransaction.ahk update."
}
if ((Test-SurfaceRuntimeFlagOn $useTransactionsFlag) -and $txnBeginRows.Count -gt 0 -and $txnCommitRows.Count -eq 0) {
    $lines += "S3: transaction_begin without commit — async Show may not reach ObserveShow, or open still in CREATING."
}
if ($txnStaleRows.Count -gt 0) {
    $lines += "S3: stale generation callbacks detected (expected on rapid re-open / superseded transactions)."
}
if ($creatingTouched.Count -gt 3 -and $activeTouched.Count -le 1) {
    $lines += "startup eagerly creates multiple hidden surfaces before user intent."
}
if ($warmupOrder.Count -ge 4) {
    $lines += "warmup queue still preloads CP/PQP/SCWV/VK under legacy_default policy."
}
if (-not (Test-SurfaceRuntimeFlagOn $managerEnabledFlag)) {
    $lines += "S4: managerEnabled=0 — set local/nmer-flags.json surfaceManager.enabled=true and reload 牛马.ahk."
}
if (-not $bootstrapHasS4Fields) {
    $lines += "S4: bootstrap missing managerEnabled/interceptWarmup — reload 牛马.ahk after S4 code+flags update."
}
if ($memoryStatus -eq "missing_baseline") {
    $lines += "S4: run capture-memory-baseline.ps1 on idle load (no CP open) after reload with interceptWarmup."
}
if ($memoryLooksCpLoaded) {
    $lines += "S4: memory baseline looks CP-loaded (snapshotKind=cp_loaded or cpLoadedPrivateMiB set) — reload, close panels, capture-memory-baseline.ps1 before interaction tests."
}
if ($memoryStatus -eq "not_improved_vs_s0") {
    $lines += "S4: emptyLoadPrivateMiB not below S0 ($($s0Ref.emptyLoadPrivateMiB) MiB from $($s0Ref.source)); verify interceptWarmup and no legacy warmup_step."
}
if ($intentDisposeRows.Count -gt 0 -and $absentAfterDispose.Count -eq 0) {
    $lines += "S4: intent_dispose fired but registry has no ABSENT surface — run >dispose ftb then re-run diagnosis."
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
if (-not $budgetOn) {
    $lines += "S5: set surfaceManager.enforceBudget=true in local/nmer-flags.json and reload 牛马.ahk."
}
if ($budgetOn -and -not $budgetConflictResolved) {
    $lines += "S5: open CP then CapsLock+F; expect search_preempt close, primary_handoff suspend, or budget_enforce."
}
if ($budgetOn -and $budgetPlanRows.Count -eq 0 -and $budgetPressureDisposeRows.Count -gt 0) {
    $lines += 'S5: budget_pressure dispose fired but budget_plan missing; fully exit and reload niuma.ahk (dashboard refresh does not load new code).'
}
if ($slotsOn -and $hotkeyEnforcePlans.Count -le 0) {
    $lines += 'S6: open search center via search hotkey while command palette may be open; expect open_plan.shouldEnforce=1.'
}
if ($slotsOn -and -not $primaryConflictResolved) {
    $lines += 'S6: primary conflict not resolved; need search_preempt, primary_handoff, slot_conflict, or budget_pressure dispose.'
}
$budgetPlanErrorRows = @($rows | Where-Object { $_.type -eq 'budget_plan_error' })
if ($budgetPlanErrorRows.Count -gt 0) {
    $lastErr = $budgetPlanErrorRows | Select-Object -Last 1
    $errMsg = if ($lastErr.meta.message) { [string]$lastErr.meta.message } else { '' }
    $lines += "S5: budget_plan_error=$errMsg"
}
if ($activeTouched -contains "floating_toolbar" -and $creatingTouched -contains "search_center") {
    $lines += "toolbar becomes active while search center remains pre-created but hidden, confirming idle preload overhead."
}

$diagnosisHints = @()
if (($routeIntentsFlag -eq $null -or $routeIntentsFlag -eq "0") -and $intentOpenRows.Count -eq 0) {
    $diagnosisHints += "S2-json: routeIntents off or bootstrap missing; check local/nmer-flags.json and reload niuma.ahk"
}
if ((Test-SurfaceRuntimeFlagOn $useTransactionsFlag) -and $txnBeginRows.Count -gt 0 -and $txnCommitRows.Count -eq 0) {
    $diagnosisHints += "S3-json: begin without commit; CP cold start needs ObserveShow after DoShow when WebView2 ready; reload and open CP until visible"
}
foreach ($line in $lines) {
    if ($line -like "S2:*" -or $line -like "S3:*" -or $line -like "S4:*" -or $line -like "S5:*" -or $line -like "startup*" -or $line -like "warmup*" -or $line -like "slot*" -or $line -like "mode-specific*") {
        if ($line -notin $diagnosisHints) { $diagnosisHints += $line }
    }
}

$registryList = @()
if ($snapshot) {
    foreach ($item in @($snapshot | Sort-Object id)) {
        $registryList += @{
            id = [string]$item.id
            state = [string]$item.state
            role = [string]$item.role
            runtime = [string]$item.runtime
        }
    }
}

$recentTxn = @($rows | Where-Object { $_.type -like "transaction_*" } | Select-Object -Last 12 | ForEach-Object {
    @{
        ts = [string]$_.ts
        type = [string]$_.type
        surface = [string]$_.surface
        generationId = if ($_.meta.generationId) { [string]$_.meta.generationId } else { "" }
        reason = if ($_.meta.reason) { [string]$_.meta.reason } else { "" }
    }
})

$gates = @(
    @{
        id = "s2"
        title = "S2 Intent Router"
        pass = [bool]$s2Pass
        metrics = @{
            intent_open = $intentOpenRows.Count
            intent_close = $intentCloseRows.Count
            intent_dispose = $intentDisposeRows.Count
            intent_open_error = $intentOpenErrRows.Count
        }
    },
    @{
        id = "s3"
        title = "S3 generationId Transaction"
        pass = [bool]$s3Pass
        metrics = @{
            transaction_begin = $txnBeginRows.Count
            transaction_commit = $txnCommitRows.Count
            transaction_abort = $txnAbortRows.Count
            transaction_timeout = @($rows | Where-Object { $_.type -eq "transaction_timeout" }).Count
            intent_open_with_generationId = $intentOpenWithGen.Count
        }
    },
    @{
        id = "s4"
        title = "S4 P1 门禁"
        pass = [bool]$s4Pass
        metrics = @{
            managerEnabled = $managerEnabledFlag
            warmupSteps = $warmupSteps.Count
            emptyLoadPrivateMiB = $currentEmptyMiB
            s0_emptyLoadPrivateMiB = $s0Ref.emptyLoadPrivateMiB
            webview2_count = $currentWv2Count
            s0_webview2_count = $s0Ref.webview2_count
            intent_dispose = $intentDisposeRows.Count
            registry_absent = $absentAfterDispose.Count
        }
    },
    @{
        id = "s5"
        title = "S5 enforceBudget"
        pass = [bool]$s5Pass
        metrics = @{
            enforceBudget = $enforceBudgetFlag
            budget_plan = $budgetPlanRows.Count
            budget_enforce = $budgetEnforceRows.Count
            budget_handoff = $budgetHandoffRows.Count
            search_preempt_close = $searchPreemptCloseRows.Count
            budget_pressure_dispose = $budgetPressureDisposeRows.Count
            policy_baseline_ref = $budgetPlanWithBaseline.Count
        }
    },
    @{
        id = "s6"
        title = "S6 enforceSlots"
        pass = [bool]$s6Pass
        metrics = @{
            enforceSlots = $enforceSlotsFlag
            hotkey_should_enforce = $hotkeyEnforcePlans.Count
            slot_suspend_conflict = $slotSuspendRows.Count
            toolbar_should_enforce = $toolbarEnforcePlans.Count
            primary_conflict_resolved = $(if ($primaryConflictResolved) { 1 } else { 0 })
        }
    }
)

@{
    capturedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    traceSession = $activeSession
    runtimeFlags = @{
        managerEnabled = $managerEnabledFlag
        routeIntents = $routeIntentsFlag
        useTransactions = $useTransactionsFlag
        interceptOpenClose = $interceptOpenCloseFlag
        interceptWarmup = $interceptWarmupFlag
        enforceBudget = $enforceBudgetFlag
        enforceSlots = $enforceSlotsFlag
    }
    gates = $gates
    s2_gate_pass = [bool]$s2Pass
    s3_gate_pass = [bool]$s3Pass
    s4_gate_pass = [bool]$s4Pass
    s5_gate_pass = [bool]$s5Pass
    s6_gate_pass = [bool]$s6Pass
    s2_failure_reasons = @($s2FailureReasons)
    s4_failure_reasons = @($s4FailureReasons)
    s5_failure_reasons = @($s5FailureReasons)
    s6_failure_reasons = @($s6FailureReasons)
    memoryGate = @{
        status = $memoryStatus
        improved_vs_s0 = [bool]$memoryImproved
        webview2_improved_vs_s0 = [bool]$wv2Improved
        s0_reference_source = $s0Ref.source
        s0_emptyLoadPrivateMiB = $s0Ref.emptyLoadPrivateMiB
        s0_webview2_count = $s0Ref.webview2_count
        current_emptyLoadPrivateMiB = $currentEmptyMiB
        current_webview2_count = $currentWv2Count
    }
    registry = $registryList
    activeSurfaces = @($activeTouched)
    creatingSurfaces = @($creatingTouched)
    recentTransactionEvents = $recentTxn
    diagnosis = $diagnosisHints
    logPath = $logPath
} | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding UTF8

$lines | Set-Content -Path $outPath -Encoding UTF8
Write-Host "surface runtime diagnosis -> $outPath"
Write-Host "surface runtime dashboard json -> $jsonPath"
exit 0
