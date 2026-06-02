; ======================================================================================================================
; 閹剚璇炲銉ュ徔閺?- WebView2 閸忋劑鍣洪柌宥嗙€悧?; 閻楀牊婀? 2.0.0
; 閸旂喕鍏?
;   - 閺佸瓨娼銉ュ徔閺嶅繒鏁遍崡鏇氶嚋 WebView2 濞撳弶鐓嬮敍宀€绮烘稉鈧挧娑樺触缂?濮楁瑩鍘ら懝?;   - 瀹革箓鏁幏鏍уЗ閺佸鐛ラ妴浣圭泊鏉烆喚缂夐弨淇扁偓浣稿礁闁款喛褰嶉崡?;   - 7 娑擃亜濮涢懗鑺ュ瘻闁筋噯绱伴幖婊呭偍閵嗕浇顔囪ぐ鏇樷偓浣瑰絹缁€楦跨槤閵嗕焦鏌婇幓鎰仛鐠囧秲鈧焦鍩呴崶淇扁偓浣筋啎缂冾喓鈧線鏁惄?;   - 閹兼粎鍌ㄩ幐澶愭尦閺€顖涘瘮闁灏幇鐔风安閸涚厧鎯涢崝銊ф暰閸滃本瀚嬮弨鐐偝缁?; ======================================================================================================================

#Requires AutoHotkey v2.0
#Include NiumaMobileBrowser.ahk
#Include GroundingCache.ahk

; 虚拟屏幕边界（SysGet 76–79）
ScreenVirtual_GetBounds(&outL, &outT, &outW, &outH) {
    outL := SysGet(76)
    outT := SysGet(77)
    outW := SysGet(78)
    outH := SysGet(79)
}

; 工作区（排除任务栏）；可选 hwnd 以定位到窗口所在显示器
ScreenWorkArea_GetBounds(&outL, &outT, &outW, &outH, hwnd := 0) {
    mon := 1
    if hwnd {
        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
            mon := MonitorGet(wx + (ww // 2), wy + (wh // 2))
        } catch {
            mon := 1
        }
    }
    try MonitorGetWorkArea(mon, &l, &t, &r, &b)
    catch {
        ScreenVirtual_GetBounds(&outL, &outT, &outW, &outH)
        return
    }
    outL := l
    outT := t
    outW := Max(0, r - l)
    outH := Max(0, b - t)
}

; NiuMa Chat 抽屉底部安全边距（工作区已排除任务栏，此处仅留视觉间隙）
FloatingToolbar_ChatDrawerBottomMarginPx(hwnd := 0) {
    return Max(12, Round(14 * FloatingToolbar_DpiFactor()))
}

FloatingToolbar_ChatDrawerHeightPx(hwnd := 0) {
    ScreenWorkArea_GetBounds(&wl, &wt, &ww, &wh, hwnd)
    margin := FloatingToolbar_ChatDrawerBottomMarginPx(hwnd)
    h := wh - margin
    if (h < 320)
        h := 320
    return h
}

FloatingToolbar_ClampWindowToWorkArea(&x, &y, w, h, hwnd := 0) {
    ScreenWorkArea_GetBounds(&wl, &wt, &ww, &wh, hwnd)
    wr := wl + ww
    wb := wt + wh
    if (x < wl)
        x := wl
    if (y < wt)
        y := wt
    if (x + w > wr)
        x := wr - w
    if (y + h > wb)
        y := wb - h
    if (x < wl)
        x := wl
    if (y < wt)
        y := wt
}

FloatingToolbar_EnsureDrawerInWorkArea() {
    global FloatingToolbarGUI, FloatingToolbarChatDrawerOpen, FloatingToolbarWindowX, FloatingToolbarWindowY
    if (!FloatingToolbarGUI || !FloatingToolbarChatDrawerOpen)
        return
    ftHwnd := FloatingToolbarGUI.Hwnd
    newW := FloatingToolbarCalculateWidth()
    newH := FloatingToolbarCalculateHeight()
    try FloatingToolbarGUI.GetPos(&x, &y, , )
    catch {
        x := FloatingToolbarWindowX
        y := FloatingToolbarWindowY
    }
    FloatingToolbar_ClampWindowToWorkArea(&x, &y, newW, newH, ftHwnd)
    FloatingToolbarWindowX := x
    FloatingToolbarWindowY := y
    try FloatingToolbarGUI.Move(x, y, newW, newH)
    catch {
    }
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
    FloatingToolbar_PushWorkAreaInsetsToWeb()
}

FloatingToolbar_PushWorkAreaInsetsToWeb() {
    global g_FTB_WV2, FloatingToolbarChatDrawerOpen
    if !(g_FTB_WV2 && FloatingToolbarChatDrawerOpen)
        return
    cssPad := Max(4, Round(6 * FloatingToolbar_DpiFactor()))
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "host_work_area_insets", "bottom", cssPad))
    catch {
    }
}

; 与系统显示缩放（100%=96DPI）对齐，配合 -DPIScale 的物理像素窗体
FloatingToolbar_DpiFactor() {
    d := A_ScreenDPI
    if d < 1
        d := 96
    return d / 96.0
}

; 用户 INI 中的 Scale 与系统 DPI 复合后的有效倍率，用于窗体与 WebView 内 --ui
FloatingToolbar_EffectiveScaleFromUser(userScale) {
    global FloatingToolbarMinScale, FloatingToolbarMaxScale
    eff := Float(userScale) * FloatingToolbar_DpiFactor()
    if (eff < FloatingToolbarMinScale)
        eff := FloatingToolbarMinScale
    if (eff > FloatingToolbarMaxScale)
        eff := FloatingToolbarMaxScale
    return eff
}

FloatingToolbar_EffectiveScale() {
    global FloatingToolbarScale
    return FloatingToolbar_EffectiveScaleFromUser(FloatingToolbarScale)
}

; 宿主脚本 CursorHelper 中定义；经 Func 转发，避免本文件单独分析时误报未赋值局部变量
FloatingToolbar_NormalizeAppearanceMode(v) {
    s := Trim(String(v))
    try {
        r := Trim(String(Func("NormalizeAppearanceActivationMode").Call(v)))
        if (r = "bubble" || r = "hole" || r = "tray" || r = "toolbar")
            return r
    } catch {
    }
    if (s = "bubble" || s = "hole" || s = "tray" || s = "toolbar")
        return s
    return "toolbar"
}

FloatingToolbar_NotifyWebViewShown(wv2) {
    if !wv2
        return
    try Func("WebView2_NotifyShown").Call(wv2)
    catch {
    }
}

FloatingToolbar_NotifyWebViewHidden(wv2) {
    if !wv2
        return
    try Func("WebView2_NotifyHidden").Call(wv2)
    catch {
    }
}

; 无 INI 时默认抽屉「逻辑宽」（三栏：52+200+主区），随高 DPI 略增、并限制在 560–1000
FloatingToolbar_ChatDrawerDefaultWidth() {
    return Min(1000, Max(560, Round(780 * FloatingToolbar_DpiFactor())))
}

; ===================== 閸忋劌鐪崣姗€鍣?=====================
global FloatingToolbarGUI := 0
global FloatingToolbarIsVisible := false
global FloatingToolbarWindowX := 0
global FloatingToolbarWindowY := 0
global FloatingToolbarScale := 1.0
global FloatingToolbarMinScale := 0.85
global FloatingToolbarMaxScale := 2.0
global FloatingToolbarCompactDiameter := 62
global g_FTB_ModeTransitionBusy := false
global g_FTB_BubbleHandoffMs := 420
global g_FTB_ModeFadeMs := 280
global g_FTB_CrossfadeMs := 340
global FloatingToolbarDragging := false
global FloatingToolbar_DragOriginScreenX := 0
global FloatingToolbar_DragOriginScreenY := 0
global FloatingToolbar_DragOriginWinX := 0
global FloatingToolbar_DragOriginWinY := 0
global FloatingToolbar_DragStartTick := 0
global FloatingToolbar_DragMaxMs := 8000
global FloatingToolbarIsMinimized := false
global FloatingToolbarChatDrawerOpen := false
global FloatingToolbarChatDrawerWidth := 780
global FloatingToolbarChatDrawerHeight := 720
global FloatingToolbarCmdVisibleCount := 7
global FloatingToolbarMaxVisibleIcons := 9
global FloatingToolbarLastClosedX := 0
global FloatingToolbarLastClosedY := 0
global g_FTB_BlockedCmdIds := Map("ch_t", true, "pqp_capture", true, "ss_menu", true)
global g_FTB_AllowedCmdIds := Map(
    "sc_activate_search", true,
    "qa_clipboard", true,
    "ch_b", true,
    "hub_capsule", true,
    "ftb_scratchpad", true,
    "ftb_screenshot", true,
    "ftb_cloud_player", true,
    "qa_config", true,
    "sys_show_vk", true,
    "ftb_cursor_menu", true
)

global g_FTB_WV2_Ctrl := 0
global g_FTB_WV2 := 0
global g_FTB_WV2_Ready := false
global g_FTB_CompatLock := false
global g_FTB_CompatQueue := []
global g_FTB_CompatLockTimestamp := 0
global g_FTB_CompatCurrentReqId := ""
global g_NiumaChatFrontReady := false
global g_NiumaChatBridgeEpoch := 0

FloatingToolbar_GetChatWv2() {
    global g_FTB_WV2
    return IsObject(g_FTB_WV2) ? g_FTB_WV2 : 0
}

FloatingToolbar_PushNodeStatus(nodeKey, status, detail := "", pingMs := 0) {
    wv2 := FloatingToolbar_GetChatWv2()
    if !wv2
        return
    try WebView_QueuePayload(wv2, Map(
        "type", "niuma_node_status",
        "nodeKey", String(nodeKey),
        "status", String(status),
        "detail", String(detail),
        "pingMs", pingMs,
        "tick", A_TickCount))
    catch {
    }
}

FloatingToolbar_PushAudit(nodeKey, message, level := "info", meta := "") {
    wv2 := FloatingToolbar_GetChatWv2()
    if !wv2
        return
    try WebView_QueuePayload(wv2, Map(
        "type", "niuma_audit_event",
        "nodeKey", String(nodeKey),
        "message", String(message),
        "level", String(level),
        "meta", String(meta),
        "tick", A_TickCount))
    catch {
    }
}

FloatingToolbar_ResetChatBridge() {
    global g_NiumaChatFrontReady, g_NiumaChatBridgeEpoch
    g_NiumaChatFrontReady := false
    g_NiumaChatBridgeEpoch += 1
    try {
        if FuncExists("NiumaMobileBrowser_Log")
            NiumaMobileBrowser_Log("HANDSHAKE", "", "reset epoch=" . g_NiumaChatBridgeEpoch)
    } catch {
    }
    try {
        if FuncExists("NiumaMobileBrowser_TraceOverlayPush")
            NiumaMobileBrowser_TraceOverlayPush("HANDSHAKE reset epoch=" . g_NiumaChatBridgeEpoch, "warn")
    } catch {
    }
}

FloatingToolbar_IsChatBridgeReady() {
    global g_NiumaChatFrontReady
    if !g_NiumaChatFrontReady
        return false
    return IsObject(FloatingToolbar_GetChatWv2())
}

FloatingToolbar_OnChatReady(msg) {
    global g_NiumaChatFrontReady, g_NiumaChatBridgeEpoch
    g_NiumaChatFrontReady := true
    epoch := msg.Has("epoch") ? String(msg["epoch"]) : ""
    try {
        if FuncExists("NiumaMobileBrowser_Log")
            NiumaMobileBrowser_Log("HANDSHAKE", "", "chat_ready received epoch=" . epoch . " bridge_epoch=" . g_NiumaChatBridgeEpoch)
    } catch {
    }
    try {
        if FuncExists("NiumaMobileBrowser_TraceOverlayPush")
            NiumaMobileBrowser_TraceOverlayPush("HANDSHAKE chat_ready epoch=" . epoch . " bridge_epoch=" . g_NiumaChatBridgeEpoch, "success")
    } catch {
    }
    try {
        if FuncExists("NiumaMobileBrowser_FlushDeferredSnapshotToChat")
            NiumaMobileBrowser_FlushDeferredSnapshotToChat()
    } catch {
    }
    wv2 := FloatingToolbar_GetChatWv2()
    if !wv2
        return
    ack := '{"type":"host_chat_bridge_ready","ok":true,"epoch":' . g_NiumaChatBridgeEpoch . '}'
    try {
        if FuncExists("NiumaMobileBrowser_PostJsonToChatDirect")
            NiumaMobileBrowser_PostJsonToChatDirect(wv2, ack, "", "host_chat_bridge_ready")
        else
            wv2.PostWebMessageAsJson(ack)
        try {
            if FuncExists("NiumaMobileBrowser_TraceOverlayPush")
                NiumaMobileBrowser_TraceOverlayPush("HANDSHAKE host_chat_bridge_ready sent epoch=" . g_NiumaChatBridgeEpoch, "success")
        } catch {
        }
    } catch as e {
        try {
            if FuncExists("NiumaMobileBrowser_Log")
                NiumaMobileBrowser_Log("HANDSHAKE", "", "host_chat_bridge_ready failed err=" . e.Message)
        } catch {
        }
        try {
            if FuncExists("NiumaMobileBrowser_TraceOverlayPush")
                NiumaMobileBrowser_TraceOverlayPush("HANDSHAKE host_chat_bridge_ready failed: " . e.Message, "err")
        } catch {
        }
    }
}
global g_FTB_WV2_FrameReady := false
global g_FTB_PendingSelection := ""
global g_FTB_PendingNiumaCompose := []
global g_FTB_PendingStudioAsk := 0
global g_FTB_PendingOpenNiumaDrawer := false
global g_FTB_NiumaHandoffOpening := false
global g_FTB_ReturnToHoleAfterNiuma := false
global g_FTB_SuspendToolbarHomeResetUntil := 0
global g_FTB_UI_Ready := false
global g_FTB_WaitingUiFinishedReveal := false
global g_FTB_ScreenshotDeferLastTick := 0  ; 闃叉姈锛歐ebView 鐭椂鍙屽彂 postMessage 浼氭帓闃熶袱娆?Deferred锛岄伩鍏嶇浜屾鍐嶈窇瀹屾暣鎴浘鍔╂墜娴佺▼
global g_FTB_WV2_CreateRetry := 0
global g_FTB_DebugOverlayEnabled := true
global g_FTB_HoleDragLastUpdateTick := 0
global g_FTB_HoleDragUpdateMinIntervalMs := 45
global g_FTB_RevealWaitStartTick := 0
; 页面底部已集成工具栏时，不再让外层悬浮条覆盖页面。
global g_FTB_OverlaySuppressedByPageDock := false
global g_FTB_PageDockActive := Map()

FloatingToolbar_CanShowOverlay() {
    global g_FTB_OverlaySuppressedByPageDock
    return !g_FTB_OverlaySuppressedByPageDock
}
FloatingToolbar_ClearOverlaySuppression() {
    global g_FTB_PageDockActive, g_FTB_OverlaySuppressedByPageDock
    g_FTB_PageDockActive := Map()
    g_FTB_OverlaySuppressedByPageDock := false
}
FloatingToolbar_PageDockEnter(tag := "") {
    global g_FTB_PageDockActive, g_FTB_OverlaySuppressedByPageDock
    t := Trim(StrLower(String(tag)))
    if (t = "")
        return
    g_FTB_PageDockActive[t] := A_TickCount
    g_FTB_OverlaySuppressedByPageDock := true
    try HideFloatingToolbar()
}

FloatingToolbar_PageDockLeave(tag := "") {
    global g_FTB_PageDockActive, g_FTB_OverlaySuppressedByPageDock
    t := Trim(StrLower(String(tag)))
    if (t != "" && g_FTB_PageDockActive.Has(t))
        g_FTB_PageDockActive.Delete(t)
    if (g_FTB_PageDockActive.Count > 0)
        return
    g_FTB_OverlaySuppressedByPageDock := false
    FloatingToolbar_RestoreAfterPageDock()
}

FloatingToolbar_RestoreAfterPageDock() {
    global AppearanceActivationMode
    mode := FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode)
    if (mode != "toolbar")
        return
    try FloatingToolbar_ClearOverlaySuppression()
    catch {
    }
    FloatingToolbar_ShowAfterPageDock()
}

; 子窗口关闭后恢复：复用已有 WebView，重置抽屉/设置叠层并重新推送图标布局。
FloatingToolbar_ShowAfterPageDock() {
    global g_FTB_WV2, g_FTB_WV2_Ready, FloatingToolbarChatDrawerOpen
    try FloatingToolbarChatDrawerOpen := false
    catch {
    }
    try ShowFloatingToolbar()
    catch {
    }
    if !(g_FTB_WV2_Ready && g_FTB_WV2)
        return
    try FloatingToolbar_NotifyWebViewShown(g_FTB_WV2)
    catch {
    }
    try FloatingToolbar_ResetWebToToolbarHome()
    catch {
    }
    try FloatingToolbarPushCmdLayoutToWeb()
    catch {
    }
    SetTimer(FloatingToolbar_PushLayoutDeferred, -10)
    SetTimer(FloatingToolbar_PushLayoutDeferred, -200)
    SetTimer(FloatingToolbar_PushLayoutDeferred, -600)
}

; 设置页/托盘切换为「悬浮栏」时统一走此入口：清 dock 抑制、显示并兜底恢复可见性。
FloatingToolbar_ShowForActivationMode() {
    global AppearanceActivationMode
    if (FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode) != "toolbar")
        return
    try FloatingToolbar_ClearOverlaySuppression()
    catch {
    }
    try ShowFloatingToolbar()
    catch {
    }
    if !FloatingToolbarIsVisible {
        SetTimer(FloatingToolbar_SoftRecoverVisible, -120)
    }
    SetTimer(FloatingToolbar_EnsureVisibleAfterActivation, -280)
    SetTimer(FloatingToolbar_EnsureVisibleAfterActivation, -900)
}

; 轻量恢复：优先 FinishReveal / 再显示；仅宿主缺失时才 ForceRecover。
FloatingToolbar_SoftRecoverVisible(*) {
    global FloatingToolbarIsVisible, FloatingToolbarGUI, g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WaitingUiFinishedReveal
    if FloatingToolbarIsVisible && !g_FTB_WaitingUiFinishedReveal
        return
    if (FloatingToolbarGUI != 0 && g_FTB_WV2_Ready && g_FTB_WV2) {
        if g_FTB_WaitingUiFinishedReveal {
            try FloatingToolbar_FinishReveal()
            catch {
            }
        } else if !FloatingToolbarIsVisible {
            try ShowFloatingToolbar()
            catch {
            }
        }
        try FloatingToolbar_NotifyWebViewShown(g_FTB_WV2)
        catch {
        }
        if !FloatingToolbar_ShouldSuppressToolbarHomeReset() {
            try FloatingToolbar_ResetWebToToolbarHome()
            catch {
            }
        }
        SetTimer(FloatingToolbar_PushLayoutDeferred, -10)
        SetTimer(FloatingToolbar_PushLayoutDeferred, -180)
        return
    }
    if (FloatingToolbarGUI != 0 && g_FTB_WV2) {
        try ShowFloatingToolbar()
        catch {
        }
        return
    }
    try FloatingToolbar_ForceRecoverVisible()
    catch {
    }
}

FloatingToolbar_IsNiumaHandoffActive() {
    global g_FTB_PendingOpenNiumaDrawer, g_FTB_NiumaHandoffOpening, FloatingToolbarChatDrawerOpen
    return !!(g_FTB_PendingOpenNiumaDrawer || g_FTB_NiumaHandoffOpening || FloatingToolbarChatDrawerOpen)
}

FloatingToolbar_ShouldSuppressToolbarHomeReset() {
    global g_FTB_SuspendToolbarHomeResetUntil
    if FloatingToolbar_IsNiumaHandoffActive()
        return true
    return (g_FTB_SuspendToolbarHomeResetUntil > 0 && A_TickCount < g_FTB_SuspendToolbarHomeResetUntil)
}

FloatingToolbar_MarkNiumaHandoffActive(ms := 3000) {
    global g_FTB_SuspendToolbarHomeResetUntil
    g_FTB_SuspendToolbarHomeResetUntil := A_TickCount + Max(800, Integer(ms))
}

FloatingToolbar_CancelToolbarRecoveryTimers() {
    try SetTimer(FloatingToolbar_EnsureVisibleAfterActivation, 0)
    catch {
    }
    try SetTimer(FloatingToolbar_SoftRecoverVisible, 0)
    catch {
    }
    try SetTimer(FloatingToolbar_RunNiumaHandoffOpen, 0)
    catch {
    }
    try SetTimer(FloatingToolbar_NiumaDrawerHandoffRetry, 0)
    catch {
    }
}

FloatingToolbar_TryReturnToHoleAfterNiuma(*) {
    global g_FTB_ReturnToHoleAfterNiuma, g_FTB_PendingOpenNiumaDrawer, g_FTB_NiumaHandoffOpening
    global AppearanceActivationMode, FloatingToolbarChatDrawerOpen, g_FTB_SuspendToolbarHomeResetUntil
    if !g_FTB_ReturnToHoleAfterNiuma
        return false
    g_FTB_ReturnToHoleAfterNiuma := false
    g_FTB_PendingOpenNiumaDrawer := false
    g_FTB_NiumaHandoffOpening := false
    g_FTB_SuspendToolbarHomeResetUntil := 0
    try FloatingToolbarChatDrawerOpen := false
    catch {
    }
    try FloatingToolbar_CancelToolbarRecoveryTimers()
    catch {
    }
    try NativeDropDiag_Log("[LauncherPick] niuma_close_restore_hole begin")
    catch {
    }
    try HideFloatingToolbar()
    catch {
    }
    if FuncExists("GDHO_PrepareDecoupledHoleForTextSelection") {
        try GDHO_PrepareDecoupledHoleForTextSelection("niuma_close_restore")
    }
    if FuncExists("GDHO_ForceApplyAppearanceMode") {
        try GDHO_ForceApplyAppearanceMode("hole")
    } else {
        AppearanceActivationMode := "hole"
        try {
            global ConfigFile
            if !IsSet(ConfigFile) || (Trim(String(ConfigFile)) = "")
                ConfigFile := Nmer_ResolveConfigFile()
            IniWrite("hole", ConfigFile, "Appearance", "ActivationMode")
        } catch {
        }
        if FuncExists("ApplyAppearanceActivationMode") {
            try ApplyAppearanceActivationMode()
        } else if FuncExists("ApplyActivationRuntimeAsync") {
            try ApplyActivationRuntimeAsync("hole")
        }
    }
    try NativeDropDiag_Log("[LauncherPick] niuma_close_restore_hole done")
    catch {
    }
    return true
}

FloatingToolbar_EnsureVisibleAfterActivation(*) {
    global AppearanceActivationMode, FloatingToolbarIsVisible, g_FTB_WaitingUiFinishedReveal
    if (FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode) != "toolbar")
        return
    if FloatingToolbarIsVisible && !g_FTB_WaitingUiFinishedReveal
        return
    try FloatingToolbar_ClearOverlaySuppression()
    catch {
    }
    if !FloatingToolbar_ShouldSuppressToolbarHomeReset() {
        try FloatingToolbar_ResetWebToToolbarHome()
        catch {
        }
    }
    if g_FTB_WaitingUiFinishedReveal {
        SetTimer(FloatingToolbar_FinishReveal, -120)
    }
    if !FloatingToolbarIsVisible {
        SetTimer(FloatingToolbar_SoftRecoverVisible, -50)
    }
}

FloatingToolbar_RequestWebReveal() {
    global g_FTB_WV2
    if !g_FTB_WV2
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "host_request_reveal"))
    catch {
    }
}

; 黑洞/启动层 handoff 打开牛马 Chat 时：禁止 host_request_reveal 把 Web 侧抽屉打回折叠条。
FloatingToolbar_RequestWebRevealSafe() {
    global g_FTB_WV2, g_FTB_PendingOpenNiumaDrawer, FloatingToolbarChatDrawerOpen
    if !g_FTB_WV2
        return
    if FloatingToolbar_ShouldSuppressToolbarHomeReset() {
        if (FloatingToolbarChatDrawerOpen || g_FTB_PendingOpenNiumaDrawer) {
            try FloatingToolbar_NotifyWebDrawerState(true)
            catch {
            }
        }
        return
    }
    try FloatingToolbar_RequestWebReveal()
    catch {
    }
}

; 收起 Niuma 抽屉/设置叠层并恢复折叠工具条（子窗口关闭、隐藏后显示时均需调用）。
FloatingToolbar_ResetWebToToolbarHome() {
    global g_FTB_WV2, FloatingToolbarChatDrawerOpen
    if FloatingToolbar_ShouldSuppressToolbarHomeReset()
        return
    try FloatingToolbarChatDrawerOpen := false
    catch {
    }
    if !g_FTB_WV2
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "host_force_toolbar_home"))
    catch {
    }
}

FloatingToolbar_EnsureCommandsLoaded() {
    global g_JsonPath, g_Commands
    if !IsSet(g_JsonPath) || g_JsonPath = ""
        g_JsonPath := Nmer_CommandsJsonPath()
    if (!IsSet(g_Commands) || !(g_Commands is Map) || !g_Commands.Has("CommandList")
        || !(g_Commands["CommandList"] is Map) || g_Commands["CommandList"].Count = 0) {
        if IsSet(_LoadCommands)
            _LoadCommands()
    }
}

FloatingToolbar_PushLayoutDeferred(*) {
    global g_FTB_WV2
    if !g_FTB_WV2
        return
    try FloatingToolbar_EnsureCommandsLoaded()
    catch {
    }
    try FloatingToolbarPushCmdLayoutToWeb()
    catch {
    }
    try FloatingToolbar_PushLogoToWeb()
    catch {
    }
    try FloatingToolbar_RequestWebRevealSafe()
    catch {
    }
}

FloatingToolbar_GetFallbackCmdIds() {
    return [
        "sc_activate_search",
        "qa_clipboard",
        "ch_b",
        "ftb_scratchpad",
        "ftb_screenshot",
        "qa_config",
        "sys_show_vk",
        "ftb_cursor_menu",
        "ftb_cloud_player"
    ]
}

FloatingToolbar_ResolveSceneCmdId(sceneId) {
    if !(IsSet(_VK_SceneIdToToolbarCmdId))
        return ""
    global g_Commands
    cid := _VK_SceneIdToToolbarCmdId(sceneId)
    if (cid != "" && IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList")
        && g_Commands["CommandList"] is Map && g_Commands["CommandList"].Has(cid))
        return cid
    if (sceneId = "scratchpad") {
        if (IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList")
            && g_Commands["CommandList"] is Map && g_Commands["CommandList"].Has("hub_capsule"))
            return "hub_capsule"
    }
    return cid
}

FloatingToolbar_CmdIdToSceneId(cmdId) {
    cid := Trim(String(cmdId))
    if (cid = "")
        return ""
    static sceneIds := ["search", "clipboard", "prompts", "scratchpad", "screenshot", "settings", "hotkeys", "cursor", "cloudplayer"]
    for sid in sceneIds {
        if (FloatingToolbar_ResolveSceneCmdId(sid) = cid)
            return sid
    }
    return ""
}

FloatingToolbar_BuildToolbarItemPayload(cid, cmdList, sceneId := "") {
    cid := Trim(String(cid))
    if (cid = "" || !(cmdList is Map) || !cmdList.Has(cid))
        return 0
    ent := cmdList[cid]
    sid := sceneId != "" ? Trim(String(sceneId)) : FloatingToolbar_CmdIdToSceneId(cid)
    nm := (ent is Map && ent.Has("name")) ? String(ent["name"]) : cid
    ic := ""
    if (sid != "" && IsSet(_VK_SceneIdToToolbarIconClass))
        ic := _VK_SceneIdToToolbarIconClass(sid)
    if (ic = "" && ent is Map && ent.Has("iconClass") && ent["iconClass"] != "") {
        ic := Trim(String(ent["iconClass"]))
        if (SubStr(ic, 1, 3) != "fa-")
            ic := "fa-solid " . ic
        else if !InStr(ic, "fa-solid") && !InStr(ic, "fa-brands") && !InStr(ic, "fa-regular")
            ic := "fa-solid " . ic
    }
    if (ic = "")
        ic := "fa-solid fa-circle"
    rowPayload := Map("cmdId", cid, "name", nm, "iconClass", ic)
    if (cid = "ftb_cursor_menu")
        rowPayload["iconPath"] := FloatingToolbar_GetCursorIconPath()
    else if (cid = "hub_capsule") {
        try {
            nu := BuildAppAssetUrl("牛马.png")
            if (nu != "")
                rowPayload["iconPath"] := nu
        } catch {
        }
    } else if ((ent is Map) && ent.Has("iconPath") && ent["iconPath"] != "")
        rowPayload["iconPath"] := String(ent["iconPath"])
    return rowPayload
}

