# S8 B3 CommandPalette Wails static gate
param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $here = Split-Path -Parent $MyInvocation.MyCommand.Path
    $RepoRoot = (Resolve-Path (Join-Path $here "..\..")).Path
}

$routerPath = Join-Path $RepoRoot "modules\CommandPaletteRouter.ahk"
$wailsHostPath = Join-Path $RepoRoot "modules\CommandPaletteWailsHost.ahk"
$intentPath = Join-Path $RepoRoot "modules\SurfaceIntentRouter.ahk"
$flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"
$exampleFlagsPath = Join-Path $RepoRoot "docs\nmer-flags.example.json"
$mainAhk = ""
$wailsExe = Join-Path $RepoRoot "apps\nmer-wails\build\bin\nmer-wails.exe"
$wailsApp = Join-Path $RepoRoot "apps\nmer-wails\app.go"
$paletteBundle = Join-Path $RepoRoot "html\vendor\a2ui\nmer-a2ui-v09.js"
$outPath = Join-Path $RepoRoot "Cache\debug\s8b3_gate_diagnosis.txt"
$jsonPath = Join-Path $RepoRoot "Cache\debug\s8b3_gate_diagnosis.json"

$null = New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null

$failureReasons = @()
$lines = @()
$lines += "S8 B3 Gate Diagnosis"
$lines += "capturedAt=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

$routerText = ""
$intentText = ""
$mainText = ""
if (-not (Test-Path $routerPath)) { $failureReasons += "router_module_missing" } else { $routerText = Get-Content $routerPath -Raw -Encoding UTF8 }
if (-not (Test-Path $wailsHostPath)) { $failureReasons += "wails_host_module_missing" } else { $null = Get-Content $wailsHostPath -Raw -Encoding UTF8 }
if (-not (Test-Path $intentPath)) { $failureReasons += "intent_router_missing" } else { $intentText = Get-Content $intentPath -Raw -Encoding UTF8 }
foreach ($candidate in (Get-ChildItem -LiteralPath $RepoRoot -Filter "*.ahk" -File -ErrorAction SilentlyContinue)) {
    try {
        $probe = Get-Content -LiteralPath $candidate.FullName -Raw -Encoding UTF8 -ErrorAction Stop
        if ($probe -match 'CommandPaletteCore\.ahk') {
            $mainAhk = $candidate.FullName
            $mainText = $probe
            break
        }
    } catch { }
}

$routerHasHostFn = $routerText -match 'Nmer_CommandPaletteHost'
$routerHasShow = $routerText -match 'CommandPaletteRouter_Show'
$intentUsesRouter = $intentText -match 'CommandPaletteRouter_Show'
$mainIncludesRouter = $mainText -match 'CommandPaletteRouter\.ahk'
$mainIncludesWailsHost = $mainText -match 'CommandPaletteWailsHost\.ahk'
$exampleHasCpHost = $false
if (Test-Path $exampleFlagsPath) {
    try {
        $ex = Get-Content $exampleFlagsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $exampleHasCpHost = $null -ne $ex.wailsBridge.commandPaletteHost
    } catch { }
}

$flagsHost = "ahk"
$legacyOn = $true
$wailsBridgeOn = $false
if (Test-Path $flagsPath) {
    try {
        $f = Get-Content $flagsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($f.wailsBridge.commandPaletteHost) { $flagsHost = [string]$f.wailsBridge.commandPaletteHost }
        if ($null -ne $f.wailsBridge.enabled) { $wailsBridgeOn = [bool]$f.wailsBridge.enabled }
        if ($null -ne $f.rollback.legacySurfaceLifecycle) { $legacyOn = [bool]$f.rollback.legacySurfaceLifecycle }
    } catch { }
}

if (-not $routerHasHostFn) { $failureReasons += "router_missing_host_selector" }
if (-not $routerHasShow) { $failureReasons += "router_missing_show" }
if (-not $intentUsesRouter) { $failureReasons += "intent_not_using_router" }
if (-not $mainAhk) { $failureReasons += "main_ahk_not_found" }
if (-not $mainIncludesRouter) { $failureReasons += "main_missing_router_include" }
if (-not $mainIncludesWailsHost) { $failureReasons += "main_missing_wails_host_include" }
if (-not $exampleHasCpHost) { $failureReasons += "example_flags_missing_cp_host" }
if (-not $legacyOn) { $failureReasons += "legacy_surface_lifecycle_off" }
if (-not (Test-Path $wailsApp)) { $failureReasons += "wails_app_missing" }
if (-not (Test-Path $paletteBundle)) { $failureReasons += "palette_a2ui_bundle_missing" }

$wailsExePresent = Test-Path $wailsExe

$cpHostEvents = 0
$logPath = Join-Path $RepoRoot "Cache\debug\surface_runtime.ndjson"
if (Test-Path $logPath) {
    $cpHostEvents = @(
        Get-Content $logPath -Encoding UTF8 | ForEach-Object {
            try { $_ | ConvertFrom-Json } catch { $null }
        } | Where-Object { $_ -and $_.type -eq "cp_host_show" }
    ).Count
}

$s8Pass = ($failureReasons.Count -eq 0)

$lines += ""
$lines += "s8B3Gate:"
$lines += "commandPaletteHost=$flagsHost"
$lines += "legacySurfaceLifecycle=$legacyOn"
$lines += "wailsBridge_enabled=$wailsBridgeOn"
$lines += "router_module=$([bool](Test-Path $routerPath))"
$lines += "wails_host_module=$([bool](Test-Path $wailsHostPath))"
$lines += "intent_uses_router=$intentUsesRouter"
$lines += "main_ahk_found=$([bool]$mainAhk)"
$lines += "main_includes_router=$mainIncludesRouter"
$lines += "main_includes_wails_host=$mainIncludesWailsHost"
$lines += "example_flags_cp_host=$exampleHasCpHost"
$lines += "wails_exe_present=$wailsExePresent"
$lines += "palette_a2ui_bundle=$([bool](Test-Path $paletteBundle))"
$lines += "cp_host_show_events=$cpHostEvents"
$lines += "s8_gate_pass=$s8Pass"
if ($failureReasons.Count) {
    $lines += "failure_reasons=$($failureReasons -join ',')"
}

$lines | Set-Content -Path $outPath -Encoding UTF8

@{
    capturedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    gate = "s8"
    title = "S8 B3 CP"
    s8_gate_pass = [bool]$s8Pass
    s8_failure_reasons = @($failureReasons)
    metrics = @{
        commandPaletteHost = $flagsHost
        legacySurfaceLifecycle = $(if ($legacyOn) { 1 } else { 0 })
        wails_exe_present = $(if ($wailsExePresent) { 1 } else { 0 })
        palette_a2ui_bundle = $(if (Test-Path $paletteBundle) { 1 } else { 0 })
        cp_host_show = $cpHostEvents
        intent_uses_router = $(if ($intentUsesRouter) { 1 } else { 0 })
        main_includes_router = $(if ($mainIncludesRouter) { 1 } else { 0 })
        main_includes_wails_host = $(if ($mainIncludesWailsHost) { 1 } else { 0 })
        example_flags_cp_host = $(if ($exampleHasCpHost) { 1 } else { 0 })
    }
} | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8

Write-Host "s8 b3 gate diagnosis -> $outPath"
Write-Host "s8 b3 gate json -> $jsonPath"
Write-Host ("S8 gate: " + $(if ($s8Pass) { "PASS" } else { "FAIL" }))
if ($failureReasons.Count) {
    Write-Host ("reasons: " + ($failureReasons -join ", "))
}
exit $(if ($s8Pass) { 0 } else { 1 })
