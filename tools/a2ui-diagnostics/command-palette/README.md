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
- `Run-Cp4AgentTransportHubGate.ps1`（CP4：`agentTransport=hub` + hub chain + hello inject；回滚 `auto|ftb`）
