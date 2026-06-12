; Diagnostics file IPC: multi-card memory tier prep (host-agnostic)

global g_Nmer_MultiCardMemoryProbeOn := false

Nmer_MultiCardMemoryProbePaths(*) {
    root := FuncExists("Nmer_InstallRoot") ? Nmer_InstallRoot() : A_ScriptDir
    dbg := root . "\Cache\debug"
    if !DirExist(dbg)
        DirCreate(dbg)
    return Map(
        "req", dbg . "\multi_card_memory_probe.json",
        "res", dbg . "\multi_card_memory_probe_result.json",
        "log", dbg . "\multi_card_memory_probe.log"
    )
}

Nmer_MultiCardMemoryProbeLog(line) {
    paths := Nmer_MultiCardMemoryProbePaths()
    try FileAppend("[" . A_Now . "] " . String(line) . "`n", paths["log"], "UTF-8")
    catch {
    }
}

Nmer_MultiCardMemoryProbeEnsure(*) {
    global g_Nmer_MultiCardMemoryProbeOn
    if g_Nmer_MultiCardMemoryProbeOn
        return
    g_Nmer_MultiCardMemoryProbeOn := true
    SetTimer(Nmer_MultiCardMemoryProbePoll, 400)
    Nmer_MultiCardMemoryProbeLog("probe_timer_on")
}

Nmer_MultiCardMemoryProbeWriteResult(id, ok, pass, code, detail := "", extra := 0) {
    paths := Nmer_MultiCardMemoryProbePaths()
    body := Map(
        "id", String(id),
        "ok", !!ok,
        "pass", !!pass,
        "code", String(code),
        "detail", String(detail),
        "finishedAt", A_Now
    )
    if (extra is Map) {
        for k, v in extra
            body[String(k)] := v
    }
    try {
        if FileExist(paths["req"])
            FileDelete(paths["req"])
    } catch {
    }
    try {
        if FileExist(paths["res"])
            FileDelete(paths["res"])
        f := FileOpen(paths["res"], "w", "UTF-8-RAW")
        if IsObject(f) {
            f.Write(Jxon_Dump(body))
            f.Close()
        }
    } catch {
    }
}

Nmer_MultiCardMemoryProbeHideCp(*) {
    if FuncExists("CommandPaletteRouter_Hide")
        CommandPaletteRouter_Hide(Map("reason", "memory_probe"))
    else if FuncExists("CommandPalette_Hide")
        CommandPalette_Hide(Map("reason", "memory_probe"))
}

Nmer_MultiCardMemoryProbeShowCp(*) {
    if FuncExists("CommandPaletteRouter_Show")
        CommandPaletteRouter_Show()
    else if FuncExists("CommandPalette_Show")
        CommandPalette_Show()
}

Nmer_MultiCardMemoryProbeSeedR3Cards(count) {
    global g_Agent_Cards
    if !(g_Agent_Cards is Map)
        g_Agent_Cards := Map()
    else
        g_Agent_Cards := Map()
    n := Max(0, Integer(count))
    now := A_Now
    Loop n {
        i := A_Index
        cid := "memtier-" . i
        rid := "memtier-req-" . i
        q := "/search mem tier " . i
        g_Agent_Cards[cid] := Map(
            "cardId", cid,
            "reqId", rid,
            "gen", i,
            "uiState", "Done",
            "title", "mem tier stub " . i,
            "query", q,
            "activeQuery", q,
            "provider", "openclaw",
            "sessionRef", "",
            "ended", true,
            "running", false,
            "error", "",
            "rawAnswer", "mem tier diagnostic stub",
            "representationRoute", "r3",
            "officialA2uiRoute", Map("route", "r3", "allowed", true, "command", "/search", "reason", "memory_probe"),
            "officialA2ui", Map("source", "fixture", "enabled", true, "fixtureId", "happy-six-components", "command", "/search"),
            "updatedAt", now,
            "createdAt", now
        )
    }
    if FuncExists("CommandPalette_AgentPersistCards")
        CommandPalette_AgentPersistCards()
    return n
}

