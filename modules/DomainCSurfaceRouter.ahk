; DomainCSurfaceRouter.ahk — S9 域 C：SearchCenter + Config 宿主路由（AHK WebView2 ↔ Wails 侧车）

DomainCSurfaceRouter_Log(message) {
    try {
        if FuncExists("Nmer_WailsBridgeLog")
            Nmer_WailsBridgeLog("domainc_router " . String(message))
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

DomainC_Router_ShouldUseAhk(*) {
    try {
        if FuncExists("Nmer_LegacySurfaceLifecycleEnabled") && Nmer_LegacySurfaceLifecycleEnabled()
            return true
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try {
        if FuncExists("Nmer_WailsBridgeForceNmerOnly") && Nmer_WailsBridgeForceNmerOnly()
            return true
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if !(FuncExists("Nmer_WailsBridgeEnabled") && Nmer_WailsBridgeEnabled())
        return true
    return false
}

DomainC_Router_ReadHostFlag(flagName, defaultHost := "ahk") {
    if DomainC_Router_ShouldUseAhk()
        return "ahk"
    host := defaultHost
    try {
        flags := Nmer_WailsBridgeReadFlags()
        wb := flags.Get("wailsBridge", Map())
        if (wb is Map)
            host := StrLower(Trim(String(wb.Get(flagName, defaultHost))))
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return (host = "wails") ? "wails" : "ahk"
}

Nmer_SearchCenterHost(*) {
    return DomainC_Router_ReadHostFlag("searchCenterHost", "ahk")
}

Nmer_ConfigWebviewHost(*) {
    return DomainC_Router_ReadHostFlag("configWebviewHost", "ahk")
}

SearchCenterRouter_NormalizeMeta(meta) {
    if FuncExists("SurfaceIntent_NormalizeMeta")
        return SurfaceIntent_NormalizeMeta(meta)
    if (meta is Map)
        return meta
    return Map()
}

SearchCenterRouter_OpenAhk(meta := 0) {
    m := SearchCenterRouter_NormalizeMeta(meta)
    mode := m.Has("mode") ? String(m["mode"]) : ""
    kw := m.Has("keyword") ? String(m["keyword"]) : ""
    ts := m.Has("triggerSource") ? String(m["triggerSource"]) : ""
    useUnified := m.Has("unified") ? !!m["unified"] : (mode != "" || ts != "")
    if useUnified {
        openMode := (StrLower(mode) = "clipboard") ? "clipboard" : "search"
        if (ts = "")
            ts := (openMode = "clipboard") ? "clipboard_hotkey" : "search_hotkey"
        if FuncExists("SCWV_OpenUnified")
            return !!SCWV_OpenUnified(openMode, kw, ts)
        return false
    }
    reason := m.Has("reason") ? String(m["reason"]) : ""
    if FuncExists("SCWV_Show")
        return !!SCWV_Show(reason, ts)
    return false
}

SearchCenterRouter_Open(meta := 0) {
    host := Nmer_SearchCenterHost()
    DomainCSurfaceRouter_Log("sc_open host=" . host)
    if (host = "wails" && FuncExists("SearchCenterWails_Open")) {
        try return !!SearchCenterWails_Open(meta)
        catch as err {
            DomainCSurfaceRouter_Log("sc_wails_open_err " . err.Message)
        }
    }
    return SearchCenterRouter_OpenAhk(meta)
}

SearchCenterRouter_Hide(persistSelection := false) {
    host := Nmer_SearchCenterHost()
    if (host = "wails" && FuncExists("SearchCenterWails_Hide")) {
        try return SearchCenterWails_Hide(persistSelection)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    if FuncExists("SCWV_Hide")
        return SCWV_Hide(persistSelection)
    return false
}

SearchCenterRouter_Dispose(reason := "") {
    host := Nmer_SearchCenterHost()
    DomainCSurfaceRouter_Log("sc_dispose host=" . host . " reason=" . String(reason))
    if (host = "wails" && FuncExists("SearchCenterWails_Dispose")) {
        try SearchCenterWails_Dispose(reason)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    if FuncExists("SCWV_Dispose")
        SCWV_Dispose(reason)
    else if FuncExists("SCWV_RequestHardClose")
        SCWV_RequestHardClose(reason)
}

ConfigWebViewRouter_Show(*) {
    host := Nmer_ConfigWebviewHost()
    DomainCSurfaceRouter_Log("config_open host=" . host)
    if (host = "wails" && FuncExists("ConfigWebViewWails_Show")) {
        try return !!ConfigWebViewWails_Show()
        catch as err {
            DomainCSurfaceRouter_Log("config_wails_show_err " . err.Message)
        }
    }
    if FuncExists("ShowConfigWebViewGUI")
        return !!ShowConfigWebViewGUI()
    return false
}

ConfigWebViewRouter_Hide(*) {
    host := Nmer_ConfigWebviewHost()
    if (host = "wails" && FuncExists("ConfigWebViewWails_Hide")) {
        try return ConfigWebViewWails_Hide()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    if FuncExists("ConfigWebView_Close")
        return ConfigWebView_Close()
    return false
}

ConfigWebViewRouter_Dispose(reason := "") {
    host := Nmer_ConfigWebviewHost()
    DomainCSurfaceRouter_Log("config_dispose host=" . host . " reason=" . String(reason))
    if (host = "wails" && FuncExists("ConfigWebViewWails_Dispose")) {
        try ConfigWebViewWails_Dispose(reason)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    if FuncExists("ConfigWebView_Dispose")
        ConfigWebView_Dispose(reason)
    else if FuncExists("ConfigWebView_Close")
        ConfigWebView_Close()
}
