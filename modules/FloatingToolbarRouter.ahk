; FloatingToolbarRouter.ahk — S10/S11：悬浮工具栏宿主路由（AHK WebView2 ↔ Wails 合壳 ↔ Hybrid）

global g_FTBRouter_LastShowTick := 0

FloatingToolbarRouter_Log(message) {
    try {
        if FuncExists("Nmer_WailsBridgeLog")
            Nmer_WailsBridgeLog("ftb_router " . String(message))
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

Nmer_FloatingToolbarHost(*) {
    if !(FuncExists("Nmer_WailsBridgeEnabled") && Nmer_WailsBridgeEnabled())
        return "ahk"
    try {
        if FuncExists("Nmer_WailsBridgeForceNmerOnly") && Nmer_WailsBridgeForceNmerOnly()
            return "ahk"
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    host := "ahk"
    try {
        flags := Nmer_WailsBridgeReadFlags()
        wb := flags.Get("wailsBridge", Map())
        if (wb is Map)
            host := StrLower(Trim(String(wb.Get("floatingToolbarHost", "ahk"))))
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if (host = "hybrid")
        return "hybrid"
    if (host = "wails") {
        try {
            if FuncExists("Nmer_LegacySurfaceLifecycleEnabled") && Nmer_LegacySurfaceLifecycleEnabled()
                return "ahk"
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        return "wails"
    }
    return "ahk"
}

FloatingToolbarRouter_CurrentHost(*) {
    return Nmer_FloatingToolbarHost()
}

FloatingToolbarRouter_ShouldUseWails(*) {
    return (Nmer_FloatingToolbarHost() = "wails")
}

FloatingToolbarRouter_ShouldUseHybrid(*) {
    return (Nmer_FloatingToolbarHost() = "hybrid")
}

FloatingToolbarRouter_AhkGuiExists(*) {
    global FloatingToolbarGUI
    return IsObject(FloatingToolbarGUI) && FloatingToolbarGUI.Hwnd
}

FloatingToolbarRouter_Show(meta := 0) {
    global g_FTBRouter_LastShowTick
    host := Nmer_FloatingToolbarHost()
    now := A_TickCount
    if (host = "wails") && (now - g_FTBRouter_LastShowTick) < 400 {
        FloatingToolbarRouter_Log("show_throttle host=wails")
        return true
    }
    g_FTBRouter_LastShowTick := now
    FloatingToolbarRouter_Log("show host=" . host)
    if (host = "hybrid" && FuncExists("FloatingToolbarWails_ShowHybrid")) {
        try return !!FloatingToolbarWails_ShowHybrid(meta)
        catch as err {
            FloatingToolbarRouter_Log("hybrid_show_err " . err.Message)
        }
    }
    if (host = "wails" && FuncExists("FloatingToolbarWails_Show")) {
        try return !!FloatingToolbarWails_Show(meta)
        catch as err {
            FloatingToolbarRouter_Log("wails_show_err " . err.Message)
        }
    }
    if FuncExists("ShowFloatingToolbar")
        return !!ShowFloatingToolbar()
    return false
}

FloatingToolbarRouter_Hide(meta := 0) {
    host := Nmer_FloatingToolbarHost()
    if (host = "hybrid" && FuncExists("FloatingToolbarWails_HideHybrid")) {
        try return !!FloatingToolbarWails_HideHybrid(meta)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    if (host = "wails" && FuncExists("FloatingToolbarWails_Hide")) {
        try return !!FloatingToolbarWails_Hide(meta)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    if FuncExists("HideFloatingToolbar")
        return !!HideFloatingToolbar()
    return false
}

FloatingToolbarRouter_Dispose(reason := "") {
    host := Nmer_FloatingToolbarHost()
    FloatingToolbarRouter_Log("dispose host=" . host . " reason=" . String(reason))
    if (host = "hybrid" && FuncExists("FloatingToolbarWails_DisposeHybrid")) {
        try FloatingToolbarWails_DisposeHybrid(reason)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        return
    }
    if (host = "wails" && FuncExists("FloatingToolbarWails_Dispose")) {
        try FloatingToolbarWails_Dispose(reason)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        if !FloatingToolbarRouter_AhkGuiExists()
            return
    }
    if FuncExists("FloatingToolbar_Dispose")
        FloatingToolbar_Dispose(reason)
}
