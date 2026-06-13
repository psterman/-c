# CP10 / S8 B3 Phase 2 signoff: aggregate static+fixtures+prior live reports + default flags.
param(
    [string]$RepoRoot = "",
    [switch]$WithFixtures,
    [switch]$JsonOnly
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RepoRoot) { $RepoRoot = Get-DiagRepoRoot -From $here }

$dbg = Join-Path $RepoRoot "Cache\debug"
$flagsPath = Join-Path $RepoRoot "local\nmer-flags.json"
$staticScript = Join-Path (Split-Path $here -Parent) "surface\Diagnose-S8B3Phase2Gate.ps1"
$fixturesScript = Join-Path $RepoRoot "html\run-palette-fixtures.mjs"
$outGate = Join-Path $dbg "s8b3_phase2_signoff.json"

function Read-Json([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try { return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

function Test-ReportPass([string]$path) {
    $j = Read-Json $path
    if (-not $j) { return @{ pass = $false; detail = "missing" } }
    $pass = $false
    if ($null -ne $j.overallPass) { $pass = [bool]$j.overallPass }
    elseif ($null -ne $j.s8b3_phase2_gate_pass) { $pass = [bool]$j.s8b3_phase2_gate_pass }
    return @{ pass = $pass; detail = $(if ($pass) { "pass" } else { "fail" }); capturedAt = $j.capturedAt; generatedAt = $j.generatedAt }
}

function Read-FlagsDefault {
    $cpHost = "?"
    $legacy = $null
    $sidecar = "?"
    if (Test-Path $flagsPath) {
        try {
            $f = Get-Content $flagsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($f.wailsBridge.commandPaletteHost) { $cpHost = [string]$f.wailsBridge.commandPaletteHost }
            if ($f.wailsBridge.sidecarHost) { $sidecar = [string]$f.wailsBridge.sidecarHost }
            if ($null -ne $f.rollback.legacySurfaceLifecycle) { $legacy = [bool]$f.rollback.legacySurfaceLifecycle }
        } catch { }
    }
    $pass = ($cpHost -eq "ahk") -and ($sidecar -eq "hub") -and ($legacy -eq $true)
    return @{ pass = $pass; host = $cpHost; sidecar = $sidecar; legacy = $legacy }
}

Write-Host ""
Write-Host "=== CP10 S8 B3 Phase 2 Signoff ===" -ForegroundColor Cyan
Write-Host ""

$checks = @()
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-Check([string]$id, [string]$name, [bool]$pass, $value, [string]$failReason = "") {
    $script:checks += [ordered]@{ id = $id; name = $name; pass = $pass; value = $value; report = $value.report }
    if (-not $pass -and $failReason) { [void]$script:failures.Add("$id`: $failReason") }
}

# P2-S static
$staticArgs = @{ RepoRoot = $RepoRoot; JsonOnly = $true }
if ($WithFixtures) { $staticArgs.WithFixtures = $true }
& $staticScript @staticArgs | Out-Null
$p2s = Test-ReportPass (Join-Path $dbg "s8b3_phase2_gate.json")
Add-Check "P2-S" "static_phase2_gate" $p2s.pass @{ detail = $p2s.detail; report = "s8b3_phase2_gate.json" } $(if ($p2s.pass) { "" } else { "static_fail" })

# P2-S7 fixtures (standalone if not -WithFixtures on static)
$fixturesPass = $null
$fixturesDetail = "skipped"
if ($WithFixtures) {
    $p2s7 = Read-Json (Join-Path $dbg "s8b3_phase2_gate.json")
    if ($p2s7 -and $p2s7.checks) {
        $fx = @($p2s7.checks | Where-Object { $_.id -eq "P2-S7" } | Select-Object -First 1)
        if ($fx) {
            $fixturesPass = [bool]$fx.pass
            $fixturesDetail = $fx.value
        }
    }
} else {
    if (Test-Path $fixturesScript) {
        Push-Location (Join-Path $RepoRoot "html")
        try {
            $fxOut = & node "run-palette-fixtures.mjs" 2>&1 | Out-String
            $fixturesPass = ($LASTEXITCODE -eq 0) -and ($fxOut -match "ok=true")
            if ($fxOut -match "passed=(\d+).*failed=(\d+)") {
                $fixturesDetail = "passed=$($Matches[1]) failed=$($Matches[2])"
                $fixturesPass = ($Matches[2] -eq "0")
            }
        } finally { Pop-Location }
    } else {
        $fixturesPass = $false
        $fixturesDetail = "missing"
    }
    Add-Check "P2-S7" "palette_fixtures" ([bool]$fixturesPass) $fixturesDetail $(if ($fixturesPass) { "" } else { "fixtures_fail" })
}

# Prior live reports
$liveReports = [ordered]@{
    cp7 = "cp7_wails_cp_shell_gate.json"
    cp8 = "cp8_wails_cp_memory_soak.json"
    cp9 = "cp9_wails_cp_hub_agent_live.json"
}
foreach ($key in $liveReports.Keys) {
    $file = $liveReports[$key]
    $path = Join-Path $dbg $file
    $r = Test-ReportPass $path
    $id = switch ($key) { "cp7" { "P2-L7" } "cp8" { "P2-L8" } "cp9" { "P2-L9" } }
    $name = switch ($key) { "cp7" { "cp7_shell_bridge_live" } "cp8" { "cp8_memory_soak" } "cp9" { "cp9_hub_agent_live" } }
    Add-Check $id $name $r.pass @{ file = $file; detail = $r.detail; capturedAt = $(if ($r.capturedAt) { $r.capturedAt } else { $r.generatedAt }) } $(if ($r.pass) { "" } else { "${key}_report_fail_or_stale" })
}

$flags = Read-FlagsDefault
Add-Check "P2-F1" "default_flags_ahk" $flags.pass $flags $(if ($flags.pass) { "" } else { "flags_not_default_ahk" })

[void]$warnings.Add("manual_signoff checklist not automated (CapsLock CP, FTB coexist, rollback UX)")

$overallPass = ($failures.Count -eq 0)
$automatedClose = $overallPass
$report = [ordered]@{
    capturedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    gate = "s8b3_phase2_signoff"
    title = "S8 B3 CP Phase 2 automated signoff"
    phase = 2
    overallPass = [bool]$overallPass
    automatedCloseReady = [bool]$automatedClose
    manualSignoffPending = $true
    failureReasons = @($failures)
    warnings = @($warnings)
    checks = $checks
    liveReports = $liveReports
    nextStep = if ($overallPass) {
        "Automated phase 2 criteria met — optional manual signoff then mark S8 phase 2 closed in docs"
    } else {
        "Re-run failed gates (CP7/8/9) or fixtures then Run-Cp10WailsCpPhase2Signoff.ps1"
    }
}
$report | ConvertTo-Json -Depth 10 | Set-Content -Path $outGate -Encoding UTF8

if ($JsonOnly) {
    $report | ConvertTo-Json -Depth 10
    exit $(if ($overallPass) { 0 } else { 1 })
}

foreach ($c in $checks) {
    $color = if ($c.pass) { "Green" } else { "Red" }
    Write-Host ("  {0} {1}: {2} -> {3}" -f $c.id, $c.name, ($c.value | ConvertTo-Json -Compress), $(if ($c.pass) { "PASS" } else { "FAIL" })) -ForegroundColor $color
}
if ($warnings.Count) {
    foreach ($w in $warnings) { Write-Host "  WARN: $w" -ForegroundColor Yellow }
}
Write-Host ""
Write-Host ("overall: {0}" -f $(if ($overallPass) { "PASS" } else { "FAIL" })) -ForegroundColor $(if ($overallPass) { "Green" } else { "Red" })
Write-Host "report: $outGate" -ForegroundColor DarkGray
exit $(if ($overallPass) { 0 } else { 1 })
