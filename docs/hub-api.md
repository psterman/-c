# 牛马 nmer 控制面 API（hub-api）

> 单一 AHK 主进程 + 侧车 exe。控制面只做四件事；**读模型**与**写模型**严格分离。

## 控制面四件事

| 职责 | 读（观测） | 写（控制） | 模块 |
|------|------------|------------|------|
| 侧车生命周期 | `NmerService_IsHealthy` / `ProcessPresent` | `NmerService_Ensure` | [`NmerServiceRegistry.ahk`](../modules/NmerServiceRegistry.ahk) |
| Surface 开关与意图 | `SurfaceManager` 登记 / snapshot 文件 | `SurfaceIntent_Open` / `Close` | [`SurfaceIntentRouter.ahk`](../modules/SurfaceIntentRouter.ahk) |
| LLM provider | `Nmer_Llm_Route("ping")` 等 | 设置保存 / HTTP 聊天 | [`Nmer_LlmProvider.ahk`](../modules/Nmer_LlmProvider.ahk) |
| 健康快照与日志 | `Nmer_BuildHealthSnapshot` | `NMER_Log` / 诊断导出 | [`NmerHealthSummary.ahk`](../modules/NmerHealthSummary.ahk) |

## 读模型 vs 写模型

### 健康快照（只读）

- API：`Nmer_BuildHealthSnapshot(trigger)` → `Nmer_WriteHealthSnapshotJson` → `Cache/debug/health_summary.json`
- **禁止**在快照路径内调用 `NmerService_Ensure`、Intent、自动重试或修复。
- **触发时机**：用户点「刷新」、打开设置健康区、托盘「系统健康」、导出诊断包前补一帧。
- **禁止**后台 `SetTimer` 高频轮询健康。

### 统一健康源

托盘、设置 advanced、诊断导出共用**同一次** `Nmer_CollectHealthSnapshot()` 结果；UI 仅渲染，不得各做独立探针。

| 入口 | 函数 | trigger |
|------|------|---------|
| 托盘「系统健康」 | `Nmer_ShowHealthSnapshotTray` | `tray_refresh` |
| 设置 WebView | `invokeAction` `getHealthSnapshot` | `open_panel` / `user_refresh` |
| 导出诊断包 | `Nmer_ExportDiagnosticsBundle` 开头 | `export_bundle` |

设置消息：

```json
{ "type": "invokeAction", "op": "getHealthSnapshot", "payload": { "trigger": "user_refresh" } }
```

回传：

```json
{ "type": "healthSnapshot", "payload": { "services": [...], "surfaces": [...], "runtime": {...}, "readModel": true } }
```

### 验收标准（P1 健康汇总签收）

> **范围说明**：工程其它位置仍可有历史 `SetTimer`、`Ensure`、局部探针（搜索/FTB/启动链等）。**不要求一次性清除**。本节只约束**健康汇总读模型**与三端 UI，不宣称整机已是统一观测体系。

| # | 标准 | 实现要点 | 手测方法 |
|---|------|----------|----------|
| 1 | 设置 advanced 点「刷新」**只生成一份快照**，不拉起侧车 | `getHealthSnapshot` → `Nmer_CollectHealthSnapshot`；路径内仅 `IsHealthy` / `ProcessPresent` / 读 JSON 文件；**无** `Ensure`、**无**健康 `SetTimer` | 未运行 ttyd 时刷新，侧车数不变；`studio_llm_test` 无关；观察进程列表 |
| 2 | 托盘健康、设置健康、诊断导出**同一数据源** | 均经 `Nmer_CollectHealthSnapshot()` 写入同一 `health_summary.json`；UI 只渲染 | 连续：托盘「系统健康」→ 设置刷新 → 导出诊断包；对比 `servicesHealthy` / `generatedAt` |
| 3 | 快照文件存在且结构稳定 | [`Cache/debug/health_summary.json`](../Cache/debug/health_summary.json)；含 `readModel:true`、`services`、`surfaces`、`runtime`、`trigger` | 刷新后打开 JSON；字段齐全；`trigger` 与操作一致 |
| 4 | `SurfaceRuntimeManager` **只登记/写日志**，健康路径不借它做控制决策 | 健康只**读** `surface_registry_snapshot.json`；**不**调用 `WriteSnapshot` / `SurfaceIntent_*` | 代码：`Nmer_HealthSnapshot_LoadSurfaces` 仅 `FileRead` |
| 5 | `routeIntents=false` 时业务正常，**不影响**健康汇总 | `runtime.surfaceManagerFlags` 只读汇报；快照不依赖 `routeIntents` 为 true | 保持 `nmer-flags.json` 默认；健康卡与托盘仍可用 |

**建议手测顺序**

1. 重载 `牛马.ahk` → 设置 → 系统 → 高级 → 点「刷新快照」
2. 托盘 →「系统健康」→ 摘要应与卡片 `summary.label` 一致（如 `3/4 侧车健康`）
3. 导出诊断包 → 包内 `health_summary.json` 与 `Cache/debug/` 下文件一致（同一 `generatedAt` 或导出前刚刷新）
4. 确认 advanced **无**「尝试拉起 / 修复」类按钮；`invokeAction` **无** `ensureService`

**明确不在本阶段验收**

- 全仓库消灭 `SetTimer` 健康轮询或业务 `Ensure`
- `SurfaceRuntime` 接管全部 Open/Close
- 健康面板自动修复侧车

### 写模型（不进健康 UI）

