#Requires AutoHotkey v2.0

#Include GDHO_P0Messenger.ahk

; De-coupled multi-window topology: starry ghost + interactive panel HUD.
; User flow: docs/TEXT_HOLE_FLOW.md — selection → weak_preview → commit → panel_open → dismiss.

global GDHO_DECOUPLED_TOPOLOGY := true
global GDHO_STAR_FULLSCREEN := false
global GDHO_PANEL_PINNED := false
global GDHO_STAR_GUI := 0
global GDHO_PANEL_GUI := 0
global GDHO_WV2_CTRL_STAR := 0
global GDHO_WV2_CTRL_PANEL := 0
global GDHO_WV2_STAR := 0
global GDHO_WV2_PANEL := 0
global GDHO_STAR_READY := false
global GDHO_PANEL_READY := false
global GDHO_PANEL_VISIBLE := false
global GDHO_PANEL_PAGE_URL := ""
global GDHO_PANEL_FALLBACK_URL := ""
global GDHO_PANEL_W := 560
global GDHO_PANEL_H := 580
global GDHO_PANEL_LAST_X := 24
global GDHO_PANEL_LAST_Y := 24
global GDHO_WM_ACTIVATE := 0x6
global g_GDHO_PanelCreateInFlight := false
global g_GDHO_PanelCreateStartedTick := 0
global g_GDHO_StarryCreateInFlight := false
global g_GDHO_PanelDeactivatePending := false
global g_GDHO_TextDragHandoffDone := false
global g_GDHO_PostSuckPanelPending := false
global g_GDHO_PostSuckTimerArmed := false
global g_GDHO_PendingPanelText := ""
global g_GDHO_PostSuckProtectUntil := 0
global g_GDHO_TextHoleCommitDone := false
global g_GDHO_TextHoleProxPollArmed := false
global g_GDHO_TextHoleProxWasOutside := true
global g_GDHO_TextHoleProxInsideSince := 0
global GDHO_TEXT_HOLE_OPEN_RADIUS_PX := 108
global GDHO_TEXT_HOLE_PROX_DEBOUNCE_MS := 100
global g_GDHO_TextHoleProxNeedsReenter := false
global g_GDHO_PanelHoldUntil := 0
global g_GDHO_TextHolePanelOpen := false
global g_GDHO_TextHoleAwaitingExpand := false
global g_GDHO_TextHoleCapturedText := ""
global g_GDHO_TextHoleStickyPanel := false
global g_GDHO_PostSuckPresentDone := false
global g_GDHO_TextHoleSessionSerial := 0
global g_GDHO_TextHoleCommitSerial := 0
global g_GDHO_TextHoleAbortOutsideSince := 0
global g_GDHO_TextHoleCommitTick := 0
global GDHO_TEXT_HOLE_EXPAND_MS := 1250
global GDHO_TEXT_HOLE_ABORT_GRACE_MS := 1500
global g_GDHO_SuppressSelectionAutoHide := false
global g_GDHO_GestureOpenGraceUntil := 0
global GDHO_TEXT_HOLE_STATE_IDLE := "idle"
global GDHO_TEXT_HOLE_STATE_PREVIEW := "preview"
global GDHO_TEXT_HOLE_STATE_ARMED := "armed"
global GDHO_TEXT_HOLE_STATE_COMMITTED := "committed"
global GDHO_TEXT_HOLE_STATE_EXPANDING := "expanding"
global GDHO_TEXT_HOLE_STATE_PANEL_SHOWN := "panel_shown"
global GDHO_TEXT_HOLE_STATE_CLOSED := "closed"
global g_GDHO_TextHoleState := GDHO_TEXT_HOLE_STATE_IDLE
global g_GDHO_TextHolePresentedSessionId := 0
global g_GDHO_TextHoleFallbackSessionId := 0
global g_GDHO_TextHoleExpandCompleteSessionId := 0
global g_GDHO_TextHoleFastPresentSid := 0
global g_GDHO_TextHoleFastPresentText := ""
global g_GDHO_TextHoleFastPresentX := 0
global g_GDHO_TextHoleFastPresentY := 0
global g_GDHO_LastOnScreenHoleCx := 0
global g_GDHO_LastOnScreenHoleCy := 0
global g_GDHO_PendingPanelShow := false
global g_GDHO_PendingPanelShowReason := ""
global g_GDHO_PendingPanelShowSince := 0
global g_GDHO_PanelUserDragging := false
global g_GDHO_PanelDragGraceUntil := 0
global g_GDHO_PanelDragBaseW := 0
global g_GDHO_PanelDragBaseH := 0
global g_GDHO_PanelDragInProgress := false
global g_GDHO_PanelLastMoveTick := 0
global g_GDHO_TextHolePanelLocked := false
global g_GDHO_UserTextHolePanelEngaged := false
global g_GDHO_TextHolePresentRetryArmed := false
global g_GDHO_PendingStarryLauncherShow := false
global g_GDHO_StarryLauncherOpen := false
global GDHO_LAUNCHER_GUI := 0
global GDHO_WV2_CTRL_LAUNCHER := 0
global GDHO_WV2_LAUNCHER := 0
global GDHO_LAUNCHER_READY := false
global GDHO_LAUNCHER_VISIBLE := false
global GDHO_LAUNCHER_W := 450
global GDHO_LAUNCHER_H := 450
global g_GDHO_LauncherLastShowTick := 0
global g_GDHO_LauncherGridSent := false
global GDHO_LAUNCHER_PAGE_URL := ""
global GDHO_LAUNCHER_FALLBACK_URL := ""
global g_GDHO_LauncherCreateInFlight := false
global g_GDHO_PendingLauncherShow := false
global g_GDHO_LauncherCmdInFlightUntil := 0
global g_GDHO_P2_LastPolicyTick := 0
global g_GDHO_P2_ExpandEnsureReason := ""
global GDHO_PHASE_IDLE := "idle"
global GDHO_PHASE_WEAK_PREVIEW := "weak_preview"
global GDHO_PHASE_COMMITTING := "committing"
global GDHO_PHASE_PANEL_OPEN := "panel_open"
global GDHO_PHASE_CLOSING := "closing"
global g_GDHO_InteractionPhase := GDHO_PHASE_IDLE

; --- Central interaction phase (see docs/TEXT_HOLE_FLOW.md) ---
GDHO_GetInteractionPhase() {
    global g_GDHO_TextHoleAwaitingExpand, g_GDHO_TextHoleState, g_GDHO_InteractionPhase
    global GDHO_TEXT_HOLE_STATE_PREVIEW, GDHO_TEXT_HOLE_STATE_ARMED, GDHO_TEXT_HOLE_STATE_COMMITTED
    global GDHO_TEXT_HOLE_STATE_EXPANDING, GDHO_TEXT_HOLE_STATE_PANEL_SHOWN
    if GDHO_IsTextHoleUserPanelActive()
        return GDHO_PHASE_PANEL_OPEN
    if (IsSet(GDHO_PANEL_VISIBLE) && GDHO_PANEL_VISIBLE && GDHO_IsTextHolePanelOpen())
        return GDHO_PHASE_PANEL_OPEN
    if g_GDHO_TextHoleAwaitingExpand
        return GDHO_PHASE_COMMITTING
    st := String(g_GDHO_TextHoleState)
    if (st = GDHO_TEXT_HOLE_STATE_COMMITTED || st = GDHO_TEXT_HOLE_STATE_EXPANDING)
        return GDHO_PHASE_COMMITTING
    if (st = GDHO_TEXT_HOLE_STATE_PANEL_SHOWN)
        return GDHO_PHASE_PANEL_OPEN
    if (st = GDHO_TEXT_HOLE_STATE_PREVIEW || st = GDHO_TEXT_HOLE_STATE_ARMED)
        return GDHO_PHASE_WEAK_PREVIEW
    if FuncExists("SelectionSense_IsSelectionHolePreviewActive") {
        try {
            if SelectionSense_IsSelectionHolePreviewActive()
                return GDHO_PHASE_WEAK_PREVIEW
        } catch {
        }
    }
    if (g_GDHO_InteractionPhase = GDHO_PHASE_CLOSING)
        return GDHO_PHASE_CLOSING
    return GDHO_PHASE_IDLE
}

GDHO_SetInteractionPhase(phase, reason := "") {
    global g_GDHO_InteractionPhase
    g_GDHO_InteractionPhase := String(phase)
    try NativeDropDiag_Log("[TextHole] phase=" . phase . " reason=" . String(reason)
        . " panel=" . (GDHO_IsTextHoleUserPanelActive() ? "1" : "0")
        . " awaiting=" . (IsSet(g_GDHO_TextHoleAwaitingExpand) && g_GDHO_TextHoleAwaitingExpand ? "1" : "0"))
}

GDHO_CanOpenWeakPreview() {
    if !GDHO_IsDecoupled()
        return true
    ph := GDHO_GetInteractionPhase()
    if (ph != GDHO_PHASE_IDLE)
        return false
    if GDHO_ShouldBlockStarryReentry()
        return false
    return true
}

GDHO_CanOpenGestureHole(reason := "") {
    global g_GDHO_GestureOpenGraceUntil, g_GDHO_TextHoleAwaitingExpand
    if !GDHO_IsDecoupled()
        return true
    if GDHO_IsTextHoleUserPanelActive()
        return false
    if (g_GDHO_GestureOpenGraceUntil > A_TickCount)
        return true
    if FuncExists("HoleActivation_IsGestureGraceActive") {
        try {
            if HoleActivation_IsGestureGraceActive()
                return true
        } catch {
        }
    }
    ph := GDHO_GetInteractionPhase()
    if (ph = GDHO_PHASE_PANEL_OPEN)
        return false
    if (ph = GDHO_PHASE_COMMITTING && !g_GDHO_TextHoleAwaitingExpand)
        return false
    return true
}

GDHO_ArmGestureOpenGrace(ms := 3200) {
    global g_GDHO_GestureOpenGraceUntil, g_GDHO_SuppressSelectionAutoHide
    g_GDHO_GestureOpenGraceUntil := A_TickCount + Max(800, Integer(ms))
    g_GDHO_SuppressSelectionAutoHide := true
    if FuncExists("HoleActivation_ArmGestureGrace") {
        try HoleActivation_ArmGestureGrace(ms)
        catch {
        }
    }
}

GDHO_IsGestureOpenGraceActive() {
    global g_GDHO_GestureOpenGraceUntil
    if (g_GDHO_GestureOpenGraceUntil > A_TickCount)
        return true
    if FuncExists("HoleActivation_IsGestureGraceActive") {
        try return HoleActivation_IsGestureGraceActive()
        catch {
        }
    }
    return false
}

; 画圈/长按唤起 A 启动层：不占划选弱预览会话，关闭后可立即再次手势唤起
GDHO_BeginGestureLauncherSession(ax, ay, reason := "gesture") {
    global GDHO_CURSOR_X, GDHO_CURSOR_Y, GDHO_EXPANDED_HOLD, GDHO_IS_SUCKING
    global g_GDHO_GestureOpenGraceUntil, g_GDHO_SuppressSelectionAutoHide
    ix := Integer(ax), iy := Integer(ay)
    g_GDHO_GestureOpenGraceUntil := A_TickCount + 700
    g_GDHO_SuppressSelectionAutoHide := false
    if FuncExists("HoleActivation_ClearGestureGrace") {
        try HoleActivation_ClearGestureGrace()
        catch {
        }
    }
    GDHO_CURSOR_X := ix
    GDHO_CURSOR_Y := iy
    GDHO_EXPANDED_HOLD := false
    GDHO_IS_SUCKING := false
    try GDHO_UpdateHoleCenterFromPolicy(ix, iy)
    catch {
    }
    if (GDHO_CX > 50 && GDHO_CY > 50) {
        try GDHO_RememberOnScreenHoleCenter(GDHO_CX, GDHO_CY)
        catch {
        }
    }
    try GDHO_SetInteractionPhase(GDHO_PHASE_IDLE, "gesture_launcher:" . String(reason))
    catch {
    }
    try NativeDropDiag_Log("[TextHole] gesture_launcher_session x=" . ix . " y=" . iy . " cx=" . GDHO_CX . " cy=" . GDHO_CY . " reason=" . String(reason))
    return true
}

GDHO_BeginGestureHoleSession(ax, ay, reason := "gesture") {
    global GDHO_CURSOR_X, GDHO_CURSOR_Y, g_GDHO_SuppressSelectionAutoHide
    global GDHO_EXPANDED_HOLD, GDHO_IS_SUCKING
    ix := Integer(ax), iy := Integer(ay)
    GDHO_ArmGestureOpenGrace(3200)
    GDHO_CURSOR_X := ix
    GDHO_CURSOR_Y := iy
    GDHO_EXPANDED_HOLD := false
    GDHO_IS_SUCKING := false
    if FuncExists("SelectionSense_ArmHoleGesturePreview") {
        try SelectionSense_ArmHoleGesturePreview(ix, iy)
        catch {
        }
    }
    try GDHO_UpdateHoleCenterFromPolicy(ix, iy)
    catch {
    }
    if (GDHO_CX > 50 && GDHO_CY > 50) {
        try GDHO_RememberOnScreenHoleCenter(GDHO_CX, GDHO_CY)
        catch {
        }
    }
    try GDHO_SetInteractionPhase(GDHO_PHASE_WEAK_PREVIEW, "gesture_begin:" . String(reason))
    catch {
    }
    if FuncExists("GDHO_TextHole_OnSelectionPreviewStart") {
        try GDHO_TextHole_OnSelectionPreviewStart("", ix, iy)
        catch {
        }
    }
    try NativeDropDiag_Log("[TextHole] gesture_session_begin x=" . ix . " y=" . iy . " cx=" . GDHO_CX . " cy=" . GDHO_CY . " reason=" . String(reason))
    return true
}

GDHO_CanCommitTextHole() {
    global g_GDHO_TextHoleAwaitingExpand
    if g_GDHO_TextHoleAwaitingExpand || GDHO_IsTextHoleUserPanelActive()
        return false
    return (GDHO_GetInteractionPhase() = GDHO_PHASE_WEAK_PREVIEW)
}

GDHO_ShouldDeferSelectionAutoHide() {
    global g_GDHO_SuppressSelectionAutoHide, g_GDHO_StarryLauncherOpen
    ph := GDHO_GetInteractionPhase()
    if (ph = GDHO_PHASE_COMMITTING || ph = GDHO_PHASE_PANEL_OPEN || ph = GDHO_PHASE_CLOSING)
        return true
    if GDHO_IsGestureOpenGraceActive()
        return true
    if g_GDHO_SuppressSelectionAutoHide
        return true
    if g_GDHO_StarryLauncherOpen
        return true
    if GDHO_IsTextHoleUserPanelActive()
        return true
    return false
}

GDHO_TraceInteraction(tag := "", reason := "") {
    ph := GDHO_GetInteractionPhase()
    sid := GDHO_TextHoleSessionId()
    pv := (IsSet(GDHO_PANEL_VISIBLE) && GDHO_PANEL_VISIBLE) ? "1" : "0"
    eng := GDHO_IsTextHoleUserPanelActive() ? "1" : "0"
    try GDHO_Trace("interaction tag=" . String(tag) . " phase=" . ph . " reason=" . String(reason) . " sid=" . sid . " panel=" . pv . " engaged=" . eng)
    catch {
        try NativeDropDiag_Log("[TextHole] interaction tag=" . String(tag) . " phase=" . ph . " reason=" . String(reason))
    }
}

