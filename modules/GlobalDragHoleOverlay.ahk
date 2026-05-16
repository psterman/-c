#Requires AutoHotkey v2.0

; GlobalDragHoleOverlay.ahk
; AHK global drag pre-judge -> drive Wails/WebView2 hole frontend (window.HoleOverlay.*)

global GDHO_GUI := 0
global GDHO_WV2_CTRL := 0
global GDHO_WV2 := 0
global GDHO_READY := false
global GDHO_VISIBLE := false
global GDHO_ERROR := false
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
global GDHO_SESSION_CAPTURE_TICKET := 0
global GDHO_FRONTEND_POST_MSG := 0x8127
global GDHO_FRONTEND_PENDING_JS := ""
global g_GDHO_FrontendQueue := []
global GDHO_PHASE_CLOSED := "CLOSED"
global GDHO_PHASE_OPENING := "OPENING"
global GDHO_PHASE_OPEN := "OPEN"
global GDHO_PHASE_CLOSING := "CLOSING"
global GDHO_PHASE_ERROR := "ERROR"
global g_GDHO_CurrentPhase := GDHO_PHASE_CLOSED
global g_GDHO_CurrentToken := 0
global g_GDHO_PhaseLastChanged := 0
global g_GDHO_IntentQueue := []
global g_GDHO_IntentPumpBusy := false
global g_GDHO_CreateInFlight := false
global g_GDHO_CreateStartTick := 0
global g_GDHO_CreateToken := 0
global g_GDHO_WaitingReadyReveal := false
global g_GDHO_OpenReason := ""
global g_GDHO_OpenPayload := 0
global g_GDHO_CloseAfterReady := false
global g_GDHO_AntiHangTimerArmed := false
global g_GDHO_LastStaleDropTick := 0
global g_GDHO_TransitionCtx := Map("allow", false)
global g_GDHO_LastOpenIntentReason := ""
global g_GDHO_LastOpenIntentTick := 0
; Warm-standby parking: keep the WebView host alive and physically offscreen.
global GDHO_PARK_X := -9999
global GDHO_PARK_Y := -9999
global GDHO_SLEEPING := true
global GDHO_INTERACTIVE := false
global GDHO_LAST_PROXIMITY_SENT := -1.0
global GDHO_LAST_HIDE_FRONTEND_TICK := 0
global GDHO_LAST_HIDE_OVERLAY_TICK := 0
global GDHO_DROP_LOCK := false
global GDHO_HITTEST_CAPTURED := false
global GDHO_IS_SUCKING := false
global GDHO_EXPANDED_HOLD := false
global GDHO_LAST_DIST_TO_HOLE := 99999.0
; Hidden-state parking: legacy dock settings are kept for ini compatibility.
global GDHO_HIDE_DOCK_ENABLED := true
global GDHO_HIDE_DOCK_EDGE := "right" ; right|left|top|bottom
global GDHO_HIDE_DOCK_MARGIN := 10
global GDHO_CX := 0
global GDHO_CY := 0
global GDHO_INNER_RADIUS := 76
global GDHO_SUCK_RADIUS := 140

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

GDHO_PhaseHex(phase) {
    p := StrUpper(Trim(String(phase)))
    switch p {
        case "OPENING":
            return "0x01"
        case "OPEN":
            return "0x02"
        case "CLOSING":
            return "0x03"
        case "ERROR":
            return "0x04"
        default:
            return "0x00"
    }
}

GDHO_LogIFS(intentCode, focusCode := "0x00", phase := "") {
    global g_GDHO_CurrentPhase
    ph := (phase != "") ? phase : g_GDHO_CurrentPhase
    try GDHO_Trace("[ifs] [" . intentCode . "/" . focusCode . "/" . GDHO_PhaseHex(ph) . "]")
}

GDHO_SetPhase(phase, reason := "") {
    global g_GDHO_CurrentPhase, g_GDHO_PhaseLastChanged
    p := StrUpper(Trim(String(phase)))
    if !(p = GDHO_PHASE_CLOSED || p = GDHO_PHASE_OPENING || p = GDHO_PHASE_OPEN || p = GDHO_PHASE_CLOSING || p = GDHO_PHASE_ERROR)
        return false
    prev := g_GDHO_CurrentPhase
    g_GDHO_CurrentPhase := p
    g_GDHO_PhaseLastChanged := A_TickCount
    try GDHO_Trace("gdho_phase " . prev . "->" . p . " reason=" . reason . " token=" . g_GDHO_CurrentToken)
    return true
}

GDHO_IsCurrentToken(token) {
    global g_GDHO_CurrentToken, g_GDHO_LastStaleDropTick
    ok := (Integer(token) = Integer(g_GDHO_CurrentToken))
    if !ok {
        now := A_TickCount
        if ((now - g_GDHO_LastStaleDropTick) > 100) {
            g_GDHO_LastStaleDropTick := now
            try GDHO_Trace("intent_drop_stale_token token=" . Integer(token) . " current=" . Integer(g_GDHO_CurrentToken))
        }
    }
    return ok
}

GDHO_InternalCallAllowed() {
    global g_GDHO_TransitionCtx
    return (g_GDHO_TransitionCtx is Map) && !!g_GDHO_TransitionCtx["allow"]
}

GDHO_IsOpeningOrBusy() {
    global g_GDHO_CurrentPhase, g_GDHO_WaitingReadyReveal, g_GDHO_CreateInFlight
    return (g_GDHO_CurrentPhase = GDHO_PHASE_OPENING
        || g_GDHO_CurrentPhase = GDHO_PHASE_CLOSING
        || g_GDHO_WaitingReadyReveal
        || g_GDHO_CreateInFlight)
}

GDHO_RequestOpen(payload := 0) {
    if !(payload is Map)
        payload := Map("payload", payload)
    if !payload.Has("reason")
        payload["reason"] := "request_open"
    GDHO_SubmitIntent("OPEN", 30, payload)
}

GDHO_RequestClose(reason := "") {
    GDHO_SubmitIntent("CLOSE", 30, Map("reason", reason != "" ? reason : "request_close"))
}

GDHO_RequestForceReset(reason := "") {
    GDHO_SubmitIntent("FORCE_RESET", 5, Map("reason", reason != "" ? reason : "request_force_reset"))
}

GDHO_SubmitIntent(intent, priority := 50, payload := 0) {
    global g_GDHO_IntentQueue, g_GDHO_LastOpenIntentReason, g_GDHO_LastOpenIntentTick
    normalized := StrUpper(Trim(String(intent)))
    if (normalized = "FORCE_CLOSE")
        normalized := "FORCE_RESET"
    if (normalized = "")
        return
    if !(g_GDHO_IntentQueue is Array)
        g_GDHO_IntentQueue := []
    intentHex := (normalized = "OPEN") ? "0x11" : ((normalized = "CLOSE") ? "0x12" : ((normalized = "FORCE_RESET") ? "0x13" : "0x10"))
    GDHO_LogIFS(intentHex)
    if (normalized = "OPEN" && payload is Map && payload.Has("reason")) {
        reasonNorm := StrLower(Trim(String(payload["reason"])))
        delta := A_TickCount - g_GDHO_LastOpenIntentTick
        if (reasonNorm != "" && reasonNorm = g_GDHO_LastOpenIntentReason && delta >= 0 && delta < 120) {
            try GDHO_Trace("gdho_intent_drop_dup_open reason=" . reasonNorm . " delta=" . delta)
            return
        }
        g_GDHO_LastOpenIntentReason := reasonNorm
        g_GDHO_LastOpenIntentTick := A_TickCount
    }
    idx := g_GDHO_IntentQueue.Length
    while (idx >= 1) {
        item := g_GDHO_IntentQueue[idx]
        if (StrUpper(Trim(String(item["intent"]))) = normalized)
            g_GDHO_IntentQueue.RemoveAt(idx)
        idx -= 1
    }
    g_GDHO_IntentQueue.Push(Map("intent", normalized, "priority", Integer(priority), "payload", payload, "ts", A_TickCount))
    SetTimer(GDHO_PumpIntents, -10)
}

