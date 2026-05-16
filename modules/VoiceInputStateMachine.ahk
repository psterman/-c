#Requires AutoHotkey v2.0

global g_VoiceFSM := Map(
    "state", "idle",
    "inDispatch", false,
    "queue", []
)

VoiceFSM_State() {
    global g_VoiceFSM
    return g_VoiceFSM["state"]
}

VoiceFSM_Log(msg) {
    try CoreAsyncHttp_Log("voice_fsm", String(msg))
}

VoiceFSM_Dispatch(event, payload := 0) {
    global g_VoiceFSM
    ev := Trim(String(event))
    if (ev = "")
        return
    if g_VoiceFSM["inDispatch"] {
        g_VoiceFSM["queue"].Push(Map("event", ev, "payload", payload))
        return
    }
    g_VoiceFSM["inDispatch"] := true
    Critical("On")
    try {
        VoiceFSM_ProcessEvent(ev, payload)
    } finally {
        Critical("Off")
        g_VoiceFSM["inDispatch"] := false
    }
    SetTimer(VoiceFSM_DrainQueue, -10)
}

VoiceFSM_DrainQueue(*) {
    global g_VoiceFSM
    if g_VoiceFSM["inDispatch"]
        return
    if !(g_VoiceFSM["queue"] is Array) || g_VoiceFSM["queue"].Length = 0
        return
    item := g_VoiceFSM["queue"].RemoveAt(1)
    VoiceFSM_Dispatch(item["event"], item["payload"])
    if (g_VoiceFSM["queue"].Length > 0)
        SetTimer(VoiceFSM_DrainQueue, -10)
}

VoiceFSM_ProcessEvent(event, payload := 0) {
    global g_VoiceFSM
    oldState := String(g_VoiceFSM["state"])
    newState := oldState
    switch event {
        case "start_request":
            if (oldState = "idle" || oldState = "paused")
                newState := "listening"
        case "pause_request":
            if (oldState = "listening")
                newState := "paused"
        case "resume_request":
            if (oldState = "paused")
                newState := "listening"
        case "stop_request":
            newState := "idle"
        case "processing_begin":
            if (oldState = "listening" || oldState = "paused")
                newState := "processing"
        case "processing_done":
            if (oldState = "processing")
                newState := "listening"
        case "error":
            newState := "error"
        case "reset":
            newState := "idle"
    }
    g_VoiceFSM["state"] := newState
    if (newState != oldState) {
        VoiceFSM_Log("event=" . event . " " . oldState . "->" . newState)
        SetTimer(VoiceFSM_ScheduleEffects.Bind(oldState, newState, event), -10)
    } else {
        VoiceFSM_Log("event=" . event . " stay=" . newState)
        if (event != "reset")
            try VoiceFSM_Log("reject event=" . event . " stay=" . newState)
    }
}

VoiceFSM_ScheduleEffects(oldState, newState, event) {
    if FuncExists("VoiceInputEffects_OnTransition")
        VoiceInputEffects_OnTransition(oldState, newState, event)
}

