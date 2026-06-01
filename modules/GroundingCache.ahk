; ======================================================================================================================
; GroundingCache.ahk — 网页 Grounding 标号/selector 的 L1 缓存（SQLite）
; ======================================================================================================================

#Requires AutoHotkey v2.0

#Include ..\lib\ahk\Class_SQLiteDB.ahk
#Include LocalPaths.ahk

global g_GroundingCacheDB := 0
global g_GroundingCachePath := ""
global g_GroundingCacheL2DB := 0
global g_GroundingCacheL2Ready := false
global g_GroundingCacheL2Version := ""

GroundingCache_EscapeSqlStr(s) {
  s := String(s || "")
  s := StrReplace(s, "'", "''")
  return s
}

GroundingCache_GetProjectRoot() {
  ; GroundingCache.ahk 固定在 modules/ 下，根目录就是其父目录
  root := RegExReplace(A_LineFile, "\\modules\\[^\\]+$", "")
  if (root = "")
    root := RegExReplace(A_LineFile, "\\[^\\]+$", "") . "\.."
  return root
}

GroundingCache_GetDbPath() {
  global g_GroundingCachePath
  p := Trim(String(g_GroundingCachePath || ""))
  if p != ""
    return p
  return Nmer_GroundingCacheDbPath()
}

GroundingCache_GetL2DbPath() {
  return Nmer_GroundingCacheVecDbPath()
}

GroundingCache_OpenL2Db() {
  global g_GroundingCacheL2DB
  if IsObject(g_GroundingCacheL2DB)
    return true
  dbPath := GroundingCache_GetL2DbPath()
  try {
    dir := RegExReplace(dbPath, "\\[^\\]+$", "")
    if !DirExist(dir)
      DirCreate(dir)
  } catch {
  }
  db := SQLiteDB()
  if !db.OpenDB(dbPath, "W", true)
    return false
  db.SetTimeout(1500)
  g_GroundingCacheL2DB := db
  return true
}

GroundingCache_DropLegacyVecOnMain() {
  global g_GroundingCacheDB
  if !IsObject(g_GroundingCacheDB)
    return
  try g_GroundingCacheDB.Exec("DROP TABLE IF EXISTS vec_l2_smoke;")
}

GroundingCache_GetVecDllPath() {
  root := GroundingCache_GetProjectRoot()
    for , rel in ["\lib\runtime\vec0.dll", "\lib\vec0.dll", "\lib\sqlite-vec.dll"] {
    p := root . rel
    if FileExist(p)
      return p
  }
  return Nmer_LibRuntimePath("vec0.dll")
}

GroundingCache_LogL2(msg) {
  try {
    logPath := GroundingCache_GetProjectRoot() . "\Cache\grounding_l2.log"
    dir := RegExReplace(logPath, "\\[^\\]+$", "")
    if !DirExist(dir)
      DirCreate(dir)
    FileAppend("[" . A_Now . "] " . String(msg) . "`r`n", logPath, "UTF-8")
  } catch {
  }
}

GroundingCache_EnableLoadExtension(db) {
  if !IsObject(db)
    return false
  if !db.Exec("PRAGMA enable_load_extension = 1;") {
    GroundingCache_LogL2("enable_load_extension PRAGMA 失败: " . db.ErrorMsg)
    return false
  }
  hDb := 0
  try hDb := db._Handle
  catch {
    hDb := 0
  }
  if !hDb
    return true
  rc := DllCall("sqlite3.dll\sqlite3_enable_load_extension", "Ptr", hDb, "Int", 1, "Cdecl Int")
  if (rc != 0) {
    GroundingCache_LogL2("sqlite3_enable_load_extension 失败 rc=" . rc . " err=" . db.ErrorMsg)
    return false
  }
  return true
}

