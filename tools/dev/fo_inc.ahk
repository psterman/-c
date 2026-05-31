#Requires AutoHotkey v2.0
SetWorkingDir(A_ScriptDir)
FileAppend("before`n", A_ScriptDir . "\..\Cache\fo_inc.txt", "UTF-8")
#Include ..\modules\GroundingCache.ahk
FileAppend("after`n", A_ScriptDir . "\..\Cache\fo_inc.txt", "UTF-8")
ExitApp 0