; 按 SceneToolbarLayout：每场景至多一个 cmd，避免 ch_x/ch_f 与 qa_clipboard/sc_activate_search 等同功能重复堆叠。
FloatingToolbar_BuildItemsFromSceneToolbarLayout() {
    global g_Commands, g_FTB_BlockedCmdIds
    items := []
    if !(IsSet(g_Commands) && g_Commands is Map)
        return items
    try FloatingToolbar_EnsureCommandsLoaded()
    catch {
    }
    try {
        if IsSet(_VK_EnsureToolbarLayout)
            _VK_EnsureToolbarLayout()
    } catch {
    }
    try {
        if IsSet(_VK_SyncToolbarLayoutFromSceneToolbar)
            _VK_SyncToolbarLayoutFromSceneToolbar()
    } catch {
    }
    if !g_Commands.Has("CommandList") || !(g_Commands["CommandList"] is Map)
        return items
    cmdList := g_Commands["CommandList"]
    sceneRows := []
    if (g_Commands.Has("SceneToolbarLayout") && g_Commands["SceneToolbarLayout"] is Array) {
        for row in g_Commands["SceneToolbarLayout"]
            sceneRows.Push(row)
    }
    if (sceneRows.Length > 1 && IsSet(_VK_SortRowsByNumericKey))
        sceneRows := _VK_SortRowsByNumericKey(sceneRows, "order_bar")
    seenCids := Map()
    for row in sceneRows {
        if !(row is Map) || !row.Has("sceneId")
            continue
        if !row.Has("visible_in_bar") || !row["visible_in_bar"]
            continue
        sid := Trim(String(row["sceneId"]))
        if (sid = "" || sid = "ai")
            continue
        cid := Trim(String(FloatingToolbar_ResolveSceneCmdId(sid)))
        if (cid = "" && IsSet(_VK_SceneIdToToolbarCmdId))
            cid := Trim(String(_VK_SceneIdToToolbarCmdId(sid)))
        if (cid = "" || !cmdList.Has(cid) || g_FTB_BlockedCmdIds.Has(cid) || seenCids.Has(cid))
            continue
        seenCids[cid] := true
        rowPayload := FloatingToolbar_BuildToolbarItemPayload(cid, cmdList, sid)
        if (rowPayload is Map)
            items.Push(rowPayload)
    }
    return items
}

FloatingToolbar_BuildItemsFromCmdIds(cmdIds) {
    global g_Commands
    items := []
    try FloatingToolbar_EnsureCommandsLoaded()
    catch {
    }
    if !(IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList") && g_Commands["CommandList"] is Map)
        return items
    cmdList := g_Commands["CommandList"]
    for cid0 in cmdIds {
        cid := Trim(String(cid0))
        if (cid = "" || !cmdList.Has(cid))
            continue
        ent := cmdList[cid]
        nm := (ent is Map && ent.Has("name")) ? String(ent["name"]) : cid
        ic := "fa-circle"
        if (ent is Map) && ent.Has("iconClass") && ent["iconClass"] != "" {
            ic := Trim(String(ent["iconClass"]))
            if (SubStr(ic, 1, 3) != "fa-")
                ic := "fa-solid " . ic
            else if !InStr(ic, "fa-solid") && !InStr(ic, "fa-brands") && !InStr(ic, "fa-regular")
                ic := "fa-solid " . ic
        }
        rowPayload := Map("cmdId", cid, "name", nm, "iconClass", ic)
        if (cid = "ftb_cursor_menu") {
            rowPayload["iconPath"] := FloatingToolbar_GetCursorIconPath()
        } else if ((ent is Map) && ent.Has("iconPath") && ent["iconPath"] != "") {
            rowPayload["iconPath"] := String(ent["iconPath"])
        }
        items.Push(rowPayload)
    }
    return items
}

FloatingToolbar_PushLegacyToolbarActionsToWeb() {
    global g_FTB_WV2, FloatingToolbarButtonItems
    if !g_FTB_WV2
        return
    actions := []
    if (IsSet(FloatingToolbarButtonItems) && FloatingToolbarButtonItems is Array) {
        for a in FloatingToolbarButtonItems
            actions.Push(String(a))
    }
    if (actions.Length = 0)
        actions := ["Search", "Record", "Prompt", "NewPrompt", "Screenshot", "Settings", "VirtualKeyboard"]
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_toolbar_config", "actions", actions))
    catch {
    }
}
global g_FTB_CursorIconDataUrl := ""

FTB_Debug(msg, level := "ok") {
    global g_FTB_DebugOverlayEnabled, g_FTB_WV2
    if !g_FTB_DebugOverlayEnabled
        return
    try OutputDebug("[FTBDBG] " . msg)
    catch {
    }
    if !g_FTB_WV2
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "ftb_debug", "msg", String(msg), "level", level, "tick", A_TickCount))
    catch {
    }
}

; ===================== 閺勫墽銇?闂呮劘妫岄幃顒佽癁缁?=====================
; 棣栨/閲嶅缓 WebView 鍚庯細鍏堝叏閫忔槑鍗犱綅锛岀瓑椤甸潰 post UI_FINISHED 鍐嶄笉閫忔槑鏄剧ず锛岄伩鍏嶆湭娓叉煋瀹屽氨闇插嚭榛戠櫧搴曘€?; 闅愯棌鍚庡啀鎵撳紑涓?WebView 浠嶅湪锛氱洿鎺ユ樉绀猴紝涓嶅啀绛夊緟銆?
FloatingToolbar_FinishReveal() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarWindowX, FloatingToolbarWindowY
    global g_FTB_WaitingUiFinishedReveal, g_FTB_WV2, g_FTB_WV2_Ctrl

    if !FloatingToolbarGUI
        return

    g_FTB_WaitingUiFinishedReveal := false
    g_FTB_RevealWaitStartTick := 0
    SetTimer(FloatingToolbar_ForceRevealIfStuck, 0)

    tw := FloatingToolbarCalculateWidth()
    th := FloatingToolbarCalculateHeight()
    try FloatingToolbarGUI.Move(FloatingToolbarWindowX, FloatingToolbarWindowY, tw, th)
    catch {
    }
    ; 首启阶段在屏幕外完成 WebView2 首帧渲染，这里再移动回真实位置并显示。
    try g_FTB_WV2_Ctrl.IsVisible := true
    catch {
    }
    try WinSetTransparent(255, "ahk_id " . FloatingToolbarGUI.Hwnd)
    catch {
    }
    try FloatingToolbarGUI.Show("x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w" . tw . " h" . th . " NoActivate")
    catch {
    }

    FloatingToolbarIsVisible := true
    try FloatingToolbar_ClearHandoffWeb()
    catch {
    }
    try FloatingToolbar_NotifyWebViewShown(g_FTB_WV2)
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
    SetTimer(FloatingToolbarCheckWindowPosition, 100)
    SetTimer(FloatingToolbar_PushLayoutDeferred, -10)
    SetTimer(FloatingToolbar_PushLayoutDeferred, -150)
    try FloatingToolbar_RequestWebRevealSafe()
    catch {
    }
    if g_FTB_PendingOpenNiumaDrawer
        FloatingToolbar_ScheduleNiumaDrawerOpen(100)
}

FloatingToolbar_ForceRevealIfStuck() {
    global g_FTB_WaitingUiFinishedReveal, g_FTB_UI_Ready, g_FTB_RevealWaitStartTick
    if !g_FTB_WaitingUiFinishedReveal
        return
    if (!g_FTB_RevealWaitStartTick)
        g_FTB_RevealWaitStartTick := A_TickCount
    if !g_FTB_UI_Ready {
        if (A_TickCount - g_FTB_RevealWaitStartTick > 7000) {
            try {
                g_FTB_WaitingUiFinishedReveal := false
                g_FTB_RevealWaitStartTick := 0
                FloatingToolbar_RetryCreateWebView()
                return
            } catch {
            }
        }
        SetTimer(FloatingToolbar_ForceRevealIfStuck, -600)
        return
    }
    OutputDebug("[FTB] UI_FINISHED timeout: recreate WebView2")
    FloatingToolbar_FinishReveal()
}

ShowFloatingToolbar() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarWindowX, FloatingToolbarWindowY
    global g_FTB_UI_Ready, g_FTB_WaitingUiFinishedReveal, g_FTB_WV2_Ready, FloatingToolbarChatDrawerOpen

    ; Safety: entering toolbar mode should start collapsed — unless we are opening Niuma from hole handoff.
    global g_FTB_PendingOpenNiumaDrawer
    if !g_FTB_PendingOpenNiumaDrawer
        FloatingToolbarChatDrawerOpen := false

    if !FloatingToolbar_CanShowOverlay() {
        if (FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode) = "toolbar")
            FloatingToolbar_ClearOverlaySuppression()
    }
    if !FloatingToolbar_CanShowOverlay() {
        try HideFloatingToolbar()
        return
    }

    if (FloatingToolbarIsVisible && FloatingToolbarGUI != 0 && !g_FTB_WaitingUiFinishedReveal) {
        if FloatingToolbar_IsNiumaHandoffActive() {
            try FloatingToolbar_OpenNiumaChatDrawer(true)
            catch {
            }
        }
        return
    }
    ; 鑻ヤ笂娆′粛鍦ㄣ€岀瓑 UI_FINISHED銆嶏紝鍏堝彇娑堣秴鏃跺畾鏃跺櫒锛岄伩鍏嶉噸澶?reveal
    if (FloatingToolbarGUI != 0 && g_FTB_WaitingUiFinishedReveal) {
        g_FTB_WaitingUiFinishedReveal := false
        SetTimer(FloatingToolbar_ForceRevealIfStuck, 0)
    }

    FloatingToolbarLoadScale()

    if (!IsSet(FloatingToolbarGUI) || FloatingToolbarGUI = 0) {
        CreateFloatingToolbarGUI()
    }

    LoadFloatingToolbarPosition()

    if (FloatingToolbarWindowX = 0 && FloatingToolbarWindowY = 0) {
        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        ToolbarWidth := FloatingToolbarCalculateWidth()
        ToolbarHeight := FloatingToolbarCalculateHeight()
        FloatingToolbarWindowX := vl + vw - ToolbarWidth
        FloatingToolbarWindowY := vt + vh - ToolbarHeight
    }

    ToolbarWidth := FloatingToolbarCalculateWidth()
    ToolbarHeight := FloatingToolbarCalculateHeight()

    ; WebView 已加载过（隐藏后再显示）：不再等待 UI_FINISHED，直接显示并刷新布局
    if g_FTB_WV2_Ready {
        g_FTB_WaitingUiFinishedReveal := false
        g_FTB_RevealWaitStartTick := 0
        SetTimer(FloatingToolbar_ForceRevealIfStuck, 0)
        try WinSetTransparent(255, "ahk_id " . FloatingToolbarGUI.Hwnd)
        catch {
        }
        FloatingToolbarGUI.Show("x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w" . ToolbarWidth . " h" . ToolbarHeight . " NoActivate")
        FloatingToolbar_FinishReveal()
        return
    }

    ; 首次加载或重建：先在真实位置创建但保持隐藏，等 HTML 发 UI_FINISHED 后再显示。
    ; 避免屏幕外坐标污染位置状态，也避免 WebView2 首帧白底露出。
    try WinSetTransparent(0, "ahk_id " . FloatingToolbarGUI.Hwnd)
    catch {
    }
    FloatingToolbarGUI.Show("Hide x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w" . ToolbarWidth . " h" . ToolbarHeight . " NoActivate")
    g_FTB_WaitingUiFinishedReveal := true
    g_FTB_RevealWaitStartTick := A_TickCount
    FloatingToolbarIsVisible := false
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
    SetTimer(FloatingToolbar_ForceRevealIfStuck, 0)
    SetTimer(FloatingToolbar_ForceRevealIfStuck, -4500)
}

HideFloatingToolbar() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, g_FTB_WaitingUiFinishedReveal, g_FTB_WV2

    try NiumaMobileBrowser_Close()
    catch {
    }
    if (FloatingToolbarGUI != 0) {
        try FloatingToolbar_ExitHoleCompactRuntime()
        SaveFloatingToolbarPosition()
        g_FTB_WaitingUiFinishedReveal := false
        SetTimer(FloatingToolbar_ForceRevealIfStuck, 0)
        try WinSetTransparent(255, "ahk_id " . FloatingToolbarGUI.Hwnd)
        catch {
        }
        try FloatingToolbar_NotifyWebViewHidden(g_FTB_WV2)
        try FloatingToolbarGUI.Hide()
        FloatingToolbarIsVisible := false
        SetTimer(FloatingToolbarCheckWindowPosition, 0)
    }
}

ToggleFloatingToolbar() {
    global FloatingToolbarIsVisible, AppearanceActivationMode

    if !FloatingToolbar_CanShowOverlay() {
        try HideFloatingToolbar()
        return
    }

    mode := FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode)
    if (mode = "hole" || mode = "bubble") {
        return
    }
    if (mode = "tray") {
        return
    }

    if (FloatingToolbarIsVisible) {
        HideFloatingToolbar()
    } else {
        ShowFloatingToolbar()
    }
}

; ===================== 閸掓稑缂揋UI =====================
CreateFloatingToolbarGUI() {
    global FloatingToolbarGUI, g_FTB_WV2_Ctrl, g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_PendingSelection
    global g_FTB_UI_Ready, g_FTB_WaitingUiFinishedReveal, g_FTB_WV2_CreateRetry
    global WebView2
    g_FTB_WV2_CreateRetry := 0

    if (FloatingToolbarGUI != 0) {
        g_FTB_WV2_Ctrl := 0
        g_FTB_WV2 := 0
        g_FTB_WV2_Ready := false
        g_FTB_WV2_FrameReady := false
        FloatingToolbar_ResetChatBridge()
        g_FTB_PendingSelection := ""
        g_FTB_UI_Ready := false
        g_FTB_WaitingUiFinishedReveal := false
        g_FTB_WV2_CreateRetry := 0
        try FloatingToolbarGUI.Destroy()
        catch as _e {
        }
        try {
            if FuncExists("NiumaMobileBrowser_TraceOverlayPush")
                NiumaMobileBrowser_TraceOverlayPush("FTB WebView 重建: Destroy 旧实例", "warn")
        } catch {
        }
    }

    FloatingToolbarGUI := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x02080000", "Floating Toolbar")
    ; Boot stays dark until the web UI has painted, avoiding light-theme blank frames.
    FloatingToolbarGUI.BackColor := FloatingToolbar_GetBootBackColorHex()
    ; 创建后立即设为完全透明，避免 WebView2 初始化期间闪现白色矩形
    try WinSetTransparent(0, "ahk_id " . FloatingToolbarGUI.Hwnd)
    FloatingToolbarGUI.OnEvent("Close", OnFloatingToolbarClose)
    FloatingToolbarGUI.OnEvent("ContextMenu", OnFloatingToolbarContextMenu)

    OnMessage(0x020A, FloatingToolbarWM_MOUSEWHEEL)

    try {
        WebView2_CreateWithSharedEnvAsync(FloatingToolbarGUI.Hwnd, FloatingToolbar_OnWebViewCreated, "floating_toolbar")
    } catch as e {
        OutputDebug("[FTB] WebView2.create failed: " . e.Message)
        try {
            if FuncExists("NiumaMobileBrowser_TraceOverlayPush")
                NiumaMobileBrowser_TraceOverlayPush("FTB WebView 创建失败: " . e.Message, "err")
        } catch {
        }
        try TrayTip("悬浮工具栏", "WebView2 创建失败，请确认已安装 Edge WebView2 运行时。", "Iconx 2")
        catch {
        }
    }
}

