#Requires AutoHotkey v2.0

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
global GDHO_PANEL_W := 480
global GDHO_PANEL_H := 520
global GDHO_PANEL_LAST_X := 24
global GDHO_PANEL_LAST_Y := 24
global GDHO_WM_ACTIVATE := 0x6
global g_GDHO_PanelCreateInFlight := false
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
global g_GDHO_PendingPanelShow := false
global g_GDHO_PendingPanelShowReason := ""
global g_GDHO_PendingPanelShowSince := 0
global g_GDHO_PanelUserDragging := false
global g_GDHO_PanelDragGraceUntil := 0
global g_GDHO_PanelDragBaseW := 0
global g_GDHO_PanelDragBaseH := 0
global g_GDHO_TextHolePanelLocked := false
global g_GDHO_UserTextHolePanelEngaged := false
global g_GDHO_TextHolePresentRetryArmed := false
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

GDHO_CanCommitTextHole() {
    global g_GDHO_TextHoleAwaitingExpand
    if g_GDHO_TextHoleAwaitingExpand || GDHO_IsTextHoleUserPanelActive()
        return false
    return (GDHO_GetInteractionPhase() = GDHO_PHASE_WEAK_PREVIEW)
}

GDHO_ShouldDeferSelectionAutoHide() {
    global g_GDHO_SuppressSelectionAutoHide
    ph := GDHO_GetInteractionPhase()
    if (ph = GDHO_PHASE_COMMITTING || ph = GDHO_PHASE_PANEL_OPEN || ph = GDHO_PHASE_CLOSING)
        return true
    if g_GDHO_SuppressSelectionAutoHide
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
    global GDHO_WV2_PANEL, GDHO_PANEL_READY, g_GDHO_PanelCreateInFlight, GDHO_PANEL_GUI, GDHO_WV2_CTRL_PANEL
    if !GDHO_IsDecoupled()
        return GDHO_PANEL_READY
    if !IsObject(GDHO_PANEL_GUI)
        try GDHO_CreatePanelGui()
    if IsObject(GDHO_WV2_PANEL)
        return GDHO_PANEL_READY
    if !IsObject(GDHO_WV2_CTRL_PANEL) && !g_GDHO_PanelCreateInFlight && IsObject(GDHO_PANEL_GUI) {
        g_GDHO_PanelCreateInFlight := true
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
    global g_GDHO_PanelUserDragging, g_GDHO_PanelDragGraceUntil
    if g_GDHO_PanelUserDragging
        return true
    return (g_GDHO_PanelDragGraceUntil > A_TickCount)
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
}

GDHO_DismissTextHolePanel(reason := "panel_dismiss") {
    global g_GDHO_TextHolePanelOpen, GDHO_PANEL_VISIBLE, g_GDHO_TextHoleStickyPanel
    if !g_GDHO_TextHolePanelOpen && !GDHO_PANEL_VISIBLE
        return
    GDHO_SetInteractionPhase(GDHO_PHASE_CLOSING, String(reason))
    GDHO_UnlockTextHoleUserPanel()
    try GDHO_DisarmTextHoleProximityPoll()
    g_GDHO_TextHolePanelOpen := false
    g_GDHO_TextHoleStickyPanel := false
    g_GDHO_SuppressSelectionAutoHide := false
    try GDHO_HideStarryAfterPanel("dismiss_" . reason)
    try GDHO_HidePanel("panel_hole_close")
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
    try GDHO_RunStarryJS("window.HoleOverlay?.hideSilent?.()")
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
    GDHO_HidePanel("selection_preview_guard")
}

GDHO_SelectionPreviewPanelGuardLate(*) {
    if GDHO_ShouldKeepTextHolePanel()
        return
    GDHO_HidePanel("selection_preview_guard_late")
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

GDHO_SetStarryClickThrough(enable := true, reason := "") {
    global GDHO_STAR_GUI, GDHO_CLICKTHROUGH
    gui := GDHO_GetStarryGui()
    if !IsObject(gui) || !gui.Hwnd
        return
    if GDHO_IsDecoupled()
        enable := true
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
    global GDHO_PARK_X, GDHO_PARK_Y, GDHO_WM_ACTIVATE
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
    global GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y, GDHO_PANEL_GUI, GDHO_PANEL_PINNED
    if FuncExists("GDHO_IsPanelDragProtected") && GDHO_IsPanelDragProtected()
        return
    if !IsObject(GDHO_PANEL_GUI)
        return
    if GDHO_PANEL_PINNED
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

GDHO_EnsurePanelShowPosition(mx := "", my := "") {
    global GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y, GDHO_PANEL_GUI, GDHO_PANEL_PINNED
    if !IsObject(GDHO_PANEL_GUI) || GDHO_PANEL_PINNED
        return
    px := Integer(GDHO_PANEL_LAST_X), py := Integer(GDHO_PANEL_LAST_Y)
    offScreen := (px < -2800 || py < -2800 || (px = 0 && py = 0))
    if !offScreen && GDHO_IsStarryHostOnScreen() {
        GDHO_SyncPanelPositionToStarry()
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
    global GDHO_PANEL_GUI, GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y, GDHO_PANEL_W, GDHO_PANEL_H, GDHO_PANEL_PINNED
    global g_GDHO_PanelDragBaseW, g_GDHO_PanelDragBaseH
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
    try GDHO_PANEL_GUI.Move(x, y, pw, ph)
}

GDHO_ApplyPanelHostScreenRect(sx, sy, sw := "", sh := "") {
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
    global g_GDHO_PendingPanelText, GDHO_PANEL_READY
    t := Trim(String(g_GDHO_PendingPanelText))
    if (t = "" || !GDHO_PANEL_READY || !FuncExists("GDHO_RunPanelJS"))
        return
    try {
        jsBody := GDHO_QuoteJsString(t)
        GDHO_RunPanelJS("try{window.HolePanel?.setCapturedText?.(" . jsBody . ");window.HolePanel?.setManualPanelVisible?.(true);}catch(_e){}")
        g_GDHO_PendingPanelText := ""
    } catch {
    }
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
    if !IsObject(GDHO_PANEL_GUI) {
        try GDHO_CreatePanelGui()
        catch {
        }
    }
    try GDHO_EnsureDecoupledPanelWebHost()
    GDHO_EnsurePanelShowPosition(mx, my)
    GDHO_ShowPanelWhenReady(reason)
    if !GDHO_PANEL_VISIBLE {
        try NativeDropDiag_Log("[PostSuck] present_retry reason=panel_not_visible source=" . String(reason))
        try GDHO_SyncPanelPositionNearCursor(mx, my)
        try GDHO_ShowPanelForced("present_retry_immediate")
    }
    if !GDHO_PANEL_VISIBLE {
        if GDHO_IsTextHoleUserPanelActive()
            GDHO_UnlockTextHoleUserPanel()
        global g_GDHO_TextHolePresentRetryArmed
        if !g_GDHO_TextHolePresentRetryArmed {
            g_GDHO_TextHolePresentRetryArmed := true
            try SetTimer(GDHO_TextHolePresentRetry, -450)
        }
        return false
    }
    g_GDHO_PostSuckPresentDone := true
    g_GDHO_TextHolePresentedSessionId := sid
    GDHO_LockTextHoleUserPanel()
    GDHO_SetInteractionPhase(GDHO_PHASE_PANEL_OPEN, "present:" . String(reason))
    GDHO_CancelTextHolePresentTimers()
    global g_GDHO_PendingPanelText, GDHO_PANEL_READY
    if (t != "") {
        if (GDHO_PANEL_READY && FuncExists("GDHO_RunPanelJS")) {
            try {
                jsBody := GDHO_QuoteJsString(t)
                GDHO_RunPanelJS("try{window.HolePanel?.setCapturedText?.(" . jsBody . ");window.HolePanel?.setManualPanelVisible?.(true);window.HolePanel?.focusPrompt?.(false);}catch(_e){}")
            } catch {
                g_GDHO_PendingPanelText := t
            }
        } else {
            g_GDHO_PendingPanelText := t
        }
    } else {
        g_GDHO_PendingPanelText := ""
    }
    try NativeDropDiag_Log("[PostSuck] present_done sid=" . sid . " len=" . StrLen(t) . " reason=" . String(reason) . " panel_ready=" . (GDHO_PANEL_READY ? "1" : "0"))
    GDHO_TextHoleTransition(GDHO_TEXT_HOLE_STATE_PANEL_SHOWN, String(reason), "", StrLen(t))
    GDHO_ArmPanelHold()
    try GDHO_Trace("present_post_suck_panel len=" . StrLen(t) . " reason=" . String(reason))
    GDHO_TraceTopology("present_post_suck_panel")
    return true
}

GDHO_PendingPanelShowPump(*) {
    global g_GDHO_PendingPanelShow, g_GDHO_PendingPanelShowReason, g_GDHO_PendingPanelShowSince, GDHO_PANEL_READY
    if !g_GDHO_PendingPanelShow
        return
    if GDHO_PANEL_READY {
        r := g_GDHO_PendingPanelShowReason
        g_GDHO_PendingPanelShow := false
        GDHO_ShowPanelForced(r)
        return
    }
    if (g_GDHO_PendingPanelShowSince > 0 && (A_TickCount - g_GDHO_PendingPanelShowSince) < 9000)
        SetTimer(GDHO_PendingPanelShowPump, -160)
    else
        try NativeDropDiag_Log("[PostSuck] pending_panel_show_timeout reason=" . g_GDHO_PendingPanelShowReason)
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

GDHO_ApplyPanelVisibleChrome() {
    if !GDHO_PANEL_READY
        return
    try GDHO_RunPanelJS("try{document.documentElement.style.background='rgba(5,10,16,0.96)';document.body.style.background='rgba(5,10,16,0.96)';window.HolePanel?.setManualPanelVisible?.(true);window.HolePanel?.onHostShow?.();}catch(_e){}")
}

GDHO_ShowPanelForced(reason := "") {
    global GDHO_PANEL_GUI, GDHO_PANEL_VISIBLE, GDHO_PANEL_W, GDHO_PANEL_H
    global GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y, GDHO_PANEL_READY, GDHO_CURSOR_X, GDHO_CURSOR_Y
    global g_GDHO_PendingPanelShow
    if !IsObject(GDHO_PANEL_GUI) {
        try GDHO_CreatePanelGui()
    }
    try GDHO_EnsureDecoupledPanelWebHost()
    if !IsObject(GDHO_PANEL_GUI) {
        try NativeDropDiag_Log("[PostSuck] show_panel_forced_fail reason=no_panel_gui source=" . String(reason))
        GDHO_PANEL_VISIBLE := false
        return
    }
    if (Integer(GDHO_PANEL_LAST_X) < -2800 || Integer(GDHO_PANEL_LAST_Y) < -2800)
        GDHO_EnsurePanelShowPosition(GDHO_CURSOR_X, GDHO_CURSOR_Y)
    try SetTimer(GDHO_PanelDeactivateCheck, 0)
    GDHO_SetPanelInteractive("show_panel_forced")
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
    if GDHO_PANEL_READY {
        GDHO_ApplyPanelVisibleChrome()
        if FuncExists("GDHO_FlushPendingPanelText")
            GDHO_FlushPendingPanelText()
    } else {
        try NativeDropDiag_Log("[PostSuck] show_panel_host_only reason=" . String(reason))
        if !g_GDHO_PendingPanelShow
            GDHO_ShowPanelWhenReady(reason)
    }
    GDHO_HideStarryAfterPanel("show_panel_forced")
    try GDHO_Trace("show_panel_forced reason=" . String(reason) . " ready=" . (GDHO_PANEL_READY ? "1" : "0"))
}

GDHO_TextHolePresentRetry(*) {
    global g_GDHO_TextHolePresentRetryArmed, g_GDHO_PostSuckPanelPending, GDHO_SESSION_TEXT, GDHO_CURSOR_X, GDHO_CURSOR_Y
    global g_GDHO_TextHoleSessionSerial, GDHO_PANEL_VISIBLE
    g_GDHO_TextHolePresentRetryArmed := false
    if !GDHO_IsDecoupled() || GDHO_PANEL_VISIBLE
        return
    if !g_GDHO_PostSuckPanelPending
        return
    t := Trim(String(GDHO_SESSION_TEXT))
    if (t = "") && FuncExists("GDHO_GetTextHoleCapturedText")
        try t := Trim(String(GDHO_GetTextHoleCapturedText()))
    if (t = "")
        return
    try GDHO_ShowPanelForced("present_retry_delayed")
    if GDHO_PANEL_VISIBLE {
        global g_GDHO_PostSuckPresentDone
        if !g_GDHO_PostSuckPresentDone
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
    if (g_GDHO_PostSuckPresentDone && GDHO_PANEL_VISIBLE)
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
    GDHO_DisarmTextHoleProximityPoll()
    GDHO_ArmTextHoleCommitWatch()
    GDHO_ClearTextDragHandoff(false)
    GDHO_SESSION_TEXT := t
    GDHO_PAYLOAD := "text"
    GDHO_CURSOR_X := mx
    GDHO_CURSOR_Y := my
    g_GDHO_TextHoleFallbackSessionId := g_GDHO_TextHoleSessionSerial
    GDHO_SetInteractionPhase(GDHO_PHASE_COMMITTING, "commit_begin:" . String(reason))
    GDHO_TextHoleTransition(GDHO_TEXT_HOLE_STATE_COMMITTED, String(reason), "", StrLen(t))
    try SetTimer(SelectionSense_HideHoleAfterSelection, 0)
    try GDHO_SetStarryClickThrough(false, "text_hole_commit")
    GDHO_CancelTextHolePresentTimers()
    expMs := Integer(GDHO_TEXT_HOLE_EXPAND_MS)
    if (expMs < 900)
        expMs := 1250
    fbMs := expMs + 280
    ; Single present fallback if hole_expand_complete is lost (was 3+ parallel timers).
    SetTimer(GDHO_TextHoleExpandFallback, -fbMs)
    GDHO_TextHoleTransition(GDHO_TEXT_HOLE_STATE_EXPANDING, "dispatch_drop", "", StrLen(t))
    GDHO_EnsurePanelWebWarm()
    GDHO_TraceInteraction("commit", String(reason))
    try GDHO_RunStarryJS("window.HoleOverlay?.drop?.({payload:'text',force:true});")
    try NativeDropDiag_Log("[PostSuck] commit sid=" . g_GDHO_TextHoleSessionSerial . " reason=" . String(reason) . " len=" . StrLen(t) . " expand_ms=" . expMs)
    return true
}

GDHO_TextHoleFastPresentTimer(*) {
    global g_GDHO_TextHoleFastPresentSid, g_GDHO_TextHoleFastPresentText, g_GDHO_TextHoleFastPresentX, g_GDHO_TextHoleFastPresentY
    sid := Integer(g_GDHO_TextHoleFastPresentSid)
    t := Trim(String(g_GDHO_TextHoleFastPresentText))
    if (sid <= 0 || t = "")
        return
    try GDHO_PresentPanelAfterTextHoleDrop(t, g_GDHO_TextHoleFastPresentX, g_GDHO_TextHoleFastPresentY, "commit_fast", sid)
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
    global GDHO_STAR_GUI, GDHO_PANEL_GUI
    if !(IsObject(GDHO_STAR_GUI) && IsObject(GDHO_PANEL_GUI))
        return
    try {
        DllCall("SetWindowPos", "Ptr", GDHO_PANEL_GUI.Hwnd, "Ptr", GDHO_STAR_GUI.Hwnd, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
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
    if !g_GDHO_PanelCreateInFlight && !IsObject(GDHO_WV2_CTRL_PANEL) {
        g_GDHO_PanelCreateInFlight := true
        try WebView2_CreateWithSharedEnvAsync(GDHO_PANEL_GUI.Hwnd, GDHO_OnPanelWebViewCreated, "gdho_panel")
    }
}

GDHO_OnPanelWebViewCreated(ctrl) {
    global GDHO_WV2_CTRL_PANEL, GDHO_WV2_PANEL, GDHO_PANEL_READY, GDHO_PANEL_PAGE_URL
    global g_GDHO_PanelCreateInFlight, g_GDHO_CreateToken, GDHO_PANEL_GUI
    g_GDHO_PanelCreateInFlight := false
    if !GDHO_IsCurrentToken(g_GDHO_CreateToken) {
        try ctrl.Close()
        catch {
        }
        return
    }
    if !IsObject(GDHO_PANEL_GUI) {
        try ctrl.Close()
        catch {
        }
        return
    }
    if !IsObject(ctrl) || !ctrl.HasProp("CoreWebView2") {
        try GDHO_Trace("panel_webview_create_failed")
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
        GDHO_SetStarryClickThrough(true, "starry_nav_completed")
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
        global g_GDHO_TextHolePanelLocked, g_GDHO_PendingPanelText
        forceKeepPanel := !!(g_GDHO_PostSuckPanelPending || g_GDHO_PendingPanelShow || g_GDHO_TextHolePanelOpen
            || g_GDHO_TextHoleStickyPanel || g_GDHO_TextHolePanelLocked || GDHO_PANEL_VISIBLE
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
            try GDHO_HidePanel("panel_nav_suppressed")
            try GDHO_RunPanelJS("window.HolePanel?.setManualPanelVisible?.(false)")
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
    if (typ = "hole_close") {
        rs := msg.Has("reason") ? StrLower(Trim(String(msg["reason"]))) : ""
        if (rs != "panel_close_btn" && rs != "panel_escape") {
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
        try GDHO_LockTextHoleUserPanel()
        global g_GDHO_PanelUserDragging, g_GDHO_PanelDragBaseW, g_GDHO_PanelDragBaseH
        g_GDHO_PanelUserDragging := true
        g_GDHO_PanelDragBaseW := Integer(GDHO_PANEL_W)
        g_GDHO_PanelDragBaseH := Integer(GDHO_PANEL_H)
        if IsObject(GDHO_PANEL_GUI) {
            try GDHO_PANEL_GUI.GetPos(, , &gw, &gh)
            if (Integer(gw) >= 320)
                g_GDHO_PanelDragBaseW := Integer(gw)
            if (Integer(gh) >= 280)
                g_GDHO_PanelDragBaseH := Integer(gh)
        }
        try GDHO_DisarmTextHoleProximityPoll()
        try GDHO_DisarmTextHoleCommitWatch()
        try GDHO_CancelTextHolePresentTimers()
        try GDHO_HideStarryAfterPanel("panel_drag")
        try GDHO_SetProximity(0.0)
        try NativeDropDiag_Log("[TextHole] panel_drag_start suppress_starry=1")
        try GDHO_ArmPanelDragGrace(2500)
        try SetTimer(GDHO_ClearPanelUserDragging, 0)
        try GDHO_RunPanelJS("try{document.getElementById('panelRoot')&&(document.getElementById('panelRoot').style.pointerEvents='auto');}catch(_e){}")
        return
    }
    if (typ = "panel_drag_end") {
        global g_GDHO_PanelUserDragging, g_GDHO_PanelDragBaseW, g_GDHO_PanelDragBaseH
        g_GDHO_PanelUserDragging := true
        g_GDHO_PanelDragBaseW := 0
        g_GDHO_PanelDragBaseH := 0
        try GDHO_ArmPanelDragGrace(1200)
        try GDHO_LockTextHoleUserPanel()
        try SetTimer(GDHO_ClearPanelUserDragging, -900)
        try GDHO_RunPanelJS("try{var r=document.getElementById('panelRoot');if(r)r.style.pointerEvents='none';window.HolePanel?.resetPanelLayout?.();}catch(_e){}")
        return
    }
    if (typ = "panel_moved") {
        global g_GDHO_PanelUserDragging
        g_GDHO_PanelUserDragging := true
        try GDHO_ArmPanelDragGrace(2500)
        if msg.Has("screenX") && msg.Has("screenY") {
            try GDHO_MovePanelHostScreen(msg["screenX"], msg["screenY"])
        }
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
    global GDHO_STAR_GUI, GDHO_VISIBLE, GDHO_MANUAL_PANEL_MODE, GDHO_ACTIVE, GDHO_DESKTOP_PINNED
    global NativeDropSessionActive, GDHO_PANEL_LAST_X, GDHO_PANEL_LAST_Y
    if !IsObject(GDHO_PANEL_GUI)
        return
    if !(FuncExists("GDHO_ShouldShowDecoupledPanel") && GDHO_ShouldShowDecoupledPanel(reason))
        return
    GDHO_SetPanelInteractive("show_panel")
    GDHO_SyncPanelPositionToStarry()
    try GDHO_PANEL_GUI.Show("NA x" Integer(GDHO_PANEL_LAST_X) " y" Integer(GDHO_PANEL_LAST_Y)
        . " w" Integer(GDHO_PANEL_W) " h" Integer(GDHO_PANEL_H))
    GDHO_PANEL_VISIBLE := true
    GDHO_HideStarryAfterPanel("show_panel")
    GDHO_RaisePanelAboveStarry()
    try GDHO_RunPanelJS("window.HolePanel?.onHostShow?.()")
    try GDHO_Trace("show_panel reason=" . String(reason))
    GDHO_TraceTopology("show_panel")
}

GDHO_HidePanel(reason := "") {
    global GDHO_PANEL_GUI, GDHO_PANEL_VISIBLE, GDHO_PANEL_PINNED
    global g_GDHO_PanelHoldUntil, g_GDHO_PostSuckPanelPending, g_GDHO_TextHoleStickyPanel
    r0 := StrLower(Trim(String(reason)))
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
    global GDHO_PANEL_GUI, GDHO_PARK_X, GDHO_PARK_Y, GDHO_PANEL_W, GDHO_PANEL_H, GDHO_PANEL_VISIBLE
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

    if (GDHO_STAR_GUI || g_GDHO_StarryCreateInFlight) {
        try GDHO_EnsureDecoupledPanelWebHost()
        return
    }
    GDHO_TraceTopology("init_decoupled_begin")
    GDHO_CreateStarryGui()
    GDHO_CreatePanelGui()
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
    global GDHO_STAR_GUI, GDHO_PANEL_GUI, GDHO_WV2_CTRL_STAR, GDHO_WV2_CTRL_PANEL
    global GDHO_WV2_STAR, GDHO_WV2_PANEL, GDHO_WV2_CTRL, GDHO_WV2, GDHO_GUI, GDHO_READY, GDHO_STAR_READY
    global GDHO_PANEL_READY, GDHO_VISIBLE, GDHO_PANEL_VISIBLE, GDHO_DIAG_CTRL
    global g_GDHO_CreateInFlight, g_GDHO_CreateStartTick, g_GDHO_StarryCreateInFlight, g_GDHO_PanelCreateInFlight
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
    GDHO_WV2_CTRL_STAR := 0
    GDHO_WV2_CTRL_PANEL := 0
    GDHO_WV2_STAR := 0
    GDHO_WV2_PANEL := 0
    GDHO_WV2_CTRL := 0
    GDHO_WV2 := 0
    GDHO_READY := false
    GDHO_STAR_READY := false
    GDHO_PANEL_READY := false
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
    GDHO_STAR_GUI := 0
    GDHO_PANEL_GUI := 0
    GDHO_GUI := 0
    GDHO_DIAG_CTRL := 0
    GDHO_VISIBLE := false
    GDHO_PANEL_VISIBLE := false
    ; Critical: clear async creation guards so next GDHO_InitDecoupled can recreate hosts.
    g_GDHO_CreateInFlight := false
    g_GDHO_CreateStartTick := 0
    g_GDHO_StarryCreateInFlight := false
    g_GDHO_PanelCreateInFlight := false
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
