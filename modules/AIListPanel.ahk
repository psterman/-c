; ======================================================================================================================
; Prompt Quick-Pad锛堝師 AI 鍔╂墜鍏ュ彛锛夛細鎻愮ず璇嶅揩鎹疯褰曚笌绮樿创
; 鏁版嵁锛欰_ScriptDir "\prompts.json" 浠呯敤鎴锋潯鐩?[{title, tags, content, category?}]
; 鍒楄〃灞曠ず = 璁剧疆涓揩鎹蜂笁椤?+ PromptTemplates + json 鍚堝苟
; 瀵瑰淇濈暀锛歋howAIListPanel / HideAIListPanel / InitAIListPanel 鍙?CursorHelper 浣跨敤鐨勫叏灞€鍙橀噺鍚?
; ======================================================================================================================

#Requires AutoHotkey v2.0

global AIListPanelGUI := 0
global AIListPanelIsVisible := false
global AIListPanelItems := []  ; 鍏煎淇濈暀锛堜笉鍐嶄娇鐢?AI 寮曟搸椤癸級
global AIListPanelHoveredIndex := 0
global AIListPanelDragging := false
global AIListPanelDragStartX := 0
global AIListPanelDragStartY := 0
global AIListPanelWindowX := 0
global AIListPanelWindowY := 0
global AIListPanelWindowW := 520
global AIListPanelWindowH := 560
global AIListPanelIsMinimized := false
global AIListPanelSearchInput := 0
global AIListPanelEnterHotkey := 0
global AIListPanelEscHotkey := 0
global AIListPanelUserMoving := false
global AIListPanelIsResizing := false

; 浠ヤ笅鍏ㄥ眬浠呬负鍏煎鏃?ini 閿笌鑴氭湰涓彲鑳界殑寮曠敤锛屽浐瀹氫负銆岀珫鎺掋€嶉€昏緫
global AIListPanelIconOnlyMode := false
global AIListPanelIconModeX := 0
global AIListPanelIconModeY := 0
global AIListPanelIconModeW := 400
global AIListPanelIconModeH := 100
global AIListPanelLastWidth := 0
global AIListPanelLastRows := 0
global AIListPanelTitleBar := 0
global AIListPanelToggleBtn := 0
global AIListPanelSearchBtn := 0
global AIListPanelSelectedEngines := []
global AIListPanelCheckboxes := Map()
global AIListPanelUserResizing := false

global PromptQuickPadData := []
global PromptQuickPadFilteredIdx := []
global PromptQuickPadListLV := 0
global PromptQuickPadStatusText := 0
global PromptQuickPadSearchDebounce := 0
global PromptQuickPadCaptureHotkeyObj := 0
global PromptQuickPadMergedSnapshot := []  ; 褰撳墠瀹屾暣鍚堝苟鍒楄〃锛堜笌 FilteredIdx 涓嬫爣瀵瑰簲锛?
global PromptQuickPadSelectedCategory := "全部"
global PromptQuickPadCategoryStrip := []  ; 鍒嗙被鏍囩鎺т欢锛屼究浜庨攢姣?
global PromptQuickPadCategoryCtrlByName := Map()
global PromptQuickPadLastCategorySig := ""
global PromptQuickPadCategoryStripHeight := 32
global PromptQuickPadDragBar := 0  ; 淇濈暀鍙橀噺锛涘凡鏀圭敤鏍囧噯鏍囬鏍忥紝涓嶅啀鍒涘缓鎷栧姩鏉?
global PromptQuickPad_PasteTargetHwnd := 0  ; 鎵撳紑闈㈡澘鍓嶇殑鍓嶅彴绐楀彛锛岀敤浜庣矘璐村洖鐩爣
global PromptQuickPadBtnImport := 0
global PromptQuickPadBtnExport := 0
global PromptQuickPadBtnJsonHelp := 0
global PromptQuickPadBtnPinTop := 0
global PromptQuickPad_PinTop := true
global PromptQuickPad_LinkBarHeight := 22
global PromptQuickPadCtxMenuGUI := 0
global PromptQuickPadCtxMenuSel := 0
global PromptQuickPadCtxHoverTimer := 0
global PromptQuickPad_CaptureChromeVisible := false
global PromptQuickPad_CaptureExpanded := false
global PromptQuickPadCaptureToggle := 0
global PromptQuickPadLblDraftTitle := 0
global PromptQuickPad_edDraftTitle := 0
global PromptQuickPadLblDraftCat := 0
global PromptQuickPad_cbDraftCategory := 0
global PromptQuickPadLblDraftTags := 0
global PromptQuickPad_edDraftTags := 0
global PromptQuickPad_chkCaptureSilent := 0
global PromptQuickPad_chkCaptureSilentTpl := 0
global PromptQuickPadLblDraftBody := 0
global PromptQuickPad_edDraftContent := 0
global PromptQuickPad_btnDraftLoad := 0
global PromptQuickPad_btnDraftSave := 0
global PromptQuickPad_btnDraftClear := 0
global PromptQuickPadLblListFilter := 0
global PromptQuickPad_PendingCaptureText := ""
global PromptQuickPad_WebSearchKeyword := ""

AIListPanelColors := {
    Background: "1e1e1e",
    Border: "3c3c3c",
    Text: "cccccc",
    TextHover: "ffffff",
    ItemBg: "252526",
    ItemHover: "37373d",
    ItemActive: "007acc",
    ItemBorder: "3c3c3c",
    LoadingBg: "2d2d30",
    LoadingText: "007acc",
    CategoryTabActive: "ff7700",
    CategoryTabInactive: "363636",
    MenuBg: "1a1a1a",
    AccentOrange: "ff9933",
    PopupBg: "1a1a1a",
    PopupTextBright: "ffffff",
    PopupEditBg: "252526",
    PopupEditText: "f0f0f0"
}

PromptQuickPad_JsonPath() => Nmer_PromptsJsonPath()

PromptQuickPad_ShouldUseWebView() {
    static ready := false
    static useWeb := true
    if !ready {
        ready := true
        cfg := Nmer_ResolveConfigFile()
        try {
            s := IniRead(cfg, "PromptQuickPad", "UseWebView", "1")
        } catch {
            s := "1"
        }
        useWeb := (s != "0" && StrLower(s) != "false")
    }
    return useWeb
}

PromptQuickPad_GetHostHwnd() {
    global AIListPanelGUI
    if PromptQuickPad_ShouldUseWebView() {
        h := PQP_GetGuiHwnd()
        if h
            return h
    }
    if AIListPanelGUI != 0 {
        try return AIListPanelGUI.Hwnd
    }
    return 0
}

PromptQuickPad_GetFollowGui() {
    global AIListPanelGUI
    if PromptQuickPad_ShouldUseWebView() {
        g := PQP_GetGui()
        if g
            return g
    }
    return AIListPanelGUI
}

PromptQuickPad_PushDataToWeb(msgType := "init") {
    global PromptQuickPadMergedSnapshot, PromptQuickPadSelectedCategory, PromptQuickPadData
    global PromptQuickPad_CaptureChromeVisible, PromptQuickPad_CaptureExpanded
    global PromptQuickPad_PinTop
    global PromptQuickPad_CapsLockBSilent, PromptQuickPad_CapsLockBSilentToTemplate
    global PromptQuickPad_CapsLockBDefaultTitle, PromptQuickPad_CapsLockBDefaultCategory, PromptQuickPad_CapsLockBDefaultTags
    if !PromptQuickPad_ShouldUseWebView() || !PQP_IsReady()
        return
    ; 娉細PromptQuickPadData 闇€鐢辫皟鐢ㄦ柟鎻愬墠 LoadFromDisk()锛圧efreshListView 鎴?ApplyWebCaptureDraft 閲屽凡璋冪敤锛?
    merged := PromptQuickPad_BuildMergedList()
    PromptQuickPad_ValidateSelectedCategory(merged)
    needle := PromptQuickPad_WebSearchKeyword
    items := []
    PromptQuickPadMergedSnapshot := merged
    PromptQuickPadFilteredIdx := []
    for index, entry in merged {
        if !PromptQuickPad_CategoryMatches(entry, PromptQuickPadSelectedCategory)
            continue
        if !PromptQuickPad_MatchFilter(entry, needle)
            continue
        PromptQuickPadFilteredIdx.Push(index)
        items.Push(Map(
            "mergedIndex", index,
            "title", entry.Has("title") ? entry["title"] : "",
            "category", entry.Has("category") ? entry["category"] : "",
            "hotkey", entry.Has("hotkey") ? entry["hotkey"] : "",
            "preview", PromptQuickPad_MakePreview(entry.Has("content") ? entry["content"] : ""),
            "content", entry.Has("content") ? entry["content"] : "",
            "source", entry.Has("source") ? entry["source"] : ""
        ))
    }
    catDisp := PromptQuickPadSelectedCategory
    if StrLen(catDisp) > 18
        catDisp := SubStr(catDisp, 1, 18) . "..."
    statusLine := "共 " . merged.Length . " 条 · prompts.json " . PromptQuickPadData.Length . " 条`n「" . catDisp . "」显示 " . items.Length . " 条 · 双击粘贴 · 右键菜单"
    categories := PromptQuickPad_UniqueCategoryTabs(merged)
    PromptQuickPad_ReloadCapsLockBSettings()
    draftMap := Map(
        "title", PromptQuickPad_CapsLockBDefaultTitle,
        "category", (Trim(PromptQuickPad_CapsLockBDefaultCategory) = "" ? "未分类" : PromptQuickPad_CapsLockBDefaultCategory),
        "tags", PromptQuickPad_CapsLockBDefaultTags,
        "silent", PromptQuickPad_CapsLockBSilent ? true : false,
        "silentTpl", PromptQuickPad_CapsLockBSilentToTemplate ? true : false,
        "body", ""
    )
    pqpSpec := "[]"
    try {
        if IsSet(_VK_SceneCtxMenuItemsJson)
            pqpSpec := _VK_SceneCtxMenuItemsJson("prompts")
    } catch {
    }
    pqpItems := []
    try pqpItems := Jxon_Load(pqpSpec)
    catch {
    }
    payload := Map(
        "type", msgType,
        "items", items,
        "categories", categories,
        "selectedCategory", PromptQuickPadSelectedCategory,
        "keyword", needle,
        "statusLine", statusLine,
        "pinTop", PromptQuickPad_PinTop ? true : false,
        "captureVisible", PromptQuickPad_CaptureChromeVisible ? true : false,
        "captureExpanded", PromptQuickPad_CaptureExpanded ? true : false,
        "captureDraft", draftMap,
        "pqpCtxMenuSpec", pqpItems
    )
    try PQP_SendToWeb(payload)
    catch {
    }
}

PQP_SendCaptureOpen(initialText := "", expanded := true) {
    global PromptQuickPad_CaptureChromeVisible, PromptQuickPad_CaptureExpanded
    PromptQuickPad_ReloadCapsLockBSettings()
    m := Map(
        "type", "captureOpen",
        "text", initialText,
        "expanded", expanded ? true : false,
        "chromeVisible", PromptQuickPad_CaptureChromeVisible ? true : false
    )
    try PQP_SendToWeb(m)
    catch {
    }
}

PromptQuickPad_ProcessWebMessage(msg) {
    global PromptQuickPadSelectedCategory
    switch msg["type"] {
        case "paste":
            if msg.Has("mergedIndex")
                PromptQuickPad_PasteByMergedIndex(Integer(msg["mergedIndex"]))
        case "pasteByIndex":
            if msg.Has("index")
                PromptQuickPad_PasteByFilteredIndex(Integer(msg["index"]))
        case "delete":
            if msg.Has("mergedIndex")
                PromptQuickPad_DeleteByMergedIndex(Integer(msg["mergedIndex"]))
        case "edit":
            if msg.Has("mergedIndex")
                PromptQuickPad_EditItemByMergedIndex(Integer(msg["mergedIndex"]))
        case "view":
            if msg.Has("mergedIndex")
                PromptQuickPad_ViewItemByMergedIndex(Integer(msg["mergedIndex"]))
        case "import":
            PromptQuickPad_DoImport()
        case "export":
            PromptQuickPad_DoExport()
        case "jsonHelp":
            PromptQuickPad_ShowJsonFormatHelp()
        case "setCategory":
            if msg.Has("category") {
                PromptQuickPadSelectedCategory := msg["category"]
                PromptQuickPad_PushDataToWeb("searchResult")
            }
        case "togglePinTop":
            PromptQuickPad_TogglePinTopWeb()
        case "requestHide":
            HideAIListPanel()
        case "captureSave":
            PromptQuickPad_SaveDraftFromWeb(msg)
        case "captureLoadSelected":
            if msg.Has("mergedIndex")
                PromptQuickPad_LoadDraftFromMergedIndex(Integer(msg["mergedIndex"]))
        case "captureClear":
            PromptQuickPad_ClearCaptureDraftWeb()
        case "captureSilentSync":
            PromptQuickPad_SyncSilentFromWeb(msg)
        case "itemEditSave":
            PromptQuickPad_SaveItemEditFromWeb(msg)
        case "syncExport":
            try PQP_SendToWeb(Map("type", "syncExportResult", "snapshot", PromptQuickPad_SyncExportSnapshot()))
            catch {
            }
        case "syncImport":
            snap := msg.Has("snapshot") ? msg["snapshot"] : 0
            merge := !(msg.Has("merge") && !msg["merge"])
            ok := PromptQuickPad_SyncImportSnapshot(snap, merge)
            try PQP_SendToWeb(Map("type", "syncImportResult", "ok", ok ? true : false))
            catch {
            }
        case "syncGetSince":
            since := msg.Has("since") ? String(msg["since"]) : ""
            arr := PromptQuickPad_SyncGetEntriesSince(since)
            try PQP_SendToWeb(Map("type", "syncSinceResult", "since", since, "entries", arr))
            catch {
            }
        case "pqpScCtxCmd":
            cmdId0 := msg.Has("cmdId") ? String(msg["cmdId"]) : ""
            mi0 := msg.Has("mergedIndex") ? Integer(msg["mergedIndex"]) : 0
            if (cmdId0 = "" || mi0 < 1)
                return
            merged0 := PromptQuickPad_BuildMergedList()
            if mi0 > merged0.Length
                return
            entry0 := merged0[mi0]
            title0 := entry0.Has("title") ? entry0["title"] : ""
            content0 := entry0.Has("content") ? entry0["content"] : ""
            m0 := Map(
                "Title", title0,
                "Content", content0,
                "DataType", "template",
                "OriginalDataType", "template",
                "Source", "pqp",
                "PromptMergedIndex", mi0,
                "ClipboardId", 0,
                "HubSegIndex", -1
            )
            try SC_ExecuteContextCommand(cmdId0, 0, m0)
            catch as err {
                OutputDebug("[PQP] pqpScCtxCmd: " . err.Message)
            }
            return
        case "openWindowsRecycleBin":
            SCWV_OpenWindowsRecycleBinFolder()
            return
        default:
            OutputDebug("[PQP] Unknown web msg: " . msg["type"])
    }
}

PromptQuickPad_TogglePinTopWeb() {
    global PromptQuickPad_PinTop
    PromptQuickPad_PinTop := !PromptQuickPad_PinTop
    PromptQuickPad_SavePinToIni()
    PQP_ApplyPinTopFromIni()
    PromptQuickPad_PushDataToWeb("searchResult")
}

