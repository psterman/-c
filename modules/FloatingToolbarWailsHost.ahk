; FloatingToolbarWailsHost.ahk — S10：Wails 合壳承载 FTB；S11：Hybrid（AHK 呈现 + Hub inject）
; 阶段 1：侧车窗口激活 + ftb_host_show
; 阶段 2：HTTP /shell/ftb 懒加载 FloatingToolbarStrip.html，退役 AHK FTB WebView

global g_FTBWails_LastShowTick := 0
global g_FTBWails_LastActivateTick := 0
global g_FTBWails_ShellMounted := false
global g_FTBWails_ShellVisible := false
global g_FTBWails_ShowInProgress := false
global g_FTBWails_LastBridgePid := 0
global g_FTBWails_EgressPumpOn := false
global g_FTBWails_LastAgentEnsureTick := 0
global g_FTBWails_AgentEnsureBusy := false
global g_FTBWails_HybridRegistered := false
global g_FTBWails_HybridReady := false
global g_FTBWails_InjectPumpOn := false
global g_FTBWails_HybridInjectFailStreak := 0

FloatingToolbarWails_Log(message) {
    try {
        if FuncExists("FloatingToolbarRouter_Log")
            FloatingToolbarRouter_Log(String(message))
        else if FuncExists("Nmer_WailsBridgeLog")
            Nmer_WailsBridgeLog("ftb_wails " . String(message))
    } catch {
    }
}

; S10 阶段 4：shell 模式下禁止创建/复用 AHK FTB WebView2（rollback 时 legacySurfaceLifecycle:true 仍走 ahk）
FloatingToolbar_AhkWebViewEnabled(*) {
    if FuncExists("FloatingToolbarWails_ShouldUseShell") && FloatingToolbarWails_ShouldUseShell()
        return false
    return true
}

FloatingToolbarWails_ShouldUseShell(*) {
    if FuncExists("FloatingToolbarRouter_ShouldUseHybrid") && FloatingToolbarRouter_ShouldUseHybrid()
        return false
    if !(FuncExists("FloatingToolbarRouter_ShouldUseWails") && FloatingToolbarRouter_ShouldUseWails())
        return false
    try {
        if FuncExists("Nmer_LegacySurfaceLifecycleEnabled") && Nmer_LegacySurfaceLifecycleEnabled()
            return false
    } catch {
        return false
    }
    return true
}

FloatingToolbarWails_ShouldUseHybrid(*) {
    return FuncExists("FloatingToolbarRouter_ShouldUseHybrid") && FloatingToolbarRouter_ShouldUseHybrid()
}

FloatingToolbarWails_FindWindow(*) {
    if FuncExists("DomainCWails_FindWindow")
        return DomainCWails_FindWindow()
    try {
        hwnd := WinExist("ahk_exe nmer-wails.exe")
        if hwnd
            return hwnd
    } catch {
    }
    try {
        return WinExist("NMER Wails POC")
    } catch {
        return 0
    }
}

FloatingToolbarWails_EnsureBridge(*) {
    if FuncExists("DomainCWails_EnsureBridge")
        return DomainCWails_EnsureBridge()
    if FuncExists("Nmer_EnsureWailsBridgeForPalette")
        return Nmer_EnsureWailsBridgeForPalette()
    if FuncExists("Nmer_StartWailsBridge") && Nmer_StartWailsBridge(false)
        return Map("ok", true, "code", "BRIDGE_STARTED")
    return Map("ok", false, "code", "BRIDGE_UNAVAILABLE")
}

FloatingToolbarWails_SyncBridgePid(*) {
    global g_FTBWails_LastBridgePid, g_FTBWails_ShellMounted, g_FTBWails_ShellVisible
    pid := 0
    try pid := ProcessExist("nmer-wails.exe")
    catch {
    }
    if pid && g_FTBWails_LastBridgePid && pid != g_FTBWails_LastBridgePid {
        g_FTBWails_ShellMounted := false
        g_FTBWails_ShellVisible := false
    }
    if pid
        g_FTBWails_LastBridgePid := pid
    else {
        g_FTBWails_LastBridgePid := 0
        g_FTBWails_ShellMounted := false
        g_FTBWails_ShellVisible := false
    }
}

