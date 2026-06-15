; CommandPaletteWailsHost.ahk — S8 B3：Wails 侧车承载命令面板（阶段 2：CP shell + inject/egress）

global g_CmdPalWails_LastShowTick := 0
global g_CmdPalWails_Visible := false
global g_CmdPalWails_ShellMounted := false
global g_CmdPalWails_ShellVisible := false
global g_CmdPalWails_EgressPumpOn := false
global g_CmdPalWails_EgressDrainCount := 0
global g_CmdPalWails_EgressLastType := ""
global g_CmdPalWails_InjectPushOk := false

CommandPaletteWails_Log(message) {
    try {
        if FuncExists("CommandPaletteRouter_Log")
            CommandPaletteRouter_Log(String(message))
        else if FuncExists("Nmer_WailsBridgeLog")
            Nmer_WailsBridgeLog("cp_wails " . String(message))
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

CommandPaletteWails_ShouldUseShell(*) {
    if FuncExists("Nmer_CommandPaletteHost")
        return Nmer_CommandPaletteHost() = "wails"
    return false
}

CommandPalette_AhkWebViewEnabled(*) {
    if FuncExists("CommandPaletteWails_ShouldUseShell") && CommandPaletteWails_ShouldUseShell()
        return false
    return true
}

CommandPaletteWails_FindWindow(*) {
    try {
        hwnd := WinExist("ahk_exe nmer-wails.exe")
        if hwnd
            return hwnd
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try {
        return WinExist("NMER Wails POC")
    } catch {
        return 0
    }
}

CommandPaletteWails_EnsureBridge(*) {
    if FuncExists("Nmer_EnsureWailsBridgeForPalette")
        return Nmer_EnsureWailsBridgeForPalette()
    if FuncExists("Nmer_StartWailsBridge") && Nmer_StartWailsBridge(false)
        return Map("ok", true, "code", "BRIDGE_STARTED")
    return Map("ok", false, "code", "BRIDGE_UNAVAILABLE")
}

CommandPaletteWails_ActivateWindow(*) {
    hwnd := CommandPaletteWails_FindWindow()
    if !hwnd
        return false
    try WinShow("ahk_id " . hwnd)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try WinActivate("ahk_id " . hwnd)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try {
        if WinActive("ahk_id " . hwnd)
            return true
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return hwnd > 0
}

CommandPaletteWails_MountShell(entry) {
    if !FuncExists("Nmer_WailsBridgePostShellCp")
        return Map("ok", false, "code", "SHELL_CP_API_MISSING")
    return Nmer_WailsBridgePostShellCp("show", String(entry))
}

CommandPaletteWails_EnsureShellForPush(*) {
    global g_CmdPalWails_ShellMounted, g_CmdPalWails_ShellVisible
    if g_CmdPalWails_ShellMounted && g_CmdPalWails_ShellVisible
        return true
    shell := CommandPaletteWails_MountShell("push_ensure")
    if shell is Map && shell.Get("ok", false) {
        g_CmdPalWails_ShellMounted := true
        g_CmdPalWails_ShellVisible := true
        return true
    }
    return false
}

CommandPaletteWails_PushToWeb(payload) {
    if !(payload is Map)
        return false
    if FuncExists("CommandPaletteWails_EnsureEgressPump")
        CommandPaletteWails_EnsureEgressPump()
    if FuncExists("CommandPaletteWails_EnsureShellForPush")
        CommandPaletteWails_EnsureShellForPush()
    if FuncExists("Nmer_WailsBridgePostShellCpInject") {
        res := Nmer_WailsBridgePostShellCpInject(payload)
        ok := !!(res is Map) && res.Get("ok", false)
        global g_CmdPalWails_InjectPushOk := ok
        return ok
    }
    return false
}

CommandPaletteWails_HandleEgressPayload(msg) {
    global g_CmdPalWails_EgressDrainCount, g_CmdPalWails_EgressLastType
    if !(msg is Map)
        return
    typ := msg.Has("type") ? String(msg["type"]) : ""
    g_CmdPalWails_EgressDrainCount += 1
    g_CmdPalWails_EgressLastType := typ
    if (typ = "nmer_cp_shell_ready") {
        if FuncExists("CommandPalette_DispatchWebMessage")
            CommandPalette_DispatchWebMessage(Map("type", "palette_ready"))
        return
    }
    if FuncExists("CommandPalette_DispatchWebMessage")
        CommandPalette_DispatchWebMessage(msg)
    try SurfaceManager_RecordEvent("cp_shell_egress", "command_palette", Map("type", typ, "host", "wails"))
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

CommandPaletteWails_EgressPumpTick(*) {
    global g_CmdPalWails_EgressPumpOn
    if !g_CmdPalWails_EgressPumpOn || !CommandPaletteWails_ShouldUseShell()
        return
    if !FuncExists("Nmer_WailsBridgeDrainShellCpEgress")
        return
    msgs := []
    try msgs := Nmer_WailsBridgeDrainShellCpEgress()
    catch {
        return
    }
    for _, msg in msgs
        CommandPaletteWails_HandleEgressPayload(msg)
}

CommandPaletteWails_EnsureEgressPump(*) {
    global g_CmdPalWails_EgressPumpOn
    if !CommandPaletteWails_ShouldUseShell()
        return
    if g_CmdPalWails_EgressPumpOn
        return
    g_CmdPalWails_EgressPumpOn := true
    SetTimer(CommandPaletteWails_EgressPumpTick, 150)
}

CommandPaletteWails_StopEgressPump(*) {
    global g_CmdPalWails_EgressPumpOn
    g_CmdPalWails_EgressPumpOn := false
    SetTimer(CommandPaletteWails_EgressPumpTick, 0)
}

CommandPaletteWails_DrainEgressOnce(*) {
    CommandPaletteWails_EgressPumpTick()
}

CommandPaletteWails_IsVisible(*) {
    global g_CmdPalWails_Visible
    if !g_CmdPalWails_Visible
        return false
    hwnd := CommandPaletteWails_FindWindow()
    if !hwnd
        return false
    try {
        return !!(WinGetStyle("ahk_id " . hwnd) & 0x10000000)
    } catch {
        return true
    }
}

CommandPaletteWails_RetireAhkWebView(reason := "shell_phase2") {
    if FuncExists("CommandPalette_AhkWebViewEnabled") && CommandPalette_AhkWebViewEnabled()
        return false
    if !FuncExists("CommandPalette_DisposeAhkWebViewIfRetired")
        return false
    ok := false
    try ok := !!CommandPalette_DisposeAhkWebViewIfRetired(reason)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if ok
        CommandPaletteWails_Log("ahk_wv2_retired reason=" . String(reason))
    return ok
}

CommandPaletteWails_FallbackToAhkShow(*) {
    if !FuncExists("CommandPalette_Show")
        return false
    return !!CommandPalette_Show()
}

CommandPaletteWails_Show(*) {
    global g_CmdPalWails_LastShowTick, g_CmdPalWails_Visible, g_CmdPalWails_ShellMounted, g_CmdPalWails_ShellVisible
    bridge := CommandPaletteWails_EnsureBridge()
    if !(bridge is Map) || !bridge.Get("ok", false) {
        CommandPaletteWails_Log("fallback bridge=" . (bridge is Map ? bridge.Get("code", "?") : "?"))
        g_CmdPalWails_Visible := false
        g_CmdPalWails_ShellMounted := false
        g_CmdPalWails_ShellVisible := false
        return CommandPaletteWails_FallbackToAhkShow()
    }
    shellPhase := CommandPaletteWails_ShouldUseShell() ? 2 : 1
    shellMounted := false
    if shellPhase >= 2 {
        shell := CommandPaletteWails_MountShell("CommandPaletteWails_Show")
        if shell is Map && shell.Get("ok", false) {
            g_CmdPalWails_ShellMounted := true
            g_CmdPalWails_ShellVisible := true
            shellMounted := true
            if FuncExists("CommandPaletteWails_RetireAhkWebView")
                CommandPaletteWails_RetireAhkWebView("shell_show")
            hwnd := CommandPaletteWails_FindWindow()
            if hwnd {
                try WinShow("ahk_id " . hwnd)
                catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
            }
        }
    }
    if !shellMounted && !CommandPaletteWails_ActivateWindow() {
        CommandPaletteWails_Log("fallback shell_mount_or_activate")
        g_CmdPalWails_Visible := false
        return CommandPaletteWails_FallbackToAhkShow()
    }
    if !CommandPaletteWails_ActivateWindow() {
        CommandPaletteWails_Log("fallback activate_after_shell")
        g_CmdPalWails_Visible := false
        return CommandPaletteWails_FallbackToAhkShow()
    }
    g_CmdPalWails_LastShowTick := A_TickCount
    g_CmdPalWails_Visible := true
    try SurfaceManager_RegisterSurface("command_palette")
    try SurfaceManager_RecordEvent("cp_host_show", "command_palette", Map(
        "host", "wails",
        "bridge", String(bridge.Get("code", "")),
        "shellPhase", shellPhase
    ))
    try SurfaceManager_ObserveShow("command_palette", Map(
        "entry", "CommandPaletteWails_Show",
        "host", "wails",
        "bridge", String(bridge.Get("code", "")),
        "shellPhase", shellPhase
    ))
    if FuncExists("Nmer_WailsBridgePostShellCpInject")
        try Nmer_WailsBridgePostShellCpInject(Map("type", "palette_show"))
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    if FuncExists("CommandPaletteWails_EnsureEgressPump")
        CommandPaletteWails_EnsureEgressPump()
    CommandPaletteWails_Log("show_ok bridge=" . bridge.Get("code", "") . " shellPhase=" . shellPhase)
    return true
}

CommandPaletteWails_Hide(*) {
    global g_CmdPalWails_Visible, g_CmdPalWails_ShellVisible
    g_CmdPalWails_Visible := false
    if FuncExists("CommandPaletteWails_StopEgressPump")
        CommandPaletteWails_StopEgressPump()
    if FuncExists("Nmer_WailsBridgePostShellCp")
        try Nmer_WailsBridgePostShellCp("hide", "CommandPaletteWails_Hide")
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    g_CmdPalWails_ShellVisible := false
    hwnd := CommandPaletteWails_FindWindow()
    if hwnd {
        try WinMinimize("ahk_id " . hwnd)
        catch {
            try WinHide("ahk_id " . hwnd)
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        }
    }
    try SurfaceManager_ObserveHide("command_palette", Map("entry", "CommandPaletteWails_Hide", "host", "wails"))
    return true
}

CommandPaletteWails_Dispose(reason := "") {
    global g_CmdPalWails_Visible, g_CmdPalWails_ShellMounted, g_CmdPalWails_ShellVisible
    g_CmdPalWails_Visible := false
    g_CmdPalWails_ShellMounted := false
    g_CmdPalWails_ShellVisible := false
    if FuncExists("Nmer_WailsBridgePostShellCp")
        try Nmer_WailsBridgePostShellCp("dispose", "CommandPaletteWails_Dispose", Map("reason", String(reason)))
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    CommandPaletteWails_Hide()
    try SurfaceManager_ObserveClose("command_palette", Map(
        "entry", "CommandPaletteWails_Dispose",
        "host", "wails",
        "reason", String(reason)
    ))
}
