#Requires AutoHotkey v2.0

VoiceInput_SyncLegacyFlags() {
    global VoiceInputActive, VoiceInputPaused, VoiceSearchActive
    st := VoiceFSM_State()
    VoiceInputActive := (st = "listening" || st = "paused" || st = "processing")
    VoiceInputPaused := (st = "paused" || st = "search_paused")
    if FuncExists("VoiceInput_IsSearchFsmState")
        VoiceSearchActive := VoiceInput_IsSearchFsmState(st)
}

VoiceInputEffects_OnTransition(oldState, newState, event) {
    o := String(oldState)
    n := String(newState)
    ev := String(event)
    if (o = n)
        return
    VoiceInput_SyncLegacyFlags()
    if (n = "search_listening" && o = "idle")
        VoiceInputEffect_SearchOpen()
    else if (n = "idle" && FuncExists("VoiceInput_IsSearchFsmState") && VoiceInput_IsSearchFsmState(o))
        VoiceInputEffect_SearchStop(o)
    else if (n = "listening" && (o = "idle" || o = "error"))
        VoiceInputEffect_StartListening(o)
    else if (n = "idle")
        VoiceInputEffect_StopToIdle(o, ev)
    else if (n = "paused" && o = "listening")
        VoiceInputEffect_Pause()
    else if (n = "search_paused" && o = "search_listening")
        VoiceInputEffect_Pause()
    else if (n = "listening" && o = "paused")
        VoiceInputEffect_Resume()
    else if (n = "search_listening" && o = "search_paused")
        VoiceInputEffect_Resume()
    else if (n = "processing")
        VoiceInputEffect_ProcessingBegin()
    else if (o = "processing" && (n = "listening" || n = "search_listening"))
        VoiceInputEffect_ProcessingDone()
    else if (n = "error")
        VoiceInputEffect_Error()
}

VoiceInputEffect_StartListening(prevState) {
    global VoiceInputContent, CursorPath, AISleepTime, PanelVisible
    if (PanelVisible)
        VoiceInput_HideCursorPanelIfNeeded()
    try {
        if !WinExist("ahk_exe Cursor.exe") {
            if (CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                Sleep(AISleepTime)
            } else {
                TrayTip(GetText("cursor_not_running_error"), GetText("error"), "Iconx 2")
                VoiceFSM_Dispatch("reset")
                return
            }
        }
        LegacyGuard_RequestCursorFocus("VoiceInput", "voice_input_cursor", 120)
        WinWaitActive("ahk_exe Cursor.exe", , 2)
        Sleep(300)
        Send("{Esc}")
        Sleep(100)
        Send("^l")
        Sleep(500)
        if !WinActive("ahk_exe Cursor.exe") {
            LegacyGuard_RequestCursorFocus("VoiceInput", "voice_input_cursor", 120)
            Sleep(200)
        }
        WinWaitActive("ahk_exe Cursor.exe", , 1)
        Sleep(200)
        Send("^a")
        Sleep(100)
        Send("{Delete}")
        Sleep(100)
        if !WinActive("ahk_exe Cursor.exe") {
            LegacyGuard_RequestCursorFocus("VoiceInput", "voice_input_cursor", 120)
            WinWaitActive("ahk_exe Cursor.exe", , 2)
            Sleep(300)
        }
        if WinActive("ahk_exe Cursor.exe") {
            Send("^+{Space}")
            Sleep(220)
            VoiceInputContent := ""
            ShowVoiceInputPanel()
            VoiceInput_SyncLegacyFlags()
        } else {
            TrayTip("无法激活 Cursor 窗口", GetText("error"), "Iconx 2")
            VoiceFSM_Dispatch("reset")
        }
    } catch as e {
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
        VoiceFSM_Dispatch("reset")
    }
}

VoiceInputEffect_StopToIdle(prevState, event) {
    global VoiceInputContent, CapsLock
    try {
        if (CapsLock)
            CapsLock := false
        if WinExist("ahk_exe Cursor.exe") {
            LegacyGuard_RequestCursorFocus("VoiceInput", "voice_input_cursor", 120)
            WinWaitActive("ahk_exe Cursor.exe", , 2)
            Sleep(200)
            Send("^+{Space}")
            Sleep(260)
            Send("{Enter}")
            Sleep(200)
        }
    } catch as e {
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    } finally {
        HideVoiceInputPanel()
        VoiceInput_SyncLegacyFlags()
    }
}

