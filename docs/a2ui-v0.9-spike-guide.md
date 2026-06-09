# A2UI v0.9 Spike 操作与迁移说明

本文说明当前官方 A2UI v0.9 Spike 的用途、测试步骤、失败护栏和后续迁移顺序。

体系总览与错误码见 [`a2ui-architecture-v2.md`](./a2ui-architecture-v2.md)、[`nmer-a2ui-error-v1.md`](./nmer-a2ui-error-v1.md)；FTB 边界见 [`ftb-module-map.md`](./ftb-module-map.md)。

## 1. 先区分两条通道

当前系统同时存在两种名字相近、但职责不同的 UI 通道：

| 通道 | 当前用途 | 状态 |
|------|----------|------|
| NMER `PaletteBlock type=a2ui` | `ComparisonTable`、`Steps`、`Alert`、`ActionChips` | 生产旧通道，继续保留 |
| 官方 A2UI v0.9 | `createSurface`、`updateComponents`、`updateDataModel` | Wails 隔离 Spike |

现阶段不把四个 NMER 组件强制翻译为官方 A2UI，也不删除 118 项旧 Fixtures。

## 2. 当前完成范围

官方依赖已锁定：

```text
@a2ui/web_core 0.10.0
@a2ui/lit      0.10.0
```

Spike 已跑通六种官方基础组件：

1. `Text`
2. `Row`
3. `Column`
4. `Card`
5. `Button`
6. `TextField`

当前处理链：

```text
固定 Fixture / JSONL
  → 输入大小与组件白名单校验
  → 官方 MessageProcessor
  → 官方 Lit a2ui-surface
  → Button ActionEnvelope
  → Fake Action Handler
```

暂未接入：

- OpenClaw、Hermes 或真实 LLM
- CommandPalette 生产卡片
- capability negotiation
- 正式 Surface Store
- Go 侧业务动作与权限决策

## 3. 启动步骤

环境要求：

- Go 1.22+
- Node 20.19+ 或 22.12+
- Wails CLI v2
- Microsoft Edge WebView2 Runtime

### 3.1 构建

```powershell
cd apps/nmer-wails
wails build
```

产物：

```text
apps/nmer-wails/build/bin/nmer-wails.exe
```

### 3.2 开发模式

```powershell
cd apps/nmer-wails
wails dev
```

打开页面后找到：

```text
POC 3 · 官方 A2UI v0.9 隔离 Spike
```

## 4. 手工测试顺序

严格按以下顺序测试，每完成一项再进入下一项。

### 步骤 1：六组件正常渲染

点击：

```text
6 组件 + data model + button
```

预期：

- 出现标题、卡片、文本框和按钮
- 标题为“A2UI v0.9 · 流式更新已生效”
- 文本框含默认问题
- 页面无 fallback 警告

### 步骤 2：安全按钮回调

点击：

```text
发送安全回调
```

预期：

- 标题更新为“回调完成：当前问题”
- Trace 包含 `safe.follow-up`
- Trace 包含 `requestId` 与 `correlationId`
- 10 秒内重复点击被抑制

### 步骤 3：非法 JSONL 护栏

点击：

```text
非法 JSONL 自动降级
```

预期：

- 显示“✓ 预期护栏已通过”
- 原因包含 `Invalid A2UI JSONL`
- 页面不白屏、不崩溃

### 步骤 4：未知组件护栏

点击：

```text
未知组件自动降级
```

预期：

- `RemoteScript` 被拒绝
- 不创建远程脚本或未知 DOM
- 页面降级为安全文本

### 步骤 5：复杂度上限护栏

点击：

```text
超限组件拒绝渲染
```

预期：

- 201 个组件被 200 上限拒绝
- 已创建的旧 Surface 被清理
- WebView2 内存不持续上升

### 步骤 6：动作超时

点击：

```text
回调超时演练
```

再点击：

```text
模拟回调超时
```

预期：

- Trace 在约 250ms 后显示 `A2UI action timed out`
- 页面仍可切换其他 Fixture
- 按钮和 Surface 不进入永久 loading

## 5. 自动测试

### 官方 A2UI Spike

```powershell
cd apps/nmer-wails/frontend
npm run test:a2ui
```

覆盖：

