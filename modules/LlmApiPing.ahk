; LlmApiPing.ahk — 设置中心 / 智能定制 API 连通性测试（WinHttp 同步，不依赖 FloatingToolbar）

global LlmApiPing_MINIMAX_BASE_CN := "https://api.minimaxi.com/anthropic"
global LlmApiPing_MINIMAX_BASE_INTL := "https://api.minimax.io/anthropic"

LlmApiPing_StripSurroundingQuotes(key) {
    key := Trim(String(key))
    dq := Chr(34)
    loop {
        if (key = "")
            break
        changed := false
        c1 := SubStr(key, 1, 1)
        if (c1 = "'" || c1 = dq) {
            key := SubStr(key, 2)
            changed := true
        }
        if (key = "")
            break
        cL := SubStr(key, -1)
        if (cL = "'" || cL = dq) {
            key := SubStr(key, 1, -2)
            changed := true
        }
        if !changed
            break
    }
    return key
}

LlmApiPing_NormalizeApiKey(key) {
    key := Trim(String(key))
    if (key = "")
        return ""
    key := RegExReplace(key, "i)^\s*Bearer\s+", "")
    key := LlmApiPing_StripSurroundingQuotes(key)
    key := RegExReplace(key, "\s+", "")
    return key
}

LlmApiPing_NormalizeProvider(prov) {
    if FuncExists("UserStudio_NormalizeLlmProvider")
        return UserStudio_NormalizeLlmProvider(prov)
    prov := Trim(String(prov))
    if (prov = "anthropic")
        return "claude"
    if (prov = "codex")
        return "openai"
    return prov
}

LlmApiPing_BaseUrlMatchesProvider(prov, url) {
    if FuncExists("UserStudio_BaseUrlMatchesProvider")
        return UserStudio_BaseUrlMatchesProvider(prov, url)
    prov := LlmApiPing_NormalizeProvider(prov)
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
        default:
            return true
    }
}

LlmApiPing_PresetFor(prov) {
    if FuncExists("UserStudio_LlmPresetFor")
        return UserStudio_LlmPresetFor(prov)
    prov := LlmApiPing_NormalizeProvider(prov)
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
        case "ollama":
            return Map("baseUrl", "http://127.0.0.1:11434/v1", "model", "nemotron-3-super:cloud")
        default:
            return Map("baseUrl", "https://api.openai.com/v1", "model", "gpt-4o-mini")
    }
}

LlmApiPing_EncodeUri(s) {
    if FuncExists("UriEncode")
        return UriEncode(s)
    return s
}

LlmApiPing_HttpSync(method, url, headers, body, timeoutMs := 18000) {
    start := A_TickCount
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open(method, url, false)
        t := Max(3000, Integer(timeoutMs))
        whr.SetTimeouts(t, t, t, t)
        if (headers is Map) {
            for k, v in headers
                whr.SetRequestHeader(String(k), String(v))
        }
        whr.Send(String(body))
        status := Integer(whr.Status)
        text := ""
        try text := String(whr.ResponseText)
        ok := (status >= 200 && status < 300)
        return Map(
            "ok", ok,
            "status", status,
            "text", text,
            "error", ok ? "" : ("HTTP " . status),
            "elapsedMs", A_TickCount - start
        )
    } catch as e {
        errMsg := e.Message
        if RegExMatch(errMsg, "i)timeout|timed\s*out|超时")
            errMsg := "连接超时（约 " . Round(Max(3000, Integer(timeoutMs)) / 1000) . " 秒），请检查网络或 Base URL 是否与密钥区域一致"
        return Map("ok", false, "status", 0, "text", "", "error", errMsg, "elapsedMs", A_TickCount - start)
    }
}

LlmApiPing_MinimaxAnthropicUrl(base) {
    u := Trim(String(base))
    if (u = "")
        u := "https://api.minimaxi.com/anthropic"
    u := RegExReplace(u, "/+$", "")
    lu := StrLower(u)
    if InStr(lu, "/v1/messages") || InStr(lu, "/messages")
        return u
    if RegExMatch(lu, "/anthropic$")
        return u . "/v1/messages"
    if RegExMatch(lu, "/v1$")
        return u . "/messages"
    return u . "/v1/messages"
}

