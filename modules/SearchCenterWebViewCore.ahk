#Requires AutoHotkey v2.0

global g_SCWV_Gui := 0
global g_SCWV_Ctrl := 0
global g_SCWV_WV2 := 0
global g_SCWV_Ready := false
global g_SCWV_UI_Ready := false
global g_SCWV_WaitingUiFinishedReveal := false
global g_SCWV_DeferredHostShow := false
global g_SCWV_WV2_CreateRetry := 0
global g_SCWV_CreateInFlight := false
global g_SCWV_CreateStartTick := 0
global g_SCWV_Visible := false
global g_SCWV_LastShown := 0  ; SCWV_Show 鍚庡闄愭湡锛岄伩鍏嶇偣鍑绘偓娴潯澶辩劍绔嬪埢 Hide 涓庝簩娆＄偣鍑绘姠璺?
global g_SCWV_ShowWaitStartTick := 0
global g_SCWV_ShowRecoveryAttempts := 0
global g_SCWV_SearchTimer := 0
global g_SCWV_FocusPending := false
global g_SCWV_CliTerminalFocus := false
global g_SCWV_SearchInputFocused := false
global g_SCWV_LoadingTier := "shell"
global g_SCWV_HomeRefreshScheduled := false
global g_SCWV_HomeViewEpoch := 0
global SearchCenterWebKeyword := ""
global SearchCenterSearchResults := []
global g_SCWV_AllResultsCache := []
global g_SCWV_AllResultsKeyword := ""
global SearchCenterHasMoreData := false
global SearchCenterFilterType := ""
global SearchCenterCurrentLimit := 30
global SearchCenterEngineMode := "go"  ; go=SearchCenterCore HTTP；ahk=SearchAllDataSources（与旧版 ListView 一致）
global g_SCWV_SkipHostSort := false     ; Go 已混排时跳过 AHK SortSearchCenterMergedResults
global g_SCWV_PendingJsonQueue := []  ; WebView 鏈?ready 鏃舵殏瀛橈紝ready 鍚庣敱 SCWV_FlushPendingJsonQueue 鍙戝嚭
global g_SCWV_RowCtxMenu := 0  ; 鍏煎鍗犱綅锛堟繁鑹茶彍鍗曚笉鍐嶄娇鐢ㄥ師鐢?Menu锛?
global g_SCWV_MenuActionRow := 0  ; 褰撳墠鑿滃崟瀵瑰簲鐨勫彲瑙佺粨鏋滆鍙凤紙1-based锛?
global g_SCWV_MenuActionUid := ""
global g_SCWV_DarkCtxGui := 0  ; 鎼滅储缁撴灉琛屾繁鑹插彸閿彍鍗?GUI
global g_SCWV_DarkCtxHoverIdx := 0
global g_SCWV_DarkCtxCmdByIdx := Map()  ; 1-based琛屽彿 -> cmdId
global g_SCWV_DarkCtxSubSpecByIdx := Map()  ; 涓昏彍鍗曡鍙?-> 瀛愯彍鍗?children 鏁扮粍
global g_SCWV_DarkSubGui := 0
global g_SCWV_DarkSubCmdByIdx := Map()
global g_SCWV_DarkSubHoverIdx := 0
global g_SCWV_DarkSubMenuHoverTimer := 0
global g_SCWV_DarkMenuHoverTimer := 0  ; 鎮仠涓よ娓愬彉
global g_SCWV_DarkCtxItemCount := 0  ; 涓诲彸閿彍鍗曡鏁帮紙閬垮厤鐢?Gui.HasProp 妫€娴嬫帶浠讹紝閮ㄥ垎鐗堟湰浼氭姏閿欏鑷存案涓嶉珮浜級
global g_SCWV_DarkSubItemCount := 0
global g_SCWV_PinnedKeys := Map()  ; 缃《閿?id:xxx 鎴?c:鍐呭鍝堝笇
global g_SCWV_RecycleBin := []  ; 鍒犻櫎椤瑰揩鐓?{title,content,id}
global g_SCWV_PreviewCapabilityCache := Map() ; extDot -> {state, ts, ...}
global g_SCWV_DeactivateBlockUntil := 0
global g_SCWV_DeactivateBlockReason := ""
global g_SCWV_FgAttachTid := 0
global g_SCWV_HotkeyFgPumpUntil := 0
global g_SCWV_HotkeyFgPumpCount := 0
global g_SCWV_QuickLookVersion := "4.5.0"
global g_SCWV_QuickLookInstallBusy := false
global g_SCWV_QuickLookInstallQueued := false
global g_SCWV_QLInvokeTimer := 0
global g_SCWV_QLInvokePath := ""
global g_SCWV_QLInvokeExe := ""
global g_SCWV_QLInvokeDir := ""
global g_SCWV_QLInvokeAttempts := 0
global g_SCWV_QLInvokeSendCount := 0
global g_SCWV_AsyncCmdJobs := Map()
global g_SCWV_AsyncCmdSeq := 0
global g_SCWV_SearchHttpInFlight := false
global g_SCWV_SearchPendingReq := 0
global g_SCWV_SearchPendingDelayMs := 10
global g_SCWV_ActiveClientQueryID := 0
global g_SCWV_RequestID := 0
global g_SCWV_LastRenderedID := 0
global g_SCWV_AsyncWhr := 0
global g_SCWV_AsyncReqMeta := 0
global g_SCWV_AsyncPollToken := 0
global g_SCWV_CoreHttpReqSeq := 0
global g_SCWV_CoreHttpReqs := Map()
global g_SCWV_CoreHttpPollArmed := false
global g_SCWV_HostTopMost := false
global g_SCWV_NavFallbackTried := false
global g_SCWV_LifecyclePhase := "closed"
global SCWV_PHASE_CLOSED := "CLOSED"
global SCWV_PHASE_OPENING := "OPENING"
global SCWV_PHASE_OPEN := "OPEN"
global SCWV_PHASE_CLOSING := "CLOSING"
global g_SCWV_CurrentPhase := SCWV_PHASE_CLOSED
global g_SCWV_CurrentToken := 0
global g_SCWV_ChannelTokens := Map("openclose", 0, "search", 0, "menu", 0, "preview", 0)
global g_SCWV_ParentTxnID := 0
global g_SCWV_UnifiedMode := "search" ; search | clipboard
global g_SCWV_PendingTriggerSource := "" ; search_hotkey | clipboard_hotkey | fulltext_hotkey
global g_SCWV_ClipboardHomeLock := false ; CapsLock+V 会话内禁止回落到搜索历史空白页
global g_SCWV_UiMode := "local" ; local | clipboard | fulltext | web | cli（搜索中心 UI 模式）
global g_SCWV_ClipboardHotMaxAgeSec := 180
global g_SCWV_PostHostShowScheduled := false
global g_SCWV_LastClipboardTimelineTick := 0
global g_SCWV_ClipboardTimelineScheduled := false
global g_SCWV_ClipboardTimelineRetries := 0
global g_SCWV_ClipboardDbEnsureRetries := 0
global g_SCWV_ClipboardTimelineGen := 0
global g_SCWV_PhaseLastChanged := 0
global g_SCWV_CloseAfterReady := false
global g_SCWV_AntiHangTimerArmed := false
global g_SCWV_CloseInFlight := false
global g_SCWV_TrayOpenLock := false
global g_SCWV_TrayOpenLockTick := 0
global g_SCWV_IntentQueue := []
global g_SCWV_IntentPumpBusy := false
global g_SCWV_TransitionCtx := Map("allow", false)
global g_SCWV_ForceResetStreak := 0
global g_SCWV_DegradedMode := false
global g_SCWV_FirstFrameSeen := false
global g_SCWV_PaintReady := false
global g_SCWV_AwaitingReshowPaint := false
global g_SCWV_LastPaintReadyTick := 0
global g_SCWV_LastRevealWaitLogTick := 0
global g_SCWV_RevealCommitted := false
global g_SCWV_GoStartPhase := "IDLE"
global g_SCWV_GoStartGen := 0
global g_SCWV_GoStartPending := false
global g_SCWV_GoKillLastTick := 0
global g_SCWV_GoResetInFlight := false
global g_SCWV_PrewarmScheduled := false
global g_SCWV_PrewarmDone := false
global g_SCWV_GoPhaseSinceTick := 0
global g_SCWV_GoStartTryCount := 0
global g_SCWV_LastSearchIntent := 0
global g_SCWV_ReloadRecoveryPending := false
global g_SCWV_ForceReinitRequested := false
global g_SCWV_LimitedRecoverReloadAttempts := 0
global g_SCWV_BackendHealthy := false
global g_SCWV_HandoffActive := false
global g_SCWV_HandoffUntilTick := 0
global g_SCWV_HandoffEpoch := 0
global g_SCWV_HandoffPendingOpen := 0
global g_SCWV_NavProgressTick := 0
global g_SCWV_LastOpenIntentReason := ""
global g_SCWV_LastOpenIntentTick := 0
global g_SCWV_CloseCommitActive := false
global g_SCWV_CloseCommitUntilTick := 0
global g_SCWV_UserMinimized := false
global g_SCWV_WebMsgQueue := []
global g_SCWV_WebMsgDrainBusy := false
global g_SCWV_CompositionWatchdogUntil := 0
global g_SCWV_CompositionWatchdogArmed := false
global g_SCWV_LastStaleDropTick := 0
global g_SCWV_ModeSwitchGuard := false
global g_SCWV_ModeSwitchGuardUntilTick := 0
global g_SCWV_ModeSwitchGuardEpoch := 0
global g_SCWV_ModeSwitchDeferredCaps := Map()
global g_SCWV_GuardPausedSearchTimer := 0
; 微创：搜索历史内存缓存 + 防抖写盘（热路径不再每次 FileRead/Jxon_Dump）
global g_SC_HistoryCache := ""      ; ""=未加载；Array=已加载历史关键词列表
global g_SC_HistoryFileMtime := ""    ; SearchCenterHistory.json 上次同步时的修改时间
global g_SC_HistoryDirty := false   ; 内存比磁盘新，待防抖写回
global g_SCWV_LastResizeW := 0
global g_SCWV_LastResizeH := 0
global g_SCWV_LastLayoutNotifyW := 0
global g_SCWV_LastLayoutNotifyH := 0
global g_SCWV_BoundsRetryGen := 0
global g_SCWV_RevealWatchdogReloadUsed := false

SCWV_FuncExists(fnName) {
    fnName := Trim(String(fnName))
    if (fnName = "")
        return false
    try {
        fnRef := %fnName%
        return IsObject(fnRef)
    } catch {
        try {
            Func(fnName)
            return true
        } catch {
            return false
        }
    }
}

SCWV_Log(event, detail := "") {
    try {
        logPath := A_ScriptDir . "\Cache\debug\scwv_trace.log"
        if SCWV_FuncExists("Nmer_DebugPath")
            logPath := Func("Nmer_DebugPath").Call("scwv_trace.log")
        ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        line := "[" . ts . "][" . event . "] " . String(detail) . "`r`n"
        if SCWV_FuncExists("NMER_AsyncLog") {
            Func("NMER_AsyncLog").Call(logPath, line)
            if SCWV_FuncExists("NMER_AsyncLogFlush")
                SetTimer(NMER_AsyncLogFlush, -1)
        } else
            FileAppend(line, logPath, "UTF-8")
    } catch {
    }
}

_SCWV_PhaseHex(phase) {
    p := StrUpper(Trim(String(phase)))
    switch p {
        case "OPENING":
            return "0x02"
        case "OPEN":
            return "0x03"
        case "CLOSING":
            return "0x04"
        case "ERROR":
            return "0x05"
        default:
            return "0x01"
    }
}

_SCWV_LogIFS(intentCode, focusCode := "0x00", phase := "") {
    global g_SCWV_CurrentPhase
    ph := (phase != "") ? phase : g_SCWV_CurrentPhase
    try SCWV_Log("ifs", "[" . intentCode . "/" . focusCode . "/" . _SCWV_PhaseHex(ph) . "]")
}

_SCWV_BlockDeactivate(ms := 1500, reason := "") {
    global g_SCWV_DeactivateBlockUntil, g_SCWV_DeactivateBlockReason
    blockUntil := A_TickCount + Max(0, Integer(ms))
    if (blockUntil > g_SCWV_DeactivateBlockUntil)
        g_SCWV_DeactivateBlockUntil := blockUntil
    g_SCWV_DeactivateBlockReason := String(reason)
}

_SCWV_IsDeactivateBlocked() {
    global g_SCWV_DeactivateBlockUntil
    return (g_SCWV_DeactivateBlockUntil > A_TickCount)
}

SCWV_HostAlive() {
    global g_SCWV_Gui
    try {
        if !(IsObject(g_SCWV_Gui) && g_SCWV_Gui)
            return false
        hwnd := g_SCWV_Gui.Hwnd
        if !hwnd
            return false
        return !!WinExist("ahk_id " . hwnd)
    } catch {
        return false
    }
}

SCWV_ResetHostState() {
    global g_SCWV_Gui, g_SCWV_Ctrl, g_SCWV_WV2, g_SCWV_Ready, g_SCWV_UI_Ready, g_SCWV_WaitingUiFinishedReveal, g_SCWV_DeferredHostShow, g_SCWV_Visible
    global g_SCWV_ShowWaitStartTick, g_SCWV_ShowRecoveryAttempts
    global g_SCWV_FocusPending, g_SCWV_PendingJsonQueue, GuiID_SearchCenter
    global g_SCWV_LifecyclePhase
    global g_SCWV_HandoffActive, g_SCWV_HandoffPendingOpen, g_SCWV_HandoffUntilTick, g_SCWV_CliTerminalFocus

    g_SCWV_Gui := 0
    g_SCWV_Ctrl := 0
    g_SCWV_WV2 := 0
    g_SCWV_Ready := false
    g_SCWV_UI_Ready := false
    global g_SCWV_FirstFrameSeen, g_SCWV_PaintReady, g_SCWV_AwaitingReshowPaint, g_SCWV_RevealCommitted
    g_SCWV_FirstFrameSeen := false
    g_SCWV_PaintReady := false
    g_SCWV_AwaitingReshowPaint := false
    g_SCWV_RevealCommitted := false
    g_SCWV_WaitingUiFinishedReveal := false
    g_SCWV_DeferredHostShow := false
    g_SCWV_WV2_CreateRetry := 0
    g_SCWV_CreateInFlight := false
    g_SCWV_CreateStartTick := 0
    g_SCWV_Visible := false
    g_SCWV_UserMinimized := false
    g_SCWV_FocusPending := false
    g_SCWV_PendingJsonQueue := []
    g_SCWV_ShowWaitStartTick := 0
    g_SCWV_LifecyclePhase := "closed"
    g_SCWV_HandoffActive := false
    g_SCWV_HandoffPendingOpen := 0
    g_SCWV_HandoffUntilTick := 0
    g_SCWV_CliTerminalFocus := false
    g_SCWV_SearchInputFocused := false
    SetTimer(SCWV_Show, 0)
    SetTimer(SCWV_RecoverAfterShowWaitTimeout, 0)
    SCWV_StopRevealWatchdog()
    GuiID_SearchCenter := 0
    global g_SCWV_RowCtxMenu
    g_SCWV_RowCtxMenu := 0
    _SCWV_DestroyDarkRowMenus()
    try SCWV_Preview_UnloadNative()
    catch {
    }
}

SCWV_ClearStaleHostState(reason := "") {
    global g_SCWV_Gui, g_SCWV_WaitingUiFinishedReveal, g_SCWV_CreateInFlight, g_SCWV_Visible, g_SCWV_LifecyclePhase
    if (SCWV_HostAlive())
        return false
    if (!(g_SCWV_Gui || g_SCWV_WaitingUiFinishedReveal || g_SCWV_CreateInFlight || g_SCWV_Visible || (g_SCWV_LifecyclePhase = "opening") || (g_SCWV_LifecyclePhase = "closing")))
        return false
    try SCWV_Log("stale_host_reset", "reason=" . reason . " gui=" . (g_SCWV_Gui ? "1" : "0") . " waiting=" . (g_SCWV_WaitingUiFinishedReveal ? "1" : "0") . " inflight=" . (g_SCWV_CreateInFlight ? "1" : "0") . " visible=" . (g_SCWV_Visible ? "1" : "0") . " phase=" . g_SCWV_LifecyclePhase)
    SCWV_ResetHostState()
    return true
}

SCWV_CreateWatchdogTick(*) {
    global g_SCWV_CreateInFlight
    if !g_SCWV_CreateInFlight
        return
    try SCWV_MaintainLifecycleState("create_watchdog")
    catch {
    }
    if g_SCWV_CreateInFlight
        SetTimer(SCWV_CreateWatchdogTick, -2000)
}

SCWV_MaintainLifecycleState(reason := "") {
    global g_SCWV_WaitingUiFinishedReveal, g_SCWV_ShowWaitStartTick, g_SCWV_ShowRecoveryAttempts
    global g_SCWV_CreateInFlight, g_SCWV_CreateStartTick
    global g_SCWV_LifecyclePhase

    if (g_SCWV_WaitingUiFinishedReveal && g_SCWV_ShowWaitStartTick > 0) {
        g_SCWV_LifecyclePhase := "opening"
        ; 首屏等待由 ShowWaitTimeoutCheck 负责；此处阈值须大于 safeWaitMs，避免 5s 误杀慢导航。
        waitStaleMs := 120000
        if ((A_TickCount - g_SCWV_ShowWaitStartTick) > waitStaleMs) {
            try SCWV_Log("wait_stale_reset", "reason=" . reason . " elapsed=" . (A_TickCount - g_SCWV_ShowWaitStartTick))
            catch {
            }
            SCWV_ForceCloseHost("stale_wait_timeout")
            return false
        }
    }

    if (g_SCWV_CreateInFlight && g_SCWV_CreateStartTick > 0) {
        g_SCWV_LifecyclePhase := "opening"
        createStaleMs := 12000
        if (SCWV_FuncExists("WebView2_GetCreateQueueDepth") && WebView2_GetCreateQueueDepth() > 1)
            createStaleMs := 90000
        if ((A_TickCount - g_SCWV_CreateStartTick) > createStaleMs) {
            try SCWV_Log("create_stale_reset", "reason=" . reason . " elapsed=" . (A_TickCount - g_SCWV_CreateStartTick) . " qlen=" . (SCWV_FuncExists("WebView2_GetCreateQueueDepth") ? WebView2_GetCreateQueueDepth() : -1))
            catch {
            }
            SCWV_ForceCloseHost("stale_create_timeout")
            return false
        }
    }

    return true
}

SCWV_PushLifecycleState(phase, reason := "") {
    global g_SCWV_LifecyclePhase, g_SCWV_Visible
    p := StrLower(Trim(String(phase)))
    if (p = "")
        return
    if !(p = "opening" || p = "open" || p = "closing" || p = "closed" || p = "error")
        p := "open"
    g_SCWV_LifecyclePhase := p
    try SCWV_PostJson(Map("type", "lifecycle", "phase", p, "reason", String(reason), "visible", g_SCWV_Visible ? true : false))
    catch {
    }
}

_SCWV_ShouldStartHandoff(reason := "") {
    global g_SCWV_UI_Ready, g_SCWV_FirstFrameSeen
    r := StrLower(Trim(String(reason)))
    if (r = "")
        return false
    ; Tray/toolbar 用户显式打开：不再进入 handoff，避免 OPEN 被排队 1.5s 看起来像“点了没反应”。
    if (InStr(r, "tray_") || InStr(r, "traymenu_") || InStr(r, "tray_menu_"))
        return false
    if (InStr(r, "toolbar_search") || InStr(r, "toolbar_open") || InStr(r, "ftb_ctx"))
        return false
    if (SubStr(r, 1, 15) = "handoff_replay_")
        return false
    if (g_SCWV_UI_Ready || g_SCWV_FirstFrameSeen)
        return false
    return (InStr(r, "show_redirect")
        || InStr(r, "storm_open"))
}

_SCWV_HandoffEnd(reason := "done") {
    global g_SCWV_HandoffActive, g_SCWV_HandoffPendingOpen
    if !g_SCWV_HandoffActive
        return
    g_SCWV_HandoffActive := false
    try SCWV_Log("handoff_end", "reason=" . reason)
    pending := g_SCWV_HandoffPendingOpen
    g_SCWV_HandoffPendingOpen := 0
    if (pending is Map) {
        try {
            p := pending["payload"]
            if (p is Map) {
                p2 := Map()
                for k, v in p
                    p2[k] := v
                p2["handoffReplay"] := 1
                r0 := p2.Has("reason") ? String(p2["reason"]) : ""
                p2["reason"] := "handoff_replay_" . (r0 != "" ? r0 : "open")
                SCWV_SubmitIntent("OPEN", Integer(pending["priority"]), p2)
            } else {
                SCWV_SubmitIntent("OPEN", Integer(pending["priority"]), Map("reason", "handoff_replay_open", "handoffReplay", 1))
            }
        }
    }
}

_SCWV_HandoffTick(epoch := 0, *) {
    global g_SCWV_HandoffEpoch, g_SCWV_HandoffActive, g_SCWV_HandoffUntilTick
    global g_SCWV_UI_Ready, g_SCWV_FirstFrameSeen
    if (epoch && epoch != g_SCWV_HandoffEpoch)
        return
    if !g_SCWV_HandoffActive
        return
    if (g_SCWV_UI_Ready || g_SCWV_FirstFrameSeen) {
        _SCWV_HandoffEnd("ready")
        return
    }
    if (A_TickCount >= g_SCWV_HandoffUntilTick) {
        _SCWV_HandoffEnd("timeout")
        return
    }
    SetTimer((*) => _SCWV_HandoffTick(epoch), -80)
}

_SCWV_HandoffBegin(reason := "") {
    global g_SCWV_HandoffActive, g_SCWV_HandoffUntilTick, g_SCWV_HandoffEpoch, g_SCWV_HandoffPendingOpen
    g_SCWV_HandoffActive := true
    g_SCWV_HandoffUntilTick := A_TickCount + 1500
    g_SCWV_HandoffEpoch += 1
    g_SCWV_HandoffPendingOpen := 0
    ep := g_SCWV_HandoffEpoch
    try SCWV_Log("handoff_begin", "reason=" . reason . " until=" . Integer(g_SCWV_HandoffUntilTick))
    SetTimer((*) => _SCWV_HandoffTick(ep), -80)
}

SCWV_SubmitIntent(intent, priority := 50, payload := 0) {
    global g_SCWV_IntentQueue, g_SCWV_HandoffActive, g_SCWV_HandoffPendingOpen
    global g_SCWV_LastOpenIntentReason, g_SCWV_LastOpenIntentTick
    global g_SCWV_CloseCommitActive, g_SCWV_CloseCommitUntilTick
    global g_SCWV_HandoffUntilTick
    if !(g_SCWV_IntentQueue is Array)
        g_SCWV_IntentQueue := []
    normalized := StrUpper(Trim(String(intent)))
    intentHex := (normalized = "OPEN") ? "0x11" : ((normalized = "CLOSE") ? "0x12" : ((normalized = "FORCE_RESET") ? "0x13" : "0x10"))
    if (normalized = "FORCE_CLOSE")
        normalized := "FORCE_RESET"
    if (normalized = "")
        return
    if FuncExists("Nmer_Telemetry_Record") {
        telemAction := ""
        if (normalized = "OPEN")
            telemAction := "search_center_intent_open"
        else if (normalized = "CLOSE")
            telemAction := "search_center_intent_close"
        else if (normalized = "FORCE_RESET")
            telemAction := "search_center_intent_force_reset"
        if (telemAction != "") {
            try Nmer_Telemetry_Record("surface", telemAction, true, Map("source", "SCWV_SubmitIntent"))
        }
    }
    if (g_SCWV_CloseCommitActive && A_TickCount >= g_SCWV_CloseCommitUntilTick) {
        ; 关闭提交窗口已过期，立即释放，避免 OPEN 被永久拦截
        g_SCWV_CloseCommitActive := false
        g_SCWV_CloseCommitUntilTick := 0
    }
    if (g_SCWV_CloseCommitActive && A_TickCount < g_SCWV_CloseCommitUntilTick && normalized = "OPEN") {
        if _SCWV_IsUserInitiatedOpen(payload) {
            g_SCWV_CloseCommitActive := false
            g_SCWV_CloseCommitUntilTick := 0
            try SCWV_Log("intent_open_clear_close_commit", "reason=" . (payload is Map ? String(payload.Get("reason", "")) : ""))
        } else {
            try SCWV_Log("intent_drop_close_commit", "intent=OPEN remain_ms=" . (g_SCWV_CloseCommitUntilTick - A_TickCount))
            return
        }
    }
    global g_SCWV_CloseInFlight
    if (g_SCWV_CloseInFlight && normalized = "OPEN") {
        if _SCWV_IsUserInitiatedOpen(payload) {
            deferMs := Max(80, Min(400, g_SCWV_CloseCommitUntilTick - A_TickCount))
            if (deferMs < 80)
                deferMs := 120
            openPayload := (payload is Map) ? payload : Map()
            try SCWV_Log("intent_open_defer_close_inflight", "defer_ms=" . deferMs)
            SetTimer((*) => SCWV_SubmitIntent("OPEN", priority, openPayload), -deferMs)
            return
        }
        try SCWV_Log("intent_drop_close_inflight", "intent=OPEN")
        return
    }
    _SCWV_LogIFS(intentHex, "0x00")
    if (normalized = "OPEN" && payload is Map && payload.Has("reason")) {
        reasonNorm := StrLower(Trim(String(payload["reason"])))
        delta := A_TickCount - g_SCWV_LastOpenIntentTick
        if (reasonNorm != "" && reasonNorm = g_SCWV_LastOpenIntentReason && delta >= 0 && delta < 180) {
            try SCWV_Log("intent_drop_dup_open", "reason=" . reasonNorm . " delta=" . delta)
            return
        }
        g_SCWV_LastOpenIntentReason := reasonNorm
        g_SCWV_LastOpenIntentTick := A_TickCount
    }
    isReplay := (payload is Map && payload.Has("handoffReplay") && payload["handoffReplay"])
    if (!isReplay && _SCWV_ShouldStartHandoff(payload is Map && payload.Has("reason") ? payload["reason"] : "")) {
        if !g_SCWV_HandoffActive
            _SCWV_HandoffBegin(payload is Map && payload.Has("reason") ? payload["reason"] : "")
    }
    ; Handoff self-heal: if active flag is stale, end it here so OPEN won't be black-holed.
    if (g_SCWV_HandoffActive && g_SCWV_HandoffUntilTick > 0 && A_TickCount >= g_SCWV_HandoffUntilTick) {
        try SCWV_Log("handoff_submit_recover", "reason=submit_timeout now=" . A_TickCount . " until=" . g_SCWV_HandoffUntilTick)
        _SCWV_HandoffEnd("submit_timeout")
    }
    if g_SCWV_HandoffActive {
        if (normalized = "OPEN") {
            g_SCWV_HandoffPendingOpen := Map("priority", Integer(priority), "payload", payload)
            try SCWV_Log("handoff_queue_open", "priority=" . Integer(priority))
            return
        }
        if (normalized = "CLOSE") {
            try SCWV_Log("handoff_end_for_close", "priority=" . Integer(priority))
            _SCWV_HandoffEnd("close_during_handoff")
        }
    }
    ; Queue cleaning: keep only the latest meaningful intent (last intent wins).
    ; 1) Remove identical intent entries.
    idx := g_SCWV_IntentQueue.Length
    while (idx >= 1) {
        item := g_SCWV_IntentQueue[idx]
        if (StrUpper(Trim(String(item["intent"]))) = normalized)
            g_SCWV_IntentQueue.RemoveAt(idx)
        idx -= 1
    }
    ; 2) Remove opposite low-priority entries for open/close races.
    if (normalized = "OPEN" || normalized = "CLOSE") {
        other := (normalized = "OPEN") ? "CLOSE" : "OPEN"
        idx := g_SCWV_IntentQueue.Length
        while (idx >= 1) {
            item := g_SCWV_IntentQueue[idx]
            if (StrUpper(Trim(String(item["intent"]))) = other && Integer(item["priority"]) >= Integer(priority))
                g_SCWV_IntentQueue.RemoveAt(idx)
            idx -= 1
        }
    }
    g_SCWV_IntentQueue.Push(Map("intent", normalized, "priority", Integer(priority), "payload", payload, "ts", A_TickCount))
    SetTimer(SCWV_PumpIntents, -10)
}

SCWV_PumpIntents(*) {
    global g_SCWV_IntentQueue, g_SCWV_IntentPumpBusy
    if g_SCWV_IntentPumpBusy
        return
    g_SCWV_IntentPumpBusy := true
    try {
        while (g_SCWV_IntentQueue is Array) && g_SCWV_IntentQueue.Length {
            bestIdx := 1
            bestPri := g_SCWV_IntentQueue[1]["priority"]
            loop g_SCWV_IntentQueue.Length {
                i := A_Index
                pri := g_SCWV_IntentQueue[i]["priority"]
                if (pri < bestPri) {
                    bestPri := pri
                    bestIdx := i
                }
            }
            it := g_SCWV_IntentQueue.RemoveAt(bestIdx)
            SCWV_HandleIntent(it["intent"], it["payload"], it["priority"])
        }
    } finally {
        g_SCWV_IntentPumpBusy := false
    }
}

SCWV_HandleIntent(intent, payload := 0, priority := 50) {
    iname := StrUpper(Trim(String(intent)))
    reason := payload is Map && payload.Has("reason") ? payload["reason"] : "intent_" . StrLower(iname)
    switch iname {
        case "OPEN":
            global g_SCWV_PendingTriggerSource, g_SCWV_ClipboardHomeLock
            try {
                if (payload is Map && payload.Has("initialMode"))
                    SCWV_SetUnifiedMode(String(payload["initialMode"]), false)
                if (payload is Map && payload.Has("triggerSource")) {
                    tsOpen := Trim(String(payload["triggerSource"]))
                    g_SCWV_PendingTriggerSource := tsOpen
                    g_SCWV_ClipboardHomeLock := (tsOpen = "clipboard_hotkey")
                } else {
                    g_SCWV_ClipboardHomeLock := false
                    if !(payload is Map && payload.Has("initialMode") && StrLower(String(payload["initialMode"])) = "clipboard")
                        g_SCWV_PendingTriggerSource := "search_hotkey"
                }
            }
            SCWV_TransitionTo(SCWV_PHASE_OPEN, reason, payload, Integer(priority))
        case "CLOSE":
            SCWV_TransitionTo(SCWV_PHASE_CLOSED, reason, payload, Integer(priority))
        case "FORCE_RESET":
            global g_SCWV_CurrentToken, g_SCWV_AsyncPollToken
            g_SCWV_CurrentToken += 1
            g_SCWV_AsyncPollToken += 1
            SCWV_BumpChannelToken("openclose", true)
            SCWV_BumpChannelToken("search")
            SCWV_BumpChannelToken("menu")
            SCWV_BumpChannelToken("preview")
            SCWV_ForceCloseHost(reason)
            SCWV_SetPhase(SCWV_PHASE_CLOSED, "force_reset_" . reason)
    }
}

SCWV_SetPhase(phase, reason := "") {
    global g_SCWV_CurrentPhase, g_SCWV_PhaseLastChanged
    p := StrUpper(Trim(String(phase)))
    if !(p = SCWV_PHASE_CLOSED || p = SCWV_PHASE_OPENING || p = SCWV_PHASE_OPEN || p = SCWV_PHASE_CLOSING)
        return false
    g_SCWV_CurrentPhase := p
    g_SCWV_PhaseLastChanged := A_TickCount
    SCWV_PushLifecycleState(StrLower(p), reason)
    return true
}

SCWV_IsCurrentToken(token) {
    global g_SCWV_CurrentToken, g_SCWV_LastStaleDropTick
    ok := (Integer(token) = Integer(g_SCWV_CurrentToken))
    if !ok {
        now := A_TickCount
        if ((now - g_SCWV_LastStaleDropTick) > 100) {
            g_SCWV_LastStaleDropTick := now
            try SCWV_Log("intent_drop_stale_token", "token=" . Integer(token) . " current=" . Integer(g_SCWV_CurrentToken))
        }
    }
    return ok
}

SCWV_BumpChannelToken(channel, resetParentTxn := false) {
    global g_SCWV_ChannelTokens, g_SCWV_ParentTxnID
    ch := StrLower(Trim(String(channel)))
    if (ch = "")
        ch := "openclose"
    if !(g_SCWV_ChannelTokens is Map)
        g_SCWV_ChannelTokens := Map("openclose", 0, "search", 0, "menu", 0, "preview", 0)
    cur := g_SCWV_ChannelTokens.Has(ch) ? Integer(g_SCWV_ChannelTokens[ch]) : 0
    cur += 1
    g_SCWV_ChannelTokens[ch] := cur
    if resetParentTxn
        g_SCWV_ParentTxnID += 1
    return cur
}

SCWV_GetChannelToken(channel) {
    global g_SCWV_ChannelTokens
    ch := StrLower(Trim(String(channel)))
    if !(g_SCWV_ChannelTokens is Map)
        return 0
    return g_SCWV_ChannelTokens.Has(ch) ? Integer(g_SCWV_ChannelTokens[ch]) : 0
}

SCWV_IsCurrentChannelToken(channel, token, parentTxn := 0) {
    global g_SCWV_ParentTxnID
    chNow := SCWV_GetChannelToken(channel)
    if (Integer(token) != Integer(chNow))
        return false
    if (parentTxn && Integer(parentTxn) != Integer(g_SCWV_ParentTxnID))
        return false
    return true
}

SCWV_ArmAntiHang(token) {
    global g_SCWV_AntiHangTimerArmed
    g_SCWV_AntiHangTimerArmed := true
    SetTimer((*) => SCWV_AntiHangTick(token), -60)
}

SCWV_AntiHangTick(token) {
    global g_SCWV_CurrentToken, g_SCWV_CurrentPhase, g_SCWV_PhaseLastChanged, g_SCWV_AntiHangTimerArmed, g_SCWV_NavProgressTick
    global g_SCWV_PendingTriggerSource, g_SCWV_WaitingUiFinishedReveal, g_SCWV_HotkeyFgPumpUntil, g_SCWV_Ready
    if (token != g_SCWV_CurrentToken)
        return
    if (g_SCWV_CurrentPhase = SCWV_PHASE_OPENING) {
        try {
            if g_SCWV_FirstFrameSeen {
                SCWV_SetPhase(SCWV_PHASE_OPEN, "anti_hang_promote_open")
                g_SCWV_AntiHangTimerArmed := false
                return
            }
        } catch {
        }
    }
    if !(g_SCWV_CurrentPhase = SCWV_PHASE_OPENING || g_SCWV_CurrentPhase = SCWV_PHASE_CLOSING) {
        g_SCWV_AntiHangTimerArmed := false
        return
    }
    elapsed := A_TickCount - g_SCWV_PhaseLastChanged
    timeoutMs := (g_SCWV_CurrentPhase = SCWV_PHASE_OPENING) ? 20000 : 2500
    ts := Trim(String(g_SCWV_PendingTriggerSource))
    if (g_SCWV_CurrentPhase = SCWV_PHASE_OPENING && ts = "search_hotkey")
        timeoutMs := 45000
    if (g_SCWV_CurrentPhase = SCWV_PHASE_OPENING && g_SCWV_HotkeyFgPumpUntil > A_TickCount)
        timeoutMs := Max(timeoutMs, 45000)
    if (g_SCWV_CurrentPhase = SCWV_PHASE_OPENING && g_SCWV_WaitingUiFinishedReveal && (g_SCWV_Ready || g_SCWV_NavProgressTick > 0))
        timeoutMs := Max(timeoutMs, 45000)
    if (g_SCWV_CurrentPhase = SCWV_PHASE_OPENING && g_SCWV_NavProgressTick > 0 && (A_TickCount - g_SCWV_NavProgressTick) < 2200) {
        SetTimer((*) => SCWV_AntiHangTick(token), -120)
        return
    }
    if (elapsed > timeoutMs) {
        g_SCWV_AntiHangTimerArmed := false
        try SCWV_Log("watchdog_stage", "stage=anti_hang phase=" . g_SCWV_CurrentPhase . " elapsed=" . elapsed)
        SCWV_SubmitIntent("FORCE_RESET", 5, Map("reason", "anti_hang_" . g_SCWV_CurrentPhase))
        return
    }
    SetTimer((*) => SCWV_AntiHangTick(token), -60)
}

SCWV_TransitionTo(targetPhase, reason := "", payload := 0, priority := 50) {
    global g_SCWV_CurrentPhase, g_SCWV_CurrentToken, g_SCWV_TransitionCtx, g_SCWV_CloseAfterReady, g_SCWV_PhaseLastChanged
    ts := StrUpper(Trim(String(targetPhase)))
    if !(ts = SCWV_PHASE_OPEN || ts = SCWV_PHASE_CLOSED)
        return false
    if FuncExists("Nmer_Telemetry_Record") {
        try {
            if (ts = SCWV_PHASE_OPEN)
                Nmer_Telemetry_Record("surface", "search_center_transition_open", true, Map("source", "SCWV_TransitionTo"))
            else
                Nmer_Telemetry_Record("surface", "search_center_transition_close", true, Map("source", "SCWV_TransitionTo"))
        } catch as _e {
            NmerCatch(A_ThisFunc, _e)
        }
    }
    cur := StrUpper(Trim(String(g_SCWV_CurrentPhase)))
    if !(g_SCWV_TransitionCtx is Map)
        g_SCWV_TransitionCtx := Map("allow", false)
    ; phase debounce: avoid oscillation within 50ms
    if ((A_TickCount - g_SCWV_PhaseLastChanged) < 50) {
        if ((cur = SCWV_PHASE_OPENING && ts = SCWV_PHASE_CLOSED) || (cur = SCWV_PHASE_CLOSING && ts = SCWV_PHASE_OPEN)) {
            SetTimer((*) => SCWV_SubmitIntent(ts = SCWV_PHASE_OPEN ? "OPEN" : "CLOSE", priority, Map("reason", "phase_debounce_" . reason)), -60)
            return true
        }
    }
    if (ts = SCWV_PHASE_OPEN) {
        if (cur = SCWV_PHASE_OPEN && SCWV_IsRevealedToUser()) {
            _SCWV_ApplyOpenWhileVisible(payload)
            return true
        }
        if (cur = SCWV_PHASE_OPEN && !SCWV_IsRevealedToUser()) {
            _SCWV_RecoverOpeningReveal("intent_reopen_not_revealed", payload)
            return true
        }
        if (cur = SCWV_PHASE_OPENING) {
            _SCWV_RecoverOpeningReveal("intent_coalesce_opening", payload)
            return true
        }
        if (cur = SCWV_PHASE_CLOSING)
            SCWV_SetPhase(SCWV_PHASE_OPENING, "interrupt_open_" . reason)
        g_SCWV_CurrentToken += 1
        SCWV_BumpChannelToken("openclose", true)
        token := g_SCWV_CurrentToken
        SCWV_SetPhase(SCWV_PHASE_OPENING, reason)
        SCWV_ArmAntiHang(token)
        g_SCWV_TransitionCtx["allow"] := true
        showTs := ""
        if (payload is Map && payload.Has("triggerSource"))
            showTs := String(payload["triggerSource"])
        try SCWV_Show(reason, showTs)
        finally g_SCWV_TransitionCtx["allow"] := false
        return true
    } else {
        if (cur = SCWV_PHASE_OPENING) {
            if SCWV_FuncExists("SurfaceTransaction_OnTargetClose")
                try SurfaceTransaction_OnTargetClose("search_center", Map("reason", reason, "entry", "opening_close"))
            SCWV_ApplyUserCloseDuringOpening(reason)
            return true
        }
        if (cur = SCWV_PHASE_CLOSED || cur = SCWV_PHASE_CLOSING)
            return true
        g_SCWV_CurrentToken += 1
        SCWV_BumpChannelToken("openclose", true)
        token := g_SCWV_CurrentToken
        SCWV_SetPhase(SCWV_PHASE_CLOSING, reason)
        SCWV_ArmAntiHang(token)
        rLowClose := StrLower(Trim(String(reason)))
        useHardClose := _SCWV_IsRecoveryCloseReason(reason)
            || InStr(rLowClose, "force")
            || InStr(rLowClose, "dispose")
            || !SCWV_CanWarmKeepAliveClose()
        if         useHardClose {
            SCWV_ForceCloseHost(reason)
            SCWV_SetPhase(SCWV_PHASE_CLOSED, "closed_after_hide_" . reason)
        } else {
            SCWV_StopForegroundPumps()
            SCWV_ArmCloseCommit(1200)
            g_SCWV_TransitionCtx["allow"] := true
            try SCWV_Hide(true)
            finally g_SCWV_TransitionCtx["allow"] := false
            SCWV_SetPhase(SCWV_PHASE_CLOSED, "closed_after_soft_hide_" . reason)
        }
        return true
    }
}

SearchCenter_ShouldUseWebView() {
    return true
}

SCWV_IsVisible() {
    global g_SCWV_Visible
    return g_SCWV_Visible
}

; 用户是否已能看到搜索中心（非透明等待首帧、宿主仍存活）
SCWV_IsRevealedToUser() {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_WaitingUiFinishedReveal
    if !g_SCWV_Visible || g_SCWV_WaitingUiFinishedReveal
        return false
    if !SCWV_HostAlive() || !g_SCWV_Gui
        return false
    try {
        if !WinExist("ahk_id " . g_SCWV_Gui.Hwnd)
            return false
    } catch {
        return false
    }
    return true
}

SCWV_SetUnifiedMode(mode := "search", syncWeb := true) {
    global g_SCWV_UnifiedMode
    m := StrLower(Trim(String(mode)))
    if (m != "clipboard")
        m := "search"
    g_SCWV_UnifiedMode := m
    if syncWeb {
        try SCWV_PostJson(Map("type", "setUnifiedMode", "mode", m))
    }
}

SCWV_GetUnifiedMode() {
    global g_SCWV_UnifiedMode
    m := StrLower(Trim(String(g_SCWV_UnifiedMode)))
    return (m = "clipboard") ? "clipboard" : "search"
}

_SCWV_NormalizeUiMode(mode) {
    m := StrLower(Trim(String(mode)))
    if (m = "cli")
        return "cli"
    if (m = "web")
        return "web"
    if (m = "clipboard")
        return "clipboard"
    if (m = "fulltext")
        return "fulltext"
    return "local"
}

_SCWV_TriggerSourceUiMode(triggerSource) {
    ts := StrLower(Trim(String(triggerSource)))
    if (ts = "clipboard_hotkey")
        return "clipboard"
    if (ts = "fulltext_hotkey")
        return "fulltext"
    return ""
}

_SCWV_ApplyOpenUiMode(uiMode, triggerSource := "") {
    global g_SCWV_UiMode, SearchCenterFilterType, g_SCWV_ClipboardHomeLock, g_SCWV_UnifiedMode
    um := _SCWV_NormalizeUiMode(uiMode)
    tsMode := _SCWV_TriggerSourceUiMode(triggerSource)
    if (tsMode != "")
        um := tsMode
    g_SCWV_UiMode := um
    if (um = "clipboard") {
        SearchCenterFilterType := "clipboard"
        g_SCWV_ClipboardHomeLock := (Trim(String(triggerSource)) = "clipboard_hotkey")
        g_SCWV_UnifiedMode := "clipboard"
    } else if (um = "fulltext") {
        SearchCenterFilterType := "fulltext"
        g_SCWV_ClipboardHomeLock := false
        g_SCWV_UnifiedMode := "search"
    } else if (um = "local") {
        g_SCWV_ClipboardHomeLock := false
        g_SCWV_UnifiedMode := "search"
        if (SearchCenterFilterType = "clipboard" || SearchCenterFilterType = "fulltext")
            SearchCenterFilterType := ""
    } else {
        g_SCWV_ClipboardHomeLock := false
        if (um = "web" || um = "cli") {
            if (SearchCenterFilterType = "clipboard" || SearchCenterFilterType = "fulltext")
                SearchCenterFilterType := ""
            g_SCWV_UnifiedMode := "search"
        }
    }
}

SCWV_IsClipboardUnifiedActive() {
    return (SCWV_IsVisible() && SCWV_GetUnifiedMode() = "clipboard")
}

_SCWV_ApplyOpenWhileVisible(payload := 0) {
    global g_SCWV_PendingTriggerSource, g_SCWV_ClipboardHomeLock, SearchCenterFilterType, SearchCenterWebKeyword
    global SearchCenterCurrentLimit, SearchCenterEngineMode, g_SCWV_TransitionCtx
    if !SCWV_IsRevealedToUser() {
        tsReopen := Trim(String(g_SCWV_PendingTriggerSource))
        if (payload is Map && payload.Has("triggerSource") && Trim(String(payload["triggerSource"])) != "")
            tsReopen := Trim(String(payload["triggerSource"]))
        reasonReopen := "reopen_not_revealed"
        if (payload is Map && payload.Has("reason") && Trim(String(payload["reason"])) != "")
            reasonReopen := String(payload["reason"])
        g_SCWV_TransitionCtx["allow"] := true
        try SCWV_Show(reasonReopen, tsReopen)
        finally g_SCWV_TransitionCtx["allow"] := false
        return
    }
    ts := Trim(String(g_SCWV_PendingTriggerSource))
    if (payload is Map) {
        if (payload.Has("triggerSource") && Trim(String(payload["triggerSource"])) != "")
            ts := Trim(String(payload["triggerSource"]))
        if (payload.Has("initialMode")) {
            im := StrLower(Trim(String(payload["initialMode"])))
            if (im = "clipboard")
                ts := "clipboard_hotkey"
            else if (im = "fulltext")
                ts := "fulltext_hotkey"
            else if (ts = "")
                ts := "search_hotkey"
        }
    }
    if (ts = "")
        ts := (SCWV_GetUnifiedMode() = "clipboard") ? "clipboard_hotkey" : "search_hotkey"
    g_SCWV_PendingTriggerSource := ts
    g_SCWV_ClipboardHomeLock := (ts = "clipboard_hotkey")
    if (ts = "clipboard_hotkey") {
        _SCWV_ApplyOpenUiMode("clipboard", ts)
        SearchCenterWebKeyword := ""
        try SCWV_SetUnifiedMode("clipboard", true)
        SetTimer((*) => _SCWV_RunClipboardTimelineSearch("", 0, SearchCenterCurrentLimit), -20)
        SetTimer(SCWV_PostHostShow, -80)
        return
    }
    if (ts = "fulltext_hotkey") {
        _SCWV_ApplyOpenUiMode("fulltext", ts)
        SearchCenterWebKeyword := ""
        try SCWV_SetUnifiedMode("search", true)
        try SCProvider_FullTextAdmin_MaybePost(true)
        _SCWV_RefreshLocalHomeView()
        SetTimer(SCWV_PostHostShow, -80)
        try SCWV_RequestFocusInput()
        return
    }
    global g_SCWV_UiMode
    um := _SCWV_NormalizeUiMode(g_SCWV_UiMode)
    if (um = "clipboard" || um = "fulltext")
        um := "local"
    _SCWV_ApplyOpenUiMode(um, ts)
    g_SCWV_PendingTriggerSource := "search_hotkey"
    try SCWV_SetUnifiedMode("search", true)
    if (Trim(SearchCenterWebKeyword) = "")
        _SCWV_ScheduleLocalHomeRefresh(40)
    SetTimer(SCWV_PostHostShow, -80)
    try SCWV_RequestFocusInput()
}

SCWV_OpenUnified(mode := "search", keyword := "", triggerSource := "") {
    global SearchCenterFilterType, SearchCenterWebKeyword, g_SCWV_PendingTriggerSource, g_SCWV_ClipboardHomeLock, g_SCWV_UiMode
    m := StrLower(Trim(String(mode)))
    if (m != "clipboard" && m != "fulltext")
        m := "search"
    ts := Trim(String(triggerSource))
    if (ts = "") {
        if (m = "clipboard")
            ts := "clipboard_hotkey"
        else if (m = "fulltext")
            ts := "fulltext_hotkey"
        else
            ts := "search_hotkey"
    }
    g_SCWV_PendingTriggerSource := ts
    g_SCWV_ClipboardHomeLock := (ts = "clipboard_hotkey")
    SCWV_SetUnifiedMode(m = "clipboard" ? "clipboard" : "search", false)
    if (m = "clipboard") {
        try SearchCenterFilterType := "clipboard"
        g_SCWV_UiMode := "clipboard"
    } else if (m = "fulltext") {
        try SearchCenterFilterType := "fulltext"
        g_SCWV_UiMode := "fulltext"
    } else {
        try SearchCenterFilterType := ""
        try _SCWV_SetCategoryByKey("ai")
    }
    if (Trim(String(keyword)) != "") {
        SearchCenterWebKeyword := Trim(String(keyword))
    } else if (ts = "clipboard_hotkey") {
        SearchCenterWebKeyword := ""
    }
    payload := Map("reason", "unified_open_" . m, "initialMode", m, "triggerSource", ts)
    if (SearchCenterWebKeyword != "")
        payload["keyword"] := SearchCenterWebKeyword
    SCWV_SubmitIntent("open", 20, payload)
    lockVal := g_SCWV_ClipboardHomeLock ? true : false
    SetTimer((*) => SCWV_PostJson(Map("type", "setUnifiedMode", "mode", m, "clipboardHomeLock", lockVal)), -80)
}

SCWV_PostHostShow(*) {
    global g_SCWV_PostHostShowScheduled
    if g_SCWV_PostHostShowScheduled
        return
    g_SCWV_PostHostShowScheduled := true
    SetTimer(_SCWV_PostHostShowFire, -120)
}

_SCWV_PostHostShowFire(*) {
    global g_SCWV_PendingTriggerSource, g_SCWV_Ready, g_SCWV_WV2, g_SCWV_Visible, g_SCWV_ClipboardHomeLock
    global g_SCWV_PostHostShowScheduled, g_SCWV_UiMode
    g_SCWV_PostHostShowScheduled := false
    if !g_SCWV_Visible || !g_SCWV_Ready || !g_SCWV_WV2
        return
    ts := Trim(String(g_SCWV_PendingTriggerSource))
    if (g_SCWV_ClipboardHomeLock)
        ts := "clipboard_hotkey"
    else if (ts = "") {
        if (SCWV_GetUnifiedMode() = "clipboard")
            ts := "clipboard_hotkey"
        else
            ts := "search_hotkey"
    }
    tsMode := _SCWV_TriggerSourceUiMode(ts)
    if (tsMode != "")
        _SCWV_ApplyOpenUiMode(tsMode, ts)
    um := _SCWV_NormalizeUiMode(g_SCWV_UiMode)
    focus := (ts = "clipboard_hotkey") ? "list" : "input"
    try {
        SCWV_PostJson(Map(
            "type", "hostShow",
            "triggerSource", ts,
            "uiMode", um,
            "initialMode", SCWV_GetUnifiedMode(),
            "focus", focus,
            "clipboardHomeLock", g_SCWV_ClipboardHomeLock ? true : false
        ))
    } catch {
    }
    try _SCWV_PushClipFloatToWeb()
    catch {
    }
    if (ts != "clipboard_hotkey" && ts != "fulltext_hotkey")
        SCWV_EnsureSearchHomeVisible()
    try {
        if FuncExists("CapsLock_RestoreForUiTypingOpen")
            CapsLock_RestoreForUiTypingOpen()
    } catch {
    }
}

SCWV_ModeSwitchGuardBegin(ms := 120) {
    global g_SCWV_ModeSwitchGuard, g_SCWV_ModeSwitchGuardUntilTick, g_SCWV_ModeSwitchGuardEpoch
    span := Integer(ms)
    if (span < 80)
        span := 80
    g_SCWV_ModeSwitchGuard := true
    g_SCWV_ModeSwitchGuardUntilTick := A_TickCount + span
    SCWV_ModeSwitchGuardSuspendHeavyWork(true)
    g_SCWV_ModeSwitchGuardEpoch += 1
    ep := g_SCWV_ModeSwitchGuardEpoch
    ; watchdog: UI 没有回传结束也要强制解禁 + flush，避免永久吞键
    SetTimer((*) => SCWV_ModeSwitchGuardWatchdog(ep), -(span + 40))
}

SCWV_ModeSwitchGuardWatchdog(epoch, *) {
    global g_SCWV_ModeSwitchGuardEpoch
    if (Integer(epoch) != Integer(g_SCWV_ModeSwitchGuardEpoch))
        return
    SCWV_ModeSwitchGuardEnd("watchdog_auto_flush")
}

SCWV_ModeSwitchGuardEnd(reason := "") {
    global g_SCWV_ModeSwitchGuard
    if !g_SCWV_ModeSwitchGuard
        return
    g_SCWV_ModeSwitchGuard := false
    SCWV_ModeSwitchGuardSuspendHeavyWork(false)
    SCWV_FlushDeferredCapsHintPress(reason)
}

SCWV_ModeSwitchGuardSuspendHeavyWork(suspend := true) {
    global g_SCWV_SearchTimer, g_SCWV_GuardPausedSearchTimer
    if suspend {
        if g_SCWV_SearchTimer {
            g_SCWV_GuardPausedSearchTimer := g_SCWV_SearchTimer
            try SetTimer(g_SCWV_SearchTimer, 0)
            g_SCWV_SearchTimer := 0
        }
        return
    }
    if g_SCWV_GuardPausedSearchTimer {
        ; 释放守护后小延迟恢复，优先让 ttyd 首帧绘制
        try SetTimer(g_SCWV_GuardPausedSearchTimer, -80)
        g_SCWV_GuardPausedSearchTimer := 0
    }
}

SCWV_IsHostForegroundActive() {
    global g_SCWV_Gui
    try {
        if IsObject(g_SCWV_Gui) && g_SCWV_Gui.Hwnd && WinActive("ahk_id " . g_SCWV_Gui.Hwnd)
            return true
    } catch {
    }
    return false
}

; sc_* / Caps 和弦：WebView 模式要求宿主可见且 WinActive，避免后台仍触发分类/筛选
SCWV_ScCapsInputAllowed() {
    try {
        if SearchCenter_ShouldUseWebView() {
            if !SCWV_IsRevealedToUser()
                return false
            return SCWV_IsHostForegroundActive()
        }
    } catch {
    }
    try {
        if FuncExists("IsSearchCenterActive")
            return IsSearchCenterActive()
    } catch {
    }
    return false
}

; 运行时分流：本地筛选不抢跑 Go；全文状态仅 fulltext 筛选触发
_SCWV_IsLocalOnlyFilter(filterType := "") {
    ft := Trim(String(filterType))
    return (ft = "" || ft = "clipboard")
}

_SCWV_ShouldPostFullTextStatus() {
    global SearchCenterFilterType
    return (Trim(String(SearchCenterFilterType)) = "fulltext")
}

_SCWV_ShouldScheduleRemoteSearchOnShow(triggerSource := "") {
    global SearchCenterWebKeyword, SearchCenterFilterType
    ts := Trim(String(triggerSource))
    kw := Trim(SearchCenterWebKeyword)
    ft := Trim(String(SearchCenterFilterType))
    if (ts = "clipboard_hotkey")
        return false
    if (ts = "search_hotkey" && kw = "")
        return false
    if (kw = "" && ft = "")
        return false
    if (kw = "" && _SCWV_IsLocalOnlyFilter(ft))
        return false
    return true
}

_SCWV_SetLoadingTier(tier := "shell") {
    global g_SCWV_LoadingTier
    t := Trim(String(tier))
    if (t = "")
        t := "shell"
    g_SCWV_LoadingTier := t
}

_SCWV_PushLoadingTierState(tier := "shell") {
    global g_SCWV_LifecyclePhase
    _SCWV_SetLoadingTier(tier)
    if !SearchCenter_ShouldUseWebView()
        return
    try SCWV_PostJson(Map("type", "state", "loadingTier", tier, "hostLifecycle", g_SCWV_LifecyclePhase))
    catch {
    }
}

; 本地空词视图唯一入口：历史首页 / 剪贴板时间线 / 按筛选走 Go，禁止沿用 init 预灌模板
_SCWV_RefreshLocalHomeView() {
    global SearchCenterWebKeyword, SearchCenterFilterType, g_SCWV_ClipboardHomeLock, g_SCWV_UiMode
    global SearchCenterEngineMode, SearchCenterCurrentLimit, SearchCenterSearchResults, SearchCenterHasMoreData

    if SCWV_IsWebSearchUIMode()
        return
    um := StrLower(Trim(String(g_SCWV_UiMode)))
    if (um = "cli")
        return
    if (Trim(SearchCenterWebKeyword) != "")
        return

    if (um = "fulltext" || SearchCenterFilterType = "fulltext") {
        g_SCWV_UiMode := "fulltext"
        SearchCenterFilterType := "fulltext"
        g_SCWV_ClipboardHomeLock := false
        SearchCenterSearchResults := []
        SearchCenterHasMoreData := false
        SCProvider_FullTextAdmin_MaybePost(true)
        SCWV_PushState("init")
        return
    }

    if (um = "clipboard" || SearchCenterFilterType = "clipboard") {
        g_SCWV_UiMode := "clipboard"
        SearchCenterFilterType := "clipboard"
        _SCWV_RunClipboardTimelineSearch("", 0, SearchCenterCurrentLimit)
        return
    }

    g_SCWV_ClipboardHomeLock := false
    g_SCWV_UiMode := "local"
    if (SearchCenterFilterType = "clipboard" || SearchCenterFilterType = "fulltext")
        SearchCenterFilterType := ""

    if (Trim(String(SearchCenterFilterType)) = "") {
        _SCWV_SetLoadingTier("local")
        SCProvider_RouteSearch(SCProvider_BuildCtx("", 0, SearchCenterCurrentLimit, SearchCenterFilterType))
        return
    }

    _SCWV_SetLoadingTier("remote")
    SearchCenterSearchResults := []
    SearchCenterHasMoreData := false
    _SCWV_SetLoadingTier("remote")
    SCProvider_RouteSearch(SCProvider_BuildCtx("", 0, SearchCenterCurrentLimit, SearchCenterFilterType, SearchCenterEngineMode))
    return
}

SCWV_EnsureSearchHomeVisible() {
    _SCWV_ScheduleLocalHomeRefresh(40)
}

_SCWV_ScheduleLocalHomeRefresh(delayMs := 50) {
    global g_SCWV_HomeRefreshScheduled
    if g_SCWV_HomeRefreshScheduled
        return
    g_SCWV_HomeRefreshScheduled := true
    SetTimer(_SCWV_LocalHomeRefreshTick, -Max(20, Integer(delayMs)))
}

_SCWV_LocalHomeRefreshTick(*) {
    global g_SCWV_HomeRefreshScheduled, g_SCWV_UiMode
    g_SCWV_HomeRefreshScheduled := false
    if SCWV_IsCloseRequested() || SCWV_IsWebSearchUIMode()
        return
    if (StrLower(Trim(String(g_SCWV_UiMode))) = "cli")
        return
    _SCWV_RefreshLocalHomeView()
}

; opening 阶段重复 OPEN 时合并为 reveal 重试，避免 token 重置与 Show 重入
_SCWV_RecoverOpeningReveal(reason := "recover", payload := 0) {
    global g_SCWV_PendingTriggerSource, g_SCWV_UserMinimized, g_SCWV_TransitionCtx, SearchCenterWebKeyword
    g_SCWV_UserMinimized := false
    if (payload is Map && payload.Has("triggerSource") && Trim(String(payload["triggerSource"])) != "")
        g_SCWV_PendingTriggerSource := Trim(String(payload["triggerSource"]))
    if SCWV_CanRevealToUser() {
        SCWV_TryFinishReveal(reason)
    } else if SCWV_HostAlive() {
        SCWV_ArmRevealWatchdog()
        try SCWV_PostJson(Map("type", "hostPaintNudge", "reason", reason))
        catch {
        }
    } else {
        g_SCWV_TransitionCtx["allow"] := true
        try SCWV_Show(reason, g_SCWV_PendingTriggerSource)
        finally g_SCWV_TransitionCtx["allow"] := false
    }
    if (Trim(SearchCenterWebKeyword) = "" && !SCWV_IsWebSearchUIMode())
        _SCWV_ScheduleLocalHomeRefresh(80)
}

SCWV_IsSearchInputFocused() {
    global g_SCWV_SearchInputFocused
    try {
        if !(IsSet(g_SCWV_SearchInputFocused) && g_SCWV_SearchInputFocused)
            return false
    } catch {
        return false
    }
    return SCWV_IsHostForegroundActive()
}

SCWV_ClearSearchInputFocus(reason := "") {
    global g_SCWV_SearchInputFocused
    g_SCWV_SearchInputFocused := false
    try SCWV_Log("search_input_focus_clear", "reason=" . String(reason))
    catch {
    }
}

SCWV_PostHostForeground(active) {
    try SCWV_PostJson(Map("type", "hostForeground", "active", !!active))
    catch {
    }
}

SCWV_StopRevealWatchdog() {
    SetTimer(SCWV_RevealWatchdogTick, 0)
    SetTimer(SCWV_ForceRevealIfStuck, 0)
    SetTimer(SCWV_ShowWaitTimeoutCheck, 0)
}

_SCWV_ScheduleRevealWatchdogTick(token := 0, delayMs := 400) {
    global g_SCWV_WaitingUiFinishedReveal, g_SCWV_CurrentToken
    if !g_SCWV_WaitingUiFinishedReveal
        return
    tk := token ? token : g_SCWV_CurrentToken
    SetTimer((*) => SCWV_RevealWatchdogTick(tk), -Max(80, Integer(delayMs)))
}

SCWV_ArmRevealWatchdog() {
    global g_SCWV_RevealWatchdogReloadUsed, g_SCWV_CurrentToken
    g_SCWV_RevealWatchdogReloadUsed := false
    SCWV_StopRevealWatchdog()
    myTok := g_SCWV_CurrentToken
    SetTimer(SCWV_ForceRevealIfStuck, -3500)
    SetTimer((*) => SCWV_ShowWaitTimeoutCheck(myTok), -8000)
    _SCWV_ScheduleRevealWatchdogTick(myTok, 400)
}

SCWV_ReleaseHostHotkeyScope() {
    global g_SCWV_SearchInputFocused, g_SCWV_WaitingUiFinishedReveal
    g_SCWV_SearchInputFocused := false
    g_SCWV_WaitingUiFinishedReveal := false
    try _SCWV_ClearScVkBindingOverrides()
    catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
    try HotIf()
    catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
}

SCWV_PostCapsHintPressGuarded(key) {
    ; 页面单键激活 chip 已停用，不再向 WebView 推送 capsHintPress
}

SCWV_FlushDeferredCapsHintPress(reason := "") {
    global g_SCWV_ModeSwitchDeferredCaps
    g_SCWV_ModeSwitchDeferredCaps := Map()
}

SearchCenter_IsOpeningOrBusy() {
    global g_SCWV_WaitingUiFinishedReveal, g_SCWV_CreateInFlight, g_SCWV_LifecyclePhase
    try {
        if (!SCWV_MaintainLifecycleState("is_opening_or_busy"))
            return false
        if (!SCWV_HostAlive()) {
            try SCWV_ClearStaleHostState("is_opening_or_busy_host_dead")
            catch {
            }
        }
        if ((g_SCWV_LifecyclePhase = "opening" || g_SCWV_LifecyclePhase = "closing")
            && !g_SCWV_WaitingUiFinishedReveal && !g_SCWV_CreateInFlight && !SCWV_IsVisible()) {
            try SCWV_Log("stale_phase_reset", "reason=is_opening_or_busy phase=" . g_SCWV_LifecyclePhase)
            catch {
            }
            g_SCWV_LifecyclePhase := "closed"
            return false
        }
        ; idle prewarm 仅建宿主、未等首屏揭示：勿阻塞悬浮栏/热键再次打开
        if (g_SCWV_LifecyclePhase = "opening" && !g_SCWV_WaitingUiFinishedReveal && !g_SCWV_CreateInFlight && !SCWV_IsVisible())
            return false
        if (g_SCWV_LifecyclePhase = "opening" || g_SCWV_LifecyclePhase = "closing")
            return true
    } catch {
    }
    try SCWV_ClearStaleHostState("is_opening_or_busy")
    catch {
    }
    return (g_SCWV_WaitingUiFinishedReveal || g_SCWV_CreateInFlight)
}

SCWV_GetGui() {
    global g_SCWV_Gui
    return g_SCWV_Gui
}

SCWV_GetGuiHwnd() {
    global g_SCWV_Gui
    if g_SCWV_Gui {
        try return g_SCWV_Gui.Hwnd
    }
    return 0
}

SCWV_NotifyToolbarSearchClosed(*) {
    if SCWV_FuncExists("FloatingToolbar_ClearToolbarSelection") {
        try FloatingToolbar_ClearToolbarSelection("")
        catch {
        }
        SetTimer((*) => FloatingToolbar_ClearToolbarSelection(""), -120)
        SetTimer((*) => FloatingToolbar_ClearToolbarSelection(""), -480)
    }
}

; 打开 Windows 系统回收站（剪贴板 / Hub / PQP 等面板共用消息 type: openWindowsRecycleBin）
SCWV_OpenWindowsRecycleBinFolder() {
    try Run("explorer.exe shell:RecycleBinFolder")
    catch as err {
        try TrayTip("系统回收站", err.Message, "Iconx 2")
        catch as e2 {
        }
    }
}

_SCWV_IsDarkCtxMenuOpen() {
    global g_SCWV_DarkCtxGui
    if !IsObject(g_SCWV_DarkCtxGui) || !g_SCWV_DarkCtxGui
        return false
    try {
        h := g_SCWV_DarkCtxGui.Hwnd
        return h && WinExist("ahk_id " . h)
    } catch {
        return false
    }
}

SCWV_Init(reason := "") {
    global g_SCWV_Gui, g_SCWV_CreateInFlight, g_SCWV_LifecyclePhase, g_SCWV_TransitionCtx
    r := Trim(String(reason))
    try SurfaceManager_ObserveInit("search_center", Map("entry", "SCWV_Init", "reason", r))

    try SCWV_Log("init_begin", "reason=" . r . " gui=" . (g_SCWV_Gui ? "1" : "0") . " alive=" . (SCWV_HostAlive() ? "1" : "0") . " inflight=" . (g_SCWV_CreateInFlight ? "1" : "0"))

    ; Guardrail: SCWV_Init is internal. External callers must use intents.
    isInternal := ((g_SCWV_TransitionCtx is Map) && g_SCWV_TransitionCtx["allow"])
    if (r = "") {
        if isInternal
            r := "show_internal"
        else {
            try SCWV_Log("init_guard_drop", "reason=empty")
            return
        }
    }
    if !isInternal {
        try SCWV_Log("init_guard_redirect", "reason=" . r)
        SCWV_SubmitIntent("OPEN", 20, Map("reason", r))
        return
    }

    if g_SCWV_Gui && SCWV_HostAlive()
        return
    if (g_SCWV_Gui || g_SCWV_CreateInFlight) && !SCWV_HostAlive()
        SCWV_ResetHostState()
    if g_SCWV_CreateInFlight {
        try SCWV_Log("init_skip_create_inflight", "reason=" . r)
        return
    }
    g_SCWV_LifecyclePhase := (r = "idle_prewarm") ? "closed" : "opening"

    ; 浣跨敤 Windows 鍘熺敓鏍囬鏍忎笌绯荤粺绐楀彛鎸夐挳锛堟渶灏忓寲/鏈€澶у寲/鍏抽棴锛?
    g_SCWV_Gui := Gui("+Resize +MinSize760x540 +MinimizeBox +MaximizeBox -DPIScale", "搜索中心")
    g_SCWV_Gui.BackColor := "0d1016"
    g_SCWV_Gui.MarginX := 0
    g_SCWV_Gui.MarginY := 0
    g_SCWV_Gui.OnEvent("Close", SCWV_OnGuiClose)
    g_SCWV_Gui.OnEvent("Size", SCWV_OnGuiResize)
    g_SCWV_Gui.Show("w1180 h760 Hide")
    try _SCWV_ApplyHostDarkChrome(g_SCWV_Gui.Hwnd)
    catch {
    }
    try Nmer_MoveGuiToPopupScreen(g_SCWV_Gui)
    catch {
    }
    g_SCWV_CreateInFlight := true
    g_SCWV_CreateStartTick := A_TickCount
    try SCWV_Log("init_create_begin", "reason=" . r . " hwnd=" . g_SCWV_Gui.Hwnd)

    WebView2_CreateWithSharedEnvAsync(g_SCWV_Gui.Hwnd, SCWV_OnCreated, "searchcenter_" . r)
    SetTimer(SCWV_CreateWatchdogTick, -2000)

    _SCWV_EnsureCurrentCategoryState()
    _SCWV_LoadSearchEngineMode()
    _SCWV_EnsureSearchDataReady()
}

; 为 _SCWV_PathToWebAssetUrl 生成的 https://x.local/... 注册对应盘符根目录
_SCWV_MapAllDriveVirtualHosts(wv2) {
    if !wv2
        return
    Loop 26 {
        dl := Chr(A_Index + 64)
        root := dl . ":\"
        if DirExist(root) {
            try wv2.SetVirtualHostNameToFolderMapping(StrLower(dl) . ".local", root, 1)
            catch {
            }
        }
    }
}

SCWV_OnCreated(ctrl) {
    global g_SCWV_Ctrl, g_SCWV_WV2, g_SCWV_Ready, g_SCWV_UI_Ready, g_SCWV_WaitingUiFinishedReveal, g_SCWV_NavFallbackTried
    global g_SCWV_WV2_CreateRetry, g_SCWV_CreateInFlight
    global g_SCWV_CreateStartTick
    global g_SCWV_LifecyclePhase, g_SCWV_FirstFrameSeen

    if !IsObject(ctrl) || !ctrl.HasProp("CoreWebView2") {
        errText := ""
        try errText := String(ctrl)
        catch {
            errText := ""
        }
        try SCWV_Log("webview_create_failed", "ctrl_type=" . Type(ctrl) . " retry=" . g_SCWV_WV2_CreateRetry . " value=" . errText)
        catch {
        }
        g_SCWV_CreateInFlight := false
        g_SCWV_CreateStartTick := 0
        SetTimer(SCWV_CreateWatchdogTick, 0)
        SCWV_ForceCloseHost("webview_create_failed")
        if (g_SCWV_WV2_CreateRetry < 2) {
            g_SCWV_WV2_CreateRetry += 1
            try SCWV_Log("webview_create_retry", "attempts=" . g_SCWV_WV2_CreateRetry)
            catch {
            }
            SetTimer(SCWV_Show, -180)
        } else {
            try SCWV_Log("webview_create_retry_exhausted", "attempts=" . g_SCWV_WV2_CreateRetry)
            catch {
            }
        }
        return
    }

    g_SCWV_WV2_CreateRetry := 0
    g_SCWV_CreateInFlight := false
    g_SCWV_CreateStartTick := 0
    SetTimer(SCWV_CreateWatchdogTick, 0)
    g_SCWV_LifecyclePhase := "opening"
    g_SCWV_Ctrl := ctrl
    g_SCWV_WV2 := ctrl.CoreWebView2
    g_SCWV_Ready := false
    g_SCWV_UI_Ready := false
    g_SCWV_FirstFrameSeen := false
    g_SCWV_PaintReady := false
    g_SCWV_RevealCommitted := false
    g_SCWV_WaitingUiFinishedReveal := false
    g_SCWV_NavFallbackTried := false
    SCWV_StopRevealWatchdog()

    try g_SCWV_Ctrl.DefaultBackgroundColor := 0xFF0D1016
    try g_SCWV_Ctrl.IsVisible := true

    SCWV_ApplyBounds()

    s := g_SCWV_WV2.Settings
    s.AreDefaultContextMenusEnabled := true
    s.AreDevToolsEnabled := true
    ; 保持 WebView2 原生按键/IME 行为，减少与宿主全局钩子的焦点竞争
    try s.AreBrowserAcceleratorKeysEnabled := true
    ApplyWebView2PerformanceSettings(g_SCWV_WV2)
    WebView2_RegisterHostBridge(g_SCWV_WV2)

    try g_SCWV_WV2.add_WebMessageReceived(SCWV_OnWebMessage)
    try g_SCWV_WV2.add_NavigationCompleted(SCWV_OnNavigationCompleted)
    try g_SCWV_WV2.add_NavigationStarting(SCWV_OnNavigationStarting)

     try ApplyUnifiedWebViewAssets(g_SCWV_WV2)

    
    ; 映射物理驱动器到虚拟域名，允许 WebView2 播放本地媒体 / PDF iframe
    ; 仅 C/D/E 时 F:、G: 等盘上的文件会得到 https://x.local/... 但无映射，预览为空
    ; 1 = COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW
    _SCWV_MapAllDriveVirtualHosts(g_SCWV_WV2)
    
    global g_SCWV_NavProgressTick
    g_SCWV_NavProgressTick := A_TickCount
    g_SCWV_WV2.Navigate(BuildAppLocalUrl("SearchCenter.html"))
}

SCWV_IsCloseRequested() {
    global g_SCWV_CloseInFlight, g_SCWV_CloseAfterReady, g_SCWV_CurrentPhase, g_SCWV_LifecyclePhase
    global g_SCWV_CloseCommitActive, g_SCWV_CloseCommitUntilTick
    if g_SCWV_CloseAfterReady || g_SCWV_CloseInFlight
        return true
    cur := StrUpper(Trim(String(g_SCWV_CurrentPhase)))
    if (cur = SCWV_PHASE_CLOSED || cur = SCWV_PHASE_CLOSING)
        return true
    lc := StrLower(Trim(String(g_SCWV_LifecyclePhase)))
    if (lc = "closed" || lc = "closing")
        return true
    if (g_SCWV_CloseCommitActive && A_TickCount < g_SCWV_CloseCommitUntilTick)
        return true
    return false
}

SCWV_ApplyUserCloseDuringOpening(reason := "") {
    global g_SCWV_TransitionCtx, g_SCWV_CloseInFlight
    global g_SCWV_WaitingUiFinishedReveal, g_SCWV_CloseAfterReady
    g_SCWV_CloseAfterReady := false
    g_SCWV_WaitingUiFinishedReveal := false
    g_SCWV_CloseInFlight := true
    SCWV_SetPhase(SCWV_PHASE_CLOSING, "opening_user_close_" . reason)
    SCWV_StopRevealWatchdog()
    SetTimer(SCWV_RefreshComposition, 0)
    SCWV_StopForegroundPumps()
    SCWV_ArmCloseCommit(2000)
    SCWV_NotifyToolbarSearchClosed()
    useHard := _SCWV_IsRecoveryCloseReason(reason) || !SCWV_CanWarmKeepAliveClose()
    if useHard {
        SCWV_ForceCloseHost(reason)
        SCWV_SetPhase(SCWV_PHASE_CLOSED, "opening_hard_close_" . reason)
        g_SCWV_CloseInFlight := false
        return
    }
    g_SCWV_TransitionCtx["allow"] := true
    try SCWV_Hide(true)
    finally g_SCWV_TransitionCtx["allow"] := false
    SCWV_SetPhase(SCWV_PHASE_CLOSED, "opening_soft_close_" . reason)
    g_SCWV_CloseInFlight := false
}

SCWV_CanWarmKeepAliveClose() {
    global g_SCWV_CreateInFlight, g_SCWV_WV2, g_SCWV_Ready, g_SCWV_DegradedMode, AppearanceActivationMode
    if g_SCWV_DegradedMode || g_SCWV_CreateInFlight
        return false
    if !SCWV_HostAlive() || !g_SCWV_WV2 || !g_SCWV_Ready
        return false
    mode := "toolbar"
    try mode := NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar")
    catch {
    }
    if (mode = "hole")
        return false
    return true
}

SCWV_ScheduleIdlePrewarm(delayMs := 6000) {
    global g_SCWV_PrewarmScheduled, g_SCWV_Gui, g_SCWV_Visible
    if g_SCWV_PrewarmScheduled
        return
    if (g_SCWV_Gui && SCWV_HostAlive())
        return
    if g_SCWV_Visible
        return
    g_SCWV_PrewarmScheduled := true
    SetTimer(SCWV_PrewarmHost, -Max(1500, Abs(delayMs)))
}

SCWV_PrewarmHost(*) {
    global g_SCWV_PrewarmDone, g_SCWV_Gui, g_SCWV_CreateInFlight, g_SCWV_TransitionCtx, g_SCWV_Visible
    if (g_SCWV_Gui && SCWV_HostAlive()) {
        g_SCWV_PrewarmDone := true
        return
    }
    if g_SCWV_CreateInFlight || g_SCWV_Visible
        return
    try SCWV_Log("prewarm_begin", "")
    g_SCWV_TransitionCtx["allow"] := true
    try SCWV_Init("idle_prewarm")
    catch {
    } finally {
        g_SCWV_TransitionCtx["allow"] := false
    }
    g_SCWV_PrewarmDone := true
    try SCWV_Log("prewarm_done", "ready=" . (g_SCWV_Ready ? "1" : "0") . " inflight=" . (g_SCWV_CreateInFlight ? "1" : "0"))
    catch {
    }
}

SCWV_OnGuiClose(*) {
    global GDHO_VISIBLE, NativeDropSessionActive, g_SCWV_WaitingUiFinishedReveal, g_SCWV_Visible
    global g_SCWV_CreateInFlight, g_SCWV_LifecyclePhase, g_SCWV_Gui, g_SCWV_IntentQueue
    global g_SCWV_CloseAfterReady, g_SCWV_HandoffActive, g_SCWV_HandoffPendingOpen, g_SCWV_TransitionCtx
    global g_SCWV_CloseInFlight
    if g_SCWV_CloseInFlight {
        try SCWV_Log("gui_close_skip_inflight", "")
        return
    }
    if (g_SCWV_LifecyclePhase = "closing") {
        try SCWV_Log("gui_close_force_destroy", "hwnd=" . (g_SCWV_Gui ? g_SCWV_Gui.Hwnd : 0))
        try {
            if g_SCWV_Gui
                g_SCWV_Gui.Destroy()
        } catch {
        }
        try SCWV_ResetHostState()
        catch {
        }
        return
    }
    g_SCWV_CloseInFlight := true
    g_SCWV_CloseAfterReady := false
    g_SCWV_WaitingUiFinishedReveal := false
    g_SCWV_HandoffActive := false
    g_SCWV_HandoffPendingOpen := 0
    g_SCWV_IntentQueue := []
    SetTimer(SCWV_PumpIntents, 0)
    SCWV_StopRevealWatchdog()
    SetTimer(SCWV_RefreshComposition, 0)
    SCWV_SetPhase(SCWV_PHASE_CLOSING, "gui_close")
    SCWV_NotifyToolbarSearchClosed()
    try SCWV_Log("gui_close_request", "visible=" . (g_SCWV_Visible ? "1" : "0") . " waiting=" . (g_SCWV_WaitingUiFinishedReveal ? "1" : "0") . " inflight=" . (g_SCWV_CreateInFlight ? "1" : "0") . " gdho=" . (GDHO_VISIBLE ? "1" : "0") . " native=" . (NativeDropSessionActive ? "1" : "0") . " warm=" . (SCWV_CanWarmKeepAliveClose() ? "1" : "0"))
    if SCWV_CanWarmKeepAliveClose() {
        SCWV_StopForegroundPumps()
        SCWV_ArmCloseCommit(2000)
        g_SCWV_TransitionCtx["allow"] := true
        try SCWV_Hide(true)
        finally g_SCWV_TransitionCtx["allow"] := false
        SCWV_SetPhase(SCWV_PHASE_CLOSED, "gui_soft_close")
        g_SCWV_CloseInFlight := false
        return
    }
    SCWV_StopForegroundPumps()
    SCWV_ArmCloseCommit(1200)
    g_SCWV_LifecyclePhase := "closing"
    SCWV_ForceCloseHost("gui_close")
}

SCWV_OnGuiResize(GuiObj, MinMax, Width, Height) {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_UserMinimized, g_SCWV_LastResizeW, g_SCWV_LastResizeH
    global g_SCWV_CliTerminalFocus
    if (MinMax = -1) {
        g_SCWV_UserMinimized := true
        g_SCWV_CliTerminalFocus := false
        SCWV_StopForegroundPumps()
        try SCWV_PostJson(Map("type", "hostMinimized", "active", true))
        catch {
        }
        return
    }
    if (MinMax >= 0) {
        wasMin := g_SCWV_UserMinimized
        g_SCWV_UserMinimized := false
        if wasMin {
            try SCWV_PostJson(Map("type", "hostMinimized", "active", false))
            catch {
            }
        }
    }
    sizeChanged := false
    if (Width > 0 && Height > 0) {
        if (Abs(Width - g_SCWV_LastResizeW) > 2 || Abs(Height - g_SCWV_LastResizeH) > 2) {
            sizeChanged := true
            g_SCWV_LastResizeW := Width
            g_SCWV_LastResizeH := Height
        }
        SCWV_ApplyBounds(Width, Height)
    }
    if SCWV_ShouldRunComposition()
        SCWV_ScheduleCompositionPump("gui_resize")
    else {
        if (Width > 0 && Height > 0)
            SCWV_ApplyBounds(Width, Height)
        try SCWV_Preview_OnHostLayoutChanged()
        catch {
        }
    }
    if sizeChanged
        SCWV_ScheduleBoundsRetries("gui_resize")
}

SCWV_OnNavigationCompleted(sender, args) {
    global g_SCWV_Visible, g_SCWV_NavFallbackTried, g_SCWV_FirstFrameSeen, g_SCWV_NavProgressTick
    global g_SCWV_WaitingUiFinishedReveal, g_SCWV_UI_Ready

    try ok := args.IsSuccess
    catch {
        ok := true
    }
    if !ok {
        if !g_SCWV_NavFallbackTried {
            g_SCWV_NavFallbackTried := true
            fileUrl := "file:///" . StrReplace(HtmlPanelPath("SearchCenter.html"), "\", "/")
            try SCWV_Log("nav_fallback_file", fileUrl)
            try sender.Navigate(fileUrl)
            catch {
            }
        }
        return
    }
    g_SCWV_FirstFrameSeen := true
    g_SCWV_NavProgressTick := A_TickCount
    if !g_SCWV_Visible && !g_SCWV_WaitingUiFinishedReveal {
        try SCWV_Log("nav_completed_prewarm", "ok=1 ui=" . (g_SCWV_UI_Ready ? "1" : "0"))
        global g_SCWV_LifecyclePhase
        g_SCWV_LifecyclePhase := "closed"
        try SurfaceManager_ObserveHide("search_center", Map("entry", "SCWV_PrewarmNavDone", "reason", "idle_prewarm"))
        catch {
        }
        try SCWV_PostJson(Map("type", "hostPaintNudge", "reason", "prewarm_nav"))
        catch {
        }
        return
    }
    try SCWV_Log("nav_completed", "ok=1 visible=" . (g_SCWV_Visible ? "1" : "0") . " waiting=" . (g_SCWV_WaitingUiFinishedReveal ? "1" : "0"))
    _SCWV_HandoffEnd("first_frame")
    if SCWV_IsCloseRequested()
        return
    if g_SCWV_WaitingUiFinishedReveal && g_SCWV_FirstFrameSeen && !g_SCWV_Ready
        _SCWV_BootstrapWebReadyIfStalled("nav_completed_waiting")
    try SCWV_PushThemeToWeb()
    catch {
    }
    SCWV_ScheduleCompositionPump("nav_completed")
    SCWV_TryFinishReveal("nav_completed")

    global g_SCWV_PendingTriggerSource
    if (Trim(String(g_SCWV_PendingTriggerSource)) = "search_hotkey") && !SCWV_IsCloseRequested()
        SCWV_StartHotkeyForegroundPump(10000)

    SCWV_RefreshComposition()
}

SCWV_OnNavigationStarting(sender, args) {
    global g_SCWV_NavProgressTick, g_SCWV_Ready, g_SCWV_UI_Ready, g_SCWV_FirstFrameSeen, g_SCWV_PaintReady, g_SCWV_RevealCommitted
    g_SCWV_NavProgressTick := A_TickCount
    g_SCWV_Ready := false
    g_SCWV_UI_Ready := false
    g_SCWV_FirstFrameSeen := false
    g_SCWV_PaintReady := false
    g_SCWV_RevealCommitted := false
}

SCWV_CanRevealToUser() {
    global g_SCWV_FirstFrameSeen, g_SCWV_UI_Ready, g_SCWV_AwaitingReshowPaint, g_SCWV_PaintReady, g_SCWV_Ready
    if !g_SCWV_UI_Ready
        return false
    ; 温保活再开：页面未重新导航，FirstFrameSeen 可能仍为 0（prewarm 时 nav_completed 早退）
    if g_SCWV_AwaitingReshowPaint || (g_SCWV_Ready && !g_SCWV_FirstFrameSeen)
        return g_SCWV_Ready && g_SCWV_PaintReady
    return g_SCWV_FirstFrameSeen && g_SCWV_UI_Ready
}

SCWV_TryFinishReveal(source := "") {
    global g_SCWV_WaitingUiFinishedReveal, g_SCWV_RevealCommitted, g_SCWV_Visible
    global g_SCWV_FirstFrameSeen, g_SCWV_UI_Ready, g_SCWV_PaintReady, g_SCWV_AwaitingReshowPaint
    if SCWV_IsCloseRequested()
        return false
    if g_SCWV_RevealCommitted || g_SCWV_Visible
        return false
    if !g_SCWV_WaitingUiFinishedReveal
        return false
    if !SCWV_CanRevealToUser() {
        try {
            global g_SCWV_LastRevealWaitLogTick
            if !(IsSet(g_SCWV_LastRevealWaitLogTick) && (A_TickCount - g_SCWV_LastRevealWaitLogTick) < 400) {
                g_SCWV_LastRevealWaitLogTick := A_TickCount
                SCWV_Log("finish_reveal_wait", "source=" . String(source) . " frame=" . (g_SCWV_FirstFrameSeen ? "1" : "0") . " ui=" . (g_SCWV_UI_Ready ? "1" : "0") . " paint=" . (g_SCWV_PaintReady ? "1" : "0") . " awaiting=" . (g_SCWV_AwaitingReshowPaint ? "1" : "0"))
            }
        } catch {
        }
        return false
    }
    g_SCWV_RevealCommitted := true
    SCWV_FinishReveal()
    return true
}

_SCWV_IsUserInitiatedOpen(payload) {
    if !(payload is Map)
        return false
    r := StrLower(Trim(String(payload.Get("reason", ""))))
    ts := StrLower(Trim(String(payload.Get("triggerSource", ""))))
    if (ts = "search_hotkey" || ts = "clipboard_hotkey" || ts = "fulltext_hotkey")
        return true
    if (InStr(r, "toolbar_search") || InStr(r, "search_hotkey") || InStr(r, "ftb_") || InStr(r, "tray_"))
        return true
    return false
}

SCWV_NotifyHostLayout(clientW, clientH) {
    global g_SCWV_WV2, g_SCWV_LastLayoutNotifyW, g_SCWV_LastLayoutNotifyH
    if !g_SCWV_WV2 || clientW < 1 || clientH < 1
        return
    cw := Integer(clientW)
    ch := Integer(clientH)
    if (Abs(cw - Integer(g_SCWV_LastLayoutNotifyW)) <= 2 && Abs(ch - Integer(g_SCWV_LastLayoutNotifyH)) <= 2)
        return
    g_SCWV_LastLayoutNotifyW := cw
    g_SCWV_LastLayoutNotifyH := ch
    try WebView_QueuePayload(g_SCWV_WV2, Map("type", "hostLayout", "width", cw, "height", ch))
    catch {
    }
}

SCWV_ApplyBounds(clientW := 0, clientH := 0) {
    global g_SCWV_Gui, g_SCWV_Ctrl

    if !g_SCWV_Gui || !g_SCWV_Ctrl
        return false

    cw := Integer(clientW)
    ch := Integer(clientH)
    if (cw < 1 || ch < 1) {
        cw := 0, ch := 0
        try WinGetClientPos(, , &cw, &ch, g_SCWV_Gui.Hwnd)
        catch {
            return false
        }
    }
    if (cw < 200 || ch < 160)
        return false
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    try g_SCWV_Ctrl.Bounds := rc
    catch {
        return false
    }
    try g_SCWV_Ctrl.NotifyParentWindowPositionChanged()
    catch {
    }
    SCWV_NotifyHostLayout(cw, ch)
    return true
}

SCWV_ScheduleBoundsRetries(reason := "") {
    static allowed := Map("show_open", 1, "show_open_recover", 1, "finish_reveal", 1, "gui_resize", 1)
    r := String(reason)
    if !allowed.Has(r)
        return
    global g_SCWV_CurrentToken, g_SCWV_BoundsRetryGen
    tok := g_SCWV_CurrentToken
    gen := ++g_SCWV_BoundsRetryGen
    for delay in [16, 120, 400] {
        SetTimer((*) => SCWV_ApplyBoundsRetryTick(tok, r, gen), -delay)
    }
}

SCWV_ApplyBoundsRetryTick(token := 0, reason := "", gen := 0) {
    global g_SCWV_BoundsRetryGen, g_SCWV_UserMinimized
    if (gen && gen != g_SCWV_BoundsRetryGen)
        return
    if (token && !SCWV_IsCurrentToken(token))
        return
    if !SCWV_ShouldRunComposition()
        return
    if SCWV_IsCloseRequested()
        return
    if SCWV_ApplyBounds()
        return
    if !g_SCWV_UserMinimized {
        try SCWV_EnsureMaximized()
        catch {
        }
    }
    SCWV_ApplyBounds()
}

SCWV_CompositionPump(reason := "", token := 0) {
    global g_SCWV_Gui, g_SCWV_Ctrl, g_SCWV_WV2, g_SCWV_UserMinimized
    if (token && !SCWV_IsCurrentToken(token))
        return
    if !g_SCWV_Gui || !g_SCWV_Ctrl
        return
    try {
        SCWV_ApplyBounds()
        try g_SCWV_Ctrl.IsVisible := true
        catch {
        }
        try g_SCWV_Ctrl.NotifyParentWindowPositionChanged()
        catch {
        }
        try SCWV_Preview_OnHostLayoutChanged()
        catch {
        }
        hwnd := g_SCWV_Gui.Hwnd
        if hwnd {
            if SCWV_FuncExists("WebView2_ForceHostRedraw")
                try WebView2_ForceHostRedraw(hwnd)
                catch {
                }
        }
    } catch {
    }
    if IsObject(g_SCWV_WV2) && !g_SCWV_UserMinimized {
        r := StrLower(Trim(String(reason)))
        if (r = "finish_reveal" || r = "show_open" || r = "web_ready")
            try WebView_QueuePayload(g_SCWV_WV2, Map("type", "hostPaintNudge", "reason", String(reason)))
            catch {
            }
    }
}

SCWV_StartCompositionWatchdog(durationMs := 12000) {
    global g_SCWV_CompositionWatchdogUntil, g_SCWV_CompositionWatchdogArmed
    g_SCWV_CompositionWatchdogUntil := A_TickCount + Max(2000, Integer(durationMs))
    if !g_SCWV_CompositionWatchdogArmed {
        g_SCWV_CompositionWatchdogArmed := true
        SetTimer(SCWV_CompositionWatchdogTick, 200)
    }
}

SCWV_StopCompositionWatchdog(*) {
    global g_SCWV_CompositionWatchdogUntil, g_SCWV_CompositionWatchdogArmed
    g_SCWV_CompositionWatchdogUntil := 0
    g_SCWV_CompositionWatchdogArmed := false
    SetTimer(SCWV_CompositionWatchdogTick, 0)
}

SCWV_CompositionWatchdogTick(*) {
    global g_SCWV_CompositionWatchdogUntil, g_SCWV_CompositionWatchdogArmed
    global g_SCWV_Visible, g_SCWV_WaitingUiFinishedReveal, g_SCWV_PaintReady, g_SCWV_Gui
    if !g_SCWV_CompositionWatchdogArmed
        return
    if SCWV_IsCloseRequested() || !(g_SCWV_Visible || g_SCWV_WaitingUiFinishedReveal) {
        SCWV_StopCompositionWatchdog()
        return
    }
    if (A_TickCount > g_SCWV_CompositionWatchdogUntil) {
        SCWV_StopCompositionWatchdog()
        return
    }
    global g_SCWV_AwaitingReshowPaint
    if (g_SCWV_Visible && g_SCWV_PaintReady && g_SCWV_Gui && !g_SCWV_AwaitingReshowPaint) {
        cw := 0, ch := 0
        try WinGetClientPos(, , &cw, &ch, g_SCWV_Gui.Hwnd)
        if (cw >= 320 && ch >= 240) {
            SCWV_StopCompositionWatchdog()
            return
        }
    }
    SCWV_CompositionPump("watchdog")
}

SCWV_ScheduleCompositionPump(reason := "") {
    global g_SCWV_CurrentToken
    tok := g_SCWV_CurrentToken
    SCWV_CompositionPump(reason . "_0", tok)
    SetTimer((*) => SCWV_CompositionPump(reason . "_16", tok), -16)
    SetTimer((*) => SCWV_CompositionPump(reason . "_48", tok), -48)
    SetTimer((*) => SCWV_CompositionPump(reason . "_120", tok), -120)
    SetTimer((*) => SCWV_CompositionPump(reason . "_280", tok), -280)
    SetTimer((*) => SCWV_CompositionPump(reason . "_420", tok), -420)
    SetTimer((*) => SCWV_CompositionPump(reason . "_640", tok), -640)
    SetTimer((*) => SCWV_CompositionPump(reason . "_900", tok), -900)
    SetTimer((*) => SCWV_CompositionPump(reason . "_1400", tok), -1400)
    SetTimer((*) => SCWV_CompositionPump(reason . "_2200", tok), -2200)
    SetTimer((*) => SCWV_CompositionPump(reason . "_3200", tok), -3200)
    SCWV_StartCompositionWatchdog(12000)
}

SCWV_ShouldRunComposition(*) {
    global g_SCWV_Visible, g_SCWV_WaitingUiFinishedReveal
    return g_SCWV_Visible || g_SCWV_WaitingUiFinishedReveal
}

SCWV_ArmCloseCommit(ms := 900) {
    global g_SCWV_CloseCommitActive, g_SCWV_CloseCommitUntilTick
    g_SCWV_CloseCommitActive := true
    g_SCWV_CloseCommitUntilTick := A_TickCount + Max(250, Integer(ms))
}

SCWV_StopForegroundPumps(*) {
    global g_SCWV_HotkeyFgPumpUntil, g_SCWV_HotkeyFgPumpCount
    g_SCWV_HotkeyFgPumpUntil := 0
    g_SCWV_HotkeyFgPumpCount := 0
    SetTimer(SCWV_HotkeyForegroundPumpTick, 0)
}

SCWV_EnsureMaximized(*) {
    global g_SCWV_Gui, g_SCWV_UserMinimized, g_SCWV_Visible, g_SCWV_WaitingUiFinishedReveal
    if g_SCWV_UserMinimized || !g_SCWV_Gui
        return
    if !g_SCWV_Visible && !g_SCWV_WaitingUiFinishedReveal
        return
    if SCWV_FuncExists("Nmer_EnsureGuiMaximizedOnPopupScreen") {
        try Nmer_EnsureGuiMaximizedOnPopupScreen(g_SCWV_Gui)
        catch {
        }
        return
    }
    hwndExpr := "ahk_id " . g_SCWV_Gui.Hwnd
    try {
        mm := WinGetMinMax(hwndExpr)
        if (mm != 1)
            WinMaximize(hwndExpr)
    } catch {
    }
}

SCWV_ApplyCapsLockForSearchOpen() {
    if SCWV_FuncExists("CapsLock_RestoreForUiTypingOpen")
        CapsLock_RestoreForUiTypingOpen()
    else if SCWV_FuncExists("CapsLock_ScheduleNormalizeAfterChord")
        CapsLock_ScheduleNormalizeAfterChord()
}

SCWV_PrepareForegroundSteal() {
    try {
        pid := DllCall("GetCurrentProcessId", "UInt")
        DllCall("AllowSetForegroundWindow", "UInt", pid)
    } catch {
    }
    try DllCall("LockSetForegroundWindow", "UInt", 2)
    catch {
    }
    try {
        if SCWV_FuncExists("CommandPalette_CancelDeferredFocusTimers")
            CommandPalette_CancelDeferredFocusTimers()
    } catch {
    }
    try {
        cpHwnd := SCWV_FuncExists("CommandPalette_GetGuiHwnd") ? CommandPalette_GetGuiHwnd() : 0
        if cpHwnd && WinExist("ahk_id " . cpHwnd)
            DllCall("ShowWindow", "Ptr", cpHwnd, "Int", 0)
    } catch {
    }
    global g_SCWV_FgAttachTid
    g_SCWV_FgAttachTid := 0
    try {
        fore := WinGetID("A")
        if fore {
            foreTid := DllCall("GetWindowThreadProcessId", "Ptr", fore, "UInt*", 0)
            curTid := DllCall("GetCurrentThreadId", "UInt")
            if foreTid && foreTid != curTid {
                if DllCall("AttachThreadInput", "UInt", curTid, "UInt", foreTid, "Int", true)
                    g_SCWV_FgAttachTid := foreTid
            }
        }
    } catch {
    }
}

SCWV_ReleaseForegroundSteal() {
    global g_SCWV_FgAttachTid
    if !g_SCWV_FgAttachTid
        return
    try {
        curTid := DllCall("GetCurrentThreadId", "UInt")
        DllCall("AttachThreadInput", "UInt", curTid, "UInt", g_SCWV_FgAttachTid, "Int", false)
    } catch {
    }
    g_SCWV_FgAttachTid := 0
}

SCWV_ScheduleHandoffForegroundRetries() {
    SetTimer((*) => SCWV_RaiseToForeground("handoff_retry_80"), -80)
    SetTimer((*) => SCWV_RaiseToForeground("handoff_retry_220"), -220)
    SetTimer((*) => SCWV_RaiseToForeground("handoff_retry_500"), -500)
    SetTimer((*) => SCWV_RaiseToForeground("handoff_retry_1000"), -1000)
    SetTimer((*) => SCWV_RaiseToForeground("handoff_retry_1800"), -1800)
}

SCWV_ForegroundPulse(hwnd) {
    if !hwnd
        return false
    expr := "ahk_id " . hwnd
    if !WinExist(expr)
        return false
    posFlags := 0x0001 | 0x0002 | 0x0040
    try DllCall("ShowWindow", "Ptr", hwnd, "Int", 9)
    catch {
    }
    try DllCall("ShowWindow", "Ptr", hwnd, "Int", 3)
    catch {
    }
    try DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", posFlags)
    catch {
    }
    try {
        vkAlt := 0x12
        DllCall("keybd_event", "UChar", vkAlt, "UChar", 0, "UInt", 0, "UPtr", 0)
        DllCall("keybd_event", "UChar", vkAlt, "UChar", 0, "UInt", 2, "UPtr", 0)
    } catch {
    }
    ok := false
    try ok := !!DllCall("SetForegroundWindow", "Ptr", hwnd)
    catch {
    }
    try DllCall("SwitchToThisWindow", "Ptr", hwnd, "Int", true)
    catch {
    }
    try DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", -2, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", posFlags)
    catch {
    }
    try {
        if WinActive(expr)
            ok := true
    } catch {
    }
    return ok
}

SCWV_StartHotkeyForegroundPump(durationMs := 14000) {
    global g_SCWV_HotkeyFgPumpUntil, g_SCWV_HotkeyFgPumpCount
    g_SCWV_HotkeyFgPumpUntil := A_TickCount + Max(3000, Integer(durationMs))
    g_SCWV_HotkeyFgPumpCount := 0
    try SCWV_PrepareForegroundSteal()
    SetTimer(SCWV_HotkeyForegroundPumpTick, 0)
    SetTimer(SCWV_HotkeyForegroundPumpTick, -1)
}

SCWV_HotkeyForegroundPumpTick(*) {
    global g_SCWV_HotkeyFgPumpUntil, g_SCWV_HotkeyFgPumpCount, g_SCWV_Gui, g_SCWV_Visible, g_SCWV_UserMinimized
    if SCWV_IsCloseRequested() || !g_SCWV_Visible || g_SCWV_UserMinimized {
        SetTimer(SCWV_HotkeyForegroundPumpTick, 0)
        return
    }
    if (A_TickCount > g_SCWV_HotkeyFgPumpUntil) {
        SetTimer(SCWV_HotkeyForegroundPumpTick, 0)
        return
    }
    g_SCWV_HotkeyFgPumpCount += 1
    hwnd := 0
    if IsObject(g_SCWV_Gui) {
        try hwnd := g_SCWV_Gui.Hwnd
        catch {
        }
    }
    if hwnd && WinExist("ahk_id " . hwnd) {
        try SCWV_EnsureMaximized()
        catch {
        }
        ok := false
        try ok := SCWV_RaiseToForeground("hotkey_fg_pump_" . g_SCWV_HotkeyFgPumpCount)
        catch {
        }
        if !ok {
            try ok := SCWV_ForegroundPulse(hwnd)
            catch {
            }
        }
        if ok && (SCWV_IsRevealedToUser() || WinActive("ahk_id " . hwnd)) {
            SetTimer(SCWV_HotkeyForegroundPumpTick, 0)
            return
        }
    }
    SetTimer(SCWV_HotkeyForegroundPumpTick, -90)
}

SCWV_RaiseToForeground(reason := "sc_raise", focusCb := 0) {
    global g_SCWV_Gui, g_SCWV_Ctrl, g_SCWV_Visible, g_SCWV_UserMinimized, g_SCWV_LifecyclePhase, g_SCWV_CurrentPhase
    global g_SCWV_WaitingUiFinishedReveal
    if !(g_SCWV_Visible || g_SCWV_WaitingUiFinishedReveal) || g_SCWV_UserMinimized
        return false
    if (g_SCWV_LifecyclePhase = "closing" || g_SCWV_LifecyclePhase = "closed")
        return false
    if (g_SCWV_CurrentPhase = SCWV_PHASE_CLOSED)
        return false
    if !IsObject(g_SCWV_Gui)
        return false
    hwnd := 0
    try hwnd := g_SCWV_Gui.Hwnd
    catch {
    }
    if !hwnd
        return false
    SCWV_PrepareForegroundSteal()
    expr := "ahk_id " . hwnd
    try WinShow(expr)
    catch {
    }
    try {
        ex := WinGetExStyle(expr)
        if (ex & 0x80)
            WinSetExStyle(ex & ~0x80, expr)
    } catch {
    }
    cb := focusCb
    if !IsObject(cb) && IsObject(g_SCWV_Ctrl)
        cb := (*) => WebView2_MoveFocusProgrammatic(g_SCWV_Ctrl)
    rs := String(reason)
    handoffRaise := (InStr(rs, "handoff") > 0 || InStr(rs, "hotkey") > 0 || InStr(rs, "finish_reveal") > 0 || InStr(rs, "show_host") > 0 || InStr(rs, "show_focus") > 0)
    ok := false
    if handoffRaise {
        try ok := SCWV_ForegroundPulse(hwnd)
        catch {
        }
    }
    if !ok {
        if SCWV_FuncExists("LegacyGuard_RequestFocus")
            ok := LegacyGuard_RequestFocus("SearchCenter", hwnd, 60, rs, 900, cb)
        else if SCWV_FuncExists("FocusBroker_Request")
            ok := FocusBroker_Request("SearchCenter", hwnd, 60, rs, 900, cb)
    }
    if !ok {
        try ok := SCWV_ForegroundPulse(hwnd)
        catch {
        }
    }
    if !ok {
        try {
            DllCall("ShowWindow", "Ptr", hwnd, "Int", 9)
            DllCall("SetForegroundWindow", "Ptr", hwnd)
            ok := WinActive(expr)
        } catch {
        }
    }
    if ok && IsObject(cb) {
        try cb.Call()
        catch {
        }
    }
    SCWV_ReleaseForegroundSteal()
    return ok
}

SCWV_ShowHostFullscreen(*) {
    global g_SCWV_Gui, g_SCWV_UserMinimized
    if g_SCWV_UserMinimized || !g_SCWV_Gui
        return
    if SCWV_IsCloseRequested()
        return
    if SCWV_FuncExists("Nmer_EnsureGuiMaximizedOnPopupScreen") {
        try Nmer_EnsureGuiMaximizedOnPopupScreen(g_SCWV_Gui)
        catch {
        }
    } else {
        try Nmer_MoveGuiToPopupScreen(g_SCWV_Gui, true)
        catch {
        }
        try {
            g_SCWV_Gui.Show("Maximize")
        } catch {
            try g_SCWV_Gui.Show()
            catch {
            }
        }
        try SCWV_EnsureMaximized()
        catch {
        }
    }
    try _SCWV_ApplyHostDarkChrome(g_SCWV_Gui.Hwnd)
    catch {
    }
    try SCWV_RaiseToForeground("show_host_fullscreen")
    catch {
    }
}

SCWV_EnsureTaskbarEligible(*) {
    global g_SCWV_Gui
    if !g_SCWV_Gui
        return
    try hwnd := g_SCWV_Gui.Hwnd
    catch {
        return
    }
    if !hwnd
        return
    expr := "ahk_id " . hwnd
    try {
        ex := WinGetExStyle(expr)
        if (ex & 0x80)
            WinSetExStyle(ex & ~0x80, expr)
    } catch {
    }
}

SCWV_FinishReveal() {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_WaitingUiFinishedReveal, g_SCWV_DeferredHostShow, g_SCWV_UserMinimized
    global g_SCWV_ShowWaitStartTick, g_SCWV_ShowRecoveryAttempts, g_SCWV_LastShown, g_SCWV_PendingTriggerSource
    global g_SCWV_Ctrl, g_SCWV_WV2, g_SCWV_CurrentToken
    if SCWV_IsCloseRequested()
        return
    if !SCWV_ShouldRunComposition()
        return
    if !g_SCWV_Gui
        return
    if !SCWV_CanRevealToUser() {
        try SCWV_Log("finish_reveal_defer_not_ready", "waiting=" . (g_SCWV_WaitingUiFinishedReveal ? "1" : "0"))
        return
    }
    try SCWV_Log("finish_reveal_begin", "deferred=" . (g_SCWV_DeferredHostShow ? "1" : "0") . " waiting=" . (g_SCWV_WaitingUiFinishedReveal ? "1" : "0"))
    g_SCWV_DeferredHostShow := false
    try WinSetTransparent(255, "ahk_id " . g_SCWV_Gui.Hwnd)
    catch {
    }
    if g_SCWV_Ctrl {
        try g_SCWV_Ctrl.IsVisible := true
        catch {
        }
    }
    if g_SCWV_UserMinimized {
        SCWV_ApplyBounds()
        g_SCWV_WaitingUiFinishedReveal := false
        g_SCWV_ShowWaitStartTick := 0
        g_SCWV_ShowRecoveryAttempts := 0
        SCWV_StopRevealWatchdog()
        try SCWV_Log("finish_reveal_skip_minimized", "")
        catch {
        }
        return
    }
    try SCWV_ShowHostFullscreen()
    catch {
    }
    SCWV_ApplyBounds()
    SCWV_ScheduleBoundsRetries("finish_reveal")
    g_SCWV_Visible := true
    SCWV_ScheduleCompositionPump("finish_reveal")
    SCWV_PostHostForeground(true)
    g_SCWV_LastShown := A_TickCount
    try WebView2_NotifyShown(g_SCWV_WV2)
    try {
        if WMActivateChain_Count() < 1
            WMActivateChain_Register(SCWV_WM_ACTIVATE)
    } catch {
    }
    ts := Trim(String(g_SCWV_PendingTriggerSource))
    if (ts != "clipboard_hotkey") {
        try SCWV_RaiseToForeground("finish_reveal_focus", (*) => WebView2_MoveFocusProgrammatic(g_SCWV_Ctrl))
        curToken := g_SCWV_CurrentToken
        SetTimer((*) => _SCWV_DeferredMoveFocus100(curToken), -100)
        SetTimer((*) => SCWV_FocusDeferred(curToken), -80)
        SetTimer((*) => SCWV_RaiseToForeground("finish_reveal_reassert"), -180)
        SCWV_RequestFocusInput()
    }
    if (ts = "search_hotkey" || ts = "clipboard_hotkey")
        SCWV_ApplyCapsLockForSearchOpen()
    else
        try CapsLock_ScheduleNormalizeAfterChord()
    try SearchCenter_ScheduleIMEStabilize()
    g_SCWV_WaitingUiFinishedReveal := false
    g_SCWV_AwaitingReshowPaint := false
    g_SCWV_ShowWaitStartTick := 0
    g_SCWV_ShowRecoveryAttempts := 0
    SCWV_StopRevealWatchdog()
    SCWV_EnsureTaskbarEligible()
    SCWV_PushLifecycleState("open", "finish_reveal")
    try SurfaceManager_ObserveShow("search_center", Map("entry", "SCWV_FinishReveal"))
    try SCWV_RaiseToForeground("finish_reveal")
    catch {
    }
    tsReveal := Trim(String(g_SCWV_PendingTriggerSource))
    if (tsReveal = "search_hotkey") {
        SCWV_ApplyCapsLockForSearchOpen()
        SCWV_ScheduleHandoffForegroundRetries()
        SCWV_StartHotkeyForegroundPump(10000)
        if g_SCWV_HostTopMost
            SetTimer((*) => SCWV_SetHostTopMost(false), -1500)
    }
    SetTimer(SCWV_PostHostShow, -90)
    SetTimer((*) => SCWV_RaiseToForeground("finish_reveal_delayed"), -220)
    if (tsReveal != "clipboard_hotkey")
        SCWV_EnsureSearchHomeVisible()
}

SCWV_RevealWatchdogTick(token := 0, *) {
    global g_SCWV_WaitingUiFinishedReveal, g_SCWV_ShowWaitStartTick, g_SCWV_Ready, g_SCWV_UI_Ready
    global g_SCWV_FirstFrameSeen, g_SCWV_PaintReady, g_SCWV_CreateInFlight, g_SCWV_NavProgressTick
    global g_SCWV_LimitedRecoverReloadAttempts, g_SCWV_RevealWatchdogReloadUsed, g_SCWV_WV2

    if (token && !SCWV_IsCurrentToken(token)) {
        SCWV_StopRevealWatchdog()
        return
    }
    if !g_SCWV_WaitingUiFinishedReveal {
        SCWV_StopRevealWatchdog()
        return
    }

    elapsed := (g_SCWV_ShowWaitStartTick > 0) ? (A_TickCount - g_SCWV_ShowWaitStartTick) : 0

    if SCWV_CanRevealToUser() {
        if SCWV_TryFinishReveal("reveal_watchdog")
            SCWV_StopRevealWatchdog()
        else
            _SCWV_ScheduleRevealWatchdogTick(token, 400)
        return
    }

    if (elapsed < 2000) {
        if g_SCWV_Ready && !g_SCWV_PaintReady {
            try SCWV_PostJson(Map("type", "hostPaintNudge"))
            catch {
            }
        }
        _SCWV_ScheduleRevealWatchdogTick(token, 400)
        return
    }

    navGraceMs := 5000
    if (g_SCWV_NavProgressTick > 0 && (A_TickCount - g_SCWV_NavProgressTick) < navGraceMs) {
        _SCWV_ScheduleRevealWatchdogTick(token, 400)
        return
    }

    if (g_SCWV_Ready && !g_SCWV_UI_Ready && !g_SCWV_RevealWatchdogReloadUsed) {
        g_SCWV_RevealWatchdogReloadUsed := true
        g_SCWV_LimitedRecoverReloadAttempts += 1
        try SCWV_Log("watchdog_stage", "stage=reload opening_elapsed=" . elapsed)
        try SCWV_Log("recover_reload", "attempt=" . g_SCWV_LimitedRecoverReloadAttempts)
        try g_SCWV_WV2.Reload()
        catch {
        }
        _SCWV_ScheduleRevealWatchdogTick(token, 800)
        return
    }

    safeWaitMs := 20000
    if g_SCWV_CreateInFlight
        safeWaitMs := 90000
    else if !g_SCWV_Ready
        safeWaitMs := 60000
    else if !g_SCWV_FirstFrameSeen
        safeWaitMs := 45000

    if (elapsed < safeWaitMs) {
        _SCWV_ScheduleRevealWatchdogTick(token, 500)
        return
    }

    if g_SCWV_CreateInFlight && elapsed >= 90000 {
        try SCWV_Log("watchdog_stage", "stage=reinit_create_inflight_timeout elapsed=" . elapsed)
        try SCWV_Log("recover_reinit", "reason=reveal_watchdog_create_inflight")
        try GDHO_RequestClose("scwv_reveal_watchdog_create_timeout")
        SCWV_ForceCloseHost("reveal_watchdog_create_timeout")
        SCWV_StopRevealWatchdog()
        return
    }

    try SCWV_Log("watchdog_stage", "stage=stall_logged elapsed=" . elapsed . " ready=" . (g_SCWV_Ready ? "1" : "0") . " ui=" . (g_SCWV_UI_Ready ? "1" : "0") . " frame=" . (g_SCWV_FirstFrameSeen ? "1" : "0"))

    if g_SCWV_FirstFrameSeen {
        if !g_SCWV_Ready
            _SCWV_BootstrapWebReadyIfStalled("reveal_watchdog_force_stall")
        if !g_SCWV_PaintReady
            g_SCWV_PaintReady := true
        if !g_SCWV_UI_Ready
            g_SCWV_UI_Ready := true
        if SCWV_TryFinishReveal("reveal_watchdog_force_stall") {
            SCWV_StopRevealWatchdog()
            return
        }
    } else if g_SCWV_WV2 && !g_SCWV_RevealWatchdogReloadUsed {
        g_SCWV_RevealWatchdogReloadUsed := true
        g_SCWV_LimitedRecoverReloadAttempts += 1
        try SCWV_Log("recover_reload", "reason=stall_no_frame attempt=" . g_SCWV_LimitedRecoverReloadAttempts)
        try g_SCWV_WV2.Reload()
        catch {
        }
    }

    _SCWV_ScheduleRevealWatchdogTick(token, 1200)
}

SCWV_ForceRevealIfStuck(*) {
    global g_SCWV_CurrentToken
    SCWV_RevealWatchdogTick(g_SCWV_CurrentToken)
}

SCWV_ShowWaitTimeoutCheck(token := 0, *) {
    SCWV_RevealWatchdogTick(token)
}

SCWV_RecoverAfterShowWaitTimeout(token := 0, *) {
    global g_SCWV_ShowRecoveryAttempts
    if (token && !SCWV_IsCurrentToken(token))
        return
    try SCWV_Log("show_wait_recover_disabled", "attempts=" . g_SCWV_ShowRecoveryAttempts)
    g_SCWV_ShowRecoveryAttempts := 0
}

SCWV_ForceCloseHost(reason := "") {
    global g_SCWV_Gui, g_SCWV_Ctrl, g_SCWV_WV2, g_SCWV_Visible, g_SCWV_WaitingUiFinishedReveal
    global g_SCWV_ShowWaitStartTick, g_SCWV_ShowRecoveryAttempts, GuiID_SearchCenter
    global g_SCWV_Ready, g_SCWV_UI_Ready
    global g_SCWV_SearchTimer, g_SCWV_PendingJsonQueue, g_SCWV_DeactivateBlockUntil, g_SCWV_DeactivateBlockReason
    global g_SCWV_CreateInFlight, g_SCWV_CreateStartTick, g_SCWV_LifecyclePhase
    global g_SCWV_AsyncWhr, g_SCWV_AsyncReqMeta, g_SCWV_SearchHttpInFlight, g_SCWV_AsyncPollToken
    global g_SCWV_CurrentToken, g_SCWV_ForceResetStreak, g_SCWV_DegradedMode, g_SCWV_FirstFrameSeen, TrayMenuCustomFailStreak, g_SCWV_BackendHealthy
    global SearchCenterWebKeyword, SearchCenterSearchResults, g_SCWV_AllResultsCache, g_SCWV_AllResultsKeyword
    global SearchCenterHasMoreData, g_SCWV_LastRenderedID, g_SCWV_RequestID, g_SCWV_SearchPendingReq, AppearanceActivationMode
    global g_SCWV_CloseCommitActive, g_SCWV_CloseCommitUntilTick

    SetTimer(SCWV_CreateWatchdogTick, 0)
    try SCWV_Log("force_close_begin", "reason=" . reason . " visible=" . (g_SCWV_Visible ? "1" : "0") . " waiting=" . (g_SCWV_WaitingUiFinishedReveal ? "1" : "0") . " ready=" . (g_SCWV_Ready ? "1" : "0") . " ui_ready=" . (g_SCWV_UI_Ready ? "1" : "0"))
    SCWV_PostHostForeground(false)
    SCWV_PushLifecycleState("closing", reason)
    SCWV_StopForegroundPumps()

    SCWV_StopRevealWatchdog()
    SetTimer(SCWV_RecoverAfterShowWaitTimeout, 0)
    SetTimer(SCWV_WMDeactivateHideTick, 0)
    SetTimer(SCWV_DeferredPush, 0)
    SetTimer(SCWV_RefreshComposition, 0)
    SetTimer(_SCWV_DeferredMoveFocus100, 0)
    SetTimer(SCWV_FocusDeferred, 0)
    SetTimer(SCWV_FlushPendingJsonQueue, 0)
    SetTimer(SCWV_DrainWebMessageQueue, 0)
    global g_SCWV_WebMsgQueue
    g_SCWV_WebMsgQueue := []
    g_SCWV_WebMsgDrainBusy := false
    if g_SCWV_SearchTimer {
        SetTimer(g_SCWV_SearchTimer, 0)
        g_SCWV_SearchTimer := 0
    }
    g_SCWV_WaitingUiFinishedReveal := false
    g_SCWV_CreateInFlight := false
    g_SCWV_CreateStartTick := 0
    g_SCWV_ShowWaitStartTick := 0
    g_SCWV_Visible := false
    g_SCWV_FirstFrameSeen := false
    g_SCWV_PaintReady := false
    g_SCWV_RevealCommitted := false
    g_SCWV_PendingJsonQueue := []
    g_SCWV_CurrentToken += 1
    g_SCWV_AsyncPollToken += 1
    g_SCWV_AsyncWhr := 0
    g_SCWV_AsyncReqMeta := 0
    g_SCWV_SearchPendingReq := 0
    g_SCWV_SearchHttpInFlight := false
    g_SCWV_SearchTimer := 0
    g_SCWV_DeactivateBlockUntil := 0
    g_SCWV_DeactivateBlockReason := ""
    GuiID_SearchCenter := 0
    isRecoveryClose := _SCWV_IsRecoveryCloseReason(reason)
    mode := "toolbar"
    try mode := NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar")
    catch {
        mode := "toolbar"
    }
    if isRecoveryClose {
        g_SCWV_ForceResetStreak += 1
        TrayMenuCustomFailStreak += 1
    } else {
        g_SCWV_ForceResetStreak := 0
        TrayMenuCustomFailStreak := 0
    }
    g_SCWV_BackendHealthy := false
    g_SCWV_LastRenderedID := 0
    g_SCWV_RequestID := 0
    ; 按激活模式区分会话恢复：黑洞模式彻底清空；悬浮栏/托盘模式保留搜索上下文。
    if (mode = "hole") {
        SearchCenterWebKeyword := ""
        SearchCenterSearchResults := []
        g_SCWV_AllResultsCache := []
        g_SCWV_AllResultsKeyword := ""
        SearchCenterHasMoreData := false
    }
    if (isRecoveryClose && g_SCWV_ForceResetStreak >= 3) {
        g_SCWV_DegradedMode := true
        try SCWV_Log("degraded_enter", "reason=" . reason . " streak=" . g_SCWV_ForceResetStreak)
        try TrayTip("搜索中心", "连续恢复失败，已暂停自动重试，请检查环境或重启。", "Iconx 2")
        catch {
        }
    } else if (!isRecoveryClose) {
        g_SCWV_DegradedMode := false
    }

    ; Hard close path must perform the same teardown that SCWV_Hide() normally does.
    ; Otherwise black-hole close buttons can leave dock/session state behind and block later tray opens.
    try SetTimer((*) => NativeDropBridge_ResetSessionAsync("search_center_exit", 0), -1)
    catch as err {
        try SCWV_Log("force_close_error", "reason=" . reason . " step=reset_bridge msg=" . err.Message)
    }
    global g_SCWV_IntentQueue, g_SCWV_CloseAfterReady, g_SCWV_HandoffActive, g_SCWV_HandoffPendingOpen
    g_SCWV_IntentQueue := []
    g_SCWV_CloseAfterReady := false
    g_SCWV_HandoffActive := false
    g_SCWV_HandoffPendingOpen := 0
    SetTimer(SCWV_PumpIntents, 0)
    ; 关闭统一宿主时，unifiedMode 可能已被切回 search，导致仅按当前模式释放会漏掉 clipboard dock。
    ; 为避免悬浮栏长期被抑制，统一兜底：同时释放 search/clipboard 两个 dock 标签。
    try FloatingToolbar_PageDockLeave("clipboard")
    catch as err {
        try SCWV_Log("force_close_error", "reason=" . reason . " step=pagedock_leave_clipboard msg=" . err.Message)
    }
    try FloatingToolbar_PageDockLeave("search")
    catch as err {
        try SCWV_Log("force_close_error", "reason=" . reason . " step=pagedock_leave_search msg=" . err.Message)
    }
    if g_SCWV_SearchTimer {
        try SetTimer(g_SCWV_SearchTimer, 0)
        g_SCWV_SearchTimer := 0
    }
    try SearchCenterInvalidateGuiControlRefs()
    catch {
    }

    try {
        SCWV_Log("wm_chain_unregister_begin", "reason=" . reason . " count=" . WMActivateChain_Count())
        WMActivateChain_Unregister(SCWV_WM_ACTIVATE)
        SCWV_Log("wm_chain_unregister_done", "reason=" . reason . " count=" . WMActivateChain_Count())
    } catch as err {
        try SCWV_Log("wm_chain_unregister_failed", "reason=" . reason . " msg=" . err.Message)
        catch {
        }
    }
    try WebView2_NotifyHidden(g_SCWV_WV2)
    catch {
    }
    try FocusBroker_Release("SearchCenter", reason)
    catch {
    }
    try {
        if g_SCWV_Gui
            g_SCWV_Gui.Destroy()
    } catch as err {
        try SCWV_Log("force_close_error", "reason=" . reason . " msg=" . err.Message)
    }

    SCWV_ResetHostState()
    g_SCWV_CloseCommitActive := false
    g_SCWV_CloseCommitUntilTick := 0
    g_SCWV_CloseInFlight := false
    if (reason != "show_wait_timeout")
        g_SCWV_ShowRecoveryAttempts := 0
    SCWV_NotifyToolbarSearchClosed()
    try SCWV_SetPhase(SCWV_PHASE_CLOSED, "close_commit_" . reason)
    SCWV_PushLifecycleState("closed", reason)
    try SCWV_Log("hide_done", "visible=0 reason=" . reason)
    try SCWV_Log("force_close_done", "reason=" . reason)
}

SCWV_RequestHardClose(reason := "") {
    try SCWV_ForceCloseHost(reason)
    catch as err {
        try SCWV_Log("force_close_error", "reason=" . reason . " msg=" . err.Message)
    }
}

SCWV_Dispose(reason := "") {
    r := String(reason != "" ? reason : "dispose")
    try SCWV_ForceCloseHost(r)
    catch as err {
        try SCWV_Log("dispose_error", "reason=" . r . " msg=" . err.Message)
        try SCWV_RequestHardClose(r)
    }
    try SurfaceManager_ObserveClose("search_center", Map("entry", "SCWV_Dispose", "reason", r))
}

_SCWV_IsRecoveryCloseReason(reason := "") {
    r := StrLower(Trim(String(reason)))
    if (r = "")
        return false
    return (InStr(r, "show_wait_timeout")
        || InStr(r, "show_wait_limited_recover")
        || InStr(r, "stale_wait_timeout")
        || InStr(r, "stale_create_timeout")
        || InStr(r, "webview_create_failed")
        || InStr(r, "anti_hang_")
        || InStr(r, "force_reset"))
}

SearchCenterUnifiedClose(reason := "unknown", preferHardClose := false, PersistSelection := true) {
    global g_SCWV_CloseInFlight, AppearanceActivationMode, g_SCWV_HandoffActive
    if g_SCWV_HandoffActive {
        try SCWV_Log("unified_close_clear_handoff", "reason=" . reason)
        _SCWV_HandoffEnd("unified_close")
    }
    if (g_SCWV_CloseInFlight) {
        try SCWV_Log("unified_close_while_inflight", "reason=" . reason)
        preferHardClose := true
    }
    g_SCWV_CloseInFlight := true
    try {
        mode := "toolbar"
        try mode := NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar")
        catch {
            mode := "toolbar"
        }
        if (mode = "hole")
            preferHardClose := true
        if (preferHardClose) {
            SCWV_ForceCloseHost(reason)
            return true
        }
        if (SearchCenter_ShouldUseWebView()) {
            SCWV_SubmitIntent("close", 30, Map("reason", reason, "persist", PersistSelection ? 1 : 0))
            return true
        }
        global GuiID_SearchCenter
        if (GuiID_SearchCenter != 0) {
            SearchCenterCloseHandler()
            return true
        }
        g_SCWV_CloseInFlight := false
    } catch as err {
        g_SCWV_CloseInFlight := false
        try SCWV_Log("unified_close_error", "reason=" . reason . " msg=" . err.Message)
    }
    return false
}

; WebView 鍐呰仈杈撳叆渚濊禆瀹夸富婵€娲?+ WebView 鍙栫劍锛孖MM/TSF 鎵嶈兘绋冲畾闄勭潃锛堝惁鍒欒〃鐜颁负鏈夋椂涓枃銆佹湁鏃惰嫳鏂囧皬鍐欙級
SCWV_FocusForIME(*) {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_Ctrl, g_SCWV_WV2, g_SCWV_Ready, g_SCWV_CliTerminalFocus
    if g_SCWV_CliTerminalFocus
        return
    if !g_SCWV_Visible || !g_SCWV_Gui || !g_SCWV_Ctrl
        return
    try {
        FocusBroker_Request("SearchCenter", g_SCWV_Gui.Hwnd, 20, "focus_for_ime", 300, (*) => WebView2_MoveFocusProgrammatic(g_SCWV_Ctrl))
        if g_SCWV_Ready && g_SCWV_WV2
            global g_SCWV_SearchInputFocused
            g_SCWV_SearchInputFocused := true
            WebView_QueueJson(g_SCWV_WV2, '{"type":"focus_input"}')
    } catch {
    }
}

SCWV_RefreshComposition(*) {
    if !SCWV_ShouldRunComposition()
        return
    SCWV_CompositionPump("refresh")
}

_SCWV_LoadSearchEngineMode() {
    global SearchCenterEngineMode, ConfigFile
    try {
        m := IniRead(ConfigFile, "Settings", "SearchCenterEngineMode", "go")
        if (m = "ahk" || m = "go")
            SearchCenterEngineMode := m
    } catch {
    }
}

_SCWV_SaveSearchEngineMode(mode) {
    global ConfigFile
    try IniWrite(mode, ConfigFile, "Settings", "SearchCenterEngineMode")
    catch {
    }
}

#Include ScwvSearchCoreBridge.ahk

SCWV_ForceReinitFromTray(*) {
    global g_SCWV_DegradedMode, g_SCWV_ForceResetStreak, g_SCWV_ShowRecoveryAttempts, g_SCWV_ForceReinitRequested
    global g_SCWV_GoStartGen, g_SCWV_GoStartPhase, g_SCWV_GoStartPending
    global g_SCWV_AsyncWhr, g_SCWV_AsyncReqMeta, g_SCWV_SearchHttpInFlight, g_SCWV_SearchPendingReq
    global g_SCWV_CurrentToken, g_SCWV_AsyncPollToken, g_SCWV_IntentQueue, g_SCWV_IntentPumpBusy
    g_SCWV_ForceReinitRequested := true
    ; Full-channel quiesce: silence async chains before scheduling new lifecycle.
    SCWV_StopRevealWatchdog()
    SetTimer(SCWV_RecoverAfterShowWaitTimeout, 0)
    SetTimer(SCWV_WMDeactivateHideTick, 0)
    SetTimer(SCWV_DeferredPush, 0)
    SetTimer(SCWV_RefreshComposition, 0)
    SetTimer(SCWV_FocusDeferred, 0)
    SetTimer(SCWV_FlushPendingJsonQueue, 0)
    SetTimer(SCWV_PumpIntents, 0)
    g_SCWV_CurrentToken += 1
    g_SCWV_AsyncPollToken += 1
    g_SCWV_AsyncWhr := 0
    g_SCWV_AsyncReqMeta := 0
    g_SCWV_SearchHttpInFlight := false
    g_SCWV_SearchPendingReq := 0
    g_SCWV_IntentQueue := []
    g_SCWV_IntentPumpBusy := false
    g_SCWV_DegradedMode := false
    g_SCWV_ForceResetStreak := 0
    g_SCWV_ShowRecoveryAttempts := 0
    g_SCWV_GoStartGen += 1
    g_SCWV_GoStartPhase := "IDLE"
    g_SCWV_GoStartPending := false
    SCWV_SubmitIntent("FORCE_RESET", 1, Map("reason", "manual_force_reinit"))
    SetTimer((*) => _SCWV_RestartSearchCore(), -10)
    SetTimer((*) => SCWV_SubmitIntent("OPEN", 10, Map("reason", "manual_force_reinit")), -180)
    SetTimer((*) => SCWV_ReplayLastSearchIntent("manual_force_reinit"), -260)
}

_SCWV_DefaultFullTextStatusPayload() {
    return Map(
        "running", false,
        "ready", false,
        "initialScanDone", false,
        "progress", 0,
        "progressText", "0.0%",
        "progressDetail", "未开始扫描",
        "efficiencyText", "0 文件/秒",
        "scanPhase", "idle",
        "indexing_file", "",
        "engine_lights", ["off", "off", "off", "off"],
        "discoveredFiles", 0,
        "processedFiles", 0,
        "indexedFiles", 0,
        "pendingTasks", 0,
        "queueCapacity", 0,
        "queueSaturated", false,
        "filesPerSec", 0,
        "etaSeconds", 0,
        "workerCount", 0,
        "scanSpeed", "normal",
        "includeLargeText", false,
        "maxFileSizeMB", 16,
        "indexDir", "",
        "lastError", "",
        "scan_mode", "",
        "indexEpoch", 0,
        "indexVersion", ""
    )
}

; 供 WebView 展示全文命中上下文（HitContext）；键名用小写便于 JS 读取
_SCWV_ResultMetadataForWeb(item) {
    if !IsObject(item) || !item.HasProp("Metadata")
        return 0
    m := item.Metadata
    if !(m is Map)
        return 0
    out := Map()
    if m.Has("HitCount")
        out["hitCount"] := m["HitCount"]
    if m.Has("HitContext") {
        ctx := m["HitContext"]
        if (ctx is Array && ctx.Length > 0) {
            ; 防止超大命中上下文导致 PostWebMessageAsJson 负载过大（单字高频词更易触发）
            ; 仅下发有限条、有限长度摘要；详情可后续按需请求。
            maxRows := 8
            maxSnippetChars := 260
            slim := []
            lim := (ctx.Length < maxRows) ? ctx.Length : maxRows
            Loop lim {
                row := ctx[A_Index]
                lineNo := 0
                snippet := ""
                if (row is Map) {
                    if row.Has("line")
                        lineNo := Integer(row["line"])
                    if row.Has("snippet")
                        snippet := String(row["snippet"])
                } else if IsObject(row) {
                    try lineNo := row.HasProp("line") ? Integer(row.line) : 0
                    try snippet := row.HasProp("snippet") ? String(row.snippet) : ""
                }
                snippet := RegExReplace(snippet, "\s+", " ")
                if (StrLen(snippet) > maxSnippetChars)
                    snippet := SubStr(snippet, 1, maxSnippetChars) . "…"
                snippet := _SCWV_SanitizeForJson(snippet)
                slim.Push(Map("line", lineNo, "snippet", snippet))
            }
            out["hitContext"] := slim
            if (ctx.Length > lim)
                out["hitContextTruncated"] := true
        }
    }
    if m.Has("StreamPhase")
        out["streamPhase"] := m["StreamPhase"]
    if m.Has("FullTextHit")
        out["fullTextHit"] := m["FullTextHit"] ? true : false
    if m.Has("FilePath")
        out["filePath"] := m["FilePath"]
    if (out.Count = 0)
        return 0
    return out
}

; 移除会破坏 JSON/WebMessage 的控制字符（保留 CR/LF/TAB）
_SCWV_SanitizeForJson(val) {
    s := String(val)
    return RegExReplace(s, "[\x00-\x08\x0B\x0C\x0E-\x1F]", " ")
}

_SCWV_MergeMap(target, source) {
    if !(target is Map) || !(source is Map)
        return target
    for k, v in source
        target[k] := v
    return target
}

; 统一从 WinHttp/回退回调的 resp Map 中取出可读错误（避免 text 为空时前端只显示泛化失败）
_SCWV_BootstrapWebReadyIfStalled(reason := "") {
    global g_SCWV_Ready, g_SCWV_FirstFrameSeen, g_SCWV_UI_Ready, g_SCWV_FocusPending, g_SCWV_ReloadRecoveryPending
    global SearchCenterWebKeyword
    if g_SCWV_Ready || !g_SCWV_FirstFrameSeen
        return false
    if SCWV_IsCloseRequested()
        return false
    g_SCWV_Ready := true
    try SCWV_Log("web_ready_bootstrap", "reason=" . String(reason))
    catch {
    }
    _SCWV_HandoffEnd("web_ready_bootstrap")
    SCWV_SetPhase(SCWV_PHASE_OPEN, "web_ready_bootstrap")
    try SCWV_PushThemeToWeb()
    catch {
    }
    if SCWV_IsWebSearchUIMode()
        _SCWV_EnsureDefaultWebEngines(GetSearchCenterCurrentCategoryKey())
    kwReady := Trim(SearchCenterWebKeyword)
    if !SCWV_IsWebSearchUIMode() {
        global g_SCWV_UiMode
        um := StrLower(Trim(String(g_SCWV_UiMode)))
        if (um != "cli") {
            if (kwReady = "")
                _SCWV_ScheduleLocalHomeRefresh(40)
            else
                SCWV_PushState("init")
        } else {
            SCWV_PushState("init")
        }
    } else {
        SCWV_PushState("init")
    }
    _SCWV_SendDockConfig()
    if _SCWV_ShouldPostFullTextStatus()
        SCProvider_FullTextAdmin_MaybePost(true)
    try SCWV_FlushPendingJsonQueue()
    catch {
    }
    if !SCWV_IsWebSearchUIMode() {
        global g_SCWV_UiMode
        um := StrLower(Trim(String(g_SCWV_UiMode)))
        if (um != "cli" && kwReady != "")
            SetTimer(_SCWV_PostRequestSearchGo, -80)
    }
    if g_SCWV_FocusPending
        SCWV_RequestFocusInput()
    if g_SCWV_ReloadRecoveryPending {
        g_SCWV_ReloadRecoveryPending := false
        SetTimer((*) => SCWV_ReplayLastSearchIntent("reload_ready"), -10)
    }
    if !g_SCWV_UI_Ready
        g_SCWV_UI_Ready := true
    SCWV_ScheduleCompositionPump("web_ready_bootstrap")
    return true
}

_SCWV_FormatSearchCoreHttpErr(resp) {
    if !(resp is Map)
        return "SearchCenterCore 无响应"
    errMsg := ""
    if resp.Has("text")
        errMsg := Trim(String(resp["text"]))
    if (errMsg = "" && resp.Has("error"))
        errMsg := Trim(String(resp["error"]))
    if (errMsg = "" && resp.Has("json") && (resp["json"] is Map)) {
        j := resp["json"]
        if j.Has("error")
            errMsg := Trim(String(j["error"]))
        else if j.Has("message")
            errMsg := Trim(String(j["message"]))
    }
    stv := 0
    if resp.Has("status")
        stv := Integer(resp["status"])
    if (errMsg = "") {
        if (stv = 0)
            errMsg := "无法连接 SearchCenterCore（超时、未启动或端口 8080 不可用）"
        else
            errMsg := "HTTP " . String(stv)
    }
    return errMsg
}

_SCWV_PostFullTextStatus(withConfig := false) {
    if !_SCWV_EnsureSearchCoreRunning() {
        if (_SCWV_SearchCoreExePath() != "" && (_SCWV_IsSearchCoreStarting() || !ProcessExist("SearchCenterCore.exe"))) {
            SetTimer((*) => _SCWV_PostFullTextStatus(withConfig), -600)
            return
        }
        ; 核心不可用时勿推送默认 0/0，避免索引区被前端误判为「清空重来」
        return
    }
    payload := Map()
    _SCWV_HttpSearchCoreJsonAsync("GET", "/v1/fulltext/status", "", (stResp) => _SCWV_PostFullTextStatus_AfterStatus(payload, withConfig, stResp))
}

_SCWV_PostFullTextStatus_AfterStatus(payload, withConfig, stResp) {
    if (stResp is Map && stResp.Has("status") && Integer(stResp["status"]) = 200 && stResp.Has("json") && (stResp["json"] is Map))
        payload := _SCWV_MergeMap(payload, stResp["json"])
    _SCWV_HttpSearchCoreJsonAsync("GET", "/v1/fulltext/progress", "", (pgResp) => _SCWV_PostFullTextStatus_AfterProgress(payload, withConfig, pgResp))
}

_SCWV_PostFullTextStatus_AfterProgress(payload, withConfig, pgResp) {
    if (pgResp is Map && pgResp.Has("status") && Integer(pgResp["status"]) = 200 && pgResp.Has("json") && (pgResp["json"] is Map))
        payload := _SCWV_MergeMap(payload, pgResp["json"])
    if withConfig {
        _SCWV_HttpSearchCoreJsonAsync("GET", "/v1/fulltext/config", "", (cfgResp) => _SCWV_PostFullTextStatus_AfterConfig(payload, cfgResp))
        return
    }
    SCWV_PostJson(Map("type", "fulltextStatus", "payload", payload))
}

_SCWV_PostFullTextStatus_AfterConfig(payload, cfgResp) {
    if (cfgResp is Map && cfgResp.Has("status") && Integer(cfgResp["status"]) = 200 && cfgResp.Has("json") && (cfgResp["json"] is Map)) {
        cfgRoot := cfgResp["json"]
        if (cfgRoot.Has("config"))
            payload["config"] := cfgRoot["config"]
        if (cfgRoot.Has("status") && (cfgRoot["status"] is Map))
            payload := _SCWV_MergeMap(payload, cfgRoot["status"])
        if (cfgRoot.Has("progress") && (cfgRoot["progress"] is Map))
            payload := _SCWV_MergeMap(payload, cfgRoot["progress"])
    }
    SCWV_PostJson(Map("type", "fulltextStatus", "payload", payload))
}

_SCWV_ControlFullText(action := "start") {
    act := StrLower(Trim(String(action)))
    if (act = "")
        act := "start"
    if !_SCWV_EnsureSearchCoreRunning() {
        SCWV_PostJson(Map("type", "fulltextActionResult", "ok", false, "action", act, "error", "SearchCenterCore 未启动"))
        _SCWV_PostFullTextStatus(true)
        return
    }
    req := Jxon_Dump(Map("action", act))
    _SCWV_HttpSearchCoreJsonAsync("POST", "/v1/fulltext/control", req, (resp) => _SCWV_ControlFullText_OnResp(act, resp))
}

_SCWV_ControlFullText_OnResp(act, resp) {
    ok := (resp is Map && resp.Has("status") && Integer(resp["status"]) = 200)
    errMsg := ok ? "" : _SCWV_FormatSearchCoreHttpErr(resp)
    SCWV_PostJson(Map("type", "fulltextActionResult", "ok", ok, "action", act, "error", errMsg))
    _SCWV_PostFullTextStatus(true)
}

_SCWV_UpdateFullTextConfig(payloadMap) {
    if !(payloadMap is Map) {
        SCWV_PostJson(Map("type", "fulltextConfigResult", "ok", false, "error", "配置参数无效"))
        return
    }
    if !_SCWV_EnsureSearchCoreRunning() {
        SCWV_PostJson(Map("type", "fulltextConfigResult", "ok", false, "error", "SearchCenterCore 未启动"))
        _SCWV_PostFullTextStatus(true)
        return
    }
    req := Jxon_Dump(payloadMap)
    _SCWV_HttpSearchCoreJsonAsync("POST", "/v1/fulltext/config", req, (resp) => _SCWV_UpdateFullTextConfig_OnResp(payloadMap, req, resp))
}

_SCWV_UpdateFullTextConfig_OnResp(payloadMap, req, resp) {
    ok := (resp is Map && resp.Has("status") && Integer(resp["status"]) = 200)
    errMsg := ok ? "" : _SCWV_FormatSearchCoreHttpErr(resp)
    lowErr := StrLower(errMsg)
    if (!ok && InStr(lowErr, "invalid json body") > 0) {
        reqWrapped := Jxon_Dump(Map("payload", payloadMap))
        _SCWV_HttpSearchCoreJsonAsync("POST", "/v1/fulltext/config", reqWrapped, (resp2) => _SCWV_UpdateFullTextConfig_OnRespWrapped(req, resp2))
        return
    }
    SCWV_PostJson(Map("type", "fulltextConfigResult", "ok", ok, "error", errMsg))
    _SCWV_PostFullTextStatus(true)
}

_SCWV_UpdateFullTextConfig_OnRespWrapped(req, resp2) {
    ok := (resp2 is Map && resp2.Has("status") && Integer(resp2["status"]) = 200)
    errMsg := ok ? "" : _SCWV_FormatSearchCoreHttpErr(resp2)
    SCWV_PostJson(Map("type", "fulltextConfigResult", "ok", ok, "error", errMsg))
    _SCWV_PostFullTextStatus(true)
}

_SCWV_UpdateFullTextConfig_OnRespFinal(resp3) {
    ok := (resp3 is Map && resp3.Has("status") && Integer(resp3["status"]) = 200)
    errMsg := ok ? "" : _SCWV_FormatSearchCoreHttpErr(resp3)
    SCWV_PostJson(Map("type", "fulltextConfigResult", "ok", ok, "error", errMsg))
    _SCWV_PostFullTextStatus(true)
}

_SCWV_ProbeFullTextFeasibility() {
    if !_SCWV_EnsureSearchCoreRunning() {
        SCWV_PostJson(Map("type", "fulltextProbeResult", "ok", false, "error", "SearchCenterCore 未启动", "probe", 0))
        return
    }
    _SCWV_HttpSearchCoreJsonAsync("GET", "/v1/fulltext/probe", "", _SCWV_ProbeFullTextFeasibility_OnResp)
}

_SCWV_ProbeFullTextFeasibility_OnResp(resp) {
    ok := (resp is Map && resp.Has("status") && Integer(resp["status"]) = 200 && resp.Has("json") && (resp["json"] is Map))
    if !ok {
        errMsg := (resp is Map && resp.Has("text")) ? String(resp["text"]) : ("HTTP " . ((resp is Map && resp.Has("status")) ? String(resp["status"]) : "0"))
        SCWV_PostJson(Map("type", "fulltextProbeResult", "ok", false, "error", errMsg, "probe", 0))
        return
    }
    root := resp["json"]
    probe := (root.Has("probe") && (root["probe"] is Map)) ? root["probe"] : root
    SCWV_PostJson(Map("type", "fulltextProbeResult", "ok", true, "error", "", "probe", probe))
}

_SCWV_PickFullTextIndexDir() {
    if !_SCWV_EnsureSearchCoreRunning() {
        SCWV_PostJson(Map("type", "fulltextIndexDirPicked", "ok", false, "error", "SearchCenterCore 未启动", "path", ""))
        return
    }

    defaultDir := Nmer_FullTextIndexDir()
    _SCWV_HttpSearchCoreJsonAsync("GET", "/v1/fulltext/config", "", (cfgResp) => _SCWV_PickFullTextIndexDir_AfterConfig(defaultDir, cfgResp))
}

_SCWV_PickFullTextIndexDir_AfterConfig(defaultDir, cfgResp) {
    try {
        if (cfgResp is Map && cfgResp.Has("status") && Integer(cfgResp["status"]) = 200 && cfgResp.Has("json") && (cfgResp["json"] is Map)) {
            root := cfgResp["json"]
            if (root.Has("config") && (root["config"] is Map)) {
                cfg := root["config"]
                if (cfg.Has("indexDir")) {
                    idx := Trim(String(cfg["indexDir"]))
                    if (idx != "")
                        defaultDir := idx
                }
            }
        }
    } catch {
    }
    hostHwnd := 0
    hostExpr := ""
    wasTop := false
    try {
        global g_SCWV_Gui, GuiID_SearchCenter
        if IsSet(g_SCWV_Gui) && (g_SCWV_Gui != 0)
            hostHwnd := g_SCWV_Gui.Hwnd
        if (!hostHwnd && IsSet(GuiID_SearchCenter) && GuiID_SearchCenter)
            hostHwnd := Integer(GuiID_SearchCenter)
        if (hostHwnd) {
            hostExpr := "ahk_id " . hostHwnd
            exStyle := WinGetExStyle(hostExpr)
            wasTop := (exStyle & 0x8) ? true : false  ; WS_EX_TOPMOST
            if (wasTop)
                WinSetAlwaysOnTop(false, hostExpr)
        }
    } catch {
    }

    picked := ""
    try picked := FileSelect("D", defaultDir, "选择全文索引目录")
    catch as e {
        try {
            if (wasTop && hostExpr != "") {
                WinSetAlwaysOnTop(true, hostExpr)
                FocusBroker_Request("SearchCenter", hostHwnd, 20, "index_dir_pick_restore", 300)
            }
        } catch {
        }
        SCWV_PostJson(Map("type", "fulltextIndexDirPicked", "ok", false, "error", e.Message, "path", ""))
        return
    }
    try {
        if (wasTop && hostExpr != "") {
            WinSetAlwaysOnTop(true, hostExpr)
            FocusBroker_Request("SearchCenter", hostHwnd, 20, "index_dir_pick_restore", 300)
        }
    } catch {
    }
    picked := Trim(String(picked))
    if (picked = "") {
        SCWV_PostJson(Map("type", "fulltextIndexDirPicked", "ok", false, "error", "已取消", "path", ""))
        return
    }
    SCWV_PostJson(Map("type", "fulltextIndexDirPicked", "ok", true, "error", "", "path", picked))
}

_SCWV_MapScBindingToVkCommand(group, value) {
    gp := StrLower(Trim(String(group)))
    vv := Trim(String(value))
    vlow := StrLower(vv)
    if (gp = "category" && vv != "")
        return "sc_cat_" . vv
    if (gp = "engine" && vv != "")
        return "sc_eng_" . vv
    if (gp != "filter")
        return ""
    switch vlow {
        case "file", "text":
            return "sc_filter_text"
        case "fulltext":
            return "sc_filter_fulltext"
        case "clipboard":
            return "sc_filter_clipboard"
        case "template", "prompt":
            return "sc_filter_prompt"
        case "config":
            return "sc_filter_config"
        case "hotkey":
            return "sc_filter_hotkey"
        case "function", "func":
            return "sc_filter_function"
        case "pinned", "pin":
            return "sc_filter_pinned"
    }
    return ""
}

_SCWV_IsScVkCommandId(cmdId) {
    cid := String(cmdId)
    p7 := SubStr(cid, 1, 7)
    p10 := SubStr(cid, 1, 10)
    return (p7 = "sc_cat_" || p7 = "sc_eng_" || p10 = "sc_filter_")
}

_SCWV_ListAllScVkCommands() {
    global g_Commands
    out := []
    if !(g_Commands is Map)
        return out
    if !g_Commands.Has("CommandList") || !(g_Commands["CommandList"] is Map)
        return out
    for cid, _ in g_Commands["CommandList"] {
        if _SCWV_IsScVkCommandId(cid)
            out.Push(String(cid))
    }
    return out
}

_SCWV_CopyMap(src) {
    dst := Map()
    if !(src is Map)
        return dst
    for k, v in src
        dst[k] := v
    return dst
}

_SCWV_MapEquals(a, b) {
    if !(a is Map) || !(b is Map)
        return false
    if (a.Count != b.Count)
        return false
    for k, v in a {
        if !b.Has(k)
            return false
        if String(b[k]) != String(v)
            return false
    }
    return true
}

_SCWV_ClearScVkBindingOverrides() {
    global g_Commands
    if !(g_Commands is Map)
        return
    if !g_Commands.Has("Bindings") || !(g_Commands["Bindings"] is Map)
        return
    if !IsSet(_VK_ApplyOverrides)
        return
    oldOverrides := g_Commands["Bindings"]
    newOverrides := Map()
    changed := false
    for k, v in oldOverrides {
        if _SCWV_IsScVkCommandId(k) {
            changed := true
            continue
        }
        newOverrides[k] := v
    }
    if !changed
        return
    try _VK_ApplyOverrides(newOverrides)
    catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
}

_SCWV_SyncScHotkeyBindings(payloadMap) {
    ; 已停用：搜索中心单键不再写入 VK 全局 g_Bindings，并清理历史 sc_* 覆盖项
    _SCWV_ClearScVkBindingOverrides()
}

; 将 Go 返回的扁平 items 按 originalDataType 分组为 SearchAllDataSources 形状
_SCWV_GroupGoItemsToAllDataResults(GoItems, hasMoreGo) {
    buckets := Map()
    for _, it in GoItems {
        od := "clipboard"
        if (it is Map) {
            if it.Has("originalDataType")
                od := String(it["originalDataType"])
            else if it.Has("OriginalDataType")
                od := String(it["OriginalDataType"])
        }
        if !buckets.Has(od)
            buckets[od] := []
        arr := buckets[od]
        arr.Push(it)
        buckets[od] := arr
    }
    AllDataResults := Map()
    for od, arr in buckets {
        dn := GetDataTypeName(od)
        if (od = "fulltext")
            dn := "全文搜索"
        AllDataResults[od] := { DataType: od, DataTypeName: dn, Items: arr, HasMore: hasMoreGo }
    }
    return AllDataResults
}

_SCWV_ShowSearchCoreError(reason) {
    try TrayTip("搜索中心", reason, "Iconx 2")
    catch {
    }
    try OutputDebug("[SCWV] " . reason)
    _SCWV_LogRuntime("SearchCoreError: " . reason)
}

_SCWV_ShowSearchCoreErrorSilent(reason) {
    try OutputDebug("[SCWV] " . reason)
    _SCWV_LogRuntime("SearchCoreError: " . reason)
}

_SCWV_ShouldToastHttp0() {
    global g_SCWV_LastHttp0ToastTick
    nowTick := A_TickCount
    lastTick := (IsSet(g_SCWV_LastHttp0ToastTick) ? Integer(g_SCWV_LastHttp0ToastTick) : 0)
    if ((nowTick - lastTick) < 12000)
        return false
    g_SCWV_LastHttp0ToastTick := nowTick
    return true
}

_SCWV_ShowHttp0Notice() {
    msg := "SearchCenterCore 瞬时不可用（HTTP 0），已保留当前结果"
    if _SCWV_ShouldToastHttp0()
        _SCWV_ShowSearchCoreError(msg)
    else
        _SCWV_ShowSearchCoreErrorSilent(msg)
}

_SCWV_LogRuntime(msg) {
    try {
        logDir := A_ScriptDir . "\cache"
        if !DirExist(logDir)
            DirCreate(logDir)
        ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        FileAppend("[" . ts . "] " . String(msg) . "`r`n", logDir . "\searchcenter_webview_runtime.log", "UTF-8")
    } catch {
    }
}

_SCWV_SetPendingGoSearch(offset, keyword, goType, limit, clientQueryID := 0, retryCount := 0, delayMs := 10) {
    global g_SCWV_SearchPendingReq, g_SCWV_SearchPendingDelayMs
    g_SCWV_SearchPendingReq := Map(
        "offset", Integer(offset),
        "keyword", String(keyword),
        "goType", String(goType),
        "limit", Integer(limit),
        "clientQueryID", Integer(clientQueryID),
        "retryCount", Integer(retryCount)
    )
    g_SCWV_SearchPendingDelayMs := Max(10, Integer(delayMs))
}

_SCWV_AdoptClientQueryID(msg := 0) {
    global g_SCWV_ActiveClientQueryID
    incoming := 0
    if (msg is Map && msg.Has("queryId"))
        incoming := Integer(msg["queryId"])
    if (incoming > 0) {
        g_SCWV_ActiveClientQueryID := Max(g_SCWV_ActiveClientQueryID, incoming)
        return g_SCWV_ActiveClientQueryID
    }
    g_SCWV_ActiveClientQueryID += 1
    return g_SCWV_ActiveClientQueryID
}

_SCWV_CacheAllResults(keyword) {
    global SearchCenterSearchResults, g_SCWV_AllResultsCache, g_SCWV_AllResultsKeyword
    g_SCWV_AllResultsKeyword := String(keyword)
    g_SCWV_AllResultsCache := []
    if !(SearchCenterSearchResults is Array)
        return
    for _, item in SearchCenterSearchResults
        g_SCWV_AllResultsCache.Push(item)
}

_SCWV_RestoreAllResultsCache(keyword) {
    global SearchCenterSearchResults, g_SCWV_AllResultsCache, g_SCWV_AllResultsKeyword
    if !(g_SCWV_AllResultsCache is Array)
        return false
    if (String(g_SCWV_AllResultsKeyword) != String(keyword))
        return false
    SearchCenterSearchResults := []
    for _, item in g_SCWV_AllResultsCache
        SearchCenterSearchResults.Push(item)
    return (SearchCenterSearchResults.Length > 0)
}

_SCWV_RunPendingGoSearch(*) {
    global g_SCWV_SearchPendingReq, g_SCWV_SearchPendingDelayMs
    if !(g_SCWV_SearchPendingReq is Map)
        return
    req := g_SCWV_SearchPendingReq
    g_SCWV_SearchPendingReq := 0
    g_SCWV_SearchPendingDelayMs := 10
    _SCWV_ExecuteGoSearchHttp(req["offset"], req["keyword"], req["goType"], req["limit"], req["clientQueryID"], req["retryCount"])
}

SCWV_RecordLastSearchIntent(offset, keyword, goType, limit) {
    global g_SCWV_LastSearchIntent, g_SCWV_CurrentToken, g_SCWV_GoStartGen, g_SCWV_ParentTxnID
    kw := Trim(String(keyword))
    if (kw = "")
        return
    g_SCWV_LastSearchIntent := Map("offset", Integer(offset), "keyword", kw, "goType", String(goType), "limit", Integer(limit), "token", Integer(g_SCWV_CurrentToken), "searchToken", Integer(SCWV_GetChannelToken("search")), "parentTxn", Integer(g_SCWV_ParentTxnID), "gen", Integer(g_SCWV_GoStartGen), "tick", A_TickCount)
}

SCWV_ReplayLastSearchIntent(reason := "") {
    global g_SCWV_LastSearchIntent, g_SCWV_DegradedMode, g_SCWV_CurrentToken, g_SCWV_GoStartGen
    if g_SCWV_DegradedMode
        return false
    if !(g_SCWV_LastSearchIntent is Map)
        return false
    it := g_SCWV_LastSearchIntent
    if (Trim(String(it["keyword"])) = "")
        return false
    ; Re-sample latest token/gen at replay time and add a tiny stabilization delay.
    curToken := g_SCWV_CurrentToken
    curGen := g_SCWV_GoStartGen
    SetTimer((*) => SCWV_ReplayLastSearchIntentDelayed(curToken, curGen, it, reason), -50)
    return true
}

SCWV_ReplayLastSearchIntentDelayed(token, gen, intentObj, reason := "", *) {
    global g_SCWV_CurrentToken, g_SCWV_GoStartGen, g_SCWV_DegradedMode
    if g_SCWV_DegradedMode
        return
    if (Integer(token) != Integer(g_SCWV_CurrentToken))
        return
    if (intentObj.Has("searchToken") && !SCWV_IsCurrentChannelToken("search", Integer(intentObj["searchToken"]), intentObj.Has("parentTxn") ? Integer(intentObj["parentTxn"]) : 0))
        return
    if (Integer(gen) != Integer(g_SCWV_GoStartGen))
        return
    if !(intentObj is Map)
        return
    try SCWV_Log("replay_last_search_intent", "reason=" . reason . " kw=" . intentObj["keyword"] . " token=" . token . " gen=" . gen)
    _SCWV_ExecuteGoSearchHttp(intentObj["offset"], intentObj["keyword"], intentObj["goType"], intentObj["limit"])
}

_SCWV_ProcessGoSearchResponse(resp, kw, off, gt, lim) {
    global SearchCenterFilterType
    gtUse := Trim(String(gt))
    if (gtUse = "")
        gtUse := _SCWV_MapFilterToGoSearchType(SearchCenterFilterType)
    st := resp.Has("status") ? Integer(resp["status"]) : 0
    if (st != 200) {
        if ((gtUse = "clipboard" || SearchCenterFilterType = "clipboard")
            && _SCWV_ApplyClipboardTimelineLocal(kw, off, lim > 0 ? lim : 0))
            return
        if (st = 0) {
            if ((gtUse = "clipboard" || SearchCenterFilterType = "clipboard")
                && _SCWV_ApplyClipboardTimelineLocal(kw, off, lim > 0 ? lim : 0))
                return
            _SCWV_LogRuntime("SearchCore HTTP 0 fast-fail")
            _SCWV_EnsureSearchCoreRunning()
            _SCWV_ShowHttp0Notice()
            if SCWV_FuncExists("CommandPalette_OnSharedGoSearchFailed") {
                try CommandPalette_OnSharedGoSearchFailed(kw, "SearchCenterCore 未响应，正在尝试启动…")
                catch {
                }
            }
            return
        } else {
            global SearchCenterSearchResults, SearchCenterHasMoreData
            SearchCenterSearchResults := []
            SearchCenterHasMoreData := false
            errMsg := "SearchCenterCore 请求失败 HTTP " . st
            _SCWV_ShowSearchCoreError(errMsg)
            if SCWV_FuncExists("CommandPalette_OnSharedGoSearchFailed") {
                try CommandPalette_OnSharedGoSearchFailed(kw, errMsg)
                catch {
                }
            }
            SCWV_PushState("state")
            return
        }
    }
    body := resp.Has("body") ? resp["body"] : ""
    if (body = "") {
        global SearchCenterSearchResults, SearchCenterHasMoreData
        SearchCenterSearchResults := []
        SearchCenterHasMoreData := false
        errMsg := "SearchCenterCore 返回空响应"
        _SCWV_ShowSearchCoreError(errMsg)
        if SCWV_FuncExists("CommandPalette_OnSharedGoSearchFailed") {
            try CommandPalette_OnSharedGoSearchFailed(kw, errMsg)
            catch {
            }
        }
        SCWV_PushState("state")
        return
    }
    maxBodyChars := 20971520
    if (StrLen(body) > maxBodyChars) {
        if (off = 0 && lim > 50) {
            _SCWV_LogRuntime("SearchCore body too large, retry with limit=50, len=" . StrLen(body))
            _SCWV_ExecuteGoSearchHttp(off, kw, gt, 50)
            return
        }
        _SCWV_ShowSearchCoreError("SearchCenterCore 返回体过大（>" . Round(maxBodyChars / 1048576) . "MB），请缩小范围")
        return
    }
    try data := Jxon_Load(body)
    catch as e {
        global SearchCenterSearchResults, SearchCenterHasMoreData
        SearchCenterSearchResults := []
        SearchCenterHasMoreData := false
        errMsg := "SearchCenterCore JSON 解析失败: " . e.Message
        _SCWV_ShowSearchCoreError(errMsg)
        if SCWV_FuncExists("CommandPalette_OnSharedGoSearchFailed") {
            try CommandPalette_OnSharedGoSearchFailed(kw, errMsg)
            catch {
            }
        }
        SCWV_PushState("state")
        return
    }
    if !(data is Map) {
        global SearchCenterSearchResults, SearchCenterHasMoreData
        SearchCenterSearchResults := []
        SearchCenterHasMoreData := false
        errMsg := "SearchCenterCore 响应格式无效"
        _SCWV_ShowSearchCoreError(errMsg)
        if SCWV_FuncExists("CommandPalette_OnSharedGoSearchFailed") {
            try CommandPalette_OnSharedGoSearchFailed(kw, errMsg)
            catch {
            }
        }
        SCWV_PushState("state")
        return
    }
    itemsRaw := []
    if (data.Has("items"))
        itemsRaw := data["items"]
    else if (data.Has("Items"))
        itemsRaw := data["Items"]
    GoItems := []
    if (itemsRaw is Array) {
        for _, it in itemsRaw
            GoItems.Push(it)
    }
    hasMore := false
    if (data.Has("hasMore"))
        hasMore := data["hasMore"] ? true : false
    else if (data.Has("HasMore"))
        hasMore := data["HasMore"] ? true : false
    if (GoItems.Length = 0 && (gtUse = "clipboard" || SearchCenterFilterType = "clipboard")) {
        if _SCWV_ApplyClipboardTimelineLocal(kw, off, lim > 0 ? lim : 0)
            return
    }
    _SCWV_ApplySearchResultSync(kw, off, hasMore, GoItems, gt)
    if SCWV_FuncExists("CommandPalette_OnSharedGoSearchResponse") {
        try CommandPalette_OnSharedGoSearchResponse(kw, GoItems, lim)
        catch {
        }
    }
    SCWV_PushState("state")
}

_SCWV_HandleSearchResponse(token, reqID, resp, kw, off, gt, lim, searchToken := 0, parentTxn := 0, clientQueryID := 0) {
    global g_SCWV_LastRenderedID, g_SCWV_ForceResetStreak, g_SCWV_DegradedMode, TrayMenuCustomFailStreak, g_SCWV_BackendHealthy
    global g_SCWV_ActiveClientQueryID
    if (token && !SCWV_IsCurrentToken(token))
        return false
    if (searchToken && !SCWV_IsCurrentChannelToken("search", searchToken, parentTxn))
        return false
    if (clientQueryID && clientQueryID != g_SCWV_ActiveClientQueryID)
        return false
    if (reqID < g_SCWV_LastRenderedID)
        return false
    _SCWV_ProcessGoSearchResponse(resp, kw, off, gt, lim)
    if (resp.Has("status") && Integer(resp["status"]) = 200) {
        g_SCWV_BackendHealthy := true
    }
    if g_SCWV_BackendHealthy {
        g_SCWV_ForceResetStreak := 0
        g_SCWV_DegradedMode := false
        TrayMenuCustomFailStreak := 0
    }
    g_SCWV_LastRenderedID := reqID
    return true
}

; 由宿主发起 WinHttp 访问本机 Go，避免 https://app.local 页面 fetch http 被混合内容拦截
_SCWV_ExecuteGoSearchHttp(offset := 0, keyword := "", goType := "", limit := 0, clientQueryID := 0, retryCount := 0) {
    global SearchCenterWebKeyword, SearchCenterCurrentLimit, SearchCenterFilterType
    global g_SCWV_SearchHttpInFlight, g_SCWV_SearchPendingReq
    global g_SCWV_RequestID, g_SCWV_LastRenderedID, g_SCWV_AsyncWhr, g_SCWV_AsyncReqMeta, g_SCWV_CurrentToken, g_SCWV_AsyncPollToken, g_SCWV_DegradedMode, g_SCWV_ParentTxnID
    global g_SCWV_ActiveClientQueryID
    if g_SCWV_DegradedMode
        return

    kw := Trim(String(keyword))
    if (kw = "")
        kw := Trim(SearchCenterWebKeyword)

    gt := Trim(String(goType))
    if (gt = "")
        gt := _SCWV_MapFilterToGoSearchType(SearchCenterFilterType)

    lim := Integer(limit)
    if (lim <= 0)
        lim := SearchCenterCurrentLimit
    if (lim <= 0)
        lim := 30

    off := Integer(offset)
    if (off < 0)
        off := 0
    cqid := Integer(clientQueryID)
    if (cqid <= 0)
        cqid := g_SCWV_ActiveClientQueryID
    retry := Max(0, Integer(retryCount))

    if g_SCWV_SearchHttpInFlight {
        _SCWV_SetPendingGoSearch(off, kw, gt, lim, cqid, retry)
        return
    }
    if FuncExists("Nmer_Telemetry_Record") {
        try Nmer_Telemetry_Record("search", "search_center_query", true, Map("source", "_SCWV_ExecuteGoSearchHttp"))
    }

    reqID := g_SCWV_RequestID + 1
    g_SCWV_RequestID := reqID
    searchToken := SCWV_BumpChannelToken("search")
    SCWV_RecordLastSearchIntent(off, kw, gt, lim)
    _SCWV_BlockDeactivate(2500, "search_http")
    try {
        if !_SCWV_EnsureSearchCoreRunning() {
            global SearchCenterSearchResults, SearchCenterHasMoreData
            SearchCenterSearchResults := []
            SearchCenterHasMoreData := false
            _SCWV_ShowSearchCoreError("SearchCenterCore 未找到（请检查 tools\\search\\SearchCenterCore.exe）")
            SCWV_PushState("state")
            return
        }
        if !ProcessExist("SearchCenterCore.exe") {
            _SCWV_SetPendingGoSearch(off, kw, gt, lim, cqid, retry, 350)
            return
        }

        encQ := kw
        try encQ := UriEncode(kw)
        catch {
        }

        q := "q=" . encQ . "&type=" . gt . "&limit=" . lim . "&offset=" . off
        url := "http://127.0.0.1:8080/search?" . q
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        if SCWV_FuncExists("NiumaOllama_IsLoopbackUrl") && NiumaOllama_IsLoopbackUrl(url)
            try whr.SetProxy(1)
        whr.Open("GET", url, true)
        whr.SetTimeouts(900, 900, 2200, 2200)
        whr.Send()
        g_SCWV_AsyncWhr := whr
        g_SCWV_AsyncReqMeta := Map("reqID", reqID, "kw", kw, "off", off, "gt", gt, "lim", lim, "startTick", A_TickCount, "token", g_SCWV_CurrentToken, "searchToken", searchToken, "parentTxn", g_SCWV_ParentTxnID, "gen", g_SCWV_GoStartGen, "clientQueryID", cqid, "retryCount", retry)
        g_SCWV_SearchHttpInFlight := true
        g_SCWV_AsyncPollToken += 1
        pollToken := g_SCWV_AsyncPollToken
        SetTimer((*) => _SCWV_AsyncPollSearchHttp(pollToken), 20)
    } catch as err {
        _SCWV_LogRuntime("ExecuteGoSearchHttp exception: " . err.Message)
    }
}

_SCWV_AsyncPollSearchHttp_FinishInFlight(*) {
    global g_SCWV_AsyncWhr, g_SCWV_AsyncReqMeta, g_SCWV_SearchHttpInFlight, g_SCWV_AsyncPollToken, g_SCWV_SearchPendingReq, g_SCWV_SearchPendingDelayMs
    g_SCWV_AsyncPollToken += 1
    g_SCWV_AsyncWhr := 0
    g_SCWV_AsyncReqMeta := 0
    g_SCWV_SearchHttpInFlight := false
    if (g_SCWV_SearchPendingReq is Map)
        SetTimer(_SCWV_RunPendingGoSearch, -Max(10, Integer(g_SCWV_SearchPendingDelayMs)))
}

_SCWV_RequeueColdStartSearch(meta, reason := "") {
    global g_SCWV_ActiveClientQueryID
    if !(meta is Map)
        return false
    cqid := meta.Has("clientQueryID") ? Integer(meta["clientQueryID"]) : 0
    if (cqid && cqid != g_SCWV_ActiveClientQueryID)
        return false
    retry := meta.Has("retryCount") ? Integer(meta["retryCount"]) : 0
    if (retry >= 8)
        return false
    delayMs := Min(1800, 220 * (retry + 1))
    _SCWV_SetPendingGoSearch(meta["off"], meta["kw"], meta["gt"], meta["lim"], cqid, retry + 1, delayMs)
    try SCWV_Log("search_core_cold_retry", "reason=" . reason . " retry=" . (retry + 1) . " delay=" . delayMs . " qid=" . cqid)
    return true
}

_SCWV_AsyncPollSearchHttp(pollToken := 0, *) {
    global g_SCWV_AsyncWhr, g_SCWV_AsyncReqMeta, g_SCWV_SearchHttpInFlight
    global g_SCWV_LastRenderedID, g_SCWV_SearchPendingReq, g_SCWV_AsyncPollToken, g_SCWV_GoStartGen
    if (pollToken && pollToken != g_SCWV_AsyncPollToken)
        return
    if !IsObject(g_SCWV_AsyncWhr) || !(g_SCWV_AsyncReqMeta is Map) {
        try SetTimer((*) => _SCWV_AsyncPollSearchHttp(pollToken), 0)
        g_SCWV_SearchHttpInFlight := false
        return
    }
    whr := g_SCWV_AsyncWhr
    meta := g_SCWV_AsyncReqMeta
    startTick := meta.Has("startTick") ? Integer(meta["startTick"]) : A_TickCount
    if (A_TickCount - startTick > 60000) {
        try whr.Abort()
        try SetTimer((*) => _SCWV_AsyncPollSearchHttp(pollToken), 0)
        _SCWV_LogRuntime("AsyncPollSearchHttp client_timeout")
        _SCWV_AsyncPollSearchHttp_FinishInFlight()
        return
    }
    pr := _SCWV_WinHttpAsyncPollResponseReady(whr)
    if pr["fatal"] {
        try SetTimer((*) => _SCWV_AsyncPollSearchHttp(pollToken), 0)
        _SCWV_LogRuntime("AsyncPollSearchHttp WaitForResponse: " . pr["err"])
        _SCWV_RequeueColdStartSearch(meta, "wait_fatal")
        _SCWV_AsyncPollSearchHttp_FinishInFlight()
        return
    }
    if !pr["ready"]
        return
    try SetTimer((*) => _SCWV_AsyncPollSearchHttp(pollToken), 0)
    try {
        st := 0
        try st := Integer(whr.Status)
        raw := _SCWV_WinHttpReadUtf8Text(whr)
        reqID := Integer(meta["reqID"])
        token := meta.Has("token") ? Integer(meta["token"]) : 0
        gen := meta.Has("gen") ? Integer(meta["gen"]) : 0
        if (gen != Integer(g_SCWV_GoStartGen)) {
            kwDrop := meta.Has("kw") ? String(meta["kw"]) : ""
            if (kwDrop != "" && SCWV_FuncExists("CommandPalette_OnSharedGoSearchFailed")) {
                try CommandPalette_OnSharedGoSearchFailed(kwDrop, "搜索已取消（内核重启）")
                catch {
                }
            }
            _SCWV_AsyncPollSearchHttp_FinishInFlight()
            return
        }
        resp := Map("status", st, "body", (st = 200) ? raw : "", "responseText", raw)
        if (st = 0 && _SCWV_RequeueColdStartSearch(meta, "http_0")) {
            _SCWV_AsyncPollSearchHttp_FinishInFlight()
            return
        }
        searchToken := meta.Has("searchToken") ? Integer(meta["searchToken"]) : 0
        parentTxn := meta.Has("parentTxn") ? Integer(meta["parentTxn"]) : 0
        clientQueryID := meta.Has("clientQueryID") ? Integer(meta["clientQueryID"]) : 0
        _SCWV_HandleSearchResponse(token, reqID, resp, meta["kw"], meta["off"], meta["gt"], meta["lim"], searchToken, parentTxn, clientQueryID)
    } catch as err {
        _SCWV_LogRuntime("AsyncPollSearchHttp error: " . err.Message)
    }
    _SCWV_AsyncPollSearchHttp_FinishInFlight()
}

_SCWV_PostRequestSearchGo(*) {
    global SearchCenterEngineMode, SearchCenterWebKeyword, g_SCWV_ModeSwitchGuard, SearchCenterFilterType
    if g_SCWV_ModeSwitchGuard {
        SetTimer(_SCWV_PostRequestSearchGo, -90)
        return
    }
    kw := Trim(SearchCenterWebKeyword)
    if (kw = "") {
        _SCWV_RefreshLocalHomeView()
        return
    }
    SCProvider_RouteSearch(SCProvider_BuildCtx(kw, 0, 0, SearchCenterFilterType, SearchCenterEngineMode))
}

_SCWV_ResultItemHas(Item, Prop) {
    if (Item is Map)
        return Item.Has(Prop)
    try return Item.HasProp(Prop)
    catch {
        return false
    }
}

_SCWV_ResultItemGet(Item, Prop, Default := "") {
    if (Item is Map)
        return Item.Has(Prop) ? Item[Prop] : Default
    try return Item.HasProp(Prop) ? Item.%Prop% : Default
    catch {
        return Default
    }
}

SCWV_PreemptPrimaryConflictsBeforeOpen(reason := "") {
    needsPreempt := false
    if SCWV_FuncExists("CommandPalette_IsVisible") && CommandPalette_IsVisible()
        needsPreempt := true
    else if SCWV_FuncExists("SurfaceManager_HasActivePrimaryConflict") && SurfaceManager_HasActivePrimaryConflict("search_center")
        needsPreempt := true
    if !needsPreempt
        return
    try SCWV_Log("preempt_primary_conflict", "reason=" . reason)
    catch {
    }
    if SCWV_FuncExists("SurfaceIntent_PreemptCommandPaletteForSearch")
        SurfaceIntent_PreemptCommandPaletteForSearch()
    else if SCWV_FuncExists("CommandPalette_Hide")
        CommandPalette_Hide()
}

SCWV_Show(reason := "", triggerSource := "") {
    reqId := SurfaceManager_Request("search_center", "open", "SCWV_Show", Map("reason", reason, "triggerSource", triggerSource))
    try SurfaceManager_BeforeOpen("search_center", "SCWV_Show", Map("requestId", reqId, "reason", reason, "triggerSource", triggerSource))
    try SurfaceManager_RegisterSurface("search_center")
    if FuncExists("Nmer_Telemetry_MarkSurfaceOpen") {
        try Nmer_Telemetry_MarkSurfaceOpen("search_center", Map("source", "SCWV_Show"))
        catch as _e {
            NmerCatch(A_ThisFunc, _e)
        }
    }
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_Ready, g_SCWV_UI_Ready, g_SCWV_FirstFrameSeen, g_SCWV_WaitingUiFinishedReveal, g_SCWV_Ctrl, g_SCWV_WV2, GuiID_SearchCenter, g_SCWV_LastShown, SearchCenterWebKeyword
    global g_SCWV_ShowWaitStartTick, g_SCWV_ShowRecoveryAttempts
    global SearchCenterEngineMode, g_SCWV_LifecyclePhase, g_SCWV_TransitionCtx, g_SCWV_LimitedRecoverReloadAttempts, g_SCWV_CurrentToken
    global g_SCWV_PendingTriggerSource, SearchCenterFilterType, SearchCenterCurrentLimit
    global g_SCWV_PaintReady, g_SCWV_AwaitingReshowPaint, g_SCWV_UserMinimized, g_SCWV_CloseInFlight
    ts := Trim(String(triggerSource))
    if (ts = "")
        ts := Trim(String(g_SCWV_PendingTriggerSource))
    if (ts != "")
        g_SCWV_PendingTriggerSource := ts
    if !(g_SCWV_TransitionCtx is Map) || !g_SCWV_TransitionCtx["allow"] {
        try SCWV_Log("show_redirect_intent", "reason=" . reason)
        try SurfaceManager_ObserveInit("search_center", Map("entry", "SCWV_Show", "redirect", "intent", "reason", reason, "requestId", reqId))
        redir := Map("reason", reason != "" ? reason : "show_redirect", "initialMode", SCWV_GetUnifiedMode(), "triggerSource", ts)
        SCWV_SubmitIntent("open", 25, redir)
        return
    }
    try SCWV_PreemptPrimaryConflictsBeforeOpen(reason != "" ? reason : "show")
    catch {
    }
    try _SCWV_ClearScVkBindingOverrides()
    catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
    if (ts = "search_hotkey")
        SCWV_PrepareForegroundSteal()
    warmHost := SCWV_HostAlive() && g_SCWV_Gui && g_SCWV_WV2 && g_SCWV_Ready
    if warmHost && g_SCWV_UI_Ready && !g_SCWV_FirstFrameSeen
        g_SCWV_FirstFrameSeen := true
    if warmHost && g_SCWV_Ready && !g_SCWV_UI_Ready
        g_SCWV_UI_Ready := true
    if warmHost && g_SCWV_Ready && !g_SCWV_PaintReady
        g_SCWV_PaintReady := true
    if SCWV_HostAlive() && g_SCWV_WV2 {
        if g_SCWV_AwaitingReshowPaint {
            g_SCWV_AwaitingReshowPaint := false
            if g_SCWV_Ready && !g_SCWV_PaintReady
                g_SCWV_PaintReady := true
        }
        if g_SCWV_FirstFrameSeen && !g_SCWV_Ready && !SCWV_IsCloseRequested()
            _SCWV_BootstrapWebReadyIfStalled("show_begin_warm")
    }
    g_SCWV_UserMinimized := false
    g_SCWV_CloseInFlight := false
    try SCWV_Log("show_begin", "reason=" . reason . " ready=" . (g_SCWV_Ready ? "1" : "0") . " ui_ready=" . (g_SCWV_UI_Ready ? "1" : "0") . " warm=" . (warmHost ? "1" : "0"))
    g_SCWV_LimitedRecoverReloadAttempts := 0
    SCWV_PushLifecycleState("opening", reason)
    _SCWV_SetLoadingTier("shell")
    _SCWV_PushLoadingTierState("shell")
    ; 打开阶段先屏蔽失焦自动关闭，避免 WebView/焦点切换瞬时抖动把窗口提前关掉（白屏/一闪）。
    _SCWV_BlockDeactivate(2800, "show_opening")

    if !SCWV_HostAlive() {
        SCWV_ResetHostState()
        SCWV_Init(reason)
    }
    if !g_SCWV_Gui
        SCWV_Init(reason)

    try FloatingToolbarCollapseTransientUi()

    GuiID_SearchCenter := g_SCWV_Gui

    if SCWV_IsRevealedToUser() {
        try SCWV_Log("show_already_visible", "reason=" . reason . " trigger=" . ts)
        ; 已可见时仅在非最大化态补一次最大化，避免反复状态切换导致横跳。
        SCWV_EnsureMaximized()
        if (ts = "clipboard_hotkey") {
            _SCWV_ApplyOpenUiMode("clipboard", ts)
            SearchCenterWebKeyword := ""
            try SCWV_SetUnifiedMode("clipboard", true)
            if (SearchCenterEngineMode = "go")
                SetTimer(_SCWV_RunDeferredSearchCoreEnsure, -10)
            SetTimer((*) => _SCWV_RunClipboardTimelineSearch("", 0, SearchCenterCurrentLimit), -20)
        } else if (ts = "fulltext_hotkey") {
            _SCWV_ApplyOpenUiMode("fulltext", ts)
            SearchCenterWebKeyword := ""
            if (SearchCenterEngineMode = "go")
                SetTimer(_SCWV_RunDeferredSearchCoreEnsure, -10)
            try SCProvider_FullTextAdmin_MaybePost(true)
            _SCWV_RefreshLocalHomeView()
        } else if (ts = "search_hotkey") {
            global g_SCWV_ClipboardHomeLock, g_SCWV_UiMode
            um := _SCWV_NormalizeUiMode(g_SCWV_UiMode)
            if (um = "clipboard" || um = "fulltext")
                um := "local"
            _SCWV_ApplyOpenUiMode(um, ts)
            try SCWV_SetUnifiedMode("search", true)
            if (Trim(SearchCenterWebKeyword) = "")
                _SCWV_ScheduleLocalHomeRefresh(40)
        }
        SetTimer(SCWV_PostHostShow, -80)
        if (ts != "clipboard_hotkey") {
            try SCWV_RaiseToForeground("show_already_visible", (*) => WebView2_MoveFocusProgrammatic(g_SCWV_Ctrl))
            curToken := g_SCWV_CurrentToken
            SetTimer((*) => _SCWV_DeferredMoveFocus100(curToken), -100)
            SetTimer((*) => SCWV_RaiseToForeground("show_already_visible_reassert"), -180)
            SCWV_RequestFocusInput()
        }
        if (ts = "search_hotkey")
            SCWV_ApplyCapsLockForSearchOpen()
        else
            try CapsLock_ScheduleNormalizeAfterChord()
        try SearchCenter_ScheduleIMEStabilize()
        SCWV_EnsureTaskbarEligible()
        if (ts = "search_hotkey")
            SCWV_ScheduleHandoffForegroundRetries()
        try SurfaceManager_ObserveShow("search_center", Map("entry", "SCWV_Show", "reason", reason, "trigger", ts, "alreadyVisible", 1, "requestId", reqId))
        return
    }

    readyToReveal := SCWV_CanRevealToUser()
    deferHost := !readyToReveal
        && SCWV_FuncExists("SurfaceManager_HasActivePrimaryConflict")
        && SurfaceManager_HasActivePrimaryConflict("search_center")
    ; 首屏未就绪时也保持宿主可见（深色壳 + HTML splash），否则 WebView2 在 Hide 父窗下不会合成首帧。
    openingShellVisible := !readyToReveal && !deferHost
    g_SCWV_DeferredHostShow := deferHost || !readyToReveal
    canShowHostShell := readyToReveal || openingShellVisible
    if readyToReveal || openingShellVisible {
        try WinSetTransparent(255, "ahk_id " . g_SCWV_Gui.Hwnd)
        catch {
        }
    } else if deferHost && g_SCWV_Gui {
        try g_SCWV_Gui.Show("Hide")
        catch {
        }
    }

    if canShowHostShell && !deferHost {
        try {
            ; 单入口全屏显示，避免 "固定尺寸 -> 最大化 -> 再最大化" 抖动链。
            SCWV_ShowHostFullscreen()
            SCWV_SetHostTopMost(g_SCWV_HostTopMost)
            SCWV_ScheduleBoundsRetries("show_open")
        } catch {
            ; 鍏滃簳锛氱獥鍙ｅ璞″瓨鍦ㄤ絾鍙ユ焺澶辨晥鏃堕噸寤轰竴娆★紝閬垮厤 鈥淕ui has no window鈥?            SCWV_ResetHostState()
            SCWV_Init(reason)
            if !g_SCWV_Gui
                return
            readyToReveal := SCWV_CanRevealToUser()
            deferHost := !readyToReveal
                && SCWV_FuncExists("SurfaceManager_HasActivePrimaryConflict")
                && SurfaceManager_HasActivePrimaryConflict("search_center")
            openingShellVisible := !readyToReveal && !deferHost
            g_SCWV_DeferredHostShow := deferHost
            if readyToReveal || openingShellVisible {
                try WinSetTransparent(255, "ahk_id " . g_SCWV_Gui.Hwnd)
                catch {
                }
            }
            if canShowHostShell && !deferHost {
                SCWV_ShowHostFullscreen()
                SCWV_SetHostTopMost(g_SCWV_HostTopMost)
                SCWV_ScheduleBoundsRetries("show_open_recover")
            } else {
                try SCWV_Log("show_defer_host", "reason=" . reason . " entry=recover")
            }
        }
    } else {
        try SCWV_Log("show_defer_host", "reason=" . reason)
    }
    if readyToReveal {
        try SCWV_Log("show_finish_reveal_immediate", "reason=" . reason)
        SCWV_FinishReveal()
    } else {
        try SCWV_Log("show_wait_ui_ready", "reason=" . reason . " shell=" . (openingShellVisible ? "1" : "0"))
        g_SCWV_WaitingUiFinishedReveal := true
        g_SCWV_ShowWaitStartTick := A_TickCount
        g_SCWV_Visible := false
        if openingShellVisible {
            SCWV_ScheduleCompositionPump("show_wait_shell")
            try {
                if WMActivateChain_Count() < 1
                    WMActivateChain_Register(SCWV_WM_ACTIVATE)
            } catch {
            }
            if g_SCWV_FirstFrameSeen && !g_SCWV_Ready && !SCWV_IsCloseRequested()
                _SCWV_BootstrapWebReadyIfStalled("show_wait_shell")
            try SCWV_PostJson(Map("type", "hostPaintNudge", "reason", "show_wait_shell"))
            catch {
            }
        }
        SCWV_ArmRevealWatchdog()
    }
    SCWV_PushLifecycleState("open", reason)

    SCWV_RefreshComposition()
    SCWV_ScheduleCompositionPump("show_open")

    ; 窗口显示后：剪贴板热键走时间线；普通空词走历史（含 3 分钟内置顶卡）
    try {
        if (SearchCenterEngineMode = "go")
            SetTimer(_SCWV_RunDeferredSearchCoreEnsure, -10)
        if (ts = "clipboard_hotkey") {
            _SCWV_ApplyOpenUiMode("clipboard", ts)
            SearchCenterWebKeyword := ""
            SetTimer((*) => _SCWV_RunClipboardTimelineSearch("", 0, SearchCenterCurrentLimit), -20)
        } else if (ts = "fulltext_hotkey") {
            _SCWV_ApplyOpenUiMode("fulltext", ts)
            SearchCenterWebKeyword := ""
            try SCProvider_FullTextAdmin_MaybePost(true)
            if (Trim(SearchCenterWebKeyword) = "")
                _SCWV_RefreshLocalHomeView()
        } else {
            global g_SCWV_UiMode
            um := _SCWV_NormalizeUiMode(g_SCWV_UiMode)
            if (um = "clipboard" || um = "fulltext")
                um := "local"
            _SCWV_ApplyOpenUiMode(um, ts)
            if (Trim(SearchCenterWebKeyword) = "")
                _SCWV_ScheduleLocalHomeRefresh(60)
        }
    } catch {
        if (ts != "clipboard_hotkey")
            _SCWV_ScheduleLocalHomeRefresh(60)
    }

    if g_SCWV_Ready {
        SCWV_PushThemeToWeb()
        if (ts != "clipboard_hotkey")
            _SCWV_ScheduleLocalHomeRefresh(80)
        if _SCWV_ShouldPostFullTextStatus() {
            try SCProvider_FullTextAdmin_MaybePost(true)
            catch {
                try _SCWV_PostFullTextStatus(true)
                catch {
                }
            }
        }
        SetTimer(SCWV_PostHostShow, -120)
    }
    else
        SetTimer(SCWV_DeferredPush, -250)

    ; 首屏：剪贴板/空词搜索热键仅本地 provider；其余按需远程检索
    if _SCWV_ShouldScheduleRemoteSearchOnShow(ts)
        SetTimer(_SCWV_PostRequestSearchGo, -20)

    if !deferHost && (ts != "clipboard_hotkey") {
        try SCWV_RaiseToForeground("show_focus", (*) => WebView2_MoveFocusProgrammatic(g_SCWV_Ctrl))
        curToken := g_SCWV_CurrentToken
        SetTimer((*) => _SCWV_DeferredMoveFocus100(curToken), -100)
        SetTimer((*) => SCWV_FocusDeferred(curToken), -80)
        SetTimer((*) => SCWV_RaiseToForeground("show_focus_reassert"), -200)
        SCWV_RequestFocusInput()
    }
    if !deferHost && openingShellVisible && (ts = "search_hotkey") && IsObject(g_SCWV_Gui) && !SCWV_IsCloseRequested() {
        try hwndShell := g_SCWV_Gui.Hwnd
        catch {
            hwndShell := 0
        }
        if hwndShell {
            try SCWV_ForegroundPulse(hwndShell)
            catch {
            }
        }
    }
    if !deferHost {
        if (ts = "search_hotkey")
            SCWV_ApplyCapsLockForSearchOpen()
        else
            try CapsLock_ScheduleNormalizeAfterChord()
        try SearchCenter_ScheduleIMEStabilize()
        if (ts = "search_hotkey")
            SCWV_ScheduleHandoffForegroundRetries()
    }
}

_SCWV_DeferredMoveFocus100(token := 0, *) {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_Ctrl
    if (token && !SCWV_IsCurrentToken(token))
        return
    if g_SCWV_Visible && g_SCWV_Gui
        SCWV_RaiseToForeground("deferred_move_focus", (*) => WebView2_MoveFocusProgrammatic(g_SCWV_Ctrl))
}

SCWV_DeferredPush(*) {
    global g_SCWV_Visible, g_SCWV_Ready, g_SCWV_PendingTriggerSource, SearchCenterFilterType

    if !g_SCWV_Visible
        return

    if g_SCWV_Ready {
        ts := Trim(String(g_SCWV_PendingTriggerSource))
        SCWV_PushThemeToWeb()
        if (ts != "clipboard_hotkey")
            SCWV_EnsureSearchHomeVisible()
        else if (SearchCenterFilterType != "clipboard") {
            SearchCenterFilterType := "clipboard"
        }
        SetTimer(SCWV_PostHostShow, -60)
    } else {
        SetTimer(SCWV_DeferredPush, -350)
    }
}

SCWV_FocusDeferred(token := 0, *) {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_Ctrl, g_SCWV_Ready
    if (token && !SCWV_IsCurrentToken(token))
        return

    if g_SCWV_Visible && g_SCWV_Gui {
        try FocusBroker_Request("SearchCenter", g_SCWV_Gui.Hwnd, 20, "focus_deferred", 300)
        try {
            if g_SCWV_Ready
                WebView2_MoveFocusProgrammatic(g_SCWV_Ctrl)
        }
    }
}

SCWV_RequestFocusInput() {
    global g_SCWV_WV2, g_SCWV_Ready, g_SCWV_FocusPending, g_SCWV_CliTerminalFocus
    if g_SCWV_CliTerminalFocus
        return
    if g_SCWV_WV2 && g_SCWV_Ready {
        global g_SCWV_SearchInputFocused
        g_SCWV_SearchInputFocused := true
        WebView_QueueJson(g_SCWV_WV2, '{"type":"focus_input"}')
        g_SCWV_FocusPending := false
        return
    }
    g_SCWV_FocusPending := true
}

SCWV_Hide(PersistSelection := true) {
    if SCWV_FuncExists("Nmer_Telemetry_MarkSurfaceClose") {
        try Nmer_Telemetry_MarkSurfaceClose("search_center", Map("source", "SCWV_Hide"))
        catch as _e {
            NmerCatch(A_ThisFunc, _e)
        }
    }
    if SCWV_FuncExists("SurfaceIntent_RouteExternalClose") && SurfaceIntent_RouteExternalClose("search_center", Map("persistSelection", PersistSelection ? 1 : 0))
        return
    if SCWV_FuncExists("SurfaceTransaction_OnTargetClose")
        try SurfaceTransaction_OnTargetClose("search_center", Map("entry", "SCWV_Hide"))
    skipTel := SCWV_FuncExists("SurfaceIntent_ShouldSkipExecutorTelemetry") && SurfaceIntent_ShouldSkipExecutorTelemetry()
    reqId := 0
    if !skipTel {
        reqId := SurfaceManager_Request("search_center", "close", "SCWV_Hide", Map("persistSelection", PersistSelection ? 1 : 0))
        try SurfaceManager_ObserveHide("search_center", Map("entry", "SCWV_Hide", "persistSelection", PersistSelection ? 1 : 0, "requestId", reqId))
    }
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_WaitingUiFinishedReveal, g_SCWV_SearchTimer, GuiID_SearchCenter, g_SCWV_PendingJsonQueue
    global g_SCWV_DeactivateBlockUntil, g_SCWV_DeactivateBlockReason, g_SCWV_ShowWaitStartTick, g_SCWV_ShowRecoveryAttempts
    global g_SCWV_LifecyclePhase, g_SCWV_TransitionCtx, g_SCWV_CloseCommitActive, g_SCWV_CloseCommitUntilTick, g_SCWV_CloseInFlight
    if !(g_SCWV_TransitionCtx is Map) || !g_SCWV_TransitionCtx["allow"] {
        try SCWV_Log("hide_redirect_intent", "persist=" . (PersistSelection ? "1" : "0"))
        g_SCWV_CloseInFlight := true
        SCWV_SubmitIntent("close", 25, Map("reason", "hide_redirect", "persist", PersistSelection ? 1 : 0))
        return
    }
    g_SCWV_CloseInFlight := true
    g_SCWV_CloseAfterReady := false
    g_SCWV_WaitingUiFinishedReveal := false
    SCWV_StopRevealWatchdog()
    if (g_SCWV_CurrentPhase != SCWV_PHASE_CLOSING && g_SCWV_CurrentPhase != SCWV_PHASE_CLOSED)
        SCWV_SetPhase(SCWV_PHASE_CLOSING, "hide")
    try SCWV_Log("hide_begin", "persist=" . (PersistSelection ? "1" : "0") . " visible=" . (g_SCWV_Visible ? "1" : "0") . " waiting=" . (g_SCWV_WaitingUiFinishedReveal ? "1" : "0") . " deact_block=" . Integer(g_SCWV_DeactivateBlockUntil))
    SCWV_PostHostForeground(false)
    SCWV_PushLifecycleState("closing", "hide")
    ; Drag-hole reentry safety: when exiting SearchCenter, force-reset native drag session
    ; so next text drag can re-trigger the hole from a clean initial state.
    try SCWV_Log("hide_step", "reset_bridge_begin")
    try NativeDropBridge_ResetSessionAsync("search_center_exit", 0)
    catch as err {
        try SCWV_Log("hide_error", "step=reset_bridge msg=" . err.Message)
    }
    try SCWV_Log("hide_step", "reset_bridge_queued")

    try SCWV_Log("hide_step", "pagedock_leave_begin")
    ; 退出统一宿主时统一兜底释放（见上面 force_close 分支原因说明）
    try FloatingToolbar_PageDockLeave("clipboard")
    catch as err {
        try SCWV_Log("hide_error", "step=pagedock_leave_clipboard msg=" . err.Message)
    }
    try FloatingToolbar_PageDockLeave("search")
    catch as err {
        try SCWV_Log("hide_error", "step=pagedock_leave_search msg=" . err.Message)
    }
    try SCWV_Log("hide_step", "pagedock_leave_done")

    if !SCWV_HostAlive() {
        try SCWV_Log("hide_host_not_alive", "")
        SCWV_ResetHostState()
        return
    }

    ; 鍙栨秷 WM_ACTIVATE 寤惰繜鍏抽棴锛岄伩鍏嶇敤鎴峰凡鍦ㄥ伐鍏锋爮鍚屾 Hide 鍚?50ms 鍙堟墽琛屼竴娆?Hide/鍓綔鐢?    SetTimer(SCWV_WMDeactivateHideTick, 0)
    SetTimer(SCWV_DeferredPush, 0)
    SetTimer(SCWV_RefreshComposition, 0)
    SetTimer(_SCWV_DeferredMoveFocus100, 0)
    SetTimer(SCWV_FocusDeferred, 0)
    SCWV_StopRevealWatchdog()
    SetTimer(SCWV_FlushPendingJsonQueue, 0)
    SetTimer(SCWV_Show, 0)
    g_SCWV_WaitingUiFinishedReveal := false
    g_SCWV_ShowWaitStartTick := 0
    g_SCWV_ShowRecoveryAttempts := 0
    g_SCWV_RevealCommitted := false
    g_SCWV_AwaitingReshowPaint := true
    g_SCWV_PaintReady := false
    g_SCWV_PendingJsonQueue := []
    g_SCWV_DeactivateBlockUntil := 0
    g_SCWV_DeactivateBlockReason := ""
    SCWV_ClearSearchInputFocus("hide")
    SCWV_StopForegroundPumps()
    SCWV_StopCompositionWatchdog()

    if PersistSelection {
        try SCWV_Log("hide_step", "save_selection_begin")
        _SCWV_SaveCurrentCategorySelection()
        try SCWV_Log("hide_step", "save_selection_done")
    }

    if g_SCWV_SearchTimer {
        try SCWV_Log("hide_step", "clear_search_timer")
        SetTimer(g_SCWV_SearchTimer, 0)
        g_SCWV_SearchTimer := 0
    }

    if g_SCWV_Gui {
        try SCWV_Log("hide_step", "gui_hide_begin")
        try {
            g_SCWV_Gui.Hide()
        } catch as err {
            try SCWV_Log("hide_error", "step=gui_hide msg=" . err.Message)
        }
    }

    g_SCWV_Visible := false
    GuiID_SearchCenter := 0
    SearchCenterInvalidateGuiControlRefs()

    try SCWV_Log("hide_step", "unregister_activate_chain count_before=" . WMActivateChain_Count())
    try {
        WMActivateChain_Unregister(SCWV_WM_ACTIVATE)
        try SCWV_Log("hide_step", "unregister_activate_chain_done count_after=" . WMActivateChain_Count())
    } catch as err {
        try SCWV_Log("hide_error", "step=unregister_activate_chain msg=" . err.Message)
    }

    try {
        WebView2_NotifyHidden(g_SCWV_WV2)
        SCWV_Log("hide_step", "webview_hidden_notified")
    } catch {
    }
    try SCWV_Log("hide_done", "visible=" . (g_SCWV_Visible ? "1" : "0"))
    if SCWV_FuncExists("CapsLock_NormalizeAfterUiClose")
        try CapsLock_NormalizeAfterUiClose()
        catch as _e {
            NmerCatch(A_ThisFunc, _e)
        }
    SCWV_ReleaseHostHotkeyScope()
    try SCWV_Preview_UnloadNative()
    catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
    SCWV_ArmCloseCommit(2000)
    SCWV_NotifyToolbarSearchClosed()
    SCWV_SetPhase(SCWV_PHASE_CLOSED, "hide")
    g_SCWV_CloseInFlight := false
    SCWV_PushLifecycleState("closed", "hide")
}

SCWV_WMDeactivateHideTick(*) {
    global g_SCWV_Visible, g_SCWV_Gui, g_SCWV_SearchHttpInFlight
    global g_SCWV_CloseCommitActive, g_SCWV_CloseCommitUntilTick
    if (g_SCWV_CloseCommitActive && A_TickCount < g_SCWV_CloseCommitUntilTick) {
        try SCWV_Log("hide_skip", "reason=close_commit")
        return
    }
    if !g_SCWV_Visible || !g_SCWV_Gui {
        try SCWV_Log("hide_skip", "reason=not_visible_or_host")
        return
    }
    if g_SCWV_SearchHttpInFlight {
        try SCWV_Log("hide_skip", "reason=search_http_in_flight")
        return
    }
    if _SCWV_IsDeactivateBlocked() {
        try SCWV_Log("hide_skip", "reason=deactivate_blocked until=" . Integer(g_SCWV_DeactivateBlockUntil) . " now=" . A_TickCount . " block_reason=" . g_SCWV_DeactivateBlockReason)
        return
    }
    if _SCWV_IsDarkCtxMenuOpen() {
        try SCWV_Log("hide_skip", "reason=dark_ctx_menu")
        return
    }
    try {
        if (FloatingToolbar_IsForegroundToolbarOrChild()) {
            try SCWV_Log("hide_skip", "reason=toolbar_foreground")
            return
        }
    } catch {
    }
    ; 长按 CapsLock 打开的 VK 会抢 WebView 焦点；若仍自动 Hide 搜索中心，会引发焦点风暴
    try {
        if VK_IsHostVisible() {
            try SCWV_Log("hide_skip", "reason=vk_visible")
            return
        }
    } catch {
    }
    global g_SCWV_CliTerminalFocus
    if g_SCWV_CliTerminalFocus {
        try SCWV_Log("hide_skip", "reason=cli_terminal_focus")
        return
    }
    ; 用户要求：搜索中心仅允许用户主动关闭（关闭按钮/ESC），失焦不再自动关闭。
    try SCWV_Log("hide_skip", "reason=wm_deactivate_disabled")
    return
}

SCWV_WM_ACTIVATE(wParam, lParam, msg, hwnd) {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_LastShown, g_SCWV_SearchHttpInFlight
    global g_SCWV_WaitingUiFinishedReveal, g_SCWV_FocusPending, g_SCWV_LifecyclePhase
    global g_SCWV_CloseCommitActive, g_SCWV_CloseCommitUntilTick

    try SCWV_Log("wm_activate_seen", "wparam=" . Integer(wParam & 0xFFFF) . " hwnd=" . hwnd . " visible=" . (g_SCWV_Visible ? "1" : "0") . " waiting=" . (g_SCWV_WaitingUiFinishedReveal ? "1" : "0") . " focus_pending=" . (g_SCWV_FocusPending ? "1" : "0") . " phase=" . g_SCWV_LifecyclePhase . " search_http=" . (g_SCWV_SearchHttpInFlight ? "1" : "0"))

    if (g_SCWV_CloseCommitActive && A_TickCount < g_SCWV_CloseCommitUntilTick) {
        try SCWV_Log("wm_activate_skip", "reason=close_commit")
        return
    }

    if !g_SCWV_Gui
        return
    if !(g_SCWV_Visible || g_SCWV_WaitingUiFinishedReveal)
        return

    if (hwnd = g_SCWV_Gui.Hwnd && (wParam & 0xFFFF) != 0) {
        SCWV_ScheduleCompositionPump("wm_activate")
        SCWV_PostHostForeground(true)
    }

    if (hwnd = g_SCWV_Gui.Hwnd && (wParam & 0xFFFF) = 0) {
        SCWV_ClearSearchInputFocus("wm_deactivate")
        SCWV_PostHostForeground(false)
        try {
            if ThemeApply_IsInProgress()
                return
        } catch {
        }
        if g_SCWV_SearchHttpInFlight {
            try SCWV_Log("wm_activate_skip", "reason=search_http_in_flight")
            return
        }
        if (g_SCWV_WaitingUiFinishedReveal || g_SCWV_FocusPending || g_SCWV_LifecyclePhase = "opening") {
            try SCWV_Log("wm_activate_skip", "reason=opening_or_focus_pending")
            return
        }
        if _SCWV_IsDeactivateBlocked() {
            try SCWV_Log("wm_activate_skip", "reason=deactivate_blocked until=" . Integer(g_SCWV_DeactivateBlockUntil) . " now=" . A_TickCount . " block_reason=" . g_SCWV_DeactivateBlockReason)
            return
        }
        ; 鐢ㄦ埛鐐瑰嚮鍚岃繘绋嬫偓娴伐鍏锋爮鍒囨崲鍏抽棴鏃讹紝鍓嶅彴甯稿湪 WebView 瀛?HWND 涓婏紝椤昏瘑鍒涓婚摼锛屽嬁鎶㈠厛 Hide
        try {
            if (FloatingToolbar_IsForegroundToolbarOrChild()) {
                try SCWV_Log("wm_activate_skip", "reason=toolbar_foreground")
                return
            }
        } catch {
        }
        ; 虚拟键盘已显示时，失焦常因焦点进入 VK 的 WebView2，勿关闭搜索中心
        try {
            if VK_IsHostVisible() {
                try SCWV_Log("wm_activate_skip", "reason=vk_visible")
                return
            }
        } catch {
        }
        global g_SCWV_CliTerminalFocus
        if g_SCWV_CliTerminalFocus {
            try SCWV_Log("wm_activate_skip", "reason=cli_terminal_focus")
            return
        }
        if _SCWV_IsDarkCtxMenuOpen() {
            try SCWV_Log("wm_activate_skip", "reason=dark_ctx_menu")
            return
        }
        if (g_SCWV_LifecyclePhase != "closing" && g_SCWV_LastShown && (A_TickCount - g_SCWV_LastShown < 500)) {
            try SCWV_Log("wm_activate_skip", "reason=recent_show delta=" . Integer(A_TickCount - g_SCWV_LastShown))
            return
        }
        ; 用户要求：搜索中心仅允许用户主动关闭（关闭按钮/ESC），失焦不再自动关闭。
        try SCWV_Log("wm_activate_skip", "reason=wm_deactivate_disabled count=" . WMActivateChain_Count())
        return
    }
}

SCWV_FlushPendingJsonQueue(*) {
    global g_SCWV_WV2, g_SCWV_Ready, g_SCWV_PendingJsonQueue
    if !g_SCWV_WV2 {
        return
    }
    if !g_SCWV_Ready {
        if (g_SCWV_PendingJsonQueue.Length)
            SetTimer(SCWV_FlushPendingJsonQueue, -80)
        return
    }
    while g_SCWV_PendingJsonQueue.Length {
        item := g_SCWV_PendingJsonQueue.RemoveAt(1)
        if (item is Map) && item.Has("obj")
            WebView_QueuePayload(g_SCWV_WV2, item["obj"])
        else if (item is Map) && item.Has("str")
            WebView_QueueJson(g_SCWV_WV2, item["str"])
    }
}

SCWV_PostJson(jsonStr) {
    global g_SCWV_WV2, g_SCWV_Ready, g_SCWV_PendingJsonQueue

    if !g_SCWV_WV2
        return
    if !g_SCWV_Ready {
        if (g_SCWV_PendingJsonQueue.Length >= 64)
            g_SCWV_PendingJsonQueue.RemoveAt(1)
        if (IsObject(jsonStr))
            g_SCWV_PendingJsonQueue.Push(Map("obj", jsonStr))
        else
            g_SCWV_PendingJsonQueue.Push(Map("str", String(jsonStr)))
        SetTimer(SCWV_FlushPendingJsonQueue, -50)
        return
    }
    if (IsObject(jsonStr))
        WebView_QueuePayload(g_SCWV_WV2, jsonStr)
    else
        WebView_QueueJson(g_SCWV_WV2, jsonStr)
}

_SCWV_NormalizeThemeToken(raw, fallback := "dark") {
    s := StrLower(Trim(String(raw)))
    if (s = "light" || s = "lite")
        return "light"
    if (s = "dark")
        return "dark"
    return (fallback = "light") ? "light" : "dark"
}

_SCWV_GetThemeMode() {
    ; Prefer direct INI read so theme stays correct even if global state is stale.
    try {
        global ConfigFile
        if (IsSet(ConfigFile) && ConfigFile != "") {
            raw := IniRead(ConfigFile, "Settings", "ThemeMode", "")
            if (Trim(String(raw)) = "")
                raw := IniRead(ConfigFile, "Appearance", "ThemeMode", "")
            if (Trim(String(raw)) != "")
                return _SCWV_NormalizeThemeToken(raw, "dark")
        }
    } catch {
    }
    try {
        fn := Func("ReadPersistedThemeMode")
        if IsObject(fn)
            return _SCWV_NormalizeThemeToken(fn.Call(), "dark")
    } catch {
    }
    try {
        global ThemeMode
        return _SCWV_NormalizeThemeToken(ThemeMode, "dark")
    } catch {
    }
    return "dark"
}

SCWV_PushThemeToWeb(*) {
    global g_SCWV_WV2
    if !g_SCWV_WV2
        return
    tm := _SCWV_GetThemeMode()
    try SCWV_PostJson(Map("type", "set_theme", "themeMode", tm))
}

SCWV_BeginHostDrag(*) {
    global g_SCWV_Gui
    if !g_SCWV_Gui
        return
    try PostMessage(0xA1, 2,,, "ahk_id " . g_SCWV_Gui.Hwnd)  ; WM_NCLBUTTONDOWN HTCAPTION
}

SCWV_MinimizeHost(*) {
    global g_SCWV_Gui, g_SCWV_UserMinimized, g_SCWV_CliTerminalFocus
    if !g_SCWV_Gui
        return
    g_SCWV_UserMinimized := true
    g_SCWV_CliTerminalFocus := false
    SCWV_StopForegroundPumps()
    try SCWV_PostJson(Map("type", "hostMinimized", "active", true))
    catch {
    }
    try WinMinimize("ahk_id " . g_SCWV_Gui.Hwnd)
}

SCWV_ToggleMaximizeHost(*) {
    global g_SCWV_Gui
    if !g_SCWV_Gui
        return
    hwndExpr := "ahk_id " . g_SCWV_Gui.Hwnd
    try {
        state := WinGetMinMax(hwndExpr)
        if (state = 1) {
            WinRestore(hwndExpr)
        } else {
            WinMaximize(hwndExpr)
        }
    }
}

SCWV_IsHostTopMost() {
    global g_SCWV_Gui, g_SCWV_HostTopMost
    try {
        if (g_SCWV_Gui && g_SCWV_Gui.Hwnd) {
            exStyle := WinGetExStyle("ahk_id " . g_SCWV_Gui.Hwnd)
            g_SCWV_HostTopMost := (exStyle & 0x8) ? true : false
        }
    } catch {
    }
    return g_SCWV_HostTopMost ? true : false
}

SCWV_SetHostTopMost(enabled := false) {
    global g_SCWV_Gui, g_SCWV_HostTopMost
    on := enabled ? true : false
    try {
        if (g_SCWV_Gui && g_SCWV_Gui.Hwnd)
            WinSetAlwaysOnTop(on, "ahk_id " . g_SCWV_Gui.Hwnd)
    } catch {
    }
    g_SCWV_HostTopMost := on
    return g_SCWV_HostTopMost
}

SCWV_ToggleHostTopMost() {
    cur := SCWV_IsHostTopMost()
    return SCWV_SetHostTopMost(!cur)
}

SCWV_OnWebMessage(sender, args) {
    jsonStr := SCWV_FuncExists("WebView2_CopyWebMessageJson") ? WebView2_CopyWebMessageJson(args) : ""
    if (jsonStr = "")
        return
    global g_SCWV_WebMsgQueue
    if !(g_SCWV_WebMsgQueue is Array)
        g_SCWV_WebMsgQueue := []
    if (g_SCWV_WebMsgQueue.Length >= 48)
        g_SCWV_WebMsgQueue.RemoveAt(1)
    g_SCWV_WebMsgQueue.Push(jsonStr)
    SetTimer(SCWV_DrainWebMessageQueue, -1)
}

SCWV_DrainWebMessageQueue(*) {
    global g_SCWV_WebMsgQueue, g_SCWV_WebMsgDrainBusy
    if g_SCWV_WebMsgDrainBusy
        return
    if !(g_SCWV_WebMsgQueue is Array) || g_SCWV_WebMsgQueue.Length = 0
        return
    g_SCWV_WebMsgDrainBusy := true
    try {
        while g_SCWV_WebMsgQueue.Length
            SCWV_ProcessWebMessageJson(g_SCWV_WebMsgQueue.RemoveAt(1))
    } finally {
        g_SCWV_WebMsgDrainBusy := false
        if (g_SCWV_WebMsgQueue is Array) && g_SCWV_WebMsgQueue.Length
            SetTimer(SCWV_DrainWebMessageQueue, -1)
    }
}

SCWV_ProcessWebMessageJson(jsonStr) {
    global GDHO_VISIBLE, NativeDropSessionActive, g_SCWV_WaitingUiFinishedReveal
    global g_SCWV_LifecyclePhase
    try {
        msg := SCWV_FuncExists("Jxon_LoadSafe") ? Jxon_LoadSafe(jsonStr) : Jxon_Load(jsonStr)
    } catch {
        return
    }

    if (msg is String) {
        try msg := SCWV_FuncExists("Jxon_LoadSafe") ? Jxon_LoadSafe(msg) : Jxon_Load(msg)
        catch {
            return
        }
    }
    if !(msg is Map)
        return

    action := msg.Has("type") ? msg["type"] : (msg.Has("action") ? msg["action"] : "")
    if (action = "")
        return

    try {
    switch action {
        case "ready":
            global g_SCWV_Ready, g_SCWV_UI_Ready, g_SCWV_WaitingUiFinishedReveal, g_SCWV_CloseAfterReady
            global g_SCWV_ForceResetStreak, g_SCWV_DegradedMode, TrayMenuCustomFailStreak
            global g_SCWV_ReloadRecoveryPending
            g_SCWV_Ready := true
            _SCWV_HandoffEnd("web_ready")
            if SCWV_IsCloseRequested() {
                try SCWV_Log("web_ready_skip_close_requested", "close_after=" . (g_SCWV_CloseAfterReady ? "1" : "0"))
                if (g_SCWV_CloseAfterReady) {
                    g_SCWV_CloseAfterReady := false
                    SCWV_SubmitIntent("CLOSE", 15, Map("reason", "close_after_ready"))
                }
                return
            }
            SCWV_SetPhase(SCWV_PHASE_OPEN, "web_ready")
            SCWV_PushThemeToWeb()
            if SCWV_IsWebSearchUIMode()
                _SCWV_EnsureDefaultWebEngines(GetSearchCenterCurrentCategoryKey())
            kwReady := Trim(SearchCenterWebKeyword)
            if !SCWV_IsWebSearchUIMode() {
                global g_SCWV_UiMode, g_SCWV_ClipboardHomeLock
                um := StrLower(Trim(String(g_SCWV_UiMode)))
                if (um != "cli") {
                    if (kwReady = "") {
                        if (um = "clipboard" || SearchCenterFilterType = "clipboard")
                            SetTimer((*) => _SCWV_RunClipboardTimelineSearch("", 0, SearchCenterCurrentLimit), -40)
                        else
                            _SCWV_ScheduleLocalHomeRefresh(40)
                    } else
                        SCWV_PushState("init")
                } else {
                    SCWV_PushState("init")
                }
            } else {
                SCWV_PushState("init")
            }
            _SCWV_SendDockConfig()
            if _SCWV_ShouldPostFullTextStatus()
                SCProvider_FullTextAdmin_MaybePost(true)
            try SCWV_FlushPendingJsonQueue()
            if !SCWV_IsWebSearchUIMode() {
                global g_SCWV_UiMode
                um := StrLower(Trim(String(g_SCWV_UiMode)))
                if (um != "cli" && kwReady != "")
                    SetTimer(_SCWV_PostRequestSearchGo, -80)
            }
            if g_SCWV_FocusPending
                SCWV_RequestFocusInput()
            if g_SCWV_ReloadRecoveryPending {
                g_SCWV_ReloadRecoveryPending := false
                SetTimer((*) => SCWV_ReplayLastSearchIntent("reload_ready"), -10)
            }
            SCWV_ScheduleCompositionPump("web_ready")
            SCWV_TryFinishReveal("web_ready")
        case "UI_PAINT_READY":
            global g_SCWV_PaintReady, g_SCWV_LastPaintReadyTick, g_SCWV_UI_Ready
            if SCWV_IsCloseRequested()
                return
            now := A_TickCount
            if g_SCWV_PaintReady && (now - g_SCWV_LastPaintReadyTick) < 120
                return
            g_SCWV_LastPaintReadyTick := now
            g_SCWV_PaintReady := true
            g_SCWV_UI_Ready := true
            SCWV_ScheduleCompositionPump("ui_paint_ready")
            SCWV_TryFinishReveal("ui_paint_ready")
        case "setEngineMode":
            global SearchCenterEngineMode
            mo := msg.Has("mode") ? String(msg["mode"]) : "go"
            if (mo = "go" || mo = "ahk") {
                SearchCenterEngineMode := mo
                _SCWV_SaveSearchEngineMode(mo)
            }
            SCWV_PushState("state")
        case "setThemeMode":
            ; 来自前端的主题切换：写入配置并同步到所有 WebView UI（含悬浮工具栏）
            tm0 := msg.Has("themeMode") ? String(msg["themeMode"]) : ""
            tm0 := (StrLower(Trim(tm0)) = "light") ? "light" : "dark"
            try {
                global ConfigFile
                IniWrite(tm0, ConfigFile, "Settings", "ThemeMode")
                IniWrite(tm0, ConfigFile, "Appearance", "ThemeMode")
            } catch {
            }
            try ApplyTheme(tm0)
            catch {
            }
        case "searchResultSync":
            kw := msg.Has("keyword") ? String(msg["keyword"]) : ""
            off := msg.Has("offset") ? Integer(msg["offset"]) : 0
            if (off < 0)
                off := 0
            hm := msg.Has("hasMore") ? (msg["hasMore"] ? true : false) : false
            raw := msg.Has("items") ? msg["items"] : []
            GoItems := []
            if (raw is Array) {
                for _, it in raw
                    GoItems.Push(it)
            }
            _SCWV_ApplySearchResultSync(kw, off, hm, GoItems)
            SCWV_PushState("state")
        case "searchGoRequest":
            global SearchCenterWebKeyword, SearchCenterHasMoreData, SearchCenterFilterType
            kw0 := msg.Has("keyword") ? String(msg["keyword"]) : ""
            off0 := msg.Has("offset") ? Integer(msg["offset"]) : 0
            if (off0 < 0)
                off0 := 0
            lim0 := msg.Has("limit") ? Integer(msg["limit"]) : 0
            gt0 := msg.Has("goType") ? String(msg["goType"]) : ""
            clientQueryID := _SCWV_AdoptClientQueryID(msg)
            SearchCenterWebKeyword := Trim(kw0)
            if (SearchCenterWebKeyword = "") {
                global g_SCWV_ClipboardHomeLock, g_SCWV_UiMode
                umEmpty := StrLower(Trim(String(g_SCWV_UiMode)))
                if (umEmpty = "clipboard" || SearchCenterFilterType = "clipboard") {
                    _SCWV_RunClipboardTimelineSearch("", off0, lim0)
                    return
                }
                if (_SCWV_HandleEmptyKeywordSearchIntent(off0, lim0, gt0))
                    return
                SearchCenterHasMoreData := false
                _SCWV_RefreshLocalHomeView()
                return
            }
            gtUse := Trim(String(gt0))
            if (gtUse = "")
                gtUse := _SCWV_MapFilterToGoSearchType(SearchCenterFilterType)
            if (gtUse = "clipboard")
                SearchCenterFilterType := "clipboard"
            _SCWV_RecordSearchHistory(SearchCenterWebKeyword)
            _SCWV_ExecuteGoSearchHttp(off0, kw0, gtUse, lim0, clientQueryID, 0)
        case "fulltextStatusRequest":
            withCfg := msg.Has("withConfig") ? (msg["withConfig"] ? true : false) : false
            _SCWV_PostFullTextStatus(withCfg)
        case "fulltextControl":
            act := msg.Has("control") ? String(msg["control"]) : "start"
            _SCWV_ControlFullText(act)
        case "fulltextConfigUpdate":
            pl := msg.Has("payload") && (msg["payload"] is Map) ? msg["payload"] : Map()
            _SCWV_UpdateFullTextConfig(pl)
        case "fulltextProbeRequest":
            _SCWV_ProbeFullTextFeasibility()
        case "fulltextPickIndexDir":
            _SCWV_PickFullTextIndexDir()
        case "scHotkeyBindingsSync":
            pl := msg.Has("payload") && (msg["payload"] is Map) ? msg["payload"] : Map()
            _SCWV_SyncScHotkeyBindings(pl)
        case "openSettingsPanel":
            try {
                global g_ConfigWebView_OneShotDefaultTab
                g_ConfigWebView_OneShotDefaultTab := ""
                if (msg.Has("defaultStartTab")) {
                    tab := Trim(String(msg["defaultStartTab"]))
                    validTabs := Map("general", true, "appearance", true, "prompts", true, "hotkeys", true, "advanced", true, "screenshot", true, "search", true, "customize", true)
                    if (tab != "" && validTabs.Has(tab))
                        g_ConfigWebView_OneShotDefaultTab := tab
                }
                if IsSet(ShowConfigWebViewGUI) {
                    SurfaceIntent_Open("config_webview")
                } else if IsSet(ShowConfigGUI) {
                    ShowConfigGUI()
                }
            } catch as err {
                SCWV_PostJson(Map("type", "fulltextActionResult", "ok", false, "action", "openSettingsPanel", "error", err.Message))
            }
        case "nmDockReady":
            _SCWV_SendDockConfig()
        case "nmDockLeave":
            ; lifecycle handled by SCWV_Show/SCWV_Hide
        case "nmDockCmd":
            _SCWV_ExecuteDockCmd(msg)
        case "reloadBlankHome":
            global SearchCenterFilterType, SearchCenterWebKeyword, g_SCWV_ClipboardHomeLock, g_SCWV_UiMode
            umReload := StrLower(Trim(String(g_SCWV_UiMode)))
            if (umReload = "clipboard" || SearchCenterFilterType = "clipboard") {
                SearchCenterFilterType := "clipboard"
                _SCWV_RunClipboardTimelineSearch("", 0, SearchCenterCurrentLimit, true)
                return
            }
            g_SCWV_ClipboardHomeLock := false
            SearchCenterFilterType := ""
            SearchCenterWebKeyword := ""
            try SCWV_SetUnifiedMode("search", false)
            _SCWV_RefreshLocalHomeView()
        case "search":
            global SearchCenterWebKeyword, SearchCenterHasMoreData, SearchCenterFilterType
            _SCWV_AdoptClientQueryID(msg)
            if !msg.Has("keyword")
                try OutputDebug("[SCWV] search message missing keyword field")
            keyword := msg.Has("keyword") ? String(msg["keyword"]) : ""
            try OutputDebug("[SCWV] search request keyword_len=" . StrLen(keyword))
            SearchCenterWebKeyword := Trim(String(keyword))
            if (SearchCenterWebKeyword = "") {
                global g_SCWV_UiMode
                umEmpty := StrLower(Trim(String(g_SCWV_UiMode)))
                if (umEmpty = "clipboard" || SearchCenterFilterType = "clipboard") {
                    _SCWV_RunClipboardTimelineSearch("", 0, SearchCenterCurrentLimit)
                    return
                }
                if (_SCWV_HandleEmptyKeywordSearchIntent(0, 0, _SCWV_MapFilterToGoSearchType(SearchCenterFilterType)))
                    return
                SearchCenterHasMoreData := false
                _SCWV_RefreshLocalHomeView()
            } else {
                if (SearchCenterEngineMode = "go")
                    _SCWV_EnsureSearchCoreRunning()
                _SCWV_RecordSearchHistory(SearchCenterWebKeyword)
                SetTimer(_SCWV_PostRequestSearchGo, -40)
            }
        case "setCategory":
            global SearchCenterWebKeyword, g_SCWV_UiMode
            if msg.Has("category")
                _SCWV_SetCategoryByKey(String(msg["category"]))
            ck := GetSearchCenterCurrentCategoryKey()
            um := StrLower(Trim(String(g_SCWV_UiMode)))
            if (ck = "cli")
                g_SCWV_UiMode := "cli"
            else if (um != "local" && ck != "")
                g_SCWV_UiMode := "web"
    if (Trim(SearchCenterWebKeyword) != "")
        SetTimer(_SCWV_PostRequestSearchGo, -1)
    else if (StrLower(Trim(String(g_SCWV_UiMode))) = "local")
                _SCWV_RefreshLocalHomeView()
            else
                SCWV_PushState("init")
        case "setFilter":
            global SearchCenterFilterType, SearchCenterWebKeyword, g_SCWV_ClipboardHomeLock, g_SCWV_UiMode
            _SCWV_AdoptClientQueryID(msg)
            nextFilter := msg.Has("filterType") ? String(msg["filterType"]) : ""
            ; 全文/剪贴板改由主模式导航承载，不再作为结果区 chip
            if (nextFilter = "fulltext") {
                SearchCenterFilterType := "fulltext"
                g_SCWV_UiMode := "fulltext"
                g_SCWV_ClipboardHomeLock := false
            } else if (nextFilter = "clipboard") {
                SearchCenterFilterType := "clipboard"
                g_SCWV_UiMode := "clipboard"
                if (Trim(String(g_SCWV_PendingTriggerSource)) = "clipboard_hotkey")
                    g_SCWV_ClipboardHomeLock := true
                else
                    g_SCWV_ClipboardHomeLock := false
            } else {
                g_SCWV_ClipboardHomeLock := false
                SearchCenterFilterType := nextFilter
                if (SearchCenterFilterType = "fulltext")
                    g_SCWV_UiMode := "fulltext"
                else
                    g_SCWV_UiMode := "local"
            }
            if msg.Has("keyword")
                SearchCenterWebKeyword := Trim(String(msg["keyword"]))
            ; 普通过滤标签优先使用上一次「全部结果」本地切换，避免切标签还要等待后端。
            if (Trim(SearchCenterWebKeyword) != "" && SearchCenterFilterType != "fulltext" && _SCWV_RestoreAllResultsCache(SearchCenterWebKeyword)) {
                SCWV_PushState("init")
                return
            }
            try _SCWV_PushClipFloatToWeb()
            catch {
            }
            if (Trim(SearchCenterWebKeyword) != "") {
                SetTimer(_SCWV_PostRequestSearchGo, -1)
                SCWV_PushState("init")
                return
            }
            if (SearchCenterFilterType = "fulltext")
                SCProvider_FullTextAdmin_MaybePost(true)
            _SCWV_RefreshLocalHomeView()
        case "setLimit":
            global SearchCenterCurrentLimit, SearchCenterEverythingLimit
            _SCWV_AdoptClientQueryID(msg)
            val := msg.Has("limit") ? Integer(msg["limit"]) : 50
            if (val <= 0)
                val := 50
            SearchCenterCurrentLimit := val
            SearchCenterEverythingLimit := val
            SetTimer(_SCWV_PostRequestSearchGo, -50)
            SCWV_PushState("state")
        case "loadMore":
            global SearchCenterWebKeyword, SearchCenterFilterType, SearchCenterCurrentLimit, SearchCenterEngineMode
            offset := msg.Has("offset") ? Integer(msg["offset"]) : 0
            if (offset < 0)
                offset := 0
            if (SearchCenterEngineMode = "go") {
                _SCWV_ExecuteGoSearchHttp(offset, SearchCenterWebKeyword, _SCWV_MapFilterToGoSearchType(SearchCenterFilterType), SearchCenterCurrentLimit)
            } else {
                _SCWV_RunAhkSearch(offset)
                SCWV_PushState("state")
            }
        case "toggleEngine":
            if msg.Has("engine")
                _SCWV_ToggleEngine(String(msg["engine"]))
            SCWV_PushState("state")
        case "batchSearch":
            _SCWV_BatchSearch()
        case "syncSelectedEngines":
            changed := false
            if msg.Has("selectedEngines")
                changed := _SCWV_ApplySelectedEnginesFromWeb(msg["selectedEngines"])
            else if msg.Has("engines")
                changed := _SCWV_ApplySelectedEnginesFromWeb(msg["engines"])
            if changed
                SCWV_PushState("state")
        case "webSearch":
            global SearchCenterWebKeyword
            if msg.Has("keyword")
                SearchCenterWebKeyword := Trim(String(msg["keyword"]))
            if msg.Has("selectedEngines")
                _SCWV_ApplySelectedEnginesFromWeb(msg["selectedEngines"])
            _SCWV_BatchSearch()
        case "setUiMode":
            global g_SCWV_UiMode, SearchCenterWebKeyword, g_SCWV_CliTerminalFocus, SearchCenterFilterType, g_SCWV_ClipboardHomeLock
            global g_SCWV_ClipboardTimelineGen
            m := msg.Has("mode") ? StrLower(Trim(String(msg["mode"]))) : "local"
            if (m = "clipboard") {
                g_SCWV_UiMode := "clipboard"
                if (Trim(String(g_SCWV_PendingTriggerSource)) = "clipboard_hotkey")
                    g_SCWV_ClipboardHomeLock := true
                else
                    g_SCWV_ClipboardHomeLock := false
                SearchCenterFilterType := "clipboard"
                g_SCWV_CliTerminalFocus := false
                if (Trim(SearchCenterWebKeyword) = "")
                    _SCWV_RunClipboardTimelineSearch("", 0, SearchCenterCurrentLimit, true)
                else {
                    SetTimer(_SCWV_PostRequestSearchGo, -1)
                    SCWV_PushState("init")
                }
            } else if (m = "fulltext") {
                g_SCWV_UiMode := "fulltext"
                g_SCWV_ClipboardHomeLock := false
                g_SCWV_ClipboardTimelineGen++
                SearchCenterFilterType := "fulltext"
                g_SCWV_CliTerminalFocus := false
                if (Trim(SearchCenterWebKeyword) = "") {
                    SCProvider_FullTextAdmin_MaybePost(true)
                    _SCWV_RefreshLocalHomeView()
                } else {
                    SetTimer(_SCWV_PostRequestSearchGo, -1)
                    SCWV_PushState("init")
                }
            } else if (m = "cli" || m = "web") {
                g_SCWV_UiMode := m
                g_SCWV_ClipboardHomeLock := false
                g_SCWV_ClipboardTimelineGen++
                if (SearchCenterFilterType = "clipboard" || SearchCenterFilterType = "fulltext")
                    SearchCenterFilterType := ""
                if (m != "cli")
                    g_SCWV_CliTerminalFocus := false
                if (m = "web") {
                    _SCWV_EnsureDefaultWebEngines(GetSearchCenterCurrentCategoryKey())
                    SCWV_PushState("init")
                } else {
                    SCWV_PushState("init")
                }
            } else {
                g_SCWV_UiMode := "local"
                g_SCWV_ClipboardHomeLock := false
                g_SCWV_ClipboardTimelineGen++
                g_SCWV_CliTerminalFocus := false
                if (SearchCenterFilterType = "clipboard" || SearchCenterFilterType = "fulltext")
                    SearchCenterFilterType := ""
                if (Trim(SearchCenterWebKeyword) = "")
                    SCWV_EnsureSearchHomeVisible()
                else {
                    SetTimer(_SCWV_PostRequestSearchGo, -1)
                    SCWV_PushState("init")
                }
            }
        case "requestUiRefresh":
            global g_SCWV_UiMode, SearchCenterWebKeyword
            m := StrLower(Trim(String(g_SCWV_UiMode)))
            if (m = "web") {
                _SCWV_EnsureDefaultWebEngines(GetSearchCenterCurrentCategoryKey())
                SCWV_PushState("init")
            } else if (m = "local") {
                if (Trim(SearchCenterWebKeyword) = "")
                    SCWV_EnsureSearchHomeVisible()
                else {
                    SetTimer(_SCWV_PostRequestSearchGo, -1)
                    SCWV_PushState("init")
                }
            } else {
                SCWV_PushState("init")
            }
        case "cliSend":
            prompt := msg.Has("prompt") ? String(msg["prompt"]) : ""
            eng := msg.Has("engine") ? Trim(String(msg["engine"])) : ""
            _SCWV_SendToCLI(prompt, eng)
        case "cliInject":
            prompt := msg.Has("prompt") ? String(msg["prompt"]) : ""
            eng := msg.Has("engine") ? Trim(String(msg["engine"])) : ""
            _SCWV_InjectPromptToTtyd(prompt, eng)
        case "cliOpen":
            OpenSelectedCLIAgents()
        case "cliTerminalFocus":
            global g_SCWV_CliTerminalFocus, g_SCWV_UserMinimized
            if g_SCWV_UserMinimized
                g_SCWV_CliTerminalFocus := false
            else {
                g_SCWV_CliTerminalFocus := msg.Has("active") ? !!msg["active"] : false
                if g_SCWV_CliTerminalFocus
                    _SCWV_BlockDeactivate(4500, "cli_terminal")
            }
        case "searchInputFocus":
            global g_SCWV_SearchInputFocused
            g_SCWV_SearchInputFocused := msg.Has("active") ? !!msg["active"] : false
            if g_SCWV_SearchInputFocused && SCWV_IsHostForegroundActive()
                SCWV_PostHostForeground(true)
        case "refreshSearchHome":
            _SCWV_AdoptClientQueryID(msg)
            SCWV_EnsureSearchHomeVisible()
        case "niuma_cli_open":
            global g_SCWV_WV2
            reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
            engine := msg.Has("engine") ? Trim(String(msg["engine"])) : "codex_cli"
            SetTimer(NiumaTtyd_DeferredOpenJob.Bind(reqId, engine, g_SCWV_WV2), -10)
        case "niuma_cli_restart":
            global g_SCWV_WV2
            reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
            engine := msg.Has("engine") ? Trim(String(msg["engine"])) : "codex_cli"
            SetTimer(NiumaTtyd_DeferredRestartJob.Bind(reqId, engine, g_SCWV_WV2), -10)
        case "niuma_cli_open_external":
            global g_SCWV_WV2
            reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
            expectedBaseUrl := msg.Has("baseUrl") ? String(msg["baseUrl"]) : ""
            engine := msg.Has("engine") ? Trim(String(msg["engine"])) : "codex_cli"
            SetTimer(NiumaTtyd_DeferredExternalOpenJob.Bind(reqId, expectedBaseUrl, engine, g_SCWV_WV2), -10)
        case "activateResult":
            row := msg.Has("row") ? Integer(msg["row"]) : 0
            _SCWV_ActivateResultRow(row)
        case "searchCenterContextMenu":
            row := msg.Has("row") ? Integer(msg["row"]) : 0
            itemUid := msg.Has("itemUid") ? String(msg["itemUid"]) : ""
            sx := msg.Has("screenX") ? Integer(msg["screenX"]) : 0
            sy := msg.Has("screenY") ? Integer(msg["screenY"]) : 0
            SCWV_BumpChannelToken("menu")
            _SCWV_ShowSearchCenterRowMenu(row, sx, sy, itemUid)
        case "modeSwitchGuard":
            active := msg.Has("active") ? !!msg["active"] : false
            span := msg.Has("ms") ? Integer(msg["ms"]) : 120
            if active
                SCWV_ModeSwitchGuardBegin(span)
            else
                SCWV_ModeSwitchGuardEnd("ui_ack")
        case "close":
            try SCWV_Log("webmsg_close", "visible=" . (g_SCWV_Visible ? "1" : "0"))
            global g_SCWV_CloseInFlight
            if g_SCWV_CloseInFlight {
                SCWV_ForceCloseHost("webmsg_close_force")
                return
            }
            SCWV_SubmitIntent("close", 20, Map("reason", "webmsg_close"))
        case "lifecycle":
            phase := msg.Has("phase") ? StrLower(Trim(String(msg["phase"]))) : ""
            reason := msg.Has("reason") ? String(msg["reason"]) : ""
            try SCWV_Log("webmsg_lifecycle", "phase=" . phase . " reason=" . reason)
            if (phase = "close_request") {
                SCWV_SubmitIntent("close", 20, Map("reason", (reason != "" ? reason : "close_request")))
            } else if (phase = "closed") {
                SCWV_SetPhase(SCWV_PHASE_CLOSED, reason != "" ? reason : "web_closed")
            } else if (phase = "opening" || phase = "open" || phase = "closing") {
                SCWV_PushLifecycleState(phase, reason)
            }
        case "dragHost":
            SCWV_BeginHostDrag()
        case "windowMinimize":
            SCWV_MinimizeHost()
        case "windowToggleMaximize":
            SCWV_ToggleMaximizeHost()
        case "windowToggleTopMost":
            SCWV_ToggleHostTopMost()
            SCWV_PushState("state")
        case "searchCenterRestoreRecycle":
            idx := msg.Has("index") ? Integer(msg["index"]) : 0
            SC_SearchCenterRestoreRecycleAt(idx)
        case "searchCenterEmptyRecycle":
            SC_SearchCenterEmptyRecycleBin()
        case "openWindowsRecycleBin":
            SCWV_OpenWindowsRecycleBinFolder()
        case "WEB_PREVIEW_TEXT":
            p := msg.Has("path") ? String(msg["path"]) : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            SCWV_BumpChannelToken("preview")
            SCWV_Preview_OnWebText(p, sq)
        case "WEB_PREVIEW_IMAGE":
            p := msg.Has("path") ? String(msg["path"]) : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            SCWV_BumpChannelToken("preview")
            SCWV_Preview_OnWebImage(p, sq)
        case "NATIVE_PREVIEW":
            p := msg.Has("path") ? String(msg["path"]) : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            bmap := msg.Has("bounds") && (msg["bounds"] is Map) ? msg["bounds"] : 0
            SCWV_BumpChannelToken("preview")
            SCWV_Preview_OnNative(p, sq, bmap)
        case "PREVIEW_NATIVE_STOP":
            SCWV_Preview_UnloadNative()
        case "QUICKLOOK":
            p := msg.Has("path") ? String(msg["path"]) : ""
            row := msg.Has("row") ? Integer(msg["row"]) : 0
            if (Trim(p) = "")
                p := _SCWV_ResolveQuickLookPathByRow(row)
            SCWV_Preview_TryQuickLook(p)
        case "INVOKE_IPREVIEW":
            p := msg.Has("path") ? String(msg["path"]) : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            bmap := msg.Has("bounds") && (msg["bounds"] is Map) ? msg["bounds"] : 0
            try SCWV_Preview_Get().InvokeNative(p, sq, bmap)
            catch as err {
                SCWV_PostJson(Map("type", "NATIVE_PREVIEW_FAILED", "message", err.Message))
            }
        case "INVOKE_WEB_MEDIA":
            p := msg.Has("path") ? String(msg["path"]) : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            _SCWV_BlockDeactivate(4500, "media_preview")
            try SCWV_Preview_Get().OnWebMedia(p, sq)
        case "GET_MEDIA_INFO":
            p := msg.Has("path") ? String(msg["path"]) : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            try SCWV_Preview_Get().PostMediaInfo(p, sq)
        case "SAVE_MEDIA_FRAME":
            p := msg.Has("path") ? String(msg["path"]) : ""
            ts := msg.Has("timeSec") ? msg["timeSec"] : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            _SCWV_BlockDeactivate(4500, "media_save_frame")
            try SCWV_Preview_Get().SaveMediaFrame(p, ts, sq)
        case "INVOKE_PDFIUM":
            p := msg.Has("path") ? String(msg["path"]) : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            SCWV_Preview_OnPdfium(p, sq)
        case "INVOKE_PDF_JS":
            p := msg.Has("path") ? String(msg["path"]) : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            _SCWV_BlockDeactivate(12000, "pdf_js_preview")
            try SCWV_Preview_Get().OnWebPdfJs(p, sq)
            catch as err {
                SCWV_PostJson(Map("type", "WEB_PREVIEW_PDF_JS_ERROR", "seq", sq, "message", err.Message))
            }
        case "INVOKE_ARCHIVE_LIST":
            p := msg.Has("path") ? String(msg["path"]) : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            mode := msg.Has("mode") ? Trim(String(msg["mode"])) : "seven_zip"
            _SCWV_BlockDeactivate(2500, "archive_preview")
            SCWV_Preview_OnArchiveList(p, sq, mode)
        case "REQUEST_PREVIEW_META":
            p := msg.Has("path") ? String(msg["path"]) : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            SCWV_Preview_RequestMeta(p, sq)
        case "INSTALL_QUICKLOOK":
            global g_SCWV_QuickLookInstallBusy
            if g_SCWV_QuickLookInstallBusy {
                SCWV_PostJson(Map("type", "quicklook_install_progress", "percent", 0, "message", "安装任务进行中，请稍候…"))
                return
            }
            if (SCWV_ResolveQuickLookExe() != "") {
                SCWV_PostJson(Map("type", "quicklook_install_state", "ok", true, "message", "QuickLook 已安装", "path", SCWV_ResolveQuickLookExe()))
                return
            }
            if !SCWV_QuickLookInstall_RequestStart()
                SCWV_PostJson(Map("type", "quicklook_install_state", "ok", false, "message", "无法开始安装（可能已有任务）", "path", ""))
        case "QUICKLOOK_STATUS":
            SCWV_PushState("state")
    }
    } catch as err {
        _SCWV_LogRuntime("OnWebMessage action=" . String(action) . " error=" . err.Message)
    }
}

_SCWV_SendDockConfig() {
    arr := []
    try {
        if IsSet(_LoadCommands)
            _LoadCommands()
        global g_Commands
        if (g_Commands is Map && g_Commands.Has("SceneToolbarLayout") && g_Commands["SceneToolbarLayout"] is Array) {
            for row in g_Commands["SceneToolbarLayout"] {
                if !(row is Map) || !row.Has("sceneId")
                    continue
                sid := Trim(String(row["sceneId"]))
                if (sid = "")
                    continue
                arr.Push(Map(
                    "sceneId", sid,
                    "visible_in_bar", row.Has("visible_in_bar") ? (row["visible_in_bar"] ? true : false) : true,
                    "order_bar", row.Has("order_bar") ? Integer(row["order_bar"]) : -1
                ))
            }
        }
    } catch {
    }
    SCWV_PostJson(Map("type", "nmDockConfig", "sceneToolbarLayout", arr))
}

_SCWV_ExecuteDockCmd(msg) {
    cmdId0 := msg.Has("cmdId") ? String(msg["cmdId"]) : ""
    if (cmdId0 = "")
        return
    if (cmdId0 = "open_cloudplayer") {
        try ShowCloudPlayer()
        return
    }
    try {
        _ExecuteCommand(cmdId0)
        return
    } catch {
    }
    m0 := Map(
        "Title", "dock",
        "Content", "",
        "DataType", "text",
        "OriginalDataType", "text",
        "Source", "dock",
        "ClipboardId", 0,
        "PromptMergedIndex", 0,
        "HubSegIndex", -1
    )
    try SC_ExecuteContextCommand(cmdId0, 0, m0)
    catch as err {
        _SCWV_LogRuntime("nmDockCmd " . cmdId0 . " error=" . err.Message)
    }
}

SCWV_QueueSearch(keyword) {
    global g_SCWV_SearchTimer, SearchCenterWebKeyword, g_SCWV_ModeSwitchGuard

    SearchCenterWebKeyword := keyword

    if g_SCWV_SearchTimer {
        SetTimer(g_SCWV_SearchTimer, 0)
        g_SCWV_SearchTimer := 0
    }

    fn := _SCWV_FireSearch.Bind()
    g_SCWV_SearchTimer := fn
    SetTimer(fn, g_SCWV_ModeSwitchGuard ? -260 : -150)
}

_SCWV_FireSearch(*) {
    global g_SCWV_SearchTimer, SearchCenterWebKeyword, SearchCenterEngineMode, SearchCenterFilterType

    g_SCWV_SearchTimer := 0
    kw := Trim(SearchCenterWebKeyword)
    if (kw = "") {
        _SCWV_RefreshLocalHomeView()
        return
    }
    SCProvider_RouteSearch(SCProvider_BuildCtx(kw, 0, 0, SearchCenterFilterType, SearchCenterEngineMode))
}

_SCWV_TypeDataField(TypeData, Prop, Fallback) {
    if (TypeData is Map && TypeData.Has(Prop))
        return TypeData[Prop]
    try {
        if (TypeData.HasProp(Prop))
            return TypeData.%Prop%
    } catch {
    }
    return Fallback
}

_SCWV_MergeAllDataResultsIntoSearchLists(AllDataResults, keyword, offset) {
    global SearchCenterSearchResults
    NewResults := []

    for DataType, TypeData in AllDataResults {
        if !IsObject(TypeData)
            continue
        itemList := unset
        if (TypeData is Map) {
            if !TypeData.Has("Items")
                continue
            itemList := TypeData["Items"]
        } else {
            if !TypeData.HasProp("Items")
                continue
            itemList := TypeData.Items
        }
        if !IsObject(itemList)
            continue

        for _, Item in itemList {
            TimeDisplay := ""
            if (_SCWV_ResultItemHas(Item, "TimeFormatted")) {
                TimeDisplay := _SCWV_ResultItemGet(Item, "TimeFormatted", "")
            } else if (_SCWV_ResultItemHas(Item, "Timestamp")) {
                ts := _SCWV_ResultItemGet(Item, "Timestamp", "")
                try {
                    TimeDisplay := FormatTime(ts, "yyyy-MM-dd HH:mm:ss")
                } catch {
                    TimeDisplay := ts
                }
            }

            TitleText := ""
            if (_SCWV_ResultItemHas(Item, "DisplayTitle") && _SCWV_ResultItemGet(Item, "DisplayTitle", "") != "") {
                TitleText := _SCWV_ResultItemGet(Item, "DisplayTitle", "")
            } else if (_SCWV_ResultItemHas(Item, "Title") && _SCWV_ResultItemGet(Item, "Title", "") != "") {
                TitleText := _SCWV_ResultItemGet(Item, "Title", "")
            } else if (_SCWV_ResultItemHas(Item, "Content") && _SCWV_ResultItemGet(Item, "Content", "") != "") {
                c := _SCWV_ResultItemGet(Item, "Content", "")
                TitleText := SubStr(c, 1, 50)
                if (StrLen(c) > 50)
                    TitleText .= "..."
            }

            ItemDataType := ""
            meta := _SCWV_ResultItemGet(Item, "Metadata", 0)
            if (IsObject(meta)) {
                if (meta is Map && meta.Has("DataType") && meta["DataType"] != "")
                    ItemDataType := meta["DataType"]
                else if (meta.HasProp("DataType") && meta.DataType != "")
                    ItemDataType := meta.DataType
            }
            if (ItemDataType = "" && _SCWV_ResultItemHas(Item, "DataType")) {
                idt := _SCWV_ResultItemGet(Item, "DataType", "")
                if (idt != "" && idt != "clipboard" && idt != "template" && idt != "config" && idt != "file" && idt != "hotkey" && idt != "function" && idt != "ui")
                    ItemDataType := idt
            }

            if (ItemDataType = "" && DataType = "clipboard") {
                if (_SCWV_ResultItemHas(Item, "DataTypeName") && _SCWV_ResultItemGet(Item, "DataTypeName", "") != "") {
                    DataTypeName := _SCWV_ResultItemGet(Item, "DataTypeName", "")
                    if (DataTypeName = "代码片段" || DataTypeName = "代码")
                        ItemDataType := "Code"
                    else if (DataTypeName = "链接")
                        ItemDataType := "Link"
                    else if (DataTypeName = "邮箱" || DataTypeName = "邮件")
                        ItemDataType := "Email"
                    else if (DataTypeName = "图片")
                        ItemDataType := "Image"
                    else if (DataTypeName = "颜色")
                        ItemDataType := "Color"
                    else if (DataTypeName = "文本" || DataTypeName = "剪贴板历史")
                        ItemDataType := "Text"
                }
            }

            if (ItemDataType = "" && DataType != "clipboard") {
                if (DataType = "template")
                    ItemDataType := "Template"
                else if (DataType = "config")
                    ItemDataType := "Config"
                else if (DataType = "file")
                    ItemDataType := "File"
                else if (DataType = "hotkey")
                    ItemDataType := "Hotkey"
                else if (DataType = "function")
                    ItemDataType := "Function"
                else if (DataType = "ui")
                    ItemDataType := "UI"
                else if (DataType = "fulltext")
                    ItemDataType := "FullText"
            }

            if (ItemDataType = "")
                ItemDataType := (DataType = "clipboard") ? "Text" : DataType

            typeName := _SCWV_TypeDataField(TypeData, "DataTypeName", DataType)
            ResultItem := {
                Title: TitleText,
                Source: typeName,
                DataType: ItemDataType,
                Time: TimeDisplay,
                Content: _SCWV_ResultItemHas(Item, "Content") ? _SCWV_ResultItemGet(Item, "Content", "") : TitleText,
                ID: _SCWV_ResultItemHas(Item, "ID") ? _SCWV_ResultItemGet(Item, "ID", "") : "",
                OriginalDataType: DataType
            }
            if (_SCWV_ResultItemHas(Item, "Action") && _SCWV_ResultItemGet(Item, "Action", "") != "")
                ResultItem.Action := _SCWV_ResultItemGet(Item, "Action", "")
            if (_SCWV_ResultItemHas(Item, "ActionParams") && IsObject(_SCWV_ResultItemGet(Item, "ActionParams", 0)))
                ResultItem.ActionParams := _SCWV_ResultItemGet(Item, "ActionParams", 0)
            if (_SCWV_ResultItemHas(Item, "Metadata") && IsObject(_SCWV_ResultItemGet(Item, "Metadata", 0)))
                ResultItem.Metadata := _SCWV_ResultItemGet(Item, "Metadata", 0)
            if (_SCWV_ResultItemHas(Item, "DisplayTitle") && _SCWV_ResultItemGet(Item, "DisplayTitle", "") != "")
                ResultItem.DisplayTitle := _SCWV_ResultItemGet(Item, "DisplayTitle", "")
            if (_SCWV_ResultItemHas(Item, "Category") && _SCWV_ResultItemGet(Item, "Category", "") != "")
                ResultItem.Category := _SCWV_ResultItemGet(Item, "Category", "")
            if (_SCWV_ResultItemHas(Item, "TypeHint") && _SCWV_ResultItemGet(Item, "TypeHint", "") != "")
                ResultItem.TypeHint := _SCWV_ResultItemGet(Item, "TypeHint", "")
            if (_SCWV_ResultItemHas(Item, "FzyCategoryBonus"))
                ResultItem.FzyCategoryBonus := _SCWV_ResultItemGet(Item, "FzyCategoryBonus", "")
            if (_SCWV_ResultItemHas(Item, "DisplayPath") && _SCWV_ResultItemGet(Item, "DisplayPath", "") != "")
                ResultItem.DisplayPath := _SCWV_ResultItemGet(Item, "DisplayPath", "")
            if (_SCWV_ResultItemHas(Item, "DisplaySubtitle") && _SCWV_ResultItemGet(Item, "DisplaySubtitle", "") != "")
                ResultItem.DisplaySubtitle := _SCWV_ResultItemGet(Item, "DisplaySubtitle", "")
            if (_SCWV_ResultItemHas(Item, "SubCategory") && _SCWV_ResultItemGet(Item, "SubCategory", "") != "")
                ResultItem.SubCategory := _SCWV_ResultItemGet(Item, "SubCategory", "")
            if (_SCWV_ResultItemHas(Item, "CategoryColor") && _SCWV_ResultItemGet(Item, "CategoryColor", "") != "")
                ResultItem.CategoryColor := _SCWV_ResultItemGet(Item, "CategoryColor", "")
            if (_SCWV_ResultItemHas(Item, "PathTrust"))
                ResultItem.PathTrust := _SCWV_ResultItemGet(Item, "PathTrust", "")
            if (_SCWV_ResultItemHas(Item, "BonusTotal"))
                ResultItem.BonusTotal := _SCWV_ResultItemGet(Item, "BonusTotal", "")
            if (_SCWV_ResultItemHas(Item, "PenaltyTotal"))
                ResultItem.PenaltyTotal := _SCWV_ResultItemGet(Item, "PenaltyTotal", "")
            if (_SCWV_ResultItemHas(Item, "FzyBase"))
                ResultItem.FzyBase := _SCWV_ResultItemGet(Item, "FzyBase", "")
            if (_SCWV_ResultItemHas(Item, "FinalScore"))
                ResultItem.FinalScore := _SCWV_ResultItemGet(Item, "FinalScore", "")
            if (_SCWV_ResultItemHas(Item, "QuotaCategory"))
                ResultItem.QuotaCategory := _SCWV_ResultItemGet(Item, "QuotaCategory", "")

            if (offset = 0)
                SearchCenterSearchResults.Push(ResultItem)
            else
                NewResults.Push(ResultItem)
        }
    }

    if (offset > 0 && NewResults.Length > 0) {
        for _, item in NewResults
            SearchCenterSearchResults.Push(item)
    }

    if (offset = 0 && SearchCenterSearchResults.Length > 0 && StrLen(keyword) > 0) {
        try {
            Loop SearchCenterSearchResults.Length {
                scItem := SearchCenterSearchResults[A_Index]
                SyncIdentityToResultItem(&scItem, keyword)
            }
        } catch {
        }
    }

    if (offset = 0 && SearchCenterSearchResults.Length > 0) {
        global g_SCWV_SkipHostSort
        if !g_SCWV_SkipHostSort {
            try SortSearchCenterMergedResults(&SearchCenterSearchResults, keyword)
        }
        g_SCWV_SkipHostSort := false
        try _SCWV_SortPinnedFirst(SearchCenterSearchResults)
    }
}

; 标准模式：走宿主 SearchAllDataSources（与 DebouncedSearchCenter 数据源一致），需 CursorHelper 已加载 SearchAllDataSources / GetSearchCenterDataTypesForFilter
_SCWV_RunAhkSearch(offset := 0) {
    global SearchCenterWebKeyword, SearchCenterCurrentLimit, SearchCenterFilterType
    global SearchCenterSearchResults, SearchCenterHasMoreData, g_SCWV_SkipHostSort

    keyword := Trim(SearchCenterWebKeyword)
    if (keyword = "") {
        SearchCenterHasMoreData := false
        return
    }
    if (SearchCenterFilterType = "fulltext") {
        _SCWV_ExecuteGoSearchHttp(offset, keyword, "fulltext", SearchCenterCurrentLimit)
        return
    }
    FilterDataTypes := GetSearchCenterDataTypesForFilter(SearchCenterFilterType)
    if (FilterDataTypes.Length > 0) {
        hasFileType := false
        for _, dt in FilterDataTypes {
            if (dt = "file") {
                hasFileType := true
                break
            }
        }
        if (!hasFileType)
            FilterDataTypes.Push("file")
    }
    try {
        AllDataResults := SearchAllDataSources(keyword, FilterDataTypes, SearchCenterCurrentLimit, offset)
        SearchCenterHasMoreData := false
        for DataType, TypeData in AllDataResults {
            hm := false
            if (TypeData is Map)
                hm := TypeData.Has("HasMore") && TypeData["HasMore"]
            else if (IsObject(TypeData) && TypeData.HasProp("HasMore"))
                hm := TypeData.HasMore
            if (hm) {
                SearchCenterHasMoreData := true
                break
            }
        }
        g_SCWV_SkipHostSort := false
        if (offset = 0)
            SearchCenterSearchResults := []
        _SCWV_MergeAllDataResultsIntoSearchLists(AllDataResults, keyword, offset)
    } catch as err {
        try OutputDebug("[SCWV] SearchAllDataSources: " . err.Message)
    }
}

_SCWV_PerformSearch(keyword, offset := 0) {
    global SearchCenterSearchResults, SearchCenterHasMoreData, SearchCenterWebKeyword

    keyword := Trim(String(keyword))
    if (offset = 0)
        SearchCenterWebKeyword := keyword

    if (offset = 0)
        SearchCenterSearchResults := []

    if (offset = 0 && keyword != "")
        _SCWV_RecordSearchHistory(keyword)

    if (keyword = "") {
        SearchCenterHasMoreData := false
        _SCWV_LoadSearchHistory()
        return
    }
    ; 已迁移至 SearchCenterCore Go，不再调用 SearchAllDataSources；请使用 _SCWV_ExecuteGoSearchHttp
    SearchCenterHasMoreData := false
    SearchCenterSearchResults := []
}

_SCWV_ApplySearchResultSync(keyword, offset, hasMoreGo, GoItems, goType := "") {
    global SearchCenterSearchResults, SearchCenterHasMoreData, SearchCenterWebKeyword, g_SCWV_SkipHostSort
    global SearchCenterFilterType

    keyword := Trim(String(keyword))
    gt := Trim(String(goType))
    if (gt = "")
        gt := _SCWV_MapFilterToGoSearchType(SearchCenterFilterType)
    if (offset = 0) {
        SearchCenterWebKeyword := keyword
        SearchCenterSearchResults := []
        if (keyword != "")
            _SCWV_RecordSearchHistory(keyword)
    }

    if (keyword = "") {
        if (SearchCenterFilterType = "clipboard" || gt = "clipboard") {
            if (GoItems.Length > 0) {
                AllDataResults := _SCWV_GroupGoItemsToAllDataResults(GoItems, hasMoreGo)
                SearchCenterHasMoreData := hasMoreGo ? true : false
                g_SCWV_SkipHostSort := true
                _SCWV_MergeAllDataResultsIntoSearchLists(AllDataResults, "", offset)
                try _SCWV_PushClipFloatToWeb()
                catch {
                }
                return
            }
            limClip := SearchCenterCurrentLimit > 0 ? SearchCenterCurrentLimit : 30
            if (_SCWV_ApplyClipboardTimelineLocal("", offset, limClip))
                return
            global g_SCWV_ClipboardHomeLock
            if g_SCWV_ClipboardHomeLock {
                SearchCenterHasMoreData := false
                return
            }
        }
        SearchCenterHasMoreData := false
        _SCWV_LoadSearchHistory()
        return
    }

    AllDataResults := _SCWV_GroupGoItemsToAllDataResults(GoItems, hasMoreGo)
    SearchCenterHasMoreData := hasMoreGo ? true : false
    g_SCWV_SkipHostSort := true
    _SCWV_MergeAllDataResultsIntoSearchLists(AllDataResults, keyword, offset)
    if (offset = 0 && (SearchCenterFilterType = "" || SearchCenterFilterType = "all"))
        _SCWV_CacheAllResults(keyword)
}

_SCWV_ResultPinKey(Item) {
    if !IsObject(Item)
        return ""
    id := ""
    if (Item is Map && Item.Has("ID"))
        id := Trim(String(Item["ID"]))
    else if (Item.HasProp("ID"))
        id := Trim(String(Item.ID))
    if (id != "")
        return "id:" . id
    c := ""
    if (Item is Map) {
        if (Item.Has("Content"))
            c := Item["Content"]
        else if (Item.Has("Title"))
            c := Item["Title"]
    } else {
        c := Item.HasProp("Content") ? Item.Content : (Item.HasProp("Title") ? Item.Title : "")
    }
    return "c:" . StrLen(c) . ":" . SubStr(c, 1, 200)
}

_SCWV_SortPinnedFirst(arr) {
    global g_SCWV_PinnedKeys
    if !(arr is Array) || arr.Length = 0
        return
    pinned := []
    rest := []
    for it in arr {
        k := _SCWV_ResultPinKey(it)
        if (k != "" && g_SCWV_PinnedKeys.Has(k) && g_SCWV_PinnedKeys[k])
            pinned.Push(it)
        else
            rest.Push(it)
    }
    arr.Length := 0
    for it in pinned
        arr.Push(it)
    for it in rest
        arr.Push(it)
}

_SCWV_LoadDefaultTemplatesData() {
    global SearchCenterSearchResults, PromptTemplates

    SearchCenterSearchResults := []
    if !PromptTemplates
        LoadPromptTemplates()

    for template in PromptTemplates {
        SearchCenterSearchResults.Push({
            Title: template.Title,
            Content: template.Content,
            Source: "模板",
            DataType: "template",
            Time: "",
            OriginalDataType: "template"
        })
    }
}

_SCWV_GetFilteredResults() {
    global SearchCenterSearchResults, SearchCenterVisibleResults, SearchCenterFilterType, g_SCWV_PinnedKeys

    FilteredResults := []
    for _, res in SearchCenterSearchResults {
        ShouldInclude := false
        if (SearchCenterFilterType = "") {
            ShouldInclude := true
        } else if (SearchCenterFilterType = "clipboard") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "clipboard") || (res.HasProp("Source") && InStr(res.Source, "剪贴板") > 0)
        } else if (SearchCenterFilterType = "template") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "template") || (res.HasProp("Source") && (InStr(res.Source, "模板") > 0 || InStr(res.Source, "提示词") > 0))
        } else if (SearchCenterFilterType = "config") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "config") || (res.HasProp("Source") && InStr(res.Source, "配置") > 0)
        } else if (SearchCenterFilterType = "hotkey") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "hotkey") || (res.HasProp("Source") && InStr(res.Source, "快捷键") > 0)
        } else if (SearchCenterFilterType = "function") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "function") || (res.HasProp("Source") && InStr(res.Source, "功能") > 0)
        } else if (SearchCenterFilterType = "File") {
            ShouldInclude := (res.HasProp("OriginalDataType") && (res.OriginalDataType = "file" || res.OriginalDataType = "fulltext")) || (res.HasProp("DataType") && res.DataType = "File") || (res.HasProp("Source") && InStr(res.Source, "文件") > 0)
        } else if (SearchCenterFilterType = "fulltext") {
            fullHit := false
            if (res.HasProp("Metadata") && IsObject(res.Metadata)) {
                if (res.Metadata is Map)
                    fullHit := res.Metadata.Has("FullTextHit") && res.Metadata["FullTextHit"]
                else if (res.Metadata.HasProp("FullTextHit"))
                    fullHit := res.Metadata.FullTextHit
            }
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "fulltext") || fullHit || (res.HasProp("DataType") && (res.DataType = "FullText" || res.DataType = "fulltext"))
        } else if (SearchCenterFilterType = "pinned") {
            pk := _SCWV_ResultPinKey(res)
            ShouldInclude := (pk != "" && g_SCWV_PinnedKeys.Has(pk) && g_SCWV_PinnedKeys[pk])
        }

        if ShouldInclude
            FilteredResults.Push(res)
    }

    SearchCenterVisibleResults := FilteredResults
    return FilteredResults
}

SCWV_PushState(msgType := "state") {
    global SearchCenterWebKeyword, SearchCenterCurrentLimit, SearchCenterSelectedEngines, SearchCenterFilterType
    global SearchCenterHasMoreData, SearchCenterEngineMode
    global g_SCWV_RecycleBin, g_SCWV_PinnedKeys, g_SCWV_LifecyclePhase, g_SCWV_UiMode
    global g_SCWV_ActiveClientQueryID, g_SCWV_LoadingTier

    if !SearchCenter_ShouldUseWebView()
        return

    visible := _SCWV_GetFilteredResults()
    results := []
    for index, item in visible {
        rowTitle := (item.HasProp("DisplayTitle") && item.DisplayTitle != "") ? item.DisplayTitle : item.Title
        rowSubtitle := (item.HasProp("DisplaySubtitle") && item.DisplaySubtitle != "") ? item.DisplaySubtitle : item.Source
        typeDisplay := item.HasProp("DataType") ? item.DataType : ""
        if (item.HasProp("OriginalDataType") && item.OriginalDataType = "file" && item.HasProp("Category") && item.Category != "") {
            try typeDisplay := FileClassifier.GetCategoryDisplayName(item.Category)
        } else if (typeDisplay != "") {
            try typeDisplay := GetContentTypeDisplayName(typeDisplay)
        }
        pkRow := _SCWV_ResultPinKey(item)
        isPinned := (pkRow != "" && g_SCWV_PinnedKeys.Has(pkRow) && g_SCWV_PinnedKeys[pkRow])
        filePath := ""
        if (item.HasProp("OriginalDataType") && item.OriginalDataType = "file") || (item.HasProp("DataType") && (item.DataType = "File" || item.DataType = "Folder")) {
            cand := item.HasProp("Content") ? Trim(String(item.Content)) : ""
            if (cand != "" && (FileExist(cand) || DirExist(cand)))
                filePath := cand
        }
        if (filePath = "" && item.HasProp("Metadata") && item.Metadata is Map && item.Metadata.Has("FilePath")) {
            cand := Trim(String(item.Metadata["FilePath"]))
            if (cand != "" && (FileExist(cand) || DirExist(cand)))
                filePath := cand
        }
        if (filePath = "") {
            cand := item.HasProp("Content") ? Trim(String(item.Content)) : ""
            ot := item.HasProp("OriginalDataType") ? item.OriginalDataType : ""
            dt := item.HasProp("DataType") ? item.DataType : ""
            if (cand != "" && (FileExist(cand) || DirExist(cand)) && (ot = "file" || ot = "fulltext" || dt = "File" || dt = "Folder"))
                filePath := cand
        }
        sizeWeb := _SCWV_ResultSizeForWeb(item, filePath)
        modLabel := _SCWV_ResultModifiedForWeb(item, filePath)
        rowMap := Map(
            "row", index,
            "itemUid", _SCWV_SanitizeForJson(_SCWV_ResultActionUid(item, index)),
            "title", _SCWV_SanitizeForJson(rowTitle),
            "subtitle", _SCWV_SanitizeForJson(rowSubtitle),
            "type", _SCWV_SanitizeForJson(typeDisplay),
            "time", _SCWV_SanitizeForJson(item.HasProp("Time") ? item.Time : ""),
            "preview", _SCWV_SanitizeForJson(item.HasProp("Content") ? SubStr(item.Content, 1, 180) : rowTitle),
            "previewText", _SCWV_SanitizeForJson(BuildSearchCenterPreviewText(item)),
            "dataType", _SCWV_SanitizeForJson(item.HasProp("DataType") ? item.DataType : ""),
            "source", _SCWV_SanitizeForJson(item.HasProp("Source") ? item.Source : ""),
            "content", _SCWV_SanitizeForJson(item.HasProp("Content") ? item.Content : rowTitle),
            "path", _SCWV_SanitizeForJson(filePath),
            "pinned", isPinned ? true : false
        )
        metaWeb := _SCWV_ResultMetadataForWeb(item)
        if (metaWeb is Map)
            rowMap["metadata"] := metaWeb
        if (item.HasProp("OriginalDataType") && item.OriginalDataType != "")
            rowMap["originalDataType"] := _SCWV_SanitizeForJson(item.OriginalDataType)
        if (sizeWeb is Map) {
            if (sizeWeb.Has("sizeBytes") && Integer(sizeWeb["sizeBytes"]) > 0)
                rowMap["sizeBytes"] := Integer(sizeWeb["sizeBytes"])
            if (sizeWeb.Has("sizeLabel") && Trim(String(sizeWeb["sizeLabel"])) != "")
                rowMap["sizeLabel"] := _SCWV_SanitizeForJson(sizeWeb["sizeLabel"])
        }
        if (modLabel != "")
            rowMap["modifiedLabel"] := _SCWV_SanitizeForJson(modLabel)
        results.Push(rowMap)
    }

    recycleBin := []
    Loop g_SCWV_RecycleBin.Length {
        i := A_Index
        ent := g_SCWV_RecycleBin[i]
        if !(ent is Map)
            continue
        recycleBin.Push(Map(
            "index", i,
            "title", ent.Has("title") ? String(ent["title"]) : "",
            "preview", SubStr(ent.Has("content") ? String(ent["content"]) : "", 1, 140)
        ))
    }

    currentCategoryKey := GetSearchCenterCurrentCategoryKey()
    global g_SCWV_ClipboardHomeLock, g_SCWV_UiMode
    umStatus := StrLower(Trim(String(g_SCWV_UiMode)))
    if (umStatus = "clipboard" || SearchCenterFilterType = "clipboard") {
        status := "剪贴板时间线"
        if (results.Length > 0)
            status .= " · " . results.Length . " 条"
    } else if (umStatus = "fulltext" || SearchCenterFilterType = "fulltext") {
        status := "全文搜索"
        if (results.Length > 0)
            status .= " · " . results.Length . " 条命中"
    } else {
        status := "本地结果 " . results.Length . " 条"
        status .= " · 已选引擎 " . (IsObject(SearchCenterSelectedEngines) ? SearchCenterSelectedEngines.Length : 0) . " 个"
        status .= " · 当前限制 " . SearchCenterCurrentLimit
    }

    qlExe := SCWV_ResolveQuickLookExe()
    payload := Map(
        "type", msgType,
        "queryId", g_SCWV_ActiveClientQueryID,
        "uiMode", StrLower(Trim(String(g_SCWV_UiMode))),
        "themeMode", _SCWV_GetThemeMode(),
        "hostTopMost", SCWV_IsHostTopMost(),
        "hostLifecycle", g_SCWV_LifecyclePhase,
        "keyword", SearchCenterWebKeyword,
        "engineMode", SearchCenterEngineMode,
        "limit", SearchCenterCurrentLimit,
        "categories", _SCWV_BuildCategoryPayload(),
        "currentCategoryKey", currentCategoryKey,
        "engines", _SCWV_BuildEnginePayload(currentCategoryKey),
        "selectedEngines", _SCWV_CopyArray(SearchCenterSelectedEngines),
        "filters", _SCWV_BuildFilterPayload(),
        "filterType", SearchCenterFilterType,
        "results", results,
        "statusLine", status,
        "isCliCategory", (currentCategoryKey = "cli") ? true : false,
        "canRun", Trim(SearchCenterWebKeyword) != "",
        "canOpenCli", (currentCategoryKey = "cli") ? true : false,
        "hasMore", SearchCenterHasMoreData ? true : false,
        "total", results.Length,
        "recycleBin", recycleBin,
        "recycleCount", recycleBin.Length,
        "loadingTier", Trim(String(g_SCWV_LoadingTier)),
        "quickLook", Map(
            "installed", (qlExe != ""),
            "path", qlExe,
            "version", g_SCWV_QuickLookVersion,
            "installBusy", g_SCWV_QuickLookInstallBusy
        )
    )

    mtPush := StrLower(Trim(String(msgType)))
    umPush := StrLower(Trim(String(g_SCWV_UiMode)))
    if ((mtPush = "state" || mtPush = "init") && umPush = "local" && Trim(SearchCenterWebKeyword) = "" && Trim(String(SearchCenterFilterType)) = "" && !g_SCWV_ClipboardHomeLock && results.Length = 0)
        return

    try SCWV_PostJson(payload)
}

; 可选组件 QuickLook：优先用户下载目录，其次兼容旧版 lib 内置路径
SCWV_ResolveQuickLookExe() {
    global g_SCWV_QuickLookVersion
    v := Trim(String(g_SCWV_QuickLookVersion))
    if (v = "")
        v := "4.5.0"
    p1 := A_ScriptDir "\cache\addons\QuickLook-" . v . "\QuickLook.exe"
    if FileExist(p1)
        return p1
    p2 := A_ScriptDir "\lib\QuickLook\QuickLook.exe"
    if FileExist(p2)
        return p2
    return ""
}

_SCWV_Read7zListLog(path) {
    p := Trim(String(path))
    if (p = "" || !FileExist(p))
        return ""
    for enc in ["UTF-8", "CP0"] {
        try {
            t := FileRead(p, enc)
            if (Trim(t) != "")
                return t
        } catch {
        }
    }
    try return FileRead(p)
    catch {
        return ""
    }
}

_SCWV_ZipListTextHasQuickLookExe(t) {
    if (Trim(String(t)) = "")
        return false
    if InStr(t, "QuickLook.exe", false)
        return true
    return RegExMatch(t, "i)QuickLook\.exe") ? true : false
}

; 在中央目录/局部文件头附近搜索 ASCII 文件名（不依赖 7z 控制台编码）
_SCWV_ZipRawContainsQuickLookExe(zipPath) {
    z := Trim(String(zipPath))
    if (z = "" || !FileExist(z))
        return false
    needle := "QuickLook.exe"
    n := StrLen(needle)
    nb := Buffer(n)
    StrPut(needle, nb, "CP0")
    try sz := FileGetSize(z)
    catch {
        return false
    }
    if (sz < n)
        return false
    chunkMax := 2 * 1024 * 1024
    f := FileOpen(z, "r")
    if !f
        return false
    try {
        tailLen := Min(chunkMax, sz)
        f.Seek(sz - tailLen)
        buf := Buffer(tailLen, 0)
        f.RawRead(buf, tailLen)
        if _SCWV_BufferFindBytes(buf, nb, n)
            return true
        f.Seek(0)
        headLen := Min(chunkMax, sz)
        buf2 := Buffer(headLen, 0)
        f.RawRead(buf2, headLen)
        return _SCWV_BufferFindBytes(buf2, nb, n)
    } catch {
        return false
    } finally {
        try f.Close()
    }
}

_SCWV_BufferFindBytes(hay, needleBuf, n) {
    if !IsObject(hay) || hay.Size < n || n < 1
        return false
    lim := hay.Size - n
    pH := hay.Ptr
    pN := needleBuf.Ptr
    Loop lim + 1 {
        i := A_Index - 1
        match := true
        Loop n {
            j := A_Index - 1
            if NumGet(pH, i + j, "UChar") != NumGet(pN, j, "UChar") {
                match := false
                break
            }
        }
        if match
            return true
    }
    return false
}

_SCWV_QuickLookInspectArchive(zipPath) {
    z := Trim(String(zipPath))
    if (z = "" || !FileExist(z))
        return Map("ok", false, "message", "压缩包不存在")
    ; Avoid synchronous external 7z listing on AHK UI thread.
    ; Use raw ZIP filename scan to detect QuickLook.exe.
    if _SCWV_ZipRawContainsQuickLookExe(z)
        return Map("ok", true, "hasExe", true, "list", "(zip raw filename scan)")
    return Map("ok", true, "hasExe", false, "list", "(zip raw filename scan: not found)")
}

_SCWV_QuickLookFindPortableRoot(dir) {
    root := Trim(String(dir))
    if (root = "" || !DirExist(root))
        return ""
    found := ""
    Loop Files root "\*", "R" {
        if (A_LoopFileName != "QuickLook.exe")
            continue
        found := A_LoopFileDir
        break
    }
    return found
}

; QuickLook 下载进度回调（供 Bind 固定 percent，避免胖箭头捕获 for 循环变量 idx 导致未赋值错误）
_SCWV_QuickLookDownloadStatusCb(percent, msg) {
    SCWV_QuickLookInstall_PostProgress(Integer(percent), String(msg))
}

; WinHttp 分段下载：状态行（Bind 固定 idx / 源总数 / 源名称）
SCWV_QuickLookInstall_OnHttpStatus(idx, n, label, msg) {
    SCWV_QuickLookInstall_PostProgress(Min(92, 6 + (idx - 1) * 3), "① 下载 · [" . idx . "/" . n . " " . label . "] " . String(msg))
}

; WinHttp 分段下载：进度（Bind 固定 idx / n / label；回调参数 pct, written, total）
SCWV_QuickLookInstall_OnHttpProgress(idx, n, label, pct, written, total) {
    span := 34 / n
    base := 10 + (idx - 1) * span
    overall := Floor(Min(48, base + (pct / 100) * span))
    wMb := Round(written / 1048576, 2)
    tMb := total > 0 ? Round(total / 1048576, 2) : 0
    line := total > 0 ? (wMb . " / " . tMb . " MB · " . pct . "%") : (wMb . " MB · " . pct . "%")
    SCWV_QuickLookInstall_PostProgress(overall, "① 下载 · [" . idx . "/" . n . " " . label . "] " . line)
}

; QuickLook 专用下载（与 Hub 词典同源逻辑；定义在本模块，避免依赖 #Include 顺序）
_SCWV_QuickLookDownloadByBuiltin(url, savePath, statusCb := 0) {
    u := Trim(String(url))
    outPath := Trim(String(savePath))
    if (u = "")
        return Map("ok", false, "message", "下载地址为空")
    if (outPath = "")
        return Map("ok", false, "message", "下载目标路径为空")
    ret := 0
    try {
        ; 优先复用“翻译设置”里的内置下载实现，保证下载链路一致
        try {
            fnBuiltin := Func("SelectionSense_HubDictInstall_DownloadByBuiltin")
            ret := fnBuiltin.Call(u, outPath, statusCb)
        } catch {
            SplitPath(outPath, , &outDir)
            if (outDir != "" && !DirExist(outDir))
                DirCreate(outDir)
            if FileExist(outPath)
                FileDelete(outPath)
            if IsObject(statusCb)
                statusCb.Call("正在下载 QuickLook（内置通道）…")
            Download(u, outPath)
            ret := Map("ok", true)
        }

        if !(ret is Map)
            ret := Map("ok", false, "message", "内置下载返回值异常")
        if !(ret.Has("ok") && ret["ok"]) {
            msg0 := ret.Has("message") ? String(ret["message"]) : "内置下载失败"
            return Map("ok", false, "message", msg0)
        }

        sz := 0
        try sz := FileGetSize(outPath)
        catch {
            sz := 0
        }
        if (sz <= 0)
            return Map("ok", false, "message", "下载结果为空（0 字节）")
        if (sz < 256 * 1024)
            return Map("ok", false, "message", "下载文件过小（" . Round(sz / 1024, 1) . "KB），疑似错误页或网络受限")
        if !_SCWV_FileLooksLikeZip(outPath)
            return Map("ok", false, "message", "文件头非 ZIP（GitHub 等资源需跟随 302 重定向，当前结果可能为网页）")
        return Map("ok", true, "bytes", sz, "total", sz, "path", outPath, "via", "builtin")
    } catch as e {
        return Map("ok", false, "message", "下载失败: " . e.Message)
    }
}

; 本地文件是否为常见 ZIP 魔数（排除 HTML/JSON 错误页）
_SCWV_FileLooksLikeZip(path) {
    p := Trim(String(path))
    if (p = "" || !FileExist(p))
        return false
    try sz := FileGetSize(p)
    catch {
        return false
    }
    if (sz < 4)
        return false
    f := FileOpen(p, "r")
    if !f
        return false
    try {
        b := Buffer(8, 0)
        nRead := f.RawRead(b, 8)
        if (nRead < 4)
            return false
        b0 := NumGet(b, 0, "UChar")
        b1 := NumGet(b, 1, "UChar")
        b2 := NumGet(b, 2, "UChar")
        b3 := NumGet(b, 3, "UChar")
        if (b0 = 0x3C)
            return false
        if (b0 = 0x50 && b1 = 0x4B) {
            if (b2 = 0x03 && b3 = 0x04)
                return true
            if (b2 = 0x05 && b3 = 0x06)
                return true
            if (b2 = 0x07 && b3 = 0x08)
                return true
        }
    } finally {
        try f.Close()
    }
    return false
}

; 依次尝试：内置下载（对齐翻译设置）→ WinHttp COM → curl -L（跟随 GitHub 302）→ 低层 WinHttp（末选）
_SCWV_QuickLookDownloadTryAll(url, zipPath, idx, nSrc, label, reportPath) {
    u := Trim(String(url))
    outPath := Trim(String(zipPath))
    if (u = "" || outPath = "")
        return Map("ok", false, "message", "参数无效")
    errors := []
    SplitPath(outPath, , &outDir)
    if (outDir != "" && !DirExist(outDir))
        DirCreate(outDir)
    if FileExist(outPath)
        try FileDelete(outPath)
    catch {
    }

    ; 1) 内置下载：和翻译设置同链路
    SCWV_QuickLookInstall_PostProgress(Min(46, 10 + idx * 3), "① 下载 · [" . idx . "/" . nSrc . " " . label . "] 内置下载（与翻译设置同链路）…")
    dlBuiltin := _SCWV_QuickLookDownloadByBuiltin(u, outPath, 0)
    if (dlBuiltin.Has("ok") && dlBuiltin["ok"]) {
        szBuiltin := dlBuiltin.Has("bytes") ? Integer(dlBuiltin["bytes"]) : 0
        if (szBuiltin <= 0) {
            try szBuiltin := FileGetSize(outPath)
            catch {
                szBuiltin := 0
            }
        }
        return Map("ok", true, "bytes", szBuiltin, "via", "builtin")
    }
    errBuiltin := dlBuiltin.Has("message") ? String(dlBuiltin["message"]) : "内置下载失败"
    errors.Push("内置下载: " . errBuiltin)
    _SCWV_QuickLookInstallReportLine(reportPath, errors[errors.Length])
    try FileDelete(outPath)
    catch {
    }

    ; 2) WinHttp COM 同步分支软禁用（避免 false 同步阻塞）
    errors.Push("COM: skipped(sync_blocked_core_async_strict)")
    _SCWV_QuickLookInstallReportLine(reportPath, errors[errors.Length])

    ; 3) 低层 WinHttp（末选）
    progressCb := SCWV_QuickLookInstall_OnHttpProgress.Bind(idx, nSrc, label)
    statusCb := SCWV_QuickLookInstall_OnHttpStatus.Bind(idx, nSrc, label)
    SCWV_QuickLookInstall_PostProgress(Min(46, 13 + idx * 3), "① 下载 · [" . idx . "/" . nSrc . " " . label . "] WinHttp 底层（无自动重定向，末选）…")
    dl2 := Map("ok", false, "message", "")
    try {
        dl2 := SelectionSense_HubDictInstall_DownloadByWinHttp(u, outPath, progressCb, statusCb)
    } catch as eW {
        dl2 := Map("ok", false, "message", eW.Message)
    }
    if (dl2.Has("ok") && dl2["ok"]) {
        try sz3 := FileGetSize(outPath)
        catch {
            sz3 := 0
        }
        if (sz3 >= 200 * 1024 && _SCWV_FileLooksLikeZip(outPath))
            return Map("ok", true, "bytes", sz3, "via", "winhttp-dll")
        try FileDelete(outPath)
        catch {
        }
        errors.Push("WinHttp: 已拉取 " . Round(sz3 / 1024, 1) . "KB 但非有效 ZIP")
        _SCWV_QuickLookInstallReportLine(reportPath, errors[errors.Length])
    } else {
        errors.Push("WinHttp: " . (dl2.Has("message") ? String(dl2["message"]) : "失败"))
        _SCWV_QuickLookInstallReportLine(reportPath, errors[errors.Length])
    }
    merged := ""
    for i, e in errors
        merged .= (i > 1 ? " | " : "") . e
    if (merged = "")
        merged := "所有下载通道均失败"
    return Map("ok", false, "message", merged)
}

_SCWV_QuickLookInstallReportLine(reportPath, text) {
    rp := Trim(String(reportPath))
    if (rp = "")
        return
    line := "[" . A_Now . "] " . String(text) . "`r`n"
    try FileAppend(line, rp, "UTF-8")
    catch {
    }
}

SCWV_QuickLookInstall_PostProgress(percent, message := "") {
    SCWV_PostJson(Map(
        "type", "quicklook_install_progress",
        "percent", Integer(percent),
        "message", String(message)
    ))
}

; 下载并解压 QuickLook 便携包到 cache\addons\QuickLook-<version>（流程对齐 Hub 词典 SQLite 包安装）
SCWV_QuickLookInstall_RunInner() {
    global g_SCWV_QuickLookVersion, g_SCWV_QuickLookInstallBusy
    v := Trim(String(g_SCWV_QuickLookVersion))
    if (v = "")
        v := "4.5.0"
    zipName := "QuickLook-" . v . ".zip"
    baseGh := "https://github.com/QL-Win/QuickLook/releases/download/" . v . "/" . zipName
    urls := [
        baseGh,
        "https://ghproxy.com/https://github.com/QL-Win/QuickLook/releases/download/" . v . "/" . zipName,
        "https://ghproxy.net/https://github.com/QL-Win/QuickLook/releases/download/" . v . "/" . zipName,
        "https://kkgithub.com/QL-Win/QuickLook/releases/download/" . v . "/" . zipName
    ]
    srcNames := ["GitHub 官方", "ghproxy.com", "ghproxy.net", "kkgithub.com"]
    nSrc := urls.Length
    workDir := A_ScriptDir "\cache\quicklook_install"
    zipPath := workDir "\" . zipName
    staging := workDir "\staging_" . A_TickCount
    finalDir := A_ScriptDir "\cache\addons\QuickLook-" . v
    reportPath := workDir "\install_report.txt"
    sevenZip := Nmer_LibRuntimePath("7z.exe")

    if !DirExist(workDir)
        DirCreate(workDir)
    if !DirExist(A_ScriptDir "\cache\addons")
        DirCreate(A_ScriptDir "\cache\addons")

    try FileDelete(reportPath)
    catch {
    }
    _SCWV_QuickLookInstallReportLine(reportPath, "开始 QuickLook 可选组件安装")
    _SCWV_QuickLookInstallReportLine(reportPath, "目标目录: " . finalDir)

    if !FileExist(sevenZip) {
        SCWV_QuickLookInstall_PostProgress(0, "缺少 lib\\runtime\\7z.exe，无法解压")
        SCWV_PostJson(Map("type", "quicklook_install_state", "ok", false, "message", "缺少解压组件 lib\\runtime\\7z.exe", "path", ""))
        return
    }

    SCWV_QuickLookInstall_PostProgress(5, "流程：① 内置下载（同翻译设置）优先，失败再 COM/curl/WinHttp → ② ZIP 与包内 QuickLook.exe 校验 → ③ 解压落盘。共 " . nSrc . " 个镜像将依次尝试。")
    packageReady := false
    selectedUrl := ""
    downloadErrors := []

    for idx, url in urls {
        label := srcNames[idx]
        _SCWV_QuickLookInstallReportLine(reportPath, "尝试源" . idx . " (" . label . "): " . url)
        dl := _SCWV_QuickLookDownloadTryAll(url, zipPath, idx, nSrc, label, reportPath)
        if (dl.Has("ok") && dl["ok"]) {
            if dl.Has("via")
                _SCWV_QuickLookInstallReportLine(reportPath, "下载成功，通道: " . dl["via"])
            try szOk := FileGetSize(zipPath)
            catch {
                szOk := 0
            }
            SCWV_QuickLookInstall_PostProgress(49, "② 校验 · [" . idx . "/" . nSrc . " " . label . "] 已下载 " . Round(szOk / 1048576, 2) . " MB，检测 QuickLook.exe …")
            info := _SCWV_QuickLookInspectArchive(zipPath)
            if !(info.Has("ok") && info["ok"]) {
                errMsg := info.Has("message") ? String(info["message"]) : "压缩包检测失败"
                downloadErrors.Push("#" . idx . " " . label . ": " . errMsg)
                _SCWV_QuickLookInstallReportLine(reportPath, "源" . idx . "列表失败: " . errMsg)
                try FileDelete(zipPath)
                catch {
                }
                if (idx < nSrc)
                    SCWV_QuickLookInstall_PostProgress(18, "③ 自动切换 · 源 " . idx . " 列表失败 → 下一源 " . (idx + 1) . "/" . nSrc . " …")
                continue
            }
            if !(info.Has("hasExe") && info["hasExe"]) {
                downloadErrors.Push("#" . idx . " " . label . ": 包内未找到 QuickLook.exe")
                _SCWV_QuickLookInstallReportLine(reportPath, "源" . idx . "包内无 QuickLook.exe（已尝试 7z 列表/findstr/二进制扫描）")
                try FileDelete(zipPath)
                catch {
                }
                if (idx < nSrc)
                    SCWV_QuickLookInstall_PostProgress(18, "③ 自动切换 · 源 " . idx . " 校验未通过 → 下一源 " . (idx + 1) . "/" . nSrc . " …")
                continue
            }
            packageReady := true
            selectedUrl := url
            _SCWV_QuickLookInstallReportLine(reportPath, "选定源: " . selectedUrl)
            break
        }
        errMsg := dl.Has("message") ? String(dl["message"]) : "下载失败"
        downloadErrors.Push("#" . idx . " " . label . ": " . errMsg)
        _SCWV_QuickLookInstallReportLine(reportPath, "源" . idx . "下载失败: " . errMsg)
        if (idx < nSrc)
            SCWV_QuickLookInstall_PostProgress(16, "③ 自动切换 · 源 " . idx . " 下载失败 → 下一源 " . (idx + 1) . "/" . nSrc . " …")
    }

    if !packageReady {
        merged := "全部 " . nSrc . " 个地址均未成功，请检查网络或稍后重试"
        if downloadErrors.Length {
            merged .= " 详情："
            for i, e in downloadErrors
                merged .= (i > 1 ? " | " : "") . e
        }
        SCWV_QuickLookInstall_PostProgress(0, merged)
        SCWV_PostJson(Map("type", "quicklook_install_state", "ok", false, "message", merged, "path", ""))
        _SCWV_QuickLookInstallReportLine(reportPath, "终止: 无可用下载源")
        return
    }

    SCWV_QuickLookInstall_PostProgress(58, "正在解压…")
    try DirDelete(staging, 1)
    catch {
    }
    if !DirExist(staging)
        DirCreate(staging)

    cmdAll := '"' . sevenZip . '" x -y -aoa -o"' . staging . '" -- "' . zipPath . '"'
    ctx := Map("staging", staging, "finalDir", finalDir, "reportPath", reportPath)
    okAsync := _SCWV_RunHiddenCommandAsync(cmdAll, (ok, why, pid) => _SCWV_QuickLookInstall_OnExtractDone(ok, why, pid, ctx), 180000, "quicklook_extract")
    if !okAsync {
        SCWV_QuickLookInstall_PostProgress(0, "解压任务启动失败")
        SCWV_PostJson(Map("type", "quicklook_install_state", "ok", false, "message", "解压任务启动失败", "path", ""))
        return
    }
    return Map("pending", true)
}

_SCWV_QuickLookInstall_OnExtractDone(ok, why, pid, ctx) {
    global g_SCWV_QuickLookInstallBusy
    _SCWV_QuickLookInstallReportLine(ctx["reportPath"], "7z 全量解压完成: ok=" . (ok ? "1" : "0") . " why=" . why . " pid=" . pid)
    if !ok {
        SCWV_QuickLookInstall_PostProgress(0, "解压超时或失败")
        SCWV_PostJson(Map("type", "quicklook_install_state", "ok", false, "message", "解压失败", "path", ""))
        g_SCWV_QuickLookInstallBusy := false
        try SCWV_PushState("state")
        return
    }
    portableRoot := _SCWV_QuickLookFindPortableRoot(ctx["staging"])
    if (portableRoot = "" || !FileExist(portableRoot "\QuickLook.exe")) {
        SCWV_QuickLookInstall_PostProgress(0, "解压后未找到 QuickLook.exe")
        SCWV_PostJson(Map("type", "quicklook_install_state", "ok", false, "message", "解压后未找到 QuickLook.exe", "path", ""))
        _SCWV_QuickLookInstallReportLine(ctx["reportPath"], "未找到 QuickLook.exe 于 staging")
        g_SCWV_QuickLookInstallBusy := false
        try SCWV_PushState("state")
        return
    }
    SCWV_QuickLookInstall_PostProgress(82, "写入安装目录…")
    try {
        if DirExist(ctx["finalDir"])
            DirDelete(ctx["finalDir"], 1)
    } catch as e0 {
        _SCWV_QuickLookInstallReportLine(ctx["reportPath"], "删除旧目录失败: " . e0.Message)
    }
    try DirCopy(portableRoot, ctx["finalDir"], 1)
    catch as e1 {
        SCWV_QuickLookInstall_PostProgress(0, "复制失败: " . e1.Message)
        SCWV_PostJson(Map("type", "quicklook_install_state", "ok", false, "message", "复制到安装目录失败", "path", ""))
        _SCWV_QuickLookInstallReportLine(ctx["reportPath"], "DirCopy 失败: " . e1.Message)
        g_SCWV_QuickLookInstallBusy := false
        try SCWV_PushState("state")
        return
    }
    exeFinal := ctx["finalDir"] . "\QuickLook.exe"
    if !FileExist(exeFinal) {
        SCWV_QuickLookInstall_PostProgress(0, "安装目录缺少 QuickLook.exe")
        SCWV_PostJson(Map("type", "quicklook_install_state", "ok", false, "message", "安装校验失败", "path", ""))
        g_SCWV_QuickLookInstallBusy := false
        try SCWV_PushState("state")
        return
    }
    _SCWV_QuickLookInstallReportLine(ctx["reportPath"], "安装成功: " . exeFinal)
    SCWV_QuickLookInstall_PostProgress(100, "QuickLook 已就绪")
    SCWV_PostJson(Map("type", "quicklook_install_state", "ok", true, "message", "QuickLook 安装完成", "path", exeFinal))
    g_SCWV_QuickLookInstallBusy := false
    try SCWV_PushState("state")
}

SCWV_QuickLookInstall_AsyncWorker(*) {
    global g_SCWV_QuickLookInstallQueued, g_SCWV_QuickLookInstallBusy
    g_SCWV_QuickLookInstallQueued := false
    pendingAsync := false
    try {
        ret := SCWV_QuickLookInstall_RunInner()
        if (ret is Map && ret.Has("pending") && ret["pending"])
            pendingAsync := true
    } catch as err {
        SCWV_PostJson(Map("type", "quicklook_install_state", "ok", false, "message", "安装异常: " . err.Message, "path", ""))
    } finally {
        if !pendingAsync {
            g_SCWV_QuickLookInstallBusy := false
            try SCWV_PushState("state")
            catch {
            }
        }
    }
}

SCWV_QuickLookInstall_RequestStart() {
    global g_SCWV_QuickLookInstallBusy, g_SCWV_QuickLookInstallQueued
    if g_SCWV_QuickLookInstallBusy || g_SCWV_QuickLookInstallQueued
        return false
    ex := SCWV_ResolveQuickLookExe()
    if (ex != "")
        return false
    g_SCWV_QuickLookInstallQueued := true
    g_SCWV_QuickLookInstallBusy := true
    SCWV_QuickLookInstall_PostProgress(2, "准备下载 QuickLook…")
    SetTimer(SCWV_QuickLookInstall_AsyncWorker, -10)
    return true
}

_SCWV_BuildFilterPayload() {
    return [
        Map("key", "", "text", "全部"),
        Map("key", "File", "text", "文件"),
        Map("key", "template", "text", "提示词"),
        Map("key", "config", "text", "配置"),
        Map("key", "hotkey", "text", "快捷键"),
        Map("key", "pinned", "text", "置顶")
    ]
}

_SCWV_BuildCategoryPayload() {
    Categories := GetSearchCenterCategories()
    payload := []
    for _, Category in Categories {
        engines := _SCWV_LoadSelectedEngines(Category.Key)
        payload.Push(Map(
            "key", Category.Key,
            "text", Category.Text,
            "selectedCount", engines.Length
        ))
    }
    return payload
}

_SCWV_BuildEnginePayload(CategoryKey) {
    engines := GetSortedSearchEngines(CategoryKey)
    payload := []
    for _, engine in engines {
        iconPath := GetSearchEngineIcon(engine.Value)
        payload.Push(Map(
            "name", engine.Name,
            "value", engine.Value,
            "iconUrl", _SCWV_PathToWebAssetUrl(iconPath)
        ))
    }
    return payload
}

_SCWV_PathToWebAssetUrl(path) {
    p := Trim(path)
    if (p = "" || !FileExist(p))
        return ""

    ; 浼樺厛妫€鏌ユ槸鍚﹀湪鑴氭湰鐩綍鍐咃紙璧勪骇鐩綍锛?
    scriptRoot := StrReplace(A_ScriptDir, "\", "/")
    normalized := StrReplace(p, "\", "/")
    
    resUrl := ""
    if (SubStr(normalized, 1, 1) != "/" && SubStr(normalized, 2, 1) != ":") {
        ; 鐩稿璺緞
    } else {
        scriptRootWithSlash := scriptRoot . "/"
        if (SubStr(normalized, 1, StrLen(scriptRootWithSlash)) = scriptRootWithSlash) {
            relativePath := StrReplace(SubStr(normalized, StrLen(scriptRootWithSlash) + 1), "\", "/")
            ; Virtual host 映射到 A_ScriptDir：assets/icons、lib/runtime 等应直链，勿加 assets/ 前缀
            resUrl := BuildAppLocalUrl(relativePath)
        }
    }

    if (resUrl = "" && RegExMatch(p, "^([a-zA-Z]):\\", &m)) {
        drive := StrLower(m[1])
        relativePath := SubStr(p, 4)
        encodedSegs := []
        for _, seg in StrSplit(relativePath, "\") {
            if (seg = "")
                continue
            encodedSegs.Push(_SCWV_UrlEncode(seg))
        }
        resUrl := "https://" . drive . ".local/" . _SCWV_JoinArray(encodedSegs, "/")
    }

    return resUrl
}

_SCWV_JoinArray(arr, sep := ",") {
    out := ""
    for i, v in arr {
        if (i > 1)
            out .= sep
        out .= String(v)
    }
    return out
}

_SCWV_UrlEncode(str) {
    fEscaped := ""
    Loop Parse, str {
        if RegExMatch(A_LoopField, "[0-9a-zA-Z\-\.\_\~\/]")
            fEscaped .= A_LoopField
        else {
            buf := Buffer(4, 0)
            len := StrPut(A_LoopField, buf, "UTF-8")
            Loop len - 1 {
                fEscaped .= "%" . Format("{:02X}", NumGet(buf, A_Index - 1, "UChar"))
            }
        }
    }
    return fEscaped
}

_SCWV_UrlDecode(str) {
    res := ""
    i := 1
    while i <= StrLen(str) {
        c := SubStr(str, i, 1)
        if (c = "%") {
            buf := Buffer(StrLen(str) // 3 + 1, 0)
            count := 0
            while i <= StrLen(str) && SubStr(str, i, 1) = "%" {
                hex := SubStr(str, i + 1, 2)
                NumPut("char", "0x" . hex, buf, count++)
                i += 3
            }
            res .= StrGet(buf, count, "UTF-8")
        } else {
            res .= c
            i += 1
        }
    }
    return res
}

_SCWV_CopyArray(arr) {
    out := []
    if !IsObject(arr)
        return out
    for _, v in arr
        out.Push(v)
    return out
}

_SCWV_ResultActionUid(item, row := 0) {
    if !IsObject(item)
        return ""
    pk := _SCWV_ResultPinKey(item)
    if (pk != "")
        return pk
    t := item.HasProp("Title") ? String(item.Title) : ""
    s := item.HasProp("Source") ? String(item.Source) : ""
    tm := item.HasProp("Time") ? String(item.Time) : ""
    c := item.HasProp("Content") ? SubStr(String(item.Content), 1, 64) : ""
    return "row:" . Integer(row) . "|" . t . "|" . s . "|" . tm . "|" . c
}

_SCWV_EnsureCurrentCategoryState() {
    global SearchCenterSelectedEngines

    Categories := GetSearchCenterCategories()
    if (Categories.Length = 0)
        return

    currentKey := GetSearchCenterCurrentCategoryKey()
    SearchCenterSelectedEngines := _SCWV_LoadSelectedEngines(currentKey)
}

_SCWV_SaveCurrentCategorySelection() {
    global SearchCenterSelectedEngines

    CategoryKey := GetSearchCenterCurrentCategoryKey()
    _SCWV_SaveSelectedEngines(CategoryKey, SearchCenterSelectedEngines)
}

_SCWV_SetCategoryByKey(CategoryKey) {
    global SearchCenterCurrentCategory, SearchCenterSelectedEngines

    _SCWV_SaveCurrentCategorySelection()

    Categories := GetSearchCenterCategories()
    for index, Category in Categories {
        if (Category.Key = CategoryKey) {
            SearchCenterCurrentCategory := index - 1
            break
        }
    }
    SearchCenterSelectedEngines := _SCWV_LoadSelectedEngines(CategoryKey)
    if SCWV_FuncExists("SCWV_IsWebSearchUIMode") && SCWV_IsWebSearchUIMode()
        _SCWV_EnsureDefaultWebEngines(CategoryKey)
}

_SCWV_LoadSelectedEngines(CategoryKey) {
    global SearchCenterSelectedEnginesByCategory, ConfigFile

    if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory))
        SearchCenterSelectedEnginesByCategory := Map()

    if (SearchCenterSelectedEnginesByCategory.Has(CategoryKey))
        return _SCWV_CopyArray(SearchCenterSelectedEnginesByCategory[CategoryKey])

    Engines := []
    try {
        CategoryEnginesStr := IniRead(ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey, "")
        if (CategoryEnginesStr != "") {
            if (InStr(CategoryEnginesStr, ":") > 0)
                CategoryEnginesStr := SubStr(CategoryEnginesStr, InStr(CategoryEnginesStr, ":") + 1)
            for _, Engine in StrSplit(CategoryEnginesStr, ",") {
                Engine := Trim(Engine)
                if (Engine != "")
                    Engines.Push(Engine)
            }
        }
    } catch {
    }

    ; 鍏煎鏃х増鏈細娓呴櫎鍘嗗彶榛樿椤癸紙鍚?openclaw/codex_cli锛夛紝閬垮厤鑷姩閫変腑
    if (Engines.Length = 1) {
        legacy := StrLower(Trim(Engines[1]))
        if (legacy = "codex_cli" || legacy = "openclaw" || legacy = "openclaw_cli")
            Engines := []
    }

    ; 浠呬繚鐣欏綋鍓嶅垎绫讳腑鏈夋晥鐨勫紩鎿庡€硷紝闃叉璺ㄥ垎绫绘畫鐣欏鑷磋鏁板紓甯革紙渚嬪 AI 鏄剧ず 1锛?
    valid := Map()
    try {
        for _, engine in GetSortedSearchEngines(CategoryKey) {
            ev := engine.HasProp("Value") ? String(engine.Value) : ""
            if (ev != "")
                valid[ev] := true
        }
    } catch {
    }
    filtered := []
    for _, ev in Engines {
        v := String(ev)
        if (v != "" && valid.Has(v))
            filtered.Push(v)
    }
    Engines := filtered

    ; CLI 鍒嗙被涓嶅啀璁剧疆榛樿寮曟搸锛屽繀椤荤敱鐢ㄦ埛鎵嬪姩閫夋嫨鍚庢墠鐢熸晥

    SearchCenterSelectedEnginesByCategory[CategoryKey] := _SCWV_CopyArray(Engines)
    return Engines
}

_SCWV_SaveSelectedEngines(CategoryKey, Engines) {
    global SearchCenterSelectedEnginesByCategory, ConfigFile

    if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory))
        SearchCenterSelectedEnginesByCategory := Map()

    SearchCenterSelectedEnginesByCategory[CategoryKey] := _SCWV_CopyArray(Engines)

    EnginesStr := ""
    if IsObject(Engines) {
        for index, Engine in Engines {
            if (index > 1)
                EnginesStr .= ","
            EnginesStr .= Engine
        }
    }
    try IniWrite(CategoryKey . ":" . EnginesStr, ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey)
}

_SCWV_ApplySelectedEnginesFromWeb(raw) {
    global SearchCenterSelectedEngines

    _SCWV_EnsureCurrentCategoryState()
    CategoryKey := GetSearchCenterCurrentCategoryKey()
    if !IsObject(SearchCenterSelectedEngines)
        SearchCenterSelectedEngines := []
    if !(raw is Array)
        return false
    valid := Map()
    try {
        for _, engine in GetSortedSearchEngines(CategoryKey) {
            ev := engine.HasProp("Value") ? String(engine.Value) : ""
            if (ev != "")
                valid[ev] := true
        }
    } catch {
    }
    next := []
    for _, ev in raw {
        v := Trim(String(ev))
        if (v != "" && (!valid.Count || valid.Has(v)))
            next.Push(v)
    }
    if (next.Length = 0)
        return false
    if (next.Length = SearchCenterSelectedEngines.Length) {
        same := true
        for i, v in next {
            if (SearchCenterSelectedEngines[i] != v) {
                same := false
                break
            }
        }
        if same
            return false
    }
    SearchCenterSelectedEngines := next
    _SCWV_SaveSelectedEngines(CategoryKey, SearchCenterSelectedEngines)
    return true
}

_SCWV_ToggleEngine(EngineValue) {
    global SearchCenterSelectedEngines

    _SCWV_EnsureCurrentCategoryState()
    CategoryKey := GetSearchCenterCurrentCategoryKey()
    if !IsObject(SearchCenterSelectedEngines)
        SearchCenterSelectedEngines := []

    idx := ArrayContainsValue(SearchCenterSelectedEngines, EngineValue)
    if (idx > 0) {
        if (SCWV_IsWebSearchUIMode() && SearchCenterSelectedEngines.Length <= 1)
            return
        SearchCenterSelectedEngines.RemoveAt(idx)
    } else {
        SearchCenterSelectedEngines.Push(EngineValue)
    }

    _SCWV_SaveSelectedEngines(CategoryKey, SearchCenterSelectedEngines)
}

_SCWV_EnsureSearchDataReady() {
    global SearchCenterSearchResults, SearchCenterWebKeyword

    ; WebView 首屏由 _SCWV_RefreshLocalHomeView / LoadSearchHistory 负责，不在 init 预灌模板
    if SearchCenter_ShouldUseWebView()
        return

    if (Trim(SearchCenterWebKeyword) = "") {
        if !IsObject(SearchCenterSearchResults) || SearchCenterSearchResults.Length = 0
            _SCWV_LoadDefaultTemplatesData()
        return
    }

    if !IsObject(SearchCenterSearchResults) || SearchCenterSearchResults.Length = 0
        _SCWV_ExecuteGoSearchHttp(0, SearchCenterWebKeyword, "", 0)
}

_SCWV_BatchSearch() {
    global SearchCenterSelectedEngines, SearchCenterWebKeyword

    _SCWV_EnsureCurrentCategoryState()
    if SCWV_IsWebSearchUIMode()
        _SCWV_EnsureDefaultWebEngines(GetSearchCenterCurrentCategoryKey())

    Keyword := Trim(SearchCenterWebKeyword)
    if (Keyword = "") {
        TrayTip("请输入搜索关键词", "提示", "Icon! 2")
        return
    }
    if (!IsObject(SearchCenterSelectedEngines) || SearchCenterSelectedEngines.Length = 0) {
        TrayTip("请至少选择一个搜索引擎", "提示", "Icon! 2")
        return
    }
    
    _SCWV_RecordSearchHistory(Keyword)

    _SCWV_BatchSearchStep(Keyword, 1)
}

_SCWV_RunHiddenCommandAsync(command, doneCb := 0, timeoutMs := 120000, tag := "") {
    global g_SCWV_AsyncCmdJobs, g_SCWV_AsyncCmdSeq
    cmd := Trim(String(command))
    if (cmd = "")
        return false
    pid := 0
    try Run(cmd, , "Hide", &pid)
    catch as e {
        if IsObject(doneCb)
            doneCb.Call(false, "run_failed:" . e.Message, 0)
        return false
    }
    if (pid <= 0) {
        if IsObject(doneCb)
            doneCb.Call(false, "run_pid_empty", 0)
        return false
    }
    g_SCWV_AsyncCmdSeq += 1
    g_SCWV_AsyncCmdJobs[g_SCWV_AsyncCmdSeq] := Map(
        "pid", pid,
        "start", A_TickCount,
        "timeout", Max(1000, Integer(timeoutMs)),
        "cb", doneCb,
        "tag", String(tag)
    )
    SetTimer(_SCWV_AsyncCmdPump, -80)
    return true
}

_SCWV_AsyncCmdPump(*) {
    global g_SCWV_AsyncCmdJobs
    if !(g_SCWV_AsyncCmdJobs is Map) || (g_SCWV_AsyncCmdJobs.Count = 0)
        return
    removeKeys := []
    now := A_TickCount
    for k, job in g_SCWV_AsyncCmdJobs {
        pid := Integer(job["pid"])
        alive := false
        try alive := !!ProcessExist(pid)
        if !alive {
            removeKeys.Push(k)
            cb := job["cb"]
            if IsObject(cb) {
                try cb.Call(true, "completed", pid)
            }
            continue
        }
        if ((now - Integer(job["start"])) >= Integer(job["timeout"])) {
            try ProcessClose(pid)
            removeKeys.Push(k)
            cb := job["cb"]
            if IsObject(cb) {
                try cb.Call(false, "timeout", pid)
            }
        }
    }
    for _, k in removeKeys {
        try g_SCWV_AsyncCmdJobs.Delete(k)
    }
    if (g_SCWV_AsyncCmdJobs.Count > 0)
        SetTimer(_SCWV_AsyncCmdPump, -80)
}

SCWV_IsWebSearchUIMode() {
    global g_SCWV_UiMode
    if !IsSet(g_SCWV_UiMode)
        return false
    return (StrLower(Trim(String(g_SCWV_UiMode))) = "web")
}

_SCWV_OpenSearchTarget(keyword, engine) {
    eng := Trim(String(engine))
    kw := Trim(String(keyword))
    if (eng = "" || kw = "")
        return false
    url := ""
    if SCWV_FuncExists("VoiceInputEffect_BuildSearchUrl")
        url := VoiceInputEffect_BuildSearchUrl(kw, eng)
    if (url = "")
        return false
    if SCWV_FuncExists("ScWebEmbedProbeShow") && SCWV_FuncExists("ScWebEmbedProbeNavigateEngine") {
        try {
            if ScWebEmbedProbeShow() {
                ScWebEmbedProbeNavigateEngine(eng, kw, 12000)
                return true
            }
        } catch {
        }
    }
    SendVoiceSearchToBrowser(kw, eng)
    return true
}

_SCWV_EnsureDefaultWebEngines(CategoryKey) {
    global SearchCenterSelectedEngines
    if (StrLower(Trim(String(CategoryKey))) != "ai")
        return
    if !IsObject(SearchCenterSelectedEngines)
        SearchCenterSelectedEngines := []
    if (SearchCenterSelectedEngines.Length > 0)
        return
    SearchCenterSelectedEngines.Push("deepseek")
    _SCWV_SaveSelectedEngines(CategoryKey, SearchCenterSelectedEngines)
}

_SCWV_BatchSearchStep(keyword, idx, *) {
    global SearchCenterSelectedEngines
    if !IsObject(SearchCenterSelectedEngines)
        return
    n := SearchCenterSelectedEngines.Length
    if (idx > n)
        return
    engine := SearchCenterSelectedEngines[idx]
    if (engine != "")
        _SCWV_OpenSearchTarget(keyword, engine)
    SetTimer((*) => _SCWV_BatchSearchStep(keyword, idx + 1), -300)
}

_SCWV_SendToCLI(prompt, engine := "") {
    global SearchCenterWebKeyword

    if (Trim(prompt) = "")
        prompt := Trim(SearchCenterWebKeyword)

    if (prompt = "") {
        TrayTip("请输入要发送给 AI 的内容", "提示", "Icon! 2")
        return
    }

    _SCWV_RecordSearchHistory(prompt)
    _SCWV_InjectPromptToTtyd(prompt, engine)
}

; 将顶部撰写区内容注入当前 ttyd iframe（行业惯例：Enter 发到用户正在看的终端）
_SCWV_InjectPromptToTtyd(prompt, engine := "") {
    global g_SCWV_Gui, g_SCWV_WV2
    p := Trim(String(prompt))
    if (p = "")
        return false
    eng := Trim(String(engine))
    if (eng = "")
        eng := "codex_cli"
    try eng := NiumaTtyd_NormalizeEngine(eng)
    catch {
        eng := "codex_cli"
    }
    port := NiumaTtyd_PortForEngine(eng)
    if !NiumaTtyd_IsHttpReadyOnPort(port, 400) {
        try NiumaTtyd_QueuePortProbe(port, 600)
        catch {
        }
    }
    try SCWV_PostJson(Map("type", "focusCliFrame", "engine", eng))
    catch {
    }
    Sleep(140)
    clipBak := ""
    try clipBak := ClipboardAll()
    catch {
    }
    try A_Clipboard := p
    catch {
        try A_Clipboard := ""
    }
    Sleep(60)
    try {
        if (IsObject(g_SCWV_Gui) && g_SCWV_Gui.HasProp("Hwnd")) {
            hwnd := g_SCWV_Gui.Hwnd
            if (hwnd && WinExist("ahk_id " . hwnd))
                WinActivate("ahk_id " . hwnd)
        }
    } catch {
    }
    Sleep(80)
    try {
        Send("^v")
        Sleep(70)
        Send("{Enter}")
    } catch {
    }
    try {
        if (clipBak != "")
            A_Clipboard := clipBak
    } catch {
    }
    return true
}

; 搜索中心结果执行：smartTextSearch=true 时，在有关键词且非文件/链接情况下用内容二次搜索（右键“立即执行”）；双击仍为粘贴
SC_ActivateSearchResultItem(Item, doHide := true, smartTextSearch := false) {
    if !IsObject(Item)
        return

    Content := Item.HasProp("Content") ? Item.Content : Item.Title
    DataType := ""
    if (Item.HasProp("DataType") && Item.DataType != "") {
        DataType := Item.DataType
    } else if (Item.HasProp("Metadata") && IsObject(Item.Metadata) && Item.Metadata.Has("DataType")) {
        DataType := Item.Metadata["DataType"]
    }

    origDt := Item.HasProp("OriginalDataType") ? Item.OriginalDataType : ""
    isFileLike := (DataType = "file" || DataType = "File" || DataType = "Folder" || origDt = "file")

    if doHide {
        ; 用户要求：执行结果后保留搜索中心，除非用户主动关闭或按 ESC。
        SetTimer((*) => _SCWV_ActivateSearchResultItemContinue(Item, smartTextSearch), -30)
        return
    }
    _SCWV_ActivateSearchResultItemContinue(Item, smartTextSearch)
}

_SCWV_ActivateSearchResultItemContinue(Item, smartTextSearch := false, *) {
    global SearchCenterWebKeyword
    if !IsObject(Item)
        return
    Content := Item.HasProp("Content") ? Item.Content : Item.Title
    DataType := ""
    if (Item.HasProp("DataType") && Item.DataType != "") {
        DataType := Item.DataType
    } else if (Item.HasProp("Metadata") && IsObject(Item.Metadata) && Item.Metadata.Has("DataType")) {
        DataType := Item.Metadata["DataType"]
    }
    origDt := Item.HasProp("OriginalDataType") ? Item.OriginalDataType : ""
    isFileLike := (DataType = "file" || DataType = "File" || DataType = "Folder" || origDt = "file")

    if (isFileLike) {
        launchTarget := _SCWV_ResolveLaunchTarget(Item)
        if (launchTarget = "")
            launchTarget := Content
        launchErr := ""
        if !_SCWV_LaunchAppTarget(launchTarget, &launchErr)
            TrayTip("打开失败", launchErr != "" ? launchErr : String(launchTarget), "Iconx 2")
        return
    }

    if (DataType = "Link") {
        try Run(Content)
        catch as err {
            TrayTip("打开链接失败", err.Message, "Iconx 2")
        }
        return
    }

    if (DataType = "Image") {
        try {
            if FileExist(Content)
                Run(Content)
            else
                TrayTip("图片文件不存在", Content, "Iconx 2")
        } catch as err {
            TrayTip("打开图片失败", err.Message, "Iconx 2")
        }
        return
    }

    kw := Trim(SearchCenterWebKeyword)
    if (smartTextSearch && kw != "" && !isFileLike && DataType != "Link" && DataType != "Image") {
        SearchCenter_RunQueryWithKeyword(Content)
        return
    }

    try {
        A_Clipboard := Content
        SetTimer((*) => Send("^v"), -80)
    } catch as err {
        TrayTip("粘贴失败", err.Message, "Iconx 2")
    }
}

_SCWV_ResolveLaunchTarget(Item) {
    candidates := []
    if !IsObject(Item)
        return ""

    ap := _SCWV_ResultItemGet(Item, "ActionParams", 0)
    if (ap is Map) {
        if ap.Has("FilePath")
            candidates.Push(ap["FilePath"])
        if ap.Has("Path")
            candidates.Push(ap["Path"])
    } else if IsObject(ap) {
        try {
            if ap.HasProp("FilePath")
                candidates.Push(ap.FilePath)
            if ap.HasProp("Path")
                candidates.Push(ap.Path)
        }
    }

    md := _SCWV_ResultItemGet(Item, "Metadata", 0)
    if (md is Map) {
        if md.Has("FilePath")
            candidates.Push(md["FilePath"])
        if md.Has("Path")
            candidates.Push(md["Path"])
    } else if IsObject(md) {
        try {
            if md.HasProp("FilePath")
                candidates.Push(md.FilePath)
            if md.HasProp("Path")
                candidates.Push(md.Path)
        }
    }

    if (_SCWV_ResultItemHas(Item, "Content"))
        candidates.Push(_SCWV_ResultItemGet(Item, "Content", ""))
    if (_SCWV_ResultItemHas(Item, "ID"))
        candidates.Push(_SCWV_ResultItemGet(Item, "ID", ""))

    for _, cand in candidates {
        p := _SCWV_CleanLaunchPath(cand)
        if (p = "")
            continue
        if _SCWV_IsShellLaunchToken(p)
            return p
        if (FileExist(p) || DirExist(p))
            return p
    }
    for _, cand in candidates {
        p := _SCWV_CleanLaunchPath(cand)
        if (p = "")
            continue
        if _SCWV_LooksLikePathOrAppToken(p)
            return p
    }
    return ""
}

_SCWV_CleanLaunchPath(raw) {
    p := Trim(String(raw))
    if (p = "")
        return ""
    if (SubStr(p, 1, 1) = '"' && SubStr(p, -10) = '"')
        p := SubStr(p, 2, StrLen(p) - 2)
    return Trim(p)
}

_SCWV_IsShellLaunchToken(s) {
    x := StrLower(Trim(String(s)))
    return (InStr(x, "shell:") = 1)
}

_SCWV_LooksLikePathOrAppToken(s) {
    x := Trim(String(s))
    if (x = "")
        return false
    if _SCWV_IsShellLaunchToken(x)
        return true
    if RegExMatch(x, "i)^[a-z]:\\")
        return true
    if RegExMatch(x, "i)^\\\\")
        return true
    SplitPath(x, , , &ext)
    ext := StrLower(ext)
    return (ext = "exe" || ext = "lnk" || ext = "cpl" || ext = "app" || ext = "appref-ms")
}

_SCWV_LaunchAppTarget(target, &errMsg) {
    errMsg := ""
    t := _SCWV_CleanLaunchPath(target)
    if (t = "") {
        errMsg := "目标为空"
        return false
    }

    if _SCWV_IsShellLaunchToken(t) {
        try {
            Run(t)
            return true
        } catch as err {
            errMsg := err.Message
            return false
        }
    }

    if DirExist(t) {
        try {
            Run('explorer.exe "' . t . '"')
            return true
        } catch as err {
            errMsg := err.Message
            return false
        }
    }

    SplitPath(t, , , &ext)
    ext := StrLower(ext)

    try {
        switch ext {
            case "exe":
                Run('"' . t . '"')
            case "cpl":
                try Run('control.exe "' . t . '"')
                catch as _ {
                    Run('rundll32.exe shell32.dll,Control_RunDLL "' . t . '"')
                }
            case "lnk", "appref-ms", "url":
                Run(t)
            case "app":
                if (FileExist(t))
                    Run('explorer.exe "' . t . '"')
                else
                    Run(t)
            default:
                if (FileExist(t) || DirExist(t))
                    Run(t)
                else
                    Run('"' . t . '"')
        }
        return true
    } catch as err {
        errMsg := err.Message
        return false
    }
}

_SCWV_ActivateResultRow(Row) {
    global SearchCenterWebKeyword
    Item := GetSearchCenterResultItemByRow(Row)
    if (SearchCenterWebKeyword != "")
        _SCWV_RecordSearchHistory(SearchCenterWebKeyword)
    SC_ActivateSearchResultItem(Item, true, false)
}

; 选区感应 / 拖放：写入关键词、打开搜索中心并执行搜索（供工具栏 WebView、SelectionSense）
SearchCenter_RunQueryWithKeyword(keyword) {
    global SearchCenterWebKeyword, g_SCWV_SearchTimer

    keyword := Trim(String(keyword))
    if (keyword = "")
        return
    if FuncExists("Nmer_Telemetry_Record") {
        try Nmer_Telemetry_Record("search", "search_center_query", true, Map("source", "SearchCenter_RunQueryWithKeyword"))
        catch as _e {
            NmerCatch(A_ThisFunc, _e)
        }
    }

    SearchCenterWebKeyword := keyword

    if g_SCWV_SearchTimer {
        SetTimer(g_SCWV_SearchTimer, 0)
        g_SCWV_SearchTimer := 0
    }

    try {
        try SCWV_Log("run_query_begin", "kw_len=" . StrLen(keyword) . " kw_prefix=" . SubStr(keyword, 1, 24))
        catch {
        }
        SCWV_Init("search_keyword")
        SCWV_SubmitIntent("open", 20, Map("reason", "search_keyword"))
        _SCWV_ExecuteGoSearchHttp(0, SearchCenterWebKeyword, "", 0)
        SCWV_PushState("state")
        SCWV_RequestFocusInput()
    } catch {
        ; 鍏滃簳閲嶈瘯锛氳閬挎棫鍙ユ焺澶辨晥瀵艰嚧鐨勫伓鍙戞墦寮€澶辫触
        SCWV_ResetHostState()
        SCWV_Init("search_keyword_retry")
        SCWV_SubmitIntent("open", 20, Map("reason", "search_keyword_retry"))
        _SCWV_ExecuteGoSearchHttp(0, SearchCenterWebKeyword, "", 0)
        SCWV_PushState("state")
        SCWV_RequestFocusInput()
    }
}

_SCWV_CommandExists(cmdId) {
    global g_Commands
    c := Trim(String(cmdId))
    if (c = "")
        return false
    if !(IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList"))
        return false
    cl := g_Commands["CommandList"]
    return (cl is Map) && cl.Has(c)
}

_SCWV_CmdDisplayName(cmdId) {
    global g_Commands
    c := Trim(String(cmdId))
    if !(IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList"))
        return c
    cl := g_Commands["CommandList"]
    if !(cl is Map) || !cl.Has(c)
        return c
    ent := cl[c]
    if ent is Map && ent.Has("name")
        return String(ent["name"])
    return c
}

_SCWV_AniMenuShow(hwnd) {
    if !hwnd
        return
    try {
        DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x1 | 0x2 | 0x10)
    } catch {
    }
}

_SCWV_DarkMenuShowSized(guiObj, posX, posY, menuW, menuH) {
    if !IsObject(guiObj) || !guiObj
        return
    guiObj.Show("x" . posX . " y" . posY . " w" . menuW . " h" . menuH . " NoActivate")
    try {
        hwnd := guiObj.Hwnd
        if hwnd {
            DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", -1, "Int", posX, "Int", posY, "Int", menuW, "Int", menuH, "UInt", 0x10)
            _SCWV_DarkMenuRoundCorners(hwnd)
        }
    } catch {
    }
}

; 涓庡壀璐存澘鍙抽敭锛?px 姗欒壊鎻忚竟 + 8px 鍐呰竟璺濓紱琛岄珮 34
_SCWV_DarkMenuLayout(&frm, &itemPad, &itemH, &innerTop) {
    frm := 1
    itemPad := 8
    itemH := 34
    innerTop := frm + itemPad
}

; Win11 DWM 圆角（失败则忽略）
_SCWV_DarkMenuRoundCorners(hwnd) {
    if !hwnd
        return
    attr := Buffer(4, 0)
    NumPut("uint", 2, attr)
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "uint", 33, "ptr", attr, "uint", 4)
    catch {
    }
}

; Win11 宿主深色边框/标题栏，避免首帧露出浅色窗口描边
_SCWV_ApplyHostDarkChrome(hwnd) {
    if !hwnd
        return
    dark := Buffer(4, 0)
    NumPut("int", 1, dark)
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "uint", 20, "ptr", dark, "uint", 4)
    catch {
    }
    ; COLORREF 0x00BBGGRR，与 Gui BackColor #0D1016 对齐
    color := Buffer(4, 0)
    NumPut("uint", 0x0016100D, color)
    for attrId in [34, 35] {
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "uint", attrId, "ptr", color, "uint", 4)
        catch {
        }
    }
}

_SCWV_FilterCtxChildrenByToolbar(childTemplates, specIdSet) {
    out := []
    if !(childTemplates is Array) || !(specIdSet is Map)
        return out
    for ch in childTemplates {
        if !(ch is Map)
            continue
        cid := ch.Has("id") ? Trim(String(ch["id"])) : ""
        if (cid != "" && specIdSet.Has(cid))
            out.Push(ch)
    }
    return out
}

_SCWV_SearchCtxPasteToChildren() {
    return [
        Map("id", "cp_ctx_pastePlain", "t", "粘贴纯文本"),
        Map("id", "cp_ctx_pasteWithNewline", "t", "粘贴并换行"),
        Map("id", "cp_ctx_pastePath", "t", "粘贴路径"),
        Map("id", "cp_ctx_copyToClipboard", "t", "复制到剪贴板")
    ]
}

_SCWV_SearchCtxCopyToChildren() {
    return [
        Map("id", "sc_copy_path", "t", "复制路径"),
        Map("id", "sc_copy_url", "t", "复制链接"),
        Map("id", "sc_copy_link", "t", "复制路径/链接（兼容）"),
        Map("id", "sc_copy_digit", "t", "复制数字"),
        Map("id", "sc_copy_chinese", "t", "复制中文"),
        Map("id", "sc_copy_md", "t", "复制 Markdown")
    ]
}

_SCWV_SearchCtxSendChildren() {
    return [
        Map("id", "sc_to_draft", "t", "发送到草稿本"),
        Map("id", "sc_to_prompt", "t", "发送到提示词中心"),
        Map("id", "sc_to_openclaw", "t", "发送到 OpenClaw"),
        Map("id", "sc_send_desktop", "t", "发送到桌面（复制文件）"),
        Map("id", "sc_send_documents", "t", "发送到文档（复制文件）"),
        Map("id", "sc_open_sendto_folder", "t", "打开“发送到”文件夹")
    ]
}

_SCWV_AppendSearchCtxStandardBlock(&out, specIds) {
    ; 绮樿创绫讳笌宸ュ叿鏍忔Ы浣嶆棤鍏筹細鎼滅储涓績缁熶竴鎻愪緵鍥涢」锛堥潪鍓创鏉跨粨鏋滄墽琛屾椂浼氭彁绀猴級
    pCh := _SCWV_SearchCtxPasteToChildren()
    if pCh.Length
        out.Push(Map("k", "sub", "t", "粘贴到 ▶", "children", pCh))
    out.Push(Map("k", "cmd", "id", "sc_copy", "t", "复制"))
    cCh := _SCWV_FilterCtxChildrenByToolbar(_SCWV_SearchCtxCopyToChildren(), specIds)
    if cCh.Length
        out.Push(Map("k", "sub", "t", "复制到 ▶", "children", cCh))
    sCh := _SCWV_FilterCtxChildrenByToolbar(_SCWV_SearchCtxSendChildren(), specIds)
    if sCh.Length
        out.Push(Map("k", "sub", "t", "发送到 ▶", "children", sCh))
}

_SCWV_RegroupSearchCtxSpec(baseSpec, Item) {
    global g_SCWV_PinnedKeys
    specIds := Map()
    for ent0 in baseSpec {
        if ent0 is Map && ent0.Has("id") {
            id0 := Trim(String(ent0["id"]))
            if (id0 != "")
                specIds[id0] := true
        }
    }
    pasteToIds := Map()
    for s in ["cp_ctx_pastePlain", "cp_ctx_pasteWithNewline", "cp_ctx_pastePath", "cp_ctx_copyToClipboard"]
        pasteToIds[s] := true
    copyTopIds := Map()
    copyTopIds["sc_copy"] := true
    copyTopIds["sc_copy_plain"] := true
    copyToIds := Map()
    for s in ["sc_copy_path", "sc_copy_url", "sc_copy_link", "sc_copy_digit", "sc_copy_chinese", "sc_copy_md"]
        copyToIds[s] := true
    sendIds := Map()
    for s in ["sc_to_draft", "sc_to_prompt", "sc_to_openclaw", "sc_send_desktop", "sc_send_documents", "sc_open_sendto_folder"]
        sendIds[s] := true
    blockIns := false
    out := []
    for ent in baseSpec {
        if !(ent is Map)
            continue
        cid := ent.Has("id") ? Trim(String(ent["id"])) : ""
        if (cid = "sc_pin_item") {
            pk := _SCWV_ResultPinKey(Item)
            pinned := (pk != "" && g_SCWV_PinnedKeys.Has(pk) && g_SCWV_PinnedKeys[pk])
            out.Push(Map("k", "cmd", "id", cid, "t", pinned ? "取消置顶" : "置顶"))
            continue
        }
        if pasteToIds.Has(cid) || copyTopIds.Has(cid) || copyToIds.Has(cid) || sendIds.Has(cid) {
            if !blockIns {
                _SCWV_AppendSearchCtxStandardBlock(&out, specIds)
                blockIns := true
            }
            continue
        }
        out.Push(ent)
    }
    if !blockIns
        _SCWV_AppendSearchCtxStandardBlock(&out, specIds)
    return out
}

; 涓昏彍鍗曢」鍙充晶瀵归綈瀛愯彍鍗曞乏涓婅锛堜笌鐐瑰嚮灞曞紑浣跨敤鍚屼竴濂楀潗鏍囷級
_SCWV_DarkCtxComputeSubXY(idx, &subX, &subY) {
    global g_SCWV_DarkCtxGui
    subX := A_ScreenWidth // 2
    subY := A_ScreenHeight // 2
    if !g_SCWV_DarkCtxGui
        return
    _SCWV_DarkMenuLayout(&Df, &Pad, &itemH, &innerTop)
    try {
        WinGetPos(&WX, &WY, &WW, &WH, "ahk_id " . g_SCWV_DarkCtxGui.Hwnd)
        subX := WX + WW - 4
        subY := WY + innerTop + (idx - 1) * itemH
    } catch {
    }
}

_SCWV_DarkMenuHoverPhase2(idx, *) {
    global g_SCWV_DarkCtxGui, g_SCWV_DarkCtxHoverIdx, g_SCWV_DarkMenuHoverTimer
    g_SCWV_DarkMenuHoverTimer := 0
    if !g_SCWV_DarkCtxGui || g_SCWV_DarkCtxHoverIdx != idx
        return
    try {
        g_SCWV_DarkCtxGui["ScCtxBg" . idx].BackColor := "ff6600"
        g_SCWV_DarkCtxGui["ScCtxTx" . idx].Opt("cFFFFFF")
    } catch {
    }
}

_SCWV_DarkSubMenuHoverPhase2(idx, *) {
    global g_SCWV_DarkSubGui, g_SCWV_DarkSubHoverIdx, g_SCWV_DarkSubMenuHoverTimer
    g_SCWV_DarkSubMenuHoverTimer := 0
    if !g_SCWV_DarkSubGui || g_SCWV_DarkSubHoverIdx != idx
        return
    try {
        g_SCWV_DarkSubGui["ScSubBg" . idx].BackColor := "ff6600"
        g_SCWV_DarkSubGui["ScSubTx" . idx].Opt("cFFFFFF")
    } catch {
    }
}

_SCWV_DestroyDarkSubMenus(*) {
    global g_SCWV_DarkSubGui, g_SCWV_DarkSubCmdByIdx, g_SCWV_DarkSubHoverIdx, g_SCWV_DarkSubMenuHoverTimer
    SetTimer(_SCWV_CheckDarkSubCtxMouse, 0)
    if g_SCWV_DarkSubMenuHoverTimer {
        SetTimer(g_SCWV_DarkSubMenuHoverTimer, 0)
        g_SCWV_DarkSubMenuHoverTimer := 0
    }
    g_SCWV_DarkSubCmdByIdx := Map()
    g_SCWV_DarkSubHoverIdx := 0
    global g_SCWV_DarkSubItemCount
    g_SCWV_DarkSubItemCount := 0
    if IsSet(g_SCWV_DarkSubGui) && g_SCWV_DarkSubGui {
        try g_SCWV_DarkSubGui.Destroy()
        catch {
        }
        g_SCWV_DarkSubGui := 0
    }
}

_SCWV_DestroyDarkRowMenus(*) {
    global g_SCWV_DarkCtxGui, g_SCWV_DarkCtxHoverIdx, g_SCWV_DarkCtxCmdByIdx, g_SCWV_RowCtxMenu
    global g_SCWV_DarkCtxSubSpecByIdx, g_SCWV_DarkMenuHoverTimer
    SetTimer(_SCWV_CheckDarkSearchCtxMouse, 0)
    SetTimer(_SCWV_CloseDarkSearchCtxIfOutside, 0)
    if g_SCWV_DarkMenuHoverTimer {
        SetTimer(g_SCWV_DarkMenuHoverTimer, 0)
        g_SCWV_DarkMenuHoverTimer := 0
    }
    _SCWV_DestroyDarkSubMenus()
    g_SCWV_DarkCtxSubSpecByIdx := Map()
    g_SCWV_DarkCtxHoverIdx := 0
    g_SCWV_DarkCtxCmdByIdx := Map()
    global g_SCWV_DarkCtxItemCount
    g_SCWV_DarkCtxItemCount := 0
    if IsSet(g_SCWV_DarkCtxGui) && g_SCWV_DarkCtxGui {
        try g_SCWV_DarkCtxGui.Destroy()
        catch {
        }
        g_SCWV_DarkCtxGui := 0
    }
    g_SCWV_RowCtxMenu := 0
}

; 会弹出资源管理器 / 系统属性 / UAC 的命令：勿立刻把焦点抢回搜索中心
_SCWV_ShouldRefocusSearchAfterCmd(cmdId) {
    c := Trim(String(cmdId))
    if (c = "sc_open_path" || c = "sc_run_as_admin")
        return false
    return true
}

_SCWV_DarkSearchItemApplyHover(idx) {
    global g_SCWV_DarkCtxGui, g_SCWV_DarkCtxHoverIdx, g_SCWV_DarkMenuHoverTimer, g_SCWV_DarkCtxSubSpecByIdx
    if g_SCWV_DarkCtxHoverIdx = idx
        return
    if g_SCWV_DarkMenuHoverTimer {
        SetTimer(g_SCWV_DarkMenuHoverTimer, 0)
        g_SCWV_DarkMenuHoverTimer := 0
    }
    if g_SCWV_DarkCtxHoverIdx > 0 {
        try {
            g_SCWV_DarkCtxGui["ScCtxBg" . g_SCWV_DarkCtxHoverIdx].BackColor := "1a1a1a"
            g_SCWV_DarkCtxGui["ScCtxTx" . g_SCWV_DarkCtxHoverIdx].Opt("cff6600")
        } catch {
        }
    }
    g_SCWV_DarkCtxHoverIdx := idx
    if idx > 0 {
        try {
            g_SCWV_DarkCtxGui["ScCtxBg" . idx].BackColor := "2a2622"
            g_SCWV_DarkCtxGui["ScCtxTx" . idx].Opt("cffb366")
        } catch {
        }
        if g_SCWV_DarkCtxSubSpecByIdx.Has(idx) {
            try {
                ch := g_SCWV_DarkCtxSubSpecByIdx[idx]
                _SCWV_DarkCtxComputeSubXY(idx, &sx, &sy)
                _SCWV_ShowDarkSubMenuAt(ch, sx, sy)
            } catch {
            }
        } else
            _SCWV_DestroyDarkSubMenus()
        fn := _SCWV_DarkMenuHoverPhase2.Bind(idx)
        g_SCWV_DarkMenuHoverTimer := fn
        SetTimer(fn, -50)
    }
}

_SCWV_CheckDarkSearchCtxMouse(*) {
    global g_SCWV_DarkCtxGui, g_SCWV_DarkCtxHoverIdx, g_SCWV_DarkSubGui, g_SCWV_DarkCtxItemCount
    if !g_SCWV_DarkCtxGui
        return
    try {
        if !g_SCWV_DarkCtxGui.Hwnd || !WinExist("ahk_id " . g_SCWV_DarkCtxGui.Hwnd) {
            _SCWV_DestroyDarkRowMenus()
            return
        }
    } catch {
        _SCWV_DestroyDarkRowMenus()
        return
    }
    try {
        MouseGetPos(&MX, &MY)
        if g_SCWV_DarkSubGui {
            try {
                WinGetPos(&SX, &SY, &SW, &SH, "ahk_id " . g_SCWV_DarkSubGui.Hwnd)
                if (MX >= SX && MX <= SX + SW && MY >= SY && MY <= SY + SH) {
                    if g_SCWV_DarkCtxHoverIdx > 0
                        _SCWV_DarkSearchItemApplyHover(0)
                    return
                }
            } catch {
            }
        }
        WinGetPos(&WX, &WY, &WW, &WH, "ahk_id " . g_SCWV_DarkCtxGui.Hwnd)
    } catch {
        return
    }
    if MX < WX || MX > WX + WW || MY < WY || MY > WY + WH {
        if g_SCWV_DarkCtxHoverIdx > 0
            _SCWV_DarkSearchItemApplyHover(0)
        return
    }
    _SCWV_DarkMenuLayout(&Df, &Pad, &MenuItemHeight, &innerTop)
    RelX := MX - WX
    RelY := MY - WY
    if RelY < innerTop || RelX < innerTop {
        if g_SCWV_DarkCtxHoverIdx > 0
            _SCWV_DarkSearchItemApplyHover(0)
        return
    }
    ItemIndex := Floor((RelY - innerTop) / MenuItemHeight) + 1
    if (ItemIndex < 1 || ItemIndex > g_SCWV_DarkCtxItemCount) {
        if g_SCWV_DarkCtxHoverIdx > 0
            _SCWV_DarkSearchItemApplyHover(0)
        return
    }
    ItemY := innerTop + (ItemIndex - 1) * MenuItemHeight
    if RelY >= ItemY && RelY < ItemY + MenuItemHeight && RelX >= innerTop && RelX < WW - innerTop
        _SCWV_DarkSearchItemApplyHover(ItemIndex)
    else if g_SCWV_DarkCtxHoverIdx > 0
        _SCWV_DarkSearchItemApplyHover(0)
}

_SCWV_CloseDarkSearchCtxIfOutside(*) {
    global g_SCWV_DarkCtxGui, g_SCWV_DarkSubGui
    if !g_SCWV_DarkCtxGui
        return
    try {
        MouseGetPos(&MX, &MY)
        WinGetPos(&WX, &WY, &WW, &WH, "ahk_id " . g_SCWV_DarkCtxGui.Hwnd)
        inMain := (MX >= WX && MX <= WX + WW && MY >= WY && MY <= WY + WH)
        inSub := false
        if g_SCWV_DarkSubGui {
            try {
                WinGetPos(&SX, &SY, &SW, &SH, "ahk_id " . g_SCWV_DarkSubGui.Hwnd)
                inSub := (MX >= SX && MX <= SX + SW && MY >= SY && MY <= SY + SH)
            } catch {
            }
        }
        if inMain || inSub
            return
        if GetKeyState("LButton", "P") || GetKeyState("RButton", "P")
            _SCWV_DestroyDarkRowMenus()
    } catch {
        _SCWV_DestroyDarkRowMenus()
    }
}

_SCWV_OnDarkSubMenuClick(idx, *) {
    global g_SCWV_DarkSubCmdByIdx, g_SCWV_MenuActionRow, g_SCWV_Gui
    c := g_SCWV_DarkSubCmdByIdx.Has(idx) ? g_SCWV_DarkSubCmdByIdx[idx] : ""
    row := g_SCWV_MenuActionRow
    if (c != "") {
        global g_SCWV_DarkSubGui
        try {
            if g_SCWV_DarkSubGui {
                g_SCWV_DarkSubGui["ScSubBg" . idx].BackColor := "ffc48a"
                g_SCWV_DarkSubGui["ScSubTx" . idx].Opt("c1a1a1a")
            }
        } catch {
        }
        SetTimer((*) => _SCWV_OnDarkSubMenuClick_Continue(idx, c, row), -42)
        return
    }
    _SCWV_OnDarkSubMenuClick_Continue(idx, c, row)
}

_SCWV_OnDarkSubMenuClick_Continue(idx, c, row, *) {
    global g_SCWV_Gui
    _SCWV_DestroyDarkRowMenus()
    if (c != "" && _SCWV_IsMenuTargetStillValid(row))
        SC_ExecuteContextCommand(c, row)
    if _SCWV_ShouldRefocusSearchAfterCmd(c) && g_SCWV_Gui {
        try FocusBroker_Request("SearchCenter", g_SCWV_Gui.Hwnd, 20, "ctx_refocus", 300)
        catch as _ea {
        }
    }
    if _SCWV_ShouldRefocusSearchAfterCmd(c) {
        try SCWV_RequestFocusInput()
        catch as _eb {
        }
    }
}

_SCWV_IsMenuTargetStillValid(row) {
    global g_SCWV_MenuActionUid
    r := Integer(row)
    if (r < 1)
        return false
    expectedUid := Trim(String(g_SCWV_MenuActionUid))
    if (expectedUid = "")
        return true
    it := GetSearchCenterResultItemByRow(r)
    if !IsObject(it)
        return false
    nowUid := _SCWV_ResultActionUid(it, r)
    if (nowUid = expectedUid)
        return true
    try SCWV_Log("menu_target_mismatch", "row=" . r . " expected=" . expectedUid . " now=" . nowUid)
    return false
}

_SCWV_CheckDarkSubCtxMouse(*) {
    global g_SCWV_DarkSubGui, g_SCWV_DarkSubHoverIdx, g_SCWV_DarkSubMenuHoverTimer, g_SCWV_DarkSubItemCount
    if !g_SCWV_DarkSubGui
        return
    try {
        if !g_SCWV_DarkSubGui.Hwnd || !WinExist("ahk_id " . g_SCWV_DarkSubGui.Hwnd) {
            _SCWV_DestroyDarkSubMenus()
            return
        }
    } catch {
        _SCWV_DestroyDarkSubMenus()
        return
    }
    _SCWV_DarkMenuLayout(&Df, &Pad, &MenuItemHeight, &innerTop)
    try {
        MouseGetPos(&MX, &MY)
        WinGetPos(&WX, &WY, &WW, &WH, "ahk_id " . g_SCWV_DarkSubGui.Hwnd)
    } catch {
        return
    }
    if MX < WX || MX > WX + WW || MY < WY || MY > WY + WH {
        if g_SCWV_DarkSubMenuHoverTimer {
            SetTimer(g_SCWV_DarkSubMenuHoverTimer, 0)
            g_SCWV_DarkSubMenuHoverTimer := 0
        }
        if g_SCWV_DarkSubHoverIdx > 0 {
            try {
                g_SCWV_DarkSubGui["ScSubBg" . g_SCWV_DarkSubHoverIdx].BackColor := "1a1a1a"
                g_SCWV_DarkSubGui["ScSubTx" . g_SCWV_DarkSubHoverIdx].Opt("cff6600")
            } catch {
            }
            g_SCWV_DarkSubHoverIdx := 0
        }
        return
    }
    RelY := MY - WY
    if RelY < innerTop {
        if g_SCWV_DarkSubMenuHoverTimer {
            SetTimer(g_SCWV_DarkSubMenuHoverTimer, 0)
            g_SCWV_DarkSubMenuHoverTimer := 0
        }
        if g_SCWV_DarkSubHoverIdx > 0 {
            try {
                g_SCWV_DarkSubGui["ScSubBg" . g_SCWV_DarkSubHoverIdx].BackColor := "1a1a1a"
                g_SCWV_DarkSubGui["ScSubTx" . g_SCWV_DarkSubHoverIdx].Opt("cff6600")
            } catch {
            }
            g_SCWV_DarkSubHoverIdx := 0
        }
        return
    }
    ItemIndex := Floor((RelY - innerTop) / MenuItemHeight) + 1
    if (ItemIndex < 1 || ItemIndex > g_SCWV_DarkSubItemCount)
        return
    ItemY := innerTop + (ItemIndex - 1) * MenuItemHeight
    if RelY < ItemY || RelY >= ItemY + MenuItemHeight {
        return
    }
    if g_SCWV_DarkSubHoverIdx = ItemIndex
        return
    if g_SCWV_DarkSubMenuHoverTimer {
        SetTimer(g_SCWV_DarkSubMenuHoverTimer, 0)
        g_SCWV_DarkSubMenuHoverTimer := 0
    }
    if g_SCWV_DarkSubHoverIdx > 0 {
        try {
            g_SCWV_DarkSubGui["ScSubBg" . g_SCWV_DarkSubHoverIdx].BackColor := "1a1a1a"
            g_SCWV_DarkSubGui["ScSubTx" . g_SCWV_DarkSubHoverIdx].Opt("cff6600")
        } catch {
        }
    }
    g_SCWV_DarkSubHoverIdx := ItemIndex
    try {
        g_SCWV_DarkSubGui["ScSubBg" . ItemIndex].BackColor := "2a2622"
        g_SCWV_DarkSubGui["ScSubTx" . ItemIndex].Opt("cffb366")
    } catch {
    }
    fn := _SCWV_DarkSubMenuHoverPhase2.Bind(ItemIndex)
    g_SCWV_DarkSubMenuHoverTimer := fn
    SetTimer(fn, -50)
}

_SCWV_ShowDarkSubMenuAt(children, posX, posY) {
    global g_SCWV_DarkSubGui, g_SCWV_DarkSubCmdByIdx, g_SCWV_DarkCtxGui, g_SCWV_Gui, g_SCWV_DarkSubItemCount
    _SCWV_DestroyDarkSubMenus()
    if !(children is Array) || children.Length = 0
        return
    _SCWV_DarkMenuLayout(&Df, &Pad, &MenuItemHeight, &innerTop)
    MenuWidth := 220
    n := children.Length
    MenuHeight := 2 * Df + n * MenuItemHeight + 2 * Pad
    ScreenWidth := SysGet(78)
    ScreenHeight := SysGet(79)
    posX := Integer(posX)
    posY := Integer(posY)
    if posX < 8
        posX := 8
    else if posX + MenuWidth > ScreenWidth - 8
        posX := ScreenWidth - MenuWidth - 8
    if posY < 8
        posY := 8
    else if posY + MenuHeight > ScreenHeight - 8
        posY := ScreenHeight - MenuHeight - 8
    ownOpt := ""
    g_SCWV_DarkSubGui := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale -Theme" . ownOpt, "SearchCtxSub")
    g_SCWV_DarkSubGui.BackColor := "1a1a1a"
    g_SCWV_DarkSubGui.MarginX := 0
    g_SCWV_DarkSubGui.MarginY := 0
    g_SCWV_DarkSubGui.Add("Text", "x0 y0 w" . MenuWidth . " h" . MenuHeight . " Background1a1a1a", "")
    g_SCWV_DarkSubCmdByIdx := Map()
    g_SCWV_DarkSubItemCount := n
    Loop children.Length {
        i := A_Index
        it := children[i]
        t := it.Has("t") ? String(it["t"]) : ""
        id := it.Has("id") ? Trim(String(it["id"])) : ""
        iy := innerTop + (i - 1) * MenuItemHeight
        ItemBg := g_SCWV_DarkSubGui.Add("Text", "x" . innerTop . " y" . iy . " w" . (MenuWidth - 2 * innerTop) . " h" . MenuItemHeight . " Background1a1a1a vScSubBg" . i, "")
        ItemBg.OnEvent("Click", _SCWV_OnDarkSubMenuClick.Bind(i))
        ItemTxt := g_SCWV_DarkSubGui.Add("Text", "x" . (innerTop + 10) . " y" . iy . " w" . (MenuWidth - 2 * innerTop - 14) . " h" . MenuItemHeight . " Left 0x200 cff6600 BackgroundTrans vScSubTx" . i, t)
        ItemTxt.SetFont("s11", "Segoe UI")
        ItemTxt.OnEvent("Click", _SCWV_OnDarkSubMenuClick.Bind(i))
        if (id != "")
            g_SCWV_DarkSubCmdByIdx[i] := id
    }
    _SCWV_DarkMenuShowSized(g_SCWV_DarkSubGui, posX, posY, MenuWidth, MenuHeight)
    try FocusBroker_Request("SearchCenter", g_SCWV_DarkSubGui.Hwnd, 20, "dark_sub_menu", 300)
    catch {
    }
    SetTimer(_SCWV_CheckDarkSubCtxMouse, 45)
}

_SCWV_OnDarkSearchMenuClick(idx, *) {
    global g_SCWV_DarkCtxCmdByIdx, g_SCWV_DarkCtxSubSpecByIdx, g_SCWV_MenuActionRow, g_SCWV_Gui, g_SCWV_DarkCtxGui
    if g_SCWV_DarkCtxSubSpecByIdx.Has(idx) {
        ch := g_SCWV_DarkCtxSubSpecByIdx[idx]
        try {
            if g_SCWV_DarkCtxGui {
                g_SCWV_DarkCtxGui["ScCtxBg" . idx].BackColor := "ffc48a"
                g_SCWV_DarkCtxGui["ScCtxTx" . idx].Opt("c1a1a1a")
            }
        } catch {
        }
        SetTimer((*) => _SCWV_OnDarkSearchMenuClick_ShowSub(idx, ch), -32)
        return
    }
    c := g_SCWV_DarkCtxCmdByIdx.Has(idx) ? g_SCWV_DarkCtxCmdByIdx[idx] : ""
    row := g_SCWV_MenuActionRow
    if (c != "") {
        try {
            if g_SCWV_DarkCtxGui {
                g_SCWV_DarkCtxGui["ScCtxBg" . idx].BackColor := "ffc48a"
                g_SCWV_DarkCtxGui["ScCtxTx" . idx].Opt("c1a1a1a")
            }
        } catch {
        }
        SetTimer((*) => _SCWV_OnDarkSearchMenuClick_Continue(c, row), -38)
        return
    }
    _SCWV_OnDarkSearchMenuClick_Continue(c, row)
}

_SCWV_OnDarkSearchMenuClick_ShowSub(idx, ch, *) {
    try {
        _SCWV_DarkCtxComputeSubXY(idx, &subX, &subY)
        _SCWV_ShowDarkSubMenuAt(ch, subX, subY)
    } catch {
        _SCWV_ShowDarkSubMenuAt(ch, A_ScreenWidth // 2, A_ScreenHeight // 2)
    }
}

_SCWV_OnDarkSearchMenuClick_Continue(c, row, *) {
    global g_SCWV_Gui
    _SCWV_DestroyDarkRowMenus()
    if (c != "" && _SCWV_IsMenuTargetStillValid(row))
        SC_ExecuteContextCommand(c, row)
    if _SCWV_ShouldRefocusSearchAfterCmd(c) && g_SCWV_Gui {
        try FocusBroker_Request("SearchCenter", g_SCWV_Gui.Hwnd, 20, "ctx_refocus", 300)
        catch as _ea {
        }
    }
    if _SCWV_ShouldRefocusSearchAfterCmd(c) {
        try SCWV_RequestFocusInput()
        catch as _eb {
        }
    }
}

_SCWV_FlattenSearchCtxSpecForPopup(spec) {
    flat := []
    if !(spec is Array)
        return flat
    for ent in spec {
        if !(ent is Map)
            continue
        if (ent.Has("k") && String(ent["k"]) = "sub" && ent.Has("children")) {
            grp := Trim(StrReplace(String(ent.Has("t") ? ent["t"] : ""), "▶", ""))
            for ch in ent["children"] {
                if !(ch is Map)
                    continue
                cid := ch.Has("id") ? Trim(String(ch["id"])) : ""
                ct := ch.Has("t") ? String(ch["t"]) : ""
                if (cid = "" && ct = "")
                    continue
                flat.Push(Map("Text", (grp != "" ? grp . " · " : "") . ct, "CmdId", cid))
            }
            continue
        }
        cid := ent.Has("id") ? Trim(String(ent["id"])) : ""
        t := ent.Has("t") ? String(ent["t"]) : ""
        if (cid = "" && t = "")
            continue
        flat.Push(Map("Text", t, "CmdId", cid))
    }
    return flat
}

_SCWV_SearchCtxMenuAction(cmdId, *) {
    global g_SCWV_MenuActionRow, g_SCWV_Gui
    c := Trim(String(cmdId))
    row := g_SCWV_MenuActionRow
    if (c != "" && _SCWV_IsMenuTargetStillValid(row))
        SC_ExecuteContextCommand(c, row)
    if _SCWV_ShouldRefocusSearchAfterCmd(c) && g_SCWV_Gui {
        try FocusBroker_Request("SearchCenter", g_SCWV_Gui.Hwnd, 20, "ctx_refocus", 300)
        catch {
        }
    }
    if _SCWV_ShouldRefocusSearchAfterCmd(c) {
        try SCWV_RequestFocusInput()
        catch {
        }
    }
}

_SCWV_ShowDarkSearchRowMenuAt(spec, posX, posY) {
    global g_SCWV_DarkCtxGui, g_SCWV_DarkCtxCmdByIdx, g_SCWV_DarkCtxHoverIdx, g_SCWV_DarkCtxSubSpecByIdx, g_SCWV_DarkCtxItemCount
    _SCWV_DestroyDarkRowMenus()
    if !(spec is Array) || spec.Length = 0
        spec := [Map("k", "cmd", "id", "", "t", "（未配置菜单）")]
    if IsSet(ShowDarkStylePopupMenuAt) {
        flat := _SCWV_FlattenSearchCtxSpecForPopup(spec)
        menuItems := []
        for ent in flat {
            cid := ent.Has("CmdId") ? Trim(String(ent["CmdId"])) : ""
            txt := ent.Has("Text") ? String(ent["Text"]) : ""
            if (txt = "")
                continue
            item := {Text: txt}
            if (cid != "")
                item.Action := _SCWV_SearchCtxMenuAction.Bind(cid)
            menuItems.Push(item)
        }
        if (menuItems.Length = 0)
            menuItems.Push({Text: "（无菜单项）"})
        ShowDarkStylePopupMenuAt(menuItems, posX + 2, posY + 2)
        return
    }
    _SCWV_DarkMenuLayout(&Df, &Pad, &MenuItemHeight, &innerTop)
    n := spec.Length
    g_SCWV_DarkCtxItemCount := n
    MenuWidth := 220
    MenuHeight := 2 * Df + n * MenuItemHeight + 2 * Pad
    cellW := MenuWidth - 2 * innerTop
    ScreenWidth := SysGet(78)
    ScreenHeight := SysGet(79)
    posX := Integer(posX)
    posY := Integer(posY)
    if posX < 8
        posX := 8
    else if posX + MenuWidth > ScreenWidth - 8
        posX := ScreenWidth - MenuWidth - 8
    if posY < 8
        posY := 8
    else     if posY + MenuHeight > ScreenHeight - 8
        posY := ScreenHeight - MenuHeight - 8

    ownOpt := ""
    g_SCWV_DarkCtxGui := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale" . ownOpt, "SearchCtx")
    g_SCWV_DarkCtxGui.BackColor := "1a1a1a"
    g_SCWV_DarkCtxGui.MarginX := 0
    g_SCWV_DarkCtxGui.MarginY := 0
    g_SCWV_DarkCtxGui.Add("Text", "x0 y0 w" . MenuWidth . " h" . MenuHeight . " Background1a1a1a", "")
    g_SCWV_DarkCtxCmdByIdx := Map()
    g_SCWV_DarkCtxSubSpecByIdx := Map()
    g_SCWV_DarkCtxHoverIdx := 0
    Loop spec.Length {
        i := A_Index
        it := spec[i]
        t := it.Has("t") ? String(it["t"]) : ""
        isSub := it.Has("k") && String(it["k"]) = "sub"
        id := isSub ? "" : (it.Has("id") ? Trim(String(it["id"])) : "")
        iy := innerTop + (i - 1) * MenuItemHeight
        ItemBg := g_SCWV_DarkCtxGui.Add("Text", "x" . innerTop . " y" . iy . " w" . cellW . " h" . MenuItemHeight . " Background1a1a1a vScCtxBg" . i, "")
        ItemBg.OnEvent("Click", _SCWV_OnDarkSearchMenuClick.Bind(i))
        ItemTxt := g_SCWV_DarkCtxGui.Add("Text", "x" . (innerTop + 10) . " y" . iy . " w" . (cellW - 14) . " h" . MenuItemHeight . " Left 0x200 cff6600 BackgroundTrans vScCtxTx" . i, t)
        ItemTxt.SetFont("s11", "Segoe UI")
        ItemTxt.OnEvent("Click", _SCWV_OnDarkSearchMenuClick.Bind(i))
        if (isSub && it.Has("children"))
            g_SCWV_DarkCtxSubSpecByIdx[i] := it["children"]
        else if (id != "")
            g_SCWV_DarkCtxCmdByIdx[i] := id
    }
    g_SCWV_DarkCtxGui.Show("x" . posX . " y" . posY . " w" . MenuWidth . " h" . MenuHeight)
    try {
        if g_SCWV_DarkCtxGui.Hwnd
            DllCall("SetWindowPos", "Ptr", g_SCWV_DarkCtxGui.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x1 | 0x2)
    } catch {
    }
    _SCWV_DarkMenuRoundCorners(g_SCWV_DarkCtxGui.Hwnd)
    SetTimer(_SCWV_CheckDarkSearchCtxMouse, 45)
    SetTimer(_SCWV_CloseDarkSearchCtxIfOutside, 80)
}

_SCWV_BuildSearchCtxMenuSpec(layoutRows) {
    spec := []
    if !(layoutRows is Array)
        return spec
    for r in layoutRows {
        if !(r is Map) || !r.Has("cmdId")
            continue
        cid := Trim(String(r["cmdId"]))
        if (SubStr(cid, 1, 12) = "sc_menu_sep_")
            continue
        if (cid = "sc_copy_sub" || cid = "sc_send_sub")
            continue
        if !_VK_IsSearchCenterGridCmd(cid)
            continue
        spec.Push(Map("k", "cmd", "id", cid, "t", _SCWV_CmdDisplayName(cid)))
    }
    return spec
}

_SCWV_FilterToolbarSearchRows() {
    global g_Commands
    out := []
    if !(IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("ToolbarLayout"))
        return out
    raw := g_Commands["ToolbarLayout"]
    rows := []
    for r in raw
        rows.Push(r)
    if rows.Length > 1
        rows := _VK_SortRowsByNumericKey(rows, "order_search_row")
    for r in rows {
        if !(r is Map) || !r.Has("cmdId")
            continue
        if !r.Has("visible_in_search_row") || !r["visible_in_search_row"]
            continue
        if !_VK_ItemHasMenuScene(r, "search_center")
            continue
        cid := Trim(String(r["cmdId"]))
        if !_VK_IsSearchCenterGridCmd(cid)
            continue
        out.Push(r)
    }
    return out
}

_SCWV_ShowSearchCenterRowMenu(row, sx, sy, itemUid := "") {
    global g_SCWV_MenuActionRow, g_SCWV_MenuActionUid

    r := Integer(row)
    if (r < 1)
        return
    Item := GetSearchCenterResultItemByRow(r)
    if !IsObject(Item)
        return

    g_SCWV_MenuActionRow := r
    g_SCWV_MenuActionUid := (Trim(String(itemUid)) != "") ? String(itemUid) : _SCWV_ResultActionUid(Item, r)
    posX := Integer(sx)
    posY := Integer(sy)
    if (posX < 1 || posY < 1) {
        try DllCall("GetCursorPos", "int*", &cx := 0, "int*", &cy := 0)
        catch {
            cx := 0, cy := 0
        }
        posX := cx
        posY := cy
    }

    layoutRows := _SCWV_FilterToolbarSearchRows()
    spec := _SCWV_BuildSearchCtxMenuSpec(layoutRows)
    spec := _SCWV_RegroupSearchCtxSpec(spec, Item)
    try _SCWV_ShowDarkSearchRowMenuAt(spec, posX, posY)
    catch as err {
        try TrayTip("菜单显示失败", err.Message, "Iconx 2")
        catch {
        }
    }
}

SC_SearchCenterTogglePinByItem(Item) {
    global g_SCWV_PinnedKeys, SearchCenterWebKeyword

    k := _SCWV_ResultPinKey(Item)
    if (k = "")
        return
    if g_SCWV_PinnedKeys.Has(k) && g_SCWV_PinnedKeys[k]
        g_SCWV_PinnedKeys.Delete(k)
    else
        g_SCWV_PinnedKeys[k] := true
    _SCWV_ExecuteGoSearchHttp(0, SearchCenterWebKeyword, "", 0)
    SCWV_PushState("state")
}

SC_SearchCenterRestoreRecycleAt(binIndex) {
    global g_SCWV_RecycleBin, SearchCenterSearchResults

    i := Integer(binIndex)
    if i < 1 || i > g_SCWV_RecycleBin.Length
        return
    snap := g_SCWV_RecycleBin[i]
    g_SCWV_RecycleBin.RemoveAt(i)
    c := snap.Has("content") ? String(snap["content"]) : ""
    t := snap.Has("title") ? String(snap["title"]) : SubStr(c, 1, 80)
    id := snap.Has("id") ? snap["id"] : ""
    origDt := "text"
    dt := "text"
    ct := Trim(c)
    if (ct != "" && (FileExist(ct) || DirExist(ct))) {
        origDt := "file"
        dt := "File"
    }
    SearchCenterSearchResults.InsertAt(1, {
        Title: t,
        Content: c,
        Source: "回收站",
        DataType: dt,
        Time: "",
        OriginalDataType: origDt,
        ID: id
    })
    SCWV_PushState("state")
}

SC_SearchCenterEmptyRecycleBin() {
    global g_SCWV_RecycleBin
    g_SCWV_RecycleBin := []
    try TrayTip("已清空", "搜索中心回收站已清空", "Iconi 1")
    catch as _e {
    }
    try SCWV_PushState("state")
    catch as _e2 {
    }
}

SC_SearchCenterRemoveVisibleRowFromList(visibleRow) {
    global SearchCenterSearchResults, g_SCWV_PinnedKeys

    r := Integer(visibleRow)
    if (r < 1)
        return
    visItem := GetSearchCenterResultItemByRow(r)
    if !IsObject(visItem)
        return

    tgtKey := _SCWV_ResultPinKey(visItem)
    idx := 0
    Loop SearchCenterSearchResults.Length {
        it := SearchCenterSearchResults[A_Index]
        if (_SCWV_ResultPinKey(it) = tgtKey) {
            idx := A_Index
            break
        }
    }
    if (idx > 0) {
        SearchCenterSearchResults.RemoveAt(idx)
        if g_SCWV_PinnedKeys.Has(tgtKey)
            g_SCWV_PinnedKeys.Delete(tgtKey)
    }
    SCWV_PushState("state")
}

SC_SearchCenterRecycleVisibleRow(visibleRow) {
    global SearchCenterSearchResults, g_SCWV_RecycleBin

    r := Integer(visibleRow)
    if (r < 1)
        return
    visItem := GetSearchCenterResultItemByRow(r)
    if !IsObject(visItem)
        return

    Content := visItem.HasProp("Content") ? visItem.Content : visItem.Title
    DataType := visItem.HasProp("DataType") ? visItem.DataType : ""
    origDt := visItem.HasProp("OriginalDataType") ? visItem.OriginalDataType : ""
    isFileLike := (DataType = "file" || DataType = "File" || DataType = "Folder" || origDt = "file")

    if isFileLike && Content != "" && FileExist(Content) {
        try FileRecycle(Content)
        catch as err {
            try TrayTip("回收失败", err.Message, "Iconx 2")
            catch {
            }
            return
        }
    }

    try g_SCWV_RecycleBin.Push(Map(
        "title", visItem.HasProp("Title") ? visItem.Title : "",
        "content", Content,
        "id", visItem.HasProp("ID") ? visItem.ID : ""
    ))
    catch {
    }

    SC_SearchCenterRemoveVisibleRowFromList(r)
}

SC_SearchCenterDeleteVisibleRow(visibleRow) {
    SC_SearchCenterRecycleVisibleRow(visibleRow)
}

; 鈹€鈹€ SearchCenter 鏂囦欢棰勮锛歐eb 璇荤洏鍥炰紶 / IPreviewHandler 鍘熺敓 / QuickLook 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
global g_SCWV_PreviewSingleton := 0
global g_SCWV_QLRaiseTimer := 0

SCWV_Preview_Get() {
    global g_SCWV_PreviewSingleton
    ; 涓嶅彲瀵?/"" 浣跨敤 "is PreviewManager"锛屽惁鍒?v2 浼氭姏閿欙紙Resize 鏃跺嵆瑙﹀彂 鈫?鎼滅储涓績闂€€锛?    if !IsObject(g_SCWV_PreviewSingleton)
        g_SCWV_PreviewSingleton := PreviewManager()
    return g_SCWV_PreviewSingleton
}

SCWV_Preview_UnloadNative() {
    try SCWV_Preview_Get().Unload()
    catch {
    }
}

SCWV_Preview_OnHostLayoutChanged() {
    try SCWV_Preview_Get().OnHostLayoutChanged()
    catch {
    }
}

SCWV_Preview_OnWebText(path, seq) {
    try SCWV_Preview_Get().OnWebText(path, seq)
    catch as err {
        _SCWV_Preview_PostTextErr(seq, err.Message)
    }
}

SCWV_Preview_OnWebImage(path, seq) {
    try SCWV_Preview_Get().OnWebImage(path, seq)
    catch as err {
        SCWV_PostJson(Map("type", "WEB_PREVIEW_IMAGE_RESULT", "seq", seq, "dataUrl", "", "error", err.Message))
    }
}

SCWV_Preview_OnPdfium(path, seq) {
    try SCWV_Preview_Get().OnPdfium(path, seq)
    catch as err {
        SCWV_PostJson(Map("type", "WEB_PREVIEW_PDFIUM_RESULT", "seq", seq, "dataUrl", "", "error", err.Message))
    }
}

SCWV_Preview_OnArchiveList(path, seq, mode := "seven_zip") {
    try SCWV_Preview_Get().OnArchiveList(path, seq, mode)
    catch as err {
        SCWV_PostJson(Map("type", "WEB_PREVIEW_ARCHIVE_RESULT", "seq", seq, "entries", [], "error", err.Message))
    }
}

SCWV_Preview_RequestMeta(path, seq) {
    try SCWV_Preview_Get().PostDetailMeta(path, seq)
    catch {
    }
}

SCWV_Preview_OnNative(path, seq, boundsMap) {
    try SCWV_Preview_Get().ScheduleNative(path, seq, boundsMap)
    catch as err {
        SCWV_PostJson(Map("type", "NATIVE_PREVIEW_FAILED", "message", err.Message))
    }
}

SCWV_Preview_TryQuickLook(path) {
    try SCWV_Preview_Get().TryQuickLook(path)
    catch {
    }
}

_SCWV_QuickLookPostOpenState(status, message := "", path := "") {
    st := Trim(String(status))
    if (st = "")
        st := "pending"
    try SCWV_PostJson(Map(
        "type", "quicklook_open_state",
        "status", st,
        "message", String(message),
        "path", String(path)
    ))
}

_SCWV_QuickLookInvokeReset() {
    global g_SCWV_QLInvokeTimer, g_SCWV_QLInvokePath, g_SCWV_QLInvokeExe, g_SCWV_QLInvokeDir, g_SCWV_QLInvokeAttempts, g_SCWV_QLInvokeSendCount
    if g_SCWV_QLInvokeTimer {
        try SetTimer(g_SCWV_QLInvokeTimer, 0)
        g_SCWV_QLInvokeTimer := 0
    }
    g_SCWV_QLInvokePath := ""
    g_SCWV_QLInvokeExe := ""
    g_SCWV_QLInvokeDir := ""
    g_SCWV_QLInvokeAttempts := 0
    g_SCWV_QLInvokeSendCount := 0
}

_SCWV_QuickLookInvokeSchedule(delayMs := 0) {
    global g_SCWV_QLInvokeTimer
    ms := Max(0, Integer(delayMs))
    if !g_SCWV_QLInvokeTimer
        g_SCWV_QLInvokeTimer := _SCWV_QuickLookInvokeStep
    SetTimer(g_SCWV_QLInvokeTimer, -ms)
}

_SCWV_QuickLookInvokeBegin(path, qlExe) {
    global g_SCWV_QLInvokePath, g_SCWV_QLInvokeExe, g_SCWV_QLInvokeDir, g_SCWV_QLInvokeAttempts, g_SCWV_QLInvokeSendCount
    _SCWV_QuickLookInvokeReset()
    g_SCWV_QLInvokePath := Trim(String(path))
    g_SCWV_QLInvokeExe := Trim(String(qlExe))
    SplitPath(g_SCWV_QLInvokeExe, , &qld)
    g_SCWV_QLInvokeDir := qld
    g_SCWV_QLInvokeAttempts := 0
    g_SCWV_QLInvokeSendCount := 0
    _SCWV_QuickLookPostOpenState("pending", "正在调用 QuickLook…", g_SCWV_QLInvokePath)
    _SCWV_QuickLookInvokeSchedule(10)
}

_SCWV_QuickLookFindPreviewHwnd() {
    lst := WinGetList("ahk_exe QuickLook.exe")
    if !(IsObject(lst) && lst.Length)
        return 0
    best := 0
    bestArea := 0
    for _, hwnd in lst {
        expr := "ahk_id " hwnd
        try {
            if !WinExist(expr)
                continue
            if !DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int")
                continue
            mm := WinGetMinMax(expr)
            if (mm = -1) ; minimized
                continue
            WinGetPos(, , &w, &h, expr)
            if (w < 120 || h < 80)
                continue
            a := w * h
            if (a > bestArea) {
                bestArea := a
                best := hwnd
            }
        } catch {
        }
    }
    return best
}

_SCWV_QuickLookInvokeStep(*) {
    global g_SCWV_QLInvokePath, g_SCWV_QLInvokeExe, g_SCWV_QLInvokeDir, g_SCWV_QLInvokeAttempts, g_SCWV_QLInvokeSendCount, g_SCWV_QLRaiseTimer
    p := Trim(String(g_SCWV_QLInvokePath))
    ql := Trim(String(g_SCWV_QLInvokeExe))
    qd := String(g_SCWV_QLInvokeDir)
    if (p = "" || ql = "") {
        _SCWV_QuickLookInvokeReset()
        return
    }
    if (!FileExist(p) && !DirExist(p)) {
        _SCWV_QuickLookPostOpenState("fail", "文件已不存在，无法打开 QuickLook 预览。", p)
        _SCWV_QuickLookInvokeReset()
        return
    }
    if !FileExist(ql) {
        _SCWV_QuickLookPostOpenState("fail", "QuickLook 未安装或路径无效。", p)
        _SCWV_QuickLookInvokeReset()
        return
    }

    g_SCWV_QLInvokeAttempts += 1
    maxAttempts := 10
    if !ProcessExist("QuickLook.exe") {
        try Run('"' ql '"', qd)
        catch as err {
            if (g_SCWV_QLInvokeAttempts >= maxAttempts) {
                _SCWV_QuickLookPostOpenState("fail", "启动 QuickLook 失败: " . err.Message, p)
                _SCWV_QuickLookInvokeReset()
                return
            }
        }
        _SCWV_QuickLookPostOpenState("pending", "QuickLook 启动中…", p)
        _SCWV_QuickLookInvokeSchedule(420)
        return
    }

    shouldSend := (g_SCWV_QLInvokeSendCount = 0)
    ; 仅在等待较久时补发一次，避免重复调用触发 QuickLook 反向切换关闭。
    if (!shouldSend && g_SCWV_QLInvokeSendCount = 1 && g_SCWV_QLInvokeAttempts >= 6)
        shouldSend := true

    if shouldSend {
        try {
            Run('"' ql '" "' p '"', qd, "UseErrorLevel")
            g_SCWV_QLInvokeSendCount += 1
        } catch as err {
            if (g_SCWV_QLInvokeAttempts >= maxAttempts) {
                _SCWV_QuickLookPostOpenState("fail", "调用 QuickLook 失败: " . err.Message, p)
                _SCWV_QuickLookInvokeReset()
                return
            }
            _SCWV_QuickLookPostOpenState("pending", "正在重试打开 QuickLook 预览…", p)
            _SCWV_QuickLookInvokeSchedule(260)
            return
        }

    }

    ; 只有本次请求已至少发送过一次目标路径，才认定“已激活”。
    ; 否则 QuickLook 仅是已有旧窗口时会被误判成功，导致新文件不切换。
    hwnd := _SCWV_QuickLookFindPreviewHwnd()
    if (hwnd && g_SCWV_QLInvokeSendCount > 0) {
        if g_SCWV_QLRaiseTimer {
            try SetTimer(g_SCWV_QLRaiseTimer, 0)
            g_SCWV_QLRaiseTimer := 0
        }
        g_SCWV_QLRaiseTimer := _SCWV_QuickLookRaiseOnce
        SetTimer(_SCWV_QuickLookRaiseOnce, -120)
        _SCWV_QuickLookPostOpenState("ok", "QuickLook 预览窗口已激活。", p)
        _SCWV_QuickLookInvokeReset()
        return
    }

    if (g_SCWV_QLInvokeAttempts >= maxAttempts) {
        _SCWV_QuickLookPostOpenState("fail", "QuickLook 已启动，但未出现预览窗口。请重试或重新安装 QuickLook。", p)
        _SCWV_QuickLookInvokeReset()
        return
    }

    _SCWV_QuickLookPostOpenState("pending", "等待 QuickLook 显示预览窗口…（" . g_SCWV_QLInvokeAttempts . "/" . maxAttempts . "）", p)
    _SCWV_QuickLookInvokeSchedule(260)
}

_SCWV_ResolveQuickLookPathByRow(row) {
    r := Integer(row)
    if (r < 1)
        return ""
    item := GetSearchCenterResultItemByRow(r)
    if !IsObject(item)
        return ""

    p := ""
    if item.HasProp("Path")
        p := Trim(String(item.Path))
    if (p != "" && (FileExist(p) || DirExist(p)))
        return p

    c := ""
    if item.HasProp("Content")
        c := Trim(String(item.Content))
    if (c != "" && (FileExist(c) || DirExist(c)))
        return c

    return ""
}

_SCWV_Preview_PostTextErr(seq, msg) {
    SCWV_PostJson(Map("type", "WEB_PREVIEW_TEXT_RESULT", "seq", seq, "text", "", "truncated", false, "sizeBytes", 0, "error", msg))
}

_SCWV_QuickLookRaiseOnce(*) {
    global g_SCWV_QLRaiseTimer
    g_SCWV_QLRaiseTimer := 0
    best := _SCWV_QuickLookFindPreviewHwnd()
    if !best
        return
    expr := "ahk_id " best
    try {
        FocusBroker_Request("SearchCenter", best, 20, "quicklook_raise", 300)
        WinSetAlwaysOnTop 1, expr
    } catch {
    }
}

_SCWV_B64EncodeBuf(buf) {
    if !(buf is Buffer) || buf.Size <= 0
        return ""
    encSz := 0
    DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf.Ptr, "UInt", buf.Size, "UInt", 0x40000001, "Ptr", 0, "UInt*", &encSz)
    if (encSz <= 1)
        return ""
    out := Buffer(encSz * 2, 0)
    if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf.Ptr, "UInt", buf.Size, "UInt", 0x40000001, "Ptr", out.Ptr, "UInt*", &encSz)
        return ""
    return StrGet(out.Ptr, encSz - 1, "UTF-16")
}

_SCWV_CountReplacementChar(s) {
    c := 0
    try StrReplace(String(s), "�", "", &c)
    catch {
        c := 0
    }
    return c
}

_SCWV_DecodeTextBuffer(buf, sizeBytes) {
    if !(buf is Buffer) || sizeBytes <= 0
        return ""
    if (sizeBytes >= 3) {
        b0 := NumGet(buf, 0, "UChar"), b1 := NumGet(buf, 1, "UChar"), b2 := NumGet(buf, 2, "UChar")
        if (b0 = 0xEF && b1 = 0xBB && b2 = 0xBF)
            return StrGet(buf.Ptr + 3, sizeBytes - 3, "UTF-8")
    }
    if (sizeBytes >= 2) {
        b0 := NumGet(buf, 0, "UChar"), b1 := NumGet(buf, 1, "UChar")
        if (b0 = 0xFF && b1 = 0xFE)
            return StrGet(buf.Ptr + 2, Floor((sizeBytes - 2) / 2), "UTF-16")
        if (b0 = 0xFE && b1 = 0xFF)
            return StrGet(buf.Ptr + 2, Floor((sizeBytes - 2) / 2), "UTF-16")
    }
    txtUtf8 := StrGet(buf, sizeBytes, "UTF-8")
    badUtf8 := _SCWV_CountReplacementChar(txtUtf8)
    if (badUtf8 = 0)
        return txtUtf8
    txt936 := StrGet(buf, sizeBytes, "CP936")
    bad936 := _SCWV_CountReplacementChar(txt936)
    return (bad936 < badUtf8) ? txt936 : txtUtf8
}

_SCWV_FormatFileSizeBytes(sz) {
    if (!IsNumber(sz) || sz < 0)
        return ""
    if (sz > 1048576)
        return Round(sz / 1048576, 2) . " MB"
    if (sz > 1024)
        return Round(sz / 1024, 1) . " KB"
    return sz . " B"
}

_SCWV_ResultSizeForWeb(item, filePath := "") {
    sizeBytes := 0
    if IsObject(item) && item.HasProp("Metadata") && item.Metadata is Map {
        m := item.Metadata
        if m.Has("Size") {
            try sizeBytes := Integer(m["Size"])
            catch {
            }
        }
        if (sizeBytes <= 0 && m.Has("IndexedSize")) {
            try sizeBytes := Integer(m["IndexedSize"])
            catch {
            }
        }
    }
    fp := Trim(String(filePath))
    if (fp != "" && DirExist(fp))
        return Map("sizeBytes", 0, "sizeLabel", "文件夹")
    if (sizeBytes <= 0 && fp != "" && FileExist(fp) && !DirExist(fp)) {
        try sizeBytes := FileGetSize(fp)
        catch {
        }
    }
    if (sizeBytes <= 0)
        return Map("sizeBytes", 0, "sizeLabel", "")
    return Map("sizeBytes", sizeBytes, "sizeLabel", _SCWV_FormatFileSizeBytes(sizeBytes))
}

_SCWV_UnixToLabel(secs) {
    try {
        if (!IsNumber(secs) || secs <= 0)
            return ""
        dt := DateAdd("19700101", Integer(secs), "Seconds")
        return FormatTime(dt, "yyyy-MM-dd HH:mm")
    } catch {
        return ""
    }
}

_SCWV_FileTimeToLabel(ft) {
    try n := Integer(ft)
    catch {
        return ""
    }
    if (n <= 116444736000000000)
        return ""
    return _SCWV_UnixToLabel((n - 116444736000000000) // 10000000)
}

_SCWV_ResultModifiedForWeb(item, filePath := "") {
    label := ""
    if IsObject(item) && item.HasProp("Metadata") && item.Metadata is Map {
        m := item.Metadata
        if m.Has("Timestamp") {
            ts := Trim(String(m["Timestamp"]))
            if (ts != "")
                label := ts
        }
        if (label = "" && m.Has("DateModified")) {
            dm := m["DateModified"]
            if (dm is Float || (IsNumber(dm) && Integer(dm) > 100000000000000000))
                label := _SCWV_FileTimeToLabel(dm)
            else {
                dmText := Trim(String(dm))
                if (dmText != "" && RegExMatch(dmText, "^\d{4}[-/]\d"))
                    label := SubStr(RegExReplace(dmText, "/", "-"), 1, 16)
            }
        }
    }
    if (label = "" && item.HasProp("Time")) {
        t := Trim(String(item.Time))
        if (t != "" && RegExMatch(t, "^\d{4}[-/]\d"))
            label := SubStr(RegExReplace(t, "/", "-"), 1, 16)
    }
    fp := Trim(String(filePath))
    if (label = "" && fp != "" && (FileExist(fp) || DirExist(fp))) {
        try label := FormatTime(FileGetTime(fp, "M"), "yyyy-MM-dd HH:mm")
        catch {
        }
    }
    return label
}

_SCWV_ReadFileTextSmart(path, maxBytes := 0) {
    if (path = "" || !FileExist(path))
        return ""
    sz := FileGetSize(path)
    if (sz <= 0)
        return ""
    n := (maxBytes > 0) ? Min(sz, maxBytes) : sz
    f := FileOpen(path, "r")
    buf := Buffer(n, 0)
    f.RawRead(buf, n)
    f.Close()
    return _SCWV_DecodeTextBuffer(buf, n)
}

_SCWV_ExecCapture(cmd, timeoutMs := 12000) {
    result := Map("stdout", "", "stderr", "", "timedOut", false, "exitCode", "")
    sh := ComObject("WScript.Shell")
    ex := sh.Exec(cmd)
    t0 := A_TickCount
    outText := ""
    errText := ""

    while true {
        try {
            while !ex.StdOut.AtEndOfStream
                outText .= ex.StdOut.Read(4096)
        } catch {
        }
        try {
            while !ex.StdErr.AtEndOfStream
                errText .= ex.StdErr.Read(2048)
        } catch {
        }

        if (ex.Status != 0)
            break

        if ((A_TickCount - t0) > timeoutMs) {
            result["timedOut"] := true
            try ex.Terminate()
            break
        }
        Sleep 30
    }

    try {
        while !ex.StdOut.AtEndOfStream
            outText .= ex.StdOut.Read(4096)
    } catch {
    }
    try {
        while !ex.StdErr.AtEndOfStream
            errText .= ex.StdErr.Read(2048)
    } catch {
    }
    try result["exitCode"] := ex.ExitCode
    catch {
    }
    result["stdout"] := outText
    result["stderr"] := errText
    return result
}

_SCWV_IsVideoExt(ext) {
    e := StrLower(Trim(String(ext)))
    return (e = "mp4" || e = "m4v" || e = "mov" || e = "webm" || e = "mkv" || e = "avi")
}

_SCWV_SimpleHash(text) {
    s := String(text)
    h := 2166136261
    Loop Parse, s {
        h := Mod((h ^ Ord(A_LoopField)) * 16777619, 4294967296)
    }
    return Format("{:08X}", h)
}

_SCWV_GetMediaDurationSeconds(path) {
    ffprobe := Nmer_LibRuntimePath("ffprobe.exe")
    if !FileExist(ffprobe)
        return ""
    cmd := '"' ffprobe '" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "' path '"'
    try cap := _SCWV_ExecCapture(cmd, 8000)
    catch
        return ""
    out := Trim(cap["stdout"])
    if (out = "")
        return ""
    try n := Number(out)
    catch
        return ""
    if !IsNumber(n)
        return ""
    return n
}

_SCWV_GetPosterSeekSeconds(durationSec) {
    try d := Number(durationSec)
    catch
        d := 0
    if !(d > 0)
        return 1.2
    if (d <= 8)
        return Min(Max(d * 0.35, 0.6), Max(d - 0.2, 0.6))
    return Min(Max(d * 0.12, 1.2), 18)
}

_SCWV_BuildMediaPoster(path, durationSec := "") {
    ffmpeg := Nmer_LibRuntimePath("ffmpeg.exe")
    if !FileExist(ffmpeg)
        return ""
    if (path = "" || !FileExist(path))
        return ""
    SplitPath path, &fileName
    size := 0
    modTime := ""
    try size := FileGetSize(path)
    try modTime := FileGetTime(path, "M")
    cacheDir := A_ScriptDir "\cache\searchcenter_media"
    try DirCreate(cacheDir)
    hash := _SCWV_SimpleHash(path "|" size "|" modTime "|" fileName)
    outPath := cacheDir "\" hash ".jpg"
    if FileExist(outPath) {
        try {
            if (FileGetSize(outPath) > 0)
                return outPath
        } catch {
        }
    }
    seekSec := _SCWV_GetPosterSeekSeconds(durationSec)
    seekArg := Format("{:.3f}", seekSec)
    cmd := '"' ffmpeg '" -hide_banner -loglevel error -y -i "' path '" -ss ' seekArg ' -frames:v 1 -q:v 3 "' outPath '"'
    try cap := _SCWV_ExecCapture(cmd, 20000)
    catch
        return ""
    if FileExist(outPath) {
        try {
            if (FileGetSize(outPath) > 0)
                return outPath
        } catch {
        }
    }
    return ""
}

_SCWV_FormatFps(raw) {
    s := Trim(String(raw))
    if (s = "")
        return ""
    if InStr(s, "/") {
        parts := StrSplit(s, "/")
        if (parts.Length >= 2) {
            try n := Number(parts[1])
            catch {
                n := 0
            }
            try d := Number(parts[2])
            catch {
                d := 0
            }
            if (n > 0 && d > 0)
                return Format("{:.3f}", n / d)
        }
    }
    return s
}

_SCWV_GetMediaInfo(path) {
    ffprobe := Nmer_LibRuntimePath("ffprobe.exe")
    if !FileExist(ffprobe)
        return Map()
    if (path = "" || !FileExist(path))
        return Map()
    cmd := '"' ffprobe '" -v error -print_format json -show_streams -show_format "' path '"'
    try cap := _SCWV_ExecCapture(cmd, 10000)
    catch
        return Map()
    json := Trim(cap["stdout"])
    if (json = "")
        return Map()
    try obj := Jxon_Load(json)
    catch
        return Map()
    info := Map()
    v := 0, a := 0
    try {
        if (obj.Has("streams") && obj["streams"] is Array) {
            for _, st in obj["streams"] {
                ctype := ""
                try ctype := String(st["codec_type"])
                if (ctype = "video" && !IsObject(v))
                    v := st
                else if (ctype = "audio" && !IsObject(a))
                    a := st
            }
        }
    }
    try {
        fmt := obj.Has("format") ? obj["format"] : 0
        if (fmt && fmt is Map) {
            if fmt.Has("format_name")
                info["封装"] := String(fmt["format_name"])
            if fmt.Has("bit_rate") {
                try br := Round(Number(fmt["bit_rate"]) / 1000)
                if (br > 0)
                    info["总码率"] := br . " kb/s"
            }
        }
    }
    if (v && v is Map) {
        try if v.Has("codec_name")
            info["视频编码"] := String(v["codec_name"])
        try if v.Has("profile")
            info["视频配置"] := String(v["profile"])
        try if v.Has("pix_fmt")
            info["像素格式"] := String(v["pix_fmt"])
        try {
            vw := v.Has("width") ? Integer(v["width"]) : 0
            vh := v.Has("height") ? Integer(v["height"]) : 0
            if (vw > 0 && vh > 0)
                info["分辨率"] := vw . " x " . vh
        }
        try if v.Has("r_frame_rate") {
            fps := _SCWV_FormatFps(v["r_frame_rate"])
            if (fps != "")
                info["帧率"] := fps . " fps"
        }
    }
    if (a && a is Map) {
        try if a.Has("codec_name")
            info["音频编码"] := String(a["codec_name"])
        try if a.Has("channels")
            info["声道"] := String(a["channels"])
        try if a.Has("sample_rate")
            info["采样率"] := String(a["sample_rate"]) . " Hz"
    }
    return info
}

_SCWV_Parse7zList(text, archivePath, maxItems := 500, &total := 0, &truncated := false) {
    entries := []
    block := Map()
    total := 0
    truncated := false
    arc := StrReplace(StrLower(String(archivePath)), "/", "\")

    ; 解析 key = value 块，空行分隔
    Loop Parse text, "`n", "`r" {
        ln := Trim(A_LoopField)
        if (ln = "") {
            if (block.Count > 0) {
                hasPath := block.Has("Path")
                if hasPath {
                    p := String(block["Path"])
                    pl := StrReplace(StrLower(p), "/", "\")
                    isHeader := (pl = arc) || (p = "") || (p = "-")
                    if (!isHeader) {
                        total += 1
                        if (entries.Length < maxItems) {
                            isFolder := block.Has("Folder") && InStr(String(block["Folder"]), "+")
                            entries.Push(Map(
                                "path", p,
                                "folder", !!isFolder,
                                "size", block.Has("Size") ? String(block["Size"]) : "",
                                "packed", block.Has("Packed Size") ? String(block["Packed Size"]) : "",
                                "modified", block.Has("Modified") ? String(block["Modified"]) : ""
                            ))
                        } else {
                            truncated := true
                        }
                    }
                }
                block := Map()
            }
            continue
        }
        if RegExMatch(ln, "^\s*([^=]+?)\s*=\s*(.*)$", &m) {
            k := Trim(m[1])
            v := m[2]
            block[k] := v
        }
    }

    if (block.Count > 0) {
        hasPath := block.Has("Path")
        if hasPath {
            p := String(block["Path"])
            pl := StrReplace(StrLower(p), "/", "\")
            isHeader := (pl = arc) || (p = "") || (p = "-")
            if (!isHeader) {
                total += 1
                if (entries.Length < maxItems) {
                    isFolder := block.Has("Folder") && InStr(String(block["Folder"]), "+")
                    entries.Push(Map(
                        "path", p,
                        "folder", !!isFolder,
                        "size", block.Has("Size") ? String(block["Size"]) : "",
                        "packed", block.Has("Packed Size") ? String(block["Packed Size"]) : "",
                        "modified", block.Has("Modified") ? String(block["Modified"]) : ""
                    ))
                } else {
                    truncated := true
                }
            }
        }
    }

    return entries
}

_SCWV_ListZipEntries(path, maxItems := 500, &total := 0, &truncated := false) {
    total := 0
    truncated := false
    entries := []
    zip := ComObject("Shell.Application").NameSpace(path)
    if !zip
        throw Error("zip_namespace_open_failed")
    items := zip.Items()
    cnt := 0
    try cnt := items.Count
    catch {
        cnt := 0
    }
    Loop cnt {
        idx := A_Index - 1
        try it := items.Item(idx)
        catch {
            continue
        }
        total += 1
        if (entries.Length >= maxItems) {
            truncated := true
            continue
        }
        nm := ""
        sz := ""
        mod := ""
        isFolder := false
        try nm := String(it.Name)
        try sz := String(it.Size)
        try mod := String(it.ModifyDate)
        try isFolder := !!it.IsFolder
        entries.Push(Map(
            "path", nm,
            "folder", isFolder,
            "size", sz,
            "packed", "",
            "modified", mod
        ))
    }
    return entries
}

_SCWV_RegReadDefault(path) {
    try {
        v := RegRead(path, "")
        v := Trim(String(v))
        if (v != "")
            return v
    } catch {
    }
    return ""
}

_SCWV_ErrToText(err) {
    txt := ""
    try txt := String(err.Message)
    catch {
        txt := "unknown error"
    }
    try {
        if (err.What != "")
            txt .= " | what=" . String(err.What)
    } catch {
    }
    try {
        if (err.Extra != "")
            txt .= " | extra=" . String(err.Extra)
    } catch {
    }
    try txt .= " | line=" . String(err.Line)
    catch {
    }
    return txt
}

; Windows 长路径前缀 \\?\ ，避免字符串转义歧义
_SCWV_Win32LongPathPrefix() {
    return Chr(92) . Chr(92) . "?" . Chr(92)
}

; PDFium：在 Init 前将 icudtl.dat 所在目录（UTF-8）交给库，若导出不存在则忽略
_SCWV_FpdfSetIcuPathUtf8(dllPath, dirContainingIcuDat) {
    n := StrPut(dirContainingIcuDat, "UTF-8")
    buf := Buffer(n)
    StrPut(dirContainingIcuDat, buf, "UTF-8")
    return DllCall(dllPath "\FPDF_SetIcuDataPath", "ptr", buf.Ptr, "int")
}

_SCWV_PdfiumCloseFpdf(st, dllPath) {
    if !IsObject(st)
        return
    if st.bmp {
        try DllCall(dllPath "\FPDFBitmap_Destroy", "ptr", st.bmp)
        st.bmp := 0
    }
    if st.page {
        try DllCall(dllPath "\FPDF_ClosePage", "ptr", st.page)
        st.page := 0
    }
    if st.doc {
        try DllCall(dllPath "\FPDF_CloseDocument", "ptr", st.doc)
        st.doc := 0
    }
}

_SCWV_PdfiumCloseAll(st, dllPath) {
    if !IsObject(st)
        return
    if st.pClone {
        try Gdip_DisposeImage(st.pClone)
        st.pClone := 0
    }
    if st.pGdip {
        try Gdip_DisposeImage(st.pGdip)
        st.pGdip := 0
    }
    _SCWV_PdfiumCloseFpdf(st, dllPath)
}

; 使用 lib\pdfium.dll（Chromium PDFium 构建）渲染首页为 JPEG Base64；需 64 位 DLL 与 64 位 AHK 匹配
_SCWV_PdfiumTryRenderFirstPageJpeg(path, quality := 70) {
    dllPath := Nmer_LibRuntimePath("pdfium.dll")
    if !FileExist(dllPath)
        return { b64: "", err: "missing_dll", engine: "pdfium_native" }

    st := { doc: 0, page: 0, bmp: 0, pGdip: 0, pClone: 0 }
    libDir := A_ScriptDir "\lib"
    try {
        DllCall("kernel32\SetDllDirectoryW", "str", libDir)
        sz := FileGetSize(path)
        if (sz > 80 * 1024 * 1024 || sz < 16)
            return { b64: "", err: "文件过大或无效（>80MB）", engine: "pdfium_native" }

        static g_SCWV_PdfiumInit := false
        if !g_SCWV_PdfiumInit {
            if FileExist(libDir "\icudtl.dat") {
                try _SCWV_FpdfSetIcuPathUtf8(dllPath, libDir)
                catch {
                }
            }
            cfg := Buffer(4 + 3 * A_PtrSize + 4, 0)
            NumPut("uint", 2, cfg, 0)
            try DllCall(dllPath "\FPDF_InitLibraryWithConfig", "ptr", cfg)
            catch {
                DllCall(dllPath "\FPDF_InitLibrary")
            }
            g_SCWV_PdfiumInit := true
        }

        fb := FileRead(path, "RAW")
        st.doc := DllCall(dllPath "\FPDF_LoadMemDocument64", "ptr", fb.Ptr, "uptr", fb.Size, "ptr", 0, "ptr")
        if !st.doc {
            le := 0
            try le := DllCall(dllPath "\FPDF_GetLastError", "uint")
            return { b64: "", err: "FPDF_LoadMemDocument64 失败 (错误 " . (le != 0 ? le : "?") . ")", engine: "pdfium_native" }
        }

        n := DllCall(dllPath "\FPDF_GetPageCount", "ptr", st.doc, "int")
        if (n < 1) {
            _SCWV_PdfiumCloseFpdf(st, dllPath)
            return { b64: "", err: "PDF 无页面", engine: "pdfium_native" }
        }

        st.page := DllCall(dllPath "\FPDF_LoadPage", "ptr", st.doc, "int", 0, "ptr")
        if !st.page {
            _SCWV_PdfiumCloseFpdf(st, dllPath)
            return { b64: "", err: "无法加载首页", engine: "pdfium_native" }
        }

        pw := DllCall(dllPath "\FPDF_GetPageWidthF", "ptr", st.page, "float")
        ph := DllCall(dllPath "\FPDF_GetPageHeightF", "ptr", st.page, "float")
        if (pw <= 0 || ph <= 0) {
            try {
                pw := DllCall(dllPath "\FPDF_GetPageWidth", "ptr", st.page, "double")
                ph := DllCall(dllPath "\FPDF_GetPageHeight", "ptr", st.page, "double")
            } catch {
                pw := 0
                ph := 0
            }
        }
        if (pw <= 0 || ph <= 0) {
            _SCWV_PdfiumCloseFpdf(st, dllPath)
            return { b64: "", err: "无效页面尺寸", engine: "pdfium_native" }
        }

        maxW := 1200, maxH := 1800
        sc := Min(maxW / pw, maxH / ph, 1.0)
        rw := Max(1, Round(pw * sc))
        rh := Max(1, Round(ph * sc))

        st.bmp := DllCall(dllPath "\FPDFBitmap_Create", "int", rw, "int", rh, "int", 0, "ptr")
        if !st.bmp {
            _SCWV_PdfiumCloseFpdf(st, dllPath)
            return { b64: "", err: "FPDFBitmap_Create 失败", engine: "pdfium_native" }
        }

        DllCall(dllPath "\FPDFBitmap_FillRect", "ptr", st.bmp, "int", 0, "int", 0, "int", rw, "int", rh, "uint", 0xFFFFFFFF)
        DllCall(dllPath "\FPDF_RenderPageBitmap", "ptr", st.bmp, "ptr", st.page, "int", 0, "int", 0, "int", rw, "int", rh, "int", 0, "int", 1)

        stride := DllCall(dllPath "\FPDFBitmap_GetStride", "ptr", st.bmp, "int")
        bufPtr := DllCall(dllPath "\FPDFBitmap_GetBuffer", "ptr", st.bmp, "ptr")

        pGdip := 0
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", rw, "Int", rh, "Int", stride, "Int", 0x26200A, "UPtr", bufPtr, "UPtr*", &pGdip)
        st.pGdip := pGdip
        if !pGdip {
            _SCWV_PdfiumCloseFpdf(st, dllPath)
            return { b64: "", err: "GdipCreateBitmapFromScan0 失败", engine: "pdfium_native" }
        }

        st.pClone := Gdip_CloneBitmapArea(pGdip, 0, 0, rw, rh, 0x26200A)
        Gdip_DisposeImage(pGdip)
        st.pGdip := 0

        _SCWV_PdfiumCloseFpdf(st, dllPath)

        if !st.pClone
            return { b64: "", err: "Gdip_CloneBitmapArea 失败", engine: "pdfium_native" }

        b64 := ImagePut("Base64", { pBitmap: st.pClone }, "jpg", quality)
        Gdip_DisposeImage(st.pClone)
        st.pClone := 0

        if (b64 = "")
            return { b64: "", err: "JPEG 编码失败", engine: "pdfium_native" }

        return { b64: b64, err: "", engine: "pdfium_native" }
    } catch as e {
        _SCWV_PdfiumCloseAll(st, dllPath)
        return { b64: "", err: e.Message, engine: "pdfium_native", detail: _SCWV_ErrToText(e) }
    } finally {
        try DllCall("kernel32\SetDllDirectoryW", "ptr", 0)
    }
}

_SCWV_ReadProgIdForExt(extDot, &fromKey := "") {
    fromKey := ""
    roots := [
        "HKCU\Software\Classes\",
        "HKCR\"
    ]
    for _, r in roots {
        k := r . extDot
        v := _SCWV_RegReadDefault(k)
        if (v != "") {
            fromKey := k
            return v
        }
    }
    return ""
}

_SCWV_RegPreviewClsidForExt(extDot, &hitPath := "", &hitSource := "", &trace := 0) {
    guid := "{8895b1c6-b41f-4c1c-a562-0d564d35d9c5}"
    extDot := "." . LTrim(StrLower(String(extDot)), ".")
    shellex := "\shellex\" . guid
    hitPath := ""
    hitSource := ""
    progid := _SCWV_ReadProgIdForExt(extDot, &progidFrom)
    attempts := []

    directPaths := [
        "HKCU\Software\Classes\" . extDot . shellex,
        "HKCR\" . extDot . shellex
    ]
    for _, p in directPaths {
        attempts.Push(p)
        v := _SCWV_RegReadDefault(p)
        if (v != "") {
            hitPath := p
            hitSource := "ext_direct"
            trace := Map("attempts", attempts, "progid", progid, "progidFrom", progidFrom)
            return v
        }
    }

    if (progid != "") {
        progidPaths := [
            "HKCU\Software\Classes\" . progid . shellex,
            "HKCR\" . progid . shellex
        ]
        for _, p in progidPaths {
            attempts.Push(p)
            v := _SCWV_RegReadDefault(p)
            if (v != "") {
                hitPath := p
                hitSource := "progid"
                trace := Map("attempts", attempts, "progid", progid, "progidFrom", progidFrom)
                return v
            }
        }
    }

    sfaPaths := [
        "HKCU\Software\Classes\SystemFileAssociations\" . extDot . shellex,
        "HKCR\SystemFileAssociations\" . extDot . shellex
    ]
    for _, p in sfaPaths {
        attempts.Push(p)
        v := _SCWV_RegReadDefault(p)
        if (v != "") {
            hitPath := p
            hitSource := "system_file_assoc"
            trace := Map("attempts", attempts, "progid", progid, "progidFrom", progidFrom)
            return v
        }
    }

    trace := Map("attempts", attempts, "progid", progid, "progidFrom", progidFrom)
    return ""
}

_SCWV_WebViewClientScreenOrigin(&sx, &sy) {
    global g_SCWV_Gui, g_SCWV_Ctrl
    sx := 0, sy := 0
    if !g_SCWV_Gui || !g_SCWV_Ctrl
        return false
    ph := 0
    try ph := g_SCWV_Ctrl.ParentWindow
    catch {
        return false
    }
    if !ph
        return false
    try {
        pt := Buffer(8, 0)
        DllCall("user32\ClientToScreen", "Ptr", ph, "Ptr", pt)
        sx := NumGet(pt, 0, "Int")
        sy := NumGet(pt, 4, "Int")
    } catch {
        return false
    }
    return true
}

_SCWV_WebViewRasterScale() {
    global g_SCWV_Ctrl
    if !g_SCWV_Ctrl
        return 1
    try {
        sc := g_SCWV_Ctrl.RasterizationScale
        if (sc > 0.1 && sc < 10)
            return sc
    } catch {
    }
    return 1
}

_SCWV_BoundsMapToScreen(boundsMap, &rx, &ry, &rw, &rh) {
    global g_SCWV_Ctrl
    rx := 0, ry := 0, rw := 400, rh := 300
    if !g_SCWV_Ctrl
        return false
    rc := g_SCWV_Ctrl.Bounds
    bw := 800
    bh := 600
    bl := 0
    bt := 0
    try {
        bw := rc.right - rc.left
        bh := rc.bottom - rc.top
        bl := rc.left
        bt := rc.top
    } catch {
    }
    sc := _SCWV_WebViewRasterScale()
    cl := 0.0
    ct := 0.0
    cw := bw / Max(sc, 0.01)
    ch := bh / Max(sc, 0.01)
    if (boundsMap is Map) && boundsMap.Has("left") {
        cl := Float(boundsMap["left"])
        ct := Float(boundsMap["top"])
        cw := Float(boundsMap["width"])
        ch := Float(boundsMap["height"])
        if (boundsMap.Has("dpr")) {
            dpr := Float(boundsMap["dpr"])
            if (dpr > 0.1 && dpr < 10)
                sc := dpr
        }
    }
    if !(_SCWV_WebViewClientScreenOrigin(&psx, &psy))
        return false
    rx := psx + bl + Round(cl * sc)
    ry := psy + bt + Round(ct * sc)
    rw := Max(Round(cw * sc), 80)
    rh := Max(Round(ch * sc), 60)
    return true
}

class PreviewManager {
    NativeGui := 0
    PreviewHandler := 0
    InitObj := 0
    RootObj := 0
    CurrentPath := ""
    BoundsCss := 0
    NativeTimer := 0
    PendingPath := ""
    PendingSeq := 0
    PendingBounds := 0
    NativeLastDiag := 0

    Unload() {
        if this.PreviewHandler {
            try ComCall(9, this.PreviewHandler, "hresult") ; IPreviewHandler::Unload
            catch {
            }
            this.PreviewHandler := 0
        }
        this.InitObj := 0
        this.RootObj := 0
        if this.NativeGui {
            try this.NativeGui.Hide()
            catch {
            }
        }
        this.CurrentPath := ""
        this.BoundsCss := 0
        if this.NativeTimer {
            SetTimer(this.NativeTimer, 0)
            this.NativeTimer := 0
        }
        this.PendingPath := ""
        this.PendingSeq := 0
        this.PendingBounds := 0
    }

    _PostNativeFail(path, userMsg, reason := "", detail := "") {
        SplitPath path, , , &ext
        payload := Map(
            "type", "NATIVE_PREVIEW_FAILED",
            "message", userMsg,
            "path", path,
            "ext", StrLower(ext),
            "reason", reason,
            "detail", detail,
            "processArch", (A_PtrSize = 8 ? "x64" : "x86")
        )
        if (this.NativeLastDiag is Map)
            payload["diag"] := this.NativeLastDiag
        SCWV_PostJson(payload)
    }

    TryQuickLook(path) {
        path := Trim(String(path))
        if (path = "" || (!FileExist(path) && !DirExist(path))) {
            _SCWV_QuickLookPostOpenState("fail", "当前条目不是可预览的本地文件。", path)
            return
        }
        ql := SCWV_ResolveQuickLookExe()
        if (ql = "" || !FileExist(ql)) {
            _SCWV_QuickLookPostOpenState("fail", "QuickLook 未安装，请先点击“QuickLook”按钮下载并启用。", path)
            return
        }
        SCWV_Preview_UnloadNative()
        _SCWV_QuickLookInvokeBegin(path, ql)
    }

    OnWebText(path, seq) {
        path := Trim(String(path))
        this._PostDetailMeta(path, seq)
        if (path = "" || !FileExist(path)) {
            _SCWV_Preview_PostTextErr(seq, "鏃犳晥璺緞")
            return
        }
        sz := FileGetSize(path)
        truncated := false
        maxB := 1048576
        n := Min(sz, maxB)
        if (sz > maxB)
            truncated := true
        f := FileOpen(path, "r")
        buf := Buffer(n, 0)
        f.RawRead(buf, n)
        f.Close()
        text := _SCWV_DecodeTextBuffer(buf, n)
        lineTrunc := false
        if truncated {
            cnt := 0
            out := ""
            Loop Parse text, "`n", "`r" {
                cnt += 1
                if (cnt > 1000) {
                    lineTrunc := true
                    break
                }
                out .= (cnt > 1 ? "`n" : "") A_LoopField
            }
            text := out
        }
        SCWV_PostJson(Map(
            "type", "WEB_PREVIEW_TEXT_RESULT",
            "seq", seq,
            "text", text,
            "truncated", truncated || lineTrunc,
            "sizeBytes", sz
        ))
    }

    OnWebImage(path, seq) {
        path := Trim(String(path))
        this._PostDetailMeta(path, seq)
        if (path = "" || !FileExist(path)) {
            SCWV_PostJson(Map("type", "WEB_PREVIEW_IMAGE_RESULT", "seq", seq, "dataUrl", ""))
            return
        }
        sz := FileGetSize(path)
        if (sz > 12582912) {
            SCWV_PostJson(Map("type", "WEB_PREVIEW_IMAGE_RESULT", "seq", seq, "dataUrl", "", "error", "鍥剧墖杩囧ぇ"))
            return
        }
        f := FileOpen(path, "r")
        buf := Buffer(sz)
        f.RawRead(buf, sz)
        f.Close()
        b64 := _SCWV_B64EncodeBuf(buf)
        SplitPath path, , , &ext
        ext := StrLower(ext)
        mime := "application/octet-stream"
        if (ext = "png")
            mime := "image/png"
        else if (ext = "jpg" || ext = "jpeg")
            mime := "image/jpeg"
        else if (ext = "gif")
            mime := "image/gif"
        else if (ext = "svg")
            mime := "image/svg+xml"
        dataUrl := "data:" mime ";base64," b64
        SCWV_PostJson(Map("type", "WEB_PREVIEW_IMAGE_RESULT", "seq", seq, "dataUrl", dataUrl))
    }

    OnWebMedia(path, seq) {
        path := Trim(String(path))
        this._PostDetailMeta(path, seq)
        if (path = "" || !FileExist(path)) {
            SCWV_PostJson(Map("type", "WEB_PREVIEW_MEDIA_RESULT", "seq", seq, "path", path, "url", "", "posterUrl", "", "durationSec", "", "mediaInfo", Map()))
            return
        }
        mediaUrl := _SCWV_PathToWebAssetUrl(path)
        SplitPath path, , , &ext
        ext := StrLower(ext)
        durationSec := _SCWV_GetMediaDurationSeconds(path)
        posterUrl := ""
        mediaInfo := _SCWV_GetMediaInfo(path)
        if (_SCWV_IsVideoExt(ext)) {
            posterPath := _SCWV_BuildMediaPoster(path, durationSec)
            posterUrl := _SCWV_PathToWebAssetUrl(posterPath)
        }
        SCWV_PostJson(Map(
            "type", "WEB_PREVIEW_MEDIA_RESULT",
            "seq", seq,
            "path", path,
            "url", mediaUrl,
            "posterUrl", posterUrl,
            "durationSec", durationSec,
            "mediaInfo", mediaInfo
        ))
    }

    ; PDF.js 内嵌预览：分块 Base64 传入 WebView，避免跨虚拟主机 CORS
    OnWebPdfJs(path, seq) {
        path := Trim(String(path))
        this._PostDetailMeta(path, seq)
        maxTotal := 40 * 1024 * 1024
        chunk := 450000
        if (path = "" || !FileExist(path)) {
            SCWV_PostJson(Map("type", "WEB_PREVIEW_PDF_JS_ERROR", "seq", seq, "message", "invalid_path"))
            return
        }
        sz := FileGetSize(path)
        if (sz < 16) {
            SCWV_PostJson(Map("type", "WEB_PREVIEW_PDF_JS_ERROR", "seq", seq, "message", "file_too_small"))
            return
        }
        if (sz > maxTotal) {
            SCWV_PostJson(Map("type", "WEB_PREVIEW_PDF_JS_ERROR", "seq", seq, "message", "pdf_too_large_40mb"))
            return
        }
        totalParts := Ceil(sz / chunk)
        if (totalParts < 1)
            totalParts := 1
        SCWV_PostJson(Map(
            "type", "WEB_PREVIEW_PDF_JS_BEGIN",
            "seq", seq,
            "totalParts", totalParts,
            "totalBytes", sz
        ))
        try {
            f := FileOpen(path, "r")
            try {
                Loop totalParts {
                    i := A_Index - 1
                    remain := sz - i * chunk
                    n := Min(chunk, remain)
                    buf := Buffer(n, 0)
                    f.RawRead(buf, n)
                    b64 := _SCWV_B64EncodeBuf(buf)
                    if (b64 = "") {
                        SCWV_PostJson(Map("type", "WEB_PREVIEW_PDF_JS_ERROR", "seq", seq, "message", "b64_failed"))
                        return
                    }
                    SCWV_PostJson(Map("type", "WEB_PREVIEW_PDF_JS_PART", "seq", seq, "index", i, "data", b64))
                }
            } finally {
                try f.Close()
                catch {
                }
            }
        } catch as e {
            SCWV_PostJson(Map("type", "WEB_PREVIEW_PDF_JS_ERROR", "seq", seq, "message", e.Message))
        }
    }

    PostMediaInfo(path, seq) {
        path := Trim(String(path))
        info := _SCWV_GetMediaInfo(path)
        SCWV_PostJson(Map("type", "MEDIA_INFO_RESULT", "seq", seq, "path", path, "info", info))
    }

    SaveMediaFrame(path, timeSec := "", seq := 0) {
        path := Trim(String(path))
        ffmpeg := Nmer_LibRuntimePath("ffmpeg.exe")
        if (path = "" || !FileExist(path) || !FileExist(ffmpeg)) {
            SCWV_PostJson(Map("type", "MEDIA_FRAME_SAVE_RESULT", "seq", seq, "ok", false, "message", "保存截图失败"))
            return
        }
        safeName := RegExReplace(RegExReplace(path, "^.*[\\/]", ""), "\.[^.]+$", "")
        if (safeName = "")
            safeName := "video_frame"
        defaultPath := A_Desktop "\" safeName "_" . FormatTime(, "yyyyMMdd_HHmmss") . ".jpg"
        savePath := FileSelect("S16", defaultPath, "保存视频截图", "图片文件 (*.jpg; *.png)")
        if (savePath = "") {
            SCWV_PostJson(Map("type", "MEDIA_FRAME_SAVE_RESULT", "seq", seq, "ok", false, "message", "已取消保存"))
            return
        }
        SplitPath savePath, , , &outExt
        outExt := StrLower(outExt)
        seek := ""
        try seekNum := Number(timeSec)
        catch {
            seekNum := 0
        }
        if (seekNum < 0)
            seekNum := 0
        seek := Format("{:.3f}", seekNum)
        qArg := (outExt = "png") ? "" : " -q:v 2"
        cmd := '"' ffmpeg '" -hide_banner -loglevel error -y -i "' path '" -ss ' seek ' -frames:v 1' qArg ' "' savePath '"'
        try _SCWV_ExecCapture(cmd, 25000)
        catch as err {
            SCWV_PostJson(Map("type", "MEDIA_FRAME_SAVE_RESULT", "seq", seq, "ok", false, "message", err.Message))
            return
        }
        ok := false
        try ok := FileExist(savePath) && (FileGetSize(savePath) > 0)
        SCWV_PostJson(Map(
            "type", "MEDIA_FRAME_SAVE_RESULT",
            "seq", seq,
            "ok", ok,
            "message", ok ? "截图已保存" : "截图保存失败",
            "path", savePath
        ))
    }

    OnPdfium(path, seq) {
        path := Trim(String(path))
        this._PostDetailMeta(path, seq)
        if (path = "" || !FileExist(path)) {
            SCWV_PostJson(Map("type", "WEB_PREVIEW_PDFIUM_RESULT", "seq", seq, "dataUrl", "", "error", "invalid_path"))
            return
        }

        pdfiumDll := Nmer_LibRuntimePath("pdfium.dll")
        icuDat := Nmer_LibRuntimePath("icudtl.dat")
        diag := Map(
            "pdfiumDllPresent", !!FileExist(pdfiumDll),
            "icuDatPresent", !!FileExist(icuDat),
            "hint", "优先 lib\\runtime\\pdfium.dll + icudtl.dat（与 AHK 同位数）；失败则回退 Windows.Data.Pdf。"
        )

        ; 1) 原生 PDFium（lib\pdfium.dll）
        if FileExist(pdfiumDll) {
            r := _SCWV_PdfiumTryRenderFirstPageJpeg(path, 70)
            diag["engine"] := r.HasProp("engine") ? r.engine : "pdfium_native"
            if (r.b64 != "") {
                diag["branch"] := "pdfium_dll"
                SCWV_PostJson(Map(
                    "type", "WEB_PREVIEW_PDFIUM_RESULT",
                    "seq", seq,
                    "dataUrl", "data:image/jpeg;base64," . r.b64,
                    "diag", diag
                ))
                return
            }
            diag["pdfiumError"] := r.HasProp("err") ? r.err : ""
            if r.HasProp("detail")
                diag["pdfiumDetail"] := r.detail
        } else {
            diag["engine"] := "fallback_only"
            diag["pdfiumSkipped"] := "lib\\runtime\\pdfium.dll 不存在"
        }

        ; 2) 回退：ImagePut → Windows.Data.Pdf（WinRT）
        pathsToTry := [path]
        lp := _SCWV_Win32LongPathPrefix()
        if (StrLen(path) >= 240 && RegExMatch(path, "^[a-zA-Z]:\\") && SubStr(path, 1, 4) != lp) {
            pathsToTry.Push(lp . path)
        }

        oldRender := ImagePut.render
        try {
            ImagePut.render := 2
            lastMsg := ""
            lastDetail := ""
            for cand in pathsToTry {
                if !FileExist(cand)
                    continue
                try {
                    b64 := ImagePut("Base64", cand, "jpg", 70)
                    if (b64 = "")
                        throw Error("empty_base64")
                    diag["engine"] := "windows_data_pdf_imageput"
                    diag["branch"] := "winrt_fallback"
                    SCWV_PostJson(Map(
                        "type", "WEB_PREVIEW_PDFIUM_RESULT",
                        "seq", seq,
                        "dataUrl", "data:image/jpeg;base64," . b64,
                        "diag", diag
                    ))
                    return
                } catch as err {
                    lastMsg := err.Message
                    lastDetail := _SCWV_ErrToText(err)
                }
            }
            diag["error"] := lastDetail != "" ? lastDetail : "no_attempt"
            diag["engine"] := "failed"
            SCWV_PostJson(Map(
                "type", "WEB_PREVIEW_PDFIUM_RESULT",
                "seq", seq,
                "dataUrl", "",
                "error", lastMsg != "" ? lastMsg : "PDF 渲染失败（PDFium 与系统 PDF 均不可用）",
                "diag", diag
            ))
        } finally {
            try ImagePut.render := oldRender
        }
    }

    OnArchiveList(path, seq, mode := "seven_zip") {
        try {
            path := Trim(String(path))
            this._PostDetailMeta(path, seq)
            if (path = "" || !FileExist(path)) {
                SCWV_PostJson(Map("type", "WEB_PREVIEW_ARCHIVE_RESULT", "seq", seq, "entries", [], "error", "invalid_path"))
                return
            }

            SplitPath path, , , &ext
            ext := StrLower(ext)
            mode := Trim(String(mode))
            if (mode = "")
                mode := "seven_zip"

            if (mode = "zip_shell_first" && ext = "zip") {
                try {
                    total := 0
                    truncated := false
                    entries := _SCWV_ListZipEntries(path, 500, &total, &truncated)
                    SCWV_PostJson(Map(
                        "type", "WEB_PREVIEW_ARCHIVE_RESULT",
                        "seq", seq,
                        "entries", entries,
                        "total", total,
                        "truncated", !!truncated,
                        "error", ""
                    ))
                    return
                } catch {
                }
            }

            sevenZip := Nmer_LibRuntimePath("7z.exe")
            sevenZipDll := Nmer_LibRuntimePath("7z.dll")
            if !FileExist(sevenZip) {
                SCWV_PostJson(Map("type", "WEB_PREVIEW_ARCHIVE_RESULT", "seq", seq, "entries", [], "error", "7z.exe not found in lib"))
                return
            }
            if !FileExist(sevenZipDll) {
                SCWV_PostJson(Map("type", "WEB_PREVIEW_ARCHIVE_RESULT", "seq", seq, "entries", [], "error", "7z.dll not found in lib"))
                return
            }

            cmdUtf8 := '"' sevenZip '" l -slt -ba -y -p"" -bb0 -sccUTF-8 -- "' path '"'
            try {
                cap1 := _SCWV_ExecCapture(cmdUtf8, 12000)
                outText := cap1["stdout"]
                errText := cap1["stderr"]
                timedOut := cap1["timedOut"]
            } catch as e {
                outText := ""
                errText := e.Message
                timedOut := false
            }

            if (timedOut) {
                SCWV_PostJson(Map("type", "WEB_PREVIEW_ARCHIVE_RESULT", "seq", seq, "entries", [], "error", "7z timeout (12s)"))
                return
            }

            if (InStr(outText, "Codec Load Error") || InStr(errText, "Codec Load Error")) {
                SCWV_PostJson(Map("type", "WEB_PREVIEW_ARCHIVE_RESULT", "seq", seq, "entries", [], "error", "7z.dll 与 7z.exe 不兼容或位数不匹配"))
                return
            }

            if (Trim(outText) = "") {
                ; 某些 7z 版本不支持 -sccUTF-8，回退一次不带该参数
                cmdBasic := '"' sevenZip '" l -slt -ba -y -p"" -bb0 -- "' path '"'
                try {
                    cap2 := _SCWV_ExecCapture(cmdBasic, 12000)
                    outText2 := cap2["stdout"]
                    errText2 := cap2["stderr"]
                    timedOut2 := cap2["timedOut"]
                } catch as e2 {
                    outText2 := ""
                    errText2 := e2.Message
                    timedOut2 := false
                }
                if (timedOut2) {
                    SCWV_PostJson(Map("type", "WEB_PREVIEW_ARCHIVE_RESULT", "seq", seq, "entries", [], "error", "7z timeout (12s)"))
                    return
                }
                if (InStr(outText2, "Codec Load Error") || InStr(errText2, "Codec Load Error")) {
                    SCWV_PostJson(Map("type", "WEB_PREVIEW_ARCHIVE_RESULT", "seq", seq, "entries", [], "error", "7z.dll 与 7z.exe 不兼容或位数不匹配"))
                    return
                }
                if (Trim(outText2) != "") {
                    outText := outText2
                    errText := errText2
                } else if (Trim(errText2) != "") {
                    errText := errText2
                }
            }

            if (Trim(outText) = "") {
                e := Trim(errText)
                if (e = "")
                    e := "empty output"
                if (ext = "zip") {
                    try {
                        entries := _SCWV_ListZipEntries(path, 500, &total, &truncated)
                        SCWV_PostJson(Map(
                            "type", "WEB_PREVIEW_ARCHIVE_RESULT",
                            "seq", seq,
                            "entries", entries,
                            "total", total,
                            "truncated", !!truncated,
                            "error", ""
                        ))
                        return
                    } catch {
                    }
                }
                SCWV_PostJson(Map("type", "WEB_PREVIEW_ARCHIVE_RESULT", "seq", seq, "entries", [], "error", e))
                return
            }

            entries := _SCWV_Parse7zList(outText, path, 500, &total, &truncated)
            SCWV_PostJson(Map(
                "type", "WEB_PREVIEW_ARCHIVE_RESULT",
                "seq", seq,
                "entries", entries,
                "total", total,
                "truncated", !!truncated,
                "error", ""
            ))
        } catch as fatal {
            SCWV_PostJson(Map("type", "WEB_PREVIEW_ARCHIVE_RESULT", "seq", seq, "entries", [], "error", "archive_preview_exception: " . fatal.Message))
        }
    }

    ScheduleNative(path, seq, boundsMap) {
        path := Trim(String(path))
        this._PostDetailMeta(path, seq)
        if (path = "" || !FileExist(path)) {
            this.NativeLastDiag := Map("step", "precheck", "error", "invalid_path")
            this._PostNativeFail(path, "无效路径", "invalid_path")
            return
        }

        ; 濡傛灉璺緞娌″彉涓旂獥鍙ｅ凡瀛樺湪锛屼粎瑙﹀彂甯冨眬鍒锋柊 (Resize)锛屼笉閲嶆柊鍔犺浇 COM
        if (this.CurrentPath = path && this.PreviewHandler && this.NativeGui) {
            this.BoundsCss := boundsMap
            this.OnHostLayoutChanged()
            return
        }

        this.PendingPath := path
        this.PendingSeq := seq
        this.PendingBounds := boundsMap
        if this.NativeTimer
            SetTimer(this.NativeTimer, 0)
        this.NativeTimer := ObjBindMethod(this, "_FireNativeDebounced")
        SetTimer(this.NativeTimer, -150)
    }

    _FireNativeDebounced() {
        this.NativeTimer := 0
        p := this.PendingPath
        sq := this.PendingSeq
        bm := this.PendingBounds
        if (p = "")
            return

        ; 鍗充娇鏄噸鏂板姞杞戒篃鍙渶娓呯悊 COM锛屼笉閿€姣?GUI
        if this.PreviewHandler {
            try ComCall(9, this.PreviewHandler, "hresult")
            catch {
            }
            this.PreviewHandler := 0
        }
        this.InitObj := 0
        this.RootObj := 0
        
        this.CurrentPath := p
        this.BoundsCss := bm
        
        global g_SCWV_Gui
        if !g_SCWV_Gui {
            this.NativeLastDiag := Map("step", "precheck", "error", "host_not_ready")
            this._PostNativeFail(p, "窗口未就绪", "host_not_ready")
            return
        }
        
        if !_SCWV_BoundsMapToScreen(bm, &rx, &ry, &rw, &rh) {
            this.NativeLastDiag := Map("step", "precheck", "error", "bounds_invalid")
            this._PostNativeFail(p, "无法计算预览区域", "bounds_invalid")
            return
        }

        if !this.NativeGui {
            ownerHwnd := g_SCWV_Gui.Hwnd
            this.NativeGui := Gui("+Owner" . ownerHwnd . " -Caption +ToolWindow +Border", "SCNativePreview")
            this.NativeGui.BackColor := "0d1016"
        }
        
        this.NativeGui.Show("x" rx " y" ry " w" rw " h" rh " NoActivate")
        try WinSetAlwaysOnTop true, "ahk_id " . this.NativeGui.Hwnd
        catch {
        }
        
        hostHwnd := this.NativeGui.Hwnd
        if !this._AttachPreviewHandler(p, hostHwnd, rw, rh) {
            this.Unload()
            this._PostNativeFail(p, "系统预览组件不可用（可改用侧栏 PDF.js 内嵌预览）", "attach_failed")
        }
    }

    OnHostLayoutChanged() {
        if !this.PreviewHandler || !this.NativeGui || !this.BoundsCss
            return
        if !_SCWV_BoundsMapToScreen(this.BoundsCss, &rx, &ry, &rw, &rh)
            return
        try this.NativeGui.Move(rx, ry, rw, rh)
        catch {
        }
        rect := Buffer(16, 0)
        NumPut("int", 0, rect, 0)
        NumPut("int", 0, rect, 4)
        NumPut("int", rw, rect, 8)
        NumPut("int", rh, rect, 12)
        try ComCall(7, this.PreviewHandler, "ptr", rect.Ptr, "hresult")
        catch {
        }
    }

    _AttachPreviewHandler(path, hostHwnd, w, h) {
        global g_SCWV_PreviewCapabilityCache
        SplitPath path, , , &ext
        extDot := "." StrLower(ext)
        nowTick := A_TickCount

        if g_SCWV_PreviewCapabilityCache.Has(extDot) {
            cacheEntry := g_SCWV_PreviewCapabilityCache[extDot]
            if (cacheEntry is Map) {
                st := cacheEntry.Has("state") ? String(cacheEntry["state"]) : ""
                ts := cacheEntry.Has("ts") ? Integer(cacheEntry["ts"]) : 0
                if (st = "no_handler" && (nowTick - ts) < 300000) {
                    this.NativeLastDiag := Map(
                        "step", "resolve_clsid",
                        "ext", extDot,
                        "state", st,
                        "cacheHit", true,
                        "cacheAgeMs", nowTick - ts,
                        "error", "cached_no_handler"
                    )
                    return false
                }
            }
        }

        clsid := _SCWV_RegPreviewClsidForExt(extDot, &regPath, &regSource, &regTrace)
        if (clsid = "") {
            g_SCWV_PreviewCapabilityCache[extDot] := Map(
                "state", "no_handler",
                "ts", nowTick,
                "ext", extDot
            )
            this.NativeLastDiag := Map(
                "step", "resolve_clsid",
                "ext", extDot,
                "state", "no_handler",
                "cacheHit", false,
                "regSource", "",
                "regPath", "",
                "trace", regTrace
            )
            return false
        }

        g_SCWV_PreviewCapabilityCache[extDot] := Map(
            "state", "has_handler",
            "ts", nowTick,
            "ext", extDot,
            "clsid", clsid,
            "regPath", regPath,
            "regSource", regSource
        )

        try this.RootObj := Func("ComObjCreate").Call(clsid)
        catch as err {
            this.NativeLastDiag := Map(
                "step", "ComObjCreate",
                "ext", extDot,
                "clsid", clsid,
                "regPath", regPath,
                "regSource", regSource,
                "trace", regTrace,
                "error", _SCWV_ErrToText(err)
            )
            return false
        }
        try this.InitObj := Func("ComObjQuery").Call(this.RootObj, "{219a5d78-a9ef-443a-9271-1e392d5d1b1e}")
        catch as err {
            this.InitObj := 0
            this.NativeLastDiag := Map(
                "step", "ComObjQuery_IInitializeWithFile",
                "ext", extDot,
                "clsid", clsid,
                "regPath", regPath,
                "regSource", regSource,
                "trace", regTrace,
                "error", _SCWV_ErrToText(err)
            )
            return false
        }
        try ComCall(3, this.InitObj, "wstr", path, "uint", 0, "hresult")
        catch as err {
            this.NativeLastDiag := Map(
                "step", "IInitializeWithFile::Initialize",
                "ext", extDot,
                "clsid", clsid,
                "path", path,
                "regPath", regPath,
                "regSource", regSource,
                "trace", regTrace,
                "error", _SCWV_ErrToText(err)
            )
            return false
        }
        try this.PreviewHandler := Func("ComObjQuery").Call(this.RootObj, "{8895b1c6-b41f-4c1c-a562-0d564d35d9c5}")
        catch as err {
            this.NativeLastDiag := Map(
                "step", "ComObjQuery_IPreviewHandler",
                "ext", extDot,
                "clsid", clsid,
                "regPath", regPath,
                "regSource", regSource,
                "trace", regTrace,
                "error", _SCWV_ErrToText(err)
            )
            return false
        }
        rect := Buffer(16, 0)
        NumPut("int", 0, rect, 0)
        NumPut("int", 0, rect, 4)
        NumPut("int", w, rect, 8)
        NumPut("int", h, rect, 12)
        try ComCall(3, this.PreviewHandler, "ptr", hostHwnd, "ptr", rect.Ptr, "hresult")
        catch as err {
            this.NativeLastDiag := Map(
                "step", "IPreviewHandler::SetWindow",
                "ext", extDot,
                "clsid", clsid,
                "regPath", regPath,
                "regSource", regSource,
                "trace", regTrace,
                "error", _SCWV_ErrToText(err)
            )
            return false
        }
        try ComCall(7, this.PreviewHandler, "ptr", rect.Ptr, "hresult")
        catch {
        }
        try ComCall(8, this.PreviewHandler, "hresult")
        catch as err {
            this.NativeLastDiag := Map(
                "step", "IPreviewHandler::DoPreview",
                "ext", extDot,
                "clsid", clsid,
                "regPath", regPath,
                "regSource", regSource,
                "trace", regTrace,
                "error", _SCWV_ErrToText(err)
            )
            return false
        }
        this.NativeLastDiag := Map(
            "step", "success",
            "ext", extDot,
            "clsid", clsid,
            "regPath", regPath,
            "regSource", regSource,
            "trace", regTrace
        )
        return true
    }

    InvokeNative(path, seq, boundsMap) {
        this.Unload()
        this.ScheduleNative(path, seq, boundsMap)
    }
    PostDetailMeta(path, seq) {
        this._PostDetailMeta(path, seq)
    }

    _PostDetailMeta(path, seq) {
        path := Trim(String(path))
        if (path = "" || !(FileExist(path) || DirExist(path)))
            return
        try {
            szStr := ""
            if DirExist(path)
                szStr := "文件夹"
            else {
                sz := FileGetSize(path)
                szStr := _SCWV_FormatFileSizeBytes(sz)
            }

            modTime := FileGetTime(path, "M")
            creTime := FileGetTime(path, "C")
            fmtMod := FormatTime(modTime, "yyyy-MM-dd HH:mm")
            fmtCre := FormatTime(creTime, "yyyy-MM-dd HH:mm")

            SplitPath path, , , &ext

            SCWV_PostJson(Map(
                "type", "PREVIEW_META_UPDATE",
                "seq", seq,
                "path", path,
                "meta", Map(
                    "大小", szStr,
                    "修改时间", fmtMod,
                    "创建时间", fmtCre,
                    "扩展名", StrUpper(ext),
                    "路径", path
                )
            ))
        } catch {
        }
    }
}

_SCWV_HistoryFilePath() {
    return Nmer_SearchCenterHistoryPath()
}

_SCWV_HistoryResolvePaths() {
    paths := []
    canonical := _SCWV_HistoryFilePath()
    paths.Push(canonical)
    legacyApp := Nmer_DataRuntimeDir() . "\app\SearchCenterHistory.json"
    if (legacyApp != canonical)
        paths.Push(legacyApp)
    legacyRoot := Nmer_DataDir() . "\SearchCenterHistory.json"
    if (legacyRoot != canonical)
        paths.Push(legacyRoot)
    return paths
}

_SCWV_HistoryReadFileMtime(path := "") {
    if (path = "")
        path := _SCWV_HistoryFilePath()
    if !FileExist(path)
        return ""
    try
        return FileGetTime(path, "M")
    catch
        return ""
}

; 解析历史 JSON：支持 ["kw"]、{history:[...]}、{0:"kw"} 等旧格式
_SCWV_ParseHistoryContent(content) {
    s := Trim(String(content))
    if (s = "" || s = "[]" || s = "{}")
        return []
    parsed := ""
    try parsed := Jxon_Load(s)
    catch {
        return []
    }
    if (parsed is Array) {
        out := []
        for _, item in parsed {
            k := Trim(String(item))
            if (k != "")
                out.Push(k)
        }
        return out
    }
    if (parsed is Map) {
        for legacyKey in ["history", "queries", "items", "keywords"] {
            if parsed.Has(legacyKey) && (parsed[legacyKey] is Array)
                return _SCWV_ParseHistoryContent(Jxon_Dump(parsed[legacyKey]))
        }
        out := []
        for k, v in parsed {
            if (RegExMatch(String(k), "^\d+$")) {
                kv := Trim(String(v))
                if (kv != "")
                    out.Push(kv)
            }
        }
        return out
    }
    return []
}

_SCWV_HistoryDiskHasEntries() {
    for path in _SCWV_HistoryResolvePaths() {
        if !FileExist(path)
            continue
        try {
            content := FileRead(path, "UTF-8")
            if (_SCWV_ParseHistoryContent(content).Length > 0)
                return true
        } catch {
        }
    }
    return false
}

_SCWV_MigrateHistoryFileToCanonical(sourcePath, historyArr) {
    canonical := _SCWV_HistoryFilePath()
    if (sourcePath = canonical || historyArr.Length = 0)
        return
    if !DirExist(Nmer_DataSearchDir())
        try DirCreate(Nmer_DataSearchDir())
    try {
        f := FileOpen(canonical, "w", "UTF-8")
        if (f) {
            f.Write(Jxon_Dump(historyArr))
            f.Close()
            try SCWV_Log("history_migrate", "from=" . sourcePath . " to=" . canonical . " n=" . historyArr.Length)
        }
    } catch {
    }
}

; 冷启动或 Record 首次：同步读盘一次填入内存缓存
_SCWV_EnsureHistoryCacheLoaded() {
    global g_SC_HistoryCache
    if (Type(g_SC_HistoryCache) = "Array") {
        if (g_SC_HistoryCache.Length = 0 && _SCWV_HistoryDiskHasEntries())
            g_SC_HistoryCache := ""
        else
            return
    }
    _SCWV_ReloadHistoryFromDisk()
}

; 强制从磁盘重载（外部改文件或 mtime 变化）
_SCWV_ReloadHistoryFromDisk() {
    global g_SC_HistoryCache, g_SC_HistoryFileMtime
    historyArr := []
    usedPath := ""
    for path in _SCWV_HistoryResolvePaths() {
        if !FileExist(path)
            continue
        try {
            content := FileRead(path, "UTF-8")
            arr := _SCWV_ParseHistoryContent(content)
            if (arr.Length > 0) {
                historyArr := arr
                usedPath := path
                break
            }
        } catch as err {
            try SCWV_Log("history_read_fail", "path=" . path . " err=" . err.Message)
        }
    }
    if (usedPath != "" && usedPath != _SCWV_HistoryFilePath())
        _SCWV_MigrateHistoryFileToCanonical(usedPath, historyArr)
    g_SC_HistoryCache := historyArr
    g_SC_HistoryFileMtime := _SCWV_HistoryReadFileMtime()
    try SCWV_Log("history_reload", "path=" . (usedPath != "" ? usedPath : _SCWV_HistoryFilePath()) . " n=" . historyArr.Length)
}

_SCWV_HistoryDedupeToFront(keyword, historyArr) {
    k := Trim(String(keyword))
    newArr := [k]
    if (Type(historyArr) = "Array") {
        for _, item in historyArr {
            if (String(item) != k)
                newArr.Push(String(item))
        }
    }
    if (newArr.Length > 1000)
        newArr.Length := 1000
    return newArr
}

_SCWV_HandleEmptyKeywordSearchIntent(offset := 0, limit := 0, goType := "") {
    global SearchCenterFilterType
    gt := Trim(String(goType))
    if (gt = "")
        gt := _SCWV_MapFilterToGoSearchType(SearchCenterFilterType)
    if (gt != "clipboard" && SearchCenterFilterType != "clipboard")
        return false
    SearchCenterFilterType := "clipboard"
    _SCWV_RunClipboardTimelineSearch("", offset, limit)
    return true
}

_SCWV_OnClipboardDbReady() {
    global g_SCWV_LifecyclePhase, g_SCWV_UiMode, g_SCWV_Visible, SearchCenterFilterType
    if (Trim(String(g_SCWV_LifecyclePhase)) = "clip_db_recovery") {
        try SCWV_BroadcastHostLifecycle("open", "clip_db_ready")
        catch {
        }
    }
    if !g_SCWV_Visible
        return
    um := StrLower(Trim(String(g_SCWV_UiMode)))
    if (um = "clipboard" || SearchCenterFilterType = "clipboard") {
        SetTimer((*) => _SCWV_RunClipboardTimelineSearch("", 0, 0, true), -200)
    }
    if SCWV_FuncExists("SearchCore_EnsureStatus")
        SetTimer((*) => SearchCore_EnsureStatus(false, "clip_db_ready"), -1200)
}

_SCWV_EnsureClipboardDb() {
    global ClipboardFTS5DB, g_SCWV_ClipboardDbEnsureRetries
    if (IsSet(ClipboardFTS5DB) && ClipboardFTS5DB && ClipboardFTS5DB != 0)
        return true
    if !SCWV_FuncExists("InitClipboardFTS5DB")
        return false
    if (g_SCWV_ClipboardDbEnsureRetries >= 3)
        return false
    try {
        if !InitClipboardFTS5DB()
            return false
        g_SCWV_ClipboardDbEnsureRetries := 0
    } catch {
        g_SCWV_ClipboardDbEnsureRetries++
        if (g_SCWV_ClipboardDbEnsureRetries < 3)
            SetTimer((*) => _SCWV_EnsureClipboardDb(), -600)
        return false
    }
    return (IsSet(ClipboardFTS5DB) && ClipboardFTS5DB && ClipboardFTS5DB != 0)
}

_SCWV_RunClipboardTimelineSearch(keyword := "", offset := 0, limit := 0, force := false) {
    global g_SCWV_LastClipboardTimelineTick, g_SCWV_ClipboardTimelineScheduled, g_SCWV_ClipboardTimelineGen
    nowTick := A_TickCount
    if (!force && Trim(String(keyword)) = "" && (nowTick - Integer(g_SCWV_LastClipboardTimelineTick)) < 350)
        return
    g_SCWV_LastClipboardTimelineTick := nowTick
    if (g_SCWV_ClipboardTimelineScheduled && !force)
        return
    g_SCWV_ClipboardTimelineScheduled := true
    gen := ++g_SCWV_ClipboardTimelineGen
    SetTimer(_SCWV_RunClipboardTimelineSearchWorker.Bind(keyword, offset, limit, force, gen), -1)
}

_SCWV_RunClipboardTimelineSearchWorker(keyword, offset, limit, force, gen) {
    global g_SCWV_ClipboardTimelineScheduled, g_SCWV_UiMode, g_SCWV_ClipboardTimelineGen
    g_SCWV_ClipboardTimelineScheduled := false
    if (gen != g_SCWV_ClipboardTimelineGen)
        return
    if (StrLower(Trim(String(g_SCWV_UiMode))) != "clipboard" && Trim(String(keyword)) = "")
        return
    _SCWV_RunClipboardTimelineSearchCore(keyword, offset, limit, force, gen)
}

_SCWV_RunClipboardTimelineSearchCore(keyword := "", offset := 0, limit := 0, force := false, gen := 0) {
    global SearchCenterFilterType, SearchCenterEngineMode, SearchCenterWebKeyword, SearchCenterCurrentLimit
    global g_SCWV_ClipboardHomeLock, g_SCWV_PendingTriggerSource, g_SCWV_UiMode, g_SCWV_ClipboardTimelineGen
    if (gen && gen != g_SCWV_ClipboardTimelineGen)
        return
    SearchCenterFilterType := "clipboard"
    if (Trim(String(g_SCWV_PendingTriggerSource)) = "clipboard_hotkey")
        g_SCWV_ClipboardHomeLock := true
    else if (StrLower(Trim(String(g_SCWV_UiMode))) = "clipboard")
        g_SCWV_ClipboardHomeLock := false
    kw := Trim(String(keyword))
    off := Integer(offset)
    if (off < 0)
        off := 0
    lim := Integer(limit)
    if (lim <= 0)
        lim := SearchCenterCurrentLimit
    if (lim <= 0)
        lim := 30
    SearchCenterWebKeyword := kw
    if (Trim(String(g_SCWV_PendingTriggerSource)) = "clipboard_hotkey") {
        try SCWV_SetUnifiedMode("clipboard", true)
        catch {
        }
    }
    _SCWV_EnsureClipboardDb()
    if (kw = "") {
        _SCWV_ApplyClipboardTimelineLocal(kw, off, lim)
        return
    }
    if (SearchCenterEngineMode = "go") {
        if !_SCWV_EnsureSearchCoreRunning() {
            _SCWV_ApplyClipboardTimelineLocal(kw, off, lim)
            return
        }
        _SCWV_ExecuteGoSearchHttp(off, kw, "clipboard", lim)
        return
    }
    _SCWV_ApplyClipboardTimelineLocal(kw, off, lim)
}

_SCWV_LoadClipMainTimeline(keyword := "", offset := 0, limit := 30) {
    GoItems := []
    if !_SCWV_EnsureClipboardDb()
        return GoItems
    global ClipboardFTS5DB
    if !(IsSet(ClipboardFTS5DB) && ClipboardFTS5DB && ClipboardFTS5DB != 0)
        return GoItems
    off := Integer(offset)
    if (off < 0)
        off := 0
    lim := Integer(limit)
    if (lim <= 0)
        lim := 30
    kw := Trim(String(keyword))
    where := "1=1"
    params := []
    if (kw != "") {
        where .= " AND Content LIKE ?"
        params.Push("%" . kw . "%")
    }
    sql := "SELECT ID, Content, Timestamp, DataType, SourceApp, LastCopyTime FROM ClipMain WHERE " . where
        . " ORDER BY IsFavorite DESC, ID DESC LIMIT " . lim . " OFFSET " . off
    try {
        table := ""
        ok := false
        if (params.Length > 0) {
            if SCWV_FuncExists("SqlSafe_GetTable")
                ok := SqlSafe_GetTable(ClipboardFTS5DB, &table, sql, params*)
            else
                ok := false
        } else {
            ok := ClipboardFTS5DB.GetTable(sql, &table)
        }
        if ok && IsObject(table) && table.HasRows && table.Rows.Length > 0 {
            loop table.Rows.Length {
                r := table.Rows[A_Index]
                cp := Map(
                    "ID", Integer(r[1]),
                    "Content", String(r[2]),
                    "Timestamp", String(r[3]),
                    "DataType", String(r[4]),
                    "SourceApp", String(r[5]),
                    "LastCopyTime", String(r[6])
                )
                GoItems.Push(_SCWV_ConvertCpItemToGoItem(cp))
            }
        }
    } catch {
    }
    return GoItems
}

_SCWV_ConvertCpItemToGoItem(cpItem) {
    content := ""
    if (cpItem is Map) {
        if cpItem.Has("Content")
            content := String(cpItem["Content"])
    } else if (IsObject(cpItem) && cpItem.HasProp("Content")) {
        content := String(cpItem.Content)
    }
    content := Trim(content)
    ts := ""
    sa := ""
    idVal := 0
    dt := "Text"
    if (cpItem is Map) {
        if cpItem.Has("LastCopyTime") && Trim(String(cpItem["LastCopyTime"])) != ""
            ts := String(cpItem["LastCopyTime"])
        else if cpItem.Has("Timestamp")
            ts := String(cpItem["Timestamp"])
        if cpItem.Has("SourceApp")
            sa := String(cpItem["SourceApp"])
        if cpItem.Has("DataType")
            dt := String(cpItem["DataType"])
        if cpItem.Has("ID")
            idVal := Integer(cpItem["ID"])
    }
    preview := SubStr(StrReplace(content, "`r`n", " "), 1, 80)
    return Map(
        "Title", preview,
        "Content", content,
        "originalDataType", "clipboard",
        "OriginalDataType", "clipboard",
        "DataType", dt,
        "Source", sa != "" ? ("剪贴板 · " . sa) : "剪贴板",
        "Timestamp", ts,
        "TimeFormatted", ts,
        "ID", idVal
    )
}

_SCWV_ApplyClipboardTimelineLocal(keyword := "", offset := 0, limit := 0) {
    global SearchCenterSearchResults, SearchCenterHasMoreData, SearchCenterCurrentLimit, g_SCWV_SkipHostSort, g_SCWV_UiMode
    kw := Trim(String(keyword))
    if (StrLower(Trim(String(g_SCWV_UiMode))) != "clipboard" && kw = "")
        return
    _SCWV_EnsureClipboardDb()
    lim := Integer(limit)
    if (lim <= 0)
        lim := SearchCenterCurrentLimit
    if (lim <= 0)
        lim := 30
    off := Integer(offset)
    if (off < 0)
        off := 0
    GoItems := _SCWV_LoadClipMainTimeline(kw, off, lim)
    if (GoItems.Length = 0 && SCWV_FuncExists("_CP_LoadItems")) {
        for _, cp in _CP_LoadItems(kw, "all", off, lim)
            GoItems.Push(_SCWV_ConvertCpItemToGoItem(cp))
    }
    if (GoItems.Length = 0) {
        for _, r in _SCWV_QueryRecentClipboard(0, lim)
            GoItems.Push(_SCWV_ConvertCpItemToGoItem(Map(
                "Content", r["content"],
                "Timestamp", r["timestamp"],
                "DataType", r["dataType"]
            )))
    }
    if (GoItems.Length = 0) {
        if (off = 0) {
            SearchCenterSearchResults := []
            SearchCenterHasMoreData := false
            SCWV_PushState("state")
            _SCWV_SetLoadingTier("")
            global g_SCWV_ClipboardTimelineRetries, g_SCWV_UiMode
            if (kw = "" && StrLower(Trim(String(g_SCWV_UiMode))) = "clipboard") {
                g_SCWV_ClipboardTimelineRetries++
                if (g_SCWV_ClipboardTimelineRetries <= 2)
                    SetTimer((*) => _SCWV_RunClipboardTimelineSearch("", 0, lim, true), -800)
            }
        }
        return false
    }
    global g_SCWV_ClipboardTimelineRetries
    g_SCWV_ClipboardTimelineRetries := 0
    if (off = 0)
        SearchCenterSearchResults := []
    SearchCenterHasMoreData := GoItems.Length >= lim
    AllDataResults := _SCWV_GroupGoItemsToAllDataResults(GoItems, SearchCenterHasMoreData)
    g_SCWV_SkipHostSort := true
    _SCWV_MergeAllDataResultsIntoSearchLists(AllDataResults, kw, off)
    try _SCWV_PushClipFloatToWeb()
    catch {
    }
    SCWV_PushState("state")
    _SCWV_SetLoadingTier("")
    return true
}

_SCWV_QueryRecentClipboard(maxAgeSec := 180, limit := 3) {
    global ClipboardDB, ClipboardFTS5DB, g_SCWV_ClipboardHotMaxAgeSec
    rows := []
    maxAge := Integer(maxAgeSec)
    if (maxAge = 0)
        whereTs := "1=1"
    else {
        if (maxAge < 0)
            maxAge := Integer(g_SCWV_ClipboardHotMaxAgeSec)
        whereTs := "Timestamp >= datetime('now','localtime','-" . maxAge . " seconds')"
    }
    lim := Integer(limit)
    if (lim <= 0)
        lim := 3

    ; 主路径：ClipMain（Clipboard.db / FTS5 实际入库表）
    _SCWV_EnsureClipboardDb()
    if (IsSet(ClipboardFTS5DB) && ClipboardFTS5DB && ClipboardFTS5DB != 0) {
        sqlFts := "SELECT Content, Timestamp, DataType FROM ClipMain WHERE " . whereTs . " ORDER BY ID DESC LIMIT " . lim
        try {
            table := ""
            if ClipboardFTS5DB.GetTable(sqlFts, &table) {
                if (table.HasRows && table.Rows.Length > 0) {
                    loop table.Rows.Length {
                        r := table.Rows[A_Index]
                        content := Trim(String(r[1]))
                        if (content = "")
                            continue
                        rows.Push(Map(
                            "content", content,
                            "timestamp", String(r[2]),
                            "dataType", String(r[3]),
                            "preview", SubStr(content, 1, 120)
                        ))
                    }
                }
            }
        } catch {
        }
    }
    if (rows.Length > 0)
        return rows

    ; 回退：CursorData.db 旧表（若仍在使用）
    if !(IsSet(ClipboardDB) && ClipboardDB && ClipboardDB != 0)
        return rows
    sqlLegacy := "SELECT Content, Timestamp, DataType FROM ClipboardHistory WHERE " . whereTs . " ORDER BY ID DESC LIMIT " . lim
    try {
        table := ""
        if !ClipboardDB.GetTable(sqlLegacy, &table)
            return rows
        if !(table.HasRows && table.Rows.Length > 0)
            return rows
        loop table.Rows.Length {
            r := table.Rows[A_Index]
            content := Trim(String(r[1]))
            if (content = "")
                continue
            rows.Push(Map(
                "content", content,
                "timestamp", String(r[2]),
                "dataType", String(r[3]),
                "preview", SubStr(content, 1, 120)
            ))
        }
    } catch {
    }
    return rows
}

_SCWV_PushClipFloatToWeb() {
    rows := _SCWV_QueryRecentClipboard(g_SCWV_ClipboardHotMaxAgeSec, 3)
    items := []
    for _, r in rows {
        items.Push(Map(
            "content", r["content"],
            "preview", r["preview"],
            "timestamp", r["timestamp"],
            "dataType", r["dataType"]
        ))
    }
    try SCWV_PostJson(Map("type", "clipFloat", "items", items, "maxAgeMs", g_SCWV_ClipboardHotMaxAgeSec * 1000))
    catch {
    }
}

_SCWV_BuildClipboardTopResultItem(content) {
    preview := Trim(String(content))
    title := "📋 刚刚复制: " . SubStr(StrReplace(preview, "`r`n", " "), 1, 80)
    return {
        Title: title,
        Subtitle: "剪贴板 · 刚刚复制",
        Content: preview,
        DataType: "剪贴板",
        Source: "剪贴板",
        Time: "刚刚",
        Path: preview,
        OriginalDataType: "clipboard_top"
    }
}

; 教程卡 + 历史项推送到 UI（从 Load 抽出，避免重复拼装）
; 顺序：历史 → 最近复制 → 仅两者皆空时展示新手指南
_SCWV_HistoryPushResultsToUI(historyArr, hotRows := unset) {
    global SearchCenterCurrentLimit, SearchCenterSearchResults, SearchCenterHasMoreData
    SearchCenterSearchResults := []
    if !IsSet(hotRows) {
        try _SCWV_EnsureClipboardDb()
        catch {
        }
        hotRows := _SCWV_QueryRecentClipboard(g_SCWV_ClipboardHotMaxAgeSec, 1)
    }
    hasHistory := (Type(historyArr) = "Array" && historyArr.Length > 0)
    hasClip := (hotRows is Array && hotRows.Length > 0)

    if hasHistory {
        limit := (SearchCenterCurrentLimit && SearchCenterCurrentLimit > 0) ? SearchCenterCurrentLimit : 30
        histCount := 0
        for _, item in historyArr {
            SearchCenterSearchResults.Push({
                Title: String(item),
                Source: "用户搜索记录",
                DataType: "history",
                Time: "",
                Path: String(item),
                OriginalDataType: "history"
            })
            histCount += 1
            if (histCount >= (limit + 5))
                break
        }
    }
    if hasClip
        SearchCenterSearchResults.Push(_SCWV_BuildClipboardTopResultItem(hotRows[1]["content"]))

    if (!hasHistory && !hasClip) {
        tutorialContent := "快速上手（30秒）`n"
                         . "1. 输入关键词：支持文件名、路径片段、剪贴板内容、模板名。`n"
                         . "2. 用方向键选择结果，按 Enter 执行。`n"
                         . "3. 通过分类和筛选缩小范围（文本、剪贴板、模板、配置等）。`n`n"
                         . "常见场景`n"
                         . "- 找文件：输入文件名关键词，可配合文件筛选。`n"
                         . "- 找复制过的内容：输入片段后切到剪贴板筛选。`n"
                         . "- 找提示词或配置：输入关键词后切到对应筛选。`n`n"
                         . "高效操作`n"
                         . "- 双击或 Enter：执行当前结果。`n"
                         . "- 右键结果：复制、发送到、置顶、删除。`n"
                         . "- 空格：重新加载当前文件预览（PDF 默认走侧栏 PDF.js）。`n`n"
                         . "建议`n"
                         . "- 首次使用先从文件和剪贴板两个筛选开始。`n"
                         . "- 关键词尽量短而准，必要时加第二个词缩小范围。"
        SearchCenterSearchResults.Push({
            Title: "搜索中心新手指南（从入门到高效）",
            Subtitle: tutorialContent,
            Content: tutorialContent,
            DataType: "tutorial",
            Source: "新手引导",
            Time: "快速开始"
        })
    }
    SearchCenterHasMoreData := false
    msgType := (Trim(SearchCenterWebKeyword) = "") ? "init" : "state"
    histN := (Type(historyArr) = "Array") ? historyArr.Length : 0
    try SCWV_Log("history_home_push", "hist=" . histN . " clip=" . (hasClip ? 1 : 0) . " tutorial=" . ((!hasHistory && !hasClip) ? 1 : 0))
    SCWV_PushState(msgType)
}

; 防抖写盘：停笔 1.5s 后单次全量序列化（主线程空闲时执行）
_SCWV_FlushSearchHistory(*) {
    global g_SC_HistoryCache, g_SC_HistoryFileMtime, g_SC_HistoryDirty
    if !g_SC_HistoryDirty
        return
    if (Type(g_SC_HistoryCache) != "Array")
        return
    if !DirExist(Nmer_DataDir())
        DirCreate(Nmer_DataDir())
    try {
        f := FileOpen(_SCWV_HistoryFilePath(), "w", "UTF-8")
        if (f) {
            f.Write(Jxon_Dump(g_SC_HistoryCache))
            f.Close()
            g_SC_HistoryFileMtime := _SCWV_HistoryReadFileMtime()
            g_SC_HistoryDirty := false
        }
    } catch {
    }
}

; 微创：Record 热路径只更新内存，不写盘
_SCWV_RecordSearchHistory(keyword) {
    global g_SC_HistoryCache, g_SC_HistoryDirty
    k := Trim(String(keyword))
    if (k == "")
        return
    _SCWV_EnsureHistoryCacheLoaded()
    g_SC_HistoryCache := _SCWV_HistoryDedupeToFront(k, g_SC_HistoryCache)
    g_SC_HistoryDirty := true
    SetTimer(_SCWV_FlushSearchHistory, 0)
    SetTimer(_SCWV_FlushSearchHistory, -1500)
}

; 微创：Load 优先内存缓存，mtime 未变则 0 读盘
_SCWV_LoadSearchHistory(retryCount := 0) {
    global g_SC_HistoryCache, g_SC_HistoryFileMtime, g_SC_HistoryDirty, g_SCWV_ClipboardHomeLock
    global g_SCWV_Ready, g_SCWV_Visible, g_SCWV_WaitingUiFinishedReveal
    if g_SCWV_ClipboardHomeLock
        return
    if !g_SCWV_Ready {
        if SCWV_HostAlive() && !SCWV_IsCloseRequested()
            SetTimer((*) => _SCWV_LoadSearchHistory(0), -120)
        return
    }
    _SCWV_EnsureHistoryCacheLoaded()
    needDiskRead := true
    diskHasEntries := _SCWV_HistoryDiskHasEntries()
    if (Type(g_SC_HistoryCache) = "Array") {
        if (g_SC_HistoryCache.Length = 0 && diskHasEntries)
            needDiskRead := true
        else if g_SC_HistoryDirty
            needDiskRead := false
        else if (_SCWV_HistoryReadFileMtime() = g_SC_HistoryFileMtime)
            needDiskRead := false
    }
    if needDiskRead {
        if (Type(g_SC_HistoryCache) = "Array" && g_SC_HistoryCache.Length = 0 && diskHasEntries)
            g_SC_HistoryCache := ""
        _SCWV_ReloadHistoryFromDisk()
    }
    try _SCWV_EnsureClipboardDb()
    catch {
    }
    hotRows := _SCWV_QueryRecentClipboard(g_SCWV_ClipboardHotMaxAgeSec, 1)
    hasHistory := (Type(g_SC_HistoryCache) = "Array" && g_SC_HistoryCache.Length > 0)
    hasClip := (hotRows is Array && hotRows.Length > 0)
    maxRetry := diskHasEntries ? 5 : 2
    if (!hasHistory && !hasClip && Integer(retryCount) < maxRetry && !SCWV_IsCloseRequested()) {
        try SCWV_Log("history_home_retry", "retry=" . Integer(retryCount) . " disk=" . (diskHasEntries ? 1 : 0))
        SetTimer((*) => _SCWV_LoadSearchHistory(Integer(retryCount) + 1), -Max(200, 120 * (Integer(retryCount) + 1)))
        return
    }
    _SCWV_HistoryPushResultsToUI(g_SC_HistoryCache, hotRows)
    _SCWV_SetLoadingTier("")
    try _SCWV_PushClipFloatToWeb()
    catch {
    }
}

SCWV_BroadcastHostLifecycle(phase := "", reason := "") {
    global g_SCWV_LifecyclePhase
    p := Trim(String(phase))
    if (p != "")
        g_SCWV_LifecyclePhase := p
    r := Trim(String(reason))
    try {
        if SCWV_FuncExists("SCWV_Log")
            SCWV_Log("host_lifecycle_broadcast", "phase=" . g_SCWV_LifecyclePhase . " reason=" . r)
    } catch {
    }
    try SCWV_PostJson(Map("type", "hostLifecycle", "phase", g_SCWV_LifecyclePhase, "reason", r))
    catch {
    }
    try SCWV_PushLifecycleState(g_SCWV_LifecyclePhase, r != "" ? r : "broadcast")
    catch {
    }
}

#Include SearchCenterProviders.ahk
