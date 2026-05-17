# AHK Async Guardrails

This document codifies required guardrails for async/state-machine refactors.

## 1) Callback lifecycle and reference cleanup

- Every request must finalize via one path: `done | error | timeout | cancelled`.
- On finalize, always release strong references:
  - `req.cb := 0`
  - `req.whr := 0`
  - `Map.Delete(reqId)`
- Cancel must use the same finalize path, not a side-path.

## 2) Re-entrancy protection

- State-machine `dispatch(event)` must be single-entry with queueing.
- Use `Critical` only for short state mutation windows.
- Never run I/O-heavy effects inside `Critical`.

## 3) Callback signature compatibility

- Core layer should emit one `result` map as the canonical callback payload.
- For legacy callbacks, use tolerant invocation (`args*` or guarded invocation).
- Never assume business callbacks all share identical arity.

## 4) Timer backoff policy

- Avoid `SetTimer(fn, -1)` loops in batch pipelines/state loops.
- Use `-10ms` minimum delay; use `-20~-50ms` for I/O-heavy loops.
- Retries must use bounded exponential backoff (+ jitter recommended).

## 5) requestId / stale protocol

- Canonical business field: `requestId`.
- Compatibility field: `reqId` (optional mirror).
- Response metadata should include: `phase`, `errorCode`, `ts`.

## 6) CloudPlayer download_folder event contract
- Request:
  - `type=cloudplayer_download_folder`
  - fields: `reqId` (or `requestId`), `path`, `name`, `token?`
- Cancel:
  - `type=cloudplayer_download_cancel`
  - fields: `reqId` (or `requestId`)
- Progress event:
  - `type=cloudplayer_download_progress`
  - fields: `reqId`, `requestId`, `phase`, `percent`, `message`, `ts`
- Result event:
  - `type=cloudplayer_download_result`
  - fields: `reqId`, `requestId`, `phase`, `ok`, `errorCode`, `message`, `path`, `name`, `ts`
- Stale policy:
  - AHK side drops stale by latest-req gate and logs `cloudplayer_drop_stale_req`.
  - Frontend side only consumes events matching current pending `reqId`.
  - If `pendingDownloadReqId` exists and event has no `reqId/requestId`, treat it as stale and ignore it.

## 7) CloudPlayer import task gate
- Request (`cloudplayer_import_storage` / `cloudplayer_import_aliyun`) should carry:
  - `taskId` (recommended), plus `reqId=requestId=taskId` for compatibility.
- Progress/result/state events should carry:
  - `taskId`, `reqId`, `requestId`, `phase`, `errorCode`, `ts`.
- Frontend must keep one session-level `pendingImportTaskId` and ignore unmatched task events.
- If `pendingImportTaskId` exists and an import event has no `taskId/reqId/requestId`, treat it as stale and ignore it.

## 8) Frontend host-event gate helper rule
- In `CloudPlayer.html`, prefer shared helpers for host event gating:
  - request id extractor: `getEventReqId(data)`
  - pending matcher: `isCurrentPendingEvent(pendingId, eventId)`
- Avoid ad-hoc inline comparisons in each event branch; new async events should reuse these helpers.
- UI must drop stale responses by request baseline (session/global scope).

## 9) Retry storm and handle governance

- Enforce `maxRetries`, timeout budget and backoff caps.
- Retry timer must check `cancelled` first.
- Always release connection/request handles on terminal states.

## 10) New Async Event Onboarding Template
- Step 1: Define ID strategy
  - Use `makeReqId("<prefix>")` for request-scoped flows.
  - For task flows, generate `taskId` once and mirror `reqId=requestId=taskId`.
- Step 2: Define pending baseline variable
  - Example: `pendingXxxReqId` or `pendingXxxTaskId` in session/global scope.
- Step 3: Add gate helpers
  - Extractor: `getEventReqId(data)` or task extractor (`taskId || reqId || requestId`).
  - Matcher: `isCurrentPendingEvent(pendingId, eventId)`.
- Step 4: Gate host events
  - In handler branch, first line must be gate check.
  - If pending exists and event id is missing, treat as stale and ignore.
- Step 5: Send protocol-complete payloads
  - Requests/events carry `requestId` (and `reqId` for compatibility).
  - Responses include `phase`, `errorCode`, `ts`.
- Step 6: Add stale observability
  - AHK side logs `cloudplayer_drop_stale_req` when dropping stale events.
- Step 7: Verify with race scenarios
  - rapid re-trigger, cancel + restart, late response after page switch.

## 11) Module onboarding checklist (requestId / stale)

| Module | stale domain | drop log tag | Mark latest | AttachMeta on host events |
|--------|--------------|--------------|-------------|---------------------------|
| CloudPlayer | `cloudplayer:<kind>` | `cloudplayer_drop_stale_req` | `CloudPlayer_MarkLatestReq` | `CloudPlayer_QueuePayload` |
| ClipboardPanel | session `g_CP_RequestID` | `cp_drop_stale_req` | host message baseline | WebView payload |
| SearchCenterWebView | token | `intent_drop_stale_token` | `g_SCWV_CurrentToken` | bridge payloads |
| GlobalDragHoleOverlay | token | `gdho_*_drop_stale` | `g_GDHO_CurrentToken` | WebView payloads |
| ConfigWebView | `config:<path>` | `config_drop_stale_req` | `ConfigWebView_MarkLatestReq` | async JSON callbacks |
| NiumaTtyd | `ttyd:<action>` | `ttyd_drop_stale_req` | `NiumaTtyd_MarkLatestReq` | `NiumaTtyd_EmitStatus` / deferred jobs |

**Required response fields:** `requestId` (canonical), optional `reqId`, `phase`, `errorCode`, `ts`.

**Bridge rule ([`modules/AhkWebViewBridge.ahk`](modules/AhkWebViewBridge.ahk)):** bridge forwards IDs only; host module owns stale gates.

Validate with: `scripts/ValidateRequestIdStaleContract.ps1`

## Acceptance checks

- 500+ request stress run returns active request table to zero.
- Offline/timeout scenario does not cause CPU spin or timer storms.
- Rapid tab/session switch does not apply stale payloads.
- Cancel during retry-wait does not resurrect requests.
