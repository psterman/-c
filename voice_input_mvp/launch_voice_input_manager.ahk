#Requires AutoHotkey v2.0
#SingleInstance Force

#Include c:\Users\Administrator\Desktop\牛马nmer\lib\ahk\WebView2.ahk
#Include c:\Users\Administrator\Desktop\牛马nmer\lib\ahk\Jxon.ahk

global MVP_Root := A_ScriptDir
global MVP_ConfigFile := MVP_Root "\voice_input_settings.json"
global MVP_HtmlFile := MVP_Root "\html\VoiceInputSettings.html"
global MVP_LogFile := MVP_Root "\voice_input_manager.log"

global MVP_Gui := 0
global MVP_Ctrl := 0
global MVP_Wv := 0
global MVP_Config := 0
global MVP_ConfigStamp := ""
global MVP_BoundHotkeys := []
global MVP_BoundSignature := ""
global MVP_ActiveSceneId := ""
global MVP_LastSceneId := ""
global MVP_Count := 0
global MVP_LastTick := 0
global MVP_EnterTimer := 0
global MVP_LastPhysicalHotkey := ""
global MVP_LastPhysicalTick := 0
global MVP_GroupDedupMs := 120
global MVP_LastRuntimeSignature := ""
global MVP_ConflictWarnings := []
global MVP_LastConflictCheckTick := 0
global MVP_SelfPid := DllCall('GetCurrentProcessId')

if !FileExist(MVP_ConfigFile) {
    MVP_EnsureConfigDir()
    MVP_WriteConfig(MVP_DefaultConfig())
}

OpenManager()
return

OpenManager() {
    global MVP_Gui
    MVP_Gui := Gui("+Resize +MinSize1080x820", "通用单键语音触发器")
    MVP_Gui.OnEvent("Close", (*) => ExitApp())
    MVP_Gui.OnEvent("Escape", (*) => ExitApp())
    MVP_Gui.Show("w1240 h860")
    try {
        WebView2.create(MVP_Gui.Hwnd, MVP_OnCreated)
    } catch as e {
        MsgBox("WebView 创建失败:`n" e.Message, "Voice Input MVP", "Iconx")
        ExitApp()
    }
}

MVP_OnCreated(ctrl) {
    global MVP_Ctrl, MVP_Wv, MVP_HtmlFile, MVP_Config
    try {
        MVP_Ctrl := ctrl
        MVP_Wv := ctrl.CoreWebView2
        try MVP_Ctrl.DefaultBackgroundColor := 0xFFF7F7F8
        try MVP_Ctrl.IsVisible := true
        try MVP_Wv.add_WebMessageReceived(MVP_OnMessage)
        MVP_Config := MVP_LoadConfig()
        MVP_RefreshBindings(true)
        html := FileExist(MVP_HtmlFile) ? FileRead(MVP_HtmlFile, "UTF-8") : "<!doctype html><html><body style='font-family:Segoe UI;padding:20px'>Missing html file</body></html>"
        MVP_Wv.NavigateToString(html)
        SetTimer(MVP_PushConfigToPage, -120)
        SetTimer(MVP_PollRuntime, 350)
    } catch as e {
        MsgBox("WebView 初始化失败:`n" e.Message, "Voice Input MVP", "Iconx")
        ExitApp()
    }
}

MVP_DefaultConfig() {
    return Map(
        "version", 2,
        "triggerSource", MVP_DefaultTriggerSource(),
        "actions", MVP_DefaultActions(),
        "scenes", MVP_DefaultScenes()
    )
}

MVP_DefaultTriggerSource() {
    return Map(
        "id", "source_ralt_default",
        "label", "右 Alt",
        "mode", "single_press",
        "grouping", "exact",
        "rawEvents", [
            MVP_MakeRawEvent("keyboard", "Alt", "AltRight", 2, "keydown", "RAlt", "右 Alt")
        ]
    )
}

MVP_DefaultActions() {
    return Map(
        "start", "voice_start",
        "cancel", "voice_cancel",
        "send", "voice_send"
    )
}

