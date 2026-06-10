; SurfaceTransaction.ahk — S3 generationId 打开事务（BEGIN / COMMIT / ABORT）

global g_SurfaceTxn_GenerationSeq := 0
global g_SurfaceTxn_Active := ""
global g_SurfaceTxn_OpenTimeoutMs := 15000
global g_SurfaceTxn_InRestore := false

SurfaceTransaction_ShouldUse(*) {
    try {
        if FuncExists("Nmer_SurfaceManagerUseTransactions") && Nmer_SurfaceManagerUseTransactions()
            return true
    } catch {
    }
    return false
}

SurfaceTransaction_ShouldBeginFor(surfaceId, meta := 0) {
    sid := String(surfaceId)
    ; resident FTB 启动/显隐为异步长流程，不走 generation 事务（避免误 timeout）
    if (sid = "floating_toolbar")
        return false
    return true
}

SurfaceTransaction_IsRestoreContext(meta) {
    global g_SurfaceTxn_InRestore
    if g_SurfaceTxn_InRestore
        return true
    if !(meta is Map)
        return false
    if meta.Has("skipTransaction") && !!meta["skipTransaction"]
        return true
    if meta.Has("reason") && String(meta["reason"]) = "transaction_abort_restore"
        return true
    return false
}

SurfaceTransaction_AllocId() {
    global g_SurfaceTxn_GenerationSeq
    g_SurfaceTxn_GenerationSeq += 1
    return "gen-" . g_SurfaceTxn_GenerationSeq
}

SurfaceTransaction_GetActive(*) {
    global g_SurfaceTxn_Active
    if !(g_SurfaceTxn_Active is Map)
        return 0
    if !g_SurfaceTxn_Active.Has("genId")
        return 0
    return g_SurfaceTxn_Active
}

SurfaceTransaction_PendingSurfaceList(pending) {
    names := []
    for item in pending {
        if !(item is Map) || !item.Has("surface")
            continue
        names.Push(String(item["surface"]))
    }
    return names
}

SurfaceTransaction_CollectPendingRestores(targetSurfaceId) {
    pending := []
    if !FuncExists("SurfaceManager_ConflictSurfaces")
        return pending
    global g_SurfaceRuntime_Registry
    for _, sid in SurfaceManager_ConflictSurfaces(targetSurfaceId) {
        if !g_SurfaceRuntime_Registry.Has(sid)
            continue
        rec := g_SurfaceRuntime_Registry[sid]
        state := (rec is Map) && rec.Has("state") ? String(rec["state"]) : ""
        if !(state = "ACTIVE" || state = "CREATING")
            continue
        pending.Push(Map(
            "surface", sid,
            "wasActive", 1,
            "wasVisible", 1,
            "priorState", state
        ))
    }
    return pending
}

SurfaceTransaction_RecordTxnEvent(kind, txn, extra := 0) {
    if !FuncExists("SurfaceManager_RecordEvent")
        return
    meta := Map(
        "generationId", String(txn["genId"]),
        "target", String(txn["target"]),
        "phase", txn.Has("phase") ? String(txn["phase"]) : ""
    )
    if txn.Has("requestId") && String(txn["requestId"]) != ""
        meta["requestId"] := String(txn["requestId"])
    if (extra is Map) {
        for key, val in extra
            meta[String(key)] := SurfaceManager_SimpleClone(val)
    }
    SurfaceManager_RecordEvent(String(kind), txn["target"], meta)
}

SurfaceTransaction_UpdateRequestId(generationId, requestId) {
    active := SurfaceTransaction_GetActive()
    if !active || String(active["genId"]) != String(generationId)
        return
    global g_SurfaceTxn_Active
    g_SurfaceTxn_Active["requestId"] := String(requestId)
}

