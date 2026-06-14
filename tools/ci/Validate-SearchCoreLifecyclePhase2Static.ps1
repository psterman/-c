param(
    [string]$Root = ""
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"

function Get-AhkFnSnippet {
    param(
        [string]$Path,
        [string]$FnPattern,
        [int]$MaxLines = 40
    )
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    $all = Get-Content -LiteralPath $Path -Encoding UTF8
    for ($i = 0; $i -lt $all.Count; $i++) {
        if ($all[$i] -match $FnPattern) {
            $end = [Math]::Min($i + $MaxLines, $all.Count - 1)
            return ($all[$i..$end] -join "`n")
        }
    }
    return ""
}

$lifecycle = Join-Path $Root "modules\SearchCoreLifecycle.ahk"
$tools = Join-Path $Root "modules\ToolsPaths.ahk"
$scwv = Join-Path $Root "modules\SearchCenterWebViewCore.ahk"
$mainAhk = Join-Path $Root "牛马.ahk"
if (-not (Test-Path -LiteralPath $mainAhk)) {
    $mainAhk = Nmer-ResolveMainAhk -Root $Root
}
$toolsRaw = if (Test-Path -LiteralPath $tools) { Get-Content -LiteralPath $tools -Raw -Encoding UTF8 } else { "" }
$mainRaw = if (Test-Path -LiteralPath $mainAhk) { Get-Content -LiteralPath $mainAhk -Raw -Encoding UTF8 } else { "" }
$scwvRestart = Get-AhkFnSnippet -Path $scwv -FnPattern '^_SCWV_RestartSearchCore\(' -MaxLines 25
$scwvLaunch = Get-AhkFnSnippet -Path $scwv -FnPattern '^_SCWV_StartSearchCoreLaunch\(' -MaxLines 25

$checks = @(
    [pscustomobject]@{
        Name = "p2_lifecycle_module_exists"
        Pass = (Test-Path -LiteralPath $lifecycle)
        Detail = "modules/SearchCoreLifecycle.ahk"
    },
    [pscustomobject]@{
        Name = "p2_tools_paths_includes_lifecycle"
        Pass = ($toolsRaw -match '#Include\s+SearchCoreLifecycle\.ahk')
        Detail = "ToolsPaths includes SearchCoreLifecycle.ahk"
    },
    [pscustomobject]@{
        Name = "p2_lifecycle_public_api"
        Pass = (Select-String -LiteralPath $lifecycle -Pattern 'SearchCore_EnsureStatus\(' -Quiet) `
            -and (Select-String -LiteralPath $lifecycle -Pattern 'SearchCore_StartWatchdog\(' -Quiet) `
            -and (Select-String -LiteralPath $lifecycle -Pattern 'SearchCore_Shutdown\(' -Quiet)
        Detail = "EnsureStatus + StartWatchdog + Shutdown in lifecycle module"
    },
    [pscustomobject]@{
        Name = "p2_scwv_restart_no_kill_phase"
        Pass = ($scwvRestart -ne "") -and -not ($scwvRestart -match 'g_SCWV_GoStartPhase\s*:=\s*"KILLING"')
        Detail = "_SCWV_RestartSearchCore skips KILLING; lifecycle handles force kill"
    },
    [pscustomobject]@{
        Name = "p2_scwv_launch_no_bare_run"
        Pass = ($scwvLaunch -ne "") -and -not ($scwvLaunch -match 'Run\(')
        Detail = "_SCWV_StartSearchCoreLaunch delegates to lifecycle only"
    },
    [pscustomobject]@{
        Name = "p2_main_watchdog_autostart"
        Pass = ($mainRaw -match 'SearchCore_StartWatchdog')
        Detail = "牛马.ahk schedules SearchCore_StartWatchdog"
    },
    [pscustomobject]@{
        Name = "p2_main_exit_stops_watchdog"
        Pass = ($mainRaw -match 'SearchCore_StopWatchdog')
        Detail = "ExitFunc stops watchdog before shutdown"
    }
)

$allPass = $true
Write-Output "== SearchCore Lifecycle Phase2 Static Validation =="
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
