#Requires AutoHotkey v2.0
SplitPath(A_LineFile, , &d)
FileAppend("ok`r`n" . d, A_Temp "\\ahk_probe.txt", "UTF-8")
