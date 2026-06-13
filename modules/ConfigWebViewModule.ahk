; ConfigWebViewModule.ahk 鈥?璁剧疆涓績 WebView 瀹夸富涓庢秷鎭ˉ锛堢敱涓昏剼鏈?#Include锛?
; 渚濊禆锛歐ebView2銆乄MActivateChain銆丣xon銆佷富鑴氭湰鍏ㄥ眬涓?BuildAppLocalUrl / WebView_DumpJson 绛夈€?

global ConfigWebViewNavFallbackTried := false
; 由搜索中心等单次打开设置时覆盖首屏标签，不写入 INI
global g_ConfigWebView_OneShotDefaultTab := ""
global g_ConfigWebView_PendingStudioSync := false
; 每次打开设置窗仅允许一次「跳到默认启动页」，避免 ready 与延迟 initData 重复抢导航
global g_ConfigWebView_StartTabNavigated := false

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

ConfigWebView_IsVkAvailable() {
    for name in ["VK_Show", "VK_EnsureInit", "VK_Execute", "_LoadCommands"] {
        try {
            if IsObject(Func(name))
                return true
        } catch {
        }
    }
    return false
}

ConfigWebView_OpenVkKeybinder() {
    if !ConfigWebView_IsVkAvailable()
        throw Error("VK KeyBinder 未加载（请完全退出并重启牛马）")
    try {
        if IsObject(Func("VK_EnsureInit"))
            VK_EnsureInit(true)
    } catch as e {
        OutputDebug("[ConfigWebView] VK_EnsureInit: " . e.Message)
    }
    try {
        SurfaceIntent_Open("virtual_keyboard")
        return
    } catch as e {
        try {
            if IsObject(Func("VK_Execute")) {
                VK_Execute("sys_show_vk")
                return
            }
        } catch as e2 {
            throw Error("VK 打开失败: " . e.Message . " / " . e2.Message)
        }
        throw Error("VK 打开失败: " . e.Message)
    }
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
    try SurfaceManager_ObserveInit("config_webview", Map("entry", "ConfigWebView_CreateHost"))
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
    global ConfigWV2Ready, g_ConfigWebView_StartTabNavigated
    try {
        if !(IsSet(ConfigWV2Ready) && ConfigWV2Ready)
            return
        navigate := false
        if !g_ConfigWebView_StartTabNavigated {
            navigate := true
            g_ConfigWebView_StartTabNavigated := true
        }
        ConfigWebView_Send(Map("type", "initData", "payload", ConfigWebView_BuildInitDataSafe(), "navigateToStartTab", navigate))
    }
}

