#Requires AutoHotkey v2.0
#Include FuncExists.ahk

; CommandPaletteCore — Raycast 风格独立命令面板（WebView2，替代 nmer-wails-input.exe）

global CommandPaletteUseWebView := true
global CommandPaletteUseNativeEdit := false

global g_CmdPal_Gui := 0
global g_CmdPal_WV2 := 0
global g_CmdPal_Ctrl := 0
global g_CmdPal_Ready := false
global g_CmdPal_Visible := false
global g_CmdPal_Width := 760
global g_CmdPal_MinHeight := 120
global g_CmdPal_CurrentHeight := 120
global g_CmdPal_CornerRadius := 20
global g_CmdPal_Revealed := false
global g_CmdPal_AnchorX := 0
global g_CmdPal_AnchorY := 0
global g_CmdPal_HasAnchor := false

global g_CmdPal_ExecCache := ""
global g_CmdPal_ExecDirty := false
global g_CmdPal_ExecFileMtime := ""
global g_CmdPal_PendingShow := false
global g_CmdPal_ShowRetryCount := 0
global g_CmdPal_HtmlVer := ""
global g_CmdPal_TurboReqGen := 0
global g_CmdPal_TurboInFlight := false
global g_CmdPal_TurboWhr := 0
global g_CmdPal_TurboMeta := 0
global g_CmdPal_TurboPollToken := 0
global g_CmdPal_TurboPendingMeta := 0
global g_CmdPal_EmptyCache := 0
global g_CmdPal_EmptyCacheTick := 0
global g_CmdPal_LiveAiKeys := 0
global g_CmdPal_LiveLlmFromFtb := Map()
global g_CmdPal_LiveActiveProvider := ""
global g_CmdPal_PendingAiSend := 0
global g_CmdPal_AiSession := 0
global g_CmdPal_AiMorphHeight := 380
global g_CmdPal_AiStreamGen := 0
global g_CmdPal_AiMorphAnimToken := 0
global g_CmdPal_AiWatchdogToken := 0
global g_CmdPal_AiRetryToken := 0
global g_CmdPal_Oc5ProbeResolver := 0
global g_CmdPal_Oc5ProbeReqId := ""
global g_CmdPal_GrayProbeResolver := 0
global g_CmdPal_GrayProbeReqId := ""
global g_CmdPal_AdpProbeResolver := 0
global g_CmdPal_AdpProbeReqId := ""
global g_CmdPal_AiPollToken := 0
global g_CmdPal_AiLastCard := 0

CommandPalette_AiLog(event, detail := "") {
    ev := Trim(String(event))
    if (ev = "")
        ev := "event"
    body := Trim(String(detail))
    ts := ""
    try ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss.fff")
    catch {
        ts := A_Now
    }
    line := "[" . ts . "][" . ev . "] " . body
    try OutputDebug("[CmdPalAI] " . line . "`n")
    catch {
    }
    if (FuncExists("NMER_Log")) {
        try Func("NMER_Log").Call("cmdpal_ai", ev, body)
        catch {
        }
    }
    try {
        path := FuncExists("Nmer_DebugPath") ? Nmer_DebugPath("command_palette_ai.log") : (A_ScriptDir . "\Cache\debug\command_palette_ai.log")
        dir := ""
        SplitPath(path, , &dir)
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)
        FileAppend(line . "`r`n", path, "UTF-8")
    } catch {
    }
}

CommandPalette_ResolveActivationMode() {
    global AppearanceActivationMode
    m := Trim(String(AppearanceActivationMode))
    if (m = "")
        m := "toolbar"
    try {
        if (FuncExists("NormalizeAppearanceActivationMode"))
            m := Trim(String(NormalizeAppearanceActivationMode(m)))
        else if (FuncExists("FloatingToolbar_NormalizeAppearanceMode"))
            m := Trim(String(FloatingToolbar_NormalizeAppearanceMode(m)))
    } catch {
    }
    m := Trim(String(m))
    if (m != "toolbar" && m != "hole" && m != "bubble" && m != "tray")
        m := "toolbar"
    return m
}

CommandPalette_ForceOpenNiumaDrawer() {
    global g_FTB_PendingOpenNiumaDrawer, g_FTB_NiumaHandoffOpening, FloatingToolbarChatDrawerOpen, g_FTB_WV2, g_FTB_WV2_Ready
    g_FTB_PendingOpenNiumaDrawer := true
    g_FTB_NiumaHandoffOpening := true
    try FloatingToolbarSetChatDrawerState(true, true)
    catch as eSet {
        CommandPalette_AiLog("force_drawer_set_err", eSet.Message)
    }
    if (g_FTB_WV2 && g_FTB_WV2_Ready) {
        try FloatingToolbar_NotifyWebDrawerState(true)
        catch {
        }
    }
    try FloatingToolbar_OpenNiumaChatDrawer(true)
    catch as eOpen {
        CommandPalette_AiLog("force_drawer_open_err", eOpen.Message)
    }
    CommandPalette_AiLog("force_drawer_done", "drawerOpen=" . (FloatingToolbarChatDrawerOpen ? 1 : 0) . " | " . CommandPalette_AiStateSnapshot())
}

CommandPalette_AiStateSnapshot() {
    global AppearanceActivationMode, FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarChatDrawerOpen
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_WaitingUiFinishedReveal, g_FTB_UI_Ready
    global g_FTB_PendingOpenNiumaDrawer, g_FTB_PendingNiumaCompose, g_FTB_OverlaySuppressedByPageDock, g_FTB_NiumaHandoffOpening
    mode := CommandPalette_ResolveActivationMode()
    pendN := 0
    if (g_FTB_PendingNiumaCompose is Array)
        pendN := g_FTB_PendingNiumaCompose.Length
    guiHwnd := 0
    if IsObject(FloatingToolbarGUI) {
        try guiHwnd := FloatingToolbarGUI.Hwnd
        catch {
        }
    }
    return "actMode=" . String(AppearanceActivationMode)
        . " normMode=" . mode
        . " guiHwnd=" . guiHwnd
        . " ftbVis=" . (FloatingToolbarIsVisible ? 1 : 0)
        . " drawerOpen=" . (FloatingToolbarChatDrawerOpen ? 1 : 0)
        . " wv2=" . (IsObject(g_FTB_WV2) ? 1 : 0)
        . " wv2Ready=" . (g_FTB_WV2_Ready ? 1 : 0)
        . " frameReady=" . (g_FTB_WV2_FrameReady ? 1 : 0)
        . " waitUiFinished=" . (g_FTB_WaitingUiFinishedReveal ? 1 : 0)
        . " uiFinished=" . (g_FTB_UI_Ready ? 1 : 0)
        . " pendDrawer=" . (g_FTB_PendingOpenNiumaDrawer ? 1 : 0)
        . " handoff=" . (g_FTB_NiumaHandoffOpening ? 1 : 0)
        . " pendCompose=" . pendN
        . " overlaySuppressed=" . (g_FTB_OverlaySuppressedByPageDock ? 1 : 0)
}

CommandPalette_GetWv2() {
    global g_CmdPal_WV2
    return IsObject(g_CmdPal_WV2) ? g_CmdPal_WV2 : 0
}

CommandPalette_IsVisible() {
    global g_CmdPal_Visible
    return !!g_CmdPal_Visible
}

; 热键输入守护：含 PendingShow / 窗口已 Show 但未置 g_CmdPal_Visible 的间隙，避免 CapsLock+字母风暴
CommandPalette_IsInputActive() {
    global g_CmdPal_PendingShow, g_CmdPal_Gui
    if g_CmdPal_PendingShow
        return true
    if IsObject(g_CmdPal_Gui) {
        try {
            hwnd := g_CmdPal_Gui.Hwnd
            if hwnd && WinExist("ahk_id " . hwnd) {
                ; 仅命令面板在前台且可见时视为输入态；Hide 后或 CP 在后台时不阻断 CapsLock 和弦
                if (WinGetStyle("ahk_id " . hwnd) & 0x10000000)
                    return WinActive("ahk_id " . hwnd)
            }
        } catch {
        }
    }
    return false
}

CommandPalette_GetGuiHwnd() {
    global g_CmdPal_Gui
    if IsObject(g_CmdPal_Gui) {
        try return g_CmdPal_Gui.Hwnd
        catch {
        }
    }
    return 0
}

_CmdPal_GetWebView2Class() {
    try return WebView2
    catch {
        return 0
    }
}

CommandPalette_ClearWindowRegion() {
    global g_CmdPal_Gui
    if !IsObject(g_CmdPal_Gui) || !g_CmdPal_Gui.Hwnd
        return
    try DllCall("user32\SetWindowRgn", "Ptr", g_CmdPal_Gui.Hwnd, "Ptr", 0, "Int", 1)
    catch {
    }
}

CommandPalette_ApplyRoundedRegion(radius := 0) {
    global g_CmdPal_Gui, g_CmdPal_CornerRadius
    if !IsObject(g_CmdPal_Gui) || !g_CmdPal_Gui.Hwnd
        return false
    hwnd := g_CmdPal_Gui.Hwnd
    iw := 0, ih := 0
    try WinGetClientPos(, , &iw, &ih, "ahk_id " hwnd)
    catch {
        return false
    }
    if (iw < 32 || ih < 32)
        return false
    rad := Integer(radius)
    if (rad < 8)
        rad := Integer(g_CmdPal_CornerRadius)
    ; 矮窗时缩小圆角，避免裁切输入行
    rad := Max(8, Min(rad, Min(iw, ih) // 2 - 2))
    try {
        rgn := DllCall("gdi32\CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", iw + 1, "Int", ih + 1, "Int", rad, "Int", rad, "Ptr")
        if rgn
            return !!DllCall("user32\SetWindowRgn", "Ptr", hwnd, "Ptr", rgn, "Int", 1)
    } catch {
    }
    return false
}

CommandPalette_ApplyChromaKey() {
    global g_CmdPal_Gui, g_CmdPal_Ctrl
    if IsObject(g_CmdPal_Gui) && g_CmdPal_Gui.Hwnd {
        try WinSetTransColor("010101", "ahk_id " . g_CmdPal_Gui.Hwnd)
        catch {
        }
        try WinSetTransparent(255, "ahk_id " . g_CmdPal_Gui.Hwnd)
        catch {
        }
    }
    if IsObject(g_CmdPal_Ctrl) {
        ; 对齐黑洞启动层：WebView 透明底 + 宿主 010101 色键；圆外由 Region 裁掉
        try g_CmdPal_Ctrl.DefaultBackgroundColor := 0x00000000
        catch {
        }
    }
}

CommandPalette_SyncHostShape() {
    CommandPalette_ApplyChromaKey()
    CommandPalette_ApplyRoundedRegion()
}

CommandPalette_Init() {
    global g_CmdPal_Gui, g_CmdPal_Width, g_CmdPal_CurrentHeight
    try SurfaceManager_ObserveInit("command_palette", Map("entry", "CommandPalette_Init"))
    if IsObject(g_CmdPal_Gui)
        return
    g_CmdPal_Gui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", "NMER Command Palette")
    g_CmdPal_Gui.BackColor := "010101"
    g_CmdPal_Gui.OnEvent("Close", (*) => CommandPalette_Hide())
    g_CmdPal_Gui.OnEvent("Escape", (*) => CommandPalette_Hide())
    g_CmdPal_Gui.Show("w" . g_CmdPal_Width . " h" . g_CmdPal_CurrentHeight . " Hide")
    CommandPalette_SyncHostShape()
    WV2 := _CmdPal_GetWebView2Class()
    if !WV2 {
        try TrayTip("命令面板", "WebView2 未加载，无法创建命令面板", "Icon!")
        catch {
        }
        return
    }
    WebView2_CreateWithSharedEnvAsync(g_CmdPal_Gui.Hwnd, CommandPalette_OnWV2Created, "command_palette")
}

CommandPalette_OnWV2Created(ctrl) {
    global g_CmdPal_WV2, g_CmdPal_Ctrl, g_CmdPal_Ready
    g_CmdPal_Ctrl := ctrl
    g_CmdPal_WV2 := ctrl.CoreWebView2
    try g_CmdPal_Ctrl.IsVisible := true
    CommandPalette_SyncHostShape()
    CommandPalette_ApplyBounds()
    try {
        s := g_CmdPal_WV2.Settings
        s.AreDefaultContextMenusEnabled := false
        s.AreDevToolsEnabled := false
        s.IsWebMessageEnabled := true
        s.AreHostObjectsAllowed := true
    } catch {
    }
    try ApplyWebView2PerformanceSettings(g_CmdPal_WV2)
    catch {
    }
    try WebView2_RegisterHostBridge(g_CmdPal_WV2)
    catch {
    }
    g_CmdPal_WV2.add_WebMessageReceived(CommandPalette_OnWebMessage)
    try g_CmdPal_WV2.add_NavigationCompleted(CommandPalette_OnNavigationCompleted)
    catch {
    }
    try ApplyUnifiedWebViewAssets(g_CmdPal_WV2)
    g_CmdPal_WV2.Navigate(CommandPalette_BuildPageUrl("CommandPalette.html"))
    g_CmdPal_Ready := true
    if g_CmdPal_PendingShow
        SetTimer(CommandPalette_DoShow, -1)
}

CommandPalette_MaybeReloadHtml(*) {
    global g_CmdPal_WV2, g_CmdPal_Ready, g_CmdPal_HtmlVer
    if !IsObject(g_CmdPal_WV2) || !g_CmdPal_Ready
        return
    ver := ""
    try {
        path := FuncExists("HtmlPanelPath") ? HtmlPanelPath("CommandPalette.html") : (A_ScriptDir . "\html\CommandPalette.html")
        ver := String(FileGetTime(path, "M"))
    } catch {
        return
    }
    if (ver = "" || ver = g_CmdPal_HtmlVer)
        return
    g_CmdPal_HtmlVer := ver
    try g_CmdPal_WV2.Navigate(CommandPalette_BuildPageUrl("CommandPalette.html"))
    catch {
    }
}

CommandPalette_OnNavigationCompleted(sender, args) {
    global g_CmdPal_Visible, g_CmdPal_Revealed, g_CmdPal_HtmlVer
    try ok := args.IsSuccess
    catch {
        ok := true
    }
    if !ok
        return
    try {
        path := FuncExists("HtmlPanelPath") ? HtmlPanelPath("CommandPalette.html") : (A_ScriptDir . "\html\CommandPalette.html")
        g_CmdPal_HtmlVer := String(FileGetTime(path, "M"))
    } catch {
    }
    if g_CmdPal_Visible {
        CommandPalette_PushThemeToWeb()
        if !g_CmdPal_Revealed
            SetTimer(CommandPalette_Reveal, -1)
    }
    CommandPalette_SyncHostShape()
    SetTimer(CommandPalette_PushEmptyQuery, -80)
    SetTimer(CommandPalette_PushWailsBridgeConfig, -120)
    if FuncExists("Nmer_WailsBridgeEnabled") && Nmer_WailsBridgeEnabled()
        && FuncExists("Nmer_WailsBridgeHealthy") && !Nmer_WailsBridgeHealthy()
        SetTimer(Nmer_AutoStartWailsBridge, -1)
}

CommandPalette_ApplyBounds() {
    global g_CmdPal_Gui, g_CmdPal_Ctrl, g_CmdPal_Width, g_CmdPal_CurrentHeight
    if !IsObject(g_CmdPal_Ctrl) || !IsObject(g_CmdPal_Gui)
        return
    WV2 := _CmdPal_GetWebView2Class()
    if !WV2
        return
    try WinGetClientPos(, , &cw, &ch, g_CmdPal_Gui.Hwnd)
    catch {
        cw := g_CmdPal_Width
        ch := g_CmdPal_CurrentHeight
    }
    rc := WV2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    try g_CmdPal_Ctrl.Bounds := rc
    catch {
    }
}

CommandPalette_CenterAndShow() {
    global g_CmdPal_Gui, g_CmdPal_Width, g_CmdPal_CurrentHeight, g_CmdPal_Visible, g_CmdPal_Revealed, g_CmdPal_Ctrl
    global g_CmdPal_AnchorX, g_CmdPal_AnchorY, g_CmdPal_HasAnchor
    w := g_CmdPal_Width
    h := g_CmdPal_CurrentHeight
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    ml := 0
    mt := 0
    mr := A_ScreenWidth
    mb := A_ScreenHeight
    CommandPalette_GetWorkAreaAtPoint(mx, my, &ml, &mt, &mr, &mb)
    x := ml + (mr - ml - w) // 2
    y := mt + Round((mb - mt) * 0.28)
    if (y < mt + 8)
        y := mt + 8
    g_CmdPal_AnchorX := x
    g_CmdPal_AnchorY := y
    g_CmdPal_HasAnchor := true
    g_CmdPal_Revealed := false
    try g_CmdPal_Gui.Show("x" . x . " y" . y . " w" . w . " h" . h)
    catch {
    }
    CommandPalette_ApplyBounds()
    CommandPalette_SyncHostShape()
    try WinActivate("ahk_id " . g_CmdPal_Gui.Hwnd)
    catch {
    }
    g_CmdPal_Visible := true
    g_CmdPal_Revealed := true
    CommandPalette_PushThemeToWeb()
    try WebView2_MoveFocusProgrammatic(g_CmdPal_Ctrl)
    catch {
    }
    SetTimer(CommandPalette_DeferredFocus, -120)
}

CommandPalette_IsHandoffHideMeta(meta) {
    if !(meta is Map)
        return false
    if !meta.Has("reason")
        return false
    r := String(meta["reason"])
    return (r = "search_preempt" || r = "primary_handoff")
}

CommandPalette_CancelDeferredFocusTimers() {
    SetTimer(CommandPalette_DeferredFocus, 0)
    SetTimer(CommandPalette_EnsureWebInputVisible, 0)
    SetTimer(CommandPalette_RevealFallback, 0)
    SetTimer(CommandPalette_SyncAiOnShow, 0)
    SetTimer(CommandPalette_AgentOnReady, 0)
    SetTimer(CommandPalette_AgentPushCardSync, 0)
    SetTimer(CommandPalette_PushEmptyQuery, 0)
}

CommandPalette_DeferredFocus(*) {
    global g_CmdPal_Visible, g_CmdPal_WV2, g_CmdPal_Ctrl
    if !g_CmdPal_Visible || !g_CmdPal_WV2
        return
    CommandPalette_EnsureWebInputVisible()
    CommandPalette_PushToWeb(Map("type", "palette_focus"))
    try WebView2_MoveFocusProgrammatic(g_CmdPal_Ctrl)
    catch {
    }
    if FuncExists("SearchCenter_ScheduleIMEStabilize")
        SearchCenter_ScheduleIMEStabilize()
}

CommandPalette_Reveal(*) {
    global g_CmdPal_Gui, g_CmdPal_Revealed, g_CmdPal_Visible
    if !g_CmdPal_Visible || g_CmdPal_Revealed || !IsObject(g_CmdPal_Gui)
        return
    g_CmdPal_Revealed := true
    CommandPalette_SyncHostShape()
}

CommandPalette_Show() {
    if FuncExists("SurfaceIntent_RouteExternalOpen") && SurfaceIntent_RouteExternalOpen("command_palette")
        return true
    global g_CmdPal_Ready, g_CmdPal_PendingShow, g_CmdPal_ShowRetryCount
    skipTel := FuncExists("SurfaceIntent_ShouldSkipExecutorTelemetry") && SurfaceIntent_ShouldSkipExecutorTelemetry()
    reqId := 0
    if !skipTel {
        reqId := SurfaceManager_Request("command_palette", "open", "CommandPalette_Show", Map("readyBefore", g_CmdPal_Ready ? 1 : 0))
        try SurfaceManager_BeforeOpen("command_palette", "CommandPalette_Show", Map("requestId", reqId, "readyBefore", g_CmdPal_Ready ? 1 : 0))
        try SurfaceManager_RegisterSurface("command_palette")
    }
    CommandPalette_Init()
    if !IsObject(g_CmdPal_Gui)
        return false
    g_CmdPal_PendingShow := true
    g_CmdPal_ShowRetryCount := 0
    if g_CmdPal_Ready {
        CommandPalette_DoShow()
        return true
    }
    SetTimer(CommandPalette_RetryShow, -250)
    if !skipTel
        try SurfaceManager_ObserveInit("command_palette", Map("entry", "CommandPalette_Show", "ready", 0, "requestId", reqId))
    return true
}

CommandPalette_RetryShow(*) {
    global g_CmdPal_Ready, g_CmdPal_PendingShow, g_CmdPal_ShowRetryCount
    if !g_CmdPal_PendingShow
        return
    g_CmdPal_ShowRetryCount += 1
    skipTel := FuncExists("SurfaceIntent_ShouldSkipExecutorTelemetry") && SurfaceIntent_ShouldSkipExecutorTelemetry()
    if g_CmdPal_Ready {
        CommandPalette_DoShow()
        return
    }
    if (g_CmdPal_ShowRetryCount >= 40) {
        g_CmdPal_PendingShow := false
        if !skipTel {
            try SurfaceTransaction_OnSurfaceFailed("command_palette", Map("entry", "CommandPalette_RetryShow", "reason", "init_timeout"))
            catch {
            }
        }
        try TrayTip("命令面板", "WebView2 初始化超时，请重载脚本后再试", "Icon!")
        catch {
        }
        return
    }
    SetTimer(CommandPalette_RetryShow, -250)
}

CommandPalette_EnsureWebInputVisible() {
    CommandPalette_ExecScript("try{document.body.classList.remove('native-input-mode')}catch(e){}")
    CommandPalette_PushToWeb(Map("type", "palette_show"))
}

CommandPalette_PushWailsBridgeConfig(*) {
    if !FuncExists("Nmer_WailsBridgeBuildHostConfig")
        return false
    try return CommandPalette_PushToWeb(Nmer_WailsBridgeBuildHostConfig())
    catch {
        return false
    }
}

CommandPalette_NormalizeOc5ProbeData(data) {
    if !(data is Map)
        return Map("ok", false, "code", "OC5_PROBE_PARSE_FAIL", "detail", SubStr(String(data), 1, 200))
    pass := !!(data.Get("ok", 0) = 1 || data.Get("ok", false) = true)
    return Map(
        "ok", pass,
        "code", String(data.Get("code", pass ? "OC5_PASS" : "OC5_FAIL")),
        "detail", data
    )
}

CommandPalette_ProbeOc5ViaExecuteScript(timeoutMs := 12000) {
    global g_CmdPal_WV2
    js := "(function(){try{"
        . "var fn=window.nmerPalette&&window.nmerPalette.probeOc5ProtocolClosure;"
        . "if(typeof fn!=='function')return JSON.stringify({ok:0,code:'OC5_PROBE_FN_MISSING'});"
        . "return JSON.stringify(fn());"
        . "}catch(e){return JSON.stringify({ok:0,code:'OC5_PROBE_ERR',err:String(e&&e.message||e)});}})();"
    try {
        raw := g_CmdPal_WV2.ExecuteScriptAsync(js).await(timeoutMs)
        data := FuncExists("CommandPalette_ParseScriptJson") ? CommandPalette_ParseScriptJson(raw) : Map()
        out := CommandPalette_NormalizeOc5ProbeData(data)
        if (out is Map) {
            det := out.Get("detail", Map())
            if (det is Map)
                det["via"] := "execute_script"
        }
        return out
    } catch as err {
        return Map("ok", false, "code", "OC5_PROBE_TIMEOUT", "detail", err.Message, "via", "execute_script")
    }
}

CommandPalette_Oc5ProbePromiseExecutor(resolve, reject) {
    global g_CmdPal_Oc5ProbeResolver, g_CmdPal_Oc5ProbeReqId
    g_CmdPal_Oc5ProbeResolver := Map("resolve", resolve, "reject", reject, "reqId", g_CmdPal_Oc5ProbeReqId)
}

CommandPalette_ProbeOc5OfflineEngine() {
    root := A_ScriptDir
    script := root . "\html\run-oc5-verify.mjs"
    if !FileExist(script)
        return Map("ok", false, "code", "OC5_L1_SCRIPT_MISSING", "closureCode", "", "via", "node_l1")
    outPath := A_Temp . "\nmer_oc5_l1_" . A_TickCount . ".txt"
    cmd := A_ComSpec . ' /c node "' . script . '" > "' . outPath . '" 2>&1'
    stdout := ""
    try RunWait(cmd, root, "Hide")
    catch as err {
        return Map("ok", false, "code", "OC5_L1_RUN_FAIL", "detail", err.Message, "closureCode", "", "via", "node_l1")
    }
    try stdout := FileRead(outPath, "UTF-8")
    catch {
    }
    try FileDelete(outPath)
    ok := InStr(stdout, "OC5_L1 ok=true") > 0
    synthesized := InStr(stdout, "synthesizes repair reply") > 0 && InStr(stdout, "PASS") > 0
    return Map(
        "ok", ok,
        "code", ok ? "OC5_L1_PASS" : "OC5_L1_FAIL",
        "closureCode", ok ? "SEM_PROTOCOL_TAG_UNCLOSED" : "",
        "synthesized", synthesized,
        "stdout", SubStr(Trim(stdout), 1, 600),
        "via", "node_l1"
    )
}

CommandPalette_ProbeOc5MergeResult(engine, live, web := 0) {
    engOk := !!(engine is Map && engine.Get("ok", false))
    closed := (live is Map) ? Integer(live.Get("closed", 0)) : 0
    repaired := (live is Map) ? Integer(live.Get("repaired", 0)) : 0
    unclosed := (live is Map) ? Integer(live.Get("unclosed", 0)) : 0
    sampled := (live is Map) ? Integer(live.Get("sampled", 0)) : 0
    livePass := !!(live is Map && live.Get("pass", false))
    code := "OC5_ENGINE_FAIL"
    if engOk {
        if livePass
            code := "OC5_PASS"
        else if (sampled = 0 || String(live.Get("code", "")) = "OC5_NEEDS_LIVE_TASK")
            code := "OC5_ENGINE_PASS_NEEDS_LIVE"
        else
            code := "OC5_ENGINE_OK_LIVE_PENDING"
    }
    ok := engOk && (code = "OC5_PASS" || code = "OC5_ENGINE_PASS_NEEDS_LIVE")
    stats := Map(
        "closed", closed,
        "repaired", repaired,
        "unclosed", unclosed,
        "withField", closed + repaired + unclosed,
        "sampled", sampled
    )
    webNote := Map("skipped", "webview_timeout_or_unavailable")
    if (web is Map) && web.Has("detail") {
        wd := web["detail"]
        if (wd is Map)
            webNote := wd
    }
    return Map(
        "ok", ok,
        "code", code,
        "detail", Map(
            "engine", engine is Map ? engine : Map(),
            "live", live is Map ? live : Map(),
            "stats", stats,
            "webview", webNote,
            "via", (web is Map) && String(web.Get("code", "")) != "OC5_PROBE_TIMEOUT" ? "hybrid" : "offline"
        )
    )
}

CommandPalette_ProbeOc5ViaPostMessage(timeoutMs := 2500) {
    global g_CmdPal_Oc5ProbeResolver, g_CmdPal_Oc5ProbeReqId
    g_CmdPal_Oc5ProbeReqId := "oc5_" . A_TickCount
    g_CmdPal_Oc5ProbeResolver := 0
    p := Promise(CommandPalette_Oc5ProbePromiseExecutor)
    CommandPalette_PushToWeb(Map("type", "palette_oc5_probe_request", "reqId", g_CmdPal_Oc5ProbeReqId))
    try {
        data := p.await(timeoutMs)
        g_CmdPal_Oc5ProbeResolver := 0
        if !(data is Map)
            return 0
        out := CommandPalette_NormalizeOc5ProbeData(data)
        if (out is Map) {
            det := out.Get("detail", Map())
            if (det is Map)
                det["via"] := "postmessage"
        }
        return out
    } catch as err {
        g_CmdPal_Oc5ProbeResolver := 0
        return Map("ok", false, "code", "OC5_PROBE_TIMEOUT", "detail", String(err.Message), "via", "postmessage")
    }
}

CommandPalette_ProbeOc5ProtocolClosure(timeoutMs := 2500) {
    engine := CommandPalette_ProbeOc5OfflineEngine()
    live := Map("pass", false, "code", "OC5_LIVE_UNAVAILABLE", "closed", 0, "repaired", 0, "unclosed", 0, "sampled", 0)
    if FuncExists("CommandPalette_AgentProbeOc5") {
        try live := CommandPalette_AgentProbeOc5()
        catch {
        }
    }
    web := 0
    global g_CmdPal_WV2, g_CmdPal_Ready
    if (IsObject(g_CmdPal_WV2) && g_CmdPal_Ready) {
        wvMs := timeoutMs > 0 ? timeoutMs : 2500
        web := CommandPalette_ProbeOc5ViaPostMessage(wvMs)
        if !(web is Map) || String(web.Get("code", "")) = "OC5_PROBE_TIMEOUT"
            web := CommandPalette_ProbeOc5ViaExecuteScript(wvMs)
    }
    return CommandPalette_ProbeOc5MergeResult(engine, live, web)
}

CommandPalette_RunOc5ProbeAndPersist(timeoutMs := 2500) {
    r := CommandPalette_ProbeOc5ProtocolClosure(timeoutMs)
    path := ""
    try {
        if FuncExists("Nmer_DebugPath")
            path := Nmer_DebugPath("oc5_probe_last.json")
        else
            path := A_ScriptDir . "\Cache\debug\oc5_probe_last.json"
        dir := ""
        SplitPath(path, , &dir)
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)
        if FileExist(path)
            FileDelete(path)
        FileAppend(Jxon_Dump(r), path, "UTF-8")
    } catch {
    }
    code := String(r.Get("code", "OC5_FAIL"))
    ok := !!r.Get("ok", false)
    det := r.Get("detail", Map())
    stats := (det is Map) ? det.Get("stats", Map()) : Map()
    engCode := ""
    if (det is Map) {
        eng := det.Get("engine", 0)
        if (eng is Map)
            engCode := String(eng.Get("closureCode", ""))
    }
    via := ""
    if (det is Map)
        via := String(det.Get("via", ""))
    msg := "OC-5 " . code
        . (ok ? " ✓" : " ✗")
        . "`n引擎=" . engCode
    if (stats is Map) {
        msg .= "`n卡: closed=" . stats.Get("closed", 0)
            . " repaired=" . stats.Get("repaired", 0)
            . " withField=" . stats.Get("withField", 0)
    }
    if (via != "")
        msg .= "`nvia=" . via
    if (via = "offline" || via = "hybrid")
        msg .= "`n(WebView 忙时走 Node+AHK 离线探针)"
    if (path != "")
        msg .= "`n→ " . path
    shown := false
    if FuncExists("Nmer_ShowAppToast") {
        try {
            Nmer_ShowAppToast("OC-5 探针", msg, ok ? "ok" : "warn")
            shown := true
        } catch {
        }
    }
    if !shown
        try TrayTip(msg, "OC-5 探针", ok ? "Iconi 4" : "Icon! 4")
        catch {
        }
    if FuncExists("CommandPalette_AgentDebugTrace")
        try CommandPalette_AgentDebugTrace("host", "oc5_probe", code . " ok=" . (ok ? 1 : 0), ok ? "info" : "warn")
        catch {
        }
    return r
}

CommandPalette_GrayProbePromiseExecutor(resolve, reject) {
    global g_CmdPal_GrayProbeResolver, g_CmdPal_GrayProbeReqId
    g_CmdPal_GrayProbeResolver := Map("resolve", resolve, "reject", reject, "reqId", g_CmdPal_GrayProbeReqId)
}

CommandPalette_AdpProbePromiseExecutor(resolve, reject) {
    global g_CmdPal_AdpProbeResolver, g_CmdPal_AdpProbeReqId
    g_CmdPal_AdpProbeResolver := Map("resolve", resolve, "reject", reject, "reqId", g_CmdPal_AdpProbeReqId)
}

CommandPalette_ProbeGrayRouteOffline(query := "/search 测试") {
    decision := Map("route", "r1r2", "allowed", false, "reason", "offline_unavailable", "command", "")
    if FuncExists("Nmer_WailsBridgeResolveOfficialRoute")
        try decision := Nmer_WailsBridgeResolveOfficialRoute(query)
        catch {
        }
    route := String(decision.Get("route", "r1r2"))
    reason := String(decision.Get("reason", ""))
    pass := (route = "r3" && reason = "whitelist_hit")
    code := pass ? "GRAY_PASS" : "GRAY_" . (reason != "" ? reason : "FAIL")
    officialOn := false
    bridgeOk := false
    wl := []
    if FuncExists("Nmer_WailsBridgeOfficialEffectiveEnabled")
        officialOn := !!Nmer_WailsBridgeOfficialEffectiveEnabled()
    if FuncExists("Nmer_WailsBridgeHealthy")
        bridgeOk := !!Nmer_WailsBridgeHealthy()
    if FuncExists("Nmer_WailsBridgeOfficialWhitelist")
        wl := Nmer_WailsBridgeOfficialWhitelist()
    return Map(
        "ok", pass,
        "code", code,
        "detail", Map(
            "decision", decision,
            "flags", Map(
                "officialEnabled", officialOn,
                "bridgeHealthy", bridgeOk,
                "whitelist", wl
            ),
            "via", "ahk_offline"
        )
    )
}

CommandPalette_ProbeGrayRouteViaExecuteScript(timeoutMs := 12000, query := "/search 测试") {
    global g_CmdPal_WV2
    qEsc := StrReplace(String(query), "\", "\\")
    qEsc := StrReplace(qEsc, '"', '\"')
    js := "(function(){try{"
        . "var fn=window.nmerPalette&&window.nmerPalette.probeGrayRoute;"
        . "if(typeof fn!=='function')return JSON.stringify({ok:0,code:'GRAY_PROBE_FN_MISSING'});"
        . "return JSON.stringify(fn(" . (qEsc != "" ? '"' . qEsc . '"' : '""') . "));"
        . "}catch(e){return JSON.stringify({ok:0,code:'GRAY_PROBE_ERR',err:String(e&&e.message||e)});}})();"
    try {
        raw := g_CmdPal_WV2.ExecuteScriptAsync(js).await(timeoutMs)
        data := FuncExists("CommandPalette_ParseScriptJson") ? CommandPalette_ParseScriptJson(raw) : Map()
        if !(data is Map)
            return Map("ok", false, "code", "GRAY_PROBE_PARSE_FAIL", "detail", SubStr(String(raw), 1, 200), "via", "execute_script")
        pass := !!(data.Get("ok", 0) = 1 || data.Get("ok", false) = true)
        det := (data is Map) ? data : Map()
        if (det is Map)
            det["via"] := "execute_script"
        return Map(
            "ok", pass,
            "code", String(data.Get("code", pass ? "GRAY_PASS" : "GRAY_FAIL")),
            "detail", det
        )
    } catch as err {
        return Map("ok", false, "code", "GRAY_PROBE_TIMEOUT", "detail", err.Message, "via", "execute_script")
    }
}

CommandPalette_ProbeGrayRouteViaPostMessage(timeoutMs := 3500, query := "/search 测试") {
    global g_CmdPal_GrayProbeResolver, g_CmdPal_GrayProbeReqId
    g_CmdPal_GrayProbeReqId := "gray_" . A_TickCount
    g_CmdPal_GrayProbeResolver := 0
    p := Promise(CommandPalette_GrayProbePromiseExecutor)
    CommandPalette_PushToWeb(Map(
        "type", "palette_gray_probe_request",
        "reqId", g_CmdPal_GrayProbeReqId,
        "query", String(query)
    ))
    try {
        data := p.await(timeoutMs)
        g_CmdPal_GrayProbeResolver := 0
        if !(data is Map)
            return 0
        pass := !!(data.Get("ok", 0) = 1 || data.Get("ok", false) = true)
        det := data.Has("detail") ? data["detail"] : data
        if !(det is Map)
            det := Map()
        det["via"] := "postmessage"
        return Map(
            "ok", pass,
            "code", String(data.Get("code", pass ? "GRAY_PASS" : "GRAY_FAIL")),
            "detail", det
        )
    } catch as err {
        g_CmdPal_GrayProbeResolver := 0
        return Map("ok", false, "code", "GRAY_PROBE_TIMEOUT", "detail", String(err.Message), "via", "postmessage")
    }
}

CommandPalette_ProbeGrayRouteMerged(offline, web := 0) {
    webCode := (web is Map) ? String(web.Get("code", "")) : ""
    if (web is Map) && webCode != "" && webCode != "GRAY_PROBE_TIMEOUT"
        return web
    if (offline is Map) {
        if (web is Map) && webCode = "GRAY_PROBE_TIMEOUT" {
            det := offline.Get("detail", Map())
            if !(det is Map)
                det := Map()
            det["webview"] := Map("code", webCode, "detail", web.Get("detail", ""))
            offline["detail"] := det
        }
        return offline
    }
    return (web is Map) ? web : Map("ok", false, "code", "GRAY_FAIL", "detail", "no_probe_result")
}

CommandPalette_ProbeGrayRoute(timeoutMs := 4000, query := "/search 测试") {
    offline := CommandPalette_ProbeGrayRouteOffline(query)
    web := 0
    global g_CmdPal_WV2, g_CmdPal_Ready
    if (IsObject(g_CmdPal_WV2) && g_CmdPal_Ready) {
        if FuncExists("CommandPalette_PushWailsBridgeConfig")
            try CommandPalette_PushWailsBridgeConfig()
            catch {
            }
        wvMs := timeoutMs > 0 ? timeoutMs : 4000
        web := CommandPalette_ProbeGrayRouteViaPostMessage(wvMs, query)
        if !(web is Map) || String(web.Get("code", "")) = "GRAY_PROBE_TIMEOUT"
            web := CommandPalette_ProbeGrayRouteViaExecuteScript(Max(wvMs, 12000), query)
    }
    return CommandPalette_ProbeGrayRouteMerged(offline, web)
}

CommandPalette_RunGrayProbeAndPersist(timeoutMs := 4000, query := "/search 测试") {
    if FuncExists("CommandPalette_PushWailsBridgeConfig")
        try CommandPalette_PushWailsBridgeConfig()
        catch {
        }
    r := CommandPalette_ProbeGrayRoute(timeoutMs, query)
    path := ""
    try {
        if FuncExists("Nmer_DebugPath")
            path := Nmer_DebugPath("gray_probe_last.json")
        else
            path := A_ScriptDir . "\Cache\debug\gray_probe_last.json"
        dir := ""
        SplitPath(path, , &dir)
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)
        if FileExist(path)
            FileDelete(path)
        FileAppend(Jxon_Dump(r), path, "UTF-8")
    } catch {
    }
    code := String(r.Get("code", "GRAY_FAIL"))
    ok := !!r.Get("ok", false)
    det := r.Get("detail", Map())
    route := ""
    reason := ""
    if (det is Map) {
        dec := det.Get("decision", 0)
        if (dec is Map) {
            route := String(dec.Get("route", ""))
            reason := String(dec.Get("reason", ""))
        }
    }
    msg := "灰度 " . code . (ok ? " ✓" : " ✗")
    if (code = "GRAY_official_disabled")
        msg .= "`n未开灰度：运行 scripts\Install-GrayFlagsExample.ps1 后重载牛马"
    if (route != "")
        msg .= "`nroute=" . route . " reason=" . reason
    via := ""
    if (det is Map)
        via := String(det.Get("via", ""))
    if (via != "")
        msg .= "`nvia=" . via
    if (via = "ahk_offline" || via = "postmessage")
        msg .= "`n(WebView 忙时走离线/PostMessage 探针)"
    if (path != "")
        msg .= "`n→ " . path
    shown := false
    if FuncExists("Nmer_ShowAppToast") {
        try {
            Nmer_ShowAppToast("A2UI 灰度探针", msg, ok ? "ok" : "warn")
            shown := true
        } catch {
        }
    }
    if !shown
        try TrayTip(msg, "A2UI 灰度探针", ok ? "Iconi 4" : "Icon! 4")
        catch {
        }
    if FuncExists("CommandPalette_AgentDebugTrace")
        try CommandPalette_AgentDebugTrace("host", "gray_probe", code . " ok=" . (ok ? 1 : 0), ok ? "info" : "warn")
        catch {
        }
    return r
}

CommandPalette_ProbeP2OfficialA2ui(timeoutMs := 4000) {
    global g_CmdPal_WV2, g_CmdPal_Ready
    if !(IsObject(g_CmdPal_WV2) && g_CmdPal_Ready)
        return Map("ok", false, "code", "CP_NOT_READY", "detail", "webview_not_ready")
    js := "(function(){try{"
        . "var fn=window.nmerPalette&&window.nmerPalette.probeP2OfficialA2ui;"
        . "if(typeof fn!=='function')return JSON.stringify({ok:0,code:'P2_PROBE_FN_MISSING'});"
        . "return JSON.stringify(fn());"
        . "}catch(e){return JSON.stringify({ok:0,code:'P2_PROBE_ERR',err:String(e&&e.message||e)});}})();"
    try {
        raw := g_CmdPal_WV2.ExecuteScriptAsync(js).await(timeoutMs)
        data := FuncExists("CommandPalette_ParseScriptJson") ? CommandPalette_ParseScriptJson(raw) : Map()
        if !(data is Map)
            return Map("ok", false, "code", "P2_PROBE_PARSE_FAIL", "detail", SubStr(String(raw), 1, 200))
        pass := !!(data.Get("ok", 0) = 1 || data.Get("ok", false) = true)
        return Map(
            "ok", pass,
            "code", String(data.Get("code", pass ? "P2_PASS" : "P2_FAIL")),
            "detail", data
        )
    } catch as err {
        return Map("ok", false, "code", "P2_PROBE_TIMEOUT", "detail", err.Message)
    }
}

CommandPalette_RunAdapterProbeAndPersist(timeoutMs := 8000) {
    if FuncExists("Nmer_WailsBridgeIngestDemoJsonl") && FuncExists("Nmer_WailsBridgeHealthy") && Nmer_WailsBridgeHealthy() {
        try {
            ingest := Nmer_WailsBridgeIngestDemoJsonl()
            if FuncExists("CommandPalette_AgentDebugTrace")
                CommandPalette_AgentDebugTrace("host", "adp_ingest_prep", String(ingest.Get("code", "")), ingest.Get("ok", false) ? "info" : "warn")
            if ingest.Get("ok", false)
                Sleep(600)
        } catch {
        }
    }
    if FuncExists("CommandPalette_PushWailsBridgeConfig")
        try CommandPalette_PushWailsBridgeConfig()
        catch {
        }
    if FuncExists("CommandPalette_PushToWeb")
        try CommandPalette_PushToWeb(Map("type", "palette_adp_demo_prepare"))
        catch {
        }
    r := CommandPalette_ProbeAdapterOfficialA2ui(timeoutMs)
    path := ""
    try {
        if FuncExists("Nmer_DebugPath")
            path := Nmer_DebugPath("adp_probe_last.json")
        else
            path := A_ScriptDir . "\Cache\debug\adp_probe_last.json"
        dir := ""
        SplitPath(path, , &dir)
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)
        if FileExist(path)
            FileDelete(path)
        FileAppend(Jxon_Dump(r), path, "UTF-8")
    } catch {
    }
    code := String(r.Get("code", "ADP_FAIL"))
    ok := !!r.Get("ok", false)
    det := r.Get("detail", Map())
    surfaceId := ""
    titleText := ""
    wsState := ""
    if (det is Map) {
        surfaceId := String(det.Get("surfaceId", ""))
        titleText := String(det.Get("titleText", ""))
        wsState := String(det.Get("wsState", ""))
    }
    msg := "Adapter " . code . (ok ? " ✓" : " ✗")
    if (surfaceId != "")
        msg .= "`nsurface=" . surfaceId
    if (titleText != "")
        msg .= "`ntitle=" . SubStr(titleText, 1, 40)
    if (wsState != "")
        msg .= "`nws=" . wsState
    via := ""
    if (det is Map)
        via := String(det.Get("via", ""))
    if (via = "" && det.Has("engine"))
        via := "offline"
    if (via != "")
        msg .= "`nvia=" . via
    if (code = "ADP_L2_PASS_L3_PENDING")
        msg .= "`n(L2 已绿；L3 需先 ingest 演示 JSONL)"
    if (path != "")
        msg .= "`n→ " . path
    shown := false
    if FuncExists("Nmer_ShowAppToast") {
        try {
            Nmer_ShowAppToast("Adapter 探针", msg, ok ? "ok" : "warn")
            shown := true
        } catch {
        }
    }
    if !shown
        try TrayTip(msg, "Adapter 探针", ok ? "Iconi 4" : "Icon! 4")
        catch {
        }
    if FuncExists("CommandPalette_AgentDebugTrace")
        try CommandPalette_AgentDebugTrace("host", "adp_probe", code . " ok=" . (ok ? 1 : 0), ok ? "info" : "warn")
        catch {
        }
    return r
}

