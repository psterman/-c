# 采集 v4 签核前置状态，写入 Cache/debug/v4_signoff_dashboard.json
param(
    [string]$RepoRoot = "",
    [switch]$SkipBaselineCapture,
    [switch]$RunP0AQuick,
    [switch]$SkipP0A
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Continue"
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
$outPath = Join-Path $debugDir "v4_signoff_dashboard.json"
$flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"

function Test-IsVolumeRoot([string]$path) {
    if (-not $path) { return $false }
    return ($path -match '^[A-Za-z]:\\?$')
}

function Get-HealthSnapshot {
    try {
        return Invoke-RestMethod -Uri "http://127.0.0.1:18791/agent/health" -TimeoutSec 4
    } catch {
        return $null
    }
}

function Get-FullTextPair {
    $status = $null
    $config = $null
    try { $status = Invoke-RestMethod "http://127.0.0.1:8080/v1/fulltext/status" -TimeoutSec 8 } catch {}
    try { $config = Invoke-RestMethod "http://127.0.0.1:8080/v1/fulltext/config" -TimeoutSec 8 } catch {}
    return $status, $config
}

function Test-SwitchAssertions($status, $config) {
    $errors = @()
    if (-not $status) {
        $errors += "fulltext status unavailable"
        return ,$errors
    }
    if ([string]$status.rootLifecycleState -ne "configured") {
        $errors += "rootLifecycleState=$($status.rootLifecycleState) want configured"
    }
    foreach ($r in @($status.roots)) {
        if (Test-IsVolumeRoot ([string]$r)) { $errors += "volume root: $r" }
    }
    $scheme = ""
    if ($config -and $config.config) { $scheme = [string]$config.config.scanScheme }
    if ($scheme -and $scheme -ne "everything") { $errors += "scanScheme=$scheme want everything" }
    $maxMb = [int]$status.maxFileSizeMB
    if ($maxMb -gt 0 -and $maxMb -ne 16) { $errors += "maxFileSizeMB=$maxMb want 16" }
    return ,$errors
}

# --- capture baseline ---
if (-not $SkipBaselineCapture) {
    & (Join-DiagScript -RelativePath "memory/capture-memory-baseline.ps1") -RepoRoot $RepoRoot | Out-Host
}

# --- P0A ---
$p0aPath = Join-Path $debugDir "p0a_root_policy_gate.json"
if ($RunP0AQuick -and -not $SkipP0A) {
    & (Join-DiagScript -RelativePath "memory/Diagnose-P0ARootPolicyGate.ps1") -RepoRoot $RepoRoot -SkipSetupTest | Out-Host
}

# --- read artifacts ---
$baseline = $null
$baselinePath = Join-Path $debugDir "a2ui_memory_baseline.json"
if (Test-Path $baselinePath) {
    try { $baseline = Get-Content $baselinePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}
$p0a = $null
if (Test-Path $p0aPath) {
    try { $p0a = Get-Content $p0aPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}
$signoff = $null
$signoffPath = Join-Path $debugDir "v4_signoff.json"
if (Test-Path $signoffPath) {
    try { $signoff = Get-Content $signoffPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}

$hub = Get-Process -Name "nmer-hub" -ErrorAction SilentlyContinue | Select-Object -First 1
$wails = Get-Process -Name "nmer-wails" -ErrorAction SilentlyContinue | Select-Object -First 1
$core = Get-Process -Name "SearchCenterCore" -ErrorAction SilentlyContinue | Select-Object -First 1
$ahk = Get-Process -Name "AutoHotkey64","AutoHotkey32" -ErrorAction SilentlyContinue | Where-Object {
    try {
        $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
        return ($cmd -like "*$RepoRoot*" -or $cmd -like "*牛马.ahk*")
    } catch { return $false }
} | Select-Object -First 1

$health = Get-HealthSnapshot
$sidecarHostFlag = "hub"
if (Test-Path $flagsPath) {
    try {
        $flags = Get-Content $flagsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $sidecarHostFlag = [string]$flags.wailsBridge.sidecarHost
        if ([string]$sidecarHostFlag -ne "wails") { $sidecarHostFlag = "hub" }
    } catch {}
}

$ftStatus, $ftConfig = Get-FullTextPair
$switchErrors = Test-SwitchAssertions $ftStatus $ftConfig

$wv2Count = $null
$wv2Cap = $null
$wv2HostCtrl = $null
$totalPrivate = $null
$emptyLoad = $null
$snapshotKind = ""
if ($baseline) {
    if ($baseline.processes) {
        $wv2Count = [int]$baseline.processes.webview2_count
        $wv2Cap = [bool]$baseline.processes.webview2_cap_exceeded
        $wv2HostCtrl = [int]$baseline.processes.webview2_host_control_count
        $totalPrivate = [double]$baseline.processes.totalPrivateMiB
    }
    if ($baseline.PSObject.Properties.Name -contains "emptyLoadPrivateMiB") {
        $emptyLoad = [double]$baseline.emptyLoadPrivateMiB
    }
    if ($baseline.PSObject.Properties.Name -contains "snapshotKind") {
        $snapshotKind = [string]$baseline.snapshotKind
    }
}

$sidecarPass = [bool]$hub -and -not $wails -and $health -and ($health.ok -eq $true)
$p0aPass = $false
if ($p0a -and $p0a.overallPass -eq $true) { $p0aPass = $true }
$p0bPass = ($null -ne $wv2Cap) -and (-not $wv2Cap) -and ($snapshotKind -ne "cp_loaded")
$wv2HostRoots = $null
if ($baseline -and $baseline.processes -and $null -ne $baseline.processes.webview2_host_root_count) {
    $wv2HostRoots = [int]$baseline.processes.webview2_host_root_count
}
$switchPass = ($switchErrors.Count -eq 0)

$manualSteps = @(
    [ordered]@{
        id = "reload_ahk"
        title = "重载 牛马.ahk"
        autoCheck = ($sidecarHostFlag -eq "hub")
        pass = $sidecarPass
        hint = "Ctrl+Shift+Q 或托盘「重启脚本」；确认仅有 nmer-hub"
    },
    [ordered]@{
        id = "close_surfaces"
        title = "关闭 CP / SC / Config 并 Dispose"
        autoCheck = $false
        pass = $p0bPass
        hint = "Esc 关各面板 → 命令面板执行 >dispose config / clipboard / ftb → 静置 15s"
    },
    [ordered]@{
        id = "empty_baseline"
        title = "空载 P0B 采样"
        autoCheck = $true
        pass = $p0bPass
        hint = "本看板刷新时会自动跑 capture-memory-baseline.ps1"
    }
)

$gates = @(
    [ordered]@{
        id = "sidecar"
        title = "侧车 hub"
        pass = $sidecarPass
        metrics = @{
            sidecarHostFlag = $sidecarHostFlag
            nmer_hub = if ($hub) { $hub.Id } else { $null }
            nmer_wails = if ($wails) { $wails.Id } else { $null }
            health_ok = if ($health) { $health.ok } else { $false }
            provider = if ($health) { [string]$health.provider } else { "" }
        }
    },
    [ordered]@{
        id = "switch"
        title = "运行态切换"
        pass = $switchPass
        metrics = @{
            rootLifecycleState = if ($ftStatus) { [string]$ftStatus.rootLifecycleState } else { "" }
            scanScheme = if ($ftConfig -and $ftConfig.config) { [string]$ftConfig.config.scanScheme } else { "" }
            maxFileSizeMB = if ($ftStatus) { [int]$ftStatus.maxFileSizeMB } else { 0 }
            roots = if ($ftStatus) { @($ftStatus.roots) } else { @() }
        }
        errors = @($switchErrors)
    },
    [ordered]@{
        id = "p0a"
        title = "P0A 根策略"
        pass = $p0aPass
        metrics = @{
            gateCount = if ($p0a -and $p0a.gates) { @($p0a.gates).Count } else { 0 }
            capturedAt = if ($p0a) { [string]$p0a.capturedAt } else { "" }
        }
        gates = if ($p0a -and $p0a.gates) { @($p0a.gates) } else { @() }
    },
    [ordered]@{
        id = "p0b"
        title = "P0B WebView cap"
        pass = $p0bPass
        metrics = @{
            webview2_host_root_count = if ($null -ne $wv2HostRoots) { $wv2HostRoots } else { $wv2HostCtrl }
            webview2_descendant_count = $wv2Count
            webview2_count = $wv2Count
            webview2_host_control_count = $wv2HostCtrl
            webview2_cap = 4
            webview2_cap_exceeded = $wv2Cap
            emptyLoadPrivateMiB = $emptyLoad
            totalPrivateMiB = $totalPrivate
            snapshotKind = $snapshotKind
        }
    }
)

$readyForFormal = $sidecarPass -and $switchPass -and $p0aPass -and $p0bPass

$report = [ordered]@{
    capturedAt          = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    repoRoot            = $RepoRoot
    readyForFormalSignoff = $readyForFormal
    gates               = $gates
    manualSteps         = $manualSteps
    processes           = [ordered]@{
        nmer_hub           = if ($hub) { @{ id = $hub.Id; start = $hub.StartTime.ToString("o") } } else { $null }
        nmer_wails         = if ($wails) { @{ id = $wails.Id } } else { $null }
        search_center_core = if ($core) { @{ id = $core.Id } } else { $null }
        ahk                = if ($ahk) { @{ id = $ahk.Id; name = $ahk.ProcessName } } else { $null }
    }
    lastSignoff         = if ($signoff) {
        [ordered]@{
            mode = [string]$signoff.mode
            overallPass = [bool]$signoff.overallPass
            capturedAt = [string]$signoff.capturedAt
        }
    } else { $null }
    commands            = [ordered]@{
        refreshDashboard = ".\tools\a2ui-diagnostics\Open-V4SignoffDashboard.ps1"
        refreshP0A       = ".\tools\a2ui-diagnostics\Open-V4SignoffDashboard.ps1 -RunP0AQuick"
        switchOnly       = ".\tools\a2ui-diagnostics\Deploy-MemoryIndexBaseline.ps1 -SwitchOnly -SkipBuild"
        formalSignoff    = ".\tools\a2ui-diagnostics\Deploy-MemoryIndexBaseline.ps1 -FormalSignoff"
    }
    notes               = @(
        "浏览器内 F5 不会更新数据；须重新运行 Open-V4SignoffDashboard.ps1",
        "Dispose 步骤须在牛马里手动完成，看板只检测 webview2_count 是否过线",
        "正式签核约 30 分钟，通过后再跑 -FormalSignoff"
    )
}

$report | ConvertTo-Json -Depth 10 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "v4_signoff_dashboard -> $outPath readyForFormal=$readyForFormal"
foreach ($g in $gates) {
    $mark = if ($g.pass) { "PASS" } else { "FAIL" }
    Write-Host ("  [{0}] {1}" -f $mark, $g.title)
}
exit $(if ($readyForFormal) { 0 } else { 2 })
