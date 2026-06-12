; Diagnostics file IPC: CommandPalette perf capture (host-side input injection)

global g_Nmer_CpPerfProbeOn := false

Nmer_CpPerfProbePaths(*) {
    root := FuncExists("Nmer_InstallRoot") ? Nmer_InstallRoot() : A_ScriptDir
    dbg := root . "\Cache\debug"
    if !DirExist(dbg)
        DirCreate(dbg)
    return Map(
        "req", dbg . "\command_palette_perf_probe.json",
        "res", dbg . "\command_palette_perf_probe_result.json",
        "log", dbg . "\command_palette_perf_probe.log"
    )
}

Nmer_CpPerfProbeLog(line) {
    paths := Nmer_CpPerfProbePaths()
    try FileAppend("[" . A_Now . "] " . String(line) . "`n", paths["log"], "UTF-8")
    catch {
    }
}

Nmer_CpPerfProbeEnsure(*) {
    global g_Nmer_CpPerfProbeOn
    if g_Nmer_CpPerfProbeOn
        return
    g_Nmer_CpPerfProbeOn := true
    SetTimer(Nmer_CpPerfProbePoll, 400)
    Nmer_CpPerfProbeLog("probe_timer_on")
}

Nmer_CpPerfProbeWriteResult(id, ok, pass, code, detail := "", extra := 0) {
    paths := Nmer_CpPerfProbePaths()
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

Nmer_CpPerfProbeHideCp(*) {
    if FuncExists("CommandPaletteRouter_Hide")
        CommandPaletteRouter_Hide(Map("reason", "perf_probe"))
    else if FuncExists("CommandPalette_Hide")
        CommandPalette_Hide(Map("reason", "perf_probe"))
}

Nmer_CpPerfProbeShowCp(*) {
    if FuncExists("CommandPaletteRouter_Show")
        CommandPaletteRouter_Show()
    else if FuncExists("CommandPalette_Show")
        CommandPalette_Show()
}

Nmer_CpPerfProbeWaitReady(maxMs := 12000) {
    global g_CmdPal_Ready, g_CmdPal_Visible, g_CmdPal_Revealed
    deadline := A_TickCount + Max(1000, Integer(maxMs))
    while (A_TickCount < deadline) {
        if g_CmdPal_Ready && g_CmdPal_Visible
            return true
        Nmer_CpPerfProbeYield(120)
    }
    return !!(g_CmdPal_Ready && g_CmdPal_Visible)
}

Nmer_CpPerfProbeYield(ms := 400) {
    deadline := A_TickCount + Max(40, Integer(ms))
    while (A_TickCount < deadline) {
        if FuncExists("CommandPalette_DrainWebMessageQueue")
            try CommandPalette_DrainWebMessageQueue()
            catch {
            }
        Sleep(30)
    }
}

Nmer_CpPerfProbeSetIntent(intent) {
    if !FuncExists("CommandPalette_PushToWeb")
        return false
    CommandPalette_PushToWeb(Map("type", "palette_set_intent", "intent", String(intent)))
    Nmer_CpPerfProbeYield(220)
    return true
}

Nmer_CpPerfProbeExecInput(intent, text) {
    if !FuncExists("CommandPalette_ExecScript")
        return false
    qEsc := FuncExists("CommandPalette_JsEscapeForParse") ? CommandPalette_JsEscapeForParse(String(text))
        : String(text)
    intEsc := FuncExists("CommandPalette_JsEscapeForParse") ? CommandPalette_JsEscapeForParse(String(intent))
        : String(intent)
    js := "try{state.intent='" . intEsc . "';if(typeof syncIntentUI==='function')syncIntentUI();"
        . "if(window.nmerPalette&&window.nmerPalette.setInputText)window.nmerPalette.setInputText('" . qEsc . "');"
        . "}catch(e){}"
    CommandPalette_ExecScript(js)
    return true
}

Nmer_CpPerfProbeTypeIncremental(text, stepMs := 110) {
    if !FuncExists("CommandPalette_SetInputText")
        return 0
    s := String(text)
    if (s = "")
        return 0
    n := 0
    built := ""
    Loop Parse s {
        built .= A_LoopField
        CommandPalette_SetInputText(built)
        n += 1
        Nmer_CpPerfProbeYield(Max(60, Integer(stepMs)))
    }
    Nmer_CpPerfProbeYield(300)
    return n
}

Nmer_CpPerfProbePrepareFresh() {
    Nmer_CpPerfProbeHideCp()
    Nmer_CpPerfProbeYield(380)
    if FuncExists("CommandPalette_Dispose")
        try CommandPalette_Dispose("perf_probe_fresh")
        catch {
        }
    Nmer_CpPerfProbeYield(280)
}

Nmer_CpPerfProbePrepareWarm() {
    Nmer_CpPerfProbeHideCp()
    Nmer_CpPerfProbeYield(420)
}

Nmer_CpPerfProbeHostSnapshotCount() {
    if !FuncExists("CommandPalette_BuildCommandSnapshot")
        return -1
    items := CommandPalette_BuildCommandSnapshot()
    try {
        return items is Array ? items.Length : 0
    } catch {
        return -1
    }
}

Nmer_CpPerfProbeScriptTruthy(raw) {
    if (raw = true || raw = 1)
        return true
    s := StrLower(Trim(String(raw)))
    return (s = "true" || s = "1")
}

Nmer_CpPerfProbeQueryWebShellReady() {
    global g_CmdPal_WV2
    if !IsObject(g_CmdPal_WV2)
        return false
    js := "(function(){try{return !!(window.nmerPalette&&document.getElementById('palette-panel')&&typeof PaletteCommandIndex!=='undefined');}catch(e){return false;}})()"
    try {
        raw := g_CmdPal_WV2.ExecuteScriptAsync(js).await(4000)
        return Nmer_CpPerfProbeScriptTruthy(raw)
    } catch {
        return false
    }
}

Nmer_CpPerfProbeWaitWebShellReady(maxMs := 18000) {
    deadline := A_TickCount + Max(3000, Integer(maxMs))
    while (A_TickCount < deadline) {
        if Nmer_CpPerfProbeQueryWebShellReady()
            return true
        Nmer_CpPerfProbeYield(220)
    }
    return Nmer_CpPerfProbeQueryWebShellReady()
}

Nmer_CpPerfProbeQueryCommandIndexSize() {
    global g_CmdPal_WV2
    if !IsObject(g_CmdPal_WV2)
        return -1
    js := "(function(){try{return (typeof PaletteCommandIndex!=='undefined'&&PaletteCommandIndex.getSize)?PaletteCommandIndex.getSize():0;}catch(e){return 0;}})()"
    try {
        raw := g_CmdPal_WV2.ExecuteScriptAsync(js).await(4000)
        return Integer(raw)
    } catch {
        return -1
    }
}

Nmer_CpPerfProbePushCommandSnapshotNow() {
    if FuncExists("CommandPalette_PushPaletteFlags")
        try CommandPalette_PushPaletteFlags()
    if FuncExists("CommandPalette_PushCommandSnapshot")
        try CommandPalette_PushCommandSnapshot()
    if FuncExists("CommandPalette_DrainWebMessageQueue")
        try CommandPalette_DrainWebMessageQueue()
}

Nmer_CpPerfProbeEnsureCommandIndexReady(maxMs := 20000) {
    hostN := Nmer_CpPerfProbeHostSnapshotCount()
    if (hostN < 0)
        hostN := 0
    if (hostN = 0) {
        return Map("ok", false, "hostCount", 0, "webCount", 0, "reason", "host_snapshot_empty")
    }
    if !Nmer_CpPerfProbeWaitWebShellReady(Min(16000, maxMs)) {
        return Map("ok", false, "hostCount", hostN, "webCount", 0, "reason", "web_shell_not_ready")
    }
    deadline := A_TickCount + Max(4000, Integer(maxMs))
    while (A_TickCount < deadline) {
        Nmer_CpPerfProbePushCommandSnapshotNow()
        Nmer_CpPerfProbeYield(380)
        n := Nmer_CpPerfProbeQueryCommandIndexSize()
        if (n > 0)
            return Map("ok", true, "hostCount", hostN, "webCount", n, "reason", "")
        Nmer_CpPerfProbeYield(280)
    }
    n := Nmer_CpPerfProbeQueryCommandIndexSize()
    ok := n > 0
    return Map(
        "ok", ok,
        "hostCount", hostN,
        "webCount", Max(0, n),
        "reason", ok ? "" : "web_index_empty"
    )
}

Nmer_CpPerfProbeExecActionBrowse(text) {
    if !FuncExists("CommandPalette_ExecScript")
        return false
    qEsc := FuncExists("CommandPalette_JsEscapeForParse") ? CommandPalette_JsEscapeForParse(String(text))
        : String(text)
    js := "try{if(window.nmerPalette&&window.nmerPalette.runPerfBrowseQuery)window.nmerPalette.runPerfBrowseQuery('" . qEsc . "');"
        . "}catch(e){}"
    CommandPalette_ExecScript(js)
    if FuncExists("CommandPalette_ExecScript")
        CommandPalette_ExecScript("try{requestAnimationFrame(function(){requestAnimationFrame(function(){if(window.PalettePerfMarks&&window.PalettePerfMarks.flush)window.PalettePerfMarks.flush();});});}catch(e){}")
    Nmer_CpPerfProbeYield(520)
    if FuncExists("CommandPalette_ExecScript")
        CommandPalette_ExecScript("try{if(window.PalettePerfMarks&&window.PalettePerfMarks.flush)window.PalettePerfMarks.flush();}catch(e){}")
    Nmer_CpPerfProbeYield(120)
    return true
}

Nmer_CpPerfProbeRunManualEquivalentCapture() {
    steps := 0
    Nmer_CpPerfProbePrepareWarm()
    Nmer_CpPerfProbeShowCp()
    if !Nmer_CpPerfProbeWaitReady(16000) {
        return Map("pass", false, "code", "CP_NOT_READY", "detail", "webview_not_ready", "steps", steps, "mode", "manual_equivalent")
    }
    Nmer_CpPerfProbeYield(600)
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map("type", "palette_show"))
    Nmer_CpPerfProbeYield(400)
    idxInfo := Nmer_CpPerfProbeEnsureCommandIndexReady(22000)
    if !(idxInfo is Map) || !idxInfo.Get("ok", false) {
        reason := idxInfo is Map ? String(idxInfo.Get("reason", "palette_command_snapshot_empty")) : "palette_command_snapshot_empty"
        hostN := idxInfo is Map ? Integer(idxInfo.Get("hostCount", 0)) : 0
        webN := idxInfo is Map ? Integer(idxInfo.Get("webCount", 0)) : 0
        detail := "reason=" . reason . " host=" . hostN . " web=" . webN
        return Map("pass", false, "code", "CMD_INDEX_NOT_READY", "detail", detail, "steps", steps, "mode", "manual_equivalent")
    }
    if FuncExists("CommandPalette_ExecScript")
        CommandPalette_ExecScript("try{if(window.PalettePerfMarks){PalettePerfMarks.mark('palette_ready');PalettePerfMarks.flush();}}catch(e){}")
    Loop 2 {
        Nmer_CpPerfProbeExecActionBrowse("ahk")
        Nmer_CpPerfProbeYield(650)
        steps += 1
    }
    browseQueries := ["search", "palette", "config", "ahk", "command", "debug", "html", "json"]
    for q in browseQueries {
        Nmer_CpPerfProbeExecActionBrowse(String(q))
        Nmer_CpPerfProbeYield(480)
        steps += 1
    }
    Loop 10 {
        i := A_Index
        Nmer_CpPerfProbeExecActionBrowse("layout probe " . i)
        Nmer_CpPerfProbeYield(380)
        Nmer_CpPerfProbeExecActionBrowse("")
        Nmer_CpPerfProbeYield(360)
        steps += 1
    }
    Nmer_CpPerfProbeYield(300)
    if FuncExists("CommandPalette_PerfFlush")
        try CommandPalette_PerfFlush()
    Nmer_CpPerfProbeYield(150)
    Nmer_CpPerfProbeHideCp()
    return Map(
        "pass", true,
        "code", "CAPTURE_OK",
        "detail", "steps=" . steps . " mode=manual_equivalent warmup_discard=2",
        "steps", steps,
        "mode", "manual_equivalent",
        "warmupDiscardPaint", 2
    )
}

