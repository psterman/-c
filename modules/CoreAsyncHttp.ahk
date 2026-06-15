#Requires AutoHotkey v2.0

global g_CoreAsyncHttpReqSeq := 0
global g_CoreAsyncHttpReqs := Map()
global g_CoreAsyncHttpPollArmed := false
global g_CoreAsyncHttpRetrySeq := 0
global g_CoreAsyncHttpRetryJobs := Map()
global g_CoreAsyncHttp_Loaded := true

CoreAsyncHttp_Log(event, detail := "") {
    try {
        line := "[" . A_Now . "][" . String(event) . "] " . String(detail) . "`r`n"
        if FuncExists("NMER_AsyncLog")
            NMER_AsyncLog(Nmer_DebugPath("core_async_http.log"), line)
        else
            FileAppend(line, Nmer_DebugPath("core_async_http.log"), "UTF-8")
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

CoreAsyncHttp_ShouldLog(req, event) {
    opts := req["opts"]
    ; abnormal states must be fully logged
    if (event = "async_http_error" || event = "async_http_timeout" || event = "async_http_cancelled" || event = "async_http_retrying")
        return true
    rate := 1
    try rate := Number(opts["sampleLogRate"])
    catch {
        rate := 1
    }
    if (rate >= 1)
        return true
    if (rate <= 0)
        return false
    return (Random(1, 1000000) <= Floor(rate * 1000000))
}

CoreAsyncHttp_LogReq(req, event, detail := "") {
    if CoreAsyncHttp_ShouldLog(req, event)
        CoreAsyncHttp_Log(event, detail)
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
        "headers", 0,
        "phase", "send",
        "attempt", 1,
        "maxRetries", 0,
        "retryDelayMs", 250,
        "retryBackoffFactor", 2.0,
        "retryMaxDelayMs", 5000,
        "retryJitterMs", 120,
        "retryOnStatuses", [408, 425, 429, 500, 502, 503, 504],
        "retryOnErrors", ["timeout", "transport_error"],
        "sampleLogRate", 1
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
    if !IsObject(whr)
        return ""
    ; ADODB.Stream 按 UTF-8 解码二进制响应，避免 ResponseText/StrGet 在中文环境下乱码
    try {
        body := whr.ResponseBody
        if body && body.Size > 0 {
            ado := ComObject("ADODB.Stream")
            ado.Type := 1
            ado.Open()
            ado.Write(body)
            ado.Position := 0
            ado.Type := 2
            ado.Charset := "utf-8"
            txt := ado.ReadText(-1)
            ado.Close()
            if (Trim(txt) != "")
                return txt
        }
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try {
        body := whr.ResponseBody
        if body && body.Size > 0 {
            buf := Buffer(body.Size)
            DllCall("RtlMoveMemory", "Ptr", buf, "Ptr", body, "UPtr", body.Size)
            return StrGet(buf, "UTF-8")
        }
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try return String(whr.ResponseText)
    catch {
        return ""
    }
}

CoreAsyncHttp_ArmPoll() {
    global g_CoreAsyncHttpPollArmed
    if g_CoreAsyncHttpPollArmed
        return
    g_CoreAsyncHttpPollArmed := true
    SetTimer(CoreAsyncHttp_PollTick, 25)
}

CoreAsyncHttp_BuildResult(ok, status, text, err, reqMeta, startTick, errorCode := "", phase := "") {
    ec := (Trim(String(errorCode)) = "") ? Trim(String(err)) : Trim(String(errorCode))
    if (ec = "")
        ec := ok ? "" : "unknown"
    ph := (Trim(String(phase)) = "") ? (reqMeta.Has("phase") ? String(reqMeta["phase"]) : "done") : String(phase)
    rid := reqMeta.Has("reqId") ? reqMeta["reqId"] : 0
    ret := Map(
        "ok", ok ? true : false,
        "status", Integer(status),
        "text", String(text),
        "json", 0,
        "error", String(err),
        "errorCode", ec,
        "phase", ph,
        "attempt", reqMeta.Has("attempt") ? Integer(reqMeta["attempt"]) : 1,
        "reqId", rid,
        "requestId", (Trim(String(rid)) != "") ? String(rid) : "",
        "ts", A_Now,
        "elapsedMs", A_TickCount - Integer(startTick)
    )
    if (Trim(String(text)) != "") {
        try ret["json"] := Jxon_Load(text)
    }
    return ret
}

CoreAsyncHttp_IsCancelled(req) {
    return req.Has("cancelled") && !!req["cancelled"]
}

CoreAsyncHttp_Finalize(id, result) {
    global g_CoreAsyncHttpReqs
    if !(g_CoreAsyncHttpReqs is Map) || !g_CoreAsyncHttpReqs.Has(id)
        return
    req := g_CoreAsyncHttpReqs[id]
    cb := req["cb"]
    ; Break strong references early to avoid closure retention on async paths.
    req["cb"] := 0
    req["whr"] := 0
    try g_CoreAsyncHttpReqs.Delete(id)
    if cb {
        try {
            if (Type(cb) = "Func" || Type(cb) = "BoundFunc") {
                if (cb.MinParams <= 1)
                    cb.Call(result)
                else
                    cb.Call(result, "")
            } else {
                cb.Call(result)
            }
        }
    }
}

CoreAsyncHttp_ShouldRetry(req, ret) {
    opts := req["opts"]
    attempt := Integer(req["attempt"])
    maxRetries := Integer(opts["maxRetries"])
    if (maxRetries <= 0 || attempt > maxRetries)
        return false
    if CoreAsyncHttp_IsCancelled(req)
        return false
    if ret["errorCode"] != "" {
        if (ret["errorCode"] = "http_status_" . ret["status"]) {
            ros := opts["retryOnStatuses"]
            if (ros is Array) {
                for _, st in ros {
                    if Integer(st) = Integer(ret["status"])
                        return true
                }
            }
            return false
        }
        roe := opts["retryOnErrors"]
        if (roe is Array) {
            for _, ec in roe {
                if (StrLower(String(ec)) = StrLower(String(ret["errorCode"])))
                    return true
            }
        }
    }
    return false
}

CoreAsyncHttp_QueueRetry(id) {
    global g_CoreAsyncHttpReqs, g_CoreAsyncHttpRetrySeq, g_CoreAsyncHttpRetryJobs
    if !(g_CoreAsyncHttpReqs is Map) || !g_CoreAsyncHttpReqs.Has(id)
        return false
    req := g_CoreAsyncHttpReqs[id]
    if CoreAsyncHttp_IsCancelled(req)
        return false
    opts := req["opts"]
    baseDelay := Max(10, Integer(opts["retryDelayMs"]))
    attempt := Max(1, Integer(req["attempt"]))
    factor := 2.0
    try factor := Number(opts["retryBackoffFactor"])
    catch {
        factor := 2.0
    }
    if (factor < 1)
        factor := 1
    maxDelay := Max(baseDelay, Integer(opts["retryMaxDelayMs"]))
    jitter := Max(0, Integer(opts["retryJitterMs"]))
    delayF := baseDelay * (factor ** Max(0, attempt - 2))
    delayMs := Min(maxDelay, Floor(delayF))
    if (jitter > 0)
        delayMs += Random(0, jitter)
    req["phase"] := "retry_wait"
    g_CoreAsyncHttpReqs[id] := req
    g_CoreAsyncHttpRetrySeq += 1
    rid := g_CoreAsyncHttpRetrySeq
    g_CoreAsyncHttpRetryJobs[rid] := id
    SetTimer((*) => CoreAsyncHttp_RetryTimerFire(rid), -delayMs)
    return true
}

CoreAsyncHttp_RetryTimerFire(retryId) {
    global g_CoreAsyncHttpRetryJobs, g_CoreAsyncHttpReqs
    if !(g_CoreAsyncHttpRetryJobs is Map) || !g_CoreAsyncHttpRetryJobs.Has(retryId)
        return
    id := g_CoreAsyncHttpRetryJobs[retryId]
    g_CoreAsyncHttpRetryJobs.Delete(retryId)
    if !(g_CoreAsyncHttpReqs is Map) || !g_CoreAsyncHttpReqs.Has(id)
        return
    req := g_CoreAsyncHttpReqs[id]
    ; must guard cancelled first to avoid resurrecting requests
    if CoreAsyncHttp_IsCancelled(req) {
        ret := CoreAsyncHttp_BuildResult(false, 0, "", "cancelled", req["opts"], req["start"], "cancelled", "cancelled")
        CoreAsyncHttp_LogReq(req, "async_http_cancelled", "id=" . id . " req_id=" . req["opts"]["reqId"] . " tag=" . req["opts"]["tag"] . " phase=retry_wait")
        CoreAsyncHttp_Finalize(id, ret)
        return
    }
    CoreAsyncHttp_SendAttempt(id)
}

CoreAsyncHttp_SendAttempt(id) {
    global g_CoreAsyncHttpReqs
    if !(g_CoreAsyncHttpReqs is Map) || !g_CoreAsyncHttpReqs.Has(id)
        return false
    req := g_CoreAsyncHttpReqs[id]
    if CoreAsyncHttp_IsCancelled(req)
        return false
    opts := req["opts"]
    req["phase"] := "send"
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        reqUrl := String(req["url"])
        ; Proxy strategy:
        ; - Loopback (127.0.0.1/localhost): force DIRECT to avoid accidental system proxy interception.
        ; - External: use PRECONFIG to respect WinHTTP proxy settings (can be imported from system proxy).
        if (FuncExists("NiumaOllama_IsLoopbackUrl") && NiumaOllama_IsLoopbackUrl(reqUrl)) {
            try whr.SetProxy(1)
        } else {
            try whr.SetProxy(0)
        }
        whr.Open(String(req["method"]), reqUrl, true)
        whr.SetTimeouts(Integer(opts["resolveTimeoutMs"]), Integer(opts["connectTimeoutMs"]), Integer(opts["sendTimeoutMs"]), Integer(opts["receiveTimeoutMs"]))
        CoreAsyncHttp_ApplyHeaders(whr, opts["headers"])
        if !CoreAsyncHttp_HasHeader(opts["headers"], "Accept-Encoding")
            try whr.SetRequestHeader("Accept-Encoding", "identity")
        m := String(req["method"])
        if (m = "POST" || m = "PUT" || m = "PATCH") {
            if !CoreAsyncHttp_HasHeader(opts["headers"], "Content-Type")
                whr.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
            payload := (Trim(String(req["body"])) = "") ? "{}" : String(req["body"])
            whr.Send(payload)
        } else {
            whr.Send()
        }
        req["whr"] := whr
        req["phase"] := "wait"
        g_CoreAsyncHttpReqs[id] := req
        CoreAsyncHttp_LogReq(req, "async_http_send", "id=" . id . " req_id=" . opts["reqId"] . " tag=" . opts["tag"] . " method=" . req["method"] . " url=" . req["url"] . " attempt=" . req["attempt"])
        CoreAsyncHttp_ArmPoll()
        return true
    } catch as e {
        retErr := CoreAsyncHttp_BuildResult(false, 0, "", e.Message, opts, req["start"], "transport_error", "send")
        if CoreAsyncHttp_ShouldRetry(req, retErr) {
            req["attempt"] := Integer(req["attempt"]) + 1
            req["phase"] := "retrying"
            g_CoreAsyncHttpReqs[id] := req
            CoreAsyncHttp_LogReq(req, "async_http_retrying", "id=" . id . " req_id=" . opts["reqId"] . " tag=" . opts["tag"] . " reason=" . retErr["errorCode"] . " next_attempt=" . req["attempt"])
            CoreAsyncHttp_QueueRetry(id)
            return false
        }
        CoreAsyncHttp_LogReq(req, "async_http_error", "id=" . id . " req_id=" . opts["reqId"] . " tag=" . opts["tag"] . " msg=" . e.Message)
        CoreAsyncHttp_Finalize(id, retErr)
        return false
    }
}

CoreAsyncHttp_PollTick(*) {
    global g_CoreAsyncHttpReqs, g_CoreAsyncHttpPollArmed
    if !(g_CoreAsyncHttpReqs is Map) || (g_CoreAsyncHttpReqs.Count = 0) {
        g_CoreAsyncHttpPollArmed := false
        SetTimer(CoreAsyncHttp_PollTick, 0)
        return
    }
    for id, req in g_CoreAsyncHttpReqs {
        if CoreAsyncHttp_IsCancelled(req) {
            try req["whr"].Abort()
            retCancel := CoreAsyncHttp_BuildResult(false, 0, "", "cancelled", req["opts"], req["start"], "cancelled", "cancelled")
            CoreAsyncHttp_LogReq(req, "async_http_cancelled", "id=" . id . " req_id=" . req["opts"]["reqId"] . " tag=" . req["opts"]["tag"] . " phase=poll")
            CoreAsyncHttp_Finalize(id, retCancel)
            continue
        }
        if (!req.Has("phase") || String(req["phase"]) != "wait")
            continue
        whr := req["whr"]
        opts := req["opts"]
        startTick := req["start"]
        timeoutMs := Integer(opts["timeoutMs"])
        if (A_TickCount - startTick > timeoutMs) {
            try whr.Abort()
            retTimeout := CoreAsyncHttp_BuildResult(false, 0, "", "timeout", opts, startTick, "timeout", "timeout")
            if CoreAsyncHttp_ShouldRetry(req, retTimeout) {
                req["attempt"] := Integer(req["attempt"]) + 1
                req["phase"] := "retrying"
                g_CoreAsyncHttpReqs[id] := req
                CoreAsyncHttp_LogReq(req, "async_http_retrying", "id=" . id . " req_id=" . opts["reqId"] . " tag=" . opts["tag"] . " reason=timeout next_attempt=" . req["attempt"])
                CoreAsyncHttp_QueueRetry(id)
            } else {
                CoreAsyncHttp_LogReq(req, "async_http_timeout", "id=" . id . " req_id=" . opts["reqId"] . " tag=" . opts["tag"] . " timeout_ms=" . timeoutMs)
                CoreAsyncHttp_Finalize(id, retTimeout)
            }
            continue
        }
        done := false
        try done := !!whr.WaitForResponse(0)
        catch as e {
            retErr := CoreAsyncHttp_BuildResult(false, 0, "", e.Message, opts, startTick, "transport_error", "wait")
            if CoreAsyncHttp_ShouldRetry(req, retErr) {
                req["attempt"] := Integer(req["attempt"]) + 1
                req["phase"] := "retrying"
                g_CoreAsyncHttpReqs[id] := req
                CoreAsyncHttp_LogReq(req, "async_http_retrying", "id=" . id . " req_id=" . opts["reqId"] . " tag=" . opts["tag"] . " reason=transport_error next_attempt=" . req["attempt"])
                CoreAsyncHttp_QueueRetry(id)
            } else {
                CoreAsyncHttp_LogReq(req, "async_http_error", "id=" . id . " req_id=" . opts["reqId"] . " tag=" . opts["tag"] . " msg=" . e.Message)
                CoreAsyncHttp_Finalize(id, retErr)
            }
            continue
        }
        if !done
            continue
        st := 0
        txt := ""
        try st := Integer(whr.Status)
        txt := CoreAsyncHttp_ReadUtf8Text(whr)
        ok := (st >= 200 && st < 300)
        errCode := ok ? "" : ("http_status_" . st)
        retDone := CoreAsyncHttp_BuildResult(ok, st, txt, ok ? "" : errCode, opts, startTick, errCode, "done")
        if (!ok && CoreAsyncHttp_ShouldRetry(req, retDone)) {
            req["attempt"] := Integer(req["attempt"]) + 1
            req["phase"] := "retrying"
            g_CoreAsyncHttpReqs[id] := req
            CoreAsyncHttp_LogReq(req, "async_http_retrying", "id=" . id . " req_id=" . opts["reqId"] . " tag=" . opts["tag"] . " reason=" . errCode . " next_attempt=" . req["attempt"])
            CoreAsyncHttp_QueueRetry(id)
            continue
        }
        CoreAsyncHttp_LogReq(req, "async_http_done", "id=" . id . " req_id=" . opts["reqId"] . " tag=" . opts["tag"] . " status=" . st . " elapsed_ms=" . (A_TickCount - startTick) . " attempt=" . req["attempt"])
        CoreAsyncHttp_Finalize(id, retDone)
    }
}

CoreAsyncHttp_Cancel(idOrReqId) {
    global g_CoreAsyncHttpReqs
    target := String(idOrReqId)
    if !(g_CoreAsyncHttpReqs is Map) || (g_CoreAsyncHttpReqs.Count = 0)
        return 0
    cancelled := 0
    for id, req in g_CoreAsyncHttpReqs {
        if (target = "*" || target = "all") {
            req["cancelled"] := true
            req["phase"] := "cancelled"
            g_CoreAsyncHttpReqs[id] := req
            try req["whr"].Abort()
            cancelled += 1
            continue
        }
        matchId := (String(id) = target)
        reqId := req["opts"].Has("reqId") ? String(req["opts"]["reqId"]) : ""
        matchReqId := (target != "" && reqId != "" && reqId = target)
        if !(matchId || matchReqId)
            continue
        req["cancelled"] := true
        req["phase"] := "cancelled"
        g_CoreAsyncHttpReqs[id] := req
        try req["whr"].Abort()
        cancelled += 1
    }
    return cancelled
}

CoreAsyncHttp_SendAsync(method, url, body := "", callback := 0, opts := 0) {
    global g_CoreAsyncHttpReqSeq, g_CoreAsyncHttpReqs
    cb := IsObject(callback) ? callback : 0
    o := CoreAsyncHttp_DefaultOpts(opts)
    g_CoreAsyncHttpReqSeq += 1
    id := g_CoreAsyncHttpReqSeq
    req := Map(
        "id", id,
        "method", String(method),
        "url", String(url),
        "body", String(body),
        "cb", cb,
        "opts", o,
        "start", A_TickCount,
        "attempt", 1,
        "phase", "send",
        "cancelled", false,
        "whr", 0
    )
    g_CoreAsyncHttpReqs[id] := req
    if !CoreAsyncHttp_SendAttempt(id) {
        if g_CoreAsyncHttpReqs.Has(id)
            CoreAsyncHttp_ArmPoll()
        return id
    }
    return id
}

HttpGetAsync(url, callback, opts := 0) {
    return CoreAsyncHttp_SendAsync("GET", url, "", callback, opts)
}

HttpJsonAsync(method, url, body, callback, opts := 0) {
    return CoreAsyncHttp_SendAsync(method, url, body, callback, opts)
}

CoreAsyncHttp_GetActiveCount() {
    global g_CoreAsyncHttpReqs
    return (g_CoreAsyncHttpReqs is Map) ? g_CoreAsyncHttpReqs.Count : 0
}

CoreAsyncHttp_GetRetryJobCount() {
    global g_CoreAsyncHttpRetryJobs
    return (g_CoreAsyncHttpRetryJobs is Map) ? g_CoreAsyncHttpRetryJobs.Count : 0
}

CoreAsyncHttp_DebugSnapshot() {
    global g_CoreAsyncHttpReqs, g_CoreAsyncHttpRetryJobs
    snap := Map(
        "active", 0,
        "retryJobs", 0,
        "phases", Map()
    )
    if (g_CoreAsyncHttpReqs is Map) {
        snap["active"] := g_CoreAsyncHttpReqs.Count
        for _, req in g_CoreAsyncHttpReqs {
            ph := req.Has("phase") ? String(req["phase"]) : "unknown"
            pm := snap["phases"]
            pm[ph] := pm.Has(ph) ? (Integer(pm[ph]) + 1) : 1
        }
    }
    if (g_CoreAsyncHttpRetryJobs is Map)
        snap["retryJobs"] := g_CoreAsyncHttpRetryJobs.Count
    return snap
}