GroundingCache_Init() {
  global g_GroundingCacheDB
  if IsObject(g_GroundingCacheDB)
    return true

  dbPath := GroundingCache_GetDbPath()
  try {
    Dir := RegExReplace(dbPath, "\\[^\\]+$", "")
    if !DirExist(Dir)
      DirCreate(Dir)
  } catch {
  }

  db := SQLiteDB()
  if !db.OpenDB(dbPath, "W", true) {
    return false
  }
  db.SetTimeout(1500)
  g_GroundingCacheDB := db
  GroundingCache_EnsureSchema()
  return true
}

GroundingCache_EnsureSchema() {
  global g_GroundingCacheDB
  if !IsObject(g_GroundingCacheDB)
    return false
  sql := []
  sql.Push("PRAGMA journal_mode = WAL;")
  sql.Push(
    "CREATE TABLE IF NOT EXISTS grounding_cache ("
      . "cache_key TEXT PRIMARY KEY, "
      . "host TEXT NOT NULL, "
      . "intent_template TEXT NOT NULL, "
      . "page_fingerprint TEXT NOT NULL, "
      . "tool TEXT NOT NULL, "
      . "target_roleHint TEXT NOT NULL, "
      . "selector TEXT NOT NULL, "
      . "textTemplate TEXT, "
      . "successCount INTEGER DEFAULT 0, "
      . "lastOkAt TEXT DEFAULT (datetime('now','localtime'))"
      . ");"
  )
  sql.Push("CREATE INDEX IF NOT EXISTS idx_grounding_cache_lookup ON grounding_cache(host, intent_template, page_fingerprint, tool, target_roleHint);")
  for , st in sql {
    try g_GroundingCacheDB.Exec(st)
  }
  GroundingCache_SeedDefaults()
  return true
}

GroundingCache_SeedDefaults() {
  global g_GroundingCacheDB
  if !IsObject(g_GroundingCacheDB)
    return false
  ; page_fingerprint='*' 作为站点首页的通配种子，供首次命中与后续自愈回写
  seeds := []
  seeds.Push(Map("host","www.baidu.com","intent","baidu_search_action","fp","*","tool","browser_input","role","search_input","selector","textarea[name='wd']","tt","{query}"))
  seeds.Push(Map("host","www.baidu.com","intent","baidu_search_action","fp","*","tool","browser_click","role","search_submit","selector","input[type='submit']","tt","百度一下"))
  seeds.Push(Map("host","www.google.com","intent","google_search_action","fp","*","tool","browser_input","role","search_input","selector","textarea[name='q']","tt","{query}"))
  seeds.Push(Map("host","www.google.com","intent","google_search_action","fp","*","tool","browser_click","role","search_submit","selector","input[type='submit']","tt","google search"))
  for , sd in seeds {
    GroundingCache_Set(sd["host"], sd["intent"], sd["fp"], sd["tool"], sd["role"], sd["selector"], sd["tt"], 0)
  }
  return true
}

GroundingCache_MakeCacheKey(host, intentTemplate, pageFingerprint, tool, targetRoleHint) {
  host := String(host || "")
  intentTemplate := String(intentTemplate || "")
  pageFingerprint := String(pageFingerprint || "")
  tool := String(tool || "")
  targetRoleHint := String(targetRoleHint || "")
  return host . "|" . intentTemplate . "|" . pageFingerprint . "|" . tool . "|" . targetRoleHint
}

