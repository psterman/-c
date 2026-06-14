#Requires AutoHotkey v2.0
#Warn All, Off
#SingleInstance Off

#Include _ProbeRoot.ahk
global MainScriptDir := Probe_ResolveProjectRoot()

#Include ..\..\..\modules\FuncExists.ahk
#Include ..\..\..\modules\ToolsPaths.ahk

reason := "e2e_shutdown_test"
if (A_Args.Length >= 1 && Trim(String(A_Args[1])) != "")
    reason := Trim(String(A_Args[1]))
SearchCore_Shutdown(reason)
ExitApp 0
