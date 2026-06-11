# Send CapsLock chords to niuma (CP double-tap, Esc, hold-CapsLock+F for SC)
param(
    [int]$Rounds = 10,
    [int]$PauseMs = 600
)

$ErrorActionPreference = "Stop"
$typeName = "NmerHybridUiKeys"
if (-not ([System.Management.Automation.PSTypeName]$typeName).Type) {
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class NmerHybridUiKeys {
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
    const byte VK_CAPITAL = 0x14;
    const byte VK_ESCAPE = 0x1B;
    const byte VK_F = 0x46;
    const uint KEYEVENTF_KEYUP = 0x0002;
    public static void Tap(byte vk, int holdMs = 45) {
        keybd_event(vk, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(holdMs);
        keybd_event(vk, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }
    public static void CapsDoubleTap(int gapMs = 140) {
        Tap(VK_CAPITAL, 40);
        System.Threading.Thread.Sleep(gapMs);
        Tap(VK_CAPITAL, 40);
    }
    public static void CapsHoldChordF() {
        keybd_event(VK_CAPITAL, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(280);
        keybd_event(VK_F, 0, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(45);
        keybd_event(VK_F, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
        System.Threading.Thread.Sleep(120);
        keybd_event(VK_CAPITAL, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }
}
"@
}

$sec = [math]::Ceiling($Rounds * ($PauseMs * 4 + 900) / 1000)
Write-Host "UI keys: $Rounds rounds (focus desktop; hands off keyboard ~${sec}s)" -ForegroundColor Yellow
Start-Sleep -Seconds 2
for ($i = 1; $i -le $Rounds; $i++) {
    Write-Host "  round $i/$Rounds"
    [NmerHybridUiKeys]::CapsDoubleTap(150)
    Start-Sleep -Milliseconds ($PauseMs + 200)
    [NmerHybridUiKeys]::Tap(0x1B)
    Start-Sleep -Milliseconds ($PauseMs + 300)
    [NmerHybridUiKeys]::CapsHoldChordF()
    Start-Sleep -Milliseconds ($PauseMs + 400)
    [NmerHybridUiKeys]::Tap(0x1B)
    Start-Sleep -Milliseconds $PauseMs
}
