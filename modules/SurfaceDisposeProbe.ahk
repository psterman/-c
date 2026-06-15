; SurfaceDisposeProbe.ahk — 命令面板内 Surface Dispose 开发探针（S1 验证用）

SurfaceDisposeProbe_ActionCatalog() {
    return [
        Map(
            "id", "dev_surface_dispose_ftb",
            "name", ">dispose ftb",
            "desc", "在动作框输入后回车；或 Ctrl+Shift+F（勿当普通提问）",
            "keywords", [">dispose", "dispose ftb"]
        ),
        Map(
            "id", "dev_surface_restore_ftb",
            "name", "Surface Restore · 悬浮栏",
            "desc", "重新显示悬浮工具栏（Dispose 后恢复）",
            "keywords", ["surface", "restore", "ftb", "toolbar", "悬浮", "工具栏", "show"]
        ),
        Map(
            "id", "dev_surface_dispose_clipboard",
            "name", "Surface Dispose · 剪贴板",
            "desc", "释放剪贴板面板 WebView（unified 时仅关重定向）",
            "keywords", ["surface", "dispose", "clipboard", "剪贴板", "cp"]
        ),
        Map(
            "id", "dev_surface_dispose_config",
            "name", "Surface Dispose · 设置",
            "desc", "释放设置中心 WebView 宿主",
            "keywords", ["surface", "dispose", "config", "设置", "configwebview"]
        )
    ]
}

SurfaceDisposeProbe_ScoreRow(row, q) {
    q := StrLower(Trim(String(q)))
    if (q = "")
        return 0
    name := row.Has("name") ? String(row["name"]) : ""
    kws := row.Has("keywords") ? row["keywords"] : []
    if FuncExists("CommandPalette_ScoreCommand")
        return CommandPalette_ScoreCommand(name, kws, q)
    hay := StrLower(name)
    for kw in kws
        hay .= " " . StrLower(String(kw))
    if InStr(hay, q)
        return 100
    return 0
}

SurfaceDisposeProbe_AppendMatchingActions(&out, query := "") {
    q := Trim(String(query))
    if (q = "")
        return
    scored := []
    for row in SurfaceDisposeProbe_ActionCatalog() {
        s := SurfaceDisposeProbe_ScoreRow(row, q)
        if (s <= 0)
            continue
        scored.Push(Map("score", s, "row", row))
    }
    if (scored.Length = 0)
        return
    loop scored.Length {
        i := A_Index
        j := i + 1
        while (j <= scored.Length) {
            if (scored[j]["score"] > scored[i]["score"]) {
                tmp := scored[i]
                scored[i] := scored[j]
                scored[j] := tmp
            }
            j += 1
        }
    }
    for item in scored {
        row := item["row"]
        out.Push(Map(
            "id", String(row["id"]),
            "label", String(row["name"]),
            "desc", String(row["desc"]),
            "binding", "",
            "matched", true,
            "kind", "command"
        ))
    }
}

SurfaceDisposeProbe_TargetAliases() {
    return Map(
        "ftb", "dev_surface_dispose_ftb",
        "toolbar", "dev_surface_dispose_ftb",
        "floating_toolbar", "dev_surface_dispose_ftb",
        "悬浮栏", "dev_surface_dispose_ftb",
        "工具栏", "dev_surface_dispose_ftb",
        "clipboard", "dev_surface_dispose_clipboard",
        "cp", "dev_surface_dispose_clipboard",
        "剪贴板", "dev_surface_dispose_clipboard",
        "config", "dev_surface_dispose_config",
        "settings", "dev_surface_dispose_config",
        "设置", "dev_surface_dispose_config"
    )
}

SurfaceDisposeProbe_ResolveTargetAlias(target) {
    key := StrLower(Trim(String(target)))
    if (key = "")
        return ""
    aliases := SurfaceDisposeProbe_TargetAliases()
    if aliases.Has(key)
        return aliases[key]
    return ""
}