MVP_DefaultScenes() {
    return [
        MVP_DefaultScene("global", "全局", true, "block", 2000, 5000, "any", ""),
        MVP_DefaultScene("editor", "编辑器", false, "pass_through", 2000, 5000, "process_contains", "Code.exe;Cursor.exe;idea64.exe;notepad++.exe;devenv.exe"),
        MVP_DefaultScene("browser", "浏览器", false, "pass_through", 2000, 5000, "process_contains", "chrome.exe;msedge.exe;firefox.exe;brave.exe")
    ]
}

MVP_DefaultScene(id, label, enabled, overrideMode, cancelWindowMs, sendDelayMs, matchKind, matchValue) {
    return Map(
        "id", id,
        "label", label,
        "enabled", enabled,
        "overrideMode", overrideMode,
        "cancelWindowMs", cancelWindowMs,
        "sendDelayMs", sendDelayMs,
        "match", Map(
            "kind", matchKind,
            "value", matchValue
        )
    )
}

MVP_MakeRawEvent(device, key, code, location, eventType, hotkey, label := "") {
    return Map(
        "device", device,
        "key", key,
        "code", code,
        "location", location,
        "type", eventType,
        "hotkey", hotkey,
        "label", (label = "" ? hotkey : label)
    )
}

MVP_EnsureConfigDir() {
    global MVP_ConfigFile
    dir := RegExReplace(MVP_ConfigFile, "\\[^\\]+$")
    if (dir != "" && !DirExist(dir))
        DirCreate(dir)
}

MVP_LoadConfig() {
    global MVP_ConfigFile
    try {
        raw := FileExist(MVP_ConfigFile) ? FileRead(MVP_ConfigFile, "UTF-8") : ""
        if (raw = "")
            return MVP_DefaultConfig()
        cfg := Jxon_Load(raw)
        if !(cfg is Map)
            return MVP_DefaultConfig()
        return MVP_NormalizeConfig(cfg)
    } catch as e {
        MVP_Log("config", "load_failed", e.Message)
        return MVP_DefaultConfig()
    }
}

MVP_WriteConfig(cfg) {
    global MVP_ConfigFile
    try FileDelete(MVP_ConfigFile)
    FileAppend(Jxon_Dump(cfg), MVP_ConfigFile, "UTF-8")
}

MVP_NormalizeConfig(cfg) {
    normalized := MVP_DefaultConfig()
    normalized["version"] := 2
    if cfg.Has("actions") && (cfg["actions"] is Map)
        normalized["actions"] := MVP_NormalizeActions(cfg["actions"])
    if cfg.Has("scenes") && (cfg["scenes"] is Array)
        normalized["scenes"] := MVP_NormalizeScenes(cfg["scenes"])
    else
        normalized["scenes"] := MVP_ScenesFromLegacy(cfg)
    if cfg.Has("triggerSource") && (cfg["triggerSource"] is Map)
        normalized["triggerSource"] := MVP_NormalizeTriggerSource(cfg["triggerSource"])
    else
        normalized["triggerSource"] := MVP_BuildSourceFromLegacyKey(MVP_LegacyRecordKey(cfg))
    return normalized
}

MVP_NormalizeActions(actions) {
    next := MVP_DefaultActions()
    for k, v in actions
        next[k] := String(v)
    return next
}

MVP_NormalizeScenes(scenes) {
    defaults := MVP_DefaultScenes()
    out := []
    ids := Map()
    for scene in scenes {
        if !(scene is Map)
            continue
        out.Push(MVP_NormalizeScene(scene))
        ids[out[out.Length]["id"]] := true
    }
    for scene in defaults {
        if !ids.Has(scene["id"])
            out.Push(scene)
    }
    return out
}

MVP_NormalizeScene(scene) {
    id := String(scene.Has("id") ? scene["id"] : "")
    default := MVP_FindDefaultScene(id)
    next := default ? MVP_CloneMap(default) : MVP_DefaultScene(id = "" ? "custom" : id, id = "" ? "自定义" : id, false, "block", 2000, 5000, "any", "")
    next["label"] := String(scene.Has("label") ? scene["label"] : next["label"])
    next["enabled"] := scene.Has("enabled") ? (scene["enabled"] ? true : false) : next["enabled"]
    next["overrideMode"] := String(scene.Has("overrideMode") ? scene["overrideMode"] : next["overrideMode"])
    next["cancelWindowMs"] := Integer(scene.Has("cancelWindowMs") ? scene["cancelWindowMs"] : next["cancelWindowMs"])
    next["sendDelayMs"] := Integer(scene.Has("sendDelayMs") ? scene["sendDelayMs"] : next["sendDelayMs"])
    if scene.Has("match") && (scene["match"] is Map) {
        next["match"] := Map(
            "kind", String(scene["match"].Has("kind") ? scene["match"]["kind"] : next["match"]["kind"]),
            "value", String(scene["match"].Has("value") ? scene["match"]["value"] : next["match"]["value"])
        )
    }
    return next
}

