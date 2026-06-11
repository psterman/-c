# CommandPalette perf gate: analyze command_palette_perf.ndjson
param(
    [string]$LogPath = "",
    [switch]$Strict,
    [switch]$JsonOnly,
    [switch]$ExpectDiscreteLayout,
    [int]$MinRows = 10,
    [int]$MinPaintSamples = 5,
    [int]$MaxContinuousResize = 0,
    [int]$MaxLayoutModeResize = 40
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = (Resolve-Path (Join-Path $here "..\..")).Path
if (-not $LogPath) {
    $LogPath = Join-Path $repo "Cache\debug\command_palette_perf.ndjson"
}

function Get-Percentile([double[]]$values, [double]$p) {
    if (-not $values -or $values.Count -eq 0) { return 0 }
    $sorted = $values | Sort-Object
    $idx = [math]::Ceiling(($p / 100.0) * $sorted.Count) - 1
    if ($idx -lt 0) { $idx = 0 }
    if ($idx -ge $sorted.Count) { $idx = $sorted.Count - 1 }
    return [double]$sorted[$idx]
}

function Test-MaxThreshold($name, $value, $limit, [ref]$failures, [switch]$FailWhenZero) {
    if ($FailWhenZero -and ($value -le 0)) {
        [void]$failures.Value.Add("${name}=missing (0 samples)")
        return @{
            name = $name
            value = [math]::Round($value, 2)
            limit = $limit
            pass = $false
        }
    }
    $pass = ($value -le $limit)
    if (-not $pass) { [void]$failures.Value.Add("${name}=${value} > ${limit}") }
    return @{
        name = $name
        value = [math]::Round($value, 2)
        limit = $limit
        pass = $pass
    }
}

function Test-MinThreshold($name, $value, $minimum, [ref]$failures) {
    $pass = ($value -ge $minimum)
    if (-not $pass) { [void]$failures.Value.Add("${name}=${value} < ${minimum}") }
    return @{
        name = $name
        value = $value
        limit = $minimum
        pass = $pass
    }
}

function Get-PaletteFlagsFromRepo([string]$root) {
    $path = Join-Path $root "local\nmer-flags.json"
    if (-not (Test-Path $path)) { return $null }
    try {
        return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $null
    }
}

$flags = Get-PaletteFlagsFromRepo $repo
$discreteEnabled = $false
$fastInputEnabled = $false
if ($flags -and $flags.palette) {
    $discreteEnabled = [bool]$flags.palette.discreteLayout
    $fastInputEnabled = [bool]$flags.palette.fastInput
}
if ($ExpectDiscreteLayout) { $discreteEnabled = $true }

$rows = @()
if (Test-Path $LogPath) {
    Get-Content $LogPath -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if (-not $line) { return }
        try {
            $obj = $line | ConvertFrom-Json
            $rows += $obj
        } catch {}
    }
}

$byEvent = @{}
foreach ($r in $rows) {
    $ev = [string]$r.event
    if (-not $ev) { continue }
    if (-not $byEvent.ContainsKey($ev)) {
        $byEvent[$ev] = New-Object System.Collections.Generic.List[double]
    }
    $dur = 0.0
    if ($null -ne $r.durationMs) { $dur = [double]$r.durationMs }
    if ($dur -gt 0) {
        [void]$byEvent[$ev].Add($dur)
    }
}

$stats = @{}
foreach ($kv in $byEvent.GetEnumerator()) {
    $vals = @($kv.Value.ToArray())
    $stats[$kv.Key] = @{
        count = $vals.Count
        p50 = [math]::Round((Get-Percentile $vals 50), 2)
        p95 = [math]::Round((Get-Percentile $vals 95), 2)
        max = [math]::Round(($vals | Measure-Object -Maximum).Maximum, 2)
    }
}

$syncPullCount = @($rows | Where-Object { $_.event -eq "sync_pull_agent_cards" }).Count
$resizeRows = @($rows | Where-Object { $_.event -eq "resize_applied" })
$resizeContinuousCount = @($resizeRows | Where-Object { [string]$_.layoutMode -eq "continuous" }).Count
$resizeDiscreteCount = @($resizeRows | Where-Object {
    $m = [string]$_.layoutMode
    $m -eq "compact" -or $m -eq "list" -or $m -eq "detail"
}).Count
$layoutRequestedCount = @($rows | Where-Object { $_.event -eq "layout_mode_requested" }).Count

$paintCount = 0
if ($stats.ContainsKey("local_results_painted")) { $paintCount += [int]$stats["local_results_painted"].count }
if ($stats.ContainsKey("query_to_paint")) { $paintCount += [int]$stats["query_to_paint"].count }

$failures = New-Object System.Collections.Generic.List[string]
$checks = @()

$checks += Test-MinThreshold "row_count_min" $rows.Count $MinRows ([ref]$failures)

$localP95 = if ($stats.ContainsKey("local_results_painted")) { $stats["local_results_painted"].p95 } else { 0 }
$queryP95 = if ($stats.ContainsKey("query_to_paint")) { $stats["query_to_paint"].p95 } else { 0 }
$showP95 = if ($stats.ContainsKey("show_to_visible")) { $stats["show_to_visible"].p95 } else { 0 }

