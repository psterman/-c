param(
  [int]$Port = 8766
)
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Resolve-Path (Join-Path $root '..\..')
$cache = Join-Path $repo 'Cache'
if (!(Test-Path $cache)) { New-Item -ItemType Directory -Path $cache | Out-Null }
$server = Start-Process -FilePath powershell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-Command',"Set-Location '$repo'; python -m http.server $Port") -WindowStyle Hidden -PassThru
Start-Sleep -Milliseconds 500
$url = "http://127.0.0.1:$Port/tools/drop-diagnostics/dashboard.html"
Start-Process $url | Out-Null
Write-Output "dashboard: $url"
Write-Output "server_pid: $($server.Id)"
Write-Output "tail files: $cache\native_drop_events.jsonl ; $cache\drop_diagnostics_runtime.log"
