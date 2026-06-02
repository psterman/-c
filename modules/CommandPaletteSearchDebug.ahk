#Requires AutoHotkey v2.0

; CommandPaletteSearchDebug — 对比搜索中心 vs 命令面板本地搜索 HTTP 链路

global g_CmdPalDbg_Gui := 0
global g_CmdPalDbg_WV2 := 0
global g_CmdPalDbg_Ctrl := 0
global g_CmdPalDbg_Ready := false
global g_CmdPalDbg_WV2Pending := false
global g_CmdPalDbg_ProbeSeq := 0
global g_CmdPalDbg_ProbeResults := Map()
global g_CmdPalDbg_PendingKeyword := ""
global g_CmdPalDbg_CachedHealthSync := Map("line", "(未探测)", "ok", false, "tick", 0)
global g_CmdPalDbg_CachedHealthProxy := Map("line", "(未探测)", "ok", false, "tick", 0)
; 诊断窗默认不读取/展示本地 log 文件（仅 HTTP 探测，无上传）
global CommandPaletteSearchDebugShowLogs := false

CommandPalette_HandleSearchDebug() {
    try CommandPalette_ShowSearchDebug(true)
    catch as e {
        try TrayTip("命令面板", "无法打开诊断: " . e.Message, "Iconx 2")
        catch {
        }
    }
}

CommandPalette_ShowSearchDebug(activate := true) {
    CommandPaletteSearchDebug_Init()
    CommandPaletteSearchDebug_EnsureVisible()
    global g_CmdPalDbg_Gui
    if IsObject(g_CmdPalDbg_Gui) && g_CmdPalDbg_Gui.Hwnd {
        try WinSetAlwaysOnTop(1, "ahk_id " . g_CmdPalDbg_Gui.Hwnd)
        catch {
        }
        if activate {
            try WinActivate("ahk_id " . g_CmdPalDbg_Gui.Hwnd)
            catch {
            }
            try DllCall("SetWindowPos", "Ptr", g_CmdPalDbg_Gui.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0003)
            catch {
            }
        }
    }
    try TrayTip("命令面板", "已打开本地搜索诊断面板", "Iconi 1")
    catch {
    }
    SetTimer(CommandPaletteSearchDebug_PushSnapshot, -200)
}

CommandPalette_AutoShowSearchDebug(*) {
    try CommandPalette_ShowSearchDebug(false)
    catch as err {
        try OutputDebug("[CmdPalDbg] auto show: " . err.Message . "`n")
        catch {
        }
    }
}

CommandPaletteSearchDebug_EnsureVisible() {
    global g_CmdPalDbg_Gui
    if !IsObject(g_CmdPalDbg_Gui)
        return
    CommandPaletteSearchDebug_PositionNearPalette()
}

CommandPaletteSearchDebug_PositionNearPalette() {
    global g_CmdPalDbg_Gui
    if !IsObject(g_CmdPalDbg_Gui)
        return
    w := 920
    h := 720
    x := (A_ScreenWidth - w) // 2
    y := (A_ScreenHeight - h) // 2
    if FuncExists("CommandPalette_GetGuiHwnd") {
        ph := CommandPalette_GetGuiHwnd()
        if ph {
            try {
                WinGetPos(&px, &py, &pw, &phh, "ahk_id " . ph)
                x := px
                y := py + phh + 12
                if (y + h > A_ScreenHeight - 40)
                    y := py - h - 12
                if (y < 8)
                    y := 8
            } catch {
            }
        }
    }
    try g_CmdPalDbg_Gui.Show("x" . x . " y" . y . " w" . w . " h" . h)
    catch {
        try g_CmdPalDbg_Gui.Show()
        catch {
        }
    }
}

