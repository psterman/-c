#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ..\lib\ahk\WebView2.ahk
#Include ..\lib\ahk\Jxon.ahk

global MVP_Root := A_ScriptDir
global MVP_ConfigFile := MVP_Root "\voice_input_settings.json"
global MVP_HtmlFile := MVP_Root "\html\VoiceInputSettings.html"

global MVP_Gui := 0
global MVP_Ctrl := 0
global MVP_Wv := 0
global MVP_Config := 0
global MVP_ConfigStamp := ""
global MVP_TriggerHotkey := ""
global MVP_TriggerHotkeys := []
global MVP_Count := 0
global MVP_LastTick := 0
global MVP_DebounceMs := 80
global MVP_KeyPressDurationMs := 50
global MVP_LastTrigger := 0
global MVP_EnterTimer := 0
global MVP_Paused := false
global MVP_RecordingMode := false
global MVP_RuntimeEnabled := false
global MVP_LogFile := MVP_Root "\voice_input_manager.log"

if !FileExist(MVP_ConfigFile) {
    MVP_EnsureConfigDir()
    MVP_WriteDefaultConfig()
}

OpenManager()
return

OpenManager() {
    global MVP_Gui
    MVP_Gui := Gui("+Resize +MinSize980x720", "一键编程管理器")
    MVP_Gui.OnEvent("Close", (*) => ExitApp())
    MVP_Gui.OnEvent("Escape", (*) => ExitApp())
    MVP_Gui.Show("w1180 h820")
    try {
        WebView2.create(MVP_Gui.Hwnd, MVP_OnCreated)
    } catch as e {
        MsgBox("WebView 创建失败:`n" e.Message, "Voice Input MVP", "Iconx")
        ExitApp()
    }
}

MVP_OnCreated(ctrl) {
    global MVP_Ctrl, MVP_Wv, MVP_HtmlFile, MVP_ConfigFile, MVP_Config
    try {
        MVP_Ctrl := ctrl
        MVP_Wv := ctrl.CoreWebView2
        try MVP_Ctrl.DefaultBackgroundColor := 0xFF0A0A0A
        try MVP_Ctrl.IsVisible := true
        try MVP_Wv.add_WebMessageReceived(MVP_OnMessage)
        MVP_Config := MVP_LoadConfig()
        MVP_ApplyConfig(true)
        html := FileExist(MVP_HtmlFile) ? FileRead(MVP_HtmlFile, "UTF-8") : "<!doctype html><html><body style='font-family:Segoe UI;padding:20px'>Missing html file</body></html>"
        MVP_Wv.NavigateToString(html)
        SetTimer(MVP_PushConfigToPage, -100)
        SetTimer(MVP_PollConfig, 500)
    } catch as e {
        MsgBox("WebView 初始化失败:`n" e.Message, "Voice Input MVP", "Iconx")
        ExitApp()
    }
}

MVP_EnsureConfigDir() {
    global MVP_ConfigFile
    dir := RegExReplace(MVP_ConfigFile, "\\[^\\]+$")
    if (dir != "" && !DirExist(dir))
        DirCreate(dir)
}

MVP_WriteDefaultConfig() {
    global MVP_ConfigFile
    cfg := MVP_DefaultConfig()
    try FileAppend(Jxon_Dump(cfg), MVP_ConfigFile, "UTF-8")
    MVP_Log("config", "write_default", Jxon_Dump(cfg))
}

MVP_DefaultConfig() {
    return Map(
        "recordKey", "RAlt",
        "intervalMs", 2000,
        "cancelEnabled", true,
        "autoEnterEnabled", true,
        "enterDelayMs", 5000,
        "debounceMs", 80,
        "keyPressDurationMs", 50,
        "mappings", [
            Map("command", "voice_start", "key", "RAlt"),
            Map("command", "voice_send", "key", ""),
            Map("command", "voice_stop", "key", "")
        ]
    )
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
    } catch {
        return MVP_DefaultConfig()
    }
}

