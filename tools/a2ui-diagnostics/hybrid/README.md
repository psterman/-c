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
| `Capture-HybridMemoryReference.ps1` | 保存 ahk/hybrid 内存参考 |
| `Open-HybridSignoffDashboard.ps1` | 采集并打开看板 |

**输出**：`Cache/debug/hybrid_signoff_dashboard.json`、`hybrid_manual_signoff.json`、`hybrid_reference_contract.json` 等。

## UI-01 双指标

- **sessionDrift**（主判）：本轮 UI 环 before/after
- **refDrift**（辅判）：after vs `hybrid_signoff_reference_hybrid.json`
- warm-session：`refDrift > 10%` 仅 warning，不阻断
- formal-cold：需托盘冷启动（pid 变化）且 `refDrift <= 10%`

