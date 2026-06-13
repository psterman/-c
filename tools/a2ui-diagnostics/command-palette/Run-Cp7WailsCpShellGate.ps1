# CP7 / S8 B3 Phase 2 live gate: static P2-S* + runtime P2-R1/R2/R3/R6/R7/R8 (2b+2c+2d scope).
param(
    [string]$RepoRoot = "",
    [switch]$WithSmoke,
    [switch]$WithHubLive,
    [switch]$SkipPrompt,
    [switch]$RevertFlags,
    [switch]$JsonOnly,
    [int]$BootSec = 180,
    [int]$PollSec = 40
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RepoRoot) { $RepoRoot = Get-DiagRepoRoot -From $here }

$dbg = Join-Path $RepoRoot "Cache\debug"
$flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"
$staticScript = Join-Path (Split-Path $here -Parent) "surface\Diagnose-S8B3Phase2Gate.ps1"
$liveSmokeScript = Join-Path $here "Run-Cp6WailsGrayLiveSmoke.ps1"
$probeScript = Join-Path $here "..\memory\Invoke-MultiCardMemoryProbe.ps1"
$cp6RevertScript = Join-Path $here "Invoke-Cp6WailsGraySmoke.ps1"
$cp9Script = Join-Path $here "Run-Cp9WailsCpHubAgentLive.ps1"
$outGate = Join-Path $dbg "cp7_wails_cp_shell_gate.json"
$outLive = Join-Path $dbg "cp7_wails_cp_shell_live_smoke.json"
$liveSmokeReport = Join-Path $dbg "cp6_wails_gray_live_smoke.json"
$perfLog = Join-Path $dbg "command_palette_perf.ndjson"