VoiceInputEffect_Pause() {
    try {
        if !WinExist("ahk_exe Cursor.exe")
            return
        LegacyGuard_RequestCursorFocus("VoiceInput", "voice_input_cursor", 120)
        WinWaitActive("ahk_exe Cursor.exe", , 2)
        Sleep(200)
        Send("^+{Space}")
        Sleep(300)
        UpdateVoiceInputPanelState()
    } catch as e {
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

VoiceInputEffect_Resume() {
    try {
        if !WinExist("ahk_exe Cursor.exe")
            return
        LegacyGuard_RequestCursorFocus("VoiceInput", "voice_input_cursor", 120)
        WinWaitActive("ahk_exe Cursor.exe", , 2)
        Sleep(200)
        Send("^+{Space}")
        Sleep(300)
        UpdateVoiceInputPanelState()
    } catch as e {
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

VoiceInputEffect_ProcessingBegin() {
    global g_VoiceFSMSearchRun
    if (g_VoiceFSMSearchRun)
        VoiceInputEffect_RunVoiceSearch()
}

VoiceInputEffect_ProcessingDone() {
    global g_VoiceFSMSearchRun
    g_VoiceFSMSearchRun := false
}

VoiceInputEffect_RunVoiceSearch() {
    global VoiceSearchInputEdit, VoiceSearchSelectedEngines, VoiceSearchPanelVisible, g_VoiceFSMSearchRun
    try {
        if (!VoiceSearchPanelVisible || !VoiceSearchInputEdit) {
            VoiceFSM_Dispatch("processing_done")
            return
        }
        Content := VoiceSearchInputEdit.Value
        if (Content = "" || StrLen(Content) = 0) {
            VoiceFSM_Dispatch("processing_done")
            return
        }
        if (!IsSet(VoiceSearchSelectedEngines) || !IsObject(VoiceSearchSelectedEngines) || VoiceSearchSelectedEngines.Length = 0) {
            TrayTip(GetText("no_search_engine_selected"), GetText("tip"), "Icon! 2")
            VoiceFSM_Dispatch("processing_done")
            return
        }
        HideVoiceSearchInputPanel()
        for Index, Engine in VoiceSearchSelectedEngines {
            if (!IsSet(Engine) || Engine = "")
                continue
            VoiceInputEffect_SendSearchToBrowser(Content, Engine)
            if (Index < VoiceSearchSelectedEngines.Length)
                Sleep(300)
        }
        TrayTip(FormatText("search_engines_opened", VoiceSearchSelectedEngines.Length), GetText("tip"), "Iconi 1")
        VoiceFSM_Dispatch("processing_done")
    } catch as e {
        g_VoiceFSMSearchRun := false
        VoiceFSM_Dispatch("error")
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

VoiceInputEffect_Error() {
    SetTimer((*) => VoiceFSM_Dispatch("reset"), -300)
}

VoiceInputEffect_SendToCursor(Content) {
    try {
        if !WinActive("ahk_exe Cursor.exe") {
            LegacyGuard_RequestCursorFocus("VoiceInput", "voice_input_cursor", 120)
            WinWaitActive("ahk_exe Cursor.exe", , 1)
            Sleep(200)
        }
        if !WinActive("ahk_exe Cursor.exe") {
            LegacyGuard_RequestCursorFocus("VoiceInput", "voice_input_cursor", 120)
            Sleep(200)
        }
        if (Content != "" && StrLen(Content) > 0) {
            Send("^l")
            Sleep(300)
            Send("^a")
            Sleep(100)
            Send("{Delete}")
            Sleep(100)
            A_Clipboard := Content
            Sleep(100)
            Send("^v")
            Sleep(200)
            Send("{Enter}")
            Sleep(300)
        }
    } catch as e {
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

VoiceInputEffect_SearchOpen() {
    global PanelVisible
    SetCapsLockState("Off")
    if (PanelVisible)
        VoiceInput_HideCursorPanelIfNeeded()
    try {
        ShowVoiceSearchInputPanel()
    } catch as e {
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
        VoiceFSM_Dispatch("search_stop")
    }
}

VoiceInputEffect_SearchStop(prevState) {
    try VoiceInputEffect_SearchStopListeningImpl()
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try VoiceInputEffect_DestroySearchPanel()
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    VoiceInput_SyncLegacyFlags()
}

VoiceInputEffect_DestroySearchPanel() {
    global GuiID_VoiceInput, VoiceSearchPanelVisible, VoiceSearchInputEdit
    SetCapsLockState("Off")
    SetTimer(MonitorSelectedText, 0)
    VoiceSearchPanelVisible := false
    if (GuiID_VoiceInput != 0) {
        try GuiID_VoiceInput.Destroy()
        GuiID_VoiceInput := 0
    }
    VoiceSearchInputEdit := 0
}

VoiceInputEffect_SearchStopListening() {
    global VoiceInputMethod, CapsLock, VoiceSearchInputEdit, VoiceSearchPanelVisible
    if (!VoiceSearchPanelVisible)
        return
    VoiceInputEffect_SearchStopListeningImpl()
}

VoiceInputEffect_SearchStartListening() {
    global VoiceInputMethod, VoiceSearchPanelVisible, VoiceSearchInputEdit, UI_Colors
    if !VoiceSearchPanelVisible
        return
    if (VoiceFSM_State() != "search_listening" && VoiceFSM_State() != "search_paused")
        return
    try {
        global GuiID_VoiceInput
        if (GuiID_VoiceInput) {
            LegacyGuard_RequestFocus("VoiceInput", GuiID_VoiceInput.Hwnd, 30, "voice_input_gui", 120)
            Sleep(200)
            if (!WinActive("ahk_id " . GuiID_VoiceInput.Hwnd)) {
                LegacyGuard_RequestFocus("VoiceInput", GuiID_VoiceInput.Hwnd, 30, "voice_input_gui", 120)
                Sleep(200)
            }
        }
        if (VoiceSearchInputEdit) {
            VoiceSearchInputEdit.Value := ""
            InputEditHwnd := VoiceSearchInputEdit.Hwnd
            try {
                ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                Sleep(100)
            } catch {
                VoiceSearchInputEdit.Focus()
                Sleep(100)
            }
        }
        VoiceInputMethod := DetectInputMethod()
        if (VoiceInputMethod = "baidu") {
            if (VoiceSearchInputEdit) {
                InputEditHwnd := VoiceSearchInputEdit.Hwnd
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(150)
                } catch {
                    VoiceSearchInputEdit.Focus()
                    Sleep(150)
                }
                SwitchToChineseIME()
                Sleep(200)
            }
            Send("!y")
            Sleep(220)
            Send("{F2}")
            Sleep(300)
        } else if (VoiceInputMethod = "xunfei") {
            Send("{F6}")
            Sleep(220)
            if (VoiceSearchInputEdit) {
                InputEditHwnd := VoiceSearchInputEdit.Hwnd
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(100)
                } catch {
                    VoiceSearchInputEdit.Focus()
                    Sleep(100)
                }
            }
        } else {
            if (VoiceSearchInputEdit) {
                InputEditHwnd := VoiceSearchInputEdit.Hwnd
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(150)
                } catch {
                    VoiceSearchInputEdit.Focus()
                    Sleep(150)
                }
                SwitchToChineseIME()
                Sleep(200)
            }
            Send("!y")
            Sleep(220)
            Send("{F2}")
            Sleep(300)
        }
        global VoiceSearchContent := ""
        Sleep(500)
        VoiceInput_SyncLegacyFlags()
    } catch as e {
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
        VoiceFSM_Dispatch("search_stop")
    }
}

VoiceInputEffect_SearchStopListeningImpl() {
    global VoiceInputMethod, CapsLock, VoiceSearchInputEdit, VoiceSearchPanelVisible
    if !VoiceSearchPanelVisible
        return
    try {
        if (CapsLock)
            CapsLock := false
        if (VoiceInputMethod = "baidu") {
            Send("{F1}")
            Sleep(220)
            OldClipboard := A_Clipboard
            Send("^a")
            Sleep(200)
            A_Clipboard := ""
            Send("^c")
            if ClipWait(0.2)
                global VoiceSearchContent := A_Clipboard
            A_Clipboard := OldClipboard
            Send("!y")
            Sleep(300)
        } else if (VoiceInputMethod = "xunfei") {
            Send("{F6}")
            Sleep(260)
            OldClipboard := A_Clipboard
            Send("^a")
            Sleep(200)
            A_Clipboard := ""
            Send("^c")
            if ClipWait(0.2)
                global VoiceSearchContent := A_Clipboard
            A_Clipboard := OldClipboard
        } else {
            Send("{F1}")
            Sleep(220)
            OldClipboard := A_Clipboard
            Send("^a")
            Sleep(200)
            A_Clipboard := ""
            Send("^c")
            if ClipWait(0.2)
                global VoiceSearchContent := A_Clipboard
            A_Clipboard := OldClipboard
            Send("!y")
            Sleep(300)
        }
        SetTimer(UpdateVoiceSearchInputInPanel, 0)
        global VoiceSearchContent
        if (VoiceSearchContent != "" && StrLen(VoiceSearchContent) > 0 && VoiceSearchInputEdit) {
            VoiceSearchInputEdit.Value := VoiceSearchContent
            VoiceSearchInputEdit.Focus()
        }
        VoiceInput_SyncLegacyFlags()
    } catch as e {
        SetTimer(UpdateVoiceSearchInputInPanel, 0)
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

VoiceInputEffect_BuildSearchUrl(Content, Engine) {
    eng := StrLower(Trim(String(Engine)))
    if (eng = "")
        return ""
    AgentInfo := GetCLIAgentLaunchInfo(Engine)
    if (AgentInfo && IsObject(AgentInfo))
        return ""
    EncodedContent := UriEncode(Content)
    switch eng {
        case "deepseek":
            return "https://chat.deepseek.com/?q=" . EncodedContent
        case "yuanbao":
            return "https://yuanbao.tencent.com/?q=" . EncodedContent
        case "doubao":
            return "https://www.doubao.com/chat/?q=" . EncodedContent
        case "zhipu":
            return "https://chatglm.cn/main/search?query=" . EncodedContent
        case "mita":
            return "https://metaso.cn/?q=" . EncodedContent
        case "wenxin":
            return "https://yiyan.baidu.com/search?query=" . EncodedContent
        case "qianwen":
            return "https://tongyi.aliyun.com/qianwen/chat?intent=chat&query=" . EncodedContent
        case "kimi":
            return "https://kimi.moonshot.cn/_prefill_chat?force_search=true&send_immediately=true&prefill_prompt=" . EncodedContent
        case "perplexity":
            return "https://www.perplexity.ai/search?intent=qa&q=" . EncodedContent
        case "copilot":
            return "https://copilot.microsoft.com/chat?q=" . EncodedContent
        case "chatgpt":
            return "https://chat.openai.com/?q=" . EncodedContent
        case "grok":
            return "https://grok.com/?q=" . EncodedContent
        case "you":
            return "https://you.com/search?q=" . EncodedContent
        case "claude":
            return "https://claude.ai/new?q=" . EncodedContent
        case "monica":
            return "https://monica.so/answers/?q=" . EncodedContent
        case "webpilot":
            return "https://webpilot.ai/search?q=" . EncodedContent
        case "zhihu":
            return "https://www.zhihu.com/search?q=" . EncodedContent
        case "baidu":
            return "https://www.baidu.com/s?wd=" . EncodedContent
        case "google", "google_image":
            return "https://www.google.com/search?q=" . EncodedContent
        case "youtube":
            return "https://www.youtube.com/results?search_query=" . EncodedContent
        case "gemini":
            return "https://gemini.google.com/app"
        default:
            return "https://chat.deepseek.com/?q=" . EncodedContent
    }
}

VoiceInputEffect_SendSearchToBrowser(Content, Engine) {
    try {
        AgentInfo := GetCLIAgentLaunchInfo(Engine)
        if (AgentInfo && IsObject(AgentInfo)) {
            if FuncExists("VoiceInputEffect_DispatchCliAgents")
                VoiceInputEffect_DispatchCliAgents(Content, "send", [Engine])
            return
        }
        SearchURL := VoiceInputEffect_BuildSearchUrl(Content, Engine)
        if (SearchURL = "")
            return
        Run(SearchURL)
        TrayTip(GetText("voice_search_sent"), GetText("tip"), "Iconi 1")
    } catch as e {
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}
