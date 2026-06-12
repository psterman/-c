# 诊断工具包公共路径（各子目录脚本 dot-source 本文件）
function Get-DiagKitRoot {
    param([string]$From = $PSScriptRoot)
    $p = $From
    for ($i = 0; $i -lt 6; $i++) {
        if (Test-Path (Join-Path $p "_DiagRoot.ps1")) {
            return (Resolve-Path $p).Path
        }
        $next = Split-Path $p -Parent
        if (-not $next -or $next -eq $p) { break }
        $p = $next
    }
    throw "未找到 a2ui-diagnostics 根目录（缺少 _DiagRoot.ps1），起始于: $From"
}

function Get-DiagRepoRoot {
    param([string]$From = $PSScriptRoot)
    $kit = Get-DiagKitRoot -From $From
    return (Resolve-Path (Join-Path $kit "..\..")).Path
}

function Join-DiagScript {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [string]$From = $PSScriptRoot
    )
    Join-Path (Get-DiagKitRoot -From $From) ($RelativePath -replace '/', '\')
}

function Get-SearchCoreSignoffSnapshot {
    $running = [bool](Get-Process -Name "SearchCenterCore" -ErrorAction SilentlyContinue)
    $scanPhase = "unknown"
    $fulltextReady = $false
    $indexLifecycle = "unknown"
    $privateMiB = $null
    $indexMappedMiB = $null

    try {
        $status = Invoke-RestMethod -Uri "http://127.0.0.1:8080/v1/fulltext/status" -TimeoutSec 3
        if ($status) {
            $running = $true
            if ($status.scanPhase) { $scanPhase = [string]$status.scanPhase }
            elseif ($status.phase) { $scanPhase = [string]$status.phase }
            $fulltextReady = [bool]$status.ready
            if ($status.indexLifecycle) {
                if ($status.indexLifecycle -is [string]) {
                    $indexLifecycle = [string]$status.indexLifecycle
                } elseif ($status.indexLifecycle.cutoverState) {
                    $indexLifecycle = [string]$status.indexLifecycle.cutoverState
                } elseif ($status.indexLifecycle.role) {
                    $indexLifecycle = [string]$status.indexLifecycle.role
                } else {
                    $indexLifecycle = ($status.indexLifecycle | ConvertTo-Json -Compress)
                }
            }
        }
    } catch {
        if (-not $running) { $scanPhase = "not_running" }
    }

    try {
        $mem = Invoke-RestMethod -Uri "http://127.0.0.1:8080/v1/fulltext/memory" -TimeoutSec 3
        if ($mem -and $mem.memory) {
            $running = $true
            if ($null -ne $mem.memory.privateMiB) { $privateMiB = [double]$mem.memory.privateMiB }
            if ($null -ne $mem.memory.indexMappedMiB) { $indexMappedMiB = [double]$mem.memory.indexMappedMiB }
            if ($mem.memory.idleLifecycle -and $indexLifecycle -eq "unknown") {
                $indexLifecycle = [string]$mem.memory.idleLifecycle
            }
        }
    } catch {}

    return [ordered]@{
        searchCore = [ordered]@{
            running        = $running
            scanPhase      = $scanPhase
            privateMiB     = $privateMiB
            indexMappedMiB = $indexMappedMiB
        }
        fulltextReady  = $fulltextReady
        indexLifecycle = $indexLifecycle
    }
}

function Get-ReferenceScanPhase($ref) {
    if (-not $ref) { return "missing" }
    if ($ref.searchCore -and $ref.searchCore.scanPhase) { return [string]$ref.searchCore.scanPhase }
    if ($ref.indexLifecycle) { return [string]$ref.indexLifecycle }
    return "unknown"
}

function Get-ReferenceAgeHours($ref) {
    if (-not $ref -or -not $ref.capturedAt) { return $null }
    try {
        $ts = [datetime]::Parse([string]$ref.capturedAt).ToUniversalTime()
        return [math]::Round(((Get-Date).ToUniversalTime() - $ts).TotalHours, 2)
    } catch {
        return $null
    }
}