FloatingToolbar_FlushPendingSelectionIfReady() {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingSelection
    if !(g_FTB_WV2 && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return
    if (g_FTB_PendingSelection = "")
        return
    pv := SubStr(String(g_FTB_PendingSelection), 1, 220)
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CHANGE", "preview", pv))
    catch as _e {
        return
    }
    g_FTB_PendingSelection := ""
}

FloatingToolbar_FlushPendingNiumaComposeIfReady() {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingNiumaCompose, g_FTB_PendingStudioAsk
    if FuncExists("CommandPalette_FlushPendingAiSendIfReady")
        try CommandPalette_FlushPendingAiSendIfReady()
        catch {
        }
    if !(g_FTB_WV2 && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return
    if (g_FTB_PendingStudioAsk is Map)
        SetTimer(FloatingToolbar_RetryPendingStudioAsk, -1)
    if !(g_FTB_PendingNiumaCompose is Array) || (g_FTB_PendingNiumaCompose.Length = 0)
        return
    try {
        n := g_FTB_PendingNiumaCompose.Length
        if FuncExists("CommandPalette_AiLog")
            try CommandPalette_AiLog("ftb_flush_compose", "count=" . n)
            catch {
            }
        for _, payload in g_FTB_PendingNiumaCompose {
            WebView_QueuePayload(g_FTB_WV2, payload)
        }
        g_FTB_PendingNiumaCompose := []
    } catch as _e {
        if FuncExists("CommandPalette_AiLog")
            try CommandPalette_AiLog("ftb_flush_compose_err", _e.Message)
            catch {
            }
    }
}

FloatingToolbar_OnNavigationStarting(sender, args) {
    global g_FTB_WV2_FrameReady
    g_FTB_WV2_FrameReady := false
}

FloatingToolbar_OnNavigationCompleted(sender, args) {
    global g_FTB_WV2_FrameReady
    ok := false
    try ok := args.IsSuccess
    catch as _e {
        ok := false
    }
    g_FTB_WV2_FrameReady := !!ok
    if ok {
        SetTimer(FloatingToolbar_PushLayoutDeferred, -40)
        SetTimer(FloatingToolbar_PushLayoutDeferred, -220)
        try FloatingToolbar_RequestWebReveal()
        catch {
        }
    }
    FloatingToolbar_FlushPendingSelectionIfReady()
    FloatingToolbar_FlushPendingNiumaComposeIfReady()
}

; ===================== 閸﹀棜顫楁潏瑙勵攱婢跺嫮鎮?=====================
; 宿主窗口保持矩形；圆角与发光统一由 WebView 内部绘制，避免 Win32 Region 边缘锯齿。
FloatingToolbarApplyRoundedCorners() {
    global FloatingToolbarGUI

    if (!IsSet(FloatingToolbarGUI) || FloatingToolbarGUI = 0) {
        return
    }

    try DllCall("SetWindowRgn", "Ptr", FloatingToolbarGUI.Hwnd, "Ptr", 0, "Int", 1)
    catch {
    }
}

; ===================== WebView2 閸ョ偠鐨?=====================
FloatingToolbar_OnWebViewCreated(ctrl) {
    global g_FTB_WV2_Ctrl, g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_WV2_CreateRetry

    if !IsObject(ctrl) {
        OutputDebug("[FTB] WebView2 create failed: invalid controller")
        try {
            if FuncExists("NiumaMobileBrowser_TraceOverlayPush")
                NiumaMobileBrowser_TraceOverlayPush("FTB WebView 创建失败: invalid controller", "err")
        } catch {
        }
        FloatingToolbar_RetryCreateWebView()
        return
    }
    g_FTB_WV2_CreateRetry := 0
    g_FTB_WV2_Ctrl := ctrl
    g_FTB_WV2 := 0
    try g_FTB_WV2 := ctrl.CoreWebView2
    catch {
        g_FTB_WV2 := 0
    }
    if !IsObject(g_FTB_WV2) {
        OutputDebug("[FTB] WebView2 create failed: CoreWebView2 unavailable")
        try {
            if FuncExists("NiumaMobileBrowser_TraceOverlayPush")
                NiumaMobileBrowser_TraceOverlayPush("FTB WebView 创建失败: CoreWebView2 unavailable", "err")
        } catch {
        }
        g_FTB_WV2_Ctrl := 0
        g_FTB_WV2 := 0
        g_FTB_WV2_Ready := false
        g_FTB_WV2_FrameReady := false
        FloatingToolbar_ResetChatBridge()
        FloatingToolbar_RetryCreateWebView()
        return
    }
    FloatingToolbar_ResetChatBridge()
    global g_NiumaMobile_Wv2Class
    g_NiumaMobile_Wv2Class := WebView2
    g_FTB_WV2_Ready := false
    g_FTB_WV2_FrameReady := false
    if FuncExists("CommandPalette_FlushPendingAiSendIfReady")
        try CommandPalette_FlushPendingAiSendIfReady()
        catch {
        }
    if FuncExists("CommandPalette_AiLog")
        try CommandPalette_AiLog("ftb_wv2_created", "CoreWebView2 ready for navigation")
        catch {
        }

    ; Keep WebView2's first compositor frame dark; theme color is applied after UI_FINISHED.
    try ctrl.DefaultBackgroundColor := FloatingToolbar_GetBootBackColorArgb()
    try ctrl.IsVisible := true

    FloatingToolbar_ApplyWebViewBounds()

    s := 0
    try s := g_FTB_WV2.Settings
    if IsObject(s) {
        s.AreDefaultContextMenusEnabled := false
        s.AreDevToolsEnabled := false
    }
    ; 避免 Ctrl+1/2/W 等被浏览器加速键先消费，确保 Niuma Chat 内快捷键优先生效
    try {
        if IsObject(s)
            s.AreBrowserAcceleratorKeysEnabled := false
    }
    ApplyWebView2PerformanceSettings(g_FTB_WV2)
    WebView2_RegisterHostBridge(g_FTB_WV2)

    g_FTB_WV2.add_NavigationStarting(FloatingToolbar_OnNavigationStarting)
    g_FTB_WV2.add_NavigationCompleted(FloatingToolbar_OnNavigationCompleted)
    g_FTB_WV2.add_WebMessageReceived(FloatingToolbar_OnWebMessage)
    try ApplyUnifiedWebViewAssets(g_FTB_WV2)
    ; 强制刷新 WebView 资源版本，避免命中旧缓存脚本导致前端变量未定义
    stripUrl := BuildAppLocalUrl("FloatingToolbarStrip.html")
    try {
        ver := String(FileGetTime(HtmlPanelPath("FloatingToolbarStrip.html"), "M"))
        if (InStr(stripUrl, "?"))
            stripUrl := stripUrl . "&v=" . ver
        else
            stripUrl := stripUrl . "?v=" . ver
    } catch {
    }
    g_FTB_WV2.Navigate(stripUrl)
}

; 历史路径/边缘情况下紧凑态 w≠h 会导致 WebView 非正方形、正圆成竖椭圆且一侧露底（常见右侧黑条）。强制为固定直径。
FloatingToolbar_SyncCompactWindowSquare() {
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY, FloatingToolbarCompactDiameter
    if !FloatingToolbarGUI
        return
    if !FloatingToolbarIsCompactMode()
        return
    s := Round(FloatingToolbarCompactDiameter)
    if (s < 48)
        s := 48
    try {
        FloatingToolbarGUI.GetPos(&gx, &gy, &gw, &gh)
        if (gw = s && gh = s) {
            FloatingToolbarWindowX := gx
            FloatingToolbarWindowY := gy
            FloatingToolbarApplyRoundedCorners()
            return
        }
        FloatingToolbarWindowX := gx
        FloatingToolbarWindowY := gy
        FloatingToolbarGUI.Move(gx, gy, s, s)
        FloatingToolbarApplyRoundedCorners()
    } catch {
    }
}

FloatingToolbar_GetGuiHwnd() {
    global FloatingToolbarGUI
    if !IsObject(FloatingToolbarGUI)
        return 0
    return FloatingToolbarGUI.Hwnd
}

; 打开手机浏览时保证总宽不超过屏幕，优先压缩 Chat 抽屉宽度，保留右侧手机区完整可见
FloatingToolbar_FitWindowWidthForMobile(&newW, &newX, rightEdge) {
    global FloatingToolbarChatDrawerWidth

    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    if (newW <= vw)
        return
    if !NiumaMobileBrowser_IsActive()
        return
    mobilePx := NiumaMobileBrowser_WidthPx()
    maxChatPx := Max(Round(380 * FloatingToolbar_EffectiveScale()), vw - mobilePx)
    eff := FloatingToolbar_EffectiveScale()
    if (eff < 0.01)
        eff := 1.0
    logicalMax := Round(maxChatPx / eff)
    if (logicalMax < 380)
        logicalMax := 380
    if (FloatingToolbarChatDrawerWidth > logicalMax)
        FloatingToolbarChatDrawerWidth := logicalMax
    newW := FloatingToolbarCalculateWidth()
    newX := rightEdge - newW
    if (newX < vl)
        newX := vl
    if (newX + newW > vr)
        newX := Max(vl, vr - newW)
}

FloatingToolbar_RefreshMobileLayout(*) {
    global FloatingToolbarGUI, FloatingToolbarChatDrawerOpen
    if !FloatingToolbarGUI || !FloatingToolbarChatDrawerOpen
        return
    if !NiumaMobileBrowser_IsActive()
        return
    FloatingToolbar_ResizeForMobileBrowser()
    FloatingToolbar_ApplyWebViewBounds()
}

FloatingToolbar_ApplyWebViewBounds() {
    global FloatingToolbarGUI, g_FTB_WV2_Ctrl

    if !(FloatingToolbarGUI && g_FTB_WV2_Ctrl)
        return
    if FloatingToolbarIsCompactMode() && !NiumaMobileBrowser_IsActive()
        FloatingToolbar_SyncCompactWindowSquare()

    WinGetClientPos(, , &cw, &ch, FloatingToolbarGUI.Hwnd)
    mobileW := 0
    if NiumaMobileBrowser_IsActive()
        mobileW := NiumaMobileBrowser_WidthPx()
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := Max(1, cw - mobileW)
    rc.bottom := ch
    try {
        g_FTB_WV2_Ctrl.Bounds := rc
        g_FTB_WV2_Ctrl.NotifyParentWindowPositionChanged()
    } catch {
    }
    if mobileW > 0 {
        try NiumaMobileBrowser_ApplyBounds(FloatingToolbarGUI.Hwnd)
        catch {
        }
    }
}

FloatingToolbar_ActivateMobileBrowser(url := "") {
    global FloatingToolbarGUI, FloatingToolbarChatDrawerOpen

    if !FloatingToolbarGUI
        return false
    if !FloatingToolbarChatDrawerOpen
        FloatingToolbarSetChatDrawerState(true, true)

    NiumaMobileBrowser_SetPendingOpen(true)
    FloatingToolbar_ResizeForMobileBrowser()
    FloatingToolbar_ApplyWebViewBounds()
    SetTimer(FloatingToolbar_RefreshMobileLayout, -60)
    SetTimer(FloatingToolbar_RefreshMobileLayout, -220)
    SetTimer(FloatingToolbar_RefreshMobileLayout, -520)

    ok := NiumaMobileBrowser_Open(FloatingToolbarGUI.Hwnd, url)
    if !ok {
        NiumaMobileBrowser_SetPendingOpen(false)
        FloatingToolbar_ResizeForMobileBrowser()
        FloatingToolbar_ApplyWebViewBounds()
    }
    return ok
}

FloatingToolbar_AfterMobileBrowserOpen() {
    FloatingToolbar_RefreshMobileLayout()
    SetTimer(FloatingToolbar_RefreshMobileLayout, -80)
    SetTimer(FloatingToolbar_RefreshMobileLayout, -350)
}

FloatingToolbar_AfterMobileBrowserClose() {
    NiumaMobileBrowser_SetPendingOpen(false)
    FloatingToolbar_ResizeForMobileBrowser()
    FloatingToolbar_ApplyWebViewBounds()
}

FloatingToolbar_ResizeForMobileBrowser() {
    global FloatingToolbarGUI, FloatingToolbarChatDrawerOpen, FloatingToolbarWindowX, FloatingToolbarWindowY

    if (!FloatingToolbarGUI || !FloatingToolbarChatDrawerOpen)
        return
    newW := FloatingToolbarCalculateWidth()
    newH := FloatingToolbarCalculateHeight()
    try FloatingToolbarGUI.GetPos(&gx, &gy, &gw, &gh)
    catch {
        gx := FloatingToolbarWindowX
        gy := FloatingToolbarWindowY
        gw := newW
        gh := newH
    }
    rightEdge := gx + gw
    newX := rightEdge - newW
    if NiumaMobileBrowser_IsActive()
        FloatingToolbar_FitWindowWidthForMobile(&newW, &newX, rightEdge)
    else {
        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        vr := vl + vw
        if (newX < vl)
            newX := vl
        if (newX + newW > vr)
            newX := Max(vl, vr - newW)
    }
    FloatingToolbarWindowX := newX
    try FloatingToolbarGUI.Move(newX, gy, newW, newH)
    catch {
    }
    FloatingToolbar_EnsureDrawerInWorkArea()
}

FloatingToolbar_RetryCreateWebView() {
    global FloatingToolbarGUI, g_FTB_WV2_CreateRetry
    if !FloatingToolbarGUI
        return
    if (g_FTB_WV2_CreateRetry >= 3) {
        try TrayTip("悬浮工具栏", "WebView 初始化失败，请重载脚本。", "Icon! 2")
        catch {
        }
        return
    }
    g_FTB_WV2_CreateRetry += 1
    SetTimer((*) => WebView2_CreateWithSharedEnvAsync(FloatingToolbarGUI.Hwnd, FloatingToolbar_OnWebViewCreated, "floating_toolbar_retry"), -200)
}

FloatingToolbar_GetLogoAppUrl() {
    if !IsSet(BuildAppLocalUrl)
        return ""
    candidates := [
        "牛马.png",
        "assets\牛马.png",
        "logo.png",
        "assets\logo.png",
        "images\logo.png",
        "images\nimabu.png",
        "assets\icons\app\logo.png",
        "lib\images\logo.png",
        "favicon.ico"
    ]
    for rel in candidates {
        full := A_ScriptDir . "\" . rel
        if FileExist(full) {
            u := StrReplace(rel, "\", "/")
            try {
                if (InStr(u, "assets/") = 1 || InStr(u, "assets\") = 1)
                    return BuildAppAssetUrl(u)
                return BuildAppLocalUrl(u)
            } catch {
                return ""
            }
        }
    }
    return ""
}

FloatingToolbar_PushLogoToWeb(*) {
    global g_FTB_WV2
    if !g_FTB_WV2
        return
    url := FloatingToolbar_GetLogoAppUrl()
    if (url = "")
        try url := BuildAppAssetUrl("牛马.png")
        catch {
        }
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_logo", "url", url))
    catch as _e {
    }
    try FloatingToolbar_RequestWebReveal()
    catch {
    }
}

; override 非空时直接使用该模式（与 ApplyTheme/INI 同步顺序无关，避免读 INI 读到旧值）
FloatingToolbar_PushThemeToWeb(override := "") {
    global g_FTB_WV2
    tm := (Trim(String(override)) != "")
        ? FloatingToolbar_NormalizeThemeToken(override, "dark")
        : FloatingToolbar_GetThemeMode()
    FloatingToolbar_ApplyHostThemeColorsForMode(tm)
    if g_FTB_WV2 {
        try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_theme", "themeMode", tm))
        catch as _e {
        }
    }
    if FuncExists("NiumaMobileBrowser_IsOpen") && NiumaMobileBrowser_IsOpen() && FuncExists("NiumaMobileBrowser_PushChromeState")
        NiumaMobileBrowser_PushChromeState(true)
}

FloatingToolbar_GetBootBackColorHex() {
    return "0a0a0a"
}

FloatingToolbar_GetBootBackColorArgb() {
    return 0xFF0A0A0A
}

FloatingToolbar_GetThemeBackColorHex() {
    tm := FloatingToolbar_GetThemeMode()
    return (tm = "light") ? "f7f7f7" : "0a0a0a"
}

FloatingToolbar_GetThemeBackColorArgb() {
    tm := FloatingToolbar_GetThemeMode()
    return (tm = "light") ? 0xFFF7F7F7 : 0xFF0A0A0A
}

FloatingToolbar_ApplyHostThemeColorsForMode(tm) {
    global FloatingToolbarGUI, g_FTB_WV2_Ctrl
    tm2 := FloatingToolbar_NormalizeThemeToken(tm, "dark")
    hex := (tm2 = "light") ? "f7f7f7" : "0a0a0a"
    argb := (tm2 = "light") ? 0xFFF7F7F7 : 0xFF0A0A0A
    try {
        if IsObject(FloatingToolbarGUI)
            FloatingToolbarGUI.BackColor := hex
    } catch {
    }
    try {
        if IsObject(g_FTB_WV2_Ctrl)
            g_FTB_WV2_Ctrl.DefaultBackgroundColor := argb
    } catch {
    }
}

FloatingToolbar_ApplyHostThemeColors() {
    FloatingToolbar_ApplyHostThemeColorsForMode(FloatingToolbar_GetThemeMode())
}

FloatingToolbar_NormalizeThemeToken(raw, fallback := "dark") {
    s := StrLower(Trim(String(raw)))
    if (s = "light" || s = "lite")
        return "light"
    if (s = "dark")
        return "dark"
    return (fallback = "light") ? "light" : "dark"
}

FloatingToolbar_GetThemeMode() {
    ; Prefer direct INI read so theme stays correct even if global state is stale.
    try {
        global ConfigFile
        if (IsSet(ConfigFile) && ConfigFile != "") {
            raw := IniRead(ConfigFile, "Settings", "ThemeMode", "")
            if (Trim(String(raw)) = "")
                raw := IniRead(ConfigFile, "Appearance", "ThemeMode", "")
            if (Trim(String(raw)) != "")
                return FloatingToolbar_NormalizeThemeToken(raw, "dark")
        }
    } catch {
    }
    try {
        fn := Func("ReadPersistedThemeMode")
        if IsObject(fn)
            return FloatingToolbar_NormalizeThemeToken(fn.Call(), "dark")
    } catch {
    }
    try {
        global ThemeMode
        return FloatingToolbar_NormalizeThemeToken(ThemeMode, "dark")
    } catch {
    }
    return "dark"
}

FloatingToolbar_OnWebMessage(sender, args) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingSelection, FloatingToolbarGUI, FloatingToolbarScale

    msg := FloatingToolbar_ParseWebMessage(args)
    if !(msg is Map)
        return

    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ != "")
        FTB_Debug("recv " . typ)

    if (typ = "chat_ready") {
        FloatingToolbar_OnChatReady(msg)
        return
    }
    if (typ = "niuma_browser_trace") {
        try {
            if FuncExists("NiumaMobileBrowser_TraceFromChat")
                NiumaMobileBrowser_TraceFromChat(msg)
        } catch {
        }
        return
    }
    if (typ = "niuma_inject_ack") {
        rid := msg.Has("reqId") ? String(msg["reqId"]) : ""
        ok := msg.Has("ok") ? !!msg["ok"] : false
        why := msg.Has("why") ? String(msg["why"]) : ""
        err := msg.Has("err") ? String(msg["err"]) : ""
        try {
            if FuncExists("NiumaMobileBrowser_Log")
                NiumaMobileBrowser_Log("HANDSHAKE", rid, "inject_ack ok=" . (ok ? 1 : 0) . " why=" . why . (err != "" ? (" err=" . err) : ""))
        } catch {
        }
        try {
            if FuncExists("NiumaMobileBrowser_TraceOverlayPush")
                NiumaMobileBrowser_TraceOverlayPush("INJECT ack rid=" . rid . " ok=" . (ok ? 1 : 0) . " why=" . why . (err != "" ? (" err=" . SubStr(err, 1, 120)) : ""), ok ? "success" : "err")
        } catch {
        }
        return
    }

    if (typ = "toolbar_ready") {
        g_FTB_WV2_Ready := true
        FloatingToolbar_ApplyWebViewBounds()
        try FloatingToolbar_EnsureCommandsLoaded()
        catch {
        }
        SetTimer(FloatingToolbar_PushLogoToWeb, -10)
        SetTimer(FloatingToolbar_PushThemeToWeb, -10)
        FloatingToolbarPushScaleStateToWeb(FloatingToolbarScale)
        try FloatingToolbarPushButtonConfigToWeb()
        catch {
        }
        SetTimer(FloatingToolbar_PushLayoutDeferred, -10)
        SetTimer(FloatingToolbar_PushLayoutDeferred, -180)
        SetTimer(FloatingToolbar_PushLayoutDeferred, -520)
        SetTimer(FloatingToolbar_PushStudioLlmOnReady, -450)
        FloatingToolbar_FlushPendingSelectionIfReady()
        FloatingToolbar_FlushPendingNiumaComposeIfReady()
        if FuncExists("CommandPalette_FlushPendingAiSendIfReady")
            try CommandPalette_FlushPendingAiSendIfReady()
            catch {
            }
        try FloatingToolbar_RequestWebReveal()
        catch {
        }
        return
    }

    if (typ = "ftb_soft_reset") {
        FloatingToolbar_ResetChatBridge()
        try {
            if FuncExists("NiumaMobileBrowser_TraceOverlayPush")
                NiumaMobileBrowser_TraceOverlayPush("DRAWER ftb_soft_reset", "warn")
        } catch {
        }
        try FloatingToolbar_EnsureCommandsLoaded()
        catch {
        }
        SetTimer(FloatingToolbar_PushLayoutDeferred, -10)
        SetTimer(FloatingToolbar_PushLayoutDeferred, -150)
        try FloatingToolbar_RequestWebReveal()
        catch {
        }
        return
    }

    if (typ = "UI_FINISHED") {
        global FloatingToolbarIsVisible, FloatingToolbarWindowX, FloatingToolbarWindowY
        global g_FTB_UI_Ready, g_FTB_WaitingUiFinishedReveal

        if !FloatingToolbarGUI
            return

        g_FTB_UI_Ready := true

        if !g_FTB_WaitingUiFinishedReveal
            return

        try FloatingToolbar_RequestWebReveal()
        catch {
        }
        ; 涓嶅啀浣跨敤 AnimateWindow(AW_BLEND)锛岄伩鍏嶉粦鐧芥笎鍙橀棯灞忥紱鐢?FloatingToolbar_FinishReveal 涓€娆℃€т笉閫忔槑鏄剧ず
        FloatingToolbar_FinishReveal()
        FloatingToolbar_FlushPendingNiumaComposeIfReady()
        if FuncExists("CommandPalette_AiLog")
            try CommandPalette_AiLog("ftb_ui_finished", CommandPalette_AiStateSnapshot())
            catch {
            }
        return
    }

    if (typ = "toolbar_action") {
        action := msg.Has("action") ? String(msg["action"]) : ""
        if (action != "")
            FloatingToolbarExecuteButtonAction(action, 0)
        return
    }

    if (typ = "toolbar_cmd") {
        cid := msg.Has("cmdId") ? Trim(String(msg["cmdId"])) : ""
        if (cid != "")
            SetTimer(FloatingToolbar_DeferredToolbarCmd.Bind(cid), -10)
        return
    }

    if (typ = "toolbar_toggle_action") {
        action := msg.Has("action") ? String(msg["action"]) : ""
        FTB_Debug("toggle " . action)
        if (action != "")
            FloatingToolbarToggleButtonAction(action)
        return
    }

    if (typ = "toolbar_search_click") {
        FloatingToolbar_ActivateSearchCenter()
        return
    }

    if (typ = "drop_search") {
        t := msg.Has("text") ? Trim(String(msg["text"])) : ""
        if (t != "") {
            try FloatingToolbar_RequestSearchByKeyword(t)
            catch {
            }
        }
        if g_FTB_WV2 {
            try {
                WebView_QueuePayload(g_FTB_WV2, Map("type", "drop_done"))
                WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CLEAR"))
            } catch {
            }
        }
        return
    }

    if (typ = "drop_action") {
        action := msg.Has("action") ? Trim(String(msg["action"])) : "Search"
        t := msg.Has("text") ? Trim(String(msg["text"])) : ""
        filePaths := []
        if (msg.Has("files") && (msg["files"] is Array)) {
            for _, f in msg["files"] {
                fp := Trim(String(f))
                if (fp != "")
                    filePaths.Push(fp)
            }
        }
        if (t != "") {
            try {
                switch action {
                    case "Search":
                        FloatingToolbar_RequestSearchByKeyword(t)
                    case "Niuma":
                        FloatingToolbar_SendTextToNiumaChat(t, true, true, true)
                    case "Prompt", "NewPrompt":
                        PromptQuickPad_OpenCaptureDraft(t, true)
                    case "Record":
                        CP_Show()
                        CP_SetSearchText(t, true, true)
                    default:
                        ; 未定义入口图标统一回退到搜索中心
                        FloatingToolbar_RequestSearchByKeyword(t)
                }
            } catch {
            }
        } else if (filePaths.Length > 0) {
            try {
                switch action {
                    case "Niuma":
                        FloatingToolbar_HandleDroppedFiles(filePaths)
                    case "Prompt", "NewPrompt", "Record", "Search":
                        FloatingToolbar_HandleDroppedFiles(filePaths)
                    default:
                        FloatingToolbar_HandleDroppedFiles(filePaths)
                }
            } catch {
            }
        }
        if g_FTB_WV2 {
            try {
                WebView_QueuePayload(g_FTB_WV2, Map("type", "drop_done"))
                WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CLEAR"))
            } catch {
            }
        }
        return
    }

    if (typ = "hole_drag_show") {
        ; Disabled: WebView dragover can flood host and freeze toolbar.
        ; NativeDropBridge drives hole animation/commands instead.
        return
    }

    if (typ = "hole_drag_update") {
        ; Disabled: avoid drag-event storm in toolbar WebView.
        return
    }

    if (typ = "hole_drag_hide") {
        ; Disabled: avoid conflicting hide/show with native bridge.
        return
    }

    if (typ = "hole_drag_drop") {
        ; Disabled: drop command is handled by native bridge / hole drop.
        return
    }

    if (typ = "drag_host") {
        global FloatingToolbarGUI, FloatingToolbarDragging
        global FloatingToolbar_DragOriginScreenX, FloatingToolbar_DragOriginScreenY
        global FloatingToolbar_DragOriginWinX, FloatingToolbar_DragOriginWinY, FloatingToolbar_DragStartTick
        ; Hard isolation: when external drag/hole session is active, never start toolbar self-drag.
        try {
            if GDHO_IsDragSessionActive()
                return
        } catch {
        }
        if !FloatingToolbarGUI || FloatingToolbarDragging
            return
        try FloatingToolbarGUI.GetPos(&FloatingToolbar_DragOriginWinX, &FloatingToolbar_DragOriginWinY)
        catch as _e {
            return
        }
        CoordMode("Mouse", "Screen")
        MouseGetPos(&FloatingToolbar_DragOriginScreenX, &FloatingToolbar_DragOriginScreenY)
        FloatingToolbarDragging := true
        FloatingToolbar_DragStartTick := A_TickCount
        SetTimer(FloatingToolbar_DragRun, 16)
        return
    }

    if (typ = "wheel") {
        global FloatingToolbarChatDrawerOpen
        if FloatingToolbarChatDrawerOpen
            return
        delta := msg.Has("delta") ? Integer(msg["delta"]) : 0
        if (delta != 0)
            FloatingToolbarApplyWheelDelta(delta)
        return
    }

    if (typ = "exit_compact") {
        FloatingToolbarExitCompactMode()
        return
    }

    if (typ = "context_menu") {
        x := msg.Has("x") ? Integer(msg["x"]) : 0
        y := msg.Has("y") ? Integer(msg["y"]) : 0
        FTB_Debug("context_menu x=" . x . " y=" . y)
        SetTimer(FloatingToolbar_ShowContextMenuDeferred.Bind(x, y), -10)
        return
    }

    if (typ = "chat_input_context_menu") {
        x := msg.Has("x") ? Integer(msg["x"]) : 0
        y := msg.Has("y") ? Integer(msg["y"]) : 0
        field := msg.Has("field") ? Trim(String(msg["field"])) : "input"
        hasSel := msg.Has("hasSelection") ? !!msg["hasSelection"] : false
        sel := msg.Has("selection") ? String(msg["selection"]) : ""
        FTB_Debug("chat_input_context_menu x=" . x . " y=" . y . " field=" . field)
        SetTimer(FloatingToolbar_ShowChatInputContextMenuDeferred.Bind(x, y, field, hasSel, sel), -10)
        return
    }

    if (typ = "toolbar_cmd_context") {
        cid := msg.Has("cmdId") ? Trim(String(msg["cmdId"])) : ""
        if (cid = "ftb_cursor_menu") {
            try FloatingToolbar_ShowCursorQuickMenu()
            catch {
            }
            return
        }
        x := msg.Has("x") ? Integer(msg["x"]) : 0
        y := msg.Has("y") ? Integer(msg["y"]) : 0
        FTB_Debug("toolbar_cmd_context x=" . x . " y=" . y)
        SetTimer(FloatingToolbar_ShowContextMenuDeferred.Bind(x, y), -10)
        return
    }

    if (typ = "niuma_mobile_browser_open") {
        url := msg.Has("url") ? String(msg["url"]) : ""
        SetTimer(FloatingToolbar_ActivateMobileBrowser.Bind(url), -1)
        SetTimer(NiumaMobileBrowser_NotifyStateLive.Bind(url), -800)
        SetTimer(NiumaMobileBrowser_NotifyStateLive.Bind(url), -2000)
        SetTimer(NiumaMobileBrowser_NotifyStateLive.Bind(url), -4500)
        SetTimer(NiumaMobileBrowser_NotifyStateLive.Bind(url), -9000)
        SetTimer(NiumaMobileBrowser_NotifyStateLive.Bind(url), -14000)
        SetTimer(NiumaMobileBrowser_NotifyStateLive.Bind(url), -20000)
        SetTimer(NiumaMobileBrowser_NotifyStateLive.Bind(url), -26000)
        return
    }
    if (typ = "niuma_browser_sync_state" || typ = "chat_request_browser_current_state") {
        u := ""
        global g_NiumaMobile_WV2
        if NiumaMobileBrowser_IsOpen() && g_NiumaMobile_WV2 {
            try u := g_NiumaMobile_WV2.SourceUri
            catch {
            }
        }
        isOpen := NiumaMobileBrowser_IsOpen()
        NiumaMobileBrowser_Log("STATE", "", typ . " 收到, IsOpen=" . (isOpen ? 1 : 0) . " url=" . u)
        NiumaMobileBrowser_NotifyStateVia(sender, isOpen, u)
        return
    }
    if (typ = "niuma_mobile_browser_navigate") {
        url := msg.Has("url") ? String(msg["url"]) : ""
        global FloatingToolbarChatDrawerOpen
        if !FloatingToolbarChatDrawerOpen || !NiumaMobileBrowser_IsOpen()
            SetTimer(FloatingToolbar_ActivateMobileBrowser.Bind(url), -1)
        else
            SetTimer(NiumaMobileBrowser_Navigate.Bind(url), -1)
        return
    }
    if (typ = "niuma_mobile_browser_close") {
        NiumaMobileBrowser_Close()
        return
    }
    if (typ = "niuma_mobile_browser_back") {
        NiumaMobileBrowser_Back()
        return
    }
    if (typ = "niuma_mobile_browser_reload") {
        NiumaMobileBrowser_Reload()
        return
    }
    if (typ = "niuma_mobile_browser_extract") {
        NiumaMobileBrowser_ExtractText()
        return
    }
    if (typ = "niuma_browser_observe") {
        reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
        SetTimer(NiumaMobileBrowser_ObserveForChatDeferred.Bind(reqId), -1)
        return
    }
    if (typ = "niuma_browser_force_relabel") {
        reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
        ; 强刷：重新打标并推送带 reqId 的快照，避免 label_parse_empty 导致模型盲视
        SetTimer(NiumaMobileBrowser_ObserveForChatDeferred.Bind(reqId), -1)
        return
    }
    if (typ = "niuma_browser_get_snapshot") {
        reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
        NiumaMobileBrowser_PushCachedSnapshot(reqId)
        return
    }
    if (typ = "niuma_browser_action") {
        action := msg.Has("action") ? String(msg["action"]) : ""
        eid := msg.Has("id") ? Integer(msg["id"]) : (msg.Has("elementId") ? Integer(msg["elementId"]) : 0)
        val := msg.Has("value") ? String(msg["value"]) : (msg.Has("text") ? String(msg["text"]) : "")
        if (action = "scroll" && val = "") {
            dir := msg.Has("scrollDirection") ? String(msg["scrollDirection"]) : ""
            dist := msg.Has("scrollDistance") ? Integer(msg["scrollDistance"]) : 0
            if (dir != "")
                val := dir
            else if (dist != 0)
                val := String(dist)
        }
        actReqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
        forceDoubao := msg.Has("forceDoubaoInput") && !!msg["forceDoubaoInput"]
        chatJsSend := msg.Has("chatJsSendOnly") && !!msg["chatJsSendOnly"]
        deepseekJsFill := msg.Has("deepseekJsFillOnly") && !!msg["deepseekJsFillOnly"]
        geminiJsFill := msg.Has("geminiJsFillOnly") && !!msg["geminiJsFillOnly"]
        FloatingToolbar_DispatchBrowserAction(action, eid, val, actReqId, forceDoubao, chatJsSend, deepseekJsFill, geminiJsFill)
        return
    }
    if (typ = "niuma_browser_chat_plan_execute") {
        planText := msg.Has("text") ? String(msg["text"]) : (msg.Has("value") ? String(msg["value"]) : "")
        planPlatform := msg.Has("platform") ? String(msg["platform"]) : ""
        planEid := msg.Has("elementId") ? Integer(msg["elementId"]) : (msg.Has("id") ? Integer(msg["id"]) : 0)
        planReqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
        FloatingToolbar_DispatchChatPlanExecute(planText, planEid, planPlatform, planReqId)
        return
    }
    if (typ = "niuma_browser_act") {
        FloatingToolbar_CompatEnqueue(msg)
        return
    }
    if (typ = "niuma_browser_resolve") {
        reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
        selector := msg.Has("selector") ? String(msg["selector"]) : ""
        roleHint := msg.Has("roleHint") ? String(msg["roleHint"]) : ""
        SetTimer(NiumaMobileBrowser_ResolveElement.Bind(reqId, selector, roleHint), -1)
        return
    }
    if (typ = "niuma_browser_pause_ai") {
        NiumaMobileBrowser_PauseAiControl()
        return
    }
    if (typ = "niuma_browser_resume_ai") {
        NiumaMobileBrowser_ResumeAiControl()
        return
    }
    if (typ = "niuma_cdp_execute") {
        SetTimer(FloatingToolbar_DeferredCdpExecute.Bind(msg), -10)
        return
    }
    if (typ = "niuma_scratchpad_run") {
        SetTimer(FloatingToolbar_DeferredScratchpadRun.Bind(msg), -10)
        return
    }
    if (typ = "niuma_browser_hide_labels") {
        NiumaMobileBrowser_HideLabels()
        return
    }
    if (typ = "niuma_browser_toggle_labels") {
        NiumaMobileBrowser_ToggleLabelDebug()
        return
    }
    if (typ = "niuma_browser_show_labels") {
        NiumaMobileBrowser_ShowLabels()
        return
    }
    if (typ = "niuma_get_hole_context") {
        holeTxt := ""
        if FuncExists("GDHO_GetTextHoleCapturedText") {
            try holeTxt := Trim(String(GDHO_GetTextHoleCapturedText()))
            catch {
                holeTxt := ""
            }
        }
        if (holeTxt = "") && FuncExists("SelectionSense_GetLastSelectedText") {
            try holeTxt := Trim(String(SelectionSense_GetLastSelectedText()))
            catch {
            }
        }
        try WebView_QueuePayload(g_FTB_WV2, Map("type", "host_hole_context", "text", holeTxt))
        catch {
        }
        return
    }

    if (typ = "niuma_grounding_cache_get") {
        reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
        host := msg.Has("host") ? String(msg["host"]) : ""
        intentTemplate := msg.Has("intentTemplate") ? String(msg["intentTemplate"]) : ""
        pageFingerprint := msg.Has("pageFingerprint") ? String(msg["pageFingerprint"]) : ""
        tool := msg.Has("tool") ? String(msg["tool"]) : ""
        targetRoleHint := msg.Has("targetRoleHint") ? String(msg["targetRoleHint"]) : ""

        ok := GroundingCache_Init()
        if !ok {
            try WebView_QueuePayload(g_FTB_WV2, Map(
                "type", "host_grounding_cache_get_result",
                "reqId", reqId,
                "ok", false,
                "error", "GroundingCache db init failed"
            ))
            catch {
            }
            return
        }

        outSel := ""
        outTT := ""
        outCnt := 0
        found := GroundingCache_Get(host, intentTemplate, pageFingerprint, tool, targetRoleHint, &outSel, &outTT, &outCnt)
        try WebView_QueuePayload(g_FTB_WV2, Map(
            "type", "host_grounding_cache_get_result",
            "reqId", reqId,
            "ok", true,
            "found", !!found,
            "selector", outSel,
            "textTemplate", outTT,
            "successCount", outCnt
        ))
        catch {
        }
        return
    }

    if (typ = "niuma_grounding_cache_set") {
        reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
        host := msg.Has("host") ? String(msg["host"]) : ""
        intentTemplate := msg.Has("intentTemplate") ? String(msg["intentTemplate"]) : ""
        pageFingerprint := msg.Has("pageFingerprint") ? String(msg["pageFingerprint"]) : ""
        tool := msg.Has("tool") ? String(msg["tool"]) : ""
        targetRoleHint := msg.Has("targetRoleHint") ? String(msg["targetRoleHint"]) : ""
        selector := msg.Has("selector") ? String(msg["selector"]) : ""
        textTemplate := msg.Has("textTemplate") ? String(msg["textTemplate"]) : ""
        inc := msg.Has("inc") ? Integer(msg["inc"]) : 1

        ok := GroundingCache_Init()
        if !ok {
            try WebView_QueuePayload(g_FTB_WV2, Map(
                "type", "host_grounding_cache_set_result",
                "reqId", reqId,
                "ok", false,
                "error", "GroundingCache db init failed"
            ))
            catch {
            }
            return
        }

        stored := GroundingCache_Set(host, intentTemplate, pageFingerprint, tool, targetRoleHint, selector, textTemplate, inc)
        try WebView_QueuePayload(g_FTB_WV2, Map(
            "type", "host_grounding_cache_set_result",
            "reqId", reqId,
            "ok", true,
            "stored", !!stored
        ))
        catch {
        }
        return
    }

    if (typ = "niuma_browser_cmd") {
        cmd := msg.Has("cmd") ? String(msg["cmd"]) : ""
        ret := NiumaMobileBrowser_RunUserCommand(cmd)
        try WebView_QueuePayload(g_FTB_WV2, Map(
            "type", "host_browser_cmd_result",
            "ok", ret.Has("ok") && ret["ok"],
            "error", ret.Has("error") ? String(ret["error"]) : "",
            "action", ret.Has("action") ? String(ret["action"]) : ""
        ))
        catch {
        }
        return
    }

    if (typ = "drawer_state") {
        open := msg.Has("open") && !!msg["open"]
        global FloatingToolbarChatDrawerOpen, g_FTB_NiumaHandoffOpening
        if !open
            FloatingToolbar_ResetChatBridge()
        try {
            if FuncExists("NiumaMobileBrowser_TraceOverlayPush")
                NiumaMobileBrowser_TraceOverlayPush("DRAWER state open=" . (open ? 1 : 0), open ? "success" : "warn")
        } catch {
        }
        wasOpen := !!FloatingToolbarChatDrawerOpen
        if (open = wasOpen && !g_FTB_NiumaHandoffOpening) {
            if open {
                try FloatingToolbar_PushStudioContextToChat()
                catch {
                }
            }
            return
        }
        FTB_Debug("drawer_state open=" . open)
        FloatingToolbarSetChatDrawerState(open, g_FTB_NiumaHandoffOpening && open)
        if open {
            try FloatingToolbar_PushStudioContextToChat()
            catch {
            }
            llm := FloatingToolbar_GetStudioLlm()
            if Trim(String(llm.Get("apiKey", ""))) != "" {
                try FloatingToolbar_PushStudioLlmToChat(llm, "", false)
                catch {
                }
            }
        }
        return
    }

    if (typ = "drawer_resize") {
        w := msg.Has("width") ? Integer(msg["width"]) : 0
        if (w > 0)
            FloatingToolbar_ApplyDrawerClientWidth(w)
        return
    }

    if (typ = "drawer_resize_done") {
        FloatingToolbarSaveDrawerWidth()
        SaveFloatingToolbarPosition()
        return
    }

    if (typ = "niuma_cli_open") {
        reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
        engine := msg.Has("engine") ? Trim(String(msg["engine"])) : "codex_cli"
        try {
            FloatingToolbar_PushNodeStatus(engine, "thinking", "正在连接 ttyd")
            FloatingToolbar_PushAudit(engine, "正在打开 CLI 终端", "info")
        } catch {
        }
        SetTimer(NiumaTtyd_DeferredOpenJob.Bind(reqId, engine), -10)
        return
    }
    if (typ = "niuma_cli_restart") {
        reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
        engine := msg.Has("engine") ? Trim(String(msg["engine"])) : "codex_cli"
        try {
            FloatingToolbar_PushNodeStatus(engine, "thinking", "正在重启 ttyd")
            FloatingToolbar_PushAudit(engine, "正在重启 CLI 终端", "info")
        } catch {
        }
        SetTimer(NiumaTtyd_DeferredRestartJob.Bind(reqId, engine), -10)
        return
    }
    if (typ = "niuma_cli_open_external") {
        reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
        expectedBaseUrl := msg.Has("baseUrl") ? String(msg["baseUrl"]) : ""
        engine := msg.Has("engine") ? Trim(String(msg["engine"])) : "codex_cli"
        SetTimer(NiumaTtyd_DeferredExternalOpenJob.Bind(reqId, expectedBaseUrl, engine), -10)
        return
    }
    if (typ = "niuma_request_ttyd_studio") {
        SetTimer(FloatingToolbar_PushTtydStudioConfig, -10)
        return
    }
    if (typ = "niuma_request_studio_context") {
        try FloatingToolbar_PushStudioContextToChat()
        catch {
        }
        return
    }
    if (typ = "niuma_fetch_studio_context") {
        reqId := Trim(String(msg.Get("reqId", "")))
        payload := FloatingToolbar_StudioContextPayload()
        try WebView_QueuePayload(g_FTB_WV2, Map(
            "type", "niuma_studio_context_result",
            "reqId", reqId,
            "ok", true,
            "autoInjectContext", payload.Get("autoInjectContext", true),
            "systemPrompt", payload.Get("systemPrompt", ""),
            "installRoot", payload.Get("installRoot", A_ScriptDir),
            "scriptDir", payload.Get("scriptDir", A_ScriptDir)
        ))
        catch {
        }
        return
    }
    if (typ = "niuma_request_studio_llm") {
        llm := FloatingToolbar_GetStudioLlm()
        ok := false
        err := ""
        try FloatingToolbar_PushStudioContextToChat()
        catch {
        }
        if Trim(String(llm.Get("apiKey", ""))) != "" {
            try FloatingToolbar_PushStudioLlmToChat(llm, "", false)
            ok := true
        } else
            err := "智能定制中未保存 API Key（请在设置中心「智能定制」填写并点「保存 API」）"
        ctx := Map()
        if FuncExists("UserStudio_GetNiumaContext") {
            try ctx := UserStudio_GetNiumaContext()
            catch {
            }
        }
        syncPayload := Map("type", "studio_llm_sync_result", "ok", ok, "error", err, "niumaContext", ctx, "llm", llm)
        if FuncExists("UserStudio_PayloadForWeb") {
            try {
                pl := UserStudio_PayloadForWeb()
                if (pl.Has("options") && pl["options"] is Map)
                    syncPayload["options"] := pl["options"]
            } catch {
            }
        }
        try WebView_QueuePayload(g_FTB_WV2, syncPayload)
        catch {
        }
        return
    }
    if (typ = "niuma_palette_ai_keys") {
        if FuncExists("CommandPalette_OnNiumaPaletteAiKeys")
            try CommandPalette_OnNiumaPaletteAiKeys(msg)
            catch as ePalKeys {
                if FuncExists("CommandPalette_AiLog")
                    try CommandPalette_AiLog("ai_keys_handler_err", ePalKeys.Message)
                    catch {
                    }
            }
        return
    }
    if (typ = "niuma_palette_ai_llm") {
        if FuncExists("CommandPalette_OnNiumaPaletteAiLlm")
            try CommandPalette_OnNiumaPaletteAiLlm(msg)
            catch as ePalLlm {
                if FuncExists("CommandPalette_AiLog")
                    try CommandPalette_AiLog("ai_llm_handler_err", ePalLlm.Message)
                    catch {
                    }
            }
        return
    }
    if (typ = "niuma_palette_ai_trace") {
        if FuncExists("CommandPalette_AiLog") {
            step := msg.Has("step") ? String(msg["step"]) : ""
            det := msg.Has("detail") ? String(msg["detail"]) : ""
            try CommandPalette_AiLog("web_" . step, det)
            catch {
            }
        }
        return
    }
    if (typ = "niuma_palette_ai_chunk") {
        if FuncExists("CommandPalette_OnNiumaPaletteAiChunk")
            try CommandPalette_OnNiumaPaletteAiChunk(msg)
            catch {
            }
        return
    }
    if (typ = "niuma_palette_ai_end") {
        if FuncExists("CommandPalette_OnNiumaPaletteAiEnd")
            try CommandPalette_OnNiumaPaletteAiEnd(msg)
            catch {
            }
        return
    }
    if (typ = "niuma_palette_ai_error") {
        if FuncExists("CommandPalette_OnNiumaPaletteAiError")
            try CommandPalette_OnNiumaPaletteAiError(msg)
            catch {
            }
        return
    }
    if (typ = "host_palette_ai_stream") {
        SetTimer(FloatingToolbar_StartPaletteAiStream.Bind(msg), -10)
        return
    }
    if (typ = "host_palette_ai_handoff") {
        try WebView_QueuePayload(g_FTB_WV2, msg)
        catch {
        }
        return
    }
    if (typ = "host_palette_ai_handoff_end") {
        try WebView_QueuePayload(g_FTB_WV2, msg)
        catch {
        }
        return
    }
    if (typ = "host_palette_ai_stream_cancel") {
        try WebView_QueuePayload(g_FTB_WV2, msg)
        catch {
        }
        return
    }
    if (typ = "niuma_sync_studio_llm") {
        llm := Map()
        if msg.Has("llm") && msg["llm"] is Map
            llm := msg["llm"]
        else {
            if msg.Has("provider")
                llm["provider"] := msg["provider"]
            if msg.Has("apiKey")
                llm["apiKey"] := msg["apiKey"]
            if msg.Has("baseUrl")
                llm["baseUrl"] := msg["baseUrl"]
            if msg.Has("model")
                llm["model"] := msg["model"]
        }
        pl := Map("llm", llm)
        if msg.Has("apiKeys") && msg["apiKeys"] is Map
            pl["options"] := Map("llmApiKeys", msg["apiKeys"])
        if Trim(String(llm.Get("apiKey", ""))) != "" {
            try {
                if FuncExists("ConfigWebView_ApplyUserStudioSave") {
                    saveMsg := Map("payload", pl)
                    try saveMsg["payloadJson"] := Jxon_Dump(pl)
                    catch {
                    }
                    ConfigWebView_ApplyUserStudioSave(saveMsg)
                } else if FuncExists("UserStudio_ApplyFromWebPayload")
                    UserStudio_ApplyFromWebPayload(pl)
            } catch {
            }
            try ConfigWebView_NotifyStudioLlmSynced()
            catch {
            }
        }
        return
    }
    if (typ = "niuma_save_ttyd_studio") {
        sh := msg.Has("shell") ? Trim(String(msg["shell"])) : ""
        wd := msg.Has("workDir") ? Trim(String(msg["workDir"])) : ""
        ok := false
        err := ""
        try {
            if FuncExists("UserStudio_ApplyFromWebPayload") {
                UserStudio_ApplyFromWebPayload(Map("ttyd", Map("shell", sh, "workDir", wd)))
                ok := true
            } else
                err := "UserStudio 未加载"
        } catch as e {
            err := e.Message
        }
        if ok {
            try SetTimer(NiumaTtyd_DeferredRestartJob.Bind("", "studio_cli", g_FTB_WV2), -400)
            catch {
            }
        }
        try WebView_QueuePayload(g_FTB_WV2, Map("type", "niuma_save_ttyd_studio_result", "ok", ok, "error", err))
        catch {
        }
        return
    }
    if (typ = "niuma_browse_ttyd_workdir") {
        start := A_ScriptDir
        if msg.Has("start") && Trim(String(msg["start"])) != ""
            start := Trim(String(msg["start"]))
        selected := ""
        try selected := FileSelect("D", start, "选择终端工作目录")
        catch {
            selected := ""
        }
        try WebView_QueuePayload(g_FTB_WV2, Map("type", "niuma_browse_ttyd_workdir_result", "path", selected))
        catch {
        }
        return
    }
    if (typ = "niuma_save_ttyd_shell") {
        sh := msg.Has("shell") ? Trim(String(msg["shell"])) : ""
        engine := msg.Has("engine") ? Trim(String(msg["engine"])) : ""
        if (engine != "" && FuncExists("NiumaTtyd_IsCliEngine") && NiumaTtyd_IsCliEngine(engine)) {
            try {
                cf := Nmer_ResolveConfigFile()
                if (sh = "")
                    sh := "cmd.exe"
                IniWrite(sh, cf, "NiumaTtyd", engine . "_shell")
            } catch {
            }
            SetTimer(NiumaTtyd_DeferredRestartJob.Bind("", engine), -400)
        } else {
            NiumaTtyd_SaveShellIni(sh)
            SetTimer(NiumaTtyd_DeferredRestartJob.Bind("", "codex_cli"), -400)
        }
        return
    }
    if (typ = "niuma_openclaw_probe_token") {
        force := msg.Has("force") && !!msg["force"]
        SetTimer(FloatingToolbar_DeferredProbeOpenClawToken.Bind(force), -10)
        return
    }
    if (typ = "niuma_debug_event") {
        evt := msg.Has("event") ? msg["event"] : ""
        FloatingToolbar_DebugWriteEvent(evt)
        return
    }
    if (typ = "niuma_debug_pull_go") {
        SetTimer(FloatingToolbar_DeferredDebugPullGo, -10)
        return
    }
    if (typ = "niuma_ollama_start") {
        SetTimer(FloatingToolbar_DeferredOllamaStart.Bind(msg), -10)
        return
    }
    if (typ = "niuma_llm_http") {
        reqId := String(msg.Get("reqId", ""))
        method := Trim(String(msg.Get("method", "POST")))
        if (method = "")
            method := "POST"
        url := Trim(String(msg.Get("url", "")))
        body := msg.Has("body") ? String(msg["body"]) : ""
        timeoutMs := Integer(msg.Get("timeoutMs", 45000))
        if (timeoutMs < 5000)
            timeoutMs := 45000
        if (timeoutMs > 300000)
            timeoutMs := 300000
        headers := Map()
        if (msg.Has("headers") && msg["headers"] is Map)
            headers := msg["headers"]
        if (url = "") {
            try WebView_QueuePayload(g_FTB_WV2, Map("type", "niuma_llm_http_result", "reqId", reqId, "ok", false, "status", 0, "text", "", "error", "empty url"))
            catch {
            }
            return
        }
        try OutputDebug("[FTB] niuma_llm_http start reqId=" . reqId . " timeoutMs=" . timeoutMs . " bodyLen=" . StrLen(body) . " url=" . SubStr(url, 1, 96))
        catch {
        }
        HttpJsonAsync(method, url, body, FloatingToolbar_OnLlmHttpDone.Bind(reqId), Map("headers", headers, "timeoutMs", timeoutMs, "receiveTimeoutMs", timeoutMs, "tag", "niuma_llm_http", "reqId", reqId))
        return
    }
    if (typ = "niuma_llm_http_cancel") {
        reqId := String(msg.Get("reqId", ""))
        if (reqId != "") {
            try CoreAsyncHttp_Cancel(reqId)
        }
        return
    }
    if (typ = "niuma_upload_file") {
        SetTimer(FloatingToolbar_DeferredNiumaUpload.Bind(msg), -10)
        return
    }
    if (typ = "niuma_pick_folder_upload") {
        SetTimer(FloatingToolbar_DeferredNiumaPickFolderUpload.Bind(msg), -10)
        return
    }
    if (typ = "niuma_attach_context") {
        SetTimer(FloatingToolbar_DeferredNiumaAttachContext.Bind(msg), -10)
        return
    }
}

FloatingToolbar_DeferredOllamaStart(msg) {
    global g_FTB_WV2
    reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
    ret := Map("ok", false, "message", "NiumaOllama 模块未加载")
    if FuncExists("NiumaOllama_StartService")
        ret := NiumaOllama_StartService()
    if !g_FTB_WV2
        return
    try WebView_QueuePayload(g_FTB_WV2, Map(
        "type", "niuma_ollama_start_result",
        "reqId", reqId,
        "ok", !!ret.Get("ok", false),
        "message", String(ret.Get("message", ""))
    ))
    catch {
    }
}

FloatingToolbar_DeferredNiumaUpload(msg) {
    global g_FTB_WV2
    if !g_FTB_WV2
        return
    reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
    payload := msg.Has("payload") && (msg["payload"] is Map) ? msg["payload"] : msg
    try {
        ret := FloatingToolbar_SaveNiumaUpload(payload)
        WebView_QueuePayload(g_FTB_WV2, Map("type", "niuma_upload_result", "reqId", reqId, "ok", true, "file", ret))
    } catch as e {
        WebView_QueuePayload(g_FTB_WV2, Map("type", "niuma_upload_result", "reqId", reqId, "ok", false, "error", e.Message))
    }
}

FloatingToolbar_DeferredNiumaPickFolderUpload(msg) {
    global g_FTB_WV2
    if !g_FTB_WV2
        return
    reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
    payload := msg.Has("payload") && (msg["payload"] is Map) ? msg["payload"] : msg
    start := payload.Has("startDir") ? String(payload["startDir"]) : ""
    maxFiles := payload.Has("maxFiles") ? Integer(payload["maxFiles"]) : 300
    if (maxFiles <= 0)
        maxFiles := 300
    if (maxFiles > 2000)
        maxFiles := 2000

    picked := ""
    try picked := FileSelect("D", start, "选择要上传的文件夹")
    catch as e {
        try WebView_QueuePayload(g_FTB_WV2, Map("type", "niuma_pick_folder_upload_result", "reqId", reqId, "ok", false, "error", e.Message))
        return
    }
    if (Trim(String(picked)) = "") {
        try WebView_QueuePayload(g_FTB_WV2, Map("type", "niuma_pick_folder_upload_result", "reqId", reqId, "ok", false, "error", "cancelled"))
        return
    }

    root := RegExReplace(String(picked), "[\\\/]+$", "")
    SplitPath root, &folderName
    if (folderName = "")
        folderName := "folder"
    uploaded := []
    truncated := false

    try {
        baseLen := StrLen(root)
        Loop Files, root . "\*.*", "FR" {
            if (uploaded.Length >= maxFiles) {
                truncated := true
                break
            }
            p := A_LoopFilePath
            rel := SubStr(p, baseLen + 2)
            rel2 := folderName . "\" . rel
            rel2 := StrReplace(rel2, "/", "\")
            ret := FloatingToolbar_SaveNiumaUploadFromLocalPathWithRel(p, rel2)
            uploaded.Push(ret)
        }
        WebView_QueuePayload(g_FTB_WV2, Map(
            "type", "niuma_pick_folder_upload_result",
            "reqId", reqId,
            "ok", true,
            "root", root,
            "folderName", folderName,
            "truncated", truncated,
            "files", uploaded
        ))
    } catch as e2 {
        try WebView_QueuePayload(g_FTB_WV2, Map("type", "niuma_pick_folder_upload_result", "reqId", reqId, "ok", false, "error", e2.Message))
    }
}

FloatingToolbar_DeferredNiumaAttachContext(msg) {
    global g_FTB_WV2
    if !g_FTB_WV2
        return
    reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
    payload := msg.Has("payload") && (msg["payload"] is Map) ? msg["payload"] : msg
    try {
        ids := payload.Has("fileIds") ? payload["fileIds"] : []
        files := FloatingToolbar_LoadNiumaAttachContext(ids)
        WebView_QueuePayload(g_FTB_WV2, Map("type", "niuma_attach_context_result", "reqId", reqId, "ok", true, "files", files))
    } catch as e {
        WebView_QueuePayload(g_FTB_WV2, Map("type", "niuma_attach_context_result", "reqId", reqId, "ok", false, "error", e.Message))
    }
}

FloatingToolbar_BuildCdpExecuteScript(selector, action, value := "") {
    sel := FloatingToolbar_EscapeJsSingle(String(selector))
    act := StrLower(Trim(String(action)))
    val := FloatingToolbar_EscapeJsSingle(String(value))
    base := "(function(){try{var el=document.querySelector('" . sel . "');if(!el)return JSON.stringify({ok:false,error:'element_not_found'});"
    if (act = "click") {
        return base . "el.click();return JSON.stringify({ok:true,action:'click'});}catch(e){return JSON.stringify({ok:false,error:String(e.message||e)});}})();"
    }
    if (act = "input" || act = "fill" || act = "type") {
        return base . "el.focus();if('value' in el)el.value='" . val . "';else el.textContent='" . val . "';el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}));return JSON.stringify({ok:true,action:'input'});}catch(e){return JSON.stringify({ok:false,error:String(e.message||e)});}})();"
    }
    if (act = "focus") {
        return base . "el.focus();return JSON.stringify({ok:true,action:'focus'});}catch(e){return JSON.stringify({ok:false,error:String(e.message||e)});}})();"
    }
    if (act = "scroll") {
        return base . "el.scrollIntoView({block:'center',behavior:'instant'});return JSON.stringify({ok:true,action:'scroll'});}catch(e){return JSON.stringify({ok:false,error:String(e.message||e)});}})();"
    }
    return base . "return JSON.stringify({ok:false,error:'unknown_action'});}catch(e){return JSON.stringify({ok:false,error:String(e.message||e)});}})();"
}

FloatingToolbar_WrapScratchpadJs(code) {
    inner := String(code)
    if StrLen(inner) > 8000
        inner := SubStr(inner, 1, 8000)
    return "(function(){try{var __r=(function(){" . inner . "})();return JSON.stringify({ok:true,result:typeof __r==='undefined'?null:String(__r)});}catch(e){return JSON.stringify({ok:false,error:String(e.message||e)});}})();"
}

FloatingToolbar_DeferredCdpExecute(msg) {
    global g_FTB_WV2, g_NiumaMobile_WV2
    if !g_FTB_WV2
        return
    reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
    payload := msg.Has("payload") && (msg["payload"] is Map) ? msg["payload"] : msg
    txId := payload.Has("txId") ? String(payload["txId"]) : ""
    selector := payload.Has("selector") ? String(payload["selector"]) : ""
    action := payload.Has("action") ? String(payload["action"]) : "click"
    value := payload.Has("value") ? String(payload["value"]) : ""
    ok := false
    err := ""
    result := ""
    if !NiumaMobileBrowser_IsOpen() || !g_NiumaMobile_WV2 {
        err := "browser_not_open"
    } else if Trim(selector) = "" {
        err := "empty_selector"
    } else {
        js := FloatingToolbar_BuildCdpExecuteScript(selector, action, value)
        try {
            raw := g_NiumaMobile_WV2.ExecuteScriptAsync(js).await(12000)
            result := Trim(String(raw))
            ok := true
            if InStr(result, '"ok":false') || InStr(result, "element_not_found")
                ok := false
        } catch as e {
            err := e.Message
            ok := false
        }
    }
    try WebView_QueuePayload(g_FTB_WV2, Map(
        "type", "niuma_cdp_execute_result",
        "reqId", reqId,
        "ok", ok,
        "txId", txId,
        "error", err,
        "result", result
    ))
    catch {
    }
}

FloatingToolbar_DeferredScratchpadRun(msg) {
    global g_FTB_WV2, g_NiumaMobile_WV2
    if !g_FTB_WV2
        return
    reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
    payload := msg.Has("payload") && (msg["payload"] is Map) ? msg["payload"] : msg
    code := payload.Has("code") ? String(payload["code"]) : ""
    ok := false
    err := ""
    result := ""
    if !NiumaMobileBrowser_IsOpen() || !g_NiumaMobile_WV2 {
        err := "browser_not_open"
    } else if Trim(code) = "" {
        err := "empty_code"
    } else {
        js := FloatingToolbar_WrapScratchpadJs(code)
        try {
            raw := g_NiumaMobile_WV2.ExecuteScriptAsync(js).await(15000)
            result := Trim(String(raw))
            ok := true
            try {
                if SubStr(result, 1, 1) = "{"
                    parsed := Jxon_Load(result)
                    if parsed is Map {
                        if parsed.Has("ok") && !parsed["ok"] {
                            ok := false
                            err := parsed.Has("error") ? String(parsed["error"]) : "scratchpad_err"
                        } else if parsed.Has("result")
                            result := String(parsed["result"])
                    }
            } catch {
            }
        } catch as e {
            err := e.Message
            ok := false
        }
    }
    try {
        if ok
            WebView_QueuePayload(g_FTB_WV2, Map("type", "niuma_scratchpad_run_result", "reqId", reqId, "ok", true, "result", result))
        else
            WebView_QueuePayload(g_FTB_WV2, Map("type", "niuma_scratchpad_run_result", "reqId", reqId, "ok", false, "error", err ? err : "scratchpad_failed", "result", result))
    } catch {
    }
}

FloatingToolbar_NiumaDataDir() {
    return Nmer_NiumaChatDataDir()
}

FloatingToolbar_NiumaUploadDir() {
    return FloatingToolbar_NiumaDataDir() . "\uploads"
}

FloatingToolbar_NiumaAttachMetaFile() {
    return FloatingToolbar_NiumaDataDir() . "\attachments.json"
}

FloatingToolbar_Base64DecodeToBuffer(b64) {
    s := Trim(String(b64))
    if (s = "")
        throw Error("empty base64")
    need := 0
    if !DllCall("crypt32\CryptStringToBinaryW", "WStr", s, "UInt", 0, "UInt", 0x1, "Ptr", 0, "UInt*", &need, "Ptr", 0, "Ptr", 0)
        throw Error("base64 decode size failed")
    if (need <= 0)
        throw Error("decoded size zero")
    buf := Buffer(need, 0)
    if !DllCall("crypt32\CryptStringToBinaryW", "WStr", s, "UInt", 0, "UInt", 0x1, "Ptr", buf.Ptr, "UInt*", &need, "Ptr", 0, "Ptr", 0)
        throw Error("base64 decode failed")
    return buf
}

FloatingToolbar_IsTextExt(name) {
    n := StrLower(String(name))
    p := InStr(n, ".",, -10)
    ext := (p > 0) ? SubStr(n, p + 1) : ""
    return RegExMatch(ext, "i)^(md|txt|json|csv|log|xml|yml|yaml|ini|cfg|js|ts|py|java|go|rs|html|css|sql|bat|cmd|ps1|psm1|sh|toml|env)$")
}

FloatingToolbar_LoadNiumaAttachMeta() {
    fp := FloatingToolbar_NiumaAttachMetaFile()
    if !FileExist(fp)
        return Map("version", 1, "files", Map())
    raw := FileRead(fp, "UTF-8")
    o := Jxon_Load(raw)
    if !(o is Map)
        return Map("version", 1, "files", Map())
    if !o.Has("files") || !(o["files"] is Map)
        o["files"] := Map()
    return o
}

FloatingToolbar_SaveNiumaAttachMeta(meta) {
    dir := FloatingToolbar_NiumaDataDir()
    try DirCreate(dir)
    fp := FloatingToolbar_NiumaAttachMetaFile()
    meta["updatedAt"] := FormatTime(, "yyyy-MM-ddTHH:mm:ss")
    try FileDelete(fp)
    FileAppend(Jxon_Dump(meta), fp, "UTF-8")
}

FloatingToolbar_SaveNiumaUpload(payload) {
    name := payload.Has("name") ? String(payload["name"]) : "file"
    rel := payload.Has("relativePath") ? String(payload["relativePath"]) : name
    mime := payload.Has("type") ? String(payload["type"]) : ""
    b64 := payload.Has("contentBase64") ? String(payload["contentBase64"]) : ""
    if (Trim(b64) = "")
        throw Error("Missing contentBase64")
    buf := FloatingToolbar_Base64DecodeToBuffer(b64)
    if (buf.Size <= 0)
        throw Error("Empty file")
    if (buf.Size > 20 * 1024 * 1024)
        throw Error("File too large (>20MB)")
    uid := "att_" . FormatTime(, "yyyyMMddHHmmss") . "_" . A_TickCount
    safe := RegExReplace(name, "[^\w\.\-\(\) ]", "_")
    upDir := FloatingToolbar_NiumaUploadDir()
    try DirCreate(upDir)
    stored := uid . "_" . safe
    fp := upDir . "\" . stored
    f := FileOpen(fp, "w")
    if !IsObject(f)
        throw Error("open file failed")
    f.RawWrite(buf, buf.Size)
    f.Close()
    excerpt := ""
    if (InStr(StrLower(mime), "text/") = 1 || FloatingToolbar_IsTextExt(name)) {
        try excerpt := Trim(StrGet(buf, "UTF-8"))
        if (StrLen(excerpt) > 12000)
            excerpt := SubStr(excerpt, 1, 12000)
    }
    meta := FloatingToolbar_LoadNiumaAttachMeta()
    files := meta["files"]
    files[uid] := Map(
        "id", uid,
        "name", name,
        "relativePath", rel,
        "type", mime,
        "size", buf.Size,
        "storedName", stored,
        "storedPath", fp,
        "uploadedAt", FormatTime(, "yyyy-MM-ddTHH:mm:ss"),
        "textExcerpt", excerpt
    )
    FloatingToolbar_SaveNiumaAttachMeta(meta)
    return Map("id", uid, "name", name, "relativePath", rel, "type", mime, "size", buf.Size)
}

FloatingToolbar_SaveNiumaUploadFromLocalPath(path) {
    p := Trim(String(path))
    if (p = "")
        throw Error("empty path")
    if !FileExist(p)
        throw Error("path not found: " . p)
    attr := FileExist(p)
    if (InStr(attr, "D"))
        throw Error("folder not supported: " . p)
    sz := FileGetSize(p)
    if (sz <= 0)
        throw Error("empty file: " . p)
    if (sz > 20 * 1024 * 1024)
        throw Error("file too large (>20MB): " . p)

    SplitPath p, &name
    if (name = "")
        name := "file"
    uid := "att_" . FormatTime(, "yyyyMMddHHmmss") . "_" . A_TickCount
    safe := RegExReplace(name, "[^\w\.\-\(\) ]", "_")
    upDir := FloatingToolbar_NiumaUploadDir()
    try DirCreate(upDir)
    stored := uid . "_" . safe
    fp := upDir . "\" . stored
    FileCopy(p, fp, true)

    excerpt := ""
    if FloatingToolbar_IsTextExt(name) {
        try excerpt := Trim(FileRead(p, "UTF-8"))
        if (StrLen(excerpt) > 12000)
            excerpt := SubStr(excerpt, 1, 12000)
    }

    meta := FloatingToolbar_LoadNiumaAttachMeta()
    files := meta["files"]
    files[uid] := Map(
        "id", uid,
        "name", name,
        "relativePath", name,
        "type", "",
        "size", sz,
        "storedName", stored,
        "storedPath", fp,
        "uploadedAt", FormatTime(, "yyyy-MM-ddTHH:mm:ss"),
        "textExcerpt", excerpt
    )
    FloatingToolbar_SaveNiumaAttachMeta(meta)
    return Map("id", uid, "name", name, "relativePath", name, "type", "", "size", sz)
}

FloatingToolbar_SaveNiumaUploadFromLocalPathWithRel(path, relPath) {
    p := Trim(String(path))
    rel := Trim(String(relPath))
    if (p = "")
        throw Error("empty path")
    if (rel = "")
        rel := ""
    if !FileExist(p)
        throw Error("path not found: " . p)
    attr := FileExist(p)
    if (InStr(attr, "D"))
        throw Error("folder not supported: " . p)
    sz := FileGetSize(p)
    if (sz <= 0)
        throw Error("empty file: " . p)
    if (sz > 20 * 1024 * 1024)
        throw Error("file too large (>20MB): " . p)

    SplitPath p, &name
    if (name = "")
        name := "file"
    uid := "att_" . FormatTime(, "yyyyMMddHHmmss") . "_" . A_TickCount
    safe := RegExReplace(name, "[^\w\.\-\(\) ]", "_")
    upDir := FloatingToolbar_NiumaUploadDir()
    try DirCreate(upDir)
    stored := uid . "_" . safe
    fp := upDir . "\" . stored
    FileCopy(p, fp, true)

    excerpt := ""
    if FloatingToolbar_IsTextExt(name) {
        try excerpt := Trim(FileRead(p, "UTF-8"))
        if (StrLen(excerpt) > 12000)
            excerpt := SubStr(excerpt, 1, 12000)
    }

    meta := FloatingToolbar_LoadNiumaAttachMeta()
    files := meta["files"]
    files[uid] := Map(
        "id", uid,
        "name", name,
        "relativePath", rel != "" ? rel : name,
        "type", "",
        "size", sz,
        "storedName", stored,
        "storedPath", fp,
        "uploadedAt", FormatTime(, "yyyy-MM-ddTHH:mm:ss"),
        "textExcerpt", excerpt
    )
    FloatingToolbar_SaveNiumaAttachMeta(meta)
    return Map("id", uid, "name", name, "relativePath", rel != "" ? rel : name, "type", "", "size", sz)
}

FloatingToolbar_LoadNiumaAttachContext(ids) {
    meta := FloatingToolbar_LoadNiumaAttachMeta()
    files := meta["files"]
    out := []
    if !(ids is Array)
        return out
    for _, id in ids {
        sid := String(id)
        if !files.Has(sid)
            continue
        x := files[sid]
        ex := x.Has("textExcerpt") ? String(x["textExcerpt"]) : ""
        if (StrLen(ex) > 6000)
            ex := SubStr(ex, 1, 6000)
        out.Push(Map(
            "id", sid,
            "name", x.Has("name") ? String(x["name"]) : "file",
            "relativePath", x.Has("relativePath") ? String(x["relativePath"]) : (x.Has("name") ? String(x["name"]) : "file"),
            "type", x.Has("type") ? String(x["type"]) : "",
            "size", x.Has("size") ? Integer(x["size"]) : 0,
            "uploadedAt", x.Has("uploadedAt") ? String(x["uploadedAt"]) : "",
            "textExcerpt", ex
        ))
    }
    return out
}

FloatingToolbar_DeferredProbeOpenClawToken(force := false) {
    try FloatingToolbar_ProbeOpenClawGatewayToken(!!force)
}

FloatingToolbar_DebugWriteEvent(evt) {
    try {
        line := ""
        if (evt is Map)
            line := Jxon_Dump(evt)
        else if (evt is Object)
            line := Jxon_Dump(evt)
        else
            line := String(evt)
        line := Trim(line)
        if (line = "")
            return
        dir := Nmer_DebugDir()
        try DirCreate(dir)
        fp := Nmer_OpenClawTimelinePath()
        FileAppend(line . "`n", fp, "UTF-8")
    } catch {
    }
}

FloatingToolbar_DeferredDebugPullGo() {
    global g_FTB_WV2, g_AhkInterface
    if !g_FTB_WV2
        return
    try {
        base := "http://127.0.0.1:8080"
        statusRaw := g_AhkInterface.HttpRequest("GET", base . "/v1/status", "", "")
        dbgRaw := g_AhkInterface.HttpRequest("GET", base . "/v1/niuma/debug", "", "")
        data := Map("status", statusRaw, "debug", dbgRaw, "fetchedAt", A_Now)
        WebView_QueuePayload(g_FTB_WV2, Map("type", "niuma_debug_go_snapshot", "data", data))
    } catch {
    }
}

FloatingToolbar_ProbeOpenClawGatewayToken(force := false) {
    global g_FTB_WV2
    if !g_FTB_WV2
        return

    token := ""
    source := ""

    try {
        envTok := Trim(String(EnvGet("OPENCLAW_GATEWAY_TOKEN")))
        if (envTok != "") {
            token := envTok
            source := "env:OPENCLAW_GATEWAY_TOKEN"
        }
    } catch {
    }

    if (token = "") {
        info := FloatingToolbar_ReadOpenClawGatewayToken()
        if (info is Map) {
            try token := Trim(String(info.Has("token") ? info["token"] : ""))
            catch {
                token := ""
            }
            try source := String(info.Has("source") ? info["source"] : "")
            catch {
                source := ""
            }
        }
    }

    try WebView_QueuePayload(g_FTB_WV2, Map(
        "type", "openclaw_host_token_probe",
        "token", token,
        "source", source,
        "force", !!force
    ))
}

FloatingToolbar_ReadOpenClawGatewayToken() {
    userProfile := ""
    try userProfile := Trim(String(EnvGet("USERPROFILE")))
    if (userProfile = "") {
        homeDrive := ""
        homePath := ""
        try homeDrive := Trim(String(EnvGet("HOMEDRIVE")))
        try homePath := Trim(String(EnvGet("HOMEPATH")))
        userProfile := homeDrive . homePath
    }
    candidates := [
        userProfile . "\.openclaw\openclaw.json",
        A_AppData . "\openclaw\openclaw.json",
        A_AppData . "\clawhub\openclaw.json"
    ]
    for _, path in candidates {
        try {
            if !FileExist(path)
                continue
            raw := FileRead(path, "UTF-8")
            if (Trim(raw) = "")
                continue
            cfg := Jxon_Load(raw)
            tok := FloatingToolbar_ExtractOpenClawGatewayToken(cfg)
            if (tok != "")
                return Map("token", tok, "source", path)
        } catch {
        }
    }
    return Map("token", "", "source", "")
}

FloatingToolbar_ExtractOpenClawGatewayToken(cfg) {
    if !(cfg is Map)
        return ""
    try {
        if cfg.Has("gateway") {
            gw := cfg["gateway"]
            if (gw is Map) {
                if gw.Has("auth") {
                    auth := gw["auth"]
                    if (auth is Map) {
                        if auth.Has("token") {
                            tok := Trim(String(auth["token"]))
                            if (tok != "")
                                return tok
                        }
                    }
                }
                if gw.Has("token") {
                    tok2 := Trim(String(gw["token"]))
                    if (tok2 != "")
                        return tok2
                }
            }
        }
    } catch {
    }
    return ""
}

; 鎸?WebView 瀹㈡埛鍖?CSS 鍍忕礌瀹藉害璋冩暣鎶藉眽锛堜繚鎸佺獥鍙ｅ彸缂樹笉鍔級
FloatingToolbar_ApplyDrawerClientWidth(clientW) {
    global FloatingToolbarGUI, FloatingToolbarChatDrawerOpen, FloatingToolbarChatDrawerWidth
    global FloatingToolbarWindowX, FloatingToolbarWindowY

    if (!FloatingToolbarGUI || !FloatingToolbarChatDrawerOpen)
        return
    eff := FloatingToolbar_EffectiveScale()
    if (eff < 0.01)
        eff := 1.0
    logical := Round(clientW / eff)
    if (logical < 560)
        logical := 560
    if (logical > 1200)
        logical := 1200
    FloatingToolbarChatDrawerWidth := logical
    newW := FloatingToolbarCalculateWidth()
    newH := FloatingToolbarCalculateHeight()
    try FloatingToolbarGUI.GetPos(&gx, &gy, &gw, &gh)
    catch as _e {
        gx := FloatingToolbarWindowX
        gy := FloatingToolbarWindowY
        gw := newW
        gh := newH
    }
    rightEdge := gx + gw
    newX := rightEdge - newW
    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    if (newX < vl)
        newX := vl
    if (newX + newW > vr)
        newX := vr - newW
    FloatingToolbarWindowX := newX
    try FloatingToolbarGUI.Move(newX, gy, newW, newH)
    catch as _e2 {
    }
    if FloatingToolbarChatDrawerOpen
        FloatingToolbar_EnsureDrawerInWorkArea()
    else {
        FloatingToolbarApplyRoundedCorners()
        FloatingToolbar_ApplyWebViewBounds()
    }
}

FloatingToolbarSaveDrawerWidth() {
    global FloatingToolbarChatDrawerWidth, ConfigFile
    try {
        if !IsSet(ConfigFile) || ConfigFile = ""
            ConfigFile := Nmer_ResolveConfigFile()
        IniWrite(String(FloatingToolbarChatDrawerWidth), ConfigFile, "FloatingToolbar", "ChatDrawerWidth")
    } catch as _e {
    }
}

FloatingToolbarLoadDrawerWidth() {
    global FloatingToolbarChatDrawerWidth, ConfigFile
    try {
        if !IsSet(ConfigFile) || ConfigFile = ""
            ConfigFile := Nmer_ResolveConfigFile()
        defW := FloatingToolbar_ChatDrawerDefaultWidth()
        v := IniRead(ConfigFile, "FloatingToolbar", "ChatDrawerWidth", String(defW))
        iv := Integer(v)
        if (iv >= 560 && iv <= 1200)
            FloatingToolbarChatDrawerWidth := (iv <= 620) ? defW : iv
        else if (iv >= 380 && iv < 560)
            FloatingToolbarChatDrawerWidth := defW
    } catch as _e {
    }
}

FloatingToolbarSetChatDrawerState(open, force := false) {
    global FloatingToolbarGUI, FloatingToolbarChatDrawerOpen, AppearanceActivationMode
    global FloatingToolbarWindowX, FloatingToolbarWindowY, FloatingToolbarIsVisible
    global FloatingToolbarLastClosedX, FloatingToolbarLastClosedY

    open := !!open
    if (FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode) != "toolbar") {
        if (open && FuncExists("CommandPalette_AiLog"))
            try CommandPalette_AiLog("set_drawer_blocked", "reason=not_toolbar actMode=" . String(AppearanceActivationMode))
            catch {
            }
        open := false
    }
    if (!FloatingToolbarGUI) {
        if (open && FuncExists("CommandPalette_AiLog"))
            try CommandPalette_AiLog("set_drawer_blocked", "reason=no_FloatingToolbarGUI")
            catch {
            }
        return
    }
    if (!force && open = !!FloatingToolbarChatDrawerOpen) {
        if (!open)
            return
        curW := 0
        try FloatingToolbarGUI.GetPos(, , &curW, )
        expW := FloatingToolbarCalculateWidth()
        if (curW > 0 && Abs(curW - expW) <= 12) {
            FloatingToolbar_NotifyWebDrawerState(true)
            return
        }
    }

    try FloatingToolbarGUI.GetPos(&oldX, &oldY, &oldW, &oldH)
    catch {
        oldX := FloatingToolbarWindowX
        oldY := FloatingToolbarWindowY
        oldW := FloatingToolbarCalculateWidth()
        oldH := FloatingToolbarCalculateHeight()
    }

    if (open && !FloatingToolbarChatDrawerOpen) {
        FloatingToolbarLastClosedX := oldX
        FloatingToolbarLastClosedY := oldY
    }

    if !open {
        try {
            global g_FTB_WV2, g_FTB_WV2_Ready
            if (g_FTB_WV2 && g_FTB_WV2_Ready)
                WebView_QueuePayload(g_FTB_WV2, Map("type", "niuma_llm_http_cancel", "reqId", "*"))
        } catch {
        }
        try {
            global g_FTB_WV2, g_FTB_WV2_Ready
            if (g_FTB_WV2 && g_FTB_WV2_Ready)
                WebView_QueuePayload(g_FTB_WV2, Map("type", "host_browser_agent_reset"))
        } catch {
        }
        NiumaMobileBrowser_Close()
    }

    if open {
        try FloatingToolbarExitCompactMode()
        catch {
        }
    }
    FloatingToolbarChatDrawerOpen := open
    newW := FloatingToolbarCalculateWidth()
    newH := FloatingToolbarCalculateHeight()

    ftHwnd := FloatingToolbarGUI.Hwnd
    ScreenWorkArea_GetBounds(&wl, &wt, &ww, &wh, ftHwnd)
    wr := wl + ww
    wb := wt + wh
    rightEdge := oldX + oldW

    if (open) {
        newX := rightEdge - newW
        newY := wt
    } else {
        if (FloatingToolbarLastClosedX != 0 || FloatingToolbarLastClosedY != 0) {
            newX := FloatingToolbarLastClosedX
            newY := FloatingToolbarLastClosedY
        } else {
            newX := rightEdge - newW
            newY := wb - newH
        }
    }

    FloatingToolbar_ClampWindowToWorkArea(&newX, &newY, newW, newH, ftHwnd)

    FloatingToolbarWindowX := newX
    FloatingToolbarWindowY := newY
    FloatingToolbarGUI.Move(newX, newY, newW, newH)
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
    FloatingToolbarPushScaleStateToWeb(FloatingToolbarScale)
    SaveFloatingToolbarPosition()
    FloatingToolbar_NotifyWebDrawerState(open)
    if open
        FloatingToolbar_PushWorkAreaInsetsToWeb()
    if !open
        SetTimer(FloatingToolbar_TryReturnToHoleAfterNiuma, -50)
}

FloatingToolbar_ScheduleNiumaDrawerOpen(delayMs := 380) {
    global g_FTB_PendingOpenNiumaDrawer
    if !g_FTB_PendingOpenNiumaDrawer
        return
    SetTimer(FloatingToolbar_RunNiumaHandoffOpen, 0)
    SetTimer(FloatingToolbar_RunNiumaHandoffOpen, -Max(60, Integer(delayMs)))
}

FloatingToolbar_RunNiumaHandoffOpen(*) {
    global g_FTB_PendingOpenNiumaDrawer
    if !g_FTB_PendingOpenNiumaDrawer
        return
    FloatingToolbar_OpenNiumaChatDrawer(true)
}

FloatingToolbar_StartPaletteAiStream(msg) {
    if !(msg is Map)
        return
    reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
    q := msg.Has("query") ? String(msg["query"]) : ""
    prov := msg.Has("provider") ? String(msg["provider"]) : ""
    if (reqId = "" || Trim(q) = "")
        return
    if FuncExists("CommandPalette_PostFtbPaletteAiStream") {
        try CommandPalette_PostFtbPaletteAiStream(reqId, q, prov)
        catch {
        }
        return
    }
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    if !(g_FTB_WV2 && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady) {
        if FuncExists("CommandPalette_AiLog")
            try CommandPalette_AiLog("palette_stream_not_ready", "reqId=" . reqId)
            catch {
            }
        return
    }
    payload := Map("type", "host_palette_ai_stream", "reqId", reqId, "query", q, "provider", prov, "openDrawer", false)
    try WebView_QueuePayload(g_FTB_WV2, payload)
    catch as eQ {
        if FuncExists("CommandPalette_OnNiumaPaletteAiError")
            try CommandPalette_OnNiumaPaletteAiError(Map("reqId", reqId, "message", eQ.Message))
            catch {
            }
    }
}

FloatingToolbar_NotifyWebDrawerState(open := false) {
    global g_FTB_WV2, g_FTB_WV2_Ready
    if !(g_FTB_WV2 && g_FTB_WV2_Ready)
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "host_set_drawer", "open", !!open))
    catch as _e {
    }
}

FloatingToolbar_OnLlmHttpDone(reqId, ret) {
    global g_FTB_WV2
    ok := false
    status := 0
    text := ""
    err := ""
    if (ret is Map) {
        ok := !!ret.Get("ok", false)
        status := Integer(ret.Get("status", 0))
        text := String(ret.Get("text", ""))
        err := String(ret.Get("error", ""))
        if (!ok) {
            if (text != "")
                err := (err != "" ? err . "`n" : "") . SubStr(text, 1, 600)
            else if (err = "" && status >= 400)
                err := "HTTP " . status
        }
    } else
        err := "invalid response"
    try OutputDebug("[FTB] niuma_llm_http done reqId=" . reqId . " ok=" . (ok ? 1 : 0) . " status=" . status . " textLen=" . StrLen(text))
    catch {
    }
    if !g_FTB_WV2
        return
    payload := Map(
        "type", "niuma_llm_http_result",
        "reqId", String(reqId),
        "ok", ok,
        "status", status,
        "text", SubStr(text, 1, 400000),
        "error", SubStr(err, 1, 4000)
    )
    try {
        if FuncExists("WebView_DumpJson") && FuncExists("WebView_QueueJson") {
            json := WebView_DumpJson(payload)
            if (json != "") {
                WebView_QueueJson(g_FTB_WV2, json)
                return
            }
        }
    } catch {
    }
    try WebView_QueuePayload(g_FTB_WV2, payload)
    catch {
    }
}

FloatingToolbar_PushTtydStudioConfig(*) {
    global g_FTB_WV2
    if !g_FTB_WV2
        return
    ttyd := Map()
    try {
        if FuncExists("UserStudio_TtydPayloadForWeb")
            ttyd := UserStudio_TtydPayloadForWeb()
    } catch {
    }
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "ttyd_studio_config", "ttyd", ttyd))
    catch {
    }
}

