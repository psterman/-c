; CliWorkbenchWebViewCore.ahk — CLI 终端工作台独立 Surface（ttyd 多引擎）
#Requires AutoHotkey v2.0

global g_CliWb_Gui := 0
global g_CliWb_Ctrl := 0
global g_CliWb_WV2 := 0
global g_CliWb_Ready := false
global g_CliWb_Visible := false
global g_CliWb_LastShown := 0
global g_CliWb_PendingKeyword := ""
global g_CliWb_PendingEngine := "codex_cli"
global g_CliWb_CliTerminalFocus := false
global g_CliWb_UserMinimized := false
global g_CliWb_DeactivateBlockUntil := 0
global g_CliWb_StatsTimerEng := ""
global g_CliWb_StatsReqId := ""

CliWb_GetGui() {
    global g_CliWb_Gui
    return g_CliWb_Gui
}

CliWb_IsVisible() {
    global g_CliWb_Visible
    return !!g_CliWb_Visible
}

CliWb_PostJson(payload) {
    global g_CliWb_WV2, g_CliWb_Ready
    if !g_CliWb_Ready || !IsObject(g_CliWb_WV2)
        return
    if (payload is Map)
        WebView_QueuePayload(g_CliWb_WV2, payload)
    else
        WebView_QueueJson(g_CliWb_WV2, payload)
}

_CliWb_GetWebView2Class() {
    try return WebView2
    catch {
        return 0
    }
}

_CliWb_BlockDeactivate(ms := 3000, reason := "") {
    global g_CliWb_DeactivateBlockUntil
    g_CliWb_DeactivateBlockUntil := A_TickCount + Max(200, Integer(ms))
}

CliWb_Init() {
    global g_CliWb_Gui
    if g_CliWb_Gui
        return
    try SurfaceManager_ObserveInit("cli_workbench", Map("entry", "CliWb_Init"))
    g_CliWb_Gui := Gui("+Resize +MinSize720x480 +MinimizeBox +MaximizeBox +Caption -DPIScale", "CLI 工作台")
    g_CliWb_Gui.BackColor := "0d1016"
    g_CliWb_Gui.MarginX := 0
    g_CliWb_Gui.MarginY := 0
    g_CliWb_Gui.OnEvent("Close", (*) => CliWb_Hide())
    g_CliWb_Gui.OnEvent("Size", _CliWb_OnGuiResize)
    g_CliWb_Gui.Show("w1100 h760 Hide")
    WebView2_CreateWithSharedEnvAsync(g_CliWb_Gui.Hwnd, _CliWb_OnWV2Created, "cli_workbench")
}

_CliWb_OnWV2Created(ctrl) {
    global g_CliWb_Ctrl, g_CliWb_WV2
    g_CliWb_Ctrl := ctrl
    g_CliWb_WV2 := ctrl.CoreWebView2
    try g_CliWb_Ctrl.DefaultBackgroundColor := 0xFF0D1016
    try g_CliWb_Ctrl.IsVisible := true
    _CliWb_ApplyBounds()
    s := g_CliWb_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.AreDevToolsEnabled := false
    if FuncExists("ApplyWebView2PerformanceSettings")
        ApplyWebView2PerformanceSettings(g_CliWb_WV2)
    if FuncExists("WebView2_RegisterHostBridge")
        WebView2_RegisterHostBridge(g_CliWb_WV2)
    g_CliWb_WV2.add_WebMessageReceived(_CliWb_OnWebMessage)
    try g_CliWb_WV2.add_NavigationCompleted(_CliWb_OnNavigationCompleted)
    try ApplyUnifiedWebViewAssets(g_CliWb_WV2)
    g_CliWb_WV2.Navigate(BuildAppLocalUrl("CliWorkbench.html"))
    global g_CliWb_Visible
    if g_CliWb_Visible {
        try WebView2_NotifyShown(g_CliWb_WV2)
        _CliWb_RefreshComposition()
        SetTimer(_CliWb_NudgeCliBootstrap, -120)
    }
}

