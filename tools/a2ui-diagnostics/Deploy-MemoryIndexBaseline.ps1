# v4 运行态切换：唯一入口 build / 配置迁移 / 进程重启 / 签核报告
param(
    [string]$RepoRoot = "",
    [switch]$SkipBuild,
    [switch]$SwitchOnly,
    [switch]$FormalSignoff,
    [switch]$WithQuickSample,
    [switch]$SkipSoak,
    [switch]$WithIdleExitTest,
    [int]$SoakMinutes = 5
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
if ($FormalSignoff) {
    $SwitchOnly = $false
    $SkipSoak = $false
    $SoakMinutes = 30
    $WithQuickSample = $true
}
if ($SwitchOnly) {
    $SkipSoak = $true
}

$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
$signoffPath = Join-Path $debugDir "v4_signoff.json"

function Stop-ProcByName([string]$name, [int]$waitMs = 2500) {
    $pids = @(Get-Process -Name ($name -replace '\.exe$','') -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
    foreach ($procId in $pids) {
        try { Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue } catch {}
    }
    if ($pids.Count -gt 0) { Start-Sleep -Milliseconds $waitMs }
}

function Stop-RepoAhkForSignoff([string]$root) {
    $escaped = [regex]::Escape($root)
    foreach ($name in @("AutoHotkey64", "AutoHotkey32")) {
        $procs = Get-CimInstance Win32_Process -Filter "Name='$name.exe'" -ErrorAction SilentlyContinue
        foreach ($p in @($procs)) {
            if ([string]$p.CommandLine -match $escaped) {
                Write-Host "[signoff] stop AHK pid=$($p.ProcessId) (avoid SearchCenterCore watchdog race)"
                try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
            }
        }
    }
    Start-Sleep -Seconds 2
}

function Wait-HttpOk([string]$url, [int]$timeoutSec = 45) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3
            if ($r.StatusCode -eq 200) { return $true }
        } catch {}
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Test-IsVolumeRoot([string]$path) {
    if (-not $path) { return $false }
    return ($path -match '^[A-Za-z]:\\?$')
}

function Test-SwitchAssertions($status, $config) {
    $errors = @()
    if ([string]$status.rootLifecycleState -ne "configured") {
        $errors += "rootLifecycleState=$($status.rootLifecycleState) want configured"
    }
    foreach ($r in @($status.roots)) {
        $clean = [string]$r
        if (Test-IsVolumeRoot $clean) {
            $errors += "unauthorized volume root: $clean"
        }
    }
    $scheme = ""
    if ($config -and $config.config) { $scheme = [string]$config.config.scanScheme }
    if ($scheme -and $scheme -ne "everything") {
        $errors += "scanScheme=$scheme want everything"
    }
    $maxMb = [int]$status.maxFileSizeMB
    if ($maxMb -gt 0 -and $maxMb -ne 16) {
        $errors += "maxFileSizeMB=$maxMb want 16"
    }
    return ,$errors
}

function Get-SidecarSnapshot {
    $hub = Get-Process -Name "nmer-hub" -ErrorAction SilentlyContinue | Select-Object -First 1
    $wails = Get-Process -Name "nmer-wails" -ErrorAction SilentlyContinue | Select-Object -First 1
    return [ordered]@{
        nmer_hub_running   = [bool]$hub
        nmer_wails_running = [bool]$wails
        hub_pid            = if ($hub) { $hub.Id } else { $null }
        wails_pid          = if ($wails) { $wails.Id } else { $null }
    }
}

$signoff = [ordered]@{
    capturedAt         = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    mode               = if ($FormalSignoff) { "formal" } elseif ($SwitchOnly) { "switch_only" } else { "default" }
    repoRoot           = $RepoRoot
    ahkReloadRequired  = $true
    switchPass         = $false
    overallPass        = $false
    assertions         = @()
    sidecar            = $null
    fulltext           = $null
    p0b                = $null
    p0c                = $null
    p2                 = $null
    p0a                = $null
    notes              = @("重载 牛马.ahk 后以 sidecar/process 与 P0A gate 为准")
}

Write-Host "== v4 Deploy ($($signoff.mode)): $RepoRoot =="

if (-not $SkipBuild) {
    Write-Host "[build] SearchCenterCore"
    Push-Location (Join-Path $RepoRoot "searchcore")
    go build -o (Join-Path $RepoRoot "tools\search\SearchCenterCore.exe") .
    if ($LASTEXITCODE -ne 0) { Pop-Location; throw "SearchCenterCore build failed" }
    Pop-Location

    Write-Host "[build] nmer-hub"
    Push-Location (Join-Path $RepoRoot "apps\nmer-hub")
    go mod tidy | Out-Null
    $hubOut = Join-Path $RepoRoot "apps\nmer-hub\build\bin"
    if (-not (Test-Path $hubOut)) { New-Item -ItemType Directory -Path $hubOut -Force | Out-Null }
    go build -o (Join-Path $hubOut "nmer-hub.exe") .
    if ($LASTEXITCODE -ne 0) { Pop-Location; throw "nmer-hub build failed" }
    Pop-Location
    $signoff["coreBuiltAt"] = (Get-Item (Join-Path $RepoRoot "tools\search\SearchCenterCore.exe")).LastWriteTimeUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    $signoff["hubBuiltAt"] = (Get-Item (Join-Path $hubOut "nmer-hub.exe")).LastWriteTimeUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
}

Write-Host "[migrate] fulltext config + settings"
$dataDir = Join-Path $RepoRoot "Data\search"
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
$configPath = Join-Path $dataDir "fulltext_config.json"
$settingsPath = Join-Path $dataDir "fulltext_settings.json"

$roots = New-Object System.Collections.Generic.List[string]
foreach ($p in @(
    (Join-Path $env:USERPROFILE "Documents"),
    (Join-Path $env:USERPROFILE "Desktop"),
    $RepoRoot
)) {
    if ($p -and (Test-Path $p)) { [void]$roots.Add((Resolve-Path $p).Path) }
}
if ($roots.Count -eq 0) { throw "no valid seed roots for migration" }

$cfg = @{
    maxScanSizeBytes  = 8388608
    knowledgeRoots    = @($roots)
    autoDiscoverRoots = $false
    rootsConfirmedAt  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    rootPolicyVersion = 1
    wizardDismissed   = $false
    idleIndexAfterSec = 0
}
if (Test-Path $configPath) {
    try {
        $old = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($old.presets) { $cfg["presets"] = $old.presets }
        if ($old.hotPresetNames) { $cfg["hotPresetNames"] = $old.hotPresetNames }
        if ($old.coldPresetNames) { $cfg["coldPresetNames"] = $old.coldPresetNames }
        if ($old.excludePaths) { $cfg["excludePaths"] = $old.excludePaths }
    } catch {}
}
$cfg | ConvertTo-Json -Depth 6 | Set-Content -Path $configPath -Encoding UTF8

$settings = @{
    autoStart        = $true
    workers          = 2
    scanScheme       = "everything"
    useUSN           = $true
    scanSpeed        = "normal"
    maxFileSizeMB    = 16
    includeLargeText = $false
    initialDelaySec  = 1
    pauseMS          = 5
}
if (Test-Path $settingsPath) {
    try {
        $oldS = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($oldS.indexDir) { $settings["indexDir"] = $oldS.indexDir }
    } catch {}
}
$settings | ConvertTo-Json -Depth 4 | Set-Content -Path $settingsPath -Encoding UTF8
Write-Host "  roots: $($roots -join '; ')"

Write-Host "[restart] nmer-hub + SearchCenterCore (kill wails)"
if ($FormalSignoff) {
    Stop-RepoAhkForSignoff $RepoRoot
}
Stop-ProcByName "nmer-wails.exe"
Stop-ProcByName "nmer-hub.exe"
Stop-ProcByName "SearchCenterCore.exe"

$hubExe = Join-Path $RepoRoot "apps\nmer-hub\build\bin\nmer-hub.exe"
if (-not (Test-Path $hubExe)) { throw "nmer-hub missing: $hubExe" }
$env:NMER_A2UI_BRIDGE_ADDR = "127.0.0.1:18791"
Start-Process -FilePath $hubExe -WorkingDirectory $RepoRoot -WindowStyle Hidden | Out-Null
if (-not (Wait-HttpOk "http://127.0.0.1:18791/agent/health" 20)) {
    Write-Warning "nmer-hub health timeout"
}

$coreExe = Join-Path $RepoRoot "tools\search\SearchCenterCore.exe"
if (-not (Test-Path $coreExe)) { throw "SearchCenterCore missing: $coreExe" }
$env:SEARCHCENTER_FT_USE_EVERYTHING = "1"
$env:SEARCHCENTER_FT_USE_MFT = "0"
$env:SEARCHCENTER_FT_USE_USN = "1"
$env:SEARCHCENTER_FT_MAX_FILE_MB = "16"
$env:SEARCHCENTER_IDLE_EXIT = "0"
Start-Process -FilePath $coreExe -ArgumentList @("-base", $RepoRoot) -WorkingDirectory $RepoRoot -WindowStyle Hidden | Out-Null
if (-not (Wait-HttpOk "http://127.0.0.1:8080/health" 30)) {
    throw "SearchCenterCore health timeout"
}

Write-Host "[roots] confirm via API"
$confirmBody = @{ roots = @($roots); remember = $true } | ConvertTo-Json
try {
    Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8080/v1/fulltext/roots/confirm" -Body $confirmBody -ContentType "application/json; charset=utf-8" -TimeoutSec 15 | Out-Null
} catch {
    Write-Warning "roots confirm: $_"
}

Start-Sleep -Seconds 5
$status = Invoke-RestMethod "http://127.0.0.1:8080/v1/fulltext/status" -TimeoutSec 15
$config = $null
try { $config = Invoke-RestMethod "http://127.0.0.1:8080/v1/fulltext/config" -TimeoutSec 10 } catch {}
Write-Host "  rootLifecycleState=$($status.rootLifecycleState) maxFileSizeMB=$($status.maxFileSizeMB)"
Write-Host "  roots=$([string]::Join(',', @($status.roots)))"

$assertErrors = Test-SwitchAssertions $status $config
$signoff["switchPass"] = ($assertErrors.Count -eq 0)
$signoff["assertions"] = @($assertErrors)
$signoff["sidecar"] = Get-SidecarSnapshot
$signoff["fulltext"] = [ordered]@{
    status = $status
    config = if ($config) { $config.config } else { $null }
}

$p0aScript = Join-Path $PSScriptRoot "Diagnose-P0ARootPolicyGate.ps1"
if (Test-Path $p0aScript) {
    Write-Host "[p0a] runtime gate"
    & $p0aScript -RepoRoot $RepoRoot | Out-Host
    $p0aPath = Join-Path $debugDir "p0a_root_policy_gate.json"
    if (Test-Path $p0aPath) {
        $signoff["p0a"] = Get-Content $p0aPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
}

Write-Host "[recover] SearchCenterCore production restart (Everything on, for baseline/soak)"
Stop-ProcByName "SearchCenterCore.exe" 4000
$env:SEARCHCENTER_FT_USE_EVERYTHING = "1"
$env:SEARCHCENTER_FT_USE_MFT = "0"
$env:SEARCHCENTER_FT_USE_USN = "1"
$env:SEARCHCENTER_FT_MAX_FILE_MB = "16"
$env:SEARCHCENTER_IDLE_EXIT = "0"
Start-Process -FilePath $coreExe -ArgumentList @("-base", $RepoRoot) -WorkingDirectory $RepoRoot -WindowStyle Hidden | Out-Null
if (-not (Wait-HttpOk "http://127.0.0.1:8080/health" 60)) {
    Write-Warning "SearchCenterCore production restart health timeout (soak may fail)"
} else {
    Start-Sleep -Seconds 15
    try {
        $confirmBody = @{ roots = @($roots); remember = $true } | ConvertTo-Json
        Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8080/v1/fulltext/roots/confirm" -Body $confirmBody -ContentType "application/json; charset=utf-8" -TimeoutSec 15 | Out-Null
    } catch {
        Write-Warning "roots re-confirm after p0a: $_"
    }
}

if ($WithQuickSample -or $FormalSignoff) {
    Write-Host "[p0b] capture baseline"
    & (Join-Path $PSScriptRoot "capture-memory-baseline.ps1") -RepoRoot $RepoRoot | Out-Host
    $baselinePath = Join-Path $debugDir "a2ui_memory_baseline.json"
    if (Test-Path $baselinePath) {
        $bl = Get-Content $baselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $signoff["p0b"] = [ordered]@{
            preFormalBaseline = -not $FormalSignoff
            webview2_cap_exceeded = $bl.processes.webview2_cap_exceeded
            webview2_count = $bl.processes.webview2_count
            webview2_host_control_count = $bl.processes.webview2_host_control_count
            totalPrivateMiB = $bl.processes.totalPrivateMiB
            pass = (-not $bl.processes.webview2_cap_exceeded)
        }
    }
}

if (-not $SkipSoak) {
    Write-Host "[p0c-prep] pause indexer before soak"
    for ($i = 0; $i -lt 24; $i++) {
        try {
            $stopBody = @{ action = "stop" } | ConvertTo-Json
            Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8080/v1/fulltext/control" -Body $stopBody -ContentType "application/json; charset=utf-8" -TimeoutSec 45 | Out-Null
            Start-Sleep -Seconds 5
            $stPause = Invoke-RestMethod "http://127.0.0.1:8080/v1/fulltext/status" -TimeoutSec 15
            if ($stPause -and -not [bool]$stPause.running -and [string]$stPause.scanPhase -eq "idle") {
                Write-Host "  indexer paused (attempt $($i + 1))"
                break
            }
        } catch {
            Write-Warning "  stop attempt $($i + 1): $_"
        }
        Start-Sleep -Seconds 5
    }
    $soakArgs = @{
        RepoRoot = $RepoRoot
        DurationMinutes = $SoakMinutes
        WindowCycles = if ($FormalSignoff) { 10 } else { 3 }
        PauseIndexerForIdleSlope = $true
    }
    if ($FormalSignoff) { $soakArgs["FormalSignoff"] = $true }
    Write-Host "[p0c] soak ($SoakMinutes min)"
    & (Join-Path $PSScriptRoot "Run-MemorySoakTest.ps1") @soakArgs | Out-Host
    $soakPath = Join-Path $debugDir "memory_soak.json"
    if (Test-Path $soakPath) {
        $signoff["p0c"] = Get-Content $soakPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
}

if ($WithIdleExitTest) {
    Write-Host "[p2] idle process exit (quick)"
    & (Join-Path $PSScriptRoot "Test-IdleProcessExit.ps1") -RepoRoot $RepoRoot -Quick | Out-Host
    $p2Path = Join-Path $debugDir "p2_idle_process_exit.json"
    if (Test-Path $p2Path) {
        $signoff["p2"] = Get-Content $p2Path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
}

$p0aPass = $false
if ($signoff.p0a -and $signoff.p0a.overallPass -eq $true) { $p0aPass = $true }
$p0bPass = $false
if ($signoff.p0b -and $signoff.p0b.pass -eq $true) { $p0bPass = $true }
$p0cPass = $false
if ($signoff.p0c -and $signoff.p0c.overallPass -eq $true) { $p0cPass = $true }
$p2Pass = $false
if ($signoff.p2 -and $signoff.p2.overallPass -eq $true) { $p2Pass = $true }
$sidecarPass = ($signoff.sidecar.nmer_hub_running -and -not $signoff.sidecar.nmer_wails_running)

if ($SwitchOnly) {
    $signoff["overallPass"] = ($signoff.switchPass -and $sidecarPass)
} elseif ($WithIdleExitTest) {
    $signoff["overallPass"] = ($signoff.switchPass -and $sidecarPass -and $p0aPass -and $p0bPass -and $p0cPass -and $p2Pass)
} else {
    $signoff["overallPass"] = ($signoff.switchPass -and $sidecarPass -and $p0aPass -and $p0bPass -and $p0cPass)
}

$signoff | ConvertTo-Json -Depth 8 | Set-Content -Path $signoffPath -Encoding UTF8
Write-Host "== deploy done: $signoffPath =="
Write-Host "  switchPass=$($signoff.switchPass) sidecarPass=$sidecarPass overallPass=$($signoff.overallPass)"
Write-Host "  >>> 请重载 牛马.ahk 使 AHK 侧车路径与 sidecarHost=hub 一致 <<<"

if ($FormalSignoff -and -not $signoff.overallPass) { exit 1 }
if ($SwitchOnly -and -not $signoff.switchPass) { exit 1 }
exit 0