MVP_NormalizeConfig(cfg) {
    if !(cfg is Map)
        return cfg
    if cfg.Has("recordKey") {
        k := Trim(String(cfg["recordKey"]))
        switch k {
            case "AutoTrigger", "AudioVolumeDown", "AudioVolumeUp", "AudioVolumeMute", "Volume_Down", "Volume_Up", "Volume_Mute":
                cfg["recordKey"] := "AutoTrigger"
            case "MediaTrackNext", "Media_Next":
                cfg["recordKey"] := "Media_Next"
            case "MediaTrackPrevious", "Media_Prev":
                cfg["recordKey"] := "Media_Prev"
            case "MediaPlayPause", "Media_Play_Pause":
                cfg["recordKey"] := "Media_Play_Pause"
            case "MediaStop", "Media_Stop":
                cfg["recordKey"] := "Media_Stop"
            case "", "``":
                cfg["recordKey"] := "RAlt"
            default:
                cfg["recordKey"] := k
        }
    }
    if cfg.Has("intervalMs") {
        val := Integer(cfg["intervalMs"])
        cfg["intervalMs"] := (val < 200) ? 200 : val
    } else {
        cfg["intervalMs"] := 2000
    }
    if !cfg.Has("enterDelayMs")
        cfg["enterDelayMs"] := 5000
    if cfg.Has("cancelEnabled") {
        v := cfg["cancelEnabled"]
        if (v = "false" || v = "0")
            cfg["cancelEnabled"] := false
        else
            cfg["cancelEnabled"] := !!v
    } else {
        cfg["cancelEnabled"] := true
    }
    if cfg.Has("autoEnterEnabled") {
        v := cfg["autoEnterEnabled"]
        if (v = "false" || v = "0")
            cfg["autoEnterEnabled"] := false
        else
            cfg["autoEnterEnabled"] := !!v
    } else {
        cfg["autoEnterEnabled"] := true
    }
    if !cfg.Has("debounceMs")
        cfg["debounceMs"] := 80
    if !cfg.Has("keyPressDurationMs")
        cfg["keyPressDurationMs"] := 50
    if !cfg.Has("mappings")
        cfg["mappings"] := MVP_DefaultConfig()["mappings"]
    return cfg
}

MVP_PollConfig() {
    global MVP_ConfigFile, MVP_ConfigStamp, MVP_Config
    try {
        if !FileExist(MVP_ConfigFile) {
            MVP_EnsureConfigDir()
            MVP_WriteDefaultConfig()
            MVP_Config := MVP_DefaultConfig()
            MVP_ApplyConfig(true)
            return
        }
        stamp := FileGetTime(MVP_ConfigFile, "M")
        if (stamp = "")
            return
        if (stamp != MVP_ConfigStamp) {
            MVP_ConfigStamp := stamp
            MVP_Config := MVP_LoadConfig()
            MVP_ApplyConfig(true)
            MVP_PushConfigToPage()
            MVP_Log("config", "reloaded", MVP_DescribeRuntime())
        }
    } catch as e {
        OutputDebug("[MVP] poll failed: " . e.Message)
    }
}

MVP_ApplyConfig(force := false) {
    global MVP_Config, MVP_TriggerHotkey, MVP_TriggerHotkeys, MVP_Count, MVP_LastTick, MVP_EnterTimer, MVP_RuntimeEnabled, MVP_DebounceMs, MVP_KeyPressDurationMs, MVP_LastTrigger
    if !(MVP_Config is Map)
        MVP_Config := MVP_DefaultConfig()
        key := String(MVP_Config.Has("recordKey") ? MVP_Config["recordKey"] : "RAlt")
    if (key = "" || key = "``")
        key := "RAlt"
    if (key = "Volume_Down" || key = "Volume_Up" || key = "Volume_Mute")
        key := "AutoTrigger"
    MVP_DebounceMs := Integer(MVP_Config.Has("debounceMs") ? MVP_Config["debounceMs"] : 80)
    MVP_KeyPressDurationMs := Integer(MVP_Config.Has("keyPressDurationMs") ? MVP_Config["keyPressDurationMs"] : 50)
    MVP_LastTrigger := 0
    if force || (key != MVP_TriggerHotkey) {
        MVP_RebindTrigger(MVP_TriggerHotkey, key)
        MVP_TriggerHotkey := key
    }
    MVP_Count := 0
    MVP_LastTick := 0
    if MVP_EnterTimer {
        SetTimer(MVP_EnterTimer, 0)
        MVP_EnterTimer := 0
    }
    MVP_RuntimeEnabled := true
    MVP_Log("runtime", "apply_config", MVP_DescribeRuntime())
}

