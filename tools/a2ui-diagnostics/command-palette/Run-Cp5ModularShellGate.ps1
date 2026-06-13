# CP5: CommandPalette.html modular shell — Wave 1-4 static gate.
param(
    [switch]$JsonOnly,
    [switch]$SkipFixtures
)

. (Join-Path $PSScriptRoot "..\_DiagRoot.ps1")
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Get-DiagRepoRoot -From $here
$dbg = Join-Path $repo "Cache\debug"
$gatePath = Join-Path $dbg "cp5_modular_shell_gate.json"
$cp4GatePath = Join-Path $dbg "cp4_agent_transport_hub_gate.json"
$cpHtml = Join-Path $repo "html\CommandPalette.html"
$fixturesScript = Join-Path $repo "html\run-palette-fixtures.mjs"

$INLINE_BASELINE = 8366
$INLINE_MAX_WAVE4 = 6866
$INLINE_MIN_REDUCTION = 1500

function Get-JsonFile([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    return Get-Content $path -Encoding UTF8 -Raw | ConvertFrom-Json
}

function Get-InlineScriptLineCount([string]$htmlPath) {
    if (-not (Test-Path $htmlPath)) { return -1 }
    $raw = Get-Content $htmlPath -Encoding UTF8 -Raw
    $m = [regex]::Match($raw, '(?s)<div id="root"[^>]*>.*?</div>\s*<script>\s*(.*?)\s*</script>\s*</body>')
    if (-not $m.Success) { return -1 }
    return (@($m.Groups[1].Value -split "`n")).Count
}

function Test-HtmlReferencesModule([string]$htmlText, [string]$modulePath) {
    return $htmlText -match [regex]::Escape($modulePath)
}

Write-Host ""
Write-Host "=== CP5 Modular Shell Gate ===" -ForegroundColor Cyan

$checks = @()
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

$cp4 = Get-JsonFile $cp4GatePath
$cp4Pass = $cp4 -and [bool]$cp4.overallPass
$checks += @{ name = "cp4_prerequisite"; pass = $cp4Pass; value = $(if ($cp4Pass) { "pass" } else { "missing_or_fail" }) }
if (-not $cp4Pass) {
    [void]$failures.Add("cp4_agent_transport_hub_gate.json overallPass!=true")
}

$wave1Modules = @(
    "palette/app/intent-router.js",
    "palette/app/palette-store.js",
    "palette/app/bootstrap.js"
)
$wave2Modules = @(
    "palette/views/result-row.js",
    "palette/search/result-merger.js",
    "palette/views/detail-pane.js",
    "palette/views/command-results.js"
)
$wave3Modules = @(
    "palette/agent/agent-summary.js",
    "palette/agent/agent-detail.js",
    "palette/app/host-bridge.js"
)
$wave3Fixture = "palette/test/PaletteActionHistoryShell.fixtures.js"
$wave4Modules = @(
    "palette/agent/agent-card-sync.js",
    "palette/views/action-bar.js",
    "palette/app/palette-shell.js"
)
$allModules = $wave1Modules + $wave2Modules + $wave3Modules + $wave4Modules

$modulesOk = $true
foreach ($rel in $allModules) {
    $abs = Join-Path (Join-Path $repo "html") ($rel -replace "/", "\")
    $exists = Test-Path $abs
    $checks += @{ name = ("module_" + ($rel -replace "[/\.]", "_")); pass = $exists; value = $(if ($exists) { "ok" } else { "missing" }) }
    if (-not $exists) {
        $modulesOk = $false
        [void]$failures.Add("missing module: $rel")
    }
}
$fixtureAbs = Join-Path (Join-Path $repo "html") ($wave3Fixture -replace "/", "\")
$fixtureExists = Test-Path $fixtureAbs
$checks += @{ name = "module_palette_test_action_history_shell_fixtures_js"; pass = $fixtureExists; value = $(if ($fixtureExists) { "ok" } else { "missing" }) }
if (-not $fixtureExists) {
    $modulesOk = $false
    [void]$failures.Add("missing fixture: $wave3Fixture")
}

$htmlText = ""
$htmlRefsOk = $false
if (Test-Path $cpHtml) {
    $htmlText = Get-Content $cpHtml -Encoding UTF8 -Raw
    $htmlRefsOk = $true
    foreach ($rel in $allModules) {
        $refOk = Test-HtmlReferencesModule $htmlText $rel
        $checks += @{ name = ("html_ref_" + ($rel -replace "[/\.]", "_")); pass = $refOk; value = $refOk }
        if (-not $refOk) {
            $htmlRefsOk = $false
            [void]$failures.Add("CommandPalette.html missing script ref: $rel")
        }
    }
} else {
    [void]$failures.Add("CommandPalette.html missing")
    $checks += @{ name = "command_palette_html"; pass = $false; value = "missing" }
}

$inlineLines = Get-InlineScriptLineCount $cpHtml
$inlineReduction = if ($inlineLines -ge 0) { $INLINE_BASELINE - $inlineLines } else { 0 }
$inlinePass = ($inlineLines -ge 0) -and ($inlineLines -le $INLINE_MAX_WAVE4) -and ($inlineReduction -ge $INLINE_MIN_REDUCTION)
$checks += @{
    name  = "inline_script_lines"
    pass  = $inlinePass
    value = $(if ($inlineLines -ge 0) { "$inlineLines (baseline=$INLINE_BASELINE reduction=$inlineReduction)" } else { "unparsed" })
}
if (-not $inlinePass) {
    [void]$failures.Add("inline script lines=$inlineLines (max=$INLINE_MAX_WAVE4 reduction min=$INLINE_MIN_REDUCTION)")
}

$noInlineIntentRouter = $true
$noInlineEnsureShell = $true
$noInlineBuildRow = $true
$noInlineSyncDetailNav = $true
$noInlineCurrentRows = $true
$noInlineHandleHostMessage = $true
$noInlineHandleHubAgentEvent = $true
$noInlineActionCardManager = $true
$noInlineRefreshHistoryHead = $true
$noInlineRenderAgentBar = $true
$noInlineRenderCardSync = $true
if ($htmlText) {
    $noInlineIntentRouter = -not ($htmlText -match 'var IntentRouter = \(function')
    $noInlineEnsureShell = -not ($htmlText -match 'function ensureShell\(')
    $noInlineBuildRow = -not ($htmlText -match 'function buildCommandResultRowHtml\(')
    $noInlineSyncDetailNav = -not ($htmlText -match 'function syncActionDetailNav\(')
    $noInlineCurrentRows = -not ($htmlText -match 'function currentRows\(')
    $noInlineHandleHostMessage = -not ($htmlText -match 'function handleHostMessage\(')
    $noInlineHandleHubAgentEvent = -not ($htmlText -match 'function handleHubAgentEvent\(')
    $noInlineActionCardManager = -not ($htmlText -match 'var actionCardManager = \{')
    $noInlineRefreshHistoryHead = -not ($htmlText -match 'toolbar\.innerHTML\s*=\s*\r?\n?\s*''<button type="button" class="action-history-filter')
    $noInlineRenderAgentBar = -not ($htmlText -match 'function renderAgentEngineBar\(\) \{\r?\n\s*var bar = document\.getElementById\("action-agent-bar"\)')
    $noInlineRenderCardSync = -not ($htmlText -match 'function renderActionCardSync\(cards, syncOpts\) \{\r?\n\s*syncOpts = syncOpts')
}
$patternPass = $noInlineIntentRouter -and $noInlineEnsureShell -and $noInlineBuildRow -and $noInlineSyncDetailNav -and $noInlineCurrentRows -and $noInlineHandleHostMessage -and $noInlineHandleHubAgentEvent -and $noInlineActionCardManager -and $noInlineRefreshHistoryHead -and $noInlineRenderAgentBar -and $noInlineRenderCardSync
$checks += @{ name = "no_inline_intent_router"; pass = $noInlineIntentRouter; value = $noInlineIntentRouter }
$checks += @{ name = "no_inline_ensure_shell"; pass = $noInlineEnsureShell; value = $noInlineEnsureShell }
$checks += @{ name = "no_inline_build_row"; pass = $noInlineBuildRow; value = $noInlineBuildRow }
$checks += @{ name = "no_inline_sync_detail_nav"; pass = $noInlineSyncDetailNav; value = $noInlineSyncDetailNav }
$checks += @{ name = "no_inline_current_rows"; pass = $noInlineCurrentRows; value = $noInlineCurrentRows }
$checks += @{ name = "no_inline_handle_host_message"; pass = $noInlineHandleHostMessage; value = $noInlineHandleHostMessage }
$checks += @{ name = "no_inline_handle_hub_agent_event"; pass = $noInlineHandleHubAgentEvent; value = $noInlineHandleHubAgentEvent }
$checks += @{ name = "no_inline_action_card_manager"; pass = $noInlineActionCardManager; value = $noInlineActionCardManager }
$checks += @{ name = "no_inline_refresh_history_head"; pass = $noInlineRefreshHistoryHead; value = $noInlineRefreshHistoryHead }
$checks += @{ name = "no_inline_render_agent_bar"; pass = $noInlineRenderAgentBar; value = $noInlineRenderAgentBar }
$checks += @{ name = "no_inline_render_card_sync"; pass = $noInlineRenderCardSync; value = $noInlineRenderCardSync }
if (-not $patternPass) {
    [void]$failures.Add("inline still contains extracted function patterns")
}

$fixturesPass = $true
$fixturesDetail = "skipped"
if (-not $SkipFixtures) {
    if (-not (Test-Path $fixturesScript)) {
        $fixturesPass = $false
        $fixturesDetail = "script_missing"
        [void]$failures.Add("run-palette-fixtures.mjs missing")
    } else {
        try {
            $fxOut = & node $fixturesScript 2>&1 | Out-String
            $fixturesPass = ($LASTEXITCODE -eq 0) -and ($fxOut -match '\d+/\d+' -or $fxOut -match 'PASS|ok')
            if ($fxOut -match '(\d+)/(\d+)') {
                $fixturesDetail = $Matches[0]
                if ($Matches[1] -ne $Matches[2]) {
                    $fixturesPass = $false
                    [void]$failures.Add("fixtures not all green: $($Matches[0])")
                }
            } elseif (-not $fixturesPass) {
                $fixturesDetail = "exit=$LASTEXITCODE"
                [void]$failures.Add("run-palette-fixtures.mjs failed")
            } else {
                $fixturesDetail = "exit=0"
            }
        } catch {
            $fixturesPass = $false
            $fixturesDetail = $_.Exception.Message
            [void]$failures.Add("fixtures run error: $($_.Exception.Message)")
        }
    }
}
$checks += @{ name = "palette_fixtures"; pass = $fixturesPass; value = $fixturesDetail }

$overallPass = ($failures.Count -eq 0)
$report = [ordered]@{
    generatedAt      = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    phase            = "CP5"
    mode             = "modular_shell_wave1_2_3_4"
    overallPass      = $overallPass
    failReason       = if ($overallPass) { "" } else { ($failures -join "; ") }
    warnings         = @($warnings)
    checks           = $checks
    inlineBaseline   = $INLINE_BASELINE
    inlineLines      = $inlineLines
    inlineReduction  = $inlineReduction
    modules          = $allModules
    cp4Gate          = $cp4GatePath
    nextStep         = if ($overallPass) { "CP5 complete (−1500 lines) — proceed CP6 Wails gray" } else { "fix failures then re-run Run-Cp5ModularShellGate.ps1" }
}

$report | ConvertTo-Json -Depth 10 | Set-Content -Path $gatePath -Encoding UTF8
if ($JsonOnly) {
    $report | ConvertTo-Json -Depth 10
    exit $(if ($overallPass) { 0 } else { 1 })
}

foreach ($c in $checks) {
    $color = if ($c.pass) { "Green" } else { "Red" }
    Write-Host ("  {0}: {1} -> {2}" -f $c.name, $c.value, $(if ($c.pass) { "PASS" } else { "FAIL" })) -ForegroundColor $color
}
if ($warnings.Count -gt 0) {
    Write-Host ""
    foreach ($w in $warnings) { Write-Host ("  WARN: {0}" -f $w) -ForegroundColor Yellow }
}
Write-Host ""
Write-Host ("overall: {0}" -f $(if ($overallPass) { "PASS" } else { "FAIL" })) -ForegroundColor $(if ($overallPass) { "Green" } else { "Red" })
Write-Host ("report: {0}" -f $gatePath) -ForegroundColor DarkGray
if ($overallPass) { Write-Host "Next: CP5 complete — CP6 Wails gray" -ForegroundColor Green }
exit $(if ($overallPass) { 0 } else { 1 })
