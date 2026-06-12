# CP perf pipeline health (Stage 1): sampling validity before P95 thresholds
param(
    [string]$LogPath = "",
    [int]$MinPaintSamples = 5,
    [int]$MinRows = 10,
    [switch]$JsonOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Get-DiagRepoRoot -From $here
if (-not $LogPath) {
    $LogPath = Join-Path $repo "Cache\debug\command_palette_perf.ndjson"
}

function Get-CpPerfLogRows([string]$path) {
    $rows = @()
    if (-not (Test-Path $path)) { return $rows }
    Get-Content $path -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if (-not $line) { return }
        try { $rows += ($line | ConvertFrom-Json) } catch { }
    }
    return $rows
}

function Test-CpPerfValidDurationRow($row) {
    if ($null -eq $row) { return $false }
    $dur = 0.0
    if ($null -ne $row.durationMs) { $dur = [double]$row.durationMs }
    if ($dur -le 0) { return $false }
    if ($row.PSObject.Properties.Name -contains "emptyResult" -and [bool]$row.emptyResult) { return $false }
    return $true
}

function Get-CpPerfEventStats([array]$rows, [string[]]$eventNames) {
    $valid = @($rows | Where-Object {
        $ev = [string]$_.event
        if ($eventNames -notcontains $ev) { return $false }
        return (Test-CpPerfValidDurationRow $_)
    } | ForEach-Object { [double]$_.durationMs })
    if ($valid.Count -eq 0) {
        return @{ count = 0; p50 = 0; p95 = 0; max = 0 }
    }
    $sorted = @($valid | Sort-Object)
    function Get-Pct([double]$p) {
        $idx = [math]::Ceiling(($p / 100.0) * $sorted.Count) - 1
        if ($idx -lt 0) { $idx = 0 }
        if ($idx -ge $sorted.Count) { $idx = $sorted.Count - 1 }
        return [double]$sorted[$idx]
    }
    return @{
        count = $valid.Count
        p50   = [math]::Round((Get-Pct 50), 2)
        p95   = [math]::Round((Get-Pct 95), 2)
        max   = [math]::Round(($valid | Measure-Object -Maximum).Maximum, 2)
    }
}

function Invoke-CpPerfPipelineTest {
    param(
        [array]$Rows,
        [string]$LogPath,
        [int]$MinPaintSamples = 5,
        [int]$MinRows = 10
    )

    $failures = New-Object System.Collections.Generic.List[string]
    $checks = @()

    $ndjsonExists = Test-Path $LogPath
    $checks += @{ name = "ndjson_exists"; value = $ndjsonExists; limit = $true; pass = $ndjsonExists }
    if (-not $ndjsonExists) { [void]$failures.Add("ndjson_exists=false") }

    $paletteReadyCount = @($Rows | Where-Object { $_.event -eq "palette_ready" }).Count
    $queryStartCount = @($Rows | Where-Object { $_.event -eq "query_start" }).Count
    $paintedRows = @($Rows | Where-Object { $_.event -eq "local_results_painted" })
    $paintedCount = $paintedRows.Count
    $paintSamples = $paintedCount
    $validDurationSamples = @($Rows | Where-Object { Test-CpPerfValidDurationRow $_ }).Count

    $checks += @{ name = "palette_ready_count"; value = $paletteReadyCount; limit = 1; pass = ($paletteReadyCount -gt 0) }
    if ($paletteReadyCount -le 0) { [void]$failures.Add("palette_ready_count=0") }

    $checks += @{ name = "query_start_count"; value = $queryStartCount; limit = 1; pass = ($queryStartCount -gt 0) }
    if ($queryStartCount -le 0) { [void]$failures.Add("query_start_count=0") }

    $checks += @{ name = "local_results_painted_count"; value = $paintedCount; limit = 1; pass = ($paintedCount -gt 0) }
    if ($paintedCount -le 0) { [void]$failures.Add("local_results_painted_count=0") }

    $checks += @{ name = "paint_samples"; value = $paintSamples; limit = $MinPaintSamples; pass = ($paintSamples -ge $MinPaintSamples) }
    if ($paintSamples -lt $MinPaintSamples) { [void]$failures.Add("paint_samples=${paintSamples} < ${MinPaintSamples}") }

    $checks += @{ name = "row_count_min"; value = $Rows.Count; limit = $MinRows; pass = ($Rows.Count -ge $MinRows) }
    if ($Rows.Count -lt $MinRows) { [void]$failures.Add("row_count_min=$($Rows.Count) < $MinRows") }

    $syncPullCount = @($Rows | Where-Object { $_.event -eq "sync_pull_agent_cards" }).Count
    $syncPass = ($syncPullCount -eq 0)
    $checks += @{ name = "sync_pull_agent_cards"; value = $syncPullCount; limit = 0; pass = $syncPass }
    if (-not $syncPass) { [void]$failures.Add("sync_pull_agent_cards=${syncPullCount} > 0") }

    $pipelinePass = ($failures.Count -eq 0)
    $reason = if (-not $pipelinePass) {
        if ($paintSamples -eq 0 -or $paintedCount -eq 0) { "no_paint_samples" } else { "perf_pipeline_fail" }
    } else { $null }

    return [ordered]@{
        logPath                = $LogPath
        rowCount               = $Rows.Count
        pipelinePass           = $pipelinePass
        performancePass        = $null
        paintSamples           = $paintSamples
        validDurationSamples   = $validDurationSamples
        paletteReadyCount      = $paletteReadyCount
        queryStartCount        = $queryStartCount
        localResultsPaintedCount = $paintedCount
        syncPullCount          = $syncPullCount
        checks                 = $checks
        failures               = @($failures)
        failReason             = $reason
        stage                  = "pipeline"
        generatedAt            = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $rows = @(Get-CpPerfLogRows $LogPath)
    $report = Invoke-CpPerfPipelineTest -Rows $rows -LogPath $LogPath -MinPaintSamples $MinPaintSamples -MinRows $MinRows

    $outPath = Join-Path $repo "Cache\debug\command_palette_perf_pipeline.json"
    $dir = Split-Path $outPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $report | ConvertTo-Json -Depth 8 | Set-Content -Path $outPath -Encoding UTF8

    if ($JsonOnly) {
        $report | ConvertTo-Json -Depth 8
        if (-not $report.pipelinePass) { exit 1 }
        exit 0
    }

    Write-Host ""
    Write-Host "=== CP Perf Pipeline (Stage 1) ===" -ForegroundColor Cyan
    Write-Host ("log: {0}" -f $LogPath)
    Write-Host ("rows: {0} | paint_samples: {1} | valid_duration: {2}" -f $report.rowCount, $report.paintSamples, $report.validDurationSamples)
    foreach ($c in $report.checks) {
        $color = if ($c.pass) { "Green" } else { "Red" }
        Write-Host ("  {0}: {1} -> {2}" -f $c.name, $c.value, ($(if ($c.pass) { "PASS" } else { "FAIL" }))) -ForegroundColor $color
    }
    Write-Host ""
    Write-Host ("pipelinePass: {0}" -f $report.pipelinePass) -ForegroundColor ($(if ($report.pipelinePass) { "Green" } else { "Red" }))
    if ($report.failReason) {
        Write-Host ("reason: {0}" -f $report.failReason) -ForegroundColor Yellow
    }
    Write-Host ("report: {0}" -f $outPath)
    Write-Host ""

    if (-not $report.pipelinePass) { exit 1 }
    exit 0
}
