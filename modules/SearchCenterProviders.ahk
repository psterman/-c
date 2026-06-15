#Requires AutoHotkey v2.0
; SearchCenterProviders.ahk — 搜索中心检索 provider 注册表与运行时分流路由
; 由 SearchCenterWebViewCore.ahk 末尾 #Include（依赖 SCWV 内 _SCWV_* 实现）

global g_SCProvider_Registry := ["cli", "history", "clipboard", "go", "ahk"]

SCProvider_Result(items := unset, hasMore := false, skipHostSort := false, source := "") {
    arr := []
    if IsSet(items) && (items is Array)
        arr := items
    return Map(
        "items", arr,
        "hasMore", hasMore ? true : false,
        "skipHostSort", skipHostSort ? true : false,
        "source", Trim(String(source))
    )
}

SCProvider_BuildCtx(keyword := unset, offset := 0, limit := 0, filterType := unset, engineMode := unset, uiMode := unset, triggerSource := unset, retryCount := 0) {
    global SearchCenterWebKeyword, SearchCenterCurrentLimit, SearchCenterFilterType
    global SearchCenterEngineMode, g_SCWV_UiMode, g_SCWV_PendingTriggerSource
    ctx := Map()
    if IsSet(keyword)
        ctx["keyword"] := Trim(String(keyword))
    else
        ctx["keyword"] := Trim(SearchCenterWebKeyword)
    ctx["offset"] := Integer(offset)
    lim := Integer(limit)
    if (lim <= 0)
        lim := SearchCenterCurrentLimit
    if (lim <= 0)
        lim := 30
    ctx["limit"] := lim
    if IsSet(filterType)
        ctx["filterType"] := Trim(String(filterType))
    else
        ctx["filterType"] := Trim(String(SearchCenterFilterType))
    if IsSet(engineMode)
        ctx["engineMode"] := Trim(String(engineMode))
    else
        ctx["engineMode"] := Trim(String(SearchCenterEngineMode))
    if IsSet(uiMode)
        ctx["uiMode"] := StrLower(Trim(String(uiMode)))
    else
        ctx["uiMode"] := StrLower(Trim(String(g_SCWV_UiMode)))
    if IsSet(triggerSource)
        ctx["triggerSource"] := Trim(String(triggerSource))
    else
        ctx["triggerSource"] := Trim(String(g_SCWV_PendingTriggerSource))
    ctx["retryCount"] := Integer(retryCount)
    return ctx
}

SCProvider_CtxKeyword(ctx) {
    return Trim(String(ctx.Get("keyword", "")))
}

SCProvider_CtxFilter(ctx) {
    return Trim(String(ctx.Get("filterType", "")))
}

SCProvider_CanServe(name, ctx) {
    global g_SCWV_ClipboardHomeLock, g_SCWV_UiMode
    n := StrLower(Trim(String(name)))
    kw := SCProvider_CtxKeyword(ctx)
    ft := SCProvider_CtxFilter(ctx)
    um := StrLower(Trim(String(ctx.Get("uiMode", g_SCWV_UiMode))))
    em := StrLower(Trim(String(ctx.Get("engineMode", "go"))))
    ts := Trim(String(ctx.Get("triggerSource", "")))

    if (n = "cli")
        return (um = "cli")
    if (n = "history") {
        if g_SCWV_ClipboardHomeLock
            return false
        if (kw != "")
            return false
        if (ft != "" && ft != "clipboard")
            return false
        if (um = "cli")
            return false
        if SCProvider_FuncExists("SCWV_IsWebSearchUIMode") && SCWV_IsWebSearchUIMode()
            return false
        return (ft = "" || ft = "clipboard") && ft != "clipboard"
    }
    if (n = "clipboard") {
        if (ft = "clipboard")
            return true
        if (ts = "clipboard_hotkey" && kw = "")
            return true
        return false
    }
    if (n = "go") {
        if (em != "go")
            return false
        if (um = "cli")
            return false
        if SCProvider_FuncExists("SCWV_IsWebSearchUIMode") && SCWV_IsWebSearchUIMode()
            return false
        if (kw != "")
            return true
        if SCProvider_FuncExists("_SCWV_IsLocalOnlyFilter") && _SCWV_IsLocalOnlyFilter(ft)
            return false
        return (ft != "")
    }
    if (n = "ahk") {
        if (em != "ahk")
            return false
        if (um = "cli")
            return false
        if SCProvider_FuncExists("SCWV_IsWebSearchUIMode") && SCWV_IsWebSearchUIMode()
            return false
        if (kw != "")
            return true
        if (ft = "fulltext")
            return false
        if SCProvider_FuncExists("_SCWV_IsLocalOnlyFilter") && _SCWV_IsLocalOnlyFilter(ft)
            return false
        return (ft != "")
    }
    return false
}

SCProvider_FuncExists(name) {
    return FuncExists(name)
}

