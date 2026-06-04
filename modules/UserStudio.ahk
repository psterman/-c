; UserStudio.ahk — 智能定制：大模型 API、软件路径、总览与还原（local/user_studio.json）
; 跨模块符号由主脚本 #Include；Func 包装避免单独打开本文件时静态分析误报「未赋值」。

_US_JxonLoad(s) => Func("Jxon_Load").Call(s)
_US_JxonDump(o) => Func("Jxon_Dump").Call(o)

global g_UserStudio := Map()
global g_UserStudioLoaded := false

UserStudio_LocalDir() {
    return A_ScriptDir . "\local"
}

UserStudio_MainConfigFile() {
    return UserStudio_LocalDir() . "\CursorShortcut.ini"
}

UserStudio_NormalizeWinPath(path) {
    path := Trim(String(path))
    if (path = "")
        return ""
    if FuncExists("NormalizeWindowsPath")
        try return Func("NormalizeWindowsPath").Call(path)
    return path
}

UserStudio_ConfigDir() {
    return A_ScriptDir . "\config"
}

UserStudio_Path() {
    return UserStudio_LocalDir() . "\user_studio.json"
}

UserStudio_DefaultsPath() {
    return UserStudio_ConfigDir() . "\user_studio.defaults.json"
}

UserStudio_BackupPath() {
    return UserStudio_LocalDir() . "\user_studio.backup.json"
}

UserStudio_NiumaLlmSyncPath() {
    return UserStudio_LocalDir() . "\niuma_chat_llm.json"
}

UserStudio_NiumaBriefPath() {
    return A_ScriptDir . "\md\docs\niuma-project-brief.md"
}

UserStudio_ReadTextFileMax(path, maxChars := 12000) {
    path := Trim(String(path))
    if (path = "" || !FileExist(path))
        return ""
    try {
        raw := FileRead(path, "UTF-8")
        if (StrLen(raw) > maxChars)
            return SubStr(raw, 1, maxChars) . "`n…（已截断）"
        return raw
    } catch {
        return ""
    }
}

UserStudio_ResolveInstallRoot(doc) {
    if !(doc is Map)
        doc := UserStudio_Get()
    opt := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
    root := Trim(String(opt.Get("niumaInstallRoot", "")))
    if (root != "") {
        try root := UserStudio_NormalizeWinPath(root)
        catch {
        }
        if DirExist(root)
            return root
    }
    return A_ScriptDir
}

UserStudio_BuildNiumaRuntimeBlock(doc) {
    if !(doc is Map)
        doc := UserStudio_Get()
    root := UserStudio_ResolveInstallRoot(doc)
    paths := doc.Has("paths") && doc["paths"] is Map ? doc["paths"] : Map()
    llm := doc.Has("llm") && doc["llm"] is Map ? doc["llm"] : Map()
    lines := []
    lines.Push("## 本机即时信息（自动识别，每次打开 Niuma Chat 更新）")
    lines.Push("- 软件安装根目录：" . root)
    lines.Push("- 主脚本目录（A_ScriptDir）：" . A_ScriptDir)
    lines.Push("- 用户定制配置：" . UserStudio_Path())
    lines.Push("- 当前默认 LLM：" . Trim(String(llm.Get("provider", ""))) . " / " . Trim(String(llm.Get("model", ""))))
    cp := Trim(String(paths.Get("cursor", "")))
    if (cp != "")
        lines.Push("- Cursor：" . cp)
    ah := Trim(String(paths.Get("autohotkey", "")))
    if (ah != "")
        lines.Push("- AutoHotkey：" . ah)
    py := Trim(String(paths.Get("python", "")))
    if (py != "")
        lines.Push("- Python：" . py)
    note := Trim(String(paths.Get("notes", "")))
    if (note != "")
        lines.Push("- 备注路径：" . note)
    lines.Push("")
    lines.Push("用户问「这个软件能干什么」时，指上述牛马 nmer 项目本身，不要回答泛化的 AHK 教程。")
    return Trim(lines.Join("`n"), "`n")
}

UserStudio_BuildDefaultNiumaSystemPrompt() {
    doc := UserStudio_Get()
    brief := UserStudio_ReadTextFileMax(UserStudio_NiumaBriefPath(), 9000)
    if (brief = "") {
        agents := UserStudio_ReadTextFileMax(A_ScriptDir . "\md\AGENTS.md", 3500)
        intro := UserStudio_ReadTextFileMax(A_ScriptDir . "\md\软件介绍.md", 4500)
        brief := "你是牛马 nmer（Windows 桌面效率工具）的维护与定制助手。用户通过 Niuma Chat 修改本仓库代码与配置。`n`n"
        if (agents != "")
            brief .= "--- AGENTS.md ---`n" . agents . "`n`n"
        if (intro != "")
            brief .= "--- 软件介绍 ---`n" . intro
    }
    rt := UserStudio_BuildNiumaRuntimeBlock(doc)
    if (rt != "")
        return Trim(brief . "`n`n" . rt, "`n")
    return Trim(brief)
}

UserStudio_NormalizeNiumaOptions(optIn) {
    if !(optIn is Map)
        optIn := Map()
    if !optIn.Has("niumaAutoInjectContext")
        optIn["niumaAutoInjectContext"] := true
    else
        optIn["niumaAutoInjectContext"] := !!optIn["niumaAutoInjectContext"]
    if !optIn.Has("niumaSystemPrompt")
        optIn["niumaSystemPrompt"] := ""
    else
        optIn["niumaSystemPrompt"] := Trim(String(optIn["niumaSystemPrompt"]))
    if !optIn.Has("niumaInstallRoot")
        optIn["niumaInstallRoot"] := ""
    else
        optIn["niumaInstallRoot"] := Trim(String(optIn["niumaInstallRoot"]))
    if !(optIn.Has("llmApiKeys") && optIn["llmApiKeys"] is Map)
        optIn["llmApiKeys"] := Map()
    if !(optIn.Has("llmBaseUrls") && optIn["llmBaseUrls"] is Map)
        optIn["llmBaseUrls"] := Map()
    if !(optIn.Has("llmManualBaseUrl") && optIn["llmManualBaseUrl"] is Map)
        optIn["llmManualBaseUrl"] := Map()
    if !(optIn.Has("llmModels") && optIn["llmModels"] is Map)
        optIn["llmModels"] := Map()
    if optIn.Has("llmCardProviders") && !(optIn["llmCardProviders"] is Array)
        optIn["llmCardProviders"] := []
    return optIn
}

UserStudio_BaseUrlMatchesProvider(prov, url) {
    prov := UserStudio_NormalizeLlmProvider(prov)
    url := Trim(String(url))
    if (url = "" || prov = "custom")
        return true
    low := StrLower(url)
    switch prov {
        case "kimi":
            return RegExMatch(low, "moonshot\.(cn|ai)")
        case "deepseek":
            return InStr(low, "deepseek")
        case "openai":
            return InStr(low, "api.openai.com") || InStr(low, "openai.azure.com")
                || (InStr(low, "azure.com") && InStr(low, "openai"))
                || InStr(low, "cognitiveservices.azure.com")
        case "minimax":
            return InStr(low, "minimax")
        case "gemini":
            return InStr(low, "generativelanguage.googleapis.com")
        case "claude":
            return InStr(low, "anthropic")
        case "qwen":
            return InStr(low, "dashscope")
        case "glm", "zhipu":
            return InStr(low, "bigmodel")
        case "siliconflow":
            return InStr(low, "siliconflow")
        case "ollama":
            return InStr(low, "11434") || InStr(low, "ollama")
        case "openclaw", "hermes":
            return true
        default:
            return true
    }
}

UserStudio_MergeLlmBaseUrls(optIn, llm) {
    if !(optIn is Map)
        optIn := Map()
    if !(llm is Map)
        return optIn
    urls := Map()
    if optIn.Has("llmBaseUrls") && optIn["llmBaseUrls"] is Map {
        for k, v in optIn["llmBaseUrls"] {
            pk := UserStudio_NormalizeLlmProvider(k)
            vu := Trim(String(v))
            if (vu != "" && UserStudio_BaseUrlMatchesProvider(pk, vu))
                urls[pk] := vu
        }
    }
    prov := UserStudio_NormalizeLlmProvider(llm.Get("provider", "openai"))
    bu := Trim(String(llm.Get("baseUrl", "")))
    if (bu != "" && UserStudio_BaseUrlMatchesProvider(prov, bu))
        urls[prov] := bu
    else if urls.Has(prov)
        llm["baseUrl"] := urls[prov]
    optIn["llmBaseUrls"] := urls
    return optIn
}

UserStudio_MergeLlmApiKeys(optIn, llm) {
    if !(optIn is Map)
        optIn := Map()
    if !(llm is Map)
        return optIn
    keys := Map()
    if optIn.Has("llmApiKeys") && optIn["llmApiKeys"] is Map {
        for k, v in optIn["llmApiKeys"] {
            pk := UserStudio_NormalizeLlmProvider(k)
            vk := UserStudio_NormalizeApiKey(v)
            if (vk != "")
                keys[pk] := vk
        }
    }
    prov := UserStudio_NormalizeLlmProvider(llm.Get("provider", "openai"))
    ak := UserStudio_NormalizeApiKey(llm.Get("apiKey", ""))
    if (ak != "")
        keys[prov] := ak
    else if keys.Has(prov)
        llm["apiKey"] := keys[prov]
    optIn["llmApiKeys"] := keys
    return optIn
}

UserStudio_LoadNiumaSystemPrompt(*) {
    doc := UserStudio_Get()
    opt := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
    opt := UserStudio_NormalizeNiumaOptions(opt)
    custom := Trim(String(opt.Get("niumaSystemPrompt", "")))
    if (custom != "")
        return custom
    return UserStudio_BuildDefaultNiumaSystemPrompt()
}

UserStudio_GetNiumaContext() {
    doc := UserStudio_Get()
    opt := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
    opt := UserStudio_NormalizeNiumaOptions(opt)
    root := UserStudio_ResolveInstallRoot(doc)
    return Map(
        "autoInject", opt["niumaAutoInjectContext"],
        "systemPrompt", UserStudio_LoadNiumaSystemPrompt(),
        "briefPath", UserStudio_NiumaBriefPath(),
        "scriptDir", A_ScriptDir,
        "installRoot", root
    )
}

UserStudio_EnsureConfigDir() {
    if !DirExist(UserStudio_LocalDir())
        try DirCreate(UserStudio_LocalDir())
    dir := UserStudio_ConfigDir()
    if !DirExist(dir)
        DirCreate(dir)
}

UserStudio_DefaultDocument() {
    defPath := UserStudio_DefaultsPath()
    if FileExist(defPath) {
        try {
            raw := FileRead(defPath, "UTF-8")
            parsed := _US_JxonLoad(raw)
            if (parsed is Map)
                return UserStudio_NormalizeDoc(parsed)
        } catch {
        }
    }
    return UserStudio_NormalizeDoc(Map(
        "version", 1,
        "llm", Map("provider", "openai", "apiKey", "", "baseUrl", "https://api.openai.com/v1", "model", "gpt-4o-mini"),
        "paths", Map("cursor", "", "autohotkey", "", "everything", "", "python", "", "notes", ""),
        "ttyd", Map("shell", "cmd.exe", "workDir", "", "port", 7691),
        "options", Map("niumaAutoInjectContext", true, "niumaSystemPrompt", "", "niumaInstallRoot", ""),
        "updatedAt", ""
    ))
}

