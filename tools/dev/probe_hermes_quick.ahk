#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\..\..\modules\ConfigWebViewModule.ahk
fb := ConfigWebView_QuickReadHermesApiServerKey()
msg := "token=" . String(fb.Get("token", "")) . "`nsource=" . String(fb.Get("source", "")) . "`n"
FileAppend(msg, A_Temp . "\nmer_hermes_quick.txt", "UTF-8")
