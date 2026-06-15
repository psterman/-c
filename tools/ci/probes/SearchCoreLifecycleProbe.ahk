#Requires AutoHotkey v2.0
#Warn All, Off
#SingleInstance Off

#Include _ProbeRoot.ahk
global MainScriptDir := Probe_ResolveProjectRoot()

#Include ..\..\..\modules\FuncExists.ahk
#Include ..\..\..\modules\ToolsPaths.ahk

global g_SCLP_Pass := ""
global g_SCLP_Fail := ""
global g_SCLP_Report := MainScriptDir . "\Cache\searchcore_lifecycle_probe_report.txt"
global g_SCLP_Jsonl := MainScriptDir . "\Cache\debug\searchcore_lifecycle.jsonl"

SCLP_Assert(name, cond, detail := "") {
    global g_SCLP_Pass, g_SCLP_Fail
    if cond {
        g_SCLP_Pass .= name . "=1`n"
        if (detail != "")
            g_SCLP_Pass .= name . "_detail=" . detail . "`n"
    } else {
        g_SCLP_Fail .= name . "=0`n"
        if (detail != "")
            g_SCLP_Fail .= name . "_detail=" . detail . "`n"
    }
}

SCLP_CountJsonlLines() {
    global g_SCLP_Jsonl
    if !FileExist(g_SCLP_Jsonl)
        return 0
    n := 0
    try {
        f := FileOpen(g_SCLP_Jsonl, "r", "UTF-8")
        if !IsObject(f)
            return 0
        while !f.AtEOF {
            line := Trim(f.ReadLine())
            if (line != "")
                n += 1
        }
        f.Close()
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return n
}

SCLP_JsonlHasEvent(eventName, sinceLine := 0) {
    global g_SCLP_Jsonl
    if !FileExist(g_SCLP_Jsonl)
        return false
    lineNo := 0
    try {
        f := FileOpen(g_SCLP_Jsonl, "r", "UTF-8")
        if !IsObject(f)
            return false
        while !f.AtEOF {
            line := f.ReadLine()
            lineNo += 1
            if (lineNo <= sinceLine)
                continue
            if InStr(line, '"event":"' . eventName . '"')
                return true
        }
        f.Close()
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return false
}

SCLP_EnsureCoreStopped() {
    if ProcessExist("SearchCenterCore.exe") {
        SearchCore_Shutdown("probe_cleanup")
        Sleep(500)
    }
}

SCLP_WriteReport(exitCode := 0) {
    global g_SCLP_Pass, g_SCLP_Fail, g_SCLP_Report, MainScriptDir
    dir := MainScriptDir . "\Cache"
    if !DirExist(dir)
        try DirCreate(dir)
    body := "searchcore_lifecycle_probe`n"
        . "main_script_dir=" . MainScriptDir . "`n"
        . "ts=" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "`n"
        . g_SCLP_Pass
        . g_SCLP_Fail
        . "fail_count=" . (StrLen(g_SCLP_Fail) > 0 ? "1" : "0") . "`n"
        . "result=" . (StrLen(g_SCLP_Fail) > 0 ? "FAIL" : "PASS") . "`n"
        . "exit_code=" . exitCode . "`n"
    try {
        if FileExist(g_SCLP_Report)
            FileDelete(g_SCLP_Report)
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    ok := false
    try {
        FileAppend(body, g_SCLP_Report, "UTF-8")
        ok := FileExist(g_SCLP_Report)
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if !ok {
        try FileAppend(body, A_Temp . "\searchcore_lifecycle_probe_report.txt", "UTF-8")
    }
}

try {
    ; --- T01/T04: Status API + bool wrapper when core absent ---
    SCLP_EnsureCoreStopped()
    jsonlStart := SCLP_CountJsonlLines()
    st := Nmer_StartSearchCenterCoreStatus(false, "lifecycle_probe")
    status := (st is Map && st.Has("status")) ? String(st["status"]) : "invalid"
    SCLP_Assert("t01_status_map", st is Map, status)
    SCLP_Assert("t01_status_started_or_debounced_or_failed",
        (status = "started" || status = "launch_debounced" || status = "failed" || status = "healthy" || status = "process_only"),
        status)
    if (status = "started")
        SCLP_Assert("t01_jsonl_start_run", SCLP_JsonlHasEvent("start_run", jsonlStart), status)

    boolRet := Nmer_StartSearchCenterCore(false)
    if (status = "process_only")
        SCLP_Assert("t04_bool_false_on_process_only", !boolRet, "wrapper=" . (boolRet ? "true" : "false"))
    else if (status = "launch_debounced" || status = "failed")
        SCLP_Assert("t04_bool_false_on_non_success", !boolRet, status)
    else if (status = "started" || status = "healthy")
        SCLP_Assert("t04_bool_true_on_started_or_healthy", !!boolRet, status)

    ; --- T05/T06: Shutdown JSONL ---
    if ProcessExist("SearchCenterCore.exe") {
        since := SCLP_CountJsonlLines()
        ok := SearchCore_Shutdown("probe_test_shutdown")
        SCLP_Assert("t05_shutdown_returns", !!ok, "")
        SCLP_Assert("t05_shutdown_requested_logged", SCLP_JsonlHasEvent("shutdown_requested", since), "")
        SCLP_Assert("t05_shutdown_done_logged", SCLP_JsonlHasEvent("shutdown_done", since), "")
        SCLP_Assert("t05_process_gone", !ProcessExist("SearchCenterCore.exe"), "")
    } else {
        since := SCLP_CountJsonlLines()
        ok2 := SearchCore_Shutdown("probe_test_not_running")
        SCLP_Assert("t06_shutdown_not_running_ok", !!ok2, "")
        SCLP_Assert("t06_shutdown_done_logged", SCLP_JsonlHasEvent("shutdown_done", since), "")
    }

    ; --- T02/T03: process_present semantics (if exe exists) ---
    exe := Nmer_SearchCenterCoreExe()
    if (exe != "" && FileExist(exe)) {
        SCLP_EnsureCoreStopped()
        try Run('"' exe '" -base "' MainScriptDir '"', MainScriptDir, "Hide")
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        if !ProcessExist("SearchCenterCore.exe") {
            SCLP_Assert("t02_skip_no_process", true, "run_failed")
        } else {
            deadline := A_TickCount + 15000
            healthOk := false
            while (A_TickCount < deadline) {
                if Nmer_SearchCenterCoreHealthy() {
                    healthOk := true
                    break
                }
                Sleep(400)
            }
            st2 := Nmer_StartSearchCenterCoreStatus(false, "lifecycle_probe_health")
            status2 := (st2 is Map && st2.Has("status")) ? String(st2["status"]) : "invalid"
            if healthOk {
                SCLP_Assert("t02_healthy_when_health_ok", status2 = "healthy", status2)
                SCLP_Assert("t02_bool_true_when_healthy", !!Nmer_StartSearchCenterCore(false), status2)
            } else {
                SCLP_Assert("t03_process_only_when_health_fail", status2 = "process_only", status2)
                SCLP_Assert("t03_bool_false_when_process_only", !Nmer_StartSearchCenterCore(false), status2)
            }
        }
        SCLP_EnsureCoreStopped()
    } else {
        SCLP_Assert("t02_skip_no_exe", true, "SearchCenterCore.exe missing")
    }
} catch as e {
    SCLP_Assert("probe_unhandled_error", false, e.Message)
}

exitCode := StrLen(g_SCLP_Fail) > 0 ? 1 : 0
SCLP_WriteReport(exitCode)
ExitApp(exitCode)
