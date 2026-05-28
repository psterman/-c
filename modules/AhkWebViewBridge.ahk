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
    Ping() => "ok"

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
                    FileAppend("[" . A_Now . "] [HOSTOBJ] GetBrowserSnapshot #" . _callCount . " OK len=" . StrLen(s) . " reqId=" . reqLogged . " head=" . head . " tail=" . tail . "`r`n", A_ScriptDir . "\Cache\niuma_mobile_snapshot_debug.log", "UTF-8")
                }
                return s
            }
            FileAppend("[" . A_Now . "] [HOSTOBJ] GetBrowserSnapshot #" . _callCount . " EMPTY`r`n", A_ScriptDir . "\Cache\niuma_mobile_snapshot_debug.log", "UTF-8")
            return '{"type":"host_browser_snapshot","reqId":"","count":0,"arrLen":0,"url":"","error":"no_cache","truncated":false,"totalCandidates":0,"snapshot":[]}'
        } catch as e {
            FileAppend("[" . A_Now . "] [HOSTOBJ] GetBrowserSnapshot ERROR: " . e.Message . "`r`n", A_ScriptDir . "\Cache\niuma_mobile_snapshot_debug.log", "UTF-8")
            return '{"type":"host_browser_snapshot","reqId":"","count":0,"arrLen":0,"url":"","error":"bridge_error","truncated":false,"totalCandidates":0,"snapshot":[]}'
        }
    }

    /** 与 GetBrowserSnapshot 相同，供前端 pull 自愈通道按行业命名调用。 */
    GetLatestSnapshotCache() {
        return this.GetBrowserSnapshot()
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
