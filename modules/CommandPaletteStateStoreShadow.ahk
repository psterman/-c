; CP3a/CP3b: mirror agent card persist to nmer-hub Go PaletteStateShadowStore (write-only shadow).
; CP3b: when palette.stateStore=true, push summary DTOs (max 20) instead of full sync DTOs.

global g_CpStateShadow_WriteSeq := 0
global g_CpStateShadow_Pending := false
global g_CpStateShadow_PendingToken := 0

CommandPalette_AgentShadowWriteLog(event, detail := "") {
    if !FuncExists("CommandPalette_AgentLog")
        return
    try CommandPalette_AgentLog("shadow_" . String(event), String(detail))
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

CommandPalette_AgentQueueShadowWrite(*) {
    if !Nmer_PaletteStateStoreShadowEnabled()
        return
    global g_CpStateShadow_Pending, g_CpStateShadow_PendingToken
    g_CpStateShadow_Pending := true
    g_CpStateShadow_PendingToken := A_TickCount
    token := g_CpStateShadow_PendingToken
    SetTimer(CommandPalette_AgentShadowWriteDebounced.Bind(token), -700)
}

CommandPalette_AgentShadowWriteDebounced(token) {
    global g_CpStateShadow_Pending, g_CpStateShadow_PendingToken
    if !g_CpStateShadow_Pending || token != g_CpStateShadow_PendingToken
        return
    g_CpStateShadow_Pending := false
    CommandPalette_AgentShadowWriteCards()
}

CommandPalette_AgentShadowSortedCards() {
    global g_Agent_Cards
    sorted := []
    if !(IsSet(g_Agent_Cards) && g_Agent_Cards is Map)
        return sorted
    for _, c in g_Agent_Cards {
        if (c is Map)
            sorted.Push(c)
    }
    if sorted.Length > 1 {
        Loop sorted.Length - 1 {
            swapped := false
            Loop sorted.Length - A_Index {
                i := A_Index
                a := sorted[i]
                b := sorted[i + 1]
                ta := (a is Map) ? String(a.Get("updatedAt", a.Get("createdAt", ""))) : ""
                tb := (b is Map) ? String(b.Get("updatedAt", b.Get("createdAt", ""))) : ""
                if (tb > ta) {
                    sorted[i] := b
                    sorted[i + 1] := a
                    swapped := true
                }
            }
            if !swapped
                break
        }
    }
    return sorted
}

CommandPalette_AgentShadowBuildCards() {
    useSummary := FuncExists("Nmer_PaletteStateStoreEnabled") && Nmer_PaletteStateStoreEnabled()
    sorted := CommandPalette_AgentShadowSortedCards()
    maxPush := sorted.Length
    if useSummary {
        global g_Agent_CardLimit
        if IsSet(g_Agent_CardLimit) && Integer(g_Agent_CardLimit) > 0
            maxPush := Integer(g_Agent_CardLimit)
        else
            maxPush := 20
    }
    arr := []
    Loop Min(maxPush, sorted.Length) {
        c := sorted[A_Index]
        if !(c is Map)
            continue
        try {
            if useSummary && FuncExists("CommandPalette_AgentCardToSummaryDto")
                arr.Push(CommandPalette_AgentCardToSummaryDto(c))
            else if FuncExists("CommandPalette_AgentCardToSyncDto")
                arr.Push(CommandPalette_AgentCardToSyncDto(c))
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    return Map("cards", arr, "summary", useSummary)
}

CommandPalette_AgentShadowWriteCards(*) {
    if !Nmer_PaletteStateStoreShadowEnabled()
        return false
    global g_CpStateShadow_WriteSeq
    built := CommandPalette_AgentShadowBuildCards()
    arr := built.Get("cards", [])
    useSummary := !!built.Get("summary", false)
    if !(arr is Array)
        arr := []
    g_CpStateShadow_WriteSeq += 1
    body := Map(
        "source", "ahk",
        "writeSeq", g_CpStateShadow_WriteSeq,
        "writeKind", useSummary ? "summary" : "full",
        "summary", useSummary,
        "cards", arr
    )
    json := "{}"
    if FuncExists("Jxon_Dump")
        json := Jxon_Dump(body)
    addr := FuncExists("Nmer_WailsBridgeDefaultAddr") ? Nmer_WailsBridgeDefaultAddr() : "127.0.0.1:18791"
    url := "http://" . addr . "/v1/palette/state/shadow"
    tag := useSummary ? "cp3b_summary_shadow" : "cp3a_shadow"
    if FuncExists("CoreAsyncHttp_SendAsync") {
        CoreAsyncHttp_SendAsync("POST", url, json, CommandPalette_AgentShadowWriteCallback
            , Map("tag", tag, "timeoutMs", 3500, "maxRetries", 1))
        CommandPalette_AgentShadowWriteLog("queued", "kind=" . (useSummary ? "summary" : "full") . " n=" . arr.Length . " seq=" . g_CpStateShadow_WriteSeq)
        return true
    }
    CommandPalette_AgentShadowWriteLog("skip", "CoreAsyncHttp_SendAsync_missing")
    return false
}

CommandPalette_AgentShadowWriteCallback(ret) {
    if !(ret is Map)
        return
    ok := !!ret.Get("ok", false)
    status := Integer(ret.Get("status", 0))
    if ok
        CommandPalette_AgentShadowWriteLog("ok", "status=" . status)
    else
        CommandPalette_AgentShadowWriteLog("fail", "status=" . status . " err=" . SubStr(String(ret.Get("error", "")), 1, 120))
}

CommandPalette_AgentShadowWriteDetail(cardId, dto) {
    if !Nmer_PaletteStateStoreShadowEnabled()
        return false
    cid := Trim(String(cardId))
    if (cid = "" || !(dto is Map))
        return false
    body := Map("source", "ahk", "cardId", cid, "card", dto)
    json := "{}"
    if FuncExists("Jxon_Dump")
        json := Jxon_Dump(body)
    addr := FuncExists("Nmer_WailsBridgeDefaultAddr") ? Nmer_WailsBridgeDefaultAddr() : "127.0.0.1:18791"
    url := "http://" . addr . "/v1/palette/state/detail"
    if FuncExists("CoreAsyncHttp_SendAsync") {
        CoreAsyncHttp_SendAsync("POST", url, json, CommandPalette_AgentShadowDetailCallback
            , Map("tag", "cp3d_detail_shadow", "timeoutMs", 3500, "maxRetries", 1))
        CommandPalette_AgentShadowWriteLog("detail_queued", "card=" . cid)
        return true
    }
    CommandPalette_AgentShadowWriteLog("detail_skip", "CoreAsyncHttp_SendAsync_missing")
    return false
}

CommandPalette_AgentShadowDetailCallback(ret) {
    if !(ret is Map)
        return
    ok := !!ret.Get("ok", false)
    status := Integer(ret.Get("status", 0))
    if ok
        CommandPalette_AgentShadowWriteLog("detail_ok", "status=" . status)
    else
        CommandPalette_AgentShadowWriteLog("detail_fail", "status=" . status . " err=" . SubStr(String(ret.Get("error", "")), 1, 120))
}