CommandPalette_ProbeAdapterOfflineEngine() {
    root := A_ScriptDir
    script := root . "\html\run-adp-cp-stream.mjs"
    if !FileExist(script)
        return Map("ok", false, "code", "ADP_L2_SCRIPT_MISSING", "via", "node_l2")
    outPath := A_Temp . "\nmer_adp_l2_" . A_TickCount . ".txt"
    cmd := A_ComSpec . ' /c node "' . script . '" > "' . outPath . '" 2>&1'
    stdout := ""
    try RunWait(cmd, root, "Hide")
    catch as err {
        return Map("ok", false, "code", "ADP_L2_RUN_FAIL", "detail", err.Message, "via", "node_l2")
    }
    try stdout := FileRead(outPath, "UTF-8")
    catch {
    }
    try FileDelete(outPath)
    ok := InStr(stdout, "PASS adp-cp-stream") > 0
    sidecarOk := false
    if FuncExists("Nmer_WailsBridgeHealthy")
        sidecarOk := !!Nmer_WailsBridgeHealthy()
    return Map(
        "ok", ok,
        "code", ok ? "ADP_L2_PASS" : "ADP_L2_FAIL",
        "sidecarHealthy", sidecarOk,
        "stdout", SubStr(Trim(stdout), 1, 400),
        "via", "node_l2"
    )
}

CommandPalette_ProbeAdapterViaExecuteScript(timeoutMs := 12000) {
    global g_CmdPal_WV2
    js := "(function(){try{"
        . "var fn=window.nmerPalette&&window.nmerPalette.probeAdapterOfficialA2ui;"
        . "if(typeof fn!=='function')return JSON.stringify({ok:0,code:'ADP_PROBE_FN_MISSING'});"
        . "return JSON.stringify(fn());"
        . "}catch(e){return JSON.stringify({ok:0,code:'ADP_PROBE_ERR',err:String(e&&e.message||e)});}})();"
    try {
        raw := g_CmdPal_WV2.ExecuteScriptAsync(js).await(timeoutMs)
        data := FuncExists("CommandPalette_ParseScriptJson") ? CommandPalette_ParseScriptJson(raw) : Map()
        if !(data is Map)
            return Map("ok", false, "code", "ADP_PROBE_PARSE_FAIL", "detail", SubStr(String(raw), 1, 200), "via", "execute_script")
        pass := !!(data.Get("ok", 0) = 1 || data.Get("ok", false) = true)
        if (data is Map)
            data["via"] := "execute_script"
        return Map(
            "ok", pass,
            "code", String(data.Get("code", pass ? "ADP_PASS" : "ADP_FAIL")),
            "detail", data
        )
    } catch as err {
        return Map("ok", false, "code", "ADP_PROBE_TIMEOUT", "detail", err.Message, "via", "execute_script")
    }
}

CommandPalette_ProbeAdapterViaPostMessage(timeoutMs := 3500) {
    global g_CmdPal_AdpProbeResolver, g_CmdPal_AdpProbeReqId
    g_CmdPal_AdpProbeReqId := "adp_" . A_TickCount
    g_CmdPal_AdpProbeResolver := 0
    p := Promise(CommandPalette_AdpProbePromiseExecutor)
    CommandPalette_PushToWeb(Map("type", "palette_adp_probe_request", "reqId", g_CmdPal_AdpProbeReqId))
    try {
        data := p.await(timeoutMs)
        g_CmdPal_AdpProbeResolver := 0
        if !(data is Map)
            return 0
        pass := !!(data.Get("ok", 0) = 1 || data.Get("ok", false) = true)
        det := data.Has("detail") ? data["detail"] : data
        if !(det is Map)
            det := Map()
        det["via"] := "postmessage"
        return Map(
            "ok", pass,
            "code", String(data.Get("code", pass ? "ADP_PASS" : "ADP_FAIL")),
            "detail", det
        )
    } catch as err {
        g_CmdPal_AdpProbeResolver := 0
        return Map("ok", false, "code", "ADP_PROBE_TIMEOUT", "detail", String(err.Message), "via", "postmessage")
    }
}

CommandPalette_ProbeAdapterMerged(engine, web := 0) {
    webCode := (web is Map) ? String(web.Get("code", "")) : ""
    if (web is Map) && webCode = "ADP_PASS"
        return web
    engOk := !!(engine is Map && engine.Get("ok", false))
    if engOk && ((web is Map) && (webCode = "ADP_PROBE_TIMEOUT" || webCode = "ADP_CARD_MISSING" || webCode = "ADP_PROBE_FN_MISSING")) {
        return Map(
            "ok", true,
            "code", "ADP_L2_PASS_L3_PENDING",
            "detail", Map(
                "engine", engine,
                "webview", (web is Map) ? web : Map(),
                "via", "offline"
            )
        )
    }
    if (web is Map) && webCode != "" && webCode != "ADP_PROBE_TIMEOUT"
        return web
    if engOk
        return Map("ok", true, "code", "ADP_L2_PASS", "detail", Map("engine", engine, "via", "node_l2"))
    return (web is Map) ? web : Map("ok", false, "code", "ADP_FAIL", "detail", engine is Map ? engine : Map())
}

CommandPalette_ProbeAdapterOfficialA2ui(timeoutMs := 8000) {
    engine := CommandPalette_ProbeAdapterOfflineEngine()
    web := 0
    global g_CmdPal_WV2, g_CmdPal_Ready
    if (IsObject(g_CmdPal_WV2) && g_CmdPal_Ready) {
        if FuncExists("CommandPalette_PushWailsBridgeConfig")
            try CommandPalette_PushWailsBridgeConfig()
            catch {
            }
        if FuncExists("CommandPalette_PushToWeb")
            try {
                CommandPalette_PushToWeb(Map("type", "palette_adp_demo_prepare"))
                Sleep(350)
            } catch {
            }
        wvMs := timeoutMs > 0 ? timeoutMs : 8000
        web := CommandPalette_ProbeAdapterViaPostMessage(wvMs)
        if !(web is Map) || String(web.Get("code", "")) = "ADP_PROBE_TIMEOUT"
            web := CommandPalette_ProbeAdapterViaExecuteScript(Max(wvMs, 12000))
    } else {
        web := Map("ok", false, "code", "CP_NOT_READY", "detail", "webview_not_ready")
    }
    return CommandPalette_ProbeAdapterMerged(engine, web)
}

CommandPalette_DoShow(*) {
    global g_CmdPal_PendingShow, CapsLock, g_CmdPal_WV2
    if FuncExists("CapsLock_RestoreForUiTypingOpen")
        CapsLock_RestoreForUiTypingOpen()
    else {
        CapsLock := false
        try SetTimer(CapsLock_DeferredSingleTapToggle, 0)
        catch {
        }
    }
    SetTimer(CommandPalette_MaybeReloadHtml, -1)
    CommandPalette_CenterAndShow()
    g_CmdPal_PendingShow := false
    ; 包 1.1：显示时恢复 WebView2 正常内存档位
    try WebView2_NotifyShown(g_CmdPal_WV2)
    catch {
    }
    SetTimer(CommandPalette_EnsureWebInputVisible, -60)
    SetTimer(CommandPalette_SyncAiOnShow, -350)
    if FuncExists("CommandPalette_AgentOnReady")
        SetTimer(CommandPalette_AgentOnReady, -80)
    else if FuncExists("CommandPalette_AgentPushCardSync")
        SetTimer(CommandPalette_AgentPushCardSync, -120)
    SetTimer(CommandPalette_PushEmptyQuery, -180)
    SetTimer(CommandPalette_PushAiProviders, -220)
    SetTimer(CommandPalette_PushWailsBridgeConfig, -260)
    SetTimer(CommandPalette_PushWailsBridgeConfig, -3200)
    if FuncExists("Nmer_WailsBridgeEnabled") && Nmer_WailsBridgeEnabled()
        && FuncExists("Nmer_WailsBridgeHealthy") && !Nmer_WailsBridgeHealthy()
        SetTimer(Nmer_AutoStartWailsBridge, -1)
    SetTimer(CommandPalette_RevealFallback, -600)
    ; 冷启动异步 WV2：OnWV2Created→DoShow 也必须 COMMIT，否则 S3 永远 timeout
    try SurfaceManager_ObserveShow("command_palette", Map("entry", "CommandPalette_DoShow", "ready", 1))
    catch {
    }
    try {
        mode := "toolbar"
        if FuncExists("FloatingToolbar_NormalizeAppearanceMode")
            mode := FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode)
        if (mode = "toolbar") {
            if FuncExists("SurfaceIntent_Open")
                SetTimer((*) => SurfaceIntent_Open("floating_toolbar", Map("reason", "cmdpal_show_ftb", "skipTransaction", true)), -80)
            else if FuncExists("ShowFloatingToolbar")
                SetTimer(ShowFloatingToolbar, -80)
        }
    } catch {
    }
}

CommandPalette_RevealFallback(*) {
    global g_CmdPal_Visible, g_CmdPal_Revealed
    if g_CmdPal_Visible && !g_CmdPal_Revealed
        CommandPalette_Reveal()
}

CommandPalette_SyncAiOnShow(*) {
    global g_CmdPal_AiSession
    if (g_CmdPal_AiSession is Map) && g_CmdPal_AiSession.Get("handoff", false) {
        if !g_CmdPal_AiSession.Get("ended", false)
            g_CmdPal_AiSession["handoff"] := false
        else if g_CmdPal_Visible
            g_CmdPal_AiSession["handoff"] := false
    }
    if !CommandPalette_PushAiSessionRestore()
        CommandPalette_PushToWeb(Map("type", "palette_ai_reset"))
}

CommandPalette_PushAiSessionRestore() {
    global g_CmdPal_AiSession, g_CmdPal_AiLastCard, g_CmdPal_AiMorphHeight
    src := 0
    if (g_CmdPal_AiSession is Map) {
        ans := String(g_CmdPal_AiSession.Get("answer", ""))
        q := Trim(String(g_CmdPal_AiSession.Get("query", "")))
        if (q != "" && (!g_CmdPal_AiSession.Get("ended", false) || ans != ""))
            src := g_CmdPal_AiSession
    } else if (g_CmdPal_AiLastCard is Map) {
        src := g_CmdPal_AiLastCard
    }
    if !(src is Map)
        return false
    ended := !!src.Get("ended", false)
    err := src.Has("error") ? Trim(String(src["error"])) : ""
    phase := ended ? (err != "" ? "error" : "done") : "streaming"
    CommandPalette_PushToWeb(Map(
        "type", "palette_ai_restore",
        "phase", phase,
        "reqId", String(src.Get("reqId", "")),
        "query", String(src.Get("query", "")),
        "provider", String(src.Get("provider", "")),
        "answer", String(src.Get("answer", "")),
        "message", err,
        "handoff", !!src.Get("handoff", false),
        "compact", true
    ))
    return true
}

