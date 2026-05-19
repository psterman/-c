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
global g_NiumaTtydHttpFailTTL := 12            ; fail 短 TTL：ttyd 启动中允许快速重探，避免 300s 锁死 loading
global g_NiumaTtydEngineWarmupProbeMs := 45000 ; 引擎刚拉起后，忽略 fail 缓存并继续探活
global g_NiumaTtydHttpProbeInflight := false
global g_NiumaTtydRealProbeCooldownMs := 3000 ; 每端口 3s 探活冷却（按端口，避免 Gemini 被其它引擎探活挡住）
global g_NiumaTtydLastRealProbeByPort := Map() ; port -> 上次真实探活完成 tick
global g_NiumaTtydEngineWarmupProbeMsByEngine := Map("gemini_cli", 120000) ; gemini CLI 启动慢，延长预热
global g_NiumaTtydPortProbeInflight := Map()  ; port -> true，按端口去重 inflight
global g_NiumaTtydLastReqId := ""
global g_NiumaTtydEnginePids := Map()
global g_NiumaTtydHttpByPort := Map()
global g_NiumaTtydEngineShell := Map()
global g_NiumaTtydEngineHealthyUntil := Map() ; engine -> tick
global g_NiumaTtydEngineInflight := Map()     ; engine -> true/false
global g_NiumaTtydEngineInflightSince := Map() ; engine -> tick（用于陈旧 inflight 自愈）
global g_NiumaTtydOpenRetryOnce := Map()      ; reqId -> retried
global g_NiumaTtydEngineStartTick := Map()    ; engine -> tick

NiumaTtyd_CliEngineList() {
    return [
        "codex_cli", "gemini_cli", "openclaw_cli", "qwen_cli", "ollama_cli",
        "claude_cli", "deepseek_cli", "kimi_cli", "zhipu_cli", "copilot_cli"
    ]
}

NiumaTtyd_IsCliEngine(engine) {
    e := "|codex_cli|gemini_cli|openclaw_cli|qwen_cli|ollama_cli|claude_cli|deepseek_cli|kimi_cli|zhipu_cli|copilot_cli|"
    return InStr(e, "|" . Trim(String(engine)) . "|")
}

NiumaTtyd_NormalizeEngine(engine) {
    eng := Trim(String(engine))
    if (eng = "")
        return "codex_cli"
    if NiumaTtyd_IsCliEngine(eng)
        return eng
    static WebToCli := 0
    if !IsObject(WebToCli) {
        WebToCli := Map(
            "codex", "codex_cli",
            "chatgpt", "codex_cli",
            "gemini", "gemini_cli",
            "openclaw", "openclaw_cli",
            "qwen", "qwen_cli",
            "qianwen", "qwen_cli",
            "ollama", "ollama_cli",
            "claude", "claude_cli",
            "deepseek", "deepseek_cli",
            "kimi", "kimi_cli",
            "zhipu", "zhipu_cli",
            "copilot", "copilot_cli"
        )
    }
    if WebToCli.Has(eng)
        return WebToCli[eng]
    return "codex_cli"
}

NiumaTtyd_PortForEngine(engine) {
    static Ports := 0
    if !IsObject(Ports) {
        Ports := Map(
            "codex_cli", 7681,
            "gemini_cli", 7682,
            "openclaw_cli", 7683,
            "qwen_cli", 7684,
            "ollama_cli", 7685,
            "claude_cli", 7686,
            "deepseek_cli", 7687,
            "kimi_cli", 7688,
            "zhipu_cli", 7689,
            "copilot_cli", 7690
        )
    }
    eng := NiumaTtyd_NormalizeEngine(engine)
    return Ports.Has(eng) ? Ports[eng] : 7681
}

NiumaTtyd_BaseUrlForEngine(engine) {
    return "http://127.0.0.1:" . NiumaTtyd_PortForEngine(engine) . "/"
}

NiumaTtyd_EngineFromPort(port) {
    port := Integer(port)
    for eng in NiumaTtyd_CliEngineList() {
        if (NiumaTtyd_PortForEngine(eng) = port)
            return eng
    }
    return "codex_cli"
}

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

NiumaTtyd_StaleDomain(action, engine := "") {
    eng := Trim(String(engine))
    if (eng != "")
        return "ttyd:" . Trim(String(action)) . ":" . eng
    return "ttyd:" . Trim(String(action))
}

NiumaTtyd_MarkLatestReq(action, reqId, engine := "") {
    a := Trim(String(action))
    rid := Trim(String(reqId))
    if (a = "" || rid = "")
        return
    if FuncExists("AsyncGuardrails_UpdateLatest")
        AsyncGuardrails_UpdateLatest(NiumaTtyd_StaleDomain(a, engine), rid)
}

NiumaTtyd_ShouldDropReq(action, reqId, engine := "") {
    a := Trim(String(action))
    rid := Trim(String(reqId))
    if (a = "" || rid = "")
        return false
    if FuncExists("AsyncGuardrails_ShouldDropStale")
        return AsyncGuardrails_ShouldDropStale(NiumaTtyd_StaleDomain(a, engine), rid)
    return false
}

NiumaTtyd_LogStaleDrop(action, reqId) {
    try CoreAsyncHttp_Log("ttyd_drop_stale_req", "action=" . String(action) . " req_id=" . String(reqId))
}

