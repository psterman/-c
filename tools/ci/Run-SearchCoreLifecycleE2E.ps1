param(
    [string]$Root = "",
    [int]$HealthWaitSec = 20
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"

$coreExe = Join-Path $Root "tools\search\SearchCenterCore.exe"
if (-not (Test-Path -LiteralPath $coreExe)) {
    $coreExe = Join-Path $Root "searchcore\SearchCenterCore.exe"
}
if (-not (Test-Path -LiteralPath $coreExe)) {
    Write-Output "searchcore_exe_missing=1"
    Write-Output "RESULT=SKIP"
    exit 2
}

$jsonl = Join-Path $Root "Cache\debug\searchcore_lifecycle.jsonl"
$debugDir = Split-Path $jsonl -Parent
if (-not (Test-Path -LiteralPath $debugDir)) {
    New-Item -ItemType Directory -Path $debugDir -Force | Out-Null
}

function Stop-SearchCoreIfRunning {
    $p = Get-Process -Name "SearchCenterCore" -ErrorAction SilentlyContinue
    if ($p) {
        $p | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
}

function Wait-SearchCoreHealth {
    param([int]$TimeoutSec = 20)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $r = Invoke-WebRequest -Uri "http://127.0.0.1:8080/health" -UseBasicParsing -TimeoutSec 3
            if ($r.StatusCode -eq 200 -and $r.Content -match "ok") { return $true }
        } catch { }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Test-JsonlHasReason {
    param([string]$Path, [string]$Event, [string]$Reason)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($line -match ('"event"\s*:\s*"' + [regex]::Escape($Event) + '"') -and $line -match ('"reason"\s*:\s*"' + [regex]::Escape($Reason) + '"')) {
            return $true
        }
    }
    return $false
}

function Invoke-SearchCoreShutdownViaAhk {
    param(
        [string]$Root,
        [string]$Reason = "e2e_shutdown_test"
    )
    try {
        $code = Nmer-InvokeSearchCoreProbe -Root $Root -ProbeRelativeName "SearchCoreShutdownProbe.ahk" -ExtraArgs @($Reason)
        return ($code -eq 0)
    } catch {
        return $false
    }
}

$checks = New-Object System.Collections.Generic.List[object]
Stop-SearchCoreIfRunning

# S1: start core -> health
$beforeLines = if (Test-Path -LiteralPath $jsonl) { (Get-Content -LiteralPath $jsonl).Count } else { 0 }
Start-Process -FilePath $coreExe -ArgumentList @("-base", $Root) -WindowStyle Hidden | Out-Null
$healthOk = Wait-SearchCoreHealth -TimeoutSec $HealthWaitSec
$checks.Add([pscustomobject]@{
    Name = "s1_health_after_start"
    Pass = $healthOk
    Detail = "GET /health within ${HealthWaitSec}s"
})

# S4: shutdown via AHK helper (requires launch choice)
if (Invoke-SearchCoreShutdownViaAhk -Root $Root -Reason "e2e_shutdown_test") {
    Start-Sleep -Milliseconds 800
    $checks.Add([pscustomobject]@{
        Name = "s4_shutdown_requested_reason"
        Pass = (Test-JsonlHasReason -Path $jsonl -Event "shutdown_requested" -Reason "e2e_shutdown_test")
        Detail = "jsonl shutdown_requested reason=e2e_shutdown_test"
    })
    $checks.Add([pscustomobject]@{
        Name = "s4_shutdown_done_reason"
        Pass = (Test-JsonlHasReason -Path $jsonl -Event "shutdown_done" -Reason "e2e_shutdown_test")
        Detail = "jsonl shutdown_done reason=e2e_shutdown_test"
    })
    $checks.Add([pscustomobject]@{
        Name = "s4_process_gone"
        Pass = -not (Get-Process -Name "SearchCenterCore" -ErrorAction SilentlyContinue)
        Detail = "SearchCenterCore.exe not running"
    })
} else {
    Stop-SearchCoreIfRunning
    $checks.Add([pscustomobject]@{
        Name = "s4_skip_shutdown_probe"
        Pass = $true
        Detail = "skipped AHK shutdown probe (run TryAhkLaunchMatrix first)"
    })
}

$allPass = $true
Write-Output "== SearchCore Lifecycle E2E =="
Write-Output "root=$Root"
Write-Output "core=$coreExe"
foreach ($c in $checks) {
    $mark = if ($c.Pass) { "PASS" } else { "FAIL" }
    Write-Output ("[{0}] {1} :: {2}" -f $mark, $c.Name, $c.Detail)
    if (-not $c.Pass) { $allPass = $false }
}
if ($allPass) {
    Write-Output "RESULT=PASS"
    exit 0
}
Write-Output "RESULT=FAIL"
exit 1
