# Hybrid 运行终验看板数据采集 -> Cache/debug/hybrid_signoff_dashboard.json
param(
    [string]$RepoRoot = "",
    [ValidateSet("formal", "formal-cold", "warm-session", "relaxed", "live", "smoke", "dev")]
    [string]$SignoffMode = "live",
    [switch]$SkipBaselineCapture,
    [switch]$SkipS11Static,
    [switch]$SkipHubChain,
    [switch]$SkipCycle,
    [switch]$RunOpenClawSmoke
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Continue"
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
$outPath = Join-Path $debugDir "hybrid_signoff_dashboard.json"
$flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"
$memoryDeltaLimitMiB = 80

function Read-JsonFile([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    try { return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

# --- static S11 ---
if (-not $SkipS11Static) {
    & (Join-DiagScript -RelativePath "surface/Diagnose-S11HybridFTBGate.ps1") -RepoRoot $RepoRoot | Out-Host
}

# --- memory baseline ---
if (-not $SkipBaselineCapture) {
    & (Join-DiagScript -RelativePath "memory/capture-memory-baseline.ps1") -RepoRoot $RepoRoot | Out-Host
}

# --- hub chain ---
$hubChain = $null
if (-not $SkipHubChain) {
    & (Join-Path $PSScriptRoot "Run-HybridHubChainSmoke.ps1") -RepoRoot $RepoRoot | Out-Host
    $hubChain = Read-JsonFile (Join-Path $debugDir "hybrid_hub_chain_smoke.json")
}

# --- cycle recovery ---
$cycle = $null
if (-not $SkipCycle) {
    & (Join-Path $PSScriptRoot "Run-HybridCycleRecovery.ps1") -RepoRoot $RepoRoot | Out-Host
    $cycle = Read-JsonFile (Join-Path $debugDir "hybrid_cycle_recovery.json")
}

# --- optional openclaw ---
$ocSmoke = $null
if ($RunOpenClawSmoke) {
    $ocScript = Join-Path $RepoRoot "scripts\Run-OpenClawAdapterSmoke.ps1"
    if (Test-Path $ocScript) {
        & $ocScript -RepoRoot $RepoRoot | Out-Host
        $ocSmoke = Read-JsonFile (Join-Path $debugDir "openclaw_adapter_smoke_last.json")
    }
}

$flags = Read-JsonFile $flagsPath
$baseline = Read-JsonFile (Join-Path $debugDir "a2ui_memory_baseline.json")
$s11 = Read-JsonFile (Join-Path $debugDir "s11hybrid_gate_diagnosis.json")
$refAhk = Read-JsonFile (Join-Path $debugDir "hybrid_signoff_reference_ahk.json")
$refHybrid = Read-JsonFile (Join-Path $debugDir "hybrid_signoff_reference_hybrid.json")

$hub = Get-Process -Name "nmer-hub" -ErrorAction SilentlyContinue | Select-Object -First 1
$wails = Get-Process -Name "nmer-wails" -ErrorAction SilentlyContinue | Select-Object -First 1
$ahk = Get-Process -Name "AutoHotkey64","AutoHotkey32" -ErrorAction SilentlyContinue | Where-Object {
    try {
        $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
        return ($cmd -like "*$RepoRoot*" -or $cmd -like "*牛马.ahk*")
    } catch { return $false }
} | Select-Object -First 1

$ftbHost = ""
$sidecarHost = ""
$legacyLifecycle = $true
if ($flags -and $flags.wailsBridge) {
    $ftbHost = [string]$flags.wailsBridge.floatingToolbarHost
    $sidecarHost = [string]$flags.wailsBridge.sidecarHost
}
if ($flags -and $flags.rollback) {
    $legacyLifecycle = [bool]$flags.rollback.legacySurfaceLifecycle
}

$health = $null
$ftbStatus = $null
try { $health = Invoke-RestMethod "http://127.0.0.1:18791/agent/health" -TimeoutSec 4 } catch {}
try {
    $ftbRaw = Invoke-RestMethod "http://127.0.0.1:18791/shell/ftb/status" -TimeoutSec 4
    if ($ftbRaw.status) { $ftbStatus = $ftbRaw.status } else { $ftbStatus = $ftbRaw }
} catch {}

$hubPrivate = $null
if ($hub) { $hub.Refresh(); $hubPrivate = [math]::Round($hub.PrivateMemorySize64 / 1MB, 2) }

$gates = @()

# G1 flags
$flagsPass = ($ftbHost -eq "hybrid") -and ($sidecarHost -ne "wails")
$gates += [ordered]@{
    id = "flags"
    title = "Flags config"
    pass = $flagsPass
    metrics = @{
        floatingToolbarHost = $ftbHost
        sidecarHost = $sidecarHost
        legacySurfaceLifecycle = $legacyLifecycle
    }
    errors = @(
        if ($ftbHost -ne "hybrid") { "floatingToolbarHost=$ftbHost want hybrid" }
        if ($sidecarHost -eq "wails") { "sidecarHost=wails want hub" }
    ) | Where-Object { $_ }
}

# G2 sidecar
$sidecarPass = [bool]$hub -and -not $wails -and $health -and (($health.ok -eq $true) -or ($health.status -eq "ok"))
$gates += [ordered]@{
    id = "sidecar"
    title = "Sidecar hub"
    pass = $sidecarPass
    metrics = @{
        nmer_hub = if ($hub) { $hub.Id } else { $null }
        nmer_wails = if ($wails) { $wails.Id } else { $null }
        hubPrivateMiB = $hubPrivate
        health_ok = if ($health) { $health.ok } else { $false }
        provider = if ($health) { $health.provider } else { "" }
    }
}

# G3 S11 static
$s11Pass = $s11 -and ($s11.s11_hybrid_gate_pass -eq $true)
$gates += [ordered]@{
    id = "s11_static"
    title = "S11 static wiring"
    pass = $s11Pass
    metrics = @{
        capturedAt = if ($s11) { $s11.capturedAt } else { "" }
        failureReasons = if ($s11) { @($s11.failureReasons) } else { @() }
    }
}

# G4 hub chain
$chainPass = $hubChain -and ($hubChain.overallPass -eq $true)
$gates += [ordered]@{
    id = "hub_chain"
    title = "Hub chain smoke"
    pass = $chainPass
    metrics = @{
        overallPass = if ($hubChain) { $hubChain.overallPass } else { $false }
    }
    gates = if ($hubChain) { @($hubChain.gates) } else { @() }
}

# G5 ftb external status
$extPass = $false
$presMode = ""
if ($ftbStatus) {
    $presMode = [string]$ftbStatus.presentationMode
    $extPass = ($presMode -eq "external")
}
$gates += [ordered]@{
    id = "ftb_external"
    title = "FTB external presentation"
    pass = $extPass
    metrics = @{
        presentationMode = $presMode
        visible = if ($ftbStatus) { $ftbStatus.visible } else { $null }
        ready = if ($ftbStatus) { $ftbStatus.ready } else { $null }
        entry = if ($ftbStatus) { $ftbStatus.entry } else { ""
        }
    }
    errors = @(
        if (-not $extPass) { "presentationMode=$presMode want external (reload ahk and show FTB)" }
    )
}

# G6 memory delta (reference contract: ahk ref only; no hybrid ref fallback)
$totalPrivate = $null
$wv2Count = $null
if ($baseline -and $baseline.processes) {
    $totalPrivate = [double]$baseline.processes.totalPrivateMiB
    $wv2Count = [int]$baseline.processes.webview2_count
}
$deltaMiB = $null
$deltaPass = $null
$deltaVerdict = $null
$deltaDeferred = $false
$deltaWarnings = @()
$sampling = Test-HybridMemoryDeltaSamplingReady -Flags $flags -Ahk $ahk -Hub $hub -Wails $wails `
    -FtbStatus $ftbStatus -Baseline $baseline -RefAhk $refAhk
if ($sampling.warnings) { $deltaWarnings = @($sampling.warnings) }

if ($sampling.deferred) {
    $deltaDeferred = $true
    $deltaPass = $null
} elseif ($refAhk -and ($null -ne $totalPrivate)) {
    $deltaMiB = [math]::Round([double]$totalPrivate - [double]$refAhk.totalPrivateMiB, 2)
    if ($deltaMiB -le 0) {
        $deltaPass = $true
        $deltaVerdict = "improvement"
    } elseif ($deltaMiB -le $memoryDeltaLimitMiB) {
        $deltaPass = $true
        $deltaVerdict = "within_limit"
    } else {
        $deltaPass = $false
        $deltaVerdict = "regression"
    }
}

$refAgeHours = Get-ReferenceAgeHours $refAhk
$gates += [ordered]@{
    id = "memory_delta"
    title = "Memory delta hybrid vs ahk ref"
    pass = $deltaPass
    deferred = $deltaDeferred
    metrics = @{
        comparisonBaseline = "ahk_ref"
        referenceKind = "ahk"
        referenceFile = "hybrid_signoff_reference_ahk.json"
        currentTotalPrivateMiB = $totalPrivate
        referenceAhkMiB = if ($refAhk) { $refAhk.totalPrivateMiB } else { $null }
        referenceHybridMiB = if ($refHybrid) { $refHybrid.totalPrivateMiB } else { $null }
        referenceHybridNote = "display only; not used for memory_delta"
        deltaMiB = $deltaMiB
        deltaVerdict = if ($deltaVerdict) { $deltaVerdict } else { $null }
        isImprovement = ($deltaVerdict -eq "improvement")
        deltaLimitMiB = $memoryDeltaLimitMiB
        webview2_count = $wv2Count
        hasReference = [bool]$refAhk
        referenceAgeHours = $refAgeHours
        searchCorePhase = $sampling.searchCorePhase
        searchCorePrivateMiB = $sampling.searchCorePrivateMiB
        searchCoreActive = $sampling.searchCoreActive
        samplingReady = $sampling.ready
        samplingReasons = @($sampling.reasons)
        warnings = @($deltaWarnings)
    }
    errors = @(
        if ($deltaDeferred) {
            if ($sampling.reasons.Count -gt 0) { "deferred: " + ($sampling.reasons -join "; ") }
            elseif ($sampling.searchCoreActive) { "deferred: searchcore_active phase=$($sampling.searchCorePhase)" }
            else { "deferred: sampling not ready" }
        }
        elseif (-not $refAhk) { "missing hybrid_signoff_reference_ahk.json; run Capture-HybridMemoryReference.ps1 -Mode ahk" }
        elseif ($deltaPass -eq $false) { "regression delta=${deltaMiB}MiB exceeds limit ${memoryDeltaLimitMiB}MiB" }
    ) | Where-Object { $_ }
}

# G7 hub cycle
$cyclePass = if ($cycle) { [bool]$cycle.pass } else { $null }
$gates += [ordered]@{
    id = "hub_cycle"
    title = "Hub inject cycle stability"
    pass = $cyclePass
    metrics = @{
        rounds = if ($cycle) { $cycle.rounds } else { 0 }
        hubStartMiB = if ($cycle) { $cycle.hubStartMiB } else { $null }
        hubPeakMiB = if ($cycle) { $cycle.hubPeakMiB } else { $null }
        hubEndMiB = if ($cycle) { $cycle.hubEndMiB } else { $null }
        recoveryPct = if ($cycle) { $cycle.recoveryPct } else { $null }
    }
}

# G8 openclaw optional
$ocPass = $null
if ($RunOpenClawSmoke) {
    $ocPass = $ocSmoke -and ($ocSmoke.ok -eq $true)
    $gates += [ordered]@{
        id = "openclaw_adapter"
        title = "OpenClaw Adapter optional"
        pass = $ocPass
        metrics = @{
            ok = if ($ocSmoke) { $ocSmoke.ok } else { $false }
            code = if ($ocSmoke) { $ocSmoke.code } else { "skipped" }
        }
    }
}

$autoGates = @($gates | Where-Object { $_.pass -ne $null })
$autoPass = ($autoGates.Count -gt 0) -and -not ($autoGates | Where-Object { $_.pass -eq $false })

$manualAuto = $null
$manualAutoPath = Join-Path $debugDir "hybrid_manual_signoff.json"
if (Test-Path $manualAutoPath) {
    try { $manualAuto = Get-Content $manualAutoPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}
function Get-ManualAutoPass($obj, [string]$stepId) {
    if (-not $obj -or -not $obj.steps) { return $null }
    foreach ($s in @($obj.steps)) {
        if ([string]$s.id -eq $stepId) {
            if ($null -eq $s.pass) { return $null }
            return [bool]$s.pass
        }
    }
    return $null
}

function Get-SignoffCases($obj) {
    if (-not $obj) { return @() }
    if ($obj.manualSignoff -and $obj.manualSignoff.signoffCases) {
        return @($obj.manualSignoff.signoffCases)
    }
    if ($obj.signoffCases) { return @($obj.signoffCases) }
    return @()
}

function Get-Ui01Case($cases) {
    foreach ($c in @($cases)) {
        if ([string]$c.caseId -eq "UI-01") { return $c }
    }
    return $null
}

function Get-CasePass([string]$caseId, $cases) {
    foreach ($c in @($cases)) {
        if ([string]$c.caseId -eq $caseId) {
            if ($null -eq $c.pass) { return $null }
            return [bool]$c.pass
        }
    }
    return $null
}

function Get-CaseStatus([string]$caseId, $cases) {
    foreach ($c in @($cases)) {
        if ([string]$c.caseId -eq $caseId) {
            if ($c.status) { return [string]$c.status }
            if ($null -eq $c.pass) { return "unsigned" }
            if ($c.pass) { return "signed" } else { return "failed" }
        }
    }
    return "unsigned"
}

$signoffCases = Get-SignoffCases $manualAuto
$ui01Case = Get-Ui01Case $signoffCases
$ui01Actual = if ($ui01Case -and $ui01Case.actual) { $ui01Case.actual } else { $null }
$manualSignoffMode = if ($manualAuto -and $manualAuto.signoffMode) { [string]$manualAuto.signoffMode } elseif ($ui01Actual -and $ui01Actual.signoffMode) { [string]$ui01Actual.signoffMode } else { "warm-session" }

$ui01Recovery = $null
if ($manualAuto -and $manualAuto.ui01Recovery) {
    $ui01Recovery = $manualAuto.ui01Recovery
} elseif ($ui01Actual) {
    $ui01Recovery = [ordered]@{
        functionalPass        = $ui01Actual.functionalPass
        sessionDriftPct       = $ui01Actual.sessionDriftPct
        refDriftPct           = $ui01Actual.refDriftPct
        sessionRecoveryPass   = $ui01Actual.sessionRecoveryPass
        referenceBaselinePass = $ui01Actual.referenceBaselinePass
        signoffMode           = $ui01Actual.signoffMode
        warnings              = if ($ui01Actual.warnings) { @($ui01Actual.warnings) } elseif ($ui01Case -and $ui01Case.warnings) { @($ui01Case.warnings) } else { @() }
        pass                  = if ($null -ne $ui01Case.pass) { [bool]$ui01Case.pass } else { $null }
        memBeforeMiB          = $ui01Actual.memBeforeMiB
        memAfterMiB           = $ui01Actual.memAfterMiB
        hybridReferenceMiB    = $ui01Actual.hybridReferenceMiB
        referenceKind         = $ui01Actual.referenceKind
        referenceFile         = $ui01Actual.referenceFile
        referenceCapturedAt   = $ui01Actual.referenceCapturedAt
        searchCorePhase       = $ui01Actual.searchCorePhase
        coldStartConfirmed    = $ui01Actual.coldStartConfirmed
    }
}

$ftbCasePass = Get-CasePass "FTB-01" $signoffCases
$cpCasePass = Get-CasePass "CP-01" $signoffCases
$uiCasePass = Get-CasePass "UI-01" $signoffCases

$ftbUxPass = Get-ManualAutoPass $manualAuto "ftb_ux"
$cpHelloPass = Get-ManualAutoPass $manualAuto "cp_hello"
$uiCyclePass = Get-ManualAutoPass $manualAuto "ui_cycle_10"

$manualSteps = @(
    [ordered]@{
        id = "reload_ahk"
        title = "Reload niuma.ahk hybrid flags"
        autoCheck = $true
        pass = [bool]$ahk
        hint = "Ctrl+Shift+Q; confirm floatingToolbarHost=hybrid, sidecarHost=hub"
    },
    [ordered]@{
        id = "ftb_ux"
        title = "FTB manual UX (FTB-01)"
        caseId = "FTB-01"
        autoCheck = ($null -ne $ftbCasePass) -or ($null -ne $ftbUxPass)
        pass = if ($null -ne $ftbCasePass) { $ftbCasePass } elseif ($null -ne $ftbUxPass) { $ftbUxPass } else { $false }
        signoffStatus = Get-CaseStatus "FTB-01" $signoffCases
        hint = "Run-HybridManualSignoff.ps1 or Run-HybridFtbUxSmoke.ps1 (inject proxy)"
    },
    [ordered]@{
        id = "cp_hello"
        title = "CP Agent hello (CP-01)"
        caseId = "CP-01"
        autoCheck = ($null -ne $cpCasePass) -or ($null -ne $cpHelloPass)
        pass = if ($null -ne $cpCasePass) { $cpCasePass } elseif ($null -ne $cpHelloPass) { $cpHelloPass } else { $false }
        signoffStatus = Get-CaseStatus "CP-01" $signoffCases
        hint = "Run-HybridManualSignoff.ps1 agent_hello IPC; no deliver_ready_timeout"
    },
    [ordered]@{
        id = "ui_cycle_10"
        title = "10-round UI recovery (UI-01)"
        caseId = "UI-01"
        autoCheck = ($null -ne $uiCasePass) -or ($null -ne $uiCyclePass)
        pass = if ($null -ne $uiCasePass) { $uiCasePass } elseif ($null -ne $uiCyclePass) { $uiCyclePass } else { $false }
        signoffStatus = Get-CaseStatus "UI-01" $signoffCases
        hint = "UI-01: sessionDrift primary; refDrift auxiliary (see ui01Recovery panel)"
    }
)

$productPass = if ($manualAuto -and ($null -ne $manualAuto.productPass)) {
    [bool]$manualAuto.productPass
} else {
    $checks = @()
    if ($null -ne $ftbCasePass) { $checks += $ftbCasePass } elseif ($null -ne $ftbUxPass) { $checks += $ftbUxPass }
    if ($null -ne $cpCasePass) { $checks += $cpCasePass } elseif ($null -ne $cpHelloPass) { $checks += $cpHelloPass }
    if ($null -ne $uiCasePass) { $checks += $uiCasePass } elseif ($null -ne $uiCyclePass) { $checks += $uiCyclePass }
    ($checks.Count -gt 0) -and (@($checks | Where-Object { $_ -ne $true }).Count -eq 0)
}
$manualPass = $productPass
$overallPass = $autoPass -and $productPass

$dashboardWarnings = @()
if ($manualAuto -and $manualAuto.warnings) {
    $dashboardWarnings += @($manualAuto.warnings)
}
if ($ui01Recovery -and $ui01Recovery.warnings) {
    foreach ($w in @($ui01Recovery.warnings)) {
        if ($dashboardWarnings -notcontains $w) { $dashboardWarnings += $w }
    }
}

$dashboard = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    signoffMode = $SignoffMode
    manualSignoffMode = $manualSignoffMode
    repoRoot = $RepoRoot
    readyForHybridSignoff = $autoPass
    overallPass = $overallPass
    autoPass = $autoPass
    manualPass = $manualPass
    productPass = $productPass
    memoryDeltaLimitMiB = $memoryDeltaLimitMiB
    warnings = @($dashboardWarnings)
    ui01Recovery = $ui01Recovery
    pipeline = @(
        @{ step = "AHK FTB"; role = "presentation"; endpoint = "g_FTB_WV2" }
        @{ step = "nmer-hub"; role = "agent+inject"; endpoint = ":18791" }
        @{ step = "inject/drain"; role = "transport"; endpoint = "/shell/ftb/inject" }
        @{ step = "CP/Agent"; role = "client"; endpoint = "paletteAgent.transport" }
        @{ step = "OpenClaw"; role = "backend"; endpoint = "/a2ui/openclaw/action" }
    )
    gates = $gates
    manualSteps = $manualSteps
    processes = @{
        nmer_hub = if ($hub) { @{ id = $hub.Id } } else { $null }
        nmer_wails = if ($wails) { @{ id = $wails.Id } } else { $null }
        ahk = if ($ahk) { @{ id = $ahk.Id } } else { $null }
    }
    references = @{
        ahk = if ($refAhk) { @{ capturedAt = $refAhk.capturedAt; totalPrivateMiB = $refAhk.totalPrivateMiB } } else { $null }
        hybrid = if ($refHybrid) { @{ capturedAt = $refHybrid.capturedAt; totalPrivateMiB = $refHybrid.totalPrivateMiB } } else { $null }
    }
    commands = @{
        openDashboard = ".\tools\a2ui-diagnostics\Open-HybridSignoffDashboard.ps1"
        manualSignoff = ".\tools\a2ui-diagnostics\Run-HybridManualSignoff.ps1 -RefreshDashboard"
        captureAhkRef = ".\tools\a2ui-diagnostics\Capture-HybridMemoryReference.ps1 -Mode ahk"
        captureHybridRef = ".\tools\a2ui-diagnostics\Capture-HybridMemoryReference.ps1 -Mode hybrid"
        hubChainOnly = ".\tools\a2ui-diagnostics\Run-HybridHubChainSmoke.ps1"
        fullCollect = ".\tools\a2ui-diagnostics\Collect-HybridSignoffDashboard.ps1 -RunOpenClawSmoke"
    }
    manualSignoff = if ($manualAuto -or ($signoffCases.Count -gt 0)) {
        @{
            capturedAt = if ($manualAuto) { [string]$manualAuto.capturedAt } else { $null }
            productPass = $productPass
            manualPass = $manualPass
            overallPass = if ($manualAuto -and ($null -ne $manualAuto.overallPass)) { [bool]$manualAuto.overallPass } else { $null }
            signoffMode = $manualSignoffMode
            signoffCases = @($signoffCases)
            ui01Recovery = $ui01Recovery
            warnings = if ($manualAuto -and $manualAuto.warnings) { @($manualAuto.warnings) } else { @() }
            steps = if ($manualAuto -and $manualAuto.steps) { @($manualAuto.steps) } else { @() }
        }
    } else { $null }
    signoffCases = @($signoffCases)
    notes = @(
        "Browser F5 does not refresh data; rerun Open-HybridSignoffDashboard.ps1",
        "memory_delta: hybrid_signoff_reference_ahk.json only; UI-01 refDrift: hybrid_signoff_reference_hybrid.json only",
        "B0: Test-HybridReferenceContract.ps1; B1 post-signoff: Capture-HybridMemoryReference ahk then hybrid",
        "UI-01 primary: sessionDriftPct <= 10%; refDrift auxiliary except formal-cold",
        "overallPass = autoPass AND productPass (FTB-01 + CP-01 + UI-01 sessionRecovery)",
        "signoffMode on dashboard is auto-gate context; manualSignoffMode is UI-01 policy"
    )
}

$dashboard | ConvertTo-Json -Depth 10 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "hybrid_signoff_dashboard -> $outPath readyForHybridSignoff=$autoPass"
if (-not $autoPass) { exit 1 }
exit 0
