; Diagnostics: SearchCenter 联网 WebView2 多标签探针（Safari 式切换，共享 Environment）
#Requires AutoHotkey v2.0

global g_SCWebProbe_On := false
global g_SCWebProbe_Gui := 0
global g_SCWebProbe_Ctrl := 0
global g_SCWebProbe_WV2 := 0
global g_SCWebProbe_Ready := false
global g_SCWebProbe_StatusText := 0
global g_SCWebProbe_LastUrl := ""
global g_SCWebProbe_LastEngine := ""
global g_SCWebProbe_LastNavOk := false
global g_SCWebProbe_LastNavError := ""
global g_SCWebProbe_LastNavMs := 0
global g_SCWebProbe_NavWait := 0
global g_SCWebProbe_Tabs := Map()
global g_SCWebProbe_TabButtons := Map()
global g_SCWebProbe_ActiveTabId := ""
global g_SCWebProbe_ChromeH := 58

ScWebEmbedProbePaths(*) {
    root := FuncExists("Nmer_InstallRoot") ? Nmer_InstallRoot() : A_ScriptDir
    dbg := root . "\Cache\debug"
    if !DirExist(dbg)
        DirCreate(dbg)
    return Map(
        "req", dbg . "\sc_web_embed_probe.json",
        "res", dbg . "\sc_web_embed_probe_result.json",
        "log", dbg . "\sc_web_embed_probe.log"
    )
}

