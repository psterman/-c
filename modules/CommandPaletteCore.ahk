#Requires AutoHotkey v2.0

; CommandPaletteCore — Raycast 风格独立命令面板（WebView2，替代 nmer-wails-input.exe）

global CommandPaletteUseWebView := true
global CommandPaletteUseNativeEdit := false

global g_CmdPal_Gui := 0
global g_CmdPal_WV2 := 0
global g_CmdPal_Ctrl := 0
global g_CmdPal_Ready := false
global g_CmdPal_Visible := false
global g_CmdPal_Width := 760
global g_CmdPal_MinHeight := 72
global g_CmdPal_CurrentHeight := 72
global g_CmdPal_CornerRadius := 20
global g_CmdPal_Revealed := false

global g_CmdPal_ExecCache := ""
global g_CmdPal_ExecDirty := false
global g_CmdPal_ExecFileMtime := ""
global g_CmdPal_PendingShow := false
global g_CmdPal_ShowRetryCount := 0

CommandPalette_GetWv2() {
    global g_CmdPal_WV2
    return IsObject(g_CmdPal_WV2) ? g_CmdPal_WV2 : 0
}

CommandPalette_IsVisible() {
    global g_CmdPal_Visible
    return !!g_CmdPal_Visible
}

CommandPalette_GetGuiHwnd() {
    global g_CmdPal_Gui
    if IsObject(g_CmdPal_Gui) {
        try return g_CmdPal_Gui.Hwnd
        catch {
        }
    }
    return 0
}

_CmdPal_GetWebView2Class() {
    try return WebView2
    catch {
        return 0
    }
}

CommandPalette_ClearWindowRegion() {
    global g_CmdPal_Gui
    if !IsObject(g_CmdPal_Gui) || !g_CmdPal_Gui.Hwnd
        return
    try DllCall("user32\SetWindowRgn", "Ptr", g_CmdPal_Gui.Hwnd, "Ptr", 0, "Int", 1)
    catch {
    }
}