GroundingCache_Get(host, intentTemplate, pageFingerprint, tool, targetRoleHint, &outSel, &outTextTemplate, &outSuccessCount) {
  global g_GroundingCacheDB
  if !IsObject(g_GroundingCacheDB)
    return false
  outSel := ""
  outTextTemplate := ""
  outSuccessCount := 0

  sql := "SELECT selector, textTemplate, successCount FROM grounding_cache "
    . "WHERE host='" . GroundingCache_EscapeSqlStr(host) . "' "
    . "AND intent_template='" . GroundingCache_EscapeSqlStr(intentTemplate) . "' "
    . "AND page_fingerprint IN ('" . GroundingCache_EscapeSqlStr(pageFingerprint) . "','*') "
    . "AND tool='" . GroundingCache_EscapeSqlStr(tool) . "' "
    . "AND target_roleHint='" . GroundingCache_EscapeSqlStr(targetRoleHint) . "' "
    . "ORDER BY CASE WHEN page_fingerprint='" . GroundingCache_EscapeSqlStr(pageFingerprint) . "' THEN 0 ELSE 1 END, successCount DESC, lastOkAt DESC LIMIT 1;"

  ok := g_GroundingCacheDB.GetTable(sql, &tb, 1)
  if !ok
    return false
  if !(tb is Object) || tb.RowCount < 1
    return false
  tb.GetRow(1, &row)
  outSel := String(row[1] || "")
  outTextTemplate := String(row[2] || "")
  outSuccessCount := Integer(row[3] || 0)
  return true
}

GroundingCache_Set(host, intentTemplate, pageFingerprint, tool, targetRoleHint, selector, textTemplate, inc := 1) {
  global g_GroundingCacheDB
  if !IsObject(g_GroundingCacheDB)
    return false
  cacheKey := GroundingCache_MakeCacheKey(host, intentTemplate, pageFingerprint, tool, targetRoleHint)
  selector := String(selector || "")
  textTemplate := String(textTemplate || "")

  selEsc := GroundingCache_EscapeSqlStr(selector)
  ttEsc := GroundingCache_EscapeSqlStr(textTemplate)
  ckEsc := GroundingCache_EscapeSqlStr(cacheKey)

  ; 先尝试 UPDATE（若存在则更新并自增）
  sqlUpd := "UPDATE grounding_cache SET "
    . "selector='" . selEsc . "', "
    . "textTemplate='" . ttEsc . "', "
    . "successCount=successCount+" . Integer(inc) . ", "
    . "lastOkAt=datetime('now','localtime') "
    . "WHERE cache_key='" . ckEsc . "';"
  okUpd := g_GroundingCacheDB.Exec(sqlUpd)
  if okUpd {
    try changes := g_GroundingCacheDB.Changes
    catch {
      changes := 0
    }
    if (Integer(changes) > 0)
      return true
  }

  ; 不存在则 INSERT
  sqlIns := "INSERT OR IGNORE INTO grounding_cache "
    . "(cache_key, host, intent_template, page_fingerprint, tool, target_roleHint, selector, textTemplate, successCount, lastOkAt) "
    . "VALUES ('" . ckEsc . "', "
    . "'" . GroundingCache_EscapeSqlStr(host) . "', "
    . "'" . GroundingCache_EscapeSqlStr(intentTemplate) . "', "
    . "'" . GroundingCache_EscapeSqlStr(pageFingerprint) . "', "
    . "'" . GroundingCache_EscapeSqlStr(tool) . "', "
    . "'" . GroundingCache_EscapeSqlStr(targetRoleHint) . "', "
    . "'" . selEsc . "', "
    . "'" . ttEsc . "', "
    . Integer(inc) . ", "
    . "datetime('now','localtime')"
    . ");"
  return g_GroundingCacheDB.Exec(sqlIns)
}

; ======================================================================================================================
; L2 旁路：sqlite-vec（显式启用，失败不影响 L1）
; ======================================================================================================================

