# NMER Wails POC（B1 + 三 POC）

Wails **v2** 工程，含三个迁移验证 POC：

| POC | 路径 | 验证内容 |
|-----|------|----------|
| **POC 1** | `frontend/src/poc/fakeProvider.ts` + `agentReducer.ts` + `litRenderer.ts` | 进程内 Fake Provider → AgentEvent → `blocks[]` → Lit |
| **POC 2** | `poc/wshub.go` + `frontend/src/poc/wsClient.ts` | Go WebSocket Hub（`:18791`）+ 断线重连 + hello 重放 + Wails `EventsEmit` |
| **POC 3** | `frontend/src/a2ui-spike/` | 官方 A2UI v0.9 MessageProcessor + Lit renderer + 安全降级 |

**当前边界：** CommandPalette 已可通过本地 WS 使用官方 A2UI；Hermes/OpenAI-compatible 服务可作为实验 Provider。OpenClaw 与 AHK 主编排仍未迁移。

迁移边界：[`docs/wails-migration-boundary.md`](../../docs/wails-migration-boundary.md)

A2UI 操作说明：[`docs/a2ui-v0.9-spike-guide.md`](../../docs/a2ui-v0.9-spike-guide.md)

## 环境

- Go 1.22+、Node 20.19+（或 22.12+）、WebView2 Runtime
- Wails CLI v2：`go install github.com/wailsapp/wails/v2/cmd/wails@latest`

## 开发

```powershell
cd apps/nmer-wails
wails dev
```

界面包含三个 POC：

- **左**：点「运行 Fake 演示」— 走 TS reducer + Lit（不经过网络）
- **右**：自动连接 `ws://127.0.0.1:18791/agent/ws`；点「Go Fake Pump」由 Go 侧推送同一脚本事件
- **下方**：官方 A2UI v0.9 固定 Fixture、按钮回调与失败护栏演练

## 构建

```powershell
# 推荐：仓库根目录一键构建
powershell -ExecutionPolicy Bypass -File scripts/Build-NmerWails.ps1

# 或手动（勿直接 go build，会缺 Wails build tags）
cd apps/nmer-wails
wails build
# → build/bin/nmer-wails.exe
```

## 自动测试（无 Wails）

```powershell
cd apps/nmer-wails/frontend
npm install
npm run test:a2ui
npm run test:reducer
npx tsc --noEmit
npm run build
npm run build:palette-a2ui
```

`build:palette-a2ui` 输出供现有 CommandPalette WebView2 使用的独立包：

```text
html/vendor/a2ui/nmer-a2ui-v09.js
```

## Go 绑定（POC 2）

| 方法 | 说明 |
|------|------|
| `GetAppInfo()` | 应用元信息 |
| `GetWsUrl()` | WebSocket URL |
| `GetWsHubStatus()` | 连接数 / pump 状态 |
| `StartWsFakePump()` / `StopWsFakePump()` | Go 侧脚本事件泵 |

Wails 事件：`ws:agent_event`、`ws:hub_status`

## P2 官方 A2UI JSONL

入口：

```text
POST http://127.0.0.1:18791/a2ui/ingest
Content-Type: application/x-ndjson
```

测试：

```powershell
curl.exe -X POST `
  -H "Content-Type: application/x-ndjson" `
  --data-binary "@poc/testdata/a2ui-command-palette.jsonl" `
  http://127.0.0.1:18791/a2ui/ingest
```

Go 校验通过后，通过 `/agent/ws` 广播 `official_a2ui_event`。

## P3 A2UI Provider

默认仍使用内置 Fake Provider：

```powershell
$env:NMER_A2UI_PROVIDER = "fake"
.\build\bin\nmer-wails.exe
```

Hermes/OpenAI-compatible Provider：

```powershell
$env:NMER_A2UI_PROVIDER = "openai-chat"
$env:NMER_A2UI_PROVIDER_URL = "http://127.0.0.1:8642/v1"
$env:NMER_A2UI_PROVIDER_MODEL = "hermes-agent"
$env:NMER_A2UI_PROVIDER_TOKEN = "<API_SERVER_KEY>"
.\build\bin\nmer-wails.exe
```

通用 OpenClaw/sidecar Adapter：

```powershell
$env:NMER_A2UI_PROVIDER = "http"
$env:NMER_A2UI_PROVIDER_URL = "http://127.0.0.1:18801/a2ui/action"
$env:NMER_A2UI_PROVIDER_TOKEN = "<adapter-token>"
.\build\bin\nmer-wails.exe
```

`http` 模式向 Adapter POST `nmer.a2ui.action.v1`，响应必须是
`application/x-ndjson` 的 `nmer.a2ui.transport.v1` 信封。默认只允许 loopback；
远程地址必须显式设置 `NMER_A2UI_ALLOW_REMOTE_PROVIDER=true`。

测试或并行实例可设置独立监听地址：

```powershell
$env:NMER_A2UI_BRIDGE_ADDR = "127.0.0.1:18792"
.\build\bin\nmer-wails.exe
```

## 目录

```
apps/nmer-wails/
├── poc/                    # Go WS hub + fake pump
├── app.go / main.go
└── frontend/src/
    ├── poc/                # TS reducer、Lit 组件、ws 客户端
    └── a2ui-spike/         # 官方 A2UI v0.9 隔离 Spike
```

## 安全

禁止 embed `local/`、`Data/`、`Cache/`、`*.db`、真实 `.env`。