NiumaTtyd_IsHttpReadyAsync(cb, waitMs := 1200, reqId := 0) {
    global g_NiumaTtydHttpProbeInflight, g_NiumaTtydLastRealProbeTick, g_NiumaTtydRealProbeCooldownMs
    global g_NiumaTtydHttpHealthy, g_NiumaTtydLastHttpTick, g_NiumaTtydHttpTTL
    if g_NiumaTtydHttpProbeInflight
        return 0
    now := A_TickCount
    ; 与按端口探活共享 3s 冷却，避免默认端口与多引擎端口双通道重复打 HTTP
    if (g_NiumaTtydLastRealProbeTick > 0
        && (now - Integer(g_NiumaTtydLastRealProbeTick)) < Integer(g_NiumaTtydRealProbeCooldownMs)) {
        if ((now - Integer(g_NiumaTtydLastHttpTick)) <= Integer(g_NiumaTtydHttpTTL))
            cb.Call(!!g_NiumaTtydHttpHealthy, Map())
        else
            cb.Call(false, Map())
        return 0
    }
    g_NiumaTtydHttpProbeInflight := true
    u := NiumaTtyd_BaseUrl()
    rid := Trim(String(reqId))
    act := "http_probe"
    if (rid != "")
        NiumaTtyd_MarkLatestReq(act, rid)
    opts := Map("timeoutMs", Integer(waitMs), "receiveTimeoutMs", Integer(waitMs), "tag", "ttyd_http_ready", "reqId", reqId)
    HttpGetAsync(u, (ret) => (
        (rid != "" && NiumaTtyd_ShouldDropReq(act, rid))
            ? (NiumaTtyd_LogStaleDrop(act, rid), 0)
            : (NiumaTtyd_OnHttpProbeDone((ret is Map) && ret["status"] >= 200 && ret["status"] < 500),
                cb.Call((ret is Map) && ret["status"] >= 200 && ret["status"] < 500, ret))
    ), opts)
}

NiumaTtyd_OnHttpProbeDone(ok) {
    global g_NiumaTtydHttpHealthy, g_NiumaTtydLastHttpTick, g_NiumaTtydHttpProbeInflight
    global g_NiumaTtydLastRealProbeTick
    g_NiumaTtydHttpProbeInflight := false
    g_NiumaTtydHttpHealthy := !!ok
    g_NiumaTtydLastHttpTick := A_TickCount
    g_NiumaTtydLastRealProbeTick := A_TickCount
}

NiumaTtyd_NormalizeUrl(url, &hostOut := "", &portOut := 0) {
    u := Trim(String(url))
    if !RegExMatch(u, "i)^https?://([^/:]+)(?::(\d+))?/?", &m)
        return ""
    host := StrLower(Trim(String(m[1])))
    if (host = "localhost")
        host := "127.0.0.1"
    port := (m[2] != "") ? Integer(m[2]) : 80
    hostOut := host
    portOut := port
    return "http://" . host . ":" . port . "/"
}

