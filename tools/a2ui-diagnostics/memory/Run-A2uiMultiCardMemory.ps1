# Multi-card memory tiers: empty -> reference -> 1/5/20 (interactive or -Auto)
param(
    [string]$RepoRoot = "",
    [int[]]$CardCounts = @(1, 5, 20),
    [int]$WaitSeconds = 8,
    [ValidateSet("formal", "smoke", "dev")]
    [string]$SignoffMode = "formal",
    [switch]$SkipEmptyCapture,
    [switch]$NonInteractive,
    [switch]$Auto
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Continue"
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
} else {
    $RepoRoot = (Resolve-Path $RepoRoot).Path
}

$cap = Join-Path $PSScriptRoot "capture-memory-baseline.ps1"
$probe = Join-Path $PSScriptRoot "Invoke-MultiCardMemoryProbe.ps1"
if (-not (Test-Path $cap)) {
    Write-Error "missing $cap"
    exit 1
}
if ($Auto -and -not (Test-Path $probe)) {
    Write-Error "missing $probe"
    exit 1
}

$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
$baselinePath = Join-Path $debugDir "a2ui_memory_baseline.json"
$reportPath = Join-Path $debugDir "multi_card_memory_report.json"
$settleMs = [math]::Max(1000, $WaitSeconds * 1000)

function Write-TierBanner([string]$title, [string[]]$steps) {
    Write-Host ""
    Write-Host ("--- {0} ---" -f $title) -ForegroundColor Cyan
    $i = 1
    foreach ($s in $steps) {
        Write-Host ("  {0}. {1}" -f $i, $s)
        $i++
    }
    Write-Host ""
}

function Wait-StepReady([string]$prompt) {
    if ($NonInteractive -or $Auto) {
        Write-Host ("auto: {0} (wait {1}s)" -f $prompt, $WaitSeconds) -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }
    Read-Host $prompt
}

function Invoke-MemoryProbeStep([string]$action, [int]$cardCount = 0) {
    $r = & $probe -RepoRoot $RepoRoot -Action $action -CardCount $cardCount -SettleMs $settleMs
    Write-Host ("  probe {0}: code={1} pass={2} detail={3}" -f $action, $r.code, $r.pass, $r.detail) -ForegroundColor DarkGray
    if (-not $r.pass -and $action -eq "prepare_tier") {
        Write-Warning "prepare_tier cardCount=$cardCount returned pass=false (continuing capture)"
    }
    return $r
}

function Resolve-UiDeltaPerCard($tier, [double]$refUiPrivate) {
    if ($tier.PSObject.Properties.Name -contains "uiDeltaPerCardMiB" -and $null -ne $tier.uiDeltaPerCardMiB) {
        return [double]$tier.uiDeltaPerCardMiB
    }
    $cardCount = if ($tier.PSObject.Properties.Name -contains "cardCount") { [int]$tier.cardCount } else { [int]$tier.tier }
    if ($refUiPrivate -gt 0 -and $cardCount -gt 0 -and $tier.PSObject.Properties.Name -contains "uiPrivateMiB" -and $null -ne $tier.uiPrivateMiB) {
        return [math]::Round(([double]$tier.uiPrivateMiB - $refUiPrivate) / $cardCount, 2)
    }
    return $null
}

