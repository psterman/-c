# 牛马 nmer — 企业 / 运维说明

面向 IT、支持人员与高级用户：本地数据在哪、密钥如何存、如何打包导出。**不涉及**设置页拆分或 SearchCenter 架构。

## 1. 数据目录（必读）

| 目录 | 用途 | 可否删 |
|------|------|--------|
| `local/` | 主配置、`user_studio.json`、DPAPI 密钥库 | 部分可删，见 [路径清单](nmer-paths-inventory.md) |
| `Data/` | SQLite、搜索/状态 JSON | 删库会丢历史 |
| `Cache/` | 全文索引、图片、调试日志 | 可整夹删后重建 |

**重要**：`local/` 与 `Data/` 中**已存在的文件**不会在启动时被仓库默认或迁移逻辑覆盖（仅目标缺失时复制补全）。

完整路径 ID 表：[nmer-paths-inventory.md](nmer-paths-inventory.md)

## 2. API 密钥（DPAPI + SecretStore）

### 机制

- 明文密钥不再长期保存在 `local/user_studio.json`（含 `llm.apiKey`、`apiKeys.*`、**`options.llmApiKeys.*`**）。
- 加密存储：`local/secrets.vault.json`（Windows **DPAPI CurrentUser**）。
- 对外 API：`modules/Nmer_SecretStore.ahk`（`Set` / `Get` / `MigrateDocument`）。
- 迁移完成后 JSON 顶层：`"secretsEncrypted": true`。

### 自动迁移

启动 `牛马.ahk` 时会调用 `Nmer_SecretStore_MigrateUserStudioPlaintext()`（若仍有明文则迁移并备份）。

### 手动迁移（支持 / 脚本）

```powershell
# 会先备份 local/user_studio.backup-{时间戳}.json
powershell -NoProfile -File tools\Migrate-PlaintextSecrets.ps1

# 验证 JSON 中无明文 Key（含 options.llmApiKeys.*）
powershell -NoProfile -File tools\Verify-SecretStore.ps1
```

**推荐**：直接重载 `牛马.ahk`，启动时会自动迁移（含 `options.llmApiKeys` 多厂商 Key）。

CLI 迁移通过 `%TEMP%` 启动 AHK 并设置环境变量 `NMRE_ROOT` 指向仓库根目录。

### 企业注意

- DPAPI 绑定**当前 Windows 用户**：换用户、换机、漫游配置**不能**直接拷贝 `secrets.vault.json` 解密。
- 换机请使用 **迁移包**（设置 → 存储与缓存 → 数据迁移，或 `tools\Nmer-ExportAll.ps1` / `Nmer-ImportMigration.ps1`），导入后在智能定制**重新填写 API Key**。
- **定制包**（仅 `user_studio.json`）用于分享 LLM 配置模板，不能替代完整迁移。
- 支持排障时优先看 `user_studio.json` 是否已 `secretsEncrypted: true`，vault 是否存在（无需导出 vault 内容）。

## 3. 迁移包（换机 / 备份）

### 应用内

`CapsLock + Q` → 设置 → **存储与缓存** → **数据迁移** → 导出/导入。

默认包含：local 配置、`user_studio.json`、OpenClaw 状态、Data 搜索/状态 JSON、剪贴板/Cursor SQLite、`Data/runtime/niuma-chat/`。可选：截图/缩略图缓存。**不含** `secrets.vault.json`。

### CLI

```powershell
# 默认含 SQLite；输出 Cache/diagnostics/nmer_migration_{时间戳}.zip
powershell -NoProfile -File tools\Nmer-ExportAll.ps1

# 含截图/缩略图
powershell -NoProfile -File tools\Nmer-ExportAll.ps1 -Preset full

# 自定义分组（JSON）
powershell -NoProfile -File tools\Nmer-ExportAll.ps1 -OptionsJson path\to\migration_opts.json

# 运维：额外含 debug 日志
powershell -NoProfile -File tools\Nmer-ExportAll.ps1 -IncludeCache

# 轻量：不含数据库
powershell -NoProfile -File tools\Nmer-ExportAll.ps1 -IncludeDataDb:$false

# 仅预览
powershell -NoProfile -File tools\Nmer-ExportAll.ps1 -WhatIf

# 导入（建议先退出牛马；应用内导入使用 -Force）
powershell -NoProfile -File tools\Nmer-ImportMigration.ps1 -ZipPath "D:\backup\nmer_migration_xxx.zip"
```

