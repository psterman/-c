# OpenClaw Gateway WebSocket 契约（FTB-2 / ADP-0）

生产 CP 经 FTB `reqOpenClaw` 连接 OpenClaw Gateway。Adapter（Wave 1 ADP-1）须复用本契约，不得把 `18789` 当 OpenAI HTTP。

实现参考：[`html/FloatingToolbarStrip.html`](../html/FloatingToolbarStrip.html) `reqOpenClaw`、`ocCanonicalSessionKey`、`paletteSessionKeyForCard`。

---

## 1. 连接

| 项 | 值 |
|----|-----|
| 协议 | WebSocket |
| URL 模板 | `ws://{host}:{port}/?token={gatewayToken}` |
| 默认 host:port | `127.0.0.1:18789`（可配置 `OPENCLAW_BASE_URL`） |
| 鉴权 | Query `token` 或 Base URL `#token=` |

`openClawEndpointFromCfg(cfg)` 解析 host/port/token；缺 token 时 **fail fast**。

---

## 2. sessionKey / sessionRef（ADP-0 结论）

### 2.1 类型：**free-form 字符串**（非 enum）

Gateway 使用 **canonical session key** 字符串路由会话，例如：

- `agent:main:main`（Control UI 默认）
- `agent:main:niuma-cp-card_123_456`（CP 生产）
- `agent:main:niuma-adp-card_123_456`（Adapter 候选，Wave 1）

**证据（本仓库）：**

```javascript
function ocCanonicalSessionKey(k) {
  var s = String(k || '').trim();
  if (!s) return '';
  if (s.indexOf('agent:') === 0) return s;
  if (s === 'main') return 'agent:main:main';
  return 'agent:main:' + s;
}
```

`reqOpenClaw` 将 `cfg.openclawSessionKey` / `gatewaySessionKey` 经 `ocCanonicalSessionKey` 后用于 `chat.history`、`sessions.send` 等 RPC。

### 2.2 命名空间约定

| 命名空间 | 模式 | 用途 | 锁定 |
|----------|------|------|------|
| **FTB/CP 生产** | `agent:main:niuma-cp-{slug}` | 新卡默认；`slug` = cardId 消毒后 ≤40 字符 | 同卡追问**复用** |
| **Adapter 灰度** | `agent:main:niuma-adp-{slug}` | 仅**新卡**且 `transport=adapter` | 与 `niuma-cp-` **禁止**混用 |
| **FTB 聊天** | `agent:main:niuma-{tabId}` | 非 CP 自动会话 | 与 CP 卡隔离 |

`slug` 规则（AHK/JS 一致）：去 `card_` 前缀 → 非 `[a-zA-Z0-9_-]` 替换为 `-` → trim `-` → 截断 40。

### 2.3 ADP-0 定稿

- **`niuma-adp-` 前缀可用** — Gateway 接受任意 `agent:main:*` 后缀；本仓库已用 `niuma-cp-`、`niuma-*` 生产验证（OC-7）。
- **禁止**在未 `transportLocked` 的卡片上从 FTB 热切 Adapter。
- **禁止** Adapter 复用已有 `niuma-cp-*` sessionRef。

共享实现：[`html/ftb/palette/openclaw-session-keys.js`](../html/ftb/palette/openclaw-session-keys.js)、[`apps/nmer-wails/poc/openclaw_session.go`](../apps/nmer-wails/poc/openclaw_session.go)。

---

## 3. reqOpenClaw 流程（Palette Agent）

```text
1. 解析 endpoint + sessionKey（canonical）
2. WebSocket connect
3. 认证 challenge / connect ack
4. sessions.send 或 chat.send（带 sessionKey + 用户消息）
5. 流式事件 → ocFeedAgentLoopFromOpenClawStream
6. 四标签 prose → CP BlockPipeline（R1/R2）
7. finalize → paletteNotifyPaletteAgentEnd(sessionRef)
```

Palette Agent 超时：`OPENCLAW_PALETTE_AGENT_WS_TIMEOUT_MS`（长于普通聊天）。

关键 RPC（经 `openClawRpcWithRetry`）：

| 方法 | 用途 |
|------|------|
| `chat.history` | `{ sessionKey, limit }` 恢复/兜底 |
| `sessions.send` / `chat.send` | 发用户消息（实现内按 Gateway 能力选择） |

---

## 4. CP ↔ FTB 桥接消息

| type | 方向 | 说明 |
|------|------|------|
| `host_palette_agent_stream` | AHK → FTB | 派发 agent 流（含 `sessionRef`） |
| `niuma_palette_agent_end` | FTB → CP | 结束 + `sessionRef` |
| `niuma_palette_agent_error` | FTB → CP | 错误 |
| `niuma_palette_agent_trace` | 双向 | 调试 |

入口：`window.runPaletteAgentStream`（[`palette-agent-bridge.js`](../html/ftb/palette/palette-agent-bridge.js)）。

---

## 5. Adapter 侧车 HTTP（ADP-1，非 Gateway）

| 路径 | 方法 | 说明 |
|------|------|------|
| `/a2ui/openclaw/action` | POST | 收 action 上下文 → 内部调 OpenClaw WS → 写 `transport.v1` ingest |
| `/a2ui/ingest` | POST | 已有：JSONL `nmer.a2ui.transport.v1` |

Adapter **不**替换 Gateway WS 协议；它是 TPA 侧编排层。

### 5.1 nmer-hub / Adapter connect 身份（CP4）

Gateway 对 `client.id=openclaw-control-ui` + `mode=webchat` 会执行 **浏览器 origin 校验**，非浏览器 WS（Go adapter）会收到 `CONTROL_UI_ORIGIN_NOT_ALLOWED`。

nmer-hub adapter 须使用 **loopback backend 客户端**（见 Gateway protocol）：

| 字段 | 值 |
|------|-----|
| `client.id` | `gateway-client`（可用 `OPENCLAW_GATEWAY_CLIENT_ID` 覆盖） |
| `client.mode` | `backend`（可用 `OPENCLAW_GATEWAY_CLIENT_MODE` 覆盖） |
| `role` | `operator` |
| `scopes` | `operator.read`, `operator.write` |
| `auth.token` | `OPENCLAW_GATEWAY_TOKEN` |

若仍失败，检查本机 OpenClaw `gateway.controlUi.allowedOrigins`（仅影响 control-ui 浏览器客户端，不影响 backend）。

---

## 6. 验收探针

| 探针 | 预期 |
|------|------|
| OC-2 | `sessionRef` 形如 `agent:main:niuma-cp-*` |
| OC-7 | 每卡独立 key；追问同 key |
| ADP-0 单测 | `niuma-cp-*` ≠ `niuma-adp-*` 同 cardId |

---

## 变更记录

| 日期 | 说明 |
|------|------|
| 2026-06-08 | Wave 1 ADP-0+FTB-2：sessionKey free-form 定稿；契约初版 |
