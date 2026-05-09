#Requires AutoHotkey v2.0

; GlobalDragHoleOverlay.ahk
; AHK global drag pre-judge -> drive Wails/WebView2 hole frontend (window.HoleOverlay.*)

global GDHO_GUI := 0
global GDHO_WV2_CTRL := 0
global GDHO_WV2 := 0
global GDHO_READY := false
global GDHO_VISIBLE := false
global GDHO_ACTIVE := false
global GDHO_PAYLOAD := "file"
global GDHO_DRAG_SOURCE_CLASS := ""
global GDHO_START_X := 0
global GDHO_START_Y := 0
global GDHO_START_CURSOR := 0
global GDHO_LAST_X := 0
global GDHO_LAST_Y := 0
global GDHO_MONITORING := false
global GDHO_PAGE_URL := "http://127.0.0.1:5173/hole.html"
global GDHO_FALLBACK_URL := ""
global GDHO_NAV_FAIL_COUNT := 0
global GDHO_PREWARM_DONE := false
global GDHO_FIRST_REVEAL_DONE := false

; drag pre-judge parameters
global GDHO_MIN_MOVE_PX := 10
global GDHO_POLL_MS := 24
global GDHO_MAX_IDLE_HIDE_MS := 160
global GDHO_LAST_UPDATE_TICK := 0
global GDHO_DESKTOP_PINNED := false
global GDHO_PIN_PAYLOAD := "text"
global GDHO_ANCHOR_W := 160
global GDHO_ANCHOR_H := 206
global GDHO_ANCHOR_GAP := 10
global GDHO_ANCHOR_MODE := "toolbar_auto_vertical" ; toolbar_auto_vertical|toolbar_below|toolbar_above|toolbar_center|toolbar_left|toolbar_right|screen
global GDHO_ANCHOR_OFFSET_X := 0
global GDHO_ANCHOR_OFFSET_Y := 0
global GDHO_SCREEN_X := 120
global GDHO_SCREEN_Y := 120
global GDHO_CLICKTHROUGH := true
global GDHO_UPDATE_MIN_INTERVAL_MS := 72
global GDHO_POLL_BUSY := false
global GDHO_CURSOR_X := 0
global GDHO_CURSOR_Y := 0
global GDHO_SUPPRESS_UNTIL_RELEASE := false
global GDHO_TOOLBAR_NEAR_RADIUS_PX := 260
global GDHO_TOOLBAR_DISMISS_RADIUS_PX := 320
global GDHO_POSITION_MODE := "anchor" ; anchor|fixed|relative
global GDHO_FIXED_X := 360
global GDHO_FIXED_Y := 260
global GDHO_SIZE_SCALE := 1.0
global GDHO_ANIM_LEVEL := 1.0
global GDHO_HOST_W := 360
global GDHO_HOST_H := 320
global GDHO_LAST_HOST_X := 120
global GDHO_LAST_HOST_Y := 120

GDHO_ScreenVirtual_GetBounds(&outL, &outT, &outW, &outH) {
    outL := SysGet(76)
    outT := SysGet(77)
    outW := SysGet(78)
    outH := SysGet(79)
}

GDHO_SetPageUrl(url) {
    global GDHO_PAGE_URL
    u := Trim(String(url))
    if (u != "")
        GDHO_PAGE_URL := u
}

GDHO_SetFallbackUrl(url) {
    global GDHO_FALLBACK_URL
    u := Trim(String(url))
    if (u != "")
        GDHO_FALLBACK_URL := u
}

GDHO_SetAnchorMode(mode := "toolbar_center") {
    global GDHO_ANCHOR_MODE
    m := Trim(String(mode))
    if (m = "")
        return
    if (m != "toolbar_auto_vertical" && m != "toolbar_center" && m != "toolbar_left" && m != "toolbar_right" && m != "toolbar_above" && m != "toolbar_below" && m != "screen")
        return
    GDHO_ANCHOR_MODE := m
}

GDHO_SetAnchorOffset(offsetX := 0, offsetY := 0) {
    global GDHO_ANCHOR_OFFSET_X, GDHO_ANCHOR_OFFSET_Y
    GDHO_ANCHOR_OFFSET_X := Integer(offsetX)
    GDHO_ANCHOR_OFFSET_Y := Integer(offsetY)
}

GDHO_SetScreenAnchor(screenX := 120, screenY := 120) {
    global GDHO_SCREEN_X, GDHO_SCREEN_Y
    GDHO_SCREEN_X := Integer(screenX)
    GDHO_SCREEN_Y := Integer(screenY)
}

