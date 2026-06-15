#Requires AutoHotkey v2.0

; 薄统一层：registry / active / capabilities / route（HTTP 在 adapter）

global g_NmerLlmLastTest := Map("ok", false, "message", "")

Nmer_Llm_ManagerEnabled() {
    if !FuncExists("UserStudio_Get")
        return true
    try {
        doc := UserStudio_Get()
        if !(doc is Map) || !doc.Has("options") || !(doc["options"] is Map)
            return true
        opt := doc["options"]
        if !opt.Has("llmManagerEnabled")
            return true
        return !!opt["llmManagerEnabled"]
    } catch {
        return true
    }
}

Nmer_Llm_IsGatewayVendor(vendor) {
    vendor := FuncExists("UserStudio_NormalizeLlmProvider")
        ? UserStudio_NormalizeLlmProvider(vendor)
        : Trim(String(vendor))
    return (vendor = "openclaw" || vendor = "hermes")
}

Nmer_Llm_IsRoutableVendor(vendor) {
    return !Nmer_Llm_IsGatewayVendor(vendor)
}

Nmer_Llm_VendorToProtocol(vendor) {
    vendor := FuncExists("UserStudio_NormalizeLlmProvider")
        ? UserStudio_NormalizeLlmProvider(vendor)
        : Trim(String(vendor))
    switch vendor {
        case "ollama":
            return "ollama"
        case "claude":
            return "anthropic"
        case "gemini":
            return "gemini"
        case "minimax":
            return "anthropic"
        case "openclaw":
            return "openclaw"
        case "hermes":
            return "hermes"
        default:
            return "openai"
    }
}

Nmer_Llm_ShouldUseManager(llm) {
    if !Nmer_Llm_ManagerEnabled() || !(llm is Map)
        return false
    vendor := FuncExists("UserStudio_NormalizeLlmProvider")
        ? UserStudio_NormalizeLlmProvider(llm.Get("provider", ""))
        : Trim(String(llm.Get("provider", "")))
    if (vendor = "openclaw" || vendor = "hermes")
        return false
    return true
}

Nmer_Llm_HttpRegistry() {
    return [
        Map("id", "openai", "label", "OpenAI 兼容（云端）", "transport", "http-openai", "routable", true, "capabilities", Nmer_Llm_GetCapabilities("openai")),
        Map("id", "anthropic", "label", "Anthropic（Claude / MiniMax）", "transport", "http-anthropic", "routable", true, "capabilities", Nmer_Llm_GetCapabilities("anthropic")),
        Map("id", "gemini", "label", "Google Gemini", "transport", "http-gemini", "routable", true, "capabilities", Nmer_Llm_GetCapabilities("gemini")),
        Map("id", "ollama", "label", "Ollama（本地）", "transport", "http-ollama", "routable", true, "capabilities", Nmer_Llm_GetCapabilities("ollama"))
    ]
}

Nmer_Llm_GatewayRegistry() {
    return [
        Map("id", "openclaw", "label", "OpenClaw Gateway", "transport", "ws-gateway", "routable", false, "capabilities", Map("chat", true, "stream", true, "listModels", false, "local", true)),
        Map("id", "hermes", "label", "Hermes API Server", "transport", "http-gateway", "routable", false, "capabilities", Map("chat", true, "stream", false, "listModels", false, "local", true))
    ]
}

Nmer_Llm_Registry() {
    out := []
    for item in Nmer_Llm_HttpRegistry()
        out.Push(item)
    for item in Nmer_Llm_GatewayRegistry()
        out.Push(item)
    return out
}

Nmer_Llm_GetCapabilities(protocolId) {
    protocolId := Trim(String(protocolId))
    switch protocolId {
        case "ollama":
            return Map("chat", true, "stream", true, "listModels", true, "local", true)
        case "anthropic":
            return Map("chat", true, "stream", true, "listModels", false, "local", false)
        case "gemini":
            return Map("chat", true, "stream", false, "listModels", false, "local", false)
        case "openai":
            return Map("chat", true, "stream", true, "listModels", false, "local", false)
        case "openclaw":
            return Map("chat", true, "stream", true, "listModels", false, "local", true)
        case "hermes":
            return Map("chat", true, "stream", false, "listModels", false, "local", true)
        default:
            return Map("chat", false, "stream", false, "listModels", false, "local", false)
    }
}

Nmer_Llm_GetHttpActive() {
    active := Nmer_Llm_GetActive()
    if !(active is Map) || Nmer_Llm_IsGatewayVendor(active.Get("vendor", ""))
        return Map()
    return active
}

