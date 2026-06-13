# CP4: palette.agentTransport=hub gray — hub chain + CP hello inject, no FTB-ready dependency.
param(
    [switch]$JsonOnly,
    [switch]$WithPerfRecheck,
    [int]$HelloWaitSec = 25,
    [int]$AdapterTimeoutSec = 120,
    [int]$AdapterAttempts = 2,
    [switch]$SkipGatewayRestart
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
$paletteStoreJs = Join-Path $repo "html\palette\app\palette-store.js"
$hostBridgeJs = Join-Path $repo "html\palette\app\host-bridge.js"
$streamClientJs = Join-Path $repo "html\palette\official\PaletteOfficialA2UIStreamClient.js"
$flagsPath = Join-Path $repo "local\nmer-flags.json"

function Get-SourceText([string]$path) {
    if (-not (Test-Path $path)) { return "" }
    return Get-Content $path -Encoding UTF8 -Raw
}

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

function Test-AdapterTimeoutLike([string]$text) {
    if (-not $text) { return $false }
    return $text -match "超时|timed?\s*out|Timeout|中止|cancel|aborted"
}

function Invoke-Cp4GatewayWarmup {
    if ($SkipGatewayRestart) { return }
    Write-Host "  openclaw gateway warmup..." -ForegroundColor DarkGray
    try {
        openclaw gateway restart 2>&1 | Out-Null
        Start-Sleep -Seconds 8
    } catch {
        Write-Host "  gateway_restart: skipped ($($_.Exception.Message))" -ForegroundColor Yellow
    }
    try {
        $cleanupJob = Start-Job { openclaw sessions cleanup --enforce 2>&1 | Out-Null }
        Wait-Job $cleanupJob -Timeout 25 | Out-Null
        Remove-Job $cleanupJob -Force -ErrorAction SilentlyContinue
    } catch { }
}

function Test-HubAdapterRoute {
    param(
        [string]$Base = "http://127.0.0.1:18791",
        [string]$Query = "Reply with one short sentence in Chinese.",
        [int]$TimeoutSec = 120,
        [int]$MaxAttempts = 2
    )
    $cardId = "card_cp4_gate_" + (Get-Date -Format "HHmmss")
    $reqId = "cpag_cp4_" + (Get-Date -Format "HHmmssfff")
    $slug = ($cardId -replace '(?i)^card[-_]?', '') -replace '[^a-zA-Z0-9_-]', '-'
    $slug = $slug.Trim('-')
    if (-not $slug) { $slug = "task" }
    if ($slug.Length -gt 40) { $slug = $slug.Substring(0, 40) }
    $sessionRef = "agent:main:niuma-adp-$slug"
    $body = @{
        cardId             = $cardId
        requestId          = $reqId
        query              = $Query
        sessionRef         = $sessionRef
        transportNamespace = "niuma-adp"
    } | ConvertTo-Json -Compress
    $last = $null
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            $json = Invoke-RestMethod -Method Post -Uri "$Base/a2ui/openclaw/action" -Body $body `
                -ContentType "application/json; charset=utf-8" -TimeoutSec $TimeoutSec
            $code = if ($json -and $json.code) { [string]$json.code } else { "ADAPTER_OK" }
            $ok = ($json -and ($json.ok -eq $true))
            $answer = if ($json -and $json.answer) { [string]$json.answer } else { "" }
            $message = if ($json -and $json.message) { [string]$json.message } else { "" }
            $routeOk = $ok -or ($code -eq "OPENCLAW_CONFIG_MISSING") -or ($code -eq "OPENCLAW_CHAT_FAILED")
            return @{
                pass     = $routeOk
                ok       = $ok
                code     = $code
                answer   = $answer
                message  = $message
                detail   = "status=200 session=$sessionRef attempt=$attempt"
                attempts = $attempt
            }
        } catch {
            $status = 0
            $code = ""
            $raw = ""
            $message = ""
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                $raw = [string]$_.ErrorDetails.Message
            }
            if (-not $raw -and $_.Exception.Response) {
                try { $status = [int]$_.Exception.Response.StatusCode } catch { }
                try {
                    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                    $raw = $reader.ReadToEnd()
                    $reader.Close()
                } catch { }
            }
            if ($raw) {
                try {
                    $j = $raw | ConvertFrom-Json
                    if ($j.code) { $code = [string]$j.code }
                    if ($j.message) { $message = [string]$j.message }
                } catch { }
            }
            if (-not $code) { $code = $_.Exception.Message }
            $routeOk = ($code -eq "OPENCLAW_CONFIG_MISSING") -or ($code -eq "OPENCLAW_CHAT_FAILED")
            if ($status -eq 409) { $routeOk = $false }
            $last = @{
                pass     = $routeOk
                ok       = $false
                code     = $code
                answer   = ""
                message  = $message
                detail   = "status=$status session=$sessionRef attempt=$attempt"
                attempts = $attempt
            }
            if ((Test-AdapterTimeoutLike $code) -and $attempt -lt $MaxAttempts) {
                Write-Host "  adapter attempt $attempt timeout; retrying..." -ForegroundColor Yellow
                Start-Sleep -Seconds 6
                continue
            }
            return $last
        }
    }
    return $last
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
    $combined = @(
        (Get-SourceText $cpHtml),
        (Get-SourceText $paletteStoreJs),
        (Get-SourceText $hostBridgeJs),
        (Get-SourceText $streamClientJs)
    ) -join "`n"
    $hasAgentTransport = $combined -match "agentTransport"
    $hasPaletteFlagsWire = ($combined -match "palette_flags") -or ($combined -match "applyPaletteFlags")
    $htmlOk = $hasAgentTransport -and $hasPaletteFlagsWire
}
$checks += @{ name = "html_agentTransport_flag"; pass = $htmlOk; value = $htmlOk }
if (-not $htmlOk) { [void]$failures.Add("palette agentTransport / palette_flags wiring missing in CP shell modules") }

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

$adapterRoutePass = $false
$adapterDetail = "skipped"
$adapterLivePass = $false
$adapterLiveDetail = "skipped"
$gatewayTcp = $false
$tokenInfo = $null
if ($hubTransport) {
    $built = Build-DiagNmerHub -RepoRoot $repo
    $checks += @{ name = "hub_rebuild"; pass = $built; value = $(if ($built) { "ok" } else { "go build failed" }) }
    if (-not $built) {
        [void]$warnings.Add("nmer-hub rebuild failed; using existing binary for adapter probe")
    }
    $tokenInfo = Get-DiagOpenClawGatewayToken -RepoRoot $repo
    $hubEnv = @{}
    if ($tokenInfo -and $tokenInfo.token) {
        $hubEnv["OPENCLAW_GATEWAY_TOKEN"] = $tokenInfo.token
        $hubEnv["OPENCLAW_GATEWAY_HOST"] = "127.0.0.1"
        $hubEnv["OPENCLAW_GATEWAY_PORT"] = "18789"
    }
    if ($built -or $tokenInfo) {
        $restarted = Restart-DiagNmerHub -RepoRoot $repo -EnvExtra $hubEnv -WarmupSec 2
        $checks += @{ name = "hub_restart_for_openclaw"; pass = $restarted; value = $(if ($restarted) { "ok" } else { "fail" }) }
        if (-not $restarted) {
            [void]$warnings.Add("nmer-hub restart failed; adapter probe may use stale env")
        }
    }
    if (-not (Ensure-DiagNmerHub -RepoRoot $repo -WarmupSec 0)) {
        [void]$failures.Add("nmer-hub not running for adapter probe")
    } else {
        $gatewayTcp = Test-DiagOpenClawGatewayTcp
        $checks += @{
            name  = "openclaw_gateway_tcp"
            pass  = $true
            value = $(if ($gatewayTcp) { "127.0.0.1:18789 reachable" } else { "127.0.0.1:18789 unreachable (skip live reply)" })
        }
        if ($gatewayTcp -and $tokenInfo -and $tokenInfo.token) {
            Invoke-Cp4GatewayWarmup
        }
        $adapter = Test-HubAdapterRoute -TimeoutSec $AdapterTimeoutSec -MaxAttempts $AdapterAttempts
        $adapterRoutePass = [bool]$adapter.pass
        $adapterDetail = [string]$adapter.detail + " code=" + [string]$adapter.code
        $checks += @{ name = "hub_adapter_route"; pass = $adapterRoutePass; value = $adapterDetail }
        if (-not $adapterRoutePass) {
            [void]$failures.Add("hub adapter route failed: $adapterDetail")
        } elseif (-not $adapter.ok -and [string]$adapter.code -eq "OPENCLAW_CONFIG_MISSING") {
            [void]$warnings.Add("OpenClaw token missing: configure in Niuma Chat then reload")
        }

        $liveRequired = $gatewayTcp -and $tokenInfo -and $tokenInfo.token
        if ($liveRequired) {
            $hasAnswer = [bool]$adapter.ok -and -not [string]::IsNullOrWhiteSpace([string]$adapter.answer)
            $msg = [string]$adapter.message
            $originBlocked = ($msg -match "CONTROL_UI_ORIGIN_NOT_ALLOWED")
            $tokenMismatch = ($msg -match "AUTH_TOKEN_MISMATCH|token mismatch")
            $adapterLivePass = $hasAnswer
            $adapterLiveDetail = if ($hasAnswer) {
                "ADAPTER_OK answerLen=$([string]$adapter.answer.Length)"
            } elseif ($originBlocked) {
                "OPENCLAW_CHAT_FAILED origin blocked (rebuild nmer-hub with gateway-client backend)"
            } elseif ($tokenMismatch) {
                "OPENCLAW_CHAT_FAILED token mismatch (Niuma Chat reconnect then reload)"
            } else {
                "code=$([string]$adapter.code) msg=$msg"
            }
            $checks += @{ name = "hub_openclaw_live_reply"; pass = $adapterLivePass; value = $adapterLiveDetail }
            if ($originBlocked -or $tokenMismatch) {
                [void]$failures.Add("OpenClaw live reply blocked: $adapterLiveDetail")
            } elseif (-not $adapterLivePass) {
                if (Test-AdapterTimeoutLike ([string]$adapter.code)) {
                    [void]$failures.Add("OpenClaw live reply timeout after $($adapter.attempts) attempt(s): $adapterLiveDetail")
                } else {
                    [void]$warnings.Add("OpenClaw live reply pending: $adapterLiveDetail (verify Gateway model in Niuma Chat)")
                }
            }
        } else {
            $skipWhy = if (-not $gatewayTcp) { "gateway down" } else { "token missing" }
            $checks += @{ name = "hub_openclaw_live_reply"; pass = $true; value = "skipped ($skipWhy)" }
            if (-not $gatewayTcp) {
                [void]$warnings.Add("OpenClaw gateway not reachable on 127.0.0.1:18789; live reply check skipped")
            } elseif (-not $tokenInfo) {
                [void]$warnings.Add("OpenClaw token missing; live reply check skipped")
            }
        }
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
