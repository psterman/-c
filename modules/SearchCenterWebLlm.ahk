; SearchCenterWebLlm.ahk — 搜索中心「网页大模型」子 GUI WebView2 叠层
#Requires AutoHotkey v2.0
;@reference SearchCenterWebLlm.d.ahk

#Include FuncExists.ahk
#Include SearchCenterWebLlmSites.ahk

global g_SCWebLlm_ParentHwnd := 0
global g_SCWebLlm_Visible := false
global g_SCWebLlm_ContentGui := 0
global g_SCWebLlm_ContentHostHwnd := 0
global g_SCWebLlm_Ctrl := 0
global g_SCWebLlm_WV2 := 0
global g_SCWebLlm_Env := 0
global g_SCWebLlm_ActiveSiteId := ""
global g_SCWebLlm_Ready := false
global g_SCWebLlm_CreateInFlight := false
global g_SCWebLlm_LastBoundsKey := ""
global g_SCWebLlm_ContentRect := Map("left", 0, "top", 220, "width", 800, "height", 500)
global g_SCWebLlm_TokenNavCompleted := 0
global g_SCWebLlm_StateCache := Map()

ScWebLlm_Catch(err) {
    if FuncExists("NmerCatch")
        try NmerCatch(A_ThisFunc, err)
}

ScWebLlm_Trace(action, ok := true, meta := 0) {
    fn := "Nmer_Telemetry_Record"
    if FuncExists(fn) {
        try {
            (%fn%)("web_llm", action, !!ok, meta is Map ? meta : Map())
            return
        } catch as e {
            ScWebLlm_Catch(e)
        }
    }
    try {
        if FuncExists("Nmer_DebugPath") {
            path := Nmer_DebugPath("nmer_trace.log")
            FileAppend("[" . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . "][web_llm][" . action . "] ok="
                . (ok ? "1" : "0") . "`n", path, "UTF-8")
        }
    } catch as e {
        ScWebLlm_Catch(e)
    }
}

ScWebLlm_StatePath() {
    if FuncExists("Nmer_ScWebLlmStatePath")
        return Nmer_ScWebLlmStatePath()
    return A_ScriptDir . "\Data\runtime\app\search_center_web_llm_state.json"
}

SearchCenterWebLlm_LoadState() {
    global g_SCWebLlm_StateCache
    path := ScWebLlm_StatePath()
    st := Map("activeSiteId", ScWebLlm_DefaultSiteId(), "sites", Map())
    if !FileExist(path)
        return st
    try {
        if FuncExists("Jxon_Load") {
            raw := FileRead(path, "UTF-8")
            if (Trim(raw) != "") {
                loaded := Jxon_Load(raw)
                if (loaded is Map) {
                    if loaded.Has("activeSiteId")
                        st["activeSiteId"] := ScWebLlm_NormalizeSiteId(loaded["activeSiteId"])
                    if loaded.Has("sites") && (loaded["sites"] is Map)
                        st["sites"] := loaded["sites"]
                }
            }
        }
    } catch as e {
        ScWebLlm_Catch(e)
    }
    if (st["activeSiteId"] = "")
        st["activeSiteId"] := ScWebLlm_DefaultSiteId()
    g_SCWebLlm_StateCache := st
    return st
}

SearchCenterWebLlm_SaveState() {
    global g_SCWebLlm_StateCache, g_SCWebLlm_ActiveSiteId, g_SCWebLlm_WV2
    st := (g_SCWebLlm_StateCache is Map) ? g_SCWebLlm_StateCache : Map()
    if !(st.Has("sites") && (st["sites"] is Map))
        st["sites"] := Map()
    sites := st["sites"]
    sid := Trim(String(g_SCWebLlm_ActiveSiteId))
    if (sid != "" && IsObject(g_SCWebLlm_WV2)) {
        try {
            url := Trim(String(g_SCWebLlm_WV2.Source))
            if (url != "")
                sites[sid] := Map("lastUrl", url)
        } catch {
        }
    }
    if (sid != "")
        st["activeSiteId"] := sid
    st["sites"] := sites
    g_SCWebLlm_StateCache := st
    path := ScWebLlm_StatePath()
    dir := ""
    if RegExMatch(path, "^(.*)\\[^\\]+$", &m)
        dir := m[1]
    if (dir != "" && !DirExist(dir))
        try DirCreate(dir)
    try {
        if FuncExists("Jxon_Dump") {
            json := Jxon_Dump(st)
            try FileDelete(path)
            FileAppend(json, path, "UTF-8")
            return true
        }
    } catch as e {
        ScWebLlm_Catch(e)
    }
    return false
}

