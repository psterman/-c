# 牛马 nmer

项目文档与说明见 **[md/README.md](md/README.md)**。

**首次使用前请阅读 [md/AGENTS.md](md/AGENTS.md)**（定制数据、设置入口、Agent 约束）。

## 说明

- **未验证的描述**：文档或注释中未经 `tools/ci/Run-MinimalGate.ps1 -Strict` 或实机回归的段落，使用前请自行验证。
- **`local/` 已存在文件不会在启动时自动覆盖**（仅 missing 时迁移/补全，与 `UserStudio_Load`、`Nmer_MigrateLocalData` 一致）。
- **混栈治理**：开发者入口见 **[docs/stack-governance.md](docs/stack-governance.md)**；本地菜单 `powershell -NoProfile -File tools\dev\Run-DevMenu.ps1`。

## 企业 / 运维

密钥（DPAPI）、配置导出 zip、路径与清理说明见 **[docs/nmer-enterprise-ops.md](docs/nmer-enterprise-ops.md)**。

| 场景 | 命令（仓库根目录） |
|------|-------------------|
| 明文密钥迁入 vault | `powershell -NoProfile -File tools\Migrate-PlaintextSecrets.ps1` |
| 验证 JSON 无明文 Key | `powershell -NoProfile -File tools\Verify-SecretStore.ps1` |
| 导出迁移包（CLI） | `powershell -NoProfile -File tools\Nmer-ExportAll.ps1` |
| 导入迁移包（CLI） | `powershell -NoProfile -File tools\Nmer-ImportMigration.ps1 -ZipPath "路径\nmer_migration_*.zip"` |
| 路径清单 | [docs/nmer-paths-inventory.md](docs/nmer-paths-inventory.md) |

## 换机（简要）

1. 旧机：设置 → **存储与缓存** → **导出迁移包**（可选勾选截图/缩略图缓存）。
2. 新机：安装牛马后 → **导入迁移包**。
3. 设置 → **智能定制** → 重新填写 API Key（vault 不随包迁移）。
4. 建议重启牛马。

## 目录速览

- 主程序入口：根目录 **`牛马.ahk`**、**`VirtualKeyboard.ahk`**
- 用户配置：**`local/`**（API Key 经 **DPAPI** 存 `secrets.vault.json`，JSON 无明文）
- 数据库与用户数据：**`Data/`**
- 外援程序（SearchCenter、Everything、ttyd）：**`tools/`**
- 命令绑定默认：**`config/Commands.json`**
- WebView 面板：**`html/`** · 模块：**`modules/`** · 运行时 DLL：**`lib/`**
- Agent / 定制说明：**[md/AGENTS.md](md/AGENTS.md)**