FloatingToolbarWails_ActivateWindow(force := false, soft := false) {
    global g_FTBWails_LastActivateTick
    hwnd := FloatingToolbarWails_FindWindow()
    if !hwnd
        return false
    now := A_TickCount
    expr := "ahk_id " . hwnd
    if soft {
        try WinShow(expr)
        catch {
        }
        return true
    }
    if !force && (now - g_FTBWails_LastActivateTick) < 1200 {
        try {
            if WinActive(expr)
                return true
        } catch {
        }
    }
    try {
        pid := DllCall("GetCurrentProcessId", "UInt")
        DllCall("AllowSetForegroundWindow", "UInt", pid)
    } catch {
    }
    try DllCall("LockSetForegroundWindow", "UInt", 2)
    catch {
    }
    try WinRestore(expr)
    catch {
    }
    ok := false
    if FuncExists("SCWV_ForegroundPulse") {
        try ok := !!SCWV_ForegroundPulse(hwnd)
        catch {
        }
    }
    if !ok && FuncExists("DomainCWails_ActivateWindow")
        ok := !!DomainCWails_ActivateWindow()
    if !ok {
        try WinShow(expr)
        catch {
        }
        try WinActivate(expr)
        catch {
        }
        try ok := WinActive(expr)
        catch {
        }
    }
    if ok
        g_FTBWails_LastActivateTick := now
    return ok
}

FloatingToolbarWails_ScheduleActivateRetries(*) {
  SetTimer((*) => FloatingToolbarWails_ActivateWindow(true), -220)
  SetTimer((*) => FloatingToolbarWails_ActivateWindow(true), -600)
}

FloatingToolbarWails_RetireAhkWebView(reason := "shell_phase4") {
    if FuncExists("FloatingToolbar_AhkWebViewEnabled") && FloatingToolbar_AhkWebViewEnabled()
        return false
    if !FuncExists("FloatingToolbar_DisposeAhkWebViewIfRetired")
        return false
    ok := false
    try ok := !!FloatingToolbar_DisposeAhkWebViewIfRetired(reason)
    catch {
    }
    if ok
        FloatingToolbarWails_Log("ahk_wv2_retired reason=" . String(reason))
    return ok
}

FloatingToolbarWails_RecordHostShow(bridge, entry, shellPhase := 1) {
    try SurfaceManager_RegisterSurface("floating_toolbar")
    try SurfaceManager_RecordEvent("ftb_host_show", "floating_toolbar", Map(
        "host", "wails",
        "bridge", String(bridge is Map ? bridge.Get("code", "") : ""),
        "shellPhase", Integer(shellPhase)
    ))
    try SurfaceManager_ObserveShow("floating_toolbar", Map(
        "entry", String(entry),
        "host", "wails",
        "bridge", String(bridge is Map ? bridge.Get("code", "") : ""),
        "shellLazy", shellPhase >= 2 ? 2 : 1,
        "shellPhase", Integer(shellPhase)
    ))
}

FloatingToolbarWails_HideWindow(entry) {
    global g_FTBWails_ShellVisible
    if FloatingToolbarWails_ShouldUseShell() && FuncExists("Nmer_WailsBridgePostShellFtb") {
        try Nmer_WailsBridgePostShellFtb("hide", String(entry))
        catch {
        }
        g_FTBWails_ShellVisible := false
        try SurfaceManager_ObserveHide("floating_toolbar", Map("entry", String(entry), "host", "wails", "shellOnly", 1))
        return
    }
    hwnd := FloatingToolbarWails_FindWindow()
    if hwnd {
        try WinMinimize("ahk_id " . hwnd)
        catch {
            try WinHide("ahk_id " . hwnd)
            catch {
            }
        }
    }
    try SurfaceManager_ObserveHide("floating_toolbar", Map("entry", String(entry), "host", "wails"))
}

FloatingToolbarWails_MountShell(entry) {
    if !FuncExists("Nmer_WailsBridgePostShellFtb")
        return Map("ok", false, "code", "SHELL_API_MISSING")
    return Nmer_WailsBridgePostShellFtb("show", String(entry))
}

FloatingToolbarWails_QueryShellReady(*) {
    if !FloatingToolbarWails_ShouldUseShell()
        return false
    if !FuncExists("Nmer_WailsBridgeGetShellFtbStatus")
        return false
    try {
        st := Nmer_WailsBridgeGetShellFtbStatus()
        return (st is Map) && st.Get("ok", false) && st.Get("ready", false) && st.Get("mounted", false)
    } catch {
        return false
    }
}