MVP_RebindTrigger(oldKey, newKey) {
    global MVP_TriggerHotkeys, MVP_Paused
    for hk in MVP_TriggerHotkeys {
        try Hotkey(hk, "Off")
    }
    MVP_TriggerHotkeys := []
    if (newKey = "AutoTrigger") {
        Hotkey("Volume_Up", MVP_OnTrigger, "On")
        Hotkey("Volume_Down", MVP_OnTrigger, "On")
        MVP_TriggerHotkeys := ["Volume_Up", "Volume_Down"]
    } else if (newKey != "") {
        Hotkey(newKey, MVP_OnTrigger, "On")
        MVP_TriggerHotkeys := [newKey]
    }
    ; Restore paused state: if paused, immediately re-disable hotkeys
    if MVP_Paused {
        for hk in MVP_TriggerHotkeys
            try Hotkey(hk, "Off")
    }
}

MVP_Pause() {
    global MVP_TriggerHotkeys, MVP_Paused
    if MVP_Paused
        return
    MVP_Paused := true
    for hk in MVP_TriggerHotkeys {
        try Hotkey(hk, "Off")
    }
    MVP_Log("runtime", "paused", "")
    MVP_PushRuntimeToPage("paused")
}

MVP_Resume() {
    global MVP_TriggerHotkeys, MVP_Paused
    if !MVP_Paused
        return
    MVP_Paused := false
    for hk in MVP_TriggerHotkeys {
        try Hotkey(hk, "On")
    }
    MVP_Log("runtime", "resumed", "")
    MVP_PushRuntimeToPage("resumed")
}

MVP_StartRecordingSession() {
    global MVP_RecordingMode, MVP_Count, MVP_LastTick, MVP_EnterTimer, MVP_Wv
    if MVP_RecordingMode
        return
    MVP_RecordingMode := true
    ; Kill any pending Enter timer and reset state machine
    if MVP_EnterTimer {
        SetTimer(MVP_EnterTimer, 0)
        MVP_EnterTimer := 0
    }
    MVP_Count := 0
    MVP_LastTick := 0
    ; Bind a broad set of keys that Bluetooth remotes/rings commonly send
    static RecordKeys := ["Volume_Up", "Volume_Down", "Volume_Mute",
                          "Media_Next", "Media_Prev", "Media_Play_Pause", "Media_Stop",
                          "Browser_Back", "Browser_Forward", "Browser_Refresh",
                          "Launch_App1", "Launch_App2", "Launch_Mail",
                          "RAlt", "RControl", "AppsKey",
                          "F13", "F14", "F15", "F16", "F17", "F18", "F19", "F20"]
    for hk in RecordKeys {
        try Hotkey(hk, MVP_OnRecordTrigger, "On")
    }
    MVP_Log("record", "session_start", "bound " RecordKeys.Length " keys")
    MVP_PushRuntimeToPage("recording_started")
}

MVP_StopRecordingSession() {
    global MVP_RecordingMode, MVP_TriggerHotkey
    if !MVP_RecordingMode
        return
    MVP_RecordingMode := false
    ; Unbind all recording keys
    static RecordKeys := ["Volume_Up", "Volume_Down", "Volume_Mute",
                          "Media_Next", "Media_Prev", "Media_Play_Pause", "Media_Stop",
                          "Browser_Back", "Browser_Forward", "Browser_Refresh",
                          "Launch_App1", "Launch_App2", "Launch_Mail",
                          "RAlt", "RControl", "AppsKey",
                          "F13", "F14", "F15", "F16", "F17", "F18", "F19", "F20"]
    for hk in RecordKeys {
        try Hotkey(hk, "Off")
    }
    ; Restore normal bindings via ApplyConfig's rebind logic
    MVP_RebindTrigger("", MVP_TriggerHotkey)
    MVP_Log("record", "session_stop", "")
}

