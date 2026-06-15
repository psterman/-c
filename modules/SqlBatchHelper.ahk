#Requires AutoHotkey v2.0
#Include FuncExists.ahk

_SqlBatch_IsPragma(sql) {
    return RegExMatch(Trim(String(sql)), "i)^PRAGMA\s")
}

_SqlBatch_ExecOrThrow(db, sql, stmtNo, batchNo) {
    if !db.Exec(sql) {
        errDetail := db.HasProp("ErrorMsg") ? String(db.ErrorMsg) : ""
        throw Error(
            "SQL exec failed at #" . stmtNo . " batch=" . batchNo
            . (errDetail != "" ? " — " . errDetail : "")
            . "`nSQL: " . SubStr(Trim(String(sql)), 1, 240)
        )
    }
}

_SqlBatch_IsOptionalPragma(sql) {
    return RegExMatch(Trim(String(sql)), "i)^PRAGMA\s+(journal_mode|synchronous|busy_timeout)\b")
}

_SqlBatch_TryPragma(db, sql, stmtNo) {
    if db.Exec(sql)
        return true
    errDetail := db.HasProp("ErrorMsg") ? String(db.ErrorMsg) : ""
    if _SqlBatch_IsOptionalPragma(sql) {
        _SqlBatch_Log("sql_pragma_skip", "stmt=" . stmtNo . " err=" . errDetail . " sql=" . SubStr(Trim(String(sql)), 1, 120))
        return false
    }
    throw Error(
        "SQL exec failed at #" . stmtNo . " batch=0"
        . (errDetail != "" ? " — " . errDetail : "")
        . "`nSQL: " . SubStr(Trim(String(sql)), 1, 240)
    )
}

/** 数据库关闭后清理残留 WAL/SHM（崩溃退出后 PRAGMA WAL 常触发 disk I/O error） */
Nmer_SqliteClearWalSidecars(dbPath) {
    dbPath := Trim(String(dbPath))
    if (dbPath = "")
        return 0
    n := 0
    for suffix in ["-wal", "-shm", "-journal"] {
        p := dbPath . suffix
        if FileExist(p) {
            try {
                FileDelete(p)
                n += 1
            } catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        }
    }
    return n
}

Nmer_SqliteBackupDbFile(dbPath, tag := "bak") {
    dbPath := Trim(String(dbPath))
    if (dbPath = "" || !FileExist(dbPath))
        return ""
    bak := dbPath . "." . tag . "." . FormatTime(, "yyyyMMddHHmmss")
    try {
        FileCopy(dbPath, bak, true)
        return bak
    } catch {
        return ""
    }
}

/** 关闭连接后删除主库与 WAL/SHM（损坏库无法用 CREATE TABLE 修复时重建） */
Nmer_SqliteResetDbFile(dbPath) {
    dbPath := Trim(String(dbPath))
    if (dbPath = "")
        return false
    Nmer_SqliteClearWalSidecars(dbPath)
    if FileExist(dbPath) {
        try FileDelete(dbPath)
        catch {
            return false
        }
    }
    Nmer_SqliteClearWalSidecars(dbPath)
    return !FileExist(dbPath)
}

Nmer_SqliteQuickCheck(dbPath) {
    dbPath := Trim(String(dbPath))
    if (dbPath = "" || !FileExist(dbPath))
        return true
    db := SQLiteDB()
    if !db.OpenDB(dbPath)
        return false
    ok := false
    try {
        t := ""
        if db.GetTable("PRAGMA quick_check(1)", &t) && IsObject(t) && t.HasProp("Rows") && t.Rows.Length > 0 && t.Rows[1].Length > 0
            ok := (String(t.Rows[1][1]) = "ok")
    } catch {
        ok := false
    }
    try db.CloseDB()
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return ok
}

SqlBatch_Run(db, statements, label := "startup_batch", chunkSize := 24, idleDelayMs := 20) {
    if !(IsObject(db))
        throw Error("SqlBatch_Run: db is invalid")
    if !(statements is Array)
        throw Error("SqlBatch_Run: statements must be Array")
    pragmas := []
    work := []
    for _, raw in statements {
        sql := String(raw)
        if (Trim(sql) = "")
            continue
        if _SqlBatch_IsPragma(sql)
            pragmas.Push(sql)
        else
            work.Push(sql)
    }
    total := work.Length
    if (total = 0 && pragmas.Length = 0)
        return Map("ok", true, "count", 0, "elapsedMs", 0)
    cs := Max(1, Integer(chunkSize))
    delay := Max(10, Integer(idleDelayMs))
    startTick := A_TickCount
    done := 0
    batchNo := 0
    _SqlBatch_Log("sql_batch_begin", "label=" . String(label) . " total=" . total . " pragmas=" . pragmas.Length . " chunk=" . cs . " idle_ms=" . delay)
    for pragmaNo, sql in pragmas {
        _SqlBatch_TryPragma(db, sql, pragmaNo)
    }
    if (total = 0)
        return Map("ok", true, "count", 0, "elapsedMs", A_TickCount - startTick)
    try db.Exec("BEGIN IMMEDIATE")
    try {
        idx := 1
        while (idx <= total) {
            batchNo += 1
            tail := Min(total, idx + cs - 1)
            loop tail - idx + 1 {
                stmtNo := idx + A_Index - 1
                sql := String(work[idx + A_Index - 1])
                if (Trim(sql) = "")
                    continue
                _SqlBatch_ExecOrThrow(db, sql, stmtNo, batchNo)
                done += 1
            }
            _SqlBatch_Log("sql_batch_chunk_done", "label=" . String(label) . " batch=" . batchNo . " stmt_from=" . idx . " stmt_to=" . tail . " done=" . done)
            idx := tail + 1
            if (idx <= total)
                Sleep(delay)
        }
        db.Exec("COMMIT")
    } catch as e {
        try db.Exec("ROLLBACK")
        _SqlBatch_Log("sql_batch_failed", "label=" . String(label) . " batch=" . batchNo . " done=" . done . " err=" . e.Message)
        throw e
    }
    elapsed := A_TickCount - startTick
    _SqlBatch_Log("sql_batch_done", "label=" . String(label) . " count=" . done . " batches=" . batchNo . " elapsed_ms=" . elapsed)
    return Map("ok", true, "count", done, "elapsedMs", elapsed, "label", String(label), "batches", batchNo)
}

_SqlBatch_Log(event, detail := "") {
    try {
        if FuncExists("NMER_Log")
            NMER_Log("startup", String(event), String(detail))
    }
}
