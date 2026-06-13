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

function Get-MemoryBaselineUiPrivate($baseline) {
    if (-not $baseline) { return $null }
    if ($baseline.processes -and $null -ne $baseline.processes.uiPrivateMiB) {
        return [double]$baseline.processes.uiPrivateMiB
    }
    if ($baseline.memoryReconciliation -and $baseline.memoryReconciliation.components) {
        $total = [double]$baseline.memoryReconciliation.totalPrivateMiB
        $sc = [double]$baseline.memoryReconciliation.components.searchCorePrivateMiB
        if ($total -gt 0) { return [math]::Round($total - $sc, 2) }
    }
    if ($baseline.singleCardMemoryCost -and $baseline.singleCardMemoryCost.tiers) {
        $tier0 = @($baseline.singleCardMemoryCost.tiers | Where-Object {
            ($_.tier -eq 0 -or $_.cardCount -eq 0) -and $null -ne $_.uiPrivateMiB
        } | Select-Object -First 1)
        if ($tier0) { return [double]$tier0.uiPrivateMiB }
    }
    return $null
}

function Get-HybridReferenceUiPrivate($ref) {
    if (-not $ref) { return $null }
    if ($null -ne $ref.uiPrivateMiB) { return [double]$ref.uiPrivateMiB }
    if ($ref.baseline) {
        $ui = Get-MemoryBaselineUiPrivate $ref.baseline
        if ($null -ne $ui) { return $ui }
    }
    return $null
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

function Stop-DiagSearchCore {
    param(
        [int]$IdleSec = 0,
        [switch]$ThrowIfStillRunning
    )
    $result = [ordered]@{
        stopSent   = $false
        running    = $null
        scanPhase  = $null
        detail     = ""
    }
    try {
        Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8080/v1/fulltext/control" `
            -Body '{"action":"stop"}' -ContentType "application/json; charset=utf-8" -TimeoutSec 8 | Out-Null
        $result.stopSent = $true
    } catch {
        $result.detail = $_.Exception.Message
    }
    if ($IdleSec -gt 0) { Start-Sleep -Seconds $IdleSec }
    try {
        $st = Invoke-RestMethod -Uri "http://127.0.0.1:8080/v1/fulltext/status" -TimeoutSec 8
        $result.running = [bool]$st.running
        $result.scanPhase = [string]$st.scanPhase
    } catch {
        if (-not $result.detail) { $result.detail = $_.Exception.Message }
    }
    if ($ThrowIfStillRunning -and ($result.running -eq $true)) {
        throw "SearchCore still running (phase=$($result.scanPhase))"
    }
    return $result
}

function Wait-DiagSearchCoreStopped {
    param(
        [int]$MaxWaitSec = 60,
        [switch]$ForceKillProcess,
        [int]$PollSec = 2
    )
    $deadline = (Get-Date).AddSeconds($MaxWaitSec)
    $lastPhase = "unknown"
    while ((Get-Date) -lt $deadline) {
        Stop-DiagSearchCore | Out-Null
        $proc = Get-Process -Name "SearchCenterCore" -ErrorAction SilentlyContinue
        $running = [bool]$proc
        try {
            $st = Invoke-RestMethod -Uri "http://127.0.0.1:8080/v1/fulltext/status" -TimeoutSec 5
            $lastPhase = [string]$st.scanPhase
            if ($null -ne $st.running) { $running = [bool]$st.running }
        } catch {
            if (-not $proc) {
                return [ordered]@{
                    ok        = $true
                    running   = $false
                    scanPhase = "not_running"
                    waitedSec = [math]::Round($MaxWaitSec - ($deadline - (Get-Date)).TotalSeconds, 1)
                }
            }
        }
        if (-not $running -and -not $proc) {
            return [ordered]@{
                ok        = $true
                running   = $false
                scanPhase = $lastPhase
                waitedSec = [math]::Round($MaxWaitSec - ($deadline - (Get-Date)).TotalSeconds, 1)
            }
        }
        Start-Sleep -Seconds $PollSec
    }
    if ($ForceKillProcess) {
        Get-Process -Name "SearchCenterCore" -ErrorAction SilentlyContinue | ForEach-Object {
            try { Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch {}
        }
        Start-Sleep -Seconds 3
        $procAfter = Get-Process -Name "SearchCenterCore" -ErrorAction SilentlyContinue
        if (-not $procAfter) {
            return [ordered]@{
                ok        = $true
                running   = $false
                scanPhase = "force_killed"
                waitedSec = $MaxWaitSec
                forceKill = $true
            }
        }
    }
    return [ordered]@{
        ok        = $false
        running   = $true
        scanPhase = $lastPhase
        waitedSec = $MaxWaitSec
        forceKill = $false
    }
}

function Test-DiagUi01MemorySampleReady {
    param($Baseline, [double]$MaxSearchCorePrivateMiB = 20)
    if (-not $Baseline -or -not $Baseline.processes) { return $false }
    $sc = $Baseline.processes.searchCorePrivateMiB
    if ($null -eq $sc) { return $true }
    return ([double]$sc -le $MaxSearchCorePrivateMiB)
}

function Test-DiagNiumaAhkRunning {
    param([string]$RepoRoot = "")
    if (-not $RepoRoot) {
        try { $RepoRoot = Get-DiagRepoRoot } catch { return $false }
    }
    $proc = Get-Process -Name "AutoHotkey64", "AutoHotkey32" -ErrorAction SilentlyContinue | Where-Object {
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
            return ($cmd -like "*$RepoRoot*" -or $cmd -like "*牛马.ahk*")
        } catch { return $false }
    } | Select-Object -First 1
    return [bool]$proc
}

function Get-DiagNiumaScriptPath {
    param([string]$RepoRoot = "")
    if (-not $RepoRoot) {
        $RepoRoot = Get-DiagRepoRoot
    }
    $proc = Get-Process -Name "AutoHotkey64", "AutoHotkey32" -ErrorAction SilentlyContinue | Where-Object {
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
            return ($cmd -like "*$RepoRoot*" -or $cmd -like "*.ahk*")
        } catch { return $false }
    } | Select-Object -First 1
    if ($proc) {
        try {
            $cmd = [string](Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)" -ErrorAction SilentlyContinue).CommandLine
            if ($cmd -match '"([^"]+\.ahk)"\s*$') {
                $fromCmd = $Matches[1]
                if (Test-Path -LiteralPath $fromCmd) {
                    return (Resolve-Path -LiteralPath $fromCmd).Path
                }
            }
        } catch { }
    }
    foreach ($name in @("牛马.ahk", "niuma.ahk")) {
        $direct = Join-Path $RepoRoot $name
        if (Test-Path -LiteralPath $direct) {
            return (Resolve-Path -LiteralPath $direct).Path
        }
    }
    $hit = Get-ChildItem -LiteralPath $RepoRoot -Filter "*.ahk" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("VirtualKeyboard.ahk") } |
        Sort-Object Length -Descending |
        Select-Object -First 1
    if ($hit) { return $hit.FullName }
    throw "niuma entry script (.ahk) not found under $RepoRoot"
}

