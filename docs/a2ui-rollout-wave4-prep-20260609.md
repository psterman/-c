# A2UI Wave 4 准备（2026-06-09）

Day 4 决策前的实网与观察收口清单。

---

## 自动化门禁

```powershell
cd <repo-root>
powershell -ExecutionPolicy Bypass -File scripts\Run-A2uiRolloutGate.ps1 -SkipBuild
powershell -ExecutionPolicy Bypass -File scripts\Run-A2uiL3ProbeSummary.ps1
powershell -ExecutionPolicy Bypass -File scripts\Run-A2uiDay4Decision.ps1
```

产物：`Cache/debug/a2ui_day4_decision_last.json`

---

## 实网烟测（可选）

### OpenClaw Adapter（生产链）

```powershell
$env:OPENCLAW_GATEWAY_TOKEN = "<token>"
powershell -ExecutionPolicy Bypass -File scripts\Run-OpenClawAdapterSmoke.ps1
```

无 token 时 **exit 2 SKIP**，不阻断 gate。

### Hermes openai-chat（实验）

```powershell
$env:HERMES_API_SERVER_KEY = "<key>"
# 可选：$env:NMER_A2UI_PROVIDER_URL = "http://127.0.0.1:8642/v1"
powershell -ExecutionPolicy Bypass -File scripts\Run-HermesProviderLive.ps1
```

---

## 7 日观察

```powershell
# 每日一次（可计划任务）
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\Run-A2uiDailyObservation.ps1
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\Evaluate-A2uiObservation.ps1
```

多卡内存（**先 step 0 采参考基线**，再 1/5/20 卡；delta = 相对参考的总私有内存增量）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Run-A2uiMultiCardMemory.ps1
```

若 `deltaPerCardMiB` 为负，说明参考步未采或 CP 卡数未按提示变化，需重跑。

---

## ADP L3 完整 PASS

1. 重载 `牛马.ahk`
2. 打开 CP → **Ctrl+Shift+U**
3. 探针会 **ingest + 内联演示 envelope 预备** → 预期 `ADP_PASS`

---

## 决策阈值

见 [`a2ui-gray-cutover-policy.md`](./a2ui-gray-cutover-policy.md) §6。
