param(
    [string]$Root = "",
    [string]$TelemetryPath = "",
    [string]$StatePath = "",
    [switch]$ResetState
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1", "..\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) {
    if (Get-Command Nmer-ResolveProjectRoot -ErrorAction SilentlyContinue) {
        $Root = Nmer-ResolveProjectRoot $PSScriptRoot
    } else {
        $Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    }
}
if (-not $TelemetryPath) {
    $TelemetryPath = Join-Path $Root "Cache\debug\nmer_telemetry.json"
}
if (-not $StatePath) {
    $StatePath = Join-Path $Root "Cache\ci\telemetry_targeted_state.json"
}

. (Join-Path $PSScriptRoot "_TelemetryRequiredChecks.ps1")

$reportDir = Join-Path $Root "Cache\ci"
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$reportPath = Join-Path $reportDir "telemetry_targeted_report.txt"

$lines = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$lines.Add("== Telemetry Targeted Check $stamp ==")
$lines.Add("root=$Root")
$lines.Add("telemetryPath=$TelemetryPath")
$lines.Add("statePath=$StatePath")
$lines.Add("resetState=$([bool]$ResetState)")
$lines.Add("")

function Add-Line {
    param([string]$Status, [string]$Name, [string]$Detail)
    $lines.Add(("[{0}] {1} -- {2}" -f $Status, $Name, $Detail))
}

function Get-ActionCount {
    param(
        [object]$Doc,
        [string]$Scope,
        [string]$Action
    )
    try {
        if ($null -eq $Doc -or -not $Doc.scopes) { return 0 }
        $scopeObj = $Doc.scopes.$Scope
        if ($null -eq $scopeObj -or -not $scopeObj.actions) { return 0 }
        $actObj = $scopeObj.actions.$Action
        if ($null -eq $actObj -or $null -eq $actObj.count) { return 0 }
        return [int]$actObj.count
    } catch {
        return 0
    }
}

$requiredChecks = $script:TelemetryRequiredChecks

if (-not (Test-Path -LiteralPath $TelemetryPath)) {
    Add-Line "FAIL" "telemetry_file_exists" "telemetry file missing"
    $lines | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Output "report=$reportPath"
    $lines | ForEach-Object { Write-Output $_ }
    exit 1
}

$doc = $null
try {
    $raw = Get-Content -LiteralPath $TelemetryPath -Raw -Encoding UTF8
    $doc = $raw | ConvertFrom-Json
    Add-Line "PASS" "telemetry_json_parse" "json parsed"
} catch {
    Add-Line "FAIL" "telemetry_json_parse" ("json parse failed: " + $_.Exception.Message)
    $lines | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Output "report=$reportPath"
    $lines | ForEach-Object { Write-Output $_ }
    exit 1
}

$state = [ordered]@{
    satisfied = @{}
    lastUpdatedAt = ""
}
if (-not $ResetState -and (Test-Path -LiteralPath $StatePath)) {
    try {
        $loaded = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($loaded.satisfied) {
            $tmp = @{}
            foreach ($p in $loaded.satisfied.PSObject.Properties) {
                $tmp[$p.Name] = [bool]$p.Value
            }
            $state.satisfied = $tmp
        }
    } catch {
    }
}

$newlySatisfied = 0
$missing = New-Object System.Collections.Generic.List[string]
$satisfiedNow = 0
foreach ($it in $requiredChecks) {
    $key = "$($it.Scope).$($it.Action)"
    $cnt = Get-ActionCount -Doc $doc -Scope $it.Scope -Action $it.Action
    $already = $false
    if ($state.satisfied.ContainsKey($key)) {
        $already = [bool]$state.satisfied[$key]
    }
    $hit = ($cnt -gt 0) -or $already
    if ($hit) {
        if (-not $already -and $cnt -gt 0) {
            $newlySatisfied += 1
        }
        $state.satisfied[$key] = $true
        $satisfiedNow += 1
        Add-Line "PASS" $key ("count=$cnt; latched=1")
    } else {
        $missing.Add($key)
        Add-Line "FAIL" $key "count=0; latched=0"
    }
}

$state.lastUpdatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
$stateJson = $state | ConvertTo-Json -Depth 5
$stateJson | Set-Content -LiteralPath $StatePath -Encoding UTF8

$lines.Add("")
$lines.Add("---- Summary ----")
$lines.Add("required_total=$($requiredChecks.Count) satisfied_total=$satisfiedNow missing_total=$($missing.Count) newly_satisfied=$newlySatisfied")

if ($missing.Count -eq 0) {
    $lines.Add("result=PASS")
} else {
    $lines.Add("result=FAIL (targeted missing checks)")
    $lines.Add("")
    $lines.Add("missing checks:")
    foreach ($k in $missing) {
        $lines.Add("- $k")
    }
    $lines.Add("")
    $lines.Add("targeted next actions:")
    if (($missing | Where-Object { $_ -like "surface.command_palette_*" -or $_ -like "cmd.*" }).Count -gt 0) {
        $lines.Add("1) Open command palette, run one command, then close it")
    }
    if (($missing | Where-Object { $_ -like "surface.prompt_quick_pad_*" }).Count -gt 0) {
        $lines.Add("2) Open PromptQuickPad and close it")
    }
    if (($missing | Where-Object { $_ -like "surface.chord_pad_*" -or $_ -eq "cmd.ch_c" }).Count -gt 0) {
        $lines.Add("3) Long-press CapsLock to open ChordPad, run one chord (e.g. C), then close")
    }
    if (($missing | Where-Object { $_ -eq "llm.request_start" }).Count -gt 0) {
        $lines.Add("4) Send one Niuma Chat message and wait for done/fail")
    }
    if (($missing | Where-Object { $_ -like "migration.*" }).Count -gt 0) {
        $lines.Add("5) Migration: export -> preview -> import (import can cancel)")
    }
    if (($missing | Where-Object { $_ -eq "diagnostics.export_bundle" }).Count -gt 0) {
        $lines.Add("6) Export diagnostics bundle once from settings")
    }
    if (($missing | Where-Object { $_ -eq "diagnostics.copy_trace_clipboard" }).Count -gt 0) {
        $lines.Add("7) Settings -> Troubleshooting -> copy recent trace log")
    }
    if (($missing | Where-Object { $_ -like "surface.search_center_*" -or $_ -like "surface.clipboard_panel_*" -or $_ -like "surface.floating_toolbar_*" -or $_ -like "surface.config_webview_*" }).Count -gt 0) {
        $lines.Add("8) Open and close related surfaces (settings/search/clipboard/toolbar)")
    }
    if (($missing | Where-Object { $_ -eq "health.update_check_done" }).Count -gt 0) {
        $lines.Add("9) Trigger update check once from settings")
    }
}

$lines | Set-Content -LiteralPath $reportPath -Encoding UTF8
Write-Output "report=$reportPath"
$lines | ForEach-Object { Write-Output $_ }
if ($missing.Count -eq 0) { exit 0 } else { exit 1 }

