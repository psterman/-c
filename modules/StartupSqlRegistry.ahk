#Requires AutoHotkey v2.0

global g_StartupSqlBatches := []
global g_StartupSqlRanLabels := Map()

StartupSql_Register(statements, label := "startup_batch", chunkSize := 24, idleDelayMs := 20) {
    global g_StartupSqlBatches, g_StartupSqlRanLabels
    if !(statements is Array) || statements.Length = 0
        return
    lbl := String(label)
    if (lbl != "" && g_StartupSqlRanLabels.Has(lbl))
        return
    for _, spec in g_StartupSqlBatches {
        if (spec is Map && spec.Has("label") && String(spec["label"]) = lbl)
            return
    }
    g_StartupSqlBatches.Push(Map(
        "statements", statements,
        "label", lbl,
        "chunkSize", Integer(chunkSize),
        "idleDelayMs", Integer(idleDelayMs)
    ))
}

StartupSql_RunAll(db) {
    global g_StartupSqlBatches, g_StartupSqlRanLabels
    if !(IsObject(db)) || !(g_StartupSqlBatches is Array)
        return Map("ok", true, "batches", 0, "total", 0)
    total := 0
    batchCount := 0
    specs := g_StartupSqlBatches.Clone()
    for _, spec in specs {
        if !(spec is Map) || !spec.Has("statements")
            continue
        lbl := spec.Has("label") ? String(spec["label"]) : "startup_batch"
        res := SqlBatch_Run(
            db,
            spec["statements"],
            lbl,
            spec.Has("chunkSize") ? spec["chunkSize"] : 24,
            spec.Has("idleDelayMs") ? spec["idleDelayMs"] : 20
        )
        batchCount += 1
        total += res.Has("count") ? Integer(res["count"]) : 0
        if (lbl != "")
            g_StartupSqlRanLabels[lbl] := true
    }
    g_StartupSqlBatches := []
    return Map("ok", true, "batches", batchCount, "total", total)
}