; 从设置中心「智能定制」跳转：打开 Niuma Chat 并显示终端定制面板（startChat=1 时自动进入 AI 对话）
FloatingToolbar_OpenNiumaChatTtydCustomize(startChat := false) {
    global g_FTB_WV2, g_FTB_WV2_Ready, FloatingToolbarIsVisible, g_FTB_TtydOpenStartChat
    g_FTB_TtydOpenStartChat := !!startChat
    try FloatingToolbar_ClearOverlaySuppression()
    catch {
    }
    try ShowFloatingToolbar()
    catch {
    }
    if !FloatingToolbarIsVisible {
        SetTimer(FloatingToolbar_OpenNiumaChatTtydCustomize, -280)
        return
    }
    try FloatingToolbarSetChatDrawerState(true, true)
    catch {
    }
    try FloatingToolbar_NotifyWebDrawerState(true)
    catch {
    }
    SetTimer(FloatingToolbar_NiumaDrawerHandoffRetry, -520)
    SetTimer(FloatingToolbar_DeferredOpenTtydCustomize, -360)
    SetTimer(FloatingToolbar_DeferredOpenTtydCustomize, -900)
}

FloatingToolbar_GetStudioLlm() {
    llm := Map("provider", "openai", "apiKey", "", "baseUrl", "https://api.openai.com/v1", "model", "gpt-4o-mini")
    if FuncExists("UserStudio_Load")
        try UserStudio_Load()
        catch {
        }
    if FuncExists("UserStudio_Get") {
        try {
            doc := UserStudio_Get()
            if (doc.Has("llm") && doc["llm"] is Map)
                llm := doc["llm"]
            if (Trim(String(llm.Get("apiKey", ""))) = "") {
                opt := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
                if (opt.Has("llmApiKeys") && opt["llmApiKeys"] is Map) {
                    for k, v in opt["llmApiKeys"] {
                        vk := UserStudio_NormalizeApiKey(v)
                        if (vk = "")
                            continue
                        llm["provider"] := UserStudio_NormalizeLlmProvider(k)
                        llm["apiKey"] := vk
                        pre := UserStudio_LlmPresetFor(llm["provider"])
                        if (Trim(String(llm.Get("baseUrl", ""))) = "")
                            llm["baseUrl"] := pre.Get("baseUrl", "")
                        if (Trim(String(llm.Get("model", ""))) = "")
                            llm["model"] := pre.Get("model", "")
                        break
                    }
                }
            }
        } catch {
        }
    }
    return llm
}

