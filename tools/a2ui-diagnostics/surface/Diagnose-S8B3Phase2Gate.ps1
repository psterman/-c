# S8 B3 Phase 2 — CommandPalette Wails shell static gate (scaffold)
param(
    [string]$RepoRoot = "",
    [switch]$WithFixtures,
    [switch]$JsonOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}

$shellGo = Join-Path $RepoRoot "apps\nmer-wails\poc\shell_cp.go"
$cpShellTs = Join-Path $RepoRoot "apps\nmer-wails\frontend\src\cp-shell\cp-shell-host.ts"
$wailsMainTs = Join-Path $RepoRoot "apps\nmer-wails\frontend\src\main.ts"
$bridgeAhk = Join-Path $RepoRoot "modules\NmerWailsBridge.ahk"
$wailsHostPath = Join-Path $RepoRoot "modules\CommandPaletteWailsHost.ahk"
$cmdPalPath = Join-Path $RepoRoot "modules\CommandPaletteCore.ahk"
$cp5GatePath = Join-Path $RepoRoot "Cache\debug\cp5_modular_shell_gate.json"
$cp6GatePath = Join-Path $RepoRoot "Cache\debug\cp6_wails_gray_gate.json"
$fixturesScript = Join-Path $RepoRoot "html\run-palette-fixtures.mjs"
$outTxt = Join-Path $RepoRoot "Cache\debug\s8b3_phase2_gate_diagnosis.txt"
$outJson = Join-Path $RepoRoot "Cache\debug\s8b3_phase2_gate.json"

function Read-Text([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return "" }
    try { return Get-Content -LiteralPath $path -Raw -Encoding UTF8 } catch { return "" }
}

