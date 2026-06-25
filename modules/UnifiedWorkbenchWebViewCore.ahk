; UnifiedWorkbenchWebViewCore.ahk — Column Unified Workbench MVP
#Requires AutoHotkey v2.0

global g_UnifiedWb_Gui := 0
global g_UnifiedWb_Ctrl := 0
global g_UnifiedWb_WV2 := 0
global g_UnifiedWb_Ready := false
global g_UnifiedWb_Visible := false
global g_UnifiedWb_LastShown := 0
global g_UnifiedWb_PendingKeyword := ""
global g_UnifiedWb_InitialIntent := "ai"
global g_UnifiedWb_FocusedColumnType := "ai"
global g_UnifiedWb_FocusedCliEngine := "codex_cli"
global g_UnifiedWb_FocusedAiSite := "deepseek"
global g_UnifiedWb_NudgeGeneration := 0
global g_UnifiedWb_AiRetryGeneration := 0
global g_UnifiedWb_AiFinalizeGeneration := 0
global g_UnifiedWb_BootstrapReplayGen := 0
global g_UnifiedWb_CriticalMessageSeq := 0
global g_UnifiedWb_LastAiColumns := 0
global g_UnifiedWb_LastBootstrapMeta := Map()
global g_UnifiedWb_LastWebBootstrapSig := ""
global g_UnifiedWb_LastWebBootstrapTick := 0
global g_UnifiedWb_LastFinalizeSig := ""
global g_UnifiedWb_LastFinalizeTick := 0
global g_UnifiedWb_LastLayoutWaitNudge := 0
global g_UnifiedWb_Saved_SCWV_Gui := 0
global g_UnifiedWb_Saved_SCWV_Ctrl := 0
global g_UnifiedWb_Saved_SCWV_WV2 := 0
global g_UnifiedWb_LastSessionSnapshot := 0

UnifiedWb_GetGui() {
    global g_UnifiedWb_Gui
    return g_UnifiedWb_Gui
}

UnifiedWb_IsVisible() {
    global g_UnifiedWb_Visible
    return !!g_UnifiedWb_Visible
}

UnifiedWb_Trace(action, ok := true, meta := 0) {
    act := String(action)
    metaCopy := Map()
    if (meta is Map) {
        for k, v in meta
            metaCopy[String(k)] := v
    }
    try SetTimer(_UnifiedWb_TraceDeferred.Bind(act, !!ok, metaCopy), -1)
    catch {
    }
    if FuncExists("ScWebLlm_Trace")
        try ScWebLlm_Trace("uwb_" . act, ok, metaCopy)
        catch {
        }
}

_UnifiedWb_TraceDeferred(action, ok, meta, *) {
    try {
        line := "[" . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . "][" . String(action) . "] ok=" . (ok ? "1" : "0")
        if (meta is Map) {
            for k, v in meta
                line .= " " . String(k) . "=" . String(v)
        }
        dir := A_ScriptDir . "\Cache\debug"
        if FuncExists("Nmer_DebugDir")
            dir := Nmer_DebugDir()
        if !DirExist(dir)
            DirCreate(dir)
        f := FileOpen(dir . "\unified_workbench_debug.log", "a", "UTF-8")
        if IsObject(f) {
            f.Write(line . "`n")
            f.Close()
        }
    } catch {
    }
}

UnifiedWb_PostJson(payload, force := false) {
    global g_UnifiedWb_WV2, g_UnifiedWb_Ready
    if !IsObject(g_UnifiedWb_WV2)
        return
    if !force && !g_UnifiedWb_Ready
        return
    if (payload is Map)
        WebView_QueuePayload(g_UnifiedWb_WV2, payload)
    else
        WebView_QueueJson(g_UnifiedWb_WV2, payload)
}

UnifiedWb_PostCriticalJson(payload, force := true) {
    global g_UnifiedWb_CriticalMessageSeq
    if (payload is Map) && !payload.Has("hostMsgId") {
        g_UnifiedWb_CriticalMessageSeq += 1
        payload["hostMsgId"] := "uwb-" . A_TickCount . "-" . g_UnifiedWb_CriticalMessageSeq
    }
    UnifiedWb_PostJson(payload, force)
    UnifiedWb_InjectHostMessage(payload)
}

UnifiedWb_InjectHostMessage(payload, retryPass := 0) {
    global g_UnifiedWb_WV2
    if !IsObject(g_UnifiedWb_WV2)
        return false
    try jsonStr := WebView_DumpJson(payload)
    catch {
        try jsonStr := Jxon_Dump(payload)
        catch {
            return false
        }
    }
    if (jsonStr = "")
        return false
    try argJson := Jxon_Dump(String(jsonStr))
    catch {
        return false
    }
    js := "(function(){try{var p=JSON.parse(" . argJson . ");"
        . "if(typeof window.__UnifiedWorkbenchHostMessage==='function'){window.__UnifiedWorkbenchHostMessage(p);return 'ok';}"
        . "return 'missing';}catch(e){return 'err:'+(e&&e.message||e);}})();"
    try g_UnifiedWb_WV2.ExecuteScriptAsync(js)
    catch as e {
        UnifiedWb_Trace("inject_host_msg", false, Map("error", e.Message))
        return false
    }
    if (retryPass < 4)
        SetTimer(UnifiedWb_InjectHostMessage.Bind(payload, retryPass + 1), -(120 + retryPass * 260))
    return true
}

UnifiedWb_BindScWebLlmHost() {
    global g_UnifiedWb_Gui, g_UnifiedWb_Ctrl, g_UnifiedWb_WV2
    global g_UnifiedWb_Saved_SCWV_Gui, g_UnifiedWb_Saved_SCWV_Ctrl, g_UnifiedWb_Saved_SCWV_WV2
    global g_SCWV_Gui, g_SCWV_Ctrl, g_SCWV_WV2, g_SCWebLlm_ParentHwnd, g_SCWebLlm_UnifiedHostActive
    global g_SCWebLlm_OwnerOverlay, g_SCWebLlm_LastBoundsKey, g_SCWebLlm_ChildHostBoundsCache
    g_UnifiedWb_Saved_SCWV_Gui := g_SCWV_Gui
    g_UnifiedWb_Saved_SCWV_Ctrl := g_SCWV_Ctrl
    g_UnifiedWb_Saved_SCWV_WV2 := g_SCWV_WV2
    g_SCWV_Gui := g_UnifiedWb_Gui
    g_SCWV_Ctrl := g_UnifiedWb_Ctrl
    g_SCWV_WV2 := g_UnifiedWb_WV2
    g_SCWebLlm_UnifiedHostActive := true
    if g_SCWebLlm_OwnerOverlay {
        g_SCWebLlm_OwnerOverlay := false
        g_SCWebLlm_LastBoundsKey := ""
        g_SCWebLlm_ChildHostBoundsCache := Map()
        if FuncExists("ScWebLlm_DisposeUnifiedOverlayHosts")
            try ScWebLlm_DisposeUnifiedOverlayHosts()
            catch {
            }
    }
    if IsObject(g_UnifiedWb_Gui) {
        try g_SCWebLlm_ParentHwnd := g_UnifiedWb_Gui.Hwnd
        catch {
            g_SCWebLlm_ParentHwnd := 0
        }
    }
    if FuncExists("SearchCenterWebLlm_HideFocusGlow") {
        try SearchCenterWebLlm_HideFocusGlow()
        catch {
        }
    }
}

UnifiedWb_RestoreScWebLlmHost() {
    global g_UnifiedWb_Saved_SCWV_Gui, g_UnifiedWb_Saved_SCWV_Ctrl, g_UnifiedWb_Saved_SCWV_WV2
    global g_SCWV_Gui, g_SCWV_Ctrl, g_SCWV_WV2, g_SCWebLlm_UnifiedHostActive
    g_SCWebLlm_OwnerOverlay := false
    g_SCWV_Gui := g_UnifiedWb_Saved_SCWV_Gui
    g_SCWV_Ctrl := g_UnifiedWb_Saved_SCWV_Ctrl
    g_SCWV_WV2 := g_UnifiedWb_Saved_SCWV_WV2
    g_SCWebLlm_UnifiedHostActive := false
    g_UnifiedWb_Saved_SCWV_Gui := 0
    g_UnifiedWb_Saved_SCWV_Ctrl := 0
    g_UnifiedWb_Saved_SCWV_WV2 := 0
}

