#Requires AutoHotkey v2.0

; CommandPaletteAgentOrchestrator — 动作 Tab 全托管代理任务编排（非阻塞）

global g_Agent_Cards := Map()
global g_CardSessionMap := Map()
global g_Agent_CancelToken := false
global g_Agent_ActiveCardId := ""
global g_Agent_DefaultProvider := "openclaw"
global g_Agent_StreamGen := 0
global g_Agent_AiRoute := Map()
global g_Agent_DispatchPending := Map()
global g_Agent_RecoverPending := Map()
global g_Agent_FtbFetchBusy := false
global g_Agent_FtbSendingCache := Map()
global g_Agent_BootstrapForce := false
global g_Agent_ShellSendingReqIds := Map()
global g_AgentDbg_PipelineState := Map()
global g_Agent_RawAnswerLimit := 120000
global g_Agent_MessageLimit := 30
global g_Agent_CardLimit := 20
global g_Agent_PersistToken := 0
global g_Agent_PersistPending := false
global g_Agent_CardsLoaded := false
global g_Agent_CardsLoadedMtime := ""

CommandPalette_AgentClipText(value, maxLen := 120000) {
    text := String(value)
    if StrLen(text) <= maxLen
        return text
    return SubStr(text, StrLen(text) - maxLen + 1)
}

CommandPalette_AgentPruneCards() {
    global g_Agent_Cards, g_CardSessionMap, g_Agent_CardLimit
    if !(g_Agent_Cards is Map)
        return 0
    removed := 0
    while g_Agent_Cards.Count > g_Agent_CardLimit {
        oldestId := ""
        oldestStamp := ""
        for cid, card in g_Agent_Cards {
            if !(card is Map)
                continue
            if card.Get("running", false) && !card.Get("ended", false)
                continue
            stamp := String(card.Get("updatedAt", card.Get("createdAt", "")))
            if (oldestId = "" || stamp < oldestStamp) {
                oldestId := cid
                oldestStamp := stamp
            }
        }
        if (oldestId = "")
            break
        g_Agent_Cards.Delete(oldestId)
        if (g_CardSessionMap is Map) && g_CardSessionMap.Has(oldestId)
            g_CardSessionMap.Delete(oldestId)
        removed += 1
    }
    return removed
}

CommandPalette_AgentProtocolPrompt() {
    return "
(
你是运行在命令面板动作 Tab 的高级全托管 AI 命令大脑（龙虾RPA/Hermes/OpenClaw 协同体）。本地 AHK 仅作动作触达终端。

【输出协议】你必须且只能使用以下四组标签通信，严禁标签外废话：
::PLAN_START:: 步骤1：… | 步骤2：… ::PLAN_END::
::STATUS_START:: [执行器] 标题
日志 ::STATUS_END::
::QUESTION_START:: 标题
说明 ::QUESTION_END::
::REPLY_START:: 标题
Markdown 复盘 ::REPLY_END::

【规则】
1. 新任务必须先 PLAN。
2. 紧急阻断前必须先闭合 STATUS（禁止标签嵌套）。
3. 目标被用户改写时必须再次输出 PLAN（重规划）。
4. 需用户确认时用 QUESTION 并等待回复。
5. 全链路完成用 REPLY 完结。
)"
}

CommandPalette_AgentBuildSystemPrompt(card) {
    base := CommandPalette_AgentProtocolPrompt()
    if !(card is Map)
        return base
    addon := Trim(String(card.Get("promptAddon", "")))
    if (addon = "")
        return base
    return base . "`n`n" . addon
}

CommandPalette_AgentCardsPath() {
    if FuncExists("Nmer_DebugPath")
        return Nmer_DebugPath("agent_cards.json")
    return A_ScriptDir . "\Cache\debug\agent_cards.json"
}

