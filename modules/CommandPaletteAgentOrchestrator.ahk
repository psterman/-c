#Requires AutoHotkey v2.0

; CommandPaletteAgentOrchestrator — 动作 Tab 全托管代理任务编排（非阻塞）

global g_Agent_Cards := Map()
global g_CardSessionMap := Map()
global g_Agent_CancelToken := false
global g_Agent_ActiveCardId := ""
global g_Agent_DefaultProvider := "openclaw"
global g_Agent_StreamGen := 0

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

CommandPalette_AgentCardsPath() {
    if FuncExists("Nmer_DebugPath")
        return Nmer_DebugPath("agent_cards.json")
    return A_ScriptDir . "\Cache\debug\agent_cards.json"
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
    return Map(
        "cardId", String(card.Get("cardId", "")),
        "reqId", String(card.Get("reqId", "")),
        "uiState", String(card.Get("uiState", "Planning")),
        "title", String(card.Get("title", card.Get("query", ""))),
        "query", String(card.Get("query", card.Get("title", ""))),
        "provider", String(card.Get("provider", CommandPalette_AgentDefaultProvider())),
        "sessionRef", String(card.Get("sessionRef", "")),
        "ended", !!card.Get("ended", false),
        "running", !!card.Get("running", false),
        "error", String(card.Get("error", "")),
        "rawAnswer", SubStr(String(card.Get("rawAnswer", "")), 1, 12000),
        "updatedAt", String(card.Get("updatedAt", ""))
    )
}

CommandPalette_AgentPersistCards() {
    global g_Agent_Cards
    path := CommandPalette_AgentCardsPath()
    try {
        dir := ""
        SplitPath(path, , &dir)
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)
        arr := []
        for _, c in g_Agent_Cards {
            if (c is Map)
                arr.Push(CommandPalette_AgentCardToSyncDto(c))
        }
        if FuncExists("Jxon_Dump") {
            FileDelete(path)
            FileAppend(Jxon_Dump(arr), path, "UTF-8")
        }
    } catch as eP {
        CommandPalette_AgentLog("persist_err", eP.Message)
    }
}

CommandPalette_AgentLoadCards() {
    global g_Agent_Cards
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
            g_Agent_Cards[cid] := Map(
                "cardId", cid,
                "reqId", String(dto.Get("reqId", "")),
                "uiState", String(dto.Get("uiState", "Done")),
                "title", String(dto.Get("title", "")),
                "query", String(dto.Get("query", "")),
                "provider", String(dto.Get("provider", CommandPalette_AgentDefaultProvider())),
                "sessionRef", String(dto.Get("sessionRef", "")),
                "ended", !!dto.Get("ended", true),
                "running", false,
                "error", String(dto.Get("error", "")),
                "rawAnswer", String(dto.Get("rawAnswer", "")),
                "gen", 0,
                "updatedAt", String(dto.Get("updatedAt", ""))
            )
            if Trim(String(dto.Get("sessionRef", ""))) != ""
                g_CardSessionMap[cid] := String(dto.Get("sessionRef", ""))
        }
    } catch as eL {
        CommandPalette_AgentLog("load_err", eL.Message)
    }
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

CommandPalette_AgentSubmit(msg) {
    global g_Agent_Cards, g_CardSessionMap, g_Agent_ActiveCardId, g_Agent_CancelToken, g_Agent_StreamGen
    g_Agent_CancelToken := false
    text := msg.Has("text") ? Trim(String(msg["text"])) : (msg.Has("query") ? Trim(String(msg["query"])) : "")
    if (text = "")
        return
    kind := msg.Has("kind") ? StrLower(String(msg["kind"])) : "new"
    cardId := msg.Has("cardId") ? Trim(String(msg["cardId"])) : ""
    prov := msg.Has("provider") ? Trim(String(msg["provider"])) : CommandPalette_AgentDefaultProvider()
    if FuncExists("CommandPalette_NormalizeAiProvider")
        prov := CommandPalette_NormalizeAiProvider(prov != "" ? prov : "openclaw")

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
            CommandPalette_AgentPersistCards()
            CommandPalette_AgentPushCardNew(card)
            CommandPalette_AgentPushCardSync()
            CommandPalette_AgentArmHeartbeat(cardId)
            CommandPalette_AgentStartAnswerPoll(cardId, reqId, text)
            SetTimer(CommandPalette_AgentDispatchStream.Bind(cardId, reqId, text, prov, gen, kind), -30)
            return
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
    reqId := CommandPalette_AgentNewId("cpag")
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
        "sessionRef", "",
        "ended", false,
        "running", true,
        "error", "",
        "rawAnswer", "",
        "gen", gen,
        "messages", [Map("role", "user", "text", text, "at", A_Now)],
        "updatedAt", A_Now
    )
    g_Agent_Cards[cardId] := card
    g_Agent_ActiveCardId := cardId
    CommandPalette_AgentPersistCards()
    CommandPalette_AgentPushCardNew(card)
    CommandPalette_AgentPushCardSync()
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_status",
            "cardId", cardId,
            "message", "正在连接代理引擎…",
            "status", "loading"
        ))
    CommandPalette_AgentArmHeartbeat(cardId)
    CommandPalette_AgentStartAnswerPoll(cardId, reqId, text)
    SetTimer(CommandPalette_AgentDispatchStream.Bind(cardId, reqId, text, prov, gen, "new"), -30)
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
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_heartbeat",
            "cardId", cid,
            "message", "仍连接 " . provLabel . "，等待模型响应…"
        ))
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
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_chunk",
            "cardId", String(cardId),
            "reqId", String(reqId),
            "delta", String(message) . "`n"
        ))
}

