#Requires AutoHotkey v2.0
#SingleInstance Force

#Include c:\Users\Administrator\Desktop\牛马nmer\lib\ahk\WebView2.ahk
#Include c:\Users\Administrator\Desktop\牛马nmer\lib\ahk\Jxon.ahk

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
global MVP_EnterTimer := 0
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
        "enterDelayMs", 5000,
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
        k := String(cfg["recordKey"])
        if (k = "AutoTrigger")
            cfg["recordKey"] := "RAlt"
        else if (k = "" || k = "``")
            cfg["recordKey"] := "RAlt"
    }
    if !cfg.Has("intervalMs")
        cfg["intervalMs"] := 2000
    if !cfg.Has("enterDelayMs")
        cfg["enterDelayMs"] := 5000
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
    global MVP_Config, MVP_TriggerHotkey, MVP_TriggerHotkeys, MVP_Count, MVP_LastTick, MVP_EnterTimer, MVP_RuntimeEnabled
    if !(MVP_Config is Map)
        MVP_Config := MVP_DefaultConfig()
        key := String(MVP_Config.Has("recordKey") ? MVP_Config["recordKey"] : "RAlt")
    if (key = "" || key = "``")
        key := "RAlt"
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
    global MVP_TriggerHotkeys
    for hk in MVP_TriggerHotkeys {
        try Hotkey(hk, "Off")
    }
    MVP_TriggerHotkeys := []
    if (newKey != "") {
        Hotkey(newKey, MVP_OnTrigger, "On")
        MVP_TriggerHotkeys := [newKey]
    }
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
            "lastAction", lastAction
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
    } catch as e {
        MsgBox("消息处理失败:`n" e.Message, "Voice Input MVP", "Iconx")
    }
}

MVP_OnTrigger(*) {
    global MVP_Config, MVP_Count, MVP_LastTick, MVP_EnterTimer
    resetMs := Integer(MVP_Config.Has("intervalMs") ? MVP_Config["intervalMs"] : 2000)
    enterDelayMs := Integer(MVP_Config.Has("enterDelayMs") ? MVP_Config["enterDelayMs"] : 5000)
    now := A_TickCount
    delta := MVP_LastTick ? (now - MVP_LastTick) : 0
    MVP_Log("trigger", "fire", "delta=" delta " count=" MVP_Count " runtime=" MVP_DescribeRuntime())

    if (MVP_LastTick && delta < resetMs) {
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

    if (MVP_Count = 2) {
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
    SendEvent("{vkA5sc138 down}")
    Sleep(35)
    SendEvent("{vkA5sc138 up}")
}

MVP_SendEnter() {
    global MVP_EnterTimer
    MVP_EnterTimer := 0
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
        . " enterDelayMs=" (MVP_Config.Has("enterDelayMs") ? MVP_Config["enterDelayMs"] : "")
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

NmerCatch(scope, err, detail := "") {
}

NMER_Log(scope, event, detail := "") {
}
