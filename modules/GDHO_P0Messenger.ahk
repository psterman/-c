#Requires AutoHotkey v2.0

; P0: AHK 仅作信使 — 禁止运行时 Move/Hide/Park；样式/透明/WebView 布局仍由 AHK 维护至 P2。
; 见 docs/INTERACTION_MANAGER.md

global GDHO_P0_READONLY := true
global GDHO_P2_WINDOW_POLICY := true
global GDHO_P0_WS_EVENT_URL := "http://127.0.0.1:18790/hole/event"
global g_GDHO_P0_LastHttpFailTick := 0
global g_GDHO_P2_LastPolicyTick := 0

GDHO_P2_IsEnabled() {
    global GDHO_P2_WINDOW_POLICY
    return !!GDHO_P2_WINDOW_POLICY
}

GDHO_P0_IsReadonly() {
    global GDHO_P0_READONLY
    return !!GDHO_P0_READONLY
}

; 仅拦截 Move / Hide / Park（不拦截 WinSet、Resize、Z 序）。显式关闭/收纳仍放行，避免残留黑块。
GDHO_P0_BlockHostMoveHide(reason := "") {
    if !GDHO_P0_IsReadonly()
        return false
    r := StrLower(Trim(String(reason)))
    if (r = "")
        r := "unspecified"
    if (InStr(r, "dismiss") || InStr(r, "panel_hole_close") || InStr(r, "panel_escape") || InStr(r, "panel_close")
        || InStr(r, "hide_overlay") || InStr(r, "park_overlay") || InStr(r, "hide_starry") || InStr(r, "starry_hole_close")
        || InStr(r, "shelve") || InStr(r, "selection_preview") || InStr(r, "weak_preview") || InStr(r, "reset_session")
        || InStr(r, "hide_panel") && (InStr(r, "close") || InStr(r, "esc") || InStr(r, "shelve")))
        return false
    if FuncExists("GDHO_IsPanelDragProtected") {
        try {
            if GDHO_IsPanelDragProtected() && (InStr(r, "move_panel") || InStr(r, "panel_host") || InStr(r, "apply_panel"))
                return false
        } catch {
        }
    }
    if FuncExists("GDHO_IsTextHolePanelOpen") {
        try {
            if GDHO_IsTextHolePanelOpen() && (InStr(r, "sync_panel") || InStr(r, "move_panel") || InStr(r, "ensure") || InStr(r, "present") || InStr(r, "show_panel"))
                return false
        } catch {
        }
    }
    if FuncExists("GDHO_ShouldKeepTextHolePanel") {
        try {
            if GDHO_ShouldKeepTextHolePanel() && (InStr(r, "sync_panel") || InStr(r, "move_panel") || InStr(r, "panel_host") || InStr(r, "apply_panel"))
                return false
        } catch {
        }
    }
    try NativeDropDiag_Log("[P0] block_move_hide reason=" . r)
    catch {
    }
    return true
}

; 兼容旧调用名
GDHO_P0_BlockHostWindowOps(reason := "") {
    return GDHO_P0_BlockHostMoveHide(reason)
}

GDHO_WS_Send(evtType, screenX := "", screenY := "", text := "", reason := "") {
    global GDHO_P0_WS_EVENT_URL, g_GDHO_P0_LastHttpFailTick
    typ := Trim(String(evtType))
    if (typ = "")
        return false
    body := Map("type", typ)
    if (text != "")
        body["text"] := String(text)
    if (reason != "")
        body["reason"] := String(reason)
    if (screenX != "" && screenY != "") {
        body["screenX"] := Integer(screenX)
        body["screenY"] := Integer(screenY)
        body["anchorX"] := Integer(screenX)
        body["anchorY"] := Integer(screenY)
    }
    try json := Jxon_Dump(body)
    catch {
        return false
    }
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", GDHO_P0_WS_EVENT_URL, false)
        whr.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
        whr.Send(json)
        if (Integer(whr.Status) >= 200 && Integer(whr.Status) < 300)
            return true
    } catch as e {
        now := A_TickCount
        if (!g_GDHO_P0_LastHttpFailTick || (now - g_GDHO_P0_LastHttpFailTick > 8000)) {
            g_GDHO_P0_LastHttpFailTick := now
            try NativeDropDiag_Log("[P0] ws_http_fail type=" . typ . " err=" . e.Message)
            catch {
            }
        }
    }
    return false
}

GDHO_WS_SendSelectionPreview(text, anchorX, anchorY) {
    return GDHO_WS_Send("selection_preview", anchorX, anchorY, text, "ahk_selection_preview")
}

GDHO_WS_SendPanelPresent(mx, my, text := "") {
    return GDHO_WS_Send("panel_present", mx, my, text, "ahk_panel_present")
}

GDHO_WS_RelayPanelMessage(msg) {
    if !(msg is Map)
        return
    typ := msg.Has("type") ? StrLower(Trim(String(msg["type"]))) : ""
    if (typ = "")
        return
    sx := msg.Has("screenX") ? msg["screenX"] : ""
    sy := msg.Has("screenY") ? msg["screenY"] : ""
    rs := msg.Has("reason") ? String(msg["reason"]) : ""
    switch typ {
        case "panel_moved", "pointer_move":
            GDHO_WS_Send("pointer_move", sx, sy)
        case "panel_drag_start":
            GDHO_WS_Send("panel_drag_start", sx, sy)
        case "panel_drag_end":
            GDHO_WS_Send("panel_drag_end", sx, sy)
        case "hole_close", "panel_dismiss", "dismiss":
            GDHO_WS_Send("dismiss", "", "", "", rs)
        case "hole_commit", "proximity_commit":
            GDHO_WS_Send("hole_commit", sx, sy)
        default:
            return
    }
}