FloatingToolbar_GetStudioApiKeys() {
    keys := Map()
    if FuncExists("UserStudio_Load")
        try UserStudio_Load()
        catch {
        }
    if FuncExists("UserStudio_Get") {
        try {
            doc := UserStudio_Get()
            opt := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
            if (opt.Has("llmApiKeys") && opt["llmApiKeys"] is Map) {
                for k, v in opt["llmApiKeys"] {
                    pk := UserStudio_NormalizeLlmProvider(k)
                    vk := UserStudio_NormalizeApiKey(v)
                    if (vk != "")
                        keys[pk] := vk
                }
            }
        } catch {
        }
    }
    return keys
}

FloatingToolbar_PushStudioLlmOnReady(*) {
    global g_FTB_WV2_Ready
    if !g_FTB_WV2_Ready
        return
    llm := FloatingToolbar_GetStudioLlm()
    if Trim(String(llm.Get("apiKey", ""))) != "" {
        try FloatingToolbar_PushStudioLlmToChat(llm, "", false)
        catch {
        }
    }
}

FloatingToolbar_DeferredOpenTtydCustomize(*) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_TtydOpenStartChat
    if !g_FTB_WV2_Ready || !g_FTB_WV2
        return
    llm := FloatingToolbar_GetStudioLlm()
    startChat := false
    if IsSet(g_FTB_TtydOpenStartChat)
        startChat := !!g_FTB_TtydOpenStartChat
    g_FTB_TtydOpenStartChat := false
    msg := Map("type", "host_open_ttyd_customize")
    if Trim(String(llm.Get("apiKey", ""))) != ""
        msg["llm"] := llm
    else
        msg["requestLlmExport"] := true
    if startChat
        msg["startChat"] := true
    try WebView_QueuePayload(g_FTB_WV2, msg)
    catch {
    }
    try FloatingToolbar_PushTtydStudioConfig()
    catch {
    }
    if Trim(String(llm.Get("apiKey", ""))) != "" {
        try FloatingToolbar_PushStudioLlmToChat(llm, "", false)
        catch {
        }
    } else {
        try SetTimer(FloatingToolbar_RequestNiumaLlmExport, -250)
        catch {
        }
    }
}

FloatingToolbar_StudioContextPayload() {
    if FuncExists("UserStudio_Load")
        try UserStudio_Load()
    ctx := Map("autoInject", true, "systemPrompt", "", "installRoot", A_ScriptDir, "scriptDir", A_ScriptDir)
    if FuncExists("UserStudio_GetNiumaContext") {
        try ctx := UserStudio_GetNiumaContext()
        catch {
        }
    }
    return Map(
        "autoInjectContext", ctx.Get("autoInject", true),
        "systemPrompt", Trim(String(ctx.Get("systemPrompt", ""))),
        "installRoot", Trim(String(ctx.Get("installRoot", A_ScriptDir))),
        "scriptDir", Trim(String(ctx.Get("scriptDir", A_ScriptDir)))
    )
}

FloatingToolbar_PushStudioContextToChat() {
    global g_FTB_WV2
    if !g_FTB_WV2
        return
    payload := FloatingToolbar_StudioContextPayload()
    try WebView_QueuePayload(g_FTB_WV2, Map(
        "type", "host_push_studio_context",
        "autoInjectContext", payload.Get("autoInjectContext", true),
        "systemPrompt", payload.Get("systemPrompt", ""),
        "installRoot", payload.Get("installRoot", A_ScriptDir),
        "scriptDir", payload.Get("scriptDir", A_ScriptDir)
    ))
    catch {
    }
}

FloatingToolbar_PushStudioLlmToChat(llm, prompt := "", autoSend := false) {
    global g_FTB_WV2
    if !g_FTB_WV2 || !(llm is Map)
        return
    try FloatingToolbar_PushStudioContextToChat()
    catch {
    }
    ctx := Map("autoInject", true, "systemPrompt", "")
    if FuncExists("UserStudio_GetNiumaContext") {
        try ctx := UserStudio_GetNiumaContext()
        catch {
        }
    }
    syncKeys := FloatingToolbar_GetStudioApiKeys()
    try WebView_QueuePayload(g_FTB_WV2, Map(
        "type", "host_apply_studio_llm",
        "llm", Map(
            "provider", llm.Get("provider", "openai"),
            "apiKey", llm.Get("apiKey", ""),
            "baseUrl", llm.Get("baseUrl", ""),
            "model", llm.Get("model", "")
        ),
        "apiKeys", syncKeys,
        "prompt", Trim(String(prompt)),
        "autoSend", !!autoSend,
        "autoInjectContext", ctx.Get("autoInject", true),
        "systemPrompt", Trim(String(ctx.Get("systemPrompt", "")))
    ))
    catch {
    }
}

; 从设置中心「智能定制」进入提问：拉起 Niuma Chat 并注入已保存的 API
FloatingToolbar_OpenNiumaChatAsk(prompt := "", autoSend := false) {
    global g_FTB_WV2, g_FTB_WV2_Ready, FloatingToolbarIsVisible
    if FuncExists("UserStudio_Load")
        try UserStudio_Load()
    llm := Map("provider", "openai", "apiKey", "", "baseUrl", "https://api.openai.com/v1", "model", "gpt-4o-mini")
    if FuncExists("UserStudio_Get") {
        try {
            doc := UserStudio_Get()
            if (doc.Has("llm") && doc["llm"] is Map)
                llm := doc["llm"]
        } catch {
        }
    }
    try FloatingToolbar_ClearOverlaySuppression()
    catch {
    }
    try ShowFloatingToolbar()
    catch {
    }
    if !FloatingToolbarIsVisible {
        SetTimer(FloatingToolbar_OpenNiumaChatAsk.Bind(prompt, autoSend), -320)
        return
    }
    try FloatingToolbarSetChatDrawerState(true, true)
    catch {
    }
    try FloatingToolbar_NotifyWebDrawerState(true)
    catch {
    }
    SetTimer(FloatingToolbar_NiumaDrawerHandoffRetry, -520)
    SetTimer(FloatingToolbar_DeferredPushStudioAsk.Bind(llm, prompt, autoSend), -450)
    SetTimer(FloatingToolbar_DeferredPushStudioAsk.Bind(llm, prompt, autoSend), -950)
}

; 设置中心「同步 API」：从 Niuma Chat localStorage 导出到 user_studio.json
FloatingToolbar_RequestNiumaLlmExport() {
    global g_FTB_WV2, g_FTB_WV2_Ready, FloatingToolbarIsVisible
    try ShowFloatingToolbar()
    catch {
    }
    if !FloatingToolbarIsVisible {
        SetTimer(FloatingToolbar_RequestNiumaLlmExport, -350)
        return
    }
    if !g_FTB_WV2_Ready || !g_FTB_WV2 {
        SetTimer(FloatingToolbar_RequestNiumaLlmExport, -350)
        return
    }
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "host_request_llm_export"))
    catch {
    }
    SetTimer(FloatingToolbar_DeferredRequestLlmExport, -500)
}

FloatingToolbar_DeferredRequestLlmExport(*) {
    global g_FTB_WV2, g_FTB_WV2_Ready
    if !g_FTB_WV2_Ready || !g_FTB_WV2
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "host_request_llm_export"))
    catch {
    }
}

FloatingToolbar_DeferredPushStudioAsk(llm, prompt, autoSend) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingStudioAsk
    pr := Trim(String(prompt))
    if !g_FTB_WV2 {
        g_FTB_PendingStudioAsk := Map("llm", llm, "prompt", pr, "autoSend", !!autoSend, "tries", 0)
        SetTimer(FloatingToolbar_RetryPendingStudioAsk, -400)
        return
    }
    if !(g_FTB_WV2_Ready && g_FTB_WV2_FrameReady) {
        tries := 0
        if (g_FTB_PendingStudioAsk is Map && g_FTB_PendingStudioAsk.Has("tries"))
            tries := Integer(g_FTB_PendingStudioAsk["tries"])
        g_FTB_PendingStudioAsk := Map("llm", llm, "prompt", pr, "autoSend", !!autoSend, "tries", tries)
        SetTimer(FloatingToolbar_RetryPendingStudioAsk, -400)
        if (pr != "")
            try FloatingToolbar_SendTextToNiumaChat(pr, !!autoSend, false, true)
            catch {
            }
        return
    }
    g_FTB_PendingStudioAsk := 0
    FloatingToolbar_PushStudioLlmToChat(llm, pr, autoSend)
    if (pr != "" && !autoSend)
        try FloatingToolbar_SendTextToNiumaChat(pr, false, false, false)
        catch {
        }
}

FloatingToolbar_RetryPendingStudioAsk(*) {
    global g_FTB_PendingStudioAsk
    if !(g_FTB_PendingStudioAsk is Map)
        return
    pending := g_FTB_PendingStudioAsk
    tries := pending.Has("tries") ? Integer(pending["tries"]) : 0
    if (tries >= 24) {
        g_FTB_PendingStudioAsk := 0
        return
    }
    pending["tries"] := tries + 1
    g_FTB_PendingStudioAsk := pending
    llm := pending.Has("llm") ? pending["llm"] : Map()
    pr := pending.Has("prompt") ? String(pending["prompt"]) : ""
    autoSend := pending.Has("autoSend") ? !!pending["autoSend"] : false
    FloatingToolbar_DeferredPushStudioAsk(llm, pr, autoSend)
}

FloatingToolbar_OpenNiumaChatDrawer(open := true) {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, AppearanceActivationMode
    global FloatingToolbarChatDrawerOpen, g_FTB_PendingOpenNiumaDrawer, g_FTB_NiumaHandoffOpening
    global g_FTB_WV2_Ready
    open := !!open
    if (FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode) != "toolbar") {
        if FuncExists("CommandPalette_AiLog")
            try CommandPalette_AiLog("open_drawer_blocked", "open=" . (open ? 1 : 0) . " actMode=" . String(AppearanceActivationMode))
            catch {
            }
        return false
    }
    if open {
        g_FTB_NiumaHandoffOpening := true
        try FloatingToolbar_MarkNiumaHandoffActive(4000)
        catch {
        }
        try FloatingToolbar_ClearOverlaySuppression()
        catch {
        }
        if !(IsObject(FloatingToolbarGUI) && FloatingToolbarGUI && FloatingToolbarIsVisible) {
            try FloatingToolbar_ShowForActivationMode()
            catch {
                global g_FTB_PendingOpenNiumaDrawer
                g_FTB_PendingOpenNiumaDrawer := true
                try ShowFloatingToolbar()
                catch {
                }
            }
        }
    }
    forceApply := open && !!g_FTB_NiumaHandoffOpening
    FloatingToolbarSetChatDrawerState(open, forceApply)
    if open {
        if (g_FTB_WV2_Ready && FloatingToolbarIsVisible)
            FloatingToolbar_NotifyWebDrawerState(true)
        SetTimer((*) => (g_FTB_NiumaHandoffOpening := false), -1200)
        SetTimer(FloatingToolbar_NiumaDrawerHandoffRetry, -520)
        SetTimer(FloatingToolbar_NiumaDrawerHandoffRetry, -1100)
    } else
        g_FTB_NiumaHandoffOpening := false
    return true
}

FloatingToolbar_NiumaDrawerHandoffRetry(*) {
    global FloatingToolbarChatDrawerOpen, FloatingToolbarIsVisible, g_FTB_WV2_Ready, AppearanceActivationMode
    if (FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode) != "toolbar")
        return
    if !FloatingToolbarIsVisible || !g_FTB_WV2_Ready
        return
    if !FloatingToolbarChatDrawerOpen {
        try FloatingToolbar_OpenNiumaChatDrawer(true)
        return
    }
    global g_FTB_PendingOpenNiumaDrawer
    g_FTB_PendingOpenNiumaDrawer := false
    FloatingToolbarSetChatDrawerState(true, true)
    try FloatingToolbar_NotifyWebDrawerState(true)
    catch {
    }
}

FloatingToolbarCollapseTransientUi(forceResize := true) {
    global g_FTB_WV2, FloatingToolbarGUI, FloatingToolbarChatDrawerOpen

    if (FloatingToolbarChatDrawerOpen) {
        try FloatingToolbarSetChatDrawerState(false)
    } else if (forceResize && IsObject(FloatingToolbarGUI)) {
        try {
            newW := FloatingToolbarCalculateWidth()
            newH := FloatingToolbarCalculateHeight()
            FloatingToolbarGUI.GetPos(&gx, &gy, &gw, &gh)
            FloatingToolbarGUI.Move(gx, gy, newW, newH)
            FloatingToolbarApplyRoundedCorners()
            FloatingToolbar_ApplyWebViewBounds()
        } catch {
        }
    }

    if g_FTB_WV2 {
        try FloatingToolbar_ResetWebToToolbarHome()
        catch {
        }
    }
}