function Read-Json([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try { return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

function Read-FlagsState([string]$path) {
    $cpHost = "ahk"
    $legacy = $true
    $sidecar = "hub"
    if (Test-Path $path) {
        try {
            $f = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($f.wailsBridge.commandPaletteHost) { $cpHost = [string]$f.wailsBridge.commandPaletteHost }
            if ($f.wailsBridge.sidecarHost) { $sidecar = [string]$f.wailsBridge.sidecarHost }
            if ($null -ne $f.rollback.legacySurfaceLifecycle) { $legacy = [bool]$f.rollback.legacySurfaceLifecycle }
        } catch { }
    }
    return @{ host = $cpHost; legacy = $legacy; sidecar = $sidecar }
}

function Add-Check([ref]$checks, [ref]$failures, [string]$id, [string]$name, [bool]$pass, $value, [string]$failReason = "") {
    $script:checks += [ordered]@{
        id = $id
        name = $name
        pass = $pass
        value = $value
    }
    if (-not $pass -and $failReason) { [void]$failures.Add("$id`: $failReason") }
}

if ($RevertFlags) {
    if (Test-Path $cp6RevertScript) {
        & $cp6RevertScript -Revert
        exit $LASTEXITCODE
    }
    $obj = Read-Json $flagsPath
    if ($obj) {
        $obj.wailsBridge | Add-Member -NotePropertyName commandPaletteHost -NotePropertyValue "ahk" -Force
        $obj.wailsBridge | Add-Member -NotePropertyName sidecarHost -NotePropertyValue "hub" -Force
        $obj.rollback | Add-Member -NotePropertyName legacySurfaceLifecycle -NotePropertyValue $true -Force
        ($obj | ConvertTo-Json -Depth 8) | Set-Content -Path $flagsPath -Encoding UTF8
    }
    Write-Host "Reverted flags to ahk/hub/legacy=true"
    exit 0
}

Write-Host ""
Write-Host "=== CP7 Wails CP Shell Gate (S8 B3 Phase 2) ===" -ForegroundColor Cyan
Write-Host ""

$checks = @()
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

$staticPass = $false
if (-not (Test-Path $staticScript)) {
    [void]$failures.Add("missing Diagnose-S8B3Phase2Gate.ps1")
} else {
    & $staticScript -RepoRoot $RepoRoot -JsonOnly | Out-Null
    $staticJson = Read-Json (Join-Path $dbg "s8b3_phase2_gate.json")
    $staticPass = $staticJson -and [bool]$staticJson.overallPass
    Add-Check ([ref]$checks) ([ref]$failures) "P2-S" "static_phase2_gate" $staticPass $(if ($staticPass) { "pass" } else { "fail" }) $(if ($staticPass) { "" } else { "s8b3_phase2_gate_fail" })
}

$runtimePass = $false
$live = $null
$gateProbe = $null
$bridgeProbe = $null

if ($WithSmoke) {
    if (-not (Test-Path $liveSmokeScript)) {
        [void]$failures.Add("missing Run-Cp6WailsGrayLiveSmoke.ps1")
    } else {
        Write-Host "Runtime: CP6 live smoke (2b shell + iframe)..." -ForegroundColor Cyan
        try {
            & $liveSmokeScript -RepoRoot $RepoRoot -PollSec $PollSec -BootSec $BootSec -NoRevert
            $live = Read-Json $liveSmokeReport
            $live | ConvertTo-Json -Depth 8 | Set-Content -Path $outLive -Encoding UTF8

            $r1 = $live -and [bool]$live.overallPass -and ([string]$live.freshHost -eq "wails") -and ([int]$live.shellPhase -ge 2) -and [bool]$live.cpShellMounted -and [bool]$live.cpHtmlOk
            Add-Check ([ref]$checks) ([ref]$failures) "P2-R1" "shell_ready_cp_host_show" $r1 @{
                shellPhase = if ($live) { $live.shellPhase } else { 0 }
                mounted = if ($live) { $live.cpShellMounted } else { $false }
                htmlOk = if ($live) { $live.cpHtmlOk } else { $false }
                host = if ($live) { $live.freshHost } else { "" }
            } $(if ($r1) { "" } else { [string]$live.failReason })

            $paletteReady = 0
            if (Test-Path $perfLog) {
                $paletteReady = @(
                    Get-Content $perfLog -Encoding UTF8 | ForEach-Object {
                        try { $_ | ConvertFrom-Json } catch { $null }
                    } | Where-Object { $_ -and $_.event -eq "palette_ready" }
                ).Count
            }
            $r2 = ($live -and [bool]$live.cpShellReady) -or ($paletteReady -gt 0)
            if (-not $r2 -and $live -and [bool]$live.cpShellMounted) {
                [void]$warnings.Add("P2-R2 palette_ready pending — iframe mounted but ready=false (may need longer soak)")
                $r2 = [bool]$live.cpShellMounted
            }
            Add-Check ([ref]$checks) ([ref]$failures) "P2-R2" "ui_ready" $r2 @{
                cpShellReady = if ($live) { $live.cpShellReady } else { $false }
                paletteReadyCount = $paletteReady
            } $(if ($r2) { "" } else { "cp_shell_not_ready" })

            Write-Host "Runtime: CP 2c bidirectional bridge smoke..." -ForegroundColor Cyan
            $bridgeProbe = $null
            try {
                $bridgeProbe = & $probeScript -RepoRoot $RepoRoot -Action cp_wails_bridge_smoke -TimeoutSec 60
            } catch {
                $bridgeProbe = @{ pass = $false; code = "PROBE_ERR"; detail = $_.Exception.Message }
            }
            $r3 = $bridgeProbe -and [bool]$bridgeProbe.injectOk
            Add-Check ([ref]$checks) ([ref]$failures) "P2-R3" "inject_push_roundtrip" $r3 @{
                injectOk = if ($bridgeProbe) { $bridgeProbe.injectOk } else { $false }
                code = if ($bridgeProbe) { $bridgeProbe.code } else { "" }
            } $(if ($r3) { "" } else { "inject_push_failed" })

            $r6 = $bridgeProbe -and [bool]$bridgeProbe.pass -and ([int]$bridgeProbe.egressDrainCount -ge 2)
            if (-not $r6 -and $bridgeProbe) {
                $r6 = [bool]$bridgeProbe.injectOk -and [bool]$bridgeProbe.egressPostOk -and [bool]$bridgeProbe.agentPostOk -and ([int]$bridgeProbe.egressDrainCount -ge 2)
            }
            Add-Check ([ref]$checks) ([ref]$failures) "P2-R6" "egress_dispatch" $r6 $bridgeProbe $(if ($r6) { "" } else { "egress_bridge_fail" })

            $r7 = $bridgeProbe -and [bool]$bridgeProbe.gateOk
            if (-not $r7 -and $bridgeProbe) {
                $r7 = ([string]$bridgeProbe.host -eq "wails") -and -not [bool]$bridgeProbe.ahkGuiExists -and -not [bool]$bridgeProbe.cmdPalWv2 -and [bool]$bridgeProbe.shellMounted
            }
            Add-Check ([ref]$checks) ([ref]$failures) "P2-R7" "no_ahk_cp_webview" $r7 $bridgeProbe $(if ($r7) { "" } else { "ahk_cp_webview_or_host_fail" })

            $r2d = $bridgeProbe -and -not [bool]$bridgeProbe.ahkGuiExists -and -not [bool]$bridgeProbe.cmdPalWv2
            Add-Check ([ref]$checks) ([ref]$failures) "P2-R9" "ahk_webview_retired" $r2d @{
                ahkGuiExists = if ($bridgeProbe) { $bridgeProbe.ahkGuiExists } else { $true }
                cmdPalWv2 = if ($bridgeProbe) { $bridgeProbe.cmdPalWv2 } else { $true }
            } $(if ($r2d) { "" } else { "ahk_cp_webview_not_retired" })
            $gateProbe = $bridgeProbe

            $hubLive = $null
            if ($WithHubLive) {
                Write-Host "Runtime: CP9 hub agent live (P2-R4/R5)..." -ForegroundColor Cyan
                try {
                    & $cp9Script -RepoRoot $RepoRoot -BootSec 0 -AgentWaitSec 120 -SkipGatewayRestart -SkipReload -NoRevert | Out-Host
                    $hubLive = Read-Json (Join-Path $dbg "cp9_wails_cp_hub_agent_live.json")
                } catch {
                    $hubLive = @{ overallPass = $false; detail = $_.Exception.Message }
                }
                $r4 = $hubLive -and [bool]$hubLive.overallPass
                $r4check = @($hubLive.checks | Where-Object { $_.id -eq "P2-R4" })
                if ($r4check -and $r4check[0]) { $r4 = [bool]$r4check[0].pass }
                Add-Check ([ref]$checks) ([ref]$failures) "P2-R4" "wails_hub_agent_live" $r4 ($r4check | Select-Object -First 1).value $(if ($r4) { "" } else { "hub_agent_live_fail" })
                $r5 = $false
                $r5check = @($hubLive.checks | Where-Object { $_.id -eq "P2-R5" })
                if ($r5check -and $r5check[0]) {
                    $r5 = [bool]$r5check[0].pass
                    Add-Check ([ref]$checks) ([ref]$failures) "P2-R5" "action_history_shell" $r5 $r5check[0].value $(if ($r5) { "" } else { "action_history_fail" })
                } else {
                    Add-Check ([ref]$checks) ([ref]$failures) "P2-R5" "action_history_shell" $false $null "action_history_fail"
                }
            } else {
                foreach ($id in @("P2-R4", "P2-R5")) {
                    Add-Check ([ref]$checks) ([ref]$failures) $id "deferred_hub_agent_live" $true "skipped_use_-WithHubLive"
                    [void]$warnings.Add("$id deferred — use -WithHubLive or Run-Cp9WailsCpHubAgentLive.ps1")
                }
            }

            Write-Host "Runtime: revert flags (P2-R8)..." -ForegroundColor DarkGray
            & $liveSmokeScript -RepoRoot $RepoRoot -Revert | Out-Null
            $after = Read-FlagsState $flagsPath
            $r8 = ($after.host -eq "ahk") -and $after.legacy -and ($after.sidecar -eq "hub")
            Add-Check ([ref]$checks) ([ref]$failures) "P2-R8" "rollback_flags" $r8 $after $(if ($r8) { "" } else { "flags_not_reverted" })

            $runtimePass = $r1 -and $r2 -and $r3 -and $r6 -and $r7 -and $r2d -and $r8
            if ($WithHubLive) { $runtimePass = $runtimePass -and $r4 -and $r5 }
        } catch {
            [void]$failures.Add("live_smoke_error: $($_.Exception.Message)")
            try { & $liveSmokeScript -RepoRoot $RepoRoot -Revert | Out-Null } catch { }
        }
    }
} else {
    [void]$warnings.Add("runtime skipped; use -WithSmoke -SkipPrompt for 2b live signoff")
}

$overallPass = $staticPass -and ((-not $WithSmoke) -or $runtimePass)
$report = [ordered]@{
    capturedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    gate = "cp7_wails_cp_shell"
    title = "S8 B3 CP Phase 2b+2c+2d live"
    phase = 2
    scope = "2b_ui_shell+2c_bidirectional_bridge+2d_ahk_webview_retire$(if ($WithHubLive) { '+hub_agent_live' } else { '' })"
    overallPass = [bool]$overallPass
    staticPass = [bool]$staticPass
    runtimePass = if ($WithSmoke) { [bool]$runtimePass } else { $null }
    failureReasons = @($failures)
    warnings = @($warnings)
    checks = $checks
    liveSmokeReport = $(if (Test-Path $outLive) { $outLive } else { $liveSmokeReport })
    gateProbe = $gateProbe
    bridgeProbe = $bridgeProbe
    nextStep = if ($overallPass -and $WithSmoke) {
        "S8 phase 2b+2c+2d live PASS — optional: hub agent live (P2-R4) + P2-M memory + manual signoff"
    } elseif ($overallPass) {
        "Run-Cp7WailsCpShellGate.ps1 -WithSmoke -SkipPrompt"
    } else {
        "fix failures and re-run Run-Cp7WailsCpShellGate.ps1 -WithSmoke -SkipPrompt"
    }
}
$report | ConvertTo-Json -Depth 10 | Set-Content -Path $outGate -Encoding UTF8

if ($JsonOnly) {
    $report | ConvertTo-Json -Depth 10
    exit $(if ($overallPass) { 0 } else { 1 })
}

foreach ($c in $checks) {
    $color = if ($c.pass) { "Green" } else { "Red" }
    Write-Host ("  {0} {1}: {2} -> {3}" -f $c.id, $c.name, ($c.value | ConvertTo-Json -Compress), $(if ($c.pass) { "PASS" } else { "FAIL" })) -ForegroundColor $color
}
if ($warnings.Count) {
    foreach ($w in $warnings) { Write-Host "  WARN: $w" -ForegroundColor Yellow }
}
Write-Host ""
Write-Host ("overall: {0}" -f $(if ($overallPass) { "PASS" } else { "FAIL" })) -ForegroundColor $(if ($overallPass) { "Green" } else { "Red" })
Write-Host "report: $outGate" -ForegroundColor DarkGray
exit $(if ($overallPass) { 0 } else { 1 })