PromptQuickPad_SaveDraftFromWeb(msg) {
    global PromptQuickPadData
    title := msg.Has("title") ? PromptQuickPad_CleanText(msg["title"]) : ""
    if title = ""
        title := "未命名"
    tags := msg.Has("tags") ? PromptQuickPad_CleanText(msg["tags"]) : ""
    body := msg.Has("body") ? Trim(PromptQuickPad_CleanText(msg["body"]), " `t`r`n") : ""
    cat := msg.Has("category") ? PromptQuickPad_CleanText(msg["category"]) : ""
    if body = "" {
        TrayTip("正文不能为空", "Prompt Quick-Pad", "Icon! 1")
        return
    }
    if cat = ""
        cat := "未分类"
    PromptQuickPad_LoadFromDisk()
    PromptQuickPadData.Push(PromptQuickPad_NormalizeEntry(Map("title", title, "tags", tags, "content", body, "category", cat, "hotkey", "")))
    PromptQuickPad_SaveToDisk()
    PromptQuickPad_RefreshListView()
    m := Map("type", "captureDraftFill", "title", title, "category", cat, "tags", tags, "body", body)
    try PQP_SendToWeb(m)
    catch {
    }
    TrayTip("已保存到 prompts.json", "Prompt Quick-Pad", "Iconi 1")
}
PromptQuickPad_ClearCaptureDraftWeb() {
    PromptQuickPad_SyncCaptureDraftFromIni()
    PQP_SendCaptureOpen("", true)
}

PromptQuickPad_LoadDraftFromMergedIndex(mi) {
    merged := PromptQuickPad_BuildMergedList()
    if mi < 1 || mi > merged.Length
        return
    entry := merged[mi]
    if !(entry is Map)
        return
    PromptQuickPad_ReloadCapsLockBSettings()
    global PromptQuickPad_CapsLockBDefaultTitle, PromptQuickPad_CapsLockBDefaultCategory, PromptQuickPad_CapsLockBDefaultTags
    PromptQuickPad_CapsLockBDefaultTitle := entry.Has("title") ? entry["title"] : ""
    PromptQuickPad_CapsLockBDefaultCategory := entry.Has("category") ? entry["category"] : ""
    PromptQuickPad_CapsLockBDefaultTags := entry.Has("tags") ? entry["tags"] : ""
    PSS_WriteCapsLockBDefaultFieldsToIni(PromptQuickPad_CapsLockBDefaultTitle, PromptQuickPad_CapsLockBDefaultCategory, PromptQuickPad_CapsLockBDefaultTags)
    PromptQuickPad_ReloadCapsLockBSettings()
    body := entry.Has("content") ? entry["content"] : ""
    m := Map("type", "captureDraftFill", "title", PromptQuickPad_CapsLockBDefaultTitle,
        "category", (Trim(PromptQuickPad_CapsLockBDefaultCategory) = "" ? "未分类" : PromptQuickPad_CapsLockBDefaultCategory),
        "tags", PromptQuickPad_CapsLockBDefaultTags, "body", body)
    try PQP_SendToWeb(m)
    catch {
    }
}

PromptQuickPad_PasteByMergedIndex(mi) {
    merged := PromptQuickPad_BuildMergedList()
    if mi < 1 || mi > merged.Length
        return
    entry := merged[mi]
    content := entry.Has("content") ? entry["content"] : ""
    if content = ""
        return
    try A_Clipboard := ""
    catch {
    }
    try A_Clipboard := content
    catch {
        TrayTip("复制失败", "Prompt Quick-Pad", "Iconx 1")
        return
    }
    if !ClipWait(0.12) {
        TrayTip("剪贴板写入失败", "Prompt Quick-Pad", "Iconx 1")
        return
    }
    try HideAIListPanel()
    catch {
    }
    TrayTip("已复制提示词，请粘贴", "Prompt Quick-Pad", "Iconi 1")
}

PromptQuickPad_PasteByFilteredIndex(i0) {
    global PromptQuickPadFilteredIdx
    if i0 < 0 || i0 >= PromptQuickPadFilteredIdx.Length
        return
    PromptQuickPad_PasteByMergedIndex(PromptQuickPadFilteredIdx[i0 + 1])
}

PromptQuickPad_DeleteByMergedIndex(mi) {
    global PromptQuickPadData
    merged := PromptQuickPad_BuildMergedList()
    if mi < 1 || mi > merged.Length
        return
    entry := merged[mi]
    src := entry.Has("source") ? entry["source"] : ""
    if src != "json" {
        MsgBox("此项来自“快捷操作”或“模板库”，请在设置里修改。", "Prompt Quick-Pad", "Iconi")
        return
    }
    if MsgBox("确定删除该条用户提示词？（仅移除 prompts.json 条目）", "Prompt Quick-Pad", "YesNo Icon?") != "Yes"
        return
    uix := entry.Has("userIndex") ? Integer(entry["userIndex"]) : 0
    if uix >= 1 && uix <= PromptQuickPadData.Length {
        PromptQuickPadData.RemoveAt(uix)
        PromptQuickPad_SaveToDisk()
        PromptQuickPad_RefreshListView()
    }
}

PromptQuickPad_EditItemByMergedIndex(mi) {
    merged := PromptQuickPad_BuildMergedList()
    if mi < 1 || mi > merged.Length
        return
    shell := merged[mi]
    if PromptQuickPad_ShouldUseWebView() && PQP_IsReady() {
        PromptQuickPad_OpenEditWeb(shell, mi)
        return
    }
    PromptQuickPad_EditEntry(shell)
}

PromptQuickPad_ViewItemByMergedIndex(mi) {
    merged := PromptQuickPad_BuildMergedList()
    if mi < 1 || mi > merged.Length
        return
    shell := merged[mi]
    title := shell.Has("title") ? shell["title"] : ""
    content := shell.Has("content") ? shell["content"] : ""
    if PromptQuickPad_ShouldUseWebView() && PQP_IsReady() {
        PromptQuickPad_OpenViewWeb(shell, mi)
        return
    }
    PromptQuickPad_OpenReadOnlyViewer(title, content)
}

PromptQuickPad_TryGetText(Key, Fallback) {
    try
        return GetText(Key)
    catch
        return Fallback
}

PromptQuickPad_LooksCorruptedText(s) {
    t := String(s)
    if (t = "")
        return false
    ; U+FFFD replacement char is a strong signal of broken decoding.
    if InStr(t, Chr(0xFFFD))
        return true
    ; Private Use Area chars often indicate broken decoding artifacts.
    if RegExMatch(t, "[\x{E000}-\x{F8FF}]")
        return true
    return false
}

PromptQuickPad_CleanText(v, fallback := "") {
    s := Trim(String(v))
    s := RegExReplace(s, "\R+", "`n")
    if (PromptQuickPad_LooksCorruptedText(s) && fallback != "")
        return fallback
    return s
}

PromptQuickPad_NormalizeCategoryName(v) {
    c := PromptQuickPad_CleanText(v)
    ; remove full-width spaces / zero-width chars
    c := StrReplace(c, Chr(0x3000), " ")
    c := RegExReplace(c, "[\x{200B}-\x{200D}\x{FEFF}]", "")
    c := Trim(c)
    if (c = "" || c = "未分类")
        return ""
    if (c = "全部")
        return "全部"
    return c
}

PromptQuickPad_NormalizeEntry(m) {
    if !(m is Map)
        return Map("id", "", "title", "", "tags", "", "content", "", "category", "", "hotkey", "", "source", "json", "enabled", true, "updatedAt", A_NowUTC)
    t := m.Has("title") ? PromptQuickPad_CleanText(m["title"]) : m.Has("Title") ? PromptQuickPad_CleanText(m["Title"]) : ""
    g := m.Has("tags") ? PromptQuickPad_CleanText(m["tags"]) : m.Has("Tags") ? PromptQuickPad_CleanText(m["Tags"]) : ""
    c := m.Has("content") ? PromptQuickPad_CleanText(m["content"]) : m.Has("Content") ? PromptQuickPad_CleanText(m["Content"]) : ""
    cat := m.Has("category") ? PromptQuickPad_NormalizeCategoryName(m["category"]) : m.Has("Category") ? PromptQuickPad_NormalizeCategoryName(m["Category"]) : ""
    hk := m.Has("hotkey") ? PromptQuickPad_CleanText(m["hotkey"]) : m.Has("Hotkey") ? PromptQuickPad_CleanText(m["Hotkey"]) : ""
    idv := m.Has("id") ? PromptQuickPad_CleanText(m["id"]) : (m.Has("ID") ? PromptQuickPad_CleanText(m["ID"]) : "")
    if idv = ""
        idv := "pqp_" . A_NowUTC . "_" . A_TickCount
    src := m.Has("source") ? StrLower(PromptQuickPad_CleanText(m["source"])) : "json"
    if (src != "json" && src != "builtin" && src != "template")
        src := "json"
    enabled := true
    if m.Has("enabled")
        enabled := !!m["enabled"]
    uat := m.Has("updatedAt") ? PromptQuickPad_CleanText(m["updatedAt"]) : A_NowUTC
    if (src = "builtin" && PromptQuickPad_LooksCorruptedText(c))
        c := PromptQuickPad_DefaultBuiltinContent(hk, t)
    out := Map("id", idv, "title", t, "tags", g, "content", c, "category", cat, "hotkey", hk, "source", src, "enabled", enabled, "updatedAt", uat)
    if m.Has("templateId")
        out["templateId"] := PromptQuickPad_CleanText(m["templateId"])
    return out
}

PromptQuickPad_DefaultBuiltinContent(hk, title := "") {
    if (hk = "CapsLock+E" || InStr(title, "解释"))
        return "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点。"
    if (hk = "CapsLock+R" || InStr(title, "重构"))
        return "重构这段代码，保持功能不变，提升可读性与可维护性，并说明关键改动。"
    if (hk = "CapsLock+O" || InStr(title, "优化"))
        return "分析这段代码的性能瓶颈，给出优化方案，并说明时间/空间复杂度变化。"
    return "请根据上下文完善该快捷提示词内容。"
}

PromptQuickPad_DedupText(v) {
    s := String(v)
    s := Trim(s)
    s := RegExReplace(s, "\R+", "`n")
    s := RegExReplace(s, "[ \t]+", " ")
    return s
}

PromptQuickPad_MakeEntryDedupKey(entry) {
    if !(entry is Map)
        return ""
    title := entry.Has("title") ? PromptQuickPad_DedupText(entry["title"]) : ""
    cat := entry.Has("category") ? PromptQuickPad_DedupText(entry["category"]) : ""
    content := entry.Has("content") ? PromptQuickPad_DedupText(entry["content"]) : ""
    if title = "" && content = ""
        return ""
    return StrLower(title) . "||" . StrLower(cat) . "||" . content
}

PromptQuickPad_SourcePriority(src) {
    switch src {
        case "builtin":
            return 3
        case "template":
            return 2
        case "json":
            return 1
    }
    return 0
}

PromptQuickPad_DeduplicateList(items) {
    seen := Map()
    out := []
    for item in items {
        key := PromptQuickPad_MakeEntryDedupKey(item)
        if key = "" {
            out.Push(item)
            continue
        }
        pri := PromptQuickPad_SourcePriority(item.Has("source") ? item["source"] : "")
        if !seen.Has(key) {
            seen[key] := Map("index", out.Length + 1, "priority", pri)
            out.Push(item)
            continue
        }
        prev := seen[key]
        if pri > prev["priority"] {
            out[prev["index"]] := item
            prev["priority"] := pri
            seen[key] := prev
        }
    }
    return out
}

PromptQuickPad_DeduplicateJsonData() {
    global PromptQuickPadData
    seen := Map()
    clean := []
    removed := 0
    for item in PromptQuickPadData {
        key := PromptQuickPad_MakeEntryDedupKey(item)
        if key = "" {
            clean.Push(item)
            continue
        }
        if seen.Has(key) {
            removed++
            continue
        }
        seen[key] := true
        clean.Push(item)
    }
    PromptQuickPadData := clean
    return removed
}

PromptQuickPad_LoadFromDisk() {
    global PromptQuickPadData
    path := PromptQuickPad_JsonPath()
    PromptQuickPadData := []
    changed := false
    if !FileExist(path) {
        try {
            store := Map(
                "version", 2,
                "updatedAt", A_NowUTC,
                "entries", [],
                "settings", Map("selectedCategory", "全部"),
                "sync", Map("cloudEnabled", false, "lastSyncAt", "", "syncEndpoint", "")
            )
            f0 := FileOpen(path, "w", "UTF-8")
            if f0 {
                f0.Write(Jxon_Dump(store))
                f0.Close()
            }
        }
        return
    }
    try {
        raw := FileRead(path, "UTF-8")
        parsed := Jxon_Load(raw)
        entries := []
        if (parsed is Array) {
            entries := parsed
        } else if (parsed is Map && parsed.Has("entries") && parsed["entries"] is Array) {
            entries := parsed["entries"]
        } else {
            entries := []
        }
        for item in entries {
            if item is Map {
                e := PromptQuickPad_NormalizeEntry(item)
                if !e.Has("source")
                    e["source"] := "json"
                oldContent := item.Has("content") ? String(item["content"]) : (item.Has("Content") ? String(item["Content"]) : "")
                if (e.Has("content") && String(e["content"]) != oldContent)
                    changed := true
                PromptQuickPadData.Push(e)
            }
        }
    } catch {
        PromptQuickPadData := []
    }
    added := PromptQuickPad_MigrateLegacySourcesIntoData()
    removed := PromptQuickPad_DeduplicateJsonData()
    if (removed > 0 || added > 0 || changed)
        PromptQuickPad_SaveToDisk()
}

PromptQuickPad_BuildCleanArrayForFile() {
    global PromptQuickPadData, PromptQuickPadSelectedCategory
    entries := []
    for item in PromptQuickPadData {
        if !(item is Map)
            continue
        o := PromptQuickPad_NormalizeEntry(item)
        entries.Push(o)
    }
    return Map(
        "version", 2,
        "updatedAt", A_NowUTC,
        "entries", entries,
        "settings", Map("selectedCategory", PromptQuickPadSelectedCategory),
        "sync", PromptQuickPad_GetSyncPortConfig()
    )
}

PromptQuickPad_SaveToDisk() {
    path := PromptQuickPad_JsonPath()
    try {
        clean := PromptQuickPad_BuildCleanArrayForFile()
        f := FileOpen(path, "w", "UTF-8")
        if !f
            return
        f.Write(Jxon_Dump(clean))
        f.Close()
    } catch {
    }
}

PromptQuickPad_TemplateExtraTags(T) {
    parts := ""
    fc := ""
    ser := ""
    try fc := T.FunctionCategory
    try ser := T.Series
    if fc != ""
        parts .= fc
    if ser != "" {
        if parts != ""
            parts .= ","
        parts .= ser
    }
    return parts
}

; 鍚堝苟锛氳缃〉涓夐」蹇嵎璇?+ PromptTemplates.ini 鍔犺浇鐨勫叏灞€妯℃澘 + prompts.json 鐢ㄦ埛椤?
PromptQuickPad_BuildMergedList() {
    global PromptQuickPadData
    addedNow := PromptQuickPad_MigrateLegacySourcesIntoData()
    if (addedNow > 0)
        PromptQuickPad_SaveToDisk()
    merged := []
    idx := 0
    for item in PromptQuickPadData {
        idx++
        e := PromptQuickPad_NormalizeEntry(item)
        if (e.Has("enabled") && !e["enabled"])
            continue
        if !e.Has("source") || e["source"] = ""
            e["source"] := "json"
        e["userIndex"] := idx
        if !e.Has("category")
            e["category"] := ""
        if !e.Has("hotkey")
            e["hotkey"] := ""
        merged.Push(e)
    }
    ; Normalize and guard against mojibake coming from ini/config sources.
    for i, it in merged {
        if !(it is Map)
            continue
        if it.Has("title")
            it["title"] := PromptQuickPad_CleanText(it["title"], "未命名")
        if it.Has("content")
            it["content"] := PromptQuickPad_CleanText(it["content"])
        if it.Has("category")
            it["category"] := PromptQuickPad_NormalizeCategoryName(it["category"])
        if it.Has("tags")
            it["tags"] := PromptQuickPad_CleanText(it["tags"])
        if it.Has("hotkey")
            it["hotkey"] := PromptQuickPad_CleanText(it["hotkey"])
        merged[i] := it
    }
    return PromptQuickPad_DeduplicateList(merged)
}

