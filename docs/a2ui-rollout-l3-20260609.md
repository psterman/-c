# A2UI L3 探针收口（2026-06-09）

本机 `Cache/debug/*_probe_last.json` 汇总。

---

## 当前读数（hybrid 探针）

| 探针 | 热键 | code | via | 说明 |
|------|------|------|-----|------|
| OC-5 | Ctrl+Shift+O | `OC5_PASS` | offline | L1+LIVE 样本绿；WebView 可超时 |
| 灰度 | Ctrl+Shift+G | `GRAY_PASS` | ahk_offline | 需 `local/nmer-flags.json` + 重载牛马 |
| Adapter | Ctrl+Shift+U | `ADP_L2_PASS_L3_PENDING` → 重载后 `ADP_PASS` | hybrid | 探针自动 ingest + 内联 envelope 预备 |

WebView `TIMEOUT` **不阻断**离线结论；重载后 Adapter 探针会**自动 ingest** 演示 JSONL。

---

## 命令

```powershell
cd <repo-root>
powershell -ExecutionPolicy Bypass -File scripts\Run-A2uiL3ProbeSummary.ps1
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\Run-A2uiDay4Decision.ps1
```

---

## 提升到 ADP_PASS（完整 L3）

1. 重载 `牛马.ahk`（含自动 ingest 补丁）
2. `Run-ProbePrep.ps1` 或 Ctrl+Shift+U
3. 确认 CP 已连 sidecar WS（SearchDebug 见 bridge healthy）
4. 再按 Ctrl+Shift+U → 预期 `ADP_PASS`

---

## 待补

- 多卡内存 `-CardCount 1/5/20`
- 7 日日检 `a2ui_observation_history.jsonl`
- Hermes 实网（可选）
