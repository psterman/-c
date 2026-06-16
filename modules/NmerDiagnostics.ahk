; NmerDiagnostics.ahk — 诊断包导出、日志入口、用户可见错误对话框
#Requires AutoHotkey v2.0
#Include FuncExists.ahk

global g_NmerErrorDlg_Report := ""
global g_NmerErrorDlg_Gui := 0

NmerDiag_CallOptional(funcName, args*) {
    name := Trim(String(funcName))
    if (name = "")
        return ""
    if !FuncExists(name)
        return ""
    try {
        return (%name%)(args*)
    } catch {
        return ""
    }
}

Nmer_ReadTraceTail(maxLines := 40) {
    maxLines := Max(1, Integer(maxLines))
    path := A_ScriptDir . "\Cache\debug\nmer_trace.log"
    if FuncExists("Nmer_TraceLogPath")
        path := NmerDiag_CallOptional("Nmer_TraceLogPath")
    if !FileExist(path)
        return "(暂无 nmer_trace.log)"
    try {
        raw := FileRead(path, "UTF-8")
        if (raw = "")
            return "(日志为空)"
        lines := StrSplit(raw, "`n", "`r")
        start := lines.Length - maxLines + 1
        if (start < 1)
            start := 1
        out := ""
        loop lines.Length - start + 1 {
            i := start + A_Index - 1
            line := lines[i]
            if (line != "")
                out .= line . "`n"
        }
        return RTrim(out, "`n")
    } catch as e {
        NmerDiag_CallOptional("NmerCatch", A_ThisFunc, e)
        return "(读取日志失败)"
    }
}

Nmer_BuildErrorReport(err, mode := "") {
    line := 0
    file := ""
    what := ""
    stack := ""
    msg := ""
    try msg := err.Message
    catch {
        msg := String(err)
    }
    try line := err.Line
    catch {
    }
    try file := err.File
    catch {
    }
    try what := err.What
    catch {
    }
    try stack := err.Stack
    catch {
    }

    session := ""
    if IsSet(NMER_TraceSession)
        session := NMER_TraceSession

    summary := msg
    if (file != "")
        summary .= "`n`n" . file . (line ? " (行 " . line . ")" : "")

    full := "【牛马错误报告】`n"
    full .= "时间: " . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . "`n"
    full .= "会话: " . session . "`n"
    full .= "AHK: " . A_AhkVersion . "`n"
    if (mode != "")
        full .= "模式: " . mode . "`n"
    full .= "`n--- 错误 ---`n" . msg . "`n"
    if (file != "")
        full .= "文件: " . file . "`n"
    if (line)
        full .= "行号: " . line . "`n"
    if (what != "")
        full .= "What: " . what . "`n"
    if (stack != "")
        full .= "`n--- Stack ---`n" . stack . "`n"
    full .= "`n--- 最近日志 (nmer_trace.log) ---`n" . Nmer_ReadTraceTail(35)

    global g_NmerErrorDlg_Report
    g_NmerErrorDlg_Report := full
    return Map("summary", summary, "full", full)
}

Nmer_ErrorDlg_OnCopy(*) {
    global g_NmerErrorDlg_Report
    if (g_NmerErrorDlg_Report = "")
        return
    A_Clipboard := g_NmerErrorDlg_Report
    try TrayTip("牛马", "错误报告已复制到剪贴板", "Iconi 2")
    catch {
        ToolTip("已复制")
        SetTimer(() => ToolTip(), -1200)
    }
}

Nmer_ErrorDlg_OnClose(guiObj, *) {
    if IsObject(guiObj)
        try guiObj.Destroy()
    global g_NmerErrorDlg_Gui
    g_NmerErrorDlg_Gui := 0
}

Nmer_ShowUserErrorDialog(err, mode := "") {
    rep := Nmer_BuildErrorReport(err, mode)
    body := rep.Has("full") ? rep["full"] : rep.Get("summary", "")

    global g_NmerErrorDlg_Gui
    if g_NmerErrorDlg_Gui {
        try g_NmerErrorDlg_Gui.Destroy()
        catch {
        }
    }

    g := Gui("+AlwaysOnTop", "牛马 — 运行出错")
    g.SetFont("s9", "Microsoft YaHei UI")
    g.MarginX := 14
    g.MarginY := 12
    g.Add("Text", "w560", "程序遇到错误，详情已写入 Cache\debug\nmer_trace.log。可复制报告或导出诊断包发给开发者。")
    g.Add("Edit", "w560 h210 ReadOnly -Wrap vNmerErrEdit", body)
    g.Add("Button", "Default w130", "复制报告").OnEvent("Click", Nmer_ErrorDlg_OnCopy)
    g.Add("Button", "x+10 w130", "打开日志目录").OnEvent("Click", (*) => Nmer_OpenLogsFolder())
    g.Add("Button", "x+10 w130", "导出诊断包").OnEvent("Click", (*) => Nmer_ExportDiagnosticsBundle())
    g.Add("Button", "x+10 w72", "关闭").OnEvent("Click", Nmer_ErrorDlg_OnClose.Bind(g))
    g.OnEvent("Close", Nmer_ErrorDlg_OnClose.Bind(g))
    g.Show()
    g_NmerErrorDlg_Gui := g
    try WinWaitClose(g.Hwnd)
    catch {
    }
}

