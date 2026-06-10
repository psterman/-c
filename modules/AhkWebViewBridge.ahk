; ======================================================================================================================
; AhkWebViewBridge.ahk — 统一宿主对象 ahk，注入各 WebView2 实例
; 依赖：lib\WebView2.ahk
; ======================================================================================================================

#Requires AutoHotkey v2.0

global g_AhkInterface := AhkInterface()

class AhkInterface {
    __New() {
        this._httpReqSeq := 0
    }
    /**
     * 连通性探测（供前端验证 hostObjects）。
     */
    Ping(_hint := "") => "ok"

    /** 打开诊断窗「动作托管」标签（原独立探面板） */
    OpenCommandPaletteAgentDebug() {
        try {
            if FuncExists("CommandPalette_ShowSearchDebug")
                CommandPalette_ShowSearchDebug(true, "agent")
            else if FuncExists("CommandPalette_HandleAgentDebug")
                CommandPalette_HandleAgentDebug()
            else
                return "err:not_loaded"
            global g_CmdPalDbg_Gui
            if IsObject(g_CmdPalDbg_Gui) && g_CmdPalDbg_Gui.Hwnd
                return "ok"
            return "err:gui_not_shown"
        } catch as e {
            return "err:" . e.Message
        }
    }

    /** 命令面板「诊」按钮：打开诊断窗（默认本地搜索标签） */
    OpenCommandPaletteSearchDebug() {
        try {
            if FuncExists("CommandPalette_ShowSearchDebug")
                CommandPalette_ShowSearchDebug(true, "search")
            else if FuncExists("CommandPalette_HandleSearchDebug")
                CommandPalette_HandleSearchDebug()
            else
                return "err:not_loaded"
            return "ok"
        } catch as e {
            return "err:" . e.Message
        }
    }

    /** 动作 Tab：同步提交（推荐 JSON 字符串；兼容旧版多参数，避免 WebView2 参数错位） */
    CommandPaletteAgentSubmitQuick(arg1, provider := "openclaw", kind := "new", cardId := "") {
        try {
            if !_AhkBridge_AgentSubmitReady()
                return "err:not_loaded"
            msg := Map("type", "palette_agent_submit")
            raw := Trim(String(arg1))
            if (SubStr(raw, 1, 1) = "{") {
                root := Jxon_Load(raw)
                if (root is Map) {
                    for k, v in root
                        msg[String(k)] := v
                }
            } else {
                msg["text"] := raw
                msg["provider"] := Trim(String(provider)) != "" ? String(provider) : "openclaw"
                msg["kind"] := Trim(String(kind)) != "" ? String(kind) : "new"
                msg["cardId"] := Trim(String(cardId))
            }
            if !msg.Has("text") && msg.Has("query")
                msg["text"] := String(msg["query"])
            provRaw := Trim(String(msg.Has("provider") ? msg["provider"] : ""))
            if (provRaw = "" || provRaw = "new" || provRaw = "append" || provRaw = "correction")
                msg["provider"] := "openclaw"
            else
                msg["provider"] := provRaw
            if !msg.Has("kind") || Trim(String(msg["kind"])) = ""
                msg["kind"] := "new"
            if !msg.Has("text") && !msg.Has("query")
                return "err:bad_json"
            if Trim(String(msg.Has("text") ? msg["text"] : "")) = ""
                return "err:empty_text"
            _AhkBridge_AgentWireLog("bridge_quick", "text=" . SubStr(String(msg["text"]), 1, 60)
                . " prov=" . String(msg["provider"]) . " kind=" . String(msg["kind"]))
            ret := _AhkBridge_AgentSubmit(msg)
            if !(ret is Map) || !ret.Get("ok", false) {
                errCode := (ret is Map) ? String(ret.Get("error", "")) : ""
                if (errCode = "provider_keyword")
                    return "err:provider_keyword"
                if (errCode = "empty_text")
                    return "err:empty_text"
                return "err:submit_failed"
            }
            cid := String(ret.Get("cardId", ""))
            rid := String(ret.Get("reqId", ""))
            prov := String(ret.Get("provider", msg["provider"]))
            if (cid = "")
                return "err:no_card_id"
            _AhkBridge_AgentDebugTrace("bridge", "submit_ok", "card=" . cid . " req=" . rid . " prov=" . prov)
            try CommandPalette_AgentDebugNoteSubmit(cid, rid, prov, "bridge_quick")
            catch {
            }
            return "ok|" . cid . "|" . rid . "|" . prov
        } catch as e {
            return "err:" . e.Message
        }
    }