UserStudio_NormalizeLlmProvider(prov) {
    prov := Trim(String(prov))
    if (prov = "anthropic")
        return "claude"
    if (prov = "codex")
        return "openai"
    return prov
}

; 各服务商官方默认接口（baseUrl 留空时由系统自动补全）
UserStudio_LlmPresetFor(prov) {
    prov := UserStudio_NormalizeLlmProvider(prov)
    switch prov {
        case "minimax":
            return Map("baseUrl", "https://api.minimaxi.com/anthropic", "model", "MiniMax-M2.7")
        case "gemini":
            return Map("baseUrl", "https://generativelanguage.googleapis.com/v1beta", "model", "gemini-2.5-flash")
        case "deepseek":
            return Map("baseUrl", "https://api.deepseek.com/v1", "model", "deepseek-chat")
        case "kimi":
            return Map("baseUrl", "https://api.moonshot.cn/v1", "model", "kimi-k2.6")
        case "claude":
            return Map("baseUrl", "https://api.anthropic.com", "model", "claude-3-5-sonnet-latest")
        case "qwen":
            return Map("baseUrl", "https://dashscope.aliyuncs.com/compatible-mode/v1", "model", "qwen-plus")
        case "glm", "zhipu":
            return Map("baseUrl", "https://open.bigmodel.cn/api/paas/v4", "model", "glm-4-plus")
        case "siliconflow":
            return Map("baseUrl", "https://api.siliconflow.cn/v1", "model", "Qwen/Qwen2.5-7B-Instruct")
        case "ollama":
            return Map("baseUrl", "http://127.0.0.1:11434/v1", "model", "nemotron-3-super:cloud")
        case "openclaw":
            return Map("baseUrl", "http://127.0.0.1:18789", "model", "gateway")
        case "hermes":
            return Map("baseUrl", "http://127.0.0.1:8642/v1", "model", "hermes-agent")
        case "custom":
            return Map("baseUrl", "", "model", "")
        default:
            return Map("baseUrl", "https://api.openai.com/v1", "model", "gpt-4o-mini")
    }
}

UserStudio_CoerceTokenFromSecretInput(value, defaults := "") {
    if (value is Map) {
        try {
            src := Trim(String(value.Get("source", "")))
            id := Trim(String(value.Get("id", "")))
            if (src = "env" && id != "")
                return Trim(String(EnvGet(id)))
        } catch {
        }
        return ""
    }
    s := Trim(String(value))
    if (s = "")
        return ""
    if RegExMatch(s, '^\$\{([A-Z][A-Z0-9_]{0,127})\}$', &m)
        return Trim(String(EnvGet(m[1])))
    if RegExMatch(s, '^\$([A-Z][A-Z0-9_]{0,127})$', &m2)
        return Trim(String(EnvGet(m2[1])))
    if RegExMatch(s, 'i)^secretref-env:([A-Z][A-Z0-9_]{0,127})$', &m3)
        return Trim(String(EnvGet(m3[1])))
    if RegExMatch(s, 'i)^__env__:([A-Z][A-Z0-9_]{0,127})$', &m4)
        return Trim(String(EnvGet(m4[1])))
    if !(s ~= '^\{')
        return s
    return ""
}

UserStudio_ExtractOpenClawGatewayToken(cfg) {
    if !(cfg is Map)
        return ""
    defaults := ""
    try {
        if cfg.Has("secrets") && cfg["secrets"] is Map && cfg["secrets"].Has("defaults")
            defaults := cfg["secrets"]["defaults"]
    } catch {
    }
    try {
        if cfg.Has("gateway") {
            gw := cfg["gateway"]
            if (gw is Map) {
                if gw.Has("auth") {
                    auth := gw["auth"]
                    if (auth is Map) {
                        if auth.Has("token") {
                            tok := UserStudio_CoerceTokenFromSecretInput(auth["token"], defaults)
                            if (tok != "")
                                return tok
                        }
                    }
                }
                if gw.Has("remote") {
                    rem := gw["remote"]
                    if (rem is Map && rem.Has("token")) {
                        tokR := UserStudio_CoerceTokenFromSecretInput(rem["token"], defaults)
                        if (tokR != "")
                            return tokR
                    }
                }
                if gw.Has("token") {
                    tok2 := UserStudio_CoerceTokenFromSecretInput(gw["token"], defaults)
                    if (tok2 != "")
                        return tok2
                }
            }
        }
    } catch {
    }
    return ""
}

UserStudio_FindOpenClawCliExe() {
    candidates := []
    try {
        appData := Trim(String(EnvGet("APPDATA")))
        if (appData != "")
            candidates.Push(appData . "\npm\openclaw.cmd")
    } catch {
    }
    if (A_AppData != "")
        candidates.Push(A_AppData . "\npm\openclaw.cmd")
    candidates.Push("C:\Program Files\nodejs\openclaw.cmd")
    for _, p in candidates {
        if FileExist(p)
            return p
    }
    out := A_Temp . "\nmer_oc_where_" . A_TickCount . ".txt"
    q := Chr(34)
    try {
        RunWait(q . A_ComSpec . q . " /c where openclaw > " . q . out . q . " 2>nul", , "Hide")
        if FileExist(out) {
            raw := FileRead(out, "UTF-8")
            try FileDelete(out)
            for _, line in StrSplit(raw, "`n", "`r") {
                line := Trim(line)
                if (line != "" && FileExist(line))
                    return line
            }
        }
    } catch {
        try FileDelete(out)
    }
    return ""
}

UserStudio_OpenClawGatewayCliOk() {
    exe := UserStudio_FindOpenClawCliExe()
    if (exe = "")
        return false
    out := A_Temp . "\nmer_openclaw_gw_status.txt"
    try FileDelete(out)
    inner := '"' . exe . '" gateway status > "' . out . '" 2>&1'
    try {
        RunWait(A_ComSpec . ' /c "' . inner . '"', , "Hide")
    } catch {
        return false
    }
    if !FileExist(out)
        return false
    raw := ""
    try raw := FileRead(out, "UTF-8")
    catch {
        return false
    }
    try FileDelete(out)
    if InStr(raw, "Connectivity probe: ok")
        return true
    if InStr(raw, "Runtime: running") && InStr(raw, "Listening: 127.0.0.1")
        return true
    return false
}

UserStudio_TcpPortOpen(host, port, timeoutMs := 2500) {
    if FuncExists("LlmApiPing_TcpPortOpen")
        return Func("LlmApiPing_TcpPortOpen").Call(host, port, timeoutMs)
    host := Trim(String(host))
    if (host = "localhost")
        host := "127.0.0.1"
    port := Integer(port)
    if (host = "" || port < 1 || port > 65535)
        return false
    if !RegExMatch(host, "^\d{1,3}(\.\d{1,3}){3}$")
        return false
    static wsaReady := false
    if !wsaReady {
        wsaData := Buffer(400, 0)
        if DllCall("ws2_32\WSAStartup", "UShort", 0x0202, "Ptr", wsaData, "Int")
            return false
        wsaReady := true
    }
    ip := DllCall("ws2_32\inet_addr", "AStr", host, "UInt")
    if (ip = 0xFFFFFFFF)
        return false
    sock := DllCall("ws2_32\socket", "Int", 2, "Int", 1, "Int", 6, "UPtr")
    if (sock = -1 || sock = 0xFFFFFFFFFFFFFFFF)
        return false
    try {
        sa := Buffer(16, 0)
        NumPut("UShort", 2, sa, 0)
        NumPut("UShort", DllCall("ws2_32\htons", "UShort", port, "UShort"), sa, 2)
        NumPut("UInt", ip, sa, 4)
        nb := 1
        if (DllCall("ws2_32\ioctlsocket", "UPtr", sock, "UInt", 0x8004667E, "UInt*", &nb, "Int") = -1)
            return false
        if (DllCall("ws2_32\connect", "UPtr", sock, "Ptr", sa, "Int", 16, "Int") = 0)
            return true
        if (DllCall("ws2_32\WSAGetLastError", "Int") != 10035)
            return false
        t := Max(500, Integer(timeoutMs))
        writeSet := Buffer(132, 0)
        NumPut("UInt", 1, writeSet, 0)
        NumPut("UPtr", sock, writeSet, 4)
        tv := Buffer(8, 0)
        NumPut("UInt", t // 1000, tv, 0)
        NumPut("UInt", Mod(t, 1000) * 1000, tv, 4)
        if (DllCall("ws2_32\select", "Int", 0, "Ptr", 0, "Ptr", writeSet, "Ptr", 0, "Ptr", tv, "Int") <= 0)
            return false
        optErr := 0
        optLen := 4
        if (DllCall("ws2_32\getsockopt", "UPtr", sock, "Int", 0xFFFF, "Int", 0x1007, "Int*", &optErr, "Int*", &optLen, "Int") = -1)
            return false
        return optErr = 0
    } catch {
        return false
    } finally {
        try DllCall("ws2_32\closesocket", "UPtr", sock)
        catch {
        }
    }
}

UserStudio_ProbeOpenClawGateway(base, token, timeoutMs := 12000) {
    if FuncExists("LlmApiPing_TestOpenClaw")
        return Func("LlmApiPing_TestOpenClaw").Call(base, token, timeoutMs)
    token := UserStudio_NormalizeApiKey(token)
    if (token = "")
        return Map("ok", false, "error", "缺少 Gateway Token", "elapsedMs", 0)
    host := "127.0.0.1"
    port := 18789
    base := Trim(String(base))
    if RegExMatch(base, "i)^[a-z]+://([^/:]+)(?::(\d+))?", &m) {
        if (m[1] != "")
            host := m[1]
        if (m[2] != "")
            port := Integer(m[2])
    } else if RegExMatch(base, ":(\d+)", &mp)
        port := Integer(mp[1])
    t0 := A_TickCount
    if UserStudio_OpenClawGatewayCliOk()
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0)
    tcpMs := Min(Max(800, Integer(timeoutMs)), 3000)
    if UserStudio_TcpPortOpen(host, port, tcpMs)
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0)
    return Map(
        "ok", false,
        "error", "无法连接本机 OpenClaw Gateway（" . host . ":" . port . "）。请执行 openclaw gateway restart。",
        "elapsedMs", A_TickCount - t0
    )
}

UserStudio_ParseOpenClawCliStdout(raw) {
    raw := Trim(String(raw))
    if (raw = "")
        return ""
    try {
        head := SubStr(raw, 1, 1)
        if (head = Chr(34) || head = "{" || head = "[") {
            parsed := _US_JxonLoad(raw)
            if (parsed != "")
                return UserStudio_NormalizeApiKey(String(parsed))
        }
    } catch {
    }
    dq := Chr(34)
    if RegExMatch(raw, "^" . dq . "(.+)" . dq . "$", &m)
        return UserStudio_NormalizeApiKey(m[1])
    last := ""
    for _, line in StrSplit(raw, "`n", "`r") {
        line := Trim(line)
        if (line = "")
            continue
        if RegExMatch(line, "i)^Config warnings:")
            continue
        if RegExMatch(line, "^OpenClaw \d")
            continue
        if RegExMatch(line, "i)^Usage:")
            continue
        if (StrLen(line) >= 8 && StrLen(line) <= 256 && RegExMatch(line, "^[\w\-\./\+]+$"))
            last := line
    }
    if (last != "")
        return UserStudio_NormalizeApiKey(last)
    return UserStudio_NormalizeApiKey(raw)
}

