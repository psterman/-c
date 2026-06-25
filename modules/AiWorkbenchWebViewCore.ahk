; AiWorkbenchWebViewCore.ahk — AI 工作台独立 Surface（复用 SearchCenterWebLlm 多列内嵌）
#Requires AutoHotkey v2.0

global g_AiWb_Gui := 0
global g_AiWb_Ctrl := 0
global g_AiWb_WV2 := 0
global g_AiWb_Ready := false
global g_AiWb_Visible := false
global g_AiWb_LastShown := 0
global g_AiWb_PendingKeyword := ""
global g_AiWb_PendingEngines := []
global g_AiWb_Saved_SCWV_Gui := 0
global g_AiWb_Saved_SCWV_Ctrl := 0
global g_AiWb_Saved_SCWV_WV2 := 0

AiWb_GetGui() {
    global g_AiWb_Gui
    return g_AiWb_Gui
}

AiWb_GetHostHwnd() {
    global g_AiWb_Gui
    if IsObject(g_AiWb_Gui) {
        try return g_AiWb_Gui.Hwnd
        catch {
        }
    }
    return 0
}

AiWb_IsVisible() {
    global g_AiWb_Visible
    return !!g_AiWb_Visible
}

AiWb_ShouldShowEmbed() {
    return AiWb_IsVisible()
}

AiWb_BindScWebLlmHost() {
    global g_AiWb_Gui, g_AiWb_Ctrl, g_AiWb_WV2
    global g_AiWb_Saved_SCWV_Gui, g_AiWb_Saved_SCWV_Ctrl, g_AiWb_Saved_SCWV_WV2
    global g_SCWV_Gui, g_SCWV_Ctrl, g_SCWV_WV2, g_SCWebLlm_ParentHwnd
    g_AiWb_Saved_SCWV_Gui := g_SCWV_Gui
    g_AiWb_Saved_SCWV_Ctrl := g_SCWV_Ctrl
    g_AiWb_Saved_SCWV_WV2 := g_SCWV_WV2
    g_SCWV_Gui := g_AiWb_Gui
    g_SCWV_Ctrl := g_AiWb_Ctrl
    g_SCWV_WV2 := g_AiWb_WV2
    if IsObject(g_AiWb_Gui) {
        try g_SCWebLlm_ParentHwnd := g_AiWb_Gui.Hwnd
        catch {
            g_SCWebLlm_ParentHwnd := 0
        }
    }
}

AiWb_RestoreScWebLlmHost() {
    global g_AiWb_Saved_SCWV_Gui, g_AiWb_Saved_SCWV_Ctrl, g_AiWb_Saved_SCWV_WV2
    global g_SCWV_Gui, g_SCWV_Ctrl, g_SCWV_WV2
    g_SCWV_Gui := g_AiWb_Saved_SCWV_Gui
    g_SCWV_Ctrl := g_AiWb_Saved_SCWV_Ctrl
    g_SCWV_WV2 := g_AiWb_Saved_SCWV_WV2
    g_AiWb_Saved_SCWV_Gui := 0
    g_AiWb_Saved_SCWV_Ctrl := 0
    g_AiWb_Saved_SCWV_WV2 := 0
}

AiWb_PostJson(payload) {
    global g_AiWb_WV2, g_AiWb_Ready
    if !g_AiWb_Ready || !IsObject(g_AiWb_WV2)
        return
    if (payload is Map)
        WebView_QueuePayload(g_AiWb_WV2, payload)
    else
        WebView_QueueJson(g_AiWb_WV2, payload)
}

AiWb_Init() {
    global g_AiWb_Gui
    if g_AiWb_Gui
        return
    try SurfaceManager_ObserveInit("ai_workbench", Map("entry", "AiWb_Init"))
    g_AiWb_Gui := Gui("+Resize +MinSize720x480 +MinimizeBox +MaximizeBox +Caption -DPIScale", "AI 工作台")
    g_AiWb_Gui.BackColor := "0d1016"
    g_AiWb_Gui.MarginX := 0
    g_AiWb_Gui.MarginY := 0
    g_AiWb_Gui.OnEvent("Close", (*) => AiWb_Hide())
    g_AiWb_Gui.OnEvent("Size", _AiWb_OnGuiResize)
    g_AiWb_Gui.Show("w1180 h780 Hide")
    WebView2_CreateWithSharedEnvAsync(g_AiWb_Gui.Hwnd, _AiWb_OnWV2Created, "ai_workbench")
}

