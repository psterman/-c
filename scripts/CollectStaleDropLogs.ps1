param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$LogPath = "",
    [int]$TailLines = 5000
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $Root "Cache\core_async_http.log"
}

$patterns = @(
    "cloudplayer_drop_stale_req",
    "config_drop_stale_req",
    "ttyd_drop_stale_req",
    "cp_drop_stale_req",
    "async_http_cancelled",
    "async_http_retrying",
    "voice_fsm_reject"
)

$counts = @{}
foreach ($p in $patterns) { $counts[$p] = 0 }

if (Test-Path $LogPath) {
    $lines = Get-Content -LiteralPath $LogPath -Tail $TailLines -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        foreach ($p in $patterns) {
            if ($line -match [regex]::Escape($p)) {
                $counts[$p] += 1
            }
        }
    }
}

Write-Output "== Stale / async diagnostic counts (tail=$TailLines) =="
Write-Output "log=$LogPath"
foreach ($p in $patterns) {
    Write-Output ("{0}={1}" -f $p, $counts[$p])
}

$outPath = Join-Path $Root "Cache\stale_drop_summary.json"
$obj = [ordered]@{
    ts          = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    logPath     = $LogPath
    tailLines   = $TailLines
    counts      = $counts
}
$obj | ConvertTo-Json | Set-Content -LiteralPath $outPath -Encoding UTF8
Write-Output "written=$outPath"