CommandPalette_DismissAiCard() {
    global g_CmdPal_AiSession, g_CmdPal_AiLastCard, g_CmdPal_AiStreamGen
    oldReqId := (g_CmdPal_AiSession is Map) ? String(g_CmdPal_AiSession.Get("reqId", "")) : ""
    CommandPalette_StopAiStreamSideEffects(oldReqId)
    g_CmdPal_AiStreamGen++
    g_CmdPal_AiLastCard := 0
    g_CmdPal_AiSession := 0
    CommandPalette_PushToWeb(Map("type", "palette_ai_reset"))
    CommandPalette_ApplyHeight(g_CmdPal_MinHeight)
}

CommandPalette_PushEmptyQuery(*) {
    global g_CmdPal_AiSession, g_CmdPal_AiLastCard
    if (g_CmdPal_AiSession is Map) {
        q := Trim(String(g_CmdPal_AiSession.Get("query", "")))
        if (q != "")
            return
    }
    if (g_CmdPal_AiLastCard is Map)
        return
    if FuncExists("CommandPalette_AgentCardCount") {
        try {
            if CommandPalette_AgentCardCount() > 0
                return
        } catch {
        }
    }
    CommandPalette_HandleQuery("")
}

CommandPalette_Hide(meta := 0) {
    if FuncExists("SurfaceIntent_RouteExternalClose") && SurfaceIntent_RouteExternalClose("command_palette", meta)
        return
    global g_CmdPal_Gui, g_CmdPal_Visible, g_CmdPal_Revealed, g_CmdPal_AiSession, g_CmdPal_WV2
    global g_CmdPal_HasAnchor
    handoff := CommandPalette_IsHandoffHideMeta(meta)
    if handoff
        CommandPalette_CancelDeferredFocusTimers()
    skipTel := FuncExists("SurfaceIntent_ShouldSkipExecutorTelemetry") && SurfaceIntent_ShouldSkipExecutorTelemetry()
    if !skipTel {
        reqId := SurfaceManager_Request("command_palette", "close", "CommandPalette_Hide", Map("visibleBefore", g_CmdPal_Visible ? 1 : 0))
        try SurfaceManager_ObserveHide("command_palette", Map("entry", "CommandPalette_Hide", "requestId", reqId))
    }
    if (g_CmdPal_AiSession is Map) && !g_CmdPal_AiSession.Get("handoff", false) && !g_CmdPal_AiSession.Get("ended", false) {
        try CommandPalette_HandoffAiToToolbar(true)
        catch {
        }
    }
    g_CmdPal_Visible := false
    g_CmdPal_Revealed := false
    g_CmdPal_HasAnchor := false
    ; 包 1.1：隐藏时降 WebView2 内存档位并 RESET_STATE
    try WebView2_NotifyHidden(g_CmdPal_WV2)
    catch {
    }
    if IsObject(g_CmdPal_Gui) {
        try g_CmdPal_Gui.Hide()
        catch {
        }
        CommandPalette_ClearWindowRegion()
    }
    if handoff {
        if FuncExists("FocusBroker_Release") {
            try FocusBroker_Release("CommandPalette", "search_preempt")
            catch {
            }
            try FocusBroker_Release("LegacyWinActivate", "search_preempt")
            catch {
            }
        }
    } else if FuncExists("CapsLock_NormalizeAfterUiClose")
        CapsLock_NormalizeAfterUiClose()
}

CommandPalette_Dispose(reason := "") {
    global g_CmdPal_Gui, g_CmdPal_Ctrl, g_CmdPal_WV2, g_CmdPal_Ready, g_CmdPal_Visible, g_CmdPal_Revealed
    try CommandPalette_Hide()
    catch {
    }
    SurfaceManager_CloseWebViewControl(g_CmdPal_Ctrl)
    g_CmdPal_Ctrl := 0
    g_CmdPal_WV2 := 0
    g_CmdPal_Ready := false
    g_CmdPal_Visible := false
    g_CmdPal_Revealed := false
    SurfaceManager_DestroyGui(g_CmdPal_Gui)
    g_CmdPal_Gui := 0
    try SurfaceManager_ObserveClose("command_palette", Map("entry", "CommandPalette_Dispose", "reason", String(reason)))
}

CommandPalette_MonitorAtPoint(px, py) {
    count := 1
    try count := MonitorGetCount()
    Loop count {
        l := 0, t := 0, r := 0, b := 0
        try MonitorGet(A_Index, &l, &t, &r, &b)
        catch
            continue
        if (px >= l && px < r && py >= t && py < b)
            return A_Index
    }
    try return MonitorGetPrimary()
    catch
        return 1
}

CommandPalette_GetWorkAreaAtPoint(px, py, &ml, &mt, &mr, &mb) {
    idx := CommandPalette_MonitorAtPoint(px, py)
    ml := 0, mt := 0, mr := A_ScreenWidth, mb := A_ScreenHeight
    try MonitorGetWorkArea(idx, &ml, &mt, &mr, &mb)
    catch {
        try MonitorGet(idx, &ml, &mt, &mr, &mb)
        catch {
        }
    }
    return idx
}

CommandPalette_MaxHeight(expanded := false) {
    global g_CmdPal_Gui, g_CmdPal_Width
    px := A_ScreenWidth // 2
    py := A_ScreenHeight // 2
    if IsObject(g_CmdPal_Gui) {
        try {
            WinGetPos(&wx, &wy, &ww, &wh, g_CmdPal_Gui.Hwnd)
            px := wx + (ww > 0 ? ww : g_CmdPal_Width) // 2
            py := wy + (wh > 0 ? wh : 1) // 2
        } catch {
        }
    } else {
        try MouseGetPos(&px, &py)
        catch {
        }
    }
    ml := 0, mt := 0, mr := A_ScreenWidth, mb := A_ScreenHeight
    CommandPalette_GetWorkAreaAtPoint(px, py, &ml, &mt, &mr, &mb)
    workH := mb - mt
    if (workH < 400)
        workH := A_ScreenHeight
    pct := expanded ? 0.96 : 0.82
    return Max(400, Round(workH * pct))
}

CommandPalette_ApplyHeight(h, expanded := false, actionWorkspace := false) {
    global g_CmdPal_Gui, g_CmdPal_Width, g_CmdPal_CurrentHeight, g_CmdPal_MinHeight
    global g_CmdPal_AnchorX, g_CmdPal_AnchorY, g_CmdPal_HasAnchor
    nh := Integer(h)
    minH := actionWorkspace ? (expanded ? 640 : 560) : g_CmdPal_MinHeight
    if (nh < minH)
        nh := minH
    maxH := CommandPalette_MaxHeight(expanded)
    if (nh > maxH)
        nh := maxH
    g_CmdPal_CurrentHeight := nh
    if !IsObject(g_CmdPal_Gui)
        return
    try {
        WinGetPos(&x, &y, &ww, &wh, g_CmdPal_Gui.Hwnd)
        baseX := g_CmdPal_HasAnchor ? g_CmdPal_AnchorX : x
        baseY := g_CmdPal_HasAnchor ? g_CmdPal_AnchorY : y
        ml := 0, mt := 0, mr := A_ScreenWidth, mb := A_ScreenHeight
        CommandPalette_GetWorkAreaAtPoint(
            baseX + (ww > 0 ? ww : g_CmdPal_Width) // 2,
            baseY + 1,
            &ml, &mt, &mr, &mb
        )
        x := baseX
        y := baseY
        if (y + nh > mb - 8)
            y := Max(mt + 8, mb - 8 - nh)
        if (y < mt + 8)
            y := mt + 8
        g_CmdPal_Gui.Move(x, y, g_CmdPal_Width, nh)
    } catch {
    }
    CommandPalette_ApplyBounds()
    SetTimer(CommandPalette_SyncHostShape, -40)
}

CommandPalette_ApplyMorphHeightStep(token, targetH, step, totalSteps) {
    global g_CmdPal_Gui, g_CmdPal_Width, g_CmdPal_CurrentHeight, g_CmdPal_AiMorphAnimToken, g_CmdPal_MinHeight
    if (token != g_CmdPal_AiMorphAnimToken)
        return
    startH := g_CmdPal_CurrentHeight
    if (step >= totalSteps) {
        CommandPalette_ApplyHeight(targetH)
        return
    }
    t := step / totalSteps
    nh := Round(startH + (targetH - startH) * t)
    if (nh < g_CmdPal_MinHeight)
        nh := g_CmdPal_MinHeight
    g_CmdPal_CurrentHeight := nh
    if IsObject(g_CmdPal_Gui) {
        try {
            WinGetPos(&x, &y, , , g_CmdPal_Gui.Hwnd)
            g_CmdPal_Gui.Move(x, y, g_CmdPal_Width, nh)
        } catch {
        }
        CommandPalette_ApplyBounds()
    }
    SetTimer(CommandPalette_ApplyMorphHeightStep.Bind(token, targetH, step + 1, totalSteps), -28)
}

CommandPalette_ApplyMorphHeight(h, animate := true) {
    global g_CmdPal_AiMorphHeight, g_CmdPal_AiMorphAnimToken, g_CmdPal_CurrentHeight
    targetH := Integer(h)
    if (targetH < g_CmdPal_MinHeight)
        targetH := g_CmdPal_AiMorphHeight
    if (targetH > 480)
        targetH := 480
    if !animate {
        CommandPalette_ApplyHeight(targetH)
        return
    }
    g_CmdPal_AiMorphAnimToken := A_TickCount
    token := g_CmdPal_AiMorphAnimToken
    SetTimer(CommandPalette_ApplyMorphHeightStep.Bind(token, targetH, 1, 8), -1)
}

CommandPalette_IsAiStreaming() {
    global g_CmdPal_AiSession
    if !(g_CmdPal_AiSession is Map)
        return false
    if g_CmdPal_AiSession.Get("ended", false)
        return false
    if g_CmdPal_AiSession.Get("handoff", false)
        return false
    return true
}

CommandPalette_AiSessionMatches(reqId, requireActiveGen := true) {
    global g_CmdPal_AiSession, g_CmdPal_AiStreamGen
    if !(g_CmdPal_AiSession is Map)
        return false
    sid := Trim(String(g_CmdPal_AiSession.Get("reqId", "")))
    if (sid = "")
        return false
    if (reqId != "" && sid != Trim(String(reqId)))
        return false
    if requireActiveGen {
        gen := Integer(g_CmdPal_AiSession.Get("gen", 0))
        if (gen != g_CmdPal_AiStreamGen)
            return false
    }
    return true
}

CommandPalette_EnsureFtbEngineForAi() {
    CommandPalette_BootstrapNiumaChat("palette_ai_engine", false)
}

CommandPalette_JsEscapeForParse(s) {
    s := String(s)
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, "'", "\'")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    return s
}

CommandPalette_InjectFtbHostPayload(payload) {
    if !(payload is Map)
        return false
    if FuncExists("CommandPalette_FtbUsesHubInject") && CommandPalette_FtbUsesHubInject() {
        mode := CommandPalette_FtbTransportMode()
        if (mode = "hybrid") && FuncExists("FloatingToolbarWails_DeliverPayloadHybrid")
            return !!FloatingToolbarWails_DeliverPayloadHybrid(payload)
        if (mode = "wails_shell") && FuncExists("FloatingToolbarWails_DeliverPayload")
            return !!FloatingToolbarWails_DeliverPayload(payload)
        return false
    }
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return false
    jsonStr := ""
    try jsonStr := Jxon_Dump(payload)
    catch {
        return false
    }
    if (jsonStr = "")
        return false
    escaped := CommandPalette_JsEscapeForParse(jsonStr)
    js := "try{if(window.__niumaHostInject)window.__niumaHostInject('" . escaped . "');"
        . "else if(window.chrome&&window.chrome.webview)window.chrome.webview.postMessage(JSON.stringify({type:'niuma_palette_ai_trace',step:'inject_no_fn',detail:'missing'}));"
        . "}catch(e){try{if(window.chrome&&window.chrome.webview)window.chrome.webview.postMessage(JSON.stringify({type:'niuma_palette_ai_trace',step:'inject_err',detail:String(e&&e.message||e)}));}catch(_){}}"
    try {
        g_FTB_WV2.ExecuteScriptAsync(js)
    } catch {
        return false
    }
    ; 注入仅为加速通道，不能代表已送达；队列成功由 DeliverFtbPayload 判定
    return false
}

CommandPalette_FtbTransportMode(*) {
    if FuncExists("PaletteAgent_FtbTransportReady") {
        tr := PaletteAgent_FtbTransportReady()
        if (tr = "hybrid")
            return "hybrid"
        if (tr = "wails_shell")
            return "wails_shell"
        if (tr = "ahk_wv2")
            return "ahk_wv2"
    }
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    if IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady
        return "ahk_wv2"
    return ""
}

CommandPalette_FtbUsesHubInject(*) {
    mode := CommandPalette_FtbTransportMode()
    return (mode = "wails_shell" || mode = "hybrid")
}

CommandPalette_DeliverFtbPayload(payload) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    if !(payload is Map)
        return false
    mode := CommandPalette_FtbTransportMode()
    if (mode = "hybrid") {
        if FuncExists("FloatingToolbarWails_DeliverPayloadHybrid")
            return !!FloatingToolbarWails_DeliverPayloadHybrid(payload)
        return false
    }
    if (mode = "wails_shell") {
        if FuncExists("FloatingToolbarWails_DeliverPayload")
            return !!FloatingToolbarWails_DeliverPayload(payload)
        return false
    }
    if (mode != "ahk_wv2")
        return false
    ok := false
    try {
        if FuncExists("WebView_QueuePayload")
            WebView_QueuePayload(g_FTB_WV2, payload)
        else
            g_FTB_WV2.PostWebMessageAsJson(Jxon_Dump(payload))
        ok := true
    } catch {
    }
    if CommandPalette_InjectFtbHostPayload(payload)
        ok := true
    return ok
}

CommandPalette_InvokeFtbPaletteAiSyncScript(reqId, q) {
    if FuncExists("CommandPalette_DeliverFtbPayload") {
        try {
            if CommandPalette_DeliverFtbPayload(Map("type", "host_palette_ai_sync", "reqId", String(reqId), "query", String(q)))
                return true
        } catch {
        }
    }
    global g_FTB_WV2
    if !IsObject(g_FTB_WV2)
        return false
    argsJson := "{}"
    try argsJson := Jxon_Dump(Map("reqId", String(reqId), "query", String(q)))
    catch {
        return false
    }
    escaped := CommandPalette_JsEscapeForParse(argsJson)
    js := "try{var o=JSON.parse('" . escaped . "');"
        . "if(window.paletteSyncAnswerForReq)window.paletteSyncAnswerForReq(o.reqId,o.query);"
        . "else if(window.__niumaHostInject)window.__niumaHostInject(JSON.stringify({type:'host_palette_ai_sync',reqId:o.reqId,query:o.query}));"
        . "}catch(e){try{if(window.chrome&&window.chrome.webview)window.chrome.webview.postMessage(JSON.stringify({type:'niuma_palette_ai_trace',step:'sync_script_err',detail:String(e&&e.message||e)}));}catch(_){}}"
    try {
        g_FTB_WV2.ExecuteScriptAsync(js)
        return true
    } catch {
        return false
    }
}

CommandPalette_ParseScriptJson(raw) {
    raw := Trim(String(raw))
    if (raw = "" || raw = "null" || raw = "undefined")
        return Map()
    try {
        if (SubStr(raw, 1, 1) = '"') {
            inner := Jxon_Load(raw)
            if (inner is String)
                return Jxon_Load(inner)
            if (inner is Map)
                return inner
        }
        parsed := Jxon_Load(raw)
        if (parsed is Map)
            return parsed
    } catch {
    }
    return Map()
}

CommandPalette_SyncFtbContextForPalette(prov, reqId := "") {
    prov := CommandPalette_NormalizeAiProvider(prov)
    if FuncExists("CommandPalette_FtbUsesHubInject") && CommandPalette_FtbUsesHubInject() {
        ok := false
        if FuncExists("CommandPalette_DeliverFtbPayload") {
            try ok := !!CommandPalette_DeliverFtbPayload(Map("type", "host_request_palette_ai_llm", "reqId", String(reqId), "provider", prov))
            catch {
            }
            try CommandPalette_DeliverFtbPayload(Map("type", "niuma_request_studio_context"))
            catch {
            }
        }
        CommandPalette_PullLiveKeysFromFtb()
        CommandPalette_RequestFtbLlmExport(prov, reqId)
        return ok
    }
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return false
    provEsc := CommandPalette_JsEscapeForParse(prov)
    js := "(function(){try{"
        . "if(typeof exportPaletteLlmForProvider!=='function')return JSON.stringify({ok:0,err:'no_export_fn'});"
        . "var llm=exportPaletteLlmForProvider('" . provEsc . "');"
        . "var keys=(typeof __niumaPaletteExportApiKeys==='function')?__niumaPaletteExportApiKeys():{};"
        . "return JSON.stringify({ok:1,llm:llm||{},apiKeys:keys||{}});"
        . "}catch(e){return JSON.stringify({ok:0,err:String(e&&e.message||e)});}})();"
    ok := false
    try {
        raw := g_FTB_WV2.ExecuteScriptAsync(js).await(5000)
        data := CommandPalette_ParseScriptJson(raw)
        if !(data is Map) || !data.Get("ok", false)
            CommandPalette_AiLog("ai_ftb_pull_fail", SubStr(String(data.Get("err", raw)), 1, 120))
        else {
            if data.Has("apiKeys")
                CommandPalette_ApplyLiveAiKeys(CommandPalette_CoerceToMap(data["apiKeys"]), prov)
            llm := data.Has("llm") ? data["llm"] : Map()
            if (llm is Map) {
                msg := Map("llm", llm, "provider", prov, "reqId", String(reqId))
                CommandPalette_OnNiumaPaletteAiLlm(msg)
            }
            ok := true
        }
    } catch as ePull {
        CommandPalette_AiLog("ai_ftb_pull_err", ePull.Message)
    }
    CommandPalette_PullLiveKeysFromFtb()
    CommandPalette_RequestFtbLlmExport(prov, reqId)
    return ok
}

CommandPalette_PollFtbPaletteLastResult(reqId, gen) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_CmdPal_AiSession
    if !CommandPalette_AiSessionMatches(reqId, false)
        return false
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return false
  js := "(function(){try{return JSON.stringify(window.__niumaPaletteLastResult||{});}catch(e){return '{}';}})();"
    try {
        raw := g_FTB_WV2.ExecuteScriptAsync(js).await(800)
        data := CommandPalette_ParseScriptJson(raw)
        if !(data is Map)
            return false
        rid := Trim(String(data.Get("reqId", "")))
        if (rid != "" && rid != Trim(String(reqId)))
            return false
        ans := Trim(String(data.Get("answer", "")))
        q := (g_CmdPal_AiSession is Map) ? Trim(String(g_CmdPal_AiSession.Get("query", ""))) : ""
        if (ans = "" || (q != "" && ans = q))
            return false
        CommandPalette_AiLog("ai_poll_hit", "reqId=" . reqId . " len=" . StrLen(ans))
        CommandPalette_PushAiStreamEnd(reqId, gen, ans)
        return true
    } catch {
        return false
    }
}

CommandPalette_InvokeFtbPaletteAiScript(reqId, q, prov) {
    global g_FTB_WV2
    if !IsObject(g_FTB_WV2)
        return false
    argsJson := "{}"
    try argsJson := Jxon_Dump(Map("reqId", String(reqId), "query", String(q), "provider", String(prov)))
    catch {
        return false
    }
    escaped := CommandPalette_JsEscapeForParse(argsJson)
    js := "try{if(window.chrome&&window.chrome.webview)window.chrome.webview.postMessage(JSON.stringify({type:'niuma_palette_ai_trace',step:'exec_probe',detail:'reqId=" . CommandPalette_JsEscapeForParse(String(reqId)) . "'}));}catch(_){}"
        . "try{var o=JSON.parse('" . escaped . "');if(window.__nmerPaletteAiStart)window.__nmerPaletteAiStart(o);"
        . "else if(window.runPaletteAiStream)window.runPaletteAiStream(o.reqId,o.query,o.provider);"
        . "else if(window.chrome&&window.chrome.webview)window.chrome.webview.postMessage(JSON.stringify({type:'niuma_palette_ai_trace',step:'exec_no_fn',detail:'missing'}));"
        . "}catch(e){try{if(window.chrome&&window.chrome.webview)window.chrome.webview.postMessage(JSON.stringify({type:'niuma_palette_ai_trace',step:'exec_script_err',detail:String(e&&e.message||e)}));}catch(_){}}"
    try {
        g_FTB_WV2.ExecuteScriptAsync(js)
        return true
    } catch {
        return false
    }
}

CommandPalette_ResolveAiLlmForProvider(provider := "") {
    global g_CmdPal_LiveAiKeys, g_CmdPal_LiveLlmFromFtb
    prov := CommandPalette_NormalizeAiProvider(provider)
    llm := Map("provider", prov, "apiKey", "", "baseUrl", "", "model", "")
    if IsObject(g_CmdPal_LiveLlmFromFtb) && g_CmdPal_LiveLlmFromFtb.Has(prov) {
        live := g_CmdPal_LiveLlmFromFtb[prov]
        if (live is Map) && Trim(String(live.Get("apiKey", ""))) != "" {
            llm["apiKey"] := Trim(String(live.Get("apiKey", "")))
            llm["baseUrl"] := Trim(String(live.Get("baseUrl", "")))
            llm["model"] := Trim(String(live.Get("model", "")))
            if FuncExists("LlmApiPing_NormalizeApiKey")
                try llm["apiKey"] := LlmApiPing_NormalizeApiKey(llm["apiKey"])
                catch {
                }
            if (prov = "kimi") && FuncExists("LlmApiPing_NormalizeMoonshotBase")
                llm["baseUrl"] := LlmApiPing_NormalizeMoonshotBase(llm["baseUrl"])
            CommandPalette_EnsureLlmEndpoint(llm, prov)
            return llm
        }
    }
    bundle := CommandPalette_ReadNiumaLlmSyncMap()
    sync := bundle.Has("sync") ? bundle["sync"] : 0
    activeProv := ""
    if (sync is Map) {
        llmIn := sync.Has("llm") && sync["llm"] is Map ? sync["llm"] : sync
        activeProv := CommandPalette_NormalizeAiProvider(llmIn.Get("provider", ""))
        if (prov = "")
            prov := activeProv
        llm["provider"] := prov
        key := ""
        if sync.Has("apiKeys") && sync["apiKeys"] is Map && prov != ""
            key := Trim(String(sync["apiKeys"].Get(prov, "")))
        if (key = "" && prov = activeProv)
            key := Trim(String(llmIn.Get("apiKey", "")))
        if (key = "" && IsObject(g_CmdPal_LiveAiKeys) && prov != "")
            key := Trim(String(g_CmdPal_LiveAiKeys.Get(prov, "")))
        if FuncExists("LlmApiPing_NormalizeApiKey")
            try key := LlmApiPing_NormalizeApiKey(key)
            catch {
            }
        llm["apiKey"] := key
        base := ""
        model := ""
        ; 仅当与 Niuma 当前活动 provider 一致时才继承 llm.baseUrl/model，避免选 Kimi 却打到 MiniMax 等地址
        if (prov != "" && prov = activeProv) {
            base := Trim(String(llmIn.Get("baseUrl", "")))
            model := Trim(String(llmIn.Get("model", "")))
        }
        if (base = "" || model = "") && FuncExists("LlmApiPing_PresetFor") && prov != "" {
            try {
                pre := LlmApiPing_PresetFor(prov)
                if (base = "")
                    base := Trim(String(pre.Get("baseUrl", "")))
                if (model = "")
                    model := Trim(String(pre.Get("model", "")))
            } catch {
            }
        }
        if (prov = "kimi") && base != "" && FuncExists("LlmApiPing_BaseUrlMatchesProvider") {
            try {
                if !LlmApiPing_BaseUrlMatchesProvider("kimi", base) {
                    preFix := LlmApiPing_PresetFor("kimi")
                    base := Trim(String(preFix.Get("baseUrl", base)))
                }
            } catch {
            }
        }
        llm["baseUrl"] := base
        llm["model"] := model
    } else {
        if (prov = "")
            prov := CommandPalette_NormalizeAiProvider("")
        llm["provider"] := prov
        if IsObject(g_CmdPal_LiveAiKeys) && prov != ""
            llm["apiKey"] := Trim(String(g_CmdPal_LiveAiKeys.Get(prov, "")))
        if FuncExists("LlmApiPing_PresetFor") && prov != "" {
            try {
                pre := LlmApiPing_PresetFor(prov)
                llm["baseUrl"] := Trim(String(pre.Get("baseUrl", "")))
                llm["model"] := Trim(String(pre.Get("model", "")))
            } catch {
            }
        }
    }
    if (prov = "kimi") && FuncExists("LlmApiPing_NormalizeMoonshotBase")
        llm["baseUrl"] := LlmApiPing_NormalizeMoonshotBase(llm["baseUrl"])
    CommandPalette_EnsureLlmEndpoint(llm, prov)
    return llm
}

CommandPalette_EnsureLlmEndpoint(llm, prov := "") {
    if !(llm is Map)
        return
    prov := CommandPalette_NormalizeAiProvider(prov != "" ? prov : llm.Get("provider", ""))
    llm["provider"] := prov
    base := Trim(String(llm.Get("baseUrl", "")))
    model := Trim(String(llm.Get("model", "")))
    if ((base = "" || model = "") && FuncExists("LlmApiPing_PresetFor") && prov != "") {
        try {
            pre := LlmApiPing_PresetFor(prov)
            if (base = "")
                base := Trim(String(pre.Get("baseUrl", "")))
            if (model = "")
                model := Trim(String(pre.Get("model", "")))
        } catch {
        }
    }
    if (prov = "kimi") {
        if (model = "")
            model := "kimi-k2.6"
        if FuncExists("LlmApiPing_NormalizeMoonshotBase")
            base := LlmApiPing_NormalizeMoonshotBase(base)
        if (base = "")
            base := "https://api.moonshot.cn/v1"
    } else if (prov = "minimax") {
        if (model = "")
            model := "MiniMax-M2.7"
        if (base = "")
            base := "https://api.minimaxi.com/anthropic"
    }
    llm["baseUrl"] := base
    llm["model"] := model
}

CommandPalette_AiStreamAlreadyResponded() {
    global g_CmdPal_AiSession
    if !(g_CmdPal_AiSession is Map)
        return false
    if g_CmdPal_AiSession.Get("directStarted", false)
        return true
    if g_CmdPal_AiSession.Get("ended", false)
        return true
    if Integer(g_CmdPal_AiSession.Get("webAnswerChunks", 0)) > 0
        return true
    return false
}

CommandPalette_IsPaletteAiReq(reqId) {
    return RegExMatch(Trim(String(reqId)), "i)^cpai_")
}