UnifiedWb_Init() {
    global g_UnifiedWb_Gui
    if g_UnifiedWb_Gui
        return
    try SurfaceManager_ObserveInit("unified_workbench", Map("entry", "UnifiedWb_Init"))
    g_UnifiedWb_Gui := Gui("+Resize +MinSize900x560 +MinimizeBox +MaximizeBox +Caption -DPIScale", "统一工作台")
    g_UnifiedWb_Gui.BackColor := "0d1016"
    g_UnifiedWb_Gui.MarginX := 0
    g_UnifiedWb_Gui.MarginY := 0
    g_UnifiedWb_Gui.OnEvent("Close", (*) => UnifiedWb_Hide())
    g_UnifiedWb_Gui.OnEvent("Size", _UnifiedWb_OnGuiResize)
    g_UnifiedWb_Gui.Show("w1320 h820 Hide")
    WebView2_CreateWithSharedEnvAsync(g_UnifiedWb_Gui.Hwnd, _UnifiedWb_OnWV2Created, "unified_workbench")
}

_UnifiedWb_GetWebView2Class() {
    try return WebView2
    catch {
        return 0
    }
}

_UnifiedWb_OnWV2Created(ctrl) {
    global g_UnifiedWb_Ctrl, g_UnifiedWb_WV2
    g_UnifiedWb_Ctrl := ctrl
    g_UnifiedWb_WV2 := ctrl.CoreWebView2
    try g_UnifiedWb_Ctrl.DefaultBackgroundColor := 0xFF0D1016
    try g_UnifiedWb_Ctrl.IsVisible := true
    _UnifiedWb_ApplyBounds()
    SetTimer(UnifiedWb_RefreshRasterizationScale, -50)
    SetTimer(UnifiedWb_RefreshRasterizationScale, -180)
    s := g_UnifiedWb_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.AreDevToolsEnabled := false
    if FuncExists("ApplyWebView2PerformanceSettings")
        ApplyWebView2PerformanceSettings(g_UnifiedWb_WV2)
    if FuncExists("WebView2_RegisterHostBridge")
        WebView2_RegisterHostBridge(g_UnifiedWb_WV2)
    g_UnifiedWb_WV2.add_WebMessageReceived(_UnifiedWb_OnWebMessage)
    try g_UnifiedWb_WV2.add_NavigationCompleted(_UnifiedWb_OnNavigationCompleted)
    try ApplyUnifiedWebViewAssets(g_UnifiedWb_WV2)
    navUrl := BuildAppLocalUrl("UnifiedWorkbench.html")
    try {
        htmlPath := FuncExists("HtmlPanelPath") ? HtmlPanelPath("UnifiedWorkbench.html") : (A_ScriptDir . "\html\UnifiedWorkbench.html")
        ver := String(FileGetTime(htmlPath, "M"))
        navUrl .= (InStr(navUrl, "?") ? "&" : "?") . "v=" . ver
    } catch {
    }
    global g_UnifiedWb_Ready
    g_UnifiedWb_Ready := false
    g_UnifiedWb_WV2.Navigate(navUrl)
    global g_UnifiedWb_Visible
    if g_UnifiedWb_Visible {
        try WebView2_NotifyShown(g_UnifiedWb_WV2)
        _UnifiedWb_RefreshComposition()
        SetTimer(_UnifiedWb_DelayedPushInit, -90)
    }
}

UnifiedWb_RefreshRasterizationScale(*) {
    global g_UnifiedWb_Ctrl
    if !IsObject(g_UnifiedWb_Ctrl)
        return
    try {
        sc := g_UnifiedWb_Ctrl.RasterizationScale
        if (sc > 0.1 && sc < 10)
            g_UnifiedWb_Ctrl.RasterizationScale := sc
    } catch {
    }
}

_UnifiedWb_ApplyBounds() {
    global g_UnifiedWb_Gui, g_UnifiedWb_Ctrl
    if !g_UnifiedWb_Ctrl || !g_UnifiedWb_Gui
        return
    WinGetClientPos(, , &cw, &ch, g_UnifiedWb_Gui.Hwnd)
    WV2 := _UnifiedWb_GetWebView2Class()
    if !WV2
        return
    rc := WV2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    g_UnifiedWb_Ctrl.Bounds := rc
    SetTimer(UnifiedWb_RefreshRasterizationScale, -1)
}

UnifiedWb_EnsureAiEmbedLayering() {
    global g_UnifiedWb_Gui, g_UnifiedWb_Visible, g_SCWebLlm_UnifiedMultiRectActive, g_SCWebLlm_MainWebViewLowered
    global g_UnifiedWb_LastLayoutWaitNudge
    if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown()
        return
    if FuncExists("ScWebLlm_IsUnifiedColumnResizeActive") && ScWebLlm_IsUnifiedColumnResizeActive()
        return
    if FuncExists("ScWebLlm_IsUnifiedLayoutPaused") && ScWebLlm_IsUnifiedLayoutPaused()
        return
    if !g_UnifiedWb_Visible || !IsObject(g_UnifiedWb_Gui)
        return
    if !g_SCWebLlm_MainWebViewLowered && FuncExists("SearchCenterWebLlm_LowerMainWebView") {
        try SearchCenterWebLlm_LowerMainWebView()
        catch {
        }
    }
    if !g_SCWebLlm_UnifiedMultiRectActive {
        nowTick := A_TickCount
        if (nowTick - Integer(g_UnifiedWb_LastLayoutWaitNudge) < 2000)
            return
        g_UnifiedWb_LastLayoutWaitNudge := nowTick
        UnifiedWb_Trace("layering", false, Map("reason", "wait_layout"))
        UnifiedWb_PostCriticalJson(Map("type", "hostOpenBootstrap", "reason", "layering_wait_layout", "includeCli", false), true)
        return
    }
    ph := 0
    try ph := g_UnifiedWb_Gui.Hwnd
    catch {
    }
    if !ph
        return
    if FuncExists("SearchCenterWebLlm_ApplyBounds") {
        try SearchCenterWebLlm_ApplyBounds(ph)
        catch {
        }
    }
    if FuncExists("SearchCenterWebLlm_ApplyUnifiedColumnResizeRails") {
        try SearchCenterWebLlm_ApplyUnifiedColumnResizeRails(ph)
        catch {
        }
    }
}

UnifiedWb_FinalizeAiEmbed(parentHwnd := 0, forceNavHome := false) {
    global g_UnifiedWb_Gui, g_UnifiedWb_Visible, g_SCWebLlm_EmbedBootstrapped, g_SCWebLlm_UnifiedMultiRectActive, g_SCWebLlm_LastBoundsKey
    if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown()
        return false
    global g_UnifiedWb_LastFinalizeSig, g_UnifiedWb_LastFinalizeTick
    if !g_UnifiedWb_Visible
        return false
    ph := Integer(parentHwnd)
    if !ph && IsObject(g_UnifiedWb_Gui) {
        try ph := g_UnifiedWb_Gui.Hwnd
        catch {
        }
    }
    if !ph || !g_SCWebLlm_UnifiedMultiRectActive
        return false
    finalSig := ph . "|" . (!!forceNavHome ? 1 : 0)
    nowTick := A_TickCount
    if (finalSig = g_UnifiedWb_LastFinalizeSig && nowTick - g_UnifiedWb_LastFinalizeTick < 450)
        return true
    g_UnifiedWb_LastFinalizeSig := finalSig
    g_UnifiedWb_LastFinalizeTick := nowTick
    if FuncExists("SearchCenterWebLlm_PrepareForWebModeShow") {
        try SearchCenterWebLlm_PrepareForWebModeShow(false)
        catch {
        }
    }
    if FuncExists("SearchCenterWebLlm_LowerMainWebView") {
        try SearchCenterWebLlm_LowerMainWebView()
        catch {
        }
    }
    ; Do not treat "site not ready yet" as a reason to force Navigate.
    ; Navigation completion is exactly what makes a site ready; forcing home
    ; during that window restarts WebView2 repeatedly and shows as white flicker.
    navHome := !!forceNavHome || !g_SCWebLlm_EmbedBootstrapped
    if FuncExists("SearchCenterWebLlm_EnsureMissingSites") {
        try SearchCenterWebLlm_EnsureMissingSites(navHome, ph)
        catch {
        }
    }
    if forceNavHome
        g_SCWebLlm_LastBoundsKey := ""
    if FuncExists("SearchCenterWebLlm_ApplyBounds") {
        try SearchCenterWebLlm_ApplyBounds(ph)
        catch {
        }
    }
    g_SCWebLlm_EmbedBootstrapped := true
    if FuncExists("ScWebLlm_ScheduleBoundsRetries") {
        try ScWebLlm_ScheduleBoundsRetries()
        catch {
        }
    }
    UnifiedWb_Trace("finalize_ai", true, Map("hwnd", ph, "navHome", navHome ? 1 : 0))
    return true
}

