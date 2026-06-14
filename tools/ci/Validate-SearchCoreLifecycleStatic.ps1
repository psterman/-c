param(
    [string]$Root = ""
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"

function Test-NoPattern {
    param([string]$Path, [string]$Pattern)
    if (-not (Test-Path -LiteralPath $Path)) { return $true }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return -not ([regex]::IsMatch($raw, $Pattern))
}

function Count-Pattern {
    param([string]$Path, [string]$Pattern)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return ([regex]::Matches($raw, $Pattern)).Count
}

$mainAhk = Join-Path $Root "牛马.ahk"
if (-not (Test-Path -LiteralPath $mainAhk)) {
    $mainAhk = Nmer-ResolveMainAhk -Root $Root
}
$scwv = Join-Path $Root "modules\SearchCenterWebViewCore.ahk"
$tools = Join-Path $Root "modules\ToolsPaths.ahk"
$lifecycle = Join-Path $Root "modules\SearchCoreLifecycle.ahk"

$lifecycleRaw = ""
if (Test-Path -LiteralPath $lifecycle) {
    $lifecycleRaw = Get-Content -LiteralPath $lifecycle -Raw -Encoding UTF8
}
$lifecycleOrTools = $lifecycleRaw
if (Test-Path -LiteralPath $tools) {
    $lifecycleOrTools = $lifecycleOrTools + (Get-Content -LiteralPath $tools -Raw -Encoding UTF8)
}

$checks = @(
    [pscustomobject]@{
        Name = "no_cold_boot_kill_after_everything"
        Pass = (Test-NoPattern -Path $mainAhk -Pattern 'InitEverythingService\(\)[\s\S]{0,500}?ProcessClose\("SearchCenterCore\.exe"\)')
        Detail = "牛马.ahk must not ProcessClose SearchCenterCore right after InitEverythingService"
    },
    [pscustomobject]@{
        Name = "single_autostart_timer"
        Pass = ((Count-Pattern -Path $mainAhk -Pattern 'SetTimer\(Nmer_AutoStartSearchCenterCore') -eq 1)
        Detail = "exactly one SetTimer(Nmer_AutoStartSearchCenterCore"
    },
    [pscustomobject]@{
        Name = "autostart_2s_not_dual"
        Pass = (Test-NoPattern -Path $mainAhk -Pattern 'Nmer_AutoStartSearchCenterCore,\s*-6000')
        Detail = "no -6000 second autostart timer"
    },
    [pscustomobject]@{
        Name = "scwv_running_requires_health_gate"
        Pass = (Select-String -LiteralPath $scwv -Pattern 'Nmer_SearchCenterCoreHealthy\(\)' -Quiet) `
            -and (Select-String -LiteralPath $scwv -Pattern 'g_SCWV_GoStartPhase := "RUNNING"' -Quiet) `
            -and (Test-NoPattern -Path $scwv -Pattern 'if ProcessExist\("SearchCenterCore\.exe"\)\s*\{\s*g_SCWV_GoStartPhase := "RUNNING"')
        Detail = "SCWV sets RUNNING only behind health gate, not immediately after ProcessExist"
    },
    [pscustomobject]@{
        Name = "status_api_exists"
        Pass = ($lifecycleOrTools -match 'Nmer_StartSearchCenterCoreStatus\(')
        Detail = "lifecycle defines Nmer_StartSearchCenterCoreStatus"
    },
    [pscustomobject]@{
        Name = "shutdown_helper_exists"
        Pass = ($lifecycleOrTools -match 'SearchCore_Shutdown\(')
        Detail = "lifecycle defines SearchCore_Shutdown"
    },
    [pscustomobject]@{
        Name = "bool_wrapper_preserved"
        Pass = ($lifecycleOrTools -match 'Nmer_StartSearchCenterCore\(forceRestart')
        Detail = "bool wrapper Nmer_StartSearchCenterCore preserved"
    }
)

$allowedBareClose = @(
    (Join-Path $Root "modules\SearchCoreLifecycle.ahk")
)
$bareClose = @()
Get-ChildItem -Path (Join-Path $Root "modules"), $Root -Filter "*.ahk" -File -ErrorAction SilentlyContinue |
    ForEach-Object {
        $lines = Select-String -LiteralPath $_.FullName -Pattern 'ProcessClose\("SearchCenterCore\.exe"\)' -AllMatches
        foreach ($m in $lines) {
            $line = $m.Line.Trim()
            if ($line -match 'SearchCore_Shutdown') { continue }
            if ($line -match 'else if ProcessExist') { continue }
            if ($allowedBareClose -contains $_.FullName) { continue }
            $raw = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
            if ($raw -match 'SearchCore_Shutdown\(' -and $raw -match 'ProcessClose\("SearchCenterCore\.exe"\)') { continue }
            $bareClose += "$($_.Name):$($m.LineNumber):$line"
        }
    }
$checks += [pscustomobject]@{
    Name = "processclose_only_shutdown_or_fallback"
    Pass = ($bareClose.Count -eq 0)
    Detail = if ($bareClose.Count -eq 0) { "ok (ToolsPaths internal + fallbacks allowed)" } else { ($bareClose -join " | ") }
}

$allPass = $true
Write-Output "== SearchCore Lifecycle Static Validation =="
Write-Output "root=$Root"
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