CommandPalette_AgentMarkStreamDispatched(cardId) {
    card := CommandPalette_AgentGetCard(cardId)
    if !(card is Map)
        return
    card["streamDispatched"] := true
    card["dispatchTick"] := A_TickCount
    card["lastChunkTick"] := A_TickCount
    CommandPalette_AgentArmStreamWatchdog(cardId)
    rid := String(card.Get("reqId", ""))
    q := Trim(String(card.Get("query", "")))
    if (rid != "" && q != "")
        CommandPalette_AgentStartAnswerPoll(cardId, rid, q)
}

CommandPalette_AgentStartAnswerPoll(cardId, reqId, query) {
    SetTimer(CommandPalette_AgentPollFtbAnswer.Bind(cardId, reqId, query, 0), -2500)
}

CommandPalette_AgentFetchAnswerFromFtb(reqId, query) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
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
        . "if(typeof fn!=='function')return JSON.stringify({ok:0,err:'no_fn'});"
        . "return JSON.stringify({ok:1,answer:String(fn(o.reqId,o.query)||'')});"
        . "}catch(e){return JSON.stringify({ok:0,err:String(e&&e.message||e)});}})();"
    try {
        raw := g_FTB_WV2.ExecuteScriptAsync(js).await(4000)
        data := FuncExists("CommandPalette_ParseScriptJson") ? CommandPalette_ParseScriptJson(raw) : Map()
        if (data is Map) && data.Get("ok", false)
            return Trim(String(data.Get("answer", "")))
    } catch {
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
    rawLen := StrLen(String(card.Get("rawAnswer", "")))
    if (rawLen > 40)
        return
    ans := CommandPalette_AgentFetchAnswerFromFtb(rid, q)
    if (ans != "") {
        CommandPalette_AgentLog("poll_hit", "card=" . cid . " len=" . StrLen(ans))
        prev := String(card.Get("rawAnswer", ""))
        delta := ""
        if (prev = "")
            delta := ans
        else if (InStr(ans, prev) = 1)
            delta := SubStr(ans, StrLen(prev) + 1)
        else if (prev != ans)
            delta := ans
        if (delta != "")
            CommandPalette_OnNiumaPaletteAgentChunk(Map("reqId", rid, "cardId", cid, "delta", delta))
        CommandPalette_OnNiumaPaletteAgentEnd(Map("reqId", rid, "cardId", cid, "answer", ans))
        return
    }
    if (tryN > 0 && Mod(tryN, 5) = 0)
        CommandPalette_AgentPushStreamStatus(cid, rid, "⏳ 同步 Niuma 会话回复中 (" . (tryN + 1) . ")…")
    if (tryN >= 60)
        return
    SetTimer(CommandPalette_AgentPollFtbAnswer.Bind(cid, rid, q, tryN + 1), -2000)
}

CommandPalette_AgentDeliverStreamPayload(payload) {
    if !(payload is Map)
        return false
    ok := false
    if FuncExists("FloatingToolbar_StartPaletteAgentStream") {
        try ok := !!FloatingToolbar_StartPaletteAgentStream(payload)
        catch {
            ok := false
        }
    }
    if !ok && FuncExists("CommandPalette_DeliverFtbPayload")
        ok := CommandPalette_DeliverFtbPayload(payload)
    return ok
}