GDHO_ApplySettings(positionMode := "anchor", triggerDistance := 260, dismissDistance := 320, fixedX := 360, fixedY := 260, sizeScale := 1.0, animLevel := 1.0) {
    global GDHO_POSITION_MODE, GDHO_TOOLBAR_NEAR_RADIUS_PX, GDHO_TOOLBAR_DISMISS_RADIUS_PX, GDHO_FIXED_X, GDHO_FIXED_Y, GDHO_SIZE_SCALE, GDHO_ANIM_LEVEL
    m := Trim(String(positionMode))
    if (m != "anchor" && m != "fixed" && m != "relative")
        m := "anchor"
    GDHO_POSITION_MODE := m
    td := Integer(triggerDistance)
    dd := Integer(dismissDistance)
    if (td < 80)
        td := 80
    if (td > 1200)
        td := 1200
    if (dd < td + 20)
        dd := td + 20
    if (dd > 1600)
        dd := 1600
    GDHO_TOOLBAR_NEAR_RADIUS_PX := td
    GDHO_TOOLBAR_DISMISS_RADIUS_PX := dd
    GDHO_FIXED_X := Integer(fixedX)
    GDHO_FIXED_Y := Integer(fixedY)
    ss := Float(sizeScale)
    if (ss < 0.6)
        ss := 0.6
    if (ss > 1.8)
        ss := 1.8
    GDHO_SIZE_SCALE := ss
    al := Float(animLevel)
    if (al < 0.4)
        al := 0.4
    if (al > 2.2)
        al := 2.2
    GDHO_ANIM_LEVEL := al
}

GDHO_Init() {
    global GDHO_GUI, GDHO_WV2_CTRL, GDHO_WV2, GDHO_READY
    global GDHO_VISIBLE

    if (GDHO_GUI)
        return

    GDHO_CreateOverlayGui()
    GDHO_WV2_CTRL := 0
    GDHO_WV2 := 0
    GDHO_READY := false
    GDHO_PREWARM_DONE := false
    GDHO_FIRST_REVEAL_DONE := false
    GDHO_VISIBLE := false
    try WebView2.create(GDHO_GUI.Hwnd, GDHO_OnWebViewCreated, WebView2_EnsureSharedEnvBlocking())
}

GDHO_CreateOverlayGui() {
    global GDHO_GUI
    GDHO_ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    hostW := Integer(GDHO_HOST_W), hostH := Integer(GDHO_HOST_H)
    if (hostW < 260)
        hostW := 260
    if (hostH < 220)
        hostH := 220
    x := Integer(vl + 24), y := Integer(vt + 24)
    ; WS_EX_LAYERED + WS_EX_TRANSPARENT + WS_EX_NOACTIVATE
    GDHO_GUI := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08080020", "Global Drag Hole Overlay")
    ; Use dedicated chroma key to keep host transparent before first WebView paint.
    GDHO_GUI.BackColor := "010101"
    ; Click-through + no activate overlay host.
    GDHO_GUI.Show("Hide x" x " y" y " w" hostW " h" hostH " NoActivate")
    ; Keep window normal opacity; transparency comes from chroma-key immediately.
    try WinSetTransparent(255, "ahk_id " GDHO_GUI.Hwnd)
    try WinSetTransColor("010101", "ahk_id " GDHO_GUI.Hwnd)
}

GDHO_SetClickThrough(enable := true) {
    global GDHO_GUI, GDHO_CLICKTHROUGH
    if !GDHO_GUI
        return
    ex := DllCall("GetWindowLongPtr", "Ptr", GDHO_GUI.Hwnd, "Int", -20, "Ptr")
    if (enable) {
        ex := ex | 0x20 ; WS_EX_TRANSPARENT
        GDHO_CLICKTHROUGH := true
    } else {
        ex := ex & ~0x20
        GDHO_CLICKTHROUGH := false
    }
    DllCall("SetWindowLongPtr", "Ptr", GDHO_GUI.Hwnd, "Int", -20, "Ptr", ex, "Ptr")
}

