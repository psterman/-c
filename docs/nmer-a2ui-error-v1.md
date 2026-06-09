# nmer.a2ui.error.v1 — 错误码契约（草案）

本文定义 NMER A2UI / TPA 层的稳定错误码，供 Go、TypeScript、AHK Debug 与 SearchDebug 统一消费。

**状态：** 草案 v1。当前生产多返回**自由文本**；新代码应优先发出本契约，旧路径逐步迁移。

**相关：** [`a2ui-architecture-v2.md`](./a2ui-architecture-v2.md)

---

## 1. 信封格式

```json
{
  "schemaVersion": "nmer.a2ui.error.v1",
  "code": "A2UI_COMPONENT_UNSUPPORTED",
  "message": "unsupported A2UI component: RemoteScript",
  "retryable": false,
  "layer": "schema",
  "context": {
    "cardId": "card-1",
    "surfaceId": "surface-1",
    "correlationId": "corr-1",
    "requestId": "req-1",
    "seq": 3,
    "provider": "fake",
    "component": "RemoteScript"
  },
  "fallback": {
    "hint": "reply_markdown",
    "userMessage": "官方界面渲染失败，已保留文字回复。"
  }
}
```

### 1.1 字段

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `schemaVersion` | string | 是 | 固定 `nmer.a2ui.error.v1` |
| `code` | string | 是 | 稳定枚举，见 §2 |
| `message` | string | 是 | 开发者可读说明（可英文） |
| `retryable` | boolean | 是 | 客户端是否应重试 |
| `layer` | enum | 是 | `format` \| `schema` \| `semantic` \| `transport` \| `policy` \| `provider` \| `render` |
| `context` | object | 否 | 定位信息，禁止含完整用户正文 |
| `fallback` | object | 否 | 建议 fallback 行为 |

### 1.2 传输载体

| 场景 | 载体 |
|------|------|
| WS 拒收 envelope | `official_a2ui_rejected` + body 含 error 对象 |
| Action 失败 | `official_a2ui_action_result` 的 `status` + 未来 `errorCode` 字段 |
| HTTP ingest | `4xx/5xx` JSON body |
| CP Debug | `palette_agent_debug_log` / Agent 页 JSON 行 |
| TS 渲染失败 | `official-a2ui-action-error` 自定义事件 + error 对象 |

---

## 2. 错误码表

### 2.1 命名规则

```text
{域}_{原因}
域：TPA | A2UI | ACTION | PROVIDER | BRIDGE | RENDER | SESSION
```

### 2.2 TPA / 传输（layer: transport）

| code | retryable | 说明 | 当前 Go/TS 对应 |
|------|-----------|------|-----------------|
| `TPA_TRANSPORT_VERSION_UNSUPPORTED` | false | `schemaVersion` ≠ `nmer.a2ui.transport.v1` | `unsupported transport version` |
| `TPA_ENVELOPE_INVALID` | false | JSON 解析失败 | `invalid A2UI envelope` |
| `TPA_ENVELOPE_EMPTY` | false | 空行 | `empty A2UI envelope` |
| `TPA_ENVELOPE_TOO_LARGE` | false | 单行 > 256KiB | `A2UI line exceeds` |
| `TPA_FIELD_REQUIRED` | false | 必填标识符缺失 | `eventId is required` 等 |
| `TPA_FIELD_TOO_LONG` | false | 标识符 > 160 字符 | `exceeds 160 characters` |
| `TPA_SEQ_INVALID` | false | seq ≤ 0 | `seq must be positive` |
| `TPA_SEQ_STALE` | false | seq 非递增 | `stale A2UI sequence` |
| `TPA_MESSAGE_REQUIRED` | false | message 为空 | `message is required` |
| `TPA_INGEST_TOO_LARGE` | false | 整请求 > 1MiB | HTTP ingest 限制 |
| `TPA_REPLAY_OVERFLOW` | true | 重放队列截断 | 客户端应请求全量 fixture |

### 2.3 A2UI 协议（layer: schema）

