#Requires AutoHotkey v2.0

; 门控式光标同步：仅在 OLE 拖放会话且已达移动阈值时，向 Go 桩发送物理坐标。

global g_NativeDropBridgeSessionId := 0

; ================= Host-Driven Hit-Test Guard (Physics) =================
; No dependency on frontend mouse events.
; 1) Low-frequency (200ms) poll: ExecuteScript -> postMessage rect JSON back to AHK.
; 2) High-frequency (60Hz) physics ticker: use screen mouse coords, collide with cached
;    screen-space rectangles; enter -> solid (-E0x20), exit -> transparent (+E0x20).

global g_HitTestGuardEnabled := true
global g_HoleIsSolidState := false
global g_HitTestGuardStarted := false

global g_HUD_X := 0, g_HUD_Y := 0, g_HUD_W := 0, g_HUD_H := 0
global g_PANEL_X := 0, g_PANEL_Y := 0, g_PANEL_W := 0, g_PANEL_H := 0
global g_HitRectReady := false

; hysteresis pixels to prevent flicker near boundary
global g_HitEnterPad := 2
global g_HitExitPad := 6
global g_HitStableIn := 0
global g_HitStableOut := 0
global g_HoleLastFocusTick := 0
global g_ManualZoneStableIn := 0
global g_ManualZoneStableOut := 0
global g_ManualZoneWasInteractive := false

NativeDrop_StartHitTestGuard() {
    global g_HitTestGuardEnabled, g_HitTestGuardStarted, GDHO_MANUAL_PANEL_MODE
    if (FuncExists("GDHO_IsDecoupled") && GDHO_IsDecoupled())
        return
    if !g_HitTestGuardEnabled
        return
    if g_HitTestGuardStarted
        return
    g_HitTestGuardStarted := true
    SetTimer(NativeDrop_PollPanelRects, 200)
    if GDHO_MANUAL_PANEL_MODE {
        if FuncExists("GDHO_ApplyManualPanelInteractive")
            try GDHO_ApplyManualPanelInteractive("hit_guard_start_manual")
        if FuncExists("GDHO_SetHostChromaTransparent")
            try GDHO_SetHostChromaTransparent(true, "hit_guard_start_chroma_bg")
        SetTimer(NativeDrop_ManualPanelZoneTicker, 32)
        return
    }
    SetTimer(NativeDrop_PhysicsHitTestTicker, 16)
}

NativeDrop_StopHitTestGuard() {
    global g_HitTestGuardStarted, g_HitStableIn, g_HitStableOut, g_HitRectReady
    global g_ManualZoneStableIn, g_ManualZoneStableOut, g_ManualZoneWasInteractive
    if !g_HitTestGuardStarted
        return
    g_HitTestGuardStarted := false
    SetTimer(NativeDrop_PollPanelRects, 0)
    SetTimer(NativeDrop_ManualPanelZoneTicker, 0)
    SetTimer(NativeDrop_PhysicsHitTestTicker, 0)
    g_ManualZoneStableIn := 0
    g_ManualZoneStableOut := 0
    g_ManualZoneWasInteractive := false
    g_HitStableIn := 0
    g_HitStableOut := 0
    g_HitRectReady := false
    NativeDrop_SetHoleSolid(false)
}

; Called by GDHO_OnWebMessage when it receives rect report (string/json)
NativeDrop_HandlePanelRectsMessage(msgText) {
    global GDHO_GUI
    global g_HUD_X, g_HUD_Y, g_HUD_W, g_HUD_H
    global g_PANEL_X, g_PANEL_Y, g_PANEL_W, g_PANEL_H, g_HitRectReady

    if (msgText = "" || !InStr(msgText, "HITTEST_RECTS"))
        return false
    if !IsObject(GDHO_GUI) || !GDHO_GUI.Hwnd
        return false

    ; Extract floats then round. Expect fields: hx,hy,hw,hh, px,py,pw,ph in client coords.
    hx := "", hy := "", hw := "", hh := ""
    px := "", py := "", pw := "", ph := ""
    if !RegExMatch(msgText, '"hx"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)', &mhx)
        return false
    if !RegExMatch(msgText, '"hy"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)', &mhy)
        return false
    if !RegExMatch(msgText, '"hw"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)', &mhw)
        return false
    if !RegExMatch(msgText, '"hh"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)', &mhh)
        return false
    if !RegExMatch(msgText, '"px"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)', &mpx)
        return false
    if !RegExMatch(msgText, '"py"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)', &mpy)
        return false
    if !RegExMatch(msgText, '"pw"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)', &mpw)
        return false
    if !RegExMatch(msgText, '"ph"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)', &mph)
        return false
    try hx := Round(Float(mhx[1])), hy := Round(Float(mhy[1])), hw := Round(Float(mhw[1])), hh := Round(Float(mhh[1]))
    try px := Round(Float(mpx[1])), py := Round(Float(mpy[1])), pw := Round(Float(mpw[1])), ph := Round(Float(mph[1]))

    try WinGetPos(&wx, &wy, , , "ahk_id " . GDHO_GUI.Hwnd)
    catch
        return false

    ; Convert client rect -> screen rect
    g_HUD_X := Integer(wx + hx)
    g_HUD_Y := Integer(wy + hy)
    g_HUD_W := Integer(hw)
    g_HUD_H := Integer(hh)

    g_PANEL_X := Integer(wx + px)
    g_PANEL_Y := Integer(wy + py)
    g_PANEL_W := Integer(pw)
    g_PANEL_H := Integer(ph)

    g_HitRectReady := true
    return true
}

