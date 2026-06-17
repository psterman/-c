param(
    [string]$Root = "",
    [switch]$Required
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Continue"
$here = $PSScriptRoot
$html = Join-Path $Root "html"
$reportDir = Join-Path $Root "Cache\ci"
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

function Resolve-NodeExe {
    $cmd = Get-Command node -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($p in @(
            (Join-Path ${env:ProgramFiles} "nodejs\node.exe"),
            (Join-Path ${env:ProgramFiles(x86)} "nodejs\node.exe")
        )) {
        if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    }
    return $null
}

function Invoke-Phase3Step {
    param([string]$Name, [scriptblock]$Run)
    Write-Host ""
    Write-Host "======== $Name ========"
    $code = 0
    try {
        & $Run 2>&1 | ForEach-Object { Write-Host $_ }
        if ($null -ne $LASTEXITCODE) { $code = [int]$LASTEXITCODE }
    } catch {
        Write-Host "error=$($_.Exception.Message)"
        $code = 1
    }
    Write-Host "exit=$code"
    return [pscustomobject]@{ Name = $Name; Code = $code }
}

$nodeExe = Resolve-NodeExe
if (-not $nodeExe) {
    if ($Required) {
        Write-Output "SUITE=BLOCKED node not in PATH (Contract Production gate requires Node.js)"
        exit 2
    }
    Write-Output "SUITE=SKIP node not in PATH"
    exit 0
}

$results = @()
$results += Invoke-Phase3Step "SCWV Drift" {
    & (Join-Path $here "Validate-ScwvMessageContract.ps1") -Root $Root
}
$results += Invoke-Phase3Step "SCWV Fixtures" {
    Push-Location $html
    try { & $nodeExe "scwv/run-scwv-contract-fixtures.mjs" }
    finally { Pop-Location }
}
$results += Invoke-Phase3Step "Palette Fixtures" {
    Push-Location $html
    try { & $nodeExe "run-palette-fixtures.mjs" }
    finally { Pop-Location }
}

$fail = @($results | Where-Object { $_.Code -ne 0 })
$report = Join-Path $reportDir "phase3_contract_suite.txt"
$gateLabel = if ($Required) { "Contract Production (MinimalGate required)" } else { "Phase3 Contract Suite (optional)" }
$lines = @("== $gateLabel $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==")
$lines += "required=$($Required.IsPresent) node=$nodeExe"
foreach ($r in $results) { $lines += "$($r.Name) exit=$($r.Code)" }
if ($fail.Count -eq 0) {
    $lines += "SUITE=PASS"
    $exit = 0
} else {
    $lines += "SUITE=FAIL failed=$($fail.Name -join ',')"
    $exit = 1
}
$lines | Set-Content -LiteralPath $report -Encoding UTF8
Write-Output "report=$report"
$lines | ForEach-Object { Write-Output $_ }
exit $exit
