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
    } catch {
    }
    return false
}

SurfaceIntent_ShouldObserveRequest(*) {
    if SurfaceIntent_ShouldRoute()
        return true
    try {
        if FuncExists("Nmer_SurfaceManagerInterceptOpenClose") && Nmer_SurfaceManagerInterceptOpenClose()
            return true
    } catch {
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
}

SurfaceIntent_ExecuteOpen(surfaceId, meta := 0) {
    sid := String(surfaceId)
    m := SurfaceIntent_NormalizeMeta(meta)
    switch sid {
        case "search_center":
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
        case "command_palette":
            SurfaceManager_InvokeOptional("CommandPalette_Show")
        case "clipboard_panel":
            SurfaceManager_InvokeOptional("CP_Show")
        case "prompt_quick_pad":
            SurfaceManager_InvokeOptional("PQP_Show")
        case "virtual_keyboard":
            SurfaceManager_InvokeOptional("VK_Show")
        case "config_webview":
            SurfaceManager_InvokeOptional("ShowConfigWebViewGUI")
        case "floating_toolbar":
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
            SurfaceManager_InvokeOptional("SCWV_Hide", persist)
        case "command_palette":
            SurfaceManager_InvokeOptional("CommandPalette_Hide")
        case "clipboard_panel":
            SurfaceManager_InvokeOptional("CP_Hide")
        case "prompt_quick_pad":
            SurfaceManager_InvokeOptional("PQP_Hide")
        case "virtual_keyboard":
            SurfaceManager_InvokeOptional("VK_Hide")
        case "config_webview":
            SurfaceManager_InvokeOptional("ConfigWebView_Close")
        case "floating_toolbar":
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
    if SurfaceIntent_ShouldObserveRequest() {
        try SurfaceManager_RegisterSurface(sid)
        requestId := SurfaceManager_Request(sid, "open", "SurfaceIntent_Open", m)
        try SurfaceManager_BeforeOpen(sid, "SurfaceIntent_Open", m)
    }
    if SurfaceIntent_ShouldRoute()
        SurfaceIntent_Record("intent_open", sid, m, requestId)
    global g_SurfaceIntent_InExecute
    prevExec := g_SurfaceIntent_InExecute
    g_SurfaceIntent_InExecute := "open"
    try {
        SurfaceIntent_ExecuteOpen(sid, m)
    } catch as err {
        SurfaceIntent_Record("intent_open_error", sid, Map("message", err.Message, "requestId", requestId), requestId)
        throw err
    } finally {
        g_SurfaceIntent_InExecute := prevExec
    }
    return requestId ? requestId : 1
}

SurfaceIntent_Close(surfaceId, meta := 0) {
    sid := String(surfaceId)
    if (sid = "")
        return 0
    m := SurfaceIntent_NormalizeMeta(meta)
    m["intentAction"] := "close"
    requestId := 0
    if SurfaceIntent_ShouldObserveRequest() {
        requestId := SurfaceManager_Request(sid, "close", "SurfaceIntent_Close", m)
    }
    if SurfaceIntent_ShouldRoute()
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
    if SurfaceIntent_ShouldRoute()
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

SurfaceIntent_OpenSearch(keyword := "", triggerSource := "search_hotkey") {
    return SurfaceIntent_Open("search_center", Map(
        "mode", "search",
        "keyword", String(keyword),
        "triggerSource", String(triggerSource),
        "unified", 1,
        "reason", "unified_open_search"
    ))
}

SurfaceIntent_OpenClipboardUnified(keyword := "", triggerSource := "clipboard_hotkey") {
    return SurfaceIntent_Open("search_center", Map(
        "mode", "clipboard",
        "keyword", String(keyword),
        "triggerSource", String(triggerSource),
        "unified", 1,
        "reason", "unified_open_clipboard"
    ))
}
