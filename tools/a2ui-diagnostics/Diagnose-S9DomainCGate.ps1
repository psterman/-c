# S9 Domain C static gate (SearchCenter + Config routers)
param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $here = Split-Path -Parent $MyInvocation.MyCommand.Path
    $RepoRoot = (Resolve-Path (Join-Path $here "..\..")).Path
}

$routerPath = Join-Path $RepoRoot "modules\DomainCSurfaceRouter.ahk"
$wailsHostPath = Join-Path $RepoRoot "modules\DomainCWailsHost.ahk"
$intentPath = Join-Path $RepoRoot "modules\SurfaceIntentRouter.ahk"
$runtimePath = Join-Path $RepoRoot "modules\SurfaceRuntimeManager.ahk"
$flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"
$exampleFlagsPath = Join-Path $RepoRoot "docs\nmer-flags.example.json"
$wailsExe = Join-Path $RepoRoot "apps\nmer-wails\build\bin\nmer-wails.exe"
$wailsApp = Join-Path $RepoRoot "apps\nmer-wails\app.go"
$scCore = Join-Path $RepoRoot "modules\SearchCenterWebViewCore.ahk"
$configMod = Join-Path $RepoRoot "modules\ConfigWebViewModule.ahk"
$outPath = Join-Path $RepoRoot "Cache\debug\s9domainc_gate_diagnosis.txt"
$jsonPath = Join-Path $RepoRoot "Cache\debug\s9domainc_gate_diagnosis.json"

$null = New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null

$failureReasons = @()
$lines = @()
$lines += "S9 Domain C Gate Diagnosis"
$lines += "capturedAt=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

$routerText = ""
$intentText = ""
$runtimeText = ""
$mainText = ""
if (-not (Test-Path $routerPath)) { $failureReasons += "router_module_missing" } else { $routerText = Get-Content $routerPath -Raw -Encoding UTF8 }
if (-not (Test-Path $wailsHostPath)) { $failureReasons += "wails_host_module_missing" } else { $null = Get-Content $wailsHostPath -Raw -Encoding UTF8 }
if (-not (Test-Path $intentPath)) { $failureReasons += "intent_router_missing" } else { $intentText = Get-Content $intentPath -Raw -Encoding UTF8 }
if (Test-Path $runtimePath) { $runtimeText = Get-Content $runtimePath -Raw -Encoding UTF8 }
foreach ($candidate in (Get-ChildItem -LiteralPath $RepoRoot -Filter "*.ahk" -File -ErrorAction SilentlyContinue)) {
    try {
        $probe = Get-Content -LiteralPath $candidate.FullName -Raw -Encoding UTF8 -ErrorAction Stop
        if ($probe -match 'CommandPaletteCore\.ahk') {
            $mainText = $probe
            break
        }
    } catch { }
}

$routerHasScHost = $routerText -match 'Nmer_SearchCenterHost'
$routerHasCfgHost = $routerText -match 'Nmer_ConfigWebviewHost'
$routerHasScOpen = $routerText -match 'SearchCenterRouter_Open'
$routerHasCfgShow = $routerText -match 'ConfigWebViewRouter_Show'
$intentUsesScRouter = $intentText -match 'SearchCenterRouter_Open'
$intentUsesCfgRouter = $intentText -match 'ConfigWebViewRouter_Show'
$runtimeUsesScDispose = $runtimeText -match 'SearchCenterRouter_Dispose'
$runtimeUsesCfgDispose = $runtimeText -match 'ConfigWebViewRouter_Dispose'
$wailsText = ""
if (Test-Path $wailsHostPath) { $wailsText = Get-Content $wailsHostPath -Raw -Encoding UTF8 }
$wailsHasScShow = $wailsText -match 'sc_host_show'
$wailsHasCfgShow = $wailsText -match 'config_host_show'
$mainIncludesRouter = $mainText -match 'DomainCSurfaceRouter\.ahk'
$mainIncludesWailsHost = $mainText -match 'DomainCWailsHost\.ahk'

$scHost = "ahk"
$cfgHost = "ahk"
$legacyOn = $true
$wailsBridgeOn = $false
$exampleHasHosts = $false
if (Test-Path $exampleFlagsPath) {
    try {
        $ex = Get-Content $exampleFlagsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $exampleHasHosts = ($null -ne $ex.wailsBridge.searchCenterHost) -and ($null -ne $ex.wailsBridge.configWebviewHost)
    } catch { }
}
if (Test-Path $flagsPath) {
    try {
        $f = Get-Content $flagsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($f.wailsBridge.searchCenterHost) { $scHost = [string]$f.wailsBridge.searchCenterHost }
        if ($f.wailsBridge.configWebviewHost) { $cfgHost = [string]$f.wailsBridge.configWebviewHost }
        if ($null -ne $f.wailsBridge.enabled) { $wailsBridgeOn = [bool]$f.wailsBridge.enabled }
        if ($null -ne $f.rollback.legacySurfaceLifecycle) { $legacyOn = [bool]$f.rollback.legacySurfaceLifecycle }
    } catch { }
}