function Test-HybridMemoryDeltaSamplingReady {
    param(
        $Flags,
        $Ahk,
        $Hub,
        $Wails,
        $FtbStatus,
        $Baseline,
        $RefAhk
    )
    $reasons = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]

    if (-not $RefAhk) { [void]$reasons.Add("missing_hybrid_signoff_reference_ahk.json") }
    if (-not $Ahk) { [void]$reasons.Add("ahk_host_missing") }
    if (-not $Hub) { [void]$reasons.Add("nmer_hub_missing") }
    if ($Wails) { [void]$reasons.Add("nmer_wails_running") }

    $ftbHost = ""
    if ($Flags -and $Flags.wailsBridge) { $ftbHost = [string]$Flags.wailsBridge.floatingToolbarHost }
    if ($ftbHost -ne "hybrid") { [void]$reasons.Add("floatingToolbarHost=$ftbHost want hybrid") }

    $wv2HostRoots = $null
    if ($Baseline -and $Baseline.processes) {
        $wv2HostRoots = [int]$Baseline.processes.webview2_host_root_count
    }
    if ($null -eq $wv2HostRoots -or $wv2HostRoots -lt 1) {
        [void]$reasons.Add("webview2_host_roots_missing")
    }

    $presMode = ""
    if ($FtbStatus) { $presMode = [string]$FtbStatus.presentationMode }
    if ($presMode -ne "external") {
        [void]$reasons.Add("ftb_not_external presentationMode=$presMode")
    }

    $scSnap = Get-SearchCoreSignoffSnapshot
    $scanPhase = [string]$scSnap.searchCore.scanPhase
    if (-not $scanPhase -or $scanPhase -eq "unknown") {
        [void]$reasons.Add("searchcore_phase_unreadable")
    }

    $totalPrivate = $null
    if ($Baseline -and $Baseline.processes) {
        $totalPrivate = [double]$Baseline.processes.totalPrivateMiB
    }
    if ($null -ne $totalPrivate -and $totalPrivate -lt 1100) {
        [void]$warnings.Add("low_total_private_warning totalPrivateMiB=$totalPrivate (<1100 MiB, not blocking)")
    }

    $searchCoreActive = $false
    if ($scanPhase -in @("walking", "indexing", "incremental_sync")) { $searchCoreActive = $true }
    try {
        $st = Invoke-RestMethod -Uri "http://127.0.0.1:8080/v1/fulltext/status" -TimeoutSec 3
        if ($st) {
            if ([bool]$st.running) { $searchCoreActive = $true }
            if ([int]$st.pendingTasks -gt 0) { $searchCoreActive = $true }
            $sp = [string]$st.scanPhase
            if ($sp -in @("walking", "indexing", "incremental_sync")) { $searchCoreActive = $true }
        }
    } catch {}

    if ($searchCoreActive) {
        [void]$warnings.Add("searchcore_active phase=$scanPhase (memory_delta deferred)")
    }

    $componentOk = ($reasons.Count -eq 0)
    $deferred = (-not $componentOk) -or $searchCoreActive

    return @{
        ready                  = $componentOk -and (-not $searchCoreActive)
        deferred               = $deferred
        componentOk            = $componentOk
        reasons                = @($reasons)
        warnings               = @($warnings)
        searchCorePhase        = $scanPhase
        searchCorePrivateMiB   = $scSnap.searchCore.privateMiB
        searchCoreActive       = $searchCoreActive
        totalPrivateMiB        = $totalPrivate
    }
}

function Ensure-DiagNmerHub {
    param(
        [string]$RepoRoot = "",
        [int]$WarmupSec = 2
    )
    if (Get-Process -Name "nmer-hub" -ErrorAction SilentlyContinue) {
        return $true
    }
    if (-not $RepoRoot) {
        try { $RepoRoot = Get-DiagRepoRoot } catch { return $false }
    }
    $candidates = @(
        (Join-Path $RepoRoot "apps\nmer-hub\build\bin\nmer-hub.exe"),
        (Join-Path $RepoRoot "apps\nmer-hub\nmer-hub.exe"),
        (Join-Path $RepoRoot "bin\nmer-hub.exe")
    )
    $exe = $null
    foreach ($c in $candidates) {
        if (Test-Path $c) { $exe = $c; break }
    }
    if (-not $exe) { return $false }
  $prev = $env:NMER_SCRIPT_DIR
    $env:NMER_SCRIPT_DIR = $RepoRoot
    try {
        Start-Process -FilePath $exe -WorkingDirectory $RepoRoot | Out-Null
    } catch {
        return $false
    } finally {
        if ($prev) { $env:NMER_SCRIPT_DIR = $prev } else { Remove-Item Env:\NMER_SCRIPT_DIR -ErrorAction SilentlyContinue }
    }
    if ($WarmupSec -gt 0) { Start-Sleep -Seconds $WarmupSec }
    return [bool](Get-Process -Name "nmer-hub" -ErrorAction SilentlyContinue)
}

function Read-HybridSignoffReference {
    param(
        [string]$RepoRoot,
        [ValidateSet("ahk", "hybrid")]
        [string]$Kind
    )
    $debugDir = Join-Path $RepoRoot "Cache\debug"
    $path = Join-Path $debugDir "hybrid_signoff_reference_$Kind.json"
    if (-not (Test-Path $path)) { return $null }
    try {
        return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $null
    }
}
