param(
    [string]$Root = ""
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"

$choice = Nmer-ReadAhkLaunchChoice -Root $Root
if ($null -eq $choice -or -not (Test-Path -LiteralPath $choice.Exe)) {
    Write-Output "ahk_launch_choice_missing=1"
    Write-Output "hint=Run tools/ci/TryAhkLaunchMatrix.ps1 first"
    Write-Output "RESULT=SKIP"
    exit 2
}

$probe = Nmer-ResolveCiScript -Root $Root -RelativeName "SearchCoreLifecycleProbe.ahk"
if (-not (Test-Path -LiteralPath $probe)) {
    throw "Probe not found: $probe"
}

$report = Join-Path $Root "Cache\searchcore_lifecycle_probe_report.txt"
if (Test-Path -LiteralPath $report) { Remove-Item -LiteralPath $report -Force -ErrorAction SilentlyContinue }

Write-Output "searchcore_lifecycle_probe_start probe=$probe"
$exitCode = Nmer-InvokeSearchCoreProbe -Root $Root -ProbeRelativeName "SearchCoreLifecycleProbe.ahk"
Write-Output ("probe_exit=" + $exitCode)

if (Test-Path -LiteralPath $report) {
    Get-Content -LiteralPath $report -Encoding UTF8
} else {
    $fallback = Join-Path $env:TEMP "searchcore_lifecycle_probe_report.txt"
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

$reportOk = (Test-Path -LiteralPath $report)
$fallback = Join-Path $env:TEMP "searchcore_lifecycle_probe_report.txt"
if (-not $reportOk) {
    $reportOk = (Test-Path -LiteralPath $fallback)
}
if (-not $reportOk) {
    Write-Output "probe_report_missing=$report"
    Write-Output "RESULT=FAIL"
    exit 1
}

Write-Output "RESULT=PASS"
exit 0
