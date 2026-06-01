; CapsLock+B锛氶潤榛樺叆搴?鎴?鎵撳紑 Prompt Quick-Pad 鍐呫€屾憳褰?閲囬泦銆嶅尯锛堥€昏緫鍦?AIListPanel.ahk锛?#Requires AutoHotkey v2.0

; 璺ㄦā鍧楀叏灞€鍙橀噺榛樿鍊硷紙鐢ㄤ簬鎶戝埗鍗曟枃浠?LSP 璇姤锛涜繍琛屾椂浼氳涓昏剼鏈湡瀹炲€艰鐩栵級
global AIListPanelGUI := 0
global FloatingToolbarGUI := 0
global GuiID_ConfigGUI := 0
global GuiID_ClipboardManager := 0
global PromptTemplates := []
global TemplateIndexByID := Map()
global TemplateIndexByTitle := Map()
global TemplateIndexByArrayIndex := Map()
global AIListPanelIsVisible := false
global PromptQuickPadData := []
global g_PQPCB_CopyTicket := 0
global g_PQPCB_CopyCtx := 0

_PQPCB_CallExternal(funcName, args*) {
    try {
        return (%funcName%)(args*)
    } catch as err {
        OutputDebug("[PQP-CapsB] external call failed: " . funcName . " - " . err.Message)
    }
    return ""
}

; PromptQuickPad_ReloadCapsLockBSettings锛氳 modules\PromptSyncService.ahk

PromptQuickPad_CapsB_IsOurGuiWindow(hwnd) {
    if !hwnd
        return false
    global AIListPanelGUI, FloatingToolbarGUI, GuiID_ConfigGUI, GuiID_ClipboardManager
    try {
        pqpHwnd := _PQPCB_CallExternal("PQP_GetGuiHwnd")
        if pqpHwnd && hwnd = pqpHwnd
            return true
        if AIListPanelGUI && hwnd = AIListPanelGUI.Hwnd
            return true
        if FloatingToolbarGUI && hwnd = FloatingToolbarGUI.Hwnd
            return true
        if GuiID_ConfigGUI && hwnd = GuiID_ConfigGUI
            return true
        if GuiID_ClipboardManager && hwnd = GuiID_ClipboardManager
            return true
    } catch {
    }
    return false
}

; Read plain text directly from CF_UNICODETEXT when clipboard content is not a String.
PromptQuickPad_CapsB_ClipboardUnicodeText() {
    if !DllCall("OpenClipboard", "ptr", 0, "int")
        return ""
    hData := 0
    pData := 0
    try {
        hData := DllCall("GetClipboardData", "uint", 13, "ptr")  ; CF_UNICODETEXT
        if !hData
            return ""
        pData := DllCall("GlobalLock", "ptr", hData, "ptr")
        if !pData
            return ""
        return StrGet(pData, "UTF-16")
    } catch {
        return ""
    } finally {
        if pData && hData
            DllCall("GlobalUnlock", "ptr", hData)
        DllCall("CloseClipboard")
    }
}

