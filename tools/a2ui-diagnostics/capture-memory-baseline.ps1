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
} else {
    $RepoRoot = (Resolve-Path $RepoRoot).Path
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

function Get-ProcessTable() {
    return @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine)
}

function Test-NmerRootProcess($row, $repoRoot) {
    if (-not $row) { return $false }
    $name = [string]$row.Name
    $cmd = [string]$row.CommandLine
    if ($name -eq "nmer-wails.exe" -or $name -eq "SearchCenterCore.exe") {
        return $true
    }
    if ($name -like "AutoHotkey*.exe") {
        if ($cmd -like "*牛马.ahk*" -or $cmd -like "*niuma.ahk*" -or $cmd -like "*$repoRoot*") {
            return $true
        }
    }
    return $false
}

function Get-DescendantProcessIds($roots, $table) {
    $ids = New-Object 'System.Collections.Generic.HashSet[int]'
    $queue = New-Object System.Collections.Queue
    foreach ($root in @($roots)) {
        if (-not $root) { continue }
        $rootPid = [int]$root.ProcessId
        if ($ids.Add($rootPid)) { [void]$queue.Enqueue($rootPid) }
    }
    while ($queue.Count -gt 0) {
        $parentId = [int]$queue.Dequeue()
        foreach ($row in @($table | Where-Object { [int]$_.ParentProcessId -eq $parentId })) {
            $childPid = [int]$row.ProcessId
            if ($ids.Add($childPid)) {
                [void]$queue.Enqueue($childPid)
            }
        }
    }
    return ,$ids
}

function Get-WebViewDataDir($commandLine) {
    $cmd = [string]$commandLine
    if ($cmd -match '--user-data-dir="([^"]+)"') { return $matches[1] }
    if ($cmd -match '--user-data-dir=([^\s"]+)') { return $matches[1] }
    return ""
}

function Get-ScopedWebView2($allWebViews, $table, $repoRoot) {
    $roots = @($table | Where-Object { Test-NmerRootProcess $_ $repoRoot })
    $descendantIds = Get-DescendantProcessIds $roots $table
    $tableByPid = @{}
    foreach ($row in @($table)) {
        $tableByPid[[int]$row.ProcessId] = $row
    }

    $scoped = @()
    $diag = @()
    foreach ($proc in @($allWebViews)) {
        $row = $tableByPid[[int]$proc.Id]
        $reasons = @()
        $dataDir = if ($row) { Get-WebViewDataDir $row.CommandLine } else { "" }
        $cmd = if ($row) { [string]$row.CommandLine } else { "" }
        if ($descendantIds.Contains([int]$proc.Id)) {
            $reasons += "descendant"
        }
        if ($dataDir -and ($dataDir -like "*CursorHelper\\Wv2Data*" -or $dataDir -like "*$repoRoot*" -or $dataDir -like "*nmer*" -or $dataDir -like "*niuma*")) {
            $reasons += "data_dir_hint"
        }
        if ($cmd -like "*--webview-exe-name=nmer-wails.exe*") {
            $reasons += "wails_exe_hint"
        }
        if ($cmd -like "*--embedded-browser-webview=1*" -and $cmd -like "*AutoHotkey*") {
            $reasons += "ahk_embed_hint"
        }
        if ($reasons.Count -gt 0) {
            $scoped += $proc
        }
        $diag += [ordered]@{
            pid        = [int]$proc.Id
            parentPid  = if ($row) { [int]$row.ParentProcessId } else { $null }
            name       = $proc.ProcessName
            privateMiB = [math]::Round($proc.PrivateMemorySize64 / 1MB, 2)
            dataDir    = $dataDir
            scoped     = ($reasons.Count -gt 0)
            reasons    = @($reasons)
        }
    }

    return [ordered]@{
        roots         = @($roots)
        descendantIds = $descendantIds
        webviews      = @($scoped | Sort-Object PrivateMemorySize64 -Descending -Unique)
        diagnostics   = @($diag | Sort-Object privateMiB -Descending)
    }
}

function Get-SearchCoreStatus() {
    $out = [ordered]@{
        healthy = $false
        phase = $null
        queueUsed = $null
        queueCapacity = $null
        workers = $null
    }
    try {
        $resp = Invoke-WebRequest -Uri "http://127.0.0.1:8080/v1/fulltext/status" -UseBasicParsing -TimeoutSec 2
        if ($resp.StatusCode -eq 200) {
            $json = $resp.Content | ConvertFrom-Json
            $out["healthy"] = $true
            $out["phase"] = $json.phase
            $out["queueUsed"] = $json.queue.used
            $out["queueCapacity"] = $json.queue.capacity
            $out["workers"] = $json.workers
        }
    } catch {
    }
    return $out
}