Nmer_CpPerfProbeRunCapture(fresh := false) {
    steps := 0
    if fresh
        Nmer_CpPerfProbePrepareFresh()
    else
        Nmer_CpPerfProbeHideCp()
    Nmer_CpPerfProbeShowCp()
    if !Nmer_CpPerfProbeWaitReady(14000) {
        return Map("pass", false, "code", "CP_NOT_READY", "detail", "webview_not_ready", "steps", steps)
    }
    Nmer_CpPerfProbeYield(750)
    if FuncExists("CommandPalette_PushToWeb")
        CommandPalette_PushToWeb(Map("type", "palette_show"))
    Nmer_CpPerfProbeYield(280)
    if FuncExists("CommandPalette_ExecScript")
        CommandPalette_ExecScript("try{if(window.PalettePerfMarks){PalettePerfMarks.mark('palette_ready');PalettePerfMarks.flush();}}catch(e){}")
    Nmer_CpPerfProbeSetIntent("local")
    Nmer_CpPerfProbeYield(700)
    if FuncExists("CommandPalette_SetInputText") {
        CommandPalette_SetInputText("ahk")
        Nmer_CpPerfProbeYield(2500)
        CommandPalette_SetInputText("")
        Nmer_CpPerfProbeYield(400)
    }
    localQueries := ["ahk", "palette", "html", "command", "search", "config", "debug", "json"]
    for q in localQueries {
        if FuncExists("CommandPalette_SetInputText")
            CommandPalette_SetInputText(String(q))
        Nmer_CpPerfProbeYield(2000)
        steps += 1
    }
    actionQueries := [">search", ">palette", ">config palette test"]
    Nmer_CpPerfProbeSetIntent("action")
    Nmer_CpPerfProbeYield(700)
    for q in actionQueries {
        if FuncExists("CommandPalette_SetInputText")
            CommandPalette_SetInputText(String(q))
        Nmer_CpPerfProbeYield(1000)
        steps += 1
    }
    Nmer_CpPerfProbeSetIntent("local")
    Nmer_CpPerfProbeYield(700)
    Loop 10 {
        i := A_Index
        if FuncExists("CommandPalette_SetInputText")
            CommandPalette_SetInputText("layout probe " . i)
        Nmer_CpPerfProbeYield(500)
        if FuncExists("CommandPalette_SetInputText")
            CommandPalette_SetInputText("")
        Nmer_CpPerfProbeYield(480)
        steps += 1
    }
    Nmer_CpPerfProbeYield(450)
    Nmer_CpPerfProbeHideCp()
    return Map("pass", true, "code", "CAPTURE_OK", "detail", "steps=" . steps . " mode=synthetic_turbo", "steps", steps, "mode", "synthetic_turbo")
}