PromptQuickPad_MakePreview(Text, MaxLen := 96) {
    s := RegExReplace(Text, "[\r\n\t]+", " ")
    s := Trim(s)
    if StrLen(s) > MaxLen
        s := SubStr(s, 1, MaxLen) . "..."
    return s
}

PromptQuickPad_UniqueCategoryTabs(merged) {
    hasUncat := false
    m := Map()
    for e in merged {
        c := e.Has("category") ? PromptQuickPad_NormalizeCategoryName(e["category"]) : ""
        if c = ""
            hasUncat := true
        else
            m[c] := true
    }
    out := ["全部"]
    if hasUncat
        out.Push("未分类")
    blob := ""
    for k in m {
        if blob != ""
            blob .= "`n"
        blob .= k
    }
    if blob != "" {
        blob := Sort(blob, "D`n")
        for k in StrSplit(blob, "`n")
            out.Push(k)
    }
    return out
}

PromptQuickPad_CategorySignature(cats) {
    s := ""
    for c in cats {
        s .= c . "`n"
    }
    return s
}

PromptQuickPad_CategoryMatches(entry, Tab) {
    if Tab = "" || Tab = "全部"
        return true
    raw := entry.Has("category") ? entry["category"] : ""
    if Tab = "未分类"
        return raw = ""
    return raw = Tab
}

PromptQuickPad_GetSyncPortConfig() {
    return Map(
        "cloudEnabled", false,
        "lastSyncAt", "",
        "syncEndpoint", "pqp://local-sync"
    )
}

PromptQuickPad_MigrateLegacySourcesIntoData() {
    global PromptQuickPadData, PromptTemplates
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize
    added := 0
    haveKey := Map()
    for it in PromptQuickPadData {
        if !(it is Map)
            continue
        k := PromptQuickPad_MakeEntryDedupKey(it)
        if k != ""
            haveKey[k] := true
    }
    capCat := "快捷操作"
    if Trim(Prompt_Explain) != ""
        added += PromptQuickPad_MigrateAddIfMissing(haveKey, Map("title", "解释代码", "category", capCat, "tags", "", "hotkey", "CapsLock+E", "content", Prompt_Explain, "source", "builtin")) ? 1 : 0
    if Trim(Prompt_Refactor) != ""
        added += PromptQuickPad_MigrateAddIfMissing(haveKey, Map("title", "重构代码", "category", capCat, "tags", "", "hotkey", "CapsLock+R", "content", Prompt_Refactor, "source", "builtin")) ? 1 : 0
    if Trim(Prompt_Optimize) != ""
        added += PromptQuickPad_MigrateAddIfMissing(haveKey, Map("title", "优化代码", "category", capCat, "tags", "", "hotkey", "CapsLock+O", "content", Prompt_Optimize, "source", "builtin")) ? 1 : 0
    if IsSet(PromptTemplates) && PromptTemplates is Array {
        for T in PromptTemplates {
            if !IsObject(T)
                continue
            title := "", content := "", cat := "", tid := ""
            try title := T.Title
            try content := T.Content
            try cat := T.Category
            try tid := T.ID
            if title = "" && content = ""
                continue
            ent := Map("title", title, "category", cat, "tags", PromptQuickPad_TemplateExtraTags(T), "hotkey", "", "content", content, "source", "template")
            if tid != ""
                ent["templateId"] := tid
            added += PromptQuickPad_MigrateAddIfMissing(haveKey, ent) ? 1 : 0
        }
    }
    return added
}

PromptQuickPad_MigrateAddIfMissing(haveKey, entry) {
    global PromptQuickPadData
    k := PromptQuickPad_MakeEntryDedupKey(entry)
    if (k = "" || haveKey.Has(k))
        return false
    haveKey[k] := true
    PromptQuickPadData.Push(PromptQuickPad_NormalizeEntry(entry))
    return true
}

PromptQuickPad_ClearCategoryStrip() {
    global PromptQuickPadCategoryStrip, PromptQuickPadCategoryCtrlByName
    for c in PromptQuickPadCategoryStrip {
        try c.Destroy()
        catch {
        }
    }
    PromptQuickPadCategoryStrip := []
    PromptQuickPadCategoryCtrlByName := Map()
}

PromptQuickPad_StyleCategoryTabs() {
    global PromptQuickPadCategoryCtrlByName, PromptQuickPadSelectedCategory, AIListPanelColors
    for name, ctrl in PromptQuickPadCategoryCtrlByName {
        active := (name = PromptQuickPadSelectedCategory)
        bg := active ? AIListPanelColors.CategoryTabActive : AIListPanelColors.CategoryTabInactive
        tc := active ? AIListPanelColors.TextHover : AIListPanelColors.Text
        try {
            ctrl.Opt("Background" . bg . " c" . tc)
            ctrl.SetFont((active ? "s10 Bold c" : "s10 Norm c") . tc, "Segoe UI")
        } catch {
        }
    }
}

PromptQuickPad_GetClientSize(hwnd, &cw, &ch) {
    rect := Buffer(16, 0)
    if !DllCall("GetClientRect", "ptr", hwnd, "ptr", rect)
        return false
    cw := NumGet(rect, 8, "int")
    ch := NumGet(rect, 12, "int")
    return true
}

PromptQuickPad_ResetCaptureDraftRefs() {
    global PromptQuickPadCaptureToggle, PromptQuickPadLblDraftTitle, PromptQuickPad_edDraftTitle
    global PromptQuickPadLblDraftCat, PromptQuickPad_cbDraftCategory, PromptQuickPadLblDraftTags, PromptQuickPad_edDraftTags
    global PromptQuickPad_chkCaptureSilent, PromptQuickPad_chkCaptureSilentTpl
    global PromptQuickPadLblDraftBody, PromptQuickPad_edDraftContent
    global PromptQuickPad_btnDraftLoad, PromptQuickPad_btnDraftSave, PromptQuickPad_btnDraftClear
    global PromptQuickPadLblListFilter
    PromptQuickPadCaptureToggle := 0
    PromptQuickPadLblDraftTitle := 0
    PromptQuickPad_edDraftTitle := 0
    PromptQuickPadLblDraftCat := 0
    PromptQuickPad_cbDraftCategory := 0
    PromptQuickPadLblDraftTags := 0
    PromptQuickPad_edDraftTags := 0
    PromptQuickPad_chkCaptureSilent := 0
    PromptQuickPad_chkCaptureSilentTpl := 0
    PromptQuickPadLblDraftBody := 0
    PromptQuickPad_edDraftContent := 0
    PromptQuickPad_btnDraftLoad := 0
    PromptQuickPad_btnDraftSave := 0
    PromptQuickPad_btnDraftClear := 0
    PromptQuickPadLblListFilter := 0
}

PromptQuickPad_LoadCaptureExpandedFromIni() {
    global PromptQuickPad_CaptureExpanded
    cfg := Nmer_ResolveConfigFile()
    try
        PromptQuickPad_CaptureExpanded := (IniRead(cfg, "PromptQuickPad", "CapturePanelExpanded", "1") = "1")
    catch
        PromptQuickPad_CaptureExpanded := true
}

PromptQuickPad_SaveCaptureExpandedToIni() {
    global PromptQuickPad_CaptureExpanded
    cfg := Nmer_ResolveConfigFile()
    try IniWrite(PromptQuickPad_CaptureExpanded ? "1" : "0", cfg, "PromptQuickPad", "CapturePanelExpanded")
    catch {
    }
}

PromptQuickPad_UpdateCaptureToggleText() {
    global PromptQuickPadCaptureToggle, PromptQuickPad_CaptureExpanded
    if PromptQuickPadCaptureToggle = 0
        return
    try PromptQuickPadCaptureToggle.Text := PromptQuickPad_CaptureExpanded ? "▼ 摘录 / 采集（点击收起）" : "▶ 摘录 / 采集（点击展开）"
    catch {
    }
}

PromptQuickPad_ApplyCaptureControlsVisibility() {
    global PromptQuickPad_CaptureExpanded, PromptQuickPad_CaptureChromeVisible
    global PromptQuickPadCaptureToggle
    global PromptQuickPadLblDraftTitle, PromptQuickPad_edDraftTitle, PromptQuickPadLblDraftCat, PromptQuickPad_cbDraftCategory
    global PromptQuickPadLblDraftTags, PromptQuickPad_edDraftTags, PromptQuickPad_chkCaptureSilent, PromptQuickPad_chkCaptureSilentTpl
    global PromptQuickPadLblDraftBody, PromptQuickPad_edDraftContent, PromptQuickPad_btnDraftLoad, PromptQuickPad_btnDraftSave
    global PromptQuickPad_btnDraftClear, PromptQuickPadLblListFilter
    draftVis := PromptQuickPad_CaptureChromeVisible && PromptQuickPad_CaptureExpanded
    if PromptQuickPadCaptureToggle != 0 {
        try PromptQuickPadCaptureToggle.Visible := PromptQuickPad_CaptureChromeVisible
        catch {
        }
    }
    for ctrl in [
        PromptQuickPadLblDraftTitle, PromptQuickPad_edDraftTitle, PromptQuickPadLblDraftCat, PromptQuickPad_cbDraftCategory,
        PromptQuickPadLblDraftTags, PromptQuickPad_edDraftTags, PromptQuickPad_chkCaptureSilent, PromptQuickPad_chkCaptureSilentTpl,
        PromptQuickPadLblDraftBody, PromptQuickPad_edDraftContent, PromptQuickPad_btnDraftLoad, PromptQuickPad_btnDraftSave,
        PromptQuickPad_btnDraftClear, PromptQuickPadLblListFilter
    ] {
        if ctrl = 0
            continue
        try ctrl.Visible := draftVis
        catch {
        }
    }
}

PromptQuickPad_SetCaptureChromeVisible(vis, doRelayout := true) {
    global PromptQuickPad_CaptureChromeVisible
    PromptQuickPad_CaptureChromeVisible := vis
    PromptQuickPad_ApplyCaptureControlsVisibility()
    if doRelayout
        PromptQuickPad_RelayoutMainControls()
    if PromptQuickPad_ShouldUseWebView() && PQP_IsReady()
        PromptQuickPad_PushDataToWeb("searchResult")
}

PromptQuickPad_OnCaptureToggleClick(*) {
    global PromptQuickPad_CaptureExpanded
    PromptQuickPad_CaptureExpanded := !PromptQuickPad_CaptureExpanded
    PromptQuickPad_SaveCaptureExpandedToIni()
    PromptQuickPad_UpdateCaptureToggleText()
    PromptQuickPad_ApplyCaptureControlsVisibility()
    PromptQuickPad_RelayoutMainControls()
}

PromptQuickPad_SetCaptureExpanded(expanded, saveIni := true) {
    global PromptQuickPad_CaptureExpanded
    PromptQuickPad_CaptureExpanded := expanded
    if saveIni
        PromptQuickPad_SaveCaptureExpandedToIni()
    PromptQuickPad_UpdateCaptureToggleText()
    PromptQuickPad_ApplyCaptureControlsVisibility()
    if PromptQuickPad_ShouldUseWebView() && PQP_IsReady()
        PromptQuickPad_PushDataToWeb("searchResult")
}

PromptQuickPad_BuildDraftCategoryChoices() {
    merged := PromptQuickPad_BuildMergedList()
    tabs := PromptQuickPad_UniqueCategoryTabs(merged)
    choices := ["未分类"]
    seen := Map("未分类", true)
    for t in tabs {
        if t = "" || t = "全部" || t = "未分类"
            continue
        if seen.Has(t)
            continue
        seen[t] := true
        choices.Push(t)
    }
    return choices
}

PromptQuickPad_RefreshDraftCategoryCombo() {
    global PromptQuickPad_cbDraftCategory
    if PromptQuickPad_cbDraftCategory = 0
        return
    cur := ""
    try cur := Trim(PromptQuickPad_cbDraftCategory.Text)
    catch {
    }
    try PromptQuickPad_cbDraftCategory.Delete()
    catch {
    }
    try PromptQuickPad_cbDraftCategory.Add(PromptQuickPad_BuildDraftCategoryChoices())
    catch {
    }
    try PromptQuickPad_cbDraftCategory.Text := (cur = "" ? "未分类" : cur)
    catch {
    }
}

PromptQuickPad_DraftCategoryTextToSave() {
    global PromptQuickPad_cbDraftCategory
    if PromptQuickPad_cbDraftCategory = 0
        return ""
    try cat := Trim(PromptQuickPad_cbDraftCategory.Text)
    catch
        return ""
    return cat = "未分类" ? "" : cat
}

PromptQuickPad_WriteDefaultsFromCaptureDraft() {
    global PromptQuickPad_edDraftTitle, PromptQuickPad_edDraftTags, PromptQuickPad_CapsLockBDefaultTitle
    global PromptQuickPad_CapsLockBDefaultCategory, PromptQuickPad_CapsLockBDefaultTags
    if PromptQuickPad_edDraftTitle = 0
        return
    title := Trim(PromptQuickPad_edDraftTitle.Value)
    if title = ""
        title := "鎽樺綍"
    tags := PromptQuickPad_edDraftTags != 0 ? Trim(PromptQuickPad_edDraftTags.Value) : ""
    cat := PromptQuickPad_DraftCategoryTextToSave()
    PromptQuickPad_CapsLockBDefaultTitle := title
    PromptQuickPad_CapsLockBDefaultCategory := cat
    PromptQuickPad_CapsLockBDefaultTags := tags
    PSS_WriteCapsLockBDefaultFieldsToIni(title, cat, tags)
}

PromptQuickPad_OnCaptureSilentChange(GuiCtrlObj, *) {
    global PromptQuickPad_CapsLockBSilent
    try PromptQuickPad_CapsLockBSilent := GuiCtrlObj.Value = 1
    catch
        return
    PSS_IniWritePQP("CapsLockBSilent", PromptQuickPad_CapsLockBSilent ? "1" : "0")
    if PromptQuickPad_CapsLockBSilent
        PromptQuickPad_WriteDefaultsFromCaptureDraft()
}

PromptQuickPad_OnCaptureSilentTplChange(GuiCtrlObj, *) {
    global PromptQuickPad_CapsLockBSilentToTemplate
    try PromptQuickPad_CapsLockBSilentToTemplate := GuiCtrlObj.Value = 1
    catch
        return
    PSS_IniWritePQP("CapsLockBSilentToTemplate", PromptQuickPad_CapsLockBSilentToTemplate ? "1" : "0")
}

PromptQuickPad_FillCaptureDraftContent(initialText := "") {
    global PromptQuickPad_edDraftContent
    if PromptQuickPad_edDraftContent = 0
        return
    PromptQuickPad_edDraftContent.Value := initialText
    try PromptQuickPad_edDraftContent.Focus()
    catch {
    }
}

PromptQuickPad_FlushPendingCaptureDraft(*) {
    global PromptQuickPad_PendingCaptureText, PromptQuickPad_edDraftContent
    if PromptQuickPad_edDraftContent = 0
        return
    want := Trim(PromptQuickPad_PendingCaptureText, " `t`r`n")
    if want = ""
        return
    if Trim(PromptQuickPad_edDraftContent.Value, " `t`r`n") = want
        return
    PromptQuickPad_FillCaptureDraftContent(PromptQuickPad_PendingCaptureText)
}