    /** 动作 Tab：同步写诊断事件（绕过 postMessage） */
    CommandPaletteAgentDebugLog(layer := "palette", event := "", detail := "", level := "info") {
        try {
            if !FuncExists("CommandPalette_AgentDebugTrace")
                return "err:not_loaded"
            safeDetail := ""
            try safeDetail := SubStr(String(detail), 1, 800)
            _AhkBridge_AgentDebugTrace(String(layer), String(event), safeDetail, String(level))
            return "ok"
        } catch as e {
            return "err:" . e.Message
        }
    }

    /** 动作 Tab：探测编排器是否已登记（供前端 probe） */
    PingAgentSubmit(_hint := "") {
        return _AhkBridge_AgentSubmitReady() ? "ok|submit" : "err:not_loaded"
    }

    /** 动作 Tab：提交托管任务（JSON 字符串，与 palette_agent_submit 同结构） */
    CommandPaletteAgentSubmit(jsonStr) {
        try {
            if !_AhkBridge_AgentSubmitReady()
                return "err:not_loaded"
            root := Jxon_Load(String(jsonStr))
            if !(root is Map)
                return "err:bad_json"
            ret := _AhkBridge_AgentSubmit(root)
            if !(ret is Map) || !ret.Get("ok", false)
                return "err:submit_failed"
            cid := String(ret.Get("cardId", ""))
            rid := String(ret.Get("reqId", ""))
            prov := String(ret.Get("provider", "openclaw"))
            if (cid = "")
                return "err:no_card_id"
            if FuncExists("CommandPalette_AgentDebugNoteSubmit")
                try CommandPalette_AgentDebugNoteSubmit(cid, rid, prov, "bridge")
                catch {
                }
            _AhkBridge_AgentDebugTrace("bridge", "submit_ok", "card=" . cid . " req=" . rid . " prov=" . prov)
            return "ok|" . cid . "|" . rid . "|" . prov
        } catch as e {
            return "err:" . e.Message
        }
    }

    /** 动作 Tab：同步拉取全部任务卡 JSON 数组（不依赖 postMessage 顺序） */
    PullCommandPaletteAgentCards(_hint := "") {
        try {
            if FuncExists("CommandPalette_AgentPullCardsJson")
                return SubStr(String(CommandPalette_AgentPullCardsJson()), 1, 200000)
        } catch as e {
            try return "[]"
        }
        return "[]"
    }

    /** 诊断窗「动作托管」：由页面主动拉取快照+事件（不依赖 postMessage） */
    PullCommandPaletteAgentDebug(_hint := "") {
        try {
            out := _AhkBridge_PullAgentDebugJson()
            if (out = "")
                out := _AhkBridge_PullAgentDebugFallback()
            return out != "" ? out : '{"snapshot":{"type":"cp_agent_debug_snapshot","tick":0,"cards":[],"routes":[],"lastSubmit":{},"health":{}},"events":[]}'
        } catch as e {
            return '{"error":"' . StrReplace(String(e.Message), '"', "'") . '"}'
        }
    }

    /** 动作托管诊断探针：ok|cards|events */
    ProbeCommandPaletteAgentDebug(_hint := "") {
        try {
            raw := _AhkBridge_PullAgentDebugJson()
            if (raw = "")
                raw := _AhkBridge_PullAgentDebugFallback()
            if (raw = "")
                return "err:empty"
            pack := Jxon_Load(raw)
            if !(pack is Map)
                return "err:bad_json"
            cards := 0
            events := 0
            if pack.Has("snapshot") && (pack["snapshot"] is Map) && pack["snapshot"].Has("cards") {
                c := pack["snapshot"]["cards"]
                if (c is Array)
                    cards := c.Length
            }
            if pack.Has("events") && (pack["events"] is Array)
                events := pack["events"].Length
            return "ok|" . cards . "|" . events
        } catch as e {
            return "err:" . e.Message
        }
    }

    /** 诊断窗「本地搜索」：拉取运行时快照 */
    PullCommandPaletteSearchDebugSnapshot(_hint := "") {
        try {
            if !FuncExists("CommandPaletteSearchDebug_PullSearchDebugJson")
                return ""
            return CommandPaletteSearchDebug_PullSearchDebugJson()
        } catch as e {
            return '{"error":"' . StrReplace(String(e.Message), '"', "'") . '"}'
        }
    }