UnifiedWb_ScheduleAiEmbedFinalize(parentHwnd := 0, forceNavHome := false) {
    if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown()
        return
    global g_UnifiedWb_AiFinalizeGeneration, g_UnifiedWb_Visible
    if !g_UnifiedWb_Visible
        return
    ph := Integer(parentHwnd)
    gen := ++g_UnifiedWb_AiFinalizeGeneration
    UnifiedWb_FinalizeAiEmbed(ph, forceNavHome)
    SetTimer(_UnifiedWb_AiEmbedFinalizeTick.Bind(ph, gen, 1, false), -90)
    SetTimer(_UnifiedWb_AiEmbedFinalizeTick.Bind(ph, gen, 2, false), -280)
    SetTimer(_UnifiedWb_AiEmbedFinalizeTick.Bind(ph, gen, 3, false), -650)
    SetTimer(_UnifiedWb_AiEmbedFinalizeTick.Bind(ph, gen, 4, false), -1300)
    SetTimer(_UnifiedWb_AiEmbedFinalizeTick.Bind(ph, gen, 5, false), -2400)
    SetTimer(_UnifiedWb_AiEmbedFinalizeTick.Bind(ph, gen, 6, false), -4800)
}

UnifiedWb_StoreBootstrapFromWeb(aiColumns, maxActive := 0, focusSiteId := "", embedViewport := 0) {
    global g_UnifiedWb_LastAiColumns, g_UnifiedWb_LastBootstrapMeta
    if !(aiColumns is Array) || !aiColumns.Length
        return false
    g_UnifiedWb_LastAiColumns := aiColumns
    meta := Map(
        "maxActive", Integer(maxActive),
        "focusSid", Trim(String(focusSiteId))
    )
    if (embedViewport is Map)
        meta["embedViewport"] := embedViewport
    g_UnifiedWb_LastBootstrapMeta := meta
    return true
}

UnifiedWb_ReplayStoredBootstrap(forceNavHome := false, notifyPage := true) {
    global g_UnifiedWb_LastAiColumns, g_UnifiedWb_LastBootstrapMeta, g_UnifiedWb_Gui, g_SCWebLlm_EmbedBootstrapped, g_SCWebLlm_ContentRectReady
    if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown()
        return false
    if FuncExists("ScWebLlm_IsUnifiedScEmbedLayout") && ScWebLlm_IsUnifiedScEmbedLayout()
        return false
    if FuncExists("ScWebLlm_IsUnifiedWorkbenchHost") && ScWebLlm_IsUnifiedWorkbenchHost() && g_SCWebLlm_ContentRectReady
        return false
    if !(g_UnifiedWb_LastAiColumns is Array) || !g_UnifiedWb_LastAiColumns.Length
        return false
    if !UnifiedWb_IsVisible()
        return false
    ph := 0
    if IsObject(g_UnifiedWb_Gui) {
        try ph := g_UnifiedWb_Gui.Hwnd
        catch {
        }
    }
    if !ph
        return false
    maxActive := g_UnifiedWb_LastBootstrapMeta.Has("maxActive") ? Integer(g_UnifiedWb_LastBootstrapMeta["maxActive"]) : 0
    focusSid := g_UnifiedWb_LastBootstrapMeta.Has("focusSid") ? String(g_UnifiedWb_LastBootstrapMeta["focusSid"]) : ""
    embedVp := g_UnifiedWb_LastBootstrapMeta.Has("embedViewport") ? g_UnifiedWb_LastBootstrapMeta["embedViewport"] : 0
    if FuncExists("SearchCenterWebLlm_ApplyUnifiedMultiColumnFromWeb") {
        try SearchCenterWebLlm_ApplyUnifiedMultiColumnFromWeb(g_UnifiedWb_LastAiColumns, maxActive, focusSid, embedVp)
        catch as e {
            UnifiedWb_Trace("replay_apply", false, Map("error", e.Message))
            return false
        }
    }
    if FuncExists("SearchCenterWebLlm_PrepareForWebModeShow") {
        try SearchCenterWebLlm_PrepareForWebModeShow(false)
        catch {
        }
    }
    navHome := !!forceNavHome || !g_SCWebLlm_EmbedBootstrapped
    UnifiedWb_FinalizeAiEmbed(ph, navHome)
    if notifyPage
        UnifiedWb_PostCriticalJson(Map("type", "hostOpenBootstrap", "reason", "stored_replay", "includeCli", false), true)
    UnifiedWb_Trace("replay_bootstrap", true, Map("cols", g_UnifiedWb_LastAiColumns.Length, "navHome", navHome ? 1 : 0))
    return true
}

UnifiedWb_ScheduleStoredBootstrapReplay() {
    global g_UnifiedWb_BootstrapReplayGen, g_SCWebLlm_ContentRectReady
    if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown()
        return
    if FuncExists("ScWebLlm_IsUnifiedScEmbedLayout") && ScWebLlm_IsUnifiedScEmbedLayout()
        return
    if FuncExists("ScWebLlm_IsUnifiedWorkbenchHost") && ScWebLlm_IsUnifiedWorkbenchHost() && g_SCWebLlm_ContentRectReady
        return
    if !(g_UnifiedWb_LastAiColumns is Array) || !g_UnifiedWb_LastAiColumns.Length
        return
    gen := ++g_UnifiedWb_BootstrapReplayGen
    SetTimer(_UnifiedWb_StoredBootstrapReplayTick.Bind(gen, 1), -500)
    SetTimer(_UnifiedWb_StoredBootstrapReplayTick.Bind(gen, 2), -1200)
    SetTimer(_UnifiedWb_StoredBootstrapReplayTick.Bind(gen, 3), -2600)
    SetTimer(_UnifiedWb_StoredBootstrapReplayTick.Bind(gen, 4), -5200)
}

_UnifiedWb_StoredBootstrapReplayTick(gen, pass, *) {
    global g_UnifiedWb_BootstrapReplayGen, g_UnifiedWb_Visible
    if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown()
        return
    if (gen != g_UnifiedWb_BootstrapReplayGen || !g_UnifiedWb_Visible)
        return
    if FuncExists("SearchCenterWebLlm_HasReadySites") && SearchCenterWebLlm_HasReadySites() && pass > 2
        return
    UnifiedWb_ReplayStoredBootstrap(pass <= 2, false)
}

_UnifiedWb_AiEmbedFinalizeTick(ph, gen, pass, forceNavHome, *) {
    global g_UnifiedWb_AiFinalizeGeneration, g_UnifiedWb_Visible
    if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown()
        return
    if (gen != g_UnifiedWb_AiFinalizeGeneration || !g_UnifiedWb_Visible)
        return
    UnifiedWb_FinalizeAiEmbed(ph, !!forceNavHome && pass = 1)
}

_UnifiedWb_OnGuiResize(GuiObj, MinMax, Width, Height) {
    if (MinMax = -1)
        return
    _UnifiedWb_ApplyBounds()
    global g_SCWebLlm_LastBoundsKey
    g_SCWebLlm_LastBoundsKey := ""
    if UnifiedWb_IsVisible() {
        UnifiedWb_EnsureAiEmbedLayering()
    }
    UnifiedWb_PostJson(Map("type", "hostLayout"), true)
}

_UnifiedWb_OnNavigationCompleted(sender, args) {
    try ok := args.IsSuccess
    catch {
        ok := true
    }
    if !ok
        return
    if UnifiedWb_IsVisible() {
        SetTimer(_UnifiedWb_DelayedPushInit, -60)
        _UnifiedWb_RefreshComposition()
        global g_UnifiedWb_Ready
        if !g_UnifiedWb_Ready
            _UnifiedWb_ScheduleBootstrapOnce(280)
    }
}