; 禁止 Sleep 轮询：GUI 线程阻塞 + WinHttp 重入会触发 Invalid memory read/write
FloatingToolbarWails_WaitShellReady(*) {
    return FloatingToolbarWails_QueryShellReady()
}

; Agent/CP 派发：仅 mount shell + egress，不抢焦点（避免 POC 窗反复 WinRestore/置前）
FloatingToolbarWails_EnsureShellForAgent(activate := false) {
    global g_FTBWails_ShellMounted, g_FTBWails_ShellVisible, g_FTBWails_LastAgentEnsureTick, g_FTBWails_AgentEnsureBusy
    if !FloatingToolbarWails_ShouldUseShell()
        return false
    if g_FTBWails_AgentEnsureBusy
        return FuncExists("Nmer_WailsBridgeHealthy") && Nmer_WailsBridgeHealthy()
    g_FTBWails_AgentEnsureBusy := true
    try {
        return FloatingToolbarWails_EnsureShellForAgentCore(activate)
    } finally {
        g_FTBWails_AgentEnsureBusy := false
    }
}

FloatingToolbarWails_EnsureShellForAgentCore(activate := false) {
    global g_FTBWails_ShellMounted, g_FTBWails_ShellVisible, g_FTBWails_LastAgentEnsureTick
    FloatingToolbarWails_SyncBridgePid()
    now := A_TickCount
    if g_FTBWails_ShellMounted && g_FTBWails_ShellVisible && FuncExists("Nmer_WailsBridgeHealthy") && Nmer_WailsBridgeHealthy() {
        if !activate
            return true
        if (now - g_FTBWails_LastAgentEnsureTick) < 3000
            return true
    }
    bridge := FloatingToolbarWails_EnsureBridge()
    if !(bridge is Map) || !bridge.Get("ok", false)
        return false
    if !g_FTBWails_ShellMounted || !g_FTBWails_ShellVisible {
        shell := FloatingToolbarWails_MountShell("agent_ensure")
        if !(shell is Map) || !shell.Get("ok", false) {
            FloatingToolbarWails_Log("agent_ensure_mount_fail code=" . (shell is Map ? shell.Get("code", "?") : "?"))
            return false
        }
        g_FTBWails_ShellMounted := true
        g_FTBWails_ShellVisible := true
        FloatingToolbarWails_EnsureEgressPump()
        FloatingToolbarWails_RetireAhkWebView("agent_ensure")
        FloatingToolbarWails_Log("agent_ensure_mount_ok code=" . shell.Get("code", ""))
    }
    if activate
        FloatingToolbarWails_ActivateWindow(false, true)
    g_FTBWails_LastAgentEnsureTick := now
    return FuncExists("Nmer_WailsBridgeHealthy") && Nmer_WailsBridgeHealthy()
}

