; ChordPad.ahk — CapsLock 长按临时和弦键盘（可视选择，不抢焦点）

#Requires AutoHotkey v2.0
#Include FuncExists.ahk
global g_ChordPad_Gui := 0
global g_ChordPad_WV2 := 0
global g_ChordPad_Ctrl := 0
global g_ChordPad_Ready := false
global g_ChordPad_Visible := false
global g_ChordPad_X := 0
global g_ChordPad_Y := 0
global g_ChordPad_W := 0
global g_ChordPad_H := 0
global g_ChordPad_UseSavedPos := false
global g_ChordPad_DragActive := false
global g_ChordPad_DragAnchorX := 0
global g_ChordPad_DragAnchorY := 0
global g_ChordPad_Scale := 1.0
global g_ChordPad_BaseW := 920
global g_ChordPad_BaseH := 480
global g_ChordPad_ScaleMin := 0.82
global g_ChordPad_ScaleMax := 1.28
global g_ChordPad_CapsWatchOn := false
global g_ChordPad_Pinned := false
global g_ChordPad_Compact := false

; 模块可能被 #Include 于脚本较后位置；入口须先确保全局已赋值，避免 IsSet 为 false 时读取报错
ChordPad_InitGlobals() {
    global g_ChordPad_Gui, g_ChordPad_WV2, g_ChordPad_Ctrl, g_ChordPad_Ready, g_ChordPad_Visible
    global g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, g_ChordPad_UseSavedPos
    global g_ChordPad_DragActive, g_ChordPad_DragAnchorX, g_ChordPad_DragAnchorY, g_ChordPad_Scale
    global g_ChordPad_BaseW, g_ChordPad_BaseH, g_ChordPad_ScaleMin, g_ChordPad_ScaleMax, g_ChordPad_CapsWatchOn
    global g_ChordPad_Pinned, g_ChordPad_Compact
    if !IsSet(g_ChordPad_Gui)
        g_ChordPad_Gui := 0
    if !IsSet(g_ChordPad_WV2)
        g_ChordPad_WV2 := 0
    if !IsSet(g_ChordPad_Ctrl)
        g_ChordPad_Ctrl := 0
    if !IsSet(g_ChordPad_Ready)
        g_ChordPad_Ready := false
    if !IsSet(g_ChordPad_Visible)
        g_ChordPad_Visible := false
    if !IsSet(g_ChordPad_X)
        g_ChordPad_X := 0
    if !IsSet(g_ChordPad_Y)
        g_ChordPad_Y := 0
    if !IsSet(g_ChordPad_W)
        g_ChordPad_W := 0
    if !IsSet(g_ChordPad_H)
        g_ChordPad_H := 0
    if !IsSet(g_ChordPad_UseSavedPos)
        g_ChordPad_UseSavedPos := false
    if !IsSet(g_ChordPad_DragActive)
        g_ChordPad_DragActive := false
    if !IsSet(g_ChordPad_DragAnchorX)
        g_ChordPad_DragAnchorX := 0
    if !IsSet(g_ChordPad_DragAnchorY)
        g_ChordPad_DragAnchorY := 0
    if !IsSet(g_ChordPad_Scale)
        g_ChordPad_Scale := 1.0
    if !IsSet(g_ChordPad_BaseW)
        g_ChordPad_BaseW := 920
    if !IsSet(g_ChordPad_BaseH)
        g_ChordPad_BaseH := 480
    if !IsSet(g_ChordPad_ScaleMin)
        g_ChordPad_ScaleMin := 0.82
    if !IsSet(g_ChordPad_ScaleMax)
        g_ChordPad_ScaleMax := 1.28
    if !IsSet(g_ChordPad_CapsWatchOn)
        g_ChordPad_CapsWatchOn := false
    if !IsSet(g_ChordPad_Pinned)
        g_ChordPad_Pinned := false
    if !IsSet(g_ChordPad_Compact)
        g_ChordPad_Compact := false
}

ChordPad_HasGui() {
    ChordPad_InitGlobals()
    global g_ChordPad_Gui
    return IsObject(g_ChordPad_Gui) && g_ChordPad_Gui
}

; Lucide 图标名须与 assets/js/lucide-registry.js 中 CHORD_* 映射一致
ChordPad_DefaultCatalog() {
    return [
        Map("action", "W", "label", "方向上", "cmdId", "ch_w", "defaultKey", "w", "iconLucide", "arrow-up"),
        Map("action", "A", "label", "方向左", "cmdId", "ch_a", "defaultKey", "a", "iconLucide", "arrow-left"),
        Map("action", "S", "label", "方向下", "cmdId", "ch_s", "defaultKey", "s", "iconLucide", "arrow-down"),
        Map("action", "D", "label", "方向右", "cmdId", "ch_d", "defaultKey", "d", "iconLucide", "arrow-right"),
        Map("action", "C", "label", "收集", "cmdId", "ch_c", "defaultKey", "c", "iconLucide", "inbox"),
        Map("action", "V", "label", "剪贴板", "cmdId", "ch_v", "defaultKey", "v", "iconLucide", "clipboard-list"),
        Map("action", "X", "label", "历史", "cmdId", "ch_x", "defaultKey", "x", "iconLucide", "history"),
        Map("action", "E", "label", "解释", "cmdId", "ch_e", "defaultKey", "e", "iconLucide", "circle-question-mark"),
        Map("action", "Q", "label", "设置", "cmdId", "ch_q", "defaultKey", "q", "iconLucide", "settings"),
        Map("action", "F", "label", "搜索", "cmdId", "ch_f", "defaultKey", "f", "iconLucide", "search"),
        Map("action", "R", "label", "重构", "cmdId", "ch_r", "defaultKey", "r", "iconLucide", "git-branch"),
        Map("action", "O", "label", "优化", "cmdId", "ch_o", "defaultKey", "o", "iconLucide", "sparkles"),
    ]
}

ChordPad_IconLucideFor(action := "", cmdId := "") {
    action := StrUpper(Trim(String(action)))
    cmdId := Trim(String(cmdId))
    for item in ChordPad_DefaultCatalog() {
        if (action != "" && item["action"] = action)
            return item["iconLucide"]
        if (cmdId != "" && item["cmdId"] = cmdId)
            return item["iconLucide"]
    }
    if (cmdId != "") {
        if RegExMatch(cmdId, "i)^sc_cat_")
            return "layout-grid"
        if RegExMatch(cmdId, "i)^sc_eng_")
            return "search"
        if RegExMatch(cmdId, "i)^sc_filter_")
            return "filter"
        if RegExMatch(cmdId, "i)^sc_")
            return "search"
        if RegExMatch(cmdId, "i)^cp_")
            return "clipboard-list"
        if RegExMatch(cmdId, "i)^qa_")
            return "settings"
        if RegExMatch(cmdId, "i)^ftb_|^ftm_|^tray_")
            return "panel-top"
    }
    return "search"
}

