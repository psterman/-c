# Automate 3 hybrid manual signoff steps -> Cache/debug/hybrid_manual_signoff.json
param(
    [string]$RepoRoot = "",
    [int]$UiRounds = 10,
    [int]$IdleSec = 15,
    [int]$UiScWaitSec = 60,
    [int]$UiPostCycleIdleSec = 30,
    [int]$UiSampleRetryMax = 2,
    [int]$UiSessionBaselineSec = 5,
    [double]$MemoryRecoveryPct = 10,
    [ValidateSet("warm-session", "formal-cold", "relaxed", "live")]
    [string]$SignoffMode = "warm-session",
    [switch]$SkipFtbUx,
    [switch]$SkipCpHello,
    [switch]$SkipUiCycle,
    [switch]$RefreshDashboard,
    [switch]$CpHelloInjectFallback = $true,
    [switch]$SkipInjectUiCycle
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
$outPath = Join-Path $debugDir "hybrid_manual_signoff.json"
$mainBaseline = Join-Path $debugDir "a2ui_memory_baseline.json"
$baselineBackup = Join-Path $debugDir "hybrid_signoff_baseline_backup.json"
$lastPidPath = Join-Path $debugDir "hybrid_ui01_last_ahk_pid.json"

function Read-Json([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    try { return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

function Rel-Artifact([string]$path) {
    if (-not $path) { return $null }
    if ($path -like "$RepoRoot*") {
        return $path.Substring($RepoRoot.Length).TrimStart('\', '/')
    }
    return $path
}

function Stop-SearchCoreForUi01Sample {
    param(
        [int]$IdleSec = 15,
        [int]$ScWaitSec = 60,
        [switch]$ForceKillSearchCore
    )
    Wait-DiagSearchCoreStopped -MaxWaitSec $ScWaitSec -ForceKillProcess:$ForceKillSearchCore | Out-Null
    if ($IdleSec -gt 0) { Start-Sleep -Seconds $IdleSec }
}

function Capture-Ui01MemorySample {
    param(
        [string]$OutPath,
        [int]$ScWaitSec = 60,
        [int]$IdleSec = 15,
        [switch]$ForceKillSearchCore,
        [int]$RetryMax = 2
    )
    $lastWait = $null
    for ($attempt = 1; $attempt -le $RetryMax; $attempt++) {
        if ($attempt -gt 1) {
            Write-Host "  ui01 memory sample retry $attempt/$RetryMax..." -ForegroundColor Yellow
            $ForceKillSearchCore = $true
            Start-Sleep -Seconds 10
        }
        Stop-SearchCoreForUi01Sample -IdleSec $IdleSec -ScWaitSec $ScWaitSec -ForceKillSearchCore:$ForceKillSearchCore
        & (Join-DiagScript -RelativePath "memory/capture-memory-baseline.ps1") -RepoRoot $RepoRoot -OutPath $OutPath | Out-Null
        $bl = Read-Json $OutPath
        if (Test-DiagUi01MemorySampleReady -Baseline $bl) {
            return @{ baseline = $bl; attempt = $attempt; ready = $true }
        }
        $scMiB = if ($bl -and $bl.processes) { $bl.processes.searchCorePrivateMiB } else { "?" }
        Write-Host "  ui01 sample not ready (searchCorePrivateMiB=$scMiB; need SC stopped)" -ForegroundColor Yellow
    }
    return @{ baseline = (Read-Json $OutPath); attempt = $RetryMax; ready = $false }
}

function New-SignoffCase {
    param(
        [string]$CaseId,
        [string]$Title,
        [string[]]$Steps,
        [string]$Expected,
        $Actual,
        [string[]]$Trace,
        $Pass,
        [string[]]$Artifacts,
        [string[]]$Warnings = @()
    )
    $status = if ($null -eq $Pass) { "skipped" } elseif ($Pass) { "signed" } else { "failed" }
    return [ordered]@{
        caseId    = $CaseId
        title     = $Title
        steps     = @($Steps)
        expected  = $Expected
        actual    = $Actual
        trace     = @($Trace)
        pass      = $Pass
        status    = $status
        warnings  = @($Warnings | Where-Object { $_ })
        artifacts = @($Artifacts | Where-Object { $_ })
    }
}

function Get-Ui01MemoryMetrics {
    param(
        [double]$MemBefore,
        [double]$MemAfter,
        [double]$UiMemBefore,
        [double]$UiMemAfter,
        [double]$HybridReferenceMiB,
        [double]$HybridReferenceUiMiB,
        [string]$HybridReferenceCapturedAt,
        [bool]$HasHybridReference,
        [double]$RecoveryPct,
        [string]$Mode,
        [int]$CurrentPid,
        [int]$LastPid,
        [string]$SearchCorePhase = ""
    )
    $sessionDeltaMiB = $null
    $sessionDriftPct = $null
    $uiSessionDeltaMiB = $null
    $uiSessionDriftPct = $null
    $refDeltaMiB = $null
    $refDriftPct = $null
    $uiRefDeltaMiB = $null
    $uiRefDriftPct = $null
    $useUiSession = ($UiMemBefore -gt 0) -and ($null -ne $UiMemAfter)
    if ($MemBefore -gt 0 -and ($null -ne $MemAfter)) {
        $sessionDeltaMiB = [math]::Round($MemAfter - $MemBefore, 2)
        $sessionDriftPct = [math]::Round(($sessionDeltaMiB / $MemBefore) * 100, 2)
    }
    if ($useUiSession) {
        $uiSessionDeltaMiB = [math]::Round($UiMemAfter - $UiMemBefore, 2)
        $uiSessionDriftPct = [math]::Round(($uiSessionDeltaMiB / $UiMemBefore) * 100, 2)
    }
    if ($HasHybridReference -and $HybridReferenceMiB -gt 0 -and ($null -ne $MemAfter)) {
        $refDeltaMiB = [math]::Round($MemAfter - $HybridReferenceMiB, 2)
        $refDriftPct = [math]::Round(($refDeltaMiB / $HybridReferenceMiB) * 100, 2)
    }
    if ($HasHybridReference -and $HybridReferenceUiMiB -gt 0 -and ($null -ne $UiMemAfter)) {
        $uiRefDeltaMiB = [math]::Round($UiMemAfter - $HybridReferenceUiMiB, 2)
        $uiRefDriftPct = [math]::Round(($uiRefDeltaMiB / $HybridReferenceUiMiB) * 100, 2)
    }
    $primarySessionDriftPct = if ($useUiSession) { $uiSessionDriftPct } else { $sessionDriftPct }
    $sessionRecoveryPass = $false
    if ($Mode -in @("warm-session", "live", "relaxed") -and -not $useUiSession) {
        $warnings += "session_baseline_missing: signoff_start_warm uiPrivate baseline required for UI-01"
    } elseif ($null -ne $primarySessionDriftPct) {
        if ($Mode -in @("warm-session", "live", "relaxed")) {
            $sessionRecoveryPass = ($primarySessionDriftPct -le $RecoveryPct)
            if ($useUiSession -and $null -ne $uiSessionDeltaMiB -and ($uiSessionDeltaMiB -gt 80)) {
                $sessionRecoveryPass = $false
            }
        } else {
            $sessionRecoveryPass = ([math]::Abs($primarySessionDriftPct) -le $RecoveryPct)
        }
    }
    $referenceBaselinePass = $null
    $primaryRefDriftPct = if ($null -ne $uiRefDriftPct) { $uiRefDriftPct } else { $refDriftPct }
    if ($null -ne $primaryRefDriftPct) {
        $referenceBaselinePass = ([math]::Abs($primaryRefDriftPct) -le $RecoveryPct)
    }
    $coldStartConfirmed = $null
    $warnings = @()
    if (-not $HasHybridReference) {
        $warnings += "missing_hybrid_reference: run Capture-HybridMemoryReference.ps1 -Mode hybrid (no ahk fallback)"
    }
    if ($useUiSession -and ($null -ne $uiSessionDeltaMiB) -and ($uiSessionDeltaMiB -gt 80) -and ($Mode -in @("warm-session", "live", "relaxed"))) {
        $warnings += "uiPrivate sessionDelta ${uiSessionDeltaMiB} MiB exceeds 80 MiB warm-session cap"
    }
    if ($useUiSession -and ($null -ne $uiSessionDriftPct) -and ($uiSessionDriftPct -gt $RecoveryPct) -and ($Mode -in @("warm-session", "live", "relaxed"))) {
        $warnings += "uiPrivate sessionDrift ${uiSessionDriftPct}% exceeds ${RecoveryPct}% (baseline=signoff_start_warm)"
    } elseif ($null -ne $sessionDriftPct -and ([math]::Abs($sessionDriftPct) -gt $RecoveryPct) -and ($Mode -in @("warm-session", "live", "relaxed"))) {
        $warnings += "totalPrivate sessionDrift ${sessionDriftPct}% exceeds ${RecoveryPct}% (no uiPrivate baseline; SC noise possible)"
    }
    if ($Mode -eq "formal-cold") {
        $coldStartConfirmed = ($LastPid -gt 0) -and ($CurrentPid -ne $LastPid)
        if (-not $coldStartConfirmed) {
            $warnings += "formal-cold: pid unchanged (current=$CurrentPid last=$LastPid); Ctrl+Shift+Q is not cold start - restart niuma process"
            $referenceBaselinePass = $false
        } elseif (-not $HasHybridReference) {
            $referenceBaselinePass = $false
        }
    } elseif ($Mode -in @("warm-session", "live", "relaxed")) {
        if ($null -ne $primaryRefDriftPct -and ([math]::Abs($primaryRefDriftPct) -gt $RecoveryPct)) {
            $warnings += "refDrift ${primaryRefDriftPct}% exceeds ${RecoveryPct}% (auxiliary; $Mode does not block on ref)"
        }
    }
    return @{
        memBeforeMiB           = $MemBefore
        memAfterMiB            = $MemAfter
        uiMemBeforeMiB         = if ($useUiSession) { $UiMemBefore } else { $null }
        uiMemAfterMiB          = if ($useUiSession) { $UiMemAfter } else { $null }
        primarySessionField    = if ($useUiSession) { "uiPrivateMiB" } else { "totalPrivateMiB" }
        sessionBaselineKind  = "signoff_start_warm"
        hybridReferenceMiB     = if ($HasHybridReference -and $HybridReferenceMiB -gt 0) { $HybridReferenceMiB } else { $null }
        hybridReferenceUiMiB   = if ($HasHybridReference -and $HybridReferenceUiMiB -gt 0) { $HybridReferenceUiMiB } else { $null }
        referenceKind          = if ($HasHybridReference) { "hybrid" } else { $null }
        referenceFile          = if ($HasHybridReference) { "hybrid_signoff_reference_hybrid.json" } else { $null }
        referenceCapturedAt    = if ($HasHybridReference) { $HybridReferenceCapturedAt } else { $null }
        sessionDeltaMiB        = $sessionDeltaMiB
        sessionDriftPct        = if ($useUiSession) { $uiSessionDriftPct } else { $sessionDriftPct }
        totalSessionDriftPct   = $sessionDriftPct
        uiSessionDeltaMiB      = $uiSessionDeltaMiB
        uiSessionDriftPct      = $uiSessionDriftPct
        refDeltaMiB            = $refDeltaMiB
        refDriftPct            = if ($null -ne $uiRefDriftPct) { $uiRefDriftPct } else { $refDriftPct }
        totalRefDriftPct       = $refDriftPct
        uiRefDriftPct          = $uiRefDriftPct
        sessionRecoveryPass    = $sessionRecoveryPass
        referenceBaselinePass  = $referenceBaselinePass
        coldStartConfirmed     = $coldStartConfirmed
        signoffMode            = $Mode
        searchCorePhase        = $SearchCorePhase
        warnings               = $warnings
    }
}

function Test-Ui01Pass {
    param(
        [bool]$FunctionalPass,
        $Metrics
    )
    if (-not $FunctionalPass) { return $false }
    if (-not $Metrics.sessionRecoveryPass) { return $false }
    if ($Metrics.signoffMode -eq "formal-cold") {
        if ($Metrics.coldStartConfirmed -ne $true) { return $false }
        if ($Metrics.referenceBaselinePass -eq $false) { return $false }
    }
    return $true
}

function Gates-ToActual($gatesObj) {
    $out = @{}
    if (-not $gatesObj) { return $out }
    foreach ($g in @($gatesObj)) {
        $out[[string]$g.id] = @{
            pass   = [bool]$g.pass
            detail = [string]$g.detail
        }
    }
    return $out
}

$ahk = Get-Process -Name "AutoHotkey64","AutoHotkey32" -ErrorAction SilentlyContinue | Where-Object {
    try {
        $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
        return ($cmd -like "*$RepoRoot*" -or $cmd -like "*牛马.ahk*")
    } catch { return $false }
} | Select-Object -First 1
if (-not $ahk) {
    Write-Host "FAIL: niuma.ahk not running. Reload hybrid flags first." -ForegroundColor Red
    exit 1
}

$steps = @()
$signoffCases = @()
$ui01Warnings = @()
$ui01Recovery = $null
$uiTrace = @()

$lastPidRec = Read-Json $lastPidPath
$lastAhkPid = if ($lastPidRec -and $lastPidRec.pid) { [int]$lastPidRec.pid } else { 0 }

# UI-01 session baseline: warm idle snapshot before FTB/CP smoke (not cold SC-kill)
$memBefore = $null
$memAfter = $null
$uiMemBeforeVal = $null
$preCycleBeforeMiB = $null
$preCycleUiBeforeMiB = $null
$ui01SessionBaselinePath = Join-Path $debugDir "hybrid_ui01_session_baseline.json"
if (-not $SkipUiCycle) {
    Write-Host "== UI-01 warm session baseline (pre-smoke, SC settled) ==" -ForegroundColor DarkGray
    $sessionCap = Capture-Ui01MemorySample -OutPath $ui01SessionBaselinePath -ScWaitSec $UiScWaitSec -IdleSec $UiPostCycleIdleSec -RetryMax $UiSampleRetryMax
    $blSession = $sessionCap.baseline
    if (-not $sessionCap.ready) {
        $ui01Warnings += "session_baseline_searchcore_active: SearchCore still attributed; UI-01 may be flaky"
        $uiTrace += "session_baseline_ready=false"
    }
    if ($blSession -and $blSession.processes) {
        $memBefore = [double]$blSession.processes.totalPrivateMiB
        $uiMemBeforeVal = Get-MemoryBaselineUiPrivate $blSession
        $scSnap0 = Get-SearchCoreSignoffSnapshot
        Write-Host ("  sessionBaseline uiPrivate={0} MiB total={1} MiB scPhase={2}" -f $uiMemBeforeVal, $memBefore, $scSnap0.searchCore.scanPhase) -ForegroundColor DarkGray
    } else {
        Write-Host "  WARN: session baseline capture failed; UI-01 will fail without signoff_start_warm" -ForegroundColor Yellow
        $ui01Warnings += "session_baseline_missing: hybrid_ui01_session_baseline.json empty or unreadable"
    }
}

# --- 1) FTB UX (hub inject proxy) ---
$ftbPass = $null
$ftbDetail = "skipped"
$ftbJson = $null
$ftbArtifacts = @(
    (Rel-Artifact (Join-Path $debugDir "hybrid_ftb_ux_smoke.json"))
    (Rel-Artifact (Join-Path $debugDir "wails_bridge.log"))
    (Rel-Artifact (Join-Path $debugDir "hubcapsule_runtime.log"))
)
if (-not $SkipFtbUx) {
    Write-Host "== [1/3] FTB UX smoke ==" -ForegroundColor Cyan
    & (Join-Path $here "Run-HybridFtbUxSmoke.ps1") -RepoRoot $RepoRoot
    $ftbJson = Read-Json (Join-Path $debugDir "hybrid_ftb_ux_smoke.json")
    $ftbPass = [bool]$ftbJson.pass
    $ftbDetail = "hub inject + external status probeId=$($ftbJson.probeId)"
}
$ftbTrace = @()
if ($ftbJson -and $ftbJson.gates) {
    foreach ($g in @($ftbJson.gates)) {
        $mark = if ($g.pass) { "OK" } else { "FAIL" }
        $ftbTrace += "$mark $($g.id): $($g.detail)"
    }
}
$signoffCases += New-SignoffCase -CaseId "FTB-01" -Title "FTB UX smoke" -Steps @(
    "Verify FTB presentationMode=external",
    "Hub inject 5x inject/drain",
    "egress roundtrip",
    "Scan wails_bridge / hubcapsule logs for inject failures"
) -Expected "FTB external=true, inject_refresh=true, egress_roundtrip=true, no_inject_fail_log=true" `
    -Actual $(if ($ftbJson) { @{ pass = $ftbPass; probeId = $ftbJson.probeId; gates = (Gates-ToActual $ftbJson.gates) } } else { @{ skipped = $true } }) `
    -Trace $ftbTrace -Pass $ftbPass -Artifacts $ftbArtifacts
$steps += [ordered]@{
    id        = "ftb_ux"
    title     = "FTB manual UX"
    pass      = $ftbPass
    autoCheck = $true
    detail    = $ftbDetail
    hint      = "Automated: register_external + 5x inject/drain + egress + log scan"
}

# --- 2) CP Agent hello (file IPC -> CommandPalette_AgentSubmit) ---
$helloPass = $null
$helloDetail = "skipped"
$helloMode = "skipped"
$hinj = $null
$helloArtifacts = @(
    (Rel-Artifact (Join-Path $debugDir "hybrid_cp_hello_inject_smoke.json"))
    (Rel-Artifact (Join-Path $debugDir "cmdpal_agent_wire.log"))
    (Rel-Artifact (Join-Path $debugDir "command_palette_ai.log"))
    (Rel-Artifact (Join-Path $debugDir "hybrid_manual_probe_result.json"))
)
$helloTrace = @()
if (-not $SkipCpHello) {
    Write-Host "== [2/3] CP Agent hello ==" -ForegroundColor Cyan
    $helloPass = $false
    $helloDetail = ""
    if ($CpHelloInjectFallback) {
        $helloMode = "hub_inject_fallback"
        Write-Host "  mode: hub inject fallback (no file IPC)" -ForegroundColor DarkGray
        & (Join-Path $here "Run-HybridCpHelloInjectSmoke.ps1") -RepoRoot $RepoRoot
        $hinj = Read-Json (Join-Path $debugDir "hybrid_cp_hello_inject_smoke.json")
        $helloPass = [bool]$hinj.pass
        $helloDetail = "inject_fallback pass=$helloPass reqId=$($hinj.reqId)"
    } else {
        $helloMode = "file_ipc"
        Write-Host "  mode: file IPC (reload niuma once if this fails in 4s)" -ForegroundColor DarkGray
        try {
            $hello = & (Join-Path $here "Invoke-HybridManualProbe.ps1") -RepoRoot $RepoRoot -Action "agent_hello" -Query "hello" -TimeoutSec 55
            $helloPass = [bool]$hello.pass
            $helloDetail = [string]$hello.code
            if ($hello.cardId) { $helloDetail += " card=$($hello.cardId) req=$($hello.reqId)" }
            $helloTrace += "probe code=$($hello.code) reqId=$($hello.reqId)"
        } catch {
            Write-Host "  IPC failed: $($_.Exception.Message.Split([char]10)[0])" -ForegroundColor Yellow
            Write-Host "  retry with hub inject fallback..." -ForegroundColor Yellow
            $helloMode = "inject_fallback_after_ipc_fail"
            & (Join-Path $here "Run-HybridCpHelloInjectSmoke.ps1") -RepoRoot $RepoRoot
            $hinj = Read-Json (Join-Path $debugDir "hybrid_cp_hello_inject_smoke.json")
            $helloPass = [bool]$hinj.pass
            $helloDetail = "inject_fallback_after_ipc_fail pass=$helloPass"
        }
    }
    if ($hinj -and $hinj.gates) {
        foreach ($g in @($hinj.gates)) {
            $mark = if ($g.pass) { "OK" } else { "FAIL" }
            $helloTrace += "$mark $($g.id): $($g.detail)"
        }
    }
}
$signoffCases += New-SignoffCase -CaseId "CP-01" -Title "CP Agent hello" -Steps @(
    "打开 CommandPalette",
    "发送 Agent hello",
    "等待 Agent 回包 / 卡片生成",
    "确认无 deliver_ready_timeout"
) -Expected "CP 可收到 Agent hello 并生成卡片；inject 被 AHK 消费" `
    -Actual $(if ($hinj) { @{ mode = $helloMode; pass = $helloPass; reqId = $hinj.reqId; gates = (Gates-ToActual $hinj.gates) } } elseif ($helloMode -eq "file_ipc") { @{ mode = $helloMode; pass = $helloPass; detail = $helloDetail } } else { @{ skipped = $true } }) `
    -Trace $helloTrace -Pass $helloPass -Artifacts $helloArtifacts
$steps += [ordered]@{
    id        = "cp_hello"
    title     = "CP Agent hello"
    pass      = $helloPass
    autoCheck = $true
    detail    = $helloDetail
    hint      = "Automated: palette_agent_submit hello via hybrid_manual_probe.json IPC"
}

# --- 3) UI cycle 10 rounds + session/ref dual memory recovery ---
$cyclePass = $null
$cycleDetail = "skipped"
$functionalPass = $null
$uiMode = "skipped"
$uinj = $null
$uiArtifacts = @(
    (Rel-Artifact (Join-Path $debugDir "hybrid_ui_cycle_inject_smoke.json"))
    (Rel-Artifact (Join-Path $debugDir "hybrid_ui_cycle_keys_smoke.json"))
    (Rel-Artifact (Join-Path $debugDir "hybrid_ui01_session_baseline.json"))
    (Rel-Artifact (Join-Path $debugDir "hybrid_ui_cycle_mem_before.json"))
    (Rel-Artifact (Join-Path $debugDir "hybrid_ui_cycle_mem_after.json"))
    (Rel-Artifact (Join-Path $debugDir "surface_runtime.ndjson"))
)
if (-not $SkipUiCycle) {
    $uiTrace += "sessionBaselineMiB=$uiMemBeforeVal source=signoff_start_warm"
    Write-Host "== [3/3] UI cycle $UiRounds rounds ==" -ForegroundColor Cyan
    if (Test-Path $mainBaseline) {
        Copy-Item $mainBaseline $baselineBackup -Force
    }
    $uiMemBefore = Join-Path $debugDir "hybrid_ui_cycle_mem_before.json"
    $uiMemAfter = Join-Path $debugDir "hybrid_ui_cycle_mem_after.json"
    Write-Host "  pre-cycle diagnostic sample (SC stopped; not used for sessionDrift)..." -ForegroundColor DarkGray
    $beforeCap = Capture-Ui01MemorySample -OutPath $uiMemBefore -ScWaitSec $UiScWaitSec -IdleSec $IdleSec -RetryMax $UiSampleRetryMax
    $bl0 = $beforeCap.baseline
    if ($bl0 -and $bl0.processes) {
        $preCycleBeforeMiB = [double]$bl0.processes.totalPrivateMiB
        $preCycleUiBeforeMiB = Get-MemoryBaselineUiPrivate $bl0
        $uiTrace += "preCycleUiPrivateMiB=$preCycleUiBeforeMiB"
    }
    Write-Host "  preflight: ensure hybrid inject drain active..." -ForegroundColor DarkGray
    $drainReady = $false
    for ($drainAttempt = 1; $drainAttempt -le 4; $drainAttempt++) {
        try {
            & (Join-Path $here "Invoke-HybridInjectPing.ps1") -RepoRoot $RepoRoot -TimeoutSec 20 -MaxAttempts 1 | Out-Null
            $drainReady = $true
            $uiTrace += "inject_drain_preflight=ok attempt=$drainAttempt"
            break
        } catch {
            $uiTrace += "inject_drain_preflight_fail attempt=$drainAttempt"
            Write-Host "  inject drain not ready (attempt $drainAttempt/4): $(($_.Exception.Message -split "`n")[0])" -ForegroundColor Yellow
            Start-Sleep -Seconds (3 + $drainAttempt)
        }
    }
    if (-not $drainReady) {
        Write-Host "  WARN: inject drain preflight failed; ui_cycle may fall back to keys" -ForegroundColor Yellow
    }
    $uiOk = $false
    if (-not $SkipInjectUiCycle) {
        $uiMode = "hub_inject_ui_cycle"
        Write-Host "  mode: hub inject ui_cycle (reload niuma Ctrl+Shift+Q if ping preflight fails)" -ForegroundColor DarkGray
        try {
            & (Join-Path $here "Run-HybridUiCycleInjectSmoke.ps1") -RepoRoot $RepoRoot -Rounds $UiRounds
            $uinj = Read-Json (Join-Path $debugDir "hybrid_ui_cycle_inject_smoke.json")
            $uiOk = [bool]$uinj.pass
            $cycleDetail = "inject code=$($uinj.resultCode) cp=$($uinj.cpOpens) sc=$($uinj.scOpens)"
            $uiTrace += "inject resultCode=$($uinj.resultCode) cpOpens=$($uinj.cpOpens) scOpens=$($uinj.scOpens)"
        } catch {
            $cycleDetail = "inject_failed " + ($_.Exception.Message -split "`n")[0]
            Write-Host "  inject ui_cycle failed: $cycleDetail" -ForegroundColor Yellow
        }
    }
    if (-not $uiOk) {
        try {
            $ping = & (Join-Path $here "Invoke-HybridManualProbe.ps1") -RepoRoot $RepoRoot -Action "ping" -TimeoutSec 12
            if ($ping.pass) {
                $uiMode = "file_ipc_ui_cycle"
                $cycle = & (Join-Path $here "Invoke-HybridManualProbe.ps1") -RepoRoot $RepoRoot -Action "ui_cycle" -Rounds $UiRounds -TimeoutSec 180 -SkipHubWake
                $uiOk = [bool]$cycle.pass
                $cycleDetail = "file_ipc " + [string]$cycle.code
                $uiTrace += "file_ipc code=$($cycle.code)"
            }
        } catch {
            Write-Host "  file IPC skipped/failed: $(($_.Exception.Message -split "`n")[0])" -ForegroundColor DarkGray
        }
    }
    if (-not $uiOk) {
        $uiMode = "keys_fallback"
        Write-Host "  fallback: CapsLock hotkeys (keep hands off keyboard ~90s)..." -ForegroundColor Yellow
        try {
            & (Join-Path $here "Run-HybridUiCycleKeysSmoke.ps1") -RepoRoot $RepoRoot -Rounds $UiRounds
            $keys = Read-Json (Join-Path $debugDir "hybrid_ui_cycle_keys_smoke.json")
            $uiOk = [bool]$keys.pass
            $cycleDetail = "keys_fallback cp=$($keys.cpOpens) sc=$($keys.scOpens) pass=$($keys.pass)"
            $uiTrace += "keys cpOpens=$($keys.cpOpens) scOpens=$($keys.scOpens)"
            if (-not $uinj) { $uinj = $keys }
        } catch {
            $uiOk = $false
            $cycleDetail = "keys_fallback_failed " + ($_.Exception.Message -split "`n")[0]
        }
    }
    $hybridRefMiB = 0.0
    $hybridRefUiMiB = 0.0
    $hybridRefCapturedAt = $null
    $hasHybridRef = $false
    $hybridRefPath = Join-Path $debugDir "hybrid_signoff_reference_hybrid.json"
    $ref = Read-Json $hybridRefPath
    if ($ref -and $ref.totalPrivateMiB) {
        $hasHybridRef = $true
        $hybridRefMiB = [double]$ref.totalPrivateMiB
        $hybridRefUiMiB = Get-HybridReferenceUiPrivate $ref
        if (-not $hybridRefUiMiB -or $hybridRefUiMiB -le 0) {
            $hybridRefUiMiB = Get-MemoryBaselineUiPrivate $ref.baseline
        }
        $hybridRefCapturedAt = [string]$ref.capturedAt
    } else {
        $uiTrace += "missing_hybrid_reference path=$hybridRefPath"
    }
    $scSnapUi = Get-SearchCoreSignoffSnapshot
    $uiSearchCorePhase = [string]$scSnapUi.searchCore.scanPhase

    if ($uiOk) {
        Write-Host "  settling surfaces + stopping SearchCore before post-cycle memory sample..." -ForegroundColor DarkGray
        $afterCap = Capture-Ui01MemorySample -OutPath $uiMemAfter -ScWaitSec $UiScWaitSec -IdleSec $UiPostCycleIdleSec -RetryMax $UiSampleRetryMax
        $bl1 = $afterCap.baseline
        if (-not $afterCap.ready) {
            $ui01Warnings += "post_cycle_sample_searchcore_active: SearchCore still attributed after wait/retry"
            $uiTrace += "post_cycle_sample_ready=false attempt=$($afterCap.attempt)"
        }
        $uiMemAfterVal = $null
        if ($bl1 -and $bl1.processes) {
            $memAfter = [double]$bl1.processes.totalPrivateMiB
            $uiMemAfterVal = Get-MemoryBaselineUiPrivate $bl1
        }
    } else {
        $uiMemAfterVal = $null
    }

    $functionalPass = [bool]$uiOk
    $metrics = Get-Ui01MemoryMetrics -MemBefore $(if ($null -ne $memBefore) { $memBefore } else { 0 }) `
        -MemAfter $memAfter `
        -UiMemBefore $(if ($null -ne $uiMemBeforeVal) { $uiMemBeforeVal } else { 0 }) `
        -UiMemAfter $uiMemAfterVal `
        -HybridReferenceMiB $hybridRefMiB `
        -HybridReferenceUiMiB $(if ($hybridRefUiMiB) { $hybridRefUiMiB } else { 0 }) `
        -HybridReferenceCapturedAt $hybridRefCapturedAt -HasHybridReference $hasHybridRef `
        -RecoveryPct $MemoryRecoveryPct -Mode $SignoffMode -CurrentPid $ahk.Id -LastPid $lastAhkPid `
        -SearchCorePhase $uiSearchCorePhase

    if ($uiOk) {
        $uiTrace += "sessionDriftPct=$($metrics.sessionDriftPct) totalSessionDriftPct=$($metrics.totalSessionDriftPct) refDriftPct=$($metrics.refDriftPct) sessionPass=$($metrics.sessionRecoveryPass) refPass=$($metrics.referenceBaselinePass)"
        if ($metrics.coldStartConfirmed -eq $false) {
            $uiTrace += "coldStartConfirmed=false pid=$($ahk.Id) lastPid=$lastAhkPid"
        }
    } else {
        if (-not $cycleDetail) { $cycleDetail = "ui_cycle probe failed" }
        $metrics = Get-Ui01MemoryMetrics -MemBefore $(if ($null -ne $memBefore) { $memBefore } else { 0 }) `
            -MemAfter $memAfter `
            -UiMemBefore $(if ($null -ne $uiMemBeforeVal) { $uiMemBeforeVal } else { 0 }) `
            -UiMemAfter $uiMemAfterVal `
            -HybridReferenceMiB $hybridRefMiB `
            -HybridReferenceUiMiB $(if ($hybridRefUiMiB) { $hybridRefUiMiB } else { 0 }) `
            -HybridReferenceCapturedAt $hybridRefCapturedAt -HasHybridReference $hasHybridRef `
            -RecoveryPct $MemoryRecoveryPct -Mode $SignoffMode -CurrentPid $ahk.Id -LastPid $lastAhkPid `
            -SearchCorePhase $uiSearchCorePhase
        $metrics.functionalPass = $false
    }

    if ($uiOk -and $functionalPass -and ($metrics.sessionRecoveryPass -ne $true)) {
        Write-Host ("  sessionDrift {0}% > {1}%; extra settle + resample once..." -f $metrics.sessionDriftPct, $MemoryRecoveryPct) -ForegroundColor Yellow
        Start-Sleep -Seconds $UiPostCycleIdleSec
        $afterCap2 = Capture-Ui01MemorySample -OutPath $uiMemAfter -ScWaitSec $UiScWaitSec -IdleSec $UiPostCycleIdleSec -RetryMax $UiSampleRetryMax -ForceKillSearchCore
        $bl1 = $afterCap2.baseline
        if ($bl1 -and $bl1.processes) {
            $memAfter = [double]$bl1.processes.totalPrivateMiB
            $uiMemAfterVal = Get-MemoryBaselineUiPrivate $bl1
        }
        $metrics = Get-Ui01MemoryMetrics -MemBefore $(if ($null -ne $memBefore) { $memBefore } else { 0 }) `
            -MemAfter $memAfter `
            -UiMemBefore $(if ($null -ne $uiMemBeforeVal) { $uiMemBeforeVal } else { 0 }) `
            -UiMemAfter $uiMemAfterVal `
            -HybridReferenceMiB $hybridRefMiB `
            -HybridReferenceUiMiB $(if ($hybridRefUiMiB) { $hybridRefUiMiB } else { 0 }) `
            -HybridReferenceCapturedAt $hybridRefCapturedAt -HasHybridReference $hasHybridRef `
            -RecoveryPct $MemoryRecoveryPct -Mode $SignoffMode -CurrentPid $ahk.Id -LastPid $lastAhkPid `
            -SearchCorePhase $uiSearchCorePhase
        $uiTrace += "post_cycle_resample sessionDriftPct=$($metrics.sessionDriftPct) sessionPass=$($metrics.sessionRecoveryPass)"
    }

    $metrics.functionalPass = $functionalPass
    $ui01Recovery = $metrics
    if ($uiOk) {
        $ui01Warnings = @($metrics.warnings)
        $cycleDetail = "ui_ok sessionDrift=$($metrics.sessionDriftPct)% totalDrift=$($metrics.totalSessionDriftPct)% refDrift=$($metrics.refDriftPct)% field=$($metrics.primarySessionField) baseline=signoff_start_warm mode=$SignoffMode"
    }
    $cyclePass = Test-Ui01Pass -FunctionalPass $functionalPass -Metrics $metrics
    Write-Host "  recovering FTB toolbar after ui_cycle..." -ForegroundColor DarkGray
    try {
            $addr = $env:NMER_A2UI_BRIDGE_ADDR
            if (-not $addr) { $addr = "127.0.0.1:18791" }
            $base = "http://$addr"
            $recoverProbe = "recover-ftb-" + (Get-Date -Format "HHmmss")
            $resultPath = Join-Path $debugDir "hybrid_signoff_inject_result.json"
            if (Test-Path $resultPath) { Remove-Item $resultPath -Force -ErrorAction SilentlyContinue }
            $wake = @{ type = "hybrid_probe_wake"; probeId = "wake-$recoverProbe" } | ConvertTo-Json -Compress
            Invoke-RestMethod -Method Post -Uri "$base/shell/ftb/inject" -Body $wake -ContentType "application/json; charset=utf-8" -TimeoutSec 8 | Out-Null
            Start-Sleep -Milliseconds 400
            $ensure = @{ type = "hybrid_signoff_ensure_ftb"; probeId = $recoverProbe } | ConvertTo-Json -Compress
            Invoke-RestMethod -Method Post -Uri "$base/shell/ftb/inject" -Body $ensure -ContentType "application/json; charset=utf-8" -TimeoutSec 10 | Out-Null
            $deadline = (Get-Date).AddSeconds(15)
            while ((Get-Date) -lt $deadline) {
                if (Test-Path $resultPath) {
                    try {
                        $r = Get-Content $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
                        if ($r.probeId -eq $recoverProbe -and $r.code -match "FTB_ENSURE") { break }
                    } catch {}
                }
                Start-Sleep -Milliseconds 350
            }
            & (Join-Path $here "Invoke-HybridInjectPing.ps1") -RepoRoot $RepoRoot -TimeoutSec 12 | Out-Null
    } catch {
        Write-Host "  FTB recover skipped: $(($_.Exception.Message -split "`n")[0])" -ForegroundColor Yellow
    }
}
$steps += [ordered]@{
    id        = "ui_cycle_10"
    title     = "10-round UI recovery CP/FTB/SC"
    pass      = $cyclePass
    autoCheck = $true
    detail    = $cycleDetail
    hint      = ('UI-01: functionalPass + uiPrivate sessionDrift le {0} pct (primary); totalPrivate auxiliary when SC active' -f $MemoryRecoveryPct)
}

$ui01Actual = if ($SkipUiCycle) {
    @{ skipped = $true }
} else {
    [ordered]@{
        mode                   = $uiMode
        functionalPass         = $functionalPass
        pass                   = $cyclePass
        sessionBaselineKind    = $ui01Recovery.sessionBaselineKind
        memBeforeMiB           = $ui01Recovery.memBeforeMiB
        memAfterMiB            = $ui01Recovery.memAfterMiB
        uiMemBeforeMiB         = $ui01Recovery.uiMemBeforeMiB
        uiMemAfterMiB          = $ui01Recovery.uiMemAfterMiB
        preCycleBeforeMiB      = $preCycleBeforeMiB
        preCycleUiBeforeMiB    = $preCycleUiBeforeMiB
        primarySessionField    = $ui01Recovery.primarySessionField
        hybridReferenceMiB     = $ui01Recovery.hybridReferenceMiB
        hybridReferenceUiMiB   = $ui01Recovery.hybridReferenceUiMiB
        referenceKind          = $ui01Recovery.referenceKind
        referenceFile          = $ui01Recovery.referenceFile
        referenceCapturedAt    = $ui01Recovery.referenceCapturedAt
        searchCorePhase        = $ui01Recovery.searchCorePhase
        sessionDeltaMiB        = $ui01Recovery.sessionDeltaMiB
        uiSessionDeltaMiB      = $ui01Recovery.uiSessionDeltaMiB
        sessionDriftPct        = $ui01Recovery.sessionDriftPct
        totalSessionDriftPct   = $ui01Recovery.totalSessionDriftPct
        uiSessionDriftPct      = $ui01Recovery.uiSessionDriftPct
        refDeltaMiB            = $ui01Recovery.refDeltaMiB
        refDriftPct            = $ui01Recovery.refDriftPct
        sessionRecoveryPass    = $ui01Recovery.sessionRecoveryPass
        referenceBaselinePass  = $ui01Recovery.referenceBaselinePass
        coldStartConfirmed     = $ui01Recovery.coldStartConfirmed
        signoffMode            = $SignoffMode
        warnings               = @($ui01Warnings)
        recoveryLimitPct       = $MemoryRecoveryPct
        detail                 = $cycleDetail
        rounds                 = $UiRounds
        ahkPid                 = $ahk.Id
        lastAhkPid             = $lastAhkPid
    }
}

$signoffCases += New-SignoffCase -CaseId "UI-01" -Title "10-cycle UI recovery" -Steps @(
    "Open/close CP, SearchCenter, FTB for $UiRounds rounds",
    "Check no white screen or hang",
    "Idle ${IdleSec}s then memory sample",
    ('Primary uiPrivate sessionDrift le {0} pct; refDrift mode-dependent' -f $MemoryRecoveryPct)
) -Expected ('functionalPass=true and uiPrivate sessionDriftPct le {0} pct; formal-cold also needs pid change and refDrift pass' -f $MemoryRecoveryPct) `
    -Actual $ui01Actual -Trace $uiTrace -Pass $cyclePass -Artifacts $uiArtifacts -Warnings $ui01Warnings

$productPass = $true
if (-not $SkipFtbUx) { if ($ftbPass -ne $true) { $productPass = $false } }
if (-not $SkipCpHello) { if ($helloPass -ne $true) { $productPass = $false } }
if (-not $SkipUiCycle) { if ($cyclePass -ne $true) { $productPass = $false } }
if ($SkipFtbUx -and $SkipCpHello -and $SkipUiCycle) { $productPass = $false }

$reportWarnings = @($ui01Warnings)

$report = [ordered]@{
    capturedAt  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    repoRoot    = $RepoRoot
    signoffMode = $SignoffMode
    autoPass    = $null
    manualPass  = $productPass
    productPass = $productPass
    overallPass = $productPass
    warnings    = @($reportWarnings)
    steps       = $steps
    manualSignoff = [ordered]@{
        signoffCases = @($signoffCases)
        productPass  = $productPass
        signoffMode  = $SignoffMode
    }
    signoffCases = @($signoffCases)
    ui01Recovery = if ($ui01Recovery) {
        [ordered]@{
            functionalPass        = $functionalPass
            sessionBaselineKind   = $ui01Recovery.sessionBaselineKind
            sessionDriftPct       = $ui01Recovery.sessionDriftPct
            uiSessionDriftPct     = $ui01Recovery.uiSessionDriftPct
            totalSessionDriftPct  = $ui01Recovery.totalSessionDriftPct
            refDriftPct           = $ui01Recovery.refDriftPct
            sessionRecoveryPass   = $ui01Recovery.sessionRecoveryPass
            referenceBaselinePass = $ui01Recovery.referenceBaselinePass
            signoffMode           = $SignoffMode
            warnings              = @($ui01Warnings)
            pass                  = $cyclePass
            memBeforeMiB          = $ui01Recovery.memBeforeMiB
            memAfterMiB           = $ui01Recovery.memAfterMiB
            uiMemBeforeMiB        = $ui01Recovery.uiMemBeforeMiB
            uiMemAfterMiB         = $ui01Recovery.uiMemAfterMiB
            preCycleBeforeMiB     = $preCycleBeforeMiB
            preCycleUiBeforeMiB   = $preCycleUiBeforeMiB
            hybridReferenceMiB    = $ui01Recovery.hybridReferenceMiB
            referenceKind         = $ui01Recovery.referenceKind
            referenceFile         = $ui01Recovery.referenceFile
            referenceCapturedAt   = $ui01Recovery.referenceCapturedAt
            searchCorePhase       = $ui01Recovery.searchCorePhase
            coldStartConfirmed    = $ui01Recovery.coldStartConfirmed
        }
    } else { $null }
    memory      = @{
        sessionBaselineKind = "signoff_start_warm"
        beforeMiB           = $memBefore
        afterMiB            = $memAfter
        preCycleBeforeMiB   = $preCycleBeforeMiB
        preCycleUiBeforeMiB = $preCycleUiBeforeMiB
        uiMemBeforeMiB      = if ($ui01Recovery) { $ui01Recovery.uiMemBeforeMiB } else { $null }
        uiMemAfterMiB       = if ($ui01Recovery) { $ui01Recovery.uiMemAfterMiB } else { $null }
        recoveryLimitPct    = $MemoryRecoveryPct
        signoffMode         = $SignoffMode
    }
    commands    = @{
        runAll = ".\tools\a2ui-diagnostics\Run-HybridManualSignoff.ps1"
        ftbOnly = ".\tools\a2ui-diagnostics\Run-HybridFtbUxSmoke.ps1"
        helloOnly = ".\tools\a2ui-diagnostics\Invoke-HybridManualProbe.ps1 -Action agent_hello"
        cycleOnly = ".\tools\a2ui-diagnostics\Invoke-HybridManualProbe.ps1 -Action ui_cycle -Rounds 10"
    }
    notes = @(
        "UI-01 primary: uiPrivateMiB sessionDriftPct vs signoff_start_warm baseline le MemoryRecoveryPct (default 10 pct)",
        "pre-cycle mem_before is diagnostic only (SC stopped); not used for sessionDrift",
        "UI-01 auxiliary: refDrift warning in warm-session/live/relaxed; blocks in formal-cold",
        "formal-cold requires new AHK pid (Ctrl+Shift+Q does not count as cold start)",
        "FTB UX automation is hub-inject proxy; CP hello uses CommandPalette_AgentSubmit"
    )
}
$report | ConvertTo-Json -Depth 10 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "hybrid_manual_signoff -> $outPath productPass=$productPass signoffMode=$SignoffMode"

[ordered]@{ pid = $ahk.Id; capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") } |
    ConvertTo-Json | Set-Content -Path $lastPidPath -Encoding UTF8

if (Test-Path $baselineBackup) {
    Copy-Item $baselineBackup $mainBaseline -Force -ErrorAction SilentlyContinue
    Write-Host "  restored a2ui_memory_baseline.json from pre-ui-cycle backup" -ForegroundColor DarkGray
}

if ($RefreshDashboard) {
    & (Join-Path $here "Open-HybridSignoffDashboard.ps1") -RepoRoot $RepoRoot -SkipBaselineCapture -CollectOnly -SignoffMode live
}

if (-not $productPass) { exit 1 }
exit 0
