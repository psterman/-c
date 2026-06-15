; ===================== msg =====================
#Requires AutoHotkey v2.0
A_MaxHotkeysPerInterval := 400
#Include modules\NmerCatch.ahk
#Include modules\LocalPaths.ahk

NMER_StartupOnError(err, mode) {
    if (mode = "Return")
        return false
    line := 0
    try line := err.Line
    msg := "启动或运行出错：`n" . err.Message
    if (line)
        msg .= "`n`n" . err.File . " (行 " . line . ")"
    errFile := ""
    errWhat := ""
    errStack := ""
    try errFile := err.File
    try errWhat := err.What
    try errStack := err.Stack
    try NMER_Log("startup", "unhandled_error",
        err.Message . " file=" . errFile . " line=" . line . " what=" . errWhat . " stack=" . errStack)
    catch {
        try FileAppend(Format("{} {}\n", A_Now, msg), Nmer_DebugPath("startup_error.log"))
    }
    try MsgBox(msg, "CursorHelper", 0x10)
    return false
}

NMER_Log(scope, event, detail := "") {
    global NMER_TraceSession
    try {
        logPath := Nmer_DebugPath("nmer_trace.log")
        dir := ""
        SplitPath(logPath, , &dir)
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)
        ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        FileAppend("[" . ts . "][" . NMER_TraceSession . "][" . scope . "][" . event . "] " . String(detail) . "`r`n", logPath, "UTF-8")
    } catch as _e {
        try NMER_Log(A_ThisFunc, "catch", _e.Message)
    }
}

OnError(NMER_StartupOnError)
#Include modules\SqlSafe.ahk
global NMER_TraceSession := FormatTime(A_Now, "yyyyMMdd-HHmmss") . "-" . A_TickCount
global pToken := Gdip_Startup()
if (!pToken) {
    MsgBox "GDI+ 启动失败，请检查 lib\ahk\Gdip_All.ahk"
ExitApp()
