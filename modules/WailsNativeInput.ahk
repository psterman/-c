#Requires AutoHotkey v2.0

; WailsNativeInput — WebView2 无边框窗体上中文 IME 不可靠，改用系统原生 Edit 输入并同步到命令栏

global WailsInputUseNativeEdit := false
global g_WailsNative_Gui := 0
global g_WailsNative_Edit := 0
global g_WailsNative_SyncTimer := 0

WailsNative_GetWailsHwnd() {
    if (IsSet(CommandPaletteUseWebView) && CommandPaletteUseWebView && FuncExists("CommandPalette_GetGuiHwnd")) {
        h := CommandPalette_GetGuiHwnd()
        if h
            return h
    }
    for q in ["ahk_exe nmer-wails-input.exe", "NMER Wails Input"] {
        if WinExist(q)
            return WinExist(q)
    }
    return 0
}

WailsNative_HideWebInput() {
    if (IsSet(CommandPaletteUseWebView) && CommandPaletteUseWebView)
        return
    js := "document.body.classList.add('native-input-mode')"
    if FuncExists("WailsWhisper_RunJsInInputHost")
        WailsWhisper_RunJsInInputHost(js)
}

WailsNative_SyncToWeb(*) {
    global g_WailsNative_Edit, g_WailsNative_SyncTimer
    g_WailsNative_SyncTimer := 0
    if !IsObject(g_WailsNative_Edit)
        return
    text := g_WailsNative_Edit.Value
    if (IsSet(CommandPaletteUseWebView) && CommandPaletteUseWebView && FuncExists("CommandPalette_SetInputText")) {
        CommandPalette_SetInputText(text)
        return
    }
    if !FuncExists("WailsWhisper_JsonStr")
        return
    js := "window.nmerVoice?.setInputText?.(" . WailsWhisper_JsonStr(text) . ")"
    if FuncExists("WailsWhisper_RunJsInInputHost")
        WailsWhisper_RunJsInInputHost(js)
}

WailsNative_ScheduleSync() {
    global g_WailsNative_SyncTimer
    if g_WailsNative_SyncTimer
        return
    g_WailsNative_SyncTimer := 1
    SetTimer(WailsNative_SyncToWeb, -80)
}

WailsNative_AlignWailsBelowBar() {
    wailsHwnd := WailsNative_GetWailsHwnd()
    if !wailsHwnd || !IsObject(g_WailsNative_Gui)
        return
    try {
        barHwnd := g_WailsNative_Gui.Hwnd
        WinGetPos(&bx, &by, &bw, &bh, "ahk_id " . barHwnd)
        if (bw < 400)
            bw := 900
        WinMove(bx, by + bh + 6, bw, , "ahk_id " . wailsHwnd)
    } catch {
    }
}

WailsNative_ShowInputBar() {
    global g_WailsNative_Gui, g_WailsNative_Edit
    if !WailsInputUseNativeEdit
        return false

    barW := 900
    barX := (A_ScreenWidth - barW) // 2
    if (barX < 8)
        barX := 8
    barY := Round(A_ScreenHeight * 0.32)

    if IsObject(g_WailsNative_Gui) {
        try g_WailsNative_Gui.Show()
        try g_WailsNative_Edit.Focus()
        WailsNative_AlignWailsBelowBar()
        WailsNative_HideWebInput()
        WailsNative_ApplyIME()
        return true
    }

    g_WailsNative_Gui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound", "NMER 命令栏输入")
    g_WailsNative_Gui.BackColor := "0a0a0a"
    g_WailsNative_Gui.SetFont("s11 cF5F5F5", "Segoe UI")
    g_WailsNative_Gui.Add("Text", "x12 y6 w80 h18 cFF9933", "命令输入")
    g_WailsNative_Edit := g_WailsNative_Gui.Add("Edit", "x12 y26 w776 h36 +WantTab -Wrap vWailsNativeEdit", "")
    btnVoice := g_WailsNative_Gui.Add("Button", "x800 y28 w88 h32", "🎤 语音")
    btnVoice.OnEvent("Click", WailsNative_VoiceClick)
    g_WailsNative_Edit.OnEvent("Change", WailsNative_ScheduleSync)
    g_WailsNative_Gui.OnEvent("Close", WailsNative_HideInputBar)
    g_WailsNative_Gui.Show("x" . barX . " y" . barY . " w" . barW . " h64")
    Sleep(80)
    WailsNative_AlignWailsBelowBar()
    WailsNative_HideWebInput()
    WailsNative_ApplyIME()
    try g_WailsNative_Edit.Focus()
    SetTimer(WailsNative_AlignWailsBelowBar, -200)
    return true
}

WailsNative_ApplyIME() {
    if !IsObject(g_WailsNative_Gui)
        return
    try {
        if FuncExists("ApplyChineseIMEConversionToHwnd")
            ApplyChineseIMEConversionToHwnd(g_WailsNative_Gui.Hwnd)
    } catch {
    }
    SetTimer(WailsNative_ApplyIME, -180)
    SetTimer(WailsNative_ApplyIME, -520)
}

WailsNative_HideInputBar(*) {
    global g_WailsNative_Gui, g_WailsNative_Edit
    if IsObject(g_WailsNative_Gui) {
        try g_WailsNative_Gui.Hide()
    }
    g_WailsNative_Edit := 0
}

WailsNative_VoiceClick(*) {
    if FuncExists("WailsWhisper_OnInputActivated")
        WailsWhisper_OnInputActivated()
}

WailsNative_OnWailsActivated() {
    if (IsSet(CommandPaletteUseWebView) && CommandPaletteUseWebView && FuncExists("CommandPalette_Show")) {
        if WailsInputUseNativeEdit
            SetTimer(WailsNative_ShowInputBar, -120)
        return
    }
    if WailsInputUseNativeEdit {
        SetTimer(WailsNative_ShowInputBar, -120)
        return
    }
    WailsNative_HideInputBar()
    if FuncExists("WailsInput_FocusWebInput")
        SetTimer(WailsInput_FocusWebInput, -150)
}

WailsNative_GetInputText() {
    if IsObject(g_WailsNative_Edit)
        return Trim(g_WailsNative_Edit.Value)
    return ""
}

WailsNative_SetInputText(text) {
    global g_WailsNative_Edit
    if !WailsInputUseNativeEdit || !IsObject(g_WailsNative_Edit)
        return false
    try g_WailsNative_Edit.Value := String(text)
    WailsNative_ScheduleSync()
    return true
}
