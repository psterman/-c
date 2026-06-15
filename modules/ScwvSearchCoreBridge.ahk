; ScwvSearchCoreBridge.ahk — SearchCore 进程编排与 HTTP 桥（SearchCenterWebViewCore 首刀拆分）
; 依赖父模块：SCWV_FuncExists, SCWV_Log, _SCWV_LogRuntime, Jxon_Load

_SCWV_IsSearchCoreAlive() {
    return ProcessExist("SearchCenterCore.exe") ? true : false
}

_SCWV_SearchCoreExePath() {
    return Nmer_SearchCenterCoreExe()
}

_SCWV_ApplySearchCoreDefaults() {
    ; v4：Everything 仅做发现；默认不启全盘 MFT（窄根 + walk 回退由 RootPolicy 控制）
    try EnvSet("SEARCHCENTER_FT_USE_EVERYTHING", "1")
    catch {
    }
    try EnvSet("SEARCHCENTER_FT_USE_MFT", "0")
    catch {
    }
    try EnvSet("SEARCHCENTER_FT_USE_USN", "1")
    catch {
    }
    try EnvSet("SEARCHCENTER_FT_MAX_FILE_MB", "16")
    catch {
    }
    try EnvSet("SEARCHCENTER_FT_HARD_LIMIT_MB", "32")
    catch {
    }
    try EnvSet("SEARCHCENTER_FT_COLD_IDLE", "1")
    catch {
    }
    ; P2：空闲停 indexer + 进程退出（诊断脚本会临时设 SEARCHCENTER_IDLE_EXIT=0）
    try EnvSet("SEARCHCENTER_IDLE_EXIT", "1")
    catch {
    }
    try EnvSet("SEARCHCENTER_IDLE_STOP_INDEXER_SEC", "300")
    catch {
    }
    try EnvSet("SEARCHCENTER_IDLE_EXIT_SEC", "600")
    catch {
    }
    try EnvSet("SEARCHCENTER_MEM_GOVERNOR", "1")
    catch {
    }
    try EnvSet("SEARCHCENTER_MEM_SOFT_MIB", "600")
    catch {
    }
    try EnvSet("SEARCHCENTER_MEM_HARD_MIB", "900")
    catch {
    }
}

_SCWV_IsSearchCoreStarting() {
    global g_SCWV_GoStartPhase
    phase := String(g_SCWV_GoStartPhase)
    return (phase = "KILLING" || phase = "STARTING" || phase = "PROCESS_ONLY")
}

_SCWV_RestartSearchCore(forceRestart := true) {
    global g_SCWV_GoStartPhase, g_SCWV_GoStartGen, g_SCWV_GoStartPending, g_SCWV_GoPhaseSinceTick, g_SCWV_GoStartTryCount
    if _SCWV_IsSearchCoreStarting() {
        g_SCWV_GoStartPending := true
        return true
    }
    if (_SCWV_SearchCoreExePath() = "") {
        g_SCWV_GoStartPhase := "IDLE"
        return false
    }
    g_SCWV_GoStartGen += 1
    myGen := g_SCWV_GoStartGen
    g_SCWV_GoStartPhase := "STARTING"
    g_SCWV_GoPhaseSinceTick := A_TickCount
    g_SCWV_GoStartTryCount := 0
    SetTimer((*) => SCWV_GoPhaseWatchdogTick(myGen), -100)
    SetTimer((*) => _SCWV_StartSearchCoreLaunch(myGen, forceRestart), -80)
    return true
}

_SCWV_StartSearchCoreLaunch(gen, forceRestart := false, *) {
    global g_SCWV_GoStartGen
    if (Integer(gen) != Integer(g_SCWV_GoStartGen))
        return
    try {
        if SCWV_FuncExists("SearchCore_EnsureStatus") {
            SearchCore_EnsureStatus(forceRestart, "SCWV")
        } else if SCWV_FuncExists("Nmer_StartSearchCenterCoreStatus") {
            Nmer_StartSearchCenterCoreStatus(forceRestart, "SCWV")
        } else if SCWV_FuncExists("Nmer_StartSearchCenterCore") {
            Nmer_StartSearchCenterCore(forceRestart)
        }
    } catch {
    }
    SetTimer((*) => _SCWV_CheckSearchCoreStartup(gen), -80)
}

