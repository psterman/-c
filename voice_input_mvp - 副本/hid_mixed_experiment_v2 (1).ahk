#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook True
#Include c:\Users\Administrator\Desktop\牛马nmer\lib\ahk\Jxon.ahk

global Hix_ConfigFile := A_ScriptDir "\牛马nmer\voice_input_mvp\voice_input_settings.json"
global Hix_DefaultConfig := Map(
    "recordKey", "AutoTrigger",
    "intervalMs", 2000,
    "enterDelayMs", 5000,
    "mappings", [
        Map("command", "voice_start", "key", "RAlt"),
        Map("command", "voice_send", "key", ""),
        Map("command", "voice_stop", "key", "")
    ]
)
global Hix_Config := Hix_LoadConfig()
global Hix_ConfigStamp := ""
global Hix_TriggerHotkey := ""
global Hix_TriggerHotkeys := []
global Hix_Count := 0
global Hix_LastTick := 0
global Hix_EnterTimer := 0

Hix_ApplyConfig(true)
SetTimer(Hix_PollConfig, 500)
return

Hix_LoadConfig() {
    global Hix_ConfigFile, Hix_DefaultConfig
    try {
        if !FileExist(Hix_ConfigFile) {
            Hix_EnsureConfigDir()
            Hix_WriteDefaultConfig()
            return Hix_CloneMap(Hix_DefaultConfig)
        }
        raw := FileRead(Hix_ConfigFile, "UTF-8")
        if (raw = "")
            return Hix_CloneMap(Hix_DefaultConfig)
        cfg := Jxon_Load(raw)
        if !(cfg is Map)
            return Hix_CloneMap(Hix_DefaultConfig)
        return Hix_MergeConfig(cfg)
    } catch {
        return Hix_CloneMap(Hix_DefaultConfig)
    }
}

Hix_EnsureConfigDir() {
    global Hix_ConfigFile
    dir := RegExReplace(Hix_ConfigFile, "\\[^\\]+$")
    if (dir != "" && !DirExist(dir))
        DirCreate(dir)
}

Hix_WriteDefaultConfig() {
    global Hix_ConfigFile, Hix_DefaultConfig
    try {
        txt := Jxon_Dump(Hix_DefaultConfig, 2)
        FileDelete(Hix_ConfigFile)
        FileAppend(txt, Hix_ConfigFile, "UTF-8")
    } catch as e {
        OutputDebug("[Hix] write default config failed: " . e.Message)
    }
}

Hix_MergeConfig(cfg) {
    global Hix_DefaultConfig
    next := Hix_CloneMap(Hix_DefaultConfig)
    if cfg.Has("recordKey") && String(cfg["recordKey"]) != ""
        next["recordKey"] := Hix_NormalizeHotkeyName(String(cfg["recordKey"]))
    if cfg.Has("intervalMs")
        next["intervalMs"] := Integer(cfg["intervalMs"])
    if cfg.Has("enterDelayMs")
        next["enterDelayMs"] := Integer(cfg["enterDelayMs"])
    if cfg.Has("mappings") && (cfg["mappings"] is Array)
        next["mappings"] := cfg["mappings"]
    return next
}

Hix_NormalizeHotkeyName(key) {
    k := Trim(String(key))
    switch k {
        case "", "`":
            return "AutoTrigger"
        case "AudioVolumeDown", "AudioVolumeUp", "AudioVolumeMute", "Volume_Down", "Volume_Up", "AutoTrigger":
            return "AutoTrigger"
        case "MediaTrackNext":
            return "Media_Next"
        case "MediaTrackPrevious":
            return "Media_Prev"
        case "MediaPlayPause":
            return "Media_Play_Pause"
        case "MediaStop":
            return "Media_Stop"
        default:
            return k
    }
}

Hix_CloneMap(obj) {
    if !(obj is Map)
        return obj
    out := Map()
    for k, v in obj
        out[k] := (v is Map) ? Hix_CloneMap(v) : ((v is Array) ? Hix_CloneArray(v) : v)
    return out
}