CommandPalette_AgentWireLog(tag, detail := "") {
    try {
        path := CommandPalette_AgentCardsPath()
        dir := ""
        SplitPath(path, , &dir)
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)
        FileAppend("[" . A_Now . "][" . String(tag) . "] " . SubStr(String(detail), 1, 800) . "`n", dir . "\cmdpal_agent_wire.log", "UTF-8")
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

CommandPalette_AgentLog(event, detail := "") {
    line := "[" . A_Now . "][agent][" . event . "] " . String(detail)
    try OutputDebug(line . "`n")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if FuncExists("NMER_Log") {
        try NMER_Log("cmdpal_agent", event, String(detail))
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    if FuncExists("Nmer_Telemetry_Record") {
        telemAction := ""
        switch ev {
            case "dispatch_ai":
                telemAction := "dispatch"
            case "dispatch_ai_paths":
                telemAction := "route_paths"
            case "adapter_ok":
                telemAction := "adapter_ok"
            case "adapter_fail":
                telemAction := "adapter_fail"
            case "recover_ok":
                telemAction := "recover"
            case "poll_hit", "poll_hit_long", "poll_final_hit":
                telemAction := "poll_hit"
        }
        if (telemAction != "") {
            try Nmer_Telemetry_Record("cmdpal_agent", telemAction, (InStr(ev, "fail") = 0), Map("detail", String(detail)))
            catch as _e {
                NmerCatch(A_ThisFunc, _e)
            }
        }
    }
    if FuncExists("CommandPalette_AgentDebugTrace") {
        dbgLayer := "ahk"
        ev := String(event)
        if (ev = "dispatch_ai" || ev = "dispatch_ai_paths")
            dbgLayer := "dispatch"
        else if (InStr(ev, "poll") || InStr(ev, "compose") || InStr(ev, "agent_dispatch"))
            dbgLayer := "ftb"
        try CommandPalette_AgentDebugTrace(dbgLayer, ev, String(detail))
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
}

CommandPalette_AgentNewId(prefix := "cpag") {
    return prefix . "_" . A_TickCount . "_" . Random(1000, 9999)
}

CommandPalette_AgentGetCard(cardId) {
    global g_Agent_Cards
    cid := Trim(String(cardId))
    if (cid = "" || !IsObject(g_Agent_Cards) || !g_Agent_Cards.Has(cid))
        return 0
    c := g_Agent_Cards[cid]
    return (c is Map) ? c : 0
}

CommandPalette_AgentIsRunning(cardId := "") {
    global g_Agent_Cards, g_Agent_ActiveCardId
    cid := Trim(String(cardId))
    if (cid = "") {
        for id, c in g_Agent_Cards {
            if (c is Map) && !c.Get("ended", true) && c.Get("running", false)
                return true
        }
        return false
    }
    c := CommandPalette_AgentGetCard(cid)
    if !(c is Map)
        return false
    return !!c.Get("running", false) && !c.Get("ended", false)
}

CommandPalette_IsAgentRunning(*) {
    return CommandPalette_AgentIsRunning()
}

CommandPalette_AgentCardToSyncDto(card) {
    global g_Agent_MessageLimit
    if !(card is Map)
        return Map()
    dto := Map(
        "cardId", String(card.Get("cardId", "")),
        "reqId", String(card.Get("reqId", "")),
        "gen", Integer(card.Get("gen", 0)),
        "uiState", String(card.Get("uiState", "Planning")),
        "title", String(card.Get("title", card.Get("query", ""))),
        "query", String(card.Get("query", card.Get("title", ""))),
        "activeQuery", String(card.Get("activeQuery", card.Get("query", card.Get("title", "")))),
        "provider", String(card.Get("provider", CommandPalette_AgentDefaultProvider())),
        "sessionRef", String(card.Get("sessionRef", "")),
        "ended", !!card.Get("ended", false),
        "running", !!card.Get("running", false),
        "error", String(card.Get("error", "")),
        "rawAnswer", SubStr(String(card.Get("rawAnswer", "")), 1, 12000),
        "liveThought", SubStr(String(card.Get("liveThought", "")), 1, 400),
        "hasProto", !!RegExMatch(String(card.Get("rawAnswer", "")), "::(PLAN|STATUS|QUESTION|REPLY)_(START|END)::"),
        "routeId", String(card.Get("routeId", "")),
        "routeLabel", String(card.Get("routeLabel", "")),
        "updatedAt", String(card.Get("updatedAt", "")),
        "createdAt", String(card.Get("createdAt", card.Get("updatedAt", ""))),
        "blockCount", 0
    )
    userMsgs := []
    if card.Has("messages") && card["messages"] is Array {
        startAt := Max(1, card["messages"].Length - g_Agent_MessageLimit + 1)
        Loop card["messages"].Length - startAt + 1 {
            m := card["messages"][startAt + A_Index - 1]
            if !(m is Map) || String(m.Get("role", "")) != "user"
                continue
            userMsgs.Push(Map(
                "role", "user",
                "text", SubStr(String(m.Get("text", "")), 1, 500),
                "at", String(m.Get("at", ""))
            ))
        }
    }
    dto["messages"] := userMsgs
    if card.Has("blockStore") && card["blockStore"] is Map {
        bs := card["blockStore"]
        dto["blockStore"] := bs
        if bs.Has("blocks") && bs["blocks"] is Array
            dto["blockCount"] := bs["blocks"].Length
    }
    if card.Has("protocolClosure") && card["protocolClosure"] is Map
        dto["protocolClosure"] := card["protocolClosure"]
    if card.Has("representationRoute")
        dto["representationRoute"] := String(card.Get("representationRoute", "r1r2"))
    if card.Has("officialA2uiRoute") && card["officialA2uiRoute"] is Map
        dto["officialA2uiRoute"] := card["officialA2uiRoute"]
    if card.Has("officialA2ui") && card["officialA2ui"] is Map
        dto["officialA2ui"] := card["officialA2ui"]
    return dto
}

CommandPalette_AgentCardToSummaryDto(card) {
    dto := CommandPalette_AgentCardToSyncDto(card)
    if !(dto is Map)
        return Map()
    raw := String(dto.Get("rawAnswer", ""))
    dto["rawAnswer"] := SubStr(raw, 1, 480)
    dto["summaryOnly"] := true
    dto["hasAnswer"] := CommandPalette_AgentAnswerIsSubstantial(raw)
    if dto.Has("blockStore")
        dto.Delete("blockStore")
    if dto.Has("officialA2ui")
        dto.Delete("officialA2ui")
    if dto.Has("protocolClosure")
        dto.Delete("protocolClosure")
    return dto
}

CommandPalette_AgentCardToPushDto(card) {
    if !(card is Map)
        return Map()
    if FuncExists("Nmer_PaletteStateStoreEnabled") && Nmer_PaletteStateStoreEnabled()
        return CommandPalette_AgentCardToSummaryDto(card)
    return CommandPalette_AgentCardToSyncDto(card)
}

CommandPalette_AgentSchedulePersist(immediate := false) {
    global g_Agent_PersistToken, g_Agent_PersistPending
    if immediate {
        g_Agent_PersistPending := false
        SetTimer(CommandPalette_AgentPersistCards, 0)
        return
    }
    g_Agent_PersistPending := true
    g_Agent_PersistToken := A_TickCount
    token := g_Agent_PersistToken
    SetTimer(CommandPalette_AgentPersistCardsDebounced.Bind(token), -800)
}

CommandPalette_AgentPersistCardsDebounced(token) {
    global g_Agent_PersistToken, g_Agent_PersistPending
    if !g_Agent_PersistPending || token != g_Agent_PersistToken
        return
    g_Agent_PersistPending := false
    CommandPalette_AgentPersistCards()
}

CommandPalette_AgentFlushPersist(*) {
    CommandPalette_AgentSchedulePersist(true)
}

CommandPalette_AgentResolveOfficialRoute(query) {
    if FuncExists("Nmer_WailsBridgeResolveOfficialRoute") {
        try return Nmer_WailsBridgeResolveOfficialRoute(query)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    return Map("route", "r1r2", "allowed", false, "reason", "bridge_module_missing", "command", "")
}

CommandPalette_AgentCardIsOfficialA2uiRoute(card) {
    if !(card is Map)
        return false
    route := StrLower(Trim(String(card.Get("representationRoute", ""))))
    if (route = "r3")
        return true
    if card.Has("officialA2uiRoute") && card["officialA2uiRoute"] is Map {
        oar := card["officialA2uiRoute"]
        if (String(oar.Get("route", "")) = "r3" && oar.Get("allowed", false))
            return true
    }
    return false
}

CommandPalette_AgentApplyOfficialRoute(card, routeDecision) {
    if !(card is Map) || !(routeDecision is Map)
        return
    route := String(routeDecision.Get("route", "r1r2"))
    card["representationRoute"] := route
    card["officialA2uiRoute"] := routeDecision
    cmd := String(routeDecision.Get("command", ""))
    if (cmd != "")
        card["slashCommand"] := cmd
    keepGoJsonl := false
    if card.Has("officialA2ui") && card["officialA2ui"] is Map
        keepGoJsonl := (String(card["officialA2ui"].Get("source", "")) = "go-jsonl")
    if (route = "r3" && !!routeDecision.Get("allowed", false)) {
        if !keepGoJsonl
            card["officialA2ui"] := Map("source", "live", "enabled", true, "command", cmd, "surfaceId", "")
    } else if !keepGoJsonl {
        if card.Has("officialA2ui")
            card.Delete("officialA2ui")
    }
}

CommandPalette_AgentPersistCards() {
    global g_Agent_Cards, g_Agent_CardsLoaded, g_Agent_CardsLoadedMtime
    CommandPalette_AgentPruneCards()
    path := CommandPalette_AgentCardsPath()
    try {
        if FuncExists("Nmer_EnsureDebugDir")
            Nmer_EnsureDebugDir()
        else {
            dir := ""
            SplitPath(path, , &dir)
            if (dir != "" && !DirExist(dir))
                DirCreate(dir)
        }
        arr := []
        for _, c in g_Agent_Cards {
            if (c is Map)
                arr.Push(CommandPalette_AgentCardToSyncDto(c))
        }
        json := "[]"
        if FuncExists("Jxon_Dump")
            json := Jxon_Dump(arr)
        ; 勿对不存在的文件 FileDelete（AHK v2 会抛错 2，导致从未写入）
        f := FileOpen(path, "w", "UTF-8")
        if !IsObject(f)
            throw Error("FileOpen 失败: " . path)
        f.Write(json)
        f.Close()
        g_Agent_CardsLoaded := true
        try g_Agent_CardsLoadedMtime := String(FileGetTime(path, "M"))
        catch
            g_Agent_CardsLoadedMtime := ""
        CommandPalette_AgentLog("persist_ok", "n=" . arr.Length . " path=" . path)
        if FuncExists("CommandPalette_AgentQueueShadowWrite")
            try CommandPalette_AgentQueueShadowWrite()
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
    } catch as eP {
        CommandPalette_AgentLog("persist_err", path . " :: " . eP.Message)
    }
}

CommandPalette_AgentLoadCards(force := false) {
    global g_Agent_Cards, g_CardSessionMap, g_Agent_CardsLoaded, g_Agent_CardsLoadedMtime
    if FuncExists("Nmer_EnsureDebugDir")
        try Nmer_EnsureDebugDir()
    path := CommandPalette_AgentCardsPath()
    stamp := ""
    try {
        if FileExist(path)
            stamp := String(FileGetTime(path, "M"))
    } catch {
        stamp := ""
    }
    if !force && g_Agent_CardsLoaded && (stamp = g_Agent_CardsLoadedMtime)
        return
    g_Agent_CardsLoaded := true
    g_Agent_CardsLoadedMtime := stamp
    if !FileExist(path)
        return
    try {
        raw := FileRead(path, "UTF-8")
        if (raw = "")
            return
        data := Jxon_Load(raw)
        if !(data is Array)
            return
        for _, dto in data {
            if !(dto is Map)
                continue
            cid := Trim(String(dto.Get("cardId", "")))
            if (cid = "")
                continue
            if g_Agent_Cards.Has(cid) && (g_Agent_Cards[cid] is Map) {
                card := g_Agent_Cards[cid]
                if card.Get("running", false) && !card.Get("ended", false)
                    continue
            } else {
                card := Map()
                g_Agent_Cards[cid] := card
            }
            card["cardId"] := cid
            card["reqId"] := String(dto.Get("reqId", ""))
            card["gen"] := Integer(dto.Get("gen", card.Get("gen", 0)))
            card["uiState"] := String(dto.Get("uiState", "Done"))
            card["title"] := String(dto.Get("title", ""))
            card["query"] := String(dto.Get("query", ""))
            card["provider"] := CommandPalette_AgentSanitizeProvider(dto.Get("provider", ""))
            card["sessionRef"] := String(dto.Get("sessionRef", ""))
            card["ended"] := !!dto.Get("ended", true)
            card["running"] := !!dto.Get("running", false)
            card["error"] := String(dto.Get("error", ""))
            card["rawAnswer"] := String(dto.Get("rawAnswer", ""))
            card["routeId"] := String(dto.Get("routeId", ""))
            card["routeLabel"] := String(dto.Get("routeLabel", ""))
            if dto.Has("blockStore") && dto["blockStore"] is Map
                card["blockStore"] := dto["blockStore"]
            card["updatedAt"] := String(dto.Get("updatedAt", ""))
            card["createdAt"] := String(dto.Get("createdAt", dto.Get("updatedAt", "")))
            if dto.Has("messages") && dto["messages"] is Array
                card["messages"] := dto["messages"]
            if Trim(String(dto.Get("sessionRef", ""))) != ""
                g_CardSessionMap[cid] := String(dto.Get("sessionRef", ""))
        }
        CommandPalette_AgentPruneCards()
    } catch as eL {
        CommandPalette_AgentLog("load_err", eL.Message)
    }
}

CommandPalette_AgentRecoverCardsIfEmpty() {
    global g_Agent_Cards
    if g_Agent_Cards.Count > 0
        return 0
    if FileExist(CommandPalette_AgentCardsPath())
        return 0
    tracePath := FuncExists("Nmer_DebugPath") ? Nmer_DebugPath("nmer_trace.log") : (A_ScriptDir . "\Cache\debug\nmer_trace.log")
    wirePath := FuncExists("Nmer_DebugPath") ? Nmer_DebugPath("cmdpal_agent_wire.log") : (A_ScriptDir . "\Cache\debug\cmdpal_agent_wire.log")
    if !FileExist(tracePath)
        return 0
    texts := []
    if FileExist(wirePath) {
        for line in StrSplit(FileRead(wirePath, "UTF-8"), "`n", "`r") {
            if RegExMatch(line, "\[submit_enter\] kind=new text=(.+)$", &m)
                texts.Push(Trim(m[1]))
        }
    }
    dispatches := []
    for line in StrSplit(FileRead(tracePath, "UTF-8"), "`n", "`r") {
        if RegExMatch(line, "\[cmdpal_agent\]\[dispatch_ai\] card=(\S+) req=(\S+) prov=(\S+)", &m)
            dispatches.Push(Map("cardId", m[1], "reqId", m[2], "prov", m[3]))
    }
    if dispatches.Length < 1
        return 0
    seen := Map()
    ti := 0
    n := 0
    for _, d in dispatches {
        cid := String(d["cardId"])
        if (cid = "" || seen.Has(cid))
            continue
        seen[cid] := true
        ti++
        title := ti <= texts.Length ? texts[ti] : ("历史任务 " . cid)
        title := SubStr(title, 1, 48)
        if (StrLen(title) > 48)
            title := SubStr(title, 1, 45) . "…"
        prov := CommandPalette_AgentSanitizeProvider(d["prov"])
        g_Agent_Cards[cid] := Map(
            "cardId", cid,
            "reqId", String(d["reqId"]),
            "uiState", "Done",
            "title", title,
            "query", title,
            "provider", prov,
            "sessionRef", "",
            "ended", true,
            "running", false,
            "error", "",
            "rawAnswer", "",
            "gen", 0,
            "updatedAt", A_Now
        )
        n++
    }
    if n > 0 {
        CommandPalette_AgentPersistCards()
        CommandPalette_AgentLog("recover_ok", "n=" . n)
    }
    return n
}

CommandPalette_AgentDefaultProvider() {
    global g_Agent_DefaultProvider
    p := Trim(String(g_Agent_DefaultProvider))
    if (p = "")
        p := "openclaw"
    if FuncExists("CommandPalette_NormalizeAiProvider")
        try return CommandPalette_NormalizeAiProvider(p)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    return p
}

CommandPalette_AgentSanitizeProvider(prov) {
    p := Trim(StrLower(String(prov)))
    if (p = "" || p = "new" || p = "append" || p = "correction")
        return CommandPalette_AgentDefaultProvider()
    if FuncExists("CommandPalette_NormalizeAiProvider")
        try p := CommandPalette_NormalizeAiProvider(p)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    if (p = "" || p = "new" || p = "append" || p = "correction")
        return CommandPalette_AgentDefaultProvider()
    return p
}

CommandPalette_AgentPushCardNew(card) {
    if !(card is Map)
        return
    dto := CommandPalette_AgentCardToSyncDto(card)
    if FuncExists("CommandPalette_PushToWeb") {
        payload := Map("type", "palette_agent_card_new")
        for k, v in dto
            payload[k] := v
        CommandPalette_PushToWeb(payload)
    }
}

CommandPalette_AgentFlushUi(card) {
    if !(card is Map)
        return
    cid := String(card.Get("cardId", ""))
    rid := String(card.Get("reqId", ""))
    if (cid = "")
        return
    prov := String(card.Get("provider", CommandPalette_AgentDefaultProvider()))
    provLabel := (prov = "hermes") ? "Hermes" : "龙虾 OpenClaw"
    useHub := FuncExists("Nmer_PaletteAgentTransportHubEnabled") && Nmer_PaletteAgentTransportHubEnabled()
    CommandPalette_AgentPushCardNew(card)
    if FuncExists("CommandPalette_PushToWeb") {
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_status",
            "cardId", cid,
            "reqId", rid,
            "message", useHub ? ("经 nmer-hub 连接 " . provLabel . "…") : ("正在连接 " . provLabel . "…"),
            "status", "loading"
        ))
        streamMsg := useHub
            ? ("🔗 任务已提交，经 nmer-hub 连接 " . provLabel . "…")
            : ("🔗 任务已提交，正在拉起 " . provLabel . "…")
        CommandPalette_AgentPushStreamStatus(cid, rid, streamMsg)
    }
}

CommandPalette_AgentRegisterAiRoute(reqId, cardId, gen) {
    global g_Agent_AiRoute
    rid := Trim(String(reqId))
    cid := Trim(String(cardId))
    if (rid = "" || cid = "")
        return
    g_Agent_AiRoute[rid] := Map("cardId", cid, "gen", Integer(gen))
}

CommandPalette_AgentClearAiRoute(reqId) {
    global g_Agent_AiRoute
    rid := Trim(String(reqId))
    if (rid != "" && g_Agent_AiRoute.Has(rid))
        g_Agent_AiRoute.Delete(rid)
}

CommandPalette_AgentForwardAiEvent(kind, msg) {
    global g_Agent_AiRoute, g_Agent_Cards
    if !(msg is Map) || !(g_Agent_AiRoute is Map)
        return
    reqId := msg.Has("reqId") ? Trim(String(msg["reqId"])) : ""
    if (reqId = "" || !g_Agent_AiRoute.Has(reqId))
        return
    route := g_Agent_AiRoute[reqId]
    if !(route is Map)
        return
    cardId := String(route.Get("cardId", ""))
    card := CommandPalette_AgentGetCard(cardId)
    if !(card is Map) || Integer(card.Get("gen", 0)) != Integer(route.Get("gen", 0))
        return
    kind := StrLower(String(kind))
    if (kind = "chunk") {
        delta := msg.Has("delta") ? String(msg["delta"]) : (msg.Has("text") ? String(msg["text"]) : "")
        if FuncExists("CommandPalette_AgentDebugTrace")
            try CommandPalette_AgentDebugTrace("ftb", "forward_chunk", "req=" . reqId . " Δ=" . SubStr(delta, 1, 48))
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        if (delta != "")
            CommandPalette_OnNiumaPaletteAgentChunk(Map("reqId", reqId, "cardId", cardId, "delta", delta))
    } else if (kind = "end") {
        ans := msg.Has("answer") ? String(msg["answer"]) : ""
        if FuncExists("CommandPalette_AgentDebugTrace")
            try CommandPalette_AgentDebugTrace("ftb", "forward_end", "req=" . reqId . " len=" . StrLen(ans))
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        if CommandPalette_AgentAnswerIsSubstantial(ans)
            CommandPalette_OnNiumaPaletteAgentEnd(Map("reqId", reqId, "cardId", cardId, "answer", ans))
        CommandPalette_AgentClearAiRoute(reqId)
    } else if (kind = "error") {
        err := msg.Has("message") ? String(msg["message"]) : (msg.Has("error") ? String(msg["error"]) : "代理请求失败")
        CommandPalette_OnNiumaPaletteAgentError(Map("reqId", reqId, "cardId", cardId, "message", err))
        CommandPalette_AgentClearAiRoute(reqId)
    }
}

CommandPalette_AgentCardCount() {
    global g_Agent_Cards
    return IsObject(g_Agent_Cards) ? g_Agent_Cards.Count : 0
}

CommandPalette_AgentPullCardsJson() {
    global g_Agent_Cards
    try {
        if g_Agent_Cards.Count < 1
            CommandPalette_AgentLoadCards()
        if FuncExists("CommandPalette_AgentShadowBuildCards") && FuncExists("Nmer_PaletteStateStoreEnabled") && Nmer_PaletteStateStoreEnabled() {
            built := CommandPalette_AgentShadowBuildCards()
            arr := built.Get("cards", [])
            return Jxon_Dump(arr is Array ? arr : [])
        }
        items := []
        for _, c in g_Agent_Cards {
            if !(c is Map)
                continue
            try items.Push(CommandPalette_AgentCardToPushDto(c))
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        }
        return Jxon_Dump(items)
    } catch {
        return "[]"
    }
}

CommandPalette_AgentPushCardSync() {
    global g_Agent_Cards, g_Agent_CardLimit
    if g_Agent_Cards.Count < 1
        CommandPalette_AgentLoadCards(true)
    CommandPalette_AgentPruneCards()
    useSummary := FuncExists("Nmer_PaletteStateStoreEnabled") && Nmer_PaletteStateStoreEnabled()
    sorted := []
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
    maxPush := useSummary ? g_Agent_CardLimit : sorted.Length
    items := []
    Loop Min(maxPush, sorted.Length) {
        c := sorted[A_Index]
        if (c is Map)
            items.Push(CommandPalette_AgentCardToPushDto(c))
    }
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map("type", "palette_agent_card_sync", "cards", items, "summary", useSummary))
    if FuncExists("CommandPalette_AgentQueueShadowWrite")
        try CommandPalette_AgentQueueShadowWrite()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
}

CommandPalette_AgentPushCardDetail(cardId) {
    cid := Trim(String(cardId))
    if (cid = "")
        return false
    card := CommandPalette_AgentGetCard(cid)
    if !(card is Map)
        return false
    dto := CommandPalette_AgentCardToSyncDto(card)
    if FuncExists("CommandPalette_AgentShadowWriteDetail")
        try CommandPalette_AgentShadowWriteDetail(cid, dto)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    if FuncExists("CommandPalette_PushToWeb")
        return CommandPalette_PushToWeb(Map("type", "palette_agent_card_detail", "card", dto))
    return false
}

CommandPalette_AgentSaveBlockStore(msg) {
    global g_Agent_Cards
    if !(msg is Map)
        return false
    cid := Trim(String(msg.Get("cardId", "")))
    if (cid = "" || !IsObject(g_Agent_Cards) || !g_Agent_Cards.Has(cid))
        return false
    card := g_Agent_Cards[cid]
    if !(card is Map)
        return false
    store := 0
    if msg.Has("blockStore") && msg["blockStore"] is Map
        store := msg["blockStore"]
    else if msg.Has("blocks") && msg["blocks"] is Array {
        store := Map(
            "blocks", msg["blocks"],
            "blockVersion", msg.Has("blockVersion") ? Integer(msg["blockVersion"]) : 1,
            "normalizerVersion", msg.Has("normalizerVersion") ? String(msg["normalizerVersion"]) : "2026-06-06"
        )
    }
    if !(store is Map)
        return false
    card["blockStore"] := store
    if msg.Has("protocolClosure") && msg["protocolClosure"] is Map
        card["protocolClosure"] := msg["protocolClosure"]
    n := 0
    if store.Has("blocks") && store["blocks"] is Array
        n := store["blocks"].Length
    CommandPalette_AgentSchedulePersist()
    if FuncExists("CommandPalette_AgentDebugTrace") {
        try CommandPalette_AgentDebugTrace("ahk", "block_store_persist", "card=" . cid . " n=" . n, "info")
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    return true
}

CommandPalette_AgentSubmit(msg) {
    global g_Agent_Cards, g_CardSessionMap, g_Agent_ActiveCardId, g_Agent_CancelToken, g_Agent_StreamGen
    global g_Agent_LastSubmitSig, g_Agent_LastSubmitCardId, g_Agent_LastSubmitTick
    g_Agent_CancelToken := false
    text := msg.Has("text") ? Trim(String(msg["text"])) : (msg.Has("query") ? Trim(String(msg["query"])) : "")
    if (text = "")
        return Map("ok", false, "error", "empty_text")
    kind := msg.Has("kind") ? StrLower(String(msg["kind"])) : "new"
    sig := kind . "|" . text
    if (sig = g_Agent_LastSubmitSig && (A_TickCount - g_Agent_LastSubmitTick) < 1500) {
        if (g_Agent_LastSubmitCardId != "" && IsObject(g_Agent_Cards) && g_Agent_Cards.Has(g_Agent_LastSubmitCardId)) {
            c0 := g_Agent_Cards[g_Agent_LastSubmitCardId]
            if FuncExists("CommandPalette_AgentDebugTrace")
                try CommandPalette_AgentDebugTrace("ahk", "submit_dedupe", "card=" . g_Agent_LastSubmitCardId, "info")
                catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
            return Map(
                "ok", true,
                "cardId", g_Agent_LastSubmitCardId,
                "reqId", String(c0.Get("reqId", "")),
                "provider", String(c0.Get("provider", "")),
                "title", String(c0.Get("title", text)),
                "query", String(c0.Get("query", text))
            )
        }
    }
    CommandPalette_AgentWireLog("submit_enter", "kind=" . kind . " text=" . SubStr(text, 1, 60))
    try CommandPalette_AgentDebugTrace("ahk", "submit_enter", "kind=" . kind . " text=" . SubStr(text, 1, 40), "info")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    routeDecision := CommandPalette_AgentResolveOfficialRoute(text)
    try CommandPalette_AgentDebugTrace(
        "route",
        "official_a2ui_gray",
        "route=" . String(routeDecision.Get("route", "r1r2"))
            . " reason=" . String(routeDecision.Get("reason", ""))
            . " cmd=" . String(routeDecision.Get("command", "")),
        String(routeDecision.Get("route", "")) = "r3" ? "info" : "debug"
    )
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    cardId := msg.Has("cardId") ? Trim(String(msg["cardId"])) : ""
    prov := CommandPalette_AgentSanitizeProvider(msg.Has("provider") ? msg["provider"] : "")
    routeId := msg.Has("routeId") ? Trim(String(msg["routeId"])) : ""
    routeLabel := msg.Has("routeLabel") ? Trim(String(msg["routeLabel"])) : ""
    promptAddon := msg.Has("promptAddon") ? Trim(String(msg["promptAddon"])) : ""
    routeConfidence := msg.Has("routeConfidence") ? String(msg["routeConfidence"]) : ""
    if (routeId != "") {
        try CommandPalette_AgentDebugTrace("route", "pipeline_route", "id=" . routeId . " conf=" . routeConfidence, "info")
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }

    if (kind = "correction" || kind = "append") {
        if (cardId = "")
            cardId := g_Agent_ActiveCardId
        card := CommandPalette_AgentGetCard(cardId)
        if !(card is Map) {
            kind := "new"
            cardId := ""
        } else {
            card["ended"] := false
            card["running"] := true
            card["uiState"] := (kind = "append") ? "Planning" : "Running"
            card["updatedAt"] := A_Now
            card["priorRawAnswer"] := String(card.Get("rawAnswer", ""))
            card["activeQuery"] := text
            card["rawAnswer"] := ""
            card["liveThought"] := (kind = "append") ? "已收到补充，继续执行…" : "已收到修正，继续执行…"
            g_Agent_ActiveCardId := cardId
            CommandPalette_AgentCancelPriorStreamForCard(cardId)
            g_Agent_StreamGen++
            gen := g_Agent_StreamGen
            reqId := CommandPalette_AgentNewId("cpag")
            card["reqId"] := reqId
            if FuncExists("CommandPalette_DeliverFtbPayload") {
                try CommandPalette_DeliverFtbPayload(Map("type", "palette_agent_prepare_new", "cardId", cardId, "reqId", reqId))
                catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
            }
            card["gen"] := gen
            msgs := card.Has("messages") && card["messages"] is Array ? card["messages"] : []
            msgs.Push(Map("role", "user", "text", text, "at", A_Now))
            card["messages"] := msgs
            if (routeId != "") {
                card["routeId"] := routeId
                card["routeLabel"] := routeLabel
                card["promptAddon"] := promptAddon
                card["routeConfidence"] := routeConfidence
            }
            CommandPalette_AgentApplyOfficialRoute(card, routeDecision)
            CommandPalette_AgentSchedulePersist()
            CommandPalette_AgentPushCardNew(card)
            CommandPalette_AgentPushCardSync()
            CommandPalette_AgentArmHeartbeat(cardId)
            CommandPalette_AgentRegisterAiRoute(reqId, cardId, gen)
            CommandPalette_AgentFlushUi(card)
            CommandPalette_AgentScheduleDispatch(cardId, reqId, text, prov, gen, 0)
            g_Agent_LastSubmitSig := sig
            g_Agent_LastSubmitCardId := cardId
            g_Agent_LastSubmitTick := A_TickCount
            ret := Map("ok", true, "cardId", cardId, "reqId", reqId, "provider", prov, "title", String(card.Get("title", text)))
            try CommandPalette_AgentDebugNoteSubmit(cardId, reqId, prov, "post")
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
            return ret
        }
    }

    CommandPalette_AgentWarmFtbHost("agent_submit")
    if !(FuncExists("Nmer_PaletteAgentTransportHubEnabled") && Nmer_PaletteAgentTransportHubEnabled()) {
        if FuncExists("CommandPalette_BootstrapNiumaChat")
            try CommandPalette_BootstrapNiumaChat("agent_submit", false)
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
    }
    g_Agent_StreamGen++
    gen := g_Agent_StreamGen
    cardId := CommandPalette_AgentNewId("card")
    CommandPalette_AgentCancelOtherStreams(cardId)
    reqId := CommandPalette_AgentNewId("cpag")
    paletteSr := CommandPalette_AgentPaletteSessionKey(cardId)
    title := SubStr(text, 1, 48)
    if (StrLen(text) > 48)
        title .= "…"
    card := Map(
        "cardId", cardId,
        "reqId", reqId,
        "uiState", "Planning",
        "title", title,
        "query", text,
        "provider", prov,
        "sessionRef", paletteSr,
        "ended", false,
        "running", true,
        "error", "",
        "rawAnswer", "",
        "liveThought", "🔗 已提交，正在连接 " . ((prov = "hermes") ? "Hermes" : "OpenClaw") . "…",
        "gen", gen,
        "messages", [Map("role", "user", "text", text, "at", A_Now)],
        "routeId", routeId,
        "routeLabel", routeLabel,
        "promptAddon", promptAddon,
        "routeConfidence", routeConfidence,
        "updatedAt", A_Now,
        "createdAt", A_Now
    )
    CommandPalette_AgentApplyOfficialRoute(card, routeDecision)
    g_Agent_Cards[cardId] := card
    g_CardSessionMap[cardId] := paletteSr
    g_Agent_ActiveCardId := cardId
    g_Agent_LastSubmitSig := sig
    g_Agent_LastSubmitCardId := cardId
    g_Agent_LastSubmitTick := A_TickCount
    CommandPalette_AgentSchedulePersist()
    CommandPalette_AgentRegisterAiRoute(reqId, cardId, gen)
    CommandPalette_AgentFlushUi(card)
    CommandPalette_AgentPushCardSync()
    CommandPalette_AgentArmHeartbeat(cardId)
    CommandPalette_AgentScheduleDispatch(cardId, reqId, text, prov, gen, 0)
    ret := Map("ok", true, "cardId", cardId, "reqId", reqId, "provider", prov, "title", title, "query", text)
    try CommandPalette_AgentDebugNoteSubmit(cardId, reqId, prov, "post")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return ret
}

CommandPalette_AgentIsStatusOnlyDelta(delta) {
    d := Trim(String(delta))
    if (d = "")
        return true
    if RegExMatch(d, "i)^(🔗|⏳|💭|📨|正在|等待|仍连接|同步|引擎|Niuma)")
        return true
    if RegExMatch(d, "i)^(正在连接|正在准备|正在请求|OpenClaw 流式|OpenClaw 处理|OpenClaw 已发送|流式输出中|已提交至 Gateway)")
        return true
    if RegExMatch(d, "i)chat\.send")
        return true
    return false
}

CommandPalette_AgentAnswerHasStructure(raw) {
    raw := Trim(String(raw))
    if (raw = "")
        return false
    if RegExMatch(raw, "m)^\d")
        return true
    if RegExMatch(raw, "m)^[-*•]")
        return true
    if RegExMatch(raw, "m)^\*\*")
        return true
    if RegExMatch(raw, "m)^#")
        return true
    if RegExMatch(raw, "m)^##")
        return true
    if RegExMatch(raw, "m)^###")
        return true
    return false
}

CommandPalette_AgentLooksLikeThinkingPreamble(ans) {
    raw := Trim(String(ans))
    if (raw = "")
        return false
    if CommandPalette_AgentAnswerHasStructure(raw)
        return false
    if (StrLen(raw) >= 400)
        return false
    if RegExMatch(raw, "\|") && RegExMatch(raw, "---")
        return false
    if RegExMatch(raw, "i)(让我先|我先想|我先查|让我查|我来搜|我来查|我去查|比较靠谱|想想到底|查一下|搜一下|给你做|给你个|我直接基于|let me (check|think|search)|i('ll| will) (check|search|look))")
        return StrLen(raw) < 320
    return false
}

CommandPalette_AgentAnswerIsSubstantial(ans) {
    raw := Trim(String(ans))
    if (raw = "")
        return false
    if RegExMatch(raw, "i)::(PLAN|STATUS|QUESTION|REPLY)_(START|END)::")
        return true
    if CommandPalette_AgentIsStatusOnlyDelta(raw)
        return false
    if CommandPalette_AgentLooksLikeThinkingPreamble(raw)
        return false
    if (StrLen(raw) < 8)
        return false
    return true
}

CommandPalette_AgentResolveCardQuery(card) {
    if !(card is Map)
        return ""
    aq := Trim(String(card.Get("activeQuery", "")))
    if (aq != "")
        return aq
    return Trim(String(card.Get("query", "")))
}

CommandPalette_AgentFetchAnswerLooksStaleForCard(card, ans) {
    if !(card is Map)
        return false
    prior := Trim(String(card.Get("priorRawAnswer", "")))
    ansT := Trim(String(ans))
    if (prior = "" || ansT = "")
        return false
    if (ansT = prior)
        return true
    if (InStr(prior, ansT) = 1 && StrLen(ansT) < StrLen(prior))
        return true
    if (InStr(prior, ansT) = 1 && StrLen(ansT) <= StrLen(prior) * 0.98)
        return true
    if RegExMatch(prior, "\|") && RegExMatch(prior, "---") && RegExMatch(ansT, "\|") && RegExMatch(ansT, "---") {
        hdrLen := Min(80, StrLen(ansT))
        if (hdrLen >= 24 && InStr(prior, SubStr(ansT, 1, hdrLen)) = 1 && StrLen(ansT) <= StrLen(prior))
            return true
    }
    return false
}

CommandPalette_AgentCompareAnswerLooksTruncated(ans) {
    raw := Trim(String(ans))
    if (raw = "" || !RegExMatch(raw, "\|") || !RegExMatch(raw, "---"))
        return false
    if RegExMatch(raw, "i)(怎么选|个人建议|结论|推荐|总结|建议继续)")
        return false
    if (StrLen(raw) >= 1400)
        return false
    if RegExMatch(raw, "i)(对比|vs )") && RegExMatch(raw, "m)^[^\r\n]*\|[^\r\n]*\|[^\r\n]*$")
        return true
    return false
}

CommandPalette_AgentHasSubstantialAnswer(card) {
    if !(card is Map)
        return false
    return CommandPalette_AgentAnswerIsSubstantial(String(card.Get("rawAnswer", "")))
}

CommandPalette_AgentAnswerTextLooksIncomplete(ans) {
    raw := Trim(String(ans))
    if (raw = "")
        return true
    if CommandPalette_AgentLooksLikeThinkingPreamble(raw)
        return true
    if CommandPalette_AgentCompareAnswerLooksTruncated(raw)
        return true
    if RegExMatch(raw, "\|") && RegExMatch(raw, "---")
        return false
    if (StrLen(raw) >= 900)
        return false
    if CommandPalette_AgentAnswerHasStructure(raw) && StrLen(raw) >= 400
        return false
    if (StrLen(raw) >= 1200)
        return false
    if !RegExMatch(raw, "\|") && StrLen(raw) < 480 {
        if RegExMatch(raw, "i)(对比|策略|vs |research|华为|小米|meta|蔚来|yu7|es9|ray-ban|眼镜)")
            return true
    }
    return false
}

CommandPalette_AgentAnswerLooksIncomplete(card) {
    if !(card is Map)
        return true
    return CommandPalette_AgentAnswerTextLooksIncomplete(String(card.Get("rawAnswer", "")))
}

CommandPalette_AgentTagFtbSession(reqId, cardId, query, provider) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return false
    if !FuncExists("CommandPalette_JsEscapeForParse")
        return false
    argsJson := "{}"
    try argsJson := Jxon_Dump(Map(
        "reqId", String(reqId),
        "cardId", String(cardId),
        "query", String(query),
        "provider", String(provider)
    ))
    catch {
        return false
    }
    escaped := CommandPalette_JsEscapeForParse(argsJson)
    js := "(function(){try{var o=JSON.parse('" . escaped . "');"
        . "var s=typeof activeSession==='function'?activeSession():null;"
        . "var p=String(o.provider||'').trim();"
        . "if(p&&typeof switchToNode==='function'){try{var g=typeof findNodeGroup==='function'?findNodeGroup(p):null;"
        . "if(g&&g.sessions&&g.sessions.length)switchToNode(p);"
        . "else if(typeof createSessionWithProvider==='function'&&typeof P!=='undefined'&&P[p])createSessionWithProvider(p);}catch(_){}}"
        . "s=typeof activeSession==='function'?activeSession():s;"
        . "if(!s)return JSON.stringify({ok:0});"
        . "s._paletteAgentReqId=String(o.reqId||'');s._paletteReqId=String(o.reqId||'');"
        . "s._paletteAgentCardId=String(o.cardId||'');s._paletteAgentQuery=String(o.query||'');"
        . "if(typeof saveCfg==='function')saveCfg(false);"
        . "return JSON.stringify({ok:1,sid:s.id||''});"
        . "}catch(e){return JSON.stringify({ok:0,err:String(e&&e.message||e)});}})();"
    try {
        g_FTB_WV2.ExecuteScriptAsync(js)
        return true
    } catch {
        return false
    }
}

CommandPalette_AgentPaletteSessionKey(cardId) {
    return CommandPalette_AgentPaletteSessionKeyForTransport(cardId, "ftb")
}

CommandPalette_AgentPaletteAdapterSessionKey(cardId) {
    return CommandPalette_AgentPaletteSessionKeyForTransport(cardId, "adapter")
}

CommandPalette_AgentPaletteSessionKeyForTransport(cardId, transport := "ftb") {
    slug := RegExReplace(String(cardId), "i)^card[-_]?", "")
    slug := RegExReplace(slug, "[^a-zA-Z0-9_-]", "-")
    slug := Trim(slug, "-")
    if (slug = "")
        slug := "task"
    if StrLen(slug) > 40
        slug := SubStr(slug, 1, 40)
    ns := (StrLower(Trim(String(transport))) = "adapter") ? "niuma-adp" : "niuma-cp"
    return "agent:main:" . ns . "-" . slug
}

CommandPalette_AgentLockAgentTransport(cardId, transport) {
    card := CommandPalette_AgentGetCard(cardId)
    if !(card is Map)
        return
    t := StrLower(Trim(String(transport)))
    if (t != "ftb" && t != "adapter")
        t := "ftb"
    card["agentTransport"] := t
}

CommandPalette_AgentHubTransportStrict(*) {
    return FuncExists("Nmer_PaletteAgentTransportHubEnabled") && Nmer_PaletteAgentTransportHubEnabled()
}

CommandPalette_AgentWarmFtbHost(reason := "") {
    if CommandPalette_AgentHubTransportStrict()
        return false
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, FloatingToolbarGUI
    if FuncExists("Nmer_WailsBridgeEnsureOpenClawHubEnv")
        try Nmer_WailsBridgeEnsureOpenClawHubEnv()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    if FuncExists("FloatingToolbarWails_EnsureHybridBridge")
        try FloatingToolbarWails_EnsureHybridBridge()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    if FuncExists("FloatingToolbarWails_RegisterExternalFtb")
        try FloatingToolbarWails_RegisterExternalFtb("agent_warm_" . Trim(String(reason)))
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    if FuncExists("StartWebViewWarmup")
        try StartWebViewWarmup()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady) {
        if (FloatingToolbarGUI = 0) && FuncExists("CreateFloatingToolbarGUI")
            try CreateFloatingToolbarGUI()
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        if !IsObject(g_FTB_WV2) && FuncExists("FloatingToolbar_RetryCreateWebView")
            try FloatingToolbar_RetryCreateWebView()
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
    }
    return IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady
}

