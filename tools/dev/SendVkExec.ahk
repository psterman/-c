#Requires AutoHotkey v2.0
#SingleInstance Force

DetectHiddenWindows true

if (A_Args.Length < 1) {
    ExitApp(2)
}
cmdId := Trim(String(A_Args[1]))
if (cmdId = "") {
    ExitApp(2)
}

VkExecQueue_Append(cmdId) {
    cid := Trim(String(cmdId))
    if (cid = "")
        return false
    root := A_ScriptDir . "\..\.."
    dir := root . "\Cache\ci"
    path := dir . "\vkexec_queue.jsonl"
    try DirCreate(dir)
    s := StrReplace(cid, "\", "\\")
    s := StrReplace(s, '"', '\"')
    line := '{"cmdId":"' . s . '","queuedAt":"' . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . '"}' . "`n"
    try {
        FileAppend(line, path, "UTF-8")
        return true
    } catch {
        return false
    }
}

targets := []
for hwnd in WinGetList("ahk_class AutoHotkey") {
    title := ""
    try title := WinGetTitle("ahk_id " . hwnd)
    if (InStr(title, "\牛马.ahk") || InStr(title, "/牛马.ahk") || InStr(title, "牛马.ahk")
        || InStr(title, "\nmer_main_debug.ahk") || InStr(title, "/nmer_main_debug.ahk") || InStr(title, "nmer_main_debug.ahk"))
        targets.Push(hwnd)
}
if (targets.Length = 0)
    ExitApp(3)

if (targets.Length > 1)
    targets := [targets[targets.Length]]

json := '{"type":"vkExec","cmdId":"' . StrReplace(cmdId, '"', '\"') . '"}'
payloadWithNull := StrPut(json, "UTF-8")
payloadBytes := payloadWithNull - 1
buf := Buffer(payloadWithNull, 0)
StrPut(json, buf, "UTF-8")

if (A_PtrSize = 8) {
    cds := Buffer(24, 0)
    NumPut("UInt64", 1, cds, 0)
    NumPut("UInt", payloadBytes, cds, 8)
    NumPut("Ptr", buf.Ptr, cds, 16)
} else {
    cds := Buffer(12, 0)
    NumPut("UInt", 1, cds, 0)
    NumPut("UInt", payloadBytes, cds, 4)
    NumPut("Ptr", buf.Ptr, cds, 8)
}

timeoutMs := 2000
if (cmdId = "telemetry_export_diagnostics" || cmdId = "telemetry_migration_chain"
    || cmdId = "telemetry_migration_export" || cmdId = "telemetry_migration_preview"
    || cmdId = "telemetry_migration_import" || cmdId = "telemetry_surface_fill_probe")
    timeoutMs := 3000
else if (SubStr(cmdId, 1, 3) = "qa_")
    timeoutMs := 2500

ok := false
for hwnd in targets {
    reply := 0
    sent := DllCall(
        "SendMessageTimeoutW",
        "ptr", hwnd,
        "uint", 0x4A,
        "ptr", 0,
        "ptr", cds.Ptr,
        "uint", 0x2,
        "uint", timeoutMs,
        "ptr*", &reply,
        "ptr"
    )
    if (sent != 0 && reply != 0) {
        ok := true
        break
    }
}
if ok
    ExitApp(0)

if VkExecQueue_Append(cmdId)
    ExitApp(0)

ExitApp(4)
