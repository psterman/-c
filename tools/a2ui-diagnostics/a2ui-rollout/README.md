# A2UI 灰度 Rollout

Wave0/Wave2 基线、日检观察、Day4 扩灰决策、合并门禁。

## 入口

| 脚本 | 用途 |
|------|------|
| `Run-A2uiP3SignoffPipeline.ps1` | P3 聚合：RolloutGate → 日检 → Day4 |
| `Run-A2uiRolloutGate.ps1` | Wave0/Wave2 + L3 + observation eval |
| `Run-A2uiDailyObservation.ps1` | 7×24 日检（追加 `a2ui_observation_history.jsonl`） |
| `Run-A2uiDay4Decision.ps1` | 扩灰决策草稿（需 `observation_days >= 7`） |
| `Run-A2uiRollbackDrill.ps1` | hybrid 回退演练 |
| `Run-A2uiL3ProbeSummary.ps1` | L3 探针汇总 |

根目录 shim：`..\Run-A2uiP3SignoffPipeline.ps1` 等。

**输出**：`p3_a2ui_signoff_pipeline.json`、`a2ui_rollout_gate_last.json`、`a2ui_day4_decision_last.json` 等（均在 `Cache/debug/`）。

## P3 两阶段

1. **`p3RolloutGatePass`**（`rolloutGatePass`）— Wave 基线 + L3 + eval 全绿 ✅ 可立即签收
2. **`p3ExpandGrayPass`**（`day4Pass`）— 需连续 **7 个自然日** 日检 + 硬检查全绿；在此之前 `recommendation=maintain_b_granularity`

```powershell
cd tools\a2ui-diagnostics
.\Run-A2uiP3SignoffPipeline.ps1 -SkipRolloutGate   # 仅刷新日检/Day4（gate 已绿时）
.\Run-A2uiDailyObservation.ps1                     # 每日 cron / 任务计划
```

## 与 CP / Wails 默认的边界（P3 独立线）

- `rolloutGatePass=true` **不改变** `commandPaletteHost`
- `rolloutGatePass=true` **不改变** `wailsDefaultEligible`
- `p3ExpandGrayPass=true` 仅建议扩灰 `r3_gray`，**仍不**切换 Wails CP 默认

A2UI 灰度与 CP 发布票（P0）、Wails Raycast UX Gate（P4.1 spec only）正交。
