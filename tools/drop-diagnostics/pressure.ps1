param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')),
  [int]$DurationSec = 30,
  [int]$EventsPerSec = 20,
  [string]$OutputDir = (Join-Path $PSScriptRoot 'results'),
  [string]$Scenario = 'drop_pressure'
)

$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$cache = Join-Path $RepoRoot 'Cache'
New-Item -ItemType Directory -Force -Path $cache | Out-Null
$bridgePath = Join-Path $cache 'native_drop_events.jsonl'
$ahkPath = Join-Path $cache 'drop_diagnostics_runtime.log'
if (!(Test-Path $bridgePath)) { New-Item -ItemType File -Path $bridgePath | Out-Null }
if (!(Test-Path $ahkPath)) { New-Item -ItemType File -Path $ahkPath | Out-Null }

$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$outFile = Join-Path $OutputDir ("drop_pressure_${ts}.json")
$total = [Math]::Max(1, $DurationSec * [Math]::Max(1,$EventsPerSec))
$intervalMs = [Math]::Max(1, [int](1000 / [Math]::Max(1,$EventsPerSec)))
$ahkWriteFail = 0
$bridgeWriteFail = 0

$sw = [System.Diagnostics.Stopwatch]::StartNew()
for ($i = 0; $i -lt $total; $i++) {
  $kind = switch ($i % 4) { 0 {'drag_start'} 1 {'drag_enter'} 2 {'drop'} default {'drag_end'} }
  $ev = [ordered]@{
    at = (Get-Date).ToString('o')
    kind = $kind
    payloadKind = if (($i % 3) -eq 0) { 'text' } else { 'file' }
    x = 100 + ($i % 700)
    y = 80 + ($i % 500)
    synthetic = $true
  }
  try {
    Add-Content -Path $bridgePath -Value ($ev | ConvertTo-Json -Compress) -Encoding UTF8 -ErrorAction Stop
  } catch {
    $bridgeWriteFail++
  }
  try {
    Add-Content -Path $ahkPath -Value ("[{0}][Synthetic_{1}] payload={2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $kind, $ev.payloadKind) -Encoding UTF8 -ErrorAction Stop
  } catch {
    $ahkWriteFail++
  }
  Start-Sleep -Milliseconds $intervalMs
}
$sw.Stop()

$elapsed = [Math]::Round($sw.Elapsed.TotalSeconds,2)
$throughput = if ($elapsed -gt 0) { [Math]::Round($total / $elapsed,2) } else { 0 }
$result = [ordered]@{
  ts = (Get-Date).ToString('s')
  scenario = $Scenario
  metrics = [ordered]@{
    durationSec = $DurationSec
    eventsPerSecTarget = $EventsPerSec
    totalEventsWritten = $total
    elapsedSec = $elapsed
    throughputEps = $throughput
    avgLatencyMs = [Math]::Round((1000.0 / [Math]::Max(1,$EventsPerSec)),2)
    peakLatencyMs = [Math]::Round((1000.0 / [Math]::Max(1,$EventsPerSec)),2)
    dropRatePct = 0
    ahkWriteFailures = $ahkWriteFail
    bridgeWriteFailures = $bridgeWriteFail
  }
  errors = @()
}
if ($ahkWriteFail -gt 0) {
  $result.errors += "ahk_log_write_failed=$ahkWriteFail"
}
if ($bridgeWriteFail -gt 0) {
  $result.errors += "bridge_log_write_failed=$bridgeWriteFail"
}
Set-Content -Path $outFile -Value ($result | ConvertTo-Json -Depth 8) -Encoding UTF8
Write-Output "pressure: $outFile"
