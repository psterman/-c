#Requires AutoHotkey v2.0
SetWorkingDir(A_ScriptDir)
if !FileExist(A_ScriptDir . "\sqlite3.dll") && FileExist(A_ScriptDir . "\..\sqlite3.dll") {
  iniPath := A_ScriptDir . "\SQLiteDB.ini"
  try FileDelete(iniPath)
  FileAppend("[Main]`nDllPath=..\sqlite3.dll`n", iniPath, "UTF-8")
}
#Include ..\modules\GroundingCache.ahk
out := A_ScriptDir . "\..\Cache\fo_fail.txt"
vecPath := GroundingCache_GetVecDllPath()
bakPath := vecPath . ".bak_failopen"
hadVec := FileExist(vecPath)
if hadVec
  FileMove(vecPath, bakPath, 1)
okInit := GroundingCache_Init()
FileAppend("init=" . okInit . "`n", out, "UTF-8")
if hadVec && FileExist(bakPath)
  FileMove(bakPath, vecPath, 1)
ExitApp 0