CommandPaletteSearchDebug_Init() {
    global g_CmdPalDbg_Gui, g_CmdPalDbg_WV2, g_CmdPalDbg_Ctrl, g_CmdPalDbg_Ready, g_CmdPalDbg_WV2Pending
    if !IsObject(g_CmdPalDbg_Gui) {
        g_CmdPalDbg_Gui := Gui("+Resize +AlwaysOnTop -DPIScale", "CommandPalette 本地搜索诊断")
        g_CmdPalDbg_Gui.BackColor := "1a2438"
        g_CmdPalDbg_Gui.OnEvent("Close", (*) => g_CmdPalDbg_Gui.Hide())
        g_CmdPalDbg_Gui.OnEvent("Size", (*) => CommandPaletteSearchDebug_ApplyBounds())
    }
    if !g_CmdPalDbg_Ready && !g_CmdPalDbg_WV2Pending {
        g_CmdPalDbg_WV2Pending := true
        WebView2_CreateWithSharedEnvAsync(g_CmdPalDbg_Gui.Hwnd, CommandPaletteSearchDebug_OnWV2Created, "cmdpal_search_debug")
    }
}

CommandPaletteSearchDebug_OnWV2Created(ctrl) {
    global g_CmdPalDbg_WV2, g_CmdPalDbg_Ctrl, g_CmdPalDbg_Ready, g_CmdPalDbg_WV2Pending
    g_CmdPalDbg_WV2Pending := false
    if !IsObject(ctrl) {
        try OutputDebug("[CmdPalDbg] WebView2 create failed`n")
        catch {
        }
        CommandPaletteSearchDebug_EnsureVisible()
        return
    }
    try {
        if ctrl.HasProp("CoreWebView2")
            g_CmdPalDbg_WV2 := ctrl.CoreWebView2
        else
            g_CmdPalDbg_WV2 := ctrl
    } catch {
        g_CmdPalDbg_WV2 := ctrl
    }
    g_CmdPalDbg_Ctrl := ctrl
    try g_CmdPalDbg_Ctrl.IsVisible := true
    try ApplyWebView2PerformanceSettings(g_CmdPalDbg_WV2)
    catch {
    }
    try WebView2_RegisterHostBridge(g_CmdPalDbg_WV2)
    catch {
    }
    g_CmdPalDbg_WV2.add_WebMessageReceived(CommandPaletteSearchDebug_OnWebMessage)
    try g_CmdPalDbg_WV2.add_NavigationCompleted(CommandPaletteSearchDebug_OnNavCompleted)
    catch {
    }
    try ApplyUnifiedWebViewAssets(g_CmdPalDbg_WV2)
    catch {
    }
    g_CmdPalDbg_WV2.Navigate(CommandPaletteSearchDebug_BuildPageUrl())
}

CommandPaletteSearchDebug_BuildPageUrl() {
    url := BuildAppLocalUrl("CommandPaletteSearchDebug.html")
    try {
        path := FuncExists("HtmlPanelPath") ? HtmlPanelPath("CommandPaletteSearchDebug.html") : (A_ScriptDir . "\html\CommandPaletteSearchDebug.html")
        ver := String(FileGetTime(path, "M"))
        url .= (InStr(url, "?") ? "&" : "?") . "v=" . ver
    } catch {
    }
    return url
}

CommandPaletteSearchDebug_ParseWebMessage(args) {
    try {
        raw := args.TryGetWebMessageAsString()
        if (raw != "") {
            m := Jxon_Load(raw)
            if (m is Map)
                return m
        }
    } catch {
    }
    try {
        jsonStr := args.WebMessageAsJson
        m := Jxon_Load(jsonStr)
        if (m is String)
            m := Jxon_Load(m)
        if (m is Map)
            return m
    } catch {
    }
    return 0
}

CommandPaletteSearchDebug_OnNavCompleted(*) {
    global g_CmdPalDbg_Ready
    g_CmdPalDbg_Ready := true
    CommandPaletteSearchDebug_ApplyBounds()
    CommandPaletteSearchDebug_EnsureVisible()
    SetTimer(CommandPaletteSearchDebug_PushSnapshot, -100)
}