ChordPad_EnsureVkData() {
    if FuncExists("_LoadCommands")
        try _LoadCommands()
    if FuncExists("LoadCommandsConfig")
        try LoadCommandsConfig()
}

ChordPad_ResolveActiveScenarioId() {
    if FuncExists("IsSearchCenterActive") {
        try {
            if IsSearchCenterActive()
                return "search"
        } catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }
    if FuncExists("VK_IsClipboardPanelActive") {
        try {
            if VK_IsClipboardPanelActive()
                return "clipboard"
        } catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }
    if FuncExists("IsScreenshotEditorActive") {
        try {
            if IsScreenshotEditorActive()
                return "screenshot"
        } catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }
    return "hotkeys"
}

ChordPad_ScenarioLabel(scenarioId) {
    switch Trim(String(scenarioId)) {
        case "search": return "搜索中心"
        case "clipboard": return "剪贴板"
        case "prompts": return "提示词"
        case "scratchpad": return "草稿本"
        case "screenshot": return "智能截图"
        case "settings": return "设置中心"
        case "hotkeys": return "快捷键"
        case "cursor": return "Cursor"
        case "cloudplayer": return "牛马云"
        case "ai": return "牛马 AI"
        default: return "快捷键"
    }
}

ChordPad_PresetCmdIdsForScenario(scenarioId) {
    scenarioId := Trim(String(scenarioId))
    switch scenarioId {
        case "search":
            return [
                "ch_q", "ch_w", "ch_e", "ch_r", "ch_a", "ch_s", "ch_d", "ch_z", "ch_x", "ch_c", "ch_v", "ch_f", "ch_g",
                "sc_activate_search",
                "sc_cat_ai", "sc_cat_cli", "sc_cat_academic", "sc_cat_baidu", "sc_cat_image", "sc_cat_audio",
                "sc_cat_video", "sc_cat_book", "sc_cat_price", "sc_cat_medical", "sc_cat_cloud",
                "sc_eng_deepseek", "sc_eng_yuanbao", "sc_eng_doubao", "sc_eng_zhipu", "sc_eng_mita", "sc_eng_wenxin",
                "sc_eng_qianwen", "sc_eng_kimi", "sc_eng_perplexity", "sc_eng_copilot", "sc_eng_chatgpt", "sc_eng_grok",
                "sc_eng_you", "sc_eng_claude", "sc_eng_monica", "sc_eng_webpilot", "sc_eng_wepilot",
                "sc_filter_text", "sc_filter_fulltext", "sc_filter_clipboard", "sc_filter_prompt", "sc_filter_config",
                "sc_filter_pinned"
            ]
        case "clipboard":
            return [
                "ch_q", "ch_w", "ch_e", "ch_r", "ch_a", "ch_s", "ch_d",
                "cp_search", "cp_clear_search", "ch_v", "cp_show_shortcuts",
                "ch_c", "ch_x", "qa_copy", "qa_paste", "qa_clipboard"
            ]
        case "prompts":
            return [
                "ch_q", "ch_w", "ch_e", "ch_r", "ch_a", "ch_s", "ch_d", "ch_f",
                "ch_z", "ch_x", "ch_c", "ch_v", "ch_g", "ch_t", "ch_p", "ch_b",
                "ch_1", "ch_2", "ch_3", "ch_4"
            ]
        case "scratchpad":
            return [
                "ch_q", "ch_w", "ch_e", "ch_r", "ch_a", "ch_s", "ch_d", "ch_f",
                "ch_z", "ch_x", "ch_c", "ch_v", "hub_capsule", "ftb_scratchpad"
            ]
        case "screenshot":
            return [
                "ss_search", "ss_copy", "ss_save", "ss_ocr", "ss_ai", "ss_close",
                "ch_f", "ch_c", "ch_v", "ch_x", "ftb_screenshot"
            ]
        case "hotkeys":
            return [
                "ch_w", "ch_s", "ch_a", "ch_d", "ch_f", "ch_x", "ch_q", "hub_capsule", "ch_t", "ch_p", "ch_r", "ch_b", "ch_g",
                "ch_c", "ch_v", "ch_e", "ch_o", "ch_z", "sys_show_vk",
                "ftm_reset_scale", "ftm_search_center", "ftm_clipboard", "ftm_minimize_to_edge", "ftm_exit_app",
                "ftm_hide_toolbar", "ftm_open_config", "ftm_toggle_toolbar", "ftm_reload_script",
                "tray_show_search", "tray_show_clipboard", "tray_show_screenshot", "tray_show_config",
                "tray_toggle_toolbar", "tray_hide_toolbar", "tray_reload_script", "tray_restart_clean", "tray_exit_app"
            ]
        default:
            return []
    }
}

ChordPad_CollectScenarioCmdIds(scenarioId) {
    global g_Commands
    out := Map()
    for cid in ChordPad_PresetCmdIdsForScenario(scenarioId) {
        x := Trim(String(cid))
        if (x != "")
            out[x] := true
    }
    if !(g_Commands is Map) || !g_Commands.Has("CommandList") || !(g_Commands["CommandList"] is Map)
        return out
    cmdList := g_Commands["CommandList"]
    if g_Commands.Has("Categories") && g_Commands["Categories"] is Array {
        for cat in g_Commands["Categories"] {
            if !(cat is Map) || !cat.Has("commands") || !(cat["commands"] is Array)
                continue
            catScenario := ChordPad_ClassifyScenarioForCategory(cat)
            if (catScenario != scenarioId)
                continue
            for c in cat["commands"] {
                x := Trim(String(c))
                if (x != "" && cmdList.Has(x))
                    out[x] := true
            }
        }
    }
    if (scenarioId = "search") {
        for cmdId, _ in cmdList {
            cid := Trim(String(cmdId))
            if (SubStr(cid, 1, 3) = "sc_")
                out[cid] := true
        }
    }
    return out
}

