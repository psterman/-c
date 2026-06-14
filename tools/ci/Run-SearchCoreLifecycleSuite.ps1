param(
    [string]$Root = ""
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Continue"
$here = $PSScriptRoot

function Invoke-Step {
    param([string]$Name, [string]$Script)
    Write-Host ""
    Write-Host "======== $Name ========"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script | Write-Host
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
    return [int]$code
}

$results = @{}
$results["static"] = Invoke-Step "L1 Static" (Join-Path $here "Validate-SearchCoreLifecycleStatic.ps1")
if ($results["static"] -ne 0) {
    Write-Output "SUITE=FAIL (static)"
    exit 1
}

$results["ahk_matrix"] = Invoke-Step "AHK Launch Matrix" (Join-Path $here "TryAhkLaunchMatrix.ps1")
if ($results["ahk_matrix"] -ne 0) {
    Write-Output "SUITE=FAIL (ahk matrix)"
    exit 1
}

$results["probe"] = Invoke-Step "L2 Probe" (Join-Path $here "Run-SearchCoreLifecycleProbe.ps1")
if ($results["probe"] -eq 1) {
    Write-Output "SUITE=FAIL (probe)"
    exit 1
}

$results["e2e"] = Invoke-Step "L3 E2E" (Join-Path $here "Run-SearchCoreLifecycleE2E.ps1")
if ($results["e2e"] -eq 1) {
    Write-Output "SUITE=FAIL (e2e)"
    exit 1
}

Write-Output ""
Write-Output "SUITE=PASS"
Write-Output ("e2e=" + $(if ($results["e2e"] -eq 2) { "SKIP" } else { "PASS" }))
exit 0
