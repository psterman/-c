#Requires AutoHotkey v2.0
#Warn All, Off
#SingleInstance Off

#Include _ProbeRoot.ahk
global MainScriptDir := Probe_ResolveProjectRoot()

#Include ..\..\..\modules\FuncExists.ahk
#Include ..\..\..\modules\ToolsPaths.ahk

caller := "e2e_start_probe"
if (A_Args.Length >= 1 && Trim(String(A_Args[1])) != "")
    caller := Trim(String(A_Args[1]))
st := Nmer_StartSearchCenterCoreStatus(false, caller)
status := (st is Map && st.Has("status")) ? String(st["status"]) : "failed"
if (status = "launch_debounced" || status = "failed")
    ExitApp 1
ExitApp 0