ChordPad_ClassifyScenarioForCategory(cat) {
    idRaw := StrLower(Trim(String(cat.Get("id", ""))))
    if (idRaw = "vk_direction")
        return "hotkeys"
    text := StrLower(Trim(String(cat.Get("id", ""))) . " " . Trim(String(cat.Get("name", ""))))
    if RegExMatch(text, "i)(cursor|vscode|code|ide|editor|命令面板|资源管理器|源代码管理|扩展|终端|语音输入)")
        return "cursor"
    if RegExMatch(text, "i)(cloudplayer|cloud|网盘|云盘|牛马云)")
        return "cloudplayer"
    if RegExMatch(text, "i)(clip|clipboard|copy|paste|剪贴|复制|粘贴)")
        return "clipboard"
    if RegExMatch(text, "i)(prompt|template|提示词|模板)")
        return "prompts"
    if RegExMatch(text, "i)(ai|gpt|llm|解释|改写|翻译)")
        return "ai"
    if RegExMatch(text, "i)(search|find|query|搜|查|检索)")
        return "search"
    if RegExMatch(text, "i)(scratchpad|draft|note|memo|草稿|笔记)")
        return "scratchpad"
    if RegExMatch(text, "i)(screen|shot|capture|image|截图|图像|ocr)")
        return "screenshot"
    if RegExMatch(text, "i)(hotkey|shortcut|快捷键)")
        return "hotkeys"
    if RegExMatch(text, "i)(setting|config|option|mode|system|window|admin|绑定|设置|配置|窗口|系统)")
        return "settings"
    return "settings"
}

ChordPad_AhkKeyToDomBase(ahkKey) {
    k := Trim(String(ahkKey))
    if (k = "" || k = "NONE")
        return ""
    while (StrLen(k) > 0) {
        p := SubStr(k, 1, 1)
        if (p = "$" || p = "*" || p = "~")
            k := SubStr(k, 2)
        else
            break
    }
    k := RegExReplace(k, "[\^!+#]+", "")
    if (k = "")
        return ""
    if (k = "``")
        return "``"
    if (StrLen(k) = 1)
        return StrLower(k)
    lk := StrLower(k)
    switch lk {
        case "esc", "escape":
            return "escape"
        case "lcontrol", "lctrl":
            return "LCtrl"
        case "rcontrol", "rctrl":
            return "RCtrl"
        case "lmenu", "lalt":
            return "LAlt"
        case "rmenu", "ralt":
            return "RAlt"
        case "lshift":
            return "LShift"
        case "rshift":
            return "RShift"
        case "lwin":
            return "LWin"
        case "rwin":
            return "RWin"
        case "appskey", "apps":
            return "AppsKey"
        case "capslock":
            return "CapsLock"
        case "backspace":
            return "Backspace"
        case "delete", "del":
            return "Delete"
        case "insert", "ins":
            return "Insert"
        case "enter", "return":
            return "Enter"
        case "space", "spacebar":
            return "Space"
        case "tab":
            return "Tab"
        case "printscreen", "prtsc":
            return "PrintScreen"
        case "scrolllock", "scrlk":
            return "ScrollLock"
        case "pause", "break":
            return "Pause"
        case "pgup", "pageup":
            return "PgUp"
        case "pgdn", "pagedown":
            return "PgDn"
        case "semicolon":
            return ";"
        case "slash":
            return "/"
        case "comma":
            return ","
        case "period", "dot":
            return "."
        case "equals", "equal":
            return "="
        case "minus", "dash":
            return "-"
        case "leftbracket", "lbracket":
            return "["
        case "rightbracket", "rbracket":
            return "]"
        case "backslash", "bslash":
            return Chr(92)
        case "quote", "apostrophe":
            return "'"
    }
    if RegExMatch(k, "i)^F([1-9]|1[0-2])$")
        return "F" . SubStr(k, 2)
    if RegExMatch(k, "i)^Numpad([0-9])$", &m)
        return m[1]
    return k
}

ChordPad_IsChordDisplayKey(domBase) {
    domBase := Trim(String(domBase))
    if (domBase = "")
        return false
    if (domBase = "CapsLock")
        return false
    return true
}

ChordPad_ResolveCmdForPhysKey(physKey, scenarioId := "") {
    k := StrLower(Trim(String(physKey)))
    if (k = "")
        return ""
    scenarioId := Trim(String(scenarioId))
    if (scenarioId = "" && FuncExists("ChordPad_ResolveActiveScenarioId"))
        scenarioId := ChordPad_ResolveActiveScenarioId()
    if (scenarioId = "search") && FuncExists("IsSearchCenterActive") {
        try {
            if IsSearchCenterActive() && FuncExists("VK_SearchCenterResolveCapsChordCmd") {
                scCmd := VK_SearchCenterResolveCapsChordCmd(k)
                if (scCmd != "")
                    return scCmd
            }
        } catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }
    if FuncExists("VK_LookupBindingCmdForPhys")
        return VK_LookupBindingCmdForPhys(k)
    return ""
}

ChordPad_CmdLabel(cmdId) {
    global g_Commands
    cmdId := Trim(String(cmdId))
    if (cmdId = "")
        return ""
    if (g_Commands is Map) && g_Commands.Has("CommandList") && g_Commands["CommandList"] is Map {
        cl := g_Commands["CommandList"]
        if cl.Has(cmdId) && cl[cmdId] is Map {
            nm := Trim(String(cl[cmdId].Get("name", "")))
            if (nm != "")
                return nm
        }
    }
    for item in ChordPad_DefaultCatalog() {
        if (item["cmdId"] = cmdId)
            return item["label"]
    }
    return cmdId
}

ChordPad_ActionForCmd(cmdId) {
    cmdId := Trim(String(cmdId))
    if RegExMatch(cmdId, "i)^ch_([a-z0-9])$", &m)
        return StrUpper(m[1])
    return ""
}

ChordPad_IsBareChordKey(ahkKey) {
    k := Trim(String(ahkKey))
    if (k = "" || k = "NONE")
        return false
    if (InStr(k, "^") || InStr(k, "!") || InStr(k, "+") || InStr(k, "#"))
        return false
    if FuncExists("_VK_IsBareSingleKey")
        return _VK_IsBareSingleKey(k)
    return (StrLen(k) = 1)
}

ChordPad_TryAddSlot(&slotsByKey, &slotsByCmd, scenarioCmds, cmdId, domKey, ahkKey := "") {
    cmdId := Trim(String(cmdId))
    domKey := Trim(String(domKey))
    if (cmdId = "" || domKey = "" || !ChordPad_IsChordDisplayKey(domKey))
        return
    if (ahkKey != "" && !ChordPad_IsBareChordKey(ahkKey))
        return
    if !(scenarioCmds is Map) || !scenarioCmds.Has(cmdId)
        return
    if slotsByCmd.Has(cmdId)
        return
    label := ChordPad_CmdLabel(cmdId)
    if (label = "")
        return
    action := ChordPad_ActionForCmd(cmdId)
    score := FuncExists("ChordUsage_GetScore") ? ChordUsage_GetScore(cmdId) : 0.0
    slot := Map(
        "key", domKey,
        "label", label,
        "cmdId", cmdId,
        "action", action,
        "iconLucide", ChordPad_IconLucideFor(action, cmdId),
        "score", score
    )
    slotsByCmd[cmdId] := true
    if !slotsByKey.Has(domKey)
        slotsByKey[domKey] := slot
    else {
        old := slotsByKey[domKey]
        if (Number(slot.Get("score", 0)) > Number(old.Get("score", 0)))
            slotsByKey[domKey] := slot
    }
}