PromptQuickPad_LoadDraftFromListSelection(*) {
    global PromptQuickPad_edDraftTitle, PromptQuickPad_cbDraftCategory, PromptQuickPad_edDraftTags, PromptQuickPad_edDraftContent
    global PromptQuickPadFilteredIdx, PromptQuickPadMergedSnapshot, PromptQuickPadListLV
    if PromptQuickPadListLV = 0
        return
    row := PromptQuickPadListLV.GetNext(0, "Focused")
    if row < 1
        row := PromptQuickPadListLV.GetNext(0)
    if row < 1 || row > PromptQuickPadFilteredIdx.Length
        return
    mi := PromptQuickPadFilteredIdx[row]
    if mi < 1 || mi > PromptQuickPadMergedSnapshot.Length
        return
    entry := PromptQuickPadMergedSnapshot[mi]
    if !(entry is Map)
        return
    if PromptQuickPad_edDraftTitle != 0
        PromptQuickPad_edDraftTitle.Value := entry.Has("title") ? entry["title"] : ""
    if PromptQuickPad_cbDraftCategory != 0
        PromptQuickPad_cbDraftCategory.Text := (entry.Has("category") && entry["category"] != "" ? entry["category"] : "未分类")
    if PromptQuickPad_edDraftTags != 0
        PromptQuickPad_edDraftTags.Value := entry.Has("tags") ? entry["tags"] : ""
    if PromptQuickPad_edDraftContent != 0
        PromptQuickPad_edDraftContent.Value := entry.Has("content") ? entry["content"] : ""
}

PromptQuickPad_SaveDraftToJson(*) {
    global PromptQuickPad_edDraftTitle, PromptQuickPad_edDraftTags, PromptQuickPad_edDraftContent, PromptQuickPadData
    title := PromptQuickPad_edDraftTitle != 0 ? Trim(PromptQuickPad_edDraftTitle.Value) : ""
    if title = ""
        title := "未命名"
    tags := PromptQuickPad_edDraftTags != 0 ? Trim(PromptQuickPad_edDraftTags.Value) : ""
    body := PromptQuickPad_edDraftContent != 0 ? Trim(PromptQuickPad_edDraftContent.Value, " `t`r`n") : ""
    if body = "" {
        TrayTip("正文不能为空", "Prompt Quick-Pad", "Icon! 1")
        return
    }
    PromptQuickPad_LoadFromDisk()
    PromptQuickPadData.Push(PromptQuickPad_NormalizeEntry(Map("title", title, "tags", tags, "content", body, "category", PromptQuickPad_DraftCategoryTextToSave(), "hotkey", "")))
    PromptQuickPad_SaveToDisk()
    PromptQuickPad_RefreshListView()
}

PromptQuickPad_ClearCaptureDraft(*) {
    PromptQuickPad_SyncCaptureDraftFromIni()
    PromptQuickPad_FillCaptureDraftContent("")
}

; WebView锛氬悓姝ユ憳褰曞尯鐘舵€佸悗鎺ㄩ€佸畬鏁村垪琛?鍒嗙被锛圧efreshListView 鍦?Web 妯″紡涓嬩笉 PostMessage锛?
; 鑻?WebView 灏氭湭灏辩华锛堥娆℃墦寮€鏃跺紓姝ュ垵濮嬪寲锛夛紝閫氳繃寤惰繜閲嶈瘯淇濊瘉鏁版嵁涓€瀹氶€佽揪銆?
global _PQP_PendingCapText := ""
global _PQP_PendingCapExpand := true
global _PQP_PendingCapRetry := 0

PromptQuickPad_ApplyWebCaptureDraft(initialText := "", forceExpand := true) {
    global _PQP_PendingCapText, _PQP_PendingCapExpand, _PQP_PendingCapRetry
    PromptQuickPad_SetCaptureChromeVisible(true, false)
    if forceExpand
        PromptQuickPad_SetCaptureExpanded(true, false)
    else
        PromptQuickPad_SetCaptureExpanded(false, false)
    PromptQuickPad_SyncCaptureDraftFromIni()
    
    ; 纭繚鏁版嵁宸插姞杞斤紙prompts.json + PromptTemplates锛夛紝BuildMergedList 鎵嶈兘瀹屾暣
    PromptQuickPad_LoadFromDisk()

    _PQP_PendingCapText := initialText
    _PQP_PendingCapExpand := forceExpand

    if PQP_IsReady() {
        PromptQuickPad_PushDataToWeb("init")
        PQP_SendCaptureOpen(Trim(initialText), forceExpand)
        _PQP_PendingCapRetry := 0
    } else {
        _PQP_PendingCapRetry := 5
        SetTimer(_PQP_DeferredCapturePush, -300)
    }
    try LegacyGuard_RequestFocus("AIListPanel.Host", "ahk_id " . PromptQuickPad_GetHostHwnd(), 45, "restore_host_focus")
    catch {
    }
}

_PQP_DeferredCapturePush(*) {
    global _PQP_PendingCapText, _PQP_PendingCapExpand, _PQP_PendingCapRetry
    if _PQP_PendingCapRetry <= 0
        return
    if PQP_IsReady() {
        _PQP_PendingCapRetry := 0
        PromptQuickPad_PushDataToWeb("init")
        PQP_SendCaptureOpen(Trim(_PQP_PendingCapText), _PQP_PendingCapExpand)
    } else {
        _PQP_PendingCapRetry--
        if _PQP_PendingCapRetry > 0
            SetTimer(_PQP_DeferredCapturePush, -400)
    }
}

PromptQuickPad_OpenCaptureDraft(initialText := "", forceExpand := true) {
    global AIListPanelIsVisible, AIListPanelGUI, PromptQuickPad_PendingCaptureText
    PromptQuickPad_PendingCaptureText := initialText
    ShowAIListPanel(true, true)
    if PromptQuickPad_ShouldUseWebView() {
        PromptQuickPad_ApplyWebCaptureDraft(initialText, forceExpand)
        return
    }
    PromptQuickPad_SetCaptureChromeVisible(true, false)
    if forceExpand
        PromptQuickPad_SetCaptureExpanded(true, false)
    PromptQuickPad_SyncCaptureDraftFromIni()
    PromptQuickPad_RefreshDraftCategoryCombo()
    PromptQuickPad_UpdateCaptureToggleText()
    PromptQuickPad_ApplyCaptureControlsVisibility()
    PromptQuickPad_RelayoutMainControls()
    PromptQuickPad_RefreshListView()
    PromptQuickPad_FillCaptureDraftContent(initialText)
    if Trim(initialText, " `t`r`n") != ""
        SetTimer(PromptQuickPad_FlushPendingCaptureDraft, -60)
    try ControlFocus(PromptQuickPad_edDraftContent)
    catch {
    }
    try LegacyGuard_RequestFocus("AIListPanel.Main", "ahk_id " . AIListPanelGUI.Hwnd, 50, "show_panel_focus")
    catch {
    }
}

; clientW/clientH 鍙紶鍏?OnEvent("Size") 鐨勫鎴风瀹介珮锛涗负 0 鏃剁敤 GetClientRect
PromptQuickPad_RelayoutMainControls(clientW := 0, clientH := 0) {
    if PromptQuickPad_ShouldUseWebView()
        return
    global AIListPanelGUI, AIListPanelSearchInput, PromptQuickPadListLV, PromptQuickPadStatusText
    global PromptQuickPadCategoryStripHeight
    global PromptQuickPad_CaptureChromeVisible, PromptQuickPad_CaptureExpanded, PromptQuickPadCaptureToggle
    global PromptQuickPadLblDraftTitle, PromptQuickPad_edDraftTitle, PromptQuickPadLblDraftCat, PromptQuickPad_cbDraftCategory
    global PromptQuickPadLblDraftTags, PromptQuickPad_edDraftTags, PromptQuickPad_chkCaptureSilent, PromptQuickPad_chkCaptureSilentTpl
    global PromptQuickPadLblDraftBody, PromptQuickPad_edDraftContent, PromptQuickPad_btnDraftLoad, PromptQuickPad_btnDraftSave
    global PromptQuickPad_btnDraftClear, PromptQuickPadLblListFilter
    global PromptQuickPadBtnImport, PromptQuickPadBtnExport, PromptQuickPadBtnPinTop, PromptQuickPadBtnJsonHelp
    if AIListPanelGUI = 0
        return
    if clientW <= 0 || clientH <= 0
        PromptQuickPad_GetClientSize(AIListPanelGUI.Hwnd, &clientW, &clientH)
    w := clientW
    h := clientH
    margin := 10
    topPad := 10
    searchH := 22
    statusH := 44
    bottomPad := 12
    linkBarH := PromptQuickPad_LinkBarHeight > 8 ? PromptQuickPad_LinkBarHeight : 22
    catBlock := PromptQuickPadCategoryStripHeight > 8 ? PromptQuickPadCategoryStripHeight : 36
    belowCat := topPad + catBlock + 6
    hdrW := w - margin * 2
    toggleH := 22
    searchY := belowCat + linkBarH + 8
    if PromptQuickPad_CaptureChromeVisible {
        capTop := belowCat + linkBarH + 2
        if PromptQuickPadCaptureToggle != 0
            PromptQuickPadCaptureToggle.Move(margin, capTop, hdrW, toggleH)
        searchY := capTop + toggleH + 6
        if PromptQuickPad_CaptureExpanded {
            rowH := 22
            lblW := 72
            edX := margin + lblW + 8
            edW := w - margin - edX
            if edW < 100
                edW := 100
            y := searchY
            if PromptQuickPadLblDraftTitle != 0
                PromptQuickPadLblDraftTitle.Move(margin, y, lblW, rowH)
            if PromptQuickPad_edDraftTitle != 0
                PromptQuickPad_edDraftTitle.Move(edX, y, edW, rowH)
            y += rowH + 6
            if PromptQuickPadLblDraftCat != 0
                PromptQuickPadLblDraftCat.Move(margin, y, lblW, rowH)
            if PromptQuickPad_cbDraftCategory != 0
                PromptQuickPad_cbDraftCategory.Move(edX, y, edW, rowH)
            y += rowH + 6
            if PromptQuickPadLblDraftTags != 0
                PromptQuickPadLblDraftTags.Move(margin, y, lblW, rowH)
            if PromptQuickPad_edDraftTags != 0
                PromptQuickPad_edDraftTags.Move(edX, y, edW, rowH)
            y += rowH + 8
            chkH := 36
            halfW := Floor((hdrW - 8) / 2)
            if hdrW < 440 {
                if PromptQuickPad_chkCaptureSilent != 0
                    PromptQuickPad_chkCaptureSilent.Move(margin, y, hdrW, chkH)
                y += chkH + 4
                if PromptQuickPad_chkCaptureSilentTpl != 0
                    PromptQuickPad_chkCaptureSilentTpl.Move(margin, y, hdrW, chkH)
                y += chkH + 8
            } else {
                if PromptQuickPad_chkCaptureSilent != 0
                    PromptQuickPad_chkCaptureSilent.Move(margin, y, halfW, chkH)
                if PromptQuickPad_chkCaptureSilentTpl != 0
                    PromptQuickPad_chkCaptureSilentTpl.Move(margin + halfW + 8, y, halfW, chkH)
                y += chkH + 8
            }
            if PromptQuickPadLblDraftBody != 0
                PromptQuickPadLblDraftBody.Move(margin, y, hdrW, 18)
            y += 22
            bodyH := Min(180, Max(90, Round(h * 0.18)))
            if PromptQuickPad_edDraftContent != 0
                PromptQuickPad_edDraftContent.Move(margin, y, hdrW, bodyH)
            y += bodyH + 8
            btnW := Floor((hdrW - 20) / 3)
            if btnW < 90
                btnW := 90
            if PromptQuickPad_btnDraftLoad != 0
                PromptQuickPad_btnDraftLoad.Move(margin, y, btnW, 28)
            if PromptQuickPad_btnDraftSave != 0
                PromptQuickPad_btnDraftSave.Move(margin + btnW + 10, y, btnW, 28)
            if PromptQuickPad_btnDraftClear != 0
                PromptQuickPad_btnDraftClear.Move(margin + (btnW + 10) * 2, y, btnW, 28)
            y += 36
            if PromptQuickPadLblListFilter != 0
                PromptQuickPadLblListFilter.Move(margin, y, hdrW, 18)
            y += 22
            searchY := y
        }
    }
    if AIListPanelSearchInput != 0
        AIListPanelSearchInput.Move(margin, searchY, w - margin * 2, searchH)
    lvY := searchY + searchH + margin
    linkY := h - bottomPad - linkBarH
    if linkY < 0
        linkY := 0
    statusY := linkY - 6 - statusH
    if statusY < lvY + 40
        statusY := lvY + 40
    lvH := statusY - lvY - margin
    if lvH < 80
        lvH := 80
    if PromptQuickPadListLV != 0 {
        PromptQuickPadListLV.Move(margin, lvY, w - margin * 2, lvH)
        try {
            avail := w - margin * 2 - 120 - 72 - 88 - 8
            if avail < 100
                avail := 100
            PromptQuickPadListLV.ModifyCol(4, avail)
        } catch {
        }
    }
    if PromptQuickPadStatusText != 0
        PromptQuickPadStatusText.Move(margin, statusY, w - margin * 2, statusH)
    if PromptQuickPadBtnImport != 0
        PromptQuickPadBtnImport.Move(margin, linkY)
    if PromptQuickPadBtnExport != 0
        PromptQuickPadBtnExport.Move(margin + 52, linkY)
    if PromptQuickPadBtnPinTop != 0
        PromptQuickPadBtnPinTop.Move(margin + 100, linkY)
    if PromptQuickPadBtnJsonHelp != 0
        PromptQuickPadBtnJsonHelp.Move(margin + 182, linkY)
}

PromptQuickPad_MakeCategoryHandler(CatName) {
    return (Ctrl, *) => PromptQuickPad_ApplyCategoryFilter(CatName)
}

PromptQuickPad_ApplyCategoryFilter(CatName) {
    global PromptQuickPadSelectedCategory
    PromptQuickPadSelectedCategory := CatName
    PromptQuickPad_StyleCategoryTabs()
    merged := PromptQuickPad_BuildMergedList()
    PromptQuickPad_FillListViewFromMerged(merged)
    PromptQuickPad_RelayoutMainControls()
}

PromptQuickPad_RefreshCategoryStrip(merged) {
    global AIListPanelGUI, PromptQuickPadLastCategorySig, PromptQuickPadSelectedCategory, AIListPanelColors
    global PromptQuickPadCategoryStripHeight, PromptQuickPadCategoryStrip, PromptQuickPadCategoryCtrlByName
    if AIListPanelGUI = 0
        return
    cats := PromptQuickPad_UniqueCategoryTabs(merged)
    sig := PromptQuickPad_CategorySignature(cats)
    if sig = PromptQuickPadLastCategorySig && PromptQuickPadCategoryStrip.Length > 0 {
        PromptQuickPad_StyleCategoryTabs()
        return
    }
    PromptQuickPadLastCategorySig := sig
    PromptQuickPad_ClearCategoryStrip()
    cw := 0
    ch := 0
    PromptQuickPad_GetClientSize(AIListPanelGUI.Hwnd, &cw, &ch)
    if cw < 200
        cw := 400
    margin := 10
    catY := 10
    rowY := catY
    x := margin
    maxRight := cw - margin
    chipH := 30
    gapX := 10
    gapY := 8
    for cat in cats {
        wch := Min(maxRight - margin, Max(52, StrLen(cat) * 9 + 28))
        if x + wch > maxRight && x > margin {
            x := margin
            rowY += chipH + gapY
        }
        bg := (cat = PromptQuickPadSelectedCategory) ? AIListPanelColors.CategoryTabActive : AIListPanelColors.CategoryTabInactive
        tc := (cat = PromptQuickPadSelectedCategory) ? AIListPanelColors.TextHover : AIListPanelColors.Text
        t := AIListPanelGUI.Add("Text", "x" . x . " y" . rowY . " w" . wch . " h" . chipH . " Center 0x200 +0x100 Background" . bg . " c" . tc, cat)
        t.SetFont((cat = PromptQuickPadSelectedCategory) ? "s10 Bold" : "s10 Norm", "Segoe UI")
        t.OnEvent("Click", PromptQuickPad_MakeCategoryHandler(cat))
        PromptQuickPadCategoryStrip.Push(t)
        PromptQuickPadCategoryCtrlByName[cat] := t
        x += wch + gapX
    }
    PromptQuickPadCategoryStripHeight := (rowY - catY) + chipH + 10
    PromptQuickPad_StyleCategoryTabs()
}

