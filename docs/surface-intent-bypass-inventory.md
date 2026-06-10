# Surface Intent 旁路清单（S0 → S2）

> 生成时间：2026-06-09；S2 更新：2026-06-08  
> 用途：S2 Intent Router 改造对照表；P0+P1 清零后方可宣称「无生产旁路」。

## S2 状态（`routeIntents: true`）

| 项 | 状态 |
|----|------|
| `SurfaceIntentRouter.ahk` | 已落地：`Open/Close/Dispose` + `OpenSearch` / `OpenClipboardUnified` |
| P0 外部入口（牛马/托盘/热键） | **已迁移** |
| P1 模块互调 | **已迁移**（`LegacyConfigGui`、`ScreenshotWorkflow`、`SearchCenterLegacyGui` 等） |
| INTERNAL executor | 保留 `*_Show/Hide` 于各 Core 模块内，仅 Router `_Execute*` 调用 |
| 已知例外 | `VirtualKeyboard.ahk` 独立进程，无 Router include，直调 `VK_Show/Hide` |
| 验证 | `surface_runtime.ndjson` 应出现 `intent_open/close/dispose`；`routeIntents:false` 回退待测 |

## 图例

| 类别 | 说明 |
|------|------|
| **P0 外部入口** | 牛马/FTB/热键/托盘等，必须改 `SurfaceIntent_*` |
| **P1 模块互调** | 跨模块 Show/Open，必须改 Intent |
| **INTERNAL** | 同模块内 executor / 定时器 / GUI 事件，S2 可保留或下沉为 `_Exec` |
| **MANAGER** | `SurfaceRuntimeManager` 仲裁调用，S1 改 `SurfaceExecutor_*` |

---

## Search（search_center）

| 文件 | 行 | 调用 | 类别 | S2 目标 |
|------|-----|------|------|---------|
| `牛马.ahk` | 6448, 6576, 6719 | `SCWV_OpenUnified(...)` | P0 | `SurfaceIntent_Open("search_center", ...)` |
| `modules/TrayMenuManager.ahk` | 854, 862, 934 | `SCWV_OpenUnified` | P0 | Intent |
| `modules/CapsLockDynamicHotkey.ahk` | 92 | `SCWV_OpenUnified("clipboard",...)` | P0 | Intent → search/clipboard |
| `modules/ClipboardPanelCore.ahk` | 387 | `SCWV_OpenUnified("clipboard",...)` | P1 | Intent |
| `modules/VirtualKeyboardExecCmd.ahk` | 420 | `SCWV_OpenUnified` | P1 | Intent |
| `modules/SearchCenterLegacyGui.ahk` | 565 | `SCWV_OpenUnified` | INTERNAL | 合并进 Router |
| `modules/SearchCenterWebViewCore.ahk` | 624, 703, 2905+ | `SCWV_Show` | INTERNAL | 降为 `_Exec` |
| `modules/FloatingToolbar.ahk` | 5192, 5199 | `SCWV_Hide` | P1 | `SurfaceIntent_Close` |

## Command Palette（command_palette）

| 文件 | 行 | 调用 | 类别 | S2 目标 |
|------|-----|------|------|---------|
| `modules/CursorPanelController.ahk` | 826, 1101 | `CommandPalette_Show` | P0 | Intent |
| `modules/WailsWhisperVoice.ahk` | 202, 388 | `CommandPalette_Show` | P1 | Intent |
| `modules/CommandPaletteCore.ahk` | 417+ | `CommandPalette_Show/Hide` | INTERNAL | `_Exec` |

## Clipboard（clipboard_panel）

