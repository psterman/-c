# 配置清单

| 配置项 | 路径 | Owner | 读写模块 | 含密钥 |
|--------|------|-------|----------|--------|
| 主 INI | `local/CursorShortcut.ini` 或 `ConfigFile` | 用户设置 | `ConfigManager`, `LegacyConfigGui` | 否 |
| 全文索引 | `Data/fulltext_config.json` | SearchCore | `SearchCoreLifecycle`, Go `fulltext_filter` | 否 |
| 用户工作室 | `local/user_studio.json` | LLM/Agent | `UserStudio`, `SecretVault` | 是（apiKey → DPAPI） |
| 聊天 LLM | `local/niuma_chat_llm.json` | Niuma Chat | `UserStudio` | 是 |
| 命令表 | `Data/Commands.json` | 命令面板 | `CommandPaletteCore`, `TrayMenuManager` | 否 |
| VK 键位 | `Data/vk_keymap.json` | 虚拟键盘 | `VirtualKeyboardCore` | 否 |
| 剪贴板 DB | `Data/clipboard.db` | 剪贴板 | `ClipboardFTS5`, `ClipboardPanelCore` | 否 |
| 调试日志 | `Cache/debug/` | 运行时 | `NmerDiagnostics`, `NMER_Log` | 否 |

## 读取约定

新代码使用 `NmerConfig_Get(section, key, default)`（`modules/ConfigManager.ahk`），勿硬编码散落路径。

已知 section/key：

- `fulltext` / `path` → `fulltext_config.json`
- `studio` / `path` → `user_studio.json`
- `commands` / `path` → `Commands.json`
- `cursor` / `shortcut_ini` → `CursorShortcut.ini`
- 其他键回退到主 `ConfigFile` INI 的 section/key

路径根目录由 `modules/LocalPaths.ahk`（`Nmer_DataDir`, `Nmer_LocalDir`, `Nmer_CacheDir`）统一解析。

## 依赖版本

见 `tools/deps.lock.json`（AHK v2 / WebView2 / Go 最低版本；SearchCenterCore 构建版本经 `/health` 响应与 `X-SearchCenterCore-Version` 头暴露）。

## Go 全文 P0-1 / P0-2

已在 `searchcore/root_policy.go` 与 `fulltext_filter_windows.go` 落地：

- `autoDiscoverRoots: false` 使用 `*bool`，不会被默认 `true` 覆盖
- 显式 `knowledgeRoots` 优先于自动发现；无确认根时进入 `RootSetupRequired`
