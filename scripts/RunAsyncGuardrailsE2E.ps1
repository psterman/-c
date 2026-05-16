param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int]$StressTotal = 600,
    [int]$StressTimeoutMs = 180000
)

$ErrorActionPreference = "Stop"

function Find-AhkExe {
    $candidates = @("AutoHotkey64.exe", "AutoHotkey.exe")
    foreach ($name in $candidates) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
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

function Read-AhkChoice {
    param([string]$RootPath)
    $p = Join-Path $RootPath "Cache\ahk_launch_choice.txt"
    if (!(Test-Path $p)) { return $null }
    $m = @{}
    foreach ($line in (Get-Content -LiteralPath $p -Encoding UTF8)) {
        if ($line -match "=") {
            $kv = $line.Split("=", 2)
            $m[$kv[0].Trim()] = $kv[1].Trim()
        }
    }
    if ($m.ContainsKey("exe") -and $m.ContainsKey("mode")) {
        return [pscustomobject]@{ Exe = $m["exe"]; Mode = $m["mode"] }
    }
    return $null
}

function Invoke-AhkScript {
    param(
        [string]$Exe,
        [string]$ScriptPath,
        [string]$Mode = "plain",
        [string[]]$ExtraArgs = @()
    )
    $scriptDir = Split-Path -Parent $ScriptPath
    $args = @()
    switch ($Mode) {
        "errorstdout" { $args = @("/ErrorStdOut", $ScriptPath) + $ExtraArgs }
        "errorstdout_with_cwd" { $args = @("/ErrorStdOut", $ScriptPath) + $ExtraArgs }
        default { $args = @($ScriptPath) + $ExtraArgs }
    }
    if ($Mode -like "*with_cwd") {
        Push-Location $scriptDir
        try { & $Exe @args } finally { Pop-Location }
    } else {
        & $Exe @args
    }
    return $LASTEXITCODE
}

$stressScript = Join-Path $Root "scripts\CoreAsyncHttpStress.ahk"
$validator = Join-Path $Root "scripts\ValidateAsyncGuardrails.ps1"
$diagnoser = Join-Path $Root "scripts\DiagnoseAhkRuntime.ps1"

Write-Output "== Async Guardrails E2E =="
Write-Output "root=$Root"

$ahk = Find-AhkExe
$choice = Read-AhkChoice -RootPath $Root
if ($null -eq $ahk) {
    Write-Output "ahk_found=0"
    Write-Output "stress_run=SKIP"
    Write-Output "hint=Install AutoHotkey v2 and ensure AutoHotkey64.exe is in PATH."
    & powershell -ExecutionPolicy Bypass -File $validator -Root $Root
    Write-Output "run_diagnose=1"
    & powershell -ExecutionPolicy Bypass -File $diagnoser -Root $Root
    exit $LASTEXITCODE
}

if ($choice -and (Test-Path $choice.Exe)) {
    $ahk = $choice.Exe
    $launchMode = $choice.Mode
    Write-Output "ahk_choice_used=1"
} else {
    $launchMode = "plain"
    Write-Output "ahk_choice_used=0"
}

Write-Output "ahk_found=1"
Write-Output "ahk_path=$ahk"
Write-Output "ahk_mode=$launchMode"
$stressExit = Invoke-AhkScript -Exe $ahk -ScriptPath $stressScript -Mode $launchMode -ExtraArgs @("$StressTotal", "$StressTimeoutMs")
Write-Output "stress_exit=$stressExit"

& powershell -ExecutionPolicy Bypass -File $validator -Root $Root
$valExit = $LASTEXITCODE
Write-Output "validate_exit=$valExit"
if ($valExit -ne 0) {
    Write-Output "run_diagnose=1"
    & powershell -ExecutionPolicy Bypass -File $diagnoser -Root $Root
}
exit $valExit
