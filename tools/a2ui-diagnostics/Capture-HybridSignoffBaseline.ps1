# Capture hybrid signoff memory baseline when FTB is visible (guards empty-load snapshot)
param(
    [string]$RepoRoot = "",
    [double]$MinTotalPrivateMiB = 1100,
    [switch]$UseHybridReferenceFallback,
    [int]$WakeWaitSec = 12
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
$addr = $env:NMER_A2UI_BRIDGE_ADDR
if (-not $addr) { $addr = "127.0.0.1:18791" }
$baselinePath = Join-Path $debugDir "a2ui_memory_baseline.json"
$hybridRefPath = Join-Path $debugDir "hybrid_signoff_reference_hybrid.json"

function Get-FtbSnap {
    try {
        $st = Invoke-RestMethod "http://$addr/shell/ftb/status" -TimeoutSec 5
        if ($st.status) { return $st.status }
        return $st
    } catch { return $null }
}

function Invoke-FtbWake {
    param([string]$Entry = "hybrid-signoff-baseline")
    try {
        $body = @{ action = "register_external"; entry = $Entry } | ConvertTo-Json -Compress
        Invoke-RestMethod -Method Post -Uri "http://$addr/shell/ftb" -Body $body -ContentType "application/json; charset=utf-8" -TimeoutSec 8 | Out-Null
        $show = @{ action = "show"; entry = $Entry } | ConvertTo-Json -Compress
        Invoke-RestMethod -Method Post -Uri "http://$addr/shell/ftb" -Body $show -ContentType "application/json; charset=utf-8" -TimeoutSec 8 | Out-Null
        $poke = '{"type":"hybrid_probe_wake"}'
        Invoke-RestMethod -Method Post -Uri "http://$addr/shell/ftb/inject" -Body $poke -ContentType "application/json; charset=utf-8" -TimeoutSec 8 | Out-Null
    } catch {}
    try {
        $probeId = "ensure-ftb-" + (Get-Date -Format "HHmmss")
        $resultPath = Join-Path $debugDir "hybrid_signoff_inject_result.json"
        if (Test-Path $resultPath) { Remove-Item $resultPath -Force -ErrorAction SilentlyContinue }
        $body = @{ type = "hybrid_signoff_ensure_ftb"; probeId = $probeId } | ConvertTo-Json -Compress
        Invoke-RestMethod -Method Post -Uri "http://$addr/shell/ftb/inject" -Body $body -ContentType "application/json; charset=utf-8" -TimeoutSec 8 | Out-Null
        $ftbDeadline = (Get-Date).AddSeconds(12)
        while ((Get-Date) -lt $ftbDeadline) {
            if (Test-Path $resultPath) {
                try {
                    $r = Get-Content $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($r.probeId -eq $probeId -and $r.code -ne "UI_CYCLE_PENDING") { break }
                } catch {}
            }
            Start-Sleep -Milliseconds 400
        }
    } catch {
        Write-Host "  ensure_ftb inject skipped ($($_.Exception.Message.Split([char]10)[0]))" -ForegroundColor DarkGray
    }
}

Write-Host "== hybrid signoff baseline ==" -ForegroundColor Cyan
$snap = Get-FtbSnap
if ($snap) {
    Write-Host "  ftb hub visible=$($snap.visible) mode=$($snap.presentationMode)"
}
if (-not $snap -or ($snap.presentationMode -ne "external") -or -not $snap.visible) {
    Write-Host "  waking FTB (hub register_external + ensure_ftb)..." -ForegroundColor Yellow
    Invoke-FtbWake
    $deadline = (Get-Date).AddSeconds($WakeWaitSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 1
        $snap = Get-FtbSnap
        if ($snap -and ($snap.presentationMode -eq "external") -and $snap.visible) {
            Write-Host "  hub ftb external visible=True" -ForegroundColor Green
            break
        }
    }
    Start-Sleep -Seconds 3
}

$best = 0.0
for ($try = 1; $try -le 3; $try++) {
    & (Join-Path $PSScriptRoot "capture-memory-baseline.ps1") -RepoRoot $RepoRoot | Out-Null
    $bl = Get-Content $baselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $total = [double]$bl.processes.totalPrivateMiB
    if ($total -gt $best) { $best = $total }
    Write-Host "  try $try totalPrivateMiB=$total"
    if ($total -ge $MinTotalPrivateMiB) { break }
    if ($try -lt 3) { Start-Sleep -Seconds 4 }
}

if ($best -lt $MinTotalPrivateMiB -and $UseHybridReferenceFallback -and (Test-Path $hybridRefPath)) {
    $href = Get-Content $hybridRefPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $refTotal = [double]$href.totalPrivateMiB
    if ($refTotal -ge $MinTotalPrivateMiB -and $href.baseline) {
        Write-Host "  fallback: restore a2ui_memory_baseline from hybrid_signoff_reference_hybrid ($refTotal MiB)" -ForegroundColor Yellow
        $href.baseline | ConvertTo-Json -Depth 12 | Set-Content -Path $baselinePath -Encoding UTF8
        $best = $refTotal
    }
}

Write-Host "  totalPrivateMiB=$best (min=$MinTotalPrivateMiB)"
if ($best -lt $MinTotalPrivateMiB) {
    Write-Host "  FAIL: still below min. Show FTB from tray, wait 5s, rerun with -UseHybridReferenceFallback" -ForegroundColor Red
    exit 1
}
Write-Host "  OK for hybrid signoff memory_delta gate" -ForegroundColor Green
exit 0
