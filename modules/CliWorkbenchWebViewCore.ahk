; CliWorkbenchWebViewCore.ahk — CLI 终端工作台独立 Surface（ttyd 多引擎）
#Requires AutoHotkey v2.0

global g_CliWb_Gui := 0
global g_CliWb_Ctrl := 0
global g_CliWb_WV2 := 0
global g_CliWb_Ready := false
global g_CliWb_Visible := false
global g_CliWb_LastShown := 0
global g_CliWb_PendingKeyword := ""
global g_CliWb_PendingEngine := "codex_cli"
global g_CliWb_CliTerminalFocus := false
global g_CliWb_UserMinimized := false
global g_CliWb_DeactivateBlockUntil := 0

CliWb_GetGui() {
    global g_CliWb_Gui
    return g_CliWb_Gui
}

CliWb_IsVisible() {
    global g_CliWb_Visible
    return !!g_CliWb_Visible
}

CliWb_PostJson(payload) {
    global g_CliWb_WV2, g_CliWb_Ready
    if !g_CliWb_Ready || !IsObject(g_CliWb_WV2)
        return
    if (payload is Map)
        WebView_QueuePayload(g_CliWb_WV2, payload)
    else
        WebView_QueueJson(g_CliWb_WV2, payload)
}

_CliWb_GetWebView2Class() {
    try return WebView2
    catch {
        return 0
    }
}

_CliWb_BlockDeactivate(ms := 3000, reason := "") {
    global g_CliWb_DeactivateBlockUntil
    g_CliWb_DeactivateBlockUntil := A_TickCount + Max(200, Integer(ms))
}

CliWb_Init() {
    global g_CliWb_Gui
    if g_CliWb_Gui
        return
    try SurfaceManager_ObserveInit("cli_workbench", Map("entry", "CliWb_Init"))
    g_CliWb_Gui := Gui("+Resize +MinSize720x480 +MinimizeBox +MaximizeBox +Caption -DPIScale", "CLI 工作台")
    g_CliWb_Gui.BackColor := "0d1016"
    g_CliWb_Gui.MarginX := 0
    g_CliWb_Gui.MarginY := 0
    g_CliWb_Gui.OnEvent("Close", (*) => CliWb_Hide())
    g_CliWb_Gui.OnEvent("Size", _CliWb_OnGuiResize)
    g_CliWb_Gui.Show("w1100 h760 Hide")
    WebView2_CreateWithSharedEnvAsync(g_CliWb_Gui.Hwnd, _CliWb_OnWV2Created, "cli_workbench")
}

_CliWb_OnWV2Created(ctrl) {
    global g_CliWb_Ctrl, g_CliWb_WV2
    g_CliWb_Ctrl := ctrl
    g_CliWb_WV2 := ctrl.CoreWebView2
    try g_CliWb_Ctrl.DefaultBackgroundColor := 0xFF0D1016
    try g_CliWb_Ctrl.IsVisible := true
    _CliWb_ApplyBounds()
    s := g_CliWb_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.AreDevToolsEnabled := false
    if FuncExists("ApplyWebView2PerformanceSettings")
        ApplyWebView2PerformanceSettings(g_CliWb_WV2)
    if FuncExists("WebView2_RegisterHostBridge")
        WebView2_RegisterHostBridge(g_CliWb_WV2)
    g_CliWb_WV2.add_WebMessageReceived(_CliWb_OnWebMessage)
    try g_CliWb_WV2.add_NavigationCompleted(_CliWb_OnNavigationCompleted)
    try ApplyUnifiedWebViewAssets(g_CliWb_WV2)
    g_CliWb_WV2.Navigate(BuildAppLocalUrl("CliWorkbench.html"))
    global g_CliWb_Visible
    if g_CliWb_Visible {
        try WebView2_NotifyShown(g_CliWb_WV2)
        _CliWb_RefreshComposition()
        SetTimer(_CliWb_NudgeCliBootstrap, -120)
    }
}

_CliWb_NudgeCliBootstrap(*) {
    global g_CliWb_Visible, g_CliWb_WV2, g_CliWb_Ready
    if !g_CliWb_Visible || !g_CliWb_Ready || !IsObject(g_CliWb_WV2)
        return
    try WebView2_NotifyShown(g_CliWb_WV2)
    _CliWb_RefreshComposition()
    CliWb_PostJson(Map("type", "hostLayout"))
    CliWb_PostJson(Map("type", "hostPaintNudge", "reason", "bootstrap"))
    SetTimer(_CliWb_EnsureTtydForActiveEngine, -40)
}