MVP_FindDefaultScene(id) {
    for scene in MVP_DefaultScenes() {
        if (scene["id"] = id)
            return scene
    }
    return 0
}

MVP_ScenesFromLegacy(cfg) {
    cancelMs := Integer(cfg.Has("intervalMs") ? cfg["intervalMs"] : 2000)
    sendMs := Integer(cfg.Has("enterDelayMs") ? cfg["enterDelayMs"] : 5000)
    return [
        MVP_DefaultScene("global", "全局", true, "block", cancelMs, sendMs, "any", ""),
        MVP_DefaultScene("editor", "编辑器", false, "pass_through", cancelMs, sendMs, "process_contains", "Code.exe;Cursor.exe;idea64.exe;notepad++.exe;devenv.exe"),
        MVP_DefaultScene("browser", "浏览器", false, "pass_through", cancelMs, sendMs, "process_contains", "chrome.exe;msedge.exe;firefox.exe;brave.exe")
    ]
}

MVP_LegacyRecordKey(cfg) {
    if cfg.Has("recordKey")
        return String(cfg["recordKey"])
    return "RAlt"
}

MVP_BuildSourceFromLegacyKey(key) {
    legacy := Trim(String(key))
    if (legacy = "" || legacy = "``")
        legacy := "RAlt"
    if (legacy = "AutoTrigger")
        return MVP_MakeVolumeMixedSource()
    evt := MVP_CanonicalEventFromHotkey(legacy)
    return Map(
        "id", "source_" . MVP_Slug(evt["hotkey"]),
        "label", evt["label"],
        "mode", "single_press",
        "grouping", "exact",
        "rawEvents", [evt]
    )
}

MVP_NormalizeTriggerSource(source) {
    events := []
    if source.Has("rawEvents") && (source["rawEvents"] is Array) {
        for raw in source["rawEvents"] {
            evt := MVP_NormalizeRawEvent(raw)
            if evt
                events.Push(evt)
        }
    }
    if (events.Length = 0) {
        fallback := source.Has("label") ? String(source["label"]) : "RAlt"
        return MVP_BuildSourceFromLegacyKey(fallback)
    }
    group := String(source.Has("grouping") ? source["grouping"] : "exact")
    if MVP_SourceContainsVolumeHotkey(events)
        return MVP_BuildSourceFromCapturedEvents(events)
    return Map(
        "id", String(source.Has("id") ? source["id"] : "source_" . MVP_Slug(events[1]["hotkey"])),
        "label", String(source.Has("label") ? source["label"] : events[1]["label"]),
        "mode", "single_press",
        "grouping", group = "same_source_group" ? "same_source_group" : "exact",
        "rawEvents", MVP_DedupeRawEvents(events)
    )
}

MVP_NormalizeRawEvent(raw) {
    if !(raw is Map)
        return 0
    hotkey := raw.Has("hotkey") ? String(raw["hotkey"]) : MVP_DeriveHotkeyFromRaw(raw)
    if (hotkey = "")
        return 0
    label := raw.Has("label") ? String(raw["label"]) : hotkey
    return Map(
        "device", String(raw.Has("device") ? raw["device"] : "keyboard"),
        "key", String(raw.Has("key") ? raw["key"] : hotkey),
        "code", String(raw.Has("code") ? raw["code"] : hotkey),
        "location", Integer(raw.Has("location") ? raw["location"] : 0),
        "type", String(raw.Has("type") ? raw["type"] : "keydown"),
        "hotkey", hotkey,
        "label", label
    )
}

