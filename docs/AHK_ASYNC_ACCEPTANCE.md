# AHK Async Acceptance Report

Generated: 2026-05-17

## Track 0 — Automated checks

### CoreAsyncHttp stress (`scripts/CoreAsyncHttpStress.ahk`)

| Metric | Result |
|--------|--------|
| total | 600 |
| done | 600 |
| timed_out | 0 |
| active_after | **0** |
| retry_jobs_after | **0** |
| elapsed_ms | 2531 |

Report: `Cache/core_async_http_stress_report.txt`

### CoreAsyncHttp recovery (`scripts/CoreAsyncHttpRecoveryProbe.ahk`)

Smoke run: `AutoHotkey64.exe scripts\CoreAsyncHttpRecoveryProbe.ahk 10000 800 90000`

See: `Cache/core_async_http_recovery_report.txt` (`pass=1` when `online_ok>0` and `active_after=0`, `retry_jobs_after=0`).

Latest smoke: stress 600/600 done, `active_after=0`; recovery probe report written (check `pass` field for network-dependent online phase).

### CloudPlayer stale contract (`scripts/ValidateCloudPlayerStale.ps1`)

**RESULT=PASS** (static contract checks)

## Manual follow-up

- CloudPlayer race: rapid download/import cancel — confirm `cloudplayer_drop_stale_req` in `Cache/core_async_http.log`
- Full 5-minute offline recovery: `AutoHotkey64.exe scripts\CoreAsyncHttpRecoveryProbe.ahk` (defaults)