NiumaTtyd_EmitStatus(wv2, state, reqId := "", msg := "") {
    if !wv2
        return
    try WebView_QueuePayload(wv2, Map(
        "type", "ttyd_status",
        "state", String(state),
        "reqId", String(reqId),
        "port", Integer(NiumaTtyd_Port),
        "message", String(msg)
    ))
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
NiumaTtyd_BareCliBootName(engine) {
    eng := NiumaTtyd_NormalizeEngine(engine)
    static BareCli := 0
    if !IsObject(BareCli) {
        BareCli := Map(
            "codex_cli", "codex",
            "gemini_cli", "gemini",
            "openclaw_cli", "openclaw",
            "qwen_cli", "qwen",
            "ollama_cli", "ollama",
            "claude_cli", "claude",
            "deepseek_cli", "deepseek",
            "kimi_cli", "kimi",
            "zhipu_cli", "chelper",
            "copilot_cli", "copilot"
        )
    }
    return BareCli.Has(eng) ? String(BareCli[eng]) : ""
}

; 仅当 ttyd 使用裸 cmd（未带 /k <cli>）时，通知前端注入首条启动命令
NiumaTtyd_AutoBootCmdForEngine(engine) {
    global g_NiumaTtydEngineShell
    eng := NiumaTtyd_NormalizeEngine(engine)
    sh := ""
    if (g_NiumaTtydEngineShell is Map) && g_NiumaTtydEngineShell.Has(eng)
        sh := Trim(String(g_NiumaTtydEngineShell[eng]))
    low := StrLower(sh)
    if (low != "cmd.exe /k" && low != "cmd /k")
        return ""
    return NiumaTtyd_BareCliBootName(eng)
}

NiumaTtyd_NotifyWeb(wv2, ok, errMsg, baseUrl, reqId := "", engine := "") {
    if !wv2
        return
    eng := NiumaTtyd_NormalizeEngine(engine)
    port := NiumaTtyd_PortForEngine(eng)
    try {
        NiumaTtyd_EmitStatus(wv2, ok ? "ready" : "error", reqId, ok ? "" : errMsg)
        if (ok) {
            payload := Map(
                "type", "ttyd_ready",
                "baseUrl", baseUrl != "" ? String(baseUrl) : NiumaTtyd_BaseUrlForEngine(eng),
                "reqId", String(reqId),
                "port", port,
                "engine", eng
            )
            boot := NiumaTtyd_AutoBootCmdForEngine(eng)
            if (boot != "")
                payload["autoBootCmd"] := boot
            WebView_QueuePayload(wv2, payload)
        } else {
            WebView_QueuePayload(wv2, Map(
                "type", "ttyd_error",
                "message", errMsg = "" ? "终端未就绪" : errMsg,
                "reqId", String(reqId),
                "port", port,
                "engine", eng
            ))
        }
    } catch {
    }
}

NiumaTtyd_BaseUrl() {
    return NiumaTtyd_BaseUrlForEngine("codex_cli")
}

; ttyd 需保持交互会话：用 cmd /k 或 PowerShell -NoExit（勿用 /c）
NiumaTtyd_FormatShellForExe(exePath) {
    exe := Trim(String(exePath))
    if (exe = "")
        return ""
    if RegExMatch(exe, "i)\.ps1$")
        return 'powershell.exe -NoExit -ExecutionPolicy Bypass -File "' . exe . '"'
    return 'cmd.exe /k "' . exe . '"'
}

; AHK v2：对不存在的键 Delete 会抛错，须先 Has
NiumaTtyd_MapRemoveKey(mapObj, key) {
    if !IsObject(mapObj)
        return
    try {
        if mapObj.Has(key)
            mapObj.Delete(key)
    } catch {
    }
}

NiumaTtyd_LogShell(engine, shell, note := "") {
    try {
        FileAppend(
            (FormatTime(, "yyyy-MM-dd HH:mm:ss")) . " ttyd shell [" . engine . "] " . note . ": " . shell . "`n",
            A_ScriptDir . "\NiumaTtyd_debug.log", "UTF-8")
    } catch {
    }
}

; ttyd 启动命令：默认与各 CLI 一致自动拉起（cmd /k gemini 等）；可用 CursorShortcut.ini 的 <engine>_ttyd_shell 覆盖
NiumaTtyd_GetTtydShellForEngine(engine) {
    eng := NiumaTtyd_NormalizeEngine(engine)
    try {
        cf := A_ScriptDir . "\CursorShortcut.ini"
        r := Trim(IniRead(cf, "NiumaTtyd", eng . "_ttyd_shell", ""))
        if (r != "") {
            NiumaTtyd_LogShell(eng, r, "ini_ttyd")
            return r
        }
    } catch {
    }
    if FuncExists("GetPreferredCLIExecutable") {
        exe := GetPreferredCLIExecutable(eng)
        if (exe != "") {
            if (InStr(exe, "\") || InStr(exe, "/")) {
                sh := NiumaTtyd_FormatShellForExe(exe)
                NiumaTtyd_LogShell(eng, sh, "ttyd_resolved_path")
                return sh
            }
            sh := "cmd.exe /k " . exe
            NiumaTtyd_LogShell(eng, sh, "ttyd_resolved_bare")
            return sh
        }
    }
    static BareCli := 0
    if !IsObject(BareCli) {
        BareCli := Map(
            "codex_cli", "codex",
            "gemini_cli", "gemini",
            "openclaw_cli", "openclaw",
            "qwen_cli", "qwen",
            "ollama_cli", "ollama",
            "claude_cli", "claude",
            "deepseek_cli", "deepseek",
            "kimi_cli", "kimi",
            "zhipu_cli", "chelper",
            "copilot_cli", "copilot"
        )
    }
    if BareCli.Has(eng) {
        sh := "cmd.exe /k " . BareCli[eng]
        NiumaTtyd_LogShell(eng, sh, "ttyd_auto_cli")
        return sh
    }
    return "cmd.exe /k"
}

NiumaTtyd_GetShellForEngine(engine) {
    eng := NiumaTtyd_NormalizeEngine(engine)
    try {
        cf := A_ScriptDir . "\CursorShortcut.ini"
        r := Trim(IniRead(cf, "NiumaTtyd", eng . "_shell", ""))
        if (r != "") {
            NiumaTtyd_LogShell(eng, r, "ini")
            return r
        }
        r := Trim(IniRead(cf, "NiumaTtyd", "Shell_" . eng, ""))
        if (r != "") {
            NiumaTtyd_LogShell(eng, r, "ini_legacy")
            return r
        }
    } catch {
    }
    if FuncExists("GetPreferredCLIExecutable") {
        exe := GetPreferredCLIExecutable(eng)
        if (exe != "") {
            if (InStr(exe, "\") || InStr(exe, "/")) {
                sh := NiumaTtyd_FormatShellForExe(exe)
                NiumaTtyd_LogShell(eng, sh, "resolved_path")
                return sh
            }
            sh := "cmd.exe /k " . exe
            NiumaTtyd_LogShell(eng, sh, "resolved_bare")
            return sh
        }
    }
    static BareCli := 0
    if !IsObject(BareCli) {
        BareCli := Map(
            "codex_cli", "codex",
            "gemini_cli", "gemini",
            "openclaw_cli", "openclaw",
            "qwen_cli", "qwen",
            "ollama_cli", "ollama",
            "claude_cli", "claude",
            "deepseek_cli", "deepseek",
            "kimi_cli", "kimi",
            "zhipu_cli", "chelper",
            "copilot_cli", "copilot"
        )
    }
    if BareCli.Has(eng) {
        sh := "cmd.exe /k " . BareCli[eng]
        NiumaTtyd_LogShell(eng, sh, "fallback_bare_name")
        return sh
    }
    sh := NiumaTtyd_GetShell()
    NiumaTtyd_LogShell(eng, sh, "fallback_global")
    return sh
}

NiumaTtyd_WarmupProbeMsForEngine(engine) {
    global g_NiumaTtydEngineWarmupProbeMs, g_NiumaTtydEngineWarmupProbeMsByEngine
    eng := NiumaTtyd_NormalizeEngine(engine)
    if (g_NiumaTtydEngineWarmupProbeMsByEngine is Map) && g_NiumaTtydEngineWarmupProbeMsByEngine.Has(eng)
        return Integer(g_NiumaTtydEngineWarmupProbeMsByEngine[eng])
    return Integer(g_NiumaTtydEngineWarmupProbeMs)
}

NiumaTtyd_IsEngineInWarmup(engine, now := 0) {
    global g_NiumaTtydEngineStartTick
    eng := NiumaTtyd_NormalizeEngine(engine)
    if !(g_NiumaTtydEngineStartTick is Map) || !g_NiumaTtydEngineStartTick.Has(eng)
        return false
    if !now
        now := A_TickCount
    return (now - Integer(g_NiumaTtydEngineStartTick[eng])) < NiumaTtyd_WarmupProbeMsForEngine(eng)
}

NiumaTtyd_EngineProcessAlive(engine) {
    global g_NiumaTtydEnginePids
    eng := NiumaTtyd_NormalizeEngine(engine)
    if !(g_NiumaTtydEnginePids is Map) || !g_NiumaTtydEnginePids.Has(eng)
        return false
    try {
        pid := Integer(g_NiumaTtydEnginePids[eng])
        return (pid > 0 && ProcessExist(pid))
    } catch {
        return false
    }
}

; 微创：非阻塞端口探活——绝不调用同步 WinHttp.Send，主线程立即返回缓存/触发后台 HttpGetAsync
NiumaTtyd_IsHttpReadyOnPort(port, waitMs := 1200) {
    global g_NiumaTtydHttpByPort, g_NiumaTtydHttpTTL, g_NiumaTtydHttpFailTTL
    global g_NiumaTtydEngineHealthyUntil, g_NiumaTtydLastRealProbeByPort, g_NiumaTtydRealProbeCooldownMs
    global g_NiumaTtydPortProbeInflight
    port := Integer(port)
    if !IsObject(g_NiumaTtydHttpByPort)
        g_NiumaTtydHttpByPort := Map()
    if !(g_NiumaTtydPortProbeInflight is Map)
        g_NiumaTtydPortProbeInflight := Map()
    now := A_TickCount
    eng := NiumaTtyd_EngineFromPort(port)
    inWarmup := NiumaTtyd_IsEngineInWarmup(eng, now)
    ; 1) 端口 TTL 缓存命中（预热期内的 fail 缓存忽略，避免 Gemini 等引擎永久 loading）
    if g_NiumaTtydHttpByPort.Has(port) {
        ent := g_NiumaTtydHttpByPort[port]
        ttl := !!ent["ok"] ? Integer(g_NiumaTtydHttpTTL) : Integer(g_NiumaTtydHttpFailTTL)
        if ((now - Integer(ent["tick"])) <= ttl) {
            if !!ent["ok"]
                return true
            if !inWarmup
                return false
            NiumaTtyd_MapRemoveKey(g_NiumaTtydHttpByPort, port)
        }
    }
    ; 2) 引擎健康短路（与 EnsureReadyForEngineAsync 一致）
    if (g_NiumaTtydEngineHealthyUntil is Map) && g_NiumaTtydEngineHealthyUntil.Has(eng) {
        if (Integer(g_NiumaTtydEngineHealthyUntil[eng]) > now)
            return true
    }
    cachedOk := false
    hasCache := g_NiumaTtydHttpByPort.Has(port)
    if hasCache
        cachedOk := !!g_NiumaTtydHttpByPort[port]["ok"]
    ; 3) 每端口探活冷却：有缓存才短路；无缓存必须继续排队（修复 Gemini 被全局冷却挡死）
    lastProbe := 0
    if (g_NiumaTtydLastRealProbeByPort is Map) && g_NiumaTtydLastRealProbeByPort.Has(port)
        lastProbe := Integer(g_NiumaTtydLastRealProbeByPort[port])
    if (lastProbe > 0 && (now - lastProbe) < Integer(g_NiumaTtydRealProbeCooldownMs) && hasCache)
        return cachedOk
    ; 4) 排队异步探活（按端口去重）
    if !g_NiumaTtydPortProbeInflight.Has(port)
        NiumaTtyd_QueuePortProbe(port, waitMs)
    ; 5) 立即返回：无有效 TTL 时 false，触发前端 loading；EnsureEngineReadyStep 轮询等待缓存回填
    return false
}