Nmer_CopyRecentTraceToClipboard(maxLines := 60) {
    text := Nmer_ReadTraceTail(maxLines)
    if (text = "" || InStr(text, "(暂无") || InStr(text, "(读取"))
        return ""
    A_Clipboard := text
    NmerDiag_CallOptional("NMER_Log", "diagnostics", "copy_trace_clipboard", "lines=" . maxLines)
    return text
}

Nmer_ExportDiagnosticsBundle(*) {
    if FuncExists("Nmer_CollectHealthSnapshot") {
        try NmerDiag_CallOptional("Nmer_CollectHealthSnapshot", "export_bundle")
        catch as _e0 {
            NmerDiag_CallOptional("NmerCatch", A_ThisFunc, _e0)
        }
    }
    root := A_ScriptDir
    if FuncExists("Nmer_CacheDir")
        cacheRoot := NmerDiag_CallOptional("Nmer_CacheDir")
    else
        cacheRoot := root . "\Cache"
    stamp := FormatTime(A_Now, "yyyyMMdd_HHmmss")
    outDir := cacheRoot . "\diagnostics_export_" . stamp
    try DirCreate(outDir)
    catch as _e {
        NmerDiag_CallOptional("NmerCatch", A_ThisFunc, _e)
        try TrayTip("牛马", "无法创建诊断目录", "Iconx 2")
        return false
    }

    copied := 0
    patterns := [
        Map("src", cacheRoot . "\debug", "glob", "*.*"),
        Map("src", cacheRoot . "\ci", "glob", "*.txt"),
        Map("src", cacheRoot . "\debug", "glob", "searchcore_*.jsonl"),
        Map("src", cacheRoot . "\debug", "glob", "searchcore_launch.log")
    ]
    for spec in patterns {
        srcDir := spec["src"]
        if !DirExist(srcDir)
            continue
        try {
            Loop Files, srcDir . "\" . spec["glob"], "F" {
                dest := outDir . "\" . A_LoopFileName
                try {
                    FileCopy(A_LoopFileFullPath, dest, true)
                    copied += 1
                } catch as _e2 {
                    NmerDiag_CallOptional("NmerCatch", A_ThisFunc, _e2)
                }
            }
        } catch as _e3 {
            NmerDiag_CallOptional("NmerCatch", A_ThisFunc, _e3)
        }
    }

    collectPs1 := A_ScriptDir . "\tools\ci\Collect-SearchCoreLogs.ps1"
    if FileExist(collectPs1) {
        try {
            Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' . collectPs1 . '" -OutDir "' . outDir . '"', , "Hide")
            copied += 1
        } catch as _e7 {
            NmerDiag_CallOptional("NmerCatch", A_ThisFunc, _e7)
        }
    }

    manifest := "exported=" . copied . "`nroot=" . root . "`nstamp=" . stamp . "`n"
    try FileAppend(manifest, outDir . "\manifest.txt", "UTF-8")
    catch as _e4 {
        NmerDiag_CallOptional("NmerCatch", A_ThisFunc, _e4)
    }

    NmerDiag_CallOptional("NMER_Log", "diagnostics", "export_bundle", "dir=" . outDir . " files=" . copied)

    msg := "已导出 " . copied . " 个文件到`n" . outDir
    try TrayTip("诊断包", msg, "Iconi 3")
    catch as _e5 {
        NmerDiag_CallOptional("NmerCatch", A_ThisFunc, _e5)
    }
    try Run('explorer.exe /select,"' . outDir . '"')
    catch as _e6 {
        NmerDiag_CallOptional("NmerCatch", A_ThisFunc, _e6)
    }
    return true
}

Nmer_OpenLogsFolder(*) {
    if FuncExists("Nmer_OpenDebugDir")
        return NmerDiag_CallOptional("Nmer_OpenDebugDir")
    return false
}