FloatingToolbarWails_Show(meta := 0) {
    global g_FTBWails_LastShowTick, g_FTBWails_ShellMounted, g_FTBWails_ShellVisible, g_FTBWails_ShowInProgress
    if g_FTBWails_ShowInProgress
        return true
    g_FTBWails_ShowInProgress := true
    try {
        entry := "FloatingToolbarWails_Show"
        if (meta is Map) && meta.Has("reason")
            entry := String(meta["reason"])
        shellPhase := FloatingToolbarWails_ShouldUseShell() ? 4 : 1
        FloatingToolbarWails_SyncBridgePid()
        now := A_TickCount
        if (shellPhase >= 2) && g_FTBWails_ShellMounted && g_FTBWails_ShellVisible && (now - g_FTBWails_LastShowTick) < 1500 {
            FloatingToolbarWails_EnsureBridge()
            FloatingToolbarWails_EnsureEgressPump()
            FloatingToolbarWails_Log("show_debounce_skip entry=" . entry)
            g_FTBWails_LastShowTick := now
            return true
        }
        bridge := FloatingToolbarWails_EnsureBridge()
        if !(bridge is Map) || !bridge.Get("ok", false) {
            FloatingToolbarWails_Log("fallback bridge=" . (bridge is Map ? bridge.Get("code", "?") : "?"))
            if (shellPhase = 1) && FuncExists("ShowFloatingToolbar")
                return !!ShowFloatingToolbar()
            return false
        }
        if FuncExists("FloatingToolbarRouter_AhkGuiExists") && FloatingToolbarRouter_AhkGuiExists() {
            try HideFloatingToolbar()
            catch {
            }
        }
        if (shellPhase >= 2) {
            if g_FTBWails_ShellMounted && g_FTBWails_ShellVisible {
                FloatingToolbarWails_Log("shell_show_skip already_visible")
            } else {
                shellMounted := g_FTBWails_ShellMounted
                shell := FloatingToolbarWails_MountShell(entry)
                if !(shell is Map) || !shell.Get("ok", false) {
                    FloatingToolbarWails_Log("shell_mount_fail code=" . (shell is Map ? shell.Get("code", "?") : "?"))
                    return false
                }
                g_FTBWails_ShellMounted := true
                g_FTBWails_ShellVisible := true
                FloatingToolbarWails_Log(shellMounted ? "shell_show_ok code=" . shell.Get("code", "") : "shell_mount_ok code=" . shell.Get("code", ""))
            }
            FloatingToolbarWails_EnsureEgressPump()
            FloatingToolbarWails_RetireAhkWebView("shell_show")
            softShow := (meta is Map) && meta.Get("soft", false)
            if !softShow {
                if !FloatingToolbarWails_ActivateWindow() {
                    Sleep(400)
                    FloatingToolbarWails_ActivateWindow(true)
                }
                FloatingToolbarWails_ScheduleActivateRetries()
            }
        } else {
            if !FloatingToolbarWails_ActivateWindow() {
                Sleep(400)
                if !FloatingToolbarWails_ActivateWindow(true) {
                    FloatingToolbarWails_Log("fallback no_wails_hwnd shellPhase=" . shellPhase)
                    if FuncExists("ShowFloatingToolbar")
                        return !!ShowFloatingToolbar()
                    return false
                }
            }
            FloatingToolbarWails_ScheduleActivateRetries()
        }
        g_FTBWails_LastShowTick := A_TickCount
        FloatingToolbarWails_RecordHostShow(bridge, entry, shellPhase)
        FloatingToolbarWails_Log("show_ok bridge=" . bridge.Get("code", "") . " shellPhase=" . shellPhase)
        return true
    } finally {
        g_FTBWails_ShowInProgress := false
    }
}

FloatingToolbarWails_Hide(meta := 0) {
    FloatingToolbarWails_HideWindow("FloatingToolbarWails_Hide")
    if FuncExists("FloatingToolbarRouter_AhkGuiExists") && FloatingToolbarRouter_AhkGuiExists() {
        try HideFloatingToolbar()
        catch {
        }
    }
    return true
}

FloatingToolbarWails_Dispose(reason := "") {
    global g_FTBWails_ShellMounted, g_FTBWails_ShellVisible
    FloatingToolbarWails_StopEgressPump()
    if FloatingToolbarWails_ShouldUseShell() && FuncExists("Nmer_WailsBridgePostShellFtb") {
        try Nmer_WailsBridgePostShellFtb("dispose", "FloatingToolbarWails_Dispose", Map("reason", String(reason)))
        catch {
        }
        g_FTBWails_ShellMounted := false
        g_FTBWails_ShellVisible := false
    } else {
        FloatingToolbarWails_HideWindow("FloatingToolbarWails_Dispose")
    }
    if FuncExists("FloatingToolbarRouter_AhkGuiExists") && FloatingToolbarRouter_AhkGuiExists() {
        if FuncExists("FloatingToolbar_Dispose")
            FloatingToolbar_Dispose(reason)
    }
}

FloatingToolbarWails_DeliverPayload(payload) {
    if !FloatingToolbarWails_ShouldUseShell()
        return false
    if !(payload is Map)
        return false
    if !FuncExists("Nmer_WailsBridgePostShellFtbInject")
        return false
    if !Nmer_WailsBridgeHealthy() {
        FloatingToolbarWails_EnsureBridge()
        if !Nmer_WailsBridgeHealthy()
            return false
    }
    if !FloatingToolbarWails_EnsureShellForAgent(false)
        return false
    FloatingToolbarWails_EnsureEgressPump()
    try {
        res := Nmer_WailsBridgePostShellFtbInject(payload)
        ok := (res is Map) && res.Get("ok", false)
        if !ok
            FloatingToolbarWails_Log("deliver_inject_fail type=" . String(payload.Get("type", "")) . " code=" . (res is Map ? res.Get("code", "?") : "?"))
        return ok
    } catch as errDeliver {
        FloatingToolbarWails_Log("deliver_inject_err type=" . String(payload.Get("type", "")) . " err=" . errDeliver.Message)
        return false
    }
}