ShowConfigWebViewGUI() {
    if FuncExists("SurfaceIntent_RouteExternalOpen") && SurfaceIntent_RouteExternalOpen("config_webview")
        return
    global GuiID_ConfigGUI, GuiID_ClipboardManager, ConfigPanelScreenIndex, g_ConfigWebView_LastShown, g_ConfigWebView_StartTabNavigated
    skipTel := FuncExists("SurfaceIntent_ShouldSkipExecutorTelemetry") && SurfaceIntent_ShouldSkipExecutorTelemetry()
    reqId := 0
    if !skipTel {
        reqId := SurfaceManager_Request("config_webview", "open", "ShowConfigWebViewGUI", Map("hostAliveBefore", ConfigWebView_HostAlive() ? 1 : 0))
        try SurfaceManager_BeforeOpen("config_webview", "ShowConfigWebViewGUI", Map("requestId", reqId, "hostAliveBefore", ConfigWebView_HostAlive() ? 1 : 0))
        try SurfaceManager_RegisterSurface("config_webview")
    }
    g_ConfigWebView_StartTabNavigated := false
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
    try SurfaceManager_ObserveShow("config_webview", Map("entry", "ShowConfigWebViewGUI", "hostAlive", ConfigWebView_HostAlive() ? 1 : 0, "requestId", reqId))
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
    htmlPath := HtmlPanelPath("SettingsPanel.html")
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
        fileUrl := "file:///" . StrReplace(HtmlPanelPath("SettingsPanel.html"), "\", "/")
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

ConfigWebView_NotifyStudioLlmSynced(*) {
    global g_ConfigWebView_PendingStudioSync
    if !IsSet(g_ConfigWebView_PendingStudioSync) || !g_ConfigWebView_PendingStudioSync
        return
    g_ConfigWebView_PendingStudioSync := false
    studio := Map()
    if FuncExists("UserStudio_PayloadForWeb")
        studio := UserStudio_PayloadForWeb()
    ConfigWebView_Send(Map("type", "syncNiumaChatLlmResult", "ok", true, "error", "", "userStudio", studio))
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
    return Nmer_SearchCenterCoreExe()
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
        "maxFileSizeMB", 16,
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

ConfigWebView_SendCacheInfo() {
    info := Nmer_CollectCacheInfo()
    webItems := []
    for it in info["items"] {
        webItems.Push(Map(
            "id", it["id"],
            "label", it["label"],
            "path", it["path"],
            "hint", it["hint"],
            "bytes", it["bytes"],
            "sizeText", it["sizeText"]
        ))
    }
    ConfigWebView_Send(Map(
        "type", "cacheInfo",
        "root", info["root"],
        "totalBytes", info["totalBytes"],
        "totalText", info["totalText"],
        "items", webItems
    ))
}

ConfigWebView_OpenCacheFolder(target) {
    t := StrLower(Trim(String(target)))
    path := Nmer_UserCacheRoot()
    switch t {
        case "fulltext":
            path := Nmer_FullTextIndexDir()
        case "images":
            path := Nmer_CacheImagesDir()
        case "thumbs":
            path := Nmer_ThumbsDir()
        case "temp":
            path := Nmer_CacheTempDir()
        case "debug":
            path := Nmer_DebugDir()
        default:
            path := Nmer_UserCacheRoot()
    }
    ok := Nmer_OpenPathInExplorer(path)
    ConfigWebView_Send(Map("type", "cacheOpenFolderResult", "ok", ok, "path", path))
}

ConfigWebView_ClearCacheAsync(targets*) {
    hasFt := false
    for t in targets {
        if (StrLower(Trim(String(t))) = "fulltext") {
            hasFt := true
            break
        }
    }
    if hasFt {
        ConfigWebView_EnsureSearchCoreRunningAsync((ok) => ConfigWebView_ClearCache_Continue(ok, targets*))
        return
    }
    ConfigWebView_ClearCache_Finish(targets*)
}

ConfigWebView_ClearCache_Continue(searchCoreOk, targets*) {
    if searchCoreOk {
        ConfigWebView_HttpSearchCoreJsonAsync("POST", "/v1/fulltext/control", Jxon_Dump(Map("action", "stop")), (resp) => (
            ConfigWebView_ClearCache_Finish(targets*)
        ))
        return
    }
    ConfigWebView_ClearCache_Finish(targets*)
}

ConfigWebView_ClearCache_Finish(targets*) {
    cleared := Nmer_ClearCacheTargets(targets*)
    needRebuild := false
    for c in cleared {
        if (c = "fulltext") {
            needRebuild := true
            break
        }
    }
    if needRebuild {
        ConfigWebView_EnsureSearchCoreRunningAsync((ok) => (
            ok ? ConfigWebView_HttpSearchCoreJsonAsync("POST", "/v1/fulltext/control", Jxon_Dump(Map("action", "rebuild")), (*) => ConfigWebView_SendCacheInfo()) : ConfigWebView_SendCacheInfo()
        ))
    } else
        ConfigWebView_SendCacheInfo()
    ConfigWebView_Send(Map("type", "cacheClearResult", "ok", true, "cleared", cleared))
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
    bindingsOut := Map()
    suggestedOut := Map()
    if g_Commands.Has("Bindings") && g_Commands["Bindings"] is Map {
        for cmdId, v in g_Commands["Bindings"] {
            cid := Trim(String(cmdId))
            if (cid = "")
                continue
            if (v = "NONE") {
                bindingsOut[cid] := Map("ahkKey", "", "displayKey", "", "explicitNone", true)
                continue
            }
            key := Trim(String(v))
            if (key = "")
                continue
            dk := key
            if FuncExists("_AhkKeyToDisplay")
                try dk := _AhkKeyToDisplay(key)
            bindingsOut[cid] := Map("ahkKey", key, "displayKey", dk)
        }
    }
    if g_Commands.Has("SuggestedBindings") && g_Commands["SuggestedBindings"] is Map {
        for cmdId, skey in g_Commands["SuggestedBindings"] {
            cid := Trim(String(cmdId))
            sk := Trim(String(skey))
            if (cid != "" && sk != "")
                suggestedOut[cid] := sk
        }
    }
    return Map(
        "toolbarLayout", tl,
        "commands", cmds,
        "contextMenuLayout", cml,
        "bindings", bindingsOut,
        "suggestedBindings", suggestedOut
    )
}

ConfigWebView_RelayVkWebJson(jsonStr) {
    global ConfigWV2Ready
    if !ConfigWV2Ready || (Trim(String(jsonStr)) = "")
        return
    try evt := FuncExists("Jxon_LoadSafe") ? Jxon_LoadSafe(jsonStr) : Jxon_Load(jsonStr)
    catch {
        return
    }
    if !(evt is Map)
        return
    t := evt.Has("type") ? String(evt["type"]) : ""
    if (t = "")
        return
    switch t {
        case "bindingUpdated", "recordHint", "recordPending", "confirmConflict", "bind_blocked":
            ConfigWebView_Send(Map("type", "vkWebEvent", "event", evt))
        default:
    }
}

ConfigWebView_VkEnsureCommandsLoaded() {
    try {
        if FuncExists("_LoadCommands")
            _LoadCommands()
    } catch {
    }
}

ConfigWebView_VkPushBindingsSnapshot() {
    snap := ConfigWebView_GetKeybinderToolbarSnapshot()
    b := snap.Has("bindings") ? snap["bindings"] : Map()
    s := snap.Has("suggestedBindings") ? snap["suggestedBindings"] : Map()
    ConfigWebView_Send(Map("type", "keybinderBindingsSnapshot", "bindings", b, "suggestedBindings", s))
}

ConfigWebView_BuildInitData() {
    global CursorPath, CapsLockHoldTimeSeconds, CapsLockHoldVkEnabled, AutoStart, DefaultStartTab, g_ConfigWebView_OneShotDefaultTab
    global ThemeMode, FunctionPanelPos, ConfigPanelScreenIndex, ConfigPanelPos, ClipboardPanelPos, PanelScreenIndex
    global PromptQuickCaptureHotkey
    global CursorShortcut_CommandPalette, CursorShortcut_Terminal, CursorShortcut_GlobalSearch
    global CursorShortcut_Explorer, CursorShortcut_SourceControl, CursorShortcut_Extensions
    global CursorShortcut_Browser, CursorShortcut_Settings, CursorShortcut_CursorSettings
    global Language, AISleepTime, LaunchDelaySeconds, MsgBoxScreenIndex, VoiceInputScreenIndex, CursorPanelScreenIndex, ClipboardPanelScreenIndex
    global SearchEngine, AutoLoadSelectedText, AutoUpdateVoiceInput, VoiceSearchEnabledCategories, VoiceSearchSelectedEngines
    global ConfigFile, PromptTemplates
    global FloatingToolbarButtonItems, FloatingToolbarMenuItems, FloatingToolbarButtonOptions, FloatingToolbarMenuOptions
    global AppearanceActivationMode
    monitorCount := 1
    try monitorCount := MonitorGetCount()
    catch
        monitorCount := 1
    popupScreenIndex := ConfigWebView_ReadPersistedPopupScreenIndex()
    ConfigWebView_ApplyPopupScreenIndex(popupScreenIndex)
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
        "ocrEnhanceEnabled", IniRead(ConfigFile, "Screenshot", "OcrEnhanceEnabled", "1") != "0",
        "ocrScalePrimary", Integer(IniRead(ConfigFile, "Screenshot", "OcrScalePrimary", "150")),
        "ocrScaleSecondary", Integer(IniRead(ConfigFile, "Screenshot", "OcrScaleSecondary", "200")),
        "ocrUseGrayscale", IniRead(ConfigFile, "Screenshot", "OcrUseGrayscale", "1") != "0",
        "ocrMonochromeLow", Integer(IniRead(ConfigFile, "Screenshot", "OcrMonochromeLow", "160")),
        "ocrMonochromeHigh", Integer(IniRead(ConfigFile, "Screenshot", "OcrMonochromeHigh", "175")),
        "ocrUseInvert", IniRead(ConfigFile, "Screenshot", "OcrUseInvert", "1") != "0",
        "ocrTextLayoutMode", IniRead(ConfigFile, "Settings", "ScreenshotOCRTextLayoutMode", "keep"),
        "ocrPunctuationMode", IniRead(ConfigFile, "Settings", "ScreenshotOCRPunctuationMode", "keep"),
        "ocrDirectCopyEnabled", IniRead(ConfigFile, "Settings", "ScreenshotOCRDirectCopyEnabled", "0") = "1"
    )
    startTabForOpen := FuncExists("NormalizeDefaultStartTab")
        ? NormalizeDefaultStartTab(DefaultStartTab) : DefaultStartTab
    if (IsSet(g_ConfigWebView_OneShotDefaultTab) && g_ConfigWebView_OneShotDefaultTab != "") {
        startTabForOpen := FuncExists("NormalizeDefaultStartTab")
            ? NormalizeDefaultStartTab(g_ConfigWebView_OneShotDefaultTab) : g_ConfigWebView_OneShotDefaultTab
        g_ConfigWebView_OneShotDefaultTab := ""
    }
    autoStartForWeb := FuncExists("ReadPersistedAutoStart") ? ReadPersistedAutoStart() : AutoStart
    AutoStart := autoStartForWeb
    cfgPayload := Map(
        "cursorPath", CursorPath,
        "capslockHoldTimeSeconds", CapsLockHoldTimeSeconds,
        "capsLockHoldVkEnabled", CapsLockHoldVkEnabled,
        "autoStart", autoStartForWeb,
        "defaultStartTab", startTabForOpen,
        "vkAvailable", ConfigWebView_IsVkAvailable(),
        ; 蹇呴』浠?INI 涓哄噯锛氬唴瀛樹腑 ThemeMode 鍙兘涓庣鐩樹笉涓€鑷达紙渚嬪浠?WebView 鍥炶皟鎵撳紑璁剧疆鏃讹級
        "themeMode", ReadPersistedThemeMode(),
        "popupScreenIndex", popupScreenIndex,
        "monitorCount", monitorCount,
        "functionPanelPos", FunctionPanelPos,
        "configPanelScreenIndex", ConfigPanelScreenIndex,
        "configPanelPos", ConfigPanelPos,
        "clipboardPanelPos", ClipboardPanelPos,
        "panelScreenIndex", PanelScreenIndex,
        "cursorRules", cursorRules,
        "promptTemplateSummary", promptTemplateSummary,
        "cursorShortcuts", [
            Map("label", "命令面板", "shortcut", CursorShortcut_CommandPalette, "vkCommandId", "qa_command_palette", "catalogId", "showCommands", "desc", "Cursor 命令面板（悬浮栏可触发）"),
            Map("label", "终端", "shortcut", CursorShortcut_Terminal, "vkCommandId", "qa_terminal", "catalogId", "toggleTerminal", "desc", "打开集成终端"),
            Map("label", "全局搜索", "shortcut", CursorShortcut_GlobalSearch, "vkCommandId", "qa_global_search", "catalogId", "globalSearch", "desc", "Cursor 工作区全局搜索"),
            Map("label", "资源管理器", "shortcut", CursorShortcut_Explorer, "vkCommandId", "qa_explorer", "catalogId", "explorer", "desc", "显示文件资源管理器侧栏"),
            Map("label", "源代码管理", "shortcut", CursorShortcut_SourceControl, "vkCommandId", "qa_source_control", "catalogId", "sourceControl", "desc", "Git / 源代码管理视图"),
            Map("label", "扩展", "shortcut", CursorShortcut_Extensions, "vkCommandId", "qa_extensions", "catalogId", "extensions", "desc", "扩展市场侧栏"),
            Map("label", "简单浏览器", "shortcut", CursorShortcut_Browser, "vkCommandId", "qa_browser", "catalogId", "simpleBrowser", "desc", "内置 Simple Browser"),
            Map("label", "编辑器设置", "shortcut", CursorShortcut_Settings, "vkCommandId", "qa_settings", "catalogId", "vscodeSettings", "desc", "VS Code 设置"),
            Map("label", "Cursor 设置", "shortcut", CursorShortcut_CursorSettings, "vkCommandId", "qa_cursor_settings", "catalogId", "cursorSettings", "desc", "Cursor 专属设置")
        ],
        "promptQuickCaptureHotkey", PromptQuickCaptureHotkey,
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
        "holeSizeScale", CfgParseFloat(IniRead(ConfigFile, "Appearance", "HoleSizeScale", "1.0"), 1.0),
        "holeAnimLevel", CfgParseFloat(IniRead(ConfigFile, "Appearance", "HoleAnimLevel", "1.0"), 1.0),
        "holeVisualStyle", IniRead(ConfigFile, "Appearance", "HoleVisualStyle", "ring"),
        "holeHideDockEnabled", (IniRead(ConfigFile, "Appearance", "HoleHideDockEnabled", "1") = "1"),
        "holeHideDockEdge", IniRead(ConfigFile, "Appearance", "HoleHideDockEdge", "right"),
        "holeHideDockMargin", Integer(IniRead(ConfigFile, "Appearance", "HoleHideDockMargin", "10")),
        "holeDecoupledTopology", (IniRead(ConfigFile, "Appearance", "HoleDecoupledTopology", "1") = "1"),
        "holeStarFullscreen", (IniRead(ConfigFile, "Appearance", "HoleStarFullscreen", "0") = "1"),
        "holePanelPinned", (IniRead(ConfigFile, "Appearance", "HolePanelPinned", "0") = "1"),
        "holeTriggerTextSelect", (IniRead(ConfigFile, "Appearance", "HoleTriggerTextSelect", "1") = "1"),
        "holeTriggerCircleCw", (IniRead(ConfigFile, "Appearance", "HoleTriggerCircleCw", "0") = "1"),
        "holeTriggerCircleCcw", (IniRead(ConfigFile, "Appearance", "HoleTriggerCircleCcw", "0") = "1"),
        "holeTriggerRButtonHold", (IniRead(ConfigFile, "Appearance", "HoleTriggerRButtonHold", "0") = "1"),
        "holeRButtonHoldMs", (FuncExists("HoleTriggers_NormalizeHoldMs") ? HoleTriggers_NormalizeHoldMs(Integer(IniRead(ConfigFile, "Appearance", "HoleRButtonHoldMs", "3000"))) : Integer(IniRead(ConfigFile, "Appearance", "HoleRButtonHoldMs", "3000"))),
        "holeSensitivityPreset", ConfigWebView_ReadHoleSensitivityPreset(),
        "holePlacementPreset", ConfigWebView_ReadHolePlacementPreset()
    )
    kbSnap := ConfigWebView_GetKeybinderToolbarSnapshot()
    cfgPayload["keybinderToolbarLayout"] := kbSnap["toolbarLayout"]
    cfgPayload["keybinderCommands"] := kbSnap["commands"]
    cfgPayload["keybinderContextMenuLayout"] := kbSnap.Has("contextMenuLayout") ? kbSnap["contextMenuLayout"] : []
    cfgPayload["keybinderBindings"] := kbSnap.Has("bindings") ? kbSnap["bindings"] : Map()
    cfgPayload["keybinderSuggestedBindings"] := kbSnap.Has("suggestedBindings") ? kbSnap["suggestedBindings"] : Map()
    if FuncExists("UserStudio_PayloadForWeb")
        cfgPayload["userStudio"] := UserStudio_PayloadForWeb()
    if FuncExists("AppUpdateCheck_PayloadForWeb")
        cfgPayload["appUpdate"] := AppUpdateCheck_PayloadForWeb()
    cfgPayload["userCacheRoot"] := Nmer_UserCacheRoot()
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
            "cursorRules", Map("general","", "web","", "miniprogram","", "android","", "ios","", "python",""),
            "promptTemplateSummary", [],
            "promptQuickCaptureHotkey", "",
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
            "keybinderContextMenuLayout", [],
            "vkAvailable", ConfigWebView_IsVkAvailable()
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
    global PromptQuickCaptureHotkey
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
        if (payload.Has("cursorPath")) {
            NewCursorPath := NormalizeWindowsPath(payload.Get("cursorPath", ""))
            if (NewCursorPath = "") {
                errorMsg := "Cursor Path 不能为空"
                return false
            }
        } else
            NewCursorPath := CursorPath
        if (payload.Has("capslockHoldTimeSeconds")) {
            NewHold := CfgParseFloat(payload.Get("capslockHoldTimeSeconds", 0.5), CapsLockHoldTimeSeconds)
            if (NewHold < 0.1 || NewHold > 5.0) {
                errorMsg := "CapsLock Hold Time 超出范围"
                return false
            }
        } else
            NewHold := CapsLockHoldTimeSeconds
        if (payload.Has("autoStart"))
            NewAutoStart := ConfigWebView_CoerceBool(payload.Get("autoStart", false), AutoStart)
        else
            NewAutoStart := AutoStart
        applyHoleSettings := ConfigWebView_PayloadHasHoleSettings(payload)
        NewCapsLockHoldVk := CapsLockHoldVkEnabled
        if (payload.Has("capsLockHoldVkEnabled"))
            NewCapsLockHoldVk := payload["capsLockHoldVkEnabled"] ? true : false
        NewDefaultTab := DefaultStartTab
        if (payload.Has("defaultStartTab")) {
            NewDefaultTab := payload.Get("defaultStartTab", "general")
            if FuncExists("NormalizeDefaultStartTab")
                NewDefaultTab := NormalizeDefaultStartTab(NewDefaultTab)
            else {
                validTabs := Map("general",1, "appearance",1, "prompts",1, "hotkeys",1, "advanced",1, "screenshot",1, "search",1, "storage",1, "customize",1)
                if !validTabs.Has(NewDefaultTab)
                    NewDefaultTab := "general"
            }
        }
        NewTheme := ThemeMode
        if (payload.Has("themeMode"))
            NewTheme := payload["themeMode"]
        else if (payload.Has("ThemeMode"))
            NewTheme := payload["ThemeMode"]
        NewTheme := NormalizeIniThemeMode(NewTheme, NormalizeIniThemeMode(ThemeMode, "dark"))
        validPos := Map("center",1, "top-left",1, "top-right",1, "bottom-left",1, "bottom-right",1)
        NewPanelPos := FunctionPanelPos
        if (payload.Has("functionPanelPos")) {
            NewPanelPos := payload.Get("functionPanelPos", "center")
            if !validPos.Has(NewPanelPos)
                NewPanelPos := "center"
        }
        NewPopupScreen := PanelScreenIndex
        hasPopupScreen := payload.Has("popupScreenIndex") || payload.Has("panelScreenIndex")
        if (hasPopupScreen) {
            monitorCount := 1
            try monitorCount := MonitorGetCount()
            catch
                monitorCount := 1
            NewPopupScreen := Integer(payload.Has("popupScreenIndex") ? payload["popupScreenIndex"] : payload["panelScreenIndex"])
            if (NewPopupScreen < 1)
                NewPopupScreen := 1
            if (NewPopupScreen > monitorCount)
                NewPopupScreen := monitorCount
        }
        NewConfigPanelPos := ConfigPanelPos
        if (payload.Has("configPanelPos")) {
            NewConfigPanelPos := payload.Get("configPanelPos", "center")
            if !validPos.Has(NewConfigPanelPos)
                NewConfigPanelPos := "center"
        }
        NewClipboardPanelPos := ClipboardPanelPos
        if (payload.Has("clipboardPanelPos")) {
            NewClipboardPanelPos := payload.Get("clipboardPanelPos", "center")
            if !validPos.Has(NewClipboardPanelPos)
                NewClipboardPanelPos := "center"
        }
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
        NewLaunchDelay := CfgParseFloat(payload.Get("launchDelaySeconds", 3.0), 3.0)
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
            "ocrEnhanceEnabled", true,
            "ocrScalePrimary", 150,
            "ocrScaleSecondary", 200,
            "ocrUseGrayscale", true,
            "ocrMonochromeLow", 160,
            "ocrMonochromeHigh", 175,
            "ocrUseInvert", true,
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
            ocrScalePrimary := Integer(sc.Get("ocrScalePrimary", 150))
            if (ocrScalePrimary < 100)
                ocrScalePrimary := 100
            if (ocrScalePrimary > 300)
                ocrScalePrimary := 300
            ocrScaleSecondary := Integer(sc.Get("ocrScaleSecondary", 200))
            if (ocrScaleSecondary < 100)
                ocrScaleSecondary := 100
            if (ocrScaleSecondary > 300)
                ocrScaleSecondary := 300
            ocrMonoLow := Integer(sc.Get("ocrMonochromeLow", 160))
            if (ocrMonoLow < 0)
                ocrMonoLow := 0
            if (ocrMonoLow > 255)
                ocrMonoLow := 255
            ocrMonoHigh := Integer(sc.Get("ocrMonochromeHigh", 175))
            if (ocrMonoHigh < 0)
                ocrMonoHigh := 0
            if (ocrMonoHigh > 255)
                ocrMonoHigh := 255
            if (ocrMonoHigh < ocrMonoLow)
                ocrMonoHigh := ocrMonoLow
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
                "ocrEnhanceEnabled", sc.Get("ocrEnhanceEnabled", true) ? true : false,
                "ocrScalePrimary", ocrScalePrimary,
                "ocrScaleSecondary", ocrScaleSecondary,
                "ocrUseGrayscale", sc.Get("ocrUseGrayscale", true) ? true : false,
                "ocrMonochromeLow", ocrMonoLow,
                "ocrMonochromeHigh", ocrMonoHigh,
                "ocrUseInvert", sc.Get("ocrUseInvert", true) ? true : false,
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
        if (applyHoleSettings) {
            if payload.Has("holePlacementPreset") {
                placeMap := ConfigWebView_ApplyHolePlacementPreset(payload["holePlacementPreset"])
                for k, v in placeMap
                    payload[k] := v
            }
            if payload.Has("holeSensitivityPreset") && FuncExists("HoleTriggers_MapSensitivityPreset") {
                dist := HoleTriggers_MapSensitivityPreset(payload["holeSensitivityPreset"])
                payload["holeTriggerDistance"] := dist["trigger"]
                payload["holeDismissDistance"] := dist["dismiss"]
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
            NewHoleSizeScale := CfgParseFloat(payload.Get("holeSizeScale", IniRead(ConfigFile, "Appearance", "HoleSizeScale", "1.0")), 1.0)
            if (NewHoleSizeScale < 0.6)
                NewHoleSizeScale := 0.6
            if (NewHoleSizeScale > 1.8)
                NewHoleSizeScale := 1.8
            NewHoleAnimLevel := CfgParseFloat(payload.Get("holeAnimLevel", IniRead(ConfigFile, "Appearance", "HoleAnimLevel", "1.0")), 1.0)
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
        }

        if (payload.Has("cursorPath"))
            CursorPath := NewCursorPath
        if (payload.Has("capslockHoldTimeSeconds"))
            CapsLockHoldTimeSeconds := NewHold
        if (payload.Has("capsLockHoldVkEnabled"))
            CapsLockHoldVkEnabled := NewCapsLockHoldVk
        if (payload.Has("autoStart"))
            AutoStart := NewAutoStart
        if (payload.Has("defaultStartTab"))
            DefaultStartTab := NewDefaultTab
        ThemeMode := NewTheme
        if (payload.Has("functionPanelPos"))
            FunctionPanelPos := NewPanelPos
        if (payload.Has("configPanelPos"))
            ConfigPanelPos := NewConfigPanelPos
        if (payload.Has("clipboardPanelPos"))
            ClipboardPanelPos := NewClipboardPanelPos
        if (hasPopupScreen)
            ConfigWebView_ApplyPopupScreenIndex(NewPopupScreen)
        PromptQuickCaptureHotkey := NewCaptureHotkey
        Language := NewLanguage
        AISleepTime := NewAiSleepTime
        LaunchDelaySeconds := NewLaunchDelay
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

        if (payload.Has("cursorPath"))
            IniWrite(CursorPath, ConfigFile, "Settings", "CursorPath")
        IniWrite(String(AISleepTime), ConfigFile, "Settings", "AISleepTime")
        if (payload.Has("capslockHoldTimeSeconds"))
            IniWrite(String(CapsLockHoldTimeSeconds), ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
        if (payload.Has("capsLockHoldVkEnabled"))
            IniWrite(CapsLockHoldVkEnabled ? "1" : "0", ConfigFile, "Settings", "CapsLockHoldVkEnabled")
        IniWrite(String(LaunchDelaySeconds), ConfigFile, "Settings", "LaunchDelaySeconds")
        IniWrite(Language, ConfigFile, "Settings", "Language")
        if (payload.Has("defaultStartTab"))
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
        IniWrite(NewScreenshotCfg["ocrEnhanceEnabled"] ? "1" : "0", ConfigFile, "Screenshot", "OcrEnhanceEnabled")
        IniWrite(String(NewScreenshotCfg["ocrScalePrimary"]), ConfigFile, "Screenshot", "OcrScalePrimary")
        IniWrite(String(NewScreenshotCfg["ocrScaleSecondary"]), ConfigFile, "Screenshot", "OcrScaleSecondary")
        IniWrite(NewScreenshotCfg["ocrUseGrayscale"] ? "1" : "0", ConfigFile, "Screenshot", "OcrUseGrayscale")
        IniWrite(String(NewScreenshotCfg["ocrMonochromeLow"]), ConfigFile, "Screenshot", "OcrMonochromeLow")
        IniWrite(String(NewScreenshotCfg["ocrMonochromeHigh"]), ConfigFile, "Screenshot", "OcrMonochromeHigh")
        IniWrite(NewScreenshotCfg["ocrUseInvert"] ? "1" : "0", ConfigFile, "Screenshot", "OcrUseInvert")
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
        if (payload.Has("appearanceActivationMode") || payload.Has("AppearanceActivationMode"))
            IniWrite(AppearanceActivationMode, ConfigFile, "Appearance", "ActivationMode")
        if (applyHoleSettings) {
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
            NewHoleDecoupled := payload.Has("holeDecoupledTopology") ? !!payload["holeDecoupledTopology"] : true
            NewHoleStarFullscreen := payload.Has("holeStarFullscreen") ? !!payload["holeStarFullscreen"] : false
            NewHolePanelPinned := payload.Has("holePanelPinned") ? !!payload["holePanelPinned"] : false
            IniWrite(NewHoleDecoupled ? "1" : "0", ConfigFile, "Appearance", "HoleDecoupledTopology")
            IniWrite(NewHoleStarFullscreen ? "1" : "0", ConfigFile, "Appearance", "HoleStarFullscreen")
            IniWrite(NewHolePanelPinned ? "1" : "0", ConfigFile, "Appearance", "HolePanelPinned")
            try GDHO_DECOUPLED_TOPOLOGY := NewHoleDecoupled
            try GDHO_STAR_FULLSCREEN := NewHoleStarFullscreen
            try GDHO_PANEL_PINNED := NewHolePanelPinned
            if FuncExists("GDHO_SavePanelPositionToIni")
                try GDHO_SavePanelPositionToIni()
        }
        if (payload.Has("functionPanelPos"))
            IniWrite(FunctionPanelPos, ConfigFile, "Appearance", "FunctionPanelPos")
        if (payload.Has("configPanelPos"))
            IniWrite(ConfigPanelPos, ConfigFile, "Appearance", "ConfigPanelPos")
        if (payload.Has("clipboardPanelPos"))
            IniWrite(ClipboardPanelPos, ConfigFile, "Appearance", "ClipboardPanelPos")
        if (payload.Has("autoStart")) {
            if !ConfigWebView_PersistAutoStartSetting(AutoStart, &errorMsg)
                return false
        }
        PromptQuickPad_RegisterCaptureHotkey()
        try FloatingToolbarPushButtonConfigToWeb()
        if (applyHoleSettings) {
            try GDHO_SetScreenAnchor(NewHoleFixedX, NewHoleFixedY)
            try GDHO_ApplySettings(NewHolePositionMode, NewHoleTriggerDistance, NewHoleDismissDistance, NewHoleFixedX, NewHoleFixedY, NewHoleSizeScale, NewHoleAnimLevel, NewHoleVisualStyle)
            try GDHO_ApplyHideDockSettings(NewHoleHideDockEnabled, NewHoleHideDockEdge, NewHoleHideDockMargin)
            try ConfigWebView_WriteHolePresetIni(payload)
            try ConfigWebView_MergeHoleTriggerPayload(payload)
        }
        if (payload.Has("userStudio") && payload["userStudio"] is Map) {
            us := payload["userStudio"]
            try {
                usMsg := Map("payload", us)
                try usMsg["payloadJson"] := Jxon_Dump(us)
                catch {
                }
                ConfigWebView_ApplyUserStudioSave(usMsg)
            } catch as e {
                try OutputDebug("[ConfigWebView] userStudio from saveSettings: " . e.Message)
                catch {
                }
            }
        }
        if (payload.Has("appearanceActivationMode") || payload.Has("AppearanceActivationMode")) {
            try SetTimer((*) => ApplyAppearanceActivationMode(), -20)
            catch {
            }
        }
        return true
    } catch as err {
        errorMsg := "保存失败: " . err.Message
        return false
    }
}

ConfigWebView_CoerceBool(val, default := false) {
    if (val = true || val = false)
        return !!val
    if IsNumber(val)
        return (Integer(val) != 0)
    s := StrLower(Trim(String(val)))
    if (s = "1" || s = "true" || s = "yes" || s = "on")
        return true
    if (s = "0" || s = "false" || s = "no" || s = "off" || s = "")
        return false
    return !!default
}

ConfigWebView_InferHolePlacementPreset(positionMode, hideDockEnabled) {
    pm := Trim(String(positionMode))
    if (pm = "fixed")
        return "fixed"
    if hideDockEnabled
        return "edge"
    return "cursor"
}

ConfigWebView_ReadHoleSensitivityPreset() {
    global ConfigFile
    raw := Trim(String(IniRead(ConfigFile, "Appearance", "HoleSensitivityPreset", "")))
    if (raw = "compact" || raw = "standard" || raw = "relaxed")
        return raw
    if FuncExists("HoleTriggers_InferSensitivityPreset")
        return HoleTriggers_InferSensitivityPreset(
            Integer(IniRead(ConfigFile, "Appearance", "HoleTriggerDistance", "260")),
            Integer(IniRead(ConfigFile, "Appearance", "HoleDismissDistance", "320")))
    return "standard"
}

ConfigWebView_ReadHolePlacementPreset() {
    global ConfigFile
    raw := Trim(String(IniRead(ConfigFile, "Appearance", "HolePlacementPreset", "")))
    if (raw = "cursor" || raw = "fixed" || raw = "edge")
        return raw
    return ConfigWebView_InferHolePlacementPreset(
        IniRead(ConfigFile, "Appearance", "HolePositionMode", "anchor"),
        IniRead(ConfigFile, "Appearance", "HoleHideDockEnabled", "1") = "1")
}

ConfigWebView_ApplyHolePlacementPreset(preset) {
    p := StrLower(Trim(String(preset)))
    switch p {
        case "fixed":
            return Map("holePositionMode", "fixed", "holeHideDockEnabled", false)
        case "edge":
            return Map("holePositionMode", "anchor", "holeHideDockEnabled", true, "holeHideDockEdge", "right")
        default:
            return Map("holePositionMode", "anchor", "holeHideDockEnabled", false)
    }
}

ConfigWebView_WriteHolePresetIni(payload) {
    global ConfigFile
    sens := Trim(String(payload.Get("holeSensitivityPreset", IniRead(ConfigFile, "Appearance", "HoleSensitivityPreset", "standard"))))
    if (sens != "compact" && sens != "standard" && sens != "relaxed")
        sens := "standard"
    place := Trim(String(payload.Get("holePlacementPreset", IniRead(ConfigFile, "Appearance", "HolePlacementPreset", "cursor"))))
    if (place != "cursor" && place != "fixed" && place != "edge")
        place := "cursor"
    IniWrite(sens, ConfigFile, "Appearance", "HoleSensitivityPreset")
    IniWrite(place, ConfigFile, "Appearance", "HolePlacementPreset")
}

ConfigWebView_MergeHoleTriggerPayload(payload) {
    global ConfigFile
    if !(payload is Map)
        return
    trig := Map(
        "textSelect", ConfigWebView_CoerceBool(payload.Get("holeTriggerTextSelect", true), true),
        "circleCw", ConfigWebView_CoerceBool(payload.Get("holeTriggerCircleCw", false), false),
        "circleCcw", ConfigWebView_CoerceBool(payload.Get("holeTriggerCircleCcw", false), false),
        "rbuttonHold", ConfigWebView_CoerceBool(payload.Get("holeTriggerRButtonHold", false), false),
        "rbuttonHoldMs", Integer(payload.Get("holeRButtonHoldMs", 3000))
    )
    hm := Integer(trig["rbuttonHoldMs"])
    if FuncExists("HoleTriggers_NormalizeHoldMs")
        hm := HoleTriggers_NormalizeHoldMs(hm)
    else {
        if (hm <= 1500)
            hm := 1000
        else if (hm <= 4000)
            hm := 3000
        else
            hm := 5000
    }
    trig["rbuttonHoldMs"] := hm
    IniWrite(trig["textSelect"] ? "1" : "0", ConfigFile, "Appearance", "HoleTriggerTextSelect")
    IniWrite(trig["circleCw"] ? "1" : "0", ConfigFile, "Appearance", "HoleTriggerCircleCw")
    IniWrite(trig["circleCcw"] ? "1" : "0", ConfigFile, "Appearance", "HoleTriggerCircleCcw")
    IniWrite(trig["rbuttonHold"] ? "1" : "0", ConfigFile, "Appearance", "HoleTriggerRButtonHold")
    IniWrite(String(hm), ConfigFile, "Appearance", "HoleRButtonHoldMs")
    if FuncExists("HoleTriggers_ApplyConfig") {
        try {
            HoleTriggers_ApplyConfig(trig)
            if FuncExists("HoleTriggers_DiagLog")
                HoleTriggers_DiagLog("[HoleTrigger] web_apply cw=" . (trig["circleCw"] ? "1" : "0")
                    . " ccw=" . (trig["circleCcw"] ? "1" : "0") . " hold=" . (trig["rbuttonHold"] ? "1" : "0"))
        } catch as e {
            if FuncExists("HoleTriggers_DiagLog")
                try HoleTriggers_DiagLog("[HoleTrigger] web_apply_fail msg=" . e.Message)
                catch {
                }
        }
    } else if FuncExists("HoleTriggers_SaveToIni") {
        try HoleTriggers_SaveToIni(trig)
        catch {
        }
    }
}

ConfigWebView_PreviewHoleOnScreen(payload, &errorMsg := "") {
    if !(payload is Map) {
        errorMsg := "payload 无效"
        return false
    }
    try {
        if payload.Has("holePlacementPreset") {
            placeMap := ConfigWebView_ApplyHolePlacementPreset(payload["holePlacementPreset"])
            for k, v in placeMap
                payload[k] := v
        }
        if payload.Has("holeSensitivityPreset") && FuncExists("HoleTriggers_MapSensitivityPreset") {
            dist := HoleTriggers_MapSensitivityPreset(payload["holeSensitivityPreset"])
            payload["holeTriggerDistance"] := dist["trigger"]
            payload["holeDismissDistance"] := dist["dismiss"]
        }
        posMode := Trim(String(payload.Get("holePositionMode", "anchor")))
        trigDist := Integer(payload.Get("holeTriggerDistance", 260))
        dismissDist := Integer(payload.Get("holeDismissDistance", 320))
        fixX := Integer(payload.Get("holeFixedX", 360))
        fixY := Integer(payload.Get("holeFixedY", 260))
        sizeScale := CfgParseFloat(payload.Get("holeSizeScale", 1.0), 1.0)
        animLevel := CfgParseFloat(payload.Get("holeAnimLevel", 1.0), 1.0)
        visualStyle := StrLower(Trim(String(payload.Get("holeVisualStyle", "ring"))))
        hideDock := !!payload.Get("holeHideDockEnabled", false)
        dockEdge := StrLower(Trim(String(payload.Get("holeHideDockEdge", "right"))))
        dockMargin := Integer(payload.Get("holeHideDockMargin", 10))
        try GDHO_SetScreenAnchor(fixX, fixY)
        try GDHO_ApplySettings(posMode, trigDist, dismissDist, fixX, fixY, sizeScale, animLevel, visualStyle)
        try GDHO_ApplyHideDockSettings(hideDock, dockEdge, dockMargin)
        mon := 1
        if FuncExists("ReadPersistedPopupScreenIndex") {
            try mon := ReadPersistedPopupScreenIndex()
            catch {
                mon := 1
            }
        }
        try MonitorGetWorkArea(mon, &wl, &wt, &wr, &wb)
        catch {
            wl := 0, wt := 0, wr := A_ScreenWidth, wb := A_ScreenHeight
        }
        cx := (wl + wr) // 2
        cy := (wt + wb) // 2
        try SetTimer(ConfigWebView_CloseHolePreview, 0)
        if FuncExists("GDHO_RequestOpen") {
            try GDHO_RequestOpen(Map("reason", "settings_preview", "positionMode", "fixed", "screenX", cx, "screenY", cy, "payload", "text"))
        }
        SetTimer(ConfigWebView_CloseHolePreview, -3500)
        return true
    } catch as err {
        errorMsg := "预览失败: " . err.Message
        return false
    }
}

ConfigWebView_CloseHolePreview(*) {
    try SetTimer(ConfigWebView_CloseHolePreview, 0)
    if FuncExists("GDHO_RequestClose")
        try GDHO_RequestClose("settings_preview")
    catch {
    }
}

ConfigWebView_SaveHoleOnly(payload, &errorMsg := "") {
    global ConfigFile
    try {
        if !(payload is Map) {
            errorMsg := "payload 鏃犳晥"
            return false
        }
        if payload.Has("holePlacementPreset") {
            placeMap := ConfigWebView_ApplyHolePlacementPreset(payload["holePlacementPreset"])
            for k, v in placeMap
                payload[k] := v
        }
        if payload.Has("holeSensitivityPreset") && FuncExists("HoleTriggers_MapSensitivityPreset") {
            dist := HoleTriggers_MapSensitivityPreset(payload["holeSensitivityPreset"])
            payload["holeTriggerDistance"] := dist["trigger"]
            payload["holeDismissDistance"] := dist["dismiss"]
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
        NewHoleSizeScale := CfgParseFloat(payload.Get("holeSizeScale", IniRead(ConfigFile, "Appearance", "HoleSizeScale", "1.0")), 1.0)
        if (NewHoleSizeScale < 0.6)
            NewHoleSizeScale := 0.6
        if (NewHoleSizeScale > 1.8)
            NewHoleSizeScale := 1.8
        NewHoleAnimLevel := CfgParseFloat(payload.Get("holeAnimLevel", IniRead(ConfigFile, "Appearance", "HoleAnimLevel", "1.0")), 1.0)
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
        try ConfigWebView_WriteHolePresetIni(payload)
        try GDHO_SetScreenAnchor(NewHoleFixedX, NewHoleFixedY)
        try GDHO_ApplySettings(NewHolePositionMode, NewHoleTriggerDistance, NewHoleDismissDistance, NewHoleFixedX, NewHoleFixedY, NewHoleSizeScale, NewHoleAnimLevel, NewHoleVisualStyle)
        try GDHO_ApplyHideDockSettings(NewHoleHideDockEnabled, NewHoleHideDockEdge, NewHoleHideDockMargin)
        try ConfigWebView_MergeHoleTriggerPayload(payload)
        return true
    } catch as err {
        errorMsg := "保存失败: " . err.Message
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
            try SetTimer((*) => SurfaceIntent_Close("floating_toolbar"), -50)
            catch {
            }
        }
        return true
    } catch as err {
        errorMsg := err.Message
        return false
    }
}

ConfigWebView_PayloadHasHoleSettings(payload) {
    if !(payload is Map)
        return false
    for k in ["holePlacementPreset", "holeSensitivityPreset", "holeTriggerTextSelect", "holeTriggerCircleCw",
        "holeTriggerCircleCcw", "holeTriggerRButtonHold", "holePositionMode", "holeVisualStyle", "holeSizeScale",
        "holeAnimLevel", "holeHideDockEnabled"]
        if payload.Has(k)
            return true
    return false
}

ConfigWebView_SaveGeneralSettings(payload, &errorMsg := "") {
    global CursorPath, CapsLockHoldTimeSeconds, CapsLockHoldVkEnabled, AutoStart, ConfigFile
    if !(payload is Map) {
        errorMsg := "payload 无效"
        return false
    }
    try {
        if (payload.Has("cursorPath")) {
            newPath := NormalizeWindowsPath(payload.Get("cursorPath", ""))
            if (newPath = "") {
                errorMsg := "Cursor Path 不能为空"
                return false
            }
            CursorPath := newPath
            IniWrite(CursorPath, ConfigFile, "Settings", "CursorPath")
        }
        if (payload.Has("capslockHoldTimeSeconds")) {
            newHold := CfgParseFloat(payload.Get("capslockHoldTimeSeconds", 0.5), CapsLockHoldTimeSeconds)
            if (newHold < 0.1 || newHold > 5.0) {
                errorMsg := "CapsLock Hold Time 超出范围"
                return false
            }
            CapsLockHoldTimeSeconds := newHold
            IniWrite(String(CapsLockHoldTimeSeconds), ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
        }
        if (payload.Has("capsLockHoldVkEnabled")) {
            CapsLockHoldVkEnabled := payload["capsLockHoldVkEnabled"] ? true : false
            IniWrite(CapsLockHoldVkEnabled ? "1" : "0", ConfigFile, "Settings", "CapsLockHoldVkEnabled")
        }
        if (payload.Has("autoStart")) {
            AutoStart := ConfigWebView_CoerceBool(payload.Get("autoStart", false), AutoStart)
            if !ConfigWebView_PersistAutoStartSetting(AutoStart, &errorMsg)
                return false
        }
        return true
    } catch as err {
        errorMsg := err.Message
        return false
    }
}

ConfigWebView_PersistAutoStartSetting(enable, &errorMsg := "") {
    global AutoStart, ConfigFile
    AutoStart := enable ? true : false
    IniWrite(AutoStart ? "1" : "0", ConfigFile, "Settings", "AutoStart")
    regErr := ""
    if !ConfigWebView_ApplyAutoStartRegistry(AutoStart, &regErr) {
        errorMsg := regErr != "" ? regErr : "注册表自启动写入失败"
        return false
    }
    return true
}

ConfigWebView_ApplyAutoStartRegistry(enable, &errorMsg := "") {
    try {
        return Nmer_ApplyAutoStartRegistry(enable, &errorMsg)
    } catch as e {
        errorMsg := e.Message
        return false
    }
}

ConfigWebView_RelocateSettingsGuiIfOpen() {
    global GuiID_ConfigGUI, ConfigPanelScreenIndex
    try {
        if !IsObject(GuiID_ConfigGUI) || !GuiID_ConfigGUI.Hwnd
            return
        if !FuncExists("GetScreenInfo")
            return
        ScreenInfo := GetScreenInfo(ConfigPanelScreenIndex)
        WinW := Max(980, Round(ScreenInfo.Width * 0.80))
        WinH := Max(680, Round(ScreenInfo.Height * 0.80))
        PosX := ScreenInfo.Left + Round((ScreenInfo.Width - WinW) / 2)
        PosY := ScreenInfo.Top + Round((ScreenInfo.Height - WinH) / 2)
        GuiID_ConfigGUI.Move(PosX, PosY, WinW, WinH)
        try ConfigWebView_ApplyBounds()
        catch {
        }
    } catch {
    }
}

; 设置中心内置：不依赖 FuncExists / ConfigManager 加载时机
ConfigWebView_ReadPersistedPopupScreenIndex() {
    global ConfigFile, PanelScreenIndex
    raw := Trim(String(IniRead(ConfigFile, "Appearance", "PopupScreenIndex", "")))
    if (raw = "" || raw = "ERROR")
        raw := Trim(String(IniRead(ConfigFile, "Appearance", "ScreenIndex", "1")))
    idx := Integer(raw)
    if (idx < 1)
        idx := 1
    monitorCount := 1
    try monitorCount := MonitorGetCount()
    catch
        monitorCount := 1
    if (idx > monitorCount)
        idx := monitorCount
    return idx
}

ConfigWebView_ApplyPopupScreenIndex(screenIndex) {
    global PanelScreenIndex, ConfigPanelScreenIndex, MsgBoxScreenIndex, VoiceInputScreenIndex
    global CursorPanelScreenIndex, ClipboardPanelScreenIndex, ConfigFile
    idx := Integer(screenIndex)
    if (idx < 1)
        idx := 1
    monitorCount := 1
    try monitorCount := MonitorGetCount()
    catch
        monitorCount := 1
    if (idx > monitorCount)
        idx := monitorCount
    PanelScreenIndex := idx
    ConfigPanelScreenIndex := idx
    MsgBoxScreenIndex := idx
    VoiceInputScreenIndex := idx
    CursorPanelScreenIndex := idx
    ClipboardPanelScreenIndex := idx
    IniWrite(idx, ConfigFile, "Appearance", "ScreenIndex")
    IniWrite(idx, ConfigFile, "Appearance", "PopupScreenIndex")
    IniWrite(idx, ConfigFile, "Advanced", "ConfigPanelScreenIndex")
    IniWrite(idx, ConfigFile, "Advanced", "MsgBoxScreenIndex")
    IniWrite(idx, ConfigFile, "Advanced", "VoiceInputScreenIndex")
    IniWrite(idx, ConfigFile, "Advanced", "CursorPanelScreenIndex")
    IniWrite(idx, ConfigFile, "Advanced", "ClipboardPanelScreenIndex")
    return idx
}

ConfigWebView_RelocateSearchCenterIfOpen(*) {
    global g_SCWV_Gui, g_SCWV_Visible
    try {
        if !IsObject(g_SCWV_Gui) || !g_SCWV_Gui.Hwnd
            return
        if !(IsSet(g_SCWV_Visible) && g_SCWV_Visible)
            return
        Nmer_MoveGuiToPopupScreen(g_SCWV_Gui)
        try WinMaximize("ahk_id " . g_SCWV_Gui.Hwnd)
        catch {
        }
        try SCWV_ApplyBounds()
        catch {
        }
    } catch {
    }
}

ConfigWebView_RelocateHubCapsuleIfOpen(*) {
    global g_SelSense_MenuGui, g_SelSense_MenuVisible, g_SelSense_MenuShowingHub, g_SelSense_MenuW, g_SelSense_MenuH
    try {
        if !(IsSet(g_SelSense_MenuGui) && g_SelSense_MenuGui && IsSet(g_SelSense_MenuVisible) && g_SelSense_MenuVisible)
            return
        if !(IsSet(g_SelSense_MenuShowingHub) && g_SelSense_MenuShowingHub)
            return
        w := g_SelSense_MenuW
        h := g_SelSense_MenuH
        if (w < 200)
            w := 420
        if (h < 160)
            h := 560
        Nmer_DefaultPopupWindowXY(w, h, &x, &y)
        try g_SelSense_MenuGui.Move(x, y, w, h)
        catch {
        }
        try SelectionSense_ApplyMenuBounds()
        catch {
        }
    } catch {
    }
}

ConfigWebView_PersistPopupScreenIndex(screenIndex, &errorMsg := "") {
    try {
        ConfigWebView_ApplyPopupScreenIndex(screenIndex)
        SetTimer(ConfigWebView_RelocateSettingsGuiIfOpen, -30)
        SetTimer(ConfigWebView_RelocateSearchCenterIfOpen, -30)
        SetTimer(ConfigWebView_RelocateHubCapsuleIfOpen, -30)
        return true
    } catch as e {
        errorMsg := e.Message != "" ? e.Message : "弹窗位置保存失败"
        return false
    }
}

ConfigWebView_SaveDefaultStartTab(tab, &errorMsg := "") {
    global DefaultStartTab, ConfigFile
    try {
        newTab := FuncExists("NormalizeDefaultStartTab")
            ? NormalizeDefaultStartTab(tab) : Trim(String(tab))
        if (newTab = "")
            newTab := "general"
        DefaultStartTab := newTab
        IniWrite(DefaultStartTab, ConfigFile, "Settings", "DefaultStartTab")
        return true
    } catch as err {
        errorMsg := err.Message
        return false
    }
}

ConfigWebView_SaveThemeMode(mode, &errorMsg := "") {
    global ThemeMode, ConfigFile
    try {
        newMode := NormalizeIniThemeMode(mode, NormalizeIniThemeMode(IsSet(ThemeMode) ? ThemeMode : "dark", "dark"))
        ThemeMode := newMode
        IniWrite(newMode, ConfigFile, "Settings", "ThemeMode")
        IniWrite(newMode, ConfigFile, "Appearance", "ThemeMode")
        ApplyTheme(newMode)
        try SetTimer(ConfigWebView_RefocusAfterThemeChange, -60)
        catch {
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

ConfigWebView_UserStudioPath() {
    return Nmer_UserStudioPath()
}

ConfigWebView_ParseUserStudioSavePayload(msg) {
    payload := msg.Has("payload") ? msg["payload"] : Map()
    jsonPl := Trim(String(msg.Get("payloadJson", "")))
    if (jsonPl != "") {
        try {
            parsed := Jxon_Load(jsonPl)
            if (parsed is Map)
                payload := parsed
        } catch {
        }
    } else if (payload is String && payload != "") {
        try payload := Jxon_Load(payload)
        catch {
            payload := Map()
        }
    }
    if !(payload is Map)
        payload := Map()
    return payload
}

ConfigWebView_BuildUserStudioPayloadFromFlat(msg) {
    if !(msg is Map)
        return Map()
    cards := []
    cardsRaw := Trim(String(msg.Get("cards", "")))
    if (cardsRaw = "__empty__") {
        cards := []
    } else if (cardsRaw != "") {
        for _, part in StrSplit(cardsRaw, ",") {
            p := Trim(part)
            if (p != "")
                cards.Push(p)
        }
    }
    opt := Map("llmCardProviders", cards)
    keysJson := Trim(String(msg.Get("keysJson", "")))
    if (keysJson != "") {
        try {
            keysParsed := Jxon_Load(keysJson)
            if (keysParsed is Map)
                opt["llmApiKeys"] := keysParsed
        } catch {
        }
    }
    modelsJson := Trim(String(msg.Get("modelsJson", "")))
    if (modelsJson != "") {
        try {
            modelsParsed := Jxon_Load(modelsJson)
            if (modelsParsed is Map)
                opt["llmModels"] := modelsParsed
        } catch {
        }
    }
    return Map(
        "llm", Map(
            "provider", msg.Get("llmProvider", "openai"),
            "apiKey", msg.Get("llmApiKey", ""),
            "baseUrl", msg.Get("llmBaseUrl", ""),
            "model", msg.Get("llmModel", "")
        ),
        "options", opt
    )
}

ConfigWebView_FallbackWriteUserStudioJson(payload) {
    if !(payload is Map)
        payload := Map()
    dir := A_ScriptDir . "\config"
    if !DirExist(dir)
        DirCreate(dir)
    path := ConfigWebView_UserStudioPath()
    doc := Map(
        "version", 1,
        "llm", Map("provider", "openai", "apiKey", "", "baseUrl", "https://api.openai.com/v1", "model", "gpt-4o-mini"),
        "paths", Map("cursor", "", "autohotkey", "", "everything", "", "python", "", "notes", ""),
        "options", Map(),
        "updatedAt", ""
    )
    if FileExist(path) {
        try {
            parsed := Jxon_Load(FileRead(path, "UTF-8"))
            if (parsed is Map)
                doc := parsed
        } catch {
        }
    }
    if !(doc.Has("llm") && doc["llm"] is Map)
        doc["llm"] := Map("provider", "openai", "apiKey", "", "baseUrl", "", "model", "")
    if !(doc.Has("paths") && doc["paths"] is Map)
        doc["paths"] := Map("cursor", "", "autohotkey", "", "everything", "", "python", "", "notes", "")
    if !(doc.Has("options") && doc["options"] is Map)
        doc["options"] := Map()
    if payload.Has("llm") && payload["llm"] is Map {
        for k, v in payload["llm"]
            doc["llm"][k] := v
    }
    if payload.Has("paths") && payload["paths"] is Map {
        for k, v in payload["paths"]
            doc["paths"][k] := Trim(String(v))
    }
    if payload.Has("options") && payload["options"] is Map {
        optIn := payload["options"]
        opt := doc["options"] is Map ? doc["options"].Clone() : Map()
        for slot in ["llmApiKeys", "llmModels", "llmBaseUrls", "llmManualBaseUrl"] {
            if optIn.Has(slot) && optIn[slot] is Map
                opt[slot] := optIn[slot].Clone()
        }
        if optIn.Has("llmCardProviders") && optIn["llmCardProviders"] is Array
            opt["llmCardProviders"] := optIn["llmCardProviders"].Clone()
        for k, v in optIn {
            if (k = "llmApiKeys" || k = "llmModels" || k = "llmBaseUrls" || k = "llmManualBaseUrl" || k = "llmCardProviders")
                continue
            opt[k] := v
        }
        doc["options"] := opt
    }
    doc["updatedAt"] := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    try {
        if FileExist(path)
            FileCopy(path, Nmer_UserStudioBackupPath(), 1)
    } catch {
    }
    f := FileOpen(path, "w", "UTF-8")
    if !f
        throw Error("无法写入 " . path)
    f.Write(Jxon_Dump(doc))
    f.Close()
    global g_UserStudioLoaded
    if IsSet(g_UserStudioLoaded)
        g_UserStudioLoaded := false
}

ConfigWebView_ApplyUserStudioSave(msg) {
    payload := ConfigWebView_ParseUserStudioSavePayload(msg)
    if (payload.Count = 0)
        payload := ConfigWebView_BuildUserStudioPayloadFromFlat(msg)
    errPrimary := ""
    try {
        UserStudio_CoerceWebPayload(&payload)
        UserStudio_ApplyFromWebPayload(payload)
        return
    } catch as e {
        errPrimary := e.Message
        try OutputDebug("[ConfigWebView] UserStudio save primary failed: " . errPrimary)
        catch {
        }
    }
    try {
        ConfigWebView_FallbackWriteUserStudioJson(payload)
    } catch as e2 {
        if (errPrimary != "")
            throw Error(errPrimary)
        throw e2
    }
}

ConfigWebView_UserStudioPayloadForWebAfterSave() {
    if FuncExists("UserStudio_PayloadForWeb") {
        try return UserStudio_PayloadForWeb()
        catch {
        }
    }
    path := ConfigWebView_UserStudioPath()
    if FileExist(path) {
        try {
            parsed := Jxon_Load(FileRead(path, "UTF-8"))
            if (parsed is Map)
                return parsed
        } catch {
        }
    }
    return Map()
}

ConfigWebView_FindOpenClawCliExe() {
    if FuncExists("UserStudio_FindOpenClawCliExe") {
        try {
            p := UserStudio_FindOpenClawCliExe()
            if (p != "")
                return p
        } catch {
        }
    }
    for _, p in [A_AppData . "\npm\openclaw.cmd", "C:\Program Files\nodejs\openclaw.cmd"] {
        if (p != "" && FileExist(p))
            return p
    }
    return ""
}

ConfigWebView_OpenClawGatewayCliOk(timeoutMs := 8000) {
    if FuncExists("LlmApiPing_OpenClawGatewayStatusOk")
        return LlmApiPing_OpenClawGatewayStatusOk(timeoutMs)
    exe := ConfigWebView_FindOpenClawCliExe()
    if (exe = "")
        return false
    out := A_Temp . "\nmer_openclaw_gw_status.txt"
    try FileDelete(out)
    inner := '"' . exe . '" gateway status > "' . out . '" 2>&1'
    pid := 0
    try {
        Run(A_ComSpec . ' /c "' . inner . '"', , "Hide", &pid)
    } catch {
        return false
    }
    if !pid
        return false
    deadline := A_TickCount + Max(1500, Integer(timeoutMs))
    while ProcessExist(pid) {
        if (A_TickCount > deadline) {
            try ProcessClose(pid)
            catch {
            }
            try FileDelete(out)
            return false
        }
        Sleep(50)
    }
    if !FileExist(out)
        return false
    raw := ""
    try raw := FileRead(out, "UTF-8")
    catch {
        return false
    }
    try FileDelete(out)
    if InStr(raw, "Connectivity probe: ok")
        return true
    if InStr(raw, "Runtime: running") && InStr(raw, "Listening: 127.0.0.1")
        return true
    return false
}

ConfigWebView_TcpPortOpen(host, port, timeoutMs := 2500) {
    if FuncExists("LlmApiPing_TcpPortOpen")
        return LlmApiPing_TcpPortOpen(host, port, timeoutMs)
    host := Trim(String(host))
    if (host = "localhost")
        host := "127.0.0.1"
    port := Integer(port)
    if (host = "" || port < 1 || port > 65535)
        return false
    if !RegExMatch(host, "^\d{1,3}(\.\d{1,3}){3}$")
        return false
    static wsaReady := false
    if !wsaReady {
        wsaData := Buffer(400, 0)
        if DllCall("ws2_32\WSAStartup", "UShort", 0x0202, "Ptr", wsaData, "Int")
            return false
        wsaReady := true
    }
    ip := DllCall("ws2_32\inet_addr", "AStr", host, "UInt")
    if (ip = 0xFFFFFFFF)
        return false
    sock := DllCall("ws2_32\socket", "Int", 2, "Int", 1, "Int", 6, "UPtr")
    if (sock = -1 || sock = 0xFFFFFFFFFFFFFFFF)
        return false
    try {
        sa := Buffer(16, 0)
        NumPut("UShort", 2, sa, 0)
        NumPut("UShort", DllCall("ws2_32\htons", "UShort", port, "UShort"), sa, 2)
        NumPut("UInt", ip, sa, 4)
        nb := 1
        if (DllCall("ws2_32\ioctlsocket", "UPtr", sock, "UInt", 0x8004667E, "UInt*", &nb, "Int") = -1)
            return false
        if (DllCall("ws2_32\connect", "UPtr", sock, "Ptr", sa, "Int", 16, "Int") = 0)
            return true
        if (DllCall("ws2_32\WSAGetLastError", "Int") != 10035)
            return false
        t := Max(500, Integer(timeoutMs))
        writeSet := Buffer(132, 0)
        NumPut("UInt", 1, writeSet, 0)
        NumPut("UPtr", sock, writeSet, 4)
        tv := Buffer(8, 0)
        NumPut("UInt", t // 1000, tv, 0)
        NumPut("UInt", Mod(t, 1000) * 1000, tv, 4)
        if (DllCall("ws2_32\select", "Int", 0, "Ptr", 0, "Ptr", writeSet, "Ptr", 0, "Ptr", tv, "Int") <= 0)
            return false
        optErr := 0
        optLen := 4
        if (DllCall("ws2_32\getsockopt", "UPtr", sock, "Int", 0xFFFF, "Int", 0x1007, "Int*", &optErr, "Int*", &optLen, "Int") = -1)
            return false
        return optErr = 0
    } catch {
        return false
    } finally {
        try DllCall("ws2_32\closesocket", "UPtr", sock)
        catch {
        }
    }
}

ConfigWebView_ProbeHermesApiServer(base, token, timeoutMs := 12000) {
    if FuncExists("UserStudio_ProbeHermesApiServer") {
        try return UserStudio_ProbeHermesApiServer(base, token, timeoutMs)
    }
    if FuncExists("LlmApiPing_TestHermes") {
        try return LlmApiPing_TestHermes(base, token, timeoutMs)
    }
    return Map("ok", false, "error", "Hermes 探测模块未加载", "elapsedMs", 0)
}

ConfigWebView_RefreshHermesStudioStatus_Deferred(msg) {
    try ConfigWebView_RunHermesStudioProbe(msg, "refreshHermesStudioStatus")
    catch as eDef {
        ConfigWebView_Send(Map(
            "type", "hermes_studio_status",
            "token", "",
            "source", "",
            "host", "127.0.0.1",
            "port", 8642,
            "apiEnabled", false,
            "gatewayOk", false,
            "gatewayError", eDef.Message,
            "debug", "deferred_err",
            "force", !!(msg is Map && msg.Has("force") && msg["force"])
        ))
    }
}

ConfigWebView_RunHermesStudioProbe(msg, action) {
    token := ""
    source := ""
    host := "127.0.0.1"
    port := 8642
    apiEnabled := false
    gwOk := false
    gwErr := ""
    info := Map()
    dbg := ""
    niumaKey := ""
    envWrote := false
    envHint := ""
    hermesEnsure := (action = "ensureHermesApiServerEnv")
        || !!(msg is Map && msg.Has("ensureEnv") && msg["ensureEnv"])
        || (action = "refreshHermesStudioStatus")
    if (hermesEnsure && FuncExists("UserStudio_EnsureHermesApiServerEnv")) {
        try {
            ens := UserStudio_EnsureHermesApiServerEnv()
            if (ens is Map) {
                envWrote := !!ens.Get("wrote", false)
                if ens.Has("hint")
                    envHint := Trim(String(ens["hint"]))
                if (envWrote)
                    dbg := "wrote=" . String(ens.Get("path", ""))
                if (!ens.Get("ok", false) && ens.Has("error"))
                    dbg .= (dbg != "" ? " | " : "") . String(ens["error"])
            }
        } catch as eEns {
            dbg := "ensure_err=" . eEns.Message
        }
    }
    try {
        if FuncExists("FloatingToolbar_ReadHermesEnvKeyDirect") {
            token := FloatingToolbar_ReadHermesEnvKeyDirect(&source, &host, &port)
            if (token != "")
                dbg := (dbg != "" ? dbg . " | " : "") . "direct=" . source
        }
    } catch as eDirect {
        dbg := "direct_err=" . eDirect.Message
    }
    try {
        fb := ConfigWebView_QuickReadHermesApiServerKey()
        if (fb is Map) {
            token := Trim(String(fb.Get("token", "")))
            if (token != "") {
                source := String(fb.Get("source", ""))
                host := Trim(String(fb.Get("host", host)))
                port := Integer(fb.Get("port", port))
                dbg := (dbg != "" ? dbg . " | " : "") . "quick=" . source
            }
        }
    } catch as eQuick {
        dbg := "quick_err=" . eQuick.Message
    }
    if (token = "") {
        try {
            if FuncExists("UserStudio_ProbeHermesGatewayToken") {
                info := UserStudio_ProbeHermesGatewayToken(hermesEnsure)
                if (info is Map) {
                    token := Trim(String(info.Get("token", "")))
                    source := String(info.Get("source", ""))
                    host := Trim(String(info.Get("host", host)))
                    port := Integer(info.Get("port", port))
                    apiEnabled := !!info.Get("apiEnabled", false)
                }
            }
        } catch as eH1 {
            dbg := (dbg != "" ? dbg . " | " : "") . "probe_err=" . eH1.Message
            try OutputDebug("[ConfigWebView] hermes probe failed: " . eH1.Message)
            catch {
            }
        }
    }
    if (token = "") {
        try {
            fb2 := ConfigWebView_QuickReadHermesApiServerKey()
            if (fb2 is Map) {
                token := Trim(String(fb2.Get("token", "")))
                if (token != "") {
                    source := String(fb2.Get("source", ""))
                    host := Trim(String(fb2.Get("host", host)))
                    port := Integer(fb2.Get("port", port))
                    dbg := (dbg != "" ? dbg . " | " : "") . "quick2=" . source
                }
            }
        } catch {
        }
    }
    try {
        if FuncExists("UserStudio_ReadNiumaHermesKey")
            niumaKey := UserStudio_ReadNiumaHermesKey()
    } catch {
    }
    if (token = "" && niumaKey != "") {
        token := niumaKey
        source := "niuma_chat_llm.json"
        dbg := (dbg != "" ? dbg . " | " : "") . "niuma_sync"
    }
    if (token != "") {
        base := "http://" . host . ":" . port . "/v1"
        pingMs := (action = "refreshHermesStudioStatus") ? 12000 : 6000
        try {
            r := ConfigWebView_ProbeHermesApiServer(base, token, pingMs)
            gwOk := !!r.Get("ok", false)
            gwErr := String(r.Get("error", ""))
        } catch as eH2 {
            gwErr := eH2.Message
        }
    } else if (info is Map && info.Has("tried") && info["tried"] is Array) {
        for _, p in info["tried"]
            dbg .= (dbg != "" ? " | " : "") . p
    }
    if (token = "" && gwErr = "")
        gwErr := "未从本机 .env 读到 API_SERVER_KEY"
    tried := []
    localAppData := ""
    primaryDir := ""
    if FuncExists("UserStudio_CollectHermesProbeMeta") {
        try {
            meta := UserStudio_CollectHermesProbeMeta()
            if (meta is Map) {
                if (meta.Has("tried") && meta["tried"] is Array)
                    tried := meta["tried"]
                localAppData := String(meta.Get("localAppData", ""))
                primaryDir := String(meta.Get("primaryDir", ""))
            }
        } catch {
        }
    }
    if (token = "" && dbg = "") {
        if (primaryDir != "")
            dbg := "primary=" . primaryDir
        else if FuncExists("UserStudio_ListHermesDataDirs") {
            dirs := UserStudio_ListHermesDataDirs()
            dbg := "dirs=" . (dirs.Length > 0 ? dirs[1] : "")
        } else if FuncExists("UserStudio_ResolveHermesHome")
            dbg := "home=" . UserStudio_ResolveHermesHome()
    }
    hasEnvKey := (token != "" && source != "" && source != "niuma_chat_llm.json")
    hasNiumaKey := (niumaKey != "")
    installKind := "none"
    installLabel := ""
    apiServerState := ""
    gatewayRunning := false
    canRestartGateway := false
    if FuncExists("UserStudio_DiscoverHermesInstall") {
        try {
            disc := UserStudio_DiscoverHermesInstall()
            if (disc is Map) {
                installKind := String(disc.Get("installKind", "none"))
                installLabel := String(disc.Get("installLabel", ""))
                apiServerState := String(disc.Get("apiServerState", ""))
                gatewayRunning := !!disc.Get("gatewayRunning", false)
                canRestartGateway := !!disc.Get("canRestartGateway", false)
                if (primaryDir = "")
                    primaryDir := String(disc.Get("dataDir", ""))
            }
        } catch {
        }
    }
    if (!gwOk && token != "" && apiServerState = "connected")
        gwErr := "API Server 已在 8642 运行，但当前 Key 与 %LOCALAPPDATA%\hermes\.env 不一致；请点「一键连接 Hermes」对齐。"
    try OutputDebug("[ConfigWebView] hermes_probe token=" . (token != "" ? "yes" : "no")
        . " gwOk=" . (gwOk ? "yes" : "no") . " err=" . gwErr)
    catch {
    }
    if (action = "ensureHermesApiServerEnv") {
        ConfigWebView_Send(Map(
            "type", "hermes_ensure_env_result",
            "ok", token != "",
            "token", token,
            "source", source,
            "path", source,
            "wrote", envWrote,
            "envWrote", envWrote,
            "envHint", envHint,
            "debug", dbg,
            "gatewayOk", gwOk,
            "gatewayError", gwErr,
            "tried", tried,
            "localAppData", localAppData,
            "hasEnvKey", hasEnvKey,
            "hasNiumaKey", hasNiumaKey,
            "installKind", installKind,
            "installLabel", installLabel,
            "apiServerState", apiServerState,
            "canRestartGateway", canRestartGateway
        ))
    } else if (action = "refreshHermesStudioStatus") {
        ConfigWebView_Send(Map(
            "type", "hermes_studio_status",
            "token", token,
            "source", source,
            "host", host,
            "port", port,
            "apiEnabled", apiEnabled,
            "gatewayOk", gwOk,
            "gatewayError", gwErr,
            "debug", dbg,
            "tried", tried,
            "localAppData", localAppData,
            "hasEnvKey", hasEnvKey,
            "hasNiumaKey", hasNiumaKey,
            "installKind", installKind,
            "installLabel", installLabel,
            "apiServerState", apiServerState,
            "canRestartGateway", canRestartGateway,
            "force", !!(msg is Map && msg.Has("force") && msg["force"]),
            "envWrote", envWrote,
            "envHint", envHint
        ))
    } else {
        ConfigWebView_Send(Map(
            "type", "hermes_host_token_probe",
            "token", token,
            "source", source,
            "host", host,
            "port", port,
            "apiEnabled", apiEnabled,
            "niumaToken", niumaKey,
            "gatewayOk", gwOk,
            "gatewayError", gwErr,
            "debug", dbg,
            "tried", tried,
            "localAppData", localAppData,
            "primaryDir", primaryDir,
            "hasEnvKey", hasEnvKey,
            "hasNiumaKey", hasNiumaKey,
            "installKind", installKind,
            "installLabel", installLabel,
            "apiServerState", apiServerState,
            "gatewayRunning", gatewayRunning,
            "canRestartGateway", canRestartGateway,
            "force", !!(msg is Map && msg.Has("force") && msg["force"]),
            "envWrote", envWrote,
            "envHint", envHint
        ))
    }
}

ConfigWebView_RefreshOpenClawStudioStatus_Deferred(msg) {
    try ConfigWebView_RunOpenClawProbe(msg, "refreshOpenClawStudioStatus")
    catch as eDef {
        reqIdOut := (msg is Map && msg.Has("reqId")) ? String(msg["reqId"]) : ""
        ConfigWebView_Send(Map(
            "type", "openclaw_studio_status",
            "token", "",
            "source", "",
            "host", "127.0.0.1",
            "port", 18789,
            "niumaToken", "",
            "gatewayOk", false,
            "gatewayError", eDef.Message,
            "debug", "deferred_err",
            "force", !!(msg is Map && msg.Has("force") && msg["force"]),
            "reqId", reqIdOut
        ))
    }
}

ConfigWebView_RunOpenClawProbe(msg, action) {
    token := ""
    source := ""
    host := "127.0.0.1"
    port := 18789
    niumaKey := ""
    gwOk := false
    gwErr := ""
    info := Map()
    quickDbg := ""
    try {
        envTok := Trim(String(EnvGet("OPENCLAW_GATEWAY_TOKEN")))
        if (envTok != "") {
            token := envTok
            source := "env:OPENCLAW_GATEWAY_TOKEN"
        }
    } catch {
    }
    if (token = "") {
        try {
            fb := ConfigWebView_QuickReadOpenClawGatewayToken()
            if (fb is Map) {
                token := Trim(String(fb.Get("token", "")))
                if (token != "") {
                    source := String(fb.Get("source", ""))
                    host := Trim(String(fb.Get("host", host)))
                    port := Integer(fb.Get("port", port))
                } else {
                    quickDbg := "quick=empty"
                }
            } else {
                quickDbg := "quick=not_map"
            }
        } catch as eQuick {
            quickDbg := "quick_err=" . eQuick.Message
        }
    }
    if (token = "") {
        try {
            fastProbe := (action = "refreshOpenClawStudioStatus")
            if FuncExists("UserStudio_ProbeOpenClawGatewayToken") {
                info := UserStudio_ProbeOpenClawGatewayToken(fastProbe)
                if (info is Map) {
                    token := Trim(String(info.Get("token", "")))
                    source := String(info.Get("source", ""))
                    host := Trim(String(info.Get("host", host)))
                    port := Integer(info.Get("port", port))
                }
            }
        } catch as e1 {
            try OutputDebug("[ConfigWebView] openclaw probe failed: " . e1.Message)
            catch {
            }
        }
    }
    try {
        if FuncExists("UserStudio_LogOpenClawProbe")
            UserStudio_LogOpenClawProbe(
                "probe_result tokenLen=" . StrLen(token),
                "source=" . source,
                "quickDbg=" . quickDbg,
                "USERPROFILE=" . EnvGet("USERPROFILE"),
                "func=" . (FuncExists("UserStudio_ProbeOpenClawGatewayToken") ? "yes" : "no"),
                "literal=" . (FuncExists("UserStudio_ReadOpenClawAuthTokenLiteral") ? "yes" : "no")
            )
    } catch {
    }
    try {
        if FuncExists("UserStudio_ReadNiumaOpenClawKey")
            niumaKey := UserStudio_ReadNiumaOpenClawKey()
    } catch {
    }
    if (token = "" && niumaKey != "") {
        token := niumaKey
        source := "niuma_chat_llm.json"
    }
    statusRefresh := (action = "refreshOpenClawStudioStatus")
    if (statusRefresh && !gwOk) {
        try {
            if ConfigWebView_TcpPortOpen(host, port, 7000)
                gwOk := true
        } catch {
        }
    }
    if (token != "" && !gwOk) {
        base := "http://" . host . ":" . port
        pingMs := statusRefresh ? 9000 : 8000
        try {
            r := ConfigWebView_ProbeOpenClawGateway(base, token, pingMs)
            gwOk := !!r.Get("ok", false)
            gwErr := String(r.Get("error", ""))
        } catch as e2 {
            gwErr := e2.Message
        }
        try {
            if FuncExists("UserStudio_LogOpenClawProbe")
                UserStudio_LogOpenClawProbe(
                    "gateway_test ok=" . (gwOk ? "1" : "0"),
                    "err=" . gwErr,
                    "pingMs=" . pingMs,
                    "host=" . host . ":" . port
                )
        } catch {
        }
    }
    dbg := quickDbg
    if (token = "") {
        home := ""
        if FuncExists("UserStudio_ResolveOpenClawUserHome")
            try home := UserStudio_ResolveOpenClawUserHome()
        dbg := (dbg != "" ? dbg . " | " : "") . "home=" . home
        if (info is Map && info.Has("tried") && info["tried"] is Array) {
            for _, p in info["tried"]
                dbg .= " | " . p
        }
    }
    reqIdOut := (msg is Map && msg.Has("reqId")) ? String(msg["reqId"]) : ""
    if (action = "refreshOpenClawStudioStatus") {
        ConfigWebView_Send(Map(
            "type", "openclaw_studio_status",
            "token", token,
            "source", source,
            "host", host,
            "port", port,
            "niumaToken", niumaKey,
            "gatewayOk", gwOk,
            "gatewayError", gwErr,
            "debug", dbg,
            "force", !!(msg is Map && msg.Has("force") && msg["force"]),
            "reqId", reqIdOut
        ))
    } else {
        ConfigWebView_Send(Map(
            "type", "openclaw_host_token_probe",
            "token", token,
            "source", source,
            "host", host,
            "port", port,
            "niumaToken", niumaKey,
            "gatewayOk", gwOk,
            "gatewayError", gwErr,
            "debug", dbg,
            "force", !!(msg is Map && msg.Has("force") && msg["force"]),
            "reqId", reqIdOut
        ))
    }
}

ConfigWebView_ProbeOpenClawGateway(base, token, timeoutMs := 12000) {
    if FuncExists("UserStudio_ProbeOpenClawGateway") {
        try return UserStudio_ProbeOpenClawGateway(base, token, timeoutMs)
        catch {
        }
    }
    if FuncExists("LlmApiPing_TestOpenClaw") {
        try return LlmApiPing_TestOpenClaw(base, token, timeoutMs)
        catch {
        }
    }
    token := Trim(String(token))
    if (token = "")
        return Map("ok", false, "error", "缺少 Gateway Token", "elapsedMs", 0)
    host := "127.0.0.1"
    port := 18789
    base := Trim(String(base))
    if RegExMatch(base, "i)^[a-z]+://([^/:]+)(?::(\d+))?", &m) {
        if (m[1] != "")
            host := m[1]
        if (m[2] != "")
            port := Integer(m[2])
    } else if RegExMatch(base, ":(\d+)", &mp)
        port := Integer(mp[1])
    t0 := A_TickCount
    tcpMs := Min(8000, Max(1500, Integer(timeoutMs) // 2))
    if ConfigWebView_TcpPortOpen(host, port, tcpMs)
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0, "via", "tcp")
    cliMs := Min(Max(8000, Integer(timeoutMs)), Max(0, Integer(timeoutMs) - (A_TickCount - t0)))
    if (cliMs >= 3000 && ConfigWebView_OpenClawGatewayCliOk(cliMs))
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0, "via", "cli_status")
    return Map(
        "ok", false,
        "error", "无法连接本机 OpenClaw Gateway（" . host . ":" . port . "）。请执行 openclaw gateway restart。",
        "elapsedMs", A_TickCount - t0
    )
}

ConfigWebView_QuickReadOpenClawGatewayToken() {
    host := "127.0.0.1"
    port := 18789
    paths := []
    try {
        up0 := Trim(String(EnvGet("USERPROFILE")))
        if (up0 != "")
            paths.Push(up0 . "\.openclaw\openclaw.json")
    } catch {
    }
    if (A_AppData != "") {
        hm := Trim(RegExReplace(A_AppData, "\\AppData\\Roaming$", ""))
        if (hm != "") {
            paths.Push(hm . "\.openclaw\openclaw.json")
            paths.Push(hm . "\.openclaw\openclaw.json.last-good")
            paths.Push(hm . "\.openclaw\openclaw.json.bak")
            paths.Push(hm . "\.openclaw\identity\device-auth.json")
        }
    }
    try {
        up := Trim(String(EnvGet("USERPROFILE")))
        if (up != "") {
            paths.Push(up . "\.openclaw\openclaw.json")
            paths.Push(up . "\.openclaw\openclaw.json.last-good")
            paths.Push(up . "\.openclaw\identity\device-auth.json")
        }
    } catch {
    }
    for _, path in paths {
        path := Trim(String(path))
        if (path = "" || !FileExist(path))
            continue
        try {
            raw := FileRead(path, "UTF-8")
            if (Trim(raw) = "")
                continue
            tok := ""
            if InStr(path, "device-auth.json") {
                doc := Jxon_Load(raw)
                if (doc is Map && doc.Has("tokens") && doc["tokens"] is Map) {
                    op := doc["tokens"].Has("operator") ? doc["tokens"]["operator"] : ""
                    if (op is Map)
                        tok := Trim(String(op.Get("token", "")))
                }
            } else {
                meta := Map("token", "", "host", host, "port", port)
                if (StrLen(raw) <= 524288) {
                    try {
                        if FuncExists("UserStudio_ExtractOpenClawGatewayToken") {
                            cfg := Jxon_Load(raw)
                            tok := UserStudio_ExtractOpenClawGatewayToken(cfg)
                            if (tok != "")
                                meta["token"] := tok
                        }
                    } catch {
                    }
                }
                if (meta["token"] = "" && FuncExists("UserStudio_ReadOpenClawAuthTokenLiteral")) {
                    lit := UserStudio_ReadOpenClawAuthTokenLiteral(raw)
                    if (lit != "")
                        meta["token"] := lit
                }
                if (meta["token"] = "" && FuncExists("UserStudio_ExtractOpenClawGatewayFromRaw"))
                    meta := UserStudio_ExtractOpenClawGatewayFromRaw(raw)
                else if (meta["token"] = "" && FuncExists("UserStudio_ReadJsonStringValueAfterKey")) {
                    gwAt := InStr(raw, '"gateway"', false)
                    if (gwAt > 0) {
                        chunk := SubStr(raw, gwAt, 8000)
                        authAt := InStr(chunk, '"auth"', false)
                        if (authAt > 0) {
                            authChunk := SubStr(chunk, authAt, 800)
                            meta["token"] := UserStudio_ReadJsonStringValueAfterKey(authChunk, "token")
                        }
                        if (meta["token"] = "")
                            meta["token"] := UserStudio_ReadJsonStringValueAfterKey(chunk, "token")
                    }
                }
                tok := Trim(String(meta.Get("token", "")))
                host := Trim(String(meta.Get("host", host)))
                port := Integer(meta.Get("port", port))
            }
            if FuncExists("UserStudio_NormalizeApiKey")
                tok := UserStudio_NormalizeApiKey(tok)
            else if FuncExists("LlmApiPing_NormalizeApiKey")
                tok := LlmApiPing_NormalizeApiKey(tok)
            else
                tok := Trim(tok)
            if (tok != "")
                return Map("token", tok, "source", path, "host", host, "port", port)
        } catch {
        }
    }
    return Map("token", "", "source", "", "host", host, "port", port)
}

ConfigWebView_LocalAppDataDir() {
    if FuncExists("UserStudio_LocalAppDataDir")
        return UserStudio_LocalAppDataDir()
    try {
        la := Trim(EnvGet("LOCALAPPDATA"))
        if (la != "")
            return la
    } catch {
    }
    if (A_AppData != "") {
        try {
            p := RegExReplace(A_AppData, "\\Roaming$", "\\Local", , 1)
            if (p != A_AppData)
                return p
        } catch {
        }
    }
    return ""
}

ConfigWebView_NormalizeHermesApiKey(key) {
    key := Trim(String(key))
    if (key = "")
        return ""
    if FuncExists("UserStudio_NormalizeApiKey")
        return UserStudio_NormalizeApiKey(key)
    if FuncExists("LlmApiPing_NormalizeApiKey")
        return LlmApiPing_NormalizeApiKey(key)
    key := RegExReplace(key, "i)^\s*Bearer\s+", "")
    if (SubStr(key, 1, 1) = Chr(34) && SubStr(key, -1) = Chr(34))
        key := SubStr(key, 2, -1)
    return RegExReplace(key, "\s+", "")
}

ConfigWebView_QuickReadHermesApiServerKey() {
    if FuncExists("UserStudio_QuickReadHermesApiServerKey") {
        try return UserStudio_QuickReadHermesApiServerKey()
        catch {
        }
    }
    host := "127.0.0.1"
    port := 8642
    key := ""
    source := ""
    paths := []
    seen := Map()
    pushHermesEnvPath(p) {
        p := Trim(String(p))
        if (p = "" || seen.Has(p))
            return
        seen[p] := true
        paths.Push(p)
    }
    la := ConfigWebView_LocalAppDataDir()
    if (la != "")
        pushHermesEnvPath(la . "\hermes\.env")
    try {
        up := Trim(String(EnvGet("USERPROFILE")))
        if (up != "") {
            pushHermesEnvPath(up . "\.hermes\.env")
            pushHermesEnvPath(up . "\AppData\Local\hermes\.env")
        }
    } catch {
    }
    for _, path in paths {
        if !FileExist(path)
            continue
        try {
            raw := FileRead(path, "UTF-8")
            k := FuncExists("UserStudio_ExtractHermesApiKeyFromEnvRaw")
                ? UserStudio_ExtractHermesApiKeyFromEnvRaw(raw)
                : ""
            if (k = "" && FuncExists("ConfigWebView_NormalizeHermesApiKey")) {
                if (Ord(SubStr(raw, 1, 1)) = 0xFEFF)
                    raw := SubStr(raw, 2)
                lastKey := ""
                for _, line in StrSplit(raw, "`n", "`r") {
                    line := Trim(line)
                    if (line = "" || SubStr(line, 1, 1) = "#" || SubStr(line, 1, 1) = ";")
                        continue
                    if RegExMatch(line, "i)^API_SERVER_KEY\s*=\s*(.+)$", &mk) {
                        cand := ConfigWebView_NormalizeHermesApiKey(Trim(mk[1]))
                        if (cand != "")
                            lastKey := cand
                    }
                }
                k := lastKey
            }
            if (k = "")
                continue
            key := k
            source := path
            if RegExMatch(raw, "m)^API_SERVER_HOST\s*=\s*([^\r\n#;]+)", &mh)
                host := Trim(mh[1])
            if RegExMatch(raw, "m)^API_SERVER_PORT\s*=\s*(\d+)", &mp)
                port := Integer(mp[1])
            if (host = "localhost")
                host := "127.0.0.1"
            break
        } catch {
        }
    }
    tried := []
    for _, path in paths
        tried.Push(path)
    return Map("token", key, "source", source, "host", host, "port", port, "tried", tried)
}

ConfigWebView_OnMessage(sender, args) {
    global ConfigWV2Ready, UseWebViewSettings
    jsonStr := FuncExists("WebView2_CopyWebMessageJson") ? WebView2_CopyWebMessageJson(args) : ""
    if (jsonStr = "")
        return
    try {
        msg := FuncExists("Jxon_LoadSafe") ? Jxon_LoadSafe(jsonStr) : Jxon_Load(jsonStr)
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
            ; 仅同步数据，不抢导航（默认页跳转由 ShowConfigWebViewGUI 延迟 initData 负责，且每窗仅一次）
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
            try selectedDir := FileSelect("D", Nmer_FullTextIndexDir(), "选择全文索引目录")
            if (selectedDir = "")
                selectedDir := ""
            ConfigWebView_Send(Map("type", "fulltextBrowseResult", "path", selectedDir))
        case "fulltextProbeRequest":
            ConfigWebView_FullTextProbe()
        case "cacheInfoRequest":
            ConfigWebView_SendCacheInfo()
        case "cacheOpenFolder":
            sub := msg.Has("target") ? String(msg["target"]) : "root"
            ConfigWebView_OpenCacheFolder(sub)
        case "cachePickRoot":
            picked := ""
            try picked := FileSelect("D", Nmer_UserCacheRoot(), "选择缓存根目录")
            ConfigWebView_Send(Map("type", "cacheRootPicked", "ok", picked != "", "path", picked, "error", picked = "" ? "已取消" : ""))
        case "cacheSaveRoot":
            newRoot := msg.Has("path") ? Trim(String(msg["path"])) : ""
            ok := false
            err := ""
            try {
                if (newRoot = "")
                    throw Error("路径为空")
                Nmer_SetUserCacheRoot(newRoot)
                ok := true
            } catch as e {
                err := e.Message
            }
            if ok
                ConfigWebView_SendCacheInfo()
            ConfigWebView_Send(Map("type", "cacheSaveRootResult", "ok", ok, "error", err, "path", ok ? Nmer_UserCacheRoot() : ""))
        case "cacheClear":
            targets := []
            if msg.Has("targets") && (msg["targets"] is Array)
                for t in msg["targets"]
                    targets.Push(String(t))
            ConfigWebView_ClearCacheAsync(targets*)
        case "browseCursorPath":
            selected := FileSelect("1", A_ScriptDir, "閫夋嫨 Cursor.exe", "Executable (*.exe)")
            if (selected = "")
                selected := ""
            ConfigWebView_Send(Map("type", "browseCursorPathResult", "path", selected))
        case "browseUserStudioPath":
            field := Trim(String(msg.Get("field", "")))
            selected := ""
            if FuncExists("UserStudio_BrowsePath")
                selected := UserStudio_BrowsePath(field)
            ConfigWebView_Send(Map("type", "browseUserStudioPathResult", "field", field, "path", selected))
        case "saveUserStudio":
            ok := false
            err := ""
            try {
                ConfigWebView_ApplyUserStudioSave(msg)
                ok := true
            } catch as e {
                err := e.Message
                try OutputDebug("[ConfigWebView] saveUserStudio failed: " . err)
                catch {
                }
            }
            if ok {
                try {
                    if FuncExists("FloatingToolbar_GetStudioLlm") && FuncExists("FloatingToolbar_PushStudioLlmToChat") {
                        llmPush := FloatingToolbar_GetStudioLlm()
                        if (llmPush is Map && Trim(String(llmPush.Get("apiKey", ""))) != "")
                            FloatingToolbar_PushStudioLlmToChat(llmPush, "", false)
                    }
                } catch {
                }
            }
            studio := ok ? ConfigWebView_UserStudioPayloadForWebAfterSave() : Map()
            ConfigWebView_Send(Map("type", "saveUserStudioResult", "ok", ok, "error", err, "userStudio", studio))
        case "saveStudioLlmCards":
            ok := false
            err := ""
            try {
                ConfigWebView_ApplyUserStudioSave(msg)
                ok := true
            } catch as e {
                err := e.Message
                try OutputDebug("[ConfigWebView] saveStudioLlmCards failed: " . err)
                catch {
                }
            }
            studio := ok ? ConfigWebView_UserStudioPayloadForWebAfterSave() : Map()
            ConfigWebView_Send(Map("type", "saveUserStudioResult", "ok", ok, "error", err, "userStudio", studio))
        case "hermes_probe_token", "refreshHermesStudioStatus", "ensureHermesApiServerEnv":
            if (action = "refreshHermesStudioStatus") {
                SetTimer(ConfigWebView_RefreshHermesStudioStatus_Deferred.Bind(msg), -1)
                return
            }
            ConfigWebView_RunHermesStudioProbe(msg, action)
        case "hermes_restart_gateway", "niuma_hermes_restart_gateway":
            rr := Map("ok", false, "error", "restart_unavailable")
            if FuncExists("UserStudio_RestartHermesGateway") {
                try rr := UserStudio_RestartHermesGateway(45000)
                catch as eRr {
                    rr := Map("ok", false, "error", eRr.Message)
                }
            }
            ConfigWebView_Send(Map(
                "type", "hermes_gateway_restart_result",
                "ok", !!rr.Get("ok", false),
                "error", String(rr.Get("error", "")),
                "elapsedMs", Integer(rr.Get("elapsedMs", 0))
            ))
        case "refreshOpenClawStudioStatus":
            SetTimer(ConfigWebView_RefreshOpenClawStudioStatus_Deferred.Bind(msg), -1)
        case "openclaw_probe_token", "niuma_openclaw_probe_token":
            ConfigWebView_RunOpenClawProbe(msg, action)
        case "testUserStudioLlm":
            payload := ConfigWebView_ParseUserStudioSavePayload(msg)
            if !(payload is Map)
                payload := Map()
            llm := payload
            if FuncExists("LlmApiPing_ResolveFromPayload")
                llm := LlmApiPing_ResolveFromPayload(payload)
            else if (payload.Has("llm") && payload["llm"] is Map)
                llm := payload["llm"]
            if !(llm is Map)
                llm := Map()
            provTest := ConfigWebView_LlmNormProv(llm.Get("provider", ""))
            if (provTest = "hermes") {
                if FuncExists("UserStudio_ReadHermesApiConfig") {
                    try {
                        cfgH := UserStudio_ReadHermesApiConfig()
                        if (cfgH is Map) {
                            envKey := ConfigWebView_NormalizeApiKey(cfgH.Get("key", ""))
                            if (envKey != "")
                                llm["apiKey"] := envKey
                            eh := Trim(String(cfgH.Get("host", "")))
                            ep := Integer(cfgH.Get("port", 8642))
                            if (eh = "localhost")
                                eh := "127.0.0.1"
                            if (eh != "" && ep > 0)
                                llm["baseUrl"] := "http://" . eh . ":" . ep . "/v1"
                        }
                    } catch {
                    }
                }
                if Trim(String(llm.Get("baseUrl", ""))) = ""
                    llm["baseUrl"] := "http://127.0.0.1:8642/v1"
            }
            ok := false
            err := ""
            elapsed := 0
            try {
                r := ConfigWebView_TestLlmPing(llm, 18000)
                ok := r.Get("ok", false)
                err := r.Get("error", "")
                elapsed := Integer(r.Get("elapsedMs", 0))
            } catch as e {
                err := e.Message
            }
            ConfigWebView_Send(Map("type", "testUserStudioLlmResult", "ok", ok, "error", err, "elapsedMs", elapsed))
        case "restoreUserStudio":
            ok := false
            err := ""
            try {
                if FuncExists("UserStudio_RestoreDefaults") {
                    r := UserStudio_RestoreDefaults()
                    ok := r.Get("ok", false)
                    err := r.Get("error", "")
                } else
                    err := "UserStudio 未加载"
            } catch as e {
                err := e.Message
            }
            studio := Map()
            if ok && FuncExists("UserStudio_PayloadForWeb") {
                try studio := UserStudio_PayloadForWeb()
                catch {
                    studio := Map()
                }
            }
            if ok {
                try ConfigWebView_Send(Map("type", "initData", "payload", ConfigWebView_BuildInitDataSafe()))
                catch {
                }
            }
            ConfigWebView_Send(Map("type", "restoreUserStudioResult", "ok", ok, "error", err, "userStudio", studio))
        case "openNiumaChatTtyd":
            try CloseConfigGUI()
            catch {
            }
            ok := false
            err := ""
            startChat := msg.Has("startChat") ? !!msg["startChat"] : false
            pl := msg.Get("payload", Map())
            if (pl is String && pl != "") {
                try pl := Jxon_Load(pl)
                catch {
                    pl := Map()
                }
            }
            if !(pl is Map)
                pl := Map()
            try {
                if FuncExists("UserStudio_ApplyFromWebPayload") && pl.Has("llm")
                    UserStudio_ApplyFromWebPayload(pl)
                if FuncExists("UserStudio_Load")
                    UserStudio_Load()
                if FuncExists("FloatingToolbar_OpenNiumaChatTtydCustomize") {
                    FloatingToolbar_OpenNiumaChatTtydCustomize(startChat)
                    ok := true
                } else
                    err := "悬浮栏未加载，无法打开 Niuma Chat"
            } catch as e {
                err := e.Message
            }
            if !ok
                ConfigWebView_Send(Map("type", "openNiumaChatTtydResult", "ok", false, "error", err))
        case "openNiumaChatAsk":
            prompt := Trim(String(msg.Get("prompt", "")))
            autoSend := msg.Has("autoSend") ? !!msg["autoSend"] : (prompt != "")
            try CloseConfigGUI()
            catch {
            }
            ok := false
            err := ""
            try {
                if FuncExists("UserStudio_ApplyFromWebPayload") && msg.Has("payload") && msg["payload"] is Map {
                    pl := msg["payload"]
                    if pl.Has("llm")
                        UserStudio_ApplyFromWebPayload(pl)
                }
                if FuncExists("FloatingToolbar_OpenNiumaChatAsk") {
                    FloatingToolbar_OpenNiumaChatAsk(prompt, autoSend)
                    ok := true
                } else
                    err := "悬浮栏未加载，无法打开 Niuma Chat"
            } catch as e {
                err := e.Message
            }
            if !ok
                ConfigWebView_Send(Map("type", "openNiumaChatAskResult", "ok", false, "error", err))
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
        case "saveThemeMode":
            tm := msg.Has("themeMode") ? msg["themeMode"] : (msg.Has("ThemeMode") ? msg["ThemeMode"] : "")
            err := ""
            ok := ConfigWebView_SaveThemeMode(tm, &err)
            saved := ""
            if ok
                saved := NormalizeIniThemeMode(IsSet(ThemeMode) ? ThemeMode : "dark", "dark")
            ConfigWebView_Send(Map("type", "saveThemeModeResult", "ok", ok, "error", err, "themeMode", saved))
        case "saveDefaultStartTab":
            tab := msg.Has("tab") ? msg["tab"] : (msg.Has("defaultStartTab") ? msg["defaultStartTab"] : "")
            err := ""
            ok := ConfigWebView_SaveDefaultStartTab(tab, &err)
            savedTab := ""
            if ok
                savedTab := FuncExists("NormalizeDefaultStartTab")
                    ? NormalizeDefaultStartTab(DefaultStartTab) : DefaultStartTab
            ConfigWebView_Send(Map("type", "saveDefaultStartTabResult", "ok", ok, "error", err, "tab", savedTab))
        case "savePopupScreenIndex":
            idx := Integer(msg.Has("popupScreenIndex") ? msg["popupScreenIndex"] : (msg.Has("screenIndex") ? msg["screenIndex"] : 1))
            err := ""
            ok := ConfigWebView_PersistPopupScreenIndex(idx, &err)
            savedIdx := ok ? ConfigWebView_ReadPersistedPopupScreenIndex() : idx
            ConfigWebView_Send(Map("type", "savePopupScreenIndexResult", "ok", ok, "error", err, "popupScreenIndex", savedIdx))
        case "saveGeneralSettings":
            gPayload := msg.Get("payload", Map())
            if (gPayload is String && gPayload != "") {
                try gPayload := Jxon_Load(gPayload)
                catch {
                    gPayload := Map()
                }
            }
            if !(gPayload is Map)
                gPayload := Map()
            err := ""
            ok := ConfigWebView_SaveGeneralSettings(gPayload, &err)
            ConfigWebView_Send(Map("type", "saveGeneralSettingsResult", "ok", ok, "error", err))
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
            resp := Map("type", "saveHoleResult", "ok", ok, "error", err)
            if ok && (payload is Map) {
                resp["saved"] := Map(
                    "holeTriggerTextSelect", ConfigWebView_CoerceBool(payload.Get("holeTriggerTextSelect", true), true),
                    "holeTriggerCircleCw", ConfigWebView_CoerceBool(payload.Get("holeTriggerCircleCw", false), false),
                    "holeTriggerCircleCcw", ConfigWebView_CoerceBool(payload.Get("holeTriggerCircleCcw", false), false),
                    "holeTriggerRButtonHold", ConfigWebView_CoerceBool(payload.Get("holeTriggerRButtonHold", false), false),
                    "holeRButtonHoldMs", Integer(payload.Get("holeRButtonHoldMs", 3000)),
                    "holeSensitivityPreset", Trim(String(payload.Get("holeSensitivityPreset", "standard"))),
                    "holePlacementPreset", Trim(String(payload.Get("holePlacementPreset", "cursor")))
                )
            }
            ConfigWebView_Send(resp)
        case "previewHoleOnScreen":
            previewPayload := msg.Get("payload", Map())
            if (previewPayload is String && previewPayload != "") {
                try previewPayload := Jxon_Load(previewPayload)
                catch {
                    previewPayload := Map()
                }
            }
            if !(previewPayload is Map)
                previewPayload := Map()
            previewErr := ""
            previewOk := ConfigWebView_PreviewHoleOnScreen(previewPayload, &previewErr)
            ConfigWebView_Send(Map("type", "previewHoleResult", "ok", previewOk, "error", previewErr))
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
        case "vkStartRecord":
            cmdId := Trim(String(msg.Get("commandId", "")))
            if (cmdId != "" && FuncExists("_BeginRecord")) {
                ConfigWebView_VkEnsureCommandsLoaded()
                try _BeginRecord(cmdId, "replace_global", "")
                catch as e {
                    ConfigWebView_Send(Map("type", "vkWebEvent", "event", Map("type", "recordHint", "active", false)))
                    OutputDebug("[ConfigWebView] vkStartRecord: " . e.Message)
                }
            }
        case "vkCancelRecord":
            if FuncExists("_EndRecord")
                try _EndRecord()
            catch {
            }
            ConfigWebView_Send(Map("type", "vkWebEvent", "event", Map("type", "recordHint", "active", false)))
        case "vkBindKey":
            cmdId := Trim(String(msg.Get("commandId", "")))
            ahkKey := Trim(String(msg.Get("ahkKey", "")))
            displayKey := msg.Has("displayKey") ? String(msg["displayKey"]) : ahkKey
            if (cmdId != "" && ahkKey != "" && FuncExists("_DoBindKey")) {
                ConfigWebView_VkEnsureCommandsLoaded()
                try {
                    if _DoBindKey(cmdId, ahkKey, displayKey, "replace_global")
                        ConfigWebView_VkPushBindingsSnapshot()
                } catch as e {
                    OutputDebug("[ConfigWebView] vkBindKey: " . e.Message)
                }
            }
        case "vkClearBinding":
            cmdId := Trim(String(msg.Get("commandId", "")))
            if (cmdId != "" && FuncExists("_DoClearBinding")) {
                ConfigWebView_VkEnsureCommandsLoaded()
                try {
                    _DoClearBinding(cmdId)
                    ConfigWebView_VkPushBindingsSnapshot()
                } catch as e {
                    OutputDebug("[ConfigWebView] vkClearBinding: " . e.Message)
                }
            }
        case "vkResetBinding":
            cmdId := Trim(String(msg.Get("commandId", "")))
            if (cmdId != "" && FuncExists("_DoResetSingle")) {
                ConfigWebView_VkEnsureCommandsLoaded()
                try {
                    _DoResetSingle(cmdId)
                    ConfigWebView_VkPushBindingsSnapshot()
                } catch as e {
                    OutputDebug("[ConfigWebView] vkResetBinding: " . e.Message)
                }
            }
        case "vkResolveConflict":
            if FuncExists("_DoBindKey") && msg.Has("confirm") && msg["confirm"] {
                cmdId := Trim(String(msg.Get("commandId", "")))
                ahkKey := Trim(String(msg.Get("ahkKey", "")))
                displayKey := msg.Has("displayKey") ? String(msg["displayKey"]) : ahkKey
                if (cmdId != "" && ahkKey != "") {
                    ConfigWebView_VkEnsureCommandsLoaded()
                    try {
                        if _DoBindKey(cmdId, ahkKey, displayKey, "replace_global")
                            ConfigWebView_VkPushBindingsSnapshot()
                    } catch as e {
                        OutputDebug("[ConfigWebView] vkResolveConflict: " . e.Message)
                    }
                }
            }
            ConfigWebView_Send(Map("type", "vkWebEvent", "event", Map("type", "recordHint", "active", false)))
        case "probeVk":
            ConfigWebView_Send(Map("type", "vkStatus", "available", ConfigWebView_IsVkAvailable()))
        case "invokeAction":
            op := msg.Get("op", msg.Get("action", ""))
            payload := msg.Get("payload", Map())
            ok := true
            err := ""
            try {
                switch op {
                    case "exportConfig":
                        ExportConfig()
                    case "importConfig":
                        ImportConfig()
                    case "resetToDefaults":
                        ResetToDefaults()
                    case "exportUserStudio":
                        if FuncExists("UserStudio_ExportTo") {
                            dest := FileSelect("S", A_ScriptDir . "\user_studio_backup.json", "导出智能定制配置", "JSON (*.json)")
                            if (dest != "") {
                                r := UserStudio_ExportTo(dest)
                                if !r.Get("ok", false)
                                    throw Error(r.Get("error", "导出失败"))
                            }
                        }
                    case "importUserStudio":
                        if FuncExists("UserStudio_ImportFrom") {
                            src := FileSelect(1, A_ScriptDir, "导入智能定制配置", "JSON (*.json)")
                            if (src != "") {
                                r := UserStudio_ImportFrom(src)
                                if !r.Get("ok", false)
                                    throw Error(r.Get("error", "导入失败"))
                            }
                        }
                    case "restoreUserStudio":
                        if FuncExists("UserStudio_RestoreDefaults") {
                            r := UserStudio_RestoreDefaults()
                            if !r.Get("ok", false)
                                throw Error(r.Get("error", "还原失败"))
                        }
                    case "openNiumaChatTtyd":
                        if FuncExists("UserStudio_ApplyFromWebPayload") && (payload is Map) && payload.Has("llm") {
                            try UserStudio_ApplyFromWebPayload(payload)
                            catch {
                            }
                        }
                        if FuncExists("UserStudio_Load")
                            try UserStudio_Load()
                            catch {
                            }
                        sc := msg.Has("startChat") ? !!msg["startChat"] : false
                        if FuncExists("FloatingToolbar_OpenNiumaChatTtydCustomize") {
                            try CloseConfigGUI()
                            catch {
                            }
                            FloatingToolbar_OpenNiumaChatTtydCustomize(sc)
                        } else
                            throw Error("无法打开 Niuma Chat")
                    case "openNiumaChatAsk":
                        if FuncExists("FloatingToolbar_OpenNiumaChatAsk") {
                            try CloseConfigGUI()
                            catch {
                            }
                            FloatingToolbar_OpenNiumaChatAsk("", false)
                        } else
                            throw Error("无法打开 Niuma Chat")
                    case "loadNiumaProjectBrief":
                        txt := ""
                        if FuncExists("UserStudio_BuildDefaultNiumaSystemPrompt") {
                            try txt := UserStudio_BuildDefaultNiumaSystemPrompt()
                            catch {
                            }
                        }
                        ConfigWebView_Send(Map("type", "loadNiumaProjectBriefResult", "ok", true, "text", txt))
                        return
                    case "syncNiumaChatLlmToStudio":
                        ok := false
                        err := ""
                        studio := Map()
                        needChatExport := false
                        try {
                            if FuncExists("UserStudio_SyncFromNiumaFile") {
                                r := UserStudio_SyncFromNiumaFile()
                                ok := r.Get("ok", false)
                                err := r.Get("error", "")
                                if r.Has("studio")
                                    studio := r["studio"]
                            }
                            ; 文件里已有 minimax 等 Key 时 ok=true，但 OpenClaw 可能只在 Chat localStorage
                            if FuncExists("UserStudio_ReadNiumaOpenClawKey") {
                                try {
                                    if (UserStudio_ReadNiumaOpenClawKey() = "")
                                        needChatExport := true
                                } catch {
                                    needChatExport := true
                                }
                            }
                            if ((!ok || needChatExport) && FuncExists("FloatingToolbar_RequestNiumaLlmExport")) {
                                global g_ConfigWebView_PendingStudioSync := true
                                FloatingToolbar_RequestNiumaLlmExport()
                                return
                            }
                        } catch as e {
                            err := e.Message
                        }
                        if ok && FuncExists("UserStudio_PayloadForWeb")
                            studio := UserStudio_PayloadForWeb()
                        ConfigWebView_Send(Map("type", "syncNiumaChatLlmResult", "ok", ok, "error", err, "userStudio", studio))
                        return
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
                    case "showVk":
                        ConfigWebView_OpenVkKeybinder()
                    default:
                        ok := false
                        err := "鏈煡鎿嶄綔: " . op
                }
            } catch as e {
                ok := false
                err := e.Message
            }
            ConfigWebView_Send(Map("type", "actionResult", "ok", ok, "error", err, "op", op))
        case "openAppRelease":
            ok := false
            err := ""
            try {
                if FuncExists("AppUpdateCheck_OpenReleasePage")
                    ok := AppUpdateCheck_OpenReleasePage()
                if !ok
                    err := "无法打开浏览器"
            } catch as e {
                err := e.Message
            }
            if !ok && err != ""
                ConfigWebView_Send(Map("type", "openAppReleaseResult", "ok", false, "error", err))
        case "checkAppUpdate":
            try {
                if FuncExists("AppUpdateCheck_CheckNow")
                    AppUpdateCheck_CheckNow(true)
            } catch {
            }
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

; WebView 设置页关闭（由 CloseConfigGUI 在 ConfigWebViewMode 下调用）
ConfigWebView_Close() {
    if FuncExists("SurfaceIntent_RouteExternalClose") && SurfaceIntent_RouteExternalClose("config_webview")
        return
    global GuiID_ConfigGUI, ConfigWV2Ctrl, ConfigWV2, g_ConfigWebView_StartTabNavigated
    skipTel := FuncExists("SurfaceIntent_ShouldSkipExecutorTelemetry") && SurfaceIntent_ShouldSkipExecutorTelemetry()
    if !skipTel {
        reqId := SurfaceManager_Request("config_webview", "close", "ConfigWebView_Close", Map("hostAliveBefore", ConfigWebView_HostAlive() ? 1 : 0))
        try SurfaceManager_ObserveHide("config_webview", Map("entry", "ConfigWebView_Close", "requestId", reqId))
    }
    g_ConfigWebView_StartTabNavigated := false
    try {
        if IsSet(ConfigWV2) && ConfigWV2
            ConfigWV2.ExecuteScriptAsync("(function(){try{if(window.__nmerFlushStudioLlm)window.__nmerFlushStudioLlm();if(window.__nmerFlushSettingsTab)window.__nmerFlushSettingsTab();}catch(e){}})()")
    } catch {
    }
    Sleep 220
    try FloatingToolbar_PageDockLeave("settings")
    try {
        WMActivateChain_Unregister(ConfigWebView_WM_ACTIVATE)
        try WebView2_NotifyHidden(ConfigWV2)
        GuiID_ConfigGUI.Hide()
    } catch {
    }
}

ConfigWebView_Dispose(reason := "") {
    global GuiID_ConfigGUI, ConfigWV2Ctrl, ConfigWV2, ConfigWebViewMode, ConfigWV2Ready
    global ConfigWebViewPreloaded, ConfigWebViewNavFallbackTried, g_ConfigWebView_StartTabNavigated
    try ConfigWebView_Close()
    catch {
    }
    SurfaceManager_CloseWebViewControl(ConfigWV2Ctrl)
    ConfigWV2Ctrl := 0
    ConfigWV2 := 0
    ConfigWV2Ready := false
    ConfigWebViewMode := false
    ConfigWebViewPreloaded := false
    ConfigWebViewNavFallbackTried := false
    g_ConfigWebView_StartTabNavigated := false
    SurfaceManager_DestroyGui(GuiID_ConfigGUI)
    GuiID_ConfigGUI := 0
    try SurfaceManager_ObserveClose("config_webview", Map("entry", "ConfigWebView_Dispose", "reason", String(reason)))
}

; ===================== 智能定制 API 连通性测试（内置于设置中心，不依赖 FuncExists / 外部模块） =====================

global ConfigWebView_MINIMAX_BASE_CN := "https://api.minimaxi.com/anthropic"
global ConfigWebView_MINIMAX_BASE_INTL := "https://api.minimax.io/anthropic"

ConfigWebView_NormalizeApiKey(key) {
    if FuncExists("LlmApiPing_NormalizeApiKey")
        return LlmApiPing_NormalizeApiKey(key)
    key := Trim(String(key))
    if (key = "")
        return ""
    key := RegExReplace(key, "i)^\s*Bearer\s+", "")
    if FuncExists("LlmApiPing_StripSurroundingQuotes")
        key := LlmApiPing_StripSurroundingQuotes(key)
    key := RegExReplace(key, "\s+", "")
    return key
}

ConfigWebView_ParseLlmErrDetail(raw) {
    raw := Trim(String(raw))
    if (raw = "")
        return ""
    try {
        j := Jxon_Load(raw)
        if (j is Map) {
            if j.Has("error") {
                er := j["error"]
                if (er is Map) && er.Has("message")
                    return Trim(String(er["message"]))
                if (er is Map) && er.Has("type")
                    return Trim(String(er["type"]))
            }
            if j.Has("base_resp") && j["base_resp"] is Map {
                br := j["base_resp"]
                sm := Trim(String(br.Get("status_msg", "")))
                sc := Integer(br.Get("status_code", 0))
                if (sm != "")
                    return (sc ? "[" . sc . "] " : "") . sm
            }
            if j.Has("message")
                return Trim(String(j["message"]))
        }
    } catch {
    }
    return SubStr(raw, 1, 200)
}

ConfigWebView_FormatMinimaxErr(status, raw, endpointUrl, baseUrl) {
    detail := ConfigWebView_ParseLlmErrDetail(raw)
    ep := (endpointUrl != "") ? (" 请求：" . endpointUrl) : ""
    bu := (baseUrl != "") ? (" Base：" . baseUrl) : ""
    if (status = 401 || RegExMatch(detail . raw, "i)authorized_error|login fail|1004|invalid api key|authentication")) {
        return "MiniMax 鉴权失败 (401)：请确认 ① 使用 Billing→Token Plan 密钥（不是开放平台「接口密钥」按量付费）；"
            . " ② 已分配 Token Plan 席位； ③ 节点与密钥区域一致（国内 "
            . ConfigWebView_MINIMAX_BASE_CN . " / 国际 " . ConfigWebView_MINIMAX_BASE_INTL . "）。"
            . (detail ? " 详情：" . detail : "") . ep . bu
    }
    return "HTTP " . status . (detail ? ("：" . detail) : (raw ? ("：" . SubStr(raw, 1, 120)) : "")) . ep
}

ConfigWebView_MinimaxPingOnce(key, base, model, timeoutMs) {
    pingAnth := Jxon_Dump(Map("model", model, "max_tokens", 8, "messages", [Map("role", "user", "content", "ping")]))
    pingOpenAI := Jxon_Dump(Map("model", model, "messages", [Map("role", "user", "content", "ping")], "max_tokens", 8, "temperature", 0.1))
    hdr := Map(
        "Content-Type", "application/json",
        "Authorization", "Bearer " . key,
        "anthropic-version", "2023-06-01"
    )
    urlA := ConfigWebView_MinimaxAnthropicUrl(base)
    r := ConfigWebView_LlmHttpSync("POST", urlA, hdr, pingAnth, timeoutMs)
    if r["ok"]
        return Map("ok", true, "error", "", "elapsedMs", r["elapsedMs"], "endpoint", urlA)
    urlO := ConfigWebView_MinimaxOpenAIUrl(base)
    r2 := ConfigWebView_LlmHttpSync("POST", urlO, Map("Content-Type", "application/json", "Authorization", "Bearer " . key), pingOpenAI, timeoutMs)
    if r2["ok"]
        return Map("ok", true, "error", "", "elapsedMs", r2["elapsedMs"], "endpoint", urlO)
    err := ConfigWebView_FormatMinimaxErr(Integer(r2.Has("status") ? r2["status"] : 401), r2.Has("text") ? r2["text"] : r["text"], urlA, base)
    return Map("ok", false, "error", err, "elapsedMs", Integer(r2.Has("elapsedMs") ? r2["elapsedMs"] : r["elapsedMs"]), "endpoint", urlA)
}

ConfigWebView_TestMinimaxPing(key, base, model, timeoutMs := 18000) {
    key := ConfigWebView_NormalizeApiKey(key)
    if (key = "")
        return Map("ok", false, "error", "请先填写 API Key", "elapsedMs", 0)
    model := Trim(String(model))
    if (model = "")
        model := "MiniMax-M2.7"
    base := Trim(String(base))
    if (base = "")
        base := ConfigWebView_MINIMAX_BASE_CN
    bases := []
    bases.Push(base)
    lb := StrLower(base)
    if InStr(lb, "minimaxi.com") && !InStr(lb, "minimax.io")
        bases.Push(ConfigWebView_MINIMAX_BASE_INTL)
    else if InStr(lb, "minimax.io") && !InStr(lb, "minimaxi.com")
        bases.Push(ConfigWebView_MINIMAX_BASE_CN)
    last := Map("ok", false, "error", "测试失败", "elapsedMs", 0)
    for b in bases {
        r := ConfigWebView_MinimaxPingOnce(key, b, model, timeoutMs)
        if r.Get("ok", false)
            return r
        last := r
        if (bases.Length = 1)
            break
        last["error"] := r.Get("error", "") . "（已自动尝试另一节点仍失败，请手动切换国内/国际）"
    }
    return last
}

ConfigWebView_LlmNormProv(prov) {
    if FuncExists("UserStudio_NormalizeLlmProvider")
        return UserStudio_NormalizeLlmProvider(prov)
    prov := Trim(String(prov))
    if (prov = "anthropic")
        return "claude"
    if (prov = "codex")
        return "openai"
    return prov
}

ConfigWebView_LlmPreset(prov) {
    if FuncExists("UserStudio_LlmPresetFor")
        return UserStudio_LlmPresetFor(prov)
    prov := ConfigWebView_LlmNormProv(prov)
    switch prov {
        case "minimax":
            return Map("baseUrl", "https://api.minimaxi.com/anthropic", "model", "MiniMax-M2.7")
        case "gemini":
            return Map("baseUrl", "https://generativelanguage.googleapis.com/v1beta", "model", "gemini-2.5-flash")
        case "deepseek":
            return Map("baseUrl", "https://api.deepseek.com/v1", "model", "deepseek-chat")
        case "kimi":
            return Map("baseUrl", "https://api.moonshot.cn/v1", "model", "kimi-k2.6")
        case "claude":
            return Map("baseUrl", "https://api.anthropic.com", "model", "claude-3-5-sonnet-latest")
        case "ollama":
            return Map("baseUrl", "http://127.0.0.1:11434/v1", "model", "nemotron-3-super:cloud")
        default:
            return Map("baseUrl", "https://api.openai.com/v1", "model", "gpt-4o-mini")
    }
}

ConfigWebView_LlmUriEnc(s) {
    if FuncExists("UriEncode")
        return UriEncode(s)
    return s
}

ConfigWebView_LlmHttpSync(method, url, headers, body, timeoutMs := 18000) {
    if FuncExists("LlmApiPing_HttpSync") {
        try return LlmApiPing_HttpSync(method, url, headers, body, timeoutMs)
        catch {
        }
    }
    start := A_TickCount
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        if RegExMatch(String(url), "i)^https?://(127\.0\.0\.1|localhost)(:\d+)?/")
            try whr.SetProxy(1)
        whr.Open(method, url, false)
        t := Max(3000, Integer(timeoutMs))
        whr.SetTimeouts(t, t, t, t)
        if (headers is Map) {
            for k, v in headers
                whr.SetRequestHeader(String(k), String(v))
        }
        whr.Send(String(body))
        status := Integer(whr.Status)
        text := ""
        try text := String(whr.ResponseText)
        ok := (status >= 200 && status < 300)
        return Map(
            "ok", ok,
            "status", status,
            "text", text,
            "error", ok ? "" : ("HTTP " . status),
            "elapsedMs", A_TickCount - start
        )
    } catch as e {
        errMsg := e.Message
        if RegExMatch(errMsg, "i)timeout|timed\s*out|超时")
            errMsg := "连接超时（约 " . Round(Max(3000, Integer(timeoutMs)) / 1000) . " 秒），请检查网络或 Base URL 是否与密钥区域一致"
        return Map("ok", false, "status", 0, "text", "", "error", errMsg, "elapsedMs", A_TickCount - start)
    }
}

ConfigWebView_MinimaxAnthropicUrl(base) {
    u := Trim(String(base))
    if (u = "")
        u := "https://api.minimaxi.com/anthropic"
    u := RegExReplace(u, "/+$", "")
    lu := StrLower(u)
    if InStr(lu, "/v1/messages") || InStr(lu, "/messages")
        return u
    if RegExMatch(lu, "/anthropic$")
        return u . "/v1/messages"
    if RegExMatch(lu, "/v1$")
        return u . "/messages"
    return u . "/v1/messages"
}

ConfigWebView_MinimaxOpenAIUrl(base) {
    u := Trim(String(base))
    if (u = "")
        return "https://api.minimax.io/v1/chat/completions"
    u := RegExReplace(u, "/+$", "")
    lu := StrLower(u)
    if InStr(lu, "/chat/completions")
        return u
    if RegExMatch(lu, "/anthropic$")
        return RegExReplace(u, "/anthropic$", "") . "/v1/chat/completions"
    if RegExMatch(lu, "/v1$") || RegExMatch(lu, "/v1beta$")
        return u . "/chat/completions"
    return u . "/v1/chat/completions"
}

ConfigWebView_OpenAIChatUrl(base) {
    u := Trim(String(base))
    if (u = "")
        u := "https://api.openai.com/v1"
    u := RegExReplace(u, "/+$", "")
    if InStr(StrLower(u), "/chat/completions")
        return u
    return u . "/chat/completions"
}

ConfigWebView_ClaudeMessagesUrl(base) {
    u := Trim(String(base))
    if (u = "")
        u := "https://api.anthropic.com"
    u := RegExReplace(u, "/+$", "")
    if InStr(StrLower(u), "/v1/messages")
        return u
    return u . "/v1/messages"
}

ConfigWebView_GeminiGenerateUrl(base, model, apiKey) {
    u := Trim(String(base))
    if (u = "")
        u := "https://generativelanguage.googleapis.com/v1beta"
    u := RegExReplace(u, "/+$", "")
    m := Trim(String(model))
    if (m = "")
        m := "gemini-2.5-flash"
    encKey := ConfigWebView_LlmUriEnc(apiKey)
    if InStr(StrLower(u), ":generatecontent")
        return u . "?key=" . encKey
    return u . "/models/" . m . ":generateContent?key=" . encKey
}

ConfigWebView_TestLlmPing(llm, timeoutMs := 18000) {
    try {
        return LlmApiPing_Test(llm, timeoutMs)
    } catch as e {
        try OutputDebug("[ConfigWebView] LlmApiPing_Test failed: " . e.Message)
        catch {
        }
    }
    if !(llm is Map)
        return Map("ok", false, "error", "配置无效", "elapsedMs", 0)
    prov := ConfigWebView_LlmNormProv(llm.Get("provider", "openai"))
    key := ConfigWebView_NormalizeApiKey(llm.Get("apiKey", ""))
    base := Trim(String(llm.Get("baseUrl", "")))
    model := Trim(String(llm.Get("model", "")))
    pre := ConfigWebView_LlmPreset(prov)
    if (base = "")
        base := pre.Get("baseUrl", "")
    if (model = "")
        model := pre.Get("model", "")
    if (prov != "ollama" && key = "")
        return Map("ok", false, "error", "请先填写 API Key", "elapsedMs", 0)
    t0 := A_TickCount
    if (prov = "minimax")
        return ConfigWebView_TestMinimaxPing(key, base, model, timeoutMs)
    if (prov = "kimi") {
        try {
            return LlmApiPing_TestKimi(key, base, model, timeoutMs)
        } catch {
            headers := Map("Content-Type", "application/json", "Authorization", "Bearer " . key)
            bu := LlmApiPing_NormalizeMoonshotBase(base)
            if (bu = "")
                bu := "https://api.moonshot.cn/v1"
            body := Jxon_Dump(Map("model", model, "messages", [Map("role", "user", "content", "ping")], "max_completion_tokens", 64))
            r := ConfigWebView_LlmHttpSync("POST", ConfigWebView_OpenAIChatUrl(bu), headers, body, timeoutMs)
            err := r["ok"] ? "" : (FuncExists("LlmApiPing_FormatHttpError") ? LlmApiPing_FormatHttpError(r, "kimi") : r["error"])
            return Map("ok", !!r["ok"], "error", err, "elapsedMs", A_TickCount - t0)
        }
    }
    pingAnth := Jxon_Dump(Map("model", model, "max_tokens", 8, "messages", [Map("role", "user", "content", "ping")]))
    pingOpenAI := Jxon_Dump(Map("model", model, "messages", [Map("role", "user", "content", "ping")], "max_tokens", 8))
    if (prov = "claude") {
        r := ConfigWebView_LlmHttpSync("POST", ConfigWebView_ClaudeMessagesUrl(base), Map(
            "Content-Type", "application/json",
            "x-api-key", key,
            "anthropic-version", "2023-06-01"
        ), pingAnth, timeoutMs)
        return Map("ok", !!r["ok"], "error", r["ok"] ? "" : r["error"], "elapsedMs", A_TickCount - t0)
    }
    if (prov = "gemini") {
        r := ConfigWebView_LlmHttpSync("POST", ConfigWebView_GeminiGenerateUrl(base, model, key), Map("Content-Type", "application/json"),
            Jxon_Dump(Map("contents", [Map("role", "user", "parts", [Map("text", "ping")])], "generationConfig", Map("maxOutputTokens", 8))), timeoutMs)
        return Map("ok", !!r["ok"], "error", r["ok"] ? "" : r["error"], "elapsedMs", A_TickCount - t0)
    }
    headers := Map("Content-Type", "application/json")
    if (key != "")
        headers["Authorization"] := "Bearer " . key
    r := ConfigWebView_LlmHttpSync("POST", ConfigWebView_OpenAIChatUrl(base), headers, pingOpenAI, timeoutMs)
    return Map("ok", !!r["ok"], "error", r["ok"] ? "" : r["error"], "elapsedMs", A_TickCount - t0)
}