$procTable = Get-ProcessTable
$wv2All = @(Get-Process -Name "msedgewebview2" -ErrorAction SilentlyContinue | Sort-Object PrivateMemorySize64 -Descending)
$wv2Scope = Get-ScopedWebView2 $wv2All $procTable $RepoRoot
$wv2Scoped = @($wv2Scope.webviews)
$wv2Top = if ($wv2Scoped.Count -gt 0) { $wv2Scoped[0] } else { $null }
$sidecar = Get-Process -Name "nmer-wails" -ErrorAction SilentlyContinue | Select-Object -First 1
$searchCore = Get-Process -Name "SearchCenterCore" -ErrorAction SilentlyContinue | Select-Object -First 1

$wv2TotalPrivate = Get-WebView2TotalPrivateMiB $wv2Scoped
$wv2GlobalTotalPrivate = Get-WebView2TotalPrivateMiB $wv2All
$sidecarPrivate = 0.0
if ($sidecar) {
    try {
        $sidecar.Refresh()
        $sidecarPrivate = $sidecar.PrivateMemorySize64 / 1MB
    } catch { }
}
$searchCorePrivate = 0.0
if ($searchCore) {
    try {
        $searchCore.Refresh()
        $searchCorePrivate = $searchCore.PrivateMemorySize64 / 1MB
    } catch { }
}
$totalPrivate = [math]::Round($wv2TotalPrivate + $sidecarPrivate + $searchCorePrivate, 2)

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
    if (Test-LooksLikeCpLoaded $wv2Scoped.Count $totalPrivate $prevEmpty) {
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
        Write-Host "preserve emptyLoadPrivateMiB=$emptyForBaseline cpLoadedPrivateMiB=$cpLoadedPrivateMiB webview2_count=$($wv2Scoped.Count) totalPrivateMiB=$totalPrivate"
    }
}

if ($CardCount -eq 0 -and $snapshotKind -eq "empty") {
    @{
        capturedAt          = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        emptyLoadPrivateMiB = $emptyForBaseline
        totalPrivateMiB     = $totalPrivate
        webview2_count      = $wv2Scoped.Count
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

$scopeRootRows = @($wv2Scope.roots)
$searchCoreStatus = Get-SearchCoreStatus
$processes = @{
    webview2_largest      = Get-ProcMemMiB $wv2Top
    webview2_totalPrivate = $wv2TotalPrivate
    webview2_count        = $wv2Scoped.Count
    webview2_globalTotalPrivate = $wv2GlobalTotalPrivate
    webview2_globalCount  = $wv2All.Count
    webview2_scopeStatus  = if ($scopeRootRows.Count -gt 0) { "scoped" } else { "unscoped_no_roots" }
    nmer_wails            = Get-ProcMemMiB $sidecar
    search_center_core    = Get-ProcMemMiB $searchCore
    totalPrivateMiB       = $totalPrivate
}
$processAttribution = [ordered]@{
    repoRoot = $RepoRoot
    rootProcesses = @($scopeRootRows | ForEach-Object {
        [ordered]@{
            pid = [int]$_.ProcessId
            parentPid = [int]$_.ParentProcessId
            name = [string]$_.Name
            commandLine = [string]$_.CommandLine
        }
    })
    webview2 = @($wv2Scope.diagnostics)
    scopedCount = $wv2Scoped.Count
    globalCount = $wv2All.Count
}

if ($SetMultiCardReference -and (Test-Path $OutPath) -and $prevSnapshot) {
    $out = @{}
    $prevSnapshot.PSObject.Properties | ForEach-Object { $out[$_.Name] = $_.Value }
    $out["multiCardReferencePrivateMiB"] = $multiCardRef
    $out["multiCardReferenceCapturedAt"] = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $out["capturedAt"] = $out["multiCardReferenceCapturedAt"]
    $out["processes"] = $processes
    $out["processAttribution"] = $processAttribution
    $out["searchCenterStatus"] = $searchCoreStatus
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
            $out["processAttribution"] = $processAttribution
            $out["searchCenterStatus"] = $searchCoreStatus
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
    processAttribution          = $processAttribution
    searchCenterStatus          = $searchCoreStatus
    emptyLoadPrivateMiB         = $emptyForBaseline
    cpLoadedPrivateMiB          = $cpLoadedPrivateMiB
    multiCardReferencePrivateMiB = $multiCardRef
    cpOpenHint                  = "Multi-card: Run-A2uiMultiCardMemory.ps1 (sets reference then 1/5/20)"
}

$baseline | ConvertTo-Json -Depth 8 | Set-Content -Path $OutPath -Encoding UTF8
Write-Host "a2ui_memory_baseline -> $OutPath"
Write-Host "emptyLoadPrivateMiB=$($baseline.emptyLoadPrivateMiB) totalPrivateMiB=$totalPrivate webview2_count=$($wv2Scoped.Count) global_webview2_count=$($wv2All.Count) scope=$($processes.webview2_scopeStatus) sidecar=$([bool]$sidecar)"
exit 0