LlmApiPing_MinimaxOpenAIUrl(base) {
    u := Trim(String(base))
    if (u = "")
        return "https://api.minimax.io/v1/chat/completions"
    u := RegExReplace(u, "/+$", "")
    lu := StrLower(u)
    if InStr(lu, "/chat/completions")
        return u
    if RegExMatch(lu, "/anthropic$")
        return RegExReplace(u, "/anthropic$", "") . "/v1/chat/completions"
    if RegExMatch(lu, "/v1$") || RegExMatch(lu, "/v1beta$")
        return u . "/chat/completions"
    return u . "/v1/chat/completions"
}

LlmApiPing_FormatHttpError(r, prov := "") {
    err := r.Has("error") ? String(r["error"]) : "测试失败"
    if r.Has("text") && Trim(String(r["text"])) != "" {
        body := Trim(String(r["text"]))
        if RegExMatch(body, '"message"\s*:\s*"([^"]+)"', &m)
            err := m[1]
        else
            err .= " — " . SubStr(body, 1, 200)
    }
    if (prov = "kimi") {
        if RegExMatch(err, "i)404|not\s*found")
            err := "接口 404：Base URL 须为 https://api.moonshot.cn/v1（国内）或 https://api.moonshot.ai/v1（国际），完整路径为 …/v1/chat/completions；勿漏 /v1"
        else if RegExMatch(err, "i)authentication|api[_ ]?key|unauthorized|401")
            err := "Kimi 鉴权失败：国内密钥→api.moonshot.cn/v1（platform.moonshot.cn）；国际密钥→api.moonshot.ai/v1（platform.kimi.ai），二者不可混用"
        else if RegExMatch(err, "i)temperature")
            err := "Kimi K2.6 模型要求 temperature=1（或不传 temperature），测试请求已去掉 0.1。请重载主程序后再测。"
        else if RegExMatch(err, "i)model|invalid_request|400|403|permission|not\s*found|不存在|未开通|无权限")
            err .= "。kimi-k2.6 需账号在 platform.moonshot.cn（国内）或 platform.kimi.ai（国际）已开通且有余额；若仅 moonshot-v1-8k 可用，请在卡片里改选 v1 模型。可用 GET …/v1/models 查看本 Key 实际可用模型列表。"
    } else if (prov = "openai") {
        if RegExMatch(err, "i)429|too many requests|rate.?limit|请求过于频繁")
            err := "HTTP 429（限流）：通常不是密钥错误，而是短时间内请求过多（RPM/TPM）。请等待 30～60 秒后再测；避免连续切换模型后立刻连点「测试 API」。每次测试最多向官方发 2 次请求，易触发免费档或低配额账号的限流。可到 platform.openai.com 查看 Usage / Billing。"
        else if RegExMatch(err, "i)401|invalid.*api|incorrect.*api|authentication")
            err := "OpenAI 鉴权失败：请确认 sk- 密钥有效、账户有余额；官方地址 https://api.openai.com/v1。Azure OpenAI 请用手动 Base URL 并勾选对应选项。"
        else if RegExMatch(err, "i)model_not_found|model.*not exist|does not exist|invalid_model")
            err .= "。模型名可能不可用或账号未开通该模型，请换 gpt-4o-mini / gpt-4.1-mini 等后重试。"
    }
    return err
}

LlmApiPing_NormalizeMoonshotBase(base) {
    u := Trim(String(base))
    if (u = "")
        return u
    u := RegExReplace(u, "/+$", "")
    if RegExMatch(u, "i)^https?://api\.moonshot\.(cn|ai)$")
        return u . "/v1"
    return u
}

LlmApiPing_OpenAIChatUrl(base) {
    u := Trim(String(base))
    if (u = "")
        u := "https://api.openai.com/v1"
    if RegExMatch(u, "i)moonshot\.(cn|ai)")
        u := LlmApiPing_NormalizeMoonshotBase(u)
    u := RegExReplace(u, "/+$", "")
    if InStr(StrLower(u), "/chat/completions")
        return u
    return u . "/chat/completions"
}