- 侧车拉起/重启：业务入口调用 `NmerService_Ensure`（**不在**健康卡片提供按钮）。
- 打开/关闭面板：**新入口**经 `SurfaceIntent_*`（见下节）；Legacy `Show*` 仅 fallback。
- 诊断导出：`Nmer_ExportDiagnosticsBundle`（写操作，但会先补一帧只读快照）。

## Surface 意图（写模型）

统一入口：[`SurfaceIntentRouter.ahk`](../modules/SurfaceIntentRouter.ahk)。**不**新增 `CfgRouter` / `FtbRouter` 等换名中间层。

### Surface ID

| surfaceId | 角色 | 执行落点 |
|-----------|------|----------|
| `search_center` | primary | `SCWV_OpenUnified` / `SCWV_Show` |
| `command_palette` | primary | `CommandPalette_Show` |
| `clipboard_panel` | secondary | `CP_Show` |
| `config_webview` | secondary | `ShowConfigWebViewGUI` |
| `floating_toolbar` | resident | `ShowFloatingToolbar` |
| `prompt_quick_pad` | secondary | `PQP_Show` |
| `virtual_keyboard` | secondary | `VK_Show` |

登记簿观测：`SurfaceRuntimeManager` 写 `surface_registry_snapshot.json`；健康快照**只读**该文件。

### 推荐 API

| 场景 | 调用 | 说明 |
|------|------|------|
| 打开设置 | `SurfaceIntent_OpenConfig(meta)` | 内部仍走 `ShowConfigGUI_Safe` 防御链 |
| 打开剪贴板面板 | `SurfaceIntent_OpenClipboardPanel(meta)` | → `clipboard_panel` |
| 打开搜索（统一） | `SurfaceIntent_OpenSearch(kw, src)` | → `search_center` unified |
| 打开剪贴板时间线（统一） | `SurfaceIntent_OpenClipboardUnified(kw, src)` | → `search_center` clipboard 模式 |
| 通用开/关 | `SurfaceIntent_Open` / `Close` | 带 `meta`：`triggerSource`、`reason` |

`meta` 示例：

```ahk
SurfaceIntent_OpenClipboardPanel(Map("triggerSource", "tray_menu", "reason", "tray_open_clipboard"))
SurfaceIntent_OpenConfig(Map("navigateTab", "advanced", "triggerSource", "tray_health"))
```

### shadow 模式与 routeIntents

默认 `local/nmer-flags.json`：`surfaceManager.shadowMode=true`，`routeIntents=false`。

- **shadowMode**：`SurfaceIntent_Open` 仍执行底层 `Show*`，并在登记簿记录 `intent_open` / `SurfaceManager_Request`（观测用）。
- **routeIntents=true**（仅开发机试验）：`RouteExternalOpen` 拦截模块内直调，强制经 Intent；**非**当前默认。

**本阶段不**以 `routeIntents` 全开作为验收条件；SurfaceRuntime **不**接管全部控制逻辑。

### 禁止（新代码）

- 直调 `LegacyConfigGui_Show`
- 新触达点直调 `ShowClipboardManager`（Legacy ListView）；应 `SurfaceIntent_OpenClipboardPanel`，Legacy 仅 catch fallback
- 为改名而拆 domain router 层

## 新功能约定

| 场景 | 应使用 | 禁止（新代码） |
|------|--------|----------------|
| 打开设置 | `SurfaceIntent_OpenConfig` / `Open("config_webview")` | 直调 `LegacyConfigGui_Show` |
| 打开剪贴板 | `SurfaceIntent_OpenClipboardPanel` | 直调 `ShowClipboardManager` |
| 侧车状态展示 | `Nmer_BuildHealthSnapshot` | 页面内散落 `ProcessExist` + `Ensure` |
| 侧车修复 | 各业务模块 `NmerService_Ensure` | 健康面板内嵌修复 |
| LLM HTTP | `Nmer_Llm_Route("ping")` / `BuildHttpChat` | 模块内自建 URL；绕过 Route 的分散 ping |
| 设置 iframe 消息 | 壳 `postMessage` → `ConfigWebView_OnMessage` | 子 iframe 直 `hostObjects` |
| 日志 | `NMER_Log` / `NmerCatch` | 裸 `catch {}` |

## SurfaceRuntime：登记簿

[`SurfaceRuntimeManager.ahk`](../modules/SurfaceRuntimeManager.ahk) 负责 Register / RecordEvent；健康快照**只读** `surface_registry_snapshot.json`，不接管路由。

## Legacy

- `UseWebViewSettings=true`、`g_ConfigPreferWebViewOnly=true` 为默认；**Legacy 源码冻结不扩张**。
- 新功能不得在非 `Legacy*` 模块新增 `LegacyConfigGui_Show` / `ShowClipboardManager` 直调；应走 `SurfaceIntent_*`。
- CI：`tools/ci/Validate-LegacyBypass.ps1`（白名单 `legacy-bypass-allowlist.txt`）；`Run-MinimalGate.ps1 -Strict` 纳入。
- 运行时 fallback 保留（如 `ShowConfigGUI_Core` → WebView 失败 → `LegacyConfigGui_Show`），**不删文件**。
- 详见 [`module-inventory.md`](module-inventory.md) 表 2。

## 相关文档

- 日志事件：[`nmer-must-log-events.md`](nmer-must-log-events.md)
- LLM 契约：[`llm-provider-contract.md`](llm-provider-contract.md)
- 仓库约定：[`nmer-conventions.md`](nmer-conventions.md)
- Legacy CI：`tools/ci/Validate-LegacyBypass.ps1`