MVP_BuildSourceFromCapturedEvents(rawEvents) {
    events := []
    for raw in rawEvents {
        evt := MVP_NormalizeRawEvent(raw)
        if evt
            events.Push(evt)
    }
    if (events.Length = 0)
        return MVP_DefaultTriggerSource()
    if MVP_SourceContainsVolumeHotkey(events)
        return MVP_MakeVolumeMixedSource()
    events := MVP_DedupeRawEvents(events)
    first := events[1]
    return Map(
        "id", "source_" . MVP_Slug(first["hotkey"]),
        "label", first["label"],
        "mode", "single_press",
        "grouping", "exact",
        "rawEvents", events
    )
}

MVP_MakeVolumeMixedSource() {
    return Map(
        "id", "source_volume_mixed",
        "label", "音量混合单键",
        "mode", "single_press",
        "grouping", "same_source_group",
        "rawEvents", [
            MVP_CanonicalEventFromHotkey("Volume_Down", "音量下"),
            MVP_CanonicalEventFromHotkey("Volume_Up", "音量上")
        ]
    )
}

MVP_CanonicalEventFromHotkey(hotkey, label := "") {
    hk := String(hotkey)
    switch hk {
        case "RAlt":
            return MVP_MakeRawEvent("keyboard", "Alt", "AltRight", 2, "keydown", hk, label = "" ? "右 Alt" : label)
        case "LAlt":
            return MVP_MakeRawEvent("keyboard", "Alt", "AltLeft", 1, "keydown", hk, label = "" ? "左 Alt" : label)
        case "Volume_Down":
            return MVP_MakeRawEvent("keyboard", "AudioVolumeDown", "AudioVolumeDown", 0, "keydown", hk, label = "" ? "音量下" : label)
        case "Volume_Up":
            return MVP_MakeRawEvent("keyboard", "AudioVolumeUp", "AudioVolumeUp", 0, "keydown", hk, label = "" ? "音量上" : label)
        case "Volume_Mute":
            return MVP_MakeRawEvent("keyboard", "AudioVolumeMute", "AudioVolumeMute", 0, "keydown", hk, label = "" ? "静音" : label)
        case "LButton", "RButton", "MButton", "XButton1", "XButton2":
            return MVP_MakeRawEvent("mouse", hk, hk, 0, "mousedown", hk, label = "" ? hk : label)
        default:
            return MVP_MakeRawEvent("keyboard", hk, hk, 0, "keydown", hk, label = "" ? hk : label)
    }
}

MVP_DeriveHotkeyFromRaw(raw) {
    device := String(raw.Has("device") ? raw["device"] : "keyboard")
    if (device = "mouse")
        return MVP_MouseButtonToHotkey(Integer(raw.Has("button") ? raw["button"] : -1))
    key := String(raw.Has("key") ? raw["key"] : "")
    code := String(raw.Has("code") ? raw["code"] : "")
    location := Integer(raw.Has("location") ? raw["location"] : 0)
    if (code = "AltRight" || (key = "Alt" && location = 2) || key = "AltGraph")
        return "RAlt"
    if (code = "AltLeft" || (key = "Alt" && location = 1))
        return "LAlt"
    if (code = "ControlRight" || (key = "Control" && location = 2))
        return "RCtrl"
    if (code = "ControlLeft" || (key = "Control" && location = 1))
        return "LCtrl"
    if (code = "ShiftRight" || (key = "Shift" && location = 2))
        return "RShift"
    if (code = "ShiftLeft" || (key = "Shift" && location = 1))
        return "LShift"
    switch key {
        case "AudioVolumeDown":
            return "Volume_Down"
        case "AudioVolumeUp":
            return "Volume_Up"
        case "AudioVolumeMute":
            return "Volume_Mute"
        case "MediaTrackNext":
            return "Media_Next"
        case "MediaTrackPrevious":
            return "Media_Prev"
        case "MediaPlayPause":
            return "Media_Play_Pause"
        case "MediaStop":
            return "Media_Stop"
        case "Escape":
            return "Esc"
        case " ":
            return "Space"
        case "ArrowUp":
            return "Up"
        case "ArrowDown":
            return "Down"
        case "ArrowLeft":
            return "Left"
        case "ArrowRight":
            return "Right"
        case "Enter":
            return "Enter"
        case "Tab":
            return "Tab"
        case "Backspace":
            return "Backspace"
        case "Delete":
            return "Delete"
        case "Home":
            return "Home"
        case "End":
            return "End"
        case "PageUp":
            return "PgUp"
        case "PageDown":
            return "PgDn"
        case "Insert":
            return "Insert"
        case "CapsLock":
            return "CapsLock"
    }
    if (StrLen(key) = 1)
        return StrUpper(key)
    return key
}

