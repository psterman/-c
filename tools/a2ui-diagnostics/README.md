# A2UI / Hybrid 诊断工具包

面向**开发者、Hybrid 签收与灰度观察**的 PowerShell 脚本集合。普通日常使用牛马**不必**运行这些脚本。

所有产物默认写入仓库 `Cache/debug/`（JSON / NDJSON / 注入后的 HTML 看板）。

## 目录结构

| 子目录 | 用途 | 典型入口 |
|--------|------|----------|
| [`hybrid/`](hybrid/) | Hybrid 运行终验：手动探测、FTB/CP/UI 环、Hub 链、看板采集 | `Run-HybridSignoff.ps1` |
| [`memory/`](memory/) | 内存基线、多卡阶梯、索引部署、 soak、P0A/P2 空闲退出 | `Run-A2uiMultiCardMemory.ps1` |
| [`surface/`](surface/) | Surface Manager 门禁 S2–S11、运行时诊断、Surface 看板 | `Open-SurfaceGateDashboard.ps1` |
| [`command-palette/`](command-palette/) | 命令面板性能采集与 PerfGate | `Run-CommandPalettePerfGate.ps1` |
| [`a2ui-rollout/`](a2ui-rollout/) | A2UI 灰度 Wave0/2、日检、Day4 决策 | `Run-A2uiRolloutGate.ps1` |
| [`v4/`](v4/) | v4 正式签收看板（P0A/P0B/P0C 前置） | `Open-V4SignoffDashboard.ps1` |
| [`dashboards/`](dashboards/) | HTML 模板与 `*-live.html`（脚本注入 JSON 后浏览器打开） | 由 `Open-*Dashboard.ps1` 生成 |

根目录仍保留与迁移前**同名**的 `.ps1`，实为 **Shim**：转发到对应子目录，文档与旧命令行无需改路径。

公共 helper：`_DiagRoot.ps1`（解析仓库根、`Join-DiagScript`）、`_Shim.ps1`（根目录转发）。

## 前置条件

1. **Windows + PowerShell 5.1+**（建议 `-ExecutionPolicy Bypass`）。
2. 在仓库根目录启动，或让脚本自动解析 `Get-DiagRepoRoot`。
3. 多数 Hybrid / Surface 脚本要求 **牛马已在运行**（`牛马.ahk`），且 `local/nmer-flags.json` 中 Hybrid 相关开关已按场景配置。
4. 内存/部署类脚本可能 **编译 Go、重启 SearchCenterCore / nmer-hub**——仅在签收或专项测试时使用。

## 常用命令（仓库根目录执行）

```powershell
# Hybrid 终验一条龙（采集 + 浏览器看板）
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\Run-HybridSignoff.ps1

# Hybrid 终验 + CP PerfGate 自动化（Patch C D→E）
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\Run-HybridCpSignoffPipeline.ps1

# 仅采内存基线
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\capture-memory-baseline.ps1

# 多卡内存阶梯（空载 -> 参考 -> 1/5/20）
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\Run-A2uiMultiCardMemory.ps1

# 全自动（需先重载牛马.ahk 以启用 MultiCardMemoryProbe IPC）
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\Run-A2uiMultiCardMemory.ps1 -Auto -SkipEmptyCapture

# Hybrid 手动探测（需牛马在跑）
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\Invoke-HybridManualProbe.ps1 -Action ping

# Surface 门禁看板
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\Open-SurfaceGateDashboard.ps1

# v4 签收看板
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\Open-V4SignoffDashboard.ps1

# A2UI 灰度合并门禁
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\Run-A2uiRolloutGate.ps1
```

也可 `cd tools\a2ui-diagnostics\hybrid` 后直接跑子目录脚本；路径解析不依赖当前工作目录。

## 主要输出文件

| 文件 | 说明 |
|------|------|
| `Cache/debug/hybrid_signoff_dashboard.json` | Hybrid 看板数据 |
| `Cache/debug/a2ui_memory_baseline.json` | 内存基线（空载/索引等） |
| `Cache/debug/v4_signoff_dashboard.json` | v4 签收看板 |
| `Cache/debug/surface_runtime_diagnosis.json` | Surface 运行时诊断 |
| `Cache/debug/command_palette_perf_gate.json` | CP 性能门禁（pipelinePass + performancePass） |
| `Cache/debug/multi_card_memory_report.json` | 多卡内存阶梯报告（uiPrivateMiB 剥离 SearchCore） |
| `Cache/debug/*_gate_diagnosis.json` | 各阶段静态门禁 |
| `dashboards/*-live.html` | 注入 JSON 后的本地看板（`file://` 打开） |

## 谁该跑哪个

| 角色 | 建议 |
|------|------|
| 普通用户 | 不运行；用托盘「彻底退出重启」即可 |
| 功能开发 | Surface / CP 相关：`surface/`、`command-palette/` |
| Hybrid 集成 | `hybrid/Run-HybridSignoff.ps1`、日志 `Cache/debug/scwv_trace.log` |
| 内存/索引优化 | `memory/` + [`docs/search-memory-index-optimization-plan.md`](../../docs/search-memory-index-optimization-plan.md) |
| 灰度值班 | `a2ui-rollout/Run-A2uiDailyObservation.ps1` |
| 正式签收 | `v4/Open-V4SignoffDashboard.ps1`、`memory/Deploy-MemoryIndexBaseline.ps1 -FormalSignoff` |

## 相关文档

- [`docs/search-memory-index-optimization-plan.md`](../../docs/search-memory-index-optimization-plan.md)
- [`docs/surface-manager-execution-plan.md`](../../docs/surface-manager-execution-plan.md)
- [`docs/command-palette-perf-phase0.md`](../../docs/command-palette-perf-phase0.md)
- [`docs/a2ui-rollout-todo.md`](../../docs/a2ui-rollout-todo.md)

## 维护说明

- 新增脚本请放入对应子目录，并在根目录添加同名 Shim（或更新 `_FixPaths.ps1` 中的映射后重跑）。
- 跨目录调用请用 `Join-DiagScript -RelativePath "memory/xxx.ps1"`，勿硬编码 `..\..`。
- HTML 模板统一放在 `dashboards/`；`Open-*Dashboard.ps1` 负责注入 JSON 并打开 `*-live.html`。