; 命令面板 / 宿主直连：OpenAI 兼容 chat/completions 请求体（Kimi 勿传 temperature=0.7）
LlmApiPing_BuildChatBody(prov, model, userText, maxTokens := 4096) {
    prov := LlmApiPing_NormalizeProvider(prov)
    model := Trim(String(model))
    if (model = "") {
        try {
            pre := LlmApiPing_PresetFor(prov)
            model := Trim(String(pre.Get("model", "")))
        } catch {
        }
    }
    tok := Max(64, Integer(maxTokens))
    m := Map(
        "model", model,
        "messages", [Map("role", "user", "content", String(userText))]
    )
    if (prov = "kimi") {
        if RegExMatch(model, "i)^kimi-k2")
            m["max_completion_tokens"] := tok, m["temperature"] := 1
        else
            m["max_tokens"] := tok
    } else {
        m["max_tokens"] := tok
        if (prov != "deepseek")
            m["temperature"] := 0.7
    }
    return Jxon_Dump(m)
}

LlmApiPing_KimiChatBodies(model, userText, maxTokens := 4096) {
    mod := Trim(String(model))
    if (mod = "")
        mod := "kimi-k2.6"
    tok := Max(64, Integer(maxTokens))
    q := String(userText)
    pingK26Lite := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", q)],
        "max_completion_tokens", tok
    ))
    pingK26Enabled := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", q)],
        "max_completion_tokens", tok,
        "thinking", Map("type", "enabled")
    ))
    pingK26 := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", q)],
        "max_completion_tokens", tok,
        "thinking", Map("type", "disabled")
    ))
    pingV1 := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", q)],
        "max_tokens", tok
    ))
    if RegExMatch(mod, "i)^kimi-k2\.6")
        return [pingK26Lite, pingK26Enabled, pingK26, pingV1]
    if RegExMatch(mod, "i)^moonshot-v1")
        return [pingV1]
    return [pingK26Lite, pingV1, pingK26Enabled, pingK26]
}

LlmApiPing_KimiPingBodies(mod) {
    mod := Trim(String(mod))
    tok := 64
    pingK26Lite := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", "ping")],
        "max_completion_tokens", tok
    ))
    pingK26Enabled := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", "ping")],
        "max_completion_tokens", tok,
        "thinking", Map("type", "enabled")
    ))
    pingK26 := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", "ping")],
        "max_completion_tokens", tok,
        "thinking", Map("type", "disabled")
    ))
    pingV1 := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", "ping")],
        "max_tokens", tok
    ))
    if RegExMatch(mod, "i)^kimi-k2\.6")
        return [pingK26Lite, pingK26Enabled, pingK26, pingV1]
    if RegExMatch(mod, "i)thinking")
        return [pingV1, pingK26Lite]
    if RegExMatch(mod, "i)^moonshot-v1")
        return [pingV1]
    return [pingK26Lite, pingV1, pingK26Enabled, pingK26]
}

LlmApiPing_ClaudeMessagesUrl(base) {
    u := Trim(String(base))
    if (u = "")
        u := "https://api.anthropic.com"
    u := RegExReplace(u, "/+$", "")
    if InStr(StrLower(u), "/v1/messages")
        return u
    return u . "/v1/messages"
}

LlmApiPing_GeminiGenerateUrl(base, model, apiKey) {
    u := Trim(String(base))
    if (u = "")
        u := "https://generativelanguage.googleapis.com/v1beta"
    u := RegExReplace(u, "/+$", "")
    m := Trim(String(model))
    if (m = "")
        m := "gemini-2.5-flash"
    encKey := LlmApiPing_EncodeUri(apiKey)
    if InStr(StrLower(u), ":generatecontent")
        return u . "?key=" . encKey
    return u . "/models/" . m . ":generateContent?key=" . encKey
}