Nmer_CpPerfProbePoll(*) {
    paths := Nmer_CpPerfProbePaths()
    if !FileExist(paths["req"])
        return
    raw := ""
    try raw := FileRead(paths["req"], "UTF-8")
    catch as errRead {
        Nmer_CpPerfProbeLog("read_fail " . errRead.Message)
        return
    }
    if (SubStr(raw, 1, 1) = Chr(0xFEFF))
        raw := SubStr(raw, 2)
    raw := Trim(raw)
    if (raw = "" || StrLen(raw) > 65536) {
        Nmer_CpPerfProbeWriteResult("", false, false, "PROBE_JSON_INVALID", "empty_or_oversize")
        try FileDelete(paths["req"])
        catch {
        }
        return
    }
    req := 0
    try req := Jxon_Load(raw)
    catch as errJson {
        Nmer_CpPerfProbeWriteResult("", false, false, "PROBE_JSON_INVALID", SubStr(String(errJson.Message), 1, 120))
        try FileDelete(paths["req"])
        catch {
        }
        return
    }
    try FileDelete(paths["req"])
    catch {
    }
    if !(req is Map) {
        Nmer_CpPerfProbeWriteResult("", false, false, "PROBE_JSON_INVALID", "expected_object")
        return
    }
    id := req.Has("id") ? String(req["id"]) : ""
    action := req.Has("action") ? StrLower(Trim(String(req["action"]))) : ""
    switch action {
        case "ping":
            Nmer_CpPerfProbeWriteResult(id, true, true, "PING_OK", "cp_perf_probe_ipc_active")
        case "capture_manual", "capture_manual_equivalent":
            info := Nmer_CpPerfProbeRunManualEquivalentCapture()
            ok := !!info.Get("pass", false)
            Nmer_CpPerfProbeWriteResult(id, true, ok, String(info.Get("code", "CAPTURE_FAIL")), String(info.Get("detail", "")), info)
        case "capture", "capture_all":
            mode := req.Has("mode") ? StrLower(Trim(String(req["mode"]))) : "synthetic_turbo"
            if (mode = "manual_equivalent") {
                info := Nmer_CpPerfProbeRunManualEquivalentCapture()
            } else {
                fresh := !req.Has("fresh") || !!req["fresh"]
                info := Nmer_CpPerfProbeRunCapture(fresh)
            }
            ok := !!info.Get("pass", false)
            Nmer_CpPerfProbeWriteResult(id, true, ok, String(info.Get("code", "CAPTURE_FAIL")), String(info.Get("detail", "")), info)
        default:
            Nmer_CpPerfProbeWriteResult(id, false, false, "PROBE_UNKNOWN_ACTION", action)
    }
}
