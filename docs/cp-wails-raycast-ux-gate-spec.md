# P4.1 — Wails Raycast UX Gate（Spec Only）

> **状态**：仅规格，**暂不实现**。默认 `commandPaletteHost` 保持 `ahk`，直至本门禁独立 PASS。

## 目的

Wails CP（`apps/nmer-wails` + `cp-shell-host.ts`）当前为 **POC shell**（嵌在 960×720 窗内、带 badge/边框），不等于 Raycast 级产品 UX。本门禁是 **唯一** 可将 `wailsDefaultEligible` 置为 `true` 的前置条件。

## 与现有门禁的关系

| 门禁 | 作用 | 是否改默认 |
|------|------|------------|
| CP7～10 / `wailsArchitecturePass` | 架构、桥接、内存、hub agent | 否 |
| P0 `cpReleasePass` | AHK 宿主产品发布 | 否（要求 `defaultHost=ahk`） |
| **P4.1 Raycast UX Gate** | Wails 窗体与交互达标 | 是（通过后方可讨论默认 `wails`） |
| P3 `rolloutGatePass` | A2UI 灰度 | **否** — 不得改变 `commandPaletteHost` 或 `wailsDefaultEligible` |

## 参考基准（AHK 产品路径）

[`CommandPaletteCore.ahk`](../modules/CommandPaletteCore.ahk) 已实现的产品 UX：

- 无边框（`-Caption`）、置顶（`+AlwaysOnTop`）
- 屏幕居中、Esc 隐藏
- 打开即焦点在输入框；失焦策略与 Raycast modernization 计划一致

## 待验项（草案，实现时固化）

### 窗体

- [ ] 独立 CP 窗（非嵌套在 960×720 POC 主窗内）
- [ ] 无边框、圆角/阴影（或等价 Raycast 视觉）
- [ ] 置顶与多显示器居中
- [ ] 无 POC badge / 调试 chrome

### 交互

- [ ] CapsLock / 热键打开 ≤ 产品阈值（对齐 PerfGate `show_to_visible`）
- [ ] Esc 隐藏；重复打开状态一致
- [ ] 搜索 / Turbo / Resize 与 AHK 路径行为等价
- [ ] 与 FTB hybrid 并存无抢焦点

### 门禁产物（未来）

- 脚本：`Run-CpWailsRaycastUxGate.ps1`（未实现）
- 报告：`Cache/debug/cp_wails_raycast_ux_gate.json`
- 字段：`overallPass`、`wailsDefaultEligible`（仅本 gate 可置 true）

## 阻塞原因常量

流水线在 gate 未 PASS 时使用：

```text
wailsDefaultBlockedReason = "raycast_ux_gate_not_passed"
```
