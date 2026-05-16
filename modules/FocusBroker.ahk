#Requires AutoHotkey v2.0

global g_FocusBroker_Owner := ""
global g_FocusBroker_ProtectUntil := 0
global g_FocusBroker_Pending := 0
global g_FocusBroker_Seq := 0

FocusBroker_Log(event, detail := "") {
    try {
        ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        line := "[" . ts . "][focus][" . event . "] " . String(detail) . "`r`n"
        if FuncExists("NMER_AsyncLog")
            NMER_AsyncLog(A_ScriptDir . "\Cache\focus_broker.log", line)
        else
            FileAppend(line, A_ScriptDir . "\Cache\focus_broker.log", "UTF-8")
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
    global g_FocusBroker_Owner, g_FocusBroker_ProtectUntil, g_FocusBroker_Pending, g_FocusBroker_Seq
    o := String(owner)
    h := Integer(hwnd)
    pri := Integer(priority)
    now := A_TickCount
    if (o = "" || !h)
        return false
    g_FocusBroker_Seq += 1
    seq := g_FocusBroker_Seq
    if (g_FocusBroker_Owner != "" && g_FocusBroker_Owner != o && now < g_FocusBroker_ProtectUntil) {
        curPri := FocusBroker_DefaultPriority(g_FocusBroker_Owner)
        if (pri >= curPri) {
            g_FocusBroker_Pending := Map("owner", o, "hwnd", h, "priority", pri, "reason", String(reason), "protectMs", Integer(protectMs), "callback", focusCallback, "seq", seq)
            delay := Max(15, g_FocusBroker_ProtectUntil - now + 5)
            FocusBroker_Log("delay", "owner=" . o . " current=" . g_FocusBroker_Owner . " delay=" . delay . " reason=" . reason)
            SetTimer((*) => FocusBroker_RunPending(seq), -delay)
            return false
        }
        FocusBroker_Log("preempt", "owner=" . o . " current=" . g_FocusBroker_Owner . " reason=" . reason)
    }
    return FocusBroker_Grant(o, h, pri, String(reason), Integer(protectMs), focusCallback)
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
    try WinActivate("ahk_id " . hwnd)
    catch as err {
        FocusBroker_Log("grant_failed", "owner=" . owner . " msg=" . err.Message)
        return false
    }
    if focusCallback {
        try focusCallback.Call()
        catch {
        }
    }
    return true
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
