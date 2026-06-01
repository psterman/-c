#Requires AutoHotkey v2.0

global g_FocusBroker_Owner := ""
global g_FocusBroker_ProtectUntil := 0
global g_FocusBroker_Pending := 0
global g_FocusBroker_Seq := 0
global g_FocusBroker_LastReqTick := Map()
global g_FocusBroker_MaxRetry := 3
global g_FocusBroker_MaxWaitMs := 150
global g_FocusBroker_RetryIntervalMs := 40

FocusBroker_Log(event, detail := "") {
    try {
        ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        line := "[" . ts . "][focus][" . event . "] " . String(detail) . "`r`n"
        if FuncExists("NMER_AsyncLog")
            NMER_AsyncLog(Nmer_DebugPath("focus_broker.log"), line)
        else
            FileAppend(line, Nmer_DebugPath("focus_broker.log"), "UTF-8")
    } catch {
    }
}

FocusBroker_IsOwner(owner) {
    global g_FocusBroker_Owner
    return (String(owner) != "" && String(owner) = String(g_FocusBroker_Owner))
}

FocusBroker_Release(owner, reason := "") {
    global g_FocusBroker_Owner, g_FocusBroker_ProtectUntil
    if (String(owner) = "" || String(owner) = String(g_FocusBroker_Owner)) {
        FocusBroker_Log("release", "owner=" . g_FocusBroker_Owner . " reason=" . reason)
        g_FocusBroker_Owner := ""
        g_FocusBroker_ProtectUntil := 0
    }
}

FocusBroker_Request(owner, hwnd, priority, reason, protectMs := 300, focusCallback := 0) {
    global g_FocusBroker_Owner, g_FocusBroker_ProtectUntil, g_FocusBroker_Pending, g_FocusBroker_Seq, g_FocusBroker_LastReqTick
    o := String(owner)
    h := Integer(hwnd)
    pri := Integer(priority)
    rs := String(reason)
    now := A_TickCount
    if (o = "" || !h)
        return false
    dedupeKey := StrLower(o) . "|" . StrLower(rs)
    lastTick := 0
    try lastTick := g_FocusBroker_LastReqTick.Get(dedupeKey, 0)
    if (lastTick > 0 && (now - lastTick) < 120) {
        FocusBroker_Log("drop_dedupe", "owner=" . o . " reason=" . rs . " delta=" . (now - lastTick))
        return false
    }
    g_FocusBroker_LastReqTick[dedupeKey] := now
    g_FocusBroker_Seq += 1
    seq := g_FocusBroker_Seq
    if (g_FocusBroker_Owner != "" && g_FocusBroker_Owner != o && now < g_FocusBroker_ProtectUntil) {
        curPri := FocusBroker_DefaultPriority(g_FocusBroker_Owner)
        if (pri >= curPri) {
            g_FocusBroker_Pending := Map("owner", o, "hwnd", h, "priority", pri, "reason", rs, "protectMs", Integer(protectMs), "callback", focusCallback, "seq", seq)
            delay := Max(15, g_FocusBroker_ProtectUntil - now + 5)
            FocusBroker_Log("delay", "owner=" . o . " current=" . g_FocusBroker_Owner . " delay=" . delay . " reason=" . rs)
            SetTimer((*) => FocusBroker_RunPending(seq), -delay)
            return false
        }
        FocusBroker_Log("preempt", "owner=" . o . " current=" . g_FocusBroker_Owner . " reason=" . rs)
    }
    return FocusBroker_Grant(o, h, pri, rs, Integer(protectMs), focusCallback)
}

FocusBroker_RunPending(seq := 0, *) {
    global g_FocusBroker_Pending
    if !(g_FocusBroker_Pending is Map)
        return
    p := g_FocusBroker_Pending
    if (seq && p.Has("seq") && Integer(p["seq"]) != Integer(seq))
        return
    g_FocusBroker_Pending := 0
    FocusBroker_Request(p["owner"], p["hwnd"], p["priority"], p["reason"], p["protectMs"], p["callback"])
}

