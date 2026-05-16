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
        out := Map("ok", false, "status", 0, "body", "", "error", "sync_http_disabled")
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
        this._httpReqSeq += 1
        rid := this._httpReqSeq
        payloadId := String(requestId)
        HttpJsonAsync(m = "" ? "GET" : m, u, body, (ret) => (
            this._EmitHttpAsyncResult(rid, payloadId, ret)
        ), Map("tag", "ahk_bridge_http", "reqId", rid, "timeoutMs", 5000, "receiveTimeoutMs", 5000))
        out["ok"] := true
        out["queued"] := true
        out["reqId"] := rid
        return Jxon_Dump(out)
    }

    _EmitHttpAsyncResult(reqId, requestId, ret) {
        evt := Map(
            "type", "ahk_http_result",
            "reqId", reqId,
            "requestId", requestId,
            "ok", (ret is Map) ? ret["ok"] : false,
            "status", (ret is Map) ? ret["status"] : 0,
            "body", (ret is Map) ? ret["text"] : "",
            "error", (ret is Map) ? ret["error"] : "invalid_ret"
        )
        try {
            if FuncExists("WebView_BroadcastPayload")
                Func("WebView_BroadcastPayload").Call(evt)
            else if FuncExists("WebView_QueuePayload")
                WebView_QueuePayload(0, evt)
        }
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