GDHO_OnWebViewCreated(ctrl) {
    global GDHO_WV2_CTRL, GDHO_WV2, GDHO_READY, GDHO_PAGE_URL, GDHO_NAV_FAIL_COUNT

    if !IsObject(ctrl) || !ctrl.HasProp("CoreWebView2")
        return

    GDHO_WV2_CTRL := ctrl
    GDHO_WV2 := ctrl.CoreWebView2
    GDHO_READY := false
    GDHO_NAV_FAIL_COUNT := 0

    try ctrl.IsVisible := true
    try ctrl.DefaultBackgroundColor := 0x00000000
    GDHO_ResizeToVirtualScreen()
    try {
        s := GDHO_WV2.Settings
        s.AreDefaultContextMenusEnabled := false
        s.AreDevToolsEnabled := false
        s.AreBrowserAcceleratorKeysEnabled := false
    }
    try ApplyWebView2PerformanceSettings(GDHO_WV2)
    try GDHO_ApplyHostMapping()
    try WebView2_RegisterHostBridge(GDHO_WV2)
    try GDHO_WV2.add_WebMessageReceived(GDHO_OnWebMessage)
    try GDHO_WV2.add_NavigationCompleted(GDHO_OnNavigationCompleted)
    try GDHO_WV2.Navigate(GDHO_PAGE_URL)
}

GDHO_ApplyHostMapping() {
    global GDHO_WV2
    if !GDHO_WV2
        return
    ; Ensure https://app.local/* resolves for static fallback pages.
    try {
        ; 0 = COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY_CORS? (depends wrapper)
        ; Keep compatibility with existing helper when available.
        if IsSet(ApplyUnifiedWebViewAssets) {
            ApplyUnifiedWebViewAssets(GDHO_WV2)
            return
        }
    } catch {
    }
    try GDHO_WV2.SetVirtualHostNameToFolderMapping("app.local", A_ScriptDir, 0)
}

GDHO_OnWebMessage(sender, args) {
    msgJson := ""
    try msgJson := args.WebMessageAsJson
    if (msgJson = "")
        return
    msg := 0
    try msg := Jxon_Load(msgJson)
    if !(msg is Map)
        return
    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ != "hole_drop")
        return
    if !msg.Has("payload") || !(msg["payload"] is Map)
        return
    GDHO_HandleDropPayload(msg["payload"])
}

GDHO_HandleDropPayload(payload) {
    kind := payload.Has("kind") ? String(payload["kind"]) : "none"
    if (kind = "text") {
        txt := payload.Has("text") ? Trim(String(payload["text"])) : ""
        if (txt != "")
            try FloatingToolbar_RequestSearchByKeyword(txt)
        return
    }

    ; Foundation for next phase (image/file/folder upload route).
    ; Keep structured payload now, wire business uploader later.
    try OutputDebug("[GDHO] hole_drop kind=" . kind)
}

GDHO_OnNavigationCompleted(sender, args) {
    global GDHO_READY, GDHO_GUI, GDHO_WV2_CTRL, GDHO_WV2
    global GDHO_FALLBACK_URL, GDHO_NAV_FAIL_COUNT, GDHO_DESKTOP_PINNED, GDHO_PIN_PAYLOAD, GDHO_PREWARM_DONE
    ok := false
    try ok := args.IsSuccess
    GDHO_READY := !!ok
    if GDHO_READY {
        GDHO_NAV_FAIL_COUNT := 0
        ; Re-apply transparency after document init to avoid occasional white/black flash.
        try GDHO_WV2_CTRL.DefaultBackgroundColor := 0x00000000
        try WinSetTransColor("010101", "ahk_id " GDHO_GUI.Hwnd)
        if !GDHO_PREWARM_DONE {
            GDHO_PREWARM_DONE := true
            ; Warm-up strategy: render one full state offscreen, then hide.
            SetTimer(GDHO_PrewarmOffscreen, -40)
        }
        if GDHO_DESKTOP_PINNED {
            p := (GDHO_PIN_PAYLOAD = "file") ? "file" : "text"
            SetTimer((*) => GDHO_RunJS("window.HoleOverlay?.show('" p "')"), -60)
            SetTimer((*) => GDHO_RunJS("window.HoleOverlay?.show('" p "')"), -220)
        }
        return
    }

    GDHO_NAV_FAIL_COUNT += 1
    if (GDHO_FALLBACK_URL != "" && GDHO_NAV_FAIL_COUNT <= 2) {
        try GDHO_WV2.Navigate(GDHO_FALLBACK_URL)
    }
}

