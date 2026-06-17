#Requires AutoHotkey v2.0
cmdId := A_Args.Length ? A_Args[1] : "telemetry_reset_surface_schedule"
targets := []
for hwnd in WinGetList("ahk_class AutoHotkey") {
    title := ""
    try title := WinGetTitle("ahk_id " . hwnd)
    if (InStr(title, "牛马.ahk"))
        targets.Push(hwnd)
}
if (targets.Length = 0)
    ExitApp(3)
if (targets.Length > 1)
    targets := [targets[targets.Length]]
json := '{"type":"vkExec","cmdId":"' . cmdId . '"}'
buf := Buffer(StrPut(json, "UTF-8"), 0)
StrPut(json, buf, "UTF-8")
payloadBytes := StrPut(json, "UTF-8") - 1
cds := Buffer(24, 0)
NumPut("UInt64", 1, cds, 0)
NumPut("UInt", payloadBytes, cds, 8)
NumPut("Ptr", buf.Ptr, cds, 16)
reply := 0
sent := DllCall("SendMessageTimeoutW", "ptr", targets[1], "uint", 0x4A, "ptr", 0, "ptr", cds.Ptr, "uint", 0x2, "uint", 30000, "ptr*", &reply, "ptr")
FileAppend("hwnd=" targets[1] " sent=" sent " reply=" reply "`n", A_ScriptDir . "\..\..\Cache\debug\vkexec_send_probe.txt")
ExitApp((sent != 0 && reply != 0) ? 0 : 4)