CommandPaletteSearchDebug_ApplyBounds() {
    global g_CmdPalDbg_Gui, g_CmdPalDbg_Ctrl
    if !IsObject(g_CmdPalDbg_Gui) || !IsObject(g_CmdPalDbg_Ctrl)
        return
    try {
        g_CmdPalDbg_Gui.GetClientPos(, , &cw, &ch)
        g_CmdPalDbg_Ctrl.Bounds := { X: 0, Y: 0, Width: cw, Height: ch }
    } catch {
    }
}

CommandPaletteSearchDebug_OnWebMessage(sender, args) {
    msg := 0
    if FuncExists("CommandPalette_ParseWebMessage")
        msg := CommandPalette_ParseWebMessage(args)
    if !(msg is Map)
        msg := CommandPaletteSearchDebug_ParseWebMessage(args)
    if !(msg is Map)
        return
    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ = "cp_search_debug_ready" || typ = "cp_search_debug_refresh") {
        CommandPaletteSearchDebug_PushSnapshotHeavy()
        return
    }
    if (typ = "cp_search_debug_run_all") {
        kw := msg.Has("keyword") ? Trim(String(msg["keyword"])) : "1"
        try CommandPaletteSearchDebug_RunAllProbes(kw)
        catch as e {
            try TrayTip("搜索诊断", "探测失败: " . e.Message, "Iconx 2")
            catch {
            }
        }
        return
    }
}

CommandPaletteSearchDebug_PushSnapshotToWeb(snap) {
    global g_CmdPalDbg_WV2, g_CmdPalDbg_Ready
    if !g_CmdPalDbg_Ready || !IsObject(g_CmdPalDbg_WV2) || !(snap is Map)
        return false
    if !snap.Has("type")
        snap["type"] := "cp_search_debug_snapshot"
    try {
        if FuncExists("WebView_QueuePayload")
            return WebView_QueuePayload(g_CmdPalDbg_WV2, snap)
    } catch {
    }
    try {
        g_CmdPalDbg_WV2.PostWebMessageAsJson(Jxon_Dump(snap))
        return true
    } catch {
        return false
    }
}

CommandPaletteSearchDebug_PushSnapshot(*) {
    CommandPaletteSearchDebug_PushSnapshotToWeb(CommandPaletteSearchDebug_BuildSnapshot(false))
}

CommandPaletteSearchDebug_ReadLogTail(relPath, maxLines := 40) {
    root := FuncExists("Nmer_InstallRoot") ? Nmer_InstallRoot() : A_ScriptDir
    path := root . "\Cache\debug\" . relPath
    if !FileExist(path)
        return ""
    try {
        lines := []
        for line in StrSplit(FileRead(path, "UTF-8"), "`n", "`r") {
            if (Trim(line) != "")
                lines.Push(line)
        }
        start := lines.Length > maxLines ? (lines.Length - maxLines + 1) : 1
        out := ""
        Loop (lines.Length - start + 1) {
            i := start + A_Index - 1
            out .= (out = "" ? "" : "`n") . lines[i]
        }
        return out
    } catch {
        return "(读取失败)"
    }
}

CommandPaletteSearchDebug_PushSnapshotHeavy(*) {
    CommandPaletteSearchDebug_PushSnapshotToWeb(CommandPaletteSearchDebug_BuildSnapshot(true))
}

CommandPaletteSearchDebug_SetWinHttpNoProxy(whr) {
    if !IsObject(whr)
        return false
    for args in [[2, "<-loopback>", "<local>"], [2, "", ""], [2]] {
        try {
            if (args.Length = 1)
                whr.SetProxy(args[1])
            else if (args.Length = 2)
                whr.SetProxy(args[1], args[2])
            else
                whr.SetProxy(args[1], args[2], args[3])
            return true
        } catch {
        }
    }
    return false
}

CommandPaletteSearchDebug_HasHttpGetAsync() {
    global g_CoreAsyncHttp_Loaded, g_CoreAsyncHttpReqs
    if IsSet(g_CoreAsyncHttp_Loaded) && g_CoreAsyncHttp_Loaded
        return true
    return IsSet(g_CoreAsyncHttpReqs) && (g_CoreAsyncHttpReqs is Map)
}

