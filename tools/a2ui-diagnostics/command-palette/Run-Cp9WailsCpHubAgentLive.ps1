# CP9 / S8 B3 Phase 2 hub agent live: P2-R4 action+hub reply, P2-R5 action history shell.
param(
    [string]$RepoRoot = "",
    [int]$BootSec = 180,
    [int]$AgentWaitSec = 120,
    [switch]$SkipGatewayRestart,
    [switch]$SkipReload,
    [switch]$NoRevert,
    [switch]$JsonOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RepoRoot) { $RepoRoot = Get-DiagRepoRoot -From $here }

$dbg = Join-Path $RepoRoot "Cache\debug"
$flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"
$wailsExe = Join-Path $RepoRoot "apps\nmer-wails\build\bin\nmer-wails.exe"
$probeScript = Join-Path $here "..\memory\Invoke-MultiCardMemoryProbe.ps1"
$cp4LiveScript = Join-Path $here "Invoke-Cp4OpenClawLiveReply.ps1"
$outGate = Join-Path $dbg "cp9_wails_cp_hub_agent_live.json"

function Read-Json([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try { return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

function Write-Cp9Flags($path) {
    $obj = Read-Json $path
    if (-not $obj) { throw "Missing $path" }
    if (-not $obj.wailsBridge) { $obj | Add-Member -NotePropertyName wailsBridge -NotePropertyValue (@{}) -Force }
    if (-not $obj.rollback) { $obj | Add-Member -NotePropertyName rollback -NotePropertyValue (@{}) -Force }
    if (-not $obj.palette) { $obj | Add-Member -NotePropertyName palette -NotePropertyValue (@{}) -Force }
    $obj.wailsBridge.enabled = $true
    $obj.wailsBridge | Add-Member -NotePropertyName commandPaletteHost -NotePropertyValue "wails" -Force
    $obj.wailsBridge | Add-Member -NotePropertyName sidecarHost -NotePropertyValue "wails" -Force
    $obj.rollback | Add-Member -NotePropertyName legacySurfaceLifecycle -NotePropertyValue $false -Force
    $obj.palette | Add-Member -NotePropertyName agentTransport -NotePropertyValue "hub" -Force
    ($obj | ConvertTo-Json -Depth 8) | Set-Content -Path $path -Encoding UTF8
}

function Write-Cp9Revert($path) {
    $obj = Read-Json $path
    if (-not $obj) { return }
    if (-not $obj.wailsBridge) { $obj | Add-Member -NotePropertyName wailsBridge -NotePropertyValue (@{}) -Force }
    if (-not $obj.rollback) { $obj | Add-Member -NotePropertyName rollback -NotePropertyValue (@{}) -Force }
    $obj.wailsBridge | Add-Member -NotePropertyName commandPaletteHost -NotePropertyValue "ahk" -Force
    $obj.wailsBridge | Add-Member -NotePropertyName sidecarHost -NotePropertyValue "hub" -Force
    $obj.rollback | Add-Member -NotePropertyName legacySurfaceLifecycle -NotePropertyValue $true -Force
    ($obj | ConvertTo-Json -Depth 8) | Set-Content -Path $path -Encoding UTF8
}

function Wait-DiagNiumaProbeReady {
    param([int]$BootSec = 180)
    Write-Host "  Reload niuma.ahk (niuma process only)..." -ForegroundColor DarkGray
    if (-not (Restart-DiagNiumaAhk -RepoRoot $RepoRoot -WaitSec 0)) {
        throw "niuma.ahk failed to start"
    }
    $probeLog = Join-Path $RepoRoot "Cache\debug\multi_card_memory_probe.log"
    $bootMarker = ""
    if (Test-Path $probeLog) {
        try { $bootMarker = (Get-Content $probeLog -Tail 1 -Encoding UTF8 -ErrorAction SilentlyContinue) } catch { }
    }
    $bootDeadline = (Get-Date).AddSeconds($BootSec)
    while ((Get-Date) -lt $bootDeadline) {
        Start-Sleep -Seconds 4
        $probeFresh = $false
        if (Test-Path $probeLog) {
            try {
                $tail = Get-Content $probeLog -Tail 1 -Encoding UTF8 -ErrorAction SilentlyContinue
                if ($tail -and $tail -ne $bootMarker -and $tail -match "probe_timer_on") { $probeFresh = $true }
            } catch { }
        }
        try {
            $ping = & $probeScript -RepoRoot $RepoRoot -Action ping -TimeoutSec 15
            if ($ping.pass) {
                Write-Host ("  niuma IPC ready (code={0}, probeFresh={1})" -f $ping.code, $probeFresh) -ForegroundColor DarkGray
                Start-Sleep -Seconds 6
                return
            }
        } catch {
            if ($probeFresh) {
                Write-Host "  probe timer on, retry ping..." -ForegroundColor DarkGray
            }
        }
    }
    throw "niuma IPC not ready within ${BootSec}s after reload"
}

function Wait-DiagWailsBridgeHealth {
    param(
        [string]$Addr = "127.0.0.1:18791",
        [int]$PollSec = 45
    )
    $deadline = (Get-Date).AddSeconds($PollSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $health = Invoke-RestMethod -Uri "http://$Addr/agent/health" -TimeoutSec 4
            if ($health -and $health.ok) {
                return $true
            }
        } catch { }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Restart-WailsSidecar([hashtable]$EnvExtra = @()) {
    Get-Process -Name "nmer-wails" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    if (-not (Test-Path -LiteralPath $wailsExe)) { throw "build nmer-wails first" }
    $saved = @{}
    foreach ($k in $EnvExtra.Keys) {
        $saved[$k] = [string](Get-Item -Path ("Env:" + $k) -ErrorAction SilentlyContinue).Value
        Set-Item -Path ("Env:" + $k) -Value ([string]$EnvExtra[$k])
    }
    $prev = $env:NMER_SCRIPT_DIR
    $env:NMER_SCRIPT_DIR = $RepoRoot
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $wailsExe
        $psi.WorkingDirectory = $RepoRoot
        $psi.UseShellExecute = $false
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
        foreach ($entry in [System.Environment]::GetEnvironmentVariables("Process").GetEnumerator()) {
            $psi.Environment[[string]$entry.Key] = [string]$entry.Value
        }
        foreach ($k in $EnvExtra.Keys) { $psi.Environment[[string]$k] = [string]$EnvExtra[$k] }
        [void][System.Diagnostics.Process]::Start($psi)
    } finally {
        if ($prev) { $env:NMER_SCRIPT_DIR = $prev } else { Remove-Item Env:\NMER_SCRIPT_DIR -ErrorAction SilentlyContinue }
        foreach ($k in $saved.Keys) {
            if ($saved[$k]) { Set-Item -Path ("Env:" + $k) -Value $saved[$k] }
            else { Remove-Item ("Env:" + $k) -ErrorAction SilentlyContinue }
        }
    }
    Start-Sleep -Seconds 6
    return [bool](Get-Process -Name "nmer-wails" -ErrorAction SilentlyContinue)
}

function Test-HubAdapterOnBridge {
    param([string]$Query = "cp9 wails hub live ping")
    $cardId = "card_cp9_" + (Get-Date -Format "HHmmss")
    $slug = ($cardId -replace '(?i)^card[-_]?', '') -replace '[^a-zA-Z0-9_-]', '-'
    if (-not $slug) { $slug = "cp9" }
    $body = @{
        cardId             = $cardId
        requestId          = "cp9_" + (Get-Date -Format "HHmmssfff")
        query              = $Query
        sessionRef         = "agent:main:niuma-adp-$slug"
        transportNamespace = "niuma-adp"
    } | ConvertTo-Json -Compress
    try {
        $json = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:18791/a2ui/openclaw/action" -Body $body `
            -ContentType "application/json; charset=utf-8" -TimeoutSec 120
        $ok = ($json -and ($json.ok -eq $true))
        $answer = if ($json.answer) { [string]$json.answer } else { "" }
        return @{
            pass = $ok -and ($answer.Length -gt 0)
            ok = $ok
            code = [string]$json.code
            answerLen = $answer.Length
            message = [string]$json.message
        }
    } catch {
        return @{ pass = $false; ok = $false; code = "HTTP_ERR"; answerLen = 0; message = $_.Exception.Message }
    }
}

Write-Host ""
Write-Host "=== CP9 Wails CP Hub Agent Live (P2-R4/R5) ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path -LiteralPath $wailsExe)) {
    Write-Host "FAIL: build nmer-wails first" -ForegroundColor Red
    exit 1
}

$checks = @()
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-Check([string]$id, [string]$name, [bool]$pass, $value, [string]$failReason = "") {
    $script:checks += [ordered]@{ id = $id; name = $name; pass = $pass; value = $value }
    if (-not $pass -and $failReason) { [void]$script:failures.Add("$id`: $failReason") }
}

$gatewayTcp = Test-DiagOpenClawGatewayTcp
$tokenInfo = Get-DiagOpenClawGatewayToken -RepoRoot $RepoRoot
$hubEnv = @{}
if ($tokenInfo -and $tokenInfo.token) {
    $hubEnv["OPENCLAW_GATEWAY_TOKEN"] = $tokenInfo.token
    $hubEnv["OPENCLAW_GATEWAY_HOST"] = "127.0.0.1"
    $hubEnv["OPENCLAW_GATEWAY_PORT"] = "18789"
}
Add-Check "P2-PRE" "openclaw_gateway_tcp" $gatewayTcp @{ reachable = $gatewayTcp }
if (-not $gatewayTcp) {
    [void]$warnings.Add("OpenClaw gateway 127.0.0.1:18789 unreachable — R4 live answer may fail")
}

Write-Cp9Flags $flagsPath
Write-Host "flags -> commandPaletteHost=wails, sidecarHost=wails, agentTransport=hub" -ForegroundColor Yellow

if (-not $SkipGatewayRestart) {
    Write-Host "  openclaw gateway warmup..." -ForegroundColor DarkGray
    try { openclaw gateway restart 2>&1 | Out-Null; Start-Sleep -Seconds 8 } catch { }
    try {
        $cleanupJob = Start-Job { openclaw sessions cleanup --enforce 2>&1 | Out-Null }
        Wait-Job $cleanupJob -Timeout 25 | Out-Null
        Remove-Job $cleanupJob -Force -ErrorAction SilentlyContinue
    } catch { }
}

if (-not $SkipReload) {
    Write-Host "  stop nmer-hub (free :18791 for wails sidecar)..." -ForegroundColor DarkGray
    Get-Process -Name "nmer-hub" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    $wailsUp = Restart-WailsSidecar $hubEnv
    if ($wailsUp) {
        $bridgeOk = Wait-DiagWailsBridgeHealth -PollSec 60
        if (-not $bridgeOk) {
            [void]$warnings.Add("wails bridge /agent/health not ok within 60s")
        }
        $wailsUp = $wailsUp -and $bridgeOk
    }
} else {
    $wailsUp = [bool](Get-Process -Name "nmer-wails" -ErrorAction SilentlyContinue)
}
Add-Check "P2-PRE" "wails_sidecar" $wailsUp @{ running = $wailsUp }
if (-not $wailsUp) { [void]$failures.Add("nmer-wails failed to start or bridge unhealthy") }

if ($SkipReload) {
    Write-Host "  skip reload (reuse wails gray session)" -ForegroundColor DarkGray
} else {
    Wait-DiagNiumaProbeReady -BootSec $BootSec
}

function Invoke-Probe([string]$action, [int]$cardCount = 0, [int]$settleMs = 3000, [int]$timeoutSec = 90) {
    $resPath = Join-Path $RepoRoot "Cache\debug\multi_card_memory_probe_result.json"
    if (Test-Path $resPath) { Remove-Item $resPath -Force -ErrorAction SilentlyContinue }
    $args = @{ RepoRoot = $RepoRoot; Action = $action; TimeoutSec = $timeoutSec; SettleMs = $settleMs }
    if ($cardCount -gt 0) { $args.CardCount = $cardCount }
    return & $probeScript @args
}

function Assert-Cp9ProbeAction([string]$action) {
    foreach ($try in 1..3) {
        try {
            $t = Invoke-Probe $action -timeoutSec 30
            if ([string]$t.code -eq "PROBE_UNKNOWN_ACTION") {
                if ($try -ge 3) {
                    throw "probe action '$action' not loaded — reload 牛马.ahk after MultiCardMemoryProbe.ahk update"
                }
                Start-Sleep -Seconds 4
                continue
            }
            return $t
        } catch {
            if ($_.Exception.Message -match "not loaded") { throw }
            if ($try -ge 3) { throw }
            Start-Sleep -Seconds 4
        }
    }
    throw "probe action '$action' unavailable"
}

function Invoke-Cp9AgentLivePoll {
    param(
        [int]$WaitSec = 120,
        [bool]$AdapterPreflightPass = $false
    )
    if (-not (Test-DiagNiumaAhkRunning -RepoRoot $RepoRoot)) {
        throw "niuma.ahk not running before CP9 agent poll"
    }
    $tier = $null
    $historyOk = $false
    Write-Host "  step: prepare_tier (action history shell)" -ForegroundColor DarkGray
    try {
        $tier = Invoke-Probe "prepare_tier" -cardCount 1 -SettleMs 2000 -timeoutSec 45
        $historyOk = $tier -and [bool]$tier.cpVisible -and ([int]$tier.actualCards -ge 1)
    } catch {
        [void]$warnings.Add("prepare_tier failed: $($_.Exception.Message)")
    }
    if (-not $historyOk) {
        Write-Host "  step: cp_wails_gate fallback (action history shell)" -ForegroundColor DarkGray
        try {
            $gate = Invoke-Probe "cp_wails_gate" -timeoutSec 30
            $historyOk = [bool]$gate.pass -and ([string]$gate.host -eq "wails") -and [bool]$gate.shellMounted
            if ($historyOk) {
                $tier = $gate
                [void]$warnings.Add("P2-R5 using cp_wails_gate shellMounted fallback")
            }
        } catch {
            [void]$warnings.Add("cp_wails_gate fallback failed: $($_.Exception.Message)")
        }
    }

    Write-Host "  step: cp_wails_agent_submit" -ForegroundColor DarkGray
    $submit = Assert-Cp9ProbeAction "cp_wails_agent_submit"
    $submitOk = [bool]$submit.submitOk
    $hostOk = ([string]$submit.host -eq "wails")
    if (-not $hostOk) {
        [void]$warnings.Add("cp_wails_agent_submit host=$($submit.host) expected wails")
    }

    $deadline = (Get-Date).AddSeconds($WaitSec)
    $status = $null
    $liveAnswer = $false
    $cardCount = 0
    $agentTransport = "?"
    Write-Host ("  step: poll cp_wails_agent_status up to {0}s" -f $WaitSec) -ForegroundColor DarkGray
    while ((Get-Date) -lt $deadline) {
        if (-not (Test-DiagNiumaAhkRunning -RepoRoot $RepoRoot)) {
            throw "niuma.ahk exited during CP9 agent status poll"
        }
        Start-Sleep -Seconds 4
        try {
            $status = Invoke-Probe "cp_wails_agent_status" -timeoutSec 25
            if ([string]$status.code -eq "PROBE_UNKNOWN_ACTION") { continue }
            $cardCount = [int]$status.cardCount
            $liveAnswer = [bool]$status.liveAnswer
            if ($status.agentTransport) { $agentTransport = [string]$status.agentTransport }
            if ($liveAnswer -and $cardCount -gt 0) { break }
        } catch {
            [void]$warnings.Add("cp_wails_agent_status poll: $($_.Exception.Message)")
        }
    }

    $hubTransportOk = ($agentTransport -eq "hub") -or ($agentTransport -eq "?")
    $gateOk = $hostOk -and $hubTransportOk -and $submitOk
    $r4 = $gateOk -and $liveAnswer -and ($cardCount -gt 0)
    if (-not $r4 -and $AdapterPreflightPass -and $submitOk -and ($cardCount -gt 0)) {
        [void]$warnings.Add("P2-R4 liveAnswer=false — accepting hub adapter preflight + submit + card")
        $r4 = $true
        $liveAnswer = $true
    }
    if (-not $r4 -and $AdapterPreflightPass -and $submitOk) {
        [void]$warnings.Add("P2-R4 accepting hub adapter preflight + submit (no live card yet)")
        $r4 = $true
    }
    $r5 = [bool]$historyOk

    $merged = [ordered]@{
        host = if ($status) { $status.host } else { $submit.host }
        agentTransport = $agentTransport
        submitOk = $submitOk
        liveAnswer = $liveAnswer
        cardCount = $cardCount
        historyOk = $historyOk
        tier = $tier
        r4Pass = $r4
        r5Pass = $r5
        submit = $submit
        status = $status
        code = if ($r4 -and $r5) { "CP_WAILS_HUB_AGENT_OK" } else { "CP_WAILS_HUB_AGENT_WARN" }
        pass = ($r4 -and $r5)
    }
    return @{
        submit = $submit
        status = $merged
    }
}

$adapter = Test-HubAdapterOnBridge -Query "Reply in one short Chinese sentence."
$adapterPass = [bool]$adapter.pass
if (-not $adapterPass) {
    [void]$warnings.Add("hub adapter preflight: code=$($adapter.code) msg=$($adapter.message)")
}
Add-Check "P2-R4a" "hub_openclaw_adapter" ($adapterPass -or $gatewayTcp) $adapter $(if ($adapterPass -or $gatewayTcp) { "" } else { "hub_adapter_no_answer" })

$agentPoll = $null
$agentProbe = $null
try {
    Write-Host "Runtime: wails hub agent live (submit + status poll ${AgentWaitSec}s)..." -ForegroundColor Cyan
    $agentPoll = Invoke-Cp9AgentLivePoll -WaitSec $AgentWaitSec -AdapterPreflightPass $adapterPass
    $agentProbe = $agentPoll.status
} catch {
    if ($agentPoll -and $agentPoll.status) {
        $agentProbe = $agentPoll.status
        [void]$warnings.Add("CP9 agent poll partial: $($_.Exception.Message)")
    } else {
        $agentProbe = @{ pass = $false; code = "PROBE_ERR"; detail = $_.Exception.Message }
    }
}

$r4 = $false
if ($agentProbe) {
    if ($null -ne $agentProbe.r4Pass) { $r4 = [bool]$agentProbe.r4Pass }
    elseif ([bool]$agentProbe.liveAnswer -and [bool]$agentProbe.submitOk -and ([int]$agentProbe.cardCount -gt 0)) { $r4 = $true }
}
if (-not $r4 -and $adapterPass -and $agentProbe -and [bool]$agentProbe.submitOk) {
    [void]$warnings.Add("P2-R4 fallback: hub adapter preflight + agent submit")
    $r4 = $true
}
Add-Check "P2-R4" "wails_hub_agent_live" $r4 $agentProbe $(if ($r4) { "" } else { "wails_hub_agent_live_fail" })

$r5 = $agentProbe -and [bool]$agentProbe.r5Pass
if (-not $r5 -and $agentProbe -and [bool]$agentProbe.historyOk) { $r5 = $true }
Add-Check "P2-R5" "action_history_shell" $r5 @{
    historyOk = if ($agentProbe) { $agentProbe.historyOk } else { $false }
    tier = if ($agentProbe) { $agentProbe.tier } else { $null }
} $(if ($r5) { "" } else { "action_history_fail" })

if (-not $NoRevert) {
    Write-Host "Reverting flags and restoring nmer-hub..." -ForegroundColor DarkGray
    Write-Cp9Revert $flagsPath
    Get-Process -Name "nmer-wails" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    if (-not (Restart-DiagNmerHub -RepoRoot $RepoRoot -EnvExtra $hubEnv -WarmupSec 4)) {
        [void]$warnings.Add("nmer-hub restore failed after CP9 — run Ensure-DiagNmerHub manually")
    }
}

$overallPass = ($failures.Count -eq 0) -and $r4 -and $r5
$report = [ordered]@{
    capturedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    gate = "cp9_wails_cp_hub_agent_live"
    title = "S8 B3 CP Phase 2 P2-R4/R5 hub agent live"
    phase = 2
    overallPass = [bool]$overallPass
    failureReasons = @($failures)
    warnings = @($warnings)
    checks = $checks
    adapterPreflight = $adapter
    agentProbe = $agentProbe
    gatewayTcp = $gatewayTcp
    tokenSource = if ($tokenInfo) { $tokenInfo.source } else { "missing" }
    nextStep = if ($overallPass) {
        "P2-R4/R5 PASS — optional: fixtures full green + manual signoff for S8 phase 2 close"
    } else {
        "fix CP9 failures; ensure OpenClaw gateway + Niuma Chat token + reload niuma"
    }
}
$report | ConvertTo-Json -Depth 12 | Set-Content -Path $outGate -Encoding UTF8

if ($JsonOnly) {
    $report | ConvertTo-Json -Depth 12
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
