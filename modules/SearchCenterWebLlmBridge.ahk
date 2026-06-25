; SearchCenterWebLlmBridge.ahk — webLlm* 消息桥（AI 工作台 / 遗留 SearchCenter 宿主）
#Requires AutoHotkey v2.0

SearchCenterWebLlmBridge_IsEmbedContext(context) {
    ctx := String(context)
    return (ctx = "ai_workbench" || ctx = "unified_workbench")
}

SearchCenterWebLlmBridge_HostGui(context) {
    if (String(context) = "unified_workbench") {
        if FuncExists("UnifiedWb_GetGui")
            return UnifiedWb_GetGui()
        return 0
    }
    if SearchCenterWebLlmBridge_IsEmbedContext(context) {
        if FuncExists("AiWb_GetGui")
            return AiWb_GetGui()
        return 0
    }
    global g_SCWV_Gui
    return g_SCWV_Gui
}

SearchCenterWebLlmBridge_PostJson(payload, context := "ai_workbench") {
    if (String(context) = "unified_workbench") {
        if FuncExists("UnifiedWb_PostJson")
            try UnifiedWb_PostJson(payload)
        return
    }
    if SearchCenterWebLlmBridge_IsEmbedContext(context) {
        if FuncExists("AiWb_PostJson")
            try AiWb_PostJson(payload)
        return
    }
    if FuncExists("SCWV_PostJson")
        try SCWV_PostJson(payload)
}

SearchCenterWebLlmBridge_DismissEmbed(dispose := true) {
    SetTimer(_SCWV_DeferredWebEmbedSync, 0)
    if dispose {
        if FuncExists("SearchCenterWebLlm_TeardownEmbed")
            try SearchCenterWebLlm_TeardownEmbed()
    } else if FuncExists("SearchCenterWebLlm_Hide")
        try SearchCenterWebLlm_Hide()
}

SearchCenterWebLlmBridge_IsUnifiedContext(context) {
    return (String(context) = "unified_workbench")
}

SearchCenterWebLlmBridge_NormalizeSiteList(raw) {
    out := []
    if !(raw is Array)
        return out
    for item in raw {
        sid := FuncExists("ScWebLlm_NormalizeSiteId") ? ScWebLlm_NormalizeSiteId(String(item)) : Trim(String(item))
        if (sid = "")
            continue
        if FuncExists("ScWebLlm_IsSiteEnabled") && !ScWebLlm_IsSiteEnabled(sid)
            continue
        dup := false
        for existing in out {
            if (existing = sid) {
                dup := true
                break
            }
        }
        if !dup
            out.Push(sid)
    }
    if out.Length && FuncExists("ScWebLlm_NormalizeBroadcastSiteIds") {
        try {
            normalized := ScWebLlm_NormalizeBroadcastSiteIds(out)
            if (normalized is Array) && normalized.Length
                out := normalized
        } catch {
        }
    }
    return out
}

SearchCenterWebLlmBridge_ApplyUnifiedEmbedSites(rawSiteIds) {
    siteIds := SearchCenterWebLlmBridge_NormalizeSiteList(rawSiteIds)
    if !siteIds.Length
        return false
    global SearchCenterSelectedEngines, g_SCWebLlm_BroadcastSynced, g_SCWebLlm_LayoutSiteIds
    g_SCWebLlm_LayoutSiteIds := siteIds.Clone()
    SearchCenterSelectedEngines := siteIds.Clone()
    g_SCWebLlm_BroadcastSynced := true
    return true
}

SearchCenterWebLlmBridge_NormalizeColumnLayout(raw) {
    if (raw is Map)
        return raw
    if !(raw is Array)
        return 0
    cols := []
    for item in raw {
        if !(item is Map)
            continue
        sid := item.Has("id") ? String(item["id"]) : (item.Has("siteId") ? String(item["siteId"]) : "")
        sid := FuncExists("ScWebLlm_NormalizeSiteId") ? ScWebLlm_NormalizeSiteId(sid) : Trim(sid)
        if (sid = "")
            continue
        w := item.Has("width") ? Integer(item["width"]) : 520
        if (w < 160)
            w := 520
        cols.Push(Map("id", sid, "width", w))
    }
    if !cols.Length
        return 0
    vpW := cols[1]["width"]
    stripW := vpW
    for i, col in cols {
        if (i > 1)
            stripW += Integer(col["width"]) + 12
    }
    return Map(
        "scrollX", 0,
        "viewportWidth", vpW,
        "stripWidth", stripW,
        "columns", cols,
        "fillExtra", 0
    )
}