CommandPaletteSearchDebug_HttpGetAsync(url, callback, opts := 0) {
    if !IsObject(callback)
        return false
    try {
        HttpGetAsync(url, callback, opts)
        return true
    } catch as e1 {
        try {
            CoreAsyncHttp_SendAsync("GET", url, "", callback, opts)
            return true
        } catch as e2 {
            try callback.Call(Map("ok", false, "error", e1.Message . " / " . e2.Message, "status", 0))
            catch {
            }
            return false
        }
    }
}

CommandPaletteSearchDebug_ProbeRow(status, ms, detail := "") {
    msNum := 0
    try msNum := Integer(ms)
    catch {
    }
    if (msNum < 0)
        msNum := 0
    return Map("status", String(status), "ms", msNum, "detail", String(detail))
}

CommandPaletteSearchDebug_ResetPaletteTurbo() {
    if FuncExists("CommandPalette_FinishTurboHttp")
        CommandPalette_FinishTurboHttp()
    if FuncExists("CommandPalette_ClearTurboPending")
        CommandPalette_ClearTurboPending()
    global g_CmdPal_TurboInFlight
    g_CmdPal_TurboInFlight := false
}

CommandPaletteSearchDebug_ResolveCoreExe() {
    exe := ""
    pid := ProcessExist("SearchCenterCore.exe")
    if pid {
        try exe := Trim(String(ProcessGetPath(pid)))
        catch {
        }
    }
    if (exe = "" || !FileExist(exe)) {
        if FuncExists("Nmer_SearchCenterCoreExe") {
            try {
                cand := Trim(String(Nmer_SearchCenterCoreExe()))
                if (cand != "" && FileExist(cand))
                    exe := cand
            } catch {
            }
        }
    }
    if (exe = "" && FuncExists("CommandPalette_ResolveSearchCoreExe")) {
        cand := Trim(String(CommandPalette_ResolveSearchCoreExe()))
        if (cand != "" && FileExist(cand))
            exe := cand
    }
    return exe
}