_UnifiedWb_DelayedPushInit(*) {
    global g_UnifiedWb_WV2
    if !UnifiedWb_IsVisible() || !IsObject(g_UnifiedWb_WV2)
        return
    UnifiedWb_PushInit(false)
}

_UnifiedWb_RefreshComposition(*) {
    global g_UnifiedWb_Ctrl, g_UnifiedWb_Gui, g_UnifiedWb_Visible
    if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown()
        return
    if !g_UnifiedWb_Visible || !g_UnifiedWb_Ctrl || !g_UnifiedWb_Gui
        return
    try {
        _UnifiedWb_ApplyBounds()
        g_UnifiedWb_Ctrl.NotifyParentWindowPositionChanged()
    } catch {
    }
    UnifiedWb_EnsureAiEmbedLayering()
}

_UnifiedWb_CancelBootstrapTimers() {
    global g_UnifiedWb_NudgeGeneration, g_UnifiedWb_AiRetryGeneration, g_UnifiedWb_AiFinalizeGeneration, g_UnifiedWb_BootstrapReplayGen
    g_UnifiedWb_NudgeGeneration += 1
    g_UnifiedWb_AiRetryGeneration += 1
    g_UnifiedWb_AiFinalizeGeneration += 1
    g_UnifiedWb_BootstrapReplayGen += 1
    SetTimer(_UnifiedWb_RunOpenBootstrap, 0)
    SetTimer(_UnifiedWb_DelayedPushInit, 0)
    SetTimer(_UnifiedWb_BootstrapDefaultCliEngines, 0)
    SetTimer(_UnifiedWb_ScheduleAiEmbedRetries, 0)
    SetTimer(_UnifiedWb_EnsureCli.Bind("codex_cli"), 0)
}

UnifiedWb_CancelBootstrapTimers(*) {
    _UnifiedWb_CancelBootstrapTimers()
}

UnifiedWb_MarkShutdown(*) {
    global g_UnifiedWb_Visible
    g_UnifiedWb_Visible := false
    _UnifiedWb_CancelBootstrapTimers()
    if FuncExists("SearchCenterWebLlm_SuspendEmbedWinOps") {
        try SearchCenterWebLlm_SuspendEmbedWinOps()
        catch {
        }
    }
    if FuncExists("SearchCenterWebLlm_SuspendUnifiedEmbed") {
        try SearchCenterWebLlm_SuspendUnifiedEmbed()
        catch {
        }
    }
}

_UnifiedWb_ScheduleBootstrapOnce(delayMs := 220) {
    global g_UnifiedWb_NudgeGeneration
    gen := ++g_UnifiedWb_NudgeGeneration
    baseDelay := Integer(delayMs)
    SetTimer(_UnifiedWb_NudgeBootstrap.Bind(gen, 1), -baseDelay)
    SetTimer(_UnifiedWb_NudgeBootstrap.Bind(gen, 2), -(baseDelay + 240))
    SetTimer(_UnifiedWb_NudgeBootstrap.Bind(gen, 3), -(baseDelay + 700))
    SetTimer(_UnifiedWb_NudgeBootstrap.Bind(gen, 4), -(baseDelay + 1500))
    SetTimer(_UnifiedWb_NudgeBootstrap.Bind(gen, 5), -(baseDelay + 2800))
}

_UnifiedWb_NudgeBootstrap(gen, pass, *) {
    global g_UnifiedWb_Visible, g_UnifiedWb_WV2, g_UnifiedWb_NudgeGeneration, g_UnifiedWb_Gui, g_SCWebLlm_Visible, g_SCWebLlm_UnifiedMultiRectActive
    if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown()
        return
    if (gen != g_UnifiedWb_NudgeGeneration)
        return
    if !g_UnifiedWb_Visible || !IsObject(g_UnifiedWb_WV2)
        return
    g_SCWebLlm_Visible := true
    if FuncExists("SearchCenterWebLlm_PrepareForWebModeShow") {
        try SearchCenterWebLlm_PrepareForWebModeShow(false)
        catch {
        }
    } else if FuncExists("SearchCenterWebLlm_MarkEmbedRequested")
        SearchCenterWebLlm_MarkEmbedRequested()
    try WebView2_NotifyShown(g_UnifiedWb_WV2)
    _UnifiedWb_RefreshComposition()
    UnifiedWb_PostCriticalJson(Map("type", "hostOpenBootstrap", "reason", "bootstrap", "gen", gen, "pass", pass, "includeCli", true), true)
    UnifiedWb_PostJson(Map("type", "hostLayout"), true)
    _UnifiedWb_BootstrapDefaultCliEngines()
    SetTimer(UnifiedWb_EnsureAiEmbedLayering.Bind(), -40)
    if IsObject(g_UnifiedWb_Gui) {
        ph := 0
        try ph := g_UnifiedWb_Gui.Hwnd
        catch {
        }
        if ph && g_SCWebLlm_UnifiedMultiRectActive && FuncExists("UnifiedWb_ScheduleAiEmbedFinalize") {
            if !(FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown())
                UnifiedWb_ScheduleAiEmbedFinalize(ph, false)
        } else if ph && g_SCWebLlm_UnifiedMultiRectActive && FuncExists("SearchCenterWebLlm_EnsureMissingSites") {
            try SearchCenterWebLlm_EnsureMissingSites(false, ph)
            catch {
            }
        }
    }
    if (pass <= 3)
        SetTimer(_UnifiedWb_ScheduleAiEmbedRetries, -120)
}

_UnifiedWb_BootstrapDefaultCliEngines(*) {
    global g_UnifiedWb_WV2, g_UnifiedWb_FocusedCliEngine
    if !IsObject(g_UnifiedWb_WV2)
        return
    eng := Trim(String(g_UnifiedWb_FocusedCliEngine))
    if (eng = "")
        eng := "codex_cli"
    _UnifiedWb_EnsureCli(eng)
}

_UnifiedWb_RunOpenBootstrap(*) {
    global g_UnifiedWb_Visible
    if !g_UnifiedWb_Visible
        return
    _UnifiedWb_ScheduleBootstrapOnce(80)
}