_CliWb_ApplyBounds() {
    global g_CliWb_Gui, g_CliWb_Ctrl
    if !g_CliWb_Ctrl || !g_CliWb_Gui
        return
    WinGetClientPos(, , &cw, &ch, g_CliWb_Gui.Hwnd)
    WV2 := _CliWb_GetWebView2Class()
    if !WV2
        return
    rc := WV2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    g_CliWb_Ctrl.Bounds := rc
}

_CliWb_OnGuiResize(GuiObj, MinMax, Width, Height) {
    if (MinMax = -1)
        return
    _CliWb_ApplyBounds()
}

_CliWb_OnNavigationCompleted(sender, args) {
    global g_CliWb_Visible, g_CliWb_Ready
    try ok := args.IsSuccess
    catch {
        ok := true
    }
    if !ok
        return
    if !g_CliWb_Visible
        return
    _CliWb_RefreshComposition()
    if g_CliWb_Ready {
        CliWb_PushInit()
        SetTimer(() => CliWb_ApplyPendingSend(), -400)
    }
    SetTimer(_CliWb_NudgeCliBootstrap, -80)
}

_CliWb_RefreshComposition(*) {
    global g_CliWb_Ctrl, g_CliWb_Gui, g_CliWb_Visible
    if !g_CliWb_Visible || !g_CliWb_Ctrl || !g_CliWb_Gui
        return
    try {
        _CliWb_ApplyBounds()
        g_CliWb_Ctrl.NotifyParentWindowPositionChanged()
    } catch {
    }
}

_CliWb_GetThemeMode() {
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

_CliWb_BuildCliEnginePayload() {
    static labels := Map(
        "codex_cli", "Codex",
        "gemini_cli", "Gemini",
        "openclaw_cli", "OpenClaw",
        "qwen_cli", "通义千问",
        "ollama_cli", "Ollama",
        "claude_cli", "Claude",
        "deepseek_cli", "DeepSeek",
        "kimi_cli", "Kimi",
        "zhipu_cli", "智谱",
        "copilot_cli", "Copilot"
    )
    payload := []
    for eng in NiumaTtyd_CliEngineList() {
        if (eng = "studio_cli")
            continue
        payload.Push(Map(
            "name", labels.Has(eng) ? labels[eng] : eng,
            "value", eng,
            "iconUrl", ""
        ))
    }
    return payload
}

_CliWb_EnsureTtydForActiveEngine(*) {
    global g_CliWb_WV2, g_CliWb_PendingEngine, g_CliWb_Visible
    if !g_CliWb_Visible || !IsObject(g_CliWb_WV2)
        return
    eng := Trim(String(g_CliWb_PendingEngine))
    if (eng = "")
        eng := "codex_cli"
    try eng := NiumaTtyd_NormalizeEngine(eng)
    catch {
        eng := "codex_cli"
    }
    SetTimer(NiumaTtyd_DeferredOpenJob.Bind("", eng, g_CliWb_WV2), -10)
}

CliWb_PushInit() {
    engines := _CliWb_BuildCliEnginePayload()
    global g_CliWb_PendingKeyword, g_CliWb_PendingEngine
    eng := Trim(String(g_CliWb_PendingEngine))
    if (eng = "")
        eng := "codex_cli"
    payload := Map(
        "type", "init",
        "uiMode", "cli",
        "currentCategoryKey", "cli",
        "themeMode", _CliWb_GetThemeMode(),
        "engines", engines,
        "activeCliEngine", eng,
        "keyword", Trim(String(g_CliWb_PendingKeyword))
    )
    CliWb_PostJson(payload)
    SetTimer(_CliWb_EnsureTtydForActiveEngine, -280)
}

_CliWb_OnWebMessage(sender, args) {
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
        global g_CliWb_Ready
        g_CliWb_Ready := true
        CliWb_PushInit()
        SetTimer(_CliWb_NudgeCliBootstrap, -80)
        SetTimer(_CliWb_NudgeCliBootstrap, -350)
        SetTimer(_CliWb_NudgeCliBootstrap, -900)
        SetTimer(() => CliWb_ApplyPendingSend(), -500)
        return
    }
    if (typ = "close") {
        CliWb_Hide()
        return
    }
    if (typ = "vk_compose") {
        act := msg.Has("action") ? StrLower(Trim(String(msg["action"]))) : ""
        if (act = "send" || act = "run") {
            kw := msg.Has("keyword") ? String(msg["keyword"]) : ""
            eng := msg.Has("engine") ? Trim(String(msg["engine"])) : ""
            ScCli_SendToCLI(kw, eng)
        }
        return
    }
    if FuncExists("SearchCenterCliBridge_HandleMessage") {
        global g_CliWb_WV2
        if SearchCenterCliBridge_HandleMessage(msg, "cli_workbench", g_CliWb_WV2)
            return
    }
}

