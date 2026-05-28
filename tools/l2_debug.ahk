#Requires AutoHotkey v2.0
SetWorkingDir(A_ScriptDir)
out := A_ScriptDir . "\..\Cache\l2_debug.txt"
try FileDelete(out)

log(s) {
  global out
  FileAppend(s . "`n", out, "UTF-8")
}

log("scriptDir=" . A_ScriptDir)

if !FileExist(A_ScriptDir . "\sqlite3.dll") && FileExist(A_ScriptDir . "\..\sqlite3.dll") {
  iniPath := A_ScriptDir . "\SQLiteDB.ini"
  FileAppend("[Main]`nDllPath=..\sqlite3.dll`n", iniPath, "UTF-8")
}

#Include ..\modules\GroundingCache.ahk
log("included GroundingCache")

if !GroundingCache_Init() {
  log("Init failed")
  ExitApp 1
}
log("Init ok db=" . GroundingCache_GetDbPath())

ver := ""
ok := GroundingCache_TryEnableL2(&ver)
log("TryEnableL2 ok=" . ok . " ver=" . ver)

res := GroundingCache_RunL2SmokeTest()
log("smoke ok=" . res["ok"] . " rowid=" . res["topRowid"] . " dist=" . res["distance"] . " err=" . res["error"])

; fail-open：临时移走 vec0.dll，验证 L1 仍可打开与读取 seed
vecPath := GroundingCache_GetVecDllPath()
bakPath := vecPath . ".bak_failopen"
hadVec := FileExist(vecPath)
if hadVec
  try FileMove(vecPath, bakPath, 1)

sel := ""
tt := ""
cnt := 0
okGet := false
try okGet := GroundingCache_Get("www.baidu.com", "baidu_search_action", "*", "browser_input", "search_input", &sel, &tt, &cnt)
catch as e
  log("L1 get exception=" . e.Message)

res2 := GroundingCache_RunL2SmokeTest()
log("failopen l1_get=" . (okGet ? "1" : "0") . " sel=" . sel)
log("failopen l2_ok=" . (res2["ok"] ? "1" : "0") . " l2_err=" . res2["error"])

if hadVec && FileExist(bakPath)
  try FileMove(bakPath, vecPath, 1)

ExitApp (ok && (res["ok"] ?? false) && okGet && !res2["ok"]) ? 0 : 1