UserStudio_FetchOpenClawTokenViaCli(timeoutMs := 20000) {
    exe := UserStudio_FindOpenClawCliExe()
    if (exe = "")
        return Map("token", "", "source", "")
    outFile := A_Temp . "\nmer_oc_gwtoken_" . A_TickCount . ".txt"
    q := Chr(34)
    cmd := q . A_ComSpec . q . " /c " . q . exe . q . " config get gateway.auth.token --json > " . q . outFile . q . " 2>nul"
    pid := 0
    try {
        Run(cmd, , "Hide", &pid)
    } catch as eRun {
        try UserStudio_LogOpenClawProbe("cli_run_fail err=" . eRun.Message)
        catch {
        }
        return Map("token", "", "source", "")
    }
    if !pid
        return Map("token", "", "source", "")
    deadline := A_TickCount + Max(1000, Integer(timeoutMs))
    while ProcessExist(pid) {
        if (A_TickCount > deadline) {
            try ProcessClose(pid)
            try UserStudio_LogOpenClawProbe("cli_get_timeout ms=" . timeoutMs)
            catch {
            }
            try FileDelete(outFile)
            return Map("token", "", "source", "")
        }
        Sleep 40
    }
    try {
        if !FileExist(outFile)
            return Map("token", "", "source", "")
        raw := Trim(FileRead(outFile, "UTF-8"))
        try FileDelete(outFile)
        tok := UserStudio_ParseOpenClawCliStdout(raw)
        if (tok != "")
            return Map("token", tok, "source", "openclaw config get gateway.auth.token --json")
    } catch as eCli {
        try FileDelete(outFile)
        try UserStudio_LogOpenClawProbe("cli_get_fail err=" . eCli.Message)
        catch {
        }
    }
    return Map("token", "", "source", "")
}

UserStudio_ReadOpenClawDeviceOperatorToken() {
    home := UserStudio_ResolveOpenClawUserHome()
    if (home = "")
        return Map("token", "", "source", "")
    path := home . "\identity\device-auth.json"
    if !FileExist(path)
        return Map("token", "", "source", "")
    try {
        doc := _US_JxonLoad(FileRead(path, "UTF-8"))
        if !(doc is Map) || !doc.Has("tokens") || !(doc["tokens"] is Map)
            return Map("token", "", "source", "")
        op := doc["tokens"].Has("operator") ? doc["tokens"]["operator"] : ""
        if !(op is Map)
            return Map("token", "", "source", "")
        tok := UserStudio_NormalizeApiKey(op.Get("token", ""))
        if (tok = "")
            return Map("token", "", "source", "")
        return Map("token", tok, "source", path . " (operator)")
    } catch {
        return Map("token", "", "source", "")
    }
}

; openclaw.json 体积大时 _US_JxonLoad 会溢出返回空 Map，用片段正则 / InStr 读取 gateway 段
UserStudio_StripUtf8Bom(raw) {
    raw := String(raw)
    if (raw = "")
        return raw
    if (Ord(SubStr(raw, 1, 1)) = 0xFEFF)
        return SubStr(raw, 2)
    return raw
}

