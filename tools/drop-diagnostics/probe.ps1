param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')),
  [string]$OutputDir = (Join-Path $PSScriptRoot 'results'),
  [string]$Scenario = 'drop_probe'
)

$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$cache = Join-Path $RepoRoot 'Cache'
$bridgePath = Join-Path $cache 'native_drop_events.jsonl'
$ahkPath = Join-Path $cache 'drop_diagnostics_runtime.log'

$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$outFile = Join-Path $OutputDir ("drop_probe_${ts}.json")

$bridgeRows = @()
if (Test-Path $bridgePath) {
  foreach ($ln in Get-Content -Path $bridgePath -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($ln)) { continue }
    try { $bridgeRows += ($ln | ConvertFrom-Json -ErrorAction Stop) } catch {}
  }
}
$ahkRows = @()
if (Test-Path $ahkPath) {
  $ahkRows = @(Get-Content -Path $ahkPath -Encoding UTF8)
}

$counts = [ordered]@{ drag_start=0; drag_enter=0; drop=0; drag_end=0; bridge_ready=0; other=0 }
$lastByKind = @{}
$outOfOrder = 0
$prevOrder = -1
$orderMap = @{ bridge_ready=0; drag_start=1; drag_enter=2; drop=3; drag_end=4 }
foreach ($ev in $bridgeRows) {
  $k = [string]$ev.kind
  if ($counts.Contains($k)) { $counts[$k]++ } else { $counts.other++ }
  if ($orderMap.ContainsKey($k)) {
    $ord = [int]$orderMap[$k]
    if ($prevOrder -gt $ord) { $outOfOrder++ }
    $prevOrder = $ord
  }
  $lastByKind[$k] = $ev
}

$matchedDrop = @($ahkRows | Where-Object { $_ -match 'Drop_Sent|Physical_Suck_Triggered|payload=' }).Count
$dropLossRate = 0
if ($counts.drop -gt 0) {
  $dropLossRate = [Math]::Round((100.0 * [Math]::Max(0, ($counts.drop - $matchedDrop))) / $counts.drop, 2)
}

$latencies = @()
foreach ($ev in $bridgeRows) {
  if (-not $ev.at) { continue }
  try {
    $tBridge = [datetime]::Parse([string]$ev.at)
    # rough proxy: compare to now for recentness; true e2e needs shared ids
    $latencies += [Math]::Abs([Math]::Round(((Get-Date) - $tBridge).TotalMilliseconds, 2))
  } catch {}
}
$avgLatency = if ($latencies.Count -gt 0) { [Math]::Round((($latencies | Measure-Object -Average).Average),2) } else { 0 }
$peakLatency = if ($latencies.Count -gt 0) { [Math]::Round((($latencies | Measure-Object -Maximum).Maximum),2) } else { 0 }

$result = [ordered]@{
  ts = (Get-Date).ToString('s')
  scenario = $Scenario
  metrics = [ordered]@{
    bridgeLines = $bridgeRows.Count
    ahkLines = $ahkRows.Count
    counts = $counts
    matchedDropSignals = $matchedDrop
    dropLossRatePct = $dropLossRate
    outOfOrder = $outOfOrder
    avgLatencyMsApprox = $avgLatency
    peakLatencyMsApprox = $peakLatency
  }
  errors = @()
}
if (-not (Test-Path $bridgePath)) { $result.errors += "missing: $bridgePath" }
if (-not (Test-Path $ahkPath)) { $result.errors += "missing: $ahkPath" }

Set-Content -Path $outFile -Value ($result | ConvertTo-Json -Depth 8) -Encoding UTF8
Write-Output "probe: $outFile"
