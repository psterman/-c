; PromptSyncService.ahk
; Prompt Quick-Pad / CapsLock+B settings read-write and capture-draft sync.

PSS_CursorShortcutIniPath() {
    return A_ScriptDir . "\CursorShortcut.ini"
}

PSS_IniWritePQP(Key, Value) {
    try IniWrite(Value, PSS_CursorShortcutIniPath(), "PromptQuickPad", Key)
    catch {
    }
}

PSS_WriteCapsLockBDefaultFieldsToIni(Title, Category, Tags) {
    PSS_IniWritePQP("CapsLockBDefaultTitle", Title)
    PSS_IniWritePQP("CapsLockBDefaultCategory", Category)
    PSS_IniWritePQP("CapsLockBDefaultTags", Tags)
}

PSS_IsCorruptedText(s) {
    t := String(s)
    if (t = "")
        return false
    if InStr(t, Chr(0xFFFD))
        return true
    ; Private Use Area chars often appear in mojibake artifacts.
    if RegExMatch(t, "[\x{E000}-\x{F8FF}]")
        return true
    return false
}

PSS_CleanText(v, fallback := "") {
    s := Trim(String(v))
    s := RegExReplace(s, "\R+", "`n")
    if (PSS_IsCorruptedText(s) && fallback != "")
        return fallback
    return s
}

PromptQuickPad_ReloadCapsLockBSettings() {
    global PromptQuickPad_CapsLockBSilent, PromptQuickPad_CapsLockBSilentToTemplate, PromptQuickPad_CapsLockBDefaultTitle
    global PromptQuickPad_CapsLockBDefaultCategory, PromptQuickPad_CapsLockBDefaultTags
    cfg := PSS_CursorShortcutIniPath()
    try {
        PromptQuickPad_CapsLockBSilent := (IniRead(cfg, "PromptQuickPad", "CapsLockBSilent", "0") = "1")
        PromptQuickPad_CapsLockBSilentToTemplate := (IniRead(cfg, "PromptQuickPad", "CapsLockBSilentToTemplate", "0") = "1")
        rawTitle := IniRead(cfg, "PromptQuickPad", "CapsLockBDefaultTitle", "摘录")
        rawCategory := IniRead(cfg, "PromptQuickPad", "CapsLockBDefaultCategory", "")
        rawTags := IniRead(cfg, "PromptQuickPad", "CapsLockBDefaultTags", "")
        PromptQuickPad_CapsLockBDefaultTitle := PSS_CleanText(rawTitle, "摘录")
        PromptQuickPad_CapsLockBDefaultCategory := PSS_CleanText(rawCategory, "")
        PromptQuickPad_CapsLockBDefaultTags := PSS_CleanText(rawTags, "")
    } catch {
    }
    if (Trim(PromptQuickPad_CapsLockBDefaultTitle) = "")
        PromptQuickPad_CapsLockBDefaultTitle := "摘录"
}

PromptQuickPad_SyncSilentFromWeb(msg) {
    silent := msg.Has("silent") && (msg["silent"] = true || msg["silent"] = 1)
    tpl := msg.Has("silentTpl") && (msg["silentTpl"] = true || msg["silentTpl"] = 1)
    PSS_IniWritePQP("CapsLockBSilent", silent ? "1" : "0")
    PSS_IniWritePQP("CapsLockBSilentToTemplate", tpl ? "1" : "0")
    PromptQuickPad_ReloadCapsLockBSettings()
}

PromptQuickPad_SyncCaptureDraftFromIni() {
    global PromptQuickPad_edDraftTitle, PromptQuickPad_edDraftTags, PromptQuickPad_cbDraftCategory
    global PromptQuickPad_chkCaptureSilent, PromptQuickPad_chkCaptureSilentTpl
    global PromptQuickPad_CapsLockBDefaultTitle, PromptQuickPad_CapsLockBDefaultCategory, PromptQuickPad_CapsLockBDefaultTags
    global PromptQuickPad_CapsLockBSilent, PromptQuickPad_CapsLockBSilentToTemplate

    PromptQuickPad_ReloadCapsLockBSettings()
    if PromptQuickPad_edDraftTitle != 0
        PromptQuickPad_edDraftTitle.Value := PromptQuickPad_CapsLockBDefaultTitle
    if PromptQuickPad_edDraftTags != 0
        PromptQuickPad_edDraftTags.Value := PromptQuickPad_CapsLockBDefaultTags
    if PromptQuickPad_cbDraftCategory != 0
        PromptQuickPad_cbDraftCategory.Text := (Trim(PromptQuickPad_CapsLockBDefaultCategory) = "" ? "未分类" : Trim(PromptQuickPad_CapsLockBDefaultCategory))
    if PromptQuickPad_chkCaptureSilent != 0
        PromptQuickPad_chkCaptureSilent.Value := PromptQuickPad_CapsLockBSilent ? 1 : 0
    if PromptQuickPad_chkCaptureSilentTpl != 0
        PromptQuickPad_chkCaptureSilentTpl.Value := PromptQuickPad_CapsLockBSilentToTemplate ? 1 : 0
}
