#Requires AutoHotkey v2.0
; Simulates rapid supersede of CloudPlayer request ids and logs cloudplayer_drop_stale_req.

#Include ..\modules\AsyncGuardrails.ahk
#Include ..\modules\CoreAsyncHttp.ahk

repoRoot := RegExReplace(A_ScriptDir, "\\scripts$")
cacheDir := repoRoot . "\Cache"
if !DirExist(cacheDir)
    try DirCreate(cacheDir)
logPath := cacheDir . "\core_async_http.log"

domain := "cloudplayer:fs_list"
reqA := "cp_race_a_" . A_TickCount
reqB := "cp_race_b_" . A_TickCount

AsyncGuardrails_UpdateLatest(domain, reqA)
AsyncGuardrails_UpdateLatest(domain, reqB)

drops := 0
if AsyncGuardrails_ShouldDropStale(domain, reqA) {
    line := "[" . A_Now . "][cloudplayer_drop_stale_req] kind=fs_list req_id=" . reqA . " probe=race_supersede`r`n"
    try FileAppend(line, logPath, "UTF-8")
    drops += 1
}
if !AsyncGuardrails_ShouldDropStale(domain, reqB) {
    CoreAsyncHttp_Log("cloudplayer_stale_race_fail", "kind=fs_list req_id=" . reqB . " expected_current=1")
    ExitApp(2)
}

report := cacheDir . "\cloudplayer_stale_race_report.txt"
try FileDelete(report)
FileAppend(
    "cloudplayer_stale_race`n"
    "ts=" . FormatTime(, "yyyyMMddHHmmss") . "`n"
    "drops_logged=" . drops . "`n"
    "RESULT=" . (drops > 0 ? "PASS" : "FAIL") . "`n",
    report, "UTF-8"
)
ExitApp(drops > 0 ? 0 : 1)