SearchCenterWebLlm_SiteLastUrl(siteId) {
    st := SearchCenterWebLlm_LoadState()
    sites := st.Has("sites") && (st["sites"] is Map) ? st["sites"] : Map()
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "" || !sites.Has(sid))
        return ""
    row := sites[sid]
    if (row is Map) && row.Has("lastUrl")
        return Trim(String(row["lastUrl"]))
    return ""
}

SearchCenterWebLlm_CreateChildHostGui(parentHwnd, bgColor := "0A0A0A") {
    if !parentHwnd
        return 0
    try {
        g := Gui("-Caption -SysMenu +E0x08000000", "")
        g.BackColor := bgColor
        g.Show("Hide w400 h400")
        hwnd := g.Hwnd
        style := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -16, "Ptr")
        style := (style | 0x40000000 | 0x10000000) & ~0x80000000
        DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -16, "Ptr", style, "Ptr")
        if !DllCall("SetParent", "Ptr", hwnd, "Ptr", parentHwnd, "Ptr") {
            try g.Destroy()
            return 0
        }
        return Map("gui", g, "hwnd", hwnd)
    } catch {
        return 0
    }
}

SearchCenterWebLlm_PositionChildHost(hostHwnd, x, y, w, h, show := true) {
    if !hostHwnd
        return
    flags := 0x0010 | 0x0004
    if (show && w > 0 && h > 0)
        flags |= 0x0040
    else {
        flags |= 0x0080
        w := 0
        h := 0
    }
    try DllCall("SetWindowPos", "Ptr", hostHwnd, "Ptr", 0, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", flags)
    catch as e {
        ScWebLlm_Catch(e)
    }
}

SearchCenterWebLlm_EnsureContentHost(parentHwnd) {
    global g_SCWebLlm_ContentGui, g_SCWebLlm_ContentHostHwnd, g_SCWebLlm_ParentHwnd
    if g_SCWebLlm_ContentHostHwnd && g_SCWebLlm_ParentHwnd = parentHwnd
        return g_SCWebLlm_ContentHostHwnd
    if g_SCWebLlm_ContentGui {
        try g_SCWebLlm_ContentGui.Destroy()
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    g_SCWebLlm_ContentGui := 0
    g_SCWebLlm_ContentHostHwnd := 0
    created := SearchCenterWebLlm_CreateChildHostGui(parentHwnd)
    if !(created is Map) || !created.Has("hwnd") || !created["hwnd"]
        return 0
    g_SCWebLlm_ContentGui := created["gui"]
    g_SCWebLlm_ContentHostHwnd := created["hwnd"]
    g_SCWebLlm_ParentHwnd := parentHwnd
    return g_SCWebLlm_ContentHostHwnd
}

SearchCenterWebLlm_HostAlive() {
    global g_SCWebLlm_ParentHwnd
    return WebView2_IsUsableHwnd(g_SCWebLlm_ParentHwnd)
}

SearchCenterWebLlm_ControllerAlive() {
    global g_SCWebLlm_Ctrl, g_SCWebLlm_WV2
    return IsObject(g_SCWebLlm_Ctrl) && IsObject(g_SCWebLlm_WV2) && SearchCenterWebLlm_HostAlive()
}

SearchCenterWebLlm_DisposeActiveController() {
    global g_SCWebLlm_Ctrl, g_SCWebLlm_WV2, g_SCWebLlm_Env, g_SCWebLlm_Ready, g_SCWebLlm_TokenNavCompleted
    if IsObject(g_SCWebLlm_WV2) && g_SCWebLlm_TokenNavCompleted {
        try g_SCWebLlm_WV2.remove_NavigationCompleted(g_SCWebLlm_TokenNavCompleted)
        catch {
        }
    }
    g_SCWebLlm_TokenNavCompleted := 0
    if IsObject(g_SCWebLlm_WV2) {
        try WebView2_NotifyHidden(g_SCWebLlm_WV2)
        catch {
        }
    }
    if IsObject(g_SCWebLlm_Ctrl) {
        try g_SCWebLlm_Ctrl.IsVisible := false
        catch {
        }
        try g_SCWebLlm_Ctrl.Close()
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    g_SCWebLlm_Ctrl := 0
    g_SCWebLlm_WV2 := 0
    g_SCWebLlm_Env := 0
    g_SCWebLlm_Ready := false
}

SearchCenterWebLlm_OnNavigationCompleted(sender, args) {
    global g_SCWebLlm_ActiveSiteId
    ok := true
    try ok := args.IsSuccess
    catch {
    }
    if ok
        SearchCenterWebLlm_SaveState()
    else
        ScWebLlm_Trace("nav_fail", false, Map("site", g_SCWebLlm_ActiveSiteId))
    SearchCenterWebLlm_PushChromeState()
}

SearchCenterWebLlm_PushChromeState() {
    global g_SCWebLlm_WV2, g_SCWebLlm_Ctrl, g_SCWebLlm_ActiveSiteId
    if !SearchCenterWebLlm_ControllerAlive()
        return
    payload := Map(
        "type", "webLlmChromeState",
        "siteId", g_SCWebLlm_ActiveSiteId,
        "loading", false,
        "canGoBack", false,
        "canGoForward", false,
        "url", "",
        "title", ""
    )
    try payload["canGoBack"] := !!g_SCWebLlm_WV2.CanGoBack
    catch {
    }
    try payload["canGoForward"] := !!g_SCWebLlm_WV2.CanGoForward
    catch {
    }
    try payload["url"] := Trim(String(g_SCWebLlm_WV2.Source))
    catch {
    }
    try payload["title"] := Trim(String(g_SCWebLlm_WV2.DocumentTitle))
    catch {
    }
    if FuncExists("SCWV_PostJson") {
        try SCWV_PostJson(payload)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
}

SearchCenterWebLlm_OnControllerReady(ctrl, siteId, url) {
    global g_SCWebLlm_Ctrl, g_SCWebLlm_WV2, g_SCWebLlm_Env, g_SCWebLlm_Ready, g_SCWebLlm_CreateInFlight
    global g_SCWebLlm_ActiveSiteId, g_SCWebLlm_TokenNavCompleted
    g_SCWebLlm_CreateInFlight := false
    if !IsObject(ctrl) {
        ScWebLlm_Trace("controller_fail", false, Map("site", siteId))
        try TrayTip("网页大模型", "WebView2 启动失败，请稍后重试。", "Iconx 2")
        catch {
        }
        return
    }
    g_SCWebLlm_Ctrl := ctrl
    try g_SCWebLlm_WV2 := ctrl.CoreWebView2
    catch {
        g_SCWebLlm_WV2 := 0
    }
    if !IsObject(g_SCWebLlm_WV2) {
        SearchCenterWebLlm_DisposeActiveController()
        return
    }
    g_SCWebLlm_ActiveSiteId := siteId
    g_SCWebLlm_Ready := true
    try {
        if !g_SCWebLlm_TokenNavCompleted
            g_SCWebLlm_TokenNavCompleted := g_SCWebLlm_WV2.add_NavigationCompleted(SearchCenterWebLlm_OnNavigationCompleted)
    } catch as e {
        ScWebLlm_Catch(e)
    }
    try g_SCWebLlm_Ctrl.IsVisible := true
    catch {
    }
    try {
        u := Trim(String(url))
        if (u != "")
            g_SCWebLlm_WV2.Navigate(u)
    } catch as e {
        ScWebLlm_Catch(e)
    }
    SearchCenterWebLlm_ApplyBounds()
    SearchCenterWebLlm_PushChromeState()
    ScWebLlm_Trace("site_open", true, Map("site", siteId))
}

SearchCenterWebLlm_OpenSite(siteId, forceNavigate := false, navigateUrl := "") {
    global g_SCWebLlm_CreateInFlight, g_SCWebLlm_ActiveSiteId, g_SCWebLlm_ParentHwnd, g_SCWebLlm_WV2
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        sid := ScWebLlm_DefaultSiteId()
    if !ScWebLlm_IsSiteEnabled(sid) {
        try TrayTip("联网搜索", "该 AI 站点暂不支持内嵌：" . sid, "Icon! 2")
        catch {
        }
        return false
    }
    if g_SCWebLlm_CreateInFlight
        return false
    st := SearchCenterWebLlm_LoadState()
    st["activeSiteId"] := sid
    global g_SCWebLlm_StateCache
    g_SCWebLlm_StateCache := st
    targetUrl := Trim(String(navigateUrl))
    if (targetUrl = "")
        targetUrl := SearchCenterWebLlm_SiteLastUrl(sid)
    if (targetUrl = "")
        targetUrl := ScWebLlm_SiteHomeUrl(sid)
    if !SearchCenterWebLlm_HostAlive() {
        if !g_SCWebLlm_ParentHwnd
            return false
    }
    parentHwnd := g_SCWebLlm_ParentHwnd
    if !parentHwnd
        return false
    hostHwnd := SearchCenterWebLlm_EnsureContentHost(parentHwnd)
    if !hostHwnd
        return false
    if (sid = g_SCWebLlm_ActiveSiteId && SearchCenterWebLlm_ControllerAlive()) {
        SearchCenterWebLlm_ApplyBounds(parentHwnd)
        if (forceNavigate && targetUrl != "" && IsObject(g_SCWebLlm_WV2)) {
            try g_SCWebLlm_WV2.Navigate(targetUrl)
            catch as e {
                ScWebLlm_Catch(e)
            }
        }
        return true
    }
    SearchCenterWebLlm_DisposeActiveController()
    g_SCWebLlm_CreateInFlight := true
    WebView2_CreateWithSiteDataDirAsync(hostHwnd, sid, (ctrl) => (
        SearchCenterWebLlm_OnControllerReady(ctrl, sid, targetUrl)
    ), "sc_web_llm_" . sid)
    return true
}

SearchCenterWebLlm_SetContentRect(rect) {
    global g_SCWebLlm_ContentRect
    if !(rect is Map)
        return
    g_SCWebLlm_ContentRect := Map(
        "left", Integer(rect.Get("left", 0)),
        "top", Integer(rect.Get("top", 220)),
        "width", Max(200, Integer(rect.Get("width", 800))),
        "height", Max(160, Integer(rect.Get("height", 500)))
    )
    SearchCenterWebLlm_ApplyBounds()
}

SearchCenterWebLlm_ApplyBounds(parentHwnd := 0) {
    global g_SCWebLlm_ParentHwnd, g_SCWebLlm_ContentHostHwnd, g_SCWebLlm_Ctrl, g_SCWebLlm_ContentRect
    global g_SCWebLlm_LastBoundsKey, g_SCWebLlm_Visible
    hwnd := Integer(parentHwnd) ? Integer(parentHwnd) : g_SCWebLlm_ParentHwnd
    if !hwnd || !g_SCWebLlm_Visible
        return false
    g_SCWebLlm_ParentHwnd := hwnd
    hostHwnd := SearchCenterWebLlm_EnsureContentHost(hwnd)
    if !hostHwnd
        return false
    left := Integer(g_SCWebLlm_ContentRect.Get("left", 0))
    top := Integer(g_SCWebLlm_ContentRect.Get("top", 220))
    w := Integer(g_SCWebLlm_ContentRect.Get("width", 800))
    h := Integer(g_SCWebLlm_ContentRect.Get("height", 500))
    if (w < 200 || h < 160) {
        try WinGetClientPos(, , &cw, &ch, hwnd)
        catch {
            return false
        }
        left := 0
        top := Min(220, Max(120, Round(ch * 0.28)))
        w := cw
        h := Max(160, ch - top)
    }
    key := left . "x" . top . "x" . w . "x" . h
    if (key = g_SCWebLlm_LastBoundsKey)
        return true
    g_SCWebLlm_LastBoundsKey := key
    SearchCenterWebLlm_PositionChildHost(hostHwnd, left, top, w, h, true)
    if IsObject(g_SCWebLlm_Ctrl) && hostHwnd {
        try {
            WinGetClientPos(, , &hw, &hh, hostHwnd)
            rc := WebView2.RECT()
            rc.left := 0
            rc.top := 0
            rc.right := hw
            rc.bottom := hh
            g_SCWebLlm_Ctrl.Bounds := rc
            g_SCWebLlm_Ctrl.NotifyParentWindowPositionChanged()
        } catch as e {
            ScWebLlm_Catch(e)
        }
    }
    return true
}

SearchCenterWebLlm_Show(parentHwnd) {
    global g_SCWebLlm_Visible, g_SCWebLlm_ParentHwnd, SearchCenterSelectedEngines
    h := Integer(parentHwnd)
    if !h
        return false
    g_SCWebLlm_ParentHwnd := h
    g_SCWebLlm_Visible := true
    st := SearchCenterWebLlm_LoadState()
    sid := st.Has("activeSiteId") ? ScWebLlm_NormalizeSiteId(st["activeSiteId"]) : ""
    if !ScWebLlm_IsSiteEnabled(sid)
        sid := ScWebLlm_PickSiteFromEngines(SearchCenterSelectedEngines)
    ok := SearchCenterWebLlm_OpenSite(sid)
    if ok
        SearchCenterWebLlm_ApplyBounds(h)
    return ok
}

SearchCenterWebLlm_NavigateEngine(engine, keyword := "") {
    eng := Trim(String(engine))
    sid := ScWebLlm_EngineToSiteId(eng)
    if (sid = "")
        return false
    global g_SCWebLlm_ParentHwnd, g_SCWebLlm_Visible
    if !g_SCWebLlm_ParentHwnd
        return false
    g_SCWebLlm_Visible := true
    url := ""
    kw := Trim(String(keyword))
    if (kw != "" && FuncExists("VoiceInputEffect_BuildSearchUrl"))
        url := VoiceInputEffect_BuildSearchUrl(kw, eng)
    return SearchCenterWebLlm_OpenSite(sid, true, url)
}

SearchCenterWebLlm_Hide() {
    global g_SCWebLlm_Visible, g_SCWebLlm_ContentHostHwnd, g_SCWebLlm_LastBoundsKey
    if !g_SCWebLlm_Visible
        return
    g_SCWebLlm_Visible := false
    g_SCWebLlm_LastBoundsKey := ""
    SearchCenterWebLlm_SaveState()
    if IsObject(g_SCWebLlm_WV2) {
        try WebView2_NotifyHidden(g_SCWebLlm_WV2)
        catch {
        }
    }
    if g_SCWebLlm_ContentHostHwnd
        SearchCenterWebLlm_PositionChildHost(g_SCWebLlm_ContentHostHwnd, 0, 0, 0, 0, false)
    if IsObject(g_SCWebLlm_Ctrl) {
        try g_SCWebLlm_Ctrl.IsVisible := false
        catch {
        }
    }
}

SearchCenterWebLlm_Dispose() {
    global g_SCWebLlm_Visible, g_SCWebLlm_ContentGui, g_SCWebLlm_ContentHostHwnd, g_SCWebLlm_ParentHwnd
    global g_SCWebLlm_LastBoundsKey, g_SCWebLlm_CreateInFlight
    g_SCWebLlm_Visible := false
    g_SCWebLlm_CreateInFlight := false
    g_SCWebLlm_LastBoundsKey := ""
    SearchCenterWebLlm_SaveState()
    SearchCenterWebLlm_DisposeActiveController()
    if IsObject(g_SCWebLlm_ContentGui) {
        try g_SCWebLlm_ContentGui.Destroy()
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    g_SCWebLlm_ContentGui := 0
    g_SCWebLlm_ContentHostHwnd := 0
    g_SCWebLlm_ParentHwnd := 0
}

SearchCenterWebLlm_SelectSite(siteId) {
    if !g_SCWebLlm_Visible
        return false
    return SearchCenterWebLlm_OpenSite(siteId, true)
}

SearchCenterWebLlm_HandleNav(action) {
    act := StrLower(Trim(String(action)))
    if !SearchCenterWebLlm_ControllerAlive()
        return false
    global g_SCWebLlm_WV2, g_SCWebLlm_ActiveSiteId
    try {
        if (act = "back") {
            if g_SCWebLlm_WV2.CanGoBack
                g_SCWebLlm_WV2.GoBack()
        } else if (act = "forward") {
            if g_SCWebLlm_WV2.CanGoForward
                g_SCWebLlm_WV2.GoForward()
        } else if (act = "reload") {
            g_SCWebLlm_WV2.Reload()
        } else if (act = "home") {
            home := ScWebLlm_SiteHomeUrl(g_SCWebLlm_ActiveSiteId)
            if (home != "")
                g_SCWebLlm_WV2.Navigate(home)
        } else if (act = "copyurl" || act = "copy_url") {
            url := ""
            try url := Trim(String(g_SCWebLlm_WV2.Source))
            if (url = "")
                return false
            A_Clipboard := url
            try TrayTip("联网搜索", "已复制当前链接", "Iconi 1")
            catch {
            }
            return true
        } else
            return false
    } catch as e {
        ScWebLlm_Catch(e)
        return false
    }
    SetTimer(SearchCenterWebLlm_PushChromeState, -120)
    return true
}

SearchCenterWebLlm_PrepareForScriptReload() {
    SearchCenterWebLlm_Dispose()
}