_AiWb_GetWebView2Class() {
    try return WebView2
    catch {
        return 0
    }
}

_AiWb_OnWV2Created(ctrl) {
    global g_AiWb_Ctrl, g_AiWb_WV2
    g_AiWb_Ctrl := ctrl
    g_AiWb_WV2 := ctrl.CoreWebView2
    try g_AiWb_Ctrl.DefaultBackgroundColor := 0xFF0D1016
    try g_AiWb_Ctrl.IsVisible := true
    _AiWb_ApplyBounds()
    s := g_AiWb_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.AreDevToolsEnabled := false
    if FuncExists("ApplyWebView2PerformanceSettings")
        ApplyWebView2PerformanceSettings(g_AiWb_WV2)
    if FuncExists("WebView2_RegisterHostBridge")
        WebView2_RegisterHostBridge(g_AiWb_WV2)
    g_AiWb_WV2.add_WebMessageReceived(_AiWb_OnWebMessage)
    try g_AiWb_WV2.add_NavigationCompleted(_AiWb_OnNavigationCompleted)
    try ApplyUnifiedWebViewAssets(g_AiWb_WV2)
    g_AiWb_WV2.Navigate(BuildAppLocalUrl("AiWorkbench.html"))
    global g_AiWb_Visible
    if g_AiWb_Visible {
        try WebView2_NotifyShown(g_AiWb_WV2)
        _AiWb_RefreshComposition()
        SetTimer(_AiWb_NudgeWebBootstrap, -120)
    }
}

_AiWb_NudgeWebBootstrap(*) {
    global g_AiWb_Visible, g_AiWb_WV2, g_AiWb_Ready
    if !g_AiWb_Visible || !g_AiWb_Ready || !IsObject(g_AiWb_WV2)
        return
    try WebView2_NotifyShown(g_AiWb_WV2)
    _AiWb_RefreshComposition()
    if FuncExists("SearchCenterWebLlm_PrepareForWebModeShow") {
        try SearchCenterWebLlm_PrepareForWebModeShow()
        catch {
        }
    }
    AiWb_PostJson(Map("type", "hostLayout"))
    AiWb_PostJson(Map("type", "hostPaintNudge", "reason", "bootstrap"))
}

_AiWb_ApplyBounds() {
    global g_AiWb_Gui, g_AiWb_Ctrl
    if !g_AiWb_Ctrl || !g_AiWb_Gui
        return
    WinGetClientPos(, , &cw, &ch, g_AiWb_Gui.Hwnd)
    WV2 := _AiWb_GetWebView2Class()
    if !WV2
        return
    rc := WV2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    g_AiWb_Ctrl.Bounds := rc
}

_AiWb_OnGuiResize(GuiObj, MinMax, Width, Height) {
    if (MinMax = -1)
        return
    _AiWb_ApplyBounds()
    if FuncExists("SearchCenterWebLlm_ApplyBounds") && AiWb_IsVisible() {
        try SearchCenterWebLlm_ApplyBounds(g_AiWb_Gui.Hwnd)
        catch {
        }
    }
}

_AiWb_OnNavigationCompleted(sender, args) {
    global g_AiWb_Visible
    try ok := args.IsSuccess
    catch {
        ok := true
    }
    if !ok
        return
    if !g_AiWb_Visible
        return
    _AiWb_RefreshComposition()
    SetTimer(_AiWb_NudgeWebBootstrap, -80)
}

_AiWb_RefreshComposition(*) {
    global g_AiWb_Ctrl, g_AiWb_Gui, g_AiWb_Visible
    if !g_AiWb_Visible || !g_AiWb_Ctrl || !g_AiWb_Gui
        return
    try {
        _AiWb_ApplyBounds()
        g_AiWb_Ctrl.NotifyParentWindowPositionChanged()
    } catch {
    }
}

_AiWb_GetThemeMode() {
    try {
        global ConfigFile
        if IsSet(ConfigFile) && ConfigFile != "" {
            raw := IniRead(ConfigFile, "Settings", "ThemeMode", "")
            if (Trim(String(raw)) = "")
                raw := IniRead(ConfigFile, "Appearance", "ThemeMode", "")
            tm := StrLower(Trim(String(raw)))
            if (tm = "light" || tm = "lite")
                return "light"
        }
    } catch {
    }
    return "dark"
}

