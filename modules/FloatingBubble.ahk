; Floating bubble implemented with WebView2.
#Requires AutoHotkey v2.0

global FloatingBubbleGUI := 0
global g_FB_WV2_Ctrl := 0
global g_FB_WV2 := 0
global g_FB_WV2_Ready := false
global g_FB_WV2_FrameReady := false
global FloatingBubbleWindowX := 0
global FloatingBubbleWindowY := 0
global FloatingBubbleIsVisible := false
global FloatingBubbleDragging := false
global FloatingBubble_DragOriginScreenX := 0
global FloatingBubble_DragOriginScreenY := 0
global FloatingBubble_DragOriginWinX := 0
global FloatingBubble_DragOriginWinY := 0
global FloatingBubbleSize := 48
global g_FB_WV2_CreateRetry := 0
global g_FB_HostMouseDownTick := 0
global g_FB_HostMouseDownX := 0
global g_FB_HostMouseDownY := 0
global g_FB_HostMouseDown := false
global g_FB_HostDragTriggered := false

FloatingBubble_GetSize() {
    return FloatingBubbleSize
}

FloatingBubble_ApplyWindowShape(hwnd) {
    global FloatingBubbleGUI
    ; Layered bitmap rendering gives us per-pixel alpha, so no hard region is needed.
    return
}

FloatingBubble_DestroyCompletely() {
    global FloatingBubbleGUI, g_FB_WV2_Ctrl, g_FB_WV2, g_FB_WV2_Ready, g_FB_WV2_FrameReady
    global FloatingBubbleIsVisible, FloatingBubbleDragging
    FloatingBubbleDragging := false
    if (FloatingBubbleGUI = 0) {
        g_FB_WV2_Ctrl := 0
        g_FB_WV2 := 0
        g_FB_WV2_Ready := false
        g_FB_WV2_FrameReady := false
        return
    }
    try SaveFloatingBubblePosition()
    catch {
    }
    g_FB_WV2_Ctrl := 0
    g_FB_WV2 := 0
    g_FB_WV2_Ready := false
    g_FB_WV2_FrameReady := false
    try FloatingBubbleGUI.Destroy()
    catch {
    }
    FloatingBubbleGUI := 0
    FloatingBubbleIsVisible := false
}

FloatingBubble_OnNavigationStarting(sender, args) {
    global g_FB_WV2_FrameReady
    g_FB_WV2_FrameReady := false
}

FloatingBubble_OnNavigationCompleted(sender, args) {
    global g_FB_WV2_FrameReady
    ok := false
    try ok := args.IsSuccess
    catch {
        ok := false
    }
    g_FB_WV2_FrameReady := !!ok
}

FloatingBubble_OnWebMessage(sender, args) {
    global g_FB_WV2, g_FB_WV2_Ready, FloatingBubbleGUI, FloatingBubbleDragging
    msg := FloatingToolbar_ParseWebMessage(args)
    if !(msg is Map)
        return
    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ = "bubble_ready") {
        g_FB_WV2_Ready := true
        FloatingBubble_ApplyWebViewBounds()
        FloatingBubble_PushLogoToWeb()
        FloatingBubble_PushThemeToWeb()
        return
    }
    if (typ = "context_menu") {
        x := msg.Has("x") ? Integer(msg["x"]) : 0
        y := msg.Has("y") ? Integer(msg["y"]) : 0
        SetTimer(FloatingBubble_ShowContextMenuDeferred.Bind(x, y), -1)
        return
    }
    if (typ = "drag_host") {
        if !FloatingBubbleGUI || FloatingBubbleDragging
            return
        try FloatingBubbleGUI.GetPos(&FloatingBubble_DragOriginWinX, &FloatingBubble_DragOriginWinY)
        catch {
            return
        }
        CoordMode("Mouse", "Screen")
        MouseGetPos(&FloatingBubble_DragOriginScreenX, &FloatingBubble_DragOriginScreenY)
        FloatingBubbleDragging := true
        SetTimer(FloatingBubble_DragRun, -1)
        return
    }
    if (typ = "bubble_mode_menu") {
        x := msg.Has("x") ? Integer(msg["x"]) : 0
        y := msg.Has("y") ? Integer(msg["y"]) : 0
        SetTimer(FloatingBubble_ShowModeMenuDeferred.Bind(x, y), -1)
        return
    }
}