CommandPalette_ShouldMirrorAiToPalette() {
    global g_CmdPal_AiSession, g_CmdPal_Visible
    if !(g_CmdPal_AiSession is Map)
        return false
    if !g_CmdPal_Visible
        return false
    if g_CmdPal_AiSession.Get("handoff", false)
        return false
    return true
}

CommandPalette_StopAiStreamSideEffects(oldReqId := "") {
    global g_CmdPal_AiRetryToken, g_CmdPal_AiWatchdogToken, g_FTB_WV2
    g_CmdPal_AiRetryToken := A_TickCount
    g_CmdPal_AiWatchdogToken := A_TickCount
    CommandPalette_StopFtbAnswerPoll()
    rid := Trim(String(oldReqId))
    if (rid != "") && FuncExists("CoreAsyncHttp_Cancel") {
        try CoreAsyncHttp_Cancel(rid)
        catch {
        }
    }
    ; 仅取消悬浮栏侧 palette 流，禁止广播 niuma_llm_http_cancel *（会误杀命令面板宿主直连）
    if (rid != "") && FuncExists("CommandPalette_DeliverFtbPayload") {
        try CommandPalette_DeliverFtbPayload(Map("type", "host_palette_ai_stream_cancel", "reqId", rid))
        catch {
        }
    }
}

CommandPalette_FormatAiHttpError(status, err, text := "", prov := "") {
    err := Trim(String(err))
    st := Integer(status)
    body := Trim(String(text))
    pk := CommandPalette_NormalizeAiProvider(prov)
    if FuncExists("LlmApiPing_FormatHttpError") {
        try {
            fe := LlmApiPing_FormatHttpError(Map("ok", false, "status", st, "text", body, "error", err), pk != "" ? pk : "openai")
            if (fe != "")
                return fe
        } catch {
        }
    }
    if (st = 429) || RegExMatch(err, "i)429|too\s*many|rate\s*limit")
        return "请求过于频繁（429），请稍等几秒后再发"
    if (st = 401) || RegExMatch(err, "i)401|http_status_401|unauthorized|invalid.*api|api[_ ]?key")
        return (pk = "kimi")
            ? "Kimi API Key 无效或未授权（401）。请在 Niuma Chat「API 设置」重新保存密钥并点「测试 API」；国内 Key→api.moonshot.cn/v1，国际 Key→api.moonshot.ai/v1（不可混用）"
            : "API Key 无效或未授权，请检查 Niuma Chat 设置"
    if (st = 403)
        return "访问被拒绝（403），请检查 API Key 与 Base URL"
    if (pk = "kimi") && RegExMatch(err, "i)temperature")
        return "Kimi K2 系列仅允许 temperature=1，已自动修正；请重载脚本后再试"
    if (pk = "kimi") && (st = 404 || RegExMatch(err, "i)404|not\s*found"))
        return "Kimi 请求 404：请确认 Key 与区域一致（国内 api.moonshot.cn/v1 / 国际 api.moonshot.ai/v1），且模型已在平台开通；可改选 moonshot-v1-8k"
    if RegExMatch(body, '"message"\s*:\s*"([^"]+)"', &m)
        return m[1]
    if (err != "" && err != "http_status_404")
        return err
    if (st = 404)
        return "HTTP 404：请检查 Base URL 是否含 /v1 及模型名是否在账号内可用"
    if (st >= 400)
        return "HTTP " . st
    if (st = 0) {
        if (pk = "kimi")
            return "无法连接 Kimi API（网络/TLS/代理）。请在 Niuma Chat 设置里点「测试 API」确认密钥与 Base URL"
        return "无法连接 API（网络/TLS/代理）。请在 Niuma Chat 设置里点「测试 API」确认密钥可用"
    }
    return (pk = "kimi") ? ("Kimi 请求失败（HTTP " . st . "）") : "请求失败"
}

CommandPalette_ArmAiDirectOnce(reqId, q, prov, gen) {
    global g_CmdPal_AiRetryToken
    if !CommandPalette_IsPaletteAiReq(reqId)
        return
    g_CmdPal_AiRetryToken := A_TickCount
    token := g_CmdPal_AiRetryToken
    for delayMs in [3800, 7000, 14000] {
        SetTimer(CommandPalette_TryDirectAiFallback.Bind(reqId, q, prov, gen, token), -delayMs)
    }
}

CommandPalette_StopFtbAnswerPoll() {
    global g_CmdPal_AiPollToken
    g_CmdPal_AiPollToken := A_TickCount
}

CommandPalette_HasSubstantivePaletteAnswer() {
    global g_CmdPal_AiSession
    if !(g_CmdPal_AiSession is Map)
        return false
    if Integer(g_CmdPal_AiSession.Get("webAnswerChunks", 0)) > 0
        return true
    acc := Trim(String(g_CmdPal_AiSession.Get("answer", "")))
    if (acc = "")
        return false
    stripped := RegExReplace(acc, "s)[\s⏳💭🔄…\r\n]+", "")
    if (stripped = "")
        return false
    if RegExMatch(acc, "s)^[\s⏳💭🔄宿主直连「」']+$")
        return false
    return true
}

CommandPalette_RequestFtbAnswerSync(reqId) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_CmdPal_AiSession
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return false
    q := ""
    if (g_CmdPal_AiSession is Map)
        q := String(g_CmdPal_AiSession.Get("query", ""))
    payload := Map("type", "host_palette_ai_sync", "reqId", String(reqId), "query", q)
    try {
        ok := CommandPalette_DeliverFtbPayload(payload)
        try CommandPalette_InvokeFtbPaletteAiSyncScript(reqId, q)
        catch {
        }
        CommandPalette_AiLog("ai_ftb_sync_req", "reqId=" . reqId . " ok=" . (ok ? 1 : 0))
        return ok
    } catch as eSync {
        CommandPalette_AiLog("ai_ftb_sync_req_err", eSync.Message)
        return false
    }
}

CommandPalette_TrySyncAnswerFromFtb(reqId, gen, token) {
    global g_CmdPal_AiSession, g_CmdPal_AiPollToken
    if (token != g_CmdPal_AiPollToken)
        return
    if !CommandPalette_AiSessionMatches(reqId, false)
        return
    if !(g_CmdPal_AiSession is Map)
        return
    if g_CmdPal_AiSession.Get("ended", false) && CommandPalette_HasSubstantivePaletteAnswer()
        return
    if CommandPalette_HasSubstantivePaletteAnswer()
        return
    if CommandPalette_PollFtbPaletteLastResult(reqId, gen)
        return
    CommandPalette_RequestFtbAnswerSync(reqId)
}

CommandPalette_ArmFtbAnswerPoll(reqId, gen) {
    global g_CmdPal_AiPollToken
    g_CmdPal_AiPollToken := A_TickCount
    token := g_CmdPal_AiPollToken
    for delayMs in [800, 1500, 2500, 4000, 6000, 9000, 13000, 18000, 28000, 40000, 55000, 75000, 95000, 110000] {
        SetTimer(CommandPalette_TrySyncAnswerFromFtb.Bind(reqId, gen, token), -delayMs)
    }
}

CommandPalette_HasDirectHttp() {
    global g_CoreAsyncHttp_Loaded
    if IsSet(g_CoreAsyncHttp_Loaded) && g_CoreAsyncHttp_Loaded
        return true
    if IsSet(g_CoreAsyncHttpReqs) && (g_CoreAsyncHttpReqs is Map)
        return true
    return false
}

; 不依赖 FuncExists（v2 对部分全局函数会误报）；与 MiniMax 直连同走 CoreAsyncHttp
CommandPalette_PostHttpJsonAsync(method, url, body, callback, opts := 0) {
    try {
        CoreAsyncHttp_SendAsync(method, url, body, callback, opts)
        return true
    } catch as e1 {
        try {
            HttpJsonAsync(method, url, body, callback, opts)
            return true
        } catch as e2 {
            CommandPalette_AiLog("http_async_fail", SubStr(String(e2.Message), 1, 120))
            return false
        }
    }
}

CommandPalette_LlmHttpSync(method, url, headers, body, timeoutMs := 90000) {
    try
        return LlmApiPing_HttpSync(method, url, headers, body, timeoutMs)
    catch as e {
        return Map("ok", false, "status", 0, "text", "", "error", e.Message)
    }
}

CommandPalette_TryDirectAiFallback(reqId, q, prov, gen, token) {
    global g_CmdPal_AiSession, g_CmdPal_AiRetryToken
    if (token != g_CmdPal_AiRetryToken)
        return
    if !CommandPalette_AiSessionMatches(reqId, false)
        return
    if CommandPalette_AiStreamAlreadyResponded()
        return
    if CommandPalette_PollFtbPaletteLastResult(reqId, gen)
        return
    if (g_CmdPal_AiSession is Map) && Integer(g_CmdPal_AiSession.Get("webAnswerChunks", 0)) > 0
        return
    provNorm := CommandPalette_NormalizeAiProvider(prov)
    if (provNorm = "kimi")
        CommandPalette_SyncFtbContextForPalette(provNorm, reqId)
    g_CmdPal_AiSession["directStarted"] := true
    CommandPalette_RequestFtbLlmExport(prov, reqId)
    CommandPalette_AiLog("ai_direct_begin", "reqId=" . reqId . " provider=" . prov)
    llmDbg := CommandPalette_ResolveAiLlmForProvider(prov)
    CommandPalette_AiLog("ai_direct_llm", "base=" . SubStr(String(llmDbg.Get("baseUrl", "")), 1, 64)
        . " model=" . String(llmDbg.Get("model", "")) . " keyLen=" . StrLen(String(llmDbg.Get("apiKey", ""))))
    CommandPalette_RunDirectAiStream(reqId, q, prov, gen)
}

CommandPalette_RunDirectAiStream(reqId, q, prov, gen) {
    global g_CmdPal_AiSession
    llm := CommandPalette_ResolveAiLlmForProvider(prov)
    p := CommandPalette_NormalizeAiProvider(llm.Get("provider", prov))
    paletteReq := CommandPalette_IsPaletteAiReq(reqId)
    if !paletteReq && (p = "kimi") {
        CommandPalette_AiLog("ai_direct_skip", "provider=kimi non_palette")
        return
    }
    if !paletteReq && (g_CmdPal_AiSession is Map) && g_CmdPal_AiSession.Get("ftbDispatched", false) {
        CommandPalette_AiLog("ai_direct_skip", "provider=" . p . " ftb=1")
        return
    }
    key := Trim(String(llm.Get("apiKey", "")))
    if (key = "") {
        CommandPalette_PushAiStreamError(reqId, gen, "未配置 API Key，请在 Niuma Chat 设置中填写")
        return
    }
    if CommandPalette_HasDirectHttp() {
        if (p = "minimax")
            CommandPalette_DirectMinimaxStream(reqId, q, llm, gen)
        else if (p = "claude")
            CommandPalette_DirectClaudeStream(reqId, q, llm, gen)
        else if (p = "kimi")
            CommandPalette_RunDirectKimiStreamSync(reqId, q, llm, gen)
        else
            CommandPalette_DirectOpenAiStream(reqId, q, llm, gen)
        return
    }
    if FuncExists("LlmApiPing_HttpSync") {
        CommandPalette_AiLog("ai_direct_sync", "reqId=" . reqId . " provider=" . p)
        if (p = "kimi")
            SetTimer(CommandPalette_RunDirectKimiStreamSync.Bind(reqId, q, llm, gen), -15)
        else
            SetTimer(CommandPalette_RunDirectAiStreamSync.Bind(reqId, q, llm, gen, p), -15)
        return
    }
    CommandPalette_PushAiStreamError(reqId, gen, "悬浮栏未响应且宿主 HTTP 模块未加载，请完全退出并重载 牛马.ahk")
}

CommandPalette_RunDirectAiStreamSync(reqId, q, llm, gen, provKind) {
    if !CommandPalette_AiSessionMatches(reqId, false)
        return
    pk := CommandPalette_NormalizeAiProvider(provKind)
    if (pk = "kimi") {
        CommandPalette_RunDirectKimiStreamSync(reqId, q, llm, gen)
        return
    }
    CommandPalette_EnsureLlmEndpoint(llm, pk)
    key := Trim(String(llm.Get("apiKey", "")))
    base := Trim(String(llm.Get("baseUrl", "")))
    model := Trim(String(llm.Get("model", "")))
    if (model = "")
        model := "MiniMax-M2.7"
    url := ""
    body := ""
    headers := Map("Content-Type", "application/json")
    if (pk = "minimax") {
        url := FuncExists("LlmApiPing_MinimaxAnthropicUrl") ? LlmApiPing_MinimaxAnthropicUrl(base) : (base . "/v1/messages")
        body := Jxon_Dump(Map("model", model, "max_tokens", 4096, "messages", [Map("role", "user", "content", String(q))], "stream", false))
        headers["Authorization"] := "Bearer " . key
        headers["anthropic-version"] := "2023-06-01"
        CommandPalette_PushAiStreamChunk(reqId, gen, "🔄 宿主直连 MiniMax…`n")
    } else if (pk = "claude") {
        url := FuncExists("LlmApiPing_ClaudeMessagesUrl") ? LlmApiPing_ClaudeMessagesUrl(base) : (base . "/v1/messages")
        body := Jxon_Dump(Map("model", model, "max_tokens", 4096, "messages", [Map("role", "user", "content", String(q))]))
        headers["x-api-key"] := key
        headers["anthropic-version"] := "2023-06-01"
        CommandPalette_PushAiStreamChunk(reqId, gen, "🔄 宿主直连 Claude…`n")
    } else {
        url := FuncExists("LlmApiPing_OpenAIChatUrl") ? LlmApiPing_OpenAIChatUrl(base) : (base . "/chat/completions")
        if FuncExists("LlmApiPing_BuildChatBody")
            body := LlmApiPing_BuildChatBody(pk, model, q, 4096)
        else
            body := Jxon_Dump(Map("model", model, "messages", [Map("role", "user", "content", String(q))], "max_tokens", 4096))
        headers["Authorization"] := "Bearer " . key
        CommandPalette_PushAiStreamChunk(reqId, gen, "🔄 宿主直连模型…`n")
    }
    r := LlmApiPing_HttpSync("POST", url, headers, body, 90000)
    if (pk = "kimi") && !(r.Get("ok", false)) && FuncExists("LlmApiPing_KimiChatBodies") && FuncExists("LlmApiPing_OpenAIChatUrl") {
        st := r.Has("status") ? Integer(r["status"]) : 0
        if (st = 404 || st = 400) {
            for _, altBody in LlmApiPing_KimiChatBodies(model, q, 4096) {
                if (altBody = body)
                    continue
                r2 := LlmApiPing_HttpSync("POST", url, headers, altBody, 90000)
                if r2.Get("ok", false) {
                    r := r2
                    break
                }
                r := r2
            }
        }
        if !(r.Get("ok", false)) && RegExMatch(model, "i)^kimi-k2") {
            fb := Map("model", "moonshot-v1-8k", "messages", [Map("role", "user", "content", String(q))], "max_tokens", 4096, "temperature", 0.7)
            r3 := LlmApiPing_HttpSync("POST", url, headers, Jxon_Dump(fb), 90000)
            if r3.Get("ok", false)
                r := r3
        }
    }
    CommandPalette_OnDirectLlmDone(reqId, gen, pk, r)
}

CommandPalette_DirectMinimaxStream(reqId, q, llm, gen) {
    key := Trim(String(llm.Get("apiKey", "")))
    base := Trim(String(llm.Get("baseUrl", "")))
    model := Trim(String(llm.Get("model", "")))
    if (model = "")
        model := "MiniMax-M2.7"
    url := FuncExists("LlmApiPing_MinimaxAnthropicUrl") ? LlmApiPing_MinimaxAnthropicUrl(base) : (base . "/v1/messages")
    body := Jxon_Dump(Map(
        "model", model,
        "max_tokens", 4096,
        "messages", [Map("role", "user", "content", String(q))],
        "stream", false
    ))
    headers := Map(
        "Content-Type", "application/json",
        "Authorization", "Bearer " . key,
        "anthropic-version", "2023-06-01"
    )
    HttpJsonAsync("POST", url, body, CommandPalette_OnDirectLlmDone.Bind(reqId, gen, "minimax"), Map(
        "headers", headers,
        "timeoutMs", 90000,
        "receiveTimeoutMs", 90000,
        "tag", "cmdpal_ai_direct",
        "reqId", reqId
    ))
}

CommandPalette_DirectClaudeStream(reqId, q, llm, gen) {
    key := Trim(String(llm.Get("apiKey", "")))
    base := Trim(String(llm.Get("baseUrl", "")))
    model := Trim(String(llm.Get("model", "")))
    url := FuncExists("LlmApiPing_ClaudeMessagesUrl") ? LlmApiPing_ClaudeMessagesUrl(base) : (base . "/v1/messages")
    body := Jxon_Dump(Map(
        "model", model,
        "max_tokens", 4096,
        "messages", [Map("role", "user", "content", String(q))]
    ))
    headers := Map(
        "Content-Type", "application/json",
        "x-api-key", key,
        "anthropic-version", "2023-06-01"
    )
    CommandPalette_PushAiStreamChunk(reqId, gen, "🔄 宿主直连 Claude…`n")
    HttpJsonAsync("POST", url, body, CommandPalette_OnDirectLlmDone.Bind(reqId, gen, "claude"), Map(
        "headers", headers,
        "timeoutMs", 90000,
        "receiveTimeoutMs", 90000,
        "tag", "cmdpal_ai_direct",
        "reqId", reqId
    ))
}

CommandPalette_DirectOpenAiStream(reqId, q, llm, gen) {
    pk := CommandPalette_NormalizeAiProvider(llm.Get("provider", ""))
    if (pk = "kimi") {
        CommandPalette_RunDirectKimiStreamSync(reqId, q, llm, gen)
        return
    }
    CommandPalette_EnsureLlmEndpoint(llm, pk)
    key := Trim(String(llm.Get("apiKey", "")))
    base := Trim(String(llm.Get("baseUrl", "")))
    model := Trim(String(llm.Get("model", "")))
    url := FuncExists("LlmApiPing_OpenAIChatUrl") ? LlmApiPing_OpenAIChatUrl(base) : (base . "/chat/completions")
    if !RegExMatch(url, "i)^https?://") {
        CommandPalette_PushAiStreamError(reqId, gen, "模型 Base URL 无效，请在 Niuma Chat 设置中填写或重选 Kimi")
        return
    }
    if FuncExists("LlmApiPing_BuildChatBody")
        body := LlmApiPing_BuildChatBody(pk, model, q, 4096)
    else
        body := Jxon_Dump(Map("model", model, "messages", [Map("role", "user", "content", String(q))], "max_tokens", 4096))
    headers := Map(
        "Content-Type", "application/json",
        "Authorization", "Bearer " . key
    )
    CommandPalette_PushAiStreamChunk(reqId, gen, "🔄 宿主直连模型…`n")
    HttpJsonAsync("POST", url, body, CommandPalette_OnDirectLlmDone.Bind(reqId, gen, pk), Map(
        "headers", headers,
        "timeoutMs", 90000,
        "receiveTimeoutMs", 90000,
        "tag", "cmdpal_ai_direct",
        "reqId", reqId
    ))
}

CommandPalette_BuildKimiChatBody(mod, q, maxTokens := 2048) {
    mod := Trim(String(mod))
    if (mod = "")
        mod := "kimi-k2.6"
    tok := Max(64, Integer(maxTokens))
    m := Map(
        "model", mod,
        "messages", [Map("role", "user", "content", String(q))]
    )
    if RegExMatch(mod, "i)^kimi-k2")
        m["max_completion_tokens"] := tok, m["temperature"] := 1
    else
        m["max_tokens"] := tok
    return Jxon_Dump(m)
}

CommandPalette_KimiChatUrl(base) {
    bu := Trim(String(base))
    if FuncExists("LlmApiPing_NormalizeMoonshotBase")
        bu := LlmApiPing_NormalizeMoonshotBase(bu)
    if (bu = "")
        bu := "https://api.moonshot.cn/v1"
    if FuncExists("LlmApiPing_OpenAIChatUrl")
        return LlmApiPing_OpenAIChatUrl(bu)
    bu := RegExReplace(bu, "/+$", "")
    if RegExMatch(bu, "i)^https?://api\.moonshot\.(cn|ai)$")
        bu .= "/v1"
    return InStr(StrLower(bu), "/chat/completions") ? bu : (bu . "/chat/completions")
}

CommandPalette_BuildKimiDirectPlan(q, llm) {
    key := Trim(String(llm.Get("apiKey", "")))
    if (key = "")
        return Map("error", "未配置 Kimi API Key", "plan", [], "planLen", 0, "headers", Map())
    model := Trim(String(llm.Get("model", "")))
    if (model = "")
        model := "kimi-k2.6"
    baseIn := Trim(String(llm.Get("baseUrl", "")))
    if FuncExists("LlmApiPing_NormalizeMoonshotBase")
        baseIn := LlmApiPing_NormalizeMoonshotBase(baseIn)
    bases := []
    if (baseIn != "")
        bases.Push(baseIn)
    for altBu in ["https://api.moonshot.cn/v1", "https://api.moonshot.ai/v1"] {
        if !CommandPalette_ArrayHasValue(bases, altBu)
            bases.Push(altBu)
    }
    models := [model]
    if RegExMatch(model, "i)^kimi-k2") && !CommandPalette_ArrayHasValue(models, "moonshot-v1-8k")
        models.Push("moonshot-v1-8k")
    tok := 2048
    plan := []
    seen := Map()
    headers := Map("Content-Type", "application/json", "Authorization", "Bearer " . key)
    for _, bu in bases {
        url := CommandPalette_KimiChatUrl(bu)
        for _, mod in models {
            bodies := [CommandPalette_BuildKimiChatBody(mod, q, tok)]
            if FuncExists("LlmApiPing_KimiChatBodies") {
                try {
                    for alt in LlmApiPing_KimiChatBodies(mod, q, tok) {
                        ab := String(alt)
                        if (ab != "")
                            bodies.Push(ab)
                    }
                } catch {
                }
            } else if FuncExists("LlmApiPing_BuildChatBody") {
                try bodies.Push(LlmApiPing_BuildChatBody("kimi", mod, q, tok))
                catch {
                }
            }
            for _, body in bodies {
                body := String(body)
                if (body = "")
                    continue
                sig := url . "|" . mod . "|" . SubStr(body, 1, 120)
                if seen.Has(sig)
                    continue
                seen[sig] := true
                plan.Push(Map("url", url, "body", body, "model", mod, "base", bu))
            }
        }
    }
    return Map("error", "", "plan", plan, "planLen", plan.Length, "headers", headers)
}

CommandPalette_RunDirectKimiStreamSync(reqId, q, llm, gen) {
    global g_CmdPal_AiSession
    if !CommandPalette_AiSessionMatches(reqId, false)
        return
    built := CommandPalette_BuildKimiDirectPlan(q, llm)
    if (built.Get("error", "") != "") {
        CommandPalette_PushAiStreamError(reqId, gen, String(built["error"]))
        return
    }
    planLen := built.Has("planLen") ? Integer(built["planLen"]) : 0
    plan := built.Has("plan") ? built["plan"] : []
    if (planLen < 1) {
        try planLen := plan.Length
        catch {
            planLen := 0
        }
    }
    if (planLen < 1) {
        CommandPalette_AiLog("ai_kimi_plan_empty", "keyLen=" . StrLen(String(llm.Get("apiKey", "")))
            . " base=" . SubStr(String(llm.Get("baseUrl", "")), 1, 48) . " model=" . String(llm.Get("model", "")))
        CommandPalette_PushAiStreamError(reqId, gen, "Kimi 请求计划为空，请检查 API Key 与 Base URL")
        return
    }
    g_CmdPal_AiSession["kimiPlan"] := plan
    g_CmdPal_AiSession["kimiPlanIdx"] := 1
    g_CmdPal_AiSession["kimiHeaders"] := built.Get("headers", Map())
    g_CmdPal_AiSession["kimiLastR"] := Map("ok", false, "status", 0, "text", "", "error", "请求失败")
    CommandPalette_PushAiStreamChunk(reqId, gen, "🔄 宿主直连 Kimi…`n")
    CommandPalette_AiLog("ai_kimi_plan", "reqId=" . reqId . " tries=" . plan.Length)
    ; 与 MiniMax 一致：CoreAsyncHttp 已加载时走异步 HttpJsonAsync，避免 FuncExists 误判后误报「HTTP 不可用」
    if CommandPalette_HasDirectHttp() {
        CommandPalette_KimiDirectHttpStep(reqId, gen)
        return
    }
    CommandPalette_KimiDirectHttpSyncAll(reqId, gen)
}

CommandPalette_KimiDirectHttpSyncAll(reqId, gen) {
    global g_CmdPal_AiSession
    if !CommandPalette_AiSessionMatches(reqId, false)
        return
    plan := g_CmdPal_AiSession.Get("kimiPlan", [])
    headers := g_CmdPal_AiSession.Get("kimiHeaders", Map())
    lastR := Map("ok", false, "status", 0, "text", "", "error", "Kimi 请求失败")
    for item in plan {
        if !(item is Map)
            continue
        r := CommandPalette_LlmHttpSync("POST", String(item["url"]), headers, String(item["body"]), 90000)
        lastR := r
        if (r is Map) && r.Get("ok", false) {
            CommandPalette_OnDirectLlmDone(reqId, gen, "kimi", r)
            return
        }
        st := (r is Map) ? Integer(r.Get("status", 0)) : 0
        CommandPalette_AiLog("ai_kimi_sync_try", "status=" . st . " base=" . SubStr(String(item.Get("base", "")), 1, 40))
        if (st = 403)
            break
    }
    CommandPalette_OnDirectLlmDone(reqId, gen, "kimi", lastR)
}

CommandPalette_KimiDirectHttpStep(reqId, gen) {
    global g_CmdPal_AiSession
    if !CommandPalette_AiSessionMatches(reqId, false)
        return
    plan := g_CmdPal_AiSession.Get("kimiPlan", [])
    idx := Integer(g_CmdPal_AiSession.Get("kimiPlanIdx", 1))
    if !(plan is Array) || idx > plan.Length {
        CommandPalette_OnDirectLlmDone(reqId, gen, "kimi", g_CmdPal_AiSession.Get("kimiLastR", Map("ok", false, "error", "请求失败")))
        return
    }
    item := plan[idx]
    g_CmdPal_AiSession["kimiPlanIdx"] := idx + 1
    headers := g_CmdPal_AiSession.Get("kimiHeaders", Map())
    url := String(item["url"])
    body := String(item["body"])
    if !RegExMatch(url, "i)^https?://") {
        g_CmdPal_AiSession["kimiLastR"] := Map("ok", false, "status", 0, "text", "", "error", "Kimi URL 无效: " . SubStr(url, 1, 80))
        CommandPalette_KimiDirectHttpStep(reqId, gen)
        return
    }
    opts := Map(
        "headers", headers,
        "timeoutMs", 90000,
        "receiveTimeoutMs", 90000,
        "tag", "cmdpal_ai_kimi",
        "reqId", reqId
    )
    if CommandPalette_PostHttpJsonAsync("POST", url, body, CommandPalette_OnKimiDirectHttp.Bind(reqId, gen), opts)
        return
    r := CommandPalette_LlmHttpSync("POST", url, headers, body, 90000)
    if (r is Map) && r.Get("ok", false) {
        CommandPalette_OnDirectLlmDone(reqId, gen, "kimi", r)
        return
    }
    g_CmdPal_AiSession["kimiLastR"] := r
    CommandPalette_KimiDirectHttpStep(reqId, gen)
}

