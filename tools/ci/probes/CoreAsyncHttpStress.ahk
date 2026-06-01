#Requires AutoHotkey v2.0
#SingleInstance Force

#Include ..\..\..\modules\CoreAsyncHttp.ahk

global CHS_Total := 600
global CHS_MinTotal := 500
global CHS_Done := 0
global CHS_Results := Map()
global CHS_Start := A_TickCount
global CHS_TimeoutMs := 180000
global CHS_ReportPath := ""

if (A_Args.Length >= 1) {
    try {
        t := Integer(A_Args[1])
        if (t > 0)
            CHS_Total := t
    }
}
if (CHS_Total < CHS_MinTotal)
    CHS_Total := CHS_MinTotal
if (A_Args.Length >= 2) {
    try {
        tm := Integer(A_Args[2])
        if (tm >= 30000)
            CHS_TimeoutMs := tm
    }
}

SplitPath(A_LineFile, , &CHS_ScriptDir)
repoRoot := RegExReplace(CHS_ScriptDir, "\\scripts$")
cacheDir := repoRoot . "\Cache"
if !DirExist(cacheDir) {
    try DirCreate(cacheDir)
}
CHS_ReportPath := cacheDir . "\core_async_http_stress_report.txt"
try FileAppend("ts=" . A_Now . " total=" . CHS_Total . " timeout_ms=" . CHS_TimeoutMs . "`r`n", cacheDir . "\core_async_http_stress_last_start.txt", "UTF-8")

Loop CHS_Total {
    i := A_Index
    reqId := "stress_" . i
    opts := Map(
        "reqId", reqId,
        "tag", "stress",
        "timeoutMs", 1300,
        "connectTimeoutMs", 350,
        "sendTimeoutMs", 350,
        "receiveTimeoutMs", 1300,
        "maxRetries", 2,
        "retryDelayMs", 220,
        "retryBackoffFactor", 2.0,
        "retryMaxDelayMs", 1200,
        "retryJitterMs", 80,
        "sampleLogRate", 1
    )
    HttpGetAsync("http://127.0.0.1:9/ping?i=" . i, CHS_OnDone, opts)
}

while (CHS_Done < CHS_Total && (A_TickCount - CHS_Start) < CHS_TimeoutMs) {
    Sleep(50)
}

snap := CoreAsyncHttp_DebugSnapshot()
elapsed := A_TickCount - CHS_Start
timedOut := (CHS_Done < CHS_Total)
report := []
report.Push("core_async_http_stress")
report.Push("ts=" . A_Now)
report.Push("total=" . CHS_Total)
report.Push("done=" . CHS_Done)
report.Push("timed_out=" . (timedOut ? "1" : "0"))
report.Push("elapsed_ms=" . elapsed)
report.Push("active_after=" . snap["active"])
report.Push("retry_jobs_after=" . snap["retryJobs"])
report.Push("error_code_counts:")
for code, cnt in CHS_Results
    report.Push("  " . code . "=" . cnt)

outPath := CHS_ReportPath
try FileDelete(outPath)
try {
    for _, line in report
        FileAppend(line . "`r`n", outPath, "UTF-8")
} catch {
    ; fallback path for rare unicode-path issues
    alt := A_Temp . "\core_async_http_stress_report.txt"
    try FileDelete(alt)
    for _, line in report
        FileAppend(line . "`r`n", alt, "UTF-8")
}

pass := (!timedOut && CHS_Done >= CHS_Total && CHS_Total >= CHS_MinTotal && snap["active"] = 0 && snap["retryJobs"] = 0)
ExitApp(pass ? 0 : (timedOut ? 2 : 1))

CHS_OnDone(ret, args*) {
    global CHS_Done, CHS_Results
    CHS_Done += 1
    code := "unknown"
    try {
        if (ret is Map && ret.Has("errorCode"))
            code := String(ret["errorCode"])
        else if (ret is Map && ret.Has("phase"))
            code := "phase_" . String(ret["phase"])
    }
    CHS_Results[code] := CHS_Results.Has(code) ? (Integer(CHS_Results[code]) + 1) : 1
}
