# S11 Hybrid FTB static gate (AHK presentation + Go Hub inject)
param(
    [string]$RepoRoot = ""
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $here = Split-Path -Parent $MyInvocation.MyCommand.Path
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}

$routerPath = Join-Path $RepoRoot "modules\FloatingToolbarRouter.ahk"
$wailsHostPath = Join-Path $RepoRoot "modules\FloatingToolbarWailsHost.ahk"
$ftbMod = Join-Path $RepoRoot "modules\FloatingToolbar.ahk"
$bridgeAhk = Join-Path $RepoRoot "modules\NmerWailsBridge.ahk"
$cmdPalPath = Join-Path $RepoRoot "modules\CommandPaletteCore.ahk"
$agentPath = Join-Path $RepoRoot "modules\CommandPaletteAgentOrchestrator.ahk"
$shellGo = Join-Path $RepoRoot "apps\nmer-wails\poc\shell_ftb.go"
$mainGo = Join-Path $RepoRoot "apps\nmer-wails\main.go"
$mainTs = Join-Path $RepoRoot "apps\nmer-wails\frontend\src\main.ts"
$exampleFlagsPath = Join-Path $RepoRoot "docs\nmer-flags.example.json"
$outPath = Join-Path $RepoRoot "Cache\debug\s11hybrid_gate_diagnosis.txt"
$jsonPath = Join-Path $RepoRoot "Cache\debug\s11hybrid_gate_diagnosis.json"

$null = New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null

$failureReasons = @()
$lines = @()
$lines += "S11 Hybrid FTB Gate Diagnosis"
$lines += "capturedAt=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

function Read-Text([string]$path) {
    if (-not (Test-Path $path)) { return "" }
    return Get-Content $path -Raw -Encoding UTF8
}

$routerText = Read-Text $routerPath
$wailsText = Read-Text $wailsHostPath
$ftbText = Read-Text $ftbMod
$bridgeText = Read-Text $bridgeAhk
$cmdPalText = Read-Text $cmdPalPath
$agentText = Read-Text $agentPath
$shellGoText = Read-Text $shellGo
$mainGoText = Read-Text $mainGo
$mainTsText = Read-Text $mainTs

if (-not $routerText) { $failureReasons += "router_module_missing" }
if (-not $wailsText) { $failureReasons += "wails_host_module_missing" }

$routerHasHybrid = $routerText -match 'FloatingToolbarRouter_ShouldUseHybrid'
$routerHasShowHybrid = $routerText -match 'FloatingToolbarWails_ShowHybrid'
$hostAcceptsHybrid = $routerText -match '"hybrid"'

$wailsHasShouldUseHybrid = $wailsText -match 'FloatingToolbarWails_ShouldUseHybrid'
$wailsHasInjectPump = $wailsText -match 'FloatingToolbarWails_InjectPumpTick'
$wailsHasDeliverHybrid = $wailsText -match 'FloatingToolbarWails_DeliverPayloadHybrid'
$wailsHasShowHybrid = $wailsText -match 'FloatingToolbarWails_ShowHybrid'
$hybridBlocksShell = ($wailsText -match 'FloatingToolbarRouter_ShouldUseHybrid') -and ($wailsText -match 'ShouldUseShell')

$transportHybrid = $wailsText -match 'return "hybrid"'
$cmdPalHybridMode = $cmdPalText -match 'mode = "hybrid"'
$cmdPalDeliverHybrid = $cmdPalText -match 'FloatingToolbarWails_DeliverPayloadHybrid'
$agentHybridEnsure = $agentText -match 'FloatingToolbarWails_EnsureHybridBridge'
$agentPollNotHybrid = ($agentText -match 'AgentPollFtbAnswerShell') -and ($agentText -match 'wails_shell')

$shellGoExternal = $shellGoText -match 'presentationMode' -and $shellGoText -match 'register_external' -and $shellGoText -match '/shell/ftb/inject/drain'
$bridgeDrainInject = $bridgeText -match 'Nmer_WailsBridgeDrainShellFtbInject'
$ftbReadyHook = $ftbText -match 'FloatingToolbarWails_RegisterExternalReady'
$mainGoHidden = $mainGoText -match 'StartHidden'
$mainTsBridgeOnly = $mainTsText -match 'bridge-only' -or $mainTsText -match 'bridgeOnly'

$exampleHasHybridComment = $false
if (Test-Path $exampleFlagsPath) {
    $ex = Get-Content $exampleFlagsPath -Raw -Encoding UTF8
    $exampleHasHybridComment = $ex -match 'hybrid'
}

$gatePass = $routerHasHybrid -and $routerHasShowHybrid -and $hostAcceptsHybrid `
    -and $wailsHasShouldUseHybrid -and $wailsHasInjectPump -and $wailsHasDeliverHybrid `
    -and $wailsHasShowHybrid -and $hybridBlocksShell -and $transportHybrid `
    -and $cmdPalHybridMode -and $cmdPalDeliverHybrid -and $agentHybridEnsure `
    -and $shellGoExternal -and $bridgeDrainInject -and $ftbReadyHook `
    -and $mainGoHidden -and $mainTsBridgeOnly

if (-not $routerHasHybrid) { $failureReasons += "router_missing_hybrid_branch" }
if (-not $wailsHasInjectPump) { $failureReasons += "missing_inject_pump" }
if (-not $shellGoExternal) { $failureReasons += "shell_go_external_incomplete" }
if (-not $bridgeDrainInject) { $failureReasons += "bridge_missing_inject_drain" }
if (-not $cmdPalDeliverHybrid) { $failureReasons += "cmdpal_missing_hybrid_deliver" }
if (-not $transportHybrid) { $failureReasons += "palette_transport_missing_hybrid" }

$lines += "s11_hybrid_gate_pass=$gatePass"
$lines += "router_hybrid=$routerHasHybrid show_hybrid=$routerHasShowHybrid host_enum=$hostAcceptsHybrid"
$lines += "wails_should_hybrid=$wailsHasShouldUseHybrid inject_pump=$wailsHasInjectPump deliver_hybrid=$wailsHasDeliverHybrid"
$lines += "shell_go_external=$shellGoExternal bridge_drain_inject=$bridgeDrainInject ftb_ready_hook=$ftbReadyHook"
$lines += "bridge_only_ui=$mainTsBridgeOnly start_hidden=$mainGoHidden"
$lines += "agent_hybrid_ensure=$agentHybridEnsure agent_poll_shell_only=$agentPollNotHybrid"
$lines += "example_flags_hybrid_doc=$exampleHasHybridComment"
if ($failureReasons.Count -gt 0) {
    $lines += "failureReasons=$($failureReasons -join ',')"
}

$lines | Set-Content -Path $outPath -Encoding UTF8
@{
    capturedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    s11_hybrid_gate_pass = $gatePass
    failureReasons = $failureReasons
    checks = @{
        router_hybrid = $routerHasHybrid
        inject_pump = $wailsHasInjectPump
        shell_go_external = $shellGoExternal
        bridge_drain_inject = $bridgeDrainInject
        cmdpal_deliver_hybrid = $cmdPalDeliverHybrid
        transport_hybrid = $transportHybrid
        bridge_only_ui = $mainTsBridgeOnly
    }
} | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8

Write-Host ($lines -join "`n")
if (-not $gatePass) { exit 1 }
