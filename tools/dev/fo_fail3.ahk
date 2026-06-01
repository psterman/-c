#Requires AutoHotkey v2.0
SetWorkingDir(A_ScriptDir)
if !FileExist(A_ScriptDir . "\sqlite3.dll") && FileExist(A_ScriptDir . "\..\sqlite3.dll") {
  iniPath := A_ScriptDir . "\SQLiteDB.ini"
  try FileDelete(iniPath)
  FileAppend("[Main]`nDllPath=..\sqlite3.dll`n", iniPath, "UTF-8")
}
#Include ..\lib\ahk\Class_SQLiteDB.ahk
out := A_ScriptDir . "\..\Cache\fo_fail3.txt"
dbPath := A_ScriptDir . "\..\Data\GroundingCache.db"
vecPath := A_ScriptDir . "\..\lib\runtime\vec0.dll"
if !FileExist(vecPath)
    vecPath := A_ScriptDir . "\..\lib\vec0.dll"
bakPath := vecPath . ".bak_failopen"
if FileExist(vecPath)
  FileMove(vecPath, bakPath, 1)
FileAppend("moved`n", out, "UTF-8")
db := SQLiteDB()
t0 := A_TickCount
ok := db.OpenDB(dbPath, "W", true)
dt := A_TickCount - t0
FileAppend("open=" . ok . " ms=" . dt . " err=" . db.ErrorMsg . "`n", out, "UTF-8")
if FileExist(bakPath)
  FileMove(bakPath, vecPath, 1)
ExitApp 0
