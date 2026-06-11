# Automate 3 hybrid manual signoff steps -> Cache/debug/hybrid_manual_signoff.json
param(
    [string]$RepoRoot = "",
    [int]$UiRounds = 10,
    [int]$IdleSec = 15,
    [double]$MemoryRecoveryPct = 10,
    [switch]$SkipFtbUx,
    [switch]$SkipCpHello,
    [switch]$SkipUiCycle,
    [switch]$RefreshDashboard,
    [switch]$CpHelloInjectFallback = $true,
    [switch]$SkipInjectUiCycle
)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $here "..\..")).Path
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
$outPath = Join-Path $debugDir "hybrid_manual_signoff.json"
$mainBaseline = Join-Path $debugDir "a2ui_memory_baseline.json"
$baselineBackup = Join-Path $debugDir "hybrid_signoff_baseline_backup.json"

function Read-Json([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    try { return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
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

# --- 1) FTB UX (hub inject proxy) ---
$ftbPass = $null
$ftbDetail = "skipped"
if (-not $SkipFtbUx) {
    Write-Host "== [1/3] FTB UX smoke ==" -ForegroundColor Cyan
    & (Join-Path $here "Run-HybridFtbUxSmoke.ps1") -RepoRoot $RepoRoot
    $ftb = Read-Json (Join-Path $debugDir "hybrid_ftb_ux_smoke.json")
    $ftbPass = [bool]$ftb.pass
    $ftbDetail = "hub inject + external status"
}
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
if (-not $SkipCpHello) {
    Write-Host "== [2/3] CP Agent hello ==" -ForegroundColor Cyan
    $helloPass = $false
    $helloDetail = ""
    if ($CpHelloInjectFallback) {
        Write-Host "  mode: hub inject fallback (no file IPC)" -ForegroundColor DarkGray
        & (Join-Path $here "Run-HybridCpHelloInjectSmoke.ps1") -RepoRoot $RepoRoot
        $hinj = Read-Json (Join-Path $debugDir "hybrid_cp_hello_inject_smoke.json")
        $helloPass = [bool]$hinj.pass
        $helloDetail = "inject_fallback pass=$helloPass"
    } else {
        Write-Host "  mode: file IPC (reload niuma once if this fails in 4s)" -ForegroundColor DarkGray
        try {
            $hello = & (Join-Path $here "Invoke-HybridManualProbe.ps1") -RepoRoot $RepoRoot -Action "agent_hello" -Query "hello" -TimeoutSec 55
            $helloPass = [bool]$hello.pass
            $helloDetail = [string]$hello.code
            if ($hello.cardId) { $helloDetail += " card=$($hello.cardId) req=$($hello.reqId)" }
        } catch {
            Write-Host "  IPC failed: $($_.Exception.Message.Split([char]10)[0])" -ForegroundColor Yellow
            Write-Host "  retry with hub inject fallback..." -ForegroundColor Yellow
            & (Join-Path $here "Run-HybridCpHelloInjectSmoke.ps1") -RepoRoot $RepoRoot
            $hinj = Read-Json (Join-Path $debugDir "hybrid_cp_hello_inject_smoke.json")
            $helloPass = [bool]$hinj.pass
            $helloDetail = "inject_fallback_after_ipc_fail pass=$helloPass"
        }
    }
}
$steps += [ordered]@{
    id        = "cp_hello"
    title     = "CP Agent hello"
    pass      = $helloPass
    autoCheck = $true
    detail    = $helloDetail
    hint      = "Automated: palette_agent_submit hello via hybrid_manual_probe.json IPC"
}

# --- 3) UI cycle 10 rounds + memory recovery ---
$cyclePass = $null
$cycleDetail = "skipped"
$memBefore = $null
$memAfter = $null
if (-not $SkipUiCycle) {
    Write-Host "== [3/3] UI cycle $UiRounds rounds ==" -ForegroundColor Cyan
    if (Test-Path $mainBaseline) {
        Copy-Item $mainBaseline $baselineBackup -Force
    }
    $uiMemBefore = Join-Path $debugDir "hybrid_ui_cycle_mem_before.json"
    $uiMemAfter = Join-Path $debugDir "hybrid_ui_cycle_mem_after.json"
    & (Join-Path $here "capture-memory-baseline.ps1") -RepoRoot $RepoRoot -OutPath $uiMemBefore | Out-Null
    $bl0 = Read-Json $uiMemBefore
    if ($bl0 -and $bl0.processes) {
        $memBefore = [double]$bl0.processes.totalPrivateMiB
    }
    $uiOk = $false
    if (-not $SkipInjectUiCycle) {
        Write-Host "  mode: hub inject ui_cycle (reload niuma Ctrl+Shift+Q if ping preflight fails)" -ForegroundColor DarkGray
        try {
            & (Join-Path $here "Run-HybridUiCycleInjectSmoke.ps1") -RepoRoot $RepoRoot -Rounds $UiRounds
            $uinj = Read-Json (Join-Path $debugDir "hybrid_ui_cycle_inject_smoke.json")
            $uiOk = [bool]$uinj.pass
            $cycleDetail = "inject code=$($uinj.resultCode) cp=$($uinj.cpOpens) sc=$($uinj.scOpens)"
        } catch {
            $cycleDetail = "inject_failed " + ($_.Exception.Message -split "`n")[0]
            Write-Host "  inject ui_cycle failed: $cycleDetail" -ForegroundColor Yellow
        }
    }
    if (-not $uiOk) {
        try {
            $ping = & (Join-Path $here "Invoke-HybridManualProbe.ps1") -RepoRoot $RepoRoot -Action "ping" -TimeoutSec 12
            if ($ping.pass) {
                $cycle = & (Join-Path $here "Invoke-HybridManualProbe.ps1") -RepoRoot $RepoRoot -Action "ui_cycle" -Rounds $UiRounds -TimeoutSec 180 -SkipHubWake
                $uiOk = [bool]$cycle.pass
                $cycleDetail = "file_ipc " + [string]$cycle.code
            }
        } catch {
            Write-Host "  file IPC skipped/failed: $(($_.Exception.Message -split "`n")[0])" -ForegroundColor DarkGray
        }
    }
    if (-not $uiOk) {
        Write-Host "  fallback: CapsLock hotkeys (keep hands off keyboard ~90s)..." -ForegroundColor Yellow
        try {
            & (Join-Path $here "Run-HybridUiCycleKeysSmoke.ps1") -RepoRoot $RepoRoot -Rounds $UiRounds
            $keys = Read-Json (Join-Path $debugDir "hybrid_ui_cycle_keys_smoke.json")
            $uiOk = [bool]$keys.pass
            $cycleDetail = "keys_fallback cp=$($keys.cpOpens) sc=$($keys.scOpens) pass=$($keys.pass)"
        } catch {
            $uiOk = $false
            $cycleDetail = "keys_fallback_failed " + ($_.Exception.Message -split "`n")[0]
        }
    }
    if ($uiOk) {
        Write-Host "  idle ${IdleSec}s before memory sample..." -ForegroundColor DarkGray
        Start-Sleep -Seconds $IdleSec
        & (Join-Path $here "capture-memory-baseline.ps1") -RepoRoot $RepoRoot -OutPath $uiMemAfter | Out-Null
        $bl1 = Read-Json $uiMemAfter
        if ($bl1 -and $bl1.processes) {
            $memAfter = [double]$bl1.processes.totalPrivateMiB
        }
        $ref = Read-Json (Join-Path $debugDir "hybrid_signoff_reference_hybrid.json")
        if (-not $ref) { $ref = Read-Json (Join-Path $debugDir "hybrid_signoff_reference_ahk.json") }
        $memPass = $true
        if ($ref -and ($null -ne $memAfter)) {
            $refMiB = [double]$ref.totalPrivateMiB
            $driftPct = if ($refMiB -gt 0) { [math]::Round((([math]::Abs($memAfter - $refMiB)) / $refMiB) * 100, 2) } else { 0 }
            $memPass = ($driftPct -le $MemoryRecoveryPct)
            $cycleDetail = "ui_ok mem=${memAfter}MiB ref=${refMiB}MiB drift=${driftPct}%"
        } elseif ($memBefore -ne $null -and $memAfter -ne $null) {
            $driftPct = if ($memBefore -gt 0) { [math]::Round((([math]::Abs($memAfter - $memBefore)) / $memBefore) * 100, 2) } else { 0 }
            $memPass = ($driftPct -le $MemoryRecoveryPct)
            $cycleDetail = "ui_ok mem ${memBefore}->${memAfter}MiB drift=${driftPct}% (no ref file)"
        } else {
            $cycleDetail = "ui_ok memory_sample_missing"
            $memPass = $false
        }
        $cyclePass = $uiOk -and $memPass
    } else {
        if (-not $cycleDetail) { $cycleDetail = "ui_cycle probe failed" }
        $cyclePass = $false
    }
}
$steps += [ordered]@{
    id        = "ui_cycle_10"
    title     = "10-round UI recovery CP/FTB/SC"
    pass      = $cyclePass
    autoCheck = $true
    detail    = $cycleDetail
    hint      = "Automated: SurfaceIntent open/close CP/SC/FTB x$UiRounds + memory drift <= ${MemoryRecoveryPct}%"
}

$allPass = ($steps | Where-Object { $_.pass -ne $null } | Where-Object { $_.pass -eq $false }).Count -eq 0
$report = [ordered]@{
    capturedAt  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    repoRoot    = $RepoRoot
    overallPass = $allPass
    steps       = $steps
    memory      = @{
        beforeMiB = $memBefore
        afterMiB  = $memAfter
        recoveryLimitPct = $MemoryRecoveryPct
    }
    commands    = @{
        runAll = ".\tools\a2ui-diagnostics\Run-HybridManualSignoff.ps1"
        ftbOnly = ".\tools\a2ui-diagnostics\Run-HybridFtbUxSmoke.ps1"
        helloOnly = ".\tools\a2ui-diagnostics\Invoke-HybridManualProbe.ps1 -Action agent_hello"
        cycleOnly = ".\tools\a2ui-diagnostics\Invoke-HybridManualProbe.ps1 -Action ui_cycle -Rounds 10"
    }
    notes = @(
        "Reload niuma.ahk once after pulling NmerWailsBridge hybrid_manual_probe IPC",
        "FTB UX automation is hub-inject proxy; visual drag/scale still optional spot-check",
        "CP hello uses real CommandPalette_AgentSubmit (adapter may fallback to FTB hybrid inject)"
    )
}
$report | ConvertTo-Json -Depth 8 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "hybrid_manual_signoff -> $outPath overallPass=$allPass"

if (Test-Path $baselineBackup) {
    Copy-Item $baselineBackup $mainBaseline -Force -ErrorAction SilentlyContinue
    Write-Host "  restored a2ui_memory_baseline.json from pre-ui-cycle backup" -ForegroundColor DarkGray
}

if ($RefreshDashboard) {
    $cap = Join-Path $here "Capture-HybridSignoffBaseline.ps1"
    if (Test-Path $cap) {
        & $cap -RepoRoot $RepoRoot -UseHybridReferenceFallback
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  WARN: memory baseline low; dashboard memory_delta may fail" -ForegroundColor Yellow
        }
    }
    & (Join-Path $here "Open-HybridSignoffDashboard.ps1") -RepoRoot $RepoRoot -SkipBaselineCapture -CollectOnly
}

if (-not $allPass) { exit 1 }
exit 0