FloatingToolbarWails_HandleEgressPayload(msg) {
    if !(msg is Map)
        return
    typ := String(msg.Get("type", ""))
    switch typ {
        case "niuma_palette_ai_keys":
            if FuncExists("CommandPalette_OnNiumaPaletteAiKeys")
                try CommandPalette_OnNiumaPaletteAiKeys(msg)
                catch {
                }
        case "niuma_palette_ai_llm":
            if FuncExists("CommandPalette_OnNiumaPaletteAiLlm")
                try CommandPalette_OnNiumaPaletteAiLlm(msg)
                catch {
                }
        case "niuma_palette_ai_trace":
            if FuncExists("CommandPalette_AiLog") {
                step := msg.Has("step") ? String(msg["step"]) : ""
                det := msg.Has("detail") ? String(msg["detail"]) : ""
                try CommandPalette_AiLog("shell_" . step, det)
                catch {
                }
            }
        case "niuma_palette_ai_chunk":
            if FuncExists("CommandPalette_OnNiumaPaletteAiChunk")
                try CommandPalette_OnNiumaPaletteAiChunk(msg)
                catch {
                }
        case "niuma_palette_ai_end":
            if FuncExists("CommandPalette_OnNiumaPaletteAiEnd")
                try CommandPalette_OnNiumaPaletteAiEnd(msg)
                catch {
                }
        case "niuma_palette_ai_error":
            if FuncExists("CommandPalette_OnNiumaPaletteAiError")
                try CommandPalette_OnNiumaPaletteAiError(msg)
                catch {
                }
        case "niuma_palette_agent_trace":
            if FuncExists("CommandPalette_AgentDebug_TraceIfAgentReq") {
                reqId0 := msg.Has("reqId") ? String(msg["reqId"]) : ""
                step0 := msg.Has("step") ? String(msg["step"]) : ""
                det0 := msg.Has("detail") ? String(msg["detail"]) : ""
                try CommandPalette_AgentDebug_TraceIfAgentReq(reqId0, "shell_ftb", "agent_trace", step0 . " " . det0)
                catch {
                }
            }
        case "niuma_palette_agent_chunk":
            if FuncExists("CommandPalette_OnNiumaPaletteAgentChunk")
                try CommandPalette_OnNiumaPaletteAgentChunk(msg)
                catch {
                }
        case "niuma_palette_agent_end":
            if FuncExists("CommandPalette_OnNiumaPaletteAgentEnd")
                try CommandPalette_OnNiumaPaletteAgentEnd(msg)
                catch {
                }
        case "niuma_palette_agent_error":
            if FuncExists("CommandPalette_OnNiumaPaletteAgentError")
                try CommandPalette_OnNiumaPaletteAgentError(msg)
                catch {
                }
        case "UI_PAINT_READY", "toolbar_ready":
            global g_FTBWails_ShellMounted
            g_FTBWails_ShellMounted := true
        default:
            if FuncExists("FloatingToolbar_ForwardShellEgressMessage")
                try FloatingToolbar_ForwardShellEgressMessage(msg)
                catch {
                }
    }
}

FloatingToolbarWails_EgressPumpTick(*) {
    global g_FTBWails_EgressPumpOn
    if !g_FTBWails_EgressPumpOn || !FloatingToolbarWails_ShouldUseShell()
        return
    if !FuncExists("Nmer_WailsBridgeDrainShellFtbEgress")
        return
    msgs := []
    try msgs := Nmer_WailsBridgeDrainShellFtbEgress()
    catch {
        return
    }
    for _, msg in msgs
        FloatingToolbarWails_HandleEgressPayload(msg)
}

FloatingToolbarWails_EnsureEgressPump(*) {
    global g_FTBWails_EgressPumpOn
    if !FloatingToolbarWails_ShouldUseShell()
        return
    if g_FTBWails_EgressPumpOn
        return
    g_FTBWails_EgressPumpOn := true
    SetTimer(FloatingToolbarWails_EgressPumpTick, 150)
}

FloatingToolbarWails_StopEgressPump(*) {
    global g_FTBWails_EgressPumpOn
    g_FTBWails_EgressPumpOn := false
    SetTimer(FloatingToolbarWails_EgressPumpTick, 0)
}

; --- S11 Hybrid：AHK 悬浮窗呈现 + Go Hub inject 队列 ---