GroundingCache_TryEnableL2(&outVersion := "") {
  global g_GroundingCacheDB, g_GroundingCacheL2Ready, g_GroundingCacheL2Version
  outVersion := ""
  if g_GroundingCacheL2Ready {
    outVersion := g_GroundingCacheL2Version
    return true
  }
  if !GroundingCache_Init() {
    GroundingCache_LogL2("L2 失败：GroundingCache_Init 未就绪")
    return false
  }

  dllPath := GroundingCache_GetVecDllPath()
  if !FileExist(dllPath) {
    GroundingCache_LogL2("L2 跳过：未找到 vec0.dll -> " . dllPath)
    return false
  }

  db := g_GroundingCacheDB
  if !GroundingCache_EnableLoadExtension(db) {
    GroundingCache_LogL2("L2 失败：无法启用 load_extension")
    return false
  }

  sqlPath := GroundingCache_EscapeSqlStr(StrReplace(dllPath, "\", "/"))
  if !db.Exec("SELECT load_extension('" . sqlPath . "');") {
    GroundingCache_LogL2("L2 失败：load_extension -> " . db.ErrorMsg)
    return false
  }

  tb := ""
  if !db.GetTable("SELECT vec_version();", &tb, 1) || !(tb is Object) || tb.RowCount < 1 {
    GroundingCache_LogL2("L2 失败：vec_version 查询 -> " . db.ErrorMsg)
    return false
  }
  row := ""
  tb.GetRow(1, &row)
  outVersion := String(row[1] || "")
  if (outVersion = "") {
    GroundingCache_LogL2("L2 失败：vec_version 为空")
    return false
  }

  g_GroundingCacheL2Version := outVersion
  g_GroundingCacheL2Ready := true
  GroundingCache_LogL2("L2 向量引擎加载成功，版本: " . outVersion)
  if GroundingCache_Init()
    GroundingCache_DropLegacyVecOnMain()
  return true
}

GroundingCache_EnsureL2SmokeSchema() {
  global g_GroundingCacheDB
  if !IsObject(g_GroundingCacheDB)
    return false
  sql := "CREATE VIRTUAL TABLE IF NOT EXISTS vec_l2_smoke USING vec0("
    . "sample_id INTEGER PRIMARY KEY, "
    . "embedding float[8]"
    . ");"
  return g_GroundingCacheDB.Exec(sql)
}

GroundingCache_RunL2SmokeTest() {
  res := Map(
    "ok", false,
    "version", "",
    "inserted", 0,
    "topRowid", 0,
    "distance", "",
    "error", ""
  )

  ver := ""
  if !GroundingCache_TryEnableL2(&ver) {
    res["error"] := "L2 enable failed (see Cache/grounding_l2.log)"
    return res
  }
  res["version"] := ver

  global g_GroundingCacheDB
  db := g_GroundingCacheDB
  if !GroundingCache_EnsureL2SmokeSchema() {
    res["error"] := "create vec_l2_smoke failed: " . db.ErrorMsg
    GroundingCache_LogL2(res["error"])
    return res
  }

  db.Exec("DELETE FROM vec_l2_smoke;")

  v1 := '[-0.200, 0.250, 0.341, -0.211, 0.645, 0.935, -0.316, -0.924]'
  v2 := '[0.443, -0.501, 0.355, -0.771, 0.707, -0.708, -0.185, 0.362]'
  q := '[0.890, 0.544, 0.825, 0.961, 0.358, 0.0196, 0.521, 0.175]'

  if !db.Exec("INSERT INTO vec_l2_smoke(sample_id, embedding) VALUES (1, '" . v1 . "'), (2, '" . v2 . "');") {
    res["error"] := "insert failed: " . db.ErrorMsg
    GroundingCache_LogL2(res["error"])
    return res
  }
  res["inserted"] := 2

  sql := "SELECT sample_id, distance FROM vec_l2_smoke WHERE embedding MATCH '" . q . "' ORDER BY distance LIMIT 1;"
  tb := ""
  if !db.GetTable(sql, &tb, 1) || !(tb is Object) || tb.RowCount < 1 {
    res["error"] := "knn query failed: " . db.ErrorMsg
    GroundingCache_LogL2(res["error"])
    return res
  }

  row := ""
  tb.GetRow(1, &row)
  res["topRowid"] := Integer(row[1] || 0)
  res["distance"] := String(row[2] || "")
  if (res["topRowid"] < 1 || res["distance"] = "") {
    res["error"] := "knn returned empty/invalid row"
    GroundingCache_LogL2(res["error"])
    return res
  }

  res["ok"] := true
  GroundingCache_LogL2("L2 烟测成功 sample_id=" . res["topRowid"] . " distance=" . res["distance"])
  return res
}

