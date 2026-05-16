#Requires AutoHotkey v2.0

VoiceInput_SyncLegacyFlags() {
    global VoiceInputActive, VoiceInputPaused
    st := VoiceFSM_State()
    VoiceInputActive := (st = "listening" || st = "paused" || st = "processing")
    VoiceInputPaused := (st = "paused")
}

VoiceInputEffects_OnTransition(oldState, newState, event) {
    o := String(oldState)
    n := String(newState)
    ev := String(event)
    if (o = n)
        return
    VoiceInput_SyncLegacyFlags()
    if (n = "listening" && (o = "idle" || o = "error"))
        VoiceInputEffect_StartListening(o)
    else if (n = "idle")
        VoiceInputEffect_StopToIdle(o, ev)
    else if (n = "paused" && o = "listening")
        VoiceInputEffect_Pause()
    else if (n = "listening" && o = "paused")
        VoiceInputEffect_Resume()
    else if (n = "processing")
        VoiceInputEffect_ProcessingBegin()
    else if (o = "processing" && n = "listening")
        VoiceInputEffect_ProcessingDone()
    else if (n = "error")
        VoiceInputEffect_Error()
}

VoiceInputEffect_StartListening(prevState) {
    global VoiceInputContent, CursorPath, AISleepTime, PanelVisible
    if (PanelVisible)
        HideCursorPanel()
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
}

VoiceInputEffect_ProcessingDone() {
}

VoiceInputEffect_Error() {
    SetTimer((*) => VoiceFSM_Dispatch("reset"), -300)
}