NiumaTtyd_QueuePortProbe(port, waitMs := 800) {
    global g_NiumaTtydPortProbeInflight
    port := Integer(port)
    if port <= 0
        return
    if !(g_NiumaTtydPortProbeInflight is Map)
        g_NiumaTtydPortProbeInflight := Map()
    if g_NiumaTtydPortProbeInflight.Has(port)
        return
    g_NiumaTtydPortProbeInflight[port] := true
    tmo := Integer(waitMs)
    if (tmo < 120)
        tmo := 120
    if (tmo > 1200)
        tmo := 1200
    engProbe := NiumaTtyd_EngineFromPort(port)
    if (engProbe = "gemini_cli" && tmo < 800)
        tmo := 800
    url := "http://127.0.0.1:" . port . "/"
    opts := Map(
        "timeoutMs", tmo,
        "receiveTimeoutMs", tmo,
        "tag", "ttyd_port_probe",
        "reqId", port
    )
    HttpGetAsync(url, (ret) => (
        NiumaTtyd_OnPortProbeDone(port, (ret is Map) && Integer(ret["status"]) >= 200 && Integer(ret["status"]) < 500)
    ), opts)
}

NiumaTtyd_OnPortProbeDone(port, ok) {
    global g_NiumaTtydHttpByPort, g_NiumaTtydPortProbeInflight, g_NiumaTtydLastRealProbeByPort
    global g_NiumaTtydEngineHealthyUntil, g_NiumaTtydEngineInflight, g_NiumaTtydEngineInflightSince
    port := Integer(port)
    if !IsObject(g_NiumaTtydHttpByPort)
        g_NiumaTtydHttpByPort := Map()
    if !(g_NiumaTtydLastRealProbeByPort is Map)
        g_NiumaTtydLastRealProbeByPort := Map()
    now := A_TickCount
    g_NiumaTtydHttpByPort[port] := Map("ok", !!ok, "tick", now)
    g_NiumaTtydLastRealProbeByPort[port] := now
    if (g_NiumaTtydPortProbeInflight is Map)
        NiumaTtyd_MapRemoveKey(g_NiumaTtydPortProbeInflight, port)
    if ok {
        eng := NiumaTtyd_EngineFromPort(port)
        if !(g_NiumaTtydEngineHealthyUntil is Map)
            g_NiumaTtydEngineHealthyUntil := Map()
        g_NiumaTtydEngineHealthyUntil[eng] := now + 15000
        if (g_NiumaTtydEngineInflight is Map && g_NiumaTtydEngineInflight.Has(eng))
            g_NiumaTtydEngineInflight[eng] := false
        if (g_NiumaTtydEngineInflightSince is Map)
            NiumaTtyd_MapRemoveKey(g_NiumaTtydEngineInflightSince, eng)
        NiumaTtyd_NotifyWebOnPortReady(port)
    }
}