LlmApiPing_ResolveFromPayload(payload) {
    if !(payload is Map)
        return Map()
    llm := payload
    if (payload.Has("llm") && payload["llm"] is Map)
        llm := payload["llm"]
    if !(llm is Map)
        return Map()
    prov := LlmApiPing_NormalizeProvider(llm.Get("provider", "openai"))
    key := LlmApiPing_NormalizeApiKey(llm.Get("apiKey", ""))
    if (key = "" && payload.Has("options") && payload["options"] is Map) {
        opt := payload["options"]
        if (opt.Has("llmApiKeys") && opt["llmApiKeys"] is Map) {
            keys := opt["llmApiKeys"]
            if keys.Has(prov)
                key := LlmApiPing_NormalizeApiKey(keys[prov])
        }
    }
    llm["provider"] := prov
    llm["apiKey"] := key
    return llm
}

LlmApiPing_TestKimi(key, base, model, timeoutMs) {
    t0 := A_TickCount
    headers := Map("Content-Type", "application/json", "Authorization", "Bearer " . key)
    bases := []
    b0 := LlmApiPing_NormalizeMoonshotBase(Trim(String(base)))
    if (b0 != "")
        bases.Push(b0)
    if !bases.Length {
        bases.Push("https://api.moonshot.cn/v1")
        bases.Push("https://api.moonshot.ai/v1")
    } else if RegExMatch(b0, "i)moonshot\.cn") {
        if !ArrayHasValue(bases, "https://api.moonshot.cn/v1")
            bases.Push("https://api.moonshot.cn/v1")
    } else if RegExMatch(b0, "i)moonshot\.ai") {
        if !ArrayHasValue(bases, "https://api.moonshot.ai/v1")
            bases.Push("https://api.moonshot.ai/v1")
    }
    m0 := Trim(String(model))
    if (m0 = "")
        m0 := "kimi-k2.6"
    modelExplicit := Trim(String(model)) != ""
    models := [m0]
    ; 仅在未显式指定模型时才尝试备用模型，避免“自动切到 moonshot-v1-8k”
    if !modelExplicit {
        if !ArrayHasValue(models, "kimi-k2.6")
            models.Push("kimi-k2.6")
        if !ArrayHasValue(models, "moonshot-v1-8k")
            models.Push("moonshot-v1-8k")
    }
    lastErr := "测试失败"
    for _, bu in bases {
        bu := LlmApiPing_NormalizeMoonshotBase(bu)
        for _, mod in models {
            for _, body in LlmApiPing_KimiPingBodies(mod) {
                r := LlmApiPing_HttpSync("POST", LlmApiPing_OpenAIChatUrl(bu), headers, body, timeoutMs)
                if r["ok"]
                    return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0, "baseUrl", bu, "model", mod)
                lastErr := LlmApiPing_FormatHttpError(r, "kimi")
            }
        }
    }
    return Map("ok", false, "error", lastErr, "elapsedMs", A_TickCount - t0)
}

ArrayHasValue(arr, val) {
    for item in arr
        if (item = val)
            return true
    return false
}

LlmApiPing_OllamaRootUrl(base) {
    root := Trim(String(base))
    if (root = "")
        root := "http://127.0.0.1:11434/v1"
    root := RegExReplace(root, "/+$", "")
    if RegExMatch(root, "i)/v1$")
        root := SubStr(root, 1, -3)
    return root
}

; Ollama 本地服务：先 GET /api/tags，再可选 POST /v1/chat/completions
LlmApiPing_TestOllama(base, model, timeoutMs := 18000) {
    t0 := A_TickCount
    root := LlmApiPing_OllamaRootUrl(base)
    r := LlmApiPing_HttpSync("GET", root . "/api/tags", Map(), "", timeoutMs)
    if !r["ok"] {
        err := Trim(String(r["error"]))
        if (err = "")
            err := "无法连接"
        return Map(
            "ok", false,
            "error", "未检测到 Ollama 服务（" . err . "）。请从开始菜单或托盘启动 Ollama；或在终端执行 ollama serve",
            "elapsedMs", A_TickCount - t0
        )
    }
    mod := Trim(String(model))
    if (mod = "" || !RegExMatch(mod, "i):cloud$"))
        mod := "nemotron-3-super:cloud"
    pingBody := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", "ping")],
        "stream", false,
        "max_tokens", 8
    ))
    r2 := LlmApiPing_HttpSync("POST", root . "/v1/chat/completions", Map("Content-Type", "application/json"), pingBody, timeoutMs)
    if r2["ok"]
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0)
    err2 := LlmApiPing_FormatHttpError(r2, "ollama")
    if RegExMatch(err2, "i)model|not found|404")
        err2 .= "。请在 Ollama 客户端添加云模型「" . mod . "」（:cloud 后缀，无需本机 pull 大文件）"
    return Map("ok", false, "error", err2, "elapsedMs", A_TickCount - t0)
}

