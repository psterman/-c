; ======================================================================================================================
; NiumaMobileBrowser.ahk — Niuma Chat 内置手机浏览器（独立 WebView2 Environment / UserData）
; ======================================================================================================================

#Requires AutoHotkey v2.0

global g_NiumaMobile_Env := 0
global g_NiumaMobile_Ctrl := 0
global g_NiumaMobile_WV2 := 0
global g_NiumaMobile_Open := false
global g_NiumaMobile_PendingOpen := false
global g_NiumaMobile_OpenInProgress := false
global g_NiumaMobile_PendingUrl := ""
global NIUMA_MOBILE_DEFAULT_URL := "https://www.baidu.com"
global g_NiumaMobile_LastKnownUrl := ""
global g_NiumaMobile_ParentHwnd := 0
global g_NiumaMobile_TokenNav := 0
global g_NiumaMobile_TokenNavStart := 0
global g_NiumaMobile_TokenNewWin := 0
global g_NiumaMobile_TokenMsg := 0
global JS_MOBILE_SETTLE := ""
global g_NiumaMobile_SettlePending := false
global g_NiumaMobile_SettleNavPending := false
global g_NiumaMobile_SettleReqId := ""
global g_NiumaMobile_SettleWatchdog := 0
global g_NiumaMobile_Jobs := Map()
global g_NiumaMobile_JobCounter := 0
global g_NiumaMobile_WidthLogical := 430
; 主 Chat WebView（由 FloatingToolbar.ahk 赋值；此处仅声明供本模块引用）
global g_FTB_WV2 := 0
global g_NiumaMobile_Wv2Class := 0
global JS_MOBILE_LABELING := ""
global JS_MOBILE_CLICK_BY_ID := ""
global JS_MOBILE_INPUT_BY_ID := ""
global JS_MOBILE_DOUBAO_CHAT := ""
global JS_MOBILE_DOUBAO_FOCUS := ""
global JS_MOBILE_DOUBAO_VERIFY_SEND := ""
global JS_MOBILE_DOUBAO_FILL_LABEL := ""
global JS_MOBILE_DOUBAO_ACTIVATE := ""
global JS_MOBILE_REACT_INPUT := ""
global JS_MOBILE_ELEMENT_CENTER := ""
global JS_MOBILE_SCROLL := ""
global JS_MOBILE_RESOLVE := ""
global JS_MOBILE_TRACE_OVERLAY := ""
global g_NiumaMobile_LastActInputText := ""
global g_NiumaMobile_LabelRefreshTimer := 0
global g_NiumaMobile_LastSnapshot := []
global g_NiumaMobile_LastElementsJson := "[]"
global g_NiumaMobile_LastElementsCount := 0
global g_NiumaMobile_LastSnapshotJson := ""
global g_NiumaMobile_AiBusy := false
global g_NiumaMobile_AiPaused := false
global g_NiumaMobile_LabelDebug := true
global g_NiumaMobile_LabelAutoHideTimer := 0
global g_NiumaMobile_LabelAutoHidePass := 0
global g_NiumaMobile_LabelAutoHideChatText := ""
global g_NiumaMobile_PendingAnalyzeCb := 0
global g_NiumaMobile_PendingActCb := 0
global g_NiumaMobile_SilentRefresh := false
global g_NiumaMobile_ObserveReqId := ""
global g_NiumaMobile_ActReqId := ""
global g_NiumaMobile_ForceDoubaoInput := false
global g_NiumaMobile_ChatSendOnly := false
global g_NiumaMobile_DeepseekJsFillOnly := false
global g_NiumaMobile_GeminiJsFillOnly := false
global g_NiumaMobile_ChatPlanActive := false
global g_NiumaMobile_ChatPlanPlatform := ""
global JS_MOBILE_CHAT_THREAD_CHECK := ""
global g_NiumaMobile_SendGateActive := false
global g_NiumaMobile_SendGateReqId := ""
global g_NiumaMobile_SendGatePendingObserveReqId := ""
global g_NiumaMobile_ThreadCheckInjected := false
global g_NiumaMobile_NavigateAckReqId := ""
global g_NiumaMobile_NavigateAckAction := ""
global g_NiumaMobile_NavigateWatchdogActive := false
global g_NiumaMobile_NavigateCoreEventFired := Map()
global g_NiumaMobile_AnalyzeWatchdog := 0
global g_NiumaMobile_SnapshotRetryReqId := ""
global g_NiumaMobile_SnapshotRetryCount := 0
global g_NiumaMobile_ObserveOpenWaitPass := 0
global NIUMA_MOBILE_MODULE_DIR := ""
global NIUMA_MOBILE_SNAPSHOT_DEBUG_LOG := A_ScriptDir . "\Cache\niuma_mobile_snapshot_debug.log"

NiumaMobileBrowser_Log(prefix, reqId, msg) {
    global NIUMA_MOBILE_SNAPSHOT_DEBUG_LOG
    rid := Trim(String(reqId))
    if (rid = "")
        rid := "-"
    line := "[" . A_Now . "] [" . prefix . "] [ReqId: " . rid . "] " . String(msg) . "`r`n"
    try {
        dir := A_ScriptDir . "\Cache"
        if !DirExist(dir)
            DirCreate(dir)
        FileAppend(line, NIUMA_MOBILE_SNAPSHOT_DEBUG_LOG, "UTF-8")
    } catch {
    }
}

NiumaMobileBrowser_NormalizeStage(stage) {
    st := StrLower(Trim(String(stage)))
    if (st = "settle_inject" || st = "inject")
        return "inject"
    if (st = "click")
        return "action_click"
    if (st = "input")
        return "action_input"
    if (st = "settle_start" || st = "settle")
        return "settle"
    if (st = "analyze" || st = "label" || st = "labeling")
        return "label"
    return st != "" ? st : "unknown"
}

NIUMA_MOBILE_UA := "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"

NIUMA_MOBILE_INJECT_JS := "(function(){try{var s=document.createElement('style');s.textContent='.download-app-banner,.open-in-app,[class*=download-app],[id*=download-app]{display:none!important} body{overflow:auto!important}';document.head.appendChild(s);}catch(e){}try{if(!window.__NIUMA_NET__){var net={active:0,lastChange:Date.now()};function nt(){net.lastChange=Date.now()}function inc(){net.active++;nt()}function dec(){if(net.active>0)net.active--;nt()}var of=window.fetch;if(typeof of==='function'){window.fetch=function(){inc();try{return of.apply(this,arguments).finally(dec)}catch(ex){dec();throw ex}}}var xo=XMLHttpRequest.prototype.open,xs=XMLHttpRequest.prototype.send;XMLHttpRequest.prototype.open=function(){this.__niuma_xhr__=true;return xo.apply(this,arguments)};XMLHttpRequest.prototype.send=function(){if(this.__niuma_xhr__){inc();var self=this;function d(){dec()}this.addEventListener('loadend',d,{once:true});this.addEventListener('error',d,{once:true});this.addEventListener('abort',d,{once:true})}return xs.apply(this,arguments)};window.__NIUMA_NET__=net}}catch(e2){}})();"

JS_MOBILE_TOGGLE_DEBUG := "(function(){try{window.__NIUMA_LABEL_DEBUG__=!window.__NIUMA_LABEL_DEBUG__;if(!window.__NIUMA_LABEL_DEBUG__){var r=document.getElementById('niuma-mobile-label-root');if(r)r.remove();var els=document.querySelectorAll('.niuma-label-badge');for(var i=0;i<els.length;i++)els[i].remove();}return JSON.stringify({ok:true,debug:!!window.__NIUMA_LABEL_DEBUG__});}catch(e){return JSON.stringify({ok:false,error:String(e)});}})();"

JS_MOBILE_SET_INPUT_BLOCK := "(function(){try{document.documentElement.style.pointerEvents='';var r=document.getElementById('niuma-mobile-label-root');if(r)r.style.pointerEvents=__NIUMA_BLOCK__?'none':'';return JSON.stringify({ok:true});}catch(e){return JSON.stringify({ok:false});}})();"

class NiumaMobile_RECT extends Buffer {
    __New() => super.__New(16)
    left {
        get => NumGet(this, 'int')
        set => NumPut('int', Value, this)
    }
    top {
        get => NumGet(this, 4, 'int')
        set => NumPut('int', Value, this, 4)
    }
    right {
        get => NumGet(this, 8, 'int')
        set => NumPut('int', Value, this, 8)
    }
    bottom {
        get => NumGet(this, 12, 'int')
        set => NumPut('int', Value, this, 12)
    }
}

NiumaMobileBrowser_ModuleDir() {
    global NIUMA_MOBILE_MODULE_DIR
    if (NIUMA_MOBILE_MODULE_DIR != "" && FileExist(NIUMA_MOBILE_MODULE_DIR . "niuma_mobile_labeling.js"))
        return NIUMA_MOBILE_MODULE_DIR
    dir := RegExReplace(A_LineFile, "\\[^\\]+$", "")
    if FileExist(dir . "niuma_mobile_labeling.js") {
        NIUMA_MOBILE_MODULE_DIR := dir
        return dir
    }
    dir2 := A_ScriptDir . "\modules\"
    if FileExist(dir2 . "niuma_mobile_labeling.js") {
        NIUMA_MOBILE_MODULE_DIR := dir2
        return dir2
    }
    NIUMA_MOBILE_MODULE_DIR := dir
    return dir
}

NiumaMobileBrowser_LoadScriptFile(name, &out) {
    path := NiumaMobileBrowser_ModuleDir() . name
    if !FileExist(path) {
        try OutputDebug("[NiumaMobile] missing script: " . path)
        catch {
        }
        return false
    }
    try {
        out := Trim(FileRead(path, "UTF-8"), "`r`n `t")
        return out != ""
    } catch {
        return false
    }
}

