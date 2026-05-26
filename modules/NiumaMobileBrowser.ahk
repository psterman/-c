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
global g_NiumaMobile_LastActInputText := ""
global g_NiumaMobile_LabelRefreshTimer := 0
global g_NiumaMobile_LastSnapshot := []
global g_NiumaMobile_LastElementsJson := "[]"
global g_NiumaMobile_LastElementsCount := 0
global g_NiumaMobile_AiBusy := false
global g_NiumaMobile_AiPaused := false
global g_NiumaMobile_LabelDebug := true
global g_NiumaMobile_PendingAnalyzeCb := 0
global g_NiumaMobile_PendingActCb := 0
global g_NiumaMobile_SilentRefresh := false
global g_NiumaMobile_ObserveReqId := ""
global g_NiumaMobile_ActReqId := ""
global g_NiumaMobile_AnalyzeWatchdog := 0
global g_NiumaMobile_SnapshotRetryReqId := ""
global g_NiumaMobile_SnapshotRetryCount := 0
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

JS_MOBILE_SET_INPUT_BLOCK := "(function(){try{document.documentElement.style.pointerEvents=__NIUMA_BLOCK__?'none':'';return JSON.stringify({ok:true});}catch(e){return JSON.stringify({ok:false});}})();"

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
    global JS_MOBILE_LABELING, JS_MOBILE_CLICK_BY_ID, JS_MOBILE_INPUT_BY_ID, JS_MOBILE_SETTLE
    ok := true
    NiumaMobileBrowser_Log("GUARD", "", "脚本自检开始 dir=" . NiumaMobileBrowser_ModuleDir())
    if (JS_MOBILE_LABELING = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_labeling.js", &JS_MOBILE_LABELING) && ok
    if (JS_MOBILE_CLICK_BY_ID = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_click.js", &JS_MOBILE_CLICK_BY_ID) && ok
    if (JS_MOBILE_INPUT_BY_ID = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_input.js", &JS_MOBILE_INPUT_BY_ID) && ok
    if (JS_MOBILE_SETTLE = "")
        ok := NiumaMobileBrowser_LoadScriptFile("niuma_mobile_settle.js", &JS_MOBILE_SETTLE) && ok
    lenLabel := StrLen(JS_MOBILE_LABELING)
    lenClick := StrLen(JS_MOBILE_CLICK_BY_ID)
    lenInput := StrLen(JS_MOBILE_INPUT_BY_ID)
    lenSettle := StrLen(JS_MOBILE_SETTLE)
    NiumaMobileBrowser_Log("GUARD", "", "LabelLen=" . lenLabel . " ClickLen=" . lenClick . " InputLen=" . lenInput . " SettleLen=" . lenSettle)
    if !ok {
        NiumaMobileBrowser_Log("GUARD", "", "脚本自检失败：文件缺失")
        return false
    }
    if (lenLabel < 500)
        NiumaMobileBrowser_Log("GUARD", "", "警告：labeling 脚本偏短 len=" . lenLabel)
    if (lenSettle < 200)
        NiumaMobileBrowser_Log("GUARD", "", "警告：settle 脚本偏短 len=" . lenSettle)
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

NiumaMobileBrowser_TryCallFunc(fnName, params*) {
    try {
        Func(fnName).Call(params*)
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
    try {
        env := wv2cls.CreateEnvironmentAsync(0, dataDir).await(20000)
        NiumaMobileBrowser_Log("GUARD", "", "OPEN worker Environment 就绪 dataDir=" . dataDir)
        NiumaMobileBrowser_OnEnvReady(hwndParent, env)
    } catch as e {
        NiumaMobileBrowser_Log("GUARD", "", "OPEN worker Environment 失败: " . e.Message)
        NiumaMobileBrowser_OpenFail("手机浏览器启动失败: " . e.Message)
        try OutputDebug("[NiumaMobile] CreateEnvironmentAsync failed: " . e.Message)
        catch {
        }
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
        ctrl := env.CreateCoreWebView2ControllerAsync(hwndParent).await(20000)
        NiumaMobileBrowser_Log("GUARD", "", "OPEN Controller 已创建")
        NiumaMobileBrowser_OnControllerReady(ctrl)
    } catch as e {
        NiumaMobileBrowser_Log("GUARD", "", "OPEN Controller 失败: " . e.Message)
        NiumaMobileBrowser_OpenFail("手机浏览器控制器启动失败: " . e.Message)
        try OutputDebug("[NiumaMobile] CreateCoreWebView2ControllerAsync failed: " . e.Message)
        catch {
        }
    }
}

NiumaMobileBrowser_InjectSettleOnDocumentCreated(*) {
    global g_NiumaMobile_WV2, JS_MOBILE_SETTLE
    if !IsObject(g_NiumaMobile_WV2) || JS_MOBILE_SETTLE = ""
        return
    try g_NiumaMobile_WV2.AddScriptToExecuteOnDocumentCreatedAsync(JS_MOBILE_SETTLE)
    catch as eAdd {
        NiumaMobileBrowser_Log("GUARD", "", "Settle 文档注入失败(非阻塞): " . eAdd.Message)
    }
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
    global g_NiumaMobile_WV2, NIUMA_MOBILE_INJECT_JS, JS_MOBILE_SETTLE, g_NiumaMobile_SettleNavPending, g_NiumaMobile_SettleReqId
        , g_NiumaMobile_AiPaused, g_NiumaMobile_PendingAnalyzeCb, g_NiumaMobile_AiBusy, g_NiumaMobile_ObserveReqId
    if !g_NiumaMobile_WV2
        return
    navOk := true
    try {
        if IsObject(args) && args.HasProp("IsSuccess") && !args.IsSuccess
            navOk := false
    } catch {
    }
    try g_NiumaMobile_WV2.ExecuteScriptAsync(NIUMA_MOBILE_INJECT_JS)
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
        NiumaMobileBrowser_EnsureLabelDebugOnPage(true)
        if !IsObject(g_NiumaMobile_PendingAnalyzeCb) && !g_NiumaMobile_AiBusy && (g_NiumaMobile_ObserveReqId = "")
            SetTimer(NiumaMobileBrowser_DeferredFirstLabel.Bind(), -650)
    }
}

NiumaMobileBrowser_DeferredFirstLabel(*) {
    global g_NiumaMobile_PendingAnalyzeCb, g_NiumaMobile_AiBusy, g_NiumaMobile_ObserveReqId
    if !NiumaMobileBrowser_IsOpen()
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
    return t
}

NiumaMobileBrowser_QueueActToChat(typ, reqId, ok := false, err := "", action := "", elementId := 0, cancelled := false, stage := "") {
    wv2 := NiumaMobileBrowser_ChatWv2()
    rid := String(reqId)
    st := NiumaMobileBrowser_NormalizeStage(stage)
    if (typ = "host_browser_act_error")
        NiumaMobileBrowser_Log("CHAT_OUT", rid, "host_browser_act_error stage=" . st . " error=" . String(err))
    else
        NiumaMobileBrowser_Log("CHAT_OUT", rid, "host_browser_act_result action=" . String(action) . " ok=" . (ok ? 1 : 0) . " err=" . String(err))
    if !wv2
        return false
    json := '{"type":"' . typ . '","reqId":"' . NiumaMobileBrowser_EscapeJsonStr(rid) . '"'
        . ',"ok":' . (ok ? "true" : "false")
        . ',"error":"' . NiumaMobileBrowser_EscapeJsonStr(String(err)) . '"'
        . ',"action":"' . NiumaMobileBrowser_EscapeJsonStr(String(action)) . '"'
        . ',"elementId":' . Integer(elementId)
        . ',"cancelled":' . (cancelled ? "true" : "false")
        . ',"stage":"' . NiumaMobileBrowser_EscapeJsonStr(st) . '"}'
    try {
        if NiumaMobileBrowser_TryCallFunc("WebView_QueueJson", wv2, json)
            return true
        wv2.PostWebMessageAsJson(json)
        return true
    } catch as e {
        NiumaMobileBrowser_Log("CHAT_OUT", rid, typ . " post_failed err=" . e.Message)
        return false
    }
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
    jobTimeout := (jobType = "click" || jobType = "input") ? 12000 : 22000
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
    }
}

NiumaMobileBrowser_HandleJobError(jobCard, errorMsg) {
    global g_NiumaMobile_PendingActCb
    reqId := jobCard.Has("reqId") ? String(jobCard["reqId"]) : ""
    jt := jobCard.Has("jobType") ? String(jobCard["jobType"]) : ""
    stage := jt = "click" ? "action_click" : (jt = "input" ? "action_input" : (jt = "analyze" ? "label" : jt))
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

NiumaMobileBrowser_NotifyState(open, url := "") {
    global g_NiumaMobile_LabelDebug, g_NiumaMobile_AiPaused
    wv2 := NiumaMobileBrowser_ChatWv2()
    if !wv2
        return
    NiumaMobileBrowser_TryCallFunc("WebView_QueuePayload", wv2, Map(
        "type", "host_mobile_browser_state",
        "open", !!open,
        "url", String(url),
        "widthPx", NiumaMobileBrowser_WidthPx(),
        "labelDebugVisible", !!g_NiumaMobile_LabelDebug,
        "aiPaused", !!g_NiumaMobile_AiPaused
    ))
}

NiumaMobileBrowser_SetAiBusy(busy) {
    global g_NiumaMobile_AiBusy
    g_NiumaMobile_AiBusy := !!busy
    wv2 := NiumaMobileBrowser_ChatWv2()
    if wv2
        NiumaMobileBrowser_TryCallFunc("WebView_QueuePayload", wv2, Map("type", "host_browser_ai_busy", "busy", !!busy))
    NiumaMobileBrowser_SetInputBlocked(!!busy)
}

NiumaMobileBrowser_SetInputBlocked(block) {
    global g_NiumaMobile_WV2, JS_MOBILE_SET_INPUT_BLOCK
    if !g_NiumaMobile_WV2
        return
    script := StrReplace(JS_MOBILE_SET_INPUT_BLOCK, "__NIUMA_BLOCK__", block ? "true" : "false")
    try g_NiumaMobile_WV2.ExecuteScriptAsync(script)
    catch {
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

NiumaMobileBrowser_QueueSnapshotToChat(items, url := "", err := "", truncated := false, total := 0, reqId := "") {
    wv2 := NiumaMobileBrowser_ChatWv2()
    if !wv2 {
        try OutputDebug("[NiumaMobile] QueueSnapshot: Chat WebView2 未就绪")
        catch {
        }
        NiumaMobileBrowser_Log("CHAT_OUT", reqId, "host_browser_snapshot wv2_not_ready")
        NiumaMobileBrowser_ScheduleSnapshotRetry(reqId)
        return false
    }
    global g_NiumaMobile_LastElementsJson, g_NiumaMobile_LastElementsCount
    rid := String(reqId)
    arrLen := g_NiumaMobile_LastElementsCount > 0 ? g_NiumaMobile_LastElementsCount
        : ((items is Array) ? items.Length : 0)
    tot := total ? Integer(total) : arrLen
    rawElementsJson := "[]"
    if (g_NiumaMobile_LastElementsJson != "[]" && g_NiumaMobile_LastElementsCount > 0)
        rawElementsJson := g_NiumaMobile_LastElementsJson
    else if (items is Array) && items.Length
        rawElementsJson := NiumaMobileBrowser_BuildCompactElementsJson(items)
    if (SubStr(Trim(rawElementsJson), 1, 1) != "[") {
        NiumaMobileBrowser_Log("CHAT_OUT", rid, "host_browser_snapshot snapshot 非数组，回退 []")
        rawElementsJson := "[]"
    }
    finalSafePayload := '{"type":"host_browser_snapshot","data":{"reqId":"' . NiumaMobileBrowser_EscapeJsonStr(rid) . '"'
        . ',"count":' . arrLen . ',"arrLen":' . arrLen
        . ',"url":"' . NiumaMobileBrowser_EscapeJsonStr(String(url)) . '"'
        . ',"error":"' . NiumaMobileBrowser_EscapeJsonStr(String(err)) . '"'
        . ',"truncated":' . (truncated ? "true" : "false")
        . ',"totalCandidates":' . tot
        . ',"snapshot":' . rawElementsJson . '}}'
    if (finalSafePayload = "" || StrLen(finalSafePayload) < 40) {
        NiumaMobileBrowser_Log("CHAT_OUT", rid, "host_browser_snapshot 直通车 JSON 过短")
        return false
    }
    try {
        if NiumaMobileBrowser_TryCallFunc("WebView_QueueJson", wv2, finalSafePayload) {
            NiumaMobileBrowser_Log("CHAT_OUT", rid, "快照直通车离港 arrLen=" . arrLen . " jsonLen=" . StrLen(finalSafePayload) . " err=" . String(err))
            return true
        }
        wv2.PostWebMessageAsJson(finalSafePayload)
        NiumaMobileBrowser_Log("CHAT_OUT", rid, "快照直通车离港(直投) arrLen=" . arrLen . " jsonLen=" . StrLen(finalSafePayload) . " err=" . String(err))
        return true
    } catch as e1 {
        try OutputDebug("[NiumaMobile] PostWebMessageAsJson failed: " . e1.Message . " | json_len=" . StrLen(finalSafePayload))
        catch {
        }
        NiumaMobileBrowser_Log("CHAT_OUT", rid, "host_browser_snapshot post_failed err=" . e1.Message)
        NiumaMobileBrowser_ScheduleSnapshotRetry(reqId)
        return false
    }
}

NiumaMobileBrowser_ParseItemsArrayJson(itemsJson) {
    items := []
    j := Trim(String(itemsJson))
    if (j = "" || j = "[]")
        return items
    try {
        arr := NiumaMobileBrowser_CallFunc("Jxon_Load", j)
        if !(arr is Array)
            return items
        for , el in arr {
            if (el is Map)
                items.Push(el)
        }
    } catch {
    }
    return items
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
    return esc
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
        parts.Push('{"id":' . id . ',"tag":"' . tag . '","type":"' . typ . '","text":"' . txt . '","hint":"' . hint . '","role":"' . role . '"}')
    }
    return "[" . (parts.Length ? parts.Join(",") : "") . "]"
}

NiumaMobileBrowser_PushCachedSnapshot(reqId := "") {
    global g_NiumaMobile_LastSnapshot, g_NiumaMobile_WV2, g_NiumaMobile_LastElementsCount
    cnt := g_NiumaMobile_LastElementsCount > 0 ? g_NiumaMobile_LastElementsCount
        : ((g_NiumaMobile_LastSnapshot is Array) ? g_NiumaMobile_LastSnapshot.Length : 0)
    if cnt < 1
        return false
    url := ""
    if g_NiumaMobile_WV2 {
        try url := g_NiumaMobile_WV2.SourceUri
        catch {
        }
    }
    return NiumaMobileBrowser_QueueSnapshotToChat(g_NiumaMobile_LastSnapshot, url, "", false, cnt, reqId)
}

NiumaMobileBrowser_ParseScriptJson(raw) {
    s := Trim(String(raw))
    if (s = "")
        return Map("ok", false, "error", "empty_result")
    if (SubStr(s, 1, 1) = '"') {
        s := NiumaMobileBrowser_UnquoteScriptResult(s)
    }
    ; 有时 WebView2 会返回形如 {\"ok\":true,...} 的“被转义过的 JSON 文本”，需要先反转义
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
    try {
        obj := NiumaMobileBrowser_CallFunc("Jxon_Load", s)
        if (obj is Map)
            return obj
        if (obj is Array)
            return Map("ok", true, "items", obj)
    } catch {
    }
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
        NiumaMobileBrowser_OnAnalyzeDone(raw)
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

    parsed := NiumaMobileBrowser_ParseScriptJson(result)
    items := []
    err := ""
    if (parsed is Map) {
        if parsed.Has("ok") && !parsed["ok"]
            err := parsed.Has("error") ? String(parsed["error"]) : "analyze_failed"
        else if parsed.Has("error") && (!parsed.Has("items") || !(parsed["items"] is Array))
            err := String(parsed["error"])
        if parsed.Has("items") {
            it := parsed["items"]
            if (it is Array)
                items := it
            else if (it is Map)
                items := NiumaMobileBrowser_MapValuesToArray(it)
        }
    }
    if (err = "" && items.Length = 0 && (parsed is Map) && parsed.Has("skipped") && parsed["skipped"])
        err := "viewport_throttle"
    if (items.Length = 0 && g_NiumaMobile_LastElementsCount > 0 && g_NiumaMobile_LastElementsJson != "[]") {
        items := NiumaMobileBrowser_ParseItemsArrayJson(g_NiumaMobile_LastElementsJson)
        if (items.Length > 0 && (err = "json_parse_failed" || err = "label_parse_empty"))
            err := ""
    }
    global g_NiumaMobile_ObserveReqId
    obsReqId := g_NiumaMobile_ObserveReqId
    if (err = "" && items.Length = 0)
        err := "label_parse_empty"
    g_NiumaMobile_LastSnapshot := items
    rawHead := SubStr(String(result), 1, 220)
    NiumaMobileBrowser_Log("JOB_CALLBACK", obsReqId, "analyze items=" . items.Length . " err=" . err . " silent=" . (silent ? 1 : 0)
        . " extracted_cnt=" . g_NiumaMobile_LastElementsCount . " raw_head=" . rawHead)

    rawJson := ""
    try rawJson := NiumaMobileBrowser_CallFunc("Jxon_Dump", parsed)
    catch {
        rawJson := String(result)
    }

    if (obsReqId != "" && !silent) {
        urlObs := ""
        try urlObs := g_NiumaMobile_WV2.SourceUri
        catch {
        }
        totObs := g_NiumaMobile_LastElementsCount > 0 ? g_NiumaMobile_LastElementsCount
            : (items.Length > 0 ? items.Length : 0)
        if (err = "json_parse_failed" && totObs > 0)
            err := ""
        NiumaMobileBrowser_QueueSnapshotToChat(items, urlObs, err,
            parsed.Has("truncated") ? !!parsed["truncated"] : false,
            parsed.Has("totalCandidates") ? Integer(parsed["totalCandidates"]) : totObs, obsReqId)
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
        NiumaMobileBrowser_QueueSnapshotToChat(items, url, err, parsed.Has("truncated") ? !!parsed["truncated"] : false,
            parsed.Has("totalCandidates") ? Integer(parsed["totalCandidates"]) : items.Length, obsReqId)
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
    global g_NiumaMobile_SettlePending, g_NiumaMobile_SettleReqId
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
        , g_NiumaMobile_LastActInputText
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
    script := NiumaMobileBrowser_BuildInputScript(elementId, text)
    if (script = "") {
        NiumaMobileBrowser_DeliverErrorToChat("input_script_missing", rid, "action_input")
        return false
    }
    g_NiumaMobile_PendingActCb := callback
    NiumaMobileBrowser_SetAiBusy(true)
    NiumaMobileBrowser_Log("JOB_LAUNCH", rid, "action_input id=" . elementId)
    if NiumaMobileBrowser_ExecScript("input", script, rid, Map("elementId", Integer(elementId)))
        return true
    NiumaMobileBrowser_DeliverErrorToChat("script_exec_failed", rid, "action_input")
    NiumaMobileBrowser_SetAiBusy(false)
    g_NiumaMobile_PendingActCb := 0
    return false
}

NiumaMobileBrowser_OnInputDone(elementId, result) {
    global g_NiumaMobile_PendingActCb, g_NiumaMobile_ObserveReqId
    cb := g_NiumaMobile_PendingActCb
    g_NiumaMobile_PendingActCb := 0
    parsed := NiumaMobileBrowser_ParseScriptJson(result)
    okAct := (parsed is Map) && parsed.Has("ok") && !!parsed["ok"]
    NiumaMobileBrowser_Log("JOB_CALLBACK", g_NiumaMobile_ObserveReqId, "action_input id=" . elementId . " ok=" . (okAct ? 1 : 0))
    NiumaMobileBrowser_SetAiBusy(false)
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
        ok := parsed.Has("ok") && !!parsed["ok"]
        if parsed.Has("error")
            err := String(parsed["error"])
    }
    NiumaMobileBrowser_QueueActToChat("host_browser_act_result", reqId, ok, err, String(action), Integer(elementId), false, "")
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

NiumaMobileBrowser_HideLabels() {
    global g_NiumaMobile_WV2, g_NiumaMobile_LabelDebug, JS_MOBILE_TOGGLE_DEBUG
    if !g_NiumaMobile_WV2
        return false
    g_NiumaMobile_LabelDebug := false
    try {
        g_NiumaMobile_WV2.ExecuteScriptAsync("(function(){try{window.__NIUMA_LABEL_DEBUG__=false;var r=document.getElementById('niuma-mobile-label-root');if(r)r.remove();var els=document.querySelectorAll('[data-niuma-label-id]');for(var i=0;i<els.length;i++){els[i].removeAttribute('data-niuma-label-id');els[i].classList.remove('niuma-label-target');els[i].style.outline='';els[i].style.outlineOffset='';}return JSON.stringify({ok:true});}catch(e){return JSON.stringify({ok:false});}})();")
    } catch {
    }
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
        , g_NiumaMobile_OpenInProgress, g_NiumaMobile_PendingOpen
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
            NiumaMobileBrowser_Log("GUARD", reqId, "observe 等待浏览器打开中")
            SetTimer(NiumaMobileBrowser_ObserveForChatDeferred.Bind(reqId), -1200)
            return true
        }
        NiumaMobileBrowser_Log("GUARD", reqId, "observe abort: browser_not_open")
        NiumaMobileBrowser_QueueSnapshotToChat([], "", "browser_not_open", false, 0, reqId)
        return false
    }
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
    global g_NiumaMobile_AiPaused
    if g_NiumaMobile_AiPaused
        return false
    act := StrLower(Trim(String(action)))
    if (act = "refresh" || act = "observe") {
        if (act = "observe")
            return NiumaMobileBrowser_ObserveForChat()
        NiumaMobileBrowser_RefreshLabels(0)
        return true
    }
    if (act = "click")
        return NiumaMobileBrowser_ClickLabeledElement(elementId)
    if (act = "input" || act = "fill")
        return NiumaMobileBrowser_InputLabeledElement(elementId, value)
    return false
}

NiumaMobileBrowser_Close() {
    global g_NiumaMobile_Env, g_NiumaMobile_Ctrl, g_NiumaMobile_WV2, g_NiumaMobile_Open
    global g_NiumaMobile_TokenNav, g_NiumaMobile_TokenNavStart, g_NiumaMobile_TokenNewWin, g_NiumaMobile_TokenMsg, g_NiumaMobile_ParentHwnd
    global g_NiumaMobile_LabelRefreshTimer, g_NiumaMobile_AiBusy, g_NiumaMobile_AiPaused
    global g_NiumaMobile_SettlePending, g_NiumaMobile_SettleNavPending, g_NiumaMobile_SettleReqId

    NiumaMobileBrowser_SetPendingOpen(false)
    g_NiumaMobile_OpenInProgress := false
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
