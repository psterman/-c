param(
  [string]$BaseUrl = 'http://127.0.0.1:8080',
  [string]$OutputDir = (Join-Path $PSScriptRoot 'results'),
  [string]$Scenario = 'search_scan_default'
)

$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$queries = @(
  'a',
  'search',
  'README',
  'SearchCenterCore',
  '中文',
  '测试',
  'C:\\Users',
  'node_modules',
  '*.ahk',
  'http'
)

$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$outFile = Join-Path $OutputDir ("search_scan_${ts}.jsonl")
$errors = @()

function Invoke-Search([string]$q) {
  $enc = [uri]::EscapeDataString($q)
  $url = "$BaseUrl/search?keyword=$enc"
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    $resp = Invoke-WebRequest -Uri $url -Method GET -TimeoutSec 8
    $sw.Stop()
    $json = $null
    try { $json = $resp.Content | ConvertFrom-Json -ErrorAction Stop } catch {}
    $count = 0
    if ($json -and $json.items) { try { $count = @($json.items).Count } catch {} }
    return [ordered]@{
      ts = (Get-Date).ToString('s')
      scenario = $Scenario
      metrics = [ordered]@{
        query = $q
        latencyMs = [Math]::Round($sw.Elapsed.TotalMilliseconds,2)
        httpStatus = [int]$resp.StatusCode
        ok = $true
        resultCount = $count
      }
      errors = @()
    }
  } catch {
    $sw.Stop()
    return [ordered]@{
      ts = (Get-Date).ToString('s')
      scenario = $Scenario
      metrics = [ordered]@{
        query = $q
        latencyMs = [Math]::Round($sw.Elapsed.TotalMilliseconds,2)
        httpStatus = 0
        ok = $false
        resultCount = 0
      }
      errors = @($_.Exception.Message)
    }
  }
}

foreach ($q in $queries) {
  $row = Invoke-Search $q
  if (-not $row.metrics.ok) { $errors += "[$q] $($row.errors -join '; ')" }
  Add-Content -Path $outFile -Value ($row | ConvertTo-Json -Depth 8 -Compress) -Encoding UTF8
}

$summary = [ordered]@{
  ts = (Get-Date).ToString('s')
  scenario = $Scenario
  metrics = [ordered]@{
    total = $queries.Count
    failed = $errors.Count
    passed = $queries.Count - $errors.Count
    output = $outFile
  }
  errors = $errors
}
$summaryFile = Join-Path $OutputDir ("search_scan_summary_${ts}.json")
Set-Content -Path $summaryFile -Value ($summary | ConvertTo-Json -Depth 8) -Encoding UTF8
Write-Output "scan_jsonl: $outFile"
Write-Output "summary: $summaryFile"
