# Hybrid 终验

Hybrid 模式下的运行态签收：Wails 桥、FTB、命令面板 hello 注入、UI 环、Hub 链、周期恢复。

## 推荐执行顺序（不可颠倒）

```text
Phase A   修签收口径（脚本/看板，不跑正式签收）
Phase B0  Test-HybridReferenceContract.ps1（contract 自检）
Phase C   Deploy-MemoryIndexBaseline -FormalSignoff + Test-IdleProcessExit + V4 dashboard
Phase B1  post-signoff 重采 ahk / hybrid reference
Phase D   Run-HybridManualSignoff -SignoffMode warm-session
Phase E   停 SearchCore → Run-CommandPalettePerfPhase0
Phase F/G CP3 / CP4
Phase H   P4 / CP5 / CP6
```

## Reference Contract（硬规则）

| 用途 | 文件 | referenceKind |
|------|------|---------------|
| `memory_delta` | `hybrid_signoff_reference_ahk.json` | `ahk` |
| UI-01 `refDrift` | `hybrid_signoff_reference_hybrid.json` | `hybrid` |

缺文件 → 对应指标 `deferred/null`，**禁止** fallback 到另一 reference。

### B1 重采顺序（post-signoff）

```powershell
# 1) pure-AHK（临时 floatingToolbarHost=ahk，托盘重启牛马）
.\Capture-HybridMemoryReference.ps1 -Mode ahk

# 2) hybrid（改回 floatingToolbarHost=hybrid，托盘重启牛马）
.\Capture-HybridSignoffBaseline.ps1
.\Capture-HybridMemoryReference.ps1 -Mode hybrid

# 3) 自检
.\Test-HybridReferenceContract.ps1
```

## 常用入口

| 脚本 | 用途 |
|------|------|
| `Test-HybridReferenceContract.ps1` | Phase B0/B1 reference contract 自检 |
| `Run-HybridSignoff.ps1` | 自动门禁 + 看板 |
| `Run-HybridManualSignoff.ps1` | FTB/CP/UI-01 手动签收 |
| `Run-HybridCpSignoffPipeline.ps1` | **D→E 一条龙**：Hybrid warm-session 签收 + 自动化 CP PerfGate |
| `Capture-HybridMemoryReference.ps1` | 保存 ahk/hybrid 内存参考 |
| `Open-HybridSignoffDashboard.ps1` | 采集并打开看板 |

**输出**：`Cache/debug/hybrid_signoff_dashboard.json`、`hybrid_manual_signoff.json`、`hybrid_reference_contract.json` 等。

## UI-01 双指标

- **sessionDrift**（主判）：本轮 UI 环 before/after 的 **uiPrivateMiB**（total − SearchCore，与 Patch C 多卡一致）；**before/after 均先 wait SearchCore 完全退出（必要时 force kill）+ IdleSec 再采样**
- **totalSessionDrift**（辅）：含 SearchCore 的 totalPrivateMiB，仅 warning
- **refDrift**（辅判）：after vs `hybrid_signoff_reference_hybrid.json` 的 uiPrivateMiB
- warm-session：`refDrift > 10%` 仅 warning，不阻断
- formal-cold：需托盘冷启动（pid 变化）且 `refDrift <= 10%`

## UI-01 inject drain 前置

UI 环依赖 AHK 消费 hub inject（`hybrid_signoff_inject_result.json` 写入 `PING_OK`）。重载后若 drain 未启动，UI-01 会降级 keys 并 FAIL。

```powershell
# 1) 托盘「重启脚本」或 Ctrl+Shift+Q（须看到 hybrid_manual_probe.log 新行 signoff_drain_timer_on）
.\Invoke-HybridInjectPing.ps1

# 2) uiPrivate 口径离线自检（不依赖 live niuma）
.\Test-Ui01UiPrivateMetrics.ps1

# 3) 正式签收
.\Run-HybridManualSignoff.ps1 -SignoffMode warm-session -RefreshDashboard
```

## D→E 自动化一条龙

Hybrid 终验 + CP PerfGate（无键盘、无 Read-Host）：

```powershell
# 前置：牛马已运行，flags 为 hybrid+hub，inject ping 可用
.\Run-HybridCpSignoffPipeline.ps1

# 仅重跑 PerfGate（Hybrid 已通过）
.\Run-HybridCpSignoffPipeline.ps1 -SkipHybrid

# 仅 Hybrid 签收
.\Run-HybridCpSignoffPipeline.ps1 -SkipPerfGate
```

**输出**：`Cache/debug/hybrid_cp_signoff_pipeline.json`（汇总 `pass` / `cpReleasePass` / `exitCode` + 各 phase 状态）

**CP 发布票（P0）**：`cpReleasePass=true` 需手动 6 项（`cp_manual_release_checklist.json`）+ Hybrid warm-session + `manual_equivalent` PerfGate + `defaultHost=ahk` + legacy rollback。`wailsArchitecturePass` 仅记录，不阻断发布。

```powershell
.\Run-CpManualReleaseChecklist.ps1 -Init
.\Run-CpManualReleaseChecklist.ps1 -RecordId raycast_ux_ahk -Pass
.\Run-HybridCpSignoffPipeline.ps1
```

**退出码**：`0` 自动化 phase 全过；`1` Hybrid fail；`2` PerfGate fail；`3` preflight fail（`cpReleasePass` 见报告 JSON，含手动项）

**注意**：FTB UX 的 `inject_refresh` 在 hub `/inject/drain` 有 count 时也可能 PASS，但 UI 环 preflight 必须 AHK 写 `PING_OK`。

