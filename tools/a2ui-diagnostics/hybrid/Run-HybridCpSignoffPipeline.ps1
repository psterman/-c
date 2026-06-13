# Patch C / Phase D→E: Hybrid warm-session signoff + automated CP PerfGate (no keyboard)
param(
    [string]$RepoRoot = "",
    [ValidateSet("warm-session", "formal-cold", "live", "relaxed")]
    [string]$SignoffMode = "warm-session",
    [ValidateSet("manual_equivalent", "synthetic_turbo")]
    [string]$PerfMode = "manual_equivalent",
    [int]$UiIdleSec = 20,
    [int]$UiPostCycleIdleSec = 45,
    [int]$UiScWaitSec = 60,
    [int]$PerfSettleSec = 20,
    [double]$MemoryRecoveryPct = 10,
    [switch]$SkipHybrid,
    [switch]$SkipPerfGate,
    [switch]$SkipManualChecklist,
    [switch]$SkipInjectPreflight,
    [switch]$SkipDashboard,
    [switch]$SkipAhkReload,
    [switch]$ContinueOnHybridFail,
    [switch]$NoArchive,
    [switch]$Force,
    [switch]$JsonOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
$outPath = Join-Path $debugDir "hybrid_cp_signoff_pipeline.json"

function Write-Phase([string]$title) {
    if (-not $JsonOnly) {
        Write-Host ""
        Write-Host $title -ForegroundColor Cyan
    }
}

function Read-CpDefaultHost([string]$flagsPath) {
    if (-not (Test-Path $flagsPath)) { return "?" }
    try {
        $f = Get-Content $flagsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($f.wailsBridge.commandPaletteHost) { return [string]$f.wailsBridge.commandPaletteHost }
    } catch { }
    return "?"
}

function Test-LegacyRollbackAvailable([string]$flagsPath) {
    if (-not (Test-Path $flagsPath)) {
        return @{ pass = $false; detail = "missing local/nmer-flags.json" }
    }
    try {
        $f = Get-Content $flagsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $cp = if ($f.wailsBridge) { [string]$f.wailsBridge.commandPaletteHost } else { "" }
        $side = if ($f.wailsBridge) { [string]$f.wailsBridge.sidecarHost } else { "" }
        $legacy = $null
        if ($f.rollback) { $legacy = $f.rollback.legacySurfaceLifecycle }
        $ok = ($cp -eq "ahk") -and ($side -eq "hub") -and ($legacy -eq $true)
        return @{
            pass   = $ok
            detail = "commandPaletteHost=$cp sidecarHost=$side legacySurfaceLifecycle=$legacy"
        }
    } catch {
        return @{ pass = $false; detail = $_.Exception.Message }
    }
}

function Test-WailsArchitecturePass([string]$debugDir) {
    $names = @(
        "cp7_wails_cp_shell_gate.json",
        "cp8_wails_cp_memory_soak.json",
        "cp9_wails_cp_hub_agent_live.json",
        "s8b3_phase2_signoff.json"
    )
    $rows = @()
    $all = $true
    foreach ($n in $names) {
        $p = Join-Path $debugDir $n
        $j = Read-DiagJson $p
        $pass = $false
        if ($j) {
            if ($null -ne $j.overallPass) { $pass = [bool]$j.overallPass }
            elseif ($null -ne $j.pass) { $pass = [bool]$j.pass }
            elseif ($null -ne $j.automatedCloseReady) { $pass = [bool]$j.automatedCloseReady }
        }
        if (-not $pass) { $all = $false }
        $rows += [ordered]@{ artifact = "Cache/debug/$n"; pass = $pass }
    }
    return @{ pass = $all; gates = $rows }
}

function Test-HybridFlagsReady([string]$flagsPath) {
    if (-not (Test-Path $flagsPath)) {
        return @{ pass = $false; detail = "missing local/nmer-flags.json" }
    }
    try {
        $f = Get-Content $flagsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $wb = $f.wailsBridge
        $ftb = if ($wb) { [string]$wb.floatingToolbarHost } else { "" }
        $side = if ($wb) { [string]$wb.sidecarHost } else { "" }
        $cp = if ($wb) { [string]$wb.commandPaletteHost } else { "" }
        $ok = ($ftb -eq "hybrid") -and ($side -eq "hub")
        return @{
            pass   = $ok
            detail = "floatingToolbarHost=$ftb sidecarHost=$side commandPaletteHost=$cp"
        }
    } catch {
        return @{ pass = $false; detail = $_.Exception.Message }
    }
}

$phases = [ordered]@{}
$overallPass = $true
$exitCode = 0
$runHybrid = -not $SkipHybrid
$runPerf = -not $SkipPerfGate

Write-Phase "== Hybrid → CP PerfGate Pipeline =="
if (-not $JsonOnly) {
    Write-Host "  repo: $RepoRoot" -ForegroundColor DarkGray
    Write-Host "  signoffMode: $SignoffMode | perfMode: $PerfMode" -ForegroundColor DarkGray
}

# --- 0) Preflight ---
Write-Phase "0/3 Preflight (hub + niuma + inject + flags)"
$preflight = [ordered]@{
    pass   = $true
    hub    = $false
    niuma  = $false
    inject = $null
    flags  = $null
    detail = @()
}
if (-not (Ensure-DiagNmerHub -RepoRoot $RepoRoot -WarmupSec 2)) {
    $preflight.pass = $false
    $preflight.detail += "nmer-hub not running and auto-start failed"
} else {
    $preflight.hub = $true
}
if (-not (Test-DiagNiumaAhkRunning -RepoRoot $RepoRoot)) {
    $preflight.pass = $false
    $preflight.detail += "牛马.ahk not running (start or Ctrl+Shift+Q reload)"
} else {
    $preflight.niuma = $true
}
$flagCheck = Test-HybridFlagsReady (Join-Path $RepoRoot "local\nmer-flags.json")
$preflight.flags = $flagCheck
if ($runHybrid -and -not $flagCheck.pass) {
    $preflight.pass = $false
    $preflight.detail += "flags: $($flagCheck.detail)"
} elseif (-not $JsonOnly) {
    Write-Host "  flags: $($flagCheck.detail)" -ForegroundColor DarkGray
}
if ($runHybrid -and -not $SkipInjectPreflight -and $preflight.hub -and $preflight.niuma) {
    try {
        $ping = & (Join-Path $here "Invoke-HybridInjectPing.ps1") -RepoRoot $RepoRoot -TimeoutSec 25 -MaxAttempts 3
        $preflight.inject = [ordered]@{ pass = $true; probeId = $ping.probeId; code = $ping.code }
        if (-not $JsonOnly) { Write-Host "  inject ping OK probeId=$($ping.probeId)" -ForegroundColor Green }
    } catch {
        $preflight.pass = $false
        $preflight.inject = [ordered]@{ pass = $false; detail = $_.Exception.Message }
        $preflight.detail += "inject ping: $($_.Exception.Message)"
    }
}
$phases.preflight = $preflight
if (-not $preflight.pass -and $runHybrid -and -not $ContinueOnHybridFail -and -not $Force) {
    $overallPass = $false
    $exitCode = 3
    $runHybrid = $false
    $runPerf = $false
    if (-not $JsonOnly) {
        Write-Host "  FAIL preflight (use -ContinueOnHybridFail or -Force to override)" -ForegroundColor Red
        foreach ($d in $preflight.detail) { Write-Host "    $d" -ForegroundColor Red }
    }
}

# --- 1) Hybrid Manual Signoff ---
$hybridPhase = [ordered]@{
    pass        = $null
    skipped     = [bool]$SkipHybrid
    productPass = $null
    overallPass = $null
    artifact    = "Cache/debug/hybrid_manual_signoff.json"
    dashboard   = "Cache/debug/hybrid_signoff_dashboard.json"
}
if ($runHybrid) {
    Write-Phase "1/3 Hybrid Manual Signoff ($SignoffMode)"
    $hybridArgs = @{
        RepoRoot            = $RepoRoot
        SignoffMode         = $SignoffMode
        IdleSec             = $UiIdleSec
        UiPostCycleIdleSec  = $UiPostCycleIdleSec
        UiScWaitSec         = $UiScWaitSec
        MemoryRecoveryPct   = $MemoryRecoveryPct
    }
    if (-not $SkipDashboard) {
        $hybridArgs["RefreshDashboard"] = $true
    }
    & (Join-Path $here "Run-HybridManualSignoff.ps1") @hybridArgs
    $hybridExit = $LASTEXITCODE
    $manual = Read-DiagJson (Join-Path $debugDir "hybrid_manual_signoff.json")
    $dash = Read-DiagJson (Join-Path $debugDir "hybrid_signoff_dashboard.json")
    if ($manual) {
        $hybridPhase.productPass = [bool]$manual.productPass
        $hybridPhase.overallPass = [bool]$manual.overallPass
        $hybridPhase.pass = ($hybridExit -eq 0) -and ($manual.productPass -eq $true)
        if ($manual.ui01Recovery) {
            $hybridPhase.ui01SessionDriftPct = $manual.ui01Recovery.sessionDriftPct
        }
    } else {
        $hybridPhase.pass = $false
        $hybridPhase.detail = "hybrid_manual_signoff.json missing"
    }
    if ($dash) {
        $hybridPhase.readyForHybridSignoff = [bool]$dash.readyForHybridSignoff
        if ($null -eq $hybridPhase.overallPass) {
            $hybridPhase.overallPass = [bool]$dash.overallPass
        }
    }
    if (-not $hybridPhase.pass) {
        $overallPass = $false
        if ($exitCode -eq 0) { $exitCode = 1 }
        if (-not $ContinueOnHybridFail -and -not $Force) {
            $runPerf = $false
            if (-not $JsonOnly) {
                Write-Host "  Hybrid FAIL — skipping PerfGate (use -ContinueOnHybridFail to force)" -ForegroundColor Yellow
            }
        }
    } elseif (-not $JsonOnly) {
        Write-Host "  Hybrid PASS productPass=$($hybridPhase.productPass)" -ForegroundColor Green
    }
} elseif (-not $SkipHybrid) {
    $hybridPhase.skipped = $true
    $hybridPhase.detail = "preflight blocked hybrid"
} elseif (-not $JsonOnly) {
    Write-Host "  skipped (-SkipHybrid)" -ForegroundColor DarkGray
}
$phases.hybrid = $hybridPhase

# --- 2) CP PerfGate (automated) ---
$perfPhase = [ordered]@{
    pass            = $null
    skipped         = [bool]$SkipPerfGate
    overallPass     = $null
    pipelinePass    = $null
    performancePass = $null
    mode            = $PerfMode
    artifact        = "Cache/debug/command_palette_perf_gate.json"
}
if ($runPerf) {
    if ($hybridPhase.pass -eq $true) {
        if (-not $SkipAhkReload) {
            if (-not $JsonOnly) {
                Write-Host "  Reload niuma.ahk before PerfGate (UI cycle stale CP web shell)..." -ForegroundColor DarkGray
            }
            if (-not (Restart-DiagNiumaAhk -RepoRoot $RepoRoot -WaitSec 45)) {
                throw "niuma.ahk failed to restart before PerfGate"
            }
            try {
                & (Join-Path $here "Invoke-HybridInjectPing.ps1") -RepoRoot $RepoRoot -TimeoutSec 30 -MaxAttempts 4 | Out-Null
            } catch {
                throw "inject ping failed after AHK reload: $($_.Exception.Message)"
            }
        } elseif ($PerfSettleSec -gt 0 -and -not $JsonOnly) {
            Write-Host "  CP settle ${PerfSettleSec}s (-SkipAhkReload)..." -ForegroundColor DarkGray
            Start-Sleep -Seconds $PerfSettleSec
        }
    }
    Write-Phase "2/3 CP PerfGate automated ($PerfMode)"
    $perfExit = 1
    try {
        $perfArgs = @{ Mode = $PerfMode; SkipReload = $true }
        if ($NoArchive) { $perfArgs["NoArchive"] = $true }
        if ($Force) { $perfArgs["Force"] = $true }
        & (Join-Path (Join-Path $here "..\command-palette") "Run-CommandPalettePerfAutomated.ps1") @perfArgs
        $perfExit = $LASTEXITCODE
    } catch {
        $perfPhase.detail = ($_.Exception.Message -split "`n")[0]
        if (-not $JsonOnly) {
            Write-Host ("  PerfGate error: {0}" -f $perfPhase.detail) -ForegroundColor Red
        }
    }
    $gate = Read-DiagJson (Join-Path $debugDir "command_palette_perf_gate.json")
    if ($gate) {
        $perfPhase.overallPass = [bool]$gate.overallPass
        $perfPhase.pipelinePass = [bool]$gate.pipelinePass
        $perfPhase.performancePass = [bool]$gate.performancePass
        $perfPhase.pass = ($perfExit -eq 0) -and ($gate.overallPass -eq $true)
    } else {
        $perfPhase.pass = $false
        $perfPhase.detail = "command_palette_perf_gate.json missing"
    }
    if (-not $perfPhase.pass) {
        $overallPass = $false
        if ($exitCode -eq 0) { $exitCode = 2 }
    } elseif (-not $JsonOnly) {
        Write-Host "  PerfGate PASS overallPass=$($perfPhase.overallPass)" -ForegroundColor Green
    }
} elseif (-not $SkipPerfGate) {
    $perfPhase.skipped = $true
    $perfPhase.detail = "blocked after hybrid fail"
} elseif (-not $JsonOnly) {
    Write-Host "  skipped (-SkipPerfGate)" -ForegroundColor DarkGray
}
$phases.perfGate = $perfPhase

Write-Phase "3/4 CP release aggregation (default AHK)"

$flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"
$defaultHost = Read-CpDefaultHost $flagsPath
$legacyRollback = Test-LegacyRollbackAvailable $flagsPath
$wailsArch = Test-WailsArchitecturePass $debugDir

$manualPhase = [ordered]@{
    pass     = $null
    skipped  = [bool]$SkipManualChecklist
    artifact = "Cache/debug/cp_manual_release_checklist.json"
}
$manualReleasePass = $false
if (-not $SkipManualChecklist) {
    $manualJson = Read-DiagJson (Join-Path $debugDir "cp_manual_release_checklist.json")
    if ($manualJson) {
        if ($null -ne $manualJson.manualReleasePass) {
            $manualReleasePass = [bool]$manualJson.manualReleasePass
        } elseif ($null -ne $manualJson.overallPass) {
            $manualReleasePass = [bool]$manualJson.overallPass
        }
        $manualPhase.pass = $manualReleasePass
    } else {
        $manualPhase.pass = $false
        $manualPhase.detail = "run Run-CpManualReleaseChecklist.ps1 -Init then record 6 items"
    }
} else {
    $manualPhase.skipped = $true
    $manualPhase.detail = "-SkipManualChecklist"
}
$phases.manualChecklist = $manualPhase

$hybridPass = $false
if ($hybridPhase.pass -eq $true) {
    $hybridPass = ($SignoffMode -eq "warm-session")
} elseif ($SkipHybrid) {
    $manualSnap = Read-DiagJson (Join-Path $debugDir "hybrid_manual_signoff.json")
    if ($manualSnap -and $manualSnap.productPass -eq $true -and $SignoffMode -eq "warm-session") {
        $hybridPass = $true
        $hybridPhase.pass = $true
        $hybridPhase.detail = "from artifact (SkipHybrid)"
    }
}
$perfGatePass = $false
$perfGateOfficial = $false
$gate = Read-DiagJson (Join-Path $debugDir "command_palette_perf_gate.json")
if ($perfPhase.pass -eq $true) {
    $perfGatePass = $true
} elseif ($SkipPerfGate -and $gate -and $gate.overallPass -eq $true) {
    $perfGatePass = $true
    $perfPhase.pass = $true
    $perfPhase.detail = "from artifact (SkipPerfGate)"
}
if ($gate) {
    $modeOk = ([string]$gate.captureMode -eq "manual_equivalent") -or ($PerfMode -eq "manual_equivalent")
    $perfGateOfficial = $perfGatePass -and $modeOk
}
$defaultHostAhk = ($defaultHost -eq "ahk")
$legacyRollbackPass = [bool]$legacyRollback.pass

$cpReleasePass = $manualReleasePass -and $hybridPass -and $perfGatePass -and $perfGateOfficial `
    -and $defaultHostAhk -and $legacyRollbackPass

$wailsArchitecturePass = [bool]$wailsArch.pass
$wailsDefaultEligible = $false
$wailsDefaultBlockedReason = "raycast_ux_gate_not_passed"

$release = [ordered]@{
    cpReleasePass             = $cpReleasePass
    manualReleasePass         = $manualReleasePass
    hybridPass                = $hybridPass
    perfGatePass              = $perfGatePass
    perfGateOfficial          = $perfGateOfficial
    defaultHost               = $defaultHost
    legacyRollbackPass        = $legacyRollbackPass
    legacyRollbackDetail      = $legacyRollback.detail
    wailsArchitecturePass     = $wailsArchitecturePass
    wailsArchitectureGates    = $wailsArch.gates
    wailsDefaultEligible      = $wailsDefaultEligible
    wailsDefaultBlockedReason = $wailsDefaultBlockedReason
    note                      = "wailsArchitecturePass is informational; does not block cpReleasePass"
}
$phases.release = $release

Write-Phase "4/4 Summary"

$report = [ordered]@{
    capturedAt  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    repoRoot    = $RepoRoot
    signoffMode = $SignoffMode
    perfMode    = $PerfMode
    pass        = $overallPass
    cpReleasePass = $cpReleasePass
    exitCode    = $exitCode
    release     = $release
    phases      = $phases
    artifacts   = @(
        "Cache/debug/hybrid_cp_signoff_pipeline.json",
        "Cache/debug/hybrid_manual_signoff.json",
        "Cache/debug/hybrid_signoff_dashboard.json",
        "Cache/debug/command_palette_perf_gate.json",
        "Cache/debug/cp_manual_release_checklist.json"
    )
    commands    = [ordered]@{
        fullPipeline   = ".\tools\a2ui-diagnostics\Run-HybridCpSignoffPipeline.ps1"
        manualChecklist  = ".\tools\a2ui-diagnostics\Run-CpManualReleaseChecklist.ps1 -Init"
        hybridOnly     = ".\tools\a2ui-diagnostics\Run-HybridManualSignoff.ps1 -SignoffMode warm-session -RefreshDashboard"
        perfOnly       = ".\tools\a2ui-diagnostics\Run-CommandPalettePerfAutomated.ps1"
    }
}
$report | ConvertTo-Json -Depth 10 | Set-Content -Path $outPath -Encoding UTF8

if (-not $JsonOnly) {
    Write-Host ""
    Write-Host "pipeline -> $outPath pass=$overallPass cpReleasePass=$cpReleasePass exitCode=$exitCode" -ForegroundColor $(if ($cpReleasePass) { "Green" } elseif ($overallPass) { "Yellow" } else { "Red" })
    Write-Host ("  manual={0} hybrid={1} perf={2} perfOfficial={3} defaultHost={4} legacyRollback={5} wailsArch={6} (info only)" -f `
        $manualReleasePass, $hybridPass, $perfGatePass, $perfGateOfficial, $defaultHost, $legacyRollbackPass, $wailsArchitecturePass) -ForegroundColor DarkGray
    if ($cpReleasePass) {
        Write-Host "CP release signed off on AHK host (Wails default still blocked)" -ForegroundColor Green
    } elseif (-not $manualReleasePass -and -not $SkipManualChecklist) {
        Write-Host "Next: complete manual checklist (Run-CpManualReleaseChecklist.ps1)" -ForegroundColor Yellow
    }
}
exit $exitCode
