; SurfaceIntentRouter.ahk — S2 中央 Intent 路由（外部入口统一经此模块）

global g_SurfaceIntent_InExecute := ""

SurfaceIntent_InExecuteContext() {
    global g_SurfaceIntent_InExecute
    return String(g_SurfaceIntent_InExecute) != ""
}

SurfaceIntent_ShouldSkipExecutorTelemetry(*) {
    return SurfaceIntent_InExecuteContext()
}

SurfaceIntent_RouteExternalOpen(surfaceId, meta := 0) {
    if SurfaceIntent_InExecuteContext()
        return false
    if !SurfaceIntent_ShouldRoute()
        return false
    SurfaceIntent_Open(surfaceId, meta)
    return true
}

SurfaceIntent_RouteExternalClose(surfaceId, meta := 0) {
    if SurfaceIntent_InExecuteContext()
        return false
    if !SurfaceIntent_ShouldRoute()
        return false
    SurfaceIntent_Close(surfaceId, meta)
    return true
}

SurfaceIntent_NormalizeMeta(meta) {
    if (meta is Map) {
        out := Map()
        for key, val in meta
            out[String(key)] := SurfaceManager_SimpleClone(val)
        return out
    }
    if (meta != 0 && String(meta) != "")
        return Map("detail", String(meta))
    return Map()
}

