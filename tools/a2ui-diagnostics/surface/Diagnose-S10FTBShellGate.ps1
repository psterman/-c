# S10 FTB Shell static gate (FloatingToolbar router + Wails host sidecar)
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
$intentPath = Join-Path $RepoRoot "modules\SurfaceIntentRouter.ahk"
$runtimePath = Join-Path $RepoRoot "modules\SurfaceRuntimeManager.ahk"
$ftbMod = Join-Path $RepoRoot "modules\FloatingToolbar.ahk"
$bridgePath = Join-Path $RepoRoot "html\ftb\palette\palette-agent-bridge.js"
$flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"
$exampleFlagsPath = Join-Path $RepoRoot "docs\nmer-flags.example.json"
$wailsExe = Join-Path $RepoRoot "apps\nmer-wails\build\bin\nmer-wails.exe"
$wailsApp = Join-Path $RepoRoot "apps\nmer-wails\app.go"
$bridgeAhk = Join-Path $RepoRoot "modules\NmerWailsBridge.ahk"
$shellGo = Join-Path $RepoRoot "apps\nmer-wails\poc\shell_ftb.go"
$shellPhase3 = $false
$shellPhase4 = $false
$ftbShellTs = Join-Path $RepoRoot "apps\nmer-wails\frontend\src\ftb-shell\ftb-shell-host.ts"
$wailsMainTs = Join-Path $RepoRoot "apps\nmer-wails\frontend\src\main.ts"
$outPath = Join-Path $RepoRoot "Cache\debug\s10ftb_gate_diagnosis.txt"
$jsonPath = Join-Path $RepoRoot "Cache\debug\s10ftb_gate_diagnosis.json"

$null = New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null

$failureReasons = @()
$lines = @()
$lines += "S10 FTB Shell Gate Diagnosis"
$lines += "capturedAt=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

$routerText = ""
$intentText = ""
$runtimeText = ""
$mainText = ""
$wailsText = ""
$bridgeAhkText = ""
if (-not (Test-Path $routerPath)) { $failureReasons += "router_module_missing" } else { $routerText = Get-Content $routerPath -Raw -Encoding UTF8 }
if (-not (Test-Path $wailsHostPath)) { $failureReasons += "wails_host_module_missing" } else { $wailsText = Get-Content $wailsHostPath -Raw -Encoding UTF8 }
if (-not (Test-Path $intentPath)) { $failureReasons += "intent_router_missing" } else { $intentText = Get-Content $intentPath -Raw -Encoding UTF8 }
if (Test-Path $runtimePath) { $runtimeText = Get-Content $runtimePath -Raw -Encoding UTF8 }
if (Test-Path $bridgeAhk) { $bridgeAhkText = Get-Content $bridgeAhk -Raw -Encoding UTF8 }
foreach ($candidate in (Get-ChildItem -LiteralPath $RepoRoot -Filter "*.ahk" -File -ErrorAction SilentlyContinue)) {
    try {
        $probe = Get-Content -LiteralPath $candidate.FullName -Raw -Encoding UTF8 -ErrorAction Stop
        if ($probe -match 'CommandPaletteCore\.ahk') {
            $mainText = $probe
            break
        }
    } catch { }
}