FloatingToolbarWails_RecordHybridHostShow(bridge, entry) {
    try SurfaceManager_RegisterSurface("floating_toolbar")
    try SurfaceManager_RecordEvent("ftb_host_show", "floating_toolbar", Map(
        "host", "hybrid",
        "bridge", String(bridge is Map ? bridge.Get("code", "") : ""),
        "shellPhase", 11
    ))
    try SurfaceManager_ObserveShow("floating_toolbar", Map(
        "entry", String(entry),
        "host", "hybrid",
        "bridge", String(bridge is Map ? bridge.Get("code", "") : ""),
        "shellPhase", 11
    ))
}

FloatingToolbarWails_RegisterExternalFtb(entry := "hybrid_register") {
    global g_FTBWails_HybridRegistered, g_FTBWails_HybridReady
    if !FloatingToolbarWails_ShouldUseHybrid()
        return false
    if !FuncExists("Nmer_WailsBridgePostShellFtb")
        return false
    res := Map("ok", false, "code", "REGISTER_FAIL")
    try res := Nmer_WailsBridgePostShellFtb("register_external", String(entry))
    catch {
    }
    ok := (res is Map) && res.Get("ok", false)
    if ok {
        g_FTBWails_HybridRegistered := true
        g_FTBWails_HybridReady := false
        FloatingToolbarWails_Log("hybrid_register_ok entry=" . String(entry))
        if FuncExists("Nmer_HybridSignoffBootstrapEnsure")
            SetTimer(Nmer_HybridSignoffBootstrapEnsure, -1)
    } else {
        FloatingToolbarWails_Log("hybrid_register_fail code=" . (res is Map ? res.Get("code", "?") : "?"))
    }
    return ok
}

FloatingToolbarWails_RegisterExternalReady(*) {
    global g_FTBWails_HybridReady, g_FTBWails_HybridRegistered
    if !FloatingToolbarWails_ShouldUseHybrid()
        return false
    if !FuncExists("Nmer_WailsBridgePostShellFtb")
        return false
    if !Nmer_WailsBridgeHealthy() {
        FloatingToolbarWails_EnsureBridge()
        if !Nmer_WailsBridgeHealthy()
            return false
    }
    if !g_FTBWails_HybridRegistered
        FloatingToolbarWails_RegisterExternalFtb("toolbar_ready")
    res := Map("ok", false)
    try res := Nmer_WailsBridgePostShellFtb("ready", "ahk_wv2_ready")
    catch {
    }
    ok := (res is Map) && res.Get("ok", false)
    if ok {
        g_FTBWails_HybridReady := true
        g_FTBWails_HybridInjectFailStreak := 0
        FloatingToolbarWails_Log("hybrid_ready_ok")
        if FuncExists("Nmer_HybridSignoffBootstrapEnsure")
            SetTimer(Nmer_HybridSignoffBootstrapEnsure, -1)
    }
    return ok
}

FloatingToolbarWails_HidePocWindow(*) {
    hwnd := FloatingToolbarWails_FindWindow()
    if !hwnd
        return
    expr := "ahk_id " . hwnd
    try WinHide(expr)
    catch {
    }
    try WinMinimize(expr)
    catch {
    }
}

FloatingToolbarWails_ResetEmbeddedShellState(*) {
    global g_FTBWails_ShellMounted, g_FTBWails_ShellVisible, g_FTBWails_HybridRegistered, g_FTBWails_HybridReady
    g_FTBWails_ShellMounted := false
    g_FTBWails_ShellVisible := false
    FloatingToolbarWails_StopEgressPump()
    if FuncExists("Nmer_WailsBridgePostShellFtb") && FuncExists("Nmer_WailsBridgeHealthy") && Nmer_WailsBridgeHealthy() {
        try Nmer_WailsBridgePostShellFtb("dispose", "hybrid_reset_embedded")
        catch {
        }
    }
    g_FTBWails_HybridRegistered := false
    g_FTBWails_HybridReady := false
}