; ===================== 閹笛嗩攽閹稿鎸抽崝銊ょ稊 =====================
; WebView2 回调须尽快返回；ExecuteScreenshotWithMenu 含 Sleep/剪贴板轮询。
; 在回调内同步调用会阻塞 WebView 消息泵，导致工具栏卡死且截图助手无法弹出。
FloatingToolbar_DeferredScreenshot(*) {
    global FloatingToolbarIsVisible, FloatingToolbar_ScheduleRestoreAfterScreenshot, g_ExecuteScreenshotWithMenuBusy
    global g_FTB_ScreenshotDeferLastTick
    try OutputDebug("[FTB] screenshot deferred begin visible=" . (FloatingToolbarIsVisible ? "1" : "0") . " busy=" . (g_ExecuteScreenshotWithMenuBusy ? "1" : "0"))
    catch {
    }

    ; 防抖：同一操作 1500ms 内只接受一次（截图流程耗时长，完成后也需防重复触发）
    if (g_FTB_ScreenshotDeferLastTick && (A_TickCount - g_FTB_ScreenshotDeferLastTick < 1500))
        return
    g_FTB_ScreenshotDeferLastTick := A_TickCount

    prevCrit := Critical("On")
    if (g_ExecuteScreenshotWithMenuBusy) {
        Critical(prevCrit)
        return
    }
    g_ExecuteScreenshotWithMenuBusy := true
    Critical(prevCrit)

    wasVisible := !!FloatingToolbarIsVisible
    FloatingToolbar_ScheduleRestoreAfterScreenshot := wasVisible

    try {
        if (wasVisible) {
            try OutputDebug("[FTB] screenshot hide toolbar before capture")
            catch {
            }
            HideFloatingToolbar()
            Sleep(120)
        }
        try OutputDebug("[FTB] screenshot call ExecuteScreenshotWithMenu(true)")
        catch {
        }
        ExecuteScreenshotWithMenu(true)
        try OutputDebug("[FTB] screenshot ExecuteScreenshotWithMenu(true) returned")
        catch {
        }
        ; 截图流程完成后刷新防抖时间戳，阻止后续 1.5 秒内的重复触发
        g_FTB_ScreenshotDeferLastTick := A_TickCount
    } catch as err {
        ; Hide/Sleep 鍦?ExecuteScreenshotWithMenu 涔嬪墠澶辫触鏃讹紝棰勫崰鐨?busy 涓嶄細鐢卞悗鑰?finally 娓呴櫎
        g_ExecuteScreenshotWithMenuBusy := false
        try OutputDebug("[FloatingToolbar] DeferredScreenshot: " . err.Message)
        catch {
        }
    }
    try OutputDebug("[FTB] screenshot deferred end")
    catch {
    }
    ; 悬浮条在 ExecuteScreenshotWithMenu 内剪贴板就绪后、ShowScreenshotEditor 前统一恢复，避免 finally 再延迟 Show 造成双重显示与位移
}

FloatingToolbar_EnsureSearchCenterFocused(*) {
    global GuiID_SearchCenter
    static lastFocusTick := 0

    try {
        hwnd := 0
        if (IsSet(SCWV_GetGuiHwnd))
            hwnd := SCWV_GetGuiHwnd()
        if (!hwnd && GuiID_SearchCenter && IsObject(GuiID_SearchCenter) && GuiID_SearchCenter.HasProp("Hwnd"))
            hwnd := GuiID_SearchCenter.Hwnd
        if !hwnd
            return
        nowTick := A_TickCount
        if (nowTick - lastFocusTick < 120) {
            try SCWV_Log("ftb_ensure_focus_drop", "reason=dedupe_window")
            return
        }
        lastFocusTick := nowTick
        try SCWV_Log("ftb_ensure_focus", "hwnd=" . hwnd . " vis=" . (SCWV_IsVisible() ? "1" : "0"))
        try FocusBroker_Request("SearchCenter", hwnd, 20, "ftb_ensure_focus", 300)
    } catch {
    }

    try {
        if (IsSet(SCWV_RequestFocusInput))
            SCWV_RequestFocusInput()
    } catch {
    }
}

FloatingToolbar_VerifySearchCenterOpen(*) {
    global FloatingToolbarIsVisible, AppearanceActivationMode
    scVisible := false
    try {
        if (SearchCenter_ShouldUseWebView()) {
            hwnd := 0
            try hwnd := SCWV_GetGuiHwnd()
            if (hwnd && WinExist("ahk_id " . hwnd) && (WinGetStyle("ahk_id " . hwnd) & 0x10000000))
                scVisible := true
            else if (SCWV_IsVisible())
                scVisible := true
        } else {
            global GuiID_SearchCenter
            if (GuiID_SearchCenter && IsObject(GuiID_SearchCenter) && GuiID_SearchCenter.HasProp("Hwnd")) {
                h := GuiID_SearchCenter.Hwnd
                if (h && WinExist("ahk_id " . h) && (WinGetStyle("ahk_id " . h) & 0x10000000))
                    scVisible := true
            }
        }
    } catch {
    }

    if scVisible
        return

    try SCWV_Log("ftb_verify_search_center_miss", "tb_visible=" . (FloatingToolbarIsVisible ? "1" : "0") . " mode=" . FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode))

    ; 搜索中心未真正拉起：释放 search dock 抑制并恢复工具栏可见性
    try FloatingToolbar_PageDockLeave("search")
    if (FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode) = "toolbar" && !FloatingToolbarIsVisible) {
        try ShowFloatingToolbar()
    }
}

; 拖拽入口：异步打开搜索中心，避免在 WebMessage 回调内同步跑搜索导致工具栏卡死。
FloatingToolbar_RequestSearchByKeyword(keyword) {
    kw := Trim(String(keyword))
    if (kw = "")
        return
    SetTimer(FloatingToolbar_DeferredOpenSearchByKeyword.Bind(kw), -10)
}

FloatingToolbar_DeferredOpenSearchByKeyword(keyword, *) {
    global FloatingToolbarIsVisible, AppearanceActivationMode
    kw := Trim(String(keyword))
    if (kw = "")
        return

    opened := false
    try FloatingToolbarCollapseTransientUi()
    ; 兜底清理：若上一次 search dock 标记残留，先释放，后续由 SCWV_Show 重新进入
    try FloatingToolbar_PageDockLeave("search")

    try {
        SearchCenter_RunQueryWithKeyword(kw)
        opened := true
    } catch {
        opened := false
    }

    ; 与工具栏搜索图标保持一致：补焦点 + 补验证，避免“工具栏消失但搜索中心没起来”
    SetTimer(FloatingToolbar_EnsureSearchCenterFocused, -20)
    SetTimer(FloatingToolbar_EnsureSearchCenterFocused, -120)
    SetTimer(FloatingToolbar_EnsureSearchCenterFocused, -320)
    SetTimer(FloatingToolbar_VerifySearchCenterOpen, -260)
    SetTimer(FloatingToolbar_VerifySearchCenterOpen, -900)

    if opened
        return

    ; 打开失败时立刻回滚 dock 抑制，确保工具栏不会残留在隐藏态
    try FloatingToolbar_PageDockLeave("search")
    if (FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode) = "toolbar" && !FloatingToolbarIsVisible) {
        try ShowFloatingToolbar()
    }
}

FloatingToolbar_OpenSearchCenterFromMenu(*) {
    try TrayMenu_QueueUiOpenFromHoleMode(TrayMenu_OpenSearchAction, "ftb_ctx_search")
    catch {
        SetTimer(FloatingToolbar_ActivateSearchCenter, -10)
    }
}

FloatingToolbar_ActivateSearchCenter() {
    global g_SCWV_WaitingUiFinishedReveal, AppearanceActivationMode
    selectedText := ""
    opened := false
    usedWebView := false

    try usedWebView := SearchCenter_ShouldUseWebView()
    try SCWV_Log("toolbar_activate_search_begin", "used_webview=" . (usedWebView ? "1" : "0"))
    ; If the app is already in hole mode and SearchCenter is not visible, reuse the same hard
    ; handoff that tray opening uses. This clears stale overlay / native drag state before we
    ; try to wake SearchCenter again.
    try {
        if (FloatingToolbar_NormalizeAppearanceMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar") = "hole" && !SCWV_IsVisible())
            TrayMenu_HardenHoleUiTransition("caps_f_search", 1800)
    } catch {
    }
    try {
        if (SearchCenter_IsOpeningOrBusy()) {
            try SCWV_Log("ftb_activate_search_center_busy", "active=" . (IsSearchCenterActive() ? "1" : "0") . " vis=" . (SCWV_IsVisible() ? "1" : "0") . " waiting=" . (g_SCWV_WaitingUiFinishedReveal ? "1" : "0"))
            if (SCWV_IsVisible()) {
                SCWV_SubmitIntent("open", 20, Map(
                    "reason", "toolbar_search_reuse",
                    "initialMode", "search",
                    "triggerSource", "search_hotkey"
                ))
                opened := true
                return
            }
            try SCWV_RequestHardClose("toolbar_search_busy_recover")
            catch {
            }
        }
    } catch {
    }
    try FloatingToolbarCollapseTransientUi()
    ; 兜底清理：若上一次 search dock 标记残留，先释放，后续由 SCWV_Show 重新进入
    try FloatingToolbar_PageDockLeave("search")

    ; 与 CapsLock+F/拖放入口统一：有选中文本时直接带词打开，否则走搜索中心显示链路
    try selectedText := Trim(String(SelectionSense_GetLastSelectedText()))
    catch {
        selectedText := ""
    }

    try {
        if (selectedText != "")
            SearchCenter_RunQueryWithKeyword(selectedText)
        else if (usedWebView) {
            SCWV_SubmitIntent("open", 20, Map(
                "reason", "toolbar_search_open",
                "initialMode", "search",
                "triggerSource", "search_hotkey"
            ))
        } else
            ShowSearchCenter()
        opened := true
    } catch {
    }

    try SCWV_Log("toolbar_activate_search_mid", "selected_len=" . StrLen(selectedText) . " opened=" . (opened ? "1" : "0") . " vis=" . (usedWebView ? (SCWV_IsVisible() ? "1" : "0") : "n/a"))

    if (!opened && usedWebView) {
        try {
            SCWV_ResetHostState()
            SCWV_SubmitIntent("open", 20, Map(
                "reason", "toolbar_search_recover",
                "initialMode", "search",
                "triggerSource", "search_hotkey"
            ))
            opened := true
        } catch {
        }
    }

    if (!opened) {
        try ShowSearchCenter()
        catch {
        }
    }

    if (usedWebView) {
        try SCWV_RequestFocusInput()
        catch {
        }
    }

    ; 宸ュ叿鏍忕偣鍑诲悗鍓嶅彴鍙兘浠嶇煭鏆傚仠鍦ㄥ伐鍏锋爮 WebView锛屼笂涓€涓縺娲婚摼浼氬悶鎺夌劍鐐癸紱琛ュ嚑娆＄‘淇濇悳绱腑蹇冪湡姝ｆ嬁鍒拌緭鍏ョ劍鐐广€?
    SetTimer(FloatingToolbar_EnsureSearchCenterFocused, -20)
    SetTimer(FloatingToolbar_EnsureSearchCenterFocused, -120)
    SetTimer(FloatingToolbar_EnsureSearchCenterFocused, -320)
    ; 防竞态：若焦点/宿主状态异常导致搜索中心未出现，自动回滚工具栏隐藏态
    SetTimer(FloatingToolbar_VerifySearchCenterOpen, -260)
    SetTimer(FloatingToolbar_VerifySearchCenterOpen, -900)
    try SCWV_Log("toolbar_activate_search_end", "opened=" . (opened ? "1" : "0") . " vis=" . (usedWebView ? (SCWV_IsVisible() ? "1" : "0") : "n/a"))
}

FloatingToolbarExecuteButtonAction(action, buttonHwnd) {
    switch action {
        case "Search":
            FloatingToolbar_ActivateSearchCenter()
        case "Record":
            ; 剪贴板：WebView2 + ClipMain/FTS5 等，失败时提示
            try CP_Show()
            catch as err {
                try TrayTip("剪贴板", "无法显示 WebView 剪贴板: " . err.Message, "Iconx 1")
                catch {
                    OutputDebug("[FloatingToolbar] CP_Show failed: " . err.Message)
                }
            }
        case "AIAssistant", "Prompt":
            try ShowPromptQuickPadListOnly()
            catch as err {
                TrayTip("AI 快捷面板: " . err.Message, "错误", "Iconx 2")
            }
        case "PromptNew", "NewPrompt":
            try SelectionSense_OpenHubCapsuleFromToolbar()
            catch as err {
                try TrayTip("Unable to open HubCapsule (SelectionSenseCore.ahk is required): " . err.Message, "Error", "Iconx 2")
                catch {
                }
            }
        case "Screenshot":
            ; 不可在 WebView2 WebMessageReceived 回调里同步执行 ExecuteScreenshotWithMenu
            ; 含长时间 Sleep/剪贴板轮询会阻塞消息泵，导致工具栏卡死且截图窗口无法显示
            SetTimer(FloatingToolbar_DeferredScreenshot, -10)
        case "Settings":
            FloatingToolbarOpenSettings()
        case "VirtualKeyboard":
            FloatingToolbarActivateVirtualKeyboard()
    }
}

; 延后一帧处理搜索切换：让 WM_ACTIVATE / 延迟 Hide 与 postMessage 顺序稳定，避免先关后立又弹回
FloatingToolbar_SearchToggleDeferred(*) {
    global GuiID_SearchCenter
    try {
        h := SCWV_GetGuiHwnd()
        if (h && WinExist("ahk_id " . h) && (WinGetStyle("ahk_id " . h) & 0x10000000)) {
            SCWV_Hide(true)
            return
        }
    } catch {
    }
    try {
        if (SCWV_IsVisible()) {
            SCWV_Hide(true)
            return
        }
    } catch {
    }
    try {
        if (GuiID_SearchCenter != 0 && (!IsSet(SearchCenter_ShouldUseWebView) || !SearchCenter_ShouldUseWebView())) {
            SearchCenterCloseHandler()
            return
        }
    } catch {
    }
    FloatingToolbarExecuteButtonAction("Search", 0)
}

FloatingToolbar_PromptToggleDeferred(*) {
    global g_PQP_Gui
    try {
        if (g_PQP_Gui && WinExist("ahk_id " . g_PQP_Gui.Hwnd) && (WinGetStyle("ahk_id " . g_PQP_Gui.Hwnd) & 0x10000000)) {
            PQP_Hide()
            return
        }
    } catch {
    }
    try {
        if (PQP_IsVisible()) {
            PQP_Hide()
            return
        }
    } catch {
    }
    FloatingToolbarExecuteButtonAction("Prompt", 0)
}

FloatingToolbarToggleButtonAction(action) {
    global GuiID_SearchCenter, GuiID_ConfigGUI, ConfigWebViewMode, GuiID_ScreenshotEditor, g_PQP_Gui
    switch action {
        case "Search":
            SetTimer(FloatingToolbar_ActivateSearchCenter, -10)
            return
        case "Record":
            try {
                if (IsSet(g_CP_Visible) && g_CP_Visible) {
                    CP_Hide()
                    return
                }
            } catch {
            }
            FloatingToolbarExecuteButtonAction(action, 0)
        case "AIAssistant", "Prompt":
            ; 延后一帧：与 WM_ACTIVATE、Hide/postMessage 顺序对齐，减少关不掉或关掉又弹回
            SetTimer(FloatingToolbar_PromptToggleDeferred, -10)
            return
        case "Settings":
            ; WebView 璁剧疆锛氬叧闂椂浠?Hide锛孏uiID_ConfigGUI 浠嶉潪 0锛屽繀椤绘寜銆屾槸鍚﹀彲瑙併€嶅垏鎹紝鍚﹀垯浼氭棤娉曞啀娆℃墦寮€
            try {
                if (GuiID_ConfigGUI != 0) {
                    cfgVisible := false
                    if (ConfigWebViewMode) {
                        try cfgVisible := ConfigWebView_HostWindowVisible()
                        catch {
                            cfgVisible := false
                        }
                    } else {
                        try {
                            cfgVisible := WinExist("ahk_id " . GuiID_ConfigGUI.Hwnd)
                                && (WinGetStyle("ahk_id " . GuiID_ConfigGUI.Hwnd) & 0x10000000)
                        } catch {
                            cfgVisible := false
                        }
                    }
                    if (cfgVisible) {
                        CloseConfigGUI()
                        return
                    }
                }
            } catch {
            }
            FloatingToolbarExecuteButtonAction(action, 0)
        case "NewPrompt":
            try {
                if (IsSet(SelectionSense_HubCapsuleHostIsOpen) && SelectionSense_HubCapsuleHostIsOpen()) {
                    SelectionSense_HideMenu()
                    return
                }
            } catch {
            }
            FloatingToolbarExecuteButtonAction(action, 0)
        case "Screenshot":
            try {
                if (IsObject(GuiID_ScreenshotEditor)) {
                    CloseScreenshotEditor()
                    return
                }
            } catch {
            }
            FloatingToolbarExecuteButtonAction(action, 0)
        case "VirtualKeyboard":
            ; VK_ToggleEmbedded 依赖可见性；失焦自动 Hide 后需与 VK_IsHostVisible 一致，见 VirtualKeyboardCore
            try {
                if (VK_IsHostVisible()) {
                    VK_Hide()
                    return
                }
            } catch {
            }
            try {
                VK_ToggleEmbedded()
            } catch as err {
                try TrayTip("虚拟键盘不可用: " . err.Message, "虚拟键盘", "Iconx 2")
                catch {
                }
            }
        default:
            FloatingToolbarExecuteButtonAction(action, 0)
    }
}

; 前台 HWND 是否为悬浮工具栏或其子窗口（点工具栏内 WebView 时 WinGetID("A") 常不是宿主 Hwnd）
FloatingToolbar_IsForegroundToolbarOrChild() {
    global FloatingToolbarGUI
    if !FloatingToolbarGUI
        return false
    fg := 0
    try fg := WinGetID("A")
    catch {
        return false
    }
    tb := FloatingToolbarGUI.Hwnd
    hw := fg
    Loop 40 {
        if (hw = tb)
            return true
        np := DllCall("user32\GetParent", "Ptr", hw, "Ptr")
        if !np
            break
        hw := np
    }
    return false
}

FloatingToolbarActivateVirtualKeyboard() {
    try VK_ToggleEmbedded()
    catch as err {
        try TrayTip("閾忔碍瀚欓柨顔炬磸娑撳秴褰查悽? " . err.Message, "閾忔碍瀚欓柨顔炬磸", "Iconx 2")
        catch {
        }
    }
}

FloatingToolbarOpenSettings() {
    try {
        if IsSet(ShowConfigWebViewGUI) {
            ShowConfigWebViewGUI()
            return
        }
    } catch {
    }
    try {
        if IsSet(ShowConfigGUI) {
            ShowConfigGUI()
            return
        }
    } catch {
    }
    try {
        SetCapsLockState("AlwaysOff")
        Send("{CapsLock down}")
        Sleep(30)
        Send("q")
        Sleep(30)
        Send("{CapsLock up}")
        SetCapsLockState("Off")
    } catch {
    }
}

; ===================== 濠婃俺鐤嗙紓鈺傛杹婢跺嫮鎮?=====================
FloatingToolbarWM_MOUSEWHEEL(wParam, lParam, msg, hwnd) {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarChatDrawerOpen
    global FloatingBubbleGUI, FloatingBubbleIsVisible, AppearanceActivationMode
    wheelDelta := (wParam >> 16) & 0xFFFF
    if (wheelDelta > 0x7FFF)
        wheelDelta := wheelDelta - 0x10000

    delta := wheelDelta > 0 ? 1 : -1
    mode := FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode)

    mouseInToolbar := false
    if (FloatingToolbarIsVisible && IsSet(FloatingToolbarGUI) && IsObject(FloatingToolbarGUI) && (FloatingToolbarGUI is Gui)) {
        MouseGetPos(&mx1, &my1)
        try FloatingToolbarGUI.GetPos(&tx, &ty, &tw, &th)
        catch {
            tx := ty := tw := th := 0
        }
        if (mx1 >= tx && mx1 <= tx + tw && my1 >= ty && my1 <= ty + th)
            mouseInToolbar := true
    }

    mouseInBubble := false
    if (FloatingBubbleIsVisible && IsSet(FloatingBubbleGUI) && IsObject(FloatingBubbleGUI) && (FloatingBubbleGUI is Gui)) {
        MouseGetPos(&mx2, &my2)
        try FloatingBubbleGUI.GetPos(&bx, &by, &bw, &bh)
        catch {
            bx := by := bw := bh := 0
        }
        if (mx2 >= bx && mx2 <= bx + bw && my2 >= by && my2 <= by + bh)
            mouseInBubble := true
    }

  ; Niuma Chat 抽屉展开时：不拦截滚轮（交给对话区滚动），也不缩放/切圆球
    if FloatingToolbarChatDrawerOpen
        return

    if (mouseInToolbar || mouseInBubble) {
        FloatingToolbar_SwitchActivationByWheel(delta)
        return 0
    }

    if (g_FTB_ModeTransitionBusy)
        return 0
    if (!mouseInToolbar)
        return
    if (mode != "toolbar")
        return

    FloatingToolbarApplyWheelDelta(delta)

    return 0
}

FloatingToolbar_ClampRect(&x, &y, w, h) {
    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    vb := vt + vh
    if (x < vl)
        x := vl
    if (y < vt)
        y := vt
    if (x + w > vr)
        x := vr - w
    if (y + h > vb)
        y := vb - h
}

FloatingToolbar_GetGuiCenter(gui, &cx, &cy) {
    cx := 0.0
    cy := 0.0
    if !IsObject(gui)
        return false
    try gui.GetPos(&x, &y, &w, &h)
    catch {
        return false
    }
    cx := x + (w / 2.0)
    cy := y + (h / 2.0)
    return true
}

FloatingToolbar_FadeGui(hwnd, fromAlpha, toAlpha, durationMs, onDone := "") {
    if !hwnd
        return
    steps := Max(6, Integer(durationMs / 18))
    tickMs := Max(12, Integer(durationMs / steps))
    curStep := 0
    FadeStep(*) {
        curStep++
        t := curStep / steps
        if (t > 1)
            t := 1.0
        eased := 1 - (1 - t) ** 3
        a := fromAlpha + (toAlpha - fromAlpha) * eased
        try WinSetTransparent(Round(a), "ahk_id " . hwnd)
        if (curStep >= steps) {
            if (onDone != "") {
                if (IsObject(onDone))
                    try onDone.Call()
                catch {
                }
            }
            return
        }
        SetTimer(FadeStep, -tickMs)
    }
    try WinSetTransparent(Round(fromAlpha), "ahk_id " . hwnd)
    SetTimer(FadeStep, -tickMs)
}

FloatingToolbar_PersistActivationBubble() {
    global AppearanceActivationMode
    AppearanceActivationMode := "bubble"
    cfg := Nmer_ResolveConfigFile()
    try IniWrite("bubble", cfg, "Appearance", "ActivationMode")
    catch {
    }
    try ApplyActivationRuntimeAsync("toolbar")
    catch {
    }
}

FloatingToolbar_RequestHandoffToBubble() {
    global g_FTB_WV2
    if !g_FTB_WV2
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "handoff_to_bubble"))
    catch {
    }
}

FloatingToolbar_ClearHandoffWeb() {
    global g_FTB_WV2
    if !g_FTB_WV2
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "handoff_clear"))
    catch {
    }
}

FloatingToolbar_FinalizeBubbleSwitch(*) {
    global g_FTB_ModeTransitionBusy
    try FloatingToolbar_ClearHandoffWeb()
    try FloatingToolbar_PersistActivationBubble()
    try HideFloatingToolbar()
    catch {
    }
    g_FTB_ModeTransitionBusy := false
}

FloatingToolbar_AnimatedSwitchToBubble_Crossfade(*) {
    global g_FTB_ModeTransitionBusy, FloatingToolbarGUI, FloatingToolbarCompactDiameter, g_FTB_CrossfadeMs, g_FTB_WV2
    if !g_FTB_ModeTransitionBusy
        return
    if !IsObject(FloatingToolbarGUI) || !(FloatingToolbarGUI is Gui) {
        g_FTB_ModeTransitionBusy := false
        return
    }
    cx := 0.0, cy := 0.0
    if !FloatingToolbar_GetGuiCenter(FloatingToolbarGUI, &cx, &cy) {
        g_FTB_ModeTransitionBusy := false
        return
    }
    sz := Round(FloatingToolbarCompactDiameter)
    hwndTb := FloatingToolbarGUI.Hwnd
    fadeMs := g_FTB_CrossfadeMs

    try ShowFloatingBubbleAt(cx, cy, sz, 0)
    catch {
        try ShowFloatingBubble()
        try {
            global g_FB_LayeredAlpha
            g_FB_LayeredAlpha := 0
            FloatingBubble_RenderLayered()
        } catch {
        }
    }

    try FloatingToolbar_RequestHandoffToBubble()
    SetTimer(FloatingToolbar_AnimatedSwitchToBubble_CrossfadeFade, -48)
}

FloatingToolbar_AnimatedSwitchToBubble_CrossfadeFade(*) {
    global g_FTB_ModeTransitionBusy, FloatingToolbarGUI, g_FTB_CrossfadeMs, g_FTB_WV2
    if !g_FTB_ModeTransitionBusy
        return
    if !IsObject(FloatingToolbarGUI) || !(FloatingToolbarGUI is Gui)
        return
    hwndTb := FloatingToolbarGUI.Hwnd
    fadeMs := g_FTB_CrossfadeMs

    try WebView_QueuePayload(g_FTB_WV2, Map("type", "handoff_fade_out"))
    catch {
    }

    FloatingToolbar_FadeGui(hwndTb, 255, 0, fadeMs + 40, (*) => 0)
    SetTimer((*) => FloatingBubble_FadeLayered(0, 255, fadeMs + 100, FloatingToolbar_FinalizeBubbleSwitch), -72)
}

FloatingToolbar_AnimatedSwitchToBubble(*) {
    global g_FTB_ModeTransitionBusy, FloatingToolbarGUI, FloatingToolbarIsVisible
    global FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarWindowX, FloatingToolbarWindowY
    global g_FTB_BubbleHandoffMs, g_FTB_WV2
    if g_FTB_ModeTransitionBusy
        return
    if !IsObject(FloatingToolbarGUI) || !(FloatingToolbarGUI is Gui) || !FloatingToolbarIsVisible
        return
    g_FTB_ModeTransitionBusy := true
    try FloatingToolbar_RequestHandoffToBubble()

    if !FloatingToolbarIsCompactMode() {
        cx := 0.0, cy := 0.0
        if !FloatingToolbar_GetGuiCenter(FloatingToolbarGUI, &cx, &cy) {
            g_FTB_ModeTransitionBusy := false
            return
        }
        FloatingToolbarScale := FloatingToolbarMinScale
        tw := FloatingToolbarCalculateWidth()
        th := FloatingToolbarCalculateHeight()
        newX := Round(cx - (tw / 2.0))
        newY := Round(cy - (th / 2.0))
        FloatingToolbar_ClampRect(&newX, &newY, tw, th)
        FloatingToolbarWindowX := newX
        FloatingToolbarWindowY := newY
        try FloatingToolbarGUI.Move(newX, newY, tw, th)
        FloatingToolbarPushScaleStateToWeb(FloatingToolbarScale)
        try FloatingToolbar_ApplyWebViewBounds()
        try FloatingToolbarApplyRoundedCorners()
        try FloatingToolbar_RequestHandoffToBubble()
        SetTimer(FloatingToolbar_AnimatedSwitchToBubble_Crossfade, -g_FTB_BubbleHandoffMs)
        return
    }
    SetTimer(FloatingToolbar_AnimatedSwitchToBubble_Crossfade, -260)
}

FloatingToolbar_FinishToolbarExpandSwitch(*) {
    global g_FTB_ModeTransitionBusy
    g_FTB_ModeTransitionBusy := false
}

FloatingToolbar_AnimatedSwitchToToolbar(*) {
    global g_FTB_ModeTransitionBusy, FloatingToolbarGUI, FloatingToolbarIsVisible
    global FloatingBubbleGUI, FloatingBubbleIsVisible
    global FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarMaxScale
    global FloatingToolbarWindowX, FloatingToolbarWindowY, g_FTB_WV2, g_FTB_ModeFadeMs
    if g_FTB_ModeTransitionBusy
        return

    cx := 0.0, cy := 0.0
    if (FloatingBubbleIsVisible && IsObject(FloatingBubbleGUI) && (FloatingBubbleGUI is Gui)) {
        if !FloatingToolbar_GetGuiCenter(FloatingBubbleGUI, &cx, &cy)
            return
    } else if (IsObject(FloatingToolbarGUI) && (FloatingToolbarGUI is Gui)) {
        if !FloatingToolbar_GetGuiCenter(FloatingToolbarGUI, &cx, &cy)
            return
    } else {
        return
    }

    g_FTB_ModeTransitionBusy := true

    if FloatingToolbarIsCompactMode() {
        targetScale := FloatingToolbarMinScale + 0.15
        if (targetScale > FloatingToolbarMaxScale)
            targetScale := FloatingToolbarMaxScale
        FloatingToolbarScale := targetScale
    }

    tw := FloatingToolbarCalculateWidth()
    th := FloatingToolbarCalculateHeight()
    newX := Round(cx - (tw / 2.0))
    newY := Round(cy - (th / 2.0))
    FloatingToolbar_ClampRect(&newX, &newY, tw, th)
    FloatingToolbarWindowX := newX
    FloatingToolbarWindowY := newY

    if (FloatingBubbleIsVisible) {
        FloatingBubble_FadeLayered(255, 0, g_FTB_ModeFadeMs, FloatingToolbar_AnimatedSwitchToToolbar_Reveal.Bind(newX, newY, tw, th))
        return
    }
    FloatingToolbar_AnimatedSwitchToToolbar_Reveal(newX, newY, tw, th)
}