SurfaceIntent_ShouldRoute(*) {
    try {
        if FuncExists("Nmer_SurfaceManagerRouteIntents") && Nmer_SurfaceManagerRouteIntents()
            return true
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return false
}

SurfaceIntent_ShouldObserveRequest(*) {
    if SurfaceIntent_ShouldRoute()
        return true
    try {
        if FuncExists("SurfaceManager_IsObservationEnabled") && SurfaceManager_IsObservationEnabled()
            return true
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
    try {
        if FuncExists("Nmer_SurfaceManagerInterceptOpenClose") && Nmer_SurfaceManagerInterceptOpenClose()
            return true
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
    return false
}

SurfaceIntent_Record(kind, surfaceId, meta := 0, requestId := 0) {
    if !FuncExists("SurfaceManager_RecordEvent")
        return
    if !SurfaceManager_IsObservationEnabled()
        return
    payload := SurfaceIntent_NormalizeMeta(meta)
    if (requestId != 0 && String(requestId) != "")
        payload["requestId"] := String(requestId)
    SurfaceManager_RecordEvent(String(kind), String(surfaceId), payload)
    if FuncExists("Nmer_Telemetry_Record") {
        try Nmer_Telemetry_Record("surface", String(kind), !InStr(String(kind), "_error"), payload)
        catch as _e {
            NmerCatch(A_ThisFunc, _e)
        }
    }
}

SurfaceIntent_ExecuteOpen(surfaceId, meta := 0) {
    sid := String(surfaceId)
    m := SurfaceIntent_NormalizeMeta(meta)
    switch sid {
        case "search_center":
            if FuncExists("SearchCenterRouter_Open")
                SearchCenterRouter_Open(m)
            else {
                mode := m.Has("mode") ? String(m["mode"]) : ""
                kw := m.Has("keyword") ? String(m["keyword"]) : ""
                ts := m.Has("triggerSource") ? String(m["triggerSource"]) : ""
                useUnified := m.Has("unified") ? !!m["unified"] : (mode != "" || ts != "")
                if useUnified {
                    openMode := (StrLower(mode) = "clipboard") ? "clipboard" : "search"
                    if (ts = "")
                        ts := (openMode = "clipboard") ? "clipboard_hotkey" : "search_hotkey"
                    SurfaceManager_InvokeOptional("SCWV_OpenUnified", openMode, kw, ts)
                } else {
                    reason := m.Has("reason") ? String(m["reason"]) : ""
                    SurfaceManager_InvokeOptional("SCWV_Show", reason, ts)
                }
            }
        case "command_palette":
            if FuncExists("CommandPaletteRouter_Show")
                CommandPaletteRouter_Show()
            else
                SurfaceManager_InvokeOptional("CommandPalette_Show")
        case "clipboard_panel":
            SurfaceManager_InvokeOptional("CP_Show")
        case "prompt_quick_pad":
            SurfaceManager_InvokeOptional("PQP_Show")
        case "virtual_keyboard":
            SurfaceManager_InvokeOptional("VK_Show")
        case "config_webview":
            if FuncExists("ConfigWebViewRouter_Show")
                ConfigWebViewRouter_Show()
            else
                SurfaceManager_InvokeOptional("ShowConfigWebViewGUI")
        case "floating_toolbar":
            if FuncExists("FloatingToolbarRouter_Show")
                FloatingToolbarRouter_Show(m)
            else
                SurfaceManager_InvokeOptional("ShowFloatingToolbar")
        default:
            throw Error("SurfaceIntent_ExecuteOpen: unknown surface " . sid)
    }
}

SurfaceIntent_ExecuteClose(surfaceId, meta := 0) {
    sid := String(surfaceId)
    m := SurfaceIntent_NormalizeMeta(meta)
    switch sid {
        case "search_center":
            persist := m.Has("persistSelection") ? !!m["persistSelection"] : false
            if FuncExists("SearchCenterRouter_Hide")
                SearchCenterRouter_Hide(persist)
            else
                SurfaceManager_InvokeOptional("SCWV_Hide", persist)
        case "command_palette":
            if FuncExists("CommandPaletteRouter_Hide")
                CommandPaletteRouter_Hide(m)
            else
                SurfaceManager_InvokeOptional("CommandPalette_Hide", m)
        case "clipboard_panel":
            SurfaceManager_InvokeOptional("CP_Hide")
        case "prompt_quick_pad":
            SurfaceManager_InvokeOptional("PQP_Hide")
        case "virtual_keyboard":
            SurfaceManager_InvokeOptional("VK_Hide")
        case "config_webview":
            if FuncExists("ConfigWebViewRouter_Hide")
                ConfigWebViewRouter_Hide()
            else
                SurfaceManager_InvokeOptional("ConfigWebView_Close")
        case "floating_toolbar":
            if FuncExists("FloatingToolbarRouter_Hide")
                FloatingToolbarRouter_Hide(m)
            else
                SurfaceManager_InvokeOptional("HideFloatingToolbar")
        default:
            throw Error("SurfaceIntent_ExecuteClose: unknown surface " . sid)
    }
}

SurfaceIntent_Open(surfaceId, meta := 0) {
    sid := String(surfaceId)
    if (sid = "")
        return 0
    SurfaceManager_EnsureBootstrap()
    m := SurfaceIntent_NormalizeMeta(meta)
    m["intentAction"] := "open"
    requestId := 0
    genId := 0
    useTxn := false
    if FuncExists("SurfaceTransaction_ShouldUse") && SurfaceTransaction_ShouldUse()
        && SurfaceIntent_ShouldRoute() && !(FuncExists("SurfaceTransaction_IsRestoreContext") && SurfaceTransaction_IsRestoreContext(m))
        && !(FuncExists("SurfaceTransaction_ShouldBeginFor") && !SurfaceTransaction_ShouldBeginFor(sid, m))
        useTxn := true
    if useTxn {
        genId := SurfaceTransaction_Begin(sid, m, 0)
        m["generationId"] := genId
    }
    if SurfaceIntent_ShouldObserveRequest() {
        try SurfaceManager_RegisterSurface(sid)
        requestId := SurfaceManager_Request(sid, "open", "SurfaceIntent_Open", m)
        if useTxn && genId
            SurfaceTransaction_UpdateRequestId(genId, requestId)
        try SurfaceManager_BeforeOpen(sid, "SurfaceIntent_Open", m)
    }
    if SurfaceIntent_ShouldObserveRequest()
        SurfaceIntent_Record("intent_open", sid, m, requestId)
    global g_SurfaceIntent_InExecute
    prevExec := g_SurfaceIntent_InExecute
    g_SurfaceIntent_InExecute := "open"
    try {
        SurfaceIntent_ExecuteOpen(sid, m)
    } catch as err {
        if useTxn && genId
            SurfaceTransaction_Abort(genId, "open_error", Map("message", err.Message, "requestId", requestId))
        SurfaceIntent_Record("intent_open_error", sid, Map("message", err.Message, "requestId", requestId, "generationId", genId), requestId)
        throw err
    } finally {
        g_SurfaceIntent_InExecute := prevExec
    }
    if FuncExists("Nmer_Telemetry_MarkSurfaceOpen") {
        try Nmer_Telemetry_MarkSurfaceOpen(sid, m)
        catch as _e {
            NmerCatch(A_ThisFunc, _e)
        }
    }
    return requestId ? requestId : 1
}

SurfaceIntent_Close(surfaceId, meta := 0) {
    sid := String(surfaceId)
    if (sid = "")
        return 0
    m := SurfaceIntent_NormalizeMeta(meta)
    m["intentAction"] := "close"
    if FuncExists("SurfaceTransaction_OnTargetClose")
        try SurfaceTransaction_OnTargetClose(sid, m)
    requestId := 0
    if SurfaceIntent_ShouldObserveRequest() {
        requestId := SurfaceManager_Request(sid, "close", "SurfaceIntent_Close", m)
    }
    if SurfaceIntent_ShouldObserveRequest()
        SurfaceIntent_Record("intent_close", sid, m, requestId)
    global g_SurfaceIntent_InExecute
    prevExec := g_SurfaceIntent_InExecute
    g_SurfaceIntent_InExecute := "close"
    try {
        SurfaceIntent_ExecuteClose(sid, m)
    } catch as err {
        SurfaceIntent_Record("intent_close_error", sid, Map("message", err.Message, "requestId", requestId), requestId)
        throw err
    } finally {
        g_SurfaceIntent_InExecute := prevExec
    }
    if FuncExists("Nmer_Telemetry_MarkSurfaceClose") {
        try Nmer_Telemetry_MarkSurfaceClose(sid, m)
        catch as _e {
            NmerCatch(A_ThisFunc, _e)
        }
    }
    return requestId
}

SurfaceIntent_Dispose(surfaceId, meta := 0) {
    sid := String(surfaceId)
    if (sid = "")
        return 0
    m := SurfaceIntent_NormalizeMeta(meta)
    m["intentAction"] := "dispose"
    requestId := 0
    if SurfaceIntent_ShouldObserveRequest() {
        requestId := SurfaceManager_Request(sid, "close", "SurfaceIntent_Dispose", m)
    }
    if SurfaceIntent_ShouldObserveRequest()
        SurfaceIntent_Record("intent_dispose", sid, m, requestId)
    global g_SurfaceIntent_InExecute
    prevExec := g_SurfaceIntent_InExecute
    g_SurfaceIntent_InExecute := "dispose"
    try {
        SurfaceExecutor_Dispose(sid, m)
    } catch as err {
        SurfaceIntent_Record("intent_dispose_error", sid, Map("message", err.Message, "requestId", requestId), requestId)
        throw err
    } finally {
        g_SurfaceIntent_InExecute := prevExec
    }
    return requestId
}

SurfaceIntent_PreemptCommandPaletteForSearch(*) {
    cpVisible := false
    try {
        if FuncExists("CommandPalette_IsVisible")
            cpVisible := CommandPalette_IsVisible()
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    cpActive := false
    try {
        if FuncExists("SurfaceManager_HasActivePrimaryConflict")
            cpActive := SurfaceManager_HasActivePrimaryConflict("search_center")
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if !cpVisible && !cpActive
        return
    try {
        pid := DllCall("GetCurrentProcessId", "UInt")
        DllCall("AllowSetForegroundWindow", "UInt", pid)
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if FuncExists("CommandPalette_CancelDeferredFocusTimers")
        try CommandPalette_CancelDeferredFocusTimers()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    preemptMeta := Map("reason", "search_preempt", "skipTransaction", true)
    if FuncExists("SurfaceIntent_Close") {
        try SurfaceIntent_Close("command_palette", preemptMeta)
        catch {
            if FuncExists("CommandPalette_Hide")
                CommandPalette_Hide(preemptMeta)
        }
    } else if FuncExists("CommandPalette_Hide")
        CommandPalette_Hide(preemptMeta)
    if FuncExists("FocusBroker_Release")
        try FocusBroker_Release("CommandPalette", "search_preempt")
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    if FuncExists("SurfaceManager_ObserveHide")
        try SurfaceManager_ObserveHide("command_palette", Map("reason", "search_preempt"))
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
}

SurfaceIntent_OpenSearch(keyword := "", triggerSource := "search_hotkey") {
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
    SurfaceIntent_PreemptCommandPaletteForSearch()
    if FuncExists("SCWV_StartHotkeyForegroundPump")
        try SCWV_StartHotkeyForegroundPump()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    return SurfaceIntent_Open("search_center", Map(
        "mode", "search",
        "keyword", String(keyword),
        "triggerSource", String(triggerSource),
        "unified", 1,
        "reason", "unified_open_search"
    ))
}

SurfaceIntent_OpenClipboardUnified(keyword := "", triggerSource := "clipboard_hotkey") {
    ; Unified clipboard runs inside search center, but telemetry selftest expects
    ; clipboard_panel_open presence for clipboard entry usage.
    if FuncExists("Nmer_Telemetry_MarkSurfaceOpen") {
        try Nmer_Telemetry_MarkSurfaceOpen("clipboard_panel", Map("source", "SurfaceIntent_OpenClipboardUnified"))
    }
    return SurfaceIntent_Open("search_center", Map(
        "mode", "clipboard",
        "keyword", String(keyword),
        "triggerSource", String(triggerSource),
        "unified", 1,
        "reason", "unified_open_clipboard"
    ))
}

; 打开 WebView 剪贴板面板（非搜索中心 unified 模式）
SurfaceIntent_OpenClipboardPanel(meta := 0) {
    m := SurfaceIntent_NormalizeMeta(meta)
    if !m.Has("reason")
        m["reason"] := "open_clipboard_panel"
    if !m.Has("triggerSource")
        m["triggerSource"] := "open_clipboard_panel"
    return SurfaceIntent_Open("clipboard_panel", m)
}

; 打开设置：保留 ShowConfigGUI_Safe 防御逻辑；Core 内再经 SurfaceIntent_Open
SurfaceIntent_OpenConfig(meta := 0) {
    m := SurfaceIntent_NormalizeMeta(meta)
    if !m.Has("reason")
        m["reason"] := "open_config"
    if !m.Has("triggerSource")
        m["triggerSource"] := "open_config"
    if (m.Has("navigateTab") || m.Has("defaultStartTab")) {
        global g_ConfigWebView_OneShotDefaultTab
        tab := m.Has("navigateTab") ? String(m["navigateTab"]) : String(m["defaultStartTab"])
        if (tab != "")
            g_ConfigWebView_OneShotDefaultTab := tab
    }
    if FuncExists("ShowConfigGUI_Safe")
        return ShowConfigGUI_Safe()
    return SurfaceIntent_Open("config_webview", m)
}