AiWb_PushInit() {
    global SearchCenterSelectedEngines
    engines := []
    if FuncExists("_SCWV_BuildEnginePayload")
        try engines := _SCWV_BuildEnginePayload("ai")
        catch {
            engines := []
        }
    sel := []
    if IsObject(SearchCenterSelectedEngines) && SearchCenterSelectedEngines.Length
        sel := SearchCenterSelectedEngines.Clone()
    payload := Map(
        "type", "init",
        "uiMode", "web",
        "currentCategoryKey", "ai",
        "themeMode", _AiWb_GetThemeMode(),
        "engines", engines,
        "selectedEngines", sel,
        "keyword", Trim(String(AiWb_PendingKeyword()))
    )
    AiWb_PostJson(payload)
}

AiWb_PendingKeyword() {
    global g_AiWb_PendingKeyword
    return g_AiWb_PendingKeyword
}

_AiWb_OnWebMessage(sender, args) {
    jsonStr := args.WebMessageAsJson
    try msg := Jxon_Load(jsonStr)
    catch {
        return
    }
    if (msg is String) {
        try msg := Jxon_Load(msg)
        catch {
            return
        }
    }
    if !(msg is Map)
        return
    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ = "ready") {
        global g_AiWb_Ready
        g_AiWb_Ready := true
        AiWb_PushInit()
        SetTimer(_AiWb_NudgeWebBootstrap, -80)
        SetTimer(_AiWb_NudgeWebBootstrap, -350)
        SetTimer(_AiWb_NudgeWebBootstrap, -900)
        return
    }
    if (typ = "close") {
        AiWb_Hide()
        return
    }
    if (typ = "search") {
        kw := msg.Has("keyword") ? Trim(String(msg["keyword"])) : ""
        if (kw != "" && FuncExists("SearchCenterWebLlm_BroadcastSearch")) {
            eng := []
            if msg.Has("selectedEngines") && IsObject(msg["selectedEngines"])
                eng := msg["selectedEngines"]
            else {
                global SearchCenterSelectedEngines
                if IsObject(SearchCenterSelectedEngines)
                    eng := SearchCenterSelectedEngines
            }
            try SearchCenterWebLlm_BroadcastSearch(kw, eng)
            catch as _e {
                NmerCatch(A_ThisFunc, _e)
            }
        }
        return
    }
    if (typ = "syncSelectedEngines") {
        if msg.Has("selectedEngines") {
            if FuncExists("_SCWV_ApplySelectedEnginesFromWeb")
                _SCWV_ApplySelectedEnginesFromWeb(msg["selectedEngines"])
            if FuncExists("ScWebLlm_SyncBroadcastLayoutFromColumnIds") {
                try ScWebLlm_SyncBroadcastLayoutFromColumnIds(msg["selectedEngines"])
                catch {
                }
            }
        }
        if FuncExists("SearchCenterWebLlm_EnsureMissingSites") {
            h := AiWb_GetHostHwnd()
            if h {
                try SearchCenterWebLlm_EnsureMissingSites(false, h)
                catch {
                }
            }
        }
        if FuncExists("SearchCenterWebLlm_ApplyBounds") {
            h := AiWb_GetHostHwnd()
            if h {
                try SearchCenterWebLlm_ApplyBounds(h)
                catch {
                }
            }
        }
        return
    }
    if (typ = "webEmbedDebugAction") {
        if FuncExists("_SCWV_HandleWebEmbedDebugAction")
            _SCWV_HandleWebEmbedDebugAction(msg)
        return
    }
    if FuncExists("SearchCenterWebLlmBridge_HandleMessage") {
        if SearchCenterWebLlmBridge_HandleMessage(msg, "ai_workbench")
            return
    }
}

AiWb_ApplyPendingSearch() {
    global g_AiWb_PendingKeyword, g_AiWb_PendingEngines
    kw := Trim(String(g_AiWb_PendingKeyword))
    if (kw = "")
        return
    if FuncExists("SearchCenterWebLlm_BroadcastSearch") {
        eng := g_AiWb_PendingEngines
        try SearchCenterWebLlm_BroadcastSearch(kw, eng)
        catch {
        }
    }
    g_AiWb_PendingKeyword := ""
    g_AiWb_PendingEngines := []
}

