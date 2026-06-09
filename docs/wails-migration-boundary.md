# Wails 迁移边界说明

本文档定义牛马 nmer 迁入 Wails 的架构边界与批次约定（B0+），**不含** OpenClaw/Hermes 业务适配实现。

## 当前状态

- `apps/nmer-wails/` 已是可执行 `wails build` 的 Wails v2 POC。
- 已包含 Fake Provider、WebSocket Hub、官方 A2UI v0.9 三个隔离验证 POC。
- 历史原型 `archive/prototype/wails-toolbar-app/` 已从 Git 删除；现网命令栏由 **AHK + WebView2**（`CommandPaletteCore.ahk`）承载。
- 兼容层仍保留：`WailsNativeInput.ahk`、`WailsWhisperVoice.ahk`、`CursorPanelController.ahk` 中的 `nmer-wails-input.exe` 回退路径（`CommandPaletteUseWebView=false` 时）。

## 目标工程位置

| 项 | 约定 |
|----|------|
| Wails 工程目录 | **`apps/nmer-wails/`** |
| MVP 版本 | **Wails v2**（稳定版） |
| v3 评估时机 | 多窗合一需求明确 **且** v3 进入 beta/stable 后 |

## 职责划分

| 层 | 职责 |
|----|------|
| **AHK** | 全局热键、窗口激活/置顶、系统级动作（截图、剪贴板、进程编排）、WebView2 宿主（过渡期） |
| **Go / Wails** | Provider Adapter 壳层、Event Pump、与 AHK 的 IPC/WS 桥接（可复用 `tools/native-drop-bridge` 思路） |
| **TypeScript** | Reducer、Renderer Registry、面板 UI（可从 `html/` 逐步迁入 `apps/nmer-wails/frontend`） |

## 禁止打包进 Wails 的内容

以下内容**不得**进入 Wails `embed` 或 `frontend/dist` 构建产物：

- `local/**`（含 API Key、`user_studio.json`、`openclaw-state/`）
- `Data/**`
- `Cache/**`
- 任意 `*.db` / `*.db-wal` / `*.db-shm`
- 含真实值的 `.env`（仅提交根目录 `env.example`）

用户密钥应继续仅存 `local/` 或系统用户目录；环境变量说明见根目录 [`env.example`](../env.example)。

## 相关 Go 侧车（非 Wails）

- [`tools/native-drop-bridge/interaction_manager.go`](../tools/native-drop-bridge/interaction_manager.go) — 五状态 FSM + `WindowController`（WebSocket `:18790`）
- 详见 [`md/docs/INTERACTION_MANAGER.md`](../md/docs/INTERACTION_MANAGER.md)

## 建议迁移批次（摘要）

1. **B0 / B0.5** — `.gitignore`、`env.example`、文档与陈旧引用卫生（已完成）
2. **B1** — `apps/nmer-wails/` v2 POC 可构建（已完成）
3. **B1.5** — 官方 A2UI v0.9 隔离 Spike 与失败护栏（已完成）
4. **B2** — AHK 启动 Wails exe，定义与现有 `postMessage`/WS 桥接
5. **B3** — 单窗 MVP（优先 CommandPalette）
6. **B4** — 退役 `nmer-wails-input.exe` 回退路径（确认无 `CommandPaletteUseWebView=false` 依赖后）
7. **B5（可选）** — v3 多窗合一 POC

官方 A2UI 的测试和迁移顺序见 [`a2ui-v0.9-spike-guide.md`](./a2ui-v0.9-spike-guide.md)。

架构修订、错误码与 FTB 测绘：

- [`a2ui-architecture-v2.md`](./a2ui-architecture-v2.md) — 三表示 + TPA + 回退逻辑
- [`nmer-a2ui-error-v1.md`](./nmer-a2ui-error-v1.md) — 错误码契约草案
- [`ftb-module-map.md`](./ftb-module-map.md) — FloatingToolbarStrip 模块边界

## 代码中仍引用旧 Wails 路径的位置（勿盲删）

以下为**运行时或回退**引用，迁移完成前保留；详见 B0.5 变更报告。

| 文件 | 说明 |
|------|------|
| `modules/CursorPanelController.ahk` | `WailsInput_GetAppRoot()`、`nmer-wails-input.exe` 启动与检测 |
| `modules/WailsNativeInput.ahk` | 窗口句柄查找 |
| `modules/WailsWhisperVoice.ahk` | 语音宿主进程名 |
| `牛马.ahk` | `GDHO_TryStartHoleDevServer()` 历史 Vite 路径 |
| `modules/CommandPaletteCore.ahk` | 注释：已替代 `nmer-wails-input.exe` |
