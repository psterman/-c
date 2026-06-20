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
global CoreAsyncStrictMode := 1
global LegacySyncFallback := 1
global g_WV2_CreateQueue := []
global g_WV2_CreateBusy := false

_WV2_TraceOptional(scope, action, ok := true, meta := 0) {
    fn := "Nmer_Telemetry_Record"
    if FuncExists(fn) {
        try {
            (%fn%)(scope, action, !!ok, meta is Map ? meta : Map())
            return
        } catch as e {
            try {
                if FuncExists("NmerCatch")
                    NmerCatch(A_ThisFunc, e)
            } catch {
            }
        }
    }
    try {
        if FuncExists("Nmer_DebugPath") {
            path := Nmer_DebugPath("nmer_trace.log")
            errText := ""
            if (meta is Map) && meta.Has("error")
                errText := " error=" . meta["error"]
            FileAppend("[" . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . "][" . scope . "][" . action . "] ok="
                . (ok ? "1" : "0") . errText . "`n", path, "UTF-8")
        }
    } catch {
    }
}

WebView2_IsUsableHwnd(hwnd) {
    h := Integer(hwnd)
    if (h <= 0)
        return false
    try {
        return !!DllCall("IsWindow", "Ptr", h, "Int")
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
        return false
    }
}

WebView2_GetSharedUserDataPath() {
    return A_AppData "\CursorHelper\Wv2Data"
}

WebView2_GetScWebLlmRoot() {
    return WebView2_GetSharedUserDataPath() . "\ScWebLlm"
}

WebView2_NormalizeScWebLlmSiteId(siteId) {
    fn := "ScWebLlm_NormalizeSiteId"
    if FuncExists(fn)
        return (%fn%)(siteId)
    id := StrLower(Trim(String(siteId)))
    if (id = "")
        return ""
    if !RegExMatch(id, "^(deepseek|doubao|gemini|grok|perplexity)$")
        return ""
    return id
}

WebView2_EnsureDirPath(path, label := "") {
    p := Trim(String(path))
    if (p = "")
        return ""
    try {
        if !DirExist(p)
            DirCreate(p)
        if DirExist(p)
            return p
    } catch as e {
        try {
            if FuncExists("NmerCatch")
                NmerCatch("WebView2_EnsureDirPath", e)
        } catch {
        }
        try {
            _WV2_TraceOptional("webview2", "dir_create_fail", false, Map("path", p, "label", label, "error", e.Message))
        } catch {
        }
    }
    return ""
}

WebView2_EnsureScWebLlmSiteDataDir(siteId, outMeta := 0) {
    id := WebView2_NormalizeScWebLlmSiteId(siteId)
    if (id = "")
        return ""
    primary := WebView2_GetScWebLlmRoot() . "\" . id
    path := WebView2_EnsureDirPath(primary, "sc_web_llm_primary")
    if (path != "") {
        if (outMeta is Map)
            outMeta["tier"] := "primary"
        return path
    }
    fallback := EnvGet("TEMP") . "\NmerScWebLlm\" . id
    path := WebView2_EnsureDirPath(fallback, "sc_web_llm_temp")
    if (path != "") {
        if (outMeta is Map)
            outMeta["tier"] := "temp"
        try TrayTip("网页大模型", "配置目录不可用，已使用临时目录；登录态可能无法跨会话保留。", "Icon! 3")
        catch {
        }
        return path
    }
    return ""
}

WebView2_GetScWebLlmSiteDataPath(siteId) {
    id := WebView2_NormalizeScWebLlmSiteId(siteId)
    if (id = "")
        return ""
    return WebView2_GetScWebLlmRoot() . "\" . id
}

WebView2_CreateWithSiteDataDirAsync(hostHwnd, siteId, callback, reason := "") {
    id := WebView2_NormalizeScWebLlmSiteId(siteId)
    if (id = "") {
        try {
            if callback
                callback.Call(0)
        } catch {
        }
        return
    }
    if !WebView2_IsUsableHwnd(hostHwnd) {
        try {
            if callback
                callback.Call(0)
        } catch {
        }
        return
    }
    meta := Map()
    dataDir := WebView2_EnsureScWebLlmSiteDataDir(id, meta)
    if (dataDir = "") {
        try {
            if callback
                callback.Call(0)
        } catch {
        }
        return
    }
    opts := 0
    try {
        if IsSet(WebView2DefaultOptions) && WebView2DefaultOptions
            opts := WebView2DefaultOptions
    }
    try {
        WebView2.CreateEnvironmentAsync(opts, dataDir)
            .then((env) => _WV2_OnSiteEnvReady(hostHwnd, env, callback, reason, id))
            .catch((err) => _WV2_OnSiteEnvFailed(callback, err, reason, id))
    } catch as e {
        _WV2_OnSiteEnvFailed(callback, e, reason, id)
    }
}

_WV2_OnSiteEnvFailed(callback, err, reason := "", siteId := "") {
    try _WV2_TraceOptional("web_llm", "env_fail", false, Map("site", siteId, "reason", reason, "error", IsObject(err) ? err.Message : String(err)))
    catch {
    }
    try {
        if callback
            callback.Call(0, err)
    } catch {
    }
}

