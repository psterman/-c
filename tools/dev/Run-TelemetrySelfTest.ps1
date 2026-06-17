param(
    [string]$Root = "",
    [string]$TelemetryPath = "",
    [switch]$Strict
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

. (Join-Path $PSScriptRoot "_TelemetryRequiredChecks.ps1")

$reportDir = Join-Path $Root "Cache\ci"
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$reportPath = Join-Path $reportDir "telemetry_selftest_report.txt"

$lines = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$lines.Add("== Telemetry SelfTest $stamp ==")
$lines.Add("root=$Root")
$lines.Add("telemetryPath=$TelemetryPath")
$lines.Add("strict=$([bool]$Strict)")
$lines.Add("")

function Add-CheckLine {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Detail
    )
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

if (-not (Test-Path -LiteralPath $TelemetryPath)) {
    Add-CheckLine -Name "telemetry_file_exists" -Status "FAIL" -Detail "telemetry file missing; run app and trigger actions first"
    $lines.Add("")
    $lines.Add("hint: open settings -> telemetry summary, do some actions, then retry")
    $lines | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Output "report=$reportPath"
    $lines | ForEach-Object { Write-Output $_ }
    exit 1
}

$doc = $null
try {
    $raw = Get-Content -LiteralPath $TelemetryPath -Raw -Encoding UTF8
    $doc = $raw | ConvertFrom-Json
    Add-CheckLine -Name "telemetry_json_parse" -Status "PASS" -Detail "json parsed"
} catch {
    Add-CheckLine -Name "telemetry_json_parse" -Status "FAIL" -Detail ("json parse failed: " + $_.Exception.Message)
    $lines | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Output "report=$reportPath"
    $lines | ForEach-Object { Write-Output $_ }
    exit 1
}

if ($null -eq $doc.scopes) {
    Add-CheckLine -Name "telemetry_scopes" -Status "FAIL" -Detail "missing scopes node"
    $lines | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Output "report=$reportPath"
    $lines | ForEach-Object { Write-Output $_ }
    exit 1
}

$requiredChecks = $script:TelemetryRequiredChecks

$advisoryAnyGroups = @(
    @{ Name = "surface_funnel_first_action"; Items = @(
            @{ Scope = "surface"; Action = "config_webview_first_action" },
            @{ Scope = "surface"; Action = "search_center_first_action" },
            @{ Scope = "surface"; Action = "clipboard_panel_first_action" },
            @{ Scope = "surface"; Action = "command_palette_first_action" },
            @{ Scope = "surface"; Action = "floating_toolbar_first_action" },
            @{ Scope = "surface"; Action = "prompt_quick_pad_first_action" },
            @{ Scope = "surface"; Action = "chord_pad_first_action" }
        )
    },
    @{ Name = "surface_funnel_open_without_action"; Items = @(
            @{ Scope = "surface"; Action = "config_webview_open_without_action" },
            @{ Scope = "surface"; Action = "search_center_open_without_action" },
            @{ Scope = "surface"; Action = "clipboard_panel_open_without_action" },
            @{ Scope = "surface"; Action = "command_palette_open_without_action" },
            @{ Scope = "surface"; Action = "floating_toolbar_open_without_action" },
            @{ Scope = "surface"; Action = "prompt_quick_pad_open_without_action" },
            @{ Scope = "surface"; Action = "chord_pad_open_without_action" }
        )
    },
    @{ Name = "bridge_state_change"; Items = @(
            @{ Scope = "health"; Action = "bridge_reconnect" },
            @{ Scope = "health"; Action = "bridge_disconnect" }
        )
    },
    @{ Name = "update_optional_actions"; Items = @(
            @{ Scope = "health"; Action = "update_available" },
            @{ Scope = "health"; Action = "update_open_release_page" }
        )
    },
    @{ Name = "llm_end_state"; Items = @(
            @{ Scope = "llm"; Action = "request_done" },
            @{ Scope = "llm"; Action = "request_fail" }
        )
    }
)

$requiredFailed = 0
$requiredPassed = 0
foreach ($it in $requiredChecks) {
    $cnt = Get-ActionCount -Doc $doc -Scope $it.Scope -Action $it.Action
    $name = "$($it.Scope).$($it.Action)"
    if ($cnt -gt 0) {
        Add-CheckLine -Name $name -Status "PASS" -Detail "count=$cnt"
        $requiredPassed += 1
    } else {
        Add-CheckLine -Name $name -Status "FAIL" -Detail "count=0 (not triggered or not persisted)"
        $requiredFailed += 1
    }
}

$advisoryWarn = 0
$advisoryPass = 0
foreach ($grp in $advisoryAnyGroups) {
    $hit = 0
    $detailArr = @()
    foreach ($it in $grp.Items) {
        $cnt = Get-ActionCount -Doc $doc -Scope $it.Scope -Action $it.Action
        if ($cnt -gt 0) { $hit += 1 }
        $detailArr += "$($it.Scope).$($it.Action)=$cnt"
    }
    if ($hit -gt 0) {
        Add-CheckLine -Name $grp.Name -Status "PASS" -Detail ("hit=$hit; " + ($detailArr -join ", "))
        $advisoryPass += 1
    } else {
        Add-CheckLine -Name $grp.Name -Status "WARN" -Detail ("hit=0; " + ($detailArr -join ", "))
        $advisoryWarn += 1
    }
}

$lines.Add("")
$lines.Add("---- Summary ----")
$lines.Add("required_pass=$requiredPassed required_fail=$requiredFailed advisory_pass=$advisoryPass advisory_warn=$advisoryWarn")

$exitCode = 0
if ($requiredFailed -gt 0) {
    $exitCode = 1
}
if ($Strict -and $advisoryWarn -gt 0) {
    $exitCode = 2
}

if ($exitCode -eq 0) {
    $lines.Add("result=PASS")
} elseif ($exitCode -eq 1) {
    $lines.Add("result=FAIL (required checks)")
} else {
    $lines.Add("result=FAIL (strict advisory checks)")
}

$lines.Add("")
$lines.Add("quick manual trigger steps:")
$lines.Add("1) settings: run import/export/reset once; 2) SearchCenter: run one query; 3) command palette: execute one command;")
$lines.Add("4) Niuma Chat: send one message; 5) run migration export+preview+import; 6) export diagnostics bundle; 7) trigger update check in settings.")

$lines | Set-Content -LiteralPath $reportPath -Encoding UTF8
Write-Output "report=$reportPath"
$lines | ForEach-Object { Write-Output $_ }
exit $exitCode

