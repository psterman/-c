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
global g_SCWebLlm_ContentRectReady := false
global g_SCWebLlm_ContentRect := Map("left", 0, "top", 220, "width", 800, "height", 500)
global g_SCWebLlm_TokenNavCompleted := 0
global g_SCWebLlm_StateCache := Map()
global g_SCWebLlm_PendingOpenRequest := 0
global g_SCWebLlm_SiteHosts := Map()
global g_SCWebLlm_MultiMobile := true
global g_SCWebLlm_EmbedBootstrapped := false
global g_SCWebLlm_OwnerOverlay := false
global g_SCWebLlm_EmbedRequested := false
global g_SCWebLlm_WatchdogToken := 0
global g_SCWebLlm_BootstrapScheduled := false
global g_SCWebLlm_BootstrapInFlight := false
global g_SCWebLlm_BootstrapWaitCount := 0
global g_SCWebLlm_MainWebViewLowered := false
global g_SCWebLlm_BoundsRetryScheduled := false

ScWebLlm_MobileUserAgent() {
    return "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
}

ScWebLlm_MobileColumnCssWidth() {
    return 390
}

ScWebLlm_GetEmbedParentHwnd() {
    global g_SCWV_Gui
    if IsObject(g_SCWV_Gui) {
        try return g_SCWV_Gui.Hwnd
        catch {
        }
    }
    return 0
}

ScWebLlm_ResolveEmbedHostHwnd() {
    global g_SCWebLlm_ParentHwnd, g_SCWV_Gui
    h := ScWebLlm_GetEmbedParentHwnd()
    if !h
        h := Integer(g_SCWebLlm_ParentHwnd)
    if !h && IsObject(g_SCWV_Gui) {
        try h := g_SCWV_Gui.Hwnd
        catch {
        }
    }
    return h
}

SearchCenterWebLlm_SiteRecord(siteId) {
    global g_SCWebLlm_SiteHosts
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        return 0
    if !g_SCWebLlm_SiteHosts.Has(sid)
        g_SCWebLlm_SiteHosts[sid] := Map(
            "siteId", sid,
            "hostGui", 0, "hostHwnd", 0,
            "ctrl", 0, "wv2", 0,
            "ready", false, "createInFlight", false,
            "tokenNavCompleted", 0
        )
    return g_SCWebLlm_SiteHosts[sid]
}

SearchCenterWebLlm_SyncActiveGlobals() {
    global g_SCWebLlm_ActiveSiteId, g_SCWebLlm_Ctrl, g_SCWebLlm_WV2, g_SCWebLlm_Ready, g_SCWebLlm_TokenNavCompleted
    rec := SearchCenterWebLlm_SiteRecord(g_SCWebLlm_ActiveSiteId)
    if !(rec is Map) {
        g_SCWebLlm_Ctrl := 0
        g_SCWebLlm_WV2 := 0
        g_SCWebLlm_Ready := false
        g_SCWebLlm_TokenNavCompleted := 0
        return
    }
    g_SCWebLlm_Ctrl := rec.Has("ctrl") ? rec["ctrl"] : 0
    g_SCWebLlm_WV2 := rec.Has("wv2") ? rec["wv2"] : 0
    g_SCWebLlm_Ready := !!rec.Get("ready", false)
    g_SCWebLlm_TokenNavCompleted := rec.Has("tokenNavCompleted") ? rec["tokenNavCompleted"] : 0
}

SearchCenterWebLlm_ApplyMobileSettings(wv2) {
    if !IsObject(wv2)
        return
    try {
        s := wv2.Settings
        if IsObject(s) {
            s.UserAgent := ScWebLlm_MobileUserAgent()
            s.AreDefaultContextMenusEnabled := true
            s.AreDevToolsEnabled := true
            s.IsStatusBarEnabled := false
        }
    } catch as e {
        ScWebLlm_Catch(e)
    }
}

SearchCenterWebLlm_ListLayoutSiteIds() {
    out := []
    for site in ScWebLlm_EnabledSites()
        out.Push(site["id"])
    return out
}

ScWebLlm_Catch(err) {
    if FuncExists("NmerCatch")
        try NmerCatch(A_ThisFunc, err)
}

ScWebLlm_ShouldShowWebEmbed() {
    fn := "_SCWV_ShouldShowWebEmbed"
    if !FuncExists(fn)
        return false
    try {
        return !!(%fn%)()
    } catch as e {
        ScWebLlm_Catch(e)
        return false
    }
}

ScWebLlm_Trace(action, ok := true, meta := 0) {
    fn := "Nmer_Telemetry_Record"
    if FuncExists(fn) {
        try {
            (%fn%)("web_llm", action, !!ok, meta is Map ? meta : Map())
        } catch as e {
            ScWebLlm_Catch(e)
        }
    }
    try {
        line := "[" . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . "][" . action . "] ok=" . (ok ? "1" : "0")
        if (meta is Map) {
            for k, v in meta
                line .= " " . k . "=" . String(v)
        }
        dir := A_ScriptDir . "\Cache\debug"
        if !DirExist(dir)
            DirCreate(dir)
        FileAppend(line . "`n", dir . "\sc_web_llm_runtime.log", "UTF-8")
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
    global g_SCWebLlm_StateCache, g_SCWebLlm_ActiveSiteId
    SearchCenterWebLlm_SyncActiveGlobals()
    global g_SCWebLlm_WV2
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

SearchCenterWebLlm_CreateChildHostGui(ownerHwnd, bgColor := "F8FAFC") {
    owner := Integer(ownerHwnd)
    if !owner
        return 0
    global g_SCWebLlm_OwnerOverlay
    try {
        if g_SCWebLlm_OwnerOverlay {
            g := Gui("+Owner" . owner . " -Caption +ToolWindow -DPIScale", "SCWebLlmEmbed")
            g.BackColor := bgColor
            g.Show("Hide x-32000 y-32000 w390 h700")
            return Map("gui", g, "hwnd", g.Hwnd)
        }
        g := Gui("-Caption -SysMenu +E0x08000000", "SCWebLlmEmbed")
        g.BackColor := bgColor
        g.Show("Hide w400 h400")
        hwnd := g.Hwnd
        style := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -16, "Ptr")
        style := (style | 0x40000000 | 0x10000000) & ~0x80000000
        DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -16, "Ptr", style, "Ptr")
        if !DllCall("SetParent", "Ptr", hwnd, "Ptr", owner, "Ptr") {
            try g.Destroy()
            return 0
        }
        return Map("gui", g, "hwnd", hwnd)
    } catch as e {
        ScWebLlm_Catch(e)
        return 0
    }
}