if ($Strict) {
    $checks += Test-MaxThreshold "local_input_p95" $localP95 40 ([ref]$failures) -FailWhenZero
    $checks += Test-MaxThreshold "query_to_paint_p95" $queryP95 40 ([ref]$failures) -FailWhenZero
} else {
    $checks += Test-MaxThreshold "local_input_p95" $localP95 40 ([ref]$failures)
    $checks += Test-MaxThreshold "query_to_paint_p95" $queryP95 40 ([ref]$failures)
}
$checks += Test-MaxThreshold "show_to_visible_p95" $showP95 100 ([ref]$failures)
$checks += Test-MinThreshold "paint_samples_min" $paintCount $MinPaintSamples ([ref]$failures)

$syncPass = ($syncPullCount -eq 0)
if (-not $syncPass) {
    [void]$failures.Add("sync_pull_agent_cards=${syncPullCount} > 0")
}

$continuousPass = ($resizeContinuousCount -le $MaxContinuousResize)
if ($discreteEnabled -and -not $continuousPass) {
    [void]$failures.Add("resize_continuous=${resizeContinuousCount} > max=${MaxContinuousResize} (discreteLayout on)")
}

$layoutPass = $true
if ($discreteEnabled -and $resizeDiscreteCount -gt $MaxLayoutModeResize) {
    $layoutPass = $false
    [void]$failures.Add("resize_discrete=${resizeDiscreteCount} > max=${MaxLayoutModeResize}")
}

$report = [ordered]@{
    logPath = $LogPath
    rowCount = $rows.Count
    stats = $stats
    checks = $checks
    syncPullCount = $syncPullCount
    syncPullPass = $syncPass
    resizeContinuousCount = $resizeContinuousCount
    resizeDiscreteCount = $resizeDiscreteCount
    layoutModeRequestedCount = $layoutRequestedCount
    resizeContinuousPass = $continuousPass
    resizeDiscretePass = $layoutPass
    paintSampleCount = $paintCount
    paletteFlags = @{
        fastInput = $fastInputEnabled
        discreteLayout = $discreteEnabled
    }
    overallPass = ($failures.Count -eq 0)
    failures = @($failures)
    generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$outPath = Join-Path $repo "Cache\debug\command_palette_perf_gate.json"
$dir = Split-Path $outPath -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$report | ConvertTo-Json -Depth 8 | Set-Content -Path $outPath -Encoding UTF8

if ($JsonOnly) {
    $report | ConvertTo-Json -Depth 8
    if ($Strict -and -not $report.overallPass) { exit 1 }
    exit 0
}

Write-Host ""
Write-Host "=== CommandPalette Perf Gate ===" -ForegroundColor Cyan
Write-Host ("log: {0}" -f $LogPath)
Write-Host ("rows: {0}" -f $report.rowCount)
Write-Host ("flags: fastInput={0} discreteLayout={1}" -f $fastInputEnabled, $discreteEnabled) -ForegroundColor DarkGray
if ($report.rowCount -eq 0) {
    Write-Host ""
    Write-Host "WARN: no perf rows. Reload niuma.ahk, open CP, type 20 chars, then close CP." -ForegroundColor Yellow
    Write-Host "      Empty log cannot PASS under -Strict." -ForegroundColor Yellow
}
Write-Host ""
foreach ($c in $checks) {
    $color = if ($c.pass) { "Green" } else { "Red" }
    $isMin = $c.name -match "_min$"
    $op = if ($isMin) { ">=" } else { "<=" }
    Write-Host ("  {0}: {1} (need {2}{3}) -> {4}" -f $c.name, $c.value, $op, $c.limit, ($(if ($c.pass) { "PASS" } else { "FAIL" }))) -ForegroundColor $color
}
$syncColor = if ($syncPass) { "Green" } else { "Red" }
Write-Host ("  sync_pull_agent_cards: {0} -> {1}" -f $syncPullCount, ($(if ($syncPass) { "PASS" } else { "FAIL" }))) -ForegroundColor $syncColor
$contColor = if ($continuousPass) { "Green" } else { "Red" }
Write-Host ("  resize_continuous: {0} (max {1}) -> {2}" -f $resizeContinuousCount, $MaxContinuousResize, ($(if ($continuousPass) { "PASS" } else { "FAIL" }))) -ForegroundColor $contColor
$discColor = if ($layoutPass) { "Green" } else { "Yellow" }
Write-Host ("  resize_discrete: {0} | layout_mode_requested: {1} -> {2}" -f $resizeDiscreteCount, $layoutRequestedCount, ($(if ($layoutPass) { "PASS" } else { "WARN" }))) -ForegroundColor $discColor
Write-Host ""
Write-Host ("overall: {0}" -f ($(if ($report.overallPass) { "PASS" } else { "FAIL" }))) -ForegroundColor ($(if ($report.overallPass) { "Green" } else { "Red" }))
Write-Host ("report: {0}" -f $outPath)
Write-Host ""

if ($Strict -and -not $report.overallPass) { exit 1 }
exit 0