_CliWb_NudgeCliBootstrap(*) {
    global g_CliWb_Visible, g_CliWb_WV2, g_CliWb_Ready
    if !g_CliWb_Visible || !g_CliWb_Ready || !IsObject(g_CliWb_WV2)
        return
    try WebView2_NotifyShown(g_CliWb_WV2)
    _CliWb_RefreshComposition()
    CliWb_PostJson(Map("type", "hostLayout"))
    CliWb_PostJson(Map("type", "hostPaintNudge", "reason", "bootstrap"))
    SetTimer(_CliWb_EnsureTtydForActiveEngine, -40)
}

_CliWb_ApplyBounds() {
    global g_CliWb_Gui, g_CliWb_Ctrl
    if !g_CliWb_Ctrl || !g_CliWb_Gui
        return
    WinGetClientPos(, , &cw, &ch, g_CliWb_Gui.Hwnd)
    WV2 := _CliWb_GetWebView2Class()
    if !WV2
        return
    rc := WV2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    g_CliWb_Ctrl.Bounds := rc
}

_CliWb_OnGuiResize(GuiObj, MinMax, Width, Height) {
    if (MinMax = -1)
        return
    _CliWb_ApplyBounds()
}

_CliWb_OnNavigationCompleted(sender, args) {
    global g_CliWb_Visible, g_CliWb_Ready
    try ok := args.IsSuccess
    catch {
        ok := true
    }
    if !ok
        return
    if !g_CliWb_Visible
        return
    _CliWb_RefreshComposition()
    if g_CliWb_Ready {
        CliWb_PushInit()
        SetTimer(() => CliWb_ApplyPendingSend(), -400)
    }
    SetTimer(_CliWb_NudgeCliBootstrap, -80)
}

_CliWb_RefreshComposition(*) {
    global g_CliWb_Ctrl, g_CliWb_Gui, g_CliWb_Visible
    if !g_CliWb_Visible || !g_CliWb_Ctrl || !g_CliWb_Gui
        return
    try {
        _CliWb_ApplyBounds()
        g_CliWb_Ctrl.NotifyParentWindowPositionChanged()
    } catch {
    }
}

_CliWb_GetThemeMode() {
    try {
        global ConfigFile
        if IsSet(ConfigFile) && ConfigFile != "" {
            raw := IniRead(ConfigFile, "Settings", "ThemeMode", "")
            if (Trim(String(raw)) = "")
                raw := IniRead(ConfigFile, "Appearance", "ThemeMode", "")
            tm := StrLower(Trim(String(raw)))
            if (tm = "light" || tm = "lite")
                return "light"
        }
    } catch {
    }
    return "dark"
}

