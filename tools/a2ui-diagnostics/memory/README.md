# 内存与索引

SearchCenter 内存基线、索引根策略（P0A）、部署切换、soak 与空闲进程退出；**P2** CP 发布后 hub/UI 斜率与侧车门禁。

**常用**：

- `capture-memory-baseline.ps1` — 当前进程/WebView2 内存快照 → `a2ui_memory_baseline.json`
- `Deploy-MemoryIndexBaseline.ps1` — 重编译 Core/hub、迁移配置、正式签收流程
- `Run-MemorySoakTest.ps1` / `Test-IdleProcessExit.ps1` — SearchCore 长跑与空闲退出
- **`Run-P2MemorySidecarGate.ps1`** — P2 主线门禁（hub private / 30min 斜率 / 10 轮恢复）
- **`Run-P2HubUiSoak.ps1`** — P2 专用 30min hub + `uiPrivateMiB` 斜率采样

## P2 门禁阈值（CP 发布后）

| 指标 | PASS | WARN | FAIL |
|------|------|------|------|
| Hub private | ≤ 50 MiB | 50–55 MiB | > 55 MiB |
| 30min hub slope | ≤ 1 MiB/h | — | > 1 MiB/h |
| 30min UI aggregate slope | ≤ 5 MiB/h **或** abs Δ ≤ 30 MiB | — | 否则 FAIL |
| 10 轮 hub inject 恢复 | `hubEnd ≤ hubStart × 1.10` | — | 超出 |

```powershell
# 全量（含 30min soak，耗时）
.\Run-P2MemorySidecarGate.ps1 -PauseIndexerForSoak

# 快速烟测（3min soak + 10 轮恢复）
.\Run-P2MemorySidecarGate.ps1 -QuickSoakMinutes 3 -PauseIndexerForSoak

# 仅聚合已有 artifact
.\Run-P2MemorySidecarGate.ps1 -SkipSoak -SkipRecovery
```

**输出**：`Cache/debug/p2_memory_sidecar_gate.json`、`p2_hub_ui_soak.json`、`hybrid_cycle_recovery.json`

详见 [`docs/search-memory-index-optimization-plan.md`](../../../docs/search-memory-index-optimization-plan.md)、[`docs/cp-release-signoff.md`](../../../docs/cp-release-signoff.md)。