SurfaceDisposeProbe_ParseSlashQuery(text) {
    t := Trim(String(text))
    if (t = "")
        return ""
    if (SubStr(t, 1, 1) != ">")
        return ""
    body := Trim(SubStr(t, 2))
    if (body = "")
        return ""
    if RegExMatch(body, "i)^(?:surface\s+)?dispose\s+(.+)$", &m)
        return SurfaceDisposeProbe_ResolveTargetAlias(m[1])
    if RegExMatch(body, "i)^(?:surface\s+)?restore\s+(.+)$", &m) {
        key := StrLower(Trim(String(m[1])))
        if (key = "ftb" || key = "toolbar" || key = "floating_toolbar" || key = "悬浮栏" || key = "工具栏")
            return "dev_surface_restore_ftb"
    }
    return ""
}

SurfaceDisposeProbe_TryExecuteSlashQuery(text) {
    cmdId := SurfaceDisposeProbe_ParseSlashQuery(text)
    if (cmdId = "")
        return ""
    SurfaceDisposeProbe_TryExecute(cmdId)
    return cmdId
}

SurfaceDisposeProbe_MapSurfaceId(cmdId) {
    switch String(cmdId) {
        case "dev_surface_dispose_ftb":
            return "floating_toolbar"
        case "dev_surface_dispose_clipboard":
            return "clipboard_panel"
        case "dev_surface_dispose_config":
            return "config_webview"
        default:
            return ""
    }
}

SurfaceDisposeProbe_TryExecute(cmdId) {
    id := Trim(String(cmdId))
    if (id = "")
        return false
    if (id = "dev_surface_restore_ftb") {
        try {
            if FuncExists("SurfaceIntent_Open")
                SurfaceIntent_Open("floating_toolbar", Map("reason", "palette_probe_restore"))
            else if FuncExists("ShowFloatingToolbar")
                ShowFloatingToolbar()
            SurfaceDisposeProbe_Notify("已 Restore floating_toolbar")
        } catch as err {
            SurfaceDisposeProbe_Notify("Restore 失败: " . err.Message, true)
        }
        return true
    }
    sid := SurfaceDisposeProbe_MapSurfaceId(id)
    if (sid = "")
        return false
    try {
        probeMeta := Map("reason", "palette_probe", "cmdId", id)
        if FuncExists("SurfaceIntent_Dispose")
            SurfaceIntent_Dispose(sid, probeMeta)
        else if FuncExists("SurfaceExecutor_Dispose")
            SurfaceExecutor_Dispose(sid, probeMeta)
        else
            throw Error("SurfaceIntent_Dispose 未载入")
        SurfaceDisposeProbe_Notify("已 Dispose " . sid . " - 请运行 capture-memory-baseline.ps1")
    } catch as err {
        SurfaceDisposeProbe_Notify("Dispose 失败: " . err.Message, true)
        return true
    }
    return true
}

SurfaceDisposeProbe_Notify(msg, isErr := false) {
    title := "Surface 探针"
    try TrayTip(String(msg), title, isErr ? "Icon! 4" : "Iconi 4")
    catch {
        try MsgBox(String(msg), title, (isErr ? 0x10 : 0x40) | 0x1000)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    try {
        if FuncExists("SurfaceManager_RecordEvent")
            SurfaceManager_RecordEvent(isErr ? "palette_probe_error" : "palette_probe_ok", "", Map("message", msg))
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

SurfaceDisposeProbe_HandleWebMessage(msg) {
    if !(msg is Map)
        return false
    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ != "palette_surface_dispose")
        return false
    cmdId := msg.Has("cmdId") ? String(msg["cmdId"]) : ""
    if (cmdId = "")
        cmdId := msg.Has("surfaceId") ? ("dev_surface_dispose_" . String(msg["surfaceId"])) : ""
    SurfaceDisposeProbe_TryExecute(cmdId)
    return true
}