MVP_OnRecordTrigger(*) {
    global MVP_Wv
    capturedKey := A_ThisHotkey
    try MVP_Wv.PostWebMessageAsJson(Jxon_Dump(Map("type", "mvp_key_captured", "key", capturedKey)))
    MVP_Log("record", "captured", "key=" capturedKey)
    MVP_StopRecordingSession()
}

MVP_PushConfigToPage() {
    global MVP_Wv, MVP_Config
    try {
        if MVP_Wv && IsObject(MVP_Config)
            MVP_Wv.PostWebMessageAsJson(Jxon_Dump(Map("type", "mvp_init", "config", MVP_Config)))
        MVP_PushRuntimeToPage("config_push")
    } catch as e {
        try MsgBox("初始化配置推送失败:`n" e.Message, "Voice Input MVP", "Iconx")
    }
}

MVP_PushRuntimeToPage(lastAction := "") {
    global MVP_Wv, MVP_Config, MVP_TriggerHotkeys
    try {
        if !MVP_Wv
            return
        key := String(MVP_Config.Has("recordKey") ? MVP_Config["recordKey"] : "")
        normalized := (key = "" ? "RAlt" : key)
        bindings := ""
        for hk in MVP_TriggerHotkeys
            bindings .= (bindings = "" ? "" : ", ") . hk
        MVP_Wv.PostWebMessageAsJson(Jxon_Dump(Map(
            "type", "mvp_runtime",
            "recordKey", key,
            "normalizedKey", normalized,
            "bindings", bindings,
            "lastAction", lastAction,
            "count", MVP_Count,
            "timerActive", MVP_EnterTimer ? true : false,
            "paused", MVP_Paused
        )))
    } catch {
    }
}

MVP_OnMessage(sender, args) {
    global MVP_ConfigFile, MVP_Config
    try {
        raw := MVP_CopyWebMessageJson(args)
        if (raw = "")
            return
        msg := Jxon_Load(raw)
        if !(msg is Map)
            return
        t := String(msg.Has("type") ? msg["type"] : "")
        if (t = "mvp_ready") {
            MVP_PushConfigToPage()
            return
        }
        if (t = "mvp_save") {
            json := String(msg.Has("json") ? msg["json"] : "")
            if (json != "") {
                try FileDelete(MVP_ConfigFile)
                FileAppend(json, MVP_ConfigFile, "UTF-8")
                try MVP_Config := MVP_NormalizeConfig(Jxon_Load(json))
                MVP_ApplyConfig(true)
                try MVP_Wv.PostWebMessageAsJson(Jxon_Dump(Map("type", "mvp_saved", "ok", true)))
                MVP_PushRuntimeToPage("saved")
                MVP_Log("runtime", "saved", MVP_DescribeRuntime())
            }
        }
        if (t = "mvp_start_recording") {
            MVP_StartRecordingSession()
        }
        if (t = "mvp_stop_recording") {
            MVP_StopRecordingSession()
        }
        if (t = "mvp_pause") {
            MVP_Pause()
            try MVP_Wv.PostWebMessageAsJson(Jxon_Dump(Map("type", "mvp_paused", "ok", true)))
        }
        if (t = "mvp_resume") {
            MVP_Resume()
            try MVP_Wv.PostWebMessageAsJson(Jxon_Dump(Map("type", "mvp_resumed", "ok", true)))
        }
        if (t = "mvp_export") {
            json := String(msg.Has("json") ? msg["json"] : "")
            if (json != "") {
                dest := FileSelect("S16", "voice_input_settings.json", "保存配置文件", "JSON (*.json)")
                if (dest != "") {
                    try {
                        FileDelete(dest)
                        FileAppend(json, dest, "UTF-8")
                        try MVP_Wv.PostWebMessageAsJson(Jxon_Dump(Map("type", "mvp_exported", "ok", true, "path", dest)))
                    } catch as fe {
                        try MVP_Wv.PostWebMessageAsJson(Jxon_Dump(Map("type", "mvp_exported", "ok", false, "error", fe.Message)))
                    }
                }
            }
        }
    } catch as e {
        MsgBox("消息处理失败:`n" e.Message, "Voice Input MVP", "Iconx")
    }
}

