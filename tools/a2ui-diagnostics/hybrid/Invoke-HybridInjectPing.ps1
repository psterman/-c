# Verify AHK drains hub signoff inject (hybrid_signoff_ping -> hybrid_signoff_inject_result.json)
param(
    [string]$RepoRoot = "",
    [int]$TimeoutSec = 20
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
$resultPath = Join-Path $debugDir "hybrid_signoff_inject_result.json"
$addr = $env:NMER_A2UI_BRIDGE_ADDR
if (-not $addr) { $addr = "127.0.0.1:18791" }
$base = "http://$addr"
$probeId = "ping-" + (Get-Date -Format "HHmmssfff")

if (Test-Path $resultPath) { Remove-Item $resultPath -Force -ErrorAction SilentlyContinue }

try {
    $reg = @{ action = "register_external"; entry = "hybrid-inject-ping" } | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Post -Uri "$base/shell/ftb" -Body $reg -ContentType "application/json; charset=utf-8" -TimeoutSec 8 | Out-Null
    $wake = @{ type = "hybrid_probe_wake"; probeId = "wake-$probeId" } | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Post -Uri "$base/shell/ftb/inject" -Body $wake -ContentType "application/json; charset=utf-8" -TimeoutSec 8 | Out-Null
    Start-Sleep -Milliseconds 500
} catch {}

$body = @{ type = "hybrid_signoff_ping"; probeId = $probeId } | ConvertTo-Json -Compress
$inj = Invoke-RestMethod -Method Post -Uri "$base/shell/ftb/inject" -Body $body -ContentType "application/json; charset=utf-8" -TimeoutSec 10
if ($inj.ok -ne $true) {
    throw "inject ping not queued: $($inj.code)"
}

$deadline = (Get-Date).AddSeconds($TimeoutSec)
$res = $null
while ((Get-Date) -lt $deadline) {
    if (Test-Path $resultPath) {
        try {
            $res = Get-Content $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($res.probeId -eq $probeId -and $res.code -eq "PING_OK") { break }
        } catch {}
    }
    Start-Sleep -Milliseconds 350
}

if (-not $res -or $res.code -ne "PING_OK") {
    throw "AHK inject drain inactive (no PING_OK in ${TimeoutSec}s). Reload niuma Ctrl+Shift+Q."
}

[ordered]@{
    ok       = $true
    pass     = $true
    probeId  = $probeId
    code     = $res.code
    via      = $res.via
    resultPath = $resultPath
}
