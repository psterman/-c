# A2UI Rollout Wave 3 进度（Provider + 观察）

---

## 已完成

| 票 | 交付 | 验证 |
|----|------|------|
| **P3-1** | `ProviderCapability` + `/agent/health` | `go test -run Capability` |
| **P3-2** | WS replay 重连单测 | `TestA2UIWebSocketReplayOnReconnect` |
| **观察** | `Evaluate-A2uiObservation.ps1` | `a2ui_observation_eval_last.json` |
| **压测** | `Run-A2uiWsReplayStress.ps1` | Go replay/health tests |
| **Day 3.5** | Hermes 异常流单测 + 隔离 | `Run-HermesProviderContract.ps1` |
| **探针预备** | `Run-ProbePrep.ps1` + hybrid 探针 | flags + ingest → Ctrl+Shift+G/U |

---

## 命令

```powershell
cd apps\nmer-wails; go test ./poc/... -run "Capability|Replay|Health"
powershell -ExecutionPolicy Bypass -File scripts\Run-A2uiWsReplayStress.ps1
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\Run-A2uiDailyObservation.ps1
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\Evaluate-A2uiObservation.ps1
# 须在仓库根目录执行，或：
cd <repo-root>
powershell -ExecutionPolicy Bypass -File scripts\Run-A2uiRolloutGate.ps1 -SkipBuild
# 等价：tools\a2ui-diagnostics\Run-A2uiRolloutGate.ps1
powershell -ExecutionPolicy Bypass -File scripts\Run-HermesProviderContract.ps1
powershell -ExecutionPolicy Bypass -File scripts\Run-ProbePrep.ps1
```

---

## 待做

- Hermes **实网**烟测（`NMER_A2UI_PROVIDER=openai-chat` + 8642）
- 7×24 观察积累（`a2ui_observation_history.jsonl`）
- OC-5 L3、多卡内存 `-CardCount 1/5/20`
