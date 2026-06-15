#Requires AutoHotkey v2.0

; OpenAI 协议族 adapter（vendor profile → LlmApiPing）

Nmer_LlmOai_Ping(cfg, timeoutMs := 18000) {
    llm := Nmer_LlmOai_CfgToLlmMap(cfg)
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

Nmer_LlmOai_Chat(cfg, messages, timeoutMs := 60000) {
    if !(cfg is Map) || !(messages is Array) || messages.Length = 0
        return Map("ok", false, "message", "请求无效", "text", "")
    llm := Nmer_LlmOai_CfgToLlmMap(cfg)
    vendor := FuncExists("UserStudio_NormalizeLlmProvider")
        ? UserStudio_NormalizeLlmProvider(cfg.Get("vendor", "openai"))
        : Trim(String(cfg.Get("vendor", "openai")))
    model := Trim(String(cfg.Get("model", "")))
    base := Trim(String(cfg.Get("baseUrl", "")))
    key := Trim(String(cfg.Get("apiKey", "")))
    if (model = "" && FuncExists("UserStudio_LlmPresetFor")) {
        pre := UserStudio_LlmPresetFor(vendor)
        model := Trim(String(pre.Get("model", "")))
        if (base = "")
            base := Trim(String(pre.Get("baseUrl", "")))
    }
    if (key = "")
        return Map("ok", false, "message", "请先填写 API Key", "text", "")
    body := Jxon_Dump(Map("model", model, "messages", messages, "stream", false, "max_tokens", 512))
    url := RegExReplace(base, "/+$", "") . "/chat/completions"
    hdr := Map("Content-Type", "application/json", "Authorization", "Bearer " . key)
    if !FuncExists("LlmApiPing_HttpSync")
        return Map("ok", false, "message", "LlmApiPing 未加载", "text", "")
    try {
        r := LlmApiPing_HttpSync("POST", url, hdr, body, timeoutMs)
        if !r.Get("ok", false)
            return Map("ok", false, "message", Trim(String(r.Get("error", "HTTP 失败"))), "text", "")
        text := Nmer_LlmOai_ParseChatText(r.Get("text", ""))
        return Map("ok", true, "message", "", "text", text)
    } catch as _e {
        return Map("ok", false, "message", _e.Message, "text", "")
    }
}

Nmer_LlmOai_ParseChatText(raw) {
    s := Trim(String(raw))
    if (s = "")
        return ""
    try {
        j := Jxon_Load(s)
        if (j is Map) {
            if j.Has("choices") && j["choices"] is Array && j["choices"].Length > 0 {
                c0 := j["choices"][1]
                if (c0 is Map) {
                    if c0.Has("message") && c0["message"] is Map
                        return Trim(String(c0["message"].Get("content", "")))
                    return Trim(String(c0.Get("text", "")))
                }
            }
        }
    } catch {
    }
    return s
}

Nmer_LlmOai_CfgToLlmMap(cfg) {
    if !(cfg is Map)
        return Map()
    vendor := FuncExists("UserStudio_NormalizeLlmProvider")
        ? UserStudio_NormalizeLlmProvider(cfg.Get("vendor", "openai"))
        : Trim(String(cfg.Get("vendor", "openai")))
    return Map(
        "provider", vendor,
        "apiKey", Trim(String(cfg.Get("apiKey", ""))),
        "baseUrl", Trim(String(cfg.Get("baseUrl", ""))),
        "model", Trim(String(cfg.Get("model", "")))
    )
}

Nmer_LlmOai_BuildHttpChat(cfg, userText, maxTokens := 4096, stream := false) {
    if !(cfg is Map) || Trim(String(userText)) = ""
        return Map("ok", false, "message", "请求无效")
    llm := Nmer_LlmOai_CfgToLlmMap(cfg)
    vendor := llm.Get("provider", "openai")
    model := Trim(String(llm.Get("model", "")))
    base := Trim(String(llm.Get("baseUrl", "")))
    key := Trim(String(llm.Get("apiKey", "")))
    if (model = "" && FuncExists("UserStudio_LlmPresetFor"))
        model := Trim(String(UserStudio_LlmPresetFor(vendor).Get("model", "")))
    if (base = "" && FuncExists("UserStudio_LlmPresetFor"))
        base := Trim(String(UserStudio_LlmPresetFor(vendor).Get("baseUrl", "")))
    if (vendor != "ollama" && key = "")
        return Map("ok", false, "message", "请先填写 API Key")
    url := FuncExists("LlmApiPing_OpenAIChatUrl")
        ? LlmApiPing_OpenAIChatUrl(base)
        : (RegExReplace(base, "/+$", "") . "/chat/completions")
    body := ""
    if FuncExists("LlmApiPing_BuildChatBody")
        body := LlmApiPing_BuildChatBody(vendor, model, userText, maxTokens)
    else
        body := Jxon_Dump(Map("model", model, "messages", [Map("role", "user", "content", String(userText))], "max_tokens", Max(64, Integer(maxTokens))))
    hdr := Map("Content-Type", "application/json")
    if (key != "")
        hdr["Authorization"] := "Bearer " . key
    if stream {
        try {
            j := Jxon_Load(body)
            if (j is Map) {
                j["stream"] := true
                body := Jxon_Dump(j)
            }
        } catch {
        }
    }
    return Map("ok", true, "url", url, "headers", hdr, "body", body, "vendor", vendor, "protocolId", "openai")
}

Nmer_LlmOai_BuildHttpChatMessages(cfg, messages, maxTokens := 4096, stream := false) {
    if !(cfg is Map) || !(messages is Array) || messages.Length = 0
        return Map("ok", false, "message", "请求无效")
    llm := Nmer_LlmOai_CfgToLlmMap(cfg)
    vendor := llm.Get("provider", "openai")
    model := Trim(String(llm.Get("model", "")))
    base := Trim(String(llm.Get("baseUrl", "")))
    key := Trim(String(llm.Get("apiKey", "")))
    if (model = "" && FuncExists("UserStudio_LlmPresetFor"))
        model := Trim(String(UserStudio_LlmPresetFor(vendor).Get("model", "")))
    if (base = "" && FuncExists("UserStudio_LlmPresetFor"))
        base := Trim(String(UserStudio_LlmPresetFor(vendor).Get("baseUrl", "")))
    if (vendor != "ollama" && key = "")
        return Map("ok", false, "message", "请先填写 API Key")
    url := FuncExists("LlmApiPing_OpenAIChatUrl")
        ? LlmApiPing_OpenAIChatUrl(base)
        : (RegExReplace(base, "/+$", "") . "/chat/completions")
    oaMsgs := []
    for _, m in messages {
        if !(m is Map)
            continue
        role := Trim(String(m.Get("role", "user")))
        content := m.Get("content", "")
        if (content is Map) || (content is Array)
            content := Jxon_Dump(content)
        oaMsgs.Push(Map("role", role, "content", String(content)))
    }
    if !oaMsgs.Length
        return Map("ok", false, "message", "消息为空")
    bodyMap := Map("model", model, "messages", oaMsgs, "max_tokens", Max(64, Integer(maxTokens)))
    if stream
        bodyMap["stream"] := true
    if (vendor = "ollama")
        bodyMap["stream"] := !!stream
    body := ""
    if FuncExists("LlmApiPing_BuildChatBody") && oaMsgs.Length = 1 && oaMsgs[1].Get("role", "") = "user" {
        body := LlmApiPing_BuildChatBody(vendor, model, oaMsgs[1].Get("content", ""), maxTokens)
        try {
            j := Jxon_Load(body)
            if (j is Map) {
                j["messages"] := oaMsgs
                if stream
                    j["stream"] := true
                body := Jxon_Dump(j)
            }
        } catch {
            body := Jxon_Dump(bodyMap)
        }
    } else
        body := Jxon_Dump(bodyMap)
    hdr := Map("Content-Type", "application/json")
    if (key != "")
        hdr["Authorization"] := "Bearer " . key
    return Map("ok", true, "url", url, "headers", hdr, "body", body, "vendor", vendor, "protocolId", "openai")
}
