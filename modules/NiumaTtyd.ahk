; Niuma Chat 本机 ttyd 终端：端口检测、重试、WebView 回传
; 依赖主脚本中的 WebView_QueuePayload、A_ScriptDir

global NiumaTtyd_Port := 7681
global NiumaTtyd_Pid := 0
global NiumaTtyd__BootI := 0
global g_NiumaTtydReadyReqSeq := 0
global g_NiumaTtydReadyReqs := Map()
global g_NiumaTtydHttpHealthy := false
global g_NiumaTtydLastHttpTick := 0
global g_NiumaTtydHttpTTL := 900
global g_NiumaTtydHttpProbeInflight := false

/**
 * 返回 ttyd.exe 的完整路径（与主程序同目录）。
 * @returns {String}
 */
NiumaTtyd_ExePath() {
    return A_ScriptDir . "\ttyd.exe"
}

/**
 * 检测本机端口是否已处于 LISTEN 状态（与语言区域无关的 netstat+findstr 组合）。
 * @returns {Boolean}
 */
NiumaTtyd_IsPortListening() {
    return (NiumaTtyd_GetListeningPid(NiumaTtyd_Port) > 0)
}

NiumaTtyd_GetListeningPid(port := 0) {
    ; Phase B: avoid blocking RunWait/netstat probing in active path.
    ; We use process-level ownership as a fast non-blocking heuristic.
    pid := 0
    try pid := ProcessExist("ttyd.exe")
    catch {
        pid := 0
    }
    return Integer(pid)
}

NiumaTtyd_IsPortOwnedByTtyd(port := 0) {
    pid := NiumaTtyd_GetListeningPid(port)
    if (pid <= 0)
        return false
    try {
        return (StrLower(ProcessGetName(pid)) = "ttyd.exe")
    } catch {
        return false
    }
}

; 仅端口 LISTEN 并不代表 Web 页面已可用；补一层 HTTP 探测可避免 WebView2 首次拒绝访问
NiumaTtyd_IsHttpReady(waitMs := 1200) {
    global g_NiumaTtydHttpHealthy, g_NiumaTtydLastHttpTick, g_NiumaTtydHttpTTL
    if ((A_TickCount - Integer(g_NiumaTtydLastHttpTick)) <= Integer(g_NiumaTtydHttpTTL))
        return !!g_NiumaTtydHttpHealthy
    NiumaTtyd_IsHttpReadyAsync((ok, _ret) => NiumaTtyd_OnHttpProbeDone(ok), waitMs)
    return !!g_NiumaTtydHttpHealthy
}

NiumaTtyd_IsHttpReadyAsync(cb, waitMs := 1200, reqId := 0) {
    global g_NiumaTtydHttpProbeInflight
    if g_NiumaTtydHttpProbeInflight
        return 0
    g_NiumaTtydHttpProbeInflight := true
    u := NiumaTtyd_BaseUrl()
    opts := Map("timeoutMs", Integer(waitMs), "receiveTimeoutMs", Integer(waitMs), "tag", "ttyd_http_ready", "reqId", reqId)
    HttpGetAsync(u, (ret) => (
        NiumaTtyd_OnHttpProbeDone((ret is Map) && ret["status"] >= 200 && ret["status"] < 500),
        cb.Call((ret is Map) && ret["status"] >= 200 && ret["status"] < 500, ret)
    ), opts)
}

NiumaTtyd_OnHttpProbeDone(ok) {
    global g_NiumaTtydHttpHealthy, g_NiumaTtydLastHttpTick, g_NiumaTtydHttpProbeInflight
    g_NiumaTtydHttpProbeInflight := false
    g_NiumaTtydHttpHealthy := !!ok
    g_NiumaTtydLastHttpTick := A_TickCount
}

/**
 * 在尚未监听时启动 ttyd 进程；已监听则 no-op。
 * @returns {Boolean} 是否已尝试启动或已在监听
 */