zip 内 `manifest.json`：`version: 2`、`kind: migration`。导入前备份至 `local/backup-migration-{时间戳}/`；结果见 `Cache/diagnostics/import_result_*.json`。

交给支持时请说明：**zip 不含 vault**；勿将 zip 提交到公共工单。

## 4. 清理（预览优先）

```powershell
powershell -NoProfile -File tools\Nmer-CleanUninstall.ps1                    # 预览 + 列注册表自启动
powershell -NoProfile -File tools\Nmer-CleanUninstall.ps1 -Confirm           # 删除 Cache 等
powershell -NoProfile -File tools\Nmer-CleanUninstall.ps1 -Confirm -RemoveAutoStart  # 并移除 HKCU\Run\Nmer / CursorHelper
```

**默认保留**：`local\CursorShortcut.ini`、`local\user_studio.json`、`Data\`。删除前请退出托盘中的牛马。

**未包含在默认删除内**（需手动）：整个 `Data\` 库、安装目录、其他用户的 DPAPI vault。

## 5. ttyd 终端（本机 Web 终端）

- 引擎端口：`7681–7691`（`studio_cli` 默认 **7691**），见 `modules/NiumaTtyd.ahk`。
- 启动参数固定 **`-i 127.0.0.1`**，仅本机回环，**不绑定** `0.0.0.0`。
- 静态检查：`powershell tools\ci\Validate-TtydBind.ps1`

**企业注意**：ttyd 在本机等价于无二次认证的 shell；EDR 可能标记 `ttyd.exe`。非必要勿改端口到公网；防火墙策略应拒绝入站。

## 6. EDR / 杀软说明（给 IT）

| 行为 | 说明 |
|------|------|
| 全局热键 | AutoHotkey 钩子，用于 CapsLock 牛马面板 |
| 剪贴板 | 剪贴板历史功能读取系统剪贴板 |
| 注入 Cursor | 向 Cursor 窗口发送按键/文本，非键盘记录外发 |
| 网络 | LLM API、SearchCenter、可选 OpenClaw；**无内置遥测上报** |
| 日志 | 仅写本地 `Cache/debug/`（如 `nmer_trace.log`） |

**建议白名单路径**：安装目录、`AutoHotkey64.exe`、`ttyd.exe`、`SearchCenterCore.exe`。  
**不提供**键盘内容上云；支持包导出见 §3，默认不含 vault。

## 7. 故障排查与日志

| 入口 | 路径 / 操作 |
|------|-------------|
| 托盘 | **导出诊断包** → `Cache/diagnostics_export_*` |
| 日志目录 | `Cache/debug/`（`nmer_trace.log`、`scwv_trace.log`、`searchcore_lifecycle.jsonl` 等） |
| 密钥自检 | `powershell tools\Verify-SecretStore.ps1` |
| 导出配置 zip | `tools\Nmer-ExportAll.ps1` |
| 导入迁移包 | `tools\Nmer-ImportMigration.ps1` |

AHK 报错弹窗时，请同时打开 `Cache/debug/nmer_trace.log` 末尾 50 行一并反馈。

## 8. 验证与约定

| 项 | 命令 / 文档 |
|----|-------------|
| 路径约定 | [nmer-conventions.md](nmer-conventions.md) |
| 日志事件 | [nmer-must-log-events.md](nmer-must-log-events.md) |
| 本地最小门 | `powershell tools\ci\Run-MinimalGate.ps1 -Strict` |

文档中未经过上述门或实机回归的段落，标注为**未验证**，部署前请自行冒烟。

## 9. 支持冒烟清单（约 5 分钟）

1. 启动 `牛马.ahk`，确认无报错。
2. 设置 → 智能定制：保存一次 API Key，运行 `tools\Verify-SecretStore.ps1` → PASS；`user_studio.json` 中 `options.llmApiKeys.*` 与 `llm.apiKey` 应为空。
3. 运行 `Nmer-ExportAll.ps1 -WhatIf`，确认无报错；可选实机导出迁移包并检查 manifest `kind=migration`。
4. 重启牛马，确认 Key 仍可用（从 vault 回填内存）。