NativeDrop_PollPanelRects(*) {
    global g_HitTestGuardStarted
    if !g_HitTestGuardStarted
        return
    ; Ask frontend to post rects back via postMessage.
    ; IMPORTANT: host-driven; does not rely on mouse events.
    if FuncExists("GDHO_RunJS") {
        js := "(function(){try{var hud=document.querySelector('#hud-panel')||document.querySelector('#holeStreamHud');var pnl=document.querySelector('#manual-config-panel')||document.querySelector('#manualPanel');function rectOf(el){if(!el)return{l:0,t:0,w:0,h:0};var st=getComputedStyle(el);if(st.display==='none'||st.visibility==='hidden'||(+st.opacity||1)<=0.01)return{l:0,t:0,w:0,h:0};var r=el.getBoundingClientRect();return{l:r.left,t:r.top,w:r.width,h:r.height};}var a=rectOf(hud),b=rectOf(pnl);var msg={type:'HITTEST_RECTS',hx:a.l,hy:a.t,hw:a.w,hh:a.h,px:b.l,py:b.t,pw:b.w,ph:b.h};if(window.chrome&&window.chrome.webview&&window.chrome.webview.postMessage)window.chrome.webview.postMessage(JSON.stringify(msg));}catch(_e){}})();"
        GDHO_RunJS(js)
    }
}

; 手动常驻：鼠标进入面板/HUD → 关色键可输入；离开 → 开色键背景透明（宿主始终 -E0x20 关闭）
NativeDrop_ManualPanelZoneTicker(*) {
    global g_HitTestGuardStarted, g_HitRectReady
    global g_HUD_X, g_HUD_Y, g_HUD_W, g_HUD_H, g_PANEL_X, g_PANEL_Y, g_PANEL_W, g_PANEL_H
    global g_HitEnterPad, g_HitExitPad, g_ManualZoneStableIn, g_ManualZoneStableOut, g_ManualZoneWasInteractive
    global g_GDHO_HostChromaOn
    if !g_HitTestGuardStarted
        return
    if FuncExists("GDHO_SetClickThrough")
        try GDHO_SetClickThrough(false, "manual_zone_tick")
    if !g_HitRectReady
        return
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    inHud := NativeDrop_PointInRect(mx, my, g_HUD_X, g_HUD_Y, g_HUD_W, g_HUD_H, g_HitEnterPad)
    inPanel := NativeDrop_PointInRect(mx, my, g_PANEL_X, g_PANEL_Y, g_PANEL_W, g_PANEL_H, g_HitEnterPad)
    inside := (inHud || inPanel)
    if inside {
        g_ManualZoneStableIn += 1
        g_ManualZoneStableOut := 0
        if (g_ManualZoneStableIn >= 2 && !g_ManualZoneWasInteractive) {
            g_ManualZoneWasInteractive := true
            if FuncExists("GDHO_SyncManualChromaByMouse")
                GDHO_SyncManualChromaByMouse(true, "enter_panel_zone")
            if FuncExists("GDHO_ApplyManualPanelInteractive")
                GDHO_ApplyManualPanelInteractive("enter_panel_zone")
        } else if g_ManualZoneWasInteractive {
            if g_GDHO_HostChromaOn && FuncExists("GDHO_SyncManualChromaByMouse")
                GDHO_SyncManualChromaByMouse(true, "hold_panel_zone")
            if inPanel && FuncExists("NativeDrop_EnsureHostFocus")
                NativeDrop_EnsureHostFocus()
        }
        return
    }
    outHud := !NativeDrop_PointInRect(mx, my, g_HUD_X, g_HUD_Y, g_HUD_W, g_HUD_H, g_HitExitPad)
    outPanel := !NativeDrop_PointInRect(mx, my, g_PANEL_X, g_PANEL_Y, g_PANEL_W, g_PANEL_H, g_HitExitPad)
    if (outHud && outPanel) {
        g_ManualZoneStableOut += 1
        g_ManualZoneStableIn := 0
        if (g_ManualZoneStableOut >= 2 && g_ManualZoneWasInteractive) {
            g_ManualZoneWasInteractive := false
            if FuncExists("GDHO_SyncManualChromaByMouse")
                GDHO_SyncManualChromaByMouse(false, "leave_panel_zone")
        }
    }
}

