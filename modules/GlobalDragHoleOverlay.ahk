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
global GDHO_PAGE_URL := "http://127.0.0.1:5173/hole_starry.html"
global GDHO_FALLBACK_URL := ""
global GDHO_NAV_FAIL_COUNT := 0
global GDHO_PREWARM_DONE := false
global GDHO_FIRST_REVEAL_DONE := false

; drag pre-judge parameters
global GDHO_MIN_MOVE_PX := 10
global GDHO_POLL_MS := 48
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
global GDHO_VISUAL_STYLE := "ring" ; ring|starry
global GDHO_HOST_W := 620
global GDHO_HOST_H := 620
global GDHO_LAST_HOST_X := 120
global GDHO_LAST_HOST_Y := 120
global GDHO_DRAG_CONFIDENCE := 0.0
global GDHO_JUMP_LERP_THRESHOLD_PX := 50
global GDHO_DIAG_CTRL := 0
global GDHO_DIAG_VISIBLE := false
global GDHO_LAST_APPLIED_ANIM_LEVEL := -1.0
global GDHO_PRIORITY_APPLIED := false
global GDHO_START_ROOT_HWND := 0
global NativeDropSessionActive := false
global GDHO_LAST_DROP_TICK := 0
global GDHO_RELEASE_SETTLE_MS := 100
global GDHO_RELEASE_PENDING := false
global GDHO_RELEASE_DEADLINE_TICK := 0
global GDHO_LAST_CURSOR_NAME := ""
global GDHO_SAW_DRAG_CURSOR := false
global GDHO_DROP_ACK_TICK := 0
global GDHO_STRICT_MODE := true
global GDHO_DRAG_CURSOR_STREAK := 0
global GDHO_LAST_DROPPED_TEXT := ""
global GDHO_SESSION_TEXT := ""
; Hidden-state parking: keep host away from center to reduce accidental obstruction.
global GDHO_HIDE_DOCK_ENABLED := true
global GDHO_HIDE_DOCK_EDGE := "right" ; right|left|top|bottom
global GDHO_HIDE_DOCK_MARGIN := 10

GDHO_ApplyHideDockSettings(enabled := true, edge := "right", margin := 10) {
    global GDHO_HIDE_DOCK_ENABLED, GDHO_HIDE_DOCK_EDGE, GDHO_HIDE_DOCK_MARGIN
    GDHO_HIDE_DOCK_ENABLED := !!enabled
    e := StrLower(Trim(String(edge)))
    if (e != "right" && e != "left" && e != "top" && e != "bottom")
        e := "right"
    GDHO_HIDE_DOCK_EDGE := e
    m := Integer(margin)
    if (m < 0)
        m := 0
    if (m > 80)
        m := 80
    GDHO_HIDE_DOCK_MARGIN := m
}

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

GDHO_ApplySettings(positionMode := "anchor", triggerDistance := 260, dismissDistance := 320, fixedX := 360, fixedY := 260, sizeScale := 1.0, animLevel := 1.0, visualStyle := "ring") {
    global GDHO_POSITION_MODE, GDHO_TOOLBAR_NEAR_RADIUS_PX, GDHO_TOOLBAR_DISMISS_RADIUS_PX, GDHO_FIXED_X, GDHO_FIXED_Y, GDHO_SIZE_SCALE, GDHO_ANIM_LEVEL, GDHO_VISUAL_STYLE
    global GDHO_ACTIVE, GDHO_SUPPRESS_UNTIL_RELEASE
    oldMode := GDHO_POSITION_MODE
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
    vs := StrLower(Trim(String(visualStyle)))
    if (vs != "ring" && vs != "starry")
        vs := "ring"
    GDHO_VISUAL_STYLE := vs
    try GDHO_RunJS("window.HoleOverlay?.setStyle({ scale: " GDHO_SIZE_SCALE ", animLevel: " GDHO_ANIM_LEVEL ", visualStyle: '" GDHO_VISUAL_STYLE "' })")

    ; Mode switch can leave toolbar drag / hole drag state half-open.
    ; Force a clean transition to prevent "toolbar stuck" and stale drag sessions.
    if (oldMode != "" && oldMode != m) {
        try FloatingToolbar_EndDrag()
        GDHO_ACTIVE := false
        GDHO_HideFrontend()
        GDHO_HideOverlay()
        GDHO_ResetPointerSeed()
        ; If user is still holding mouse while switching mode, wait until release.
        GDHO_SUPPRESS_UNTIL_RELEASE := GetKeyState("LButton", "P")
    }
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
    global GDHO_GUI, GDHO_DIAG_CTRL
    GDHO_ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    hostW := Integer(GDHO_HOST_W), hostH := Integer(GDHO_HOST_H)
    if (hostW < 260)
        hostW := 260
    if (hostH < 220)
        hostH := 220
    x := Integer(vl + 24), y := Integer(vt + 24)
    ; WS_EX_LAYERED + WS_EX_NOACTIVATE (do NOT include WS_EX_TRANSPARENT at creation)
    ; Click-through will be toggled explicitly by GDHO_SetClickThrough().
    GDHO_GUI := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08080000", "Global Drag Hole Overlay")
    GDHO_DIAG_CTRL := GDHO_GUI.AddText("Hidden x6 y6 w340 h44 BackgroundTrans c66FF66", "")
    ; Use dedicated chroma key to keep host transparent before first WebView paint.
    GDHO_GUI.BackColor := "010101"
    ; Click-through + no activate overlay host.
    GDHO_GUI.Show("Hide x" x " y" y " w" hostW " h" hostH " NoActivate")
    ; Keep window normal opacity; transparency comes from chroma-key immediately.
    try WinSetTransparent(255, "ahk_id " GDHO_GUI.Hwnd)
    try WinSetTransColor("010101", "ahk_id " GDHO_GUI.Hwnd)
}

