param(
    [string]$Root = ""
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

function Stop-SearchCoreIfRunning {
    $p = Get-Process -Name "SearchCenterCore" -ErrorAction SilentlyContinue
    if ($p) {
        $p | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800
    }
}

$checks = New-Object System.Collections.Generic.List[object]
Stop-SearchCoreIfRunning

$start1 = Nmer-InvokeSearchCoreProbe -Root $Root -ProbeRelativeName "SearchCoreStartProbe.ahk" -ExtraArgs @("e2e_debounce_first")
Stop-SearchCoreIfRunning
Start-Sleep -Milliseconds 400

$start2 = Nmer-InvokeSearchCoreProbe -Root $Root -ProbeRelativeName "SearchCoreStartProbe.ahk" -ExtraArgs @("e2e_debounce_second")
$checks.Add([pscustomobject]@{
    Name = "s3_lifecycle_relaunch_within_debounce"
    Pass = ($start1 -eq 0) -and ($start2 -eq 0)
    Detail = "StartProbe first=$start1 second=$start2"
})
Stop-SearchCoreIfRunning

$allPass = $true
Write-Output "== SearchCore Lifecycle Phase1 E2E =="
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