Hix_CloneArray(arr) {
    out := []
    for v in arr
        out.Push((v is Map) ? Hix_CloneMap(v) : ((v is Array) ? Hix_CloneArray(v) : v))
    return out
}

Hix_ApplyConfig(force := false) {
    global Hix_Config, Hix_TriggerHotkey, Hix_TriggerHotkeys, Hix_Count, Hix_LastTick, Hix_EnterTimer
    key := String(Hix_Config.Has("recordKey") ? Hix_Config["recordKey"] : "AutoTrigger")
    if (key = "" || key = "`")
        key := "AutoTrigger"
    if force || (key != Hix_TriggerHotkey) {
        Hix_RebindTrigger(Hix_TriggerHotkey, key)
        Hix_TriggerHotkey := key
    }
    Hix_Count := 0
    Hix_LastTick := 0
    if Hix_EnterTimer {
        SetTimer(Hix_EnterTimer, 0)
        Hix_EnterTimer := 0
    }
}

Hix_RebindTrigger(oldKey, newKey) {
    global Hix_TriggerHotkeys
    for hk in Hix_TriggerHotkeys {
        try Hotkey(hk, "Off")
    }
    Hix_TriggerHotkeys := []
    if (newKey != "") {
        if (newKey = "`")
            newKey := "AutoTrigger"
        if (newKey = "AutoTrigger") {
            Hotkey("Volume_Up", Hix_OnTrigger, "On")
            Hotkey("Volume_Down", Hix_OnTrigger, "On")
            Hix_TriggerHotkeys := ["Volume_Up", "Volume_Down"]
        } else {
            Hotkey(newKey, Hix_OnTrigger, "On")
            Hix_TriggerHotkeys := [newKey]
        }
    }
}

Hix_PollConfig() {
    global Hix_ConfigFile, Hix_ConfigStamp, Hix_Config
    try {
        if !FileExist(Hix_ConfigFile) {
            Hix_EnsureConfigDir()
            Hix_WriteDefaultConfig()
            Hix_Config := Hix_CloneMap(Hix_DefaultConfig)
            Hix_ApplyConfig(true)
            return
        }
        stamp := FileGetTime(Hix_ConfigFile, "M")
        if (stamp = "")
            return
        if (stamp != Hix_ConfigStamp) {
            Hix_ConfigStamp := stamp
            Hix_Config := Hix_LoadConfig()
            Hix_ApplyConfig(true)
        }
    } catch as e {
        OutputDebug("[Hix] poll failed: " . e.Message)
    }
}

Hix_OnTrigger(*) {
    global Hix_Config, Hix_Count, Hix_LastTick, Hix_EnterTimer
    resetMs := Integer(Hix_Config.Has("intervalMs") ? Hix_Config["intervalMs"] : 2000)
    enterDelayMs := Integer(Hix_Config.Has("enterDelayMs") ? Hix_Config["enterDelayMs"] : 5000)
    now := A_TickCount
    delta := Hix_LastTick ? (now - Hix_LastTick) : 0

    if (Hix_LastTick && delta < resetMs) {
        if Hix_EnterTimer {
            SetTimer(Hix_EnterTimer, 0)
            Hix_EnterTimer := 0
        }
        Hix_Count := 0
        Hix_LastTick := now
        Send "{Esc}"
        return
    }

    Hix_SendPureRAlt()
    Hix_Count += 1
    Hix_LastTick := now

    if Hix_EnterTimer {
        SetTimer(Hix_EnterTimer, 0)
        Hix_EnterTimer := 0
    }

    if (Hix_Count = 2) {
        Hix_EnterTimer := Hix_SendEnter.Bind()
        SetTimer(Hix_EnterTimer, -enterDelayMs)
        return
    }

    if (Hix_Count >= 3)
        Hix_Count := 1
}

Hix_SendPureRAlt() {
    SendEvent("{vkA5sc138 down}")
    Sleep(35)
    SendEvent("{vkA5sc138 up}")
}

Hix_SendEnter() {
    global Hix_EnterTimer
    Hix_EnterTimer := 0
    Send "{Enter}"
}
