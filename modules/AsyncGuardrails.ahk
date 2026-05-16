#Requires AutoHotkey v2.0

global g_AsyncStaleLastByDomain := Map()

AsyncGuardrails_NowTs() {
    return A_Now
}

AsyncGuardrails_RequestIdFromPayload(payload) {
    if !(payload is Map)
        return ""
    if payload.Has("requestId")
        return String(payload["requestId"])
    if payload.Has("reqId")
        return String(payload["reqId"])
    return ""
}

AsyncGuardrails_ShouldDropStale(domain, requestId) {
    global g_AsyncStaleLastByDomain
    d := Trim(String(domain))
    rid := Trim(String(requestId))
    if (d = "" || rid = "")
        return false
    cur := g_AsyncStaleLastByDomain.Has(d) ? String(g_AsyncStaleLastByDomain[d]) : ""
    if (cur != "" && cur != rid)
        return true
    return false
}

AsyncGuardrails_UpdateLatest(domain, requestId) {
    global g_AsyncStaleLastByDomain
    d := Trim(String(domain))
    rid := Trim(String(requestId))
    if (d = "" || rid = "")
        return
    g_AsyncStaleLastByDomain[d] := rid
}

AsyncGuardrails_AttachMeta(payload, requestId := "", phase := "", errorCode := "") {
    out := (payload is Map) ? payload : Map()
    rid := Trim(String(requestId))
    if (rid != "") {
        out["requestId"] := rid
        if !out.Has("reqId")
            out["reqId"] := rid
    }
    ph := Trim(String(phase))
    if (ph != "")
        out["phase"] := ph
    ec := Trim(String(errorCode))
    if (ec != "")
        out["errorCode"] := ec
    out["ts"] := AsyncGuardrails_NowTs()
    return out
}

