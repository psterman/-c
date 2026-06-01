param(
    [string]$Root = ""
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"

$checks = @(
    @{ Name = "async_guardrails"; Path = "modules\AsyncGuardrails.ahk"; Patterns = @("AsyncGuardrails_ShouldDropStale", "AsyncGuardrails_UpdateLatest", "AsyncGuardrails_AttachMeta") },
    @{ Name = "cloudplayer_stale"; Path = "modules\CloudPlayer.ahk"; Patterns = @("cloudplayer_drop_stale_req", "CloudPlayer_MarkLatestReq", "AsyncGuardrails_") },
    @{ Name = "clipboard_stale"; Path = "modules\ClipboardPanelCore.ahk"; Patterns = @("cp_drop_stale_req") },
    @{ Name = "config_stale"; Path = "modules\ConfigWebViewModule.ahk"; Patterns = @("config_drop_stale_req", "ConfigWebView_MarkLatestReq") },
    @{ Name = "ttyd_stale"; Path = "modules\NiumaTtyd.ahk"; Patterns = @("ttyd_drop_stale_req", "NiumaTtyd_MarkLatestReq") },
    @{ Name = "core_request_id"; Path = "modules\CoreAsyncHttp.ahk"; Patterns = @('"requestId"') },
    @{ Name = "guardrails_doc"; Path = "docs\AHK_ASYNC_GUARDRAILS.md"; Patterns = @("Module onboarding checklist") }
)

$allPass = $true
Write-Output "== RequestId / Stale Contract Validation =="
Write-Output "root=$Root"
foreach ($c in $checks) {
    $fp = Join-Path $Root $c.Path
    if (!(Test-Path $fp)) {
        Write-Output "[FAIL] $($c.Name) :: missing $fp"
        $allPass = $false
        continue
    }
    $ok = $true
    foreach ($p in $c.Patterns) {
        if (-not (Select-String -LiteralPath $fp -Pattern $p -SimpleMatch -Quiet)) {
            Write-Output "[FAIL] $($c.Name) :: missing pattern $p"
            $ok = $false
            $allPass = $false
        }
    }
    if ($ok) { Write-Output "[PASS] $($c.Name)" }
}
if ($allPass) {
    Write-Output "RESULT=PASS"
    exit 0
}
Write-Output "RESULT=FAIL"
exit 1
