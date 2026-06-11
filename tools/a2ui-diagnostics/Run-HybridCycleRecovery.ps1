# Hub inject cycle stability (10 rounds) — proxy for recovery gate before full UI cycle
param(
    [string]$RepoRoot = "",
    [int]$Rounds = 10,
    [double]$RecoveryLimitPct = 10
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
$outPath = Join-Path $debugDir "hybrid_cycle_recovery.json"

$addr = $env:NMER_A2UI_BRIDGE_ADDR
if (-not $addr) { $addr = "127.0.0.1:18791" }
$base = "http://$addr"

function Get-HubPrivateMiB {
    $p = Get-Process -Name "nmer-hub" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $p) { return $null }
    $p.Refresh()
    return [math]::Round($p.PrivateMemorySize64 / 1MB, 2)
}

$start = Get-HubPrivateMiB
$peak = $start
$samples = @(@{ round = 0; hubPrivateMiB = $start })

for ($i = 1; $i -le $Rounds; $i++) {
    $body = (@{ type = "hybrid_cycle"; round = $i; ts = (Get-Date).ToUniversalTime().ToString("o") } | ConvertTo-Json -Compress)
    Invoke-RestMethod -Method Post -Uri "$base/shell/ftb/inject" -Body $body -ContentType "application/json; charset=utf-8" -TimeoutSec 10 | Out-Null
    Invoke-RestMethod -Uri "$base/shell/ftb/inject/drain" -TimeoutSec 10 | Out-Null
    Start-Sleep -Milliseconds 400
    $priv = Get-HubPrivateMiB
    if ($null -ne $priv -and $priv -gt $peak) { $peak = $priv }
    $samples += @{ round = $i; hubPrivateMiB = $priv }
}

$end = Get-HubPrivateMiB
$recoveryPct = if ($start -gt 0) { [math]::Round((($peak - $start) / $start) * 100, 2) } else { 0 }
$endDriftPct = if ($start -gt 0) { [math]::Round((([math]::Abs($end - $start)) / $start) * 100, 2) } else { 0 }
$pass = ($recoveryPct -le $RecoveryLimitPct) -and ($endDriftPct -le $RecoveryLimitPct)

$report = [ordered]@{
    capturedAt        = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    rounds            = $Rounds
    hubStartMiB       = $start
    hubPeakMiB        = $peak
    hubEndMiB         = $end
    recoveryPct       = $recoveryPct
    endDriftPct       = $endDriftPct
    recoveryLimitPct  = $RecoveryLimitPct
    pass              = $pass
    samples           = $samples
    note              = "hub inject cycle proxy; full UI 10-round open/close remains manual on dashboard"
}
$report | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "hybrid_cycle_recovery -> $outPath pass=$pass start=$start peak=$peak end=$end recoveryPct=$recoveryPct%"
if (-not $pass) { exit 1 }
exit 0