    /** 诊断面板「全部探测」 */
    RunCommandPaletteSearchDebugProbes(keyword := "1") {
        try {
            if !FuncExists("CommandPaletteSearchDebug_RunAllProbes")
                return "err:not_loaded"
            CommandPaletteSearchDebug_RunAllProbes(String(keyword))
            return "ok"
        } catch as e {
            return "err:" . e.Message
        }
    }

    /** 手机浏览器顶栏菜单：撑满 overlay 以便底部 Sheet 完整显示。open: 1/0 */
    SetMobileChromeSheet(open := 0) {
        try {
            if FuncExists("NiumaMobileBrowser_SetChromeSheetOpen")
                NiumaMobileBrowser_SetChromeSheetOpen(!!Integer(open))
        } catch {
        }
        return "ok"
    }

    /** 顶栏 WebView → 宿主：同步派发 postMessage（后退/刷新/导航/菜单等） */
    MobileChromePost(jsonStr) {
        try {
            if !FuncExists("NiumaMobileBrowser_DispatchChromeBrowserMessage")
                return "err"
            root := Jxon_Load(String(jsonStr))
            if !(root is Map) || !root.Has("type")
                return "err"
            typ := String(root["type"])
            if (typ = "niuma_browser_sync_state") {
                if FuncExists("NiumaMobileBrowser_PushChromeState")
                    NiumaMobileBrowser_PushChromeState()
                return "ok"
            }
            NiumaMobileBrowser_DispatchChromeBrowserMessage(root)
            return "ok"
        } catch {
            return "err"
        }
    }

    /** 内容区 WebView 右键：同步派发 contextmenu 目标信息 */
    MobileBrowserContextMenu(jsonStr) {
        try {
            if !FuncExists("NiumaMobileBrowser_HandleContextMenuWebMessage")
                return "err"
            root := Jxon_Load(String(jsonStr))
            if !(root is Map)
                return "err"
            if !root.Has("type")
                root["type"] := "niuma_browser_context_menu"
            NiumaMobileBrowser_HandleContextMenuWebMessage(root)
            return "ok"
        } catch {
            return "err"
        }
    }

    /**
     * 返回纯文本剪贴板内容。
     */
    GetClipboardText() {
        try return String(A_Clipboard)
        catch {
            return ""
        }
    }

    /**
     * 写入剪贴板文本，成功返回 true。
     */
    SetClipboardText(text) {
        try {
            A_Clipboard := String(text)
            return true
        } catch {
            return false
        }
    }

    /**
     * 同步 HTTP 请求；headersJson 为 JSON 对象字符串，如 {"Authorization":"Bearer x"}；返回 JSON 字符串 {ok,status,body,error}。
     */
    HttpRequest(method, url, headersJson := "", body := "") {
        payload := Map(
            "reqId", 0,
            "requestId", "",
            "ok", false,
            "status", 0,
            "body", "",
            "error", "sync_http_disabled"
        )
        out := Map("type", "event", "name", "ahk_http_result", "payload", payload)
        out["legacy"] := AhkInterface._BuildLegacyHttpResult(payload)
        return Jxon_Dump(out)
    }

    HttpRequestAsync(method, url, headersJson := "", body := "", requestId := "") {
        m := StrUpper(Trim(String(method)))
        u := Trim(String(url))
        out := Map("ok", false, "queued", false, "reqId", 0, "requestId", String(requestId), "error", "")
        if (u = "") {
            out["error"] := "empty url"
            return Jxon_Dump(out)
        }
        headersRet := this._ParseHeadersJson(headersJson)
        if !headersRet["ok"] {
            out["error"] := headersRet["error"]
            return Jxon_Dump(out)
        }
        headersMap := headersRet["headers"]
        this._httpReqSeq += 1
        rid := this._httpReqSeq
        payloadId := String(requestId)
        HttpJsonAsync(m = "" ? "GET" : m, u, body, (ret) => (
            this._EmitHttpAsyncResult(rid, payloadId, ret)
        ), Map("tag", "ahk_bridge_http", "reqId", rid, "timeoutMs", 5000, "receiveTimeoutMs", 5000, "headers", headersMap))
        out["ok"] := true
        out["queued"] := true
        out["reqId"] := rid
        return Jxon_Dump(out)
    }

