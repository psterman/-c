; SearchCenterCliBridge.ahk — CLI / ttyd 消息桥（CLI 工作台 / 遗留 SearchCenter）
#Requires AutoHotkey v2.0

SearchCenterCliBridge_IsCliContext(context) {
    ctx := String(context)
    return (ctx = "cli_workbench" || ctx = "unified_workbench")
}

ScCli_GetHostGui() {
    if FuncExists("UnifiedWb_IsVisible") && UnifiedWb_IsVisible() && FuncExists("UnifiedWb_GetGui") {
        try return UnifiedWb_GetGui()
        catch {
        }
    }
    if FuncExists("CliWb_IsVisible") && CliWb_IsVisible() && FuncExists("CliWb_GetGui") {
        try return CliWb_GetGui()
        catch {
        }
    }
    global g_SCWV_Gui
    return g_SCWV_Gui
}

ScCli_GetHostWv2(context := "") {
    ctx := Trim(String(context))
    if (ctx = "unified_workbench") {
        global g_UnifiedWb_WV2
        if IsObject(g_UnifiedWb_WV2)
            return g_UnifiedWb_WV2
    }
    if (ctx = "cli_workbench" || SearchCenterCliBridge_IsCliContext(ctx)) {
        global g_CliWb_WV2
        if IsObject(g_CliWb_WV2)
            return g_CliWb_WV2
    }
    if FuncExists("CliWb_IsVisible") && CliWb_IsVisible() {
        global g_CliWb_WV2
        return g_CliWb_WV2
    }
    global g_SCWV_WV2
    return g_SCWV_WV2
}

ScCli_PostJsonToHost(payload) {
    if FuncExists("UnifiedWb_IsVisible") && UnifiedWb_IsVisible() && FuncExists("UnifiedWb_PostJson") {
        try UnifiedWb_PostJson(payload, true)
        return
    }
    if FuncExists("CliWb_IsVisible") && CliWb_IsVisible() && FuncExists("CliWb_PostJson") {
        try CliWb_PostJson(payload)
        return
    }
    if FuncExists("SCWV_PostJson")
        try SCWV_PostJson(payload)
}

ScCli_FocusTtydForEngine(engine := "") {
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
    try ScCli_PostJsonToHost(Map("type", "focusCliFrame", "engine", eng))
    catch {
    }
    Sleep(140)
    gui := ScCli_GetHostGui()
    try {
        if (IsObject(gui) && gui.HasProp("Hwnd")) {
            hwnd := gui.Hwnd
            if (hwnd && WinExist("ahk_id " . hwnd))
                WinActivate("ahk_id " . hwnd)
        }
    } catch {
    }
    Sleep(80)
    return true
}