_SCWV_CheckSearchCoreStartup(gen, *) {
    global g_SCWV_GoStartGen, g_SCWV_GoStartPhase, g_SCWV_GoStartPending, g_SCWV_GoPhaseSinceTick, g_SCWV_GoStartTryCount, g_SCWV_BackendHealthy
    if (Integer(gen) != Integer(g_SCWV_GoStartGen))
        return
    if ProcessExist("SearchCenterCore.exe") {
        healthOk := SCWV_FuncExists("Nmer_SearchCenterCoreHealthy") && Nmer_SearchCenterCoreHealthy()
        if healthOk {
            g_SCWV_GoStartPhase := "RUNNING"
            g_SCWV_GoPhaseSinceTick := A_TickCount
            g_SCWV_GoStartPending := false
            g_SCWV_BackendHealthy := true
            if SCWV_FuncExists("SearchCore_LifecycleLogJson")
                SearchCore_LifecycleLogJson("health_ok", Map("caller", "SCWV", "phase", "RUNNING"))
            SetTimer(_SCWV_RunPendingGoSearch, -60)
            SetTimer((*) => _SCWV_PostFullTextStatus(false), -120)
            return
        }
        g_SCWV_GoStartPhase := "PROCESS_ONLY"
        g_SCWV_BackendHealthy := false
        g_SCWV_GoStartTryCount += 1
        if (g_SCWV_GoStartTryCount < 100) {
            SetTimer((*) => _SCWV_CheckSearchCoreStartup(gen), -80)
            return
        }
        if (Integer(gen) = Integer(g_SCWV_GoStartGen))
            g_SCWV_GoStartPhase := "HEALTH_TIMEOUT"
        if SCWV_FuncExists("SearchCore_LifecycleLogJson")
            SearchCore_LifecycleLogJson("health_timeout", Map("caller", "SCWV", "tries", g_SCWV_GoStartTryCount))
        if g_SCWV_GoStartPending {
            g_SCWV_GoStartPending := false
            SetTimer(_SCWV_RunDeferredSearchCoreEnsure, -10)
        }
        _SCWV_ShowSearchCoreError("SearchCenterCore 已启动但 /health 未就绪（请检查 8080 端口）")
        return false
    }
    g_SCWV_GoStartTryCount += 1
    if (g_SCWV_GoStartTryCount < 100) {
        SetTimer((*) => _SCWV_CheckSearchCoreStartup(gen), -80)
        return
    }
    if (Integer(gen) = Integer(g_SCWV_GoStartGen))
        g_SCWV_GoStartPhase := "START_FAILED"
    if g_SCWV_GoStartPending {
        g_SCWV_GoStartPending := false
        SetTimer(_SCWV_RunDeferredSearchCoreEnsure, -10)
    }
    if !ProcessExist("SearchCenterCore.exe")
        _SCWV_ShowSearchCoreError("SearchCenterCore 启动超时（请检查 tools\\search\\SearchCenterCore.exe）")
    return false
}

_SCWV_EnsureSearchCoreRunning() {
    global g_SCWV_GoStartPhase, g_SCWV_BackendHealthy, g_SCWV_GoStartGen
    if SCWV_FuncExists("SearchCore_IsHealthy") && SCWV_FuncExists("SearchCore_ProcessPresent")
        && SearchCore_ProcessPresent() && SearchCore_IsHealthy() {
        g_SCWV_GoStartPhase := "RUNNING"
        g_SCWV_BackendHealthy := true
        return true
    }
    if SCWV_FuncExists("SearchCore_ProcessPresent") && SearchCore_ProcessPresent() {
        g_SCWV_BackendHealthy := false
        phase := String(g_SCWV_GoStartPhase)
        if !(phase = "STARTING" || phase = "KILLING") {
            if (_SCWV_SearchCoreExePath() != "")
                _SCWV_RestartSearchCore(false)
        } else {
            g_SCWV_GoStartPhase := "PROCESS_ONLY"
        }
        return false
    }
    if (_SCWV_SearchCoreExePath() = "")
        return false
    st := 0
    if SCWV_FuncExists("SearchCore_EnsureStatus")
        st := SearchCore_EnsureStatus(false, "SCWV_ensure")
    else if SCWV_FuncExists("Nmer_StartSearchCenterCoreStatus")
        st := Nmer_StartSearchCenterCoreStatus(false, "SCWV_ensure")
    if (st is Map) {
        status := st.Has("status") ? String(st["status"]) : "failed"
        if (status = "healthy") {
            g_SCWV_GoStartPhase := "RUNNING"
            g_SCWV_BackendHealthy := true
            return true
        }
        if (status = "started") {
            g_SCWV_GoStartGen += 1
            myGen := g_SCWV_GoStartGen
            g_SCWV_GoStartPhase := "STARTING"
            SetTimer((*) => _SCWV_CheckSearchCoreStartup(myGen), -80)
            return false
        }
    }
    return _SCWV_RestartSearchCore(false)
}

_SCWV_RunDeferredSearchCoreEnsure(*) {
    _SCWV_EnsureSearchCoreRunning()
}

