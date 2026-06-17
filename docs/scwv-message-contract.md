# SCWV 消息契约（SearchCenter WebView）

> **术语**：组织成熟度 L0–L5、执行 Phase 0–4、契约 anchor/stable/production 的定义见 [`stack-governance.md` §0](stack-governance.md#0-术语映射必读)。**不得将「L3 组织成熟度」与「production 契约」混读。**

## 当前状态

| 字段 | 值 |
|------|-----|
| **契约成熟度** | **production** |
| **schemaVersion** | `1` |
| **机器可读清单** | [`tools/ci/scwv-contract-types.json`](../tools/ci/scwv-contract-types.json) |
| **回归 fixtures** | `node html/scwv/run-scwv-contract-fixtures.mjs` |
| **漂移门禁** | `tools/ci/Validate-ScwvMessageContract.ps1` |
| **合入阻断** | **是**（`Run-MinimalGate.ps1 -Strict` 含 **Contract Production** 套件） |

**与 L3 的区分**：契约 **production** 只表示消息协议变更须过门禁；组织成熟度目标仍约 **L3**（非 L4/L5）。

---

## 范围

- **宿主**：`modules/SearchCenterWebViewCore.ahk`（`SCWV_ProcessWebMessageJson`）
- **面板**：`html/SearchCenter.html`（`postToAhk` / `chrome.webview` listener）
- **方向**：WebView → AHK（上行）；AHK → WebView（`init` / `state` 等下行）

---

## 消息外形（production）

```json
{
  "type": "<白名单见 manifest>",
  "schemaVersion": 1
}
```

- `type` 与历史 `action`：宿主仍兼容 `action`；**新消息只用 `type`**。
- 未知 `type`：宿主记日志并忽略，不得静默改默认行为。
- **production 变更规则**：改 `type` 或关键 payload → 同步 manifest、本文件、fixtures；`Run-MinimalGate.ps1 -Strict` 必须绿。

---

## WebView → AHK（上行）

完整列表以 [`scwv-contract-types.json`](../tools/ci/scwv-contract-types.json) 的 `inbound.webToAhk` 为准（**64** 项）。

### 关键 payload（production 已文档化）

| type | 必填字段 | 说明 |
|------|----------|------|
| `ready` | `type` | 面板脚本就绪 |
| `search` | `keyword` | 本地/混合搜索 |
| `searchGoRequest` | `keyword` | 导航式搜索 |
| `setUiMode` | `mode` | `local` / `web` / `cli` |
| `setCategory` | `category` | 分类键 |
| `setFilter` | `filterType`, `keyword` | 子过滤器 |
| `cliSend` | `prompt` | CLI 发送 |
| `lifecycle` | `phase` | 如 `close_request` |
| `NATIVE_PREVIEW` | `path`, `seq` | 原生预览 |
| `QUICKLOOK` | `path`, `row` | QuickLook 集成 |
| `scHotkeyBindingsSync` | `payload.entries` | 热键绑定同步 |

代表样本见 [`html/scwv/scwv-contract.fixtures.json`](../html/scwv/scwv-contract.fixtures.json)。

### 仅宿主侧入口（`inbound.ahkOnly`）

HTML 未发送但 AHK 已实现的 `type`：见 manifest `inbound.ahkOnly`。

---

## AHK → WebView（下行）

代表 `type` 见 manifest `outbound.ahkToWeb`。核心：`init` / `state` / `lifecycle` / `set_theme` / `fulltextStatus` / `hostPaintNudge` / `RESET_STATE` 等。

---

## 成熟度路线图

| 阶段 | 标志 | 门禁 |
|------|------|------|
| anchor | 白名单 + schemaVersion 占位 | 无 |
| stable | manifest + fixtures + 漂移门 | DevMenu optional |
| **production**（**当前**） | 升 **MinimalGate required**（`-Strict`） | **合入阻断** |

---

## 变更记录

| 日期 | 成熟度 | 说明 |
|------|--------|------|
| 2026-06 | anchor | 初版白名单 |
| 2026-06 | stable | manifest、fixtures、漂移门 |
| 2026-06 | **production** | 纳入 `Run-MinimalGate.ps1 -Strict` Contract Production 套件 |