_UnifiedWb_GetThemeMode() {
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

_UnifiedWb_BuildAiEnginePayload() {
    rows := []
    if FuncExists("ScWebLlm_SiteCatalog") {
        try {
            for site in ScWebLlm_SiteCatalog() {
                if !(site is Map)
                    continue
                id := site.Has("id") ? String(site["id"]) : ""
                if (id = "")
                    continue
                enabled := true
                if FuncExists("ScWebLlm_SiteEmbedEnabled")
                    enabled := ScWebLlm_SiteEmbedEnabled(site)
                if !enabled
                    continue
                rows.Push(Map(
                    "name", site.Has("label") ? String(site["label"]) : id,
                    "value", id,
                    "id", id,
                    "homeUrl", site.Has("homeUrl") ? String(site["homeUrl"]) : ""
                ))
            }
        } catch {
        }
    }
    if !rows.Length
        rows.Push(Map("name", "DeepSeek", "value", "deepseek", "id", "deepseek", "homeUrl", "https://chat.deepseek.com/"))
    return rows
}

_UnifiedWb_BuildCliEnginePayload() {
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
    try {
        for eng in NiumaTtyd_CliEngineList() {
            if (eng = "studio_cli")
                continue
            payload.Push(Map("name", labels.Has(eng) ? labels[eng] : eng, "value", eng, "iconUrl", ""))
        }
    } catch {
    }
    if !payload.Length
        payload.Push(Map("name", "Codex", "value", "codex_cli", "iconUrl", ""))
    return payload
}

_UnifiedWb_GetLayoutPref(key, default := "") {
    try {
        global ConfigFile
        if IsSet(ConfigFile) && ConfigFile != "" {
            v := IniRead(ConfigFile, "UnifiedWorkbench", key, default)
            if (Trim(String(v)) != "")
                return v
        }
    } catch {
    }
    return default
}

_UnifiedWb_ClampLayoutInt(raw, minVal, maxVal, fallback) {
    try {
        n := Integer(raw)
    } catch {
        n := fallback
    }
    if (n < minVal)
        return minVal
    if (n > maxVal)
        return maxVal
    return n
}

_UnifiedWb_SessionPath() {
    if FuncExists("Nmer_UnifiedWorkbenchSessionPath")
        return Nmer_UnifiedWorkbenchSessionPath()
    return A_ScriptDir . "\Data\runtime\app\unified_workbench_session.json"
}

_UnifiedWb_LoadSession() {
    path := _UnifiedWb_SessionPath()
    if !FileExist(path)
        return Map()
    try {
        if FuncExists("Jxon_Load") {
            raw := FileRead(path, "UTF-8")
            if (Trim(raw) != "") {
                loaded := Jxon_Load(raw)
                if (loaded is Map)
                    return loaded
            }
        }
    } catch as e {
        UnifiedWb_Trace("session_load", false, Map("error", e.Message))
    }
    return Map()
}

_UnifiedWb_PersistSession(st := 0) {
    global g_UnifiedWb_LastSessionSnapshot
    snap := (st is Map) ? st : g_UnifiedWb_LastSessionSnapshot
    if !(snap is Map) || !snap.Has("columns")
        return false
    path := _UnifiedWb_SessionPath()
    dir := ""
    if RegExMatch(path, "^(.*)\\[^\\]+$", &m)
        dir := m[1]
    if (dir != "" && !DirExist(dir))
        try DirCreate(dir)
    out := Map()
    for k, v in snap
        out[String(k)] := v
    out["savedAt"] := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    try {
        if FuncExists("Jxon_Dump") {
            json := Jxon_Dump(out)
            try FileDelete(path)
            FileAppend(json, path, "UTF-8")
            g_UnifiedWb_LastSessionSnapshot := out
            return true
        }
    } catch as e {
        UnifiedWb_Trace("session_save", false, Map("error", e.Message))
    }
    return false
}

UnifiedWb_PushInit(forceReset := false) {
    global g_UnifiedWb_InitialIntent, g_UnifiedWb_PendingKeyword
    payload := Map(
        "type", "init",
        "themeMode", _UnifiedWb_GetThemeMode(),
        "aiEngines", _UnifiedWb_BuildAiEnginePayload(),
        "cliEngines", _UnifiedWb_BuildCliEnginePayload(),
        "initialIntent", g_UnifiedWb_InitialIntent,
        "keyword", Trim(String(g_UnifiedWb_PendingKeyword)),
        "defaultAiColumns", _UnifiedWb_ClampLayoutInt(_UnifiedWb_GetLayoutPref("DefaultAiColumns", "2"), 1, 8, 2),
        "defaultCliColumns", _UnifiedWb_ClampLayoutInt(_UnifiedWb_GetLayoutPref("DefaultCliColumns", "1"), 0, 3, 1),
        "maxColumns", _UnifiedWb_ClampLayoutInt(_UnifiedWb_GetLayoutPref("MaxColumns", "8"), 3, 21, 8),
        "maxVirtualColumns", _UnifiedWb_ClampLayoutInt(_UnifiedWb_GetLayoutPref("MaxVirtualColumns", "21"), 3, 21, 21),
        "virtualColumnThreshold", _UnifiedWb_ClampLayoutInt(_UnifiedWb_GetLayoutPref("VirtualColumnThreshold", "9"), 9, 21, 9),
        "maxActiveAiEmbeds", ScWebLlm_UnifiedMaxActiveAiEmbedsConfigured(),
        "effectiveMaxActiveAiEmbeds", ScWebLlm_UnifiedMaxActiveAiEmbeds(),
        "memoryTierCap", ScWebLlm_UnifiedMemoryTierCap(),
        "ignoreMemoryTierCap", ScWebLlm_UnifiedIgnoreMemoryTierCap(),
        "forceReset", !!forceReset
    )
    if !forceReset {
        saved := _UnifiedWb_LoadSession()
        if (saved is Map) && saved.Has("columns") {
            cols := saved["columns"]
            if (cols is Array) && cols.Length
                payload["savedSession"] := saved
        }
    }
    UnifiedWb_PostCriticalJson(payload, true)
    if UnifiedWb_IsVisible() && forceReset
        _UnifiedWb_ScheduleBootstrapOnce(220)
}

_UnifiedWb_EnsureCli(engine := "codex_cli") {
    global g_UnifiedWb_WV2
    if !IsObject(g_UnifiedWb_WV2)
        return
    eng := Trim(String(engine))
    if (eng = "")
        eng := "codex_cli"
    try eng := NiumaTtyd_NormalizeEngine(eng)
    catch {
        eng := "codex_cli"
    }
    SetTimer(NiumaTtyd_DeferredOpenJob.Bind("uwb_" . eng, eng, g_UnifiedWb_WV2), -10)
}

_UnifiedWb_ScheduleAiEmbedRetries(parentHwnd := 0) {
    global g_UnifiedWb_Visible, g_UnifiedWb_AiRetryGeneration
    if !g_UnifiedWb_Visible
        return
    ph := Integer(parentHwnd)
    if !ph {
        try {
            g := UnifiedWb_GetGui()
            if IsObject(g)
                ph := g.Hwnd
        } catch {
        }
    }
    if !ph
        return
    gen := ++g_UnifiedWb_AiRetryGeneration
    SetTimer(_UnifiedWb_AiEmbedRetryTick.Bind(ph, gen, 1), -220)
    SetTimer(_UnifiedWb_AiEmbedRetryTick.Bind(ph, gen, 2), -700)
    SetTimer(_UnifiedWb_AiEmbedRetryTick.Bind(ph, gen, 3), -1500)
    SetTimer(_UnifiedWb_AiEmbedRetryTick.Bind(ph, gen, 4), -2800)
}

_UnifiedWb_AiEmbedRetryTick(ph, gen, pass, *) {
    global g_UnifiedWb_Visible, g_UnifiedWb_AiRetryGeneration
    if (gen != g_UnifiedWb_AiRetryGeneration)
        return
    if !g_UnifiedWb_Visible
        return
    hwnd := Integer(ph)
    if !hwnd
        return
    if FuncExists("UnifiedWb_FinalizeAiEmbed")
        UnifiedWb_FinalizeAiEmbed(hwnd, pass = 1)
}

_UnifiedWb_OnWebMessage(sender, args) {
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
    if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown()
        return
    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ = "" && msg.Has("action"))
        typ := String(msg["action"])
    if (typ = "webLlmLayoutPause") {
        if FuncExists("SearchCenterWebLlm_SetUnifiedEmbedLayoutPaused") {
            paused := msg.Has("paused") ? !!msg["paused"] : true
            try SearchCenterWebLlm_SetUnifiedEmbedLayoutPaused(paused)
            catch {
            }
        }
        return
    }
    if (typ = "unifiedColumnResizeBegin") {
        leftColId := msg.Has("leftColId") ? String(msg["leftColId"]) : ""
        rightColId := msg.Has("rightColId") ? String(msg["rightColId"]) : ""
        startLeftW := msg.Has("startLeftW") ? Integer(msg["startLeftW"]) : 0
        startRightW := msg.Has("startRightW") ? Integer(msg["startRightW"]) : 0
        if (leftColId != "" && rightColId != "" && FuncExists("ScWebLlm_BeginUnifiedColumnResizeDrag")) {
            try ScWebLlm_BeginUnifiedColumnResizeDrag(leftColId, rightColId, startLeftW, startRightW, true)
            catch {
            }
        }
        return
    }
    if (typ = "unifiedColumnResizeEnd") {
        if FuncExists("ScWebLlm_FinishUnifiedColumnResizeDrag") {
            try ScWebLlm_FinishUnifiedColumnResizeDrag()
            catch {
            }
        } else if FuncExists("ScWebLlm_SetUnifiedColumnResizeInteract") {
            try ScWebLlm_SetUnifiedColumnResizeInteract(false)
            catch {
            }
        }
        return
    }
    if (typ = "unifiedColumnResizeInteract") {
        if FuncExists("ScWebLlm_SetUnifiedColumnResizeInteract") {
            active := msg.Has("active") ? !!msg["active"] : true
            try ScWebLlm_SetUnifiedColumnResizeInteract(active)
            catch {
            }
        }
        return
    }
    if (typ = "webLlmLayoutLive") {
        if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown()
            return
        if FuncExists("ScWebLlm_IsUnifiedScEmbedLayout") && ScWebLlm_IsUnifiedScEmbedLayout()
            return
        if msg.Has("allColumns") && FuncExists("ScWebLlm_UnifiedSetWebColumns") {
            try ScWebLlm_UnifiedSetWebColumns(msg["allColumns"])
            catch {
            }
        }
        if msg.Has("aiColumns") && FuncExists("SearchCenterWebLlm_ApplyUnifiedMultiColumnFromWeb") {
            maxActive := msg.Has("maxActiveAiEmbeds") ? Integer(msg["maxActiveAiEmbeds"]) : 0
            focusSid := msg.Has("focusSiteId") ? Trim(String(msg["focusSiteId"])) : ""
            embedVp := (msg.Has("embedViewport") && (msg["embedViewport"] is Map)) ? msg["embedViewport"] : 0
            try SearchCenterWebLlm_ApplyUnifiedMultiColumnFromWeb(msg["aiColumns"], maxActive, focusSid, embedVp, true)
            catch {
            }
        }
        if FuncExists("SearchCenterWebLlm_ApplyUnifiedColumnResizeRails") {
            try SearchCenterWebLlm_ApplyUnifiedColumnResizeRails()
            catch {
            }
        }
        return
    }
    if (typ = "layoutSnapshot") {
        if msg.Has("session") && (msg["session"] is Map) {
            global g_UnifiedWb_LastSessionSnapshot
            g_UnifiedWb_LastSessionSnapshot := msg["session"]
            _UnifiedWb_PersistSession(msg["session"])
        }
        return
    }
    if (typ = "ready") {
        global g_UnifiedWb_Ready
        g_UnifiedWb_Ready := true
        if UnifiedWb_IsVisible() {
            UnifiedWb_PushInit(false)
            _UnifiedWb_ScheduleBootstrapOnce(180)
        }
        return
    }
    if (typ = "close") {
        UnifiedWb_Hide()
        return
    }
    if (typ = "column_focus") {
        global g_UnifiedWb_FocusedColumnType, g_UnifiedWb_FocusedCliEngine, g_UnifiedWb_FocusedAiSite
        if msg.Has("columnType")
            g_UnifiedWb_FocusedColumnType := String(msg["columnType"])
        if msg.Has("engine")
            g_UnifiedWb_FocusedCliEngine := Trim(String(msg["engine"]))
        if msg.Has("siteId")
            g_UnifiedWb_FocusedAiSite := Trim(String(msg["siteId"]))
        return
    }
    if (typ = "column_reload") {
        if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown()
            return
        colType := msg.Has("columnType") ? String(msg["columnType"]) : ""
        if (colType = "ai") {
            sid := msg.Has("siteId") ? Trim(String(msg["siteId"])) : ""
            if (sid != "" && FuncExists("SearchCenterWebLlm_ReloadSites")) {
                try SearchCenterWebLlm_ReloadSites([sid])
                catch {
                }
            }
        } else if (colType = "cli") {
            global g_UnifiedWb_WV2
            reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
            eng := msg.Has("engine") ? Trim(String(msg["engine"])) : "codex_cli"
            try eng := NiumaTtyd_NormalizeEngine(eng)
            catch {
                eng := "codex_cli"
            }
            if IsObject(g_UnifiedWb_WV2) && FuncExists("NiumaTtyd_DeferredRestartJob")
                SetTimer(NiumaTtyd_DeferredRestartJob.Bind(reqId, eng, g_UnifiedWb_WV2), -10)
        }
        return
    }
    if (typ = "broadcast_ai") {
        text := msg.Has("text") ? String(msg["text"]) : ""
        engines := []
        if msg.Has("siteIds") && (msg["siteIds"] is Array) {
            for sid in msg["siteIds"] {
                s := Trim(String(sid))
                if (s != "")
                    engines.Push(s)
            }
        }
        if !engines.Length {
            global g_SCWebLlm_LayoutSiteIds
            if IsObject(g_SCWebLlm_LayoutSiteIds) && g_SCWebLlm_LayoutSiteIds.Length
                engines := g_SCWebLlm_LayoutSiteIds.Clone()
        }
        if (text != "" && FuncExists("SearchCenterWebLlm_BroadcastSearch")) {
            try SearchCenterWebLlm_BroadcastSearch(text, engines)
            catch {
            }
        }
        return
    }
    if (typ = "ensure_cli") {
        global g_UnifiedWb_WV2
        if !IsObject(g_UnifiedWb_WV2)
            return
        eng := msg.Has("engine") ? Trim(String(msg["engine"])) : "codex_cli"
        reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
        try eng := NiumaTtyd_NormalizeEngine(eng)
        catch {
            eng := "codex_cli"
        }
        SetTimer(NiumaTtyd_DeferredOpenJob.Bind(reqId, eng, g_UnifiedWb_WV2), -10)
        return
    }
    if (typ = "send_cli") {
        text := msg.Has("text") ? String(msg["text"]) : ""
        eng := msg.Has("engine") ? Trim(String(msg["engine"])) : ""
        ScCli_SendToCLI(text, eng)
        return
    }
    if (typ = "send_ai") {
        text := msg.Has("text") ? String(msg["text"]) : ""
        sid := msg.Has("siteId") ? Trim(String(msg["siteId"])) : ""
        if (sid != "" && FuncExists("SearchCenterWebLlm_FocusSite"))
            try SearchCenterWebLlm_FocusSite(sid)
        if (text != "" && FuncExists("SearchCenterWebLlm_BroadcastSearch")) {
            engines := []
            if (sid != "")
                engines.Push(sid)
            try SearchCenterWebLlm_BroadcastSearch(text, engines)
        }
        return
    }
    if (typ = "webLlmBootstrap") {
        hasRect := msg.Has("rect") && (msg["rect"] is Map)
        hasAiCols := msg.Has("aiColumns")
        if hasRect && !hasAiCols {
            if FuncExists("SearchCenterWebLlmBridge_HandleMessage") {
                SearchCenterWebLlmBridge_HandleMessage(msg, "unified_workbench")
            }
            return
        }
        if hasAiCols && FuncExists("ScWebLlm_IsUnifiedScEmbedLayout") && ScWebLlm_IsUnifiedScEmbedLayout() {
            UnifiedWb_Trace("web_bootstrap_msg", true, Map("reason", "sc_embed_skip_aiColumns"))
            return
        }
        _UnifiedWb_HandleWebLlmBootstrap(msg)
        return
    }
    if (typ = "webEmbedDebugAction") {
        _UnifiedWb_HandleDebugAction(msg)
        return
    }
    if FuncExists("SearchCenterWebLlmBridge_HandleMessage") {
        if SearchCenterWebLlmBridge_HandleMessage(msg, "unified_workbench")
            return
    }
    if FuncExists("SearchCenterCliBridge_HandleMessage") {
        global g_UnifiedWb_WV2
        if SearchCenterCliBridge_HandleMessage(msg, "unified_workbench", g_UnifiedWb_WV2)
            return
    }
}