CommandPalette_OnKimiDirectHttp(reqId, gen, ret) {
    global g_CmdPal_AiSession
    if !CommandPalette_AiSessionMatches(reqId, false)
        return
    if (ret is Map) && ret.Get("ok", false) {
        CommandPalette_AiLog("ai_kimi_ok", "reqId=" . reqId . " status=" . Integer(ret.Get("status", 0)))
        CommandPalette_OnDirectLlmDone(reqId, gen, "kimi", ret)
        return
    }
    if (ret is Map)
        g_CmdPal_AiSession["kimiLastR"] := ret
    st := (ret is Map) ? Integer(ret.Get("status", 0)) : 0
    det := "status=" . st
    if (g_CmdPal_AiSession is Map) {
        pi := Integer(g_CmdPal_AiSession.Get("kimiPlanIdx", 1)) - 1
        pl := g_CmdPal_AiSession.Get("kimiPlan", [])
        if (pl is Array) && pi >= 1 && pi <= pl.Length {
            item := pl[pi]
            if (item is Map)
                det .= " base=" . SubStr(String(item.Get("base", "")), 1, 48)
        }
    }
    CommandPalette_AiLog("ai_kimi_try_fail", "reqId=" . reqId . " " . det . " err=" . SubStr((ret is Map) ? String(ret.Get("error", "")) : "", 1, 80))
    CommandPalette_KimiDirectHttpStep(reqId, gen)
}

CommandPalette_ArrayHasValue(arr, val) {
    for item in arr
        if (item = val)
            return true
    return false
}

CommandPalette_OnDirectLlmDone(reqId, gen, kind, ret) {
    global g_CmdPal_AiSession
    if !CommandPalette_AiSessionMatches(reqId, false)
        return
    ok := false
    status := 0
    text := ""
    err := ""
    if (ret is Map) {
        ok := !!ret.Get("ok", false)
        status := Integer(ret.Get("status", 0))
        text := String(ret.Get("text", ""))
        err := String(ret.Get("error", ""))
    } else
        err := "无效响应"
    if !ok {
        errLow := StrLower(err)
        if (errLow = "cancelled" || errLow = "canceled")
            return
        err := CommandPalette_FormatAiHttpError(status, err, text, kind)
        if (CommandPalette_NormalizeAiProvider(kind) = "kimi") && (status = 404 || status = 400)
            && CommandPalette_AiSessionMatches(reqId, false) && (g_CmdPal_AiSession is Map)
            && !g_CmdPal_AiSession.Get("kimiV1Retried", false) {
            llmFb := CommandPalette_ResolveAiLlmForProvider("kimi")
            mod0 := Trim(String(llmFb.Get("model", "")))
            if RegExMatch(mod0, "i)^kimi-k2") {
                g_CmdPal_AiSession["kimiV1Retried"] := true
                llmFb["model"] := "moonshot-v1-8k"
                CommandPalette_PushAiStreamChunk(reqId, gen, "`n⟳ 改用 moonshot-v1-8k 重试…`n")
                SetTimer(CommandPalette_RunDirectKimiStreamSync.Bind(reqId, String(g_CmdPal_AiSession.Get("query", "")), llmFb, gen), -1)
                return
            }
        }
        CommandPalette_PushAiStreamError(reqId, gen, err)
        return
    }
    ans := CommandPalette_ExtractLlmAnswer(text, kind)
    if (ans = "") {
        CommandPalette_PushAiStreamError(reqId, gen, "模型返回空内容")
        return
    }
    chunkSize := 24
    pos := 1
    len := StrLen(ans)
    while (pos <= len) {
        part := SubStr(ans, pos, chunkSize)
        pos += chunkSize
        CommandPalette_PushAiStreamChunk(reqId, gen, part)
    }
    CommandPalette_PushAiStreamEnd(reqId, gen, ans)
}

CommandPalette_ExtractLlmAnswer(raw, kind := "") {
    raw := Trim(String(raw))
    if (raw = "")
        return ""
    try {
        parsed := Jxon_Load(raw)
        if (parsed is Map) {
            if parsed.Has("content") && parsed["content"] is Array {
                for item in parsed["content"] {
                    if (item is Map) {
                        t := Trim(String(item.Get("text", "")))
                        if (t != "")
                            return t
                    }
                }
            }
            if parsed.Has("choices") && parsed["choices"] is Array && parsed["choices"].Length > 0 {
                ch := parsed["choices"][1]
                if (ch is Map) {
                    if ch.Has("message") && ch["message"] is Map
                        return Trim(String(ch["message"].Get("content", "")))
                    if ch.Has("text")
                        return Trim(String(ch["text"]))
                }
            }
        }
    } catch {
    }
    return raw
}

CommandPalette_PostFtbPaletteAiStreamInner(reqId, q, prov, isRetry := false) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return false
    ok := false
    payload := Map(
        "type", "host_palette_ai_stream",
        "reqId", String(reqId),
        "query", String(q),
        "provider", String(prov),
        "openDrawer", false
    )
    try {
        ok := CommandPalette_DeliverFtbPayload(payload)
        if !isRetry
            CommandPalette_AiLog("ai_stream_posted_ftb", "reqId=" . reqId . " provider=" . prov . " ok=" . (ok ? 1 : 0))
    } catch as ePost {
        CommandPalette_AiLog("ai_stream_post_err", ePost.Message)
    }
    try CommandPalette_InvokeFtbPaletteAiScript(reqId, q, prov)
    catch {
    }
    return ok
}

CommandPalette_ArmAiStreamWatchdog(reqId, gen) {
    global g_CmdPal_AiWatchdogToken
    g_CmdPal_AiWatchdogToken := A_TickCount
    token := g_CmdPal_AiWatchdogToken
    SetTimer(CommandPalette_AiStreamWatchdog.Bind(reqId, gen, token), -120000)
}

CommandPalette_AiStreamWatchdog(reqId, gen, token) {
    global g_CmdPal_AiSession, g_CmdPal_AiWatchdogToken
    if (token != g_CmdPal_AiWatchdogToken)
        return
    if !CommandPalette_AiSessionMatches(reqId, false)
        return
    if (g_CmdPal_AiSession is Map) && g_CmdPal_AiSession.Get("ended", false)
        return
    if (g_CmdPal_AiSession is Map) && g_CmdPal_AiSession.Get("ftbDispatched", false) {
        if CommandPalette_PollFtbPaletteLastResult(reqId, gen)
            return
        CommandPalette_RequestFtbAnswerSync(reqId)
        SetTimer(CommandPalette_AiStreamWatchdogFinalize.Bind(reqId, gen, token), -4000)
        return
    }
    CommandPalette_PushAiStreamError(reqId, gen, "请求超时（120s），请检查 API 或网络")
}

CommandPalette_AiStreamWatchdogFinalize(reqId, gen, token) {
    global g_CmdPal_AiSession, g_CmdPal_AiWatchdogToken
    if (token != g_CmdPal_AiWatchdogToken)
        return
    if !CommandPalette_AiSessionMatches(reqId, false)
        return
    if (g_CmdPal_AiSession is Map) && g_CmdPal_AiSession.Get("ended", false)
        return
    CommandPalette_TrySyncAnswerFromFtb(reqId, gen, g_CmdPal_AiPollToken)
    if (g_CmdPal_AiSession is Map) && g_CmdPal_AiSession.Get("ended", false)
        return
    if CommandPalette_PollFtbPaletteLastResult(reqId, gen)
        return
    if CommandPalette_HasSubstantivePaletteAnswer() {
        ans := Trim(String(g_CmdPal_AiSession.Get("answer", "")))
        CommandPalette_PushAiStreamEnd(reqId, gen, ans)
        return
    }
    if CommandPalette_IsPaletteAiReq(reqId) && (g_CmdPal_AiSession is Map) && !g_CmdPal_AiSession.Get("directStarted", false) {
        q := String(g_CmdPal_AiSession.Get("query", ""))
        prov := String(g_CmdPal_AiSession.Get("provider", ""))
        g_CmdPal_AiSession["directStarted"] := true
        CommandPalette_AiLog("ai_watchdog_direct", "reqId=" . reqId)
        CommandPalette_RunDirectAiStream(reqId, q, prov, gen)
        return
    }
    CommandPalette_PushAiStreamError(reqId, gen, "未能获取模型回复：请检查 API Key，或 Tab 在 Niuma Chat 中查看")
}

CommandPalette_CollapsePaletteAfterAi() {
    global g_CmdPal_MinHeight
    CommandPalette_PushToWeb(Map("type", "palette_ai_reset"))
    CommandPalette_ApplyMorphHeight(g_CmdPal_MinHeight, true)
}

; 命令面板 AI：悬浮栏可选投递一次，600ms 后宿主直连（单次 HTTP，避免 429）
CommandPalette_PostFtbPaletteAiStream(reqId, q, prov) {
    global g_CmdPal_AiSession
    gen := (g_CmdPal_AiSession is Map) ? Integer(g_CmdPal_AiSession.Get("gen", 0)) : 0
    try CommandPalette_PostFtbPaletteAiStreamInner(reqId, q, prov, false)
    catch {
    }
    CommandPalette_AiLog("ai_stream_posted", "reqId=" . reqId . " provider=" . prov)
    if (g_CmdPal_AiSession is Map) {
        g_CmdPal_AiSession["webChunkCount"] := 0
        g_CmdPal_AiSession["webAnswerChunks"] := 0
        g_CmdPal_AiSession["ftbDispatched"] := true
        g_CmdPal_AiSession["directStarted"] := false
        g_CmdPal_AiSession["error"] := ""
    }
    CommandPalette_ArmAiStreamWatchdog(reqId, gen)
    CommandPalette_ArmFtbAnswerPoll(reqId, gen)
    CommandPalette_ArmAiDirectOnce(reqId, q, prov, gen)
    pollTok := g_CmdPal_AiPollToken
    SetTimer(CommandPalette_TrySyncAnswerFromFtb.Bind(reqId, gen, pollTok), -400)
    return true
}

CommandPalette_DispatchPaletteAiStream(reqId, q, prov, gen, tryN := 0) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_UI_Ready, g_CmdPal_AiStreamGen, g_CmdPal_AiSession
    if !(g_CmdPal_AiSession is Map) || Trim(String(g_CmdPal_AiSession.Get("reqId", ""))) != Trim(String(reqId))
        return
    if Integer(g_CmdPal_AiSession.Get("gen", 0)) != Integer(gen)
        return
    tryN := Integer(tryN)
    if (IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady && g_FTB_UI_Ready) {
        CommandPalette_PostFtbPaletteAiStream(reqId, q, prov)
        return
    }
    if (tryN >= 40) {
        CommandPalette_AiLog("ai_stream_wv2_timeout", "reqId=" . reqId . " ready=" . (g_FTB_WV2_Ready ? 1 : 0) . " frame=" . (g_FTB_WV2_FrameReady ? 1 : 0) . " ui=" . (g_FTB_UI_Ready ? 1 : 0))
        if (g_CmdPal_AiSession is Map)
            g_CmdPal_AiSession["directStarted"] := true
        CommandPalette_RunDirectAiStream(reqId, q, prov, gen)
        return
    }
    CommandPalette_EnsureFtbEngineForAi()
    SetTimer(CommandPalette_DispatchPaletteAiStream.Bind(reqId, q, prov, gen, tryN + 1), -380)
}

CommandPalette_PushAiStreamChunk(reqId, gen, delta) {
    global g_CmdPal_AiSession, g_CmdPal_AiWatchdogToken
    if !CommandPalette_AiSessionMatches(reqId, false)
        return
    g_CmdPal_AiWatchdogToken := A_TickCount
    CommandPalette_ArmAiStreamWatchdog(reqId, gen)
    d := String(delta)
    if (d = "")
        return
    acc := String(g_CmdPal_AiSession.Get("answer", "")) . d
    g_CmdPal_AiSession["answer"] := acc
    g_CmdPal_AiSession["error"] := ""
    if !CommandPalette_ShouldMirrorAiToPalette()
        return
    g_CmdPal_AiSession["chunkCount"] := Integer(g_CmdPal_AiSession.Get("chunkCount", 0)) + 1
    cc := Integer(g_CmdPal_AiSession.Get("chunkCount", 0))
    if (Mod(cc, 12) = 1)
        CommandPalette_AiLog("ai_chunk", "reqId=" . reqId . " len=" . StrLen(acc))
    CommandPalette_PushToWeb(Map("type", "palette_ai_chunk", "reqId", reqId, "delta", d))
}

CommandPalette_PushAiStreamEnd(reqId, gen, answer := "") {
    global g_CmdPal_AiSession, g_CmdPal_AiWatchdogToken
    if !CommandPalette_AiSessionMatches(reqId, false)
        return
    g_CmdPal_AiWatchdogToken := A_TickCount
    if (Trim(String(answer)) != "")
        g_CmdPal_AiSession["answer"] := String(answer)
    g_CmdPal_AiSession["ended"] := true
    g_CmdPal_AiSession["error"] := ""
    ans := String(g_CmdPal_AiSession.Get("answer", ""))
    CommandPalette_StopFtbAnswerPoll()
    CommandPalette_AiLog("ai_end", "reqId=" . reqId . " len=" . StrLen(ans))
    global g_CmdPal_AiLastCard
    g_CmdPal_AiLastCard := Map(
        "reqId", reqId,
        "query", String(g_CmdPal_AiSession.Get("query", "")),
        "provider", String(g_CmdPal_AiSession.Get("provider", "")),
        "answer", ans,
        "ended", true,
        "handoff", !!g_CmdPal_AiSession.Get("handoff", false),
        "error", ""
    )
    if CommandPalette_ShouldMirrorAiToPalette()
        CommandPalette_PushToWeb(Map("type", "palette_ai_end", "reqId", reqId, "answer", ans))
    if g_CmdPal_AiSession.Get("handoff", false) && IsObject(g_FTB_WV2) {
        try WebView_QueuePayload(g_FTB_WV2, Map("type", "host_palette_ai_handoff_end", "reqId", reqId))
        catch {
        }
    }
}

CommandPalette_PushAiStreamError(reqId, gen, message) {
    global g_CmdPal_AiSession
    if !CommandPalette_AiSessionMatches(reqId, false)
        return
    g_CmdPal_AiSession["ended"] := true
    g_CmdPal_AiSession["error"] := String(message)
    global g_CmdPal_AiLastCard
    g_CmdPal_AiLastCard := Map(
        "reqId", reqId,
        "query", String(g_CmdPal_AiSession.Get("query", "")),
        "provider", String(g_CmdPal_AiSession.Get("provider", "")),
        "answer", String(g_CmdPal_AiSession.Get("answer", "")),
        "ended", true,
        "handoff", false,
        "error", String(message)
    )
    CommandPalette_AiLog("ai_error", "reqId=" . reqId . " msg=" . String(message))
    if CommandPalette_ShouldMirrorAiToPalette()
        CommandPalette_PushToWeb(Map("type", "palette_ai_error", "reqId", reqId, "message", String(message)))
}

CommandPalette_OnNiumaPaletteAiChunk(msg) {
    global g_CmdPal_AiSession, g_CmdPal_AiRetryToken
    if !(msg is Map)
        return
    if FuncExists("CommandPalette_AgentForwardAiEvent")
        try CommandPalette_AgentForwardAiEvent("chunk", msg)
        catch {
        }
    if FuncExists("CommandPalette_AgentDebug_TraceIfAgentReq") {
        reqId0 := msg.Has("reqId") ? String(msg["reqId"]) : ""
        delta0 := msg.Has("delta") ? String(msg["delta"]) : ""
        CommandPalette_AgentDebug_TraceIfAgentReq(reqId0, "ftb", "ai_chunk", "len=" . StrLen(delta0) . " head=" . SubStr(delta0, 1, 40))
    }
    reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
    gen := msg.Has("gen") ? Integer(msg["gen"]) : Integer(g_CmdPal_AiSession is Map ? g_CmdPal_AiSession.Get("gen", 0) : 0)
    delta := msg.Has("delta") ? String(msg["delta"]) : (msg.Has("text") ? String(msg["text"]) : "")
    if (g_CmdPal_AiSession is Map) && Trim(String(g_CmdPal_AiSession.Get("reqId", ""))) = Trim(String(reqId)) {
        g_CmdPal_AiSession["webChunkCount"] := Integer(g_CmdPal_AiSession.Get("webChunkCount", 0)) + 1
        if (delta != "" && !RegExMatch(delta, "s)^[\s⏳💭🔄宿主直连]+"))
            g_CmdPal_AiSession["webAnswerChunks"] := Integer(g_CmdPal_AiSession.Get("webAnswerChunks", 0)) + 1
    }
    g_CmdPal_AiRetryToken := A_TickCount
    CommandPalette_PushAiStreamChunk(reqId, gen, delta)
}

CommandPalette_OnNiumaPaletteAiEnd(msg) {
    global g_CmdPal_AiSession
    if !(msg is Map)
        return
    if FuncExists("CommandPalette_AgentForwardAiEvent")
        try CommandPalette_AgentForwardAiEvent("end", msg)
        catch {
        }
    if FuncExists("CommandPalette_AgentDebug_TraceIfAgentReq") {
        reqId0 := msg.Has("reqId") ? String(msg["reqId"]) : ""
        ans0 := msg.Has("answer") ? String(msg["answer"]) : ""
        CommandPalette_AgentDebug_TraceIfAgentReq(reqId0, "ftb", "ai_end", "len=" . StrLen(ans0))
    }
    reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
    if !CommandPalette_AiSessionMatches(reqId, false)
        return
    gen := (g_CmdPal_AiSession is Map) ? Integer(g_CmdPal_AiSession.Get("gen", 0)) : 0
    ans := msg.Has("answer") ? String(msg["answer"]) : ""
    if (ans = "") && (g_CmdPal_AiSession is Map)
        ans := String(g_CmdPal_AiSession.Get("answer", ""))
    q := (g_CmdPal_AiSession is Map) ? Trim(String(g_CmdPal_AiSession.Get("query", ""))) : ""
    webChunks := (g_CmdPal_AiSession is Map) ? Integer(g_CmdPal_AiSession.Get("webAnswerChunks", 0)) : 0
    if (q != "" && Trim(ans) = q && webChunks < 1)
        return
    CommandPalette_AiLog("ai_web_end", "reqId=" . reqId . " ansLen=" . StrLen(ans))
    CommandPalette_StopFtbAnswerPoll()
    g_CmdPal_AiWatchdogToken := A_TickCount
    if (g_CmdPal_AiSession is Map) {
        g_CmdPal_AiSession["error"] := ""
        g_CmdPal_AiSession["ended"] := false
    }
    if (Trim(ans) != "") && !CommandPalette_HasSubstantivePaletteAnswer()
        CommandPalette_PushAiStreamChunk(reqId, gen, ans)
    CommandPalette_PushAiStreamEnd(reqId, gen, ans)
}

CommandPalette_OnNiumaPaletteAiError(msg) {
    if !(msg is Map)
        return
    if FuncExists("CommandPalette_AgentForwardAiEvent")
        try CommandPalette_AgentForwardAiEvent("error", msg)
        catch {
        }
    if FuncExists("CommandPalette_AgentDebug_TraceIfAgentReq") {
        reqId0 := msg.Has("reqId") ? String(msg["reqId"]) : ""
        err0 := msg.Has("message") ? String(msg["message"]) : ""
        CommandPalette_AgentDebug_TraceIfAgentReq(reqId0, "ftb", "ai_error", err0, "err")
    }
    reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
    gen := msg.Has("gen") ? Integer(msg["gen"]) : 0
    err := msg.Has("message") ? String(msg["message"]) : (msg.Has("error") ? String(msg["error"]) : "未知错误")
    CommandPalette_StopFtbAnswerPoll()
    CommandPalette_PushAiStreamError(reqId, gen, err)
}

CommandPalette_CancelAiStream() {
    global g_CmdPal_AiSession, g_CmdPal_AiStreamGen, g_FTB_WV2
    oldReqId := (g_CmdPal_AiSession is Map) ? String(g_CmdPal_AiSession.Get("reqId", "")) : ""
    g_CmdPal_AiStreamGen++
    CommandPalette_StopAiStreamSideEffects(oldReqId)
    g_CmdPal_AiSession := 0
}

CommandPalette_HandoffAiToToolbar(fromHide := false) {
    global g_CmdPal_AiSession, g_CmdPal_AiStreamGen, g_FTB_WV2
    if !(g_CmdPal_AiSession is Map)
        return
    if g_CmdPal_AiSession.Get("handoff", false)
        return
    g_CmdPal_AiSession["handoff"] := true
    g_CmdPal_AiStreamGen++
    reqId := String(g_CmdPal_AiSession.Get("reqId", ""))
    CommandPalette_AiLog("ai_handoff", "reqId=" . reqId . " fromHide=" . (fromHide ? 1 : 0))
    if fromHide
        CommandPalette_PushToWeb(Map("type", "palette_ai_status", "message", "后台继续生成 · 再次打开面板可查看", "status", "loading"))
    else
        CommandPalette_PushToWeb(Map("type", "palette_ai_status", "message", "已在后台继续生成（看悬浮栏图标）", "status", "idle"))
    if !fromHide
        CommandPalette_CollapsePaletteAfterAi()
    if IsObject(g_FTB_WV2) {
        try WebView_QueuePayload(g_FTB_WV2, Map("type", "host_palette_ai_handoff", "reqId", reqId, "showHud", true))
        catch {
        }
    }
}

CommandPalette_PromoteAiToNiumaChat(msg := 0) {
    global g_CmdPal_AiSession
    q := ""
    prov := ""
    ans := ""
    if (msg is Map) {
        q := Trim(String(msg.Get("query", "")))
        prov := CommandPalette_NormalizeAiProvider(msg.Get("provider", ""))
        ans := String(msg.Get("answer", ""))
    }
    if (g_CmdPal_AiSession is Map) {
        if (q = "")
            q := Trim(String(g_CmdPal_AiSession.Get("query", "")))
        if (prov = "")
            prov := CommandPalette_NormalizeAiProvider(g_CmdPal_AiSession.Get("provider", ""))
        if (ans = "")
            ans := String(g_CmdPal_AiSession.Get("answer", ""))
    }
    CommandPalette_AiLog("ai_promote", "provider=" . prov . " qLen=" . StrLen(q))
    CommandPalette_Hide()
    CommandPalette_BootstrapNiumaChat("ai_promote", true)
    if FuncExists("FloatingToolbar_OpenNiumaChatAsk") {
        try FloatingToolbar_OpenNiumaChatAsk(q, false)
        catch {
        }
    }
    if (q != "" && FuncExists("FloatingToolbar_SendTextToNiumaChat")) {
        try {
            if (prov != "")
                FloatingToolbar_SendTextToNiumaChat(q, false, false, true, prov)
            else
                FloatingToolbar_SendTextToNiumaChat(q, false, false, true)
        } catch {
        }
    }
    if (ans != "" && FuncExists("FloatingToolbar_SendTextToNiumaChat") && ans != q) {
        ; 已有部分回答时仅打开抽屉展示会话，不重复发送用户问题
    }
    g_CmdPal_AiSession := 0
}

CommandPalette_InjectPalettePayload(payload) {
    global g_CmdPal_WV2
    if !IsObject(g_CmdPal_WV2)
        return false
    if !(payload is Map)
        return false
    jsonStr := ""
    try jsonStr := Jxon_Dump(payload)
    catch {
        return false
    }
    if (jsonStr = "")
        return false
    escaped := CommandPalette_JsEscapeForParse(jsonStr)
    js := "try{if(window.__nmerPaletteHostInject)window.__nmerPaletteHostInject('" . escaped . "');"
        . "}catch(e){}"
    try {
        g_CmdPal_WV2.ExecuteScriptAsync(js)
        return true
    } catch as eInj {
        if FuncExists("CommandPalette_AgentDebugTrace")
            try CommandPalette_AgentDebugTrace("push", "inject_fail", eInj.Message, "err")
            catch {
            }
        return false
    }
}

CommandPalette_PushToWeb(payload) {
    global g_CmdPal_WV2
    if !IsObject(g_CmdPal_WV2)
        return false
    ok := false
    try {
        if FuncExists("WebView_QueuePayload")
            ok := !!WebView_QueuePayload(g_CmdPal_WV2, payload)
        if !ok {
            json := Jxon_Dump(payload)
            g_CmdPal_WV2.PostWebMessageAsJson(json)
            ok := true
        }
    } catch {
        ok := false
    }
    if FuncExists("CommandPalette_InjectPalettePayload")
        try CommandPalette_InjectPalettePayload(payload)
        catch {
        }
    if FuncExists("CommandPalette_AgentDebug_TracePalettePush")
        try CommandPalette_AgentDebug_TracePalettePush(payload)
        catch {
        }
    return ok
}

CommandPalette_ExecScript(js) {
    global g_CmdPal_WV2
    if !IsObject(g_CmdPal_WV2)
        return false
    try {
        g_CmdPal_WV2.ExecuteScriptAsync(js)
        return true
    } catch {
        return false
    }
}

CommandPalette_SetInputText(text) {
    CommandPalette_PushToWeb(Map("type", "palette_set_input", "text", String(text)))
}

CommandPalette_PushStatus(message, status := "idle") {
    CommandPalette_PushToWeb(Map("type", "palette_status", "message", String(message), "status", String(status)))
}

CommandPalette_PushResults(items, seq := 0) {
    payload := Map("type", "palette_results", "items", items)
    if (Integer(seq) > 0)
        payload["seq"] := Integer(seq)
    CommandPalette_PushToWeb(payload)
}

CommandPalette_ParseWebMessage(args) {
    if FuncExists("FloatingToolbar_ParseWebMessage")
        return FloatingToolbar_ParseWebMessage(args)
    try {
        raw := args.TryGetWebMessageAsString()
        if (raw != "") {
            m := Jxon_Load(raw)
            if (m is Map)
                return m
        }
    } catch {
    }
    try {
        m := Jxon_Load(args.WebMessageAsJson)
        if (m is String)
            m := Jxon_Load(m)
        if (m is Map)
            return m
    } catch {
    }
    return 0
}