FloatingToolbarWails_EnsureHybridBridge(*) {
    global g_FTBWails_HybridRegistered
    if !FloatingToolbarWails_ShouldUseHybrid()
        return false
    FloatingToolbarWails_SyncBridgePid()
    needRestart := false
    if FuncExists("Nmer_WailsBridge_ProcessExists") && Nmer_WailsBridge_ProcessExists() {
        if FuncExists("Nmer_WailsBridgeHealthy") && Nmer_WailsBridgeHealthy() && FuncExists("Nmer_WailsBridgeGetShellFtbStatus") {
            st := Nmer_WailsBridgeGetShellFtbStatus()
            mode := (st is Map) ? StrLower(Trim(String(st.Get("presentationMode", "")))) : ""
            if (mode != "external")
                needRestart := true
        }
    }
    if needRestart && FuncExists("Nmer_StartWailsBridge") {
        FloatingToolbarWails_Log("hybrid_bridge_restart mode=embedded")
        FloatingToolbarWails_ResetEmbeddedShellState()
        try Nmer_StartWailsBridge(true)
        catch {
        }
    }
    bridge := FloatingToolbarWails_EnsureBridge()
    if !(bridge is Map) || !bridge.Get("ok", false) {
        if FuncExists("Nmer_StartWailsBridge") {
            try Nmer_StartWailsBridge(false)
            catch {
            }
            bridge := FloatingToolbarWails_EnsureBridge()
        }
    }
    if !(bridge is Map) || !bridge.Get("ok", false)
        return false
    FloatingToolbarWails_HidePocWindow()
    if !g_FTBWails_HybridRegistered
        FloatingToolbarWails_RegisterExternalFtb("ensure_bridge")
    FloatingToolbarWails_EnsureInjectPump()
    if FuncExists("Nmer_HybridManualProbeEnsure")
        try Nmer_HybridManualProbeEnsure()
        catch {
        }
    return FuncExists("Nmer_WailsBridgeHealthy") && Nmer_WailsBridgeHealthy()
}

FloatingToolbarWails_EnsureInjectPump(*) {
    global g_FTBWails_InjectPumpOn
    if !FloatingToolbarWails_ShouldUseHybrid()
        return
    g_FTBWails_InjectPumpOn := true
    SetTimer(FloatingToolbarWails_InjectPumpTick, 150)
}

FloatingToolbarWails_StopInjectPump(*) {
    global g_FTBWails_InjectPumpOn
    g_FTBWails_InjectPumpOn := false
    SetTimer(FloatingToolbarWails_InjectPumpTick, 0)
}

FloatingToolbarWails_InjectPumpTick(*) {
    global g_FTBWails_InjectPumpOn
    if FloatingToolbarWails_ShouldUseHybrid() {
        if FuncExists("Nmer_HybridManualProbeEnsure")
            try Nmer_HybridManualProbeEnsure()
        if FuncExists("Nmer_HybridManualProbePoll")
            try Nmer_HybridManualProbePoll()
    }
    if !g_FTBWails_InjectPumpOn || !FloatingToolbarWails_ShouldUseHybrid()
        return
    if FuncExists("Nmer_HybridSignoffDrainInjectQueue")
        try Nmer_HybridSignoffDrainInjectQueue()
}

FloatingToolbarWails_DeliverPayloadHybrid(payload) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTBWails_HybridInjectFailStreak
    if !FloatingToolbarWails_ShouldUseHybrid()
        return false
    if !(payload is Map)
        return false
    if !FloatingToolbarWails_EnsureHybridBridge()
        return FloatingToolbarWails_DeliverPayloadHybridFallback(payload)
    if !FuncExists("Nmer_WailsBridgePostShellFtbInject")
        return FloatingToolbarWails_DeliverPayloadHybridFallback(payload)
    try {
        res := Nmer_WailsBridgePostShellFtbInject(payload)
        ok := (res is Map) && res.Get("ok", false)
        if ok {
            g_FTBWails_HybridInjectFailStreak := 0
            FloatingToolbarWails_EnsureInjectPump()
            return true
        }
        g_FTBWails_HybridInjectFailStreak += 1
        FloatingToolbarWails_Log("hybrid_inject_fail type=" . String(payload.Get("type", "")) . " code=" . (res is Map ? res.Get("code", "?") : "?"))
        agentStream := (String(payload.Get("type", "")) = "host_palette_agent_stream")
        if agentStream || (g_FTBWails_HybridInjectFailStreak >= 3)
            return FloatingToolbarWails_DeliverPayloadHybridFallback(payload)
        return false
    } catch as errHybrid {
        g_FTBWails_HybridInjectFailStreak += 1
        FloatingToolbarWails_Log("hybrid_inject_err type=" . String(payload.Get("type", "")) . " err=" . errHybrid.Message)
        if (g_FTBWails_HybridInjectFailStreak >= 3)
            return FloatingToolbarWails_DeliverPayloadHybridFallback(payload)
        return false
    }
}

