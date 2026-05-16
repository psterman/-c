#Requires AutoHotkey v2.0

SqlBatch_Run(db, statements, label := "startup_batch", chunkSize := 24, idleDelayMs := 20) {
    if !(IsObject(db))
        throw Error("SqlBatch_Run: db is invalid")
    if !(statements is Array)
        throw Error("SqlBatch_Run: statements must be Array")
    total := statements.Length
    if (total = 0)
        return Map("ok", true, "count", 0, "elapsedMs", 0)
    cs := Max(1, Integer(chunkSize))
    delay := Max(10, Integer(idleDelayMs))
    startTick := A_TickCount
    done := 0
    batchNo := 0
    _SqlBatch_Log("sql_batch_begin", "label=" . String(label) . " total=" . total . " chunk=" . cs . " idle_ms=" . delay)
    try db.Exec("BEGIN IMMEDIATE")
    try {
        idx := 1
        while (idx <= total) {
            batchNo += 1
            tail := Min(total, idx + cs - 1)
            loop tail - idx + 1 {
                stmtNo := idx + A_Index - 1
                sql := String(statements[idx + A_Index - 1])
                if (Trim(sql) = "")
                    continue
                if !db.Exec(sql)
                    throw Error("SQL exec failed at #" . stmtNo . " batch=" . batchNo)
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