; ttyd 启动后附加的可执行（默认 cmd.exe），可在 CursorShortcut.ini [NiumaTtyd] Shell= 覆写
NiumaTtyd_GetShell() {
    s := "cmd.exe"
    try {
        cf := A_ScriptDir . "\CursorShortcut.ini"
        r := IniRead(cf, "NiumaTtyd", "Shell", "cmd.exe")
        r := Trim(String(r))
        if (r != "")
            s := r
    } catch {
    }
    if (StrLen(s) > 800)
        s := "cmd.exe"
    return s
}

NiumaTtyd_SaveShellIni(shell) {
    sh := Trim(String(shell))
    if (sh = "")
        sh := "cmd.exe"
    if (StrLen(sh) > 800)
        sh := "cmd.exe"
    try {
        cf := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(sh, cf, "NiumaTtyd", "Shell")
    } catch {
    }
}

NiumaTtyd_WorkDir() {
    d := String(A_ScriptDir)
    if RegExMatch(d, "[^\x00-\x7F]") {
        try {
            u := String(EnvGet("USERPROFILE"))
            if (u != "" && !RegExMatch(u, "[^\x00-\x7F]") && DirExist(u))
                return u
        } catch {
        }
        if DirExist("C:\\")
            return "C:\\"
    }
    return d
}

NiumaTtyd_StartProcess() {
    global NiumaTtyd_Pid
    ttydExe := NiumaTtyd_ExePath()
    p := NiumaTtyd_Port
    if !FileExist(ttydExe)
        return false
    if NiumaTtyd_IsPortOwnedByTtyd(p) {
        NiumaTtyd_Pid := NiumaTtyd_GetListeningPid(p)
        return true
    }
    if (NiumaTtyd_IsPortListening())
        return false
    shell := NiumaTtyd_GetShell()
    workDir := NiumaTtyd_WorkDir()
    ; 可执行与参数原样作为 ttyd 的 command 尾段（与官方 ttyd 命令行一致）
    ; WebView2 鍦ㄩ儴鍒嗘満鍣ㄤ笂浼氬嚭鐜?xterm 娓叉煋鍣ㄩ粦灞忥紝寮哄埗 DOM renderer 鏇寸ǔ
    cmdLine := '"' . ttydExe . '" -W -i 127.0.0.1 -p ' . p . ' -t rendererType=dom -t fontSize=14 -w "' . workDir . '" ' . shell
    try {
        Run(cmdLine, workDir, "Hide", &pid)
        if (pid > 0)
            NiumaTtyd_Pid := pid
    } catch as e {
        ; 常见：杀软拦截、工作目录无权限、Shell 路径无效
        try {
            FileAppend(
                (FormatTime(, "yyyy-MM-dd HH:mm:ss")) . " ttyd Run failed: " . e.Message . "`n",
                A_ScriptDir . "\NiumaTtyd_debug.log", "UTF-8")
        } catch {
        }
        return false
    }
    return true
}

/**
 * 确保 ttyd 已监听，带超时与轮询（换机/杀软/慢速磁盘时更稳）。
 * @param {Number} timeoutMs 最长等待毫秒，默认 20000
 * @returns {Boolean} 成功则 true
 */
NiumaTtyd_EnsureReady(timeoutMs := 20000) {
    global NiumaTtyd_Pid
    if !FileExist(NiumaTtyd_ExePath())
        return false
    if NiumaTtyd_IsPortOwnedByTtyd(NiumaTtyd_Port) {
        NiumaTtyd_Pid := NiumaTtyd_GetListeningPid(NiumaTtyd_Port)
        if NiumaTtyd_IsHttpReady(1200)
            return true
    }
    if (NiumaTtyd_IsPortListening())
        return false
    if !NiumaTtyd_StartProcess()
        return false
    deadline := A_TickCount + Integer(timeoutMs)
    while (A_TickCount < deadline) {
        if NiumaTtyd_IsPortOwnedByTtyd(NiumaTtyd_Port) {
            NiumaTtyd_Pid := NiumaTtyd_GetListeningPid(NiumaTtyd_Port)
            if NiumaTtyd_IsHttpReady(1200)
                return true
        }
        Sleep(150)
    }
    return (NiumaTtyd_IsPortOwnedByTtyd(NiumaTtyd_Port) && NiumaTtyd_IsHttpReady(1200))
}

