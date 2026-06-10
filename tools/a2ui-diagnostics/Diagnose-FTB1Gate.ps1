# S7 — FTB-1 静态门禁：runPaletteAgentStreamOnce 已迁入 palette-agent-bridge.js
param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if (-not $RepoRoot) {
    $here = Split-Path -Parent $MyInvocation.MyCommand.Path
    $RepoRoot = (Resolve-Path (Join-Path $here "..\..")).Path
}

$bridgePath = Join-Path $RepoRoot "html\ftb\palette\palette-agent-bridge.js"
$htmlPath = Join-Path $RepoRoot "html\FloatingToolbarStrip.html"
$outPath = Join-Path $RepoRoot "Cache\debug\ftb1_gate_diagnosis.txt"
$jsonPath = Join-Path $RepoRoot "Cache\debug\ftb1_gate_diagnosis.json"

$null = New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null

$lines = @()
$lines += "FTB-1 Gate Diagnosis (S7)"
$lines += "capturedAt=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$lines += "bridgePath=$bridgePath"
$lines += "htmlPath=$htmlPath"

$failureReasons = @()
$bridgeText = ""
$htmlText = ""

if (-not (Test-Path $bridgePath)) {
    $failureReasons += "bridge_file_missing"
} else {
    $bridgeText = Get-Content $bridgePath -Raw -Encoding UTF8
}

if (-not (Test-Path $htmlPath)) {
    $failureReasons += "ftb_html_missing"
} else {
    $htmlText = Get-Content $htmlPath -Raw -Encoding UTF8
}

$bridgeVersion = ""
if ($bridgeText -match 'VERSION\s*=\s*"([^"]+)"') {
    $bridgeVersion = $Matches[1]
}

$bridgeHasStreamOnce = $false
$bridgeRequiresHostInject = $false
if ($bridgeText) {
    $bridgeHasStreamOnce = ($bridgeText -match 'async\s+function\s+runPaletteAgentStreamOnce') -or
        ($bridgeText -match 'function\s+runPaletteAgentStreamOnce')
    $bridgeRequiresHostInject = ($bridgeText -match 'missing\s+ctx\.runPaletteAgentStreamOnce') -or
        ($bridgeText -match 'ctx\.runPaletteAgentStreamOnce')
}

$htmlHasInlineStreamOnce = $false
$htmlLoadsBridge = $false
$htmlInjectsStreamOnce = $false
if ($htmlText) {
    $htmlHasInlineStreamOnce = $htmlText -match 'async\s+function\s+runPaletteAgentStreamOnce'
    $htmlLoadsBridge = $htmlText -match 'ftb/palette/palette-agent-bridge\.js'
    $htmlInjectsStreamOnce = $htmlText -match 'runPaletteAgentStreamOnce\s*:'
}

if (-not $bridgeHasStreamOnce) { $failureReasons += "bridge_missing_runPaletteAgentStreamOnce" }
if ($bridgeRequiresHostInject) { $failureReasons += "bridge_still_requires_host_inject" }
if ($htmlHasInlineStreamOnce) { $failureReasons += "html_still_has_inline_stream_once" }
if (-not $htmlLoadsBridge) { $failureReasons += "html_missing_bridge_script" }
if ($htmlInjectsStreamOnce) { $failureReasons += "html_still_injects_stream_once" }
if ($bridgeVersion -and ($bridgeVersion -lt "ftb-1.2.0")) { $failureReasons += "bridge_version_below_1_2" }

$s7Pass = ($failureReasons.Count -eq 0)

$lines += ""
$lines += "s7Ftb1Gate:"
$lines += "bridge_version=$bridgeVersion"
$lines += "bridge_has_stream_once=$bridgeHasStreamOnce"
$lines += "bridge_requires_host_inject=$bridgeRequiresHostInject"
$lines += "html_loads_bridge=$htmlLoadsBridge"
$lines += "html_inline_stream_once=$htmlHasInlineStreamOnce"
$lines += "html_injects_stream_once=$htmlInjectsStreamOnce"
$lines += "s7_gate_pass=$s7Pass"

if (-not $s7Pass) {
    $lines += ""
    $lines += "failure_reasons=$($failureReasons -join ',')"
}

$lines | Set-Content -Path $outPath -Encoding UTF8

@{
    capturedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    gate = "s7"
    title = "S7 FTB-1"
    s7_gate_pass = [bool]$s7Pass
    s7_failure_reasons = @($failureReasons)
    metrics = @{
        bridge_version = $bridgeVersion
        bridge_has_stream_once = $(if ($bridgeHasStreamOnce) { 1 } else { 0 })
        html_loads_bridge = $(if ($htmlLoadsBridge) { 1 } else { 0 })
        html_inline_stream_once = $(if ($htmlHasInlineStreamOnce) { 1 } else { 0 })
        html_injects_stream_once = $(if ($htmlInjectsStreamOnce) { 1 } else { 0 })
    }
    bridgePath = $bridgePath
    htmlPath = $htmlPath
} | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8

Write-Host "ftb-1 gate diagnosis -> $outPath"
Write-Host "ftb-1 gate json -> $jsonPath"
Write-Host ("S7 gate: " + $(if ($s7Pass) { "PASS" } else { "FAIL" }))
if ($failureReasons.Count) {
    Write-Host ("reasons: " + ($failureReasons -join ", "))
}
exit $(if ($s7Pass) { 0 } else { 1 })
