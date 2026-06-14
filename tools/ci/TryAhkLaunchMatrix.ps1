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
#SingleInstance Off
outPath := (A_Args.Length >= 1 && Trim(String(A_Args[1])) != "")
    ? Trim(String(A_Args[1]))
    : (A_Temp . "\ahk_launch_probe\probe_out.txt")
try {
    SplitPath outPath, , &outDir
    if (outDir != "" && !DirExist(outDir))
        DirCreate(outDir)
    FileAppend("ok`n", outPath, "UTF-8")
} catch as e {
    try FileAppend("err=" . e.Message . "`n", A_Temp . "\ahk_launch_probe\probe_err.txt", "UTF-8")
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
    @{ Name = "plain"; UseCwd = $false },
    @{ Name = "plain_with_cwd"; UseCwd = $true },
    @{ Name = "errorstdout"; UseCwd = $false },
    @{ Name = "errorstdout_with_cwd"; UseCwd = $true }
)

$winner = $null
foreach ($exe in $cands) {
    foreach ($v in $variants) {
        if (Test-Path $probeOut) { Remove-Item -LiteralPath $probeOut -Force -ErrorAction SilentlyContinue }
        $ok = $false
        $errText = ""
        $exitCode = ""
        try {
            $argList = New-Object System.Collections.Generic.List[string]
            if ($v.Name -like "errorstdout*") {
                $argList.Add("/ErrorStdOut")
            }
            $argList.Add($probeScript)
            $argList.Add($probeOut)
            $wd = if ($v.UseCwd) { $probeDir } else { $null }
            $proc = Start-Process -FilePath $exe -ArgumentList $argList.ToArray() `
                -WorkingDirectory $(if ($wd) { $wd } else { (Get-Location).Path }) `
                -Wait -PassThru -NoNewWindow
            $exitCode = $proc.ExitCode
            Start-Sleep -Milliseconds 50
            $ok = Test-Path -LiteralPath $probeOut
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