UserStudio_ResolveOpenClawUserHome() {
    dirs := []
    try {
        up := Trim(String(EnvGet("USERPROFILE")))
        if (up != "")
            dirs.Push(up)
    } catch {
    }
    try {
        localApp := Trim(String(EnvGet("LOCALAPPDATA")))
        if (localApp != "")
            dirs.Push(localApp)
    } catch {
    }
    if (A_AppData != "") {
        homeFromRoaming := RegExReplace(A_AppData, "\\AppData\\Roaming$", "")
        if (homeFromRoaming != "" && homeFromRoaming != A_AppData)
            dirs.Push(homeFromRoaming)
        dirs.Push(A_AppData)
    }
    try {
        hd := Trim(String(EnvGet("HOMEDRIVE")))
        hp := Trim(String(EnvGet("HOMEPATH")))
        hpHome := hd . hp
        if (hpHome != "")
            dirs.Push(hpHome)
    } catch {
    }
    for _, dir in dirs {
        dir := Trim(String(dir))
        if (dir = "")
            continue
        dir := RTrim(dir, "\")
        if FileExist(dir . "\.openclaw\openclaw.json")
            return dir
    }
    for _, dir in dirs {
        dir := Trim(String(dir))
        if (dir != "")
            return RTrim(dir, "\")
    }
    return ""
}

UserStudio_OpenClawConfigFileCandidates() {
    home := UserStudio_ResolveOpenClawUserHome()
    names := ["openclaw.json", "openclaw.json.last-good", "openclaw.json.bak"]
    paths := []
    try {
        up := Trim(String(EnvGet("USERPROFILE")))
        if (up != "")
            paths.Push(up . "\.openclaw\openclaw.json")
    } catch {
    }
    if (A_AppData != "") {
        hm := Trim(RegExReplace(A_AppData, "\\AppData\\Roaming$", ""))
        if (hm != "") {
            for _, name in names
                paths.Push(hm . "\.openclaw\" . name)
        }
    }
    try {
        up := Trim(String(EnvGet("USERPROFILE")))
        if (up != "") {
            for _, name in names
                paths.Push(up . "\.openclaw\" . name)
        }
    } catch {
    }
    if (home != "") {
        for _, name in names
            paths.Push(home . "\.openclaw\" . name)
    }
    try {
        stateDir := Trim(String(EnvGet("OPENCLAW_STATE_DIR")))
        if (stateDir != "") {
            stateDir := RTrim(stateDir, "\")
            for _, name in names
                paths.Push(stateDir . "\" . name)
        }
    } catch {
    }
    paths.Push(A_AppData . "\openclaw\openclaw.json")
    paths.Push(A_AppData . "\clawhub\openclaw.json")
    uniq := Map()
    out := []
    for _, p in paths {
        p := Trim(String(p))
        if (p = "" || uniq.Has(p))
            continue
        uniq[p] := true
        out.Push(p)
    }
    return out
}

UserStudio_ReadJsonStringValueAfterKey(haystack, key, startPos := 1) {
    if (haystack = "" || key = "")
        return ""
    ; 必须匹配 "key": ，避免命中 "mode": "token" 里的值 token
    needle := Chr(34) . key . Chr(34) . ":"
    pos := startPos
    while (pos := InStr(haystack, needle, false, pos)) {
        tail := SubStr(haystack, pos + StrLen(needle))
        tail := LTrim(tail, " `t`r`n")
        if (SubStr(tail, 1, 1) = Chr(34)) {
            end := InStr(tail, Chr(34), false, 2)
            if (end > 1)
                return SubStr(tail, 2, end - 1)
        } else if RegExMatch(tail, 'i)^\$\{([A-Z][A-Z0-9_]+)\}$', &mEnv) {
            return Trim(String(EnvGet(mEnv[1])))
        }
        pos += StrLen(needle)
    }
    return ""
}

UserStudio_ReadOpenClawAuthTokenLiteral(raw) {
    raw := UserStudio_StripUtf8Bom(Trim(String(raw)))
    if (raw = "")
        return ""
    gwAt := InStr(raw, '"gateway"', false)
    if (gwAt < 1)
        return ""
    chunk := SubStr(raw, gwAt, 3000)
    authAt := InStr(chunk, '"auth"', false)
    if (authAt < 1)
        return ""
    sub := SubStr(chunk, authAt, 600)
    for _, needle in ['"token": "', '"token":"'] {
        p := InStr(sub, needle, false)
        if (p < 1)
            continue
        rest := SubStr(sub, p + StrLen(needle))
        end := InStr(rest, Chr(34), false)
        if (end > 1)
            return SubStr(rest, 1, end - 1)
    }
    return ""
}

UserStudio_ExtractOpenClawGatewayFromRaw(raw) {
    out := Map("token", "", "host", "127.0.0.1", "port", 18789)
    raw := UserStudio_StripUtf8Bom(Trim(String(raw)))
    if (raw = "")
        return out
    tok := UserStudio_ReadOpenClawAuthTokenLiteral(raw)
    if (tok != "")
        out["token"] := UserStudio_CoerceTokenFromSecretInput(tok)
    gwAt := InStr(raw, '"gateway"', false)
    if (gwAt < 1)
        return out
    chunk := SubStr(raw, gwAt, 8000)
    if (out["token"] = "") {
        authAt := InStr(chunk, '"auth"', false)
        if (authAt > 0) {
            authChunk := SubStr(chunk, authAt, 800)
            tok := UserStudio_ReadJsonStringValueAfterKey(authChunk, "token")
            if (tok != "")
                out["token"] := UserStudio_CoerceTokenFromSecretInput(tok)
        }
    }
    if (out["token"] = "")
        out["token"] := UserStudio_CoerceTokenFromSecretInput(UserStudio_ReadJsonStringValueAfterKey(chunk, "token"))
    portStr := UserStudio_ReadJsonStringValueAfterKey(chunk, "port")
    if (portStr != "" && RegExMatch(portStr, "^\d+$"))
        out["port"] := Integer(portStr)
    else if RegExMatch(chunk, 'i)"port"\s*:\s*(\d+)', &mp)
        out["port"] := Integer(mp[1])
    bindVal := UserStudio_ReadJsonStringValueAfterKey(chunk, "bind")
    if (bindVal = "loopback" || bindVal = "localhost")
        out["host"] := "127.0.0.1"
    else if RegExMatch(chunk, 'i)"bind"\s*:\s*"([^"]+)"', &mb) {
        b := Trim(mb[1])
        if (b = "loopback" || b = "localhost")
            out["host"] := "127.0.0.1"
    }
    return out
}

UserStudio_LogOpenClawProbe(lines*) {
    try {
        path := A_ScriptDir . "\Cache\debug\openclaw_probe.log"
        DirCreate(A_ScriptDir . "\Cache\debug")
        buf := ""
        for _, ln in lines
            buf .= FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " " . String(ln) . "`n"
        FileAppend(buf, path, "UTF-8")
    } catch {
    }
}

UserStudio_ReadOpenClawGatewayToken() {
    tried := []
    for _, path in UserStudio_OpenClawConfigFileCandidates() {
        tried.Push(path)
        try {
            if !FileExist(path)
                continue
            raw := FileRead(path, "UTF-8")
            if (Trim(raw) = "")
                continue
            tok := ""
            meta := Map("host", "127.0.0.1", "port", 18789)
            if (StrLen(raw) <= 524288) {
                try {
                    cfg := _US_JxonLoad(raw)
                    tok := UserStudio_ExtractOpenClawGatewayToken(cfg)
                } catch as eJxon {
                    try UserStudio_LogOpenClawProbe("jxon_fail path=" . path . " err=" . eJxon.Message)
                    catch {
                    }
                }
            }
            if (tok = "") {
                meta := UserStudio_ExtractOpenClawGatewayFromRaw(raw)
                tok := Trim(String(meta.Get("token", "")))
            } else {
                meta := UserStudio_ExtractOpenClawGatewayFromRaw(raw)
            }
            if (tok != "") {
                tok := UserStudio_NormalizeApiKey(tok)
                return Map(
                    "token", tok,
                    "source", path,
                    "host", meta.Get("host", "127.0.0.1"),
                    "port", meta.Get("port", 18789)
                )
            }
        } catch as ePath {
            try UserStudio_LogOpenClawProbe("read_fail path=" . path . " err=" . ePath.Message)
            catch {
            }
        }
    }
    cli := UserStudio_FetchOpenClawTokenViaCli(20000)
    cliTok := Trim(String(cli.Get("token", "")))
    if (cliTok != "") {
        return Map(
            "token", cliTok,
            "source", String(cli.Get("source", "")),
            "host", "127.0.0.1",
            "port", 18789,
            "tried", tried
        )
    }
    dev := UserStudio_ReadOpenClawDeviceOperatorToken()
    devTok := Trim(String(dev.Get("token", "")))
    if (devTok != "") {
        return Map(
            "token", devTok,
            "source", String(dev.Get("source", "")),
            "host", "127.0.0.1",
            "port", 18789,
            "tried", tried
        )
    }
    try UserStudio_LogOpenClawProbe(
        "no_token USERPROFILE=" . EnvGet("USERPROFILE"),
        "home=" . UserStudio_ResolveOpenClawUserHome(),
        "tried=" . tried.Length,
        "cli=" . UserStudio_FindOpenClawCliExe()
    )
    catch {
    }
    return Map("token", "", "source", "", "host", "127.0.0.1", "port", 18789, "tried", tried)
}

UserStudio_ProbeOpenClawGatewayToken() {
    host := "127.0.0.1"
    port := 18789
    try {
        envTok := Trim(String(EnvGet("OPENCLAW_GATEWAY_TOKEN")))
        if (envTok != "")
            return Map("token", envTok, "source", "env:OPENCLAW_GATEWAY_TOKEN", "host", host, "port", port)
    } catch {
    }
    try {
        envPwd := Trim(String(EnvGet("OPENCLAW_GATEWAY_PASSWORD")))
        if (envPwd != "")
            return Map("token", envPwd, "source", "env:OPENCLAW_GATEWAY_PASSWORD", "host", host, "port", port)
    } catch {
    }
    info := UserStudio_ReadOpenClawGatewayToken()
    tok := Trim(String(info.Get("token", "")))
    if (tok != "") {
        host := Trim(String(info.Get("host", host)))
        port := Integer(info.Get("port", port))
        return info
    }
    if FuncExists("FloatingToolbar_ReadOpenClawGatewayToken") {
        try {
            fb := Func("FloatingToolbar_ReadOpenClawGatewayToken").Call()
            if (fb is Map) {
                tok := Trim(String(fb.Get("token", "")))
                if (tok != "")
                    return Map(
                        "token", tok,
                        "source", String(fb.Get("source", "")),
                        "host", Trim(String(fb.Get("host", host))),
                        "port", Integer(fb.Get("port", port))
                    )
            }
        } catch {
        }
    }
    return info
}

UserStudio_HermesAddDataDir(dirs, seen, path) {
    path := Trim(String(path))
    if (path = "")
        return
    try path := RTrim(path, "\/")
    catch {
    }
    if seen.Has(path)
        return
    if (DirExist(path) || FileExist(path . "\config.yaml") || FileExist(path . "\.env")) {
        seen[path] := true
        dirs.Push(path)
    }
}

UserStudio_ListHermesDataDirs() {
    dirs := []
    seen := Map()
    la := UserStudio_LocalAppDataDir()
    if (la != "")
        UserStudio_HermesAddDataDir(dirs, seen, la . "\hermes")
    try {
        h := Trim(String(EnvGet("HERMES_HOME")))
        if (h != "")
            UserStudio_HermesAddDataDir(dirs, seen, h)
    } catch {
    }
    up := ""
    try up := Trim(String(EnvGet("USERPROFILE")))
    catch {
    }
    if (up = "")
        up := A_UserName ? "C:\Users\" . A_UserName : A_AppData
    UserStudio_HermesAddDataDir(dirs, seen, up . "\.hermes")
    if (up != "")
        UserStudio_HermesAddDataDir(dirs, seen, up . "\AppData\Local\hermes")
    return dirs
}

UserStudio_LocalAppDataDir() {
    static cached := ""
    if (cached != "")
        return cached
    try cached := Trim(EnvGet("LOCALAPPDATA"))
    catch {
        cached := ""
    }
    if (cached = "" && A_AppData != "") {
        try {
            p := RegExReplace(A_AppData, "\\Roaming$", "\\Local", , 1)
            if (p != A_AppData && DirExist(p))
                cached := p
        } catch {
        }
    }
    if (cached = "") {
        up := ""
        try up := Trim(EnvGet("USERPROFILE"))
        catch {
        }
        if (up = "")
            up := A_UserName ? "C:\Users\" . A_UserName : ""
        if (up != "") {
            p2 := up . "\AppData\Local"
            if DirExist(p2)
                cached := p2
        }
    }
    return cached
}

UserStudio_ResolveHermesHome() {
    dirs := UserStudio_ListHermesDataDirs()
    if (dirs.Length > 0)
        return dirs[1]
    try {
        h := Trim(String(EnvGet("HERMES_HOME")))
        if (h != "")
            return h
    } catch {
    }
    up := ""
    try up := Trim(String(EnvGet("USERPROFILE")))
    catch {
    }
    if (up = "")
        up := A_UserName ? "C:\Users\" . A_UserName : A_AppData
    return up . "\.hermes"
}

UserStudio_GetHermesEnvPath() {
    la := UserStudio_LocalAppDataDir()
    if (la != "") {
        p := la . "\hermes\.env"
        if FileExist(p)
            return p
    }
    return UserStudio_GetHermesPrimaryDataDir() . "\.env"
}

UserStudio_GetHermesPrimaryDataDir() {
    la := UserStudio_LocalAppDataDir()
    if (la != "" && DirExist(la . "\hermes"))
        return la . "\hermes"
    dirs := UserStudio_ListHermesDataDirs()
    if (dirs.Length > 0)
        return dirs[1]
    return UserStudio_ResolveHermesHome()
}

/** 供 NiumaChat / 设置页 Hermes 探测：返回已查找的 .env 路径与 LOCALAPPDATA（写入日志，不含密钥）。 */
UserStudio_CollectHermesProbeMeta() {
    tried := []
    seen := Map()
    for _, dir in UserStudio_ListHermesDataDirs() {
        p := dir . "\.env"
        if (p != "" && !seen.Has(p)) {
            seen[p] := true
            tried.Push(p)
        }
    }
    up := ""
    try up := Trim(String(EnvGet("USERPROFILE")))
    catch {
    }
    if (up != "") {
        p2 := up . "\.hermes\.env"
        if !seen.Has(p2) {
            seen[p2] := true
            tried.Push(p2)
        }
    }
    la := UserStudio_LocalAppDataDir()
    return Map("tried", tried, "localAppData", la, "primaryDir", UserStudio_GetHermesPrimaryDataDir())
}

UserStudio_ParseHermesEnvFile(path) {
    out := Map()
    path := Trim(String(path))
    if (path = "" || !FileExist(path))
        return out
    raw := ""
    try raw := FileRead(path, "UTF-8")
    catch {
        return out
    }
    if (Ord(SubStr(raw, 1, 1)) = 0xFEFF)
        raw := SubStr(raw, 2)
    for _, line in StrSplit(raw, "`n", "`r") {
        line := Trim(line)
        if (line = "" || SubStr(line, 1, 1) = "#" || SubStr(line, 1, 1) = ";")
            continue
        if !RegExMatch(line, "^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", &m)
            continue
        key := m[1]
        val := Trim(m[2])
        if (SubStr(val, 1, 1) = Chr(34) && SubStr(val, -1) = Chr(34))
            val := SubStr(val, 2, -1)
        else if (SubStr(val, 1, 1) = "'" && SubStr(val, -1) = "'")
            val := SubStr(val, 2, -1)
        out[key] := val
    }
    if (!out.Has("API_SERVER_KEY") || Trim(String(out.Get("API_SERVER_KEY", ""))) = "") {
        if RegExMatch(raw, "m)^API_SERVER_KEY\s*=\s*([^\r\n#;]+)", &mk)
            out["API_SERVER_KEY"] := Trim(mk[1])
    }
    return out
}

UserStudio_HermesNormalizeKey(key) {
    key := Trim(String(key))
    if (key = "")
        return ""
    key := RegExReplace(key, "i)^\s*Bearer\s+", "")
    dq := Chr(34)
    if (SubStr(key, 1, 1) = dq && SubStr(key, -1) = dq)
        key := SubStr(key, 2, -1)
    return RegExReplace(key, "\s+", "")
}

UserStudio_ExtractHermesApiKeyFromEnvRaw(raw) {
    raw := Trim(String(raw))
    if (raw = "")
        return ""
    if (Ord(SubStr(raw, 1, 1)) = 0xFEFF)
        raw := SubStr(raw, 2)
    last := ""
    pos := 1
    while RegExMatch(raw, "i)API_SERVER_KEY\s*=\s*([^\r\n#;]+)", &mk, pos) {
        cand := UserStudio_HermesNormalizeKey(Trim(mk[1]))
        if (cand != "")
            last := cand
        pos := mk.Pos(0) + mk.Len(0)
    }
    return last
}

/** 从本机 hermes .env 读取 API_SERVER_KEY（供 NiumaChat / 设置页一键连接） */
UserStudio_QuickReadHermesApiServerKey() {
    host := "127.0.0.1"
    port := 8642
    key := ""
    source := ""
    tried := []
    seen := Map()
    pushPath(p) {
        p := Trim(String(p))
        if (p = "" || seen.Has(p))
            return
        seen[p] := true
        tried.Push(p)
    }
    for _, dir in UserStudio_ListHermesDataDirs()
        pushPath(dir . "\.env")
    la := UserStudio_LocalAppDataDir()
    if (la != "")
        pushPath(la . "\hermes\.env")
    up := ""
    try up := Trim(EnvGet("USERPROFILE"))
    catch {
    }
    if (up != "") {
        pushPath(up . "\.hermes\.env")
        pushPath(up . "\AppData\Local\hermes\.env")
    }
    for _, path in tried {
        if !FileExist(path)
            continue
        raw := ""
        try raw := FileRead(path, "UTF-8")
        catch {
            try raw := FileRead(path)
            catch {
                continue
            }
        }
        k := UserStudio_ExtractHermesApiKeyFromEnvRaw(raw)
        if (k = "")
            continue
        key := k
        source := path
        if RegExMatch(raw, "m)^API_SERVER_HOST\s*=\s*([^\r\n#;]+)", &mh)
            host := Trim(mh[1])
        if RegExMatch(raw, "m)^API_SERVER_PORT\s*=\s*(\d+)", &mp)
            port := Integer(mp[1])
        if (host = "localhost")
            host := "127.0.0.1"
        break
    }
    return Map("token", key, "source", source, "host", host, "port", port, "tried", tried)
}

UserStudio_HermesEnvTruthy(val) {
    v := StrLower(Trim(String(val)))
    return (v = "1" || v = "true" || v = "yes" || v = "on")
}

UserStudio_ReadHermesDotEnv() {
    merged := Map()
    merged["_sources"] := Map()
    for _, dir in UserStudio_ListHermesDataDirs() {
        envPath := dir . "\.env"
        part := UserStudio_ParseHermesEnvFile(envPath)
        if !(part is Map)
            continue
        for k, v in part {
            if (k = "_sources")
                continue
            merged[k] := v
            if (k = "API_SERVER_KEY" && Trim(String(v)) != "")
                merged["_sources"]["API_SERVER_KEY"] := envPath
        }
    }
    return merged
}

UserStudio_GenerateHermesApiServerKey() {
    chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    out := ""
    Loop 32
        out .= SubStr(chars, Random(1, StrLen(chars)), 1)
    return out
}

UserStudio_AppendHermesEnvLines(envPath, lines) {
    envPath := Trim(String(envPath))
    if (envPath = "")
        return false
    dir := ""
    if RegExMatch(envPath, "^(.*)\\[^\\]+$", &m)
        dir := m[1]
    if (dir != "" && !DirExist(dir))
        try DirCreate(dir)
    block := "`n# NMER: Hermes API Server (for 牛马智能定制一键连接)`n"
    for _, line in lines
        block .= line . "`n"
    try {
        if FileExist(envPath) {
            raw := FileRead(envPath, "UTF-8")
            if !RegExMatch(raw, "i)\r?\n\s*$")
                block := "`n" . block
            FileAppend(block, envPath, "UTF-8")
        } else
            FileAppend(RTrim(block, "`n"), envPath, "UTF-8")
        return true
    } catch {
        return false
    }
}

UserStudio_EnsureHermesApiServerEnv() {
    cfg := UserStudio_ReadHermesApiConfig()
    key := Trim(String(cfg.Get("key", "")))
    if (key != "")
        return Map("ok", true, "key", key, "source", String(cfg.Get("source", "")), "wrote", false, "path", "")
    envPath := UserStudio_GetHermesEnvPath()
    key := UserStudio_GenerateHermesApiServerKey()
    lines := [
        "API_SERVER_ENABLED=true",
        "API_SERVER_KEY=" . key,
        "API_SERVER_HOST=127.0.0.1",
        "API_SERVER_PORT=8642"
    ]
    if !UserStudio_AppendHermesEnvLines(envPath, lines)
        return Map("ok", false, "error", "无法写入 " . envPath, "wrote", false, "path", envPath)
    cfg2 := UserStudio_ReadHermesApiConfig()
    key2 := Trim(String(cfg2.Get("key", "")))
    if (key2 = "")
        key2 := key
    return Map(
        "ok", true,
        "key", key2,
        "source", envPath,
        "wrote", true,
        "path", envPath,
        "hint", "已写入 API_SERVER_KEY。请完全退出并重新打开 Hermes 桌面应用，待网关启动后再点一键连接（端口 8642）。"
    )
}

UserStudio_FindHermesCliExe() {
    candidates := []
    try {
        la := Trim(String(EnvGet("LOCALAPPDATA")))
        if (la != "") {
            candidates.Push(la . "\hermes\bin\hermes.cmd")
            candidates.Push(la . "\hermes\hermes-agent\venv\Scripts\hermes.exe")
            candidates.Push(la . "\hermes\hermes-agent\apps\desktop\release\win-unpacked\Hermes.exe")
        }
    } catch {
    }
    candidates.Push("C:\Program Files\hermes\hermes.exe")
    for _, p in candidates {
        if FileExist(p)
            return p
    }
    out := A_Temp . "\nmer_hermes_where_" . A_TickCount . ".txt"
    q := Chr(34)
    try {
        RunWait(q . A_ComSpec . q . " /c where hermes > " . q . out . q . " 2>nul", , "Hide")
        if FileExist(out) {
            raw := FileRead(out, "UTF-8")
            try FileDelete(out)
            for _, line in StrSplit(raw, "`n", "`r") {
                line := Trim(line)
                if (line != "" && FileExist(line))
                    return line
            }
        }
    } catch {
        try FileDelete(out)
    }
    return ""
}

UserStudio_HermesGatewayCliOk(timeoutMs := 15000) {
    exe := UserStudio_FindHermesCliExe()
    if (exe = "")
        return false
    out := A_Temp . "\nmer_hermes_gw_status.txt"
    try FileDelete(out)
    inner := '"' . exe . '" gateway status > "' . out . '" 2>&1'
    try {
        RunWait(A_ComSpec . ' /c "' . inner . '"', , "Hide")
    } catch {
        return false
    }
    if !FileExist(out)
        return false
    raw := ""
    try raw := FileRead(out, "UTF-8")
    catch {
        return false
    }
    try FileDelete(out)
    low := StrLower(raw)
    if InStr(low, "running") || InStr(low, "listening") || InStr(low, "ok")
        return true
    if RegExMatch(raw, ":\s*8642")
        return true
    return false
}

UserStudio_ReadHermesApiConfig() {
    host := "127.0.0.1"
    port := 8642
    key := ""
    enabled := false
    source := ""
    try {
        if UserStudio_HermesEnvTruthy(EnvGet("API_SERVER_ENABLED"))
            enabled := true
    } catch {
    }
    try {
        eh := Trim(String(EnvGet("API_SERVER_HOST")))
        if (eh != "")
            host := eh
    } catch {
    }
    try {
        ep := Trim(String(EnvGet("API_SERVER_PORT")))
        if (ep != "" && ep ~= "^\d+$")
            port := Integer(ep)
    } catch {
    }
    try {
        ek := UserStudio_NormalizeApiKey(EnvGet("API_SERVER_KEY"))
        if (ek != "") {
            key := ek
            source := "env:API_SERVER_KEY"
        }
    } catch {
    }
    dot := UserStudio_ReadHermesDotEnv()
    if (dot is Map) {
        if (dot.Has("API_SERVER_ENABLED") && UserStudio_HermesEnvTruthy(dot["API_SERVER_ENABLED"]))
            enabled := true
        if (dot.Has("API_SERVER_HOST") && Trim(String(dot["API_SERVER_HOST"])) != "")
            host := Trim(String(dot["API_SERVER_HOST"]))
        if (dot.Has("API_SERVER_PORT") && Trim(String(dot["API_SERVER_PORT"])) ~= "^\d+$")
            port := Integer(dot["API_SERVER_PORT"])
        if (key = "" && dot.Has("API_SERVER_KEY")) {
            k2 := UserStudio_NormalizeApiKey(dot["API_SERVER_KEY"])
            if (k2 != "") {
                key := k2
                srcPath := ""
                if (dot.Has("_sources") && dot["_sources"] is Map)
                    srcPath := Trim(String(dot["_sources"].Get("API_SERVER_KEY", "")))
                source := srcPath != "" ? srcPath : (UserStudio_GetHermesPrimaryDataDir() . "\.env")
            }
        }
    }
    if (host = "localhost")
        host := "127.0.0.1"
    return Map("host", host, "port", port, "key", key, "enabled", enabled, "source", source)
}

UserStudio_ProbeHermesApiServer(base, key, timeoutMs := 12000) {
    key := UserStudio_NormalizeApiKey(key)
    host := "127.0.0.1"
    port := 8642
    base := Trim(String(base))
    if RegExMatch(base, "i)^[a-z]+://([^/:]+)(?::(\d+))?", &m) {
        if (m[1] != "")
            host := m[1]
        if (m[2] != "")
            port := Integer(m[2])
    } else if RegExMatch(base, ":(\d+)", &mp)
        port := Integer(mp[1])
    t0 := A_TickCount
    if (key != "" && FuncExists("LlmApiPing_HttpSync")) {
        url := "http://" . host . ":" . port . "/health"
        try {
            r := Func("LlmApiPing_HttpSync").Call("GET", url, Map("Authorization", "Bearer " . key), "", Min(Max(3000, Integer(timeoutMs)), 8000))
            if r is Map && r.Get("ok", false)
                return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0)
            if r is Map && Integer(r.Get("status", 0)) = 401
                return Map("ok", false, "error", "API Server 鉴权失败：请核对 ~/.hermes/.env 中 API_SERVER_KEY 与 NMER 中保存的一致。", "elapsedMs", A_TickCount - t0)
        } catch {
        }
        url2 := "http://" . host . ":" . port . "/v1/models"
        try {
            r2 := Func("LlmApiPing_HttpSync").Call("GET", url2, Map("Authorization", "Bearer " . key), "", Min(Max(3000, Integer(timeoutMs)), 8000))
            if r2 is Map && r2.Get("ok", false)
                return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0)
        } catch {
        }
    }
    if UserStudio_HermesGatewayCliOk(Min(Max(6000, Integer(timeoutMs)), 15000))
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0)
    tcpMs := Min(Max(800, Integer(timeoutMs)), 3000)
    if UserStudio_TcpPortOpen(host, port, tcpMs)
        return Map(
            "ok", true,
            "error", "",
            "elapsedMs", A_TickCount - t0,
            "hint", key = "" ? "端口已开放但未验证 API Key" : ""
        )
    dataDir := UserStudio_GetHermesPrimaryDataDir()
    err := "无法连接 Hermes API Server（" . host . ":" . port . "）。Key 已就绪时请完全退出并重启 Hermes 桌面应用以启动 API Server。"
    if (key = "")
        err := "未找到 API_SERVER_KEY。请在 " . dataDir . "\.env 配置，或在设置里点「一键连接 Hermes」自动写入。"
    return Map("ok", false, "error", err, "elapsedMs", A_TickCount - t0)
}

UserStudio_ProbeHermesGatewayToken(ensureEnv := false) {
    if (ensureEnv && FuncExists("UserStudio_EnsureHermesApiServerEnv")) {
        try UserStudio_EnsureHermesApiServerEnv()
        catch {
        }
    }
    cfg := UserStudio_ReadHermesApiConfig()
    host := Trim(String(cfg.Get("host", "127.0.0.1")))
    port := Integer(cfg.Get("port", 8642))
    key := Trim(String(cfg.Get("key", "")))
    source := Trim(String(cfg.Get("source", "")))
    tried := []
    for _, dir in UserStudio_ListHermesDataDirs()
        tried.Push(dir . "\.env")
    if (key != "")
        return Map("token", key, "source", source, "host", host, "port", port, "apiEnabled", !!cfg.Get("enabled", false), "tried", tried)
    return Map("token", "", "source", "", "host", host, "port", port, "apiEnabled", !!cfg.Get("enabled", false), "tried", tried)
}

UserStudio_ExtractOpenClawKeyFromDoc(doc) {
    if !(doc is Map)
        return ""
    if doc.Has("apiKeys") && doc["apiKeys"] is Map {
        k := UserStudio_NormalizeApiKey(doc["apiKeys"].Get("openclaw", ""))
        if (k != "")
            return k
    }
    if doc.Has("llm") && doc["llm"] is Map {
        if UserStudio_NormalizeLlmProvider(doc["llm"].Get("provider", "")) = "openclaw" {
            k2 := UserStudio_NormalizeApiKey(doc["llm"].Get("apiKey", ""))
            if (k2 != "")
                return k2
        }
    }
    opt := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
    opt := UserStudio_NormalizeNiumaOptions(opt)
    if opt.Has("llmApiKeys") && opt["llmApiKeys"] is Map {
        k3 := UserStudio_NormalizeApiKey(opt["llmApiKeys"].Get("openclaw", ""))
        if (k3 != "")
            return k3
    }
    return ""
}

UserStudio_ReadNiumaHermesKey() {
    path := ""
    if FuncExists("UserStudio_NiumaLlmSyncPath")
        path := UserStudio_NiumaLlmSyncPath()
    if (path != "" && FileExist(path)) {
        try {
            raw := FileRead(path, "UTF-8")
            if (Trim(raw) != "") {
                doc := _US_JxonLoad(raw)
                if ((doc is Map) && doc.Has("apiKeys") && doc["apiKeys"] is Map) {
                    k := UserStudio_NormalizeApiKey(doc["apiKeys"].Get("hermes", ""))
                    if (k != "")
                        return k
                }
            }
        } catch {
        }
    }
    try {
        doc := UserStudio_Get()
        if ((doc is Map) && doc.Has("apiKeys") && doc["apiKeys"] is Map) {
            k := UserStudio_NormalizeApiKey(doc["apiKeys"].Get("hermes", ""))
            if (k != "")
                return k
        }
    } catch {
    }
    return ""
}

UserStudio_ReadNiumaOpenClawKey() {
    path := ""
    if FuncExists("UserStudio_NiumaLlmSyncPath")
        path := UserStudio_NiumaLlmSyncPath()
    if (path != "" && FileExist(path)) {
        try {
            raw := FileRead(path, "UTF-8")
            if (Trim(raw) != "") {
                doc := _US_JxonLoad(raw)
                k := UserStudio_ExtractOpenClawKeyFromDoc(doc)
                if (k != "")
                    return k
            }
        } catch {
        }
    }
    try {
        kStudio := UserStudio_ExtractOpenClawKeyFromDoc(UserStudio_Get())
        if (kStudio != "")
            return kStudio
    } catch {
    }
    return ""
}

UserStudio_ApplyLlmAutoDefaults(doc) {
    if !(doc is Map)
        return doc
    if !(doc.Has("llm") && doc["llm"] is Map)
        return doc
    llm := doc["llm"]
    prov := UserStudio_NormalizeLlmProvider(llm["provider"])
    llm["provider"] := prov
    if (prov = "custom")
        return doc
    optIn := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
    optIn := UserStudio_NormalizeNiumaOptions(optIn)
    manualMap := optIn.Has("llmManualBaseUrl") && optIn["llmManualBaseUrl"] is Map ? optIn["llmManualBaseUrl"] : Map()
    manualThis := !!manualMap.Get(prov, optIn.Get("manualBaseUrl", false))
    pre := UserStudio_LlmPresetFor(prov)
    bu := Trim(String(llm["baseUrl"]))
    if manualThis && bu != "" && UserStudio_BaseUrlMatchesProvider(prov, bu) {
        ; 保留该服务商手动指定的合法地址
    } else if !UserStudio_BaseUrlMatchesProvider(prov, bu) || !manualThis
        llm["baseUrl"] := pre.Get("baseUrl", "")
    m := Trim(String(llm["model"]))
    if (m = "")
        llm["model"] := pre.Get("model", "")
    doc["llm"] := llm
    return doc
}

UserStudio_NormalizeDoc(doc) {
    if !(doc is Map)
        doc := Map()
    llmIn := doc.Has("llm") && doc["llm"] is Map ? doc["llm"] : Map()
    pathsIn := doc.Has("paths") && doc["paths"] is Map ? doc["paths"] : Map()
    optIn := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
    cardProvidersIn := []
    hasCardProviders := false
    if optIn.Has("llmCardProviders") {
        hasCardProviders := true
        cardProvidersIn := UserStudio_NormalizeCardProviders(optIn["llmCardProviders"])
    }
    prov := UserStudio_NormalizeLlmProvider(llmIn.Get("provider", "openai"))
    if (prov = "")
        prov := "openai"
    llm := Map(
        "provider", prov,
        "apiKey", UserStudio_NormalizeApiKey(llmIn.Get("apiKey", "")),
        "baseUrl", Trim(String(llmIn.Get("baseUrl", ""))),
        "model", Trim(String(llmIn.Get("model", "")))
    )
    paths := Map(
        "cursor", Trim(String(pathsIn.Get("cursor", ""))),
        "autohotkey", Trim(String(pathsIn.Get("autohotkey", ""))),
        "everything", Trim(String(pathsIn.Get("everything", ""))),
        "python", Trim(String(pathsIn.Get("python", ""))),
        "notes", Trim(String(pathsIn.Get("notes", "")))
    )
    ttydIn := doc.Has("ttyd") && doc["ttyd"] is Map ? doc["ttyd"] : Map()
    sh := Trim(String(ttydIn.Get("shell", "cmd.exe")))
    if (sh = "")
        sh := "cmd.exe"
    wd := Trim(String(ttydIn.Get("workDir", "")))
    tp := Integer(ttydIn.Get("port", 7691))
    if (tp < 1024 || tp > 65535)
        tp := 7691
    ttyd := Map("shell", sh, "workDir", wd, "port", tp)
    optIn := UserStudio_NormalizeNiumaOptions(optIn)
    optIn := UserStudio_MergeLlmApiKeys(optIn, llm)
    optIn := UserStudio_MergeLlmBaseUrls(optIn, llm)
    if hasCardProviders
        optIn["llmCardProviders"] := cardProvidersIn
    return UserStudio_ApplyLlmAutoDefaults(Map(
        "version", Integer(doc.Get("version", 1)),
        "llm", llm,
        "paths", paths,
        "ttyd", ttyd,
        "options", optIn,
        "updatedAt", Trim(String(doc.Get("updatedAt", "")))
    ))
}

UserStudio_MergeWithRuntimePaths(doc) {
    global CursorPath, ConfigFile
    doc := UserStudio_NormalizeDoc(doc)
    paths := doc["paths"]
    if (paths["cursor"] = "" && IsSet(CursorPath) && CursorPath != "")
        paths["cursor"] := CursorPath
    if (paths["autohotkey"] = "") {
        try paths["autohotkey"] := A_AhkPath
        catch {
        }
    }
    doc["paths"] := paths
    return doc
}

UserStudio_Load(*) {
    global g_UserStudio, g_UserStudioLoaded
    UserStudio_EnsureConfigDir()
    path := UserStudio_Path()
    doc := UserStudio_DefaultDocument()
    if FileExist(path) {
        try {
            raw := FileRead(path, "UTF-8")
            parsed := _US_JxonLoad(raw)
            if (parsed is Map)
                doc := UserStudio_NormalizeDoc(parsed)
        } catch as e {
            OutputDebug("[UserStudio] load failed: " . e.Message)
        }
    } else {
        try UserStudio_Save(doc)
        catch {
        }
    }
    doc := UserStudio_MergeWithRuntimePaths(doc)
    doc := UserStudio_MergeLlmFromNiumaSync(doc)
    g_UserStudio := doc
    g_UserStudioLoaded := true
    return doc
}

; 从 niuma_chat_llm.json 合并到内存；若新读到 Key 则写回 user_studio.json
UserStudio_SyncFromNiumaFile(*) {
    doc := UserStudio_Load()
    keyBefore := Trim(String(doc["llm"].Get("apiKey", "")))
    ocBefore := UserStudio_ExtractOpenClawKeyFromDoc(doc)
    doc := UserStudio_MergeLlmFromNiumaSync(doc)
    keyAfter := Trim(String(doc["llm"].Get("apiKey", "")))
    ocAfter := UserStudio_ExtractOpenClawKeyFromDoc(doc)
    if (keyAfter != "" && keyAfter != keyBefore) {
        try UserStudio_Save(doc)
        catch {
        }
    } else if (keyAfter != "" || ocAfter != ocBefore) {
        global g_UserStudio
        g_UserStudio := doc
        if (ocAfter != "" && ocAfter != ocBefore) {
            try UserStudio_Save(doc)
            catch {
            }
        }
    }
    ok := (keyAfter != "")
    err := ok ? "" : "未找到 API Key（请先在 Niuma Chat 设置中保存，或点「从 Niuma Chat 同步 API」）"
    return Map(
        "ok", ok,
        "error", err,
        "openclawOk", (ocAfter != ""),
        "studio", UserStudio_PayloadForWeb()
    )
}

UserStudio_MergeLlmFromNiumaSync(doc) {
    path := UserStudio_NiumaLlmSyncPath()
    if !FileExist(path)
        return doc
    try {
        raw := FileRead(path, "UTF-8")
        sync := _US_JxonLoad(raw)
        if !(sync is Map)
            return doc
        if !doc.Has("llm") || !(doc["llm"] is Map)
            doc["llm"] := Map()
        if !doc.Has("options") || !(doc["options"] is Map)
            doc["options"] := Map()
        doc["options"] := UserStudio_NormalizeNiumaOptions(doc["options"])
        llmIn := sync.Has("llm") && sync["llm"] is Map ? sync["llm"] : sync
        syncProv := UserStudio_NormalizeLlmProvider(llmIn.Get("provider", doc["llm"].Get("provider", "openai")))
        keys := doc["options"].Has("llmApiKeys") && doc["options"]["llmApiKeys"] is Map ? doc["options"]["llmApiKeys"] : Map()
        if (sync.Has("apiKeys") && sync["apiKeys"] is Map) {
            for k, v in sync["apiKeys"] {
                pk := UserStudio_NormalizeLlmProvider(k)
                vk := UserStudio_NormalizeApiKey(v)
                if (vk != "")
                    keys[pk] := vk
            }
        }
        key := UserStudio_NormalizeApiKey(llmIn.Get("apiKey", ""))
        if (key != "")
            keys[syncProv] := key
        doc["options"]["llmApiKeys"] := keys
        curProv := UserStudio_NormalizeLlmProvider(doc["llm"].Get("provider", "openai"))
        curKey := UserStudio_NormalizeApiKey(doc["llm"].Get("apiKey", ""))
        if (curKey = "" && keys.Has(curProv))
            doc["llm"]["apiKey"] := keys[curProv]
        else if (curKey = "" && keys.Has(syncProv))
            doc["llm"]["apiKey"] := keys[syncProv]
        if (doc["llm"].Get("provider", "") = "")
            doc["llm"]["provider"] := syncProv
        if (Trim(String(doc["llm"].Get("baseUrl", ""))) = "" && Trim(String(llmIn.Get("baseUrl", ""))) != "")
            doc["llm"]["baseUrl"] := Trim(String(llmIn["baseUrl"]))
        if (Trim(String(doc["llm"].Get("model", ""))) = "" && Trim(String(llmIn.Get("model", ""))) != "")
            doc["llm"]["model"] := Trim(String(llmIn["model"]))
        doc := UserStudio_NormalizeDoc(doc)
    } catch {
    }
    return doc
}

UserStudio_WriteNiumaLlmSync(docOrLlm) {
    if !(docOrLlm is Map)
        return
    llm := docOrLlm
    apiKeys := Map()
    if (docOrLlm.Has("llm") && docOrLlm["llm"] is Map)
        llm := docOrLlm["llm"]
    if (docOrLlm.Has("options") && docOrLlm["options"] is Map) {
        opt := UserStudio_NormalizeNiumaOptions(docOrLlm["options"])
        if (opt.Has("llmApiKeys") && opt["llmApiKeys"] is Map) {
            for k, v in opt["llmApiKeys"] {
                pk := UserStudio_NormalizeLlmProvider(k)
                vk := UserStudio_NormalizeApiKey(v)
                if (vk != "")
                    apiKeys[pk] := vk
            }
        }
    }
    UserStudio_EnsureConfigDir()
    key := Trim(String(llm.Get("apiKey", "")))
    if (key = "" && apiKeys.Count = 0)
        return
    if (key = "") {
        prov := UserStudio_NormalizeLlmProvider(llm.Get("provider", "openai"))
        if apiKeys.Has(prov)
            key := apiKeys[prov]
    }
    if (key = "")
        return
    try {
        f := FileOpen(UserStudio_NiumaLlmSyncPath(), "w", "UTF-8")
        if !f
            return
        f.Write(_US_JxonDump(Map(
            "llm", Map(
                "provider", llm.Get("provider", "openai"),
                "apiKey", key,
                "baseUrl", llm.Get("baseUrl", ""),
                "model", llm.Get("model", "")
            ),
            "apiKeys", apiKeys,
            "updatedAt", FormatTime(, "yyyy-MM-dd HH:mm:ss")
        )))
        f.Close()
    } catch {
    }
}

UserStudio_Get() {
    global g_UserStudio, g_UserStudioLoaded
    if !g_UserStudioLoaded
        return UserStudio_Load()
    return g_UserStudio
}

UserStudio_Save(doc) {
    global g_UserStudio, g_UserStudioLoaded
    UserStudio_EnsureConfigDir()
    doc := UserStudio_NormalizeDoc(doc)
    doc["updatedAt"] := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    path := UserStudio_Path()
    try {
        if FileExist(path)
            FileCopy(path, UserStudio_BackupPath(), 1)
    } catch {
    }
    f := FileOpen(path, "w", "UTF-8")
    if !f
        throw Error("无法写入 " . path)
    f.Write(_US_JxonDump(doc))
    f.Close()
    g_UserStudio := doc
    g_UserStudioLoaded := true
    return doc
}

UserStudio_RestoreDefaults(*) {
    doc := UserStudio_DefaultDocument()
    try UserStudio_Save(doc)
    catch as e {
        return Map("ok", false, "error", e.Message)
    }
    try UserStudio_ApplyPathsToGlobals(doc)
    catch {
    }
    try UserStudio_SyncTtydToIni(doc)
    catch {
    }
    return Map("ok", true, "error", "", "studio", doc)
}

UserStudio_ExportTo(path) {
    src := UserStudio_Path()
    if !FileExist(src)
        UserStudio_Load()
    try {
        FileCopy(src, path, 1)
        return Map("ok", true, "error", "")
    } catch as e {
        return Map("ok", false, "error", e.Message)
    }
}

UserStudio_ImportFrom(path) {
    if !FileExist(path)
        return Map("ok", false, "error", "文件不存在")
    try {
        raw := FileRead(path, "UTF-8")
        parsed := _US_JxonLoad(raw)
        if !(parsed is Map)
            return Map("ok", false, "error", "JSON 格式无效")
        doc := UserStudio_NormalizeDoc(parsed)
        UserStudio_Save(doc)
        UserStudio_ApplyPathsToGlobals(doc)
        try UserStudio_SyncTtydToIni(doc)
        catch {
        }
        return Map("ok", true, "error", "", "studio", doc)
    } catch as e {
        return Map("ok", false, "error", e.Message)
    }
}

UserStudio_ApplyPathsToGlobals(doc) {
    global CursorPath, ConfigFile
    if !(doc is Map)
        return
    paths := doc.Has("paths") && doc["paths"] is Map ? doc["paths"] : Map()
    cp := Trim(String(paths.Get("cursor", "")))
    if (cp != "") {
        try cp := UserStudio_NormalizeWinPath(cp)
        catch {
        }
        if FileExist(cp) {
            CursorPath := cp
            if (IsSet(ConfigFile) && ConfigFile != "")
                IniWrite(CursorPath, ConfigFile, "Settings", "CursorPath")
        }
    }
}

UserStudio_EnsureDocStructure(&doc) {
    if !(doc is Map)
        doc := Map()
    if !doc.Has("llm") || !(doc["llm"] is Map)
        doc["llm"] := Map("provider", "openai", "apiKey", "", "baseUrl", "", "model", "")
    if !doc.Has("paths") || !(doc["paths"] is Map)
        doc["paths"] := Map("cursor", "", "autohotkey", "", "everything", "", "python", "", "notes", "")
    if !doc.Has("options") || !(doc["options"] is Map)
        doc["options"] := Map()
    if !doc.Has("ttyd") || !(doc["ttyd"] is Map)
        doc["ttyd"] := Map("shell", "cmd.exe", "workDir", "", "port", 7691)
    doc["options"] := UserStudio_NormalizeNiumaOptions(doc["options"])
}

UserStudio_CoerceWebMap(val) {
    if (val is String) {
        s := Trim(String(val))
        if (s != "") {
            try {
                parsed := _US_JxonLoad(s)
                if (parsed is Map)
                    return parsed
            } catch {
            }
        }
        return Map()
    }
    if (val is Map)
        return val
    return Map()
}

UserStudio_CoerceWebPayload(&payload) {
    if !(payload is Map) {
        if (payload is String) {
            s := Trim(String(payload))
            if (s != "")
                try payload := _US_JxonLoad(s)
        }
        if !(payload is Map)
            payload := Map()
    }
    if payload.Has("llm")
        payload["llm"] := UserStudio_CoerceWebMap(payload["llm"])
    if payload.Has("options")
        payload["options"] := UserStudio_CoerceWebMap(payload["options"])
    if payload.Has("paths")
        payload["paths"] := UserStudio_CoerceWebMap(payload["paths"])
    opt := payload.Has("options") && payload["options"] is Map ? payload["options"] : Map()
    if opt.Has("llmApiKeys") && !(opt["llmApiKeys"] is Map)
        opt["llmApiKeys"] := UserStudio_CoerceWebMap(opt["llmApiKeys"])
    if opt.Has("llmBaseUrls") && !(opt["llmBaseUrls"] is Map)
        opt["llmBaseUrls"] := UserStudio_CoerceWebMap(opt["llmBaseUrls"])
    if opt.Has("llmModels") && !(opt["llmModels"] is Map)
        opt["llmModels"] := UserStudio_CoerceWebMap(opt["llmModels"])
    payload["options"] := opt
}

UserStudio_NormalizeCardProviders(raw) {
    cards := []
    if (raw is Array) {
        for _, p in raw {
            pv := UserStudio_NormalizeLlmProvider(p)
            if (pv != "")
                cards.Push(pv)
        }
        return cards
    }
    if (raw is String) {
        s := Trim(String(raw))
        if (s != "") {
            try {
                parsed := _US_JxonLoad(s)
                if (parsed is Array) {
                    for _, p in parsed {
                        pv := UserStudio_NormalizeLlmProvider(p)
                        if (pv != "")
                            cards.Push(pv)
                    }
                }
            } catch {
            }
        }
    }
    return cards
}

UserStudio_MergePayloadLlmApiKeys(mergedOpt, optPayload, llmPayload) {
    if !(mergedOpt is Map)
        mergedOpt := Map()
    keys := mergedOpt.Has("llmApiKeys") && mergedOpt["llmApiKeys"] is Map ? mergedOpt["llmApiKeys"].Clone() : Map()
    if (optPayload is Map && optPayload.Has("llmApiKeys") && optPayload["llmApiKeys"] is Map) {
        for k, v in optPayload["llmApiKeys"] {
            pk := UserStudio_NormalizeLlmProvider(k)
            vk := UserStudio_NormalizeApiKey(v)
            if (vk != "")
                keys[pk] := vk
        }
    }
    if (llmPayload is Map) {
        prov := UserStudio_NormalizeLlmProvider(llmPayload.Get("provider", mergedOpt.Get("provider", "openai")))
        ak := UserStudio_NormalizeApiKey(llmPayload.Get("apiKey", ""))
        if (ak != "")
            keys[prov] := ak
    }
    mergedOpt["llmApiKeys"] := keys
    return mergedOpt
}

UserStudio_PickDisplayApiKey(doc) {
    if !(doc is Map)
        return ""
    llm := doc.Has("llm") && doc["llm"] is Map ? doc["llm"] : Map()
    prov := UserStudio_NormalizeLlmProvider(llm.Get("provider", "openai"))
    ak := UserStudio_NormalizeApiKey(llm.Get("apiKey", ""))
    if (ak != "")
        return ak
    opt := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
    if opt.Has("llmApiKeys") && opt["llmApiKeys"] is Map && opt["llmApiKeys"].Has(prov)
        return UserStudio_NormalizeApiKey(opt["llmApiKeys"][prov])
    return ""
}

UserStudio_ApplyLlmCardsFlat(msg) {
    if !(msg is Map)
        throw Error("无效的大模型卡片数据")
    doc := UserStudio_Get()
    UserStudio_EnsureDocStructure(&doc)
    cards := []
    cardsRaw := Trim(String(msg.Get("cards", "")))
    if (cardsRaw = "__empty__") {
        cards := []
    } else if (cardsRaw != "") {
        for _, part in StrSplit(cardsRaw, ",") {
            p := UserStudio_NormalizeLlmProvider(Trim(part))
            if (p != "")
                cards.Push(p)
        }
    }
    doc["options"]["llmCardProviders"] := cards
    keysJson := Trim(String(msg.Get("keysJson", "")))
    if (keysJson != "") {
        try {
            keysParsed := _US_JxonLoad(keysJson)
            if (keysParsed is Map) {
                keys := Map()
                for k, v in keysParsed {
                    pk := UserStudio_NormalizeLlmProvider(k)
                    vk := UserStudio_NormalizeApiKey(v)
                    if (vk != "")
                        keys[pk] := vk
                }
                doc["options"]["llmApiKeys"] := keys
            }
        } catch {
        }
    }
    modelsJson := Trim(String(msg.Get("modelsJson", "")))
    if (modelsJson != "") {
        try {
            modelsParsed := _US_JxonLoad(modelsJson)
            if (modelsParsed is Map) {
                models := Map()
                for k, v in modelsParsed {
                    pk := UserStudio_NormalizeLlmProvider(k)
                    mv := Trim(String(v))
                    if (mv != "")
                        models[pk] := mv
                }
                doc["options"]["llmModels"] := models
            }
        } catch {
        }
    }
    prov := UserStudio_NormalizeLlmProvider(msg.Get("llmProvider", doc["llm"].Get("provider", "openai")))
    doc["llm"]["provider"] := prov
    ak := UserStudio_NormalizeApiKey(msg.Get("llmApiKey", ""))
    doc["llm"]["apiKey"] := ak
    bu := Trim(String(msg.Get("llmBaseUrl", "")))
    if (bu != "")
        doc["llm"]["baseUrl"] := bu
    mo := Trim(String(msg.Get("llmModel", "")))
    if (mo != "")
        doc["llm"]["model"] := mo
    doc["options"] := UserStudio_MergeLlmApiKeys(doc["options"], doc["llm"])
    doc := UserStudio_NormalizeDoc(doc)
    UserStudio_Save(doc)
    try UserStudio_WriteNiumaLlmSync(doc)
    catch {
    }
    return doc
}

UserStudio_ApplyFromWebPayload(payload) {
    if !(payload is Map)
        throw Error("定制数据无效")
    UserStudio_CoerceWebPayload(&payload)
    cur := UserStudio_Get()
    UserStudio_EnsureDocStructure(&cur)
    llmPayload := payload.Has("llm") && payload["llm"] is Map ? payload["llm"] : Map()
    if (llmPayload.Count > 0) {
        for k, v in llmPayload
            cur["llm"][k] := v
    }
    if payload.Has("paths") && payload["paths"] is Map {
        for k, v in payload["paths"]
            cur["paths"][k] := Trim(String(v))
    }
    if payload.Has("options") && payload["options"] is Map {
        merged := cur["options"].Clone()
        optPayload := payload["options"]
        merged := UserStudio_MergePayloadLlmApiKeys(merged, optPayload, llmPayload)
        if optPayload.Has("llmBaseUrls") && optPayload["llmBaseUrls"] is Map {
            urls := merged.Has("llmBaseUrls") && merged["llmBaseUrls"] is Map ? merged["llmBaseUrls"].Clone() : Map()
            for k, v in optPayload["llmBaseUrls"] {
                pk := UserStudio_NormalizeLlmProvider(k)
                vu := Trim(String(v))
                if (vu != "" && UserStudio_BaseUrlMatchesProvider(pk, vu))
                    urls[pk] := vu
            }
            merged["llmBaseUrls"] := urls
        }
        if optPayload.Has("llmModels") && optPayload["llmModels"] is Map {
            models := merged.Has("llmModels") && merged["llmModels"] is Map ? merged["llmModels"].Clone() : Map()
            for k, v in optPayload["llmModels"] {
                pk := UserStudio_NormalizeLlmProvider(k)
                mv := Trim(String(v))
                if (mv != "")
                    models[pk] := mv
            }
            merged["llmModels"] := models
        }
        if optPayload.Has("llmCardProviders")
            merged["llmCardProviders"] := UserStudio_NormalizeCardProviders(optPayload["llmCardProviders"])
        for k, v in optPayload {
            if (k = "llmApiKeys" || k = "llmBaseUrls" || k = "llmModels" || k = "llmCardProviders")
                continue
            merged[k] := v
        }
        cur["options"] := UserStudio_NormalizeNiumaOptions(merged)
    } else if (llmPayload.Count > 0) {
        merged := cur["options"].Clone()
        cur["options"] := UserStudio_MergePayloadLlmApiKeys(merged, Map(), llmPayload)
    }
    if payload.Has("llmApiKeys") && payload["llmApiKeys"] is Map {
        merged := cur["options"].Clone()
        cur["options"] := UserStudio_MergePayloadLlmApiKeys(merged, Map("llmApiKeys", payload["llmApiKeys"]), llmPayload)
    }
    if payload.Has("ttyd") && payload["ttyd"] is Map {
        for k, v in payload["ttyd"]
            cur["ttyd"][k] := v
    }
    cur["options"] := UserStudio_MergeLlmApiKeys(cur["options"], cur["llm"])
    cur := UserStudio_NormalizeDoc(cur)
    UserStudio_Save(cur)
    try UserStudio_WriteNiumaLlmSync(cur)
    catch {
    }
    UserStudio_ApplyPathsToGlobals(cur)
    try UserStudio_SyncTtydToIni(cur)
    catch {
    }
    return cur
}

UserStudio_GetTtydShell() {
    doc := UserStudio_Get()
    ttyd := doc.Has("ttyd") && doc["ttyd"] is Map ? doc["ttyd"] : Map()
    sh := Trim(String(ttyd.Get("shell", "cmd.exe")))
    if (sh = "")
        sh := "cmd.exe"
    if (StrLen(sh) > 1200)
        sh := "cmd.exe"
    return sh
}

UserStudio_GetTtydWorkDir() {
    doc := UserStudio_Get()
    ttyd := doc.Has("ttyd") && doc["ttyd"] is Map ? doc["ttyd"] : Map()
    wd := Trim(String(ttyd.Get("workDir", "")))
    if (wd != "") {
        try {
            if DirExist(wd)
                return wd
        } catch {
        }
    }
    if FuncExists("NiumaTtyd_WorkDir")
        return Func("NiumaTtyd_WorkDir").Call()
    return A_ScriptDir
}

UserStudio_SyncTtydToIni(doc) {
    global ConfigFile
    if !(doc is Map)
        return
    ttyd := doc.Has("ttyd") && doc["ttyd"] is Map ? doc["ttyd"] : Map()
    sh := Trim(String(ttyd.Get("shell", "cmd.exe")))
    if (sh = "")
        sh := "cmd.exe"
    cf := UserStudio_MainConfigFile()
    if (IsSet(ConfigFile) && ConfigFile != "")
        cf := ConfigFile
    try {
        IniWrite(sh, cf, "NiumaTtyd", "studio_cli_ttyd_shell")
        IniWrite(sh, cf, "NiumaTtyd", "studio_cli_shell")
        IniWrite(String(Integer(ttyd.Get("port", 7691))), cf, "NiumaTtyd", "studio_cli_port")
        wd := Trim(String(ttyd.Get("workDir", "")))
        IniWrite(wd, cf, "NiumaTtyd", "studio_cli_workdir")
    } catch {
    }
}

UserStudio_TtydPayloadForWeb() {
    doc := UserStudio_Get()
    ttyd := doc.Has("ttyd") && doc["ttyd"] is Map ? doc["ttyd"] : Map()
    port := Integer(ttyd.Get("port", 7691))
    if (port < 1024 || port > 65535)
        port := 7691
    baseUrl := "http://127.0.0.1:" . port . "/"
    if FuncExists("NiumaTtyd_BaseUrlForEngine")
        baseUrl := Func("NiumaTtyd_BaseUrlForEngine").Call("studio_cli")
    exeOk := false
    if FuncExists("NiumaTtyd_ExePath")
        exeOk := FileExist(Func("NiumaTtyd_ExePath").Call())
    httpOk := false
    if FuncExists("NiumaTtyd_IsHttpReadyOnPort")
        try httpOk := Func("NiumaTtyd_IsHttpReadyOnPort").Call(port, 400)
    return Map(
        "shell", ttyd.Get("shell", "cmd.exe"),
        "workDir", ttyd.Get("workDir", ""),
        "port", port,
        "baseUrl", baseUrl,
        "exeExists", exeOk,
        "httpReady", httpOk
    )
}

UserStudio_MaskApiKey(key) {
    k := Trim(String(key))
    if (k = "")
        return ""
    if (StrLen(k) <= 8)
        return "********"
    return SubStr(k, 1, 4) . "…" . SubStr(k, -4)
}

UserStudio_PathStatus(path) {
    p := Trim(String(path))
    if (p = "")
        return Map("set", false, "exists", false, "label", "未填写")
    ex := false
    try ex := !!FileExist(p)
    catch {
        ex := false
    }
    return Map("set", true, "exists", ex, "label", ex ? "已找到" : "路径无效")
}

UserStudio_BuildOverview() {
    global ConfigFile, CursorPath, AppearanceActivationMode, Language, ThemeMode
    doc := UserStudio_Get()
    paths := doc["paths"]
    llm := doc["llm"]
    modules := []
    modules.Push(Map("id", "config", "name", "设置中心 WebView", "on", true))
    modules.Push(Map("id", "search", "name", "搜索中心", "on", FuncExists("SCWV_Show")))
    modules.Push(Map("id", "hole", "name", "文本黑洞", "on", FuncExists("GDHO_IsDecoupledTopologyEnabled")))
    modules.Push(Map("id", "vk", "name", "虚拟键盘 KeyBinder", "on", FuncExists("VK_Show")))
    modules.Push(Map("id", "clipboard", "name", "剪贴板面板", "on", FuncExists("ShowClipboardManager")))
    modules.Push(Map("id", "pqp", "name", "Prompt Quick-Pad", "on", FuncExists("PromptQuickPad_Show")))
    act := "toolbar"
    try act := NormalizeAppearanceActivationMode(AppearanceActivationMode)
    catch {
    }
    return Map(
        "appName", "牛马 nmer",
        "ahkVersion", A_AhkVersion,
        "scriptDir", A_ScriptDir,
        "configFile", IsSet(ConfigFile) ? ConfigFile : "",
        "studioPath", UserStudio_Path(),
        "studioUpdatedAt", doc.Has("updatedAt") ? doc["updatedAt"] : "",
        "language", IsSet(Language) ? Language : "zh",
        "themeMode", IsSet(ThemeMode) ? ThemeMode : "dark",
        "activationMode", act,
        "cursorPathIni", IsSet(CursorPath) ? CursorPath : "",
        "pathStatus", Map(
            "cursor", UserStudio_PathStatus(paths.Get("cursor", "")),
            "autohotkey", UserStudio_PathStatus(paths.Get("autohotkey", "")),
            "everything", UserStudio_PathStatus(paths.Get("everything", "")),
            "python", UserStudio_PathStatus(paths.Get("python", ""))
        ),
        "llmProvider", llm.Get("provider", ""),
        "llmModel", llm.Get("model", ""),
        "llmKeyMasked", UserStudio_MaskApiKey(UserStudio_PickDisplayApiKey(doc)),
        "llmConfigured", Trim(String(UserStudio_PickDisplayApiKey(doc))) != "",
        "modules", modules
    )
}

UserStudio_PayloadForWeb() {
    doc := UserStudio_Get()
    llm := doc["llm"]
    opt := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
    keysOut := Map()
    if opt.Has("llmApiKeys") && opt["llmApiKeys"] is Map {
        for k, v in opt["llmApiKeys"] {
            pk := UserStudio_NormalizeLlmProvider(k)
            vk := UserStudio_NormalizeApiKey(v)
            if (vk != "")
                keysOut[pk] := vk
        }
    }
    prov := UserStudio_NormalizeLlmProvider(llm.Get("provider", "openai"))
    ak := UserStudio_NormalizeApiKey(llm.Get("apiKey", ""))
    if (ak = "" && keysOut.Has(prov))
        ak := keysOut[prov]
    optOut := opt.Clone()
    optOut["llmApiKeys"] := keysOut
    modelsOut := Map()
    if opt.Has("llmModels") && opt["llmModels"] is Map {
        for k, v in opt["llmModels"] {
            pk := UserStudio_NormalizeLlmProvider(k)
            mv := Trim(String(v))
            if (mv != "")
                modelsOut[pk] := mv
        }
    }
    optOut["llmModels"] := modelsOut
    if opt.Has("llmCardProviders") && opt["llmCardProviders"] is Array {
        cardProviders := []
        seen := Map()
        for _, p in opt["llmCardProviders"] {
            pv := UserStudio_NormalizeLlmProvider(p)
            if (pv != "" && !seen.Has(pv)) {
                seen[pv] := true
                cardProviders.Push(pv)
            }
        }
        optOut["llmCardProviders"] := cardProviders
    }
    return Map(
        "version", doc["version"],
        "updatedAt", doc["updatedAt"],
        "llm", Map(
            "provider", llm["provider"],
            "apiKey", ak,
            "baseUrl", llm["baseUrl"],
            "model", llm["model"]
        ),
        "paths", doc["paths"],
        "ttyd", UserStudio_TtydPayloadForWeb(),
        "options", optOut,
        "niumaContext", UserStudio_GetNiumaContext(),
        "overview", UserStudio_BuildOverview()
    )
}

UserStudio_BrowsePath(field, filterDesc := "可执行文件 (*.exe)") {
    field := Trim(String(field))
    doc := UserStudio_Get()
    paths := doc["paths"]
    start := ""
    if (field != "" && paths.Has(field))
        start := paths[field]
    if (start = "" || !FileExist(start))
        start := A_ScriptDir
    selected := ""
    try {
        if (field = "ttydWorkDir") {
        selected := FileSelect("D", start, "选择终端工作目录")
        if (selected = "")
            return ""
        return selected
    }
    if (field = "python")
            selected := FileSelect("1", start, "选择 Python", "Python (python.exe)")
        else if (field = "everything")
            selected := FileSelect("1", start, "选择 Everything", "Executable (*.exe)")
        else
            selected := FileSelect("1", start, "选择程序", filterDesc)
    } catch {
        selected := ""
    }
    if (selected = "")
        return ""
    try selected := UserStudio_NormalizeWinPath(selected)
    catch {
    }
    return selected
}

UserStudio_NormalizeApiKey(key) {
    if FuncExists("LlmApiPing_NormalizeApiKey")
        return Func("LlmApiPing_NormalizeApiKey").Call(key)
    if FuncExists("ConfigWebView_NormalizeApiKey")
        return Func("ConfigWebView_NormalizeApiKey").Call(key)
    return Trim(String(key))
}

UserStudio_TestLlmPing(llm, timeoutMs := 18000) {
    if FuncExists("ConfigWebView_TestMinimaxPing") && (llm is Map) {
        prov := UserStudio_NormalizeLlmProvider(llm.Get("provider", "openai"))
        if (prov = "minimax")
            return Func("ConfigWebView_TestMinimaxPing").Call(UserStudio_NormalizeApiKey(llm.Get("apiKey", "")), llm.Get("baseUrl", ""), llm.Get("model", ""), timeoutMs)
    }
    if FuncExists("LlmApiPing_Test")
        return Func("LlmApiPing_Test").Call(llm, timeoutMs)
    return Map("ok", false, "error", "LlmApiPing 模块未加载，请重载牛马主程序", "elapsedMs", 0)
}