GDHO_ResizeToVirtualScreen() {
    global GDHO_GUI, GDHO_WV2_CTRL, GDHO_HOST_W, GDHO_HOST_H
    if !(GDHO_GUI && GDHO_WV2_CTRL)
        return
    try GDHO_GUI.GetPos(&gx, &gy)
    hostW := Integer(GDHO_HOST_W), hostH := Integer(GDHO_HOST_H)
    try GDHO_GUI.Move(gx, gy, hostW, hostH)
    rc := WebView2.RECT()
    rc.left := 0, rc.top := 0, rc.right := hostW, rc.bottom := hostH
    try GDHO_WV2_CTRL.Bounds := rc
}

GDHO_PrewarmOffscreen(*) {
    ; Keep host window hidden; just force one render pass to prebuild GPU textures.
    GDHO_RunJS("(function(){var h=window.HoleOverlay;if(!h)return;h.show('text');h.update({payload:'text',x:120,y:120,proximity:0.36});setTimeout(function(){try{h.hide();}catch(_e){}},90);})();")
}

GDHO_RunJS(js) {
    global GDHO_WV2, GDHO_READY
    if !(GDHO_WV2 && GDHO_READY)
        return false
    try {
        GDHO_WV2.ExecuteScript(js)
        return true
    } catch {
        return false
    }
}

GDHO_ShowOverlay() {
    global GDHO_GUI, GDHO_VISIBLE, GDHO_WV2, GDHO_READY, GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y, GDHO_HOST_W, GDHO_HOST_H, GDHO_FIRST_REVEAL_DONE
    if !GDHO_GUI
        return
    ; Avoid first-frame black flash: don't reveal host before WebView content is ready.
    if !GDHO_READY
        return
    if !GDHO_FIRST_REVEAL_DONE {
        GDHO_FIRST_REVEAL_DONE := true
        SetTimer(GDHO_ShowOverlay, -16)
        return
    }
    if !GDHO_VISIBLE {
        try GDHO_GUI.Show("x" Integer(GDHO_LAST_HOST_X) " y" Integer(GDHO_LAST_HOST_Y) " w" Integer(GDHO_HOST_W) " h" Integer(GDHO_HOST_H) " NoActivate")
        try WinSetTransColor("010101", "ahk_id " GDHO_GUI.Hwnd)
        GDHO_SetClickThrough(true)
        GDHO_KeepBelowToolbar()
        GDHO_VISIBLE := true
        try WebView2_NotifyShown(GDHO_WV2)
    }
}

GDHO_KeepBelowToolbar() {
    global GDHO_GUI, FloatingToolbarGUI, FloatingToolbarIsVisible
    global FloatingBubbleGUI, FloatingBubbleIsVisible
    if !GDHO_GUI
        return
    anchorGui := 0
    try {
        if (IsSet(FloatingToolbarGUI) && IsObject(FloatingToolbarGUI) && (FloatingToolbarGUI is Gui)
            && (!IsSet(FloatingToolbarIsVisible) || FloatingToolbarIsVisible))
            anchorGui := FloatingToolbarGUI
    } catch {
    }
    if !anchorGui {
        try {
            if (IsSet(FloatingBubbleGUI) && IsObject(FloatingBubbleGUI) && (FloatingBubbleGUI is Gui)
                && IsSet(FloatingBubbleIsVisible) && FloatingBubbleIsVisible)
                anchorGui := FloatingBubbleGUI
        } catch {
        }
    }
    if !anchorGui
        return
    try {
        ; Keep hole overlay directly below current anchor (toolbar or bubble) in topmost z-order.
        DllCall("SetWindowPos"
            , "Ptr", GDHO_GUI.Hwnd
            , "Ptr", anchorGui.Hwnd
            , "Int", 0, "Int", 0, "Int", 0, "Int", 0
            , "UInt", 0x0001 | 0x0002 | 0x0010) ; NOSIZE|NOMOVE|NOACTIVATE
    }
}