SearchCenterWebLlmBridge_ApplySelectedEngines(msg, context) {
    ctx := String(context)
    if SearchCenterWebLlmBridge_IsUnifiedContext(ctx) {
        if !msg.Has("selectedEngines")
            return false
        return SearchCenterWebLlmBridge_ApplyUnifiedEmbedSites(msg["selectedEngines"])
    }
    if msg.Has("selectedEngines") && FuncExists("_SCWV_ApplySelectedEnginesFromWeb")
        return !!_SCWV_ApplySelectedEnginesFromWeb(msg["selectedEngines"])
    return false
}

SearchCenterWebLlmBridge_ApplyColumnLayout(rawLayout, context) {
    if !FuncExists("SearchCenterWebLlm_SetColumnLayout")
        return false
    layout := rawLayout
    if SearchCenterWebLlmBridge_IsUnifiedContext(context)
        layout := SearchCenterWebLlmBridge_NormalizeColumnLayout(rawLayout)
    if !(layout is Map)
        return false
    try SearchCenterWebLlm_SetColumnLayout(layout)
    catch as _e {
        NmerCatch(A_ThisFunc, _e)
        return false
    }
    return true
}

ScWebLlm_PostJsonToHost(payload) {
    if FuncExists("AiWb_IsVisible") && AiWb_IsVisible() {
        SearchCenterWebLlmBridge_PostJson(payload, "ai_workbench")
        return
    }
    if FuncExists("UnifiedWb_IsVisible") && UnifiedWb_IsVisible() {
        SearchCenterWebLlmBridge_PostJson(payload, "unified_workbench")
        return
    }
    SearchCenterWebLlmBridge_PostJson(payload, "search_center")
}

