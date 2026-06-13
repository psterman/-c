# A2UI 灰度 Rollout

Wave0/Wave2 基线、日检观察、Day4 扩灰决策、合并门禁。

**入口**：`Run-A2uiRolloutGate.ps1`、`Run-A2uiRollbackDrill.ps1`、`Run-A2uiL3ProbeSummary.ps1`

**输出**：`gray_flags_baseline.json`、`a2ui_daily_observation_last.json` 等（均在 `Cache/debug/`）。

## 与 CP / Wails 默认的边界（P3 独立线）

- `rolloutGatePass=true` **不改变** `commandPaletteHost`
- `rolloutGatePass=true` **不改变** `wailsDefaultEligible`

A2UI 灰度与 CP 发布票（P0）、Wails Raycast UX Gate（P4.1 spec only）正交。
