# Hybrid hub chain: health -> register_external -> inject -> drain -> egress round-trip
param(
    [string]$RepoRoot = "",
    [string]$OutPath = ""
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
if (-not $OutPath) { $OutPath = Join-Path $debugDir "hybrid_hub_chain_smoke.json" }

$addr = $env:NMER_A2UI_BRIDGE_ADDR
if (-not $addr) { $addr = "127.0.0.1:18791" }
$base = "http://$addr"
$probeId = "hybrid-signoff-" + (Get-Date -Format "HHmmss")

$report = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    base       = $base
    probeId    = $probeId
    gates      = @()
    overallPass = $false
}

function Add-Gate([string]$id, [bool]$pass, [string]$detail) {
    $script:report.gates += [ordered]@{ id = $id; pass = $pass; detail = $detail }
}

# G1 health
try {
    $h = Invoke-RestMethod -Uri "$base/agent/health" -TimeoutSec 5
    $ok = ($h.ok -eq $true) -or ($h.status -eq "ok")
    Add-Gate "health" $ok "ok=$($h.ok) provider=$($h.provider)"
} catch {
    Add-Gate "health" $false $_.Exception.Message
}

# G2 register_external (hybrid presentation)
try {
    $body = @{ action = "register_external"; entry = $probeId } | ConvertTo-Json -Compress
    $st = Invoke-RestMethod -Method Post -Uri "$base/shell/ftb" -Body $body -ContentType "application/json; charset=utf-8" -TimeoutSec 10
    $snap = $st.status
    if (-not $snap) { $snap = $st }
    $mode = [string]$snap.presentationMode
    $pass = ($mode -eq "external")
    Add-Gate "register_external" $pass "presentationMode=$mode visible=$($snap.visible)"
} catch {
    Add-Gate "register_external" $false $_.Exception.Message
}

# G3 inject -> drain (AHK pump may consume queue before HTTP drain returns)
try {
    $resultPath = Join-Path $debugDir "hybrid_signoff_inject_result.json"
    if (Test-Path $resultPath) { Remove-Item $resultPath -Force -ErrorAction SilentlyContinue }
    $injectBody = (@{
        type    = "hybrid_signoff_ping"
        probeId = $probeId
        ts      = (Get-Date).ToUniversalTime().ToString("o")
    } | ConvertTo-Json -Compress)
    $inj = Invoke-RestMethod -Method Post -Uri "$base/shell/ftb/inject" -Body $injectBody -ContentType "application/json; charset=utf-8" -TimeoutSec 10
    $injectOk = ($inj.ok -eq $true)
    Start-Sleep -Milliseconds 400
    $drain = Invoke-RestMethod -Uri "$base/shell/ftb/inject/drain" -TimeoutSec 10
    $cnt = [int]$drain.count
    $pingOk = $false
    $deadline = (Get-Date).AddSeconds(8)
    while ((Get-Date) -lt $deadline -and -not $pingOk) {
        if (Test-Path $resultPath) {
            try {
                $res = Get-Content $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($res.probeId -eq $probeId -and $res.code -eq "PING_OK") { $pingOk = $true; break }
            } catch {}
        }
        Start-Sleep -Milliseconds 300
    }
    # drainCount=0 is normal when AHK pump already consumed the hub queue
    $pass = $injectOk -and (($cnt -ge 1) -or $pingOk)
    if ($injectOk -and $cnt -eq 0 -and $pingOk) {
        $detail = "inject=$($inj.code) drainCount=$cnt pumpConsumed=1 code=PING_OK"
    } elseif ($injectOk -and $cnt -ge 1) {
        $detail = "inject=$($inj.code) drainCount=$cnt"
    } else {
        $detail = "inject=$($inj.code) drainCount=$cnt pingOk=$pingOk"
    }
    Add-Gate "inject_drain" $pass $detail
} catch {
    Add-Gate "inject_drain" $false $_.Exception.Message
}

# G4 egress round-trip
try {
    $egBody = (@{ type = "hybrid_signoff_egress"; probeId = $probeId } | ConvertTo-Json -Compress)
    $egPost = Invoke-RestMethod -Method Post -Uri "$base/shell/ftb/egress" -Body $egBody -ContentType "application/json; charset=utf-8" -TimeoutSec 10
    Start-Sleep -Milliseconds 150
    $egGet = Invoke-RestMethod -Uri "$base/shell/ftb/egress" -TimeoutSec 10
    $egCnt = [int]$egGet.count
    $pass = ($egPost.ok -eq $true) -and ($egCnt -ge 1)
    Add-Gate "egress_roundtrip" $pass "post=$($egPost.code) drainCount=$egCnt"
} catch {
    Add-Gate "egress_roundtrip" $false $_.Exception.Message
}

$report.overallPass = -not @($report.gates | Where-Object { -not $_.pass }).Count
$report | ConvertTo-Json -Depth 6 | Set-Content -Path $OutPath -Encoding UTF8
Write-Host "hybrid_hub_chain_smoke -> $OutPath overallPass=$($report.overallPass)"
foreach ($g in $report.gates) {
    $mark = if ($g.pass) { "PASS" } else { "FAIL" }
    Write-Host "  [$mark] $($g.id): $($g.detail)"
}
if (-not $report.overallPass) { exit 1 }
exit 0