MVP_MouseButtonToHotkey(button) {
    switch button {
        case 0:
            return "LButton"
        case 1:
            return "MButton"
        case 2:
            return "RButton"
        case 3:
            return "XButton1"
        case 4:
            return "XButton2"
        default:
            return ""
    }
}

MVP_SourceContainsVolumeHotkey(events) {
    for evt in events {
        hk := evt["hotkey"]
        if (hk = "Volume_Down" || hk = "Volume_Up")
            return true
    }
    return false
}

MVP_DedupeRawEvents(events) {
    out := []
    seen := Map()
    for evt in events {
        sig := evt["hotkey"] . "|" . evt["type"]
        if seen.Has(sig)
            continue
        seen[sig] := true
        out.Push(evt)
    }
    return out
}

MVP_PollRuntime() {
    global MVP_ConfigFile, MVP_ConfigStamp, MVP_Config
    try {
        if !FileExist(MVP_ConfigFile) {
            MVP_EnsureConfigDir()
            MVP_Config := MVP_DefaultConfig()
            MVP_WriteConfig(MVP_Config)
            MVP_ConfigStamp := FileGetTime(MVP_ConfigFile, "M")
            MVP_RefreshBindings(true)
            MVP_PushConfigToPage()
            return
        }
        stamp := FileGetTime(MVP_ConfigFile, "M")
        if (stamp != "" && stamp != MVP_ConfigStamp) {
            MVP_ConfigStamp := stamp
            MVP_Config := MVP_LoadConfig()
            MVP_RefreshBindings(true)
            MVP_PushConfigToPage()
            MVP_Log("config", "reloaded", MVP_RuntimeSummary())
        } else {
            MVP_RefreshBindings(false)
            MVP_PushRuntimeToPage("")
        }
    } catch as e {
        MVP_Log("runtime", "poll_failed", e.Message)
    }
}

MVP_RefreshBindings(force := false) {
    global MVP_Config, MVP_BoundSignature, MVP_ActiveSceneId, MVP_LastSceneId
    if !(MVP_Config is Map)
        MVP_Config := MVP_DefaultConfig()
    scene := MVP_GetActiveScene(MVP_Config["scenes"])
    source := MVP_Config["triggerSource"]
    signature := MVP_BuildBindingSignature(source, scene)
    if force || signature != MVP_BoundSignature {
        MVP_RebindTrigger(MVP_BuildBindingHotkeys(source, scene))
        MVP_BoundSignature := signature
        MVP_LastSceneId := MVP_ActiveSceneId
        MVP_ActiveSceneId := scene["id"]
        MVP_ResetStateMachine()
        MVP_Log("runtime", "rebind", signature)
    } else {
        MVP_ActiveSceneId := scene["id"]
    }
    MVP_RefreshConflicts(false)
}

MVP_BuildBindingSignature(source, scene) {
    base := scene["id"] . "|" . scene["overrideMode"] . "|"
    for hk in MVP_SourceHotkeys(source)
        base .= hk . ","
    return base
}

MVP_SourceHotkeys(source) {
    hotkeys := []
    if !(source is Map)
        return hotkeys
    if !source.Has("rawEvents")
        return hotkeys
    seen := Map()
    for evt in source["rawEvents"] {
        hk := String(evt.Has("hotkey") ? evt["hotkey"] : "")
        if (hk = "" || seen.Has(hk))
            continue
        seen[hk] := true
        hotkeys.Push(hk)
    }
    return hotkeys
}

MVP_BuildBindingHotkeys(source, scene) {
    mode := String(scene["overrideMode"])
    prefix := (mode = "pass_through") ? "~" : ""
    out := []
    for hk in MVP_SourceHotkeys(source)
        out.Push(prefix . hk)
    return out
}