GDHO_DIAG_LOG(msg, elapsedMs := "") {
    global GDHO_DIAG_CTRL, GDHO_DIAG_VISIBLE
    if !IsObject(GDHO_DIAG_CTRL)
        return
    ts := FormatTime(, "HH:mm:ss")
    line := "[" ts "] " String(msg)
    if (elapsedMs != "")
        line .= " (" Format("{:.1f}", Float(elapsedMs)) "ms)"
    GDHO_DIAG_CTRL.Value := line
    slow := (elapsedMs != "" && Float(elapsedMs) > 15.0)
    if slow {
        GDHO_DIAG_CTRL.Opt("cFF4D4D")
        GDHO_DIAG_CTRL.Visible := true
        GDHO_DIAG_VISIBLE := true
    } else {
        GDHO_DIAG_CTRL.Opt("c66FF66")
        if !GDHO_DIAG_VISIBLE
            GDHO_DIAG_CTRL.Visible := false
    }
}

GDHO_ApplyAdaptiveAnimLevel() {
    global GDHO_ANIM_LEVEL, GDHO_SIZE_SCALE, GDHO_DRAG_CONFIDENCE, GDHO_LAST_APPLIED_ANIM_LEVEL, GDHO_VISUAL_STYLE
    targetAnim := Float(GDHO_ANIM_LEVEL)
    if (GDHO_DRAG_CONFIDENCE < 0.5)
        targetAnim := Max(0.4, targetAnim * 0.62)
    if (GDHO_LAST_APPLIED_ANIM_LEVEL >= 0 && Abs(targetAnim - GDHO_LAST_APPLIED_ANIM_LEVEL) < 0.01)
        return
    GDHO_RunJS("window.HoleOverlay?.setStyle({ scale: " GDHO_SIZE_SCALE ", animLevel: " targetAnim ", visualStyle: '" GDHO_VISUAL_STYLE "' })")
    GDHO_LAST_APPLIED_ANIM_LEVEL := targetAnim
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

    try NativeDropDiag_Log("gdho webview_created begin")
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
    global GDHO_DROP_ACK_TICK
    msg := 0
    ; 1) Preferred path: postMessage(string) payload.
    try {
        raw := args.TryGetWebMessageAsString()
        if (raw != "") {
            try {
                m := Jxon_Load(raw)
                if (m is Map)
                    msg := m
            } catch {
            }
        }
    } catch {
    }
    ; 2) Fallback path: WebMessageAsJson (object or quoted string).
    if !(msg is Map) {
        try {
            jsonStr := args.WebMessageAsJson
            if (jsonStr != "") {
                m := Jxon_Load(jsonStr)
                if (m is String)
                    m := Jxon_Load(m)
                if (m is Map)
                    msg := m
            }
        } catch {
        }
    }
    if !(msg is Map)
        return
    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ = "hole_drop_ack") {
        GDHO_DROP_ACK_TICK := A_TickCount
        try GDHO_RunJS("window.HoleOverlay?.setNativeState({ dispatch: 'ack:first_frame' })")
        return
    }
    if (typ != "hole_drop")
        return
    if !msg.Has("payload") || !(msg["payload"] is Map)
        return
    GDHO_HandleDropPayload(msg["payload"])
}

GDHO_HandleDropPayload(payload) {
    global GDHO_LAST_DROPPED_TEXT, GDHO_SESSION_TEXT
    kind := payload.Has("kind") ? String(payload["kind"]) : "none"
    if (kind = "text") {
        txt := payload.Has("text") ? Trim(String(payload["text"])) : ""
        if (txt != "") {
            GDHO_LAST_DROPPED_TEXT := txt
            GDHO_SESSION_TEXT := txt
            ; Always open SearchCenter first, then inject keyword query.
            try FloatingToolbar_ActivateSearchCenter()
            try SetTimer(FloatingToolbar_ActivateSearchCenter, -80)
            try SetTimer(FloatingToolbar_RequestSearchByKeyword.Bind(txt), -120)
            try SetTimer(FloatingToolbar_RequestSearchByKeyword.Bind(txt), -320)
        }
        return
    }

    if (kind = "file" || kind = "folder" || kind = "mixed") {
        items := []
        files := []
        if (payload.Has("files") && (payload["files"] is Array)) {
            for _, item in payload["files"] {
                fp := ""
                if (item is Map) {
                    items.Push(item)
                    fp := item.Has("path") ? Trim(String(item["path"])) : ""
                    if (fp = "")
                        fp := item.Has("name") ? Trim(String(item["name"])) : ""
                } else
                    fp := Trim(String(item))
                if (fp != "")
                    files.Push(fp)
            }
        }
        if (items.Length > 0) {
            try {
                if FloatingToolbar_HandleDroppedPayloadItems(items)
                    return
            } catch {
            }
        }
        if (files.Length > 0) {
            try FloatingToolbar_HandleDroppedFiles(files)
            return
        }
    }
    try OutputDebug("[GDHO] hole_drop ignored kind=" . kind)
}

