#Requires AutoHotkey v2.0

global g_CoreAsyncHttpReqSeq := 0
global g_CoreAsyncHttpReqs := Map()
global g_CoreAsyncHttpPollArmed := false

CoreAsyncHttp_Log(event, detail := "") {
    try {
        line := "[" . A_Now . "][" . String(event) . "] " . String(detail) . "`r`n"
        if FuncExists("NMER_AsyncLog")
            NMER_AsyncLog(A_ScriptDir . "\Cache\core_async_http.log", line)
        else
            FileAppend(line, A_ScriptDir . "\Cache\core_async_http.log", "UTF-8")
    } catch {
    }
}

CoreAsyncHttp_DefaultOpts(opts := 0) {
    out := Map(
        "timeoutMs", 2200,
        "connectTimeoutMs", 900,
        "sendTimeoutMs", 900,
        "receiveTimeoutMs", 2200,
        "resolveTimeoutMs", 900,
        "reqId", 0,
        "tag", "",
        "headers", 0
    )
    if (opts is Map) {
        for k, v in opts
            out[k] := v
    }
    return out
}

CoreAsyncHttp_ApplyHeaders(whr, headers) {
    if !(headers is Map)
        return
    for k, v in headers {
        hk := Trim(String(k))
        if (hk = "")
            continue
        try whr.SetRequestHeader(hk, String(v))
    }
}

CoreAsyncHttp_HasHeader(headers, keyName) {
    if !(headers is Map)
        return false
    want := StrLower(Trim(String(keyName)))
    if (want = "")
        return false
    for k, _ in headers {
        if (StrLower(Trim(String(k))) = want)
            return true
    }
    return false
}

CoreAsyncHttp_ReadUtf8Text(whr) {
    try {
        body := whr.ResponseBody
        if !body
            return ""
        size := body.Size
        if (size <= 0)
            return ""
        pData := 0
        try pData := body.pData
        if !pData
            return ""
        return StrGet(pData, size, "UTF-8")
    } catch {
        try return String(whr.ResponseText)
        catch {
            return ""
        }
    }
}

CoreAsyncHttp_ArmPoll() {
    global g_CoreAsyncHttpPollArmed
    if g_CoreAsyncHttpPollArmed
        return
    g_CoreAsyncHttpPollArmed := true
    SetTimer(CoreAsyncHttp_PollTick, 25)
}

CoreAsyncHttp_Finalize(req, result) {
    cb := req["cb"]
    if cb {
        try cb.Call(result)
    }
}

CoreAsyncHttp_BuildResult(ok, status, text, err, reqMeta, startTick) {
    ret := Map(
        "ok", ok ? true : false,
        "status", Integer(status),
        "text", String(text),
        "json", 0,
        "error", String(err),
        "reqId", reqMeta.Has("reqId") ? reqMeta["reqId"] : 0,
        "elapsedMs", A_TickCount - Integer(startTick)
    )
    if (Trim(String(text)) != "") {
        try ret["json"] := Jxon_Load(text)
    }
    return ret
}

CoreAsyncHttp_PollTick(*) {
    global g_CoreAsyncHttpReqs, g_CoreAsyncHttpPollArmed
    if !(g_CoreAsyncHttpReqs is Map) || (g_CoreAsyncHttpReqs.Count = 0) {
        g_CoreAsyncHttpPollArmed := false
        SetTimer(CoreAsyncHttp_PollTick, 0)
        return
    }
    removeIds := []
    for id, req in g_CoreAsyncHttpReqs {
        whr := req["whr"]
        opts := req["opts"]
        startTick := req["start"]
        timeoutMs := Integer(opts["timeoutMs"])
        if (A_TickCount - startTick > timeoutMs) {
            try whr.Abort()
            CoreAsyncHttp_Log("async_http_timeout", "id=" . id . " req_id=" . opts["reqId"] . " tag=" . opts["tag"] . " timeout_ms=" . timeoutMs)
            retTimeout := CoreAsyncHttp_BuildResult(false, 0, "", "timeout", opts, startTick)
            CoreAsyncHttp_Finalize(req, retTimeout)
            removeIds.Push(id)
            continue
        }
        done := false
        try done := !!whr.WaitForResponse(0)
        catch as e {
            CoreAsyncHttp_Log("async_http_error", "id=" . id . " req_id=" . opts["reqId"] . " tag=" . opts["tag"] . " msg=" . e.Message)
            retErr := CoreAsyncHttp_BuildResult(false, 0, "", e.Message, opts, startTick)
            CoreAsyncHttp_Finalize(req, retErr)
            removeIds.Push(id)
            continue
        }
        if !done
            continue
        st := 0
        txt := ""
        try st := Integer(whr.Status)
        txt := CoreAsyncHttp_ReadUtf8Text(whr)
        ok := (st >= 200 && st < 300)
        err := ok ? "" : ("http_status_" . st)
        CoreAsyncHttp_Log("async_http_done", "id=" . id . " req_id=" . opts["reqId"] . " tag=" . opts["tag"] . " status=" . st . " elapsed_ms=" . (A_TickCount - startTick))
        retDone := CoreAsyncHttp_BuildResult(ok, st, txt, err, opts, startTick)
        CoreAsyncHttp_Finalize(req, retDone)
        removeIds.Push(id)
    }
    for _, id in removeIds {
        try g_CoreAsyncHttpReqs.Delete(id)
    }
}

CoreAsyncHttp_SendAsync(method, url, body := "", callback := 0, opts := 0) {
    global g_CoreAsyncHttpReqSeq, g_CoreAsyncHttpReqs
    cb := IsObject(callback) ? callback : 0
    o := CoreAsyncHttp_DefaultOpts(opts)
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open(String(method), String(url), true)
        whr.SetTimeouts(Integer(o["resolveTimeoutMs"]), Integer(o["connectTimeoutMs"]), Integer(o["sendTimeoutMs"]), Integer(o["receiveTimeoutMs"]))
        CoreAsyncHttp_ApplyHeaders(whr, o["headers"])
        if (String(method) = "POST" || String(method) = "PUT" || String(method) = "PATCH") {
            if !CoreAsyncHttp_HasHeader(o["headers"], "Content-Type")
                whr.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
            payload := (Trim(String(body)) = "") ? "{}" : String(body)
            whr.Send(payload)
        } else {
            whr.Send()
        }
        g_CoreAsyncHttpReqSeq += 1
        id := g_CoreAsyncHttpReqSeq
        g_CoreAsyncHttpReqs[id] := Map("whr", whr, "cb", cb, "start", A_TickCount, "opts", o)
        CoreAsyncHttp_Log("async_http_send", "id=" . id . " req_id=" . o["reqId"] . " tag=" . o["tag"] . " method=" . String(method) . " url=" . String(url))
        CoreAsyncHttp_ArmPoll()
        return id
    } catch as e {
        CoreAsyncHttp_Log("async_http_error", "req_id=" . o["reqId"] . " tag=" . o["tag"] . " msg=" . e.Message)
        if cb {
            ret := CoreAsyncHttp_BuildResult(false, 0, "", e.Message, o, A_TickCount)
            try cb.Call(ret)
        }
        return 0
    }
}

HttpGetAsync(url, callback, opts := 0) {
    return CoreAsyncHttp_SendAsync("GET", url, "", callback, opts)
}

HttpJsonAsync(method, url, body, callback, opts := 0) {
    return CoreAsyncHttp_SendAsync(method, url, body, callback, opts)
}