_WV2_OnSiteEnvReady(hostHwnd, env, callback, reason := "", siteId := "") {
    if !WebView2_IsUsableHwnd(hostHwnd) || !IsObject(env) {
        try {
            if callback
                callback.Call(0)
        } catch {
        }
        return
    }
    try {
        env.CreateCoreWebView2ControllerAsync(hostHwnd)
            .then((ctrl) => _WV2_OnSiteControllerReady(ctrl, callback, reason, siteId))
            .catch((err) => _WV2_OnSiteEnvFailed(callback, err, reason, siteId))
    } catch as e {
        _WV2_OnSiteEnvFailed(callback, e, reason, siteId)
    }
}

_WV2_OnSiteControllerReady(ctrl, callback, reason := "", siteId := "") {
  try {
        if IsObject(ctrl) {
            try {
                wv2 := ctrl.CoreWebView2
                if IsObject(wv2)
                    ApplyWebView2PerformanceSettings(wv2)
            } catch {
            }
        }
        if callback
            callback.Call(ctrl)
    } catch as e {
        _WV2_OnSiteEnvFailed(callback, e, reason, siteId)
    }
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
    global g_WV2SharedEnv, CoreAsyncStrictMode
    if g_WV2SharedEnv
        return g_WV2SharedEnv
    try {
        if CoreAsyncStrictMode
            NMER_AsyncLog(Nmer_DebugPath("wv2_shared_env.log"), "[" . A_Now . "][sync_blocked] WebView2_EnsureSharedEnvBlocking rejected`r`n")
    }
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try OutputDebug("[WV2] blocking shared env request rejected on hot path")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
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
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
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
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
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
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        }
        return
    }
    if !(g_WV2EnvReadyCallbacks is Array)
        g_WV2EnvReadyCallbacks := []
    g_WV2EnvReadyCallbacks.Push(onReady)
    WebView2_GetOrCreateSharedEnvPromise().then(_WV2_OnSharedEnvPromiseResolved, _WV2_OnSharedEnvPromiseRejected)
}

WebView2_IsHighPriorityCreateReason(reason := "") {
    r := StrLower(Trim(String(reason)))
    if (r = "")
        return false
    return (InStr(r, "searchcenter")
        || InStr(r, "search_center")
        || InStr(r, "command_palette")
        || InStr(r, "commandpalette"))
}