GDHO_PumpIntents(*) {
    global g_GDHO_IntentQueue, g_GDHO_IntentPumpBusy
    if g_GDHO_IntentPumpBusy
        return
    g_GDHO_IntentPumpBusy := true
    try {
        while (g_GDHO_IntentQueue is Array) && g_GDHO_IntentQueue.Length {
            bestIdx := 1
            bestPri := g_GDHO_IntentQueue[1]["priority"]
            loop g_GDHO_IntentQueue.Length {
                i := A_Index
                pri := g_GDHO_IntentQueue[i]["priority"]
                if (pri < bestPri) {
                    bestPri := pri
                    bestIdx := i
                }
            }
            it := g_GDHO_IntentQueue.RemoveAt(bestIdx)
            GDHO_HandleIntent(it["intent"], it["payload"], it["priority"])
        }
    } finally {
        g_GDHO_IntentPumpBusy := false
    }
}

GDHO_HandleIntent(intent, payload := 0, priority := 50) {
    global g_GDHO_CurrentToken
    iname := StrUpper(Trim(String(intent)))
    reason := payload is Map && payload.Has("reason") ? payload["reason"] : "gdho_" . StrLower(iname)
    switch iname {
        case "OPEN":
            GDHO_TransitionTo(GDHO_PHASE_OPEN, reason, payload, Integer(priority))
        case "CLOSE":
            GDHO_TransitionTo(GDHO_PHASE_CLOSED, reason, payload, Integer(priority))
        case "FORCE_RESET":
            g_GDHO_CurrentToken += 1
            GDHO_SetPhase(GDHO_PHASE_ERROR, "force_reset_" . reason)
            GDHO_ForceReset(reason)
            GDHO_SetPhase(GDHO_PHASE_CLOSED, "force_reset_done_" . reason)
    }
}

GDHO_ArmAntiHang(token) {
    global g_GDHO_AntiHangTimerArmed
    g_GDHO_AntiHangTimerArmed := true
    SetTimer((*) => GDHO_AntiHangTick(token), -80)
}

GDHO_AntiHangTick(token) {
    global g_GDHO_CurrentToken, g_GDHO_CurrentPhase, g_GDHO_PhaseLastChanged, g_GDHO_AntiHangTimerArmed
    global GDHO_READY, GDHO_VISIBLE, g_GDHO_WaitingReadyReveal
    if (token != g_GDHO_CurrentToken)
        return
    if (g_GDHO_CurrentPhase = GDHO_PHASE_OPENING && GDHO_READY && (GDHO_VISIBLE || !g_GDHO_WaitingReadyReveal)) {
        GDHO_SetPhase(GDHO_PHASE_OPEN, "anti_hang_promote_open")
        g_GDHO_AntiHangTimerArmed := false
        return
    }
    if !(g_GDHO_CurrentPhase = GDHO_PHASE_OPENING || g_GDHO_CurrentPhase = GDHO_PHASE_CLOSING) {
        g_GDHO_AntiHangTimerArmed := false
        return
    }
    elapsed := A_TickCount - g_GDHO_PhaseLastChanged
    timeoutMs := (g_GDHO_CurrentPhase = GDHO_PHASE_OPENING) ? 7000 : 2500
    if (elapsed > timeoutMs) {
        g_GDHO_AntiHangTimerArmed := false
        try GDHO_Trace("gdho_force_reset_watchdog phase=" . g_GDHO_CurrentPhase . " elapsed=" . elapsed)
        GDHO_SubmitIntent("FORCE_RESET", 5, Map("reason", "anti_hang_" . g_GDHO_CurrentPhase))
        return
    }
    SetTimer((*) => GDHO_AntiHangTick(token), -80)
}

GDHO_TransitionTo(targetPhase, reason := "", payload := 0, priority := 50) {
    global g_GDHO_CurrentPhase, g_GDHO_CurrentToken, g_GDHO_TransitionCtx, g_GDHO_CloseAfterReady
    global g_GDHO_OpenPayload, g_GDHO_OpenReason, g_GDHO_WaitingReadyReveal
    global GDHO_VISIBLE, GDHO_READY, GDHO_DESKTOP_PINNED
    ts := StrUpper(Trim(String(targetPhase)))
    cur := StrUpper(Trim(String(g_GDHO_CurrentPhase)))
    if !(ts = GDHO_PHASE_OPEN || ts = GDHO_PHASE_CLOSED)
        return false
    if (ts = GDHO_PHASE_OPEN) {
        g_GDHO_CurrentToken += 1
        token := g_GDHO_CurrentToken
        g_GDHO_OpenPayload := payload
        g_GDHO_OpenReason := reason
        g_GDHO_CloseAfterReady := false
        g_GDHO_WaitingReadyReveal := true
        if (cur = GDHO_PHASE_CLOSING)
            GDHO_SetPhase(GDHO_PHASE_OPENING, "interrupt_open_" . reason)
        else if !(cur = GDHO_PHASE_OPEN && GDHO_VISIBLE)
            GDHO_SetPhase(GDHO_PHASE_OPENING, reason)
        GDHO_ArmAntiHang(token)
        g_GDHO_TransitionCtx["allow"] := true
        try GDHO_Init()
        finally g_GDHO_TransitionCtx["allow"] := false
        if (payload is Map)
            _GDHO_ApplyOpenPayload(payload)
        if (GDHO_READY)
            GDHO_RevealIfReady(token, reason)
        return true
    }
    if (cur = GDHO_PHASE_OPENING) {
        g_GDHO_CloseAfterReady := true
        try GDHO_Trace("gdho_close_defer_until_ready reason=" . reason)
        return true
    }
    if (GDHO_DESKTOP_PINNED && reason != "desktop_unpin") {
        try GDHO_Trace("gdho_intent_drop_pinned_close reason=" . reason)
        return false
    }
    if (cur = GDHO_PHASE_CLOSED && !GDHO_VISIBLE)
        return true
    g_GDHO_CurrentToken += 1
    token := g_GDHO_CurrentToken
    GDHO_SetPhase(GDHO_PHASE_CLOSING, reason)
    GDHO_ArmAntiHang(token)
    GDHO_InternalClose(reason, token)
    GDHO_SetPhase(GDHO_PHASE_CLOSED, "closed_after_hide_" . reason)
    return true
}

