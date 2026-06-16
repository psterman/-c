param(
    [string]$Root = "",
    [switch]$Strict,
    [switch]$IncludeMemoryProbe
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Continue"
$here = $PSScriptRoot
$reportDir = Join-Path $Root "Cache\ci"
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$report = Join-Path $reportDir "minimal_gate_report.txt"
$lines = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$lines.Add("== Minimal Gate $stamp ==")
$lines.Add("root=$Root")

function Invoke-GateStep {
    param([string]$Name, [string]$ScriptName, [switch]$StepStrict)
    $scriptPath = Join-Path $here $ScriptName
    $lines.Add("")
    $lines.Add("---- $Name ----")
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        $lines.Add("BLOCKED missing=$ScriptName")
        return [pscustomobject]@{ Name = $Name; Code = 2 }
    }
    $code = 0
    try {
        Push-Location $here
        if ($StepStrict) {
            & $scriptPath -Root $Root -Strict 2>&1 | ForEach-Object { $lines.Add([string]$_) }
        } else {
            & $scriptPath -Root $Root 2>&1 | ForEach-Object { $lines.Add([string]$_) }
        }
        if ($null -ne $LASTEXITCODE) { $code = [int]$LASTEXITCODE }
    } catch {
        $lines.Add("error=$($_.Exception.Message)")
        $code = 1
    } finally {
        Pop-Location
    }
    $lines.Add("exit=$code")
    return [pscustomobject]@{ Name = $Name; Code = $code }
}

$results = @()
$results += Invoke-GateStep "SearchCore Phase1" "Run-SearchCoreLifecyclePhase1Suite.ps1" -StepStrict:$Strict
$results += Invoke-GateStep "Catch Policy" "Validate-CatchPolicy.ps1"
$results += Invoke-GateStep "Sql Policy" "Validate-SqlPolicy.ps1"
$results += Invoke-GateStep "Legacy Bypass" "Validate-LegacyBypass.ps1" -StepStrict:$Strict
$results += Invoke-GateStep "Migration Pack" "Validate-MigrationPack.ps1"
$results += Invoke-GateStep "WS Policy" "Validate-WsPolicy.ps1"
$results += Invoke-GateStep "AHK Launch Matrix" "TryAhkLaunchMatrix.ps1"
if ($IncludeMemoryProbe) {
    $memScript = Join-Path (Split-Path $here -Parent) "a2ui-diagnostics\memory\Run-ScWebEmbedProbe.ps1"
    $lines.Add("")
    $lines.Add("---- Memory Probe (optional) ----")
    if (Test-Path -LiteralPath $memScript) {
        try {
            & $memScript -Root $Root 2>&1 | ForEach-Object { $lines.Add([string]$_) }
            $memCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
        } catch {
            $lines.Add("error=$($_.Exception.Message)")
            $memCode = 1
        }
        $lines.Add("exit=$memCode")
        $results += [pscustomobject]@{ Name = "Memory Probe"; Code = $memCode }
    } else {
        $lines.Add("BLOCKED missing=Run-ScWebEmbedProbe.ps1")
        $results += [pscustomobject]@{ Name = "Memory Probe"; Code = 2 }
    }
}

$fail = $results | Where-Object { $_.Code -ne 0 }
$blocked = $results | Where-Object { $_.Code -eq 2 }
$lines.Add("")
if ($fail.Count -eq 0) {
    $lines.Add("SUITE=PASS")
    $exit = 0
} else {
    $lines.Add("SUITE=FAIL failed=$($fail.Name -join ',')")
    $exit = 1
}
if ($blocked.Count -gt 0) {
    $lines.Add("BLOCKED=$($blocked.Name -join ',')")
}

$lines | Set-Content -LiteralPath $report -Encoding UTF8
Write-Output "report=$report"
$lines | ForEach-Object { Write-Output $_ }
exit $exit