PromptQuickPad_ValidateSelectedCategory(merged) {
    global PromptQuickPadSelectedCategory
    cats := PromptQuickPad_UniqueCategoryTabs(merged)
    ok := false
    for c in cats {
        if c = PromptQuickPadSelectedCategory {
            ok := true
            break
        }
    }
    if !ok
        PromptQuickPadSelectedCategory := "全部"
}

PromptQuickPad_MatchFilter(entry, needle) {
    if needle = ""
        return true
    t := entry.Has("title") ? entry["title"] : ""
    g := entry.Has("tags") ? entry["tags"] : ""
    c := entry.Has("content") ? entry["content"] : ""
    cat := entry.Has("category") ? entry["category"] : ""
    hk := entry.Has("hotkey") ? entry["hotkey"] : ""
    pv := PromptQuickPad_MakePreview(c, 200)
    if SubStr(needle, 1, 1) = "/" {
        endPos := InStr(needle, "/", , 2)
        if endPos >= 2 {
            pat := SubStr(needle, 2, endPos - 2)
            opt := ""
            rest := SubStr(needle, endPos + 1)
            if (rest = "i" || SubStr(rest, 1, 1) = "i")
                opt := "i)"
            try {
                return RegExMatch(t, opt . pat) || RegExMatch(g, opt . pat) || RegExMatch(cat, opt . pat)
                    || RegExMatch(c, opt . pat) || RegExMatch(hk, opt . pat)
            } catch {
                return false
            }
        }
    }
    n := StrLower(needle)
    return InStr(StrLower(t), n) || InStr(StrLower(g), n) || InStr(StrLower(cat), n) || InStr(StrLower(c), n)
        || InStr(StrLower(hk), n) || InStr(StrLower(pv), n)
}

PromptQuickPad_FillListViewFromMerged(merged) {
    global AIListPanelSearchInput, PromptQuickPadListLV, PromptQuickPadFilteredIdx, PromptQuickPadMergedSnapshot
    global PromptQuickPadStatusText, PromptQuickPadData, PromptQuickPadSelectedCategory
    if PromptQuickPad_ShouldUseWebView() {
        PromptQuickPad_PushDataToWeb("searchResult")
        return
    }
    if PromptQuickPadListLV = 0
        return
    needle := AIListPanelSearchInput != 0 ? Trim(AIListPanelSearchInput.Value) : ""
    PromptQuickPadMergedSnapshot := merged
    PromptQuickPadFilteredIdx := []
    PromptQuickPadListLV.Delete()
    row := 0
    for index, entry in merged {
        if !PromptQuickPad_CategoryMatches(entry, PromptQuickPadSelectedCategory)
            continue
        if !PromptQuickPad_MatchFilter(entry, needle)
            continue
        row++
        ccol := entry.Has("category") ? entry["category"] : ""
        hk := entry.Has("hotkey") ? entry["hotkey"] : ""
        cont := entry.Has("content") ? entry["content"] : ""
        prev := PromptQuickPad_MakePreview(cont)
        PromptQuickPadListLV.Add("", entry["title"], ccol, hk, prev)
        PromptQuickPadFilteredIdx.Push(index)
    }
    if PromptQuickPadStatusText != 0 {
        catDisp := PromptQuickPadSelectedCategory
        if StrLen(catDisp) > 18
            catDisp := SubStr(catDisp, 1, 18) . "..."
        PromptQuickPadStatusText.Value := "共 " . merged.Length . " 条 · prompts.json " . PromptQuickPadData.Length
            . " 条`n「" . catDisp . "」显示 " . row . " 条 · 双击粘贴 · 右键菜单 · 上方可导入/导出/查看 JSON 说明"
    }
}

PromptQuickPad_RefreshListView(*) {
    global PromptQuickPadListLV, PromptQuickPadData
    ; WebView 妯″紡涓嬩篃闇€瑕佸厛鍔犺浇鏁版嵁锛孊uildMergedList 鎵嶈兘鍖呭惈 prompts.json 鏉＄洰
    if PromptQuickPad_ShouldUseWebView()
        PromptQuickPad_LoadFromDisk()
    merged := PromptQuickPad_BuildMergedList()
    PromptQuickPad_ValidateSelectedCategory(merged)
    PromptQuickPad_RefreshCategoryStrip(merged)
    PromptQuickPad_FillListViewFromMerged(merged)
    if PromptQuickPad_ShouldUseWebView() {
        ; WebView 妯″紡锛氭瀯寤哄畬 merged 鍚庢帹閫佸埌鍓嶇
        PromptQuickPad_PushDataToWeb("searchResult")
        return
    }
    if PromptQuickPadListLV = 0
        return
    PromptQuickPad_RelayoutMainControls()
}

PromptQuickPad_OnSearchChange(*) {
    global PromptQuickPadSearchDebounce
    if PromptQuickPadSearchDebounce
        SetTimer(PromptQuickPadSearchDebounce, 0)
    PromptQuickPadSearchDebounce := PromptQuickPad_DebouncedRefresh
    SetTimer(PromptQuickPadSearchDebounce, -80)
}

PromptQuickPad_DebouncedRefresh(*) {
    global PromptQuickPadSearchDebounce
    PromptQuickPadSearchDebounce := 0
    PromptQuickPad_RefreshListView()
}

PromptQuickPad_GetFocusedRow() {
    global PromptQuickPadListLV
    if PromptQuickPadListLV = 0
        return 0
    r := PromptQuickPadListLV.GetNext(0, "Focused")
    if r = 0
        r := PromptQuickPadListLV.GetNext(0)
    return r
}

PromptQuickPad_PasteRow(row) {
    global PromptQuickPadFilteredIdx, PromptQuickPadMergedSnapshot
    if row < 1 || row > PromptQuickPadFilteredIdx.Length
        return
    srcIdx := PromptQuickPadFilteredIdx[row]
    if srcIdx < 1 || srcIdx > PromptQuickPadMergedSnapshot.Length
        return
    entry := PromptQuickPadMergedSnapshot[srcIdx]
    content := entry.Has("content") ? entry["content"] : ""
    if content = ""
        return
    try A_Clipboard := ""
    catch {
    }
    try A_Clipboard := content
    catch {
        TrayTip("澶嶅埗澶辫触", "Prompt Quick-Pad", "Iconx 1")
        return
    }
    if !ClipWait(0.12) {
        TrayTip("剪贴板写入失败", "Prompt Quick-Pad", "Iconx 1")
        return
    }
    try HideAIListPanel()
    catch {
    }
    TrayTip("宸插鍒舵彁绀鸿瘝锛岃绮樿创", "Prompt Quick-Pad", "Iconi 1")
}

PromptQuickPad_OnEnter(*) {
    row := PromptQuickPad_GetFocusedRow()
    if row > 0
        PromptQuickPad_PasteRow(row)
}

PromptQuickPad_OnEsc(*) {
    HideAIListPanel()
}

; 鍙屽嚮浠呯敱 WM_NOTIFY NM_DBLCLK 澶勭悊锛岄伩鍏嶄笌 OnEvent("DoubleClick") 閲嶅瑙﹀彂瀵艰嚧绮樿创涓ゆ

; ListView 鍙屽嚮鍦ㄩ儴鍒嗙幆澧冧笅 OnEvent 涓嶅彲闈狅紝鐢?WM_NOTIFY 鍏滃簳锛堜笉娉ㄥ唽 DoubleClick锛?
PromptQuickPad_ListViewHitItemOneBased(LV) {
    if LV = 0
        return 0
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "int*", &gx := 0, "int*", &gy := 0)
    NumPut("int", gx, pt, 0)
    NumPut("int", gy, pt, 4)
    if !DllCall("ScreenToClient", "ptr", LV.Hwnd, "ptr", pt)
        return 0
    lx := NumGet(pt, 0, "int")
    ly := NumGet(pt, 4, "int")
    info := Buffer(24, 0)
    NumPut("int", lx, info, 0)
    NumPut("int", ly, info, 4)
    SendMessage(0x1012, 0, info, LV)
    idx := NumGet(info, 12, "int")
    if idx < 0
        return 0
    return idx + 1
}

PromptQuickPad_OnWmNotify(wParam, lParam, msg, hwnd) {
    if PromptQuickPad_ShouldUseWebView()
        return
    global AIListPanelGUI, PromptQuickPadListLV
    if AIListPanelGUI = 0 || PromptQuickPadListLV = 0
        return
    if hwnd != AIListPanelGUI.Hwnd
        return
    hwndFrom := NumGet(lParam, 0, "ptr")
    if hwndFrom != PromptQuickPadListLV.Hwnd
        return
    code := NumGet(lParam, 2 * A_PtrSize, "int")
    nmSize := A_PtrSize = 8 ? 24 : 12
    iItem := NumGet(lParam, nmSize, "int")
    if code = -3 {  ; NM_DBLCLK锛堜粎姝よ矾寰勫鐞嗗弻鍑荤矘璐达紝閬垮厤閲嶅锛?
        r := 0
        if iItem >= 0
            r := iItem + 1
        else
            r := PromptQuickPad_ListViewHitItemOneBased(PromptQuickPadListLV)
        if r > 0
            PromptQuickPad_PasteRow(r)
    }
    ; 鍙抽敭鑿滃崟浠呯敱 ListView ContextMenu 浜嬩欢寮瑰嚭锛堝惈 Client鈫扴creen锛夛紝閬垮厤涓?NM_RCLICK 鍙屽紑鑿滃崟
}

PromptQuickPad_LoadPinFromIni() {
    global PromptQuickPad_PinTop
    try {
        v := IniRead(Nmer_ResolveConfigFile(), "PromptQuickPad", "AlwaysOnTop", "1")
        PromptQuickPad_PinTop := !(v = "0" || StrLower(v) = "false")
    } catch {
        PromptQuickPad_PinTop := true
    }
}

PromptQuickPad_SavePinToIni() {
    global PromptQuickPad_PinTop
    try IniWrite(PromptQuickPad_PinTop ? "1" : "0", Nmer_ResolveConfigFile(), "PromptQuickPad", "AlwaysOnTop")
    catch {
    }
}

PromptQuickPad_RefreshPinTopLabel(*) {
    global PromptQuickPadBtnPinTop, PromptQuickPad_PinTop
    if PromptQuickPadBtnPinTop
        PromptQuickPadBtnPinTop.Value := PromptQuickPad_PinTop ? "置顶·开" : "置顶·关"
}

PromptQuickPad_TogglePinTop(*) {
    global AIListPanelGUI, PromptQuickPad_PinTop
    PromptQuickPad_PinTop := !PromptQuickPad_PinTop
    PromptQuickPad_SavePinToIni()
    if AIListPanelGUI {
        try AIListPanelGUI.Opt(PromptQuickPad_PinTop ? "+AlwaysOnTop" : "-AlwaysOnTop")
        catch {
        }
    }
    if PromptQuickPad_ShouldUseWebView()
        PQP_ApplyPinTopFromIni()
    PromptQuickPad_RefreshPinTopLabel()
    if PromptQuickPad_ShouldUseWebView() && PQP_IsReady()
        PromptQuickPad_PushDataToWeb("searchResult")
}

PromptQuickPad_DestroyCtxMenu() {
    global PromptQuickPadCtxMenuGUI, PromptQuickPadCtxMenuSel
    PromptQuickPad_CtxCancelHoverAnim()
    SetTimer(PromptQuickPad_CheckCtxMenuMouse, 0)
    SetTimer(PromptQuickPad_CloseCtxMenuIfOutside, 0)
    PromptQuickPadCtxMenuSel := 0
    if PromptQuickPadCtxMenuGUI {
        try PromptQuickPadCtxMenuGUI.Destroy()
        catch {
        }
        PromptQuickPadCtxMenuGUI := 0
    }
}

PromptQuickPad_CtxMenuClick(act, *) {
    PromptQuickPad_DestroyCtxMenu()
    try act()
    catch {
    }
}

PromptQuickPad_CtxCancelHoverAnim() {
    global PromptQuickPadCtxHoverTimer
    if PromptQuickPadCtxHoverTimer {
        SetTimer(PromptQuickPadCtxHoverTimer, 0)
        PromptQuickPadCtxHoverTimer := 0
    }
}

PromptQuickPad_CtxItemHoverPhase2(ItemIndex, *) {
    global PromptQuickPadCtxMenuGUI, PromptQuickPadCtxMenuSel, PromptQuickPadCtxHoverTimer
    PromptQuickPadCtxHoverTimer := 0
    if !PromptQuickPadCtxMenuGUI || PromptQuickPadCtxMenuSel != ItemIndex
        return
    try {
        PromptQuickPadCtxMenuGUI["MenuItemBg" . ItemIndex].BackColor := "ff6600"
        PromptQuickPadCtxMenuGUI["MenuItemText" . ItemIndex].Opt("cFFFFFF")
        if PromptQuickPadCtxMenuGUI.HasProp("MenuItemIcon" . ItemIndex)
            PromptQuickPadCtxMenuGUI["MenuItemIcon" . ItemIndex].Opt("cFFFFFF")
    } catch {
    }
}

PromptQuickPad_CtxItemHover(ItemIndex) {
    global PromptQuickPadCtxMenuGUI, PromptQuickPadCtxMenuSel, PromptQuickPadCtxHoverTimer
    if PromptQuickPadCtxMenuSel = ItemIndex
        return
    PromptQuickPad_CtxCancelHoverAnim()
    if PromptQuickPadCtxMenuSel > 0 {
        try {
            PromptQuickPadCtxMenuGUI["MenuItemBg" . PromptQuickPadCtxMenuSel].BackColor := "1a1a1a"
            PromptQuickPadCtxMenuGUI["MenuItemText" . PromptQuickPadCtxMenuSel].Opt("cff6600")
            if PromptQuickPadCtxMenuGUI.HasProp("MenuItemIcon" . PromptQuickPadCtxMenuSel)
                PromptQuickPadCtxMenuGUI["MenuItemIcon" . PromptQuickPadCtxMenuSel].Opt("cff6600")
        } catch {
        }
    }
    PromptQuickPadCtxMenuSel := ItemIndex
    try {
        PromptQuickPadCtxMenuGUI["MenuItemBg" . ItemIndex].BackColor := "2a2622"
        PromptQuickPadCtxMenuGUI["MenuItemText" . ItemIndex].Opt("cffb366")
        if PromptQuickPadCtxMenuGUI.HasProp("MenuItemIcon" . ItemIndex)
            PromptQuickPadCtxMenuGUI["MenuItemIcon" . ItemIndex].Opt("cffb366")
    } catch {
    }
    fn := PromptQuickPad_CtxItemHoverPhase2.Bind(ItemIndex)
    PromptQuickPadCtxHoverTimer := fn
    SetTimer(fn, -50)
}