CommandPalette_OnWebMessage(sender, args) {
    msg := CommandPalette_ParseWebMessage(args)
    if !(msg is Map)
        return
    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ = "palette_ready") {
        CommandPalette_PushThemeToWeb()
        SetTimer(CommandPalette_PushAiProviders, -40)
        if FuncExists("CommandPalette_AgentOnReady")
            SetTimer(CommandPalette_AgentOnReady, -60)
        SetTimer(CommandPalette_Reveal, -1)
        SetTimer(CommandPalette_DeferredFocus, -80)
        SetTimer(CommandPalette_SyncHostShape, -1)
        return
    }
    if (typ = "palette_oc5_probe_result") {
        global g_CmdPal_Oc5ProbeResolver
        if !(g_CmdPal_Oc5ProbeResolver is Map)
            return
        wantReq := String(g_CmdPal_Oc5ProbeResolver.Get("reqId", ""))
        gotReq := msg.Has("reqId") ? String(msg["reqId"]) : ""
        if (wantReq != "" && gotReq != "" && wantReq != gotReq)
            return
        resolver := g_CmdPal_Oc5ProbeResolver.Get("resolve", 0)
        g_CmdPal_Oc5ProbeResolver := 0
        if resolver
            try resolver.Call(msg)
            catch {
            }
        return
    }
    if (typ = "palette_gray_probe_result") {
        global g_CmdPal_GrayProbeResolver
        if !(g_CmdPal_GrayProbeResolver is Map)
            return
        wantReq := String(g_CmdPal_GrayProbeResolver.Get("reqId", ""))
        gotReq := msg.Has("reqId") ? String(msg["reqId"]) : ""
        if (wantReq != "" && gotReq != "" && wantReq != gotReq)
            return
        resolver := g_CmdPal_GrayProbeResolver.Get("resolve", 0)
        g_CmdPal_GrayProbeResolver := 0
        if resolver
            try resolver.Call(msg)
            catch {
            }
        return
    }
    if (typ = "palette_adp_probe_result") {
        global g_CmdPal_AdpProbeResolver
        if !(g_CmdPal_AdpProbeResolver is Map)
            return
        wantReq := String(g_CmdPal_AdpProbeResolver.Get("reqId", ""))
        gotReq := msg.Has("reqId") ? String(msg["reqId"]) : ""
        if (wantReq != "" && gotReq != "" && wantReq != gotReq)
            return
        resolver := g_CmdPal_AdpProbeResolver.Get("resolve", 0)
        g_CmdPal_AdpProbeResolver := 0
        if resolver
            try resolver.Call(msg)
            catch {
            }
        return
    }
    if (typ = "palette_resize") {
        h := msg.Has("height") ? Integer(msg["height"]) : 76
        expanded := false
        if (msg.Has("expanded"))
            expanded := !!msg["expanded"]
        actionWorkspace := msg.Has("workspace") ? !!msg["workspace"] : false
        if (!actionWorkspace && msg.Has("intent"))
            actionWorkspace := (String(msg["intent"]) = "action")
        CommandPalette_ApplyHeight(h, expanded, actionWorkspace)
        return
    }
    if (typ = "palette_morph_resize") {
        h := msg.Has("height") ? Integer(msg["height"]) : g_CmdPal_AiMorphHeight
        CommandPalette_ApplyMorphHeight(h, true)
        return
    }
    if (typ = "palette_ai_handoff") {
        CommandPalette_HandoffAiToToolbar(false)
        return
    }
    if (typ = "palette_ai_promote") {
        CommandPalette_PromoteAiToNiumaChat(msg)
        return
    }
    if (typ = "palette_ai_cancel") {
        CommandPalette_CancelAiStream()
        return
    }
    if (typ = "palette_hide") {
        CommandPalette_Hide()
        return
    }
    if (typ = "palette_query") {
        q := msg.Has("input") ? String(msg["input"]) : ""
        seq := msg.Has("seq") ? Integer(msg["seq"]) : 0
        CommandPalette_HandleQuery(q, seq)
        return
    }
    if (typ = "palette_execute") {
        CommandPalette_HandleExecute(msg)
        return
    }
    if (typ = "palette_voice_toggle") {
        CommandPalette_HandleVoiceToggle()
        return
    }
    if (typ = "palette_turbo_search") {
        q := msg.Has("query") ? Trim(String(msg["query"])) : ""
        lim := msg.Has("limit") ? Integer(msg["limit"]) : 20
        seq := msg.Has("seq") ? Integer(msg["seq"]) : 0
        if (lim <= 0)
            lim := 20
        if (lim > 20)
            lim := 20
        CommandPalette_HandleTurboSearch(q, lim, seq)
        return
    }
    if (typ = "palette_turbo_execute") {
        CommandPalette_HandleTurboExecute(msg)
        return
    }
    if (typ = "palette_ai_stub") {
        q := msg.Has("query") ? Trim(String(msg["query"])) : ""
        CommandPalette_HandleAiStub(q)
        return
    }
    if (typ = "palette_ai_refresh") {
        CommandPalette_RefreshAiProviders()
        return
    }
    if (typ = "palette_ai_send") {
        q := msg.Has("query") ? Trim(String(msg["query"])) : ""
        prov := msg.Has("provider") ? Trim(String(msg["provider"])) : ""
        CommandPalette_HandleAiSend(q, prov)
        return
    }
    if (typ = "palette_ai_dismiss") {
        CommandPalette_DismissAiCard()
        return
    }
    if (typ = "palette_search_debug") {
        tab := msg.Has("tab") ? Trim(String(msg["tab"])) : "search"
        if FuncExists("CommandPalette_ShowSearchDebug")
            CommandPalette_ShowSearchDebug(true, tab)
        else
            CommandPalette_HandleSearchDebug()
        return
    }
    if (typ = "palette_surface_dispose") {
        if FuncExists("SurfaceDisposeProbe_HandleWebMessage")
            SurfaceDisposeProbe_HandleWebMessage(msg)
        if FuncExists("CommandPalette_SetInputText")
            try CommandPalette_SetInputText("")
        return
    }
    if (typ = "palette_agent_debug") {
        CommandPalette_HandleAgentDebug()
        return
    }
    if (typ = "palette_agent_debug_log") {
        if FuncExists("CommandPalette_AgentWireLog")
            try CommandPalette_AgentWireLog("wm_debug_log", msg.Has("event") ? String(msg["event"]) : "log")
            catch {
            }
        try {
            lay := msg.Has("layer") ? String(msg["layer"]) : "palette"
            evt := msg.Has("event") ? String(msg["event"]) : "log"
            det := msg.Has("detail") ? String(msg["detail"]) : ""
            lvl := msg.Has("level") ? String(msg["level"]) : "info"
            CommandPalette_AgentDebugTrace(lay, evt, det, lvl)
        } catch as eDbg {
            if FuncExists("CommandPalette_AgentWireLog")
                try CommandPalette_AgentWireLog("wm_debug_err", eDbg.Message)
                catch {
                }
        }
        return
    }
    if (typ = "cp_pipeline_debug") {
        global g_AgentDbg_PipelineState
        if msg.Has("state") && msg["state"] is Map
            g_AgentDbg_PipelineState := msg["state"]
        if FuncExists("CommandPaletteSearchDebug_PushPayload") {
            try CommandPaletteSearchDebug_PushPayload(Map("type", "cp_pipeline_debug", "state", g_AgentDbg_PipelineState))
            catch {
            }
        }
        return
    }
    if (typ = "palette_agent_submit") {
        if FuncExists("CommandPalette_AgentWireLog")
            try CommandPalette_AgentWireLog("wm_submit", SubStr(String(msg.Has("text") ? msg["text"] : ""), 1, 80))
            catch {
            }
        try CommandPalette_HandleAgentSubmit(msg)
        catch as eSub {
            if FuncExists("CommandPalette_AgentWireLog")
                try CommandPalette_AgentWireLog("wm_submit_err", eSub.Message)
                catch {
                }
        }
        return
    }
    if (typ = "palette_agent_cancel") {
        if FuncExists("CommandPalette_HandleAgentCancel")
            CommandPalette_HandleAgentCancel(msg)
        return
    }
    if (typ = "palette_agent_dismiss") {
        if FuncExists("CommandPalette_HandleAgentDismiss")
            CommandPalette_HandleAgentDismiss(msg)
        return
    }
    if (typ = "palette_agent_pull") {
        if FuncExists("CommandPalette_AgentOnReady")
            CommandPalette_AgentOnReady()
        return
    }
    if (typ = "palette_agent_recover") {
        if FuncExists("CommandPalette_AgentRecoverCardAnswer")
            CommandPalette_AgentRecoverCardAnswer(msg)
        return
    }
    if (typ = "palette_agent_prepare_new") {
        if FuncExists("CommandPalette_DeliverFtbPayload")
            try CommandPalette_DeliverFtbPayload(msg)
            catch {
            }
        return
    }
    if (typ = "palette_agent_block_store") {
        if FuncExists("CommandPalette_AgentSaveBlockStore")
            CommandPalette_AgentSaveBlockStore(msg)
        return
    }
    if (typ = "palette_agent_physical") {
        if FuncExists("CommandPalette_HandleAgentPhysical")
            CommandPalette_HandleAgentPhysical(msg)
        return
    }
}

