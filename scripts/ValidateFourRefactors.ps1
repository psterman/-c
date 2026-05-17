param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$scripts = @(
    "ValidateRequestIdStaleContract.ps1",
    "ValidateAsyncGuardrails.ps1",
    "ValidateVoiceInputFsm.ps1"
)
$allPass = $true
Write-Output "== Four Refactors Validation =="
foreach ($s in $scripts) {
    $p = Join-Path $Root "scripts\$s"
    & powershell -ExecutionPolicy Bypass -File $p -Root $Root
    if ($LASTEXITCODE -ne 0) { $allPass = $false }
}
$cp = Join-Path $Root "modules\CloudPlayer.ahk"
$httpJson = (Select-String -LiteralPath $cp -Pattern 'CloudPlayer_HttpJson\(' | Where-Object { $_.Line -notmatch 'CloudPlayer_HttpJsonAsync|CloudPlayer_HttpJsonFromCore' }).Count
Write-Output ("cloudplayer_httpjson_sync_call_sites={0}" -f $httpJson)
if ($httpJson -gt 20) {
    Write-Output "[WARN] many sync bridge calls remain (import/admin); routed via CoreAsyncHttp"
}
if ($allPass) {
    Write-Output "RESULT=PASS"
    exit 0
}
Write-Output "RESULT=FAIL"
exit 1
