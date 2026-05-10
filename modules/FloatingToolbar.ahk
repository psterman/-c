; ======================================================================================================================
; 閹剚璇炲銉ュ徔閺?- WebView2 閸忋劑鍣洪柌宥嗙€悧?; 閻楀牊婀? 2.0.0
; 閸旂喕鍏?
;   - 閺佸瓨娼銉ュ徔閺嶅繒鏁遍崡鏇氶嚋 WebView2 濞撳弶鐓嬮敍宀€绮烘稉鈧挧娑樺触缂?濮楁瑩鍘ら懝?;   - 瀹革箓鏁幏鏍уЗ閺佸鐛ラ妴浣圭泊鏉烆喚缂夐弨淇扁偓浣稿礁闁款喛褰嶉崡?;   - 7 娑擃亜濮涢懗鑺ュ瘻闁筋噯绱伴幖婊呭偍閵嗕浇顔囪ぐ鏇樷偓浣瑰絹缁€楦跨槤閵嗕焦鏌婇幓鎰仛鐠囧秲鈧焦鍩呴崶淇扁偓浣筋啎缂冾喓鈧線鏁惄?;   - 閹兼粎鍌ㄩ幐澶愭尦閺€顖涘瘮闁灏幇鐔风安閸涚厧鎯涢崝銊ф暰閸滃本瀚嬮弨鐐偝缁?; ======================================================================================================================

#Requires AutoHotkey v2.0

