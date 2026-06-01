param(
    [string]$Root = ""
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"

function Find-AhkCandidates {
    $list = New-Object System.Collections.Generic.List[string]
    $pathCmds = @("AutoHotkey64.exe", "AutoHotkey.exe")
    foreach ($n in $pathCmds) {
        $cmd = Get-Command $n -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) { $list.Add($cmd.Source) }
    }
    $hard = @(
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey.exe",
        "$env:ProgramFiles\AutoHotkey\AutoHotkey.exe",
        "$env:ProgramFiles(x86)\AutoHotkey\AutoHotkeyU64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\AutoHotkey64.exe"
    )
    foreach ($p in $hard) {
        if ($p -and (Test-Path $p) -and -not $list.Contains($p)) { $list.Add($p) }
    }
    return $list
}

$cacheDir = Join-Path $Root "Cache"
if (!(Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
$report = Join-Path $cacheDir "ahk_launch_matrix.txt"
$chosen = Join-Path $cacheDir "ahk_launch_choice.txt"

$probeDir = Join-Path $env:TEMP "ahk_launch_probe"
if (!(Test-Path $probeDir)) { New-Item -ItemType Directory -Path $probeDir -Force | Out-Null }
$probeScript = Join-Path $probeDir "probe.ahk"
$probeOut = Join-Path $probeDir "probe_out.txt"

$probeCode = @'
#Requires AutoHotkey v2.0
try {
    FileAppend("ok`r`n", A_Temp "\ahk_launch_probe\probe_out.txt", "UTF-8")
} catch {
}
ExitApp 0
'@
Set-Content -LiteralPath $probeScript -Value $probeCode -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("ahk_launch_matrix")
$lines.Add("ts=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')")
$lines.Add("root=$Root")

$cands = Find-AhkCandidates
if ($cands.Count -eq 0) {
    $lines.Add("candidate_count=0")
    $lines.Add("result=FAIL")
    Set-Content -LiteralPath $report -Value $lines -Encoding UTF8
    Get-Content -LiteralPath $report -Encoding UTF8
    exit 1
}

$lines.Add("candidate_count=$($cands.Count)")
$variants = @(
    @{ Name="plain"; Args={ param($exe,$script) @($script) }; UseCwd=$false },
    @{ Name="plain_with_cwd"; Args={ param($exe,$script) @($script) }; UseCwd=$true },
    @{ Name="errorstdout"; Args={ param($exe,$script) @("/ErrorStdOut", $script) }; UseCwd=$false },
    @{ Name="errorstdout_with_cwd"; Args={ param($exe,$script) @("/ErrorStdOut", $script) }; UseCwd=$true }
)

$winner = $null
foreach ($exe in $cands) {
    foreach ($v in $variants) {
        if (Test-Path $probeOut) { Remove-Item -LiteralPath $probeOut -Force -ErrorAction SilentlyContinue }
        $ok = $false
        $errText = ""
        $exitCode = ""
        try {
            $args = & $v.Args $exe $probeScript
            if ($v.UseCwd) {
                Push-Location $probeDir
                try {
                    & $exe @args
                    $exitCode = $LASTEXITCODE
                } finally {
                    Pop-Location
                }
            } else {
                & $exe @args
                $exitCode = $LASTEXITCODE
            }
            $ok = Test-Path $probeOut
        } catch {
            $errText = $_.Exception.Message
            $ok = $false
        }
        $lines.Add("variant exe=""$exe"" mode=$($v.Name) exit=$exitCode out_exists=$([int]$ok) err=""$errText""")
        if ($ok -and -not $winner) {
            $winner = [pscustomobject]@{
                Exe = $exe
                Mode = $v.Name
            }
        }
    }
}

if ($winner) {
    Set-Content -LiteralPath $chosen -Value @(
        "exe=$($winner.Exe)"
        "mode=$($winner.Mode)"
    ) -Encoding UTF8
    $lines.Add("winner_exe=$($winner.Exe)")
    $lines.Add("winner_mode=$($winner.Mode)")
    $lines.Add("result=PASS")
    Set-Content -LiteralPath $report -Value $lines -Encoding UTF8
    Get-Content -LiteralPath $report -Encoding UTF8
    exit 0
}

$lines.Add("result=FAIL")
Set-Content -LiteralPath $report -Value $lines -Encoding UTF8
Get-Content -LiteralPath $report -Encoding UTF8
exit 1
