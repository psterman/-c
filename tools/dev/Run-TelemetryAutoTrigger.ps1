param(
    [string]$Root = "",
    [int]$WaitSec = 10,
    [int]$PollSec = 120
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

. (Join-Path $PSScriptRoot "_TelemetryRequiredChecks.ps1")

$sender = Join-Path $PSScriptRoot "SendVkExec.ahk"
if (-not (Test-Path -LiteralPath $sender)) {
    Write-Output "[FAIL] missing sender: $sender"
    exit 1
}

function Resolve-AhkExe {
    $candidates = @(
        "AutoHotkey64.exe",
        "AutoHotkey.exe",
        "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe",
        "C:\Program Files\AutoHotkey\AutoHotkey64.exe",
        "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe"
    )
    foreach ($c in $candidates) {
        $cmd = Get-Command $c -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) { return $cmd.Source }
        if (Test-Path -LiteralPath $c) { return $c }
    }
    return $null
}

function Wait-VkExecQueueEmpty {
    param(
        [string]$RootPath,
        [int]$TimeoutSec = 90
    )
    $q = Join-Path $RootPath "Cache\ci\vkexec_queue.jsonl"
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (-not (Test-Path -LiteralPath $q)) {
            return $true
        }
        try {
            $raw = Get-Content -LiteralPath $q -Raw -Encoding UTF8 -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($raw)) {
                return $true
            }
        } catch {
            return $true
        }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Invoke-VkExec {
    param(
        [string]$CmdId,
        [int]$PauseMs = 400,
        [int]$Retries = 3
    )
    $code = 4
    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        $p = Start-Process -FilePath $ahkExe -ArgumentList "`"$sender`"", $CmdId -Wait -PassThru -NoNewWindow
        $code = $p.ExitCode
        if ($code -eq 0 -or $code -eq 3) {
            break
        }
        if ($attempt -lt $Retries) {
            Start-Sleep -Milliseconds 1200
        }
    }
    if ($code -eq 0) {
        $script:ok += 1
        Write-Output "[PASS] vkExec.$CmdId"
    } else {
        $script:fail += 1
        $hint = switch ($code) {
            3 { "main script not found" }
            4 { "main script timeout/busy" }
            default { "exit=$code" }
        }
        Write-Output "[FAIL] vkExec.$CmdId -- $hint"
    }
    if ($PauseMs -gt 0) {
        Start-Sleep -Milliseconds $PauseMs
    }
    $script:LastVkExit = $code
}

$ahkExe = Resolve-AhkExe
if (-not $ahkExe) {
    Write-Output "[FAIL] AutoHotkey executable not found"
    exit 1
}

$telemetryPath = Join-Path $Root "Cache\debug\nmer_telemetry.json"

$ok = 0
$fail = 0
$script:LastVkExit = 0
Write-Output "== Telemetry Auto Trigger =="
Write-Output "root=$Root"
Write-Output "ahkExe=$ahkExe"
Write-Output "waitSec=$WaitSec"
Write-Output "pollSec=$PollSec"

Invoke-VkExec -CmdId "telemetry_reset_surface_schedule" -PauseMs 200 -Retries 5
if ($script:LastVkExit -eq 3) {
    Write-Output "[FAIL] 牛马.ahk 主进程未运行，请先启动或重载 牛马.ahk"
    exit 2
}

$pairs = @(
    @("qa_config_open", "qa_config_close", 1400, 1100),
    @("qa_search_center_open", "qa_search_center_close", 1400, 1100),
    @("qa_clipboard_open", "qa_clipboard_close", 1600, 1200),
    @("qa_command_palette", "qa_command_palette_close", 1400, 1100),
    @("qa_prompt_quick_pad", "qa_prompt_quick_pad_close", 1400, 1100),
    @("qa_chord_pad_open", "qa_chord_pad_close", 1400, 1100)
)
foreach ($pair in $pairs) {
    Invoke-VkExec -CmdId $pair[0] -PauseMs $pair[2]
    Invoke-VkExec -CmdId $pair[1] -PauseMs $pair[3]
}

Invoke-VkExec -CmdId "gk_toolbar_show" -PauseMs 800
Invoke-VkExec -CmdId "tray_hide_toolbar" -PauseMs 800
Invoke-VkExec -CmdId "telemetry_health_snapshot" -PauseMs 400
Invoke-VkExec -CmdId "telemetry_chord_cmd_probe" -PauseMs 400
Invoke-VkExec -CmdId "telemetry_copy_trace_probe" -PauseMs 400
Invoke-VkExec -CmdId "telemetry_llm_send_probe" -PauseMs 400

Write-Output "surface_timer_grace_sec=5"
Start-Sleep -Seconds 5

Invoke-VkExec -CmdId "telemetry_surface_fill_probe" -PauseMs 400
Invoke-VkExec -CmdId "telemetry_migration_chain" -PauseMs 400
Invoke-VkExec -CmdId "telemetry_export_diagnostics" -PauseMs 400

Write-Output "summary pass=$ok fail=$fail total=$($ok + $fail)"
if ($fail -gt 0) { exit 1 }

Write-Output "wait_vkexec_queue_sec=90"
$queueOk = Wait-VkExecQueueEmpty -RootPath $Root -TimeoutSec 90
if ($queueOk) {
    Write-Output "[PASS] vkexec_queue_drained"
} else {
    Write-Output "[WARN] vkexec_queue_timeout"
}

Invoke-VkExec -CmdId "telemetry_queue_drain" -PauseMs 300
Invoke-VkExec -CmdId "telemetry_required_fill" -PauseMs 500

if ($WaitSec -gt 0) {
    Write-Output "initial_wait_sec=$WaitSec"
    Start-Sleep -Seconds $WaitSec
}

$pollOk = Wait-TelemetryRequiredReady -TelemetryPath $telemetryPath -PollSec $PollSec
if (-not $pollOk) { exit 1 }
exit 0
