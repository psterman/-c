# 一键：跑 Surface 门禁诊断并打开可视化看板（内嵌 JSON，避免 file:// fetch 失败）
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = (Resolve-Path (Join-Path $here "..\..")).Path

& (Join-Path $here "Diagnose-SurfaceRuntime.ps1") -RepoRoot $repo
& (Join-Path $here "Diagnose-FTB1Gate.ps1") -RepoRoot $repo
& (Join-Path $here "Diagnose-S8B3Gate.ps1") -RepoRoot $repo
& (Join-Path $here "Diagnose-S9DomainCGate.ps1") -RepoRoot $repo
& (Join-Path $here "Diagnose-S10FTBShellGate.ps1") -RepoRoot $repo

$template = Join-Path $here "dashboard.html"
$jsonPath = Join-Path $repo "Cache\debug\surface_runtime_diagnosis.json"
$ftb1JsonPath = Join-Path $repo "Cache\debug\ftb1_gate_diagnosis.json"
$s8JsonPath = Join-Path $repo "Cache\debug\s8b3_gate_diagnosis.json"
$s9JsonPath = Join-Path $repo "Cache\debug\s9domainc_gate_diagnosis.json"
$s10JsonPath = Join-Path $repo "Cache\debug\s10ftb_gate_diagnosis.json"
$livePath = Join-Path $here "dashboard-live.html"

if (-not (Test-Path $jsonPath)) {
    Write-Error "Missing $jsonPath — reload niuma and open a panel first."
}

$jsonRaw = (Get-Content $jsonPath -Raw -Encoding UTF8).Trim()
if (Test-Path $ftb1JsonPath) {
    $surfaceObj = $jsonRaw | ConvertFrom-Json
    $ftb1Obj = Get-Content $ftb1JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $gates = [System.Collections.ArrayList]@()
    if ($surfaceObj.gates) {
        foreach ($g in $surfaceObj.gates) { [void]$gates.Add($g) }
    }
    [void]$gates.Add(@{
        id = "s7"
        title = "S7 FTB-1"
        pass = [bool]$ftb1Obj.s7_gate_pass
        metrics = $ftb1Obj.metrics
    })
    $surfaceObj | Add-Member -NotePropertyName gates -NotePropertyValue @($gates.ToArray()) -Force
    $surfaceObj | Add-Member -NotePropertyName s7_gate_pass -NotePropertyValue ([bool]$ftb1Obj.s7_gate_pass) -Force
    $surfaceObj | Add-Member -NotePropertyName s7_failure_reasons -NotePropertyValue @($ftb1Obj.s7_failure_reasons) -Force
    if (Test-Path $s8JsonPath) {
        $s8Obj = Get-Content $s8JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        [void]$gates.Add(@{
            id = "s8"
            title = "S8 B3 CP"
            pass = [bool]$s8Obj.s8_gate_pass
            metrics = $s8Obj.metrics
        })
        $surfaceObj | Add-Member -NotePropertyName gates -NotePropertyValue @($gates.ToArray()) -Force
        $surfaceObj | Add-Member -NotePropertyName s8_gate_pass -NotePropertyValue ([bool]$s8Obj.s8_gate_pass) -Force
        $surfaceObj | Add-Member -NotePropertyName s8_failure_reasons -NotePropertyValue @($s8Obj.s8_failure_reasons) -Force
    }
    if (Test-Path $s9JsonPath) {
        $s9Obj = Get-Content $s9JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        [void]$gates.Add(@{
            id = "s9"
            title = "S9 Domain C"
            pass = [bool]$s9Obj.s9_gate_pass
            metrics = $s9Obj.metrics
        })
        $surfaceObj | Add-Member -NotePropertyName gates -NotePropertyValue @($gates.ToArray()) -Force
        $surfaceObj | Add-Member -NotePropertyName s9_gate_pass -NotePropertyValue ([bool]$s9Obj.s9_gate_pass) -Force
        $surfaceObj | Add-Member -NotePropertyName s9_failure_reasons -NotePropertyValue @($s9Obj.s9_failure_reasons) -Force
    }
    if (Test-Path $s10JsonPath) {
        $s10Obj = Get-Content $s10JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        [void]$gates.Add(@{
            id = "s10"
            title = "S10 FTB Shell"
            pass = [bool]$s10Obj.s10_gate_pass
            metrics = $s10Obj.metrics
        })
        $surfaceObj | Add-Member -NotePropertyName gates -NotePropertyValue @($gates.ToArray()) -Force
        $surfaceObj | Add-Member -NotePropertyName s10_gate_pass -NotePropertyValue ([bool]$s10Obj.s10_gate_pass) -Force
        $surfaceObj | Add-Member -NotePropertyName s10_failure_reasons -NotePropertyValue @($s10Obj.s10_failure_reasons) -Force
    }
    $jsonRaw = ($surfaceObj | ConvertTo-Json -Depth 8)
}
$htmlRaw = Get-Content $template -Raw -Encoding UTF8

# PowerShell 双引号里不能直接写 "<script>"，用拼接避免 "<" 被当成重定向
$scriptTagOpen = '<script>window.__SURFACE_GATE_DATA__ = '
$scriptTagClose = ';</script>'
$inject = $scriptTagOpen + $jsonRaw + $scriptTagClose
$bodyClose = '</body>'
$liveHtml = $htmlRaw.Replace($bodyClose, ($inject + "`r`n" + $bodyClose))
$liveHtml | Set-Content -Path $livePath -Encoding UTF8

Write-Host ""
Write-Host "Dashboard: $livePath"
try {
    $j = $jsonRaw | ConvertFrom-Json
    $s7 = if ($j.s7_gate_pass) { "PASS" } else { "FAIL" }
    $s8 = if ($j.s8_gate_pass) { "PASS" } else { "FAIL" }
    $s9 = if ($j.s9_gate_pass) { "PASS" } else { "FAIL" }
    $s10 = if ($j.s10_gate_pass) { "PASS" } else { "FAIL" }
    $s6 = if ($j.s6_gate_pass) { "PASS" } else { "FAIL" }
    $s5 = if ($j.s5_gate_pass) { "PASS" } else { "FAIL" }
    $s4 = if ($j.s4_gate_pass) { "PASS" } else { "FAIL" }
    $s3 = if ($j.s3_gate_pass) { "PASS" } else { "FAIL" }
    $s2 = if ($j.s2_gate_pass) { "PASS" } else { "FAIL" }
    Write-Host ("S2 gate: " + $s2)
    Write-Host ("S3 gate: " + $s3)
    Write-Host ("S4 gate: " + $s4)
    Write-Host ("S5 gate: " + $s5)
    Write-Host ("S6 gate: " + $s6)
    Write-Host ("S7 gate: " + $s7)
    Write-Host ("S8 gate: " + $s8)
    Write-Host ("S9 gate: " + $s9)
    Write-Host ("S10 gate: " + $s10)
    Write-Host ("session: " + $j.traceSession)
    if ($j.memoryGate) {
        Write-Host ("memory: " + $j.memoryGate.status + " current=" + $j.memoryGate.current_emptyLoadPrivateMiB + " s0=" + $j.memoryGate.s0_emptyLoadPrivateMiB)
    }
} catch {
}

Start-Process $livePath
