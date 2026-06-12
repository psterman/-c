# 命令面板性能

采集 `command_palette_perf.ndjson` 并运行 PerfGate → `command_palette_perf_gate.json`。

## 两阶段门禁

| 阶段 | 字段 | 说明 |
|------|------|------|
| Stage 1 | `pipelinePass` | 采样是否有效（ndjson、palette_ready、query_start、paint_samples≥5） |
| Stage 2 | `performancePass` | P95 / resize 阈值（仅 pipeline 通过后评估） |

无采样时 `failReason=no_paint_samples`（`perf_pipeline_fail`，不是 `performance_fail`）。

**入口**：

- `Run-CommandPalettePerfPhase0.ps1`（Phase0 全流程）
- `Test-CpPerfPipeline.ps1`（仅 Stage 1 自检）
- `Run-CommandPalettePerfGate.ps1 -Strict`（完整两阶段）
- `Capture-CommandPalettePerfSession.ps1`（采集结束自动 pipeline 自检 + gate）