Nmer_Llm_GetActive() {
    if !FuncExists("UserStudio_Get")
        return Map()
    doc := UserStudio_Get()
    if FuncExists("UserStudio_FillSecretsFromVault")
        doc := UserStudio_FillSecretsFromVault(doc.Clone())
    llm := doc.Has("llm") && doc["llm"] is Map ? doc["llm"] : Map()
    vendor := FuncExists("UserStudio_NormalizeLlmProvider")
        ? UserStudio_NormalizeLlmProvider(llm.Get("provider", "openai"))
        : Trim(String(llm.Get("provider", "openai")))
    protocolId := Nmer_Llm_VendorToProtocol(vendor)
    model := Trim(String(llm.Get("model", "")))
    baseUrl := Trim(String(llm.Get("baseUrl", "")))
    apiKey := ""
    if FuncExists("UserStudio_PickDisplayApiKey")
        apiKey := UserStudio_PickDisplayApiKey(doc)
    else
        apiKey := Trim(String(llm.Get("apiKey", "")))
    if FuncExists("UserStudio_LlmPresetFor") {
        pre := UserStudio_LlmPresetFor(vendor)
        if (model = "")
            model := Trim(String(pre.Get("model", "")))
        if (baseUrl = "")
            baseUrl := Trim(String(pre.Get("baseUrl", "")))
    }
    return Map(
        "protocolId", protocolId,
        "vendor", vendor,
        "model", model,
        "baseUrl", baseUrl,
        "apiKey", apiKey
    )
}

Nmer_Llm_CfgFromLlmMap(llm) {
    if !(llm is Map)
        return Nmer_Llm_GetActive()
    vendor := FuncExists("UserStudio_NormalizeLlmProvider")
        ? UserStudio_NormalizeLlmProvider(llm.Get("provider", "openai"))
        : Trim(String(llm.Get("provider", "openai")))
    protocolId := Nmer_Llm_VendorToProtocol(vendor)
    model := Trim(String(llm.Get("model", "")))
    baseUrl := Trim(String(llm.Get("baseUrl", "")))
    apiKey := ""
    if FuncExists("UserStudio_NormalizeApiKey")
        apiKey := UserStudio_NormalizeApiKey(llm.Get("apiKey", ""))
    else
        apiKey := Trim(String(llm.Get("apiKey", "")))
    if (apiKey = "" && FuncExists("UserStudio_Get")) {
        doc := UserStudio_Get()
        if FuncExists("UserStudio_FillSecretsFromVault")
            doc := UserStudio_FillSecretsFromVault(doc.Clone())
        prov := vendor
        opt := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
        if opt.Has("llmApiKeys") && opt["llmApiKeys"] is Map && opt["llmApiKeys"].Has(prov)
            apiKey := FuncExists("UserStudio_NormalizeApiKey")
                ? UserStudio_NormalizeApiKey(opt["llmApiKeys"][prov])
                : Trim(String(opt["llmApiKeys"][prov]))
    }
    if FuncExists("UserStudio_LlmPresetFor") {
        pre := UserStudio_LlmPresetFor(vendor)
        if (model = "")
            model := Trim(String(pre.Get("model", "")))
        if (baseUrl = "")
            baseUrl := Trim(String(pre.Get("baseUrl", "")))
    }
    return Map(
        "protocolId", protocolId,
        "vendor", vendor,
        "model", model,
        "baseUrl", baseUrl,
        "apiKey", apiKey
    )
}

Nmer_Llm_PingResultFromDirect(r, cfg) {
    if !(r is Map)
        return Map("ok", false, "message", "无效响应", "elapsedMs", 0)
    if !(cfg is Map)
        cfg := Map()
    return Map(
        "ok", !!r.Get("ok", false),
        "message", Trim(String(r.Get("error", r.Get("message", "")))),
        "elapsedMs", Integer(r.Get("elapsedMs", 0)),
        "endpoint", Trim(String(r.Get("endpoint", ""))),
        "status", Integer(r.Get("status", 0)),
        "diagnostics", Trim(String(r.Get("diagnostics", ""))),
        "phase", Trim(String(r.Get("phase", ""))),
        "baseUrl", Trim(String(r.Get("baseUrl", cfg.Get("baseUrl", "")))),
        "model", Trim(String(r.Get("model", cfg.Get("model", "")))),
        "provider", Trim(String(cfg.Get("vendor", "")))
    )
}

