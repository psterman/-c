# 命令面板性能

采集 `command_palette_perf.ndjson` 并运行 PerfGate → `command_palette_perf_gate.json`。

## 两阶段门禁

| 阶段 | 字段 | 说明 |
|------|------|------|
| Stage 1 | `pipelinePass` | 采样是否有效（ndjson、palette_ready、query_start、paint_samples≥5） |
| Stage 2 | `performancePass` | P95 / resize 阈值（仅 pipeline 通过后评估） |

无采样时 `failReason=no_paint_samples`（`perf_pipeline_fail`，不是 `performance_fail`）。

**入口**：

- `Run-CommandPalettePerfAutomated.ps1`（Phase E 一键自动化，默认 `manual_equivalent` 同步命令索引路径）
- `Run-CommandPalettePerfPhase0.ps1`（Phase0 全流程 / 人工键盘）
- `Test-CpPerfPipeline.ps1`（仅 Stage 1 自检）
- `Run-CommandPalettePerfGate.ps1 -Strict`（完整两阶段）
- `Capture-CommandPalettePerfSession.ps1`（采集结束自动 pipeline 自检 + gate）
- `Run-Cp3aShadowWriteGate.ps1`（CP3a：hub 影子 StateStore；默认不重跑 PerfGate，加 `-WithPerfRecheck` 才做回归）
- `Run-Cp3bSummaryStoreGate.ps1`（CP3b：`stateStore` 开启时 summary DTO 写入 Go shadow，拒收 blockStore）
- `Run-Cp3cSummaryPullGate.ps1`（CP3c：前端优先 hub summary 首拉 ≤20）
- `Run-Cp3dDetailLazyLoadGate.ps1`（CP3d：按 cardId 懒加载 detail/blockStore）
- `Run-Cp4AgentTransportHubGate.ps1`（CP4：`agentTransport=hub` + hub chain + hello inject + **OpenClaw 真回复**；回滚 `auto|ftb`）
- `Invoke-Cp4OpenClawLiveReply.ps1`（CP4 手工烟测：adapter → Gateway 实网一句回复）
- `Run-Cp5ModularShellGate.ps1`（CP5 Wave 1–2：`CommandPalette.html` 壳层 + views/search 模块化；前置 CP4 PASS + fixtures 全绿）

## CP5 模块化壳层（Wave 1–4）

**前置**：`cp4_agent_transport_hub_gate.json` → `overallPass=true`。

```powershell
cd tools\a2ui-diagnostics\command-palette
.\Run-Cp5ModularShellGate.ps1
```

**通过标准**：`cp5_modular_shell_gate.json` 中 `overallPass=true`；内联 script 较基线 8366 行减少 ≥1500 行（Wave 4 收口）；`node html/run-palette-fixtures.mjs` 全绿（含 `ActionHistoryShell` 用例）。

**Wave 4 模块**：`agent-card-sync.js`（pull/sync/cache/空态）、`action-bar.js`（托管引擎条）、`palette-shell.js`（bindUI）、`agent-summary.js` 含历史工具栏。

## CP6 Wails 灰度（命令面板宿主）

**前置**：`cp5_modular_shell_gate.json` → `overallPass=true`（建议 CP4 也已 PASS）。

```powershell
cd tools\a2ui-diagnostics\command-palette

# Stage 1：静态脚手架（默认，不改 flags）
.\Run-Cp6WailsGrayGate.ps1

# Stage 2：构建侧车后跑运行时烟测（自动化 live，推荐）
cd ..\..\apps\nmer-wails
wails build
cd ..\..\tools\a2ui-diagnostics\command-palette
.\Run-Cp6WailsGrayGate.ps1 -WithSmoke -SkipPrompt

# 或单独跑 live 烟测（IPC show_cp + 新鲜 cp_host_show host=wails）
.\Run-Cp6WailsGrayLiveSmoke.ps1

# 仅分析已有 surface_runtime.ndjson（历史会话，非 live 认证）
.\Invoke-Cp6WailsGraySmoke.ps1 -AnalyzeOnly -SkipPrompt

# 回滚 flags
.\Run-Cp6WailsGrayGate.ps1 -RevertFlags
```

**通过标准**：

| 阶段 | 字段 | 说明 |
|------|------|------|
| Static | `staticPass` | Router/WailsHost 模块、主脚本 include、`nmer-wails/app.go`、flags 契约 |
| Runtime | `runtimePass` | `-WithSmoke -SkipPrompt` 时 live 自动化：`fresh cp_host_show` 且 `host=wails`（`cp6_wails_gray_live_smoke.json`） |
| Overall | `overallPass` | 静态必过；加 `-WithSmoke` 时 live 运行时也必须过 |

**静态增量检查**：`wails_host_visible_state`、`core_isvisible_wails_delegate`、`memory_probe_show_cp`。

