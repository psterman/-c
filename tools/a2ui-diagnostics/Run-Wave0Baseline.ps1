# Wave 0 一键基线：自动化测试 + 灰度快照 + 内存快照 + 汇总 JSON
param(
    [string]$RepoRoot = "",
    [ValidateSet("wave0", "daily")]
    [string]$FlagsContext = "wave0"
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }

Push-Location $RepoRoot
try {
    Write-Host "=== fixtures ==="
    $fxOut = node html/run-palette-fixtures.mjs 2>&1 | Out-String
    Write-Host $fxOut
    $fxOk = $fxOut -match "ok=true" -and $fxOut -notmatch "failed=[1-9]"
    $fxMatch = [regex]::Match($fxOut, "passed=(\d+)\s+failed=(\d+)")
    $fxPassed = if ($fxMatch.Success) { [int]$fxMatch.Groups[1].Value } else { 0 }
    $fxFailed = if ($fxMatch.Success) { [int]$fxMatch.Groups[2].Value } else { 1 }

    Write-Host "=== gray smoke ==="
    $smOut = node html/run-gray-a2ui-smoke.mjs 2>&1 | Out-String
    Write-Host $smOut
    $smOk = $smOut -match "ok=true"

    Write-Host "=== oc5 L1 ==="
    $ocOut = node html/run-oc5-verify.mjs 2>&1 | Out-String
    Write-Host $ocOut
    $ocOk = $ocOut -match "OC5_L1 ok=true"

    Write-Host "=== go test ==="
    Push-Location (Join-Path $RepoRoot "apps\nmer-wails")
    $goOut = go test ./poc/... 2>&1 | Out-String
    Pop-Location
    Write-Host $goOut
    $goOk = $LASTEXITCODE -eq 0

    Write-Host "=== gray flags snapshot ==="
    & (Join-Path $PSScriptRoot "capture-gray-flags-snapshot.ps1") -RepoRoot $RepoRoot -Context $FlagsContext
    $grayExit = $LASTEXITCODE

    Write-Host "=== memory baseline ==="
    $memoryArgs = @{ RepoRoot = $RepoRoot }
    if ($FlagsContext -eq "daily") { $memoryArgs["PreserveEmptyWhenCpLoaded"] = $true }
    & (Join-Path $PSScriptRoot "capture-memory-baseline.ps1") @memoryArgs
} finally {
    Pop-Location
}

$summary = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    wave       = 0
    flagsContext = $FlagsContext
    automation = [ordered]@{
        fixtures  = @{ ok = $fxOk; passed = $fxPassed; failed = $fxFailed }
        graySmoke = @{ ok = $smOk }
        oc5L1     = @{ ok = $ocOk }
        goPoc     = @{ ok = $goOk }
    }
    artifacts  = @(
        "Cache/debug/gray_flags_baseline.json",
        "Cache/debug/a2ui_memory_baseline.json"
    )
    manualStillNeeded = @(
        "Ctrl+Shift+O OC-5 L3 probe (reload niuma.ahk) -> Cache/debug/oc5_probe_last.json"
    )
    wave0Pass  = ($fxOk -and $smOk -and $ocOk -and $goOk -and ($grayExit -eq 0))
}

$summaryPath = Join-Path $debugDir "wave0_baseline_last.json"
$summary | ConvertTo-Json -Depth 6 | Set-Content -Path $summaryPath -Encoding UTF8
Write-Host "wave0 summary -> $summaryPath pass=$($summary.wave0Pass)"

if (-not $summary.wave0Pass) { exit 1 }
exit 0
