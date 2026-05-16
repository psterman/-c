param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int]$OfflineMs = 300000,
    [int]$IntervalMs = 1200,
    [int]$TimeoutMs = 420000,
    [int]$Port = 19191
)

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
    throw "AHK launch choice missing. Run scripts/TryAhkLaunchMatrix.ps1 first."
}

$probeScript = Join-Path $Root "scripts\CoreAsyncHttpRecoveryProbe.ahk"
$reportPath = Join-Path $Root "Cache\core_async_http_recovery_report.txt"
$offlineUrl = "http://127.0.0.1:$Port/recovery_probe"
$onlineUrl = $offlineUrl

if (Test-Path $reportPath) { Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue }

$listenerJob = $null
try {
    Write-Output "recovery_probe_start offline_ms=$OfflineMs interval_ms=$IntervalMs timeout_ms=$TimeoutMs port=$Port"
    Invoke-Ahk -Exe $choice.Exe -ScriptPath $probeScript -Mode $choice.Mode -ExtraArgs @("$OfflineMs", "$IntervalMs", "$TimeoutMs", $offlineUrl, $onlineUrl)

    $delay = [Math]::Max(1000, $OfflineMs + 500)
    Start-Sleep -Milliseconds $delay

    $listenerJob = Start-Job -ScriptBlock {
        param($PortArg)
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add("http://127.0.0.1:$PortArg/")
        $listener.Start()
        try {
            $end = (Get-Date).AddMinutes(10)
            while ((Get-Date) -lt $end) {
                if (-not $listener.IsListening) { break }
                $ctx = $listener.GetContext()
                $resp = $ctx.Response
                $buf = [System.Text.Encoding]::UTF8.GetBytes("ok")
                $resp.StatusCode = 200
                $resp.ContentType = "text/plain; charset=utf-8"
                $resp.ContentLength64 = $buf.Length
                $resp.OutputStream.Write($buf, 0, $buf.Length)
                $resp.OutputStream.Close()
            }
        } finally {
            try { $listener.Stop() } catch {}
            try { $listener.Close() } catch {}
        }
    } -ArgumentList $Port

    $waitUntil = (Get-Date).AddMilliseconds($TimeoutMs + 30000)
    while ((Get-Date) -lt $waitUntil) {
        if (Test-Path $reportPath) { break }
        Start-Sleep -Milliseconds 500
    }

    if (Test-Path $reportPath) {
        Get-Content -LiteralPath $reportPath -Encoding UTF8
    } else {
        Write-Output "recovery_report_missing=$reportPath"
    }
}
finally {
    if ($listenerJob) {
        try { Stop-Job -Job $listenerJob -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
        try { Remove-Job -Job $listenerJob -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
    }
}