ChordPad_BuildSlots() {
    ChordPad_EnsureVkData()
    global g_InverseBindings
    scenarioId := ChordPad_ResolveActiveScenarioId()
    scenarioCmds := ChordPad_CollectScenarioCmdIds(scenarioId)
    slotsByKey := Map()
    slotsByCmd := Map()

    if IsSet(g_InverseBindings) && g_InverseBindings is Map {
        for cmdId, ahkKey in g_InverseBindings
            ChordPad_TryAddSlot(&slotsByKey, &slotsByCmd, scenarioCmds, cmdId, ChordPad_AhkKeyToDomBase(ahkKey), ahkKey)
    }

    ChordPad_FillSlotsFromScenarioPresets(&slotsByKey, &slotsByCmd, scenarioCmds)

    if (scenarioId = "search") && FuncExists("IsSearchCenterActive") {
        try {
            if IsSearchCenterActive() {
                loop 26 {
                    k := Chr(96 + A_Index)
                    cmdId := ChordPad_ResolveCmdForPhysKey(k, scenarioId)
                    if (cmdId != "")
                        ChordPad_TryAddSlot(&slotsByKey, &slotsByCmd, scenarioCmds, cmdId, k)
                }
            }
        } catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }

    slots := []
    for domKey, slot in slotsByKey
        slots.Push(slot)

    if (slots.Length = 0) {
        for item in ChordPad_DefaultCatalog() {
            cmdId := item["cmdId"]
            key := ""
            if IsSet(g_InverseBindings) && g_InverseBindings is Map && g_InverseBindings.Has(cmdId)
                key := ChordPad_AhkKeyToDomBase(g_InverseBindings[cmdId])
            if (key = "")
                key := StrLower(item["defaultKey"])
            score := FuncExists("ChordUsage_GetScore") ? ChordUsage_GetScore(cmdId) : 0.0
            slots.Push(Map(
                "key", key,
                "label", item["label"],
                "cmdId", cmdId,
                "action", item["action"],
                "iconLucide", item.Get("iconLucide", ChordPad_IconLucideFor(item["action"], cmdId)),
                "score", score
            ))
        }
    }

    if FuncExists("ChordUsage_SortSlots")
        slots := ChordUsage_SortSlots(slots)
    return ChordPad_ApplyOnboardingToSlots(slots)
}

ChordPad_FillSlotsFromScenarioPresets(&slotsByKey, &slotsByCmd, scenarioCmds) {
    global g_Commands
    if !(scenarioCmds is Map)
        return
    bindings := Map()
    suggested := Map()
    if (g_Commands is Map) {
        if g_Commands.Has("Bindings") && g_Commands["Bindings"] is Map
            bindings := g_Commands["Bindings"]
        if g_Commands.Has("SuggestedBindings") && g_Commands["SuggestedBindings"] is Map
            suggested := g_Commands["SuggestedBindings"]
    }
    for cmdId, _ in scenarioCmds {
        cid := Trim(String(cmdId))
        if (cid = "" || slotsByCmd.Has(cid))
            continue
        ahkKey := ""
        if bindings.Has(cid) {
            v := bindings[cid]
            if (v != "" && StrUpper(String(v)) != "NONE")
                ahkKey := String(v)
        }
        if (ahkKey = "" && suggested.Has(cid))
            ahkKey := String(suggested[cid])
        domKey := ChordPad_AhkKeyToDomBase(ahkKey)
        if (domKey = "" && RegExMatch(cid, "i)^ch_([a-z0-9])$", &m))
            domKey := m[1]
        ChordPad_TryAddSlot(&slotsByKey, &slotsByCmd, scenarioCmds, cid, domKey, ahkKey)
    }
}

ChordPad_ApplyOnboardingToSlots(slots) {
    if !(slots is Array)
        return slots
    ; ChordPad 展示全部有效命令，不做渐进锁定（设置里「跳过引导」仍记入 onboarding 统计）
    for s in slots {
        s["revealed"] := true
        s["locked"] := false
    }
    return slots
}

ChordPad_SetPinned(pinned) {
    ChordPad_InitGlobals()
    global g_ChordPad_Pinned
    g_ChordPad_Pinned := !!pinned
    return g_ChordPad_Pinned
}

ChordPad_SetCompact(compact) {
    ChordPad_InitGlobals()
    global g_ChordPad_Compact
    g_ChordPad_Compact := !!compact
    ChordPad_SaveCompactPref()
    return g_ChordPad_Compact
}

ChordPad_SaveCompactPref() {
    ChordPad_InitGlobals()
    global g_ChordPad_Compact
    path := ChordPad_PosPath()
    doc := Map()
    if FileExist(path) {
        try {
            raw := FileRead(path, "UTF-8")
            if (raw != "") {
                loaded := Jxon_Load(raw)
                if loaded is Map
                    doc := loaded
            }
        } catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }
    doc["compact"] := !!g_ChordPad_Compact
    try {
        parent := ""
        SplitPath(path, , &parent)
        if (parent != "" && !DirExist(parent))
            DirCreate(parent)
        FileDelete(path)
        f := FileOpen(path, "w", "UTF-8")
        if !IsObject(f)
            return false
        f.Write(Jxon_Dump(doc))
        f.Close()
        return true
    } catch as e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, e)
        return false
    }
}

ChordPad_TogglePinned(*) {
    ChordPad_InitGlobals()
    global g_ChordPad_Pinned
    return ChordPad_SetPinned(!g_ChordPad_Pinned)
}

ChordPad_ToggleCompact(*) {
    ChordPad_InitGlobals()
    global g_ChordPad_Compact
    return ChordPad_SetCompact(!g_ChordPad_Compact)
}

ChordPad_IsVisible() {
    ChordPad_InitGlobals()
    global g_ChordPad_Visible
    return !!g_ChordPad_Visible
}

