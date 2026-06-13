# Offline UI-01 uiPrivateMiB gate check (no live niuma required)
param(
    [string]$RepoRoot = "",
    [double]$RecoveryPct = 10
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
$outPath = Join-Path $debugDir "ui01_uiprivate_metrics_test.json"

function Get-Ui01MemoryMetrics {
    param(
        [double]$MemBefore,
        [double]$MemAfter,
        [double]$UiMemBefore,
        [double]$UiMemAfter,
        [double]$HybridReferenceMiB,
        [double]$HybridReferenceUiMiB,
        [string]$HybridReferenceCapturedAt,
        [bool]$HasHybridReference,
        [double]$RecoveryPct,
        [string]$Mode,
        [int]$CurrentPid,
        [int]$LastPid,
        [string]$SearchCorePhase = ""
    )
    $sessionDeltaMiB = $null
    $sessionDriftPct = $null
    $uiSessionDeltaMiB = $null
    $uiSessionDriftPct = $null
    $refDeltaMiB = $null
    $refDriftPct = $null
    $uiRefDeltaMiB = $null
    $uiRefDriftPct = $null
    $useUiSession = ($UiMemBefore -gt 0) -and ($null -ne $UiMemAfter)
    if ($MemBefore -gt 0 -and ($null -ne $MemAfter)) {
        $sessionDeltaMiB = [math]::Round($MemAfter - $MemBefore, 2)
        $sessionDriftPct = [math]::Round(($sessionDeltaMiB / $MemBefore) * 100, 2)
    }
    if ($useUiSession) {
        $uiSessionDeltaMiB = [math]::Round($UiMemAfter - $UiMemBefore, 2)
        $uiSessionDriftPct = [math]::Round(($uiSessionDeltaMiB / $UiMemBefore) * 100, 2)
    }
    if ($HasHybridReference -and $HybridReferenceMiB -gt 0 -and ($null -ne $MemAfter)) {
        $refDeltaMiB = [math]::Round($MemAfter - $HybridReferenceMiB, 2)
        $refDriftPct = [math]::Round(($refDeltaMiB / $HybridReferenceMiB) * 100, 2)
    }
    if ($HasHybridReference -and $HybridReferenceUiMiB -gt 0 -and ($null -ne $UiMemAfter)) {
        $uiRefDeltaMiB = [math]::Round($UiMemAfter - $HybridReferenceUiMiB, 2)
        $uiRefDriftPct = [math]::Round(($uiRefDeltaMiB / $HybridReferenceUiMiB) * 100, 2)
    }
    $primarySessionDriftPct = if ($useUiSession) { $uiSessionDriftPct } else { $sessionDriftPct }
    $sessionRecoveryPass = ($null -ne $primarySessionDriftPct) -and ($primarySessionDriftPct -le $RecoveryPct)
    $primaryRefDriftPct = if ($null -ne $uiRefDriftPct) { $uiRefDriftPct } else { $refDriftPct }
    return [ordered]@{
        primarySessionField  = if ($useUiSession) { "uiPrivateMiB" } else { "totalPrivateMiB" }
        sessionDriftPct      = if ($useUiSession) { $uiSessionDriftPct } else { $sessionDriftPct }
        totalSessionDriftPct = $sessionDriftPct
        uiSessionDriftPct    = $uiSessionDriftPct
        refDriftPct          = if ($null -ne $uiRefDriftPct) { $uiRefDriftPct } else { $refDriftPct }
        sessionRecoveryPass  = $sessionRecoveryPass
        signoffMode          = $Mode
    }
}

$cases = @(
    [ordered]@{
        name           = "fixture_ui_private_pass_total_fail"
        memBefore      = 827.0
        memAfter       = 1056.0
        uiBefore       = 648.1
        uiAfter        = 610.98
        refTotal       = 1427.4
        refUi          = 648.0
        expectSession  = $true
        expectTotalFail = $true
    }
)

$results = @()
$allPass = $true
foreach ($c in $cases) {
    $m = Get-Ui01MemoryMetrics -MemBefore $c.memBefore -MemAfter $c.memAfter `
        -UiMemBefore $c.uiBefore -UiMemAfter $c.uiAfter `
        -HybridReferenceMiB $c.refTotal -HybridReferenceUiMiB $c.refUi `
        -HybridReferenceCapturedAt "fixture" -HasHybridReference $true `
        -RecoveryPct $RecoveryPct -Mode "warm-session" -CurrentPid 1 -LastPid 1
    $sessionOk = ($m.sessionRecoveryPass -eq $c.expectSession)
    $totalWouldFail = ($m.totalSessionDriftPct -gt $RecoveryPct)
    $totalOk = ($totalWouldFail -eq $c.expectTotalFail)
    $casePass = $sessionOk -and $totalOk
    if (-not $casePass) { $allPass = $false }
    $results += [ordered]@{
        name                = $c.name
        pass                = $casePass
        primarySessionField = $m.primarySessionField
        sessionDriftPct     = $m.sessionDriftPct
        totalSessionDriftPct = $m.totalSessionDriftPct
        sessionRecoveryPass = $m.sessionRecoveryPass
    }
}

$report = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    recoveryPct = $RecoveryPct
    pass       = $allPass
    cases      = $results
}
$report | ConvertTo-Json -Depth 5 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "ui01_uiprivate_metrics_test -> $outPath pass=$allPass"
if (-not $allPass) { exit 1 }
exit 0
