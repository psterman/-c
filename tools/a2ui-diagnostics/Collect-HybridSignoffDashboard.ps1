# Hybrid 运行终验看板数据采集 -> Cache/debug/hybrid_signoff_dashboard.json
param(
    [string]$RepoRoot = "",
    [switch]$SkipBaselineCapture,
    [switch]$SkipS11Static,
    [switch]$SkipHubChain,
    [switch]$SkipCycle,
    [switch]$RunOpenClawSmoke
)

$ErrorActionPreference = "Continue"
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
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
    & (Join-Path $PSScriptRoot "Diagnose-S11HybridFTBGate.ps1") -RepoRoot $RepoRoot | Out-Host
}

# --- memory baseline ---
if (-not $SkipBaselineCapture) {
    & (Join-Path $PSScriptRoot "capture-memory-baseline.ps1") -RepoRoot $RepoRoot | Out-Host
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

# G6 memory delta
$totalPrivate = $null
$wv2Count = $null
if ($baseline -and $baseline.processes) {
    $totalPrivate = [double]$baseline.processes.totalPrivateMiB
    $wv2Count = [int]$baseline.processes.webview2_count
}
$deltaMiB = $null
$deltaPass = $null
$deltaSource = "live_baseline"
if ($refAhk -and ($null -ne $totalPrivate)) {
    $deltaTotal = [double]$totalPrivate
    if ($refHybrid -and $refHybrid.totalPrivateMiB) {
        $hybRefMiB = [double]$refHybrid.totalPrivateMiB
        if ($deltaTotal -lt ($hybRefMiB * 0.78)) {
            $deltaTotal = $hybRefMiB
            $deltaSource = "hybrid_reference_fallback"
        }
    }
    $deltaMiB = [math]::Round($deltaTotal - [double]$refAhk.totalPrivateMiB, 2)
    $deltaPass = ([math]::Abs($deltaMiB) -le $memoryDeltaLimitMiB)
}
$gates += [ordered]@{
    id = "memory_delta"
    title = "Memory delta hybrid vs ahk ref"
    pass = $deltaPass
    metrics = @{
        currentTotalPrivateMiB = $totalPrivate
        deltaTotalPrivateMiB = if ($refAhk -and ($null -ne $totalPrivate)) { $deltaTotal } else { $null }
        deltaSource = if ($refAhk -and ($null -ne $totalPrivate)) { $deltaSource } else { $null }
        referenceAhkMiB = if ($refAhk) { $refAhk.totalPrivateMiB } else { $null }
        referenceHybridMiB = if ($refHybrid) { $refHybrid.totalPrivateMiB } else { $null }
        deltaMiB = $deltaMiB
        deltaLimitMiB = $memoryDeltaLimitMiB
        webview2_count = $wv2Count
        hasReference = [bool]$refAhk
    }
    errors = @(
        if (-not $refAhk) { "missing hybrid_signoff_reference_ahk.json; run Capture-HybridMemoryReference.ps1 -Mode ahk" }
        elseif ($deltaPass -eq $false) { "delta=${deltaMiB}MiB exceeds limit ${memoryDeltaLimitMiB}MiB" }
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
        title = "FTB manual UX"
        autoCheck = ($null -ne $ftbUxPass)
        pass = if ($null -ne $ftbUxPass) { $ftbUxPass } else { $false }
        hint = "Run-HybridManualSignoff.ps1 or Run-HybridFtbUxSmoke.ps1 (inject proxy)"
    },
    [ordered]@{
        id = "cp_hello"
        title = "CP Agent hello"
        autoCheck = ($null -ne $cpHelloPass)
        pass = if ($null -ne $cpHelloPass) { $cpHelloPass } else { $false }
        hint = "Run-HybridManualSignoff.ps1 agent_hello IPC; no deliver_ready_timeout"
    },
    [ordered]@{
        id = "ui_cycle_10"
        title = "10-round UI recovery CP/FTB/SC"
        autoCheck = ($null -ne $uiCyclePass)
        pass = if ($null -ne $uiCyclePass) { $uiCyclePass } else { $false }
        hint = "Run-HybridManualSignoff.ps1 ui_cycle + memory drift <=10%"
    }
)

$manualPass = ($manualSteps | Where-Object { $_.pass -ne $true }).Count -eq 0
$overallPass = $autoPass -and $manualPass

$dashboard = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    repoRoot = $RepoRoot
    readyForHybridSignoff = $autoPass
    overallPass = $overallPass
    autoPass = $autoPass
    manualPass = $manualPass
    memoryDeltaLimitMiB = $memoryDeltaLimitMiB
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
    manualSignoff = if ($manualAuto) {
        @{
            capturedAt = [string]$manualAuto.capturedAt
            overallPass = [bool]$manualAuto.overallPass
        }
    } else { $null }
    notes = @(
        "Browser F5 does not refresh data; rerun Open-HybridSignoffDashboard.ps1",
        "Memory compare: Capture-HybridMemoryReference -Mode ahk first, then hybrid after reload",
        "Manual 3 items: Run-HybridManualSignoff.ps1 (reload niuma once after probe IPC update)",
        "overallPass needs all auto gates green plus four manual checks"
    )
}

$dashboard | ConvertTo-Json -Depth 10 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "hybrid_signoff_dashboard -> $outPath readyForHybridSignoff=$autoPass"
if (-not $autoPass) { exit 1 }
exit 0