SurfaceTransaction_ScheduleOpenTimeout() {
    global g_SurfaceTxn_OpenTimeoutMs
    ms := g_SurfaceTxn_OpenTimeoutMs
    active := SurfaceTransaction_GetActive()
    if active {
        tgt := String(active["target"])
        if (tgt = "search_center" || tgt = "command_palette")
            ms := 25000
    }
    try SetTimer(SurfaceTransaction_OnOpenTimeout, 0)
    try SetTimer(SurfaceTransaction_OnOpenTimeout, -ms)
}

SurfaceTransaction_ClearOpenTimeout() {
    try SetTimer(SurfaceTransaction_OnOpenTimeout, 0)
}

SurfaceTransaction_ShouldRestorePending(reason, txn := 0) {
    r := String(reason)
    if (r = "superseded" || r = "user_close" || r = "target_close")
        return false
    return true
}

SurfaceTransaction_ShouldRestoreItem(item) {
    if !(item is Map) || !item.Has("surface")
        return false
    if !item.Has("wasActive") || !item["wasActive"]
        return false
    sid := String(item["surface"])
    global g_SurfaceRuntime_Registry
    if !g_SurfaceRuntime_Registry.Has(sid)
        return false
    rec := g_SurfaceRuntime_Registry[sid]
    state := (rec is Map) && rec.Has("state") ? String(rec["state"]) : ""
    if (state = "SUSPENDED")
        return true
    return false
}

SurfaceTransaction_OnTargetClose(surfaceId, meta := 0) {
    active := SurfaceTransaction_GetActive()
    if !active
        return false
    if String(active["target"]) != String(surfaceId)
        return false
    if String(active["phase"]) != "opening"
        return false
    return SurfaceTransaction_Abort(String(active["genId"]), "user_close", meta)
}

SurfaceTransaction_OnOpenTimeout(*) {
    active := SurfaceTransaction_GetActive()
    if !active
        return
    if String(active["phase"]) != "opening"
        return
    elapsed := A_TickCount - active["beginTick"]
    pending := active.Has("pendingRestores") ? active["pendingRestores"] : []
    genId := String(active["genId"])
    ; 异步 Init（CP/SCWV 等）可能超过 15s 仍在 CREATING：仅记超时并释放事务，禁止 Dispose
    SurfaceTransaction_RecordTxnEvent("transaction_timeout", active, Map("elapsedMs", elapsed))
    global g_SurfaceTxn_Active
    g_SurfaceTxn_Active := ""
    SurfaceTransaction_ClearOpenTimeout()
    if pending.Length > 0 && SurfaceTransaction_ShouldRestorePending("open_timeout", active)
        SurfaceTransaction_RestorePending(pending, genId)
}

