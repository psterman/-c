# AHK Async Acceptance Report

**锁定方式：** 仅当 `scripts/LockAsyncAcceptance.ps1` 成功并生成 `Cache/ahk_async_acceptance_locked.txt` 时，视为红线验收通过。

## 红线验收标准

| 红线 | 要求 | 锁定字段 |
|------|------|----------|
| 500+ 压测 | `total ≥ 500` 且 `active_after=0`、`retry_jobs_after=0` | `stress_total`, `stress_active_after` |
| 5 分钟断网恢复 | `offline_ms ≥ 300000`、`online_ok ≥ 1`、`pass=1`、句柄归零 | `recovery_offline_ms`, `recovery_pass` |
| VoiceInput | 所有 Send/IME/网络副作用在 `VoiceInputEffects.ahk` | 代码审查 + FSM 单入口 |

> **注意：** `Cache/core_async_http_stress_last_start.txt` 仅记录启动参数；**不以之为准**。旧烟测 `total=5` 不代表未通过，以 `core_async_http_stress_report.txt` 与锁定文件为准。

## 一键锁定（推荐）

```powershell
powershell -ExecutionPolicy Bypass -File scripts\LockAsyncAcceptance.ps1
```

预计耗时：压测 ~10s + 断网恢复 ~8min。

## 分项复跑

```powershell
powershell -ExecutionPolicy Bypass -File scripts\RunAsyncGuardrailsE2E.ps1 -StressTotal 600
powershell -ExecutionPolicy Bypass -File scripts\ValidateAsyncGuardrails.ps1 -MinRequests 500
powershell -ExecutionPolicy Bypass -File scripts\RunRecoveryProbeE2E.ps1
powershell -ExecutionPolicy Bypass -File scripts\ValidateRecoveryProbe.ps1
```

## VoiceInput effect 层（副作用归属）

| 函数 | 文件 |
|------|------|
| Cursor 面板 start/stop/pause/resume | `VoiceInputEffects.ahk` |
| 发送到 Cursor | `VoiceInputEffect_SendToCursor` |
| 搜索 IME 启停 | `VoiceInputEffect_SearchStartListening` / `SearchStopListening` |
| 搜索执行 | `VoiceInputEffect_RunVoiceSearch` |
| 模块内保留 | GUI 构建、`Show*/Hide*Panel`（无 Send/网络） |

## 四项改造状态

| 项 | 状态 |
|----|------|
| A) CloudPlayer 事件驱动 | 已落地 |
| B) VoiceInput 状态机 | 已落地（副作用已迁入 effect 层） |
| C) SQL 启动批处理 | 已落地 |
| D) requestId/stale | 已落地 |