ScCli_InjectPromptToTtyd(prompt, engine := "") {
    p := Trim(String(prompt))
    if (p = "")
        return false
    if !ScCli_FocusTtydForEngine(engine)
        return false
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

ScCli_PasteToTtyd(engine := "") {
    if !ScCli_FocusTtydForEngine(engine)
        return false
    try {
        Send("^v")
    } catch {
        return false
    }
    return true
}

ScCli_InterruptTtyd(engine := "") {
    if !ScCli_FocusTtydForEngine(engine)
        return false
    try {
        Send("^{c}")
    } catch {
        return false
    }
    return true
}

ScCli_SendToCLI(prompt, engine := "") {
    global SearchCenterWebKeyword
    p := Trim(String(prompt))
    if (p = "")
        p := Trim(String(SearchCenterWebKeyword))
    if (p = "") {
        try TrayTip("请输入要发送给终端的内容", "提示", "Icon! 2")
        catch {
        }
        return
    }
    if FuncExists("_SCWV_RecordSearchHistory")
        try _SCWV_RecordSearchHistory(p)
        catch {
        }
    ScCli_InjectPromptToTtyd(p, engine)
}

ScCli_OpenCliWorkDir(engine := "") {
    eng := Trim(String(engine))
    if (eng = "")
        eng := "codex_cli"
    try eng := NiumaTtyd_NormalizeEngine(eng)
    catch {
        eng := "codex_cli"
    }
    wd := ""
    try wd := NiumaTtyd_GetWorkDirForEngine(eng)
    catch {
    }
    if (wd = "")
        try wd := NiumaTtyd_WorkDir()
        catch {
        }
    wd := Trim(String(wd))
    if (wd = "" || !DirExist(wd)) {
        try TrayTip("终端", "工作目录不存在", "Icon! 2")
        catch {
        }
        return false
    }
    try {
        Run('explorer.exe /e,"' . wd . '"')
        return true
    } catch as e {
        try TrayTip("终端", "无法打开工作目录: " . e.Message, "Iconx 2")
        catch {
        }
        return false
    }
}

SearchCenterCliBridge_HandleMessage(msg, context := "cli_workbench", senderWv2 := 0) {
    if !(msg is Map)
        return false
    if !SearchCenterCliBridge_IsCliContext(context)
        return false
    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ = "")
        return false
    wv2 := IsObject(senderWv2) ? senderWv2 : ScCli_GetHostWv2(context)

    switch typ {
        case "ensure_cli":
            reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
            engine := msg.Has("engine") ? Trim(String(msg["engine"])) : "codex_cli"
            SetTimer(NiumaTtyd_DeferredOpenJob.Bind(reqId, engine, wv2), -10)
            return true
        case "send_cli":
            prompt := msg.Has("text") ? String(msg["text"]) : ""
            eng := msg.Has("engine") ? Trim(String(msg["engine"])) : ""
            ScCli_SendToCLI(prompt, eng)
            return true
        case "cliSend":
            prompt := msg.Has("prompt") ? String(msg["prompt"]) : ""
            eng := msg.Has("engine") ? Trim(String(msg["engine"])) : ""
            ScCli_SendToCLI(prompt, eng)
            return true
        case "cliInject":
            prompt := msg.Has("prompt") ? String(msg["prompt"]) : ""
            eng := msg.Has("engine") ? Trim(String(msg["engine"])) : ""
            ScCli_InjectPromptToTtyd(prompt, eng)
            return true
        case "cliPaste":
            eng := msg.Has("engine") ? Trim(String(msg["engine"])) : ""
            ScCli_PasteToTtyd(eng)
            return true
        case "cliInterrupt":
            eng := msg.Has("engine") ? Trim(String(msg["engine"])) : ""
            ScCli_InterruptTtyd(eng)
            return true
        case "cliOpen":
            if FuncExists("OpenSelectedCLIAgents")
                try OpenSelectedCLIAgents()
                catch as _e {
                    NmerCatch(A_ThisFunc, _e)
                }
            return true
        case "cliTerminalFocus":
            global g_CliWb_CliTerminalFocus, g_CliWb_UserMinimized
            if g_CliWb_UserMinimized
                g_CliWb_CliTerminalFocus := false
            else {
                g_CliWb_CliTerminalFocus := msg.Has("active") ? !!msg["active"] : false
                if g_CliWb_CliTerminalFocus && FuncExists("_CliWb_BlockDeactivate")
                    _CliWb_BlockDeactivate(4500, "cli_terminal")
            }
            return true
        case "niuma_cli_open":
            reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
            engine := msg.Has("engine") ? Trim(String(msg["engine"])) : "codex_cli"
            SetTimer(NiumaTtyd_DeferredOpenJob.Bind(reqId, engine, wv2), -10)
            return true
        case "niuma_cli_restart":
            reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
            engine := msg.Has("engine") ? Trim(String(msg["engine"])) : "codex_cli"
            SetTimer(NiumaTtyd_DeferredRestartJob.Bind(reqId, engine, wv2), -10)
            return true
        case "niuma_cli_open_external":
            reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
            expectedBaseUrl := msg.Has("baseUrl") ? String(msg["baseUrl"]) : ""
            engine := msg.Has("engine") ? Trim(String(msg["engine"])) : "codex_cli"
            SetTimer(NiumaTtyd_DeferredExternalOpenJob.Bind(reqId, expectedBaseUrl, engine, wv2), -10)
            return true
        case "niuma_cli_open_workdir":
            eng := msg.Has("engine") ? Trim(String(msg["engine"])) : "codex_cli"
            ScCli_OpenCliWorkDir(eng)
            return true
        default:
            return false
    }
}