| code | retryable | 说明 | 当前对应 |
|------|-----------|------|----------|
| `A2UI_PROTOCOL_VERSION_UNSUPPORTED` | false | message.version ≠ `v0.9` | Go validator |
| `A2UI_MESSAGE_INVALID` | false | message JSON 无效 | `invalid A2UI v0.9 message` |
| `A2UI_OPERATION_AMBIGUOUS` | false | 单 message 多 operation | `must contain exactly one operation` |
| `A2UI_CATALOG_NOT_ALLOWED` | false | catalogId 非 basic catalog | `catalog is not allowed` |
| `A2UI_SURFACE_MISMATCH` | false | envelope.surfaceId ≠ message.surfaceId | Go validator |
| `A2UI_COMPONENT_UNSUPPORTED` | false | 非白名单组件 | `unsupported A2UI component` |
| `A2UI_COMPONENT_LIMIT` | false | 组件数 > 200 | `component limit exceeded` |
| `A2UI_COMPONENT_ID_REQUIRED` | false | 组件缺 id | `component id is required` |
| `A2UI_JSONL_INVALID` | false | JSONL 行解析失败 | TS `Invalid A2UI JSONL` |
| `A2UI_SCHEMA_VALIDATION_FAILED` | false | zod/A2uiMessageSchema 失败 | TS spike runtime |

### 2.4 语义（layer: semantic）

| code | retryable | 说明 |
|------|-----------|------|
| `SEM_CARD_SURFACE_MISMATCH` | false | envelope.cardId 与当前卡不一致 |
| `SEM_CORRELATION_UNKNOWN` | false | correlationId 无 Ledger 记录 |
| `SEM_ACTION_CONTEXT_MISMATCH` | false | Provider 回 envelope 与 action 上下文不符 |
| `SEM_DEPTH_EXCEEDED` | false | 追问链深度 > 策略上限 |
| `SEM_VALUE_OUT_OF_RANGE` | false | 业务校验失败（如表格行列超限） |
| `SEM_PROTOCOL_TAG_UNCLOSED` | false | 四标签未闭合（R1 路径） |
| `SEM_PROTOCOL_TAG_NESTED` | false | 标签嵌套非法（R1 路径） |

### 2.5 Action 策略（layer: policy）

| code | retryable | 说明 | 当前 action result status |
|------|-----------|------|---------------------------|
| `ACTION_VERSION_UNSUPPORTED` | false | action schema 版本不对 | `rejected` |
| `ACTION_NOT_ALLOWED` | false | actionName 非白名单 | `rejected` |
| `ACTION_KIND_UNSAFE` | false | kind ≠ safe | `rejected` |
| `ACTION_DEPTH_EXCEEDED` | false | depth > 2 | `rejected` |
| `ACTION_TIMEOUT_RANGE` | false | timeoutMs 越界 | `rejected` |
| `ACTION_DUPLICATE` | true | 10s 内重复 requestId | `rejected` |
| `ACTION_ABORT_MISMATCH` | false | abortId 与活跃 action 不符 | `rejected` |
| `ACTION_NOT_ACTIVE` | false | 取消时无进行中 action | `rejected` |
| `ACTION_TIMED_OUT` | true | Provider 超时 | `timeout` |
| `ACTION_CANCELLED` | false | 用户/abort 取消 | `cancelled` |

### 2.6 Provider（layer: provider）

| code | retryable | 说明 |
|------|-----------|------|
| `PROVIDER_UNAVAILABLE` | true | sidecar 未启动 |
| `PROVIDER_CONFIG_INVALID` | false | 环境变量/URL 无效 |
| `PROVIDER_REMOTE_DENIED` | false | 非 loopback 且未显式允许 |
| `PROVIDER_HTTP_ERROR` | true | Adapter HTTP 非 2xx |
| `PROVIDER_EMPTY_RESPONSE` | true | 无 JSONL 行 |
| `PROVIDER_FORMAT_NON_JSONL` | false | 返回 prose/markdown |
| `PROVIDER_OPENAI_NO_CHOICES` | true | chat/completions 空 choices |
| `PROVIDER_OPENCLAW_TOKEN_MISSING` | false | Gateway Token 未配置 |
| `PROVIDER_OPENCLAW_WS_FAILED` | true | WS 建连失败 |

### 2.7 Bridge / 会话（layer: transport）