_GDHO_ApplyOpenPayload(payload) {
    global GDHO_PAYLOAD, GDHO_CURSOR_X, GDHO_CURSOR_Y, GDHO_POSITION_MODE
    if !(payload is Map)
        return
    if payload.Has("payload")
        GDHO_PAYLOAD := (String(payload["payload"]) = "text") ? "text" : "file"
    if payload.Has("positionMode")
        GDHO_POSITION_MODE := String(payload["positionMode"])
    if payload.Has("screenX")
        GDHO_CURSOR_X := Integer(payload["screenX"])
    if payload.Has("screenY")
        GDHO_CURSOR_Y := Integer(payload["screenY"])
}

GDHO_RevealIfReady(token := 0, reason := "") {
    global GDHO_READY, GDHO_VISIBLE, g_GDHO_OpenPayload, g_GDHO_WaitingReadyReveal, g_GDHO_CloseAfterReady, g_GDHO_TransitionCtx
    if (token && !GDHO_IsCurrentToken(token))
        return false
    if !GDHO_READY {
        g_GDHO_WaitingReadyReveal := true
        try GDHO_Trace("gdho_reveal_wait_ready reason=" . reason . " token=" . token)
        return false
    }
    g_GDHO_WaitingReadyReveal := false
    g_GDHO_TransitionCtx["allow"] := true
    try GDHO_Show(g_GDHO_OpenPayload)
    finally g_GDHO_TransitionCtx["allow"] := false
    if GDHO_VISIBLE
        GDHO_SetPhase(GDHO_PHASE_OPEN, "ready_reveal_" . reason)
    if g_GDHO_CloseAfterReady {
        g_GDHO_CloseAfterReady := false
        GDHO_SubmitIntent("CLOSE", 15, Map("reason", "close_after_ready"))
    }
    return GDHO_VISIBLE
}

GDHO_InternalClose(reason := "", token := 0) {
    global g_GDHO_TransitionCtx
    if (token && !GDHO_IsCurrentToken(token))
        return
    g_GDHO_TransitionCtx["allow"] := true
    try {
        GDHO_HideFrontend()
        GDHO_HideOverlay()
    } finally {
        g_GDHO_TransitionCtx["allow"] := false
    }
}

GDHO_ForceReset(reason := "") {
    global GDHO_VISIBLE, GDHO_ACTIVE, GDHO_READY, GDHO_INTERACTIVE, GDHO_CLICKTHROUGH, GDHO_FIRST_REVEAL_DONE, GDHO_ERROR
    global GDHO_FRONTEND_PENDING_JS, g_GDHO_FrontendQueue, g_GDHO_WaitingReadyReveal, g_GDHO_CloseAfterReady
    global GDHO_RELEASE_PENDING, GDHO_RELEASE_DEADLINE_TICK, GDHO_IS_SUCKING, GDHO_EXPANDED_HOLD, NativeDropSessionActive
    global g_GDHO_CreateInFlight, g_GDHO_CreateStartTick
    try GDHO_Trace("gdho_force_reset reason=" . reason)
    GDHO_FRONTEND_PENDING_JS := ""
    g_GDHO_FrontendQueue := []
    g_GDHO_WaitingReadyReveal := false
    g_GDHO_CloseAfterReady := false
    g_GDHO_CreateInFlight := false
    g_GDHO_CreateStartTick := 0
    GDHO_RELEASE_PENDING := false
    GDHO_RELEASE_DEADLINE_TICK := 0
    GDHO_IS_SUCKING := false
    GDHO_EXPANDED_HOLD := false
    NativeDropSessionActive := false
    GDHO_ACTIVE := false
    GDHO_INTERACTIVE := false
    GDHO_READY := false
    GDHO_VISIBLE := false
    GDHO_ERROR := false
    GDHO_FIRST_REVEAL_DONE := false
    try GDHO_SetClickThrough(true)
    catch {
    }
    try GDHO_ParkOverlay()
    catch {
    }
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
        GDHO_RequestClose("apply_settings_mode_switch")
        GDHO_ResetPointerSeed()
        ; If user is still holding mouse while switching mode, wait until release.
        GDHO_SUPPRESS_UNTIL_RELEASE := GetKeyState("LButton", "P")
    }
}

GDHO_Init() {
    global GDHO_GUI, GDHO_WV2_CTRL, GDHO_WV2, GDHO_READY
    global GDHO_VISIBLE, GDHO_SLEEPING, GDHO_INTERACTIVE, GDHO_LAST_PROXIMITY_SENT
    global g_GDHO_TransitionCtx, g_GDHO_CreateInFlight, g_GDHO_CreateStartTick, g_GDHO_CreateToken

    if !(g_GDHO_TransitionCtx is Map) || !g_GDHO_TransitionCtx["allow"] {
        try GDHO_Trace("gdho_redirect_init")
        GDHO_RequestOpen(Map("reason", "init_redirect", "payload", GDHO_PAYLOAD))
        return
    }
    if (GDHO_GUI || g_GDHO_CreateInFlight)
        return

    GDHO_Trace("init begin")

    GDHO_CreateOverlayGui()
    GDHO_WV2_CTRL := 0
    GDHO_WV2 := 0
    GDHO_READY := false
    GDHO_PREWARM_DONE := false
    GDHO_FIRST_REVEAL_DONE := false
    GDHO_VISIBLE := false
    GDHO_SLEEPING := true
    GDHO_INTERACTIVE := false
    GDHO_LAST_PROXIMITY_SENT := -1.0
    g_GDHO_CreateInFlight := true
    g_GDHO_CreateStartTick := A_TickCount
    g_GDHO_CreateToken := g_GDHO_CurrentToken
    try WebView2_CreateWithSharedEnvAsync(GDHO_GUI.Hwnd, GDHO_OnWebViewCreated, "global_drag_hole")
}

GDHO_CreateOverlayGui() {
    global GDHO_GUI, GDHO_DIAG_CTRL
    OnMessage(GDHO_FRONTEND_POST_MSG, GDHO_OnFrontendPostMessage)
    GDHO_ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    hostW := Integer(GDHO_HOST_W), hostH := Integer(GDHO_HOST_H)
    if (hostW < 260)
        hostW := 260
    if (hostH < 220)
        hostH := 220
    x := -9999, y := -9999
    ; WS_EX_LAYERED + WS_EX_NOACTIVATE + WS_EX_TRANSPARENT.
    ; The host is always shown NoActivate and parked offscreen until needed.
    GDHO_GUI := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08080020", "Global Drag Hole Overlay")
    GDHO_DIAG_CTRL := GDHO_GUI.AddText("Hidden x6 y6 w340 h44 BackgroundTrans c66FF66", "")
    ; Use dedicated chroma key to keep host transparent before first WebView paint.
    GDHO_GUI.BackColor := "010101"
    ; Click-through + no activate overlay host.
    GDHO_GUI.Show("x" x " y" y " w" hostW " h" hostH " NoActivate")
    ; Keep window normal opacity; transparency comes from chroma-key immediately.
    try WinSetTransparent(255, "ahk_id " GDHO_GUI.Hwnd)
    try WinSetTransColor("010101", "ahk_id " GDHO_GUI.Hwnd)
    GDHO_SetClickThrough(true)
}