WebView2_CopyWebMessageJson(args, maxLen := 4194304) {
    s := ""
    try {
        if IsObject(args) {
            try {
                t := args.TryGetWebMessageAsString()
                if (t != "")
                    s := "" . t
            } catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
            if (s = "") {
                try {
                    if args.HasProp("WebMessageAsJson")
                        s := "" . String(args.WebMessageAsJson)
                } catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
            }
        }
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if (s = "")
        return ""
    if (maxLen > 0 && StrLen(s) > maxLen)
        s := SubStr(s, 1, maxLen)
    return s
}

WebView2_GetCreateQueueDepth() {
    global g_WV2_CreateQueue, g_WV2_CreateBusy
    depth := (g_WV2_CreateQueue is Array) ? g_WV2_CreateQueue.Length : 0
    if g_WV2_CreateBusy
        depth += 1
    return depth
}

; 强制宿主 HWND 走一遍 DWM 合成（截图/截屏会隐式触发同类刷新，首屏未合成时可主动调用）
WebView2_ForceHostRedraw(hwnd) {
    h := Integer(hwnd)
    if (h <= 0)
        return
    if !WebView2_IsUsableHwnd(h)
        return
    ; UpdateWindow 在 HWND 销毁竞态时会触发 Invalid memory read/write，try 无法捕获
    redrawFlags := 0x105 ; RDW_INVALIDATE | RDW_UPDATENOW | RDW_ERASE
    try {
        if !DllCall("IsWindow", "Ptr", h, "Int")
            return
        DllCall("RedrawWindow", "Ptr", h, "Ptr", 0, "Ptr", 0, "UInt", redrawFlags)
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
        return
    }
    try {
        if !DllCall("IsWindow", "Ptr", h, "Int")
            return
        DllCall("SetWindowPos", "Ptr", h, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0037)
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
}

WebView2_CreateWithSharedEnvAsync(hwnd, callback, reason := "") {
    global g_WV2_CreateQueue
    if !(g_WV2_CreateQueue is Array)
        g_WV2_CreateQueue := []
    item := Map("hwnd", hwnd, "cb", callback, "reason", String(reason))
    if WebView2_IsHighPriorityCreateReason(reason)
        g_WV2_CreateQueue.InsertAt(1, item)
    else
        g_WV2_CreateQueue.Push(item)
    try NMER_AsyncLog(Nmer_DebugPath("wv2_shared_env.log"), "[" . A_Now . "][create_enqueue] reason=" . String(reason) . " qlen=" . g_WV2_CreateQueue.Length . " pri=" . (WebView2_IsHighPriorityCreateReason(reason) ? "1" : "0") . "`r`n")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    WebView2_DrainCreateQueue()
}

WebView2_DrainCreateQueue(*) {
    global g_WV2_CreateQueue, g_WV2_CreateBusy
    if g_WV2_CreateBusy
        return
    if !(g_WV2_CreateQueue is Array) || g_WV2_CreateQueue.Length = 0
        return
    g_WV2_CreateBusy := true
    item := g_WV2_CreateQueue.RemoveAt(1)
    hwnd := item["hwnd"]
    cb := item["cb"]
    reason := item.Has("reason") ? item["reason"] : ""
    wrappedCb := (ctrl) => _WV2_OnCreateQueueItemDone(ctrl, cb, reason)
    WebView2_OnSharedEnvReady((env, err := 0) => _WV2_CreateWithSharedEnvReady(hwnd, wrappedCb, reason, env, err))
}

_WV2_OnCreateQueueItemDone(ctrl, cb, reason) {
    global g_WV2_CreateBusy
    try {
        if cb
            cb.Call(ctrl)
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    } finally {
        g_WV2_CreateBusy := false
        try NMER_AsyncLog(Nmer_DebugPath("wv2_shared_env.log"), "[" . A_Now . "][create_done] reason=" . String(reason) . "`r`n")
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        SetTimer(WebView2_DrainCreateQueue, -1)
    }
}

; 脚本 Reload / 硬重启前调用，避免旧 Environment 与新建 WebView 竞态触发 0x8007139F
WebView2_PrepareForScriptReload() {
    global g_WV2SharedEnv, g_WV2EnvCreatePromise, g_WV2EnvReadyCallbacks
    global g_WV2EnvCreateFailed, g_WV2EnvCreateError
    try {
        if FuncExists("Nmer_WailsBridgePrepareForScriptReload")
            Nmer_WailsBridgePrepareForScriptReload()
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try {
        if FuncExists("NiumaMobileBrowser_PrepareForScriptReload")
            NiumaMobileBrowser_PrepareForScriptReload()
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try {
        if FuncExists("ScWebEmbedProbePrepareForScriptReload")
            ScWebEmbedProbePrepareForScriptReload()
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try {
        if FuncExists("SearchCenterWebLlm_PrepareForScriptReload")
            SearchCenterWebLlm_PrepareForScriptReload()
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    WebView2_ResetSharedEnvState()
    try OutputDebug("[WV2] PrepareForScriptReload: shared env reset")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

; 托盘/热键干净重启：仅停定时器并重置共享环境指针，勿同步 Close 多路 WebView（会卡死重启）
WebView2_PrepareForCleanExit() {
    try {
        if FuncExists("Nmer_WailsBridgePrepareForScriptReload")
            Nmer_WailsBridgePrepareForScriptReload()
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    WebView2_ResetSharedEnvState()
    try OutputDebug("[WV2] PrepareForCleanExit: shared env reset")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

WebView2_ResetSharedEnvState() {
    global g_WV2SharedEnv, g_WV2EnvCreatePromise, g_WV2EnvReadyCallbacks
    global g_WV2EnvCreateFailed, g_WV2EnvCreateError
    global g_WV2_CreateQueue, g_WV2_CreateBusy
    g_WV2SharedEnv := 0
    g_WV2EnvCreatePromise := 0
    g_WV2EnvReadyCallbacks := []
    g_WV2EnvCreateFailed := false
    g_WV2EnvCreateError := ""
    g_WV2_CreateQueue := []
    g_WV2_CreateBusy := false
}

_WV2_CreateWithSharedEnvReady(hwnd, callback, reason, env, err := 0) {
    if !WebView2_IsUsableHwnd(hwnd) {
        try OutputDebug("[WV2] create skipped invalid hwnd reason=" . reason . " hwnd=" . hwnd)
        catch as _e {
            NmerCatch(A_ThisFunc, _e)
        }
        try callback.Call(0)
        catch as _e {
            NmerCatch(A_ThisFunc, _e)
        }
        return
    }
    if err || !env {
        try OutputDebug("[WV2] shared env failed reason=" . reason)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        try callback.Call(err ? err : 0)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        return
    }
    try WebView2.create(hwnd, callback, env)
    catch as e {
        ; 句柄在异步创建窗口控制器期间失效时，降级为忽略，避免脚本级崩溃。
        if !WebView2_IsUsableHwnd(hwnd) {
            try OutputDebug("[WV2] create failed after hwnd invalidated reason=" . reason . " hwnd=" . hwnd)
            catch as _e {
                NmerCatch(A_ThisFunc, _e)
            }
            try callback.Call(0)
            catch as _e {
                NmerCatch(A_ThisFunc, _e)
            }
            return
        }
        try callback.Call(e)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
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
    try wv2.PostWebMessageAsJson('{"type":"hostPaintNudge","reason":"notify_shown"}')
    catch as e {
        try OutputDebug("[WV2] NotifyShown hostPaintNudge: " . e.Message)
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
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
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
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
}