| code | retryable | 说明 |
|------|-----------|------|
| `BRIDGE_WS_DISCONNECTED` | true | `:18791` 断线 |
| `BRIDGE_WS_REJECTED` | true | hello/鉴权失败 |
| `BRIDGE_FTB_NOT_READY` | true | `g_FTB_WV2_FrameReady`  false |
| `BRIDGE_FTB_NO_STREAM_FN` | false | `runPaletteAgentStream` 缺失 |
| `SESSION_REF_STALE` | false | OpenClaw sessionKey 与卡不一致 |
| `SESSION_ISOLATION_VIOLATION` | false | 跨 cardId 复用 surface |

### 2.8 渲染（layer: render）

| code | retryable | 说明 |
|------|-----------|------|
| `RENDER_SURFACE_FAILED` | false | MessageProcessor 抛错 |
| `RENDER_FALLBACK_APPLIED` | false | 已降级到 markdown（信息性） |
| `RENDER_REGISTRY_MISSING` | false | 无对应 Lit/legacy renderer |
| `RENDER_THEME_CONFLICT` | false | 样式桥失败（信息性） |

---

## 3. 与 action result 的映射

当前 `A2UIActionResult`（`nmer.a2ui.action-result.v1`）：

| status | 建议 errorCode |
|--------|----------------|
| `accepted` | — |
| `completed` | — |
| `rejected` | §2.5 / §2.3 中具体 code |
| `timeout` | `ACTION_TIMED_OUT` |
| `cancelled` | `ACTION_CANCELLED` |

**迁移：** 在 `A2UIActionResult` 增加可选字段 `errorCode`，保留 `error` 字符串兼容旧客户端。

---

## 4. 客户端处理指南

### 4.1 按 layer

| layer | 客户端动作 |
|-------|------------|
| `format` | 不重试渲染；触发 Provider 重发；记录 debug |
| `schema` | fallback 到 R1 reply；不白屏 |
| `semantic` | 显示 `fallback.userMessage`；可选 `palette_agent_recover` |
| `transport` | 退避重连 WS |
| `policy` | 展示拒绝原因；不重复点击 |
| `provider` | 按 `retryable`；toast 区分 Token 与网络 |
| `render` | 级联 fallback；保留已有 blocks |

### 4.2 级联 fallback 触发

```text
RENDER_* / A2UI_* / TPA_*（不可恢复）
  → fallback.hint = reply_markdown
  → 不清空已有 R2 blocks

PROVIDER_OPENCLAW_*
  → 保持 R1 status 块；uiState = error

BRIDGE_FTB_*
  → toast + Agent Debug；不创建空 reply
```

---

## 5. Debug 与可观测性

### 5.1 日志字段（最小集）

```json
{
  "evt": "a2ui_error",
  "code": "A2UI_COMPONENT_UNSUPPORTED",
  "cardId": "…",
  "surfaceId": "…",
  "seq": 3,
  "retryable": false
}
```

### 5.2 SearchDebug / Agent 页

- 错误行显示：`code` + 短 `message`
- 可过滤：`layer=provider`、`code~OPENCLAW`

### 5.3 指标（P4 灰度）

| 指标 | 说明 |
|------|------|
| `a2ui_error_total{code}` | 按码计数 |
| `a2ui_fallback_total{hint}` | fallback 次数 |
| `a2ui_action_result_total{status}` | Action 结局 |

---

## 6. 实现优先级

| 优先级 | 工作 |
|--------|------|
| P0 | Go `Validate` / `ActionPolicy` 返回 struct Error 而非纯 string |
| P0 | WS `official_a2ui_rejected` 携带 error 对象 |
| P1 | TS Bridge 映射 TS 异常 → `RENDER_*` |
| P1 | Orchestrator FTB 未就绪 → `BRIDGE_FTB_NOT_READY` toast |
| P2 | `A2UIActionResult.errorCode` 字段 |
| P2 | R1 四标签检测 → `SEM_PROTOCOL_*` |

---

## 7. 非目标

- 不定义 HTTP 状态码与 code 的一对一全球标准（仅 NMER 内部）
- 不在错误对象中携带完整 LLM 输出或用户 query 全文
- 不要求 AHK 解析所有 code（AHK 只处理 BRIDGE_* 子集）

---

## 8. 变更记录

| 版本 | 说明 |
|------|------|
| v1.0-draft | 首版草案，对齐 `poc/a2ui.go`、`a2ui_action.go`、TS spike 现有字符串 |
