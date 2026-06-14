# SC 联网 WebView2 探针：豆包 / Gemini / 谷歌 / YouTube 加载与内存采样
param(
    [string]$RepoRoot = "",
    [string[]]$Engines = @("doubao", "gemini", "google", "youtube"),
    [string]$Query = "牛马搜索探针",
    [int]$NavWaitMs = 12000,
    [int]$SettleMs = 5000,
    [switch]$Interactive,
    [switch]$KeepOpen,
    [switch]$SkipMemory,
    [switch]$PauseIndexer
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }

$probe = Join-Path $PSScriptRoot "Invoke-ScWebEmbedProbe.ps1"
$capture = Join-Path $PSScriptRoot "capture-memory-baseline.ps1"
$outPath = Join-Path $debugDir "sc_web_embed_probe_report.json"
$reportEngines = @()

function Invoke-ScWebProbe {
    param(
        [string]$Action,
        [string]$Engine = "",
        [int]$WaitMs = 0
    )
    $args = @{
        RepoRoot = $RepoRoot
        Action   = $Action
        Engine   = $Engine
        Query    = $Query
        WaitMs   = $WaitMs
    }
    return & $probe @args
}

function Get-MemorySnapshot {
    param([string]$Label)
    if ($SkipMemory) {
        return [ordered]@{ label = $Label; skipped = $true }
    }
    & $capture -RepoRoot $RepoRoot | Out-Null
    $baselinePath = Join-Path $debugDir "a2ui_memory_baseline.json"
    if (-not (Test-Path $baselinePath)) {
        return [ordered]@{ label = $Label; error = "missing_baseline" }
    }
    $b = Get-Content $baselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $proc = $b.processes
    return [ordered]@{
        label                   = $Label
        capturedAt              = $b.capturedAt
        totalPrivateMiB         = [double]$proc.totalPrivateMiB
        uiPrivateMiB            = [double]$proc.uiPrivateMiB
        webview2PrivateMiB      = [double]$proc.webview2_totalPrivate
        webview2Count           = [int]$proc.webview2_count
        webview2HostRootCount   = [int]$proc.webview2_host_root_count
        hubPrivateMiB           = if ($proc.nmer_sidecar) { [double]$proc.nmer_sidecar.privateMiB } else { $null }
        searchCorePrivateMiB    = [double]$proc.searchCorePrivateMiB
    }
}

function Add-DeltaRow {
    param($Before, $After)
    if (-not $Before -or -not $After -or $Before.skipped -or $After.skipped) { return $null }
    return [ordered]@{
        totalPrivateMiB    = [math]::Round([double]$After.totalPrivateMiB - [double]$Before.totalPrivateMiB, 2)
        uiPrivateMiB       = [math]::Round([double]$After.uiPrivateMiB - [double]$Before.uiPrivateMiB, 2)
        webview2PrivateMiB = [math]::Round([double]$After.webview2PrivateMiB - [double]$Before.webview2PrivateMiB, 2)
        webview2Count      = [int]$After.webview2Count - [int]$Before.webview2Count
    }
}

Write-Host "=== SC WebView2 embed probe ===" -ForegroundColor Cyan
Write-Host ("engines: {0}" -f ($Engines -join ", "))
Write-Host ("query: {0}" -f $Query)
Write-Host "Requires: reload 牛马.ahk after ScWebEmbedProbe.ahk is added" -ForegroundColor DarkYellow

if ($PauseIndexer) {
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:8080/v1/fulltext/control" -Method Post -Body '{"action":"stop"}' -ContentType "application/json" -TimeoutSec 5 | Out-Null
        Write-Host "SearchCore indexer paused (stop)" -ForegroundColor DarkGray
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "SearchCore pause skipped (not running or API unavailable)" -ForegroundColor DarkYellow
    }
}

$ping = Invoke-ScWebProbe -Action ping
if (-not $ping.pass) {
    throw "probe PING failed — reload 牛马.ahk"
}

$memBeforeOpen = Get-MemorySnapshot -Label "before_open"
$open = Invoke-ScWebProbe -Action open
if (-not $open.pass) {
    throw "probe OPEN failed: $($open.detail)"
}
Start-Sleep -Seconds 2
$memAfterOpen = Get-MemorySnapshot -Label "after_open"
$openDelta = Add-DeltaRow $memBeforeOpen $memAfterOpen