function Restart-DiagNiumaAhk {
    param(
        [string]$RepoRoot = "",
        [int]$WaitSec = 45
    )
    if (-not $RepoRoot) {
        $RepoRoot = Get-DiagRepoRoot
    }
    $scriptPath = Get-DiagNiumaScriptPath -RepoRoot $RepoRoot
    $procs = @(Get-Process -Name "AutoHotkey64", "AutoHotkey32" -ErrorAction SilentlyContinue | Where-Object {
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
            return ($cmd -like "*$RepoRoot*" -or $cmd -like "*牛马.ahk*")
        } catch { return $false }
    })
    $defaultAhkExe = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
    $ahkExe = $defaultAhkExe
    if ($procs.Count -gt 0) {
        foreach ($p in $procs) {
            try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch { }
        }
        Start-Sleep -Seconds 2
        if ($procs[0].Path) { $ahkExe = $procs[0].Path }
    } elseif (-not (Test-Path $defaultAhkExe)) {
        throw "AutoHotkey64 not found at $defaultAhkExe"
    }
    Start-Process -FilePath $ahkExe -ArgumentList @("`"$scriptPath`"")
    if ($WaitSec -gt 0) { Start-Sleep -Seconds $WaitSec }
    return Test-DiagNiumaAhkRunning -RepoRoot $RepoRoot
}

function Read-DiagJson {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try { return Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

function Get-DiagOpenClawGatewayToken {
    param([string]$RepoRoot = "")
    $tok = [string]$env:OPENCLAW_GATEWAY_TOKEN
    if ($tok) { return @{ token = $tok; source = "env:OPENCLAW_GATEWAY_TOKEN" } }
    if (-not $RepoRoot) {
        try { $RepoRoot = Get-DiagRepoRoot } catch { return $null }
    }
    $studioPath = Join-Path $RepoRoot "local\user_studio.json"
    if (-not (Test-Path $studioPath)) { return $null }
    try {
        $studio = Get-Content $studioPath -Encoding UTF8 -Raw | ConvertFrom-Json
        $tok2 = ""
        if ($studio.options -and $studio.options.llmApiKeys -and $studio.options.llmApiKeys.openclaw) {
            $tok2 = [string]$studio.options.llmApiKeys.openclaw
        }
        if ($tok2) { return @{ token = $tok2.Trim(); source = "local/user_studio.json" } }
    } catch { }
    return $null
}

function Test-DiagOpenClawGatewayTcp {
    param(
        [string]$HostAddr = "127.0.0.1",
        [int]$Port = 18789,
        [int]$TimeoutMs = 1500
    )
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($HostAddr, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
            $client.Close()
            return $false
        }
        $client.EndConnect($iar)
        $client.Close()
        return $true
    } catch {
        return $false
    }
}

function Build-DiagNmerHub {
    param([string]$RepoRoot = "")
    if (-not $RepoRoot) {
        try { $RepoRoot = Get-DiagRepoRoot } catch { return $false }
    }
    $hubDir = Join-Path $RepoRoot "apps\nmer-hub"
    if (-not (Test-Path (Join-Path $hubDir "main.go"))) { return $false }
    $outDir = Join-Path $hubDir "build\bin"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $outExe = Join-Path $outDir "nmer-hub.exe"
    Push-Location $hubDir
    try {
        & go build -o $outExe .
        return ($LASTEXITCODE -eq 0) -and (Test-Path $outExe)
    } catch {
        return $false
    } finally {
        Pop-Location
    }
}

function Restart-DiagNmerHub {
    param(
        [string]$RepoRoot = "",
        [hashtable]$EnvExtra = @{},
        [int]$WarmupSec = 2
    )
    if (-not $RepoRoot) {
        try { $RepoRoot = Get-DiagRepoRoot } catch { return $false }
    }
    Get-Process -Name "nmer-hub" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 400
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
    $prevScriptDir = $env:NMER_SCRIPT_DIR
    $savedEnv = @{}
    if ($EnvExtra -and $EnvExtra.Count -gt 0) {
        foreach ($k in $EnvExtra.Keys) {
            $savedEnv[$k] = [string](Get-Item -Path ("Env:" + $k) -ErrorAction SilentlyContinue).Value
            Set-Item -Path ("Env:" + $k) -Value ([string]$EnvExtra[$k])
        }
    }
    $env:NMER_SCRIPT_DIR = $RepoRoot
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe
        $psi.WorkingDirectory = $RepoRoot
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        foreach ($entry in [System.Environment]::GetEnvironmentVariables("Process").GetEnumerator()) {
            $psi.Environment[[string]$entry.Key] = [string]$entry.Value
        }
        if ($EnvExtra -and $EnvExtra.Count -gt 0) {
            foreach ($k in $EnvExtra.Keys) {
                $psi.Environment[[string]$k] = [string]$EnvExtra[$k]
            }
        }
        [void][System.Diagnostics.Process]::Start($psi)
    } catch {
        return $false
    } finally {
        if ($prevScriptDir) { $env:NMER_SCRIPT_DIR = $prevScriptDir }
        else { Remove-Item Env:\NMER_SCRIPT_DIR -ErrorAction SilentlyContinue }
        foreach ($k in $savedEnv.Keys) {
            if ($savedEnv[$k]) { Set-Item -Path ("Env:" + $k) -Value $savedEnv[$k] }
            else { Remove-Item ("Env:" + $k) -ErrorAction SilentlyContinue }
        }
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
