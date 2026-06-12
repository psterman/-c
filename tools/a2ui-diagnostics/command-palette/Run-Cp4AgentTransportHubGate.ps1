# CP4: palette.agentTransport=hub gray — hub chain + CP hello inject, no FTB-ready dependency.
param(
    [switch]$JsonOnly,
    [switch]$WithPerfRecheck,
    [int]$HelloWaitSec = 25
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Get-DiagRepoRoot -From $here
$dbg = Join-Path $repo "Cache\debug"
$hybridDir = Join-Path (Split-Path $here -Parent) "hybrid"
$gatePath = Join-Path $dbg "cp4_agent_transport_hub_gate.json"
$cp3dGatePath = Join-Path $dbg "cp3d_detail_lazy_load_gate.json"
$perfGatePath = Join-Path $dbg "command_palette_perf_gate.json"
$hubChainPath = Join-Path $dbg "hybrid_hub_chain_smoke.json"
$helloPath = Join-Path $dbg "hybrid_cp_hello_inject_smoke.json"
$cpHtml = Join-Path $repo "html\CommandPalette.html"
$orchAhk = Join-Path $repo "modules\CommandPaletteAgentOrchestrator.ahk"
$flagsPath = Join-Path $repo "local\nmer-flags.json"

function Get-JsonFile([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    return Get-Content $path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Test-NiumaAhkRunning {
    $procs = Get-Process -Name "AutoHotkey64", "AutoHotkey32" -ErrorAction SilentlyContinue
    if (-not $procs) { return $false }
    foreach ($p in $procs) {
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter ("ProcessId=" + $p.Id) -ErrorAction SilentlyContinue).CommandLine
            if ($cmd -and ($cmd -like "*$repo*" -or $cmd -like "*牛马.ahk*")) { return $true }
        } catch { }
    }
    return $false
}

function Test-LogForbiddenPatterns {
    $badPattern = "deliver_ready_timeout|waiting FTB shell|dispatch_exhausted|BRIDGE_FTB_NOT_READY"
    $paths = @(
        (Join-Path $dbg "cmdpal_agent_wire.log"),
        (Join-Path $dbg "command_palette_ai.log"),
        (Join-Path $dbg "wails_bridge.log")
    )
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        try {
            $tail = Get-Content $p -Tail 160 -Encoding UTF8 -ErrorAction SilentlyContinue
            foreach ($line in $tail) {
                if ($line -match $badPattern) { return $line }
            }
        } catch { }
    }
    return ""
}

Write-Host ""
Write-Host "=== CP4 Agent Transport Hub Gate ===" -ForegroundColor Cyan

$checks = @()
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

$cp3d = Get-JsonFile $cp3dGatePath
$cp3dPass = $cp3d -and [bool]$cp3d.overallPass
$checks += @{ name = "cp3d_prerequisite"; pass = $cp3dPass; value = $(if ($cp3dPass) { "pass" } else { "missing_or_fail" }) }
if (-not $cp3dPass) {
    [void]$failures.Add("cp3d_detail_lazy_load_gate.json overallPass!=true")
}

$flags = Get-JsonFile $flagsPath
$agentTransport = "auto"
$sidecarHost = ""
$stateStore = $false
$shadowFlag = $false
if ($flags) {
    if ($flags.palette) {
        $agentTransport = [string]$flags.palette.agentTransport
        $stateStore = [bool]$flags.palette.stateStore
        $shadowFlag = [bool]$flags.palette.stateStoreShadow
    }
    if ($flags.wailsBridge) {
        $sidecarHost = [string]$flags.wailsBridge.sidecarHost
    }
}
$hubTransport = ($agentTransport -eq "hub")
$hubSidecar = ($sidecarHost -eq "hub")
$checks += @{ name = "agentTransport_hub"; pass = $hubTransport; value = $agentTransport }
$checks += @{ name = "sidecarHost_hub"; pass = $hubSidecar; value = $(if ($sidecarHost) { $sidecarHost } else { "missing" }) }
$checks += @{ name = "stateStore_flag"; pass = $stateStore; value = $stateStore }
$checks += @{ name = "stateStoreShadow_flag"; pass = $shadowFlag; value = $shadowFlag }
if (-not $hubTransport) {
    [void]$failures.Add("set local/nmer-flags.json palette.agentTransport=hub (rollback: auto|ftb)")
}
if (-not $hubSidecar) {
    [void]$failures.Add("wailsBridge.sidecarHost should be hub for CP4")
}

$htmlOk = $false
if (Test-Path $cpHtml) {
    $htmlText = Get-Content $cpHtml -Encoding UTF8 -Raw
    $htmlOk = $htmlText -match "agentTransport" -and $htmlText -match "palette_flags"
}
$checks += @{ name = "html_agentTransport_flag"; pass = $htmlOk; value = $htmlOk }
if (-not $htmlOk) { [void]$failures.Add("CommandPalette.html missing agentTransport in palette_flags") }

$orchOk = $false
if (Test-Path $orchAhk) {
    $orchText = Get-Content $orchAhk -Encoding UTF8 -Raw
    $orchOk = $orchText -match 'flagT = "hub"' -and $orchText -match "AgentDispatchViaOpenClawAdapter"
}
$checks += @{ name = "ahk_hub_dispatch_path"; pass = $orchOk; value = $orchOk }
if (-not $orchOk) { [void]$failures.Add("CommandPaletteAgentOrchestrator missing hub-only dispatch path") }