_CliWb_EngineIconWebUrl(engineId) {
    eng := Trim(String(engineId))
    iconPath := ""
    if FuncExists("GetSearchEngineIcon") {
        try iconPath := GetSearchEngineIcon(eng)
        catch {
        }
    }
    if (iconPath = "" || !FileExist(iconPath))
        return ""
    if FuncExists("_SCWV_PathToWebAssetUrl") {
        try return _SCWV_PathToWebAssetUrl(iconPath)
        catch {
        }
    }
    if FuncExists("BuildAppLocalUrl") {
        normalized := StrReplace(iconPath, "\", "/")
        scriptRoot := StrReplace(A_ScriptDir, "\", "/") . "/"
        if (InStr(normalized, scriptRoot) = 1) {
            rel := SubStr(normalized, StrLen(scriptRoot) + 1)
            try return BuildAppLocalUrl(rel)
            catch {
            }
        }
    }
    return ""
}

_CliWb_BuildCliEnginePayload() {
    static labels := Map(
        "codex_cli", "Codex",
        "gemini_cli", "Gemini",
        "openclaw_cli", "OpenClaw",
        "qwen_cli", "通义千问",
        "ollama_cli", "Ollama",
        "claude_cli", "Claude",
        "deepseek_cli", "DeepSeek",
        "kimi_cli", "Kimi",
        "zhipu_cli", "智谱",
        "copilot_cli", "Copilot"
    )
    payload := []
    for eng in NiumaTtyd_CliEngineList() {
        if (eng = "studio_cli")
            continue
        payload.Push(Map(
            "name", labels.Has(eng) ? labels[eng] : eng,
            "value", eng,
            "iconUrl", _CliWb_EngineIconWebUrl(eng)
        ))
    }
    return payload
}

_CliWb_NormalizeEngine(engine) {
    eng := Trim(String(engine))
    if (eng = "")
        eng := "codex_cli"
    try eng := NiumaTtyd_NormalizeEngine(eng)
    catch {
        eng := "codex_cli"
    }
    return eng
}

_CliWb_BuildEngineRuntime(engine) {
    eng := _CliWb_NormalizeEngine(engine)
    wd := ""
    port := 7681
    shell := ""
    try wd := NiumaTtyd_GetWorkDirForEngine(eng)
    catch {
    }
    try port := NiumaTtyd_PortForEngine(eng)
    catch {
    }
    try shell := NiumaTtyd_GetShellForEngine(eng)
    catch {
    }
    return Map(
        "engine", eng,
        "port", port,
        "workDir", Trim(String(wd)),
        "shell", _CliWb_TruncateShell(shell, 80)
    )
}

_CliWb_TruncateShell(s, maxLen := 80) {
    t := Trim(String(s))
    if (t = "")
        return ""
    if (StrLen(t) <= maxLen)
        return t
    return SubStr(t, 1, maxLen - 1) . "…"
}

_CliWb_TryCmdOutput(cmd, workDir := "", timeoutMs := 2000) {
    cmd := Trim(String(cmd))
    if (cmd = "")
        return ""
    outFile := A_Temp . "\nmer_cli_cmd_" . A_TickCount . "_" . Random(1000, 9999) . ".txt"
    try FileDelete(outFile)
    catch {
    }
    q := Chr(34)
    runCmd := q . A_ComSpec . q . " /c " . cmd . " > " . q . outFile . q . " 2>nul"
    wd := Trim(String(workDir))
    try {
        if (wd != "" && DirExist(wd))
            RunWait(runCmd, wd, "Hide")
        else
            RunWait(runCmd, , "Hide")
    } catch {
        try FileDelete(outFile)
        catch {
        }
        return ""
    }
    out := ""
    try {
        if FileExist(outFile)
            out := Trim(FileRead(outFile, "UTF-8"))
    } catch {
    }
    try FileDelete(outFile)
    catch {
    }
    return out
}

_CliWb_ToShortPath(path) {
    if FuncExists("Nmer_WailsBridge_ToShortPath")
        return Nmer_WailsBridge_ToShortPath(path)
    p := String(path)
    if (p = "")
        return p
    buf := Buffer(32768, 0)
    len := DllCall("GetShortPathNameW", "wstr", p, "ptr", buf, "uint", 32767, "uint")
    return len ? StrGet(buf) : p
}

_CliWb_IsGitWorkTree(dir) {
    d := Trim(String(dir))
    if (d = "" || !DirExist(d))
        return false
    q := Chr(34)
    try {
        out := Trim(String(_CliWb_TryCmdOutput("git -C " . q . d . q . " rev-parse --is-inside-work-tree", "", 2000)))
        return (out = "true")
    } catch {
        return false
    }
}

; ttyd 工作目录可能因中文路径回退到 USERPROFILE，此处回退到脚本目录（含短路径）做 Git 探测
_CliWb_ResolveGitProbeDir(workDir) {
    wd := Trim(String(workDir))
    if _CliWb_IsGitWorkTree(wd)
        return wd
    scriptDir := A_ScriptDir
    if _CliWb_IsGitWorkTree(scriptDir)
        return scriptDir
    shortSd := _CliWb_ToShortPath(scriptDir)
    if (shortSd != "" && shortSd != scriptDir && _CliWb_IsGitWorkTree(shortSd))
        return shortSd
    return ""
}

_CliWb_ProbeGitBranch(dir) {
    d := Trim(String(dir))
    if (d = "" || !DirExist(d) || !_CliWb_IsGitWorkTree(d))
        return ""
    q := Chr(34)
    branch := ""
    try branch := Trim(String(_CliWb_TryCmdOutput("git -C " . q . d . q . " branch --show-current", "", 2000)))
    catch {
        branch := ""
    }
    if (branch != "")
        return branch
    hash := ""
    try hash := Trim(String(_CliWb_TryCmdOutput("git -C " . q . d . q . " rev-parse --short HEAD", "", 2000)))
    catch {
        hash := ""
    }
    if (hash != "")
        return "detached@" . hash
    return ""
}

_CliWb_ProbeGitStatus(dir) {
    result := Map("gitStatus", "", "modifiedCount", 0, "untrackedCount", 0)
    d := Trim(String(dir))
    if (d = "" || !DirExist(d) || !_CliWb_IsGitWorkTree(d))
        return result
    q := Chr(34)
    out := ""
    try out := _CliWb_TryCmdOutput("git -C " . q . d . q . " status --porcelain", "", 2500)
    catch {
        return result
    }
    out := Trim(String(out))
    if (out = "") {
        result["gitStatus"] := "clean"
        return result
    }
    modified := 0
    untracked := 0
    for line in StrSplit(out, "`n", "`r") {
        line := Trim(String(line))
        if (line = "")
            continue
        if (SubStr(line, 1, 2) = "??")
            untracked++
        else
            modified++
    }
    result["modifiedCount"] := modified
    result["untrackedCount"] := untracked
    if (modified = 0 && untracked = 0)
        result["gitStatus"] := "clean"
    else if (modified > 0 && untracked = 0)
        result["gitStatus"] := "modified"
    else if (modified = 0 && untracked > 0)
        result["gitStatus"] := "untracked"
    else
        result["gitStatus"] := "mixed"
    return result
}

_CliWb_ProbeGitRecentCommit(dir) {
    result := Map("commitHash", "", "commitSubject", "", "commitAt", "", "recentCommit", "")
    d := Trim(String(dir))
    if (d = "" || !DirExist(d) || !_CliWb_IsGitWorkTree(d))
        return result
    q := Chr(34)
    out := ""
    try out := _CliWb_TryCmdOutput("git -C " . q . d . q . " log -1 --pretty=format:%h%x1f%s%x1f%ct", "", 2000)
    catch {
        return result
    }
    out := Trim(String(out))
    if (out = "")
        return result
    sep := Chr(0x1f)
    parts := StrSplit(out, sep)
    if (parts.Length >= 3) {
        result["commitHash"] := Trim(String(parts[1]))
        result["commitSubject"] := Trim(String(parts[2]))
        result["commitAt"] := Trim(String(parts[3]))
        result["recentCommit"] := result["commitHash"] . " " . result["commitSubject"]
    } else {
        result["recentCommit"] := out
    }
    return result
}

_CliWb_ApplyGitStatusToRuntime(runtime, statusMap) {
    if !(runtime is Map) || !(statusMap is Map)
        return
    if statusMap.Has("gitStatus") && String(statusMap["gitStatus"]) != ""
        runtime["gitStatus"] := String(statusMap["gitStatus"])
    if statusMap.Has("modifiedCount")
        runtime["modifiedCount"] := Integer(statusMap["modifiedCount"])
    if statusMap.Has("untrackedCount")
        runtime["untrackedCount"] := Integer(statusMap["untrackedCount"])
}

_CliWb_ApplyCommitToRuntime(runtime, commitMap) {
    if !(runtime is Map) || !(commitMap is Map)
        return
    for key in ["commitHash", "commitSubject", "commitAt", "recentCommit"] {
        if commitMap.Has(key) && String(commitMap[key]) != ""
            runtime[key] := String(commitMap[key])
    }
}

_CliWb_ProbeCliToolVersion(engine) {
    eng := _CliWb_NormalizeEngine(engine)
    cmd := ""
    switch eng {
        case "codex_cli":
            cmd := "codex --version"
        case "openclaw_cli":
            cmd := "openclaw --version"
        default:
            return ""
    }
    if (cmd = "")
        return ""
    try return _CliWb_TryCmdOutput(cmd, "", 2000)
    catch {
        return ""
    }
}

_CliWb_ProbeNodeVersion() {
    try return _CliWb_TryCmdOutput("node -v", "", 1500)
    catch {
        return ""
    }
}

_CliWb_ProbePythonVersion() {
    try return _CliWb_TryCmdOutput("python --version", "", 1500)
    catch {
        return ""
    }
}

_CliWb_ProbeGitVersion() {
    try return _CliWb_TryCmdOutput("git --version", "", 1500)
    catch {
        return ""
    }
}

_CliWb_ProbeEnginePid(engine) {
    eng := _CliWb_NormalizeEngine(engine)
    pid := 0
    try {
        global g_NiumaTtydEnginePids
        if IsObject(g_NiumaTtydEnginePids) && g_NiumaTtydEnginePids.Has(eng)
            pid := Integer(g_NiumaTtydEnginePids[eng])
    } catch {
    }
    if (pid > 0 && ProcessExist(pid))
        return pid
    try {
        port := NiumaTtyd_PortForEngine(eng)
        pid := NiumaTtyd_GetListeningPid(port)
    } catch {
    }
    if (pid > 0 && ProcessExist(pid))
        return pid
    return 0
}

_CliWb_ProbeProcessStatsByPid(pid) {
    result := Map("cpuPercent", "", "memoryMb", "")
    pid := Integer(pid)
    if (pid <= 0 || !ProcessExist(pid))
        return result
    try {
        q := "SELECT WorkingSetSize FROM Win32_Process WHERE ProcessId=" . pid
        for p in ComObjGet("winmgmts:").ExecQuery(q) {
            ws := Integer(p.WorkingSetSize)
            if (ws > 0)
                result["memoryMb"] := Round(ws / 1048576, 1)
            break
        }
    } catch {
    }
    cpu := ""
    try {
        q := "SELECT PercentProcessorTime FROM Win32_PerfFormattedData_PerfProc_Process WHERE IDProcess=" . pid
        loop 2 {
            for p in ComObjGet("winmgmts:").ExecQuery(q) {
                v := Integer(p.PercentProcessorTime)
                if (A_Index = 2)
                    cpu := v
                break
            }
            if (A_Index = 1)
                Sleep(300)
        }
        if (cpu != "" && Integer(cpu) >= 0)
            result["cpuPercent"] := Integer(cpu)
    } catch {
    }
    return result
}

_CliWb_StopStatsPoll() {
    global g_CliWb_StatsTimerEng, g_CliWb_StatsReqId
    try SetTimer(_CliWb_StatsPollTick, 0)
    catch {
    }
    g_CliWb_StatsTimerEng := ""
    g_CliWb_StatsReqId := ""
}

_CliWb_StartStatsPoll(engine, reqId := "") {
    global g_CliWb_Visible, g_CliWb_StatsTimerEng, g_CliWb_StatsReqId
    if !g_CliWb_Visible
        return
    eng := _CliWb_NormalizeEngine(engine)
    _CliWb_StopStatsPoll()
    g_CliWb_StatsTimerEng := eng
    rid := Trim(String(reqId))
    if (rid = "")
        rid := "stats_" . eng
    g_CliWb_StatsReqId := rid
    SetTimer(_CliWb_StatsPollTick, 30000)
    SetTimer(() => _CliWb_DeferredStatsOnly(eng, g_CliWb_StatsReqId), -80)
}

_CliWb_StatsPollTick(*) {
    global g_CliWb_Visible, g_CliWb_StatsTimerEng, g_CliWb_StatsReqId, g_CliWb_PendingEngine
    if !g_CliWb_Visible {
        _CliWb_StopStatsPoll()
        return
    }
    eng := String(g_CliWb_StatsTimerEng)
    if (eng = "" || _CliWb_NormalizeEngine(g_CliWb_PendingEngine) != _CliWb_NormalizeEngine(eng)) {
        _CliWb_StopStatsPoll()
        return
    }
    _CliWb_DeferredStatsOnly(eng, g_CliWb_StatsReqId)
}

_CliWb_DeferredStatsOnly(engine, reqId) {
    eng := _CliWb_NormalizeEngine(engine)
    global g_CliWb_Visible, g_CliWb_StatsTimerEng
    if !g_CliWb_Visible || String(g_CliWb_StatsTimerEng) != eng
        return
    stats := _CliWb_ProbeProcessStatsByPid(_CliWb_ProbeEnginePid(eng))
    runtime := Map("engine", eng, "statsAt", A_TickCount)
    runtime["cpuPercent"] := (stats is Map && stats.Has("cpuPercent") && stats["cpuPercent"] != "") ? stats["cpuPercent"] : ""
    runtime["memoryMb"] := (stats is Map && stats.Has("memoryMb") && stats["memoryMb"] != "") ? stats["memoryMb"] : ""
    CliWb_PostJson(Map(
        "type", "cli_engine_runtime",
        "engine", eng,
        "reqId", String(reqId),
        "ok", true,
        "engineRuntime", runtime,
        "partial", "stats"
    ))
}

_CliWb_ProbeEngineResourceStats(engine) {
    return _CliWb_ProbeProcessStatsByPid(_CliWb_ProbeEnginePid(engine))
}

_CliWb_ListDirShallow(dir, maxItems := 10) {
    entries := []
    d := Trim(String(dir))
    maxItems := Max(1, Min(12, Integer(maxItems)))
    if (d = "" || !DirExist(d))
        return entries
    n := 0
    try {
        Loop Files, d . "\*", "DF" {
            if (n >= maxItems)
                break
            name := A_LoopFileName
            if (name = "." || name = "..")
                continue
            isDir := false
            try isDir := !!(A_LoopFileAttrib ~= "D")
            catch {
            }
            entries.Push(Map("name", name, "isDir", isDir))
            n++
        }
    } catch {
    }
    return entries
}

_CliWb_DeferredRuntimeExtras(engine, reqId, workDir) {
    eng := _CliWb_NormalizeEngine(engine)
    wd := Trim(String(workDir))
    runtime := _CliWb_BuildEngineRuntime(eng)
    branch := ""
    nodeVersion := ""
    pythonVersion := ""
    gitVersion := ""
    cliToolVersion := ""
    dirEntries := []
    gitDir := _CliWb_ResolveGitProbeDir(wd)
    if (gitDir != "") {
        runtime["gitRepo"] := true
        if (gitDir != wd)
            runtime["gitProbeDir"] := gitDir
        try branch := _CliWb_ProbeGitBranch(gitDir)
        catch {
        }
        try _CliWb_ApplyGitStatusToRuntime(runtime, _CliWb_ProbeGitStatus(gitDir))
        catch {
        }
        try _CliWb_ApplyCommitToRuntime(runtime, _CliWb_ProbeGitRecentCommit(gitDir))
        catch {
        }
    } else {
        runtime["gitRepo"] := false
    }
    try nodeVersion := _CliWb_ProbeNodeVersion()
    catch {
    }
    if (nodeVersion = "") {
        try pythonVersion := _CliWb_ProbePythonVersion()
        catch {
        }
    }
    try gitVersion := _CliWb_ProbeGitVersion()
    catch {
    }
    try cliToolVersion := _CliWb_ProbeCliToolVersion(eng)
    catch {
    }
    try dirEntries := _CliWb_ListDirShallow(wd, 10)
    catch {
    }
    if (branch != "")
        runtime["branch"] := branch
    if (nodeVersion != "")
        runtime["nodeVersion"] := nodeVersion
    if (pythonVersion != "")
        runtime["pythonVersion"] := pythonVersion
    if (gitVersion != "")
        runtime["gitVersion"] := gitVersion
    if (cliToolVersion != "")
        runtime["cliToolVersion"] := cliToolVersion
    if (dirEntries.Length > 0)
        runtime["dirEntries"] := dirEntries
    CliWb_PostJson(Map(
        "type", "cli_engine_runtime",
        "engine", eng,
        "reqId", String(reqId),
        "ok", true,
        "engineRuntime", runtime,
        "partial", "extras"
    ))
    _CliWb_StartStatsPoll(eng, "stats_" . eng)
}

_CliWb_ScheduleRuntimeExtras(engine, reqId, workDir) {
    if (Trim(String(workDir)) = "")
        return
    SetTimer(() => _CliWb_DeferredRuntimeExtras(engine, reqId, workDir), -10)
}

_CliWb_TryGitBranch(dir) {
    return _CliWb_ProbeGitBranch(dir)
}

_CliWb_PostEngineRuntime(engine, reqId := "", partial := "") {
    eng := _CliWb_NormalizeEngine(engine)
    runtime := _CliWb_BuildEngineRuntime(eng)
    payload := Map(
        "type", "cli_engine_runtime",
        "engine", eng,
        "reqId", String(reqId),
        "ok", true,
        "engineRuntime", runtime
    )
    if (partial != "")
        payload["partial"] := String(partial)
    CliWb_PostJson(payload)
}

_CliWb_HandleCliEngineChanged(msg) {
    eng := msg.Has("engine") ? Trim(String(msg["engine"])) : "codex_cli"
    reqId := msg.Has("reqId") ? String(msg["reqId"]) : ""
    eng := _CliWb_NormalizeEngine(eng)
    _CliWb_StopStatsPoll()
    runtime := _CliWb_BuildEngineRuntime(eng)
    wd := runtime.Has("workDir") ? String(runtime["workDir"]) : ""
    CliWb_PostJson(Map(
        "type", "cli_engine_runtime",
        "engine", eng,
        "reqId", reqId,
        "ok", true,
        "engineRuntime", runtime
    ))
    _CliWb_ScheduleRuntimeExtras(eng, reqId, wd)
    return true
}

_CliWb_EnsureTtydForActiveEngine(*) {
    global g_CliWb_WV2, g_CliWb_PendingEngine, g_CliWb_Visible
    if !g_CliWb_Visible || !IsObject(g_CliWb_WV2)
        return
    eng := _CliWb_NormalizeEngine(g_CliWb_PendingEngine)
    SetTimer(NiumaTtyd_DeferredOpenJob.Bind("", eng, g_CliWb_WV2), -10)
}

CliWb_PushInit() {
    engines := _CliWb_BuildCliEnginePayload()
    global g_CliWb_PendingKeyword, g_CliWb_PendingEngine
    eng := _CliWb_NormalizeEngine(g_CliWb_PendingEngine)
    g_CliWb_PendingEngine := eng
    runtime := _CliWb_BuildEngineRuntime(eng)
    payload := Map(
        "type", "init",
        "uiMode", "cli",
        "currentCategoryKey", "cli",
        "themeMode", _CliWb_GetThemeMode(),
        "engines", engines,
        "activeCliEngine", eng,
        "keyword", Trim(String(g_CliWb_PendingKeyword)),
        "engineRuntime", runtime
    )
    CliWb_PostJson(payload)
    wd := runtime.Has("workDir") ? String(runtime["workDir"]) : ""
    _CliWb_ScheduleRuntimeExtras(eng, "init", wd)
    SetTimer(_CliWb_EnsureTtydForActiveEngine, -280)
}

_CliWb_OnWebMessage(sender, args) {
    jsonStr := args.WebMessageAsJson
    try msg := Jxon_Load(jsonStr)
    catch {
        return
    }
    if (msg is String) {
        try msg := Jxon_Load(msg)
        catch {
            return
        }
    }
    if !(msg is Map)
        return
    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ = "ready") {
        global g_CliWb_Ready
        g_CliWb_Ready := true
        CliWb_PushInit()
        SetTimer(_CliWb_NudgeCliBootstrap, -80)
        SetTimer(_CliWb_NudgeCliBootstrap, -350)
        SetTimer(_CliWb_NudgeCliBootstrap, -900)
        SetTimer(() => CliWb_ApplyPendingSend(), -500)
        return
    }
    if (typ = "close") {
        CliWb_Hide()
        return
    }
    if (typ = "vk_compose") {
        act := msg.Has("action") ? StrLower(Trim(String(msg["action"]))) : ""
        if (act = "send" || act = "run") {
            kw := msg.Has("keyword") ? String(msg["keyword"]) : ""
            eng := msg.Has("engine") ? Trim(String(msg["engine"])) : ""
            ScCli_SendToCLI(kw, eng)
        }
        return
    }
    if (typ = "cli_engine_changed") {
        _CliWb_HandleCliEngineChanged(msg)
        return
    }
    if FuncExists("SearchCenterCliBridge_HandleMessage") {
        global g_CliWb_WV2
        if SearchCenterCliBridge_HandleMessage(msg, "cli_workbench", g_CliWb_WV2)
            return
    }
}

CliWb_ApplyPendingSend() {
    global g_CliWb_PendingKeyword, g_CliWb_PendingEngine
    kw := Trim(String(g_CliWb_PendingKeyword))
    if (kw = "")
        return
    ScCli_SendToCLI(kw, g_CliWb_PendingEngine)
    g_CliWb_PendingKeyword := ""
}

CliWb_Show(meta := 0) {
    if FuncExists("SurfaceIntent_RouteExternalOpen") && SurfaceIntent_RouteExternalOpen("cli_workbench", meta)
        return true
    global g_CliWb_Visible, g_CliWb_Ready, g_CliWb_PendingKeyword, g_CliWb_PendingEngine, g_CliWb_UserMinimized
    m := (meta is Map) ? meta : Map()
    if m.Has("keyword")
        g_CliWb_PendingKeyword := String(m["keyword"])
    if m.Has("engine")
        g_CliWb_PendingEngine := Trim(String(m["engine"]))
    else if m.Has("activeCliEngine")
        g_CliWb_PendingEngine := Trim(String(m["activeCliEngine"]))
    reqId := 0
    try {
        reqId := SurfaceManager_Request("cli_workbench", "open", "CliWb_Show", m)
        SurfaceManager_BeforeOpen("cli_workbench", "CliWb_Show", Map("requestId", reqId))
        SurfaceManager_RegisterSurface("cli_workbench")
    } catch {
    }
    if FuncExists("Nmer_Telemetry_MarkSurfaceOpen") {
        try Nmer_Telemetry_MarkSurfaceOpen("cli_workbench", Map("source", "CliWb_Show"))
        catch {
        }
    }
    if !g_CliWb_Gui
        CliWb_Init()
    if !g_CliWb_Gui
        return false
    g_CliWb_UserMinimized := false
    ScreenW := SysGet(0)
    ScreenH := SysGet(1)
    w := 1100
    h := 760
    x := (ScreenW - w) // 2
    y := (ScreenH - h) // 2
    try g_CliWb_Gui.Show("x" . x . " y" . y . " w" . w . " h" . h)
    catch {
        try g_CliWb_Gui.Show("Maximize")
        catch {
        }
    }
    g_CliWb_Visible := true
    g_CliWb_LastShown := A_TickCount
    try WebView2_NotifyShown(g_CliWb_WV2)
    _CliWb_RefreshComposition()
    SetTimer(_CliWb_RefreshComposition, -120)
    if g_CliWb_Ready {
        CliWb_PushInit()
        SetTimer(_CliWb_NudgeCliBootstrap, -150)
        SetTimer(_CliWb_NudgeCliBootstrap, -500)
    }
    try SurfaceManager_ObserveShow("cli_workbench", Map("entry", "CliWb_Show", "requestId", reqId))
    try LegacyGuard_RequestFocus("CliWorkbench", g_CliWb_Gui.Hwnd, 40, "cli_workbench_show")
    return true
}

CliWb_Hide(*) {
    global g_CliWb_Visible, g_CliWb_Gui, g_CliWb_CliTerminalFocus
    if !g_CliWb_Visible && !g_CliWb_Gui
        return false
    if FuncExists("SurfaceIntent_RouteExternalClose") && SurfaceIntent_RouteExternalClose("cli_workbench")
        return true
    _CliWb_StopStatsPoll()
    g_CliWb_Visible := false
    g_CliWb_CliTerminalFocus := false
    if g_CliWb_Gui {
        try g_CliWb_Gui.Hide()
        catch {
        }
    }
    try WebView2_NotifyHidden(g_CliWb_WV2)
    if FuncExists("Nmer_Telemetry_MarkSurfaceClose") {
        try Nmer_Telemetry_MarkSurfaceClose("cli_workbench", Map("source", "CliWb_Hide"))
        catch {
        }
    }
    try SurfaceManager_ObserveHide("cli_workbench", Map("entry", "CliWb_Hide"))
    return true
}

CliWb_Dispose(reason := "") {
    CliWb_Hide()
    global g_CliWb_Gui, g_CliWb_Ctrl, g_CliWb_WV2, g_CliWb_Ready
    if IsObject(g_CliWb_Ctrl) {
        try g_CliWb_Ctrl.Close()
        catch {
        }
    }
    if IsObject(g_CliWb_Gui) {
        try g_CliWb_Gui.Destroy()
        catch {
        }
    }
    g_CliWb_Gui := 0
    g_CliWb_Ctrl := 0
    g_CliWb_WV2 := 0
    g_CliWb_Ready := false
    try SurfaceManager_ObserveClose("cli_workbench", Map("entry", "CliWb_Dispose", "reason", reason))
}

CliWorkbenchRouter_Open(meta := 0) {
    return CliWb_Show(meta)
}

CliWorkbenchRouter_Hide(*) {
    return CliWb_Hide()
}

CliWorkbenchRouter_Dispose(reason := "") {
    CliWb_Dispose(reason)
}