FocusBroker_Grant(owner, hwnd, priority, reason, protectMs, focusCallback := 0) {
    global g_FocusBroker_Owner, g_FocusBroker_ProtectUntil
    if !WinExist("ahk_id " . hwnd)
        return false
    g_FocusBroker_Owner := String(owner)
    g_FocusBroker_ProtectUntil := A_TickCount + Max(0, Integer(protectMs))
    FocusBroker_Log("grant", "owner=" . owner . " hwnd=" . hwnd . " priority=" . priority . " reason=" . reason)
    ctx := Map(
        "owner", String(owner),
        "hwnd", Integer(hwnd),
        "priority", Integer(priority),
        "reason", String(reason),
        "protectMs", Integer(protectMs),
        "callback", focusCallback,
        "retry", 0,
        "start", A_TickCount,
        "active", true,
        "timerFunc", 0
    )
    timerFn := 0
    timerFn := (*) => FocusBroker_AttemptActivate(ctx)
    ctx["timerFunc"] := timerFn
    SetTimer(timerFn, -1)
    return true
}

FocusBroker_AttemptActivate(ctx) {
    global g_FocusBroker_MaxRetry, g_FocusBroker_MaxWaitMs, g_FocusBroker_RetryIntervalMs, g_FocusBroker_Owner, g_FocusBroker_ProtectUntil
    if !(ctx is Map)
        return
    owner := String(ctx["owner"])
    hwnd := Integer(ctx["hwnd"])
    reason := String(ctx["reason"])
    retry := Integer(ctx["retry"])
    start := Integer(ctx["start"])
    timerFn := ctx["timerFunc"]
    if !ctx["active"] {
        try SetTimer(timerFn, 0)
        return
    }
    if !WinExist("ahk_id " . hwnd) {
        FocusBroker_Log("focus_failed_fallback", "owner=" . owner . " reason=" . reason . " msg=target_gone")
        ctx["active"] := false
        try SetTimer(timerFn, 0)
        if (g_FocusBroker_Owner = owner) {
            g_FocusBroker_Owner := ""
            g_FocusBroker_ProtectUntil := 0
        }
        return
    }
    now := A_TickCount
    if (retry >= g_FocusBroker_MaxRetry || (now - start) > g_FocusBroker_MaxWaitMs) {
        FocusBroker_Log("focus_failed_fallback", "owner=" . owner . " reason=" . reason . " retry=" . retry . " elapsed=" . (now - start))
        ctx["active"] := false
        try SetTimer(timerFn, 0)
        if (g_FocusBroker_Owner = owner) {
            g_FocusBroker_Owner := ""
            g_FocusBroker_ProtectUntil := 0
        }
        return
    }
    okActivate := FocusBroker_SetForegroundNow(hwnd)
    if !okActivate
        FocusBroker_Log("focus_soft_request", "owner=" . owner . " retry=" . retry . " reason=" . reason . " hwnd=" . hwnd)
    active := 0
    try active := WinGetID("A")
    if (active = hwnd) {
        ctx["active"] := false
        try SetTimer(timerFn, 0)
        cb := ctx["callback"]
        if cb {
            try cb.Call()
            catch {
            }
        }
        return
    }
    ctx["retry"] := retry + 1
    SetTimer(timerFn, -Abs(Integer(g_FocusBroker_RetryIntervalMs)))
}

FocusBroker_SetForegroundNow(hwnd) {
    h := Integer(hwnd)
    if !h
        return false
    try DllCall("ShowWindow", "Ptr", h, "Int", 9) ; SW_RESTORE
    ok := 0
    try ok := !!DllCall("SetForegroundWindow", "Ptr", h, "Int")
    if !ok
        return false
    try return !!WinActive("ahk_id " . h)
    catch {
        return ok
    }
}

FocusBroker_DefaultPriority(owner) {
    o := StrLower(String(owner))
    switch o {
        case "traymenu":
            return 10
        case "searchcenter":
            return 20
        case "hubcapsule":
            return 30
    }
    return 50
}