FloatingBubble_ShowModeMenuDeferred(x := 0, y := 0, *) {
    FloatingBubble_ShowModeMenuAt(x, y)
}

; 鎮诞鐞冿細鍏抽棴 / 鍒囨崲鎮诞鏍?/ 浠呮墭鐩橈紙涓庡瑙傝缃啓鍏ュ悓涓€閿級
FloatingBubble_PersistModeAndApply(mode) {
    global AppearanceActivationMode
    AppearanceActivationMode := NormalizeAppearanceActivationMode(mode)
    cfg := A_ScriptDir . "\CursorShortcut.ini"
    try IniWrite(AppearanceActivationMode, cfg, "Appearance", "ActivationMode")
    catch {
    }
    ; Apply after the current UI event finishes to avoid mode-switch races.
    SetTimer((*) => ApplyAppearanceActivationMode(), -200)
}

FloatingBubble_MenuClose(*) {
    try HideFloatingBubble()
    catch {
    }
}

FloatingBubble_MenuToolbarMode(*) {
    FloatingBubble_PersistModeAndApply("toolbar")
}

FloatingBubble_MenuTrayOnly(*) {
    FloatingBubble_PersistModeAndApply("tray")
}

FloatingBubble_ShowModeMenuAt(anchorX := 0, anchorY := 0) {
    static LastBubbleMenuTick := 0
    if (LastBubbleMenuTick != 0 && (A_TickCount - LastBubbleMenuTick < 450))
        return
    LastBubbleMenuTick := A_TickCount
    if (anchorX <= 0 || anchorY <= 0) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&anchorX, &anchorY)
    }
    MenuItems := []
    MenuItems.Push({ Text: "关闭悬浮球", Icon: "◻", Action: FloatingBubble_MenuClose })
    MenuItems.Push({ Text: "切换到悬浮栏模式", Icon: "▤", Action: FloatingBubble_MenuToolbarMode })
    MenuItems.Push({ Text: "永久关闭（仅托盘）", Icon: "⊡", Action: FloatingBubble_MenuTrayOnly })
    try ShowDarkStylePopupMenuAt(MenuItems, anchorX, anchorY)
    catch {
    }
}

FloatingBubble_ShowContextMenuDeferred(anchorX := 0, anchorY := 0) {
    if (anchorX <= 0 || anchorY <= 0) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&anchorX, &anchorY)
    }
    try ShowFloatingToolbarUnifiedContextMenu(anchorX, anchorY)
    catch {
    }
}

FloatingBubble_PushLogoToWeb(*) {
    FloatingBubble_RenderLayered()
}

FloatingBubble_PushThemeToWeb(*) {
    FloatingBubble_ApplyHostTheme()
}

FloatingBubble_ApplyHostTheme(mode := "") {
    FloatingBubble_RenderLayered(mode)
}

FloatingBubble_NormalizeThemeToken(raw, fallback := "dark") {
    s := StrLower(Trim(String(raw)))
    if (s = "light" || s = "lite")
        return "light"
    if (s = "dark")
        return "dark"
    return (fallback = "light") ? "light" : "dark"
}

FloatingBubble_GetThemeMode() {
    ; Prefer direct INI read so theme stays correct even if global state is stale.
    try {
        global ConfigFile
        if (IsSet(ConfigFile) && ConfigFile != "") {
            raw := IniRead(ConfigFile, "Settings", "ThemeMode", "")
            if (Trim(String(raw)) = "")
                raw := IniRead(ConfigFile, "Appearance", "ThemeMode", "")
            if (Trim(String(raw)) != "")
                return FloatingBubble_NormalizeThemeToken(raw, "dark")
        }
    } catch {
    }
    try {
        fn := Func("ReadPersistedThemeMode")
        if IsObject(fn)
            return FloatingBubble_NormalizeThemeToken(fn.Call(), "dark")
    } catch {
    }
    try {
        global ThemeMode
        return FloatingBubble_NormalizeThemeToken(ThemeMode, "dark")
    } catch {
    }
    return "dark"
}

