#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\..\..\lib\ahk\Jxon.ahk
#Include %A_ScriptDir%\..\..\modules\LlmApiPing.ahk
#Include %A_ScriptDir%\..\..\modules\UserStudio.ahk

out := A_Temp . "\nmer_hermes_probe_result.txt"
msg := "LOCALAPPDATA=" . EnvGet("LOCALAPPDATA") . "`n"
msg .= "UserStudio_LocalAppDataDir=" . UserStudio_LocalAppDataDir() . "`n"
try {
    fb := UserStudio_QuickReadHermesApiServerKey()
    msg .= "token=" . String(fb.Get("token", "")) . "`n"
    msg .= "source=" . String(fb.Get("source", "")) . "`n"
} catch as e {
    msg .= "QuickRead ERR=" . e.Message . "`n"
}
cfg := UserStudio_ReadHermesApiConfig()
msg .= "cfgKey=" . String(cfg.Get("key", "")) . "`n"
FileAppend(msg, out, "UTF-8")
