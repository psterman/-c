#Requires AutoHotkey v2.0

global g_StartupSqlBatches := []

StartupSql_Register(statements, label := "startup_batch", chunkSize := 24, idleDelayMs := 20) {
    global g_StartupSqlBatches
    if !(statements is Array) || statements.Length = 0
        return
    g_StartupSqlBatches.Push(Map(
        "statements", statements,
        "label", String(label),
        "chunkSize", Integer(chunkSize),
        "idleDelayMs", Integer(idleDelayMs)
    ))
}

StartupSql_RunAll(db) {
    global g_StartupSqlBatches
    if !(IsObject(db)) || !(g_StartupSqlBatches is Array)
        return Map("ok", true, "batches", 0, "total", 0)
    total := 0
    batchCount := 0
    for _, spec in g_StartupSqlBatches {
        if !(spec is Map) || !spec.Has("statements")
            continue
        res := SqlBatch_Run(
            db,
            spec["statements"],
            spec.Has("label") ? spec["label"] : "startup_batch",
            spec.Has("chunkSize") ? spec["chunkSize"] : 24,
            spec.Has("idleDelayMs") ? spec["idleDelayMs"] : 20
        )
        batchCount += 1
        total += res.Has("count") ? Integer(res["count"]) : 0
    }
    return Map("ok", true, "batches", batchCount, "total", total)
}