PromptQuickPad_CheckCtxMenuMouse(*) {
    global PromptQuickPadCtxMenuGUI, PromptQuickPadCtxMenuSel
    if !PromptQuickPadCtxMenuGUI
        return
    try {
        if !PromptQuickPadCtxMenuGUI.HasProp("Hwnd") || !PromptQuickPadCtxMenuGUI.Hwnd {
            PromptQuickPadCtxMenuGUI := 0
            SetTimer(PromptQuickPad_CheckCtxMenuMouse, 0)
            return
        }
        if !WinExist("ahk_id " . PromptQuickPadCtxMenuGUI.Hwnd) {
            PromptQuickPadCtxMenuGUI := 0
            SetTimer(PromptQuickPad_CheckCtxMenuMouse, 0)
            return
        }
    } catch {
        PromptQuickPadCtxMenuGUI := 0
        SetTimer(PromptQuickPad_CheckCtxMenuMouse, 0)
        return
    }
    try {
        MouseGetPos(&MX, &MY)
        WinGetPos(&WX, &WY, &WW, &WH, "ahk_id " . PromptQuickPadCtxMenuGUI.Hwnd)
    } catch {
        PromptQuickPadCtxMenuGUI := 0
        SetTimer(PromptQuickPad_CheckCtxMenuMouse, 0)
        return
    }
    if MX < WX || MX > WX + WW || MY < WY || MY > WY + WH {
        PromptQuickPad_CtxCancelHoverAnim()
        if PromptQuickPadCtxMenuSel > 0 {
            try {
                PromptQuickPadCtxMenuGUI["MenuItemBg" . PromptQuickPadCtxMenuSel].BackColor := "1a1a1a"
                PromptQuickPadCtxMenuGUI["MenuItemText" . PromptQuickPadCtxMenuSel].Opt("cff6600")
                if PromptQuickPadCtxMenuGUI.HasProp("MenuItemIcon" . PromptQuickPadCtxMenuSel)
                    PromptQuickPadCtxMenuGUI["MenuItemIcon" . PromptQuickPadCtxMenuSel].Opt("cff6600")
                PromptQuickPadCtxMenuSel := 0
            } catch {
            }
        }
        return
    }
    RelY := MY - WY
    MenuItemHeight := 35
    Padding := 10
    if RelY < Padding {
        PromptQuickPad_CtxCancelHoverAnim()
        if PromptQuickPadCtxMenuSel > 0 {
            try {
                PromptQuickPadCtxMenuGUI["MenuItemBg" . PromptQuickPadCtxMenuSel].BackColor := "1a1a1a"
                PromptQuickPadCtxMenuGUI["MenuItemText" . PromptQuickPadCtxMenuSel].Opt("cff6600")
                if PromptQuickPadCtxMenuGUI.HasProp("MenuItemIcon" . PromptQuickPadCtxMenuSel)
                    PromptQuickPadCtxMenuGUI["MenuItemIcon" . PromptQuickPadCtxMenuSel].Opt("cff6600")
                PromptQuickPadCtxMenuSel := 0
            } catch {
            }
        }
        return
    }
    ItemIndex := Floor((RelY - Padding) / MenuItemHeight) + 1
    try {
        if !PromptQuickPadCtxMenuGUI["MenuItemBg" . ItemIndex]
            return
    } catch {
        return
    }
    ItemY := Padding + (ItemIndex - 1) * MenuItemHeight
    if RelY >= ItemY && RelY < ItemY + MenuItemHeight
        PromptQuickPad_CtxItemHover(ItemIndex)
    else {
        PromptQuickPad_CtxCancelHoverAnim()
        if PromptQuickPadCtxMenuSel > 0 {
            try {
                PromptQuickPadCtxMenuGUI["MenuItemBg" . PromptQuickPadCtxMenuSel].BackColor := "1a1a1a"
                PromptQuickPadCtxMenuGUI["MenuItemText" . PromptQuickPadCtxMenuSel].Opt("cff6600")
                if PromptQuickPadCtxMenuGUI.HasProp("MenuItemIcon" . PromptQuickPadCtxMenuSel)
                    PromptQuickPadCtxMenuGUI["MenuItemIcon" . PromptQuickPadCtxMenuSel].Opt("cff6600")
                PromptQuickPadCtxMenuSel := 0
            } catch {
            }
        }
    }
}

PromptQuickPad_CloseCtxMenuIfOutside(*) {
    global PromptQuickPadCtxMenuGUI
    if !PromptQuickPadCtxMenuGUI
        return
    try {
        if !PromptQuickPadCtxMenuGUI.HasProp("Hwnd") || !PromptQuickPadCtxMenuGUI.Hwnd {
            PromptQuickPad_DestroyCtxMenu()
            return
        }
        MouseGetPos(&MX, &MY)
        WinGetPos(&WX, &WY, &WW, &WH, "ahk_id " . PromptQuickPadCtxMenuGUI.Hwnd)
        if MX < WX || MX > WX + WW || MY < WY || MY > WY + WH {
            if GetKeyState("LButton", "P") || GetKeyState("RButton", "P")
                PromptQuickPad_DestroyCtxMenu()
        }
    } catch {
        PromptQuickPad_DestroyCtxMenu()
    }
}

; 涓庢偓娴伐鍏锋爮 ShowDarkStylePopupMenuAt 鍚屾锛氶粦搴?+ 姗欒壊瀛?鍥炬爣 + 鎮仠姗欐潯锛堢嫭绔?GUI锛屼笉鍗?TrayMenuGUI锛?
PromptQuickPad_ShowDarkCtxMenuAt(MenuItems, posX, posY) {
    global PromptQuickPadCtxMenuGUI, PromptQuickPadCtxMenuSel
    PromptQuickPad_DestroyCtxMenu()

    MenuWidth := 220
    MenuItemHeight := 35
    Padding := 10
    MenuHeight := MenuItems.Length * MenuItemHeight + Padding * 2

    ScreenWidth := SysGet(78)
    ScreenHeight := SysGet(79)
    if posX < 10
        posX := 10
    else if posX + MenuWidth > ScreenWidth - 10
        posX := ScreenWidth - MenuWidth - 10
    if posY < 10
        posY := 10
    else if posY + MenuHeight > ScreenHeight - 10
        posY := ScreenHeight - MenuHeight - 10

    PromptQuickPadCtxMenuGUI := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    PromptQuickPadCtxMenuGUI.BackColor := "1a1a1a"
    PromptQuickPadCtxMenuGUI.Add("Text", "x0 y0 w" . MenuWidth . " h" . MenuHeight . " Background1a1a1a", "")
    PromptQuickPadCtxMenuSel := 0
    IconSize := 20
    IconLeftMargin := Padding + 8
    TextLeftMargin := IconLeftMargin + IconSize + 10

    Loop MenuItems.Length {
        Index := A_Index
        Item := MenuItems[Index]
        actFn := Item["Action"]
        ItemY := Padding + (Index - 1) * MenuItemHeight
        ItemBg := PromptQuickPadCtxMenuGUI.Add("Text", "x" . Padding . " y" . ItemY . " w" . (MenuWidth - Padding * 2) . " h" . MenuItemHeight . " Background1a1a1a vMenuItemBg" . Index, "")
        ItemBg.OnEvent("Click", PromptQuickPad_CtxMenuClick.Bind(actFn))
        if Item.Has("Icon") && Item["Icon"] != "" {
            IconText := PromptQuickPadCtxMenuGUI.Add("Text", "x" . IconLeftMargin . " y" . ItemY . " w" . IconSize . " h" . MenuItemHeight . " Center 0x200 cff6600 BackgroundTrans vMenuItemIcon" . Index, Item["Icon"])
            IconText.SetFont("s14", "Segoe UI Symbol")
            IconText.OnEvent("Click", PromptQuickPad_CtxMenuClick.Bind(actFn))
        }
        ItemText := PromptQuickPadCtxMenuGUI.Add("Text", "x" . TextLeftMargin . " y" . ItemY . " w" . (MenuWidth - TextLeftMargin - Padding) . " h" . MenuItemHeight . " Left 0x200 cff6600 BackgroundTrans vMenuItemText" . Index, Item["Text"])
        ItemText.SetFont("s11", "Segoe UI")
        ItemText.OnEvent("Click", PromptQuickPad_CtxMenuClick.Bind(actFn))
    }

    PromptQuickPadCtxMenuGUI.Show("x" . posX . " y" . posY . " w" . MenuWidth . " h" . MenuHeight)
    try LegacyGuard_RequestFocus("AIListPanel.CtxMenu", "ahk_id " . PromptQuickPadCtxMenuGUI.Hwnd, 50, "show_ctx_menu_focus")
    catch {
    }
    SetTimer(PromptQuickPad_CheckCtxMenuMouse, 50)
    SetTimer(PromptQuickPad_CloseCtxMenuIfOutside, 100)
}

PromptQuickPad_ShowRowContextMenu(RowOneBased, mx := unset, my := unset) {
    global PromptQuickPadListLV
    if RowOneBased < 1 || PromptQuickPadListLV = 0
        return
    try PromptQuickPadListLV.Modify(RowOneBased, "Select Vis")
    catch {
    }
    if !IsSet(mx) || !IsSet(my)
        DllCall("GetCursorPos", "int*", &mx := 0, "int*", &my := 0)
    r := RowOneBased
    menuItems := [
        Map("Text", "编辑提示词", "Icon", "✎", "Action", (*) => PromptQuickPad_EditItem(r)),
        Map("Text", "删除", "Icon", "✕", "Action", (*) => PromptQuickPad_DeleteItem(r))
    ]
    MenuItemHeight := 35
    Padding := 10
    MenuHeight := menuItems.Length * MenuItemHeight + Padding * 2
    MenuWidth := 220
    anchorX := mx
    anchorY := my
    posX := anchorX + 2
    posY := anchorY + 2
    ScreenWidth := SysGet(78)
    ScreenHeight := SysGet(79)
    if posY + MenuHeight > ScreenHeight - 10
        posY := anchorY - MenuHeight - 2
    if posX + MenuWidth > ScreenWidth - 10
        posX := anchorX - MenuWidth - 2
    PromptQuickPad_ShowDarkCtxMenuAt(menuItems, posX, posY)
}

PromptQuickPad_ApplyListViewStyles() {
    global PromptQuickPadListLV
    if PromptQuickPadListLV = 0
        return
    LVM_SETEXTENDEDLISTVIEWSTYLE := 0x1000 + 54
    ex := 0x20 | 0x8 | 0x10000  ; FULLROWSELECT | TRACKSELECT | DOUBLEBUFFER
    try SendMessage(LVM_SETEXTENDEDLISTVIEWSTYLE, 0xFFFFFFFF, ex, , "ahk_id " . PromptQuickPadListLV.Hwnd)
}

PromptQuickPad_OnSize(GuiObj, MinMax, Width, Height) {
    global AIListPanelWindowW, AIListPanelWindowH, AIListPanelIsResizing
    if MinMax = -1
        return
    AIListPanelIsResizing := true
    AIListPanelWindowW := Width
    AIListPanelWindowH := Height
    PromptQuickPad_RelayoutMainControls(Width, Height)
    AIListPanelIsResizing := false
    SaveAIListPanelPosition()
}

PromptQuickPad_LVContextMenu(GuiCtrl, Item, IsRightClick, X, Y) {
    row := Item >= 1 ? Item : PromptQuickPad_ListViewHitItemOneBased(GuiCtrl)
    if row < 1
        return
    pt := Buffer(8, 0)
    NumPut("int", Integer(X), pt, 0)
    NumPut("int", Integer(Y), pt, 4)
    if !DllCall("ClientToScreen", "ptr", GuiCtrl.Hwnd, "ptr", pt)
        return
    sx := NumGet(pt, 0, "int")
    sy := NumGet(pt, 4, "int")
    PromptQuickPad_ShowRowContextMenu(row, sx, sy)
}

PromptQuickPad_DeleteItem(row) {
    global PromptQuickPadFilteredIdx, PromptQuickPadMergedSnapshot, PromptQuickPadData
    if row < 1 || row > PromptQuickPadFilteredIdx.Length
        return
    mi := PromptQuickPadFilteredIdx[row]
    if mi < 1 || mi > PromptQuickPadMergedSnapshot.Length
        return
    entry := PromptQuickPadMergedSnapshot[mi]
    if MsgBox("确定删除该条提示词？（将从 prompts.json 移除）", "Prompt Quick-Pad", "YesNo Icon?") != "Yes"
        return
    uix := entry.Has("userIndex") ? Integer(entry["userIndex"]) : 0
    if uix >= 1 && uix <= PromptQuickPadData.Length {
        PromptQuickPadData.RemoveAt(uix)
        PromptQuickPad_SaveToDisk()
        PromptQuickPad_RefreshListView()
    }
}

PromptQuickPad_OpenReadOnlyViewer(Title, Content) {
    global AIListPanelColors
    opt := "+AlwaysOnTop +Resize"
    ownerHwnd := PromptQuickPad_GetHostHwnd()
    if ownerHwnd != 0
        opt .= " +Owner" . ownerHwnd
    g := Gui(opt, "查看 - " . (Title != "" ? Title : "内置/模板"))
    g.BackColor := AIListPanelColors.PopupBg
    top := g.Add("Text", "x12 y10 w540 h40 c" . AIListPanelColors.PopupTextBright . " Wrap",
        "此项来自设置中的快捷操作或模板库。若需改正文，请在「设置 -> 提示词」中编辑。")
    top.SetFont("s10", "Segoe UI")
    ed := g.Add("Edit", "x12 y54 w540 h300 Multi ReadOnly VScroll -Theme Background" . AIListPanelColors.PopupEditBg . " c" . AIListPanelColors.PopupEditText, Content)
    ed.SetFont("s10", "Consolas")
    bClose := g.Add("Button", "x12 y362 w100 h30 Default Backgroundff6600", "关闭")
    bClose.SetFont("s10 cffffff", "Segoe UI")
    bClose.OnEvent("Click", (*) => g.Destroy())
    g.OnEvent("Escape", (*) => g.Destroy())
    g.Show()
}

PromptQuickPad_OpenViewWeb(shell, mergedIndex) {
    payload := Map(
        "type", "itemModalOpen",
        "mode", "view",
        "mergedIndex", mergedIndex,
        "source", shell.Has("source") ? shell["source"] : "",
        "title", shell.Has("title") ? shell["title"] : "",
        "category", shell.Has("category") ? shell["category"] : "",
        "tags", shell.Has("tags") ? shell["tags"] : "",
        "hotkey", shell.Has("hotkey") ? shell["hotkey"] : "",
        "content", shell.Has("content") ? shell["content"] : "",
        "editable", false
    )
    try PQP_SendToWeb(payload)
    catch {
    }
}

PromptQuickPad_OpenEditWeb(shell, mergedIndex) {
    src := shell.Has("source") ? shell["source"] : ""
    allowTitle := true
    allowCategory := true
    allowTags := true
    payload := Map(
        "type", "itemModalOpen",
        "mode", "edit",
        "mergedIndex", mergedIndex,
        "source", src,
        "title", shell.Has("title") ? shell["title"] : "",
        "category", shell.Has("category") ? shell["category"] : "",
        "tags", shell.Has("tags") ? shell["tags"] : "",
        "hotkey", shell.Has("hotkey") ? shell["hotkey"] : "",
        "content", shell.Has("content") ? shell["content"] : "",
        "editable", true,
        "allowTitle", allowTitle,
        "allowCategory", allowCategory,
        "allowTags", allowTags
    )
    try PQP_SendToWeb(payload)
    catch {
    }
}

