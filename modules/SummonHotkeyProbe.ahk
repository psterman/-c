; SummonHotkeyProbe.ahk — 主唤起键冲突探针

global g_SummonProbe_Hk := ""
global g_SummonProbe_Responded := false
global g_SummonProbe_TimerArmed := false

Nmer_NormalizeSummonPreset(preset) {
    return "capslock"
}

Nmer_ResolveActiveSummonPreset(*) {
    global SummonHotkeyPreset
    ; Phase 1：非 capslock 预设仅存储，运行时回退 CapsLock
    preset := Nmer_NormalizeSummonPreset(IsSet(SummonHotkeyPreset) ? SummonHotkeyPreset : "capslock")
    if (preset != "capslock")
        return "capslock"
    return preset
}

Nmer_PresetToAhkKey(preset, customKey := "") {
    preset := Nmer_NormalizeSummonPreset(preset)
    switch preset {
        case "alt_space": return "!Space"
        case "ctrl_space": return "^Space"
        case "win_space": return "#Space"
        case "ctrl_shift": return "^+"
        case "alt_shift": return "!+"
        case "capslock": return "CapsLock"
        case "custom":
            hk := Trim(String(customKey))
            return hk != "" ? hk : "!Space"
    }
    return "CapsLock"
}

Nmer_PresetDisplayLabel(preset, customKey := "") {
    preset := Nmer_NormalizeSummonPreset(preset)
    switch preset {
        case "alt_space": return "Alt+Space"
        case "ctrl_space": return "Ctrl+Space"
        case "win_space": return "Win+Space"
        case "ctrl_shift": return "Ctrl+Shift"
        case "alt_shift": return "Alt+Shift"
        case "capslock": return "CapsLock"
        case "custom":
            hk := Trim(String(customKey))
            if (hk = "")
                return "自定义"
            if FuncExists("_ToDisplayKey")
                try return _ToDisplayKey(hk)
            return hk
    }
    return "CapsLock"
}

Nmer_SummonKnownConflictProcesses() {
    return [
        Map("name", "搜狗输入法", "processes", ["SogouCloud.exe", "SogouIme.exe", "SGTool.exe"], "doc", "https://pinyin.sogou.com/"),
        Map("name", "百度输入法", "processes", ["BaiduPinyin.exe", "BaiduPinyinService.exe"], "doc", "https://shurufa.baidu.com/"),
        Map("name", "卡巴斯基", "processes", ["avp.exe", "avpui.exe"], "doc", "https://www.kaspersky.com/")
    ]
}

Nmer_ProbeTryRegisterHotkey(ahkKey) {
    hk := Trim(String(ahkKey))
    if (hk = "" || StrLower(hk) = "capslock")
        return Map("ok", true, "message", "CapsLock 由专用热键处理")
    try {
        Hotkey(hk, Nmer_SummonProbe_DummyCb, "On")
        Hotkey(hk, "Off")
        return Map("ok", true, "message", "试注册成功")
    } catch as e {
        return Map("ok", false, "message", e.Message)
    }
}

Nmer_SummonProbe_DummyCb(*) {
    global g_SummonProbe_Responded := true
    Nmer_SummonProbe_StopInteractive()
    try {
        if FuncExists("ConfigWebView_Send")
            ConfigWebView_Send(Map("type", "summonProbeResult", "responded", true))
    } catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
    }
}

Nmer_SummonProbe_StopInteractive() {
    global g_SummonProbe_Hk, g_SummonProbe_TimerArmed
    hk := g_SummonProbe_Hk
    g_SummonProbe_Hk := ""
    if (hk != "") {
        try Hotkey(hk, "Off")
        catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }
    if g_SummonProbe_TimerArmed {
        g_SummonProbe_TimerArmed := false
        SetTimer(Nmer_SummonProbe_InteractiveTimeout, 0)
    }
}

Nmer_SummonProbe_InteractiveTimeout(*) {
    global g_SummonProbe_Responded, g_SummonProbe_TimerArmed
    g_SummonProbe_TimerArmed := false
    if g_SummonProbe_Responded {
        g_SummonProbe_Responded := false
        return
    }
    Nmer_SummonProbe_StopInteractive()
    try {
        if FuncExists("ConfigWebView_Send")
            ConfigWebView_Send(Map("type", "summonProbeResult", "responded", false, "timeout", true))
    } catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
    }
}

