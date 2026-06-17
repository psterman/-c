; CommandPaletteRouter.ahk — S8 B3：命令面板宿主路由（AHK WebView2 ↔ Wails 侧车）

CommandPaletteRouter_Log(message) {
    try {
        if FuncExists("Nmer_WailsBridgeLog")
            Nmer_WailsBridgeLog("cp_router " . String(message))
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

Nmer_CommandPaletteHost(*) {
    try {
        if FuncExists("Nmer_LegacySurfaceLifecycleEnabled") && Nmer_LegacySurfaceLifecycleEnabled()
            return "ahk"
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try {
        if FuncExists("Nmer_WailsBridgeForceNmerOnly") && Nmer_WailsBridgeForceNmerOnly()
            return "ahk"
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if !(FuncExists("Nmer_WailsBridgeEnabled") && Nmer_WailsBridgeEnabled())
        return "ahk"
    host := "ahk"
    try {
        flags := Nmer_WailsBridgeReadFlags()
        wb := flags.Get("wailsBridge", Map())
        if (wb is Map)
            host := StrLower(Trim(String(wb.Get("commandPaletteHost", "ahk"))))
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return (host = "wails") ? "wails" : "ahk"
}

CommandPaletteRouter_CurrentHost(*) {
    return Nmer_CommandPaletteHost()
}

CommandPaletteRouter_ShouldUseWails(*) {
    return (Nmer_CommandPaletteHost() = "wails")
}

CommandPaletteRouter_Show(*) {
    host := Nmer_CommandPaletteHost()
    CommandPaletteRouter_Log("show host=" . host)
    if (host = "wails" && FuncExists("CommandPaletteWails_Show")) {
        if FuncExists("Nmer_Telemetry_MarkSurfaceOpen") {
            try Nmer_Telemetry_MarkSurfaceOpen("command_palette", Map("source", "CommandPaletteRouter_Show", "host", "wails"))
        }
        try return !!CommandPaletteWails_Show()
        catch as err {
            CommandPaletteRouter_Log("wails_show_err " . err.Message)
        }
    }
    if !FuncExists("CommandPalette_Show")
        return false
    return !!CommandPalette_Show()
}

CommandPaletteRouter_Hide(meta := 0) {
    host := Nmer_CommandPaletteHost()
    if (host = "wails" && FuncExists("CommandPaletteWails_Hide")) {
        if FuncExists("Nmer_Telemetry_MarkSurfaceClose") {
            try Nmer_Telemetry_MarkSurfaceClose("command_palette", Map("source", "CommandPaletteRouter_Hide", "host", "wails"))
        }
        try return CommandPaletteWails_Hide()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    if FuncExists("CommandPalette_Hide")
        return CommandPalette_Hide(meta)
    return false
}

CommandPaletteRouter_AhkGuiExists(*) {
    global g_CmdPal_Gui
    return !!(IsObject(g_CmdPal_Gui) && g_CmdPal_Gui.Hwnd)
}

CommandPaletteRouter_Dispose(reason := "") {
    host := Nmer_CommandPaletteHost()
    CommandPaletteRouter_Log("dispose host=" . host . " reason=" . String(reason))
    if (host = "wails") {
        if FuncExists("CommandPaletteWails_Dispose") {
            try CommandPaletteWails_Dispose(reason)
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        }
        if FuncExists("CommandPaletteWails_RetireAhkWebView")
            try CommandPaletteWails_RetireAhkWebView("router_dispose")
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        else if FuncExists("CommandPalette_DisposeAhkWebViewIfRetired")
            try CommandPalette_DisposeAhkWebViewIfRetired("router_dispose")
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        return
    }
    if FuncExists("CommandPalette_Dispose")
        CommandPalette_Dispose(reason)
}
