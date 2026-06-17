# 牛马 nmer — Agent / 大模型定制入口

## 用户定制数据（优先只改这些）

| 文件 | 用途 |
|------|------|
| `local/user_studio.json` | 大模型 API、本机软件路径、扩展选项 |
| `config/user_studio.defaults.json` | 还原默认时的模板（勿删） |
| `local/CursorShortcut.ini` | 主程序设置（热键、主题等）；`SummonHotkeyPreset` / `CapsLockMode` 见 `[Settings]` |
| `local/openclaw-state/` | OpenClaw CLI 工作区状态 |

## 设置页入口

- `CapsLock + Q` → 设置中心 → **智能定制** 标签
- 功能：软件总览、填写 API Key / Base URL / 模型、标注路径、跳转 **Niuma Chat → 终端定制（ttyd）**、**导出/导入/还原定制包**（仅 `user_studio.json`）
- **换机 / 完整备份**：设置 → **存储与缓存** → **数据迁移**（迁移包，含 INI、OpenClaw、剪贴板库等；**不含** DPAPI vault，导入后需重填 Key）

## 定制包 vs 迁移包

| 类型 | 入口 | 内容 |
|------|------|------|
| 定制包 | 智能定制 → 导出/导入定制包 | 仅 `local/user_studio.json` |
| 迁移包 | 存储与缓存 → 数据迁移 | local 配置、Data 状态/库、OpenClaw、Chat runtime 等 |
| 诊断包 | 高级 → 导出诊断包 | `Cache/debug` 日志（排障用） |

## 定制 JSON 结构

```json
{
  "version": 1,
  "llm": { "provider": "openai", "apiKey": "", "baseUrl": "https://api.openai.com/v1", "model": "gpt-4o-mini" },
  "paths": { "cursor": "", "autohotkey": "", "everything": "", "python": "", "notes": "" },
  "ttyd": { "shell": "cmd.exe", "workDir": "", "port": 7691 },
  "options": {},
  "updatedAt": ""
}
```

## PR / 架构纪律

- 混栈治理术语与 DevMenu： [docs/stack-governance.md](../docs/stack-governance.md)（**L3 ≠ SCWV production**）。
- SearchCenter WebView 消息契约（当前 **production**，`-Strict` 进门禁）： [docs/scwv-message-contract.md](../docs/scwv-message-contract.md)。
- 合入自检： [docs/pull-request-checklist.md](../docs/pull-request-checklist.md)。
- 改 Hub、命令面板 A2UI 时： [docs/pr-architecture-discipline.md](../docs/pr-architecture-discipline.md)（**禁止 Go/TS 双写 Surface 状态**）。

## 约束

- 不要修改 `牛马.ahk` 或 `modules/*.ahk`，除非用户明确要求高级钩子。
- **例外**：治理 plan 档 **§1–§3**（路径清单、运维脚本、约定文档）范围内的新增/修改，或用户显式列出的必做项，可改 `modules/` 与 `tools/`。
- 保存 `user_studio.json` 前会自动备份到 `local/user_studio.backup.json`。
- 「还原默认定制」仅重置 `user_studio.json`，不重置整个 `local/CursorShortcut.ini`。
- 主唤起键：`CursorShortcut.ini` `[Settings]` 中 `SummonHotkeyPreset`（`alt_space`/`ctrl_space`/`win_space`/`capslock`/`custom`）、`SummonHotkeyCustom`、`CapsLockMode`（`chord`/`off`）；渐进解锁状态在 `Data/state/onboarding_hotkeys.json`。

## Niuma Chat 项目背景

- 默认说明：`md/docs/niuma-project-brief.md`（打开牛马 Chat 时自动注入 System Prompt）
- 智能定制 →「Niuma Chat 项目背景」可覆盖或关闭自动注入

## 更多文档

- `md/docs/TEXT_HOLE_FLOW.md` — 文本黑洞交互
- `md/软件介绍.md` — 功能总览