GDHO_AnchorHoleUnderToolbar() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible
    global FloatingBubbleGUI, FloatingBubbleIsVisible
    global GDHO_ANCHOR_W, GDHO_ANCHOR_H, GDHO_ANCHOR_GAP
    global GDHO_ANCHOR_MODE, GDHO_ANCHOR_OFFSET_X, GDHO_ANCHOR_OFFSET_Y, GDHO_SCREEN_X, GDHO_SCREEN_Y
    global GDHO_CURSOR_X, GDHO_CURSOR_Y
    anchorGui := 0
    try {
        if (IsSet(FloatingToolbarGUI) && IsObject(FloatingToolbarGUI) && (FloatingToolbarGUI is Gui)
            && (!IsSet(FloatingToolbarIsVisible) || FloatingToolbarIsVisible))
            anchorGui := FloatingToolbarGUI
    } catch {
    }
    if !anchorGui {
        try {
            if (IsSet(FloatingBubbleGUI) && IsObject(FloatingBubbleGUI) && (FloatingBubbleGUI is Gui)
                && IsSet(FloatingBubbleIsVisible) && FloatingBubbleIsVisible)
                anchorGui := FloatingBubbleGUI
        } catch {
        }
    }
    if !anchorGui
        return GDHO_AnchorHoleByScreen()
    try anchorGui.GetPos(&tx, &ty, &tw, &th)
    catch
        return GDHO_AnchorHoleByScreen()

    GDHO_ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    holeW := Integer(GDHO_ANCHOR_W), holeH := Integer(GDHO_ANCHOR_H), gap := Integer(GDHO_ANCHOR_GAP)
    mode := GDHO_ANCHOR_MODE
    if (mode = "screen")
        return GDHO_AnchorHoleByScreen()

    if (mode = "toolbar_left")
        x := Integer(tx + 8 - vl)
    else if (mode = "toolbar_right")
        x := Integer(tx + tw - holeW - 8 - vl)
    else
        x := Integer(tx + (tw / 2) - (holeW / 2) - vl)

    if (mode = "toolbar_auto_vertical") {
        ; Stable placement: prefer above toolbar; if not enough space, place below.
        yAbove := Integer(ty - holeH - gap - vt)
        yBelow := Integer(ty + th + gap - vt)
        if (yAbove >= 12)
            y := yAbove
        else
            y := yBelow
    } else if (mode = "toolbar_above") {
        y := Integer(ty - holeH - gap - vt)
    } else {
        y := Integer(ty + th + gap - vt)
    }
    x += Integer(GDHO_ANCHOR_OFFSET_X)
    y += Integer(GDHO_ANCHOR_OFFSET_Y)
    if (x < 12)
        x := 12
    if (y < 12)
        y := 12
    maxX := vw - holeW - 12
    maxY := vh - holeH - 12
    if (x > maxX)
        x := maxX
    if (y > maxY)
        y := maxY
    GDHO_MoveHostToHole(x, y)
    return GDHO_RunJS("window.HoleOverlay?.moveTo({ x: 90, y: 56 })")
}

GDHO_AnchorHoleByScreen() {
    global GDHO_ANCHOR_W, GDHO_ANCHOR_H, GDHO_SCREEN_X, GDHO_SCREEN_Y
    global GDHO_ANCHOR_OFFSET_X, GDHO_ANCHOR_OFFSET_Y
    GDHO_ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    holeW := Integer(GDHO_ANCHOR_W), holeH := Integer(GDHO_ANCHOR_H)
    x := Integer(GDHO_SCREEN_X + GDHO_ANCHOR_OFFSET_X)
    y := Integer(GDHO_SCREEN_Y + GDHO_ANCHOR_OFFSET_Y)
    if (x < 12)
        x := 12
    if (y < 12)
        y := 12
    maxX := vw - holeW - 12
    maxY := vh - holeH - 12
    if (x > maxX)
        x := maxX
    if (y > maxY)
        y := maxY
    GDHO_MoveHostToHole(x, y)
    return GDHO_RunJS("window.HoleOverlay?.moveTo({ x: 90, y: 56 })")
}

GDHO_MoveHostToHole(holeX, holeY) {
    global GDHO_GUI, GDHO_HOST_W, GDHO_HOST_H, GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y
    if !GDHO_GUI
        return
    GDHO_ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    hostW := Integer(GDHO_HOST_W), hostH := Integer(GDHO_HOST_H)
    hx := Integer(vl + holeX - 90)
    hy := Integer(vt + holeY - 56)
    if (hx < vl + 2)
        hx := vl + 2
    if (hy < vt + 2)
        hy := vt + 2
    maxX := vl + vw - hostW - 2
    maxY := vt + vh - hostH - 2
    if (hx > maxX)
        hx := maxX
    if (hy > maxY)
        hy := maxY
    GDHO_LAST_HOST_X := hx
    GDHO_LAST_HOST_Y := hy
    try GDHO_GUI.Move(hx, hy, hostW, hostH)
}

GDHO_GlobalPointToHostLocal(globalX, globalY, &localX, &localY) {
    global GDHO_GUI
    localX := Integer(globalX)
    localY := Integer(globalY)
    if !GDHO_GUI
        return
    try GDHO_GUI.GetPos(&gx, &gy)
    catch
        return
    localX := Integer(globalX - gx)
    localY := Integer(globalY - gy)
}

