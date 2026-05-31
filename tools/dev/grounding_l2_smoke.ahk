#Requires AutoHotkey v2.0
; sqlite-vec L2 旁路烟测：load_extension + vec_version + vec0 向量读写
; 用法：双击运行，或 AutoHotkey64.exe tools\grounding_l2_smoke.ahk

SetWorkingDir(A_ScriptDir)
; Class_SQLiteDB 默认从 A_ScriptDir 找 sqlite3.dll；烟测在 tools/，用相对路径 ini（避免中文绝对路径导致 IniRead 失败）
if !FileExist(A_ScriptDir . "\sqlite3.dll") && FileExist(A_ScriptDir . "\..\sqlite3.dll") {
  iniPath := A_ScriptDir . "\SQLiteDB.ini"
  try FileDelete(iniPath)
  FileAppend("[Main]`nDllPath=..\sqlite3.dll`n", iniPath, "UTF-8")
}

#Include ..\modules\GroundingCache.ahk

GroundingCache_LogL2("=== L2 smoke start ===")

if !GroundingCache_Init() {
  MsgBox("GroundingCache_Init 失败，无法打开 Data\GroundingCache.db", "L2 烟测", "IconX")
  ExitApp 1
}

res := GroundingCache_RunL2SmokeTest()

if res["ok"] {
  msg := "L2 烟测成功`n`n"
    . "vec_version: " . res["version"] . "`n"
    . "inserted: " . res["inserted"] . "`n"
    . "top rowid: " . res["topRowid"] . "`n"
    . "distance: " . res["distance"] . "`n`n"
    . "日志: Cache\grounding_l2.log"
  MsgBox(msg, "L2 烟测", "Iconi")
  ExitApp 0
}

err := String(res["error"] || "unknown")
MsgBox(
  "L2 烟测失败`n`n"
  . err . "`n`n"
  . "请确认 lib\vec0.dll 存在且 sqlite3.dll 支持 load_extension。`n"
  . "详情见 Cache\grounding_l2.log",
  "L2 烟测",
  "IconX"
)
ExitApp 1