CommandPalette_AgentFallbackToFtb(cardId, reqId, query, provider, statusMsg := "") {
    if CommandPalette_AgentHubTransportStrict()
        return false
    cid := Trim(String(cardId))
    rid := Trim(String(reqId))
    q := Trim(String(query))
    if (cid = "" || rid = "" || q = "")
        return false
    prov := CommandPalette_AgentSanitizeProvider(provider)
    card := CommandPalette_AgentGetCard(cid)
    CommandPalette_AgentLockAgentTransport(cid, "ftb")
    if (card is Map) {
        card["agentTransport"] := "ftb"
        card["streamDispatched"] := false
        card["officialA2uiPending"] := false
        sr := CommandPalette_AgentPaletteSessionKey(cid)
        card["sessionRef"] := sr
    }
    msg := Trim(String(statusMsg))
    if (msg != "")
        CommandPalette_AgentPushStreamStatus(cid, rid, msg)
    CommandPalette_AgentWarmFtbHost("ftb_fallback")
    if FuncExists("FloatingToolbarWails_EnsureShellForAgent")
        try FloatingToolbarWails_EnsureShellForAgent(false)
    sr := CommandPalette_AgentPaletteSessionKey(cid)
    sysPrompt := CommandPalette_AgentBuildSystemPrompt(card)
    agentPayload := Map(
        "type", "host_palette_agent_stream",
        "reqId", rid,
        "cardId", cid,
        "query", q,
        "provider", prov,
        "systemPrompt", sysPrompt,
        "sessionRef", sr,
        "openDrawer", false
    )
    streamOk := CommandPalette_AgentDeliverStreamPayload(agentPayload)
    scriptOk := false
    if !streamOk && FuncExists("FloatingToolbar_StartPaletteAgentStream") {
        try streamOk := !!FloatingToolbar_StartPaletteAgentStream(agentPayload)
        catch {
            streamOk := false
        }
    }
    if !streamOk {
        try scriptOk := CommandPalette_InvokeFtbPaletteAgentScript(cid, rid, q, prov, sr)
        catch {
            scriptOk := false
        }
    }
    if (streamOk || scriptOk) {
        CommandPalette_AgentMarkStreamDispatched(cid, false)
        CommandPalette_AgentPushStreamStatus(cid, rid, "📡 已改走 Niuma Chat 直连 OpenClaw…")
        CommandPalette_AgentWireLog("dispatch_ftb_fallback", "card=" . cid . " req=" . rid . " agent=" . (streamOk ? 1 : 0) . " script=" . (scriptOk ? 1 : 0))
        return true
    }
    CommandPalette_AgentWireLog("dispatch_ftb_fallback_fail", "card=" . cid . " req=" . rid)
    return false
}

CommandPalette_AgentPostOpenClawAdapter(cardId, reqId, query, sessionRef, systemPrompt := "") {
    if !FuncExists("Nmer_WailsBridgeOpenClawAdapterUrl")
        return Map("ok", false, "code", "ADAPTER_URL_MISSING")
    if FuncExists("Nmer_WailsBridge_ShouldAvoidSyncWinHttp") && Nmer_WailsBridge_ShouldAvoidSyncWinHttp()
        return Map("ok", false, "code", "ADAPTER_DEFER_WINHTTP", "detail", "webview_busy")
    if FuncExists("Nmer_WailsBridgeEnsureOpenClawHubEnv") {
        envSync := Nmer_WailsBridgeEnsureOpenClawHubEnv()
        if !(envSync is Map) || !envSync.Get("ok", false) {
            code := (envSync is Map) ? String(envSync.Get("code", "TOKEN_MISSING")) : "TOKEN_MISSING"
            return Map("ok", false, "code", "OPENCLAW_CONFIG_MISSING", "detail", code)
        }
    }
    url := Nmer_WailsBridgeOpenClawAdapterUrl()
    body := ""
    try {
        payload := Map(
            "cardId", String(cardId),
            "requestId", String(reqId),
            "query", String(query),
            "sessionRef", String(sessionRef),
            "transportNamespace", "niuma-adp"
        )
        sys := Trim(String(systemPrompt))
        if (sys != "")
            payload["systemPrompt"] := sys
        body := Jxon_Dump(payload)
    } catch {
        return Map("ok", false, "code", "ADAPTER_BODY_FAIL")
    }
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        if FuncExists("NiumaOllama_IsLoopbackUrl") && NiumaOllama_IsLoopbackUrl(url)
            try whr.SetProxy(1)
        whr.Open("POST", url, false)
        whr.SetTimeouts(5000, 5000, 120000, 120000)
        whr.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
        whr.Send(body)
        status := Integer(whr.Status)
        raw := Trim(String(whr.ResponseText))
        data := Map()
        if (raw != "" && FuncExists("CommandPalette_ParseScriptJson"))
            data := CommandPalette_ParseScriptJson(raw)
        ok := (status = 200) && (data is Map) && !!data.Get("ok", false)
        return Map(
            "ok", ok,
            "code", (data is Map) ? String(data.Get("code", "ADAPTER_HTTP_" . status)) : ("ADAPTER_HTTP_" . status),
            "status", status,
            "surfaceId", (data is Map) ? String(data.Get("surfaceId", "")) : "",
            "accepted", (data is Map) ? Integer(data.Get("accepted", 0)) : 0,
            "answer", (data is Map) ? String(data.Get("answer", "")) : "",
            "requestId", (data is Map) ? String(data.Get("requestId", "")) : "",
            "detail", SubStr(raw, 1, 400)
        )
    } catch as err {
        return Map("ok", false, "code", "ADAPTER_HTTP_ERR", "detail", SubStr(String(err.Message), 1, 200))
    }
}

CommandPalette_AgentRunOpenClawAdapterAsync(cardId, reqId, query, sessionRef) {
    cid := Trim(String(cardId))
    rid := Trim(String(reqId))
    card := CommandPalette_AgentGetCard(cid)
    isR3 := CommandPalette_AgentCardIsOfficialA2uiRoute(card)
    sysPrompt := isR3 ? "" : CommandPalette_AgentBuildSystemPrompt(card)
    if FuncExists("Nmer_WailsBridge_ShouldAvoidSyncWinHttp") && Nmer_WailsBridge_ShouldAvoidSyncWinHttp() {
        SetTimer(CommandPalette_AgentRunOpenClawAdapterAsync.Bind(cardId, reqId, query, sessionRef), -180)
        return
    }
    result := CommandPalette_AgentPostOpenClawAdapter(cardId, reqId, query, sessionRef, sysPrompt)
    if (result is Map) && result.Get("ok", false) {
        ans := Trim(String(result.Get("answer", "")))
        surfaceId := Trim(String(result.Get("surfaceId", "")))
        CommandPalette_AgentLog("adapter_ok", "card=" . cid . " r3=" . (isR3 ? 1 : 0) . " accepted=" . Integer(result.Get("accepted", 0)) . " ansLen=" . StrLen(ans))
        try CommandPalette_AgentDebugTrace("adapter", "ingest_ok", "card=" . cid . " r3=" . (isR3 ? 1 : 0) . " surface=" . surfaceId . " ans=" . StrLen(ans), "info")
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        if (card is Map) {
            card["streamDispatched"] := true
            card["agentTransport"] := "adapter"
            card["sessionRef"] := String(sessionRef)
        }
        if isR3 {
            if (card is Map) {
                card["officialA2uiPending"] := true
                card["officialA2ui"] := Map("source", "live", "enabled", true, "surfaceId", surfaceId, "command", Trim(String(card.Get("slashCommand", ""))))
            }
            CommandPalette_AgentPushStreamStatus(cid, rid, "✅ 官方 A2UI 已投递，等待 Surface 渲染…")
            CommandPalette_AgentMarkOfficialA2uiPending(cid, rid)
            return
        }
        if (ans != "" && CommandPalette_AgentAnswerIsSubstantial(ans)) {
            CommandPalette_AgentPushStreamStatus(cid, rid, "✅ hub 通道已完成回复")
            CommandPalette_OnNiumaPaletteAgentEnd(Map("reqId", rid, "cardId", cid, "answer", ans, "sessionRef", String(sessionRef)))
            return
        }
        CommandPalette_AgentPushStreamStatus(cid, rid, "✅ OpenClaw Adapter 已写入官方 A2UI Surface")
        CommandPalette_AgentMarkStreamDispatched(cid, false)
        return
    }
    code := (result is Map) ? String(result.Get("code", "ADAPTER_FAIL")) : "ADAPTER_FAIL"
    CommandPalette_AgentLog("adapter_fail", "card=" . cid . " code=" . code)
    try CommandPalette_AgentDebugTrace("adapter", "ingest_fail", "card=" . cid . " code=" . code, "warn")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    prov := "openclaw"
    if (card is Map)
        prov := CommandPalette_AgentSanitizeProvider(String(card.Get("provider", "openclaw")))
    retryable := (code = "OPENCLAW_CONFIG_MISSING" || code = "TOKEN_MISSING"
        || code = "OPENCLAW_CHAT_FAILED" || code = "ADAPTER_HTTP_502" || code = "ADAPTER_DEFER_WINHTTP"
        || InStr(code, "ADAPTER_HTTP_") = 1)
    if retryable && FuncExists("Nmer_WailsBridgeEnsureOpenClawHubEnv") {
        try {
            env := Nmer_WailsBridgeEnsureOpenClawHubEnv()
            if (env is Map) && env.Get("ok", false) {
                result2 := CommandPalette_AgentPostOpenClawAdapter(cardId, reqId, query, sessionRef, sysPrompt)
                if (result2 is Map) && result2.Get("ok", false) {
                    ans2 := Trim(String(result2.Get("answer", "")))
                    if (ans2 != "" && CommandPalette_AgentAnswerIsSubstantial(ans2)) {
                        CommandPalette_AgentPushStreamStatus(cid, rid, "✅ hub 通道已完成回复")
                        CommandPalette_OnNiumaPaletteAgentEnd(Map("reqId", rid, "cardId", cid, "answer", ans2, "sessionRef", String(sessionRef)))
                        return
                    }
                    if (card is Map) {
                        card["streamDispatched"] := true
                        card["agentTransport"] := "adapter"
                    }
                    CommandPalette_AgentMarkStreamDispatched(cid, false)
                    return
                }
                if (result2 is Map)
                    code := String(result2.Get("code", code))
            }
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    ftbMsg := "⚠ hub Adapter 失败（" . code . "），改走 Niuma Chat…"
    if !CommandPalette_AgentHubTransportStrict() && CommandPalette_AgentFallbackToFtb(cid, rid, query, prov, ftbMsg)
        return
    if (code = "OPENCLAW_CONFIG_MISSING" || code = "TOKEN_MISSING") {
        CommandPalette_AgentPushError(rid, cid, "OpenClaw Gateway Token 未配置：请在 Niuma Chat 设置里对「龙虾」点「一键连接」后重载牛马")
        return
    }
    detail := (result is Map) ? SubStr(String(result.Get("detail", "")), 1, 160) : ""
    if CommandPalette_AgentHubTransportStrict() {
        CommandPalette_AgentPushError(rid, cid, "OpenClaw hub 派发失败：" . code . (detail != "" ? (" · " . detail) : ""))
        return
    }
    CommandPalette_AgentPushError(rid, cid, "OpenClaw 派发失败：" . code . (detail != "" ? (" · " . detail) : "") . "（Niuma Chat 通路也未就绪，请打开悬浮栏）")
}

CommandPalette_AgentDispatchViaOpenClawAdapter(cardId, reqId, query, sessionRef) {
    SetTimer(CommandPalette_AgentRunOpenClawAdapterAsync.Bind(
        cardId, reqId, query, sessionRef
    ), -1)
    return true
}

CommandPalette_AgentTryDispatchHubFallback(cardId, reqId, query, prov, sessionRef, statusMsg := "") {
    prov0 := Trim(String(prov))
    if (prov0 != "openclaw" && prov0 != "hermes")
        return false
    if !FuncExists("Nmer_WailsBridgeHealthy") || !Nmer_WailsBridgeHealthy()
        return false
    cid := Trim(String(cardId))
    rid := Trim(String(reqId))
    q := Trim(String(query))
    if (cid = "" || rid = "" || q = "")
        return false
    card := CommandPalette_AgentGetCard(cid)
    hubSr := Trim(String(sessionRef))
    if (hubSr = "" || InStr(hubSr, "niuma-cp-"))
        hubSr := CommandPalette_AgentPaletteSessionKeyForTransport(cid, "adapter")
    if (hubSr = "")
        return false
    if !CommandPalette_AgentDispatchViaOpenClawAdapter(cid, rid, q, hubSr)
        return false
    if (card is Map) {
        card["sessionRef"] := hubSr
        card["agentTransport"] := "adapter"
    }
    CommandPalette_AgentMarkStreamDispatched(cid, false)
    msg := Trim(String(statusMsg))
    if (msg = "")
        msg := "🔌 hub 通道（OpenClaw Adapter）…"
    CommandPalette_AgentPushStreamStatus(cid, rid, msg)
    return true
}

CommandPalette_AgentResolveAgentTransport(cardId, query := "") {
    flagT := "auto"
    if FuncExists("Nmer_PaletteAgentTransport")
        flagT := Nmer_PaletteAgentTransport()
    if (flagT = "ftb")
        return "ftb"
    if (flagT = "hub")
        return "adapter"
    card := CommandPalette_AgentGetCard(cardId)
    if (card is Map) {
        locked := StrLower(Trim(String(card.Get("agentTransport", ""))))
        if (locked = "ftb" || locked = "adapter")
            return locked
        if card.Get("streamDispatched", false)
            return "ftb"
        sr := Trim(String(card.Get("sessionRef", "")))
        if (sr != "" && InStr(sr, "niuma-cp-"))
            return "ftb"
    }
    if FuncExists("Nmer_WailsBridgeResolveOfficialRoute") {
        decision := Nmer_WailsBridgeResolveOfficialRoute(query)
        if (decision is Map) && decision.Get("route", "") = "r3" && decision.Get("allowed", false)
            return "adapter"
    }
    if (flagT = "auto") && FuncExists("Nmer_WailsBridgeHealthy") && Nmer_WailsBridgeHealthy()
        return "adapter"
    return "ftb"
}

CommandPalette_AgentResolveSessionRef(cardId) {
    global g_CardSessionMap
    cid := Trim(String(cardId))
    card := CommandPalette_AgentGetCard(cid)
    sr := ""
    if (card is Map)
        sr := Trim(String(card.Get("sessionRef", "")))
    if (sr = "" && IsObject(g_CardSessionMap) && g_CardSessionMap.Has(cid))
        sr := Trim(String(g_CardSessionMap[cid]))
    return sr
}

CommandPalette_AgentPrefetchOpenClawSessionRef(cardId) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_CardSessionMap
    cid := Trim(String(cardId))
    if (cid = "")
        return ""
    card := CommandPalette_AgentGetCard(cid)
    sr := CommandPalette_AgentResolveSessionRef(cardId)
    if (sr != "")
        return sr
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return ""
    if !FuncExists("CommandPalette_JsEscapeForParse")
        return ""
    cidEsc := CommandPalette_JsEscapeForParse(cid)
    js := "(function(){try{var fn=window.exportPaletteOpenClawGatewayKey;"
        . "if(typeof fn!=='function')return JSON.stringify({ok:0});"
        . "return JSON.stringify({ok:1,key:String(fn('','" . cidEsc . "')||'')});"
        . "}catch(e){return JSON.stringify({ok:0});}})();"
    try {
        raw := g_FTB_WV2.ExecuteScriptAsync(js).await(3500)
        data := FuncExists("CommandPalette_ParseScriptJson") ? CommandPalette_ParseScriptJson(raw) : Map()
        if (data is Map) && data.Get("ok", false) {
            sr := Trim(String(data.Get("key", "")))
            if (sr != "" && card is Map) {
                card["sessionRef"] := sr
                if IsObject(g_CardSessionMap)
                    g_CardSessionMap[cid] := sr
            }
        }
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return sr
}

CommandPalette_InvokeFtbPaletteAgentScript(cardId, reqId, query, provider, sessionRef := "") {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    prov := CommandPalette_AgentSanitizeProvider(provider)
    sr := Trim(String(sessionRef))
    if (sr = "")
        sr := CommandPalette_AgentResolveSessionRef(cardId)
    card := CommandPalette_AgentGetCard(cardId)
    sysPrompt := CommandPalette_AgentBuildSystemPrompt(card)
    ftbMode := FuncExists("CommandPalette_FtbTransportMode") ? CommandPalette_FtbTransportMode() : ""
    if (ftbMode = "wails_shell" || ftbMode = "hybrid") {
        if (ftbMode = "wails_shell") && FuncExists("FloatingToolbarWails_EnsureShellForAgent")
            FloatingToolbarWails_EnsureShellForAgent(false)
        if (ftbMode = "hybrid") && FuncExists("FloatingToolbarWails_EnsureHybridBridge")
            FloatingToolbarWails_EnsureHybridBridge()
        if FuncExists("CommandPalette_DeliverFtbPayload") {
            return !!CommandPalette_DeliverFtbPayload(Map(
                "type", "host_palette_agent_stream",
                "reqId", String(reqId),
                "cardId", String(cardId),
                "query", String(query),
                "provider", prov,
                "systemPrompt", sysPrompt,
                "sessionRef", sr,
                "openDrawer", false
            ))
        }
        return false
    }
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return false
    if !FuncExists("CommandPalette_JsEscapeForParse")
        return false
    routeId0 := (card is Map) ? Trim(String(card.Get("routeId", ""))) : ""
    if (routeId0 != "") {
        try CommandPalette_AgentDebugTrace("route", "prompt_inject", "route=" . routeId0 . " len=" . StrLen(sysPrompt), "info")
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    argsJson := "{}"
    try argsJson := Jxon_Dump(Map(
        "reqId", String(reqId),
        "cardId", String(cardId),
        "query", String(query),
        "provider", prov,
        "systemPrompt", sysPrompt,
        "sessionRef", sr
    ))
    catch {
        return false
    }
    escaped := CommandPalette_JsEscapeForParse(argsJson)
    js := "try{var o=JSON.parse('" . escaped . "');"
        . "if(window.runPaletteAgentStream)window.runPaletteAgentStream(o.reqId,o.cardId,o.query,o.provider,o.systemPrompt||'',o.sessionRef||'');"
        . "else if(window.chrome&&window.chrome.webview)window.chrome.webview.postMessage(JSON.stringify({type:'niuma_palette_agent_trace',step:'exec_no_fn',detail:'missing_runPaletteAgentStream'}));"
        . "}catch(e){try{if(window.chrome&&window.chrome.webview)window.chrome.webview.postMessage(JSON.stringify({type:'niuma_palette_agent_trace',step:'exec_script_err',detail:String(e&&e.message||e)}));}catch(_){}}"
    try {
        g_FTB_WV2.ExecuteScriptAsync(js)
        return true
    } catch {
        return false
    }
}

CommandPalette_AgentSendViaCompose(cardId, reqId, query, provider) {
    ; 动作 Tab 必须走 runPaletteAgentStream → reqOpenClaw 直连，禁止改道 Niuma Chat 输入框
    CommandPalette_AgentLog("compose_skip", "card=" . cardId . " reason=agent_uses_stream_only")
    return false
}

CommandPalette_AgentArmHeartbeat(cardId) {
    global g_Agent_Cards
    cid := Trim(String(cardId))
    if (cid = "")
        return
    card := CommandPalette_AgentGetCard(cid)
    if !(card is Map)
        return
    card["heartbeatTick"] := A_TickCount
    SetTimer(CommandPalette_AgentHeartbeatTick.Bind(cid), -10000)
}

CommandPalette_AgentHeartbeatTick(cardId) {
    global g_Agent_Cards
    cid := Trim(String(cardId))
    card := CommandPalette_AgentGetCard(cid)
    if !(card is Map) || card.Get("ended", false) || !card.Get("running", false)
        return
    if Trim(String(card.Get("error", ""))) != ""
        return
    prov := String(card.Get("provider", "openclaw"))
    provLabel := (prov = "hermes") ? "Hermes" : "龙虾 OpenClaw"
    dispatchTick := Integer(card.Get("dispatchTick", 0))
    elapsed := dispatchTick > 0 ? Round((A_TickCount - dispatchTick) / 1000) : 0
    hbMsg := "仍连接 " . provLabel . "，等待模型响应… (" . elapsed . "s)"
    card["liveThought"] := hbMsg
    card["updatedAt"] := A_Now
    if FuncExists("CommandPalette_PushToWeb") {
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_heartbeat",
            "cardId", cid,
            "reqId", String(card.Get("reqId", "")),
            "message", hbMsg,
            "liveThought", hbMsg,
            "status", "loading"
        ))
    }
    SetTimer(CommandPalette_AgentHeartbeatTick.Bind(cid), -10000)
}

CommandPalette_AgentEnsureEngine(*) {
    if FuncExists("Nmer_PaletteAgentTransport") && Nmer_PaletteAgentTransport() = "hub" {
        CommandPalette_AgentWarmFtbHost("ensure_engine")
        if FuncExists("Nmer_WailsBridgeHealthy") && Nmer_WailsBridgeHealthy()
            return true
        return false
    }
    if FuncExists("FloatingToolbarWails_ShouldUseHybrid") && FloatingToolbarWails_ShouldUseHybrid() {
        if FuncExists("FloatingToolbarWails_EnsureHybridBridge")
            try FloatingToolbarWails_EnsureHybridBridge()
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        if FuncExists("PaletteAgent_FtbTransportReady")
            return (PaletteAgent_FtbTransportReady() = "hybrid")
        global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
        return IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady
    }
    if FuncExists("FloatingToolbar_AhkWebViewEnabled") && !FloatingToolbar_AhkWebViewEnabled() {
        if FuncExists("FloatingToolbarWails_EnsureShellForAgent")
            try return !!FloatingToolbarWails_EnsureShellForAgent(false)
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        if FuncExists("PaletteAgent_FtbTransportReady")
            return PaletteAgent_FtbTransportReady() != ""
        return false
    }
    if FuncExists("StartWebViewWarmup")
        try StartWebViewWarmup()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    if FuncExists("CommandPalette_BootstrapNiumaChat")
        try CommandPalette_BootstrapNiumaChat("agent_stream", false)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    if FuncExists("PaletteAgent_FtbTransportReady") {
        tr := PaletteAgent_FtbTransportReady()
        if (tr != "")
            return true
    }
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    return IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady
}

CommandPalette_AgentPushToolEvent(cardId, reqId, tool, phase, text, level := "info") {
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_tool_event",
            "cardId", String(cardId),
            "reqId", String(reqId),
            "tool", String(tool),
            "phase", String(phase),
            "text", String(text),
            "level", String(level),
            "ts", A_TickCount
        ))
}

