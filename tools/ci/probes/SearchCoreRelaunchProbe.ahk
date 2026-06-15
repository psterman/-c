#Requires AutoHotkey v2.0
#Warn All, Off
#SingleInstance Off

#Include _ProbeRoot.ahk
global MainScriptDir := Probe_ResolveProjectRoot()

#Include ..\..\..\modules\FuncExists.ahk
#Include ..\..\..\modules\ToolsPaths.ahk

global g_SCRP_Pass := ""
global g_SCRP_Fail := ""
global g_SCRP_Report := MainScriptDir . "\Cache\searchcore_relaunch_probe_report.txt"

SCRP_Assert(name, cond, detail := "") {
    global g_SCRP_Pass, g_SCRP_Fail
    if cond {
        g_SCRP_Pass .= name . "=1`n"
        if (detail != "")
            g_SCRP_Pass .= name . "_detail=" . detail . "`n"
    } else {
        g_SCRP_Fail .= name . "=0`n"
        if (detail != "")
            g_SCRP_Fail .= name . "_detail=" . detail . "`n"
    }
}

SCRP_EnsureCoreStopped() {
    if ProcessExist("SearchCenterCore.exe") {
        SearchCore_Shutdown("relaunch_probe_cleanup")
        Sleep(400)
    }
}

SCRP_WriteReport(exitCode := 0) {
    global g_SCRP_Pass, g_SCRP_Fail, g_SCRP_Report, MainScriptDir
    dir := MainScriptDir . "\Cache"
    if !DirExist(dir)
        try DirCreate(dir)
    body := "searchcore_relaunch_probe`n"
        . "main_script_dir=" . MainScriptDir . "`n"
        . "ts=" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "`n"
        . g_SCRP_Pass
        . g_SCRP_Fail
        . "fail_count=" . (StrLen(g_SCRP_Fail) > 0 ? "1" : "0") . "`n"
        . "result=" . (StrLen(g_SCRP_Fail) > 0 ? "FAIL" : "PASS") . "`n"
        . "exit_code=" . exitCode . "`n"
    try {
        if FileExist(g_SCRP_Report)
            FileDelete(g_SCRP_Report)
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try FileAppend(body, g_SCRP_Report, "UTF-8")
    catch {
        try FileAppend(body, A_Temp . "\searchcore_relaunch_probe_report.txt", "UTF-8")
    }
}

try {
    exe := Nmer_SearchCenterCoreExe()
    if (exe = "" || !FileExist(exe)) {
        SCRP_Assert("r00_skip_no_exe", true, "SearchCenterCore.exe missing")
    } else {
        SCRP_EnsureCoreStopped()

        st1 := Nmer_StartSearchCenterCoreStatus(false, "relaunch_probe_first")
        status1 := (st1 is Map && st1.Has("status")) ? String(st1["status"]) : "invalid"
        SCRP_Assert("r01_first_start_ok", (status1 = "started" || status1 = "healthy"), status1)

        if (status1 = "started" || status1 = "healthy") {
            SearchCore_Shutdown("relaunch_probe_kill")
            Sleep(350)
            SCRP_Assert("r02_process_gone_after_kill", !ProcessExist("SearchCenterCore.exe"), "")

            inDebounce := false
            global g_Nmer_SearchCoreLastLaunchTick
            if IsSet(g_Nmer_SearchCoreLastLaunchTick) && (A_TickCount - Integer(g_Nmer_SearchCoreLastLaunchTick) < 10000)
                inDebounce := true
            SCRP_Assert("r03_still_in_debounce_window", !!inDebounce, "tick=" . (IsSet(g_Nmer_SearchCoreLastLaunchTick) ? g_Nmer_SearchCoreLastLaunchTick : 0))

            st2 := Nmer_StartSearchCenterCoreStatus(false, "relaunch_probe_second")
            status2 := (st2 is Map && st2.Has("status")) ? String(st2["status"]) : "invalid"
            SCRP_Assert("r04_not_launch_debounced", status2 != "launch_debounced", status2)
            SCRP_Assert("r05_restarted", (status2 = "started" || status2 = "healthy" || status2 = "process_only"), status2)

            if (status2 = "started" || status2 = "process_only") {
                Sleep(600)
                deadline := A_TickCount + 25000
                healthOk := false
                while (A_TickCount < deadline) {
                    if Nmer_SearchCenterCoreHealthy() {
                        healthOk := true
                        break
                    }
                    Sleep(400)
                }
                SCRP_Assert("r06_health_after_relaunch", healthOk, status2)
            }
        }
        SCRP_EnsureCoreStopped()
    }
} catch as e {
    SCRP_Assert("relaunch_probe_unhandled_error", false, e.Message)
}

exitCode := StrLen(g_SCRP_Fail) > 0 ? 1 : 0
SCRP_WriteReport(exitCode)
ExitApp(exitCode)
