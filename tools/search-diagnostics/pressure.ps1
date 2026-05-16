param(
  [string]$BaseUrl = 'http://127.0.0.1:8080',
  [int]$DurationSec = 30,
  [int]$Concurrency = 2,
  [int]$Qps = 8,
  [string]$OutputDir = (Join-Path $PSScriptRoot 'results'),
  [string]$Scenario = 'search_pressure'
)

$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$queries = @('search','README','中文','test','C:\\','*.ahk','http','core')
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$outFile = Join-Path $OutputDir ("search_pressure_${ts}.json")

$scriptBlock = {
  param($BaseUrl, $DurationSec, $Qps, $Queries, $WorkerId)
  $endAt = (Get-Date).AddSeconds($DurationSec)
  $intervalMs = if ($Qps -le 0) { 200 } else { [Math]::Max(20, [int](1000 / $Qps)) }
  $rows = New-Object System.Collections.ArrayList
  $i = 0
  while ((Get-Date) -lt $endAt) {
    $q = $Queries[$i % $Queries.Count]
    $i++
    $enc = [uri]::EscapeDataString($q)
    $url = "$BaseUrl/search?keyword=$enc"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
      $resp = Invoke-WebRequest -Uri $url -Method GET -TimeoutSec 8
      $sw.Stop()
      [void]$rows.Add([ordered]@{ ok = $true; status = [int]$resp.StatusCode; latencyMs = [double]([Math]::Round($sw.Elapsed.TotalMilliseconds,2)); worker = $WorkerId })
    } catch {
      $sw.Stop()
      [void]$rows.Add([ordered]@{ ok = $false; status = 0; latencyMs = [double]([Math]::Round($sw.Elapsed.TotalMilliseconds,2)); worker = $WorkerId; error = $_.Exception.Message })
    }
    Start-Sleep -Milliseconds $intervalMs
  }
  return ,$rows
}

$jobs = @()
for ($w=1; $w -le $Concurrency; $w++) {
  $jobs += Start-Job -ScriptBlock $scriptBlock -ArgumentList $BaseUrl, $DurationSec, $Qps, $queries, $w
}
$allRows = @()
foreach ($j in $jobs) {
  $data = Receive-Job -Job $j -Wait
  if ($data) { $allRows += $data }
}
$jobs | Remove-Job -Force | Out-Null

$lat = @($allRows | Where-Object { $_.ok } | ForEach-Object { [double]$_.latencyMs } | Sort-Object)
function Percentile($arr, [double]$p) {
  if (-not $arr -or $arr.Count -eq 0) { return 0 }
  $idx = [Math]::Ceiling($p * $arr.Count) - 1
  if ($idx -lt 0) { $idx = 0 }
  if ($idx -ge $arr.Count) { $idx = $arr.Count - 1 }
  return [Math]::Round([double]$arr[$idx],2)
}

$total = @($allRows).Count
$failed = @($allRows | Where-Object { -not $_.ok }).Count
$ok = $total - $failed
$failureRate = if ($total -gt 0) { [Math]::Round((100.0 * $failed) / $total, 2) } else { 0 }
$throughput = if ($DurationSec -gt 0) { [Math]::Round($total / $DurationSec, 2) } else { 0 }
$backpressureRisk = if ((Percentile $lat 0.99) -ge 1200 -or $failureRate -ge 10) { 'critical' } elseif ((Percentile $lat 0.90) -ge 700 -or $failureRate -ge 3) { 'warn' } else { 'ok' }

$result = [ordered]@{
  ts = (Get-Date).ToString('s')
  scenario = $Scenario
  metrics = [ordered]@{
    durationSec = $DurationSec
    concurrency = $Concurrency
    targetQpsPerWorker = $Qps
    requests = $total
    success = $ok
    failed = $failed
    failureRatePct = $failureRate
    throughputRps = $throughput
    p50Ms = (Percentile $lat 0.50)
    p90Ms = (Percentile $lat 0.90)
    p99Ms = (Percentile $lat 0.99)
    backpressure = $backpressureRisk
  }
  errors = @($allRows | Where-Object { -not $_.ok } | Select-Object -First 20 -ExpandProperty error)
}
Set-Content -Path $outFile -Value ($result | ConvertTo-Json -Depth 8) -Encoding UTF8
Write-Output "pressure: $outFile"