    _EmitHttpAsyncResult(reqId, requestId, ret) {
        payload := Map(
            "reqId", reqId,
            "requestId", requestId,
            "ok", (ret is Map) ? ret["ok"] : false,
            "status", (ret is Map) ? ret["status"] : 0,
            "body", (ret is Map) ? ret["text"] : "",
            "error", (ret is Map) ? ret["error"] : "invalid_ret"
        )
        evt := Map(
            "type", "event",
            "name", "ahk_http_result",
            "payload", payload
        )
        evt["legacy"] := AhkInterface._BuildLegacyHttpResult(payload)
        try CoreAsyncHttp_Log("ahk_bridge_http_event_legacy_compat", "name=ahk_http_result req_id=" . reqId . " request_id=" . requestId)
        try {
            if FuncExists("WebView_BroadcastPayload")
                Func("WebView_BroadcastPayload").Call(evt)
            else if FuncExists("WebView_QueuePayload")
                WebView_QueuePayload(0, evt)
        }
    }

    _ParseHeadersJson(headersJson) {
        raw := Trim(String(headersJson))
        if (raw = "")
            return Map("ok", true, "headers", Map(), "error", "")
        root := 0
        try root := Jxon_Load(raw)
        catch as e {
            return Map("ok", false, "headers", Map(), "error", "invalid_headers_json: " . e.Message)
        }
        if !(root is Map)
            return Map("ok", false, "headers", Map(), "error", "invalid_headers_json: expected object")
        normalized := Map()
        for k, v in root {
            hk := Trim(String(k))
            if (hk = "")
                continue
            normalized[hk] := String(v)
        }
        return Map("ok", true, "headers", normalized, "error", "")
    }

    /**
     * 在脚本目录下读取 UTF-8 文本；rel 必须为相对路径，不得含 .. 。
     */
    FileReadUtf8(relPath) {
        p := AhkInterface._ResolveUnderScriptDir(relPath)
        if p = ""
            return ""
        try return FileRead(p, "UTF-8")
        catch {
            return ""
        }
    }

    /**
     * 在脚本目录下追加 UTF-8 文本（无则创建）；返回 true/false。
     */
    FileAppendUtf8(relPath, content) {
        p := AhkInterface._ResolveUnderScriptDir(relPath)
        if p = ""
            return false
        try {
            FileAppend(String(content), p, "UTF-8")
            return true
        } catch {
            return false
        }
    }

    static _ScriptBase() {
        try {
            global MainScriptDir
            if IsSet(MainScriptDir) && MainScriptDir != ""
                return MainScriptDir
        } catch {
        }
        return A_ScriptDir
    }

