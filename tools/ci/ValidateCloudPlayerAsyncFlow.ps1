param(
  [string]$CloudPlayerPath = 'modules/CloudPlayer.ahk'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $CloudPlayerPath)) {
  throw "CloudPlayer file not found: $CloudPlayerPath"
}

$txt = Get-Content -LiteralPath $CloudPlayerPath -Raw

$required = @(
  'CloudPlayer_UseAsyncFlow()',
  'CloudPlayer_UseAsyncImport()',
  'CloudPlayer_UseAsyncDownload()',
  'CloudPlayer_UseAsyncBrowse()',
  'CloudPlayer_AsyncFlowStart(',
  'CloudPlayer_HttpJsonAsyncReq(',
  'CloudPlayer_TryBootstrapQuarkCookieAsync(',
  'CloudPlayer_TryBootstrapQuarkOpenAsync(',
  'CloudPlayer_VerifyMountListAsync(',
  'cloudplayer_async_http_start',
  'cloudplayer_async_http_done',
  'cloudplayer_async_cancelled',
  'cloudplayer_async_timeout_total'
)

$missing = @()
foreach($k in $required){
  if($txt.IndexOf($k, [System.StringComparison]::OrdinalIgnoreCase) -lt 0){
    $missing += $k
  }
}

if($missing.Count -gt 0){
  Write-Host 'Missing async guardrails:'
  $missing | ForEach-Object { Write-Host " - $_" }
  exit 2
}

Write-Host 'Async flow guardrails OK.'
exit 0
