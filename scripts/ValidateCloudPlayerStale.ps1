param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Must-Exist {
    param([string]$Path)
    if (!(Test-Path $Path)) { throw "Missing file: $Path" }
}

function Contains-Pattern {
    param(
        [string]$Path,
        [string]$Pattern
    )
    return [bool](Select-String -LiteralPath $Path -Pattern $Pattern -SimpleMatch -ErrorAction SilentlyContinue)
}

$cloudAhk = Join-Path $Root "modules\CloudPlayer.ahk"
$cloudHtml = Join-Path $Root "CloudPlayer.html"
$coreLog = Join-Path $Root "Cache\core_async_http.log"

Must-Exist $cloudAhk
Must-Exist $cloudHtml

$coreAhk = Join-Path $Root "modules\CoreAsyncHttp.ahk"

$checks = @(
    [pscustomobject]@{ Name = "html_has_pendingDownloadReqId"; Pass = (Contains-Pattern $cloudHtml "pendingDownloadReqId") },
    [pscustomobject]@{ Name = "html_has_pendingImportTaskId"; Pass = (Contains-Pattern $cloudHtml "pendingImportTaskId") },
    [pscustomobject]@{ Name = "html_has_getEventReqId"; Pass = (Contains-Pattern $cloudHtml "function getEventReqId") },
    [pscustomobject]@{ Name = "html_has_task_id_gate"; Pass = (Contains-Pattern $cloudHtml "taskId || data.reqId || data.requestId") },
    [pscustomobject]@{ Name = "html_import_gate"; Pass = (Contains-Pattern $cloudHtml "isCurrentImportTaskEvent") },
    [pscustomobject]@{ Name = "html_download_gate"; Pass = (Contains-Pattern $cloudHtml "isCurrentDownloadEvent") },
    [pscustomobject]@{ Name = "ahk_marks_latest_req"; Pass = (Contains-Pattern $cloudAhk "CloudPlayer_MarkLatestReq(") },
    [pscustomobject]@{ Name = "ahk_async_guardrails_stale"; Pass = (Contains-Pattern $cloudAhk "AsyncGuardrails_ShouldDropStale") },
    [pscustomobject]@{ Name = "ahk_queue_payload_meta"; Pass = (Contains-Pattern $cloudAhk "CloudPlayer_QueuePayload(") },
    [pscustomobject]@{ Name = "ahk_drops_stale_req"; Pass = (Contains-Pattern $cloudAhk "cloudplayer_drop_stale_req") },
    [pscustomobject]@{ Name = "ahk_response_has_requestId"; Pass = (Contains-Pattern $cloudAhk "requestId") },
    [pscustomobject]@{ Name = "ahk_response_has_phase"; Pass = (Contains-Pattern $cloudAhk '"phase"') },
    [pscustomobject]@{ Name = "ahk_response_has_errorCode"; Pass = (Contains-Pattern $cloudAhk '"errorCode"') },
    [pscustomobject]@{ Name = "core_result_has_requestId"; Pass = (Test-Path $coreAhk) -and (Contains-Pattern $coreAhk '"requestId"') }
)

$allPass = $true
Write-Output "== CloudPlayer Stale Contract Validation =="
Write-Output "root=$Root"
foreach ($c in $checks) {
    $mark = if ($c.Pass) { "PASS" } else { "FAIL" }
    Write-Output ("[{0}] {1}" -f $mark, $c.Name)
    if (-not $c.Pass) { $allPass = $false }
}

$staleLogCount = 0
if (Test-Path $coreLog) {
    $staleLogCount = (Select-String -LiteralPath $coreLog -Pattern "cloudplayer_drop_stale_req" -SimpleMatch | Measure-Object).Count
}
Write-Output ("runtime_stale_drop_logs={0}" -f $staleLogCount)

if ($allPass) {
    Write-Output "RESULT=PASS"
    exit 0
}

Write-Output "RESULT=FAIL"
exit 1