if (-not $routerHasScHost) { $failureReasons += "router_missing_sc_host_selector" }
if (-not $routerHasCfgHost) { $failureReasons += "router_missing_config_host_selector" }
if (-not $routerHasScOpen) { $failureReasons += "router_missing_sc_open" }
if (-not $routerHasCfgShow) { $failureReasons += "router_missing_config_show" }
if (-not $intentUsesScRouter) { $failureReasons += "intent_not_using_sc_router" }
if (-not $intentUsesCfgRouter) { $failureReasons += "intent_not_using_config_router" }
if (-not $runtimeUsesScDispose) { $failureReasons += "runtime_not_using_sc_router_dispose" }
if (-not $runtimeUsesCfgDispose) { $failureReasons += "runtime_not_using_config_router_dispose" }
if (-not $mainIncludesRouter) { $failureReasons += "main_missing_domainc_router_include" }
if (-not $mainIncludesWailsHost) { $failureReasons += "main_missing_domainc_wails_host_include" }
if (-not $exampleHasHosts) { $failureReasons += "example_flags_missing_domainc_hosts" }
if (-not $wailsHasScShow) { $failureReasons += "wails_host_missing_sc_event" }
if (-not $wailsHasCfgShow) { $failureReasons += "wails_host_missing_config_event" }
if (-not $legacyOn) { $failureReasons += "legacy_surface_lifecycle_off" }
if (-not (Test-Path $wailsApp)) { $failureReasons += "wails_app_missing" }
if (-not (Test-Path $scCore)) { $failureReasons += "scwv_core_missing" }
if (-not (Test-Path $configMod)) { $failureReasons += "config_webview_module_missing" }

$wailsExePresent = Test-Path $wailsExe

$scHostEvents = 0
$configHostEvents = 0
$logPath = Join-Path $RepoRoot "Cache\debug\surface_runtime.ndjson"
if (Test-Path $logPath) {
    $rows = @(Get-Content $logPath -Encoding UTF8 | ForEach-Object {
        try { $_ | ConvertFrom-Json } catch { $null }
    } | Where-Object { $_ })
    $scHostEvents = @($rows | Where-Object { $_.type -eq "sc_host_show" }).Count
    $configHostEvents = @($rows | Where-Object { $_.type -eq "config_host_show" }).Count
}

$s9Pass = ($failureReasons.Count -eq 0)

$lines += ""
$lines += "s9DomainCGate:"
$lines += "searchCenterHost=$scHost"
$lines += "configWebviewHost=$cfgHost"
$lines += "legacySurfaceLifecycle=$legacyOn"
$lines += "wailsBridge_enabled=$wailsBridgeOn"
$lines += "intent_uses_sc_router=$intentUsesScRouter"
$lines += "intent_uses_config_router=$intentUsesCfgRouter"
$lines += "runtime_uses_sc_dispose=$runtimeUsesScDispose"
$lines += "runtime_uses_config_dispose=$runtimeUsesCfgDispose"
$lines += "main_includes_router=$mainIncludesRouter"
$lines += "main_includes_wails_host=$mainIncludesWailsHost"
$lines += "wails_exe_present=$wailsExePresent"
$lines += "sc_host_show_events=$scHostEvents"
$lines += "config_host_show_events=$configHostEvents"
$lines += "s9_gate_pass=$s9Pass"
if ($failureReasons.Count) {
    $lines += "failure_reasons=$($failureReasons -join ',')"
}

$lines | Set-Content -Path $outPath -Encoding UTF8

@{
    capturedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    gate = "s9"
    title = "S9 Domain C"
    s9_gate_pass = [bool]$s9Pass
    s9_failure_reasons = @($failureReasons)
    metrics = @{
        searchCenterHost = $scHost
        configWebviewHost = $cfgHost
        legacySurfaceLifecycle = $(if ($legacyOn) { 1 } else { 0 })
        wails_exe_present = $(if ($wailsExePresent) { 1 } else { 0 })
        sc_host_show = $scHostEvents
        config_host_show = $configHostEvents
        intent_uses_sc_router = $(if ($intentUsesScRouter) { 1 } else { 0 })
        intent_uses_config_router = $(if ($intentUsesCfgRouter) { 1 } else { 0 })
        main_includes_router = $(if ($mainIncludesRouter) { 1 } else { 0 })
        main_includes_wails_host = $(if ($mainIncludesWailsHost) { 1 } else { 0 })
    }
} | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8

Write-Host "s9 domain c gate diagnosis -> $outPath"
Write-Host "s9 domain c gate json -> $jsonPath"
Write-Host ("S9 gate: " + $(if ($s9Pass) { "PASS" } else { "FAIL" }))
if ($failureReasons.Count) {
    Write-Host ("reasons: " + ($failureReasons -join ", "))
}
exit $(if ($s9Pass) { 0 } else { 1 })