CommandPalette_AgentDispatchStream(cardId, reqId, query, provider, gen, kind) {
    global g_Agent_Cards, g_Agent_CancelToken
    if (g_Agent_CancelToken)
        return
    card := CommandPalette_AgentGetCard(cardId)
    if !(card is Map) || Integer(card.Get("gen", 0)) != Integer(gen)
        return
    if Trim(String(card.Get("reqId", ""))) != Trim(String(reqId))
        return
    q := Trim(String(query))
    prov := Trim(String(provider))
    card["streamDispatched"] := false
    card["dispatchTick"] := A_TickCount
    card["lastChunkTick"] := 0
    sys := CommandPalette_AgentProtocolPrompt()
    if (kind = "correction" || kind = "append")
        sys .= "`n【续聊】用户在当前卡片内追加/修正，请继承上下文继续，必要时重出 PLAN。"
    payload := Map(
        "type", "host_palette_agent_stream",
        "reqId", reqId,
        "cardId", cardId,
        "query", q,
        "provider", prov,
        "systemPrompt", sys,
        "openDrawer", false
    )
    CommandPalette_AgentLog("dispatch", "card=" . cardId . " req=" . reqId . " prov=" . prov)
    CommandPalette_AgentEnsureEngine()
    provLabel := (prov = "hermes") ? "Hermes" : "龙虾 OpenClaw"
    CommandPalette_AgentPushStreamStatus(cardId, reqId, "🔗 正在连接 " . provLabel . "…")
    if CommandPalette_AgentDeliverStreamPayload(payload) {
        CommandPalette_AgentMarkStreamDispatched(cardId)
        CommandPalette_AgentLog("dispatch_ok", "immediate")
        return
    }
    SetTimer(CommandPalette_AgentDispatchStreamRetry.Bind(payload, 0), -400)
}

CommandPalette_AgentDispatchStreamRetry(payload, tryN) {
    global g_Agent_CancelToken
    if (g_Agent_CancelToken || !(payload is Map))
        return
    tryN := Integer(tryN)
    cid := String(payload.Get("cardId", ""))
    rid := String(payload.Get("reqId", ""))
    prov := String(payload.Get("provider", "openclaw"))
    provLabel := (prov = "hermes") ? "Hermes" : "龙虾 OpenClaw"
    CommandPalette_AgentEnsureEngine()
    if (Mod(tryN, 4) = 0)
        CommandPalette_AgentPushStreamStatus(cid, rid, "⏳ 等待 Niuma 引擎就绪 (" . (tryN + 1) . ")…")
    if CommandPalette_AgentDeliverStreamPayload(payload) {
        CommandPalette_AgentMarkStreamDispatched(cid)
        CommandPalette_AgentLog("dispatch_ok", "try=" . tryN)
        return
    }
    if (tryN >= 48) {
        CommandPalette_AgentPushError(rid, cid, "无法连接 Niuma 引擎：请确认牛马悬浮栏已显示，并在 Niuma Chat 设置里对「" . provLabel . "」点「一键连接」")
        return
    }
    SetTimer(CommandPalette_AgentDispatchStreamRetry.Bind(payload, tryN + 1), -350)
}

CommandPalette_AgentArmStreamWatchdog(cardId) {
    SetTimer(CommandPalette_AgentStreamWatchdogTick.Bind(cardId), -15000)
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
    last := Integer(card.Get("lastChunkTick", 0))
    dispatched := !!card.Get("streamDispatched", false)
    rawLen := StrLen(String(card.Get("rawAnswer", "")))
    if (!dispatched && (now - Integer(card.Get("dispatchTick", now)) > 45000)) {
        prov := String(card.Get("provider", "openclaw"))
        pl := (prov = "hermes") ? "Hermes" : "龙虾 OpenClaw"
        CommandPalette_AgentPushError(rid, cid, "引擎未启动：请先打开牛马悬浮栏，并在设置里对「" . pl . "」点一键连接")
        return
    }
    if (dispatched && rawLen < 1 && last > 0 && (now - last > 90000)) {
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
    global g_Agent_Cards
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
    if !(card is Map)
        return
    acc := String(card.Get("rawAnswer", "")) . delta
    card["rawAnswer"] := acc
    card["lastChunkTick"] := A_TickCount
    card["streamDispatched"] := true
    card["updatedAt"] := A_Now
    if (cardId = "")
        cardId := String(card.Get("cardId", ""))
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map(
            "type", "palette_agent_chunk",
            "cardId", cardId,
            "reqId", reqId,
            "delta", delta
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
            "answer", ans
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
    CommandPalette_AgentSubmit(msg)
}

CommandPalette_HandleAgentCancel(msg) {
    cid := msg.Has("cardId") ? String(msg["cardId"]) : ""
    CommandPalette_AgentCancel(cid)
}

CommandPalette_HandleAgentPhysical(msg) {
    at := msg.Has("actionType") ? String(msg["actionType"]) : ""
    args := msg.Has("args") && msg["args"] is Map ? msg["args"] : Map()
    cid := msg.Has("cardId") ? String(msg["cardId"]) : ""
    CommandPalette_DispatchPhysicalAction(at, args, cid)
}