CommandPaletteSearchDebug_BuildSnapshot(heavy := false) {
    global g_CmdPal_TurboInFlight, g_CmdPal_TurboPendingMeta, g_CmdPal_TurboReqGen
    global g_CmdPalDbg_CachedHealthSync, g_CmdPalDbg_CachedHealthProxy, g_CmdPalDbg_ProbeResults
    global CommandPaletteSearchDebugShowLogs
    proc := ProcessExist("SearchCenterCore.exe") ? "运行中 PID=" . ProcessExist("SearchCenterCore.exe") : "未运行"
    if heavy {
        g_CmdPalDbg_CachedHealthSync := CommandPaletteSearchDebug_ProbeHealthSync(false)
        g_CmdPalDbg_CachedHealthSync["tick"] := A_TickCount
        g_CmdPalDbg_CachedHealthProxy := CommandPaletteSearchDebug_ProbeHealthSync(true)
        g_CmdPalDbg_CachedHealthProxy["tick"] := A_TickCount
    }
    healthSync := g_CmdPalDbg_CachedHealthSync
    healthProxy := g_CmdPalDbg_CachedHealthProxy
    exe := CommandPaletteSearchDebug_ResolveCoreExe()
    hasCmdPalTag := false
    if (g_CmdPalDbg_ProbeResults.Has("search_cmdpal")) {
        r := g_CmdPalDbg_ProbeResults["search_cmdpal"]
        if (r is Map && r.Has("status") && r["status"] = "ok")
            hasCmdPalTag := true
    }
    if !hasCmdPalTag && CommandPaletteSearchDebugShowLogs {
        logCore := CommandPaletteSearchDebug_ReadLogTail("core_async_http.log", 35)
        hasCmdPalTag := InStr(logCore, "cmdpal_turbo_search") > 0
    }
    activeN := 0
    try activeN := CoreAsyncHttp_GetActiveCount()
    catch {
    }
    statusRows := [
        Map("k", "SearchCenterCore.exe", "v", proc),
        Map("k", "exe 路径", "v", exe != "" ? exe : "(未找到)"),
        Map("k", "Health 同步(无代理绕过)", "v", healthSync["line"]),
        Map("k", "Health SetProxy(2)", "v", healthProxy["line"]),
        Map("k", "core_async 含 cmdpal", "v", hasCmdPalTag ? "是 — 探测/搜索已走 HttpGetAsync" : "否 — 请点「全部探测」或命令面板本地搜一次")
    ]
    pending := "无"
    if (g_CmdPal_TurboPendingMeta is Map)
        pending := "kw=" . (g_CmdPal_TurboPendingMeta.Has("kw") ? g_CmdPal_TurboPendingMeta["kw"] : "") . " tries=" . (g_CmdPal_TurboPendingMeta.Has("tries") ? g_CmdPal_TurboPendingMeta["tries"] : 0)
    paletteRows := [
        Map("k", "turboInFlight", "v", g_CmdPal_TurboInFlight ? "是" : "否"),
        Map("k", "turboReqGen", "v", String(g_CmdPal_TurboReqGen)),
        Map("k", "pendingMeta", "v", pending),
        Map("k", "HttpGetAsync", "v", CommandPaletteSearchDebug_HasHttpGetAsync()
            ? ("可用 · active=" . activeN)
            : "不可用 — 请确认 牛马.ahk 已 #Include CoreAsyncHttp.ahk 并重载")
    ]
    global g_CmdPalDbg_ProbeResults
    probes := Map()
    for id, r in g_CmdPalDbg_ProbeResults {
        if !(r is Map)
            continue
        st := r.Has("status") ? String(r["status"]) : "idle"
        ms := r.Has("ms") ? r["ms"] : 0
        det := r.Has("detail") ? String(r["detail"]) : ""
        probes[id] := CommandPaletteSearchDebug_ProbeRow(st, ms, det)
    }
    summary := Map("text", "待探测", "level", "idle")
    if probes.Has("search_cmdpal") && probes.Has("search_scwv") {
        stCp := probes["search_cmdpal"].Has("status") ? String(probes["search_cmdpal"]["status"]) : ""
        stSc := probes["search_scwv"].Has("status") ? String(probes["search_scwv"]["status"]) : ""
        if (stCp = "run" || stSc = "run") {
            summary := Map("text", "探测中…", "level", "warn")
        } else if (stCp = "ok" && stSc = "ok") {
            summary := Map("text", "两条链路均 OK", "level", "ok")
        } else if (stCp = "err" && stSc = "ok") {
            summary := Map("text", "仅命令面板路径失败 → 查代理/HttpGetAsync", "level", "err")
        } else if (stCp = "ok" && stSc = "err") {
            summary := Map("text", "仅 SCWV 路径失败", "level", "warn")
        } else if (stCp != "" || stSc != "") {
            summary := Map("text", "两条均失败 → 核心未响应", "level", "err")
        }
    } else if g_CmdPalDbg_ProbeResults.Count > 0 {
        anyRun := false
        for _, row in g_CmdPalDbg_ProbeResults {
            if (row is Map && row.Has("status") && row["status"] = "run") {
                anyRun := true
                break
            }
        }
        if anyRun
            summary := Map("text", "探测中…", "level", "warn")
    }
    diffNote := "<strong>说明：</strong>本面板仅在本机做 HTTP 探测，<strong>不会上传任何日志</strong>。默认不读取 Cache\\debug 下的 log 文件；判断链路是否正常请看上方探测结果与耗时。"
    if !hasCmdPalTag
        diffNote .= " 若「命令面板 HttpGetAsync」探测为 ok，则本地搜索链路已通。"
    return Map(
        "type", "cp_search_debug_snapshot",
        "statusRows", statusRows,
        "paletteRows", paletteRows,
        "probes", probes,
        "summary", summary,
        "diffNote", diffNote
    )
}

