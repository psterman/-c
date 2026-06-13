# A2UI R1/R2 回退演练 — architecture v2 SS5.4 (hybrid hub aware)
param(
    [string]$RepoRoot = "",
    [ValidateSet("R1", "R2", "ALL")]
    [string]$Drill = "ALL",
    [switch]$SkipFixtures
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
if (-not $RepoRoot) { $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot }

$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }

$results = @{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    drills     = @()
    pass       = $true
}

function Add-DrillResult($id, $ok, $detail) {
    $script:results.drills += @{ id = $id; ok = $ok; detail = $detail }
    if (-not $ok) { $script:results.pass = $false }
    $flag = if ($ok) { "PASS" } else { "FAIL" }
    Write-Host "$flag $id — $detail"
}

function Run-FixturesCheck {
    if ($SkipFixtures) {
        Add-DrillResult "fixtures" $true "skipped"
        return
    }
    Push-Location $RepoRoot
    try {
        $out = node html/run-palette-fixtures.mjs 2>&1 | Out-String
        $ok = $out -match "ok=true" -and $out -notmatch "failed=[1-9]"
        Add-DrillResult "fixtures" $ok $(if ($ok) { "all green" } else { "fixtures regression" })
    } finally {
        Pop-Location
    }
}

function Invoke-GraySnapshot {
    $snapScript = Join-Path $PSScriptRoot "capture-gray-flags-snapshot.ps1"
    if (-not (Test-Path $snapScript)) {
        Add-DrillResult "gray_snapshot" $false "missing capture-gray-flags-snapshot.ps1"
        return $null
    }
    & $snapScript -RepoRoot $RepoRoot | Out-Null
    $path = Join-Path $debugDir "gray_flags_baseline.json"
    if (-not (Test-Path $path)) {
        Add-DrillResult "gray_snapshot" $false "no gray_flags_baseline.json"
        return $null
    }
    return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-A2uiSidecarKind([string]$Root) {
    $kind = "wails"
    $flagsPath = Join-Path $Root "local\nmer-flags.json"
    if (Test-Path $flagsPath) {
        try {
            $f = Get-Content $flagsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($f.wailsBridge -and $f.wailsBridge.sidecarHost) {
                $k = [string]$f.wailsBridge.sidecarHost
                if ($k -eq "hub") { $kind = "hub" }
            }
        } catch { }
    }
    if (Get-Process -Name "nmer-hub" -ErrorAction SilentlyContinue) { return "hub" }
    return $kind
}

function Test-A2uiBridgeHealth {
    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:18791/agent/health" -UseBasicParsing -TimeoutSec 2 | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Run-R1Drill {
    $sidecarKind = Get-A2uiSidecarKind $RepoRoot
    $stopNames = if ($sidecarKind -eq "hub") { @("nmer-hub") } else { @("nmer-wails") }
    Write-Host "=== R1: stop sidecar ($sidecarKind -> $($stopNames -join ',')) ==="
    $wasRunning = $false
    foreach ($name in $stopNames) {
        if (Get-Process -Name $name -ErrorAction SilentlyContinue) {
            $wasRunning = $true
            Stop-Process -Name $name -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep -Seconds 2
    $still = @($stopNames | Where-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue })
    Add-DrillResult "R1_sidecar_stopped" ($still.Count -eq 0) $(if ($still.Count) { "still running: $($still -join ',')" } else { "sidecar stopped ($sidecarKind)" })

    $healthOk = Test-A2uiBridgeHealth
    Add-DrillResult "R1_health_down" (-not $healthOk) $(if ($healthOk) { "health still 200 on :18791" } else { "health unreachable (expected)" })

    Run-FixturesCheck

    if ($wasRunning) {
        $restarted = $false
        if ($sidecarKind -eq "hub") {
            $restarted = Ensure-DiagNmerHub -RepoRoot $RepoRoot -WarmupSec 3
            if ($restarted) { Start-Sleep -Seconds 1; $restarted = Test-A2uiBridgeHealth }
            Add-DrillResult "R1_sidecar_restarted" $restarted $(if ($restarted) { "nmer-hub up, health ok" } else { "nmer-hub restart failed" })
        } else {
            $exe = @(
                (Join-Path $RepoRoot "apps\nmer-wails\build\bin\nmer-wails.exe"),
                (Join-Path $RepoRoot "tools\wails\nmer-wails.exe")
            ) | Where-Object { Test-Path $_ } | Select-Object -First 1
            if ($exe) {
                Start-Process -FilePath $exe -WorkingDirectory $RepoRoot -WindowStyle Hidden
                Start-Sleep -Seconds 2
                $restarted = Test-A2uiBridgeHealth
                Add-DrillResult "R1_sidecar_restarted" $restarted "started $($exe.Name)"
            } else {
                Add-DrillResult "R1_sidecar_restarted" $false "nmer-wails.exe not found"
            }
        }
    }
}

function Run-R2Drill {
    Write-Host "=== R2: forceNmerOnly=true ==="
    $flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"
    $backupPath = Join-Path $debugDir "nmer-flags.rollback-drill.bak"
    $hadFile = Test-Path $flagsPath
    if ($hadFile) { Copy-Item $flagsPath $backupPath -Force }
    $forceFlags = @{
        wailsBridge  = @{ enabled = $true }
        officialA2ui = @{ enabled = $true; commandWhitelist = @("/search") }
        rollback     = @{ forceNmerOnly = $true }
    }
    $localDir = Join-Path $RepoRoot "local"
    if (-not (Test-Path $localDir)) { New-Item -ItemType Directory -Path $localDir -Force | Out-Null }
    $forceFlags | ConvertTo-Json -Depth 5 | Set-Content -Path $flagsPath -Encoding UTF8

    $snap = Invoke-GraySnapshot
    if ($snap) {
        Add-DrillResult "R2_route_mode" (($snap.routeMode -eq "force_nmer_only")) "routeMode=$($snap.routeMode)"
        Add-DrillResult "R2_force_flag" ($snap.rollback.forceNmerOnly -eq $true) "forceNmerOnly=$($snap.rollback.forceNmerOnly)"
    }

    Run-FixturesCheck

    if ($hadFile) {
        Copy-Item $backupPath $flagsPath -Force
        Remove-Item $backupPath -Force -ErrorAction SilentlyContinue
        Add-DrillResult "R2_flags_restored" $true "restored backup"
    } else {
        Remove-Item $flagsPath -Force -ErrorAction SilentlyContinue
        Add-DrillResult "R2_flags_restored" $true "removed drill flags file"
    }
    Invoke-GraySnapshot | Out-Null
}

switch ($Drill) {
    "R1" { Run-R1Drill }
    "R2" { Run-R2Drill }
    "ALL" { Run-R1Drill; Run-R2Drill }
}

$outPath = Join-Path $debugDir "rollback_drill_last.json"
$results | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "rollback_drill_last -> $outPath pass=$($results.pass)"
exit $(if ($results.pass) { 0 } else { 1 })