GDHO_HideOverlay() {
    global GDHO_GUI, GDHO_VISIBLE, GDHO_WV2
    if !GDHO_GUI
        return
    try WebView2_NotifyHidden(GDHO_WV2)
    GDHO_SetClickThrough(true)
    try GDHO_GUI.Hide()
    GDHO_VISIBLE := false
}

GDHO_Show(payload := "file") {
    global GDHO_CURSOR_X, GDHO_CURSOR_Y, GDHO_POSITION_MODE
    p := (payload = "text") ? "text" : "file"
    try {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        GDHO_CURSOR_X := mx
        GDHO_CURSOR_Y := my
    }
    GDHO_ShowOverlay()
    if (GDHO_POSITION_MODE = "fixed")
        GDHO_AnchorHoleByScreen()
    else if (GDHO_POSITION_MODE = "relative") {
        GDHO_MoveHostToHole(Integer(GDHO_CURSOR_X - 90), Integer(GDHO_CURSOR_Y - 110))
        GDHO_RunJS("window.HoleOverlay?.moveTo({ x: 90, y: 56 })")
    }
    else
        GDHO_AnchorHoleUnderToolbar()
    GDHO_RunJS("window.HoleOverlay?.show('" p "')")
    GDHO_RunJS("window.HoleOverlay?.setStyle({ scale: " GDHO_SIZE_SCALE ", animLevel: " GDHO_ANIM_LEVEL " })")
}

GDHO_Update(payload := "file", x := "", y := "") {
    global GDHO_LAST_UPDATE_TICK, GDHO_UPDATE_MIN_INTERVAL_MS, GDHO_CURSOR_X, GDHO_CURSOR_Y, GDHO_POSITION_MODE
    nowTick := A_TickCount
    if (GDHO_LAST_UPDATE_TICK && (nowTick - GDHO_LAST_UPDATE_TICK < GDHO_UPDATE_MIN_INTERVAL_MS))
        return
    p := (payload = "text") ? "text" : "file"
    if (x != "" && y != "") {
        GDHO_CURSOR_X := Integer(x)
        GDHO_CURSOR_Y := Integer(y)
    }
    if (GDHO_POSITION_MODE = "fixed")
        GDHO_AnchorHoleByScreen()
    else if (GDHO_POSITION_MODE = "relative" && x != "" && y != "") {
        GDHO_MoveHostToHole(Integer(x - 90), Integer(y - 110))
        GDHO_RunJS("window.HoleOverlay?.moveTo({ x: 90, y: 56 })")
    }
    else
        GDHO_AnchorHoleUnderToolbar()
    if (x = "" || y = "") {
        GDHO_RunJS("window.HoleOverlay?.update({ payload: '" p "' })")
    } else {
        GDHO_GlobalPointToHostLocal(Integer(x), Integer(y), &lx, &ly)
        GDHO_RunJS("window.HoleOverlay?.update({ payload: '" p "', x: " Integer(lx) ", y: " Integer(ly) " })")
    }
    GDHO_LAST_UPDATE_TICK := nowTick
}

GDHO_Drop(payload := "file") {
    p := (payload = "text") ? "text" : "file"
    GDHO_RunJS("window.HoleOverlay?.drop({ payload: '" p "' })")
}

GDHO_HideFrontend() {
    global GDHO_DESKTOP_PINNED, GDHO_PIN_PAYLOAD
    if GDHO_DESKTOP_PINNED {
        p := (GDHO_PIN_PAYLOAD = "file") ? "file" : "text"
        GDHO_RunJS("window.HoleOverlay?.show('" p "')")
        return
    }
    GDHO_RunJS("window.HoleOverlay?.hide()")
}

GDHO_Start() {
    global GDHO_MONITORING
    GDHO_Init()
    if GDHO_MONITORING
        return
    GDHO_MONITORING := true
    SetTimer(GDHO_PollDrag, GDHO_POLL_MS)
}

GDHO_Stop() {
    global GDHO_MONITORING, GDHO_ACTIVE
    GDHO_MONITORING := false
    GDHO_ACTIVE := false
    SetTimer(GDHO_PollDrag, 0)
    GDHO_HideFrontend()
    GDHO_HideOverlay()
}

GDHO_IsDragSessionActive() {
    global GDHO_ACTIVE, GDHO_START_X, GDHO_START_Y
    if GDHO_ACTIVE
        return true
    if (GDHO_START_X != 0 || GDHO_START_Y != 0)
        return GetKeyState("LButton", "P")
    return false
}