_UnifiedWb_HandleWebLlmBootstrap(msg) {
    global g_UnifiedWb_LastWebBootstrapSig, g_UnifiedWb_LastWebBootstrapTick, g_UnifiedWb_Gui, g_SCWebLlm_EmbedBootstrapped
    if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown()
        return false
    if !(msg is Map)
        return false
    if FuncExists("ScWebLlm_IsUnifiedScEmbedLayout") && ScWebLlm_IsUnifiedScEmbedLayout() {
        UnifiedWb_Trace("web_bootstrap_msg", true, Map("reason", "sc_embed_layout_active"))
        return true
    }
    if !msg.Has("aiColumns") {
        UnifiedWb_Trace("web_bootstrap_msg", false, Map("reason", "missing_aiColumns"))
        return false
    }
    maxActive := msg.Has("maxActiveAiEmbeds") ? Integer(msg["maxActiveAiEmbeds"]) : 0
    focusSid := msg.Has("focusSiteId") ? Trim(String(msg["focusSiteId"])) : ""
    cols := msg["aiColumns"]
    colCount := 0
    if (cols is Array) {
        try colCount := cols.Length
        catch {
            colCount := 0
        }
    }
    sig := _UnifiedWb_WebBootstrapSig(cols, maxActive, focusSid, msg.Has("embedViewport") ? msg["embedViewport"] : 0)
    nowTick := A_TickCount
    if (sig != "" && sig = g_UnifiedWb_LastWebBootstrapSig && nowTick - g_UnifiedWb_LastWebBootstrapTick < 1200)
        return true
    g_UnifiedWb_LastWebBootstrapSig := sig
    g_UnifiedWb_LastWebBootstrapTick := nowTick
    UnifiedWb_Trace("web_bootstrap_msg", true, Map("cols", colCount, "focus", focusSid))
    embedVp := (msg.Has("embedViewport") && (msg["embedViewport"] is Map)) ? msg["embedViewport"] : 0
    if FuncExists("UnifiedWb_RefreshRasterizationScale") {
        try UnifiedWb_RefreshRasterizationScale()
        catch {
        }
    }
    if FuncExists("ScWebLlm_NotifyUnifiedHostComposition") {
        try ScWebLlm_NotifyUnifiedHostComposition()
        catch {
        }
    }
    if FuncExists("SearchCenterWebLlm_ApplyUnifiedMultiColumnFromWeb") {
        try SearchCenterWebLlm_ApplyUnifiedMultiColumnFromWeb(cols, maxActive, focusSid, embedVp)
        catch as e {
            UnifiedWb_Trace("web_bootstrap_apply", false, Map("error", e.Message))
            return false
        }
    }
    if msg.Has("allColumns") && FuncExists("ScWebLlm_UnifiedSetWebColumns") {
        try ScWebLlm_UnifiedSetWebColumns(msg["allColumns"])
        catch {
        }
    }
    if FuncExists("SearchCenterWebLlm_ApplyUnifiedColumnResizeRails") {
        try SearchCenterWebLlm_ApplyUnifiedColumnResizeRails()
        catch {
        }
    }
    if FuncExists("UnifiedWb_StoreBootstrapFromWeb")
        UnifiedWb_StoreBootstrapFromWeb(cols, maxActive, focusSid, embedVp)
    if FuncExists("SearchCenterWebLlm_PrepareForWebModeShow") {
        try SearchCenterWebLlm_PrepareForWebModeShow(false)
        catch {
        }
    } else if FuncExists("SearchCenterWebLlm_MarkEmbedRequested")
        SearchCenterWebLlm_MarkEmbedRequested()
    ph := 0
    if IsObject(g_UnifiedWb_Gui) {
        try ph := g_UnifiedWb_Gui.Hwnd
        catch {
        }
    }
    if !ph
        return false
    sitesReady := false
    if FuncExists("SearchCenterWebLlm_HasReadySites") {
        try sitesReady := SearchCenterWebLlm_HasReadySites()
        catch {
        }
    }
    if sitesReady {
        g_SCWebLlm_EmbedBootstrapped := true
        if FuncExists("UnifiedWb_EnsureAiEmbedLayering") {
            try UnifiedWb_EnsureAiEmbedLayering()
            catch {
            }
        }
        return true
    }
    navHome := !g_SCWebLlm_EmbedBootstrapped
    if FuncExists("UnifiedWb_ScheduleAiEmbedFinalize")
        UnifiedWb_ScheduleAiEmbedFinalize(ph, navHome)
    else if FuncExists("SearchCenterWebLlm_EnsureMissingSites") {
        try SearchCenterWebLlm_EnsureMissingSites(navHome, ph)
        catch {
        }
    }
    return true
}