CommandPalette_AgentTryPushToolEventFromStatus(cardId, reqId, message) {
    msg := Trim(String(message))
    if (msg = "")
        return
    tool := ""
    phase := "progress"
    if InStr(msg, "chat.send")
        tool := "chat.send"
    else if RegExMatch(msg, "i)正在调用工具\s+``([^``]+)``", &m)
        tool := m[1]
    else if RegExMatch(msg, "i)正在调用工具\s+'([^']+)'", &m)
        tool := m[1]
    else if RegExMatch(msg, "i)正在调用工具\s+(\S+)", &m)
        tool := m[1]
    if (tool = "")
        return
    CommandPalette_AgentPushToolEvent(cardId, reqId, tool, phase, msg, "info")
}

CommandPalette_AgentPushStreamStatus(cardId, reqId, message) {
    msg := Trim(String(message))
    if (msg = "")
        return
    card := CommandPalette_AgentGetCard(cardId)
    if (card is Map) {
        card["liveThought"] := msg
        card["updatedAt"] := A_Now
        card["streamDispatched"] := true
        if !card.Get("ended", false) {
            card["running"] := true
            if (card.Get("uiState", "") = "Done")
                card["uiState"] := "Running"
        }
    }
    CommandPalette_AgentTryPushToolEventFromStatus(cardId, reqId, msg)
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_chunk",
            "cardId", String(cardId),
            "reqId", String(reqId),
            "delta", msg . "`n",
            "liveThought", msg
        ))
}

CommandPalette_AgentMarkStreamDispatched(cardId, viaCompose := false) {
    global g_Agent_ShellSendingReqIds
    card := CommandPalette_AgentGetCard(cardId)
    if !(card is Map)
        return
    card["streamDispatched"] := true
    card["dispatchTick"] := A_TickCount
    card["lastChunkTick"] := A_TickCount
    if viaCompose
        card["composeDispatched"] := true
    rid := String(card.Get("reqId", ""))
    if (rid != "") {
        if !IsObject(g_Agent_ShellSendingReqIds)
            g_Agent_ShellSendingReqIds := Map()
        g_Agent_ShellSendingReqIds[rid] := true
    }
    CommandPalette_AgentArmStreamWatchdog(cardId)
    q := CommandPalette_AgentResolveCardQuery(card)
    if (rid != "" && q != "")
        CommandPalette_AgentStartAnswerPoll(cardId, rid, q)
}

CommandPalette_AgentMarkOfficialA2uiPending(cardId, reqId) {
    global g_Agent_ShellSendingReqIds
    card := CommandPalette_AgentGetCard(cardId)
    if !(card is Map)
        return
    card["streamDispatched"] := true
    card["officialA2uiPending"] := true
    rid := Trim(String(reqId))
    if (rid != "") {
        if !IsObject(g_Agent_ShellSendingReqIds)
            g_Agent_ShellSendingReqIds := Map()
        g_Agent_ShellSendingReqIds[rid] := true
    }
    CommandPalette_AgentArmOfficialA2uiWatchdog(cardId, reqId)
}

CommandPalette_AgentArmOfficialA2uiWatchdog(cardId, reqId) {
    SetTimer(CommandPalette_AgentOfficialA2uiWatchdogTick.Bind(cardId, reqId, 0), -120000)
}

CommandPalette_AgentOfficialA2uiWatchdogTick(cardId, reqId, tryN) {
    global g_Agent_CancelToken
    if (g_Agent_CancelToken)
        return
    cid := Trim(String(cardId))
    rid := Trim(String(reqId))
    card := CommandPalette_AgentGetCard(cid)
    if !(card is Map) || card.Get("ended", false) || !card.Get("officialA2uiPending", false)
        return
    if Trim(String(card.Get("reqId", ""))) != rid
        return
    tryN := Integer(tryN)
    if (tryN > 0 && Mod(tryN, 4) = 0)
        CommandPalette_AgentPushStreamStatus(cid, rid, "⏳ 等待官方 A2UI Surface…")
    if (tryN >= 12) {
        card["officialA2uiPending"] := false
        CommandPalette_AgentPushError(rid, cid, "官方 A2UI 渲染超时：请确认 nmer-hub WS 已连接且命令命中 R3 白名单")
        return
    }
    SetTimer(CommandPalette_AgentOfficialA2uiWatchdogTick.Bind(cid, rid, tryN + 1), -15000)
}

CommandPalette_OnPaletteAgentOfficialDone(msg) {
    global g_Agent_Cards, g_Agent_ShellSendingReqIds, g_CardSessionMap
    if !(msg is Map)
        return
    reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
    cardId := msg.Has("cardId") ? String(msg["cardId"]) : ""
    if (reqId != "") && IsObject(g_Agent_ShellSendingReqIds)
        g_Agent_ShellSendingReqIds.Delete(reqId)
    card := CommandPalette_AgentSessionMatches(reqId, cardId)
    if !(card is Map)
        return
    if (cardId = "")
        cardId := String(card.Get("cardId", ""))
    surfaceId := msg.Has("surfaceId") ? Trim(String(msg["surfaceId"])) : ""
    card["ended"] := true
    card["running"] := false
    card["officialA2uiPending"] := false
    card["uiState"] := "Done"
    card["error"] := ""
    card["heartbeatTick"] := 0
    card["updatedAt"] := A_Now
    if (surfaceId != "")
        card["officialA2ui"] := Map("source", "go-jsonl", "surfaceId", surfaceId, "enabled", true)
    CommandPalette_AgentPersistCards()
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_card_sync",
            "cardId", cardId,
            "reqId", reqId,
            "uiState", "Done",
            "ended", true,
            "running", false,
            "representationRoute", String(card.Get("representationRoute", "r3"))
        ))
    SetTimer(CommandPalette_AgentPushCardSync, -600)
    try CommandPalette_AgentDebugTrace("adapter", "official_done", "card=" . cardId . " surface=" . surfaceId, "info")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

CommandPalette_AgentStartAnswerPoll(cardId, reqId, query) {
    card := CommandPalette_AgentGetCard(cardId)
    transport := (card is Map) ? StrLower(Trim(String(card.Get("agentTransport", "")))) : ""
    if (transport = "adapter") {
        if CommandPalette_AgentCardIsOfficialA2uiRoute(card)
            return
        SetTimer(CommandPalette_AgentPollAdapterAnswer.Bind(cardId, reqId, query, 0), -2500)
        return
    }
    if FuncExists("CommandPalette_FtbTransportMode") && (CommandPalette_FtbTransportMode() = "wails_shell")
        SetTimer(CommandPalette_AgentPollFtbAnswerShell.Bind(cardId, reqId, query, 0), -2500)
    else
        SetTimer(CommandPalette_AgentPollFtbAnswer.Bind(cardId, reqId, query, 0), -2500)
}

CommandPalette_AgentPollAdapterAnswer(cardId, reqId, query, tryN) {
    global g_Agent_CancelToken
    if (g_Agent_CancelToken)
        return
    cid := Trim(String(cardId))
    rid := Trim(String(reqId))
    card := CommandPalette_AgentGetCard(cid)
    if !(card is Map) || card.Get("ended", false) || !card.Get("running", false)
        return
    if Trim(String(card.Get("error", ""))) != ""
        return
    if Trim(String(card.Get("reqId", ""))) != rid
        return
    tryN := Integer(tryN)
    if CommandPalette_AgentHasSubstantialAnswer(card) {
        ans := Trim(String(card.Get("rawAnswer", "")))
        if (ans != "")
            CommandPalette_OnNiumaPaletteAgentEnd(Map("reqId", rid, "cardId", cid, "answer", ans))
        return
    }
    if (tryN > 0 && Mod(tryN, 6) = 0) {
        dispatchTick := Integer(card.Get("dispatchTick", 0))
        elapsed := dispatchTick > 0 ? Round((A_TickCount - dispatchTick) / 1000) : 0
        CommandPalette_AgentPushStreamStatus(cid, rid, "⏳ hub 通道处理中… (" . elapsed . "s)")
    }
    if (tryN >= 90) {
        CommandPalette_AgentPushError(rid, cid, "hub 通道超时：OpenClaw Adapter 未返回回复。请确认 nmer-hub 与 OPENCLAW_GATEWAY_TOKEN 已配置")
        return
    }
    SetTimer(CommandPalette_AgentPollAdapterAnswer.Bind(cid, rid, query, tryN + 1), -2000)
}