$routerHasHostFn = $routerText -match 'Nmer_FloatingToolbarHost'
$routerHasShow = $routerText -match 'FloatingToolbarRouter_Show'
$routerHasHide = $routerText -match 'FloatingToolbarRouter_Hide'
$routerHasDispose = $routerText -match 'FloatingToolbarRouter_Dispose'
$intentUsesRouterShow = $intentText -match 'FloatingToolbarRouter_Show'
$intentUsesRouterHide = $intentText -match 'FloatingToolbarRouter_Hide'
$runtimeUsesRouterDispose = $runtimeText -match 'FloatingToolbarRouter_Dispose'
$wailsHasFtbShow = $wailsText -match 'ftb_host_show'
$wailsHasShellPhase2 = $wailsText -match 'FloatingToolbarWails_ShouldUseShell'
$wailsHasShellMount = $wailsText -match 'Nmer_WailsBridgePostShellFtb'
$ftbHasShellGuard = $false
if (Test-Path $ftbMod) {
    $ftbText = Get-Content $ftbMod -Raw -Encoding UTF8
    $ftbHasShellGuard = ($ftbText -match 'FloatingToolbarWails_ShouldUseShell') -or ($ftbText -match 'FloatingToolbar_AhkWebViewEnabled')
}
$shellGoPresent = Test-Path $shellGo
$ftbShellTsPresent = Test-Path $ftbShellTs
$mainTsUsesFtbShell = $false
if (Test-Path $wailsMainTs) {
    $mainTsText = Get-Content $wailsMainTs -Raw -Encoding UTF8
    $mainTsUsesFtbShell = ($mainTsText -match 'nmer-ftb-shell-host') -and ($mainTsText -match 'shell:ftb')
}
$bridgeHasShellApi = $bridgeAhkText -match 'Nmer_WailsBridgePostShellFtb'
$bridgeHasShellInject = $bridgeAhkText -match 'Nmer_WailsBridgePostShellFtbInject'
$bridgeHasShellEgress = $bridgeAhkText -match 'Nmer_WailsBridgeDrainShellFtbEgress'
$wailsHasDeliverPayload = $wailsText -match 'FloatingToolbarWails_DeliverPayload'
$wailsHasEgressPump = $wailsText -match 'FloatingToolbarWails_EgressPumpTick'
$shellGoHasInject = $false
$shellGoHasEgress = $false
if (Test-Path $shellGo) {
    $shellGoText = Get-Content $shellGo -Raw -Encoding UTF8
    $shellGoHasInject = $shellGoText -match '/shell/ftb/inject'
    $shellGoHasEgress = $shellGoText -match '/shell/ftb/egress'
}
$cmdPalHasTransportMode = $false
$cmdPalPath = Join-Path $RepoRoot "modules\CommandPaletteCore.ahk"
if (Test-Path $cmdPalPath) {
    $cmdPalText = Get-Content $cmdPalPath -Raw -Encoding UTF8
    $cmdPalHasTransportMode = $cmdPalText -match 'CommandPalette_FtbTransportMode'
}
$shellPhase3 = $shellGoHasInject -and $shellGoHasEgress -and $bridgeHasShellInject -and $bridgeHasShellEgress -and $wailsHasDeliverPayload -and $wailsHasEgressPump -and $cmdPalHasTransportMode
$ftbHasAhkRetireGuard = $false
$ftbHasDisposeRetired = $false
$wailsHasRetireHook = $false
if (Test-Path $ftbMod) {
    if (-not $ftbText) { $ftbText = Get-Content $ftbMod -Raw -Encoding UTF8 }
    $ftbHasAhkRetireGuard = $ftbText -match 'FloatingToolbar_AhkWebViewEnabled'
    $ftbHasDisposeRetired = $ftbText -match 'FloatingToolbar_DisposeAhkWebViewIfRetired'
}
$wailsHasRetireHook = $wailsText -match 'FloatingToolbarWails_RetireAhkWebView'
$shellPhase4 = $ftbHasAhkRetireGuard -and $ftbHasDisposeRetired -and $wailsHasRetireHook -and $shellPhase3
$mainIncludesRouter = $mainText -match 'FloatingToolbarRouter\.ahk'
$mainIncludesWailsHost = $mainText -match 'FloatingToolbarWailsHost\.ahk'
$bridgeHasFtbFlag = $bridgeAhkText -match 'Nmer_FloatingToolbarHostFlag'
$bridgeHasStreamOnce = $false
if (Test-Path $bridgePath) {
    $bridgeJs = Get-Content $bridgePath -Raw -Encoding UTF8
    $bridgeHasStreamOnce = ($bridgeJs -match 'runPaletteAgentStreamOnce')
}

$ftbHost = "ahk"
$legacyOn = $true
$wailsBridgeOn = $false
$exampleHasFtbHost = $false
if (Test-Path $exampleFlagsPath) {
    try {
        $ex = Get-Content $exampleFlagsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $exampleHasFtbHost = $null -ne $ex.wailsBridge.floatingToolbarHost
    } catch { }
}
if (Test-Path $flagsPath) {
    try {
        $f = Get-Content $flagsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($f.wailsBridge.floatingToolbarHost) { $ftbHost = [string]$f.wailsBridge.floatingToolbarHost }
        if ($null -ne $f.wailsBridge.enabled) { $wailsBridgeOn = [bool]$f.wailsBridge.enabled }
        if ($null -ne $f.rollback.legacySurfaceLifecycle) { $legacyOn = [bool]$f.rollback.legacySurfaceLifecycle }
    } catch { }
}

if (-not $routerHasHostFn) { $failureReasons += "router_missing_host_selector" }
if (-not $routerHasShow) { $failureReasons += "router_missing_show" }
if (-not $routerHasHide) { $failureReasons += "router_missing_hide" }
if (-not $routerHasDispose) { $failureReasons += "router_missing_dispose" }
if (-not $intentUsesRouterShow) { $failureReasons += "intent_not_using_router_show" }
if (-not $intentUsesRouterHide) { $failureReasons += "intent_not_using_router_hide" }
if (-not $runtimeUsesRouterDispose) { $failureReasons += "runtime_not_using_router_dispose" }
if (-not $mainIncludesRouter) { $failureReasons += "main_missing_router_include" }
if (-not $mainIncludesWailsHost) { $failureReasons += "main_missing_wails_host_include" }
if (-not $exampleHasFtbHost) { $failureReasons += "example_flags_missing_ftb_host" }
if (-not $wailsHasFtbShow) { $failureReasons += "wails_host_missing_ftb_event" }
if (-not $bridgeHasFtbFlag) { $failureReasons += "bridge_missing_ftb_host_flag" }
if (-not $bridgeHasShellApi) { $failureReasons += "bridge_missing_shell_ftb_api" }
if (-not $shellGoPresent) { $failureReasons += "wails_shell_ftb_go_missing" }
if (-not $ftbShellTsPresent) { $failureReasons += "wails_ftb_shell_host_missing" }
if (-not $mainTsUsesFtbShell) { $failureReasons += "wails_main_missing_ftb_shell_listener" }
if (-not $wailsHasShellPhase2) { $failureReasons += "wails_host_missing_shell_phase2" }
if (-not $wailsHasShellMount) { $failureReasons += "wails_host_missing_shell_mount" }
if (-not $ftbHasShellGuard) { $failureReasons += "ftb_missing_shell_guard" }
if (-not (Test-Path $wailsApp)) { $failureReasons += "wails_app_missing" }
if (-not (Test-Path $ftbMod)) { $failureReasons += "ftb_module_missing" }
if (-not $bridgeHasStreamOnce) { $failureReasons += "palette_bridge_missing_stream_once" }