_UnifiedWb_WebBootstrapSig(cols, maxActive := 0, focusSid := "", embedViewport := 0) {
    if !(cols is Array)
        return ""
    vpPart := ""
    if (embedViewport is Map)
        vpPart := Integer(embedViewport.Get("left", 0)) . "," . Integer(embedViewport.Get("top", 0)) . ","
            . Integer(embedViewport.Get("width", 0)) . "," . Integer(embedViewport.Get("height", 0)) . "|"
    body := ""
    for item in cols {
        if !(item is Map)
            continue
        sid := item.Has("siteId") ? Trim(String(item["siteId"])) : ""
        rect := item.Has("rect") ? item["rect"] : item
        if !(rect is Map)
            continue
        part := sid . "@" . Integer(rect.Get("left", 0)) . "," . Integer(rect.Get("top", 0)) . "," . Integer(rect.Get("width", 0)) . "," . Integer(rect.Get("height", 0))
        body .= (body = "" ? "" : "|") . part
    }
    return vpPart . Trim(String(focusSid)) . "|" . Integer(maxActive) . "|" . body
}

_UnifiedWb_HandleDebugAction(msg) {
    if !(msg is Map)
        return
    act := msg.Has("action") ? StrLower(Trim(String(msg["action"]))) : ""
    result := Map("type", "webEmbedDebugActionResult", "action", act, "ok", false)
    switch act {
        case "open_log_dir":
            if FuncExists("Nmer_OpenDebugDir") {
                try result["ok"] := !!Nmer_OpenDebugDir()
                catch {
                    result["ok"] := false
                }
            }
        case "rebootstrap_sc_embed":
            global g_SCWebLlm_EmbedBootstrapped, g_SCWebLlm_ContentRectReady
            if FuncExists("ScWebLlm_ClearUnifiedMultiColumnRects") {
                try ScWebLlm_ClearUnifiedMultiColumnRects()
                catch {
                }
            }
            g_SCWebLlm_EmbedBootstrapped := false
            g_SCWebLlm_ContentRectReady := false
            if FuncExists("SearchCenterWebLlm_PrepareForWebModeShow") {
                try SearchCenterWebLlm_PrepareForWebModeShow(false)
                catch {
                }
            }
            UnifiedWb_PostCriticalJson(Map("type", "hostOpenBootstrap", "reason", "debug_sc_embed_rebootstrap", "includeCli", false), true)
            result["ok"] := true
            UnifiedWb_Trace("debug_sc_embed_rebootstrap", true, Map())
        case "rebootstrap":
            global g_UnifiedWb_Gui, g_SCWebLlm_EmbedBootstrapped
            ph := 0
            if IsObject(g_UnifiedWb_Gui) {
                try ph := g_UnifiedWb_Gui.Hwnd
                catch {
                }
            }
            if msg.Has("aiColumns") && FuncExists("UnifiedWb_StoreBootstrapFromWeb") {
                maxActive := msg.Has("maxActiveAiEmbeds") ? Integer(msg["maxActiveAiEmbeds"]) : 0
                focusSid := msg.Has("focusSiteId") ? Trim(String(msg["focusSiteId"])) : ""
                try UnifiedWb_StoreBootstrapFromWeb(msg["aiColumns"], maxActive, focusSid)
                catch as e {
                    result["error"] := e.Message
                }
            }
            if FuncExists("UnifiedWb_ReplayStoredBootstrap") {
                try result["ok"] := !!UnifiedWb_ReplayStoredBootstrap(true)
                catch as e {
                    result["error"] := e.Message
                    result["ok"] := false
                }
            }
            UnifiedWb_PostCriticalJson(Map("type", "hostOpenBootstrap", "reason", "debug_rebootstrap", "includeCli", true), true)
            UnifiedWb_Trace("debug_rebootstrap", !!result["ok"], Map("hwnd", ph))
        case "copy_trace":
            text := ""
            if FuncExists("SearchCenterWebLlm_BuildDebugSnapshot") {
                try {
                    snap := SearchCenterWebLlm_BuildDebugSnapshot(msg.Has("client") ? msg["client"] : Map())
                    text := "=== 统一工作台诊断 " . snap.Get("ts", A_Now) . " ===`n"
                    flags := snap.Get("flags", Map())
                    if (flags is Map) {
                        for k, v in flags
                            text .= k . "=" . String(v) . " "
                        text .= "`n"
                    }
                    u := snap.Get("unified", Map())
                    if (u is Map) {
                        text .= "unified.multiRect=" . (u.Get("multiRectActive", false) ? "1" : "0")
                        text .= " layoutReady=" . (u.Get("layoutReady", false) ? "1" : "0")
                        text .= " overlay=" . (u.Get("ownerOverlay", false) ? "1" : "0") . "`n"
                    }
                    issues := snap.Get("issues", [])
                    if (issues is Array) {
                        for iss in issues {
                            if !(iss is Map)
                                continue
                            text .= "[!" . iss.Get("level", "?") . "] " . iss.Get("msg", "") . "`n"
                        }
                    }
                    logs := snap.Get("logs", Map())
                    if (logs is Map) && logs.Has("uwb")
                        text .= "--- uwb log ---`n" . String(logs["uwb"]) . "`n"
                    if (logs is Map) && logs.Has("webLlm")
                        text .= "--- webLlm log ---`n" . String(logs["webLlm"]) . "`n"
                } catch as e {
                    text := "snapshot error: " . e.Message
                }
            }
            if (text != "") {
                try {
                    A_Clipboard := text
                    result["ok"] := true
                } catch {
                    result["ok"] := false
                }
            }
        default:
            result["error"] := "unknown action"
    }
    UnifiedWb_PostJson(result, true)
}