GDHO_OnNavigationCompleted(sender, args) {
    global GDHO_READY, GDHO_GUI, GDHO_WV2_CTRL, GDHO_WV2
    global GDHO_FALLBACK_URL, GDHO_NAV_FAIL_COUNT, GDHO_DESKTOP_PINNED, GDHO_PIN_PAYLOAD, GDHO_PREWARM_DONE
    ok := false
    try ok := args.IsSuccess
    GDHO_READY := !!ok
    try NativeDropDiag_Log("gdho navigation_completed ok=" . (GDHO_READY ? "1" : "0"))
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
        ; Receive actual drop events while hole is visible.
        GDHO_SetClickThrough(false)
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
    GDHO_ApplyDropHitTestByProximity(0.0)
    try GDHO_DockHostWhenHidden()
    try GDHO_GUI.Hide()
    GDHO_VISIBLE := false
}

GDHO_DockHostWhenHidden() {
    global GDHO_GUI, GDHO_HIDE_DOCK_ENABLED, GDHO_HIDE_DOCK_EDGE, GDHO_HIDE_DOCK_MARGIN
    global GDHO_HOST_W, GDHO_HOST_H, GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y
    if !GDHO_HIDE_DOCK_ENABLED || !GDHO_GUI
        return

    GDHO_ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    hostW := Integer(GDHO_HOST_W), hostH := Integer(GDHO_HOST_H)
    m := Integer(GDHO_HIDE_DOCK_MARGIN)
    if (m < 0)
        m := 0

    x := Integer(vl + vw - hostW - m)
    y := Integer(vt + (vh - hostH) / 2)
    edge := StrLower(Trim(String(GDHO_HIDE_DOCK_EDGE)))
    if (edge = "left")
        x := Integer(vl + m)
    else if (edge = "top") {
        x := Integer(vl + (vw - hostW) / 2)
        y := Integer(vt + m)
    } else if (edge = "bottom") {
        x := Integer(vl + (vw - hostW) / 2)
        y := Integer(vt + vh - hostH - m)
    }

    minX := vl + 2
    minY := vt + 2
    maxX := vl + vw - hostW - 2
    maxY := vt + vh - hostH - 2
    if (x < minX)
        x := minX
    if (y < minY)
        y := minY
    if (x > maxX)
        x := maxX
    if (y > maxY)
        y := maxY

    GDHO_LAST_HOST_X := x
    GDHO_LAST_HOST_Y := y
    try GDHO_GUI.Move(x, y, hostW, hostH)
}

GDHO_PushThemeToWeb() {
    global GDHO_VISUAL_STYLE
    tm := "dark"
    try {
        if IsSet(ThemeMode) {
            m := StrLower(Trim(String(ThemeMode)))
            if (m = "light")
                tm := "light"
        }
    } catch {
    }
    GDHO_RunJS("window.HoleOverlay?.setTheme({ themeMode: '" tm "', visualStyle: '" GDHO_VISUAL_STYLE "' })")
}

GDHO_Show(payload := "file", x := "", y := "") {
    global GDHO_CURSOR_X, GDHO_CURSOR_Y, GDHO_POSITION_MODE
    p := (payload = "text") ? "text" : "file"
    if (x != "" && y != "") {
        GDHO_CURSOR_X := Integer(x)
        GDHO_CURSOR_Y := Integer(y)
    } else {
        try {
            CoordMode("Mouse", "Screen")
            MouseGetPos(&mx, &my)
            GDHO_CURSOR_X := mx
            GDHO_CURSOR_Y := my
        }
    }
    GDHO_ShowOverlay()
    GDHO_SetClickThrough(false)
    GDHO_PushThemeToWeb()
    if (GDHO_POSITION_MODE = "fixed")
        GDHO_AnchorHoleByScreen()
    else if (GDHO_POSITION_MODE = "relative") {
        GDHO_MoveHostToHole(Integer(GDHO_CURSOR_X - 90), Integer(GDHO_CURSOR_Y - 110))
        GDHO_RunJS("window.HoleOverlay?.moveTo({ x: 90, y: 56 })")
    }
    else
        GDHO_AnchorHoleUnderToolbar()
    GDHO_RunJS("window.HoleOverlay?.show('" p "')")
    GDHO_RunJS("window.HoleOverlay?.setStyle({ scale: " GDHO_SIZE_SCALE ", animLevel: " GDHO_ANIM_LEVEL ", visualStyle: '" GDHO_VISUAL_STYLE "' })")
}

GDHO_Update(payload := "file", x := "", y := "") {
    global GDHO_LAST_UPDATE_TICK, GDHO_UPDATE_MIN_INTERVAL_MS, GDHO_CURSOR_X, GDHO_CURSOR_Y, GDHO_POSITION_MODE
    global GDHO_LAST_X, GDHO_LAST_Y, GDHO_JUMP_LERP_THRESHOLD_PX
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
        ; Relative mode: lock hole at activation position for current drag session.
        ; Do not follow cursor during update; only feed pointer for proximity.
    }
    else
        GDHO_AnchorHoleUnderToolbar()
    GDHO_ApplyAdaptiveAnimLevel()
    prox := 0.45
    if (x = "" || y = "") {
        GDHO_RunJS("window.HoleOverlay?.update({ payload: '" p "' })")
    } else {
        ; If pointer jump is too large, inject one lerp frame to smooth frontend animation.
        if (GDHO_LAST_X != 0 || GDHO_LAST_Y != 0) {
            dxj := Integer(x) - Integer(GDHO_LAST_X)
            dyj := Integer(y) - Integer(GDHO_LAST_Y)
            jumpDist := Sqrt(dxj * dxj + dyj * dyj)
            if (jumpDist > GDHO_JUMP_LERP_THRESHOLD_PX) {
                midX := Integer((Integer(GDHO_LAST_X) + Integer(x)) / 2)
                midY := Integer((Integer(GDHO_LAST_Y) + Integer(y)) / 2)
                GDHO_GlobalPointToHostLocal(midX, midY, &mlx, &mly)
                GDHO_RunJS("window.HoleOverlay?.update({ payload: '" p "', x: " Integer(mlx) ", y: " Integer(mly) " })")
            }
        }
        GDHO_GlobalPointToHostLocal(Integer(x), Integer(y), &lx, &ly)
        cx := 90
        cy := 56 + (206 / 2)
        dxp := lx - cx
        dyp := ly - cy
        dist := Sqrt(dxp * dxp + dyp * dyp)
        radius := 140.0
        prox := Max(0.0, Min(1.0, 1.0 - (dist / radius)))
        GDHO_RunJS("window.HoleOverlay?.update({ payload: '" p "', x: " Integer(lx) ", y: " Integer(ly) " })")
    }
    GDHO_ApplyDropHitTestByProximity(prox)
    GDHO_LAST_UPDATE_TICK := nowTick
}