NiumaMobileBrowser_EnsureLabelScripts() {
    global JS_MOBILE_LABELING, JS_MOBILE_CLICK_BY_ID, JS_MOBILE_INPUT_BY_ID, JS_MOBILE_DOUBAO_CHAT, JS_MOBILE_DOUBAO_FOCUS, JS_MOBILE_DOUBAO_VERIFY_SEND, JS_MOBILE_DOUBAO_FILL_LABEL, JS_MOBILE_DOUBAO_ACTIVATE, JS_MOBILE_REACT_INPUT, JS_MOBILE_ELEMENT_CENTER, JS_MOBILE_SETTLE, JS_MOBILE_SCROLL, JS_MOBILE_RESOLVE, JS_MOBILE_TRACE_OVERLAY, JS_MOBILE_CHAT_THREAD_CHECK
    ok := true
    NiumaMobileBrowser_Log("GUARD", "", "脚本自检开始 dir=" . NiumaMobileBrowser_ModuleDir())
    if (JS_MOBILE_LABELING = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_labeling.js", &JS_MOBILE_LABELING) && ok
    if (JS_MOBILE_CLICK_BY_ID = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_click.js", &JS_MOBILE_CLICK_BY_ID) && ok
    if (JS_MOBILE_INPUT_BY_ID = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_input.js", &JS_MOBILE_INPUT_BY_ID) && ok
    if (JS_MOBILE_REACT_INPUT = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_react_input.js", &JS_MOBILE_REACT_INPUT) && ok
    if (JS_MOBILE_ELEMENT_CENTER = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_element_center.js", &JS_MOBILE_ELEMENT_CENTER) && ok
    if (JS_MOBILE_DOUBAO_CHAT = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_doubao_chat.js", &JS_MOBILE_DOUBAO_CHAT) && ok
    if (JS_MOBILE_DOUBAO_FOCUS = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_doubao_focus.js", &JS_MOBILE_DOUBAO_FOCUS) && ok
    if (JS_MOBILE_DOUBAO_VERIFY_SEND = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_doubao_verify_send.js", &JS_MOBILE_DOUBAO_VERIFY_SEND) && ok
    if (JS_MOBILE_DOUBAO_FILL_LABEL = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_doubao_fill_label.js", &JS_MOBILE_DOUBAO_FILL_LABEL) && ok
    if (JS_MOBILE_DOUBAO_ACTIVATE = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_doubao_activate.js", &JS_MOBILE_DOUBAO_ACTIVATE) && ok
    if (JS_MOBILE_SETTLE = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_settle.js", &JS_MOBILE_SETTLE) && ok
    if (JS_MOBILE_SCROLL = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_scroll.js", &JS_MOBILE_SCROLL) && ok
    if (JS_MOBILE_RESOLVE = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_resolve.js", &JS_MOBILE_RESOLVE) && ok
    if (JS_MOBILE_TRACE_OVERLAY = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_trace_overlay.js", &JS_MOBILE_TRACE_OVERLAY) && ok
    if (JS_MOBILE_CHAT_THREAD_CHECK = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_chat_thread_check.js", &JS_MOBILE_CHAT_THREAD_CHECK) && ok
    lenLabel := StrLen(JS_MOBILE_LABELING)
    lenClick := StrLen(JS_MOBILE_CLICK_BY_ID)
    lenInput := StrLen(JS_MOBILE_INPUT_BY_ID)
    lenReact := StrLen(JS_MOBILE_REACT_INPUT)
    lenSettle := StrLen(JS_MOBILE_SETTLE)
    lenScroll := StrLen(JS_MOBILE_SCROLL)
    lenResolve := StrLen(JS_MOBILE_RESOLVE)
    lenTrace := StrLen(JS_MOBILE_TRACE_OVERLAY)
    NiumaMobileBrowser_Log("GUARD", "", "LabelLen=" . lenLabel . " ClickLen=" . lenClick . " InputLen=" . lenInput . " ReactInputLen=" . lenReact . " SettleLen=" . lenSettle)
    if !ok {
        NiumaMobileBrowser_Log("GUARD", "", "脚本自检失败：文件缺失")
        return false
    }
    if (lenLabel < 500)
        NiumaMobileBrowser_Log("GUARD", "", "警告：labeling 脚本偏短 len=" . lenLabel)
    if (lenSettle < 200)
        NiumaMobileBrowser_Log("GUARD", "", "警告：settle 脚本偏短 len=" . lenSettle)
    if (lenScroll < 200)
        NiumaMobileBrowser_Log("GUARD", "", "警告：scroll 脚本偏短 len=" . lenScroll)
    if (lenResolve < 200)
        NiumaMobileBrowser_Log("GUARD", "", "警告：resolve 脚本偏短 len=" . lenResolve)
    if (lenTrace < 200)
        NiumaMobileBrowser_Log("GUARD", "", "警告：trace overlay 脚本偏短 len=" . lenTrace)
    NiumaMobileBrowser_Log("GUARD", "", "脚本自检通过")
    return true
}

NiumaMobileBrowser_EnsureLabelScript() {
    return NiumaMobileBrowser_EnsureLabelScripts()
}

NiumaMobileBrowser_CallFunc(fnName, params*) {
    try
        return Func(fnName).Call(params*)
    catch {
        return ""
    }
}

; 动作结果序列化：固定 true/false 字面量（Jxon_Dump 在 AHK v2 会把布尔写成 1/0，导致 ParseScriptJson 失败）
NiumaMobileBrowser_DumpActParsed(parsed, fallback := "") {
    if !(parsed is Map)
        return fallback != "" ? fallback : '{"ok":false,"error":"invalid_parsed"}'
    ok := (parsed.Has("sendOk") && !!parsed["sendOk"]) || (parsed.Has("sentInThread") && !!parsed["sentInThread"])
        || (parsed.Has("domAssertOk") && !!parsed["domAssertOk"]) || (parsed.Has("idempotentSkip") && !!parsed["idempotentSkip"])
        || (parsed.Has("ok") && !!parsed["ok"])
    return '{"ok":' . (ok ? "true" : "false") . NiumaMobileBrowser_BuildActExtraJson(parsed) . "}"
}

NiumaMobileBrowser_NormalizeActBoolMap(m) {
    if !(m is Map)
        return m
    for key in ["ok", "inputOk", "sendOk", "sentInThread", "sendClicked", "submitted", "deferred", "chatSubmit", "idempotentSkip", "domAssertOk"] {
        if m.Has(key) {
            v := m[key]
            if (v is Integer) || (v is Float)
                m[key] := !!v
        }
    }
    return m
}

NiumaMobileBrowser_TryCallFunc(fnName, params*) {
    try {
        Func(fnName).Call(params*)
        return true
    } catch {
        return false
    }
}

NiumaMobileBrowser_FuncExists(fnName) {
    try {
        Func(fnName)
        return true
    } catch {
        return false
    }
}

NiumaMobileBrowser_Wv2Class() {
    global g_NiumaMobile_Wv2Class
    return IsObject(g_NiumaMobile_Wv2Class) ? g_NiumaMobile_Wv2Class : 0
}

NiumaMobileBrowser_ChatWv2() {
    ; 优先通过 FloatingToolbar 模块提供的 getter（可在重建时返回最新实例）
    try {
        wv2 := Func("FloatingToolbar_GetChatWv2").Call()
        if IsObject(wv2)
            return wv2
    } catch {
    }
    ; 兜底回退：使用全局 g_FTB_WV2（同一脚本进程共享），并在日志里记录
    global g_FTB_WV2
    if IsObject(g_FTB_WV2)
        return g_FTB_WV2
    return 0
}

NiumaMobileBrowser_GetDataPath() {
    p := A_AppData . "\CursorHelper\Wv2Data\NiumaMobile"
    if !DirExist(p)
        DirCreate(p)
    return p
}

NiumaMobileBrowser_LogicalWidth() {
    global g_NiumaMobile_WidthLogical
    w := Integer(g_NiumaMobile_WidthLogical)
    if (w < 390)
        w := 390
    if (w > 520)
        w := 520
    return w
}

NiumaMobileBrowser_WidthPx() {
    eff := 1.0
    r := NiumaMobileBrowser_CallFunc("FloatingToolbar_EffectiveScale")
    if IsNumber(r) && r > 0.01
        eff := r
    px := Max(360, Round(NiumaMobileBrowser_LogicalWidth() * eff))
    return px
}

NiumaMobileBrowser_IsOpen() {
    global g_NiumaMobile_Open, g_NiumaMobile_Ctrl
    return !!(g_NiumaMobile_Open && g_NiumaMobile_Ctrl)
}

NiumaMobileBrowser_IsActive() {
    global g_NiumaMobile_PendingOpen
    return NiumaMobileBrowser_IsOpen() || g_NiumaMobile_PendingOpen
}

NiumaMobileBrowser_SetPendingOpen(on) {
    global g_NiumaMobile_PendingOpen
    g_NiumaMobile_PendingOpen := !!on
}

NiumaMobileBrowser_NormalizeUrl(url) {
    global NIUMA_MOBILE_DEFAULT_URL
    u := Trim(String(url))
    if (u = "")
        return NIUMA_MOBILE_DEFAULT_URL
    if !NiumaMobileBrowser_IsSafeHttpUrl(u)
        return NIUMA_MOBILE_DEFAULT_URL
    return u
}

NiumaMobileBrowser_IsSafeHttpUrl(url) {
    u := Trim(String(url))
    if (u = "")
        return false
    low := StrLower(u)
    if !(InStr(low, "http://") = 1 || InStr(low, "https://") = 1)
        return false
    if InStr(low, "javascript:") || InStr(low, "data:") || InStr(low, "vbscript:")
        return false
    return true
}

NiumaMobileBrowser_OpenFail(msg) {
    global g_NiumaMobile_OpenInProgress
    g_NiumaMobile_OpenInProgress := false
    NiumaMobileBrowser_SetPendingOpen(false)
    NiumaMobileBrowser_TryCallFunc("FloatingToolbar_AfterMobileBrowserClose")
    NiumaMobileBrowser_NotifyError(msg)
}

NiumaMobileBrowser_Open(hwndParent, url := "") {
    global g_NiumaMobile_PendingUrl, g_NiumaMobile_ParentHwnd, g_NiumaMobile_OpenInProgress
    if !hwndParent {
        NiumaMobileBrowser_Log("GUARD", "", "OPEN abort: hwndParent 为空")
        return false
    }
    g_NiumaMobile_ParentHwnd := hwndParent
    u := NiumaMobileBrowser_NormalizeUrl(url)
    g_NiumaMobile_PendingUrl := u

    if NiumaMobileBrowser_IsOpen() {
        global g_NiumaMobile_WV2
        try g_NiumaMobile_WV2.Navigate(u)
        NiumaMobileBrowser_NotifyState(true, u)
        NiumaMobileBrowser_Log("GUARD", "", "OPEN reuse 已打开，Navigate " . u)
        return true
    }

    wv2cls := NiumaMobileBrowser_Wv2Class()
    if !IsObject(wv2cls) {
        NiumaMobileBrowser_OpenFail("WebView2 未就绪，请先打开 NiuMa Chat 主界面")
        NiumaMobileBrowser_Log("GUARD", "", "OPEN abort: WebView2 类未注入")
        return false
    }

    if g_NiumaMobile_OpenInProgress {
        NiumaMobileBrowser_Log("GUARD", "", "OPEN skip: 已在后台创建中")
        return true
    }
    g_NiumaMobile_OpenInProgress := true
    NiumaMobileBrowser_SetPendingOpen(true)
    NiumaMobileBrowser_Log("GUARD", "", "OPEN defer worker hwnd=" . hwndParent . " url=" . u)
    SetTimer(NiumaMobileBrowser_OpenWorker.Bind(hwndParent, u), -1)
    return true
}

NiumaMobileBrowser_OpenWorker(hwndParent, url, *) {
    global g_NiumaMobile_OpenInProgress
    NiumaMobileBrowser_Log("GUARD", "", "OPEN worker 开始 env+controller")
    wv2cls := NiumaMobileBrowser_Wv2Class()
    if !IsObject(wv2cls) {
        NiumaMobileBrowser_OpenFail("WebView2 未就绪，请先打开 NiuMa Chat 主界面")
        return
    }
    dataDir := NiumaMobileBrowser_GetDataPath()
    ; 避免 await 阻塞导致回调无法触发：全链路 Promise.then/catch
    try {
        wv2cls.CreateEnvironmentAsync(0, dataDir)
            .then((env) => (
                NiumaMobileBrowser_Log("GUARD", "", "OPEN worker Environment 就绪 dataDir=" . dataDir),
                NiumaMobileBrowser_OnEnvReady(hwndParent, env)
            ))
            .catch((e) => (
                NiumaMobileBrowser_Log("GUARD", "", "OPEN worker Environment 失败: " . (IsObject(e) ? e.Message : String(e))),
                NiumaMobileBrowser_OpenFail("手机浏览器启动失败: " . (IsObject(e) ? e.Message : String(e)))
            ))
    } catch as e2 {
        NiumaMobileBrowser_Log("GUARD", "", "OPEN worker Environment 异常: " . e2.Message)
        NiumaMobileBrowser_OpenFail("手机浏览器启动失败: " . e2.Message)
    }
}

NiumaMobileBrowser_Navigate(url) {
    u := NiumaMobileBrowser_NormalizeUrl(url)
    if NiumaMobileBrowser_IsOpen() {
        global g_NiumaMobile_WV2
        try g_NiumaMobile_WV2.Navigate(u)
        NiumaMobileBrowser_NotifyState(true, u)
        return true
    }
    global g_NiumaMobile_ParentHwnd
    hwnd := NiumaMobileBrowser_CallFunc("FloatingToolbar_GetGuiHwnd")
    if !hwnd
        hwnd := g_NiumaMobile_ParentHwnd
    if hwnd
        return NiumaMobileBrowser_Open(hwnd, u)
    return false
}

NiumaMobileBrowser_NotifyError(msg) {
    wv2 := NiumaMobileBrowser_ChatWv2()
    if !wv2
        return
    NiumaMobileBrowser_TryCallFunc("WebView_QueuePayload", wv2, Map("type", "niuma_mobile_browser_error", "error", String(msg)))
    NiumaMobileBrowser_NotifyState(false)
}

NiumaMobileBrowser_OnEnvReady(hwndParent, env) {
    global g_NiumaMobile_Env
    if !env || !hwndParent {
        NiumaMobileBrowser_Log("GUARD", "", "OPEN OnEnvReady abort: env/hwnd 无效")
        NiumaMobileBrowser_OpenFail("手机浏览器环境创建失败")
        return
    }
    g_NiumaMobile_Env := env
    try {
        env.CreateCoreWebView2ControllerAsync(hwndParent)
            .then((ctrl) => (
                NiumaMobileBrowser_Log("GUARD", "", "OPEN Controller 已创建"),
                NiumaMobileBrowser_OnControllerReady(ctrl)
            ))
            .catch((e) => (
                NiumaMobileBrowser_Log("GUARD", "", "OPEN Controller 失败: " . (IsObject(e) ? e.Message : String(e))),
                NiumaMobileBrowser_OpenFail("手机浏览器控制器启动失败: " . (IsObject(e) ? e.Message : String(e)))
            ))
    } catch as e2 {
        NiumaMobileBrowser_Log("GUARD", "", "OPEN Controller 异常: " . e2.Message)
        NiumaMobileBrowser_OpenFail("手机浏览器控制器启动失败: " . e2.Message)
    }
}

NiumaMobileBrowser_InjectSettleOnDocumentCreated(*) {
    global g_NiumaMobile_WV2, JS_MOBILE_SETTLE, JS_MOBILE_REACT_INPUT
    if !IsObject(g_NiumaMobile_WV2)
        return
    if (JS_MOBILE_REACT_INPUT != "") {
        try g_NiumaMobile_WV2.AddScriptToExecuteOnDocumentCreatedAsync(JS_MOBILE_REACT_INPUT)
        catch as eReact {
            NiumaMobileBrowser_Log("GUARD", "", "ReactInput 文档注入失败(非阻塞): " . eReact.Message)
        }
    }
    if (JS_MOBILE_SETTLE = "")
        return
    try g_NiumaMobile_WV2.AddScriptToExecuteOnDocumentCreatedAsync(JS_MOBILE_SETTLE)
    catch as eAdd {
        NiumaMobileBrowser_Log("GUARD", "", "Settle 文档注入失败(非阻塞): " . eAdd.Message)
    }
}

NiumaMobileBrowser_EnsureReactInputInjected() {
    global g_NiumaMobile_WV2, JS_MOBILE_REACT_INPUT
    if !g_NiumaMobile_WV2 || JS_MOBILE_REACT_INPUT = ""
        return false
    try {
        raw := g_NiumaMobile_WV2.ExecuteScriptAsync(
            "!!(window.__NIUMA_REACT_INPUT__&&window.__NIUMA_REACT_INPUT__.fillByLabelId)"
        ).await(2000)
        if (InStr(String(raw), "true"))
            return true
    } catch {
    }
    try g_NiumaMobile_WV2.ExecuteScriptAsync(JS_MOBILE_REACT_INPUT).await(3000)
    catch {
        return false
    }
    return true
}

NiumaMobileBrowser_OnControllerReady(ctrl) {
    global g_NiumaMobile_Ctrl, g_NiumaMobile_WV2, g_NiumaMobile_Open, g_NiumaMobile_PendingUrl
    global g_NiumaMobile_TokenNav, g_NiumaMobile_TokenNewWin, g_NiumaMobile_TokenMsg, NIUMA_MOBILE_UA
    global g_NiumaMobile_OpenInProgress

    if !ctrl {
        NiumaMobileBrowser_Log("GUARD", "", "OPEN OnControllerReady abort: ctrl 为空")
        NiumaMobileBrowser_OpenFail("手机浏览器控制器创建失败")
        return
    }
    g_NiumaMobile_Ctrl := ctrl
    g_NiumaMobile_WV2 := 0
    try g_NiumaMobile_WV2 := ctrl.CoreWebView2
    if !IsObject(g_NiumaMobile_WV2) {
        try ctrl.Close()
        catch {
        }
        g_NiumaMobile_Ctrl := 0
        NiumaMobileBrowser_Log("GUARD", "", "OPEN OnControllerReady abort: CoreWebView2 为空")
        NiumaMobileBrowser_OpenFail("手机浏览器内核创建失败")
        return
    }

    g_NiumaMobile_Open := true
    g_NiumaMobile_OpenInProgress := false
    global g_NiumaMobile_ParentHwnd

    try ctrl.DefaultBackgroundColor := 0xFF0A0A0A
    try ctrl.IsVisible := true
    try ctrl.ZoomFactor := 1.0
    catch {
    }
    try NiumaMobileBrowser_ApplyBounds(g_NiumaMobile_ParentHwnd)
    catch {
    }

    try {
        s := g_NiumaMobile_WV2.Settings
        if IsObject(s) {
            s.UserAgent := NIUMA_MOBILE_UA
            s.AreDefaultContextMenusEnabled := false
            s.AreDevToolsEnabled := false
            s.IsStatusBarEnabled := false
        }
    } catch {
    }
    NiumaMobileBrowser_TryCallFunc("ApplyWebView2PerformanceSettings", g_NiumaMobile_WV2)
    if NiumaMobileBrowser_EnsureLabelScripts()
        SetTimer(NiumaMobileBrowser_InjectSettleOnDocumentCreated, -1)
    else
        NiumaMobileBrowser_Log("GUARD", "", "打开时脚本未就绪，Settle 将延后注入")

    try g_NiumaMobile_TokenNav := g_NiumaMobile_WV2.add_NavigationCompleted(NiumaMobileBrowser_OnNavigationCompleted)
    catch {
        g_NiumaMobile_TokenNav := 0
    }
    try g_NiumaMobile_TokenNavStart := g_NiumaMobile_WV2.add_NavigationStarting(NiumaMobileBrowser_OnNavigationStarting)
    catch {
        g_NiumaMobile_TokenNavStart := 0
    }
    try g_NiumaMobile_TokenNewWin := g_NiumaMobile_WV2.add_NewWindowRequested(NiumaMobileBrowser_OnNewWindowRequested)
    catch {
        g_NiumaMobile_TokenNewWin := 0
    }
    try g_NiumaMobile_TokenMsg := g_NiumaMobile_WV2.add_WebMessageReceived(NiumaMobileBrowser_OnWebMessageReceived)
    catch {
        g_NiumaMobile_TokenMsg := 0
    }

    NiumaMobileBrowser_SetPendingOpen(false)
    url := g_NiumaMobile_PendingUrl
    if (url = "")
        url := "about:blank"
    try g_NiumaMobile_WV2.Navigate(url)
    catch {
    }

    NiumaMobileBrowser_Log("GUARD", "", "OPEN 完成 Navigate=" . url)
    NiumaMobileBrowser_NotifyState(true, url)
    NiumaMobileBrowser_TryCallFunc("FloatingToolbar_AfterMobileBrowserOpen")
    NiumaMobileBrowser_TryCallFunc("FloatingToolbar_RefreshMobileLayout")
    hwnd := g_NiumaMobile_ParentHwnd
    SetTimer(NiumaMobileBrowser_DeferredLayout.Bind(hwnd), -80)
    SetTimer(NiumaMobileBrowser_DeferredLayout.Bind(hwnd), -280)
    SetTimer(NiumaMobileBrowser_DeferredLayout.Bind(hwnd), -700)
}

NiumaMobileBrowser_DeferredLayout(hwnd, *) {
    if !NiumaMobileBrowser_IsOpen()
        return
    NiumaMobileBrowser_TryCallFunc("FloatingToolbar_RefreshMobileLayout")
    try NiumaMobileBrowser_ApplyBounds(hwnd)
    catch {
    }
}

NiumaMobileBrowser_OnNavigationStarting(sender, args) {
    global g_NiumaMobile_SettlePending, g_NiumaMobile_SettleNavPending, g_NiumaMobile_SettleReqId, g_NiumaMobile_ObserveReqId
    if !g_NiumaMobile_SettlePending
        return
    g_NiumaMobile_SettleNavPending := true
    if (g_NiumaMobile_SettleReqId = "")
        g_NiumaMobile_SettleReqId := g_NiumaMobile_ObserveReqId
    NiumaMobileBrowser_Log("GATE_FLOW", g_NiumaMobile_SettleReqId, "nav_start 熔断 JS settle，等待 NavigationCompleted")
}

NiumaMobileBrowser_OnNavigationCompleted(sender, args) {
    global g_NiumaMobile_WV2, NIUMA_MOBILE_INJECT_JS, JS_MOBILE_SETTLE, JS_MOBILE_REACT_INPUT, g_NiumaMobile_SettleNavPending, g_NiumaMobile_SettleReqId
        , g_NiumaMobile_AiPaused, g_NiumaMobile_PendingAnalyzeCb, g_NiumaMobile_AiBusy, g_NiumaMobile_ObserveReqId
        , g_NiumaMobile_NavigateWatchdogActive, g_NiumaMobile_NavigateAckReqId
    if !g_NiumaMobile_WV2
        return
    navOk := true
    try {
        if IsObject(args) && args.HasProp("IsSuccess") && !args.IsSuccess
            navOk := false
    } catch {
    }
    try {
        uNav := g_NiumaMobile_WV2.SourceUri
        if (uNav != "")
            g_NiumaMobile_LastKnownUrl := String(uNav)
    } catch {
    }
    if (g_NiumaMobile_NavigateWatchdogActive && String(g_NiumaMobile_NavigateAckReqId) != "") {
        ; 导航完成优先关闭 watchdog，避免出现伪超时日志。
        SetTimer(NiumaMobileBrowser_NavigateWatchdogTimeout, 0)
        NiumaMobileBrowser_FireNavigateAckOnce(g_NiumaMobile_NavigateAckReqId, navOk, navOk ? "" : "navigation_failed")
    }
    try g_NiumaMobile_WV2.ExecuteScriptAsync(NIUMA_MOBILE_INJECT_JS)
    catch {
    }
    if (JS_MOBILE_REACT_INPUT != "") {
        if NiumaMobileBrowser_EnsureLabelScripts()
            NiumaMobileBrowser_EnsureReactInputInjected()
    }
    ; 注入调试悬浮窗（右侧浏览器）
    try NiumaMobileBrowser_EnsureTraceOverlayInjected()
    catch {
    }
    if (JS_MOBILE_SETTLE != "") {
        try g_NiumaMobile_WV2.ExecuteScriptAsync(JS_MOBILE_SETTLE)
        catch {
        }
    }
    if g_NiumaMobile_SettleNavPending {
        g_NiumaMobile_SettleNavPending := false
        rid := g_NiumaMobile_SettleReqId
        if (rid != "" && navOk && !g_NiumaMobile_AiPaused) {
            g_NiumaMobile_ObserveReqId := rid
            NiumaMobileBrowser_Log("GATE_FLOW", rid, "nav_completed 开闸候选")
            NiumaMobileBrowser_CentralSettleGate(rid, "nav_completed")
        }
        return
    }
    if !g_NiumaMobile_AiPaused {
        if g_NiumaMobile_LabelDebug {
            NiumaMobileBrowser_EnsureLabelDebugOnPage(true)
            if !IsObject(g_NiumaMobile_PendingAnalyzeCb) && !g_NiumaMobile_AiBusy && (g_NiumaMobile_ObserveReqId = "")
                SetTimer(NiumaMobileBrowser_DeferredFirstLabel.Bind(), -650)
        } else {
            NiumaMobileBrowser_EnsureLabelDebugOnPage(false)
        }
    }
}

NiumaMobileBrowser_EnsureTraceOverlayInjected() {
    global g_NiumaMobile_WV2, JS_MOBILE_TRACE_OVERLAY
    if !g_NiumaMobile_WV2
        return false
    if (JS_MOBILE_TRACE_OVERLAY = "" && !NiumaMobileBrowser_EnsureLabelScripts())
        return false
    ; 版本戳：用于确认右侧悬浮窗是否加载到最新脚本
    try g_NiumaMobile_WV2.ExecuteScriptAsync("window.__NIUMA_TRACE_OVERLAY_VER__='" . NiumaMobileBrowser_EscapeJsSingle(A_Now) . "';")
    catch {
    }
    try g_NiumaMobile_WV2.ExecuteScriptAsync(JS_MOBILE_TRACE_OVERLAY)
    catch {
        return false
    }
    return true
}

NiumaMobileBrowser_TraceOverlayPush(line, level := "") {
    global g_NiumaMobile_WV2
    if !g_NiumaMobile_WV2
        return false
    try NiumaMobileBrowser_EnsureTraceOverlayInjected()
    catch {
    }
    s := NiumaMobileBrowser_EscapeJsSingle(String(line))
    lv := NiumaMobileBrowser_EscapeJsSingle(String(level))
    js := "(function(){try{if(window.__NIUMA_TRACE_OVERLAY__&&window.__NIUMA_TRACE_OVERLAY__.push){window.__NIUMA_TRACE_OVERLAY__.push('" . s . "','" . lv . "');return 'ok';}return 'no';}catch(e){return 'err';}})();"
    try g_NiumaMobile_WV2.ExecuteScriptAsync(js)
    catch {
        return false
    }
    return true
}

NiumaMobileBrowser_CheckChatInjectConsumed(reqId, *) {
    wv2 := NiumaMobileBrowser_ChatWv2()
    rid := String(reqId)
    static _seen := Map()
    ; 去重：避免短时间内重复刷屏，但不要“一次误判就永不再试”
    if (_seen.Has(rid)) {
        v := _seen[rid]
        if (v = "ok")
            return
        if (IsNumber(v) && (A_TickCount - v) < 900)
            return
    }
    _seen[rid] := A_TickCount
    try NiumaMobileBrowser_TraceOverlayPush("CHAT 消费检查 start rid=" . rid, "warn")
    catch {
    }
    if !wv2 {
        try NiumaMobileBrowser_TraceOverlayPush("CHAT 消费检查 abort: ChatWv2 为空 rid=" . rid, "err")
        catch {
        }
        return
    }
    js := "(function(){try{return JSON.stringify(window.__NIUMA_LAST_HOSTINJECT__||null);}catch(e){return 'null';}})();"
    try {
        raw := wv2.ExecuteScriptAsync(js).await(220)
        s := Trim(String(raw))
        if (SubStr(s, 1, 1) = '"')
            s := NiumaMobileBrowser_UnquoteScriptResult(s)
        s2 := Trim(String(s))
        if (s2 = "" || s2 = "null") {
            try NiumaMobileBrowser_TraceOverlayPush("CHAT 注入未被消费 rid=" . rid . " (var=null)，改走 HostObject 注入", "warn")
            catch {
            }
            try NiumaMobileBrowser_InjectCachedSnapshotViaHostObject(wv2, rid)
            catch {
            }
            return
        }
        ; 简单匹配 reqId，避免依赖 Jxon_Load
        if InStr(s2, '"type":"host_inject_parse_error"') {
            em := ""
            if RegExMatch(s2, '"err"\s*:\s*"((?:[^"\\]|\\.)*)"', &mE2)
                em := mE2[1]
            try NiumaMobileBrowser_TraceOverlayPush("CHAT 注入解析失败 rid=" . rid . " err=" . SubStr(em, 1, 140), "err")
            catch {
            }
            ; parse_error 时无法确认是否消费成功：走 HostObject 补注入
            try NiumaMobileBrowser_InjectCachedSnapshotViaHostObject(wv2, rid)
            catch {
            }
            return
        }
        if (rid != "" && InStr(s2, '"reqId":"' . rid . '"')) {
            NiumaMobileBrowser_TraceOverlayPush("CHAT 注入已消费 rid=" . rid, "success")
            _seen[rid] := "ok"
        } else {
            try NiumaMobileBrowser_TraceOverlayPush("CHAT 注入已消费但 rid 不匹配 rid=" . rid . " raw=" . SubStr(s2, 1, 80), "warn")
            catch {
            }
            ; 很可能是别的 rid 覆盖了 __NIUMA_LAST_HOSTINJECT__：走 HostObject 补注入兜底
            try NiumaMobileBrowser_InjectCachedSnapshotViaHostObject(wv2, rid)
            catch {
            }
        }
    } catch as e {
        try NiumaMobileBrowser_TraceOverlayPush("CHAT 注入消费检查失败 rid=" . rid . " err=" . e.Message, "warn")
        catch {
        }
    }
}

NiumaMobileBrowser_TraceFromChat(msg) {
    if !(msg is Map)
        return
    t := msg.Has("t") ? String(msg["t"]) : ""
    turn := msg.Has("turn") ? Integer(msg["turn"]) : 0
    text := msg.Has("text") ? String(msg["text"]) : ""
    detail := msg.Has("detail") ? String(msg["detail"]) : ""
    lvl := msg.Has("level") ? String(msg["level"]) : ""
    if (text = "" && detail = "")
        return
    line := (t != "" ? t . " " : "") . (turn > 0 ? ("T" . turn . " ") : "") . text
    if (detail != "")
        line := line . " · " . SubStr(detail, 1, 220)
    NiumaMobileBrowser_TraceOverlayPush(line, lvl)
}

NiumaMobileBrowser_DeferredFirstLabel(*) {
    global g_NiumaMobile_PendingAnalyzeCb, g_NiumaMobile_AiBusy, g_NiumaMobile_ObserveReqId, g_NiumaMobile_LabelDebug
    if !NiumaMobileBrowser_IsOpen()
        return
    if !g_NiumaMobile_LabelDebug
        return
    ; 避免导航后静默打标覆盖 ObserveForChat 的 PendingAnalyzeCb，导致 Chat 永远等不到带 reqId 的快照
    if IsObject(g_NiumaMobile_PendingAnalyzeCb) || g_NiumaMobile_AiBusy || (g_NiumaMobile_ObserveReqId != "")
        return
    NiumaMobileBrowser_AnalyzePage(0, true)
}

NiumaMobileBrowser_EnsureLabelDebugOnPage(on := true) {
    global g_NiumaMobile_WV2
    if !g_NiumaMobile_WV2
        return
    flag := on ? "true" : "false"
    script := "(function(){try{window.__NIUMA_LABEL_DEBUG__=" . flag . ";return 'ok';}catch(e){return '';}})()"
    try g_NiumaMobile_WV2.ExecuteScriptAsync(script)
    catch {
    }
}

NiumaMobileBrowser_OnNewWindowRequested(sender, args) {
    global g_NiumaMobile_WV2
    uri := ""
    try {
        args.Handled := true
        uri := args.Uri
    } catch {
    }
    if (uri != "" && g_NiumaMobile_WV2) {
        try g_NiumaMobile_WV2.Navigate(uri)
        catch {
        }
    }
}

NiumaMobileBrowser_ApplyBounds(parentHwnd := 0) {
    global g_NiumaMobile_Ctrl, g_NiumaMobile_ParentHwnd
    hwnd := Integer(parentHwnd) ? Integer(parentHwnd) : g_NiumaMobile_ParentHwnd
    if !hwnd || !g_NiumaMobile_Ctrl
        return
    try WinGetClientPos(, , &cw, &ch, hwnd)
    catch {
        return
    }
    if (cw < 1 || ch < 1)
        return
    mobileW := NiumaMobileBrowser_WidthPx()
    if (mobileW > cw)
        mobileW := cw
    rc := NiumaMobile_RECT()
    rc.left := Max(0, cw - mobileW)
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    try {
        g_NiumaMobile_Ctrl.Bounds := rc
        g_NiumaMobile_Ctrl.NotifyParentWindowPositionChanged()
        g_NiumaMobile_Ctrl.IsVisible := true
    } catch {
    }
}

NiumaMobileBrowser_Back() {
    global g_NiumaMobile_WV2
    if !g_NiumaMobile_WV2
        return false
    try {
        if g_NiumaMobile_WV2.CanGoBack {
            g_NiumaMobile_WV2.GoBack()
            return true
        }
    } catch {
    }
    return false
}

NiumaMobileBrowser_Reload() {
    global g_NiumaMobile_WV2
    if !g_NiumaMobile_WV2
        return false
    try {
        g_NiumaMobile_WV2.Reload()
        return true
    } catch {
    }
    return false
}

NiumaMobileBrowser_StartNavigateAction(actionType, reqId := "") {
    global g_NiumaMobile_WV2, g_NiumaMobile_NavigateAckReqId, g_NiumaMobile_NavigateWatchdogActive
        , g_NiumaMobile_NavigateCoreEventFired, g_NiumaMobile_NavigateAckAction
    if !g_NiumaMobile_WV2
        return false
    rid := String(reqId)
    if (rid = "")
        rid := "act-" . A_TickCount . "-" . Random(1000, 9999)
    g_NiumaMobile_NavigateAckReqId := rid
    g_NiumaMobile_NavigateAckAction := String(actionType)
    g_NiumaMobile_NavigateWatchdogActive := true
    try g_NiumaMobile_NavigateCoreEventFired.Delete(rid)
    catch {
    }
    g_NiumaMobile_NavigateCoreEventFired[rid] := false
    SetTimer(NiumaMobileBrowser_NavigateWatchdogTimeout, -3500)
    ok := false
    try {
        if (actionType = "refresh") {
            g_NiumaMobile_WV2.Reload()
            ok := true
        } else if (actionType = "back") {
            if g_NiumaMobile_WV2.CanGoBack {
                g_NiumaMobile_WV2.GoBack()
                ok := true
            } else {
                ok := false
            }
        }
    } catch {
        ok := false
    }
    if !ok {
        SetTimer(NiumaMobileBrowser_NavigateWatchdogTimeout, 0)
        NiumaMobileBrowser_FireNavigateAckOnce(rid, false, "navigate_dispatch_failed")
        return false
    }
    NiumaMobileBrowser_Log("GATE_FLOW", rid, "navigate action start action=" . String(actionType))
    return true
}

NiumaMobileBrowser_NavigateWatchdogTimeout(*) {
    global g_NiumaMobile_NavigateAckReqId, g_NiumaMobile_NavigateWatchdogActive
    if !g_NiumaMobile_NavigateWatchdogActive
        return
    rid := String(g_NiumaMobile_NavigateAckReqId)
    if (rid = "")
        return
    NiumaMobileBrowser_Log("GATE_FLOW", rid, "navigate watchdog timeout, force ack")
    NiumaMobileBrowser_FireNavigateAckOnce(rid, false, "watchdog_timeout")
}

NiumaMobileBrowser_FireNavigateAckOnce(reqId, ok := true, reason := "") {
    global g_NiumaMobile_NavigateCoreEventFired, g_NiumaMobile_NavigateWatchdogActive
        , g_NiumaMobile_NavigateAckReqId, g_NiumaMobile_NavigateAckAction
    rid := String(reqId)
    if (rid = "")
        return false
    fired := false
    try fired := g_NiumaMobile_NavigateCoreEventFired.Has(rid) && !!g_NiumaMobile_NavigateCoreEventFired[rid]
    catch {
        fired := false
    }
    if fired
        return false
    g_NiumaMobile_NavigateCoreEventFired[rid] := true
    g_NiumaMobile_NavigateWatchdogActive := false
    SetTimer(NiumaMobileBrowser_NavigateWatchdogTimeout, 0)
    action := String(g_NiumaMobile_NavigateAckAction)
    g_NiumaMobile_NavigateAckReqId := ""
    g_NiumaMobile_NavigateAckAction := ""
    if ok
        return NiumaMobileBrowser_QueueActToChat("host_browser_act_result", rid, true, "", action, 0, false, "action_" . action)
    return NiumaMobileBrowser_QueueActToChat("host_browser_act_error", rid, false, reason, action, 0, false, "action_" . action)
}

NiumaMobileBrowser_ExtractText() {
    global g_NiumaMobile_WV2
    if !g_NiumaMobile_WV2
        return false
    script := "(function(){try{var t=(document.body&&document.body.innerText)||'';return String(t).substring(0,120000);}catch(e){return '';}})()"
    try {
        raw := g_NiumaMobile_WV2.ExecuteScriptAsync(script).await(12000)
        NiumaMobileBrowser_OnExtractDone(raw)
        return true
    } catch {
    }
    return false
}

NiumaMobileBrowser_EscapeJsSingle(s) {
    t := StrReplace(String(s), "\", "\\")
    t := StrReplace(t, "'", "\'")
    t := StrReplace(t, "`r", "\r")
    t := StrReplace(t, "`n", "\n")
    ; JS 字符串字面量禁用 U+2028/U+2029（会导致 ExecuteScriptAsync 语法错误/注入不生效）
    t := StrReplace(t, Chr(0x2028), "\u2028")
    t := StrReplace(t, Chr(0x2029), "\u2029")
    return t
}

NiumaMobileBrowser_EmbedJsTextLiteral(text) {
    t := Trim(String(text))
    if (t = "")
        return "''"
    return "'" . NiumaMobileBrowser_EscapeJsSingle(t) . "'"
}

NiumaMobileBrowser_IsCompatReqId(reqId) {
    rid := String(reqId)
    return (SubStr(rid, 1, 7) = "compat-")
}

NiumaMobileBrowser_BuildActExtraJson(parsed) {
    if !(parsed is Map)
        return ""
    out := ""
    for key in ["inputOk", "sendOk", "sentInThread", "sendClicked", "submitted", "deferred", "chatSubmit", "idempotentSkip", "domAssertOk", "planPipe"] {
        if !parsed.Has(key)
            continue
        val := parsed[key]
        if (val is String)
            out .= ',"' . key . '":"' . NiumaMobileBrowser_EscapeJsonStr(String(val)) . '"'
        else
            out .= ',"' . key . '":' . (val ? "true" : "false")
    }
    if parsed.Has("editorText") {
        et := String(parsed["editorText"])
        if (StrLen(et) > 160)
            et := SubStr(et, 1, 160)
        out .= ',"editorText":"' . NiumaMobileBrowser_EscapeJsonStr(et) . '"'
    }
    if parsed.Has("methods") {
        mt := String(parsed["methods"])
        if (StrLen(mt) > 80)
            mt := SubStr(mt, 1, 80)
        out .= ',"methods":"' . NiumaMobileBrowser_EscapeJsonStr(mt) . '"'
    }
    if parsed.Has("sendGateMs") {
        out .= ',"sendGateMs":' . Integer(parsed["sendGateMs"])
    }
    return out
}

NiumaMobileBrowser_QueueActToChat(typ, reqId, ok := false, err := "", action := "", elementId := 0, cancelled := false, stage := "", parsed := 0) {
    wv2 := NiumaMobileBrowser_ChatWv2()
    rid := String(reqId)
    st := NiumaMobileBrowser_NormalizeStage(stage)
    if (typ = "host_browser_act_error")
        NiumaMobileBrowser_Log("CHAT_OUT", rid, "host_browser_act_error stage=" . st . " error=" . String(err))
    else if (typ = "host_browser_chat_plan_result")
        NiumaMobileBrowser_Log("CHAT_OUT", rid, "host_browser_chat_plan_result ok=" . (ok ? 1 : 0) . " err=" . String(err))
    else
        NiumaMobileBrowser_Log("CHAT_OUT", rid, "host_browser_act_result action=" . String(action) . " ok=" . (ok ? 1 : 0) . " err=" . String(err))
    if !wv2
        return false
    try {
        lvl := (typ = "host_browser_act_error" || !ok) ? "err" : (cancelled ? "warn" : "success")
        NiumaMobileBrowser_TraceOverlayPush("ACT " . String(action) . " #" . Integer(elementId) . " ok=" . (ok ? 1 : 0) . " stage=" . st . " err=" . String(err), lvl)
    } catch {
    }
    json := '{"type":"' . typ . '","reqId":"' . NiumaMobileBrowser_EscapeJsonStr(rid) . '"'
        . ',"ok":' . (ok ? "true" : "false")
        . ',"error":"' . NiumaMobileBrowser_EscapeJsonStr(String(err)) . '"'
        . ',"action":"' . NiumaMobileBrowser_EscapeJsonStr(String(action)) . '"'
        . ',"elementId":' . Integer(elementId)
        . ',"cancelled":' . (cancelled ? "true" : "false")
        . ',"stage":"' . NiumaMobileBrowser_EscapeJsonStr(st) . '"'
        . NiumaMobileBrowser_BuildActExtraJson(parsed) . '}'
    sent := false
    try {
        if NiumaMobileBrowser_TryCallFunc("WebView_QueueJson", wv2, json) {
            sent := true
        } else {
            wv2.PostWebMessageAsJson(json)
            sent := true
        }
    } catch as e {
        NiumaMobileBrowser_Log("CHAT_OUT", rid, typ . " post_failed err=" . e.Message)
        return false
    }
    if (sent && NiumaMobileBrowser_IsCompatReqId(rid)) {
        legacy := '{"type":"' . typ . '","ok":' . (ok ? "true" : "false")
            . ',"error":"' . NiumaMobileBrowser_EscapeJsonStr(String(err)) . '"'
            . ',"action":"' . NiumaMobileBrowser_EscapeJsonStr(String(action)) . '"'
            . ',"elementId":' . Integer(elementId)
            . ',"cancelled":' . (cancelled ? "true" : "false")
            . ',"stage":"' . NiumaMobileBrowser_EscapeJsonStr(st) . '"'
            . NiumaMobileBrowser_BuildActExtraJson(parsed) . '}'
        try {
            if !NiumaMobileBrowser_TryCallFunc("WebView_QueueJson", wv2, legacy)
                wv2.PostWebMessageAsJson(legacy)
        } catch {
        }
        NiumaMobileBrowser_TryCallFunc("FloatingToolbar_CompatOnActAck", rid)
    }
    return true
}

NiumaMobileBrowser_DeliverErrorToChat(err, reqId := "", stage := "") {
    global g_NiumaMobile_ActReqId, g_NiumaMobile_ObserveReqId
    rid := String(reqId)
    if (rid = "")
        rid := g_NiumaMobile_ActReqId != "" ? g_NiumaMobile_ActReqId : g_NiumaMobile_ObserveReqId
    NiumaMobileBrowser_QueueActToChat("host_browser_act_error", rid, false, String(err), "", 0, false, stage)
}

NiumaMobileBrowser_ExecScript(jobType, script, reqId := "", meta := 0) {
    global g_NiumaMobile_WV2, g_NiumaMobile_Jobs, g_NiumaMobile_JobCounter
    if !g_NiumaMobile_WV2
        return ""
    if !IsObject(meta)
        meta := Map()
    g_NiumaMobile_JobCounter += 1
    jobId := "JOB_" . g_NiumaMobile_JobCounter . "_" . A_TickCount
    card := Map(
        "jobId", jobId,
        "jobType", String(jobType),
        "reqId", String(reqId),
        "startedAt", A_TickCount,
        "meta", meta
    )
    g_NiumaMobile_Jobs[jobId] := card
    ; Google 等站点无 chrome.webview.postMessage，勿用 postMessage 包装（会永远 job_timeout）
    jobTimeout := (jobType = "click" || jobType = "input" || jobType = "scroll") ? 12000 : 22000
    NiumaMobileBrowser_Log("JOB_LAUNCH", reqId, "jobId=" . jobId . " type=" . jobType . " mode=await")
    try {
        raw := g_NiumaMobile_WV2.ExecuteScriptAsync(script).await(jobTimeout)
        NiumaMobileBrowser_OnScriptResult(jobId, raw, true, "")
    } catch as e {
        NiumaMobileBrowser_OnScriptResult(jobId, "", false, e.Message)
    }
    return jobId
}

NiumaMobileBrowser_OnJobWatchdog(jobId, *) {
    NiumaMobileBrowser_OnScriptResult(jobId, "", false, "job_timeout")
}

NiumaMobileBrowser_OnScriptResult(jobId, rawResult, ok := true, err := "") {
    global g_NiumaMobile_Jobs
    if !g_NiumaMobile_Jobs.Has(jobId)
        return
    card := g_NiumaMobile_Jobs[jobId]
    g_NiumaMobile_Jobs.Delete(jobId)
    if card.Has("watchdog") {
        try SetTimer(card["watchdog"], 0)
        catch {
        }
    }
    reqLog := card.Has("reqId") ? String(card["reqId"]) : ""
    typ := card.Has("jobType") ? String(card["jobType"]) : ""
    if !ok {
        NiumaMobileBrowser_Log("JOB_CALLBACK", reqLog, "jobId=" . jobId . " type=" . typ . " ok=0 err=" . String(err))
        NiumaMobileBrowser_HandleJobError(card, err)
        return
    }
    NiumaMobileBrowser_Log("JOB_CALLBACK", reqLog, "jobId=" . jobId . " type=" . typ . " ok=1")
    typ := card["jobType"]
    meta := card["meta"]
    switch typ {
        case "analyze":
            NiumaMobileBrowser_OnAnalyzeDone(rawResult)
        case "click":
            NiumaMobileBrowser_OnClickDone(meta.Has("elementId") ? Integer(meta["elementId"]) : 0, rawResult)
        case "input":
            NiumaMobileBrowser_OnInputDone(meta.Has("elementId") ? Integer(meta["elementId"]) : 0, rawResult)
        case "scroll":
            NiumaMobileBrowser_OnScrollDone(meta.Has("elementId") ? Integer(meta["elementId"]) : 0, rawResult)
    }
}

NiumaMobileBrowser_HandleJobError(jobCard, errorMsg) {
    global g_NiumaMobile_PendingActCb
    reqId := jobCard.Has("reqId") ? String(jobCard["reqId"]) : ""
    jt := jobCard.Has("jobType") ? String(jobCard["jobType"]) : ""
    stage := jt = "click" ? "action_click" : (jt = "input" ? "action_input" : (jt = "scroll" ? "action_scroll" : (jt = "analyze" ? "label" : jt)))
    if (jt = "click" || jt = "input") {
        NiumaMobileBrowser_SetAiBusy(false)
        g_NiumaMobile_PendingActCb := 0
    }
    NiumaMobileBrowser_DeliverErrorToChat("script_exec_failed: " . String(errorMsg), reqId, stage)
}

NiumaMobileBrowser_OnWebMessageReceived(sender, args) {
    raw := ""
    try raw := args.WebMessageAsJson
    catch {
        return
    }
    if (raw = "")
        return
    try msg := NiumaMobileBrowser_CallFunc("Jxon_Load", raw)
    catch {
        return
    }
    if !(msg is Map) || !msg.Has("type")
        return
    typ := String(msg["type"])
    if (typ = "niuma_job_completed") {
        jid := msg.Has("jobId") ? String(msg["jobId"]) : ""
        ok := msg.Has("ok") ? !!msg["ok"] : false
        data := ""
        if msg.Has("data") {
            dRaw := msg["data"]
            if (dRaw is Map) || (dRaw is Array) {
                try data := NiumaMobileBrowser_CallFunc("Jxon_Dump", dRaw)
                catch {
                    data := ""
                }
            } else
                data := String(dRaw)
        }
        err := msg.Has("error") ? String(msg["error"]) : ""
        NiumaMobileBrowser_Log("JOB_CALLBACK", "", "WebMessage jobId=" . jid . " ok=" . (ok ? 1 : 0))
        NiumaMobileBrowser_OnScriptResult(jid, data, ok, err)
        return
    }
    if (typ = "niuma_settle_done") {
        rid := msg.Has("reqId") ? String(msg["reqId"]) : ""
        src := msg.Has("source") ? String(msg["source"]) : "settle_sensor"
        NiumaMobileBrowser_Log("GATE_FLOW", rid, "收到 niuma_settle_done source=" . src)
        NiumaMobileBrowser_CentralSettleGate(rid, src)
        return
    }
}

NiumaMobileBrowser_UnquoteScriptResult(raw) {
    s := Trim(String(raw))
    if (s = "")
        return ""
    if (SubStr(s, 1, 1) = '"') {
        try {
            wrapped := '{"v":' . s . '}'
            obj := NiumaMobileBrowser_CallFunc("Jxon_Load", wrapped)
            if (obj is Map && obj.Has("v"))
                return String(obj["v"])
        } catch {
        }
        s := SubStr(s, 2, StrLen(s) - 2)
        s := StrReplace(s, '\\n', "`n")
        s := StrReplace(s, '\\r', "`r")
        s := StrReplace(s, '\\t', "`t")
        s := StrReplace(s, '\\"', '"')
        s := StrReplace(s, '\\\\', '\')
    }
    return s
}

NiumaMobileBrowser_OnExtractDone(result) {
    wv2 := NiumaMobileBrowser_ChatWv2()
    text := NiumaMobileBrowser_UnquoteScriptResult(result)
    if !wv2
        return
    NiumaMobileBrowser_TryCallFunc("WebView_QueuePayload", wv2, Map("type", "niuma_mobile_extract_result", "text", text))
}

NiumaMobileBrowser_NotifyStateVia(wv2, open, url := "") {
    global g_NiumaMobile_LabelDebug, g_NiumaMobile_AiPaused, g_NiumaMobile_LastKnownUrl
    if !IsObject(wv2) {
        NiumaMobileBrowser_Log("STATE", "", "NotifyStateVia abort: wv2 非对象")
        return
    }
    u0 := String(url)
    if (u0 != "")
        g_NiumaMobile_LastKnownUrl := u0
    ; 绕过 WebView_QueuePayload 异步队列，直接 PostWebMessageAsJson 同步投递，
    ; 避免队列 Flush 时 wv2 被回收导致消息静默丢弃。
    jsonStr := '{"type":"host_mobile_browser_state"'
        . ',"open":' . (!!open ? "true" : "false")
        . ',"url":"' . NiumaMobileBrowser_EscapeJsonStr(u0) . '"'
        . ',"widthPx":' . NiumaMobileBrowser_WidthPx()
        . ',"labelDebugVisible":' . (!!g_NiumaMobile_LabelDebug ? "true" : "false")
        . ',"aiPaused":' . (!!g_NiumaMobile_AiPaused ? "true" : "false")
        . '}'
    try {
        wv2.PostWebMessageAsJson(jsonStr)
        NiumaMobileBrowser_Log("STATE", "", "host_mobile_browser_state 直投成功 open=" . (!!open) . " url=" . String(url))
    } catch as e {
        NiumaMobileBrowser_Log("STATE", "", "host_mobile_browser_state 直投失败: " . e.Message)
    }
}

NiumaMobileBrowser_NotifyState(open, url := "") {
    wv2 := NiumaMobileBrowser_ChatWv2()
    if !wv2 {
        NiumaMobileBrowser_Log("STATE", "", "NotifyState ChatWv2 为空，启动重试链 open=" . (!!open))
        SetTimer(NiumaMobileBrowser_NotifyStateRetry.Bind(!!open, String(url), 0), -500)
        return
    }
    NiumaMobileBrowser_NotifyStateVia(wv2, open, url)
}

NiumaMobileBrowser_NotifyStateRetry(open, url, attempt, *) {
    if (attempt >= 12) {
        NiumaMobileBrowser_Log("STATE", "", "NotifyState 重试耗尽 attempt=" . attempt . " open=" . (!!open))
        return
    }
    wv2 := NiumaMobileBrowser_ChatWv2()
    if !wv2 {
        NiumaMobileBrowser_Log("STATE", "", "NotifyState 重试 attempt=" . (attempt + 1) . " ChatWv2 仍为空")
        SetTimer(NiumaMobileBrowser_NotifyStateRetry.Bind(open, url, attempt + 1), -500)
        return
    }
    NiumaMobileBrowser_Log("STATE", "", "NotifyState 重试成功 attempt=" . (attempt + 1) . " open=" . (!!open))
    NiumaMobileBrowser_NotifyStateVia(wv2, open, url)
}

; SetTimer 用 Bind(IsOpen(),…) 会在「调度时」把 open 定死为 false；必须在触发时再读 IsOpen()
NiumaMobileBrowser_NotifyStateLive(url := "") {
    u := String(url)
    global g_NiumaMobile_WV2
    if (u = "" && NiumaMobileBrowser_IsOpen() && g_NiumaMobile_WV2) {
        try u := g_NiumaMobile_WV2.SourceUri
        catch {
        }
    }
    NiumaMobileBrowser_NotifyState(NiumaMobileBrowser_IsOpen(), u)
}

NiumaMobileBrowser_SetAiBusy(busy, blockPage := true) {
    global g_NiumaMobile_AiBusy
    g_NiumaMobile_AiBusy := !!busy
    wv2 := NiumaMobileBrowser_ChatWv2()
    if wv2
        NiumaMobileBrowser_TryCallFunc("WebView_QueuePayload", wv2, Map("type", "host_browser_ai_busy", "busy", !!busy))
    if blockPage
        NiumaMobileBrowser_SetInputBlocked(!!busy, true)
}

NiumaMobileBrowser_SetInputBlocked(block, waitDone := false) {
    global g_NiumaMobile_WV2, JS_MOBILE_SET_INPUT_BLOCK
    if !g_NiumaMobile_WV2
        return
    script := StrReplace(JS_MOBILE_SET_INPUT_BLOCK, "__NIUMA_BLOCK__", block ? "true" : "false")
    try {
        if waitDone
            g_NiumaMobile_WV2.ExecuteScriptAsync(script).await(1500)
        else
            g_NiumaMobile_WV2.ExecuteScriptAsync(script)
    } catch {
    }
}

NiumaMobileBrowser_MapValuesToArray(m) {
    arr := []
    if !(m is Map)
        return arr
    for , v in m.OwnProps()
        arr.Push(v)
    return arr
}

; 与 NotifyStateVia 相同：必须 PostWebMessageAsJson 直投；WebView_QueueJson 队列在 Flush 时可能静默丢包。
NiumaMobileBrowser_PostJsonToChatDirect(wv2, jsonStr, reqId := "", logLabel := "") {
    if !wv2 || jsonStr = ""
        return false
    try {
        wv2.PostWebMessageAsJson(jsonStr)
        if (logLabel != "")
            NiumaMobileBrowser_Log("CHAT_OUT", reqId, logLabel)
        return true
    } catch as e {
        NiumaMobileBrowser_Log("CHAT_OUT", reqId, (logLabel != "" ? logLabel . " " : "") . "直投失败 err=" . e.Message)
        return false
    }
}

; 小包通知：Chat 收到后通过 HostObject / __niumaHostInject 拉取 g_NiumaMobile_LastSnapshotJson。
NiumaMobileBrowser_NotifySnapshotReady(wv2, reqId, arrLen, url := "", err := "") {
    if !wv2
        return false
    rid := NiumaMobileBrowser_EscapeJsonStr(String(reqId))
    n := Integer(arrLen)
    poke := '{"type":"host_browser_snapshot_ready","reqId":"' . rid . '","count":' . n . ',"arrLen":' . n
        . ',"url":"' . NiumaMobileBrowser_EscapeJsonStr(String(url)) . '"'
        . ',"error":"' . NiumaMobileBrowser_EscapeJsonStr(String(err)) . '"}'
    return NiumaMobileBrowser_PostJsonToChatDirect(wv2, poke, reqId, "snapshot_ready poke count=" . n)
}

NiumaMobileBrowser_IsChatBridgeReady() {
    try {
        if NiumaMobileBrowser_FuncExists("FloatingToolbar_IsChatBridgeReady")
            return !!Func("FloatingToolbar_IsChatBridgeReady").Call()
    } catch as e {
        ; 极少数情况下 Func().Call 可能抛异常（加载时序/函数未就绪）。退回到全局标志位+句柄检查，避免假 not_ready。
        try {
            global g_NiumaChatFrontReady
            w := NiumaMobileBrowser_ChatWv2()
            ok := !!g_NiumaChatFrontReady && IsObject(w)
            NiumaMobileBrowser_TraceOverlayPush("BRIDGE check exception: " . e.Message . " fallback=" . (ok ? 1 : 0), "warn")
            return ok
        } catch {
        }
    }
    try {
        global g_NiumaChatFrontReady
        w2 := NiumaMobileBrowser_ChatWv2()
        return !!g_NiumaChatFrontReady && IsObject(w2)
    } catch {
        return false
    }
}

; 滞港调度：始终写缓存；仅 chat_ready 且 ChatWv2 有效时直投。返回 delivered | deferred | failed
NiumaMobileBrowser_SnapshotDispatcher(finalSafePayload, reqId, arrLen := 0, url := "", err := "", meta := "") {
    global g_NiumaMobile_LastSnapshotJson
    rid := String(reqId)
    j := Trim(String(finalSafePayload))
    if (j = "" || StrLen(j) < 40)
        return "failed"
    g_NiumaMobile_LastSnapshotJson := j
    bridgeReady := NiumaMobileBrowser_IsChatBridgeReady()
    wv2 := NiumaMobileBrowser_ChatWv2()
    if !bridgeReady || !wv2 {
        reason := !bridgeReady ? "chat_not_ready" : "wv2_null"
        NiumaMobileBrowser_Log("DISPATCH", rid, "deferred reason=" . reason . " jsonLen=" . StrLen(j)
            . " meta=" . String(meta))
        try {
            global g_NiumaChatFrontReady, g_NiumaChatBridgeEpoch, g_FTB_WV2_Ready, FloatingToolbarChatDrawerOpen, g_FTB_WV2
            hasChatWv2 := IsObject(g_FTB_WV2) ? 1 : 0
            NiumaMobileBrowser_TraceOverlayPush(
                "SNAP deferred rid=" . rid
                . " reason=" . reason
                . " n=" . Integer(arrLen)
                . " err=" . String(err)
                . " meta=" . String(meta)
                . " | drawer=" . (FloatingToolbarChatDrawerOpen ? 1 : 0)
                . " chat_ready=" . (g_NiumaChatFrontReady ? 1 : 0)
                . " epoch=" . Integer(g_NiumaChatBridgeEpoch)
                . " chatWv2=" . hasChatWv2
                . " wv2Ready=" . (g_FTB_WV2_Ready ? 1 : 0),
                "warn"
            )
        } catch {
        }
        catch {
        }
        if !wv2
            NiumaMobileBrowser_ScheduleSnapshotRetry(reqId)
        return "deferred"
    }
    n := Integer(arrLen)
    NiumaMobileBrowser_NotifySnapshotReady(wv2, rid, n, url, err)
    posted := NiumaMobileBrowser_PostJsonToChatDirect(wv2, j, rid,
        "快照直通车离港(直投) arrLen=" . n . " jsonLen=" . StrLen(j) . " err=" . String(err))
    if posted {
        ; 双通道兜底：部分机器/状态下 WebMessage 可能丢包，但 ExecuteScript 注入仍可达。
        try {
            NiumaMobileBrowser_InjectHostJsonToChat(wv2, j, rid)
            NiumaMobileBrowser_TraceOverlayPush("SNAP delivered rid=" . rid . " n=" . n . " err=" . String(err) . " meta=" . String(meta) . " inject=1", "success")
            try SetTimer(NiumaMobileBrowser_CheckChatInjectConsumed.Bind(rid), -220)
            catch {
            }
        } catch {
            try NiumaMobileBrowser_TraceOverlayPush("SNAP delivered rid=" . rid . " n=" . n . " err=" . String(err) . " meta=" . String(meta) . " inject=0", "warn")
            catch {
            }
        }
        return "delivered"
    }
    NiumaMobileBrowser_Log("CHAT_OUT", rid, "快照直投失败 inject_async meta=" . String(meta))
    try NiumaMobileBrowser_TraceOverlayPush("SNAP post_failed rid=" . rid . " n=" . n . " meta=" . String(meta), "err")
    catch {
    }
    NiumaMobileBrowser_InjectHostJsonToChat(wv2, j, rid)
    NiumaMobileBrowser_ScheduleSnapshotRetry(reqId)
    return "failed"
}

NiumaMobileBrowser_FlushDeferredSnapshotToChat() {
    global g_NiumaMobile_LastSnapshotJson, g_NiumaMobile_ObserveReqId
    j := Trim(String(g_NiumaMobile_LastSnapshotJson))
    if (j = "" || StrLen(j) < 40)
        return false
    if !NiumaMobileBrowser_IsChatBridgeReady()
        return false
    rid := ""
    if RegExMatch(j, '"reqId"\s*:\s*"([^"]*)"', &mR)
        rid := mR[1]
    if (rid = "" && g_NiumaMobile_ObserveReqId != "")
        rid := String(g_NiumaMobile_ObserveReqId)
    arrLen := 0
    if RegExMatch(j, '"arrLen"\s*:\s*(\d+)', &mN)
        arrLen := Integer(mN[1])
    else if RegExMatch(j, '"count"\s*:\s*(\d+)', &mC)
        arrLen := Integer(mC[1])
    url := ""
    err := ""
    if RegExMatch(j, '"url"\s*:\s*"((?:[^"\\]|\\.)*)"', &mU)
        url := mU[1]
    if RegExMatch(j, '"error"\s*:\s*"((?:[^"\\]|\\.)*)"', &mE)
        err := mE[1]
    NiumaMobileBrowser_Log("HANDSHAKE", rid, "flush deferred len=" . StrLen(j))
    try NiumaMobileBrowser_TraceOverlayPush("HANDSHAKE flush deferred rid=" . rid . " n=" . arrLen . " err=" . String(err), "warn")
    catch {
    }
    return NiumaMobileBrowser_SnapshotDispatcher(j, rid, arrLen, url, err, "flush") = "delivered"
}

NiumaMobileBrowser_QueueSnapshotToChat(items, url := "", err := "", truncated := false, total := 0, reqId := "") {
    global g_NiumaMobile_LastElementsJson, g_NiumaMobile_LastElementsCount, g_NiumaMobile_LastKnownUrl
    rid := String(reqId)
    arrLen := g_NiumaMobile_LastElementsCount > 0 ? g_NiumaMobile_LastElementsCount
        : ((items is Array) ? items.Length : 0)
    tot := total ? Integer(total) : arrLen
    ; 调用方在 label_parse_empty 等分支下可能未传 url，导致前端显示“(无 URL)”
    if (String(url) = "") {
        try {
            global g_NiumaMobile_WV2
            if g_NiumaMobile_WV2
                url := String(g_NiumaMobile_WV2.SourceUri)
        } catch {
        }
        if (String(url) = "" && String(g_NiumaMobile_LastKnownUrl) != "")
            url := String(g_NiumaMobile_LastKnownUrl)
    }
    rawElementsJson := "[]"
    if (g_NiumaMobile_LastElementsJson != "[]" && g_NiumaMobile_LastElementsCount > 0)
        rawElementsJson := g_NiumaMobile_LastElementsJson
    else if (items is Array) && items.Length
        rawElementsJson := NiumaMobileBrowser_BuildCompactElementsJson(items)
    if (SubStr(Trim(rawElementsJson), 1, 1) != "[") {
        NiumaMobileBrowser_Log("CHAT_OUT", rid, "host_browser_snapshot snapshot 非数组，回退 []")
        rawElementsJson := "[]"
    }
    if (arrLen > 0)
        err := ""
    finalSafePayload := '{"type":"host_browser_snapshot"'
        . ',"reqId":"' . NiumaMobileBrowser_EscapeJsonStr(rid) . '"'
        . ',"count":' . arrLen . ',"arrLen":' . arrLen
        . ',"url":"' . NiumaMobileBrowser_EscapeJsonStr(String(url)) . '"'
        . ',"error":"' . NiumaMobileBrowser_EscapeJsonStr(String(err)) . '"'
        . ',"truncated":' . (truncated ? "true" : "false")
        . ',"totalCandidates":' . tot
        . ',"snapshot":' . rawElementsJson . '}'
    if (finalSafePayload = "" || StrLen(finalSafePayload) < 40) {
        NiumaMobileBrowser_Log("CHAT_OUT", rid, "host_browser_snapshot 直通车 JSON 过短")
        return false
    }
    r := NiumaMobileBrowser_SnapshotDispatcher(finalSafePayload, rid, arrLen, url, err, "queue")
    if (r = "failed") {
        NiumaMobileBrowser_ScheduleSnapshotRetry(reqId)
        return false
    }
    return true
}

NiumaMobileBrowser_ParseCompactItemsJson(itemsJson) {
    items := []
    j := Trim(String(itemsJson))
    if (j = "" || j = "[]")
        return items
    pos := 1
    while RegExMatch(j, '"id"\s*:\s*(\d+)', &mId, pos) {
        id := Integer(mId[1])
        chunkStart := mId.Pos
        nextPos := StrLen(j) + 1
        if RegExMatch(j, '"id"\s*:\s*\d+', &mNext, chunkStart + 4)
            nextPos := mNext.Pos
        chunk := SubStr(j, chunkStart, nextPos - chunkStart)
        el := Map("id", id)
        if RegExMatch(chunk, '"tag"\s*:\s*"([^"]*)"', &mt)
            el["tag"] := mt[1]
        if RegExMatch(chunk, '"type"\s*:\s*"([^"]*)"', &mty)
            el["type"] := mty[1]
        if RegExMatch(chunk, '"text"\s*:\s*"((?:\\.|[^"\\])*)"', &mtx)
            el["text"] := StrReplace(StrReplace(mtx[1], '\"', '"'), '\\', '\')
        if RegExMatch(chunk, '"hint"\s*:\s*"([^"]*)"', &mh)
            el["hint"] := mh[1]
        if RegExMatch(chunk, '"role"\s*:\s*"([^"]*)"', &mr)
            el["role"] := mr[1]
        if RegExMatch(chunk, '"roleHint"\s*:\s*"([^"]*)"', &mrh)
            el["roleHint"] := mrh[1]
        if RegExMatch(chunk, '"sel"\s*:\s*"([^"]*)"', &ms)
            el["sel"] := ms[1]
        items.Push(el)
        pos := chunkStart + StrLen(chunk)
        if (pos <= chunkStart)
            pos += 4
    }
    return items
}

NiumaMobileBrowser_ParseItemsArrayJson(itemsJson) {
    items := []
    j := Trim(String(itemsJson))
    if (j = "" || j = "[]")
        return items
    try {
        arr := NiumaMobileBrowser_CallFunc("Jxon_Load", j)
        if (arr is Array) {
            for , el in arr {
                if (el is Map)
                    items.Push(el)
            }
            if (items.Length > 0)
                return items
        }
    } catch {
    }
    return NiumaMobileBrowser_ParseCompactItemsJson(j)
}

NiumaMobileBrowser_ExtractItemsJson(s, &outItemsJson, &outCount) {
    outItemsJson := "[]"
    outCount := 0
    pos := InStr(s, '"items":[')
    if !pos
        pos := InStr(s, '"items" : [')
    if !pos
        return false
    start := InStr(s, "[", false, pos)
    if !start
        return false
    i := start
    depth := 0
    inQuote := false
    esc := false
    len := StrLen(s)
    while (i <= len) {
        ch := SubStr(s, i, 1)
        if inQuote {
            if esc {
                esc := false
            } else if (ch = "\") {
                esc := true
            } else if (ch = '"') {
                inQuote := false
            }
        } else {
            if (ch = '"') {
                inQuote := true
            } else if (ch = "[") {
                depth += 1
            } else if (ch = "]") {
                depth -= 1
                if (depth = 0) {
                    outItemsJson := SubStr(s, start, i - start + 1)
                    ; 粗略计数：统计 "id": 出现次数
                    outCount := 0
                    p := 1
                    while (p := InStr(outItemsJson, '"id":', false, p)) {
                        outCount += 1
                        p += 4
                    }
                    return true
                }
            }
        }
        i += 1
    }
    return false
}

NiumaMobileBrowser_ScheduleSnapshotRetry(reqId := "") {
    global g_NiumaMobile_SnapshotRetryReqId, g_NiumaMobile_SnapshotRetryCount
    rid := String(reqId)
    if (rid = "")
        rid := "noid"
    if (g_NiumaMobile_SnapshotRetryReqId != rid) {
        g_NiumaMobile_SnapshotRetryReqId := rid
        g_NiumaMobile_SnapshotRetryCount := 0
    }
    if (g_NiumaMobile_SnapshotRetryCount >= 12)
        return false
    g_NiumaMobile_SnapshotRetryCount += 1
    NiumaMobileBrowser_Log("CHAT_OUT", rid, "host_browser_snapshot retry count=" . g_NiumaMobile_SnapshotRetryCount)
    ; 使用缓存快照（g_NiumaMobile_LastSnapshot），避免把很大的 items 再次序列化
    try SetTimer(NiumaMobileBrowser_PushCachedSnapshot.Bind(reqId), -800)
    catch {
    }
    return true
}

NiumaMobileBrowser_EscapeJsonStr(s) {
    esc := StrReplace(String(s), "\", "\\")
    esc := StrReplace(esc, '"', '\"')
    esc := StrReplace(esc, "`r", "\r")
    esc := StrReplace(esc, "`n", "\n")
    esc := StrReplace(esc, "`t", "\t")
    ; JSON 字符串禁止未转义的控制字符（0x00-0x1F）
    try {
        esc := RegExReplace(esc, "[\x00-\x1F]", NiumaMobileBrowser_JsonEscapeCtl)
    } catch {
    }
    return esc
}

NiumaMobileBrowser_JsonEscapeCtl(m) {
    ch := m[0]
    n := Ord(ch)
    return "\u" . Format("{:04X}", n)
}

NiumaMobileBrowser_EscapeJsSingleQuoted(s) {
    esc := StrReplace(String(s), "\", "\\")
    esc := StrReplace(esc, "'", "\'")
    esc := StrReplace(esc, "`r", "\r")
    esc := StrReplace(esc, "`n", "\n")
    ; JS 字符串字面量禁用 U+2028/U+2029（会导致 ExecuteScriptAsync 语法错误/注入不生效）
    esc := StrReplace(esc, Chr(0x2028), "\u2028")
    esc := StrReplace(esc, Chr(0x2029), "\u2029")
    return esc
}

; PostWebMessage 失败时的兜底：异步注入，禁止 .await 阻塞 AHK 消息循环（大 JSON 会 TimeoutError 并拖死队列）。
NiumaMobileBrowser_InjectHostJsonToChat(wv2, jsonStr, reqId := "") {
    if !wv2
        return false
    j := Trim(String(jsonStr))
    if (j = "")
        return false
    rid := NiumaMobileBrowser_EscapeJsSingleQuoted(String(reqId))
    ; 先探测注入入口是否存在，避免“注入成功但未消费”无从判断
    try {
        probe := wv2.ExecuteScriptAsync("(function(){try{return String(typeof window.__niumaHostInject);}catch(e){return 'err';}})();").await(180)
        p := Trim(String(probe))
        if (p != "" && p != "null") {
            try NiumaMobileBrowser_TraceOverlayPush("INJECT probe rid=" . String(reqId) . " typeof __niumaHostInject=" . p, (InStr(p, "function") ? "success" : "warn"))
            catch {
            }
        }
    } catch {
    }
    js := "(function(){try{var ok=0,why='';" .
        "if(window.__niumaHostInject){" .
        "window.__niumaHostInject('" . NiumaMobileBrowser_EscapeJsSingleQuoted(j) . "');ok=1;why='injected';" .
        "}else{ok=0;why='no_inject';}" .
        "try{if(window.chrome&&window.chrome.webview&&window.chrome.webview.postMessage){" .
        "window.chrome.webview.postMessage({type:'niuma_inject_ack',reqId:'" . rid . "',ok:!!ok,why:String(why)});" .
        "}}catch(_e){}" .
        "return ok?'ok':why;" .
        "}catch(e){try{if(window.chrome&&window.chrome.webview&&window.chrome.webview.postMessage){" .
        "window.chrome.webview.postMessage({type:'niuma_inject_ack',reqId:'" . rid . "',ok:false,why:'err',err:String(e&&e.message||e)});" .
        "}}catch(_e2){}return 'err:' + String(e&&e.message||e);}})();"
    try {
        wv2.ExecuteScriptAsync(js)
        return true
    } catch as e {
        NiumaMobileBrowser_Log("CHAT_OUT", reqId, "host_inject_async failed err=" . String(e.Message))
        try NiumaMobileBrowser_TraceOverlayPush("INJECT ExecuteScriptAsync failed rid=" . String(reqId) . " err=" . String(e.Message), "err")
        catch {
        }
    }
    return false
}

; 兜底注入：不在脚本字面量里塞 10KB+ JSON，改为在 Chat WebView 内通过 HostObject 拉取宿主缓存快照，再喂给 __niumaHostInject。
NiumaMobileBrowser_InjectCachedSnapshotViaHostObject(wv2, reqId := "") {
    if !wv2
        return false
    rid := NiumaMobileBrowser_EscapeJsSingleQuoted(String(reqId))
    ; 不依赖 ExecuteScriptAsync 等待 Promise（可能回 {}）；采用“启动异步→写入窗口变量→宿主轮询”。
    jsStart := "(async function(){try{" .
        "window.__NIUMA_HOSTOBJ_INJECT_STATUS__={rid:'" . rid . "',state:'started',at:Date.now(),err:''};" .
        "if(typeof window.__niumaHostobjPullSnapshot==='function'){" .
        "try{var ok=false;var detail='';" .
        "if(typeof window.__niumaHostobjPullSnapshotDiag==='function'){" .
        "var r=await window.__niumaHostobjPullSnapshotDiag('" . rid . "');" .
        "ok=!!(r&&r.ok);detail=(r&&((r.reason||'') + (r.detail?(' ' + r.detail):'')))||'';" .
        "window.__NIUMA_HOSTOBJ_INJECT_STATUS__.bridge='__niumaHostobjPullSnapshotDiag';" .
        "}else{" .
        "ok=await window.__niumaHostobjPullSnapshot('" . rid . "');" .
        "window.__NIUMA_HOSTOBJ_INJECT_STATUS__.bridge='__niumaHostobjPullSnapshot';" .
        "}" .
        "window.__NIUMA_HOSTOBJ_INJECT_STATUS__.state=ok?'ok':'err';" .
        "if(!ok) window.__NIUMA_HOSTOBJ_INJECT_STATUS__.err=detail||'hostobj_pull_snapshot_failed';" .
        "return ok?'dispatch':('err:' + (detail||'hostobj_pull_snapshot_failed'));}catch(eP){window.__NIUMA_HOSTOBJ_INJECT_STATUS__.state='err';window.__NIUMA_HOSTOBJ_INJECT_STATUS__.bridge='__niumaHostobjPullSnapshot';window.__NIUMA_HOSTOBJ_INJECT_STATUS__.err=String(eP&&eP.message||eP);return 'err:' + String(eP&&eP.message||eP);}}" .
        "var host=(window.chrome&&window.chrome.webview&&window.chrome.webview.hostObjects)||null;" .
        "if(!host){window.__NIUMA_HOSTOBJ_INJECT_STATUS__.state='no_hostobj';return 'no_hostobj';}" .
        "var ahk=null;var bridgeKind='';" .
        "if(host.sync&&host.sync.ahk){ahk=host.sync.ahk;bridgeKind='sync.ahk';}" .
        "else if(host.ahk){ahk=host.ahk;bridgeKind='ahk(async)';}" .
        "else {window.__NIUMA_HOSTOBJ_INJECT_STATUS__.state='no_hostobj_ahk';return 'no_hostobj_ahk';}" .
        "var raw=null;" .
        "function _read(){if(!ahk) return null;" .
        "if(typeof ahk.GetLatestSnapshotCache==='function') return ahk.GetLatestSnapshotCache();" .
        "if(typeof ahk.GetBrowserSnapshot==='function') return ahk.GetBrowserSnapshot();" .
        "return null;}" .
        "function _read1(){if(!ahk) return null;" .
        "if(typeof ahk.GetLatestSnapshotCache==='function') return ahk.GetLatestSnapshotCache('');" .
        "if(typeof ahk.GetBrowserSnapshot==='function') return ahk.GetBrowserSnapshot('');" .
        "return null;}" .
        "try{raw=_read();}catch(e0){try{raw=_read1();}catch(e1){window.__NIUMA_HOSTOBJ_INJECT_STATUS__.state='err';window.__NIUMA_HOSTOBJ_INJECT_STATUS__.err=String(e1&&e1.message||e1||e0&&e0.message||e0);window.__NIUMA_HOSTOBJ_INJECT_STATUS__.bridge=bridgeKind;return 'err:' + String(e1&&e1.message||e1||e0&&e0.message||e0);}}" .
        "if(raw&&typeof raw.then==='function'){try{raw=await raw;}catch(e2){window.__NIUMA_HOSTOBJ_INJECT_STATUS__.state='err';window.__NIUMA_HOSTOBJ_INJECT_STATUS__.err=String(e2&&e2.message||e2);window.__NIUMA_HOSTOBJ_INJECT_STATUS__.bridge=bridgeKind;return 'err:' + String(e2&&e2.message||e2);}}" .
        "if(!raw){window.__NIUMA_HOSTOBJ_INJECT_STATUS__.state='empty';return 'empty';}" .
        "var s='';" .
        "try{if(typeof raw==='string') s=raw; else s=String(raw);}catch(es0){try{if(raw&&typeof raw.toString==='function') s=raw.toString();}catch(es1){s='';}}" .
        "if(!s){try{s=JSON.stringify(raw);}catch(es2){window.__NIUMA_HOSTOBJ_INJECT_STATUS__.state='err';window.__NIUMA_HOSTOBJ_INJECT_STATUS__.err='hostobj_raw_to_string_failed: ' + String(es2&&es2.message||es2);window.__NIUMA_HOSTOBJ_INJECT_STATUS__.bridge=bridgeKind;return 'err:' + String(es2&&es2.message||es2);}}" .
        "if(!window.__niumaHostInject){window.__NIUMA_HOSTOBJ_INJECT_STATUS__.state='no_inject';return 'no_inject';}" .
        "try{window.__niumaHostInject(s);window.__NIUMA_HOSTOBJ_INJECT_STATUS__.state='ok';window.__NIUMA_HOSTOBJ_INJECT_STATUS__.bridge=bridgeKind;}catch(ei){window.__NIUMA_HOSTOBJ_INJECT_STATUS__.state='err';window.__NIUMA_HOSTOBJ_INJECT_STATUS__.err=String(ei&&ei.message||ei);window.__NIUMA_HOSTOBJ_INJECT_STATUS__.bridge=bridgeKind;return 'err:' + String(ei&&ei.message||ei);}" .
        "return 'dispatch';" .
        "}catch(e){try{window.__NIUMA_HOSTOBJ_INJECT_STATUS__.state='err';window.__NIUMA_HOSTOBJ_INJECT_STATUS__.err=String(e&&e.message||e);}catch(_e){}return 'err:' + String(e&&e.message||e);}})();"
    okStart := false
    try {
        wv2.ExecuteScriptAsync(jsStart)
        okStart := true
    } catch as e {
        try NiumaMobileBrowser_TraceOverlayPush("INJECT hostobj start failed rid=" . String(reqId) . " err=" . e.Message, "err")
        catch {
        }
        return false
    }
    if okStart {
        try NiumaMobileBrowser_TraceOverlayPush("INJECT hostobj dispatch rid=" . String(reqId) . " ret=dispatch", "warn")
        catch {
        }
        try SetTimer(NiumaMobileBrowser_CheckHostObjInjectStatus.Bind(String(reqId), 0), -520)
        catch {
        }
        return true
    }
    return false
}

NiumaMobileBrowser_CheckHostObjInjectStatus(reqId, attempt, *) {
    if (attempt >= 6)
        return
    wv2 := NiumaMobileBrowser_ChatWv2()
    rid := String(reqId)
    if !wv2 {
        try NiumaMobileBrowser_TraceOverlayPush("INJECT hostobj status abort: ChatWv2 为空 rid=" . rid, "err")
        catch {
        }
        return
    }
    js := "(function(){try{return JSON.stringify(window.__NIUMA_HOSTOBJ_INJECT_STATUS__||null);}catch(e){return 'null';}})();"
    try {
        raw := wv2.ExecuteScriptAsync(js).await(260)
        s := Trim(String(raw))
        if (SubStr(s, 1, 1) = '"')
            s := NiumaMobileBrowser_UnquoteScriptResult(s)
        s2 := Trim(String(s))
        ; WebView2 可能返回 {\"k\":\"v\"} 形式转义 JSON
        if (InStr(s2, '{\"') || InStr(s2, '\"state\"')) {
            try {
                s2 := StrReplace(s2, "\\\\", "\")
                s2 := StrReplace(s2, '\"', '"')
            } catch {
            }
        }
        if (s2 = "" || s2 = "null") {
            try SetTimer(NiumaMobileBrowser_CheckHostObjInjectStatus.Bind(rid, attempt + 1), -260)
            catch {
            }
            return
        }
        ; 仅提取 state/err，避免 Jxon_Load
        st := ""
        srid := ""
        if RegExMatch(s2, '"rid"\s*:\s*"([^"]+)"', &mR)
            srid := mR[1]
        if RegExMatch(s2, '"state"\s*:\s*"([^"]+)"', &mS)
            st := mS[1]
        eMsg := ""
        if RegExMatch(s2, '"err"\s*:\s*"((?:[^"\\]|\\.)*)"', &mE)
            eMsg := mE[1]
        if (srid != "" && srid != rid) {
            ; 旧状态，继续等本次 rid
            try SetTimer(NiumaMobileBrowser_CheckHostObjInjectStatus.Bind(rid, attempt + 1), -220)
            catch {
            }
            return
        }
        if (st = "") {
            try NiumaMobileBrowser_TraceOverlayPush("INJECT hostobj status rid=" . rid . " parse_failed raw=" . SubStr(s2, 1, 140), "warn")
            catch {
            }
            try SetTimer(NiumaMobileBrowser_CheckHostObjInjectStatus.Bind(rid, attempt + 1), -220)
            catch {
            }
            return
        }
        lvl := (st = "ok") ? "success" : (st = "started" ? "warn" : (InStr(st, "err") ? "err" : "warn"))
        try NiumaMobileBrowser_TraceOverlayPush("INJECT hostobj status rid=" . rid . " state=" . st . (eMsg != "" ? (" err=" . SubStr(eMsg, 1, 120)) : ""), lvl)
        catch {
        }
        if (st = "ok") {
            try SetTimer(NiumaMobileBrowser_CheckChatInjectConsumedHostObj.Bind(rid), -220)
            catch {
            }
            return
        }
        if (st = "started") {
            try SetTimer(NiumaMobileBrowser_CheckHostObjInjectStatus.Bind(rid, attempt + 1), -260)
            catch {
            }
            return
        }
        ; 非 ok 且非 started：终止
        return
    } catch as e {
        try NiumaMobileBrowser_TraceOverlayPush("INJECT hostobj status check failed rid=" . rid . " err=" . e.Message, "warn")
        catch {
        }
        try SetTimer(NiumaMobileBrowser_CheckHostObjInjectStatus.Bind(rid, attempt + 1), -260)
        catch {
        }
    }
}

NiumaMobileBrowser_CheckChatInjectConsumedHostObj(reqId, *) {
    wv2 := NiumaMobileBrowser_ChatWv2()
    rid := String(reqId)
    if !wv2 {
        try NiumaMobileBrowser_TraceOverlayPush("CHAT HostObj 消费检查 abort: ChatWv2 为空 rid=" . rid, "err")
        catch {
        }
        return
    }
    js := "(function(){try{return JSON.stringify(window.__NIUMA_LAST_HOSTINJECT__||null);}catch(e){return 'null';}})();"
    try {
        raw := wv2.ExecuteScriptAsync(js).await(260)
        s := Trim(String(raw))
        if (SubStr(s, 1, 1) = '"')
            s := NiumaMobileBrowser_UnquoteScriptResult(s)
        s2 := Trim(String(s))
        if (s2 = "" || s2 = "null") {
            try NiumaMobileBrowser_TraceOverlayPush("CHAT HostObj 注入仍未被消费 rid=" . rid . " (var=null)", "err")
            catch {
            }
            return
        }
        ; HostObject 拉取链路已完成（INJECT hostobj status=ok）时，__NIUMA_LAST_HOSTINJECT__ 可能仍停留在 parse_error。
        ; 此时不应再用它判定 rid，否则会产生误报。
        if InStr(s2, "host_inject_parse_error") {
            try NiumaMobileBrowser_TraceOverlayPush("CHAT HostObj 拉取已完成 rid=" . rid . " (last_inject=parse_error)", "success")
            catch {
            }
            return
        }
        if (rid != "" && InStr(s2, '"reqId":"' . rid . '"')) {
            NiumaMobileBrowser_TraceOverlayPush("CHAT HostObj 注入已消费 rid=" . rid, "success")
        } else {
            try NiumaMobileBrowser_TraceOverlayPush("CHAT HostObj 已消费但 rid 不匹配 rid=" . rid . " raw=" . SubStr(s2, 1, 80), "warn")
            catch {
            }
        }
    } catch as e {
        try NiumaMobileBrowser_TraceOverlayPush("CHAT HostObj 消费检查失败 rid=" . rid . " err=" . e.Message, "warn")
        catch {
        }
    }
}

NiumaMobileBrowser_BuildCompactElementsJson(items) {
    if !(items is Array) || !items.Length
        return "[]"
    parts := []
    for , el in items {
        if !(el is Map)
            continue
        id := el.Has("id") ? Integer(el["id"]) : 0
        tag := el.Has("tag") ? NiumaMobileBrowser_EscapeJsonStr(el["tag"]) : ""
        typ := el.Has("type") ? NiumaMobileBrowser_EscapeJsonStr(el["type"]) : ""
        txt := el.Has("text") ? NiumaMobileBrowser_EscapeJsonStr(SubStr(String(el["text"]), 1, 120)) : ""
        hint := el.Has("hint") ? NiumaMobileBrowser_EscapeJsonStr(SubStr(String(el["hint"]), 1, 60)) : ""
        role := el.Has("role") ? NiumaMobileBrowser_EscapeJsonStr(el["role"]) : ""
        roleHint := el.Has("roleHint") ? NiumaMobileBrowser_EscapeJsonStr(el["roleHint"]) : ""
        sel1 := el.Has("selectorTop1") ? NiumaMobileBrowser_EscapeJsonStr(SubStr(String(el["selectorTop1"]), 1, 160)) : ""
        parts.Push('{"id":' . id . ',"tag":"' . tag . '","type":"' . typ . '","text":"' . txt . '","hint":"' . hint . '","role":"' . role . '","roleHint":"' . roleHint . '","sel":"' . sel1 . '"}')
    }
    return "[" . (parts.Length ? parts.Join(",") : "") . "]"
}

NiumaMobileBrowser_PushCachedSnapshot(reqId := "") {
    global g_NiumaMobile_LastSnapshot, g_NiumaMobile_WV2, g_NiumaMobile_LastElementsCount, g_NiumaMobile_LastSnapshotJson
    cnt := g_NiumaMobile_LastElementsCount > 0 ? g_NiumaMobile_LastElementsCount
        : ((g_NiumaMobile_LastSnapshot is Array) ? g_NiumaMobile_LastSnapshot.Length : 0)
    url := ""
    if g_NiumaMobile_WV2 {
        try url := g_NiumaMobile_WV2.SourceUri
        catch {
        }
    }
    if cnt < 1 {
        if NiumaMobileBrowser_IsChatBridgeReady() && Trim(String(g_NiumaMobile_LastSnapshotJson)) != ""
            return NiumaMobileBrowser_FlushDeferredSnapshotToChat()
        if (reqId != "")
            return NiumaMobileBrowser_QueueSnapshotToChat([], url, "", false, 0, reqId)
        return false
    }
    r := NiumaMobileBrowser_QueueSnapshotToChat(g_NiumaMobile_LastSnapshot, url, "", false, cnt, reqId)
    if !r
        return false
    if NiumaMobileBrowser_IsChatBridgeReady() {
        j := Trim(String(g_NiumaMobile_LastSnapshotJson))
        wv2 := NiumaMobileBrowser_ChatWv2()
        if wv2 && j != ""
            NiumaMobileBrowser_InjectHostJsonToChat(wv2, j, reqId)
    }
    return true
}

NiumaMobileBrowser_NormalizeScriptRaw(raw) {
    s := Trim(String(raw))
    if (s = "")
        return ""
    if (SubStr(s, 1, 1) = '"')
        s := NiumaMobileBrowser_UnquoteScriptResult(s)
    if ((SubStr(s, 1, 2) = "{\") || (SubStr(s, 1, 2) = "[\")) {
        s := StrReplace(s, "\\\\", "\")
        s := StrReplace(s, '\"', '"')
    } else if InStr(s, '\"ok\"') || InStr(s, '{\"ok\"') || InStr(s, '{\"ok\":') {
        s := StrReplace(s, "\\\\", "\")
        s := StrReplace(s, '\"', '"')
    }
    if (SubStr(s, 1, 1) != "{" && SubStr(s, 1, 1) != "[") {
        i := InStr(s, "{")
        j := InStr(s, "}",, -1)
        if (i && j && j > i)
            s := SubStr(s, i, j - i + 1)
    }
    return s
}

NiumaMobileBrowser_ScriptJsonHasOkTrue(s) {
    if RegExMatch(s, 'i)"ok"\s*:\s*(?:true|1)\b')
        return true
    if InStr(s, '"ok":true') || InStr(s, '"ok":1') || InStr(s, '\"ok\":true') || InStr(s, '\\"ok\\":true')
        return true
    return false
}

NiumaMobileBrowser_ScriptJsonFieldTruthy(s, fieldName) {
    return RegExMatch(s, 'i)"' . fieldName . '"\s*:\s*(?:true|1)\b')
}

NiumaMobileBrowser_ScriptJsonExtractStringField(s, fieldName) {
    if RegExMatch(s, 'i)"' . fieldName . '"\s*:\s*"([^"]*)"', &m)
        return m[1]
    return ""
}

NiumaMobileBrowser_InferActMapFromRaw(raw) {
    s := NiumaMobileBrowser_NormalizeScriptRaw(raw)
    if (s = "")
        return 0
    if RegExMatch(s, 'i)"ok"\s*:\s*false\b') {
        err := NiumaMobileBrowser_ScriptJsonExtractStringField(s, "error")
        m := Map("ok", false, "error", err != "" ? err : "script_failed", "inferred", true)
        if RegExMatch(s, 'i)"inputOk"\s*:\s*false\b')
            m["inputOk"] := false
        if RegExMatch(s, 'i)"sendOk"\s*:\s*false\b')
            m["sendOk"] := false
        if NiumaMobileBrowser_ScriptJsonFieldTruthy(s, "inputOk")
            m["inputOk"] := true
        if NiumaMobileBrowser_ScriptJsonFieldTruthy(s, "sendOk")
            m["sendOk"] := true
        if NiumaMobileBrowser_ScriptJsonFieldTruthy(s, "domAssertOk")
            m["domAssertOk"] := true
        et := NiumaMobileBrowser_ScriptJsonExtractStringField(s, "editorText")
        if (et != "")
            m["editorText"] := et
        mt := NiumaMobileBrowser_ScriptJsonExtractStringField(s, "methods")
        if (mt != "")
            m["methods"] := mt
        return m
    }
    if !NiumaMobileBrowser_ScriptJsonHasOkTrue(s)
        return 0
    m := Map("ok", true, "inferred", true)
    if RegExMatch(s, 'i)"inputOk"\s*:\s*false\b') {
        m["ok"] := false
        m["inputOk"] := false
    } else if NiumaMobileBrowser_ScriptJsonFieldTruthy(s, "inputOk")
        m["inputOk"] := true
    if RegExMatch(s, 'i)"sendOk"\s*:\s*false\b')
        m["sendOk"] := false
    else if NiumaMobileBrowser_ScriptJsonFieldTruthy(s, "sendOk")
        m["sendOk"] := true
    if NiumaMobileBrowser_ScriptJsonFieldTruthy(s, "domAssertOk")
        m["domAssertOk"] := true
    if NiumaMobileBrowser_ScriptJsonFieldTruthy(s, "chatSubmit")
        m["chatSubmit"] := true
    if (m.Has("inputOk") && !m["inputOk"])
        m["ok"] := false
    if RegExMatch(s, 'i)"submitted"\s*:\s*true')
        m["submitted"] := true
    if RegExMatch(s, 'i)"deferred"\s*:\s*true')
        m["deferred"] := true
    tag := NiumaMobileBrowser_ScriptJsonExtractStringField(s, "tag")
    if (tag != "")
        m["tag"] := tag
    et := NiumaMobileBrowser_ScriptJsonExtractStringField(s, "editorText")
    if (et != "")
        m["editorText"] := et
    mt := NiumaMobileBrowser_ScriptJsonExtractStringField(s, "methods")
    if (mt != "")
        m["methods"] := mt
    return m
}

NiumaMobileBrowser_ParseScriptJson(raw) {
    s := NiumaMobileBrowser_NormalizeScriptRaw(raw)
    if (s = "")
        return Map("ok", false, "error", "empty_result")
    try {
        obj := ""
        try obj := Jxon_Load(s)
        catch {
            obj := NiumaMobileBrowser_CallFunc("Jxon_Load", s)
        }
        if (obj is Map) {
            if (obj.Count > 0)
                return NiumaMobileBrowser_NormalizeActBoolMap(obj)
        }
        if (obj is Array)
            return Map("ok", true, "items", obj)
        if (obj is String) {
            inner := Trim(String(obj))
            if (inner != "" && (SubStr(inner, 1, 1) = "{" || SubStr(inner, 1, 1) = "[")) {
                try {
                    obj2 := Jxon_Load(inner)
                    if (obj2 is Map)
                        return NiumaMobileBrowser_NormalizeActBoolMap(obj2)
                    if (obj2 is Array)
                        return Map("ok", true, "items", obj2)
                } catch {
                }
            }
        }
    } catch {
    }
    inferred := NiumaMobileBrowser_InferActMapFromRaw(raw)
    if (IsObject(inferred))
        return inferred
    return Map("ok", false, "error", "json_parse_failed", "raw", s)
}

NiumaMobileBrowser_AnalyzePage(callback := 0, silent := false) {
    global g_NiumaMobile_WV2, g_NiumaMobile_AiPaused, g_NiumaMobile_PendingAnalyzeCb, g_NiumaMobile_SilentRefresh, g_NiumaMobile_AnalyzeWatchdog
    if g_NiumaMobile_AiPaused
        return false
    global g_NiumaMobile_ObserveReqId
    if (silent && g_NiumaMobile_ObserveReqId != "")
        return false
    if !g_NiumaMobile_WV2 {
        if IsObject(callback)
            try callback.Call([], "", "browser_not_open")
        catch {
        }
        return false
    }
    if !NiumaMobileBrowser_EnsureLabelScript() {
        if IsObject(callback)
            try callback.Call([], "", "label_script_missing")
        catch {
        }
        return false
    }
    global JS_MOBILE_LABELING
    ; 进行中的 Chat observe 回调不要被静默打标覆盖
    if (silent && IsObject(g_NiumaMobile_PendingAnalyzeCb) && !IsObject(callback))
        return false
    g_NiumaMobile_PendingAnalyzeCb := callback
    g_NiumaMobile_SilentRefresh := !!silent
    try {
        if g_NiumaMobile_AnalyzeWatchdog
            SetTimer(g_NiumaMobile_AnalyzeWatchdog, 0)
    } catch {
    }
    g_NiumaMobile_AnalyzeWatchdog := NiumaMobileBrowser_OnAnalyzeWatchdog.Bind(callback)
    SetTimer(g_NiumaMobile_AnalyzeWatchdog, -22000)
    global g_NiumaMobile_ObserveReqId
    obsRid := g_NiumaMobile_ObserveReqId
    NiumaMobileBrowser_Log("JOB_LAUNCH", obsRid, "analyze labeling silent=" . (silent ? 1 : 0))
    try {
        raw := g_NiumaMobile_WV2.ExecuteScriptAsync(JS_MOBILE_LABELING).await(22000)
        try NiumaMobileBrowser_OnAnalyzeDone(raw)
        catch as eDone {
            NiumaMobileBrowser_Log("JOB_CALLBACK", obsRid, "OnAnalyzeDone err=" . eDone.Message)
            if (obsRid != "" && !silent)
                NiumaMobileBrowser_DeliverErrorToChat("analyze_done_failed: " . eDone.Message, obsRid, "label")
            if IsObject(callback)
                try callback.Call([], "", eDone.Message)
                catch {
                }
            return false
        }
        return true
    } catch as e {
        try SetTimer(g_NiumaMobile_AnalyzeWatchdog, 0)
        catch {
        }
        g_NiumaMobile_AnalyzeWatchdog := 0
        g_NiumaMobile_PendingAnalyzeCb := 0
        NiumaMobileBrowser_Log("JOB_CALLBACK", obsRid, "analyze ok=0 err=" . e.Message)
        if (obsRid != "" && !silent)
            NiumaMobileBrowser_DeliverErrorToChat("script_exec_failed: " . e.Message, obsRid, "label")
        if IsObject(callback)
            try callback.Call([], "", e.Message)
        catch {
        }
        return false
    }
}

NiumaMobileBrowser_OnAnalyzeWatchdog(callback, *) {
    global g_NiumaMobile_PendingAnalyzeCb, g_NiumaMobile_AnalyzeWatchdog
    g_NiumaMobile_AnalyzeWatchdog := 0
    if !g_NiumaMobile_PendingAnalyzeCb
        return
    g_NiumaMobile_PendingAnalyzeCb := 0
    if IsObject(callback) {
        try callback.Call([], "", "analyze_timeout")
        catch {
        }
    }
}

NiumaMobileBrowser_OnAnalyzeDone(result) {
    global g_NiumaMobile_PendingAnalyzeCb, g_NiumaMobile_LastSnapshot, g_NiumaMobile_SilentRefresh, g_NiumaMobile_WV2, g_NiumaMobile_AnalyzeWatchdog
        , g_NiumaMobile_LastElementsJson, g_NiumaMobile_LastElementsCount
    try {
        if g_NiumaMobile_AnalyzeWatchdog
            SetTimer(g_NiumaMobile_AnalyzeWatchdog, 0)
    } catch {
    }
    g_NiumaMobile_AnalyzeWatchdog := 0
    cb := g_NiumaMobile_PendingAnalyzeCb
    g_NiumaMobile_PendingAnalyzeCb := 0
    silent := g_NiumaMobile_SilentRefresh
    g_NiumaMobile_SilentRefresh := false

    ; 先尝试直接从字符串里截取 items 数组 JSON，绕开 Jxon_Load 的兼容性问题
    s := Trim(String(result))
    if (SubStr(s, 1, 1) = '"')
        s := NiumaMobileBrowser_UnquoteScriptResult(s)
    ; 去除常见的 {\"ok\":...} 形式转义
    if InStr(s, '{\"ok\"') || InStr(s, '\"items\"') {
        s := StrReplace(s, "\\\\", "\")
        s := StrReplace(s, '\"', '"')
    }
    itemsJson := "[]"
    itemsCnt := 0
    if NiumaMobileBrowser_ExtractItemsJson(s, &itemsJson, &itemsCnt) {
        g_NiumaMobile_LastElementsJson := itemsJson
        g_NiumaMobile_LastElementsCount := itemsCnt
    } else {
        g_NiumaMobile_LastElementsJson := "[]"
        g_NiumaMobile_LastElementsCount := 0
    }

    ; Analyze 路径以字符串提取为主：避免对包含复杂网页文本的 items 数组做重度 Jxon_Load。
    items := []
    err := ""
    if RegExMatch(s, 'i)"ok"\s*:\s*false\b') {
        err := NiumaMobileBrowser_ScriptJsonExtractStringField(s, "error")
        if (err = "")
            err := "analyze_failed"
    } else {
        err := NiumaMobileBrowser_ScriptJsonExtractStringField(s, "error")
    }
    if (err = "" && RegExMatch(s, 'i)"skipped"\s*:\s*true\b'))
        err := "viewport_throttle"
    if (g_NiumaMobile_LastElementsCount > 0 && g_NiumaMobile_LastElementsJson != "" && g_NiumaMobile_LastElementsJson != "[]") {
        items := NiumaMobileBrowser_ParseItemsArrayJson(g_NiumaMobile_LastElementsJson)
    }
    if (items.Length < 1 && g_NiumaMobile_LastElementsCount > 0 && g_NiumaMobile_LastElementsJson != "" && g_NiumaMobile_LastElementsJson != "[]") {
        items := NiumaMobileBrowser_ParseCompactItemsJson(g_NiumaMobile_LastElementsJson)
    }
    if (g_NiumaMobile_LastElementsCount > 0) {
        if (err = "json_parse_failed" || err = "label_parse_empty")
            err := ""
    }
    global g_NiumaMobile_ObserveReqId
    obsReqId := g_NiumaMobile_ObserveReqId
    if (err = "" && items.Length = 0 && g_NiumaMobile_LastElementsCount < 1)
        err := "label_parse_empty"
    g_NiumaMobile_LastSnapshot := items
    rawHead := SubStr(String(result), 1, 220)
    NiumaMobileBrowser_Log("JOB_CALLBACK", obsReqId, "analyze items=" . items.Length . " err=" . err . " silent=" . (silent ? 1 : 0)
        . " extracted_cnt=" . g_NiumaMobile_LastElementsCount . " raw_head=" . rawHead)

    rawJson := s
    truncatedFlag := RegExMatch(s, 'i)"truncated"\s*:\s*true\b') ? true : false
    totalCandidates := 0
    if RegExMatch(s, 'i)"totalCandidates"\s*:\s*(\d+)', &mTot)
        totalCandidates := Integer(mTot[1])

    if (obsReqId != "" && !silent) {
        urlObs := ""
        try urlObs := g_NiumaMobile_WV2.SourceUri
        catch {
        }
        totObs := g_NiumaMobile_LastElementsCount > 0 ? g_NiumaMobile_LastElementsCount
            : (items.Length > 0 ? items.Length : 0)
        if (err = "json_parse_failed" && totObs > 0)
            err := ""
        try {
            NiumaMobileBrowser_QueueSnapshotToChat(items, urlObs, err,
                truncatedFlag,
                totalCandidates > 0 ? totalCandidates : totObs, obsReqId)
        } catch as eSnap {
            NiumaMobileBrowser_Log("JOB_CALLBACK", obsReqId, "QueueSnapshot err=" . eSnap.Message)
        }
    }

    if IsObject(cb) {
        try cb.Call(items, rawJson, err)
        catch {
        }
    }

    if !silent && !IsObject(cb) {
        url := ""
        try url := g_NiumaMobile_WV2.SourceUri
        catch {
        }
        NiumaMobileBrowser_QueueSnapshotToChat(items, url, err, truncatedFlag,
            totalCandidates > 0 ? totalCandidates : items.Length, obsReqId)
    }
}

NiumaMobileBrowser_RefreshLabels(delayMs := 500) {
    global g_NiumaMobile_LabelRefreshTimer, g_NiumaMobile_AiPaused
    if g_NiumaMobile_AiPaused
        return
    try {
        if g_NiumaMobile_LabelRefreshTimer
            SetTimer(g_NiumaMobile_LabelRefreshTimer, 0)
    } catch {
    }
    g_NiumaMobile_LabelRefreshTimer := NiumaMobileBrowser_DoRefreshLabels.Bind(delayMs)
    SetTimer(g_NiumaMobile_LabelRefreshTimer, -Max(50, Integer(delayMs)))
}

NiumaMobileBrowser_DoRefreshLabels(delayMs, *) {
    global g_NiumaMobile_LabelRefreshTimer, g_NiumaMobile_PendingAnalyzeCb, g_NiumaMobile_ObserveReqId
    g_NiumaMobile_LabelRefreshTimer := 0
    if g_NiumaMobile_PendingAnalyzeCb || (g_NiumaMobile_ObserveReqId != "")
        return
    NiumaMobileBrowser_AnalyzePage(0, true)
}

NiumaMobileBrowser_BuildClickScript(elementId) {
    global JS_MOBILE_CLICK_BY_ID
    if (JS_MOBILE_CLICK_BY_ID = "" && !NiumaMobileBrowser_EnsureLabelScripts())
        return ""
    id := Integer(elementId)
    if (id < 1)
        return ""
    return StrReplace(JS_MOBILE_CLICK_BY_ID, "__NIUMA_ID__", id)
}

NiumaMobileBrowser_BuildInputScript(elementId, text) {
    global JS_MOBILE_INPUT_BY_ID
    if (JS_MOBILE_INPUT_BY_ID = "" && !NiumaMobileBrowser_EnsureLabelScripts())
        return ""
    id := Integer(elementId)
    if (id < 1)
        return ""
    esc := NiumaMobileBrowser_CallFunc("Jxon_Dump", text)
    if (esc = "")
        esc := '""'
    s := StrReplace(JS_MOBILE_INPUT_BY_ID, "__NIUMA_ID__", id)
    return StrReplace(s, "__NIUMA_TEXT__", esc)
}

NiumaMobileBrowser_BuildDoubaoChatScript(elementId, text, sendOnly := false) {
    global JS_MOBILE_DOUBAO_CHAT
    if (JS_MOBILE_DOUBAO_CHAT = "" && !NiumaMobileBrowser_EnsureLabelScripts())
        return ""
    id := Integer(elementId)
    if (id < 1)
        id := 0
    esc := NiumaMobileBrowser_EmbedJsTextLiteral(text)
    s := StrReplace(JS_MOBILE_DOUBAO_CHAT, "__NIUMA_ID__", id)
    s := StrReplace(s, "__NIUMA_TEXT__", esc)
    return StrReplace(s, "__NIUMA_SEND_ONLY__", sendOnly ? "true" : "false")
}

NiumaMobileBrowser_BuildDoubaoFocusScript(elementId, text) {
    global JS_MOBILE_DOUBAO_FOCUS
    if (JS_MOBILE_DOUBAO_FOCUS = "" && !NiumaMobileBrowser_EnsureLabelScripts())
        return ""
    id := Integer(elementId)
    if (id < 1)
        id := 0
    esc := NiumaMobileBrowser_EmbedJsTextLiteral(text)
    s := StrReplace(JS_MOBILE_DOUBAO_FOCUS, "__NIUMA_ID__", id)
    return StrReplace(s, "__NIUMA_TEXT__", esc)
}

NiumaMobileBrowser_BuildDoubaoActivateScript(elementId) {
    global JS_MOBILE_DOUBAO_ACTIVATE
    if (JS_MOBILE_DOUBAO_ACTIVATE = "" && !NiumaMobileBrowser_EnsureLabelScripts())
        return ""
    id := Integer(elementId)
    if (id < 1)
        id := 0
    return StrReplace(JS_MOBILE_DOUBAO_ACTIVATE, "__NIUMA_ID__", id)
}

NiumaMobileBrowser_BuildDoubaoFillLabelScript(elementId, text) {
    global JS_MOBILE_DOUBAO_FILL_LABEL
    if (JS_MOBILE_DOUBAO_FILL_LABEL = "" && !NiumaMobileBrowser_EnsureLabelScripts())
        return ""
    id := Integer(elementId)
    if (id < 1)
        id := 0
    esc := NiumaMobileBrowser_EmbedJsTextLiteral(text)
    s := StrReplace(JS_MOBILE_DOUBAO_FILL_LABEL, "__NIUMA_ID__", id)
    return StrReplace(s, "__NIUMA_TEXT__", esc)
}

NiumaMobileBrowser_DismissOpenFileDialog() {
    try {
        if WinExist("ahk_class #32770") {
            winTitle := WinGetTitle("ahk_class #32770")
            if InStr(winTitle, "打开") || InStr(winTitle, "Open") {
                WinClose("ahk_class #32770")
                Sleep(80)
                return true
            }
        }
    } catch {
    }
    return false
}

NiumaMobileBrowser_IsDeepSeekPage(url := "") {
    u := url != "" ? String(url) : NiumaMobileBrowser_GetPageUrl()
    return InStr(u, "deepseek.com") > 0
}

NiumaMobileBrowser_IsGeminiPage(url := "") {
    u := url != "" ? String(url) : NiumaMobileBrowser_GetPageUrl()
    return InStr(u, "gemini.google") > 0
}

NiumaMobileBrowser_ShouldSkipPhysicalPaste() {
    global g_NiumaMobile_DeepseekJsFillOnly, g_NiumaMobile_GeminiJsFillOnly, g_NiumaMobile_ChatPlanActive
    return g_NiumaMobile_ChatPlanActive || g_NiumaMobile_DeepseekJsFillOnly || g_NiumaMobile_GeminiJsFillOnly
        || NiumaMobileBrowser_IsDeepSeekPage() || NiumaMobileBrowser_IsGeminiPage()
}

NiumaMobileBrowser_ApplyChatPlanPlatformFlags(platform) {
    global g_NiumaMobile_DeepseekJsFillOnly, g_NiumaMobile_GeminiJsFillOnly, g_NiumaMobile_ChatPlanPlatform
    p := Trim(String(platform))
    g_NiumaMobile_ChatPlanPlatform := p
    g_NiumaMobile_DeepseekJsFillOnly := (p = "deepseek")
    g_NiumaMobile_GeminiJsFillOnly := (p = "gemini")
}

NiumaMobileBrowser_ClearChatPlanPlatformFlags() {
    global g_NiumaMobile_DeepseekJsFillOnly, g_NiumaMobile_GeminiJsFillOnly, g_NiumaMobile_ChatPlanPlatform
    g_NiumaMobile_ChatPlanPlatform := ""
    g_NiumaMobile_DeepseekJsFillOnly := false
    g_NiumaMobile_GeminiJsFillOnly := false
}

NiumaMobileBrowser_NotifyChatPlanResult(parsed, elementId) {
    global g_NiumaMobile_ActReqId
    reqId := g_NiumaMobile_ActReqId
    ok := false
    err := ""
    if (parsed is Map) {
        idemSkip := parsed.Has("idempotentSkip") && parsed["idempotentSkip"]
        sendOk := parsed.Has("sendOk") && parsed["sendOk"]
        sentThread := parsed.Has("sentInThread") && parsed["sentInThread"]
        ok := idemSkip || sendOk || sentThread
        if parsed.Has("error")
            err := String(parsed["error"])
        if (sendOk || sentThread || idemSkip)
            err := ""
        if !ok && (parsed.Has("inputOk") && parsed["inputOk"]) && !sendOk && !sentThread && !idemSkip {
            if (err = "")
                err := "input_only_not_sent"
        }
    }
    NiumaMobileBrowser_Log("PLAN_PIPE", reqId, "chat_plan_result ok=" . (ok ? 1 : 0) . " err=" . err)
    NiumaMobileBrowser_QueueActToChat("host_browser_chat_plan_result", reqId, ok, err, "chat_plan", Integer(elementId), false, "chat_plan", parsed)
}

NiumaMobileBrowser_OnChatPlanDone(elementId, result) {
    global g_NiumaMobile_LastActInputText, g_NiumaMobile_ObserveReqId, g_NiumaMobile_ActReqId
        , g_NiumaMobile_SettlePending, g_NiumaMobile_SettleReqId, g_NiumaMobile_SettleNavPending
    parsed := NiumaMobileBrowser_ParseScriptJson(result)
    NiumaMobileBrowser_SetAiBusy(false)
    SetTimer(NiumaMobileBrowser_ClearVpThrottle.Bind(), -200)
    NiumaMobileBrowser_NotifyChatPlanResult(parsed, elementId)
    if !(parsed is Map)
        return
    settleMs := 120
    sentLike := (parsed.Has("sendOk") && parsed["sendOk"]) || (parsed.Has("sentInThread") && parsed["sentInThread"])
        || (parsed.Has("idempotentSkip") && parsed["idempotentSkip"])
    if sentLike {
        settleMs := 700
        if (parsed.Has("sendGateMs") && Integer(parsed["sendGateMs"]) > 0)
            settleMs := Max(settleMs, Integer(parsed["sendGateMs"]) + 350)
        rid := g_NiumaMobile_ObserveReqId != "" ? g_NiumaMobile_ObserveReqId : g_NiumaMobile_ActReqId
        g_NiumaMobile_SettlePending := false
        g_NiumaMobile_SettleNavPending := false
        g_NiumaMobile_SettleReqId := ""
        NiumaMobileBrowser_CancelSettleWatchdog()
        NiumaMobileBrowser_ScheduleAutoHideLabelsAfterChat(g_NiumaMobile_LastActInputText)
        if (rid != "")
            NiumaMobileBrowser_PushCachedSnapshot(rid)
        g_NiumaMobile_ObserveReqId := ""
        g_NiumaMobile_ActReqId := ""
        NiumaMobileBrowser_Log("PLAN_PIPE", rid, "chat_plan_sent skip_settle_observe")
        return
    }
    SetTimer(NiumaMobileBrowser_BeginPostActSettle.Bind(), -settleMs)
}

NiumaMobileBrowser_LaunchChatPlanPipe(elementId, text, platform, reqId := "") {
    global g_NiumaMobile_WV2, g_NiumaMobile_AiPaused, g_NiumaMobile_ActReqId, g_NiumaMobile_ObserveReqId
        , g_NiumaMobile_SettleReqId, g_NiumaMobile_ChatPlanActive
    rid := Trim(String(reqId))
    if (rid = "")
        rid := "plan-" . A_TickCount . "-" . Random(1000, 9999)
    if g_NiumaMobile_ChatPlanActive {
        NiumaMobileBrowser_QueueActToChat("host_browser_chat_plan_result", rid, false, "plan_pipe_busy", "chat_plan", Integer(elementId), false, "chat_plan")
        return false
    }
    if g_NiumaMobile_AiPaused {
        NiumaMobileBrowser_QueueActToChat("host_browser_chat_plan_result", rid, false, "ai_paused", "chat_plan", Integer(elementId), false, "chat_plan")
        return false
    }
    if !g_NiumaMobile_WV2 {
        NiumaMobileBrowser_QueueActToChat("host_browser_chat_plan_result", rid, false, "browser_not_ready", "chat_plan", Integer(elementId), false, "chat_plan")
        return false
    }
    if !NiumaMobileBrowser_EnsureLabelScripts() {
        NiumaMobileBrowser_QueueActToChat("host_browser_chat_plan_result", rid, false, "doubao_scripts_missing", "chat_plan", Integer(elementId), false, "chat_plan")
        return false
    }
    g_NiumaMobile_ActReqId := rid
    g_NiumaMobile_ObserveReqId := rid
    g_NiumaMobile_SettleReqId := rid
    NiumaMobileBrowser_SetAiBusy(true, false)
    NiumaMobileBrowser_SetInputBlocked(false, true)
    NiumaMobileBrowser_Log("PLAN_PIPE", rid, "launch platform=" . String(platform) . " textLen=" . StrLen(Trim(String(text))))
    SetTimer(NiumaMobileBrowser_ExecuteChatPlanPipe.Bind(Integer(elementId), String(text), String(platform), rid), -1)
    return true
}

NiumaMobileBrowser_ExecuteChatPlanPipe(elementId, text, platform, rid, *) {
    global g_NiumaMobile_WV2, g_NiumaMobile_ChatPlanActive, g_NiumaMobile_LastActInputText
    result := '{"ok":false,"error":"chat_plan_failed","inputOk":false,"sendOk":false,"methods":"chat_plan_pipe"}'
    parsed := Map()
    elementId := Integer(elementId)
    txt := Trim(String(text))
    plat := Trim(String(platform))
    methodsTag := "chat_plan_pipe"
    inputOk := false
    sendOk := false
    sentThread := false
    g_NiumaMobile_ChatPlanActive := true
    NiumaMobileBrowser_ApplyChatPlanPlatformFlags(plat)
    try {
        if (txt = "")
            throw Error("empty_text_plan")
        g_NiumaMobile_LastActInputText := txt
        if !NiumaMobileBrowser_EnsureLabelScripts()
            throw Error("doubao_scripts_missing")
        NiumaMobileBrowser_EnsureReactInputInjected()
        NiumaMobileBrowser_EnsureThreadCheckInjected()
        NiumaMobileBrowser_ClearVpThrottle()
        NiumaMobileBrowser_DismissOpenFileDialog()

        if NiumaMobileBrowser_IsChatSlatePage() && txt != "" {
            threadHit := NiumaMobileBrowser_IsMessageInThread(txt)
            if (threadHit is Map) && threadHit.Has("alreadySent") && threadHit["alreadySent"] {
                g_NiumaMobile_LastActInputText := ""
                result := '{"ok":true,"inputOk":true,"sendOk":true,"sentInThread":true,"idempotentSkip":true,"chatSubmit":true,"methods":"idempotent_thread","planPipe":true}'
                NiumaMobileBrowser_Log("PLAN_PIPE", rid, "idempotent_skip")
                g_NiumaMobile_ChatPlanActive := false
                NiumaMobileBrowser_ClearChatPlanPlatformFlags()
                NiumaMobileBrowser_OnChatPlanDone(elementId, result)
                return
            }
        }

        activateScript := NiumaMobileBrowser_BuildDoubaoActivateScript(elementId)
        if (activateScript != "") {
            try {
                rawAct := g_NiumaMobile_WV2.ExecuteScriptAsync(activateScript).await(8000)
                NiumaMobileBrowser_Log("PLAN_PIPE", rid, "activate " . SubStr(NiumaMobileBrowser_NormalizeScriptRaw(String(rawAct)), 1, 80))
            } catch {
            }
        }
        Sleep(200)

        NiumaMobileBrowser_BeginSendGate(rid)

        fillLabelScript := NiumaMobileBrowser_BuildDoubaoFillLabelScript(elementId, txt)
        if (fillLabelScript != "") {
            try {
                rawFill := g_NiumaMobile_WV2.ExecuteScriptAsync(fillLabelScript).await(12000)
                normFill := NiumaMobileBrowser_NormalizeScriptRaw(String(rawFill))
                if (normFill != "") {
                    NiumaMobileBrowser_Log("PLAN_PIPE", rid, "fill " . SubStr(normFill, 1, 100))
                    result := normFill
                }
            } catch {
            }
            NiumaMobileBrowser_DoubaoLoadParsed(result, &parsed, &methodsTag)
            inputOk := (parsed is Map) && parsed.Has("inputOk") && parsed["inputOk"]
            sendOk := (parsed is Map) && parsed.Has("sendOk") && parsed["sendOk"]
            sentThread := (parsed is Map) && parsed.Has("sentInThread") && parsed["sentInThread"]
        }

        if !sendOk && !sentThread && inputOk {
            chatScript := NiumaMobileBrowser_BuildDoubaoChatScript(elementId, txt, true)
            if (chatScript != "") {
                try {
                    rawSend := g_NiumaMobile_WV2.ExecuteScriptAsync(chatScript).await(14000)
                    normSend := NiumaMobileBrowser_NormalizeScriptRaw(String(rawSend))
                    if (normSend != "")
                        result := normSend
                } catch {
                }
                NiumaMobileBrowser_DoubaoLoadParsed(result, &parsed, &methodsTag)
                sendOk := (parsed is Map) && parsed.Has("sendOk") && parsed["sendOk"]
                sentThread := (parsed is Map) && parsed.Has("sentInThread") && parsed["sentInThread"]
                inputOk := (parsed is Map) && parsed.Has("inputOk") && parsed["inputOk"]
            }
        }

        if !sendOk && !sentThread && !inputOk {
            chatScript2 := NiumaMobileBrowser_BuildDoubaoChatScript(elementId, txt, false)
            if (chatScript2 != "") {
                try {
                    rawFull := g_NiumaMobile_WV2.ExecuteScriptAsync(chatScript2).await(14000)
                    normFull := NiumaMobileBrowser_NormalizeScriptRaw(String(rawFull))
                    if (normFull != "")
                        result := normFull
                } catch {
                }
                NiumaMobileBrowser_DoubaoLoadParsed(result, &parsed, &methodsTag)
                inputOk := (parsed is Map) && parsed.Has("inputOk") && parsed["inputOk"]
                sendOk := (parsed is Map) && parsed.Has("sendOk") && parsed["sendOk"]
                sentThread := (parsed is Map) && parsed.Has("sentInThread") && parsed["sentInThread"]
            }
        }

        gateMs := (plat = "deepseek" || plat = "gemini") ? 2200 : 2000
        gateInfo := NiumaMobileBrowser_WaitSendDomAssert(txt, elementId, gateMs)
        NiumaMobileBrowser_EndSendGate()
        NiumaMobileBrowser_MergeSendGateIntoParsed(&parsed, gateInfo)
        sendOk := (parsed is Map) && parsed.Has("sendOk") && parsed["sendOk"]
        sentThread := (parsed is Map) && parsed.Has("sentInThread") && parsed["sentInThread"]
        inputOk := (parsed is Map) && parsed.Has("inputOk") && parsed["inputOk"]

        if !sendOk && !sentThread {
            normVerify := NiumaMobileBrowser_RunDoubaoVerifySend(txt, methodsTag . ",plan_verify", elementId)
            if (normVerify != "") {
                result := normVerify
                NiumaMobileBrowser_DoubaoLoadParsed(result, &parsed, &methodsTag)
                sendOk := (parsed is Map) && parsed.Has("sendOk") && parsed["sendOk"]
                sentThread := (parsed is Map) && parsed.Has("sentInThread") && parsed["sentInThread"]
            }
        }

        if (parsed is Map) {
            parsed["planPipe"] := true
            if (sendOk || sentThread) {
                parsed["ok"] := true
                parsed["sendOk"] := true
                if !parsed.Has("inputOk")
                    parsed["inputOk"] := true
                g_NiumaMobile_LastActInputText := ""
            } else if inputOk {
                parsed["ok"] := false
                if !parsed.Has("error") || Trim(String(parsed["error"])) = ""
                    parsed["error"] := "input_only_not_sent"
            }
            result := NiumaMobileBrowser_DumpActParsed(parsed, result)
        }
        NiumaMobileBrowser_Log("PLAN_PIPE", rid, "done sendOk=" . (sendOk ? 1 : 0) . " sentThread=" . (sentThread ? 1 : 0))
    } catch as e {
        result := '{"ok":false,"error":"' . NiumaMobileBrowser_EscapeJsonStr(e.Message) . '","inputOk":false,"sendOk":false,"methods":"chat_plan_pipe","planPipe":true}'
        NiumaMobileBrowser_EndSendGate()
    }
    g_NiumaMobile_ChatPlanActive := false
    NiumaMobileBrowser_ClearChatPlanPlatformFlags()
    NiumaMobileBrowser_ClearVpThrottle()
    if (Trim(result) = "" && (parsed is Map))
        result := NiumaMobileBrowser_DumpActParsed(parsed, '{"ok":false,"error":"chat_plan_empty","inputOk":false,"sendOk":false,"planPipe":true}')
    NiumaMobileBrowser_OnChatPlanDone(elementId, result)
}

NiumaMobileBrowser_BeginSendGate(reqId := "") {
    global g_NiumaMobile_SendGateActive, g_NiumaMobile_SendGateReqId
    g_NiumaMobile_SendGateActive := true
    g_NiumaMobile_SendGateReqId := Trim(String(reqId))
    NiumaMobileBrowser_Log("GATE_FLOW", g_NiumaMobile_SendGateReqId, "SendGate 进入")
}

NiumaMobileBrowser_EndSendGate() {
    global g_NiumaMobile_SendGateActive, g_NiumaMobile_SendGateReqId, g_NiumaMobile_SendGatePendingObserveReqId
    rid := g_NiumaMobile_SendGateReqId
    g_NiumaMobile_SendGateActive := false
    g_NiumaMobile_SendGateReqId := ""
    NiumaMobileBrowser_Log("GATE_FLOW", rid, "SendGate 释放")
    pending := g_NiumaMobile_SendGatePendingObserveReqId
    g_NiumaMobile_SendGatePendingObserveReqId := ""
    if (pending != "")
        SetTimer(NiumaMobileBrowser_ObserveForChat.Bind(pending), -80)
}

NiumaMobileBrowser_BuildChatThreadCheckScript(text) {
    global JS_MOBILE_CHAT_THREAD_CHECK
    if (JS_MOBILE_CHAT_THREAD_CHECK = "" && !NiumaMobileBrowser_EnsureLabelScripts())
        return ""
    esc := NiumaMobileBrowser_EmbedJsTextLiteral(text)
    return StrReplace(JS_MOBILE_CHAT_THREAD_CHECK, "__NIUMA_TEXT__", esc)
}

NiumaMobileBrowser_EnsureThreadCheckInjected() {
    global g_NiumaMobile_WV2, g_NiumaMobile_ThreadCheckInjected, JS_MOBILE_CHAT_THREAD_CHECK
    if g_NiumaMobile_ThreadCheckInjected || !g_NiumaMobile_WV2
        return true
    if (JS_MOBILE_CHAT_THREAD_CHECK = "" && !NiumaMobileBrowser_EnsureLabelScripts())
        return false
    initScript := StrReplace(JS_MOBILE_CHAT_THREAD_CHECK, "__NIUMA_TEXT__", '""')
    try {
        g_NiumaMobile_WV2.ExecuteScriptAsync(initScript).await(5000)
        g_NiumaMobile_ThreadCheckInjected := true
        return true
    } catch {
        return false
    }
}

NiumaMobileBrowser_IsMessageInThread(text) {
    global g_NiumaMobile_WV2
    out := Map("alreadySent", false, "ok", false)
    txt := Trim(String(text))
    if (txt = "" || !g_NiumaMobile_WV2)
        return out
    if !NiumaMobileBrowser_EnsureThreadCheckInjected()
        return out
    script := NiumaMobileBrowser_BuildChatThreadCheckScript(txt)
    if (script = "")
        return out
    try {
        raw := g_NiumaMobile_WV2.ExecuteScriptAsync(script).await(6000)
        norm := NiumaMobileBrowser_NormalizeScriptRaw(String(raw))
        if (norm = "")
            return out
        parsed := NiumaMobileBrowser_ParseScriptJson(norm)
        if !(parsed is Map)
            return out
        out["ok"] := true
        if parsed.Has("alreadySent")
            out["alreadySent"] := !!parsed["alreadySent"]
        else if parsed.Has("sentInThread")
            out["alreadySent"] := !!parsed["sentInThread"]
        if parsed.Has("matchedBy")
            out["matchedBy"] := String(parsed["matchedBy"])
        return out
    } catch {
        return out
    }
}

NiumaMobileBrowser_WaitSendDomAssert(expectedText, elementId, maxMs := 2000) {
    global g_NiumaMobile_SendGateReqId
    txt := Trim(String(expectedText))
    rid := g_NiumaMobile_SendGateReqId
    t0 := A_TickCount
    domAssertOk := false
    sentThread := false
    sendOk := false
    loops := Max(1, Integer(maxMs / 200))
    loop loops {
        norm := NiumaMobileBrowser_RunDoubaoVerifySend(txt, "send_gate", elementId)
        if (norm != "") {
            parsed := NiumaMobileBrowser_ParseScriptJson(norm)
            if (parsed is Map) {
                sentThread := parsed.Has("sentInThread") && parsed["sentInThread"]
                sendOk := parsed.Has("sendOk") && parsed["sendOk"]
                editorTxt := parsed.Has("editorText") ? Trim(String(parsed["editorText"])) : ""
                editorEmpty := (editorTxt = "") || StrLen(editorTxt) < 2
                if (sentThread || sendOk) {
                    domAssertOk := true
                    break
                }
                if (editorEmpty && txt != "") {
                    domAssertOk := true
                    sendOk := true
                    break
                }
            }
        }
        if (A_TickCount - t0) >= maxMs
            break
        Sleep(200)
    }
    ms := A_TickCount - t0
    NiumaMobileBrowser_Log("GATE_FLOW", rid, "domAssert ok=" . (domAssertOk ? 1 : 0) . " sentThread=" . (sentThread ? 1 : 0) . " ms=" . ms)
    return Map(
        "domAssertOk", domAssertOk,
        "sentInThread", sentThread,
        "sendOk", sendOk,
        "sendGateMs", ms
    )
}

NiumaMobileBrowser_MergeSendGateIntoParsed(&parsed, gateInfo) {
    if !(parsed is Map) || !(gateInfo is Map)
        return
    parsed["sendGateMs"] := gateInfo.Has("sendGateMs") ? Integer(gateInfo["sendGateMs"]) : 0
    if gateInfo.Has("domAssertOk") && gateInfo["domAssertOk"] {
        parsed["domAssertOk"] := true
    } else {
        parsed["domAssertOk"] := false
    }
    if gateInfo.Has("sentInThread") && gateInfo["sentInThread"] {
        parsed["sentInThread"] := true
        parsed["ok"] := true
        parsed["sendOk"] := true
        parsed["chatSubmit"] := true
    }
    if gateInfo.Has("sendOk") && gateInfo["sendOk"] {
        parsed["sendOk"] := true
        parsed["ok"] := true
        parsed["chatSubmit"] := true
    }
}

NiumaMobileBrowser_PhysicalSendEnter() {
    global g_NiumaMobile_ParentHwnd, g_NiumaMobile_Ctrl
    if g_NiumaMobile_ParentHwnd {
        try DllCall("SetForegroundWindow", "Ptr", g_NiumaMobile_ParentHwnd)
        Sleep(80)
    }
    if g_NiumaMobile_Ctrl {
        try g_NiumaMobile_Ctrl.Focus()
        catch {
        }
        Sleep(60)
    }
    try SendInput("{Enter}")
    Sleep(120)
    try SendInput("^{Enter}")
    Sleep(120)
    return true
}

NiumaMobileBrowser_BuildDoubaoVerifySendScript(text, elementId := 0) {
    global JS_MOBILE_DOUBAO_VERIFY_SEND
    if (JS_MOBILE_DOUBAO_VERIFY_SEND = "" && !NiumaMobileBrowser_EnsureLabelScripts())
        return ""
    esc := NiumaMobileBrowser_EmbedJsTextLiteral(text)
    s := StrReplace(JS_MOBILE_DOUBAO_VERIFY_SEND, "__NIUMA_TEXT__", esc)
    return StrReplace(s, "__NIUMA_ID__", Integer(elementId))
}

NiumaMobileBrowser_BuildElementCenterScript(elementId) {
    global JS_MOBILE_ELEMENT_CENTER
    if (JS_MOBILE_ELEMENT_CENTER = "" && !NiumaMobileBrowser_EnsureLabelScripts())
        return ""
    id := Integer(elementId)
    if (id < 1)
        id := 0
    return StrReplace(JS_MOBILE_ELEMENT_CENTER, "__NIUMA_ID__", id)
}

NiumaMobileBrowser_ClientCoordsToScreen(cx, cy) {
    global g_NiumaMobile_ParentHwnd, g_NiumaMobile_Ctrl
    cx := Integer(cx)
    cy := Integer(cy)
    ctrlHwnd := 0
    if IsObject(g_NiumaMobile_Ctrl) {
        try ctrlHwnd := g_NiumaMobile_Ctrl.Hwnd
        catch {
        }
    }
    if (ctrlHwnd) {
        pt := Buffer(8, 0)
        NumPut("Int", cx, pt, 0)
        NumPut("Int", cy, pt, 4)
        if !DllCall("ClientToScreen", "Ptr", ctrlHwnd, "Ptr", pt)
            return Map("ok", false, "error", "ctrl_client_to_screen_failed")
        return Map("ok", true, "x", NumGet(pt, 0, "Int"), "y", NumGet(pt, 4, "Int"), "cx", cx, "cy", cy, "source", "webview_ctrl")
    }
    hwnd := g_NiumaMobile_ParentHwnd
    if !hwnd
        return Map("ok", false, "error", "browser_not_ready")
    try NiumaMobileBrowser_ApplyBounds(hwnd)
    catch {
    }
    try WinGetClientPos(, , &cw, &ch, hwnd)
    catch {
        return Map("ok", false, "error", "client_pos_failed")
    }
    mobileW := NiumaMobileBrowser_WidthPx()
    if (mobileW > cw)
        mobileW := cw
    offLeft := Max(0, cw - mobileW)
    pt := Buffer(8, 0)
    NumPut("Int", offLeft + cx, pt, 0)
    NumPut("Int", cy, pt, 4)
    if !DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", pt)
        return Map("ok", false, "error", "client_to_screen_failed")
    return Map("ok", true, "x", NumGet(pt, 0, "Int"), "y", NumGet(pt, 4, "Int"), "cx", cx, "cy", cy, "source", "parent_client")
}

NiumaMobileBrowser_GetElementScreenPoint(elementId) {
    global g_NiumaMobile_WV2, g_NiumaMobile_Ctrl, g_NiumaMobile_ParentHwnd
    if !g_NiumaMobile_WV2 || !g_NiumaMobile_Ctrl || !g_NiumaMobile_ParentHwnd
        return Map("ok", false, "error", "browser_not_ready")
    script := NiumaMobileBrowser_BuildElementCenterScript(elementId)
    if (script = "")
        return Map("ok", false, "error", "center_script_missing")
    try {
        raw := g_NiumaMobile_WV2.ExecuteScriptAsync(script).await(5000)
        norm := NiumaMobileBrowser_NormalizeScriptRaw(String(raw))
        parsed := NiumaMobileBrowser_ParseScriptJson(norm)
        if !(parsed is Map) || !parsed.Has("ok") || !parsed["ok"]
            return Map("ok", false, "error", parsed.Has("error") ? String(parsed["error"]) : "center_failed")
        return NiumaMobileBrowser_ClientCoordsToScreen(
            Integer(parsed.Has("cx") ? parsed["cx"] : 0),
            Integer(parsed.Has("cy") ? parsed["cy"] : 0)
        )
    } catch as e {
        return Map("ok", false, "error", e.Message)
    }
}

NiumaMobileBrowser_IsValidPasteClientPoint(cx, cy) {
    return Integer(cy) >= 40 && Integer(cx) >= 0
}

NiumaMobileBrowser_IsValidPasteScreenPoint(pt) {
    if !(pt is Map) || !pt.Has("ok") || !pt["ok"]
        return false
    if pt.Has("cy") && NiumaMobileBrowser_IsValidPasteClientPoint(pt["cx"], pt["cy"])
        return true
    y := Integer(pt.Has("y") ? pt["y"] : 0)
    x := Integer(pt.Has("x") ? pt["x"] : 0)
    return (y >= 60 && x >= 40)
}

NiumaMobileBrowser_PointFromActivateJson(activateJson) {
    if (activateJson = "")
        return Map("ok", false, "error", "no_activate_json")
    parsed := NiumaMobileBrowser_ParseScriptJson(activateJson)
    if !(parsed is Map) || !parsed.Has("ok") || !parsed["ok"]
        return Map("ok", false, "error", "activate_not_ok")
    if !parsed.Has("cx") || !parsed.Has("cy")
        return Map("ok", false, "error", "activate_no_coords")
    cy := Integer(parsed["cy"])
    cx := Integer(parsed["cx"])
    if !NiumaMobileBrowser_IsValidPasteClientPoint(cx, cy)
        return Map("ok", false, "error", "activate_bad_client_xy")
    pt := NiumaMobileBrowser_ClientCoordsToScreen(cx, cy)
    if (pt is Map) && pt.Has("ok") && pt["ok"]
        pt["source"] := "doubao_activate"
    return pt
}

NiumaMobileBrowser_GetDoubaoEditorScreenPoint(elementId, activateJson := "") {
    global g_NiumaMobile_WV2
    if (activateJson != "") {
        ptAct := NiumaMobileBrowser_PointFromActivateJson(activateJson)
        if NiumaMobileBrowser_IsValidPasteScreenPoint(ptAct)
            return ptAct
    }
    if !g_NiumaMobile_WV2
        return Map("ok", false, "error", "browser_not_ready")
    script := NiumaMobileBrowser_BuildDoubaoActivateScript(elementId)
    if (script != "") {
        try {
            raw := g_NiumaMobile_WV2.ExecuteScriptAsync(script).await(8000)
            norm := NiumaMobileBrowser_NormalizeScriptRaw(String(raw))
            ptAct2 := NiumaMobileBrowser_PointFromActivateJson(norm)
            if NiumaMobileBrowser_IsValidPasteScreenPoint(ptAct2)
                return ptAct2
        } catch {
        }
    }
    ptEl := NiumaMobileBrowser_GetElementScreenPoint(elementId)
    if NiumaMobileBrowser_IsValidPasteScreenPoint(ptEl) {
        ptEl["source"] := "element_center"
        return ptEl
    }
    return Map("ok", false, "error", "invalid_paste_point")
}

NiumaMobileBrowser_FocusBrowserForPhysical() {
    global g_NiumaMobile_ParentHwnd, g_NiumaMobile_Ctrl
    if g_NiumaMobile_ParentHwnd {
        try DllCall("SetForegroundWindow", "Ptr", g_NiumaMobile_ParentHwnd)
        Sleep(150)
    }
    if g_NiumaMobile_Ctrl {
        try g_NiumaMobile_Ctrl.Focus()
        catch {
        }
        Sleep(100)
    }
}

NiumaMobileBrowser_PhysicalClickScreenPoint(x, y) {
    CoordMode("Mouse", "Screen")
    try {
        Click(Integer(x), Integer(y), 1)
        Sleep(100)
        Click(Integer(x), Integer(y), 1)
        Sleep(120)
        return true
    } catch {
        return false
    }
}

; Slate：剪贴板 + ^v（OS 级输入，不依赖 DOM value）
NiumaMobileBrowser_PhysicalPasteAtScreenPoint(x, y, text) {
    txt := String(text)
    if (txt = "")
        return false
    NiumaMobileBrowser_FocusBrowserForPhysical()
    if !NiumaMobileBrowser_PhysicalClickScreenPoint(x, y)
        return false
    Sleep(220)
    clipSaved := ClipboardAll()
    pasted := false
    try {
        A_Clipboard := ""
        A_Clipboard := txt
        if ClipWait(2) {
            SendInput("^v")
            Sleep(450)
            pasted := true
        }
    } catch {
    }
    try A_Clipboard := clipSaved
    catch {
        A_Clipboard := ""
    }
    return pasted
}

; Slate 兜底：SendText 模拟真实键盘逐字输入
NiumaMobileBrowser_PhysicalTypeInput(elementId, text, activateJson := "") {
    txt := String(text)
    if (txt = "")
        return false
    pt := NiumaMobileBrowser_GetDoubaoEditorScreenPoint(elementId, activateJson)
    if !(pt is Map) || !pt.Has("ok") || !pt["ok"]
        return false
    NiumaMobileBrowser_FocusBrowserForPhysical()
    if !NiumaMobileBrowser_PhysicalClickScreenPoint(pt["x"], pt["y"])
        return false
    Sleep(280)
    try {
        SendText(txt)
        Sleep(500)
        return true
    } catch {
        return false
    }
}

NiumaMobileBrowser_PhysicalPasteInput(elementId, text, activateJson := "") {
    global g_NiumaMobile_ActReqId, g_NiumaMobile_ObserveReqId
    ridPt := g_NiumaMobile_ActReqId != "" ? g_NiumaMobile_ActReqId : g_NiumaMobile_ObserveReqId
    pt := NiumaMobileBrowser_GetDoubaoEditorScreenPoint(elementId, activateJson)
    if !(pt is Map) || !pt.Has("ok") || !pt["ok"] {
        errPt := (pt is Map) && pt.Has("error") ? String(pt["error"]) : "center_failed"
        NiumaMobileBrowser_Log("JOB_STEP", ridPt, "physical_paste_skip " . errPt . " id=" . elementId)
        return false
    }
    src := pt.Has("source") ? String(pt["source"]) : "element_center"
    ok := NiumaMobileBrowser_PhysicalPasteAtScreenPoint(pt["x"], pt["y"], text)
    NiumaMobileBrowser_Log("JOB_STEP", ridPt, "physical_paste " . (ok ? "ok" : "fail") . " src=" . src . " x=" . pt["x"] . " y=" . pt["y"])
    return ok
}

NiumaMobileBrowser_RunDoubaoVerifySend(text, methodsPrefix := "", elementId := 0) {
    global g_NiumaMobile_WV2
    if !g_NiumaMobile_WV2
        return ""
    verifyScript := NiumaMobileBrowser_BuildDoubaoVerifySendScript(text, elementId)
    if (verifyScript = "")
        return ""
    best := ""
    loop 4 {
        try {
            raw := g_NiumaMobile_WV2.ExecuteScriptAsync(verifyScript).await(6000)
            norm := NiumaMobileBrowser_NormalizeScriptRaw(String(raw))
            if (norm = "")
                continue
            parsed := Map()
            try {
                loaded := NiumaMobileBrowser_CallFunc("Jxon_Load", norm)
                if (loaded is Map)
                    parsed := loaded
            } catch {
            }
            if (parsed is Map) && parsed.Has("inputOk") && parsed["inputOk"] {
                if (methodsPrefix != "") {
                    m0 := parsed.Has("methods") ? String(parsed["methods"]) : ""
                    parsed["methods"] := methodsPrefix . (m0 != "" ? "," . m0 : "")
                }
                return NiumaMobileBrowser_CallFunc("Jxon_Dump", parsed)
            }
            best := norm
        } catch {
        }
        Sleep(280)
    }
    if (best != "" && methodsPrefix != "") {
        try {
            parsed := NiumaMobileBrowser_CallFunc("Jxon_Load", best)
            if (parsed is Map) {
                m1 := parsed.Has("methods") ? String(parsed["methods"]) : ""
                parsed["methods"] := methodsPrefix . (m1 != "" ? "," . m1 : "")
                return NiumaMobileBrowser_CallFunc("Jxon_Dump", parsed)
            }
        } catch {
        }
    }
    return best
}

NiumaMobileBrowser_GetPageUrl() {
    global g_NiumaMobile_WV2, g_NiumaMobile_LastKnownUrl
    url := ""
    if IsObject(g_NiumaMobile_WV2) {
        try {
            url := g_NiumaMobile_WV2.SourceUri
            if (url = "")
                url := g_NiumaMobile_WV2.Source
        } catch {
        }
    }
    if (url = "" && g_NiumaMobile_LastKnownUrl != "")
        url := String(g_NiumaMobile_LastKnownUrl)
    if (url != "")
        global g_NiumaMobile_LastKnownUrl := String(url)
    return String(url)
}

NiumaMobileBrowser_IsDoubaoPage(url := "") {
    u := url != "" ? String(url) : NiumaMobileBrowser_GetPageUrl()
    return InStr(u, "doubao.com") > 0
}

NiumaMobileBrowser_IsChatSlatePage(url := "") {
    u := url != "" ? String(url) : NiumaMobileBrowser_GetPageUrl()
    return InStr(u, "doubao.com") > 0 || InStr(u, "deepseek.com") > 0 || InStr(u, "gemini.google") > 0
}

NiumaMobileBrowser_ClearVpThrottle(*) {
    global g_NiumaMobile_WV2
    if !g_NiumaMobile_WV2
        return
    try g_NiumaMobile_WV2.ExecuteScriptAsync("try{window.__NIUMA_VP_THROTTLE__=false;}catch(e){}").await(1500)
    catch {
    }
}

NiumaMobileBrowser_DoubaoLoadParsed(result, &parsed, &methodsTag) {
    try {
        loaded := NiumaMobileBrowser_CallFunc("Jxon_Load", result)
        if (loaded is Map)
            parsed := loaded
    } catch {
    }
    if (parsed is Map) && parsed.Has("methods")
        methodsTag := String(parsed["methods"])
}

NiumaMobileBrowser_InputDoubaoHybrid(elementId, text, callback := 0) {
    global g_NiumaMobile_WV2, g_NiumaMobile_PendingActCb, g_NiumaMobile_AiPaused, g_NiumaMobile_ObserveReqId, g_NiumaMobile_ActReqId
        , g_NiumaMobile_ChatPlanActive
    rid := g_NiumaMobile_ActReqId != "" ? g_NiumaMobile_ActReqId : g_NiumaMobile_ObserveReqId
    if g_NiumaMobile_ChatPlanActive {
        NiumaMobileBrowser_DeliverErrorToChat("plan_pipe_busy", rid, "action_input")
        if IsObject(callback)
            try callback.Call(Map("ok", false, "error", "plan_pipe_busy"))
            catch {
            }
        return false
    }
    if g_NiumaMobile_AiPaused {
        if IsObject(callback)
            try callback.Call(Map("ok", false, "error", "ai_paused"))
        catch {
        }
        return false
    }
    if !g_NiumaMobile_WV2
        return false
    if !NiumaMobileBrowser_EnsureLabelScripts() {
        NiumaMobileBrowser_DeliverErrorToChat("doubao_scripts_missing", rid, "action_input")
        return false
    }
    g_NiumaMobile_PendingActCb := callback
    NiumaMobileBrowser_SetAiBusy(true, false)
    NiumaMobileBrowser_SetInputBlocked(false, true)
    NiumaMobileBrowser_Log("JOB_LAUNCH", rid, "action_input doubao_clipboard id=" . elementId . " textLen=" . StrLen(Trim(String(text))))
    SetTimer(NiumaMobileBrowser_InputDoubaoWorker.Bind(Integer(elementId), String(text), rid), -1)
    return true
}

NiumaMobileBrowser_InputDoubaoWorker(elementId, text, rid, *) {
    global g_NiumaMobile_WV2, g_NiumaMobile_ParentHwnd, g_NiumaMobile_Ctrl, g_NiumaMobile_ChatSendOnly, g_NiumaMobile_DeepseekJsFillOnly, g_NiumaMobile_GeminiJsFillOnly
    result := '{"ok":false,"error":"doubao_worker_failed","inputOk":false,"sendOk":false,"methods":"slate_physical"}'
    parsed := Map()
    elementId := Integer(elementId)
    txt := Trim(String(text))
    global g_NiumaMobile_LastActInputText
    if (txt = "" && g_NiumaMobile_LastActInputText != "")
        txt := Trim(String(g_NiumaMobile_LastActInputText))
    methodsTag := "slate_physical"
    normAct := ""
    try {
        if (txt = "")
            throw Error("empty_text_host")
        if !NiumaMobileBrowser_EnsureLabelScripts()
            throw Error("doubao_scripts_missing")
        NiumaMobileBrowser_EnsureReactInputInjected()
        NiumaMobileBrowser_EnsureThreadCheckInjected()
        NiumaMobileBrowser_ClearVpThrottle()
        NiumaMobileBrowser_SetInputBlocked(false, true)

        NiumaMobileBrowser_DismissOpenFileDialog()

        if NiumaMobileBrowser_IsChatSlatePage() && txt != "" {
            threadHit := NiumaMobileBrowser_IsMessageInThread(txt)
            if (threadHit is Map) && threadHit.Has("alreadySent") && threadHit["alreadySent"] {
                g_NiumaMobile_LastActInputText := ""
                result := '{"ok":true,"inputOk":true,"sendOk":true,"sentInThread":true,"idempotentSkip":true,"chatSubmit":true,"methods":"idempotent_thread"}'
                NiumaMobileBrowser_Log("JOB_STEP", rid, "idempotent_skip thread already has message")
                NiumaMobileBrowser_OnInputDone(elementId, result)
                return
            }
        }

        if g_NiumaMobile_ChatSendOnly {
            g_NiumaMobile_ChatSendOnly := false
            g_NiumaMobile_DeepseekJsFillOnly := false
            g_NiumaMobile_GeminiJsFillOnly := false
            methodsTag := "js_send_only"
            parsed := Map()
            NiumaMobileBrowser_BeginSendGate(rid)
            chatScript := NiumaMobileBrowser_BuildDoubaoChatScript(elementId, txt, true)
            if (chatScript != "") {
                try {
                    rawJs := g_NiumaMobile_WV2.ExecuteScriptAsync(chatScript).await(14000)
                    normJs := NiumaMobileBrowser_NormalizeScriptRaw(String(rawJs))
                    if (normJs != "")
                        result := normJs
                } catch {
                }
                NiumaMobileBrowser_DoubaoLoadParsed(result, &parsed, &methodsTag)
            }
            gateMsJs := (NiumaMobileBrowser_IsDeepSeekPage() || NiumaMobileBrowser_IsGeminiPage()) ? 2200 : 2000
            gateInfo := NiumaMobileBrowser_WaitSendDomAssert(txt, elementId, gateMsJs)
            NiumaMobileBrowser_EndSendGate()
            NiumaMobileBrowser_MergeSendGateIntoParsed(&parsed, gateInfo)
            if (parsed.Has("sendOk") && parsed["sendOk"]) || (parsed.Has("sentInThread") && parsed["sentInThread"]) {
                g_NiumaMobile_LastActInputText := ""
                parsed["ok"] := true
                parsed["idempotentSkip"] := false
                result := NiumaMobileBrowser_DumpActParsed(parsed, result)
            }
            NiumaMobileBrowser_Log("JOB_CALLBACK", rid, "action_input js_send_only id=" . elementId)
            NiumaMobileBrowser_OnInputDone(elementId, result)
            return
        }

        activateScript := NiumaMobileBrowser_BuildDoubaoActivateScript(elementId)
        if (activateScript != "") {
            try {
                rawAct := g_NiumaMobile_WV2.ExecuteScriptAsync(activateScript).await(8000)
                normAct := NiumaMobileBrowser_NormalizeScriptRaw(String(rawAct))
                NiumaMobileBrowser_Log("JOB_STEP", rid, "doubao_activate " . SubStr(normAct, 1, 120))
            } catch {
            }
        }
        Sleep(200)
        parsed := Map()
        inputOk := false
        sendOk := false
        sentThread := false
        didPhysical := false

        NiumaMobileBrowser_DoubaoLoadParsed(result, &parsed, &methodsTag)

        ; 1) 物理：剪贴板 + ^v（DeepSeek 跳过，避免误触附件/文件对话框）
        if !NiumaMobileBrowser_ShouldSkipPhysicalPaste() && NiumaMobileBrowser_PhysicalPasteInput(elementId, txt, normAct) {
            didPhysical := true
            methodsTag := "slate_clipboard_paste"
            Sleep(450)
            normPhys0 := NiumaMobileBrowser_RunDoubaoVerifySend(txt, methodsTag, elementId)
            if (normPhys0 != "")
                result := normPhys0
            NiumaMobileBrowser_DoubaoLoadParsed(result, &parsed, &methodsTag)
            inputOk := (parsed is Map) && parsed.Has("inputOk") && parsed["inputOk"]
            sendOk := (parsed is Map) && parsed.Has("sendOk") && parsed["sendOk"]
            sentThread := (parsed is Map) && parsed.Has("sentInThread") && parsed["sentInThread"]
        }

        ; 2) JS 填词（不重复物理粘贴）
        if !sendOk && !sentThread && !inputOk {
            fillLabelScript := NiumaMobileBrowser_BuildDoubaoFillLabelScript(elementId, txt)
            if (fillLabelScript != "") {
                try {
                    rawFill := g_NiumaMobile_WV2.ExecuteScriptAsync(fillLabelScript).await(12000)
                    normFill := NiumaMobileBrowser_NormalizeScriptRaw(String(rawFill))
                    if (normFill != "") {
                        NiumaMobileBrowser_Log("JOB_STEP", rid, "doubao_fill_label " . SubStr(normFill, 1, 120))
                        result := normFill
                    }
                } catch {
                }
                NiumaMobileBrowser_DoubaoLoadParsed(result, &parsed, &methodsTag)
                inputOk := (parsed is Map) && parsed.Has("inputOk") && parsed["inputOk"]
                sendOk := (parsed is Map) && parsed.Has("sendOk") && parsed["sendOk"]
                sentThread := (parsed is Map) && parsed.Has("sentInThread") && parsed["sentInThread"]
            }
        }

        ; 3) 已填词未发送：DeepSeek 用 JS 点发送（勿 Enter，易误触附件）；其它站可 Enter
        if !sendOk && !sentThread && inputOk {
            if didPhysical && !NiumaMobileBrowser_ShouldSkipPhysicalPaste() {
                NiumaMobileBrowser_PhysicalSendEnter()
            } else {
                NiumaMobileBrowser_BeginSendGate(rid)
                ; 已填词：仅 JS 点发送，避免 chat 脚本再次填词叠字
                chatScript := NiumaMobileBrowser_BuildDoubaoChatScript(elementId, txt, true)
                if (chatScript != "") {
                    try {
                        raw0 := g_NiumaMobile_WV2.ExecuteScriptAsync(chatScript).await(14000)
                        norm0 := NiumaMobileBrowser_NormalizeScriptRaw(String(raw0))
                        if (norm0 != "")
                            result := norm0
                    } catch {
                    }
                    NiumaMobileBrowser_DoubaoLoadParsed(result, &parsed, &methodsTag)
                    sendOk := (parsed is Map) && parsed.Has("sendOk") && parsed["sendOk"]
                    sentThread := (parsed is Map) && parsed.Has("sentInThread") && parsed["sentInThread"]
                }
                gateMs := (NiumaMobileBrowser_IsDeepSeekPage() || NiumaMobileBrowser_IsGeminiPage()) ? 2200 : 2000
                gateInfo := NiumaMobileBrowser_WaitSendDomAssert(txt, elementId, gateMs)
                NiumaMobileBrowser_EndSendGate()
                NiumaMobileBrowser_MergeSendGateIntoParsed(&parsed, gateInfo)
                sendOk := (parsed is Map) && parsed.Has("sendOk") && parsed["sendOk"]
                sentThread := (parsed is Map) && parsed.Has("sentInThread") && parsed["sentInThread"]
            }
            if !sendOk && !sentThread && didPhysical && !NiumaMobileBrowser_ShouldSkipPhysicalPaste() {
                Sleep(500)
                normSend := NiumaMobileBrowser_RunDoubaoVerifySend(txt, methodsTag . ",enter_send", elementId)
                if (normSend != "")
                    result := normSend
                NiumaMobileBrowser_DoubaoLoadParsed(result, &parsed, &methodsTag)
                sendOk := (parsed is Map) && parsed.Has("sendOk") && parsed["sendOk"]
                sentThread := (parsed is Map) && parsed.Has("sentInThread") && parsed["sentInThread"]
            } else if !sendOk && !sentThread {
                Sleep(500)
                normSend := NiumaMobileBrowser_RunDoubaoVerifySend(txt, methodsTag . ",js_send", elementId)
                if (normSend != "")
                    result := normSend
                NiumaMobileBrowser_DoubaoLoadParsed(result, &parsed, &methodsTag)
                sendOk := (parsed is Map) && parsed.Has("sendOk") && parsed["sendOk"]
                sentThread := (parsed is Map) && parsed.Has("sentInThread") && parsed["sentInThread"]
            }
        }

        if !sendOk && !sentThread && !inputOk && !didPhysical {
            NiumaMobileBrowser_BeginSendGate(rid)
            chatScript2 := NiumaMobileBrowser_BuildDoubaoChatScript(elementId, txt)
            if (chatScript2 != "") {
                try {
                    raw1 := g_NiumaMobile_WV2.ExecuteScriptAsync(chatScript2).await(14000)
                    norm1 := NiumaMobileBrowser_NormalizeScriptRaw(String(raw1))
                    if (norm1 != "")
                        result := norm1
                } catch {
                }
                NiumaMobileBrowser_DoubaoLoadParsed(result, &parsed, &methodsTag)
                inputOk := (parsed is Map) && parsed.Has("inputOk") && parsed["inputOk"]
                sendOk := (parsed is Map) && parsed.Has("sendOk") && parsed["sendOk"]
                sentThread := (parsed is Map) && parsed.Has("sentInThread") && parsed["sentInThread"]
            }
            gateMs2 := (NiumaMobileBrowser_IsDeepSeekPage() || NiumaMobileBrowser_IsGeminiPage()) ? 2200 : 2000
            gateInfo2 := NiumaMobileBrowser_WaitSendDomAssert(txt, elementId, gateMs2)
            NiumaMobileBrowser_EndSendGate()
            NiumaMobileBrowser_MergeSendGateIntoParsed(&parsed, gateInfo2)
            sendOk := (parsed is Map) && parsed.Has("sendOk") && parsed["sendOk"]
            sentThread := (parsed is Map) && parsed.Has("sentInThread") && parsed["sentInThread"]
            inputOk := (parsed is Map) && parsed.Has("inputOk") && parsed["inputOk"]
        }

        if (parsed is Map) && (sendOk || sentThread) {
            parsed["ok"] := true
            parsed["sendOk"] := true
            if !parsed.Has("inputOk")
                parsed["inputOk"] := true
            g_NiumaMobile_LastActInputText := ""
            result := NiumaMobileBrowser_DumpActParsed(parsed, result)
        } else if (parsed is Map) && inputOk && !sendOk && !sentThread {
            parsed["ok"] := false
            if !parsed.Has("error") || Trim(String(parsed["error"])) = ""
                parsed["error"] := "input_only_not_sent"
            result := NiumaMobileBrowser_DumpActParsed(parsed, result)
        }
    } catch as e {
        result := '{"ok":false,"error":"' . NiumaMobileBrowser_EscapeJsonStr(e.Message) . '","inputOk":false,"sendOk":false,"methods":"' . NiumaMobileBrowser_EscapeJsonStr(methodsTag) . '"}'
    }
    g_NiumaMobile_ChatSendOnly := false
    g_NiumaMobile_DeepseekJsFillOnly := false
    g_NiumaMobile_GeminiJsFillOnly := false
    NiumaMobileBrowser_ClearVpThrottle()
    if (Trim(result) = "" && (parsed is Map))
        result := NiumaMobileBrowser_DumpActParsed(parsed, '{"ok":false,"error":"doubao_worker_empty","inputOk":false,"sendOk":false}')
    NiumaMobileBrowser_Log("JOB_CALLBACK", rid, "action_input doubao_clipboard id=" . elementId . " raw=" . SubStr(result, 1, 160))
    NiumaMobileBrowser_OnInputDone(elementId, result)
}

NiumaMobileBrowser_BuildScrollScript(elementId, direction) {
    global JS_MOBILE_SCROLL
    if (JS_MOBILE_SCROLL = "" && !NiumaMobileBrowser_EnsureLabelScripts())
        return ""
    id := Integer(elementId)
    if (id < 1)
        id := 0
    dir := Trim(String(direction))
    if (dir = "")
        dir := "down"
    s := StrReplace(JS_MOBILE_SCROLL, "__NIUMA_ID__", id)
    escDir := NiumaMobileBrowser_CallFunc("Jxon_Dump", dir)
    if (escDir = "")
        escDir := '"down"'
    return StrReplace(s, "__NIUMA_DIRECTION__", escDir)
}

NiumaMobileBrowser_BuildResolveScript(selector, roleHint := "") {
    global JS_MOBILE_RESOLVE
    if (JS_MOBILE_RESOLVE = "" && !NiumaMobileBrowser_EnsureLabelScripts())
        return ""
    sel := String(selector)
    escSel := NiumaMobileBrowser_CallFunc("Jxon_Dump", sel)
    if (escSel = "")
        escSel := '""'
    rh := String(roleHint)
    escRole := NiumaMobileBrowser_CallFunc("Jxon_Dump", rh)
    if (escRole = "")
        escRole := '""'
    s := StrReplace(JS_MOBILE_RESOLVE, "__NIUMA_SELECTOR__", escSel)
    return StrReplace(s, "__NIUMA_ROLEHINT__", escRole)
}

NiumaMobileBrowser_ResolveElement(reqId, selector, roleHint := "") {
    global g_NiumaMobile_WV2
    rid := String(reqId)
    if !g_NiumaMobile_WV2 {
        wv2x := NiumaMobileBrowser_ChatWv2()
        if wv2x
            NiumaMobileBrowser_TryCallFunc("WebView_QueuePayload", wv2x, Map("type", "host_browser_resolve_result", "reqId", rid, "ok", false, "error", "browser_not_open"))
        return false
    }
    script := NiumaMobileBrowser_BuildResolveScript(selector, roleHint)
    if (script = "") {
        wv2x := NiumaMobileBrowser_ChatWv2()
        if wv2x
            NiumaMobileBrowser_TryCallFunc("WebView_QueuePayload", wv2x, Map("type", "host_browser_resolve_result", "reqId", rid, "ok", false, "error", "resolve_script_missing"))
        return false
    }
    try {
        raw := g_NiumaMobile_WV2.ExecuteScriptAsync(script).await(12000)
        parsed := NiumaMobileBrowser_ParseScriptJson(raw)
        okR := (parsed is Map) && parsed.Has("ok") && !!parsed["ok"]
        eid := (parsed is Map && parsed.Has("id")) ? Integer(parsed["id"]) : 0
        selUsed := (parsed is Map && parsed.Has("selectorUsed")) ? String(parsed["selectorUsed"]) : ""
        repaired := (parsed is Map && parsed.Has("repaired")) ? !!parsed["repaired"] : false
        rhOut := (parsed is Map && parsed.Has("roleHint")) ? String(parsed["roleHint"]) : String(roleHint)
        errR := (parsed is Map && parsed.Has("error")) ? String(parsed["error"]) : ""
        wv2 := NiumaMobileBrowser_ChatWv2()
        if wv2 {
            NiumaMobileBrowser_TryCallFunc("WebView_QueuePayload", wv2, Map(
                "type", "host_browser_resolve_result",
                "reqId", rid,
                "ok", !!okR,
                "elementId", eid,
                "selectorUsed", selUsed,
                "roleHint", rhOut,
                "repaired", repaired,
                "error", errR
            ))
        }
        return okR
    } catch as e {
        wv2 := NiumaMobileBrowser_ChatWv2()
        if wv2
            NiumaMobileBrowser_TryCallFunc("WebView_QueuePayload", wv2, Map("type", "host_browser_resolve_result", "reqId", rid, "ok", false, "error", String(e.Message)))
        return false
    }
}

NiumaMobileBrowser_CancelSettleWatchdog() {
    global g_NiumaMobile_SettleWatchdog
    try {
        if g_NiumaMobile_SettleWatchdog
            SetTimer(g_NiumaMobile_SettleWatchdog, 0)
    } catch {
    }
    g_NiumaMobile_SettleWatchdog := 0
}

NiumaMobileBrowser_OnSettleWatchdog(*) {
    global g_NiumaMobile_SettlePending, g_NiumaMobile_SettleNavPending, g_NiumaMobile_SettleReqId, g_NiumaMobile_ObserveReqId
    g_NiumaMobile_SettleWatchdog := 0
    if g_NiumaMobile_SettleNavPending
        return
    if !g_NiumaMobile_SettlePending
        return
    rid := g_NiumaMobile_SettleReqId
    NiumaMobileBrowser_Log("GATE_FLOW", rid, "watchdog timeout 强制开闸")
    NiumaMobileBrowser_CentralSettleGate(rid, "watchdog")
}

NiumaMobileBrowser_BeginPostActSettle() {
    global g_NiumaMobile_WV2, g_NiumaMobile_SettlePending, g_NiumaMobile_SettleNavPending, g_NiumaMobile_SettleReqId
        , g_NiumaMobile_ObserveReqId
    if !g_NiumaMobile_WV2
        return false
    if !NiumaMobileBrowser_EnsureLabelScripts() {
        NiumaMobileBrowser_DeliverErrorToChat("settle_script_missing", g_NiumaMobile_ObserveReqId, "settle")
        return false
    }
    g_NiumaMobile_SettleNavPending := false
    g_NiumaMobile_SettlePending := true
    if (g_NiumaMobile_SettleReqId = "")
        g_NiumaMobile_SettleReqId := g_NiumaMobile_ObserveReqId
    NiumaMobileBrowser_CancelSettleWatchdog()
    g_NiumaMobile_SettleWatchdog := NiumaMobileBrowser_OnSettleWatchdog
    SetTimer(g_NiumaMobile_SettleWatchdog, -12000)
    rid := g_NiumaMobile_SettleReqId
    escRid := NiumaMobileBrowser_CallFunc("Jxon_Dump", rid)
    if (escRid = "")
        escRid := '""'
    NiumaMobileBrowser_Log("GATE_FLOW", rid, "启动 settle 传感器 __NIUMA_START_SETTLE_FLOW__")
    try {
        g_NiumaMobile_WV2.ExecuteScriptAsync("window.__NIUMA_START_SETTLE_FLOW__(" . escRid . ");")
        return true
    } catch as e {
        g_NiumaMobile_SettlePending := false
        NiumaMobileBrowser_CancelSettleWatchdog()
        g_NiumaMobile_SettleReqId := ""
        NiumaMobileBrowser_DeliverErrorToChat("script_exec_failed: " . e.Message, rid, "settle")
        if (rid != "")
            SetTimer(NiumaMobileBrowser_ObserveForChat.Bind(rid), -200)
        else
            SetTimer(NiumaMobileBrowser_ObserveForChat, -200)
        return false
    }
}

NiumaMobileBrowser_CentralSettleGate(reqId, source := "") {
    global g_NiumaMobile_SettlePending, g_NiumaMobile_SettleReqId, g_NiumaMobile_SendGateActive, g_NiumaMobile_SendGatePendingObserveReqId
    rid := String(reqId)
    if !g_NiumaMobile_SettlePending {
        NiumaMobileBrowser_Log("GATE_FLOW", rid, "skip:not_pending source=" . source)
        return
    }
    if (rid = "")
        rid := String(g_NiumaMobile_SettleReqId)
    if (String(g_NiumaMobile_SettleReqId) != "" && rid != String(g_NiumaMobile_SettleReqId)) {
        NiumaMobileBrowser_Log("GATE_FLOW", rid, "skip:reqId_mismatch expected=" . g_NiumaMobile_SettleReqId . " source=" . source)
        return
    }
    g_NiumaMobile_SettlePending := false
    g_NiumaMobile_SettleReqId := ""
    NiumaMobileBrowser_CancelSettleWatchdog()
    if g_NiumaMobile_SendGateActive {
        g_NiumaMobile_SendGatePendingObserveReqId := rid
        NiumaMobileBrowser_Log("GATE_FLOW", rid, "SendGate 活跃，延后 Observe source=" . source)
        return
    }
    NiumaMobileBrowser_Log("GATE_FLOW", rid, "开闸 source=" . source . " → ObserveForChat")
    if (rid != "")
        SetTimer(NiumaMobileBrowser_ObserveForChat.Bind(rid), -120)
    else
        SetTimer(NiumaMobileBrowser_ObserveForChat, -120)
}

NiumaMobileBrowser_ClickLabeledElement(elementId, callback := 0) {
    global g_NiumaMobile_WV2, g_NiumaMobile_PendingActCb, g_NiumaMobile_AiPaused, g_NiumaMobile_ObserveReqId, g_NiumaMobile_ActReqId
    rid := g_NiumaMobile_ActReqId != "" ? g_NiumaMobile_ActReqId : g_NiumaMobile_ObserveReqId
    if g_NiumaMobile_AiPaused {
        if IsObject(callback)
            try callback.Call(Map("ok", false, "error", "ai_paused"))
        catch {
        }
        return false
    }
    if !g_NiumaMobile_WV2
        return false
    NiumaMobileBrowser_DismissOpenFileDialog()
    script := NiumaMobileBrowser_BuildClickScript(elementId)
    if (script = "") {
        NiumaMobileBrowser_DeliverErrorToChat("click_script_missing", rid, "action_click")
        return false
    }
    g_NiumaMobile_PendingActCb := callback
    NiumaMobileBrowser_SetAiBusy(true)
    NiumaMobileBrowser_Log("JOB_LAUNCH", rid, "action_click id=" . elementId)
    if NiumaMobileBrowser_ExecScript("click", script, rid, Map("elementId", Integer(elementId)))
        return true
    NiumaMobileBrowser_DeliverErrorToChat("script_exec_failed", rid, "action_click")
    NiumaMobileBrowser_SetAiBusy(false)
    g_NiumaMobile_PendingActCb := 0
    return false
}

NiumaMobileBrowser_ScrollLabeledElement(elementId, direction, callback := 0) {
    global g_NiumaMobile_WV2, g_NiumaMobile_PendingActCb, g_NiumaMobile_AiPaused, g_NiumaMobile_ObserveReqId, g_NiumaMobile_ActReqId
    rid := g_NiumaMobile_ActReqId != "" ? g_NiumaMobile_ActReqId : g_NiumaMobile_ObserveReqId
    if g_NiumaMobile_AiPaused {
        if IsObject(callback)
            try callback.Call(Map("ok", false, "error", "ai_paused"))
        catch {
        }
        return false
    }
    if !g_NiumaMobile_WV2
        return false
    script := NiumaMobileBrowser_BuildScrollScript(elementId, direction)
    if (script = "") {
        NiumaMobileBrowser_DeliverErrorToChat("scroll_script_missing", rid, "action_scroll")
        return false
    }
    g_NiumaMobile_PendingActCb := callback
    NiumaMobileBrowser_SetAiBusy(true)
    NiumaMobileBrowser_Log("JOB_LAUNCH", rid, "action_scroll id=" . elementId . " dir=" . direction)
    if NiumaMobileBrowser_ExecScript("scroll", script, rid, Map("elementId", Integer(elementId)))
        return true
    NiumaMobileBrowser_DeliverErrorToChat("script_exec_failed", rid, "action_scroll")
    NiumaMobileBrowser_SetAiBusy(false)
    g_NiumaMobile_PendingActCb := 0
    return false
}

NiumaMobileBrowser_OnScrollDone(elementId, result) {
    global g_NiumaMobile_PendingActCb, g_NiumaMobile_ObserveReqId
    cb := g_NiumaMobile_PendingActCb
    g_NiumaMobile_PendingActCb := 0
    parsed := NiumaMobileBrowser_ParseScriptJson(result)
    okAct := (parsed is Map) && parsed.Has("ok") && !!parsed["ok"]
    NiumaMobileBrowser_Log("JOB_CALLBACK", g_NiumaMobile_ObserveReqId, "action_scroll id=" . elementId . " ok=" . (okAct ? 1 : 0))
    NiumaMobileBrowser_SetAiBusy(false)
    NiumaMobileBrowser_NotifyActResult(parsed, "scroll", elementId)
    if IsObject(cb) {
        try cb.Call(parsed)
        catch {
        }
    }
    if !(parsed is Map) || !parsed.Has("ok") || !parsed["ok"]
        return
    SetTimer(NiumaMobileBrowser_BeginPostActSettle.Bind(), -200)
}

NiumaMobileBrowser_OnClickDone(elementId, result) {
    global g_NiumaMobile_PendingActCb, g_NiumaMobile_ObserveReqId
    cb := g_NiumaMobile_PendingActCb
    g_NiumaMobile_PendingActCb := 0
    parsed := NiumaMobileBrowser_ParseScriptJson(result)
    okAct := (parsed is Map) && parsed.Has("ok") && !!parsed["ok"]
    NiumaMobileBrowser_Log("JOB_CALLBACK", g_NiumaMobile_ObserveReqId, "action_click id=" . elementId . " ok=" . (okAct ? 1 : 0))
    NiumaMobileBrowser_SetAiBusy(false)
    NiumaMobileBrowser_NotifyActResult(parsed, "click", elementId)
    if IsObject(cb) {
        try cb.Call(parsed)
        catch {
        }
    }
    if !(parsed is Map) || !parsed.Has("ok") || !parsed["ok"]
        return
    SetTimer(NiumaMobileBrowser_BeginPostActSettle.Bind(), -120)
}

NiumaMobileBrowser_UriEncodeComponent(s) {
    s := Trim(String(s))
    if (s = "")
        return ""
    static hex := "0123456789ABCDEF"
    out := ""
    Loop Parse s {
        c := Ord(A_LoopField)
        if (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || InStr("-_.!~*'()", A_LoopField)
            out .= A_LoopField
        else if (c <= 127)
            out .= "%" . SubStr(hex, (c >> 4) + 1, 1) . SubStr(hex, Mod(c, 16) + 1, 1)
        else {
            utf8 := Buffer(4, 0)
            len := StrPut(A_LoopField, utf8, "UTF-8") - 1
            Loop len
                out .= "%" . Format("{:02X}", NumGet(utf8, A_Index - 1, "UChar"))
        }
    }
    return out
}

NiumaMobileBrowser_ScheduleSearchNavigateFallback(*) {
    global g_NiumaMobile_WV2, g_NiumaMobile_LastActInputText
    q := Trim(g_NiumaMobile_LastActInputText)
    if (q = "" || !g_NiumaMobile_WV2)
        return
    try u := g_NiumaMobile_WV2.SourceUri
    catch
        return
    if RegExMatch(u, "i)/search(\?|$|/)")
        return
    enc := NiumaMobileBrowser_UriEncodeComponent(q)
    if (enc = "")
        return
    if RegExMatch(u, "i)^https?://([a-z0-9-]+\.)*google\.") {
        try g_NiumaMobile_WV2.Navigate("https://www.google.com/search?q=" . enc . "&oq=" . enc)
        catch {
        }
        return
    }
    if RegExMatch(u, "i)^https?://([a-z0-9-]+\.)*baidu\.") {
        try g_NiumaMobile_WV2.Navigate("https://www.baidu.com/s?wd=" . enc)
        catch {
        }
    }
}

NiumaMobileBrowser_InputLabeledElement(elementId, text, callback := 0) {
    global g_NiumaMobile_WV2, g_NiumaMobile_PendingActCb, g_NiumaMobile_AiPaused, g_NiumaMobile_ObserveReqId, g_NiumaMobile_ActReqId
        , g_NiumaMobile_LastActInputText, g_NiumaMobile_ForceDoubaoInput
    g_NiumaMobile_LastActInputText := String(text)
    rid := g_NiumaMobile_ActReqId != "" ? g_NiumaMobile_ActReqId : g_NiumaMobile_ObserveReqId
    if g_NiumaMobile_AiPaused {
        if IsObject(callback)
            try callback.Call(Map("ok", false, "error", "ai_paused"))
        catch {
        }
        return false
    }
    if !g_NiumaMobile_WV2
        return false
    if (g_NiumaMobile_ForceDoubaoInput || NiumaMobileBrowser_IsChatSlatePage())
        return NiumaMobileBrowser_InputDoubaoHybrid(elementId, text, callback)
    script := NiumaMobileBrowser_BuildInputScript(elementId, text)
    if (script = "") {
        NiumaMobileBrowser_DeliverErrorToChat("input_script_missing", rid, "action_input")
        return false
    }
    g_NiumaMobile_PendingActCb := callback
    NiumaMobileBrowser_SetAiBusy(true)
    NiumaMobileBrowser_Log("JOB_LAUNCH", rid, "action_input id=" . elementId . " textLen=" . StrLen(Trim(String(text))))
    if NiumaMobileBrowser_ExecScript("input", script, rid, Map("elementId", Integer(elementId)))
        return true
    NiumaMobileBrowser_DeliverErrorToChat("script_exec_failed", rid, "action_input")
    NiumaMobileBrowser_SetAiBusy(false)
    g_NiumaMobile_PendingActCb := 0
    return false
}

NiumaMobileBrowser_OnInputDone(elementId, result) {
    global g_NiumaMobile_PendingActCb, g_NiumaMobile_ObserveReqId, g_NiumaMobile_LastActInputText
    cb := g_NiumaMobile_PendingActCb
    g_NiumaMobile_PendingActCb := 0
    parsed := NiumaMobileBrowser_ParseScriptJson(result)
    okAct := (parsed is Map) && parsed.Has("ok") && !!parsed["ok"]
    inf := (parsed is Map) && parsed.Has("inferred") && parsed["inferred"] ? " inferred=1" : ""
    NiumaMobileBrowser_Log("JOB_CALLBACK", g_NiumaMobile_ObserveReqId, "action_input id=" . elementId . " ok=" . (okAct ? 1 : 0) . inf)
    NiumaMobileBrowser_SetAiBusy(false)
    SetTimer(NiumaMobileBrowser_ClearVpThrottle.Bind(), -200)
    NiumaMobileBrowser_NotifyActResult(parsed, "input", elementId)
    if IsObject(cb) {
        try cb.Call(parsed)
        catch {
        }
    }
    if !(parsed is Map) || !parsed.Has("ok") || !parsed["ok"]
        return
    settleMs := 120
    if (parsed.Has("deferred") && parsed["deferred"])
        settleMs := 700
    sentLike := (parsed.Has("sendOk") && parsed["sendOk"]) || (parsed.Has("sentInThread") && parsed["sentInThread"]) || (parsed.Has("chatSubmit") && parsed["chatSubmit"]) || (parsed.Has("idempotentSkip") && parsed["idempotentSkip"])
    if sentLike {
        settleMs := NiumaMobileBrowser_IsDeepSeekPage() ? 800 : 650
        if (parsed.Has("sendGateMs") && Integer(parsed["sendGateMs"]) > 0)
            settleMs := Max(settleMs, Integer(parsed["sendGateMs"]) + 350)
        NiumaMobileBrowser_ScheduleAutoHideLabelsAfterChat(g_NiumaMobile_LastActInputText)
    }
    SetTimer(NiumaMobileBrowser_BeginPostActSettle.Bind(), -settleMs)
    if (parsed.Has("submitted") && parsed["submitted"])
        SetTimer(NiumaMobileBrowser_ScheduleSearchNavigateFallback.Bind(), -450)
}

NiumaMobileBrowser_NotifyActResult(parsed, action, elementId) {
    global g_NiumaMobile_ObserveReqId, g_NiumaMobile_ActReqId
    reqId := g_NiumaMobile_ActReqId != "" ? g_NiumaMobile_ActReqId : g_NiumaMobile_ObserveReqId
    ok := false
    err := ""
    if (parsed is Map) {
        idemSkip := parsed.Has("idempotentSkip") && parsed["idempotentSkip"]
        sendOk := parsed.Has("sendOk") && parsed["sendOk"]
        sentThread := parsed.Has("sentInThread") && parsed["sentInThread"]
        domAssert := parsed.Has("domAssertOk") && parsed["domAssertOk"]
        inputOk := parsed.Has("inputOk") && parsed["inputOk"]
        chatSubmit := parsed.Has("chatSubmit") && parsed["chatSubmit"]
        ok := idemSkip || sendOk || sentThread || (domAssert && (sendOk || sentThread))
            || ((parsed.Has("ok") && parsed["ok"]) && inputOk && (sendOk || sentThread))
        if parsed.Has("inputOk") && !inputOk && !sendOk && !sentThread && !domAssert && !idemSkip
            ok := false
        if parsed.Has("error")
            err := String(parsed["error"])
        if (sendOk || sentThread)
            err := ""
    }
    NiumaMobileBrowser_QueueActToChat("host_browser_act_result", reqId, ok, err, String(action), Integer(elementId), false, "", parsed)
}

NiumaMobileBrowser_PauseAiControl() {
    global g_NiumaMobile_LabelRefreshTimer, g_NiumaMobile_AiPaused, g_NiumaMobile_PendingAnalyzeCb, g_NiumaMobile_PendingActCb
        , g_NiumaMobile_SettlePending, g_NiumaMobile_SettleNavPending, g_NiumaMobile_SettleReqId
    g_NiumaMobile_AiPaused := true
    g_NiumaMobile_SettlePending := false
    g_NiumaMobile_SettleNavPending := false
    g_NiumaMobile_SettleReqId := ""
    NiumaMobileBrowser_CancelSettleWatchdog()
    try {
        if g_NiumaMobile_LabelRefreshTimer
            SetTimer(g_NiumaMobile_LabelRefreshTimer, 0)
    } catch {
    }
    g_NiumaMobile_LabelRefreshTimer := 0
    g_NiumaMobile_PendingAnalyzeCb := 0
    g_NiumaMobile_PendingActCb := 0
    NiumaMobileBrowser_SetAiBusy(false)
    global g_NiumaMobile_ActReqId, g_NiumaMobile_ObserveReqId
    rid := g_NiumaMobile_ActReqId != "" ? g_NiumaMobile_ActReqId : g_NiumaMobile_ObserveReqId
    NiumaMobileBrowser_QueueActToChat("host_browser_act_result", rid, false, "user_paused", "", 0, true, "")
    NiumaMobileBrowser_NotifyState(NiumaMobileBrowser_IsOpen())
}

NiumaMobileBrowser_ResumeAiControl() {
    global g_NiumaMobile_AiPaused
    g_NiumaMobile_AiPaused := false
    NiumaMobileBrowser_NotifyState(NiumaMobileBrowser_IsOpen())
}

NiumaMobileBrowser_ShowLabels() {
    global g_NiumaMobile_LabelDebug
    NiumaMobileBrowser_CancelAutoHideLabelsTimer()
    if !NiumaMobileBrowser_IsOpen() {
        NiumaMobileBrowser_NotifyLabelError("browser_not_open")
        return false
    }
    if !NiumaMobileBrowser_EnsureLabelScripts() {
        NiumaMobileBrowser_NotifyLabelError("label_script_missing: " . NiumaMobileBrowser_ModuleDir())
        return false
    }
    g_NiumaMobile_LabelDebug := true
    NiumaMobileBrowser_EnsureLabelDebugOnPage(true)
    NiumaMobileBrowser_NotifyState(true)
    return NiumaMobileBrowser_ObserveForChat()
}

NiumaMobileBrowser_NotifyLabelError(msg) {
    NiumaMobileBrowser_QueueSnapshotToChat([], "", String(msg), false, 0, "")
}

NiumaMobileBrowser_CancelAutoHideLabelsTimer() {
    global g_NiumaMobile_LabelAutoHideTimer
    try {
        if g_NiumaMobile_LabelAutoHideTimer
            SetTimer(g_NiumaMobile_LabelAutoHideTimer, 0)
    } catch {
    }
    g_NiumaMobile_LabelAutoHideTimer := 0
}

NiumaMobileBrowser_BuildChatReplyProbeScript(expectedText := "") {
    esc := NiumaMobileBrowser_EscapeJsSingle(Trim(String(expectedText)))
    return "(function(){try{var q='" . esc . "';var needle=q.length>=8?q.slice(0,8):q.length>=6?q.slice(0,6):q.length>=4?q.slice(0,4):q;"
        . "var host=String((location&&location.hostname)||'').toLowerCase();var onGemini=host.indexOf('gemini.google')>=0;"
        . "var nodes=document.querySelectorAll('[class*=message],[role=article],p,div,span');"
        . "var i,b,longCount=0,longAssistant=0;"
        . "for(i=0;i<nodes.length;i++){b=String(nodes[i].innerText||nodes[i].textContent||'').trim();"
        . "if(b.length<60)continue;"
        . "if(/^发消息|想聊点什么|Ask\\s*Gemini|Enter\\s*a\\s*prompt|给\\s*DeepSeek|豆包\\s*新对话|使用快速模式|DeepThink|联网搜索/.test(b))continue;"
        . "if(/热键编写|编写方法|完整示例|AutoHotkey|by the way|Backspace|Numpad|LButton|UTF-8|快速上手/.test(b)&&b.length>80)return JSON.stringify({ok:true,hasReply:true});"
        . "if(q&&needle&&b.indexOf(needle)>=0&&b.length>q.length+48)return JSON.stringify({ok:true,hasReply:true});"
        . "if(b.length>120){longCount++;if(/assistant|ai-message|bot-message|model-response/i.test(String(nodes[i].className||'')))longAssistant++;}}"
        . "if(onGemini&&(longAssistant>=1||longCount>=1))return JSON.stringify({ok:true,hasReply:true});"
        . "return JSON.stringify({ok:true,hasReply:longCount>=2});}catch(e){return JSON.stringify({ok:false,hasReply:false});}})();"
}

NiumaMobileBrowser_PageHasChatReplyVisible(expectedText := "") {
    global g_NiumaMobile_WV2
    if !g_NiumaMobile_WV2
        return false
    script := NiumaMobileBrowser_BuildChatReplyProbeScript(expectedText)
    try {
        raw := g_NiumaMobile_WV2.ExecuteScriptAsync(script).await(5000)
        parsed := NiumaMobileBrowser_ParseScriptJson(String(raw))
        if (parsed is Map) && parsed.Has("hasReply") && parsed["hasReply"]
            return true
    } catch {
    }
    return false
}

NiumaMobileBrowser_ScheduleAutoHideLabelsAfterChat(expectedText := "") {
    global g_NiumaMobile_LabelAutoHidePass, g_NiumaMobile_LabelAutoHideChatText, g_NiumaMobile_LabelAutoHideTimer
    g_NiumaMobile_LabelAutoHideChatText := Trim(String(expectedText))
    g_NiumaMobile_LabelAutoHidePass := 0
    NiumaMobileBrowser_CancelAutoHideLabelsTimer()
    g_NiumaMobile_LabelAutoHideTimer := NiumaMobileBrowser_TickAutoHideLabelsAfterChat
    SetTimer(g_NiumaMobile_LabelAutoHideTimer, 2000)
}

NiumaMobileBrowser_TickAutoHideLabelsAfterChat(*) {
    global g_NiumaMobile_LabelAutoHidePass, g_NiumaMobile_LabelAutoHideTimer, g_NiumaMobile_LabelAutoHideChatText
    g_NiumaMobile_LabelAutoHidePass += 1
    if NiumaMobileBrowser_PageHasChatReplyVisible(g_NiumaMobile_LabelAutoHideChatText) {
        NiumaMobileBrowser_CancelAutoHideLabelsTimer()
        NiumaMobileBrowser_HideLabels()
        return
    }
    if (g_NiumaMobile_LabelAutoHidePass >= 45) {
        NiumaMobileBrowser_CancelAutoHideLabelsTimer()
        NiumaMobileBrowser_HideLabels()
    }
}

NiumaMobileBrowser_HideLabels() {
    global g_NiumaMobile_WV2, g_NiumaMobile_LabelDebug
    if !g_NiumaMobile_WV2
        return false
    NiumaMobileBrowser_CancelAutoHideLabelsTimer()
    g_NiumaMobile_LabelDebug := false
    try {
        g_NiumaMobile_WV2.ExecuteScriptAsync("(function(){try{window.__NIUMA_LABEL_DEBUG__=false;var r=document.getElementById('niuma-mobile-label-root');if(r)r.remove();var badges=document.querySelectorAll('.niuma-label-badge');for(var i=0;i<badges.length;i++)badges[i].remove();var els=document.querySelectorAll('[data-niuma-label-id]');for(var j=0;j<els.length;j++){els[j].removeAttribute('data-niuma-label-id');els[j].classList.remove('niuma-label-target');els[j].style.outline='';els[j].style.outlineOffset='';}return JSON.stringify({ok:true});}catch(e){return JSON.stringify({ok:false});}})();")
    } catch {
    }
    NiumaMobileBrowser_EnsureLabelDebugOnPage(false)
    NiumaMobileBrowser_NotifyState(NiumaMobileBrowser_IsOpen())
    return true
}

NiumaMobileBrowser_ToggleLabelDebug() {
    global g_NiumaMobile_LabelDebug
    if g_NiumaMobile_LabelDebug
        return NiumaMobileBrowser_HideLabels()
    return NiumaMobileBrowser_ShowLabels()
}

NiumaMobileBrowser_RunUserCommand(cmd) {
    global g_NiumaMobile_AiPaused
    if g_NiumaMobile_AiPaused
        return Map("ok", false, "error", "ai_paused")
    s := Trim(String(cmd))
    if (s = "")
        return Map("ok", false, "error", "empty_command")
    low := StrLower(s)
    if (low = "观察" || low = "observe" || low = "刷新标签" || low = "label" || low = "labels")
        return Map("ok", NiumaMobileBrowser_ShowLabels(), "action", "observe")
    if RegExMatch(s, "i)^(点击|click)\s*#?(\d+)\s*$", &m)
        return Map("ok", NiumaMobileBrowser_ClickLabeledElement(Integer(m[2])), "action", "click", "elementId", Integer(m[2]))
    if RegExMatch(s, "i)^(输入|input|fill)\s*#?(\d+)\s+(.+)$", &m2)
        return Map("ok", NiumaMobileBrowser_InputLabeledElement(Integer(m2[2]), m2[3]), "action", "input", "elementId", Integer(m2[2]))
    if RegExMatch(s, "i)^#?(\d+)\s*$", &m3) {
        id := Integer(m3[1])
        return Map("ok", NiumaMobileBrowser_ClickLabeledElement(id), "action", "click", "elementId", id)
    }
    return Map("ok", false, "error", "unknown_command")
}

NiumaMobileBrowser_ObserveForChatDeferred(reqId, *) {
    NiumaMobileBrowser_ObserveForChat(reqId)
}

NiumaMobileBrowser_ObserveForChat(reqId := "") {
    global g_NiumaMobile_AiPaused, g_NiumaMobile_ObserveReqId, g_NiumaMobile_LastSnapshot, g_NiumaMobile_WV2
        , g_NiumaMobile_OpenInProgress, g_NiumaMobile_PendingOpen, g_NiumaMobile_SendGateActive, g_NiumaMobile_LabelDebug
    if g_NiumaMobile_SendGateActive {
        NiumaMobileBrowser_Log("GUARD", reqId, "SendGate 活跃，Observe 延迟 200ms")
        SetTimer(NiumaMobileBrowser_ObserveForChatDeferred.Bind(reqId), -200)
        return true
    }
    ; Chat @网页 带 reqId 的 observe 应自动解除历史暂停，避免快照 err=ai_paused
    if (reqId != "") {
        g_NiumaMobile_AiPaused := false
        NiumaMobileBrowser_NotifyState(NiumaMobileBrowser_IsOpen())
    }
    if g_NiumaMobile_AiPaused {
        NiumaMobileBrowser_QueueSnapshotToChat([], "", "ai_paused", false, 0, reqId)
        return false
    }
    if !NiumaMobileBrowser_IsOpen() {
        if (g_NiumaMobile_OpenInProgress || g_NiumaMobile_PendingOpen) {
            g_NiumaMobile_ObserveOpenWaitPass += 1
            if (g_NiumaMobile_ObserveOpenWaitPass <= 32) {
                NiumaMobileBrowser_Log("GUARD", reqId, "observe 等待浏览器打开中 pass=" . g_NiumaMobile_ObserveOpenWaitPass)
                SetTimer(NiumaMobileBrowser_ObserveForChatDeferred.Bind(reqId), -750)
                return true
            }
            g_NiumaMobile_ObserveOpenWaitPass := 0
        }
        NiumaMobileBrowser_Log("GUARD", reqId, "observe abort: browser_not_open")
        NiumaMobileBrowser_QueueSnapshotToChat([], "", "browser_not_open", false, 0, reqId)
        return false
    }
    g_NiumaMobile_ObserveOpenWaitPass := 0
    g_NiumaMobile_ObserveReqId := String(reqId)
    NiumaMobileBrowser_Log("GUARD", reqId, "observe 开始 ObserveReqId 已锁定")
    url := ""
    try url := g_NiumaMobile_WV2.SourceUri
    catch {
    }
    global g_NiumaMobile_LastElementsCount
    cnt := g_NiumaMobile_LastElementsCount > 0 ? g_NiumaMobile_LastElementsCount
        : ((g_NiumaMobile_LastSnapshot is Array) ? g_NiumaMobile_LastSnapshot.Length : 0)
    ; @网页 智能操控带 reqId 时勿先推缓存快照，避免 Chat 吃到过期/无搜索框列表导致超时或误操作
    if (reqId = "" && cnt > 0)
        NiumaMobileBrowser_QueueSnapshotToChat(g_NiumaMobile_LastSnapshot, url, "", false, cnt, reqId)
    NiumaMobileBrowser_EnsureLabelDebugOnPage(!!g_NiumaMobile_LabelDebug)
    NiumaMobileBrowser_SetAiBusy(true)
    return NiumaMobileBrowser_AnalyzePage(NiumaMobileBrowser_OnObserveForChatDone.Bind(), false)
}

NiumaMobileBrowser_OnObserveForChatDone(items, rawJson, err) {
    global g_NiumaMobile_WV2, g_NiumaMobile_ObserveReqId, g_NiumaMobile_LastElementsCount
    reqId := g_NiumaMobile_ObserveReqId
    NiumaMobileBrowser_SetAiBusy(false)
    ; 勿过早清空 ObserveReqId，避免与 OnAnalyzeDone 竞态导致快照无 reqId
    url := ""
    try url := g_NiumaMobile_WV2.SourceUri
    catch {
    }
    truncated := false
    total := g_NiumaMobile_LastElementsCount > 0 ? g_NiumaMobile_LastElementsCount : items.Length
    if (err = "json_parse_failed" && g_NiumaMobile_LastElementsCount > 0)
        err := ""
    try {
        p := NiumaMobileBrowser_CallFunc("Jxon_Load", rawJson)
        if (p is Map) {
            truncated := p.Has("truncated") ? !!p["truncated"] : false
            if p.Has("totalCandidates")
                total := Integer(p["totalCandidates"])
        }
    } catch {
    }
    NiumaMobileBrowser_QueueSnapshotToChat(items, url, err, truncated, total, reqId)
    g_NiumaMobile_ObserveReqId := ""
}

NiumaMobileBrowser_ActFromChatDeferred(action, elementId, value, *) {
    NiumaMobileBrowser_ActFromChat(action, elementId, value)
}

NiumaMobileBrowser_ActFromChat(action, elementId := 0, value := "") {
    global g_NiumaMobile_AiPaused, g_NiumaMobile_ObserveReqId, g_NiumaMobile_ActReqId, g_NiumaMobile_ForceDoubaoInput, g_NiumaMobile_ChatSendOnly
    if g_NiumaMobile_AiPaused
        return false
    act := StrLower(Trim(String(action)))
    rid := g_NiumaMobile_ActReqId != "" ? g_NiumaMobile_ActReqId : g_NiumaMobile_ObserveReqId
    ; 刚性防御：elementId 非法时 0ms 回包，避免前端长等超时
    if ((act = "click" || act = "input" || act = "fill") && (Integer(elementId) <= 0)) {
        try NiumaMobileBrowser_DeliverErrorToChat("invalid_element_id", rid, "action_" . act)
        catch {
        }
        return false
    }
    if (act = "observe") {
        return NiumaMobileBrowser_ObserveForChat()
    }
    if (act = "refresh") {
        return NiumaMobileBrowser_StartNavigateAction("refresh", rid)
    }
    if (act = "back") {
        return NiumaMobileBrowser_StartNavigateAction("back", rid)
    }
    if (act = "click")
        return NiumaMobileBrowser_ClickLabeledElement(elementId)
    if (act = "input" || act = "fill") {
        ok := NiumaMobileBrowser_InputLabeledElement(elementId, value)
        g_NiumaMobile_ForceDoubaoInput := false
        g_NiumaMobile_ChatSendOnly := false
        g_NiumaMobile_DeepseekJsFillOnly := false
        g_NiumaMobile_GeminiJsFillOnly := false
        return ok
    }
    if (act = "scroll")
        return NiumaMobileBrowser_ScrollLabeledElement(elementId, value)
    g_NiumaMobile_ForceDoubaoInput := false
    g_NiumaMobile_ChatSendOnly := false
    g_NiumaMobile_DeepseekJsFillOnly := false
    g_NiumaMobile_GeminiJsFillOnly := false
    return false
}

NiumaMobileBrowser_PreCloseCleanup() {
    global g_NiumaMobile_WV2, g_NiumaMobile_Jobs, g_NiumaMobile_PendingAnalyzeCb, g_NiumaMobile_PendingActCb
        , g_NiumaMobile_AnalyzeWatchdog, g_NiumaMobile_LabelRefreshTimer, g_NiumaMobile_SendGateActive
        , g_NiumaMobile_SendGateReqId, g_NiumaMobile_SendGatePendingObserveReqId
    g_NiumaMobile_SendGateActive := false
    g_NiumaMobile_SendGateReqId := ""
    g_NiumaMobile_SendGatePendingObserveReqId := ""
    g_NiumaMobile_ChatPlanActive := false
    g_NiumaMobile_ChatPlanPlatform := ""
    NiumaMobileBrowser_ClearChatPlanPlatformFlags()
    g_NiumaMobile_PendingAnalyzeCb := 0
    g_NiumaMobile_PendingActCb := 0
    try {
        if g_NiumaMobile_AnalyzeWatchdog
            SetTimer(g_NiumaMobile_AnalyzeWatchdog, 0)
    } catch {
    }
    g_NiumaMobile_AnalyzeWatchdog := 0
    try {
        if g_NiumaMobile_LabelRefreshTimer
            SetTimer(g_NiumaMobile_LabelRefreshTimer, 0)
    } catch {
    }
    g_NiumaMobile_LabelRefreshTimer := 0
    NiumaMobileBrowser_CancelSettleWatchdog()
    for jobId, card in g_NiumaMobile_Jobs.Clone() {
        try NiumaMobileBrowser_OnScriptResult(jobId, "", false, "cancelled_close")
        catch {
        }
    }
    if g_NiumaMobile_WV2 {
        try {
            g_NiumaMobile_WV2.ExecuteScriptAsync(
                "try{var r=document.getElementById('niuma-mobile-label-root');if(r)r.remove();"
                . "var els=document.querySelectorAll('.niuma-label-badge');"
                . "for(var i=0;i<els.length;i++)els[i].remove();}catch(e){}"
            )
        } catch {
        }
    }
}

NiumaMobileBrowser_Close() {
    global g_NiumaMobile_Env, g_NiumaMobile_Ctrl, g_NiumaMobile_WV2, g_NiumaMobile_Open
    global g_NiumaMobile_TokenNav, g_NiumaMobile_TokenNavStart, g_NiumaMobile_TokenNewWin, g_NiumaMobile_TokenMsg, g_NiumaMobile_ParentHwnd
    global g_NiumaMobile_LabelRefreshTimer, g_NiumaMobile_AiBusy, g_NiumaMobile_AiPaused
    global g_NiumaMobile_SettlePending, g_NiumaMobile_SettleNavPending, g_NiumaMobile_SettleReqId
        , g_NiumaMobile_NavigateAckReqId, g_NiumaMobile_NavigateAckAction, g_NiumaMobile_NavigateWatchdogActive

    NiumaMobileBrowser_PreCloseCleanup()
    NiumaMobileBrowser_SetPendingOpen(false)
    g_NiumaMobile_OpenInProgress := false
    g_NiumaMobile_SettlePending := false
    g_NiumaMobile_SettleNavPending := false
    g_NiumaMobile_SettleReqId := ""
    g_NiumaMobile_NavigateAckReqId := ""
    g_NiumaMobile_NavigateAckAction := ""
    g_NiumaMobile_NavigateWatchdogActive := false
    SetTimer(NiumaMobileBrowser_NavigateWatchdogTimeout, 0)
    NiumaMobileBrowser_CancelSettleWatchdog()
    try {
        if g_NiumaMobile_LabelRefreshTimer
            SetTimer(g_NiumaMobile_LabelRefreshTimer, 0)
    } catch {
    }
    g_NiumaMobile_LabelRefreshTimer := 0
    g_NiumaMobile_AiBusy := false
    g_NiumaMobile_AiPaused := false
    NiumaMobileBrowser_SetInputBlocked(false)
    if g_NiumaMobile_WV2 {
        try {
            if g_NiumaMobile_TokenNav
                g_NiumaMobile_WV2.remove_NavigationCompleted(g_NiumaMobile_TokenNav)
        } catch {
        }
        try {
            if g_NiumaMobile_TokenNavStart
                g_NiumaMobile_WV2.remove_NavigationStarting(g_NiumaMobile_TokenNavStart)
        } catch {
        }
        try {
            if g_NiumaMobile_TokenNewWin
                g_NiumaMobile_WV2.remove_NewWindowRequested(g_NiumaMobile_TokenNewWin)
        } catch {
        }
        try {
            if g_NiumaMobile_TokenMsg
                g_NiumaMobile_WV2.remove_WebMessageReceived(g_NiumaMobile_TokenMsg)
        } catch {
        }
    }
    g_NiumaMobile_TokenNav := 0
    g_NiumaMobile_TokenNavStart := 0
    g_NiumaMobile_TokenNewWin := 0
    g_NiumaMobile_TokenMsg := 0

    if g_NiumaMobile_Ctrl {
        try g_NiumaMobile_Ctrl.IsVisible := false
        catch {
        }
        try g_NiumaMobile_Ctrl.Close()
        catch {
        }
    }

    g_NiumaMobile_Ctrl := 0
    g_NiumaMobile_WV2 := 0
    g_NiumaMobile_Env := 0
    g_NiumaMobile_Open := false
    g_NiumaMobile_ParentHwnd := 0

    NiumaMobileBrowser_NotifyState(false)
    NiumaMobileBrowser_TryCallFunc("FloatingToolbar_AfterMobileBrowserClose")
}

NiumaMobileBrowser_PrepareForScriptReload() {
    NiumaMobileBrowser_Close()
}