FloatingToolbar_AnimatedSwitchToToolbar_Reveal(newX, newY, tw, th, *) {
    global g_FTB_ModeTransitionBusy, FloatingToolbarGUI, FloatingToolbarIsVisible, g_FTB_WV2, g_FTB_ModeFadeMs
    global FloatingToolbarScale, AppearanceActivationMode

    try HideFloatingBubble()
    catch {
    }

    AppearanceActivationMode := "toolbar"
    cfg := Nmer_ResolveConfigFile()
    try IniWrite("toolbar", cfg, "Appearance", "ActivationMode")
    catch {
    }
    try ApplyActivationRuntimeAsync("toolbar")
    catch {
    }
    try FloatingToolbar_ClearHandoffWeb()

    if !IsObject(FloatingToolbarGUI) || !(FloatingToolbarGUI is Gui) {
        try ShowFloatingToolbar()
        g_FTB_ModeTransitionBusy := false
        return
    }

    hwnd := FloatingToolbarGUI.Hwnd
    FloatingToolbarWindowX := newX
    FloatingToolbarWindowY := newY
    try WinSetTransparent(0, "ahk_id " . hwnd)
    try FloatingToolbarGUI.Move(newX, newY, tw, th)
    FloatingToolbarPushScaleStateToWeb(FloatingToolbarScale)
    try FloatingToolbar_ApplyWebViewBounds()
    try FloatingToolbarApplyRoundedCorners()
    try FloatingToolbarGUI.Show("x" . newX . " y" . newY . " w" . tw . " h" . th . " NoActivate")
    FloatingToolbarIsVisible := true
    try FloatingToolbar_NotifyWebViewShown(g_FTB_WV2)
    FloatingToolbar_FadeGui(hwnd, 0, 255, g_FTB_ModeFadeMs + 60, FloatingToolbar_FinishToolbarExpandSwitch)
}

FloatingToolbar_SetActivationMode(mode) {
    global AppearanceActivationMode, g_FTB_ModeTransitionBusy, FloatingToolbarIsVisible, FloatingBubbleIsVisible
    if g_FTB_ModeTransitionBusy
        return
    m := FloatingToolbar_NormalizeAppearanceMode(mode)
    if (m != "toolbar" && m != "bubble" && m != "hole" && m != "tray")
        return
    cur := FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode)
    if (m = "bubble" && cur = "toolbar" && FloatingToolbarIsVisible) {
        FloatingToolbar_AnimatedSwitchToBubble()
        return
    }
    if (m = "toolbar" && cur = "bubble" && FloatingBubbleIsVisible) {
        FloatingToolbar_AnimatedSwitchToToolbar()
        return
    }
    ; Idempotent guard: wheel/UI can emit repeated same-mode toggles in a short burst.
    if (cur = m)
        return
    AppearanceActivationMode := m
    cfg := Nmer_ResolveConfigFile()
    try IniWrite(AppearanceActivationMode, cfg, "Appearance", "ActivationMode")
    catch {
    }
    SetTimer((*) => ApplyAppearanceActivationMode(), -10)
    if (m = "toolbar")
        SetTimer(FloatingToolbar_ShowForActivationMode, -30)
}

FloatingToolbar_SwitchActivationByWheel(delta) {
    global AppearanceActivationMode, g_FTB_ModeTransitionBusy, FloatingToolbarChatDrawerOpen
    if FloatingToolbarChatDrawerOpen
        return
    if g_FTB_ModeTransitionBusy
        return
    mode := FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode)
    if (delta > 0) {
        if (mode = "bubble")
            FloatingToolbar_AnimatedSwitchToToolbar()
        else if (mode != "toolbar")
            FloatingToolbar_SetActivationMode("toolbar")
        return
    }
    if (mode = "toolbar")
        FloatingToolbar_AnimatedSwitchToBubble()
    else if (mode = "bubble")
        FloatingToolbar_AnimatedSwitchToBubble()
}

FloatingToolbarApplyWheelDelta(delta) {
    global FloatingToolbarGUI, FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarMaxScale
    global FloatingToolbarWindowX, FloatingToolbarWindowY, g_FTB_WV2, FloatingToolbarChatDrawerOpen

    if FloatingToolbarChatDrawerOpen
        return
    ; 必须与 CreateFloatingToolbarGUI 创建的 Gui 一致；勿与他处同名全局混用，否则此处可能得到 Integer 而非 Gui
    if !IsObject(FloatingToolbarGUI) || !(FloatingToolbarGUI is Gui)
        return

    scaleStep := 0.15
    newScale := FloatingToolbarScale

    ; 已在最小缩放附近继续缩小：等紧凑态动画后再切到悬浮球
    if (delta < 0 && (FloatingToolbarScale - scaleStep) <= (FloatingToolbarMinScale + 0.0001)) {
        global g_FTB_BubbleHandoffMs
        SetTimer(FloatingToolbar_AnimatedSwitchToBubble, -g_FTB_BubbleHandoffMs)
        return
    }

    if (delta > 0) {
        newScale := FloatingToolbarScale + scaleStep
        if (newScale > FloatingToolbarMaxScale)
            newScale := FloatingToolbarMaxScale
    } else {
        newScale := FloatingToolbarScale - scaleStep
        if (newScale < FloatingToolbarMinScale)
            newScale := FloatingToolbarMinScale
    }

    if (newScale != FloatingToolbarScale) {
        wasCompact := FloatingToolbarIsCompactMode(FloatingToolbarScale)
        FloatingToolbarGUI.GetPos(&oldX, &oldY, &oldWidth, &oldHeight)
        MouseGetPos(&mouseScreenX, &mouseScreenY)
        mouseRelX := mouseScreenX - oldX
        mouseRelY := mouseScreenY - oldY
        mouseRatioX := oldWidth > 0 ? mouseRelX / oldWidth : 0.5
        mouseRatioY := oldHeight > 0 ? mouseRelY / oldHeight : 0.5

        FloatingToolbarScale := newScale

        ToolbarWidth := FloatingToolbarCalculateWidth()
        ToolbarHeight := FloatingToolbarCalculateHeight()

        newX := mouseScreenX - Round(mouseRatioX * ToolbarWidth)
        newY := mouseScreenY - Round(mouseRatioY * ToolbarHeight)

        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        vr := vl + vw
        vb := vt + vh
        if (newX < vl)
            newX := vl
        if (newY < vt)
            newY := vt
        if (newX + ToolbarWidth > vr)
            newX := vr - ToolbarWidth
        if (newY + ToolbarHeight > vb)
            newY := vb - ToolbarHeight

        FloatingToolbarWindowX := newX
        FloatingToolbarWindowY := newY

        FloatingToolbarGUI.Move(newX, newY, ToolbarWidth, ToolbarHeight)
        FloatingToolbarApplyRoundedCorners()
        FloatingToolbar_ApplyWebViewBounds()

        FloatingToolbarPushScaleStateToWeb(newScale)

        FloatingToolbarSaveScale()
        SaveFloatingToolbarPosition()
        nowCompact := FloatingToolbarIsCompactMode(newScale)
        if (nowCompact && !wasCompact) {
            try FloatingToolbar_EnterHoleCompactRuntime()
        } else if (!nowCompact && wasCompact) {
            try FloatingToolbar_ExitHoleCompactRuntime()
        }
        if (delta < 0 && FloatingToolbarIsCompactMode(newScale)) {
            global g_FTB_BubbleHandoffMs
            SetTimer(FloatingToolbar_AnimatedSwitchToBubble, -g_FTB_BubbleHandoffMs)
        }

    }
}

FloatingToolbar_EnterHoleCompact() {
    global FloatingToolbarScale, FloatingToolbarMinScale
    FloatingToolbarScale := FloatingToolbarMinScale
    FloatingToolbarSaveScale()
    FloatingToolbarPushScaleStateToWeb(FloatingToolbarScale)
    try FloatingToolbar_ApplyWebViewBounds()
    try FloatingToolbarApplyRoundedCorners()
    try FloatingToolbar_EnterHoleCompactRuntime()
}

FloatingToolbar_EnterHoleCompactRuntime() {
    ; Disabled for stability: hole runtime visibility is owned by ActivationMode=hole.
    return
}

FloatingToolbar_ExitHoleCompactRuntime() {
    global AppearanceActivationMode
    try GDHO_UnpinFromDesktop()
    if (FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode) != "hole") {
        try GDHO_Stop()
        try NativeDropBridge_Stop()
    }
}

; ===================== 鎷栧姩锛圵ebView2 鍐?PostMessage HTCAPTION 涓嶅彲闈狅紝鐢ㄦ墜鍔?Move锛涘悓姝ュ惊鐜瘮 1ms 瀹氭椂鍣ㄦ洿璺熸墜锛?===================
FloatingToolbar_DragRun(*) {
    global FloatingToolbarGUI, FloatingToolbarDragging, FloatingToolbarWindowX, FloatingToolbarWindowY
    global FloatingToolbar_DragOriginScreenX, FloatingToolbar_DragOriginScreenY
    global FloatingToolbar_DragOriginWinX, FloatingToolbar_DragOriginWinY
    global FloatingToolbar_DragStartTick, FloatingToolbar_DragMaxMs

    if !(FloatingToolbarGUI && FloatingToolbarDragging) {
        SetTimer(FloatingToolbar_DragRun, 0)
        return
    }
    if (!GetKeyState("LButton", "P")) {
        FloatingToolbar_EndDrag()
        return
    }
    if (FloatingToolbar_DragStartTick && (A_TickCount - FloatingToolbar_DragStartTick > FloatingToolbar_DragMaxMs)) {
        FloatingToolbar_EndDrag()
        return
    }
    try {
        ToolbarWidth := FloatingToolbarCalculateWidth()
        ToolbarHeight := FloatingToolbarCalculateHeight()
        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        vr := vl + vw
        vb := vt + vh
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        newX := FloatingToolbar_DragOriginWinX + (mx - FloatingToolbar_DragOriginScreenX)
        newY := FloatingToolbar_DragOriginWinY + (my - FloatingToolbar_DragOriginScreenY)
        global FloatingToolbarChatDrawerOpen
        if FloatingToolbarChatDrawerOpen {
            ftHwnd := FloatingToolbarGUI.Hwnd
            FloatingToolbar_ClampWindowToWorkArea(&newX, &newY, ToolbarWidth, ToolbarHeight, ftHwnd)
        } else {
            if (newX < vl)
                newX := vl
            if (newY < vt)
                newY := vt
            if (newX + ToolbarWidth > vr)
                newX := vr - ToolbarWidth
            if (newY + ToolbarHeight > vb)
                newY := vb - ToolbarHeight
        }
        if (newX != FloatingToolbarWindowX || newY != FloatingToolbarWindowY) {
            try FloatingToolbarGUI.Move(newX, newY)
            FloatingToolbarWindowX := newX
            FloatingToolbarWindowY := newY
        }
    } catch {
        FloatingToolbar_EndDrag()
        return
    }
}

FloatingToolbar_EndDrag() {
    global FloatingToolbarDragging, FloatingToolbar_DragStartTick
    FloatingToolbarDragging := false
    FloatingToolbar_DragStartTick := 0
    SetTimer(FloatingToolbar_DragRun, 0)
    FloatingToolbarCheckWindowPosition()
    SaveFloatingToolbarPosition()
}

; ===================== 缁愭褰涙担宥囩枂濡偓閺屻儰绗岀壕浣告儧 =====================
FloatingToolbarCheckWindowPosition() {
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY, FloatingToolbarDragging, FloatingToolbarIsVisible
    global FloatingToolbarChatDrawerOpen

    if (!FloatingToolbarIsVisible || !IsSet(FloatingToolbarGUI) || FloatingToolbarGUI = 0)
        return

    if (FloatingToolbarDragging)
        return

    if FloatingToolbarChatDrawerOpen {
        FloatingToolbar_EnsureDrawerInWorkArea()
        SaveFloatingToolbarPosition()
        return
    }

    if (!GetKeyState("LButton", "P")) {
        try {
            FloatingToolbarGUI.GetPos(&newX, &newY)
            FloatingToolbarWindowX := newX
            FloatingToolbarWindowY := newY

            ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
            vr := vl + vw
            vb := vt + vh
            adjustedX := newX
            adjustedY := newY

            snapDistance := 30
            windowWidth := FloatingToolbarCalculateWidth()
            windowHeight := FloatingToolbarCalculateHeight()

            if (adjustedX < vl + snapDistance)
                adjustedX := vl
            else if (adjustedX + windowWidth > vr - snapDistance)
                adjustedX := vr - windowWidth

            if (adjustedY < vt + snapDistance)
                adjustedY := vt
            else if (adjustedY + windowHeight > vb - snapDistance)
                adjustedY := vb - windowHeight

            if (adjustedX < vl)
                adjustedX := vl
            if (adjustedY < vt)
                adjustedY := vt
            if (adjustedX + windowWidth > vr)
                adjustedX := vr - windowWidth
            if (adjustedY + windowHeight > vb)
                adjustedY := vb - windowHeight

            if (adjustedX != newX || adjustedY != newY) {
                FloatingToolbarGUI.Move(adjustedX, adjustedY)
                FloatingToolbarWindowX := adjustedX
                FloatingToolbarWindowY := adjustedY
            }

            SaveFloatingToolbarPosition()
            FloatingToolbar_ApplyWebViewBounds()
        } catch {
        }
    }
}

; 閸欐娊鏁懣婊冨礋閻㈠彉瀵岄懘姘拱 ShowFloatingToolbarUnifiedContextMenu 閹绘劒绶甸敍鍫熺箒閼规彃鑴婄粣妤佺壉瀵骏绱氶敍宀勪缉閸忓秳绗?#Include 閸愯尙鐛婇妴?
FloatingToolbarResetScale() {
    global FloatingToolbarScale, FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY, g_FTB_WV2

    FloatingToolbarScale := 1.0
    ToolbarWidth := FloatingToolbarCalculateWidth()
    ToolbarHeight := FloatingToolbarCalculateHeight()

    FloatingToolbarGUI.Move(FloatingToolbarWindowX, FloatingToolbarWindowY, ToolbarWidth, ToolbarHeight)
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()

    FloatingToolbarPushScaleStateToWeb(1.0)

    FloatingToolbarSaveScale()
    SaveFloatingToolbarPosition()
}

OnFloatingToolbarContextMenu(*) {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    SetTimer(FloatingToolbar_ShowContextMenuDeferred.Bind(mx, my), -10)
}

FloatingToolbar_ParseWebMessage(args) {
    ; 1) Preferred path for postMessage(string): raw payload without extra JSON wrapper.
    try {
        raw := args.TryGetWebMessageAsString()
        if (raw != "") {
            try {
                m := Jxon_Load(raw)
                if (m is Map)
                    return m
            } catch {
            }
        }
    } catch {
    }

    ; 2) Fallback path for postMessage(object): JSON value from WebMessageAsJson.
    try {
        jsonStr := args.WebMessageAsJson
        m := Jxon_Load(jsonStr)
        if (m is String)
            m := Jxon_Load(m)
        if (m is Map)
            return m
    } catch {
    }

    FTB_Debug("web message parse failed", "err")
    return 0
}

FloatingToolbar_ShowContextMenuDeferred(anchorX := 0, anchorY := 0) {
    global AppearanceActivationMode, g_SCWV_WaitingUiFinishedReveal
    if (anchorX <= 0 || anchorY <= 0) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&anchorX, &anchorY)
    }
    try {
        mode := FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode)
        FTB_Debug("show menu @" . anchorX . "," . anchorY . " mode=" . mode . " search_active=" . (IsSearchCenterActive() ? "1" : "0") . " waiting=" . (g_SCWV_WaitingUiFinishedReveal ? "1" : "0"))
    } catch {
        FTB_Debug("show menu @" . anchorX . "," . anchorY)
    }
    try ShowFloatingToolbarUnifiedContextMenu(anchorX, anchorY)
    catch as err {
        FTB_Debug("show menu failed: " . err.Message, "err")
    }
}

FloatingToolbar_EscapeJsSingle(s) {
    if FuncExists("NiumaMobileBrowser_EscapeJsSingle")
        return NiumaMobileBrowser_EscapeJsSingle(s)
    t := StrReplace(String(s), "\", "\\")
    t := StrReplace(t, "'", "\'")
    t := StrReplace(t, "`r", "\r")
    t := StrReplace(t, "`n", "\n")
    return t
}

FloatingToolbar_ChatInputFieldJs(fieldId := "input") {
    fid := Trim(String(fieldId))
    if (fid = "")
        fid := "input"
    return "document.getElementById('" . FloatingToolbar_EscapeJsSingle(fid) . "')"
}

FloatingToolbar_ChatInputCtxRunJs(js) {
    wv2 := FloatingToolbar_GetChatWv2()
    if !wv2
        return false
    try {
        wv2.ExecuteScriptAsync(js)
        return true
    } catch {
        return false
    }
}

FloatingToolbar_ChatInputCtxCopy(hasSel, selection, *) {
    if hasSel && Trim(String(selection)) != "" {
        try {
            A_Clipboard := ""
            A_Clipboard := String(selection)
            ClipWait(1)
        } catch {
        }
        return
    }
    elJs := FloatingToolbar_ChatInputFieldJs("input")
    FloatingToolbar_ChatInputCtxRunJs("(function(){try{var el=" . elJs . ";if(!el)return false;el.focus();"
        . "if(el.selectionStart!=null&&el.selectionEnd!=null&&el.selectionStart!==el.selectionEnd)return document.execCommand('copy');"
        . "return document.execCommand('copy');}catch(e){return false;}})();")
}

FloatingToolbar_ChatInputCtxCut(selection, fieldId := "input", *) {
    sel := String(selection)
    if (sel != "") {
        try {
            A_Clipboard := ""
            A_Clipboard := sel
            ClipWait(1)
        } catch {
        }
    }
    elJs := FloatingToolbar_ChatInputFieldJs(fieldId)
    js := "(function(){try{var el=" . elJs . ";if(!el)return;var a=el.selectionStart,b=el.selectionEnd;"
        . "if(a==null||a===b)return;el.value=el.value.slice(0,a)+el.value.slice(b);el.selectionStart=el.selectionEnd=a;"
        . "el.dispatchEvent(new Event('input',{bubbles:true}));el.focus();}catch(e){}})();"
    FloatingToolbar_ChatInputCtxRunJs(js)
}

FloatingToolbar_ChatInputCtxPaste(fieldId := "input", *) {
    clip := A_Clipboard
    clipEsc := FloatingToolbar_EscapeJsSingle(String(clip))
    elJs := FloatingToolbar_ChatInputFieldJs(fieldId)
    js := "(function(){try{var el=" . elJs . ";if(!el)return;var t='" . clipEsc . "';"
        . "el.focus();var a=el.selectionStart,b=el.selectionEnd;"
        . "if(a!=null&&b!=null){el.value=el.value.slice(0,a)+t+el.value.slice(b);el.selectionStart=el.selectionEnd=a+t.length;}"
        . "else{el.value=(el.value||'')+t;}"
        . "el.dispatchEvent(new Event('input',{bubbles:true}));}catch(e){}})();"
    FloatingToolbar_ChatInputCtxRunJs(js)
}

FloatingToolbar_ChatInputCtxSelectAll(fieldId := "input", *) {
    elJs := FloatingToolbar_ChatInputFieldJs(fieldId)
    FloatingToolbar_ChatInputCtxRunJs("(function(){try{var el=" . elJs . ";if(!el)return;el.focus();el.select();}catch(e){}})();")
}

FloatingToolbar_ShowChatInputContextMenuDeferred(anchorX := 0, anchorY := 0, fieldId := "input", hasSel := false, selection := "") {
    if (anchorX <= 0 || anchorY <= 0) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&anchorX, &anchorY)
    }
    fid := Trim(String(fieldId))
    if (fid = "")
        fid := "input"
    sel := String(selection)
    menuItems := []
    menuItems.Push({ Text: "复制", Icon: "📋", Action: FloatingToolbar_ChatInputCtxCopy.Bind(hasSel, sel) })
    if hasSel && Trim(sel) != ""
        menuItems.Push({ Text: "剪切", Icon: "✂", Action: FloatingToolbar_ChatInputCtxCut.Bind(sel, fid) })
    menuItems.Push({ Text: "粘贴", Icon: "📥", Action: FloatingToolbar_ChatInputCtxPaste.Bind(fid) })
    menuItems.Push({ Text: "全选", Icon: "▦", Action: FloatingToolbar_ChatInputCtxSelectAll.Bind(fid) })
    try {
        if IsSet(ShowDarkStylePopupMenuAt)
            ShowDarkStylePopupMenuAt(menuItems, anchorX + 2, anchorY + 2)
        else {
            m := Menu()
            for item in menuItems {
                act := item.HasProp("Action") ? item.Action : 0
                lbl := item.HasProp("Text") ? String(item.Text) : ""
                if (lbl = "")
                    continue
                if act
                    m.Add(lbl, act)
                else
                    m.Add(lbl)
            }
            m.Show(anchorX + 2, anchorY + 2)
        }
    } catch as err {
        FTB_Debug("chat input menu failed: " . err.Message, "err")
    }
}

; ===================== 缁愭褰涢崗鎶芥４娴滃娆?=====================
OnFloatingToolbarClose(*) {
    try NiumaMobileBrowser_Close()
    catch {
    }
    HideFloatingToolbar()
}

; ===================== 娴ｅ秶鐤嗘穱婵嗙摠閸滃苯濮炴潪?=====================
SaveFloatingToolbarPosition() {
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY
    global FloatingToolbarChatDrawerOpen, FloatingToolbarLastClosedX, FloatingToolbarLastClosedY

    if (!IsSet(FloatingToolbarGUI) || FloatingToolbarGUI = 0)
        return

    try {
        if (FloatingToolbarChatDrawerOpen && (FloatingToolbarLastClosedX != 0 || FloatingToolbarLastClosedY != 0)) {
            x := FloatingToolbarLastClosedX
            y := FloatingToolbarLastClosedY
        } else {
            FloatingToolbarGUI.GetPos(&x, &y)
        }
        FloatingToolbarWindowX := x
        FloatingToolbarWindowY := y

        ConfigFile := Nmer_ResolveConfigFile()
        IniWrite(String(x), ConfigFile, "WindowPositions", "FloatingToolbar_X")
        IniWrite(String(y), ConfigFile, "WindowPositions", "FloatingToolbar_Y")
    } catch {
    }
}

LoadFloatingToolbarPosition() {
    global FloatingToolbarWindowX, FloatingToolbarWindowY

    try {
        ConfigFile := Nmer_ResolveConfigFile()
        savedX := IniRead(ConfigFile, "WindowPositions", "FloatingToolbar_X", "")
        savedY := IniRead(ConfigFile, "WindowPositions", "FloatingToolbar_Y", "")

        if (savedX != "" && savedY != "" && savedX != "ERROR" && savedY != "ERROR") {
            FloatingToolbarWindowX := Integer(savedX)
            FloatingToolbarWindowY := Integer(savedY)

            ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
            vr := vl + vw
            vb := vt + vh
            ToolbarWidth := FloatingToolbarCalculateWidth()
            ToolbarHeight := FloatingToolbarCalculateHeight()

            if (FloatingToolbarWindowX < vl || FloatingToolbarWindowX > vr - ToolbarWidth)
                FloatingToolbarWindowX := vr - ToolbarWidth
            if (FloatingToolbarWindowY < vt || FloatingToolbarWindowY > vb - ToolbarHeight)
                FloatingToolbarWindowY := vb - ToolbarHeight
        }
    } catch {
        FloatingToolbarWindowX := 0
        FloatingToolbarWindowY := 0
    }
}

; ===================== 缂傗晜鏂佹穱婵嗙摠閸滃苯濮炴潪?=====================
FloatingToolbarSaveScale() {
    global FloatingToolbarScale
    try {
        ConfigFile := Nmer_ResolveConfigFile()
        IniWrite(String(FloatingToolbarScale), ConfigFile, "FloatingToolbar", "Scale")
    } catch {
    }
}

FloatingToolbarLoadScale() {
    global FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarMaxScale
    try {
        ConfigFile := Nmer_ResolveConfigFile()
        savedScale := IniRead(ConfigFile, "FloatingToolbar", "Scale", "1.0")
        if (savedScale != "" && savedScale != "ERROR") {
            scaleValue := IsSet(CfgParseFloat) ? CfgParseFloat(savedScale, 1.0) : Number(savedScale)
            if (scaleValue >= FloatingToolbarMinScale && scaleValue <= FloatingToolbarMaxScale)
                FloatingToolbarScale := scaleValue
        }
    } catch {
    }
    FloatingToolbarLoadDrawerWidth()
}

FloatingToolbar_ForceRecoverVisible() {
    global FloatingToolbarWindowX, FloatingToolbarWindowY, FloatingToolbarGUI
    global FloatingToolbarChatDrawerOpen, FloatingToolbarScale
    global g_FTB_WaitingUiFinishedReveal, g_FTB_UI_Ready, g_FTB_WV2_Ready
    global g_FTB_WV2
    try FloatingToolbar_ClearOverlaySuppression()
    catch {
    }
    try GDHO_UnpinFromDesktop()
    catch {
    }
    try GDHO_Stop()
    catch {
    }
    try NativeDropBridge_Stop()
    catch {
    }
    try {
        tw := FloatingToolbarCalculateWidth()
        th := FloatingToolbarCalculateHeight()
        ; Always recover to primary-screen visible area.
        FloatingToolbarWindowX := Max(16, A_ScreenWidth - tw - 36)
        FloatingToolbarWindowY := Max(16, A_ScreenHeight - th - 80)
        ConfigFile := Nmer_ResolveConfigFile()
        IniWrite(String(FloatingToolbarWindowX), ConfigFile, "WindowPositions", "FloatingToolbar_X")
        IniWrite(String(FloatingToolbarWindowY), ConfigFile, "WindowPositions", "FloatingToolbar_Y")
    } catch {
    }
    ; Reset sticky drawer/compact state before recreate/show.
    try FloatingToolbarChatDrawerOpen := false
    try FloatingToolbarScale := Max(1.0, FloatingToolbarScale)
    try FloatingToolbarSaveScale()
    try {
        if (g_FTB_WV2) {
            try FloatingToolbar_ResetWebToToolbarHome()
            catch {
            }
            WebView_QueuePayload(g_FTB_WV2, Map("type", "set_scale", "scale", FloatingToolbar_EffectiveScale(), "compact", false))
        }
    } catch {
    }
    ; Hard recovery: rebuild toolbar host once to break stuck reveal states.
    try {
        g_FTB_WaitingUiFinishedReveal := false
        g_FTB_UI_Ready := false
        g_FTB_WV2_Ready := false
        FloatingToolbar_ResetChatBridge()
        CreateFloatingToolbarGUI()
    } catch {
    }
    try ShowFloatingToolbar()
    catch {
    }
    try SetTimer(FloatingToolbar_RequestWebReveal, -200)
    try SetTimer((*) => ShowFloatingToolbar(), -260)
    catch {
    }
    try SetTimer((*) => ShowFloatingToolbar(), -680)
    catch {
    }
    ; Last resort: force host window visible immediately.
    try {
        if (FloatingToolbarGUI && IsObject(FloatingToolbarGUI) && (FloatingToolbarGUI is Gui)) {
            tw := FloatingToolbarCalculateWidth()
            th := FloatingToolbarCalculateHeight()
            FloatingToolbarGUI.Show("x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w" . tw . " h" . th . " NoActivate")
            WinSetTransparent(255, "ahk_id " . FloatingToolbarGUI.Hwnd)
        }
    } catch {
    }
}

FloatingToolbarIsCompactMode(scaleValue := "") {
    global FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarChatDrawerOpen
    sc := (scaleValue = "") ? FloatingToolbarScale : Float(scaleValue)
    if FloatingToolbarChatDrawerOpen
        return false
    ; 最小缩放时进入紧凑态：只保留一个 NiuMa 图标。
    return (sc <= (FloatingToolbarMinScale + 0.0001))
}

FloatingToolbarPushScaleStateToWeb(userScale := "") {
    global g_FTB_WV2, FloatingToolbarScale
    if !g_FTB_WV2
        return
    u := (userScale = "") ? FloatingToolbarScale : Float(userScale)
    eff := FloatingToolbar_EffectiveScaleFromUser(u)
    compact := FloatingToolbarIsCompactMode(u)
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_scale", "scale", eff, "compact", compact))
    catch as _e {
    }
}

FloatingToolbar_SwitchToToolbarFromMenu(*) {
    try FloatingToolbar_SetActivationMode("toolbar")
    catch {
    }
}

FloatingToolbar_SwitchToHoleMode(*) {
    global AppearanceActivationMode
    cur := FloatingToolbar_NormalizeAppearanceMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar")
    if (cur = "hole") {
        try FloatingBubbleShowFromMenu()
        catch {
        }
        return
    }
    try FloatingToolbar_SetActivationMode("hole")
    catch {
    }
    try SetTimer(FloatingBubbleShowFromMenu, -100)
    catch {
    }
}

FloatingToolbar_AppendActivationModeMenuItems(&MenuItems, mode := "", seenSlots := "") {
    global AppearanceActivationMode, GDHO_VISIBLE, g_GDHO_CurrentPhase, GDHO_PHASE_OPEN, GDHO_PHASE_OPENING
    if (IsObject(seenSlots) && seenSlots.Has("slot:switch_hole"))
        return
    m := (mode != "") ? FloatingToolbar_NormalizeAppearanceMode(mode) : FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode)
    if (m = "hole") {
        holeVisible := false
        try holeVisible := (g_GDHO_CurrentPhase = GDHO_PHASE_OPEN || g_GDHO_CurrentPhase = GDHO_PHASE_OPENING || GDHO_VISIBLE)
        catch {
            holeVisible := false
        }
        if (holeVisible)
            MenuItems.Push({ Text: "隐藏黑洞", Action: FloatingBubbleHideFromMenu, Icon: "◉" })
        else
            MenuItems.Push({ Text: "显示黑洞", Action: FloatingBubbleShowFromMenu, Icon: "◉" })
        MenuItems.Push({ Text: "切换到悬浮栏", Action: FloatingToolbar_SwitchToToolbarFromMenu, Icon: "▤" })
    } else {
        MenuItems.Push({ Text: "切换到黑洞", Action: FloatingToolbar_SwitchToHoleMode, Icon: "◉" })
        if (m = "bubble")
            MenuItems.Push({ Text: "切换到悬浮栏", Action: FloatingToolbar_SwitchToToolbarFromMenu, Icon: "▤" })
    }
    if (IsObject(seenSlots))
        seenSlots["slot:switch_hole"] := true
}