GDHO_DistanceToToolbar(mx, my) {
    global FloatingToolbarGUI, FloatingToolbarIsVisible
    if !IsSet(FloatingToolbarGUI)
        return 999999
    if !IsObject(FloatingToolbarGUI) || !(FloatingToolbarGUI is Gui)
        return 999999
    if (IsSet(FloatingToolbarIsVisible) && !FloatingToolbarIsVisible)
        return 999999
    try FloatingToolbarGUI.GetPos(&tx, &ty, &tw, &th)
    catch
        return 999999
    left := tx, top := ty, right := tx + tw, bottom := ty + th
    dx := 0, dy := 0
    if (mx < left)
        dx := left - mx
    else if (mx > right)
        dx := mx - right
    if (my < top)
        dy := top - my
    else if (my > bottom)
        dy := my - bottom
    return Sqrt(dx * dx + dy * dy)
}

GDHO_PinToDesktop(payload := "text") {
    global GDHO_DESKTOP_PINNED, GDHO_PIN_PAYLOAD, GDHO_ACTIVE
    p := (payload = "file") ? "file" : "text"
    GDHO_PIN_PAYLOAD := p
    GDHO_DESKTOP_PINNED := true
    GDHO_ACTIVE := false
    GDHO_Init()
    GDHO_ShowOverlay()
    if !GDHO_RunJS("window.HoleOverlay?.show('" p "')") {
        SetTimer((*) => GDHO_RunJS("window.HoleOverlay?.show('" p "')"), -180)
        SetTimer((*) => GDHO_RunJS("window.HoleOverlay?.show('" p "')"), -420)
    }
}

GDHO_UnpinFromDesktop() {
    global GDHO_DESKTOP_PINNED
    GDHO_DESKTOP_PINNED := false
    GDHO_HideFrontend()
    GDHO_HideOverlay()
}

; ===== Global drag pre-judge =====
; Strategy:
; 1) Detect left-button hold + movement threshold.
; 2) Use cursor-shape change OR explorer-like source class to reduce false positives.
; 3) If likely dragging payload, show/update overlay globally.
GDHO_PollDrag(*) {
    global GDHO_ACTIVE, GDHO_START_X, GDHO_START_Y, GDHO_LAST_X, GDHO_LAST_Y
    global GDHO_START_CURSOR, GDHO_DRAG_SOURCE_CLASS, GDHO_PAYLOAD
    global GDHO_MIN_MOVE_PX, GDHO_LAST_UPDATE_TICK, GDHO_MAX_IDLE_HIDE_MS
    global GDHO_POLL_BUSY, GDHO_SUPPRESS_UNTIL_RELEASE, GDHO_TOOLBAR_NEAR_RADIUS_PX, GDHO_TOOLBAR_DISMISS_RADIUS_PX
    if GDHO_POLL_BUSY
        return
    GDHO_POLL_BUSY := true

    try {
        lDown := GetKeyState("LButton", "P")
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my, &hwnd)
        isOwn := GDHO_IsOwnWindowHwnd(hwnd)

        if !lDown {
            ; Defensive: if toolbar drag state got stuck, force-close it on mouse-up.
            try FloatingToolbar_EndDrag()
            GDHO_SUPPRESS_UNTIL_RELEASE := false
            if GDHO_ACTIVE {
                GDHO_Drop(GDHO_PAYLOAD)
                GDHO_ACTIVE := false
                SetTimer((*) => GDHO_HideOverlay(), -700)
            } else if (A_TickCount - GDHO_LAST_UPDATE_TICK > GDHO_MAX_IDLE_HIDE_MS) {
                GDHO_HideFrontend()
                GDHO_HideOverlay()
            }
            GDHO_ResetPointerSeed()
            return
        }

        if GDHO_SUPPRESS_UNTIL_RELEASE {
            GDHO_HideFrontend()
            GDHO_HideOverlay()
            GDHO_ACTIVE := false
            return
        }

        if (GDHO_START_X = 0 && GDHO_START_Y = 0) {
            ; Do not seed drag from our own UI (toolbar/bubble/hole), avoid feedback loops.
            if isOwn
                return
            GDHO_START_X := mx
            GDHO_START_Y := my
            GDHO_LAST_X := mx
            GDHO_LAST_Y := my
            GDHO_START_CURSOR := GDHO_GetCursorHandle()
            GDHO_DRAG_SOURCE_CLASS := GDHO_GetClassByHwnd(hwnd)
            GDHO_PAYLOAD := GDHO_GuessPayloadType(GDHO_DRAG_SOURCE_CLASS)
            return
        }

        dx := mx - GDHO_START_X
        dy := my - GDHO_START_Y
        moved := (dx * dx + dy * dy) >= (GDHO_MIN_MOVE_PX * GDHO_MIN_MOVE_PX)
        if !moved
            return

        likelyDrag := GDHO_IsLikelyDrag(GDHO_DRAG_SOURCE_CLASS, GDHO_START_CURSOR)
        if !likelyDrag
            return

        distToTb := GDHO_DistanceToToolbar(mx, my)
        limit := GDHO_ACTIVE ? GDHO_TOOLBAR_DISMISS_RADIUS_PX : GDHO_TOOLBAR_NEAR_RADIUS_PX
        if (distToTb > limit) {
            GDHO_HideFrontend()
            GDHO_HideOverlay()
            GDHO_ACTIVE := false
            GDHO_SUPPRESS_UNTIL_RELEASE := true
            return
        }

        ; If drag already seeded from external window, keep updating even when cursor passes over toolbar.
        if !GDHO_ACTIVE {
            GDHO_Show(GDHO_PAYLOAD)
            GDHO_ACTIVE := true
        }
        GDHO_Update(GDHO_PAYLOAD, mx, my)
        GDHO_LAST_X := mx
        GDHO_LAST_Y := my
    } finally {
        GDHO_POLL_BUSY := false
    }
}

