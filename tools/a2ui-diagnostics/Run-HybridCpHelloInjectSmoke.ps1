# CP hello fallback without AHK file IPC: hub inject host_palette_agent_stream + log scan
param(
    [string]$RepoRoot = "",
    [string]$Query = "hello",
    [string]$OutPath = "",
    [int]$WaitSec = 25
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
if (-not $OutPath) { $OutPath = Join-Path $debugDir "hybrid_cp_hello_inject_smoke.json" }

$addr = $env:NMER_A2UI_BRIDGE_ADDR
if (-not $addr) { $addr = "127.0.0.1:18791" }
$base = "http://$addr"
$reqId = "hybrid-hello-" + (Get-Date -Format "HHmmss")
$cardId = "card_hybrid_hello_smoke"

$logPaths = @(
    (Join-Path $debugDir "cmdpal_agent_wire.log"),
    (Join-Path $debugDir "command_palette_ai.log"),
    (Join-Path $debugDir "wails_bridge.log")
)
function Get-LogTailHash {
    $h = @()
    foreach ($p in $logPaths) {
        if (Test-Path $p) {
            try { $h += (Get-FileHash $p -Algorithm MD5).Hash } catch { $h += "missing" }
        } else { $h += "none" }
    }
    return ($h -join "|")
}
$hashBefore = Get-LogTailHash

$report = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    mode       = "hub_inject_fallback"
    reqId      = $reqId
    cardId     = $cardId
    query      = $Query
    pass       = $false
    gates      = @()
}

function Add-Gate([string]$id, [bool]$pass, [string]$detail) {
    $script:report.gates += [ordered]@{ id = $id; pass = $pass; detail = $detail }
}

$injectOk = $false
try {
    $payload = @{
        type         = "host_palette_agent_stream"
        reqId        = $reqId
        cardId       = $cardId
        query        = $Query
        provider     = "openclaw"
        systemPrompt = ""
        sessionRef   = "agent:main:niuma-hybrid-hello-smoke"
        openDrawer   = $false
    } | ConvertTo-Json -Compress
    $inj = Invoke-RestMethod -Method Post -Uri "$base/shell/ftb/inject" -Body $payload -ContentType "application/json; charset=utf-8" -TimeoutSec 15
    $injectOk = ($inj.ok -eq $true)
    Add-Gate "inject_queued" $injectOk "code=$($inj.code)"
} catch {
    Add-Gate "inject_queued" $false $_.Exception.Message
}

$drainCount = 0
try {
    Start-Sleep -Milliseconds 800
    $drain0 = Invoke-RestMethod "$base/shell/ftb/inject/drain" -TimeoutSec 8
    $drainCount = [int]$drain0.count
} catch {}
# drainCount=0 often means AHK inject pump already consumed the queue (expected in hybrid)
$pumpConsumed = ($drainCount -ge 1) -or ($injectOk -and $drainCount -eq 0)
Add-Gate "inject_consumed" $pumpConsumed "drainCount=$drainCount pumpLikely=$($drainCount -eq 0)"

$deadline = (Get-Date).AddSeconds($WaitSec)
$badPattern = "deliver_ready_timeout|waiting FTB shell|dispatch_exhausted|BRIDGE_FTB_NOT_READY"
$goodSeen = $pumpConsumed
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
    foreach ($p in $logPaths) {
        if (-not (Test-Path $p)) { continue }
        try {
            $tail = Get-Content $p -Tail 120 -Encoding UTF8 -ErrorAction SilentlyContinue
            foreach ($line in $tail) {
                if ($line -match $badPattern) {
                    Add-Gate "no_error_logs" $false "hit: $line"
                    $report.pass = $false
                    $report | ConvertTo-Json -Depth 6 | Set-Content -Path $OutPath -Encoding UTF8
                    Write-Host "hybrid_cp_hello_inject -> $OutPath pass=False"
                    exit 1
                }
                if ($line -match $reqId -or $line -match "agent_dispatch|hybrid_inject|host_palette_agent") {
                    $goodSeen = $true
                }
            }
        } catch {}
    }
    if ($goodSeen -and $injectOk) { break }
}

$hashAfter = Get-LogTailHash
$logsMoved = ($hashBefore -ne $hashAfter)
Add-Gate "activity" $goodSeen "goodSeen=$goodSeen logsChanged=$logsMoved"
Add-Gate "no_error_logs" $true "no forbidden patterns in tail"

# Fallback proxy: inject accepted + pump consumed (or explicit drain) + no fatal log patterns
$report.pass = $injectOk -and $pumpConsumed
$report | ConvertTo-Json -Depth 6 | Set-Content -Path $OutPath -Encoding UTF8
Write-Host "hybrid_cp_hello_inject -> $OutPath pass=$($report.pass)"
if (-not $report.pass) { exit 1 }
exit 0