CliWb_ApplyPendingSend() {
    global g_CliWb_PendingKeyword, g_CliWb_PendingEngine
    kw := Trim(String(g_CliWb_PendingKeyword))
    if (kw = "")
        return
    ScCli_SendToCLI(kw, g_CliWb_PendingEngine)
    g_CliWb_PendingKeyword := ""
}

CliWb_Show(meta := 0) {
    if FuncExists("SurfaceIntent_RouteExternalOpen") && SurfaceIntent_RouteExternalOpen("cli_workbench", meta)
        return true
    global g_CliWb_Visible, g_CliWb_Ready, g_CliWb_PendingKeyword, g_CliWb_PendingEngine, g_CliWb_UserMinimized
    m := (meta is Map) ? meta : Map()
    if m.Has("keyword")
        g_CliWb_PendingKeyword := String(m["keyword"])
    if m.Has("engine")
        g_CliWb_PendingEngine := Trim(String(m["engine"]))
    else if m.Has("activeCliEngine")
        g_CliWb_PendingEngine := Trim(String(m["activeCliEngine"]))
    reqId := 0
    try {
        reqId := SurfaceManager_Request("cli_workbench", "open", "CliWb_Show", m)
        SurfaceManager_BeforeOpen("cli_workbench", "CliWb_Show", Map("requestId", reqId))
        SurfaceManager_RegisterSurface("cli_workbench")
    } catch {
    }
    if FuncExists("Nmer_Telemetry_MarkSurfaceOpen") {
        try Nmer_Telemetry_MarkSurfaceOpen("cli_workbench", Map("source", "CliWb_Show"))
        catch {
        }
    }
    if !g_CliWb_Gui
        CliWb_Init()
    if !g_CliWb_Gui
        return false
    g_CliWb_UserMinimized := false
    ScreenW := SysGet(0)
    ScreenH := SysGet(1)
    w := 1100
    h := 760
    x := (ScreenW - w) // 2
    y := (ScreenH - h) // 2
    try g_CliWb_Gui.Show("x" . x . " y" . y . " w" . w . " h" . h)
    catch {
        try g_CliWb_Gui.Show("Maximize")
        catch {
        }
    }
    g_CliWb_Visible := true
    g_CliWb_LastShown := A_TickCount
    try WebView2_NotifyShown(g_CliWb_WV2)
    _CliWb_RefreshComposition()
    SetTimer(_CliWb_RefreshComposition, -120)
    if g_CliWb_Ready {
        CliWb_PushInit()
        SetTimer(_CliWb_NudgeCliBootstrap, -150)
        SetTimer(_CliWb_NudgeCliBootstrap, -500)
    }
    try SurfaceManager_ObserveShow("cli_workbench", Map("entry", "CliWb_Show", "requestId", reqId))
    try LegacyGuard_RequestFocus("CliWorkbench", g_CliWb_Gui.Hwnd, 40, "cli_workbench_show")
    return true
}

CliWb_Hide(*) {
    global g_CliWb_Visible, g_CliWb_Gui, g_CliWb_CliTerminalFocus
    if !g_CliWb_Visible && !g_CliWb_Gui
        return false
    if FuncExists("SurfaceIntent_RouteExternalClose") && SurfaceIntent_RouteExternalClose("cli_workbench")
        return true
    g_CliWb_Visible := false
    g_CliWb_CliTerminalFocus := false
    if g_CliWb_Gui {
        try g_CliWb_Gui.Hide()
        catch {
        }
    }
    try WebView2_NotifyHidden(g_CliWb_WV2)
    if FuncExists("Nmer_Telemetry_MarkSurfaceClose") {
        try Nmer_Telemetry_MarkSurfaceClose("cli_workbench", Map("source", "CliWb_Hide"))
        catch {
        }
    }
    try SurfaceManager_ObserveHide("cli_workbench", Map("entry", "CliWb_Hide"))
    return true
}

CliWb_Dispose(reason := "") {
    CliWb_Hide()
    global g_CliWb_Gui, g_CliWb_Ctrl, g_CliWb_WV2, g_CliWb_Ready
    if IsObject(g_CliWb_Ctrl) {
        try g_CliWb_Ctrl.Close()
        catch {
        }
    }
    if IsObject(g_CliWb_Gui) {
        try g_CliWb_Gui.Destroy()
        catch {
        }
    }
    g_CliWb_Gui := 0
    g_CliWb_Ctrl := 0
    g_CliWb_WV2 := 0
    g_CliWb_Ready := false
    try SurfaceManager_ObserveClose("cli_workbench", Map("entry", "CliWb_Dispose", "reason", reason))
}

CliWorkbenchRouter_Open(meta := 0) {
    return CliWb_Show(meta)
}

CliWorkbenchRouter_Hide(*) {
    return CliWb_Hide()
}

CliWorkbenchRouter_Dispose(reason := "") {
    CliWb_Dispose(reason)
}
