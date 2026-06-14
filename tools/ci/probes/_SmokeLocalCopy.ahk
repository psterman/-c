#Requires AutoHotkey v2.0
#SingleInstance Off
FileAppend('before
', A_Temp . '\sc_probe_smoke5.txt', 'UTF-8')
#Include _ToolsPathsCopy.ahk
FileAppend('after
', A_Temp . '\sc_probe_smoke5.txt', 'UTF-8')
ExitApp 0