function Build-MultiCardReport([string]$baselineFile, [string]$mode) {
    if (-not (Test-Path $baselineFile)) { return $null }
    try {
        $mem = Get-Content $baselineFile -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $null
    }

    $searchCoreState = [ordered]@{
        scanPhase  = $null
        privateMiB = $null
        phase      = $null
        healthy    = $false
    }
    if ($mem.searchCenterMemory) {
        $searchCoreState.privateMiB = $mem.searchCenterMemory.privateMiB
        $searchCoreState.healthy = [bool]$mem.searchCenterMemory.healthy
    }
    if ($mem.searchCenterStatus) {
        $searchCoreState.phase = $mem.searchCenterStatus.phase
        $searchCoreState.scanPhase = $mem.searchCenterStatus.phase
    }

    $refUiPrivate = $null
    if ($mem.PSObject.Properties.Name -contains "multiCardReferenceUiPrivateMiB" -and $null -ne $mem.multiCardReferenceUiPrivateMiB) {
        $refUiPrivate = [double]$mem.multiCardReferenceUiPrivateMiB
    }
    if (-not $refUiPrivate -or $refUiPrivate -le 0) {
        $refTier = @($mem.singleCardMemoryCost.tiers | Where-Object {
            $n = if ($_.PSObject.Properties.Name -contains "cardCount") { [int]$_.cardCount } else { [int]$_.tier }
            $n -eq 0 -and $_.measured -eq $true
        } | Select-Object -First 1)
        if ($refTier -and $refTier.uiPrivateMiB) { $refUiPrivate = [double]$refTier.uiPrivateMiB }
    }

    $tiers = @()
    $rawTiers = $mem.singleCardMemoryCost.tiers
    foreach ($tier in @($rawTiers)) {
        $cardCount = if ($tier.PSObject.Properties.Name -contains "cardCount") { [int]$tier.cardCount } else { [int]$tier.tier }
        $uiDeltaPerCard = Resolve-UiDeltaPerCard $tier $refUiPrivate
        $uiDeltaFromRef = if ($tier.PSObject.Properties.Name -contains "uiDeltaFromReferenceMiB") { $tier.uiDeltaFromReferenceMiB } elseif ($null -ne $uiDeltaPerCard -and $cardCount -gt 0) { [math]::Round($uiDeltaPerCard * $cardCount, 2) } else { $null }
        $row = [ordered]@{
            cardCount              = $cardCount
            label                  = $tier.label
            measured               = [bool]$tier.measured
            totalPrivateMiB        = $tier.totalPrivateMiB
            uiPrivateMiB           = $tier.uiPrivateMiB
            webview2Count          = $tier.webview2Count
            webview2PrivateMiB     = $tier.webview2PrivateMiB
            ahkPrivateMiB          = $tier.ahkPrivateMiB
            hubPrivateMiB          = $tier.hubPrivateMiB
            searchCorePrivateMiB   = $tier.searchCorePrivateMiB
            cardRenderTimeMs       = $tier.cardRenderTimeMs
            restoreTimeMs          = $tier.restoreTimeMs
            deltaFromReferenceMiB  = $tier.deltaFromReferenceMiB
            deltaPerCardMiB        = $tier.deltaPerCardMiB
            referencePrivateMiB    = $tier.referencePrivateMiB
            uiDeltaFromReferenceMiB = $uiDeltaFromRef
            uiDeltaPerCardMiB      = $uiDeltaPerCard
            uiReferencePrivateMiB  = if ($tier.PSObject.Properties.Name -contains "uiReferencePrivateMiB") { $tier.uiReferencePrivateMiB } else { $refUiPrivate }
            note                   = $tier.note
        }
        $tiers += $row
    }

    $warnings = @()
    $measured = @($tiers | Where-Object { $_.measured -eq $true -and $_.cardCount -gt 0 })
    foreach ($t in $measured) {
        if ($null -ne $t.uiDeltaPerCardMiB -and [double]$t.uiDeltaPerCardMiB -lt -50) {
            $warnings += "cardCount=$($t.cardCount) severe negative uiDeltaPerCardMiB=$($t.uiDeltaPerCardMiB)"
        } elseif ($null -ne $t.uiDeltaPerCardMiB -and [double]$t.uiDeltaPerCardMiB -lt 0) {
            $warnings += "cardCount=$($t.cardCount) mild negative uiDeltaPerCardMiB=$($t.uiDeltaPerCardMiB) (>= -50 MiB)"
        } elseif ($null -ne $t.deltaPerCardMiB -and [double]$t.deltaPerCardMiB -lt -50) {
            $warnings += "cardCount=$($t.cardCount) total deltaPerCardMiB=$($t.deltaPerCardMiB) negative but uiDeltaPerCardMiB=$($t.uiDeltaPerCardMiB) (SearchCore noise)"
        }
    }
    if ($measured.Count -lt 3) {
        $warnings += "measured_card_tiers=$($measured.Count) (expected >= 3)"
    }

    return [ordered]@{
        capturedAt                   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        signoffMode                  = $mode
        captureMode                  = if ($Auto) { "auto_probe" } elseif ($NonInteractive) { "non_interactive" } else { "interactive" }
        multiCardReferencePrivateMiB   = $mem.multiCardReferencePrivateMiB
        multiCardReferenceUiPrivateMiB = $refUiPrivate
        deltaFormula                   = "(totalPrivateMiB_at_N - multiCardReferencePrivateMiB) / N"
        uiDeltaFormula                 = "(uiPrivateMiB_at_N - multiCardReferenceUiPrivateMiB) / N"
        primaryDeltaField              = "uiDeltaPerCardMiB"
        uiPrivateFormula               = "uiPrivateMiB = totalPrivateMiB - searchCorePrivateMiB"
        searchCoreState              = $searchCoreState
        tiers                        = $tiers
        warnings                     = $warnings
        sourceBaseline               = $baselineFile
    }
}

Write-Host ""
Write-Host "=== A2UI multi-card memory capture ===" -ForegroundColor Cyan
Write-Host ("signoffMode: {0} | mode: {1}" -f $SignoffMode, ($(if ($Auto) { "Auto" } elseif ($NonInteractive) { "NonInteractive" } else { "Interactive" })))
Write-Host ("Wait/settle: {0}s" -f $WaitSeconds)
Write-Host "Formula: uiPrivateMiB = totalPrivateMiB - searchCorePrivateMiB" -ForegroundColor DarkGray
if ($Auto) {
    Write-Host "Auto: seeds diagnostic R3 fixture cards via multi_card_memory_probe IPC" -ForegroundColor DarkYellow
    Write-Host "      Requires niuma.ahk reload after MultiCardMemoryProbe.ahk update" -ForegroundColor DarkYellow
}
Write-Host ""