CommandPalette_ApplyRoundedRegion(radius := 0) {
    global g_CmdPal_Gui, g_CmdPal_CornerRadius
    if !IsObject(g_CmdPal_Gui) || !g_CmdPal_Gui.Hwnd
        return false
    hwnd := g_CmdPal_Gui.Hwnd
    iw := 0, ih := 0
    try WinGetClientPos(, , &iw, &ih, "ahk_id " hwnd)
    catch {
        return false
    }
    if (iw < 32 || ih < 32)
        return false
    rad := Integer(radius)
    if (rad < 8)
        rad := Integer(g_CmdPal_CornerRadius)
    ; 矮窗时缩小圆角，避免裁切输入行
    rad := Max(8, Min(rad, Min(iw, ih) // 2 - 2))
    try {
        rgn := DllCall("gdi32\CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", iw + 1, "Int", ih + 1, "Int", rad, "Int", rad, "Ptr")
        if rgn
            return !!DllCall("user32\SetWindowRgn", "Ptr", hwnd, "Ptr", rgn, "Int", 1)
    } catch {
    }
    return false
}

CommandPalette_ApplyChromaKey() {
    global g_CmdPal_Gui, g_CmdPal_Ctrl
    if IsObject(g_CmdPal_Gui) && g_CmdPal_Gui.Hwnd {
        try WinSetTransColor("010101", "ahk_id " . g_CmdPal_Gui.Hwnd)
        catch {
        }
        try WinSetTransparent(255, "ahk_id " . g_CmdPal_Gui.Hwnd)
        catch {
        }
    }
    if IsObject(g_CmdPal_Ctrl) {
        ; 对齐黑洞启动层：WebView 透明底 + 宿主 010101 色键；圆外由 Region 裁掉
        try g_CmdPal_Ctrl.DefaultBackgroundColor := 0x00000000
        catch {
        }
    }
}

CommandPalette_SyncHostShape() {
    CommandPalette_ApplyChromaKey()
    CommandPalette_ApplyRoundedRegion()
}

CommandPalette_Init() {
    global g_CmdPal_Gui, g_CmdPal_Width, g_CmdPal_CurrentHeight
    if IsObject(g_CmdPal_Gui)
        return
    g_CmdPal_Gui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", "NMER Command Palette")
    g_CmdPal_Gui.BackColor := "010101"
    g_CmdPal_Gui.OnEvent("Close", (*) => CommandPalette_Hide())
    g_CmdPal_Gui.OnEvent("Escape", (*) => CommandPalette_Hide())
    g_CmdPal_Gui.Show("w" . g_CmdPal_Width . " h" . g_CmdPal_CurrentHeight . " Hide")
    CommandPalette_SyncHostShape()
    WV2 := _CmdPal_GetWebView2Class()
    if !WV2 {
        try TrayTip("命令面板", "WebView2 未加载，无法创建命令面板", "Icon!")
        catch {
        }
        return
    }
    WebView2_CreateWithSharedEnvAsync(g_CmdPal_Gui.Hwnd, CommandPalette_OnWV2Created, "command_palette")
}

CommandPalette_OnWV2Created(ctrl) {
    global g_CmdPal_WV2, g_CmdPal_Ctrl, g_CmdPal_Ready
    g_CmdPal_Ctrl := ctrl
    g_CmdPal_WV2 := ctrl.CoreWebView2
    try g_CmdPal_Ctrl.IsVisible := true
    CommandPalette_SyncHostShape()
    CommandPalette_ApplyBounds()
    try {
        s := g_CmdPal_WV2.Settings
        s.AreDefaultContextMenusEnabled := false
        s.AreDevToolsEnabled := false
        s.IsWebMessageEnabled := true
        s.AreHostObjectsAllowed := true
    } catch {
    }
    try ApplyWebView2PerformanceSettings(g_CmdPal_WV2)
    catch {
    }
    try WebView2_RegisterHostBridge(g_CmdPal_WV2)
    catch {
    }
    g_CmdPal_WV2.add_WebMessageReceived(CommandPalette_OnWebMessage)
    try g_CmdPal_WV2.add_NavigationCompleted(CommandPalette_OnNavigationCompleted)
    catch {
    }
    try ApplyUnifiedWebViewAssets(g_CmdPal_WV2)
    g_CmdPal_WV2.Navigate(BuildAppLocalUrl("CommandPalette.html"))
    g_CmdPal_Ready := true
    if g_CmdPal_PendingShow
        SetTimer(CommandPalette_DoShow, -1)
}

CommandPalette_OnNavigationCompleted(sender, args) {
    global g_CmdPal_Visible, g_CmdPal_Revealed
    try ok := args.IsSuccess
    catch {
        ok := true
    }
    if !ok
        return
    if g_CmdPal_Visible {
        CommandPalette_PushThemeToWeb()
        if !g_CmdPal_Revealed
            SetTimer(CommandPalette_Reveal, -1)
    }
    CommandPalette_SyncHostShape()
    SetTimer(CommandPalette_PushEmptyQuery, -80)
}

CommandPalette_ApplyBounds() {
    global g_CmdPal_Gui, g_CmdPal_Ctrl, g_CmdPal_Width, g_CmdPal_CurrentHeight
    if !IsObject(g_CmdPal_Ctrl) || !IsObject(g_CmdPal_Gui)
        return
    WV2 := _CmdPal_GetWebView2Class()
    if !WV2
        return
    try WinGetClientPos(, , &cw, &ch, g_CmdPal_Gui.Hwnd)
    catch {
        cw := g_CmdPal_Width
        ch := g_CmdPal_CurrentHeight
    }
    rc := WV2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    try g_CmdPal_Ctrl.Bounds := rc
    catch {
    }
}

CommandPalette_CenterAndShow() {
    global g_CmdPal_Gui, g_CmdPal_Width, g_CmdPal_CurrentHeight, g_CmdPal_Visible, g_CmdPal_Revealed, g_CmdPal_Ctrl
    w := g_CmdPal_Width
    h := g_CmdPal_CurrentHeight
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    idx := 1
    try idx := MonitorGet(mx, my)
    catch {
    }
    ml := 0
    mt := 0
    mr := A_ScreenWidth
    mb := A_ScreenHeight
    try MonitorGet(idx, &ml, &mt, &mr, &mb)
    catch {
    }
    x := ml + (mr - ml - w) // 2
    y := mt + Round((mb - mt) * 0.28)
    if (y < mt + 8)
        y := mt + 8
    g_CmdPal_Revealed := false
    try g_CmdPal_Gui.Show("x" . x . " y" . y . " w" . w . " h" . h)
    catch {
    }
    CommandPalette_ApplyBounds()
    CommandPalette_SyncHostShape()
    try WinActivate("ahk_id " . g_CmdPal_Gui.Hwnd)
    catch {
    }
    g_CmdPal_Visible := true
    g_CmdPal_Revealed := true
    CommandPalette_PushThemeToWeb()
    try WebView2_MoveFocusProgrammatic(g_CmdPal_Ctrl)
    catch {
    }
    SetTimer(CommandPalette_DeferredFocus, -120)
}

CommandPalette_DeferredFocus(*) {
    global g_CmdPal_Visible, g_CmdPal_WV2, g_CmdPal_Ctrl
    if !g_CmdPal_Visible || !g_CmdPal_WV2
        return
    CommandPalette_PushToWeb(Map("type", "palette_focus"))
    try WebView2_MoveFocusProgrammatic(g_CmdPal_Ctrl)
    catch {
    }
    if FuncExists("SearchCenter_ScheduleIMEStabilize")
        SearchCenter_ScheduleIMEStabilize()
}

CommandPalette_Reveal(*) {
    global g_CmdPal_Gui, g_CmdPal_Revealed, g_CmdPal_Visible
    if !g_CmdPal_Visible || g_CmdPal_Revealed || !IsObject(g_CmdPal_Gui)
        return
    g_CmdPal_Revealed := true
    CommandPalette_SyncHostShape()
}

CommandPalette_Show() {
    global g_CmdPal_Ready, g_CmdPal_PendingShow, g_CmdPal_ShowRetryCount
    CommandPalette_Init()
    if !IsObject(g_CmdPal_Gui)
        return false
    g_CmdPal_PendingShow := true
    g_CmdPal_ShowRetryCount := 0
    if g_CmdPal_Ready {
        CommandPalette_DoShow()
        return true
    }
    SetTimer(CommandPalette_RetryShow, -250)
    return true
}

CommandPalette_RetryShow(*) {
    global g_CmdPal_Ready, g_CmdPal_PendingShow, g_CmdPal_ShowRetryCount
    if !g_CmdPal_PendingShow
        return
    g_CmdPal_ShowRetryCount += 1
    if g_CmdPal_Ready {
        CommandPalette_DoShow()
        return
    }
    if (g_CmdPal_ShowRetryCount >= 40) {
        g_CmdPal_PendingShow := false
        try TrayTip("命令面板", "WebView2 初始化超时，请重载脚本后再试", "Icon!")
        catch {
        }
        return
    }
    SetTimer(CommandPalette_RetryShow, -250)
}

CommandPalette_DoShow(*) {
    global g_CmdPal_PendingShow, CapsLock
    g_CmdPal_PendingShow := false
    CapsLock := false
    CommandPalette_CenterAndShow()
    SetTimer(CommandPalette_PushEmptyQuery, -180)
    SetTimer(CommandPalette_RevealFallback, -600)
}

CommandPalette_RevealFallback(*) {
    global g_CmdPal_Visible, g_CmdPal_Revealed
    if g_CmdPal_Visible && !g_CmdPal_Revealed
        CommandPalette_Reveal()
}

CommandPalette_PushEmptyQuery(*) {
    CommandPalette_HandleQuery("")
}

CommandPalette_Hide(*) {
    global g_CmdPal_Gui, g_CmdPal_Visible, g_CmdPal_Revealed
    g_CmdPal_Visible := false
    g_CmdPal_Revealed := false
    if IsObject(g_CmdPal_Gui) {
        try g_CmdPal_Gui.Hide()
        catch {
        }
        CommandPalette_ClearWindowRegion()
    }
}

CommandPalette_ApplyHeight(h) {
    global g_CmdPal_Gui, g_CmdPal_Width, g_CmdPal_CurrentHeight, g_CmdPal_MinHeight
    nh := Integer(h)
    if (nh < g_CmdPal_MinHeight)
        nh := g_CmdPal_MinHeight
    if (nh > 480)
        nh := 480
    g_CmdPal_CurrentHeight := nh
    if !IsObject(g_CmdPal_Gui)
        return
    try {
        WinGetPos(&x, &y, , , g_CmdPal_Gui.Hwnd)
        g_CmdPal_Gui.Move(x, y, g_CmdPal_Width, nh)
    } catch {
    }
    CommandPalette_ApplyBounds()
    SetTimer(CommandPalette_SyncHostShape, -40)
}

CommandPalette_PushToWeb(payload) {
    global g_CmdPal_WV2
    if !IsObject(g_CmdPal_WV2)
        return false
    try {
        if FuncExists("WebView_QueuePayload")
            return WebView_QueuePayload(g_CmdPal_WV2, payload)
        json := Jxon_Dump(payload)
        g_CmdPal_WV2.PostWebMessageAsJson(json)
        return true
    } catch {
        return false
    }
}

CommandPalette_ExecScript(js) {
    global g_CmdPal_WV2
    if !IsObject(g_CmdPal_WV2)
        return false
    try {
        g_CmdPal_WV2.ExecuteScriptAsync(js)
        return true
    } catch {
        return false
    }
}

CommandPalette_SetInputText(text) {
    CommandPalette_PushToWeb(Map("type", "palette_set_input", "text", String(text)))
}

CommandPalette_PushStatus(message, status := "idle") {
    CommandPalette_PushToWeb(Map("type", "palette_status", "message", String(message), "status", String(status)))
}

CommandPalette_PushResults(items) {
    CommandPalette_PushToWeb(Map("type", "palette_results", "items", items))
}

CommandPalette_ParseWebMessage(args) {
    if FuncExists("FloatingToolbar_ParseWebMessage")
        return FloatingToolbar_ParseWebMessage(args)
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
        m := Jxon_Load(args.WebMessageAsJson)
        if (m is String)
            m := Jxon_Load(m)
        if (m is Map)
            return m
    } catch {
    }
    return 0
}

CommandPalette_OnWebMessage(sender, args) {
    msg := CommandPalette_ParseWebMessage(args)
    if !(msg is Map)
        return
    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ = "palette_ready") {
        CommandPalette_PushThemeToWeb()
        SetTimer(CommandPalette_Reveal, -1)
        SetTimer(CommandPalette_DeferredFocus, -80)
        SetTimer(CommandPalette_SyncHostShape, -1)
        return
    }
    if (typ = "palette_resize") {
        h := msg.Has("height") ? Integer(msg["height"]) : 76
        CommandPalette_ApplyHeight(h)
        return
    }
    if (typ = "palette_hide") {
        CommandPalette_Hide()
        return
    }
    if (typ = "palette_query") {
        q := msg.Has("input") ? String(msg["input"]) : ""
        CommandPalette_HandleQuery(q)
        return
    }
    if (typ = "palette_execute") {
        CommandPalette_HandleExecute(msg)
        return
    }
    if (typ = "palette_voice_toggle") {
        CommandPalette_HandleVoiceToggle()
        return
    }
}