MVP_RebindTrigger(nextHotkeys) {
    global MVP_BoundHotkeys
    for hk in MVP_BoundHotkeys {
        try Hotkey(hk, "Off")
    }
    MVP_BoundHotkeys := []
    for hk in nextHotkeys {
        try {
            Hotkey(hk, MVP_OnTrigger, "On")
            MVP_BoundHotkeys.Push(hk)
        } catch as e {
            MVP_Log("runtime", "bind_failed", hk . " | " . e.Message)
        }
    }
}

MVP_ResetStateMachine() {
    global MVP_Count, MVP_LastTick, MVP_EnterTimer, MVP_LastPhysicalHotkey, MVP_LastPhysicalTick
    MVP_Count := 0
    MVP_LastTick := 0
    MVP_LastPhysicalHotkey := ""
    MVP_LastPhysicalTick := 0
    if MVP_EnterTimer {
        SetTimer(MVP_EnterTimer, 0)
        MVP_EnterTimer := 0
    }
}

MVP_GetActiveScene(scenes) {
    proc := ""
    title := ""
    try proc := WinGetProcessName("A")
    try title := WinGetTitle("A")
    for scene in scenes {
        if !scene["enabled"]
            continue
        if (scene["id"] = "global")
            continue
        if MVP_IsSceneMatch(scene, proc, title)
            return scene
    }
    for scene in scenes {
        if (scene["id"] = "global")
            return scene
    }
    return MVP_DefaultScenes()[1]
}

MVP_IsSceneMatch(scene, proc, title) {
    kind := String(scene["match"]["kind"])
    value := String(scene["match"]["value"])
    if (kind = "any")
        return true
    if (kind = "process_contains") {
        for part in StrSplit(value, ";") {
            token := Trim(part)
            if (token != "" && InStr(StrLower(proc), StrLower(token)))
                return true
        }
        return false
    }
    if (kind = "title_contains") {
        for part in StrSplit(value, ";") {
            token := Trim(part)
            if (token != "" && InStr(StrLower(title), StrLower(token)))
                return true
        }
    }
    return false
}

MVP_OnTrigger(*) {
    global MVP_Config, MVP_Count, MVP_LastTick, MVP_EnterTimer, MVP_LastPhysicalHotkey, MVP_LastPhysicalTick, MVP_GroupDedupMs
    scene := MVP_GetActiveScene(MVP_Config["scenes"])
    source := MVP_Config["triggerSource"]
    now := A_TickCount
    currentHotkey := MVP_CanonicalBoundHotkey(A_ThisHotkey)
    if (source["grouping"] = "same_source_group" && MVP_LastPhysicalHotkey != "" && now - MVP_LastPhysicalTick <= MVP_GroupDedupMs) {
        if MVP_SourceHasHotkey(source, currentHotkey) && MVP_SourceHasHotkey(source, MVP_LastPhysicalHotkey) {
            MVP_Log("trigger", "group_dedup", currentHotkey)
            return
        }
    }
    MVP_LastPhysicalHotkey := currentHotkey
    MVP_LastPhysicalTick := now

    resetMs := Integer(scene["cancelWindowMs"])
    enterDelayMs := Integer(scene["sendDelayMs"])
    delta := MVP_LastTick ? (now - MVP_LastTick) : 0
    MVP_Log("trigger", "fire", "hotkey=" currentHotkey " scene=" scene["id"] " delta=" delta " count=" MVP_Count)

    if (MVP_LastTick && delta < resetMs) {
        if MVP_EnterTimer {
            SetTimer(MVP_EnterTimer, 0)
            MVP_EnterTimer := 0
        }
        MVP_Count := 0
        MVP_LastTick := now
        MVP_DoVoiceCancel()
        MVP_PushRuntimeToPage("voice_cancel")
        return
    }

    MVP_DoVoiceStart()
    MVP_Count += 1
    MVP_LastTick := now
    MVP_PushRuntimeToPage("voice_start")

    if MVP_EnterTimer {
        SetTimer(MVP_EnterTimer, 0)
        MVP_EnterTimer := 0
    }

    if (MVP_Count = 2) {
        MVP_EnterTimer := MVP_SendEnter.Bind()
        SetTimer(MVP_EnterTimer, -enterDelayMs)
        MVP_Log("timer", "enter_scheduled", "delay=" enterDelayMs)
        MVP_PushRuntimeToPage("voice_send_wait")
        return
    }

    if (MVP_Count >= 3)
        MVP_Count := 1
}