SurfaceTransaction_Begin(surfaceId, meta := 0, requestId := 0) {
    sid := String(surfaceId)
    active := SurfaceTransaction_GetActive()
    if active
        SurfaceTransaction_Abort(active["genId"], "superseded", Map("newTarget", sid))
    genId := SurfaceTransaction_AllocId()
    pending := SurfaceTransaction_CollectPendingRestores(sid)
    budgetPreempt := false
    try {
        if pending.Length > 0
            && FuncExists("Nmer_SurfaceManagerEnforceBudget") && Nmer_SurfaceManagerEnforceBudget()
            && FuncExists("SurfaceManager_ConflictGroupFor") && SurfaceManager_ConflictGroupFor(sid) != ""
            budgetPreempt := true
    } catch {
    }
    if budgetPreempt {
        kept := []
        for item in pending {
            if !(item is Map) || !item.Has("surface")
                continue
            conflictSid := String(item["surface"])
            isPrimaryConflict := false
            try {
                if FuncExists("SurfaceManager_ConflictGroupFor")
                    isPrimaryConflict := (SurfaceManager_ConflictGroupFor(conflictSid) = "primary")
            } catch {
            }
            if !isPrimaryConflict {
                kept.Push(item)
                continue
            }
            handoff := false
            try {
                if FuncExists("SurfaceManager_IsPrimaryHandoff")
                    handoff := SurfaceManager_IsPrimaryHandoff(sid, conflictSid)
            } catch {
            }
            enforceMeta := Map(
                "reason", handoff ? "primary_handoff" : "budget_pressure",
                "requester", sid,
                "phase", "pre_open",
                "bucket", "primary"
            )
            if FuncExists("SurfaceManager_RecordEvent")
                try SurfaceManager_RecordEvent("budget_enforce", conflictSid, enforceMeta)
            if handoff {
                if FuncExists("SurfaceExecutor_Suspend")
                    SurfaceExecutor_Suspend(conflictSid, enforceMeta)
            } else if FuncExists("SurfaceIntent_Dispose") && FuncExists("Nmer_SurfaceManagerRouteIntents") && Nmer_SurfaceManagerRouteIntents()
                SurfaceIntent_Dispose(conflictSid, enforceMeta)
            else if FuncExists("SurfaceExecutor_Dispose")
                SurfaceExecutor_Dispose(conflictSid, enforceMeta)
        }
        pending := kept
        if FuncExists("SurfaceManager_RecomputeBudget")
            try SurfaceManager_RecomputeBudget("pre_open", sid, "", true)
    }
    txn := Map(
        "genId", genId,
        "target", sid,
        "requestId", requestId ? String(requestId) : "",
        "phase", "opening",
        "pendingRestores", pending,
        "beginTick", A_TickCount
    )
    global g_SurfaceTxn_Active
    g_SurfaceTxn_Active := txn
    SurfaceTransaction_RecordTxnEvent("transaction_begin", txn, Map(
        "pendingCount", pending.Length,
        "pendingSurfaces", SurfaceTransaction_PendingSurfaceList(pending)
    ))
    shouldEnforce := false
    try {
        if FuncExists("SurfaceManager_ShouldEnforceSlotsForRequest")
            shouldEnforce := SurfaceManager_ShouldEnforceSlotsForRequest(sid, "SurfaceIntent_Open", meta)
    } catch {
    }
    if shouldEnforce && FuncExists("SurfaceManager_HideSurface") {
        for item in pending
            SurfaceManager_HideSurface(item["surface"], "slot_conflict", sid)
    }
    SurfaceTransaction_ScheduleOpenTimeout()
    return genId
}

SurfaceTransaction_RecordStale(generationId, surfaceId, reason, meta := 0) {
    if !FuncExists("SurfaceManager_RecordEvent")
        return
    payload := Map(
        "generationId", String(generationId),
        "surface", String(surfaceId),
        "reason", String(reason)
    )
    if (meta is Map) {
        for key, val in meta
            payload[String(key)] := SurfaceManager_SimpleClone(val)
    }
    active := SurfaceTransaction_GetActive()
    if active
        payload["activeGenerationId"] := String(active["genId"])
    SurfaceManager_RecordEvent("transaction_stale", surfaceId, payload)
}

SurfaceTransaction_Commit(generationId, surfaceId := "", meta := 0) {
    genId := String(generationId)
    if (genId = "")
        return false
    active := SurfaceTransaction_GetActive()
    if !active || String(active["genId"]) != genId {
        SurfaceTransaction_RecordStale(genId, surfaceId, "commit", meta)
        return false
    }
    if String(active["target"]) != String(surfaceId) {
        SurfaceTransaction_RecordStale(genId, surfaceId, "commit_target_mismatch", meta)
        return false
    }
    active["phase"] := "committed"
    extra := (meta is Map) ? meta : Map()
    SurfaceTransaction_RecordTxnEvent("transaction_commit", active, extra)
    global g_SurfaceTxn_Active
    g_SurfaceTxn_Active := ""
    SurfaceTransaction_ClearOpenTimeout()
    return true
}

