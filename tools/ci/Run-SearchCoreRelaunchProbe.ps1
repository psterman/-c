param(
    [string]$Root = ""
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"

$report = Join-Path $Root "Cache\searchcore_relaunch_probe_report.txt"
if (Test-Path -LiteralPath $report) { Remove-Item -LiteralPath $report -Force -ErrorAction SilentlyContinue }

Write-Output "searchcore_relaunch_probe_start"
$exitCode = Nmer-InvokeSearchCoreProbe -Root $Root -ProbeRelativeName "SearchCoreRelaunchProbe.ahk"
Write-Output ("probe_exit=" + $exitCode)

if (Test-Path -LiteralPath $report) {
    Get-Content -LiteralPath $report -Encoding UTF8
} else {
    $fallback = Join-Path $env:TEMP "searchcore_relaunch_probe_report.txt"
    if (Test-Path -LiteralPath $fallback) {
        Write-Output "probe_report_fallback=$fallback"
        Get-Content -LiteralPath $fallback -Encoding UTF8
    } else {
        Write-Output "probe_report_missing=$report"
    }
}

if ($exitCode -ne 0) {
    Write-Output "RESULT=FAIL"
    exit 1
}
if (-not (Test-Path -LiteralPath $report) -and -not (Test-Path -LiteralPath (Join-Path $env:TEMP "searchcore_relaunch_probe_report.txt"))) {
    Write-Output "RESULT=FAIL"
    exit 1
}
Write-Output "RESULT=PASS"
exit 0