ChordPad_CapsWatchTick(*) {
    ChordPad_InitGlobals()
    global g_ChordPad_Visible, g_ChordPad_CapsWatchOn, g_ChordPad_Pinned
    if !g_ChordPad_Visible || !g_ChordPad_CapsWatchOn
        return
    if g_ChordPad_Pinned
        return
    physDown := false
    try physDown := GetKeyState("CapsLock", "P")
    catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
    }
    if physDown
        return
    ChordPad_Hide()
}

ChordPad_StartCapsWatch() {
    ChordPad_InitGlobals()
    global g_ChordPad_CapsWatchOn
    g_ChordPad_CapsWatchOn := true
    SetTimer(ChordPad_CapsWatchTick, 80)
}

ChordPad_StopCapsWatch() {
    ChordPad_InitGlobals()
    global g_ChordPad_CapsWatchOn
    g_ChordPad_CapsWatchOn := false
    SetTimer(ChordPad_CapsWatchTick, 0)
}

ChordPad_DismissIfVisible() {
    if !ChordPad_IsVisible()
        return false
    ChordPad_Hide()
    return true
}

ChordPad_PosPath(*) {
    if FuncExists("Nmer_DataStatePath")
        return Nmer_DataStatePath("chord_pad_pos.json")
    return A_ScriptDir . "\Data\state\chord_pad_pos.json"
}

ChordPad_LoadPosConfig() {
    ChordPad_InitGlobals()
    global g_ChordPad_X, g_ChordPad_Y, g_ChordPad_UseSavedPos, g_ChordPad_Scale, g_ChordPad_Compact
    g_ChordPad_UseSavedPos := false
    g_ChordPad_Scale := 1.0
    path := ChordPad_PosPath()
    if !FileExist(path)
        return
    try {
        raw := FileRead(path, "UTF-8")
        if (raw = "")
            return
        doc := Jxon_Load(raw)
        if !(doc is Map)
            return
        g_ChordPad_Compact := doc.Get("compact", false) ? true : false
        if !doc.Get("custom", false)
            return
        g_ChordPad_X := Integer(doc.Get("x", 0))
        g_ChordPad_Y := Integer(doc.Get("y", 0))
        scale := ChordPad_ClampScale(doc.Get("scale", 1.0))
        g_ChordPad_Scale := scale
        g_ChordPad_Compact := doc.Get("compact", false) ? true : false
        g_ChordPad_UseSavedPos := true
    } catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
    }
}

ChordPad_SavePosFromGui() {
    global g_ChordPad_Gui, g_ChordPad_W, g_ChordPad_H, g_ChordPad_Scale, g_ChordPad_Compact
    if !ChordPad_HasGui()
        return false
    try WinGetPos(&x, &y, &w, &h, g_ChordPad_Gui)
    catch {
        return false
    }
    path := ChordPad_PosPath()
    try {
        parent := ""
        SplitPath(path, , &parent)
        if (parent != "" && !DirExist(parent))
            DirCreate(parent)
        scale := ChordPad_ClampScale(g_ChordPad_Scale)
        g_ChordPad_Scale := scale
        payload := Map("custom", true, "x", x, "y", y, "w", w, "h", h, "scale", scale, "compact", !!g_ChordPad_Compact)
        FileDelete(path)
        f := FileOpen(path, "w", "UTF-8")
        if !IsObject(f)
            return false
        f.Write(Jxon_Dump(payload))
        f.Close()
        return true
    } catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
        return false
    }
}

ChordPad_ClampScale(scale) {
    ChordPad_InitGlobals()
    global g_ChordPad_ScaleMin, g_ChordPad_ScaleMax
    s := Round(Number(scale), 2)
    if (s < g_ChordPad_ScaleMin)
        s := g_ChordPad_ScaleMin
    else if (s > g_ChordPad_ScaleMax)
        s := g_ChordPad_ScaleMax
    return s
}

ChordPad_GetWorkArea(monitor := 0) {
    mon := monitor ? monitor : 1
    try {
        if !monitor
            mon := MonitorGetPrimary()
    } catch {
        mon := 1
    }
    MonitorGetWorkArea(mon, &l, &t, &r, &b)
    waW := Max(640, r - l)
    waH := Max(480, b - t)
    return Map("l", l, "t", t, "r", r, "b", b, "w", waW, "h", waH, "mon", mon)
}

ChordPad_ContentSizeForScale(scale := "", monitor := 0) {
    ChordPad_InitGlobals()
    global g_ChordPad_BaseH, g_ChordPad_Scale
    if (scale = "")
        scale := g_ChordPad_Scale
    s := ChordPad_ClampScale(scale)
    wa := ChordPad_GetWorkArea(monitor)
    return [wa["w"], Max(280, Round(g_ChordPad_BaseH * s))]
}

ChordPad_ResizeToContent(w, h, anchorBottom := true) {
    ChordPad_InitGlobals()
    global g_ChordPad_Gui, g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, g_ChordPad_UseSavedPos
    if !ChordPad_HasGui()
        return false
    nh := Integer(h)
    if (nh < 180)
        return false
    nh := Max(280, nh)
    if (g_ChordPad_H > 0 && Abs(nh - g_ChordPad_H) <= 2)
        return true
    wa := ChordPad_GetWorkArea()
    oldH := g_ChordPad_H
    g_ChordPad_W := wa["w"]
    g_ChordPad_H := nh
    g_ChordPad_X := wa["l"]
    if anchorBottom {
        if (oldH > 0)
            g_ChordPad_Y += oldH - nh
        else
            g_ChordPad_Y := wa["b"] - nh
    }
    clamped := ChordPad_ClampPos(g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, wa["mon"])
    g_ChordPad_X := clamped[1]
    g_ChordPad_Y := clamped[2]
    try WinMove(g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, g_ChordPad_Gui)
    catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
        return false
    }
    ChordPad_ApplyBounds()
    return true
}

ChordPad_ApplyScaleLayout(anchorBottom := true) {
    ChordPad_InitGlobals()
    global g_ChordPad_Gui, g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, g_ChordPad_Scale, g_ChordPad_UseSavedPos
    if !ChordPad_HasGui()
        return false
    oldH := g_ChordPad_H
    g_ChordPad_Scale := ChordPad_ClampScale(g_ChordPad_Scale)
    size := ChordPad_ContentSizeForScale(g_ChordPad_Scale)
    wa := ChordPad_GetWorkArea()
    g_ChordPad_W := size[1]
    g_ChordPad_H := size[2]
    if !g_ChordPad_UseSavedPos
        g_ChordPad_X := wa["l"]
    if (anchorBottom && oldH > 0)
        g_ChordPad_Y += oldH - g_ChordPad_H
    clamped := ChordPad_ClampPos(g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, wa["mon"])
    g_ChordPad_X := clamped[1]
    g_ChordPad_Y := clamped[2]
    try WinMove(g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, g_ChordPad_Gui)
    catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
        return false
    }
    ChordPad_ApplyBounds()
    return true
}

