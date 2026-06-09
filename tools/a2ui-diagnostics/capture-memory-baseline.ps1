# WebView2 / sidecar memory baseline - Wave 0.3
param(
    [string]$RepoRoot = "",
    [string]$OutPath = "",
    [int]$CardCount = 0,
    [switch]$PreserveEmptyWhenCpLoaded,
    [switch]$SetMultiCardReference
)

$ErrorActionPreference = "Continue"

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
if (-not $OutPath) {
    $debugDir = Join-Path $RepoRoot "Cache\debug"
    if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
    $OutPath = Join-Path $debugDir "a2ui_memory_baseline.json"
}

function Get-ProcMemMiB($proc) {
    if (-not $proc) { return $null }
    try {
        $proc.Refresh()
        return @{
            pid           = $proc.Id
            name          = $proc.ProcessName
            workingSetMiB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
            privateMiB    = [math]::Round($proc.PrivateMemorySize64 / 1MB, 2)
        }
    } catch {
        return $null
    }
}

function Get-WebView2TotalPrivateMiB($procs) {
    $sum = 0.0
    foreach ($p in @($procs)) {
        try {
            $p.Refresh()
            $sum += $p.PrivateMemorySize64 / 1MB
        } catch { }
    }
    return [math]::Round($sum, 2)
}

$wv2All = @(Get-Process -Name "msedgewebview2" -ErrorAction SilentlyContinue | Sort-Object PrivateMemorySize64 -Descending)
$wv2Top = if ($wv2All.Count -gt 0) { $wv2All[0] } else { $null }
$sidecar = Get-Process -Name "nmer-wails" -ErrorAction SilentlyContinue | Select-Object -First 1

$wv2TotalPrivate = Get-WebView2TotalPrivateMiB $wv2All
$sidecarPrivate = 0.0
if ($sidecar) {
    try {
        $sidecar.Refresh()
        $sidecarPrivate = $sidecar.PrivateMemorySize64 / 1MB
    } catch { }
}
$totalPrivate = [math]::Round($wv2TotalPrivate + $sidecarPrivate, 2)

function Test-LooksLikeCpLoaded([int]$wv2Count, [double]$measuredTotal, [double]$prevEmpty) {
    if ($wv2Count -ge 8) { return $true }
    if ($prevEmpty -gt 0 -and $measuredTotal -gt ($prevEmpty * 1.35)) { return $true }
    return $false
}

function Copy-TiersFromPrev($prevTiers) {
    $out = @()
    if (-not $prevTiers) { return $out }
    foreach ($tier in @($prevTiers)) {
        $t = @{}
        $tier.PSObject.Properties | ForEach-Object { $t[$_.Name] = $_.Value }
        $out += $t
    }
    return $out
}

function New-DefaultTiers([double]$emptyTotal) {
    $defs = @(
        @{ n = 0; label = "empty"; note = "auto captured empty load" },
        @{ n = 1; label = "basic"; note = "CP open with N R3 cards" },
        @{ n = 5; label = "medium"; note = "CP open with N R3 cards" },
        @{ n = 20; label = "replay_cap"; note = "CP open with N R3 cards (replay cap)" }
    )
    $tiers = @()
    foreach ($def in $defs) {
        $tiers += @{
            tier            = $def.n
            label           = $def.label
            cardCount       = $def.n
            measured        = ($def.n -eq 0)
            note            = $def.note
            totalPrivateMiB = if ($def.n -eq 0) { $emptyTotal } else { $null }
            deltaPerCardMiB = if ($def.n -eq 0) { 0 } else { $null }
        }
    }
    return $tiers
}

