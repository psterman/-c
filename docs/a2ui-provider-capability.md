# A2UI ProviderCapability（Wave 3）

Sidecar 内 **A2UI Action Provider** 的能力声明，与 **OpenClaw Adapter**（`POST /a2ui/openclaw/action`）分离。

## 读取

```powershell
curl http://127.0.0.1:18791/agent/health
```

响应示例：

```json
{
  "ok": true,
  "provider": "fake",
  "capability": {
    "provider": "fake",
    "stream": true,
    "action": true,
    "abort": true,
    "routes": ["r3"],
    "experimental": false,
    "description": "in-process fake follow-up surface"
  }
}
```

`GetWsHubStatus()` / `HubStatus.providerCapability` 字段同步。

## 矩阵

| Provider | stream | action | abort | routes | experimental |
|----------|--------|--------|-------|--------|--------------|
| `fake` | yes | yes | yes | r3 | no |
| `http` | yes | yes | yes | r3 | no |
| `openai-chat` | yes | yes | yes | r3 | **yes**（Hermes 实验） |

## 代码

- [`a2ui_provider_capability.go`](../apps/nmer-wails/poc/a2ui_provider_capability.go)
- 环境变量：`NMER_A2UI_PROVIDER`（`fake` / `http` / `openai-chat`）

## 注意

- R1/R2 生产链走 FTB OpenClaw 四标签，**不**由本 Provider 矩阵覆盖。
- 扩大灰度前须 `openai-chat` 与 Adapter 路径隔离（实验 provider 不得污染生产链）。