NiumaTtyd_EnsureReadyAsync(cb, timeoutMs := 20000) {
    global g_NiumaTtydReadyReqSeq, g_NiumaTtydReadyReqs, NiumaTtyd_Pid
    if !FileExist(NiumaTtyd_ExePath()) {
        cb.Call(false, "missing_ttyd_exe")
        return 0
    }
    if (NiumaTtyd_IsPortOwnedByTtyd(NiumaTtyd_Port)) {
        NiumaTtyd_Pid := NiumaTtyd_GetListeningPid(NiumaTtyd_Port)
    } else if (NiumaTtyd_IsPortListening()) {
        cb.Call(false, "port_occupied")
        return 0
    } else if !NiumaTtyd_StartProcess() {
        cb.Call(false, "start_failed")
        return 0
    }
    g_NiumaTtydReadyReqSeq += 1
    rid := g_NiumaTtydReadyReqSeq
    g_NiumaTtydReadyReqs[rid] := Map("cb", cb, "deadline", A_TickCount + Integer(timeoutMs), "inProbe", false)
    SetTimer((*) => NiumaTtyd_EnsureReadyStep(rid), -10)
    return rid
}

NiumaTtyd_EnsureReadyStep(rid) {
    global g_NiumaTtydReadyReqs, NiumaTtyd_Pid
    if !(g_NiumaTtydReadyReqs is Map) || !g_NiumaTtydReadyReqs.Has(rid)
        return
    req := g_NiumaTtydReadyReqs[rid]
    if (A_TickCount >= Integer(req["deadline"])) {
        cb := req["cb"]
        g_NiumaTtydReadyReqs.Delete(rid)
        cb.Call(false, "timeout")
        return
    }
    if !NiumaTtyd_IsPortOwnedByTtyd(NiumaTtyd_Port) {
        SetTimer((*) => NiumaTtyd_EnsureReadyStep(rid), -150)
        return
    }
    NiumaTtyd_Pid := NiumaTtyd_GetListeningPid(NiumaTtyd_Port)
    if req["inProbe"]
        return
    req["inProbe"] := true
    g_NiumaTtydReadyReqs[rid] := req
    NiumaTtyd_IsHttpReadyAsync((ok, _ret) => NiumaTtyd_EnsureReadyProbeDone(rid, ok), 1200, rid)
}

NiumaTtyd_EnsureReadyProbeDone(rid, ok) {
    global g_NiumaTtydReadyReqs
    if !(g_NiumaTtydReadyReqs is Map) || !g_NiumaTtydReadyReqs.Has(rid)
        return
    req := g_NiumaTtydReadyReqs[rid]
    cb := req["cb"]
    if ok {
        g_NiumaTtydReadyReqs.Delete(rid)
        cb.Call(true, "")
        return
    }
    req["inProbe"] := false
    g_NiumaTtydReadyReqs[rid] := req
    SetTimer((*) => NiumaTtyd_EnsureReadyStep(rid), -180)
}

/**
 * 结束本机 ttyd 进程后重新拉起并等待端口就绪（「重启」按钮用）。
 * @param {Number} waitMs
 * @returns {Boolean}
 */
NiumaTtyd_Restart(waitMs := 20000) {
    try {
        Run(A_ComSpec . ' /c "taskkill /F /IM ttyd.exe 2>nul"', , "Hide")
    } catch {
    }
    Sleep(120)
    return NiumaTtyd_EnsureReady(waitMs)
}

NiumaTtyd_StopProcess() {
    global NiumaTtyd_Pid
    pid := NiumaTtyd_Pid
    if (pid > 0) {
        try ProcessClose(pid)
    }
    pid2 := NiumaTtyd_GetListeningPid(NiumaTtyd_Port)
    if (pid2 > 0) {
        try {
            if (StrLower(ProcessGetName(pid2)) = "ttyd.exe")
                ProcessClose(pid2)
        } catch {
        }
    }
    NiumaTtyd_Pid := 0
}