GDHO_DIAG_LOG(msg, elapsedMs := "") {
    global GDHO_DIAG_CTRL, GDHO_DIAG_VISIBLE
    if !IsObject(GDHO_DIAG_CTRL)
        return
    ; Runtime diagnostics should not leak into the drag overlay UI.
    GDHO_DIAG_CTRL.Visible := false
    GDHO_DIAG_VISIBLE := false
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

GDHO_SetSleepMode(enable := true) {
    global GDHO_SLEEPING
    GDHO_SLEEPING := !!enable
    GDHO_RunJS("window.HoleOverlay?.setSleepMode?.(" . (GDHO_SLEEPING ? "true" : "false") . ")")
}

GDHO_ParkOverlay() {
    global GDHO_GUI, GDHO_HOST_W, GDHO_HOST_H, GDHO_PARK_X, GDHO_PARK_Y
    global GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y, GDHO_INTERACTIVE
    if !GDHO_GUI
        return
    GDHO_INTERACTIVE := false
    GDHO_LAST_HOST_X := Integer(GDHO_PARK_X)
    GDHO_LAST_HOST_Y := Integer(GDHO_PARK_Y)
    GDHO_SetClickThrough(true)
    try WinSetAlwaysOnTop(0, "ahk_id " GDHO_GUI.Hwnd)
    try GDHO_GUI.Move(Integer(GDHO_PARK_X), Integer(GDHO_PARK_Y), Integer(GDHO_HOST_W), Integer(GDHO_HOST_H))
}

GDHO_SetProximity(prox) {
    global GDHO_LAST_PROXIMITY_SENT
    p := Max(0.0, Min(1.0, Float(prox)))
    if (GDHO_LAST_PROXIMITY_SENT >= 0 && Abs(p - GDHO_LAST_PROXIMITY_SENT) < 0.025)
        return
    GDHO_LAST_PROXIMITY_SENT := p
    GDHO_RunJS("window.HoleOverlay?.setProximity?.(" . Format("{:.3f}", p) . ")")
}

GDHO_OnWebViewCreated(ctrl) {
    global GDHO_WV2_CTRL, GDHO_WV2, GDHO_READY, GDHO_PAGE_URL, GDHO_NAV_FAIL_COUNT
    global g_GDHO_CreateInFlight, g_GDHO_CreateStartTick, g_GDHO_CreateToken

    if !GDHO_IsCurrentToken(g_GDHO_CreateToken) {
        try GDHO_Trace("gdho_webview_create_drop_stale token=" . g_GDHO_CreateToken)
        return
    }
    g_GDHO_CreateInFlight := false
    g_GDHO_CreateStartTick := 0
    if !IsObject(ctrl) || !ctrl.HasProp("CoreWebView2") {
        try GDHO_Trace("gdho_webview_create_failed")
        GDHO_SubmitIntent("FORCE_RESET", 5, Map("reason", "webview_create_failed"))
        return
    }

    GDHO_Trace("webview_created begin")
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
    global GDHO_DROP_ACK_TICK, GDHO_IS_SUCKING, GDHO_EXPANDED_HOLD
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
        GDHO_Trace("webmsg hole_drop_ack")
        try GDHO_RunJS("window.HoleOverlay?.setNativeState({ dispatch: 'ack:first_frame' })")
        return
    }
    if (typ = "hole_close") {
        GDHO_Trace("webmsg hole_close")
        GDHO_IS_SUCKING := false
        GDHO_EXPANDED_HOLD := false
        GDHO_RequestClose("frontend_hole_close")
        try GDHO_ResetSession()
        try GDHO_ArmPolling()
        NativeDropBridge_ResetSessionAsync("hole_close", 0)
        return
    }
    if (typ != "hole_drop")
        return
    if !msg.Has("payload") || !(msg["payload"] is Map)
        return
    GDHO_RequestClose("frontend_hole_drop")
    GDHO_HandleDropPayload(msg["payload"])
    try NativeDropBridge_ResetSessionAsync("hole_drop", 1)
}

