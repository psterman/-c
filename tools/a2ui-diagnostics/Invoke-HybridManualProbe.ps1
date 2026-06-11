# File IPC to running niuma.ahk (Nmer_HybridManualProbePoll in NmerWailsBridge.ahk)
param(
    [string]$RepoRoot = "",
    [Parameter(Mandatory = $true)]
    [string]$Action,
    [string]$Query = "hello",
    [string]$Provider = "openclaw",
    [int]$Rounds = 10,
    [int]$TimeoutSec = 60,
    [switch]$SkipHubWake
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }

$reqPath = Join-Path $debugDir "hybrid_manual_probe.json"
$resPath = Join-Path $debugDir "hybrid_manual_probe_result.json"
$id = [guid]::NewGuid().ToString("N")

function Write-ProbeRequest([hashtable]$payload) {
    $json = ($payload | ConvertTo-Json -Compress)
    [System.IO.File]::WriteAllText($reqPath, $json, [System.Text.UTF8Encoding]::new($false))
}

if (-not $SkipHubWake) {
    $addr = $env:NMER_A2UI_BRIDGE_ADDR
    if (-not $addr) { $addr = "127.0.0.1:18791" }
    try {
        $wake = @{ action = "register_external"; entry = "hybrid-probe-wake" } | ConvertTo-Json -Compress
        Invoke-RestMethod -Method Post -Uri "http://$addr/shell/ftb" -Body $wake -ContentType "application/json; charset=utf-8" -TimeoutSec 6 | Out-Null
        $poke = '{"type":"hybrid_probe_wake","ts":"' + (Get-Date).ToUniversalTime().ToString("o") + '"}'
        Invoke-RestMethod -Method Post -Uri "http://$addr/shell/ftb/inject" -Body $poke -ContentType "application/json; charset=utf-8" -TimeoutSec 6 | Out-Null
        Start-Sleep -Milliseconds 900
    } catch {}
}

$body = [ordered]@{
    id          = $id
    action      = $Action
    query       = $Query
    provider    = $Provider
    rounds      = $Rounds
    timeoutMs   = $TimeoutSec * 1000
    requestedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

if (Test-Path $resPath) { Remove-Item $resPath -Force -ErrorAction SilentlyContinue }
if (Test-Path $reqPath) { Remove-Item $reqPath -Force -ErrorAction SilentlyContinue }
Write-ProbeRequest $body

# Fast-fail when probe timer not running (reload niuma after NmerWailsBridge update)
Start-Sleep -Seconds 4
if (Test-Path $reqPath) {
    $logHint = ""
    $logPath = Join-Path $debugDir "hybrid_manual_probe.log"
    if (Test-Path $logPath) {
        $tail = Get-Content $logPath -Tail 3 -Encoding UTF8 -ErrorAction SilentlyContinue
        $logHint = " log_tail=" + ($tail -join " | ")
    }
    throw "hybrid manual probe IPC inactive (request not consumed in 4s). Reload niuma Ctrl+Shift+Q.$logHint"
}

$deadline = (Get-Date).AddSeconds($TimeoutSec + 15)
while ((Get-Date) -lt $deadline) {
    if (Test-Path $resPath) {
        try {
            $raw = Get-Content $resPath -Raw -Encoding UTF8
            if ($raw.StartsWith([char]0xFEFF)) { $raw = $raw.Substring(1) }
            $result = $raw | ConvertFrom-Json
            if ([string]$result.id -eq $id) {
                return $result
            }
        } catch {}
    }
    Start-Sleep -Milliseconds 350
}

throw "hybrid manual probe timeout action=$Action id=$id"