foreach ($eng in @($Engines)) {
    $eng = [string]$eng.Trim().ToLower()
    if (-not $eng) { continue }
    Write-Host ""
    Write-Host ("--- engine: {0} ---" -f $eng) -ForegroundColor Yellow

    $memBeforeNav = Get-MemorySnapshot -Label ("before_" + $eng)
    $nav = Invoke-ScWebProbe -Action navigate -Engine $eng -WaitMs $NavWaitMs
    $navPass = [bool]$nav.pass
    $navCode = [string]$nav.code
    $navUrl = ""
    $navMs = $null
  if ($nav.PSObject.Properties.Name -contains "url") { $navUrl = [string]$nav.url }
    if ($nav.PSObject.Properties.Name -contains "navMs") { $navMs = $nav.navMs }

    if ($Interactive) {
        Write-Host "探针窗口已打开，请目视检查页面加载/登录/搜索效果。" -ForegroundColor Green
        Write-Host "检查完毕后按 Enter 继续采样内存…" -ForegroundColor Green
        [void][System.Console]::ReadLine()
    } elseif ($SettleMs -gt 0) {
        Start-Sleep -Milliseconds $SettleMs
    }

    $memAfterNav = Get-MemorySnapshot -Label ("after_" + $eng)
    $navDelta = Add-DeltaRow $memBeforeNav $memAfterNav

    $row = [ordered]@{
        engine        = $eng
        query         = $Query
        navPass       = $navPass
        navCode       = $navCode
        navUrl        = $navUrl
        navMs         = $navMs
        memoryBefore  = $memBeforeNav
        memoryAfter   = $memAfterNav
        memoryDelta   = $navDelta
    }
    $reportEngines += $row

    $dUi = if ($navDelta) { $navDelta.uiPrivateMiB } else { "n/a" }
    $dWv = if ($navDelta) { $navDelta.webview2PrivateMiB } else { "n/a" }
    Write-Host ("  nav={0} url={1}" -f $navCode, $(if ($navUrl.Length -gt 72) { $navUrl.Substring(0, 72) + "…" } else { $navUrl }))
    Write-Host ("  Δui={0} MiB  Δwebview2={1} MiB" -f $dUi, $dWv) -ForegroundColor $(if ($navPass) { "Green" } else { "Yellow" })

    if (-not $KeepOpen -and -not $Interactive) {
        Invoke-ScWebProbe -Action blank -WaitMs 2000 | Out-Null
        Start-Sleep -Seconds 1
    }
}

$memBeforeClose = Get-MemorySnapshot -Label "before_close"
if (-not $KeepOpen) {
    Invoke-ScWebProbe -Action close | Out-Null
    Start-Sleep -Seconds 2
    $memAfterClose = Get-MemorySnapshot -Label "after_close"
} else {
    Write-Host ""
    Write-Host "KeepOpen: 探针窗口保持打开，请手动关闭或运行 -Action dispose" -ForegroundColor Cyan
    $memAfterClose = Get-MemorySnapshot -Label "after_keep_open"
}
$closeDelta = Add-DeltaRow $memBeforeClose $memAfterClose

$report = [ordered]@{
    capturedAt   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    gate         = "sc_web_embed_probe"
    query        = $Query
    engines      = @($reportEngines)
    interactive  = [bool]$Interactive
    keepOpen     = [bool]$KeepOpen
    navWaitMs    = $NavWaitMs
    settleMs     = $SettleMs
    openMemory   = [ordered]@{
        before = $memBeforeOpen
        after  = $memAfterOpen
        delta  = $openDelta
    }
    closeMemory  = [ordered]@{
        before = $memBeforeClose
        after  = $memAfterClose
        delta  = $closeDelta
    }
    artifacts    = @(
        "Cache/debug/sc_web_embed_probe_report.json",
        "Cache/debug/sc_web_embed_probe.log",
        "Cache/debug/a2ui_memory_baseline.json"
    )
    notes        = @(
        "gemini 仅打开 https://gemini.google.com/app（无 URL 预填词）；需在窗口内手动提问验证",
        "google/youtube 受网络环境影响；失败记入 navCode",
        "Δ 以 uiPrivateMiB / webview2PrivateMiB 为主（不含 SearchCore 索引噪声时对比更清晰）"
    )
}

$report | ConvertTo-Json -Depth 10 | Set-Content -Path $outPath -Encoding UTF8
Write-Host ""
Write-Host ("report -> {0}" -f $outPath) -ForegroundColor Green

if ($KeepOpen -or $Interactive) {
    Write-Host "dispose: .\tools\a2ui-diagnostics\memory\Invoke-ScWebEmbedProbe.ps1 -Action dispose" -ForegroundColor DarkGray
}

exit 0