; 异步探活成功后主动通知 WebView（否则仅依赖 open 回调，切标签易卡在 loading）
NiumaTtyd_NotifyWebOnPortReady(port) {
    global g_SCWV_WV2, g_FTB_WV2
    port := Integer(port)
    if (port <= 0)
        return
    eng := NiumaTtyd_EngineFromPort(port)
    wv2 := g_SCWV_WV2
    if !wv2
        wv2 := g_FTB_WV2
    if !wv2
        return
    try {
        NiumaTtyd_NotifyWeb(wv2, true, "", NiumaTtyd_BaseUrlForEngine(eng), "", eng)
    } catch {
    }
}

NiumaTtyd_StartProcessOnPort(port, shellCommand) {
    global g_NiumaTtydEnginePids, g_NiumaTtydEngineShell, g_NiumaTtydEngineStartTick, g_NiumaTtydHttpByPort
    ttydExe := NiumaTtyd_ExePath()
    p := Integer(port)
    if !FileExist(ttydExe) || p <= 0
        return false
    shell := Trim(String(shellCommand))
    if (shell = "")
        shell := "cmd.exe /k"
    if (StrLen(shell) > 1200)
        shell := "cmd.exe /k"
    workDir := NiumaTtyd_WorkDir()
    cmdLine := '"' . ttydExe . '" -W -i 127.0.0.1 -p ' . p . ' -t rendererType=dom -t fontSize=14 -w "' . workDir . '" ' . shell
    try {
        Run(cmdLine, workDir, "Hide", &pid)
        if (pid > 0) {
            eng := NiumaTtyd_EngineFromPort(p)
            if !IsObject(g_NiumaTtydHttpByPort)
                g_NiumaTtydHttpByPort := Map()
            NiumaTtyd_MapRemoveKey(g_NiumaTtydHttpByPort, p)
            g_NiumaTtydEnginePids[eng] := pid
            if !(g_NiumaTtydEngineStartTick is Map)
                g_NiumaTtydEngineStartTick := Map()
            g_NiumaTtydEngineStartTick[eng] := A_TickCount
            if !IsObject(g_NiumaTtydEngineShell)
                g_NiumaTtydEngineShell := Map()
            g_NiumaTtydEngineShell[eng] := shell
            if (p = Integer(NiumaTtyd_Port))
                NiumaTtyd_Pid := pid
            try FileAppend(
                (FormatTime(, "yyyy-MM-dd HH:mm:ss")) . " ttyd started port " . p . " pid " . pid . " cmd=" . shell . "`n",
                A_ScriptDir . "\NiumaTtyd_debug.log", "UTF-8")
            catch {
            }
        }
    } catch as e {
        try FileAppend(
            (FormatTime(, "yyyy-MM-dd HH:mm:ss")) . " ttyd Run port " . p . " failed: " . e.Message . "`n",
            A_ScriptDir . "\NiumaTtyd_debug.log", "UTF-8")
        catch {
        }
        return false
    }
    return true
}