NativeDrop_PhysicsHitTestTicker(*) {
    global g_HitTestGuardStarted, g_HitRectReady
    global g_HUD_X, g_HUD_Y, g_HUD_W, g_HUD_H, g_PANEL_X, g_PANEL_Y, g_PANEL_W, g_PANEL_H
    global g_HitEnterPad, g_HitExitPad, g_HitStableIn, g_HitStableOut
    if !g_HitTestGuardStarted
        return
    if !g_HitRectReady
        return
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)

    inHud := NativeDrop_PointInRect(mx, my, g_HUD_X, g_HUD_Y, g_HUD_W, g_HUD_H, g_HitEnterPad)
    inPanel := NativeDrop_PointInRect(mx, my, g_PANEL_X, g_PANEL_Y, g_PANEL_W, g_PANEL_H, g_HitEnterPad)
    inside := (inHud || inPanel)

    if inside {
        g_HitStableIn += 1
        g_HitStableOut := 0
        if (g_HitStableIn >= 2)
            NativeDrop_SetHoleSolid(true, inPanel)
        return
    }

    ; exit uses larger pad to avoid jitter
    outHud := !NativeDrop_PointInRect(mx, my, g_HUD_X, g_HUD_Y, g_HUD_W, g_HUD_H, g_HitExitPad)
    outPanel := !NativeDrop_PointInRect(mx, my, g_PANEL_X, g_PANEL_Y, g_PANEL_W, g_PANEL_H, g_HitExitPad)
    fullyOutside := (outHud && outPanel)
    if fullyOutside {
        g_HitStableOut += 1
        g_HitStableIn := 0
        if (g_HitStableOut >= 2)
            NativeDrop_SetHoleSolid(false, false)
    }
}

NativeDrop_PointInRect(x, y, rx, ry, rw, rh, pad := 0) {
    if (rw <= 1 || rh <= 1)
        return false
    x0 := Integer(rx) - Integer(pad)
    y0 := Integer(ry) - Integer(pad)
    x1 := Integer(rx + rw) + Integer(pad)
    y1 := Integer(ry + rh) + Integer(pad)
    return (x >= x0 && x <= x1 && y >= y0 && y <= y1)
}