GDHO_IsOwnWindowHwnd(hwnd) {
    global GDHO_GUI, FloatingToolbarGUI, FloatingBubbleGUI
    if !hwnd
        return false
    rootHwnd := GDHO_GetRootHwnd(hwnd)
    try {
        if (GDHO_GUI && (hwnd = GDHO_GUI.Hwnd || rootHwnd = GDHO_GUI.Hwnd))
            return true
    } catch {
    }
    try {
        if (FloatingToolbarGUI && IsObject(FloatingToolbarGUI)
            && (hwnd = FloatingToolbarGUI.Hwnd || rootHwnd = FloatingToolbarGUI.Hwnd))
            return true
    } catch {
    }
    try {
        if (FloatingBubbleGUI && IsObject(FloatingBubbleGUI)
            && (hwnd = FloatingBubbleGUI.Hwnd || rootHwnd = FloatingBubbleGUI.Hwnd))
            return true
    } catch {
    }
    return false
}

GDHO_GetRootHwnd(hwnd) {
    if !hwnd
        return 0
    ; GA_ROOT = 2
    try return DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    catch
        return hwnd
}

GDHO_ResetPointerSeed(*) {
    global GDHO_START_X, GDHO_START_Y, GDHO_START_CURSOR, GDHO_DRAG_SOURCE_CLASS
    global GDHO_ACTIVE
    if GDHO_ACTIVE
        return
    GDHO_START_X := 0
    GDHO_START_Y := 0
    GDHO_START_CURSOR := 0
    GDHO_DRAG_SOURCE_CLASS := ""
}

GDHO_GetCursorHandle() {
    ci := Buffer(24, 0)
    NumPut("UInt", 24, ci, 0)
    if !DllCall("GetCursorInfo", "Ptr", ci.Ptr)
        return 0
    return NumGet(ci, 8, "Ptr")
}

GDHO_GetClassByHwnd(hwnd) {
    if !hwnd
        return ""
    try return WinGetClass("ahk_id " hwnd)
    catch {
        return ""
    }
}

GDHO_IsLikelyDrag(srcClass, startCursor) {
    cNow := GDHO_GetCursorHandle()
    if (cNow = 0)
        return false

    ; Explorer/Desktop class: high confidence file/folder drag
    if (srcClass = "CabinetWClass" || srcClass = "ExploreWClass" || srcClass = "WorkerW" || srcClass = "Progman")
        return true

    ; generic fallback: cursor changed after movement, usually indicates drag-mode cursor
    if (startCursor != 0 && cNow != startCursor)
        return true

    return false
}

GDHO_GuessPayloadType(srcClass) {
    ; Explorer/Desktop drags are generally file/folder.
    if (srcClass = "CabinetWClass" || srcClass = "ExploreWClass" || srcClass = "WorkerW" || srcClass = "Progman")
        return "file"
    ; Other apps default to text-like drag behavior.
    return "text"
}