ScWebEmbedProbeLog(line) {
    paths := ScWebEmbedProbePaths()
    try FileAppend("[" . A_Now . "] " . String(line) . "`n", paths["log"], "UTF-8")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

ScWebEmbedProbeEnsure(*) {
    global g_SCWebProbe_On
    if g_SCWebProbe_On
        return
    g_SCWebProbe_On := true
    SetTimer(ScWebEmbedProbePoll, 400)
    ScWebEmbedProbeLog("probe_timer_on")
}

ScWebEmbedProbeWriteResult(id, ok, pass, code, detail := "", extra := 0) {
    paths := ScWebEmbedProbePaths()
    body := Map(
        "id", String(id),
        "ok", !!ok,
        "pass", !!pass,
        "code", String(code),
        "detail", String(detail),
        "finishedAt", A_Now
    )
    if (extra is Map) {
        for k, v in extra
            body[String(k)] := v
    }
    try {
        if FileExist(paths["req"])
            FileDelete(paths["req"])
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try {
        if FileExist(paths["res"])
            FileDelete(paths["res"])
        f := FileOpen(paths["res"], "w", "UTF-8-RAW")
        if IsObject(f) {
            f.Write(Jxon_Dump(body))
            f.Close()
        }
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

ScWebEmbedProbeTabCatalog() {
    return [
        Map("id", "deepseek", "label", "DeepSeek", "engine", "deepseek"),
        Map("id", "doubao", "label", "豆包", "engine", "doubao"),
        Map("id", "yuanbao", "label", "元宝", "engine", "yuanbao"),
        Map("id", "gemini", "label", "Gemini", "engine", "gemini"),
        Map("id", "google", "label", "Google", "engine", "google"),
        Map("id", "youtube", "label", "YouTube", "engine", "youtube")
    ]
}

ScWebEmbedProbeEngines() {
    out := []
    for tab in ScWebEmbedProbeTabCatalog()
        out.Push(tab["engine"])
    return out
}

ScWebEmbedProbeResolveTabId(engineOrId) {
    key := StrLower(Trim(String(engineOrId)))
    if (key = "")
        return ""
    for tab in ScWebEmbedProbeTabCatalog() {
        if (StrLower(tab["id"]) = key || StrLower(tab["engine"]) = key)
            return tab["id"]
    }
    return key
}

ScWebEmbedProbeEnsureTabRecord(tabId) {
    global g_SCWebProbe_Tabs
    id := Trim(String(tabId))
    if (id = "")
        return 0
    if !g_SCWebProbe_Tabs.Has(id)
        g_SCWebProbe_Tabs[id] := Map(
            "id", id,
            "hostGui", 0,
            "hostHwnd", 0,
            "ctrl", 0,
            "wv2", 0,
            "ready", false,
            "createInFlight", false,
            "lastUrl", "",
            "lastNavOk", false,
            "lastNavError", ""
        )
    return g_SCWebProbe_Tabs[id]
}

ScWebEmbedProbeCreateChildHost(parentHwnd) {
    if !parentHwnd
        return 0
    try {
        g := Gui("-Caption -SysMenu +E0x08000000", "")
        g.BackColor := "1b1b1d"
        g.Show("Hide w400 h400")
        hwnd := g.Hwnd
        style := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -16, "Ptr")
        style := (style | 0x40000000 | 0x10000000) & ~0x80000000
        DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -16, "Ptr", style, "Ptr")
        if !DllCall("SetParent", "Ptr", hwnd, "Ptr", parentHwnd, "Ptr") {
            try g.Destroy()
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
            return 0
        }
        return Map("gui", g, "hwnd", hwnd)
    } catch {
        return 0
    }
}

ScWebEmbedProbePositionChildHost(hostHwnd, x, y, w, h, show := true) {
    if !hostHwnd
        return
    flags := 0x0010 | 0x0004
    if (show && w > 0 && h > 0)
        flags |= 0x0040
    else {
        flags |= 0x0080
        h := 0
    }
    try DllCall("SetWindowPos", "Ptr", hostHwnd, "Ptr", 0, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", flags)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

ScWebEmbedProbeDestroyTabHost(tab) {
    if !(tab is Map)
        return
    if tab.Has("ctrl") && IsObject(tab["ctrl"]) {
        try tab["ctrl"].Close()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    tab["ctrl"] := 0
    tab["wv2"] := 0
    tab["ready"] := false
    tab["createInFlight"] := false
    if tab.Has("hostGui") && IsObject(tab["hostGui"]) {
        try tab["hostGui"].Destroy()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    tab["hostGui"] := 0
    tab["hostHwnd"] := 0
}

ScWebEmbedProbeEnsureTabHost(tabId) {
    global g_SCWebProbe_Gui
    tab := ScWebEmbedProbeEnsureTabRecord(tabId)
    if !(tab is Map) || !IsObject(g_SCWebProbe_Gui)
        return 0
    if tab.Has("hostHwnd") && tab["hostHwnd"]
        return tab["hostHwnd"]
    created := ScWebEmbedProbeCreateChildHost(g_SCWebProbe_Gui.Hwnd)
    if !(created is Map) || !created.Has("hwnd") || !created["hwnd"]
        return 0
    tab["hostGui"] := created["gui"]
    tab["hostHwnd"] := created["hwnd"]
    return tab["hostHwnd"]
}

ScWebEmbedProbeTabDefaultUrl(tabId) {
    id := ScWebEmbedProbeResolveTabId(tabId)
    for tab in ScWebEmbedProbeTabCatalog() {
        if (tab["id"] = id)
            return ScWebEmbedProbeBuildUrl(tab["engine"], "")
    }
    return ""
}

ScWebEmbedProbeEnsureTabHome(tabId) {
    tab := ScWebEmbedProbeGetTab(tabId)
    if !(tab is Map) || !tab.Has("ready") || !tab["ready"] || !IsObject(tab["wv2"])
        return false
    url := tab.Has("lastUrl") ? Trim(String(tab["lastUrl"])) : ""
    if (url != "" && url != "about:blank")
        return true
    home := ScWebEmbedProbeTabDefaultUrl(tabId)
    if (home = "")
        return false
    try tab["wv2"].Navigate(home)
    catch {
        return false
    }
    tab["lastUrl"] := home
    return true
}

ScWebEmbedProbeGetTab(tabId) {
    id := Trim(String(tabId))
    if (id = "")
        return 0
    global g_SCWebProbe_Tabs
    if !g_SCWebProbe_Tabs.Has(id)
        return 0
    return g_SCWebProbe_Tabs[id]
}

ScWebEmbedProbeSyncActiveGlobals() {
    global g_SCWebProbe_ActiveTabId, g_SCWebProbe_Ctrl, g_SCWebProbe_WV2, g_SCWebProbe_Ready
    tab := ScWebEmbedProbeGetTab(g_SCWebProbe_ActiveTabId)
    if tab is Map && tab.Has("ready") && tab["ready"] {
        g_SCWebProbe_Ctrl := tab.Has("ctrl") ? tab["ctrl"] : 0
        g_SCWebProbe_WV2 := tab.Has("wv2") ? tab["wv2"] : 0
        g_SCWebProbe_Ready := true
        g_SCWebProbe_LastUrl := tab.Has("lastUrl") ? String(tab["lastUrl"]) : ""
        g_SCWebProbe_LastNavOk := tab.Has("lastNavOk") ? !!tab["lastNavOk"] : false
        g_SCWebProbe_LastNavError := tab.Has("lastNavError") ? String(tab["lastNavError"]) : ""
    } else {
        g_SCWebProbe_Ctrl := 0
        g_SCWebProbe_WV2 := 0
        g_SCWebProbe_Ready := false
    }
}

ScWebEmbedProbeEncodeQuery(query) {
    q := Trim(String(query))
    if (q = "")
        q := "牛马搜索探针"
    if FuncExists("UriEncode") {
        try return UriEncode(q)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    return q
}

ScWebEmbedProbeBuildUrl(engine, query := "") {
    eng := StrLower(Trim(String(engine)))
    if (eng = "")
        return ""
    if FuncExists("VoiceInputEffect_BuildSearchUrl") {
        try {
            u := VoiceInputEffect_BuildSearchUrl(String(query), eng)
            if (u != "")
                return u
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    enc := ScWebEmbedProbeEncodeQuery(query)
    switch eng {
        case "deepseek":
            return "https://chat.deepseek.com/?q=" . enc
        case "doubao":
            return "https://www.doubao.com/chat/?q=" . enc
        case "yuanbao":
            return "https://yuanbao.tencent.com/?q=" . enc
        case "gemini":
            return "https://gemini.google.com/app"
        case "google":
            return "https://www.google.com/search?q=" . enc
        case "youtube":
            return "https://www.youtube.com/results?search_query=" . enc
        default:
            return ""
    }
}

ScWebEmbedProbeSetStatus(text) {
    global g_SCWebProbe_StatusText
    msg := String(text)
    if IsObject(g_SCWebProbe_StatusText) {
        try g_SCWebProbe_StatusText.Value := msg
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    ScWebEmbedProbeLog(msg)
}

ScWebEmbedProbeRefreshTabButtons() {
    global g_SCWebProbe_TabButtons, g_SCWebProbe_ActiveTabId
    for id, btn in g_SCWebProbe_TabButtons {
        try {
            if (id = g_SCWebProbe_ActiveTabId)
                btn.Opt("+Default")
            else
                btn.Opt("-Default")
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
}

ScWebEmbedProbeBuildTabBar() {
    global g_SCWebProbe_Gui, g_SCWebProbe_TabButtons
    if !IsObject(g_SCWebProbe_Gui)
        return
    for _, btn in g_SCWebProbe_TabButtons {
        try btn.Destroy()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    g_SCWebProbe_TabButtons := Map()
    x := 6
    for tab in ScWebEmbedProbeTabCatalog() {
        tid := tab["id"]
        lbl := tab["label"]
        btn := g_SCWebProbe_Gui.Add("Button", "x" . x . " y26 w92 h26 vTab_" . tid, lbl)
        btn.OnEvent("Click", ScWebEmbedProbeMakeTabClickHandler(tid))
        g_SCWebProbe_TabButtons[tid] := btn
        ScWebEmbedProbeEnsureTabRecord(tid)
        x += 96
    }
    ScWebEmbedProbeRefreshTabButtons()
}

ScWebEmbedProbeMakeTabClickHandler(tabId) {
    return (*) => ScWebEmbedProbeSwitchTab(tabId)
}

ScWebEmbedProbeApplyBounds() {
    global g_SCWebProbe_Gui, g_SCWebProbe_Tabs, g_SCWebProbe_ActiveTabId, g_SCWebProbe_ChromeH, WebView2
    if !IsObject(g_SCWebProbe_Gui)
        return false
    try {
        g_SCWebProbe_Gui.GetClientPos(, , &cw, &ch)
    } catch {
        return false
    }
    if (cw < 240 || ch < 180)
        return false
    top := Integer(g_SCWebProbe_ChromeH)
    bodyW := cw
    bodyH := Max(0, ch - top)
    for id, tab in g_SCWebProbe_Tabs {
        if !(tab is Map) || !tab.Has("hostHwnd") || !tab["hostHwnd"]
            continue
        show := (id = g_SCWebProbe_ActiveTabId)
        ScWebEmbedProbePositionChildHost(tab["hostHwnd"], 0, top, bodyW, bodyH, show)
        if show && tab.Has("ctrl") && IsObject(tab["ctrl"]) {
            rc := WebView2.RECT()
            rc.left := 0
            rc.top := 0
            rc.right := bodyW
            rc.bottom := bodyH
            try tab["ctrl"].Bounds := rc
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
            try tab["ctrl"].IsVisible := true
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        }
    }
    return true
}

ScWebEmbedProbeOnGuiSize(guiObj, minMax, width, height, *) {
    if (minMax = -1)
        return
    ScWebEmbedProbeApplyBounds()
}

ScWebEmbedProbeOnGuiClose(*) {
    ScWebEmbedProbeHide()
}

ScWebEmbedProbeHideTabWebViews(exceptId := "") {
    global g_SCWebProbe_Gui, g_SCWebProbe_Tabs, g_SCWebProbe_ChromeH
    if !IsObject(g_SCWebProbe_Gui)
        return
    try {
        g_SCWebProbe_Gui.GetClientPos(, , &cw, &ch)
    } catch {
        return
    }
    top := Integer(g_SCWebProbe_ChromeH)
    bodyW := cw
    bodyH := Max(0, ch - top)
    for id, tab in g_SCWebProbe_Tabs {
        if (id = exceptId)
            continue
        if !(tab is Map)
            continue
        if tab.Has("hostHwnd") && tab["hostHwnd"]
            ScWebEmbedProbePositionChildHost(tab["hostHwnd"], 0, top, bodyW, bodyH, false)
        if tab.Has("wv2") && IsObject(tab["wv2"]) && FuncExists("WebView2_NotifyHidden") {
            try WebView2_NotifyHidden(tab["wv2"])
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        }
    }
}

ScWebEmbedProbeOnTabNavCompleted(tabId, sender, args) {
    global g_SCWebProbe_NavWait, g_SCWebProbe_LastNavMs
    tab := ScWebEmbedProbeGetTab(tabId)
    if !(tab is Map)
        return
    wv2 := tab.Has("wv2") ? tab["wv2"] : 0
    if !IsObject(wv2)
        return
    url := ""
    try url := wv2.Source
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if (url = "")
        try url := wv2.SourceUri
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    tab["lastUrl"] := String(url)
    ok := true
    err := ""
    try {
        if IsObject(args) && args.HasProp("IsSuccess") && !args.IsSuccess {
            ok := false
            try err := String(args.WebErrorStatus)
            catch {
                err := "navigation_failed"
            }
        }
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    tab["lastNavOk"] := ok
    tab["lastNavError"] := err
    global g_SCWebProbe_ActiveTabId
    if (tabId = g_SCWebProbe_ActiveTabId) {
        global g_SCWebProbe_LastUrl, g_SCWebProbe_LastNavOk, g_SCWebProbe_LastNavError
        g_SCWebProbe_LastUrl := tab["lastUrl"]
        g_SCWebProbe_LastNavOk := ok
        g_SCWebProbe_LastNavError := err
        if (g_SCWebProbe_NavWait is Map) {
            g_SCWebProbe_NavWait["completed"] := true
            g_SCWebProbe_NavWait["ok"] := ok
            g_SCWebProbe_NavWait["error"] := err
            g_SCWebProbe_NavWait["url"] := g_SCWebProbe_LastUrl
            if g_SCWebProbe_NavWait.Has("startTick")
                g_SCWebProbe_LastNavMs := Max(0, A_TickCount - Integer(g_SCWebProbe_NavWait["startTick"]))
        }
        ScWebEmbedProbeSetStatus((ok ? "导航完成: " : "导航失败: ") . g_SCWebProbe_LastUrl)
    }
}

ScWebEmbedProbeMakeNavCompletedHandler(tabId) {
    return (sender, args) => ScWebEmbedProbeOnTabNavCompleted(tabId, sender, args)
}

ScWebEmbedProbeOnTabCreated(tabId, ctrl) {
    tab := ScWebEmbedProbeGetTab(tabId)
    if !(tab is Map) {
        tab := ScWebEmbedProbeEnsureTabRecord(tabId)
        if !(tab is Map)
            return
    }
    tab["createInFlight"] := false
    if !IsObject(ctrl) || !ctrl.HasProp("CoreWebView2") {
        ScWebEmbedProbeSetStatus("WebView2 创建失败: " . tabId)
        ScWebEmbedProbeLog("create_failed tab=" . tabId . " type=" . Type(ctrl))
        return
    }
    tab["ctrl"] := ctrl
    tab["wv2"] := ctrl.CoreWebView2
    tab["ready"] := true
    try ctrl.DefaultBackgroundColor := 0xFF1B1B1D
    try {
        s := tab["wv2"].Settings
        s.AreDefaultContextMenusEnabled := true
        s.AreDevToolsEnabled := true
        s.AreBrowserAcceleratorKeysEnabled := true
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if FuncExists("ApplyWebView2PerformanceSettings")
        try ApplyWebView2PerformanceSettings(tab["wv2"])
    try tab["wv2"].add_NavigationCompleted(ScWebEmbedProbeMakeNavCompletedHandler(tabId))
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    global g_SCWebProbe_ActiveTabId
    if (tabId = g_SCWebProbe_ActiveTabId) {
        try ctrl.IsVisible := true
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        ScWebEmbedProbeApplyBounds()
        if FuncExists("WebView2_NotifyShown") && IsObject(tab["wv2"])
            try WebView2_NotifyShown(tab["wv2"])
        ScWebEmbedProbeSyncActiveGlobals()
        ScWebEmbedProbeSetStatus("标签就绪: " . tabId)
        ScWebEmbedProbeEnsureTabHome(tabId)
    } else {
        if tab.Has("hostHwnd") && tab["hostHwnd"]
            ScWebEmbedProbePositionChildHost(tab["hostHwnd"], 0, 0, 0, 0, false)
        if FuncExists("WebView2_NotifyHidden") && IsObject(tab["wv2"])
            try WebView2_NotifyHidden(tab["wv2"])
    }
}

ScWebEmbedProbeMakeCreatedHandler(tabId) {
    return (ctrl) => ScWebEmbedProbeOnTabCreated(tabId, ctrl)
}

ScWebEmbedProbeStartCreateTab(tabId) {
    global g_SCWebProbe_Gui
    id := Trim(String(tabId))
    if (id = "" || !IsObject(g_SCWebProbe_Gui))
        return false
    tab := ScWebEmbedProbeEnsureTabRecord(id)
    if !(tab is Map)
        return false
    if tab.Has("ready") && tab["ready"]
        return true
    hostHwnd := ScWebEmbedProbeEnsureTabHost(id)
    if !hostHwnd
        return false
    if tab.Has("createInFlight") && tab["createInFlight"]
        return ScWebEmbedProbeWaitTabReady(id, 45000)
    if !FuncExists("WebView2_CreateWithSharedEnvAsync") {
        ScWebEmbedProbeSetStatus("缺少 WebView2_CreateWithSharedEnvAsync")
        return false
    }
    tab["createInFlight"] := true
    WebView2_CreateWithSharedEnvAsync(hostHwnd, ScWebEmbedProbeMakeCreatedHandler(id), "sc_web_probe_" . id)
    return ScWebEmbedProbeWaitTabReady(id, 45000)
}

ScWebEmbedProbeWaitTabReady(tabId, timeoutMs := 30000) {
    deadline := A_TickCount + Max(1000, Integer(timeoutMs))
    while (A_TickCount < deadline) {
        tab := ScWebEmbedProbeGetTab(tabId)
        if tab is Map && tab.Has("ready") && tab["ready"] && IsObject(tab["wv2"])
            return true
        Sleep(80)
    }
    tab := ScWebEmbedProbeGetTab(tabId)
    return (tab is Map && tab.Has("ready") && tab["ready"] && IsObject(tab["wv2"]))
}

ScWebEmbedProbeSwitchTab(tabId) {
    global g_SCWebProbe_ActiveTabId, g_SCWebProbe_Gui
    id := ScWebEmbedProbeResolveTabId(tabId)
    if (id = "")
        return false
    if !IsObject(g_SCWebProbe_Gui)
        return false
    prevId := g_SCWebProbe_ActiveTabId
    if (prevId != "" && prevId != id)
        ScWebEmbedProbeHideTabWebViews("")
    g_SCWebProbe_ActiveTabId := id
    ScWebEmbedProbeRefreshTabButtons()
    if !ScWebEmbedProbeStartCreateTab(id)
        return false
    tab := ScWebEmbedProbeGetTab(id)
    if !(tab is Map) || !IsObject(tab["ctrl"])
        return false
    ScWebEmbedProbeHideTabWebViews(id)
    ScWebEmbedProbeApplyBounds()
    if FuncExists("WebView2_NotifyShown") && IsObject(tab["wv2"])
        try WebView2_NotifyShown(tab["wv2"])
    ScWebEmbedProbeSyncActiveGlobals()
    ScWebEmbedProbeEnsureTabHome(id)
    ScWebEmbedProbeSetStatus("切换标签: " . id)
    return true
}

ScWebEmbedProbeEnsureHost() {
    global g_SCWebProbe_Gui, g_SCWebProbe_ActiveTabId
    if IsObject(g_SCWebProbe_Gui) {
        if (g_SCWebProbe_ActiveTabId = "") {
            catalog := ScWebEmbedProbeTabCatalog()
            if catalog.Length
                ScWebEmbedProbeSwitchTab(catalog[1]["id"])
        }
        return true
    }
    g_SCWebProbe_Gui := Gui("+Resize +MinSize640x480 -DPIScale", "SC 联网探针 · 多标签")
    g_SCWebProbe_Gui.BackColor := "1b1b1d"
    g_SCWebProbe_Gui.MarginX := 0
    g_SCWebProbe_Gui.MarginY := 0
    g_SCWebProbe_Gui.OnEvent("Close", ScWebEmbedProbeOnGuiClose)
    g_SCWebProbe_Gui.OnEvent("Size", ScWebEmbedProbeOnGuiSize)
    g_SCWebProbe_StatusText := g_SCWebProbe_Gui.Add("Text", "x6 y4 w1160 h20 cFFFFFF BackgroundTrans", "探针初始化…")
    ScWebEmbedProbeBuildTabBar()
    g_SCWebProbe_Gui.Show("w1180 h760")
    try {
        if FuncExists("Nmer_MoveGuiToPopupScreen")
            Nmer_MoveGuiToPopupScreen(g_SCWebProbe_Gui)
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    catalog := ScWebEmbedProbeTabCatalog()
    if catalog.Length
        ScWebEmbedProbeSwitchTab(catalog[1]["id"])
    return true
}

ScWebEmbedProbeWaitReady(timeoutMs := 30000) {
    global g_SCWebProbe_ActiveTabId
    if (g_SCWebProbe_ActiveTabId = "") {
        catalog := ScWebEmbedProbeTabCatalog()
        if catalog.Length
            g_SCWebProbe_ActiveTabId := catalog[1]["id"]
    }
    return ScWebEmbedProbeWaitTabReady(g_SCWebProbe_ActiveTabId, timeoutMs)
}

ScWebEmbedProbeShow() {
    if !ScWebEmbedProbeEnsureHost()
        return false
    global g_SCWebProbe_Gui
    try g_SCWebProbe_Gui.Show()
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    ScWebEmbedProbeApplyBounds()
    ScWebEmbedProbeSyncActiveGlobals()
    if FuncExists("WebView2_NotifyShown") && IsObject(g_SCWebProbe_WV2)
        try WebView2_NotifyShown(g_SCWebProbe_WV2)
    try WinActivate("ahk_id " . g_SCWebProbe_Gui.Hwnd)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return true
}

ScWebEmbedProbeHide() {
    global g_SCWebProbe_Gui
    ScWebEmbedProbeHideTabWebViews("")
    if IsObject(g_SCWebProbe_Gui) {
        try g_SCWebProbe_Gui.Hide()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
}

ScWebEmbedProbeDispose() {
    global g_SCWebProbe_Gui, g_SCWebProbe_Tabs, g_SCWebProbe_TabButtons
    global g_SCWebProbe_Ctrl, g_SCWebProbe_WV2, g_SCWebProbe_Ready, g_SCWebProbe_StatusText
    global g_SCWebProbe_NavWait, g_SCWebProbe_ActiveTabId
    g_SCWebProbe_NavWait := 0
    for id, tab in g_SCWebProbe_Tabs {
        ScWebEmbedProbeDestroyTabHost(tab)
    }
    g_SCWebProbe_Tabs := Map()
    g_SCWebProbe_ActiveTabId := ""
    g_SCWebProbe_Ctrl := 0
    g_SCWebProbe_WV2 := 0
    g_SCWebProbe_Ready := false
    g_SCWebProbe_StatusText := 0
    for _, btn in g_SCWebProbe_TabButtons {
        try btn.Destroy()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    g_SCWebProbe_TabButtons := Map()
    if IsObject(g_SCWebProbe_Gui) {
        try g_SCWebProbe_Gui.Destroy()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    g_SCWebProbe_Gui := 0
}

ScWebEmbedProbeNavigateActiveUrl(url, waitMs := 0) {
    global g_SCWebProbe_WV2, g_SCWebProbe_NavWait, g_SCWebProbe_ActiveTabId
    u := Trim(String(url))
    if (u = "")
        return Map("ok", false, "code", "URL_EMPTY", "url", "")
    if !ScWebEmbedProbeEnsureHost()
        return Map("ok", false, "code", "HOST_NOT_READY", "url", u)
    if (g_SCWebProbe_ActiveTabId = "")
        return Map("ok", false, "code", "NO_ACTIVE_TAB", "url", u)
    if !ScWebEmbedProbeWaitTabReady(g_SCWebProbe_ActiveTabId, 45000)
        return Map("ok", false, "code", "TAB_NOT_READY", "url", u)
    ScWebEmbedProbeSyncActiveGlobals()
    if !IsObject(g_SCWebProbe_WV2)
        return Map("ok", false, "code", "WV2_MISSING", "url", u)
    g_SCWebProbe_NavWait := Map(
        "completed", false,
        "ok", false,
        "error", "",
        "url", "",
        "startTick", A_TickCount,
        "tabId", g_SCWebProbe_ActiveTabId
    )
    try g_SCWebProbe_WV2.Navigate(u)
    catch as e {
        g_SCWebProbe_NavWait := 0
        return Map("ok", false, "code", "NAVIGATE_THROW", "url", u, "error", e.Message)
    }
    wm := Max(0, Integer(waitMs))
    if (wm > 0)
        ScWebEmbedProbeWaitNavigation(wm)
    st := ScWebEmbedProbeStatusMap("navigate")
    st["targetUrl"] := u
    st["tabId"] := g_SCWebProbe_ActiveTabId
    st["timedOut"] := (g_SCWebProbe_NavWait is Map) && !g_SCWebProbe_NavWait["completed"]
    loaded := (st["url"] != "" && st["url"] != "about:blank")
    st["ok"] := st["navOk"] || (loaded && !st["timedOut"])
    st["code"] := st["ok"] ? "NAV_OK" : (st["timedOut"] ? "NAV_TIMEOUT" : "NAV_FAIL")
    return st
}

ScWebEmbedProbeNavigateUrl(url, waitMs := 0) {
    return ScWebEmbedProbeNavigateActiveUrl(url, waitMs)
}

ScWebEmbedProbeNavigateEngine(engine, query := "", waitMs := 0) {
    eng := StrLower(Trim(String(engine)))
    tabId := ScWebEmbedProbeResolveTabId(eng)
    if (tabId = "")
        return Map("ok", false, "code", "UNKNOWN_ENGINE", "engine", eng, "url", "")
    if !ScWebEmbedProbeEnsureHost()
        return Map("ok", false, "code", "HOST_NOT_READY", "engine", eng, "url", "")
    ScWebEmbedProbeShow()
    ScWebEmbedProbeSwitchTab(tabId)
    url := ScWebEmbedProbeBuildUrl(eng, query)
    if (url = "")
        return Map("ok", false, "code", "URL_BUILD_FAIL", "engine", eng, "url", "")
    global g_SCWebProbe_LastEngine
    g_SCWebProbe_LastEngine := eng
    out := ScWebEmbedProbeNavigateActiveUrl(url, waitMs)
    out["engine"] := eng
    out["query"] := Trim(String(query))
    out["targetUrl"] := url
    out["tabId"] := tabId
    return out
}

ScWebEmbedProbeWaitNavigation(timeoutMs := 12000) {
    global g_SCWebProbe_NavWait
    deadline := A_TickCount + Max(500, Integer(timeoutMs))
    while (A_TickCount < deadline) {
        if !(g_SCWebProbe_NavWait is Map)
            break
        if g_SCWebProbe_NavWait["completed"]
            break
        Sleep(60)
    }
}

ScWebEmbedProbeStatusMap(tag := "") {
    global g_SCWebProbe_Ready, g_SCWebProbe_WV2, g_SCWebProbe_LastUrl, g_SCWebProbe_LastEngine
    global g_SCWebProbe_LastNavOk, g_SCWebProbe_LastNavError, g_SCWebProbe_LastNavMs, g_SCWebProbe_Gui
    global g_SCWebProbe_ActiveTabId, g_SCWebProbe_Tabs
    ScWebEmbedProbeSyncActiveGlobals()
    visible := false
    hwnd := 0
    if IsObject(g_SCWebProbe_Gui) {
        try hwnd := g_SCWebProbe_Gui.Hwnd
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        try visible := g_SCWebProbe_Gui.Visible
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    title := ""
    if (hwnd && WinExist("ahk_id " . hwnd))
        try title := WinGetTitle("ahk_id " . hwnd)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    tabCount := 0
    readyTabs := 0
    for _, tab in g_SCWebProbe_Tabs {
        tabCount++
        if tab is Map && tab.Has("ready") && tab["ready"]
            readyTabs++
    }
    return Map(
        "tag", String(tag),
        "ready", !!g_SCWebProbe_Ready,
        "visible", !!visible,
        "hwnd", hwnd,
        "title", title,
        "engine", String(g_SCWebProbe_LastEngine),
        "activeTab", String(g_SCWebProbe_ActiveTabId),
        "tabCount", tabCount,
        "readyTabs", readyTabs,
        "url", String(g_SCWebProbe_LastUrl),
        "navOk", !!g_SCWebProbe_LastNavOk,
        "navError", String(g_SCWebProbe_LastNavError),
        "navMs", Integer(g_SCWebProbe_LastNavMs),
        "wv2", IsObject(g_SCWebProbe_WV2)
    )
}

ScWebEmbedProbePrepareForScriptReload() {
    ScWebEmbedProbeDispose()
}

ScWebEmbedProbePoll(*) {
    paths := ScWebEmbedProbePaths()
    reqPath := paths["req"]
    if !FileExist(reqPath)
        return
    raw := ""
    try raw := FileRead(reqPath, "UTF-8")
    catch as errRead {
        ScWebEmbedProbeLog("read_fail " . errRead.Message)
        return
    }
    if (SubStr(raw, 1, 1) = Chr(0xFEFF))
        raw := SubStr(raw, 2)
    raw := Trim(raw)
    if (raw = "" || StrLen(raw) > 65536) {
        ScWebEmbedProbeWriteResult("", false, false, "PROBE_JSON_INVALID", "empty_or_oversize")
        try FileDelete(reqPath)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        return
    }
    root := Map()
    try root := Jxon_Load(raw)
    catch as errJson {
        ScWebEmbedProbeWriteResult("", false, false, "PROBE_JSON_INVALID", SubStr(String(errJson.Message), 1, 120))
        try FileDelete(reqPath)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        return
    }
    if !(root is Map) {
        ScWebEmbedProbeWriteResult("", false, false, "PROBE_JSON_INVALID", "expected_object")
        try FileDelete(reqPath)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        return
    }
    id := root.Has("id") ? String(root["id"]) : ""
    action := root.Has("action") ? StrLower(Trim(String(root["action"]))) : ""
    engine := root.Has("engine") ? String(root["engine"]) : ""
    query := root.Has("query") ? String(root["query"]) : ""
    waitMs := root.Has("waitMs") ? Integer(root["waitMs"]) : 0
    url := root.Has("url") ? String(root["url"]) : ""
    tabId := root.Has("tabId") ? String(root["tabId"]) : (root.Has("tab") ? String(root["tab"]) : "")

    switch action {
        case "ping":
            ScWebEmbedProbeWriteResult(id, true, true, "PING_OK", "sc_web_embed_probe_ipc_active")
        case "open":
            ok := ScWebEmbedProbeShow()
            ScWebEmbedProbeWriteResult(id, ok, ok, ok ? "PROBE_OPEN" : "PROBE_OPEN_FAIL", "show", ScWebEmbedProbeStatusMap("open"))
        case "switchtab":
            tid := ScWebEmbedProbeResolveTabId(tabId != "" ? tabId : engine)
            ok := ScWebEmbedProbeEnsureHost() && ScWebEmbedProbeSwitchTab(tid)
            ScWebEmbedProbeWriteResult(id, ok, ok, ok ? "TAB_SWITCH_OK" : "TAB_SWITCH_FAIL", tid, ScWebEmbedProbeStatusMap("switchtab"))
        case "navigate":
            if (url != "")
                nav := ScWebEmbedProbeNavigateUrl(url, waitMs)
            else
                nav := ScWebEmbedProbeNavigateEngine(engine, query, waitMs)
            if !(nav is Map)
                nav := Map("ok", false, "code", "NAV_MAP_INVALID")
            ok := nav.Has("ok") && nav["ok"]
            code := nav.Has("code") ? String(nav["code"]) : (ok ? "NAV_OK" : "NAV_FAIL")
            ScWebEmbedProbeWriteResult(id, true, ok, code, "engine=" . engine, nav)
        case "blank":
            nav := ScWebEmbedProbeNavigateUrl("about:blank", waitMs > 0 ? waitMs : 1500)
            ScWebEmbedProbeWriteResult(id, true, true, "BLANK_OK", "about:blank", nav)
        case "status":
            ScWebEmbedProbeWriteResult(id, true, true, "STATUS_OK", "status", ScWebEmbedProbeStatusMap("status"))
        case "close":
            ScWebEmbedProbeHide()
            ScWebEmbedProbeWriteResult(id, true, true, "PROBE_CLOSED", "hidden", ScWebEmbedProbeStatusMap("close"))
        case "dispose":
            ScWebEmbedProbeDispose()
            ScWebEmbedProbeWriteResult(id, true, true, "PROBE_DISPOSED", "disposed", ScWebEmbedProbeStatusMap("dispose"))
        default:
            ScWebEmbedProbeWriteResult(id, false, false, "PROBE_UNKNOWN_ACTION", action)
    }
}