GDHO_ResolvePanelPageUrl() {
    global GDHO_PANEL_PAGE_URL, GDHO_PANEL_FALLBACK_URL
    if (Trim(String(GDHO_PANEL_FALLBACK_URL)) != "")
        return Trim(String(GDHO_PANEL_FALLBACK_URL))
    u := Trim(String(GDHO_PANEL_PAGE_URL))
    if (InStr(u, "127.0.0.1:5173") || InStr(u, "localhost:5173"))
        u := ""
    if (u = "") && FileExist(A_ScriptDir . "\hole_panel.html") {
        if FuncExists("GDHO_BuildFileUrl")
            try u := GDHO_BuildFileUrl(A_ScriptDir . "\hole_panel.html")
        if (u = "")
            u := "file:///" . StrReplace(A_ScriptDir . "\hole_panel.html", "\", "/")
    }
    return u
}

GDHO_EnsureDecoupledPanelWebHost() {
    global GDHO_WV2_PANEL, GDHO_PANEL_READY, g_GDHO_PanelCreateInFlight, g_GDHO_PanelCreateStartedTick
    global GDHO_PANEL_GUI, GDHO_WV2_CTRL_PANEL
    if !GDHO_IsDecoupled()
        return GDHO_PANEL_READY
    if !IsObject(GDHO_PANEL_GUI)
        try GDHO_CreatePanelGui()
    if IsObject(GDHO_WV2_PANEL)
        return GDHO_PANEL_READY
    if g_GDHO_PanelCreateInFlight && !IsObject(GDHO_WV2_PANEL) && g_GDHO_PanelCreateStartedTick > 0
        && (A_TickCount - g_GDHO_PanelCreateStartedTick) > 4500 {
        g_GDHO_PanelCreateInFlight := false
        g_GDHO_PanelCreateStartedTick := 0
        try NativeDropDiag_Log("[TextHole] panel_create_stall_reset")
    }
    if !IsObject(GDHO_WV2_CTRL_PANEL) && !g_GDHO_PanelCreateInFlight && IsObject(GDHO_PANEL_GUI) {
        g_GDHO_PanelCreateInFlight := true
        g_GDHO_PanelCreateStartedTick := A_TickCount
        try NativeDropDiag_Log("[TextHole] panel_webview_create_begin hwnd=" . GDHO_PANEL_GUI.Hwnd)
        try WebView2_CreateWithSharedEnvAsync(GDHO_PANEL_GUI.Hwnd, GDHO_OnPanelWebViewCreated, "gdho_panel_ensure")
    }
    return false
}

GDHO_EnsurePanelWebWarm() {
    global GDHO_WV2_PANEL, GDHO_PANEL_READY, g_GDHO_PanelCreateInFlight, GDHO_PANEL_GUI, GDHO_WV2_CTRL_PANEL
    if GDHO_PANEL_READY
        return true
    url := GDHO_ResolvePanelPageUrl()
    if (url = "")
        return false
    GDHO_EnsureDecoupledPanelWebHost()
    if IsObject(GDHO_WV2_PANEL) {
        try GDHO_WV2_PANEL.Navigate(url)
        return false
    }
    return false
}

; P1 full_defer: 弱预览不创建面板宿主；commit/analyzing 才 CreatePanelGui + WebView2。
GDHO_EnsurePanelHostForPhase(phase := "") {
    global GDHO_PANEL_READY
    if !GDHO_IsDecoupled()
        return false
    p := StrLower(Trim(String(phase)))
    if (p = "" || p = "idle" || p = "weak_preview" || InStr(p, "weak_preview") || InStr(p, "selection_preview")) {
        try NativeDropDiag_Log("[TextHole] panel_host_defer phase=" . (p != "" ? p : "unspecified"))
        return false
    }
    if (p = "committing" || p = "analyzing" || InStr(p, "commit")) {
        if GDHO_IsStarryLauncherMode() {
            try NativeDropDiag_Log("[TextHole] panel_host_defer phase=" . p . " reason=starry_launcher")
            return false
        }
        try GDHO_CreatePanelGui()
        try GDHO_EnsureDecoupledPanelWebHost()
        try NativeDropDiag_Log("[TextHole] panel_host_warm phase=" . p)
        return GDHO_EnsurePanelWebWarm()
    }
    if (p = "panel_open" || p = "manual" || InStr(p, "manual")) {
        if !IsObject(GDHO_PANEL_GUI)
            try GDHO_CreatePanelGui()
        try GDHO_EnsureDecoupledPanelWebHost()
        if !GDHO_PANEL_READY
            try GDHO_EnsurePanelWebWarm()
        return !!GDHO_PANEL_READY
    }
    if (p = "resulting" || p = "panel" || InStr(p, "present")) {
        if GDHO_IsStarryLauncherMode() {
            try NativeDropDiag_Log("[TextHole] panel_host_defer phase=" . p . " reason=starry_launcher")
            return false
        }
        if !IsObject(GDHO_PANEL_GUI)
            try GDHO_CreatePanelGui()
        try GDHO_EnsureDecoupledPanelWebHost()
        if !GDHO_PANEL_READY
            try GDHO_EnsurePanelWebWarm()
        return !!GDHO_PANEL_READY
    }
    try NativeDropDiag_Log("[TextHole] panel_host_defer phase=" . p)
    return false
}

GDHO_TextHoleSessionId() {
    global g_GDHO_TextHoleSessionSerial
    return Integer(g_GDHO_TextHoleSessionSerial)
}

GDHO_TextHoleTransition(newState, reason := "", dist := "", txtLen := "") {
    global g_GDHO_TextHoleState, GDHO_TEXT_HOLE_STATE_PREVIEW, GDHO_TEXT_HOLE_STATE_ARMED
    global GDHO_TEXT_HOLE_STATE_COMMITTED, GDHO_TEXT_HOLE_STATE_EXPANDING, GDHO_TEXT_HOLE_STATE_PANEL_SHOWN
    global GDHO_TEXT_HOLE_STATE_CLOSED, GDHO_TEXT_HOLE_STATE_IDLE
    oldState := String(g_GDHO_TextHoleState)
    g_GDHO_TextHoleState := String(newState)
    ns := String(newState)
    if (ns = GDHO_TEXT_HOLE_STATE_PREVIEW || ns = GDHO_TEXT_HOLE_STATE_ARMED)
        GDHO_SetInteractionPhase(GDHO_PHASE_WEAK_PREVIEW, "sm:" . String(reason))
    else if (ns = GDHO_TEXT_HOLE_STATE_COMMITTED || ns = GDHO_TEXT_HOLE_STATE_EXPANDING)
        GDHO_SetInteractionPhase(GDHO_PHASE_COMMITTING, "sm:" . String(reason))
    else if (ns = GDHO_TEXT_HOLE_STATE_PANEL_SHOWN)
        GDHO_SetInteractionPhase(GDHO_PHASE_PANEL_OPEN, "sm:" . String(reason))
    else if (ns = GDHO_TEXT_HOLE_STATE_CLOSED || ns = GDHO_TEXT_HOLE_STATE_IDLE)
        GDHO_SetInteractionPhase(GDHO_PHASE_IDLE, "sm:" . String(reason))
    sid := GDHO_TextHoleSessionId()
    d := (dist = "" ? "-" : String(dist))
    tl := (txtLen = "" ? "-" : String(txtLen))
    pv := (IsSet(GDHO_PANEL_VISIBLE) && GDHO_PANEL_VISIBLE) ? "1" : "0"
    ph := GDHO_GetInteractionPhase()
    try NativeDropDiag_Log("[TextHoleSM] sid=" . sid . " from=" . oldState . " to=" . newState . " phase=" . ph . " reason=" . String(reason) . " dist=" . d . " text_len=" . tl . " panel_visible=" . pv)
}

GDHO_TextHoleLogSnapshot(tag := "", reason := "") {
    global g_GDHO_TextHoleSessionSerial, g_GDHO_TextHoleCommitSerial, g_GDHO_PostSuckPanelPending, g_GDHO_TextHoleState
    try NativeDropDiag_Log("[TextHoleSM] snapshot tag=" . String(tag) . " reason=" . String(reason)
        . " session=" . Integer(g_GDHO_TextHoleSessionSerial)
        . " commit=" . Integer(g_GDHO_TextHoleCommitSerial)
        . " pending=" . (g_GDHO_PostSuckPanelPending ? "1" : "0")
        . " state=" . String(g_GDHO_TextHoleState))
}

GDHO_TextHole_OnSelectionPreviewStart(txt := "", mx := "", my := "") {
    global GDHO_SESSION_TEXT, GDHO_CURSOR_X, GDHO_CURSOR_Y
    t := Trim(String(txt))
    if (t != "") {
        try GDHO_StampTextHoleCapturedText(t)
        try GDHO_SESSION_TEXT := t
    }
    if (mx != "" && my != "") {
        GDHO_CURSOR_X := Integer(mx)
        GDHO_CURSOR_Y := Integer(my)
    }
    GDHO_TextHoleTransition(GDHO_TEXT_HOLE_STATE_PREVIEW, "selection_preview_start", "", StrLen(t))
    try GDHO_ShelvePanelHost("selection_preview")
}

GDHO_TextHole_OnExpandComplete(sessionId := 0) {
    global g_GDHO_TextHoleSessionSerial
    sid := Integer(sessionId)
    cur := Integer(g_GDHO_TextHoleSessionSerial)
    if (sid > 0 && cur > 0 && sid != cur) {
        try NativeDropDiag_Log("[TextHoleSM] expand_complete_skip sid=" . sid . " current_sid=" . cur . " reason=stale_session")
        return false
    }
    GDHO_TextHoleTransition(GDHO_TEXT_HOLE_STATE_PANEL_SHOWN, "expand_complete")
    return true
}

GDHO_IsDecoupled() {
    return IsSet(GDHO_DECOUPLED_TOPOLOGY) && GDHO_DECOUPLED_TOPOLOGY
}

GDHO_TextHolePresentAllowed() {
    global g_GDHO_TextHoleSessionSerial, g_GDHO_TextHoleCommitSerial, g_GDHO_TextHoleAwaitingExpand
    global g_GDHO_TextHoleCommitDone, g_GDHO_TextHoleCapturedText, GDHO_SESSION_TEXT
    cs := Integer(g_GDHO_TextHoleCommitSerial)
    ss := Integer(g_GDHO_TextHoleSessionSerial)
    if (cs > 0 && ss > 0 && cs = ss)
        return (g_GDHO_TextHoleAwaitingExpand || g_GDHO_TextHoleCommitDone)
    ; Recovery path: allow one-shot present when text is already captured
    ; but the serial markers were reset/raced.
    if (g_GDHO_TextHoleAwaitingExpand || g_GDHO_TextHoleCommitDone) {
        t := Trim(String(g_GDHO_TextHoleCapturedText))
        if (t = "")
            t := Trim(String(GDHO_SESSION_TEXT))
        if (t != "")
            return true
    }
    return false
}

GDHO_DisarmTextHoleCommitWatch() {
    global g_GDHO_TextHoleAbortOutsideSince
    g_GDHO_TextHoleAbortOutsideSince := 0
    try SetTimer(GDHO_WatchTextHoleCommit, 0)
}

GDHO_CancelTextHolePresentTimers() {
    try SetTimer(GDHO_PostSuckPanelTimer, 0)
    try SetTimer(GDHO_TextHoleExpandFallback, 0)
    try SetTimer(GDHO_TextHoleExpandCompleteEnsure, 0)
    try SetTimer(GDHO_ForcePresentPanelAfterCommit, 0)
    try SetTimer(GDHO_TextHoleFastPresentTimer, 0)
    try SetTimer(GDHO_CommitEarlyLauncherPump, 0)
    try SetTimer(GDHO_TextHolePresentRetry, 0)
    global g_GDHO_PostSuckTimerArmed, g_GDHO_TextHolePresentRetryArmed
    g_GDHO_PostSuckTimerArmed := false
    g_GDHO_TextHolePresentRetryArmed := false
}

GDHO_ArmTextHoleCommitWatch() {
    global g_GDHO_TextHoleAbortOutsideSince
    g_GDHO_TextHoleAbortOutsideSince := 0
    try SetTimer(GDHO_WatchTextHoleCommit, 0)
    SetTimer(GDHO_WatchTextHoleCommit, 60)
}

GDHO_WatchTextHoleCommit(*) {
    global g_GDHO_TextHoleAwaitingExpand, g_GDHO_TextHolePanelOpen, g_GDHO_TextHoleAbortOutsideSince
    global GDHO_TEXT_HOLE_OPEN_RADIUS_PX
    if GDHO_IsTextHoleUserPanelActive() || g_GDHO_TextHolePanelOpen || !g_GDHO_TextHoleAwaitingExpand {
        GDHO_DisarmTextHoleCommitWatch()
        return
    }
    ; 吸入动画期间允许鼠标离开洞心，避免误 abort 导致面板永不出现。
    if (GDHO_GetInteractionPhase() = GDHO_PHASE_COMMITTING)
        return
    if !GDHO_TextHolePresentAllowed() {
        GDHO_DisarmTextHoleCommitWatch()
        return
    }
    global g_GDHO_TextHoleCommitTick, GDHO_TEXT_HOLE_EXPAND_MS, GDHO_TEXT_HOLE_ABORT_GRACE_MS
    graceMs := Integer(GDHO_TEXT_HOLE_ABORT_GRACE_MS)
    if (graceMs < Integer(GDHO_TEXT_HOLE_EXPAND_MS) + 200)
        graceMs := Integer(GDHO_TEXT_HOLE_EXPAND_MS) + 200
    if (g_GDHO_TextHoleCommitTick > 0 && (A_TickCount - g_GDHO_TextHoleCommitTick) < graceMs)
        return
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    dist := GDHO_GetDistanceToHoleCenter(mx, my)
    openR := Float(GDHO_TEXT_HOLE_OPEN_RADIUS_PX)
    if (dist > openR * 1.45) {
        if (g_GDHO_TextHoleAbortOutsideSince = 0)
            g_GDHO_TextHoleAbortOutsideSince := A_TickCount
        else if ((A_TickCount - g_GDHO_TextHoleAbortOutsideSince) >= 480)
            GDHO_AbortTextHoleCommit("left_hole_before_panel")
    } else
        g_GDHO_TextHoleAbortOutsideSince := 0
}

GDHO_AbortTextHoleCommit(reason := "") {
    global g_GDHO_TextHoleCommitSerial, g_GDHO_TextHoleAwaitingExpand, g_GDHO_TextHoleCommitDone
    global g_GDHO_PostSuckPanelPending, g_GDHO_PostSuckProtectUntil, g_GDHO_PanelHoldUntil, g_GDHO_PostSuckPresentDone
    global g_GDHO_SuppressSelectionAutoHide, g_GDHO_TextHoleCapturedText, GDHO_SESSION_TEXT
    if FuncExists("GDHO_IsTextHolePanelOpen") && GDHO_IsTextHolePanelOpen()
        return
    tKeep := ""
    try tKeep := Trim(String(g_GDHO_TextHoleCapturedText))
    if (tKeep = "")
        try tKeep := Trim(String(GDHO_SESSION_TEXT))
    if (tKeep != "") {
        try NativeDropDiag_Log("[TextHole] abort_skip reason=has_text len=" . StrLen(tKeep) . " abort_reason=" . String(reason))
        return
    }
    g_GDHO_SuppressSelectionAutoHide := false
    g_GDHO_TextHoleCommitSerial := 0
    g_GDHO_TextHoleAwaitingExpand := false
    g_GDHO_TextHoleCommitDone := false
    g_GDHO_PostSuckPanelPending := false
    g_GDHO_PostSuckProtectUntil := 0
    g_GDHO_PanelHoldUntil := 0
    g_GDHO_PostSuckPresentDone := false
    GDHO_DisarmTextHoleCommitWatch()
    try SetTimer(GDHO_TextHoleExpandFallback, 0)
    try SetTimer(GDHO_PostSuckPanelTimer, 0)
    try GDHO_DismissLauncherUI("abort_" . String(reason))
    try GDHO_RunStarryJS("window.HoleOverlay?.hideSilent?.()")
    GDHO_TextHoleTransition(GDHO_TEXT_HOLE_STATE_CLOSED, "abort_" . String(reason))
    try NativeDropDiag_Log("[TextHole] abort reason=" . String(reason))
}

GDHO_IsPostSuckProtected() {
    global g_GDHO_PostSuckProtectUntil, g_GDHO_PostSuckPanelPending, g_GDHO_PostSuckTimerArmed, g_GDHO_PanelHoldUntil
    if FuncExists("GDHO_IsTextHolePanelOpen") && GDHO_IsTextHolePanelOpen()
        return true
    if (g_GDHO_PostSuckPanelPending || g_GDHO_PostSuckTimerArmed)
        return true
    if (g_GDHO_PanelHoldUntil > 0 && A_TickCount < g_GDHO_PanelHoldUntil)
        return true
    return (g_GDHO_PostSuckProtectUntil > 0 && A_TickCount < g_GDHO_PostSuckProtectUntil)
}

GDHO_IsTextHolePanelOpen() {
    global g_GDHO_TextHolePanelOpen, GDHO_PANEL_VISIBLE
    return !!(g_GDHO_TextHolePanelOpen || GDHO_PANEL_VISIBLE)
}

GDHO_IsExplicitTextHolePanelCloseReason(reason := "") {
    r := StrLower(Trim(String(reason)))
    return (r = "panel_hole_close" || r = "panel_dismiss" || r = "panel_escape" || r = "panel_close_btn"
        || r = "launcher_close_btn"
        || InStr(r, "dismiss_panel_close_btn") || InStr(r, "dismiss_panel_escape"))
}

GDHO_IsTextHoleUserPanelActive() {
    global g_GDHO_TextHolePanelLocked, g_GDHO_UserTextHolePanelEngaged, GDHO_PANEL_VISIBLE
    if g_GDHO_UserTextHolePanelEngaged || g_GDHO_TextHolePanelLocked
        return true
    if (IsSet(GDHO_PANEL_VISIBLE) && GDHO_PANEL_VISIBLE)
        return true
    return (FuncExists("GDHO_IsTextHolePanelOpen") && GDHO_IsTextHolePanelOpen())
}

GDHO_MayAutoHideTextHolePanel(reason := "") {
    if GDHO_IsExplicitTextHolePanelCloseReason(reason)
        return true
    if GDHO_IsTextHoleUserPanelActive()
        return false
    if FuncExists("GDHO_ShouldKeepTextHolePanel") && GDHO_ShouldKeepTextHolePanel()
        return false
    return true
}

GDHO_LockTextHoleUserPanel() {
    global g_GDHO_TextHolePanelLocked, g_GDHO_TextHolePanelOpen, g_GDHO_TextHoleStickyPanel, g_GDHO_SuppressSelectionAutoHide
    global g_GDHO_UserTextHolePanelEngaged
    g_GDHO_UserTextHolePanelEngaged := true
    g_GDHO_TextHolePanelLocked := true
    g_GDHO_TextHolePanelOpen := true
    g_GDHO_TextHoleStickyPanel := true
    g_GDHO_SuppressSelectionAutoHide := true
    GDHO_DisarmTextHoleProximityPoll()
    GDHO_DisarmTextHoleCommitWatch()
    try GDHO_HideStarryAfterPanel("panel_engaged")
    try GDHO_SetProximity(0.0)
    GDHO_ArmPanelHold()
    try SetTimer(SelectionSense_HideHoleAfterSelection, 0)
    try NativeDropDiag_Log("[TextHole] user_panel_engaged=1 until_exit")
}

GDHO_UnlockTextHoleUserPanel() {
    global g_GDHO_TextHolePanelLocked, g_GDHO_UserTextHolePanelEngaged
    g_GDHO_UserTextHolePanelEngaged := false
    g_GDHO_TextHolePanelLocked := false
    try NativeDropDiag_Log("[TextHole] user_panel_engaged=0")
}

; 输入面板已打开时，避免新一轮弱预览把当前面板关掉。
GDHO_ShouldSkipSelectionPreviewRestart(newText := "") {
    if GDHO_IsTextHoleUserPanelActive()
        return true
    if !(FuncExists("GDHO_IsTextHolePanelOpen") && GDHO_IsTextHolePanelOpen())
        return false
    if FuncExists("GDHO_ShouldKeepTextHolePanel") {
        try {
            if GDHO_ShouldKeepTextHolePanel()
                return true
        } catch {
        }
    }
    tNew := Trim(String(newText))
    tOld := ""
    if FuncExists("GDHO_GetTextHoleCapturedText")
        try tOld := Trim(String(GDHO_GetTextHoleCapturedText()))
    if (tNew != "" && tOld != "" && tNew = tOld)
        return true
    return false
}

GDHO_IsPanelDragProtected() {
    global g_GDHO_PanelUserDragging, g_GDHO_PanelDragGraceUntil, g_GDHO_PanelDragInProgress
    if g_GDHO_PanelDragInProgress || g_GDHO_PanelUserDragging
        return true
    return (g_GDHO_PanelDragGraceUntil > A_TickCount)
}

GDHO_PanelDragSetOpaque(enable := true) {
    global GDHO_WV2_CTRL_PANEL
    if !IsObject(GDHO_WV2_CTRL_PANEL)
        return
    try {
        if enable
            GDHO_WV2_CTRL_PANEL.DefaultBackgroundColor := 0xFF0A0E14
        else
            GDHO_WV2_CTRL_PANEL.DefaultBackgroundColor := 0x00000000
    } catch {
    }
}

; 面板宿主：平时隐藏 + 穿透；黑洞提交后再激活显示。
GDHO_SetPanelClickThrough(enable := true, reason := "") {
    global GDHO_PANEL_GUI
    if !IsObject(GDHO_PANEL_GUI) || !GDHO_PANEL_GUI.Hwnd
        return
    hwnd := GDHO_PANEL_GUI.Hwnd
    try {
        ex := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr")
        if enable
            ex := (ex | 0x20) | 0x08000000
        else
            ex := (ex & ~0x20) | 0x08000000
        DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr", ex, "Ptr")
    } catch {
    }
    try GDHO_PanelDragSetOpaque(!enable)
    if enable {
        try GDHO_PANEL_GUI.BackColor := "010101"
        try WinSetTransparent(255, "ahk_id " hwnd)
        try WinSetTransColor("010101", "ahk_id " hwnd)
    }
    try GDHO_Trace("panel_clickthrough=" . (enable ? "1" : "0") . " reason=" . Trim(String(reason)))
}

GDHO_ShelvePanelHost(reason := "passive") {
    if GDHO_IsPanelDragProtected()
        return
    r := StrLower(Trim(String(reason)))
    if FuncExists("GDHO_IsTextHoleUserPanelActive") && GDHO_IsTextHoleUserPanelActive()
        && !(InStr(r, "dismiss") || InStr(r, "close") || InStr(r, "reset") || InStr(r, "esc"))
        return
    GDHO_SetPanelClickThrough(true, reason)
    try GDHO_HidePanel("shelve:" . reason)
    try GDHO_RunPanelJS("try{window.HolePanel?.onHostHide?.();var r=document.getElementById('panelRoot');if(r){r.dataset.interactionState='idle';r.style.opacity='0';r.style.pointerEvents='none';}}catch(_e){}")
}

GDHO_ActivatePanelHost(reason := "activate") {
    global GDHO_PANEL_GUI
    if !IsObject(GDHO_PANEL_GUI)
        return
    try GDHO_PANEL_GUI.BackColor := "0A0E14"
    GDHO_SetPanelClickThrough(false, reason)
    GDHO_SetPanelInteractive(reason)
    try GDHO_SyncPanelCapturedPreview()
}

; Win32 无边框窗体拖动（不依赖 WebView postMessage 流）。
GDHO_BeginPanelHostDrag() {
    global GDHO_PANEL_GUI
    if !IsObject(GDHO_PANEL_GUI) || !GDHO_PANEL_GUI.Hwnd
        return false
    GDHO_ActivatePanelHost("native_panel_drag")
    hwnd := GDHO_PANEL_GUI.Hwnd
    try {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        try GDHO_PANEL_GUI.GetPos(&wx, &wy)
        catch {
            wx := 0, wy := 0
        }
        cx := Integer(mx - wx) & 0xFFFF
        cy := Integer(my - wy) & 0xFFFF
        lParam := (cy << 16) | cx
        DllCall("ReleaseCapture")
        PostMessage(0xA1, 2, lParam, 0, "ahk_id " hwnd)
        return true
    } catch {
        return false
    }
}

GDHO_SyncPanelCapturedPreview() {
    global g_GDHO_PendingPanelText, GDHO_PANEL_READY
    if GDHO_IsStarryLauncherMode()
        return false
    t := Trim(String(g_GDHO_PendingPanelText))
    if (t = "")
        t := GDHO_GetTextHoleCapturedText()
    if FuncExists("GDHO_RefreshTextHoleCapturedTextFromSelection")
        try t := GDHO_RefreshTextHoleCapturedTextFromSelection(4)
    g_GDHO_PendingPanelText := t
    if !(GDHO_PANEL_READY && FuncExists("GDHO_RunPanelJS"))
        return false
    jsBody := GDHO_QuoteJsString(t)
    try {
        if GDHO_RunPanelJS("try{window.HolePanel?.ensurePanelLoaded?.();window.HolePanel?.onHostShowLauncher?.(" . jsBody . ");}catch(_e){}")
            return true
    } catch {
    }
    return false
}

GDHO_PushPanelCapturedText() {
    global g_GDHO_PendingPanelText, GDHO_PANEL_READY
    t := Trim(String(g_GDHO_PendingPanelText))
    if (t = "")
        t := GDHO_GetTextHoleCapturedText()
    if FuncExists("GDHO_RefreshTextHoleCapturedTextFromSelection")
        try t := GDHO_RefreshTextHoleCapturedTextFromSelection(4)
    if (t = "")
        return false
    g_GDHO_PendingPanelText := t
    if GDHO_PANEL_READY && FuncExists("GDHO_RunPanelJS") {
        jsBody := GDHO_QuoteJsString(t)
        if GDHO_RunPanelJS("try{window.HolePanel?.ensurePanelLoaded?.();window.HolePanel?.openManualWithText?.(" . jsBody . ");window.HolePanel?.focusPrompt?.(false);}catch(_e){}") {
            g_GDHO_PendingPanelText := ""
            try NativeDropDiag_Log("[TextHole] push_panel_text len=" . StrLen(t))
            return true
        }
        try NativeDropDiag_Log("[TextHole] push_panel_text_fail len=" . StrLen(t) . " ready=1 run_js=0")
    }
    try NativeDropDiag_Log("[TextHole] push_panel_text_defer len=" . StrLen(t) . " ready=" . (GDHO_PANEL_READY ? "1" : "0"))
    return false
}

; 用户已激活输入面板：在 Esc/关闭按钮退出前，禁止任何黑洞/弱预览再入场。
GDHO_ShouldBlockStarryReentry() {
    if GDHO_IsPanelDragProtected()
        return true
    ph := GDHO_GetInteractionPhase()
    if (ph = GDHO_PHASE_PANEL_OPEN || ph = GDHO_PHASE_COMMITTING || ph = GDHO_PHASE_CLOSING)
        return true
    return GDHO_IsTextHoleUserPanelActive()
}

GDHO_IsStarryOpenIntentBlocked(reason := "", payload := 0) {
    if !GDHO_ShouldBlockStarryReentry()
        return false
    r := StrLower(Trim(String(reason)))
    if (payload is Map) {
        if payload.Has("reason")
            r := StrLower(Trim(String(payload["reason"])))
        if (payload.Has("weakPreview") && payload["weakPreview"])
            return true
    }
    if FuncExists("GDHO_IsWeakPreviewReason") && GDHO_IsWeakPreviewReason(r)
        return true
    if (InStr(r, "gesture") || InStr(r, "circle") || InStr(r, "rbutton_hold") || InStr(r, "hold_early"))
        return false
    return (InStr(r, "text_drag") || InStr(r, "drag_activate") || InStr(r, "selection_copy")
        || InStr(r, "hole_mode") || InStr(r, "post_suck") || InStr(r, "physical_suck")
        || InStr(r, "preview") || InStr(r, "proximity"))
}

GDHO_ArmPanelDragGrace(ms := 500) {
    global g_GDHO_PanelDragGraceUntil
    g_GDHO_PanelDragGraceUntil := A_TickCount + Integer(ms)
}

GDHO_ClearPanelUserDragging(*) {
    global g_GDHO_PanelUserDragging
    g_GDHO_PanelUserDragging := false
}

GDHO_ShouldKeepTextHolePanel() {
    global g_GDHO_TextHoleStickyPanel, g_GDHO_TextHolePanelLocked
    if GDHO_IsPanelDragProtected()
        return true
    if g_GDHO_TextHolePanelLocked
        return true
    if GDHO_IsTextHolePanelOpen() || g_GDHO_TextHoleStickyPanel
        return true
    return GDHO_IsPostSuckProtected()
}

GDHO_RefreshTextHoleCapturedTextFromSelection(minLen := 4) {
    global g_GDHO_TextHoleCapturedText, GDHO_SESSION_TEXT
    t := Trim(String(g_GDHO_TextHoleCapturedText))
    if (t = "")
        try t := Trim(String(GDHO_SESSION_TEXT))
    if (StrLen(t) >= Integer(minLen))
        return t
    fresh := ""
    if FuncExists("SelectionSense_GetLastSelectedText")
        try fresh := Trim(SelectionSense_GetLastSelectedText())
    if (fresh = "" && FuncExists("GDHO_GetBestSelectedText"))
        try fresh := Trim(GDHO_GetBestSelectedText())
    if (StrLen(fresh) > StrLen(t)) {
        g_GDHO_TextHoleCapturedText := fresh
        GDHO_SESSION_TEXT := fresh
        try NativeDropDiag_Log("[TextHole] capture_refresh len=" . StrLen(fresh) . " was=" . StrLen(t))
        return fresh
    }
    return t
}

GDHO_GetTextHoleCapturedText() {
    global g_GDHO_TextHoleCapturedText, GDHO_SESSION_TEXT
    t := Trim(String(g_GDHO_TextHoleCapturedText))
    if (t != "")
        return t
    t := Trim(String(GDHO_SESSION_TEXT))
    if (t != "")
        return t
    if FuncExists("SelectionSense_GetLastSelectedText")
        try t := Trim(SelectionSense_GetLastSelectedText())
    if (t = "") && FuncExists("GDHO_GetBestSelectedText")
        try t := Trim(GDHO_GetBestSelectedText())
    return t
}

; 解耦拓扑进入黑洞模式：不钉住桌面 file 态，清会话后保持空闲，等待划选文字触发弱预览。
GDHO_PrepareDecoupledHoleForTextSelection(reason := "activation_hole") {
    global GDHO_EXPANDED_HOLD, GDHO_IS_SUCKING, GDHO_VISIBLE
    global g_GDHO_UserTextHolePanelEngaged, g_GDHO_TextHolePanelLocked
    if !GDHO_IsDecoupled()
        return false
    try GDHO_UnpinFromDesktop()
    catch {
    }
    try GDHO_UnlockTextHoleUserPanel()
    catch {
    }
    g_GDHO_UserTextHolePanelEngaged := false
    g_GDHO_TextHolePanelLocked := false
    GDHO_EXPANDED_HOLD := false
    GDHO_IS_SUCKING := false
    try GDHO_DismissLauncherUI("prepare_hole:" . String(reason))
    catch {
    }
    if GDHO_VISIBLE {
        if FuncExists("GDHO_RequestClose")
            try GDHO_RequestClose("prepare_hole:" . String(reason))
    }
    global g_GDHO_PostSuckPresentDone, g_GDHO_TextHolePanelOpen, g_GDHO_TextHoleStickyPanel, g_GDHO_PostSuckPanelPending
    global g_GDHO_PostSuckTimerArmed, g_GDHO_TextHoleState, g_GDHO_StarryLauncherOpen
    g_GDHO_PostSuckPresentDone := false
    g_GDHO_TextHolePanelOpen := false
    g_GDHO_TextHoleStickyPanel := false
    g_GDHO_PostSuckPanelPending := false
    g_GDHO_PostSuckTimerArmed := false
    g_GDHO_StarryLauncherOpen := false
    try GDHO_ResetTextHoleSession()
    catch {
    }
    try GDHO_SetInteractionPhase(GDHO_PHASE_IDLE, "prepare_hole:" . String(reason))
    if FuncExists("GDHO_HideStarryHost")
        try GDHO_HideStarryHost("prepare_hole:" . String(reason))
    if FuncExists("GDHO_ParkOverlay")
        try GDHO_ParkOverlay()
    try NativeDropDiag_Log("[TextHole] prepare_decoupled_hole reason=" . String(reason) . " phase=" . GDHO_GetInteractionPhase())
    return true
}

; 启动层关闭后回收手势会话，避免星空残留 + SelectionSense 仍占 preview 导致无法再次画圈唤起。
GDHO_ClearGestureHolePresentation(reason := "gesture_clear") {
    global g_GDHO_GestureOpenGraceUntil, g_GDHO_SuppressSelectionAutoHide, GDHO_VISIBLE
    global g_SelSense_TextCaptured, g_SelSense_AllowTextHoleGesture, g_SelSense_HoleDragPhase
    r := StrLower(Trim(String(reason)))
    g_GDHO_GestureOpenGraceUntil := 0
    g_GDHO_SuppressSelectionAutoHide := false
    if FuncExists("HoleActivation_ClearGestureGrace") {
        try HoleActivation_ClearGestureGrace()
        catch {
        }
    }
    try GDHO_DisarmTextHoleProximityPoll()
    catch {
    }
    try GDHO_EndSelectionPreviewForPanel()
    catch {
    }
    g_SelSense_TextCaptured := false
    g_SelSense_AllowTextHoleGesture := false
    g_SelSense_HoleDragPhase := "idle"
    try SetTimer(SelectionSense_HideHoleAfterSelection, 0)
    catch {
    }
    if FuncExists("GDHO_SetInteractionPhase") {
        try GDHO_SetInteractionPhase(GDHO_PHASE_IDLE, r)
        catch {
        }
    }
    if FuncExists("GDHO_IsStarryLauncherMode") && GDHO_IsStarryLauncherMode() && GDHO_UseLauncherLayer() {
        try GDHO_RunStarryJS("window.HoleOverlay?.hideSilent?.()")
        catch {
        }
        if (GDHO_VISIBLE || (FuncExists("GDHO_IsStarryHostVisible") && GDHO_IsStarryHostVisible())) {
            if FuncExists("GDHO_HideStarryAfterPanel")
                try GDHO_HideStarryAfterPanel("clear_gesture:" . r)
            catch {
            }
            if FuncExists("GDHO_HideStarryHost")
                try GDHO_HideStarryHost("clear_gesture:" . r)
            catch {
            }
        }
        try GDHO_SetStarryClickThrough(true, "clear_gesture:" . r)
        catch {
        }
    }
    if FuncExists("HoleTriggers_OnLauncherDismissed") {
        try HoleTriggers_OnLauncherDismissed(r)
        catch {
        }
    }
    try NativeDropDiag_Log("[TextHole] clear_gesture_presentation reason=" . r . " vis=" . (GDHO_VISIBLE ? "1" : "0"))
}

; 画圈/长按等无划选手势：在光标处弹出启动层（starry 拓扑），与划选弱预览同会话标记
GDHO_PresentGestureHoleAt(mx, my, reason := "gesture") {
    global GDHO_CX, GDHO_CY, GDHO_LAUNCHER_VISIBLE, g_GDHO_StarryLauncherOpen, GDHO_STAR_GUI
    ax := Integer(mx), ay := Integer(my)
    if (ax = 0 && ay = 0) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&ax, &ay)
    }
    try NativeDropDiag_Log("[TextHole] gesture_present_begin x=" . ax . " y=" . ay . " reason=" . String(reason)
        . " phase=" . GDHO_GetInteractionPhase())
    if GDHO_IsDecoupled() && !GDHO_CanOpenGestureHole(reason) {
        try GDHO_PrepareDecoupledHoleForTextSelection("gesture_present:" . String(reason))
        catch {
        }
    }
    if !IsObject(GDHO_STAR_GUI) {
        try GDHO_CreateStarryGui()
        catch {
        }
    }
    sessionOk := true
    try GDHO_BeginGestureHoleSession(ax, ay, reason)
    catch as e0 {
        sessionOk := false
        try NativeDropDiag_Log("[TextHole] gesture_session_fail msg=" . e0.Message)
    }
    ok := false
    if GDHO_UseLauncherLayer() {
        try GDHO_ShowStarryPassthroughOnly("gesture:" . String(reason))
        catch {
        }
        try GDHO_UpdateHoleCenterFromPolicy(ax, ay)
        catch {
        }
        if !GDHO_EnsureStarryOnScreenForLauncher() {
            try {
                if !IsObject(GDHO_STAR_GUI) && FuncExists("GDHO_CreateStarryGui")
                    GDHO_CreateStarryGui()
                if IsObject(GDHO_STAR_GUI)
                    GDHO_STAR_GUI.Show("NA")
            } catch {
            }
            try GDHO_EnsureStarryOnScreenForLauncher()
            catch {
            }
        }
        try ok := GDHO_ShowLauncherLayerForced("gesture:" . String(reason))
        catch {
        }
        if !ok && FuncExists("GDHO_ForceShowLauncherLayerByPolicy") {
            try ok := GDHO_ForceShowLauncherLayerByPolicy(ax, ay, "gesture_present:" . String(reason))
            catch {
            }
        }
        try GDHO_SetStarryClickThrough(false, "gesture_interactive")
        catch {
        }
        rGesture := StrLower(Trim(String(reason)))
        armProx := !(InStr(rGesture, "free_circle") || InStr(rGesture, "circle_cw") || InStr(rGesture, "circle_ccw"))
        if armProx && FuncExists("GDHO_ArmTextHoleProximityPoll") {
            try GDHO_ArmTextHoleProximityPoll()
            catch {
            }
        }
        if (ok || GDHO_LAUNCHER_VISIBLE || g_GDHO_StarryLauncherOpen)
            ok := true
        try NativeDropDiag_Log("[TextHole] gesture_launcher ok=" . (ok ? "1" : "0") . " x=" . ax . " y=" . ay
            . " cx=" . GDHO_CX . " cy=" . GDHO_CY . " lv=" . (GDHO_LAUNCHER_VISIBLE ? "1" : "0") . " reason=" . String(reason))
        if ok
            return true
    }
    if FuncExists("GDHO_ForceShowLauncherLayerByPolicy") {
        try {
            if ok := GDHO_ForceShowLauncherLayerByPolicy(ax, ay, "gesture_drag_fallback:" . String(reason))
                return true
        } catch {
        }
    }
    if FuncExists("GDHO_ShowTextDragAt") {
        try {
            if GDHO_ShowTextDragAt(ax, ay, true, true)
                return true
        } catch {
        }
    }
    try NativeDropDiag_Log("[TextHole] gesture_open_fail reason=" . String(reason) . " session=" . (sessionOk ? "1" : "0"))
    return false
}

GDHO_OpenGestureHoleAt(mx, my, reason := "gesture") {
    return GDHO_PresentGestureHoleAt(mx, my, reason)
}

GDHO_ForceApplyAppearanceMode(mode := "hole") {
    global AppearanceActivationMode, g_ActivationApplyLastMode, g_ActivationApplyLastTick
    m := NormalizeAppearanceActivationMode(mode)
    AppearanceActivationMode := m
    g_ActivationApplyLastMode := ""
    g_ActivationApplyLastTick := 0
    if FuncExists("ApplyAppearanceActivationMode")
        return ApplyAppearanceActivationMode()
    return false
}

GDHO_ResetTextHoleSession() {
    if GDHO_IsTextHoleUserPanelActive() {
        try NativeDropDiag_Log("[TextHole] reset_session_skip reason=panel_locked")
        return
    }
    global g_GDHO_TextHoleCommitDone, g_GDHO_TextHoleProxWasOutside, g_GDHO_TextHoleProxInsideSince
    global g_GDHO_TextHoleProxNeedsReenter, g_GDHO_TextHolePanelOpen, g_GDHO_TextHoleAwaitingExpand
    global g_GDHO_TextHoleCapturedText, g_GDHO_PostSuckPanelPending, g_GDHO_PostSuckTimerArmed
    global g_GDHO_PendingPanelText, g_GDHO_PostSuckProtectUntil, g_GDHO_PanelHoldUntil, g_GDHO_TextHoleStickyPanel
    global g_GDHO_PostSuckPresentDone, g_GDHO_TextHoleSessionSerial, g_GDHO_TextHoleCommitSerial
    global g_GDHO_TextHolePresentedSessionId, g_GDHO_TextHoleFallbackSessionId, g_GDHO_TextHoleExpandCompleteSessionId
    global g_GDHO_StarryLauncherOpen, g_GDHO_PendingStarryLauncherShow
    global g_GDHO_LastOnScreenHoleCx, g_GDHO_LastOnScreenHoleCy
    g_GDHO_StarryLauncherOpen := false
    g_GDHO_PendingStarryLauncherShow := false
    g_GDHO_LastOnScreenHoleCx := 0
    g_GDHO_LastOnScreenHoleCy := 0
    try GDHO_HideStarryLauncher()
    try GDHO_HideLauncherLayer("reset_session")
    try GDHO_RestoreStarryPassthroughIfIdle("reset_session")
    g_GDHO_TextHoleSessionSerial += 1
    g_GDHO_TextHoleCommitSerial := 0
    g_GDHO_TextHolePanelOpen := false
    g_GDHO_TextHoleAwaitingExpand := false
    g_GDHO_TextHoleCommitDone := false
    g_GDHO_PostSuckPanelPending := false
    g_GDHO_PostSuckTimerArmed := false
    g_GDHO_PendingPanelText := ""
    g_GDHO_PostSuckProtectUntil := 0
    g_GDHO_PanelHoldUntil := 0
    g_GDHO_TextHoleCapturedText := ""
    g_GDHO_TextHoleStickyPanel := false
    g_GDHO_PostSuckPresentDone := false
    g_GDHO_TextHolePresentedSessionId := 0
    g_GDHO_TextHoleFallbackSessionId := 0
    g_GDHO_TextHoleExpandCompleteSessionId := 0
    g_GDHO_SuppressSelectionAutoHide := false
    g_GDHO_TextHoleProxInsideSince := 0
    g_GDHO_TextHoleProxNeedsReenter := false
    g_GDHO_TextHoleProxWasOutside := true
    try SetTimer(GDHO_TextHoleExpandFallback, 0)
    try SetTimer(GDHO_PostSuckPanelTimer, 0)
    try SetTimer(GDHO_ForcePresentPanelAfterCommit, 0)
    try SetTimer(GDHO_PanelDeactivateCheck, 0)
    GDHO_DisarmTextHoleCommitWatch()
    GDHO_CancelSelectionPreviewPanelGuards()
    GDHO_DisarmTextHoleProximityPoll()
    GDHO_ClearTextDragHandoff(true)
    try GDHO_RunStarryJS("window.HoleOverlay?.hideSilent?.()")
    g_GDHO_TextHoleProxNeedsReenter := false
    g_GDHO_TextHoleProxWasOutside := true
    GDHO_TextHoleTransition(GDHO_TEXT_HOLE_STATE_IDLE, "reset_session")
    GDHO_SetInteractionPhase(GDHO_PHASE_IDLE, "reset_session")
    try GDHO_ShelvePanelHost("reset_session")
}