SearchCenterWebLlmBridge_HandleMessage(msg, context := "ai_workbench") {
    if !(msg is Map)
        return false
    if FuncExists("Nmer_IsAppShuttingDown") && Nmer_IsAppShuttingDown() {
        typEarly := msg.Has("type") ? String(msg["type"]) : ""
        if (typEarly != "webLlmDismiss")
            return false
    }
    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ = "")
        return false
    embedCtx := SearchCenterWebLlmBridge_IsEmbedContext(context)
    hostGui := SearchCenterWebLlmBridge_HostGui(context)

    switch typ {
        case "webLlmDismiss":
            dispose := true
            if msg.Has("dispose")
                dispose := !!msg["dispose"]
            SearchCenterWebLlmBridge_DismissEmbed(dispose)
            return true
        case "webLlmContentRect":
            if !embedCtx
                return false
            if SearchCenterWebLlmBridge_IsUnifiedContext(context) && FuncExists("ScWebLlm_ClearUnifiedMultiColumnRects") {
                try ScWebLlm_ClearUnifiedMultiColumnRects()
                catch as _e {
                    NmerCatch(A_ThisFunc, _e)
                }
            }
            if FuncExists("SearchCenterWebLlm_MarkEmbedRequested")
                SearchCenterWebLlm_MarkEmbedRequested()
            rect := (msg.Has("rect") && (msg["rect"] is Map)) ? msg["rect"] : msg
            if !(rect is Map)
                return true
            rw := Integer(rect.Get("width", 0))
            rh := Integer(rect.Get("height", 0))
            if (rw < 80 || rh < 40)
                return true
            if FuncExists("SearchCenterWebLlm_SetContentRect")
                SearchCenterWebLlm_SetContentRect(rect)
            if msg.Has("selectedEngines")
                SearchCenterWebLlmBridge_ApplySelectedEngines(msg, context)
            if msg.Has("columnLayout")
                SearchCenterWebLlmBridge_ApplyColumnLayout(msg["columnLayout"], context)
            else if hostGui && FuncExists("SearchCenterWebLlm_EnsureEmbedSitesLoaded") {
                try SearchCenterWebLlm_EnsureEmbedSitesLoaded(true, hostGui.Hwnd)
                catch as _e {
                    NmerCatch(A_ThisFunc, _e)
                }
            }
            return true
        case "webLlmSelectSite":
            if !embedCtx || !msg.Has("siteId")
                return false
            sid := Trim(String(msg["siteId"]))
            if (sid = "")
                return true
            if FuncExists("SearchCenterWebLlm_FocusSite")
                SearchCenterWebLlm_FocusSite(sid)
            else if FuncExists("SearchCenterWebLlm_SelectSite")
                SearchCenterWebLlm_SelectSite(sid)
            return true
        case "webLlmFocusSite":
            if !embedCtx || !msg.Has("siteId")
                return false
            sid := Trim(String(msg["siteId"]))
            preserveLayout := msg.Has("preserveLayout") && !!msg["preserveLayout"]
            if (sid != "") {
                sidNorm := FuncExists("ScWebLlm_NormalizeSiteId") ? ScWebLlm_NormalizeSiteId(sid) : sid
                if SearchCenterWebLlmBridge_IsUnifiedContext(context) {
                    global g_SCWebLlm_UnifiedMultiRectActive, g_SCWebLlm_ActiveSiteId
                    if preserveLayout || g_SCWebLlm_UnifiedMultiRectActive {
                        g_SCWebLlm_ActiveSiteId := sidNorm
                        if g_SCWebLlm_UnifiedMultiRectActive && FuncExists("ScWebLlm_EnsureUnifiedMultiHostStack") {
                            try ScWebLlm_EnsureUnifiedMultiHostStack(sidNorm)
                            catch as _e {
                                NmerCatch(A_ThisFunc, _e)
                            }
                        } else if FuncExists("ScWebLlm_EnsureEmbedHostStack") {
                            try ScWebLlm_EnsureEmbedHostStack(sidNorm)
                            catch as _e {
                                NmerCatch(A_ThisFunc, _e)
                            }
                        }
                        if FuncExists("SearchCenterWebLlm_FocusSiteInput")
                            try SearchCenterWebLlm_FocusSiteInput(sidNorm)
                            catch as _e {
                                NmerCatch(A_ThisFunc, _e)
                            }
                        hostGui := SearchCenterWebLlmBridge_HostGui(context)
                        ph := 0
                        if hostGui {
                            try ph := hostGui.Hwnd
                            catch {
                            }
                        }
                        if FuncExists("SearchCenterWebLlm_EnsureMissingSites")
                            try SearchCenterWebLlm_EnsureMissingSites(false, ph)
                            catch as _e {
                                NmerCatch(A_ThisFunc, _e)
                            }
                        if FuncExists("SearchCenterWebLlm_ApplyBounds") && ph
                            try SearchCenterWebLlm_ApplyBounds(ph)
                            catch as _e {
                                NmerCatch(A_ThisFunc, _e)
                            }
                        if FuncExists("ScWebLlm_ApplyActiveSiteChrome")
                            try ScWebLlm_ApplyActiveSiteChrome(sidNorm, ph)
                            catch as _e {
                                NmerCatch(A_ThisFunc, _e)
                            }
                        return true
                    }
                    SearchCenterWebLlmBridge_ApplyUnifiedEmbedSites([sidNorm])
                }
                if FuncExists("SearchCenterWebLlm_FocusSite")
                    SearchCenterWebLlm_FocusSite(sidNorm)
            }
            return true
        case "webLlmNavigate":
            if !embedCtx || !msg.Has("url") || !FuncExists("SearchCenterWebLlm_NavigateUrl")
                return false
            sid := msg.Has("siteId") ? Trim(String(msg["siteId"])) : ""
            try SearchCenterWebLlm_NavigateUrl(msg["url"], sid)
            catch as _e {
                NmerCatch(A_ThisFunc, _e)
            }
            return true
        case "webLlmNav":
            if !embedCtx || !msg.Has("action") || !FuncExists("SearchCenterWebLlm_HandleNav")
                return false
            SearchCenterWebLlm_HandleNav(msg["action"])
            return true
        case "webLlmColumnLayout":
            if !embedCtx || !msg.Has("columnLayout")
                return false
            return SearchCenterWebLlmBridge_ApplyColumnLayout(msg["columnLayout"], context)
        case "webLlmScroll":
            if !embedCtx
                return false
            if msg.Has("siteId") && FuncExists("ScWebLlm_ScrollEmbedToSite") {
                try ScWebLlm_ScrollEmbedToSite(String(msg["siteId"]))
                catch as _e {
                    NmerCatch(A_ThisFunc, _e)
                }
            } else if msg.Has("adjacent") && FuncExists("ScWebLlm_FocusAdjacentEmbedSite") {
                try ScWebLlm_FocusAdjacentEmbedSite(Integer(msg["adjacent"]))
                catch as _e {
                    NmerCatch(A_ThisFunc, _e)
                }
            } else if msg.Has("scrollX") && FuncExists("ScWebLlm_ApplyEmbedScrollCss") {
                vp := msg.Has("viewportWidth") ? Integer(msg["viewportWidth"]) : 0
                strip := msg.Has("stripWidth") ? Integer(msg["stripWidth"]) : 0
                finalize := msg.Has("finalize") ? !!msg["finalize"] : false
                try ScWebLlm_ApplyEmbedScrollCss(Integer(msg["scrollX"]), vp, strip, finalize)
                catch as _e {
                    NmerCatch(A_ThisFunc, _e)
                }
            } else if msg.Has("deltaCss") && FuncExists("ScWebLlm_ScrollEmbedByCssDelta") {
                try ScWebLlm_ScrollEmbedByCssDelta(Integer(msg["deltaCss"]))
                catch as _e {
                    NmerCatch(A_ThisFunc, _e)
                }
            } else if msg.Has("delta") && FuncExists("ScWebLlm_ScrollEmbedByColumns") {
                try ScWebLlm_ScrollEmbedByColumns(Integer(msg["delta"]))
                catch as _e {
                    NmerCatch(A_ThisFunc, _e)
                }
            }
            return true
        case "webLlmLayoutLive":
            if !embedCtx || !SearchCenterWebLlmBridge_IsUnifiedContext(context)
                return false
            if FuncExists("ScWebLlm_IsUnifiedScEmbedLayout") && ScWebLlm_IsUnifiedScEmbedLayout()
                return true
            if !msg.Has("aiColumns")
                return false
            maxActive := msg.Has("maxActiveAiEmbeds") ? Integer(msg["maxActiveAiEmbeds"]) : 0
            focusSid := msg.Has("focusSiteId") ? Trim(String(msg["focusSiteId"])) : ""
            embedVp := (msg.Has("embedViewport") && (msg["embedViewport"] is Map)) ? msg["embedViewport"] : 0
            if FuncExists("SearchCenterWebLlm_ApplyUnifiedMultiColumnFromWeb") {
                try SearchCenterWebLlm_ApplyUnifiedMultiColumnFromWeb(msg["aiColumns"], maxActive, focusSid, embedVp, true)
                catch as _e {
                    NmerCatch(A_ThisFunc, _e)
                }
            }
            return true
        case "webLlmLayoutPause":
            if !embedCtx || !SearchCenterWebLlmBridge_IsUnifiedContext(context)
                return false
            paused := msg.Has("paused") ? !!msg["paused"] : true
            if FuncExists("SearchCenterWebLlm_SetUnifiedEmbedLayoutPaused") {
                try SearchCenterWebLlm_SetUnifiedEmbedLayoutPaused(paused)
                catch as _e {
                    NmerCatch(A_ThisFunc, _e)
                }
            }
            return true
        case "webLlmBootstrap":
            if !embedCtx
                return false
            if SearchCenterWebLlmBridge_IsUnifiedContext(context) && msg.Has("rect") && FuncExists("ScWebLlm_ClearUnifiedMultiColumnRects") {
                try ScWebLlm_ClearUnifiedMultiColumnRects()
                catch as _e {
                    NmerCatch(A_ThisFunc, _e)
                }
            }
            if SearchCenterWebLlmBridge_IsUnifiedContext(context) && msg.Has("aiColumns") {
                if FuncExists("_UnifiedWb_HandleWebLlmBootstrap") {
                    try return !!_UnifiedWb_HandleWebLlmBootstrap(msg)
                    catch as _e {
                        NmerCatch(A_ThisFunc, _e)
                        return false
                    }
                }
                return false
            }
            SearchCenterWebLlmBridge_ApplySelectedEngines(msg, context)
            if msg.Has("columnLayout")
                SearchCenterWebLlmBridge_ApplyColumnLayout(msg["columnLayout"], context)
            rect := (msg.Has("rect") && (msg["rect"] is Map)) ? msg["rect"] : 0
            if (rect is Map) {
                if FuncExists("SearchCenterWebLlm_ApplyContentRectNow")
                    SearchCenterWebLlm_ApplyContentRectNow(rect)
                else if FuncExists("SearchCenterWebLlm_SetContentRect")
                    SearchCenterWebLlm_SetContentRect(rect)
            }
            if FuncExists("SearchCenterWebLlm_PrepareForWebModeShow")
                SearchCenterWebLlm_PrepareForWebModeShow(false)
            else if FuncExists("SearchCenterWebLlm_MarkEmbedRequested")
                SearchCenterWebLlm_MarkEmbedRequested()
            if hostGui && FuncExists("SearchCenterWebLlm_EnsureEmbedSitesLoaded") {
                global g_SCWebLlm_EmbedBootstrapped
                navHome := !g_SCWebLlm_EmbedBootstrapped
                try SearchCenterWebLlm_EnsureEmbedSitesLoaded(navHome, hostGui.Hwnd)
                catch as _e {
                    NmerCatch(A_ThisFunc, _e)
                }
            }
            return true
        case "webEmbedDebugRequest":
            if !embedCtx
                return false
            client := (msg.Has("client") && (msg["client"] is Map)) ? msg["client"] : Map()
            snap := Map("type", "webEmbedDebugResult", "ok", true)
            if FuncExists("SearchCenterWebLlm_BuildDebugSnapshot") {
                try snap["snapshot"] := SearchCenterWebLlm_BuildDebugSnapshot(client)
                catch as e {
                    snap["ok"] := false
                    snap["error"] := e.Message
                }
            } else {
                snap["ok"] := false
                snap["error"] := "SearchCenterWebLlm_BuildDebugSnapshot missing"
            }
            SearchCenterWebLlmBridge_PostJson(snap, context)
            return true
        default:
            return false
    }
}
