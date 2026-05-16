; ======================================================================================================================
; WebView2SharedEnv.ahk — 全局共享 WebView2 Environment、内存挂起辅助、统一性能相关 Settings
; 依赖：lib\WebView2.ahk（须先 #Include）、全局 WebView2DefaultOptions（可选）
; ======================================================================================================================

#Requires AutoHotkey v2.0

global g_WV2SharedEnv := 0
global g_WV2EnvCreatePromise := 0
global g_WV2EnvReadyCallbacks := []
global g_WV2EnvCreateFailed := false
global g_WV2EnvCreateError := ""

WebView2_GetSharedUserDataPath() {
    return A_AppData "\CursorHelper\Wv2Data"
}

WebView2_GetOrCreateSharedEnvPromise() {
    global g_WV2EnvCreatePromise, WebView2DefaultOptions
    if !g_WV2EnvCreatePromise {
        dataDir := WebView2_GetSharedUserDataPath()
        if !DirExist(dataDir)
            DirCreate(dataDir)
        opts := 0
        try {
            if IsSet(WebView2DefaultOptions) && WebView2DefaultOptions
                opts := WebView2DefaultOptions
        }
        g_WV2EnvCreatePromise := WebView2.CreateEnvironmentAsync(opts, dataDir)
    }
    return g_WV2EnvCreatePromise
}

WebView2_EnsureSharedEnvBlocking() {
    global g_WV2SharedEnv
    if g_WV2SharedEnv
        return g_WV2SharedEnv
    try OutputDebug("[WV2] blocking shared env request rejected on hot path")
    catch {
    }
    return 0
}

; .then 回调不能使用 env => { ... }：`{` 会被解析为对象字面量而非代码块（AHK v2）。
global g_WV2_OnSharedEnvReadyCallback := 0

_WV2_OnSharedEnvPromiseResolved(env) {
    global g_WV2SharedEnv, g_WV2EnvReadyCallbacks, g_WV2EnvCreateFailed, g_WV2EnvCreateError
    g_WV2SharedEnv := env
    g_WV2EnvCreateFailed := false
    g_WV2EnvCreateError := ""
    callbacks := g_WV2EnvReadyCallbacks
    g_WV2EnvReadyCallbacks := []
    for _, cb in callbacks {
        try cb.Call(env, 0)
        catch {
            try cb.Call()
            catch {
            }
        }
    }
}

_WV2_OnSharedEnvPromiseRejected(err) {
    global g_WV2EnvCreatePromise, g_WV2EnvReadyCallbacks, g_WV2EnvCreateFailed, g_WV2EnvCreateError
    g_WV2EnvCreatePromise := 0
    g_WV2EnvCreateFailed := true
    try g_WV2EnvCreateError := err.Message
    catch {
        g_WV2EnvCreateError := String(err)
    }
    callbacks := g_WV2EnvReadyCallbacks
    g_WV2EnvReadyCallbacks := []
    for _, cb in callbacks {
        try cb.Call(0, err)
        catch {
            try cb.Call()
            catch {
            }
        }
    }
}

WebView2_InitSharedEnvAsync(onReady?) {
    if IsSet(onReady)
        WebView2_OnSharedEnvReady(onReady)
    else
        WebView2_OnSharedEnvReady()
}

WebView2_OnSharedEnvReady(onReady?) {
    global g_WV2SharedEnv, g_WV2EnvReadyCallbacks
    if !IsSet(onReady) || !onReady
        return
    if g_WV2SharedEnv {
        try onReady.Call(g_WV2SharedEnv, 0)
        catch {
            try onReady.Call()
            catch {
            }
        }
        return
    }
    if !(g_WV2EnvReadyCallbacks is Array)
        g_WV2EnvReadyCallbacks := []
    g_WV2EnvReadyCallbacks.Push(onReady)
    WebView2_GetOrCreateSharedEnvPromise().then(_WV2_OnSharedEnvPromiseResolved, _WV2_OnSharedEnvPromiseRejected)
}

WebView2_CreateWithSharedEnvAsync(hwnd, callback, reason := "") {
    WebView2_OnSharedEnvReady((env, err := 0) => _WV2_CreateWithSharedEnvReady(hwnd, callback, reason, env, err))
}

_WV2_CreateWithSharedEnvReady(hwnd, callback, reason, env, err := 0) {
    if err || !env {
        try OutputDebug("[WV2] shared env failed reason=" . reason)
        catch {
        }
        try callback.Call(err ? err : 0)
        catch {
        }
        return
    }
    try WebView2.create(hwnd, callback, env)
    catch as e {
        try callback.Call(e)
        catch {
        }
    }
}

ApplyWebView2PerformanceSettings(wv2) {
    if !wv2
        return
    try {
        s := wv2.Settings
        s.IsStatusBarEnabled := false
        s.IsPasswordAutosaveEnabled := false
        s.IsGeneralAutofillEnabled := false
    } catch as e {
        try OutputDebug("[WV2] ApplyWebView2PerformanceSettings: " . e.Message)
    }
}

WebView2_NotifyHidden(wv2) {
    if !wv2
        return
    try wv2.PostWebMessageAsJson('{"type":"RESET_STATE"}')
    catch as e {
        try OutputDebug("[WV2] NotifyHidden PostWebMessage: " . e.Message)
    }
    try wv2.MemoryUsageTargetLevel := 1
    catch as e {
        try OutputDebug("[WV2] NotifyHidden MemoryUsageTargetLevel: " . e.Message)
    }
}

WebView2_NotifyShown(wv2) {
    if !wv2
        return
    try wv2.MemoryUsageTargetLevel := 0
    catch as e {
        try OutputDebug("[WV2] NotifyShown MemoryUsageTargetLevel: " . e.Message)
    }
}

global g_NMER_AsyncLogQueues := Map()
global g_NMER_AsyncLogTimerArmed := false

NMER_AsyncLog(logPath, line) {
    global g_NMER_AsyncLogQueues, g_NMER_AsyncLogTimerArmed
    try {
        p := String(logPath)
        if (p = "")
            return
        if !(g_NMER_AsyncLogQueues is Map)
            g_NMER_AsyncLogQueues := Map()
        if !g_NMER_AsyncLogQueues.Has(p)
            g_NMER_AsyncLogQueues[p] := []
        q := g_NMER_AsyncLogQueues[p]
        q.Push(String(line))
        if (q.Length >= 64) {
            SetTimer(NMER_AsyncLogFlush, 0)
            g_NMER_AsyncLogTimerArmed := false
            NMER_AsyncLogFlush()
            return
        }
        if !g_NMER_AsyncLogTimerArmed {
            g_NMER_AsyncLogTimerArmed := true
            SetTimer(NMER_AsyncLogFlush, -250)
        }
    } catch {
    }
}

NMER_AsyncLogFlush(*) {
    global g_NMER_AsyncLogQueues, g_NMER_AsyncLogTimerArmed
    g_NMER_AsyncLogTimerArmed := false
    if !(g_NMER_AsyncLogQueues is Map)
        return
    queues := g_NMER_AsyncLogQueues
    g_NMER_AsyncLogQueues := Map()
    for p, q in queues {
        if !(q is Array) || q.Length = 0
            continue
        try {
            dir := ""
            SplitPath(p, , &dir)
            if (dir != "" && !DirExist(dir))
                DirCreate(dir)
            buf := ""
            for _, line in q
                buf .= line
            FileAppend(buf, p, "UTF-8")
        } catch {
        }
    }
}