Nmer_Llm_PingFromLlmMap(llm, timeoutMs := 18000) {
    cfg := Nmer_Llm_CfgFromLlmMap(llm)
    prov := Trim(String(cfg.Get("vendor", "")))
    keyLen := StrLen(Trim(String(cfg.Get("apiKey", ""))))
    if FuncExists("NMER_Log") {
        try NMER_Log("llm_ping", "route_start", "prov=" . prov . " keyLen=" . keyLen . " via=route")
        catch as _e0 {
            NmerCatch(A_ThisFunc, _e0)
        }
    }
    routeR := Map("ok", false, "message", "Route 未就绪", "elapsedMs", 0)
    try routeR := Nmer_Llm_Route("ping", cfg, timeoutMs)
    catch as _e1 {
        routeR := Map("ok", false, "message", _e1.Message, "elapsedMs", 0)
        NmerCatch(A_ThisFunc, _e1)
    }
    out := Map()
    if FuncExists("LlmApiPing_NormalizeRoutePingResult")
        out := LlmApiPing_NormalizeRoutePingResult(routeR, llm, cfg)
    else
        out := Map(
            "ok", !!routeR.Get("ok", false),
            "error", Trim(String(routeR.Get("message", routeR.Get("error", "")))),
            "elapsedMs", Integer(routeR.Get("elapsedMs", 0)),
            "provider", prov,
            "status", Integer(routeR.Get("status", 0))
        )
    if FuncExists("NMER_Log") {
        st := out.Has("status") ? Integer(out["status"]) : 0
        try NMER_Log("llm_ping", "route_done", "prov=" . prov . " keyLen=" . keyLen . " ok=" . (out.Get("ok", false) ? "1" : "0") . " st=" . st)
        catch as _e2 {
            NmerCatch(A_ThisFunc, _e2)
        }
    }
    return out
}

Nmer_Llm_SetActive(protocolId, vendor := "", model := "", baseUrl := "") {
    if !FuncExists("UserStudio_Get") || !FuncExists("UserStudio_Save")
        return false
    protocolId := Trim(String(protocolId))
    vendor := Trim(String(vendor))
    if (vendor = "" && protocolId = "ollama")
        vendor := "ollama"
    else if (vendor = "")
        vendor := "openai"
    if FuncExists("UserStudio_NormalizeLlmProvider")
        vendor := UserStudio_NormalizeLlmProvider(vendor)
    doc := UserStudio_Get()
    UserStudio_EnsureDocStructure(&doc)
    doc["llm"]["provider"] := vendor
    if (model != "")
        doc["llm"]["model"] := model
    if (baseUrl != "")
        doc["llm"]["baseUrl"] := baseUrl
  if (protocolId = "ollama" && doc["llm"]["provider"] != "ollama")
        doc["llm"]["provider"] := "ollama"
    try {
        UserStudio_Save(doc)
        return true
    } catch {
        return false
    }
}

Nmer_Llm_RecordTest(r) {
    global g_NmerLlmLastTest
    if !(r is Map)
        return
    g_NmerLlmLastTest := Map(
        "ok", !!r.Get("ok", false),
        "message", Trim(String(r.Get("message", r.Get("error", ""))))
    )
}

Nmer_Llm_BuildUnifiedPayload() {
    active := Nmer_Llm_GetActive()
    activeOut := Map(
        "protocolId", active.Get("protocolId", "openai"),
        "vendor", active.Get("vendor", "openai"),
        "model", active.Get("model", ""),
        "baseUrl", active.Get("baseUrl", "")
    )
    providers := []
    gateways := []
    for item in Nmer_Llm_Registry() {
        if !(item is Map)
            continue
        row := Map(
            "id", item.Get("id", ""),
            "label", item.Get("label", ""),
            "transport", item.Get("transport", ""),
            "routable", !!item.Get("routable", true),
            "capabilities", item.Get("capabilities", Map())
        )
        if item.Get("routable", true)
            providers.Push(row)
        else
            gateways.Push(row)
    }
    global g_NmerLlmLastTest
    testStatus := Map(
        "ok", !!g_NmerLlmLastTest.Get("ok", false),
        "message", Trim(String(g_NmerLlmLastTest.Get("message", "")))
    )
    return Map(
        "managerEnabled", Nmer_Llm_ManagerEnabled(),
        "active", activeOut,
        "providers", providers,
        "gateways", gateways,
        "testStatus", testStatus
    )
}