GDHO_Drop(payload := "file") {
    global GDHO_LAST_DROP_TICK
    p := (payload = "text") ? "text" : "file"
    nowTick := A_TickCount
    if (GDHO_LAST_DROP_TICK && (nowTick - GDHO_LAST_DROP_TICK < 120))
        return
    GDHO_LAST_DROP_TICK := nowTick
    ; Let frontend play drop expansion first, then execute command shortly after.
    try GDHO_RunJS("window.HoleOverlay?.setNativeState({ kind: 'drop', dispatch: 'pending' })")
    GDHO_RunJS("window.HoleOverlay?.drop({ payload: '" p "' })")
    SetTimer(GDHO_ExecuteDropCommand.Bind(p), -700)
}

GDHO_ExecuteDropCommand(payload := "file") {
    global GDHO_LAST_DROPPED_TEXT, GDHO_SESSION_TEXT
    p := (payload = "text") ? "text" : "file"
    if (p = "text") {
        txt := Trim(String(GDHO_SESSION_TEXT))
        if (txt = "")
            txt := Trim(String(GDHO_LAST_DROPPED_TEXT))
        if (txt = "") {
            try txt := Trim(String(GDHO_GetBestSelectedText()))
        }
        if (txt = "") {
            try txt := Trim(String(GDHO_CaptureSelectedTextViaCopy()))
        }
        if (txt = "") {
            try txt := Trim(String(A_Clipboard))
        }
        try FloatingToolbar_ActivateSearchCenter()
        try SetTimer(FloatingToolbar_ActivateSearchCenter, -80)
        try SetTimer(FloatingToolbar_ActivateSearchCenter, -220)
        if (txt != "") {
            try FloatingToolbar_RequestSearchByKeyword(txt)
            try SetTimer(FloatingToolbar_RequestSearchByKeyword.Bind(txt), -120)
            try SetTimer(FloatingToolbar_RequestSearchByKeyword.Bind(txt), -320)
        }
        try GDHO_RunJS("window.HoleOverlay?.setNativeState({ dispatch: 'search:" (txt != "" ? "ok" : "empty") "' })")
        GDHO_SESSION_TEXT := ""
        return
    }
    ; File-like drop path: attempt native explorer fallback immediately.
    try GDHO_TryHandleExplorerDrop()
    try GDHO_RunJS("window.HoleOverlay?.setNativeState({ dispatch: 'files:fallback' })")
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
    global GDHO_MONITORING, GDHO_PRIORITY_APPLIED
    try NativeDropDiag_Log("gdho start begin")
    GDHO_Init()
    if GDHO_MONITORING
        return
    if !GDHO_PRIORITY_APPLIED {
        try ProcessSetPriority("Normal")
        try DllCall("SetThreadPriority", "Ptr", DllCall("GetCurrentThread", "Ptr"), "Int", 0)
        GDHO_PRIORITY_APPLIED := true
    }
    GDHO_MONITORING := true
    SetTimer(GDHO_PollDrag, GDHO_POLL_MS)
    try NativeDropDiag_Log("gdho start armed poll_ms=" . Integer(GDHO_POLL_MS))
}