ChordPad_ClampPos(x, y, w, h, monitor := 0) {
    mon := monitor ? monitor : 1
    try {
        if !monitor
            mon := MonitorGetPrimary()
    } catch {
        mon := 1
    }
    MonitorGetWorkArea(mon, &l, &t, &r, &b)
    maxX := Max(l, r - w)
    maxY := Max(t, b - h)
    return [Max(l, Min(x, maxX)), Max(t, Min(y, maxY))]
}

ChordPad_ComputeBounds(monitor := 0) {
    ChordPad_InitGlobals()
    global g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, g_ChordPad_UseSavedPos, g_ChordPad_Scale
    wa := ChordPad_GetWorkArea(monitor)
    ChordPad_LoadPosConfig()
    g_ChordPad_Scale := ChordPad_ClampScale(g_ChordPad_Scale)
    size := ChordPad_ContentSizeForScale(g_ChordPad_Scale, wa["mon"])
    g_ChordPad_W := size[1]
    g_ChordPad_H := size[2]
    if !g_ChordPad_UseSavedPos {
        g_ChordPad_X := wa["l"]
        g_ChordPad_Y := wa["b"] - g_ChordPad_H
    } else {
        g_ChordPad_X := wa["l"]
    }
    clamped := ChordPad_ClampPos(g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, wa["mon"])
    g_ChordPad_X := clamped[1]
    g_ChordPad_Y := clamped[2]
}

ChordPad_BeginHostDrag(*) {
    ChordPad_InitGlobals()
    global g_ChordPad_Gui, g_ChordPad_DragActive, g_ChordPad_DragAnchorX, g_ChordPad_DragAnchorY
    if !ChordPad_HasGui() || g_ChordPad_DragActive
        return false
    if !GetKeyState("LButton", "P")
        return false
    CoordMode("Mouse", "Screen")
    MouseGetPos(&g_ChordPad_DragAnchorX, &g_ChordPad_DragAnchorY)
    g_ChordPad_DragActive := true
    SetTimer(ChordPad_DragTick, 16)
    return true
}

ChordPad_DragTick(*) {
    ChordPad_InitGlobals()
    global g_ChordPad_Gui, g_ChordPad_DragActive, g_ChordPad_DragAnchorX, g_ChordPad_DragAnchorY
    global g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, g_ChordPad_UseSavedPos
    if !g_ChordPad_DragActive || !ChordPad_HasGui() {
        ChordPad_EndDrag()
        return
    }
    if !GetKeyState("LButton", "P") {
        ChordPad_EndDrag()
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    dx := mx - g_ChordPad_DragAnchorX
    dy := my - g_ChordPad_DragAnchorY
    if (dx = 0 && dy = 0)
        return
    g_ChordPad_DragAnchorX := mx
    g_ChordPad_DragAnchorY := my
    try WinGetPos(&x, &y, &w, &h, g_ChordPad_Gui)
    catch {
        ChordPad_EndDrag()
        return
    }
    clamped := ChordPad_ClampPos(x + dx, y + dy, w, h)
    nx := clamped[1]
    ny := clamped[2]
    g_ChordPad_X := nx
    g_ChordPad_Y := ny
    g_ChordPad_W := w
    g_ChordPad_H := h
    g_ChordPad_UseSavedPos := true
    try WinMove(nx, ny, w, h, g_ChordPad_Gui)
    catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
    }
}

ChordPad_EndDrag(*) {
    ChordPad_InitGlobals()
    global g_ChordPad_DragActive
    if !g_ChordPad_DragActive
        return
    g_ChordPad_DragActive := false
    SetTimer(ChordPad_DragTick, 0)
    ChordPad_SyncPosAfterMove()
}

ChordPad_SyncPosAfterMove() {
    global g_ChordPad_Gui, g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, g_ChordPad_UseSavedPos
    if !ChordPad_HasGui()
        return
    try WinGetPos(&x, &y, &w, &h, g_ChordPad_Gui)
    catch {
        return
    }
    clamped := ChordPad_ClampPos(x, y, w, h)
    nx := clamped[1]
    ny := clamped[2]
    if (nx != x || ny != y) {
        try WinMove(nx, ny, w, h, g_ChordPad_Gui)
        catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }
    g_ChordPad_X := nx
    g_ChordPad_Y := ny
    g_ChordPad_W := w
    g_ChordPad_H := h
    g_ChordPad_UseSavedPos := true
    ChordPad_SavePosFromGui()
}

ChordPad_OnExitSizeMove(wParam, lParam, msg, hwnd) {
    if !ChordPad_HasGui()
        return
    global g_ChordPad_Gui
    if (hwnd != g_ChordPad_Gui.Hwnd)
        return
    ChordPad_SyncPosAfterMove()
}

ChordPad_RunSlot(action, cmdId := "", key := "") {
    action := StrUpper(Trim(String(action)))
    cmdId := Trim(String(cmdId))
    key := StrLower(Trim(String(key)))

    try SetTimer(ShowPanelTimer, 0)
    catch as _e {
    }
    global CapsLock2
    CapsLock2 := false
    if FuncExists("RestoreCapsLockAfterChord")
        RestoreCapsLockAfterChord()
    if (key != "") && FuncExists("ChordPad_FlashKey")
        ChordPad_FlashKey(key)

    if (cmdId != "") && FuncExists("VK_Execute") {
        try {
            if VK_Execute(cmdId) {
                if FuncExists("VK_NoteLastExecutedId")
                    VK_NoteLastExecutedId(cmdId)
                if FuncExists("ChordUsage_Record")
                    ChordUsage_Record(cmdId)
                return true
            }
        } catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }

    if FuncExists("CursorPanel_RunQuickAction") {
        switch action {
            case "E":
                CursorPanel_RunQuickAction("Explain")
                if FuncExists("ChordUsage_Record")
                    ChordUsage_Record(cmdId != "" ? cmdId : "ch_e")
                return true
            case "R":
                CursorPanel_RunQuickAction("Refactor")
                if FuncExists("ChordUsage_Record")
                    ChordUsage_Record(cmdId != "" ? cmdId : "ch_r")
                return true
            case "O":
                CursorPanel_RunQuickAction("Optimize")
                if FuncExists("ChordUsage_Record")
                    ChordUsage_Record(cmdId != "" ? cmdId : "ch_o")
                return true
        }
    }

    if (action != "") && FuncExists("HandleDynamicHotkey") {
        pressKey := key != "" ? key : StrLower(action)
        try {
            if HandleDynamicHotkey(pressKey, action) {
                if FuncExists("VK_NoteLastChFromCapsLockKey")
                    VK_NoteLastChFromCapsLockKey(pressKey)
                return true
            }
        } catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }
    return false
}