Nmer_Llm_ToLegacyLlm(active) {
    if !(active is Map)
        return Map("provider", "openai", "apiKey", "", "baseUrl", "https://api.openai.com/v1", "model", "gpt-4o-mini")
    return Map(
        "provider", active.Get("vendor", "openai"),
        "apiKey", Trim(String(active.Get("apiKey", ""))),
        "baseUrl", Trim(String(active.Get("baseUrl", ""))),
        "model", Trim(String(active.Get("model", "")))
    )
}

Nmer_Llm_ResolveLegacyLlm(provider := "") {
    if !FuncExists("Nmer_Llm_GetActive")
        return Map()
    active := Nmer_Llm_GetActive()
    if !(active is Map) || !active.Has("vendor")
        return Map()
    want := ""
    if (provider != "") {
        want := FuncExists("UserStudio_NormalizeLlmProvider")
            ? UserStudio_NormalizeLlmProvider(provider)
            : Trim(String(provider))
    }
    cur := active.Get("vendor", "openai")
    if (want != "" && want != cur)
        return Map()
    llm := Nmer_Llm_ToLegacyLlm(active)
    if Nmer_Llm_IsGatewayVendor(cur)
        return llm
    pk := cur
    if (pk != "ollama" && Trim(String(llm.Get("apiKey", ""))) = "")
        return Map()
    return llm
}

Nmer_Llm_ResolveForConsumer(provider := "") {
    return Nmer_Llm_ResolveLegacyLlm(provider)
}

Nmer_Llm_ResolveHttpLegacyLlm(provider := "") {
    if !FuncExists("Nmer_Llm_GetHttpActive")
        return Map()
    active := Nmer_Llm_GetHttpActive()
    if !(active is Map) || !active.Has("vendor")
        return Map()
    want := ""
    if (provider != "") {
        want := FuncExists("UserStudio_NormalizeLlmProvider")
            ? UserStudio_NormalizeLlmProvider(provider)
            : Trim(String(provider))
    }
    cur := active.Get("vendor", "openai")
    if (want != "" && want != cur)
        return Map()
    llm := Nmer_Llm_ToLegacyLlm(active)
    if (cur != "ollama" && Trim(String(llm.Get("apiKey", ""))) = "")
        return Map()
    return llm
}

Nmer_Llm_BuildHttpChat(cfg, payload, maxTokens := 4096, stream := false) {
    if !(cfg is Map)
        cfg := Nmer_Llm_GetHttpActive()
    if !(cfg is Map) || cfg.Count = 0
        return Map("ok", false, "message", "未配置 HTTP 对话模型")
    if Nmer_Llm_IsGatewayVendor(cfg.Get("vendor", ""))
        return Map("ok", false, "message", "Gateway 协议请走专用连接，不支持 httpChat")
    protocolId := Trim(String(cfg.Get("protocolId", "")))
    if (protocolId = "")
        protocolId := Nmer_Llm_VendorToProtocol(cfg.Get("vendor", "openai"))
    if (protocolId = "openclaw" || protocolId = "hermes")
        return Map("ok", false, "message", "Gateway 协议请走专用连接，不支持 httpChat")
    messages := unset
    userText := ""
    if IsObject(payload) && (payload is Array) && payload.Length > 0
        messages := payload
    else
        userText := Trim(String(payload))
    if !IsSet(messages) && userText = ""
        return Map("ok", false, "message", "请求无效")
    switch protocolId {
        case "ollama":
            return IsSet(messages)
                ? Nmer_LlmOllama_BuildHttpChatMessages(cfg, messages, maxTokens, stream)
                : Nmer_LlmOllama_BuildHttpChat(cfg, userText, maxTokens, stream)
        case "anthropic":
            return IsSet(messages)
                ? Nmer_LlmAnthropic_BuildHttpChatMessages(cfg, messages, maxTokens, stream)
                : Nmer_LlmAnthropic_BuildHttpChat(cfg, userText, maxTokens, stream)
        case "gemini":
            if IsSet(messages)
                return Nmer_LlmGemini_BuildHttpChatMessages(cfg, messages, maxTokens)
            return Nmer_LlmGemini_BuildHttpChat(cfg, userText, maxTokens)
        default:
            return IsSet(messages)
                ? Nmer_LlmOai_BuildHttpChatMessages(cfg, messages, maxTokens, stream)
                : Nmer_LlmOai_BuildHttpChat(cfg, userText, maxTokens, stream)
    }
}

