# Split local_input_p95 vs query_to_paint_p95 for PerfGate triage
param(
    [string]$LogPath = "",
    [string]$GatePath = "",
    [switch]$JsonOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$repo = Get-DiagRepoRoot -From $PSScriptRoot
if (-not $LogPath) { $LogPath = Join-Path $repo "Cache\debug\command_palette_perf.ndjson" }
if (-not $GatePath) { $GatePath = Join-Path $repo "Cache\debug\command_palette_perf_gate.json" }

function Get-Pct([double[]]$vals, [double]$p) {
    if ($vals.Count -eq 0) { return 0 }
    $s = @($vals | Sort-Object)
    $idx = [math]::Ceiling(($p / 100.0) * $s.Count) - 1
    if ($idx -lt 0) { $idx = 0 }
    if ($idx -ge $s.Count) { $idx = $s.Count - 1 }
    return [math]::Round($s[$idx], 2)
}

$rows = @()
if (Test-Path $LogPath) {
    Get-Content $LogPath -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line) {
            try { $rows += ($line | ConvertFrom-Json) } catch { }
        }
    }
}

$painted = @($rows | Where-Object {
    $_.event -eq "local_results_painted" -and [double]$_.durationMs -gt 0 -and -not $_.emptyResult
} | ForEach-Object { [double]$_.durationMs })

$q2p = @($rows | Where-Object {
    $_.event -eq "query_to_paint" -and [double]$_.durationMs -gt 0
} | ForEach-Object { [double]$_.durationMs })

$bySource = @{}
$rows | Where-Object { $_.event -eq "local_results_painted" } | ForEach-Object {
    $src = if ($_.source) { [string]$_.source } else { "unknown" }
    if (-not $bySource.ContainsKey($src)) { $bySource[$src] = 0 }
    $bySource[$src]++
}

$report = [ordered]@{
    logPath = $LogPath
    gatePath = if (Test-Path $GatePath) { $GatePath } else { "" }
    rowCount = $rows.Count
    localResultsPainted = @($rows | Where-Object { $_.event -eq "local_results_painted" }).Count
    queryToPaintEvents = @($rows | Where-Object { $_.event -eq "query_to_paint" }).Count
    resultsSent = @($rows | Where-Object { $_.event -eq "results_sent" }).Count
    local_input_p95 = Get-Pct $painted 95
    query_to_paint_p95 = Get-Pct $q2p 95
    paintedBySource = $bySource
    recommendation = ""
}

if ($report.local_input_p95 -gt 40 -and $report.query_to_paint_p95 -gt 40) {
    if ($report.resultsSent -gt ($report.localResultsPainted * 2)) {
        $report.recommendation = "SearchCore async turbo dominates; strip or gate async metrics separately from CP paint hot path."
    } else {
        $report.recommendation = "Both metrics high on sync path; profile CP WebView paint + command index."
    }
} elseif ($report.local_input_p95 -gt 40) {
    $report.recommendation = "local_input hot; inspect runLocalCommandSearch / layout paint in web."
} elseif ($report.query_to_paint_p95 -gt 40) {
    $report.recommendation = "query_to_paint hot; inspect query_start->turbo_results round trip."
} else {
    $report.recommendation = "P95 within threshold on valid-duration samples in log."
}

$outPath = Join-Path $repo "Cache\debug\command_palette_perf_p95_split.json"
$report | ConvertTo-Json -Depth 6 | Set-Content $outPath -Encoding UTF8

if ($JsonOnly) {
    $report | ConvertTo-Json -Depth 6
    exit 0
}

Write-Host ""
Write-Host "=== CP Perf P95 Split ===" -ForegroundColor Cyan
Write-Host ("local_input_p95:    {0} ms" -f $report.local_input_p95)
Write-Host ("query_to_paint_p95: {0} ms" -f $report.query_to_paint_p95)
Write-Host ("results_sent:       {0}" -f $report.resultsSent)
Write-Host ("recommendation:     {0}" -f $report.recommendation) -ForegroundColor Yellow
Write-Host ("report: {0}" -f $outPath) -ForegroundColor DarkGray
Write-Host ""
