param(
    [string]$Root = "",
    [switch]$Confirm,
    [switch]$WhatIf,
    [switch]$RemoveAutoStart
)

foreach ($rel in @("_Resolve.ps1", "ci\_Resolve.ps1", "..\tools\ci\_Resolve.ps1")) {
    $resolvePath = Join-Path $PSScriptRoot $rel
    if (Test-Path -LiteralPath $resolvePath) { . $resolvePath; break }
}
if (-not $Root) { $Root = Nmer-ResolveProjectRoot $PSScriptRoot }

$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logPath = Join-Path $env:TEMP "nmer_clean_uninstall_$stamp.log"

function Write-Log([string]$msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
    if ([Console]::OutputEncoding.WebName -ne "utf-8") {
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    }
    Write-Output $line
    Add-Content -LiteralPath $script:logPath -Value $line -Encoding UTF8
}

function Remove-NmerPath([string]$abs) {
    if (-not (Test-Path -LiteralPath $abs)) { return $true }
    try {
        if ((Get-Item -LiteralPath $abs).PSIsContainer) {
            Get-ChildItem -LiteralPath $abs -Force -ErrorAction SilentlyContinue |
                ForEach-Object {
                    Remove-NmerPath $_.FullName | Out-Null
                }
            Remove-Item -LiteralPath $abs -Force -ErrorAction Stop
        } else {
            Remove-Item -LiteralPath $abs -Force -ErrorAction Stop
        }
        return $true
    } catch {
        Write-Log "WARN: delete failed: $abs ($($_.Exception.Message))"
        return $false
    }
}

$deletable = @(
    "Cache",
    "local\openclaw-state",
    "local\secrets.vault.json",
    "local\user_studio.backup.json",
    "local\niuma_chat_llm.json"
)

$autoStartNames = @("Nmer", "CursorHelper")
$regRun = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

Write-Log "== Nmer CleanUninstall =="
Write-Log "root=$Root confirm=$Confirm whatIf=$WhatIf removeAutoStart=$RemoveAutoStart"

$procs = @("SearchCenterCore", "native-drop-bridge", "ttyd")
foreach ($p in $procs) {
    $running = Get-Process -Name $p -ErrorAction SilentlyContinue
    if ($running) {
        Write-Log "stop process: $p"
        if ($Confirm -and -not $WhatIf) {
            $running | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    }
}

$nmer = Get-Process | Where-Object {
    $_.Path -and $_.Path -match "AutoHotkey" -and
    (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty CommandLine) -match [regex]::Escape($Root)
}
if ($nmer) {
    $n = @($nmer).Count
    Write-Log "WARN: Nmer AutoHotkey still running ($n process(es)); exit tray icon before -Confirm"
}

Write-Log "-- registry autostart (HKCU Run) --"
foreach ($name in $autoStartNames) {
    try {
        $val = (Get-ItemProperty -LiteralPath $regRun -Name $name -ErrorAction SilentlyContinue).$name
        if ($val) {
            Write-Log "autostart FOUND: $name = $val"
            if ($RemoveAutoStart -and $Confirm -and -not $WhatIf) {
                Remove-ItemProperty -LiteralPath $regRun -Name $name -ErrorAction SilentlyContinue
                Write-Log "autostart REMOVED: $name"
            }
        } else {
            Write-Log "autostart absent: $name"
        }
    } catch {
        Write-Log "autostart absent: $name"
    }
}
if ($RemoveAutoStart -and -not $Confirm) {
    Write-Log "NOTE: removing autostart requires -RemoveAutoStart -Confirm"
}

Write-Log "-- filesystem --"
foreach ($rel in $deletable) {
    $abs = Join-Path $Root $rel
    if (-not (Test-Path -LiteralPath $abs)) {
        Write-Log "skip missing: $rel"
        continue
    }
    Write-Log "delete: $rel"
    if ($Confirm -and -not $WhatIf) {
        if (Remove-NmerPath $abs) {
            Write-Log "deleted: $rel"
        }
    }
}

Write-Log "KEPT (default): local\CursorShortcut.ini, local\user_studio.json, Data\, tools\, html\"
Write-Log "OPTIONAL manual: delete entire install folder after above"
Write-Log "DONE log=$logPath"