Nmer_MultiCardMemoryProbePushWebState(cardCount) {
    if !FuncExists("CommandPalette_PushToWeb")
        return 0
    CommandPalette_PushToWeb(Map("type", "palette_set_intent", "intent", "action"))
    if FuncExists("CommandPalette_AgentPushCardSync")
        CommandPalette_AgentPushCardSync()
    ids := []
    global g_Agent_Cards
    for cid, card in g_Agent_Cards {
        if !(card is Map)
            continue
        ids.Push(String(cid))
    }
    if (Integer(cardCount) > 0 && ids.Length > 0) {
        CommandPalette_PushToWeb(Map(
            "type", "palette_memory_tier_mount",
            "cardIds", ids,
            "fixtureId", "happy-six-components"
        ))
    }
    CommandPalette_PushToWeb(Map("type", "palette_show"))
    return ids.Length
}

Nmer_MultiCardMemoryProbePrepareTier(cardCount, settleMs) {
    Nmer_MultiCardMemoryProbeHideCp()
    Sleep(350)
    seeded := Nmer_MultiCardMemoryProbeSeedR3Cards(cardCount)
    Nmer_MultiCardMemoryProbeShowCp()
    Sleep(900)
    mounted := Nmer_MultiCardMemoryProbePushWebState(cardCount)
    if (settleMs < 1000)
        settleMs := 1000
    if (settleMs > 90000)
        settleMs := 90000
    Sleep(settleMs)
    actual := FuncExists("CommandPalette_AgentCardCount") ? CommandPalette_AgentCardCount() : 0
    cpVisible := FuncExists("CommandPalette_IsVisible") ? CommandPalette_IsVisible() : false
    return Map(
        "cardCount", Integer(cardCount),
        "seeded", seeded,
        "mounted", mounted,
        "actualCards", actual,
        "cpVisible", !!cpVisible
    )
}

Nmer_MultiCardMemoryProbePoll(*) {
    paths := Nmer_MultiCardMemoryProbePaths()
    reqPath := paths["req"]
    if !FileExist(reqPath)
        return
    raw := ""
    try raw := FileRead(reqPath, "UTF-8")
    catch as errRead {
        Nmer_MultiCardMemoryProbeLog("read_fail " . errRead.Message)
        return
    }
    if (SubStr(raw, 1, 1) = Chr(0xFEFF))
        raw := SubStr(raw, 2)
    raw := Trim(raw)
    if (raw = "" || StrLen(raw) > 65536) {
        Nmer_MultiCardMemoryProbeWriteResult("", false, false, "PROBE_JSON_INVALID", "empty_or_oversize")
        try FileDelete(reqPath)
        catch {
        }
        return
    }
    root := Map()
    try root := Jxon_Load(raw)
    catch as errJson {
        Nmer_MultiCardMemoryProbeWriteResult("", false, false, "PROBE_JSON_INVALID", SubStr(String(errJson.Message), 1, 120))
        try FileDelete(reqPath)
        catch {
        }
        return
    }
    try FileDelete(reqPath)
    catch {
    }
    if !(root is Map) {
        Nmer_MultiCardMemoryProbeWriteResult("", false, false, "PROBE_JSON_INVALID", "expected_object")
        return
    }
    id := Trim(String(root.Get("id", "")))
    action := StrLower(Trim(String(root.Get("action", ""))))
    switch action {
        case "ping":
            Nmer_MultiCardMemoryProbeWriteResult(id, true, true, "PING_OK", "memory_probe_ipc_active")
        case "hide_cp":
            Nmer_MultiCardMemoryProbeHideCp()
            Nmer_MultiCardMemoryProbeWriteResult(id, true, true, "CP_HIDDEN", "command_palette_hidden")
        case "prepare_tier":
            count := Integer(root.Get("cardCount", 0))
            settle := Integer(root.Get("settleMs", 3000))
            info := Nmer_MultiCardMemoryProbePrepareTier(count, settle)
            ok := info.Get("cpVisible", false)
            if (count > 0)
                ok := ok && (Integer(info.Get("actualCards", 0)) >= count)
            code := ok ? "TIER_READY" : "TIER_PREPARE_WARN"
            Nmer_MultiCardMemoryProbeWriteResult(id, true, ok, code, "seeded=" . info.Get("seeded", 0) . " actual=" . info.Get("actualCards", 0), info)
        default:
            Nmer_MultiCardMemoryProbeWriteResult(id, false, false, "PROBE_UNKNOWN_ACTION", action)
    }
}