FloatingBubble_ApplyWebViewBounds() {
    global FloatingBubbleGUI, g_FB_WV2_Ctrl
    FloatingBubble_RenderLayered()
}

FloatingBubble_RetryCreateWebView() {
    global FloatingBubbleGUI, g_FB_WV2_CreateRetry
    if !FloatingBubbleGUI
        return
    if (g_FB_WV2_CreateRetry >= 3)
        return
    g_FB_WV2_CreateRetry += 1
    SetTimer((*) => WebView2_CreateWithSharedEnvAsync(FloatingBubbleGUI.Hwnd, FloatingBubble_OnWebViewCreated, "floating_bubble"), -200)
}

FloatingBubble_OnWebViewCreated(ctrl) {
    global g_FB_WV2_Ctrl, g_FB_WV2, g_FB_WV2_Ready, g_FB_WV2_FrameReady, g_FB_WV2_CreateRetry

    if !IsObject(ctrl) || !ctrl.HasProp("CoreWebView2") {
        FloatingBubble_RetryCreateWebView()
        return
    }
    g_FB_WV2_CreateRetry := 0
    g_FB_WV2_Ctrl := ctrl
    g_FB_WV2 := ctrl.CoreWebView2
    g_FB_WV2_Ready := false
    g_FB_WV2_FrameReady := false
    ; Keep host + WebView background synchronized with current theme to reduce edge fringing.
    FloatingBubble_ApplyHostTheme()
    try ctrl.IsVisible := true

    FloatingBubble_ApplyWebViewBounds()

    s := g_FB_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.AreDevToolsEnabled := false
    try s.AreBrowserAcceleratorKeysEnabled := false
    ApplyWebView2PerformanceSettings(g_FB_WV2)
    WebView2_RegisterHostBridge(g_FB_WV2)

    g_FB_WV2.add_NavigationStarting(FloatingBubble_OnNavigationStarting)
    g_FB_WV2.add_NavigationCompleted(FloatingBubble_OnNavigationCompleted)
    g_FB_WV2.add_WebMessageReceived(FloatingBubble_OnWebMessage)
    try ApplyUnifiedWebViewAssets(g_FB_WV2)
    g_FB_WV2.Navigate(BuildAppLocalUrl("FloatingBubble.html"))
}

FloatingBubble_GetLogoFilePath() {
    candidates := [
        "牛马.png",
        "assets\牛马.png",
        "logo.png",
        "images\logo.png",
        "images\nimabu.png",
        "favicon.ico"
    ]
    for rel in candidates {
        full := A_ScriptDir . "\" . rel
        if FileExist(full)
            return full
    }
    return ""
}