function Get-GatePass([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    try {
        $j = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        return [bool]$j.overallPass
    } catch { return $false }
}

$null = New-Item -ItemType Directory -Force -Path (Split-Path $outTxt) | Out-Null

$failureReasons = New-Object System.Collections.Generic.List[string]
$checks = @()

function Add-Check([string]$id, [string]$name, [bool]$pass, $value, [string]$failReason = "") {
    $script:checks += [ordered]@{
        id = $id
        name = $name
        pass = $pass
        value = $value
    }
    if (-not $pass -and $failReason) {
        [void]$script:failureReasons.Add($failReason)
    }
}

$shellGoText = Read-Text $shellGo
$cpShellTsText = Read-Text $cpShellTs
$mainTsText = Read-Text $wailsMainTs
$bridgeText = Read-Text $bridgeAhk
$wailsHostText = Read-Text $wailsHostPath
$cmdPalText = Read-Text $cmdPalPath

# P2-S1: Go shell CP API
$shellGoPresent = Test-Path -LiteralPath $shellGo
$shellGoInject = $shellGoText -match '/shell/cp/inject'
$shellGoDrain = $shellGoText -match '/shell/cp/inject/drain'
$shellGoEgress = $shellGoText -match '/shell/cp/egress'
$p2s1 = $shellGoPresent -and $shellGoInject -and $shellGoDrain -and $shellGoEgress
Add-Check "P2-S1" "shell_cp_go_api" $p2s1 @{
    present = $shellGoPresent
    inject = $shellGoInject
    drain = $shellGoDrain
    egress = $shellGoEgress
} "shell_cp_go_missing_or_incomplete"

# P2-S2: Wails frontend CP shell host
$cpShellTsPresent = Test-Path -LiteralPath $cpShellTs
$mainUsesCpShell = ($mainTsText -match 'nmer-cp-shell-host') -and ($mainTsText -match 'shell:cp')
$p2s2 = $cpShellTsPresent -and $mainUsesCpShell
Add-Check "P2-S2" "wails_cp_shell_host" $p2s2 @{
    cp_shell_host_ts = $cpShellTsPresent
    main_ts_listener = $mainUsesCpShell
} "wails_cp_shell_host_missing"

# P2-S3: AHK bridge + WailsHost shell mount
$bridgeCpInject = $bridgeText -match 'Nmer_WailsBridgePostShellCpInject|/shell/cp/inject'
$bridgeCpEgress = $bridgeText -match 'Nmer_WailsBridgeDrainShellCpEgress|/shell/cp/egress'
$wailsHostShellMount = $wailsHostText -match 'Nmer_WailsBridgePostShellCp|CommandPaletteWails_.*Shell|cp_shell'
$p2s3 = $bridgeCpInject -and $bridgeCpEgress -and $wailsHostShellMount
Add-Check "P2-S3" "ahk_cp_shell_bridge" $p2s3 @{
    bridge_inject = $bridgeCpInject
    bridge_egress = $bridgeCpEgress
    wails_host_mount = $wailsHostShellMount
} "ahk_cp_shell_bridge_missing"

# P2-S4: PushToWeb wails route (no hard dependency on g_CmdPal_WV2 when host=wails)
$pushWailsRoute = ($cmdPalText -match 'CommandPalette_PushToWebWails|CommandPalette_WailsPushToWeb') `
    -or ($cmdPalText -match 'Nmer_CommandPaletteHost' -and $cmdPalText -match 'CommandPalette_PushToWeb' -and $cmdPalText -match 'Nmer_WailsBridgePostShellCp')
$p2s4 = [bool]$pushWailsRoute
Add-Check "P2-S4" "push_to_web_wails_route" $p2s4 $pushWailsRoute "push_to_web_still_wv2_only"

# P2-S5: AHK CP WebView retire guard
$ahkRetireGuard = ($cmdPalText -match 'CommandPalette_AhkWebViewEnabled') `
    -and ($cmdPalText -match 'CommandPalette_DisposeAhkWebViewIfRetired') `
    -and ($wailsHostText -match 'CommandPaletteWails_RetireAhkWebView')
$p2s5 = [bool]$ahkRetireGuard
Add-Check "P2-S5" "ahk_cp_webview_retire_guard" $p2s5 @{
    ahk_webview_enabled = ($cmdPalText -match 'CommandPalette_AhkWebViewEnabled')
    dispose_if_retired = ($cmdPalText -match 'CommandPalette_DisposeAhkWebViewIfRetired')
    wails_retire_hook = ($wailsHostText -match 'CommandPaletteWails_RetireAhkWebView')
} "ahk_cp_webview_retire_guard_missing"

# P2-S8: CP shell egress pump (2c bidirectional bridge)
$egressPump = ($wailsHostText -match 'CommandPaletteWails_EnsureEgressPump') `
    -and ($wailsHostText -match 'CommandPaletteWails_EgressPumpTick') `
    -and ($wailsHostText -match 'CommandPaletteWails_HandleEgressPayload') `
    -and ($bridgeText -match 'Nmer_WailsBridgeDrainShellCpEgress')
$p2s8 = [bool]$egressPump
Add-Check "P2-S8" "cp_shell_egress_pump" $p2s8 $egressPump "cp_shell_egress_pump_missing"

# P2-S6: CP5 + CP6 prerequisites
$cp5Pass = Get-GatePass $cp5GatePath
$cp6Pass = Get-GatePass $cp6GatePath
$p2s6 = $cp5Pass -and $cp6Pass
Add-Check "P2-S6" "cp5_cp6_prerequisite" $p2s6 @{
    cp5 = $(if ($cp5Pass) { "pass" } else { "fail" })
    cp6 = $(if ($cp6Pass) { "pass" } else { "fail" })
} "cp5_or_cp6_prerequisite_fail"

# P2-S7: palette fixtures (optional unless -WithFixtures)
$fixturesPass = $null
$fixturesRan = $false
if ($WithFixtures) {
    $fixturesRan = $true
    if (-not (Test-Path -LiteralPath $fixturesScript)) {
        $fixturesPass = $false
        [void]$failureReasons.Add("palette_fixtures_script_missing")
    } else {
        $node = Get-Command node -ErrorAction SilentlyContinue
        if (-not $node) {
            $fixturesPass = $false
            [void]$failureReasons.Add("node_missing_for_fixtures")
        } else {
            Push-Location (Join-Path $RepoRoot "html")
            try {
                & node "run-palette-fixtures.mjs" 2>&1 | Out-Null
                $fixturesPass = ($LASTEXITCODE -eq 0)
                if (-not $fixturesPass) { [void]$failureReasons.Add("palette_fixtures_fail") }
            } finally {
                Pop-Location
            }
        }
    }
    Add-Check "P2-S7" "palette_fixtures" ([bool]$fixturesPass) @{
        ran = $true
        pass = $fixturesPass
    } $(if ($fixturesPass) { "" } else { "palette_fixtures_fail" })
} else {
    Add-Check "P2-S7" "palette_fixtures" $true "skipped_use_-WithFixtures"
}

$overallPass = ($failureReasons.Count -eq 0)

$lines = @(
    "S8 B3 Phase 2 Gate Diagnosis"
    "capturedAt=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    ""
    "phase2Gate:"
    "overall_pass=$overallPass"
    "checks=$($checks.Count)"
    "fixtures_ran=$fixturesRan"
)
if ($failureReasons.Count) {
    $lines += "failure_reasons=$($failureReasons -join ',')"
}
$lines | Set-Content -Path $outTxt -Encoding UTF8

$report = [ordered]@{
    capturedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    gate = "s8b3_phase2"
    title = "S8 B3 CP Phase 2"
    phase = 2
    overallPass = [bool]$overallPass
    s8b3_phase2_gate_pass = [bool]$overallPass
    failureReasons = @($failureReasons)
    checks = $checks
    fixturesRan = $fixturesRan
    fixturesPass = $fixturesPass
    prerequisites = @{
        cp5 = $cp5GatePath
        cp6 = $cp6GatePath
        cp5Pass = $cp5Pass
        cp6Pass = $cp6Pass
    }
    nextStep = if ($overallPass) {
        "Run-Cp7WailsCpShellGate.ps1 -WithSmoke -SkipPrompt"
    } else {
        "implement phase 2a-2d wiring then re-run Diagnose-S8B3Phase2Gate.ps1"
    }
}
$report | ConvertTo-Json -Depth 8 | Set-Content -Path $outJson -Encoding UTF8

if ($JsonOnly) {
    $report | ConvertTo-Json -Depth 8
    exit $(if ($overallPass) { 0 } else { 1 })
}

Write-Host ""
Write-Host "=== S8 B3 Phase 2 static gate ===" -ForegroundColor Cyan
foreach ($c in $checks) {
    $color = if ($c.pass) { "Green" } else { "Red" }
    $val = if ($c.value -is [hashtable] -or $c.value -is [System.Collections.Specialized.OrderedDictionary]) {
        ($c.value.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value }) -join " "
    } else {
        [string]$c.value
    }
    Write-Host ("  {0} {1}: {2} -> {3}" -f $c.id, $c.name, $val, $(if ($c.pass) { "PASS" } else { "FAIL" })) -ForegroundColor $color
}
Write-Host ""
Write-Host ("overall: {0}" -f $(if ($overallPass) { "PASS" } else { "FAIL" })) -ForegroundColor $(if ($overallPass) { "Green" } else { "Red" })
if ($failureReasons.Count) {
    Write-Host ("reasons: {0}" -f ($failureReasons -join ", ")) -ForegroundColor Yellow
}
Write-Host ("txt: {0}" -f $outTxt) -ForegroundColor DarkGray
Write-Host ("json: {0}" -f $outJson) -ForegroundColor DarkGray
Write-Host ("next: {0}" -f $report.nextStep) -ForegroundColor DarkGray
exit $(if ($overallPass) { 0 } else { 1 })