    static _ResolveUnderScriptDir(relPath) {
        r := Trim(String(relPath), " `t`r`n")
        r := StrReplace(r, "/", "\")
        if (r = "" || InStr(r, ".."))
            return ""
        base := AhkInterface._ScriptBase()
        if (base = "")
            return ""
        p := base . "\" . r
        ; 规范化后须仍在 base 下
        if (StrLen(p) < StrLen(base) + 1)
            return ""
        if (StrLower(SubStr(p, 1, StrLen(base))) != StrLower(base))
            return ""
        return p
    }

    static _BuildLegacyHttpResult(payload) {
        if !(payload is Map)
            payload := Map("ok", false, "status", 0, "body", "", "error", "invalid_payload", "reqId", 0, "requestId", "")
        return Map(
            "type", "ahk_http_result",
            "reqId", payload.Has("reqId") ? payload["reqId"] : 0,
            "requestId", payload.Has("requestId") ? payload["requestId"] : "",
            "ok", payload.Has("ok") ? payload["ok"] : false,
            "status", payload.Has("status") ? payload["status"] : 0,
            "body", payload.Has("body") ? payload["body"] : "",
            "error", payload.Has("error") ? payload["error"] : ""
        )
    }
    /**
     * 返回最新浏览器快照 JSON（供 Chat 通过 HostObject 同步拉取，绕过 Native→JS 断连）。
     */
    GetBrowserSnapshot() {
        try {
            global g_NiumaMobile_LastSnapshotJson
            static _callCount := 0
            _callCount += 1
            s := String(g_NiumaMobile_LastSnapshotJson)
            if (s != "" && StrLen(s) >= 40) {
                reqLogged := ""
                if RegExMatch(s, '"reqId"\s*:\s*"([^"]*)"', &mR)
                    reqLogged := mR[1]
                if (Mod(_callCount, 3) = 1) {
                    head := SubStr(s, 1, 160)
                    tail := SubStr(s, Max(1, StrLen(s) - 120))
                    ; 避免日志被换行打断
                    head := StrReplace(StrReplace(StrReplace(head, "`r", " "), "`n", " "), "`t", " ")
                    tail := StrReplace(StrReplace(StrReplace(tail, "`r", " "), "`n", " "), "`t", " ")
                    FileAppend("[" . A_Now . "] [HOSTOBJ] GetBrowserSnapshot #" . _callCount . " OK len=" . StrLen(s) . " reqId=" . reqLogged . " head=" . head . " tail=" . tail . "`r`n", Nmer_DebugPath("niuma_mobile_snapshot_debug.log"), "UTF-8")
                }
                return s
            }
            FileAppend("[" . A_Now . "] [HOSTOBJ] GetBrowserSnapshot #" . _callCount . " EMPTY`r`n", Nmer_DebugPath("niuma_mobile_snapshot_debug.log"), "UTF-8")
            return '{"type":"host_browser_snapshot","reqId":"","count":0,"arrLen":0,"url":"","error":"no_cache","truncated":false,"totalCandidates":0,"snapshot":[]}'
        } catch as e {
            FileAppend("[" . A_Now . "] [HOSTOBJ] GetBrowserSnapshot ERROR: " . e.Message . "`r`n", Nmer_DebugPath("niuma_mobile_snapshot_debug.log"), "UTF-8")
            return '{"type":"host_browser_snapshot","reqId":"","count":0,"arrLen":0,"url":"","error":"bridge_error","truncated":false,"totalCandidates":0,"snapshot":[]}'
        }
    }

    /** 与 GetBrowserSnapshot 相同，供前端 pull 自愈通道按行业命名调用。 */
    GetLatestSnapshotCache() {
        return this.GetBrowserSnapshot()
    }
}

_AhkBridge_AgentSubmitReady() {
    global g_CmdPal_AgentSubmitDispatch
    if IsSet(g_CmdPal_AgentSubmitDispatch) && g_CmdPal_AgentSubmitDispatch
        return true
    try {
        ref := CommandPalette_HandleAgentSubmit
        return !!ref
    } catch {
        return false
    }
}

_AhkBridge_AgentSubmit(msg) {
    global g_CmdPal_AgentSubmitDispatch
    if IsSet(g_CmdPal_AgentSubmitDispatch) && g_CmdPal_AgentSubmitDispatch
        return g_CmdPal_AgentSubmitDispatch(msg)
    return CommandPalette_HandleAgentSubmit(msg)
}

_AhkBridge_AgentDebugTrace(layer, event, detail, level := "info") {
    global g_CmdPal_AgentDebugTraceDispatch
    if IsSet(g_CmdPal_AgentDebugTraceDispatch) && g_CmdPal_AgentDebugTraceDispatch
        g_CmdPal_AgentDebugTraceDispatch(layer, event, detail, level)
    else
        CommandPalette_AgentDebugTrace(layer, event, detail, level)
}

_AhkBridge_AgentWireLog(event, detail := "") {
    global g_CmdPal_AgentWireLogDispatch
    try {
        if IsSet(g_CmdPal_AgentWireLogDispatch) && g_CmdPal_AgentWireLogDispatch
            g_CmdPal_AgentWireLogDispatch(event, detail)
        else
            CommandPalette_AgentWireLog(event, detail)
    } catch {
    }
}

_AhkBridge_PullAgentDebugJson() {
    global g_CmdPal_AgentPullDebugDispatch
    if IsSet(g_CmdPal_AgentPullDebugDispatch) && g_CmdPal_AgentPullDebugDispatch
        return g_CmdPal_AgentPullDebugDispatch()
    try {
        return CommandPaletteSearchDebug_PullAgentDebugJson()
    } catch {
        return ""
    }
}

_AhkBridge_PullAgentDebugFallback() {
    try {
        snap := CommandPalette_AgentDebug_BuildSnapshot()
        events := []
        global g_AgentDbg_Events
        if (g_AgentDbg_Events is Array) {
            for _, row in g_AgentDbg_Events
                if (row is Map)
                    events.Push(row)
        }
        return Jxon_Dump(Map("snapshot", snap, "events", events))
    } catch {
        return ""
    }
}

WebView2_RegisterHostBridge(wv2) {
    global g_AhkInterface
    if !wv2 || !IsObject(g_AhkInterface)
        return
    try {
        s := wv2.Settings
        s.AreHostObjectsAllowed := true
    } catch as e {
        try OutputDebug("[AhkBridge] AreHostObjectsAllowed: " . e.Message)
    }
    try wv2.AddHostObjectToScript("ahk", g_AhkInterface)
    catch as e {
        try OutputDebug("[AhkBridge] AddHostObjectToScript: " . e.Message)
    }
    try wv2.InjectAhkComponent()
    catch as e {
        try OutputDebug("[AhkBridge] InjectAhkComponent: " . e.Message)
    }
}
