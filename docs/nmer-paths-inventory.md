# 牛马 nmer 路径清单

> 单一事实来源：[`modules/LocalPaths.ahk`](../modules/LocalPaths.ahk)。配置项语义见 [`config-inventory.md`](config-inventory.md)（密钥段落以本文 + `Nmer_SecretStore` 为准）。

## 图例

| 列 | 说明 |
|----|------|
| 可删 | 用户可整夹/整文件删除后由程序重建或丢失可接受 |
| 含密钥 | 可能含 API Key 或 DPAPI 保护数据 |
| 迁移 | 首次启动 `Nmer_Migrate*` 行为（**仅 missing 时复制**，不覆盖已有） |

## local/（用户私有配置）

| ID | 路径 | Owner | 可删 | 含密钥 | 迁移 |
|----|------|-------|------|--------|------|
| `local.dir` | `{ScriptDir}/local/` | `LocalPaths`, `Nmer_EnsureLocalDir` | 否 | 部分 | `Nmer_MigrateLocalData` |
| `local.config` | `local/CursorShortcut.ini` | `ConfigManager`, `ConfigWebViewModule` | 否 | 否 | 根目录 `CursorShortcut.ini` → local |
| `local.prompt_templates` | `local/PromptTemplates.ini` | 提示词模块 | 否 | 否 | 根目录迁入 |
| `local.user_studio` | `local/user_studio.json` | `UserStudio.ahk` | 否 | 是（迁移后明文为空） | `config/` → local |
| `local.user_studio_backup` | `local/user_studio.backup.json` | `UserStudio` 保存前备份 | 是 | 可能 | 同上 |
| `local.secrets_vault` | `local/secrets.vault.json` | `SecretVault` / `Nmer_SecretStore` | 是 | 是（DPAPI） | 无 |
| `local.niuma_chat_llm` | `local/niuma_chat_llm.json` | Niuma Chat | 是 | 可能 | `config/` → local |
| `local.openclaw_state` | `local/openclaw-state/` | OpenClaw 集成 | 是 | 可能 | `Cache/openclaw-state` → local |

## Data/（持久化用户数据）

| ID | 路径 | Owner | 可删 | 含密钥 | 迁移 |
|----|------|-------|------|--------|------|
| `data.db.clipboard` | `Data/db/Clipboard.db` | `ClipboardPanelCore`, FTS5 | 否 | 否 | `Nmer_MigrateDataLayout` |
| `data.db.cursor` | `Data/db/CursorData.db` | Cursor 面板 | 否 | 否 | 同上 |
| `data.db.grounding` | `Data/db/GroundingCache*.db` | Grounding | 否 | 否 | 同上 |
| `data.dict.*` | `Data/dict/*.db` | 词典 | 否 | 否 | 同上 |
| `data.search.history` | `Data/search/SearchCenterHistory.json` | SearchCenter | 否 | 否 | 同上 |
| `data.search.fulltext_settings` | `Data/search/fulltext_settings.json` | 全文索引 | 否 | 否 | 同上 |
| `data.search.fulltext_config` | `Data/search/fulltext_config.json` | 全文过滤 | 否 | 否 | 同上 |
| `data.state.prompts` | `Data/state/prompts.json` | 提示词状态 | 否 | 否 | 同上 |
| `data.state.cmdpal` | `Data/state/CommandPaletteExec.json` | 命令面板 | 否 | 否 | 同上 |
| `data.state.vk_keymap` | `Data/state/vk_cursor_keymap_compiled.json` | 虚拟键盘 | 否 | 否 | 同上 |
| `data.runtime.niuma_chat` | `Data/runtime/niuma-chat/` | Niuma Chat | 否 | 可能 | 树迁移 |

## Cache/（可重建缓存，根目录可自定义）

默认 `{ScriptDir}/Cache` 或 `CursorShortcut.ini` `[Paths] UserCacheRoot`。

| ID | 路径 | Owner | 可删 | 含密钥 | 迁移 |
|----|------|-------|------|--------|------|
| `cache.root` | `Cache/` 或自定义 | `Nmer_UserCacheRoot` | 是 | 否 | `Nmer_MigrateUserCacheFiles` |
| `cache.fulltext_index` | `Cache/fulltext-index/` | 全文 Bluge | 是 | 否 | Data → Cache |
| `cache.images` | `Cache/images/` | 剪贴板图 | 是 | 否 | 同上 |
| `cache.thumbs` | `Cache/thumbs/` | 缩略图 | 是 | 否 | 同上 |
| `cache.temp` | `Cache/temp/` | 临时截图等 | 是 | 否 | 同上 |
| `cache.debug` | `Cache/debug/` | 追踪日志 | 是 | 否 | `Nmer_MigrateDebugFiles` |
| `cache.diagnostics` | `Cache/diagnostics/` | 诊断导出 zip | 是 | 否 | 脚本创建 |

## config/（仓库随附默认，只读模板）

| ID | 路径 | Owner | 可删 | 含密钥 | 迁移 |
|----|------|-------|------|--------|------|
| `config.commands` | `config/Commands.json` | 命令绑定 | 否（仓库） | 否 | 无 |
| `config.studio_defaults` | `config/user_studio.defaults.json` | 还原默认 | 否（仓库） | 否 | 仅作模板，不自动覆盖 local |

## 运维脚本引用

- 导出：`tools/Nmer-ExportAll.ps1`（默认跳过 `secrets.vault.json` 内容；可选 `-IncludeDataDb`、`-IncludeCache`）
- 企业操作说明：[nmer-enterprise-ops.md](nmer-enterprise-ops.md)
- 清理：`tools/Nmer-CleanUninstall.ps1`（`Cache/` 全清；local 部分可删项见脚本内列表）