; --- History provider（本地 JSON + 置顶剪贴板卡）---
SCProvider_History_Fetch(ctx) {
    if SCProvider_FuncExists("_SCWV_SetLoadingTier")
        _SCWV_SetLoadingTier("local")
    retry := Integer(ctx.Get("retryCount", 0))
    _SCWV_LoadSearchHistory(retry)
    return SCProvider_Result(, false, false, "history")
}

; --- Clipboard provider（空词本地 FTS5；非空词 Go 异步 + 本地降级）---
SCProvider_Clipboard_Fetch(ctx) {
    if SCProvider_FuncExists("_SCWV_SetLoadingTier")
        _SCWV_SetLoadingTier("local")
    _SCWV_RunClipboardTimelineSearch(
        SCProvider_CtxKeyword(ctx),
        Integer(ctx.Get("offset", 0)),
        Integer(ctx.Get("limit", 0))
    )
    return SCProvider_Result(, false, false, "clipboard")
}

; --- Go HTTP provider ---
SCProvider_GoSearch_Fetch(ctx) {
    global SearchCenterCurrentLimit
    if SCProvider_FuncExists("_SCWV_SetLoadingTier")
        _SCWV_SetLoadingTier("remote")
    kw := SCProvider_CtxKeyword(ctx)
    off := Integer(ctx.Get("offset", 0))
    if (off < 0)
        off := 0
    lim := Integer(ctx.Get("limit", 0))
    if (lim <= 0)
        lim := SearchCenterCurrentLimit
    ft := SCProvider_CtxFilter(ctx)
    if (kw = "") {
        gt := _SCWV_MapFilterToGoSearchType(ft)
        _SCWV_ExecuteGoSearchHttp(off, "", gt, lim)
        return SCProvider_Result(, false, false, "go")
    }
    if SCProvider_FuncExists("SearchCore_EnsureStatus")
        SetTimer((*) => SearchCore_EnsureStatus(false, "provider_go"), -1)
    _SCWV_ExecuteGoSearchHttp(off, kw, "", lim)
    return SCProvider_Result(, false, false, "go")
}

; --- Legacy AHK provider ---
SCProvider_AhkSearch_Fetch(ctx) {
    global SearchCenterFilterType
    kw := SCProvider_CtxKeyword(ctx)
    ft := SCProvider_CtxFilter(ctx)
    if (ft = "fulltext" && kw = "") {
        return SCProvider_GoSearch_Fetch(ctx)
    }
    if (kw != "") {
        _SCWV_RunAhkSearch(Integer(ctx.Get("offset", 0)))
        if SCProvider_FuncExists("SCWV_PushState")
            SCWV_PushState("state")
        return SCProvider_Result(, false, false, "ahk")
    }
    if (ft != "" && ft != "clipboard") {
        _SCWV_RunAhkSearch(0)
        if SCProvider_FuncExists("SCWV_PushState")
            SCWV_PushState("init")
    }
    return SCProvider_Result(, false, false, "ahk")
}

; --- CLI bridge（ttyd 注入，非结果行 provider）---
SCProvider_CliBridge_Fetch(ctx) {
    return SCProvider_Result(, false, false, "cli")
}

; --- Fulltext admin（状态/进度，非行检索）---
SCProvider_FullTextAdmin_MaybePost(withConfig := false) {
    if !SCProvider_FuncExists("_SCWV_ShouldPostFullTextStatus")
        return false
    if !_SCWV_ShouldPostFullTextStatus()
        return false
    if SCProvider_FuncExists("SearchCore_EnsureStatus")
        SetTimer((*) => SearchCore_EnsureStatus(false, "provider_fulltext"), -1)
    try _SCWV_PostFullTextStatus(withConfig ? true : false)
    catch {
        return false
    }
    return true
}

SCProvider_FetchByName(name, ctx) {
    switch StrLower(Trim(String(name))) {
        case "history":
            return SCProvider_History_Fetch(ctx)
        case "clipboard":
            return SCProvider_Clipboard_Fetch(ctx)
        case "go":
            return SCProvider_GoSearch_Fetch(ctx)
        case "ahk":
            return SCProvider_AhkSearch_Fetch(ctx)
        case "cli":
            return SCProvider_CliBridge_Fetch(ctx)
    }
    return SCProvider_Result(, false, false, String(name))
}

SCProvider_RouteSearch(ctx) {
    global g_SCProvider_Registry
    if !(ctx is Map)
        ctx := SCProvider_BuildCtx()
    for name in g_SCProvider_Registry {
        if SCProvider_CanServe(name, ctx) {
            try {
                if SCProvider_FuncExists("SCWV_Log")
                    SCWV_Log("provider_route", "name=" . String(name) . " filter=" . SCProvider_CtxFilter(ctx) . " kw=" . SubStr(SCProvider_CtxKeyword(ctx), 1, 40))
            } catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
            SCProvider_FetchByName(name, ctx)
            return String(name)
        }
    }
    return ""
}
