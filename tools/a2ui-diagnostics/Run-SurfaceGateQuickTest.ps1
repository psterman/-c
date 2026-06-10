# Surface gate quick retest: capture EMPTY baseline first, then 5 manual steps, then dashboard
param(
    [switch]$SkipBaseline,
    [switch]$SkipPrompt
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = (Resolve-Path (Join-Path $here "..\..")).Path
$baselinePath = Join-Path $repo "Cache\debug\a2ui_memory_baseline.json"

function Get-GatePass($obj, [string]$stage) {
    $prop = "${stage}_gate_pass"
    if ($null -eq $obj) { return $false }
    if ($obj.PSObject.Properties.Name -contains $prop) {
        return [bool]($obj.$prop)
    }
    return $false
}

function Test-BaselineLooksEmpty($path) {
    if (-not (Test-Path $path)) { return $false }
    try {
        $b = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        $kind = ""
        if ($b.PSObject.Properties.Name -contains "snapshotKind") {
            $kind = [string]$b.snapshotKind
        }
        if ($kind -eq "cp_loaded") { return $false }
        if ($b.PSObject.Properties.Name -contains "cpLoadedPrivateMiB") {
            $cpLoaded = $b.cpLoadedPrivateMiB
            if ($null -ne $cpLoaded -and [double]$cpLoaded -gt 0) { return $false }
        }
        if ($kind -eq "empty") { return $true }
        $wv2 = $null
        if ($b.processes -and $null -ne $b.processes.webview2_count) {
            $wv2 = [int]$b.processes.webview2_count
        }
        if ($null -ne $wv2 -and $wv2 -ge 8) { return $false }
        return $true
    } catch {
        return $false
    }
}

Write-Host ""
Write-Host "=== Surface gate quick retest ===" -ForegroundColor Cyan
Write-Host ""

if (-not $SkipBaseline) {
    Write-Host "STEP 0 (before any panel): empty-load memory baseline" -ForegroundColor Yellow
    Write-Host "  - Fully reload niuma first" -ForegroundColor Yellow
    Write-Host "  - Close CP / search / FTB, wait 3s" -ForegroundColor Yellow
    Write-Host "  - Then press Enter here to capture baseline" -ForegroundColor Yellow
    Write-Host ""
    if (-not $SkipPrompt) {
        Read-Host "Ready for empty baseline? Press Enter"
    }
    & (Join-Path $here "capture-memory-baseline.ps1")
    if (Test-BaselineLooksEmpty $baselinePath) {
        $b = Get-Content $baselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $wv2 = [int]$b.processes.webview2_count
        $mib = [double]$b.emptyLoadPrivateMiB
        Write-Host ("  baseline OK: webview2_count={0} emptyLoadPrivateMiB={1}" -f $wv2, $mib) -ForegroundColor Green
    } else {
        Write-Host "  baseline FAIL: snapshotKind=cp_loaded. Close all panels and retry STEP 0." -ForegroundColor Red
        Write-Host "  Do NOT continue to step 1-5 until baseline is empty." -ForegroundColor Red
        return
    }
    Write-Host ""
} else {
    if (-not (Test-BaselineLooksEmpty $baselinePath)) {
        Write-Host "[warn] existing baseline looks CP-loaded; S4 will fail. Omit -SkipBaseline and recapture." -ForegroundColor Red
        Write-Host ""
    }
}

Write-Host "STEP 1-5 (same niuma session, do NOT recapture baseline after):" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Double-tap CapsLock     -> open CP (S2 open + S3 txn)"
Write-Host "  2. Esc                     -> close CP (S2 close)"
Write-Host "  3. Double-tap CapsLock"
Write-Host "     type >dispose ftb Enter -> dispose FTB (S2 dispose + S4 ABSENT)"
Write-Host "  4. Double-tap CapsLock     -> open CP, keep open"
Write-Host "  5. Hold CapsLock + F       -> open search (S5 + S6)"
Write-Host ""
Write-Host "[warn] Do not run capture-memory-baseline.ps1 after step 1-5" -ForegroundColor DarkGray
Write-Host ""

if (-not $SkipPrompt) {
    Write-Host ""
    Write-Host "[IMPORTANT] Steps 1-5 must run in the SAME niuma session BEFORE you press Enter here." -ForegroundColor Magenta
    Write-Host "  Reload-only + dashboard = startup FTB logs only; S2-S6 will FAIL." -ForegroundColor Magenta
    Write-Host ""
    Read-Host "Press Enter after steps 1-5 to build dashboard"
}

Write-Host ""
Write-Host "Building dashboard..." -ForegroundColor Cyan
& (Join-Path $here "Open-SurfaceGateDashboard.ps1")

$jsonPath = Join-Path $repo "Cache\debug\surface_runtime_diagnosis.json"
if (-not (Test-Path $jsonPath)) { return }

$j = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

$s7Pass = $false
$s8Pass = $false
$s9Pass = $false
$s10Pass = $false
$ftb1Json = Join-Path $repo "Cache\debug\ftb1_gate_diagnosis.json"
$s8Json = Join-Path $repo "Cache\debug\s8b3_gate_diagnosis.json"
$s9Json = Join-Path $repo "Cache\debug\s9domainc_gate_diagnosis.json"
$s10Json = Join-Path $repo "Cache\debug\s10ftb_gate_diagnosis.json"
if (Test-Path $ftb1Json) {
    $ftb1 = Get-Content $ftb1Json -Raw -Encoding UTF8 | ConvertFrom-Json
    $s7Pass = [bool]$ftb1.s7_gate_pass
}
if (Test-Path $s8Json) {
    $s8 = Get-Content $s8Json -Raw -Encoding UTF8 | ConvertFrom-Json
    $s8Pass = [bool]$s8.s8_gate_pass
}
if (Test-Path $s9Json) {
    $s9 = Get-Content $s9Json -Raw -Encoding UTF8 | ConvertFrom-Json
    $s9Pass = [bool]$s9.s9_gate_pass
}
if (Test-Path $s10Json) {
    $s10 = Get-Content $s10Json -Raw -Encoding UTF8 | ConvertFrom-Json
    $s10Pass = [bool]$s10.s10_gate_pass
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan

$checks = @(
    @{ label = "S2 Intent";      pass = (Get-GatePass $j "s2"); hint = "add Esc or >dispose ftb" },
    @{ label = "S3 Transaction"; pass = (Get-GatePass $j "s3"); hint = "double-tap CapsLock open CP" },
    @{ label = "S4 P1";          pass = (Get-GatePass $j "s4"); hint = "STEP 0 empty baseline BEFORE steps 1-5" },
    @{ label = "S5 Budget";      pass = (Get-GatePass $j "s5"); hint = "CP open, then CapsLock+F" },
    @{ label = "S6 Slots";       pass = (Get-GatePass $j "s6"); hint = "same as step 5" },
    @{ label = "S7 FTB-1";       pass = $s7Pass; hint = "static" },
    @{ label = "S8 B3 CP";       pass = $s8Pass; hint = "static" },
    @{ label = "S9 Domain C";    pass = $s9Pass; hint = "static" },
    @{ label = "S10 FTB Shell";  pass = $s10Pass; hint = "static" }
)

$failed = @()
foreach ($c in $checks) {
    $mark = if ($c.pass) { "PASS" } else { "FAIL" }
    $color = if ($c.pass) { "Green" } else { "Red" }
    Write-Host ("  {0,-16} {1}" -f $c.label, $mark) -ForegroundColor $color
    if (-not $c.pass) { $failed += $c }
}

$session = if ($j.traceSession) { [string]$j.traceSession } else { "?" }
Write-Host ("  session: {0}" -f $session) -ForegroundColor DarkGray

if ($failed.Count -eq 0) {
    Write-Host ""
    Write-Host "All gates passed." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Still missing:" -ForegroundColor Yellow
    foreach ($c in $failed) {
        Write-Host ("  - {0}: {1}" -f $c.label, $c.hint)
    }
}