NativeDrop_SetHoleSolid(isSolid := false, requestFocus := false) {
    global GDHO_GUI, g_HoleIsSolidState, GDHO_MANUAL_PANEL_MODE
    if FuncExists("GDHO_IsLauncherLayerActive") {
        try {
            if GDHO_IsLauncherLayerActive()
                return
        } catch {
        }
    }
    if (FuncExists("GDHO_IsDecoupled") && GDHO_IsDecoupled()) {
        if isSolid {
            if FuncExists("GDHO_ShowPanel") {
                if !FuncExists("GDHO_ShouldShowDecoupledPanel") || GDHO_ShouldShowDecoupledPanel("hit_guard_solid")
                    try GDHO_ShowPanel("hit_guard_solid")
            }
            if requestFocus && FuncExists("NativeDrop_EnsureHostFocus")
                NativeDrop_EnsureHostFocus()
        } else {
            if FuncExists("GDHO_HidePanel") && !GDHO_MANUAL_PANEL_MODE {
                skipHide := false
                if FuncExists("GDHO_IsTextHoleUserPanelActive") {
                    try skipHide := GDHO_IsTextHoleUserPanelActive()
                    catch {
                    }
                }
                if FuncExists("GDHO_IsPanelDragProtected") {
                    try skipHide := (skipHide || GDHO_IsPanelDragProtected())
                    catch {
                    }
                }
                if !skipHide
                    try GDHO_HidePanel("hit_guard_transparent")
            }
        }
        return
    }
    if !IsObject(GDHO_GUI) || !GDHO_GUI.Hwnd
        return
    wantSolid := !!isSolid
    ; 源头硬锁：手动输入面板模式下，宿主必须保持实体化，禁止切回穿透。
    if GDHO_MANUAL_PANEL_MODE
        wantSolid := true
    if (wantSolid = g_HoleIsSolidState) {
        if (wantSolid && requestFocus)
            NativeDrop_EnsureHostFocus()
        return
    }
    try {
        if FuncExists("GDHO_SetClickThrough") {
            GDHO_SetClickThrough(!wantSolid, "host_hit_guard_solid=" . (wantSolid ? "1" : "0"))
        } else {
            if wantSolid
                GDHO_GUI.Opt("-E0x20")
            else
                GDHO_GUI.Opt("+E0x20")
            hwnd := GDHO_GUI.Hwnd
            DllCall("user32\\SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0037)
        }
        g_HoleIsSolidState := wantSolid
    } catch {
        g_HoleIsSolidState := false
    }
    exAfter := 0
    try exAfter := DllCall("GetWindowLongPtr", "Ptr", GDHO_GUI.Hwnd, "Int", -20, "Ptr")
    try NativeDropDiag_Log("[HOST_HIT_GUARD] SetHoleSolid wantSolid=" . (wantSolid ? "1" : "0")
        . " requestFocus=" . (requestFocus ? "1" : "0")
        . " manualMode=" . (GDHO_MANUAL_PANEL_MODE ? "1" : "0")
        . " ex_after=0x" . Format("{:X}", exAfter)
        . " bit_WS_EX_TRANSPARENT=" . (!!(exAfter & 0x20) ? "1" : "0"))
    catch {
    }
    if (wantSolid && requestFocus)
        NativeDrop_EnsureHostFocus()
}

NativeDrop_EnsureHostFocus() {
    global GDHO_GUI, GDHO_PANEL_GUI, g_HoleLastFocusTick, GDHO_PANEL_VISIBLE
    if FuncExists("GDHO_IsPanelDragProtected") {
        try {
            if GDHO_IsPanelDragProtected()
                return
        } catch {
        }
    }
    if FuncExists("GDHO_IsTextHoleUserPanelActive") {
        try {
            if GDHO_IsTextHoleUserPanelActive()
                return
        } catch {
        }
    }
    if (FuncExists("GDHO_IsDecoupled") && GDHO_IsDecoupled() && IsSet(GDHO_PANEL_VISIBLE) && GDHO_PANEL_VISIBLE)
        return
    focusGui := 0
    if (FuncExists("GDHO_IsDecoupled") && GDHO_IsDecoupled() && IsObject(GDHO_PANEL_GUI))
        return
    else if IsObject(GDHO_GUI)
        focusGui := GDHO_GUI
    if !IsObject(focusGui) || !focusGui.Hwnd
        return
    now := A_TickCount
    if (now - g_HoleLastFocusTick < 120)
        return
    g_HoleLastFocusTick := now
    try {
        if !WinActive("ahk_id " . focusGui.Hwnd)
            WinActivate("ahk_id " . focusGui.Hwnd)
    } catch {
    }
}

NativeDropBridge_GetSessionId() {
    global g_NativeDropBridgeSessionId
    return g_NativeDropBridgeSessionId
}

NativeDropBridge_BumpSessionId() {
    global g_NativeDropBridgeSessionId
    g_NativeDropBridgeSessionId += 1
    return g_NativeDropBridgeSessionId
}

NativeDropBridge_FindGoHwnd() {
    hwnd := 0
    try hwnd := WinExist("ahk_exe native-drop-bridge.exe")
    if !hwnd {
        try hwnd := WinExist("ahk_class NMER_NativeDropBridge")
    }
    return hwnd
}

NativeDropBridge_SendCursorToGo(x, y, session := 0) {
    hwnd := NativeDropBridge_FindGoHwnd()
    if !hwnd
        return false
    if (session <= 0) {
        session := NativeDropBridge_GetSessionId()
    }
    payload := '{"op":"cursor","x":' . Integer(x) . ',"y":' . Integer(y) . ',"session":' . Integer(session) . '}'
    buf := Buffer((StrLen(payload) + 1) * 2, 0)
    StrPut(payload, buf, "UTF-8")
    cb := StrLen(payload) + 1
    cds := Buffer(A_PtrSize = 8 ? 24 : 12, 0)
    NumPut("Ptr", 2, cds, 0)
    NumPut("UInt", cb, cds, A_PtrSize)
    NumPut("Ptr", buf.Ptr, cds, A_PtrSize + 4)
    try {
        SendMessage(0x004A, 0, cds, , "ahk_id " . hwnd)
        return true
    } catch {
        return false
    }
}

NativeDropCursorSync_Start() {
    SetTimer(NativeDropCursorSync_Tick, 32)
}

NativeDropCursorSync_Stop() {
    SetTimer(NativeDropCursorSync_Tick, 0)
}

NativeDropCursorSync_Tick(*) {
    global NativeDropBridgePID, NativeDropSessionActive, NativeDropMovedEnough
    if !(NativeDropBridgePID && ProcessExist(NativeDropBridgePID))
        return
    if !(NativeDropSessionActive && NativeDropMovedEnough)
        return
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    static lastSig := ""
    sig := mx . "," . my
    if (sig = lastSig)
        return
    lastSig := sig
    NativeDropBridge_SendCursorToGo(mx, my, NativeDropBridge_GetSessionId())
}