**CP6 灰度仅切换** `commandPaletteHost=wails` + `legacySurfaceLifecycle=false`（不强制 SC/Config 走 Wails）。全表面灰度仍用 `surface/Run-WailsGraySmoke.ps1`。

## CP7 Wails CP Shell（阶段 2b+2c+2d）

```powershell
.\Run-Cp7WailsCpShellGate.ps1 -WithSmoke -SkipPrompt -BootSec 180
```

**通过标准**：`cp7_wails_cp_shell_gate.json` → `overallPass=true`（P2-R1～R3/R6/R7/R9/R8；R4/R5 defer）。

## CP8 P2-M 内存 soak

**前置**：`wails build`；牛马已重载（含 `MultiCardMemoryProbe.ahk` 新探针）。

```powershell
.\Run-Cp8WailsCpMemorySoak.ps1 -BootSec 180 -Cycles 10
# 跳过 AHK 对照基线（仅验 wails 路径）：
.\Run-Cp8WailsCpMemorySoak.ps1 -SkipAhkBaseline
```

**通过标准**（`cp8_wails_cp_memory_soak.json`）：

| ID | 说明 |
|----|------|
| P2-M1 | AHK 宿主开 CP 有 `g_CmdPal_WV2`；wails 宿主无 AHK CP GUI/WV2 |
| P2-M2 | 10 次 show/hide/dispose 无 hwnd/WV2 泄漏 |
| P2-M3 | `nmer-wails.exe` 始终单实例 |

**产物**：`cp8_memory_ahk_open.json`、`cp8_memory_wails_open.json`

## CP9 P2-R4/R5 hub agent live（Wails CP）

```powershell
.\Run-Cp9WailsCpHubAgentLive.ps1 -BootSec 180 -AgentWaitSec 120 -SkipGatewayRestart
# 或并入 CP7：
.\Run-Cp7WailsCpShellGate.ps1 -WithSmoke -WithHubLive -SkipPrompt -BootSec 180
```

**通过标准**（`cp9_wails_cp_hub_agent_live.json`）：

| ID | 说明 |
|----|------|
| P2-R4 | egress `palette_agent_submit` → hub 回复 → `liveAnswer=true` |
| P2-R5 | `prepare_tier` 历史壳挂载 `TIER_READY` |

## CP10 阶段 2 自动化签 off

```powershell
.\Run-Cp10WailsCpPhase2Signoff.ps1
```

聚合 P2-S、fixtures 160/160、CP7/8/9 live 报告、默认 flags。报告：`s8b3_phase2_signoff.json`

## CP4 真回复验证（OpenClaw Gateway）

**前置**：本机 OpenClaw Gateway 监听 `127.0.0.1:18789`；Niuma Chat「龙虾」已一键连接（或 `local/user_studio.json` 有 openclaw key）。

1. 重载牛马（同步 Token 到 hub 子进程）
2. 构建并重启 hub（门禁脚本会自动执行，也可手工）：
   ```powershell
   cd tools\a2ui-diagnostics\command-palette
   .\Invoke-Cp4OpenClawLiveReply.ps1
   ```
3. 跑完整 CP4 门禁（Gateway 在线时 `hub_openclaw_live_reply` 须 PASS）：
   ```powershell
   .\Run-Cp4AgentTransportHubGate.ps1
   ```
4. 命令面板实机：动作模式 → 选「龙虾」→ 输入短句 Enter → 卡片应出现流式/完成回复（无需 FTB 前台）

**通过标准**：`cp4_openclaw_live_reply.json` 中 `overallPass=true` 且 `answerLen>0`；CP4 报告 `hub_openclaw_live_reply` 为 PASS。

**若仍见 `CONTROL_UI_ORIGIN_NOT_ALLOWED`**：确认已用最新 `nmer-hub`（connect 使用 `gateway-client`/`backend`，非 `openclaw-control-ui`）。

## CP 发布票（P0，默认 AHK）

**产品默认 = AHK**；Wails CP 为 **architecture ready / non-default**（CP7～10）。**CP 发布票已关 ≠ Wails 默认票已关**。

| 步骤 | 脚本 |
|------|------|
| 手动 6 项 | `Run-CpManualReleaseChecklist.ps1`（`-SignoffAll` 或 `-RecordId <id>`） |
| 仅发布聚合 | `Run-HybridCpSignoffPipeline.ps1 -SkipHybrid -SkipPerfGate` |
| Hybrid + Perf + 聚合 | `Run-HybridCpSignoffPipeline.ps1` |

示例 schema：[`cp_release_gate.example.json`](cp_release_gate.example.json)

**`cpReleasePass` 条件**：`manualReleasePass` + `hybridPass`（warm-session）+ `perfGateOfficial`（`manual_equivalent`）+ `defaultHost=ahk` + legacy rollback。`wailsArchitecturePass` 只记录。

详见 [`docs/cp-release-signoff.md`](../../../docs/cp-release-signoff.md)、[`docs/surface-manager-execution-plan.md`](../../../docs/surface-manager-execution-plan.md) §十五。
