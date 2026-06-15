#Requires AutoHotkey v2.0

; Ollama 本地 adapter

Nmer_LlmOllama_Ping(cfg, timeoutMs := 18000) {
    base := Nmer_LlmOllama_BaseUrl(cfg)
    model := Trim(String(cfg.Get("model", "")))
    if FuncExists("NiumaOllama_StartService") {
        try NiumaOllama_StartService(8000)
        catch {
        }
    }
    if FuncExists("LlmApiPing_TestOllama") {
        try {
            r := LlmApiPing_TestOllama(base, model, timeoutMs)
            return Map(
                "ok", !!r.Get("ok", false),
                "message", Trim(String(r.Get("error", ""))),
                "elapsedMs", Integer(r.Get("elapsedMs", 0))
            )
        } catch as _e {
            return Map("ok", false, "message", _e.Message, "elapsedMs", 0)
        }
    }
    return Map("ok", false, "message", "LlmApiPing 未加载", "elapsedMs", 0)
}

Nmer_LlmOllama_Chat(cfg, messages, timeoutMs := 60000) {
    if !(cfg is Map) || !(messages is Array) || messages.Length = 0
        return Map("ok", false, "message", "请求无效", "text", "")
    base := Nmer_LlmOllama_BaseUrl(cfg)
    model := Trim(String(cfg.Get("model", "")))
    if (model = "" && FuncExists("UserStudio_LlmPresetFor"))
        model := Trim(String(UserStudio_LlmPresetFor("ollama").Get("model", "")))
    if FuncExists("NiumaOllama_StartService")
        try NiumaOllama_StartService(8000)
    body := Jxon_Dump(Map("model", model, "messages", messages, "stream", false))
    root := FuncExists("LlmApiPing_OllamaRootUrl") ? LlmApiPing_OllamaRootUrl(base) : base
    url := RegExReplace(root, "/+$", "") . "/v1/chat/completions"
    if !FuncExists("LlmApiPing_HttpSync")
        return Map("ok", false, "message", "LlmApiPing 未加载", "text", "")
    try {
        r := LlmApiPing_HttpSync("POST", url, Map("Content-Type", "application/json"), body, timeoutMs)
        if !r.Get("ok", false)
            return Map("ok", false, "message", Trim(String(r.Get("error", "HTTP 失败"))), "text", "")
        text := ""
        if FuncExists("Nmer_LlmOai_ParseChatText")
            text := Nmer_LlmOai_ParseChatText(r.Get("text", ""))
        else
            text := Trim(String(r.Get("text", "")))
        return Map("ok", true, "message", "", "text", text)
    } catch as _e {
        return Map("ok", false, "message", _e.Message, "text", "")
    }
}

Nmer_LlmOllama_ListModels(cfg, timeoutMs := 8000) {
    base := Nmer_LlmOllama_BaseUrl(cfg)
    root := FuncExists("LlmApiPing_OllamaRootUrl") ? LlmApiPing_OllamaRootUrl(base) : base
    if !FuncExists("LlmApiPing_HttpSync")
        return Map("ok", false, "models", [], "message", "LlmApiPing 未加载")
    try {
        r := LlmApiPing_HttpSync("GET", RegExReplace(root, "/+$", "") . "/api/tags", Map(), "", timeoutMs)
        if !r.Get("ok", false)
            return Map("ok", false, "models", [], "message", Trim(String(r.Get("error", ""))))
        models := []
        try {
            j := Jxon_Load(r.Get("text", ""))
            if (j is Map && j.Has("models") && j["models"] is Array) {
                for m in j["models"] {
                    if (m is Map && m.Has("name")) {
                        n := Trim(String(m["name"]))
                        if (n != "")
                            models.Push(n)
                    }
                }
            }
        } catch {
        }
        return Map("ok", true, "models", models, "message", "")
    } catch as _e {
        return Map("ok", false, "models", [], "message", _e.Message)
    }
}

Nmer_LlmOllama_BaseUrl(cfg) {
    base := ""
    if (cfg is Map)
        base := Trim(String(cfg.Get("baseUrl", "")))
    if (base = "" && FuncExists("UserStudio_LlmPresetFor"))
        base := Trim(String(UserStudio_LlmPresetFor("ollama").Get("baseUrl", "")))
    if (base = "")
        base := "http://127.0.0.1:11434/v1"
    return base
}

Nmer_LlmOllama_BuildHttpChat(cfg, userText, maxTokens := 4096, stream := false) {
    if !(cfg is Map) || Trim(String(userText)) = ""
        return Map("ok", false, "message", "请求无效")
    base := Nmer_LlmOllama_BaseUrl(cfg)
    model := Trim(String(cfg.Get("model", "")))
    if (model = "" && FuncExists("UserStudio_LlmPresetFor"))
        model := Trim(String(UserStudio_LlmPresetFor("ollama").Get("model", "")))
    root := FuncExists("LlmApiPing_OllamaRootUrl") ? LlmApiPing_OllamaRootUrl(base) : base
    url := RegExReplace(root, "/+$", "") . "/v1/chat/completions"
    bodyMap := Map(
        "model", model,
        "messages", [Map("role", "user", "content", String(userText))],
        "stream", !!stream
    )
    return Map(
        "ok", true,
        "url", url,
        "headers", Map("Content-Type", "application/json"),
        "body", Jxon_Dump(bodyMap),
        "vendor", "ollama",
        "protocolId", "ollama"
    )
}

Nmer_LlmOllama_BuildHttpChatMessages(cfg, messages, maxTokens := 4096, stream := false) {
    if !(cfg is Map) || !(messages is Array) || messages.Length = 0
        return Map("ok", false, "message", "请求无效")
    base := Nmer_LlmOllama_BaseUrl(cfg)
    model := Trim(String(cfg.Get("model", "")))
    if (model = "" && FuncExists("UserStudio_LlmPresetFor"))
        model := Trim(String(UserStudio_LlmPresetFor("ollama").Get("model", "")))
    root := FuncExists("LlmApiPing_OllamaRootUrl") ? LlmApiPing_OllamaRootUrl(base) : base
    url := RegExReplace(root, "/+$", "") . "/v1/chat/completions"
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
    bodyMap := Map(
        "model", model,
        "messages", oaMsgs,
        "stream", !!stream
    )
    return Map(
        "ok", true,
        "url", url,
        "headers", Map("Content-Type", "application/json"),
        "body", Jxon_Dump(bodyMap),
        "vendor", "ollama",
        "protocolId", "ollama"
    )
}