GDHO_Stop() {
    global GDHO_MONITORING, GDHO_ACTIVE
    try NativeDropDiag_Log("gdho stop begin")
    GDHO_MONITORING := false
    GDHO_ACTIVE := false
    SetTimer(GDHO_PollDrag, 0)
    GDHO_HideFrontend()
    GDHO_HideOverlay()
    try NativeDropDiag_Log("gdho stop done")
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

GDHO_IsPointInHole(mx, my, margin := 0) {
    global GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y
    ; HoleOverlayStandalone: .hole-wrap default size 180x206 and moveTo({x:90,y:56})
    hx := Integer(GDHO_LAST_HOST_X) + 90 - Integer(margin)
    hy := Integer(GDHO_LAST_HOST_Y) + 56 - Integer(margin)
    hw := 180 + Integer(margin) * 2
    hh := 206 + Integer(margin) * 2
    x := Integer(mx), y := Integer(my)
    return (x >= hx && x <= hx + hw && y >= hy && y <= hy + hh)
}

GDHO_IsPointInToolbar(mx, my) {
    global FloatingToolbarGUI, FloatingToolbarIsVisible
    if !IsSet(FloatingToolbarGUI)
        return false
    if !IsObject(FloatingToolbarGUI) || !(FloatingToolbarGUI is Gui)
        return false
    if (IsSet(FloatingToolbarIsVisible) && !FloatingToolbarIsVisible)
        return false
    try FloatingToolbarGUI.GetPos(&tx, &ty, &tw, &th)
    catch
        return false
    return (mx >= tx && mx <= tx + tw && my >= ty && my <= ty + th)
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

GDHO_GetBestSelectedText() {
    txt := ""
    try txt := Trim(String(SelectionSense_GetLastSelectedText()))
    catch {
        txt := ""
    }
    return txt
}

GDHO_CaptureSelectedTextViaCopy() {
    oldClip := ""
    hadOld := false
    out := ""
    try {
        oldClip := ClipboardAll()
        hadOld := true
    } catch {
        hadOld := false
        oldClip := ""
    }
    try A_Clipboard := ""
    catch {
    }
    try Send("^c")
    catch {
    }
    try ClipWait(0.18)
    catch {
    }
    try out := Trim(String(A_Clipboard))
    catch {
        out := ""
    }
    try {
        if hadOld
            A_Clipboard := oldClip
    } catch {
    }
    return out
}

; ===== Global drag pre-judge =====
; Strategy:
; 1) Detect left-button hold + movement threshold.
; 2) Use cursor-shape change OR explorer-like source class to reduce false positives.
; 3) If likely dragging payload, show/update overlay globally.
GDHO_PollDrag(*) {
    global GDHO_ACTIVE, GDHO_START_X, GDHO_START_Y, GDHO_LAST_X, GDHO_LAST_Y
    global GDHO_START_CURSOR, GDHO_DRAG_SOURCE_CLASS, GDHO_PAYLOAD, GDHO_SESSION_TEXT
    global GDHO_MIN_MOVE_PX, GDHO_LAST_UPDATE_TICK, GDHO_MAX_IDLE_HIDE_MS, GDHO_DRAG_CONFIDENCE
    global GDHO_POLL_BUSY, GDHO_SUPPRESS_UNTIL_RELEASE, GDHO_TOOLBAR_NEAR_RADIUS_PX, GDHO_TOOLBAR_DISMISS_RADIUS_PX, GDHO_POSITION_MODE
    global FloatingToolbarDragging, NativeDropSessionActive
    global GDHO_RELEASE_PENDING, GDHO_RELEASE_DEADLINE_TICK, GDHO_RELEASE_SETTLE_MS
    global GDHO_LAST_CURSOR_NAME, GDHO_SAW_DRAG_CURSOR, GDHO_STRICT_MODE, GDHO_DRAG_CURSOR_STREAK
    if GDHO_POLL_BUSY
        return
    GDHO_POLL_BUSY := true

    try {
        pollStartTick := A_TickCount

        lDown := GetKeyState("LButton", "P")
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my, &hwnd)
        isOwn := GDHO_IsOwnWindowHwnd(hwnd)
        isOwnProc := GDHO_IsOwnProcessHwnd(hwnd)
        cName := ""
        try cName := String(A_Cursor)
        if (cName != "") {
            GDHO_LAST_CURSOR_NAME := cName
            if !GDHO_IsStandardCursorName(cName) {
                GDHO_SAW_DRAG_CURSOR := true
                GDHO_DRAG_CURSOR_STREAK += 1
            } else if lDown {
                GDHO_DRAG_CURSOR_STREAK := 0
            }
        }

        ; Physical fallback + settle buffer:
        ; keep state for a short window after release to avoid race with delayed native Drop.
        if (NativeDropSessionActive && !lDown) {
            if !GDHO_RELEASE_PENDING {
                GDHO_RELEASE_PENDING := true
                GDHO_RELEASE_DEADLINE_TICK := A_TickCount + Integer(GDHO_RELEASE_SETTLE_MS)
                if GDHO_ACTIVE
                    GDHO_Drop(GDHO_PAYLOAD)
            }
            if (GDHO_RELEASE_PENDING && GDHO_SAW_DRAG_CURSOR && GDHO_IsStandardCursorName(cName) && GDHO_IsPointInHole(mx, my, 20)) {
                GDHO_ExecuteDropCommand(GDHO_PAYLOAD)
                GDHO_SAW_DRAG_CURSOR := false
            }
            if (A_TickCount < GDHO_RELEASE_DEADLINE_TICK)
                return
            GDHO_RELEASE_PENDING := false
            GDHO_RELEASE_DEADLINE_TICK := 0
            GDHO_ACTIVE := false
            NativeDropSessionActive := false
            GDHO_SAW_DRAG_CURSOR := false
            GDHO_DRAG_CURSOR_STREAK := 0
            GDHO_HideFrontend()
            GDHO_HideOverlay()
            GDHO_ResetPointerSeed()
            return
        }

        ; Hard guard: dragging/operating toolbar must never trigger hole logic.
        if (IsSet(FloatingToolbarDragging) && FloatingToolbarDragging) {
            GDHO_SUPPRESS_UNTIL_RELEASE := true
            GDHO_ACTIVE := false
            GDHO_HideFrontend()
            GDHO_HideOverlay()
            GDHO_ResetPointerSeed()
            return
        }
        if isOwn {
            GDHO_SUPPRESS_UNTIL_RELEASE := true
            GDHO_ACTIVE := false
            GDHO_HideFrontend()
            GDHO_HideOverlay()
            GDHO_ResetPointerSeed()
            return
        }
        if isOwnProc {
            GDHO_SUPPRESS_UNTIL_RELEASE := true
            GDHO_ACTIVE := false
            GDHO_HideFrontend()
            GDHO_HideOverlay()
            GDHO_ResetPointerSeed()
            return
        }
        if GDHO_IsPointInToolbar(mx, my) {
            GDHO_SUPPRESS_UNTIL_RELEASE := true
            GDHO_ACTIVE := false
            GDHO_HideFrontend()
            GDHO_HideOverlay()
            GDHO_ResetPointerSeed()
            return
        }

        if !lDown {
            ; Defensive: if toolbar drag state got stuck, force-close it on mouse-up.
            try FloatingToolbar_EndDrag()
            GDHO_SUPPRESS_UNTIL_RELEASE := false
            GDHO_DRAG_CONFIDENCE := 0.0
            GDHO_DRAG_CURSOR_STREAK := 0
            if (GDHO_ACTIVE || NativeDropSessionActive) {
                if !GDHO_RELEASE_PENDING {
                    GDHO_RELEASE_PENDING := true
                    GDHO_RELEASE_DEADLINE_TICK := A_TickCount + Integer(GDHO_RELEASE_SETTLE_MS)
                    if GDHO_ACTIVE
                        GDHO_Drop(GDHO_PAYLOAD)
                }
                if (GDHO_RELEASE_PENDING && GDHO_SAW_DRAG_CURSOR && GDHO_IsStandardCursorName(cName) && GDHO_IsPointInHole(mx, my, 20)) {
                    GDHO_ExecuteDropCommand(GDHO_PAYLOAD)
                    GDHO_SAW_DRAG_CURSOR := false
                }
                if (A_TickCount < GDHO_RELEASE_DEADLINE_TICK)
                    return
                GDHO_RELEASE_PENDING := false
                GDHO_RELEASE_DEADLINE_TICK := 0
                NativeDropSessionActive := false
                if GDHO_ACTIVE {
                    GDHO_ACTIVE := false
                    GDHO_TryHandleExplorerDrop()
                    SetTimer((*) => GDHO_HideOverlay(), -700)
                } else if (A_TickCount - GDHO_LAST_UPDATE_TICK > GDHO_MAX_IDLE_HIDE_MS) {
                    GDHO_HideFrontend()
                    GDHO_HideOverlay()
                }
                GDHO_SAW_DRAG_CURSOR := false
                GDHO_DRAG_CURSOR_STREAK := 0
                GDHO_ResetPointerSeed()
                return
            } else if (A_TickCount - GDHO_LAST_UPDATE_TICK > GDHO_MAX_IDLE_HIDE_MS) {
                GDHO_HideFrontend()
                GDHO_HideOverlay()
            }
            GDHO_RELEASE_PENDING := false
            GDHO_RELEASE_DEADLINE_TICK := 0
            GDHO_SAW_DRAG_CURSOR := false
            GDHO_DRAG_CURSOR_STREAK := 0
            GDHO_SESSION_TEXT := ""
            GDHO_ResetPointerSeed()
            return
        }

        if GDHO_SUPPRESS_UNTIL_RELEASE {
            GDHO_HideFrontend()
            GDHO_HideOverlay()
            GDHO_ACTIVE := false
            GDHO_SESSION_TEXT := ""
            return
        }

        if (GDHO_START_X = 0 && GDHO_START_Y = 0) {
            ; Do not seed drag from our own UI (toolbar/bubble/hole), avoid feedback loops.
            if isOwn
                return
            GDHO_START_X := mx
            GDHO_START_Y := my
            GDHO_START_ROOT_HWND := GDHO_GetRootHwnd(hwnd)
            GDHO_LAST_X := mx
            GDHO_LAST_Y := my
            GDHO_START_CURSOR := GDHO_GetCursorHandle()
            GDHO_DRAG_SOURCE_CLASS := GDHO_GetClassByHwnd(hwnd)
            GDHO_PAYLOAD := GDHO_GuessPayloadType(GDHO_DRAG_SOURCE_CLASS)
            if (GDHO_PAYLOAD = "text")
                GDHO_SESSION_TEXT := GDHO_GetBestSelectedText()
            return
        }

        dx := mx - GDHO_START_X
        dy := my - GDHO_START_Y
        startClass := GDHO_DRAG_SOURCE_CLASS
        startCursorChanged := (GDHO_START_CURSOR != 0 && GDHO_START_CURSOR != GDHO_GetCursorHandle())
        quickThreshold := (startClass = "Chrome_WidgetWin_1" || startClass = "Edit") && startCursorChanged
        activeMovePx := quickThreshold ? 5 : GDHO_MIN_MOVE_PX
        moved := (dx * dx + dy * dy) >= (activeMovePx * activeMovePx)
        if !moved
            return

        likelyDrag := GDHO_IsLikelyDrag(GDHO_DRAG_SOURCE_CLASS, GDHO_START_CURSOR)
        if !likelyDrag
            return
        if (GDHO_STRICT_MODE && !GDHO_IsStrictDragQualified(GDHO_DRAG_SOURCE_CLASS, GDHO_DRAG_CURSOR_STREAK, cName, GDHO_START_CURSOR))
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
            ; In relative mode, position with current frame coordinates first to avoid follow-offset.
            if (GDHO_POSITION_MODE != "relative") {
                ; Reveal hole immediately on activation for faster visual response.
                GDHO_ShowOverlay()
                GDHO_RunJS("window.HoleOverlay?.show('" GDHO_PAYLOAD "')")
            }
            ; Relative mode will place hole once here, then GDHO_Update keeps it fixed.
            GDHO_Show(GDHO_PAYLOAD, mx, my)
            GDHO_ACTIVE := true
            NativeDropSessionActive := true
            GDHO_RELEASE_PENDING := false
            GDHO_RELEASE_DEADLINE_TICK := 0
        }
        GDHO_Update(GDHO_PAYLOAD, mx, my)
        GDHO_LAST_X := mx
        GDHO_LAST_Y := my
    } finally {
        pollElapsed := A_TickCount - pollStartTick
        if (pollElapsed >= 18)
            try NativeDropDiag_Log("gdho poll slow ms=" . pollElapsed . " active=" . (GDHO_ACTIVE ? "1" : "0") . " ldown=" . (lDown ? "1" : "0"))
        GDHO_DIAG_LOG("PollDrag", pollElapsed)
        GDHO_POLL_BUSY := false
    }
}

