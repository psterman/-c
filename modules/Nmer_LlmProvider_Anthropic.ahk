#Requires AutoHotkey v2.0

; Anthropic Messages API（claude、minimax 等）

Nmer_LlmAnthropic_Ping(cfg, timeoutMs := 18000) {
    llm := Nmer_LlmAnthropic_CfgToLlmMap(cfg)
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

Nmer_LlmAnthropic_Chat(cfg, messages, timeoutMs := 60000) {
    req := Nmer_LlmAnthropic_BuildHttpChat(cfg, Nmer_LlmAnthropic_FirstUserText(messages), 512, false)
    if !req.Get("ok", false)
        return Map("ok", false, "message", req.Get("message", "请求无效"), "text", "")
    if !FuncExists("LlmApiPing_HttpSync")
        return Map("ok", false, "message", "LlmApiPing 未加载", "text", "")
    try {
        r := LlmApiPing_HttpSync("POST", req["url"], req["headers"], req["body"], timeoutMs)
        if !r.Get("ok", false)
            return Map("ok", false, "message", Trim(String(r.Get("error", "HTTP 失败"))), "text", "")
        text := Nmer_LlmAnthropic_ParseText(r.Get("text", ""))
        return Map("ok", true, "message", "", "text", text)
    } catch as _e {
        return Map("ok", false, "message", _e.Message, "text", "")
    }
}

Nmer_LlmAnthropic_BuildHttpChat(cfg, userText, maxTokens := 4096, stream := false) {
    if !(cfg is Map) || Trim(String(userText)) = ""
        return Map("ok", false, "message", "请求无效")
    vendor := Nmer_LlmAnthropic_Vendor(cfg)
    model := Trim(String(cfg.Get("model", "")))
    base := Trim(String(cfg.Get("baseUrl", "")))
    key := Trim(String(cfg.Get("apiKey", "")))
    if (model = "" && FuncExists("UserStudio_LlmPresetFor"))
        model := Trim(String(UserStudio_LlmPresetFor(vendor).Get("model", "")))
    if (base = "" && FuncExists("UserStudio_LlmPresetFor"))
        base := Trim(String(UserStudio_LlmPresetFor(vendor).Get("baseUrl", "")))
    if (key = "")
        return Map("ok", false, "message", "请先填写 API Key")
    url := ""
    if (vendor = "minimax") && FuncExists("LlmApiPing_MinimaxAnthropicUrl")
        url := LlmApiPing_MinimaxAnthropicUrl(base)
    else if FuncExists("LlmApiPing_ClaudeMessagesUrl")
        url := LlmApiPing_ClaudeMessagesUrl(base)
    else
        url := RegExReplace(base, "/+$", "") . "/v1/messages"
    bodyMap := Map(
        "model", model,
        "max_tokens", Max(64, Integer(maxTokens)),
        "messages", [Map("role", "user", "content", String(userText))]
    )
    if stream
        bodyMap["stream"] := true
    hdr := Map(
        "Content-Type", "application/json",
        "anthropic-version", "2023-06-01"
    )
    if (vendor = "minimax") {
        hdr["Authorization"] := "Bearer " . key
        hdr["x-api-key"] := key
    } else
        hdr["x-api-key"] := key
    return Map(
        "ok", true,
        "url", url,
        "headers", hdr,
        "body", Jxon_Dump(bodyMap),
        "vendor", vendor,
        "protocolId", "anthropic"
    )
}

Nmer_LlmAnthropic_BuildHttpChatMessages(cfg, messages, maxTokens := 4096, stream := false) {
    if !(cfg is Map) || !(messages is Array) || messages.Length = 0
        return Map("ok", false, "message", "请求无效")
    vendor := Nmer_LlmAnthropic_Vendor(cfg)
    model := Trim(String(cfg.Get("model", "")))
    base := Trim(String(cfg.Get("baseUrl", "")))
    key := Trim(String(cfg.Get("apiKey", "")))
    if (model = "" && FuncExists("UserStudio_LlmPresetFor"))
        model := Trim(String(UserStudio_LlmPresetFor(vendor).Get("model", "")))
    if (base = "" && FuncExists("UserStudio_LlmPresetFor"))
        base := Trim(String(UserStudio_LlmPresetFor(vendor).Get("baseUrl", "")))
    if (key = "")
        return Map("ok", false, "message", "请先填写 API Key")
    url := ""
    if (vendor = "minimax") && FuncExists("LlmApiPing_MinimaxAnthropicUrl")
        url := LlmApiPing_MinimaxAnthropicUrl(base)
    else if FuncExists("LlmApiPing_ClaudeMessagesUrl")
        url := LlmApiPing_ClaudeMessagesUrl(base)
    else
        url := RegExReplace(base, "/+$", "") . "/v1/messages"
    system := ""
    anthMsgs := []
    for _, m in messages {
        if !(m is Map)
            continue
        role := Trim(String(m.Get("role", "")))
        content := m.Get("content", "")
        if (content is Map) || (content is Array)
            content := Jxon_Dump(content)
        content := String(content)
        if (role = "system") {
            system := (system != "" ? system . "`n" : "") . content
            continue
        }
        if (role != "user" && role != "assistant")
            role := "user"
        anthMsgs.Push(Map("role", role, "content", content))
    }
    if !anthMsgs.Length
        return Map("ok", false, "message", "消息为空")
    bodyMap := Map(
        "model", model,
        "max_tokens", Max(64, Integer(maxTokens)),
        "messages", anthMsgs
    )
    if (system != "")
        bodyMap["system"] := system
    if stream
        bodyMap["stream"] := true
    hdr := Map(
        "Content-Type", "application/json",
        "anthropic-version", "2023-06-01"
    )
    if (vendor = "minimax") {
        hdr["Authorization"] := "Bearer " . key
        hdr["x-api-key"] := key
    } else
        hdr["x-api-key"] := key
    return Map(
        "ok", true,
        "url", url,
        "headers", hdr,
        "body", Jxon_Dump(bodyMap),
        "vendor", vendor,
        "protocolId", "anthropic"
    )
}

Nmer_LlmAnthropic_ParseText(raw) {
    s := Trim(String(raw))
    if (s = "")
        return ""
    try {
        j := Jxon_Load(s)
        if (j is Map) {
            if j.Has("content") && j["content"] is Array {
                parts := []
                for _, block in j["content"] {
                    if (block is Map) && block.Has("text")
                        parts.Push(Trim(String(block["text"])))
                }
                if parts.Length
                    return Trim(parts.Join("`n"))
            }
        }
    } catch {
    }
    return s
}

Nmer_LlmAnthropic_FirstUserText(messages) {
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

Nmer_LlmAnthropic_Vendor(cfg) {
    vendor := FuncExists("UserStudio_NormalizeLlmProvider")
        ? UserStudio_NormalizeLlmProvider(cfg.Get("vendor", "claude"))
        : Trim(String(cfg.Get("vendor", "claude")))
    if (vendor = "minimax" || vendor = "claude")
        return vendor
    return "claude"
}

Nmer_LlmAnthropic_CfgToLlmMap(cfg) {
    if !(cfg is Map)
        return Map()
    vendor := Nmer_LlmAnthropic_Vendor(cfg)
    return Map(
        "provider", vendor,
        "apiKey", Trim(String(cfg.Get("apiKey", ""))),
        "baseUrl", Trim(String(cfg.Get("baseUrl", ""))),
        "model", Trim(String(cfg.Get("model", "")))
    )
}