MVP_DoVoiceStart() {
    MVP_Log("action", "voice_start", "")
    SendEvent("{vkA5sc138 down}")
    Sleep(35)
    SendEvent("{vkA5sc138 up}")
}

MVP_DoVoiceCancel() {
    MVP_Log("action", "voice_cancel", "")
    Send "{Esc}"
}

MVP_SendEnter() {
    global MVP_EnterTimer
    MVP_EnterTimer := 0
    MVP_Log("action", "voice_send", "")
    Send "{Enter}"
    MVP_PushRuntimeToPage("voice_send")
}

MVP_SourceHasHotkey(source, hotkey) {
    for hk in MVP_SourceHotkeys(source) {
        if (hk = hotkey)
            return true
    }
    return false
}

MVP_CanonicalBoundHotkey(hk) {
    clean := String(hk)
    while (SubStr(clean, 1, 1) = "~")
        clean := SubStr(clean, 2)
    return clean
}

MVP_PushConfigToPage() {
    global MVP_Wv, MVP_Config
    try {
        if MVP_Wv && (MVP_Config is Map)
            MVP_Wv.PostWebMessageAsJson(Jxon_Dump(Map("type", "mvp_init", "config", MVP_Config)))
        MVP_PushRuntimeToPage("config_push")
    } catch as e {
        MVP_Log("ui", "push_init_failed", e.Message)
    }
}

MVP_PushRuntimeToPage(lastAction := "") {
    global MVP_Wv, MVP_Config, MVP_BoundHotkeys, MVP_ActiveSceneId, MVP_LastRuntimeSignature, MVP_ConflictWarnings
    try {
        if !MVP_Wv
            return
        scene := MVP_GetActiveScene(MVP_Config["scenes"])
        bindings := ""
        for hk in MVP_BoundHotkeys
            bindings .= (bindings = "" ? "" : ", ") . hk
        payload := Map(
            "type", "mvp_runtime",
            "activeSceneId", scene["id"],
            "activeSceneLabel", scene["label"],
            "bindings", bindings,
            "lastAction", lastAction = "" ? "-" : lastAction,
            "sourceLabel", MVP_Config["triggerSource"]["label"],
            "sourceGrouping", MVP_Config["triggerSource"]["grouping"],
            "conflicts", MVP_CloneArray(MVP_ConflictWarnings)
        )
        signature := Jxon_Dump(payload)
        if (signature = MVP_LastRuntimeSignature && lastAction = "")
            return
        MVP_LastRuntimeSignature := signature
        MVP_Wv.PostWebMessageAsJson(signature)
    } catch as e {
        MVP_Log("ui", "push_runtime_failed", e.Message)
    }
}

MVP_OnMessage(sender, args) {
    global MVP_Config, MVP_ConfigFile, MVP_ConfigStamp, MVP_Wv
    try {
        raw := MVP_CopyWebMessageJson(args)
        if (raw = "")
            return
        msg := Jxon_Load(raw)
        if !(msg is Map)
            return
        msgType := String(msg.Has("type") ? msg["type"] : "")
        switch msgType {
            case "mvp_ready":
                MVP_PushConfigToPage()
            case "mvp_save":
                json := String(msg.Has("json") ? msg["json"] : "")
                if (json = "")
                    return
                next := Jxon_Load(json)
                if !(next is Map)
                    return
                MVP_Config := MVP_NormalizeConfig(next)
                MVP_WriteConfig(MVP_Config)
                MVP_ConfigStamp := FileGetTime(MVP_ConfigFile, "M")
                MVP_RefreshBindings(true)
                MVP_Log("config", "saved", MVP_RuntimeSummary())
                try MVP_Wv.PostWebMessageAsJson(Jxon_Dump(Map("type", "mvp_saved", "ok", true)))
                MVP_PushRuntimeToPage("saved")
            case "mvp_capture_source":
                if !msg.Has("rawEvents")
                    return
                source := MVP_BuildSourceFromCapturedEvents(msg["rawEvents"])
                try MVP_Wv.PostWebMessageAsJson(Jxon_Dump(Map("type", "mvp_source_captured", "source", source)))
            case "mvp_request_runtime":
                MVP_PushRuntimeToPage("runtime_refresh")
        }
    } catch as e {
        MVP_Log("ui", "message_failed", e.Message)
        try MsgBox("消息处理失败:`n" e.Message, "Voice Input MVP", "Iconx")
    }
}

