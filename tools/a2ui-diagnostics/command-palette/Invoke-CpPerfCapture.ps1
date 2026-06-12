# CP perf capture via hub inject (cp_perf_capture) + CommandPalettePerfProbe.ahk host-side input.
param(
    [ValidateSet("synthetic_turbo", "manual_equivalent")]
    [string]$Mode = "synthetic_turbo",
    [switch]$Quick,
    [switch]$SkipGate,
    [switch]$ClearLog,
    [int]$TimeoutSec = 180,
    [switch]$SkipReload
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$repo = Get-DiagRepoRoot -From $here
$logPath = Join-Path $repo "Cache\debug\command_palette_perf.ndjson"
$injectRes = Join-Path $repo "Cache\debug\hybrid_signoff_inject_result.json"
$scriptPath = Join-Path $repo "牛马.ahk"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Write-JsonFile([string]$path, [string]$json) {
    [System.IO.File]::WriteAllText($path, $json, $utf8NoBom)
}

function Invoke-NiumaReload {
    Get-Process -Name "AutoHotkey64" -ErrorAction SilentlyContinue | Where-Object {
        $_.Id -ne $PID -and $_.CommandLine -match 'CommandPalettePerfProbe'
    } | Stop-Process -Force -ErrorAction SilentlyContinue
    $proc = Get-Process -Name "AutoHotkey64" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $proc) {
        Write-Host "  Starting niuma.ahk" -ForegroundColor Yellow
        Start-Process -FilePath $scriptPath
        Start-Sleep -Seconds 35
        return
    }
    $exe = $proc.Path
    Write-Host "  Reload niuma.ahk (wait ~35s for hybrid inject)" -ForegroundColor DarkGray
    Stop-Process -Id $proc.Id -Force
    Start-Sleep -Seconds 2
    Start-Process -FilePath $exe -ArgumentList @("`"$scriptPath`"")
    Start-Sleep -Seconds 35
}

function Invoke-HubInjectPing {
    param([int]$TimeoutSec = 20)
    $addr = if ($env:NMER_A2UI_BRIDGE_ADDR) { $env:NMER_A2UI_BRIDGE_ADDR } else { "127.0.0.1:18791" }
    $base = "http://$addr"
    $probeId = "ping-" + (Get-Date -Format "HHmmssfff")
    if (Test-Path $injectRes) { Remove-Item $injectRes -Force -ErrorAction SilentlyContinue }
    try {
        $reg = @{ action = "register_external"; entry = "cp-perf-capture" } | ConvertTo-Json -Compress
        Invoke-RestMethod -Method Post -Uri "$base/shell/ftb" -Body $reg -ContentType "application/json; charset=utf-8" -TimeoutSec 8 | Out-Null
        $wake = @{ type = "hybrid_probe_wake"; probeId = "wake-$probeId" } | ConvertTo-Json -Compress
        Invoke-RestMethod -Method Post -Uri "$base/shell/ftb/inject" -Body $wake -ContentType "application/json; charset=utf-8" -TimeoutSec 8 | Out-Null
        Start-Sleep -Milliseconds 400
        $body = @{ type = "hybrid_signoff_ping"; probeId = $probeId } | ConvertTo-Json -Compress
        Invoke-RestMethod -Method Post -Uri "$base/shell/ftb/inject" -Body $body -ContentType "application/json; charset=utf-8" -TimeoutSec 10 | Out-Null
    } catch {
        return $false
    }
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $injectRes) {
            try {
                $res = Get-Content $injectRes -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($res.probeId -eq $probeId -and $res.code -eq "PING_OK") { return $true }
            } catch { }
        }
        Start-Sleep -Milliseconds 300
    }
    return $false
}

function Read-HubInjectResult {
    param([string]$Path, [string]$ProbeId)
    if (-not (Test-Path $Path)) { return $null }
    $raw = Get-Content $Path -Raw -Encoding UTF8
    if (-not $raw) { return $null }
    $chunks = @()
    if ($raw -match '^\s*\{') {
        $depth = 0
        $start = -1
        for ($i = 0; $i -lt $raw.Length; $i++) {
            $ch = $raw[$i]
            if ($ch -eq '{') {
                if ($depth -eq 0) { $start = $i }
                $depth++
            } elseif ($ch -eq '}') {
                $depth--
                if ($depth -eq 0 -and $start -ge 0) {
                    $chunks += $raw.Substring($start, $i - $start + 1)
                    $start = -1
                }
            }
        }
    }
    for ($i = $chunks.Count - 1; $i -ge 0; $i--) {
        try {
            $res = $chunks[$i] | ConvertFrom-Json
            if ($res.probeId -eq $ProbeId) { return $res }
        } catch { }
    }
    return $null
}

function Invoke-HubCpPerfCapture {
    param(
        [int]$TimeoutSec = 120,
        [string]$Mode = "synthetic_turbo"
    )
    $addr = if ($env:NMER_A2UI_BRIDGE_ADDR) { $env:NMER_A2UI_BRIDGE_ADDR } else { "127.0.0.1:18791" }
    $base = "http://$addr"
    $probeId = "cp-perf-" + (Get-Date -Format "HHmmssfff")
    if (Test-Path $injectRes) { Remove-Item $injectRes -Force -ErrorAction SilentlyContinue }
    $reg = @{ action = "register_external"; entry = "cp-perf-capture" } | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Post -Uri "$base/shell/ftb" -Body $reg -ContentType "application/json; charset=utf-8" -TimeoutSec 8 | Out-Null
    $wake = @{ type = "hybrid_probe_wake"; probeId = "wake-$probeId" } | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Post -Uri "$base/shell/ftb/inject" -Body $wake -ContentType "application/json; charset=utf-8" -TimeoutSec 8 | Out-Null
    Start-Sleep -Milliseconds 500
    $body = @{ type = "cp_perf_capture"; probeId = $probeId; mode = $Mode } | ConvertTo-Json -Compress
    $inj = Invoke-RestMethod -Method Post -Uri "$base/shell/ftb/inject" -Body $body -ContentType "application/json; charset=utf-8" -TimeoutSec 10
    if ($inj.ok -ne $true) { throw "cp_perf_capture inject not queued: $($inj.code)" }
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $res = Read-HubInjectResult -Path $injectRes -ProbeId $probeId
        if ($res -and $res.code -ne "CP_PERF_PENDING") {
            return $res
        }
        Start-Sleep -Milliseconds 400
    }
    return $null
}

Write-Host ""
Write-Host "=== CP Perf Hub Capture ($Mode) ===" -ForegroundColor Cyan
Write-Host ("Log: {0}" -f $logPath) -ForegroundColor DarkGray

try {
    Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8080/v1/fulltext/control" `
        -Body '{"action":"stop"}' -ContentType "application/json" -TimeoutSec 5 | Out-Null
    Write-Host "  SearchCore stop requested" -ForegroundColor DarkGray
} catch {
    Write-Host "  WARN: SearchCore stop skipped" -ForegroundColor DarkYellow
}

if (-not $SkipReload) {
    if (-not (Invoke-HubInjectPing)) {
        Write-Host "  Hub inject inactive — reloading AHK..." -ForegroundColor Yellow
        Invoke-NiumaReload
        if (-not (Invoke-HubInjectPing 50)) {
            throw "Hub inject still inactive after reload. Ensure nmer-hub is running and wait ~50s after 牛马.ahk start."
        }
    }
    Write-Host "  Hub inject PING_OK" -ForegroundColor Green
}

if ($ClearLog -and (Test-Path $logPath)) {
    Remove-Item $logPath -Force
    Write-Host "Log cleared." -ForegroundColor DarkGray
}

Write-Host "  Running cp_perf_capture..." -ForegroundColor Cyan
$res = Invoke-HubCpPerfCapture -TimeoutSec $TimeoutSec -Mode $Mode
if (-not $res -or $res.code -ne "CAPTURE_OK") {
    $code = if ($res) { $res.code } else { "TIMEOUT" }
    $detail = if ($res) { $res.detail } else { "no inject result" }
    throw "CP perf capture failed: $code ($detail)"
}
Write-Host ("  {0}: {1}" -f $res.code, $res.detail) -ForegroundColor Green

$lines = 0
if (Test-Path $logPath) { $lines = (Get-Content $logPath -Encoding UTF8 | Where-Object { $_.Trim() }).Count }
Write-Host ("Captured {0} ndjson rows" -f $lines) -ForegroundColor $(if ($lines -ge 10) { "Green" } else { "Yellow" })

if ($SkipGate) { exit 0 }

& (Join-Path $here "Test-CpPerfPipeline.ps1")
if ($LASTEXITCODE -ne 0) {
    Write-Host "Pipeline check failed." -ForegroundColor Yellow
}

$gateArgs = @{ Strict = $true; ExpectDiscreteLayout = $true }
if ($Mode -eq "manual_equivalent") {
    $gateArgs["SkipFirstPaintSamples"] = 2
}
& (Join-Path $here "Run-CommandPalettePerfGate.ps1") @gateArgs
$gatePath = Join-Path $repo "Cache\debug\command_palette_perf_gate.json"
if (Test-Path $gatePath) {
    try {
        $g = Get-Content $gatePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $g | Add-Member -NotePropertyName "captureMode" -NotePropertyValue $Mode -Force
        $g | Add-Member -NotePropertyName "captureSource" -NotePropertyValue "Invoke-CpPerfCapture.ps1" -Force
        if ($Mode -eq "manual_equivalent") {
            $g | Add-Member -NotePropertyName "warmupDiscardPaint" -NotePropertyValue 2 -Force
        }
        if ($Mode -eq "synthetic_turbo" -and $g.pipelinePass -eq $true -and $g.performancePass -eq $false) {
            $g.failReason = "synthetic_turbo_performance_fail"
            $g | Add-Member -NotePropertyName "syntheticTurboNote" -NotePropertyValue "SearchCore HTTP turbo path; Stage1 only." -Force
        }
        $g | ConvertTo-Json -Depth 8 | Set-Content $gatePath -Encoding UTF8
    } catch { }
}
exit $LASTEXITCODE
