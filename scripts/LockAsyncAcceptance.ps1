param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int]$StressTotal = 600,
    [int]$OfflineMs = 300000,
    [int]$RecoveryPort = 19191,
    [switch]$SkipRecovery
)

$ErrorActionPreference = "Stop"
$cache = Join-Path $Root "Cache"
$locked = Join-Path $cache "ahk_async_acceptance_locked.txt"
$stressReport = Join-Path $cache "core_async_http_stress_report.txt"
$recoveryReport = Join-Path $cache "core_async_http_recovery_report.txt"

if ($StressTotal -lt 500) { throw "StressTotal must be >= 500 (got $StressTotal)" }

function Write-Locked {
    param([hashtable]$Fields)
    $lines = @("ahk_async_acceptance_locked", "ts=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    foreach ($k in ($Fields.Keys | Sort-Object)) {
        $lines += "$k=$($Fields[$k])"
    }
    $lines += "RESULT=PASS"
    Set-Content -LiteralPath $locked -Value ($lines -join "`r`n") -Encoding UTF8
}

Write-Output "== Lock Async Acceptance (stress_total=$StressTotal offline_ms=$OfflineMs) =="

$e2eStress = Join-Path $Root "scripts\RunAsyncGuardrailsE2E.ps1"
& powershell -ExecutionPolicy Bypass -File $e2eStress -Root $Root -StressTotal $StressTotal
if ($LASTEXITCODE -ne 0) {
    Write-Output "RESULT=FAIL stage=stress_e2e"
    exit 1
}

$valStress = Join-Path $Root "scripts\ValidateAsyncGuardrails.ps1"
& powershell -ExecutionPolicy Bypass -File $valStress -Root $Root -MinRequests 500
if ($LASTEXITCODE -ne 0) {
    Write-Output "RESULT=FAIL stage=validate_stress"
    exit 1
}

$sr = @{}
if (Test-Path $stressReport) {
    foreach ($line in (Get-Content -LiteralPath $stressReport -Encoding UTF8)) {
        if ($line -match "^(\w+)=(.+)$") { $sr[$Matches[1]] = $Matches[2].Trim() }
    }
}
if ([int]$sr["total"] -lt 500 -or [int]$sr["active_after"] -ne 0) {
    Write-Output "RESULT=FAIL stage=stress_report total=$($sr['total']) active_after=$($sr['active_after'])"
    exit 1
}

$fields = @{
    stress_total       = $sr["total"]
    stress_done        = $sr["done"]
    stress_active_after = $sr["active_after"]
    stress_retry_jobs_after = $sr["retry_jobs_after"]
}

if (-not $SkipRecovery) {
    $listenerScript = Join-Path $Root "scripts\RecoveryProbeListener.ps1"
    $listenerProc = $null
    try {
        $listenerProc = Start-Process -FilePath "powershell.exe" `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $listenerScript, "-Port", $RecoveryPort) `
            -WindowStyle Hidden -PassThru
        Start-Sleep -Seconds 2

        $e2eRecovery = Join-Path $Root "scripts\RunRecoveryProbeE2E.ps1"
        & powershell -ExecutionPolicy Bypass -File $e2eRecovery -Root $Root -OfflineMs $OfflineMs -Port $RecoveryPort
        if ($LASTEXITCODE -ne 0) {
            Write-Output "RESULT=FAIL stage=recovery_e2e"
            exit 1
        }

        $valRecovery = Join-Path $Root "scripts\ValidateRecoveryProbe.ps1"
        & powershell -ExecutionPolicy Bypass -File $valRecovery -Root $Root
        if ($LASTEXITCODE -ne 0) {
            Write-Output "RESULT=FAIL stage=validate_recovery"
            exit 1
        }

        $rr = @{}
        if (Test-Path $recoveryReport) {
            foreach ($line in (Get-Content -LiteralPath $recoveryReport -Encoding UTF8)) {
                if ($line -match "^(\w+)=(.+)$") { $rr[$Matches[1]] = $Matches[2].Trim() }
            }
        }
        if ([int]$rr["offline_ms"] -lt 300000 -or [int]$rr["pass"] -ne 1 -or [int]$rr["online_ok"] -lt 1 -or [int]$rr["active_after"] -ne 0) {
            Write-Output "RESULT=FAIL stage=recovery_report pass=$($rr['pass']) online_ok=$($rr['online_ok']) offline_ms=$($rr['offline_ms'])"
            exit 1
        }
        $fields["recovery_offline_ms"] = $rr["offline_ms"]
        $fields["recovery_online_ok"] = $rr["online_ok"]
        $fields["recovery_pass"] = $rr["pass"]
        $fields["recovery_active_after"] = $rr["active_after"]
    } finally {
        if ($listenerProc -and -not $listenerProc.HasExited) {
            try { Stop-Process -Id $listenerProc.Id -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
}

Write-Locked -Fields $fields
Write-Output "written=$locked"
Get-Content -LiteralPath $locked -Encoding UTF8
Write-Output "RESULT=PASS"
exit 0