GDHO_DismissTextHolePanel(reason := "panel_dismiss") {
    global g_GDHO_TextHolePanelOpen, GDHO_PANEL_VISIBLE, g_GDHO_TextHoleStickyPanel, g_GDHO_StarryLauncherOpen
    if !g_GDHO_TextHolePanelOpen && !GDHO_PANEL_VISIBLE && !g_GDHO_StarryLauncherOpen
        return
    g_GDHO_StarryLauncherOpen := false
    try GDHO_HideStarryLauncher()
    try GDHO_HideLauncherLayer("dismiss_" . String(reason))
    try GDHO_RestoreStarryPassthroughIfIdle("dismiss_" . String(reason))
    GDHO_SetInteractionPhase(GDHO_PHASE_CLOSING, String(reason))
    GDHO_UnlockTextHoleUserPanel()
    try GDHO_DisarmTextHoleProximityPoll()
    g_GDHO_TextHolePanelOpen := false
    g_GDHO_TextHoleStickyPanel := false
    g_GDHO_SuppressSelectionAutoHide := false
    try GDHO_HideStarryAfterPanel("dismiss_" . reason)
    if FuncExists("GDHO_WS_Send")
        try GDHO_WS_Send("dismiss", "", "", "", String(reason))
    try GDHO_ShelvePanelHost("dismiss_" . reason)
    GDHO_ResetTextHoleSession()
    GDHO_TextHoleTransition(GDHO_TEXT_HOLE_STATE_CLOSED, "dismiss_" . String(reason))
    try GDHO_Trace("text_hole_dismiss reason=" . String(reason))
}

GDHO_StampTextHoleCapturedText(txt := "") {
    global g_GDHO_TextHoleCapturedText
    t := Trim(String(txt))
    if (t = "")
        return
    g_GDHO_TextHoleCapturedText := t
}

GDHO_HideStarryAfterPanel(reason := "") {
    global GDHO_STAR_GUI, GDHO_HOST_W, GDHO_HOST_H, GDHO_PARK_X, GDHO_PARK_Y, GDHO_VISIBLE, GDHO_ACTIVE
    if FuncExists("GDHO_ShouldDeferStarryCloseForTextHole") && GDHO_ShouldDeferStarryCloseForTextHole(reason)
        return
    gui := GDHO_GetStarryGui()
    if !IsObject(gui)
        return
    if GDHO_IsStarryLauncherMode() && GDHO_UseLauncherLayer() {
        r := StrLower(Trim(String(reason)))
        try GDHO_SuppressEmbeddedStarryLauncher()
        if (InStr(r, "hole_close") || InStr(r, "frontend_hole") || InStr(r, "starry_hole_close")
            || InStr(r, "dismiss") || InStr(r, "hide_overlay") || InStr(r, "internal_close")
            || InStr(r, "reset_session") || InStr(r, "abort_") || InStr(r, "request_close") || InStr(r, "idle")
            || InStr(r, "clear_gesture") || InStr(r, "gesture_clear") || InStr(r, "hide_launcher")) {
            try GDHO_DismissLauncherUI("hide_starry_after_panel:" . reason)
            try GDHO_RunStarryJS("window.HoleOverlay?.hideSilent?.()")
            if !GDHO_P0_BlockHostMoveHide("hide_starry_after_panel")
                try gui.Move(Integer(GDHO_PARK_X), Integer(GDHO_PARK_Y), Integer(GDHO_HOST_W), Integer(GDHO_HOST_H))
            GDHO_VISIBLE := false
            GDHO_ACTIVE := false
            try GDHO_Trace("hide_starry_after_panel_closed reason=" . String(reason))
            return
        }
        try GDHO_Trace("hide_starry_after_panel_keep_galaxy reason=" . String(reason))
        return
    }
    try GDHO_RunStarryJS("window.HoleOverlay?.hideSilent?.()")
    if !GDHO_P0_BlockHostMoveHide("hide_starry_after_panel")
        try gui.Move(Integer(GDHO_PARK_X), Integer(GDHO_PARK_Y), Integer(GDHO_HOST_W), Integer(GDHO_HOST_H))
    GDHO_VISIBLE := false
    GDHO_ACTIVE := false
    try GDHO_Trace("hide_starry_after_panel reason=" . String(reason))
}

GDHO_CancelSelectionPreviewPanelGuards() {
    try SetTimer(GDHO_SelectionPreviewPanelGuard, 0)
    try SetTimer(GDHO_SelectionPreviewPanelGuardLate, 0)
}

GDHO_SelectionPreviewPanelGuard(*) {
    if GDHO_ShouldKeepTextHolePanel()
        return
    try GDHO_ShelvePanelHost("selection_preview_guard")
}

GDHO_SelectionPreviewPanelGuardLate(*) {
    if GDHO_ShouldKeepTextHolePanel()
        return
    try GDHO_ShelvePanelHost("selection_preview_guard_late")
}

GDHO_ArmPanelHold() {
    global g_GDHO_PanelHoldUntil, g_GDHO_PostSuckProtectUntil
    holdMs := 120000
    g_GDHO_PanelHoldUntil := A_TickCount + holdMs
    g_GDHO_PostSuckProtectUntil := A_TickCount + holdMs
    try SetTimer(SelectionSense_HideHoleAfterSelection, 0)
    GDHO_CancelSelectionPreviewPanelGuards()
    try SetTimer(GDHO_PanelDeactivateCheck, 0)
}

GDHO_TraceTopology(extra := "") {
    global GDHO_STAR_GUI, GDHO_PANEL_GUI
    starHwnd := 0, panelHwnd := 0
    try {
        if IsObject(GDHO_STAR_GUI)
            starHwnd := GDHO_STAR_GUI.Hwnd
    } catch {
    }
    try {
        if IsObject(GDHO_PANEL_GUI)
            panelHwnd := GDHO_PANEL_GUI.Hwnd
    } catch {
    }
    topo := GDHO_IsDecoupled() ? "decoupled" : "legacy"
    msg := "topology=" . topo . " star_hwnd=" . starHwnd . " panel_hwnd=" . panelHwnd
    if (extra != "")
        msg .= " " . String(extra)
    try GDHO_Trace(msg)
    catch {
        try NativeDropDiag_Log("gdho " . msg)
    }
}

GDHO_SetPanelPageUrl(url) {
    global GDHO_PANEL_PAGE_URL
    u := Trim(String(url))
    if (u != "")
        GDHO_PANEL_PAGE_URL := u
}

GDHO_SetPanelFallbackUrl(url) {
    global GDHO_PANEL_FALLBACK_URL
    u := Trim(String(url))
    if (u != "")
        GDHO_PANEL_FALLBACK_URL := u
}

GDHO_GetStarryGui() {
    global GDHO_STAR_GUI, GDHO_GUI
    if GDHO_IsDecoupled() {
        if IsObject(GDHO_STAR_GUI)
            return GDHO_STAR_GUI
        return 0
    }
    return GDHO_GUI
}

GDHO_GetPanelGui() {
    global GDHO_PANEL_GUI
    return IsObject(GDHO_PANEL_GUI) ? GDHO_PANEL_GUI : 0
}

GDHO_ShouldStarryWindowReceiveClicks(reason := "") {
    global g_GDHO_StarryLauncherOpen, g_GDHO_TextHolePanelLocked, g_GDHO_UserTextHolePanelEngaged
    if FuncExists("GDHO_P2_IsEnabled") && GDHO_P2_IsEnabled()
        return false
    ; 方案 A 启动层：点击由独立 LAUNCHER_GUI 接收，星空宿主必须保持穿透，不能变实体
    if GDHO_UseLauncherLayer()
        return false
    if g_GDHO_StarryLauncherOpen
        return true
    if g_GDHO_TextHolePanelLocked || g_GDHO_UserTextHolePanelEngaged
        return false
    r0 := StrLower(Trim(String(reason)))
    if (InStr(r0, "launcher") || InStr(r0, "starry_launcher") || InStr(r0, "interactive") || InStr(r0, "manual"))
        return true
    return false
}

GDHO_IsLauncherLayerActive() {
    global GDHO_LAUNCHER_VISIBLE, GDHO_LAUNCHER_GUI
    if !GDHO_UseLauncherLayer() || !GDHO_LAUNCHER_VISIBLE
        return false
    if IsObject(GDHO_LAUNCHER_GUI) && GDHO_LAUNCHER_GUI.Hwnd {
        vis := false
        try vis := DllCall("IsWindowVisible", "Ptr", GDHO_LAUNCHER_GUI.Hwnd, "Int")
        catch {
            vis := true
        }
        if !vis {
            GDHO_LAUNCHER_VISIBLE := false
            return false
        }
    }
    return true
}

GDHO_ApplyStarryLauncherInteractive(reason := "") {
    global g_GDHO_StarryLauncherOpen
    if FuncExists("GDHO_P2_IsEnabled") && GDHO_P2_IsEnabled()
        return
    if GDHO_UseLauncherLayer()
        return
    g_GDHO_StarryLauncherOpen := true
    try GDHO_SetStarryClickThrough(false, "starry_launcher_interactive:" . String(reason))
    if FuncExists("GDHO_SetWebOlePassthrough")
        try GDHO_SetWebOlePassthrough(false)
    try GDHO_RunStarryJS("try{window.__gdhoOlePassthrough=false;var r=document.getElementById('root');if(r)r.classList.remove('ole-passthrough');var h=document.getElementById('holeSceneLauncher');if(h)h.style.pointerEvents='auto';if(window.HoleOverlay&&window.HoleOverlay.setOlePassthrough)window.HoleOverlay.setOlePassthrough(false);}catch(_e){}")
}

GDHO_RestoreStarryPassthroughIfIdle(reason := "") {
    global g_GDHO_StarryLauncherOpen
    if g_GDHO_StarryLauncherOpen
        return
    if FuncExists("GDHO_IsTextHoleUserPanelActive") && GDHO_IsTextHoleUserPanelActive()
        return
    if FuncExists("GDHO_IsTextDragSession") && GDHO_IsTextDragSession()
        return
    try GDHO_SetStarryClickThrough(true, "starry_passthrough_restore:" . String(reason))
}

GDHO_SetStarryClickThrough(enable := true, reason := "") {
    global GDHO_STAR_GUI, GDHO_CLICKTHROUGH
    gui := GDHO_GetStarryGui()
    if !IsObject(gui) || !gui.Hwnd
        return
    if FuncExists("GDHO_P2_IsEnabled") && GDHO_P2_IsEnabled() && GDHO_IsDecoupled() && !enable {
        try GDHO_HitTestDbgLog("blocked_unsolid_starry reason=" . Trim(String(reason)))
        enable := true
    }
    if GDHO_IsDecoupled() && GDHO_ShouldStarryWindowReceiveClicks(reason)
        enable := false
    r := Trim(String(reason))
    if (r = "")
        r := "starry_clickthrough"
    exBefore := DllCall("GetWindowLongPtr", "Ptr", gui.Hwnd, "Int", -20, "Ptr")
    req := !!enable
    ex := exBefore
    if req {
        ex := ex | 0x20
        GDHO_CLICKTHROUGH := true
    } else {
        ex := ex & ~0x20
        GDHO_CLICKTHROUGH := false
    }
    DllCall("SetWindowLongPtr", "Ptr", gui.Hwnd, "Int", -20, "Ptr", ex, "Ptr")
    try GDHO_HitTestDbgLog("SetStarryClickThrough reason=" . r . " transparent=" . (req ? "1" : "0"))
}

GDHO_CreateStarryGui() {
    global GDHO_STAR_GUI, GDHO_GUI, GDHO_DIAG_CTRL, GDHO_WM_NCHITTEST, GDHO_HOST_W, GDHO_HOST_H
    global GDHO_PARK_X, GDHO_PARK_Y, GDHO_STAR_FULLSCREEN
    OnMessage(GDHO_FRONTEND_POST_MSG, GDHO_OnFrontendPostMessage)
    hostW := Integer(GDHO_HOST_W), hostH := Integer(GDHO_HOST_H)
    if (hostW < 260)
        hostW := 260
    if (hostH < 220)
        hostH := 220
    x := Integer(GDHO_PARK_X), y := Integer(GDHO_PARK_Y)
    if GDHO_STAR_FULLSCREEN {
        GDHO_ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        x := vl, y := vt, hostW := vw, hostH := vh
    }
    GDHO_STAR_GUI := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08080020", "Global Drag Hole Starry")
    GDHO_GUI := GDHO_STAR_GUI
    GDHO_DIAG_CTRL := GDHO_STAR_GUI.AddText("Hidden x6 y6 w340 h44 BackgroundTrans c66FF66", "")
    GDHO_STAR_GUI.BackColor := "010101"
    showOpt := "x" x " y" y " w" hostW " h" hostH . " NoActivate"
    GDHO_STAR_GUI.Show(showOpt)
    try GDHO_STAR_GUI.OnMessage(GDHO_WM_NCHITTEST, GDHO_OnHostNcHitTest)
    try WinSetTransparent(255, "ahk_id " GDHO_STAR_GUI.Hwnd)
    try WinSetTransColor("010101", "ahk_id " GDHO_STAR_GUI.Hwnd)
    GDHO_SetStarryClickThrough(true, "create_starry_gui")
    GDHO_TraceTopology("create_starry")
}

GDHO_CreatePanelGui() {
    global GDHO_PANEL_GUI, GDHO_PANEL_W, GDHO_PANEL_H, GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y
    global GDHO_PARK_X, GDHO_PARK_Y, GDHO_WM_ACTIVATE, GDHO_WV2_CTRL_PANEL, GDHO_WV2_PANEL, GDHO_PANEL_READY
    global g_GDHO_PanelCreateInFlight, g_GDHO_PanelCreateStartedTick
    if IsObject(GDHO_PANEL_GUI) && GDHO_PANEL_GUI.Hwnd {
        return GDHO_PANEL_GUI
    }
    if IsObject(GDHO_WV2_CTRL_PANEL) {
        try GDHO_WV2_CTRL_PANEL.Close()
        catch {
        }
    }
    GDHO_WV2_CTRL_PANEL := 0
    GDHO_WV2_PANEL := 0
    GDHO_PANEL_READY := false
    g_GDHO_PanelCreateInFlight := false
    g_GDHO_PanelCreateStartedTick := 0
    if IsObject(GDHO_PANEL_GUI) {
        try GDHO_PANEL_GUI.Destroy()
        catch {
        }
    }
    GDHO_PANEL_GUI := 0
    pw := Integer(GDHO_PANEL_W), ph := Integer(GDHO_PANEL_H)
    if (pw < 320)
        pw := 320
    if (ph < 280)
        ph := 280
    px := Integer(GDHO_PANEL_LAST_X)
    py := Integer(GDHO_PANEL_LAST_Y)
    if (px < -5000)
        px := Integer(GDHO_PARK_X)
    if (py < -5000)
        py := Integer(GDHO_PARK_Y)
    GDHO_PANEL_GUI := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 -DPIScale", "Global Drag Hole Panel")
    GDHO_PANEL_GUI.BackColor := "0A0E14"
    GDHO_PANEL_GUI.Show("x" px " y" py " w" pw " h" ph . " Hide NA")
    try GDHO_PANEL_GUI.OnMessage(GDHO_WM_ACTIVATE, GDHO_OnPanelActivate)
    GDHO_SetPanelInteractive("create_panel_gui")
    GDHO_ApplyPanelNoActivateStyle()
    GDHO_TraceTopology("create_panel")
}

GDHO_ApplyPanelNoActivateStyle() {
    global GDHO_PANEL_GUI
    if !IsObject(GDHO_PANEL_GUI) || !GDHO_PANEL_GUI.Hwnd
        return
    try {
        ex := DllCall("GetWindowLongPtr", "Ptr", GDHO_PANEL_GUI.Hwnd, "Int", -20, "Ptr")
        ex := (ex & ~0x20) | 0x08000000
        DllCall("SetWindowLongPtr", "Ptr", GDHO_PANEL_GUI.Hwnd, "Int", -20, "Ptr", ex, "Ptr")
    } catch {
    }
}

GDHO_SetPanelInteractive(reason := "") {
    global GDHO_PANEL_GUI
    if !IsObject(GDHO_PANEL_GUI) || !GDHO_PANEL_GUI.Hwnd
        return
    try WinSetTransparent(255, "ahk_id " GDHO_PANEL_GUI.Hwnd)
    try WinSetTransColor("Off", "ahk_id " GDHO_PANEL_GUI.Hwnd)
    GDHO_ApplyPanelNoActivateStyle()
    try GDHO_HitTestDbgLog("SetPanelInteractive reason=" . Trim(String(reason)) . " transparent=0 noactivate=1")
}

GDHO_ResizeStarryHost() {
    global GDHO_STAR_GUI, GDHO_WV2_CTRL_STAR, GDHO_HOST_W, GDHO_HOST_H, GDHO_STAR_FULLSCREEN
    gui := GDHO_GetStarryGui()
    if !(IsObject(gui) && GDHO_WV2_CTRL_STAR)
        return
    if GDHO_STAR_FULLSCREEN {
        GDHO_ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        try gui.Move(vl, vt, vw, vh)
        hostW := vw, hostH := vh
    } else {
        try gui.GetPos(&gx, &gy)
        hostW := Integer(GDHO_HOST_W), hostH := Integer(GDHO_HOST_H)
        try gui.Move(gx, gy, hostW, hostH)
    }
    rc := WebView2.RECT()
    rc.left := 0, rc.top := 0, rc.right := hostW, rc.bottom := hostH
    try GDHO_WV2_CTRL_STAR.Bounds := rc
}

GDHO_ResizePanelHost() {
    global GDHO_PANEL_GUI, GDHO_WV2_CTRL_PANEL, GDHO_PANEL_W, GDHO_PANEL_H
    if !(IsObject(GDHO_PANEL_GUI) && GDHO_WV2_CTRL_PANEL)
        return
    try GDHO_PANEL_GUI.GetPos(&gx, &gy)
    pw := Integer(GDHO_PANEL_W), ph := Integer(GDHO_PANEL_H)
    try GDHO_PANEL_GUI.Move(gx, gy, pw, ph)
    rc := WebView2.RECT()
    rc.left := 0, rc.top := 0, rc.right := pw, rc.bottom := ph
    try GDHO_WV2_CTRL_PANEL.Bounds := rc
}

GDHO_ComputePanelRectFromHoleHost(hostX := "", hostY := "") {
    global GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y, GDHO_HOST_H, GDHO_PANEL_W, GDHO_PANEL_H
    hx := (hostX = "") ? Integer(GDHO_LAST_HOST_X) : Integer(hostX)
    hy := (hostY = "") ? Integer(GDHO_LAST_HOST_Y) : Integer(hostY)
    px := hx + 12
    py := hy + Integer(GDHO_HOST_H) - Integer(GDHO_PANEL_H) - 12
    if (py < hy + 12)
        py := hy + 12
    return { x: px, y: py, w: Integer(GDHO_PANEL_W), h: Integer(GDHO_PANEL_H) }
}

GDHO_SyncPanelPositionToStarry() {
    if FuncExists("GDHO_SyncLauncherLayerPosition")
        try GDHO_SyncLauncherLayerPosition()
    if GDHO_P0_BlockHostMoveHide("sync_panel_to_starry")
        return
    global GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y, GDHO_PANEL_GUI, GDHO_PANEL_PINNED
    if FuncExists("GDHO_IsPanelDragProtected") && GDHO_IsPanelDragProtected()
        return
    if !IsObject(GDHO_PANEL_GUI)
        return
    if GDHO_PANEL_PINNED
        return
    if !GDHO_IsStarryHostOnScreen()
        return
    rect := GDHO_ComputePanelRectFromHoleHost()
    px := rect.x, py := rect.y
    GDHO_PANEL_LAST_X := px
    GDHO_PANEL_LAST_Y := py
    try GDHO_PANEL_GUI.Move(px, py, rect.w, rect.h)
}

GDHO_IsStarryHostOnScreen() {
    global GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y
    hx := Integer(GDHO_LAST_HOST_X), hy := Integer(GDHO_LAST_HOST_Y)
    return (hx > -2800 && hy > -2800)
}

GDHO_EnsurePanelShowPosition(mx := "", my := "", forceNearCursor := false) {
    global GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y, GDHO_PANEL_GUI, GDHO_PANEL_PINNED
    if !IsObject(GDHO_PANEL_GUI) || GDHO_PANEL_PINNED
        return
    px := Integer(GDHO_PANEL_LAST_X), py := Integer(GDHO_PANEL_LAST_Y)
    offScreen := (px < -2800 || py < -2800 || (px = 0 && py = 0))
    staleDefault := (px <= 48 && py <= 48)
    if !(FuncExists("GDHO_IsPanelDragProtected") && GDHO_IsPanelDragProtected()) && !forceNearCursor && !staleDefault {
        if !offScreen && GDHO_IsStarryHostOnScreen() {
            px0 := px, py0 := py
            GDHO_SyncPanelPositionToStarry()
            px1 := Integer(GDHO_PANEL_LAST_X), py1 := Integer(GDHO_PANEL_LAST_Y)
            if (px1 != px0 || py1 != py0) && !(px1 <= 48 && py1 <= 48)
                return
        }
    } else if !offScreen && !staleDefault && !forceNearCursor {
        return
    }
    if (mx = "" || my = "") {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
    }
    mx := Integer(mx), my := Integer(my)
    if FuncExists("GDHO_ComputePanelRectFromAnchor") && FuncExists("GDHO_IsStarryHostOnScreen") && !GDHO_IsStarryHostOnScreen() {
        try {
            rect := GDHO_ComputePanelRectFromAnchor(mx, my)
            global GDHO_PANEL_W, GDHO_PANEL_H
            GDHO_PANEL_LAST_X := rect.x
            GDHO_PANEL_LAST_Y := rect.y
            try GDHO_PANEL_GUI.Move(rect.x, rect.y, Integer(GDHO_PANEL_W), Integer(GDHO_PANEL_H))
            return
        } catch {
        }
    }
    GDHO_SyncPanelPositionNearCursor(mx, my)
}

GDHO_SyncPanelPositionNearCursor(mx, my) {
    if GDHO_P0_BlockHostMoveHide("sync_panel_near_cursor")
        return
    global GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y, GDHO_PANEL_W, GDHO_PANEL_H, GDHO_PANEL_GUI, GDHO_PANEL_PINNED
    if FuncExists("GDHO_IsPanelDragProtected") && GDHO_IsPanelDragProtected()
        return
    if !IsObject(GDHO_PANEL_GUI) || GDHO_PANEL_PINNED
        return
    px := Integer(mx) + 20
    py := Integer(my) - Integer(GDHO_PANEL_H) // 2
    try {
        if FuncExists("GDHO_ScreenVirtual_GetBounds") {
            GDHO_ScreenVirtual_GetBounds(&waL, &waT, &waW, &waH)
            waR := waL + waW, waB := waT + waH
        } else {
            mon := MonitorGet(mx, my)
            MonitorGetWorkArea(mon, &waL, &waT, &waR, &waB)
        }
        if (px + Integer(GDHO_PANEL_W) > waR - 8)
            px := Integer(mx) - Integer(GDHO_PANEL_W) - 20
        if (px < waL + 8)
            px := waL + 8
        if (py < waT + 8)
            py := waT + 8
        if (py + Integer(GDHO_PANEL_H) > waB - 8)
            py := waB - Integer(GDHO_PANEL_H) - 8
    } catch {
    }
    GDHO_PANEL_LAST_X := px
    GDHO_PANEL_LAST_Y := py
    try GDHO_PANEL_GUI.Move(px, py, Integer(GDHO_PANEL_W), Integer(GDHO_PANEL_H))
}

; 拖动时只移动宿主位置，绝不改宽高（改宽高会导致面板越拖越小然后消失）。
GDHO_MovePanelHostScreen(sx, sy) {
    dragMove := false
    if FuncExists("GDHO_IsPanelDragProtected") {
        try dragMove := GDHO_IsPanelDragProtected()
        catch {
        }
    }
    if !dragMove && GDHO_P0_BlockHostMoveHide("move_panel_host_screen") {
        try GDHO_WS_Send("pointer_move", sx, sy)
        return
    }
    global GDHO_PANEL_GUI, GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y, GDHO_PANEL_W, GDHO_PANEL_H, GDHO_PANEL_PINNED
    global GDHO_PANEL_VISIBLE, g_GDHO_PanelDragBaseW, g_GDHO_PanelDragBaseH
    if !IsObject(GDHO_PANEL_GUI) || GDHO_PANEL_PINNED
        return
    x := Integer(sx), y := Integer(sy)
    pw := Integer(g_GDHO_PanelDragBaseW > 0 ? g_GDHO_PanelDragBaseW : GDHO_PANEL_W)
    ph := Integer(g_GDHO_PanelDragBaseH > 0 ? g_GDHO_PanelDragBaseH : GDHO_PANEL_H)
    if (pw < 320)
        pw := 320
    if (ph < 280)
        ph := 280
    try {
        if FuncExists("GDHO_ScreenVirtual_GetBounds") {
            GDHO_ScreenVirtual_GetBounds(&waL, &waT, &waW, &waH)
            waR := waL + waW, waB := waT + waH
        } else {
            mon := MonitorGet(x, y)
            MonitorGetWorkArea(mon, &waL, &waT, &waR, &waB)
        }
        if (x + pw > waR - 8)
            x := waR - pw - 8
        if (y + ph > waB - 8)
            y := waB - ph - 8
        if (x < waL + 8)
            x := waL + 8
        if (y < waT + 8)
            y := waT + 8
    } catch {
    }
    GDHO_PANEL_LAST_X := x
    GDHO_PANEL_LAST_Y := y
    hwnd := GDHO_PANEL_GUI.Hwnd
    if hwnd {
        ; SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE — 避免 Gui.Move 在 WebView2 上触发布局/透明异常
        try DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", 0, "Int", 0, "UInt", 0x0015)
        catch {
            try GDHO_PANEL_GUI.Move(x, y, pw, ph)
        }
    } else {
        try GDHO_PANEL_GUI.Move(x, y, pw, ph)
    }
    if !GDHO_PANEL_VISIBLE {
        try GDHO_PANEL_GUI.Show("NA x" . x . " y" . y . " w" . pw . " h" . ph)
        GDHO_PANEL_VISIBLE := true
    }
    try GDHO_SetPanelInteractive("panel_moved")
}

GDHO_ApplyPanelHostScreenRect(sx, sy, sw := "", sh := "") {
    if GDHO_P0_BlockHostMoveHide("apply_panel_host_rect") {
        try GDHO_WS_Send("pointer_move", sx, sy)
        return
    }
    if FuncExists("GDHO_IsPanelDragProtected") && GDHO_IsPanelDragProtected() {
        try GDHO_MovePanelHostScreen(sx, sy)
        return
    }
    global GDHO_PANEL_GUI, GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y, GDHO_PANEL_W, GDHO_PANEL_H, GDHO_PANEL_PINNED
    if !IsObject(GDHO_PANEL_GUI) || GDHO_PANEL_PINNED
        return
    x := Integer(sx), y := Integer(sy)
    pw := Integer(GDHO_PANEL_W), ph := Integer(GDHO_PANEL_H)
    if (sw != "" && Integer(sw) >= 280)
        pw := Integer(sw)
    if (sh != "" && Integer(sh) >= 200)
        ph := Integer(sh)
    try {
        if FuncExists("GDHO_ScreenVirtual_GetBounds") {
            GDHO_ScreenVirtual_GetBounds(&waL, &waT, &waW, &waH)
            waR := waL + waW, waB := waT + waH
        } else {
            mon := MonitorGet(x, y)
            MonitorGetWorkArea(mon, &waL, &waT, &waR, &waB)
        }
        if (x + pw > waR - 8)
            x := waR - pw - 8
        if (y + ph > waB - 8)
            y := waB - ph - 8
        if (x < waL + 8)
            x := waL + 8
        if (y < waT + 8)
            y := waT + 8
    } catch {
    }
    GDHO_PANEL_LAST_X := x
    GDHO_PANEL_LAST_Y := y
    GDHO_PANEL_W := pw
    GDHO_PANEL_H := ph
    try GDHO_PANEL_GUI.Move(x, y, pw, ph)
    try GDHO_ResizePanelHost()
}

GDHO_ClearTextDragHandoff(cancelPostSuckTimer := true) {
    global g_GDHO_TextDragHandoffDone, g_GDHO_PostSuckPanelPending, g_GDHO_PostSuckTimerArmed
    global g_GDHO_PendingPanelText, g_GDHO_PostSuckProtectUntil
    if (cancelPostSuckTimer && GDHO_IsPostSuckProtected())
        cancelPostSuckTimer := false
    g_GDHO_TextDragHandoffDone := false
    if cancelPostSuckTimer {
        g_GDHO_PostSuckPanelPending := false
        g_GDHO_PostSuckTimerArmed := false
        g_GDHO_PostSuckProtectUntil := 0
        g_GDHO_PendingPanelText := ""
        try SetTimer(GDHO_PostSuckPanelTimer, 0)
    }
}

GDHO_FlushPendingPanelText() {
    try GDHO_SyncPanelCapturedPreview()
}

GDHO_ArmPostSuckPanelTimer(reason := "") {
    global g_GDHO_PostSuckTimerArmed, g_GDHO_PostSuckProtectUntil, g_GDHO_PostSuckPresentDone
    global g_GDHO_PostSuckPanelPending, g_GDHO_PendingPanelShow
    if !GDHO_IsDecoupled()
        return
    r0 := StrLower(Trim(String(reason)))
    if InStr(r0, "text_hole")
        return
    if (g_GDHO_PostSuckPresentDone && GDHO_PANEL_VISIBLE && GDHO_IsTextHolePanelOpen())
        return
    if !(g_GDHO_PostSuckPanelPending || g_GDHO_PendingPanelShow)
        g_GDHO_PostSuckPresentDone := false
    g_GDHO_PostSuckTimerArmed := true
    g_GDHO_PostSuckProtectUntil := A_TickCount + 5000
    ; P1: 吸入动画期间并行创建 panel WebView2（物理吸入不走 CommitTextHoleToPanel）。
    try GDHO_EnsurePanelHostForPhase("analyzing")
    try SetTimer(GDHO_PostSuckPanelTimer, 0)
    delayMs := Integer(GDHO_TEXT_HOLE_EXPAND_MS) + 320
    if (delayMs < 1500)
        delayMs := 1500
    SetTimer(GDHO_PostSuckPanelTimer, -delayMs)
    try NativeDropDiag_Log("[PostSuck] arm_timer reason=" . String(reason))
    try GDHO_Trace("arm_post_suck_panel reason=" . String(reason))
}