LlmApiPing_InetAddrV4(host) {
    host := Trim(String(host))
    if (host = "localhost")
        host := "127.0.0.1"
    if !RegExMatch(host, "^\d{1,3}(\.\d{1,3}){3}$")
        return 0
    addr := DllCall("ws2_32\inet_addr", "AStr", host, "UInt")
    return (addr = 0xFFFFFFFF) ? 0 : addr
}

LlmApiPing_TcpPortOpen(host, port, timeoutMs := 2500) {
    static wsaReady := false
    if !wsaReady {
        wsaData := Buffer(400, 0)
        if DllCall("ws2_32\WSAStartup", "UShort", 0x0202, "Ptr", wsaData, "Int")
            return false
        wsaReady := true
    }
    host := Trim(String(host))
    port := Integer(port)
    if (host = "" || port < 1 || port > 65535)
        return false
    ip := LlmApiPing_InetAddrV4(host)
    if !ip
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

LlmApiPing_ParseOpenClawEndpoint(base) {
    host := "127.0.0.1"
    port := 18789
    base := Trim(String(base))
    if (base = "")
        return Map("host", host, "port", port)
    raw := base
    if !RegExMatch(raw, "i)^[a-z]+://")
        raw := "http://" . raw
    try {
        if RegExMatch(raw, "i)^[a-z]+://([^/:]+)(?::(\d+))?", &m) {
            if (m[1] != "")
                host := m[1]
            if (m[2] != "")
                port := Integer(m[2])
        }
    } catch {
    }
    if (port < 1 || port > 65535)
        port := 18789
    return Map("host", host, "port", port)
}

LlmApiPing_OpenClawGatewayStatusOk(timeoutMs := 9000) {
    if !FuncExists("UserStudio_FindOpenClawCliExe")
        return false
    exe := UserStudio_FindOpenClawCliExe()
    if (exe = "")
        return false
    out := A_Temp . "\nmer_openclaw_gw_status.txt"
    try FileDelete(out)
    ; 整条子命令必须包在一对引号内，否则 gateway status 不会传给 openclaw.cmd（约 60ms 空跑）
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

LlmApiPing_TestOpenClaw(base, key, timeoutMs := 8000) {
    key := LlmApiPing_NormalizeApiKey(key)
    if (key = "")
        return Map("ok", false, "error", "缺少 Gateway Token", "elapsedMs", 0)
    ep := LlmApiPing_ParseOpenClawEndpoint(base)
    host := ep.Get("host", "127.0.0.1")
    port := Integer(ep.Get("port", 18789))
    t0 := A_TickCount
    tcpMs := Min(Max(800, Integer(timeoutMs)), 3000)
    ; CLI 含 WebSocket 探活最准；TCP 作快速兜底（Gateway 根路径 HTTP 常挂起）
    if LlmApiPing_OpenClawGatewayStatusOk(Min(Max(6000, Integer(timeoutMs)), 15000))
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0)
    if LlmApiPing_TcpPortOpen(host, port, tcpMs)
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0)
    return Map(
        "ok", false,
        "error", "无法连接本机 OpenClaw Gateway（" . host . ":" . port . "）。请执行 openclaw gateway restart 后重试。",
        "elapsedMs", A_TickCount - t0
    )
}