GDHO_ApplyDropHitTestByProximity(p) {
    global GDHO_GUI, GDHO_ACTIVE, GDHO_CLICKTHROUGH
    if !GDHO_GUI
        return
    prox := Max(0.0, Min(1.0, Float(p)))
    if (prox >= 0.6) {
        try WinSetExStyle("-0x20", "ahk_id " GDHO_GUI.Hwnd)
        GDHO_CLICKTHROUGH := false
        return
    }
    if (!GDHO_ACTIVE || prox < 0.5) {
        try WinSetExStyle("+0x20", "ahk_id " GDHO_GUI.Hwnd)
        GDHO_CLICKTHROUGH := true
    }
}

GDHO_IsStandardCursorName(name) {
    n := StrLower(Trim(String(name)))
    if (n = "")
        return false
    return (n = "arrow" || n = "ibeam" || n = "wait" || n = "appstarting" || n = "cross" || n = "help"
        || n = "uparrow" || n = "sizeall" || n = "sizens" || n = "sizewe" || n = "sizenesw" || n = "sizenwse"
        || n = "hand" || n = "no")
}

GDHO_IsStrictDragQualified(srcClass, cursorStreak, currentCursorName, startCursor) {
    ; Strict mode goal:
    ; 1) Ordinary mouse pass should not light up the hole.
    ; 2) Require explicit drag-cursor evidence (continuous frames).
    if (cursorStreak < 2)
        return false
    ; Explorer/Desktop source can be accepted once drag cursor is stable.
    if (srcClass = "CabinetWClass" || srcClass = "ExploreWClass" || srcClass = "WorkerW" || srcClass = "Progman")
        return true
    ; Non-explorer source: need stronger evidence than class alone.
    if !GDHO_IsStandardCursorName(currentCursorName)
        return true
    ; Fallback: if handle changed from press seed and streak is stable.
    return (startCursor != 0 && startCursor != GDHO_GetCursorHandle())
}

