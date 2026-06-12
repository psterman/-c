# CommandPalette perf gate: Stage 1 pipeline + Stage 2 performance thresholds
param(
    [string]$LogPath = "",
    [switch]$Strict,
    [switch]$JsonOnly,
    [switch]$ExpectDiscreteLayout,
    [int]$MinRows = 10,
    [int]$MinPaintSamples = 5,
    [int]$SkipFirstPaintSamples = 0,
    [int]$MaxContinuousResize = 0,
    [int]$MaxLayoutModeResize = 40
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
. (Join-Path $PSScriptRoot "Test-CpPerfPipeline.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Get-DiagRepoRoot -From $here
if (-not $LogPath) {
    $LogPath = Join-Path $repo "Cache\debug\command_palette_perf.ndjson"
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

$rows = @(Get-CpPerfLogRows $LogPath)
$pipeline = Invoke-CpPerfPipelineTest -Rows $rows -LogPath $LogPath -MinPaintSamples $MinPaintSamples -MinRows $MinRows

$perfRows = if ($SkipFirstPaintSamples -gt 0) {
    @(Get-CpPerfRowsSkipFirstPaintEvents -Rows $rows -SkipFirst $SkipFirstPaintSamples)
} else { $rows }

$localStats = Get-CpPerfEventStats $perfRows @("local_results_painted")
$queryStats = Get-CpPerfEventStats $perfRows @("query_to_paint")
$showStats = Get-CpPerfEventStats $gateRows @("show_to_visible")

$stats = @{
    local_results_painted = $localStats
    query_to_paint = $queryStats
    show_to_visible = $showStats
}

$resizeRows = @($rows | Where-Object { $_.event -eq "resize_applied" })
$resizeContinuousCount = @($resizeRows | Where-Object { [string]$_.layoutMode -eq "continuous" }).Count
$resizeDiscreteCount = @($resizeRows | Where-Object {
    $m = [string]$_.layoutMode
    $m -eq "compact" -or $m -eq "list" -or $m -eq "detail"
}).Count
$layoutRequestedCount = @($rows | Where-Object { $_.event -eq "layout_mode_requested" }).Count

$perfFailures = New-Object System.Collections.Generic.List[string]
$perfChecks = @()
$performancePass = $null
$failReason = $pipeline.failReason

if ($pipeline.pipelinePass) {
    $localP95 = $localStats.p95
    $queryP95 = $queryStats.p95
    $showP95 = $showStats.p95

    if ($Strict) {
        $perfChecks += Test-MaxThreshold "local_input_p95" $localP95 40 ([ref]$perfFailures) -FailWhenZero
        $perfChecks += Test-MaxThreshold "query_to_paint_p95" $queryP95 40 ([ref]$perfFailures) -FailWhenZero
    } else {
        $perfChecks += Test-MaxThreshold "local_input_p95" $localP95 40 ([ref]$perfFailures)
        $perfChecks += Test-MaxThreshold "query_to_paint_p95" $queryP95 40 ([ref]$perfFailures)
    }
    $perfChecks += Test-MaxThreshold "show_to_visible_p95" $showP95 100 ([ref]$perfFailures)

    $continuousPass = ($resizeContinuousCount -le $MaxContinuousResize)
    if ($discreteEnabled -and -not $continuousPass) {
        [void]$perfFailures.Add("resize_continuous=${resizeContinuousCount} > max=${MaxContinuousResize} (discreteLayout on)")
    }

    $layoutPass = $true
    if ($discreteEnabled -and $resizeDiscreteCount -gt $MaxLayoutModeResize) {
        $layoutPass = $false
        [void]$perfFailures.Add("resize_discrete=${resizeDiscreteCount} > max=${MaxLayoutModeResize}")
    }

    $performancePass = ($perfFailures.Count -eq 0)
    if (-not $performancePass) { $failReason = "performance_fail" }
} else {
    $continuousPass = ($resizeContinuousCount -le $MaxContinuousResize)
    $layoutPass = -not ($discreteEnabled -and $resizeDiscreteCount -gt $MaxLayoutModeResize)
}

$overallPass = ($pipeline.pipelinePass -and ($performancePass -eq $true))

$report = [ordered]@{
    logPath = $LogPath
    rowCount = $rows.Count
    stats = $stats
    pipelineChecks = $pipeline.checks
    performanceChecks = $perfChecks
    pipelinePass = $pipeline.pipelinePass
    performancePass = $performancePass
    paintSamples = $pipeline.paintSamples
    validDurationSamples = $pipeline.validDurationSamples
    paletteReadyCount = $pipeline.paletteReadyCount
    queryStartCount = $pipeline.queryStartCount
    localResultsPaintedCount = $pipeline.localResultsPaintedCount
    syncPullCount = $pipeline.syncPullCount
    syncPullPass = ($pipeline.syncPullCount -eq 0)
    resizeContinuousCount = $resizeContinuousCount
    resizeDiscreteCount = $resizeDiscreteCount
    layoutModeRequestedCount = $layoutRequestedCount
    resizeContinuousPass = $continuousPass
    resizeDiscretePass = $layoutPass
    paletteFlags = @{
        fastInput = $fastInputEnabled
        discreteLayout = $discreteEnabled
    }
    checks = @($pipeline.checks) + @($perfChecks)
    pipelineFailures = $pipeline.failures
    performanceFailures = @($perfFailures)
    failures = @($pipeline.failures) + @($perfFailures)
    failReason = $failReason
    overallPass = $overallPass
    skipFirstPaintSamples = $SkipFirstPaintSamples
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
Write-Host "Stage 1 — pipeline" -ForegroundColor Cyan
foreach ($c in $pipeline.checks) {
    $color = if ($c.pass) { "Green" } else { "Red" }
    Write-Host ("  {0}: {1} -> {2}" -f $c.name, $c.value, ($(if ($c.pass) { "PASS" } else { "FAIL" }))) -ForegroundColor $color
}
$pipeColor = if ($pipeline.pipelinePass) { "Green" } else { "Red" }
Write-Host ("  pipelinePass: {0}" -f $pipeline.pipelinePass) -ForegroundColor $pipeColor
if (-not $pipeline.pipelinePass -and $pipeline.failReason) {
    Write-Host ("  reason: {0} (not performance_fail)" -f $pipeline.failReason) -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Stage 2 — performance" -ForegroundColor Cyan
if ($null -eq $performancePass) {
    Write-Host "  skipped (pipeline not ready)" -ForegroundColor DarkGray
} else {
    foreach ($c in $perfChecks) {
        $color = if ($c.pass) { "Green" } else { "Red" }
        Write-Host ("  {0}: {1} (need <= {2}) -> {3}" -f $c.name, $c.value, $c.limit, ($(if ($c.pass) { "PASS" } else { "FAIL" }))) -ForegroundColor $color
    }
    $syncColor = if ($report.syncPullPass) { "Green" } else { "Red" }
    Write-Host ("  sync_pull_agent_cards: {0} -> {1}" -f $report.syncPullCount, ($(if ($report.syncPullPass) { "PASS" } else { "FAIL" }))) -ForegroundColor $syncColor
    $contColor = if ($continuousPass) { "Green" } else { "Red" }
    Write-Host ("  resize_continuous: {0} (max {1}) -> {2}" -f $resizeContinuousCount, $MaxContinuousResize, ($(if ($continuousPass) { "PASS" } else { "FAIL" }))) -ForegroundColor $contColor
    $discColor = if ($layoutPass) { "Green" } else { "Yellow" }
    Write-Host ("  resize_discrete: {0} | layout_mode_requested: {1} -> {2}" -f $resizeDiscreteCount, $layoutRequestedCount, ($(if ($layoutPass) { "PASS" } else { "WARN" }))) -ForegroundColor $discColor
    $perfColor = if ($performancePass) { "Green" } else { "Red" }
    Write-Host ("  performancePass: {0}" -f $performancePass) -ForegroundColor $perfColor
}
Write-Host ""
Write-Host ("paint_samples: {0} | valid_duration: {1}" -f $report.paintSamples, $report.validDurationSamples) -ForegroundColor DarkGray
Write-Host ("overall: {0}" -f ($(if ($report.overallPass) { "PASS" } else { "FAIL" }))) -ForegroundColor ($(if ($report.overallPass) { "Green" } else { "Red" }))
if ($report.failReason) {
    Write-Host ("failReason: {0}" -f $report.failReason) -ForegroundColor Yellow
}
Write-Host ("report: {0}" -f $outPath)
Write-Host ""

if ($Strict -and -not $report.overallPass) { exit 1 }
exit 0
