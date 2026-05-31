# 牛马 nmer — Agent / 大模型定制入口

## 用户定制数据（优先只改这些）

| 文件 | 用途 |
|------|------|
| `config/user_studio.json` | 大模型 API、本机软件路径、扩展选项 |
| `config/user_studio.defaults.json` | 还原默认时的模板（勿删） |
| `CursorShortcut.ini` | 主程序设置（热键、主题等） |

## 设置页入口

- `CapsLock + Q` → 设置中心 → **智能定制** 标签
- 功能：软件总览、填写 API Key / Base URL / 模型、标注路径、跳转 **Niuma Chat → 终端定制（ttyd）**、导出/导入/还原定制包

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

## 约束

- 不要修改 `牛马.ahk` 或 `modules/*.ahk`，除非用户明确要求高级钩子。
- 保存 `user_studio.json` 前会自动备份到 `config/user_studio.backup.json`。
- 「还原默认定制」仅重置 `user_studio.json`，不重置整个 `CursorShortcut.ini`。

## Niuma Chat 项目背景

- 默认说明：`docs/niuma-project-brief.md`（打开牛马 Chat 时自动注入 System Prompt）
- 智能定制 →「Niuma Chat 项目背景」可覆盖或关闭自动注入

## 更多文档

- `docs/TEXT_HOLE_FLOW.md` — 文本黑洞交互
- `软件介绍.md` — 功能总览