GDHO_IsOwnGuiRefHwnd(guiRef, hwnd, rootHwnd) {
    if !hwnd
        return false
    if !IsSet(guiRef) || !guiRef
        return false
    try {
        if IsObject(guiRef) {
            if !guiRef.HasProp("Hwnd")
                return false
            oh := guiRef.Hwnd
            return (oh && (hwnd = oh || rootHwnd = oh))
        }
        gh := Integer(guiRef)
        return (gh && (hwnd = gh || rootHwnd = gh))
    } catch {
        return false
    }
}

GDHO_IsOwnWindowHwnd(hwnd) {
    global GDHO_GUI, FloatingToolbarGUI, FloatingBubbleGUI
    global TrayMenuGUI, g_SCWV_Gui, g_CP_Gui, g_VK_Gui, g_PQP_Gui, g_SelSense_MenuGui
    global AIListPanelGUI, GuiID_ConfigGUI, GuiID_SearchCenter
    global GuiID_ClipboardManager, GuiID_ClipboardHistory, GuiID_ClipboardFTS5, GuiID_ClipboardMonitor, GuiID_ClipboardDebug
    global GuiID_ClipboardSmartMenu, GuiID_ScreenshotEditor, GuiID_ScreenshotToolbar
    global GuiID_VoiceInputPanel, GuiID_VoiceInput, PromptQuickPadCtxMenuGUI, g_CP_PeekGui, g_CloudPlayerGui

    if !hwnd
        return false
    rootHwnd := GDHO_GetRootHwnd(hwnd)

    if (IsSet(GDHO_GUI) && GDHO_IsOwnGuiRefHwnd(GDHO_GUI, hwnd, rootHwnd))
        return true
    if (IsSet(FloatingToolbarGUI) && GDHO_IsOwnGuiRefHwnd(FloatingToolbarGUI, hwnd, rootHwnd))
        return true
    if (IsSet(FloatingBubbleGUI) && GDHO_IsOwnGuiRefHwnd(FloatingBubbleGUI, hwnd, rootHwnd))
        return true
    if (IsSet(TrayMenuGUI) && GDHO_IsOwnGuiRefHwnd(TrayMenuGUI, hwnd, rootHwnd))
        return true
    if (IsSet(g_SCWV_Gui) && GDHO_IsOwnGuiRefHwnd(g_SCWV_Gui, hwnd, rootHwnd))
        return true
    if (IsSet(g_CP_Gui) && GDHO_IsOwnGuiRefHwnd(g_CP_Gui, hwnd, rootHwnd))
        return true
    if (IsSet(g_CP_PeekGui) && GDHO_IsOwnGuiRefHwnd(g_CP_PeekGui, hwnd, rootHwnd))
        return true
    if (IsSet(g_VK_Gui) && GDHO_IsOwnGuiRefHwnd(g_VK_Gui, hwnd, rootHwnd))
        return true
    if (IsSet(g_PQP_Gui) && GDHO_IsOwnGuiRefHwnd(g_PQP_Gui, hwnd, rootHwnd))
        return true
    if (IsSet(g_SelSense_MenuGui) && GDHO_IsOwnGuiRefHwnd(g_SelSense_MenuGui, hwnd, rootHwnd))
        return true
    if (IsSet(AIListPanelGUI) && GDHO_IsOwnGuiRefHwnd(AIListPanelGUI, hwnd, rootHwnd))
        return true
    if (IsSet(GuiID_ConfigGUI) && GDHO_IsOwnGuiRefHwnd(GuiID_ConfigGUI, hwnd, rootHwnd))
        return true
    if (IsSet(GuiID_SearchCenter) && GDHO_IsOwnGuiRefHwnd(GuiID_SearchCenter, hwnd, rootHwnd))
        return true
    if (IsSet(GuiID_ClipboardManager) && GDHO_IsOwnGuiRefHwnd(GuiID_ClipboardManager, hwnd, rootHwnd))
        return true
    if (IsSet(GuiID_ClipboardHistory) && GDHO_IsOwnGuiRefHwnd(GuiID_ClipboardHistory, hwnd, rootHwnd))
        return true
    if (IsSet(GuiID_ClipboardFTS5) && GDHO_IsOwnGuiRefHwnd(GuiID_ClipboardFTS5, hwnd, rootHwnd))
        return true
    if (IsSet(GuiID_ClipboardMonitor) && GDHO_IsOwnGuiRefHwnd(GuiID_ClipboardMonitor, hwnd, rootHwnd))
        return true
    if (IsSet(GuiID_ClipboardDebug) && GDHO_IsOwnGuiRefHwnd(GuiID_ClipboardDebug, hwnd, rootHwnd))
        return true
    if (IsSet(GuiID_ClipboardSmartMenu) && GDHO_IsOwnGuiRefHwnd(GuiID_ClipboardSmartMenu, hwnd, rootHwnd))
        return true
    if (IsSet(GuiID_ScreenshotEditor) && GDHO_IsOwnGuiRefHwnd(GuiID_ScreenshotEditor, hwnd, rootHwnd))
        return true
    if (IsSet(GuiID_ScreenshotToolbar) && GDHO_IsOwnGuiRefHwnd(GuiID_ScreenshotToolbar, hwnd, rootHwnd))
        return true
    if (IsSet(GuiID_VoiceInputPanel) && GDHO_IsOwnGuiRefHwnd(GuiID_VoiceInputPanel, hwnd, rootHwnd))
        return true
    if (IsSet(GuiID_VoiceInput) && GDHO_IsOwnGuiRefHwnd(GuiID_VoiceInput, hwnd, rootHwnd))
        return true
    if (IsSet(PromptQuickPadCtxMenuGUI) && GDHO_IsOwnGuiRefHwnd(PromptQuickPadCtxMenuGUI, hwnd, rootHwnd))
        return true
    if (IsSet(g_CloudPlayerGui) && GDHO_IsOwnGuiRefHwnd(g_CloudPlayerGui, hwnd, rootHwnd))
        return true
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
    GDHO_START_ROOT_HWND := 0
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

GDHO_IsOwnProcessHwnd(hwnd) {
    if !hwnd
        return false
    try {
        pname := StrLower(WinGetProcessName("ahk_id " hwnd))
        if InStr(pname, "autohotkey")
            return true
    } catch {
    }
    return false
}

GDHO_IsLikelyDrag(srcClass, startCursor) {
    global GDHO_DRAG_CONFIDENCE
    cNow := GDHO_GetCursorHandle()
    if (cNow = 0)
        return false

    ; Explorer/Desktop class: high confidence file/folder drag
    if (srcClass = "CabinetWClass" || srcClass = "ExploreWClass" || srcClass = "WorkerW" || srcClass = "Progman") {
        GDHO_DRAG_CONFIDENCE := 1.0
        return true
    }

    ; Browser/Edit text drag: cursor switched means strong signal.
    if ((srcClass = "Chrome_WidgetWin_1" || srcClass = "Edit") && startCursor != 0 && cNow != startCursor) {
        GDHO_DRAG_CONFIDENCE := 0.95
        return true
    }

    ; generic fallback: cursor changed after movement, usually indicates drag-mode cursor
    if (startCursor != 0 && cNow != startCursor) {
        GDHO_DRAG_CONFIDENCE := 0.7
        return true
    }

    GDHO_DRAG_CONFIDENCE := 0.2

    return false
}

GDHO_GuessPayloadType(srcClass) {
    ; Explorer/Desktop drags are generally file/folder.
    if (srcClass = "CabinetWClass" || srcClass = "ExploreWClass" || srcClass = "WorkerW" || srcClass = "Progman")
        return "file"
    ; Other apps default to text-like drag behavior.
    return "text"
}

; ==== Explorer drop fallback: get selected files via Shell.Application COM ====
GDHO_TryHandleExplorerDrop() {
    global GDHO_DRAG_SOURCE_CLASS, GDHO_START_ROOT_HWND
    static s_lastDropTick := 0
    if (GDHO_DRAG_SOURCE_CLASS != "CabinetWClass" && GDHO_DRAG_SOURCE_CLASS != "ExploreWClass"
        && GDHO_DRAG_SOURCE_CLASS != "WorkerW" && GDHO_DRAG_SOURCE_CLASS != "Progman")
        return
    if !GDHO_START_ROOT_HWND
        return
    ; Deduplicate: prevent double-fire from both OS COM and JS native drop
    if (A_TickCount - s_lastDropTick < 1200)
        return
    s_lastDropTick := A_TickCount
    files := []
    try {
        shell := ComObject("Shell.Application")
        for window in shell.Windows {
            try {
                if (window.HWND = GDHO_START_ROOT_HWND) {
                    doc := window.Document
                    for item in doc.SelectedItems {
                        fp := Trim(String(item.Path))
                        if (fp != "")
                            files.Push(fp)
                    }
                    break
                }
            }
        }
    }
    if (files.Length > 0) {
        try FloatingToolbar_HandleDroppedFiles(files)
    }
}




