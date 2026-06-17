param(
    [string]$Root = "",
    [switch]$ResetState,
    [switch]$Strict,
    [switch]$AutoTrigger,
    [int]$AutoTriggerWaitSec = 8,
    [int]$AutoTriggerPollSec = 120
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1", "..\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) {
    if (Get-Command Nmer-ResolveProjectRoot -ErrorAction SilentlyContinue) {
        $Root = Nmer-ResolveProjectRoot $PSScriptRoot
    } else {
        $Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    }
}

$reportDir = Join-Path $Root "Cache\ci"
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$reportPath = Join-Path $reportDir "telemetry_e2e_report.txt"
$autoScript = Join-Path $PSScriptRoot "Run-TelemetryAutoTrigger.ps1"
$targetedScript = Join-Path $PSScriptRoot "Run-TelemetryTargeted.ps1"
$selfTestScript = Join-Path $PSScriptRoot "Run-TelemetrySelfTest.ps1"

$lines = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$lines.Add("== Telemetry E2E $stamp ==")
$lines.Add("root=$Root")
$lines.Add("resetState=$([bool]$ResetState)")
$lines.Add("strict=$([bool]$Strict)")
$lines.Add("autoTrigger=$([bool]$AutoTrigger)")
$lines.Add("")

function Add-Section {
    param([string]$title, [string[]]$content)
    $lines.Add("---- $title ----")
    foreach ($ln in $content) {
        $lines.Add($ln)
    }
    $lines.Add("")
}

if (-not (Test-Path -LiteralPath $targetedScript)) {
    $lines.Add("[FAIL] missing_script -- $targetedScript")
    $lines | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Output "report=$reportPath"
    $lines | ForEach-Object { Write-Output $_ }
    exit 1
}
if (-not (Test-Path -LiteralPath $selfTestScript)) {
    $lines.Add("[FAIL] missing_script -- $selfTestScript")
    $lines | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Output "report=$reportPath"
    $lines | ForEach-Object { Write-Output $_ }
    exit 1
}
if ($AutoTrigger -and -not (Test-Path -LiteralPath $autoScript)) {
    $lines.Add("[FAIL] missing_script -- $autoScript")
    $lines | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Output "report=$reportPath"
    $lines | ForEach-Object { Write-Output $_ }
    exit 1
}

if ($AutoTrigger) {
    $autoArgs = @(
        "-NoProfile", "-File", $autoScript,
        "-Root", $Root,
        "-WaitSec", $AutoTriggerWaitSec,
        "-PollSec", $AutoTriggerPollSec
    )
    $autoOut = & powershell @autoArgs 2>&1
    $autoExit = $LASTEXITCODE
    Add-Section -title "Run-TelemetryAutoTrigger.ps1 (exit=$autoExit)" -content ($autoOut | ForEach-Object { "$_" })
    if ($autoExit -ne 0) {
        $lines.Add("auto_trigger=FAIL exit=$autoExit (skip targeted/selftest until main process passes auto trigger)")
        $lines | Set-Content -LiteralPath $reportPath -Encoding UTF8
        Write-Output "report=$reportPath"
        $lines | ForEach-Object { Write-Output $_ }
        exit 1
    }
}

$targetedArgs = @("-NoProfile", "-File", $targetedScript, "-Root", $Root)
if ($ResetState) { $targetedArgs += "-ResetState" }
$targetedOut = & powershell @targetedArgs 2>&1
$targetedExit = $LASTEXITCODE
Add-Section -title "Run-TelemetryTargeted.ps1 (exit=$targetedExit)" -content ($targetedOut | ForEach-Object { "$_" })

$selfArgs = @("-NoProfile", "-File", $selfTestScript, "-Root", $Root)
if ($Strict) { $selfArgs += "-Strict" }
$selfOut = & powershell @selfArgs 2>&1
$selfExit = $LASTEXITCODE
Add-Section -title "Run-TelemetrySelfTest.ps1 (exit=$selfExit)" -content ($selfOut | ForEach-Object { "$_" })

$targetedResult = "UNKNOWN"
$selfResult = "UNKNOWN"
foreach ($ln in $targetedOut) {
    if ("$ln" -like "result=*") {
        $targetedResult = "$ln".Substring(7)
    }
}
foreach ($ln in $selfOut) {
    if ("$ln" -like "result=*") {
        $selfResult = "$ln".Substring(7)
    }
}

$lines.Add("---- Final Summary ----")
$lines.Add("targeted_exit=$targetedExit targeted_result=$targetedResult")
$lines.Add("selftest_exit=$selfExit selftest_result=$selfResult")

$exitCode = 0
if ($targetedExit -ne 0 -or $selfExit -ne 0) {
    $exitCode = 1
    $lines.Add("overall=FAIL")
} else {
    $lines.Add("overall=PASS")
}

$lines | Set-Content -LiteralPath $reportPath -Encoding UTF8
Write-Output "report=$reportPath"
$lines | ForEach-Object { Write-Output $_ }
exit $exitCode