SCWV_GoTimeoutReset(reason := "go_phase_timeout") {
    global g_SCWV_GoResetInFlight, g_SCWV_GoStartGen, g_SCWV_GoStartPhase, g_SCWV_GoStartPending, g_SCWV_GoPhaseSinceTick
    if g_SCWV_GoResetInFlight
        return false
    g_SCWV_GoResetInFlight := true
    try {
        g_SCWV_GoStartGen += 1
        g_SCWV_GoStartPhase := "IDLE"
        g_SCWV_GoStartPending := false
        g_SCWV_GoPhaseSinceTick := A_TickCount
        SCWV_Log("go_phase_timeout_reset", "reason=" . reason . " gen=" . g_SCWV_GoStartGen)
        return true
    } finally {
        g_SCWV_GoResetInFlight := false
    }
}

SCWV_GoPhaseWatchdogTick(gen, *) {
    global g_SCWV_GoStartGen, g_SCWV_GoStartPhase, g_SCWV_GoPhaseSinceTick
    if (Integer(gen) != Integer(g_SCWV_GoStartGen))
        return
    phase := String(g_SCWV_GoStartPhase)
    if !(phase = "KILLING" || phase = "STARTING")
        return
    if ((A_TickCount - Integer(g_SCWV_GoPhaseSinceTick)) > 5000) {
        SCWV_GoTimeoutReset("watchdog_" . phase)
        return
    }
    SetTimer((*) => SCWV_GoPhaseWatchdogTick(gen), -100)
}


_SCWV_MapFilterToGoSearchType(FilterType) {
    switch FilterType {
        case "clipboard":
            return "clipboard"
        case "fulltext":
            return "fulltext"
        case "template":
            return "template"
        case "config":
            return "config"
        case "File", "file":
            return "file"
        case "hotkey":
            return "hotkey"
        case "function":
            return "function"
        case "ui":
            return "ui"
        default:
            return "all"
    }
}

_SCWV_HttpGetSearchCore(queryString) {
    ; Sync HTTP on AHK main thread is disabled on runtime hot paths.
    try _SCWV_LogRuntime("sync_path_blocked _SCWV_HttpGetSearchCore")
    return ""
}

_SCWV_WinHttpReadUtf8Text(whr) {
    if !IsObject(whr)
        return ""
    try {
        ado := ComObject("ADODB.Stream")
        ado.Type := 1  ; binary
        ado.Open()
        ado.Write(whr.ResponseBody)
        ado.Position := 0
        ado.Type := 2  ; text
        ado.Charset := "utf-8"
        txt := ado.ReadText(-1)
        ado.Close()
        return txt
    } catch {
        try return whr.ResponseText
        catch {
            return ""
        }
    }
}

; WinHttp.WinHttpRequest.5.1 无 MSXML 的 ReadyState；异步轮询用 WaitForResponse(0)（0 秒超时即返回，True 表示响应已到）。
_SCWV_WinHttpAsyncPollResponseReady(whr) {
    if !IsObject(whr)
        return Map("fatal", true, "err", "invalid whr")
    try
        return Map("fatal", false, "ready", !!whr.WaitForResponse(0))
    catch as e
        return Map("fatal", true, "err", e.Message)
}

; 返回 Map: status, body（仅 status=200 时 body 为 JSON 文本）
_SCWV_HttpGetSearchCoreResp(queryString) {
    ; Sync HTTP on AHK main thread is disabled on runtime hot paths.
    try _SCWV_LogRuntime("sync_path_blocked _SCWV_HttpGetSearchCoreResp")
    return Map("status", 0, "body", "", "responseText", "", "error", "sync_http_disabled")
}

_SCWV_HttpSearchCoreJsonRaw(method, path, body := "") {
    ; Sync HTTP on AHK main thread is disabled on runtime hot paths.
    try _SCWV_LogRuntime("sync_path_blocked _SCWV_HttpSearchCoreJsonRaw path=" . path)
    return Map("status", 0, "text", "", "json", 0, "error", "sync_http_disabled")
}

_SCWV_HttpSearchCoreJson(method, path, body := "") {
    ; Keep compatibility signature but do not run sync HTTP anymore.
    return _SCWV_HttpSearchCoreJsonRaw(method, path, body)
}

_SCWV_CoreHttpArmPoll() {
    global g_SCWV_CoreHttpPollArmed
    if g_SCWV_CoreHttpPollArmed
        return
    g_SCWV_CoreHttpPollArmed := true
    SetTimer(_SCWV_CoreHttpPollTick, 25)
}

