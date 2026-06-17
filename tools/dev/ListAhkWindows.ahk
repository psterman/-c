#Requires AutoHotkey v2.0
#SingleInstance Force
DetectHiddenWindows true
out := A_ScriptDir . "\..\..\Cache\debug\ahk_windows_list.txt"
lines := ""
for hwnd in WinGetList("ahk_class AutoHotkey") {
    try title := WinGetTitle("ahk_id " . hwnd)
    catch
        title := ""
    try path := WinGetProcessPath("ahk_id " . hwnd)
    catch
        path := ""
    lines .= hwnd . "`t" . title . "`t" . path . "`n"
}
try FileDelete(out)
FileAppend(lines, out, "UTF-8")
ExitApp(0)