FloatingToolbarWails_DeliverPayloadHybridFallback(payload) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTBWails_HybridInjectFailStreak
    if !(payload is Map)
        return false
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return false
    ok := false
    try {
        if FuncExists("WebView_QueuePayload")
            WebView_QueuePayload(g_FTB_WV2, payload)
        else
            g_FTB_WV2.PostWebMessageAsJson(Jxon_Dump(payload))
        ok := true
    } catch {
    }
    if ok {
        g_FTBWails_HybridInjectFailStreak := 0
        try SurfaceManager_RecordEvent("ftb_hybrid_inject_fallback", "floating_toolbar", Map(
            "type", String(payload.Get("type", ""))
        ))
        catch {
        }
        FloatingToolbarWails_Log("hybrid_inject_fallback type=" . String(payload.Get("type", "")))
    }
    return ok
}

FloatingToolbarWails_ShowHybrid(meta := 0) {
    global g_FTBWails_LastShowTick, g_FTBWails_HybridRegistered
    entry := "FloatingToolbarWails_ShowHybrid"
    if (meta is Map) && meta.Has("reason")
        entry := String(meta["reason"])
    if !FloatingToolbarWails_EnsureHybridBridge() {
        FloatingToolbarWails_Log("hybrid_show_bridge_fail")
        if FuncExists("ShowFloatingToolbar")
            return !!ShowFloatingToolbar()
        return false
    }
    bridge := Map("ok", true, "code", "HYBRID_BRIDGE_OK")
    FloatingToolbarWails_HidePocWindow()
    ok := false
    if FuncExists("ShowFloatingToolbar")
        ok := !!ShowFloatingToolbar()
    if ok {
        g_FTBWails_LastShowTick := A_TickCount
        FloatingToolbarWails_RecordHybridHostShow(bridge, entry)
        FloatingToolbarWails_Log("hybrid_show_ok bridge=" . bridge.Get("code", ""))
    }
    return ok
}

FloatingToolbarWails_HideHybrid(meta := 0) {
    global g_FTBWails_HybridReady
    if FuncExists("Nmer_WailsBridgePostShellFtb") && Nmer_WailsBridgeHealthy() {
        try Nmer_WailsBridgePostShellFtb("hide", "FloatingToolbarWails_HideHybrid")
        catch {
        }
    }
    g_FTBWails_HybridReady := false
    if FuncExists("HideFloatingToolbar")
        return !!HideFloatingToolbar()
    return true
}

FloatingToolbarWails_DisposeHybrid(reason := "") {
    global g_FTBWails_HybridRegistered, g_FTBWails_HybridReady
    FloatingToolbarWails_StopInjectPump()
    if FuncExists("Nmer_WailsBridgePostShellFtb") && Nmer_WailsBridgeHealthy() {
        try Nmer_WailsBridgePostShellFtb("dispose", "FloatingToolbarWails_DisposeHybrid", Map("reason", String(reason)))
        catch {
        }
    }
    g_FTBWails_HybridRegistered := false
    g_FTBWails_HybridReady := false
    if FuncExists("FloatingToolbar_Dispose")
        FloatingToolbar_Dispose(reason)
}

PaletteAgent_FtbTransportReady(*) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTBWails_ShellMounted
    global g_FTBWails_HybridRegistered, g_FTBWails_HybridReady
    if FuncExists("FloatingToolbarWails_ShouldUseHybrid") && FloatingToolbarWails_ShouldUseHybrid() {
        if IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady {
            if FuncExists("Nmer_WailsBridgeHealthy") && Nmer_WailsBridgeHealthy()
                return "hybrid"
            if FuncExists("FloatingToolbarWails_EnsureHybridBridge") && FloatingToolbarWails_EnsureHybridBridge()
                return "hybrid"
        }
        return ""
    }
    if IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady
        return "ahk_wv2"
    if FuncExists("FloatingToolbarWails_ShouldUseShell") && FloatingToolbarWails_ShouldUseShell() {
        if g_FTBWails_ShellMounted && FuncExists("Nmer_WailsBridgeHealthy") && Nmer_WailsBridgeHealthy()
            return "wails_shell"
        if FuncExists("Nmer_WailsBridgeGetShellFtbStatus") {
            st := Nmer_WailsBridgeGetShellFtbStatus()
            if (st is Map) && st.Get("ok", false) && st.Get("mounted", false) {
                g_FTBWails_ShellMounted := true
                return "wails_shell"
            }
        }
    }
    return ""
}