$prevSnapshot = $null
if (Test-Path $OutPath) {
    try { $prevSnapshot = Get-Content $OutPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
}

$emptyArchivedPath = Join-Path (Split-Path $OutPath -Parent) "a2ui_memory_empty_archive.json"
$snapshotKind = "empty"
$cpLoadedPrivateMiB = $null
$emptyForBaseline = $totalPrivate
$tiers = New-DefaultTiers $emptyForBaseline

if ($prevSnapshot -and $prevSnapshot.singleCardMemoryCost -and $prevSnapshot.singleCardMemoryCost.tiers) {
    $tiers = Copy-TiersFromPrev $prevSnapshot.singleCardMemoryCost.tiers
    if ($tiers.Count -eq 0) { $tiers = New-DefaultTiers $emptyForBaseline }
}

if ($CardCount -eq 0 -and $PreserveEmptyWhenCpLoaded -and $prevSnapshot) {
    $prevEmpty = [double]$prevSnapshot.emptyLoadPrivateMiB
    if (Test-LooksLikeCpLoaded $wv2All.Count $totalPrivate $prevEmpty) {
        $snapshotKind = "cp_loaded"
        $cpLoadedPrivateMiB = $totalPrivate
        $emptyForBaseline = $prevEmpty
        foreach ($tier in $tiers) {
            if ([int]$tier["tier"] -eq 0) {
                $tier["totalPrivateMiB"] = [math]::Round($prevEmpty, 2)
                $tier["measured"] = $true
                $tier["note"] = "preserved empty baseline (CP was open during daily observe)"
            }
        }
        Write-Host "preserve emptyLoadPrivateMiB=$emptyForBaseline cpLoadedPrivateMiB=$cpLoadedPrivateMiB webview2_count=$($wv2All.Count) totalPrivateMiB=$totalPrivate"
    }
}

if ($CardCount -eq 0 -and $snapshotKind -eq "empty" -and $wv2All.Count -lt 8) {
    @{
        capturedAt          = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        emptyLoadPrivateMiB = $emptyForBaseline
        totalPrivateMiB     = $totalPrivate
        webview2_count      = $wv2All.Count
        note                = "archived empty baseline"
    } | ConvertTo-Json -Depth 4 | Set-Content -Path $emptyArchivedPath -Encoding UTF8
}

$multiCardRef = $null
if ($prevSnapshot -and $prevSnapshot.PSObject.Properties.Name -contains "multiCardReferencePrivateMiB") {
    $multiCardRef = [double]$prevSnapshot.multiCardReferencePrivateMiB
}

if ($SetMultiCardReference) {
    $multiCardRef = $totalPrivate
    Write-Host "multiCardReferencePrivateMiB=$multiCardRef (CP baseline for tier deltas)"
}

$processes = @{
    webview2_largest      = Get-ProcMemMiB $wv2Top
    webview2_totalPrivate = $wv2TotalPrivate
    webview2_count        = $wv2All.Count
    nmer_wails            = Get-ProcMemMiB $sidecar
    totalPrivateMiB       = $totalPrivate
}

if ($SetMultiCardReference -and (Test-Path $OutPath) -and $prevSnapshot) {
    $out = @{}
    $prevSnapshot.PSObject.Properties | ForEach-Object { $out[$_.Name] = $_.Value }
    $out["multiCardReferencePrivateMiB"] = $multiCardRef
    $out["multiCardReferenceCapturedAt"] = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $out["capturedAt"] = $out["multiCardReferenceCapturedAt"]
    $out["processes"] = $processes
    $out | ConvertTo-Json -Depth 8 | Set-Content -Path $OutPath -Encoding UTF8
    exit 0
}

if ($CardCount -gt 0 -and $prevSnapshot) {
    try {
        $reference = [double]$multiCardRef
        if ($reference -le 0) { $reference = [double]$prevSnapshot.cpLoadedPrivateMiB }
        if ($reference -le 0) { $reference = [double]$prevSnapshot.emptyLoadPrivateMiB }
        $delta = if ($CardCount -gt 0) { [math]::Round(($totalPrivate - $reference) / $CardCount, 2) } else { $null }
        $tierList = Copy-TiersFromPrev $prevSnapshot.singleCardMemoryCost.tiers
        if ($tierList.Count -eq 0) { $tierList = New-DefaultTiers ([double]$prevSnapshot.emptyLoadPrivateMiB) }
        $updated = $false
        foreach ($tier in $tierList) {
            if ([int]$tier["tier"] -eq $CardCount -or [int]$tier["cardCount"] -eq $CardCount) {
                $tier["measured"] = $true
                $tier["totalPrivateMiB"] = $totalPrivate
                $tier["deltaPerCardMiB"] = $delta
                $tier["referencePrivateMiB"] = $reference
                $tier["note"] = "captured CardCount=$CardCount ref=$reference total=$totalPrivate"
                $updated = $true
            }
        }
        if ($updated) {
            $out = @{}
            $prevSnapshot.PSObject.Properties | ForEach-Object { $out[$_.Name] = $_.Value }
            $out["capturedAt"] = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            $out["processes"] = $processes
            $out["singleCardMemoryCost"] = @{
                tiers        = $tierList
                deltaFormula = "(totalPrivateMiB_at_N - multiCardReferencePrivateMiB) / N"
            }
            if ($delta -lt 0) {
                Write-Warning "negative deltaPerCardMiB=$delta — reference may be stale; re-run Run-A2uiMultiCardMemory.ps1 from step 0"
            }
            $out | ConvertTo-Json -Depth 8 | Set-Content -Path $OutPath -Encoding UTF8
            Write-Host "a2ui_memory_baseline tier=$CardCount -> $OutPath deltaPerCardMiB=$delta ref=$reference total=$totalPrivate"
            exit 0
        }
    } catch {
        Write-Warning "tier capture failed: $_"
    }
}

$baseline = @{
    capturedAt                  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    snapshotKind                = $snapshotKind
    singleCardMemoryCost        = @{
        tiers        = $tiers
        deltaFormula = "(totalPrivateMiB_at_N - multiCardReferencePrivateMiB) / N"
    }
    processes                   = $processes
    emptyLoadPrivateMiB         = $emptyForBaseline
    cpLoadedPrivateMiB          = $cpLoadedPrivateMiB
    multiCardReferencePrivateMiB = $multiCardRef
    cpOpenHint                  = "Multi-card: Run-A2uiMultiCardMemory.ps1 (sets reference then 1/5/20)"
}

$baseline | ConvertTo-Json -Depth 8 | Set-Content -Path $OutPath -Encoding UTF8
Write-Host "a2ui_memory_baseline -> $OutPath"
Write-Host "emptyLoadPrivateMiB=$($baseline.emptyLoadPrivateMiB) totalPrivateMiB=$totalPrivate webview2_count=$($wv2All.Count) sidecar=$([bool]$sidecar)"
exit 0
