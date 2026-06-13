# Surface Manager 门禁

Surface 运行时 trace 汇总与各阶段静态门禁（S2–S11、FTB Shell 等）。

**入口**：`Open-SurfaceGateDashboard.ps1` — 跑诊断并打开 `dashboards/dashboard-live.html`

**输出**：`surface_runtime_diagnosis.json`、`s8b3_gate_diagnosis.json`、`s8b3_phase2_gate.json` 等。

**S8 B3 阶段 2 静态门禁（脚手架）**：

```powershell
.\Diagnose-S8B3Phase2Gate.ps1
.\Diagnose-S8B3Phase2Gate.ps1 -WithFixtures   # 含 palette fixtures 回归
```
