# CommandPalette 阶段 0 — PerfGate 实机基线

目标：在**不改变用户可见行为**的前提下，证明 CP0–CP2 优化有效，并建立可对比的 P50/P95 与 resize 基线。

## 前提

1. **v4 FormalSignoff** `deploy done` 后再采（避免签核与热重载交叉）。
2. 采前 **完全退出并重新启动** `牛马.ahk`（AHK/HTML 有变更时必须重载）。
3. `local/nmer-flags.json` 建议：

```json
"palette": {
  "fastInput": true,
  "discreteLayout": true,
  "streamBatching": true
},
"wailsBridge": { "commandPaletteHost": "ahk" }
```

## 一键流程

```powershell
cd tools\a2ui-diagnostics
.\Run-CommandPalettePerfPhase0.ps1
```

快速只测本地连打（跳过 layout/stream 场景）：

```powershell
.\Run-CommandPalettePerfPhase0.ps1 -Quick
```

签核未完成但强制采集：

```powershell
.\Run-CommandPalettePerfPhase0.ps1 -Force
```

## 分步流程

### 1. 清空并重载

```powershell
Remove-Item ..\..\Cache\debug\command_palette_perf.ndjson -ErrorAction SilentlyContinue
# 重载 牛马.ahk
```

### 2. 引导采集

```powershell
.\Capture-CommandPalettePerfSession.ps1 -ClearLog -Strict
```

| 场景 | 操作 |
|------|------|
| `local-type` | 本地意图连打 20 字 |
| `action-type` | 动作意图 `>` 命令搜索连打 20 字 |
| `layout-toggle` | 空输入 ↔ 有输入切换约 10 次 |
| `stream-type` | 流式 Agent 期间再输入（可选） |

单场景：

```powershell
.\Capture-CommandPalettePerfSession.ps1 -Scenario local-type -ClearLog -Strict
```

### 3. 门禁

```powershell
.\Run-CommandPalettePerfGate.ps1 -Strict
```

## 门禁阈值（-Strict）

| 检查项 | 阈值 |
|--------|------|
| `query_to_paint` / `local_results_painted` P95 | ≤ 40ms |
| `show_to_visible` P95 | ≤ 100ms |
| `sync_pull_agent_cards` | = 0 |
| `resize_continuous`（discreteLayout 开） | = 0 |
| `paint_samples` | ≥ 5 |
| `row_count` | ≥ 10 |

空日志在 `-Strict` 下 **不能 PASS**。

## 输出文件

| 路径 | 说明 |
|------|------|
| `Cache/debug/command_palette_perf.ndjson` | 原始时间线 |
| `Cache/debug/command_palette_perf_gate.json` | 门禁报告 |
| `Cache/debug/perf-baselines/phase0_*` | 阶段 0 归档副本 |

## 归因字段

ndjson 中关注：

- `source`: `web` / `ahk`
- `event`: `query_to_paint`, `local_results_painted`, `resize_applied`, `layout_mode_requested`
- `layoutMode`: `continuous`（旧回路） vs `compact`/`list`/`detail`

## 失败排查

| 失败项 | 可能原因 |
|--------|----------|
| `sync_pull_agent_cards > 0` | 未重载、或热路径仍 sync 拉卡 |
| `resize_continuous > 0` | `discreteLayout` 未开或未生效 |
| P95 > 40ms | Action 整卡 `innerHTML`、或未走 `fastInput` |
| `paint_samples` 不足 | 未连打够 20 字、或 perf-marks 未加载 |

## 自动化（可选）

已有 ndjson、跳过采集：

```powershell
.\Run-CommandPalettePerfPhase0.ps1 -SkipCapture
```
