; SearchCoreLifecycle.ahk — SearchCenterCore 进程生命周期（由 ToolsPaths 在路径/健康探针之后 #Include）

SearchCore_LifecycleJsonEscape(s) {
    s := StrReplace(String(s), "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\r")
    return s
}

SearchCore_LifecycleJsonValue(v) {
    if (v is Integer || v is Float)
        return String(v)
    if (v = true)
        return "true"
    if (v = false)
        return "false"
    return '"' . SearchCore_LifecycleJsonEscape(v) . '"'
}

SearchCore_LifecycleLogJson(event, fields := 0) {
    try {
        dir := Nmer_InstallRoot() . "\Cache\debug"
        if !DirExist(dir)
            DirCreate(dir)
        ts := FormatTime(, "yyyy-MM-dd HH:mm:ss.fff")
        line := "{" . SearchCore_LifecycleJsonValue("ts") . ":" . SearchCore_LifecycleJsonValue(ts)
            . "," . SearchCore_LifecycleJsonValue("event") . ":" . SearchCore_LifecycleJsonValue(String(event))
        if (fields is Map) {
            for k, v in fields
                line .= "," . SearchCore_LifecycleJsonValue(String(k)) . ":" . SearchCore_LifecycleJsonValue(v)
        }
        line .= "}`n"
        FileAppend(line, dir . "\searchcore_lifecycle.jsonl", "UTF-8")
    } catch as e {
        try Nmer_SearchCoreLog("lifecycle_json_fail " . e.Message)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
}

SearchCore_Shutdown(reason := "") {
    reason := Trim(String(reason))
    if (reason = "")
        reason := "unspecified"
    pid := ProcessExist("SearchCenterCore.exe")
    SearchCore_LifecycleLogJson("shutdown_requested", Map("reason", reason, "pid", pid ? pid : 0))
    if !pid {
        SearchCore_LifecycleLogJson("shutdown_done", Map("reason", reason, "pid", 0, "note", "not_running"))
        return true
    }
    try {
        ProcessClose("SearchCenterCore.exe")
        SearchCore_LifecycleLogJson("shutdown_done", Map("reason", reason, "pid", pid))
        Sleep(350)
        return true
    } catch as err {
        SearchCore_LifecycleLogJson("shutdown_failed", Map("reason", reason, "pid", pid, "error", err.Message))
        return false
    }
}

SearchCore_ProcessPresent(*) {
    return ProcessExist("SearchCenterCore.exe") ? true : false
}

SearchCore_IsHealthy(*) {
    return Nmer_SearchCenterCoreHealthy()
}

; HTTP/全文路径：仅 healthy 或刚启动（started）；process_only 不算 ready
SearchCore_StatusHttpReady(st) {
    if !(st is Map)
        return false
    if st.Has("healthOk") && st["healthOk"]
        return true
    status := st.Has("status") ? String(st["status"]) : ""
    return (status = "healthy" || status = "started")
}

SearchCore_EnsureHttpReady(caller := "http") {
    st := SearchCore_EnsureStatus(false, caller)
    if SearchCore_StatusHttpReady(st)
        return true
    status := (st is Map && st.Has("status")) ? String(st["status"]) : ""
    if (status = "process_only" && FuncExists("SearchCore_ForceRestart")) {
        st2 := SearchCore_ForceRestart(caller . "_process_only")
        return SearchCore_StatusHttpReady(st2)
    }
    return false
}

SearchCore_EnsureStatus(forceRestart := false, caller := "") {
    return Nmer_StartSearchCenterCoreStatus(forceRestart, caller)
}

SearchCore_EnsureHealthy(caller := "ensure") {
    st := Nmer_StartSearchCenterCoreStatus(false, caller)
    if !(st is Map)
        return false
    if st.Has("healthOk") && st["healthOk"]
        return true
    status := st.Has("status") ? String(st["status"]) : "failed"
    return (status = "healthy" || status = "started")
}

SearchCore_ForceRestart(caller := "force_restart") {
    st := Nmer_StartSearchCenterCoreStatus(true, caller)
    if !(st is Map)
        return Map("status", "failed", "healthOk", false)
    return st
}

Nmer_StartSearchCenterCoreStatus(forceRestart := false, caller := "") {
    global g_Nmer_SearchCoreLastLaunchTick, g_Nmer_SearchCoreLaunchPid
    caller := Trim(String(caller))
    if (caller = "")
        caller := "unknown"
    SearchCore_LifecycleLogJson("start_requested", Map("caller", caller, "forceRestart", forceRestart ? 1 : 0))
    existingPid := ProcessExist("SearchCenterCore.exe")
    if !forceRestart && existingPid {
        healthOk := Nmer_SearchCenterCoreHealthy()
        status := healthOk ? "healthy" : "process_only"
        SearchCore_LifecycleLogJson("start_skip_process_present", Map(
            "caller", caller, "pid", existingPid, "status", status, "healthOk", healthOk ? 1 : 0))
        Nmer_SearchCoreLog("start_skip process_present pid=" . existingPid . " status=" . status)
        return Map("status", status, "pid", existingPid, "healthOk", healthOk)
    }
    exe := Nmer_SearchCenterCoreExe()
    if (exe = "" || !FileExist(exe)) {
        Nmer_SearchCoreLog("start_abort exe_missing path=" . exe)
        SearchCore_LifecycleLogJson("start_failed", Map("caller", caller, "status", "failed", "reason", "exe_missing"))
        return Map("status", "failed", "reason", "exe_missing", "healthOk", false)
    }
    root := Nmer_InstallRoot()
    if forceRestart && ProcessExist("SearchCenterCore.exe") {
        Nmer_SearchCoreLog("start_force_kill")
        SearchCore_Shutdown("force_restart")
        Sleep(400)
    }
    existingPid := ProcessExist("SearchCenterCore.exe")
    if existingPid {
        healthOk := Nmer_SearchCenterCoreHealthy()
        status := healthOk ? "healthy" : "process_only"
        Nmer_SearchCoreLog("start_skip process_present pid=" . existingPid . " status=" . status)
        SearchCore_LifecycleLogJson("start_skip_process_present", Map(
            "caller", caller, "pid", existingPid, "status", status, "healthOk", healthOk ? 1 : 0))
        return Map("status", status, "pid", existingPid, "healthOk", healthOk)
    }
    now := A_TickCount
    if IsSet(g_Nmer_SearchCoreLastLaunchTick) && (now - Integer(g_Nmer_SearchCoreLastLaunchTick) < 10000) {
        if ProcessExist("SearchCenterCore.exe") {
            SearchCore_LifecycleLogJson("start_debounced", Map("caller", caller, "status", "launch_debounced"))
            Nmer_SearchCoreLog("start_debounced caller=" . caller)
            return Map("status", "launch_debounced", "healthOk", false)
        }
        SearchCore_LifecycleLogJson("start_relaunch_after_exit", Map("caller", caller, "within_ms", now - Integer(g_Nmer_SearchCoreLastLaunchTick)))
        Nmer_SearchCoreLog("start_relaunch_after_exit caller=" . caller)
    }
    g_Nmer_SearchCoreLastLaunchTick := now
    if FuncExists("_SCWV_ApplySearchCoreDefaults") {
        try _SCWV_ApplySearchCoreDefaults()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    cmd := '"' . exe . '" -base "' . root . '"'
    Nmer_SearchCoreLog("start_run cmd=" . cmd . " cwd=" . root)
    SearchCore_LifecycleLogJson("start_run", Map("caller", caller, "cmd", cmd))
    try {
        Run(cmd, root, "Hide", &pid)
        g_Nmer_SearchCoreLaunchPid := pid
        Nmer_SearchCoreLog("start_run ok pid=" . (pid ? pid : "?"))
        SearchCore_LifecycleLogJson("start_run_ok", Map("caller", caller, "pid", pid ? pid : 0))
        return Map("status", "started", "pid", pid ? pid : 0, "healthOk", false)
    } catch as err {
        Nmer_SearchCoreLog("start_run failed: " . err.Message)
        SearchCore_LifecycleLogJson("start_failed", Map("caller", caller, "status", "failed", "error", err.Message))
        return Map("status", "failed", "reason", err.Message, "healthOk", false)
    }
}

Nmer_StartSearchCenterCore(forceRestart := false) {
    st := Nmer_StartSearchCenterCoreStatus(forceRestart, "legacy_bool_wrapper")
    if !(st is Map)
        return false
    status := st.Has("status") ? String(st["status"]) : "failed"
    return (status = "healthy" || status = "started")
}

Nmer_AutoStartSearchCenterCore(*) {
    pid := ProcessExist("SearchCenterCore.exe")
    if pid {
        Nmer_SearchCoreLog("autostart_skip process_present pid=" . pid)
        return
    }
    Nmer_SearchCoreLog("autostart_begin")
    Nmer_StartSearchCenterCore(false)
}

global g_SearchCore_WatchdogEnabled := false
global g_SearchCore_WatchdogLastPhase := ""
global g_SearchCore_WatchdogIntervalMs := 60000
global g_SearchCore_WatchdogBadTicks := 0
global g_SearchCore_WatchdogBadThreshold := 3

SearchCore_StartWatchdog(intervalMs := 60000) {
    global g_SearchCore_WatchdogEnabled, g_SearchCore_WatchdogIntervalMs
    g_SearchCore_WatchdogIntervalMs := Max(15000, Integer(intervalMs))
    g_SearchCore_WatchdogEnabled := true
    SetTimer(SearchCore_WatchdogTick, -g_SearchCore_WatchdogIntervalMs)
    SearchCore_LifecycleLogJson("watchdog_started", Map("interval_ms", g_SearchCore_WatchdogIntervalMs))
}

SearchCore_StopWatchdog(*) {
    global g_SearchCore_WatchdogEnabled, g_SearchCore_WatchdogBadTicks
    g_SearchCore_WatchdogEnabled := false
    g_SearchCore_WatchdogBadTicks := 0
    SetTimer(SearchCore_WatchdogTick, 0)
    SearchCore_LifecycleLogJson("watchdog_stopped", Map())
}

SearchCore_WatchdogTick(*) {
    global g_SearchCore_WatchdogEnabled, g_SearchCore_WatchdogLastPhase, g_SearchCore_WatchdogIntervalMs
    global g_SearchCore_WatchdogBadTicks, g_SearchCore_WatchdogBadThreshold
    if !g_SearchCore_WatchdogEnabled
        return
    pid := ProcessExist("SearchCenterCore.exe")
    healthOk := false
    if pid
        healthOk := Nmer_SearchCenterCoreHealthy()
    phase := !pid ? "absent" : (healthOk ? "healthy" : "process_only")
    if (phase != g_SearchCore_WatchdogLastPhase) {
        g_SearchCore_WatchdogLastPhase := phase
        SearchCore_LifecycleLogJson("watchdog_phase", Map(
            "phase", phase, "pid", pid ? pid : 0, "healthOk", healthOk ? 1 : 0))
        Nmer_SearchCoreLog("watchdog_phase=" . phase . " pid=" . (pid ? pid : 0))
    }
    if (phase = "healthy") {
        g_SearchCore_WatchdogBadTicks := 0
    } else {
        g_SearchCore_WatchdogBadTicks += 1
        if (g_SearchCore_WatchdogBadTicks >= g_SearchCore_WatchdogBadThreshold) {
            g_SearchCore_WatchdogBadTicks := 0
            reason := "watchdog_" . phase
            SearchCore_LifecycleLogJson("watchdog_restart", Map("reason", reason, "pid", pid ? pid : 0))
            Nmer_SearchCoreLog("watchdog_restart reason=" . reason)
            if FuncExists("NmerService_Ensure")
                NmerService_Ensure("searchcore", reason, true)
            else
                SearchCore_ForceRestart(reason)
        }
    }
    SetTimer(SearchCore_WatchdogTick, -g_SearchCore_WatchdogIntervalMs)
}