if ($Auto) {
    Write-Host "[auto] checking probe IPC (ping)..." -ForegroundColor Cyan
    try {
        $ping = Invoke-MemoryProbeStep "ping"
        if (-not $ping.pass) {
            Write-Error "probe ping failed: $($ping.code) $($ping.detail)"
            exit 1
        }
        Write-Host "[auto] probe IPC ready" -ForegroundColor Green
    } catch {
        Write-Error $_.Exception.Message
        exit 1
    }

    if (-not $SkipEmptyCapture) {
        Write-TierBanner "Step 0: empty load" @("hide CP", "capture empty baseline")
        Invoke-MemoryProbeStep "hide_cp" | Out-Null
        Start-Sleep -Seconds 2
        & $cap -RepoRoot $RepoRoot
    }

    Write-Host "[auto] Step 1/5: reference tier (0 cards)..." -ForegroundColor Cyan
    Invoke-MemoryProbeStep "prepare_tier" 0 | Out-Null
    & $cap -RepoRoot $RepoRoot -SetMultiCardReference
    Write-Host "[auto] reference captured" -ForegroundColor Green

    $step = 2
    $total = 1 + $CardCounts.Count
    foreach ($n in $CardCounts) {
        Write-Host ("[auto] Step {0}/{1}: tier cardCount={2} (seed + settle {3}s)..." -f $step, $total, $n, $WaitSeconds) -ForegroundColor Cyan
        Invoke-MemoryProbeStep "prepare_tier" $n | Out-Null
        & $cap -RepoRoot $RepoRoot -CardCount $n
        Write-Host ("[auto] tier {0} captured" -f $n) -ForegroundColor Green
        $step++
    }
} else {
    if (-not $SkipEmptyCapture) {
        Write-TierBanner "Step 0: empty load (no CP or fully closed)" @(
            "Close Command Palette if open"
            "Ensure minimal R3 cards visible"
            "Press Enter to capture empty baseline"
        )
        Wait-StepReady "Ready for empty capture"
        & $cap -RepoRoot $RepoRoot
        if ($LASTEXITCODE -ne 0) { Write-Warning "empty capture returned exit $LASTEXITCODE" }
    }

    Write-TierBanner "Step 1: multi-card reference" @(
        "Open Command Palette (Ctrl+Shift+Q)"
        "Keep 0 R3 agent cards in CP"
        "Wait for layout to settle"
        "Press Enter to set multiCardReferencePrivateMiB"
    )
    Wait-StepReady "Ready for reference capture"
    Start-Sleep -Seconds $WaitSeconds
    & $cap -RepoRoot $RepoRoot -SetMultiCardReference
    if ($LASTEXITCODE -ne 0) { Write-Warning "reference capture returned exit $LASTEXITCODE" }

    foreach ($n in $CardCounts) {
        Write-TierBanner ("Tier cardCount={0}" -f $n) @(
            "In CP, open exactly $n R3 card(s)"
            "Wait for render to finish"
            "Press Enter to sample tier $n"
        )
        Wait-StepReady ("Prepare $n card(s) in CP")
        Start-Sleep -Seconds $WaitSeconds
        & $cap -RepoRoot $RepoRoot -CardCount $n
        if ($LASTEXITCODE -ne 0) { Write-Warning "tier $n capture returned exit $LASTEXITCODE" }
    }
}

$report = Build-MultiCardReport $baselinePath $SignoffMode
if ($report) {
    $report | ConvertTo-Json -Depth 8 | Set-Content -Path $reportPath -Encoding UTF8
    Write-Host ""
    Write-Host ("report -> {0}" -f $reportPath) -ForegroundColor Green
    if ($report.warnings.Count -gt 0) {
        foreach ($w in $report.warnings) {
            Write-Host ("WARN: {0}" -f $w) -ForegroundColor Yellow
        }
    }
    $measured = @($report.tiers | Where-Object { $_.measured -eq $true -and $_.cardCount -gt 0 })
    Write-Host ("measured tiers: {0}" -f $measured.Count) -ForegroundColor DarkGray
    foreach ($t in $measured) {
        Write-Host ("  tier {0}: uiPrivate={1} MiB uiDeltaPerCard={2} totalDeltaPerCard={3}" -f $t.cardCount, $t.uiPrivateMiB, $t.uiDeltaPerCardMiB, $t.deltaPerCardMiB) -ForegroundColor DarkGray
    }
} else {
    Write-Warning "failed to build multi_card_memory_report.json"
    exit 1
}

Write-Host ""
Write-Host "done -> $baselinePath" -ForegroundColor Green
exit 0
