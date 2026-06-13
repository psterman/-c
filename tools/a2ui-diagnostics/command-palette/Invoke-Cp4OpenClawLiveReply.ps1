# CP4 manual smoke: hub adapter -> OpenClaw Gateway live reply (not route-only).
param(
    [string]$Query = "Reply with one short sentence in Chinese.",
    [switch]$JsonOnly,
    [switch]$SkipGatewayRestart
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$repo = Get-DiagRepoRoot -From $PSScriptRoot
$dbg = Join-Path $repo "Cache\debug"
$outPath = Join-Path $dbg "cp4_openclaw_live_reply.json"

function Test-HubAdapterPing {
    param([string]$QueryText)
    $cardId = "card_cp4_live_" + (Get-Date -Format "HHmmss")
    $slug = ($cardId -replace '(?i)^card[-_]?', '') -replace '[^a-zA-Z0-9_-]', '-'
    if (-not $slug) { $slug = "live" }
    if ($slug.Length -gt 40) { $slug = $slug.Substring(0, 40) }
    $body = @{
        cardId             = $cardId
        requestId          = "cpag_live_" + (Get-Date -Format "HHmmssfff")
        query              = $QueryText
        sessionRef         = "agent:main:niuma-adp-$slug"
        transportNamespace = "niuma-adp"
    } | ConvertTo-Json -Compress
    return Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:18791/a2ui/openclaw/action" `
        -Body $body -ContentType "application/json; charset=utf-8" -TimeoutSec 120
}

Write-Host ""
Write-Host "=== CP4 OpenClaw Live Reply Probe ===" -ForegroundColor Cyan

if (-not $SkipGatewayRestart) {
    Write-Host "  gateway_restart: in progress..." -ForegroundColor DarkGray
    try {
        openclaw gateway restart 2>&1 | Out-Null
        Start-Sleep -Seconds 8
        Write-Host "  gateway_restart: ok" -ForegroundColor DarkGray
    } catch {
        Write-Host "  gateway_restart: skipped ($($_.Exception.Message))" -ForegroundColor Yellow
    }
    try {
        $cleanupJob = Start-Job { openclaw sessions cleanup --enforce 2>&1 | Out-Null }
        Wait-Job $cleanupJob -Timeout 25 | Out-Null
        Remove-Job $cleanupJob -Force -ErrorAction SilentlyContinue
    } catch { }
}

$gatewayTcp = Test-DiagOpenClawGatewayTcp
$tokenInfo = Get-DiagOpenClawGatewayToken -RepoRoot $repo
$built = Build-DiagNmerHub -RepoRoot $repo
$hubEnv = @{}
if ($tokenInfo -and $tokenInfo.token) {
    $hubEnv["OPENCLAW_GATEWAY_TOKEN"] = $tokenInfo.token
    $hubEnv["OPENCLAW_GATEWAY_HOST"] = "127.0.0.1"
    $hubEnv["OPENCLAW_GATEWAY_PORT"] = "18789"
}
$restarted = Restart-DiagNmerHub -RepoRoot $repo -EnvExtra $hubEnv -WarmupSec 2
$hubUp = Ensure-DiagNmerHub -RepoRoot $repo -WarmupSec 0

$result = @{
    generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    gatewayTcp  = $gatewayTcp
    tokenSource = if ($tokenInfo) { $tokenInfo.source } else { "missing" }
    hubRebuild  = $built
    hubRestart  = $restarted
    hubRunning  = $hubUp
    query       = $Query
    ok          = $false
    code        = "SKIPPED"
    answerLen   = 0
    message     = ""
}

if (-not $hubUp) {
    $result.code = "HUB_DOWN"
    $result.message = "nmer-hub not running"
} elseif (-not $gatewayTcp) {
    $result.code = "GATEWAY_DOWN"
    $result.message = "127.0.0.1:18789 unreachable"
} elseif (-not $tokenInfo -or -not $tokenInfo.token) {
    $result.code = "TOKEN_MISSING"
    $result.message = "set OPENCLAW_GATEWAY_TOKEN or user_studio openclaw key"
} else {
    try {
        $resp = Test-HubAdapterPing -QueryText $Query
        $result.code = [string]$resp.code
        $result.ok = [bool]$resp.ok
        $result.answerLen = if ($resp.answer) { [string]$resp.answer.Length } else { 0 }
        $result.message = [string]$resp.message
        if ($result.ok -and $result.answerLen -gt 0) {
            $result.answerPreview = [string]$resp.answer.Substring(0, [Math]::Min(160, $result.answerLen))
        }
    } catch {
        $result.code = "PROBE_FAIL"
        $result.message = $_.Exception.Message
    }
}

$result.overallPass = $result.ok -and ($result.answerLen -gt 0)
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding UTF8

if ($JsonOnly) {
    $result | ConvertTo-Json -Depth 6
    exit $(if ($result.overallPass) { 0 } else { 1 })
}

Write-Host ("  gateway_tcp: {0}" -f $(if ($gatewayTcp) { "reachable" } else { "down" }))
Write-Host ("  token: {0}" -f $result.tokenSource)
Write-Host ("  hub_rebuild: {0}" -f $(if ($built) { "ok" } else { "fail" }))
Write-Host ("  hub_restart: {0}" -f $(if ($restarted) { "ok" } else { "fail" }))
Write-Host ("  adapter: code={0} ok={1} answerLen={2}" -f $result.code, $result.ok, $result.answerLen) `
    -ForegroundColor $(if ($result.overallPass) { "Green" } else { "Yellow" })
if ($result.answerPreview) {
    Write-Host ("  preview: {0}" -f $result.answerPreview) -ForegroundColor DarkGray
}
if (-not $result.overallPass -and $result.message) {
    Write-Host ("  message: {0}" -f $result.message) -ForegroundColor Yellow
}
Write-Host ("report: {0}" -f $outPath) -ForegroundColor DarkGray
exit $(if ($result.overallPass) { 0 } else { 1 })