CommandPalette_BuildPageUrl(htmlFile) {
    url := BuildAppLocalUrl(htmlFile)
    try {
        path := FuncExists("HtmlPanelPath") ? HtmlPanelPath(htmlFile) : (A_ScriptDir . "\html\" . htmlFile)
        ver := String(FileGetTime(path, "M"))
        url .= (InStr(url, "?") ? "&" : "?") . "v=" . ver
    } catch {
    }
    return url
}

CommandPalette_EnsureCommandsLoaded() {
    if FuncExists("VK_EnsureInit")
        VK_EnsureInit(true)
    else if FuncExists("_LoadCommands")
        _LoadCommands()
}

CommandPalette_ScoreCommand(name, keywords, q) {
    if (q = "")
        return 1
    label := StrLower(String(name))
    q := String(q)
    if (SubStr(label, 1, StrLen(q)) = q)
        return 120
    if InStr(label, q)
        return 90
    score := 0
    for kw in keywords {
        kl := StrLower(String(kw))
        if (SubStr(kl, 1, StrLen(q)) = q) {
            if (score < 80)
                score := 80
            continue
        }
        if InStr(kl, q) && score < 60
            score := 60
    }
    if (score = 0) {
        for part in StrSplit(q, A_Space) {
            p := Trim(String(part))
            if (p != "" && InStr(label, p))
                score += 20
        }
    }
    return Integer(score)
}

CommandPalette_GetBindingLabel(cmdId) {
    global g_InverseBindings, g_Bindings
    if IsSet(g_InverseBindings) && g_InverseBindings is Map && g_InverseBindings.Has(cmdId)
        return String(g_InverseBindings[cmdId])
    if IsSet(g_Bindings) && g_Bindings is Map && g_Bindings.Has(cmdId) {
        b := String(g_Bindings[cmdId])
        if (b != "" && b != "NONE")
            return b
    }
    return ""
}

CommandPalette_RowScore(row) {
    if !(IsObject(row))
        return 0
    raw := 0
    try {
        if row is Map
            raw := row.Has("score") ? row["score"] : 0
        else
            raw := row.score
    } catch {
        raw := 0
    }
    try return Integer(raw)
    catch {
        return 0
    }
}

CommandPalette_RowText(row, key) {
    if !(IsObject(row))
        return ""
    try {
        if row is Map
            return row.Has(key) ? String(row[key]) : ""
        if row.HasProp(key)
            return String(row.%key%)
    } catch {
    }
    return ""
}

CommandPalette_CompareScoredRows(a, b, *) {
    sa := CommandPalette_RowScore(a)
    sb := CommandPalette_RowScore(b)
    if (sa != sb)
        return sb - sa
    na := CommandPalette_RowText(a, "name")
    nb := CommandPalette_RowText(b, "name")
    c := StrCompare(na, nb, false)
    if (c > 0)
        return 1
    if (c < 0)
        return -1
    return 0
}

CommandPalette_SortScoredRows(&scored) {
    if (scored.Length < 2)
        return
    n := scored.Length
    loop n - 1 {
        swapped := false
        loop n - A_Index {
            i := A_Index
            if (CommandPalette_CompareScoredRows(scored[i], scored[i + 1]) > 0) {
                tmp := scored[i]
                scored[i] := scored[i + 1]
                scored[i + 1] := tmp
                swapped := true
            }
        }
        if !swapped
            break
    }
}

CommandPalette_BuildActionList(query := "") {
    q := StrLower(Trim(String(query)))
    if (q = "")
        return CommandPalette_BuildEmptyStateList()
    CommandPalette_EnsureCommandsLoaded()
    global g_Commands
    out := []
    if !(IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList"))
        return out
    cmdList := g_Commands["CommandList"]
    scored := []
    for cmdId, meta in cmdList {
        if !(meta is Map)
            continue
        id := Trim(String(cmdId))
        if (id = "")
            continue
        name := meta.Has("name") ? String(meta["name"]) : id
        desc := meta.Has("desc") ? String(meta["desc"]) : ""
        kws := []
        if meta.Has("keywords") && meta["keywords"] is Array {
            for kw in meta["keywords"]
                kws.Push(String(kw))
        }
        s := CommandPalette_ScoreCommand(name, kws, q)
        if (s <= 0)
            continue
        scored.Push(Map(
            "score", Integer(s),
            "id", id,
            "name", name,
            "desc", desc
        ))
    }
    if (scored.Length = 0) {
        if FuncExists("SurfaceDisposeProbe_AppendMatchingActions")
            SurfaceDisposeProbe_AppendMatchingActions(&out, q)
        return out
    }
    CommandPalette_SortScoredRows(&scored)
    lim := Min(8, scored.Length)
    loop lim {
        i := A_Index
        row := scored[i]
        out.Push(Map(
            "id", CommandPalette_RowText(row, "id"),
            "label", CommandPalette_RowText(row, "name"),
            "desc", CommandPalette_RowText(row, "desc"),
            "binding", CommandPalette_GetBindingLabel(CommandPalette_RowText(row, "id")),
            "matched", true,
            "kind", "command"
        ))
    }
    if FuncExists("SurfaceDisposeProbe_AppendMatchingActions")
        SurfaceDisposeProbe_AppendMatchingActions(&out, q)
    return out
}

CommandPalette_BuildEmptyStateList() {
    global g_CmdPal_EmptyCache, g_CmdPal_EmptyCacheTick
    if (IsSet(g_CmdPal_EmptyCache) && g_CmdPal_EmptyCache is Array && (A_TickCount - Integer(g_CmdPal_EmptyCacheTick)) < 4000)
        return g_CmdPal_EmptyCache
    out := []
    if FuncExists("_SCWV_EnsureHistoryCacheLoaded")
        _SCWV_EnsureHistoryCacheLoaded()
    global g_SC_HistoryCache
    if (IsSet(g_SC_HistoryCache) && g_SC_HistoryCache is Array) {
        lim := Min(8, g_SC_HistoryCache.Length)
        loop lim {
            k := String(g_SC_HistoryCache[A_Index])
            if (k = "")
                continue
            out.Push(Map(
                "id", "",
                "label", k,
                "desc", "最近搜索",
                "binding", "",
                "matched", false,
                "kind", "history"
            ))
        }
    }
    for row in CommandPalette_LoadExecHistory() {
        if (out.Length >= 20)
            break
        cid := row.Has("cmdId") ? String(row["cmdId"]) : ""
        out.Push(Map(
            "id", cid,
            "label", row.Has("name") ? String(row["name"]) : cid,
            "desc", row.Has("query") ? ("最近执行 · " . String(row["query"])) : "最近执行",
            "binding", CommandPalette_GetBindingLabel(cid),
            "matched", false,
            "kind", "exec"
        ))
    }
    CommandPalette_EnsureCommandsLoaded()
    global g_Commands
    if (out.Length < 12 && IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList")) {
        for cmdId, meta in g_Commands["CommandList"] {
            if (out.Length >= 20)
                break
            if !(meta is Map)
                continue
            id := Trim(String(cmdId))
            out.Push(Map(
                "id", id,
                "label", meta.Has("name") ? String(meta["name"]) : id,
                "desc", meta.Has("desc") ? String(meta["desc"]) : "",
                "binding", CommandPalette_GetBindingLabel(id),
                "matched", false,
                "kind", "command"
            ))
        }
    }
    g_CmdPal_EmptyCache := out
    g_CmdPal_EmptyCacheTick := A_TickCount
    return out
}

CommandPalette_InvalidateEmptyCache() {
    global g_CmdPal_EmptyCache
    g_CmdPal_EmptyCache := 0
}

CommandPalette_HandleQuery(q, seq := 0) {
    if (SubStr(Trim(String(q)), 1, 1) = ">") {
        CommandPalette_PushResults([
            Map("id", "", "label", ">dispose ftb", "desc", "释放悬浮栏 WebView · 回车执行", "binding", "^+Shift+F", "matched", true, "kind", "history"),
            Map("id", "", "label", ">restore ftb", "desc", "恢复悬浮栏 · 回车执行", "binding", "^+Shift+R", "matched", true, "kind", "history"),
            Map("id", "", "label", ">dispose clipboard", "desc", "释放剪贴板 WebView", "binding", "", "matched", true, "kind", "history"),
            Map("id", "", "label", ">dispose config", "desc", "释放设置 WebView", "binding", "", "matched", true, "kind", "history")
        ], seq)
        return
    }
    try {
        CommandPalette_PushResults(CommandPalette_BuildActionList(q), seq)
    } catch as e {
        try TrayTip("命令面板", "搜索失败: " . e.Message, "Icon!")
        catch {
        }
        CommandPalette_PushResults([], seq)
    }
}

CommandPalette_HandleExecute(msg) {
    kind := msg.Has("kind") ? StrLower(String(msg["kind"])) : "command"
    query := msg.Has("query") ? Trim(String(msg["query"])) : ""
    cmdId := msg.Has("cmdId") ? Trim(String(msg["cmdId"])) : ""
    label := msg.Has("label") ? String(msg["label"]) : ""
    if (kind = "history") {
        pick := label != "" ? label : query
        if (pick != "") {
            if FuncExists("SurfaceDisposeProbe_TryExecuteSlashQuery") && SurfaceDisposeProbe_TryExecuteSlashQuery(pick) != "" {
                CommandPalette_Hide()
                return
            }
            CommandPalette_SetInputText(pick)
            SetTimer(() => CommandPalette_HandleQuery(pick), -80)
        }
        return
    }
    if (cmdId = "" && query != "" && kind = "history") {
        CommandPalette_SetInputText(query)
        SetTimer(() => CommandPalette_HandleQuery(query), -80)
        return
    }
    if (cmdId = "")
        return
    if (query != "" && FuncExists("_SCWV_RecordSearchHistory"))
        _SCWV_RecordSearchHistory(query)
    name := label
    if (name = "") {
        CommandPalette_EnsureCommandsLoaded()
        global g_Commands
        if (IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList")) {
            cl := g_Commands["CommandList"]
            if (cl is Map && cl.Has(cmdId) && cl[cmdId] is Map)
                name := cl[cmdId].Has("name") ? String(cl[cmdId]["name"]) : cmdId
        }
    }
    if FuncExists("SurfaceDisposeProbe_TryExecute") && SurfaceDisposeProbe_TryExecute(cmdId) {
        CommandPalette_RecordExec(cmdId, name, query)
        CommandPalette_Hide()
        return
    }
    CommandPalette_RecordExec(cmdId, name, query)
    if FuncExists("VK_Execute")
        VK_Execute(cmdId)
    CommandPalette_Hide()
}

CommandPalette_HandleVoiceToggle() {
    if FuncExists("WailsWhisper_IsRecording") && WailsWhisper_IsRecording() {
        if FuncExists("WailsWhisper_StopAndTranscribe")
            SetTimer(WailsWhisper_StopAndTranscribe, -30)
        return
    }
    if FuncExists("WailsWhisper_StartRecording")
        WailsWhisper_StartRecording()
}

CommandPalette_HandleAgentDebug() {
    if FuncExists("CommandPalette_ShowSearchDebug") {
        try CommandPalette_ShowSearchDebug(true, "agent")
        catch as e {
            try TrayTip("命令面板", "无法打开诊断: " . e.Message, "Iconx 2")
            catch {
            }
        }
        return
    }
    if FuncExists("CommandPalette_AgentDebug_Show") {
        try CommandPalette_AgentDebug_Show(true)
        catch as e {
            try TrayTip("命令面板", "无法打开诊断: " . e.Message, "Iconx 2")
            catch {
            }
        }
    }
}

CommandPalette_ExecFilePath() {
    return Nmer_CommandPaletteExecPath()
}

CommandPalette_ExecReadMtime() {
    path := CommandPalette_ExecFilePath()
    if !FileExist(path)
        return ""
    try return FileGetTime(path, "M")
    catch {
        return ""
    }
}

CommandPalette_EnsureExecCacheLoaded() {
    global g_CmdPal_ExecCache
    if (Type(g_CmdPal_ExecCache) = "Array")
        return
    CommandPalette_ReloadExecFromDisk()
}

CommandPalette_ReloadExecFromDisk() {
    global g_CmdPal_ExecCache, g_CmdPal_ExecFileMtime
    path := CommandPalette_ExecFilePath()
    arr := []
    if FileExist(path) {
        try {
            raw := FileRead(path, "UTF-8")
            if (raw != "")
                arr := Jxon_Load(raw)
        } catch {
            arr := []
        }
    }
    if (Type(arr) != "Array")
        arr := []
    g_CmdPal_ExecCache := arr
    g_CmdPal_ExecFileMtime := CommandPalette_ExecReadMtime()
}

CommandPalette_LoadExecHistory() {
    CommandPalette_EnsureExecCacheLoaded()
    global g_CmdPal_ExecCache, g_CmdPal_ExecDirty, g_CmdPal_ExecFileMtime
    if !g_CmdPal_ExecDirty && CommandPalette_ExecReadMtime() != g_CmdPal_ExecFileMtime
        CommandPalette_ReloadExecFromDisk()
    if (Type(g_CmdPal_ExecCache) = "Array")
        return g_CmdPal_ExecCache
    return []
}

CommandPalette_RecordExec(cmdId, name, query := "") {
    global g_CmdPal_ExecCache, g_CmdPal_ExecDirty
    CommandPalette_InvalidateEmptyCache()
    id := Trim(String(cmdId))
    if (id = "")
        return
    CommandPalette_EnsureExecCacheLoaded()
    row := Map("cmdId", id, "name", String(name), "query", Trim(String(query)), "at", A_Now)
    newArr := [row]
    for item in g_CmdPal_ExecCache {
        if !(item is Map)
            continue
        oldId := item.Has("cmdId") ? String(item["cmdId"]) : ""
        if (oldId = id && item.Has("query") && String(item["query"]) = Trim(String(query)))
            continue
        newArr.Push(item)
        if (newArr.Length >= 50)
            break
    }
    g_CmdPal_ExecCache := newArr
    g_CmdPal_ExecDirty := true
    SetTimer(CommandPalette_FlushExecHistory, 0)
    SetTimer(CommandPalette_FlushExecHistory, -1500)
}

CommandPalette_FlushExecHistory(*) {
    global g_CmdPal_ExecCache, g_CmdPal_ExecDirty, g_CmdPal_ExecFileMtime
    if !g_CmdPal_ExecDirty
        return
    path := CommandPalette_ExecFilePath()
    try DirCreate(A_ScriptDir . "\Data")
    catch {
    }
    try {
        FileDelete(path)
        FileAppend(Jxon_Dump(g_CmdPal_ExecCache), path, "UTF-8")
        g_CmdPal_ExecFileMtime := CommandPalette_ExecReadMtime()
        g_CmdPal_ExecDirty := false
    } catch {
    }
}

CommandPalette_OnInputActivated() {
    if !CommandPalette_IsVisible()
        CommandPalette_Show()
    else
        SetTimer(CommandPalette_DeferredFocus, -150)
}

CommandPalette_NormalizeThemeToken(raw, fallback := "dark") {
    s := StrLower(Trim(String(raw)))
    if (s = "light" || s = "lite" || s = "浅色")
        return "light"
    if (s = "dark")
        return "dark"
    return (fallback = "light") ? "light" : "dark"
}

CommandPalette_GetThemeMode() {
    if FuncExists("FloatingToolbar_GetThemeMode")
        return CommandPalette_NormalizeThemeToken(FloatingToolbar_GetThemeMode())
    if FuncExists("_VK_GetThemeMode")
        return CommandPalette_NormalizeThemeToken(_VK_GetThemeMode())
    try {
        global ThemeMode
        if IsSet(ThemeMode)
            return CommandPalette_NormalizeThemeToken(ThemeMode)
    } catch {
    }
    return "dark"
}

CommandPalette_PushThemeToWeb(override := "") {
    tm := (Trim(String(override)) != "")
        ? CommandPalette_NormalizeThemeToken(override)
        : CommandPalette_GetThemeMode()
    CommandPalette_PushToWeb(Map("type", "set_theme", "themeMode", tm))
}

CommandPalette_PushTurboError(message) {
    CommandPalette_ClearTurboPending()
    CommandPalette_PushToWeb(Map("type", "palette_turbo_error", "message", String(message)))
}

CommandPalette_InstallRoot() {
    if IsSet(MainScriptDir) {
        try {
            r := Trim(String(MainScriptDir))
            if (r != "")
                return r
        } catch {
        }
    }
    return A_ScriptDir
}

CommandPalette_ResolveSearchCoreExe() {
    root := CommandPalette_InstallRoot()
    for rel in ["\tools\search\SearchCenterCore.exe", "\searchcore\SearchCenterCore.exe", "\SearchCenterCore.exe"] {
        p := root . rel
        if FileExist(p)
            return p
    }
    if FuncExists("Nmer_SearchCenterCoreExe") {
        try {
            p := Trim(String(Nmer_SearchCenterCoreExe()))
            if (p != "" && FileExist(p))
                return p
        } catch {
        }
    }
    return ""
}

CommandPalette_EnsureSearchCoreRunning() {
    if ProcessExist("SearchCenterCore.exe")
        return true
    if FuncExists("Nmer_StartSearchCenterCore")
        return Nmer_StartSearchCenterCore(false)
    exe := CommandPalette_ResolveSearchCoreExe()
    if (exe = "")
        return false
    root := CommandPalette_InstallRoot()
    try {
        if FuncExists("_SCWV_ApplySearchCoreDefaults")
            _SCWV_ApplySearchCoreDefaults()
        Run('"' exe '" -base "' root '"', root, "Hide")
    } catch {
        return false
    }
    return true
}

CommandPalette_IsSearchCoreReady() {
    if FuncExists("Nmer_SearchCenterCoreHealthy") && Nmer_SearchCenterCoreHealthy()
        return true
    ; 进程在但 WinHttp /health 探针失败时仍允许发搜索（避免误等 45s 报 8080 超时）
    return ProcessExist("SearchCenterCore.exe") ? true : false
}

CommandPalette_MapGoItemFromAny(it) {
    if (it is Map)
        return CommandPalette_MapGoItemToTurbo(it)
    if !IsObject(it)
        return 0
    m := Map()
    for key in ["Title", "SubTitle", "Content", "Source", "DataType", "ID", "Metadata", "ActionParams", "originalDataType"] {
        try {
            if it.HasProp(key)
                m[key] := it.%key%
        } catch {
        }
    }
    return CommandPalette_MapGoItemToTurbo(m)
}

CommandPalette_MapGoItemToTurbo(it) {
    if !(it is Map)
        return 0
    title := ""
    if it.Has("Title")
        title := String(it["Title"])
    else if it.Has("title")
        title := String(it["title"])
    subtitle := ""
    if it.Has("SubTitle")
        subtitle := String(it["SubTitle"])
    else if it.Has("subtitle")
        subtitle := String(it["subtitle"])
    else if it.Has("Source")
        subtitle := String(it["Source"])
    path := ""
    if it.Has("Content") {
        cand := Trim(String(it["Content"]))
        if (cand != "" && (InStr(cand, ":\") || InStr(cand, "/") || InStr(cand, "\\")))
            path := cand
        else if (cand != "" && (FileExist(cand) || DirExist(cand)))
            path := cand
    }
    if (path = "" && it.Has("Metadata") && it["Metadata"] is Map) {
        meta := it["Metadata"]
        if meta.Has("FilePath") {
            cand := Trim(String(meta["FilePath"]))
            if (cand != "")
                path := cand
        }
    }
    if (path = "" && it.Has("ActionParams") && it["ActionParams"] is Map) {
        ap := it["ActionParams"]
        if ap.Has("FilePath") {
            cand := Trim(String(ap["FilePath"]))
            if (cand != "")
                path := cand
        }
    }
    if (path = "" && it.Has("ID")) {
        cand := Trim(String(it["ID"]))
        if (cand != "" && (InStr(cand, ":\") || InStr(cand, "\\") || InStr(cand, "/")))
            path := cand
    }
    if (title = "" && path != "")
        title := RegExReplace(path, ".*\\", "")
    kind := "file"
    dt := ""
    if it.Has("DataType")
        dt := StrLower(String(it["DataType"]))
    else if it.Has("dataType")
        dt := StrLower(String(it["dataType"]))
    if (dt = "folder")
        kind := "folder"
    return Map(
        "label", title,
        "desc", subtitle,
        "path", path,
        "kind", kind,
        "title", title,
        "subtitle", subtitle
    )
}

CommandPalette_ParseTurboGoBody(body, kw, limit) {
    items := []
    try data := Jxon_Load(body)
    catch {
        return items
    }
    if !(data is Map)
        return items
    itemsRaw := data.Has("items") ? data["items"] : (data.Has("Items") ? data["Items"] : [])
    if !(itemsRaw is Array)
        return items
    cap := limit > 0 ? limit : 20
    for _, it in itemsRaw {
        if (items.Length >= cap)
            break
        row := CommandPalette_MapGoItemFromAny(it)
        if (row is Map && (row["path"] != "" || row["label"] != ""))
            items.Push(row)
    }
    return items
}

CommandPalette_ClearTurboPending() {
    global g_CmdPal_TurboPendingMeta
    g_CmdPal_TurboPendingMeta := 0
    SetTimer(CommandPalette_TurboPendingTimeout, 0)
}

CommandPalette_TurboPendingTimeout(*) {
    global g_CmdPal_TurboPendingMeta
    if !(g_CmdPal_TurboPendingMeta is Map)
        return
    meta := g_CmdPal_TurboPendingMeta
    kw := meta.Has("kw") ? String(meta["kw"]) : ""
    proc := ProcessExist("SearchCenterCore.exe") ? "1" : "0"
    healthy := "0"
    if FuncExists("Nmer_SearchCenterCoreHealthy")
        try healthy := Nmer_SearchCenterCoreHealthy() ? "1" : "0"
    if FuncExists("Nmer_SearchCoreLog")
        Nmer_SearchCoreLog("palette_timeout kw=" . kw . " proc=" . proc . " health=" . healthy . " tries=" . (meta.Has("tries") ? meta["tries"] : 0))
    g_CmdPal_TurboPendingMeta := 0
    msg := "本地搜索超时，SearchCenterCore 未在 8080 就绪"
    if (proc = "0")
        msg .= "（任务管理器无进程，见 Cache\\debug\\searchcore_launch.log）"
    else if (healthy = "0")
        msg .= "（进程在但 8080 无响应，可能被占用或正在启动）"
    CommandPalette_PushTurboError(msg)
}

CommandPalette_OnSharedGoSearchResponse(keyword, goItems, limit := 20) {
    global g_CmdPal_TurboPendingMeta, g_CmdPal_Visible
    if !g_CmdPal_Visible
        return
    if !(g_CmdPal_TurboPendingMeta is Map)
        return
    meta := g_CmdPal_TurboPendingMeta
    kw := Trim(String(keyword))
    if (Trim(String(meta.Has("kw") ? meta["kw"] : "")) != kw)
        return
    seq := meta.Has("seq") ? Integer(meta["seq"]) : 0
    lim := Integer(limit) > 0 ? Integer(limit) : (meta.Has("lim") ? Integer(meta["lim"]) : 20)
    items := []
    if (goItems is Array) {
        for _, it in goItems {
            if (items.Length >= lim)
                break
            row := CommandPalette_MapGoItemFromAny(it)
            if (row is Map && (row["path"] != "" || row["label"] != ""))
                items.Push(row)
        }
    }
    CommandPalette_ClearTurboPending()
    payload := Map("type", "palette_turbo_results", "query", kw, "items", items, "elapsedMs", 0)
    if (seq > 0)
        payload["seq"] := seq
    CommandPalette_PushToWeb(payload)
}

CommandPalette_OnSharedGoSearchFailed(keyword, message) {
    global g_CmdPal_TurboPendingMeta
    if !(g_CmdPal_TurboPendingMeta is Map)
        return
    meta := g_CmdPal_TurboPendingMeta
    if (Trim(String(meta.Has("kw") ? meta["kw"] : "")) != Trim(String(keyword)))
        return
    CommandPalette_ClearTurboPending()
    CommandPalette_PushTurboError(String(message))
}

CommandPalette_FireTurboGoSearch(keyword, limit := 20) {
    global g_CmdPal_TurboPendingMeta, g_CmdPal_TurboReqGen
    kw := Trim(String(keyword))
    lim := Integer(limit)
    if (lim <= 0)
        lim := 20
    if (lim > 20)
        lim := 20
    seq := 0
    if (g_CmdPal_TurboPendingMeta is Map && g_CmdPal_TurboPendingMeta.Has("seq"))
        seq := Integer(g_CmdPal_TurboPendingMeta["seq"])
    CommandPalette_ExecuteGoSearch(kw, lim, g_CmdPal_TurboReqGen, seq)
}

CommandPalette_DeferredTurboViaScwv(*) {
    global g_CmdPal_TurboPendingMeta
    if !(g_CmdPal_TurboPendingMeta is Map)
        return
    meta := g_CmdPal_TurboPendingMeta
    tries := meta.Has("tries") ? Integer(meta["tries"]) : 0
    if (tries >= 80) {
        if FuncExists("Nmer_SearchCoreLog")
            Nmer_SearchCoreLog("palette_deferred_giveup kw=" . String(meta["kw"]) . " tries=" . tries)
        CommandPalette_OnSharedGoSearchFailed(String(meta["kw"]), "SearchCenterCore 启动超时（8080 无响应）")
        return
    }
    meta["tries"] := tries + 1
    g_CmdPal_TurboPendingMeta := meta
    if (Mod(tries, 10) = 0) && FuncExists("Nmer_SearchCoreLog")
        Nmer_SearchCoreLog("palette_deferred_wait kw=" . String(meta["kw"]) . " try=" . tries . " proc=" . (ProcessExist("SearchCenterCore.exe") ? "1" : "0") . " health=" . (CommandPalette_IsSearchCoreReady() ? "1" : "0"))
    if ProcessExist("SearchCenterCore.exe") || CommandPalette_IsSearchCoreReady() {
        SetTimer(CommandPalette_TurboPendingTimeout, 0)
        lim := meta.Has("lim") ? Integer(meta["lim"]) : 20
        CommandPalette_FireTurboGoSearch(String(meta["kw"]), lim)
        return
    }
    CommandPalette_EnsureSearchCoreRunning()
    SetTimer(CommandPalette_DeferredTurboViaScwv, -300)
}

CommandPalette_HandleTurboSearch(keyword, limit := 20, seq := 0) {
    kw := Trim(String(keyword))
    if (kw = "") {
        CommandPalette_HandleQuery("", seq)
        return
    }
    global g_CmdPal_TurboReqGen, g_CmdPal_TurboPendingMeta
    g_CmdPal_TurboReqGen++
    lim := Integer(limit) > 0 ? Integer(limit) : 20
    if (lim > 20)
        lim := 20
    g_CmdPal_TurboPendingMeta := Map("kw", kw, "lim", lim, "seq", Integer(seq), "tick", A_TickCount, "tries", 0)
    SetTimer(CommandPalette_TurboPendingTimeout, -28000)
    if FuncExists("Nmer_SearchCoreLog")
        Nmer_SearchCoreLog("palette_turbo_begin kw=" . kw)
    if (CommandPalette_ResolveSearchCoreExe() = "") {
        CommandPalette_OnSharedGoSearchFailed(kw, "SearchCenterCore 未找到，请在 searchcore 编译后复制到 tools\\search\\SearchCenterCore.exe")
        return
    }
    if ProcessExist("SearchCenterCore.exe") {
        SetTimer(CommandPalette_TurboPendingTimeout, 0)
        SetTimer((*) => CommandPalette_FireTurboGoSearch(kw, lim), -1)
        return
    }
    CommandPalette_EnsureSearchCoreRunning()
    if ProcessExist("SearchCenterCore.exe") {
        SetTimer(CommandPalette_TurboPendingTimeout, 0)
        SetTimer((*) => CommandPalette_FireTurboGoSearch(kw, lim), -1)
        return
    }
    SetTimer(CommandPalette_DeferredTurboViaScwv, -150)
}

CommandPalette_OnTurboHttpAsync(ret, meta) {
    global g_CmdPal_TurboPollToken, g_CmdPal_TurboReqGen, g_CmdPal_TurboInFlight
    if !(meta is Map)
        return
    pollToken := meta.Has("pollToken") ? Integer(meta["pollToken"]) : 0
    if (pollToken && pollToken != g_CmdPal_TurboPollToken)
        return
    gen := meta.Has("gen") ? Integer(meta["gen"]) : 0
    if (gen != Integer(g_CmdPal_TurboReqGen))
        return
    g_CmdPal_TurboInFlight := false
    kw := meta.Has("kw") ? String(meta["kw"]) : ""
    lim := meta.Has("lim") ? Integer(meta["lim"]) : 20
    seq := meta.Has("seq") ? Integer(meta["seq"]) : 0
    ok := false
    if (ret is Map) && ret.Has("ok")
        ok := !!ret["ok"]
    if !ok {
        errMsg := "本地搜索失败"
        if (ret is Map) {
            if (ret.Has("errorCode") && String(ret["errorCode"]) = "timeout")
                errMsg := "本地搜索超时（SearchCenterCore 响应过慢）"
            else if (ret.Has("error") && String(ret["error"]) != "")
                errMsg := "本地搜索失败: " . String(ret["error"])
        }
        if FuncExists("Nmer_SearchCoreLog")
            Nmer_SearchCoreLog("palette_http_fail kw=" . kw . " err=" . errMsg)
        CommandPalette_PushTurboError(errMsg)
        return
    }
    st := ret.Has("status") ? Integer(ret["status"]) : 0
    raw := ret.Has("text") ? String(ret["text"]) : ""
    if (st != 200) {
        CommandPalette_PushTurboError("SearchCenterCore 请求失败 HTTP " . st)
        return
    }
    if (raw = "") {
        CommandPalette_PushTurboError("SearchCenterCore 返回空响应")
        return
    }
    items := CommandPalette_ParseTurboGoBody(raw, kw, lim)
    CommandPalette_ClearTurboPending()
    elapsed := meta.Has("startTick") ? (A_TickCount - Integer(meta["startTick"])) : 0
    payload := Map("type", "palette_turbo_results", "query", kw, "items", items, "elapsedMs", elapsed)
    if (seq > 0)
        payload["seq"] := seq
    if FuncExists("Nmer_SearchCoreLog")
        Nmer_SearchCoreLog("palette_http_ok kw=" . kw . " items=" . items.Length . " ms=" . elapsed)
    CommandPalette_PushToWeb(payload)
}

CommandPalette_ExecuteGoSearch(keyword, limit, gen, seq := 0) {
    global g_CmdPal_TurboInFlight, g_CmdPal_TurboWhr, g_CmdPal_TurboMeta, g_CmdPal_TurboPollToken
    kw := Trim(String(keyword))
    lim := Integer(limit)
    if (lim <= 0)
        lim := 20
    if (lim > 20)
        lim := 20
    if g_CmdPal_TurboInFlight {
        global g_CmdPal_TurboReqGen
        g_CmdPal_TurboReqGen++
        gen := g_CmdPal_TurboReqGen
    }
    if (CommandPalette_ResolveSearchCoreExe() = "") {
        CommandPalette_PushTurboError("SearchCenterCore 未找到，请在 searchcore 编译后复制到 tools\\search\\SearchCenterCore.exe")
        return
    }
    if !ProcessExist("SearchCenterCore.exe") {
        CommandPalette_EnsureSearchCoreRunning()
        if !ProcessExist("SearchCenterCore.exe") {
            CommandPalette_PushTurboError("SearchCenterCore 未启动，请稍候重试")
            return
        }
    }
    SetTimer(CommandPalette_TurboPendingTimeout, 0)
    encQ := kw
    try encQ := UriEncode(kw)
    catch {
    }
    q := "q=" . encQ . "&type=all&limit=" . lim . "&offset=0"
    url := "http://127.0.0.1:8080/search?" . q
    g_CmdPal_TurboPollToken += 1
    pollToken := g_CmdPal_TurboPollToken
    meta := Map("kw", kw, "lim", lim, "gen", gen, "seq", Integer(seq), "startTick", A_TickCount, "pollToken", pollToken)
    g_CmdPal_TurboMeta := meta
    g_CmdPal_TurboInFlight := true
    if (IsSet(g_CoreAsyncHttp_Loaded) && g_CoreAsyncHttp_Loaded) {
        if FuncExists("Nmer_SearchCoreLog")
            Nmer_SearchCoreLog("palette_http_send kw=" . kw . " url=" . url)
        opts := Map(
            "tag", "cmdpal_turbo_search",
            "timeoutMs", 90000,
            "resolveTimeoutMs", 3000,
            "connectTimeoutMs", 3000,
            "sendTimeoutMs", 30000,
            "receiveTimeoutMs", 90000,
            "maxRetries", 1,
            "retryDelayMs", 200
        )
        try {
            HttpGetAsync(url, (ret) => CommandPalette_OnTurboHttpAsync(ret, meta), opts)
            return
        } catch as err {
            if FuncExists("Nmer_SearchCoreLog")
                Nmer_SearchCoreLog("palette_http_async_fail kw=" . kw . " err=" . err.Message)
        }
    } else if FuncExists("Nmer_SearchCoreLog") {
        Nmer_SearchCoreLog("palette_http_skip reason=core_async_not_loaded")
    }
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        if FuncExists("NiumaOllama_IsLoopbackUrl") && NiumaOllama_IsLoopbackUrl(url)
            try whr.SetProxy(1)
        whr.Open("GET", url, true)
        whr.SetTimeouts(3000, 3000, 90000, 90000)
        whr.Send()
        g_CmdPal_TurboWhr := whr
        SetTimer((*) => CommandPalette_PollTurboHttp(pollToken), 20)
    } catch as err {
        g_CmdPal_TurboInFlight := false
        CommandPalette_PushTurboError("本地搜索请求失败: " . err.Message)
    }
}

CommandPalette_FinishTurboHttp() {
    global g_CmdPal_TurboInFlight, g_CmdPal_TurboWhr, g_CmdPal_TurboMeta, g_CmdPal_TurboPollToken
    g_CmdPal_TurboPollToken += 1
    g_CmdPal_TurboWhr := 0
    g_CmdPal_TurboMeta := 0
    g_CmdPal_TurboInFlight := false
}

CommandPalette_PollTurboHttp(pollToken := 0, *) {
    global g_CmdPal_TurboWhr, g_CmdPal_TurboMeta, g_CmdPal_TurboInFlight, g_CmdPal_TurboPollToken, g_CmdPal_TurboReqGen
    if (pollToken && pollToken != g_CmdPal_TurboPollToken)
        return
    if !IsObject(g_CmdPal_TurboWhr) || !(g_CmdPal_TurboMeta is Map) {
        CommandPalette_FinishTurboHttp()
        return
    }
    whr := g_CmdPal_TurboWhr
    meta := g_CmdPal_TurboMeta
    startTick := meta.Has("startTick") ? Integer(meta["startTick"]) : A_TickCount
    if (A_TickCount - startTick > 120000) {
        try whr.Abort()
        CommandPalette_FinishTurboHttp()
        CommandPalette_PushTurboError("本地搜索超时（SearchCenterCore 响应过慢，可缩小关键词或稍后重试）")
        return
    }
    pr := Map("ready", false, "fatal", false, "err", "")
    if FuncExists("_SCWV_WinHttpAsyncPollResponseReady")
        pr := _SCWV_WinHttpAsyncPollResponseReady(whr)
    else {
        try {
            if (whr.readyState = 4)
                pr["ready"] := true
        } catch {
        }
    }
    if pr["fatal"] {
        CommandPalette_FinishTurboHttp()
        CommandPalette_PushTurboError("本地搜索连接失败")
        return
    }
    if !pr["ready"] {
        SetTimer((*) => CommandPalette_PollTurboHttp(pollToken), -25)
        return
    }
    gen := meta.Has("gen") ? Integer(meta["gen"]) : 0
    if (gen != Integer(g_CmdPal_TurboReqGen)) {
        CommandPalette_FinishTurboHttp()
        return
    }
    kw := meta.Has("kw") ? String(meta["kw"]) : ""
    lim := meta.Has("lim") ? Integer(meta["lim"]) : 20
    elapsed := A_TickCount - startTick
    try {
        st := Integer(whr.Status)
        raw := ""
        if FuncExists("_SCWV_WinHttpReadUtf8Text")
            raw := _SCWV_WinHttpReadUtf8Text(whr)
        else
            raw := whr.ResponseText
        if (st != 200) {
            CommandPalette_PushTurboError("SearchCenterCore 请求失败 HTTP " . st)
        } else if (raw = "") {
            CommandPalette_PushTurboError("SearchCenterCore 返回空响应")
        } else {
            items := CommandPalette_ParseTurboGoBody(raw, kw, lim)
            CommandPalette_ClearTurboPending()
            payload := Map(
                "type", "palette_turbo_results",
                "query", kw,
                "items", items,
                "elapsedMs", elapsed
            )
            if (meta.Has("seq") && Integer(meta["seq"]) > 0)
                payload["seq"] := Integer(meta["seq"])
            CommandPalette_PushToWeb(payload)
        }
    } catch as err {
        CommandPalette_PushTurboError("解析搜索结果失败: " . err.Message)
    }
    CommandPalette_FinishTurboHttp()
}

CommandPalette_HandleTurboExecute(msg) {
    path := msg.Has("path") ? Trim(String(msg["path"])) : ""
    title := msg.Has("title") ? String(msg["title"]) : ""
    query := msg.Has("query") ? Trim(String(msg["query"])) : ""
    if (query != "" && FuncExists("_SCWV_RecordSearchHistory"))
        _SCWV_RecordSearchHistory(query)
    if (path = "") {
        try TrayTip("命令面板", "无法打开：路径为空", "Icon!")
        catch {
        }
        CommandPalette_Hide()
        return
    }
    errMsg := ""
    launched := false
    if FuncExists("_SCWV_LaunchAppTarget")
        launched := _SCWV_LaunchAppTarget(path, &errMsg)
    if !launched {
        try {
            if DirExist(path)
                Run('explorer.exe "' . path . '"')
            else if FileExist(path)
                Run(path)
            else
                Run('explorer.exe /select,"' . path . '"')
            launched := true
        } catch as err {
            errMsg := err.Message
        }
    }
    if !launched {
        try TrayTip("打开失败", errMsg != "" ? errMsg : path, "Iconx 2")
        catch {
        }
    }
    CommandPalette_Hide()
}

CommandPalette_HandleAiStub(query) {
    q := Trim(String(query))
    try {
        if (q != "")
            OutputDebug("[CommandPalette] AI stub query=" . q . "`n")
    } catch {
    }
    CommandPalette_PushToWeb(Map(
        "type", "palette_ai_status",
        "message", "选择模型后 Enter 发送",
        "status", "idle"
    ))
}

CommandPalette_AiProviderLabels() {
    static labels := 0
    if !IsObject(labels) {
        labels := Map(
            "openai", "OpenAI",
            "deepseek", "DeepSeek",
            "kimi", "Kimi",
            "qwen", "Qwen",
            "claude", "Claude",
            "gemini", "Gemini",
            "glm", "GLM",
            "zhipu", "智谱",
            "minimax", "MiniMax",
            "siliconflow", "硅基流动",
            "openclaw", "OpenClaw",
            "codex_cli", "Codex CLI",
            "gemini_cli", "Gemini CLI",
            "qwen_cli", "Qwen CLI",
            "ollama_cli", "Ollama CLI",
            "claude_cli", "Claude CLI",
            "deepseek_cli", "DeepSeek CLI",
            "kimi_cli", "Kimi CLI",
            "zhipu_cli", "智谱 CLI",
            "copilot_cli", "Copilot CLI",
            "openclaw_cli", "OpenClaw CLI",
            "studio_cli", "定制终端"
        )
    }
    return labels
}

CommandPalette_NormalizeAiProvider(id) {
    p := Trim(StrLower(String(id)))
    if (p = "")
        return ""
    if FuncExists("UserStudio_NormalizeLlmProvider")
        try return UserStudio_NormalizeLlmProvider(p)
        catch {
        }
    return p
}

CommandPalette_AiProviderIconBase(id) {
    p := CommandPalette_NormalizeAiProvider(id)
    if (p = "")
        return ""
    if RegExMatch(p, "_cli$")
        p := SubStr(p, 1, StrLen(p) - 4)
    aliases := Map(
        "kimi_cli", "kimi", "deepseek_cli", "deepseek", "claude_cli", "claude",
        "gemini_cli", "gemini", "qwen_cli", "qwen", "ollama_cli", "ollama",
        "zhipu_cli", "zhipu", "copilot_cli", "copilot", "openclaw_cli", "openclaw",
        "codex_cli", "codex", "studio_cli", "openclaw"
    )
    if aliases.Has(p)
        return aliases[p]
    return p
}

CommandPalette_AiProviderIconBases(id) {
    p := CommandPalette_NormalizeAiProvider(id)
    bases := []
    nameMap := Map(
        "openai", ["ChatGPT", "chatgpt", "openai", "codex", "Codex"],
        "codex_cli", ["codex", "Codex", "codex1", "terminal", "cmd"],
        "gemini_cli", ["gemini", "Gemini"],
        "openclaw_cli", ["openclaw", "OpenClaw"],
        "qwen_cli", ["qwen", "Qwen"],
        "ollama_cli", ["ollama", "Ollama"],
        "claude_cli", ["claude", "Claude"],
        "deepseek_cli", ["DeepSeek", "deepseek"],
        "kimi_cli", ["kimi", "Kimi", "moonshot"],
        "zhipu_cli", ["zhipu", "Zhipu", "glm", "chelper"],
        "copilot_cli", ["copilot", "Copilot", "ChatGPT"],
        "kimi", ["kimi", "Kimi", "moonshot"],
        "qwen", ["qwen", "Qwen"],
        "deepseek", ["DeepSeek", "deepseek"],
        "claude", ["Claude", "claude"],
        "gemini", ["gemini", "Gemini"],
        "glm", ["glm", "GLM", "zhipu"],
        "zhipu", ["zhipu", "Zhipu", "glm"],
        "minimax", ["minimax", "MiniMax"],
        "siliconflow", ["siliconflow", "硅基流动"],
        "ollama", ["ollama", "Ollama"],
        "openclaw", ["openclaw", "OpenClaw"],
        "openrouter", ["openrouter", "OpenRouter"]
    )
    if nameMap.Has(p) {
        for _, b in nameMap[p]
            bases.Push(b)
    }
    if (p != "") {
        found := false
        for b in bases {
            if (b = p) {
                found := true
                break
            }
        }
        if !found {
            if (bases.Length = 0)
                bases.Push(p)
            else
                bases.InsertAt(1, p)
        }
    }
    p1 := CommandPalette_AiProviderIconBase(id)
    if (p1 != "") {
        found := false
        for b in bases {
            if (b = p1) {
                found := true
                break
            }
        }
        if !found
            bases.Push(p1)
    }
    return bases
}

CommandPalette_AiProviderIconFile(relUnderAssets) {
    p := A_ScriptDir . "\assets\" . StrReplace(relUnderAssets, "/", "\")
    if FileExist(p)
        return p
    return ""
}

CommandPalette_AiProviderIconUrlForFile(relUnderAssets) {
    if (CommandPalette_AiProviderIconFile(relUnderAssets) = "")
        return ""
    if FuncExists("BuildAppAssetUrl") {
        try return BuildAppAssetUrl(relUnderAssets)
        catch {
        }
    }
    return "https://app.local/assets/" . StrReplace(relUnderAssets, "\", "/")
}

CommandPalette_AiProviderIconKey(id) {
    ; 与 FloatingToolbarStrip NEW_SESSION_GROUP_DEFS 的 icon 字段一致
    p := CommandPalette_NormalizeAiProvider(id)
    static pickIcon := 0
    if !IsObject(pickIcon) {
        pickIcon := Map(
            "openai", "openai", "deepseek", "deepseek", "kimi", "kimi", "qwen", "qwen",
            "claude", "claude", "gemini", "gemini", "glm", "glm", "zhipu", "zhipu",
            "minimax", "minimax", "siliconflow", "siliconflow", "ollama", "ollama", "openclaw", "openclaw",
            "codex_cli", "codex_cli", "gemini_cli", "gemini_cli", "openclaw_cli", "openclaw_cli",
            "qwen_cli", "qwen_cli", "ollama_cli", "ollama_cli", "claude_cli", "claude_cli",
            "deepseek_cli", "deepseek_cli", "kimi_cli", "kimi_cli", "zhipu_cli", "zhipu_cli",
            "copilot_cli", "copilot_cli", "studio_cli", "studio_cli"
        )
    }
    if pickIcon.Has(p)
        return pickIcon[p]
    if RegExMatch(p, "_cli$")
        return p
    return p != "" ? p : "openai"
}

CommandPalette_ResolveProviderIconSrc(id) {
    ; 与 Niuma Chat providerIconUrlList 相同优先级，但在宿主按磁盘解析首个存在的图标（优先 PNG/JPG）
    bases := CommandPalette_AiProviderIconBases(id)
    pid := CommandPalette_NormalizeAiProvider(id)
    if (pid = "")
        pid := "openai"
    if (bases.Length = 0)
        bases.Push(pid)
    for _, base in bases {
        for ext in [".png", ".jpg", ".jpeg", ".svg", ".webp"] {
            u := CommandPalette_AiProviderIconUrlForFile("icons/app/" . base . ext)
            if (u != "")
                return u
        }
    }
    for ext in [".svg", ".webp", ".png", ".jpg", ".jpeg"] {
        u := CommandPalette_AiProviderIconUrlForFile("icons/ai/" . pid . ext)
        if (u != "")
            return u
        u := CommandPalette_AiProviderIconUrlForFile("icons/app/" . pid . ext)
        if (u != "")
            return u
    }
    fb := CommandPalette_AiProviderIconUrlForFile("icons/app/chat-ai-fallback.svg")
    return fb != "" ? fb : "https://app.local/assets/icons/app/chat-ai-fallback.svg"
}

CommandPalette_AiProviderIconUrls(id) {
    ; 回退链：与 FloatingToolbarStrip providerIconUrlList 一致（app 别名 → ai/app pid → 兜底）
    urls := []
    src := CommandPalette_ResolveProviderIconSrc(id)
    if (src != "")
        urls.Push(src)
    bases := CommandPalette_AiProviderIconBases(id)
    pid := CommandPalette_NormalizeAiProvider(id)
    if (pid = "")
        pid := "openai"
    if (bases.Length = 0)
        bases.Push(pid)
    for _, base in bases {
        for ext in [".png", ".jpg", ".jpeg", ".svg", ".webp"] {
            u := CommandPalette_AiProviderIconUrlForFile("icons/app/" . base . ext)
            if (u != "" && !CommandPalette_UrlInList(urls, u))
                urls.Push(u)
        }
    }
    for ext in [".svg", ".webp", ".png", ".jpg", ".jpeg"] {
        u := CommandPalette_AiProviderIconUrlForFile("icons/ai/" . pid . ext)
        if (u != "" && !CommandPalette_UrlInList(urls, u))
            urls.Push(u)
        u := CommandPalette_AiProviderIconUrlForFile("icons/app/" . pid . ext)
        if (u != "" && !CommandPalette_UrlInList(urls, u))
            urls.Push(u)
    }
    fb := CommandPalette_AiProviderIconUrlForFile("icons/app/chat-ai-fallback.svg")
    if (fb != "" && !CommandPalette_UrlInList(urls, fb))
        urls.Push(fb)
    if (urls.Length = 0)
        urls.Push("https://app.local/assets/icons/app/chat-ai-fallback.svg")
    return urls
}

CommandPalette_UrlInList(urls, u) {
    for _, x in urls {
        if (x = u)
            return true
    }
    return false
}

CommandPalette_CoerceToMap(obj) {
    if (obj is Map)
        return obj
    if !IsObject(obj)
        return Map()
    out := Map()
    try {
        for k, v in obj
            out[String(k)] := v
    } catch {
    }
    return out
}

CommandPalette_MarkKeyedFromApiKeys(keyed, apiKeys) {
    if !(keyed is Map)
        return
    apiKeys := CommandPalette_CoerceToMap(apiKeys)
    for k, v in apiKeys {
        pk := CommandPalette_NormalizeAiProvider(k)
        vk := Trim(String(v))
        if FuncExists("UserStudio_NormalizeApiKey")
            try vk := UserStudio_NormalizeApiKey(v)
            catch {
            }
        if (pk != "" && vk != "")
            keyed[pk] := true
    }
}

CommandPalette_FillKeyedFromLlmRaw(keyed, raw) {
    active := ""
    if !(keyed is Map) || Trim(String(raw)) = ""
        return active
    if RegExMatch(raw, 'i)"apiKeys"\s*:\s*\{([^{}]*)\}', &blk) {
        block := blk[1]
        pos := 1
        while RegExMatch(block, '"([a-zA-Z0-9_]+)"\s*:\s*"([^"]+)"', &m, pos) {
            pk := CommandPalette_NormalizeAiProvider(m[1])
            vk := Trim(String(m[2]))
            if (pk != "" && vk != "")
                keyed[pk] := true
            pos := m.Pos + m.Len
        }
    }
    if RegExMatch(raw, 'i)"provider"\s*:\s*"([a-zA-Z0-9_]+)"', &prov)
        active := CommandPalette_NormalizeAiProvider(prov[1])
    return active
}

CommandPalette_ReadNiumaLlmSyncMap() {
    paths := []
    if FuncExists("Nmer_NiumaChatLlmPath")
        paths.Push(Nmer_NiumaChatLlmPath())
    paths.Push(A_ScriptDir . "\local\niuma_chat_llm.json")
    paths.Push(A_ScriptDir . "\config\niuma_chat_llm.json")
    for _, path in paths {
        if (path = "" || !FileExist(path))
            continue
        try {
            raw := FileRead(path, "UTF-8")
            if (SubStr(raw, 1, 1) = Chr(0xFEFF))
                raw := SubStr(raw, 2)
            parsed := Jxon_Load(raw)
            if (parsed is Map) && (parsed.Has("apiKeys") || parsed.Has("llm") || parsed.Count > 0)
                return Map("sync", parsed, "raw", raw)
            keyedProbe := Map()
            CommandPalette_FillKeyedFromLlmRaw(keyedProbe, raw)
            if (keyedProbe.Count > 0)
                return Map("sync", Map("apiKeys", keyedProbe, "llm", Map("provider", "")), "raw", raw)
        } catch {
        }
    }
    return Map("sync", 0, "raw", "")
}

CommandPalette_BootstrapNiumaChat(reason := "", openDrawer := false) {
    global AppearanceActivationMode, ConfigFile, g_FTB_PendingOpenNiumaDrawer, g_FTB_NiumaHandoffOpening
    global FloatingToolbarGUI, g_FTB_WV2, g_FTB_WaitingUiFinishedReveal, g_FTB_UI_Ready

    openDrawer := !!openDrawer
    CommandPalette_AiLog("bootstrap_begin", "reason=" . Trim(String(reason)) . " openDrawer=" . (openDrawer ? 1 : 0) . " | " . CommandPalette_AiStateSnapshot())

    if openDrawer {
        g_FTB_PendingOpenNiumaDrawer := true
        g_FTB_NiumaHandoffOpening := true
    }

    ; S10 shell 模式：跳过 AHK WebView 创建/反复 SurfaceIntent，仅确保 Wails FTB shell
    if FuncExists("FloatingToolbar_AhkWebViewEnabled") && !FloatingToolbar_AhkWebViewEnabled() {
        if FuncExists("FloatingToolbarWails_EnsureShellForAgent")
            try FloatingToolbarWails_EnsureShellForAgent(false)
            catch {
            }
        else if FuncExists("FloatingToolbarRouter_Show")
            try FloatingToolbarRouter_Show(Map("reason", "cmdpal_bootstrap", "soft", true))
            catch {
            }
        if openDrawer {
            if FuncExists("FloatingToolbar_ScheduleNiumaDrawerOpen")
                try FloatingToolbar_ScheduleNiumaDrawerOpen(100)
                catch {
                }
            CommandPalette_ForceOpenNiumaDrawer()
        }
        CommandPalette_AiLog("bootstrap_end", "shell_mode reason=" . Trim(String(reason)))
        return
    }

    mode := CommandPalette_ResolveActivationMode()

    if (mode != "toolbar") {
        CommandPalette_AiLog("bootstrap_switch_mode", "from=" . mode . " to=toolbar via=" . (FuncExists("GDHO_OpenNiumaChatFromLauncher") ? "GDHO" : "ApplyAppearance"))
        if FuncExists("GDHO_OpenNiumaChatFromLauncher") {
            try GDHO_OpenNiumaChatFromLauncher()
            catch as eGdho {
                CommandPalette_AiLog("bootstrap_gdho_err", eGdho.Message)
            }
        } else {
            AppearanceActivationMode := "toolbar"
            try IniWrite("toolbar", ConfigFile, "Appearance", "ActivationMode")
            catch {
            }
            if FuncExists("GDHO_ForceApplyAppearanceMode") {
                try GDHO_ForceApplyAppearanceMode("toolbar")
                catch {
                }
            } else if FuncExists("ApplyAppearanceActivationMode") {
                try ApplyAppearanceActivationMode()
                catch {
                }
            }
        }
    }

    if FuncExists("FloatingToolbar_ClearOverlaySuppression")
        try FloatingToolbar_ClearOverlaySuppression()
        catch {
        }
    if FuncExists("StartWebViewWarmup")
        try StartWebViewWarmup()
        catch {
        }
    if FuncExists("WebView2_InitSharedEnvAsync")
        try WebView2_InitSharedEnvAsync()
        catch {
        }

    if (FloatingToolbarGUI = 0) {
        CommandPalette_AiLog("bootstrap_create_gui", "CreateFloatingToolbarGUI")
        if FuncExists("CreateFloatingToolbarGUI")
            try CreateFloatingToolbarGUI()
            catch as eGui {
                CommandPalette_AiLog("bootstrap_create_gui_err", eGui.Message)
            }
    } else if !IsObject(g_FTB_WV2) {
        CommandPalette_AiLog("bootstrap_retry_wv2", "FloatingToolbar_RetryCreateWebView")
        if FuncExists("FloatingToolbar_RetryCreateWebView")
            try FloatingToolbar_RetryCreateWebView()
            catch as eWv {
                CommandPalette_AiLog("bootstrap_retry_wv2_err", eWv.Message)
            }
    }

    if FuncExists("FloatingToolbar_ShowForActivationMode")
        try FloatingToolbar_ShowForActivationMode()
        catch {
        }
    if FuncExists("SurfaceIntent_Open")
        try SurfaceIntent_Open("floating_toolbar", Map("reason", "cmdpal_bootstrap"))
        catch {
        }
    else if FuncExists("ShowFloatingToolbar")
        try ShowFloatingToolbar()
        catch {
        }

    if (g_FTB_WaitingUiFinishedReveal && g_FTB_UI_Ready) {
        if FuncExists("FloatingToolbar_FinishReveal")
            try FloatingToolbar_FinishReveal()
            catch {
            }
    } else if (g_FTB_WaitingUiFinishedReveal && FuncExists("FloatingToolbar_ForceRevealIfStuck")) {
        SetTimer(FloatingToolbar_ForceRevealIfStuck, -1)
    }

    if openDrawer {
        if FuncExists("FloatingToolbar_ScheduleNiumaDrawerOpen")
            try FloatingToolbar_ScheduleNiumaDrawerOpen(100)
            catch {
            }
        if FuncExists("GDHO_NiumaDrawerOpenPump") {
            SetTimer(GDHO_NiumaDrawerOpenPump, -120)
            SetTimer(GDHO_NiumaDrawerOpenPump, -480)
            SetTimer(GDHO_NiumaDrawerOpenPump, -1100)
        }
        CommandPalette_ForceOpenNiumaDrawer()
    }
    CommandPalette_AiLog("bootstrap_end", CommandPalette_AiStateSnapshot())
}

CommandPalette_BeginNiumaChatHandoff() {
    CommandPalette_BootstrapNiumaChat("handoff", true)
}

CommandPalette_ApplyLiveAiKeys(apiKeys, activeProvider := "") {
    global g_CmdPal_LiveAiKeys, g_CmdPal_LiveActiveProvider
    if !(apiKeys is Map)
        return
    if !IsObject(g_CmdPal_LiveAiKeys)
        g_CmdPal_LiveAiKeys := Map()
    for k, v in apiKeys {
        pk := CommandPalette_NormalizeAiProvider(k)
        vk := Trim(String(v))
        if (pk != "" && vk != "")
            g_CmdPal_LiveAiKeys[pk] := vk
    }
    ap := CommandPalette_NormalizeAiProvider(activeProvider)
    if (ap != "")
        g_CmdPal_LiveActiveProvider := ap
}

CommandPalette_PullLiveKeysFromFtb() {
    if FuncExists("CommandPalette_FtbTransportMode") && (CommandPalette_FtbTransportMode() = "")
        return false
    try {
        CommandPalette_DeliverFtbPayload(Map("type", "host_request_palette_ai_keys"))
        return true
    } catch as eReq {
        CommandPalette_AiLog("ai_keys_post_err", eReq.Message)
        return false
    }
}

CommandPalette_RequestFtbLlmExport(prov, reqId := "") {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return false
    prov := CommandPalette_NormalizeAiProvider(prov)
    try {
        CommandPalette_DeliverFtbPayload(Map(
            "type", "host_request_palette_ai_llm",
            "provider", prov,
            "reqId", String(reqId)
        ))
        return true
    } catch as eLlm {
        CommandPalette_AiLog("ai_llm_export_err", eLlm.Message)
        return false
    }
}

; 仅刷新命令面板模型列表；并从 Niuma Chat 内存同步密钥（抽屉可关闭）。
CommandPalette_RefreshAiProviders() {
    CommandPalette_PushAiProviders()
    CommandPalette_PullLiveKeysFromFtb()
}

CommandPalette_RequestLiveAiKeysFromNiumaChat(*) {
    CommandPalette_RefreshAiProviders()
}

CommandPalette_OnNiumaPaletteAiKeys(msg) {
    if !(msg is Map)
        return
    apiKeys := msg.Has("apiKeys") ? CommandPalette_CoerceToMap(msg["apiKeys"]) : Map()
    active := msg.Has("activeProvider") ? msg["activeProvider"] : ""
    keyN := 0
    try keyN := apiKeys.Count
    catch {
    }
    CommandPalette_AiLog("ai_keys_received", "active=" . String(active) . " keyCount=" . keyN)
    CommandPalette_ApplyLiveAiKeys(apiKeys, active)
    CommandPalette_PushAiProviders()
}

CommandPalette_OnNiumaPaletteAiLlm(msg) {
    global g_CmdPal_LiveLlmFromFtb
    if !(msg is Map)
        return
    llmIn := (msg.Has("llm") && msg["llm"] is Map) ? msg["llm"] : msg
    prov := CommandPalette_NormalizeAiProvider(llmIn.Get("provider", msg.Get("provider", "")))
    if (prov = "")
        return
    if !IsObject(g_CmdPal_LiveLlmFromFtb)
        g_CmdPal_LiveLlmFromFtb := Map()
    g_CmdPal_LiveLlmFromFtb[prov] := Map(
        "provider", prov,
        "apiKey", Trim(String(llmIn.Get("apiKey", ""))),
        "baseUrl", Trim(String(llmIn.Get("baseUrl", ""))),
        "model", Trim(String(llmIn.Get("model", "")))
    )
    CommandPalette_AiLog("ai_llm_from_ftb", "prov=" . prov
        . " base=" . SubStr(String(llmIn.Get("baseUrl", "")), 1, 56)
        . " model=" . String(llmIn.Get("model", ""))
        . " keyLen=" . StrLen(Trim(String(llmIn.Get("apiKey", "")))))
}

CommandPalette_BuildAiProviderList() {
    global g_CmdPal_LiveAiKeys, g_CmdPal_LiveActiveProvider
    labels := CommandPalette_AiProviderLabels()
    ; 与 FloatingToolbarStrip PROVIDER_PICK_ORDER 一致
    order := [
        "openai", "kimi", "qwen", "deepseek", "claude", "gemini", "glm", "siliconflow", "minimax", "zhipu",
        "ollama", "openclaw",
        "codex_cli", "gemini_cli", "openclaw_cli", "qwen_cli", "ollama_cli",
        "claude_cli", "deepseek_cli", "kimi_cli", "zhipu_cli", "copilot_cli", "studio_cli"
    ]
    keyed := Map()
    active := CommandPalette_NormalizeAiProvider(g_CmdPal_LiveActiveProvider)
    bundle := CommandPalette_ReadNiumaLlmSyncMap()
    rawLlm := bundle.Has("raw") ? String(bundle["raw"]) : ""
    sync := bundle.Has("sync") ? bundle["sync"] : 0
    if (sync is Map) {
        try {
            llmIn := sync.Has("llm") && sync["llm"] is Map ? sync["llm"] : sync
            if (active = "")
                active := CommandPalette_NormalizeAiProvider(llmIn.Get("provider", ""))
            if sync.Has("apiKeys")
                CommandPalette_MarkKeyedFromApiKeys(keyed, sync["apiKeys"])
            key := Trim(String(llmIn.Get("apiKey", "")))
            if FuncExists("UserStudio_NormalizeApiKey")
                try key := UserStudio_NormalizeApiKey(key)
                catch {
                }
            if (active != "" && key != "")
                keyed[active] := true
        } catch {
        }
    }
    if (rawLlm != "") {
        fromRaw := CommandPalette_FillKeyedFromLlmRaw(keyed, rawLlm)
        if (active = "" && fromRaw != "")
            active := fromRaw
    }
    if IsObject(g_CmdPal_LiveAiKeys) {
        for pk, vk in g_CmdPal_LiveAiKeys {
            if (Trim(String(vk)) != "")
                keyed[pk] := true
        }
    }
    if FuncExists("UserStudio_Load") {
        try {
            doc := UserStudio_Load()
            if (doc.Has("llm") && doc["llm"] is Map) {
                lp := CommandPalette_NormalizeAiProvider(doc["llm"].Get("provider", ""))
                if (active = "" && lp != "")
                    active := lp
                lk := Trim(String(doc["llm"].Get("apiKey", "")))
                if (lp != "" && lk != "")
                    keyed[lp] := true
            }
            if (doc.Has("options") && doc["options"] is Map && doc["options"].Has("llmApiKeys") && doc["options"]["llmApiKeys"] is Map) {
                for k, v in doc["options"]["llmApiKeys"] {
                    pk := CommandPalette_NormalizeAiProvider(k)
                    if (pk != "" && Trim(String(v)) != "")
                        keyed[pk] := true
                }
            }
        } catch {
        }
    }
    items := []
    seen := Map()
    addIds := []
    if (active != "")
        addIds.Push(Map("id", active, "configured", keyed.Has(active)))
    for _, id in order {
        if keyed.Has(id)
            addIds.Push(Map("id", id, "configured", true))
    }
    for id, _ in keyed
        addIds.Push(Map("id", id, "configured", true))
    for _, id in order
        addIds.Push(Map("id", id, "configured", keyed.Has(id)))
    if (addIds.Length = 0) {
        for _, id in ["deepseek", "kimi", "openai", "gemini", "minimax"]
            addIds.Push(Map("id", id, "configured", keyed.Has(id)))
    }
    for _, row in addIds {
        id := CommandPalette_NormalizeAiProvider(row["id"])
        if (id = "" || seen.Has(id))
            continue
        seen[id] := true
        cfg := keyed.Has(id)
        lbl := labels.Has(id) ? labels[id] : id
        desc := cfg ? "已配置 API · Enter 发送" : "未配置 Key（可在 Niuma Chat 设置）"
        iconKey := CommandPalette_AiProviderIconKey(id)
        items.Push(Map(
            "id", id,
            "kind", "ai_provider",
            "label", lbl,
            "desc", desc,
            "configured", cfg ? 1 : 0,
            "active", (id = active) ? 1 : 0,
            "icon", iconKey,
            "iconSrc", CommandPalette_ResolveProviderIconSrc(id),
            "iconUrls", CommandPalette_AiProviderIconUrls(id)
        ))
    }
    return Map("items", items, "activeProvider", active)
}

CommandPalette_PushAiProviders() {
    data := CommandPalette_BuildAiProviderList()
    CommandPalette_PushToWeb(Map(
        "type", "palette_ai_providers",
        "items", data["items"],
        "activeProvider", data["activeProvider"]
    ))
}

CommandPalette_EnsureFloatingToolbarForAi() {
    CommandPalette_BootstrapNiumaChat("ensure_ftb", true)
}

CommandPalette_StageNiumaCompose(query, provider := "", sendNow := true) {
    global g_FTB_PendingNiumaCompose, g_FTB_PendingOpenNiumaDrawer
    q := Trim(String(query))
    if (q = "")
        return false
    prov := CommandPalette_NormalizeAiProvider(provider)
    g_FTB_PendingOpenNiumaDrawer := true
    preview := SubStr(q, 1, 48)
    if (StrLen(q) > 48)
        preview .= "…"
    payload := Map(
        "type", "niuma_compose_send",
        "text", q,
        "send", !!sendNow,
        "append", false,
        "openDrawer", true
    )
    if (prov != "")
        payload["provider"] := prov
    if !(g_FTB_PendingNiumaCompose is Array)
        g_FTB_PendingNiumaCompose := []
    for _, existing in g_FTB_PendingNiumaCompose {
        if !(existing is Map)
            continue
        exProv := existing.Has("provider") ? CommandPalette_NormalizeAiProvider(existing["provider"]) : ""
        if (String(existing.Get("text", "")) = q && exProv = prov)
            return true
    }
    g_FTB_PendingNiumaCompose.Push(payload)
    pendN := g_FTB_PendingNiumaCompose.Length
    CommandPalette_AiLog("compose_staged", "provider=" . prov . " send=" . (sendNow ? 1 : 0) . " text=" . preview . " queueLen=" . pendN . " | " . CommandPalette_AiStateSnapshot())
    return true
}

CommandPalette_TrySendToNiumaChat(query, provider := "", sendNow := true) {
    prov := CommandPalette_NormalizeAiProvider(provider)
    global g_FTB_WV2
    if !IsObject(g_FTB_WV2) {
        CommandPalette_AiLog("compose_send_skip", "reason=no_wv2 provider=" . prov)
        return false
    }
    if FuncExists("FloatingToolbar_SendTextToNiumaChat") {
        try {
            ok := false
            if (prov != "")
                ok := !!FloatingToolbar_SendTextToNiumaChat(query, sendNow, false, true, prov)
            else
                ok := !!FloatingToolbar_SendTextToNiumaChat(query, sendNow, false, true)
            CommandPalette_AiLog("compose_send", "ok=" . (ok ? 1 : 0) . " provider=" . prov . " | " . CommandPalette_AiStateSnapshot())
            return ok
        } catch as eSend {
            CommandPalette_AiLog("compose_send_err", eSend.Message)
        }
    }
    return false
}

; 旧路径：托盘/外部仍可能调用；命令面板 palette_ai_send 已改走流式会话。
CommandPalette_QueuePendingAiSend(query, provider := "") {
    global g_CmdPal_PendingAiSend
    g_CmdPal_PendingAiSend := Map(
        "query", Trim(String(query)),
        "provider", CommandPalette_NormalizeAiProvider(provider),
        "tries", 0
    )
    SetTimer(CommandPalette_FlushPendingAiSend, -280)
}

CommandPalette_FlushPendingAiSend(*) {
    global g_CmdPal_PendingAiSend, g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    if !(g_CmdPal_PendingAiSend is Map)
        return
    q := Trim(String(g_CmdPal_PendingAiSend.Get("query", "")))
    prov := CommandPalette_NormalizeAiProvider(g_CmdPal_PendingAiSend.Get("provider", ""))
    if (q = "") {
        g_CmdPal_PendingAiSend := 0
        return
    }
    tries := Integer(g_CmdPal_PendingAiSend.Get("tries", 0))
    preview := SubStr(q, 1, 40)
    if (StrLen(q) > 40)
        preview .= "…"
    CommandPalette_AiLog("flush_tick", "try=" . tries . " provider=" . prov . " text=" . preview . " | " . CommandPalette_AiStateSnapshot())
    CommandPalette_BootstrapNiumaChat("flush_try=" . tries, true)
    global FloatingToolbarChatDrawerOpen
    if IsObject(g_FTB_WV2) {
        sent := false
        if (g_FTB_WV2_Ready && g_FTB_WV2_FrameReady) {
            CommandPalette_ForceOpenNiumaDrawer()
            sent := CommandPalette_TrySendToNiumaChat(q, prov, true)
        } else {
            CommandPalette_StageNiumaCompose(q, prov, true)
        }
        if (g_FTB_WV2_Ready && g_FTB_WV2_FrameReady) {
            if FuncExists("FloatingToolbar_FlushPendingNiumaComposeIfReady")
                try FloatingToolbar_FlushPendingNiumaComposeIfReady()
                catch as eFlush {
                    CommandPalette_AiLog("compose_flush_err", eFlush.Message)
                }
            if (FloatingToolbarChatDrawerOpen || sent) {
                CommandPalette_AiLog("flush_ok", "provider=" . prov . " sent=" . (sent ? 1 : 0) . " | " . CommandPalette_AiStateSnapshot())
                g_CmdPal_PendingAiSend := 0
                return
            }
            CommandPalette_AiLog("flush_incomplete", "drawer closed sent=" . (sent ? 1 : 0) . " | " . CommandPalette_AiStateSnapshot())
        } else {
            CommandPalette_AiLog("flush_wait_ready", "wv2=1 ready=" . (g_FTB_WV2_Ready ? 1 : 0) . " frame=" . (g_FTB_WV2_FrameReady ? 1 : 0))
        }
    } else {
        CommandPalette_StageNiumaCompose(q, prov, true)
        CommandPalette_AiLog("flush_wait_wv2", "staged compose until WebView2 exists")
    }
    if (tries >= 72) {
        g_CmdPal_PendingAiSend := 0
        CommandPalette_AiLog("flush_fail", "timeout after 72 tries | " . CommandPalette_AiStateSnapshot())
        try TrayTip("命令面板", "无法自动打开 Niuma Chat：请查看 Cache\debug\command_palette_ai.log", "Icon!")
        catch {
        }
        return
    }
    g_CmdPal_PendingAiSend["tries"] := tries + 1
    delay := tries < 12 ? 320 : (tries < 30 ? 480 : 620)
    SetTimer(CommandPalette_FlushPendingAiSend, -delay)
}

CommandPalette_HandleAiSend(query, provider := "") {
    global g_CmdPal_AiSession, g_CmdPal_AiStreamGen
    q := Trim(String(query))
    prov := CommandPalette_NormalizeAiProvider(provider)
    if (q = "")
        return
    if (prov = "") {
        data := CommandPalette_BuildAiProviderList()
        prov := CommandPalette_NormalizeAiProvider(data.Get("activeProvider", ""))
    }
    oldReqId := (g_CmdPal_AiSession is Map) ? String(g_CmdPal_AiSession.Get("reqId", "")) : ""
    CommandPalette_StopAiStreamSideEffects(oldReqId)
    if (g_CmdPal_AiSession is Map) && !g_CmdPal_AiSession.Get("ended", false)
        g_CmdPal_AiSession := 0
    g_CmdPal_AiStreamGen++
    gen := g_CmdPal_AiStreamGen
    reqId := "cpai_" . A_TickCount
    g_CmdPal_AiSession := Map(
        "reqId", reqId,
        "query", q,
        "provider", prov,
        "gen", gen,
        "handoff", false,
        "ended", false,
        "answer", "",
        "chunkCount", 0,
        "webChunkCount", 0,
        "webAnswerChunks", 0,
        "directStarted", false,
        "ftbDispatched", false
    )
    preview := SubStr(q, 1, 60)
    if (StrLen(q) > 60)
        preview .= "…"
    logPath := FuncExists("Nmer_DebugPath") ? Nmer_DebugPath("command_palette_ai.log") : (A_ScriptDir . "\Cache\debug\command_palette_ai.log")
    CommandPalette_AiLog("ai_send_begin", "reqId=" . reqId . " provider=" . prov . " text=" . preview . " log=" . logPath)
    CommandPalette_PushToWeb(Map("type", "palette_ai_status", "message", "正在同步 Niuma 配置…", "status", "loading", "reqId", reqId))
    CommandPalette_EnsureFtbEngineForAi()
    SetTimer(CommandPalette_AiSendAfterFtbSync.Bind(reqId, q, prov, gen), -80)
}

CommandPalette_AiSendAfterFtbSync(reqId, q, prov, gen) {
    global g_CmdPal_AiSession, g_CmdPal_AiStreamGen
    if !(g_CmdPal_AiSession is Map) || Trim(String(g_CmdPal_AiSession.Get("reqId", ""))) != Trim(String(reqId))
        return
    if Integer(g_CmdPal_AiSession.Get("gen", 0)) != Integer(gen)
        return
    CommandPalette_SyncFtbContextForPalette(prov, reqId)
    CommandPalette_DispatchPaletteAiStream(reqId, q, prov, gen, 0)
}

CommandPalette_FlushPendingAiSendIfReady() {
    global g_CmdPal_PendingAiSend
    if !(g_CmdPal_PendingAiSend is Map)
        return
    SetTimer(CommandPalette_FlushPendingAiSend, -120)
}

; 命令面板可见时 Esc 关闭（WebView 未收到按键时由宿主兜底）
#HotIf CommandPalette_IsVisible()
^+f:: {
    try {
        if FuncExists("SurfaceIntent_Dispose")
            SurfaceIntent_Dispose("floating_toolbar", Map("reason", "hotkey_dispose_ftb"))
        else if FuncExists("SurfaceDisposeProbe_TryExecute")
            SurfaceDisposeProbe_TryExecute("dev_surface_dispose_ftb")
    } catch as e {
        try TrayTip("Surface 探针", e.Message, "Iconx 2")
        catch {
        }
    }
}
^+r:: {
    try {
        if FuncExists("SurfaceIntent_Open")
            SurfaceIntent_Open("floating_toolbar", Map("reason", "hotkey_restore_ftb"))
        else if FuncExists("SurfaceDisposeProbe_TryExecute")
            SurfaceDisposeProbe_TryExecute("dev_surface_restore_ftb")
    } catch as e {
        try TrayTip("Surface 探针", e.Message, "Iconx 2")
        catch {
        }
    }
}
Esc:: {
    if FuncExists("CommandPalette_IsAgentRunning") && CommandPalette_IsAgentRunning() {
        if FuncExists("CommandPalette_AgentCancel")
            CommandPalette_AgentCancel("")
        return
    }
    if CommandPalette_IsAiStreaming()
        CommandPalette_HandoffAiToToolbar(false)
    CommandPalette_Hide()
}
#HotIf