CommandPalette_EnsureCommandsLoaded() {
    if FuncExists("VK_EnsureInit")
        VK_EnsureInit(true)
    else if FuncExists("_LoadCommands")
        _LoadCommands()
}

CommandPalette_ScoreCommand(name, keywords, q) {
    if (q = "")
        return 1
    label := StrLower(String(name))
    q := String(q)
    if (SubStr(label, 1, StrLen(q)) = q)
        return 120
    if InStr(label, q)
        return 90
    score := 0
    for kw in keywords {
        kl := StrLower(String(kw))
        if (SubStr(kl, 1, StrLen(q)) = q) {
            if (score < 80)
                score := 80
            continue
        }
        if InStr(kl, q) && score < 60
            score := 60
    }
    if (score = 0) {
        for part in StrSplit(q, A_Space) {
            p := Trim(String(part))
            if (p != "" && InStr(label, p))
                score += 20
        }
    }
    return Integer(score)
}

CommandPalette_GetBindingLabel(cmdId) {
    global g_InverseBindings, g_Bindings
    if IsSet(g_InverseBindings) && g_InverseBindings is Map && g_InverseBindings.Has(cmdId)
        return String(g_InverseBindings[cmdId])
    if IsSet(g_Bindings) && g_Bindings is Map && g_Bindings.Has(cmdId) {
        b := String(g_Bindings[cmdId])
        if (b != "" && b != "NONE")
            return b
    }
    return ""
}

