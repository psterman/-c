# Command Palette 发布签收（AHK 宿主）

> 签收日期：2026-06-13  
> 分支：`slim`  
> 产物：`Cache/debug/hybrid_cp_signoff_pipeline.json` → `cpReleasePass=true`

## 产品结论

| 项 | 值 |
|----|-----|
| **CP 产品默认** | `commandPaletteHost=ahk` |
| **CP 发布票** | **已关**（`cpReleasePass=true`） |
| **Wails CP** | architecture ready / **non-default** |
| **Wails 默认票** | **未关**（`wailsDefaultEligible=false`） |

**CP 发布票已关 ≠ Wails 默认票已关。** 默认切 Wails 需独立 [P4.1 Raycast UX Gate](cp-wails-raycast-ux-gate-spec.md)（当前 spec only）。

## P0 门禁（全部满足）

1. 手动 6 项 → `cp_manual_release_checklist.json`
2. Hybrid warm-session → `hybrid_manual_signoff.json`
3. CP PerfGate official → `command_palette_perf_gate.json`（`captureMode=manual_equivalent`）
4. `defaultHost=ahk`
5. legacy rollback → `ahk` + `hub` + `legacySurfaceLifecycle=true`

## 发布聚合 schema

见 [`tools/a2ui-diagnostics/command-palette/cp_release_gate.example.json`](../tools/a2ui-diagnostics/command-palette/cp_release_gate.example.json)。

`wailsArchitecturePass` 读 CP7/8/9/10 报告，**不阻断** `cpReleasePass`。

## 复现命令

```powershell
cd tools\a2ui-diagnostics
.\Run-CpManualReleaseChecklist.ps1 -SignoffAll   # 或逐项 -RecordId
.\Run-HybridCpSignoffPipeline.ps1 -SkipHybrid -SkipPerfGate
```

全量重跑（含 Hybrid + PerfGate）：

```powershell
.\Run-HybridCpSignoffPipeline.ps1
```

## 后续路线

| 线 | 说明 |
|----|------|
| **P2** | 内存与侧车：`Run-P2MemorySidecarGate.ps1`（见下） |
| P3 | A2UI 灰度（独立；`rolloutGatePass` 不改 CP host） |
| P4.1 | Wails Raycast UX Gate（spec only） |
| P4.2 | SearchCenter / Config → Wails 灰度 |
| P4.3 | Surface-by-surface eligibility |

详见 [`surface-manager-execution-plan.md`](surface-manager-execution-plan.md) §十五。

## P2 — 内存与侧车

```powershell
cd tools\a2ui-diagnostics
.\Run-P2MemorySidecarGate.ps1 -PauseIndexerForSoak
```

| 门禁 | 阈值 |
|------|------|
| Hub private | ≤50 PASS · 50–55 WARN · >55 FAIL |
| 30min hub slope | ≤ 1 MiB/hour |
| 30min UI aggregate | ≤ 5 MiB/hour **或** abs Δ ≤ 30 MiB |
| 10 轮 hub 恢复 | `hubEnd ≤ hubStart × 1.10` |

产物：`Cache/debug/p2_memory_sidecar_gate.json`。`PASS_WITH_WARNINGS` = hub 在 50–55 MiB 警告带。
