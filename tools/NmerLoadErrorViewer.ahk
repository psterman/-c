; NmerLoadErrorViewer.ahk — 独立加载错误展示（校验子进程或冷启动失败时）
#Requires AutoHotkey v2.0
#Include ..\modules\FuncExists.ahk
#Include ..\modules\LocalPaths.ahk
#Include ..\modules\NmerDiagnostics.ahk

if !Trim(EnvGet("NMRE_ROOT"))
    EnvSet("NMRE_ROOT", A_ScriptDir . "\..")

payloadFile := A_Temp . "\nmer_load_error.txt"
metaFile := A_Temp . "\nmer_load_error_meta.txt"
errText := ""
scriptPath := ""
scene := "startup"

if FileExist(payloadFile) {
    try errText := FileRead(payloadFile, "UTF-8")
    catch {
    }
}
if FileExist(metaFile) {
    try {
        meta := StrSplit(FileRead(metaFile, "UTF-8"), "`n", "`r")
        if (meta.Length >= 1)
            scriptPath := Trim(meta[1])
        if (meta.Length >= 2 && Trim(meta[2]) != "")
            scene := Trim(meta[2])
    } catch {
    }
}

if (errText = "" && A_Args.Length >= 1)
    errText := A_Args[1]
if (scriptPath = "" && A_Args.Length >= 2)
    scriptPath := A_Args[2]
if (A_Args.Length >= 3 && Trim(A_Args[3]) != "")
    scene := Trim(A_Args[3])

if (errText = "") {
    MsgBox("未收到加载错误内容。", "牛马 — 脚本无法加载", 0x10)
    ExitApp(1)
}

Nmer_ShowLoadErrorDialog(errText, scriptPath, scene)