PromptQuickPad_CapsB_CopySelection(&outText) {
    global CoreAsyncStrictMode
    try {
        if CoreAsyncStrictMode
            NMER_AsyncLog(Nmer_DebugPath("core_async_guard.log"), "[" . A_Now . "][legacy_sync_path_hit] PromptQuickPad_CapsB_CopySelection`r`n")
    } catch {
    }
    outText := ""
    fg := DllCall("GetForegroundWindow", "ptr")
    global PromptQuickPad_PasteTargetHwnd
    if PromptQuickPad_CapsB_IsOurGuiWindow(fg) {
        tgt := PromptQuickPad_PasteTargetHwnd
        if !tgt || !DllCall("IsWindow", "ptr", tgt) || PromptQuickPad_CapsB_IsOurGuiWindow(tgt) {
            TrayTip("璇峰厛鍒囧埌瑕佹憳褰曠殑搴旂敤閲岄€変腑鏂囧瓧锛堢劍鐐瑰湪鏈潰鏉挎椂鏃犳硶浠庡叾瀹冪獥鍙ｅ鍒讹級", "Prompt Quick-Pad", "Icon! 1")
            return false
        }
        try {
            if FuncExists("FocusBroker_Request")
                FocusBroker_Request("PromptQuickPad", tgt, 45, "capslock_b_sync_copy", 120)
            else
                DllCall("SetForegroundWindow", "ptr", tgt, "int")
            WinWaitActive("ahk_id " . tgt, , 0.6)
        } catch {
        }
        DllCall("Sleep", "uint", 120)
    } else {
        DllCall("Sleep", "uint", 80)
    }
    oldClip := ClipboardAll()
    try {
        if CoreAsyncStrictMode {
            ; Legacy sync path is soft-disabled in strict mode: avoid ClipWait-style blocking.
            return false
        }
        A_Clipboard := ""
        SendInput("^c")
        Sleep(80)
        DllCall("Sleep", "uint", 60)
        raw := ""
        try
            raw := A_Clipboard
        catch
            return false
        if Trim(String(raw), " `t`r`n") = "" {
            Send("^c")
            Sleep(90)
            try raw := A_Clipboard
            catch {
                raw := ""
            }
        }
        if Trim(String(raw), " `t`r`n") = "" {
            SendEvent("^c")
            Sleep(110)
            try raw := A_Clipboard
            catch {
                raw := ""
            }
        }
        if !(raw is String) {
            try
                raw := String(raw)
            catch
                raw := ""
        }
        if Trim(raw, " `t`r`n") = "" {
            plain := PromptQuickPad_CapsB_ClipboardUnicodeText()
            if plain != ""
                raw := plain
        }
        if Trim(raw, " `t`r`n") = ""
            return false
        outText := Trim(raw, " `t`r`n")
        return true
    } finally {
        try
            A_Clipboard := oldClip
        catch {
        }
    }
}

PromptQuickPad_CapsB_BeginAsyncCopy(fgHwnd, doneCb) {
    global g_PQPCB_CopyTicket, g_PQPCB_CopyCtx, PromptQuickPad_PasteTargetHwnd
    g_PQPCB_CopyTicket += 1
    ticket := g_PQPCB_CopyTicket
    oldClip := ClipboardAll()
    target := 0
    if PromptQuickPad_CapsB_IsOurGuiWindow(fgHwnd) {
        tgt := PromptQuickPad_PasteTargetHwnd
        if (!tgt || !DllCall("IsWindow", "ptr", tgt) || PromptQuickPad_CapsB_IsOurGuiWindow(tgt)) {
            try doneCb.Call(false, "", "no_target")
            return
        }
        target := tgt
    }
    pollFn := 0
    ctx := Map("ticket", ticket, "start", A_TickCount, "tries", 0, "oldClip", oldClip, "target", target, "done", doneCb, "inFlight", false, "timerFunc", 0)
    pollFn := (*) => PromptQuickPad_CapsB_CopyPoll(ctx)
    ctx["timerFunc"] := pollFn
    g_PQPCB_CopyCtx := ctx
    try A_Clipboard := ""
    catch {
    }
    if (target) {
        try {
            if FuncExists("FocusBroker_Request")
                FocusBroker_Request("PromptQuickPad", target, 45, "capslock_b_copy", 120)
            else
                DllCall("SetForegroundWindow", "ptr", target, "int")
        } catch {
        }
    }
    SetTimer(pollFn, 40)
}

PromptQuickPad_CapsB_CopyFinish(ctx, ok, text := "", reason := "") {
    global g_PQPCB_CopyCtx
    if !(ctx is Map) || !(g_PQPCB_CopyCtx is Map)
        return
    if (g_PQPCB_CopyCtx != ctx)
        return
    fn := ctx["timerFunc"]
    try SetTimer(fn, 0)
    doneCb := ctx["done"]
    oldClip := ctx["oldClip"]
    try A_Clipboard := oldClip
    catch {
    }
    g_PQPCB_CopyCtx := 0
    if IsObject(doneCb) {
        try doneCb.Call(ok ? true : false, String(text), String(reason))
    }
}