MVP_OnTrigger(*) {
    global MVP_Config, MVP_Count, MVP_LastTick, MVP_EnterTimer, MVP_LastTrigger, MVP_DebounceMs
    now := A_TickCount
    if (MVP_LastTrigger && (now - MVP_LastTrigger) < MVP_DebounceMs)
        return
    MVP_LastTrigger := now
    resetMs := Integer(MVP_Config.Has("intervalMs") ? MVP_Config["intervalMs"] : 2000)
    enterDelayMs := Integer(MVP_Config.Has("enterDelayMs") ? MVP_Config["enterDelayMs"] : 5000)
    autoEnterEnabled := MVP_Config.Has("autoEnterEnabled") ? !!MVP_Config["autoEnterEnabled"] : true
    delta := MVP_LastTick ? (now - MVP_LastTick) : 0
    MVP_Log("trigger", "fire", "delta=" delta " count=" MVP_Count " runtime=" MVP_DescribeRuntime())

    cancelEnabled := MVP_Config.Has("cancelEnabled") ? !!MVP_Config["cancelEnabled"] : true
    if (cancelEnabled && MVP_LastTick && delta < resetMs) {
        if MVP_EnterTimer {
            SetTimer(MVP_EnterTimer, 0)
            MVP_EnterTimer := 0
        }
        MVP_Count := 0
        MVP_LastTick := now
        Send "{Esc}"
        MVP_Log("action", "esc", "resetMs=" resetMs)
        MVP_PushRuntimeToPage("esc")
        return
    }

    MVP_SendPureRAlt()
    MVP_Count += 1
    MVP_LastTick := now
    MVP_Log("action", "ralt", "count=" MVP_Count)
    MVP_PushRuntimeToPage("ralt")

    if MVP_EnterTimer {
        SetTimer(MVP_EnterTimer, 0)
        MVP_EnterTimer := 0
    }

    if (MVP_Count = 2 && autoEnterEnabled) {
        MVP_EnterTimer := MVP_SendEnter.Bind()
        SetTimer(MVP_EnterTimer, -enterDelayMs)
        MVP_Log("timer", "enter_scheduled", "enterDelayMs=" enterDelayMs)
        MVP_PushRuntimeToPage("enter_scheduled")
        return
    }

    if (MVP_Count >= 3)
        MVP_Count := 1
}

MVP_SendPureRAlt() {
    global MVP_KeyPressDurationMs
    SendEvent("{vkA5sc138 down}")
    Sleep(MVP_KeyPressDurationMs)
    SendEvent("{vkA5sc138 up}")
}

MVP_SendEnter() {
    global MVP_EnterTimer, MVP_Count, MVP_LastTick
    MVP_EnterTimer := 0
    MVP_Count := 0
    MVP_LastTick := 0
    Send "{Enter}"
    MVP_Log("action", "enter", "")
    MVP_PushRuntimeToPage("enter")
}

MVP_DescribeRuntime() {
    global MVP_Config, MVP_TriggerHotkey, MVP_TriggerHotkeys
    key := String(MVP_Config.Has("recordKey") ? MVP_Config["recordKey"] : "")
    return "recordKey=" key
        . " trigger=" MVP_TriggerHotkey
        . " hotkeys=" MVP_DescribeHotkeys()
        . " intervalMs=" (MVP_Config.Has("intervalMs") ? MVP_Config["intervalMs"] : "")
        . " cancelEnabled=" (MVP_Config.Has("cancelEnabled") ? MVP_Config["cancelEnabled"] : "")
        . " autoEnterEnabled=" (MVP_Config.Has("autoEnterEnabled") ? MVP_Config["autoEnterEnabled"] : "")
        . " enterDelayMs=" (MVP_Config.Has("enterDelayMs") ? MVP_Config["enterDelayMs"] : "")
        . " debounceMs=" (MVP_Config.Has("debounceMs") ? MVP_Config["debounceMs"] : "")
        . " keyPressDurationMs=" (MVP_Config.Has("keyPressDurationMs") ? MVP_Config["keyPressDurationMs"] : "")
}

MVP_DescribeHotkeys() {
    global MVP_TriggerHotkeys
    out := ""
    for hk in MVP_TriggerHotkeys
        out .= (out = "" ? "" : ",") . hk
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
