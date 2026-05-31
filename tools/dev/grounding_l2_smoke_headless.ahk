#Requires AutoHotkey v2.0
SetWorkingDir(A_ScriptDir)
if !FileExist(A_ScriptDir . "\sqlite3.dll") && FileExist(A_ScriptDir . "\..\sqlite3.dll") {
  iniPath := A_ScriptDir . "\SQLiteDB.ini"
  try FileDelete(iniPath)
  FileAppend("[Main]`nDllPath=..\sqlite3.dll`n", iniPath, "UTF-8")
}
#Include ..\modules\GroundingCache.ahk

out := GroundingCache_GetProjectRoot() . "\Cache\grounding_l2_headless.txt"
dbg := A_Temp . "\niuma_grounding_l2_headless_dbg.txt"
try FileDelete(dbg)
FileAppend("out=" . out . "`n", dbg, "UTF-8")
try FileDelete(out)

if !GroundingCache_Init() {
  try FileAppend("init=fail`n", out, "UTF-8")
  catch as e
    FileAppend("append fail init=" . e.Message . "`n", dbg, "UTF-8")
  ExitApp 1
}

res := GroundingCache_RunL2SmokeTest()
txt := "init=ok`ndb=" . GroundingCache_GetDbPath() . "`nvecDll=" . GroundingCache_GetVecDllPath() . "`nok=" . (res["ok"] ? "1" : "0") . "`nversion=" . res["version"] . "`ntopRowid=" . res["topRowid"] . "`ndistance=" . res["distance"] . "`nerror=" . res["error"] . "`n"
try FileAppend(txt, out, "UTF-8")
catch as e
  FileAppend("append fail ok=" . e.Message . "`n", dbg, "UTF-8")
FileAppend("exists_after=" . (FileExist(out) ? "1" : "0") . "`n", dbg, "UTF-8")
ExitApp res["ok"] ? 0 : 1
