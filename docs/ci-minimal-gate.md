# 最小 CI 门禁

本地 signoff（不依赖 GitHub Actions）：

```powershell
powershell -ExecutionPolicy Bypass -File tools\ci\Run-MinimalGate.ps1 -Strict
```

报告输出：`Cache/ci/minimal_gate_report.txt`

包含步骤：

1. SearchCore Lifecycle Phase1 套件（`-Strict` 时 P1 静态也失败即退出）
2. `Validate-CatchPolicy.ps1` — 禁止 `modules/` 内裸 `catch {}`（白名单除外）
3. `Validate-SqlPolicy.ps1` — Tier-1 剪贴板模块禁止用户输入 SQL 字符串拼接 LIKE
4. `Validate-LegacyBypass.ps1` — 非 Legacy 模块禁止**新增** `LegacyConfigGui_Show` / `ShowClipboardManager` 直调（白名单见 `tools/ci/legacy-bypass-allowlist.txt`；`-Strict` 时违规即失败）
5. `Validate-WsPolicy.ps1` — 内部 WS hub token 鉴权接线（Go + AHK）
6. `TryAhkLaunchMatrix.ps1` — AHK 语法/启动烟雾

单独收集 SearchCore 日志：

```powershell
powershell -ExecutionPolicy Bypass -File tools\ci\Collect-SearchCoreLogs.ps1
```

可选内存探针（耗时，默认不跑）：

```powershell
powershell -ExecutionPolicy Bypass -File tools\ci\Run-MinimalGate.ps1 -Strict -IncludeMemoryProbe
```