GDHO_HandleDropPayload(payload) {
    global GDHO_LAST_DROPPED_TEXT, GDHO_SESSION_TEXT
    kind := payload.Has("kind") ? String(payload["kind"]) : "none"
    GDHO_Trace("handle_drop kind=" . kind)
    if (kind = "text") {
        txt := payload.Has("text") ? Trim(String(payload["text"])) : ""
        if (txt != "") {
            GDHO_LAST_DROPPED_TEXT := txt
            GDHO_SESSION_TEXT := txt
            try GDHO_RunJS("window.HoleOverlay?.setNativeState({ dispatch: 'text:captured' })")
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
    global GDHO_PAGE_URL
    global g_GDHO_CurrentToken
    ok := false
    try ok := args.IsSuccess
    GDHO_READY := !!ok
    failInfo := ""
    if !GDHO_READY {
        try failInfo .= " navErr=" . args.WebErrorStatus
        catch {
        }
        try failInfo .= " isSuccess=" . (args.IsSuccess ? "1" : "0")
        catch {
        }
        try failInfo .= " isHttp=" . (args.IsHttpStatusCodeSuccess ? "1" : "0")
        catch {
        }
        try failInfo .= " status=" . args.HttpStatusCode
        catch {
        }
        try failInfo .= " uri=" . args.Uri
        catch {
        }
        try failInfo .= " page=" . GDHO_PAGE_URL
        catch {
        }
        try failInfo .= " fallback=" . GDHO_FALLBACK_URL
        catch {
        }
    }
    GDHO_Trace("navigation_completed ok=" . (GDHO_READY ? "1" : "0") . failInfo)
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
            GDHO_QueueFrontendJs("window.HoleOverlay?.show('" p "')", g_GDHO_CurrentToken)
            SetTimer((*) => GDHO_QueueFrontendJs("window.HoleOverlay?.show('" p "')", g_GDHO_CurrentToken), -180)
        }
        GDHO_RevealIfReady(g_GDHO_CurrentToken, "nav_completed")
        return
    }

    GDHO_NAV_FAIL_COUNT += 1
    GDHO_Trace("navigation_retry count=" . GDHO_NAV_FAIL_COUNT . " fallback=" . (GDHO_FALLBACK_URL != "" ? "1" : "0"))
    if (GDHO_FALLBACK_URL != "" && GDHO_NAV_FAIL_COUNT <= 2) {
        GDHO_Trace("navigation_retry use_fallback")
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
    global GDHO_ACTIVE, NativeDropSessionActive
    ; Keep host parked; force one render pass unless the user is already interacting.
    if (GDHO_ACTIVE || NativeDropSessionActive)
        return
    GDHO_Trace("prewarm offscreen begin")
    GDHO_RunJS("(function(){var h=window.HoleOverlay;if(!h)return;window.__gdhoUserInteracting=false;h.setSleepMode&&h.setSleepMode(false);h.show&&h.show('text',{prewarm:true});h.update&&h.update({payload:'text',x:120,y:120,proximity:0.36,prewarm:true});setTimeout(function(){try{if(!(window.__gdhoUserInteracting)){h.hide&&h.hide();h.setSleepMode&&h.setSleepMode(true);}}catch(_e){}},90);})();")
    try GDHO_ParkOverlay()
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

GDHO_Trace(msg) {
    try NativeDropDiag_Log("gdho " . String(msg))
    catch {
        try OutputDebug("[GDHO] " . String(msg))
        catch {
        }
    }
}

GDHO_QueueFrontendJs(js, token := 0) {
    global GDHO_GUI, GDHO_FRONTEND_PENDING_JS, GDHO_FRONTEND_POST_MSG, g_GDHO_FrontendQueue, g_GDHO_CurrentToken
    if !GDHO_GUI
        return false
    GDHO_FRONTEND_PENDING_JS := String(js)
    if !(g_GDHO_FrontendQueue is Array)
        g_GDHO_FrontendQueue := []
    g_GDHO_FrontendQueue.Push(Map("token", token ? Integer(token) : Integer(g_GDHO_CurrentToken), "js", String(js)))
    try {
        PostMessage(GDHO_FRONTEND_POST_MSG, 1, 0, , "ahk_id " GDHO_GUI.Hwnd)
        return true
    } catch {
        return false
    }
}

GDHO_OnFrontendPostMessage(wParam, lParam, msg, hwnd) {
    global GDHO_FRONTEND_PENDING_JS, GDHO_GUI, GDHO_WV2, GDHO_READY, g_GDHO_FrontendQueue, g_GDHO_CurrentToken
    Critical "Off"
    if (wParam != 1)
        return 0
    js := GDHO_FRONTEND_PENDING_JS
    GDHO_FRONTEND_PENDING_JS := ""
    if (!GDHO_GUI)
        return 0
    queue := g_GDHO_FrontendQueue
    g_GDHO_FrontendQueue := []
    if !(queue is Array)
        return 0
    for _, item in queue {
        if !(item is Map)
            continue
        tok := item.Has("token") ? Integer(item["token"]) : 0
        if (tok && tok != g_GDHO_CurrentToken) {
            try GDHO_Trace("gdho_ready_drop_stale token=" . tok . " current=" . g_GDHO_CurrentToken)
            continue
        }
        if (GDHO_WV2 && GDHO_READY)
            GDHO_RunJS(String(item["js"]))
    }
    return 0
}

GDHO_ShowOverlay() {
    global GDHO_GUI, GDHO_VISIBLE, GDHO_WV2, GDHO_READY, GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y, GDHO_HOST_W, GDHO_HOST_H, GDHO_FIRST_REVEAL_DONE, GDHO_INTERACTIVE, GDHO_PAYLOAD
    global g_GDHO_CurrentToken
    global GDHO_CX, GDHO_CY
    if !GDHO_InternalCallAllowed() {
        try GDHO_Trace("gdho_redirect_show_overlay")
        GDHO_RequestOpen(Map("reason", "show_overlay_redirect", "payload", GDHO_PAYLOAD))
        return
    }
    if !GDHO_GUI
        return
    ; Avoid first-frame black flash: don't reveal host before WebView content is ready.
    if !GDHO_READY
        return
    if !GDHO_FIRST_REVEAL_DONE {
        GDHO_FIRST_REVEAL_DONE := true
        SetTimer((*) => GDHO_RevealIfReady(g_GDHO_CurrentToken, "first_reveal"), -16)
        return
    }
    if !GDHO_VISIBLE {
        GDHO_SetSleepMode(false)
        try WinSetAlwaysOnTop(1, "ahk_id " GDHO_GUI.Hwnd)
        try GDHO_GUI.Show("x" Integer(GDHO_LAST_HOST_X) " y" Integer(GDHO_LAST_HOST_Y) " w" Integer(GDHO_HOST_W) " h" Integer(GDHO_HOST_H) " NoActivate")
        GDHO_CX := Integer(GDHO_LAST_HOST_X) + 180
        GDHO_CY := Integer(GDHO_LAST_HOST_Y) + 159
        try WinSetTransColor("010101", "ahk_id " GDHO_GUI.Hwnd)
        ; Stay transparent until drag confidence/proximity promotes interaction.
        GDHO_INTERACTIVE := false
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
    global GDHO_GUI, GDHO_HOST_W, GDHO_HOST_H, GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y, GDHO_CX, GDHO_CY
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
    GDHO_CX := hx + 180
    GDHO_CY := hy + 159
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
    global GDHO_GUI, GDHO_VISIBLE, GDHO_WV2, GDHO_LAST_HIDE_OVERLAY_TICK, g_GDHO_WaitingReadyReveal
    if !GDHO_InternalCallAllowed() {
        try GDHO_Trace("gdho_redirect_hide_overlay")
        GDHO_RequestClose("hide_overlay_redirect")
        return
    }
    if !GDHO_GUI
        return
    nowTick := A_TickCount
    if (GDHO_LAST_HIDE_OVERLAY_TICK && (nowTick - GDHO_LAST_HIDE_OVERLAY_TICK < 120))
        return
    GDHO_LAST_HIDE_OVERLAY_TICK := nowTick
    GDHO_Trace("hide_overlay")
    try WebView2_NotifyHidden(GDHO_WV2)
    GDHO_ApplyDropHitTestByProximity(0.0)
    GDHO_SetProximity(0.0)
    GDHO_SetSleepMode(true)
    try GDHO_ParkOverlay()
    GDHO_VISIBLE := false
    g_GDHO_WaitingReadyReveal := false
}

GDHO_Hide() {
    if !GDHO_InternalCallAllowed() {
        try GDHO_Trace("gdho_redirect_hide")
        GDHO_RequestClose("hide_redirect")
        return
    }
    GDHO_HideFrontend()
    GDHO_HideOverlay()
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
    global GDHO_CURSOR_X, GDHO_CURSOR_Y, GDHO_POSITION_MODE, g_GDHO_CurrentToken
    if !GDHO_InternalCallAllowed() {
        try GDHO_Trace("gdho_redirect_show")
        openPayload := (payload is Map) ? payload : Map("reason", "show_redirect", "payload", payload)
        if (openPayload is Map) {
            if !openPayload.Has("reason")
                openPayload["reason"] := "show_redirect"
            if (x != "" && !openPayload.Has("screenX"))
                openPayload["screenX"] := x
            if (y != "" && !openPayload.Has("screenY"))
                openPayload["screenY"] := y
        }
        GDHO_RequestOpen(openPayload)
        return
    }
    payloadMap := 0
    if (payload is Map) {
        payloadMap := payload
        if payloadMap.Has("screenX")
            x := payloadMap["screenX"]
        if payloadMap.Has("screenY")
            y := payloadMap["screenY"]
        if payloadMap.Has("payload")
            payload := payloadMap["payload"]
    }
    p := (String(payload) = "text") ? "text" : "file"
    GDHO_Trace("show payload=" . p)
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
    if (GDHO_POSITION_MODE = "fixed")
        GDHO_AnchorHoleByScreen()
    else if (GDHO_POSITION_MODE = "relative") {
        GDHO_MoveHostToHole(Integer(GDHO_CURSOR_X - 90), Integer(GDHO_CURSOR_Y - 110))
        GDHO_RunJS("window.HoleOverlay?.moveTo({ x: 90, y: 56 })")
    }
    else
        GDHO_AnchorHoleUnderToolbar()
    GDHO_ShowOverlay()
    GDHO_SetSleepMode(false)
    GDHO_PushThemeToWeb()
    GDHO_QueueFrontendJs("window.HoleOverlay?.show('" p "', { forceAccept: true })", g_GDHO_CurrentToken)
    GDHO_QueueFrontendJs("window.HoleOverlay?.setStyle({ scale: " GDHO_SIZE_SCALE ", animLevel: " GDHO_ANIM_LEVEL ", visualStyle: '" GDHO_VISUAL_STYLE "' })", g_GDHO_CurrentToken)
}

GDHO_Update(payload := "file", x := "", y := "") {
    global GDHO_LAST_UPDATE_TICK, GDHO_UPDATE_MIN_INTERVAL_MS, GDHO_CURSOR_X, GDHO_CURSOR_Y, GDHO_POSITION_MODE
    global GDHO_LAST_X, GDHO_LAST_Y, GDHO_JUMP_LERP_THRESHOLD_PX, GDHO_GUI, GDHO_CLICKTHROUGH, GDHO_HITTEST_CAPTURED
    global GDHO_LAST_DIST_TO_HOLE, GDHO_SUCK_RADIUS, GDHO_IS_SUCKING
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
    prox := 0.10
    distToCenter := 99999.0
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
        distToCenter := GDHO_GetDistanceToHoleCenter(Integer(x), Integer(y))
        GDHO_LAST_DIST_TO_HOLE := distToCenter
        radius := Float(GDHO_SUCK_RADIUS)
        prox := Max(0.10, Min(1.0, 1.0 - (distToCenter / radius)))
        GDHO_RunJS("window.HoleOverlay?.update({ payload: '" p "', x: " Integer(lx) ", y: " Integer(ly) ", proximity: " Format("{:.3f}", prox) " })")
        if (!GetKeyState("LButton", "P") && !GDHO_IS_SUCKING && distToCenter <= Float(GDHO_SUCK_RADIUS)) {
            try NativeDropDiag_Log("[Physical_Suck_UpdateFallback] dist=" . Format("{:.1f}", distToCenter))
            GDHO_ForceSuckAction()
            SetTimer(GDHO_FinishSuckSession, -2000)
            return
        }
    }
    GDHO_SetProximity(prox)
    if (x != "" && y != "" && GDHO_GUI) {
        inInner := (distToCenter <= Float(GDHO_INNER_RADIUS))
        if (inInner && GDHO_CLICKTHROUGH) {
            try WinSetExStyle("-0x20", "ahk_id " GDHO_GUI.Hwnd)
            GDHO_CLICKTHROUGH := false
            GDHO_HITTEST_CAPTURED := true
        } else if (!inInner && !GDHO_CLICKTHROUGH) {
            try WinSetExStyle("+0x20", "ahk_id " GDHO_GUI.Hwnd)
            GDHO_CLICKTHROUGH := true
            GDHO_HITTEST_CAPTURED := false
        }
    }
    if !GDHO_HITTEST_CAPTURED
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
        try GDHO_RunJS("window.HoleOverlay?.setNativeState({ dispatch: 'text:" (txt != "" ? "captured" : "empty") "' })")
        GDHO_SESSION_TEXT := ""
        return
    }
    ; File-like drop path: attempt native explorer fallback immediately.
    try GDHO_TryHandleExplorerDrop()
    try GDHO_RunJS("window.HoleOverlay?.setNativeState({ dispatch: 'files:fallback' })")
}

GDHO_HideFrontend() {
    global GDHO_DESKTOP_PINNED, GDHO_PIN_PAYLOAD, GDHO_LAST_HIDE_FRONTEND_TICK, g_GDHO_CurrentToken
    if !GDHO_InternalCallAllowed() {
        try GDHO_Trace("gdho_redirect_hide_frontend")
        GDHO_RequestClose("hide_frontend_redirect")
        return
    }
    nowTick := A_TickCount
    if (GDHO_LAST_HIDE_FRONTEND_TICK && (nowTick - GDHO_LAST_HIDE_FRONTEND_TICK < 120))
        return
    GDHO_LAST_HIDE_FRONTEND_TICK := nowTick
    if GDHO_DESKTOP_PINNED {
        p := (GDHO_PIN_PAYLOAD = "file") ? "file" : "text"
        GDHO_Trace("hide_frontend pinned show payload=" . p)
        GDHO_QueueFrontendJs("window.HoleOverlay?.show('" p "')", g_GDHO_CurrentToken)
        return
    }
    ; Do not call the bridge synchronously during teardown. Post the work to the GUI thread
    ; so tray/menu cleanup cannot hang on a slow or wedged WebView2 bridge.
    GDHO_Trace("hide_frontend queue hide")
    GDHO_QueueFrontendJs("window.HoleOverlay?.hide()", g_GDHO_CurrentToken)
}

GDHO_Start() {
    global GDHO_MONITORING, GDHO_PRIORITY_APPLIED, g_GDHO_TransitionCtx
    try NativeDropDiag_Log("gdho start begin")
    g_GDHO_TransitionCtx["allow"] := true
    try GDHO_Init()
    finally g_GDHO_TransitionCtx["allow"] := false
    if !GDHO_PRIORITY_APPLIED {
        try ProcessSetPriority("Normal")
        try DllCall("SetThreadPriority", "Ptr", DllCall("GetCurrentThread", "Ptr"), "Int", 0)
        GDHO_PRIORITY_APPLIED := true
    }
    ; Text drags can be blocked before WebView/native Drop sees them, so keep the
    ; lightweight physical poller armed while hole mode is enabled.
    try GDHO_PrewarmOffscreen()
    catch {
    }
    GDHO_ArmPolling()
    try NativeDropDiag_Log("gdho start poll_armed")
}

GDHO_ArmPolling() {
    global GDHO_MONITORING, GDHO_POLL_MS
    if GDHO_MONITORING
        return
    GDHO_MONITORING := true
    SetTimer(GDHO_PollDrag, GDHO_POLL_MS)
    try NativeDropDiag_Log("gdho poll armed poll_ms=" . Integer(GDHO_POLL_MS))
}

GDHO_DisarmPolling(reason := "") {
    global GDHO_MONITORING, GDHO_ACTIVE
    if !GDHO_MONITORING {
        if (reason != "")
            try NativeDropDiag_Log("gdho poll disarm skip reason=" . reason)
        return
    }
    GDHO_MONITORING := false
    GDHO_ACTIVE := false
    SetTimer(GDHO_PollDrag, 0)
    if (reason != "")
        try NativeDropDiag_Log("gdho poll disarmed reason=" . reason)
}

GDHO_Stop() {
    global GDHO_MONITORING, GDHO_ACTIVE, g_GDHO_TransitionCtx, g_GDHO_CurrentToken
    try NativeDropDiag_Log("gdho stop begin")
    GDHO_DisarmPolling("stop")
    g_GDHO_CurrentToken += 1
    GDHO_SetPhase(GDHO_PHASE_CLOSING, "stop")
    g_GDHO_TransitionCtx["allow"] := true
    try {
        GDHO_HideFrontend()
        GDHO_HideOverlay()
    } finally g_GDHO_TransitionCtx["allow"] := false
    GDHO_SetPhase(GDHO_PHASE_CLOSED, "stop_done")
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

GDHO_IsPointInInnerHoleRadius(mx, my) {
    global GDHO_CX, GDHO_CY, GDHO_INNER_RADIUS
    cx := Integer(GDHO_CX)
    cy := Integer(GDHO_CY)
    if (cx = 0 && cy = 0) {
        ; Fallback to current host geometry center approximation.
        global GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y
        cx := Integer(GDHO_LAST_HOST_X) + 90 + 90
        cy := Integer(GDHO_LAST_HOST_Y) + 56 + 103
    }
    r := Float(GDHO_INNER_RADIUS)
    dx := Float(mx) - Float(cx)
    dy := Float(my) - Float(cy)
    return ((dx * dx + dy * dy) < (r * r))
}

GDHO_GetDistanceToHoleCenter(mx, my) {
    global GDHO_CX, GDHO_CY, GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y
    cx := Integer(GDHO_CX)
    cy := Integer(GDHO_CY)
    if (cx = 0 && cy = 0) {
        cx := Integer(GDHO_LAST_HOST_X) + 90 + 90
        cy := Integer(GDHO_LAST_HOST_Y) + 56 + 103
    }
    dx := Float(mx) - Float(cx)
    dy := Float(my) - Float(cy)
    return Sqrt(dx * dx + dy * dy)
}

GDHO_HandleDropAction() {
    global GDHO_PAYLOAD, GDHO_DROP_LOCK
    GDHO_DROP_LOCK := true
    try GDHO_RunJS("window.HoleOverlay?.drop({payload: '" GDHO_PAYLOAD "'})")
    ; Keep drop animation responsive before any native fallback collection.
    SetTimer((*) => GDHO_TryHandleExplorerDrop(), -80)
    try NativeDropDiag_Log("[Drop_Sent] target=hole_starry payload=" . GDHO_PAYLOAD)
}

GDHO_ForceSuckAction() {
    global GDHO_PAYLOAD, GDHO_DROP_LOCK, GDHO_SESSION_TEXT
    global GDHO_IS_SUCKING, GDHO_EXPANDED_HOLD, GDHO_GUI, GDHO_CLICKTHROUGH, GDHO_HITTEST_CAPTURED, GDHO_SESSION_CAPTURE_TICKET
    if (GDHO_IS_SUCKING)
        return
    GDHO_IS_SUCKING := true
    GDHO_EXPANDED_HOLD := true
    GDHO_DROP_LOCK := true
    try NativeDropDiag_Log("[Physical_Suck_Triggered] payload=" . GDHO_PAYLOAD)
    if (GDHO_GUI) {
        try WinSetExStyle("-0x20", "ahk_id " GDHO_GUI.Hwnd)
        GDHO_CLICKTHROUGH := false
        GDHO_HITTEST_CAPTURED := true
    }
    try GDHO_RunJS("window.HoleOverlay?.drop({payload: '" GDHO_PAYLOAD "'})")
    if (GDHO_PAYLOAD = "text") {
        try A_Clipboard := ""
        try Send("^c")
        GDHO_SESSION_CAPTURE_TICKET += 1
        ticket := GDHO_SESSION_CAPTURE_TICKET
        try GDHO_RunJS("window.HoleOverlay?.setNativeState({ dispatch: 'text:pending' })")
        SetTimer((*) => GDHO_CompleteSessionTextCapture(ticket), -90)
    } else {
        try GDHO_TryHandleExplorerDrop()
    }
}

GDHO_CompleteSessionTextCapture(ticket, *) {
    global GDHO_SESSION_CAPTURE_TICKET, GDHO_SESSION_TEXT
    if (ticket != GDHO_SESSION_CAPTURE_TICKET)
        return
    try GDHO_SESSION_TEXT := Trim(String(A_Clipboard))
    catch {
        GDHO_SESSION_TEXT := ""
    }
    try GDHO_RunJS("window.HoleOverlay?.setNativeState({ dispatch: 'text:" (GDHO_SESSION_TEXT != "" ? "captured" : "empty") "' })")
}

GDHO_FinishSuckSession(*) {
    global GDHO_IS_SUCKING
    GDHO_IS_SUCKING := false
    GDHO_ResetSession()
}

GDHO_ResetSession(*) {
    global GDHO_ACTIVE, NativeDropSessionActive, GDHO_DROP_LOCK, GDHO_HITTEST_CAPTURED
    global GDHO_RELEASE_PENDING, GDHO_RELEASE_DEADLINE_TICK, GDHO_SAW_DRAG_CURSOR, GDHO_DRAG_CURSOR_STREAK
    global GDHO_SESSION_TEXT, GDHO_SUPPRESS_UNTIL_RELEASE, GDHO_IS_SUCKING, GDHO_EXPANDED_HOLD
    if (GDHO_IS_SUCKING)
        return
    if (GDHO_EXPANDED_HOLD) {
        GDHO_ACTIVE := false
        NativeDropSessionActive := false
        GDHO_DROP_LOCK := false
        GDHO_HITTEST_CAPTURED := true
        GDHO_RELEASE_PENDING := false
        GDHO_RELEASE_DEADLINE_TICK := 0
        GDHO_SAW_DRAG_CURSOR := false
        GDHO_DRAG_CURSOR_STREAK := 0
        GDHO_SESSION_TEXT := ""
        GDHO_SUPPRESS_UNTIL_RELEASE := false
        GDHO_ResetPointerSeed()
        return
    }
    GDHO_DROP_LOCK := false
    GDHO_HITTEST_CAPTURED := false
    GDHO_ACTIVE := false
    NativeDropSessionActive := false
    GDHO_RELEASE_PENDING := false
    GDHO_RELEASE_DEADLINE_TICK := 0
    GDHO_SAW_DRAG_CURSOR := false
    GDHO_DRAG_CURSOR_STREAK := 0
    GDHO_SESSION_TEXT := ""
    GDHO_SUPPRESS_UNTIL_RELEASE := false
    GDHO_ResetPointerSeed()
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
    global GDHO_DESKTOP_PINNED, GDHO_PIN_PAYLOAD, GDHO_ACTIVE, GDHO_SCREEN_X, GDHO_SCREEN_Y
    p := (payload = "file") ? "file" : "text"
    GDHO_PIN_PAYLOAD := p
    GDHO_DESKTOP_PINNED := true
    GDHO_ACTIVE := false
    GDHO_RequestOpen(Map("reason", "desktop_pin", "payload", p, "positionMode", "fixed", "screenX", GDHO_SCREEN_X, "screenY", GDHO_SCREEN_Y))
}

GDHO_UnpinFromDesktop() {
    global GDHO_DESKTOP_PINNED
    GDHO_DESKTOP_PINNED := false
    GDHO_RequestClose("desktop_unpin")
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
    global GDHO_DROP_LOCK, GDHO_IS_SUCKING, GDHO_EXPANDED_HOLD, GDHO_LAST_DIST_TO_HOLE, GDHO_INNER_RADIUS, GDHO_SUCK_RADIUS
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

        if (GDHO_EXPANDED_HOLD) {
            if !lDown
                return
            if !GDHO_IsPointInHole(mx, my, 40) {
                GDHO_EXPANDED_HOLD := false
                GDHO_IS_SUCKING := false
                GDHO_RequestClose("expanded_hold_exit")
                GDHO_ResetSession()
                return
            }
            return
        }

        ; Mouse-up over the WebView can report our overlay as the hwnd. Treat physical release
        ; as the highest-priority signal before own-window feedback guards can hide the hole.
        if !lDown {
            try FloatingToolbar_EndDrag()
            GDHO_SUPPRESS_UNTIL_RELEASE := false
            GDHO_DRAG_CONFIDENCE := 0.0
            GDHO_DRAG_CURSOR_STREAK := 0
            distNow := GDHO_GetDistanceToHoleCenter(mx, my)
            inSuckZone := (distNow <= Float(GDHO_SUCK_RADIUS) || GDHO_LAST_DIST_TO_HOLE <= Float(GDHO_SUCK_RADIUS))
            if ((GDHO_ACTIVE || NativeDropSessionActive) && inSuckZone) {
                try NativeDropDiag_Log("[Physical_Suck_Release] dist=" . Format("{:.1f}", distNow) . " lastDist=" . Format("{:.1f}", GDHO_LAST_DIST_TO_HOLE))
                GDHO_ForceSuckAction()
                SetTimer(GDHO_FinishSuckSession, -2000)
                return
            }
            if (GDHO_ACTIVE || NativeDropSessionActive) {
                GDHO_RequestClose("drag_release")
                GDHO_ResetSession()
                return
            } else if (A_TickCount - GDHO_LAST_UPDATE_TICK > GDHO_MAX_IDLE_HIDE_MS) {
                GDHO_RequestClose("drag_idle_timeout")
            }
            GDHO_ResetSession()
            return
        }

        ; Hard guard: dragging/operating toolbar must never trigger hole logic.
        if (IsSet(FloatingToolbarDragging) && FloatingToolbarDragging) {
            GDHO_SUPPRESS_UNTIL_RELEASE := true
            GDHO_ACTIVE := false
            GDHO_RequestClose("toolbar_dragging")
            GDHO_ResetPointerSeed()
            return
        }
        if isOwn {
            GDHO_SUPPRESS_UNTIL_RELEASE := true
            GDHO_ACTIVE := false
            GDHO_RequestClose("own_window_guard")
            GDHO_ResetPointerSeed()
            return
        }
        if isOwnProc {
            GDHO_SUPPRESS_UNTIL_RELEASE := true
            GDHO_ACTIVE := false
            GDHO_RequestClose("own_process_guard")
            GDHO_ResetPointerSeed()
            return
        }
        if GDHO_IsPointInToolbar(mx, my) {
            GDHO_SUPPRESS_UNTIL_RELEASE := true
            GDHO_ACTIVE := false
            GDHO_RequestClose("toolbar_guard")
            GDHO_ResetPointerSeed()
            return
        }

        if GDHO_DROP_LOCK
            return

        if GDHO_SUPPRESS_UNTIL_RELEASE {
            GDHO_RequestClose("suppress_until_release")
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
        if (GDHO_STRICT_MODE && !GDHO_IsStrictDragQualified(GDHO_DRAG_SOURCE_CLASS, GDHO_DRAG_CURSOR_STREAK, cName, GDHO_START_CURSOR, GDHO_PAYLOAD))
            return

        distToTb := GDHO_DistanceToToolbar(mx, my)
        limit := GDHO_ACTIVE ? GDHO_TOOLBAR_DISMISS_RADIUS_PX : GDHO_TOOLBAR_NEAR_RADIUS_PX
        if (GDHO_PAYLOAD != "text" && distToTb > limit) {
            GDHO_RequestClose("toolbar_distance_guard")
            GDHO_ACTIVE := false
            GDHO_SUPPRESS_UNTIL_RELEASE := true
            return
        }

        ; If drag already seeded from external window, keep updating even when cursor passes over toolbar.
        if !GDHO_ACTIVE {
            GDHO_RequestOpen(Map("reason", "drag_activate", "payload", GDHO_PAYLOAD, "screenX", mx, "screenY", my, "positionMode", GDHO_POSITION_MODE))
            GDHO_ACTIVE := true
            NativeDropSessionActive := true
            GDHO_ArmPolling()
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
    global GDHO_GUI, GDHO_ACTIVE, GDHO_CLICKTHROUGH, GDHO_DRAG_CONFIDENCE, GDHO_INTERACTIVE, NativeDropSessionActive
    if !GDHO_GUI
        return
    prox := Max(0.0, Min(1.0, Float(p)))
    sessionActive := (GDHO_ACTIVE || NativeDropSessionActive)
    if (sessionActive && GDHO_DRAG_CONFIDENCE >= 0.85 && prox >= 0.88) {
        try WinSetExStyle("-0x20", "ahk_id " GDHO_GUI.Hwnd)
        GDHO_CLICKTHROUGH := false
        GDHO_INTERACTIVE := true
        return
    }
    if (!sessionActive || prox < 0.82 || GDHO_DRAG_CONFIDENCE < 0.85) {
        try WinSetExStyle("+0x20", "ahk_id " GDHO_GUI.Hwnd)
        GDHO_CLICKTHROUGH := true
        GDHO_INTERACTIVE := false
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

GDHO_IsStrictDragQualified(srcClass, cursorStreak, currentCursorName, startCursor, payload := "file") {
    ; Strict mode goal:
    ; 1) Ordinary mouse pass should not light up the hole.
    ; 2) Require explicit drag-cursor evidence (continuous frames).
    ; Text drag (browser/edit) often keeps standard cursor names while handle changes.
    ; Accept it when cursor handle differs from press seed.
    if ((srcClass = "Chrome_WidgetWin_1" || srcClass = "Edit" || srcClass = "Chrome_RenderWidgetHostHWND"
        || srcClass = "MozillaWindowClass" || srcClass = "Notepad" || srcClass = "RichEditD2DPT")
        && startCursor != 0
        && (startCursor != GDHO_GetCursorHandle() || cursorStreak >= 1))
        return true
    ; Physical text drag fallback: if source is inferred text payload, do not require drag-cursor streak.
    if (payload = "text" && startCursor != 0)
        return true
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

    ; Browser/Edit text drag: selection drags often keep a standard cursor, so allow it earlier.
    if ((srcClass = "Chrome_WidgetWin_1" || srcClass = "Edit" || srcClass = "Chrome_RenderWidgetHostHWND"
        || srcClass = "MozillaWindowClass" || srcClass = "Notepad" || srcClass = "RichEditD2DPT") && startCursor != 0) {
        GDHO_DRAG_CONFIDENCE := (cNow != startCursor) ? 0.95 : 0.88
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
    if (srcClass = "Chrome_WidgetWin_1" || srcClass = "Edit" || srcClass = "Chrome_RenderWidgetHostHWND"
        || srcClass = "MozillaWindowClass" || srcClass = "Notepad" || srcClass = "RichEditD2DPT")
        return "text"
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




