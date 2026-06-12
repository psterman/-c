# WebView2 / sidecar memory baseline - Wave 0.3
param(
    [string]$RepoRoot = "",
    [string]$OutPath = "",
    [int]$CardCount = 0,
    [switch]$PreserveEmptyWhenCpLoaded,
    [switch]$SetMultiCardReference
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Continue"

if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
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
    if ($name -eq "nmer-wails.exe" -or $name -eq "nmer-hub.exe" -or $name -eq "SearchCenterCore.exe") {
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

function Get-WebView2HostRootRows($table, $rootRows) {
    $rootIds = New-Object 'System.Collections.Generic.HashSet[int]'
    foreach ($root in @($rootRows)) {
        if (-not $root) { continue }
        [void]$rootIds.Add([int]$root.ProcessId)
    }
    $hostRoots = @()
    foreach ($row in @($table)) {
        if ([string]$row.Name -ne "msedgewebview2.exe") { continue }
        if ($rootIds.Contains([int]$row.ParentProcessId)) {
            $hostRoots += $row
        }
    }
    return @($hostRoots)
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

function Get-SearchCoreMemory() {
    $out = [ordered]@{
        healthy = $false
    }
    try {
        $resp = Invoke-WebRequest -Uri "http://127.0.0.1:8080/v1/fulltext/memory" -UseBasicParsing -TimeoutSec 3
        if ($resp.StatusCode -eq 200) {
            $json = $resp.Content | ConvertFrom-Json
            $mem = $json.memory
            if ($mem) {
                $out["healthy"] = $true
                $out["privateMiB"] = $mem.privateMiB
                $out["workingSetMiB"] = $mem.workingSetMiB
                $out["heapAllocMiB"] = $mem.heapAllocMiB
                $out["heapSysMiB"] = $mem.heapSysMiB
                $out["heapInuseMiB"] = $mem.heapInuseMiB
                $out["heapIdleMiB"] = $mem.heapIdleMiB
                $out["heapReleasedMiB"] = $mem.heapReleasedMiB
                $out["indexMappedMiB"] = $mem.indexMappedMiB
                if ($mem.idleLifecycle) {
                    $out["idleLifecycle"] = $mem.idleLifecycle
                }
            }
        }
    } catch {
    }
    return $out
}

$procTable = Get-ProcessTable
$wv2All = @(Get-Process -Name "msedgewebview2" -ErrorAction SilentlyContinue | Sort-Object PrivateMemorySize64 -Descending)
$wv2Scope = Get-ScopedWebView2 $wv2All $procTable $RepoRoot
$wv2Scoped = @($wv2Scope.webviews)
$scopeRootRows = @($wv2Scope.roots)
$wv2HostRootRows = Get-WebView2HostRootRows $procTable $scopeRootRows
$wv2Top = if ($wv2Scoped.Count -gt 0) { $wv2Scoped[0] } else { $null }
$sidecar = Get-Process -Name "nmer-hub","nmer-wails" -ErrorAction SilentlyContinue | Sort-Object PrivateMemorySize64 -Descending | Select-Object -First 1
$searchCore = Get-Process -Name "SearchCenterCore" -ErrorAction SilentlyContinue | Select-Object -First 1
$ahkHost = @($procTable | Where-Object {
    $n = [string]$_.Name
    $cmd = [string]$_.CommandLine
    return ($n -like "AutoHotkey*.exe") -and ($cmd -like "*$RepoRoot*" -or $cmd -like "*牛马.ahk*" -or $cmd -like "*niuma.ahk*")
} | ForEach-Object {
    try { Get-Process -Id ([int]$_.ProcessId) -ErrorAction SilentlyContinue } catch { $null }
}) | Where-Object { $_ } | Select-Object -First 1

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
$ahkPrivate = 0.0
$ahkWorkingSet = 0.0
if ($ahkHost) {
    try {
        $ahkHost.Refresh()
        $ahkPrivate = $ahkHost.PrivateMemorySize64 / 1MB
        $ahkWorkingSet = $ahkHost.WorkingSet64 / 1MB
    } catch { }
}
$webview2HostRootCount = @($wv2HostRootRows).Count
$webview2DescendantCount = $wv2Scoped.Count
$webview2HostControlCount = $webview2HostRootCount
$webview2ProcessCap = 4
$webview2HostControlCap = 4
$totalPrivate = [math]::Round($wv2TotalPrivate + $sidecarPrivate + $searchCorePrivate + $ahkPrivate, 2)

function Test-LooksLikeCpLoaded([int]$wv2HostRoots, [int]$wv2Descendants, [double]$measuredTotal, [double]$prevEmpty) {
    if ($wv2HostRoots -ge 3) { return $true }
    if ($wv2Descendants -ge 8) { return $true }
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

function New-TierMemorySnapshot(
    [double]$TotalPrivate,
    [double]$Wv2TotalPrivate,
    [double]$SidecarPrivate,
    [double]$SearchCorePrivate,
    [double]$AhkPrivate,
    [int]$Wv2Count
) {
    return @{
        totalPrivateMiB        = [math]::Round($TotalPrivate, 2)
        uiPrivateMiB           = [math]::Round($TotalPrivate - $SearchCorePrivate, 2)
        webview2Count          = $Wv2Count
        webview2PrivateMiB     = [math]::Round($Wv2TotalPrivate, 2)
        ahkPrivateMiB          = [math]::Round($AhkPrivate, 2)
        hubPrivateMiB          = [math]::Round($SidecarPrivate, 2)
        searchCorePrivateMiB   = [math]::Round($SearchCorePrivate, 2)
        cardRenderTimeMs       = $null
        restoreTimeMs          = $null
    }
}

function Apply-TierMemorySnapshot([hashtable]$Tier, [hashtable]$Snapshot) {
    foreach ($kv in $Snapshot.GetEnumerator()) {
        $Tier[$kv.Key] = $kv.Value
    }
}

function Get-MultiCardUiReferenceMiB($tierList, $prevSnapshot) {
    if ($prevSnapshot -and $prevSnapshot.PSObject.Properties.Name -contains "multiCardReferenceUiPrivateMiB") {
        $v = [double]$prevSnapshot.multiCardReferenceUiPrivateMiB
        if ($v -gt 0) { return $v }
    }
    foreach ($tier in @($tierList)) {
        $n = if ($tier.ContainsKey("tier")) { [int]$tier["tier"] } elseif ($tier.ContainsKey("cardCount")) { [int]$tier["cardCount"] } else { -1 }
        if ($n -eq 0 -and $tier.ContainsKey("uiPrivateMiB") -and $null -ne $tier["uiPrivateMiB"]) {
            $ui = [double]$tier["uiPrivateMiB"]
            if ($ui -gt 0) { return $ui }
        }
    }
    return 0
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
            uiPrivateMiB    = $null
            deltaPerCardMiB = if ($def.n -eq 0) { 0 } else { $null }
            deltaFromReferenceMiB = if ($def.n -eq 0) { 0 } else { $null }
            uiDeltaPerCardMiB = if ($def.n -eq 0) { 0 } else { $null }
            uiDeltaFromReferenceMiB = if ($def.n -eq 0) { 0 } else { $null }
            uiReferencePrivateMiB = $null
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
    if (Test-LooksLikeCpLoaded $wv2HostRootRows.Count $wv2Scoped.Count $totalPrivate $prevEmpty) {
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
    $emptySnap = New-TierMemorySnapshot $totalPrivate $wv2TotalPrivate $sidecarPrivate $searchCorePrivate $ahkPrivate $wv2Scoped.Count
    foreach ($tier in $tiers) {
        if ([int]$tier["tier"] -eq 0) {
            Apply-TierMemorySnapshot $tier $emptySnap
            $tier["measured"] = $true
        }
    }
    @{
        capturedAt          = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        emptyLoadPrivateMiB = $emptyForBaseline
        totalPrivateMiB     = $totalPrivate
        uiPrivateMiB        = $emptySnap.uiPrivateMiB
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
$searchCoreMemory = Get-SearchCoreMemory
$componentSumPrivate = [math]::Round($wv2TotalPrivate + $sidecarPrivate + $searchCorePrivate + $ahkPrivate, 2)
$memoryReconciliation = @{
    componentSumMiB   = $componentSumPrivate
    totalPrivateMiB   = $totalPrivate
    deltaMiB          = [math]::Round($totalPrivate - $componentSumPrivate, 2)
    withinTolerance   = ([math]::Abs($totalPrivate - $componentSumPrivate) -lt 1.0)
    components        = [ordered]@{
        webview2ScopedPrivateMiB = $wv2TotalPrivate
        sidecarPrivateMiB        = [math]::Round($sidecarPrivate, 2)
        searchCorePrivateMiB     = [math]::Round($searchCorePrivate, 2)
        ahkHostPrivateMiB        = [math]::Round($ahkPrivate, 2)
    }
}
$processes = @{
    webview2_largest      = Get-ProcMemMiB $wv2Top
    webview2_totalPrivate = $wv2TotalPrivate
    webview2_count        = $webview2DescendantCount
    webview2_host_root_count = $webview2HostRootCount
    webview2_descendant_count = $webview2DescendantCount
    webview2_globalTotalPrivate = $wv2GlobalTotalPrivate
    webview2_globalCount  = $wv2All.Count
    webview2_scopeStatus  = if ($scopeRootRows.Count -gt 0) { "scoped" } else { "unscoped_no_roots" }
    nmer_sidecar          = Get-ProcMemMiB $sidecar
    search_center_core    = Get-ProcMemMiB $searchCore
    ahk_host              = Get-ProcMemMiB $ahkHost
    totalPrivateMiB       = $totalPrivate
    webview2_host_control_count = $webview2HostControlCount
    webview2_process_cap  = $webview2ProcessCap
    webview2_host_control_cap = $webview2HostControlCap
    webview2_cap_exceeded = ($webview2HostRootCount -gt $webview2ProcessCap) -or ($webview2HostRootCount -gt $webview2HostControlCap)
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
    webview2HostRoots = @($wv2HostRootRows | ForEach-Object {
        [ordered]@{
            pid = [int]$_.ProcessId
            parentPid = [int]$_.ParentProcessId
            name = [string]$_.Name
            commandLine = [string]$_.CommandLine
        }
    })
    webview2 = @($wv2Scope.diagnostics)
    scopedCount = $webview2DescendantCount
    hostRootCount = $webview2HostRootCount
    globalCount = $wv2All.Count
}

if ($SetMultiCardReference -and (Test-Path $OutPath) -and $prevSnapshot) {
    $refSnap = New-TierMemorySnapshot $totalPrivate $wv2TotalPrivate $sidecarPrivate $searchCorePrivate $ahkPrivate $wv2Scoped.Count
    $tierList = Copy-TiersFromPrev $prevSnapshot.singleCardMemoryCost.tiers
    if ($tierList.Count -eq 0) { $tierList = New-DefaultTiers $emptyForBaseline }
    foreach ($tier in $tierList) {
        if ([int]$tier["tier"] -eq 0) {
            Apply-TierMemorySnapshot $tier $refSnap
            $tier["measured"] = $true
            $tier["referencePrivateMiB"] = $multiCardRef
            $tier["deltaFromReferenceMiB"] = 0
            $tier["deltaPerCardMiB"] = 0
            $tier["uiReferencePrivateMiB"] = $refSnap.uiPrivateMiB
            $tier["uiDeltaFromReferenceMiB"] = 0
            $tier["uiDeltaPerCardMiB"] = 0
            $tier["note"] = "multi-card reference (CP open, 0 R3 cards)"
        }
    }
    $out = @{}
    $prevSnapshot.PSObject.Properties | ForEach-Object { $out[$_.Name] = $_.Value }
    $out["multiCardReferencePrivateMiB"] = $multiCardRef
    $out["multiCardReferenceUiPrivateMiB"] = $refSnap.uiPrivateMiB
    $out["multiCardReferenceCapturedAt"] = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $out["capturedAt"] = $out["multiCardReferenceCapturedAt"]
    $out["processes"] = $processes
    $out["processAttribution"] = $processAttribution
    $out["searchCenterStatus"] = $searchCoreStatus
    $out["searchCenterMemory"] = $searchCoreMemory
    $out["memoryReconciliation"] = $memoryReconciliation
    $out["singleCardMemoryCost"] = @{
        tiers             = $tierList
        deltaFormula      = "(totalPrivateMiB_at_N - multiCardReferencePrivateMiB) / N"
        uiDeltaFormula    = "(uiPrivateMiB_at_N - multiCardReferenceUiPrivateMiB) / N"
        primaryDeltaField = "uiDeltaPerCardMiB"
    }
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
        $tierSnap = New-TierMemorySnapshot $totalPrivate $wv2TotalPrivate $sidecarPrivate $searchCorePrivate $ahkPrivate $wv2Scoped.Count
        $deltaFromRef = [math]::Round($totalPrivate - $reference, 2)
        $uiRef = Get-MultiCardUiReferenceMiB $tierList $prevSnapshot
        $uiDeltaFromRef = [math]::Round($tierSnap.uiPrivateMiB - $uiRef, 2)
        $uiDeltaPerCard = if ($CardCount -gt 0 -and $uiRef -gt 0) { [math]::Round(($tierSnap.uiPrivateMiB - $uiRef) / $CardCount, 2) } else { $null }
        foreach ($tier in $tierList) {
            if ([int]$tier["tier"] -eq $CardCount -or [int]$tier["cardCount"] -eq $CardCount) {
                $tier["measured"] = $true
                Apply-TierMemorySnapshot $tier $tierSnap
                $tier["deltaPerCardMiB"] = $delta
                $tier["deltaFromReferenceMiB"] = $deltaFromRef
                $tier["referencePrivateMiB"] = $reference
                $tier["uiReferencePrivateMiB"] = $uiRef
                $tier["uiDeltaFromReferenceMiB"] = $uiDeltaFromRef
                $tier["uiDeltaPerCardMiB"] = $uiDeltaPerCard
                $tier["note"] = "captured CardCount=$CardCount ref=$reference uiRef=$uiRef total=$totalPrivate ui=$($tierSnap.uiPrivateMiB) uiDeltaPerCard=$uiDeltaPerCard"
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
            $out["searchCenterMemory"] = $searchCoreMemory
            $out["memoryReconciliation"] = $memoryReconciliation
            $out["singleCardMemoryCost"] = @{
                tiers             = $tierList
                deltaFormula      = "(totalPrivateMiB_at_N - multiCardReferencePrivateMiB) / N"
                uiDeltaFormula    = "(uiPrivateMiB_at_N - multiCardReferenceUiPrivateMiB) / N"
                primaryDeltaField = "uiDeltaPerCardMiB"
            }
            if ($uiDeltaPerCard -lt -50) {
                Write-Warning "severe negative uiDeltaPerCardMiB=$uiDeltaPerCard (< -50 MiB) — reference may be stale; re-run Run-A2uiMultiCardMemory.ps1 from step 0"
            } elseif ($uiDeltaPerCard -lt 0) {
                Write-Host "INFO: mild negative uiDeltaPerCardMiB=$uiDeltaPerCard within GC noise tolerance (warning threshold -50 MiB)"
            } elseif ($delta -lt -50) {
                Write-Host "INFO: total deltaPerCardMiB=$delta negative but uiDeltaPerCardMiB=$uiDeltaPerCard (SearchCore noise excluded)"
            }
            $out | ConvertTo-Json -Depth 8 | Set-Content -Path $OutPath -Encoding UTF8
            Write-Host "a2ui_memory_baseline tier=$CardCount -> $OutPath uiDeltaPerCardMiB=$uiDeltaPerCard deltaPerCardMiB=$delta ref=$reference uiRef=$uiRef total=$totalPrivate"
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
        tiers             = $tiers
        deltaFormula      = "(totalPrivateMiB_at_N - multiCardReferencePrivateMiB) / N"
        uiDeltaFormula    = "(uiPrivateMiB_at_N - multiCardReferenceUiPrivateMiB) / N"
        primaryDeltaField = "uiDeltaPerCardMiB"
    }
    processes                   = $processes
    processAttribution          = $processAttribution
    searchCenterStatus          = $searchCoreStatus
    searchCenterMemory          = $searchCoreMemory
    memoryReconciliation        = $memoryReconciliation
    emptyLoadPrivateMiB         = $emptyForBaseline
    cpLoadedPrivateMiB          = $cpLoadedPrivateMiB
    multiCardReferencePrivateMiB = $multiCardRef
    cpOpenHint                  = "Multi-card: Run-A2uiMultiCardMemory.ps1 (sets reference then 1/5/20)"
}

$baseline | ConvertTo-Json -Depth 8 | Set-Content -Path $OutPath -Encoding UTF8
Write-Host "a2ui_memory_baseline -> $OutPath"
Write-Host "emptyLoadPrivateMiB=$($baseline.emptyLoadPrivateMiB) totalPrivateMiB=$totalPrivate webview2_host_roots=$webview2HostRootCount webview2_descendants=$webview2DescendantCount cap_exceeded=$($processes.webview2_cap_exceeded) scope=$($processes.webview2_scopeStatus) sidecar=$([bool]$sidecar)"
exit 0