; 婢舵碍妯夌粈鍝勬珤閾忔碍瀚欏宀勬桨閸栧懎娲块惄鎺炵礄SM_XVIRTUALSCREEN 76閳?9閿?
ScreenVirtual_GetBounds(&outL, &outT, &outW, &outH) {
    outL := SysGet(76)
    outT := SysGet(77)
    outW := SysGet(78)
    outH := SysGet(79)
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

; 无 INI 时默认抽屉「逻辑宽」，随高 DPI 略增、并限制在 400–1000
FloatingToolbar_ChatDrawerDefaultWidth() {
    return Min(1000, Max(400, Round(620 * FloatingToolbar_DpiFactor())))
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
global FloatingToolbarDragging := false
global FloatingToolbar_DragOriginScreenX := 0
global FloatingToolbar_DragOriginScreenY := 0
global FloatingToolbar_DragOriginWinX := 0
global FloatingToolbar_DragOriginWinY := 0
global FloatingToolbar_DragStartTick := 0
global FloatingToolbar_DragMaxMs := 8000
global FloatingToolbarIsMinimized := false
global FloatingToolbarChatDrawerOpen := false
global FloatingToolbarChatDrawerWidth := 620
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
global g_FTB_WV2_FrameReady := false
global g_FTB_PendingSelection := ""
global g_FTB_PendingNiumaCompose := []
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
    global AppearanceActivationMode, FloatingToolbarIsVisible
    mode := NormalizeAppearanceActivationMode(AppearanceActivationMode)
    if (mode != "toolbar")
        return
    if FloatingToolbarIsVisible
        return
    try ShowFloatingToolbar()
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
    try WebView2_NotifyShown(g_FTB_WV2)
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
    SetTimer(FloatingToolbarCheckWindowPosition, 100)
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
    global g_FTB_UI_Ready, g_FTB_WaitingUiFinishedReveal, g_FTB_WV2_Ready

    if !FloatingToolbar_CanShowOverlay() {
        try HideFloatingToolbar()
        return
    }

    if (FloatingToolbarIsVisible && FloatingToolbarGUI != 0) {
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

    readyToReveal := (g_FTB_WV2_Ready && g_FTB_UI_Ready)

    ; WebView 已就绪（隐藏后再次打开）：直接不透明显示，不再等待
    if readyToReveal {
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

    if (FloatingToolbarGUI != 0) {
        SaveFloatingToolbarPosition()
        g_FTB_WaitingUiFinishedReveal := false
        SetTimer(FloatingToolbar_ForceRevealIfStuck, 0)
        try WinSetTransparent(255, "ahk_id " . FloatingToolbarGUI.Hwnd)
        catch {
        }
        try WebView2_NotifyHidden(g_FTB_WV2)
        try FloatingToolbarGUI.Hide()
        FloatingToolbarIsVisible := false
        SetTimer(FloatingToolbarCheckWindowPosition, 0)
    }
}

ToggleFloatingToolbar() {
    global FloatingToolbarIsVisible, AppearanceActivationMode, FloatingBubbleIsVisible

    if !FloatingToolbar_CanShowOverlay() {
        try HideFloatingToolbar()
        return
    }

    mode := NormalizeAppearanceActivationMode(AppearanceActivationMode)
    if (mode = "bubble") {
        if (FloatingBubbleIsVisible) {
            HideFloatingBubble()
        } else {
            ShowFloatingBubble()
        }
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
        g_FTB_PendingSelection := ""
        g_FTB_UI_Ready := false
        g_FTB_WaitingUiFinishedReveal := false
        g_FTB_WV2_CreateRetry := 0
        try FloatingToolbarGUI.Destroy()
        catch as _e {
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
        WebView2.create(FloatingToolbarGUI.Hwnd, FloatingToolbar_OnWebViewCreated, WebView2_EnsureSharedEnvBlocking())
    } catch as e {
        OutputDebug("[FTB] WebView2.create failed: " . e.Message)
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
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingNiumaCompose
    if !(g_FTB_WV2 && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return
    if !(g_FTB_PendingNiumaCompose is Array) || (g_FTB_PendingNiumaCompose.Length = 0)
        return
    try {
        for _, payload in g_FTB_PendingNiumaCompose {
            WebView_QueuePayload(g_FTB_WV2, payload)
        }
        g_FTB_PendingNiumaCompose := []
    } catch as _e {
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

    if !IsObject(ctrl) || !ctrl.HasProp("CoreWebView2") {
        OutputDebug("[FTB] WebView2 create failed: invalid controller")
        FloatingToolbar_RetryCreateWebView()
        return
    }
    g_FTB_WV2_CreateRetry := 0
    g_FTB_WV2_Ctrl := ctrl
    g_FTB_WV2 := ctrl.CoreWebView2
    g_FTB_WV2_Ready := false
    g_FTB_WV2_FrameReady := false

    ; Keep WebView2's first compositor frame dark; theme color is applied after UI_FINISHED.
    try ctrl.DefaultBackgroundColor := FloatingToolbar_GetBootBackColorArgb()
    try ctrl.IsVisible := true

    FloatingToolbar_ApplyWebViewBounds()

    s := g_FTB_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.AreDevToolsEnabled := false
    ; 避免 Ctrl+1/2/W 等被浏览器加速键先消费，确保 Niuma Chat 内快捷键优先生效
    try s.AreBrowserAcceleratorKeysEnabled := false
    ApplyWebView2PerformanceSettings(g_FTB_WV2)
    WebView2_RegisterHostBridge(g_FTB_WV2)

    g_FTB_WV2.add_NavigationStarting(FloatingToolbar_OnNavigationStarting)
    g_FTB_WV2.add_NavigationCompleted(FloatingToolbar_OnNavigationCompleted)
    g_FTB_WV2.add_WebMessageReceived(FloatingToolbar_OnWebMessage)
    try ApplyUnifiedWebViewAssets(g_FTB_WV2)
    ; 强制刷新 WebView 资源版本，避免命中旧缓存脚本导致前端变量未定义
    stripUrl := BuildAppLocalUrl("FloatingToolbarStrip.html")
    try {
        ver := String(FileGetTime(A_ScriptDir . "\FloatingToolbarStrip.html", "M"))
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

FloatingToolbar_ApplyWebViewBounds() {
    global FloatingToolbarGUI, g_FTB_WV2_Ctrl

    if !(FloatingToolbarGUI && g_FTB_WV2_Ctrl)
        return
    if FloatingToolbarIsCompactMode()
        FloatingToolbar_SyncCompactWindowSquare()

    WinGetClientPos(, , &cw, &ch, FloatingToolbarGUI.Hwnd)
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    try {
        g_FTB_WV2_Ctrl.Bounds := rc
        g_FTB_WV2_Ctrl.NotifyParentWindowPositionChanged()
    } catch {
    }
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
    SetTimer((*) => WebView2.create(FloatingToolbarGUI.Hwnd, FloatingToolbar_OnWebViewCreated, WebView2_EnsureSharedEnvBlocking()), -200)
}

FloatingToolbar_GetLogoAppUrl() {
    if !IsSet(BuildAppLocalUrl)
        return ""
    candidates := [
        "牛马.png",
        "logo.png",
        "images\logo.png",
        "images\nimabu.png",
        "favicon.ico"
    ]
    for rel in candidates {
        full := A_ScriptDir . "\" . rel
        if FileExist(full) {
            u := StrReplace(rel, "\", "/")
            try return BuildAppLocalUrl(u)
            catch {
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
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_logo", "url", url))
    catch as _e {
    }
}

; override 非空时直接使用该模式（与 ApplyTheme/INI 同步顺序无关，避免读 INI 读到旧值）
FloatingToolbar_PushThemeToWeb(override := "") {
    global g_FTB_WV2
    tm := (Trim(String(override)) != "")
        ? FloatingToolbar_NormalizeThemeToken(override, "dark")
        : FloatingToolbar_GetThemeMode()
    FloatingToolbar_ApplyHostThemeColorsForMode(tm)
    if !g_FTB_WV2
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_theme", "themeMode", tm))
    catch as _e {
    }
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

    if (typ = "toolbar_ready") {
        g_FTB_WV2_Ready := true
        FloatingToolbar_ApplyWebViewBounds()
        SetTimer(FloatingToolbar_PushLogoToWeb, -10)
        SetTimer(FloatingToolbar_PushThemeToWeb, -10)
        FloatingToolbarPushScaleStateToWeb(FloatingToolbarScale)
        FloatingToolbarPushButtonConfigToWeb()
        FloatingToolbar_FlushPendingSelectionIfReady()
        FloatingToolbar_FlushPendingNiumaComposeIfReady()
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

        ; 涓嶅啀浣跨敤 AnimateWindow(AW_BLEND)锛岄伩鍏嶉粦鐧芥笎鍙橀棯灞忥紱鐢?FloatingToolbar_FinishReveal 涓€娆℃€т笉閫忔槑鏄剧ず
        FloatingToolbar_FinishReveal()
        FloatingToolbar_FlushPendingNiumaComposeIfReady()
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
            SetTimer(FloatingToolbar_DeferredToolbarCmd.Bind(cid), -1)
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
        SetTimer(FloatingToolbar_ShowContextMenuDeferred.Bind(x, y), -1)
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
        SetTimer(FloatingToolbar_ShowContextMenuDeferred.Bind(x, y), -1)
        return
    }

    if (typ = "drawer_state") {
        open := msg.Has("open") && !!msg["open"]
        FTB_Debug("drawer_state open=" . open)
        FloatingToolbarSetChatDrawerState(open)
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
        ; WebView 回调内不可长时间阻塞；端口就绪后由 NiumaTtyd 回传 ttyd_ready / ttyd_error
        SetTimer(NiumaTtyd_DeferredOpenJob, -1)
        return
    }
    if (typ = "niuma_cli_restart") {
        SetTimer(NiumaTtyd_DeferredRestartJob, -1)
        return
    }
    if (typ = "niuma_cli_open_external") {
        SetTimer(NiumaTtyd_DeferredExternalOpenJob, -1)
        return
    }
    if (typ = "niuma_save_ttyd_shell") {
        sh := msg.Has("shell") ? Trim(String(msg["shell"])) : ""
        NiumaTtyd_SaveShellIni(sh)
        SetTimer(NiumaTtyd_DeferredRestartJob, -400)
        return
    }
    if (typ = "niuma_openclaw_probe_token") {
        force := msg.Has("force") && !!msg["force"]
        SetTimer(FloatingToolbar_DeferredProbeOpenClawToken.Bind(force), -1)
        return
    }
    if (typ = "niuma_debug_event") {
        evt := msg.Has("event") ? msg["event"] : ""
        FloatingToolbar_DebugWriteEvent(evt)
        return
    }
    if (typ = "niuma_debug_pull_go") {
        SetTimer(FloatingToolbar_DeferredDebugPullGo, -1)
        return
    }
    if (typ = "niuma_upload_file") {
        SetTimer(FloatingToolbar_DeferredNiumaUpload.Bind(msg), -1)
        return
    }
    if (typ = "niuma_attach_context") {
        SetTimer(FloatingToolbar_DeferredNiumaAttachContext.Bind(msg), -1)
        return
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

FloatingToolbar_NiumaDataDir() {
    return A_ScriptDir . "\Data\niuma-chat"
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
    p := InStr(n, ".",, -1)
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
        dir := A_ScriptDir . "\Data\NiuMaDebug"
        try DirCreate(dir)
        fp := dir . "\openclaw_timeline.jsonl"
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
    if (logical < 380)
        logical := 380
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
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
}

FloatingToolbarSaveDrawerWidth() {
    global FloatingToolbarChatDrawerWidth, ConfigFile
    try {
        if !IsSet(ConfigFile) || ConfigFile = ""
            ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(String(FloatingToolbarChatDrawerWidth), ConfigFile, "FloatingToolbar", "ChatDrawerWidth")
    } catch as _e {
    }
}

FloatingToolbarLoadDrawerWidth() {
    global FloatingToolbarChatDrawerWidth, ConfigFile
    try {
        if !IsSet(ConfigFile) || ConfigFile = ""
            ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        defW := String(FloatingToolbar_ChatDrawerDefaultWidth())
        v := IniRead(ConfigFile, "FloatingToolbar", "ChatDrawerWidth", defW)
        iv := Integer(v)
        if (iv >= 380 && iv <= 1200)
            FloatingToolbarChatDrawerWidth := iv
    } catch as _e {
    }
}

FloatingToolbarSetChatDrawerState(open) {
    global FloatingToolbarGUI, FloatingToolbarChatDrawerOpen
    global FloatingToolbarWindowX, FloatingToolbarWindowY, FloatingToolbarIsVisible
    global FloatingToolbarLastClosedX, FloatingToolbarLastClosedY

    open := !!open
    ; Do not gate by FloatingToolbarIsVisible: this state flag can lag behind
    ; WebView UI transitions and would block drawer open/close resize.
    if (!FloatingToolbarGUI)
        return

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

    FloatingToolbarChatDrawerOpen := open
    newW := FloatingToolbarCalculateWidth()
    newH := FloatingToolbarCalculateHeight()

    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    vb := vt + vh
    rightEdge := oldX + oldW

    if (open) {
        newX := rightEdge - newW
        newY := vt
    } else {
        if (FloatingToolbarLastClosedX != 0 || FloatingToolbarLastClosedY != 0) {
            newX := FloatingToolbarLastClosedX
            newY := FloatingToolbarLastClosedY
        } else {
            newX := rightEdge - newW
            newY := vb - newH
        }
    }

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
    FloatingToolbarPushScaleStateToWeb(FloatingToolbarScale)
    SaveFloatingToolbarPosition()
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
        try WebView_QueuePayload(g_FTB_WV2, Map("type", "host_force_toolbar_home"))
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
            HideFloatingToolbar()
            Sleep(120)
        }
        ExecuteScreenshotWithMenu(true)
        ; 截图流程完成后刷新防抖时间戳，阻止后续 1.5 秒内的重复触发
        g_FTB_ScreenshotDeferLastTick := A_TickCount
    } catch as err {
        ; Hide/Sleep 鍦?ExecuteScreenshotWithMenu 涔嬪墠澶辫触鏃讹紝棰勫崰鐨?busy 涓嶄細鐢卞悗鑰?finally 娓呴櫎
        g_ExecuteScreenshotWithMenuBusy := false
        try OutputDebug("[FloatingToolbar] DeferredScreenshot: " . err.Message)
        catch {
        }
    }
    ; 悬浮条在 ExecuteScreenshotWithMenu 内剪贴板就绪后、ShowScreenshotEditor 前统一恢复，避免 finally 再延迟 Show 造成双重显示与位移
}

FloatingToolbar_EnsureSearchCenterFocused(*) {
    global GuiID_SearchCenter

    try {
        hwnd := 0
        if (IsSet(SCWV_GetGuiHwnd))
            hwnd := SCWV_GetGuiHwnd()
        if (!hwnd && GuiID_SearchCenter && IsObject(GuiID_SearchCenter) && GuiID_SearchCenter.HasProp("Hwnd"))
            hwnd := GuiID_SearchCenter.Hwnd
        if !hwnd
            return
        WinActivate("ahk_id " . hwnd)
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

    ; 搜索中心未真正拉起：释放 search dock 抑制并恢复工具栏可见性
    try FloatingToolbar_PageDockLeave("search")
    if (NormalizeAppearanceActivationMode(AppearanceActivationMode) = "toolbar" && !FloatingToolbarIsVisible) {
        try ShowFloatingToolbar()
    }
}

; 拖拽入口：异步打开搜索中心，避免在 WebMessage 回调内同步跑搜索导致工具栏卡死。
FloatingToolbar_RequestSearchByKeyword(keyword) {
    kw := Trim(String(keyword))
    if (kw = "")
        return
    SetTimer(FloatingToolbar_DeferredOpenSearchByKeyword.Bind(kw), -1)
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
    if (NormalizeAppearanceActivationMode(AppearanceActivationMode) = "toolbar" && !FloatingToolbarIsVisible) {
        try ShowFloatingToolbar()
    }
}

FloatingToolbar_ActivateSearchCenter() {
    selectedText := ""
    opened := false
    usedWebView := false

    try usedWebView := SearchCenter_ShouldUseWebView()
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
            SCWV_Init()
            SCWV_Show()
        } else
            ShowSearchCenter()
        opened := true
    } catch {
    }

    ; 鍏滃簳閲嶅缓锛氶伩鍏?g_SCWV_Visible / 瀹夸富鍙ユ焺娈嬬暀瀵艰嚧鈥滃垽瀹氬凡寮€浣嗛潰鏉挎病鍑烘潵鈥濄€?
    if (!opened && usedWebView) {
        try {
            SCWV_ResetHostState()
            SCWV_Init()
            SCWV_Show()
            opened := true
        } catch {
        }
    }

    if (!opened) {
        try ShowSearchCenter()
        catch {
        }
    }

    ; 涓嶈鍏ュ彛鏉ヨ嚜鍥炬爣杩樻槸鍙抽敭鑿滃崟锛屾渶鍚庨兘鍐嶅己鍒朵竴娆″彲瑙佷笌杈撳叆鐒︾偣銆?
    if (usedWebView) {
        try {
            if (!SCWV_IsVisible())
                SCWV_Show()
        } catch {
            try {
                SCWV_ResetHostState()
                SCWV_Init()
                SCWV_Show()
            } catch {
            }
        }
        try {
            SCWV_RequestFocusInput()
        } catch {
        }
    }

    ; 宸ュ叿鏍忕偣鍑诲悗鍓嶅彴鍙兘浠嶇煭鏆傚仠鍦ㄥ伐鍏锋爮 WebView锛屼笂涓€涓縺娲婚摼浼氬悶鎺夌劍鐐癸紱琛ュ嚑娆＄‘淇濇悳绱腑蹇冪湡姝ｆ嬁鍒拌緭鍏ョ劍鐐广€?
    SetTimer(FloatingToolbar_EnsureSearchCenterFocused, -20)
    SetTimer(FloatingToolbar_EnsureSearchCenterFocused, -120)
    SetTimer(FloatingToolbar_EnsureSearchCenterFocused, -320)
    ; 防竞态：若焦点/宿主状态异常导致搜索中心未出现，自动回滚工具栏隐藏态
    SetTimer(FloatingToolbar_VerifySearchCenterOpen, -260)
    SetTimer(FloatingToolbar_VerifySearchCenterOpen, -900)
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
            SetTimer(FloatingToolbar_DeferredScreenshot, -1)
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
            SetTimer(FloatingToolbar_ActivateSearchCenter, -1)
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
            SetTimer(FloatingToolbar_PromptToggleDeferred, -1)
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
    mode := NormalizeAppearanceActivationMode(AppearanceActivationMode)

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

    if (mouseInToolbar || mouseInBubble) {
        FloatingToolbar_SwitchActivationByWheel(delta)
        return 0
    }

    if (!mouseInToolbar)
        return
    if (mode != "toolbar")
        return
    ; 抽屉展开时由页面内滚动，不在此处用滚轮缩放整窗
    if (FloatingToolbarChatDrawerOpen)
        return

    FloatingToolbarApplyWheelDelta(delta)

    return 0
}

FloatingToolbar_SetActivationMode(mode) {
    global AppearanceActivationMode
    m := NormalizeAppearanceActivationMode(mode)
    if (m != "toolbar" && m != "bubble" && m != "tray")
        return
    AppearanceActivationMode := m
    cfg := A_ScriptDir . "\CursorShortcut.ini"
    try IniWrite(AppearanceActivationMode, cfg, "Appearance", "ActivationMode")
    catch {
    }
    SetTimer((*) => ApplyAppearanceActivationMode(), -10)
}

FloatingToolbar_SwitchActivationByWheel(delta) {
    global AppearanceActivationMode, FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarMaxScale
    global FloatingToolbarWindowX, FloatingToolbarWindowY
    global FloatingBubbleGUI, FloatingBubbleIsVisible, FloatingBubbleWindowX, FloatingBubbleWindowY
    mode := NormalizeAppearanceActivationMode(AppearanceActivationMode)
    if (delta > 0) {
        if (mode != "toolbar") {
            ; Ensure wheel-up from bubble opens full toolbar directly (skip compact square state).
            if FloatingToolbarIsCompactMode() {
                targetScale := FloatingToolbarMinScale + 0.15
                if (targetScale > FloatingToolbarMaxScale)
                    targetScale := FloatingToolbarMaxScale
                FloatingToolbarScale := targetScale
                FloatingToolbarSaveScale()
            }

            ; Anchor expansion to bubble center so position follows visual continuity.
            if (mode = "bubble" && FloatingBubbleIsVisible) {
                bx := FloatingBubbleWindowX
                by := FloatingBubbleWindowY
                bw := bh := 0
                try FloatingBubbleGUI.GetPos(&bx, &by, &bw, &bh)
                catch {
                }
                if (bw <= 0 || bh <= 0) {
                    try bw := bh := FloatingBubble_GetSize()
                    catch {
                        bw := bh := 48
                    }
                }
                cx := bx + (bw / 2.0)
                cy := by + (bh / 2.0)
                tw := FloatingToolbarCalculateWidth()
                th := FloatingToolbarCalculateHeight()
                newX := Round(cx - (tw / 2.0))
                newY := Round(cy - (th / 2.0))
                ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
                vr := vl + vw
                vb := vt + vh
                if (newX < vl)
                    newX := vl
                if (newY < vt)
                    newY := vt
                if (newX + tw > vr)
                    newX := vr - tw
                if (newY + th > vb)
                    newY := vb - th
                FloatingToolbarWindowX := newX
                FloatingToolbarWindowY := newY
                cfg := A_ScriptDir . "\CursorShortcut.ini"
                try IniWrite(String(newX), cfg, "WindowPositions", "FloatingToolbar_X")
                try IniWrite(String(newY), cfg, "WindowPositions", "FloatingToolbar_Y")
            }
            FloatingToolbar_SetActivationMode("toolbar")
        }
        return
    }
    if (mode != "bubble") {
        ; Persist bubble target position before mode switch; ShowFloatingBubble() reloads from ini.
        tx := FloatingToolbarWindowX
        ty := FloatingToolbarWindowY
        tw := th := 0
        if IsObject(FloatingToolbarGUI) {
            try FloatingToolbarGUI.GetPos(&tx, &ty, &tw, &th)
            catch {
            }
        }
        if (tw <= 0 || th <= 0) {
            tw := FloatingToolbarCalculateWidth()
            th := FloatingToolbarCalculateHeight()
        }
        try bs := FloatingBubble_GetSize()
        catch {
            bs := 48
        }
        bx := Round(tx + (tw - bs) / 2.0)
        by := Round(ty + (th - bs) / 2.0)
        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        vr := vl + vw
        vb := vt + vh
        if (bx < vl)
            bx := vl
        if (by < vt)
            by := vt
        if (bx + bs > vr)
            bx := vr - bs
        if (by + bs > vb)
            by := vb - bs
        FloatingBubbleWindowX := bx
        FloatingBubbleWindowY := by
        cfg := A_ScriptDir . "\CursorShortcut.ini"
        try IniWrite(String(bx), cfg, "WindowPositions", "FloatingBubble_X")
        try IniWrite(String(by), cfg, "WindowPositions", "FloatingBubble_Y")
        FloatingToolbar_SetActivationMode("bubble")
    }
}

FloatingToolbarApplyWheelDelta(delta) {
    global FloatingToolbarGUI, FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarMaxScale
    global FloatingToolbarWindowX, FloatingToolbarWindowY, g_FTB_WV2

    ; 必须与 CreateFloatingToolbarGUI 创建的 Gui 一致；勿与他处同名全局混用，否则此处可能得到 Integer 而非 Gui
    if !IsObject(FloatingToolbarGUI) || !(FloatingToolbarGUI is Gui)
        return

    scaleStep := 0.15
    newScale := FloatingToolbarScale

    ; Scroll-down from toolbar should switch directly to bubble before entering compact square.
    if (delta < 0 && (FloatingToolbarScale - scaleStep) <= (FloatingToolbarMinScale + 0.0001)) {
        FloatingToolbar_SwitchActivationByWheel(-1)
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

        if (delta < 0 && FloatingToolbarIsCompactMode(newScale)) {
            ; Reaching minimum scale switches to bubble mode instead of staying a square compact block.
            FloatingToolbar_SwitchActivationByWheel(-1)
        }
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
        if (newX < vl)
            newX := vl
        if (newY < vt)
            newY := vt
        if (newX + ToolbarWidth > vr)
            newX := vr - ToolbarWidth
        if (newY + ToolbarHeight > vb)
            newY := vb - ToolbarHeight
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

    if (!FloatingToolbarIsVisible || !IsSet(FloatingToolbarGUI) || FloatingToolbarGUI = 0)
        return

    if (FloatingToolbarDragging)
        return

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
    SetTimer(FloatingToolbar_ShowContextMenuDeferred.Bind(mx, my), -1)
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
    if (anchorX <= 0 || anchorY <= 0) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&anchorX, &anchorY)
    }
    FTB_Debug("show menu @" . anchorX . "," . anchorY)
    try ShowFloatingToolbarUnifiedContextMenu(anchorX, anchorY)
    catch as err {
        FTB_Debug("show menu failed: " . err.Message, "err")
    }
}

; ===================== 缁愭褰涢崗鎶芥４娴滃娆?=====================
OnFloatingToolbarClose(*) {
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

        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(String(x), ConfigFile, "WindowPositions", "FloatingToolbar_X")
        IniWrite(String(y), ConfigFile, "WindowPositions", "FloatingToolbar_Y")
    } catch {
    }
}

LoadFloatingToolbarPosition() {
    global FloatingToolbarWindowX, FloatingToolbarWindowY

    try {
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
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
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(String(FloatingToolbarScale), ConfigFile, "FloatingToolbar", "Scale")
    } catch {
    }
}

FloatingToolbarLoadScale() {
    global FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarMaxScale
    try {
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        savedScale := IniRead(ConfigFile, "FloatingToolbar", "Scale", "1.0")
        if (savedScale != "" && savedScale != "ERROR") {
            scaleValue := Float(savedScale)
            if (scaleValue >= FloatingToolbarMinScale && scaleValue <= FloatingToolbarMaxScale)
                FloatingToolbarScale := scaleValue
        }
    } catch {
    }
    FloatingToolbarLoadDrawerWidth()
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

FloatingToolbar_DeferredToolbarCmd(cmdId) {
    c := String(cmdId)
    ; 命令工具栏与面板类入口统一走 toggle，保证同一按钮可显可隐
    if (c = "sc_activate_search") {
        FloatingToolbarToggleButtonAction("Search")
        return
    }
    if (c = "qa_clipboard") {
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
    try {
        if (!IsSet(g_Commands) || !(g_Commands is Map) || !g_Commands.Has("CommandList") || !(g_Commands["CommandList"] is Map)
            || g_Commands["CommandList"].Count = 0)
            _LoadCommands()
    } catch {
    }
    try {
        if (IsSet(_VK_EnsureToolbarLayout) && IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList"))
            _VK_EnsureToolbarLayout()
    } catch {
    }
    if !(IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("ToolbarLayout") && g_Commands["ToolbarLayout"] is Array
        && g_Commands.Has("CommandList") && g_Commands["CommandList"] is Map)
        return
    cmdList := g_Commands["CommandList"]
    items := []
    hasCursorMenu := false
    hasCloudPlayer := false
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
        if (cid = "" || !cmdList.Has(cid))
            continue
        if g_FTB_BlockedCmdIds.Has(cid)
            continue
        if !g_FTB_AllowedCmdIds.Has(cid)
            continue
        ent := cmdList[cid]
        nm := ent.Has("name") ? String(ent["name"]) : cid
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
            hasCursorMenu := true
            rowPayload["iconPath"] := FloatingToolbar_GetCursorIconPath()
        }
        if (cid = "ftb_cloud_player")
            hasCloudPlayer := true
        if (cid != "ftb_cursor_menu" && (ent is Map) && ent.Has("iconPath") && ent["iconPath"] != "")
            rowPayload["iconPath"] := String(ent["iconPath"])
        items.Push(rowPayload)
    }
    if !hasCloudPlayer {
        items.Push(Map(
            "cmdId", "ftb_cloud_player",
            "name", "云盘",
            "iconClass", "fa-solid fa-cloud"
        ))
    }
    ; ToolbarLayout 里没配置时也保底补上 cursor 菜单按钮，避免图标缺失。
    if !hasCursorMenu {
        items.Push(Map(
            "cmdId", "ftb_cursor_menu",
            "name", "Cursor",
            "iconClass", "fa-solid fa-location-crosshairs",
            "iconPath", FloatingToolbar_GetCursorIconPath()
        ))
    }
    maxIcons := (FloatingToolbarMaxVisibleIcons > 0) ? Integer(FloatingToolbarMaxVisibleIcons) : 9
    if (maxIcons < 1)
        maxIcons := 1
    if (items.Length > maxIcons) {
        trimmed := []
        Loop maxIcons
            trimmed.Push(items[A_Index])
        items := trimmed
    }
    cloudVisible := false
    for _, it in items {
        if ((it is Map) && it.Has("cmdId") && String(it["cmdId"]) = "ftb_cloud_player") {
            cloudVisible := true
            break
        }
    }
    if !cloudVisible {
        if (items.Length >= maxIcons && items.Length > 0)
            items[items.Length] := Map("cmdId", "ftb_cloud_player", "name", "云盘", "iconClass", "fa-solid fa-cloud")
        else
            items.Push(Map("cmdId", "ftb_cloud_player", "name", "云盘", "iconClass", "fa-solid fa-cloud"))
    }
    FloatingToolbarCmdVisibleCount := items.Length
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_toolbar_cmds", "items", items))
    catch as _e {
    }
    if !FloatingToolbarChatDrawerOpen && !FloatingToolbarIsCompactMode()
        FloatingToolbar_ResizeForToolbarCount()
}

FloatingToolbar_GetCursorIconPath() {
    global g_FTB_CursorIconDataUrl
    if (g_FTB_CursorIconDataUrl != "")
        return g_FTB_CursorIconDataUrl
    iconFile := A_ScriptDir "\lib\images\cursor.png"
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
    global FloatingToolbarChatDrawerOpen, FloatingToolbarChatDrawerWidth, FloatingToolbarCompactDiameter, FloatingToolbarCmdVisibleCount, FloatingToolbarMaxVisibleIcons
    eff := FloatingToolbar_EffectiveScale()
    iconCount := (FloatingToolbarCmdVisibleCount > 0) ? FloatingToolbarCmdVisibleCount : 7
    if (FloatingToolbarMaxVisibleIcons > 0 && iconCount > FloatingToolbarMaxVisibleIcons)
        iconCount := FloatingToolbarMaxVisibleIcons
    ; 按「Logo + 图标数量」自适应宽度，并在最终像素向上取整避免右侧 1~2px 截断。
    ; CSS 对应：左右 padding(16) + logo(42) + 间距(8) + 图标区(40*n + 5*(n-1))
    BaseWidth := Max(190, 61 + iconCount * 45)
    if (FloatingToolbarChatDrawerOpen)
        return Ceil(Max(BaseWidth, FloatingToolbarChatDrawerWidth) * eff + 6)
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
        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        return vh
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

    ; Prefer bubble mode as the minimized representation.
    FloatingToolbar_SwitchActivationByWheel(-1)
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

FloatingToolbar_SendTextToNiumaChat(text, sendNow := true, appendMode := true, openDrawer := true) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingNiumaCompose

    t := Trim(String(text), " `t`r`n")
    if (t = "")
        return false
    if !g_FTB_WV2
        return false

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
    if !(g_FTB_WV2_Ready && g_FTB_WV2_FrameReady) {
        try {
            if !(g_FTB_PendingNiumaCompose is Array)
                g_FTB_PendingNiumaCompose := []
            g_FTB_PendingNiumaCompose.Push(payload)
            return true
        } catch as _ePending {
            return false
        }
    }
    try {
        WebView_QueuePayload(g_FTB_WV2, payload)
        return true
    } catch as _e {
        return false
    }
}

; ===================== 閸掓繂顫愰崠?=====================
InitFloatingToolbar() {
    try ShowFloatingToolbar()
    ; 启动后兜底重试，避免共享环境/首帧竞态导致工具栏未显示
    SetTimer((*) => ShowFloatingToolbar(), -1200)
    SetTimer((*) => ShowFloatingToolbar(), -3200)
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