MVP_CopyWebMessageJson(args) {
    try {
        if IsObject(args) {
            try {
                raw := args.TryGetWebMessageAsString()
                if (raw != "")
                    return String(raw)
            } catch {
            }
            try {
                if args.HasProp("WebMessageAsJson")
                    return String(args.WebMessageAsJson)
            } catch {
            }
        }
    } catch {
    }
    return ""
}

MVP_RefreshConflicts(force := false) {
    global MVP_LastConflictCheckTick, MVP_ConflictWarnings
    now := A_TickCount
    if !force && now - MVP_LastConflictCheckTick < 4000
        return
    MVP_LastConflictCheckTick := now
    MVP_ConflictWarnings := MVP_FindConflictWarnings()
}

MVP_FindConflictWarnings() {
    global MVP_SelfPid
    warnings := []
    rows := MVP_QueryAutoHotkeyProcesses()
    for row in rows {
        if !(row is Map)
            continue
        cmd := String(row.Has("CommandLine") ? row["CommandLine"] : "")
        pid := Integer(row.Has("ProcessId") ? row["ProcessId"] : 0)
        if (pid = MVP_SelfPid || cmd = "")
            continue
        if InStr(StrLower(cmd), StrLower("hid_mixed_experiment_v2.ahk"))
            warnings.Push("检测到备份原型正在运行：hid_mixed_experiment_v2.ahk")
        else if InStr(StrLower(cmd), StrLower("launch_voice_input_manager.ahk"))
            warnings.Push("检测到另一个 manager 实例或副本正在运行")
    }
    return warnings
}

MVP_QueryAutoHotkeyProcesses() {
    global MVP_SelfPid
    rows := []
    try {
        locator := ComObject("WbemScripting.SWbemLocator")
        service := locator.ConnectServer(".", "root\cimv2")
        query := "SELECT ProcessId, CommandLine, Name FROM Win32_Process WHERE Name LIKE 'AutoHotkey%'"
        for proc in service.ExecQuery(query) {
            pid := Integer(proc.ProcessId)
            if (pid = MVP_SelfPid)
                continue
            rows.Push(Map(
                "ProcessId", pid,
                "CommandLine", String(proc.CommandLine)
            ))
        }
    } catch as e {
        MVP_Log("runtime", "process_query_failed", e.Message)
    }
    return rows
}

MVP_RuntimeSummary() {
    global MVP_Config, MVP_BoundHotkeys, MVP_ActiveSceneId
    source := MVP_Config["triggerSource"]
    return "source=" . source["label"]
        . " group=" . source["grouping"]
        . " scene=" . MVP_ActiveSceneId
        . " bindings=" . MVP_ArrayToCsv(MVP_BoundHotkeys)
}

MVP_ArrayToCsv(arr) {
    out := ""
    for item in arr
        out .= (out = "" ? "" : ",") . String(item)
    return out
}

MVP_Slug(text) {
    cleaned := RegExReplace(StrLower(String(text)), "[^a-z0-9]+", "_")
    cleaned := Trim(cleaned, "_")
    return cleaned = "" ? "source" : cleaned
}

MVP_CloneMap(obj) {
    if !(obj is Map)
        return obj
    out := Map()
    for k, v in obj
        out[k] := (v is Map) ? MVP_CloneMap(v) : ((v is Array) ? MVP_CloneArray(v) : v)
    return out
}

MVP_CloneArray(arr) {
    out := []
    for v in arr
        out.Push((v is Map) ? MVP_CloneMap(v) : ((v is Array) ? MVP_CloneArray(v) : v))
    return out
}

MVP_Log(scope, event, detail := "") {
    global MVP_LogFile
    try {
        line := "[" A_Now "][" scope "][" event "] " detail "`n"
        FileAppend(line, MVP_LogFile, "UTF-8")
    } catch {
    }
}

NmerCatch(scope, err, detail := "") {
}

NMER_Log(scope, event, detail := "") {
}



