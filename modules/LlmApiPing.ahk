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
            return Map("baseUrl", "http://127.0.0.1:11434/v1", "model", "llama3.1:8b")
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