UnifiedWb_Show(meta := 0) {
    if FuncExists("SurfaceIntent_OpenUnifiedWorkbenchRedirect")
        return SurfaceIntent_OpenUnifiedWorkbenchRedirect(meta)
    if FuncExists("SurfaceIntent_RouteExternalOpen") && SurfaceIntent_RouteExternalOpen("unified_workbench", meta)
        return true
    global g_UnifiedWb_Visible, g_UnifiedWb_Ready, g_UnifiedWb_PendingKeyword, g_UnifiedWb_InitialIntent
    m := (meta is Map) ? meta : Map()
    if m.Has("keyword")
        g_UnifiedWb_PendingKeyword := String(m["keyword"])
    if m.Has("initialIntent")
        g_UnifiedWb_InitialIntent := (String(m["initialIntent"]) = "cli") ? "cli" : "ai"
    else if m.Has("intent")
        g_UnifiedWb_InitialIntent := (String(m["intent"]) = "cli") ? "cli" : "ai"
    reqId := 0
    try {
        reqId := SurfaceManager_Request("unified_workbench", "open", "UnifiedWb_Show", m)
        SurfaceManager_BeforeOpen("unified_workbench", "UnifiedWb_Show", Map("requestId", reqId))
        SurfaceManager_RegisterSurface("unified_workbench")
    } catch {
    }
    if FuncExists("Nmer_Telemetry_MarkSurfaceOpen") {
        try Nmer_Telemetry_MarkSurfaceOpen("unified_workbench", Map("source", "UnifiedWb_Show"))
        catch {
        }
    }
    if !g_UnifiedWb_Gui
        UnifiedWb_Init()
    if !g_UnifiedWb_Gui
        return false
    UnifiedWb_BindScWebLlmHost()
    if FuncExists("ScWebLlm_ResetUnifiedColumnResizeState") {
        try ScWebLlm_ResetUnifiedColumnResizeState()
        catch {
        }
    }
    resuming := false
    if FuncExists("SearchCenterWebLlm_UnifiedHasResumableSites") {
        try resuming := SearchCenterWebLlm_UnifiedHasResumableSites()
        catch {
            resuming := false
        }
    }
    UnifiedWb_Trace("show", true, Map("intent", g_UnifiedWb_InitialIntent, "resuming", resuming ? 1 : 0))
    if resuming {
        if FuncExists("SearchCenterWebLlm_ResumeUnifiedEmbed") {
            try SearchCenterWebLlm_ResumeUnifiedEmbed(g_UnifiedWb_Gui.Hwnd)
            catch {
            }
        }
    } else {
        if FuncExists("SearchCenterWebLlm_TeardownEmbed") {
            try SearchCenterWebLlm_TeardownEmbed()
            catch {
            }
        }
    }
    if FuncExists("SearchCenterWebLlm_PrepareForWebModeShow") {
        try SearchCenterWebLlm_PrepareForWebModeShow(false)
        catch {
        }
    } else if FuncExists("SearchCenterWebLlm_MarkEmbedRequested")
        SearchCenterWebLlm_MarkEmbedRequested()
    ScreenW := SysGet(0)
    ScreenH := SysGet(1)
    w := Min(1520, ScreenW - 60)
    h := Min(860, ScreenH - 60)
    x := (ScreenW - w) // 2
    y := (ScreenH - h) // 2
    try g_UnifiedWb_Gui.Show("x" . x . " y" . y . " w" . w . " h" . h)
    catch {
        try g_UnifiedWb_Gui.Show("Maximize")
        catch {
        }
    }
    g_UnifiedWb_Visible := true
    g_UnifiedWb_LastShown := A_TickCount
    try WebView2_NotifyShown(g_UnifiedWb_WV2)
    _UnifiedWb_RefreshComposition()
    SetTimer(_UnifiedWb_RefreshComposition, -120)
    UnifiedWb_PushInit(!resuming)
    _UnifiedWb_ScheduleBootstrapOnce(resuming ? 100 : 160)
    SetTimer(UnifiedWb_EnsureAiEmbedLayering.Bind(), -260)
    SetTimer(UnifiedWb_EnsureAiEmbedLayering.Bind(), -900)
    SetTimer(_UnifiedWb_BootstrapDefaultCliEngines, -180)
    SetTimer(UnifiedWb_ScheduleStoredBootstrapReplay.Bind(), -1800)
    try SurfaceManager_ObserveShow("unified_workbench", Map("entry", "UnifiedWb_Show", "requestId", reqId))
    try LegacyGuard_RequestFocus("UnifiedWorkbench", g_UnifiedWb_Gui.Hwnd, 40, "unified_workbench_show")
    return true
}

UnifiedWb_Hide(*) {
    global g_UnifiedWb_Visible, g_UnifiedWb_Gui, g_UnifiedWb_LastSessionSnapshot
    if !g_UnifiedWb_Visible && !g_UnifiedWb_Gui
        return false
    if FuncExists("SurfaceIntent_RouteExternalClose") && SurfaceIntent_RouteExternalClose("unified_workbench")
        return true
    if g_UnifiedWb_LastSessionSnapshot is Map
        _UnifiedWb_PersistSession(g_UnifiedWb_LastSessionSnapshot)
    g_UnifiedWb_Visible := false
    _UnifiedWb_CancelBootstrapTimers()
    if FuncExists("SearchCenterWebLlm_SuspendUnifiedEmbed") {
        try SearchCenterWebLlm_SuspendUnifiedEmbed()
        catch {
            if FuncExists("SearchCenterWebLlm_TeardownEmbed")
                try SearchCenterWebLlm_TeardownEmbed()
        }
    } else if FuncExists("SearchCenterWebLlm_TeardownEmbed") {
        try SearchCenterWebLlm_TeardownEmbed()
    }
    UnifiedWb_RestoreScWebLlmHost()
    if g_UnifiedWb_Gui {
        try g_UnifiedWb_Gui.Hide()
        catch {
        }
    }
    try WebView2_NotifyHidden(g_UnifiedWb_WV2)
    if FuncExists("Nmer_Telemetry_MarkSurfaceClose") {
        try Nmer_Telemetry_MarkSurfaceClose("unified_workbench", Map("source", "UnifiedWb_Hide"))
        catch {
        }
    }
    try SurfaceManager_ObserveHide("unified_workbench", Map("entry", "UnifiedWb_Hide"))
    return true
}

UnifiedWb_Dispose(reason := "") {
    UnifiedWb_Hide()
    global g_UnifiedWb_Gui, g_UnifiedWb_Ctrl, g_UnifiedWb_WV2, g_UnifiedWb_Ready
    if IsObject(g_UnifiedWb_Ctrl) {
        try g_UnifiedWb_Ctrl.Close()
        catch {
        }
    }
    if IsObject(g_UnifiedWb_Gui) {
        try g_UnifiedWb_Gui.Destroy()
        catch {
        }
    }
    g_UnifiedWb_Gui := 0
    g_UnifiedWb_Ctrl := 0
    g_UnifiedWb_WV2 := 0
    g_UnifiedWb_Ready := false
    try SurfaceManager_ObserveClose("unified_workbench", Map("entry", "UnifiedWb_Dispose", "reason", reason))
}

UnifiedWorkbenchRouter_Open(meta := 0) {
    if FuncExists("SurfaceIntent_OpenUnifiedWorkbenchRedirect")
        return SurfaceIntent_OpenUnifiedWorkbenchRedirect(meta)
    return UnifiedWb_Show(meta)
}

UnifiedWorkbenchRouter_Hide(*) {
    return UnifiedWb_Hide()
}

UnifiedWorkbenchRouter_Dispose(reason := "") {
    UnifiedWb_Dispose(reason)
}