GDHO_PostSuckPanelTimer(*) {
    global g_GDHO_PostSuckTimerArmed, GDHO_SESSION_TEXT, GDHO_CURSOR_X, GDHO_CURSOR_Y, g_GDHO_PostSuckPresentDone
    global NativeDropSeedText, g_GDHO_PendingPanelShow, GDHO_PANEL_VISIBLE
    g_GDHO_PostSuckTimerArmed := false
    if !GDHO_IsDecoupled()
        return
    if (g_GDHO_PendingPanelShow && !GDHO_PANEL_VISIBLE) {
        try GDHO_EnsureDecoupledPanelWebHost()
        try NativeDropDiag_Log("[PostSuck] timer_skip reason=awaiting_panel_nav")
        return
    }
    if g_GDHO_PostSuckPresentDone {
        try NativeDropDiag_Log("[PostSuck] timer_skip reason=present_done")
        return
    }
    txt := ""
    try txt := Trim(String(GDHO_SESSION_TEXT))
    if (txt = "")
        try txt := Trim(String(NativeDropSeedText))
    if (txt = "") && FuncExists("SelectionSense_GetLastSelectedText")
        try txt := Trim(SelectionSense_GetLastSelectedText())
    try NativeDropDiag_Log("[PostSuck] timer_fire len=" . StrLen(txt))
    if (g_GDHO_PostSuckPresentDone && GDHO_PANEL_VISIBLE && GDHO_IsTextHolePanelOpen()) {
        try NativeDropDiag_Log("[PostSuck] timer_skip reason=panel_already_shown")
        return
    }
    if (txt != "" && Integer(g_GDHO_TextHoleSessionSerial) <= 0) {
        global g_GDHO_TextHoleSessionSerial, g_GDHO_TextHoleCommitSerial, g_GDHO_TextHoleCommitDone, g_GDHO_TextHoleAwaitingExpand
        g_GDHO_TextHoleSessionSerial := 1
        g_GDHO_TextHoleCommitSerial := 1
        g_GDHO_TextHoleCommitDone := true
        g_GDHO_TextHoleAwaitingExpand := false
        if FuncExists("GDHO_StampTextHoleCapturedText")
            try GDHO_StampTextHoleCapturedText(txt)
        GDHO_SESSION_TEXT := txt
        try NativeDropDiag_Log("[PostSuck] timer_rearm_session len=" . StrLen(txt))
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mxT, &myT)
    if (Integer(GDHO_CURSOR_X) < -2000 || Integer(GDHO_CURSOR_Y) < -2000 || (Integer(GDHO_CURSOR_X) = 0 && Integer(GDHO_CURSOR_Y) = 0)) {
        GDHO_CURSOR_X := mxT
        GDHO_CURSOR_Y := myT
    }
    GDHO_PresentPanelAfterTextHoleDrop(txt, GDHO_CURSOR_X, GDHO_CURSOR_Y, "post_suck_timer", Integer(g_GDHO_TextHoleSessionSerial))
}

; 黑洞吸入动画结束后：藏星空、显示输入面板并填入文本。
GDHO_TextHoleExpandFallback(*) {
    global g_GDHO_TextHoleAwaitingExpand, GDHO_SESSION_TEXT, GDHO_CURSOR_X, GDHO_CURSOR_Y
    global g_GDHO_TextHoleFallbackSessionId, g_GDHO_TextHoleSessionSerial
    sid := Integer(g_GDHO_TextHoleFallbackSessionId)
    if (sid <= 0)
        sid := Integer(g_GDHO_TextHoleSessionSerial)
    if (sid <= 0 || sid != Integer(g_GDHO_TextHoleSessionSerial))
        return
    if !GDHO_TextHolePresentAllowed()
        return
    GDHO_TextHoleTransition(GDHO_TEXT_HOLE_STATE_EXPANDING, "expand_fallback", "", "")
    try NativeDropDiag_Log("[PostSuck] expand_complete sid=" . sid . " source=fallback")
    t := GDHO_GetTextHoleCapturedText()
    if (t != "")
        GDHO_SESSION_TEXT := t
    GDHO_PresentPanelAfterTextHoleDrop(t, GDHO_CURSOR_X, GDHO_CURSOR_Y, "expand_fallback", sid)
}

GDHO_TextHoleExpandCompleteEnsure(*) {
    global g_GDHO_TextHoleExpandCompleteSessionId, g_GDHO_TextHoleSessionSerial
    global g_GDHO_TextHoleCommitSerial, g_GDHO_TextHoleAwaitingExpand, g_GDHO_TextHoleCommitDone, GDHO_SESSION_TEXT
    sid := Integer(g_GDHO_TextHoleExpandCompleteSessionId)
    if (sid <= 0 || sid != Integer(g_GDHO_TextHoleSessionSerial))
        return
    if (IsSet(GDHO_PANEL_VISIBLE) && GDHO_PANEL_VISIBLE)
        return
    t := ""
    if FuncExists("GDHO_GetTextHoleCapturedText")
        try t := Trim(String(GDHO_GetTextHoleCapturedText()))
    if (t = "")
        try t := Trim(String(GDHO_SESSION_TEXT))
    if (t = "")
        return
    if !GDHO_TextHolePresentAllowed() {
        g_GDHO_TextHoleCommitSerial := g_GDHO_TextHoleSessionSerial
        g_GDHO_TextHoleAwaitingExpand := true
        g_GDHO_TextHoleCommitDone := true
    }
    try NativeDropDiag_Log("[PostSuck] expand_complete_ensure sid=" . sid . " len=" . StrLen(t))
    GDHO_PresentPanelAfterTextHoleDrop(t, GDHO_CURSOR_X, GDHO_CURSOR_Y, "expand_complete_ensure", sid)
}

GDHO_PresentPanelAfterTextHoleDrop(txt := "", mx := "", my := "", reason := "post_suck_panel", sessionId := 0) {
    global g_GDHO_PostSuckPanelPending, g_GDHO_TextDragHandoffDone, g_GDHO_OpenPayload
    global GDHO_PAYLOAD, GDHO_CURSOR_X, GDHO_CURSOR_Y, GDHO_ACTIVE, GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y
    global g_GDHO_TextHoleAwaitingExpand, g_GDHO_TextHolePanelOpen, g_GDHO_TextHoleCapturedText, g_GDHO_TextHoleStickyPanel
    global g_GDHO_PostSuckPresentDone, g_GDHO_TextHoleSessionSerial, g_GDHO_TextHolePresentedSessionId
    if !GDHO_IsDecoupled()
        return false
    sid := Integer(sessionId)
    if (sid <= 0)
        sid := Integer(g_GDHO_TextHoleSessionSerial)
    if (sid > 0 && Integer(g_GDHO_TextHoleSessionSerial) > 0 && sid != Integer(g_GDHO_TextHoleSessionSerial)) {
        try NativeDropDiag_Log("[PostSuck] present_skip reason=stale_sid sid=" . sid . " current_sid=" . Integer(g_GDHO_TextHoleSessionSerial) . " source=" . String(reason))
        return false
    }
    if ((g_GDHO_TextHolePresentedSessionId = sid || g_GDHO_PostSuckPresentDone) && GDHO_PANEL_VISIBLE && GDHO_IsTextHolePanelOpen()) {
        try GDHO_SyncPanelCapturedPreview()
        try NativeDropDiag_Log("[PostSuck] present_skip reason=already_presented sid=" . sid . " source=" . String(reason))
        return true
    }
    if (g_GDHO_PostSuckPresentDone && GDHO_PANEL_VISIBLE) {
        try NativeDropDiag_Log("[PostSuck] present_skip reason=panel_visible source=" . String(reason))
        return true
    }
    global g_GDHO_PendingPanelShow, g_GDHO_PendingPanelShowSince
    if (g_GDHO_PendingPanelShow && !GDHO_PANEL_VISIBLE && g_GDHO_PendingPanelShowSince > 0
        && (A_TickCount - g_GDHO_PendingPanelShowSince) < 6000) {
        try GDHO_EnsureDecoupledPanelWebHost()
        try NativeDropDiag_Log("[PostSuck] present_skip reason=awaiting_panel_nav source=" . String(reason))
        return false
    }
    if !GDHO_TextHolePresentAllowed() {
        tRecover := Trim(String(txt))
        if (tRecover = "")
            tRecover := GDHO_GetTextHoleCapturedText()
        if (tRecover != "") {
            global g_GDHO_TextHoleCommitSerial, g_GDHO_TextHoleAwaitingExpand, g_GDHO_TextHoleCommitDone
            if (Integer(g_GDHO_TextHoleSessionSerial) <= 0)
                g_GDHO_TextHoleSessionSerial := 1
            g_GDHO_TextHoleCommitSerial := g_GDHO_TextHoleSessionSerial
            g_GDHO_TextHoleAwaitingExpand := true
            g_GDHO_TextHoleCommitDone := true
            g_GDHO_TextHoleCapturedText := tRecover
            GDHO_SESSION_TEXT := tRecover
            try NativeDropDiag_Log("[PostSuck] present_rearm_session sid=" . Integer(g_GDHO_TextHoleSessionSerial) . " source=" . String(reason))
        } else {
            try NativeDropDiag_Log("[PostSuck] present_skip reason=stale_session sid=" . sid . " source=" . String(reason))
            GDHO_TextHoleLogSnapshot("present_skip", String(reason))
            return false
        }
    }
    t := Trim(String(txt))
    if (t = "")
        t := GDHO_GetTextHoleCapturedText()
    if FuncExists("GDHO_RefreshTextHoleCapturedTextFromSelection")
        try t := GDHO_RefreshTextHoleCapturedTextFromSelection(4)
    if (mx = "" || my = "") {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
    }
    mx := Integer(mx), my := Integer(my)
    if (mx < -2000 || my < -2000 || (mx = 0 && my = 0)) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
    }
    try NativeDropDiag_Log("[PostSuck] present_begin sid=" . sid . " reason=" . String(reason) . " host_x=" . Integer(GDHO_LAST_HOST_X) . " host_y=" . Integer(GDHO_LAST_HOST_Y) . " cursor_x=" . mx . " cursor_y=" . my)
    GDHO_DisarmTextHoleCommitWatch()
    g_GDHO_TextHoleAwaitingExpand := false
    try SetTimer(GDHO_TextHoleExpandFallback, 0)
    GDHO_CURSOR_X := mx
    GDHO_CURSOR_Y := my
    try GDHO_RememberOnScreenHoleCenter(mx, my)
    g_GDHO_PostSuckPanelPending := true
    g_GDHO_TextHolePanelOpen := true
    g_GDHO_TextHoleStickyPanel := true
    g_GDHO_SuppressSelectionAutoHide := true
    g_GDHO_TextHoleCapturedText := t
    GDHO_SESSION_TEXT := t
    g_GDHO_TextDragHandoffDone := true
    if FuncExists("GDHO_EndSelectionPreviewForPanel")
        GDHO_EndSelectionPreviewForPanel()
    pl := Map(
        "reason", "text_post_suck_panel",
        "payload", "text",
        "screenX", mx,
        "screenY", my,
        "positionMode", "relative",
        "weakPreview", false
    )
    if FuncExists("GDHO_StampOpenPayload")
        GDHO_StampOpenPayload(pl)
    else
        g_GDHO_OpenPayload := pl
    GDHO_PAYLOAD := "text"
    GDHO_ACTIVE := true
    try SetTimer(SelectionSense_HideHoleAfterSelection, 0)
    if !GDHO_IsStarryLauncherMode()
        try GDHO_EnsurePanelHostForPhase("resulting")
    global g_GDHO_PendingPanelText
    g_GDHO_PendingPanelText := (t != "") ? t : ""
    if !GDHO_PresentLauncherAfterExpand(t, mx, my, reason, sid) {
        global g_GDHO_TextHolePresentRetryArmed
        if !g_GDHO_TextHolePresentRetryArmed {
            g_GDHO_TextHolePresentRetryArmed := true
            try SetTimer(GDHO_TextHolePresentRetry, -450)
        }
        return false
    }
    g_GDHO_PostSuckPresentDone := true
    g_GDHO_TextHolePresentedSessionId := sid
    GDHO_CancelTextHolePresentTimers()
    try NativeDropDiag_Log("[PostSuck] present_done sid=" . sid . " len=" . StrLen(t) . " reason=" . String(reason) . " mode=" . GDHO_GetTextHoleLauncherMode())
    if FuncExists("GDHO_WS_SendPanelPresent")
        try GDHO_WS_SendPanelPresent(mx, my, t)
    GDHO_TextHoleTransition(GDHO_TEXT_HOLE_STATE_PANEL_SHOWN, String(reason), "", StrLen(t))
    GDHO_ArmPanelHold()
    try GDHO_Trace("present_launcher len=" . StrLen(t) . " reason=" . String(reason))
    GDHO_TraceTopology("present_launcher")
    return true
}

GDHO_PendingPanelShowPump(*) {
    global g_GDHO_PendingPanelShow, g_GDHO_PendingPanelShowReason, g_GDHO_PendingPanelShowSince, GDHO_PANEL_READY
    if !g_GDHO_PendingPanelShow
        return
    if GDHO_PANEL_READY {
        r := g_GDHO_PendingPanelShowReason
        g_GDHO_PendingPanelShow := false
        if InStr(StrLower(r), "overlay") || InStr(StrLower(r), "present_panel") || InStr(StrLower(r), "present_launcher")
            GDHO_ShowPanelOverlayForced(r)
        else
            GDHO_ShowPanelForced(r)
        return
    }
    if (g_GDHO_PendingPanelShowSince > 0 && (A_TickCount - g_GDHO_PendingPanelShowSince) < 9000)
        SetTimer(GDHO_PendingPanelShowPump, -160)
    else {
        try NativeDropDiag_Log("[PostSuck] pending_panel_show_timeout reason=" . g_GDHO_PendingPanelShowReason)
        global g_GDHO_PanelCreateInFlight
        g_GDHO_PanelCreateInFlight := false
        try GDHO_EnsurePanelHostForPhase("resulting")
        g_GDHO_PendingPanelShowSince := A_TickCount
        SetTimer(GDHO_PendingPanelShowPump, -200)
    }
}

GDHO_ShowPanelWhenReady(reason := "") {
    global GDHO_PANEL_READY, g_GDHO_PendingPanelShow, g_GDHO_PendingPanelShowReason, g_GDHO_PendingPanelShowSince
    g_GDHO_PendingPanelShowReason := Trim(String(reason))
    if GDHO_PANEL_READY {
        g_GDHO_PendingPanelShow := false
        GDHO_ShowPanelForced(g_GDHO_PendingPanelShowReason)
        return true
    }
    g_GDHO_PendingPanelShow := true
    g_GDHO_PendingPanelShowSince := A_TickCount
    GDHO_EnsurePanelWebWarm()
    try NativeDropDiag_Log("[PostSuck] defer_panel_show reason=" . g_GDHO_PendingPanelShowReason)
    try SetTimer(GDHO_PendingPanelShowPump, 0)
    SetTimer(GDHO_PendingPanelShowPump, -160)
    return false
}

