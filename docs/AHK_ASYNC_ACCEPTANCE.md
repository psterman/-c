# AHK Async Acceptance Report

## Batch completion checklist

| Batch | Scope | Status |
|-------|--------|--------|
| 0 | SQL registry + FTS5 batch + stale contract doc + `ValidateRequestIdStaleContract.ps1` | Done |
| 1 | ConfigWebView + NiumaTtyd stale gates | Done |
| 2 | CloudPlayer download FS via queue walk + CoreAsyncHttp sync bridge | Done |
| 3 | CloudPlayer import/admin via `CloudPlayer_HttpJson` → CoreAsyncHttp bridge | Done |
| 4 | VoiceInput search FSM (`search_*` states) | Done |
| 5 | `SendVoiceSearchToBrowser` in effects | Done |
| 6 | Validators + `LockAsyncAcceptance.ps1` | See below |

## Locked infrastructure (CoreAsyncHttp)

Run: `powershell -ExecutionPolicy Bypass -File scripts\LockAsyncAcceptance.ps1`

Artifacts: `Cache/ahk_async_acceptance_locked.txt`, `Cache/async_guardrails_validation.txt`, `Cache/async_recovery_validation.txt`

## Four-refactor validators

```powershell
powershell -ExecutionPolicy Bypass -File scripts\ValidateFourRefactors.ps1
powershell -ExecutionPolicy Bypass -File scripts\ValidateRequestIdStaleContract.ps1
powershell -ExecutionPolicy Bypass -File scripts\ValidateVoiceInputFsm.ps1
powershell -ExecutionPolicy Bypass -File scripts\CollectStaleDropLogs.ps1
```

## Notes

- `CloudPlayer_HttpJson` is a **sync bridge** over `HttpJsonAsync` (import/admin/download). Call sites remain; traffic uses CoreAsyncHttp lifecycle.
- VoiceInput module may still contain `Send` in legacy GUI/CLI helpers; browser search `Send`/`Run` moved to `VoiceInputEffects.ahk`.
- FTS5 startup DDL runs via `StartupSql_Register("fts5_schema")`; migrations/triggers still run inline after batch.
