# CP6: Command Palette Wails gray — static gate + optional runtime smoke.
param(
    [switch]$JsonOnly,
    [switch]$WithSmoke,
    [switch]$SkipPrompt,
    [switch]$RevertFlags
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Get-DiagRepoRoot -From $here
$dbg = Join-Path $repo "Cache\debug"
$gatePath = Join-Path $dbg "cp6_wails_gray_gate.json"
$cp5GatePath = Join-Path $dbg "cp5_modular_shell_gate.json"
$cp4GatePath = Join-Path $dbg "cp4_agent_transport_hub_gate.json"
$s8JsonPath = Join-Path $dbg "s8b3_gate_diagnosis.json"
$flagsPath = Join-Path $repo "local\nmer-flags.json"
$exampleFlagsPath = Join-Path $repo "docs\nmer-flags.example.json"
$routerPath = Join-Path $repo "modules\CommandPaletteRouter.ahk"
$wailsHostPath = Join-Path $repo "modules\CommandPaletteWailsHost.ahk"
$wailsAppPath = Join-Path $repo "apps\nmer-wails\app.go"
$wailsExePath = Join-Path $repo "apps\nmer-wails\build\bin\nmer-wails.exe"
$surfaceLogPath = Join-Path $dbg "surface_runtime.ndjson"
$smokeScript = Join-Path $here "Invoke-Cp6WailsGraySmoke.ps1"
$liveSmokeScript = Join-Path $here "Run-Cp6WailsGrayLiveSmoke.ps1"
$liveSmokeReportPath = Join-Path $dbg "cp6_wails_gray_live_smoke.json"

function Get-JsonFile([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    return Get-Content $path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Read-AhkText([string]$path) {
    if (-not (Test-Path $path)) { return "" }
    try { return Get-Content -LiteralPath $path -Raw -Encoding UTF8 } catch { return "" }
}
function Find-MainAhkText([string]$root) {
    foreach ($candidate in (Get-ChildItem -LiteralPath $root -Filter "*.ahk" -File -ErrorAction SilentlyContinue)) {
        try {
            $probe = Get-Content -LiteralPath $candidate.FullName -Raw -Encoding UTF8 -ErrorAction Stop
            if ($probe -match "CommandPaletteCore\.ahk") { return $probe }
        } catch { }
    }
    return ""
}

Write-Host ""
Write-Host "=== CP6 Wails Gray Gate ===" -ForegroundColor Cyan

if ($RevertFlags) {
    if (Test-Path $smokeScript) {
        & $smokeScript -Revert
        exit $LASTEXITCODE
    }
    Write-Host "FAIL: Invoke-Cp6WailsGraySmoke.ps1 missing" -ForegroundColor Red
    exit 1
}

$checks = @()
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

$cp5 = Get-JsonFile $cp5GatePath
$cp5Pass = $cp5 -and [bool]$cp5.overallPass
$checks += @{ name = "cp5_prerequisite"; pass = $cp5Pass; value = $(if ($cp5Pass) { "pass" } else { "missing_or_fail" }) }
if (-not $cp5Pass) { [void]$failures.Add("cp5_modular_shell_gate.json overallPass!=true") }

$cp4 = Get-JsonFile $cp4GatePath
$cp4Pass = $cp4 -and [bool]$cp4.overallPass
$checks += @{ name = "cp4_prerequisite"; pass = $cp4Pass; value = $(if ($cp4Pass) { "pass" } else { "warn" }) }
if (-not $cp4Pass) { [void]$warnings.Add("cp4_agent_transport_hub_gate.json not pass (recommended before CP6 gray)") }

$routerOk = Test-Path $routerPath
$wailsHostOk = Test-Path $wailsHostPath
$wailsAppOk = Test-Path $wailsAppPath
$wailsExeOk = Test-Path $wailsExePath
$checks += @{ name = "module_command_palette_router"; pass = $routerOk; value = $(if ($routerOk) { "ok" } else { "missing" }) }
$checks += @{ name = "module_command_palette_wails_host"; pass = $wailsHostOk; value = $(if ($wailsHostOk) { "ok" } else { "missing" }) }
$checks += @{ name = "wails_app_go"; pass = $wailsAppOk; value = $(if ($wailsAppOk) { "ok" } else { "missing" }) }
$checks += @{ name = "wails_exe_built"; pass = $wailsExeOk; value = $(if ($wailsExeOk) { "ok" } else { "not_built" }) }
if (-not $routerOk) { [void]$failures.Add("CommandPaletteRouter.ahk missing") }
if (-not $wailsHostOk) { [void]$failures.Add("CommandPaletteWailsHost.ahk missing") }
if (-not $wailsAppOk) { [void]$failures.Add("apps/nmer-wails/app.go missing") }
if (-not $wailsExeOk) { [void]$warnings.Add("nmer-wails.exe not built — runtime smoke blocked until wails build") }

$mainText = Find-MainAhkText $repo
$mainIncludesRouter = $mainText -match "CommandPaletteRouter\.ahk"
$mainIncludesWailsHost = $mainText -match "CommandPaletteWailsHost\.ahk"
$checks += @{ name = "main_includes_router"; pass = $mainIncludesRouter; value = $mainIncludesRouter }
$checks += @{ name = "main_includes_wails_host"; pass = $mainIncludesWailsHost; value = $mainIncludesWailsHost }
if (-not $mainIncludesRouter) { [void]$failures.Add("main ahk missing CommandPaletteRouter include") }
if (-not $mainIncludesWailsHost) { [void]$failures.Add("main ahk missing CommandPaletteWailsHost include") }

$exampleHasCpHost = $false
if (Test-Path $exampleFlagsPath) {
    try {
        $ex = Get-Content $exampleFlagsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $exampleHasCpHost = $null -ne $ex.wailsBridge.commandPaletteHost
    } catch { }
}
$checks += @{ name = "example_flags_cp_host"; pass = $exampleHasCpHost; value = $exampleHasCpHost }
if (-not $exampleHasCpHost) { [void]$failures.Add("docs/nmer-flags.example.json missing commandPaletteHost") }

$wailsHostText = Read-AhkText $wailsHostPath
$corePath = Join-Path $repo "modules\CommandPaletteCore.ahk"
$probePath = Join-Path $repo "modules\MultiCardMemoryProbe.ahk"
$coreText = Read-AhkText $corePath
$probeText = Read-AhkText $probePath
$wailsVisibleOk = $wailsHostText -match "CommandPaletteWails_IsVisible" -and $wailsHostText -match "g_CmdPalWails_Visible"
$coreVisibleOk = $coreText -match "CommandPaletteWails_IsVisible"
$probeShowOk = $probeText -match 'case "show_cp"'
$checks += @{ name = "wails_host_visible_state"; pass = $wailsVisibleOk; value = $wailsVisibleOk }
$checks += @{ name = "core_isvisible_wails_delegate"; pass = $coreVisibleOk; value = $coreVisibleOk }
$checks += @{ name = "memory_probe_show_cp"; pass = $probeShowOk; value = $probeShowOk }
if (-not $wailsVisibleOk) { [void]$failures.Add("CommandPaletteWailsHost missing visible state helpers") }
if (-not $coreVisibleOk) { [void]$failures.Add("CommandPalette_IsVisible missing wails delegate") }
if (-not $probeShowOk) { [void]$failures.Add("MultiCardMemoryProbe missing show_cp action") }

$flagsHost = "ahk"
$legacyOn = $true
$wailsBridgeOn = $false
function Read-FlagsState {
    param([string]$Path)
    $cpHost = "ahk"
    $legacy = $true
    $bridgeOn = $false
    if (Test-Path $Path) {
        try {
            $f = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($f.wailsBridge.commandPaletteHost) { $cpHost = [string]$f.wailsBridge.commandPaletteHost }
            if ($null -ne $f.wailsBridge.enabled) { $bridgeOn = [bool]$f.wailsBridge.enabled }
            if ($null -ne $f.rollback.legacySurfaceLifecycle) { $legacy = [bool]$f.rollback.legacySurfaceLifecycle }
        } catch { }
    }
    return @{ host = $cpHost; legacy = $legacy; bridgeOn = $bridgeOn }
}
$flagsState = Read-FlagsState $flagsPath
$flagsHost = $flagsState.host
$legacyOn = $flagsState.legacy
$wailsBridgeOn = $flagsState.bridgeOn

$cpHostEvents = 0
if (Test-Path $surfaceLogPath) {
    $cpHostEvents = @(
        Get-Content $surfaceLogPath -Encoding UTF8 | ForEach-Object {
            try { $_ | ConvertFrom-Json } catch { $null }
        } | Where-Object { $_ -and $_.type -eq "cp_host_show" }
    ).Count
}
$checks += @{ name = "cp_host_show_ndjson_count"; pass = ($cpHostEvents -gt 0); value = $cpHostEvents }

$staticPass = ($failures.Count -eq 0)
$runtimePass = $false
$runtimeDetail = "skipped"
$runtimeMode = "skipped"
$smokeReportPath = Join-Path $dbg "cp6_wails_gray_smoke.json"

if ($WithSmoke) {
    if (-not (Test-Path $smokeScript)) {
        [void]$failures.Add("Invoke-Cp6WailsGraySmoke.ps1 missing")
        $runtimeDetail = "script_missing"
    } elseif ($SkipPrompt -and (Test-Path $liveSmokeScript)) {
        $runtimeMode = "live_automation"
        Write-Host ""
        Write-Host "Runtime: automated live smoke (IPC show_cp)..." -ForegroundColor Cyan
        try {
            & $liveSmokeScript -PollSec 25
            $live = Get-JsonFile $liveSmokeReportPath
            $runtimePass = ($LASTEXITCODE -eq 0) -and $live -and [bool]$live.overallPass -and ([string]$live.freshHost -eq "wails")
            $runtimeDetail = if ($runtimePass) { "live_pass" } else { [string]$live.failReason }
            if (-not $runtimePass) {
                $reason = if ($live -and $live.failReason) { [string]$live.failReason } else { "live_smoke_failed" }
                [void]$failures.Add("cp6_wails_gray_live_smoke: $reason")
            }
            @{
                capturedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                overallPass = [bool]$runtimePass
                failReason = if ($runtimePass) { "" } else { $runtimeDetail }
                counts = @{
                    cp_host_show = if ($live) { [int]$live.afterCount } else { 0 }
                    cp_host_show_wails = if ($runtimePass) { 1 } else { 0 }
                }
                analyzeOnly = $false
                scope = "live_automation"
                liveReport = $liveSmokeReportPath
            } | ConvertTo-Json -Depth 6 | Set-Content -Path $smokeReportPath -Encoding UTF8
        } catch {
            $runtimePass = $false
            $runtimeDetail = $_.Exception.Message
            [void]$failures.Add("cp6 live smoke error: $($_.Exception.Message)")
        }
    } else {
        $runtimeMode = if ($SkipPrompt) { "analyze_only" } else { "manual_prompt" }
        $smokeParams = @{}
        if ($SkipPrompt) { $smokeParams.SkipPrompt = $true }
        if ($cpHostEvents -gt 0 -and $SkipPrompt) { $smokeParams.AnalyzeOnly = $true }
        try {
            & $smokeScript @smokeParams
            $runtimePass = ($LASTEXITCODE -eq 0)
            $runtimeDetail = if ($runtimePass) { "pass" } else { "fail" }
            if (-not $runtimePass) { [void]$failures.Add("cp6_wails_gray_smoke failed") }
        } catch {
            $runtimePass = $false
            $runtimeDetail = $_.Exception.Message
            [void]$failures.Add("cp6 smoke error: $($_.Exception.Message)")
        }
    }
} else {
    if ($cpHostEvents -gt 0) {
        [void]$warnings.Add("cp_host_show present in ndjson; re-run with -WithSmoke -SkipPrompt to certify live")
    }
}

$flagsState = Read-FlagsState $flagsPath
$flagsHost = $flagsState.host
$legacyOn = $flagsState.legacy
$wailsBridgeOn = $flagsState.bridgeOn
$defaultRollbackOk = ($flagsHost -eq "ahk") -and $legacyOn
$checks += @{ name = "default_host_ahk"; pass = $defaultRollbackOk; value = "host=$flagsHost legacy=$legacyOn" }
if (-not $defaultRollbackOk) {
    if ($WithSmoke -and $runtimePass) {
        [void]$failures.Add("live smoke finished but flags not reverted to ahk (host=$flagsHost legacy=$legacyOn)")
    } else {
        [void]$warnings.Add("local/nmer-flags.json not on default ahk rollback (host=$flagsHost legacy=$legacyOn)")
    }
}

$staticPass = ($failures.Count -eq 0)
$overallPass = $staticPass -and ((-not $WithSmoke) -or $runtimePass)
$report = [ordered]@{
    generatedAt   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    phase         = "CP6"
    mode          = if ($WithSmoke) { "wails_gray_static+$runtimeMode" } else { "wails_gray_static" }
    staticPass    = $staticPass
    runtimePass   = if ($WithSmoke) { $runtimePass } else { $null }
    overallPass   = $overallPass
    failReason    = if ($overallPass) { "" } else { ($failures -join "; ") }
    warnings      = @($warnings)
    checks        = $checks
    flagsHost     = $flagsHost
    legacySurfaceLifecycle = $legacyOn
    wailsExeBuilt = $wailsExeOk
    cpHostShowCount = $cpHostEvents
    cp5Gate       = $cp5GatePath
    cp4Gate       = $cp4GatePath
    smokeReport   = $(if (Test-Path $smokeReportPath) { $smokeReportPath } else { "" })
    liveSmokeReport = $(if (Test-Path $liveSmokeReportPath) { $liveSmokeReportPath } else { "" })
    runtimeMode   = $runtimeMode
    nextStep      = if ($overallPass -and $WithSmoke) {
        "CP6 gray certified — rollback drill: .\Run-Cp6WailsGrayGate.ps1 -RevertFlags"
    } elseif ($overallPass) {
        "Automated runtime: .\Run-Cp6WailsGrayGate.ps1 -WithSmoke -SkipPrompt"
    } else {
        "fix failures then re-run Run-Cp6WailsGrayGate.ps1"
    }
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
if ($WithSmoke) {
    $rtColor = if ($runtimePass) { "Green" } else { "Red" }
    Write-Host ("  runtime_smoke ({0}): {1} -> {2}" -f $runtimeMode, $runtimeDetail, $(if ($runtimePass) { "PASS" } else { "FAIL" })) -ForegroundColor $rtColor
}
if ($warnings.Count -gt 0) {
    Write-Host ""
    foreach ($w in $warnings) { Write-Host ("  WARN: {0}" -f $w) -ForegroundColor Yellow }
}
Write-Host ""
Write-Host ("static: {0}" -f $(if ($staticPass) { "PASS" } else { "FAIL" })) -ForegroundColor $(if ($staticPass) { "Green" } else { "Red" })
if ($WithSmoke) {
    Write-Host ("runtime: {0}" -f $(if ($runtimePass) { "PASS" } else { "FAIL" })) -ForegroundColor $(if ($runtimePass) { "Green" } else { "Red" })
}
Write-Host ("overall: {0}" -f $(if ($overallPass) { "PASS" } else { "FAIL" })) -ForegroundColor $(if ($overallPass) { "Green" } else { "Red" })
Write-Host ("report: {0}" -f $gatePath) -ForegroundColor DarkGray
Write-Host ("next: {0}" -f $report.nextStep) -ForegroundColor $(if ($overallPass) { "Green" } else { "DarkGray" })
exit $(if ($overallPass) { 0 } else { 1 })
