# File IPC to niuma.ahk (Nmer_MultiCardMemoryProbePoll in MultiCardMemoryProbe.ahk)
param(
    [string]$RepoRoot = "",
    [Parameter(Mandatory = $true)]
    [string]$Action,
    [int]$CardCount = 0,
    [int]$SettleMs = 3000,
    [int]$TimeoutSec = 90
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }

$reqPath = Join-Path $debugDir "multi_card_memory_probe.json"
$resPath = Join-Path $debugDir "multi_card_memory_probe_result.json"
$id = [guid]::NewGuid().ToString("N")

if (Test-Path $resPath) { Remove-Item $resPath -Force -ErrorAction SilentlyContinue }
if (Test-Path $reqPath) { Remove-Item $reqPath -Force -ErrorAction SilentlyContinue }

$body = [ordered]@{
    id          = $id
    action      = $Action
    cardCount   = $CardCount
    settleMs    = $SettleMs
    requestedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}
[System.IO.File]::WriteAllText($reqPath, ($body | ConvertTo-Json -Compress), [System.Text.UTF8Encoding]::new($false))

Write-Host ("probe -> action={0} id={1}" -f $Action, $id) -ForegroundColor DarkGray

$consumeDeadline = (Get-Date).AddSeconds(8)
while ((Get-Date) -lt $consumeDeadline) {
    if (-not (Test-Path $reqPath)) { break }
    Start-Sleep -Milliseconds 250
}
if (Test-Path $reqPath) {
    $logHint = ""
    $logPath = Join-Path $debugDir "multi_card_memory_probe.log"
    if (Test-Path $logPath) {
        $tail = Get-Content $logPath -Tail 3 -Encoding UTF8 -ErrorAction SilentlyContinue
        $logHint = " log_tail=" + ($tail -join " | ")
    }
    throw "multi-card memory probe IPC inactive (request not consumed in 8s). Reload niuma.ahk once.$logHint"
}

$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
    if (Test-Path $resPath) {
        try {
            $raw = [System.IO.File]::ReadAllText($resPath, (New-Object System.Text.UTF8Encoding $false))
            $raw = $raw.TrimStart([char]0xFEFF).Trim()
            $result = $raw | ConvertFrom-Json
            if ([string]$result.id -eq $id) {
                Write-Host ("probe <- code={0} pass={1}" -f $result.code, $result.pass) -ForegroundColor DarkGray
                return $result
            }
        } catch {}
    }
    Start-Sleep -Milliseconds 200
}
$hint = ""
if (Test-Path $resPath) {
    try { $hint = " stale_res=" + (Get-Content $resPath -Raw -Encoding UTF8) } catch {}
}
throw "multi-card memory probe timeout (${TimeoutSec}s) action=$Action expect_id=$id$hint"