ChordPad_ApplyTransparency() {
    ChordPad_InitGlobals()
    global g_ChordPad_Gui, g_ChordPad_Ctrl
    if ChordPad_HasGui() {
        try g_ChordPad_Gui.BackColor := "010101"
        try WinSetTransColor("010101", g_ChordPad_Gui)
        try WinSetTransparent(255, g_ChordPad_Gui)
    }
    if g_ChordPad_Ctrl {
        try g_ChordPad_Ctrl.DefaultBackgroundColor := 0x00000000
        try g_ChordPad_Ctrl.IsVisible := true
    }
}

ChordPad_EnsureInit() {
    ChordPad_InitGlobals()
    global g_ChordPad_Gui, g_ChordPad_W, g_ChordPad_H
    if ChordPad_HasGui()
        return true
    ChordPad_ComputeBounds()
    g_ChordPad_Gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80000 -DPIScale", "ChordPad")
    g_ChordPad_Gui.BackColor := "010101"
    g_ChordPad_Gui.MarginX := 0
    g_ChordPad_Gui.MarginY := 0
    g_ChordPad_Gui.OnEvent("Close", (*) => ChordPad_Hide())
    try g_ChordPad_Gui.OnMessage(0x0232, ChordPad_OnExitSizeMove)  ; WM_EXITSIZEMOVE
    g_ChordPad_Gui.Show("w" . g_ChordPad_W . " h" . g_ChordPad_H . " Hide")
    try WinSetExStyle("+0x08000000", g_ChordPad_Gui)  ; WS_EX_NOACTIVATE
    if !FuncExists("WebView2_CreateWithSharedEnvAsync")
        return false
    WebView2_CreateWithSharedEnvAsync(g_ChordPad_Gui.Hwnd, ChordPad_OnWV2Created, "chord_pad")
    return true
}

ChordPad_OnWV2Created(ctrl) {
    ChordPad_InitGlobals()
    global g_ChordPad_WV2, g_ChordPad_Ctrl, g_ChordPad_Gui
    g_ChordPad_Ctrl := ctrl
    g_ChordPad_WV2 := ctrl.CoreWebView2
    try g_ChordPad_Ctrl.DefaultBackgroundColor := 0x00000000
    ChordPad_ApplyTransparency()
    ChordPad_ApplyBounds()
    s := g_ChordPad_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.AreDevToolsEnabled := false
    if FuncExists("ApplyWebView2PerformanceSettings")
        ApplyWebView2PerformanceSettings(g_ChordPad_WV2)
    try Func("WebView2_RegisterHostBridge").Call(g_ChordPad_WV2)
    g_ChordPad_WV2.add_WebMessageReceived(ChordPad_OnWebMessage)
    try g_ChordPad_WV2.add_NavigationCompleted(ChordPad_OnNavigationCompleted)
    if FuncExists("ApplyUnifiedWebViewAssets")
        try ApplyUnifiedWebViewAssets(g_ChordPad_WV2)
    if FuncExists("BuildAppLocalUrl")
        g_ChordPad_WV2.Navigate(BuildAppLocalUrl("ChordPad.html"))
}

ChordPad_ApplyBounds() {
    ChordPad_InitGlobals()
    global g_ChordPad_Gui, g_ChordPad_Ctrl, g_ChordPad_W, g_ChordPad_H
    if !g_ChordPad_Ctrl || !ChordPad_HasGui()
        return
    try {
        rc := WebView2.RECT()
        rc.left := 0
        rc.top := 0
        rc.right := g_ChordPad_W
        rc.bottom := g_ChordPad_H
        g_ChordPad_Ctrl.Bounds := rc
    } catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
    }
}

ChordPad_OnNavigationCompleted(sender, args) {
    ChordPad_InitGlobals()
    global g_ChordPad_Ready
    g_ChordPad_Ready := true
    ChordPad_PushInit()
}

ChordPad_OnWebMessage(sender, args) {
    try {
        raw := args.WebMessageAsJson
        msg := Jxon_Load(raw)
        if !(msg is Map)
            return
        t := msg.Get("type", "")
        switch t {
            case "chordPadReady":
                ChordPad_PushInit()
            case "chordPadBeginDrag":
                ChordPad_BeginHostDrag()
            case "chordPadRun":
                ChordPad_RunSlot(msg.Get("action", ""), msg.Get("cmdId", ""), msg.Get("key", ""))
            case "chordPadClose", "chordPadCancel", "chordPadDismiss":
                ChordPad_Hide()
            case "chordPadSetPin":
                ChordPad_SetPinned(msg.Get("pinned", false))
            case "chordPadTogglePin":
                ChordPad_TogglePinned()
            case "chordPadSetCompact":
                ChordPad_SetCompact(msg.Get("compact", false))
            case "chordPadToggleCompact":
                ChordPad_ToggleCompact()
            case "chordPadSetScale":
                ChordPad_SetScale(msg.Get("scale", 1.0), msg.Get("height", 0))
            case "chordPadResize":
                ChordPad_ResizeFromMeasure(msg.Get("height", 0))
        }
    } catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
    }
}

ChordPad_ResizeFromMeasure(h) {
    ChordPad_InitGlobals()
    global g_ChordPad_BaseH, g_ChordPad_Scale
    nh := Integer(h)
    if (nh < 180)
        return false
    s := ChordPad_ClampScale(g_ChordPad_Scale)
    if (s > 0)
        g_ChordPad_BaseH := Max(280, Round(nh / s))
    return ChordPad_ResizeToContent(0, nh, true)
}

ChordPad_SetScale(scale, height := 0) {
    ChordPad_InitGlobals()
    global g_ChordPad_Scale, g_ChordPad_BaseH
    g_ChordPad_Scale := ChordPad_ClampScale(scale)
    h := Integer(height)
    if (h < 180)
        h := Max(280, Round(g_ChordPad_BaseH * g_ChordPad_Scale))
    ChordPad_ResizeToContent(0, h, true)
    ChordPad_SavePosFromGui()
}

