#Requires AutoHotkey v2.0
#SingleInstance Off

#Include ..\..\..\modules\CoreAsyncHttp.ahk

global CRP_OfflineMs := 300000
global CRP_IntervalMs := 1200
global CRP_TimeoutMs := 120000
global CRP_OfflineUrl := "http://127.0.0.1:9/recovery_probe"
global CRP_OnlineUrl := "https://www.msftconnecttest.com/connecttest.txt"
global CRP_Sent := 0
global CRP_Done := 0
global CRP_OfflineFail := 0
global CRP_OnlineOk := 0
global CRP_OnlineFail := 0
global CRP_Pending := 0

if (A_Args.Length >= 1) {
    try {
        v := Integer(A_Args[1])
        if (v >= 10000)
            CRP_OfflineMs := v
    }
}
if (A_Args.Length >= 2) {
    try {
        v2 := Integer(A_Args[2])
        if (v2 >= 200)
            CRP_IntervalMs := v2
    }
}
if (A_Args.Length >= 3) {
    try {
        v3 := Integer(A_Args[3])
        if (v3 >= 30000)
            CRP_TimeoutMs := v3
    }
}
if (A_Args.Length >= 4) {
    u := Trim(String(A_Args[4]))
    if (u != "")
        CRP_OfflineUrl := u
}
if (A_Args.Length >= 5) {
    u := Trim(String(A_Args[5]))
    if (u != "")
        CRP_OnlineUrl := u
}

CRP_OnDone(ret, args*) {
    global CRP_Pending, CRP_Done, CRP_OfflineFail, CRP_OnlineOk, CRP_OnlineFail
    CRP_Pending := Max(0, CRP_Pending - 1)
    CRP_Done += 1
    ok := false
    try ok := (ret is Map) && ret.Has("ok") && !!ret["ok"]
    phase := ""
    try phase := String(ret["phase"])
    if (phase = "retrying" || phase = "retry_wait")
        return
    reqId := ""
    try reqId := String(ret["reqId"])
    isOnline := (SubStr(reqId, 1, 11) = "recovery_on")
    if !ok {
        if (isOnline)
            CRP_OnlineFail += 1
        else
            CRP_OfflineFail += 1
    } else if (isOnline)
        CRP_OnlineOk += 1
}

CRP_SendOne(url, reqId) {
    global CRP_Pending, CRP_Sent
    CRP_Sent += 1
    CRP_Pending += 1
    opts := Map(
        "reqId", reqId,
        "tag", "recovery_probe",
        "timeoutMs", 2200,
        "connectTimeoutMs", 700,
        "sendTimeoutMs", 700,
        "receiveTimeoutMs", 2200,
        "maxRetries", 2,
        "retryDelayMs", 300,
        "retryBackoffFactor", 2.0,
        "retryMaxDelayMs", 1800,
        "retryJitterMs", 120,
        "sampleLogRate", 1
    )
    HttpGetAsync(url, CRP_OnDone, opts)
}

startTick := A_TickCount
offlineEnd := startTick + CRP_OfflineMs
nextAt := startTick
while ((A_TickCount - startTick) < CRP_OfflineMs) {
    if (A_TickCount >= nextAt) {
        CRP_SendOne(CRP_OfflineUrl, "recovery_off_" . CRP_Sent)
        nextAt := A_TickCount + CRP_IntervalMs
    }
    while (CRP_Pending > 0 && (A_TickCount - startTick) < CRP_OfflineMs)
        Sleep(25)
    Sleep(25)
}

onlinePhaseMs := CRP_TimeoutMs - CRP_OfflineMs
if (onlinePhaseMs < 60000)
    onlinePhaseMs := 60000
onlineStart := A_TickCount
nextAt := onlineStart
while ((A_TickCount - onlineStart) < onlinePhaseMs) {
    if (CRP_OnlineOk > 0 && CRP_Pending = 0)
        break
    if (A_TickCount >= nextAt) {
        CRP_SendOne(CRP_OnlineUrl, "recovery_on_" . CRP_Sent)
        nextAt := A_TickCount + CRP_IntervalMs
    }
    while (CRP_Pending > 0 && (A_TickCount - onlineStart) < onlinePhaseMs)
        Sleep(25)
    Sleep(25)
}

deadline := onlineStart + onlinePhaseMs + 15000
while (CRP_Pending > 0 && A_TickCount < deadline)
    Sleep(25)

snap := CoreAsyncHttp_DebugSnapshot()
elapsed := A_TickCount - startTick
crpPass := (CRP_OnlineOk > 0) && (snap["active"] = 0) && (snap["retryJobs"] = 0)

SplitPath(A_LineFile, , &scriptDir)
repoRoot := RegExReplace(scriptDir, "\\scripts$")
cacheDir := repoRoot . "\Cache"
if !DirExist(cacheDir)
    try DirCreate(cacheDir)
reportPath := cacheDir . "\core_async_http_recovery_report.txt"
report := []
report.Push("core_async_http_recovery_probe")
report.Push("ts=" . A_Now)
report.Push("offline_ms=" . CRP_OfflineMs)
report.Push("interval_ms=" . CRP_IntervalMs)
report.Push("timeout_ms=" . CRP_TimeoutMs)
report.Push("sent=" . CRP_Sent)
report.Push("done=" . CRP_Done)
report.Push("offline_fail=" . CRP_OfflineFail)
report.Push("online_ok=" . CRP_OnlineOk)
report.Push("online_fail=" . CRP_OnlineFail)
report.Push("active_after=" . snap["active"])
report.Push("retry_jobs_after=" . snap["retryJobs"])
report.Push("elapsed_ms=" . elapsed)
report.Push("pass=" . (crpPass ? "1" : "0"))
try FileDelete(reportPath)
for _, line in report
    FileAppend(line . "`r`n", reportPath, "UTF-8")
ExitApp(crpPass ? 0 : 1)