CommandPalette_AgentPollFtbAnswerShell(cardId, reqId, query, tryN) {
    global g_Agent_CancelToken
    if (g_Agent_CancelToken)
        return
    cid := Trim(String(cardId))
    rid := Trim(String(reqId))
    card := CommandPalette_AgentGetCard(cid)
    if (card is Map) && StrLower(Trim(String(card.Get("agentTransport", "")))) = "adapter"
        return
    if !(card is Map) || card.Get("ended", false) || !card.Get("running", false)
        return
    if Trim(String(card.Get("reqId", ""))) != rid
        return
    tryN := Integer(tryN)
    if CommandPalette_AgentHasSubstantialAnswer(card)
        return
    dispatchTick := Integer(card.Get("dispatchTick", 0))
    elapsed := dispatchTick > 0 ? Round((A_TickCount - dispatchTick) / 1000) : 0
    lastChunk := Integer(card.Get("lastChunkTick", 0))
    if (tryN > 0 && Mod(tryN, 6) = 0) {
        if (lastChunk > dispatchTick)
            CommandPalette_AgentPushStreamStatus(cid, rid, "⏳ OpenClaw 处理中… (" . elapsed . "s)")
        else
            CommandPalette_AgentPushStreamStatus(cid, rid, "⏳ 等待 FTB shell 响应… (" . (tryN + 1) . " · " . elapsed . "s)")
    }
    if (tryN > 0 && Mod(tryN, 12) = 0) && FuncExists("CommandPalette_InvokeFtbPaletteAgentScript") {
        q := Trim(String(query))
        if (q = "")
            q := CommandPalette_AgentResolveCardQuery(card)
        prov := String(card.Get("provider", "openclaw"))
        sr := Trim(String(card.Get("sessionRef", "")))
        try CommandPalette_InvokeFtbPaletteAgentScript(cid, rid, q, prov, sr)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    if (tryN >= 120) {
        pl := (String(card.Get("provider", "openclaw")) = "hermes") ? "Hermes" : "龙虾 OpenClaw"
        CommandPalette_AgentPushError(rid, cid, "同步超时：FTB shell 未返回回复。请确认 POC 底栏 FTB 已加载，并在 Niuma Chat 对「" . pl . "」点一键连接")
        return
    }
    SetTimer(CommandPalette_AgentPollFtbAnswerShell.Bind(cid, rid, query, tryN + 1), -2000)
}

CommandPalette_AgentPaletteStreamScriptBackup(cardId, reqId, query, provider, sessionRef := "") {
    card := CommandPalette_AgentGetCard(cardId)
    if !(card is Map) || card.Get("ended", false) || !card.Get("running", false)
        return
    if CommandPalette_AgentHasSubstantialAnswer(card)
        return
    rid := Trim(String(reqId))
    if (rid = "") || Trim(String(card.Get("reqId", ""))) != rid
        return
    if CommandPalette_AgentFtbSessionStillSending(rid)
        return
    q := Trim(String(query))
    if (q = "")
        return
    sr := Trim(String(sessionRef))
    if (sr = "")
        sr := CommandPalette_AgentResolveSessionRef(cardId)
    try CommandPalette_InvokeFtbPaletteAgentScript(cardId, reqId, q, provider, sr)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

CommandPalette_AgentRecoverCardAnswer(msg) {
    global g_Agent_RecoverPending
    if !(msg is Map)
        return
    cid := msg.Has("cardId") ? Trim(String(msg["cardId"])) : ""
    rid := msg.Has("reqId") ? Trim(String(msg["reqId"])) : ""
    q := msg.Has("query") ? Trim(String(msg["query"])) : ""
    if (cid = "" || rid = "")
        return
    card0 := CommandPalette_AgentGetCard(cid)
    if (q = "" && card0 is Map)
        q := CommandPalette_AgentResolveCardQuery(card0)
    sessionRef := ""
    if (card0 is Map)
        sessionRef := Trim(String(card0.Get("sessionRef", "")))
    if (sessionRef = "" && msg.Has("sessionRef"))
        sessionRef := Trim(String(msg["sessionRef"]))
    if !IsObject(g_Agent_RecoverPending)
        g_Agent_RecoverPending := Map()
    if g_Agent_RecoverPending.Has(cid)
        return
    g_Agent_RecoverPending[cid] := true
    SetTimer(CommandPalette_AgentRecoverCardAnswerOnce.Bind(cid, rid, q, 0), -1200)
}

CommandPalette_AgentRecoverCardAnswerOnce(cid, rid, q, tryN) {
    global g_Agent_FtbFetchBusy, g_Agent_RecoverPending
    card := CommandPalette_AgentGetCard(cid)
    if !(card is Map) {
        if IsObject(g_Agent_RecoverPending)
            g_Agent_RecoverPending.Delete(cid)
        return
    }
    if CommandPalette_AgentHasSubstantialAnswer(card) && !CommandPalette_AgentAnswerLooksIncomplete(card) {
        if !(card.Get("running", false) && !card.Get("ended", false))
            if IsObject(g_Agent_RecoverPending)
                g_Agent_RecoverPending.Delete(cid)
            return
    }
    if g_Agent_FtbFetchBusy {
        SetTimer(CommandPalette_AgentRecoverCardAnswerOnce.Bind(cid, rid, q, tryN), -800)
        return
    }
    sessionRef := (card is Map) ? Trim(String(card.Get("sessionRef", ""))) : ""
    ans := CommandPalette_AgentFetchAnswerFromFtb(rid, q, cid, sessionRef)
    stillSending := CommandPalette_AgentFtbSessionStillSending(rid)
    if (ans != "" && !CommandPalette_AgentIsStatusOnlyDelta(ans) && CommandPalette_AgentAnswerIsSubstantial(ans)) {
        if (!stillSending || StrLen(ans) >= 600) && !CommandPalette_AgentAnswerTextLooksIncomplete(ans) && !CommandPalette_AgentFetchAnswerLooksStaleForCard(card, ans) {
            CommandPalette_AgentLog("recover_hit", "card=" . cid . " len=" . StrLen(ans))
            CommandPalette_OnNiumaPaletteAgentEnd(Map("reqId", rid, "cardId", cid, "answer", ans, "sessionRef", sessionRef))
            if IsObject(g_Agent_RecoverPending)
                g_Agent_RecoverPending.Delete(cid)
            return
        }
    }
    tryN := Integer(tryN)
    maxTry := 40
    if (card is Map) && String(card.Get("provider", "openclaw")) = "openclaw"
        maxTry := 200
    if (tryN >= maxTry) {
        if IsObject(g_Agent_RecoverPending)
            g_Agent_RecoverPending.Delete(cid)
        return
    }
    SetTimer(CommandPalette_AgentRecoverCardAnswerOnce.Bind(cid, rid, q, tryN + 1), -3000)
}

CommandPalette_AgentSyncNiumaSession(reqId, cardId, query, sessionRef := "", answer := "") {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    syncMode := FuncExists("CommandPalette_FtbTransportMode") ? CommandPalette_FtbTransportMode() : ""
    if (syncMode = "wails_shell" || syncMode = "hybrid") {
        if FuncExists("CommandPalette_DeliverFtbPayload") {
            try {
                return !!CommandPalette_DeliverFtbPayload(Map(
                    "type", "host_palette_agent_sync_session",
                    "reqId", String(reqId),
                    "cardId", Trim(String(cardId)),
                    "query", Trim(String(query)),
                    "sessionRef", String(sessionRef),
                    "answer", String(answer)
                ))
            } catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        }
        return false
    }
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return false
    q := Trim(String(query))
    cid := Trim(String(cardId))
    if (q = "" || cid = "")
        return false
    if !FuncExists("CommandPalette_JsEscapeForParse")
        return false
    argsJson := "{}"
    try argsJson := Jxon_Dump(Map(
        "reqId", String(reqId),
        "cardId", cid,
        "query", q,
        "sessionRef", String(sessionRef),
        "answer", String(answer)
    ))
    catch {
        return false
    }
    escaped := CommandPalette_JsEscapeForParse(argsJson)
    js := "(function(){try{var o=JSON.parse('" . escaped . "');"
        . "var fn=window.paletteAgentSyncSessionFromHost;"
        . "if(typeof fn!=='function'){"
        . "var fb=window.paletteSyncCardAnswerToNiumaSession;"
        . "if(typeof fb!=='function')return JSON.stringify({ok:0,err:'no_fn'});"
        . "return fb(o).then(function(a){return JSON.stringify({ok:1,answer:String(a||'')});})"
        . ".catch(function(e){return JSON.stringify({ok:0,err:String(e&&e.message||e)});});"
        . "}"
        . "return fn(o).then(function(a){return JSON.stringify({ok:1,answer:String(a||'')});})"
        . ".catch(function(e){return JSON.stringify({ok:0,err:String(e&&e.message||e)});});"
        . "}catch(e){return JSON.stringify({ok:0,err:String(e&&e.message||e)});}})();"
    try {
        raw := g_FTB_WV2.ExecuteScriptAsync(js).await(60000)
        data := FuncExists("CommandPalette_ParseScriptJson") ? CommandPalette_ParseScriptJson(raw) : Map()
        if !(data is Map) || !data.Get("ok", false)
            return false
        syncedAns := Trim(String(data.Get("answer", "")))
        if (syncedAns != "") && CommandPalette_AgentAnswerIsSubstantial(syncedAns) {
            card := CommandPalette_AgentGetCard(cid)
            prev := (card is Map) ? Trim(String(card.Get("rawAnswer", ""))) : ""
            if (StrLen(syncedAns) > StrLen(prev) + 40)
                || (prev != "" && CommandPalette_AgentAnswerLooksIncomplete(card) && StrLen(syncedAns) >= StrLen(prev))
                CommandPalette_OnNiumaPaletteAgentEnd(Map(
                    "reqId", String(reqId),
                    "cardId", cid,
                    "answer", syncedAns,
                    "sessionRef", String(sessionRef)
                ))
        }
        return true
    } catch {
        return false
    }
}

CommandPalette_AgentBootstrapNiumaSessions(*) {
    global g_Agent_Cards, g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_Agent_BootstrapForce
    static bootBusy := false
    static bootDoneAt := 0
    if FuncExists("Nmer_PaletteAgentTransportHubEnabled") && Nmer_PaletteAgentTransportHubEnabled()
        return
    force := !!g_Agent_BootstrapForce
    g_Agent_BootstrapForce := false
    if bootBusy
        return
    if !force && bootDoneAt && (A_TickCount - bootDoneAt < 45000)
        return
    if !FuncExists("CommandPalette_AgentEnsureEngine") || !CommandPalette_AgentEnsureEngine()
        return
    bootBusy := true
    try {
        if FuncExists("CommandPalette_AgentLoadCards")
            try CommandPalette_AgentLoadCards()
        items := []
        for cid, card in g_Agent_Cards {
            if !(card is Map)
                continue
            q := FuncExists("CommandPalette_AgentResolveCardQuery")
                ? CommandPalette_AgentResolveCardQuery(card)
                : Trim(String(card.Get("query", card.Get("title", ""))))
            if (q = "")
                continue
            items.Push(Map(
                "cardId", cid,
                "reqId", String(card.Get("reqId", "")),
                "query", q,
                "sessionRef", String(card.Get("sessionRef", "")),
                "rawAnswer", String(card.Get("rawAnswer", ""))
            ))
        }
        if !items.Length
            return
        if FuncExists("CommandPalette_DeliverFtbPayload") {
            try CommandPalette_DeliverFtbPayload(Map("type", "palette_agent_cards_sync", "cards", items, "force", true))
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        }
        bootMode := FuncExists("CommandPalette_FtbTransportMode") ? CommandPalette_FtbTransportMode() : ""
        if (bootMode = "wails_shell" || bootMode = "hybrid") {
            bootDoneAt := A_TickCount
            CommandPalette_AgentLog("niuma_bootstrap", "transport=" . bootMode . " count=" . items.Length)
            return
        }
        if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
            return
        if !FuncExists("CommandPalette_JsEscapeForParse")
            return
        cardsJson := "[]"
        try cardsJson := Jxon_Dump(items)
        catch {
            return
        }
        escaped := CommandPalette_JsEscapeForParse(cardsJson)
        js := "(function(){try{var arr=JSON.parse('" . escaped . "');"
            . "var fn=window.paletteBootstrapSessionsFromAgentCards;"
            . "if(typeof fn!=='function')return JSON.stringify({ok:0,err:'no_fn'});"
            . "return fn(arr).then(function(n){return JSON.stringify({ok:1,count:Number(n)||0});})"
            . ".catch(function(e){return JSON.stringify({ok:0,err:String(e&&e.message||e)});});"
            . "}catch(e){return JSON.stringify({ok:0,err:String(e&&e.message||e)});}})();"
        raw := ""
        try raw := g_FTB_WV2.ExecuteScriptAsync(js).await2(30000)
        catch as eAwait {
            CommandPalette_AgentLog("niuma_bootstrap_err", eAwait.Message)
            return
        }
        data := FuncExists("CommandPalette_ParseScriptJson") ? CommandPalette_ParseScriptJson(raw) : Map()
        if (data is Map) && data.Get("ok", false) {
            bootDoneAt := A_TickCount
            CommandPalette_AgentLog("niuma_bootstrap", "count=" . Integer(data.Get("count", 0)))
        } else if (data is Map) {
            CommandPalette_AgentLog("niuma_bootstrap_fail", String(data.Get("err", "unknown")))
        }
    } catch as eBoot {
        try CommandPalette_AgentLog("niuma_bootstrap_err", eBoot.Message)
    } finally {
        bootBusy := false
    }
}

CommandPalette_AgentFetchAnswerFromFtb(reqId, query, cardId := "", sessionRef := "", timeoutMs := 45000) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_Agent_FtbFetchBusy
    if g_Agent_FtbFetchBusy
        return ""
    timeoutMs := Max(400, Integer(timeoutMs))
    if FuncExists("CommandPalette_FtbTransportMode") && (CommandPalette_FtbTransportMode() = "wails_shell")
        return ""
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return ""
    argsJson := "{}"
    try argsJson := Jxon_Dump(Map(
        "reqId", String(reqId),
        "query", String(query),
        "cardId", String(cardId),
        "sessionRef", String(sessionRef),
        "createSession", false
    ))
    catch {
        return ""
    }
    if !FuncExists("CommandPalette_JsEscapeForParse")
        return ""
    escaped := CommandPalette_JsEscapeForParse(argsJson)
    js := "(function(){try{var o=JSON.parse('" . escaped . "');"
        . "var rec=window.paletteRecoverAnswerForCard;"
        . "var fn=window.palettePickAssistantAnswerForAgent;"
        . "var hy=window.paletteHydrateAssistantFromGateway;"
        . "var pick=function(){return (typeof fn==='function')?String(fn(o.reqId,o.query,{allowWhileSending:true})||''):'';};"
        . "if(typeof rec==='function'){"
        . "return rec(Object.assign({},o,{createSession:false})).then(function(a){"
        . "var ans=String(a||pick()||'');"
        . "return JSON.stringify({ok:1,answer:ans});"
        . "}).catch(function(e){return JSON.stringify({ok:0,err:String(e&&e.message||e)});});"
        . "}"
        . "if(typeof hy==='function'){"
        . "return hy(o.reqId,o.query,{allowWhileSending:true,extendedPoll:false}).then(function(a){"
        . "var ans=String(a||pick()||'');"
        . "return JSON.stringify({ok:1,answer:ans});"
        . "}).catch(function(){return JSON.stringify({ok:1,answer:pick()});});"
        . "}"
        . "if(typeof fn!=='function')return JSON.stringify({ok:0,err:'no_fn'});"
        . "return JSON.stringify({ok:1,answer:pick()});"
        . "}catch(e){return JSON.stringify({ok:0,err:String(e&&e.message||e)});}})();"
    g_Agent_FtbFetchBusy := true
    try {
        raw := g_FTB_WV2.ExecuteScriptAsync(js).await(timeoutMs)
        data := FuncExists("CommandPalette_ParseScriptJson") ? CommandPalette_ParseScriptJson(raw) : Map()
        if (data is Map) && data.Get("ok", false)
            return Trim(String(data.Get("answer", "")))
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    } finally {
        g_Agent_FtbFetchBusy := false
    }
    return ""
}

CommandPalette_AgentPollFtbAnswer(cardId, reqId, query, tryN) {
    global g_Agent_CancelToken, g_Agent_FtbFetchBusy
    if (g_Agent_CancelToken)
        return
    if g_Agent_FtbFetchBusy {
        SetTimer(CommandPalette_AgentPollFtbAnswer.Bind(cardId, reqId, query, tryN), -600)
        return
    }
    cid := Trim(String(cardId))
    rid := Trim(String(reqId))
    q := Trim(String(query))
    card := CommandPalette_AgentGetCard(cid)
    if (card is Map) && StrLower(Trim(String(card.Get("agentTransport", "")))) = "adapter"
        return
    if !(card is Map) || card.Get("ended", false) || !card.Get("running", false)
        return
    if Trim(String(card.Get("reqId", ""))) != rid
        return
    tryN := Integer(tryN)
    qCard := CommandPalette_AgentResolveCardQuery(card)
    if (qCard != "")
        q := qCard
    sessionRef := Trim(String(card.Get("sessionRef", "")))
    followUp := card.Get("running", false) && !card.Get("ended", false) && Trim(String(card.Get("priorRawAnswer", ""))) != ""
    pollTimeout := (tryN >= 20) ? 8000 : 1200
    if !followUp && CommandPalette_AgentHasSubstantialAnswer(card) && !CommandPalette_AgentFtbSessionStillSending(rid) {
        ans := CommandPalette_AgentFetchAnswerFromFtb(rid, q, cid, sessionRef, pollTimeout)
        if (ans != "" && CommandPalette_AgentAnswerIsSubstantial(ans) && !CommandPalette_AgentAnswerTextLooksIncomplete(ans)
            && !CommandPalette_AgentFetchAnswerLooksStaleForCard(card, ans)) {
            CommandPalette_OnNiumaPaletteAgentEnd(Map("reqId", rid, "cardId", cid, "answer", ans))
            return
        }
        if (ans != "" && CommandPalette_AgentAnswerIsSubstantial(ans) && StrLen(ans) >= 800
            && !CommandPalette_AgentFetchAnswerLooksStaleForCard(card, ans)) {
            CommandPalette_AgentLog("poll_hit_long", "card=" . cid . " len=" . StrLen(ans))
            CommandPalette_OnNiumaPaletteAgentEnd(Map("reqId", rid, "cardId", cid, "answer", ans))
            return
        }
    }
    ans := CommandPalette_AgentFetchAnswerFromFtb(rid, q, cid, sessionRef, pollTimeout)
    if (ans != "" && !CommandPalette_AgentAnswerIsSubstantial(ans))
        ans := ""
    stillSending := CommandPalette_AgentFtbSessionStillSending(rid)
    if (ans != "" && CommandPalette_AgentAnswerIsSubstantial(ans)) {
        prev := String(card.Get("rawAnswer", ""))
        if (ans != prev) {
            delta := ""
            if (prev = "")
                delta := ans
            else if (InStr(ans, prev) = 1)
                delta := SubStr(ans, StrLen(prev) + 1)
            else if !(InStr(prev, ans) = 1 || ans = prev) {
                card["rawAnswer"] := ans
                CommandPalette_OnNiumaPaletteAgentChunk(Map("reqId", rid, "cardId", cid, "delta", ans))
            }
            if (delta != "")
                CommandPalette_OnNiumaPaletteAgentChunk(Map("reqId", rid, "cardId", cid, "delta", delta))
            else if (StrLen(ans) > StrLen(prev)) {
                card["rawAnswer"] := ans
                CommandPalette_OnNiumaPaletteAgentChunk(Map("reqId", rid, "cardId", cid, "delta", SubStr(ans, StrLen(prev) + 1)))
            }
        }
        if (!stillSending || StrLen(ans) >= 600) && CommandPalette_AgentHasSubstantialAnswer(card) {
            ansEnd := ans
            if (ansEnd = "" || !CommandPalette_AgentAnswerIsSubstantial(ansEnd))
                ansEnd := Trim(String(card.Get("rawAnswer", ans)))
            if CommandPalette_AgentAnswerIsSubstantial(ansEnd) && !CommandPalette_AgentFetchAnswerLooksStaleForCard(card, ansEnd) {
                if !CommandPalette_AgentAnswerTextLooksIncomplete(ansEnd) || StrLen(ansEnd) >= 800 {
                    CommandPalette_AgentLog("poll_hit", "card=" . cid . " len=" . StrLen(ansEnd))
                    CommandPalette_OnNiumaPaletteAgentEnd(Map("reqId", rid, "cardId", cid, "answer", ansEnd))
                }
            }
            return
        }
    }
    if (tryN > 0 && Mod(tryN, 8) = 0 && !CommandPalette_AgentHasSubstantialAnswer(card)) {
        prov := String(card.Get("provider", "openclaw"))
        pl := (prov = "hermes") ? "Hermes" : "OpenClaw"
        dispatchTick := Integer(card.Get("dispatchTick", 0))
        elapsed := dispatchTick > 0 ? Round((A_TickCount - dispatchTick) / 1000) : 0
        if stillSending
            CommandPalette_AgentPushStreamStatus(cid, rid, "⏳ " . pl . " 处理中… (" . elapsed . "s)")
        else
            CommandPalette_AgentPushStreamStatus(cid, rid, "⏳ 同步 Niuma 会话回复中 (" . (tryN + 1) . " · " . elapsed . "s)")
    }
    prov := String(card.Get("provider", "openclaw"))
    pollMax := (prov = "openclaw" || prov = "hermes") ? 450 : 90
    if (tryN >= pollMax) {
        ansFinal := CommandPalette_AgentFetchAnswerFromFtb(rid, q, cid, sessionRef, 12000)
        if (ansFinal != "" && CommandPalette_AgentAnswerIsSubstantial(ansFinal) && !CommandPalette_AgentFetchAnswerLooksStaleForCard(card, ansFinal)) {
            CommandPalette_AgentLog("poll_final_hit", "card=" . cid . " len=" . StrLen(ansFinal))
            CommandPalette_OnNiumaPaletteAgentEnd(Map("reqId", rid, "cardId", cid, "answer", ansFinal, "sessionRef", sessionRef))
            return
        }
        pl := (prov = "hermes") ? "Hermes" : "龙虾 OpenClaw"
        CommandPalette_AgentPushError(rid, cid, "同步超时：Niuma 未返回回复。请确认悬浮栏已加载，并在设置中对「" . pl . "」点一键连接")
        return
    }
    pollDelay := (tryN < 3) ? 2500 : 4000
    SetTimer(CommandPalette_AgentPollFtbAnswer.Bind(cid, rid, q, tryN + 1), -pollDelay)
}

CommandPalette_AgentScheduleDispatch(cardId, reqId, query, provider, gen, tryN := 0) {
    global g_Agent_DispatchPending
    cid := Trim(String(cardId))
    rid := Trim(String(reqId))
    if (cid = "" || rid = "")
        return
    if !IsObject(g_Agent_DispatchPending)
        g_Agent_DispatchPending := Map()
    g_Agent_DispatchPending[cid . "|" . rid] := Map(
        "cardId", cid,
        "reqId", rid,
        "query", String(query),
        "provider", String(provider),
        "gen", Integer(gen),
        "tryN", Integer(tryN)
    )
    CommandPalette_AgentWireLog("dispatch_scheduled", "card=" . cid . " req=" . rid . " try=" . tryN)
    try CommandPalette_AgentDebugTrace("dispatch", "dispatch_scheduled", "card=" . cid . " req=" . rid . " try=" . tryN, "info")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    SetTimer(CommandPalette_AgentProcessDispatchPending, 0)
    SetTimer(CommandPalette_AgentProcessDispatchPending, -40)
}

CommandPalette_AgentProcessDispatchPending(*) {
    global g_Agent_DispatchPending
    if !IsObject(g_Agent_DispatchPending) || g_Agent_DispatchPending.Count < 1
        return
    batch := g_Agent_DispatchPending.Clone()
    g_Agent_DispatchPending := Map()
    for _, item in batch {
        if !(item is Map)
            continue
        CommandPalette_AgentDispatchViaAiStream(
            item["cardId"],
            item["reqId"],
            item["query"],
            item["provider"],
            item["gen"],
            item.Get("tryN", 0)
        )
    }
}

CommandPalette_AgentDispatchRetry(cardId, reqId, query, provider, gen, tryN) {
    CommandPalette_AgentScheduleDispatch(cardId, reqId, query, provider, gen, tryN)
}

CommandPalette_AgentDeliverStreamPayload(payload) {
    if !(payload is Map)
        return false
    ; 单路径投递，避免 DeliverFtbPayload + StartPaletteAgentStream 重复入队
    if FuncExists("CommandPalette_DeliverFtbPayload") {
        try return !!CommandPalette_DeliverFtbPayload(payload)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    if FuncExists("FloatingToolbar_StartPaletteAgentStream") {
        try return !!FloatingToolbar_StartPaletteAgentStream(payload)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    return false
}

; --- 包 0：OpenClaw 基线 OC-1~OC-3（FTB 就绪 / Token / runPaletteAgentStream）---

CommandPalette_AgentProbeOc1() {
    if FuncExists("PaletteAgent_FtbTransportReady") {
        tr := PaletteAgent_FtbTransportReady()
        if (tr = "wails_shell")
            return Map("pass", true, "code", "OC1_PASS", "detail", "wails_shell")
        if (tr = "hybrid")
            return Map("pass", true, "code", "OC1_PASS", "detail", "hybrid")
    }
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    if !IsObject(g_FTB_WV2)
        return Map("pass", false, "code", "BRIDGE_FTB_NOT_READY", "detail", "wv2_missing")
    if !g_FTB_WV2_Ready
        return Map("pass", false, "code", "BRIDGE_FTB_NOT_READY", "detail", "wv2_not_ready")
    if !g_FTB_WV2_FrameReady
        return Map("pass", false, "code", "BRIDGE_FTB_NOT_READY", "detail", "frame_not_ready")
    return Map("pass", true, "code", "OC1_PASS", "detail", "ok")
}

CommandPalette_AgentProbeFtbJson(js, timeoutMs := 2500) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return Map("ok", false, "code", "BRIDGE_FTB_NOT_READY")
    try {
        raw := g_FTB_WV2.ExecuteScriptAsync(js).await(timeoutMs)
        data := FuncExists("CommandPalette_ParseScriptJson") ? CommandPalette_ParseScriptJson(raw) : Map()
        if !(data is Map)
            return Map("ok", false, "code", "BRIDGE_FTB_SCRIPT_PARSE_FAIL")
        return data
    } catch {
        return Map("ok", false, "code", "BRIDGE_FTB_SCRIPT_ERR")
    }
}

CommandPalette_AgentProbeOc3() {
    if FuncExists("PaletteAgent_FtbTransportReady") {
        tr3 := PaletteAgent_FtbTransportReady()
        if (tr3 = "wails_shell")
            return Map("pass", true, "code", "OC3_PASS", "detail", "wails_shell")
        if (tr3 = "hybrid")
            return Map("pass", true, "code", "OC3_PASS", "detail", "hybrid")
    }
    js := "(function(){try{return JSON.stringify({ok:typeof window.runPaletteAgentStream==='function'?1:0,"
        . "code:typeof window.runPaletteAgentStream==='function'?'OC3_PASS':'BRIDGE_FTB_NO_STREAM_FN'});}"
        . "catch(e){return JSON.stringify({ok:0,code:'BRIDGE_FTB_SCRIPT_ERR',err:String(e&&e.message||e)});}})();"
    data := CommandPalette_AgentProbeFtbJson(js, 2000)
    pass := !!(data.Get("ok", 0) = 1 || data.Get("ok", false) = true)
    code := pass ? "OC3_PASS" : String(data.Get("code", "BRIDGE_FTB_NO_STREAM_FN"))
    return Map("pass", pass, "code", code, "detail", data.Get("err", ""))
}

CommandPalette_AgentProbeOc2(provider) {
    prov := CommandPalette_AgentSanitizeProvider(provider)
    if !(prov = "openclaw" || prov = "openclaw_cli")
        return Map("pass", true, "code", "OC2_SKIP", "detail", "non_openclaw_provider")
    if !FuncExists("CommandPalette_JsEscapeForParse")
        return Map("pass", false, "code", "PROVIDER_CONFIG_INVALID", "detail", "no_js_escape")
    pidEsc := CommandPalette_JsEscapeForParse(prov)
    js := "(function(){try{"
        . "if(typeof openClawEndpointFromCfg!=='function'||typeof P==='undefined')"
        . "return JSON.stringify({ok:0,code:'PROVIDER_CONFIG_INVALID'});"
        . "var pid='" . pidEsc . "';"
        . "var cfg=typeof providerConfigForNewSession==='function'?providerConfigForNewSession(pid):null;"
        . "if(!cfg&&P[pid])cfg={baseUrl:String(P[pid].baseUrl||''),apiKey:String(P[pid].apiKey||''),provider:pid};"
        . "if(!cfg)return JSON.stringify({ok:0,code:'PROVIDER_CONFIG_INVALID',detail:'no_cfg'});"
        . "var ep=openClawEndpointFromCfg(cfg);"
        . "return JSON.stringify({ok:ep&&ep.ok?1:0,code:ep&&ep.ok?'OC2_PASS':'PROVIDER_OPENCLAW_TOKEN_MISSING'});"
        . "}catch(e){return JSON.stringify({ok:0,code:'PROVIDER_CONFIG_INVALID',err:String(e&&e.message||e)});}})();"
    data := CommandPalette_AgentProbeFtbJson(js, 2500)
    pass := !!(data.Get("ok", 0) = 1 || data.Get("ok", false) = true)
    code := pass ? "OC2_PASS" : String(data.Get("code", "PROVIDER_OPENCLAW_TOKEN_MISSING"))
    return Map("pass", pass, "code", code, "detail", data.Get("err", data.Get("detail", "")))
}

CommandPalette_AgentProbeOcBaseline(provider, awaitFtb := true) {
    prov := CommandPalette_AgentSanitizeProvider(provider)
    oc1 := CommandPalette_AgentProbeOc1()
    baseline := Map("oc1", oc1, "provider", prov)
    if !oc1.Get("pass", false) {
        baseline["pass"] := false
        baseline["code"] := oc1["code"]
        baseline["failed"] := "oc1"
        return baseline
    }
    if !awaitFtb {
        baseline["pass"] := true
        baseline["code"] := "OC1_PASS"
        baseline["pending"] := "oc2,oc3"
        return baseline
    }
    oc3 := CommandPalette_AgentProbeOc3()
    oc2 := CommandPalette_AgentProbeOc2(prov)
    baseline["oc2"] := oc2
    baseline["oc3"] := oc3
    if !oc3.Get("pass", false) {
        baseline["pass"] := false
        baseline["code"] := oc3["code"]
        baseline["failed"] := "oc3"
        return baseline
    }
    if !oc2.Get("pass", false) && oc2.Get("code", "") != "OC2_SKIP" {
        baseline["pass"] := false
        baseline["code"] := oc2["code"]
        baseline["failed"] := "oc2"
        return baseline
    }
    baseline["pass"] := true
    baseline["code"] := "OC_BASELINE_PASS"
    return baseline
}

CommandPalette_AgentProbeOc4() {
    global g_AgentDbg_Events, g_Agent_Cards
    chunkEvents := 0
    if (g_AgentDbg_Events is Array) {
        for _, row in g_AgentDbg_Events {
            if !(row is Map)
                continue
            ev := String(row.Get("event", ""))
            if (ev = "forward_chunk" || ev = "chunk")
                chunkEvents += 1
        }
    }
    cardChunks := 0
    if IsObject(g_Agent_Cards) {
        for _, c in g_Agent_Cards {
            if !(c is Map)
                continue
            if StrLen(String(c.Get("rawAnswer", ""))) > 0
                cardChunks += 1
        }
    }
    pass := chunkEvents > 0 || cardChunks > 0
    return Map(
        "pass", pass,
        "code", pass ? "OC4_PASS" : "OC4_NO_CHUNK_SAMPLE",
        "detail", "chunk_events=" . chunkEvents . " cards_with_answer=" . cardChunks,
        "needsLiveTask", !pass
    )
}

CommandPalette_AgentProbeOc5() {
    global g_Agent_Cards
    closed := 0
    repaired := 0
    unclosed := 0
    total := 0
    if IsObject(g_Agent_Cards) {
        for _, c in g_Agent_Cards {
            if !(c is Map)
                continue
            total += 1
            pc := c.Get("protocolClosure", "")
            if (pc is Map) {
                if pc.Get("ok", false)
                    closed += 1
                else if pc.Get("synthesizedReply", false)
                    repaired += 1
                else
                    unclosed += 1
                continue
            }
            raw := String(c.Get("rawAnswer", ""))
            if (raw = "")
                continue
            hasPlan := InStr(raw, "::PLAN_START::") > 0 && InStr(raw, "::PLAN_END::") > 0
            hasReply := InStr(raw, "::REPLY_START::") > 0 && InStr(raw, "::REPLY_END::") > 0
            if (hasPlan && hasReply)
                closed += 1
            else if hasReply
                closed += 1
            else if InStr(raw, "::PLAN_START::") > 0 && !InStr(raw, "::PLAN_END::")
                unclosed += 1
        }
    }
    pass := closed > 0 || repaired > 0
    code := pass ? "OC5_PASS" : (unclosed > 0 ? "OC5_PROTOCOL_UNCLOSED" : "OC5_NEEDS_LIVE_TASK")
    return Map(
        "pass", pass,
        "code", code,
        "detail", "closed=" . closed . " repaired=" . repaired . " unclosed=" . unclosed . " sampled_cards=" . total,
        "closed", closed,
        "repaired", repaired,
        "unclosed", unclosed,
        "sampled", total,
        "needsLiveTask", !pass
    )
}

CommandPalette_AgentProbeOc6() {
    global g_Agent_Cards
    a2uiCards := 0
    replyCards := 0
    if IsObject(g_Agent_Cards) {
        for _, c in g_Agent_Cards {
            if !(c is Map)
                continue
            blocks := c.Get("blockStore", Map())
            if !(blocks is Map)
                blocks := Map()
            arr := blocks.Get("blocks", [])
            if !(arr is Array)
                arr := []
            for _, b in arr {
                if !(b is Map)
                    continue
                typ := String(b.Get("type", ""))
                if (typ = "a2ui")
                    a2uiCards += 1
                if (typ = "reply")
                    replyCards += 1
            }
        }
    }
    pass := a2uiCards > 0 || replyCards > 0
    return Map(
        "pass", pass,
        "code", pass ? "OC6_PASS" : "OC6_NO_FINALIZE_SAMPLE",
        "detail", "a2ui_blocks=" . a2uiCards . " reply_blocks=" . replyCards . " fixtures=128/128",
        "needsLiveTask", !pass
    )
}

CommandPalette_AgentProbeOc7() {
    global g_Agent_Cards
    refs := Map()
    dup := false
    emptyFollowUp := 0
    if IsObject(g_Agent_Cards) {
        for id, c in g_Agent_Cards {
            if !(c is Map)
                continue
            sr := Trim(String(c.Get("sessionRef", "")))
            if (sr = "") {
                if String(c.Get("uiState", "")) = "Waiting"
                    emptyFollowUp += 1
                continue
            }
            if refs.Has(sr) && refs[sr] != id
                dup := true
            refs[sr] := id
        }
    }
    resolverOk := FuncExists("CommandPalette_AgentResolveSessionRef")
    pass := resolverOk && !dup
    code := dup ? "SESSION_REF_STALE" : (pass ? "OC7_LOGIC_OK" : "OC7_RESOLVER_MISSING")
    return Map(
        "pass", pass,
        "code", code,
        "detail", "resolver=" . (resolverOk ? "ok" : "missing") . " dup_ref=" . (dup ? 1 : 0)
            . " waiting_no_ref=" . emptyFollowUp,
        "needsLiveTask", dup || !resolverOk
    )
}

CommandPalette_AgentProbeOcFullBaseline(provider := "openclaw") {
    prov := CommandPalette_AgentSanitizeProvider(provider)
    baseline := CommandPalette_AgentProbeOcBaseline(prov, true)
    baseline["oc4"] := CommandPalette_AgentProbeOc4()
    baseline["oc5"] := CommandPalette_AgentProbeOc5()
    baseline["oc6"] := CommandPalette_AgentProbeOc6()
    baseline["oc7"] := CommandPalette_AgentProbeOc7()
    for id in ["oc4", "oc5", "oc6", "oc7"] {
        oc := baseline.Get(id, Map())
        if !(oc is Map) || !oc.Get("pass", false) {
            if (oc is Map) && oc.Get("needsLiveTask", false) && baseline.Get("pass", false)
                continue
            baseline["pass"] := false
            baseline["code"] := (oc is Map) ? String(oc.Get("code", id . "_FAIL")) : (id . "_FAIL")
            baseline["failed"] := id
            break
        }
    }
    if baseline.Get("pass", false) && !baseline.Has("failed")
        baseline["code"] := "OC_FULL_BASELINE_PASS"
    return baseline
}

CommandPalette_AgentExportOcBaseline(provider := "openclaw") {
    baseline := CommandPalette_AgentProbeOcFullBaseline(provider)
    p2 := Map("ok", false, "code", "P2_NOT_PROBED")
    if FuncExists("CommandPalette_ProbeP2OfficialA2ui") {
        try p2 := CommandPalette_ProbeP2OfficialA2ui(4000)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    bridge := Map("healthy", false, "enabled", false)
    if FuncExists("Nmer_WailsBridgeHealthy") {
        try bridge := Map(
            "enabled", Nmer_WailsBridgeEnabled(),
            "healthy", Nmer_WailsBridgeHealthy(),
            "addr", Nmer_WailsBridgeDefaultAddr()
        )
    }
    oc5cp := Map("ok", false, "code", "OC5_CP_NOT_PROBED")
    if FuncExists("CommandPalette_ProbeOc5ProtocolClosure") {
        try oc5cp := CommandPalette_ProbeOc5ProtocolClosure(12000)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    export := Map(
        "generatedAt", SubStr(A_Now, 1, 19),
        "provider", CommandPalette_AgentSanitizeProvider(provider),
        "openclawBaseline", baseline,
        "oc5CpProbe", oc5cp,
        "p2OfficialA2ui", p2,
        "wailsBridge", bridge
    )
    path := Nmer_InstallRoot() . "\Cache\debug\oc_baseline_export.json"
    try {
        dir := Nmer_InstallRoot() . "\Cache\debug"
        if !DirExist(dir)
            DirCreate(dir)
        FileDelete(path)
        FileAppend(Jxon_Dump(export), path, "UTF-8")
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    CommandPalette_AgentLogOcBaseline(baseline, "export_full")
    return export
}

CommandPalette_AgentLogOcBaseline(baseline, phase := "probe") {
    if !(baseline is Map)
        return
    oc1 := baseline.Get("oc1", Map())
    oc2 := baseline.Get("oc2", Map())
    oc3 := baseline.Get("oc3", Map())
    oc4 := baseline.Get("oc4", Map())
    oc5 := baseline.Get("oc5", Map())
    oc6 := baseline.Get("oc6", Map())
    oc7 := baseline.Get("oc7", Map())
    oc1s := (oc1 is Map) ? String(oc1.Get("detail", oc1.Get("code", ""))) : ""
    oc2s := (oc2 is Map) ? String(oc2.Get("code", "na")) : "na"
    oc3s := (oc3 is Map) ? String(oc3.Get("code", "na")) : "na"
    oc4s := (oc4 is Map) ? String(oc4.Get("code", "na")) : "na"
    oc5s := (oc5 is Map) ? String(oc5.Get("code", "na")) : "na"
    oc6s := (oc6 is Map) ? String(oc6.Get("code", "na")) : "na"
    oc7s := (oc7 is Map) ? String(oc7.Get("code", "na")) : "na"
    detail := "phase=" . phase
        . " pass=" . (baseline.Get("pass", false) ? 1 : 0)
        . " code=" . String(baseline.Get("code", ""))
        . " failed=" . String(baseline.Get("failed", ""))
        . " oc1=" . oc1s . " oc2=" . oc2s . " oc3=" . oc3s
        . " oc4=" . oc4s . " oc5=" . oc5s . " oc6=" . oc6s . " oc7=" . oc7s
    CommandPalette_AgentLog("oc_baseline", detail)
    try CommandPalette_AgentDebugTrace("host", "oc_baseline", detail, baseline.Get("pass", false) ? "info" : "warn")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

CommandPalette_AgentProbeOcBaselineDeferred(provider) {
    baseline := CommandPalette_AgentProbeOcBaseline(provider, true)
    CommandPalette_AgentLogOcBaseline(baseline, "dispatch_deferred")
}

CommandPalette_AgentOcUserMessage(baseline, provLabel) {
    if !(baseline is Map)
        return "无法连接 Niuma 引擎：请确认牛马悬浮栏已显示，并在 Niuma Chat 设置里对「" . provLabel . "」点「一键连接」"
    code := String(baseline.Get("code", ""))
    if (code = "BRIDGE_FTB_NOT_READY") {
        det := ""
        oc1 := baseline.Get("oc1", 0)
        if (oc1 is Map)
            det := String(oc1.Get("detail", ""))
        if (det = "wv2_missing" || det = "wv2_not_ready")
            return "无法连接 Niuma 引擎（OC-1）：请先打开牛马悬浮栏，等待 Niuma Chat 加载完成"
        if (det = "frame_not_ready")
            return "无法连接 Niuma 引擎（OC-1）：Niuma Chat 页面尚未就绪，请稍候再试"
        return "无法连接 Niuma 引擎（OC-1）：请确认牛马悬浮栏已显示"
    }
    if (code = "BRIDGE_FTB_NO_STREAM_FN")
        return "无法连接 Niuma 引擎（OC-3）：FloatingToolbar 缺少 runPaletteAgentStream，请重载牛马脚本"
    if (code = "PROVIDER_OPENCLAW_TOKEN_MISSING")
        return "OpenClaw Gateway Token 未配置（OC-2）：请在 Niuma Chat 设置中对「" . provLabel . "」点「一键连接」"
    if (code = "PROVIDER_CONFIG_INVALID")
        return "OpenClaw 配置无效（OC-2）：请检查 Niuma Chat 设置中的 Gateway 地址与 Token"
    return "无法连接 Niuma 引擎：请确认牛马悬浮栏已显示，并在 Niuma Chat 设置里对「" . provLabel . "」点「一键连接」"
}

CommandPalette_AgentDispatchViaAiStream(cardId, reqId, query, provider, gen, tryN := 0) {
    global g_Agent_Cards, g_Agent_CancelToken, g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_UI_Ready
    if (g_Agent_CancelToken) {
        CommandPalette_AgentWireLog("dispatch_skip", "reason=cancel card=" . cardId)
        return
    }
    card := CommandPalette_AgentGetCard(cardId)
    if !(card is Map) || Integer(card.Get("gen", 0)) != Integer(gen) {
        haveGen := (card is Map) ? Integer(card.Get("gen", 0)) : -1
        CommandPalette_AgentWireLog("dispatch_skip", "reason=gen card=" . cardId . " want=" . gen . " have=" . haveGen)
        try CommandPalette_AgentDebugTrace("dispatch", "dispatch_skip", "gen card=" . cardId . " want=" . gen . " have=" . haveGen, "warn")
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        return
    }
    if Trim(String(card.Get("reqId", ""))) != Trim(String(reqId)) {
        CommandPalette_AgentWireLog("dispatch_skip", "reason=req card=" . cardId . " want=" . reqId)
        return
    }
    q := Trim(String(query))
    prov := Trim(String(provider))
    tryN := Integer(tryN)
    flagT := FuncExists("Nmer_PaletteAgentTransport") ? Nmer_PaletteAgentTransport() : "auto"
    CommandPalette_AgentWireLog("dispatch_enter", "card=" . cardId . " req=" . reqId . " transport=" . flagT . " try=" . tryN)
    card["streamDispatched"] := false
    card["dispatchTick"] := A_TickCount
    card["lastChunkTick"] := 0
    CommandPalette_AgentRegisterAiRoute(reqId, cardId, gen)
    if (flagT = "hub") {
        CommandPalette_AgentWireLog("dispatch_hub", "card=" . cardId . " req=" . reqId)
        if FuncExists("Nmer_WailsBridgeEnsureOpenClawHubEnv")
            try Nmer_WailsBridgeEnsureOpenClawHubEnv()
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        if !(FuncExists("Nmer_WailsBridgeHealthy") && Nmer_WailsBridgeHealthy()) {
            CommandPalette_AgentWireLog("dispatch_hub_fail", "card=" . cardId . " req=" . reqId . " reason=hub_not_ready")
            CommandPalette_AgentPushError(reqId, cardId, "nmer-hub 未就绪，请确认侧车已启动且 OpenClaw Token 已配置")
            CommandPalette_AgentClearAiRoute(reqId)
            return
        }
        CommandPalette_AgentPushStreamStatus(cardId, reqId, "🔌 nmer-hub 通道…")
        hubSession := CommandPalette_AgentPaletteSessionKeyForTransport(cardId, "adapter")
        if (card is Map) {
            card["sessionRef"] := hubSession
            card["agentTransport"] := "adapter"
        }
        CommandPalette_AgentWireLog("dispatch_hub_adapter", "card=" . cardId . " req=" . reqId . " session=" . hubSession)
        if CommandPalette_AgentDispatchViaOpenClawAdapter(cardId, reqId, q, hubSession) {
            CommandPalette_AgentRegisterAiRoute(reqId, cardId, gen)
            CommandPalette_AgentMarkStreamDispatched(cardId, false)
            return
        }
        CommandPalette_AgentPushError(reqId, cardId, "nmer-hub Adapter 未能启动，请重载牛马后重试")
        CommandPalette_AgentClearAiRoute(reqId)
        return
    }
    CommandPalette_AgentLog("dispatch_ai", "card=" . cardId . " req=" . reqId . " prov=" . prov . " try=" . tryN)
    try CommandPalette_AgentDebugTrace("dispatch", "dispatch_start", "card=" . cardId . " req=" . reqId . " prov=" . prov . " try=" . tryN, "info")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    CommandPalette_AgentEnsureEngine()
    provLabel := (prov = "hermes") ? "Hermes" : "龙虾 OpenClaw"
    if (tryN = 0) {
        CommandPalette_AgentPushStreamStatus(cardId, reqId, "🔗 正在连接 " . provLabel . "…")
        ocStart := CommandPalette_AgentProbeOcBaseline(prov, false)
        CommandPalette_AgentLogOcBaseline(ocStart, "dispatch_start")
        SetTimer(CommandPalette_AgentProbeOcBaselineDeferred.Bind(prov), -1)
    }
    CommandPalette_AgentTagFtbSession(reqId, cardId, q, prov)
    transport := CommandPalette_AgentResolveAgentTransport(cardId, q)
    CommandPalette_AgentLockAgentTransport(cardId, transport)
    sessionRef := CommandPalette_AgentResolveSessionRef(cardId)
    if (sessionRef = "" || (transport = "adapter" && InStr(sessionRef, "niuma-cp-"))) {
        sessionRef := CommandPalette_AgentPaletteSessionKeyForTransport(cardId, transport)
        if (card is Map)
            card["sessionRef"] := sessionRef
    }
    if (transport = "adapter") && FuncExists("Nmer_WailsBridgeHealthy") && Nmer_WailsBridgeHealthy() {
        CommandPalette_AgentPushStreamStatus(cardId, reqId, "🔌 OpenClaw Adapter 通道…")
        if CommandPalette_AgentDispatchViaOpenClawAdapter(cardId, reqId, q, sessionRef) {
            CommandPalette_AgentRegisterAiRoute(reqId, cardId, gen)
            CommandPalette_AgentMarkStreamDispatched(cardId, false)
            return
        }
    }
    if (sessionRef = "")
        sessionRef := CommandPalette_AgentPrefetchOpenClawSessionRef(cardId)
    if (sessionRef = "")
        sessionRef := CommandPalette_AgentResolveSessionRef(cardId)
    if FuncExists("FloatingToolbarWails_EnsureShellForAgent")
        try FloatingToolbarWails_EnsureShellForAgent(false)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    ftbReady := false
    if FuncExists("PaletteAgent_FtbTransportReady") && (PaletteAgent_FtbTransportReady() != "")
        ftbReady := true
    else if (IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        ftbReady := true
    if ftbReady {
        sysPrompt := CommandPalette_AgentBuildSystemPrompt(card)
        routeId1 := Trim(String(card.Get("routeId", "")))
        if (routeId1 != "") {
            try CommandPalette_AgentDebugTrace("route", "prompt_inject", "route=" . routeId1 . " len=" . StrLen(sysPrompt), "info")
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        }
        agentPayload := Map(
            "type", "host_palette_agent_stream",
            "reqId", reqId,
            "cardId", cardId,
            "query", q,
            "provider", prov,
            "systemPrompt", sysPrompt,
            "sessionRef", sessionRef,
            "openDrawer", false
        )
        streamOk := CommandPalette_AgentDeliverStreamPayload(agentPayload)
        scriptOk := false
        if !streamOk {
            try scriptOk := CommandPalette_InvokeFtbPaletteAgentScript(cardId, reqId, q, prov, sessionRef)
            catch {
                scriptOk := false
            }
        }
        if (streamOk || scriptOk) {
            SetTimer(CommandPalette_AgentPaletteStreamScriptBackup.Bind(cardId, reqId, q, prov, sessionRef), -2500)
        }
        CommandPalette_AgentLog("dispatch_ai_paths", "agent=" . (streamOk ? 1 : 0) . " script=" . (scriptOk ? 1 : 0) . " compose=0")
        try CommandPalette_AgentDebugTrace("ftb", "agent_dispatch", "card=" . cardId . " agent=" . (streamOk ? 1 : 0) . " script=" . (scriptOk ? 1 : 0), "info")
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        if (streamOk || scriptOk) {
            CommandPalette_AgentMarkStreamDispatched(cardId, false)
            CommandPalette_AgentPushStreamStatus(cardId, reqId, "📡 已派发至 " . provLabel . " 代理通道…")
            return
        }
        ocFail := CommandPalette_AgentProbeOcBaseline(prov, true)
        CommandPalette_AgentLogOcBaseline(ocFail, "dispatch_paths_fail")
        if CommandPalette_AgentTryDispatchHubFallback(cardId, reqId, q, prov, sessionRef, "🔌 hub 回退（FTB 派发失败）…") {
            CommandPalette_AgentRegisterAiRoute(reqId, cardId, gen)
            return
        }
    }
    if !ftbReady {
        hubMsg := (tryN = 0)
            ? "🔌 hub 通道（FTB 未就绪，直送 OpenClaw）…"
            : "🔌 hub 回退通道（FTB 未就绪）…"
        if CommandPalette_AgentTryDispatchHubFallback(cardId, reqId, q, prov, sessionRef, hubMsg) {
            CommandPalette_AgentRegisterAiRoute(reqId, cardId, gen)
            return
        }
    }
    if (tryN = 0 || Mod(tryN, 8) = 0)
        CommandPalette_AgentPushStreamStatus(cardId, reqId, "⏳ 等待 Niuma 引擎就绪 (" . (tryN + 1) . ")…")
    if (tryN >= 24) {
        ocExhausted := CommandPalette_AgentProbeOcBaseline(prov, true)
        CommandPalette_AgentLogOcBaseline(ocExhausted, "dispatch_exhausted")
        CommandPalette_AgentPushError(reqId, cardId, CommandPalette_AgentOcUserMessage(ocExhausted, provLabel))
        CommandPalette_AgentClearAiRoute(reqId)
        return
    }
    SetTimer(CommandPalette_AgentDispatchRetry.Bind(cardId, reqId, q, prov, gen, tryN + 1), -380)
}

CommandPalette_AgentDispatchStream(cardId, reqId, query, provider, gen, kind) {
    CommandPalette_AgentDispatchViaAiStream(cardId, reqId, query, provider, gen, 0)
}

CommandPalette_AgentComposeBackup(cardId, reqId, query, provider) {
    ; 已废弃：compose 兜底会在 Niuma Chat 重复发用户词，且与直连 OpenClaw 冲突
}

CommandPalette_AgentDispatchStreamRetry(payload, tryN) {
    if !(payload is Map)
        return
    CommandPalette_AgentDispatchViaAiStream(
        String(payload.Get("cardId", "")),
        String(payload.Get("reqId", "")),
        String(payload.Get("query", "")),
        String(payload.Get("provider", "openclaw")),
        0,
        Integer(tryN)
    )
}

CommandPalette_AgentArmStreamWatchdog(cardId) {
    SetTimer(CommandPalette_AgentStreamWatchdogTick.Bind(cardId), -15000)
}

CommandPalette_AgentStreamIdleLimitMs(card) {
    if !(card is Map)
        return 120000
    prov := String(card.Get("provider", "openclaw"))
    if (prov = "openclaw" || prov = "hermes")
        return 180000
    return 120000
}

CommandPalette_AgentFtbSessionStillSending(reqId, cacheMs := 2500) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_Agent_ShellSendingReqIds, g_Agent_FtbSendingCache
    rid := Trim(String(reqId))
    if (rid = "")
        return false
    if IsObject(g_Agent_FtbSendingCache) && g_Agent_FtbSendingCache.Has(rid) {
        ent := g_Agent_FtbSendingCache[rid]
        if (ent is Map) && (A_TickCount - Integer(ent.Get("tick", 0)) < Max(500, Integer(cacheMs)))
            return !!ent.Get("sending", false)
    }
    if FuncExists("CommandPalette_FtbTransportMode") && (CommandPalette_FtbTransportMode() = "wails_shell") {
        if IsObject(g_Agent_ShellSendingReqIds) && g_Agent_ShellSendingReqIds.Has(rid)
            return true
        return false
    }
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return false
    if !FuncExists("CommandPalette_JsEscapeForParse")
        return false
    argsJson := "{}"
    try argsJson := Jxon_Dump(Map("reqId", rid))
    catch {
        return false
    }
    escaped := CommandPalette_JsEscapeForParse(argsJson)
    js := "(function(){try{var o=JSON.parse('" . escaped . "');"
        . "var fn=window.paletteIsSessionSendingForAgentReqId;"
        . "if(typeof fn!=='function')return JSON.stringify({ok:0});"
        . "return JSON.stringify({ok:1,sending:!!fn(o.reqId)});"
        . "}catch(e){return JSON.stringify({ok:0});}})();"
    sending := false
    try {
        raw := g_FTB_WV2.ExecuteScriptAsync(js).await(600)
        data := FuncExists("CommandPalette_ParseScriptJson") ? CommandPalette_ParseScriptJson(raw) : Map()
        if (data is Map) && data.Get("ok", false)
            sending := !!data.Get("sending", false)
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if !IsObject(g_Agent_FtbSendingCache)
        g_Agent_FtbSendingCache := Map()
    g_Agent_FtbSendingCache[rid] := Map("sending", sending, "tick", A_TickCount)
    return sending
}

CommandPalette_AgentStreamWatchdogTick(cardId) {
    global g_Agent_Cards, g_Agent_CancelToken
    if (g_Agent_CancelToken)
        return
    card := CommandPalette_AgentGetCard(cardId)
    if !(card is Map) || card.Get("ended", false) || !card.Get("running", false)
        return
    cid := String(card.Get("cardId", cardId))
    rid := String(card.Get("reqId", ""))
    now := A_TickCount
    lastSub := Integer(card.Get("lastSubstantiveChunkTick", 0))
    dispatchTick := Integer(card.Get("dispatchTick", 0))
    idleFrom := lastSub > 0 ? lastSub : (dispatchTick > 0 ? dispatchTick : now)
    idleMs := now - idleFrom
    idleLimit := CommandPalette_AgentStreamIdleLimitMs(card)
    dispatched := !!card.Get("streamDispatched", false)
    rawLen := StrLen(String(card.Get("rawAnswer", "")))
    if (!dispatched && dispatchTick > 0 && (now - dispatchTick > 45000)) {
        prov := String(card.Get("provider", "openclaw"))
        pl := (prov = "hermes") ? "Hermes" : "龙虾 OpenClaw"
        CommandPalette_AgentPushError(rid, cid, "引擎未启动：请先打开牛马悬浮栏，并在设置里对「" . pl . "」点一键连接")
        return
    }
    if (dispatched && rawLen < 1 && idleMs > 90000 && !CommandPalette_AgentFtbSessionStillSending(rid)) {
        q := CommandPalette_AgentResolveCardQuery(card)
        prov := CommandPalette_AgentSanitizeProvider(String(card.Get("provider", "openclaw")))
        if (q != "" && !card.Get("redispatchTried", false)) {
            card["redispatchTried"] := true
            card["streamDispatched"] := false
            CommandPalette_AgentPushStreamStatus(cid, rid, "🔁 派发未送达，正在重试直连 Niuma Chat…")
            CommandPalette_AgentWireLog("dispatch_redispatch", "card=" . cid . " req=" . rid)
            gen := Integer(card.Get("gen", 0))
            SetTimer(CommandPalette_AgentDispatchViaAiStream.Bind(cid, rid, q, prov, gen, 0), -200)
            return
        }
    }
    if (dispatched && rawLen < 1 && idleMs > idleLimit) {
        if CommandPalette_AgentFtbSessionStillSending(rid) {
            CommandPalette_AgentArmStreamWatchdog(cid)
            return
        }
        q := CommandPalette_AgentResolveCardQuery(card)
        sessionRef := Trim(String(card.Get("sessionRef", "")))
        ans := (q != "") ? CommandPalette_AgentFetchAnswerFromFtb(rid, q, cid, sessionRef, 8000) : ""
        if (ans != "" && !CommandPalette_AgentFetchAnswerLooksStaleForCard(card, ans)) {
            CommandPalette_OnNiumaPaletteAgentEnd(Map("reqId", rid, "cardId", cid, "answer", ans))
            return
        }
        CommandPalette_AgentPushError(rid, cid, "引擎超时无响应：请检查 OpenClaw/Hermes 网关是否在运行")
        return
    }
    if (dispatched && !card.Get("ended", false))
        CommandPalette_AgentArmStreamWatchdog(cid)
}

CommandPalette_AgentSessionMatches(reqId, cardId := "") {
    global g_Agent_Cards
    rid := Trim(String(reqId))
    cid := Trim(String(cardId))
    for id, c in g_Agent_Cards {
        if !(c is Map)
            continue
        if (cid != "" && id != cid)
            continue
        if Trim(String(c.Get("reqId", ""))) = rid
            return c
    }
    return 0
}

CommandPalette_OnNiumaPaletteAgentChunk(msg) {
    global g_Agent_Cards, g_CardSessionMap
    if !(msg is Map)
        return
    reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
    cardId := msg.Has("cardId") ? String(msg["cardId"]) : ""
    delta := msg.Has("delta") ? String(msg["delta"]) : (msg.Has("text") ? String(msg["text"]) : "")
    card := CommandPalette_AgentSessionMatches(reqId, cardId)
    if !(card is Map) && reqId != "" {
        for id, c in g_Agent_Cards {
            if (c is Map) && Trim(String(c.Get("reqId", ""))) = reqId {
                card := c
                if (cardId = "")
                    cardId := id
                break
            }
        }
    }
    if !(card is Map) {
        if FuncExists("CommandPalette_AgentDebugTrace")
            try CommandPalette_AgentDebugTrace("ahk", "chunk_no_card", "req=" . reqId . " card=" . cardId, "warn")
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        return
    }
    if CommandPalette_AgentCardIsOfficialA2uiRoute(card)
        return
    if card.Get("ended", false)
        return
    if CommandPalette_AgentIsStatusOnlyDelta(delta)
        card["liveThought"] := Trim(delta)
    if !CommandPalette_AgentIsStatusOnlyDelta(delta) {
        priorRaw := Trim(String(card.Get("priorRawAnswer", "")))
        prev := String(card.Get("rawAnswer", ""))
        if (prev = "")
            card["rawAnswer"] := CommandPalette_AgentClipText(delta)
        else if (priorRaw != "" && InStr(delta, priorRaw) = 1)
            card["rawAnswer"] := CommandPalette_AgentClipText(SubStr(delta, StrLen(priorRaw) + 1))
        else if (InStr(delta, prev) = 1)
            card["rawAnswer"] := CommandPalette_AgentClipText(delta)
        else if (InStr(prev, delta) = 1)
            card["rawAnswer"] := prev
        else if (InStr(prev, delta) > 0)
            card["rawAnswer"] := prev
        else
            card["rawAnswer"] := CommandPalette_AgentClipText(prev . delta)
        card["lastSubstantiveChunkTick"] := A_TickCount
        lt := Trim(SubStr(String(card.Get("rawAnswer", "")), 1, 120))
        if (lt != "")
            card["liveThought"] := lt . (StrLen(String(card.Get("rawAnswer", ""))) > 120 ? "…" : "")
    }
    card["lastChunkTick"] := A_TickCount
    card["streamDispatched"] := true
    card["updatedAt"] := A_Now
    if (cardId = "")
        cardId := String(card.Get("cardId", ""))
    if msg.Has("sessionRef") {
        sr := Trim(String(msg["sessionRef"]))
        if (sr != "") {
            card["sessionRef"] := sr
            g_CardSessionMap[cardId] := sr
        }
    }
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_chunk",
            "cardId", cardId,
            "reqId", reqId,
            "delta", delta,
            "liveThought", String(card.Get("liveThought", "")),
            "sessionRef", String(card.Get("sessionRef", ""))
        ))
}

CommandPalette_OnNiumaPaletteAgentEnd(msg) {
    global g_Agent_Cards, g_CardSessionMap, g_Agent_ShellSendingReqIds
    if !(msg is Map)
        return
    reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
    cardId := msg.Has("cardId") ? String(msg["cardId"]) : ""
    if (reqId != "") && IsObject(g_Agent_ShellSendingReqIds)
        g_Agent_ShellSendingReqIds.Delete(reqId)
    card := CommandPalette_AgentSessionMatches(reqId, cardId)
    if !(card is Map)
        return
    if CommandPalette_AgentCardIsOfficialA2uiRoute(card) {
        try CommandPalette_AgentDebugTrace("adapter", "end_skip_prose", "card=" . cardId, "info")
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        return
    }
    ans := msg.Has("answer") ? String(msg["answer"]) : String(card.Get("rawAnswer", ""))
    if !CommandPalette_AgentAnswerIsSubstantial(ans)
        return
    if CommandPalette_AgentFetchAnswerLooksStaleForCard(card, ans)
        return
    if card.Get("ended", false) {
        prev := Trim(String(card.Get("rawAnswer", "")))
        newAns := Trim(ans)
        gatewayLonger := (StrLen(newAns) > StrLen(prev) + 40)
        if !gatewayLonger && CommandPalette_AgentAnswerIsSubstantial(prev) && StrLen(prev) >= StrLen(newAns) {
            if !(CommandPalette_AgentAnswerTextLooksIncomplete(prev) && !CommandPalette_AgentAnswerTextLooksIncomplete(newAns))
                && !(StrLen(newAns) >= 800 && StrLen(newAns) > StrLen(prev))
                return
        }
    }
    card["rawAnswer"] := ans
    card["priorRawAnswer"] := ""
    card["ended"] := true
    card["running"] := false
    card["uiState"] := "Done"
    card["error"] := ""
    card["heartbeatTick"] := 0
    card["updatedAt"] := A_Now
    if (cardId = "")
        cardId := String(card.Get("cardId", ""))
    if msg.Has("sessionRef") {
        sr := Trim(String(msg["sessionRef"]))
        if (sr != "") {
            card["sessionRef"] := sr
            g_CardSessionMap[cardId] := sr
        }
    }
    CommandPalette_AgentPersistCards()
    qSync := FuncExists("CommandPalette_AgentResolveCardQuery")
        ? CommandPalette_AgentResolveCardQuery(card)
        : Trim(String(card.Get("query", card.Get("title", ""))))
    srSync := String(card.Get("sessionRef", ""))
    if FuncExists("CommandPalette_AgentSyncNiumaSession")
        SetTimer(CommandPalette_AgentSyncNiumaSession.Bind(reqId, cardId, qSync, srSync, ans), -50)
    if FuncExists("CommandPalette_AgentRecoverCardAnswer")
        && (CommandPalette_AgentAnswerLooksIncomplete(card)
            || (FuncExists("Nmer_PaletteOpenClawAnswerSync") && Nmer_PaletteOpenClawAnswerSync()
                && String(card.Get("provider", "openclaw")) = "openclaw"))
        SetTimer(CommandPalette_AgentRecoverCardAnswer.Bind(Map(
            "cardId", cardId,
            "reqId", reqId,
            "query", qSync,
            "sessionRef", srSync
        )), -2500)
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_end",
            "cardId", cardId,
            "reqId", reqId,
            "answer", ans,
            "sessionRef", srSync,
            "query", qSync
        ))
    SetTimer(CommandPalette_AgentPushCardSync, -600)
    if (cardId != "") && FuncExists("CommandPalette_AgentPushCardDetail")
        && !(FuncExists("Nmer_PaletteStateStoreEnabled") && Nmer_PaletteStateStoreEnabled())
        SetTimer(CommandPalette_AgentPushCardDetail.Bind(cardId), -120)
}

CommandPalette_AgentPushError(reqId, cardId, message) {
    card := CommandPalette_AgentSessionMatches(reqId, cardId)
    if (card is Map) {
        card["ended"] := true
        card["running"] := false
        card["uiState"] := "Done"
        card["error"] := String(message)
        card["liveThought"] := ""
        card["heartbeatTick"] := 0
        card["updatedAt"] := A_Now
        CommandPalette_AgentPersistCards()
    }
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_error",
            "cardId", cardId,
            "reqId", reqId,
            "message", String(message)
        ))
    CommandPalette_AgentPushCardSync()
}

CommandPalette_OnNiumaPaletteAgentError(msg) {
    global g_Agent_ShellSendingReqIds
    if !(msg is Map)
        return
    rid := msg.Has("reqId") ? String(msg["reqId"]) : ""
    if (rid != "") && IsObject(g_Agent_ShellSendingReqIds)
        g_Agent_ShellSendingReqIds.Delete(rid)
    CommandPalette_AgentPushError(
        rid,
        msg.Has("cardId") ? String(msg["cardId"]) : "",
        msg.Has("message") ? String(msg["message"]) : "代理请求失败"
    )
}

CommandPalette_AgentCancelPriorStreamForCard(cardId) {
    cid := Trim(String(cardId))
    if (cid = "")
        return
    card := CommandPalette_AgentGetCard(cid)
    if !(card is Map)
        return
    rid := Trim(String(card.Get("reqId", "")))
    if (rid = "")
        return
    CommandPalette_AgentClearAiRoute(rid)
    if FuncExists("CommandPalette_DeliverFtbPayload") {
        try CommandPalette_DeliverFtbPayload(Map("type", "host_palette_agent_stream_cancel", "reqId", rid, "cardId", cid))
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
}

CommandPalette_AgentCancelOtherStreams(keepCardId := "") {
    global g_Agent_Cards
    keep := Trim(String(keepCardId))
    if FuncExists("CommandPalette_DeliverFtbPayload") {
        try CommandPalette_DeliverFtbPayload(Map("type", "palette_agent_prepare_new", "cardId", keep))
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    for id, c in g_Agent_Cards {
        if !(c is Map) || id = keep
            continue
        if !c.Get("running", false) || c.Get("ended", false)
            continue
        rid := String(c.Get("reqId", ""))
        if (rid = "") || !FuncExists("CommandPalette_DeliverFtbPayload")
            continue
        try CommandPalette_DeliverFtbPayload(Map(
            "type", "host_palette_agent_stream_cancel",
            "reqId", rid,
            "cardId", id
        ))
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
}

CommandPalette_AgentCancelDeliverFtb(reqId, cardId) {
    rid := Trim(String(reqId))
    cid := Trim(String(cardId))
    if (rid = "") || !FuncExists("CommandPalette_DeliverFtbPayload")
        return
    try CommandPalette_DeliverFtbPayload(Map("type", "host_palette_agent_stream_cancel", "reqId", rid, "cardId", cid))
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try CommandPalette_DeliverFtbPayload(Map("type", "host_palette_ai_stream_cancel", "reqId", rid))
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

CommandPalette_AgentCancel(cardId := "") {
    global g_Agent_CancelToken, g_Agent_Cards, g_Agent_ActiveCardId
    g_Agent_CancelToken := true
    cid := Trim(String(cardId))
    if (cid = "")
        cid := g_Agent_ActiveCardId
    card := CommandPalette_AgentGetCard(cid)
    reqId := (card is Map) ? String(card.Get("reqId", "")) : ""
    if (card is Map) {
        card["running"] := false
        card["ended"] := true
        card["uiState"] := "Done"
        card["error"] := "已取消"
        card["updatedAt"] := A_Now
        CommandPalette_AgentPersistCards()
    }
    if (reqId != "") && FuncExists("CommandPalette_DeliverFtbPayload") {
        SetTimer(CommandPalette_AgentCancelDeliverFtb.Bind(reqId, cid), -1)
    }
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_status",
            "cardId", cid,
            "message", "任务已取消",
            "status", "cancelled"
        ))
    SetTimer(CommandPalette_AgentPushCardSync, -1)
    SetTimer(() => (g_Agent_CancelToken := false), -800)
}

CommandPalette_AgentStampAgeSec(stamp) {
    s := Trim(String(stamp))
    if (StrLen(s) < 14)
        return 999999
    try {
        now := A_Now
        cardDay := SubStr(s, 1, 8)
        nowDay := SubStr(now, 1, 8)
        if (nowDay < cardDay)
            return 0
        if (nowDay != cardDay)
            return 999999
        nowSec := Integer(SubStr(now, 9, 2)) * 3600 + Integer(SubStr(now, 11, 2)) * 60 + Integer(SubStr(now, 13, 2))
        cardSec := Integer(SubStr(s, 9, 2)) * 3600 + Integer(SubStr(s, 11, 2)) * 60 + Integer(SubStr(s, 13, 2))
        return Max(0, nowSec - cardSec)
    } catch {
        return 999999
    }
}

CommandPalette_AgentReconcileStaleRunningCards(maxAgeSec := 180) {
    global g_Agent_Cards
    changed := false
    maxAgeSec := Max(60, Integer(maxAgeSec))
    for cid, card in g_Agent_Cards {
        if !(card is Map) || card.Get("ended", false) || !card.Get("running", false)
            continue
        age := CommandPalette_AgentStampAgeSec(String(card.Get("updatedAt", card.Get("createdAt", ""))))
        if (age <= maxAgeSec)
            continue
        card["running"] := false
        card["ended"] := true
        card["uiState"] := "Done"
        if Trim(String(card.Get("error", ""))) = ""
            card["error"] := "任务已超时（自动结束）"
        card["liveThought"] := ""
        card["heartbeatTick"] := 0
        card["updatedAt"] := A_Now
        changed := true
        CommandPalette_AgentLog("stale_end", "card=" . cid . " ageSec=" . age)
    }
    if changed
        CommandPalette_AgentPersistCards()
    return changed
}

CommandPalette_AgentOnReady() {
    CommandPalette_AgentLoadCards()
    CommandPalette_AgentReconcileStaleRunningCards()
    global g_CmdPal_Visible
    if FuncExists("CommandPalette_PushToWeb") && g_CmdPal_Visible {
        try CommandPalette_PushToWeb(Map("type", "palette_show"))
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    SetTimer(CommandPalette_AgentPushCardSync, -180)
}

CommandPalette_AgentOnPull(*) {
    CommandPalette_AgentLoadCards(true)
    SetTimer(CommandPalette_AgentPushCardSync, -20)
}

CommandPalette_DispatchPhysicalAction(actionType, actionArgs, cardId := "") {
    global g_Agent_CancelToken
    if (g_Agent_CancelToken)
        return
    SetTimer(CommandPalette_ExecutePhysicalStep.Bind(actionType, actionArgs, cardId), -10)
}

CommandPalette_ExecutePhysicalStep(actionType, actionArgs, cardId := "") {
    global g_Agent_CancelToken
    if (g_Agent_CancelToken) {
        CommandPalette_AgentLog("physical_cancel", "card=" . cardId)
        return
    }
    at := Trim(String(actionType))
    status := "success"
    detail := ""
    try {
        if (at = "click" || at = "click_dom") {
            x := 0
            y := 0
            if (IsObject(actionArgs)) {
                if actionArgs.Has("x")
                    x := Integer(actionArgs["x"])
                if actionArgs.Has("y")
                    y := Integer(actionArgs["y"])
            }
            if (x > 0 && y > 0)
                Click(x, y)
            else
                status := "error", detail := "invalid_coords"
        } else if (at = "send_keys" || at = "keys") {
            keys := IsObject(actionArgs) && actionArgs.Has("keys") ? String(actionArgs["keys"]) : ""
            if (keys != "")
                Send(keys)
            else
                status := "error", detail := "empty_keys"
        } else {
            status := "error"
            detail := "unknown_action:" . at
        }
    } catch as ePh {
        status := "error"
        detail := ePh.Message
    }
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map(
            "type", "PALETTE_PHYSICAL_FEEDBACK",
            "cardId", String(cardId),
            "status", status,
            "detail", detail,
            "actionType", at
        ))
}

CommandPalette_HandleAgentSubmit(msg) {
    CommandPalette_AgentWireLog("handle_submit", "text=" . SubStr(String(msg.Has("text") ? msg["text"] : ""), 1, 60))
    try CommandPalette_AgentDebugTrace("ahk", "handle_submit", "via=host", "info")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return CommandPalette_AgentSubmit(msg)
}

CommandPalette_HandleAgentCancel(msg) {
    cid := msg.Has("cardId") ? String(msg["cardId"]) : ""
    CommandPalette_AgentCancel(cid)
}

CommandPalette_HandleAgentDismiss(msg) {
    global g_Agent_Cards, g_CardSessionMap, g_Agent_ActiveCardId
    cid := Trim(String(msg.Has("cardId") ? msg["cardId"] : ""))
    if (cid = "")
        return
    if IsObject(g_Agent_Cards) && g_Agent_Cards.Has(cid)
        g_Agent_Cards.Delete(cid)
    if IsObject(g_CardSessionMap) && g_CardSessionMap.Has(cid)
        g_CardSessionMap.Delete(cid)
    if (g_Agent_ActiveCardId = cid)
        g_Agent_ActiveCardId := ""
    CommandPalette_AgentPersistCards()
    if FuncExists("CommandPalette_AgentPushCardSync")
        CommandPalette_AgentPushCardSync()
}

CommandPalette_HandleAgentPhysical(msg) {
    at := msg.Has("actionType") ? String(msg["actionType"]) : ""
    args := msg.Has("args") && msg["args"] is Map ? msg["args"] : Map()
    cid := msg.Has("cardId") ? String(msg["cardId"]) : ""
    CommandPalette_DispatchPhysicalAction(at, args, cid)
}

; ---------- 动作托管链路诊断（UI 在 CommandPaletteSearchDebug 诊断窗「动作托管」标签）----------

global g_AgentDbg_Events := []
global g_AgentDbg_MaxEvents := 400
global g_AgentDbg_LastSubmit := Map()
global g_AgentDbg_PullCache := ""
global g_Agent_LastSubmitSig := ""
global g_Agent_LastSubmitCardId := ""
global g_Agent_LastSubmitTick := 0

CommandPalette_AgentDebug_Show(activate := true) {
    if FuncExists("CommandPalette_ShowSearchDebug")
        CommandPalette_ShowSearchDebug(activate, "agent")
}

CommandPalette_AgentDebug_ClearEvents() {
    global g_AgentDbg_Events
    g_AgentDbg_Events := []
    CommandPalette_AgentDebugPushToWeb(Map("type", "cp_agent_debug_clear_ok"))
}

CommandPalette_AgentDebug_RefreshPullCache() {
    global g_AgentDbg_PullCache
    try {
        g_AgentDbg_PullCache := Jxon_Dump(CommandPaletteSearchDebug_BuildAgentDebugPullPack())
    } catch {
        g_AgentDbg_PullCache := ""
    }
}

CommandPalette_AgentDebugTrace(layer, event, detail := "", level := "info", extra := 0) {
    global g_AgentDbg_Events, g_AgentDbg_MaxEvents
    lay := Trim(String(layer))
    if (lay = "")
        lay := "ahk"
    evt := Trim(String(event))
    if (evt = "")
        return
    row := Map(
        "t", A_TickCount,
        "ts", SubStr(A_Now, 1, 19),
        "layer", lay,
        "event", evt,
        "detail", SubStr(String(detail), 1, 1200),
        "level", Trim(String(level)) != "" ? String(level) : "info"
    )
    if (extra is Map) {
        for k, v in extra
            row[String(k)] := v
    }
    g_AgentDbg_Events.Push(row)
    while (g_AgentDbg_Events.Length > g_AgentDbg_MaxEvents)
        g_AgentDbg_Events.RemoveAt(1)
    try OutputDebug("[AgentDbg][" . lay . "][" . evt . "] " . SubStr(String(detail), 1, 240) . "`n")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    CommandPalette_AgentDebug_RefreshPullCache()
    if FuncExists("CommandPalette_SearchDebug_DbgReady") && CommandPalette_SearchDebug_DbgReady()
        SetTimer(CommandPalette_AgentDebug_PushSnapshot, -80)
}

CommandPalette_AgentDebugNoteSubmit(cardId, reqId, provider, bridgeRet := "") {
    global g_AgentDbg_LastSubmit, g_Agent_Cards
    q := ""
    if IsObject(g_Agent_Cards) && g_Agent_Cards.Has(cardId) {
        c := g_Agent_Cards[cardId]
        if (c is Map)
            q := SubStr(String(c.Get("query", c.Get("title", ""))), 1, 120)
    }
    routeId := ""
    routeLabel := ""
    if IsObject(g_Agent_Cards) && g_Agent_Cards.Has(cardId) {
        c1 := g_Agent_Cards[cardId]
        if (c1 is Map) {
            routeId := String(c1.Get("routeId", ""))
            routeLabel := String(c1.Get("routeLabel", ""))
        }
    }
    g_AgentDbg_LastSubmit := Map(
        "cardId", String(cardId),
        "reqId", String(reqId),
        "provider", String(provider),
        "query", q,
        "routeId", routeId,
        "routeLabel", routeLabel,
        "bridgeRet", SubStr(String(bridgeRet), 1, 200),
        "tick", A_TickCount,
        "at", SubStr(A_Now, 1, 19)
    )
    CommandPalette_AgentDebugTrace("ahk", "submit", "card=" . cardId . " req=" . reqId . " prov=" . provider . " bridge=" . SubStr(String(bridgeRet), 1, 80), "info")
    CommandPalette_AgentDebug_RefreshPullCache()
    if FuncExists("CommandPalette_SearchDebug_DbgReady") && CommandPalette_SearchDebug_DbgReady()
        SetTimer(CommandPalette_AgentDebug_PushSnapshot, -60)
}

CommandPalette_AgentDebugPushToWeb(payload) {
    if FuncExists("CommandPaletteSearchDebug_PushPayload")
        return CommandPaletteSearchDebug_PushPayload(payload)
    return false
}

CommandPalette_AgentDebug_FlushEvents(*) {
    global g_AgentDbg_Events
    if !(FuncExists("CommandPalette_SearchDebug_DbgReady") && CommandPalette_SearchDebug_DbgReady())
        return
    if !(g_AgentDbg_Events is Array) || g_AgentDbg_Events.Length < 1
        return
    batch := []
    for _, row in g_AgentDbg_Events
        if (row is Map)
            batch.Push(row)
    if (batch.Length < 1)
        return
    CommandPalette_AgentDebugPushToWeb(Map("type", "cp_agent_debug_events", "items", batch))
}

CommandPalette_AgentDebug_Tick(*) {
    active := false
    try active := CommandPalette_SearchDebug_IsAgentTabActive()
    catch {
        active := false
    }
    if !active {
        SetTimer(CommandPalette_AgentDebug_Tick, 0)
        return
    }
    CommandPalette_AgentDebug_PushSnapshot()
    CommandPalette_AgentDebug_FlushEvents()
}

CommandPalette_AgentDebug_PushSnapshot(*) {
    CommandPalette_AgentDebugPushToWeb(CommandPalette_AgentDebug_BuildSnapshot())
}

CommandPalette_AgentDebug_BuildSnapshot() {
    global g_CmdPal_WV2, g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_UI_Ready
    global g_Agent_Cards, g_Agent_AiRoute, g_Agent_ActiveCardId, g_AgentDbg_LastSubmit, g_AgentDbg_Events
    cards := []
    if IsObject(g_Agent_Cards) {
        for id, c in g_Agent_Cards {
            if !(c is Map)
                continue
            cards.Push(Map(
                "cardId", String(c.Get("cardId", id)),
                "reqId", String(c.Get("reqId", "")),
                "title", SubStr(String(c.Get("title", c.Get("query", ""))), 1, 80),
                "query", SubStr(String(c.Get("query", c.Get("title", ""))), 1, 120),
                "uiState", String(c.Get("uiState", "")),
                "provider", String(c.Get("provider", "")),
                "running", !!c.Get("running", false),
                "ended", !!c.Get("ended", false),
                "streamDispatched", !!c.Get("streamDispatched", false),
                "rawLen", StrLen(String(c.Get("rawAnswer", ""))),
                "error", SubStr(String(c.Get("error", "")), 1, 120),
                "routeId", String(c.Get("routeId", "")),
                "routeLabel", String(c.Get("routeLabel", "")),
                "representationRoute", String(c.Get("representationRoute", "")),
                "grayReason", (c.Has("officialA2uiRoute") && c["officialA2uiRoute"] is Map) ? String(c["officialA2uiRoute"].Get("reason", "")) : "",
                "blockCount", (c.Has("blockStore") && c["blockStore"] is Map && c["blockStore"].Has("blocks") && c["blockStore"]["blocks"] is Array) ? c["blockStore"]["blocks"].Length : 0
            ))
        }
    }
    routes := []
    if IsObject(g_Agent_AiRoute) {
        for rid, r in g_Agent_AiRoute {
            if (r is Map)
                routes.Push(Map("reqId", String(rid), "cardId", String(r.Get("cardId", ""))))
        }
    }
    cardN := IsObject(g_Agent_Cards) ? g_Agent_Cards.Count : 0
    evtN := (g_AgentDbg_Events is Array) ? g_AgentDbg_Events.Length : 0
    global g_CmdPal_AgentSubmitDispatch
    orchOk := IsSet(g_CmdPal_AgentSubmitDispatch) && g_CmdPal_AgentSubmitDispatch
    if !orchOk {
        try {
            ref := CommandPalette_AgentSubmit
            orchOk := !!ref
        } catch {
            orchOk := false
        }
    }
    snap := Map(
        "type", "cp_agent_debug_snapshot",
        "tick", A_TickCount,
        "health", Map(
            "cmdPalWv2", IsObject(g_CmdPal_WV2),
            "ftbWv2", IsObject(g_FTB_WV2),
            "ftbReady", !!g_FTB_WV2_Ready,
            "ftbFrame", !!g_FTB_WV2_FrameReady,
            "ftbUi", !!g_FTB_UI_Ready,
            "orchestrator", orchOk,
            "injectFn", true,
            "cardCount", cardN,
            "eventCount", evtN
        ),
        "activeCardId", String(g_Agent_ActiveCardId),
        "cards", cards,
        "routes", routes,
        "lastSubmit", (g_AgentDbg_LastSubmit is Map) ? g_AgentDbg_LastSubmit : Map(),
        "pipeline", (g_AgentDbg_PipelineState is Map) ? g_AgentDbg_PipelineState : Map()
    )
    return snap
}

CommandPalette_AgentDebug_TraceIfAgentReq(reqId, layer, event, detail := "", level := "info") {
    rid := Trim(String(reqId))
    if (rid = "")
        return
    isAgent := InStr(rid, "cpag") = 1
    if !isAgent && IsObject(g_Agent_AiRoute) && g_Agent_AiRoute.Has(rid)
        isAgent := true
    if !isAgent
        return
    CommandPalette_AgentDebugTrace(layer, event, detail, level)
}

CommandPalette_AgentDebug_TracePalettePush(payload) {
    if !(payload is Map)
        return
    typ := payload.Has("type") ? String(payload["type"]) : ""
    if (typ = "" || !InStr(typ, "palette_agent"))
        return
    if (typ = "palette_agent_card_sync")
        return
    cid := payload.Has("cardId") ? String(payload["cardId"]) : ""
    rid := payload.Has("reqId") ? String(payload["reqId"]) : ""
    det := ""
    if (cid != "")
        det .= "card=" . cid
    if (rid != "")
        det .= (det != "" ? " " : "") . "req=" . rid
    lay := "palette"
    evt := typ
    if (typ = "palette_agent_chunk") {
        lay := "palette"
        evt := "chunk"
        if payload.Has("delta")
            det .= (det != "" ? " " : "") . "Δ=" . SubStr(String(payload["delta"]), 1, 80)
    } else if (typ = "palette_agent_tool_event") {
        lay := "palette"
        evt := "tool_event"
        if payload.Has("tool")
            det .= (det != "" ? " " : "") . "tool=" . String(payload["tool"])
        if payload.Has("phase")
            det .= (det != "" ? " " : "") . "phase=" . String(payload["phase"])
        if payload.Has("text")
            det .= (det != "" ? " " : "") . "txt=" . SubStr(String(payload["text"]), 1, 80)
    } else if (typ = "palette_agent_status") {
        lay := "palette"
        evt := "status"
        if payload.Has("message")
            det .= (det != "" ? " " : "") . "msg=" . SubStr(String(payload["message"]), 1, 80)
    } else if (typ = "palette_agent_card_new") {
        evt := "card_new"
    } else if (typ = "palette_agent_end") {
        lay := "palette"
        evt := "end"
    } else if (typ = "palette_agent_error") {
        lay := "palette"
        evt := "error"
        if payload.Has("message")
            det .= (det != "" ? " " : "") . String(payload["message"])
    }
    if (det = "")
        det := typ
    CommandPalette_AgentDebugTrace(lay, evt, det, "info")
}

; 供 WebView hostObjects 桥接：避免 Func("…") 在 sync 上下文中误报不存在
global g_CmdPal_AgentSubmitDispatch := CommandPalette_HandleAgentSubmit
global g_CmdPal_AgentDebugTraceDispatch := CommandPalette_AgentDebugTrace
global g_CmdPal_AgentWireLogDispatch := CommandPalette_AgentWireLog

; 启动时从磁盘恢复历史任务卡；若曾持久化失败则从 trace 日志一次性重建
try CommandPalette_AgentLoadCards()
try CommandPalette_AgentRecoverCardsIfEmpty()
if FuncExists("CommandPalette_AgentBootstrapNiumaSessions")
    SetTimer(CommandPalette_AgentBootstrapNiumaSessions, -12000)
