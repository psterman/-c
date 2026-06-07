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
global g_AgentDbg_PipelineState := Map()

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
    } catch {
    }
}

CommandPalette_AgentLog(event, detail := "") {
    line := "[" . A_Now . "][agent][" . event . "] " . String(detail)
    try OutputDebug(line . "`n")
    catch {
    }
    if FuncExists("NMER_Log") {
        try NMER_Log("cmdpal_agent", event, String(detail))
        catch {
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
        catch {
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
    if !(card is Map)
        return Map()
    dto := Map(
        "cardId", String(card.Get("cardId", "")),
        "reqId", String(card.Get("reqId", "")),
        "gen", Integer(card.Get("gen", 0)),
        "uiState", String(card.Get("uiState", "Planning")),
        "title", String(card.Get("title", card.Get("query", ""))),
        "query", String(card.Get("query", card.Get("title", ""))),
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
        "blockCount", 0
    )
    if card.Has("blockStore") && card["blockStore"] is Map {
        bs := card["blockStore"]
        dto["blockStore"] := bs
        if bs.Has("blocks") && bs["blocks"] is Array
            dto["blockCount"] := bs["blocks"].Length
    }
    return dto
}

CommandPalette_AgentPersistCards() {
    global g_Agent_Cards
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
        CommandPalette_AgentLog("persist_ok", "n=" . arr.Length . " path=" . path)
    } catch as eP {
        CommandPalette_AgentLog("persist_err", path . " :: " . eP.Message)
    }
}

CommandPalette_AgentLoadCards() {
    global g_Agent_Cards, g_CardSessionMap
    if FuncExists("Nmer_EnsureDebugDir")
        try Nmer_EnsureDebugDir()
    path := CommandPalette_AgentCardsPath()
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
            if Trim(String(dto.Get("sessionRef", ""))) != ""
                g_CardSessionMap[cid] := String(dto.Get("sessionRef", ""))
        }
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
        catch {
        }
    return p
}

CommandPalette_AgentSanitizeProvider(prov) {
    p := Trim(StrLower(String(prov)))
    if (p = "" || p = "new" || p = "append" || p = "correction")
        return CommandPalette_AgentDefaultProvider()
    if FuncExists("CommandPalette_NormalizeAiProvider")
        try p := CommandPalette_NormalizeAiProvider(p)
        catch {
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
    CommandPalette_AgentPushCardNew(card)
    if FuncExists("CommandPalette_PushToWeb") {
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_status",
            "cardId", cid,
            "reqId", rid,
            "message", "正在连接 " . provLabel . "…",
            "status", "loading"
        ))
        CommandPalette_AgentPushStreamStatus(cid, rid, "🔗 任务已提交，正在拉起 " . provLabel . "…")
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
            catch {
            }
        if (delta != "")
            CommandPalette_OnNiumaPaletteAgentChunk(Map("reqId", reqId, "cardId", cardId, "delta", delta))
    } else if (kind = "end") {
        ans := msg.Has("answer") ? String(msg["answer"]) : ""
        if FuncExists("CommandPalette_AgentDebugTrace")
            try CommandPalette_AgentDebugTrace("ftb", "forward_end", "req=" . reqId . " len=" . StrLen(ans))
            catch {
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
        items := []
        for _, c in g_Agent_Cards {
            if !(c is Map)
                continue
            try items.Push(CommandPalette_AgentCardToSyncDto(c))
            catch {
            }
        }
        return Jxon_Dump(items)
    } catch {
        return "[]"
    }
}

CommandPalette_AgentPushCardSync() {
    global g_Agent_Cards
    items := []
    for _, c in g_Agent_Cards {
        if (c is Map)
            items.Push(CommandPalette_AgentCardToSyncDto(c))
    }
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map("type", "palette_agent_card_sync", "cards", items))
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
    n := 0
    if store.Has("blocks") && store["blocks"] is Array
        n := store["blocks"].Length
    CommandPalette_AgentPersistCards()
    if FuncExists("CommandPalette_AgentDebugTrace") {
        try CommandPalette_AgentDebugTrace("ahk", "block_store_persist", "card=" . cid . " n=" . n, "info")
        catch {
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
                catch {
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
    catch {
    }
    cardId := msg.Has("cardId") ? Trim(String(msg["cardId"])) : ""
    prov := CommandPalette_AgentSanitizeProvider(msg.Has("provider") ? msg["provider"] : "")
    routeId := msg.Has("routeId") ? Trim(String(msg["routeId"])) : ""
    routeLabel := msg.Has("routeLabel") ? Trim(String(msg["routeLabel"])) : ""
    promptAddon := msg.Has("promptAddon") ? Trim(String(msg["promptAddon"])) : ""
    routeConfidence := msg.Has("routeConfidence") ? String(msg["routeConfidence"]) : ""
    if (routeId != "") {
        try CommandPalette_AgentDebugTrace("route", "pipeline_route", "id=" . routeId . " conf=" . routeConfidence, "info")
        catch {
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
            g_Agent_ActiveCardId := cardId
            g_Agent_StreamGen++
            gen := g_Agent_StreamGen
            reqId := CommandPalette_AgentNewId("cpag")
            card["reqId"] := reqId
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
            CommandPalette_AgentPersistCards()
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
            catch {
            }
            return ret
        }
    }

    if FuncExists("CommandPalette_BootstrapNiumaChat")
        try CommandPalette_BootstrapNiumaChat("agent_submit", false)
        catch {
        }
    if FuncExists("StartWebViewWarmup")
        try StartWebViewWarmup()
        catch {
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
        "updatedAt", A_Now
    )
    g_Agent_Cards[cardId] := card
    g_CardSessionMap[cardId] := paletteSr
    g_Agent_ActiveCardId := cardId
    g_Agent_LastSubmitSig := sig
    g_Agent_LastSubmitCardId := cardId
    g_Agent_LastSubmitTick := A_TickCount
    CommandPalette_AgentPersistCards()
    CommandPalette_AgentRegisterAiRoute(reqId, cardId, gen)
    CommandPalette_AgentFlushUi(card)
    CommandPalette_AgentPushCardSync()
    CommandPalette_AgentArmHeartbeat(cardId)
    CommandPalette_AgentScheduleDispatch(cardId, reqId, text, prov, gen, 0)
    ret := Map("ok", true, "cardId", cardId, "reqId", reqId, "provider", prov, "title", title, "query", text)
    try CommandPalette_AgentDebugNoteSubmit(cardId, reqId, prov, "post")
    catch {
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

CommandPalette_AgentLooksLikeThinkingPreamble(ans) {
    raw := Trim(String(ans))
    if (raw = "")
        return false
    if RegExMatch(raw, "m)^(\d+[.)]\s|[-*•]\s|\*\*[^*]+\*\*|#{1,3}\s)")
        return false
    if (StrLen(raw) >= 400)
        return false
    if RegExMatch(raw, "i)(让我先|我先想|我先查|让我查|比较靠谱|想想到底|查一下|let me (check|think|search)|i('ll| will) (check|search|look))")
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

CommandPalette_AgentHasSubstantialAnswer(card) {
    if !(card is Map)
        return false
    return CommandPalette_AgentAnswerIsSubstantial(String(card.Get("rawAnswer", "")))
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
    slug := RegExReplace(String(cardId), "i)^card[-_]?", "")
    slug := RegExReplace(slug, "[^a-zA-Z0-9_-]", "-")
    slug := Trim(slug, "-")
    if (slug = "")
        slug := "task"
    return "agent:main:niuma-cp-" . slug
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
    } catch {
    }
    return sr
}

CommandPalette_InvokeFtbPaletteAgentScript(cardId, reqId, query, provider, sessionRef := "") {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return false
    if !FuncExists("CommandPalette_JsEscapeForParse")
        return false
    prov := CommandPalette_AgentSanitizeProvider(provider)
    sr := Trim(String(sessionRef))
    if (sr = "")
        sr := CommandPalette_AgentResolveSessionRef(cardId)
    card := CommandPalette_AgentGetCard(cardId)
    sysPrompt := CommandPalette_AgentBuildSystemPrompt(card)
    routeId0 := (card is Map) ? Trim(String(card.Get("routeId", ""))) : ""
    if (routeId0 != "") {
        try CommandPalette_AgentDebugTrace("route", "prompt_inject", "route=" . routeId0 . " len=" . StrLen(sysPrompt), "info")
        catch {
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
    SetTimer(CommandPalette_AgentHeartbeatTick.Bind(cid), -5000)
}

CommandPalette_AgentHeartbeatTick(cardId) {
    global g_Agent_Cards
    cid := Trim(String(cardId))
    card := CommandPalette_AgentGetCard(cid)
    if !(card is Map) || card.Get("ended", false) || !card.Get("running", false)
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
            "liveThought", hbMsg
        ))
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_status",
            "cardId", cid,
            "reqId", String(card.Get("reqId", "")),
            "message", hbMsg,
            "status", "loading"
        ))
    }
    SetTimer(CommandPalette_AgentHeartbeatTick.Bind(cid), -5000)
}

CommandPalette_AgentEnsureEngine(*) {
    if FuncExists("StartWebViewWarmup")
        try StartWebViewWarmup()
        catch {
        }
    if FuncExists("CommandPalette_BootstrapNiumaChat")
        try CommandPalette_BootstrapNiumaChat("agent_stream", false)
        catch {
        }
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    return IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady
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
    card := CommandPalette_AgentGetCard(cardId)
    if !(card is Map)
        return
    card["streamDispatched"] := true
    card["dispatchTick"] := A_TickCount
    card["lastChunkTick"] := A_TickCount
    if viaCompose
        card["composeDispatched"] := true
    CommandPalette_AgentArmStreamWatchdog(cardId)
    rid := String(card.Get("reqId", ""))
    q := Trim(String(card.Get("query", "")))
    if (rid != "" && q != "")
        CommandPalette_AgentStartAnswerPoll(cardId, rid, q)
}

CommandPalette_AgentStartAnswerPoll(cardId, reqId, query) {
    SetTimer(CommandPalette_AgentPollFtbAnswer.Bind(cardId, reqId, query, 0), -2500)
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
    catch {
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
    if CommandPalette_AgentHasSubstantialAnswer(card) {
        if IsObject(g_Agent_RecoverPending)
            g_Agent_RecoverPending.Delete(cid)
        return
    }
    if g_Agent_FtbFetchBusy {
        SetTimer(CommandPalette_AgentRecoverCardAnswerOnce.Bind(cid, rid, q, tryN), -800)
        return
    }
    ans := CommandPalette_AgentFetchAnswerFromFtb(rid, q)
    stillSending := CommandPalette_AgentFtbSessionStillSending(rid)
    if (ans != "" && !CommandPalette_AgentIsStatusOnlyDelta(ans) && CommandPalette_AgentAnswerIsSubstantial(ans) && !stillSending) {
        CommandPalette_AgentLog("recover_hit", "card=" . cid . " len=" . StrLen(ans))
        CommandPalette_OnNiumaPaletteAgentEnd(Map("reqId", rid, "cardId", cid, "answer", ans))
        if IsObject(g_Agent_RecoverPending)
            g_Agent_RecoverPending.Delete(cid)
        return
    }
    tryN := Integer(tryN)
    maxTry := 40
    if (card is Map) && String(card.Get("provider", "openclaw")) = "openclaw"
        maxTry := 120
    if (tryN >= maxTry) {
        if IsObject(g_Agent_RecoverPending)
            g_Agent_RecoverPending.Delete(cid)
        return
    }
    SetTimer(CommandPalette_AgentRecoverCardAnswerOnce.Bind(cid, rid, q, tryN + 1), -3000)
}

CommandPalette_AgentFetchAnswerFromFtb(reqId, query) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_Agent_FtbFetchBusy
    if g_Agent_FtbFetchBusy
        return ""
    if !(IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return ""
    argsJson := "{}"
    try argsJson := Jxon_Dump(Map("reqId", String(reqId), "query", String(query)))
    catch {
        return ""
    }
    if !FuncExists("CommandPalette_JsEscapeForParse")
        return ""
    escaped := CommandPalette_JsEscapeForParse(argsJson)
    js := "(function(){try{var o=JSON.parse('" . escaped . "');"
        . "var fn=window.palettePickAssistantAnswerForAgent;"
        . "var hy=window.paletteHydrateAssistantFromGateway;"
        . "if(typeof fn!=='function')return JSON.stringify({ok:0,err:'no_fn'});"
        . "var pick=function(){return String(fn(o.reqId,o.query,{allowWhileSending:true})||'');};"
        . "if(typeof hy==='function'){"
        . "return hy(o.reqId,o.query,{allowWhileSending:true}).then(function(a){"
        . "var ans=String(a||pick()||'');"
        . "return JSON.stringify({ok:1,answer:ans});"
        . "}).catch(function(){return JSON.stringify({ok:1,answer:pick()});});"
        . "}"
        . "return JSON.stringify({ok:1,answer:pick()});"
        . "}catch(e){return JSON.stringify({ok:0,err:String(e&&e.message||e)});}})();"
    g_Agent_FtbFetchBusy := true
    try {
        raw := g_FTB_WV2.ExecuteScriptAsync(js).await(12000)
        data := FuncExists("CommandPalette_ParseScriptJson") ? CommandPalette_ParseScriptJson(raw) : Map()
        if (data is Map) && data.Get("ok", false)
            return Trim(String(data.Get("answer", "")))
    } catch {
    } finally {
        g_Agent_FtbFetchBusy := false
    }
    return ""
}

CommandPalette_AgentPollFtbAnswer(cardId, reqId, query, tryN) {
    global g_Agent_CancelToken
    if (g_Agent_CancelToken)
        return
    cid := Trim(String(cardId))
    rid := Trim(String(reqId))
    q := Trim(String(query))
    card := CommandPalette_AgentGetCard(cid)
    if !(card is Map) || card.Get("ended", false) || !card.Get("running", false)
        return
    tryN := Integer(tryN)
    if CommandPalette_AgentHasSubstantialAnswer(card) && !CommandPalette_AgentFtbSessionStillSending(rid) {
        ans := CommandPalette_AgentFetchAnswerFromFtb(rid, q)
        if (ans = "" || !CommandPalette_AgentAnswerIsSubstantial(ans))
            ans := Trim(String(card.Get("rawAnswer", "")))
        if CommandPalette_AgentAnswerIsSubstantial(ans)
            CommandPalette_OnNiumaPaletteAgentEnd(Map("reqId", rid, "cardId", cid, "answer", ans))
        return
    }
    ans := CommandPalette_AgentFetchAnswerFromFtb(rid, q)
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
        if !stillSending && CommandPalette_AgentHasSubstantialAnswer(card) {
            ansEnd := CommandPalette_AgentFetchAnswerFromFtb(rid, q)
            if (ansEnd = "" || !CommandPalette_AgentAnswerIsSubstantial(ansEnd))
                ansEnd := Trim(String(card.Get("rawAnswer", ans)))
            if CommandPalette_AgentAnswerIsSubstantial(ansEnd) {
                CommandPalette_AgentLog("poll_hit", "card=" . cid . " len=" . StrLen(ansEnd))
                CommandPalette_OnNiumaPaletteAgentEnd(Map("reqId", rid, "cardId", cid, "answer", ansEnd))
            }
            return
        }
    }
    if (tryN > 0 && Mod(tryN, 3) = 0 && !CommandPalette_AgentHasSubstantialAnswer(card)) {
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
    pollMax := (prov = "openclaw" || prov = "hermes") ? 300 : 90
    if (tryN >= pollMax) {
        pl := (prov = "hermes") ? "Hermes" : "龙虾 OpenClaw"
        CommandPalette_AgentPushError(rid, cid, "同步超时：Niuma 未返回回复。请确认悬浮栏已加载，并在设置中对「" . pl . "」点一键连接")
        return
    }
    SetTimer(CommandPalette_AgentPollFtbAnswer.Bind(cid, rid, q, tryN + 1), -2000)
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
    catch {
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
        catch {
        }
    }
    if FuncExists("FloatingToolbar_StartPaletteAgentStream") {
        try return !!FloatingToolbar_StartPaletteAgentStream(payload)
        catch {
        }
    }
    return false
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
        catch {
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
    card["streamDispatched"] := false
    card["dispatchTick"] := A_TickCount
    card["lastChunkTick"] := 0
    CommandPalette_AgentRegisterAiRoute(reqId, cardId, gen)
    CommandPalette_AgentLog("dispatch_ai", "card=" . cardId . " req=" . reqId . " prov=" . prov . " try=" . tryN)
    try CommandPalette_AgentDebugTrace("dispatch", "dispatch_start", "card=" . cardId . " req=" . reqId . " prov=" . prov . " try=" . tryN, "info")
    catch {
    }
    CommandPalette_AgentEnsureEngine()
    provLabel := (prov = "hermes") ? "Hermes" : "龙虾 OpenClaw"
    if (tryN = 0)
        CommandPalette_AgentPushStreamStatus(cardId, reqId, "🔗 正在连接 " . provLabel . "…")
    CommandPalette_AgentTagFtbSession(reqId, cardId, q, prov)
    sessionRef := CommandPalette_AgentPrefetchOpenClawSessionRef(cardId)
    if (sessionRef = "")
        sessionRef := CommandPalette_AgentResolveSessionRef(cardId)
    if (IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady) {
        sysPrompt := CommandPalette_AgentBuildSystemPrompt(card)
        routeId1 := Trim(String(card.Get("routeId", "")))
        if (routeId1 != "") {
            try CommandPalette_AgentDebugTrace("route", "prompt_inject", "route=" . routeId1 . " len=" . StrLen(sysPrompt), "info")
            catch {
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
        catch {
        }
        if (streamOk || scriptOk) {
            CommandPalette_AgentMarkStreamDispatched(cardId, false)
            CommandPalette_AgentPushStreamStatus(cardId, reqId, "📡 已派发至 " . provLabel . " 代理通道…")
            return
        }
    }
    if (Mod(tryN, 4) = 0)
        CommandPalette_AgentPushStreamStatus(cardId, reqId, "⏳ 等待 Niuma 引擎就绪 (" . (tryN + 1) . ")…")
    if (tryN >= 50) {
        CommandPalette_AgentPushError(reqId, cardId, "无法连接 Niuma 引擎：请确认牛马悬浮栏已显示，并在 Niuma Chat 设置里对「" . provLabel . "」点「一键连接」")
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
        return 600000
    return 120000
}

CommandPalette_AgentFtbSessionStillSending(reqId) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    rid := Trim(String(reqId))
    if (rid = "")
        return false
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
    try {
        raw := g_FTB_WV2.ExecuteScriptAsync(js).await(3000)
        data := FuncExists("CommandPalette_ParseScriptJson") ? CommandPalette_ParseScriptJson(raw) : Map()
        if (data is Map) && data.Get("ok", false)
            return !!data.Get("sending", false)
    } catch {
    }
    return false
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
    if (dispatched && rawLen < 1 && idleMs > idleLimit) {
        if CommandPalette_AgentFtbSessionStillSending(rid) {
            CommandPalette_AgentArmStreamWatchdog(cid)
            return
        }
        q := Trim(String(card.Get("query", "")))
        ans := (q != "") ? CommandPalette_AgentFetchAnswerFromFtb(rid, q) : ""
        if (ans != "") {
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
            catch {
            }
        return
    }
    if card.Get("ended", false)
        return
    if CommandPalette_AgentIsStatusOnlyDelta(delta)
        card["liveThought"] := Trim(delta)
    if !CommandPalette_AgentIsStatusOnlyDelta(delta) {
        prev := String(card.Get("rawAnswer", ""))
        if (prev = "")
            card["rawAnswer"] := delta
        else if (InStr(delta, prev) = 1)
            card["rawAnswer"] := delta
        else if (InStr(prev, delta) = 1)
            card["rawAnswer"] := prev
        else if (InStr(prev, delta) > 0)
            card["rawAnswer"] := prev
        else
            card["rawAnswer"] := prev . delta
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
    global g_Agent_Cards, g_CardSessionMap
    if !(msg is Map)
        return
    reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
    cardId := msg.Has("cardId") ? String(msg["cardId"]) : ""
    card := CommandPalette_AgentSessionMatches(reqId, cardId)
    if !(card is Map)
        return
    ans := msg.Has("answer") ? String(msg["answer"]) : String(card.Get("rawAnswer", ""))
    if !CommandPalette_AgentAnswerIsSubstantial(ans)
        return
    if card.Get("ended", false) {
        prev := Trim(String(card.Get("rawAnswer", "")))
        if CommandPalette_AgentAnswerIsSubstantial(prev) && StrLen(prev) >= StrLen(Trim(ans))
            return
    }
    card["rawAnswer"] := ans
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
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_end",
            "cardId", cardId,
            "reqId", reqId,
            "answer", ans,
            "sessionRef", String(card.Get("sessionRef", ""))
        ))
    CommandPalette_AgentPushCardSync()
}

CommandPalette_AgentPushError(reqId, cardId, message) {
    card := CommandPalette_AgentSessionMatches(reqId, cardId)
    if (card is Map) {
        card["ended"] := true
        card["running"] := false
        card["uiState"] := "Done"
        card["error"] := String(message)
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
    if !(msg is Map)
        return
    CommandPalette_AgentPushError(
        msg.Has("reqId") ? String(msg["reqId"]) : "",
        msg.Has("cardId") ? String(msg["cardId"]) : "",
        msg.Has("message") ? String(msg["message"]) : "代理请求失败"
    )
}

CommandPalette_AgentCancelOtherStreams(keepCardId := "") {
    global g_Agent_Cards
    keep := Trim(String(keepCardId))
    if FuncExists("CommandPalette_DeliverFtbPayload") {
        try CommandPalette_DeliverFtbPayload(Map("type", "palette_agent_prepare_new", "cardId", keep))
        catch {
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
        catch {
        }
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
        try CommandPalette_DeliverFtbPayload(Map("type", "host_palette_agent_stream_cancel", "reqId", reqId, "cardId", cid))
        catch {
        }
        try CommandPalette_DeliverFtbPayload(Map("type", "host_palette_ai_stream_cancel", "reqId", reqId))
        catch {
        }
    }
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_status",
            "cardId", cid,
            "message", "任务已取消",
            "status", "cancelled"
        ))
    CommandPalette_AgentPushCardSync()
    SetTimer(() => (g_Agent_CancelToken := false), -800)
}

CommandPalette_AgentOnReady() {
    CommandPalette_AgentLoadCards()
    CommandPalette_AgentPushCardSync()
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
    catch {
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
    catch {
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