if (-not (Ensure-DiagNmerHub -RepoRoot $repo -WarmupSec 2)) {
    [void]$failures.Add("nmer-hub not running")
    $checks += @{ name = "hub_running"; pass = $false; value = $false }
} else {
    $checks += @{ name = "hub_running"; pass = $true; value = $true }
}

$ahkRunning = Test-NiumaAhkRunning
$checks += @{ name = "ahk_running"; pass = $ahkRunning; value = $ahkRunning }
if (-not $ahkRunning) {
    [void]$warnings.Add("牛马.ahk not detected — hello inject smoke may fail; reload script before gate")
}

if ($WithPerfRecheck) {
    $perf = Get-JsonFile $perfGatePath
    $perfPass = $perf -and [bool]$perf.overallPass
    $checks += @{ name = "perf_gate_recheck"; pass = $perfPass; value = $(if ($perfPass) { "pass" } else { "fail_or_stale" }) }
    if (-not $perfPass) { [void]$failures.Add("command_palette_perf_gate.json overallPass!=true") }
}

$hubChainPass = $false
$helloPass = $false
if ($failures.Count -eq 0 -or ($hubTransport -and (Ensure-DiagNmerHub -RepoRoot $repo -WarmupSec 0))) {
    $hubScript = Join-Path $hybridDir "Run-HybridHubChainSmoke.ps1"
    $helloScript = Join-Path $hybridDir "Run-HybridCpHelloInjectSmoke.ps1"
    if (-not (Test-Path $hubScript)) {
        [void]$failures.Add("missing $hubScript")
    } else {
        & $hubScript -RepoRoot $repo -OutPath $hubChainPath
        $hubChain = Get-JsonFile $hubChainPath
        $hubChainPass = $hubChain -and [bool]$hubChain.overallPass
        $checks += @{ name = "hybrid_hub_chain"; pass = $hubChainPass; value = $(if ($hubChainPass) { "pass" } else { "fail" }) }
        if (-not $hubChainPass) { [void]$failures.Add("hybrid_hub_chain_smoke overallPass!=true") }
    }
    if (-not (Test-Path $helloScript)) {
        [void]$failures.Add("missing $helloScript")
    } else {
        & $helloScript -RepoRoot $repo -OutPath $helloPath -WaitSec $HelloWaitSec
        $hello = Get-JsonFile $helloPath
        $helloPass = $hello -and [bool]$hello.pass
        $checks += @{ name = "hybrid_cp_hello_inject"; pass = $helloPass; value = $(if ($helloPass) { "pass" } else { "fail" }) }
        if (-not $helloPass) { [void]$failures.Add("hybrid_cp_hello_inject_smoke pass!=true") }
    }
}

$badLog = Test-LogForbiddenPatterns
$logOk = [string]::IsNullOrWhiteSpace($badLog)
$checks += @{ name = "no_ftb_fatal_logs"; pass = $logOk; value = $(if ($logOk) { "clean" } else { $badLog }) }
if (-not $logOk) { [void]$failures.Add("forbidden log pattern: $badLog") }

$overallPass = ($failures.Count -eq 0)
$report = [ordered]@{
    generatedAt   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    phase         = "CP4"
    mode          = "agentTransport_hub_gray"
    overallPass   = $overallPass
    failReason    = if ($overallPass) { "" } else { ($failures -join "; ") }
    warnings      = @($warnings)
    checks        = $checks
    flagsPath     = $flagsPath
    agentTransport = $agentTransport
    sidecarHost   = $sidecarHost
    hubChain      = $hubChainPath
    helloInject   = $helloPath
    rollback      = "palette.agentTransport=auto or ftb"
    nextStep      = if ($overallPass) { "Phase H: P4 / CP5 / CP6 when stable" } else { "fix failures; ensure agentTransport=hub + reload 牛马.ahk" }
}

$report | ConvertTo-Json -Depth 10 | Set-Content -Path $gatePath -Encoding UTF8
if ($JsonOnly) {
    $report | ConvertTo-Json -Depth 10
    exit $(if ($overallPass) { 0 } else { 1 })
}

foreach ($c in $checks) {
    $color = if ($c.pass) { "Green" } else { "Red" }
    Write-Host ("  {0}: {1} -> {2}" -f $c.name, $c.value, $(if ($c.pass) { "PASS" } else { "FAIL" })) -ForegroundColor $color
}
if ($warnings.Count -gt 0) {
    Write-Host ""
    foreach ($w in $warnings) { Write-Host ("  WARN: {0}" -f $w) -ForegroundColor Yellow }
}
Write-Host ""
Write-Host ("overall: {0}" -f $(if ($overallPass) { "PASS" } else { "FAIL" })) -ForegroundColor $(if ($overallPass) { "Green" } else { "Red" })
Write-Host ("report: {0}" -f $gatePath) -ForegroundColor DarkGray
if (-not $hubTransport) {
    Write-Host "Enable: local/nmer-flags.json -> palette.agentTransport = hub" -ForegroundColor Yellow
}
if ($overallPass) { Write-Host "Next: Phase H (P4/CP5/CP6) when product-ready" -ForegroundColor Green }
exit $(if ($overallPass) { 0 } else { 1 })
