#Requires AutoHotkey v2.0
SetWorkingDir(A_ScriptDir)
#Include ..\modules\GroundingCache.ahk

out := GroundingCache_GetProjectRoot() . "\Cache\migrate_main.txt"
dbg := A_Temp . "\niuma_grounding_l2_migrate_dbg.txt"
try FileDelete(dbg)
FileAppend("out=" . out . "`n", dbg, "UTF-8")
try FileDelete(out)
FileAppend("0`n", out, "UTF-8")

mainPath := GroundingCache_GetDbPath()
db := SQLiteDB()
if !db.OpenDB(mainPath, "W", true) {
  FileAppend("open fail " . db.ErrorMsg . "`n", out, "UTF-8")
  ExitApp 1
}

dllPath := GroundingCache_GetVecDllPath()
if !FileExist(dllPath) {
  FileAppend("no vec0`n", out, "UTF-8")
  ExitApp 2
}
if !GroundingCache_EnableLoadExtension(db) {
  FileAppend("enable_load_extension fail`n", out, "UTF-8")
  ExitApp 3
}

sqlPath := GroundingCache_EscapeSqlStr(StrReplace(dllPath, "\", "/"))
if !db.Exec("SELECT load_extension('" . sqlPath . "');") {
  FileAppend("load_extension fail " . db.ErrorMsg . "`n", out, "UTF-8")
  ExitApp 4
}

ok := db.Exec("DROP TABLE IF EXISTS vec_l2_smoke;")
FileAppend("drop=" . ok . " err=" . db.ErrorMsg . "`n", out, "UTF-8")
ExitApp 0
