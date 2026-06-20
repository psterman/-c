; SearchCenterWebLlmBridge.ahk — webLlm* 消息桥（AI 工作台 / 遗留 SearchCenter 宿主）
#Requires AutoHotkey v2.0

SearchCenterWebLlmBridge_IsEmbedContext(context) {
    return (String(context) = "ai_workbench")
}

SearchCenterWebLlmBridge_HostGui(context) {
    if SearchCenterWebLlmBridge_IsEmbedContext(context) {
        if FuncExists("AiWb_GetGui")
            return AiWb_GetGui()
        return 0
    }
    global g_SCWV_Gui
    return g_SCWV_Gui
}

SearchCenterWebLlmBridge_PostJson(payload, context := "ai_workbench") {
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

ScWebLlm_PostJsonToHost(payload) {
    if FuncExists("AiWb_IsVisible") && AiWb_IsVisible() {
        SearchCenterWebLlmBridge_PostJson(payload, "ai_workbench")
        return
    }
    SearchCenterWebLlmBridge_PostJson(payload, "search_center")
}

SearchCenterWebLlmBridge_HandleMessage(msg, context := "ai_workbench") {
    if !(msg is Map)
        return false
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
            if msg.Has("columnLayout") && FuncExists("SearchCenterWebLlm_SetColumnLayout")
                SearchCenterWebLlm_SetColumnLayout(msg["columnLayout"])
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
            if (sid != "" && FuncExists("SearchCenterWebLlm_FocusSite"))
                SearchCenterWebLlm_FocusSite(sid)
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
            if !embedCtx || !msg.Has("columnLayout") || !FuncExists("SearchCenterWebLlm_SetColumnLayout")
                return false
            SearchCenterWebLlm_SetColumnLayout(msg["columnLayout"])
            return true
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
        case "webLlmBootstrap":
            if !embedCtx
                return false
            if msg.Has("selectedEngines") && FuncExists("_SCWV_ApplySelectedEnginesFromWeb")
                _SCWV_ApplySelectedEnginesFromWeb(msg["selectedEngines"])
            if FuncExists("SearchCenterWebLlm_PrepareForWebModeShow")
                SearchCenterWebLlm_PrepareForWebModeShow()
            else if FuncExists("SearchCenterWebLlm_MarkEmbedRequested")
                SearchCenterWebLlm_MarkEmbedRequested()
            rect := (msg.Has("rect") && (msg["rect"] is Map)) ? msg["rect"] : 0
            if (rect is Map) {
                if FuncExists("SearchCenterWebLlm_ApplyContentRectNow")
                    SearchCenterWebLlm_ApplyContentRectNow(rect)
                else if FuncExists("SearchCenterWebLlm_SetContentRect")
                    SearchCenterWebLlm_SetContentRect(rect)
            }
            if msg.Has("columnLayout") && FuncExists("SearchCenterWebLlm_SetColumnLayout")
                SearchCenterWebLlm_SetColumnLayout(msg["columnLayout"])
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
