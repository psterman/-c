# Phase B0: reference contract self-check (no signoff run)
param(
    [string]$RepoRoot = "",
    [switch]$JsonOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
$outPath = Join-Path $debugDir "hybrid_reference_contract.json"

function Test-RefContract($ref, [string]$expectedKind) {
    $checks = @()
    $failures = New-Object System.Collections.Generic.List[string]

    $exists = ($null -ne $ref)
    $checks += @{ name = "${expectedKind}_exists"; pass = $exists }
    if (-not $exists) {
        [void]$failures.Add("missing hybrid_signoff_reference_$expectedKind.json")
        return @{ checks = $checks; failures = @($failures); pass = $false }
    }

    $modeOk = ([string]$ref.mode -eq $expectedKind)
    $checks += @{ name = "${expectedKind}_mode"; pass = $modeOk; value = [string]$ref.mode }
    if (-not $modeOk) { [void]$failures.Add("mode=$($ref.mode) want $expectedKind") }

    $kind = if ($ref.referenceKind) { [string]$ref.referenceKind } else { [string]$ref.mode }
    $kindOk = ($kind -eq $expectedKind)
    $checks += @{ name = "${expectedKind}_referenceKind"; pass = $kindOk; value = $kind }
    if (-not $kindOk) { [void]$failures.Add("referenceKind=$kind want $expectedKind") }

    $totalOk = ($null -ne $ref.totalPrivateMiB) -and ([double]$ref.totalPrivateMiB -gt 0)
    $checks += @{ name = "${expectedKind}_totalPrivateMiB"; pass = $totalOk; value = $ref.totalPrivateMiB }
    if (-not $totalOk) { [void]$failures.Add("${expectedKind} totalPrivateMiB missing or zero") }

    $capturedOk = [bool]$ref.capturedAt
    $checks += @{ name = "${expectedKind}_capturedAt"; pass = $capturedOk; value = [string]$ref.capturedAt }
    if (-not $capturedOk) { [void]$failures.Add("${expectedKind} capturedAt missing") }

    $metaOk = $true
    if ($expectedKind -eq "hybrid") {
        if ($ref.flags -and [string]$ref.flags.floatingToolbarHost -ne "hybrid") {
            $metaOk = $false
            [void]$failures.Add("hybrid ref flags.floatingToolbarHost=$($ref.flags.floatingToolbarHost) want hybrid")
        }
        if ($ref.nmerWailsRunning -eq $true) {
            $metaOk = $false
            [void]$failures.Add("hybrid ref captured with nmer-wails running")
        }
    }
    $checks += @{ name = "${expectedKind}_metadata"; pass = $metaOk }

    $pass = ($failures.Count -eq 0)
    return @{ checks = $checks; failures = @($failures); pass = $pass; ref = $ref }
}

$ahkRef = Read-HybridSignoffReference -RepoRoot $RepoRoot -Kind "ahk"
$hybridRef = Read-HybridSignoffReference -RepoRoot $RepoRoot -Kind "hybrid"

$ahkEval = Test-RefContract $ahkRef "ahk"
$hybridEval = Test-RefContract $hybridRef "hybrid"

$crossFailures = New-Object System.Collections.Generic.List[string]
if ($ahkRef -and $hybridRef) {
    if ([math]::Abs([double]$ahkRef.totalPrivateMiB - [double]$hybridRef.totalPrivateMiB) -lt 0.01) {
        [void]$crossFailures.Add("ahk and hybrid reference totals identical — likely same-mode capture mistake")
    }
}

$contractRules = @(
    "memory_delta uses hybrid_signoff_reference_ahk.json only (referenceKind=ahk)"
    "UI-01 refDrift uses hybrid_signoff_reference_hybrid.json only (referenceKind=hybrid)"
    "no silent fallback between reference files"
)

$overallPass = $ahkEval.pass -and $hybridEval.pass -and ($crossFailures.Count -eq 0)

$report = [ordered]@{
    capturedAt    = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    phase         = "b0_contract_selfcheck"
    repoRoot      = $RepoRoot
    contractRules = $contractRules
    ahkRef        = @{
        path       = "hybrid_signoff_reference_ahk.json"
        pass       = $ahkEval.pass
        checks     = $ahkEval.checks
        failures   = $ahkEval.failures
        totalPrivateMiB = if ($ahkRef) { $ahkRef.totalPrivateMiB } else { $null }
        capturedAt = if ($ahkRef) { $ahkRef.capturedAt } else { $null }
        ageHours   = Get-ReferenceAgeHours $ahkRef
    }
    hybridRef     = @{
        path       = "hybrid_signoff_reference_hybrid.json"
        pass       = $hybridEval.pass
        checks     = $hybridEval.checks
        failures   = $hybridEval.failures
        totalPrivateMiB = if ($hybridRef) { $hybridRef.totalPrivateMiB } else { $null }
        capturedAt = if ($hybridRef) { $hybridRef.capturedAt } else { $null }
        ageHours   = Get-ReferenceAgeHours $hybridRef
    }
    crossChecks   = @{
        pass     = ($crossFailures.Count -eq 0)
        failures = @($crossFailures)
    }
    overallPass   = $overallPass
    nextSteps     = if ($overallPass) {
        @("Phase C: Deploy-MemoryIndexBaseline -FormalSignoff")
    } else {
        @(
            "Phase B1 (pre-signoff): capture ahk ref with floatingToolbarHost=ahk"
            "Phase B1: capture hybrid ref with floatingToolbarHost=hybrid"
            "Re-run Test-HybridReferenceContract.ps1"
        )
    }
}

$report | ConvertTo-Json -Depth 8 | Set-Content -Path $outPath -Encoding UTF8

if ($JsonOnly) {
    $report | ConvertTo-Json -Depth 8
} else {
    Write-Host ""
    Write-Host "=== Hybrid Reference Contract (B0) ===" -ForegroundColor Cyan
    Write-Host ("ahk ref:    pass={0} total={1}" -f $ahkEval.pass, $(if ($ahkRef) { $ahkRef.totalPrivateMiB } else { "missing" }))
    Write-Host ("hybrid ref: pass={0} total={1}" -f $hybridEval.pass, $(if ($hybridRef) { $hybridRef.totalPrivateMiB } else { "missing" }))
    if ($crossFailures.Count -gt 0) {
        foreach ($f in $crossFailures) { Write-Host "  cross: $f" -ForegroundColor Yellow }
    }
    Write-Host ("overallPass: {0}" -f $overallPass) -ForegroundColor $(if ($overallPass) { "Green" } else { "Yellow" })
    Write-Host ("-> {0}" -f $outPath) -ForegroundColor DarkGray
}

if (-not $overallPass) { exit 1 }
exit 0