AiWb_Show(meta := 0) {
    if FuncExists("SurfaceIntent_RouteExternalOpen") && SurfaceIntent_RouteExternalOpen("ai_workbench", meta)
        return true
    global g_AiWb_Visible, g_AiWb_Ready, g_AiWb_PendingKeyword, g_AiWb_PendingEngines
    m := (meta is Map) ? meta : Map()
    if m.Has("keyword")
        g_AiWb_PendingKeyword := String(m["keyword"])
    if m.Has("selectedEngines") && IsObject(m["selectedEngines"])
        g_AiWb_PendingEngines := m["selectedEngines"].Clone()
    reqId := 0
    try {
        reqId := SurfaceManager_Request("ai_workbench", "open", "AiWb_Show", m)
        SurfaceManager_BeforeOpen("ai_workbench", "AiWb_Show", Map("requestId", reqId))
        SurfaceManager_RegisterSurface("ai_workbench")
    } catch {
    }
    if FuncExists("Nmer_Telemetry_MarkSurfaceOpen") {
        try Nmer_Telemetry_MarkSurfaceOpen("ai_workbench", Map("source", "AiWb_Show"))
        catch {
        }
    }
    if !g_AiWb_Gui
        AiWb_Init()
    if !g_AiWb_Gui
        return false
    AiWb_BindScWebLlmHost()
    if FuncExists("SearchCenterWebLlm_PrepareForWebModeShow") {
        try SearchCenterWebLlm_PrepareForWebModeShow()
        catch {
        }
    } else if FuncExists("SearchCenterWebLlm_MarkEmbedRequested")
        SearchCenterWebLlm_MarkEmbedRequested()
    ScreenW := SysGet(0)
    ScreenH := SysGet(1)
    w := 1180
    h := 780
    x := (ScreenW - w) // 2
    y := (ScreenH - h) // 2
    try g_AiWb_Gui.Show("x" . x . " y" . y . " w" . w . " h" . h)
    catch {
        try g_AiWb_Gui.Show("Maximize")
        catch {
        }
    }
    g_AiWb_Visible := true
    g_AiWb_LastShown := A_TickCount
    try WebView2_NotifyShown(g_AiWb_WV2)
    _AiWb_RefreshComposition()
    SetTimer(_AiWb_RefreshComposition, -120)
    if g_AiWb_Ready {
        AiWb_PushInit()
        SetTimer(_AiWb_NudgeWebBootstrap, -150)
        SetTimer(_AiWb_NudgeWebBootstrap, -500)
    }
    SetTimer(() => AiWb_ApplyPendingSearch(), -600)
    try SurfaceManager_ObserveShow("ai_workbench", Map("entry", "AiWb_Show", "requestId", reqId))
    try LegacyGuard_RequestFocus("AiWorkbench", g_AiWb_Gui.Hwnd, 40, "ai_workbench_show")
    return true
}

AiWb_Hide(*) {
    global g_AiWb_Visible, g_AiWb_Gui
    if !g_AiWb_Visible && !g_AiWb_Gui
        return false
    if FuncExists("SurfaceIntent_RouteExternalClose") && SurfaceIntent_RouteExternalClose("ai_workbench")
        return true
    g_AiWb_Visible := false
    if FuncExists("SearchCenterWebLlm_TeardownEmbed")
        try SearchCenterWebLlm_TeardownEmbed()
    AiWb_RestoreScWebLlmHost()
    if g_AiWb_Gui {
        try g_AiWb_Gui.Hide()
        catch {
        }
    }
    try WebView2_NotifyHidden(g_AiWb_WV2)
    if FuncExists("Nmer_Telemetry_MarkSurfaceClose") {
        try Nmer_Telemetry_MarkSurfaceClose("ai_workbench", Map("source", "AiWb_Hide"))
        catch {
        }
    }
    try SurfaceManager_ObserveHide("ai_workbench", Map("entry", "AiWb_Hide"))
    return true
}

AiWb_Dispose(reason := "") {
    AiWb_Hide()
    global g_AiWb_Gui, g_AiWb_Ctrl, g_AiWb_WV2, g_AiWb_Ready
    if IsObject(g_AiWb_Ctrl) {
        try g_AiWb_Ctrl.Close()
        catch {
        }
    }
    if IsObject(g_AiWb_Gui) {
        try g_AiWb_Gui.Destroy()
        catch {
        }
    }
    g_AiWb_Gui := 0
    g_AiWb_Ctrl := 0
    g_AiWb_WV2 := 0
    g_AiWb_Ready := false
    try SurfaceManager_ObserveClose("ai_workbench", Map("entry", "AiWb_Dispose", "reason", reason))
}

AiWorkbenchRouter_Open(meta := 0) {
    return AiWb_Show(meta)
}

AiWorkbenchRouter_Hide(*) {
    return AiWb_Hide()
}

AiWorkbenchRouter_Dispose(reason := "") {
    AiWb_Dispose(reason)
}