- 六组件 Surface
- 官方 `MessageProcessor` 状态
- Button 回调
- 非法 JSONL
- 未知组件
- 组件数量上限
- Action 超时

### 旧 NMER Reducer

```powershell
npm run test:reducer
```

### TypeScript 与构建

```powershell
npx tsc --noEmit
npm run build
```

### CommandPalette 旧通道回归

```powershell
cd ../../..
node html/run-palette-fixtures.mjs
```

验收线：

```text
passed=128 failed=0 ok=true
```

## 6. 当前安全与资源边界

| 项目 | 当前规则 |
|------|----------|
| 官方组件白名单 | `Text/Row/Column/Card/Button/TextField` |
| 单消息大小 | 最大 256 KiB |
| 单次组件数量 | 最大 200 |
| Action 类型 | 仅 `kind: safe` |
| Action 深度 | 最大 2 |
| 重复动作 | 同 Surface/组件/动作 10 秒抑制 |
| 默认动作超时 | 30 秒 |
| 测试超时 | 可由 Fixture 下调，最低 100ms |
| CommandPalette 卡片 | 最多 20 |
| 单卡消息 | 最多 30 |
| 流式文本 | 最多保留 120000 字符 |

Go 与 TypeScript 的未来职责：

- Go：会话、权限、Catalog 决策、业务动作、Provider 路由。
- TypeScript：组件 schema、URL/XSS 兜底、渲染、局部瞬时状态。
- 铁律：Go 决策，TypeScript 兜底。

## 7. 下一阶段改造顺序

### P0：当前 Spike

已完成。保持隔离，不接真实 LLM。

### P1：CommandPalette 并列入口

当前已完成：

1. 卡片新增独立 `.card-official-a2ui` 容器。
2. 旧 NMER 四组件继续走 `.card-a2ui` Lit renderer。
3. P1 只允许白名单 Fixture 写入新容器。
4. 官方 Surface 失败时优先显示旧 Markdown/reply。
5. 官方渲染器打成独立浏览器包，不依赖 Wails 页面运行。
6. P1 回归线从 118 项增加到 122 项；P2/P3 Action/Abort 闭环后为 128 项。

在 CommandPalette 调试上下文中一键创建并列测试卡：

```javascript
window.nmerPalette.runOfficialA2uiFixture("happy-six-components")
```

该测试卡同时包含：

- 旧 NMER `Alert`
- 旧 Markdown reply
- 官方 A2UI v0.9 Surface

挂载到已有活动卡：

```javascript
window.nmerPalette.mountOfficialA2uiFixture("", "happy-six-components")
```

失败路径：

```javascript
window.nmerPalette.mountOfficialA2uiFixture("", "malformed-jsonl")
window.nmerPalette.mountOfficialA2uiFixture("", "unsupported-component")
window.nmerPalette.mountOfficialA2uiFixture("", "oversized-surface")
```

清理：

```javascript
window.nmerPalette.clearOfficialA2ui("")
```

剩余 P1 验收：在真实 CommandPalette WebView2 中完成手工交互和内存观察。

### P2：Go 桥接

当前已完成：

1. Go 在 `http://127.0.0.1:18791/a2ui/ingest` 接收 JSONL。
2. Go 校验 transport version、A2UI v0.9、Catalog、Surface、序列和组件白名单。
3. Go 通过现有 `/agent/ws` 广播 `official_a2ui_event`。
4. CommandPalette 使用指数退避 WS 客户端订阅。
5. TS 再次校验信封、序列、消息大小、组件白名单与 props。
6. 重连时最多重放最近 20 张卡，防止历史洪泛。

传输信封：

```json
{
  "schemaVersion": "nmer.a2ui.transport.v1",
  "eventId": "evt-1",
  "requestId": "req-1",
  "correlationId": "corr-1",
  "cardId": "card-1",
  "surfaceId": "surface-1",
  "seq": 1,
  "final": false,
  "message": {
    "version": "v0.9",
    "createSurface": {
      "surfaceId": "surface-1",
      "catalogId": "https://a2ui.org/specification/v0_9/basic_catalog.json"
    }
  }
}
```

手工验收：

1. 启动 `apps/nmer-wails/build/bin/nmer-wails.exe`。
2. 打开生产 CommandPalette。
3. 执行：