FloatingBubble_RenderLayered(mode := "") {
    global FloatingBubbleGUI
    if !FloatingBubbleGUI
        return

    sz := FloatingBubble_GetSize()
    tm := FloatingBubble_NormalizeThemeToken(mode = "" ? FloatingBubble_GetThemeMode() : mode, "dark")
    circleColor := (tm = "light") ? 0xFFF7F7F7 : 0xFF121212
    outerStroke := (tm = "light") ? 0x14000000 : 0x10FFFFFF
    innerStroke := (tm = "light") ? 0x16000000 : 0x16FFFFFF

    pBitmap := Gdip_CreateBitmap(sz, sz)
    if !pBitmap
        return
    G := Gdip_GraphicsFromImage(pBitmap)
    if !G {
        Gdip_DisposeImage(pBitmap)
        return
    }
    Gdip_SetSmoothingMode(G, 4)
    Gdip_SetInterpolationMode(G, 7)
    Gdip_GraphicsClear(G, 0x00000000)

    brush := Gdip_BrushCreateSolid(circleColor)
    Gdip_FillEllipse(G, brush, 0.6, 0.6, sz - 1.2, sz - 1.2)
    Gdip_DeleteBrush(brush)

    penOuter := Gdip_CreatePen(outerStroke, 0.85)
    Gdip_DrawEllipse(G, penOuter, 0.75, 0.75, sz - 1.5, sz - 1.5)
    Gdip_DeletePen(penOuter)

    penInner := Gdip_CreatePen(innerStroke, 0.6)
    Gdip_DrawEllipse(G, penInner, 2.05, 2.05, sz - 4.1, sz - 4.1)
    Gdip_DeletePen(penInner)

    logoPath := FloatingBubble_GetLogoFilePath()
    if (logoPath != "") {
        pLogo := Gdip_CreateBitmapFromFile(logoPath)
        if (pLogo > 0) {
            logoSize := Round(sz * 0.76)
            logoX := Round((sz - logoSize) / 2)
            logoY := Round((sz - logoSize) / 2)
            Gdip_DrawImage(G, pLogo, logoX, logoY, logoSize, logoSize, 0, 0, Gdip_GetImageWidth(pLogo), Gdip_GetImageHeight(pLogo))
            Gdip_DisposeImage(pLogo)
        }
    }

    hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap, 0x00000000)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hBitmap)
    try UpdateLayeredWindow(FloatingBubbleGUI.Hwnd, hdc, "", "", sz, sz, 255)
    SelectObject(hdc, obm)
    DeleteObject(hBitmap)
    DeleteDC(hdc)
    Gdip_DeleteGraphics(G)
    Gdip_DisposeImage(pBitmap)
}

CreateFloatingBubbleGUI() {
    global FloatingBubbleGUI, g_FB_WV2_Ctrl, g_FB_WV2, g_FB_WV2_Ready, g_FB_WV2_FrameReady
    global WebView2, g_FB_WV2_CreateRetry
    g_FB_WV2_CreateRetry := 0

    if (FloatingBubbleGUI != 0) {
        g_FB_WV2_Ctrl := 0
        g_FB_WV2 := 0
        g_FB_WV2_Ready := false
        g_FB_WV2_FrameReady := false
        try FloatingBubbleGUI.Destroy()
        catch {
        }
    }

    FloatingBubbleGUI := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x00080000", "Floating Bubble")
    try FloatingBubble_BindHostMouseFallback(FloatingBubbleGUI.Hwnd)
    g_FB_WV2_Ctrl := 0
    g_FB_WV2 := 0
    g_FB_WV2_Ready := true
    g_FB_WV2_FrameReady := true
}

SaveFloatingBubblePosition() {
    global FloatingBubbleGUI, FloatingBubbleWindowX, FloatingBubbleWindowY
    if (FloatingBubbleGUI = 0)
        return
    try {
        FloatingBubbleGUI.GetPos(&x, &y)
        FloatingBubbleWindowX := x
        FloatingBubbleWindowY := y
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(String(x), ConfigFile, "WindowPositions", "FloatingBubble_X")
        IniWrite(String(y), ConfigFile, "WindowPositions", "FloatingBubble_Y")
    } catch {
    }
}

LoadFloatingBubblePosition() {
    global FloatingBubbleWindowX, FloatingBubbleWindowY
    try {
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        savedX := IniRead(ConfigFile, "WindowPositions", "FloatingBubble_X", "")
        savedY := IniRead(ConfigFile, "WindowPositions", "FloatingBubble_Y", "")
        if (savedX != "" && savedY != "" && savedX != "ERROR" && savedY != "ERROR") {
            FloatingBubbleWindowX := Integer(savedX)
            FloatingBubbleWindowY := Integer(savedY)
            sz := FloatingBubble_GetSize()
            ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
            vr := vl + vw
            vb := vt + vh
            if (FloatingBubbleWindowX < vl || FloatingBubbleWindowX > vr - sz)
                FloatingBubbleWindowX := vl
            if (FloatingBubbleWindowY < vt || FloatingBubbleWindowY > vb - sz)
                FloatingBubbleWindowY := vt
        }
    } catch {
        FloatingBubbleWindowX := 0
        FloatingBubbleWindowY := 0
    }
}

