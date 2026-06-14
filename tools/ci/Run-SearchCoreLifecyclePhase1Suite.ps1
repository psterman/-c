param(
    [string]$Root = "",
    [switch]$Strict
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Continue"
$here = $PSScriptRoot

function Invoke-Step {
    param([string]$Name, [string]$ScriptName, [switch]$AllowSkip)
    $scriptPath = Join-Path $here $ScriptName
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        Write-Host ""
        Write-Host "======== $Name ========"
        Write-Output "script_missing=$scriptPath"
        return [pscustomobject]@{ Name = $Name; Code = 1 }
    }
    Write-Host ""
    Write-Host "======== $Name ========"
    $code = 0
    try {
        Push-Location $here
        try {
            & ".\$ScriptName" -Root $Root | Write-Host
            if ($null -ne $LASTEXITCODE) { $code = [int]$LASTEXITCODE }
        } finally {
            Pop-Location
        }
    } catch {
        Write-Output ("step_error=" + $_.Exception.Message)
        $code = 1
    }
    return [pscustomobject]@{ Name = $Name; Code = [int]$code }
}

$results = @{}
$results["p0_static"] = Invoke-Step "L1 Phase0 Static" "Validate-SearchCoreLifecycleStatic.ps1"
if ($results["p0_static"].Code -ne 0) {
    Write-Output "SUITE=FAIL (phase0 static)"
    exit 1
}

$results["p1_static"] = Invoke-Step "L1 Phase1 Static" "Validate-SearchCoreLifecyclePhase1Static.ps1"
if ($Strict -and $results["p1_static"].Code -ne 0) {
    Write-Output "SUITE=FAIL (phase1 static)"
    exit 1
}

$results["p2_static"] = Invoke-Step "L1 Phase2 Static" "Validate-SearchCoreLifecyclePhase2Static.ps1"
if ($Strict -and $results["p2_static"].Code -ne 0) {
    Write-Output "SUITE=FAIL (phase2 static)"
    exit 1
}

$results["ahk_matrix"] = Invoke-Step "AHK Launch Matrix" "TryAhkLaunchMatrix.ps1"
if ($results["ahk_matrix"].Code -ne 0) {
    Write-Output "SUITE=FAIL (ahk matrix)"
    exit 1
}

$results["p0_probe"] = Invoke-Step "L2 Phase0 Probe" "Run-SearchCoreLifecycleProbe.ps1"
if ($results["p0_probe"].Code -eq 1) {
    Write-Output "SUITE=FAIL (phase0 probe)"
    exit 1
}

$results["p1_relaunch"] = Invoke-Step "L2 Phase1 Relaunch Probe" "Run-SearchCoreRelaunchProbe.ps1"
if ($Strict -and $results["p1_relaunch"].Code -eq 1) {
    Write-Output "SUITE=FAIL (phase1 relaunch probe)"
    exit 1
}

$results["p0_e2e"] = Invoke-Step "L3 Phase0 E2E" "Run-SearchCoreLifecycleE2E.ps1"
if ($results["p0_e2e"].Code -eq 1) {
    Write-Output "SUITE=FAIL (phase0 e2e)"
    exit 1
}

Write-Host ""
Write-Host "======== L3 Phase1 E2E ========"
Write-Output "phase1_e2e_note=covered_by_L2_relaunch_probe"
$results["p1_e2e"] = $results["p1_relaunch"]
if ($Strict -and $results["p1_e2e"].Code -eq 1) {
    Write-Output "SUITE=FAIL (phase1 e2e)"
    exit 1
}

Write-Output ""
$p1Pending = @()
if ($results["p1_static"].Code -ne 0) { $p1Pending += "phase1_static" }
if ($results["p1_relaunch"].Code -eq 1) { $p1Pending += "phase1_relaunch" }
if ($results["p1_e2e"].Code -eq 1) { $p1Pending += "phase1_e2e" }

if ($Strict) {
    Write-Output "SUITE=PASS (strict, phase0+phase1+phase2)"
    exit 0
}

if ($p1Pending.Count -gt 0) {
    Write-Output ("SUITE=PASS (phase0); P1_PENDING=" + ($p1Pending -join ","))
    exit 0
}
Write-Output "SUITE=PASS (phase0+phase1)"
exit 0