SurfaceTransaction_RestorePending(pending, abortedGenId) {
    global g_SurfaceTxn_InRestore
    prev := g_SurfaceTxn_InRestore
    g_SurfaceTxn_InRestore := true
    try {
        for item in pending {
            if !SurfaceTransaction_ShouldRestoreItem(item)
                continue
            sid := String(item["surface"])
            if !FuncExists("SurfaceIntent_Open")
                continue
            try SurfaceIntent_Open(sid, Map(
                "reason", "transaction_abort_restore",
                "skipTransaction", true,
                "restoredFromGen", abortedGenId
            ))
            catch {
            }
        }
    } finally {
        g_SurfaceTxn_InRestore := prev
    }
}

SurfaceTransaction_CleanupPartialTarget(targetSurfaceId, genId, reason) {
    sid := String(targetSurfaceId)
    state := ""
    global g_SurfaceRuntime_Registry
    if g_SurfaceRuntime_Registry.Has(sid) {
        rec := g_SurfaceRuntime_Registry[sid]
        state := (rec is Map) && rec.Has("state") ? String(rec["state"]) : ""
    }
    if !(state = "CREATING" || state = "ACTIVE")
        return
    if !FuncExists("SurfaceExecutor_Dispose")
        return
    try SurfaceExecutor_Dispose(sid, Map(
        "reason", "transaction_abort_partial",
        "generationId", genId,
        "abortReason", String(reason)
    ))
    catch {
    }
}

SurfaceTransaction_Abort(generationId, reason := "", extra := 0) {
    genId := String(generationId)
    active := SurfaceTransaction_GetActive()
    if !active
        return false
    if String(active["genId"]) != genId {
        SurfaceTransaction_RecordStale(genId, active["target"], "abort_mismatch", Map("reason", reason))
        return false
    }
    active["phase"] := "aborted"
    payload := Map("reason", String(reason))
    if (extra is Map) {
        for key, val in extra
            payload[String(key)] := SurfaceManager_SimpleClone(val)
    }
    SurfaceTransaction_RecordTxnEvent("transaction_abort", active, payload)
    target := String(active["target"])
    pending := active.Has("pendingRestores") ? active["pendingRestores"] : []
    global g_SurfaceTxn_Active
    g_SurfaceTxn_Active := ""
    SurfaceTransaction_ClearOpenTimeout()
    r := String(reason)
    if SurfaceTransaction_ShouldRestorePending(r, active)
        SurfaceTransaction_RestorePending(pending, genId)
    if (r != "superseded" && (r = "open_error" || r = "show_failed"))
        SurfaceTransaction_CleanupPartialTarget(target, genId, r)
    return true
}

SurfaceTransaction_EnrichObserveMeta(surfaceId, meta := 0) {
    out := Map()
    if (meta is Map) {
        for key, val in meta
            out[String(key)] := SurfaceManager_SimpleClone(val)
    } else if (meta != 0 && String(meta) != "") {
        out["detail"] := meta
    }
    if out.Has("generationId") && String(out["generationId"]) != ""
        return out
    active := SurfaceTransaction_GetActive()
    if active && String(active["target"]) = String(surfaceId) && String(active["phase"]) = "opening" {
        out["generationId"] := String(active["genId"])
        if !out.Has("requestId") && active.Has("requestId") && String(active["requestId"]) != ""
            out["requestId"] := String(active["requestId"])
    }
    return out
}

SurfaceTransaction_OnSurfaceActive(surfaceId, meta := 0) {
    if !SurfaceTransaction_ShouldUse()
        return
    m := SurfaceTransaction_EnrichObserveMeta(surfaceId, meta)
    if !m.Has("generationId") || String(m["generationId"]) = ""
        return
    SurfaceTransaction_Commit(String(m["generationId"]), surfaceId, m)
}

SurfaceTransaction_OnSurfaceFailed(surfaceId, meta := 0) {
    if !SurfaceTransaction_ShouldUse()
        return
    m := SurfaceTransaction_EnrichObserveMeta(surfaceId, meta)
    if !m.Has("generationId") || String(m["generationId"]) = ""
        return
    SurfaceTransaction_Abort(String(m["generationId"]), "show_failed", m)
}