LlmApiPing_Test(llm, timeoutMs := 18000) {
    if !(llm is Map)
        return Map("ok", false, "error", "配置无效", "elapsedMs", 0)
    prov := LlmApiPing_NormalizeProvider(llm.Get("provider", "openai"))
    key := LlmApiPing_NormalizeApiKey(llm.Get("apiKey", ""))
    base := Trim(String(llm.Get("baseUrl", "")))
    model := Trim(String(llm.Get("model", "")))
    pre := LlmApiPing_PresetFor(prov)
    if (base = "")
        base := pre.Get("baseUrl", "")
    if !LlmApiPing_BaseUrlMatchesProvider(prov, base)
        base := pre.Get("baseUrl", "")
    if (model = "")
        model := pre.Get("model", "")
    if (prov != "ollama" && key = "")
        return Map("ok", false, "error", "请先填写 API Key", "elapsedMs", 0)
    if (prov = "ollama")
        return LlmApiPing_TestOllama(base, model, timeoutMs)
    if (prov = "openclaw")
        return LlmApiPing_TestOpenClaw(base, key, Min(timeoutMs, 12000))
    pingAnth := Jxon_Dump(Map("model", model, "max_tokens", 8, "messages", [Map("role", "user", "content", "ping")]))
    pingOpenAI := Jxon_Dump(Map("model", model, "messages", [Map("role", "user", "content", "ping")], "max_tokens", 8, "temperature", 0.1))
    pingOpenAINew := Jxon_Dump(Map("model", model, "messages", [Map("role", "user", "content", "ping")], "max_completion_tokens", 16, "temperature", 0.1))
    t0 := A_TickCount
    if (prov = "minimax") {
        r := LlmApiPing_HttpSync("POST", LlmApiPing_MinimaxAnthropicUrl(base), Map(
            "Content-Type", "application/json",
            "Authorization", "Bearer " . key,
            "anthropic-version", "2023-06-01"
        ), pingAnth, timeoutMs)
        if r["ok"]
            return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0)
        r2 := LlmApiPing_HttpSync("POST", LlmApiPing_MinimaxOpenAIUrl(base), Map(
            "Content-Type", "application/json",
            "Authorization", "Bearer " . key
        ), pingOpenAI, timeoutMs)
        if r2["ok"]
            return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0)
        err := r2.Has("error") ? r2["error"] : "测试失败"
        if r2.Has("text") && Trim(String(r2["text"])) != ""
            err .= " " . SubStr(Trim(String(r2["text"])), 1, 120)
        return Map("ok", false, "error", err, "elapsedMs", A_TickCount - t0)
    }
    if (prov = "claude") {
        r := LlmApiPing_HttpSync("POST", LlmApiPing_ClaudeMessagesUrl(base), Map(
            "Content-Type", "application/json",
            "x-api-key", key,
            "anthropic-version", "2023-06-01"
        ), pingAnth, timeoutMs)
        return Map("ok", !!r["ok"], "error", r["ok"] ? "" : r["error"], "elapsedMs", A_TickCount - t0)
    }
    if (prov = "gemini") {
        r := LlmApiPing_HttpSync("POST", LlmApiPing_GeminiGenerateUrl(base, model, key), Map("Content-Type", "application/json"),
            Jxon_Dump(Map("contents", [Map("role", "user", "parts", [Map("text", "ping")])], "generationConfig", Map("maxOutputTokens", 8))), timeoutMs)
        err := r["ok"] ? "" : LlmApiPing_FormatHttpError(r, prov)
        return Map("ok", !!r["ok"], "error", err, "elapsedMs", A_TickCount - t0)
    }
    if (prov = "kimi")
        return LlmApiPing_TestKimi(key, base, model, timeoutMs)
    headers := Map("Content-Type", "application/json")
    if (key != "")
        headers["Authorization"] := "Bearer " . key
    bodies := [pingOpenAI]
    if (prov = "openai")
        bodies.InsertAt(1, pingOpenAINew)
    lastErr := ""
    for _, body in bodies {
        r := LlmApiPing_HttpSync("POST", LlmApiPing_OpenAIChatUrl(base), headers, body, timeoutMs)
        if r["ok"]
            return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0)
        lastErr := LlmApiPing_FormatHttpError(r, prov = "openai" ? "openai" : prov)
        ; 429/401 等再发第二种请求体会加倍消耗配额，易连续 429；仅对可能「参数不兼容」的 400 再尝试
        st := r.Has("status") ? Integer(r["status"]) : 0
        if (prov = "openai" && (st = 429 || st = 401 || st = 402 || st = 403))
            break
    }
    return Map("ok", false, "error", lastErr, "elapsedMs", A_TickCount - t0)
}
