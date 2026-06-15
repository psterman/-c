#Requires AutoHotkey v2.0

; Google Gemini GenerateContent API

Nmer_LlmGemini_Ping(cfg, timeoutMs := 18000) {
    llm := Nmer_LlmGemini_CfgToLlmMap(cfg)
    if !(llm is Map)
        return Map("ok", false, "message", "配置无效", "elapsedMs", 0)
    if !FuncExists("LlmApiPing_TestHttpDirect")
        return Map("ok", false, "message", "LlmApiPing 未加载", "elapsedMs", 0)
    try {
        r := LlmApiPing_TestHttpDirect(llm, timeoutMs)
        return FuncExists("Nmer_Llm_PingResultFromDirect")
            ? Nmer_Llm_PingResultFromDirect(r, cfg)
            : Map("ok", !!r.Get("ok", false), "message", Trim(String(r.Get("error", ""))), "elapsedMs", Integer(r.Get("elapsedMs", 0)))
    } catch as _e {
        return Map("ok", false, "message", _e.Message, "elapsedMs", 0)
    }
}

Nmer_LlmGemini_Chat(cfg, messages, timeoutMs := 60000) {
    req := Nmer_LlmGemini_BuildHttpChat(cfg, Nmer_LlmGemini_FirstUserText(messages), 512)
    if !req.Get("ok", false)
        return Map("ok", false, "message", req.Get("message", "请求无效"), "text", "")
    if !FuncExists("LlmApiPing_HttpSync")
        return Map("ok", false, "message", "LlmApiPing 未加载", "text", "")
    try {
        r := LlmApiPing_HttpSync("POST", req["url"], req["headers"], req["body"], timeoutMs)
        if !r.Get("ok", false)
            return Map("ok", false, "message", Trim(String(r.Get("error", "HTTP 失败"))), "text", "")
        text := Nmer_LlmGemini_ParseText(r.Get("text", ""))
        return Map("ok", true, "message", "", "text", text)
    } catch as _e {
        return Map("ok", false, "message", _e.Message, "text", "")
    }
}

Nmer_LlmGemini_BuildHttpChat(cfg, userText, maxTokens := 4096) {
    if !(cfg is Map) || Trim(String(userText)) = ""
        return Map("ok", false, "message", "请求无效")
    model := Trim(String(cfg.Get("model", "")))
    base := Trim(String(cfg.Get("baseUrl", "")))
    key := Trim(String(cfg.Get("apiKey", "")))
    if FuncExists("UserStudio_LlmPresetFor") {
        pre := UserStudio_LlmPresetFor("gemini")
        if (model = "")
            model := Trim(String(pre.Get("model", "")))
        if (base = "")
            base := Trim(String(pre.Get("baseUrl", "")))
    }
    if (key = "")
        return Map("ok", false, "message", "请先填写 API Key")
    url := FuncExists("LlmApiPing_GeminiGenerateUrl")
        ? LlmApiPing_GeminiGenerateUrl(base, model, key)
        : (RegExReplace(base, "/+$", "") . "/models/" . model . ":generateContent?key=" . key)
    body := Jxon_Dump(Map(
        "contents", [Map("role", "user", "parts", [Map("text", String(userText))])],
        "generationConfig", Map("maxOutputTokens", Max(64, Integer(maxTokens)))
    ))
    return Map(
        "ok", true,
        "url", url,
        "headers", Map("Content-Type", "application/json"),
        "body", body,
        "vendor", "gemini",
        "protocolId", "gemini"
    )
}

Nmer_LlmGemini_BuildHttpChatMessages(cfg, messages, maxTokens := 4096) {
    if !(cfg is Map) || !(messages is Array) || messages.Length = 0
        return Map("ok", false, "message", "请求无效")
    model := Trim(String(cfg.Get("model", "")))
    base := Trim(String(cfg.Get("baseUrl", "")))
    key := Trim(String(cfg.Get("apiKey", "")))
    if FuncExists("UserStudio_LlmPresetFor") {
        pre := UserStudio_LlmPresetFor("gemini")
        if (model = "")
            model := Trim(String(pre.Get("model", "")))
        if (base = "")
            base := Trim(String(pre.Get("baseUrl", "")))
    }
    if (key = "")
        return Map("ok", false, "message", "请先填写 API Key")
    url := FuncExists("LlmApiPing_GeminiGenerateUrl")
        ? LlmApiPing_GeminiGenerateUrl(base, model, key)
        : (RegExReplace(base, "/+$", "") . "/models/" . model . ":generateContent?key=" . key)
    contents := []
    for _, m in messages {
        if !(m is Map)
            continue
        role := Trim(String(m.Get("role", "user")))
        content := m.Get("content", "")
        if (content is Map) || (content is Array)
            content := Jxon_Dump(content)
        content := String(content)
        if (role = "system") {
            contents.Push(Map("role", "user", "parts", [Map("text", content)]))
            continue
        }
        gemRole := (role = "assistant" || role = "model") ? "model" : "user"
        contents.Push(Map("role", gemRole, "parts", [Map("text", content)]))
    }
    if !contents.Length
        return Map("ok", false, "message", "消息为空")
    body := Jxon_Dump(Map(
        "contents", contents,
        "generationConfig", Map("maxOutputTokens", Max(64, Integer(maxTokens)))
    ))
    return Map(
        "ok", true,
        "url", url,
        "headers", Map("Content-Type", "application/json"),
        "body", body,
        "vendor", "gemini",
        "protocolId", "gemini"
    )
}

Nmer_LlmGemini_ParseText(raw) {
    s := Trim(String(raw))
    if (s = "")
        return ""
    try {
        j := Jxon_Load(s)
        if (j is Map) && j.Has("candidates") && j["candidates"] is Array && j["candidates"].Length > 0 {
            c0 := j["candidates"][1]
            if (c0 is Map) && c0.Has("content") && c0["content"] is Map {
                parts := c0["content"].Get("parts", [])
                if (parts is Array) {
                    out := []
                    for _, p in parts {
                        if (p is Map) && p.Has("text")
                            out.Push(Trim(String(p["text"])))
                    }
                    if out.Length
                        return Trim(out.Join("`n"))
                }
            }
        }
    } catch {
    }
    return s
}

Nmer_LlmGemini_FirstUserText(messages) {
    if !(messages is Array)
        return ""
    for _, m in messages {
        if (m is Map) && Trim(String(m.Get("role", ""))) = "user"
            return Trim(String(m.Get("content", "")))
    }
    if messages.Length > 0 && (messages[1] is Map)
        return Trim(String(messages[1].Get("content", "")))
    return ""
}

Nmer_LlmGemini_CfgToLlmMap(cfg) {
    if !(cfg is Map)
        return Map()
    return Map(
        "provider", "gemini",
        "apiKey", Trim(String(cfg.Get("apiKey", ""))),
        "baseUrl", Trim(String(cfg.Get("baseUrl", ""))),
        "model", Trim(String(cfg.Get("model", "")))
    )
}
