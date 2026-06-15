; DomainCWailsHost.ahk — S9 域 C：Wails 侧车承载 SearchCenter / Config（阶段 1：桥接 + 窗口激活，失败回退 AHK）

DomainCWails_Log(surfaceId, message) {
    try {
        if FuncExists("DomainCSurfaceRouter_Log")
            DomainCSurfaceRouter_Log(String(surfaceId) . " " . String(message))
        else if FuncExists("Nmer_WailsBridgeLog")
            Nmer_WailsBridgeLog("domainc_wails " . String(surfaceId) . " " . String(message))
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

DomainCWails_FindWindow(*) {
    try {
        hwnd := WinExist("ahk_exe nmer-wails.exe")
        if hwnd
            return hwnd
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try {
        return WinExist("NMER Wails POC")
    } catch {
        return 0
    }
}

DomainCWails_EnsureBridge(*) {
    if FuncExists("Nmer_EnsureWailsBridgeForPalette")
        return Nmer_EnsureWailsBridgeForPalette()
    if FuncExists("Nmer_StartWailsBridge") && Nmer_StartWailsBridge(false)
        return Map("ok", true, "code", "BRIDGE_STARTED")
    return Map("ok", false, "code", "BRIDGE_UNAVAILABLE")
}

DomainCWails_ActivateWindow(*) {
    hwnd := DomainCWails_FindWindow()
    if !hwnd
        return false
    expr := "ahk_id " . hwnd
    try {
        pid := DllCall("GetCurrentProcessId", "UInt")
        DllCall("AllowSetForegroundWindow", "UInt", pid)
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try DllCall("LockSetForegroundWindow", "UInt", 2)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try WinRestore(expr)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if FuncExists("SCWV_ForegroundPulse") {
        try {
            if SCWV_ForegroundPulse(hwnd)
                return true
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    try WinShow(expr)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try WinActivate(expr)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try {
        if WinActive(expr)
            return true
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return hwnd > 0
}

DomainCWails_RecordHostShow(surfaceId, bridge, entry) {
    sid := String(surfaceId)
    try SurfaceManager_RegisterSurface(sid)
    eventType := (sid = "config_webview") ? "config_host_show" : "sc_host_show"
    try SurfaceManager_RecordEvent(eventType, sid, Map(
        "host", "wails",
        "bridge", String(bridge is Map ? bridge.Get("code", "") : "")
    ))
    try SurfaceManager_ObserveShow(sid, Map(
        "entry", String(entry),
        "host", "wails",
        "bridge", String(bridge is Map ? bridge.Get("code", "") : "")
    ))
}

DomainCWails_HideWindow(surfaceId, entry) {
    hwnd := DomainCWails_FindWindow()
    if hwnd {
        try WinMinimize("ahk_id " . hwnd)
        catch {
            try WinHide("ahk_id " . hwnd)
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        }
    }
    try SurfaceManager_ObserveHide(String(surfaceId), Map("entry", String(entry), "host", "wails"))
}

SearchCenterWails_Open(meta := 0) {
    bridge := DomainCWails_EnsureBridge()
    if !(bridge is Map) || !bridge.Get("ok", false) {
        DomainCWails_Log("search_center", "fallback bridge=" . (bridge is Map ? bridge.Get("code", "?") : "?"))
        return SearchCenterRouter_OpenAhk(meta)
    }
    if !DomainCWails_ActivateWindow() {
        DomainCWails_Log("search_center", "fallback no_wails_hwnd")
        return SearchCenterRouter_OpenAhk(meta)
    }
    DomainCWails_RecordHostShow("search_center", bridge, "SearchCenterWails_Open")
    DomainCWails_Log("search_center", "show_ok bridge=" . bridge.Get("code", ""))
    return true
}

SearchCenterWails_Hide(persistSelection := false) {
    DomainCWails_HideWindow("search_center", "SearchCenterWails_Hide")
    return true
}

SearchCenterWails_Dispose(reason := "") {
    SearchCenterWails_Hide(false)
    try SurfaceManager_ObserveClose("search_center", Map(
        "entry", "SearchCenterWails_Dispose",
        "host", "wails",
        "reason", String(reason)
    ))
}

ConfigWebViewWails_Show(*) {
    bridge := DomainCWails_EnsureBridge()
    if !(bridge is Map) || !bridge.Get("ok", false) {
        DomainCWails_Log("config_webview", "fallback bridge=" . (bridge is Map ? bridge.Get("code", "?") : "?"))
        if FuncExists("ShowConfigWebViewGUI")
            return !!ShowConfigWebViewGUI()
        return false
    }
    if !DomainCWails_ActivateWindow() {
        DomainCWails_Log("config_webview", "fallback no_wails_hwnd")
        if FuncExists("ShowConfigWebViewGUI")
            return !!ShowConfigWebViewGUI()
        return false
    }
    DomainCWails_RecordHostShow("config_webview", bridge, "ConfigWebViewWails_Show")
    DomainCWails_Log("config_webview", "show_ok bridge=" . bridge.Get("code", ""))
    return true
}

ConfigWebViewWails_Hide(*) {
    DomainCWails_HideWindow("config_webview", "ConfigWebViewWails_Hide")
    return true
}

ConfigWebViewWails_Dispose(reason := "") {
    ConfigWebViewWails_Hide()
    try SurfaceManager_ObserveClose("config_webview", Map(
        "entry", "ConfigWebViewWails_Dispose",
        "host", "wails",
        "reason", String(reason)
    ))
}
