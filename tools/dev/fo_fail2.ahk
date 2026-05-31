#Requires AutoHotkey v2.0
SetWorkingDir(A_ScriptDir)
if !FileExist(A_ScriptDir . "\sqlite3.dll") && FileExist(A_ScriptDir . "\..\sqlite3.dll") {
  iniPath := A_ScriptDir . "\SQLiteDB.ini"
  try FileDelete(iniPath)
  FileAppend("[Main]`nDllPath=..\sqlite3.dll`n", iniPath, "UTF-8")
}
#Include ..\modules\GroundingCache.ahk
out := A_ScriptDir . "\..\Cache\fo_fail2.txt"
FileAppend("a`n", out, "UTF-8")
vecPath := GroundingCache_GetVecDllPath()
bakPath := vecPath . ".bak_failopen"
if FileExist(vecPath)
  FileMove(vecPath, bakPath, 1)
FileAppend("b`n", out, "UTF-8")
okInit := GroundingCache_Init()
FileAppend("c init=" . okInit . "`n", out, "UTF-8")
if FileExist(bakPath)
  FileMove(bakPath, vecPath, 1)
FileAppend("d`n", out, "UTF-8")
ExitApp 0
