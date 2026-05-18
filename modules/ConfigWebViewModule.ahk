; ConfigWebViewModule.ahk 鈥?璁剧疆涓績 WebView 瀹夸富涓庢秷鎭ˉ锛堢敱涓昏剼鏈?#Include锛?
; 渚濊禆锛歐ebView2銆乄MActivateChain銆丣xon銆佷富鑴氭湰鍏ㄥ眬涓?BuildAppLocalUrl / WebView_DumpJson 绛夈€?

global ConfigWebViewNavFallbackTried := false

ConfigWebView_StaleDomain(pathKey) {
    return "config:" . Trim(String(pathKey))
}

ConfigWebView_MarkLatestReq(pathKey, reqId) {
    k := Trim(String(pathKey))
    rid := Trim(String(reqId))
    if (k = "" || rid = "")
        return
    if FuncExists("AsyncGuardrails_UpdateLatest")
        AsyncGuardrails_UpdateLatest(ConfigWebView_StaleDomain(k), rid)
}

ConfigWebView_LogStaleDrop(pathKey, reqId) {
    try CoreAsyncHttp_Log("config_drop_stale_req", "path=" . String(pathKey) . " req_id=" . String(reqId))
}

ConfigWebView_ShouldDropReq(pathKey, reqId) {
    k := Trim(String(pathKey))
    rid := Trim(String(reqId))
    if (k = "" || rid = "")
        return false
    if FuncExists("AsyncGuardrails_ShouldDropStale")
        return AsyncGuardrails_ShouldDropStale(ConfigWebView_StaleDomain(k), rid)
    return false
}

ConfigWebView_HttpJsonAsync(method, url, body := "", callback := 0, reqId := 0) {
    cb := IsObject(callback) ? callback : 0
    rid := Trim(String(reqId))
    pathKey := String(url)
    if RegExMatch(pathKey, "://[^/]+(/.*)$", &m)
        pathKey := m[1]
    if (rid != "")
        ConfigWebView_MarkLatestReq(pathKey, rid)
    HttpJsonAsync(method, url, body, (resp) => (
        (rid != "" && ConfigWebView_ShouldDropReq(pathKey, rid))
            ? (ConfigWebView_LogStaleDrop(pathKey, rid), 0)
            : (cb ? cb.Call(resp) : 0)
    ), Map("timeoutMs", 2600, "reqId", reqId, "tag", "cfg_http_json"))
}

ConfigWebView_HostAlive() {
    global GuiID_ConfigGUI
    try {
        if !(IsObject(GuiID_ConfigGUI) && GuiID_ConfigGUI)
            return false
        hwnd := GuiID_ConfigGUI.Hwnd
        if !hwnd
            return false
        return !!WinExist("ahk_id " . hwnd)
    } catch {
        return false
    }
}

ConfigWebView_CreateHost() {
    global GuiID_ConfigGUI, ConfigWebViewMode, ConfigWV2Ready, ConfigWebViewPreloaded, ConfigWebViewNavFallbackTried
    global ConfigWV2Ctrl, ConfigWV2

    if (GuiID_ConfigGUI != 0) {
        if (ConfigWebView_HostAlive())
            return
        try {
            WMActivateChain_Unregister(ConfigWebView_WM_ACTIVATE)
        } catch {
        }
        GuiID_ConfigGUI := 0
        ConfigWebViewMode := false
        ConfigWV2Ready := false
        ConfigWV2Ctrl := 0
        ConfigWV2 := 0
        ConfigWebViewPreloaded := false
        ConfigWebViewNavFallbackTried := false
    }

    ConfigGUI := Gui("+Resize +MinimizeBox +MaximizeBox +Owner", GetText("config_title"))
    ConfigGUI.BackColor := "0a0a0a"

    GuiID_ConfigGUI := ConfigGUI
    ConfigWebViewMode := true
    ConfigWV2Ready := false
    ConfigWV2Ctrl := 0
    ConfigWV2 := 0
    ConfigWebViewPreloaded := false
    ConfigWebViewNavFallbackTried := false

    ConfigGUI.OnEvent("Close", (*) => CloseConfigGUI())
    ConfigGUI.OnEvent("Escape", (*) => CloseConfigGUI())
    ConfigGUI.OnEvent("Size", ConfigWebView_OnSize)
    ConfigGUI.Show("w980 h680 Hide")

    WebView2_CreateWithSharedEnvAsync(ConfigGUI.Hwnd, ConfigWebView_OnCreated, "config")
}

; 寤跺悗涓€甯ф帹閫?initData锛岄伩鍏嶄粠鎮诞宸ュ叿鏍忕瓑 WebView 鐨?WebMessageReceived 鍐呭悓姝ヨ皟鐢ㄦ椂閲嶅叆/闃熷垪椤哄簭寮傚父瀵艰嚧涓婚閿欎负娣辫壊
ConfigWebView_SendInitDataIfReady(*) {
    global ConfigWV2Ready
    try {
        if IsSet(ConfigWV2Ready) && ConfigWV2Ready
            ConfigWebView_Send(Map("type", "initData", "payload", ConfigWebView_BuildInitDataSafe()))
    }
}

ShowConfigWebViewGUI() {
    global GuiID_ConfigGUI, GuiID_ClipboardManager, ConfigPanelScreenIndex, g_ConfigWebView_LastShown
    try FloatingToolbar_PageDockEnter("settings")
    ; 鍗曚緥
    ConfigWebView_CreateHost()
    if !GuiID_ConfigGUI
        return
    HideClipboardPanelsForConfigConflict()

    ScreenInfo := GetScreenInfo(ConfigPanelScreenIndex)
    WinW := Max(980, Round(ScreenInfo.Width * 0.80))
    WinH := Max(680, Round(ScreenInfo.Height * 0.80))
    PosX := ScreenInfo.Left + Round((ScreenInfo.Width - WinW) / 2)
    PosY := ScreenInfo.Top + Round((ScreenInfo.Height - WinH) / 2)

    GuiID_ConfigGUI.Show("w" . WinW . " h" . WinH . " x" . PosX . " y" . PosY)
    try WinSetAlwaysOnTop(true, "ahk_id " . GuiID_ConfigGUI.Hwnd)
    catch {
    }
    try LegacyGuard_RequestFocus("ConfigWebView", GuiID_ConfigGUI.Hwnd, 20, "show_config_webview", 220)
    catch {
    }
    g_ConfigWebView_LastShown := A_TickCount
    WMActivateChain_Register(ConfigWebView_WM_ACTIVATE)
    ConfigWebView_ApplyBounds()
    ConfigWebView_RefreshWebViewComposition()
    SetTimer(ConfigWebView_RefreshWebViewComposition, -30)
    SetTimer(ConfigWebView_RefreshWebViewComposition, -120)
    SetTimer(ConfigWebView_RefreshWebViewComposition, -380)
    SetTimer(ConfigWebView_RefreshRasterizationScale, -50)
    SetTimer(ConfigWebView_RefreshRasterizationScale, -150)
    SetTimer(ConfigWebView_FocusDeferred, -80)
    SetTimer(ConfigWebView_EnsureVisibleOrRecover, -420)
    global ConfigWV2, ConfigWV2Ready
    try WebView2_NotifyShown(ConfigWV2)
    ; 姣忔鎵撳紑閮介噸鏂版帹閫?initData锛堝欢鍚庝竴甯э級锛岀‘淇濅富棰樼瓑涓?INI 涓€鑷翠笖閬垮紑 WebView 鍥炶皟閲嶅叆
    SetTimer(ConfigWebView_SendInitDataIfReady, -10)
}

ConfigWebView_EnsureVisibleOrRecover(*) {
    if (ThemeApply_IsInProgress() || ActivationApply_IsInProgress()) {
        SetTimer(ConfigWebView_EnsureVisibleOrRecover, -180)
        return
    }
    if ConfigWebView_HostAlive() {
        try ConfigWebView_RefocusAfterThemeChange()
        catch {
        }
        return
    }
    if !ConfigWebView_HostAlive() {
        try ConfigWebView_ReleaseSettingsDock("host_dead")
        catch {
        }
        try SetTimer(ShowConfigGUI_FallbackCheck, -10)
        catch {
        }
    }
}

ConfigWebView_OnCreated(ctrl) {
    global ConfigWV2Ctrl, ConfigWV2, GuiID_ConfigGUI, ConfigWebViewPreloaded
    ConfigWV2Ctrl := ctrl
    ConfigWV2 := ctrl.CoreWebView2
    try ConfigWV2Ctrl.DefaultBackgroundColor := 0xFF0A0A0A
    s := ConfigWV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.AreDevToolsEnabled := true
    ApplyWebView2PerformanceSettings(ConfigWV2)
    WebView2_RegisterHostBridge(ConfigWV2)
    ConfigWV2.add_WebMessageReceived(ConfigWebView_OnMessage)
    try ConfigWV2.add_NavigationCompleted(ConfigWebView_OnNavigationCompleted)
    ConfigWebView_ApplyBounds()
    try ApplyUnifiedWebViewAssets(ConfigWV2)
    try ConfigWV2Ctrl.IsVisible := true
    htmlPath := A_ScriptDir "\SettingsPanel.html"
    try {
        ConfigWV2.Navigate(BuildAppLocalUrl("SettingsPanel.html"))
    } catch as e {
        OutputDebug("[ConfigWV2] Navigate app.local: " . e.Message)
        if FileExist(htmlPath) {
            try ConfigWV2.NavigateToString(FileRead(htmlPath, "UTF-8"))
            catch as e2 {
                OutputDebug("[ConfigWV2] NavigateToString fallback: " . e2.Message)
            }
        }
    }
    ConfigWebViewPreloaded := true
}

