#Requires AutoHotkey v2.0
; Hermes 8642 连通性诊断（无 #Include）。双击同目录「运行Hermes连接诊断.bat」或本文件。

Probe_HttpGet(url, authBearer, timeoutMs := 8000) {
    start := A_TickCount
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        if RegExMatch(String(url), "i)^https?://(127\.0\.0\.1|localhost)(:\d+)?")
            try whr.SetProxy(1)
        whr.Open("GET", url, false)
        t := Max(3000, Integer(timeoutMs))
        whr.SetTimeouts(t, t, t, t)
        if (authBearer != "")
            whr.SetRequestHeader("Authorization", "Bearer " . authBearer)
        whr.Send()
        status := Integer(whr.Status)
        return Map(
            "ok", status >= 200 && status < 300,
            "status", status,
            "error", status >= 200 && status < 300 ? "" : ("HTTP " . status),
            "elapsedMs", A_TickCount - start
        )
    } catch as e {
        return Map("ok", false, "status", 0, "error", e.Message, "elapsedMs", A_TickCount - start)
    }
}

Probe_TcpOpen(host, port) {
    if (host = "localhost")
        host := "127.0.0.1"
    port := Integer(port)
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        try whr.SetProxy(1)
        whr.Open("GET", "http://" . host . ":" . port . "/health", false)
        whr.SetTimeouts(1500, 1500, 1500, 1500)
        whr.Send()
        return true
    } catch {
        return false
    }
}

out := A_ScriptDir . "\probe_hermes_test_conn_result.txt"
FileAppend("start`n", out, "UTF-8")

key := ""
envPath := EnvGet("LOCALAPPDATA") . "\hermes\.env"
apiSt := ""
gwPath := EnvGet("LOCALAPPDATA") . "\hermes\gateway_state.json"
if FileExist(gwPath) {
    try {
        if RegExMatch(FileRead(gwPath, "UTF-8"), '"api_server"\s*:\s*\{[^}]*"state"\s*:\s*"([^"]+)"', &m)
            apiSt := m[1]
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}
if FileExist(envPath) {
    raw := FileRead(envPath, "UTF-8")
    if RegExMatch(raw, "m)^API_SERVER_KEY\s*=\s*([^\r\n#;]+)", &mk)
        key := Trim(mk[1])
}

host := "127.0.0.1"
port := 8642
txt := ""
txt .= "script_dir=" . A_ScriptDir . "`n"
txt .= "env=" . envPath . "`n"
txt .= "key_len=" . StrLen(key) . "`n"
txt .= "api_server_state=" . apiSt . "`n"
txt .= "tcp_8642=" . (Probe_TcpOpen(host, port) ? "yes" : "no") . "`n"

r1 := Probe_HttpGet("http://" . host . ":" . port . "/health", key, 6000)
txt .= "health_ok=" . (r1.Get("ok", false) ? "yes" : "no") . "`n"
txt .= "health_status=" . Integer(r1.Get("status", 0)) . "`n"
txt .= "health_err=" . String(r1.Get("error", "")) . "`n"

r2 := Probe_HttpGet("http://" . host . ":" . port . "/v1/models", key, 6000)
txt .= "models_ok=" . (r2.Get("ok", false) ? "yes" : "no") . "`n"
txt .= "models_status=" . Integer(r2.Get("status", 0)) . "`n"
txt .= "models_err=" . String(r2.Get("error", "")) . "`n"

if (r1.Get("ok", false) || r2.Get("ok", false))
    txt .= "verdict=Hermes API Server 正常。请完全退出并重启牛马后再在设置里点「测试连接」。`n"
else if (apiSt = "connected")
    txt .= "verdict=Gateway 显示已连接，但 HTTP 鉴权失败；请核对 .env 的 API_SERVER_KEY。`n"
else if Probe_TcpOpen(host, port)
    txt .= "verdict=8642 已监听；可执行 hermes gateway restart 后重试。`n"
else
    txt .= "verdict=8642 未监听；请启动 Hermes 并 hermes gateway restart。`n"

FileAppend(txt, out, "UTF-8")
ExitApp(0)