NiumaTtyd_StartProcessForEngine(engine, forceRestart := false) {
    global g_NiumaTtydEngineShell, g_NiumaTtydHttpByPort, g_NiumaTtydEnginePids, g_NiumaTtydEngineStartTick
    eng := NiumaTtyd_NormalizeEngine(engine)
    port := NiumaTtyd_PortForEngine(eng)
    shell := NiumaTtyd_GetTtydShellForEngine(eng)
    if !IsObject(g_NiumaTtydEngineShell)
        g_NiumaTtydEngineShell := Map()
    if !IsObject(g_NiumaTtydHttpByPort)
        g_NiumaTtydHttpByPort := Map()
    prev := ""
    if g_NiumaTtydEngineShell.Has(eng)
        prev := g_NiumaTtydEngineShell[eng]
    httpOk := NiumaTtyd_IsHttpReadyOnPort(port, 120)
    if !forceRestart && IsObject(g_NiumaTtydEnginePids) && g_NiumaTtydEnginePids.Has(eng) {
        ep := Integer(g_NiumaTtydEnginePids[eng])
        try {
            ; 进程存活不等于可用：必须同时 HTTP 可达，避免复用僵死 ttyd
            if (ep > 0 && ProcessExist(ep) && httpOk)
                return true
        } catch {
        }
    }
    if !forceRestart && IsObject(g_NiumaTtydEngineStartTick) && g_NiumaTtydEngineStartTick.Has(eng) {
        ; 新进程预热窗口：4.5 秒内不重复拉起，避免雪崩重启导致全局卡顿
        if (!httpOk && (A_TickCount - Integer(g_NiumaTtydEngineStartTick[eng])) < 4500)
            return true
    }
    if (!forceRestart && httpOk && prev = shell)
        return true
    if (httpOk && (prev = "" || prev != shell || forceRestart))
        NiumaTtyd_StopEngine(eng)
    return NiumaTtyd_StartProcessOnPort(port, shell)
}

; 取消某引擎进行中的 ready 轮询 / inflight 锁，避免「restart failed: inflight」永久卡死
NiumaTtyd_CancelEngineReadyWork(engine) {
    global g_NiumaTtydReadyReqs, g_NiumaTtydEngineInflight, g_NiumaTtydEngineInflightSince
    global g_NiumaTtydEngineHealthyUntil, g_NiumaTtydHttpByPort, g_NiumaTtydPortProbeInflight
    eng := NiumaTtyd_NormalizeEngine(engine)
    port := NiumaTtyd_PortForEngine(eng)
    if (g_NiumaTtydEngineInflight is Map)
        g_NiumaTtydEngineInflight[eng] := false
    if (g_NiumaTtydEngineInflightSince is Map)
        NiumaTtyd_MapRemoveKey(g_NiumaTtydEngineInflightSince, eng)
    if (g_NiumaTtydReadyReqs is Map) {
        toDel := []
        for rid, req in g_NiumaTtydReadyReqs {
            if !(req is Map)
                continue
            if (req.Has("engine") && String(req["engine"]) = eng)
                toDel.Push(rid)
        }
        for _, rid in toDel
            g_NiumaTtydReadyReqs.Delete(rid)
    }
    if (g_NiumaTtydEngineHealthyUntil is Map)
        NiumaTtyd_MapRemoveKey(g_NiumaTtydEngineHealthyUntil, eng)
    if !IsObject(g_NiumaTtydHttpByPort)
        g_NiumaTtydHttpByPort := Map()
    NiumaTtyd_MapRemoveKey(g_NiumaTtydHttpByPort, port)
    if (g_NiumaTtydPortProbeInflight is Map)
        NiumaTtyd_MapRemoveKey(g_NiumaTtydPortProbeInflight, port)
}

NiumaTtyd_StopEngine(engine) {
    global g_NiumaTtydEnginePids, g_NiumaTtydHttpByPort, g_NiumaTtydEngineShell, g_NiumaTtydEngineStartTick
    eng := NiumaTtyd_NormalizeEngine(engine)
    NiumaTtyd_CancelEngineReadyWork(eng)
    port := NiumaTtyd_PortForEngine(eng)
    if !IsObject(g_NiumaTtydHttpByPort)
        g_NiumaTtydHttpByPort := Map()
    if !IsObject(g_NiumaTtydEngineShell)
        g_NiumaTtydEngineShell := Map()
    if !IsObject(g_NiumaTtydEnginePids)
        g_NiumaTtydEnginePids := Map()
    NiumaTtyd_MapRemoveKey(g_NiumaTtydHttpByPort, port)
    NiumaTtyd_MapRemoveKey(g_NiumaTtydEngineShell, eng)
    NiumaTtyd_MapRemoveKey(g_NiumaTtydEngineStartTick, eng)
    if g_NiumaTtydEnginePids.Has(eng) {
        pid := Integer(g_NiumaTtydEnginePids[eng])
        NiumaTtyd_MapRemoveKey(g_NiumaTtydEnginePids, eng)
        if (pid > 0) {
            try ProcessClose(pid)
            catch {
            }
        }
    }
}

; 微创：兼容旧同步 API，内部走 Async + 短 Sleep，绝无同步 WinHttp.Send
NiumaTtyd_EnsureReadyForEngine(engine, timeoutMs := 20000) {
    eng := NiumaTtyd_NormalizeEngine(engine)
    port := NiumaTtyd_PortForEngine(eng)
    if !FileExist(NiumaTtyd_ExePath())
        return false
    if NiumaTtyd_IsHttpReadyOnPort(port, 180)
        return true
    if !NiumaTtyd_StartProcessForEngine(eng, false)
        return false
    wait := Map("done", false, "ok", false)
    NiumaTtyd_EnsureReadyForEngineAsync(eng, (ok, _reason) => (wait["ok"] := !!ok, wait["done"] := true), timeoutMs)
    deadline := A_TickCount + Integer(timeoutMs)
    while (!wait["done"] && A_TickCount < deadline)
        Sleep(30)
    return wait["done"] && wait["ok"]
}