GDHO_NotifyPanelHostPresent(text := "") {
    global GDHO_WV2_PANEL, GDHO_PANEL_READY
    if !(GDHO_PANEL_READY && IsObject(GDHO_WV2_PANEL))
        return false
    t := Trim(String(text))
    if (t != "") {
        te := StrReplace(t, "\", "\\")
        te := StrReplace(te, "`"", "\`"")
        te := StrReplace(te, "`r", "\r")
        te := StrReplace(te, "`n", "\n")
        payload := '{"type":"host_present","text":"' . te . '"}'
    } else
        payload := '{"type":"host_present"}'
    try {
        GDHO_WV2_PANEL.PostWebMessageAsJson(payload)
        return true
    } catch {
        return false
    }
}

GDHO_GetTextHoleLauncherMode() {
    static mode := ""
    if (mode != "")
        return mode
    mode := "starry"
    try {
        cf := A_ScriptDir . "\CursorShortcut.ini"
        if FileExist(cf) {
            v := StrLower(Trim(IniRead(cf, "TextHole", "launcher_mode", "starry")))
            if (v = "starry" || v = "panel" || v = "both" || v = "a" || v = "b")
                mode := (v = "a") ? "starry" : ((v = "b") ? "panel" : v)
        }
    } catch {
    }
    return mode
}

GDHO_IsStarryLauncherMode() {
    return (GDHO_GetTextHoleLauncherMode() = "starry")
}

GDHO_UseLauncherLayer() {
    m := GDHO_GetTextHoleLauncherMode()
    return (m = "starry" || m = "both")
}

GDHO_MarkTextHoleExpandedHold() {
    global GDHO_IS_SUCKING, GDHO_EXPANDED_HOLD, GDHO_VISIBLE, GDHO_ACTIVE
    GDHO_IS_SUCKING := true
    GDHO_EXPANDED_HOLD := true
    GDHO_VISIBLE := true
    GDHO_ACTIVE := true
    try GDHO_SyncHoleCenterFromStarryWindow()
}

GDHO_IsHostParkedPos(x, y) {
    global GDHO_PARK_X, GDHO_PARK_Y
    ix := Integer(x), iy := Integer(y)
    if (ix < -5000 || iy < -5000)
        return true
    return (Abs(ix - Integer(GDHO_PARK_X)) < 80 && Abs(iy - Integer(GDHO_PARK_Y)) < 80)
}

GDHO_RememberOnScreenHoleCenter(cx, cy) {
    global g_GDHO_LastOnScreenHoleCx, g_GDHO_LastOnScreenHoleCy
    x := Integer(cx), y := Integer(cy)
    if (x > 50 && y > 50 && !GDHO_IsHostParkedPos(x, y)) {
        g_GDHO_LastOnScreenHoleCx := x
        g_GDHO_LastOnScreenHoleCy := y
    }
}

GDHO_GetRememberedHoleCenter() {
    global g_GDHO_LastOnScreenHoleCx, g_GDHO_LastOnScreenHoleCy, GDHO_CURSOR_X, GDHO_CURSOR_Y
    if (g_GDHO_LastOnScreenHoleCx > 50 && g_GDHO_LastOnScreenHoleCy > 50)
        return { x: g_GDHO_LastOnScreenHoleCx, y: g_GDHO_LastOnScreenHoleCy }
    mx := Integer(GDHO_CURSOR_X), my := Integer(GDHO_CURSOR_Y)
    if (mx > 50 && my > 50)
        return { x: mx, y: my }
    return { x: 0, y: 0 }
}

GDHO_EnsureStarryOnScreenForLauncher() {
    global GDHO_STAR_GUI, GDHO_STAR_FULLSCREEN, GDHO_HOST_W, GDHO_HOST_H
    global GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y, GDHO_VISIBLE, GDHO_ACTIVE
    gui := GDHO_GetStarryGui()
    if !IsObject(gui) || !gui.Hwnd
        return false
    sx := 0, sy := 0, sw := 0, sh := 0
    try WinGetPos(&sx, &sy, &sw, &sh, "ahk_id " gui.Hwnd)
    if !GDHO_IsHostParkedPos(sx, sy)
        return true
    if GDHO_STAR_FULLSCREEN {
        GDHO_ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        if !(FuncExists("GDHO_P0_BlockHostMoveHide") && GDHO_P0_BlockHostMoveHide("ensure_starry_for_launcher"))
            try gui.Move(vl, vt, vw, vh)
        GDHO_LAST_HOST_X := vl
        GDHO_LAST_HOST_Y := vt
        GDHO_HOST_W := vw
        GDHO_HOST_H := vh
    } else {
        c := GDHO_GetRememberedHoleCenter()
        if (c.x < 50)
            return false
        hw := Integer(GDHO_HOST_W), hh := Integer(GDHO_HOST_H)
        if (hw < 260)
            hw := 260
        if (hh < 220)
            hh := 220
        nx := c.x - (hw // 2), ny := c.y - (hh // 2)
        if !(FuncExists("GDHO_P0_BlockHostMoveHide") && GDHO_P0_BlockHostMoveHide("ensure_starry_for_launcher"))
            try gui.Move(nx, ny, hw, hh)
        GDHO_LAST_HOST_X := nx
        GDHO_LAST_HOST_Y := ny
    }
    GDHO_VISIBLE := true
    GDHO_ACTIVE := true
    try gui.Show("NA")
    try GDHO_ResizeStarryHost()
    return true
}

GDHO_SyncHoleCenterFromStarryWindow() {
    global GDHO_STAR_GUI, GDHO_CX, GDHO_CY, GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y, GDHO_HOST_W, GDHO_HOST_H
    if IsObject(GDHO_STAR_GUI) && GDHO_STAR_GUI.Hwnd {
        try {
            WinGetPos(&sx, &sy, &sw, &sh, "ahk_id " GDHO_STAR_GUI.Hwnd)
            if !GDHO_IsHostParkedPos(sx, sy) {
                GDHO_CX := sx + (sw // 2)
                GDHO_CY := sy + (sh // 2)
                GDHO_LAST_HOST_X := sx
                GDHO_LAST_HOST_Y := sy
                GDHO_HOST_W := sw
                GDHO_HOST_H := sh
                try GDHO_RememberOnScreenHoleCenter(GDHO_CX, GDHO_CY)
                return
            }
        } catch {
        }
    }
    rem := GDHO_GetRememberedHoleCenter()
    if (rem.x > 50) {
        GDHO_CX := rem.x
        GDHO_CY := rem.y
        return
    }
    lx := Integer(GDHO_LAST_HOST_X), ly := Integer(GDHO_LAST_HOST_Y)
    if !GDHO_IsHostParkedPos(lx, ly) {
        GDHO_CX := lx + (Integer(GDHO_HOST_W) // 2)
        GDHO_CY := ly + (Integer(GDHO_HOST_H) // 2)
        return
    }
}

GDHO_ApplyLauncherNoActivateStyle() {
    global GDHO_LAUNCHER_GUI
    if !IsObject(GDHO_LAUNCHER_GUI) || !GDHO_LAUNCHER_GUI.Hwnd
        return
    try {
        ex := DllCall("GetWindowLongPtr", "Ptr", GDHO_LAUNCHER_GUI.Hwnd, "Int", -20, "Ptr")
        ex := (ex & ~0x20) | 0x08000000 ; WS_EX_NOACTIVATE：显示启动层不抢前台，避免最大化窗口被系统还原
        DllCall("SetWindowLongPtr", "Ptr", GDHO_LAUNCHER_GUI.Hwnd, "Int", -20, "Ptr", ex, "Ptr")
    } catch {
    }
}

GDHO_ApplyLauncherLayerInteractive(reason := "") {
    global GDHO_LAUNCHER_GUI
    if !IsObject(GDHO_LAUNCHER_GUI) || !GDHO_LAUNCHER_GUI.Hwnd
        return
    hwnd := GDHO_LAUNCHER_GUI.Hwnd
    try WinSetTransColor("Off", "ahk_id " hwnd)
    try WinSetTransparent(255, "ahk_id " hwnd)
    try GDHO_ApplyLauncherNoActivateStyle()
    try {
        ex := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr")
        ex := ex & ~0x20
        DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr", ex, "Ptr")
    } catch {
    }
    if FuncExists("GDHO_SetWebOlePassthrough")
        try GDHO_SetWebOlePassthrough(false)
    try GDHO_HitTestDbgLog("ApplyLauncherLayerInteractive reason=" . Trim(String(reason)))
}

GDHO_DismissLauncherUI(reason := "") {
    global g_GDHO_StarryLauncherOpen, g_GDHO_PendingLauncherShow, g_GDHO_LauncherGridSent
    g_GDHO_StarryLauncherOpen := false
    g_GDHO_PendingLauncherShow := false
    g_GDHO_LauncherGridSent := false
    try GDHO_SuppressEmbeddedStarryLauncher()
    if GDHO_UseLauncherLayer() {
        try GDHO_HideLauncherLayer("dismiss_ui:" . String(reason))
        catch {
        }
    }
    if FuncExists("GDHO_ClearGestureHolePresentation") {
        try GDHO_ClearGestureHolePresentation("dismiss_launcher:" . String(reason))
        catch {
        }
    }
}

GDHO_SuppressEmbeddedStarryLauncher() {
    try GDHO_RunStarryJS("try{window.__gdhoUseLauncherLayer=true;var r=document.getElementById('root');if(r)r.classList.add('use-external-launcher');var h=document.getElementById('holeSceneLauncher');if(h){h.classList.remove('visible');h.style.display='none';h.style.visibility='hidden';h.style.opacity='0';h.style.pointerEvents='none';}if(window.HoleOverlay&&window.HoleOverlay.hideSceneLauncher)window.HoleOverlay.hideSceneLauncher();}catch(_e){}")
}

GDHO_SetLauncherFallbackUrl(url) {
    global GDHO_LAUNCHER_FALLBACK_URL
    u := Trim(String(url))
    if (u != "")
        GDHO_LAUNCHER_FALLBACK_URL := u
}

GDHO_ResolveLauncherPageUrl() {
    global GDHO_LAUNCHER_FALLBACK_URL, GDHO_LAUNCHER_PAGE_URL
    if (Trim(String(GDHO_LAUNCHER_FALLBACK_URL)) != "")
        return Trim(String(GDHO_LAUNCHER_FALLBACK_URL))
    u := Trim(String(GDHO_LAUNCHER_PAGE_URL))
    if (InStr(u, "127.0.0.1:5173") || InStr(u, "localhost:5173"))
        u := ""
    ; 优先 app.local（UnifiedAssetsRoot=A_ScriptDir，映射 hole_launcher_layer.html + assets/*）
    if (u = "") && FileExist(A_ScriptDir . "\hole_launcher_layer.html")
        u := "https://app.local/hole_launcher_layer.html"
    if (u = "") && FileExist(A_ScriptDir . "\hole_launcher_layer.html") {
        if FuncExists("GDHO_BuildFileUrl")
            try u := GDHO_BuildFileUrl(A_ScriptDir . "\hole_launcher_layer.html")
        if (u = "")
            u := "file:///" . StrReplace(A_ScriptDir . "\hole_launcher_layer.html", "\", "/")
    }
    return u
}

GDHO_ComputeLauncherRectFromHole(diameter := 440) {
    return GDHO_ComputePanelRectCenteredOnHole(diameter)
}

GDHO_CreateLauncherGui() {
    global GDHO_LAUNCHER_GUI, GDHO_LAUNCHER_W, GDHO_LAUNCHER_H, GDHO_STAR_GUI
    if IsObject(GDHO_LAUNCHER_GUI) && GDHO_LAUNCHER_GUI.Hwnd
        return GDHO_LAUNCHER_GUI
    lw := Integer(GDHO_LAUNCHER_W), lh := Integer(GDHO_LAUNCHER_H)
    if (lw < 360)
        lw := 360
    if (lh < 360)
        lh := 360
    rect := GDHO_ComputeLauncherRectFromHole(lw)
    GDHO_LAUNCHER_GUI := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 -DPIScale", "Global Drag Hole Launcher")
    GDHO_LAUNCHER_GUI.BackColor := "010101"
    GDHO_LAUNCHER_GUI.Show("x" rect.x " y" rect.y " w" rect.w " h" rect.h . " Hide NA")
    try GDHO_ApplyLauncherLayerInteractive("create_launcher_gui")
    GDHO_LAUNCHER_VISIBLE := false
    try GDHO_TraceTopology("create_launcher_layer")
    return GDHO_LAUNCHER_GUI
}

GDHO_ResizeLauncherHost() {
    global GDHO_LAUNCHER_GUI, GDHO_WV2_CTRL_LAUNCHER, GDHO_LAUNCHER_W, GDHO_LAUNCHER_H
    if !(IsObject(GDHO_LAUNCHER_GUI) && GDHO_WV2_CTRL_LAUNCHER)
        return
    rect := GDHO_ComputeLauncherRectFromHole(Integer(GDHO_LAUNCHER_W))
    try GDHO_LAUNCHER_GUI.Move(rect.x, rect.y, rect.w, rect.h)
    pw := Integer(rect.w), ph := Integer(rect.h)
    rc := WebView2.RECT()
    rc.left := 0, rc.top := 0, rc.right := pw, rc.bottom := ph
    try GDHO_WV2_CTRL_LAUNCHER.Bounds := rc
}

GDHO_SyncLauncherLayerPosition() {
    global GDHO_LAUNCHER_GUI, GDHO_LAUNCHER_VISIBLE
    if !GDHO_LAUNCHER_VISIBLE || !IsObject(GDHO_LAUNCHER_GUI)
        return
    rect := GDHO_ComputeLauncherRectFromHole(Integer(GDHO_LAUNCHER_W))
    try GDHO_LAUNCHER_GUI.Move(rect.x, rect.y, rect.w, rect.h)
    try GDHO_ResizeLauncherHost()
}

GDHO_ApplyStarryHostChildPassthrough(enable := true, reason := "") {
    global GDHO_STAR_GUI
    gui := GDHO_GetStarryGui()
    if !IsObject(gui) || !gui.Hwnd
        return
    want := !!enable
    hwnd := DllCall("GetWindow", "Ptr", gui.Hwnd, "UInt", 5, "Ptr")
    while hwnd {
        try {
            ex := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr")
            if want
                ex |= 0x20
            else
                ex &= ~0x20
            DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr", ex, "Ptr")
        } catch {
        }
        hwnd := DllCall("GetWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
    }
    try GDHO_HitTestDbgLog("ApplyStarryHostChildPassthrough enable=" . (want ? "1" : "0") . " reason=" . Trim(String(reason)))
}

GDHO_RaiseLauncherAboveStarry() {
    global GDHO_STAR_GUI, GDHO_LAUNCHER_GUI, GDHO_LAUNCHER_VISIBLE
    if !(IsObject(GDHO_STAR_GUI) && IsObject(GDHO_LAUNCHER_GUI) && GDHO_LAUNCHER_VISIBLE)
        return
    try {
        ; HWND_TOPMOST：启动层必须在全屏星空之上，否则穿透星空会吃掉点击
        DllCall("SetWindowPos", "Ptr", GDHO_LAUNCHER_GUI.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
    } catch {
    }
    try GDHO_SetStarryClickThrough(true, "raise_launcher_above_starry")
    try GDHO_ApplyStarryHostChildPassthrough(true, "raise_launcher_above_starry")
}

GDHO_EnsureLauncherLayerOnTop(*) {
    global GDHO_LAUNCHER_VISIBLE
    if !GDHO_LAUNCHER_VISIBLE || !GDHO_IsLauncherLayerActive()
        return
    if FuncExists("GDHO_IsStarryHostVisible") && !GDHO_IsStarryHostVisible() {
        try GDHO_HideLauncherLayer("ensure_on_top_starry_gone")
        return
    }
    try GDHO_SyncLauncherLayerPosition()
    try GDHO_RaiseLauncherAboveStarry()
}

GDHO_ShowStarryPassthroughOnly(reason := "p2_starry_passthrough") {
    global GDHO_STAR_GUI, GDHO_STAR_FULLSCREEN
    if !IsObject(GDHO_STAR_GUI)
        try GDHO_CreateStarryGui()
    if GDHO_UseLauncherLayer()
        try GDHO_EnsureStarryOnScreenForLauncher()
    if IsObject(GDHO_STAR_GUI) {
        try GDHO_STAR_GUI.Show("NA")
    }
    try GDHO_SetStarryClickThrough(true, reason)
    if FuncExists("GDHO_SetWebOlePassthrough")
        try GDHO_SetWebOlePassthrough(false)
    try GDHO_SuppressEmbeddedStarryLauncher()
    try GDHO_RunStarryJS("try{window.__gdhoOlePassthrough=false;var r=document.getElementById('root');if(r)r.classList.remove('ole-passthrough');window.HoleOverlay?.setOlePassthrough?.(false);}catch(_e){}")
}

GDHO_HideStarryHost(reason := "p2_hide_starry") {
    if IsObject(GDHO_STAR_GUI) {
        try GDHO_STAR_GUI.Hide()
    }
    try GDHO_SetStarryClickThrough(true, reason)
}

GDHO_ForceShowLauncherLayerByPolicy(ax := 0, ay := 0, reason := "policy") {
    if !GDHO_UseLauncherLayer()
        return false
    try GDHO_ShowStarryPassthroughOnly("before_force_launcher:" . reason)
    try GDHO_UpdateHoleCenterFromPolicy(Integer(ax), Integer(ay))
    ok := GDHO_ShowLauncherLayerForced("force_policy:" . reason)
    if FuncExists("NMER_Log")
        try NMER_Log("P2_PUMP", "force_show_launcher_by_policy", "reason=" . reason . " ok=" . (ok ? "1" : "0"))
    try NativeDropDiag_Log("[P2_PUMP] force_show_launcher_by_policy reason=" . reason . " cx=" . GDHO_CX . " cy=" . GDHO_CY)
    return ok
}

GDHO_ApplyWindowPolicyFromGo(msg) {
    global g_GDHO_PendingPanelText, GDHO_SESSION_TEXT, GDHO_CX, GDHO_CY
    if !(msg is Map)
        return false
    if !(FuncExists("GDHO_P2_IsEnabled") && GDHO_P2_IsEnabled())
        return false
    st := msg.Has("state") ? StrLower(Trim(String(msg["state"]))) : ""
    starry := msg.Has("starry") ? StrLower(Trim(String(msg["starry"]))) : ""
    launcher := msg.Has("launcher") ? StrLower(Trim(String(msg["launcher"]))) : ""
    panel := msg.Has("panel") ? StrLower(Trim(String(msg["panel"]))) : ""
    px := msg.Has("x") ? Integer(msg["x"]) : 0
    py := msg.Has("y") ? Integer(msg["y"]) : 0
    g_GDHO_P2_LastPolicyTick := A_TickCount
    try NativeDropDiag_Log("[P2] window_policy state=" . st . " starry=" . starry . " launcher=" . launcher . " panel=" . panel)
    if (px != 0 || py != 0) {
        try GDHO_UpdateHoleCenterFromPolicy(px, py)
    } else if (st = "resulting" || launcher = "show_topmost") {
        try GDHO_UpdateHoleCenterFromPolicy(0, 0)
    }
    if (px != 0 || py != 0 || st = "resulting") {
        cli := GDHO_PolicyScreenToStarryClient(GDHO_CX, GDHO_CY)
        try GDHO_RunStarryJS("try{var x=" . cli.x . ",y=" . cli.y . ";document.documentElement.style.setProperty('--hx',Math.max(80,x)+'px');document.documentElement.style.setProperty('--hy',Math.max(80,y)+'px');}catch(_e){}")
    }
    if (launcher = "show_topmost") {
        t := Trim(String(g_GDHO_PendingPanelText))
        if (t = "")
            t := Trim(String(GDHO_SESSION_TEXT))
        if (t != "")
            g_GDHO_PendingPanelText := t
        if GDHO_UseLauncherLayer()
            try GDHO_ForceShowLauncherLayerByPolicy(px, py, "go_policy:" . st)
    } else if (launcher = "hide" || st = "idle") {
        if GDHO_UseLauncherLayer()
            try GDHO_HideLauncherLayer("go_policy:" . st . ":" . launcher)
    }
    if (starry = "hide" && launcher != "show_topmost") {
        try GDHO_HideStarryHost("go_policy_hide_starry")
    } else if (starry = "show_passthrough" || starry = "show" || launcher = "show_topmost") {
        try GDHO_ShowStarryPassthroughOnly("go_policy:" . st)
    }
    if (panel = "show") {
        if FuncExists("GDHO_ShowPanel")
            try GDHO_ShowPanel("go_policy:" . st)
    } else if (panel = "hide") {
        if FuncExists("GDHO_HidePanel")
            try GDHO_HidePanel("go_policy:" . st)
    }
    return true
}

GDHO_P2_PolicyPresentFallback(*) {
    global g_GDHO_P2_LastPolicyTick, g_GDHO_PendingPanelText
    if !(FuncExists("GDHO_P2_IsEnabled") && GDHO_P2_IsEnabled())
        return
    if FuncExists("GDHO_IsStarryHostVisible") && !GDHO_IsStarryHostVisible()
        return
    if GDHO_IsLauncherLayerActive()
        return
    if (GDHO_LAUNCHER_VISIBLE && GDHO_LAUNCHER_READY)
        return
    if (A_TickCount - g_GDHO_P2_LastPolicyTick < 500)
        return
    try NativeDropDiag_Log("[P2] policy_fallback show_launcher_layer")
    if GDHO_UseLauncherLayer()
        try GDHO_ShowLauncherLayerForced("p2_policy_fallback")
}

GDHO_ArmLauncherLayerShow(reason := "") {
    global g_GDHO_PendingLauncherShow, g_GDHO_StarryLauncherOpen
    if !GDHO_UseLauncherLayer()
        return false
    g_GDHO_StarryLauncherOpen := true
    try GDHO_MarkTextHoleExpandedHold()
    try GDHO_SuppressEmbeddedStarryLauncher()
    if (GDHO_LAUNCHER_VISIBLE && GDHO_LAUNCHER_READY) {
        try GDHO_SyncLauncherLayerPosition()
        return true
    }
    g_GDHO_PendingLauncherShow := true
    try GDHO_EnsureLauncherLayerHost()
    if GDHO_ShowLauncherLayerForced("arm:" . reason)
        return true
    try SetTimer(GDHO_LauncherShowPump, -80)
    return false
}

GDHO_P2_EnsureLauncherVisibleAfterExpand(reason := "") {
    if !(FuncExists("GDHO_P2_IsEnabled") && GDHO_P2_IsEnabled())
        return false
    if !GDHO_UseLauncherLayer()
        return false
    if (GDHO_LAUNCHER_VISIBLE && GDHO_LAUNCHER_READY)
        return true
    try NativeDropDiag_Log("[P2] ensure_launcher_after_expand reason=" . String(reason))
    return GDHO_ArmLauncherLayerShow("p2_ensure:" . reason)
}

GDHO_P2_ExpandLauncherEnsure(*) {
    global g_GDHO_P2_ExpandEnsureReason
    try GDHO_P2_EnsureLauncherVisibleAfterExpand(String(g_GDHO_P2_ExpandEnsureReason))
}

GDHO_P2_RequestPanelPresent(txt, mx, my, reason := "") {
    global g_GDHO_PendingPanelText, g_GDHO_P2_ExpandEnsureReason, GDHO_TEXT_HOLE_EXPAND_MS
    g_GDHO_PendingPanelText := Trim(String(txt))
    sent := false
    if FuncExists("GDHO_WS_SendPanelPresent")
        sent := GDHO_WS_SendPanelPresent(mx, my, txt)
    if sent {
        global g_GDHO_P2_LastPolicyTick
        g_GDHO_P2_LastPolicyTick := A_TickCount
    } else {
        try NativeDropDiag_Log("[P2] panel_present_http_fail reason=" . String(reason))
    }
    expMs := Integer(GDHO_TEXT_HOLE_EXPAND_MS)
    if (expMs < 900)
        expMs := 1250
    g_GDHO_P2_ExpandEnsureReason := String(reason)
    if !(GDHO_LAUNCHER_VISIBLE && GDHO_LAUNCHER_READY)
        try SetTimer(GDHO_P2_ExpandLauncherEnsure, -600)
    return sent
}

GDHO_EnsureLauncherLayerHost() {
    global GDHO_WV2_LAUNCHER, GDHO_LAUNCHER_READY, g_GDHO_LauncherCreateInFlight, GDHO_LAUNCHER_GUI
    if !GDHO_UseLauncherLayer()
        return GDHO_LAUNCHER_READY
    if !IsObject(GDHO_STAR_GUI)
        return false
    if !IsObject(GDHO_LAUNCHER_GUI)
        try GDHO_CreateLauncherGui()
    if IsObject(GDHO_WV2_LAUNCHER)
        return GDHO_LAUNCHER_READY
    if g_GDHO_LauncherCreateInFlight
        return false
    if !IsObject(GDHO_LAUNCHER_GUI) || !GDHO_LAUNCHER_GUI.Hwnd
        return false
    g_GDHO_LauncherCreateInFlight := true
    try NativeDropDiag_Log("[TextHole] launcher_webview_create_begin hwnd=" . GDHO_LAUNCHER_GUI.Hwnd)
    try WebView2_CreateWithSharedEnvAsync(GDHO_LAUNCHER_GUI.Hwnd, GDHO_OnLauncherWebViewCreated, "gdho_launcher_layer")
    return false
}

GDHO_RunLauncherJS(js) {
    global GDHO_WV2_LAUNCHER, GDHO_LAUNCHER_READY
    if !(GDHO_WV2_LAUNCHER && GDHO_LAUNCHER_READY)
        return false
    try {
        GDHO_WV2_LAUNCHER.ExecuteScript(js)
        return true
    } catch {
        return false
    }
}

GDHO_SendLauncherLayerConfig() {
    global g_GDHO_PendingPanelText, g_GDHO_LauncherGridSent
    layoutJson := GDHO_GetSceneToolbarLayoutJson()
    previewJs := GDHO_QuoteJsString(Trim(String(g_GDHO_PendingPanelText)))
    js := "try{window.HoleLauncherLayer?.applyConfig?.({sceneToolbarLayout:" . layoutJson . "});window.HoleLauncherLayer?.show?.(" . previewJs . ");}catch(_e){}"
    if GDHO_RunLauncherJS(js) {
        g_GDHO_LauncherGridSent := true
        return true
    }
    return false
}

GDHO_ShowLauncherLayerForced(reason := "") {
    global GDHO_LAUNCHER_GUI, GDHO_LAUNCHER_VISIBLE, GDHO_LAUNCHER_READY
    global g_GDHO_PendingLauncherShow, g_GDHO_StarryLauncherOpen, g_GDHO_LauncherLastShowTick
    if !GDHO_UseLauncherLayer()
        return false
    now := A_TickCount
    launcherShown := false
    if IsObject(GDHO_LAUNCHER_GUI) && GDHO_LAUNCHER_GUI.Hwnd {
        try launcherShown := DllCall("IsWindowVisible", "Ptr", GDHO_LAUNCHER_GUI.Hwnd, "Int")
        catch {
            launcherShown := false
        }
    }
    if (GDHO_LAUNCHER_VISIBLE && launcherShown && g_GDHO_LauncherLastShowTick > 0 && (now - g_GDHO_LauncherLastShowTick) < 300) {
        try GDHO_MarkTextHoleExpandedHold()
        try GDHO_SuppressEmbeddedStarryLauncher()
        try GDHO_SyncLauncherLayerPosition()
        return true
    }
    if (GDHO_LAUNCHER_VISIBLE && !launcherShown)
        GDHO_LAUNCHER_VISIBLE := false
    g_GDHO_LauncherLastShowTick := now
    g_GDHO_StarryLauncherOpen := true
    try GDHO_MarkTextHoleExpandedHold()
    try GDHO_EnsureStarryOnScreenForLauncher()
    try GDHO_SyncHoleCenterFromStarryWindow()
    try GDHO_SuppressEmbeddedStarryLauncher()
    try GDHO_EnsureLauncherLayerHost()
    try GDHO_SetStarryClickThrough(true, "show_launcher_layer_starry_pass")
    if FuncExists("GDHO_SetWebOlePassthrough")
        try GDHO_SetWebOlePassthrough(false)
    try GDHO_RunStarryJS("try{window.__gdhoOlePassthrough=false;var r=document.getElementById('root');if(r){r.classList.add('use-external-launcher');r.classList.remove('ole-passthrough');}window.HoleOverlay?.hideSceneLauncher?.();window.HoleOverlay?.setOlePassthrough?.(false);}catch(_e){}")
    rect := GDHO_ComputeLauncherRectFromHole(Integer(GDHO_LAUNCHER_W))
    if !IsObject(GDHO_LAUNCHER_GUI)
        try GDHO_CreateLauncherGui()
    try GDHO_LAUNCHER_GUI.Move(rect.x, rect.y, rect.w, rect.h)
    try GDHO_LAUNCHER_GUI.Show("NA x" rect.x " y" rect.y " w" rect.w " h" rect.h)
    GDHO_LAUNCHER_VISIBLE := true
    try GDHO_ApplyLauncherLayerInteractive("show_launcher_layer:" . reason)
    try GDHO_ApplyStarryHostChildPassthrough(true, "show_launcher_layer")
    try GDHO_ResizeLauncherHost()
    try GDHO_RaiseLauncherAboveStarry()
    try WinSetAlwaysOnTop(1, "ahk_id " GDHO_LAUNCHER_GUI.Hwnd)
    g_GDHO_PendingLauncherShow := false
    if (GDHO_WV2_LAUNCHER) {
        try GDHO_WV2_LAUNCHER.PostWebMessageAsString('{"type":"launcher_show"}')
    }
    if GDHO_LAUNCHER_READY {
        try GDHO_SendLauncherLayerConfig()
    } else {
        g_GDHO_PendingLauncherShow := true
        try SetTimer(GDHO_LauncherShowPump, -15)
    }
    try NativeDropDiag_Log("[TextHole] show_launcher_layer reason=" . String(reason) . " x=" . rect.x . " y=" . rect.y . " cx=" . GDHO_CX . " cy=" . GDHO_CY)
    return true
}

GDHO_HideLauncherLayer(reason := "") {
    global GDHO_LAUNCHER_GUI, GDHO_LAUNCHER_VISIBLE, g_GDHO_PendingLauncherShow, g_GDHO_StarryLauncherOpen
    global g_GDHO_LauncherLastShowTick, g_GDHO_LauncherGridSent
    g_GDHO_PendingLauncherShow := false
    g_GDHO_StarryLauncherOpen := false
    g_GDHO_LauncherLastShowTick := 0
    g_GDHO_LauncherGridSent := false
    try SetTimer(GDHO_EnsureLauncherLayerOnTop, 0)
    try SetTimer(GDHO_LauncherShowPump, 0)
    try SetTimer(GDHO_P2_PolicyPresentFallback, 0)
    try SetTimer(GDHO_P2_ExpandLauncherEnsure, 0)
    try SetTimer(GDHO_CommitEarlyLauncherPump, 0)
    rs := StrLower(Trim(String(reason)))
    shouldClearSession := !(InStr(rs, "reset_session") || InStr(rs, "prepare_hole") || InStr(rs, "show_launcher_layer")
        || InStr(rs, "force_policy") || InStr(rs, "force_show"))
    if !GDHO_LAUNCHER_VISIBLE && !IsObject(GDHO_LAUNCHER_GUI) {
        if shouldClearSession && FuncExists("GDHO_ClearGestureHolePresentation") {
            try GDHO_ClearGestureHolePresentation("hide_launcher_early:" . rs)
            catch {
            }
        }
        return
    }
    GDHO_LAUNCHER_VISIBLE := false
    try GDHO_RunLauncherJS("try{window.HoleLauncherLayer?.hide?.();}catch(_e){}")
    if (GDHO_WV2_LAUNCHER) {
        try GDHO_WV2_LAUNCHER.PostWebMessageAsString('{"type":"launcher_hide"}')
    }
    try GDHO_RunStarryJS("try{window.__gdhoUseLauncherLayer=false;var r=document.getElementById('root');if(r)r.classList.remove('use-external-launcher');window.HoleOverlay?.hideSceneLauncher?.();}catch(_e){}")
    if IsObject(GDHO_LAUNCHER_GUI) {
        try GDHO_LAUNCHER_GUI.Hide()
    }
    if FuncExists("GDHO_IsStarryHostVisible") && GDHO_IsStarryHostVisible()
        try GDHO_ApplyStarryHostChildPassthrough(false, "hide_launcher_layer")
    if shouldClearSession && FuncExists("GDHO_ClearGestureHolePresentation") {
        try GDHO_ClearGestureHolePresentation("hide_launcher:" . rs)
        catch {
        }
    }
    try NativeDropDiag_Log("[TextHole] hide_launcher_layer reason=" . String(reason))
}

GDHO_IsStarryHostVisible() {
    global GDHO_VISIBLE, GDHO_STAR_GUI
    if !GDHO_VISIBLE
        return false
    if IsObject(GDHO_STAR_GUI) && GDHO_STAR_GUI.Hwnd
        return WinExist("ahk_id " GDHO_STAR_GUI.Hwnd)
    return false
}

GDHO_LauncherShowPump(*) {
    global g_GDHO_PendingLauncherShow, GDHO_LAUNCHER_READY, g_GDHO_StarryLauncherOpen
    if !(g_GDHO_PendingLauncherShow || g_GDHO_StarryLauncherOpen)
        return
    if FuncExists("GDHO_IsStarryHostVisible") && !GDHO_IsStarryHostVisible() {
        g_GDHO_PendingLauncherShow := false
        g_GDHO_StarryLauncherOpen := false
        try GDHO_HideLauncherLayer("launcher_pump_starry_gone")
        return
    }
    if GDHO_LAUNCHER_READY {
        g_GDHO_PendingLauncherShow := false
        try GDHO_EnsureStarryOnScreenForLauncher()
        GDHO_ShowLauncherLayerForced("launcher_show_pump")
        return
    }
    if GDHO_EnsureLauncherLayerHost()
        return
    try SetTimer(GDHO_LauncherShowPump, -30)
}

GDHO_LauncherNavPresentDonePump(*) {
    if !GDHO_UseLauncherLayer() || !GDHO_LAUNCHER_READY
        return
    try GDHO_ShowLauncherLayerForced("launcher_nav_present_done")
}

GDHO_GetStarryClientOrigin() {
    global GDHO_STAR_GUI, GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y
    ox := Integer(GDHO_LAST_HOST_X)
    oy := Integer(GDHO_LAST_HOST_Y)
    if IsObject(GDHO_STAR_GUI) && GDHO_STAR_GUI.Hwnd {
        try WinGetPos(&ox, &oy, , , "ahk_id " GDHO_STAR_GUI.Hwnd)
    }
    return { x: ox, y: oy }
}

GDHO_UpdateHoleCenterFromPolicy(screenX := 0, screenY := 0) {
    global GDHO_CX, GDHO_CY, GDHO_IS_SUCKING, GDHO_EXPANDED_HOLD, GDHO_STAR_FULLSCREEN
    global GDHO_STAR_GUI, GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y, GDHO_HOST_W, GDHO_HOST_H
    sx := Integer(screenX), sy := Integer(screenY)
    if (GDHO_IS_SUCKING || GDHO_EXPANDED_HOLD || GDHO_STAR_FULLSCREEN) {
        if IsObject(GDHO_STAR_GUI) && GDHO_STAR_GUI.Hwnd {
            try {
                WinGetPos(&ox, &oy, &ow, &oh, "ahk_id " GDHO_STAR_GUI.Hwnd)
                if !GDHO_IsHostParkedPos(ox, oy) {
                    GDHO_CX := ox + (ow // 2)
                    GDHO_CY := oy + (oh // 2)
                    try GDHO_RememberOnScreenHoleCenter(GDHO_CX, GDHO_CY)
                    return
                }
            } catch {
            }
        }
        rem := GDHO_GetRememberedHoleCenter()
        if (rem.x > 50) {
            GDHO_CX := rem.x
            GDHO_CY := rem.y
            return
        }
        lx := Integer(GDHO_LAST_HOST_X), ly := Integer(GDHO_LAST_HOST_Y)
        if !GDHO_IsHostParkedPos(lx, ly) {
            GDHO_CX := lx + (Integer(GDHO_HOST_W) // 2)
            GDHO_CY := ly + (Integer(GDHO_HOST_H) // 2)
            return
        }
    }
    if (sx > 0 && sy > 0) {
        o := GDHO_GetStarryClientOrigin()
        ow := 0, oh := 0
        if IsObject(GDHO_STAR_GUI) && GDHO_STAR_GUI.Hwnd {
            try WinGetPos(, , &ow, &oh, "ahk_id " GDHO_STAR_GUI.Hwnd)
        }
        if (ow > 0 && sx <= ow && sy <= oh)
            GDHO_CX := o.x + sx, GDHO_CY := o.y + sy
        else
            GDHO_CX := sx, GDHO_CY := sy
        return
    }
    c := GDHO_GetHoleCenterScreenCoords()
    GDHO_CX := c.x
    GDHO_CY := c.y
}

GDHO_PolicyScreenToStarryClient(screenX, screenY) {
    global GDHO_STAR_GUI, GDHO_IS_SUCKING, GDHO_EXPANDED_HOLD, GDHO_STAR_FULLSCREEN
    o := GDHO_GetStarryClientOrigin()
    sw := 620, sh := 620
    if IsObject(GDHO_STAR_GUI) && GDHO_STAR_GUI.Hwnd {
        try WinGetPos(, , &sw, &sh, "ahk_id " GDHO_STAR_GUI.Hwnd)
    }
    if (GDHO_IS_SUCKING || GDHO_EXPANDED_HOLD || GDHO_STAR_FULLSCREEN || sw > 800 || sh > 800) {
        return { x: Max(80, sw // 2), y: Max(80, sh // 2) }
    }
    sx := Integer(screenX), sy := Integer(screenY)
    if (sx > 0 && sy > 0) {
        cx := sx - o.x
        cy := sy - o.y
    } else {
        cx := sw // 2
        cy := sh // 2
    }
    cx := Max(80, Min(cx, sw - 80))
    cy := Max(80, Min(cy, sh - 80))
    return { x: cx, y: cy }
}

GDHO_GetHoleCenterScreenCoords() {
    global GDHO_LAST_HOST_X, GDHO_LAST_HOST_Y, GDHO_HOST_W, GDHO_HOST_H
    global GDHO_CX, GDHO_CY, GDHO_IS_SUCKING, GDHO_EXPANDED_HOLD, GDHO_STAR_GUI, GDHO_STAR_FULLSCREEN
    if (GDHO_IS_SUCKING || GDHO_EXPANDED_HOLD || GDHO_STAR_FULLSCREEN) {
        if IsObject(GDHO_STAR_GUI) && GDHO_STAR_GUI.Hwnd {
            try {
                WinGetPos(&sx, &sy, &sw, &sh, "ahk_id " GDHO_STAR_GUI.Hwnd)
                if !GDHO_IsHostParkedPos(sx, sy)
                    return { x: sx + (sw // 2), y: sy + (sh // 2) }
            } catch {
            }
        }
        rem := GDHO_GetRememberedHoleCenter()
        if (rem.x > 50)
            return rem
        lx := Integer(GDHO_LAST_HOST_X), ly := Integer(GDHO_LAST_HOST_Y)
        if !GDHO_IsHostParkedPos(lx, ly) {
            return {
                x: lx + (Integer(GDHO_HOST_W) // 2),
                y: ly + (Integer(GDHO_HOST_H) // 2)
            }
        }
        return rem
    }
    cx := Integer(GDHO_CX)
    cy := Integer(GDHO_CY)
    if (cx > 0 && cy > 0)
        return { x: cx, y: cy }
    o := GDHO_GetStarryClientOrigin()
    return { x: o.x + 180, y: o.y + 159 }
}

GDHO_ComputePanelRectCenteredOnHole(diameter := 480) {
    global GDHO_PANEL_W, GDHO_PANEL_H
    c := GDHO_GetHoleCenterScreenCoords()
    half := Integer(diameter) // 2
    if (half < 1)
        half := 240
    GDHO_PANEL_W := Integer(diameter)
    GDHO_PANEL_H := Integer(diameter)
    return { x: Integer(c.x) - half, y: Integer(c.y) - half, w: Integer(diameter), h: Integer(diameter) }
}

GDHO_SendStarryLauncherConfig() {
    global g_GDHO_PendingPanelText, g_GDHO_PendingStarryLauncherShow
    if GDHO_UseLauncherLayer() {
        if GDHO_ShowLauncherLayerForced("send_launcher_layer") {
            g_GDHO_PendingStarryLauncherShow := false
            return true
        }
        g_GDHO_PendingStarryLauncherShow := true
        return false
    }
    layoutJson := GDHO_GetSceneToolbarLayoutJson()
    previewJs := GDHO_QuoteJsString(Trim(String(g_GDHO_PendingPanelText)))
    js := "try{window.HoleOverlay?.applySceneLauncherConfig?.({sceneToolbarLayout:" . layoutJson . "});window.HoleOverlay?.showSceneLauncher?.(" . previewJs . ");}catch(_e){}"
    if GDHO_RunStarryJS(js) {
        g_GDHO_PendingStarryLauncherShow := false
        try GDHO_ApplyStarryLauncherInteractive("send_config")
        return true
    }
    g_GDHO_PendingStarryLauncherShow := true
    return false
}

GDHO_FlushPendingStarryLauncher(*) {
    global g_GDHO_PendingStarryLauncherShow
    if !g_GDHO_PendingStarryLauncherShow
        return
    if GDHO_SendStarryLauncherConfig()
        return
    try SetTimer(GDHO_FlushPendingStarryLauncher, -120)
}

GDHO_PresentStarryLauncher(preview := "") {
    global g_GDHO_PendingPanelText
    g_GDHO_PendingPanelText := Trim(String(preview))
    try GDHO_SetInteractionPhase(GDHO_PHASE_PANEL_OPEN, "present_starry_launcher")
    if FuncExists("GDHO_P2_IsEnabled") && GDHO_P2_IsEnabled() && GDHO_UseLauncherLayer() {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        try GDHO_ArmLauncherLayerShow("present_starry_launcher")
        GDHO_P2_RequestPanelPresent(preview, mx, my, "present_starry_launcher")
        return true
    }
    if GDHO_UseLauncherLayer() {
        if GDHO_SendStarryLauncherConfig()
            return true
        try SetTimer(GDHO_SendStarryLauncherConfig, -80)
        try SetTimer(GDHO_LauncherShowPump, -200)
        return true
    }
    try GDHO_ApplyStarryLauncherInteractive("present")
    if GDHO_SendStarryLauncherConfig()
        return true
    try SetTimer(GDHO_SendStarryLauncherConfig, -80)
    try SetTimer(GDHO_FlushPendingStarryLauncher, -200)
    return true
}

GDHO_ShowPanelOverlayLauncher(preview := "") {
    global GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y, GDHO_PANEL_GUI, GDHO_PANEL_VISIBLE
    global g_GDHO_PendingPanelText, g_GDHO_PendingPanelShow, g_GDHO_PendingPanelShowReason, g_GDHO_PendingPanelShowSince
    g_GDHO_PendingPanelText := Trim(String(preview))
    rect := GDHO_ComputePanelRectCenteredOnHole(480)
    GDHO_PANEL_LAST_X := rect.x
    GDHO_PANEL_LAST_Y := rect.y
    if !IsObject(GDHO_PANEL_GUI)
        try GDHO_CreatePanelGui()
    try GDHO_EnsureDecoupledPanelWebHost()
    g_GDHO_PendingPanelShow := true
    g_GDHO_PendingPanelShowReason := "present_panel_overlay"
    g_GDHO_PendingPanelShowSince := A_TickCount
    if GDHO_PANEL_READY {
        GDHO_ShowPanelOverlayForced("present_panel_overlay")
        return GDHO_PANEL_VISIBLE
    }
    try SetTimer(GDHO_PendingPanelShowPump, -120)
    return false
}

GDHO_ShowPanelOverlayForced(reason := "") {
    global GDHO_PANEL_GUI, GDHO_PANEL_VISIBLE, GDHO_PANEL_W, GDHO_PANEL_H
    global GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y, GDHO_PANEL_READY, g_GDHO_PendingPanelText
    if !IsObject(GDHO_PANEL_GUI)
        return
    if !GDHO_PANEL_READY {
        GDHO_ShowPanelWhenReady(reason)
        return
    }
    rect := GDHO_ComputePanelRectCenteredOnHole(480)
    GDHO_PANEL_LAST_X := rect.x
    GDHO_PANEL_LAST_Y := rect.y
    try GDHO_PANEL_GUI.Move(rect.x, rect.y, rect.w, rect.h)
    try GDHO_PANEL_GUI.Show("NA x" . rect.x . " y" . rect.y . " w" . rect.w . " h" . rect.h)
    GDHO_PANEL_VISIBLE := true
    try WinSetAlwaysOnTop(1, "ahk_id " . GDHO_PANEL_GUI.Hwnd)
    try WinSetTransparent(255, "ahk_id " . GDHO_PANEL_GUI.Hwnd)
    GDHO_RaisePanelAboveStarry()
    previewJs := GDHO_QuoteJsString(Trim(String(g_GDHO_PendingPanelText)))
    try GDHO_RunPanelJS("try{document.documentElement.style.background='transparent';document.body.style.background='transparent';document.body.classList.add('overlay-hole-mode');window.HolePanel?.ensurePanelLoaded?.();window.HolePanel?.onHostShowLauncherOverlay?.(" . previewJs . ");}catch(_e){}")
    try GDHO_SendPanelDockConfig()
    ; 方案 B：保留星空，透明面板叠在洞心
    try GDHO_Trace("show_panel_overlay reason=" . String(reason))
}

GDHO_DismissTextHoleAfterLauncherPick(*) {
    if FuncExists("GDHO_DismissTextHolePanel")
        try GDHO_DismissTextHolePanel("panel_scene_pick_delayed")
}

GDHO_IsLauncherCmdInFlight() {
    global g_GDHO_LauncherCmdInFlightUntil
    return (g_GDHO_LauncherCmdInFlightUntil > 0 && A_TickCount < g_GDHO_LauncherCmdInFlightUntil)
}

GDHO_ArmLauncherCmdInFlight(ms := 2800) {
    global g_GDHO_LauncherCmdInFlightUntil
    g_GDHO_LauncherCmdInFlightUntil := A_TickCount + Max(800, Integer(ms))
}

GDHO_IsLauncherContextActive() {
    global g_GDHO_StarryLauncherOpen, GDHO_LAUNCHER_VISIBLE
    if (GDHO_LAUNCHER_VISIBLE || g_GDHO_StarryLauncherOpen)
        return true
    if GDHO_IsPostSuckProtected()
        return true
    if GDHO_IsTextSelectionPreviewReady()
        return true
    return false
}

GDHO_LauncherSearchHandoffWatch(*) {
    static tries := 0
    global g_GDHO_LauncherCmdInFlightUntil
    vis := false
    busy := false
    try vis := SCWV_IsVisible()
    catch {
        vis := false
    }
    if !vis {
        try vis := IsSearchCenterActive()
        catch {
        }
    }
    try busy := SearchCenter_IsOpeningOrBusy()
    catch {
        busy := false
    }
    if (vis || busy) {
        tries := 0
        g_GDHO_LauncherCmdInFlightUntil := 0
        try NativeDropDiag_Log("[LauncherPick] search_handoff_ok vis=" . (vis ? "1" : "0") . " busy=" . (busy ? "1" : "0"))
        return
    }
    if !GDHO_IsLauncherCmdInFlight() {
        tries := 0
        return
    }
    tries += 1
    if (tries > 5) {
        tries := 0
        g_GDHO_LauncherCmdInFlightUntil := 0
        try NativeDropDiag_Log("[LauncherPick] search_handoff_giveup")
        return
    }
    try NativeDropDiag_Log("[LauncherPick] search_handoff_retry try=" . tries)
    try {
        if FuncExists("TrayMenu_OpenSearchActionRun")
            TrayMenu_OpenSearchActionRun()
        else
            FloatingToolbar_ActivateSearchCenter()
    } catch as e {
        try NativeDropDiag_Log("[LauncherPick] search_handoff_retry_ERR " . e.Message)
    }
}

GDHO_OpenSearchFromLauncher() {
    global g_GDHO_PendingPanelText, g_GDHO_TextHoleCapturedText
    kw := ""
    try kw := Trim(String(g_GDHO_TextHoleCapturedText))
    if (kw = "")
        try kw := Trim(String(g_GDHO_PendingPanelText))
    try {
        TrayMenu_QueueUiOpenFromHoleMode(TrayMenu_OpenSearchAction, "search")
        try NativeDropDiag_Log("[LauncherPick] exec_path=TrayMenu_QueueUiOpenFromHoleMode launcher_ctx kw_len=" . StrLen(kw))
        SetTimer(GDHO_LauncherSearchHandoffWatch, -120)
        SetTimer(GDHO_LauncherSearchHandoffWatch, -520)
        SetTimer(GDHO_LauncherSearchHandoffWatch, -1100)
        return true
    } catch as e {
        try NativeDropDiag_Log("[LauncherPick] launcher_search_queue_ERR msg=" . e.Message)
    }
    try {
        if (kw != "") {
            SearchCenter_RunQueryWithKeyword(kw)
            try NativeDropDiag_Log("[LauncherPick] exec_path=SearchCenter_RunQueryWithKeyword kw_len=" . StrLen(kw))
        } else {
            FloatingToolbar_ActivateSearchCenter()
            try NativeDropDiag_Log("[LauncherPick] exec_path=FloatingToolbar_ActivateSearchCenter launcher_fallback")
        }
        SetTimer(GDHO_LauncherSearchHandoffWatch, -200)
        SetTimer(GDHO_LauncherSearchHandoffWatch, -700)
        return true
    } catch as e2 {
        try NativeDropDiag_Log("[LauncherPick] launcher_search_direct_ERR msg=" . e2.Message)
        return false
    }
}

GDHO_HandleLauncherPick(msg) {
    if !(msg is Map)
        return
    typ := msg.Has("type") ? String(msg["type"]) : ""
    cmdId := msg.Has("cmdId") ? Trim(String(msg["cmdId"])) : ""
    sceneId := msg.Has("sceneId") ? Trim(String(msg["sceneId"])) : ""
    try NativeDropDiag_Log("[LauncherPick] type=" . typ . " cmdId=" . cmdId . " scene=" . sceneId)
    if (typ = "panel_open_manual" || (typ = "panel_scene_pick" && msg.Has("internal") && msg["internal"])) {
        try GDHO_ApplyStarryHostChildPassthrough(false, "panel_open_manual")
        GDHO_PanelOpenManualPage()
        return
    }
    if (typ = "panel_scene_pick") {
        if (cmdId = "")
            return
        try GDHO_ApplyStarryHostChildPassthrough(false, "panel_scene_pick")
        GDHO_ArmLauncherCmdInFlight((cmdId = "sc_activate_search" || cmdId = "ftm_search_center") ? 3200 : 2200)
        ok := false
        try ok := GDHO_ExecutePanelDockCmd(cmdId)
        try NativeDropDiag_Log("[LauncherPick] execute ok=" . (ok ? "1" : "0") . " cmdId=" . cmdId)
        if ok {
            if (cmdId = "sc_activate_search" || cmdId = "ftm_search_center" || cmdId = "ch_r") {
                try GDHO_DismissLauncherUI("panel_scene_pick_" . cmdId)
                try SetTimer(GDHO_DismissTextHoleAfterLauncherPick, -1500)
            } else {
                try GDHO_DismissLauncherUI("panel_scene_pick")
                try SetTimer(GDHO_DismissTextHoleAfterLauncherPick, -450)
            }
        } else {
            global g_GDHO_LauncherCmdInFlightUntil
            g_GDHO_LauncherCmdInFlightUntil := 0
            try TrayTip("黑洞启动层", "未能打开功能，请查看日志 cmdId=" . cmdId, "Icon! 3")
        }
        return
    }
}

GDHO_HideStarryLauncher() {
    if GDHO_UseLauncherLayer() {
        try GDHO_HideLauncherLayer("hide_starry_launcher")
    } else {
        try GDHO_RunStarryJS("try{window.HoleOverlay?.hideSceneLauncher?.();}catch(_e){}")
    }
}

GDHO_PresentLauncherAfterExpand(txt := "", mx := "", my := "", reason := "", sessionId := 0) {
    mode := GDHO_GetTextHoleLauncherMode()
    ok := false
    if (mode = "starry" || mode = "both") {
        if FuncExists("GDHO_P2_IsEnabled") && GDHO_P2_IsEnabled() {
            if (GDHO_LAUNCHER_VISIBLE && GDHO_LAUNCHER_READY) {
                try GDHO_SyncLauncherLayerPosition()
                ok := true
            } else {
                try GDHO_MarkTextHoleExpandedHold()
                if GDHO_UseLauncherLayer()
                    try GDHO_ShowLauncherLayerForced("present_after_expand:" . reason)
                GDHO_P2_RequestPanelPresent(txt, mx, my, reason)
                ok := true
            }
        } else {
            GDHO_PresentStarryLauncher(txt)
            ok := true
        }
    }
    if (mode = "panel" || mode = "both") {
        if GDHO_ShowPanelOverlayLauncher(txt)
            ok := true
    }
    if (mode != "starry" && mode != "panel" && mode != "both") {
        GDHO_PresentStarryLauncher(txt)
        ok := true
    }
    if ok {
        global g_GDHO_TextHolePanelOpen, g_GDHO_TextHoleStickyPanel, g_GDHO_StarryLauncherOpen
        if (mode = "starry") {
            if !GDHO_UseLauncherLayer()
                try GDHO_ApplyStarryLauncherInteractive("present_after_expand")
            g_GDHO_TextHolePanelOpen := false
            g_GDHO_TextHoleStickyPanel := false
            if GDHO_PANEL_VISIBLE && FuncExists("GDHO_HidePanel")
                try GDHO_HidePanel("starry_launcher_present")
        } else {
            g_GDHO_TextHolePanelOpen := true
            g_GDHO_TextHoleStickyPanel := true
            try GDHO_LockTextHoleUserPanel()
        }
    }
    try NativeDropDiag_Log("[PostSuck] present_launcher mode=" . mode . " ok=" . (ok ? "1" : "0") . " reason=" . String(reason))
    return ok
}

GDHO_GetSceneToolbarLayoutJson() {
    arr := []
    if FuncExists("VK_GetSceneToolbarLayoutArray") {
        try arr := VK_GetSceneToolbarLayoutArray()
        catch {
            arr := []
        }
    }
    try {
        return WebView_DumpJson(arr)
    } catch {
        return "[]"
    }
}

GDHO_SendPanelDockConfig() {
    global GDHO_WV2_PANEL, GDHO_PANEL_READY
    if !(GDHO_PANEL_READY && IsObject(GDHO_WV2_PANEL))
        return false
    layoutJson := GDHO_GetSceneToolbarLayoutJson()
    js := "try{window.HolePanel?.applyDockConfig?.({sceneToolbarLayout:" . layoutJson . "});}catch(_e){}"
    try {
        GDHO_WV2_PANEL.ExecuteScript(js)
        return true
    } catch {
        return false
    }
}

GDHO_PanelOpenManualPage() {
    global g_GDHO_PendingPanelText, GDHO_CURSOR_X, GDHO_CURSOR_Y
    t := Trim(String(g_GDHO_PendingPanelText))
    if (t = "")
        t := GDHO_GetTextHoleCapturedText()
    if FuncExists("GDHO_RefreshTextHoleCapturedTextFromSelection")
        try t := GDHO_RefreshTextHoleCapturedTextFromSelection(4)
    g_GDHO_PendingPanelText := t
    try GDHO_HideStarryLauncher()
    try GDHO_EnsurePanelHostForPhase("panel_open")
    if !GDHO_PANEL_READY {
        try GDHO_ShowPanelWhenReady("panel_open_manual")
        return false
    }
    if !GDHO_PANEL_VISIBLE {
        GDHO_EnsurePanelShowPosition(GDHO_CURSOR_X, GDHO_CURSOR_Y, true)
        try GDHO_ShowPanel("panel_open_manual")
    }
    jsBody := GDHO_QuoteJsString(t)
    try {
        if GDHO_RunPanelJS("try{document.body.classList.remove('overlay-hole-mode');window.HolePanel?.resetPanelLayout?.();window.HolePanel?.ensurePanelLoaded?.();window.HolePanel?.openManualWithText?.(" . jsBody . ");}catch(_e){}")
            return true
    } catch {
    }
    return false
}

GDHO_TryCall(fnName, args*) {
    try {
        if (args.Length = 0)
            %fnName%()
        else if (args.Length = 1)
            %fnName%(args[1])
        else if (args.Length = 2)
            %fnName%(args[1], args[2])
        else if (args.Length = 3)
            %fnName%(args[1], args[2], args[3])
        else
            throw Error("too many args for GDHO_TryCall")
        return true
    } catch as e {
        try NativeDropDiag_Log("[LauncherPick] TryCall_ERR fn=" . fnName . " msg=" . e.Message)
        return false
    }
}

GDHO_OpenNiumaChatFromLauncher(*) {
    Critical "Off"
    global AppearanceActivationMode, ConfigFile, g_FTB_PendingOpenNiumaDrawer, g_FTB_ReturnToHoleAfterNiuma
    try NativeDropDiag_Log("[LauncherPick] niuma_open_begin mode=" . (IsSet(AppearanceActivationMode) ? AppearanceActivationMode : ""))
    g_FTB_ReturnToHoleAfterNiuma := true
    g_FTB_PendingOpenNiumaDrawer := true
    if FuncExists("FloatingToolbar_MarkNiumaHandoffActive")
        try FloatingToolbar_MarkNiumaHandoffActive(4000)
    if FuncExists("GDHO_PrepareDecoupledHoleForTextSelection")
        try GDHO_PrepareDecoupledHoleForTextSelection("niuma_handoff_open")
    AppearanceActivationMode := "toolbar"
    try IniWrite("toolbar", ConfigFile, "Appearance", "ActivationMode")
    catch {
    }
    if FuncExists("GDHO_ForceApplyAppearanceMode") {
        try GDHO_ForceApplyAppearanceMode("toolbar")
    } else {
        try ApplyAppearanceActivationMode()
        catch as e {
            try NativeDropDiag_Log("[LauncherPick] niuma_apply_mode_ERR msg=" . e.Message)
        }
    }
    try SetTimer(GDHO_NiumaDrawerOpenPump, -80)
    try SetTimer(GDHO_NiumaDrawerOpenPump, -320)
    try SetTimer(GDHO_NiumaDrawerOpenPump, -720)
    try SetTimer(GDHO_NiumaDrawerOpenPump, -1200)
}

GDHO_NiumaDrawerOpenPump(*) {
    global g_FTB_PendingOpenNiumaDrawer, g_FTB_NiumaHandoffOpening, AppearanceActivationMode
    if (NormalizeAppearanceActivationMode(AppearanceActivationMode) != "toolbar")
        return
    if !(g_FTB_PendingOpenNiumaDrawer || g_FTB_NiumaHandoffOpening)
        return
    if FuncExists("FloatingToolbar_OpenNiumaChatDrawer") {
        try {
            ok := FloatingToolbar_OpenNiumaChatDrawer(true)
            try NativeDropDiag_Log("[LauncherPick] niuma_open_drawer ok=" . (ok ? "1" : "0") . " pending=" . (g_FTB_PendingOpenNiumaDrawer ? "1" : "0"))
        } catch as e {
            try NativeDropDiag_Log("[LauncherPick] niuma_open_drawer_ERR msg=" . e.Message)
        }
    }
}

GDHO_ExecutePanelDockCmd(cmdId) {
    cmdId := Trim(String(cmdId))
    if (cmdId = "")
        return false
    try NativeDropDiag_Log("[LauncherPick] exec_begin cmdId=" . cmdId)
    global AppearanceActivationMode
    inHole := false
    try inHole := (IsSet(AppearanceActivationMode) && NormalizeAppearanceActivationMode(AppearanceActivationMode) = "hole")
    catch {
        inHole := false
    }
    switch cmdId {
        case "sc_activate_search", "ftm_search_center":
            if GDHO_IsLauncherContextActive() || inHole
                return GDHO_OpenSearchFromLauncher()
            try {
                FloatingToolbar_ActivateSearchCenter()
                try NativeDropDiag_Log("[LauncherPick] exec_path=FloatingToolbar_ActivateSearchCenter")
                return true
            } catch as e {
                try NativeDropDiag_Log("[LauncherPick] FTB_Search_ERR msg=" . e.Message)
            }
            try {
                ShowSearchCenter()
                try NativeDropDiag_Log("[LauncherPick] exec_path=ShowSearchCenter")
                return true
            } catch as e2 {
                try NativeDropDiag_Log("[LauncherPick] ShowSearchCenter_ERR msg=" . e2.Message)
            }
        case "ch_r":
            if GDHO_IsLauncherContextActive() || inHole {
                try {
                    GDHO_OpenNiumaChatFromLauncher()
                    try NativeDropDiag_Log("[LauncherPick] exec_path=GDHO_OpenNiumaChatFromLauncher direct")
                    return true
                } catch as e {
                    try NativeDropDiag_Log("[LauncherPick] hole_niuma_direct_ERR msg=" . e.Message)
                }
            }
            try {
                if FloatingToolbar_OpenNiumaChatDrawer(true) {
                    try NativeDropDiag_Log("[LauncherPick] exec_path=FloatingToolbar_OpenNiumaChatDrawer")
                    return true
                }
            } catch as e {
                try NativeDropDiag_Log("[LauncherPick] FTB_NiumaDrawer_ERR msg=" . e.Message)
            }
            try {
                VK_EnsureNiumaWindow(true)
                try NativeDropDiag_Log("[LauncherPick] exec_path=VK_EnsureNiumaWindow")
                return true
            } catch as e {
                try NativeDropDiag_Log("[LauncherPick] VK_EnsureNiumaWindow_ERR msg=" . e.Message)
            }
        case "qa_clipboard", "ftm_clipboard":
            try {
                CP_Show()
                try NativeDropDiag_Log("[LauncherPick] exec_path=CP_Show")
                return true
            } catch as e {
                try NativeDropDiag_Log("[LauncherPick] CP_Show_ERR msg=" . e.Message)
            }
        case "hub_capsule", "ftb_scratchpad":
            try {
                SelectionSense_OpenHubCapsuleFromToolbar()
                try NativeDropDiag_Log("[LauncherPick] exec_path=SelectionSense_OpenHubCapsuleFromToolbar")
                return true
            } catch as e {
                try NativeDropDiag_Log("[LauncherPick] hub_capsule_ERR msg=" . e.Message)
            }
        case "ch_t", "ftb_screenshot":
            try SetTimer(FloatingToolbar_DeferredScreenshot, -10)
            catch as e {
                try NativeDropDiag_Log("[LauncherPick] DeferredScreenshot_ERR " . e.Message)
                return false
            }
            try NativeDropDiag_Log("[LauncherPick] exec_path=FloatingToolbar_DeferredScreenshot")
            return true
        case "qa_config":
            if GDHO_TryCall("ShowConfigGUI_Safe") {
                try NativeDropDiag_Log("[LauncherPick] exec_path=ShowConfigGUI_Safe")
                return true
            }
        case "sys_show_vk":
            if GDHO_TryCall("VK_Show") {
                try NativeDropDiag_Log("[LauncherPick] exec_path=VK_Show")
                return true
            }
        case "open_cloudplayer":
            if GDHO_TryCall("ShowCloudPlayer") {
                try NativeDropDiag_Log("[LauncherPick] exec_path=ShowCloudPlayer")
                return true
            }
        case "ch_b":
            if GDHO_TryCall("FloatingToolbarToggleButtonAction", "Prompt") {
                try NativeDropDiag_Log("[LauncherPick] exec_path=FloatingToolbarToggleButtonAction")
                return true
            }
        case "cursor_open":
            if GDHO_TryCall("ShowCursorPanel") {
                try NativeDropDiag_Log("[LauncherPick] exec_path=ShowCursorPanel")
                return true
            }
    }
    try {
        if VK_Execute(cmdId) {
            try NativeDropDiag_Log("[LauncherPick] exec_path=VK_Execute ok=1")
            return true
        }
    } catch as e {
        try NativeDropDiag_Log("[LauncherPick] VK_Execute_ERR msg=" . e.Message)
    }
    try {
        if VK_ExecuteDockCmd(cmdId) {
            try NativeDropDiag_Log("[LauncherPick] exec_path=VK_ExecuteDockCmd ok=1")
            return true
        }
    } catch as e {
        try NativeDropDiag_Log("[LauncherPick] VK_ExecuteDockCmd_ERR msg=" . e.Message)
    }
    try NativeDropDiag_Log("[LauncherPick] exec_failed cmdId=" . cmdId)
    return false
}

GDHO_ApplyPanelVisibleChrome() {
    global g_GDHO_PendingPanelText
    if GDHO_IsStarryLauncherMode()
        return
    if !GDHO_PANEL_READY
        return
    t := Trim(String(g_GDHO_PendingPanelText))
    if (t = "")
        t := GDHO_GetTextHoleCapturedText()
    previewJs := GDHO_QuoteJsString(t)
    try GDHO_RunPanelJS("try{document.documentElement.style.background='transparent';document.body.style.background='transparent';window.HolePanel?.ensurePanelLoaded?.();window.HolePanel?.onHostShowLauncher?.(" . previewJs . ");}catch(_e){}")
    try GDHO_NotifyPanelHostPresent(t)
    try GDHO_SendPanelDockConfig()
}

GDHO_ShowPanelForced(reason := "") {
    global GDHO_PANEL_GUI, GDHO_PANEL_VISIBLE, GDHO_PANEL_W, GDHO_PANEL_H
    global GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y, GDHO_PANEL_READY, GDHO_CURSOR_X, GDHO_CURSOR_Y
    global g_GDHO_PendingPanelShow, g_GDHO_PendingPanelShowSince, g_GDHO_PendingPanelText
    r0 := StrLower(Trim(String(reason)))
    textHoleShow := (InStr(r0, "present") || InStr(r0, "post_suck") || InStr(r0, "hole_expand") || InStr(r0, "expand_complete")
        || Trim(String(g_GDHO_PendingPanelText)) != "")
    if (textHoleShow && GDHO_IsStarryLauncherMode()) {
        if GDHO_PANEL_VISIBLE && FuncExists("GDHO_HidePanel")
            try GDHO_HidePanel("starry_launcher_forced")
        try GDHO_PresentStarryLauncher(Trim(String(g_GDHO_PendingPanelText)))
        return
    }
    if !IsObject(GDHO_PANEL_GUI) {
        try GDHO_CreatePanelGui()
    }
    try GDHO_EnsureDecoupledPanelWebHost()
    if !IsObject(GDHO_PANEL_GUI) {
        try NativeDropDiag_Log("[PostSuck] show_panel_forced_fail reason=no_panel_gui source=" . String(reason))
        GDHO_PANEL_VISIBLE := false
        return
    }
    ; Avoid showing a blank/black panel before the WebView has finished navigating.
    if !GDHO_PANEL_READY {
        if textHoleShow {
            try GDHO_EnsurePanelHostForPhase("resulting")
        } else {
            try GDHO_EnsurePanelWebWarm()
        }
        g_GDHO_PendingPanelShow := true
        g_GDHO_PendingPanelShowSince := A_TickCount
        try NativeDropDiag_Log("[PostSuck] show_panel_defer_until_nav reason=" . String(reason))
        try SetTimer(GDHO_PendingPanelShowPump, 0)
        SetTimer(GDHO_PendingPanelShowPump, -160)
        GDHO_PANEL_VISIBLE := false
        try GDHO_PANEL_GUI.Hide()
        return
    }
    if (Integer(GDHO_PANEL_LAST_X) < -2800 || Integer(GDHO_PANEL_LAST_Y) < -2800
        || (Integer(GDHO_PANEL_LAST_X) <= 48 && Integer(GDHO_PANEL_LAST_Y) <= 48))
        GDHO_EnsurePanelShowPosition(GDHO_CURSOR_X, GDHO_CURSOR_Y, true)
    try SetTimer(GDHO_PanelDeactivateCheck, 0)
    GDHO_ActivatePanelHost("show_panel_forced")
    shownOk := false
    try {
        GDHO_PANEL_GUI.Show("NA x" Integer(GDHO_PANEL_LAST_X) " y" Integer(GDHO_PANEL_LAST_Y)
            . " w" Integer(GDHO_PANEL_W) " h" Integer(GDHO_PANEL_H))
        shownOk := true
    } catch {
        shownOk := false
    }
    if !shownOk {
        try {
            try GDHO_EnsureDecoupledPanelWebHost()
            if IsObject(GDHO_PANEL_GUI)
                GDHO_PANEL_GUI.Show("NA x" Integer(GDHO_PANEL_LAST_X) " y" Integer(GDHO_PANEL_LAST_Y)
                    . " w" Integer(GDHO_PANEL_W) " h" Integer(GDHO_PANEL_H))
            shownOk := true
        } catch {
            shownOk := false
        }
    }
    GDHO_PANEL_VISIBLE := shownOk
    if !shownOk {
        try NativeDropDiag_Log("[PostSuck] show_panel_forced_fail reason=show_exception source=" . String(reason))
        return
    }
    try WinSetAlwaysOnTop(1, "ahk_id " . GDHO_PANEL_GUI.Hwnd)
    GDHO_ApplyPanelNoActivateStyle()
    GDHO_RaisePanelAboveStarry()
    lm := GDHO_GetTextHoleLauncherMode()
    if textHoleShow && (lm = "panel" || lm = "both") {
        GDHO_ShowPanelOverlayForced(reason)
        return
    }
    if textHoleShow && (lm = "starry") {
        try GDHO_PresentStarryLauncher(Trim(String(g_GDHO_PendingPanelText)))
        return
    }
    if GDHO_PANEL_READY {
        GDHO_ApplyPanelVisibleChrome()
        if FuncExists("GDHO_FlushPendingPanelText")
            GDHO_FlushPendingPanelText()
    } else {
        try NativeDropDiag_Log("[PostSuck] show_panel_host_only reason=" . String(reason))
        if !g_GDHO_PendingPanelShow
            GDHO_ShowPanelWhenReady(reason)
    }
    if !(lm = "starry" || lm = "both")
        GDHO_HideStarryAfterPanel("show_panel_forced")
    try GDHO_Trace("show_panel_forced reason=" . String(reason) . " ready=" . (GDHO_PANEL_READY ? "1" : "0"))
}

GDHO_TextHolePresentRetry(*) {
    global g_GDHO_TextHolePresentRetryArmed, g_GDHO_PostSuckPanelPending, GDHO_SESSION_TEXT, GDHO_CURSOR_X, GDHO_CURSOR_Y
    global g_GDHO_TextHoleSessionSerial, GDHO_PANEL_VISIBLE, g_GDHO_PostSuckPresentDone, g_GDHO_StarryLauncherOpen
    g_GDHO_TextHolePresentRetryArmed := false
    if !GDHO_IsDecoupled()
        return
    if GDHO_IsStarryLauncherMode() {
        if (g_GDHO_PostSuckPresentDone || g_GDHO_StarryLauncherOpen)
            return
    } else if GDHO_PANEL_VISIBLE
        return
    if !g_GDHO_PostSuckPanelPending
        return
    t := Trim(String(GDHO_SESSION_TEXT))
    if (t = "") && FuncExists("GDHO_GetTextHoleCapturedText")
        try t := Trim(String(GDHO_GetTextHoleCapturedText()))
    if (t = "")
        return
    if !g_GDHO_PostSuckPresentDone {
        GDHO_PresentPanelAfterTextHoleDrop(t, GDHO_CURSOR_X, GDHO_CURSOR_Y, "present_retry_delayed", Integer(g_GDHO_TextHoleSessionSerial))
        return
    }
    try GDHO_EnsureDecoupledPanelWebHost()
}

GDHO_EnsurePanelVisibleAfterExpand(*) {
    global g_GDHO_PostSuckPresentDone, GDHO_PANEL_VISIBLE, GDHO_CURSOR_X, GDHO_CURSOR_Y, GDHO_SESSION_TEXT
    global g_GDHO_TextHoleSessionSerial, g_GDHO_TextHoleCommitSerial, g_GDHO_TextHoleAwaitingExpand, g_GDHO_TextHoleCommitDone
    if !GDHO_IsDecoupled()
        return
    t := ""
    if FuncExists("GDHO_GetTextHoleCapturedText")
        try t := Trim(String(GDHO_GetTextHoleCapturedText()))
    if (t = "")
        try t := Trim(String(GDHO_SESSION_TEXT))
    global g_GDHO_StarryLauncherOpen
    if (g_GDHO_PostSuckPresentDone && (GDHO_PANEL_VISIBLE || g_GDHO_StarryLauncherOpen))
        return
    if !GDHO_TextHolePresentAllowed() {
        if (t = "")
            return
        ; Recover session markers for late/async expand callbacks.
        if (Integer(g_GDHO_TextHoleSessionSerial) <= 0)
            g_GDHO_TextHoleSessionSerial := 1
        g_GDHO_TextHoleCommitSerial := g_GDHO_TextHoleSessionSerial
        g_GDHO_TextHoleAwaitingExpand := true
        g_GDHO_TextHoleCommitDone := true
        try NativeDropDiag_Log("[PostSuck] ensure_after_expand_rearm len=" . StrLen(t))
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    if (Integer(GDHO_CURSOR_X) = 0 && Integer(GDHO_CURSOR_Y) = 0) {
        GDHO_CURSOR_X := mx
        GDHO_CURSOR_Y := my
    }
    if GDHO_IsStarryLauncherMode() {
        try GDHO_PresentStarryLauncher(t)
        if !g_GDHO_PostSuckPresentDone
            try GDHO_PresentPanelAfterTextHoleDrop(t, Integer(GDHO_CURSOR_X), Integer(GDHO_CURSOR_Y), "ensure_after_expand")
        return
    }
    try GDHO_EnsurePanelShowPosition(Integer(GDHO_CURSOR_X), Integer(GDHO_CURSOR_Y))
    try GDHO_ShowPanelForced("ensure_after_expand")
    if !GDHO_PANEL_VISIBLE
        try GDHO_PresentPanelAfterTextHoleDrop(t, Integer(GDHO_CURSOR_X), Integer(GDHO_CURSOR_Y), "ensure_after_expand")
}

GDHO_ForcePresentPanelAfterCommit(*) {
    global g_GDHO_PostSuckPresentDone, GDHO_CURSOR_X, GDHO_CURSOR_Y, GDHO_SESSION_TEXT
    global g_GDHO_TextHoleSessionSerial, g_GDHO_TextHoleCommitSerial, g_GDHO_TextHoleAwaitingExpand, g_GDHO_TextHoleCommitDone
    if !GDHO_IsDecoupled()
        return
    if g_GDHO_PostSuckPresentDone
        return
    t := ""
    if FuncExists("GDHO_GetTextHoleCapturedText")
        try t := Trim(String(GDHO_GetTextHoleCapturedText()))
    if (t = "")
        try t := Trim(String(GDHO_SESSION_TEXT))
    if (t = "")
        return
    if !GDHO_TextHolePresentAllowed() {
        if (Integer(g_GDHO_TextHoleSessionSerial) <= 0)
            g_GDHO_TextHoleSessionSerial := 1
        g_GDHO_TextHoleCommitSerial := g_GDHO_TextHoleSessionSerial
        g_GDHO_TextHoleAwaitingExpand := true
        g_GDHO_TextHoleCommitDone := true
        try NativeDropDiag_Log("[TextHole] force_present_rearm_session len=" . StrLen(t))
    }
    try NativeDropDiag_Log("[TextHole] force_present_after_commit len=" . StrLen(t))
    GDHO_PresentPanelAfterTextHoleDrop(t, GDHO_CURSOR_X, GDHO_CURSOR_Y, "force_present_after_commit")
}

GDHO_IsTextHoleAwaitingExpand() {
    global g_GDHO_TextHoleAwaitingExpand, g_GDHO_TextHoleCommitDone
    return !!(g_GDHO_TextHoleAwaitingExpand || g_GDHO_TextHoleCommitDone)
}

; 展开动画进行中：禁止关星空/reset，否则收不到 hole_expand_complete。
GDHO_ShouldDeferStarryCloseForTextHole(reason := "") {
    global g_GDHO_TextHoleAwaitingExpand, g_GDHO_TextHoleCommitDone, g_GDHO_PostSuckPresentDone
    r := StrLower(Trim(String(reason)))
    if (InStr(r, "panel_hole_close") || InStr(r, "panel_dismiss") || InStr(r, "panel_escape") || InStr(r, "panel_close_btn"))
        return false
    if (g_GDHO_PostSuckPresentDone && IsSet(GDHO_PANEL_VISIBLE) && GDHO_PANEL_VISIBLE)
        return false
    if (g_GDHO_TextHoleAwaitingExpand || g_GDHO_TextHoleCommitDone)
        return true
    if FuncExists("GDHO_TextHolePresentAllowed") {
        try {
            if GDHO_TextHolePresentAllowed()
                return true
        } catch {
        }
    }
    if GDHO_IsGestureOpenGraceActive()
        return true
    if FuncExists("SelectionSense_IsSelectionHolePreviewActive") {
        try {
            if SelectionSense_IsSelectionHolePreviewActive() && (InStr(r, "drag_idle") || InStr(r, "drag_release") || InStr(r, "hide_overlay"))
                return true
        } catch {
        }
    }
    return false
}

GDHO_QuoteJsString(s) {
    s := StrReplace(String(s), "\", "\\")
    s := StrReplace(s, "`"", "\`"")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    return "`"" . s . "`""
}

GDHO_IsTextSelectionPreviewReady() {
    global g_GDHO_TextHoleCommitDone, g_SelSense_TextCaptured
    if g_GDHO_TextHoleCommitDone
        return false
    if !FuncExists("SelectionSense_IsSelectionHolePreviewActive")
        return false
    try {
        if !SelectionSense_IsSelectionHolePreviewActive()
            return false
    } catch {
        return false
    }
    return !!g_SelSense_TextCaptured
}

GDHO_ResetTextHoleCommitState() {
    GDHO_ResetTextHoleSession()
}

GDHO_EndSelectionPreviewForPanel() {
    global g_SelSense_HoleDragPhase, g_SelSense_TextCaptured, g_SelSense_AllowTextHoleGesture
    g_SelSense_AllowTextHoleGesture := false
    g_SelSense_HoleDragPhase := "idle"
    try SetTimer(SelectionSense_HideHoleAfterSelection, 0)
}

GDHO_ArmTextHoleProximityPoll() {
    global g_GDHO_TextHoleProxPollArmed
    if !GDHO_IsDecoupled()
        return
    if (GDHO_GetInteractionPhase() != GDHO_PHASE_WEAK_PREVIEW) {
        GDHO_DisarmTextHoleProximityPoll()
        return
    }
    if GDHO_ShouldBlockStarryReentry() {
        GDHO_DisarmTextHoleProximityPoll()
        return
    }
    g_GDHO_TextHoleProxPollArmed := true
    g_GDHO_TextHoleProxNeedsReenter := false
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    dist0 := GDHO_GetDistanceToHoleCenter(mx, my)
    enterR0 := Float(GDHO_TEXT_HOLE_OPEN_RADIUS_PX) * 0.92
    if (dist0 <= enterR0) {
        g_GDHO_TextHoleProxWasOutside := false
        g_GDHO_TextHoleProxInsideSince := A_TickCount
    } else {
        g_GDHO_TextHoleProxWasOutside := true
        g_GDHO_TextHoleProxInsideSince := 0
    }
    GDHO_TextHoleTransition(GDHO_TEXT_HOLE_STATE_ARMED, "arm_proximity_poll")
    try SetTimer(GDHO_PollTextHoleProximity, 0)
    SetTimer(GDHO_PollTextHoleProximity, 45)
}

GDHO_DisarmTextHoleProximityPoll() {
    global g_GDHO_TextHoleProxPollArmed, g_GDHO_TextHoleProxInsideSince
    g_GDHO_TextHoleProxPollArmed := false
    g_GDHO_TextHoleProxInsideSince := 0
    try SetTimer(GDHO_PollTextHoleProximity, 0)
}

GDHO_PollTextHoleProximity(*) {
    global g_GDHO_TextHoleProxPollArmed, g_GDHO_TextHoleProxWasOutside, g_GDHO_TextHoleProxInsideSince
    global g_GDHO_TextHoleProxNeedsReenter, GDHO_TEXT_HOLE_OPEN_RADIUS_PX, GDHO_TEXT_HOLE_PROX_DEBOUNCE_MS, GDHO_VISIBLE
    if GDHO_ShouldBlockStarryReentry() {
        GDHO_DisarmTextHoleProximityPoll()
        return
    }
    if !g_GDHO_TextHoleProxPollArmed
        return
    if !GDHO_IsTextSelectionPreviewReady() {
        GDHO_DisarmTextHoleProximityPoll()
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    dist := GDHO_GetDistanceToHoleCenter(mx, my)
    openR := Float(GDHO_TEXT_HOLE_OPEN_RADIUS_PX)
    ; Use hysteresis to avoid jitter around a single boundary:
    ; enter by inner radius, leave only after crossing a larger outer radius.
    enterR := openR * 0.92
    exitR := openR * 1.12
    if g_GDHO_TextHoleProxNeedsReenter {
        if (dist > exitR * 1.08) {
            g_GDHO_TextHoleProxNeedsReenter := false
            g_GDHO_TextHoleProxWasOutside := true
        } else if (dist <= enterR) {
            g_GDHO_TextHoleProxNeedsReenter := false
            g_GDHO_TextHoleProxWasOutside := false
            g_GDHO_TextHoleProxInsideSince := A_TickCount
            try GDHO_SetProximity(0.92)
        } else if GDHO_VISIBLE {
            prox := Max(0.08, Min(0.5, 1.0 - (dist / (openR * 2.5))))
            try GDHO_SetProximity(prox)
        }
        if g_GDHO_TextHoleProxNeedsReenter
            return
    }
    if g_GDHO_TextHoleProxWasOutside {
        if (dist > enterR) {
            g_GDHO_TextHoleProxInsideSince := 0
            if GDHO_VISIBLE {
                prox := Max(0.08, Min(0.55, 1.0 - (dist / (openR * 2.2))))
                try GDHO_SetProximity(prox)
            }
            return
        }
        g_GDHO_TextHoleProxWasOutside := false
        g_GDHO_TextHoleProxInsideSince := A_TickCount
        try GDHO_SetProximity(0.92)
        GDHO_TextHoleTransition(GDHO_TEXT_HOLE_STATE_ARMED, "proximity_enter", Integer(Round(dist)), "")
    } else if (dist > exitR) {
        g_GDHO_TextHoleProxWasOutside := true
        g_GDHO_TextHoleProxInsideSince := 0
        if GDHO_VISIBLE {
            prox := Max(0.08, Min(0.55, 1.0 - (dist / (openR * 2.2))))
            try GDHO_SetProximity(prox)
        }
        return
    }
    deb := Integer(GDHO_TEXT_HOLE_PROX_DEBOUNCE_MS)
    if (deb < 60)
        deb := 60
    if (g_GDHO_TextHoleProxInsideSince > 0 && (A_TickCount - g_GDHO_TextHoleProxInsideSince) >= deb)
        GDHO_CommitTextHoleToPanel("proximity", mx, my)
}

GDHO_CommitTextHoleToPanel(reason := "commit", mx := "", my := "") {
    global g_GDHO_TextHoleCommitDone, GDHO_SESSION_TEXT, GDHO_PAYLOAD, GDHO_CURSOR_X, GDHO_CURSOR_Y
    if GDHO_ShouldBlockStarryReentry() || !GDHO_CanCommitTextHole() {
        try NativeDropDiag_Log("[TextHole] commit_skip reason=" . String(reason) . " phase=" . GDHO_GetInteractionPhase())
        return false
    }
    if !GDHO_IsDecoupled() || g_GDHO_TextHoleCommitDone
        return false
    if (!GDHO_IsTextSelectionPreviewReady())
        return false
    t := ""
    if FuncExists("SelectionSense_GetLastSelectedText")
        try t := Trim(SelectionSense_GetLastSelectedText())
    if (t = "") && FuncExists("GDHO_GetBestSelectedText")
        try t := Trim(GDHO_GetBestSelectedText())
    if (t = "")
        return false
    if (mx = "" || my = "") {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
    }
    mx := Integer(mx), my := Integer(my)
    global g_GDHO_TextHoleCapturedText, g_GDHO_TextHoleAwaitingExpand, g_GDHO_PostSuckPresentDone
    global g_GDHO_TextHoleSessionSerial, g_GDHO_TextHoleCommitSerial, g_GDHO_TextHoleCommitTick, GDHO_TEXT_HOLE_EXPAND_MS
    global g_GDHO_TextHoleFallbackSessionId
    if (Integer(g_GDHO_TextHoleSessionSerial) <= 0)
        g_GDHO_TextHoleSessionSerial := 1
    g_GDHO_TextHoleCommitDone := true
    g_GDHO_TextHoleCommitTick := A_TickCount
    g_GDHO_PostSuckPresentDone := false
    g_GDHO_TextHoleCapturedText := t
    g_GDHO_TextHoleCommitSerial := g_GDHO_TextHoleSessionSerial
    g_GDHO_TextHoleAwaitingExpand := true
    g_GDHO_PostSuckPanelPending := false
    g_GDHO_SuppressSelectionAutoHide := true
    if FuncExists("GDHO_WS_Send")
        try GDHO_WS_Send("hole_commit", mx, my, t, String(reason))
    GDHO_DisarmTextHoleProximityPoll()
    GDHO_ArmTextHoleCommitWatch()
    GDHO_ClearTextDragHandoff(false)
    GDHO_SESSION_TEXT := t
    GDHO_PAYLOAD := "text"
    GDHO_CURSOR_X := mx
    GDHO_CURSOR_Y := my
    try GDHO_RememberOnScreenHoleCenter(mx, my)
    g_GDHO_TextHoleFallbackSessionId := g_GDHO_TextHoleSessionSerial
    GDHO_SetInteractionPhase(GDHO_PHASE_COMMITTING, "commit_begin:" . String(reason))
    GDHO_TextHoleTransition(GDHO_TEXT_HOLE_STATE_COMMITTED, String(reason), "", StrLen(t))
    try SetTimer(SelectionSense_HideHoleAfterSelection, 0)
    GDHO_CancelTextHolePresentTimers()
    expMs := Integer(GDHO_TEXT_HOLE_EXPAND_MS)
    if (expMs < 900)
        expMs := 1250
    fbMs := expMs + 280
    ; Single present fallback if hole_expand_complete is lost (was 3+ parallel timers).
    SetTimer(GDHO_TextHoleExpandFallback, -fbMs)
    GDHO_TextHoleTransition(GDHO_TEXT_HOLE_STATE_EXPANDING, "dispatch_drop", "", StrLen(t))
    try GDHO_EnsurePanelHostForPhase("analyzing")
    GDHO_TraceInteraction("commit", String(reason))
    global g_GDHO_TextHoleFastPresentSid, g_GDHO_TextHoleFastPresentText, g_GDHO_TextHoleFastPresentX, g_GDHO_TextHoleFastPresentY
    g_GDHO_TextHoleFastPresentText := t
    g_GDHO_TextHoleFastPresentX := mx
    g_GDHO_TextHoleFastPresentY := my
    g_GDHO_TextHoleFastPresentSid := Integer(g_GDHO_TextHoleSessionSerial)
    try SetTimer(GDHO_TextHoleFastPresentTimer, 0)
    if GDHO_UseLauncherLayer() {
        global g_GDHO_PendingPanelText
        g_GDHO_PendingPanelText := t
        try GDHO_MarkTextHoleExpandedHold()
        try GDHO_EnsureLauncherLayerHost()
        try GDHO_ShowStarryPassthroughOnly("commit_drop")
        try GDHO_ShowLauncherLayerForced("commit_drop")
    }
    try GDHO_RunStarryJS("window.HoleOverlay?.drop?.({payload:'text',force:true});")
    if FuncExists("GDHO_P2_IsEnabled") && GDHO_P2_IsEnabled() {
        try GDHO_P2_RequestPanelPresent(t, mx, my, String(reason))
    } else {
        SetTimer(GDHO_TextHoleFastPresentTimer, -420)
    }
    try NativeDropDiag_Log("[PostSuck] commit sid=" . g_GDHO_TextHoleSessionSerial . " reason=" . String(reason) . " len=" . StrLen(t) . " expand_ms=" . expMs)
    return true
}

GDHO_CommitEarlyLauncherPump(*) {
    global g_GDHO_PendingPanelText, g_GDHO_TextHoleFastPresentText, g_GDHO_TextHoleFastPresentX, g_GDHO_TextHoleFastPresentY
    global g_GDHO_LauncherGridSent
    if !(GDHO_UseLauncherLayer() && GDHO_IsStarryLauncherMode())
        return
    try GDHO_MarkTextHoleExpandedHold()
    try GDHO_SyncHoleCenterFromStarryWindow()
    try GDHO_SuppressEmbeddedStarryLauncher()
    if !(GDHO_LAUNCHER_VISIBLE) {
        try GDHO_ShowLauncherLayerForced("commit_early_pump")
    } else {
        try GDHO_SyncLauncherLayerPosition()
        if (GDHO_LAUNCHER_READY && !g_GDHO_LauncherGridSent) {
            try GDHO_SendLauncherLayerConfig()
        }
    }
}

GDHO_OnLauncherExpandStart(msg := 0) {
    global g_GDHO_PendingPanelText, GDHO_SESSION_TEXT
    if !GDHO_UseLauncherLayer()
        return
    t := ""
    if (msg is Map) {
        if msg.Has("previewText")
            t := Trim(String(msg["previewText"]))
        else if msg.Has("text")
            t := Trim(String(msg["text"]))
    }
    if (t = "")
        t := Trim(String(g_GDHO_PendingPanelText))
    if (t = "")
        t := Trim(String(GDHO_SESSION_TEXT))
    if (t != "")
        g_GDHO_PendingPanelText := t
    try GDHO_MarkTextHoleExpandedHold()
    try GDHO_ShowStarryPassthroughOnly("launcher_expand_start")
    if !(GDHO_LAUNCHER_VISIBLE) {
        try GDHO_ShowLauncherLayerForced("launcher_expand_start")
    } else {
        try GDHO_SyncLauncherLayerPosition()
        global g_GDHO_LauncherGridSent
        if (GDHO_LAUNCHER_READY && !g_GDHO_LauncherGridSent) {
            try GDHO_SendLauncherLayerConfig()
        }
    }
}

GDHO_TextHoleFastPresentTimer(*) {
    global g_GDHO_TextHoleFastPresentSid, g_GDHO_TextHoleFastPresentText, g_GDHO_TextHoleFastPresentX, g_GDHO_TextHoleFastPresentY
    sid := Integer(g_GDHO_TextHoleFastPresentSid)
    t := Trim(String(g_GDHO_TextHoleFastPresentText))
    if (sid <= 0 || t = "")
        return
    if FuncExists("GDHO_P2_IsEnabled") && GDHO_P2_IsEnabled() {
        GDHO_P2_RequestPanelPresent(t, g_GDHO_TextHoleFastPresentX, g_GDHO_TextHoleFastPresentY, "commit_fast")
    } else {
        try GDHO_PresentPanelAfterTextHoleDrop(t, g_GDHO_TextHoleFastPresentX, g_GDHO_TextHoleFastPresentY, "commit_fast", sid)
    }
}

GDHO_TryCommitTextHoleOnClick(mx, my) {
    if GDHO_ShouldBlockStarryReentry() || !GDHO_CanCommitTextHole()
        return true
    if GDHO_IsTextHoleUserPanelActive()
        return true
    if !GDHO_IsTextSelectionPreviewReady()
        return false
    inHole := false
    if FuncExists("GDHO_IsPointInHole")
        try inHole := GDHO_IsPointInHole(Integer(mx), Integer(my), 28)
    if !inHole {
        dist := GDHO_GetDistanceToHoleCenter(Integer(mx), Integer(my))
        if (dist > Float(GDHO_INNER_RADIUS) + 36.0)
            return false
    }
    return GDHO_CommitTextHoleToPanel("click", mx, my)
}

GDHO_ApplyTextPreviewStarryInteractive(*) {
    if !GDHO_IsTextSelectionPreviewReady()
        return
    if FuncExists("GDHO_P2_IsEnabled") && GDHO_P2_IsEnabled()
        return
    try GDHO_SetStarryClickThrough(false, "selection_preview_interactive")
}

; 解耦文本：不再走拖动接手，仅保留划选预览期间的靠近/点击提交。
GDHO_HandoffTextDragToPanel(mx := "", my := "", reason := "text_drag_handoff") {
    if !GDHO_IsDecoupled()
        return false
    try SetTimer(SelectionSense_HideHoleAfterSelection, 0)
    return true
}

GDHO_RaisePanelAboveStarry() {
    global GDHO_STAR_GUI, GDHO_PANEL_GUI, GDHO_LAUNCHER_GUI, GDHO_LAUNCHER_VISIBLE
    if !(IsObject(GDHO_STAR_GUI) && IsObject(GDHO_PANEL_GUI))
        return
    anchor := GDHO_STAR_GUI.Hwnd
    if (GDHO_LAUNCHER_VISIBLE && IsObject(GDHO_LAUNCHER_GUI) && GDHO_LAUNCHER_GUI.Hwnd)
        anchor := GDHO_LAUNCHER_GUI.Hwnd
    try {
        DllCall("SetWindowPos", "Ptr", GDHO_PANEL_GUI.Hwnd, "Ptr", anchor, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
    } catch {
    }
}

GDHO_RunStarryJS(js) {
    global GDHO_WV2_STAR, GDHO_STAR_READY, GDHO_WV2, GDHO_READY
    wv := GDHO_IsDecoupled() ? GDHO_WV2_STAR : GDHO_WV2
    ready := GDHO_IsDecoupled() ? GDHO_STAR_READY : GDHO_READY
    if !(wv && ready)
        return false
    try {
        wv.ExecuteScript(js)
        return true
    } catch {
        return false
    }
}

GDHO_RunPanelJS(js) {
    global GDHO_WV2_PANEL, GDHO_PANEL_READY
    if !(GDHO_WV2_PANEL && GDHO_PANEL_READY)
        return false
    try {
        GDHO_WV2_PANEL.ExecuteScript(js)
        return true
    } catch {
        return false
    }
}

GDHO_OnStarryWebViewCreated(ctrl) {
    global GDHO_WV2_CTRL_STAR, GDHO_WV2_STAR, GDHO_WV2_CTRL, GDHO_WV2, GDHO_STAR_READY, GDHO_READY
    global GDHO_PAGE_URL, GDHO_NAV_FAIL_COUNT, g_GDHO_StarryCreateInFlight, g_GDHO_CreateToken, GDHO_STAR_GUI
    global g_GDHO_PanelCreateInFlight, GDHO_WV2_CTRL_PANEL, GDHO_PANEL_GUI
    if !GDHO_IsCurrentToken(g_GDHO_CreateToken) {
        try ctrl.Close()
        catch {
        }
        return
    }
    if !IsObject(GDHO_STAR_GUI) {
        g_GDHO_StarryCreateInFlight := false
        try ctrl.Close()
        catch {
        }
        return
    }
    g_GDHO_StarryCreateInFlight := false
    if !IsObject(ctrl) || !ctrl.HasProp("CoreWebView2") {
        GDHO_SubmitIntent("FORCE_RESET", 5, Map("reason", "starry_webview_create_failed"))
        return
    }
    GDHO_WV2_CTRL_STAR := ctrl
    GDHO_WV2_CTRL := ctrl
    GDHO_WV2_STAR := ctrl.CoreWebView2
    GDHO_WV2 := GDHO_WV2_STAR
    GDHO_STAR_READY := false
    GDHO_READY := false
    GDHO_NAV_FAIL_COUNT := 0
    try ctrl.IsVisible := true
    try ctrl.DefaultBackgroundColor := 0x00000000
    try ctrl.AllowExternalDrop := false
    GDHO_ResizeStarryHost()
    try {
        s := GDHO_WV2_STAR.Settings
        s.AreDefaultContextMenusEnabled := false
        s.AreDevToolsEnabled := false
        s.AreBrowserAcceleratorKeysEnabled := false
    }
    try ApplyWebView2PerformanceSettings(GDHO_WV2_STAR)
    try GDHO_ApplyHostMappingFor(GDHO_WV2_STAR)
    try WebView2_RegisterHostBridge(GDHO_WV2_STAR)
    try GDHO_WV2_STAR.add_WebMessageReceived(GDHO_OnWebMessage)
    try GDHO_WV2_STAR.add_NavigationCompleted(GDHO_OnStarryNavigationCompleted)
    try GDHO_WV2_STAR.Navigate(GDHO_PAGE_URL)
    if GDHO_UseLauncherLayer()
        try SetTimer(GDHO_PrewarmLauncherLayerHost, -120)
    ; P1: panel WebView2 deferred until analyzing (GDHO_EnsurePanelHostForPhase).
}

GDHO_PrewarmLauncherLayerHost(*) {
    if !GDHO_UseLauncherLayer()
        return
    try GDHO_CreateLauncherGui()
    try GDHO_EnsureLauncherLayerHost()
}

GDHO_OnPanelWebViewCreated(ctrl) {
    global GDHO_WV2_CTRL_PANEL, GDHO_WV2_PANEL, GDHO_PANEL_READY, GDHO_PANEL_PAGE_URL
    global g_GDHO_PanelCreateInFlight, g_GDHO_PanelCreateStartedTick, GDHO_PANEL_GUI
    g_GDHO_PanelCreateInFlight := false
    g_GDHO_PanelCreateStartedTick := 0
    if !IsObject(GDHO_PANEL_GUI) || !GDHO_PANEL_GUI.Hwnd {
        try NativeDropDiag_Log("[TextHole] panel_webview_abort reason=no_panel_gui")
        try ctrl.Close()
        catch {
        }
        return
    }
    try {
        if IsObject(ctrl) && ctrl.Hwnd && (Integer(ctrl.Hwnd) != Integer(GDHO_PANEL_GUI.Hwnd)) {
            try NativeDropDiag_Log("[TextHole] panel_webview_abort reason=hwnd_mismatch panel=" . GDHO_PANEL_GUI.Hwnd . " ctrl=" . ctrl.Hwnd)
            try ctrl.Close()
            catch {
            }
            return
        }
    } catch {
    }
    if !IsObject(ctrl) || !ctrl.HasProp("CoreWebView2") {
        try NativeDropDiag_Log("[TextHole] panel_webview_create_failed")
        return
    }
    GDHO_WV2_CTRL_PANEL := ctrl
    GDHO_WV2_PANEL := ctrl.CoreWebView2
    GDHO_PANEL_READY := false
    try ctrl.IsVisible := true
    try ctrl.DefaultBackgroundColor := 0x00000000
    try ctrl.AllowExternalDrop := true
    GDHO_ResizePanelHost()
    try {
        s := GDHO_WV2_PANEL.Settings
        s.AreDefaultContextMenusEnabled := false
        s.AreDevToolsEnabled := false
        s.AreBrowserAcceleratorKeysEnabled := false
    }
    try ApplyWebView2PerformanceSettings(GDHO_WV2_PANEL)
    try GDHO_ApplyHostMappingFor(GDHO_WV2_PANEL)
    try WebView2_RegisterHostBridge(GDHO_WV2_PANEL)
    try GDHO_WV2_PANEL.add_WebMessageReceived(GDHO_OnPanelWebMessage)
    try GDHO_WV2_PANEL.add_NavigationCompleted(GDHO_OnPanelNavigationCompleted)
    navUrl := GDHO_ResolvePanelPageUrl()
    try NativeDropDiag_Log("[TextHole] panel_webview_created url=" . (navUrl != "" ? "ok" : "empty"))
    if (navUrl != "")
        try GDHO_WV2_PANEL.Navigate(navUrl)
}

GDHO_ApplyHostMappingFor(wv2) {
    if !wv2
        return
    try {
        if IsSet(ApplyUnifiedWebViewAssets) {
            ApplyUnifiedWebViewAssets(wv2)
            return
        }
    } catch {
    }
    try wv2.SetVirtualHostNameToFolderMapping("app.local", A_ScriptDir, 0)
}

GDHO_OnLauncherWebViewCreated(ctrl) {
    global GDHO_WV2_CTRL_LAUNCHER, GDHO_WV2_LAUNCHER, GDHO_LAUNCHER_READY, GDHO_LAUNCHER_GUI
    global g_GDHO_LauncherCreateInFlight
    g_GDHO_LauncherCreateInFlight := false
    if !IsObject(GDHO_LAUNCHER_GUI) || !GDHO_LAUNCHER_GUI.Hwnd {
        try ctrl.Close()
        catch {
        }
        return
    }
    if !IsObject(ctrl) || !ctrl.HasProp("CoreWebView2") {
        try NativeDropDiag_Log("[TextHole] launcher_webview_create_failed")
        return
    }
    GDHO_WV2_CTRL_LAUNCHER := ctrl
    GDHO_WV2_LAUNCHER := ctrl.CoreWebView2
    GDHO_LAUNCHER_READY := false
    try ctrl.IsVisible := true
    try ctrl.DefaultBackgroundColor := 0x00000000
    try ctrl.AllowExternalDrop := false
    GDHO_ResizeLauncherHost()
    try GDHO_ApplyLauncherLayerInteractive("launcher_webview_created")
    try {
        s := GDHO_WV2_LAUNCHER.Settings
        s.AreDefaultContextMenusEnabled := false
        s.AreDevToolsEnabled := false
        s.AreBrowserAcceleratorKeysEnabled := false
    }
    try ApplyWebView2PerformanceSettings(GDHO_WV2_LAUNCHER)
    try GDHO_ApplyHostMappingFor(GDHO_WV2_LAUNCHER)
    try WebView2_RegisterHostBridge(GDHO_WV2_LAUNCHER)
    try GDHO_WV2_LAUNCHER.add_WebMessageReceived(GDHO_OnLauncherWebMessage)
    try GDHO_WV2_LAUNCHER.add_NavigationCompleted(GDHO_OnLauncherNavigationCompleted)
    navUrl := GDHO_ResolveLauncherPageUrl()
    if (navUrl != "")
        try GDHO_WV2_LAUNCHER.Navigate(navUrl)
}

GDHO_OnLauncherNavigationCompleted(sender, args) {
    global GDHO_LAUNCHER_READY, g_GDHO_PendingLauncherShow, g_GDHO_StarryLauncherOpen
    ok := false
    try ok := args.IsSuccess
    GDHO_LAUNCHER_READY := !!ok
    try NativeDropDiag_Log("[TextHole] launcher_nav_completed ok=" . (ok ? "1" : "0"))
    if GDHO_LAUNCHER_READY {
        try GDHO_WV2_CTRL_LAUNCHER.DefaultBackgroundColor := 0x00000000
        try GDHO_ApplyLauncherLayerInteractive("launcher_nav_completed")
        if g_GDHO_PendingLauncherShow || g_GDHO_StarryLauncherOpen {
            if FuncExists("NMER_Log")
                try NMER_Log("P2_NAV", "nav_completed_trigger_pump", "pending=" . (g_GDHO_PendingLauncherShow ? "1" : "0") . " open=" . (g_GDHO_StarryLauncherOpen ? "1" : "0"))
            try NativeDropDiag_Log("[P2_NAV] nav_completed_trigger_pump pending=" . (g_GDHO_PendingLauncherShow ? "1" : "0") . " open=" . (g_GDHO_StarryLauncherOpen ? "1" : "0"))
            try GDHO_LauncherShowPump()
        } else if GDHO_UseLauncherLayer() {
            global g_GDHO_PostSuckPresentDone
            if g_GDHO_PostSuckPresentDone || GDHO_IsTextHolePanelOpen() {
                g_GDHO_StarryLauncherOpen := true
                try SetTimer(GDHO_LauncherNavPresentDonePump, -40)
            }
        }
        return
    }
    ; app.local 导航失败时回退 file:// 交叉验证（映射由 ApplyUnifiedWebViewAssets / GDHO_ApplyHostMappingFor 提供）
    fb := ""
    if FileExist(A_ScriptDir . "\hole_launcher_layer.html") {
        if FuncExists("GDHO_BuildFileUrl")
            try fb := GDHO_BuildFileUrl(A_ScriptDir . "\hole_launcher_layer.html")
        if (fb = "")
            fb := "file:///" . StrReplace(A_ScriptDir . "\hole_launcher_layer.html", "\", "/")
    }
    if (fb != "")
        try NativeDropDiag_Log("[TextHole] launcher_nav_fallback file=" . fb)
    if (fb != "") && IsObject(GDHO_WV2_LAUNCHER)
        try GDHO_WV2_LAUNCHER.Navigate(fb)
}

GDHO_OnLauncherWebMessage(sender, args) {
    msg := 0
    try {
        raw := args.TryGetWebMessageAsString()
        if (raw != "")
            msg := Jxon_Load(raw)
    } catch {
    }
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
    try NativeDropDiag_Log("[LauncherWM] type=" . typ)
    if FuncExists("GDHO_WS_RelayPanelMessage")
        try GDHO_WS_RelayPanelMessage(msg)
    if (typ = "hole_close") {
        rs := msg.Has("reason") ? StrLower(Trim(String(msg["reason"]))) : ""
        try GDHO_DismissLauncherUI("launcher_wm_hole_close:" . rs)
        if (rs = "launcher_close_btn" || rs = "panel_close_btn" || rs = "panel_escape") {
            if FuncExists("GDHO_DismissTextHolePanel")
                GDHO_DismissTextHolePanel(rs)
            else if FuncExists("GDHO_HidePanel")
                GDHO_HidePanel("launcher_hole_close")
        }
        return
    }
    if (typ = "panel_open_manual" || typ = "panel_scene_pick") {
        try {
            GDHO_HandleLauncherPick(msg)
        } catch as e {
            try NativeDropDiag_Log("[LauncherWM] HandleLauncherPick_ERR " . e.Message)
        }
        return
    }
}

GDHO_OnStarryNavigationCompleted(sender, args) {
    global GDHO_STAR_READY, GDHO_READY, GDHO_FALLBACK_URL, GDHO_NAV_FAIL_COUNT, GDHO_PREWARM_DONE
    global GDHO_DESKTOP_PINNED, GDHO_PIN_PAYLOAD, GDHO_PAGE_URL, g_GDHO_CurrentToken, GDHO_MANUAL_PANEL_MODE
    ok := false
    try ok := args.IsSuccess
    GDHO_STAR_READY := !!ok
    GDHO_READY := GDHO_STAR_READY
    if GDHO_STAR_READY {
        GDHO_NAV_FAIL_COUNT := 0
        try GDHO_WV2_CTRL_STAR.DefaultBackgroundColor := 0x00000000
        try WinSetTransColor("010101", "ahk_id " GDHO_STAR_GUI.Hwnd)
        global g_GDHO_PendingStarryLauncherShow, g_GDHO_StarryLauncherOpen
        if GDHO_UseLauncherLayer() {
            if (g_GDHO_PendingLauncherShow || g_GDHO_PendingStarryLauncherShow)
                try SetTimer(GDHO_LauncherShowPump, -40)
        } else if (g_GDHO_PendingStarryLauncherShow || g_GDHO_StarryLauncherOpen) {
            try GDHO_ApplyStarryLauncherInteractive("starry_nav_completed")
        } else {
            GDHO_SetStarryClickThrough(true, "starry_nav_completed")
        }
        if g_GDHO_PendingStarryLauncherShow
            try SetTimer(GDHO_FlushPendingStarryLauncher, -40)
        if !GDHO_PREWARM_DONE {
            GDHO_PREWARM_DONE := true
            SetTimer(GDHO_PrewarmOffscreen, -40)
        }
        if GDHO_DESKTOP_PINNED {
            p := (GDHO_PIN_PAYLOAD = "file") ? "file" : "text"
            GDHO_QueueFrontendJs("window.HoleOverlay?.show('" p "')", g_GDHO_CurrentToken)
        }
        GDHO_RevealIfReady(g_GDHO_CurrentToken, "starry_nav_completed")
        if GDHO_MANUAL_PANEL_MODE
            GDHO_ShowPanel("starry_nav_manual")
        if (GDHO_IsTextDragSession() || g_GDHO_TextOlePassthrough)
            try GDHO_SetWebOlePassthrough(true)
        return
    }
    GDHO_NAV_FAIL_COUNT += 1
    if (GDHO_FALLBACK_URL != "" && GDHO_NAV_FAIL_COUNT <= 2)
        try GDHO_WV2_STAR.Navigate(GDHO_FALLBACK_URL)
}

GDHO_OnPanelNavigationCompleted(sender, args) {
    global GDHO_PANEL_READY, GDHO_PANEL_FALLBACK_URL, GDHO_MANUAL_PANEL_MODE
    global g_GDHO_PostSuckPanelPending, g_GDHO_TextHolePanelOpen, g_GDHO_TextHoleStickyPanel
    ok := false
    try ok := args.IsSuccess
    GDHO_PANEL_READY := !!ok
    if GDHO_PANEL_READY {
        try GDHO_WV2_CTRL_PANEL.DefaultBackgroundColor := 0x00000000
        GDHO_SetPanelInteractive("panel_nav_completed")
        global g_GDHO_PendingPanelShow, g_GDHO_PendingPanelShowReason
        if g_GDHO_PendingPanelShow {
            g_GDHO_PendingPanelShow := false
            GDHO_ShowPanelForced(g_GDHO_PendingPanelShowReason)
            return
        }
        global g_GDHO_TextHolePanelLocked, g_GDHO_PendingPanelText, g_GDHO_TextHoleAwaitingExpand, g_GDHO_PostSuckTimerArmed
        phNav := GDHO_GetInteractionPhase()
        if GDHO_IsStarryLauncherMode() {
            try NativeDropDiag_Log("[TextHole] panel_nav_skip reason=starry_launcher")
            if FuncExists("GDHO_FlushPendingPanelText")
                GDHO_FlushPendingPanelText()
            if GDHO_PANEL_VISIBLE && FuncExists("GDHO_HidePanel")
                try GDHO_HidePanel("starry_panel_nav_hide")
            return
        }
        forceKeepPanel := !!(g_GDHO_PostSuckPanelPending || g_GDHO_PendingPanelShow || g_GDHO_TextHolePanelOpen
            || g_GDHO_TextHoleStickyPanel || g_GDHO_TextHolePanelLocked || GDHO_PANEL_VISIBLE
            || g_GDHO_TextHoleAwaitingExpand || g_GDHO_PostSuckTimerArmed
            || (phNav = GDHO_PHASE_COMMITTING || phNav = GDHO_PHASE_PANEL_OPEN)
            || Trim(String(g_GDHO_PendingPanelText)) != "")
        if FuncExists("GDHO_ShouldKeepTextHolePanel") {
            try forceKeepPanel := (forceKeepPanel || GDHO_ShouldKeepTextHolePanel())
            catch {
            }
        }
        if (forceKeepPanel || (FuncExists("GDHO_ShouldShowDecoupledPanel") && GDHO_ShouldShowDecoupledPanel("panel_nav_completed"))) {
            GDHO_ShowPanel("panel_nav_completed")
            GDHO_ApplyPanelVisibleChrome()
            if FuncExists("GDHO_FlushPendingPanelText")
                GDHO_FlushPendingPanelText()
        } else if FuncExists("GDHO_IsTextHoleUserPanelActive") && GDHO_IsTextHoleUserPanelActive() {
            try GDHO_Trace("panel_nav_keep reason=panel_active")
            try GDHO_ShowPanel("panel_nav_keep")
            GDHO_ApplyPanelVisibleChrome()
        } else {
            try NativeDropDiag_Log("[TextHole] panel_nav_idle_keep_wv2 reason=no_present_intent")
            if FuncExists("GDHO_FlushPendingPanelText")
                GDHO_FlushPendingPanelText()
        }
        return
    }
    fb := GDHO_ResolvePanelPageUrl()
    if (fb != "")
        try GDHO_WV2_PANEL.Navigate(fb)
}

GDHO_OnPanelWebMessage(sender, args) {
    msg := 0
    try {
        raw := args.TryGetWebMessageAsString()
        if (raw != "")
            msg := Jxon_Load(raw)
    } catch {
    }
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
    if FuncExists("GDHO_WS_RelayPanelMessage")
        try GDHO_WS_RelayPanelMessage(msg)
    if (typ = "hole_close") {
        rs := msg.Has("reason") ? StrLower(Trim(String(msg["reason"]))) : ""
        if (rs != "panel_close_btn" && rs != "panel_escape" && rs != "launcher_close_btn") {
            try GDHO_Trace("panel_hole_close_ignored reason=" . (rs = "" ? "empty" : rs))
            return
        }
        if FuncExists("GDHO_DismissTextHolePanel")
            GDHO_DismissTextHolePanel(rs)
        else
            GDHO_HidePanel("panel_hole_close")
        return
    }
    if (typ = "panel_show_request") {
        if !(FuncExists("GDHO_ShouldShowDecoupledPanel") && GDHO_ShouldShowDecoupledPanel("panel_show_request"))
            return
        GDHO_ShowPanel("panel_show_request")
        return
    }
    if (typ = "panel_stream_start") {
        if !(FuncExists("GDHO_ShouldShowDecoupledPanel") && GDHO_ShouldShowDecoupledPanel("panel_stream_start"))
            return
        GDHO_ShowPanel("panel_stream_start")
        return
    }
    if (typ = "panel_open_manual" || typ = "panel_scene_pick") {
        try {
            GDHO_HandleLauncherPick(msg)
        } catch as e {
            try NativeDropDiag_Log("[PanelWM] HandleLauncherPick_ERR " . e.Message)
        }
        return
    }
    if (typ = "panel_launcher_show") {
        try GDHO_RunPanelJS("try{window.HolePanel?.showLauncher?.();}catch(_e){}")
        try GDHO_SendPanelDockConfig()
        return
    }
    if (typ = "panel_input_focus" || typ = "panel_input_activity") {
        try GDHO_LockTextHoleUserPanel()
        try GDHO_ArmPanelHold()
        try SetTimer(SelectionSense_HideHoleAfterSelection, 0)
        global g_GDHO_PanelUserDragging
        g_GDHO_PanelUserDragging := false
        try GDHO_Trace("panel_input_keep_starry type=" . typ)
        return
    }
    if (typ = "panel_drag_start") {
        try GDHO_ActivatePanelHost("panel_drag_start")
        try GDHO_LockTextHoleUserPanel()
        global g_GDHO_PanelUserDragging, g_GDHO_PanelDragBaseW, g_GDHO_PanelDragBaseH
        global GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y, g_GDHO_PanelDragInProgress, g_GDHO_PanelLastMoveTick
        g_GDHO_PanelDragInProgress := true
        g_GDHO_PanelLastMoveTick := 0
        g_GDHO_PanelUserDragging := true
        g_GDHO_PanelDragBaseW := Integer(GDHO_PANEL_W)
        g_GDHO_PanelDragBaseH := Integer(GDHO_PANEL_H)
        if IsObject(GDHO_PANEL_GUI) {
            try GDHO_PANEL_GUI.GetPos(&gx, &gy, &gw, &gh)
            if (Integer(gw) >= 320)
                g_GDHO_PanelDragBaseW := Integer(gw)
            if (Integer(gh) >= 280)
                g_GDHO_PanelDragBaseH := Integer(gh)
            if (Integer(gx) > -2800 && Integer(gy) > -2800) {
                GDHO_PANEL_LAST_X := Integer(gx)
                GDHO_PANEL_LAST_Y := Integer(gy)
            }
        }
        ax := msg.Has("screenX") ? Integer(msg["screenX"]) : Integer(GDHO_PANEL_LAST_X)
        ay := msg.Has("screenY") ? Integer(msg["screenY"]) : Integer(GDHO_PANEL_LAST_Y)
        if (ax > -2800 && ay > -2800) {
            GDHO_PANEL_LAST_X := ax
            GDHO_PANEL_LAST_Y := ay
        }
        try GDHO_DisarmTextHoleProximityPoll()
        try GDHO_DisarmTextHoleCommitWatch()
        try GDHO_CancelTextHolePresentTimers()
        try GDHO_HideStarryAfterPanel("panel_drag")
        try GDHO_SetProximity(0.0)
        try NativeDropDiag_Log("[TextHole] panel_drag_start suppress_starry=1 x=" . GDHO_PANEL_LAST_X . " y=" . GDHO_PANEL_LAST_Y)
        try GDHO_ArmPanelDragGrace(6000)
        try SetTimer(GDHO_ClearPanelUserDragging, 0)
        try GDHO_PanelDragSetOpaque(true)
        try GDHO_RunPanelJS("try{window.HolePanel?.syncDragHostAnchor?.(" . Integer(GDHO_PANEL_LAST_X) . "," . Integer(GDHO_PANEL_LAST_Y) . ");document.getElementById('panelRoot')&&(document.getElementById('panelRoot').style.pointerEvents='auto');}catch(_e){}")
        if !GDHO_BeginPanelHostDrag() {
            try GDHO_ActivatePanelHost("panel_drag_start")
        }
        return
    }
    if (typ = "panel_drag_end") {
        global g_GDHO_PanelUserDragging, g_GDHO_PanelDragBaseW, g_GDHO_PanelDragBaseH, g_GDHO_PanelDragInProgress
        g_GDHO_PanelDragInProgress := false
        g_GDHO_PanelUserDragging := true
        g_GDHO_PanelDragBaseW := 0
        g_GDHO_PanelDragBaseH := 0
        try GDHO_ArmPanelDragGrace(1200)
        try GDHO_LockTextHoleUserPanel()
        try GDHO_PanelDragSetOpaque(false)
        try GDHO_SetPanelInteractive("panel_drag_end")
        try SetTimer(GDHO_ClearPanelUserDragging, -900)
        try GDHO_RunPanelJS("try{var mp=document.getElementById('manualPanel');if(mp)mp.classList.remove('dragging');window.HolePanel?.onHostShowCurrent?.();}catch(_e){}")
        return
    }
    if (typ = "panel_moved") {
        global g_GDHO_PanelUserDragging, g_GDHO_PanelDragInProgress, g_GDHO_PanelLastMoveTick
        g_GDHO_PanelDragInProgress := true
        g_GDHO_PanelUserDragging := true
        try GDHO_ArmPanelDragGrace(6000)
        if !(msg.Has("screenX") && msg.Has("screenY"))
            return
        now := A_TickCount
        if (g_GDHO_PanelLastMoveTick > 0 && (now - g_GDHO_PanelLastMoveTick) < 10)
            return
        g_GDHO_PanelLastMoveTick := now
        try GDHO_MovePanelHostScreen(msg["screenX"], msg["screenY"])
        return
    }
}

GDHO_OnPanelActivate(wParam, lParam, msg, hwnd) {
    global GDHO_PANEL_GUI, g_GDHO_PanelDeactivatePending
    if !IsObject(GDHO_PANEL_GUI) || hwnd != GDHO_PANEL_GUI.Hwnd
        return
    wa := Integer(wParam) & 0xFFFF
    g_GDHO_PanelDeactivatePending := false
    ; Do not auto-hide panel on deactivate; close is explicit via Esc/close button.
    return
}

GDHO_PanelDeactivateCheck(*) {
    ; Disabled: panel should not auto-exit.
    return
}

GDHO_ShowPanel(reason := "") {
    global GDHO_PANEL_GUI, GDHO_PANEL_VISIBLE, GDHO_PANEL_W, GDHO_PANEL_H, GDHO_PANEL_PINNED
    global GDHO_PANEL_READY
    global GDHO_STAR_GUI, GDHO_VISIBLE, GDHO_MANUAL_PANEL_MODE, GDHO_ACTIVE, GDHO_DESKTOP_PINNED
    global NativeDropSessionActive, GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y
    if !IsObject(GDHO_PANEL_GUI)
        return
    if !(FuncExists("GDHO_ShouldShowDecoupledPanel") && GDHO_ShouldShowDecoupledPanel(reason))
        return
    ; Ensure panel WebView is ready before showing (prevents blank/black window).
    if !GDHO_PANEL_READY {
        GDHO_ShowPanelWhenReady("show_panel:" . String(reason))
        return
    }
    GDHO_ActivatePanelHost("show_panel")
    if !(GDHO_P0_IsReadonly()) && !(FuncExists("GDHO_IsPanelDragProtected") && GDHO_IsPanelDragProtected())
        GDHO_SyncPanelPositionToStarry()
    try GDHO_PANEL_GUI.Show("NA x" Integer(GDHO_PANEL_LAST_X) " y" Integer(GDHO_PANEL_LAST_Y)
        . " w" Integer(GDHO_PANEL_W) " h" Integer(GDHO_PANEL_H))
    GDHO_PANEL_VISIBLE := true
    if !(GDHO_IsStarryLauncherMode() && GDHO_UseLauncherLayer())
        GDHO_HideStarryAfterPanel("show_panel")
    GDHO_RaisePanelAboveStarry()
    try GDHO_ApplyPanelVisibleChrome()
    try GDHO_Trace("show_panel reason=" . String(reason))
    GDHO_TraceTopology("show_panel")
}

GDHO_HidePanel(reason := "") {
    if GDHO_P0_BlockHostMoveHide("hide_panel:" . String(reason))
        return
    global GDHO_PANEL_GUI, GDHO_PANEL_VISIBLE, GDHO_PANEL_PINNED
    global g_GDHO_PanelHoldUntil, g_GDHO_PostSuckPanelPending, g_GDHO_TextHoleStickyPanel
    r0 := StrLower(Trim(String(reason)))
    if FuncExists("GDHO_IsPanelDragProtected") {
        try {
            if GDHO_IsPanelDragProtected() && !GDHO_IsExplicitTextHolePanelCloseReason(r0) {
                try GDHO_Trace("hide_panel_skip reason=" . String(reason) . " policy=panel_drag")
                return
            }
        } catch {
        }
    }
    if !GDHO_MayAutoHideTextHolePanel(r0) {
        try GDHO_Trace("hide_panel_skip reason=" . String(reason) . " policy=panel_locked")
        try NativeDropDiag_Log("[TextHole] hide_panel_skip reason=" . r0 . " policy=panel_locked")
        return
    }
    if GDHO_IsExplicitTextHolePanelCloseReason(r0) {
        GDHO_UnlockTextHoleUserPanel()
        global g_GDHO_TextHolePanelOpen
        g_GDHO_TextHolePanelOpen := false
        g_GDHO_TextHoleStickyPanel := false
        g_GDHO_PanelHoldUntil := 0
        g_GDHO_PostSuckPanelPending := false
    } else if (r0 = "selection_copy_timeout" || r0 = "hide_overlay" || r0 = "starry_hole_close") {
        try GDHO_Trace("hide_panel_skip reason=" . String(reason) . " policy=text_panel_persist")
        return
    }
    if GDHO_PANEL_PINNED
        return
    if !IsObject(GDHO_PANEL_GUI)
        return
    try GDHO_PANEL_GUI.Hide()
    GDHO_PANEL_VISIBLE := false
    r := StrLower(Trim(String(reason)))
    if !(InStr(r, "handoff") || InStr(r, "text_drag") || InStr(r, "post_suck") || InStr(r, "native_drop") || InStr(r, "drag"))
        GDHO_ClearTextDragHandoff()
    try GDHO_Trace("hide_panel reason=" . String(reason))
}

GDHO_ParkPanel() {
    if GDHO_P0_BlockHostMoveHide("park_panel")
        return
    global GDHO_PANEL_GUI, GDHO_PARK_X, GDHO_PARK_Y, GDHO_PANEL_W, GDHO_PANEL_H, GDHO_PANEL_VISIBLE
    if FuncExists("GDHO_IsPanelDragProtected") {
        try {
            if GDHO_IsPanelDragProtected() {
                try GDHO_Trace("park_panel_skip policy=panel_drag")
                return
            }
        } catch {
        }
    }
    if FuncExists("GDHO_IsTextHoleUserPanelActive") {
        try {
            if GDHO_IsTextHoleUserPanelActive() {
                try GDHO_Trace("park_panel_skip policy=panel_engaged")
                return
            }
        } catch {
        }
    }
    if !IsObject(GDHO_PANEL_GUI)
        return
    GDHO_PANEL_VISIBLE := false
    try GDHO_PANEL_GUI.Move(Integer(GDHO_PARK_X), Integer(GDHO_PARK_Y), Integer(GDHO_PANEL_W), Integer(GDHO_PANEL_H))
    try GDHO_PANEL_GUI.Hide()
}

GDHO_InitDecoupled() {
    global GDHO_STAR_GUI, GDHO_PANEL_GUI, GDHO_WV2_CTRL_STAR, GDHO_WV2_STAR, GDHO_WV2_CTRL_PANEL, GDHO_WV2_PANEL
    global GDHO_READY, GDHO_STAR_READY, GDHO_PANEL_READY, GDHO_VISIBLE, GDHO_SLEEPING, GDHO_INTERACTIVE
    global GDHO_LAST_PROXIMITY_SENT, g_GDHO_CreateInFlight, g_GDHO_CreateStartTick, g_GDHO_CreateToken
    global g_GDHO_StarryCreateInFlight, g_GDHO_PanelCreateInFlight, GDHO_PREWARM_DONE, GDHO_FIRST_REVEAL_DONE
    global GDHO_WV2_CTRL, GDHO_WV2, GDHO_GUI

    if (GDHO_STAR_GUI || g_GDHO_StarryCreateInFlight)
        return
    GDHO_TraceTopology("init_decoupled_begin")
    GDHO_CreateStarryGui()
    GDHO_WV2_CTRL_STAR := 0
    GDHO_WV2_STAR := 0
    GDHO_WV2_CTRL_PANEL := 0
    GDHO_WV2_PANEL := 0
    GDHO_WV2_CTRL := 0
    GDHO_WV2 := 0
    GDHO_READY := false
    GDHO_STAR_READY := false
    GDHO_PANEL_READY := false
    GDHO_PREWARM_DONE := false
    GDHO_FIRST_REVEAL_DONE := false
    GDHO_VISIBLE := false
    GDHO_SLEEPING := true
    GDHO_INTERACTIVE := false
    GDHO_LAST_PROXIMITY_SENT := -1.0
    g_GDHO_CreateInFlight := true
    g_GDHO_StarryCreateInFlight := true
    g_GDHO_CreateStartTick := A_TickCount
    g_GDHO_CreateToken := g_GDHO_CurrentToken
    try WebView2_CreateWithSharedEnvAsync(GDHO_STAR_GUI.Hwnd, GDHO_OnStarryWebViewCreated, "gdho_starry")
}

GDHO_HardRecycleDecoupled(reason := "") {
    GDHO_ClearTextDragHandoff()
    global GDHO_STAR_GUI, GDHO_PANEL_GUI, GDHO_LAUNCHER_GUI, GDHO_WV2_CTRL_STAR, GDHO_WV2_CTRL_PANEL, GDHO_WV2_CTRL_LAUNCHER
    global GDHO_WV2_STAR, GDHO_WV2_PANEL, GDHO_WV2_LAUNCHER, GDHO_WV2_CTRL, GDHO_WV2, GDHO_GUI, GDHO_READY, GDHO_STAR_READY
    global GDHO_PANEL_READY, GDHO_LAUNCHER_READY, GDHO_VISIBLE, GDHO_PANEL_VISIBLE, GDHO_LAUNCHER_VISIBLE, GDHO_DIAG_CTRL
    global g_GDHO_CreateInFlight, g_GDHO_CreateStartTick, g_GDHO_StarryCreateInFlight, g_GDHO_PanelCreateInFlight
    global g_GDHO_LauncherCreateInFlight, g_GDHO_PendingLauncherShow
    if IsObject(GDHO_WV2_CTRL_STAR) {
        try GDHO_WV2_CTRL_STAR.Close()
        catch {
        }
    }
    if IsObject(GDHO_WV2_CTRL_PANEL) {
        try GDHO_WV2_CTRL_PANEL.Close()
        catch {
        }
    }
    if IsObject(GDHO_WV2_CTRL_LAUNCHER) {
        try GDHO_WV2_CTRL_LAUNCHER.Close()
        catch {
        }
    }
    GDHO_WV2_CTRL_STAR := 0
    GDHO_WV2_CTRL_PANEL := 0
    GDHO_WV2_CTRL_LAUNCHER := 0
    GDHO_WV2_STAR := 0
    GDHO_WV2_PANEL := 0
    GDHO_WV2_LAUNCHER := 0
    GDHO_WV2_CTRL := 0
    GDHO_WV2 := 0
    GDHO_READY := false
    GDHO_STAR_READY := false
    GDHO_PANEL_READY := false
    GDHO_LAUNCHER_READY := false
    if IsObject(GDHO_STAR_GUI) {
        try GDHO_STAR_GUI.Destroy()
        catch {
        }
    }
    if IsObject(GDHO_PANEL_GUI) {
        try GDHO_PANEL_GUI.Destroy()
        catch {
        }
    }
    if IsObject(GDHO_LAUNCHER_GUI) {
        try GDHO_LAUNCHER_GUI.Destroy()
        catch {
        }
    }
    GDHO_STAR_GUI := 0
    GDHO_PANEL_GUI := 0
    GDHO_LAUNCHER_GUI := 0
    GDHO_GUI := 0
    GDHO_DIAG_CTRL := 0
    GDHO_VISIBLE := false
    GDHO_PANEL_VISIBLE := false
    GDHO_LAUNCHER_VISIBLE := false
    g_GDHO_PendingLauncherShow := false
    ; Critical: clear async creation guards so next GDHO_InitDecoupled can recreate hosts.
    g_GDHO_CreateInFlight := false
    g_GDHO_CreateStartTick := 0
    g_GDHO_StarryCreateInFlight := false
    g_GDHO_PanelCreateInFlight := false
    g_GDHO_LauncherCreateInFlight := false
    g_GDHO_PanelCreateStartedTick := 0
    GDHO_TraceTopology("hard_recycle " . String(reason))
}

GDHO_HideStarryKeepPanel(reason := "") {
    if FuncExists("GDHO_HideStarryAfterPanel")
        GDHO_HideStarryAfterPanel(reason)
}

GDHO_LoadPanelPositionFromIni() {
    global ConfigFile, GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y, GDHO_PANEL_W, GDHO_PANEL_H, GDHO_PANEL_PINNED
    if !IsSet(ConfigFile) || ConfigFile = "" || !FileExist(ConfigFile)
        return
    try GDHO_PANEL_LAST_X := Integer(IniRead(ConfigFile, "Appearance", "HolePanelX", GDHO_PANEL_LAST_X))
    try GDHO_PANEL_LAST_Y := Integer(IniRead(ConfigFile, "Appearance", "HolePanelY", GDHO_PANEL_LAST_Y))
    try GDHO_PANEL_W := Integer(IniRead(ConfigFile, "Appearance", "HolePanelW", GDHO_PANEL_W))
    try GDHO_PANEL_H := Integer(IniRead(ConfigFile, "Appearance", "HolePanelH", GDHO_PANEL_H))
    try GDHO_PANEL_PINNED := (IniRead(ConfigFile, "Appearance", "HolePanelPinned", "0") = "1")
}

GDHO_SavePanelPositionToIni() {
    global ConfigFile, GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y, GDHO_PANEL_W, GDHO_PANEL_H, GDHO_PANEL_PINNED
    if !IsSet(ConfigFile) || ConfigFile = ""
        return
    try IniWrite(String(GDHO_PANEL_LAST_X), ConfigFile, "Appearance", "HolePanelX")
    try IniWrite(String(GDHO_PANEL_LAST_Y), ConfigFile, "Appearance", "HolePanelY")
    try IniWrite(String(GDHO_PANEL_W), ConfigFile, "Appearance", "HolePanelW")
    try IniWrite(String(GDHO_PANEL_H), ConfigFile, "Appearance", "HolePanelH")
    try IniWrite(GDHO_PANEL_PINNED ? "1" : "0", ConfigFile, "Appearance", "HolePanelPinned")
}