```powershell
curl.exe -X POST `
  -H "Content-Type: application/x-ndjson" `
  --data-binary "@apps/nmer-wails/poc/testdata/a2ui-command-palette.jsonl" `
  http://127.0.0.1:18791/a2ui/ingest
```

预期：

- CommandPalette 自动创建 `p2-a2ui-demo` 卡片。
- 标题最终显示“P2 · JSONL 流转发完成”。
- 旧 Markdown 安全回复仍在卡片中。
- 点击“安全回调”后，Go 返回 `accepted`，Fake Provider 推送一个新的 follow-up Surface，最后返回 `completed`。
- Fixture 页面中的按钮保持本地运行，不会误发到 Go。

剩余 P2：

- Provider 身份认证与会话权限。
- 多 Surface 版本冲突策略。

### P3：Provider 接入

按以下顺序接入：

1. `FixtureMessageSource`
2. Fake 流式 Provider（已完成）
3. 通用 HTTP Adapter Provider（已完成）
4. Hermes/OpenAI-compatible Provider（已完成实验适配）
5. Gemini
6. Claude/GPT
7. Ollama

渲染层只接受统一 A2UI 消息，不感知具体模型。

当前 Action 契约：

- WebSocket 上行类型：`official_a2ui_action`
- 契约版本：`nmer.a2ui.action.v1`
- 仅允许：`safe.follow-up`
- 必须携带：`requestId/correlationId/cardId/surfaceId/componentId/abortId`
- Go 侧执行：10 秒 `requestId` 去重、深度上限 2、超时范围 100ms–30s
- 回执类型：`official_a2ui_action_result`
- 回执状态：`accepted/completed/rejected/timeout/cancelled`
- 取消上行：`official_a2ui_abort`，由 `requestId + abortId` 精确取消 Go context

Fake Provider 手工验收：

1. 先按 P2 命令注入 `a2ui-command-palette.jsonl`。
2. 在生成的卡片里填写“补充问题”。
3. 点击“发送安全回调”。
4. 预期原 Surface 被新 follow-up Surface 替换，显示“Fake Provider 回调完成”。
5. 10 秒内重复同一请求应被 Go 拒绝；危险 Action 和深度大于 2 的 Action 必须被拒绝。

Hermes 实验接入：

```powershell
$env:NMER_A2UI_PROVIDER = "openai-chat"
$env:NMER_A2UI_PROVIDER_URL = "http://127.0.0.1:8642/v1"
$env:NMER_A2UI_PROVIDER_MODEL = "hermes-agent"
$env:NMER_A2UI_PROVIDER_TOKEN = "<API_SERVER_KEY>"
.\apps\nmer-wails\build\bin\nmer-wails.exe
```

该模式调用 `/v1/chat/completions`，要求模型仅返回 A2UI v0.9 JSONL。Go 会重新包装
transport envelope，并再次校验 Catalog、组件白名单、Surface 和序列。模型输出 prose、
非法 JSONL 或越权组件时，Action 返回 `rejected`，旧 Markdown/reply 保持可见。

OpenClaw 当前不直接连接 `18789`：该端口属于 Gateway/WebSocket 生命周期，不应假设为
OpenAI-compatible HTTP。正确路线是运行一个 loopback Adapter，并配置：

```powershell
$env:NMER_A2UI_PROVIDER = "http"
$env:NMER_A2UI_PROVIDER_URL = "http://127.0.0.1:18801/a2ui/action"
```

Adapter 接收 `nmer.a2ui.action.v1`，返回 `nmer.a2ui.transport.v1` JSONL。这样未来替换
OpenClaw、Hermes 或 SimpleAgent 时，CommandPalette 与 TS renderer 不需要变化。

### P4：生产灰度

1. 默认继续使用旧 NMER 通道。
2. 仅特定命令或开发开关启用官方 A2UI。
3. 记录成功率、fallback 率、动作超时和内存峰值。
4. 达到稳定指标后再提高官方 A2UI 流量。

## 8. 暂停线

出现任意一项立即停止扩大接入范围：

- 128 项 Fixtures 有失败
- Wails 或 CommandPalette 白屏
- Surface 切换后组件未释放
- WebView2 私有内存持续增长
- Action 可绕过 `kind: safe`
- fallback 无法恢复为可读文本
- Provider 逻辑进入 Lit 组件

这些暂停线用于避免“小裂缝积累成洪水”。