_SCWV_HttpSearchCoreJsonAsync(method, path, body := "", callback := 0, timeoutMs := 10000) {
    global g_SCWV_CoreHttpReqSeq, g_SCWV_CoreHttpReqs
    cb := IsObject(callback) ? callback : 0
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        url := "http://127.0.0.1:8080" . path
        whr.Open(method, url, true)
        pollMs := Integer(timeoutMs)
        recvMs := 2200
        m := StrUpper(Trim(String(method)))
        if (m = "POST" && (InStr(path, "/v1/fulltext/control") || InStr(path, "/v1/fulltext/config"))) {
            recvMs := 120000
            if (pollMs < recvMs + 15000)
                pollMs := recvMs + 15000
        }
        whr.SetTimeouts(900, 900, 2200, recvMs)
        if (method = "POST" || method = "PUT" || method = "PATCH") {
            whr.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
            payload := (Trim(String(body)) = "") ? "{}" : body
            whr.Send(payload)
        } else {
            whr.Send()
        }
        g_SCWV_CoreHttpReqSeq += 1
        reqId := g_SCWV_CoreHttpReqSeq
        g_SCWV_CoreHttpReqs[reqId] := Map("whr", whr, "cb", cb, "start", A_TickCount, "timeout", pollMs)
        _SCWV_CoreHttpArmPoll()
    } catch as err {
        _SCWV_HttpSearchCoreJsonAsync_Fallback(method, path, body, cb, timeoutMs, err.Message)
    }
}

_SCWV_HttpSearchCoreJsonAsync_Fallback(method, path, body := "", cb := 0, timeoutMs := 10000, reason := "") {
    SetTimer((*) => _SCWV_HttpSearchCoreJsonFallback_Run(method, path, body, cb, timeoutMs, reason), -1)
}

_SCWV_HttpSearchCoreJsonFallback_Run(method, path, body := "", cb := 0, timeoutMs := 10000, reason := "") {
    url := "http://127.0.0.1:8080" . path
    try {
        xhr := ComObject("MSXML2.ServerXMLHTTP.6.0")
        t := Integer(timeoutMs)
        if (t <= 0)
            t := 10000
        ; resolve, connect, send, receive
        xhr.setTimeouts(900, 900, t, t)
        xhr.open(method, url, false)
        if (method = "POST" || method = "PUT" || method = "PATCH") {
            xhr.setRequestHeader("Content-Type", "application/json; charset=utf-8")
            payload := (Trim(String(body)) = "") ? "{}" : body
            xhr.send(payload)
        } else {
            xhr.send()
        }
        st := 0
        txt := ""
        obj := 0
        try st := Integer(xhr.status)
        try txt := String(xhr.responseText)
        if (Trim(String(txt)) != "") {
            try obj := Jxon_Load(txt)
        }
        if cb
            try cb.Call(Map("status", st, "text", txt, "json", obj, "fallback", "msxml"))
    } catch as e2 {
        if cb
            try cb.Call(Map("status", 0, "text", "", "json", 0, "error", (reason != "" ? reason . " | " : "") . e2.Message))
    }
}

_SCWV_CoreHttpPollTick(*) {
    global g_SCWV_CoreHttpReqs, g_SCWV_CoreHttpPollArmed
    if !(g_SCWV_CoreHttpReqs is Map) || (g_SCWV_CoreHttpReqs.Count = 0) {
        g_SCWV_CoreHttpPollArmed := false
        SetTimer(_SCWV_CoreHttpPollTick, 0)
        return
    }
    removeIds := []
    for reqId, req in g_SCWV_CoreHttpReqs {
        if !(req is Map) {
            removeIds.Push(reqId)
            continue
        }
        whr := req["whr"]
        cb := req["cb"]
        startTick := req["start"]
        timeoutMs := req["timeout"]
        if (A_TickCount - startTick > timeoutMs) {
            try whr.Abort()
            if cb
                try cb.Call(Map("status", 0, "text", "", "json", 0, "error", "timeout"))
            removeIds.Push(reqId)
            continue
        }
        pr := _SCWV_WinHttpAsyncPollResponseReady(whr)
        if pr["fatal"] {
            if cb
                try cb.Call(Map("status", 0, "text", "", "json", 0, "error", pr["err"]))
            removeIds.Push(reqId)
            continue
        }
        if !pr["ready"]
            continue
        st := 0
        txt := ""
        obj := 0
        try st := Integer(whr.Status)
        try txt := _SCWV_WinHttpReadUtf8Text(whr)
        if (Trim(String(txt)) != "") {
            try obj := Jxon_Load(txt)
        }
        if cb
            try cb.Call(Map("status", st, "text", txt, "json", obj))
        removeIds.Push(reqId)
    }
    for _, reqId in removeIds {
        try g_SCWV_CoreHttpReqs.Delete(reqId)
    }
    if (g_SCWV_CoreHttpReqs.Count = 0) {
        g_SCWV_CoreHttpPollArmed := false
        SetTimer(_SCWV_CoreHttpPollTick, 0)
    }
}

