param(
    [string]$Root = ""
)

foreach ($rel in @("_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"

function Find-AhkExe {
    $names = @("AutoHotkey64.exe", "AutoHotkey.exe")
    foreach ($n in $names) {
        $cmd = Get-Command $n -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    $paths = @(
        "$env:ProgramFiles\AutoHotkey\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:ProgramFiles(x86)\AutoHotkey\AutoHotkeyU64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\AutoHotkey64.exe"
    )
    foreach ($p in $paths) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    return $null
}

$cacheDir = Join-Path $Root "Cache"
if (!(Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
$report = Join-Path $cacheDir "ahk_runtime_diagnose.txt"

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("ahk_runtime_diagnose")
$lines.Add("ts=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')")
$lines.Add("root=$Root")
$lines.Add("pwd=$(Get-Location)")
$lines.Add("user=$env:USERNAME")
$lines.Add("session_name=$env:SESSIONNAME")
$lines.Add("is_user_interactive=$([Environment]::UserInteractive)")
$lines.Add("ps_edition=$($PSVersionTable.PSEdition)")
$lines.Add("ps_version=$($PSVersionTable.PSVersion)")
$lines.Add("os=$([Environment]::OSVersion.VersionString)")

$ahk = Find-AhkExe
if ($null -eq $ahk) {
    $lines.Add("ahk_found=0")
    $lines.Add("result=FAIL")
    Set-Content -LiteralPath $report -Value $lines -Encoding UTF8
    Get-Content -LiteralPath $report -Encoding UTF8
    exit 1
}

$lines.Add("ahk_found=1")
$lines.Add("ahk_path=$ahk")
try {
    $fi = Get-Item -LiteralPath $ahk
    $lines.Add("ahk_length=$($fi.Length)")
    $lines.Add("ahk_lastwrite=$($fi.LastWriteTime)")
} catch {
    $lines.Add("ahk_meta_error=$($_.Exception.Message)")
}

$probeDir = Join-Path $env:TEMP "ahk_diag_probe"
if (!(Test-Path $probeDir)) { New-Item -ItemType Directory -Path $probeDir -Force | Out-Null }
$probeScript = Join-Path $probeDir "probe.ahk"
$probeOut = Join-Path $probeDir "probe_out.txt"
if (Test-Path $probeOut) { Remove-Item -LiteralPath $probeOut -Force -ErrorAction SilentlyContinue }

$ahkCode = @'
#Requires AutoHotkey v2.0
try {
    FileAppend("ok`r`n", A_Temp "\ahk_diag_probe\probe_out.txt", "UTF-8")
} catch as e {
}
ExitApp
'@
Set-Content -LiteralPath $probeScript -Value $ahkCode -Encoding UTF8

try {
    & $ahk $probeScript
    $lines.Add("probe_exit=$LASTEXITCODE")
} catch {
    $lines.Add("probe_exec_error=$($_.Exception.Message)")
}

$probeExists = Test-Path $probeOut
$lines.Add("probe_out_exists=$([int]$probeExists)")
if ($probeExists) {
    try {
        $content = (Get-Content -LiteralPath $probeOut -Encoding UTF8 | Select-Object -First 1)
        $lines.Add("probe_out_first=$content")
    } catch {
        $lines.Add("probe_out_read_error=$($_.Exception.Message)")
    }
}

$proc = Get-Process -Name AutoHotkey64,AutoHotkey,AutoHotkey32 -ErrorAction SilentlyContinue
$lines.Add("ahk_process_count=$(($proc | Measure-Object).Count)")

$result = if ($probeExists) { "PASS" } else { "FAIL" }
$lines.Add("result=$result")
Set-Content -LiteralPath $report -Value $lines -Encoding UTF8
Get-Content -LiteralPath $report -Encoding UTF8
if ($result -eq "PASS") { exit 0 } else { exit 1 }