; 鍚屾鎷栧姩寰幆锛堟瘮 1ms 瀹氭椂鍣ㄦ洿璺熸墜锛岄伩鍏?WebView 娑堟伅娉典笌璁℃椂鍣ㄥ悎甯у欢杩燂級
FloatingBubble_DragRun(*) {
    global FloatingBubbleGUI, FloatingBubbleDragging, FloatingBubbleWindowX, FloatingBubbleWindowY
    global FloatingBubble_DragOriginScreenX, FloatingBubble_DragOriginScreenY
    global FloatingBubble_DragOriginWinX, FloatingBubble_DragOriginWinY

    if !(FloatingBubbleGUI && FloatingBubbleDragging)
        return
    try {
        while GetKeyState("LButton", "P") {
            CoordMode("Mouse", "Screen")
            MouseGetPos(&mx, &my)
            newX := FloatingBubble_DragOriginWinX + (mx - FloatingBubble_DragOriginScreenX)
            newY := FloatingBubble_DragOriginWinY + (my - FloatingBubble_DragOriginScreenY)
            sz := FloatingBubble_GetSize()
            ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
            vr := vl + vw
            vb := vt + vh
            if (newX < vl)
                newX := vl
            if (newY < vt)
                newY := vt
            if (newX + sz > vr)
                newX := vr - sz
            if (newY + sz > vb)
                newY := vb - sz
            try FloatingBubbleGUI.Move(newX, newY)
            FloatingBubbleWindowX := newX
            FloatingBubbleWindowY := newY
        }
    } catch {
    }
    FloatingBubbleDragging := false
    SaveFloatingBubblePosition()
    try FloatingBubble_ApplyWebViewBounds()
    catch {
    }
}

InitFloatingBubble() {
}

ShowFloatingBubble() {
    global FloatingBubbleGUI, FloatingBubbleIsVisible, FloatingBubbleWindowX, FloatingBubbleWindowY

    if (FloatingBubbleGUI = 0)
        CreateFloatingBubbleGUI()

    LoadFloatingBubblePosition()
    sz := FloatingBubble_GetSize()
    if (FloatingBubbleWindowX = 0 && FloatingBubbleWindowY = 0) {
        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        FloatingBubbleWindowX := vl + vw - sz - 16
        FloatingBubbleWindowY := vt + vh - sz - 16
    }

    try FloatingBubbleGUI.Show("x" . FloatingBubbleWindowX . " y" . FloatingBubbleWindowY . " w" . sz . " h" . sz . " NoActivate")
    catch {
    }
    FloatingBubble_ApplyWebViewBounds()
    FloatingBubbleIsVisible := true
    try WebView2_NotifyShown(g_FB_WV2)
    SetTimer(FloatingBubble_PushLogoToWeb, -50)
}

FloatingBubble_BindHostMouseFallback(hwnd) {
    static Bound := false
    if Bound
        return
    OnMessage(0x0201, FloatingBubble_HostLButtonDown) ; WM_LBUTTONDOWN
    OnMessage(0x0202, FloatingBubble_HostLButtonUp)   ; WM_LBUTTONUP
    OnMessage(0x0200, FloatingBubble_HostMouseMove)   ; WM_MOUSEMOVE
    OnMessage(0x0205, FloatingBubble_HostRButtonUp)   ; WM_RBUTTONUP
    ; Share the same middle-wheel mode switch handler with toolbar.
    OnMessage(0x020A, FloatingToolbarWM_MOUSEWHEEL)
    Bound := true
}

FloatingBubble_IsOwnHwnd(hwnd) {
    global FloatingBubbleGUI
    if (!IsSet(FloatingBubbleGUI) || !FloatingBubbleGUI)
        return false
    if (hwnd = FloatingBubbleGUI.Hwnd)
        return true
    try return DllCall("user32\GetAncestor", "ptr", hwnd, "uint", 2, "ptr") = FloatingBubbleGUI.Hwnd
    catch {
        return false
    }
}