$wailsExePresent = Test-Path $wailsExe

$ftbHostEvents = 0
$logPath = Join-Path $RepoRoot "Cache\debug\surface_runtime.ndjson"
if (Test-Path $logPath) {
    $ftbHostEvents = @(
        Get-Content $logPath -Encoding UTF8 | ForEach-Object {
            try { $_ | ConvertFrom-Json } catch { $null }
        } | Where-Object { $_ -and $_.type -eq "ftb_host_show" }
    ).Count
}

$s10Pass = ($failureReasons.Count -eq 0)

$lines += ""
$lines += "s10FtbShellGate:"
$lines += "floatingToolbarHost=$ftbHost"
$lines += "legacySurfaceLifecycle=$legacyOn"
$lines += "wailsBridge_enabled=$wailsBridgeOn"
$lines += "intent_uses_router_show=$intentUsesRouterShow"
$lines += "intent_uses_router_hide=$intentUsesRouterHide"
$lines += "runtime_uses_router_dispose=$runtimeUsesRouterDispose"
$lines += "main_includes_router=$mainIncludesRouter"
$lines += "main_includes_wails_host=$mainIncludesWailsHost"
$lines += "example_flags_ftb_host=$exampleHasFtbHost"
$lines += "wails_exe_present=$wailsExePresent"
$lines += "palette_bridge_stream_once=$bridgeHasStreamOnce"
$lines += "shell_ftb_go=$shellGoPresent"
$lines += "ftb_shell_host_ts=$ftbShellTsPresent"
$lines += "shell_phase2_wired=$($wailsHasShellPhase2 -and $bridgeHasShellApi -and $shellGoPresent -and $ftbShellTsPresent)"
$lines += "shell_phase3_wired=$shellPhase3"
$lines += "shell_phase4_wired=$shellPhase4"
$lines += "ftb_host_show_events=$ftbHostEvents"
$lines += "s10_gate_pass=$s10Pass"
if ($failureReasons.Count) {
    $lines += "failure_reasons=$($failureReasons -join ',')"
}

$lines | Set-Content -Path $outPath -Encoding UTF8

@{
    capturedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    gate = "s10"
    title = "S10 FTB Shell"
    s10_gate_pass = [bool]$s10Pass
    s10_failure_reasons = @($failureReasons)
    metrics = @{
        floatingToolbarHost = $ftbHost
        legacySurfaceLifecycle = $(if ($legacyOn) { 1 } else { 0 })
        wails_exe_present = $(if ($wailsExePresent) { 1 } else { 0 })
        ftb_host_show = $ftbHostEvents
        intent_uses_router_show = $(if ($intentUsesRouterShow) { 1 } else { 0 })
        intent_uses_router_hide = $(if ($intentUsesRouterHide) { 1 } else { 0 })
        runtime_uses_router_dispose = $(if ($runtimeUsesRouterDispose) { 1 } else { 0 })
        main_includes_router = $(if ($mainIncludesRouter) { 1 } else { 0 })
        main_includes_wails_host = $(if ($mainIncludesWailsHost) { 1 } else { 0 })
        example_flags_ftb_host = $(if ($exampleHasFtbHost) { 1 } else { 0 })
        palette_bridge_stream_once = $(if ($bridgeHasStreamOnce) { 1 } else { 0 })
        shell_ftb_go = $(if ($shellGoPresent) { 1 } else { 0 })
        ftb_shell_host_ts = $(if ($ftbShellTsPresent) { 1 } else { 0 })
        shell_phase2_wired = $(if ($wailsHasShellPhase2 -and $bridgeHasShellApi -and $shellGoPresent -and $ftbShellTsPresent) { 1 } else { 0 })
        shell_phase3_wired = $(if ($shellPhase3) { 1 } else { 0 })
        shell_phase4_wired = $(if ($shellPhase4) { 1 } else { 0 })
    }
} | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8

Write-Host "s10 ftb shell gate diagnosis -> $outPath"
Write-Host "s10 ftb shell gate json -> $jsonPath"
Write-Host ("S10 gate: " + $(if ($s10Pass) { "PASS" } else { "FAIL" }))
if ($failureReasons.Count) {
    Write-Host ("reasons: " + ($failureReasons -join ", "))
}
exit $(if ($s10Pass) { 0 } else { 1 })