CommandPaletteSearchDebug_ProbeHealthSync(useProxy) {
    t0 := A_TickCount
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        if useProxy
            CommandPaletteSearchDebug_SetWinHttpNoProxy(whr)
        whr.Open("GET", "http://127.0.0.1:8080/health", false)
        whr.SetTimeouts(1500, 1500, 5000, 5000)
        whr.Send()
        ms := A_TickCount - t0
        st := Integer(whr.Status)
        body := SubStr(whr.ResponseText, 1, 20)
        return Map("ok", st = 200, "line", "HTTP " . st . " " . ms . "ms " . body)
    } catch as e {
        return Map("ok", false, "line", "失败 " . (A_TickCount - t0) . "ms: " . e.Message)
    }
}

CommandPaletteSearchDebug_RunAllProbes(keyword) {
    global g_CmdPalDbg_ProbeResults, g_CmdPalDbg_ProbeSeq, g_CmdPalDbg_PendingKeyword
    CommandPaletteSearchDebug_ResetPaletteTurbo()
    kw := Trim(String(keyword))
    if (kw = "")
        kw := "1"
    g_CmdPalDbg_PendingKeyword := kw
    g_CmdPalDbg_ProbeResults := Map()
    g_CmdPalDbg_ProbeSeq += 1
    seq := g_CmdPalDbg_ProbeSeq
    g_CmdPalDbg_ProbeResults["health_sync"] := CommandPaletteSearchDebug_ProbeRow("run", 0, "探测中")
    g_CmdPalDbg_ProbeResults["health_proxy"] := CommandPaletteSearchDebug_ProbeRow("run", 0, "探测中")
    g_CmdPalDbg_ProbeResults["search_scwv"] := CommandPaletteSearchDebug_ProbeRow("run", 0, "探测中")
    g_CmdPalDbg_ProbeResults["search_cmdpal"] := CommandPaletteSearchDebug_ProbeRow("run", 0, "探测中")
    CommandPaletteSearchDebug_PushSnapshot()
    SetTimer(CommandPaletteSearchDebug_ProbeHealthAsync.Bind(seq, false), -1)
    SetTimer(CommandPaletteSearchDebug_ProbeHealthAsync.Bind(seq, true), -80)
    SetTimer(CommandPaletteSearchDebug_ProbeSearchScwv.Bind(seq, kw), -160)
    SetTimer(CommandPaletteSearchDebug_ProbeSearchCmdPal.Bind(seq, kw), -240)
}

CommandPaletteSearchDebug_ProbeHealthAsync(seq, useProxy, *) {
    global g_CmdPalDbg_ProbeSeq, g_CmdPalDbg_ProbeResults
    global g_CmdPalDbg_CachedHealthSync, g_CmdPalDbg_CachedHealthProxy
    if (seq != g_CmdPalDbg_ProbeSeq)
        return
    id := useProxy ? "health_proxy" : "health_sync"
    t0 := A_TickCount
    r := CommandPaletteSearchDebug_ProbeHealthSync(useProxy)
    ms := A_TickCount - t0
    r["tick"] := A_TickCount
    if useProxy
        g_CmdPalDbg_CachedHealthProxy := r
    else
        g_CmdPalDbg_CachedHealthSync := r
    st := r["ok"] ? "ok" : "err"
    g_CmdPalDbg_ProbeResults[id] := CommandPaletteSearchDebug_ProbeRow(st, ms, r["line"])
    CommandPaletteSearchDebug_PushSnapshot()
}

CommandPaletteSearchDebug_BuildSearchUrl(kw, limit := 5) {
    encQ := kw
    try encQ := UriEncode(kw)
    catch {
    }
    return "http://127.0.0.1:8080/search?q=" . encQ . "&type=all&limit=" . Integer(limit) . "&offset=0"
}