NiumaTtyd_EnsureReadyForEngineAsync(engine, cb, timeoutMs := 20000, reqId := "", force := false) {
    global g_NiumaTtydReadyReqSeq, g_NiumaTtydReadyReqs, g_NiumaTtydEngineHealthyUntil, g_NiumaTtydEngineInflight
    global g_NiumaTtydEngineInflightSince
    eng := NiumaTtyd_NormalizeEngine(engine)
    if !FileExist(NiumaTtyd_ExePath()) {
        cb.Call(false, "missing_ttyd_exe")
        return 0
    }
    now := A_TickCount
    if !(g_NiumaTtydEngineHealthyUntil is Map)
        g_NiumaTtydEngineHealthyUntil := Map()
    if !(g_NiumaTtydEngineInflight is Map)
        g_NiumaTtydEngineInflight := Map()
    if !(g_NiumaTtydEngineInflightSince is Map)
        g_NiumaTtydEngineInflightSince := Map()
    if force
        NiumaTtyd_CancelEngineReadyWork(eng)
    if (g_NiumaTtydEngineInflight.Has(eng) && g_NiumaTtydEngineInflight[eng]) {
        since := g_NiumaTtydEngineInflightSince.Has(eng) ? Integer(g_NiumaTtydEngineInflightSince[eng]) : 0
        if (force || since <= 0 || (now - since) > 12000) {
            NiumaTtyd_CancelEngineReadyWork(eng)
        } else {
            cb.Call(false, "inflight")
            return 0
        }
    }
    if !force && (g_NiumaTtydEngineHealthyUntil.Has(eng) && Integer(g_NiumaTtydEngineHealthyUntil[eng]) > now) {
        cb.Call(true, "")
        return 0
    }
    g_NiumaTtydEngineInflight[eng] := true
    g_NiumaTtydEngineInflightSince[eng] := now
    port := NiumaTtyd_PortForEngine(eng)
    if NiumaTtyd_IsHttpReadyOnPort(port, 600) {
        g_NiumaTtydEngineHealthyUntil[eng] := A_TickCount + 15000
        g_NiumaTtydEngineInflight[eng] := false
        NiumaTtyd_MapRemoveKey(g_NiumaTtydEngineInflightSince, eng)
        cb.Call(true, "")
        return 0
    }
    if !NiumaTtyd_StartProcessForEngine(eng, !!force) {
        g_NiumaTtydEngineInflight[eng] := false
        NiumaTtyd_MapRemoveKey(g_NiumaTtydEngineInflightSince, eng)
        cb.Call(false, "start_failed")
        return 0
    }
    g_NiumaTtydReadyReqSeq += 1
    rid := g_NiumaTtydReadyReqSeq
    g_NiumaTtydReadyReqs[rid] := Map(
        "cb", cb,
        "deadline", A_TickCount + Integer(timeoutMs),
        "engine", eng,
        "port", port,
        "reqId", Trim(String(reqId)),
        "force", !!force
    )
    SetTimer((*) => NiumaTtyd_EnsureEngineReadyStep(rid), -10)
    return rid
}

