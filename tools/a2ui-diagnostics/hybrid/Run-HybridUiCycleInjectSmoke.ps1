# UI cycle via hub inject -> AHK SurfaceIntent (no file IPC)
param(
    [string]$RepoRoot = "",
    [int]$Rounds = 10,
    [int]$PauseMs = 450,
    [int]$TimeoutSec = 180,
    [string]$OutPath = ""
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $RepoRoot = Get-DiagRepoRoot -From $PSScriptRoot
}
$debugDir = Join-Path $RepoRoot "Cache\debug"
if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
if (-not $OutPath) { $OutPath = Join-Path $debugDir "hybrid_ui_cycle_inject_smoke.json" }
$resultPath = Join-Path $debugDir "hybrid_signoff_inject_result.json"
$rtPath = Join-Path $debugDir "surface_runtime.ndjson"

$addr = $env:NMER_A2UI_BRIDGE_ADDR
if (-not $addr) { $addr = "127.0.0.1:18791" }
$base = "http://$addr"
$probeId = "ui-cycle-" + (Get-Date -Format "HHmmss")

function Get-IntentOpenCount([string]$path, [string]$surface, [int]$afterLine) {
    if (-not (Test-Path $path)) { return 0 }
    $n = 0
    $i = 0
    foreach ($line in (Get-Content $path -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        $i++
        if ($i -le $afterLine) { continue }
        if ($line -match '"type"\s*:\s*"intent_open"' -and $line -match "`"$surface`"") { $n++ }
    }
    return $n
}

function Invoke-HubWake {
    try {
        $reg = @{ action = "register_external"; entry = "hybrid-ui-cycle-smoke" } | ConvertTo-Json -Compress
        Invoke-RestMethod -Method Post -Uri "$base/shell/ftb" -Body $reg -ContentType "application/json; charset=utf-8" -TimeoutSec 8 | Out-Null
        $poke = @{ type = "hybrid_probe_wake"; probeId = "wake-$probeId" } | ConvertTo-Json -Compress
        Invoke-RestMethod -Method Post -Uri "$base/shell/ftb/inject" -Body $poke -ContentType "application/json; charset=utf-8" -TimeoutSec 8 | Out-Null
        Start-Sleep -Milliseconds 600
    } catch {}
}

$lineBefore = 0
if (Test-Path $rtPath) { $lineBefore = @(Get-Content $rtPath -Encoding UTF8).Count }

if (Test-Path $resultPath) { Remove-Item $resultPath -Force -ErrorAction SilentlyContinue }

Invoke-HubWake

Write-Host "  preflight: inject ping (needs AHK signoff drain timer)..." -ForegroundColor DarkGray
try {
    & (Join-Path $PSScriptRoot "Invoke-HybridInjectPing.ps1") -RepoRoot $RepoRoot -TimeoutSec 25 | Out-Null
    Write-Host "  inject ping OK" -ForegroundColor Green
} catch {
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    $fail = [ordered]@{
        capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        mode       = "hub_inject_ui_cycle"
        probeId    = $probeId
        pass       = $false
        resultCode = "PING_PREFLIGHT_FAIL"
        detail     = $_.Exception.Message
    }
    $fail | ConvertTo-Json | Set-Content -Path $OutPath -Encoding UTF8
    exit 1
}

if (Test-Path $resultPath) { Remove-Item $resultPath -Force -ErrorAction SilentlyContinue }

$injectOk = $false
$injectCode = ""
try {
    $payload = @{
        type    = "hybrid_signoff_ui_cycle"
        probeId = $probeId
        rounds  = $Rounds
        pauseMs = $PauseMs
    } | ConvertTo-Json -Compress
    $inj = Invoke-RestMethod -Method Post -Uri "$base/shell/ftb/inject" -Body $payload -ContentType "application/json; charset=utf-8" -TimeoutSec 15
    $injectOk = ($inj.ok -eq $true)
    $injectCode = [string]$inj.code
} catch {
    $injectCode = $_.Exception.Message
}

$deadline = (Get-Date).AddSeconds($TimeoutSec)
$res = $null
$dots = 0
while ((Get-Date) -lt $deadline) {
    if (Test-Path $resultPath) {
        try {
            $res = Get-Content $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($res.probeId -eq $probeId) {
                if ($res.code -eq "UI_CYCLE_PENDING") {
                    if (($dots % 10) -eq 0) { Write-Host "  ui_cycle running... ($($res.detail))" -ForegroundColor DarkGray }
                } else { break }
            }
        } catch {}
    } elseif (($dots % 8) -eq 0) {
        Write-Host "  waiting inject drain (ftb ready may be false; signoff bypasses wv2)..." -ForegroundColor DarkGray
    }
    $dots++
    Start-Sleep -Milliseconds 500
}

Start-Sleep -Seconds 2
$cpOpens = Get-IntentOpenCount $rtPath "command_palette" $lineBefore
$scOpens = Get-IntentOpenCount $rtPath "search_center" $lineBefore
$scNeed = [math]::Max(3, $Rounds - 3)

$injectPass = $false
$resCode = "no_result"
if ($res) {
    $injectPass = ($res.pass -eq $true)
    $resCode = [string]$res.code
}
$intentPass = ($cpOpens -ge $Rounds) -and ($scOpens -ge $scNeed)
$pass = $injectOk -and ($injectPass -or $intentPass)

$report = [ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    mode       = "hub_inject_ui_cycle"
    probeId    = $probeId
    rounds     = $Rounds
    injectOk   = $injectOk
    injectCode = $injectCode
    resultCode = $resCode
    cpOpens    = $cpOpens
    scOpens    = $scOpens
    pass       = $pass
}
$report | ConvertTo-Json -Depth 6 | Set-Content -Path $OutPath -Encoding UTF8
Write-Host "hybrid_ui_cycle_inject -> $OutPath pass=$pass inject=$injectOk code=$resCode cp=$cpOpens sc=$scOpens"
if (-not $pass) { exit 1 }
exit 0
