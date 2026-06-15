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
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
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
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try {
        if FileExist(paths["res"])
            FileDelete(paths["res"])
        f := FileOpen(paths["res"], "w", "UTF-8-RAW")
        if IsObject(f) {
            f.Write(Jxon_Dump(body))
            f.Close()
        }
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
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
    wailsHost := false
    try {
        if FuncExists("Nmer_CommandPaletteHost")
            wailsHost := Nmer_CommandPaletteHost() = "wails"
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if wailsHost {
        if (settleMs > 4000)
            settleMs := 4000
    }
    Nmer_MultiCardMemoryProbeHideCp()
    Sleep(350)
    seeded := Nmer_MultiCardMemoryProbeSeedR3Cards(cardCount)
    Nmer_MultiCardMemoryProbeShowCp()
    Sleep(wailsHost ? 450 : 900)
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

Nmer_MultiCardMemoryProbeDisposeCp(*) {
    if FuncExists("CommandPaletteRouter_Dispose")
        CommandPaletteRouter_Dispose("memory_probe")
    else if FuncExists("CommandPalette_Dispose")
        CommandPalette_Dispose("memory_probe")
}

Nmer_MultiCardMemoryProbeCpMemorySnapshot() {
    host := "?"
    try {
        if FuncExists("Nmer_CommandPaletteHost")
            host := Nmer_CommandPaletteHost()
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    ahvGui := false
    try {
        if FuncExists("CommandPaletteRouter_AhkGuiExists")
            ahvGui := CommandPaletteRouter_AhkGuiExists()
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    global g_CmdPal_WV2
    wv2 := IsObject(g_CmdPal_WV2)
    cpHwnd := 0
    try cpHwnd := WinExist("NMER Command Palette")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return Map(
        "host", host,
        "ahkGuiExists", ahvGui,
        "cmdPalWv2", wv2,
        "cpAhkHwnd", cpHwnd
    )
}

Nmer_MultiCardMemoryProbeAgentHasLiveAnswer(*) {
    global g_Agent_Cards
    if !(g_Agent_Cards is Map)
        return false
    for _, card in g_Agent_Cards {
        if !(card is Map)
            continue
        ans := String(card.Get("rawAnswer", card.Get("answer", "")))
        if FuncExists("CommandPalette_AgentAnswerIsSubstantial") {
            if CommandPalette_AgentAnswerIsSubstantial(ans)
                return true
        } else if (StrLen(Trim(ans)) > 4)
            return true
        st := String(card.Get("uiState", ""))
        if card.Get("running", false) || st = "Streaming" || st = "Running"
            return true
    }
    return false
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
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        return
    }
    root := Map()
    try root := Jxon_Load(raw)
    catch as errJson {
        Nmer_MultiCardMemoryProbeWriteResult("", false, false, "PROBE_JSON_INVALID", SubStr(String(errJson.Message), 1, 120))
        try FileDelete(reqPath)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        return
    }
    try FileDelete(reqPath)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
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
        case "show_cp":
            Nmer_MultiCardMemoryProbeShowCp()
            Sleep(500)
            snap := Nmer_MultiCardMemoryProbeCpMemorySnapshot()
            cpVisible := FuncExists("CommandPalette_IsVisible") ? CommandPalette_IsVisible() : false
            code := cpVisible ? "CP_SHOWN" : "CP_SHOW_WARN"
            extra := snap
            extra["cpVisible"] := cpVisible
            Nmer_MultiCardMemoryProbeWriteResult(id, true, !!cpVisible, code, "command_palette_show", extra)
        case "cp_wails_gate":
            host := "?"
            try {
                if FuncExists("Nmer_CommandPaletteHost")
                    host := Nmer_CommandPaletteHost()
            } catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
            ahvGui := false
            try {
                if FuncExists("CommandPaletteRouter_AhkGuiExists")
                    ahvGui := CommandPaletteRouter_AhkGuiExists()
            } catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
            global g_CmdPal_WV2
            wv2 := IsObject(g_CmdPal_WV2)
            shellMounted := false
            shellReady := false
            shellPhase := 0
            if FuncExists("Nmer_WailsBridgeGetShellCpStatus") {
                try {
                    st := Nmer_WailsBridgeGetShellCpStatus()
                    if st is Map {
                        shellMounted := !!st.Get("mounted", false)
                        shellReady := !!st.Get("ready", false)
                        shellPhase := Integer(st.Get("phase", 0))
                    }
                } catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
            }
            ok := (host = "wails") && !ahvGui && !wv2 && shellMounted
            code := ok ? "CP_WAILS_GATE_OK" : "CP_WAILS_GATE_WARN"
            Nmer_MultiCardMemoryProbeWriteResult(id, true, ok, code, "host=" . host, Map(
                "host", host,
                "ahkGuiExists", ahvGui,
                "cmdPalWv2", wv2,
                "shellMounted", shellMounted,
                "shellReady", shellReady,
                "shellPhase", shellPhase
            ))
        case "cp_wails_bridge_smoke":
            global g_CmdPalWails_EgressDrainCount, g_CmdPalWails_EgressLastType, g_CmdPalWails_InjectPushOk
            g_CmdPalWails_EgressDrainCount := 0
            g_CmdPalWails_EgressLastType := ""
            g_CmdPalWails_InjectPushOk := false
            host := "?"
            try {
                if FuncExists("Nmer_CommandPaletteHost")
                    host := Nmer_CommandPaletteHost()
            } catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
            ahvGui := false
            try {
                if FuncExists("CommandPaletteRouter_AhkGuiExists")
                    ahvGui := CommandPaletteRouter_AhkGuiExists()
            } catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
            global g_CmdPal_WV2
            wv2 := IsObject(g_CmdPal_WV2)
            shellMounted := false
            shellReady := false
            shellPhase := 0
            if FuncExists("Nmer_WailsBridgeGetShellCpStatus") {
                try {
                    st := Nmer_WailsBridgeGetShellCpStatus()
                    if st is Map {
                        shellMounted := !!st.Get("mounted", false)
                        shellReady := !!st.Get("ready", false)
                        shellPhase := Integer(st.Get("phase", 0))
                    }
                } catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
            }
            if FuncExists("CommandPaletteWails_EnsureEgressPump")
                CommandPaletteWails_EnsureEgressPump()
            Nmer_MultiCardMemoryProbeShowCp()
            Sleep(400)
            injectOk := false
            if FuncExists("CommandPalette_PushToWeb") {
                injectOk := !!CommandPalette_PushToWeb(Map("type", "palette_set_intent", "intent", "search"))
            }
            egressPostOk := false
            if FuncExists("Nmer_WailsBridgePostShellCpEgress") {
                try {
                    eg := Nmer_WailsBridgePostShellCpEgress(Map("type", "palette_query", "input", "cp2c_smoke", "seq", 1))
                    egressPostOk := (eg is Map) && eg.Get("ok", false)
                } catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
            }
            if FuncExists("CommandPaletteWails_DrainEgressOnce")
                CommandPaletteWails_DrainEgressOnce()
            agentPostOk := false
            if FuncExists("Nmer_WailsBridgePostShellCpEgress") {
                try {
                    eg2 := Nmer_WailsBridgePostShellCpEgress(Map("type", "palette_turbo_search", "query", "cp2c", "limit", 5, "seq", 2))
                    agentPostOk := (eg2 is Map) && eg2.Get("ok", false)
                } catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
            }
            if FuncExists("CommandPaletteWails_DrainEgressOnce")
                CommandPaletteWails_DrainEgressOnce()
            gateOk := (host = "wails") && !ahvGui && !wv2 && shellMounted
            bridgeOk := injectOk && egressPostOk && agentPostOk && (Integer(g_CmdPalWails_EgressDrainCount) >= 2)
            ok := gateOk && bridgeOk
            code := ok ? "CP_WAILS_BRIDGE_OK" : "CP_WAILS_BRIDGE_WARN"
            Nmer_MultiCardMemoryProbeWriteResult(id, true, ok, code, "inject=" . (injectOk ? 1 : 0) . " egress=" . g_CmdPalWails_EgressDrainCount, Map(
                "host", host,
                "ahkGuiExists", ahvGui,
                "cmdPalWv2", wv2,
                "shellMounted", shellMounted,
                "shellReady", shellReady,
                "shellPhase", shellPhase,
                "gateOk", gateOk,
                "injectOk", injectOk,
                "egressPostOk", egressPostOk,
                "agentPostOk", agentPostOk,
                "egressDrainCount", Integer(g_CmdPalWails_EgressDrainCount),
                "egressLastType", String(g_CmdPalWails_EgressLastType)
            ))
        case "hide_cp":
            Nmer_MultiCardMemoryProbeHideCp()
            Nmer_MultiCardMemoryProbeWriteResult(id, true, true, "CP_HIDDEN", "command_palette_hidden")
        case "dispose_cp":
            Nmer_MultiCardMemoryProbeHideCp()
            Sleep(150)
            Nmer_MultiCardMemoryProbeDisposeCp()
            Sleep(150)
            snap := Nmer_MultiCardMemoryProbeCpMemorySnapshot()
            ok := !snap.Get("ahkGuiExists", true) && !snap.Get("cmdPalWv2", true)
            code := ok ? "CP_DISPOSED" : "CP_DISPOSE_WARN"
            Nmer_MultiCardMemoryProbeWriteResult(id, true, ok, code, "command_palette_dispose", snap)
        case "cp_memory_snapshot":
            snap := Nmer_MultiCardMemoryProbeCpMemorySnapshot()
            Nmer_MultiCardMemoryProbeWriteResult(id, true, true, "CP_MEMORY_SNAPSHOT", "cp_memory_snapshot", snap)
        case "cp_wails_memory_soak":
            cycles := Integer(root.Get("cardCount", 10))
            if (cycles < 1)
                cycles := 10
            if (cycles > 20)
                cycles := 20
            start := Nmer_MultiCardMemoryProbeCpMemorySnapshot()
            maxAhkGui := start.Get("ahkGuiExists", false) ? 1 : 0
            maxWv2 := start.Get("cmdPalWv2", false) ? 1 : 0
            leakAfterDispose := false
            Loop cycles {
                Nmer_MultiCardMemoryProbeShowCp()
                Sleep(220)
                mid := Nmer_MultiCardMemoryProbeCpMemorySnapshot()
                if mid.Get("ahkGuiExists", false)
                    maxAhkGui := 1
                if mid.Get("cmdPalWv2", false)
                    maxWv2 := 1
                Nmer_MultiCardMemoryProbeHideCp()
                Sleep(160)
                Nmer_MultiCardMemoryProbeDisposeCp()
                Sleep(160)
                post := Nmer_MultiCardMemoryProbeCpMemorySnapshot()
                if post.Get("ahkGuiExists", false) || post.Get("cmdPalWv2", false)
                    leakAfterDispose := true
            }
            end := Nmer_MultiCardMemoryProbeCpMemorySnapshot()
            host := end.Get("host", "?")
            ok := (host = "wails") && !end.Get("ahkGuiExists", true) && !end.Get("cmdPalWv2", true) && !leakAfterDispose
            code := ok ? "CP_WAILS_MEMORY_SOAK_OK" : "CP_WAILS_MEMORY_SOAK_WARN"
            Nmer_MultiCardMemoryProbeWriteResult(id, true, ok, code, "cycles=" . cycles, Map(
                "host", host,
                "cycles", cycles,
                "start", start,
                "end", end,
                "maxAhkGui", maxAhkGui,
                "maxWv2", maxWv2,
                "leakAfterDispose", leakAfterDispose,
                "ahkGuiExists", end.Get("ahkGuiExists", false),
                "cmdPalWv2", end.Get("cmdPalWv2", false),
                "cpAhkHwnd", end.Get("cpAhkHwnd", 0)
            ))
        case "cp_wails_agent_submit":
            host := "?"
            try {
                if FuncExists("Nmer_CommandPaletteHost")
                    host := Nmer_CommandPaletteHost()
            } catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
            Nmer_MultiCardMemoryProbeShowCp()
            Sleep(500)
            if FuncExists("CommandPaletteWails_EnsureEgressPump")
                CommandPaletteWails_EnsureEgressPump()
            if FuncExists("CommandPalette_PushToWeb") {
                try CommandPalette_PushToWeb(Map("type", "palette_set_intent", "intent", "action"))
                catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
                Sleep(200)
            }
            submitOk := false
            query := "Reply in one short Chinese sentence: wails cp9 live"
            if FuncExists("Nmer_WailsBridgePostShellCpEgress") {
                try {
                    eg := Nmer_WailsBridgePostShellCpEgress(Map(
                        "type", "palette_agent_submit",
                        "query", query,
                        "text", query,
                        "provider", "openclaw",
                        "probe", true
                    ))
                    submitOk := (eg is Map) && eg.Get("ok", false)
                } catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
            }
            if FuncExists("CommandPaletteWails_DrainEgressOnce")
                CommandPaletteWails_DrainEgressOnce()
            snap := Nmer_MultiCardMemoryProbeCpMemorySnapshot()
            code := submitOk ? "CP_WAILS_AGENT_SUBMIT_OK" : "CP_WAILS_AGENT_SUBMIT_WARN"
            Nmer_MultiCardMemoryProbeWriteResult(id, true, submitOk, code, "submit", Map(
                "host", host,
                "submitOk", submitOk,
                "query", query,
                "snapshot", snap
            ))
        case "cp_wails_agent_status":
            if FuncExists("CommandPaletteWails_DrainEgressOnce")
                try CommandPaletteWails_DrainEgressOnce()
                catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
            snap := Nmer_MultiCardMemoryProbeCpMemorySnapshot()
            cardCount := FuncExists("CommandPalette_AgentCardCount") ? CommandPalette_AgentCardCount() : 0
            liveAnswer := Nmer_MultiCardMemoryProbeAgentHasLiveAnswer()
            agentTransport := FuncExists("Nmer_PaletteAgentTransport") ? Nmer_PaletteAgentTransport() : "?"
            Nmer_MultiCardMemoryProbeWriteResult(id, true, true, "CP_WAILS_AGENT_STATUS", "status", Map(
                "host", snap.Get("host", "?"),
                "agentTransport", agentTransport,
                "cardCount", cardCount,
                "liveAnswer", liveAnswer,
                "ahkGuiExists", snap.Get("ahkGuiExists", false),
                "cmdPalWv2", snap.Get("cmdPalWv2", false),
                "snapshot", snap
            ))
        case "cp_wails_hub_agent_live":
            global g_CmdPalWails_InjectPushOk
            settleMs := Integer(root.Get("settleMs", 90000))
            if (settleMs < 15000)
                settleMs := 15000
            if (settleMs > 180000)
                settleMs := 180000
            host := "?"
            agentTransport := "?"
            try {
                if FuncExists("Nmer_CommandPaletteHost")
                    host := Nmer_CommandPaletteHost()
            } catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
            try {
                if FuncExists("Nmer_PaletteAgentTransport")
                    agentTransport := Nmer_PaletteAgentTransport()
                else if FuncExists("Nmer_WailsBridgeReadFlags") {
                    flags := Nmer_WailsBridgeReadFlags()
                    pal := flags.Get("palette", Map())
                    if (pal is Map)
                        agentTransport := String(pal.Get("agentTransport", "?"))
                }
            } catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
            Nmer_MultiCardMemoryProbeShowCp()
            Sleep(600)
            if FuncExists("CommandPaletteWails_EnsureEgressPump")
                CommandPaletteWails_EnsureEgressPump()
            if FuncExists("CommandPalette_PushToWeb") {
                try CommandPalette_PushToWeb(Map("type", "palette_set_intent", "intent", "action"))
                catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
                Sleep(200)
            }
            submitOk := false
            query := "Reply in one short Chinese sentence: wails cp9 live"
            if FuncExists("Nmer_WailsBridgePostShellCpEgress") {
                try {
                    eg := Nmer_WailsBridgePostShellCpEgress(Map(
                        "type", "palette_agent_submit",
                        "query", query,
                        "text", query,
                        "provider", "openclaw",
                        "probe", true
                    ))
                    submitOk := (eg is Map) && eg.Get("ok", false)
                } catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
            }
            if FuncExists("CommandPaletteWails_DrainEgressOnce")
                CommandPaletteWails_DrainEgressOnce()
            deadline := A_TickCount + settleMs
            liveAnswer := false
            cardCount := 0
            while (A_TickCount < deadline) {
                if FuncExists("CommandPaletteWails_DrainEgressOnce")
                    try CommandPaletteWails_DrainEgressOnce()
                    catch as _e {
                        NmerCatch(A_ThisFunc, _e) 
                    }
                cardCount := FuncExists("CommandPalette_AgentCardCount") ? CommandPalette_AgentCardCount() : 0
                if Nmer_MultiCardMemoryProbeAgentHasLiveAnswer()
                    liveAnswer := true
                if liveAnswer && cardCount > 0
                    break
                Sleep(500)
            }
            syncOk := false
            if FuncExists("CommandPalette_AgentPushCardSync") {
                try {
                    CommandPalette_AgentPushCardSync()
                    syncOk := !!g_CmdPalWails_InjectPushOk
                } catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
            }
            tier := Nmer_MultiCardMemoryProbePrepareTier(1, 2500)
            historyOk := tier.Get("cpVisible", false) && (Integer(tier.Get("actualCards", 0)) >= 1)
            gateOk := (host = "wails") && (agentTransport = "hub") && submitOk
            r4 := gateOk && liveAnswer && (cardCount > 0)
            r5 := historyOk
            ok := r4 && r5
            code := ok ? "CP_WAILS_HUB_AGENT_OK" : "CP_WAILS_HUB_AGENT_WARN"
            Nmer_MultiCardMemoryProbeWriteResult(id, true, ok, code, "cards=" . cardCount . " live=" . (liveAnswer ? 1 : 0), Map(
                "host", host,
                "agentTransport", agentTransport,
                "submitOk", submitOk,
                "liveAnswer", liveAnswer,
                "cardCount", cardCount,
                "syncOk", syncOk,
                "injectOk", !!g_CmdPalWails_InjectPushOk,
                "historyOk", historyOk,
                "tier", tier,
                "r4Pass", r4,
                "r5Pass", r5
            ))
        case "adp_l3_probe":
            Nmer_MultiCardMemoryProbeShowCp()
            global g_CmdPal_Ready
            readyDeadline := A_TickCount + 25000
            while (A_TickCount < readyDeadline) {
                if (g_CmdPal_Ready)
                    break
                Sleep(250)
            }
            if FuncExists("CommandPalette_PushToWeb") {
                try {
                    CommandPalette_PushToWeb(Map("type", "palette_set_intent", "intent", "action"))
                    Sleep(400)
                } catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
            }
            adpCode := "ADP_PROBE_UNAVAILABLE"
            adpOk := false
            if FuncExists("CommandPalette_RunAdapterProbeAndPersist")
                r := CommandPalette_RunAdapterProbeAndPersist(22000)
            else if FuncExists("CommandPalette_ProbeAdapterOfficialA2ui")
                r := CommandPalette_ProbeAdapterOfficialA2ui(22000)
            else
                r := Map("ok", false, "code", "ADP_PROBE_UNAVAILABLE")
            if (r is Map) {
                adpCode := String(r.Get("code", "ADP_FAIL"))
                adpOk := !!r.Get("ok", false)
            }
            Nmer_MultiCardMemoryProbeWriteResult(id, true, adpOk, adpCode, "adapter_l3_probe", Map(
                "adpCode", adpCode,
                "adpOk", adpOk
            ))
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