PromptQuickPad_CapsB_CopyPoll(ctx, *) {
    global g_PQPCB_CopyCtx, g_PQPCB_CopyTicket
    if !(ctx is Map)
        return
    fn := ctx["timerFunc"]
    if !(g_PQPCB_CopyCtx is Map) || (g_PQPCB_CopyCtx != ctx) || (Integer(ctx["ticket"]) != Integer(g_PQPCB_CopyTicket)) {
        try SetTimer(fn, 0)
        return
    }
    if ctx["inFlight"] {
        try SetTimer(fn, -35)
        return
    }
    ctx["inFlight"] := true
    if ((A_TickCount - Integer(ctx["start"])) > 2300) {
        PromptQuickPad_CapsB_CopyFinish(ctx, false, "", "timeout")
        return
    }
    tries := Integer(ctx["tries"])
    if (tries = 0)
        SendInput("^c")
    else if (tries = 4)
        Send("^c")
    else if (tries = 8)
        SendEvent("^c")
    ctx["tries"] := tries + 1
    raw := ""
    try raw := A_Clipboard
    catch {
        raw := ""
    }
    if !(raw is String) {
        try raw := String(raw)
        catch {
            raw := ""
        }
    }
    if (Trim(raw, " `t`r`n") = "") {
        plain := PromptQuickPad_CapsB_ClipboardUnicodeText()
        if (Trim(plain, " `t`r`n") != "")
            raw := plain
    }
    if (Trim(raw, " `t`r`n") != "") {
        PromptQuickPad_CapsB_CopyFinish(ctx, true, Trim(raw, " `t`r`n"), "ok")
        return
    }
    ctx["inFlight"] := false
    try SetTimer(fn, -90)
}

PromptQuickPad_AppendCapsLockBToTemplateLibrary(content) {
    global PromptTemplates, TemplateIndexByID, TemplateIndexByTitle, TemplateIndexByArrayIndex
    global PromptQuickPad_CapsLockBDefaultTitle, PromptQuickPad_CapsLockBDefaultCategory
    global AIListPanelIsVisible
    title := Trim(PromptQuickPad_CapsLockBDefaultTitle)
    if title = ""
        title := "鎽樺綍"
    cat := Trim(PromptQuickPad_CapsLockBDefaultCategory)
    if cat = ""
        cat := "自定义"
    NewID := "template_" . A_TickCount
    NewTemplate := { ID: NewID, Title: title, Content: content, Icon: "", Category: cat }
    PromptTemplates.Push(NewTemplate)
    TemplateIndexByID[NewID] := NewTemplate
    Key := NewTemplate.Category . "|" . NewTemplate.Title
    TemplateIndexByTitle[Key] := NewTemplate
    TemplateIndexByArrayIndex[NewID] := PromptTemplates.Length
    _PQPCB_CallExternal("InvalidateTemplateCache")
    try {
        _PQPCB_CallExternal("SavePromptTemplates")
    } catch as err {
        TrayTip("淇濆瓨妯℃澘搴撳け璐ワ細" . err.Message, "Prompt Quick-Pad", "Iconx 1")
        return false
    }
    if AIListPanelIsVisible
        _PQPCB_CallExternal("PromptQuickPad_RefreshListView")
    try
        _PQPCB_CallExternal("RefreshPromptListView")
    catch {
    }
    tip := "已静默保存到模板库（PromptTemplates.ini）"
    if StrLen(title) <= 24
        tip .= "`n「" . title . "」"
    else
        tip .= "`n「" . SubStr(title, 1, 24) . "…」"
    TrayTip(tip, "Prompt Quick-Pad", "Iconi 1")
    return true
}