ConfigWebView_OnNavigationCompleted(sender, args) {
    global ConfigWebViewNavFallbackTried
    try ok := args.IsSuccess
    catch as e
        ok := true
    if ok {
        if ConfigWebView_HostWindowVisible()
            ConfigWebView_RefreshWebViewComposition()
        return
    }
    if !ConfigWebViewNavFallbackTried {
        ConfigWebViewNavFallbackTried := true
        fileUrl := "file:///" . StrReplace(A_ScriptDir . "\SettingsPanel.html", "\", "/")
        try {
            sender.Navigate(fileUrl)
            return
        } catch {
        }
    }
    try {
        sender.NavigateToString("<!doctype html><html><body style='background:#111;color:#eee;font-family:Segoe UI;padding:16px'>璁剧疆闈㈡澘椤甸潰鍔犺浇澶辫触銆傝閲嶅惎鑴氭湰鍚庨噸璇曘€?/body></html>")
    } catch as e {
        OutputDebug("[ConfigWV2] error page failed: " . e.Message)
    }
}

ConfigWebView_OnSize(*) {
    ConfigWebView_ApplyBounds()
}

ConfigWebView_ApplyBounds() {
    global GuiID_ConfigGUI, ConfigWV2Ctrl
    if !GuiID_ConfigGUI || !ConfigWV2Ctrl
        return
    WinGetClientPos(, , &cw, &ch, GuiID_ConfigGUI.Hwnd)
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    ConfigWV2Ctrl.Bounds := rc
}

; WebView2锛氬厛 Hide 鍐?Show 鐨勫涓诲彲鑳介粦灞忥紝闇€鍒锋柊鍚堟垚锛堜笌 ClipboardPanel / VK 涓€鑷达級
ConfigWebView_RefreshWebViewComposition(*) {
    global GuiID_ConfigGUI, ConfigWV2Ctrl
    if !GuiID_ConfigGUI || !ConfigWV2Ctrl
        return
    try {
        ConfigWebView_ApplyBounds()
        ConfigWV2Ctrl.NotifyParentWindowPositionChanged()
    } catch as e {
        OutputDebug("[ConfigWV2] RefreshWebViewComposition: " . e.Message)
    }
}

; 瑙﹀彂 RasterizationScale 鍐欏洖锛岀紦瑙ｉ珮 DPI / -DPIScale 涓嬪伓鍙戞ā绯?
ConfigWebView_RefreshRasterizationScale(*) {
    global ConfigWV2Ctrl
    if !ConfigWV2Ctrl
        return
    try {
        sc := ConfigWV2Ctrl.RasterizationScale
        ConfigWV2Ctrl.RasterizationScale := sc
    } catch as e {
        OutputDebug("[ConfigWV2] RefreshRasterizationScale: " . e.Message)
    }
}

ConfigWebView_HostWindowVisible() {
    global GuiID_ConfigGUI
    if !GuiID_ConfigGUI
        return false
    return WinExist("ahk_id " . GuiID_ConfigGUI.Hwnd) && (WinGetStyle("ahk_id " . GuiID_ConfigGUI.Hwnd) & 0x10000000)
}

ConfigWebView_FocusDeferred(*) {
    global GuiID_ConfigGUI, ConfigWV2Ctrl
    if GuiID_ConfigGUI {
        try LegacyGuard_RequestFocus("ConfigWebView", GuiID_ConfigGUI.Hwnd, 20, "focus_deferred", 180)
        WebView2_MoveFocusProgrammatic(ConfigWV2Ctrl)
    }
}

ConfigWebView_RefocusAfterThemeChange(*) {
    global GuiID_ConfigGUI, ConfigWV2Ctrl
    if !ConfigWebView_HostAlive()
        return
    try WinSetAlwaysOnTop(true, "ahk_id " . GuiID_ConfigGUI.Hwnd)
    catch {
    }
    try LegacyGuard_RequestFocus("ConfigWebView", GuiID_ConfigGUI.Hwnd, 20, "refocus_after_theme", 220)
    catch {
    }
    try WebView2_MoveFocusProgrammatic(ConfigWV2Ctrl)
    catch {
    }
}

ConfigWebView_ReleaseSettingsDock(reason := "") {
    try FloatingToolbar_PageDockLeave("settings")
    catch {
    }
}

ConfigWebView_WM_ACTIVATE(wParam, lParam, msg, hwnd) {
    global GuiID_ConfigGUI, ConfigWebViewMode, g_ConfigWebView_LastShown
    if !ConfigWebViewMode || !GuiID_ConfigGUI
        return
    if (hwnd = GuiID_ConfigGUI.Hwnd && (wParam & 0xFFFF) = 0) {
        try {
            if ThemeApply_IsInProgress()
                return
        } catch {
        }
        try {
            if (FloatingToolbar_IsForegroundToolbarOrChild())
                return
        } catch {
        }
        ; 鍒?Show 鍚庣煭鏃堕棿鍐呭彲鑳芥敹鍒板け鐒︼紙涓庣疆椤舵偓娴潯鎶㈢劍鐐癸級锛屽嬁绔嬪嵆鍏抽棴
        if (g_ConfigWebView_LastShown && (A_TickCount - g_ConfigWebView_LastShown < 500))
            return
        SetTimer(CloseConfigGUI, -50)
    }
}

ConfigWebView_Send(msgMap) {
    global ConfigWV2, ConfigWV2Ready
    if !ConfigWV2 || !ConfigWV2Ready
        return
    WebView_QueuePayload(ConfigWV2, msgMap)
}

ConfigWebView_EnsureSearchCoreRunning() {
    if ProcessExist("SearchCenterCore.exe")
        return true
    exe := ConfigWebView_SearchCoreExePath()
    if !FileExist(exe)
        return false
    try {
        Run('"' exe '" -base "' A_ScriptDir '"', A_ScriptDir, "Hide")
        return true
    } catch {
    }
    return false
}

ConfigWebView_SearchCoreExePath() {
    preferred := A_ScriptDir "\searchcore\SearchCenterCore.exe"
    if FileExist(preferred)
        return preferred
    fallback := A_ScriptDir "\SearchCenterCore.exe"
    if FileExist(fallback)
        return fallback
    return ""
}

ConfigWebView_HttpSearchCoreJsonRaw(method, path, body := "") {
    return Map("status", 0, "text", "", "json", 0, "error", "sync_http_disabled")
}

ConfigWebView_HttpSearchCoreJson(method, path, body := "") {
    return ConfigWebView_HttpSearchCoreJsonRaw(method, path, body)
}

ConfigWebView_HttpSearchCoreJsonAsync(method, path, body := "", callback := 0, reqId := 0) {
    url := "http://127.0.0.1:8080" . path
    ConfigWebView_HttpJsonAsync(method, url, body, callback, reqId)
}

ConfigWebView_HealthProbeAsync(callback := 0) {
    cb := IsObject(callback) ? callback : 0
    HttpGetAsync("http://127.0.0.1:8080/health", (resp) => (
        cb ? cb.Call((resp.Has("status") && Integer(resp["status"]) = 200), resp) : 0
    ), Map("timeoutMs", 2200, "reqId", 0, "tag", "cfg_health_probe"))
}

ConfigWebView_HttpProbeSearchCoreAsync(callback := 0) {
    ConfigWebView_HealthProbeAsync(callback)
}

ConfigWebView_EnsureSearchCoreRunningAsync(callback := 0, retry := 0) {
    cb := IsObject(callback) ? callback : 0
    if ProcessExist("SearchCenterCore.exe") {
        ConfigWebView_HealthProbeAsync((ok, resp) => ConfigWebView_EnsureSearchCoreRunningAsync_OnProbe(ok, cb, retry))
        return
    }
    if !ConfigWebView_EnsureSearchCoreRunning() {
        cb ? cb.Call(false) : 0
        return
    }
    if (retry >= 5) {
        cb ? cb.Call(false) : 0
        return
    }
    SetTimer((*) => ConfigWebView_EnsureSearchCoreRunningAsync(cb, retry + 1), -220)
}

ConfigWebView_EnsureSearchCoreRunningAsync_OnProbe(ok, cb, retry) {
    if ok {
        if cb
            cb.Call(true)
        return
    }
    if ConfigWebView_EnsureSearchCoreRunning() {
        SetTimer((*) => ConfigWebView_EnsureSearchCoreRunningAsync(cb, retry + 1), -220)
        return
    }
    if cb
        cb.Call(false)
}

ConfigWebView_MergeMap(target, source) {
    if !(target is Map) || !(source is Map)
        return target
    for k, v in source
        target[k] := v
    return target
}

ConfigWebView_DefaultFullTextStatusPayload() {
    return Map(
        "running", false,
        "ready", false,
        "progress", 0,
        "progressText", "0.0%",
        "indexing_file", "",
        "indexVersion", "",
        "engine_lights", ["off", "off", "off", "off"],
        "workerCount", 0,
        "scanSpeed", "normal",
        "includeLargeText", false,
        "maxFileSizeMB", 2,
        "indexDir", "",
        "lastError", ""
    )
}

ConfigWebView_PostFullTextStatus(withConfig := true) {
    payload := ConfigWebView_DefaultFullTextStatusPayload()
    ConfigWebView_EnsureSearchCoreRunningAsync((ok) => ConfigWebView_PostFullTextStatus_Continue(ok, withConfig, payload))
}

ConfigWebView_PostFullTextStatus_Continue(ok, withConfig, payload) {
    if !ok {
        ConfigWebView_Send(Map("type", "fulltextStatus", "payload", payload))
        return
    }
    ConfigWebView_HttpSearchCoreJsonAsync("GET", "/v1/fulltext/status", "", (stResp) => ConfigWebView_PostFullTextStatus_AfterStatus(stResp, withConfig, payload))
}

ConfigWebView_PostFullTextStatus_AfterStatus(stResp, withConfig, payload) {
    if (stResp is Map && stResp.Has("status") && Integer(stResp["status"]) = 200 && stResp.Has("json") && (stResp["json"] is Map))
        payload := ConfigWebView_MergeMap(payload, stResp["json"])
    ConfigWebView_HttpSearchCoreJsonAsync("GET", "/v1/fulltext/progress", "", (pgResp) => ConfigWebView_PostFullTextStatus_AfterProgress(pgResp, withConfig, payload))
}

ConfigWebView_PostFullTextStatus_AfterProgress(pgResp, withConfig, payload) {
    if (pgResp is Map && pgResp.Has("status") && Integer(pgResp["status"]) = 200 && pgResp.Has("json") && (pgResp["json"] is Map))
        payload := ConfigWebView_MergeMap(payload, pgResp["json"])
    if !withConfig {
        ConfigWebView_Send(Map("type", "fulltextStatus", "payload", payload))
        return
    }
    ConfigWebView_HttpSearchCoreJsonAsync("GET", "/v1/fulltext/config", "", (cfgResp) => ConfigWebView_PostFullTextStatus_AfterConfig(cfgResp, payload))
}

ConfigWebView_PostFullTextStatus_AfterConfig(cfgResp, payload) {
    if (cfgResp is Map && cfgResp.Has("status") && Integer(cfgResp["status"]) = 200 && cfgResp.Has("json") && (cfgResp["json"] is Map)) {
        root := cfgResp["json"]
        if (root.Has("config"))
            payload["config"] := root["config"]
        if (root.Has("status") && (root["status"] is Map))
            payload := ConfigWebView_MergeMap(payload, root["status"])
        if (root.Has("progress") && (root["progress"] is Map))
            payload := ConfigWebView_MergeMap(payload, root["progress"])
    }
    ConfigWebView_Send(Map("type", "fulltextStatus", "payload", payload))
}

ConfigWebView_FullTextControl(action) {
    act := StrLower(Trim(String(action)))
    if (act = "")
        act := "start"
    ConfigWebView_EnsureSearchCoreRunningAsync((ok) => ConfigWebView_FullTextControl_Continue(ok, act))
}

ConfigWebView_FullTextControl_Continue(ok, act) {
    if !ok {
        ConfigWebView_Send(Map("type", "fulltextActionResult", "ok", false, "action", act, "error", "SearchCenterCore not running"))
        ConfigWebView_PostFullTextStatus(true)
        return
    }
    ConfigWebView_HttpSearchCoreJsonAsync("POST", "/v1/fulltext/control", Jxon_Dump(Map("action", act)), (resp) => ConfigWebView_FullTextControl_After(resp, act))
}

ConfigWebView_FullTextControl_After(resp, act) {
    ok := (resp is Map) && resp.Has("status") && Integer(resp["status"]) = 200
    err := ""
    if !ok
        err := (resp is Map && resp.Has("text")) ? String(resp["text"]) : "HTTP 0"
    ConfigWebView_Send(Map("type", "fulltextActionResult", "ok", ok, "action", act, "error", err))
    ConfigWebView_PostFullTextStatus(true)
}

ConfigWebView_FullTextUpdateConfig(payload) {
    if !(payload is Map) {
        ConfigWebView_Send(Map("type", "fulltextConfigResult", "ok", false, "error", "invalid payload"))
        return
    }
    ConfigWebView_EnsureSearchCoreRunningAsync((ok) => ConfigWebView_FullTextUpdateConfig_Continue(ok, payload))
}

ConfigWebView_FullTextUpdateConfig_Continue(ok, payload) {
    if !ok {
        ConfigWebView_Send(Map("type", "fulltextConfigResult", "ok", false, "error", "SearchCenterCore not running"))
        ConfigWebView_PostFullTextStatus(true)
        return
    }
    ConfigWebView_HttpSearchCoreJsonAsync("POST", "/v1/fulltext/config", Jxon_Dump(payload), (resp) => ConfigWebView_FullTextUpdateConfig_After(resp))
}

ConfigWebView_FullTextUpdateConfig_After(resp) {
    ok := (resp is Map) && resp.Has("status") && Integer(resp["status"]) = 200
    err := ""
    if !ok
        err := (resp is Map && resp.Has("text")) ? String(resp["text"]) : "HTTP 0"
    ConfigWebView_Send(Map("type", "fulltextConfigResult", "ok", ok, "error", err))
    ConfigWebView_PostFullTextStatus(true)
}

ConfigWebView_FullTextProbe() {
    ConfigWebView_EnsureSearchCoreRunningAsync((ok) => ConfigWebView_FullTextProbe_Continue(ok))
}

ConfigWebView_FullTextProbe_Continue(okRunning) {
    if !okRunning {
        ConfigWebView_Send(Map("type", "fulltextProbeResult", "ok", false, "error", "SearchCenterCore not running", "probe", 0))
        return
    }
    ConfigWebView_HttpSearchCoreJsonAsync("GET", "/v1/fulltext/probe", "", (resp) => ConfigWebView_FullTextProbe_After(resp))
}

ConfigWebView_FullTextProbe_After(resp) {
    ok := (resp is Map) && resp.Has("status") && Integer(resp["status"]) = 200 && resp.Has("json") && (resp["json"] is Map)
    if !ok {
        errMsg := (resp is Map && resp.Has("text")) ? String(resp["text"]) : "HTTP 0"
        ConfigWebView_Send(Map("type", "fulltextProbeResult", "ok", false, "error", errMsg, "probe", 0))
        return
    }
    root := resp["json"]
    probe := (root.Has("probe") && (root["probe"] is Map)) ? root["probe"] : root
    ConfigWebView_Send(Map("type", "fulltextProbeResult", "ok", true, "error", "", "probe", probe))
}

JoinArray(arr, sep := ",") {
    if !(arr is Array) || arr.Length = 0
        return ""
    out := ""
    for idx, item in arr {
        if (idx > 1)
            out .= sep
        out .= item
    }
    return out
}

; 渚?SettingsPanel銆岄珮绾ц缃€嶆偓娴潯 1:1 鎿嶄綔鍙帮細涓?Commands.json 涓?ToolbarLayout / CommandList 鍚屾
ConfigWebView_GetKeybinderToolbarSnapshot() {
    global g_Commands
    tl := []
    cmds := []
    try {
        _LoadCommands()
    } catch {
    }
    if !(IsSet(g_Commands) && g_Commands is Map)
        return Map("toolbarLayout", tl, "commands", cmds)
    if g_Commands.Has("ToolbarLayout") && g_Commands["ToolbarLayout"] is Array {
        for row in g_Commands["ToolbarLayout"] {
            if !(row is Map) || !row.Has("cmdId")
                continue
            cid := Trim(String(row["cmdId"]))
            if (cid = "")
                continue
            te := false
            if row.Has("toolbarEligible")
                te := !!row["toolbarEligible"]
            else
                te := (row.Has("visible_in_bar") && row["visible_in_bar"]) || (row.Has("visible_in_menu") && row["visible_in_menu"])
            tl.Push(Map(
                "cmdId", cid,
                "visible_in_bar", row.Has("visible_in_bar") ? !!row["visible_in_bar"] : (row.Has("in_bar") ? !!row["in_bar"] : false),
                "visible_in_menu", row.Has("visible_in_menu") ? !!row["visible_in_menu"] : (row.Has("in_context_menu") ? !!row["in_context_menu"] : false),
                "order_bar", row.Has("order_bar") ? Integer(row["order_bar"]) : -1,
                "order_menu", row.Has("order_menu") ? Integer(row["order_menu"]) : -1,
                "toolbarEligible", te
            ))
        }
    }
    if g_Commands.Has("CommandList") && g_Commands["CommandList"] is Map {
        for cid, ent in g_Commands["CommandList"] {
            if (SubStr(cid, 1, 3) = "pt_")
                continue
            nm := (ent is Map && ent.Has("name")) ? String(ent["name"]) : cid
            desc := (ent is Map && ent.Has("desc")) ? String(ent["desc"]) : ""
            fn := (ent is Map && ent.Has("fn")) ? String(ent["fn"]) : ""
            ic := (ent is Map && ent.Has("iconClass")) ? String(ent["iconClass"]) : ""
            cmds.Push(Map("id", cid, "name", nm, "desc", desc, "fn", fn, "iconClass", ic))
        }
    }
    cml := []
    if (g_Commands.Has("ContextMenuLayout") && g_Commands["ContextMenuLayout"] is Array) {
        for item in g_Commands["ContextMenuLayout"]
            cml.Push(String(item))
    }
    return Map("toolbarLayout", tl, "commands", cmds, "contextMenuLayout", cml)
}

ConfigWebView_BuildInitData() {
    global CursorPath, CapsLockHoldTimeSeconds, CapsLockHoldVkEnabled, AutoStart, DefaultStartTab
    global ThemeMode, FunctionPanelPos, ConfigPanelScreenIndex, ConfigPanelPos, ClipboardPanelPos, PanelScreenIndex
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, SplitHotkey, BatchHotkey, HotkeyT, HotkeyF, HotkeyP
    global PromptQuickCaptureHotkey, QuickActionButtons
    global Language, AISleepTime, LaunchDelaySeconds, MsgBoxScreenIndex, VoiceInputScreenIndex, CursorPanelScreenIndex, ClipboardPanelScreenIndex
    global SearchEngine, AutoLoadSelectedText, AutoUpdateVoiceInput, VoiceSearchEnabledCategories, VoiceSearchSelectedEngines
    global ConfigFile, DefaultTemplateIDs, PromptTemplates
    global FloatingToolbarButtonItems, FloatingToolbarMenuItems, FloatingToolbarButtonOptions, FloatingToolbarMenuOptions
    global AppearanceActivationMode
    monitorCount := 1
    try monitorCount := MonitorGetCount()
    catch
        monitorCount := 1
    popupScreenIndex := PanelScreenIndex
    if (popupScreenIndex < 1)
        popupScreenIndex := 1
    if (popupScreenIndex > monitorCount)
        popupScreenIndex := monitorCount
    hotkeys := Map(
        "ESC", HotkeyESC, "C", HotkeyC, "V", HotkeyV, "X", HotkeyX, "E", HotkeyE, "R", HotkeyR, "O", HotkeyO,
        "Q", HotkeyQ, "Z", HotkeyZ, "S", SplitHotkey, "B", BatchHotkey, "T", HotkeyT, "F", HotkeyF, "P", HotkeyP
    )
    qa := []
    for item in QuickActionButtons {
        qaType := "Explain"
        qaHotkey := "e"
        if (item is Map) {
            qaType := item.Get("Type", qaType)
            qaHotkey := item.Get("Hotkey", qaHotkey)
        } else if (IsObject(item)) {
            if item.HasProp("Type")
                qaType := item.Type
            if item.HasProp("Hotkey")
                qaHotkey := item.Hotkey
        }
        qa.Push(Map("type", qaType, "hotkey", qaHotkey))
    }
    cats := []
    for c in VoiceSearchEnabledCategories
        cats.Push(c)
    toolbarButtons := FTB_SanitizeToolbarButtonItems(FloatingToolbarButtonItems)
    toolbarMenus := FTB_SanitizeToolbarMenuItems(FloatingToolbarMenuItems)
    selectedCsv := ""
    if (IsSet(VoiceSearchSelectedEngines) && VoiceSearchSelectedEngines.Length > 0)
        selectedCsv := JoinArray(VoiceSearchSelectedEngines, ",")
    promptTemplateSummary := []
    if (IsSet(PromptTemplates) && PromptTemplates is Array) {
        for t in PromptTemplates {
            tid := ""
            ttitle := ""
            tcat := ""
            if (t is Map) {
                tid := t.Get("ID", "")
                ttitle := t.Get("Title", "")
                tcat := t.Get("Category", t.Get("FunctionCategory", ""))
            } else if (IsObject(t)) {
                if t.HasProp("ID")
                    tid := t.ID
                if t.HasProp("Title")
                    ttitle := t.Title
                if t.HasProp("Category")
                    tcat := t.Category
                else if t.HasProp("FunctionCategory")
                    tcat := t.FunctionCategory
            }
            tcontent := ""
            if (t is Map)
                tcontent := t.Get("Content", "")
            else if (IsObject(t) && t.HasProp("Content"))
                tcontent := t.Content
            promptTemplateSummary.Push(Map("id", tid, "title", ttitle, "category", tcat, "content", tcontent))
        }
    }
    templateIds := (IsSet(DefaultTemplateIDs) && DefaultTemplateIDs is Map) ? DefaultTemplateIDs : Map()
    defaultTemplates := Map(
        "Explain", templateIds.Has("Explain") ? templateIds["Explain"] : "",
        "Refactor", templateIds.Has("Refactor") ? templateIds["Refactor"] : "",
        "Optimize", templateIds.Has("Optimize") ? templateIds["Optimize"] : ""
    )
    cursorRules := Map(
        "general", IniRead(ConfigFile, "CursorRules", "general", ""),
        "web", IniRead(ConfigFile, "CursorRules", "web", ""),
        "miniprogram", IniRead(ConfigFile, "CursorRules", "miniprogram", ""),
        "android", IniRead(ConfigFile, "CursorRules", "android", ""),
        "ios", IniRead(ConfigFile, "CursorRules", "ios", ""),
        "python", IniRead(ConfigFile, "CursorRules", "python", "")
    )
    screenshotConfig := Map(
        "captureMode", IniRead(ConfigFile, "Screenshot", "CaptureMode", "selection"),
        "outputTarget", IniRead(ConfigFile, "Screenshot", "OutputTarget", "editor"),
        "includeCursor", IniRead(ConfigFile, "Screenshot", "IncludeCursor", "0") = "1",
        "autoCopyClipboard", IniRead(ConfigFile, "Screenshot", "AutoCopyClipboard", "1") != "0",
        "scalePercent", Integer(IniRead(ConfigFile, "Screenshot", "ScalePercent", "100")),
        "imageFormat", IniRead(ConfigFile, "Screenshot", "ImageFormat", "png"),
        "jpegQuality", Integer(IniRead(ConfigFile, "Screenshot", "JpegQuality", "90")),
        "saveFilenamePattern", IniRead(ConfigFile, "Screenshot", "SaveFilenamePattern", "Screenshot_{yyyyMMdd_HHmmss}"),
        "ocrTextLayoutMode", IniRead(ConfigFile, "Settings", "ScreenshotOCRTextLayoutMode", "keep"),
        "ocrPunctuationMode", IniRead(ConfigFile, "Settings", "ScreenshotOCRPunctuationMode", "keep"),
        "ocrDirectCopyEnabled", IniRead(ConfigFile, "Settings", "ScreenshotOCRDirectCopyEnabled", "0") = "1"
    )
    cfgPayload := Map(
        "cursorPath", CursorPath,
        "capslockHoldTimeSeconds", CapsLockHoldTimeSeconds,
        "capsLockHoldVkEnabled", CapsLockHoldVkEnabled,
        "autoStart", AutoStart,
        "defaultStartTab", DefaultStartTab,
        ; 蹇呴』浠?INI 涓哄噯锛氬唴瀛樹腑 ThemeMode 鍙兘涓庣鐩樹笉涓€鑷达紙渚嬪浠?WebView 鍥炶皟鎵撳紑璁剧疆鏃讹級
        "themeMode", ReadPersistedThemeMode(),
        "popupScreenIndex", popupScreenIndex,
        "monitorCount", monitorCount,
        "functionPanelPos", FunctionPanelPos,
        "configPanelScreenIndex", ConfigPanelScreenIndex,
        "configPanelPos", ConfigPanelPos,
        "clipboardPanelPos", ClipboardPanelPos,
        "panelScreenIndex", PanelScreenIndex,
        "promptExplain", Prompt_Explain,
        "promptRefactor", Prompt_Refactor,
        "promptOptimize", Prompt_Optimize,
        "cursorRules", cursorRules,
        "promptTemplateSummary", promptTemplateSummary,
        "defaultTemplates", defaultTemplates,
        "hotkeys", hotkeys,
        "promptQuickCaptureHotkey", PromptQuickCaptureHotkey,
        "quickActions", qa,
        "language", Language,
        "aiSleepTime", AISleepTime,
        "launchDelaySeconds", LaunchDelaySeconds,
        "msgBoxScreenIndex", MsgBoxScreenIndex,
        "voiceInputScreenIndex", VoiceInputScreenIndex,
        "cursorPanelScreenIndex", CursorPanelScreenIndex,
        "clipboardPanelScreenIndex", ClipboardPanelScreenIndex,
        "searchEngine", SearchEngine,
        "autoLoadSelectedText", AutoLoadSelectedText,
        "autoUpdateVoiceInput", AutoUpdateVoiceInput,
        "voiceSearchEnabledCategories", cats,
        "voiceSearchSelectedEnginesCsv", selectedCsv,
        "screenshotConfig", screenshotConfig,
        "floatingToolbarButtons", toolbarButtons,
        "floatingToolbarMenuItems", toolbarMenus,
        "floatingToolbarButtonOptions", FloatingToolbarButtonOptions,
        "floatingToolbarMenuOptions", FloatingToolbarMenuOptions,
        "appearanceActivationMode", NormalizeAppearanceActivationMode(AppearanceActivationMode),
        "holePositionMode", IniRead(ConfigFile, "Appearance", "HolePositionMode", "anchor"),
        "holeTriggerDistance", Integer(IniRead(ConfigFile, "Appearance", "HoleTriggerDistance", "260")),
        "holeDismissDistance", Integer(IniRead(ConfigFile, "Appearance", "HoleDismissDistance", "320")),
        "holeFixedX", Integer(IniRead(ConfigFile, "Appearance", "HoleFixedX", "360")),
        "holeFixedY", Integer(IniRead(ConfigFile, "Appearance", "HoleFixedY", "260")),
        "holeSizeScale", Float(IniRead(ConfigFile, "Appearance", "HoleSizeScale", "1.0")),
        "holeAnimLevel", Float(IniRead(ConfigFile, "Appearance", "HoleAnimLevel", "1.0")),
        "holeVisualStyle", IniRead(ConfigFile, "Appearance", "HoleVisualStyle", "ring"),
        "holeHideDockEnabled", (IniRead(ConfigFile, "Appearance", "HoleHideDockEnabled", "1") = "1"),
        "holeHideDockEdge", IniRead(ConfigFile, "Appearance", "HoleHideDockEdge", "right"),
        "holeHideDockMargin", Integer(IniRead(ConfigFile, "Appearance", "HoleHideDockMargin", "10"))
    )
    kbSnap := ConfigWebView_GetKeybinderToolbarSnapshot()
    cfgPayload["keybinderToolbarLayout"] := kbSnap["toolbarLayout"]
    cfgPayload["keybinderCommands"] := kbSnap["commands"]
    cfgPayload["keybinderContextMenuLayout"] := kbSnap.Has("contextMenuLayout") ? kbSnap["contextMenuLayout"] : []
    return cfgPayload
}

ConfigWebView_BuildInitDataSafe() {
    global ThemeMode
    try {
        return ConfigWebView_BuildInitData()
    } catch as err {
        OutputDebug("[ConfigWebView] BuildInitData failed: " . err.Message)
        _tm := ReadPersistedThemeMode()
        return Map(
            "cursorPath", "",
            "capslockHoldTimeSeconds", 0.5,
            "capsLockHoldVkEnabled", true,
            "autoStart", false,
            "defaultStartTab", "general",
            "themeMode", _tm,
            "popupScreenIndex", 1,
            "monitorCount", 1,
            "functionPanelPos", "center",
            "configPanelScreenIndex", 1,
            "configPanelPos", "center",
            "clipboardPanelPos", "center",
            "panelScreenIndex", 1,
            "promptExplain", "",
            "promptRefactor", "",
            "promptOptimize", "",
            "cursorRules", Map("general","", "web","", "miniprogram","", "android","", "ios","", "python",""),
            "promptTemplateSummary", [],
            "defaultTemplates", Map("Explain","", "Refactor","", "Optimize",""),
            "hotkeys", Map("ESC","", "C","", "V","", "X","", "E","", "R","", "O","", "Q","", "Z","", "S","", "B","", "T","", "F","", "P",""),
            "promptQuickCaptureHotkey", "",
            "quickActions", [Map("type","Explain","hotkey","e"), Map("type","Refactor","hotkey","r"), Map("type","Optimize","hotkey","o"), Map("type","Config","hotkey","q"), Map("type","Explain","hotkey","e")],
            "language", "zh",
            "aiSleepTime", 200,
            "launchDelaySeconds", 3.0,
            "msgBoxScreenIndex", 1,
            "voiceInputScreenIndex", 1,
            "cursorPanelScreenIndex", 1,
            "clipboardPanelScreenIndex", 1,
            "searchEngine", "deepseek",
            "autoLoadSelectedText", false,
            "autoUpdateVoiceInput", true,
            "voiceSearchEnabledCategories", ["ai","cli","academic","baidu","image","audio","video","book","price","medical","cloud"],
            "voiceSearchSelectedEnginesCsv", "deepseek",
            "screenshotConfig", Map(
                "captureMode", "selection",
                "outputTarget", "editor",
                "includeCursor", false,
                "autoCopyClipboard", true,
                "scalePercent", 100,
                "imageFormat", "png",
                "jpegQuality", 90,
                "saveFilenamePattern", "Screenshot_{yyyyMMdd_HHmmss}",
                "ocrTextLayoutMode", "keep",
                "ocrPunctuationMode", "keep",
                "ocrDirectCopyEnabled", false
            ),
            "floatingToolbarButtons", ["Search","Record","Prompt","NewPrompt","Screenshot","Settings","VirtualKeyboard"],
            "floatingToolbarMenuItems", ["ToggleToolbar","MinimizeToEdge","ResetScale","SearchCenter","Clipboard","OpenConfig","HideToolbar","ReloadScript","ExitApp"],
            "floatingToolbarButtonOptions", [
                Map("id","Search","name","Search"),
                Map("id","Record","name","Record"),
                Map("id","Prompt","name","Prompt"),
                Map("id","NewPrompt","name","NewPrompt"),
                Map("id","Screenshot","name","Screenshot"),
                Map("id","Settings","name","Settings"),
                Map("id","VirtualKeyboard","name","VirtualKeyboard")
            ],
            "floatingToolbarMenuOptions", [
                Map("id","ToggleToolbar","name","ToggleToolbar"),
                Map("id","MinimizeToEdge","name","MinimizeToEdge"),
                Map("id","ResetScale","name","ResetScale"),
                Map("id","SearchCenter","name","SearchCenter"),
                Map("id","Clipboard","name","Clipboard"),
                Map("id","OpenConfig","name","OpenConfig"),
                Map("id","HideToolbar","name","HideToolbar"),
                Map("id","ReloadScript","name","ReloadScript"),
                Map("id","ExitApp","name","ExitApp")
            ],
            "appearanceActivationMode", "toolbar",
            "keybinderToolbarLayout", [],
            "keybinderCommands", [],
            "keybinderContextMenuLayout", []
        )
    }
}

ConfigWebView_SendDockConfig() {
    arr := []
    try {
        if IsSet(_LoadCommands)
            _LoadCommands()
        global g_Commands
        try {
            trayCount := (g_Commands is Map && g_Commands.Has("SceneMenus") && g_Commands["SceneMenus"] is Map
                && g_Commands["SceneMenus"].Has("tray_menu") && g_Commands["SceneMenus"]["tray_menu"] is Array)
                ? g_Commands["SceneMenus"]["tray_menu"].Length
                : -1
            cmdCount := (g_Commands is Map && g_Commands.Has("CommandList") && g_Commands["CommandList"] is Map)
                ? g_Commands["CommandList"].Count
                : 0
            OutputDebug("[ConfigWV2] SendDockConfig tray_menu count=" . trayCount . " cmd_count=" . cmdCount)
        } catch {
        }
        if (g_Commands is Map && g_Commands.Has("SceneToolbarLayout") && g_Commands["SceneToolbarLayout"] is Array) {
            for row in g_Commands["SceneToolbarLayout"] {
                if !(row is Map) || !row.Has("sceneId")
                    continue
                sid := Trim(String(row["sceneId"]))
                if (sid = "")
                    continue
                arr.Push(Map(
                    "sceneId", sid,
                    "visible_in_bar", row.Has("visible_in_bar") ? (row["visible_in_bar"] ? true : false) : true,
                    "order_bar", row.Has("order_bar") ? Integer(row["order_bar"]) : -1
                ))
            }
        }
    } catch {
    }
    ConfigWebView_Send(Map("type", "nmDockConfig", "sceneToolbarLayout", arr))
}

ConfigWebView_ExecuteDockCmd(msg) {
    cmdId0 := msg.Has("cmdId") ? String(msg["cmdId"]) : ""
    if (cmdId0 = "")
        return
    if (cmdId0 = "open_cloudplayer") {
        try ShowCloudPlayer()
        return
    }
    try {
        _ExecuteCommand(cmdId0)
        return
    } catch {
    }
    m0 := Map(
        "Title", "dock",
        "Content", "",
        "DataType", "text",
        "OriginalDataType", "text",
        "Source", "dock",
        "ClipboardId", 0,
        "PromptMergedIndex", 0,
        "HubSegIndex", -1
    )
    try SC_ExecuteContextCommand(cmdId0, 0, m0)
    catch as err {
        OutputDebug("[ConfigWebView] nmDockCmd: " . err.Message)
    }
}

ConfigWebView_ValidateAndApply(payload, &errorMsg := "") {
    global CursorPath, CapsLockHoldTimeSeconds, CapsLockHoldVkEnabled, AutoStart, DefaultStartTab
    global ThemeMode, FunctionPanelPos, ConfigPanelScreenIndex, ConfigPanelPos, ClipboardPanelPos, PanelScreenIndex
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, SplitHotkey, BatchHotkey, HotkeyT, HotkeyF, HotkeyP
    global PromptQuickCaptureHotkey, QuickActionButtons
    global Language, AISleepTime, LaunchDelaySeconds, MsgBoxScreenIndex, VoiceInputScreenIndex, CursorPanelScreenIndex, ClipboardPanelScreenIndex
    global SearchEngine, AutoLoadSelectedText, AutoUpdateVoiceInput, VoiceSearchEnabledCategories, VoiceSearchSelectedEngines
    global FloatingToolbarButtonItems
    global AppearanceActivationMode
    global ConfigFile

    try {
        if !(payload is Map) {
            errorMsg := "payload 鏃犳晥"
            return false
        }
        NewCursorPath := NormalizeWindowsPath(payload.Get("cursorPath", ""))
        if (NewCursorPath = "") {
            errorMsg := "Cursor Path 涓嶈兘涓虹┖"
            return false
        }
        NewHold := Float(payload.Get("capslockHoldTimeSeconds", 0.5))
        if (NewHold < 0.1 || NewHold > 5.0) {
            errorMsg := "CapsLock Hold Time 瓒呭嚭鑼冨洿"
            return false
        }
        NewAutoStart := payload.Get("autoStart", false) ? true : false
        NewCapsLockHoldVk := CapsLockHoldVkEnabled
        if (payload.Has("capsLockHoldVkEnabled"))
            NewCapsLockHoldVk := payload["capsLockHoldVkEnabled"] ? true : false
        NewDefaultTab := payload.Get("defaultStartTab", "general")
        validTabs := Map("general",1, "appearance",1, "prompts",1, "hotkeys",1, "advanced",1, "screenshot",1, "search",1)
        if !validTabs.Has(NewDefaultTab)
            NewDefaultTab := "general"
        NewTheme := ThemeMode
        if (payload.Has("themeMode"))
            NewTheme := payload["themeMode"]
        else if (payload.Has("ThemeMode"))
            NewTheme := payload["ThemeMode"]
        NewTheme := NormalizeIniThemeMode(NewTheme, NormalizeIniThemeMode(ThemeMode, "dark"))
        NewPanelPos := payload.Get("functionPanelPos", "center")
        validPos := Map("center",1, "top-left",1, "top-right",1, "bottom-left",1, "bottom-right",1)
        if !validPos.Has(NewPanelPos)
            NewPanelPos := "center"
        monitorCount := 1
        try monitorCount := MonitorGetCount()
        catch
            monitorCount := 1
        NewPopupScreen := Integer(payload.Get("popupScreenIndex", payload.Get("panelScreenIndex", 1)))
        if (NewPopupScreen < 1)
            NewPopupScreen := 1
        if (NewPopupScreen > monitorCount)
            NewPopupScreen := monitorCount
        NewConfigPanelPos := payload.Get("configPanelPos", "center")
        if !validPos.Has(NewConfigPanelPos)
            NewConfigPanelPos := "center"
        NewClipboardPanelPos := payload.Get("clipboardPanelPos", "center")
        if !validPos.Has(NewClipboardPanelPos)
            NewClipboardPanelPos := "center"
        NewPromptExplain := payload.Get("promptExplain", "")
        NewPromptRefactor := payload.Get("promptRefactor", "")
        NewPromptOptimize := payload.Get("promptOptimize", "")
        NewCursorRules := Map(
            "general", IniRead(ConfigFile, "CursorRules", "general", ""),
            "web", IniRead(ConfigFile, "CursorRules", "web", ""),
            "miniprogram", IniRead(ConfigFile, "CursorRules", "miniprogram", ""),
            "android", IniRead(ConfigFile, "CursorRules", "android", ""),
            "ios", IniRead(ConfigFile, "CursorRules", "ios", ""),
            "python", IniRead(ConfigFile, "CursorRules", "python", "")
        )
        if (payload.Has("cursorRules") && payload["cursorRules"] is Map) {
            crPayload := payload["cursorRules"]
            for k in ["general","web","miniprogram","android","ios","python"] {
                if crPayload.Has(k)
                    NewCursorRules[k] := crPayload.Get(k, "")
            }
        }
        NewLanguage := payload.Get("language", "zh")
        if (NewLanguage != "zh" && NewLanguage != "en")
            NewLanguage := "zh"
        NewAiSleepTime := Integer(payload.Get("aiSleepTime", 200))
        if (NewAiSleepTime < 50)
            NewAiSleepTime := 50
        NewLaunchDelay := Float(payload.Get("launchDelaySeconds", 3.0))
        if (NewLaunchDelay < 0.5)
            NewLaunchDelay := 0.5
        if (NewLaunchDelay > 10.0)
            NewLaunchDelay := 10.0
        NewSearchEngine := Trim(payload.Get("searchEngine", "deepseek"))
        if (NewSearchEngine = "")
            NewSearchEngine := "deepseek"
        NewAutoLoad := payload.Get("autoLoadSelectedText", false) ? true : false
        NewAutoUpdate := payload.Get("autoUpdateVoiceInput", true) ? true : false
        NewCaptureHotkey := Trim(payload.Get("promptQuickCaptureHotkey", ""))
        NewVoiceEngineCsv := Trim(payload.Get("voiceSearchSelectedEnginesCsv", ""))
        NewScreenshotCfg := Map(
            "captureMode", "selection",
            "outputTarget", "editor",
            "includeCursor", false,
            "autoCopyClipboard", true,
            "scalePercent", 100,
            "imageFormat", "png",
            "jpegQuality", 90,
            "saveFilenamePattern", "Screenshot_{yyyyMMdd_HHmmss}",
            "ocrTextLayoutMode", "keep",
            "ocrPunctuationMode", "keep",
            "ocrDirectCopyEnabled", false
        )
        if (payload.Has("screenshotConfig") && payload["screenshotConfig"] is Map) {
            sc := payload["screenshotConfig"]
            cm := Trim(String(sc.Get("captureMode", "selection")))
            if (cm != "selection" && cm != "fullscreen" && cm != "active_window")
                cm := "selection"
            ot := Trim(String(sc.Get("outputTarget", "editor")))
            if (ot != "editor" && ot != "clipboard" && ot != "both")
                ot := "editor"
            sf := Trim(String(sc.Get("imageFormat", "png")))
            if (sf != "png" && sf != "jpg" && sf != "bmp")
                sf := "png"
            sp := Integer(sc.Get("scalePercent", 100))
            if (sp < 25)
                sp := 25
            if (sp > 300)
                sp := 300
            jq := Integer(sc.Get("jpegQuality", 90))
            if (jq < 10)
                jq := 10
            if (jq > 100)
                jq := 100
            pat := Trim(String(sc.Get("saveFilenamePattern", "Screenshot_{yyyyMMdd_HHmmss}")))
            if (pat = "")
                pat := "Screenshot_{yyyyMMdd_HHmmss}"
            tl := Trim(String(sc.Get("ocrTextLayoutMode", "keep")))
            if (tl != "keep" && tl != "single_line" && tl != "multi_line")
                tl := "keep"
            pm := Trim(String(sc.Get("ocrPunctuationMode", "keep")))
            if (pm != "keep" && pm != "halfwidth" && pm != "strip")
                pm := "keep"
            NewScreenshotCfg := Map(
                "captureMode", cm,
                "outputTarget", ot,
                "includeCursor", sc.Get("includeCursor", false) ? true : false,
                "autoCopyClipboard", sc.Get("autoCopyClipboard", true) ? true : false,
                "scalePercent", sp,
                "imageFormat", sf,
                "jpegQuality", jq,
                "saveFilenamePattern", pat,
                "ocrTextLayoutMode", tl,
                "ocrPunctuationMode", pm,
                "ocrDirectCopyEnabled", sc.Get("ocrDirectCopyEnabled", false) ? true : false
            )
        }
        NewVoiceCats := []
        if (payload.Has("voiceSearchEnabledCategories") && payload["voiceSearchEnabledCategories"] is Array) {
            for c in payload["voiceSearchEnabledCategories"] {
                if (c != "")
                    NewVoiceCats.Push(c)
            }
        }
        if (NewVoiceCats.Length = 0)
            NewVoiceCats := ["ai","cli","academic","baidu","image","audio","video","book","price","medical","cloud"]
        _amRaw := ""
        if (payload is Map) {
            if payload.Has("appearanceActivationMode")
                _amRaw := payload["appearanceActivationMode"]
            else if payload.Has("AppearanceActivationMode")
                _amRaw := payload["AppearanceActivationMode"]
        }
        if (_amRaw = "" && payload is Map)
            _amRaw := payload.Get("appearanceActivationMode", "toolbar")
        if (_amRaw = "")
            _amRaw := "toolbar"
        NewAppearanceActivationMode := NormalizeAppearanceActivationMode(_amRaw)
        NewFloatingToolbarButtons := FTB_SanitizeToolbarButtonItems(FloatingToolbarButtonItems)
        if (payload.Has("floatingToolbarButtons") && payload["floatingToolbarButtons"] is Array)
            NewFloatingToolbarButtons := FTB_SanitizeToolbarButtonItems(payload["floatingToolbarButtons"])
        NewHolePositionMode := Trim(String(payload.Get("holePositionMode", IniRead(ConfigFile, "Appearance", "HolePositionMode", "anchor"))))
        if (NewHolePositionMode != "anchor" && NewHolePositionMode != "fixed" && NewHolePositionMode != "relative")
            NewHolePositionMode := "anchor"
        NewHoleTriggerDistance := Integer(payload.Get("holeTriggerDistance", IniRead(ConfigFile, "Appearance", "HoleTriggerDistance", "260")))
        if (NewHoleTriggerDistance < 80)
            NewHoleTriggerDistance := 80
        if (NewHoleTriggerDistance > 1200)
            NewHoleTriggerDistance := 1200
        NewHoleDismissDistance := Integer(payload.Get("holeDismissDistance", IniRead(ConfigFile, "Appearance", "HoleDismissDistance", "320")))
        if (NewHoleDismissDistance < NewHoleTriggerDistance + 20)
            NewHoleDismissDistance := NewHoleTriggerDistance + 20
        if (NewHoleDismissDistance > 1600)
            NewHoleDismissDistance := 1600
        NewHoleFixedX := Integer(payload.Get("holeFixedX", IniRead(ConfigFile, "Appearance", "HoleFixedX", "360")))
        NewHoleFixedY := Integer(payload.Get("holeFixedY", IniRead(ConfigFile, "Appearance", "HoleFixedY", "260")))
        NewHoleSizeScale := Float(payload.Get("holeSizeScale", IniRead(ConfigFile, "Appearance", "HoleSizeScale", "1.0")))
        if (NewHoleSizeScale < 0.6)
            NewHoleSizeScale := 0.6
        if (NewHoleSizeScale > 1.8)
            NewHoleSizeScale := 1.8
        NewHoleAnimLevel := Float(payload.Get("holeAnimLevel", IniRead(ConfigFile, "Appearance", "HoleAnimLevel", "1.0")))
        if (NewHoleAnimLevel < 0.4)
            NewHoleAnimLevel := 0.4
        if (NewHoleAnimLevel > 2.2)
            NewHoleAnimLevel := 2.2
        NewHoleVisualStyle := StrLower(Trim(String(payload.Get("holeVisualStyle", IniRead(ConfigFile, "Appearance", "HoleVisualStyle", "ring")))))
        if (NewHoleVisualStyle != "ring" && NewHoleVisualStyle != "starry")
            NewHoleVisualStyle := "ring"
        NewHoleHideDockEnabled := !!payload.Get("holeHideDockEnabled", IniRead(ConfigFile, "Appearance", "HoleHideDockEnabled", "1") = "1")
        NewHoleHideDockEdge := StrLower(Trim(String(payload.Get("holeHideDockEdge", IniRead(ConfigFile, "Appearance", "HoleHideDockEdge", "right")))))
        if (NewHoleHideDockEdge != "right" && NewHoleHideDockEdge != "left" && NewHoleHideDockEdge != "top" && NewHoleHideDockEdge != "bottom")
            NewHoleHideDockEdge := "right"
        NewHoleHideDockMargin := Integer(payload.Get("holeHideDockMargin", IniRead(ConfigFile, "Appearance", "HoleHideDockMargin", "10")))
        if (NewHoleHideDockMargin < 0)
            NewHoleHideDockMargin := 0
        if (NewHoleHideDockMargin > 80)
            NewHoleHideDockMargin := 80
        NewQuickActions := []
        if (payload.Has("quickActions") && payload["quickActions"] is Array) {
            for item in payload["quickActions"] {
                if (item is Map) {
                    qaType := item.Get("type", "Explain")
                    qaHotkey := item.Get("hotkey", "")
                    NewQuickActions.Push(Map("Type", qaType, "Hotkey", qaHotkey))
                }
            }
        }
        while (NewQuickActions.Length < 5)
            NewQuickActions.Push(Map("Type", "Explain", "Hotkey", "e"))
        while (NewQuickActions.Length > 5)
            NewQuickActions.Pop()
        hkMap := payload.Get("hotkeys", Map())
        hkGet(Key, Def) {
            if (hkMap is Map && hkMap.Has(Key))
                return Trim(hkMap[Key])
            return Def
        }
        NewHotkeyESC := hkGet("ESC", HotkeyESC)
        NewHotkeyC := hkGet("C", HotkeyC)
        NewHotkeyV := hkGet("V", HotkeyV)
        NewHotkeyX := hkGet("X", HotkeyX)
        NewHotkeyE := hkGet("E", HotkeyE)
        NewHotkeyR := hkGet("R", HotkeyR)
        NewHotkeyO := hkGet("O", HotkeyO)
        NewHotkeyQ := hkGet("Q", HotkeyQ)
        NewHotkeyZ := hkGet("Z", HotkeyZ)
        NewSplitHotkey := hkGet("S", SplitHotkey)
        NewBatchHotkey := hkGet("B", BatchHotkey)
        NewHotkeyT := hkGet("T", HotkeyT)
        NewHotkeyF := hkGet("F", HotkeyF)
        NewHotkeyP := hkGet("P", HotkeyP)

        CursorPath := NewCursorPath
        CapsLockHoldTimeSeconds := NewHold
        CapsLockHoldVkEnabled := NewCapsLockHoldVk
        AutoStart := NewAutoStart
        DefaultStartTab := NewDefaultTab
        ThemeMode := NewTheme
        FunctionPanelPos := NewPanelPos
        ConfigPanelPos := NewConfigPanelPos
        ClipboardPanelPos := NewClipboardPanelPos
        PanelScreenIndex := NewPopupScreen
        ConfigPanelScreenIndex := NewPopupScreen
        Prompt_Explain := NewPromptExplain
        Prompt_Refactor := NewPromptRefactor
        Prompt_Optimize := NewPromptOptimize
        HotkeyESC := NewHotkeyESC
        HotkeyC := NewHotkeyC
        HotkeyV := NewHotkeyV
        HotkeyX := NewHotkeyX
        HotkeyE := NewHotkeyE
        HotkeyR := NewHotkeyR
        HotkeyO := NewHotkeyO
        HotkeyQ := NewHotkeyQ
        HotkeyZ := NewHotkeyZ
        SplitHotkey := NewSplitHotkey
        BatchHotkey := NewBatchHotkey
        HotkeyT := NewHotkeyT
        HotkeyF := NewHotkeyF
        HotkeyP := NewHotkeyP
        PromptQuickCaptureHotkey := NewCaptureHotkey
        QuickActionButtons := NewQuickActions
        Language := NewLanguage
        AISleepTime := NewAiSleepTime
        LaunchDelaySeconds := NewLaunchDelay
        MsgBoxScreenIndex := NewPopupScreen
        VoiceInputScreenIndex := NewPopupScreen
        CursorPanelScreenIndex := NewPopupScreen
        ClipboardPanelScreenIndex := NewPopupScreen
        SearchEngine := NewSearchEngine
        AutoLoadSelectedText := NewAutoLoad
        AutoUpdateVoiceInput := NewAutoUpdate
        VoiceSearchEnabledCategories := NewVoiceCats
        FloatingToolbarButtonItems := NewFloatingToolbarButtons
        AppearanceActivationMode := NewAppearanceActivationMode
        VoiceSearchSelectedEngines := []
        if (NewVoiceEngineCsv != "") {
            for item in StrSplit(NewVoiceEngineCsv, ",") {
                v := Trim(item)
                if (v != "")
                    VoiceSearchSelectedEngines.Push(v)
            }
        }
        if (VoiceSearchSelectedEngines.Length = 0)
            VoiceSearchSelectedEngines.Push("deepseek")
        ; 鍏堟寔涔呭寲涓婚鍐?ApplyTheme锛岄伩鍏?FloatingToolbar 绛変粠 INI 璇诲埌鏃у€硷紱ApplyTheme 鍐呬篃浼氭樉寮忎紶鍏?Mode
        IniWrite(NewTheme, ConfigFile, "Settings", "ThemeMode")
        IniWrite(NewTheme, ConfigFile, "Appearance", "ThemeMode")
        ApplyTheme(NewTheme)
        try SetTimer(ConfigWebView_RefocusAfterThemeChange, -60)
        catch {
        }

        IniWrite(CursorPath, ConfigFile, "Settings", "CursorPath")
        IniWrite(String(AISleepTime), ConfigFile, "Settings", "AISleepTime")
        IniWrite(String(CapsLockHoldTimeSeconds), ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
        IniWrite(CapsLockHoldVkEnabled ? "1" : "0", ConfigFile, "Settings", "CapsLockHoldVkEnabled")
        IniWrite(String(LaunchDelaySeconds), ConfigFile, "Settings", "LaunchDelaySeconds")
        IniWrite(Language, ConfigFile, "Settings", "Language")
        IniWrite(Prompt_Explain, ConfigFile, "Settings", "Prompt_Explain")
        IniWrite(Prompt_Refactor, ConfigFile, "Settings", "Prompt_Refactor")
        IniWrite(Prompt_Optimize, ConfigFile, "Settings", "Prompt_Optimize")
        IniWrite(AutoStart ? "1" : "0", ConfigFile, "Settings", "AutoStart")
        IniWrite(DefaultStartTab, ConfigFile, "Settings", "DefaultStartTab")
        IniWrite(PromptQuickCaptureHotkey, ConfigFile, "Settings", "PromptQuickCaptureHotkey")
        IniWrite(SearchEngine, ConfigFile, "Settings", "SearchEngine")
        IniWrite(AutoLoadSelectedText ? "1" : "0", ConfigFile, "Settings", "AutoLoadSelectedText")
        IniWrite(AutoUpdateVoiceInput ? "1" : "0", ConfigFile, "Settings", "AutoUpdateVoiceInput")
        IniWrite(JoinArray(VoiceSearchEnabledCategories, ","), ConfigFile, "Settings", "VoiceSearchEnabledCategories")
        IniWrite(JoinArray(VoiceSearchSelectedEngines, ","), ConfigFile, "Settings", "VoiceSearchSelectedEngines")
        IniWrite(NewScreenshotCfg["captureMode"], ConfigFile, "Screenshot", "CaptureMode")
        IniWrite(NewScreenshotCfg["outputTarget"], ConfigFile, "Screenshot", "OutputTarget")
        IniWrite(NewScreenshotCfg["includeCursor"] ? "1" : "0", ConfigFile, "Screenshot", "IncludeCursor")
        IniWrite(NewScreenshotCfg["autoCopyClipboard"] ? "1" : "0", ConfigFile, "Screenshot", "AutoCopyClipboard")
        IniWrite(String(NewScreenshotCfg["scalePercent"]), ConfigFile, "Screenshot", "ScalePercent")
        IniWrite(NewScreenshotCfg["imageFormat"], ConfigFile, "Screenshot", "ImageFormat")
        IniWrite(String(NewScreenshotCfg["jpegQuality"]), ConfigFile, "Screenshot", "JpegQuality")
        IniWrite(NewScreenshotCfg["saveFilenamePattern"], ConfigFile, "Screenshot", "SaveFilenamePattern")
        IniWrite(NewScreenshotCfg["ocrTextLayoutMode"], ConfigFile, "Settings", "ScreenshotOCRTextLayoutMode")
        IniWrite(NewScreenshotCfg["ocrPunctuationMode"], ConfigFile, "Settings", "ScreenshotOCRPunctuationMode")
        IniWrite(NewScreenshotCfg["ocrDirectCopyEnabled"] ? "1" : "0", ConfigFile, "Settings", "ScreenshotOCRDirectCopyEnabled")
        IniWrite(FTB_ItemsToCsv(FloatingToolbarButtonItems), ConfigFile, "Settings", "FloatingToolbarButtonItems")
        IniWrite(NewCursorRules["general"], ConfigFile, "CursorRules", "general")
        IniWrite(NewCursorRules["web"], ConfigFile, "CursorRules", "web")
        IniWrite(NewCursorRules["miniprogram"], ConfigFile, "CursorRules", "miniprogram")
        IniWrite(NewCursorRules["android"], ConfigFile, "CursorRules", "android")
        IniWrite(NewCursorRules["ios"], ConfigFile, "CursorRules", "ios")
        IniWrite(NewCursorRules["python"], ConfigFile, "CursorRules", "python")
        IniWrite(HotkeyESC, ConfigFile, "Hotkeys", "ESC")
        IniWrite(HotkeyC, ConfigFile, "Hotkeys", "C")
        IniWrite(HotkeyV, ConfigFile, "Hotkeys", "V")
        IniWrite(HotkeyX, ConfigFile, "Hotkeys", "X")
        IniWrite(HotkeyE, ConfigFile, "Hotkeys", "E")
        IniWrite(HotkeyR, ConfigFile, "Hotkeys", "R")
        IniWrite(HotkeyO, ConfigFile, "Hotkeys", "O")
        IniWrite(HotkeyQ, ConfigFile, "Hotkeys", "Q")
        IniWrite(HotkeyZ, ConfigFile, "Hotkeys", "Z")
        IniWrite(SplitHotkey, ConfigFile, "Hotkeys", "Split")
        IniWrite(BatchHotkey, ConfigFile, "Hotkeys", "Batch")
        IniWrite(HotkeyT, ConfigFile, "Hotkeys", "T")
        IniWrite(HotkeyF, ConfigFile, "Hotkeys", "F")
        IniWrite(HotkeyP, ConfigFile, "Hotkeys", "P")
        IniWrite("5", ConfigFile, "QuickActions", "ButtonCount")
        Loop 5 {
            idx := A_Index
            btnType := "Explain"
            btnHotkey := "e"
            btn := QuickActionButtons[idx]
            if (btn is Map) {
                btnType := btn.Get("Type", btnType)
                btnHotkey := btn.Get("Hotkey", btnHotkey)
            } else if (IsObject(btn)) {
                if btn.HasProp("Type")
                    btnType := btn.Type
                if btn.HasProp("Hotkey")
                    btnHotkey := btn.Hotkey
            }
            IniWrite(btnType, ConfigFile, "QuickActions", "Button" . idx . "Type")
            IniWrite(btnHotkey, ConfigFile, "QuickActions", "Button" . idx . "Hotkey")
        }
        IniWrite(PanelScreenIndex, ConfigFile, "Appearance", "ScreenIndex")
        IniWrite(PanelScreenIndex, ConfigFile, "Appearance", "PopupScreenIndex")
        IniWrite(AppearanceActivationMode, ConfigFile, "Appearance", "ActivationMode")
        IniWrite(NewHolePositionMode, ConfigFile, "Appearance", "HolePositionMode")
        IniWrite(String(NewHoleTriggerDistance), ConfigFile, "Appearance", "HoleTriggerDistance")
        IniWrite(String(NewHoleDismissDistance), ConfigFile, "Appearance", "HoleDismissDistance")
        IniWrite(String(NewHoleFixedX), ConfigFile, "Appearance", "HoleFixedX")
        IniWrite(String(NewHoleFixedY), ConfigFile, "Appearance", "HoleFixedY")
        IniWrite(String(NewHoleSizeScale), ConfigFile, "Appearance", "HoleSizeScale")
        IniWrite(String(NewHoleAnimLevel), ConfigFile, "Appearance", "HoleAnimLevel")
        IniWrite(NewHoleVisualStyle, ConfigFile, "Appearance", "HoleVisualStyle")
        IniWrite(NewHoleHideDockEnabled ? "1" : "0", ConfigFile, "Appearance", "HoleHideDockEnabled")
        IniWrite(NewHoleHideDockEdge, ConfigFile, "Appearance", "HoleHideDockEdge")
        IniWrite(String(NewHoleHideDockMargin), ConfigFile, "Appearance", "HoleHideDockMargin")
        IniWrite(FunctionPanelPos, ConfigFile, "Appearance", "FunctionPanelPos")
        IniWrite(ConfigPanelPos, ConfigFile, "Appearance", "ConfigPanelPos")
        IniWrite(ClipboardPanelPos, ConfigFile, "Appearance", "ClipboardPanelPos")
        IniWrite(ConfigPanelScreenIndex, ConfigFile, "Advanced", "ConfigPanelScreenIndex")
        IniWrite(MsgBoxScreenIndex, ConfigFile, "Advanced", "MsgBoxScreenIndex")
        IniWrite(VoiceInputScreenIndex, ConfigFile, "Advanced", "VoiceInputScreenIndex")
        IniWrite(CursorPanelScreenIndex, ConfigFile, "Advanced", "CursorPanelScreenIndex")
        IniWrite(ClipboardPanelScreenIndex, ConfigFile, "Advanced", "ClipboardPanelScreenIndex")
        SetAutoStart(AutoStart)
        PromptQuickPad_RegisterCaptureHotkey()
        try FloatingToolbarPushButtonConfigToWeb()
        try GDHO_SetScreenAnchor(NewHoleFixedX, NewHoleFixedY)
        try GDHO_ApplySettings(NewHolePositionMode, NewHoleTriggerDistance, NewHoleDismissDistance, NewHoleFixedX, NewHoleFixedY, NewHoleSizeScale, NewHoleAnimLevel, NewHoleVisualStyle)
        try GDHO_ApplyHideDockSettings(NewHoleHideDockEnabled, NewHoleHideDockEdge, NewHoleHideDockMargin)
        ; Apply mode asynchronously to avoid blocking settings WebView thread.
        try SetTimer((*) => ApplyAppearanceActivationMode(), -20)
        catch {
        }
        return true
    } catch as err {
        errorMsg := "淇濆瓨澶辫触: " . err.Message
        return false
    }
}

ConfigWebView_SaveHoleOnly(payload, &errorMsg := "") {
    global ConfigFile
    try {
        if !(payload is Map) {
            errorMsg := "payload 鏃犳晥"
            return false
        }
        NewHolePositionMode := Trim(String(payload.Get("holePositionMode", IniRead(ConfigFile, "Appearance", "HolePositionMode", "anchor"))))
        if (NewHolePositionMode != "anchor" && NewHolePositionMode != "fixed" && NewHolePositionMode != "relative")
            NewHolePositionMode := "anchor"
        NewHoleTriggerDistance := Integer(payload.Get("holeTriggerDistance", IniRead(ConfigFile, "Appearance", "HoleTriggerDistance", "260")))
        if (NewHoleTriggerDistance < 80)
            NewHoleTriggerDistance := 80
        if (NewHoleTriggerDistance > 1200)
            NewHoleTriggerDistance := 1200
        NewHoleDismissDistance := Integer(payload.Get("holeDismissDistance", IniRead(ConfigFile, "Appearance", "HoleDismissDistance", "320")))
        if (NewHoleDismissDistance < NewHoleTriggerDistance + 20)
            NewHoleDismissDistance := NewHoleTriggerDistance + 20
        if (NewHoleDismissDistance > 1600)
            NewHoleDismissDistance := 1600
        NewHoleFixedX := Integer(payload.Get("holeFixedX", IniRead(ConfigFile, "Appearance", "HoleFixedX", "360")))
        NewHoleFixedY := Integer(payload.Get("holeFixedY", IniRead(ConfigFile, "Appearance", "HoleFixedY", "260")))
        NewHoleSizeScale := Float(payload.Get("holeSizeScale", IniRead(ConfigFile, "Appearance", "HoleSizeScale", "1.0")))
        if (NewHoleSizeScale < 0.6)
            NewHoleSizeScale := 0.6
        if (NewHoleSizeScale > 1.8)
            NewHoleSizeScale := 1.8
        NewHoleAnimLevel := Float(payload.Get("holeAnimLevel", IniRead(ConfigFile, "Appearance", "HoleAnimLevel", "1.0")))
        if (NewHoleAnimLevel < 0.4)
            NewHoleAnimLevel := 0.4
        if (NewHoleAnimLevel > 2.2)
            NewHoleAnimLevel := 2.2
        NewHoleVisualStyle := StrLower(Trim(String(payload.Get("holeVisualStyle", IniRead(ConfigFile, "Appearance", "HoleVisualStyle", "ring")))))
        if (NewHoleVisualStyle != "ring" && NewHoleVisualStyle != "starry")
            NewHoleVisualStyle := "ring"
        NewHoleHideDockEnabled := !!payload.Get("holeHideDockEnabled", IniRead(ConfigFile, "Appearance", "HoleHideDockEnabled", "1") = "1")
        NewHoleHideDockEdge := StrLower(Trim(String(payload.Get("holeHideDockEdge", IniRead(ConfigFile, "Appearance", "HoleHideDockEdge", "right")))))
        if (NewHoleHideDockEdge != "right" && NewHoleHideDockEdge != "left" && NewHoleHideDockEdge != "top" && NewHoleHideDockEdge != "bottom")
            NewHoleHideDockEdge := "right"
        NewHoleHideDockMargin := Integer(payload.Get("holeHideDockMargin", IniRead(ConfigFile, "Appearance", "HoleHideDockMargin", "10")))
        if (NewHoleHideDockMargin < 0)
            NewHoleHideDockMargin := 0
        if (NewHoleHideDockMargin > 80)
            NewHoleHideDockMargin := 80

        IniWrite(NewHolePositionMode, ConfigFile, "Appearance", "HolePositionMode")
        IniWrite(String(NewHoleTriggerDistance), ConfigFile, "Appearance", "HoleTriggerDistance")
        IniWrite(String(NewHoleDismissDistance), ConfigFile, "Appearance", "HoleDismissDistance")
        IniWrite(String(NewHoleFixedX), ConfigFile, "Appearance", "HoleFixedX")
        IniWrite(String(NewHoleFixedY), ConfigFile, "Appearance", "HoleFixedY")
        IniWrite(String(NewHoleSizeScale), ConfigFile, "Appearance", "HoleSizeScale")
        IniWrite(String(NewHoleAnimLevel), ConfigFile, "Appearance", "HoleAnimLevel")
        IniWrite(NewHoleVisualStyle, ConfigFile, "Appearance", "HoleVisualStyle")
        IniWrite(NewHoleHideDockEnabled ? "1" : "0", ConfigFile, "Appearance", "HoleHideDockEnabled")
        IniWrite(NewHoleHideDockEdge, ConfigFile, "Appearance", "HoleHideDockEdge")
        IniWrite(String(NewHoleHideDockMargin), ConfigFile, "Appearance", "HoleHideDockMargin")
        try GDHO_SetScreenAnchor(NewHoleFixedX, NewHoleFixedY)
        try GDHO_ApplySettings(NewHolePositionMode, NewHoleTriggerDistance, NewHoleDismissDistance, NewHoleFixedX, NewHoleFixedY, NewHoleSizeScale, NewHoleAnimLevel, NewHoleVisualStyle)
        try GDHO_ApplyHideDockSettings(NewHoleHideDockEnabled, NewHoleHideDockEdge, NewHoleHideDockMargin)
        return true
    } catch as err {
        errorMsg := "淇濆瓨澶辫触: " . err.Message
        return false
    }
}

ConfigWebView_SaveAppearanceActivationMode(mode, &errorMsg := "") {
    global AppearanceActivationMode, ConfigFile
    try {
        newMode := NormalizeAppearanceActivationMode(mode)
        if (newMode = "") {
            errorMsg := "invalid activation mode"
            return false
        }
        try OutputDebug("[ConfigWebView] saveAppearanceActivationMode mode=" . newMode)
        catch {
        }
        AppearanceActivationMode := newMode
        IniWrite(AppearanceActivationMode, ConfigFile, "Appearance", "ActivationMode")
        if (newMode = "toolbar") {
            try FloatingToolbar_ClearOverlaySuppression()
            catch {
            }
        }
        ; Defer the actual visibility change so we do not re-enter WebView2 show/create paths
        ; while still inside the config WebView message callback.
        try SetTimer(ApplyAppearanceActivationMode, -10)
        catch {
            try ApplyAppearanceActivationMode()
            catch {
            }
        }
        if (newMode = "toolbar") {
            try SetTimer(FloatingToolbar_ShowForActivationMode, -40)
            catch {
            }
        } else if (newMode = "hole" || newMode = "bubble") {
            try SetTimer((*) => HideFloatingToolbar(), -50)
            catch {
            }
        }
        return true
    } catch as err {
        errorMsg := err.Message
        return false
    }
}

ConfigWebView_SaveSettingsSingleFlight(payload) {
    global g_ConfigSaveInFlight, g_ConfigSaveQueuedPayload, g_ConfigSaveFlushTimerArmed, g_ConfigSaveLastTick
    nowTick := A_TickCount
    if (IsSet(g_ConfigSaveInFlight) && g_ConfigSaveInFlight) {
        g_ConfigSaveQueuedPayload := payload
        return
    }
    if IsSet(g_ConfigSaveLastTick) {
        delta := nowTick - g_ConfigSaveLastTick
        if (delta < 350) {
            g_ConfigSaveQueuedPayload := payload
            if !(IsSet(g_ConfigSaveFlushTimerArmed) && g_ConfigSaveFlushTimerArmed) {
                g_ConfigSaveFlushTimerArmed := true
                SetTimer(ConfigWebView_FlushQueuedSaveSettings, -(350 - delta + 10))
            }
            return
        }
    }
    ConfigWebView_RunSaveSettings(payload)
}

ConfigWebView_FlushQueuedSaveSettings(*) {
    global g_ConfigSaveFlushTimerArmed, g_ConfigSaveQueuedPayload
    g_ConfigSaveFlushTimerArmed := false
    if !(IsSet(g_ConfigSaveQueuedPayload) && (g_ConfigSaveQueuedPayload is Map))
        return
    payload := g_ConfigSaveQueuedPayload
    g_ConfigSaveQueuedPayload := 0
    ConfigWebView_RunSaveSettings(payload)
}

ConfigWebView_RunSaveSettings(payload) {
    global g_ConfigSaveInFlight, g_ConfigSaveQueuedPayload, g_ConfigSaveLastTick
    if !(payload is Map)
        payload := Map()
    g_ConfigSaveInFlight := true
    err := ""
    ok := false
    try ok := ConfigWebView_ValidateAndApply(payload, &err)
    catch as e {
        ok := false
        err := e.Message
    }
    ConfigWebView_Send(Map("type", "saveResult", "ok", ok, "error", err))
    g_ConfigSaveLastTick := A_TickCount
    g_ConfigSaveInFlight := false
    if (IsSet(g_ConfigSaveQueuedPayload) && (g_ConfigSaveQueuedPayload is Map))
        SetTimer(ConfigWebView_FlushQueuedSaveSettings, -380)
}

ConfigWebView_OnMessage(sender, args) {
    global ConfigWV2Ready, UseWebViewSettings
    jsonStr := args.WebMessageAsJson
    try {
        msg := Jxon_Load(jsonStr)
    } catch {
        return
    }
    if !(msg is Map)
        return
    action := msg.Has("type") ? msg["type"] : (msg.Has("action") ? msg["action"] : "")
    if (action = "")
        return
    try OutputDebug("[ConfigWebView] onmessage action=" . action)
    catch {
    }
    switch action {
        case "ready":
            ConfigWV2Ready := true
            ConfigWebView_Send(Map("type", "initData", "payload", ConfigWebView_BuildInitDataSafe()))
            ConfigWebView_PostFullTextStatus(true)
            ConfigWebView_SendDockConfig()
        case "nmDockReady":
            ConfigWebView_SendDockConfig()
        case "nmDockLeave":
            ; lifecycle handled by ShowConfigWebViewGUI/ConfigWebView_Close
        case "nmDockCmd":
            ConfigWebView_ExecuteDockCmd(msg)
        case "fulltextStatusRequest":
            withCfg := msg.Has("withConfig") ? (msg["withConfig"] ? true : false) : true
            ConfigWebView_PostFullTextStatus(withCfg)
        case "fulltextControl":
            act := msg.Has("control") ? String(msg["control"]) : "start"
            ConfigWebView_FullTextControl(act)
        case "fulltextConfigUpdate":
            pl := msg.Has("payload") && (msg["payload"] is Map) ? msg["payload"] : Map()
            ConfigWebView_FullTextUpdateConfig(pl)
        case "fulltextPickIndexDir":
            selectedDir := ""
            try selectedDir := FileSelect("D", A_ScriptDir, "閫夋嫨绱㈠紩鐩綍")
            if (selectedDir = "")
                selectedDir := ""
            ConfigWebView_Send(Map("type", "fulltextBrowseResult", "path", selectedDir))
        case "fulltextProbeRequest":
            ConfigWebView_FullTextProbe()
        case "browseCursorPath":
            selected := FileSelect("1", A_ScriptDir, "閫夋嫨 Cursor.exe", "Executable (*.exe)")
            if (selected = "")
                selected := ""
            ConfigWebView_Send(Map("type", "browseCursorPathResult", "path", selected))
        case "saveSettings":
            payload := msg.Get("payload", Map())
            if (payload is String && payload != "") {
                try payload := Jxon_Load(payload)
                catch {
                    payload := Map()
                }
            }
            if !(payload is Map)
                payload := Map()
            ConfigWebView_SaveSettingsSingleFlight(payload)
        case "saveAppearanceActivationMode":
            mode := msg.Get("mode", "")
            err := ""
            ok := ConfigWebView_SaveAppearanceActivationMode(mode, &err)
            ConfigWebView_Send(Map("type", "saveAppearanceActivationModeResult", "ok", ok, "error", err, "mode", NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar")))
        case "saveHoleSettings":
            payload := msg.Get("payload", Map())
            if (payload is String && payload != "") {
                try payload := Jxon_Load(payload)
                catch {
                    payload := Map()
                }
            }
            if !(payload is Map)
                payload := Map()
            err := ""
            ok := ConfigWebView_SaveHoleOnly(payload, &err)
            ConfigWebView_Send(Map("type", "saveHoleResult", "ok", ok, "error", err))
        case "saveKeybinderToolbarLayout":
            tl := msg.Has("toolbarLayout") && msg["toolbarLayout"] is Array ? msg["toolbarLayout"] : []
            cml := msg.Has("contextMenuLayout") && msg["contextMenuLayout"] is Array ? msg["contextMenuLayout"] : []
            ok := false
            err := ""
            try {
                try {
                    _LoadCommands()
                } catch {
                }
                if _VK_ApplyToolbarLayoutFromWeb(Map("toolbarLayout", tl)) {
                    _VK_ApplyContextMenuLayoutFromWeb(cml)
                    _SaveBindings()
                    try FloatingToolbarReloadFromToolbarLayout()
                    catch as e
                        OutputDebug("[ConfigWebView] FloatingToolbarReloadFromToolbarLayout: " . e.Message)
                    if (IsSet(g_VK_Ready) && g_VK_Ready)
                        _PushInit()
                    ok := true
                } else
                    err := "invalid toolbar layout or commands not loaded"
            } catch as e {
                err := e.Message
            }
            ConfigWebView_Send(Map("type", "saveKeybinderToolbarLayoutResult", "ok", ok, "error", err))
        case "invokeAction":
            op := msg.Get("op", msg.Get("action", ""))
            payload := msg.Get("payload", Map())
            ok := true
            err := ""
            try {
                switch op {
                    case "installCursorChinese":
                        InstallCursorChinese()
                    case "exportConfig":
                        ExportConfig()
                    case "importConfig":
                        ImportConfig()
                    case "resetToDefaults":
                        ResetToDefaults()
                    case "importPromptTemplates":
                        ImportPromptTemplates()
                    case "exportPromptTemplates":
                        ExportPromptTemplates()
                    case "reloadPromptTemplates":
                        LoadPromptTemplates()
                    case "promptTemplateUpsert":
                        WebViewPromptTemplateUpsert(payload)
                    case "promptTemplateDelete":
                        WebViewPromptTemplateDelete(payload)
                    case "promptTemplateSetDefault":
                        WebViewPromptTemplateSetDefault(payload)
                    case "openLegacySettings":
                        try {
                            CloseConfigGUI()
                        } catch {
                        }
                        OpenLegacyConfigGUI()
                    case "openLegacyTab":
                        targetTab := msg.Get("tab", "general")
                        try {
                            CloseConfigGUI()
                        } catch {
                        }
                        OpenLegacyConfigGUI(targetTab)
                    case "openCompareSettings":
                        ; 淇濈暀褰撳墠 WebView锛屽悓鏃跺啀鎵撳紑涓€浠藉師鐗堣缃〉鐢ㄤ簬瀵圭収
                        OpenLegacyConfigGUI()
                    default:
                        ok := false
                        err := "鏈煡鎿嶄綔: " . op
                }
            } catch as e {
                ok := false
                err := e.Message
            }
            ConfigWebView_Send(Map("type", "actionResult", "ok", ok, "error", err, "op", op))
            if ok
                ConfigWebView_Send(Map("type", "initData", "payload", ConfigWebView_BuildInitDataSafe()))
        case "cancel":
            CloseConfigGUI()
    }
}


WebViewPromptTemplateUpsert(payload) {
    global PromptTemplates, TemplateIndexByArrayIndex
    if !(payload is Map)
        throw Error("妯℃澘鏁版嵁鏃犳晥")
    tId := Trim(payload.Get("id", ""))
    tTitle := Trim(payload.Get("title", ""))
    tCategory := Trim(payload.Get("category", ""))
    tContent := payload.Get("content", "")
    if (tTitle = "" || tContent = "")
        throw Error("template title/content cannot be empty")
    if (tCategory = "")
        tCategory := "custom"
    if (tId != "" && TemplateIndexByArrayIndex.Has(tId)) {
        idx := TemplateIndexByArrayIndex[tId]
        old := PromptTemplates[idx]
        old.Title := tTitle
        old.Category := tCategory
        old.Content := tContent
        PromptTemplates[idx] := old
    } else {
        if (tId = "")
            tId := "template_" . A_TickCount
        newTpl := { ID: tId, Title: tTitle, Content: tContent, Icon: "", Category: tCategory }
        PromptTemplates.Push(newTpl)
    }
    InvalidateTemplateCache()
    SavePromptTemplates()
}

WebViewPromptTemplateDelete(payload) {
    global PromptTemplates, DefaultTemplateIDs, TemplateIndexByArrayIndex
    if !(payload is Map)
        throw Error("妯℃澘鏁版嵁鏃犳晥")
    tId := Trim(payload.Get("id", ""))
    if (tId = "")
        throw Error("妯℃澘ID涓嶈兘涓虹┖")
    for _, did in DefaultTemplateIDs {
        if (did = tId)
            throw Error("榛樿妯℃澘涓嶈兘鍒犻櫎")
    }
    if !TemplateIndexByArrayIndex.Has(tId)
        throw Error("template does not exist")
    idx := TemplateIndexByArrayIndex[tId]
    PromptTemplates.RemoveAt(idx)
    InvalidateTemplateCache()
    SavePromptTemplates()
}

WebViewPromptTemplateSetDefault(payload) {
    global DefaultTemplateIDs, TemplateIndexByID
    if !(payload is Map)
        throw Error("榛樿妯℃澘鍙傛暟鏃犳晥")
    tId := Trim(payload.Get("id", ""))
    tType := Trim(payload.Get("type", ""))
    if (tId = "" || tType = "")
        throw Error("default template params are incomplete")
    if !TemplateIndexByID.Has(tId)
        throw Error("template does not exist")
    if (tType != "Explain" && tType != "Refactor" && tType != "Optimize")
        throw Error("榛樿妯℃澘绫诲瀷鏃犳晥")
    DefaultTemplateIDs[tType] := tId
    SavePromptTemplates()
}


; ===================== 淇濆瓨閰嶇疆绐楀彛浣嶇疆 =====================
SaveConfigGUIPosition(ConfigGUI) {
    global GuiID_ConfigGUI
    try {
        ; 妫€鏌ョ獥鍙ｆ槸鍚﹁繕瀛樺湪
        if (!ConfigGUI || !GuiID_ConfigGUI || GuiID_ConfigGUI = 0) {
            ; 绐楀彛宸插叧闂紝鍋滄瀹氭椂鍣ㄥ苟绔嬪嵆淇濆瓨鎵€鏈夊緟淇濆瓨鐨勪綅缃?
            SetTimer(() => SaveConfigGUIPosition(ConfigGUI), 0)
            FlushPendingWindowPositions()
            return
        }
        
        ; 鑾峰彇绐楀彛浣嶇疆鍜屽ぇ灏?
        WinGetPos(&WinX, &WinY, &WinW, &WinH, ConfigGUI.Hwnd)
        WindowName := GetText("config_title")
        ; 浣跨敤寤惰繜淇濆瓨锛岀粺涓€绠＄悊
        QueueWindowPositionSave(WindowName, WinX, WinY, WinW, WinH)
    } catch as err {
        ; 蹇界暐閿欒锛堢獥鍙ｅ彲鑳藉凡鍏抽棴锛?
    }
}

; WebView 璁剧疆椤靛叧闂紙鐢?CloseConfigGUI 鍦?ConfigWebViewMode 涓嬭皟鐢級
ConfigWebView_Close() {
    global GuiID_ConfigGUI, ConfigWV2Ctrl, ConfigWV2
    try FloatingToolbar_PageDockLeave("settings")
    try {
        WMActivateChain_Unregister(ConfigWebView_WM_ACTIVATE)
        try WebView2_NotifyHidden(ConfigWV2)
        GuiID_ConfigGUI.Hide()
    } catch {
    }
}