CommandPaletteSearchDebug_OnHttpProbeDone(seq, t0, probeId, label, ret, *) {
    global g_CmdPalDbg_ProbeSeq, g_CmdPalDbg_ProbeResults
    if (seq != g_CmdPalDbg_ProbeSeq)
        return
    ms := A_TickCount - t0
    ok := false
    if (ret is Map && ret.Has("ok"))
        ok := !!ret["ok"]
    st := (ret is Map && ret.Has("status")) ? Integer(ret["status"]) : 0
    len := (ret is Map && ret.Has("text")) ? StrLen(ret["text"]) : 0
    err := (ret is Map && ret.Has("error")) ? String(ret["error"]) : ""
    detail := ok ? ("HTTP " . st . " len=" . len) : (err != "" ? err : label . " 失败")
    g_CmdPalDbg_ProbeResults[probeId] := CommandPaletteSearchDebug_ProbeRow(ok ? "ok" : "err", ms, detail)
    CommandPaletteSearchDebug_PushSnapshot()
    if (probeId = "search_cmdpal" || probeId = "search_scwv")
        SetTimer(CommandPaletteSearchDebug_PushSnapshotHeavy, -300)
}

CommandPaletteSearchDebug_ProbeSearchScwv(seq, kw, *) {
    global g_CmdPalDbg_ProbeSeq, g_CmdPalDbg_ProbeResults
    if (seq != g_CmdPalDbg_ProbeSeq)
        return
    url := CommandPaletteSearchDebug_BuildSearchUrl(kw, 5)
    t0 := A_TickCount
    cb := CommandPaletteSearchDebug_OnHttpProbeDone.Bind(seq, t0, "search_scwv", "SCWV")
    opts := Map(
        "tag", "cmdpal_dbg_scwv",
        "timeoutMs", 60000,
        "receiveTimeoutMs", 60000,
        "connectTimeoutMs", 5000,
        "sendTimeoutMs", 60000
    )
    if !CommandPaletteSearchDebug_HttpGetAsync(url, cb, opts) {
        g_CmdPalDbg_ProbeResults["search_scwv"] := CommandPaletteSearchDebug_ProbeRow("err", A_TickCount - t0, "HttpGetAsync 启动失败")
        CommandPaletteSearchDebug_PushSnapshot()
    }
}

CommandPaletteSearchDebug_ProbeSearchCmdPal(seq, kw, *) {
    global g_CmdPalDbg_ProbeSeq, g_CmdPalDbg_ProbeResults
    if (seq != g_CmdPalDbg_ProbeSeq)
        return
    url := CommandPaletteSearchDebug_BuildSearchUrl(kw, 5)
    t0 := A_TickCount
    cb := CommandPaletteSearchDebug_OnHttpProbeDone.Bind(seq, t0, "search_cmdpal", "CmdPal")
    opts := Map(
        "tag", "cmdpal_turbo_search",
        "timeoutMs", 60000,
        "receiveTimeoutMs", 60000,
        "connectTimeoutMs", 5000,
        "sendTimeoutMs", 60000
    )
    if !CommandPaletteSearchDebug_HttpGetAsync(url, cb, opts) {
        g_CmdPalDbg_ProbeResults["search_cmdpal"] := CommandPaletteSearchDebug_ProbeRow("err", A_TickCount - t0, "HttpGetAsync 启动失败")
        CommandPaletteSearchDebug_PushSnapshot()
        return
    }
    SetTimer((*) => CommandPaletteSearchDebug_ProbeCmdPalWatchdog(seq, t0), -65000)
}

CommandPaletteSearchDebug_ProbeCmdPalWatchdog(seq, t0, *) {
    global g_CmdPalDbg_ProbeSeq, g_CmdPalDbg_ProbeResults
    if (seq != g_CmdPalDbg_ProbeSeq)
        return
    r := g_CmdPalDbg_ProbeResults.Has("search_cmdpal") ? g_CmdPalDbg_ProbeResults["search_cmdpal"] : 0
    if (r is Map && r.Has("status") && r["status"] = "run") {
        g_CmdPalDbg_ProbeResults["search_cmdpal"] := CommandPaletteSearchDebug_ProbeRow("err", A_TickCount - t0, "65s 无回调")
        CommandPaletteSearchDebug_PushSnapshot()
    }
}
