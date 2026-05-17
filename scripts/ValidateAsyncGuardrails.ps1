param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int]$MinRequests = 500
)

$ErrorActionPreference = "Stop"

function Read-KvLine {
    param([string]$Line)
    if ($Line -notmatch "=") { return $null }
    $parts = $Line.Split("=", 2)
    return [pscustomobject]@{ Key = $parts[0].Trim(); Value = $parts[1].Trim() }
}

function Parse-StressReport {
    param([string]$Path)
    if (!(Test-Path $Path)) { return $null }
    $raw = Get-Content -LiteralPath $Path -Encoding UTF8
    $map = @{}
    foreach ($line in $raw) {
        $kv = Read-KvLine -Line $line
        if ($null -ne $kv) { $map[$kv.Key] = $kv.Value }
    }
    return $map
}

function Count-LogPattern {
    param(
        [string]$Path,
        [string]$Pattern
    )
    if (!(Test-Path $Path)) { return 0 }
    return (Select-String -LiteralPath $Path -Pattern $Pattern -SimpleMatch | Measure-Object).Count
}

$cacheDir = Join-Path $Root "Cache"
$stressReport = Join-Path $cacheDir "core_async_http_stress_report.txt"
$coreLog = Join-Path $cacheDir "core_async_http.log"

$lastStartPath = Join-Path $cacheDir "core_async_http_stress_last_start.txt"
$report = Parse-StressReport -Path $stressReport
if ($null -eq $report) {
    Write-Output "== Async Guardrails Validation =="
    Write-Output "stress_report_missing=$stressReport"
    Write-Output "RESULT=SKIP"
    exit 2
}

$lastStartTotal = 0
if (Test-Path $lastStartPath) {
    foreach ($line in (Get-Content -LiteralPath $lastStartPath -Encoding UTF8)) {
        if ($line -match "total=(\d+)") { $lastStartTotal = [int]$Matches[1] }
    }
}

$total = [int]($report["total"])
$done = [int]($report["done"])
$timedOut = [int]($report["timed_out"])
$activeAfter = [int]($report["active_after"])
$retryJobsAfter = [int]($report["retry_jobs_after"])

$retryingCount = Count-LogPattern -Path $coreLog -Pattern "[async_http_retrying]"
$cancelCount = Count-LogPattern -Path $coreLog -Pattern "[async_http_cancelled]"
$timeoutCount = Count-LogPattern -Path $coreLog -Pattern "[async_http_timeout]"
$doneCount = Count-LogPattern -Path $coreLog -Pattern "[async_http_done]"

$checks = @(
    [pscustomobject]@{ Name = "total_requests"; Pass = ($total -ge $MinRequests); Detail = "total=$total min=$MinRequests" },
    [pscustomobject]@{ Name = "last_start_not_smoke"; Pass = ($lastStartTotal -eq 0 -or $lastStartTotal -ge $MinRequests); Detail = "last_start_total=$lastStartTotal min=$MinRequests" },
    [pscustomobject]@{ Name = "all_done"; Pass = ($done -eq $total); Detail = "done=$done total=$total" },
    [pscustomobject]@{ Name = "not_timed_out"; Pass = ($timedOut -eq 0); Detail = "timed_out=$timedOut" },
    [pscustomobject]@{ Name = "active_zero_after"; Pass = ($activeAfter -eq 0); Detail = "active_after=$activeAfter" },
    [pscustomobject]@{ Name = "retry_jobs_zero_after"; Pass = ($retryJobsAfter -eq 0); Detail = "retry_jobs_after=$retryJobsAfter" },
    [pscustomobject]@{ Name = "has_done_logs"; Pass = ($doneCount -gt 0); Detail = "done_logs=$doneCount" }
)

$allPass = $true
Write-Output "== Async Guardrails Validation =="
Write-Output "root=$Root"
Write-Output "stress_report=$stressReport"
Write-Output "core_log=$coreLog"
Write-Output ""
foreach ($c in $checks) {
    $mark = if ($c.Pass) { "PASS" } else { "FAIL" }
    Write-Output ("[{0}] {1} :: {2}" -f $mark, $c.Name, $c.Detail)
    if (-not $c.Pass) { $allPass = $false }
}

Write-Output ""
Write-Output "log_counters: retrying=$retryingCount cancelled=$cancelCount timeout=$timeoutCount done=$doneCount"

if ($allPass) {
    Write-Output "RESULT=PASS"
    exit 0
}

Write-Output "RESULT=FAIL"
exit 1