| 文件 | 行 | 调用 | 类别 | S2 目标 |
|------|-----|------|------|---------|
| `牛马.ahk` | 6895 | `CP_Show` | P0 | Intent |
| `modules/FloatingToolbar.ahk` | 1992, 5156, 5243 | `CP_Show/Hide` | P0/P1 | Intent |
| `modules/TrayMenuManager.ahk` | 954 | `CP_Show` | P0 | Intent |
| `modules/CapsLockDynamicHotkey.ahk` | 100 | `CP_Show` | P0 | Intent |
| `modules/GlobalDragHoleDecoupled.ahk` | 3641 | `CP_Show` | P1 | Intent |
| `modules/LegacyConfigGui.ahk` | 8824, 9924 | `CP_Show/Hide` | P1 | Intent |
| `modules/ClipboardPanelCore.ahk` | 380+ | `CP_Show/Hide` | INTERNAL | `_Exec` |

## Prompt Quick-Pad（prompt_quick_pad）

| 文件 | 行 | 调用 | 类别 | S2 目标 |
|------|-----|------|------|---------|
| `modules/AIListPanel.ahk` | 2395, 2447 | `PQP_Show/Hide` | P1 | Intent |
| `modules/FloatingToolbar.ahk` | 5218, 5225 | `PQP_Hide` | P1 | Intent |
| `modules/PromptQuickPadCore.ahk` | 362+ | `PQP_Show/Hide` | INTERNAL | `_Exec` |

## Virtual Keyboard（virtual_keyboard）

| 文件 | 行 | 调用 | 类别 | S2 目标 |
|------|-----|------|------|---------|
| `modules/CursorPanelController.ahk` | 925, 1087 | `VK_Show/Hide` | P1 | Intent |
| `modules/ConfigWebViewModule.ahk` | 59 | `VK_Show` | P1 | Intent |
| `modules/FloatingToolbar.ahk` | 5301 | `VK_Hide` | P1 | Intent |
| `modules/VirtualKeyboardExecCmd.ahk` | 521, 760 | `VK_Show`, `ShowFloatingToolbar` | P1 | Intent |
| `VirtualKeyboard.ahk` | 32, 34 | `VK_Show/Hide` | P0 | Intent |
| `modules/VirtualKeyboardCore.ahk` | 5320+ | `VK_Show/Hide` | INTERNAL | `_Exec` |

## Config WebView（config_webview）

| 文件 | 行 | 调用 | 类别 | S2 目标 |
|------|-----|------|------|---------|
| `牛马.ahk` | 5162, 5244, 5430 | `ShowConfigWebViewGUI` / `ConfigWebView_Close` | P0 | Intent |
| `modules/FloatingToolbar.ahk` | 5353 | `ShowConfigWebViewGUI` | P0 | Intent |
| `modules/SearchCenterWebViewCore.ahk` | 3640 | `ShowConfigWebViewGUI` | P1 | Intent |
| `modules/ConfigWebViewModule.ahk` | 158+ | Show/Close | INTERNAL | `_Exec` |

## Floating Toolbar（floating_toolbar / resident）

| 文件 | 行 | 调用 | 类别 | S2 目标 |
|------|-----|------|------|---------|
| `牛马.ahk` | 多处 | `Show/HideFloatingToolbar` | P0 | Intent（resident 策略） |
| `modules/CursorPanelController.ahk` | 55 | `ShowFloatingToolbar` | P0 | Intent |
| `modules/CommandPaletteCore.ahk` | 4531 | `ShowFloatingToolbar` | P1 | Intent |
| `modules/FloatingToolbar.ahk` | 1055+ | Show/Hide | INTERNAL | `_Exec` |
| `modules/ScreenshotWorkflow.ahk` | 13 | `ShowFloatingToolbar` | P1 | Intent |

## Manager 仲裁（S1 已改）

| 文件 | 调用 | 备注 |
|------|------|------|
| `modules/SurfaceRuntimeManager.ahk` | `SurfaceExecutor_Suspend/Dispose` | 替代直接 `*_Hide` |

---

## 统计

| 类别 | 约计生产旁路数（去重文件） |
|------|---------------------------|
| P0 外部入口 | 8 文件 |
| P1 模块互调 | 12 文件 |
| INTERNAL | 7 模块内核 |

**S2 完成标准**：P0+P1 行清零；INTERNAL 仅 Router 内 `_Exec` 可调用。
