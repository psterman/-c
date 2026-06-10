; CommandPaletteWailsHost.ahk — S8 B3：Wails 侧车承载命令面板（阶段 1：桥接 + 窗口激活，失败回退 AHK CP）

global g_CmdPalWails_LastShowTick := 0

CommandPaletteWails_Log(message) {
    try {
        if FuncExists("CommandPaletteRouter_Log")
            CommandPaletteRouter_Log(String(message))
        else if FuncExists("Nmer_WailsBridgeLog")
            Nmer_WailsBridgeLog("cp_wails " . String(message))
    } catch {
    }
}

CommandPaletteWails_FindWindow(*) {
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
    catch {
    }
    try WinActivate("ahk_id " . hwnd)
    catch {
    }
    try {
        if WinActive("ahk_id " . hwnd)
            return true
    } catch {
    }
    return hwnd > 0
}

CommandPaletteWails_Show(*) {
    global g_CmdPalWails_LastShowTick
    bridge := CommandPaletteWails_EnsureBridge()
    if !(bridge is Map) || !bridge.Get("ok", false) {
        CommandPaletteWails_Log("fallback bridge=" . (bridge is Map ? bridge.Get("code", "?") : "?"))
        return CommandPalette_Show()
    }
    if !CommandPaletteWails_ActivateWindow() {
        CommandPaletteWails_Log("fallback no_wails_hwnd")
        return CommandPalette_Show()
    }
    g_CmdPalWails_LastShowTick := A_TickCount
    try SurfaceManager_RegisterSurface("command_palette")
    try SurfaceManager_RecordEvent("cp_host_show", "command_palette", Map(
        "host", "wails",
        "bridge", String(bridge.Get("code", ""))
    ))
    try SurfaceManager_ObserveShow("command_palette", Map(
        "entry", "CommandPaletteWails_Show",
        "host", "wails",
        "bridge", String(bridge.Get("code", ""))
    ))
    CommandPaletteWails_Log("show_ok bridge=" . bridge.Get("code", ""))
    return true
}

CommandPaletteWails_Hide(*) {
    hwnd := CommandPaletteWails_FindWindow()
    if hwnd {
        try WinMinimize("ahk_id " . hwnd)
        catch {
            try WinHide("ahk_id " . hwnd)
            catch {
            }
        }
    }
    try SurfaceManager_ObserveHide("command_palette", Map("entry", "CommandPaletteWails_Hide", "host", "wails"))
    return true
}

CommandPaletteWails_Dispose(reason := "") {
  CommandPaletteWails_Hide()
  try SurfaceManager_ObserveClose("command_palette", Map(
      "entry", "CommandPaletteWails_Dispose",
      "host", "wails",
      "reason", String(reason)
  ))
}
