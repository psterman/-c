param(
    [string]$Root = "",
    [int]$OfflineMs = 300000,
    [int]$IntervalMs = 1200,
    [int]$TimeoutMs = 420000,
    [int]$Port = 19191
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"

function Read-AhkChoice {
    param([string]$RootPath)
    $p = Join-Path $RootPath "Cache\ahk_launch_choice.txt"
    if (!(Test-Path $p)) { return $null }
    $m = @{}
    foreach ($line in (Get-Content -LiteralPath $p -Encoding UTF8)) {
        if ($line -match "=") {
            $kv = $line.Split("=", 2)
            $m[$kv[0].Trim()] = $kv[1].Trim()
        }
    }
    if ($m.ContainsKey("exe") -and $m.ContainsKey("mode")) {
        return [pscustomobject]@{ Exe = $m["exe"]; Mode = $m["mode"] }
    }
    return $null
}

function Invoke-Ahk {
    param(
        [string]$Exe,
        [string]$ScriptPath,
        [string]$Mode,
        [string[]]$ExtraArgs
    )
    $args = @()
    switch ($Mode) {
        "errorstdout_with_cwd" { $args = @("/ErrorStdOut", $ScriptPath) + $ExtraArgs }
        "errorstdout" { $args = @("/ErrorStdOut", $ScriptPath) + $ExtraArgs }
        default { $args = @($ScriptPath) + $ExtraArgs }
    }
    $wd = Split-Path -Parent $ScriptPath
    if ($Mode -like "*with_cwd") {
        Push-Location $wd
        try { & $Exe @args } finally { Pop-Location }
    } else {
        & $Exe @args
    }
}

$choice = Read-AhkChoice -RootPath $Root
if ($null -eq $choice -or -not (Test-Path $choice.Exe)) {
    throw "AHK launch choice missing. Run tools/ci/TryAhkLaunchMatrix.ps1 first."
}

$probeScript = Nmer-ResolveCiScript $Root "CoreAsyncHttpRecoveryProbe.ahk"
$reportPath = Join-Path $Root "Cache\core_async_http_recovery_report.txt"
$offlineUrl = "http://127.0.0.1:9/recovery_probe"
$onlineUrl = "http://127.0.0.1:$Port/recovery_probe"
$listenerScript = Nmer-ResolveCiScript $Root "RecoveryProbeListener.ps1"
$listenerProc = $null

if (Test-Path $reportPath) { Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue }

try {
    if (Test-Path $listenerScript) {
        $listenerProc = Start-Process -FilePath "powershell.exe" `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $listenerScript, "-Port", $Port) `
            -WindowStyle Hidden -PassThru
        Start-Sleep -Seconds 2
    }
    Write-Output "recovery_probe_start offline_ms=$OfflineMs interval_ms=$IntervalMs timeout_ms=$TimeoutMs online_url=$onlineUrl listener=$([bool]$listenerProc)"
    Invoke-Ahk -Exe $choice.Exe -ScriptPath $probeScript -Mode $choice.Mode -ExtraArgs @("$OfflineMs", "$IntervalMs", "$TimeoutMs", $offlineUrl, $onlineUrl)
} finally {
    if ($listenerProc -and -not $listenerProc.HasExited) {
        try { Stop-Process -Id $listenerProc.Id -Force -ErrorAction SilentlyContinue } catch {}
    }
}

$waitUntil = (Get-Date).AddMilliseconds($TimeoutMs + 120000)
while ((Get-Date) -lt $waitUntil) {
    if (Test-Path $reportPath) { break }
    Start-Sleep -Milliseconds 500
}

if (Test-Path $reportPath) {
    Get-Content -LiteralPath $reportPath -Encoding UTF8
} else {
    Write-Output "recovery_report_missing=$reportPath"
}