CommandPalette_RowScore(row) {
    if !(IsObject(row))
        return 0
    raw := 0
    try {
        if row is Map
            raw := row.Has("score") ? row["score"] : 0
        else
            raw := row.score
    } catch {
        raw := 0
    }
    try return Integer(raw)
    catch {
        return 0
    }
}

CommandPalette_RowText(row, key) {
    if !(IsObject(row))
        return ""
    try {
        if row is Map
            return row.Has(key) ? String(row[key]) : ""
        if row.HasProp(key)
            return String(row.%key%)
    } catch {
    }
    return ""
}

CommandPalette_CompareScoredRows(a, b, *) {
    sa := CommandPalette_RowScore(a)
    sb := CommandPalette_RowScore(b)
    if (sa != sb)
        return sb - sa
    na := CommandPalette_RowText(a, "name")
    nb := CommandPalette_RowText(b, "name")
    c := StrCompare(na, nb, false)
    if (c > 0)
        return 1
    if (c < 0)
        return -1
    return 0
}

CommandPalette_SortScoredRows(&scored) {
    if (scored.Length < 2)
        return
    n := scored.Length
    loop n - 1 {
        swapped := false
        loop n - A_Index {
            i := A_Index
            if (CommandPalette_CompareScoredRows(scored[i], scored[i + 1]) > 0) {
                tmp := scored[i]
                scored[i] := scored[i + 1]
                scored[i + 1] := tmp
                swapped := true
            }
        }
        if !swapped
            break
    }
}

