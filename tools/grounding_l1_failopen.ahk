#Requires AutoHotkey v2.0
; 验收：缺 vec0.dll 时 L1 仍可用
SetWorkingDir(A_ScriptDir)
if !FileExist(A_ScriptDir . "\sqlite3.dll") && FileExist(A_ScriptDir . "\..\sqlite3.dll") {
  iniPath := A_ScriptDir . "\SQLiteDB.ini"
  try FileDelete(iniPath)
  FileAppend("[Main]`nDllPath=..\sqlite3.dll`n", iniPath, "UTF-8")
}
#Include ..\modules\GroundingCache.ahk

out := GroundingCache_GetProjectRoot() . "\Cache\grounding_l1_failopen.txt"
dbg := A_Temp . "\niuma_grounding_l1_failopen_dbg.txt"
try FileDelete(dbg)
FileAppend("out=" . out . "`n", dbg, "UTF-8")
try FileDelete(out)

vecPath := GroundingCache_GetVecDllPath()
bakPath := vecPath . ".bak_failopen"
hadVec := FileExist(vecPath)
if hadVec
  try FileMove(vecPath, bakPath, 1)

pass := false
try {
  okInit := GroundingCache_Init()
  sel := ""
  tt := ""
  cnt := 0
  okGet := false
  if okInit
    okGet := GroundingCache_Get("www.baidu.com", "baidu_search_action", "*", "browser_input", "search_input", &sel, &tt, &cnt)
  l2 := GroundingCache_RunL2SmokeTest()
  txt := "init=" . (okInit ? "1" : "0") . "`nget=" . (okGet ? "1" : "0") . "`nsel=" . sel . "`nl2ok=" . (l2["ok"] ? "1" : "0") . "`nl2err=" . l2["error"] . "`n"
  try FileAppend(txt, out, "UTF-8")
  catch as e
    FileAppend("append fail " . e.Message . "`n", dbg, "UTF-8")
  FileAppend("exists_after=" . (FileExist(out) ? "1" : "0") . "`n", dbg, "UTF-8")
  pass := okInit && okGet && !l2["ok"]
} finally {
  if hadVec && FileExist(bakPath)
    try FileMove(bakPath, vecPath, 1)
}
ExitApp pass ? 0 : 1