/**
 * 向 WebView2 回传终端就绪/失败，供 HTML 在就绪后再设 iframe，避免 127.0.0.1 拒绝。
 * @param wv2 WebView2 实例，可为 0
 * @param {Boolean} ok
 * @param {String} errMsg 失败时短文案
 * @param {String} baseUrl 成功时页地址
 */
NiumaTtyd_NotifyWeb(wv2, ok, errMsg, baseUrl) {
    if !wv2
        return
    try {
        if (ok) {
            WebView_QueuePayload(wv2, Map("type", "ttyd_ready", "baseUrl", String(baseUrl)))
        } else {
            WebView_QueuePayload(
                wv2, Map("type", "ttyd_error", "message", errMsg = "" ? "终端未就绪" : errMsg)
            )
        }
    } catch {
    }
}

NiumaTtyd_BaseUrl() {
    return "http://localhost:" . NiumaTtyd_Port . "/"
}

NiumaTtyd_OpenExternal(url := "") {
    u := Trim(String(url))
    if (u = "")
        u := NiumaTtyd_BaseUrl()
    if !NiumaTtyd_EnsureReady(20000)
        return false
    try {
        Run(u)
        return true
    } catch {
        return false
    }
}

; WebMessage 里同步长逻辑会卡 UI：延期到独立定时器
NiumaTtyd_DeferredOpenJob(*) {
    global g_FTB_WV2
    wv2 := g_FTB_WV2
    if !FileExist(NiumaTtyd_ExePath()) {
        NiumaTtyd_NotifyWeb(wv2, false, "missing ttyd.exe", "")
        return
    }
    NiumaTtyd_EnsureReadyAsync((ok, reason) => (
        ok
            ? NiumaTtyd_NotifyWeb(wv2, true, "", NiumaTtyd_BaseUrl())
            : NiumaTtyd_NotifyWeb(wv2, false, "20s ready timeout: " . reason, "")
    ), 20000)
}

NiumaTtyd_DeferredRestartJob(*) {
    global g_FTB_WV2
    wv2 := g_FTB_WV2
    if !FileExist(NiumaTtyd_ExePath()) {
        NiumaTtyd_NotifyWeb(wv2, false, "missing ttyd.exe", "")
        return
    }
    try Run(A_ComSpec . ' /c "taskkill /F /IM ttyd.exe 2>nul"', , "Hide")
    SetTimer((*) => NiumaTtyd_EnsureReadyAsync((ok, reason) => (
        ok
            ? NiumaTtyd_NotifyWeb(wv2, true, "", NiumaTtyd_BaseUrl())
            : NiumaTtyd_NotifyWeb(wv2, false, "restart failed: " . reason, "")
    ), 25000), -500)
}

NiumaTtyd_DeferredExternalOpenJob(*) {
    global g_FTB_WV2
    wv2 := g_FTB_WV2
    NiumaTtyd_EnsureReadyAsync((ok, reason) => (
        ok
            ? (Run(NiumaTtyd_BaseUrl()), NiumaTtyd_NotifyWeb(wv2, true, "", NiumaTtyd_BaseUrl()))
            : NiumaTtyd_NotifyWeb(wv2, false, "open external failed: " . reason, "")
    ), 20000)
}

/**
 * 主程序启动时热启动 ttyd，并多轮短重试，避免比 WebView/iframe 晚就绪。
 * @param {Object} * 定时器用
 */
AutoStartTtydForNiumaChat(*) {
    global NiumaTtyd__BootI
    NiumaTtyd__BootI := 0
    NiumaTtyd_StartProcess()
    SetTimer(NiumaTtyd_BootstrapRetryStep, -600)
}

NiumaTtyd_BootstrapRetryStep(*) {
    global NiumaTtyd__BootI
    NiumaTtyd__BootI++
    if (NiumaTtyd_IsPortOwnedByTtyd(NiumaTtyd_Port) || NiumaTtyd__BootI > 20) {
        NiumaTtyd__BootI := 0
        return
    }
    NiumaTtyd_StartProcess()
    SetTimer(NiumaTtyd_BootstrapRetryStep, -500)
}