SearchCenterWebLlm_PositionChildHost(hostHwnd, x, y, w, h, show := true, parentHwnd := 0) {
    if !hostHwnd
        return
    global g_SCWebLlm_OwnerOverlay, g_SCWebLlm_ParentHwnd
    id := "ahk_id " . hostHwnd
    if g_SCWebLlm_OwnerOverlay {
        sx := Integer(x)
        sy := Integer(y)
        ph := Integer(parentHwnd) ? Integer(parentHwnd) : Integer(g_SCWebLlm_ParentHwnd)
        if ph {
            pt := Buffer(8, 0)
            NumPut("Int", sx, pt, 0)
            NumPut("Int", sy, pt, 4)
            try {
                if DllCall("ClientToScreen", "Ptr", ph, "Ptr", pt) {
                    sx := NumGet(pt, 0, "Int")
                    sy := NumGet(pt, 4, "Int")
                }
            } catch as e {
                ScWebLlm_Catch(e)
            }
        }
        if (show && w > 0 && h > 0) {
            try WinMove(sx, sy, w, h, id)
            try WinShow(id)
        } else {
            try WinHide(id)
        }
        return
    }
    flags := 0x0010
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

SearchCenterWebLlm_LowerMainWebView() {
    global g_SCWebLlm_MainWebViewLowered, g_SCWV_Ctrl
    if g_SCWebLlm_MainWebViewLowered
        return
    if !IsObject(g_SCWV_Ctrl)
        return
    mainHwnd := 0
    try mainHwnd := g_SCWV_Ctrl.ParentWindow
    catch {
    }
    if !mainHwnd
        return
    try DllCall("SetWindowPos", "Ptr", mainHwnd, "Ptr", 1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0010 | 0x0001 | 0x0002)
    catch as e {
        ScWebLlm_Catch(e)
        return
    }
    g_SCWebLlm_MainWebViewLowered := true
}

SearchCenterWebLlm_RestoreMainWebView() {
    global g_SCWebLlm_MainWebViewLowered, g_SCWV_Ctrl
    if !g_SCWebLlm_MainWebViewLowered
        return
    if !IsObject(g_SCWV_Ctrl)
        return
    mainHwnd := 0
    try mainHwnd := g_SCWV_Ctrl.ParentWindow
    catch {
    }
    if mainHwnd {
        try DllCall("SetWindowPos", "Ptr", mainHwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0010 | 0x0001 | 0x0002)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    g_SCWebLlm_MainWebViewLowered := false
}

SearchCenterWebLlm_RaiseChildHost(hostHwnd) {
    if !hostHwnd
        return
    global g_SCWebLlm_OwnerOverlay
    if g_SCWebLlm_OwnerOverlay {
        id := "ahk_id " . hostHwnd
        try WinSetAlwaysOnTop false, id
        catch {
        }
        try WinShow(id)
        catch as e {
            ScWebLlm_Catch(e)
        }
        return
    }
    insertAfter := 0
    global g_SCWV_Ctrl
    if IsObject(g_SCWV_Ctrl) {
        try insertAfter := g_SCWV_Ctrl.ParentWindow
        catch {
        }
    }
    if insertAfter {
        try DllCall("SetWindowPos", "Ptr", hostHwnd, "Ptr", insertAfter, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0010 | 0x0001 | 0x0002)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    try DllCall("SetWindowPos", "Ptr", hostHwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0010 | 0x0001 | 0x0002)
    catch as e {
        ScWebLlm_Catch(e)
    }
}

SearchCenterWebLlm_RaiseSiteHosts(activeSiteId := "") {
    global g_SCWebLlm_SiteHosts, g_SCWebLlm_MultiMobile
    if g_SCWebLlm_MultiMobile {
        for sid in SearchCenterWebLlm_ListLayoutSiteIds() {
            rec := SearchCenterWebLlm_SiteRecord(sid)
            if (rec is Map) && rec.Has("hostHwnd") && rec["hostHwnd"]
                SearchCenterWebLlm_RaiseChildHost(rec["hostHwnd"])
        }
        return
    }
    active := ScWebLlm_NormalizeSiteId(activeSiteId)
    for sid, rec in g_SCWebLlm_SiteHosts {
        if !(rec is Map) || !rec.Has("hostHwnd") || !rec["hostHwnd"]
            continue
        if (sid != active)
            SearchCenterWebLlm_RaiseChildHost(rec["hostHwnd"])
    }
    if (active != "") {
        rec := SearchCenterWebLlm_SiteRecord(active)
        if (rec is Map) && rec.Has("hostHwnd") && rec["hostHwnd"]
            SearchCenterWebLlm_RaiseChildHost(rec["hostHwnd"])
    }
}

ScWebLlm_GetRasterScale() {
    global g_SCWV_Ctrl
    if IsObject(g_SCWV_Ctrl) {
        try {
            sc := g_SCWV_Ctrl.RasterizationScale
            if (sc > 0.1 && sc < 10)
                return sc
        } catch {
        }
    }
    if FuncExists("_SCWV_WebViewRasterScale") {
        try return _SCWV_WebViewRasterScale()
        catch {
        }
    }
    return 1.0
}

SearchCenterWebLlm_EnsureSiteHost(parentHwnd, siteId) {
    global g_SCWebLlm_ParentHwnd
    sid := ScWebLlm_NormalizeSiteId(siteId)
    rec := SearchCenterWebLlm_SiteRecord(sid)
    if !(rec is Map)
        return 0
    ph := ScWebLlm_GetEmbedParentHwnd()
    if !ph
        ph := Integer(parentHwnd)
    if !ph
        return 0
    g_SCWebLlm_ParentHwnd := ph
    if rec.Has("hostHwnd") && rec["hostHwnd"] {
        global g_SCWebLlm_OwnerOverlay
        if g_SCWebLlm_OwnerOverlay {
            if (rec.Has("ownerHwnd") && rec["ownerHwnd"] = ph)
                return rec["hostHwnd"]
        } else {
            try {
                if (DllCall("GetParent", "Ptr", rec["hostHwnd"], "Ptr") = ph)
                    return rec["hostHwnd"]
            } catch {
            }
        }
    }
    SearchCenterWebLlm_DisposeSiteController(sid)
    if IsObject(rec["hostGui"]) {
        try rec["hostGui"].Destroy()
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    created := SearchCenterWebLlm_CreateChildHostGui(ph)
    if !(created is Map) || !created.Has("hwnd") || !created["hwnd"]
        return 0
    rec["hostGui"] := created["gui"]
    rec["hostHwnd"] := created["hwnd"]
    rec["ownerHwnd"] := ph
    return rec["hostHwnd"]
}

SearchCenterWebLlm_EnsureContentHost(parentHwnd) {
    global g_SCWebLlm_ActiveSiteId
    sid := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    if (sid = "")
        sid := ScWebLlm_DefaultSiteId()
    return SearchCenterWebLlm_EnsureSiteHost(parentHwnd, sid)
}

SearchCenterWebLlm_HostAlive() {
    global g_SCWebLlm_ParentHwnd
    return WebView2_IsUsableHwnd(g_SCWebLlm_ParentHwnd)
}

SearchCenterWebLlm_ControllerAlive() {
    global g_SCWebLlm_ActiveSiteId
    rec := SearchCenterWebLlm_SiteRecord(g_SCWebLlm_ActiveSiteId)
    if !(rec is Map)
        return false
    return IsObject(rec["ctrl"]) && IsObject(rec["wv2"]) && SearchCenterWebLlm_HostAlive()
}

SearchCenterWebLlm_DisposeSiteController(siteId) {
    rec := SearchCenterWebLlm_SiteRecord(siteId)
    if !(rec is Map)
        return
    if IsObject(rec["wv2"]) && rec["tokenNavCompleted"] {
        try rec["wv2"].remove_NavigationCompleted(rec["tokenNavCompleted"])
        catch {
        }
    }
    rec["tokenNavCompleted"] := 0
    if IsObject(rec["wv2"]) {
        try WebView2_NotifyHidden(rec["wv2"])
        catch {
        }
    }
    if IsObject(rec["ctrl"]) {
        try rec["ctrl"].IsVisible := false
        catch {
        }
        try rec["ctrl"].Close()
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    rec["ctrl"] := 0
    rec["wv2"] := 0
    rec["ready"] := false
    rec["createInFlight"] := false
    SearchCenterWebLlm_SyncActiveGlobals()
}

SearchCenterWebLlm_DisposeActiveController() {
    global g_SCWebLlm_SiteHosts
    for sid, rec in g_SCWebLlm_SiteHosts
        SearchCenterWebLlm_DisposeSiteController(sid)
    global g_SCWebLlm_Ctrl, g_SCWebLlm_WV2, g_SCWebLlm_Env, g_SCWebLlm_Ready, g_SCWebLlm_TokenNavCompleted
    g_SCWebLlm_Ctrl := 0
    g_SCWebLlm_WV2 := 0
    g_SCWebLlm_Env := 0
    g_SCWebLlm_Ready := false
    g_SCWebLlm_TokenNavCompleted := 0
}

SearchCenterWebLlm_MakeNavCompletedHandler(siteId) {
    sid := ScWebLlm_NormalizeSiteId(siteId)
    return (sender, args) => SearchCenterWebLlm_OnNavigationCompleted(sid, sender, args)
}

SearchCenterWebLlm_OnNavigationCompleted(siteId, sender, args) {
    global g_SCWebLlm_ActiveSiteId
    sid := ScWebLlm_NormalizeSiteId(siteId)
    ok := true
    try ok := args.IsSuccess
    catch {
    }
    if ok && sid = ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
        SearchCenterWebLlm_SaveState()
    else if !ok
        ScWebLlm_Trace("nav_fail", false, Map("site", sid))
    if (sid = ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId))
        SearchCenterWebLlm_PushChromeState()
}

SearchCenterWebLlm_PushChromeState() {
    SearchCenterWebLlm_SyncActiveGlobals()
    global g_SCWebLlm_WV2, g_SCWebLlm_ActiveSiteId
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
    global g_SCWebLlm_ActiveSiteId, g_SCWebLlm_MultiMobile
    sid := ScWebLlm_NormalizeSiteId(siteId)
    rec := SearchCenterWebLlm_SiteRecord(sid)
    if !(rec is Map) {
        return
    }
    rec["createInFlight"] := false
    if !IsObject(ctrl) {
        ScWebLlm_Trace("controller_fail", false, Map("site", sid))
        try TrayTip("联网搜索", (ScWebLlm_FindSite(sid) is Map ? ScWebLlm_FindSite(sid)["label"] : sid) . " 内嵌页启动失败", "Iconx 2")
        catch {
        }
        return
    }
    rec["ctrl"] := ctrl
    try rec["wv2"] := ctrl.CoreWebView2
    catch {
        rec["wv2"] := 0
    }
    if !IsObject(rec["wv2"]) {
        SearchCenterWebLlm_DisposeSiteController(sid)
        return
    }
    rec["ready"] := true
    try ctrl.DefaultBackgroundColor := 0xFFF8FAFC
    catch {
    }
    SearchCenterWebLlm_ApplyMobileSettings(rec["wv2"])
    if FuncExists("ApplyWebView2PerformanceSettings") {
        try ApplyWebView2PerformanceSettings(rec["wv2"])
        catch {
        }
    }
    try {
        if !rec["tokenNavCompleted"]
            rec["tokenNavCompleted"] := rec["wv2"].add_NavigationCompleted(SearchCenterWebLlm_MakeNavCompletedHandler(sid))
    } catch as e {
        ScWebLlm_Catch(e)
    }
    try ctrl.IsVisible := true
    catch {
    }
    try {
        u := Trim(String(url))
        if (u != "")
            rec["wv2"].Navigate(u)
    } catch as e {
        ScWebLlm_Catch(e)
    }
    SearchCenterWebLlm_SyncActiveGlobals()
    SearchCenterWebLlm_ApplyBounds()
    ScWebLlm_ScheduleBoundsRetries()
    if IsObject(rec["wv2"]) && FuncExists("WebView2_NotifyShown") {
        try WebView2_NotifyShown(rec["wv2"])
        catch {
        }
    }
    if (sid = ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId))
        SearchCenterWebLlm_PushChromeState()
    ScWebLlm_Trace("site_open", true, Map("site", sid, "multi", !!g_SCWebLlm_MultiMobile))
}

SearchCenterWebLlm_QueueOpenSite(siteId, forceNavigate := false, navigateUrl := "") {
    global g_SCWebLlm_PendingOpenRequest
    g_SCWebLlm_PendingOpenRequest := Map(
        "siteId", ScWebLlm_NormalizeSiteId(siteId),
        "forceNavigate", !!forceNavigate,
        "navigateUrl", Trim(String(navigateUrl))
    )
    return true
}

SearchCenterWebLlm_OpenSite(siteId, forceNavigate := false, navigateUrl := "") {
    global g_SCWebLlm_ActiveSiteId, g_SCWebLlm_ParentHwnd, g_SCWebLlm_MultiMobile
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        sid := ScWebLlm_DefaultSiteId()
    if !ScWebLlm_IsSiteEnabled(sid) {
        try TrayTip("联网搜索", "该 AI 站点暂不支持内嵌：" . sid, "Icon! 2")
        catch {
        }
        return false
    }
    rec := SearchCenterWebLlm_SiteRecord(sid)
    if !(rec is Map)
        return false
    if rec["createInFlight"]
        return true
    if (sid = ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)) {
        st := SearchCenterWebLlm_LoadState()
        st["activeSiteId"] := sid
        global g_SCWebLlm_StateCache
        g_SCWebLlm_StateCache := st
    }
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
    hostHwnd := SearchCenterWebLlm_EnsureSiteHost(parentHwnd, sid)
    if !hostHwnd
        return false
    global g_SCWebLlm_Visible
    g_SCWebLlm_Visible := true
    ScWebLlm_EnsureFallbackContentRect()
    SearchCenterWebLlm_ApplyBounds(parentHwnd)
    if (rec["ready"] && IsObject(rec["wv2"])) {
        SearchCenterWebLlm_ApplyBounds(parentHwnd)
        if (forceNavigate && targetUrl != "") {
            try rec["wv2"].Navigate(targetUrl)
            catch as e {
                ScWebLlm_Catch(e)
            }
        }
        SearchCenterWebLlm_SyncActiveGlobals()
        return true
    }
    SearchCenterWebLlm_DisposeSiteController(sid)
    rec["createInFlight"] := true
    ScWebLlm_Trace("open_site", true, Map("site", sid, "url", targetUrl, "host", hostHwnd))
    if !FuncExists("WebView2_CreateWithSharedEnvAsync") {
        rec["createInFlight"] := false
        ScWebLlm_Trace("open_site_fail", false, Map("site", sid, "reason", "no_shared_env"))
        return false
    }
    WebView2_CreateWithSharedEnvAsync(hostHwnd, (ctrl) => (
        SearchCenterWebLlm_OnControllerReady(ctrl, sid, targetUrl)
    ), "searchcenter_sc_web_llm_" . sid)
    return true
}

SearchCenterWebLlm_OpenSiteDelayed(siteId, forceNavigate := false, *) {
    SearchCenterWebLlm_OpenSite(siteId, forceNavigate)
}

SearchCenterWebLlm_EnsureMissingSites(forceNavigate := false) {
    ok := false
    pending := 0
    for site in ScWebLlm_EnabledSites() {
        sid := site["id"]
        rec := SearchCenterWebLlm_SiteRecord(sid)
        if !(rec is Map)
            continue
        if rec.Get("ready", false) && IsObject(rec.Get("wv2", 0))
            continue
        if rec.Get("createInFlight", false)
            continue
        delay := pending * 420
        if (delay <= 0)
            ok := SearchCenterWebLlm_OpenSite(sid, forceNavigate) || ok
        else
            SetTimer(SearchCenterWebLlm_OpenSiteDelayed.Bind(sid, forceNavigate), -delay)
        ok := true
        pending += 1
    }
    return ok
}

SearchCenterWebLlm_OpenAllSites(forceNavigate := false) {
    global g_SCWebLlm_MultiMobile
    if !g_SCWebLlm_MultiMobile {
        sid := ScWebLlm_DefaultSiteId()
        global g_SCWebLlm_ActiveSiteId
        if (g_SCWebLlm_ActiveSiteId != "")
            sid := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
        return SearchCenterWebLlm_OpenSite(sid, forceNavigate)
    }
    ok := false
    idx := 0
    for site in ScWebLlm_EnabledSites() {
        sid := site["id"]
        delay := idx * 420
        if (delay <= 0)
            ok := SearchCenterWebLlm_OpenSite(sid, forceNavigate) || ok
        else
            SetTimer(SearchCenterWebLlm_OpenSiteDelayed.Bind(sid, forceNavigate), -delay)
        ok := true
        idx += 1
    }
    return ok
}

ScWebLlm_ResolveClientRect(parentHwnd, &left, &top, &w, &h) {
    global g_SCWebLlm_ContentRect, g_SCWV_Ctrl
    ph := Integer(parentHwnd)
    if !ph
        ph := ScWebLlm_GetEmbedParentHwnd()
    if (g_SCWebLlm_ContentRect is Map) && ph && IsObject(g_SCWV_Ctrl) && FuncExists("_SCWV_ViewportRectToParentClient") {
        try {
            if _SCWV_ViewportRectToParentClient(g_SCWebLlm_ContentRect, ph, &left, &top, &w, &h)
                return (w >= 200 && h >= 140)
        } catch as e {
            ScWebLlm_Catch(e)
        }
    }
    cssL := 0
    cssT := 220
    cssW := 800
    cssH := 500
    if (g_SCWebLlm_ContentRect is Map) {
        cssL := Integer(g_SCWebLlm_ContentRect.Get("left", 0))
        cssT := Integer(g_SCWebLlm_ContentRect.Get("top", 220))
        cssW := Integer(g_SCWebLlm_ContentRect.Get("width", 800))
        cssH := Integer(g_SCWebLlm_ContentRect.Get("height", 500))
    }
    sc := ScWebLlm_GetRasterScale()
    left := Round(cssL * sc)
    top := Round(cssT * sc)
    w := Round(cssW * sc)
    h := Round(cssH * sc)
    if (w < 200 || h < 140) {
        ph := Integer(parentHwnd)
        if !ph
            return false
        try WinGetClientPos(, , &cw, &ch, ph)
        catch {
            return false
        }
        if (cw < 200 || ch < 160)
            return false
        left := 0
        top := Min(Round(ch * 0.28), Max(120, Round(cssT * sc)))
        w := cw
        h := Max(140, ch - top)
    }
    return (w >= 200 && h >= 140)
}

ScWebLlm_ResolveEmbedScreenRect(&left, &top, &w, &h) {
    global g_SCWebLlm_ContentRect
    if !(g_SCWebLlm_ContentRect is Map)
        return false
    if FuncExists("_SCWV_BoundsMapToScreen") {
        try return _SCWV_BoundsMapToScreen(g_SCWebLlm_ContentRect, &left, &top, &w, &h)
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    return false
}

ScWebLlm_EnsureFallbackContentRect(markReady := false) {
    global g_SCWebLlm_ContentRect, g_SCWebLlm_ContentRectReady, g_SCWV_Gui
    if (g_SCWebLlm_ContentRectReady && (g_SCWebLlm_ContentRect is Map) && Integer(g_SCWebLlm_ContentRect.Get("width", 0)) >= 160)
        return true
    if !IsObject(g_SCWV_Gui)
        return false
    try {
        WinGetClientPos(, , &cw, &ch, g_SCWV_Gui.Hwnd)
        if (cw < 200 || ch < 200)
            return false
        g_SCWebLlm_ContentRect := Map(
            "left", 0,
            "top", Max(200, Round(ch * 0.34)),
            "width", cw,
            "height", Max(180, Round(ch * 0.52))
        )
        if markReady
            g_SCWebLlm_ContentRectReady := true
        return true
    } catch as e {
        ScWebLlm_Catch(e)
    }
    return false
}

ScWebLlm_ScheduleBoundsRetries() {
    global g_SCWebLlm_BoundsRetryScheduled
    if g_SCWebLlm_BoundsRetryScheduled
        return
    g_SCWebLlm_BoundsRetryScheduled := true
    SetTimer(ScWebLlm_BoundsRetryTick, -220)
}

ScWebLlm_BoundsRetryTick() {
    global g_SCWebLlm_BoundsRetryScheduled
    g_SCWebLlm_BoundsRetryScheduled := false
    try SearchCenterWebLlm_ApplyBounds()
    catch as e {
        ScWebLlm_Catch(e)
    }
}

ScWebLlm_EmbedBootstrapTick() {
    global g_SCWebLlm_BootstrapScheduled, g_SCWebLlm_BootstrapInFlight, g_SCWebLlm_BootstrapWaitCount
    g_SCWebLlm_BootstrapScheduled := false
    if g_SCWebLlm_BootstrapInFlight
        return
    if !ScWebLlm_ShouldShowWebEmbed()
        return
    if !SearchCenterWebLlm_CanBootstrapEmbed() {
        g_SCWebLlm_BootstrapWaitCount += 1
        if (g_SCWebLlm_BootstrapWaitCount >= 12)
            ScWebLlm_EnsureFallbackContentRect(true)
        if !SearchCenterWebLlm_CanBootstrapEmbed() {
            if (g_SCWebLlm_BootstrapWaitCount < 24)
                ScWebLlm_ScheduleEmbedBootstrap()
            return
        }
    }
    g_SCWebLlm_BootstrapInFlight := true
    try SearchCenterWebLlm_EnsureEmbedSitesLoaded(false)
    catch as e {
        ScWebLlm_Catch(e)
    }
    g_SCWebLlm_BootstrapInFlight := false
}

ScWebLlm_ScheduleEmbedBootstrap() {
    global g_SCWebLlm_BootstrapScheduled
    if g_SCWebLlm_BootstrapScheduled
        return
    g_SCWebLlm_BootstrapScheduled := true
    SetTimer(ScWebLlm_EmbedBootstrapTick, -320)
}

SearchCenterWebLlm_StartEmbedWatchdog() {
    global g_SCWebLlm_WatchdogToken
    g_SCWebLlm_WatchdogToken := A_TickCount
    token := g_SCWebLlm_WatchdogToken
    SetTimer((*) => SearchCenterWebLlm_EmbedWatchdogTick(token, 0), -2500)
}

SearchCenterWebLlm_EmbedWatchdogTick(token, n) {
    global g_SCWebLlm_WatchdogToken, g_SCWebLlm_EmbedBootstrapped
    if (token != g_SCWebLlm_WatchdogToken)
        return
    if !ScWebLlm_ShouldShowWebEmbed()
        return
    if !g_SCWebLlm_EmbedBootstrapped
        ScWebLlm_ScheduleEmbedBootstrap()
    else {
        try SearchCenterWebLlm_ApplyBounds()
        catch as e {
            ScWebLlm_Catch(e)
        }
    }
    if (n < 8)
        SetTimer((*) => SearchCenterWebLlm_EmbedWatchdogTick(token, n + 1), -3000)
}

SearchCenterWebLlm_MarkEmbedRequested() {
    global g_SCWebLlm_EmbedRequested
    g_SCWebLlm_EmbedRequested := true
}

SearchCenterWebLlm_CanBootstrapEmbed() {
    global g_SCWV_Ctrl, g_SCWebLlm_ContentRectReady
    if !IsObject(g_SCWV_Ctrl)
        return false
    if !ScWebLlm_GetEmbedParentHwnd()
        return false
    if !g_SCWebLlm_ContentRectReady
        return false
    return true
}

SearchCenterWebLlm_SetContentRect(rect) {
    global g_SCWebLlm_ContentRect, g_SCWebLlm_Visible, g_SCWebLlm_ContentRectReady, g_SCWebLlm_ParentHwnd
    global g_SCWebLlm_LastBoundsKey
    if !(rect is Map)
        return
    SearchCenterWebLlm_MarkEmbedRequested()
    g_SCWebLlm_Visible := true
    w := Max(0, Integer(rect.Get("width", 0)))
    h := Max(0, Integer(rect.Get("height", 0)))
    prevW := 0
    prevH := 0
    if (g_SCWebLlm_ContentRect is Map) {
        prevW := Integer(g_SCWebLlm_ContentRect.Get("width", 0))
        prevH := Integer(g_SCWebLlm_ContentRect.Get("height", 0))
    }
    if (w > prevW + 48 || h > prevH + 48)
        g_SCWebLlm_LastBoundsKey := ""
    g_SCWebLlm_ContentRect := Map(
        "left", Integer(rect.Get("left", 0)),
        "top", Integer(rect.Get("top", 220)),
        "width", Max(200, w),
        "height", Max(140, h)
    )
    parent := g_SCWebLlm_ParentHwnd
    g_SCWebLlm_ContentRectReady := (w >= 160 && h >= 80)
    if g_SCWebLlm_ContentRectReady
        g_SCWebLlm_BootstrapWaitCount := 0
    SearchCenterWebLlm_ApplyBounds()
    ScWebLlm_ScheduleBoundsRetries()
    ScWebLlm_ScheduleEmbedBootstrap()
    if !g_SCWebLlm_EmbedBootstrapped
        SearchCenterWebLlm_StartEmbedWatchdog()
}

ScWebLlm_ComputeSiteColumnLayout(siteIds, activeSiteId, embedLeft, embedTop, embedW, embedH, &colLeft, &colTop, &colW, &colH, index) {
    n := siteIds.Length
    if (n < 1 || index < 0 || index >= n)
        return false
    colTop := embedTop
    colH := embedH
    colLeft := embedLeft + Round(index * embedW / n)
    if (index = n - 1)
        colW := embedLeft + embedW - colLeft
    else {
        nextLeft := embedLeft + Round((index + 1) * embedW / n)
        colW := nextLeft - colLeft
    }
    return (colW >= 160 && colH >= 140)
}

SearchCenterWebLlm_ApplyBounds(parentHwnd := 0) {
    global g_SCWebLlm_ParentHwnd, g_SCWebLlm_ContentRect
    global g_SCWebLlm_LastBoundsKey, g_SCWebLlm_Visible, g_SCWebLlm_ActiveSiteId, g_SCWebLlm_MultiMobile
    global g_SCWebLlm_ContentRectReady
    if !ScWebLlm_ShouldShowWebEmbed() {
        SearchCenterWebLlm_Hide()
        return false
    }
    if !g_SCWebLlm_ContentRectReady
        return false
    hwnd := Integer(parentHwnd) ? Integer(parentHwnd) : g_SCWebLlm_ParentHwnd
    if !hwnd || !g_SCWebLlm_Visible
        return false
    g_SCWebLlm_ParentHwnd := hwnd
    embedLeft := 0
    embedTop := 0
    embedW := 0
    embedH := 0
    resolved := ScWebLlm_ResolveClientRect(hwnd, &embedLeft, &embedTop, &embedW, &embedH)
    if !resolved
        return false
    siteIds := SearchCenterWebLlm_ListLayoutSiteIds()
    if !g_SCWebLlm_MultiMobile {
        sid := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
        if (sid = "")
            sid := ScWebLlm_DefaultSiteId()
        siteIds := [sid]
    }
    key := embedLeft . "x" . embedTop . "x" . embedW . "x" . embedH . "x" . g_SCWebLlm_ActiveSiteId . "x" . siteIds.Length
    if (key != g_SCWebLlm_LastBoundsKey)
        g_SCWebLlm_LastBoundsKey := key
    activeNorm := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    if !g_SCWebLlm_OwnerOverlay
        SearchCenterWebLlm_LowerMainWebView()
    idx := 0
    for sid in siteIds {
        rec := SearchCenterWebLlm_SiteRecord(sid)
        if !(rec is Map)
            continue
        colL := 0
        colT := 0
        colW := 0
        colH := 0
        if !ScWebLlm_ComputeSiteColumnLayout(siteIds, activeNorm, embedLeft, embedTop, embedW, embedH, &colL, &colT, &colW, &colH, idx)
            continue
        hostHwnd := rec.Has("hostHwnd") ? rec["hostHwnd"] : 0
        if !hostHwnd
            hostHwnd := SearchCenterWebLlm_EnsureSiteHost(hwnd, sid)
        if hostHwnd
            SearchCenterWebLlm_PositionChildHost(hostHwnd, colL, colT, colW, colH, true, hwnd)
        if IsObject(rec["ctrl"]) && hostHwnd {
            try {
                WinGetClientPos(, , &hw, &hh, hostHwnd)
                if (hw > 0 && hh > 0) {
                    rc := WebView2.RECT()
                    rc.left := 0
                    rc.top := 0
                    rc.right := hw
                    rc.bottom := hh
                    rec["ctrl"].Bounds := rc
                    rec["ctrl"].NotifyParentWindowPositionChanged()
                }
            } catch as e {
                ScWebLlm_Catch(e)
            }
            try rec["ctrl"].IsVisible := true
            catch {
            }
            if IsObject(rec["wv2"]) && FuncExists("WebView2_NotifyShown") {
                try WebView2_NotifyShown(rec["wv2"])
                catch {
                }
            }
        }
        idx += 1
    }
    SearchCenterWebLlm_RaiseSiteHosts(activeNorm)
    SearchCenterWebLlm_SyncActiveGlobals()
    return true
}

SearchCenterWebLlm_Show(parentHwnd) {
    return SearchCenterWebLlm_EnsureEmbedSitesLoaded(false, parentHwnd)
}

SearchCenterWebLlm_EnsureEmbedSitesLoaded(forceNavigateHome := false, parentHwnd := 0) {
    global g_SCWebLlm_Visible, g_SCWebLlm_ParentHwnd, SearchCenterSelectedEngines
    global g_SCWebLlm_ContentRectReady, g_SCWebLlm_LastBoundsKey, g_SCWebLlm_ActiveSiteId
    global g_SCWebLlm_EmbedBootstrapped, g_SCWV_Ctrl
    ScWebLlm_Trace("ensure_enter", true, Map("force", !!forceNavigateHome, "ready", !!g_SCWebLlm_ContentRectReady, "boot", !!g_SCWebLlm_EmbedBootstrapped))
    if !ScWebLlm_ShouldShowWebEmbed() {
        ScWebLlm_Trace("ensure_skip", false, Map("reason", "should_not_embed"))
        return false
    }
    if !SearchCenterWebLlm_CanBootstrapEmbed() {
        ScWebLlm_Trace("ensure_wait", false, Map("reason", "not_ready", "wait", g_SCWebLlm_BootstrapWaitCount))
        return false
    }
    h := ScWebLlm_GetEmbedParentHwnd()
    if !h
        h := Integer(parentHwnd)
    if !h {
        ScWebLlm_Trace("ensure_abort", false, Map("reason", "no_parent_hwnd"))
        return false
    }
    SearchCenterWebLlm_MarkEmbedRequested()
    g_SCWebLlm_ParentHwnd := h
    g_SCWebLlm_Visible := true
    if !g_SCWebLlm_ContentRectReady
        g_SCWebLlm_LastBoundsKey := ""
    st := SearchCenterWebLlm_LoadState()
    sid := st.Has("activeSiteId") ? ScWebLlm_NormalizeSiteId(st["activeSiteId"]) : ""
    if !ScWebLlm_IsSiteEnabled(sid)
        sid := ScWebLlm_PickSiteFromEngines(SearchCenterSelectedEngines)
    g_SCWebLlm_ActiveSiteId := sid
    navHome := !!forceNavigateHome
    if !g_SCWebLlm_EmbedBootstrapped {
        navHome := true
        g_SCWebLlm_EmbedBootstrapped := true
        ok := SearchCenterWebLlm_OpenAllSites(navHome)
    } else if navHome {
        ok := SearchCenterWebLlm_OpenAllSites(true)
    } else {
        ok := SearchCenterWebLlm_EnsureMissingSites(false)
    }
    if ok {
        SearchCenterWebLlm_ApplyBounds(h)
        ScWebLlm_ScheduleBoundsRetries()
        ScWebLlm_Trace("bootstrap", true, Map("sites", SearchCenterWebLlm_ListLayoutSiteIds().Length))
    } else {
        ScWebLlm_Trace("bootstrap", false, Map("reason", "open_all_failed"))
    }
    return ok
}

SearchCenterWebLlm_NavigateEngine(engine, keyword := "") {
    eng := Trim(String(engine))
    sid := ScWebLlm_EngineToSiteId(eng)
    if (sid = "")
        return false
    global g_SCWebLlm_ParentHwnd, g_SCWebLlm_Visible, g_SCWV_Gui
    if !ScWebLlm_ShouldShowWebEmbed()
        return false
    h := ScWebLlm_ResolveEmbedHostHwnd()
    if !h
        return false
    g_SCWebLlm_ParentHwnd := h
    g_SCWebLlm_Visible := true
    global g_SCWebLlm_ActiveSiteId
    g_SCWebLlm_ActiveSiteId := sid
    kw := Trim(String(keyword))
    url := ""
    if (kw != "") {
        if FuncExists("VoiceInputEffect_BuildSearchUrl") {
            try url := VoiceInputEffect_BuildSearchUrl(kw, eng)
            catch {
            }
        }
        if (url = "" && InStr(kw, "://"))
            url := kw
        else if (url = "" && RegExMatch(kw, "i)^[\w-]+(\.[\w.-]+)+"))
            url := "https://" . kw
    }
    if (url != "") {
        ok := SearchCenterWebLlm_OpenSite(sid, true, url)
        SearchCenterWebLlm_ApplyBounds(h)
        SearchCenterWebLlm_PushChromeState()
        return ok
    }
    ok := SearchCenterWebLlm_OpenSite(sid, true)
    SearchCenterWebLlm_ApplyBounds(h)
    SearchCenterWebLlm_PushChromeState()
    return ok
}

ScWebLlm_ResolveTargetSites(engines := 0) {
    targets := []
    seen := Map()
    src := engines
    if !(IsObject(src) && src.Length > 0) {
        global SearchCenterSelectedEngines
        src := IsObject(SearchCenterSelectedEngines) ? SearchCenterSelectedEngines : []
    }
    if IsObject(src) {
        for eng in src {
            sid := ScWebLlm_EngineToSiteId(eng)
            if (sid = "")
                sid := ScWebLlm_NormalizeSiteId(eng)
            if (sid != "" && !seen.Has(sid)) {
                seen[sid] := true
                targets.Push(sid)
            }
        }
    }
    if (targets.Length = 0) {
        for site in ScWebLlm_EnabledSites()
            targets.Push(site["id"])
    }
    return targets
}

SearchCenterWebLlm_BroadcastSearch(keyword, engines := 0) {
    kw := Trim(String(keyword))
    if (kw = "")
        return false
    if !ScWebLlm_ShouldShowWebEmbed()
        return false
    global g_SCWebLlm_ParentHwnd, g_SCWV_Gui, g_SCWebLlm_Visible
    h := ScWebLlm_ResolveEmbedHostHwnd()
    if !h
        return false
    g_SCWebLlm_ParentHwnd := h
    g_SCWebLlm_Visible := true
    targets := ScWebLlm_ResolveTargetSites(engines)
    ok := false
    for sid in targets {
        try {
            if SearchCenterWebLlm_NavigateEngine(sid, kw)
                ok := true
        } catch as e {
            ScWebLlm_Catch(e)
        }
    }
    SearchCenterWebLlm_ApplyBounds(h)
    return ok
}

SearchCenterWebLlm_ReloadSites(engines := 0) {
    global g_SCWebLlm_ParentHwnd, g_SCWV_Gui, g_SCWebLlm_Visible
    h := ScWebLlm_ResolveEmbedHostHwnd()
    if !h
        return false
    g_SCWebLlm_ParentHwnd := h
    g_SCWebLlm_Visible := true
    targets := ScWebLlm_ResolveTargetSites(engines)
    ok := false
    for sid in targets {
        rec := SearchCenterWebLlm_SiteRecord(sid)
        if (rec is Map) && IsObject(rec["wv2"]) {
            try {
                rec["wv2"].Reload()
                ok := true
            } catch as e {
                ScWebLlm_Catch(e)
            }
        } else {
            try {
                if SearchCenterWebLlm_OpenSite(sid, true)
                    ok := true
            } catch as e {
                ScWebLlm_Catch(e)
            }
        }
    }
    SearchCenterWebLlm_ApplyBounds(h)
    SetTimer(SearchCenterWebLlm_PushChromeState, -120)
    return ok
}

SearchCenterWebLlm_Hide() {
    global g_SCWebLlm_Visible, g_SCWebLlm_LastBoundsKey, g_SCWebLlm_ContentRectReady, g_SCWebLlm_SiteHosts
    global g_SCWebLlm_BootstrapScheduled, g_SCWebLlm_BootstrapInFlight, g_SCWebLlm_BootstrapWaitCount
    global g_SCWebLlm_WatchdogToken, g_SCWebLlm_BoundsRetryScheduled
    g_SCWebLlm_Visible := false
    g_SCWebLlm_ContentRectReady := false
    g_SCWebLlm_LastBoundsKey := ""
    g_SCWebLlm_PendingOpenRequest := 0
    g_SCWebLlm_BootstrapScheduled := false
    g_SCWebLlm_BootstrapInFlight := false
    g_SCWebLlm_BootstrapWaitCount := 0
    g_SCWebLlm_BoundsRetryScheduled := false
    g_SCWebLlm_WatchdogToken := 0
    SearchCenterWebLlm_RestoreMainWebView()
    SearchCenterWebLlm_SaveState()
    for sid, rec in g_SCWebLlm_SiteHosts {
        if !(rec is Map)
            continue
        if IsObject(rec["wv2"]) {
            try WebView2_NotifyHidden(rec["wv2"])
            catch {
            }
        }
        if rec.Has("hostHwnd") && rec["hostHwnd"]
            SearchCenterWebLlm_PositionChildHost(rec["hostHwnd"], 0, 0, 0, 0, false)
        if IsObject(rec["ctrl"]) {
            try rec["ctrl"].IsVisible := false
            catch {
            }
        }
    }
}

SearchCenterWebLlm_Dispose() {
    global g_SCWebLlm_Visible, g_SCWebLlm_ParentHwnd, g_SCWebLlm_EmbedBootstrapped
    global g_SCWebLlm_LastBoundsKey, g_SCWebLlm_SiteHosts
    g_SCWebLlm_Visible := false
    g_SCWebLlm_LastBoundsKey := ""
    g_SCWebLlm_PendingOpenRequest := 0
    SearchCenterWebLlm_SaveState()
    SearchCenterWebLlm_DisposeActiveController()
    for sid, rec in g_SCWebLlm_SiteHosts {
        if !(rec is Map)
            continue
        if IsObject(rec["hostGui"]) {
            try rec["hostGui"].Destroy()
            catch as e {
                ScWebLlm_Catch(e)
            }
        }
        rec["hostGui"] := 0
        rec["hostHwnd"] := 0
    }
    g_SCWebLlm_SiteHosts := Map()
    global g_SCWebLlm_ContentGui, g_SCWebLlm_ContentHostHwnd
    g_SCWebLlm_ContentGui := 0
    g_SCWebLlm_ContentHostHwnd := 0
    g_SCWebLlm_ParentHwnd := 0
    g_SCWebLlm_EmbedBootstrapped := false
}

SearchCenterWebLlm_SelectSite(siteId) {
    global g_SCWebLlm_Visible, g_SCWebLlm_ParentHwnd, g_SCWV_Gui
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        return false
    h := ScWebLlm_ResolveEmbedHostHwnd()
    if !h
        return false
    g_SCWebLlm_ParentHwnd := h
    g_SCWebLlm_Visible := true
    g_SCWebLlm_ActiveSiteId := sid
    SearchCenterWebLlm_ApplyBounds(h)
    SearchCenterWebLlm_PushChromeState()
    return SearchCenterWebLlm_OpenSite(sid, true)
}

SearchCenterWebLlm_FocusSite(siteId) {
    global g_SCWebLlm_Visible, g_SCWebLlm_ParentHwnd, g_SCWV_Gui, g_SCWebLlm_ActiveSiteId
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        return false
    h := ScWebLlm_ResolveEmbedHostHwnd()
    if !h
        return false
    g_SCWebLlm_ParentHwnd := h
    g_SCWebLlm_Visible := true
    g_SCWebLlm_ActiveSiteId := sid
    SearchCenterWebLlm_ApplyBounds(h)
    SearchCenterWebLlm_PushChromeState()
    return true
}

SearchCenterWebLlm_NavigateUrl(url, siteId := "") {
    global g_SCWebLlm_ActiveSiteId, g_SCWebLlm_ParentHwnd, g_SCWebLlm_Visible, g_SCWebLlm_WV2, g_SCWV_Gui
    u := Trim(String(url))
    if (u = "")
        return false
    if !ScWebLlm_ShouldShowWebEmbed()
        return false
    sid := ScWebLlm_NormalizeSiteId(siteId)
    if (sid = "")
        sid := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
    if (sid = "")
        sid := ScWebLlm_DefaultSiteId()
    h := ScWebLlm_ResolveEmbedHostHwnd()
    if !h
        return false
    g_SCWebLlm_ParentHwnd := h
    g_SCWebLlm_Visible := true
    g_SCWebLlm_ActiveSiteId := sid
    SearchCenterWebLlm_SyncActiveGlobals()
    rec := SearchCenterWebLlm_SiteRecord(sid)
    if (rec is Map) && rec["ready"] && IsObject(rec["wv2"]) {
        try rec["wv2"].Navigate(u)
        catch as e {
            ScWebLlm_Catch(e)
            return false
        }
        SearchCenterWebLlm_ApplyBounds(h)
        SearchCenterWebLlm_PushChromeState()
        return true
    }
    return SearchCenterWebLlm_OpenSite(sid, true, u)
}

SearchCenterWebLlm_HandleNav(action) {
    act := StrLower(Trim(String(action)))
    if (act = "reload_all") {
        global SearchCenterSelectedEngines
        return SearchCenterWebLlm_ReloadSites(SearchCenterSelectedEngines)
    }
    if !SearchCenterWebLlm_ControllerAlive() {
        global g_SCWebLlm_ActiveSiteId, g_SCWebLlm_ParentHwnd, g_SCWV_Gui, g_SCWebLlm_Visible
        if (act = "home" || act = "reload") {
            sid := ScWebLlm_NormalizeSiteId(g_SCWebLlm_ActiveSiteId)
            if (sid = "")
                sid := ScWebLlm_DefaultSiteId()
            h := ScWebLlm_ResolveEmbedHostHwnd()
            if !h
                return false
            g_SCWebLlm_ParentHwnd := h
            g_SCWebLlm_Visible := true
            return SearchCenterWebLlm_OpenSite(sid, true)
        }
        return false
    }
    global g_SCWebLlm_ActiveSiteId
    SearchCenterWebLlm_SyncActiveGlobals()
    rec := SearchCenterWebLlm_SiteRecord(g_SCWebLlm_ActiveSiteId)
    if !(rec is Map) || !IsObject(rec["wv2"])
        return false
    wv2 := rec["wv2"]
    try {
        if (act = "back") {
            if wv2.CanGoBack
                wv2.GoBack()
        } else if (act = "forward") {
            if wv2.CanGoForward
                wv2.GoForward()
        } else if (act = "reload") {
            wv2.Reload()
        } else if (act = "home") {
            home := ScWebLlm_SiteHomeUrl(g_SCWebLlm_ActiveSiteId)
            if (home != "")
                wv2.Navigate(home)
        } else if (act = "copyurl" || act = "copy_url") {
            url := ""
            try url := Trim(String(wv2.Source))
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