PromptQuickPad_SaveBuiltinPrompt(KeyName, NewContent) {
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize
    cfg := Nmer_ResolveConfigFile()
    if KeyName = "Explain" {
        Prompt_Explain := NewContent
        try IniWrite(NewContent, cfg, "Settings", "Prompt_Explain")
        catch {
        }
        try IniWrite(NewContent, cfg, "Prompts", "Explain")
        catch {
        }
        return
    }
    if KeyName = "Refactor" {
        Prompt_Refactor := NewContent
        try IniWrite(NewContent, cfg, "Settings", "Prompt_Refactor")
        catch {
        }
        try IniWrite(NewContent, cfg, "Prompts", "Refactor")
        catch {
        }
        return
    }
    if KeyName = "Optimize" {
        Prompt_Optimize := NewContent
        try IniWrite(NewContent, cfg, "Settings", "Prompt_Optimize")
        catch {
        }
        try IniWrite(NewContent, cfg, "Prompts", "Optimize")
        catch {
        }
    }
}

PromptQuickPad_SaveTemplateContent(TemplateID, NewTitle, NewCategory, NewContent) {
    global PromptTemplates
    for idx, T in PromptTemplates {
        try tid := T.ID
        catch
            tid := ""
        if tid != TemplateID
            continue
        try T.Title := NewTitle
        catch {
        }
        try T.Category := NewCategory
        catch {
        }
        try T.Content := NewContent
        catch {
        }
        PromptTemplates[idx] := T
        try SavePromptTemplates()
        catch {
        }
        try RefreshPromptListView()
        catch {
        }
        return true
    }
    return false
}

PromptQuickPad_SaveEditContent(eg, ed, entry) {
    entry["content"] := ed.Value
    PromptQuickPad_SaveToDisk()
    eg.Destroy()
    PromptQuickPad_RefreshListView()
}

PromptQuickPad_SaveBuiltinEdit(eg, ed, keyName) {
    PromptQuickPad_SaveBuiltinPrompt(keyName, ed.Value)
    eg.Destroy()
    PromptQuickPad_RefreshListView()
}

PromptQuickPad_SaveTemplateEdit(eg, titleEd, catEd, bodyEd, templateId) {
    title := Trim(titleEd.Value)
    cat := Trim(catEd.Value)
    if title = ""
        title := "未命名模板"
    if cat = ""
        cat := "未分类"
    if PromptQuickPad_SaveTemplateContent(templateId, title, cat, bodyEd.Value) {
        eg.Destroy()
        PromptQuickPad_RefreshListView()
        return
    }
    MsgBox("未找到要保存的模板。", "Prompt Quick-Pad", "Iconx")
}

PromptQuickPad_SaveItemEditFromWeb(msg) {
    mergedIndex := msg.Has("mergedIndex") ? Integer(msg["mergedIndex"]) : 0
    merged := PromptQuickPad_BuildMergedList()
    if mergedIndex < 1 || mergedIndex > merged.Length
        return
    shell := merged[mergedIndex]
    title := msg.Has("title") ? Trim(String(msg["title"])) : ""
    category := msg.Has("category") ? Trim(String(msg["category"])) : ""
    tags := msg.Has("tags") ? Trim(String(msg["tags"])) : ""
    content := msg.Has("content") ? String(msg["content"]) : ""
    global PromptQuickPadData
    uix := shell.Has("userIndex") ? Integer(shell["userIndex"]) : 0
    if uix < 1 || uix > PromptQuickPadData.Length
        return
    if title = ""
        title := "未命名"
    old := PromptQuickPadData[uix]
    src := old.Has("source") ? old["source"] : "json"
    idv := old.Has("id") ? old["id"] : ""
    PromptQuickPadData[uix] := PromptQuickPad_NormalizeEntry(Map(
        "id", idv,
        "source", src,
        "title", title,
        "tags", tags,
        "content", content,
        "category", category,
        "hotkey", shell.Has("hotkey") ? shell["hotkey"] : "",
        "enabled", true,
        "updatedAt", A_NowUTC
    ))
    PromptQuickPad_SaveToDisk()
    PromptQuickPad_RefreshListView()
}

PromptQuickPad_EditEntry(shell) {
    global PromptQuickPadData, AIListPanelColors
    src := shell.Has("source") ? shell["source"] : ""
    opt := "+AlwaysOnTop"
    ownerHwnd := PromptQuickPad_GetHostHwnd()
    if ownerHwnd != 0
        opt .= " +Owner" . ownerHwnd
    if src = "json" {
        uix := shell.Has("userIndex") ? Integer(shell["userIndex"]) : 0
        if uix < 1 || uix > PromptQuickPadData.Length
            return
        entry := PromptQuickPadData[uix]
        eg := Gui(opt, "缂栬緫鍐呭")
        eg.BackColor := AIListPanelColors.Background
        eg.SetFont("s10 c" . AIListPanelColors.Text, "Segoe UI")
        ed := eg.Add("Edit", "x10 y10 w420 h260 Multi WantReturn VScroll", entry["content"])
        ed.SetFont("s9", "Consolas")
        eg.Add("Button", "x10 y280 w100 h28 Default", "淇濆瓨").OnEvent("Click", (*) => PromptQuickPad_SaveEditContent(eg, ed, entry))
        eg.Add("Button", "x120 y280 w100 h28", "鍙栨秷").OnEvent("Click", (*) => eg.Destroy())
        eg.OnEvent("Escape", (*) => eg.Destroy())
        eg.Show()
        return
    }
    if src = "builtin" {
        title := shell.Has("title") ? shell["title"] : "快捷提示词"
        content := shell.Has("content") ? shell["content"] : ""
        builtinKey := ""
        hk := shell.Has("hotkey") ? shell["hotkey"] : ""
        if hk = "CapsLock+E"
            builtinKey := "Explain"
        else if hk = "CapsLock+R"
            builtinKey := "Refactor"
        else if hk = "CapsLock+O"
            builtinKey := "Optimize"
        if builtinKey = "" {
            PromptQuickPad_OpenReadOnlyViewer(title, content)
            return
        }
        eg := Gui(opt, "编辑全局提示词")
        eg.BackColor := AIListPanelColors.Background
        eg.SetFont("s10 c" . AIListPanelColors.Text, "Segoe UI")
        eg.Add("Text", "x10 y10 w420 h22", title . "（修改后同步到设置）")
        ed := eg.Add("Edit", "x10 y38 w420 h232 Multi WantReturn VScroll", content)
        ed.SetFont("s9", "Consolas")
        eg.Add("Button", "x10 y282 w100 h28 Default", "淇濆瓨").OnEvent("Click", (*) => PromptQuickPad_SaveBuiltinEdit(eg, ed, builtinKey))
        eg.Add("Button", "x120 y282 w100 h28", "鍙栨秷").OnEvent("Click", (*) => eg.Destroy())
        eg.OnEvent("Escape", (*) => eg.Destroy())
        eg.Show()
        return
    }
    if src = "template" {
        templateId := shell.Has("templateId") ? shell["templateId"] : ""
        title := shell.Has("title") ? shell["title"] : ""
        category := shell.Has("category") ? shell["category"] : ""
        content := shell.Has("content") ? shell["content"] : ""
        eg := Gui(opt, "缂栬緫妯℃澘")
        eg.BackColor := AIListPanelColors.Background
        eg.SetFont("s10 c" . AIListPanelColors.Text, "Segoe UI")
        eg.Add("Text", "x10 y10 w60 h22", "鏍囬")
        titleEd := eg.Add("Edit", "x80 y10 w350 h22", title)
        eg.Add("Text", "x10 y40 w60 h22", "鍒嗙被")
        catEd := eg.Add("Edit", "x80 y40 w350 h22", category)
        eg.Add("Text", "x10 y70 w60 h22", "姝ｆ枃")
        bodyEd := eg.Add("Edit", "x10 y94 w420 h180 Multi WantReturn VScroll", content)
        bodyEd.SetFont("s9", "Consolas")
        eg.Add("Button", "x10 y286 w100 h28 Default", "淇濆瓨").OnEvent("Click", (*) => PromptQuickPad_SaveTemplateEdit(eg, titleEd, catEd, bodyEd, templateId))
        eg.Add("Button", "x120 y286 w100 h28", "鍙栨秷").OnEvent("Click", (*) => eg.Destroy())
        eg.OnEvent("Escape", (*) => eg.Destroy())
        eg.Show()
        return
    }
    eg := Gui(opt, "鏌ョ湅鍐呭")
    eg.BackColor := AIListPanelColors.Background
    eg.SetFont("s10 c" . AIListPanelColors.Text, "Segoe UI")
    ed := eg.Add("Edit", "x10 y10 w420 h260 Multi ReadOnly VScroll", shell.Has("content") ? shell["content"] : "")
    ed.SetFont("s9", "Consolas")
    eg.Add("Button", "x10 y280 w100 h28 Default", "鍏抽棴").OnEvent("Click", (*) => eg.Destroy())
    eg.OnEvent("Escape", (*) => eg.Destroy())
    eg.Show()
}

PromptQuickPad_EditItem(row) {
    global PromptQuickPadFilteredIdx, PromptQuickPadMergedSnapshot
    if row < 1 || row > PromptQuickPadFilteredIdx.Length
        return
    mi := PromptQuickPadFilteredIdx[row]
    if mi < 1 || mi > PromptQuickPadMergedSnapshot.Length
        return
    shell := PromptQuickPadMergedSnapshot[mi]
    PromptQuickPad_EditEntry(shell)
}

PromptQuickPad_CenterAndMaximizeOnActiveMonitor() {
    global AIListPanelWindowX, AIListPanelWindowY, AIListPanelWindowW, AIListPanelWindowH
    gGui := PromptQuickPad_GetFollowGui()
    if !gGui
        return
    mx := 0, my := 0
    try MouseGetPos(&mx, &my)
    monCount := 1
    try monCount := MonitorGetCount()
    targetMon := 1
    try targetMon := MonitorGetPrimary()
    Loop monCount {
        try {
            MonitorGetWorkArea(A_Index, &ml, &mt, &mr, &mb)
            if mx >= ml && mx < mr && my >= mt && my < mb {
                targetMon := A_Index
                break
            }
        } catch {
        }
    }
    try MonitorGetWorkArea(targetMon, &left, &top, &right, &bottom)
    catch {
        left := 0
        top := 0
        right := SysGet(0)
        bottom := SysGet(1)
    }
    workW := right - left
    workH := bottom - top
    normalW := AIListPanelWindowW > 0 ? AIListPanelWindowW : 560
    normalH := AIListPanelWindowH > 0 ? AIListPanelWindowH : 560
    if normalW < 440
        normalW := 440
    if normalH < 460
        normalH := 460
    if normalW > workW
        normalW := workW
    if normalH > workH
        normalH := workH
    centerX := left + (workW - normalW) // 2
    centerY := top + (workH - normalH) // 2
    AIListPanelWindowX := centerX
    AIListPanelWindowY := centerY
    AIListPanelWindowW := normalW
    AIListPanelWindowH := normalH
    try gGui.Show("x" . centerX . " y" . centerY . " w" . normalW . " h" . normalH)
    catch {
    }
    try WinMaximize("ahk_id " . gGui.Hwnd)
    catch {
    }
}

ShowAIListPanel_WebView(openForCapture := false, forceCenterMaximize := false) {
    global AIListPanelIsVisible, AIListPanelWindowX, AIListPanelWindowY, AIListPanelWindowW, AIListPanelWindowH
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY
    global AIListPanelEscHotkey
    global PromptQuickPad_PasteTargetHwnd
    global PromptQuickPad_CaptureChromeVisible

    if AIListPanelIsVisible && PQP_IsVisible() {
        if forceCenterMaximize {
            try WinRestore("ahk_id " . PQP_GetGuiHwnd())
            catch {
            }
            PromptQuickPad_CenterAndMaximizeOnActiveMonitor()
            try LegacyGuard_RequestFocus("AIListPanel.PQP", "ahk_id " . PQP_GetGuiHwnd(), 50, "restore_pqp_focus")
            catch {
            }
            return
        }
        HideAIListPanel()
        return
    }

    PromptQuickPad_CaptureChromeVisible := openForCapture
    prevHwnd := DllCall("GetForegroundWindow", "ptr")
    if prevHwnd && !PromptQuickPad_CapsB_IsOurGuiWindow(prevHwnd)
        PromptQuickPad_PasteTargetHwnd := prevHwnd

    LoadAIListPanelPosition()

    savedX := AIListPanelWindowX
    savedY := AIListPanelWindowY
    savedW := AIListPanelWindowW
    savedH := AIListPanelWindowH
    if savedX != 0 && savedY != 0 {
        panelX := savedX
        panelY := savedY
        panelW := savedW > 0 ? savedW : 520
        panelH := savedH > 0 ? savedH : 620
    } else if FloatingToolbarGUI != 0 {
        try {
            FloatingToolbarGUI.GetPos(&toolbarX, &toolbarY, &toolbarW, &toolbarH)
            panelW := AIListPanelWindowW > 0 ? AIListPanelWindowW : 560
            panelH := AIListPanelWindowH > 0 ? AIListPanelWindowH : 620
            panelX := toolbarX
            panelY := toolbarY - panelH
            if panelY < 0
                panelY := toolbarY + toolbarH + 5
        } catch {
            ScreenWidth := SysGet(0)
            ScreenHeight := SysGet(1)
            panelW := 560
            panelH := 620
            panelX := (ScreenWidth - panelW) // 2
            panelY := (ScreenHeight - panelH) // 2
        }
    } else {
        ScreenWidth := SysGet(0)
        ScreenHeight := SysGet(1)
        panelW := 560
        panelH := 620
        panelX := (ScreenWidth - panelW) // 2
        panelY := (ScreenHeight - panelH) // 2
    }
    AIListPanelWindowX := panelX
    AIListPanelWindowY := panelY
    AIListPanelWindowW := panelW
    AIListPanelWindowH := panelH

    SurfaceIntent_Open("prompt_quick_pad")
    if forceCenterMaximize
        PromptQuickPad_CenterAndMaximizeOnActiveMonitor()

    AIListPanelIsVisible := true

    if !openForCapture
        PromptQuickPad_SetCaptureChromeVisible(false, false)
    PromptQuickPad_RefreshListView()
    SetTimer(AIListPanelFollowToolbar, 100)

    hostHwnd := PromptQuickPad_GetHostHwnd()
    try {
        HotIfWinActive("ahk_id " . hostHwnd)
        AIListPanelEscHotkey := Hotkey("Escape", PromptQuickPad_OnEsc, "On")
        HotIfWinActive()
    } catch {
    }
}

ShowAIListPanel(openForCapture := false, forceCenterMaximize := false) {
    if PromptQuickPad_ShouldUseWebView() {
        ShowAIListPanel_WebView(openForCapture, forceCenterMaximize)
        return
    }
    LegacyPromptQuickPad_ShowNative(openForCapture, forceCenterMaximize)
}

HideAIListPanel() {
    global AIListPanelGUI, AIListPanelIsVisible, AIListPanelEnterHotkey, AIListPanelEscHotkey, PromptQuickPad_CaptureChromeVisible

    PromptQuickPad_DestroyCtxMenu()

    if PromptQuickPad_ShouldUseWebView() {
        try SaveAIListPanelPosition()
        catch {
        }
        try {
            h := PromptQuickPad_GetHostHwnd()
            if h {
                HotIfWinActive("ahk_id " . h)
                if AIListPanelEscHotkey != 0 {
                    AIListPanelEscHotkey.Off()
                    AIListPanelEscHotkey := 0
                }
                HotIfWinActive()
            }
        } catch {
            try HotIfWinActive()
            catch {
            }
        }
        SurfaceIntent_Close("prompt_quick_pad")
        AIListPanelIsVisible := false
        PromptQuickPad_CaptureChromeVisible := false
        SetTimer(AIListPanelFollowToolbar, 0)
        return
    }

    LegacyPromptQuickPad_HideNative()
}