FloatingToolbar_MakeContextMenuAction(cmdId) {
    c := String(cmdId)
    return (*) => SetTimer(FloatingToolbar_DeferredToolbarCmd.Bind(c), -10)
}

FloatingToolbar_DeferredToolbarCmd(cmdId) {
    c := String(cmdId)
    ; 命令工具栏与面板类入口统一走 toggle，保证同一按钮可显可隐
    if (c = "sc_activate_search" || c = "ftm_search_center") {
        FloatingToolbar_OpenSearchCenterFromMenu()
        return
    }
    if (c = "qa_clipboard" || c = "ftm_clipboard") {
        FloatingToolbarToggleButtonAction("Record")
        return
    }
    if (c = "ch_b" || c = "qa_batch") {
        FloatingToolbarToggleButtonAction("Prompt")
        return
    }
    if (c = "ftb_scratchpad" || c = "hub_capsule") {
        FloatingToolbarToggleButtonAction("NewPrompt")
        return
    }
    if (c = "ftb_screenshot" || c = "ch_t") {
        FloatingToolbarToggleButtonAction("Screenshot")
        return
    }
    if (c = "ftb_cloud_player") {
        try ShowCloudPlayer()
        catch as e {
            try OutputDebug("[FloatingToolbar] cloud player open failed: " . e.Message)
            catch {
            }
        }
        return
    }
    if (c = "qa_config") {
        FloatingToolbarToggleButtonAction("Settings")
        return
    }
    if (c = "sys_show_vk") {
        FloatingToolbarToggleButtonAction("VirtualKeyboard")
        return
    }
    if (c = "ftb_cursor_menu") {
        FloatingToolbar_ShowCursorQuickMenu()
        return
    }
    if (c = "ftm_switch_hole") {
        FloatingToolbar_SwitchToHoleMode()
        return
    }
    try {
        _ExecuteCommand(c)
    } catch as e {
        try OutputDebug("[FloatingToolbar] toolbar_cmd: " . e.Message)
        catch {
        }
    }
}

FloatingToolbarPushCmdLayoutToWeb() {
    global g_FTB_WV2, g_Commands, FloatingToolbarCmdVisibleCount, FloatingToolbarChatDrawerOpen, g_FTB_BlockedCmdIds, g_FTB_AllowedCmdIds, FloatingToolbarMaxVisibleIcons
    if !g_FTB_WV2
        return
    try FloatingToolbar_EnsureCommandsLoaded()
    catch {
    }
    try {
        if (IsSet(_VK_EnsureToolbarLayout) && IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList"))
            _VK_EnsureToolbarLayout()
    } catch {
    }
    if !(IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("ToolbarLayout") && g_Commands["ToolbarLayout"] is Array
        && g_Commands.Has("CommandList") && g_Commands["CommandList"] is Map) {
        items := FloatingToolbar_BuildItemsFromCmdIds(FloatingToolbar_GetFallbackCmdIds())
        if (items.Length > 0) {
            try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_toolbar_cmds", "items", items))
            catch {
            }
        } else {
            try FloatingToolbar_PushLegacyToolbarActionsToWeb()
            catch {
            }
        }
        try FloatingToolbar_RequestWebReveal()
        catch {
        }
        return
    }
    cmdList := g_Commands["CommandList"]
    items := FloatingToolbar_BuildItemsFromSceneToolbarLayout()
    if (items.Length = 0) {
        seenCids := Map()
        seenScenes := Map()
        rows := []
        for row in g_Commands["ToolbarLayout"]
            rows.Push(row)
        if rows.Length > 1
            rows := _VK_SortRowsByNumericKey(rows, "order_bar")
        for row in rows {
            if !(row is Map) || !row.Has("cmdId")
                continue
            if !row.Has("visible_in_bar") || !row["visible_in_bar"]
                continue
            cid := Trim(String(row["cmdId"]))
            if (cid = "" || !cmdList.Has(cid) || g_FTB_BlockedCmdIds.Has(cid) || seenCids.Has(cid))
                continue
            sid := FloatingToolbar_CmdIdToSceneId(cid)
            if (sid != "" && seenScenes.Has(sid))
                continue
            seenCids[cid] := true
            if (sid != "")
                seenScenes[sid] := true
            rowPayload := FloatingToolbar_BuildToolbarItemPayload(cid, cmdList, sid)
            if (rowPayload is Map)
                items.Push(rowPayload)
        }
    }
    ; 让悬浮栏按实际可见项展开，避免 keybinder 下发的后续图标被 9 个上限截断。
    FloatingToolbarCmdVisibleCount := items.Length
    if (items.Length = 0) {
        items := FloatingToolbar_BuildItemsFromCmdIds(FloatingToolbar_GetFallbackCmdIds())
        if (items.Length = 0) {
            try FloatingToolbar_PushLegacyToolbarActionsToWeb()
            catch {
            }
            try FloatingToolbar_RequestWebReveal()
            catch {
            }
            return
        }
    }
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_toolbar_cmds", "items", items))
    catch as _e {
        try FloatingToolbar_PushLegacyToolbarActionsToWeb()
        catch {
        }
    }
    try FloatingToolbar_RequestWebReveal()
    catch {
    }
    if !FloatingToolbarChatDrawerOpen && !FloatingToolbarIsCompactMode()
        FloatingToolbar_ResizeForToolbarCount()
}

FloatingToolbar_GetCursorIconPath() {
    global g_FTB_CursorIconDataUrl
    if (g_FTB_CursorIconDataUrl != "")
        return g_FTB_CursorIconDataUrl
    iconFile := Nmer_AssetsIconPath("app", "cursor.png")
    if !FileExist(iconFile) {
        iconFile2 := A_ScriptDir "\images\cursor.png"
        if FileExist(iconFile2)
            iconFile := iconFile2
    }
    if !FileExist(iconFile)
        return iconFile
    try {
        buf := FileRead(iconFile, "RAW")
        b64 := FloatingToolbar_Base64EncodeBuffer(buf)
        if (b64 != "")
            g_FTB_CursorIconDataUrl := "data:image/png;base64," . b64
    } catch {
    }
    return (g_FTB_CursorIconDataUrl != "") ? g_FTB_CursorIconDataUrl : iconFile
}

FloatingToolbar_Base64EncodeBuffer(buf) {
    if !(buf is Buffer) || (buf.Size <= 0)
        return ""
    flags := 0x40000001 ; CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF
    chars := 0
    if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf.Ptr, "UInt", buf.Size, "UInt", flags, "Ptr", 0, "UInt*", &chars)
        return ""
    out := Buffer(chars * 2, 0)
    if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf.Ptr, "UInt", buf.Size, "UInt", flags, "Ptr", out.Ptr, "UInt*", &chars)
        return ""
    return Trim(StrGet(out.Ptr, "UTF-16"), "`r`n`t ")
}

FloatingToolbarReloadFromToolbarLayout() {
    FloatingToolbarPushCmdLayoutToWeb()
}

FloatingToolbarPushButtonConfigToWeb() {
    FloatingToolbarPushCmdLayoutToWeb()
}

FloatingToolbarExitCompactMode() {
    global FloatingToolbarGUI, FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarMaxScale
    global FloatingToolbarWindowX, FloatingToolbarWindowY

    if !IsObject(FloatingToolbarGUI) || !(FloatingToolbarGUI is Gui)
        return
    if !FloatingToolbarIsCompactMode()
        return

    targetScale := FloatingToolbarMinScale + 0.15
    if (targetScale > FloatingToolbarMaxScale)
        targetScale := FloatingToolbarMaxScale

    try FloatingToolbarGUI.GetPos(&oldX, &oldY, &oldW, &oldH)
    catch {
        oldX := FloatingToolbarWindowX
        oldY := FloatingToolbarWindowY
        oldW := FloatingToolbarCalculateWidth()
        oldH := FloatingToolbarCalculateHeight()
    }

    centerX := oldX + (oldW / 2.0)
    centerY := oldY + (oldH / 2.0)
    FloatingToolbarScale := targetScale
    newW := FloatingToolbarCalculateWidth()
    newH := FloatingToolbarCalculateHeight()
    newX := Round(centerX - (newW / 2.0))
    newY := Round(centerY - (newH / 2.0))

    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    vb := vt + vh
    if (newX < vl)
        newX := vl
    if (newY < vt)
        newY := vt
    if (newX + newW > vr)
        newX := vr - newW
    if (newY + newH > vb)
        newY := vb - newH

    FloatingToolbarWindowX := newX
    FloatingToolbarWindowY := newY
    FloatingToolbarGUI.Move(newX, newY, newW, newH)
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
    FloatingToolbarPushScaleStateToWeb(targetScale)
    FloatingToolbarSaveScale()
    SaveFloatingToolbarPosition()
}

; ===================== 鐠侊紕鐣诲銉ュ徔閺嶅繐顔旀惔锕€鎷版妯哄 =====================
FloatingToolbarCalculateWidth() {
    global FloatingToolbarChatDrawerOpen, FloatingToolbarChatDrawerWidth, FloatingToolbarCompactDiameter, FloatingToolbarCmdVisibleCount
    eff := FloatingToolbar_EffectiveScale()
    iconCount := (FloatingToolbarCmdVisibleCount > 0) ? FloatingToolbarCmdVisibleCount : 7
    ; 按「Logo + 图标数量」自适应宽度，并在最终像素向上取整避免右侧 1~2px 截断。
    ; CSS 对应：左右 padding(16) + logo(42) + 间距(8) + 图标区(40*n + 5*(n-1))
    BaseWidth := Max(190, 61 + iconCount * 45)
    if (FloatingToolbarChatDrawerOpen) {
        w := Ceil(Max(BaseWidth, FloatingToolbarChatDrawerWidth) * eff + 6)
        if NiumaMobileBrowser_IsActive()
            w += NiumaMobileBrowser_WidthPx()
        return w
    }
    if FloatingToolbarIsCompactMode()
        ; 紧凑态使用固定像素直径，避免高 DPI 下过小。
        return Round(FloatingToolbarCompactDiameter)
    return Ceil(BaseWidth * eff + 6)
}

FloatingToolbar_ShowCursorQuickMenu() {
    menuItems := []
    try {
        if (IsSet(g_Commands) && g_Commands is Map
            && g_Commands.Has("SceneMenus") && g_Commands["SceneMenus"] is Map
            && g_Commands["SceneMenus"].Has("cursor") && g_Commands["SceneMenus"]["cursor"] is Array) {
            vm := Map()
            if (g_Commands.Has("SceneMenuVisibility") && g_Commands["SceneMenuVisibility"] is Map
                && g_Commands["SceneMenuVisibility"].Has("cursor") && g_Commands["SceneMenuVisibility"]["cursor"] is Map)
                vm := g_Commands["SceneMenuVisibility"]["cursor"]
            cmdList := (g_Commands.Has("CommandList") && g_Commands["CommandList"] is Map) ? g_Commands["CommandList"] : Map()
            seen := Map()
            for cid0 in g_Commands["SceneMenus"]["cursor"] {
                cid := Trim(String(cid0))
                if (cid = "" || seen.Has(cid))
                    continue
                seen[cid] := true
                if vm.Has(cid) && !vm[cid]
                    continue
                if !cmdList.Has(cid)
                    continue
                nm := (cmdList[cid] is Map && cmdList[cid].Has("name")) ? String(cmdList[cid]["name"]) : cid
                menuItems.Push({ Text: nm, Icon: "▶", Action: ((*) => _ExecuteCommand(cid)) })
            }
        }
    } catch {
    }
    if (menuItems.Length = 0) {
        menuItems := [
            { Text: "命令面板  (Ctrl+Shift+P)", Icon: "▶", Action: (*) => _ExecuteCommand("qa_command_palette") },
            { Text: "全局搜索  (Ctrl+Shift+F)", Icon: "▶", Action: (*) => _ExecuteCommand("qa_global_search") },
            { Text: "资源管理器  (Ctrl+Shift+E)", Icon: "▶", Action: (*) => _ExecuteCommand("qa_explorer") },
            { Text: "源代码管理  (Ctrl+Shift+G)", Icon: "▶", Action: (*) => _ExecuteCommand("qa_source_control") },
            { Text: "扩展  (Ctrl+Shift+X)", Icon: "▶", Action: (*) => _ExecuteCommand("qa_extensions") },
            { Text: "终端  (Ctrl+Shift+``)", Icon: "▶", Action: (*) => _ExecuteCommand("qa_terminal") },
            { Text: "Cursor 设置  (Ctrl+,)", Icon: "▶", Action: (*) => _ExecuteCommand("qa_cursor_settings") }
        ]
    }
    try {
        MouseGetPos &mx, &my
        ShowDarkStylePopupMenuAt(menuItems, mx + 2, my + 2)
    } catch {
    }
}

FloatingToolbar_ResizeForToolbarCount() {
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY, FloatingToolbarChatDrawerOpen
    if !IsObject(FloatingToolbarGUI) || FloatingToolbarChatDrawerOpen || FloatingToolbarIsCompactMode()
        return
    newW := FloatingToolbarCalculateWidth()
    newH := FloatingToolbarCalculateHeight()
    try FloatingToolbarGUI.GetPos(&gx, &gy, &gw, &gh)
    catch {
        gx := FloatingToolbarWindowX
        gy := FloatingToolbarWindowY
        gw := newW
    }
    rightEdge := gx + gw
    newX := rightEdge - newW
    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    if (newX < vl)
        newX := vl
    if (newX + newW > vr)
        newX := vr - newW
    FloatingToolbarWindowX := newX
    FloatingToolbarWindowY := gy
    try FloatingToolbarGUI.Move(newX, gy, newW, newH)
    catch {
    }
    FloatingToolbar_ApplyWebViewBounds()
}

FloatingToolbarCalculateHeight() {
    global FloatingToolbarChatDrawerOpen, FloatingToolbarChatDrawerHeight, FloatingToolbarCompactDiameter
    eff := FloatingToolbar_EffectiveScale()
    ; 增加高度余量，避免放大后图标顶部/底部被裁。
    BaseHeight := 72
    if FloatingToolbarChatDrawerOpen {
        global FloatingToolbarGUI
        hwnd := FloatingToolbarGUI ? FloatingToolbarGUI.Hwnd : 0
        return FloatingToolbar_ChatDrawerHeightPx(hwnd)
    }
    if FloatingToolbarIsCompactMode()
        ; 紧凑态使用固定像素直径，避免高 DPI 下过小。
        return Round(FloatingToolbarCompactDiameter)
    return Round(BaseHeight * eff)
}

; ===================== 閺堚偓鐏忓繐瀵查崚鏉跨潌楠炴洝绔熺紓?=====================
MinimizeFloatingToolbarToEdge() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible

    if (!FloatingToolbarIsVisible || !IsSet(FloatingToolbarGUI) || FloatingToolbarGUI = 0)
        return

    ; 与早期一致：最小化表现为悬浮球圆圈，带过渡动画
    FloatingToolbar_AnimatedSwitchToBubble()
}

RestoreFloatingToolbar() {
    global FloatingToolbarIsMinimized
    FloatingToolbarIsMinimized := false
}

; ===================== 闁灏幇鐔风安閼辨柨濮?=====================
FloatingToolbar_NotifySelectionChange(fullText) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingSelection

    if !g_FTB_WV2 {
        g_FTB_PendingSelection := String(fullText)
        return
    }
    if !(g_FTB_WV2_Ready && g_FTB_WV2_FrameReady) {
        g_FTB_PendingSelection := String(fullText)
        return
    }
    pv := SubStr(String(fullText), 1, 220)
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CHANGE", "preview", pv))
    catch as _e {
        g_FTB_PendingSelection := String(fullText)
        return
    }
}

FloatingToolbar_NotifySelectionClear() {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingSelection

    g_FTB_PendingSelection := ""
    if !(g_FTB_WV2 && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CLEAR"))
    catch as _e {
    }
}

FloatingToolbar_SendTextToNiumaChat(text, sendNow := true, appendMode := true, openDrawer := true, providerId := "") {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingNiumaCompose, g_FTB_PendingOpenNiumaDrawer

    t := Trim(String(text), " `t`r`n")
    prov := Trim(String(providerId))
    if FuncExists("CommandPalette_AiLog") {
        preview := SubStr(t, 1, 40)
        if (StrLen(t) > 40)
            preview .= "…"
        try CommandPalette_AiLog("ftb_send_text", "provider=" . prov . " send=" . (sendNow ? 1 : 0) . " openDrawer=" . (openDrawer ? 1 : 0) . " text=" . preview)
        catch {
        }
    }
    if (t = "")
        return false
    if openDrawer
        g_FTB_PendingOpenNiumaDrawer := true
    if !g_FTB_WV2 {
        if FuncExists("CreateFloatingToolbarGUI") {
            try CreateFloatingToolbarGUI()
            catch as eGui {
                if FuncExists("CommandPalette_AiLog")
                    try CommandPalette_AiLog("ftb_send_no_wv2_create_err", eGui.Message)
                    catch {
                    }
            }
        }
        if !g_FTB_WV2 {
            if FuncExists("CommandPalette_AiLog")
                try CommandPalette_AiLog("ftb_send_no_wv2", "CreateFloatingToolbarGUI did not yield CoreWebView2")
                catch {
                }
            return false
        }
    }

    if openDrawer {
        try FloatingToolbarSetChatDrawerState(true)
    }

    payload := Map(
        "type", "niuma_compose_send",
        "text", t,
        "send", !!sendNow,
        "append", !!appendMode,
        "openDrawer", !!openDrawer
    )
    prov := Trim(String(providerId))
    if (prov != "")
        payload["provider"] := prov
    if !(g_FTB_WV2_Ready && g_FTB_WV2_FrameReady) {
        try {
            if !(g_FTB_PendingNiumaCompose is Array)
                g_FTB_PendingNiumaCompose := []
            g_FTB_PendingNiumaCompose.Push(payload)
            if FuncExists("CommandPalette_AiLog")
                try CommandPalette_AiLog("ftb_send_queued", "reason=wv2_not_ready ready=" . (g_FTB_WV2_Ready ? 1 : 0) . " frame=" . (g_FTB_WV2_FrameReady ? 1 : 0) . " queueLen=" . g_FTB_PendingNiumaCompose.Length)
                catch {
                }
            if openDrawer && FuncExists("FloatingToolbar_OpenNiumaChatDrawer")
                try FloatingToolbar_OpenNiumaChatDrawer(true)
                catch {
                }
            return true
        } catch as _ePending {
            if FuncExists("CommandPalette_AiLog")
                try CommandPalette_AiLog("ftb_send_queue_err", _ePending.Message)
                catch {
                }
            return false
        }
    }
    try {
        WebView_QueuePayload(g_FTB_WV2, payload)
        if FuncExists("CommandPalette_AiLog")
            try CommandPalette_AiLog("ftb_send_posted", "niuma_compose_send provider=" . prov)
            catch {
            }
        return true
    } catch as _e {
        if FuncExists("CommandPalette_AiLog")
            try CommandPalette_AiLog("ftb_send_post_err", _e.Message)
            catch {
            }
        return false
    }
}

; ===================== 初始化 =====================
InitFloatingToolbar() {
    ; 不在 WebView2 共享环境就绪前 Show：否则会先闪一小窗圆形启动图（ftbBootSplash），
    ; 再由 _WV2_BeginWarmupAfterEnv → ApplyAppearanceActivationMode 拉成完整悬浮栏。
    ; 正常展示由 ApplyAppearanceActivationMode / FloatingToolbar_ShowForActivationMode 负责。
    SetTimer(FloatingToolbar_InitShowFallback, -1800)
    SetTimer(FloatingToolbar_InitShowFallback, -4000)
}

FloatingToolbar_InitShowFallback(*) {
    global AppearanceActivationMode, FloatingToolbarIsVisible, g_FTB_WaitingUiFinishedReveal
    if (FloatingToolbar_NormalizeAppearanceMode(AppearanceActivationMode) != "toolbar")
        return
    if (FloatingToolbarIsVisible && !g_FTB_WaitingUiFinishedReveal)
        return
    try FloatingToolbar_ShowForActivationMode()
    catch {
        try ShowFloatingToolbar()
        catch {
        }
    }
}

FloatingToolbar_HandleDroppedFiles(filePaths) {
    global g_FTB_WV2
    paths := []
    for _, p in filePaths {
        s := Trim(String(p))
        if (s = "")
            continue
        paths.Push(s)
    }
    if (paths.Length = 0)
        return false
    uploaded := []
    failed := []
    for _, p in paths {
        try {
            ret := FloatingToolbar_SaveNiumaUploadFromLocalPath(p)
            if (ret is Map)
                uploaded.Push(ret)
        } catch as e {
            failed.Push(p . " => " . e.Message)
        }
    }
    if (uploaded.Length > 0 && g_FTB_WV2) {
        try WebView_QueuePayload(g_FTB_WV2, Map("type", "niuma_stage_attachments", "files", uploaded))
    }
    if (failed.Length > 0) {
        msg := "以下文件未能加入附件：" . "`n" . JoinArray(failed, "`n")
        try FloatingToolbar_SendTextToNiumaChat(msg, false, false, true)
    } else {
        ; Open Niuma drawer and hint user to send with attachments.
        try FloatingToolbarSetChatDrawerState(true)
        try FloatingToolbar_SendTextToNiumaChat("已添加附件，可直接发送。", false, false, true)
    }
    return (uploaded.Length > 0)
}

FloatingToolbar_HandleDroppedPayloadItems(items) {
    global g_FTB_WV2
    if !(items is Array) || (items.Length = 0)
        return false
    uploaded := []
    failed := []
    for _, it in items {
        if !(it is Map)
            continue
        p := it.Has("path") ? Trim(String(it["path"])) : ""
        nm := it.Has("name") ? Trim(String(it["name"])) : "file"
        typ := it.Has("type") ? String(it["type"]) : ""
        sz := it.Has("size") ? Integer(it["size"]) : 0
        b64 := it.Has("contentBase64") ? Trim(String(it["contentBase64"])) : ""
        try {
            if (b64 != "") {
                ret := FloatingToolbar_SaveNiumaUpload(Map(
                    "name", nm,
                    "relativePath", nm,
                    "type", typ,
                    "size", sz,
                    "contentBase64", b64
                ))
                uploaded.Push(ret)
            } else if (p != "") {
                ret := FloatingToolbar_SaveNiumaUploadFromLocalPath(p)
                uploaded.Push(ret)
            } else {
                throw Error("missing file content/path")
            }
        } catch as e {
            failed.Push(nm . " => " . e.Message)
        }
    }
    if (uploaded.Length > 0 && g_FTB_WV2) {
        try WebView_QueuePayload(g_FTB_WV2, Map("type", "niuma_stage_attachments", "files", uploaded))
    }
    if (failed.Length > 0) {
        msg := "以下文件未能加入附件：" . "`n" . JoinArray(failed, "`n")
        try FloatingToolbar_SendTextToNiumaChat(msg, false, false, true)
    } else {
        try FloatingToolbarSetChatDrawerState(true)
        try FloatingToolbar_SendTextToNiumaChat("已添加附件，可直接发送。", false, false, true)
    }
    return (uploaded.Length > 0)
}

; ===================== 閺嶈宓侀幐澶愭尦action閼惧嘲褰囬幓鎰仛閺傚洤鐡?=====================
GetButtonTip(action) {
    switch action {
        case "Search":
            return "鎼滅储璁板綍 (CapsLock + F)"
        case "Record":
            return "鏂板壀璐存澘 (WebView2 路 FTS5)"
        case "AIAssistant":
            return "AI 鍔╂墜 (Ctrl+Shift+B)"
        case "PromptNew":
            return "Hub 鑽夌 路 杩愯 hub_capsule 路 閲囬泦 CapsLock+C"
        case "Screenshot":
            return "灞忓箷鎴浘 (CapsLock + T)"
        case "Settings":
            return "绯荤粺璁剧疆 (CapsLock + Q)"
        case "VirtualKeyboard":
            return "铏氭嫙閿洏 (Ctrl+Shift+K)"
        default:
            return ""
    }
}

FloatingToolbar_DispatchChatPlanExecute(text, eid, platform, actReqId := "") {
    rid := String(actReqId)
    if (rid = "")
        rid := "plan-" . A_TickCount . "-" . Random(1000, 9999)
    global g_NiumaMobile_ObserveReqId, g_NiumaMobile_SettleReqId, g_NiumaMobile_ActReqId
    g_NiumaMobile_ActReqId := rid
    g_NiumaMobile_ObserveReqId := rid
    g_NiumaMobile_SettleReqId := rid
    NiumaMobileBrowser_LaunchChatPlanPipe(Integer(eid), String(text), String(platform), rid)
    return rid
}

FloatingToolbar_DispatchBrowserAction(action, eid, val, actReqId := "", forceDoubao := false, chatJsSend := false, deepseekJsFill := false, geminiJsFill := false) {
    action := String(action)
    rid := String(actReqId)
    if (rid = "")
        rid := "act-" . A_TickCount . "-" . Random(1000, 9999)
    global g_NiumaMobile_ObserveReqId, g_NiumaMobile_SettleReqId, g_NiumaMobile_ActReqId, g_NiumaMobile_ForceDoubaoInput, g_NiumaMobile_ChatSendOnly, g_NiumaMobile_DeepseekJsFillOnly, g_NiumaMobile_GeminiJsFillOnly
    g_NiumaMobile_ForceDoubaoInput := !!forceDoubao
    g_NiumaMobile_ChatSendOnly := !!chatJsSend
    g_NiumaMobile_DeepseekJsFillOnly := !!deepseekJsFill
    g_NiumaMobile_GeminiJsFillOnly := !!geminiJsFill
    g_NiumaMobile_ActReqId := rid
    g_NiumaMobile_ObserveReqId := rid
    g_NiumaMobile_SettleReqId := rid
    SetTimer(NiumaMobileBrowser_ActFromChatDeferred.Bind(action, Integer(eid), String(val)), -1)
    return rid
}

FloatingToolbar_CompatEnqueue(msgObj) {
    global g_FTB_CompatQueue
    g_FTB_CompatQueue.Push(msgObj)
    SetTimer(FloatingToolbar_ProcessCompatQueue, -1)
}

FloatingToolbar_ProcessCompatQueue(*) {
    global g_FTB_CompatLock, g_FTB_CompatQueue, g_FTB_CompatLockTimestamp, g_FTB_CompatCurrentReqId
    if (g_FTB_CompatLock) {
        FloatingToolbar_CheckCompatLockTimeout()
        return
    }
    if (g_FTB_CompatQueue.Length = 0)
        return
    g_FTB_CompatLock := true
    g_FTB_CompatLockTimestamp := A_TickCount
    msg := g_FTB_CompatQueue.RemoveAt(1)
    action := msg.Has("action") ? String(msg["action"]) : ""
    eid := msg.Has("elementId") ? Integer(msg["elementId"]) : (msg.Has("id") ? Integer(msg["id"]) : 0)
    val := msg.Has("text") ? String(msg["text"]) : (msg.Has("value") ? String(msg["value"]) : "")
    rid := "compat-" . A_TickCount . "-" . Random(1000, 9999)
    g_FTB_CompatCurrentReqId := rid
    FloatingToolbar_DispatchBrowserAction(action, eid, val, rid)
    SetTimer(FloatingToolbar_CheckCompatLockTimeout, -8100)
}

FloatingToolbar_CheckCompatLockTimeout(*) {
    global g_FTB_CompatLock, g_FTB_CompatLockTimestamp, g_FTB_CompatCurrentReqId, g_FTB_WV2
    if !g_FTB_CompatLock
        return
    if (A_TickCount - g_FTB_CompatLockTimestamp <= 8000)
        return
    rid := String(g_FTB_CompatCurrentReqId)
    try OutputDebug("[LOCK_BREAK] compat lock timeout >8s rid=" . rid)
    if g_FTB_WV2 {
        try WebView_QueueJson(g_FTB_WV2, '{"type":"host_browser_act_error","reqId":"' . rid . '","ok":false,"error":"compat_lock_timeout"}')
        try WebView_QueueJson(g_FTB_WV2, '{"type":"host_browser_act_error","ok":false,"error":"compat_lock_timeout"}')
    }
    SetTimer(FloatingToolbar_ReleaseCompatLock, -1)
}

FloatingToolbar_CompatOnActAck(reqId := "") {
    global g_FTB_CompatLock, g_FTB_CompatCurrentReqId
    if !g_FTB_CompatLock
        return
    if (String(reqId) = "" || String(reqId) != String(g_FTB_CompatCurrentReqId))
        return
    SetTimer(FloatingToolbar_ReleaseCompatLock, -1)
}

FloatingToolbar_ReleaseCompatLock(*) {
    global g_FTB_CompatLock, g_FTB_CompatCurrentReqId
    g_FTB_CompatLock := false
    g_FTB_CompatCurrentReqId := ""
    SetTimer(FloatingToolbar_ProcessCompatQueue, -1)
}
