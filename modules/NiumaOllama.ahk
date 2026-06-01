#Requires AutoHotkey v2.0
; 本机 Ollama 服务检测与启动（供 Niuma Chat / 设置页）

NiumaOllama_DefaultPort() {
    return 11434
}

NiumaOllama_IsLoopbackUrl(url) {
    return RegExMatch(String(url), "i)^https?://(127\.0\.0\.1|localhost)(:\d+)?/")
}

NiumaOllama_FindExe() {
  if FuncExists("GetPreferredCLIExecutable") {
        try {
            ex := GetPreferredCLIExecutable("ollama_cli")
            if (ex != "" && FileExist(ex))
                return ex
        } catch {
        }
    }
    pf := EnvGet("ProgramFiles")
    localPf := EnvGet("LocalAppData")
    appData := EnvGet("APPDATA")
    for p in [
        localPf . "\Programs\Ollama\Ollama.exe",
        localPf . "\Programs\Ollama\ollama.exe",
        pf . "\Ollama\Ollama.exe",
        pf . "\Ollama\ollama.exe",
        appData . "\Programs\Ollama\Ollama.exe",
        appData . "\Programs\Ollama\ollama.exe"
    ] {
        if FileExist(p)
            return p
    }
    return ""
}

NiumaOllama_PortOpen(port := 0) {
    if !port
        port := NiumaOllama_DefaultPort()
    url := "http://127.0.0.1:" . port . "/api/tags"
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        try whr.SetProxy(2)
        whr.Open("GET", url, false)
        whr.SetTimeouts(1500, 2000, 2000, 5000)
        whr.Send()
        return Integer(whr.Status) = 200
    } catch {
        return false
    }
}

NiumaOllama_StartService(maxWaitMs := 50000) {
    if NiumaOllama_PortOpen()
        return Map("ok", true, "message", "Ollama 已在运行")

    exe := NiumaOllama_FindExe()
    if (exe = "")
        return Map("ok", false, "message", "未找到 Ollama。请从 ollama.com 安装后重试。")

    launched := false
    SplitPath(exe, , &dir)
    try EnvSet("OPENBLAS_NUM_THREADS", "1")
    try EnvSet("OMP_NUM_THREADS", "1")
    try EnvSet("OLLAMA_NUM_PARALLEL", "1")
    try {
        Run('"' . exe . '"', dir, , &pid)
        launched := true
    } catch as e1 {
        try {
            Run('"' . exe . '" serve', dir, "Hide", &pid2)
            launched := true
        } catch as e2 {
            return Map("ok", false, "message", "启动失败：" . e2.Message)
        }
    }
    if !launched
        return Map("ok", false, "message", "无法启动 Ollama 进程")

    deadline := A_TickCount + maxWaitMs
    while (A_TickCount < deadline) {
        if NiumaOllama_PortOpen()
            return Map("ok", true, "message", "Ollama 已启动")
        Sleep(400)
    }
    return Map(
        "ok", false,
        "message", "已尝试启动 Ollama，但 " . NiumaOllama_DefaultPort() . " 端口仍未就绪。请从开始菜单打开「Ollama」等待托盘图标出现后再点对话区「同步」。"
    )
}
