# Day 4 rollout decision draft from local artifacts (heuristic)
param(
    [string]$RepoRoot = "",
    [double]$MaxTotalPrivateMiB = 4096,
    [double]$MaxLargestRendererPrivateMiB = 2048,
    [int]$MinObservationDays = 7
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Continue"
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}

$debugDir = Join-Path $RepoRoot "Cache\debug"

function Read-Json($path) {
    if (-not (Test-Path $path)) { return $null }
    try { return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

$gate = Read-Json (Join-Path $debugDir "a2ui_rollout_gate_last.json")
$l3 = Read-Json (Join-Path $debugDir "a2ui_l3_probe_summary_last.json")
$gray = Read-Json (Join-Path $debugDir "gray_flags_baseline.json")
$mem = Read-Json (Join-Path $debugDir "a2ui_memory_baseline.json")
$obs = Read-Json (Join-Path $debugDir "a2ui_observation_eval_last.json")

$checks = @()
$recommendation = "maintain_b_granularity"
$pass = $true

function Add-Check($id, $ok, $detail, [switch]$Hard) {
    $script:checks += @{ id = $id; ok = $ok; hard = [bool]$Hard; detail = $detail }
    if ($Hard -and -not $ok) { $script:pass = $false }
    $flag = if ($ok) { "PASS" } else { if ($Hard) { "FAIL" } else { "WARN" } }
    Write-Host "$flag $id — $detail"
}

Add-Check "rollout_gate" ($gate -and $gate.rolloutGatePass -eq $true) "rolloutGatePass=$($gate.rolloutGatePass)" -Hard
Add-Check "l3_probes" ($l3 -and $l3.l3Pass -eq $true) "l3Pass=$($l3.l3Pass)" -Hard

if ($gray) {
    $mode = [string]$gray.routeMode
    $intentOk = ($mode -eq "r3_gray") -or ($mode -eq "r1r2_only")
    Add-Check "route_mode_intent" $intentOk "routeMode=$mode" -Hard:$false
    if ($mode -eq "force_nmer_only") {
        $recommendation = "rollback_review"
        Add-Check "force_nmer_only" $false "unexpected force_nmer_only" -Hard
    }
}

if ($mem) {
    $empty = [double]$mem.emptyLoadPrivateMiB
    Add-Check "memory_empty_baseline" ($empty -gt 0) "emptyLoadPrivateMiB=$empty"
    $totalPrivate = [double]$mem.processes.totalPrivateMiB
    $largestPrivate = [double]$mem.processes.webview2_largest.privateMiB
    Add-Check "memory_total_private" ($totalPrivate -gt 0 -and $totalPrivate -le $MaxTotalPrivateMiB) "totalPrivateMiB=$totalPrivate limit=$MaxTotalPrivateMiB" -Hard
    Add-Check "memory_largest_renderer" ($largestPrivate -ge 0 -and $largestPrivate -le $MaxLargestRendererPrivateMiB) "largestRendererPrivateMiB=$largestPrivate limit=$MaxLargestRendererPrivateMiB" -Hard
    $tiers = $mem.singleCardMemoryCost.tiers
    $measuredTiers = @($tiers | Where-Object { $_.measured -eq $true -and $_.tier -gt 0 })
    $refUiPrivate = $null
    if ($mem.PSObject.Properties.Name -contains "multiCardReferenceUiPrivateMiB" -and $null -ne $mem.multiCardReferenceUiPrivateMiB) {
        $refUiPrivate = [double]$mem.multiCardReferenceUiPrivateMiB
    }
    if (-not $refUiPrivate -or $refUiPrivate -le 0) {
        $refTier = @($tiers | Where-Object { $_.tier -eq 0 -and $_.measured -eq $true } | Select-Object -First 1)
        if ($refTier -and $refTier.uiPrivateMiB) { $refUiPrivate = [double]$refTier.uiPrivateMiB }
    }
    $resolveUiDelta = {
        param($tier, [double]$refUi)
        if ($tier.PSObject.Properties.Name -contains "uiDeltaPerCardMiB" -and $null -ne $tier.uiDeltaPerCardMiB) {
            return [double]$tier.uiDeltaPerCardMiB
        }
        $cardCount = if ($tier.PSObject.Properties.Name -contains "cardCount") { [int]$tier.cardCount } else { [int]$tier.tier }
        if ($refUi -gt 0 -and $cardCount -gt 0 -and $tier.uiPrivateMiB) {
            return [math]::Round(([double]$tier.uiPrivateMiB - $refUi) / $cardCount, 2)
        }
        return $null
    }
    $severeNegDelta = @($measuredTiers | Where-Object {
        $d = & $resolveUiDelta $_ $refUiPrivate
        $null -ne $d -and $d -lt -50
    })
    $mildNegDelta = @($measuredTiers | Where-Object {
        $d = & $resolveUiDelta $_ $refUiPrivate
        $null -ne $d -and $d -lt 0 -and $d -ge -50
    })
    $tierDetail = "measured_card_tiers=$($measuredTiers.Count) primary=uiDeltaPerCardMiB"
    if ($measuredTiers.Count -gt 0) {
        $uiDeltas = ($measuredTiers | ForEach-Object {
            $d = & $resolveUiDelta $_ $refUiPrivate
            "$($_.cardCount)=ui:$d"
        }) -join ","
        $tierDetail += " uiDeltas=$uiDeltas"
    }
    Add-Check "memory_multi_card" (($measuredTiers.Count -ge 3) -and ($severeNegDelta.Count -eq 0)) $tierDetail -Hard
    if ($severeNegDelta.Count -gt 0) {
        Add-Check "memory_delta_sign" $false "severe negative uiDeltaPerCardMiB (< -50 MiB) — re-run Run-A2uiMultiCardMemory.ps1 from step 0" -Hard
    } elseif ($mildNegDelta.Count -gt 0) {
        Add-Check "memory_delta_sign" $true "mild negative uiDeltaPerCardMiB within GC noise (>= -50 MiB threshold)"
    }
}

if ($obs) {
    Add-Check "observation_eval" ($obs.evaluatePass -eq $true) "evaluatePass=$($obs.evaluatePass)"
}

$ocSmoke = Read-Json (Join-Path $debugDir "openclaw_adapter_smoke_last.json")
$hermesLive = Read-Json (Join-Path $debugDir "hermes_provider_live_last.json")
if ($ocSmoke) {
    Add-Check "openclaw_adapter_smoke" ($ocSmoke.ok -eq $true) "code=$($ocSmoke.code) accepted=$($ocSmoke.accepted)"
} else {
    Add-Check "openclaw_adapter_smoke" $false "not run (OPENCLAW_GATEWAY_TOKEN + Run-OpenClawAdapterSmoke.ps1)"
}
if ($hermesLive) {
    Add-Check "hermes_provider_live" ($hermesLive.ok -eq $true) "exitCode=$($hermesLive.exitCode)"
} else {
    Add-Check "hermes_provider_live" $false "not run (HERMES_API_SERVER_KEY optional)"
}

$histPath = Join-Path $debugDir "a2ui_observation_history.jsonl"
if (Test-Path $histPath) {
    $lines = @(Get-Content $histPath -Encoding UTF8 | Where-Object { $_.Trim() })
    $days = @(
        $lines | ForEach-Object {
            try {
                $row = $_ | ConvertFrom-Json
                ([datetime]$row.capturedAt).ToUniversalTime().ToString("yyyy-MM-dd")
            } catch { }
        } | Where-Object { $_ } | Sort-Object -Unique
    )
    Add-Check "observation_days" ($days.Count -ge $MinObservationDays) "distinct_days=$($days.Count) history_lines=$($lines.Count) (needs >=$MinObservationDays)" -Hard
    if ($days.Count -lt $MinObservationDays) { $recommendation = "maintain_b_granularity" }
}

if ($pass -and $l3 -and $l3.l3Pass -and $gray -and $gray.routeMode -eq "r3_gray") {
    $recommendation = "expand_gray_cautiously"
}

$out = [ordered]@{
    capturedAt     = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    recommendation = $recommendation
    checks         = $checks
    day4Pass       = $pass
    notes          = @(
        "expand_gray_cautiously: gate+l3 green and r3_gray enabled",
        "maintain_b_granularity: default until 7d observation",
        "rollback_review: force_nmer_only or gate failure"
    )
}

$path = Join-Path $debugDir "a2ui_day4_decision_last.json"
$out | ConvertTo-Json -Depth 6 | Set-Content -Path $path -Encoding UTF8
Write-Host "day4 decision -> $path recommendation=$recommendation pass=$pass"
exit $(if ($pass) { 0 } else { 1 })