ChordPad_PushInit() {
    ChordPad_InitGlobals()
    global g_ChordPad_WV2, g_ChordPad_Ready, g_ChordPad_Scale, g_ChordPad_ScaleMin, g_ChordPad_ScaleMax, g_ChordPad_W
    if !g_ChordPad_Ready || !g_ChordPad_WV2
        return
    scenarioId := ChordPad_ResolveActiveScenarioId()
    slots := ChordPad_BuildSlots()
    arr := "["
    sep := ""
    for s in slots {
        arr .= sep . '{"key":' . ChordPad_JsonStr(s["key"])
            . ',"label":' . ChordPad_JsonStr(s["label"])
            . ',"cmdId":' . ChordPad_JsonStr(s["cmdId"])
            . ',"action":' . ChordPad_JsonStr(s["action"])
            . ',"iconLucide":' . ChordPad_JsonStr(s.Get("iconLucide", ChordPad_IconLucideFor(s["action"], s["cmdId"])))
            . ',"tier":' . ChordPad_JsonStr(s.Get("tier", "normal"))
            . ',"rank":' . Round(Number(s.Get("rank", 99)))
            . ',"score":' . Round(Number(s.Get("score", 0)), 2)
            . ',"revealed":' . (s.Get("revealed", true) ? "true" : "false")
            . ',"locked":' . (s.Get("locked", false) ? "true" : "false") . '}'
        sep := ","
    }
    arr .= "]"
    scenarioLabel := ChordPad_ScenarioLabel(scenarioId)
    hint := "CapsLock+键执行 · 置顶后松手不关闭 · 缩小为宫格"
    scale := ChordPad_ClampScale(g_ChordPad_Scale)
    g_ChordPad_Scale := scale
    global g_ChordPad_Pinned, g_ChordPad_Compact
    obTier := 3
    obLaunch := 0
    obRevealed := "[]"
    obHint := ""
    obForceAll := true
    if FuncExists("OnboardingHotkeys_PayloadForWeb") {
        ob := OnboardingHotkeys_PayloadForWeb()
        if ob is Map {
            obTier := Integer(ob.Get("onboardingTier", 1))
            obLaunch := Integer(ob.Get("launchCount", 0))
            obHint := String(ob.Get("unlockHint", ""))
            obForceAll := ob.Get("forceRevealAll", false) ? true : false
            revArr := ob.Has("revealedSlots") && ob["revealedSlots"] is Array ? ob["revealedSlots"] : []
            obRevealed := "["
            sepR := ""
            for a in revArr {
                obRevealed .= sepR . ChordPad_JsonStr(String(a))
                sepR := ","
            }
            obRevealed .= "]"
        }
    }
    payload := '{"type":"chordPadInit","hint":' . ChordPad_JsonStr(hint)
        . ',"scenarioId":' . ChordPad_JsonStr(scenarioId)
        . ',"scenarioLabel":' . ChordPad_JsonStr(scenarioLabel)
        . ',"scale":' . scale
        . ',"scaleMin":' . g_ChordPad_ScaleMin
        . ',"scaleMax":' . g_ChordPad_ScaleMax
        . ',"viewportWidth":' . (IsSet(g_ChordPad_W) && g_ChordPad_W > 0 ? g_ChordPad_W : ChordPad_GetWorkArea()["w"])
        . ',"fullWidth":true'
        . ',"onboardingTier":' . obTier
        . ',"launchCount":' . obLaunch
        . ',"revealedSlots":' . obRevealed
        . ',"unlockHint":' . ChordPad_JsonStr(obHint)
        . ',"forceRevealAll":' . (obForceAll ? "true" : "false")
        . ',"pinned":' . (g_ChordPad_Pinned ? "true" : "false")
        . ',"compact":' . (g_ChordPad_Compact ? "true" : "false")
        . ',"slots":' . arr . '}'
    try g_ChordPad_WV2.PostWebMessageAsJson(payload)
    catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
    }
}

ChordPad_JsonStr(s) {
    s := String(s)
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    return '"' . s . '"'
}

ChordPad_PositionAndShow() {
    ChordPad_InitGlobals()
    global g_ChordPad_Gui, g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, g_ChordPad_Visible, g_ChordPad_Pinned
    if !ChordPad_HasGui()
        return false
    g_ChordPad_Pinned := false
    ChordPad_ComputeBounds()
    ChordPad_ApplyBounds()
    ChordPad_ApplyTransparency()
    try g_ChordPad_Gui.Show("x" . g_ChordPad_X . " y" . g_ChordPad_Y . " w" . g_ChordPad_W . " h" . g_ChordPad_H . " NoActivate")
    catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
        return false
    }
    try WinSetExStyle("+0x08000000", g_ChordPad_Gui)
    g_ChordPad_Visible := true
    ChordPad_StartCapsWatch()
    if FuncExists("OnboardingHotkeys_RecordSummon") {
        obResult := OnboardingHotkeys_RecordSummon()
        if obResult is Map && obResult.Get("upgraded", false) {
            newTier := Integer(obResult.Get("newTier", 1))
            if (newTier = 2) && FuncExists("Nmer_ShowAppToast") {
                try Nmer_ShowAppToast("快捷键解锁", "已解锁 X 历史、E 解释", "ok")
                catch as _e {
                    if FuncExists("NmerCatch")
                        NmerCatch(A_ThisFunc, _e)
                }
            }
        }
    }
    ChordPad_PushInit()
    return true
}

ChordPad_Show(*) {
    ChordPad_EnsureInit()
    if !ChordPad_HasGui()
        return false
    return ChordPad_PositionAndShow()
}

ChordPad_Hide(*) {
    ChordPad_InitGlobals()
    global g_ChordPad_Gui, g_ChordPad_Visible, g_ChordPad_WV2, VKHoldVisible, g_ChordPad_Pinned
    ChordPad_EndDrag()
    ChordPad_StopCapsWatch()
    g_ChordPad_Visible := false
    g_ChordPad_Pinned := false
    try VKHoldVisible := false
    catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
    }
    if g_ChordPad_WV2 {
        try g_ChordPad_WV2.PostWebMessageAsJson('{"type":"chordPadHide"}')
        catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }
    if ChordPad_HasGui() {
        try g_ChordPad_Gui.Hide()
        catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }
}

ChordPad_FlashKey(key) {
    ChordPad_InitGlobals()
    global g_ChordPad_WV2, g_ChordPad_Visible
    if !g_ChordPad_Visible || !g_ChordPad_WV2
        return
    k := StrLower(Trim(String(key)))
    if (k = "")
        return
    if (k = "escape" || k = "esc")
        k := "esc"
    try g_ChordPad_WV2.PostWebMessageAsJson('{"type":"keyPreview","key":' . ChordPad_JsonStr(k) . '}')
    catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
    }
}
