# Hybrid FTB UX smoke: external presentation + inject refresh + window health
param(
    [string]$RepoRoot = "",
    [string]$OutPath = ""
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
if (-not $OutPath) { $OutPath = Join-Path $debugDir "hybrid_ftb_ux_smoke.json" }

$addr = $env:NMER_A2UI_BRIDGE_ADDR
if (-not $addr) { $addr = "127.0.0.1:18791" }
$base = "http://$addr"
$probeId = "hybrid-ftb-ux-" + (Get-Date -Format "HHmmss")

$report = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    probeId    = $probeId
    gates      = @()
    pass       = $false
}

function Add-Gate([string]$id, [bool]$pass, [string]$detail) {
    $script:report.gates += [ordered]@{ id = $id; pass = $pass; detail = $detail }
}

function Test-LogPattern([string[]]$paths, [string]$pattern) {
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        try {
            $tail = Get-Content $p -Tail 120 -Encoding UTF8 -ErrorAction SilentlyContinue
            foreach ($line in $tail) {
                if ($line -match $pattern) { return $true }
            }
        } catch {}
    }
    return $false
}

# G1 status external
try {
    $st = Invoke-RestMethod "$base/shell/ftb/status" -TimeoutSec 6
    $snap = if ($st.status) { $st.status } else { $st }
    $mode = [string]$snap.presentationMode
    $pass = ($mode -eq "external")
    Add-Gate "ftb_external" $pass "mode=$mode visible=$($snap.visible) ready=$($snap.ready)"
} catch {
    Add-Gate "ftb_external" $false $_.Exception.Message
}

# G2 register_external
try {
    $body = @{ action = "register_external"; entry = $probeId } | ConvertTo-Json -Compress
    $reg = Invoke-RestMethod -Method Post -Uri "$base/shell/ftb" -Body $body -ContentType "application/json; charset=utf-8" -TimeoutSec 10
    $snap = if ($reg.status) { $reg.status } else { $reg }
    $pass = ([string]$snap.presentationMode -eq "external")
    Add-Gate "register_external" $pass "visible=$($snap.visible)"
} catch {
    Add-Gate "register_external" $false $_.Exception.Message
}

# G3 inject refresh rounds
$injectOk = 0
$injectFail = 0
for ($i = 1; $i -le 5; $i++) {
    try {
        $payload = (@{
            type    = "hybrid_ftb_ux_probe"
            probeId = $probeId
            round   = $i
            ts      = (Get-Date).ToUniversalTime().ToString("o")
        } | ConvertTo-Json -Compress)
        $inj = Invoke-RestMethod -Method Post -Uri "$base/shell/ftb/inject" -Body $payload -ContentType "application/json; charset=utf-8" -TimeoutSec 10
        Start-Sleep -Milliseconds 250
        $drain = Invoke-RestMethod "$base/shell/ftb/inject/drain" -TimeoutSec 10
        if (($inj.ok -eq $true) -and ([int]$drain.count -ge 1)) { $injectOk++ } else { $injectFail++ }
    } catch {
        $injectFail++
    }
}
Add-Gate "inject_refresh" ($injectOk -ge 5 -and $injectFail -eq 0) "ok=$injectOk fail=$injectFail"

# G4 egress
try {
    $egBody = (@{ type = "hybrid_ftb_ux_egress"; probeId = $probeId } | ConvertTo-Json -Compress)
    $egPost = Invoke-RestMethod -Method Post -Uri "$base/shell/ftb/egress" -Body $egBody -ContentType "application/json; charset=utf-8" -TimeoutSec 10
    Start-Sleep -Milliseconds 150
    $egGet = Invoke-RestMethod "$base/shell/ftb/egress" -TimeoutSec 10
    $pass = ($egPost.ok -eq $true) -and ([int]$egGet.count -ge 1)
    Add-Gate "egress_roundtrip" $pass "post=$($egPost.code) count=$($egGet.count)"
} catch {
    Add-Gate "egress_roundtrip" $false $_.Exception.Message
}

# G5 no recent inject failures in logs
$logPaths = @(
    (Join-Path $debugDir "wails_bridge.log"),
    (Join-Path $debugDir "hubcapsule_runtime.log")
)
$badLog = Test-LogPattern $logPaths "hybrid_inject_fail|deliver_inject_fail"
Add-Gate "no_inject_fail_log" (-not $badLog) "scanned=wails_bridge,hubcapsule"

# G6 AHK alive
$ahk = Get-Process -Name "AutoHotkey64","AutoHotkey32" -ErrorAction SilentlyContinue | Where-Object {
    try {
        $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
        return ($cmd -like "*$RepoRoot*" -or $cmd -like "*牛马.ahk*")
    } catch { return $false }
} | Select-Object -First 1
$ahkDetail = if ($ahk) { "pid=$($ahk.Id)" } else { "niuma.ahk not found" }
Add-Gate "ahk_running" ([bool]$ahk) $ahkDetail

$report.pass = -not @($report.gates | Where-Object { -not $_.pass }).Count
$report | ConvertTo-Json -Depth 6 | Set-Content -Path $OutPath -Encoding UTF8
Write-Host "hybrid_ftb_ux_smoke -> $OutPath pass=$($report.pass)"
foreach ($g in $report.gates) {
    $mark = if ($g.pass) { "PASS" } else { "FAIL" }
    Write-Host "  [$mark] $($g.id): $($g.detail)"
}
if (-not $report.pass) { exit 1 }
exit 0
