; ======================================================================================================================
; NiumaMobileBrowser.ahk — Niuma Chat 内置手机浏览器（独立 WebView2 Environment / UserData）
; ======================================================================================================================

#Requires AutoHotkey v2.0

global g_NiumaMobile_Env := 0
global g_NiumaMobile_Ctrl := 0
global g_NiumaMobile_WV2 := 0
global g_NiumaMobile_Open := false
global g_NiumaMobile_PendingOpen := false
global g_NiumaMobile_PendingUrl := ""
global NIUMA_MOBILE_DEFAULT_URL := "https://www.baidu.com"
global g_NiumaMobile_ParentHwnd := 0
global g_NiumaMobile_TokenNav := 0
global g_NiumaMobile_TokenNewWin := 0
global g_NiumaMobile_WidthLogical := 400
; 主 Chat WebView（由 FloatingToolbar.ahk 赋值；此处仅声明供本模块引用）
global g_FTB_WV2 := 0
global g_NiumaMobile_Wv2Class := 0

NIUMA_MOBILE_UA := "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"

NIUMA_MOBILE_INJECT_JS := "(function(){try{var s=document.createElement('style');s.textContent='.download-app-banner,.open-in-app,[class*=download-app],[id*=download-app]{display:none!important} body{overflow:auto!important}';document.head.appendChild(s);}catch(e){}})();"

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
    global g_FTB_WV2
    return IsObject(g_FTB_WV2) ? g_FTB_WV2 : 0
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
    if (w < 375)
        w := 375
    if (w > 450)
        w := 450
    return w
}

NiumaMobileBrowser_WidthPx() {
    eff := 1.0
    r := NiumaMobileBrowser_CallFunc("FloatingToolbar_EffectiveScale")
    if IsNumber(r) && r > 0.01
        eff := r
    return Max(1, Round(NiumaMobileBrowser_LogicalWidth() * eff))
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

NiumaMobileBrowser_Open(hwndParent, url := "") {
    global g_NiumaMobile_PendingUrl, g_NiumaMobile_ParentHwnd
    if !hwndParent
        return false
    g_NiumaMobile_ParentHwnd := hwndParent
    u := NiumaMobileBrowser_NormalizeUrl(url)
    g_NiumaMobile_PendingUrl := u

    if NiumaMobileBrowser_IsOpen() {
        global g_NiumaMobile_WV2
        try g_NiumaMobile_WV2.Navigate(u)
        NiumaMobileBrowser_NotifyState(true, u)
        return true
    }

    wv2cls := NiumaMobileBrowser_Wv2Class()
    if !IsObject(wv2cls) {
        NiumaMobileBrowser_SetPendingOpen(false)
        NiumaMobileBrowser_NotifyError("WebView2 未就绪，请先打开 NiuMa Chat 主界面")
        return false
    }

    dataDir := NiumaMobileBrowser_GetDataPath()
    try {
        wv2cls.CreateEnvironmentAsync(0, dataDir)
            .then(NiumaMobileBrowser_OnEnvReady.Bind(hwndParent))
    } catch as e {
        NiumaMobileBrowser_SetPendingOpen(false)
        NiumaMobileBrowser_TryCallFunc("FloatingToolbar_AfterMobileBrowserClose")
        NiumaMobileBrowser_NotifyError("手机浏览器启动失败: " . e.Message)
        try OutputDebug("[NiumaMobile] CreateEnvironmentAsync failed: " . e.Message)
        catch {
        }
        return false
    }
    return true
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
        NiumaMobileBrowser_SetPendingOpen(false)
        NiumaMobileBrowser_NotifyError("手机浏览器环境创建失败")
        NiumaMobileBrowser_TryCallFunc("FloatingToolbar_AfterMobileBrowserClose")
        return
    }
    g_NiumaMobile_Env := env
    try {
        env.CreateCoreWebView2ControllerAsync(hwndParent).then(NiumaMobileBrowser_OnControllerReady)
    } catch as e {
        NiumaMobileBrowser_SetPendingOpen(false)
        NiumaMobileBrowser_NotifyError("手机浏览器控制器启动失败: " . e.Message)
        NiumaMobileBrowser_TryCallFunc("FloatingToolbar_AfterMobileBrowserClose")
        try OutputDebug("[NiumaMobile] CreateCoreWebView2ControllerAsync failed: " . e.Message)
        catch {
        }
    }
}