Nmer_ProbeSummonHotkey_Interactive(preset := "", customKey := "") {
    global SummonHotkeyPreset, SummonHotkeyCustom, g_SummonProbe_Hk, g_SummonProbe_Responded
    if (preset = "")
        preset := IsSet(SummonHotkeyPreset) ? SummonHotkeyPreset : "capslock"
    if (customKey = "" && IsSet(SummonHotkeyCustom))
        customKey := SummonHotkeyCustom
    active := Nmer_ResolveActiveSummonPreset()
    hk := Nmer_PresetToAhkKey(active, customKey)
    Nmer_SummonProbe_StopInteractive()
    g_SummonProbe_Responded := false
    if (StrLower(hk) = "capslock") {
        try {
            if FuncExists("ConfigWebView_Send")
                ConfigWebView_Send(Map("type", "summonProbeWait", "message", "请长按 CapsLock 达到设定时长，看和弦面板是否弹出。"))
        } catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
        return Map("interactive", true, "mode", "capslock_hold")
    }
    reg := Nmer_ProbeTryRegisterHotkey(hk)
    if !reg.Get("ok", false) {
        return Map("interactive", false, "responded", false, "error", reg.Get("message", "无法注册试按热键"))
    }
    try {
        g_SummonProbe_Hk := hk
        Hotkey(hk, Nmer_SummonProbe_DummyCb, "On")
        global g_SummonProbe_TimerArmed := true
        SetTimer(Nmer_SummonProbe_InteractiveTimeout, -5000)
        if FuncExists("ConfigWebView_Send")
            ConfigWebView_Send(Map(
                "type", "summonProbeWait",
                "message", "请在 5 秒内按一次 " . Nmer_PresetDisplayLabel(active, customKey) . "，检测是否响应。"
            ))
        return Map("interactive", true, "mode", "hotkey", "ahkKey", hk)
    } catch as e {
        Nmer_SummonProbe_StopInteractive()
        return Map("interactive", false, "responded", false, "error", e.Message)
    }
}

