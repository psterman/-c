# Wave 2 灰度基线：灰度烟测 + 回退演练 + ADP L1/L2 + Go 单测 + 快照
param(
    [string]$RepoRoot = "",
    [switch]$SkipAdpIntegration
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }

function Test-SidecarHealth {
    param([string]$Base = "http://127.0.0.1:18791")
    try {
        $r = Invoke-WebRequest -Uri "$Base/agent/health" -UseBasicParsing -TimeoutSec 2
        return ($r.StatusCode -eq 200)
    } catch {
        return $false
    }
}

function Ensure-SidecarHealth {
    param([int]$WaitSec = 20)
    if (Test-SidecarHealth) { return $true }
    $exe = @(
        (Join-Path $RepoRoot "apps\nmer-wails\build\bin\nmer-wails.exe"),
        (Join-Path $RepoRoot "tools\wails\nmer-wails.exe")
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($exe) {
        Write-Host "sidecar not healthy — starting $($exe.Name)"
        Start-Process -FilePath $exe -WorkingDirectory $RepoRoot -WindowStyle Hidden
    }
    for ($i = 0; $i -lt $WaitSec; $i++) {
        if (Test-SidecarHealth) { return $true }
        Start-Sleep -Seconds 1
    }
    return $false
}

Push-Location $RepoRoot
try {
    Write-Host "=== gray smoke ==="
    $smOut = node html/run-gray-a2ui-smoke.mjs 2>&1 | Out-String
    Write-Host $smOut
    $smOk = $smOut -match "ok=true"

    Write-Host "=== rollback drill ==="
    & (Join-Path $RepoRoot "scripts\Run-A2uiRollbackDrill.ps1") -RepoRoot $RepoRoot
    $rbOk = $LASTEXITCODE -eq 0
    $rbPath = Join-Path $debugDir "rollback_drill_last.json"
    if ($rbOk -and (Test-Path $rbPath)) {
        try {
            $rbJson = Get-Content $rbPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($rbJson.pass -ne $true) { $rbOk = $false }
        } catch {
            $rbOk = $false
        }
    }

    Write-Host "=== ensure sidecar (post rollback drill) ==="
    $sidecarOk = Ensure-SidecarHealth
    if (-not $sidecarOk) { Write-Host "WARN sidecar still down — ADP L1 may fail" }

    Write-Host "=== adp integration ==="
    $adpOk = $true
    $adpSkipped = $false
    if (-not $SkipAdpIntegration) {
        if (-not $sidecarOk) {
            $adpSkipped = $true
            Write-Host "SKIP adp integration (sidecar unhealthy — 重载牛马.ahk 或 go build sidecar)"
        } else {
            & (Join-Path $RepoRoot "scripts\Run-AdpCpIntegration.ps1") -RepoRoot $RepoRoot -SkipAdapterPost
            $adpOk = $LASTEXITCODE -eq 0
        }
    } else {
        $adpSkipped = $true
        Write-Host "SKIP adp integration (-SkipAdpIntegration)"
    }

    Write-Host "=== go test (action policy) ==="
    Push-Location (Join-Path $RepoRoot "apps\nmer-wails")
    $goOut = go test ./poc/... -run "TestA2UIActionPolicy|TestA2UIValidator" 2>&1 | Out-String
    Pop-Location
    Write-Host $goOut
    $goOk = $LASTEXITCODE -eq 0

    Write-Host "=== gray flags snapshot ==="
    & (Join-Path $PSScriptRoot "capture-gray-flags-snapshot.ps1") -RepoRoot $RepoRoot -Context daily
    $grayExit = $LASTEXITCODE
} finally {
    Pop-Location
}

$summary = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    wave       = 2
    automation = [ordered]@{
        graySmoke      = @{ ok = $smOk }
        rollbackDrill  = @{ ok = $rbOk }
        adpIntegration = @{ ok = $adpOk; skipped = [bool]$adpSkipped; sidecarHealthy = $sidecarOk }
        goActionPolicy = @{ ok = $goOk }
        graySnapshot   = @{ ok = ($grayExit -eq 0) }
    }
    artifacts  = @(
        "Cache/debug/gray_flags_baseline.json",
        "Cache/debug/rollback_drill_last.json"
    )
    manualStillNeeded = @(
        "local/nmer-flags.json from docs/nmer-flags.example.json for r3_gray on dev machine",
        "Ctrl+Shift+G gray probe with flags enabled",
        "Ctrl+Shift+U ADP L3 after ingest demo JSONL"
    )
    wave2Pass = ($smOk -and $rbOk -and $goOk -and ($grayExit -eq 0) -and ($adpOk -or $adpSkipped))
}

$summaryPath = Join-Path $debugDir "wave2_gray_baseline_last.json"
$summary | ConvertTo-Json -Depth 6 | Set-Content -Path $summaryPath -Encoding UTF8
Write-Host "wave2 summary -> $summaryPath pass=$($summary.wave2Pass)"

if (-not $summary.wave2Pass) { exit 1 }
exit 0
