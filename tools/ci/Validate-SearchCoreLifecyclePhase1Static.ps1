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

function Test-Snippet {
    param(
        [string]$Snippet,
        [string]$MustMatch = "",
        [string]$MustNotMatch = ""
    )
    if (-not $Snippet) { return $false }
    if ($MustMatch -and -not ([regex]::IsMatch($Snippet, $MustMatch))) { return $false }
    if ($MustNotMatch -and ([regex]::IsMatch($Snippet, $MustNotMatch))) { return $false }
    return $true
}

$tools = Join-Path $Root "modules\ToolsPaths.ahk"
$palette = Join-Path $Root "modules\CommandPaletteCore.ahk"
$config = Join-Path $Root "modules\ConfigWebViewModule.ahk"
$clipboard = Join-Path $Root "modules\ClipboardPanelCore.ahk"
$scwv = Join-Path $Root "modules\SearchCenterWebViewCore.ahk"

$toolsRaw = if (Test-Path -LiteralPath $tools) { Get-Content -LiteralPath $tools -Raw -Encoding UTF8 } else { "" }

$checks = @(
    [pscustomobject]@{
        Name = "p1_debounce_relaunch_when_process_gone"
        Pass = -not ([regex]::IsMatch($toolsRaw, '(?s)if !ProcessExist\("SearchCenterCore\.exe"\)\s*\{[^\}]*launch_debounced'))
        Detail = "10s debounce must not return launch_debounced when process already exited"
    },
    [pscustomobject]@{
        Name = "p1_palette_ensure_via_lifecycle"
        Pass = (Test-Snippet -Snippet (Get-AhkFnSnippet -Path $palette -FnPattern '^CommandPalette_EnsureSearchCoreRunning\(') `
            -MustMatch 'SearchCore_EnsureStatus|Nmer_StartSearchCenterCore(Status)?\(' `
            -MustNotMatch 'Run\(')
        Detail = "CommandPalette_EnsureSearchCoreRunning uses lifecycle API, no bare Run"
    },
    [pscustomobject]@{
        Name = "p1_config_ensure_via_lifecycle"
        Pass = (Test-Snippet -Snippet (Get-AhkFnSnippet -Path $config -FnPattern '^ConfigWebView_EnsureSearchCoreRunning\(') `
            -MustMatch 'SearchCore_EnsureStatus|Nmer_StartSearchCenterCore(Status)?\(' `
            -MustNotMatch 'Run\(')
        Detail = "ConfigWebView_EnsureSearchCoreRunning uses lifecycle API, no bare Run"
    },
    [pscustomobject]@{
        Name = "p1_clipboard_ensure_via_lifecycle"
        Pass = (Test-Snippet -Snippet (Get-AhkFnSnippet -Path $clipboard -FnPattern '^_CP_EnsureSearchCoreRunning\(') `
            -MustMatch 'SearchCore_EnsureStatus|Nmer_StartSearchCenterCore(Status)?\(' `
            -MustNotMatch 'Run\(')
        Detail = "_CP_EnsureSearchCoreRunning uses lifecycle API, no bare Run"
    },
    [pscustomobject]@{
        Name = "p1_fulltext_invalid_json_no_default_force_restart"
        Pass = (Test-Snippet -Snippet (Get-AhkFnSnippet -Path $scwv -FnPattern '^_SCWV_UpdateFullTextConfig_OnRespWrapped\(' -MaxLines 25) `
            -MustNotMatch '_SCWV_RestartSearchCore\(\)')
        Detail = "invalid json body path must not call _SCWV_RestartSearchCore() with default forceRestart"
    }
)

$allPass = $true
Write-Output "== SearchCore Lifecycle Phase1 Static Validation =="
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