Nmer_ProbeSummonHotkey(preset := "", customKey := "", interactive := false) {
    global SummonHotkeyPreset, SummonHotkeyCustom, CapsLockMode
    if interactive
        return Nmer_ProbeSummonHotkey_Interactive(preset, customKey)
    if (preset = "")
        preset := IsSet(SummonHotkeyPreset) ? SummonHotkeyPreset : "capslock"
    if (customKey = "" && IsSet(SummonHotkeyCustom))
        customKey := SummonHotkeyCustom
    preset := Nmer_NormalizeSummonPreset(preset)
    ahkKey := Nmer_PresetToAhkKey(preset, customKey)
    activePreset := Nmer_ResolveActiveSummonPreset()
    items := []
    blocking := false
    recommendedPreset := "capslock"

    ; 1) 系统占键
    sysStatus := "ok"
    sysMsg := "主键可注册"
    sysBlocking := false
    if (preset = "alt_space") {
        sysMsg := "Alt+Space 常被系统/输入法占用，且为一键触发，不适合当按住层键"
        sysStatus := "error"
        sysBlocking := false
    } else if (preset = "win_space") {
        sysMsg := "Win+Space 通常被系统输入法切换占用"
        sysStatus := "warn"
    } else if (preset = "ctrl_space") {
        sysMsg := "Ctrl+Space 多被输入法占用，且含 Space 无法「按住当层」"
        sysStatus := "error"
    } else if (preset = "ctrl_shift") {
        sysMsg := "双修饰层：按住 Ctrl+Shift 再按字母（下一版本启用）"
        sysStatus := "ok"
    } else if (preset = "alt_shift") {
        sysMsg := "双修饰层：按住 Alt+Shift 再按字母（下一版本启用）"
        sysStatus := "ok"
    }
    if (preset != "capslock" && preset != "ctrl_shift" && preset != "alt_shift") {
        reg := Nmer_ProbeTryRegisterHotkey(ahkKey)
        if !reg.Get("ok", false) {
            sysStatus := "error"
            sysMsg := "主键已被占用：" . reg.Get("message", "")
            sysBlocking := true
            blocking := true
        }
    }
    items.Push(Map(
        "id", "systemOccupied",
        "status", sysStatus,
        "message", sysMsg,
        "blocking", sysBlocking
    ))

    ; 2) CapsLock 短按
    capsStatus := "ok"
    capsMsg := "非 CapsLock 预设，跳过"
    capsSuggest := ""
    if (preset = "capslock") {
        mode := IsSet(CapsLockMode) ? StrLower(Trim(String(CapsLockMode))) : "chord"
        capsMsg := "长按唤起 + CapsLock+字母和弦"
        if (mode = "chord")
            capsMsg .= "；若短按大写异常，建议 CapsLockMode=off"
        else
            capsMsg := "仅长按唤起，字母和弦已关闭"
        capsStatus := (mode = "chord") ? "warn" : "ok"
        capsSuggest := (mode = "chord") ? "off" : ""
    }
    items.Push(Map(
        "id", "capsLockShortPress",
        "status", capsStatus,
        "message", capsMsg,
        "suggestCapsLockMode", capsSuggest,
        "blocking", false
    ))

    ; 3) 已知占键进程
    foundProcs := []
    for entry in Nmer_SummonKnownConflictProcesses() {
        procs := entry.Has("processes") && entry["processes"] is Array ? entry["processes"] : []
        for pn in procs {
            if ProcessExist(pn) {
                foundProcs.Push(Map("name", entry["name"], "process", pn, "doc", entry.Get("doc", "")))
                break
            }
        }
    }
    procStatus := foundProcs.Length ? "warn" : "ok"
    procMsg := foundProcs.Length
        ? "检测到可能抢占热键的进程，可一键改用 CapsLock 或 Ctrl+Space"
        : "未检测到常见占键进程"
    items.Push(Map(
        "id", "knownProcesses",
        "status", procStatus,
        "message", procMsg,
        "blocking", false,
        "safeModePreset", "capslock"
    ))

    ; 4) VK 冲突（自定义键与全局绑定）
    vkStatus := "ok"
    vkMsg := "无 VK 绑定冲突"
    if (preset = "custom" && ahkKey != "" && FuncExists("GetHotkeyConflict")) {
        try {
            cf := GetHotkeyConflict(ahkKey, 3, "global")
            if cf.Get("conflict", false) {
                vkStatus := "warn"
                vkMsg := "「" . ahkKey . "」已被命令 " . cf.Get("cmdId", "") . " 占用"
            }
        } catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }
    items.Push(Map(
        "id", "vkConflict",
        "status", vkStatus,
        "message", vkMsg,
        "blocking", false
    ))

    phase1Note := (preset != "capslock")
        ? "此唤起方式将在下一版本启用，当前仍使用 CapsLock 长按"
        : ""

    return Map(
        "items", items,
        "blocking", blocking,
        "recommendedPreset", recommendedPreset,
        "activePreset", activePreset,
        "requestedPreset", preset,
        "ahkKey", ahkKey,
        "displayKey", Nmer_PresetDisplayLabel(preset, customKey),
        "phase1Note", phase1Note
    )
}

Nmer_ProbeSummonHotkeyReportForWeb(report) {
    if !(report is Map)
        return Map("blocking", false, "items", [])
    items := []
    if report.Has("items") && report["items"] is Array {
        for it in report["items"] {
            if !(it is Map)
                continue
            items.Push(Map(
                "id", it.Has("id") ? String(it["id"]) : "",
                "status", it.Has("status") ? String(it["status"]) : "ok",
                "message", it.Has("message") ? String(it["message"]) : "",
                "blocking", it.Has("blocking") ? !!it["blocking"] : false
            ))
        }
    }
    return Map(
        "blocking", report.Get("blocking", false) ? true : false,
        "recommendedPreset", String(report.Get("recommendedPreset", "capslock")),
        "activePreset", String(report.Get("activePreset", "capslock")),
        "requestedPreset", String(report.Get("requestedPreset", "")),
        "displayKey", String(report.Get("displayKey", "")),
        "phase1Note", String(report.Get("phase1Note", "")),
        "items", items
    )
}

Nmer_ApplySummonSafeMode() {
    global SummonHotkeyPreset, SummonHotkeyCustom, ConfigFile
    SummonHotkeyPreset := "capslock"
    SummonHotkeyCustom := ""
    if IsSet(ConfigFile) && ConfigFile != "" {
        IniWrite("capslock", ConfigFile, "Settings", "SummonHotkeyPreset")
        IniWrite("", ConfigFile, "Settings", "SummonHotkeyCustom")
    }
    return true
}
