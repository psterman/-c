param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$mod = Join-Path $Root "modules\VoiceInputModule.ahk"
$eff = Join-Path $Root "modules\VoiceInputEffects.ahk"
$cli = Join-Path $Root "modules\VoiceInputCliEffects.ahk"
$fsm = Join-Path $Root "modules\VoiceInputStateMachine.ahk"

$checks = @(
    @{ Name = "fsm_search_states"; Path = $fsm; Patterns = @("search_listening", "search_open", "VoiceInput_IsSearchFsmState") },
    @{ Name = "module_no_direct_send"; Path = $mod; Patterns = @() },
    @{ Name = "effects_has_send"; Path = $eff; Patterns = @("VoiceInputEffect_SendSearchToBrowser", "Send(") },
    @{ Name = "cli_effects_dispatch"; Path = $cli; Patterns = @("VoiceInputEffect_DispatchCliAgents", "OpenCLIAgentTerminal(") }
)

$sendInMod = (Select-String -LiteralPath $mod -Pattern '\bSend\(' -AllMatches | Measure-Object).Count
$allPass = $true
Write-Output "== VoiceInput FSM Validation =="
Write-Output ("module_send_count={0} (allowlist: GUI helpers may remain)" -f $sendInMod)
foreach ($c in $checks) {
    if (!(Test-Path $c.Path)) {
        Write-Output "[FAIL] $($c.Name) missing file"
        $allPass = $false
        continue
    }
    $ok = $true
    foreach ($p in $c.Patterns) {
        if (-not (Select-String -LiteralPath $c.Path -Pattern $p -SimpleMatch -Quiet)) {
            Write-Output "[FAIL] $($c.Name) missing $p"
            $ok = $false
            $allPass = $false
        }
    }
    if ($ok -and $c.Patterns.Count -gt 0) { Write-Output "[PASS] $($c.Name)" }
}
$cliInMod = @(
    (Select-String -LiteralPath $mod -Pattern '\bOpenCLIAgentTerminal\(' -AllMatches).Count
    (Select-String -LiteralPath $mod -Pattern '\bDispatchPromptToCLIAgent\(' -AllMatches).Count
) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
if ($cliInMod -gt 0) {
    Write-Output "[FAIL] module_has_cli_side_effects :: count=$cliInMod"
    $allPass = $false
} else {
    Write-Output "[PASS] module_no_cli_side_effects"
}
if ($sendInMod -gt 80) {
    Write-Output "[FAIL] module_send_count_too_high :: count=$sendInMod max=80"
    $allPass = $false
} else {
    Write-Output "[PASS] module_send_count_under_cap :: count=$sendInMod"
}
if ($allPass) {
    Write-Output "RESULT=PASS"
    exit 0
}
Write-Output "RESULT=FAIL"
exit 1
