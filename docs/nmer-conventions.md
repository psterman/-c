# 牛马 nmer 仓库约定

## 路径与配置

- 读写用户路径统一经 [`LocalPaths.ahk`](../modules/LocalPaths.ahk) 或 `NmerConfig_Get()`（见 [`config-inventory.md`](config-inventory.md)）。
- 路径 ID 清单：[`nmer-paths-inventory.md`](nmer-paths-inventory.md)。
- **`local/` 已存在文件不会在启动时自动覆盖**；`Nmer_Migrate*` / `UserStudio_Load` 仅在目标缺失时复制或补全。

## 错误处理

- 业务 catch 优先 `NmerCatch(scope, err)`（见 [`NmerCatch.ahk`](../modules/NmerCatch.ahk)）。
- 空 `catch {}` 审计：`tools/CatchAudit.ps1`；策略门：`tools/ci/Validate-CatchPolicy.ps1`。

## 密钥

- 对外 API：[`Nmer_SecretStore.ahk`](../modules/Nmer_SecretStore.ahk)（内部 DPAPI：`SecretVault.ahk`）。
- `user_studio.json` 迁移后设 `secretsEncrypted: true`，明文 `apiKey` 字段置空。
- 迁移：`Nmer_SecretStore_MigrateUserStudioPlaintext()` 或 `tools/Migrate-PlaintextSecrets.ps1`。
- 企业说明：[nmer-enterprise-ops.md](nmer-enterprise-ops.md) §2。

## 设置页 iframe

- 壳：[`html/SettingsPanel.html`](../html/SettingsPanel.html) + [`html/settings/settings-bridge.js`](../html/settings/settings-bridge.js)。
- 子页禁止直接 `chrome.webview`；经 `postMessage` 由壳转发（与 AHK `ConfigWebViewModule` message type 不变）。
- 分组：General / Prompts / Hotkeys / System / Workspace（见治理计划 §6）。

## WebSocket 安全

- Hub：[`apps/nmer-wails/poc/wshub.go`](../apps/nmer-wails/poc/wshub.go) — `CheckOrigin` 白名单 + `NMER_WS_HUB_TOKEN` 查询参数。
- 修改 Go 后需在 `apps/nmer-wails/poc` 目录本地 `go build` 并重部署对应二进制（无 CI 自动发布）。

## SQL

- 用户输入进 SQLite 须经 [`SqlSafe.ahk`](../modules/SqlSafe.ahk)；FTS5 用 `SqlSafe_Fts5Escape`。
- 门：`tools/ci/Validate-SqlPolicy.ps1`。

## Git 与提交

- 中文 commit subject，见 [`.cursor/rules/commit-zh.mdc`](../.cursor/rules/commit-zh.mdc)。
- 混栈治理手册：[`docs/stack-governance.md`](stack-governance.md)（术语、DevMenu、契约 **production**）。
- 本地开发菜单：`tools/dev/Run-DevMenu.ps1`（required/optional 分项 + Summary）。
- 契约 production 门禁：`Run-MinimalGate.ps1 -Strict`（含 `Run-Phase3ContractSuite.ps1 -Required`）；单独跑见 `ci-minimal-gate.md`。
- 最小 CI 门（本地）：[`docs/ci-minimal-gate.md`](ci-minimal-gate.md) → `tools/ci/Run-MinimalGate.ps1 -Strict`。
- PR 自检：[`docs/pull-request-checklist.md`](pull-request-checklist.md)。
- PR 改 Hub / palette A2UI 时：[`docs/pr-architecture-discipline.md`](pr-architecture-discipline.md)。

## Agent 修改范围

见 [`md/AGENTS.md`](../md/AGENTS.md)：治理计划文档/运维脚本/约定范围内的 `modules/`、`tools/` 修改允许。

## 控制面与读模型

- 控制面只做四件事：侧车生命周期、Surface 意图、LLM provider、健康快照与日志。
- **健康快照是读模型**：`Nmer_BuildHealthSnapshot` 只观测，禁止混入 `Ensure` 或自动修复；详见 [`hub-api.md`](hub-api.md)。
- **Surface 开关是写模型**：新入口经 `SurfaceIntent_OpenConfig` / `OpenClipboardPanel` / `Open`；详见 hub-api §Surface 意图。
- 托盘、设置 advanced、诊断导出共用 `health_summary.json`，禁止各端独立探针或后台健康轮询。
- **Legacy 冻结**：新模块不得直调 `LegacyConfigGui_Show` / `ShowClipboardManager`；CI 见 `Validate-LegacyBypass.ps1`。