Nmer_Llm_ParseChatHttpResult(cfg, httpResult) {
    if !(httpResult is Map) || !httpResult.Get("ok", false)
        return Map("ok", false, "error", Trim(String(httpResult.Get("error", "HTTP 失败"))), "text", "", "status", Integer(httpResult.Get("status", 0)))
    raw := httpResult.Get("text", "")
    protocolId := Trim(String(cfg.Get("protocolId", "")))
    if (protocolId = "")
        protocolId := Nmer_Llm_VendorToProtocol(cfg.Get("vendor", "openai"))
    text := ""
    switch protocolId {
        case "anthropic":
            text := Nmer_LlmAnthropic_ParseText(raw)
        case "gemini":
            text := Nmer_LlmGemini_ParseText(raw)
        default:
            text := Nmer_LlmOai_ParseChatText(raw)
    }
    return Map("ok", true, "error", "", "text", text, "status", Integer(httpResult.Get("status", 200)))
}

Nmer_Llm_ExecuteHttpChat(cfg, payload, maxTokens := 4096, timeoutMs := 90000) {
    req := Nmer_Llm_BuildHttpChat(cfg, payload, maxTokens, false)
    if !req.Get("ok", false)
        return Map("ok", false, "error", Trim(String(req.Get("message", "请求无效"))), "text", "", "status", 0)
    if !FuncExists("LlmApiPing_HttpSync")
        return Map("ok", false, "error", "LlmApiPing 未加载", "text", "", "status", 0)
  try {
        r := LlmApiPing_HttpSync("POST", req["url"], req["headers"], req["body"], timeoutMs)
        return Nmer_Llm_ParseChatHttpResult(cfg, r)
    } catch as _e {
        return Map("ok", false, "error", _e.Message, "text", "", "status", 0)
    }
}

Nmer_Llm_Route(op, cfg, args*) {
    if !(cfg is Map)
        cfg := Nmer_Llm_GetActive()
    vendor := cfg.Get("vendor", "")
    protocolId := Trim(String(cfg.Get("protocolId", "")))
    if (protocolId = "")
        protocolId := Nmer_Llm_VendorToProtocol(vendor)
    op := Trim(String(op))
    if (op = "httpChat" || op = "ping" || op = "chat" || op = "listModels") {
        if Nmer_Llm_IsGatewayVendor(vendor) || protocolId = "openclaw" || protocolId = "hermes"
            return Map("ok", false, "message", "Gateway 协议请走专用连接，不支持 HTTP Route")
    }
    if (op = "httpChat")
        return Nmer_Llm_BuildHttpChat(cfg, args.Length > 0 ? args[1] : "", args.Length > 1 ? Integer(args[2]) : 4096, args.Length > 2 ? !!args[3] : false)
    switch protocolId {
        case "ollama":
            switch op {
                case "ping":
                    return Nmer_LlmOllama_Ping(cfg, args.Length > 0 ? Integer(args[1]) : 18000)
                case "chat":
                    return Nmer_LlmOllama_Chat(cfg, args.Length > 0 ? args[1] : [], args.Length > 1 ? Integer(args[2]) : 60000)
                case "listModels":
                    return Nmer_LlmOllama_ListModels(cfg, args.Length > 0 ? Integer(args[1]) : 8000)
                default:
                    return Map("ok", false, "message", "未知操作: " . op)
            }
        case "anthropic":
            switch op {
                case "ping":
                    return Nmer_LlmAnthropic_Ping(cfg, args.Length > 0 ? Integer(args[1]) : 18000)
                case "chat":
                    return Nmer_LlmAnthropic_Chat(cfg, args.Length > 0 ? args[1] : [], args.Length > 1 ? Integer(args[2]) : 60000)
                default:
                    return Map("ok", false, "message", "未知操作: " . op)
            }
        case "gemini":
            switch op {
                case "ping":
                    return Nmer_LlmGemini_Ping(cfg, args.Length > 0 ? Integer(args[1]) : 18000)
                case "chat":
                    return Nmer_LlmGemini_Chat(cfg, args.Length > 0 ? args[1] : [], args.Length > 1 ? Integer(args[2]) : 60000)
                default:
                    return Map("ok", false, "message", "未知操作: " . op)
            }
        default:
            switch op {
                case "ping":
                    return Nmer_LlmOai_Ping(cfg, args.Length > 0 ? Integer(args[1]) : 18000)
                case "chat":
                    return Nmer_LlmOai_Chat(cfg, args.Length > 0 ? args[1] : [], args.Length > 1 ? Integer(args[2]) : 60000)
                case "listModels":
                    return Map("ok", false, "models", [], "message", "该协议族不支持列出模型")
                default:
                    return Map("ok", false, "message", "未知操作: " . op)
            }
    }
}