ToggleAIListPanel() {
    global AIListPanelIsVisible
    if AIListPanelIsVisible
        HideAIListPanel()
    else
        ShowAIListPanel(false)
}

ShowPromptQuickPadListOnly() {
    global AIListPanelIsVisible, AIListPanelGUI, AIListPanelSearchInput
    ShowAIListPanel(true, true)
    if !AIListPanelIsVisible
        return
    if PromptQuickPad_ShouldUseWebView() {
        PromptQuickPad_SetCaptureExpanded(false, false)
        PromptQuickPad_UpdateCaptureToggleText()
        PromptQuickPad_ApplyCaptureControlsVisibility()
        PromptQuickPad_RelayoutMainControls()
        return
    }
    if AIListPanelGUI = 0
        return
    ; 鎮诞宸ュ叿鏍?Prompt锛氭樉绀哄悓娆炬姌鍙犳爮锛屼絾榛樿淇濇寔鏀惰捣
    PromptQuickPad_SetCaptureExpanded(false, false)
    PromptQuickPad_UpdateCaptureToggleText()
    PromptQuickPad_ApplyCaptureControlsVisibility()
    PromptQuickPad_RelayoutMainControls()
    if AIListPanelSearchInput != 0 {
        try AIListPanelSearchInput.Focus()
        catch {
        }
    }
}


#Include "LegacyPromptQuickPadGui.ahk"

CreateAIListPanelGUI() {
    if PromptQuickPad_ShouldUseWebView()
        return
    LegacyPromptQuickPad_CreateGUI()
}

AIListPanelFollowToolbar() {
    global AIListPanelIsVisible, FloatingToolbarGUI, FloatingToolbarIsVisible
    global AIListPanelDragging, AIListPanelUserMoving

    gPanel := PromptQuickPad_GetFollowGui()
    if !AIListPanelIsVisible || !gPanel || !FloatingToolbarIsVisible || FloatingToolbarGUI = 0
        return
    if AIListPanelDragging || AIListPanelUserMoving
        return

    try {
        FloatingToolbarGUI.GetPos(&toolbarX, &toolbarY, &toolbarW, &toolbarH)
        gPanel.GetPos(&panelX, &panelY, &panelW, &panelH)
        idealX := toolbarX
        idealY := toolbarY - panelH
        ScreenHeight := SysGet(1)
        if idealY < 0
            idealY := toolbarY + toolbarH + 5
        panelCenterX := panelX + panelW // 2
        panelCenterY := panelY + panelH // 2
        idealCenterX := idealX + panelW // 2
        idealCenterY := idealY + panelH // 2
        if Abs(panelCenterX - idealCenterX) <= 30 && Abs(panelCenterY - idealCenterY) <= 30 {
            if panelX != idealX || panelY != idealY {
                gPanel.Move(idealX, idealY)
                AIListPanelWindowX := idealX
                AIListPanelWindowY := idealY
                SaveAIListPanelPosition()
            }
        }
    } catch {
    }
}

SaveAIListPanelPosition() {
    global AIListPanelGUI, AIListPanelWindowX, AIListPanelWindowY, AIListPanelWindowW, AIListPanelWindowH
    gSave := PromptQuickPad_GetFollowGui()
    if !gSave
        return
    try {
        gSave.GetPos(&x, &y, &w, &h)
        AIListPanelWindowX := x
        AIListPanelWindowY := y
        AIListPanelWindowW := w
        AIListPanelWindowH := h
        ConfigFile := Nmer_ResolveConfigFile()
        IniWrite(String(x), ConfigFile, "WindowPositions", "AIListPanel_X")
        IniWrite(String(y), ConfigFile, "WindowPositions", "AIListPanel_Y")
        IniWrite(String(w), ConfigFile, "WindowPositions", "AIListPanel_W")
        IniWrite(String(h), ConfigFile, "WindowPositions", "AIListPanel_H")
    } catch {
    }
}

LoadAIListPanelPosition() {
    global AIListPanelWindowX, AIListPanelWindowY, AIListPanelWindowW, AIListPanelWindowH
    try {
        ConfigFile := Nmer_ResolveConfigFile()
        ScreenWidth := SysGet(0)
        ScreenHeight := SysGet(1)
        savedX := IniRead(ConfigFile, "WindowPositions", "AIListPanel_X", "")
        savedY := IniRead(ConfigFile, "WindowPositions", "AIListPanel_Y", "")
        savedW := IniRead(ConfigFile, "WindowPositions", "AIListPanel_W", "")
        savedH := IniRead(ConfigFile, "WindowPositions", "AIListPanel_H", "")

        if savedX != "" && savedY != "" && savedX != "ERROR" && savedY != "ERROR" {
            AIListPanelWindowX := Integer(savedX)
            AIListPanelWindowY := Integer(savedY)
            AIListPanelWindowW := (savedW != "" && savedW != "ERROR") ? Integer(savedW) : 520
            AIListPanelWindowH := (savedH != "" && savedH != "ERROR") ? Integer(savedH) : 560
        } else {
            AIListPanelWindowX := 0
            AIListPanelWindowY := 0
            AIListPanelWindowW := 520
            AIListPanelWindowH := 560
        }
        if AIListPanelWindowW < 400
            AIListPanelWindowW := 400
        if AIListPanelWindowH < 520
            AIListPanelWindowH := 520
        if AIListPanelWindowX < 0 || AIListPanelWindowX > ScreenWidth - 50
            AIListPanelWindowX := 0
        if AIListPanelWindowY < 0 || AIListPanelWindowY > ScreenHeight - 50
            AIListPanelWindowY := 0
    } catch {
        AIListPanelWindowX := 0
        AIListPanelWindowY := 0
        AIListPanelWindowW := 520
        AIListPanelWindowH := 560
    }
}

MinimizeAIListPanelToEdge() {
    global AIListPanelIsVisible, AIListPanelIsMinimized, AIListPanelWindowX, AIListPanelWindowY
    gPanel := PromptQuickPad_GetFollowGui()
    if !AIListPanelIsVisible || !gPanel
        return
    gPanel.GetPos(&currentX, &currentY, &currentW, &currentH)
    ScreenWidth := SysGet(0)
    ScreenHeight := SysGet(1)
    distLeft := currentX
    distRight := ScreenWidth - (currentX + currentW)
    distTop := currentY
    distBottom := ScreenHeight - (currentY + currentH)
    minDist := distLeft
    targetX := 0
    targetY := currentY
    if distRight < minDist {
        minDist := distRight
        targetX := ScreenWidth - currentW
        targetY := currentY
    }
    if distTop < minDist {
        minDist := distTop
        targetX := currentX
        targetY := 0
    }
    if distBottom < minDist {
        targetX := currentX
        targetY := ScreenHeight - currentH
    }
    gPanel.Move(targetX, targetY)
    AIListPanelWindowX := targetX
    AIListPanelWindowY := targetY
    AIListPanelIsMinimized := true
    SaveAIListPanelPosition()
}

RestoreAIListPanel() {
    global AIListPanelIsMinimized
    AIListPanelIsMinimized := false
}

; 澶嶅埗褰撳墠閫夊尯骞舵墦寮€鏀跺綍鍖?
PromptQuickPad_QuickCapture(*) {
    oldClip := ClipboardAll()
    try {
        A_Clipboard := ""
        SendInput("^c")
        if !ClipWait(0.2) {
            ; HandleCapsLockB 鍦ㄦ棤閫夊尯鏃朵笉浼氭墦寮€闈㈡澘锛涚洿鎺ユ墦寮€鏀跺綍鍖轰緵鎵嬪姩绮樿创銆?
            try PromptQuickPad_OpenCaptureDraft("", true)
            catch as err
                try TrayTip("打开 Prompt Quick-Pad 失败:`n" . err.Message, "Prompt Quick-Pad", "Iconx 2")
                catch as _e {
                }
            TrayTip("未获取到选中文本，已打开采集区，可手动粘贴。", "Prompt Quick-Pad", "Iconi 1")
            return
        }
        PromptQuickPad_OpenCaptureDraft(A_Clipboard, true)
    } finally {
        A_Clipboard := oldClip
    }
}

; 鐢变富鑴氭湰鍦ㄥ姞杞介厤缃悗璋冪敤锛氭牴鎹?PromptQuickCaptureHotkey 娉ㄥ唽/娉ㄩ攢
PromptQuickPad_RegisterCaptureHotkey() {
    global PromptQuickPadCaptureHotkeyObj
    global PromptQuickCaptureHotkey
    if PromptQuickPadCaptureHotkeyObj != 0 {
        try PromptQuickPadCaptureHotkeyObj.Off()
        catch {
        }
        PromptQuickPadCaptureHotkeyObj := 0
    }
    hk := Trim(PromptQuickCaptureHotkey)
    if hk = ""
        return
    try {
        PromptQuickPadCaptureHotkeyObj := Hotkey(hk, PromptQuickPad_QuickCapture, "On")
    } catch as e {
        TrayTip("Prompt 采集热键无效: " . hk . " - " . e.Message, "Prompt Quick-Pad", "Iconx 2")
    }
}

PromptQuickPad_GetJsonHelpBody() {
    return "
(
文件位置：脚本目录下的 prompts.json，UTF-8 编码。

推荐使用 v2 对象结构（统一管理、便于云同步）：
{
  ""version"": 2,
  ""updatedAt"": ""2026-05-08T00:00:00Z"",
  ""entries"": [
    {
      ""id"": ""pqp_xxx"",
      ""source"": ""json"",
      ""title"": ""代码说明"",
      ""content"": ""请解释以下代码..."",
      ""category"": ""文档"",
      ""tags"": ""doc,zh"",
      ""hotkey"": """",
      ""enabled"": true,
      ""updatedAt"": ""2026-05-08T00:00:00Z""
    }
  ],
  ""settings"": { ""selectedCategory"": ""全部"" },
  ""sync"": {
    ""cloudEnabled"": false,
    ""lastSyncAt"": """",
    ""syncEndpoint"": ""pqp://local-sync""
  }
}

兼容说明：
  - 旧格式（顶层数组）仍可导入，读取时会自动归一化为 entries。
  - 提示词条目统一由 prompts.json 托管。
)"
}

PromptQuickPad_ShowJsonFormatHelp(*) {
    if PromptQuickPad_ShouldUseWebView() && PQP_IsReady() {
        payload := Map(
            "type", "jsonHelpOpen",
            "body", PromptQuickPad_GetJsonHelpBody()
        )
        try PQP_SendToWeb(payload)
        catch {
        }
        return
    }
    global AIListPanelColors
    opt := "+AlwaysOnTop +Resize"
    ownerHwnd := PromptQuickPad_GetHostHwnd()
    if ownerHwnd != 0
        opt .= " +Owner" . ownerHwnd
    g := Gui(opt, "prompts.json 格式说明")
    g.BackColor := AIListPanelColors.PopupBg
    top := g.Add("Text", "x12 y10 w560 h44 c" . AIListPanelColors.PopupTextBright . " Wrap",
        "以下为 prompts.json v2 结构说明。导入/导出使用相同格式。")
    top.SetFont("s10", "Segoe UI")
    ed := g.Add("Edit", "x12 y60 w560 h352 Multi ReadOnly VScroll WantReturn -Theme Background" . AIListPanelColors.PopupEditBg . " c" . AIListPanelColors.PopupEditText, PromptQuickPad_GetJsonHelpBody())
    ed.SetFont("s10", "Consolas")
    bClose := g.Add("Button", "x12 y422 w100 h30 Default Backgroundff6600", "关闭")
    bClose.SetFont("s10 cffffff", "Segoe UI")
    bClose.OnEvent("Click", (*) => g.Destroy())
    g.OnEvent("Escape", (*) => g.Destroy())
    g.Show()
}

PromptQuickPad_DoImport(*) {
    global PromptQuickPadData
    p := FileSelect(1, A_ScriptDir, "閫夋嫨瑕佸鍏ョ殑 JSON", "JSON (*.json)")
    if p = ""
        return
    try
        raw := FileRead(p, "UTF-8")
    catch {
        MsgBox("无法读取该文件。", "导入提示词", "Iconx")
        return
    }
    try
        parsed := Jxon_Load(raw)
    catch {
        MsgBox("JSON 解析失败，请检查语法。", "导入提示词", "Iconx")
        return
    }
    importEntries := []
    if (parsed is Array)
        importEntries := parsed
    else if (parsed is Map && parsed.Has("entries") && parsed["entries"] is Array)
        importEntries := parsed["entries"]
    else {
        MsgBox("文件必须是 JSON 数组或 v2 对象（含 entries 数组）。", "导入提示词", "Iconx")
        return
    }
    ans := MsgBox("将读取 " . importEntries.Length . " 条记录。`n`n是 = 合并到现有末尾`n否 = 清空后仅保留导入内容`n取消 = 放弃", "导入提示词", "YesNoCancel Icon?")
    if ans = "Cancel"
        return
    if ans = "No"
        PromptQuickPadData := []
    for item in importEntries {
        if item is Map
            PromptQuickPadData.Push(PromptQuickPad_NormalizeEntry(item))
    }
    PromptQuickPad_SaveToDisk()
    PromptQuickPad_RefreshListView()
    TrayTip("导入完成", "Prompt Quick-Pad", "Iconi 1")
}

PromptQuickPad_DoExport(*) {
    def := A_ScriptDir . "\prompts_export_" . A_Now . ".json"
    p := FileSelect("S16", def, "瀵煎嚭 prompts.json", "JSON (*.json)")
    if p = ""
        return
    try {
        clean := PromptQuickPad_BuildCleanArrayForFile()
        f := FileOpen(p, "w", "UTF-8")
        if !f {
            MsgBox("无法创建或写入文件。", "导出提示词", "Iconx")
            return
        }
        f.Write(Jxon_Dump(clean))
        f.Close()
        TrayTip("已导出", "Prompt Quick-Pad", "Iconi 1")
    } catch as e {
        MsgBox("导出失败: " . e.Message, "导出提示词", "Iconx")
    }
}

PromptQuickPad_SyncExportSnapshot() {
    return PromptQuickPad_BuildCleanArrayForFile()
}

PromptQuickPad_SyncImportSnapshot(snapshot, merge := true) {
    global PromptQuickPadData
    arr := []
    if (snapshot is Array)
        arr := snapshot
    else if (snapshot is Map && snapshot.Has("entries") && snapshot["entries"] is Array)
        arr := snapshot["entries"]
    else
        return false
    if !merge
        PromptQuickPadData := []
    for item in arr {
        if item is Map
            PromptQuickPadData.Push(PromptQuickPad_NormalizeEntry(item))
    }
    PromptQuickPad_SaveToDisk()
    PromptQuickPad_RefreshListView()
    return true
}

PromptQuickPad_SyncGetEntriesSince(utcTs := "") {
    global PromptQuickPadData
    out := []
    for item in PromptQuickPadData {
        if !(item is Map)
            continue
        if (utcTs = "") {
            out.Push(item)
            continue
        }
        t := item.Has("updatedAt") ? String(item["updatedAt"]) : ""
        if (t != "" && t >= utcTs)
            out.Push(item)
    }
    return out
}

InitAIListPanel() {
}

; WM_NOTIFY 鐢变富鑴氭湰 OnClipboardListViewWMNotify 杞彂鍒?PromptQuickPad_OnWmNotify锛堥伩鍏嶈鐩栧叏灞€鐩戝惉锛?