FloatingBubble_HostLButtonDown(wParam, lParam, msg, hwnd) {
    global FloatingBubbleGUI, g_FB_HostMouseDown, g_FB_HostMouseDownTick
    global g_FB_HostMouseDownX, g_FB_HostMouseDownY, g_FB_HostDragTriggered
    if !FloatingBubble_IsOwnHwnd(hwnd)
        return
    g_FB_HostMouseDown := true
    g_FB_HostDragTriggered := false
    g_FB_HostMouseDownTick := A_TickCount
    CoordMode("Mouse", "Screen")
    MouseGetPos(&g_FB_HostMouseDownX, &g_FB_HostMouseDownY)
    SetTimer(FloatingBubble_HostStartDragIfHeld, -60)
}

FloatingBubble_HostMouseMove(wParam, lParam, msg, hwnd) {
    global FloatingBubbleGUI, g_FB_HostMouseDown, FloatingBubbleDragging
    global g_FB_HostMouseDownX, g_FB_HostMouseDownY
    if !FloatingBubble_IsOwnHwnd(hwnd)
        return
    if !g_FB_HostMouseDown || FloatingBubbleDragging
        return
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    dx := mx - g_FB_HostMouseDownX
    dy := my - g_FB_HostMouseDownY
    if (dx * dx + dy * dy >= 25)
        FloatingBubble_HostStartDragNow()
}

FloatingBubble_HostLButtonUp(wParam, lParam, msg, hwnd) {
    global FloatingBubbleGUI, g_FB_HostMouseDown, FloatingBubbleDragging, g_FB_HostDragTriggered
    if !FloatingBubble_IsOwnHwnd(hwnd)
        return
    hadDrag := FloatingBubbleDragging || g_FB_HostDragTriggered
    g_FB_HostMouseDown := false
    g_FB_HostDragTriggered := false
    if !hadDrag {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&x, &y)
        SetTimer(FloatingBubble_ShowModeMenuDeferred.Bind(x, y), -1)
    }
}

FloatingBubble_HostRButtonUp(wParam, lParam, msg, hwnd) {
    if !FloatingBubble_IsOwnHwnd(hwnd)
        return
    CoordMode("Mouse", "Screen")
    MouseGetPos(&x, &y)
    SetTimer(FloatingBubble_ShowContextMenuDeferred.Bind(x, y), -1)
}

FloatingBubble_HostStartDragIfHeld(*) {
    global g_FB_HostMouseDown, FloatingBubbleDragging
    if !g_FB_HostMouseDown || FloatingBubbleDragging
        return
    if !GetKeyState("LButton", "P")
        return
    FloatingBubble_HostStartDragNow()
}

FloatingBubble_HostStartDragNow() {
    global FloatingBubbleGUI, FloatingBubbleDragging, g_FB_HostDragTriggered
    global FloatingBubble_DragOriginWinX, FloatingBubble_DragOriginWinY
    global FloatingBubble_DragOriginScreenX, FloatingBubble_DragOriginScreenY
    if !FloatingBubbleGUI || FloatingBubbleDragging
        return
    try FloatingBubbleGUI.GetPos(&FloatingBubble_DragOriginWinX, &FloatingBubble_DragOriginWinY)
    CoordMode("Mouse", "Screen")
    MouseGetPos(&FloatingBubble_DragOriginScreenX, &FloatingBubble_DragOriginScreenY)
    g_FB_HostDragTriggered := true
    FloatingBubbleDragging := true
    SetTimer(FloatingBubble_DragRun, -1)
}

HideFloatingBubble() {
    global FloatingBubbleGUI, FloatingBubbleIsVisible, FloatingBubbleDragging
    global g_FB_HostMouseDown, g_FB_HostDragTriggered

    if (FloatingBubbleGUI = 0)
        return
    FloatingBubbleDragging := false
    g_FB_HostMouseDown := false
    g_FB_HostDragTriggered := false
    SaveFloatingBubblePosition()
    try WebView2_NotifyHidden(g_FB_WV2)
    try FloatingBubbleGUI.Hide()
    catch {
    }
    FloatingBubbleIsVisible := false
}