NiumaMobileBrowser_OnControllerReady(ctrl) {
    global g_NiumaMobile_Ctrl, g_NiumaMobile_WV2, g_NiumaMobile_Open, g_NiumaMobile_PendingUrl
    global g_NiumaMobile_TokenNav, g_NiumaMobile_TokenNewWin, NIUMA_MOBILE_UA

    if !ctrl {
        NiumaMobileBrowser_SetPendingOpen(false)
        NiumaMobileBrowser_TryCallFunc("FloatingToolbar_AfterMobileBrowserClose")
        NiumaMobileBrowser_NotifyError("手机浏览器控制器创建失败")
        return
    }
    NiumaMobileBrowser_SetPendingOpen(false)
    g_NiumaMobile_Ctrl := ctrl
    g_NiumaMobile_WV2 := 0
    try g_NiumaMobile_WV2 := ctrl.CoreWebView2
    if !IsObject(g_NiumaMobile_WV2) {
        try ctrl.Close()
        catch {
        }
        g_NiumaMobile_Ctrl := 0
        NiumaMobileBrowser_SetPendingOpen(false)
        NiumaMobileBrowser_NotifyError("手机浏览器内核创建失败")
        NiumaMobileBrowser_TryCallFunc("FloatingToolbar_AfterMobileBrowserClose")
        return
    }

    try ctrl.DefaultBackgroundColor := 0xFF0A0A0A
    try ctrl.IsVisible := true

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

    try g_NiumaMobile_TokenNav := g_NiumaMobile_WV2.add_NavigationCompleted(NiumaMobileBrowser_OnNavigationCompleted)
    catch {
        g_NiumaMobile_TokenNav := 0
    }
    try g_NiumaMobile_TokenNewWin := g_NiumaMobile_WV2.add_NewWindowRequested(NiumaMobileBrowser_OnNewWindowRequested)
    catch {
        g_NiumaMobile_TokenNewWin := 0
    }

    g_NiumaMobile_Open := true
    url := g_NiumaMobile_PendingUrl
    if (url = "")
        url := "about:blank"
    try g_NiumaMobile_WV2.Navigate(url)
    catch {
    }

    NiumaMobileBrowser_NotifyState(true, url)
    NiumaMobileBrowser_TryCallFunc("FloatingToolbar_AfterMobileBrowserOpen")
    try NiumaMobileBrowser_ApplyBounds(g_NiumaMobile_ParentHwnd)
    catch {
    }
}

NiumaMobileBrowser_OnNavigationCompleted(sender, args) {
    global g_NiumaMobile_WV2, NIUMA_MOBILE_INJECT_JS
    if !g_NiumaMobile_WV2
        return
    try {
        if IsObject(args) && args.HasProp("IsSuccess") && !args.IsSuccess
            return
    } catch {
    }
    try g_NiumaMobile_WV2.ExecuteScriptAsync(NIUMA_MOBILE_INJECT_JS)
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
        g_NiumaMobile_WV2.ExecuteScriptAsync(script).then(NiumaMobileBrowser_OnExtractDone)
        return true
    } catch {
    }
    return false
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
    wv2 := NiumaMobileBrowser_ChatWv2()
    if !wv2
        return
    NiumaMobileBrowser_TryCallFunc("WebView_QueuePayload", wv2, Map("type", "host_mobile_browser_state", "open", !!open, "url", String(url)))
}

NiumaMobileBrowser_Close() {
    global g_NiumaMobile_Env, g_NiumaMobile_Ctrl, g_NiumaMobile_WV2, g_NiumaMobile_Open
    global g_NiumaMobile_TokenNav, g_NiumaMobile_TokenNewWin, g_NiumaMobile_ParentHwnd

    NiumaMobileBrowser_SetPendingOpen(false)
    if g_NiumaMobile_WV2 {
        try {
            if g_NiumaMobile_TokenNav
                g_NiumaMobile_WV2.remove_NavigationCompleted(g_NiumaMobile_TokenNav)
        } catch {
        }
        try {
            if g_NiumaMobile_TokenNewWin
                g_NiumaMobile_WV2.remove_NewWindowRequested(g_NiumaMobile_TokenNewWin)
        } catch {
        }
    }
    g_NiumaMobile_TokenNav := 0
    g_NiumaMobile_TokenNewWin := 0

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
