# LLM Provider 契约（v3）

薄统一层：**HTTP 对话模型** 与 **本机 Gateway** 分层。配置读取、registry、httpChat 构建/解析在 `Nmer_LlmProvider.ahk`；HTTP 实现在各 adapter。

## 边界原则

| 类别 | vendor | transport | routable | 走统一 httpChat |
|------|--------|-----------|----------|-----------------|
| HTTP 对话 | openai, kimi, claude, gemini, minimax, ollama… | `http-*` | **true** | **是** |
| Gateway | `openclaw` | `ws-gateway` | **false** | **否**（WebSocket 专用） |
| Gateway | `hermes` | `http-gateway` | **false** | **否**（本机 API Server 专用） |

`Nmer_Llm_Route("ping"|"chat"|"httpChat"|"listModels")` 对 Gateway vendor **直接拒绝**，避免把特殊协议塞进通用 LLM 抽象。

## ActiveConfig（`Nmer_Llm_GetActive`）

| 字段 | 说明 |
|------|------|
| `protocolId` | 协议族：`openai`、`anthropic`、`gemini`、`ollama`、`openclaw`、`hermes` |
| `vendor` | 厂商 profile |
| `model` / `baseUrl` / `apiKey` | 与 v2 相同 |

`Nmer_Llm_GetHttpActive()`：当前 active **不是** Gateway 时返回配置，否则空 Map（供 HTTP 消费点使用）。

## 统一配置读取

| API | 用途 |
|-----|------|
| `Nmer_Llm_ResolveLegacyLlm(provider?)` | **FTB / CP / Settings 同步** 唯一入口；返回 `{provider, apiKey, baseUrl, model}` |
| `Nmer_Llm_ResolveForConsumer` | `ResolveLegacyLlm` 别名 |
| `Nmer_Llm_ResolveHttpLegacyLlm` | 仅 HTTP active；Gateway 或密钥缺失时返回空 |
| `Nmer_Llm_ToLegacyLlm(active)` | ActiveConfig → 旧 llm Map |

Palette 指定 provider 与 active 不一致时返回空 Map，由 CP 旧 per-slot 回退（palette 专用场景）。

## Vendor → Protocol

| vendor | protocolId | adapter |
|--------|------------|---------|
| openai, kimi, deepseek, qwen, glm, custom… | `openai` | Oai |
| claude, minimax | `anthropic` | Anthropic |
| gemini | `gemini` | Gemini |
| ollama | `ollama` | Ollama |
| openclaw | `openclaw` | **Gateway registry**，非 HTTP adapter |
| hermes | `hermes` | **Gateway registry**，非 HTTP adapter |

## Registry v3

**HTTP providers**（`routable: true`）：`openai`、`anthropic`、`gemini`、`ollama`

**Gateways**（`routable: false`）：`openclaw`（`ws-gateway`）、`hermes`（`http-gateway`）

`Nmer_Llm_BuildUnifiedPayload()` 返回 `providers` + `gateways` 分栏。

## httpChat 收口（v3）

| 函数 | 说明 |
|------|------|
| `Nmer_Llm_BuildHttpChat(cfg, payload, maxTokens?, stream?)` | `payload` 为 **userText 字符串** 或 **messages 数组**；返回 `{ok, url, headers, body}` |
| `Nmer_Llm_ParseChatHttpResult(cfg, httpResult)` | HTTP 原始响应 → `{ok, text, error, status}` |
| `Nmer_Llm_ExecuteHttpChat(...)` | 同步：Build + HttpSync + Parse |

**禁止**在 CP/FTB 新代码中分散拼 `/chat/completions`、`/v1/messages` 等 URL。

## Route 操作（仅 routable HTTP）

| op | 说明 |
|----|------|
| `ping` | 连通性测试 |
| `chat` | 非流式对话（adapter 内闭环） |
| `httpChat` | 构建 HTTP 请求包 |
| `listModels` | 仅 ollama |

## 消费点（v3）

| 模块 | 行为 |
|------|------|
| 设置页「对话模型」 | 仅 **云端 / Ollama**；Hermes/OpenClaw 在「本机 Gateway」区 |
| `testUserStudioLlm` | HTTP：`LlmApiPing_Test` → `Nmer_Llm_Route("ping")`（manager 开启时）；Gateway：`LlmApiPing_TestHermes` / `TestOpenClaw` | Gateway 不走 HTTP Route |
| `FloatingToolbar_GetStudioLlm` | `ResolveLegacyLlm()` |
| `CommandPalette_ResolveAiLlmForProvider` | 优先 `ResolveLegacyLlm` |
| `CommandPalette_RunDirectAiStream` | **仅** `BuildHttpChat` + 宿主 HTTP；Gateway 报错指引 Niuma Chat |
| FTB `niuma_llm_http_chat` | 宿主 `BuildHttpChat` + `ParseChatHttpResult`；前端 `hostUnifiedHttpChat` |
| FTB `niuma_llm_http` | 保留（列表/探测等）；**对话**优先 unified |
| `UserStudio_WriteNiumaLlmSync` | `GetActive`（含 Gateway）同步 Niuma Chat |

## Feature flag

`options.llmManagerEnabled` 默认 **true**。Gateway 不受 manager 的 HTTP Route 影响。

## 未做 / 后续

- 真 SSE 流式分块（统一层稳定后再接）
- `go-gateway` 接口位