PromptQuickPad_HandleCapsLockB() {
    global PromptQuickPad_CapsLockBSilent, PromptQuickPad_CapsLockBSilentToTemplate
    global PromptQuickPad_CapsLockBDefaultTitle, PromptQuickPad_CapsLockBDefaultCategory, PromptQuickPad_CapsLockBDefaultTags
    global PromptQuickPadData, AIListPanelIsVisible, PromptQuickPad_PasteTargetHwnd
    PromptQuickPad_ReloadCapsLockBSettings()
    fg := DllCall("GetForegroundWindow", "ptr")
    if !PromptQuickPad_CapsB_IsOurGuiWindow(fg)
        PromptQuickPad_PasteTargetHwnd := fg
    PromptQuickPad_CapsB_BeginAsyncCopy(fg, (ok, t, reason) => PromptQuickPad_HandleCapsLockB_CopyDone(ok, t, reason, fg))
    return
    /*
    if !PromptQuickPad_CapsB_CopySelection(&t) {
        if !PromptQuickPad_CapsB_IsOurGuiWindow(fg)
            TrayTip("鏈幏鍙栧埌閫変腑鏂囨湰锛堣纭宸查€変腑鏂囧瓧锛岄儴鍒嗙▼搴忛渶鍏?Ctrl+C锛?, "Prompt Quick-Pad", "Iconi 1")
        return
    }
    if PromptQuickPad_CapsLockBSilent {
        if PromptQuickPad_CapsLockBSilentToTemplate {
            PromptQuickPad_AppendCapsLockBToTemplateLibrary(t)
            return
        }
        _PQPCB_CallExternal("PromptQuickPad_LoadFromDisk")
        title := Trim(PromptQuickPad_CapsLockBDefaultTitle)
        if title = ""
            title := "鎽樺綍"
        cat := Trim(PromptQuickPad_CapsLockBDefaultCategory)
        tags := Trim(PromptQuickPad_CapsLockBDefaultTags)
        normalized := _PQPCB_CallExternal("PromptQuickPad_NormalizeEntry", Map("title", title, "tags", tags, "content", t, "category", cat, "hotkey", ""))
        if normalized is Map
            PromptQuickPadData.Push(normalized)
        else
            PromptQuickPadData.Push(Map("title", title, "tags", tags, "content", t, "category", cat, "hotkey", ""))
        _PQPCB_CallExternal("PromptQuickPad_SaveToDisk")
        if AIListPanelIsVisible
            _PQPCB_CallExternal("PromptQuickPad_RefreshListView")
        TrayTip("已静默保存到用户库（prompts.json）", "Prompt Quick-Pad", "Iconi 1")
        return
    }
    _PQPCB_CallExternal("PromptQuickPad_OpenCaptureDraft", t, true)
    */
}

PromptQuickPad_HandleCapsLockB_CopyDone(ok, t, reason, fg) {
    global PromptQuickPad_CapsLockBSilent, PromptQuickPad_CapsLockBSilentToTemplate
    global PromptQuickPad_CapsLockBDefaultTitle, PromptQuickPad_CapsLockBDefaultCategory, PromptQuickPad_CapsLockBDefaultTags
    global PromptQuickPadData, AIListPanelIsVisible
    if !ok {
        if !PromptQuickPad_CapsB_IsOurGuiWindow(fg)
            TrayTip("鏈幏鍙栧埌閫変腑鏂囨湰锛岃纭宸查€変腑鏂囧瓧", "Prompt Quick-Pad", "Iconi 1")
        return
    }
    if PromptQuickPad_CapsLockBSilent {
        if PromptQuickPad_CapsLockBSilentToTemplate {
            PromptQuickPad_AppendCapsLockBToTemplateLibrary(t)
            return
        }
        _PQPCB_CallExternal("PromptQuickPad_LoadFromDisk")
        title := Trim(PromptQuickPad_CapsLockBDefaultTitle)
        if title = ""
            title := "鎽樺綍"
        cat := Trim(PromptQuickPad_CapsLockBDefaultCategory)
        tags := Trim(PromptQuickPad_CapsLockBDefaultTags)
        normalized := _PQPCB_CallExternal("PromptQuickPad_NormalizeEntry", Map("title", title, "tags", tags, "content", t, "category", cat, "hotkey", ""))
        if normalized is Map
            PromptQuickPadData.Push(normalized)
        else
            PromptQuickPadData.Push(Map("title", title, "tags", tags, "content", t, "category", cat, "hotkey", ""))
        _PQPCB_CallExternal("PromptQuickPad_SaveToDisk")
        if AIListPanelIsVisible
            _PQPCB_CallExternal("PromptQuickPad_RefreshListView")
        TrayTip("已静默保存到用户库（prompts.json）", "Prompt Quick-Pad", "Iconi 1")
        return
    }
    _PQPCB_CallExternal("PromptQuickPad_OpenCaptureDraft", t, true)
}