CommandPalette_BuildActionList(query := "") {
    q := StrLower(Trim(String(query)))
    if (q = "")
        return CommandPalette_BuildEmptyStateList()
    CommandPalette_EnsureCommandsLoaded()
    global g_Commands
    out := []
    if !(IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList"))
        return out
    cmdList := g_Commands["CommandList"]
    scored := []
    for cmdId, meta in cmdList {
        if !(meta is Map)
            continue
        id := Trim(String(cmdId))
        if (id = "")
            continue
        name := meta.Has("name") ? String(meta["name"]) : id
        desc := meta.Has("desc") ? String(meta["desc"]) : ""
        kws := []
        if meta.Has("keywords") && meta["keywords"] is Array {
            for kw in meta["keywords"]
                kws.Push(String(kw))
        }
        s := CommandPalette_ScoreCommand(name, kws, q)
        if (s <= 0)
            continue
        scored.Push(Map(
            "score", Integer(s),
            "id", id,
            "name", name,
            "desc", desc
        ))
    }
    if (scored.Length = 0)
        return out
    CommandPalette_SortScoredRows(&scored)
    lim := Min(8, scored.Length)
    loop lim {
        i := A_Index
        row := scored[i]
        out.Push(Map(
            "id", CommandPalette_RowText(row, "id"),
            "label", CommandPalette_RowText(row, "name"),
            "desc", CommandPalette_RowText(row, "desc"),
            "binding", CommandPalette_GetBindingLabel(CommandPalette_RowText(row, "id")),
            "matched", true,
            "kind", "command"
        ))
    }
    return out
}

CommandPalette_BuildEmptyStateList() {
    out := []
    if FuncExists("_SCWV_EnsureHistoryCacheLoaded")
        _SCWV_EnsureHistoryCacheLoaded()
    global g_SC_HistoryCache
    if (IsSet(g_SC_HistoryCache) && g_SC_HistoryCache is Array) {
        lim := Min(8, g_SC_HistoryCache.Length)
        loop lim {
            k := String(g_SC_HistoryCache[A_Index])
            if (k = "")
                continue
            out.Push(Map(
                "id", "",
                "label", k,
                "desc", "最近搜索",
                "binding", "",
                "matched", false,
                "kind", "history"
            ))
        }
    }
    for row in CommandPalette_LoadExecHistory() {
        if (out.Length >= 20)
            break
        cid := row.Has("cmdId") ? String(row["cmdId"]) : ""
        out.Push(Map(
            "id", cid,
            "label", row.Has("name") ? String(row["name"]) : cid,
            "desc", row.Has("query") ? ("最近执行 · " . String(row["query"])) : "最近执行",
            "binding", CommandPalette_GetBindingLabel(cid),
            "matched", false,
            "kind", "exec"
        ))
    }
    CommandPalette_EnsureCommandsLoaded()
    global g_Commands
    if (out.Length < 12 && IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList")) {
        for cmdId, meta in g_Commands["CommandList"] {
            if (out.Length >= 20)
                break
            if !(meta is Map)
                continue
            id := Trim(String(cmdId))
            out.Push(Map(
                "id", id,
                "label", meta.Has("name") ? String(meta["name"]) : id,
                "desc", meta.Has("desc") ? String(meta["desc"]) : "",
                "binding", CommandPalette_GetBindingLabel(id),
                "matched", false,
                "kind", "command"
            ))
        }
    }
    return out
}

CommandPalette_HandleQuery(q) {
    try {
        CommandPalette_PushResults(CommandPalette_BuildActionList(q))
    } catch as e {
        try TrayTip("命令面板", "搜索失败: " . e.Message, "Icon!")
        catch {
        }
        CommandPalette_PushResults([])
    }
}

CommandPalette_HandleExecute(msg) {
    kind := msg.Has("kind") ? StrLower(String(msg["kind"])) : "command"
    query := msg.Has("query") ? Trim(String(msg["query"])) : ""
    cmdId := msg.Has("cmdId") ? Trim(String(msg["cmdId"])) : ""
    label := msg.Has("label") ? String(msg["label"]) : ""
    if (kind = "history") {
        pick := label != "" ? label : query
        if (pick != "") {
            CommandPalette_SetInputText(pick)
            SetTimer(() => CommandPalette_HandleQuery(pick), -80)
        }
        return
    }
    if (cmdId = "" && query != "" && kind = "history") {
        CommandPalette_SetInputText(query)
        SetTimer(() => CommandPalette_HandleQuery(query), -80)
        return
    }
    if (cmdId = "")
        return
    if (query != "" && FuncExists("_SCWV_RecordSearchHistory"))
        _SCWV_RecordSearchHistory(query)
    name := label
    if (name = "") {
        CommandPalette_EnsureCommandsLoaded()
        global g_Commands
        if (IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList")) {
            cl := g_Commands["CommandList"]
            if (cl is Map && cl.Has(cmdId) && cl[cmdId] is Map)
                name := cl[cmdId].Has("name") ? String(cl[cmdId]["name"]) : cmdId
        }
    }
    CommandPalette_RecordExec(cmdId, name, query)
    if FuncExists("VK_Execute")
        VK_Execute(cmdId)
    CommandPalette_Hide()
}

CommandPalette_HandleVoiceToggle() {
    if FuncExists("WailsWhisper_IsRecording") && WailsWhisper_IsRecording() {
        if FuncExists("WailsWhisper_StopAndTranscribe")
            SetTimer(WailsWhisper_StopAndTranscribe, -30)
        return
    }
    if FuncExists("WailsWhisper_StartRecording")
        WailsWhisper_StartRecording()
}

CommandPalette_ExecFilePath() {
    return A_ScriptDir . "\Data\CommandPaletteExec.json"
}

CommandPalette_ExecReadMtime() {
    path := CommandPalette_ExecFilePath()
    if !FileExist(path)
        return ""
    try return FileGetTime(path, "M")
    catch {
        return ""
    }
}

CommandPalette_EnsureExecCacheLoaded() {
    global g_CmdPal_ExecCache
    if (Type(g_CmdPal_ExecCache) = "Array")
        return
    CommandPalette_ReloadExecFromDisk()
}

CommandPalette_ReloadExecFromDisk() {
    global g_CmdPal_ExecCache, g_CmdPal_ExecFileMtime
    path := CommandPalette_ExecFilePath()
    arr := []
    if FileExist(path) {
        try {
            raw := FileRead(path, "UTF-8")
            if (raw != "")
                arr := Jxon_Load(raw)
        } catch {
            arr := []
        }
    }
    if (Type(arr) != "Array")
        arr := []
    g_CmdPal_ExecCache := arr
    g_CmdPal_ExecFileMtime := CommandPalette_ExecReadMtime()
}

CommandPalette_LoadExecHistory() {
    CommandPalette_EnsureExecCacheLoaded()
    global g_CmdPal_ExecCache, g_CmdPal_ExecDirty, g_CmdPal_ExecFileMtime
    if !g_CmdPal_ExecDirty && CommandPalette_ExecReadMtime() != g_CmdPal_ExecFileMtime
        CommandPalette_ReloadExecFromDisk()
    if (Type(g_CmdPal_ExecCache) = "Array")
        return g_CmdPal_ExecCache
    return []
}

CommandPalette_RecordExec(cmdId, name, query := "") {
    global g_CmdPal_ExecCache, g_CmdPal_ExecDirty
    id := Trim(String(cmdId))
    if (id = "")
        return
    CommandPalette_EnsureExecCacheLoaded()
    row := Map("cmdId", id, "name", String(name), "query", Trim(String(query)), "at", A_Now)
    newArr := [row]
    for item in g_CmdPal_ExecCache {
        if !(item is Map)
            continue
        oldId := item.Has("cmdId") ? String(item["cmdId"]) : ""
        if (oldId = id && item.Has("query") && String(item["query"]) = Trim(String(query)))
            continue
        newArr.Push(item)
        if (newArr.Length >= 50)
            break
    }
    g_CmdPal_ExecCache := newArr
    g_CmdPal_ExecDirty := true
    SetTimer(CommandPalette_FlushExecHistory, 0)
    SetTimer(CommandPalette_FlushExecHistory, -1500)
}

CommandPalette_FlushExecHistory(*) {
    global g_CmdPal_ExecCache, g_CmdPal_ExecDirty, g_CmdPal_ExecFileMtime
    if !g_CmdPal_ExecDirty
        return
    path := CommandPalette_ExecFilePath()
    try DirCreate(A_ScriptDir . "\Data")
    catch {
    }
    try {
        FileDelete(path)
        FileAppend(Jxon_Dump(g_CmdPal_ExecCache), path, "UTF-8")
        g_CmdPal_ExecFileMtime := CommandPalette_ExecReadMtime()
        g_CmdPal_ExecDirty := false
    } catch {
    }
}

CommandPalette_OnInputActivated() {
    if !CommandPalette_IsVisible()
        CommandPalette_Show()
    else
        SetTimer(CommandPalette_DeferredFocus, -150)
}

CommandPalette_NormalizeThemeToken(raw, fallback := "dark") {
    s := StrLower(Trim(String(raw)))
    if (s = "light" || s = "lite" || s = "浅色")
        return "light"
    if (s = "dark")
        return "dark"
    return (fallback = "light") ? "light" : "dark"
}

CommandPalette_GetThemeMode() {
    if FuncExists("FloatingToolbar_GetThemeMode")
        return CommandPalette_NormalizeThemeToken(FloatingToolbar_GetThemeMode())
    if FuncExists("_VK_GetThemeMode")
        return CommandPalette_NormalizeThemeToken(_VK_GetThemeMode())
    try {
        global ThemeMode
        if IsSet(ThemeMode)
            return CommandPalette_NormalizeThemeToken(ThemeMode)
    } catch {
    }
    return "dark"
}

CommandPalette_PushThemeToWeb(override := "") {
    tm := (Trim(String(override)) != "")
        ? CommandPalette_NormalizeThemeToken(override)
        : CommandPalette_GetThemeMode()
    CommandPalette_PushToWeb(Map("type", "set_theme", "themeMode", tm))
}

; 命令面板可见时 Esc 关闭（WebView 未收到按键时由宿主兜底）
#HotIf CommandPalette_IsVisible()
Esc:: {
    CommandPalette_Hide()
}
#HotIf
