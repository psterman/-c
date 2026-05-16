param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$report = Join-Path $Root "Cache\core_async_http_recovery_report.txt"
if (!(Test-Path $report)) {
    Write-Output "recovery_report_missing=$report"
    Write-Output "RESULT=SKIP"
    exit 2
}

$map = @{}
foreach ($line in (Get-Content -LiteralPath $report -Encoding UTF8)) {
    if ($line -match "=") {
        $kv = $line.Split("=",2)
        $map[$kv[0].Trim()] = $kv[1].Trim()
    }
}

$onlineOk = [int]($map["online_ok"])
$active = [int]($map["active_after"])
$retryJobs = [int]($map["retry_jobs_after"])
$timedOut = [int]($map["timed_out"])
$offlineFail = [int]($map["offline_fail"])

$checks = @(
    [pscustomobject]@{ Name="offline_phase_has_failures"; Pass=($offlineFail -gt 0); Detail="offline_fail=$offlineFail" },
    [pscustomobject]@{ Name="online_phase_recovered"; Pass=($onlineOk -gt 0); Detail="online_ok=$onlineOk" },
    [pscustomobject]@{ Name="active_zero_after"; Pass=($active -eq 0); Detail="active_after=$active" },
    [pscustomobject]@{ Name="retry_jobs_zero_after"; Pass=($retryJobs -eq 0); Detail="retry_jobs_after=$retryJobs" },
    [pscustomobject]@{ Name="not_timed_out"; Pass=($timedOut -eq 0); Detail="timed_out=$timedOut" }
)

$allPass = $true
Write-Output "== Recovery Probe Validation =="
Write-Output "report=$report"
foreach ($c in $checks) {
    $mark = if ($c.Pass) { "PASS" } else { "FAIL" }
    Write-Output ("[{0}] {1} :: {2}" -f $mark, $c.Name, $c.Detail)
    if (-not $c.Pass) { $allPass = $false }
}
if ($allPass) {
    Write-Output "RESULT=PASS"
    exit 0
}
Write-Output "RESULT=FAIL"
exit 1