NiumaTtyd_EnsureEngineReadyStep(rid) {
    global g_NiumaTtydReadyReqs, g_NiumaTtydEngineInflight, g_NiumaTtydEngineHealthyUntil, g_NiumaTtydEngineInflightSince, g_NiumaTtydHttpByPort
    if !(g_NiumaTtydReadyReqs is Map) || !g_NiumaTtydReadyReqs.Has(rid)
        return
    req := g_NiumaTtydReadyReqs[rid]
    eng := req.Has("engine") ? String(req["engine"]) : ""
    if (A_TickCount >= Integer(req["deadline"])) {
        port := Integer(req["port"])
        if (eng != "") && NiumaTtyd_EngineProcessAlive(eng) && !req.Has("extended") {
            req["extended"] := true
            req["deadline"] := A_TickCount + 45000
            NiumaTtyd_MapRemoveKey(g_NiumaTtydHttpByPort, port)
            SetTimer((*) => NiumaTtyd_EnsureEngineReadyStep(rid), -220)
            return
        }
        cb := req["cb"]
        if (eng != "") {
            if g_NiumaTtydEngineInflight.Has(eng)
                g_NiumaTtydEngineInflight[eng] := false
            NiumaTtyd_MapRemoveKey(g_NiumaTtydEngineInflightSince, eng)
        }
        g_NiumaTtydReadyReqs.Delete(rid)
        cb.Call(false, "timeout")
        return
    }
    port := Integer(req["port"])
    if NiumaTtyd_IsHttpReadyOnPort(port, 600) {
        cb := req["cb"]
        if (eng != "") {
            g_NiumaTtydEngineHealthyUntil[eng] := A_TickCount + 15000
            if g_NiumaTtydEngineInflight.Has(eng)
                g_NiumaTtydEngineInflight[eng] := false
            NiumaTtyd_MapRemoveKey(g_NiumaTtydEngineInflightSince, eng)
        }
        g_NiumaTtydReadyReqs.Delete(rid)
        cb.Call(true, "")
        return
    }
    SetTimer((*) => NiumaTtyd_EnsureEngineReadyStep(rid), -220)
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
NiumaTtyd_DeferredOpenJob(reqId := "", engine := "codex_cli", wv2 := 0) {
    global g_FTB_WV2, g_SCWV_WV2, g_NiumaTtydOpenRetryOnce
    if !wv2
        wv2 := g_FTB_WV2
    if !wv2
        wv2 := g_SCWV_WV2
    rid := String(reqId)
    if !(g_NiumaTtydOpenRetryOnce is Map)
        g_NiumaTtydOpenRetryOnce := Map()
    eng := NiumaTtyd_NormalizeEngine(engine)
    if (rid != "")
        NiumaTtyd_MarkLatestReq("open", rid, eng)
    NiumaTtyd_EmitStatus(wv2, "starting", rid, "starting ttyd " . eng)
    if !FileExist(NiumaTtyd_ExePath()) {
        NiumaTtyd_NotifyWeb(wv2, false, "missing ttyd.exe", "", rid, eng)
        return
    }
    port := NiumaTtyd_PortForEngine(eng)
    if NiumaTtyd_IsHttpReadyOnPort(port, 800) {
        NiumaTtyd_NotifyWeb(wv2, true, "", NiumaTtyd_BaseUrlForEngine(eng), rid, eng)
        return
    }
    NiumaTtyd_EmitStatus(wv2, "probing", rid, "probing ttyd " . eng)
    NiumaTtyd_EnsureReadyForEngineAsync(eng, (ok, reason) => (
        (rid != "" && NiumaTtyd_ShouldDropReq("open", rid, eng))
            ? (NiumaTtyd_LogStaleDrop("open", rid), 0)
            : ((!ok && String(reason) = "inflight")
                ? (SetTimer((*) => NiumaTtyd_DeferredOpenJob(rid, eng, wv2), -220), 0)
                : (!ok && rid != "" && (String(reason) = "timeout" || String(reason) = "start_failed") && !g_NiumaTtydOpenRetryOnce.Has(rid)
                    ? (g_NiumaTtydOpenRetryOnce[rid] := true,
                        NiumaTtyd_EngineProcessAlive(eng)
                            ? NiumaTtyd_MapRemoveKey(g_NiumaTtydHttpByPort, NiumaTtyd_PortForEngine(eng))
                            : NiumaTtyd_StopEngine(eng),
                        SetTimer((*) => NiumaTtyd_DeferredOpenJob(rid, eng, wv2), -260), 0)
                    : (ok
                        ? (NiumaTtyd_MapRemoveKey(g_NiumaTtydOpenRetryOnce, rid), NiumaTtyd_NotifyWeb(wv2, true, "", NiumaTtyd_BaseUrlForEngine(eng), rid, eng))
                        : (NiumaTtyd_MapRemoveKey(g_NiumaTtydOpenRetryOnce, rid), NiumaTtyd_NotifyWeb(wv2, false, "ttyd 就绪超时: " . reason, "", rid, eng)))))
    ), 45000, rid)
}

NiumaTtyd_DeferredRestartJob(reqId := "", engine := "codex_cli", wv2 := 0) {
    global g_FTB_WV2, g_SCWV_WV2
    if !wv2
        wv2 := g_FTB_WV2
    if !wv2
        wv2 := g_SCWV_WV2
    rid := String(reqId)
    eng := NiumaTtyd_NormalizeEngine(engine)
    if (rid != "")
        NiumaTtyd_MarkLatestReq("restart", rid, eng)
    NiumaTtyd_EmitStatus(wv2, "starting", rid, "restarting ttyd " . eng)
    if !FileExist(NiumaTtyd_ExePath()) {
        NiumaTtyd_NotifyWeb(wv2, false, "missing ttyd.exe", "", rid, eng)
        return
    }
    NiumaTtyd_StopEngine(eng)
    SetTimer((*) => NiumaTtyd_EnsureReadyForEngineAsync(eng, (ok, reason) => (
        (rid != "" && NiumaTtyd_ShouldDropReq("restart", rid, eng))
            ? (NiumaTtyd_LogStaleDrop("restart", rid), 0)
            : ((!ok && String(reason) = "inflight")
                ? (SetTimer((*) => NiumaTtyd_DeferredRestartJob(rid, eng, wv2), -220), 0)
                : (ok
                    ? NiumaTtyd_NotifyWeb(wv2, true, "", NiumaTtyd_BaseUrlForEngine(eng), rid, eng)
                    : NiumaTtyd_NotifyWeb(wv2, false, "restart failed: " . reason, "", rid, eng)))
    ), 45000, rid, true), -500)
}

NiumaTtyd_DeferredExternalOpenJob(reqId := "", expectedBaseUrl := "", engine := "codex_cli", wv2 := 0) {
    global g_FTB_WV2, g_SCWV_WV2
    if !wv2
        wv2 := g_FTB_WV2
    if !wv2
        wv2 := g_SCWV_WV2
    rid := String(reqId)
    eng := NiumaTtyd_NormalizeEngine(engine)
    url := Trim(String(expectedBaseUrl))
    if (url = "")
        url := NiumaTtyd_BaseUrlForEngine(eng)
    NiumaTtyd_EnsureReadyForEngineAsync(eng, (ok, reason) => (
        ok
            ? (Run(url), NiumaTtyd_NotifyWeb(wv2, true, "", url, rid, eng))
            : NiumaTtyd_NotifyWeb(wv2, false, "open external failed: " . reason, "", rid, eng)
    ), 20000, rid)
}

/**
 * 主程序启动时热启动 ttyd，并多轮短重试，避免比 WebView/iframe 晚就绪。
 * @param {Object} * 定时器用
 */
AutoStartTtydForNiumaChat(*) {
    ; 改为按需懒激活：不再启动期预热拉起 ttyd
    return
}

NiumaTtyd_BootstrapRetryStep(*) {
    global NiumaTtyd__BootI
    NiumaTtyd__BootI++
    if (NiumaTtyd_IsHttpReadyOnPort(NiumaTtyd_PortForEngine("codex_cli"), 600) || NiumaTtyd__BootI > 20) {
        NiumaTtyd__BootI := 0
        return
    }
    NiumaTtyd_StartProcessForEngine("codex_cli")
    SetTimer(NiumaTtyd_BootstrapRetryStep, -500)
}
