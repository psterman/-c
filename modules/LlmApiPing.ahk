; LlmApiPing.ahk — 设置中心 / 智能定制 API 连通性测试（WinHttp 同步，不依赖 FloatingToolbar）

global LlmApiPing_MINIMAX_BASE_CN := "https://api.minimaxi.com/anthropic"
global LlmApiPing_MINIMAX_BASE_INTL := "https://api.minimax.io/anthropic"

/** 避免静态分析把内置 FuncExists 当成未赋值局部变量 */
LlmApiPing_HasFunc(name) {
    try return (%"FuncExists"%).Call(name)
    catch
        return false
}

LlmApiPing_Join(arr, sep := "") {
    out := ""
    if !(arr is Array)
        return String(arr)
    for i, v in arr
        out .= (i > 1 ? sep : "") . String(v)
    return out
}

LlmApiPing_StripSurroundingQuotes(key) {
    key := Trim(String(key))
    dq := Chr(34)
    loop {
        if (key = "")
            break
        changed := false
        c1 := SubStr(key, 1, 1)
        if (c1 = "'" || c1 = dq) {
            key := SubStr(key, 2)
            changed := true
        }
        if (key = "")
            break
        cL := SubStr(key, -1)
        if (cL = "'" || cL = dq) {
            key := SubStr(key, 1, -2)
            changed := true
        }
        if !changed
            break
    }
    return key
}

LlmApiPing_NormalizeApiKey(key) {
    key := Trim(String(key))
    if (key = "")
        return ""
    key := RegExReplace(key, "i)^\s*Bearer\s+", "")
    key := LlmApiPing_StripSurroundingQuotes(key)
    key := RegExReplace(key, "\s+", "")
    return key
}

LlmApiPing_NormalizeProvider(prov) {
    if LlmApiPing_HasFunc("UserStudio_NormalizeLlmProvider")
        return UserStudio_NormalizeLlmProvider(prov)
    prov := Trim(String(prov))
    if (prov = "anthropic")
        return "claude"
    if (prov = "codex")
        return "openai"
    return prov
}

LlmApiPing_BaseUrlMatchesProvider(prov, url) {
    if LlmApiPing_HasFunc("UserStudio_BaseUrlMatchesProvider")
        return UserStudio_BaseUrlMatchesProvider(prov, url)
    prov := LlmApiPing_NormalizeProvider(prov)
    url := Trim(String(url))
    if (url = "" || prov = "custom")
        return true
    low := StrLower(url)
    switch prov {
        case "kimi":
            return RegExMatch(low, "moonshot\.(cn|ai)")
        case "deepseek":
            return InStr(low, "deepseek")
        case "openai":
            return InStr(low, "api.openai.com") || InStr(low, "openai.azure.com")
                || (InStr(low, "azure.com") && InStr(low, "openai"))
                || InStr(low, "cognitiveservices.azure.com")
        case "minimax":
            return InStr(low, "minimax")
        case "gemini":
            return InStr(low, "generativelanguage.googleapis.com")
        case "claude":
            return InStr(low, "anthropic")
        case "qwen":
            return InStr(low, "dashscope")
        case "glm", "zhipu":
            return InStr(low, "bigmodel")
        case "siliconflow":
            return InStr(low, "siliconflow")
        case "ollama":
            return InStr(low, "11434") || InStr(low, "ollama")
        default:
            return true
    }
}

LlmApiPing_PresetFor(prov) {
    if LlmApiPing_HasFunc("UserStudio_LlmPresetFor")
        return UserStudio_LlmPresetFor(prov)
    prov := LlmApiPing_NormalizeProvider(prov)
    switch prov {
        case "minimax":
            return Map("baseUrl", "https://api.minimaxi.com/anthropic", "model", "MiniMax-M2.7")
        case "gemini":
            return Map("baseUrl", "https://generativelanguage.googleapis.com/v1beta", "model", "gemini-2.5-flash")
        case "deepseek":
            return Map("baseUrl", "https://api.deepseek.com/v1", "model", "deepseek-chat")
        case "kimi":
            return Map("baseUrl", "https://api.moonshot.cn/v1", "model", "kimi-k2.6")
        case "claude":
            return Map("baseUrl", "https://api.anthropic.com", "model", "claude-3-5-sonnet-latest")
        case "ollama":
            return Map("baseUrl", "http://127.0.0.1:11434/v1", "model", "nemotron-3-super:cloud")
        default:
            return Map("baseUrl", "https://api.openai.com/v1", "model", "gpt-4o-mini")
    }
}

LlmApiPing_EncodeUri(s) {
    if LlmApiPing_HasFunc("UriEncode")
        return UriEncode(s)
    return s
}

LlmApiPing_ClassifyNetworkError(msg, timeoutMs := 0) {
    low := StrLower(Trim(String(msg)))
    if (low = "")
        return ""
    if RegExMatch(low, "dns|name not resolved|can't resolve|cannot resolve|unknown host|无法解析|找不到服务器|未找到主机|0x80072ee7|11001|11002")
        return "DNS 解析失败"
    if RegExMatch(low, "proxy|tunnel|407|authentication required|proxy authentication|代理|0x80072f19|0x80072f78|0x80072f79")
        return "代理未同步或代理鉴权失败"
    if RegExMatch(low, "certificate|ssl|tls|secure channel|证书|0x80072f7d|0x80072f8f")
        return "TLS/证书握手失败"
    if RegExMatch(low, "refused|actively refused|connection refused|connectex|unreachable|network is unreachable|no route to host|无法连接|连接被拒绝|0x80072efd|0x8007274c")
        return "连接被拒绝或出站被阻断"
    if RegExMatch(low, "timeout|timed\s*out|超时|0x80072ee2|0x8007274d")
        return "请求超时"
    if (timeoutMs > 0)
        return "请求超时（约 " . Round(Max(3000, Integer(timeoutMs)) / 1000) . " 秒）"
    return ""
}

LlmApiPing_ParseUrlHostPort(url) {
    u := Trim(String(url))
    host := ""
    port := 443
    scheme := "https"
    if RegExMatch(u, "i)^(https?)://([^/:]+)(?::(\d+))?", &m) {
        scheme := StrLower(m[1])
        host := m[2]
        if (m[3] != "")
            port := Integer(m[3])
        else if (scheme = "http")
            port := 80
    }
    if (host = "localhost")
        host := "127.0.0.1"
    return Map("host", host, "port", port, "scheme", scheme)
}

LlmApiPing_WinHttpErrDetail(msg) {
    raw := Trim(String(msg))
    if (raw = "")
        return Map("code", "", "phase", "", "label", "")
    code := ""
    if RegExMatch(raw, "0x8007[0-9A-Fa-f]{4}|0x800727[0-9A-Fa-f]{2}", &m)
        code := StrUpper(m[0])
    else if RegExMatch(raw, "\b(\d{5})\b", &m2) && Integer(m2[1]) >= 10000
        code := m2[1]
    phase := ""
    label := ""
    switch code {
        case "0x80072EE7", "11001", "11002":
            phase := "dns", label := "DNS 无法解析主机名"
        case "0x80072EFD", "0x8007274C", "10061":
            phase := "connect", label := "TCP 连接被拒绝或不可达"
        case "0x80072EE2", "0x8007274D", "10060":
            phase := "timeout", label := "连接/发送超时"
        case "0x80072F7D":
            phase := "tls", label := "TLS/证书握手失败"
        case "0x80072F19", "0x80072F78", "0x80072F79":
            phase := "proxy", label := "代理不可达或代理鉴权失败"
        case "0x80072F8F", "0x80072EFE":
            phase := "reset", label := "连接被重置或中断"
        case "0x80072F0D":
            phase := "url", label := "URL 无效"
        default:
            if RegExMatch(raw, "i)name not resolved|dns|unknown host|无法解析|找不到服务器")
                phase := "dns", label := "DNS 解析失败"
            else if RegExMatch(raw, "i)proxy|407|tunnel")
                phase := "proxy", label := "代理相关错误"
            else if RegExMatch(raw, "i)certificate|ssl|tls|secure channel|证书")
                phase := "tls", label := "TLS/证书错误"
            else if RegExMatch(raw, "i)refused|cannot connect|connectex|unreachable|无法连接")
                phase := "connect", label := "无法建立连接"
            else if RegExMatch(raw, "i)timeout|timed\s*out|超时")
                phase := "timeout", label := "请求超时"
    }
    if (label = "")
        label := SubStr(raw, 1, 120)
    return Map("code", code, "phase", phase, "label", label, "raw", raw)
}

LlmApiPing_EnsureWsa() {
    static ready := false
    if ready
        return true
    wsaData := Buffer(400, 0)
    if DllCall("ws2_32\WSAStartup", "UShort", 0x0202, "Ptr", wsaData, "Int")
        return false
    ready := true
    return true
}

LlmApiPing_DnsLookupV4(host) {
    host := Trim(String(host))
    if (host = "")
        return Map("ok", false, "addrs", [], "error", "主机名为空")
    if (host = "localhost" || host = "127.0.0.1")
        return Map("ok", true, "addrs", ["127.0.0.1"], "error", "")
    if RegExMatch(host, "^\d{1,3}(\.\d{1,3}){3}$")
        return Map("ok", true, "addrs", [host], "error", "")
    if !LlmApiPing_EnsureWsa()
        return Map("ok", false, "addrs", [], "error", "WSA 初始化失败")
    hints := Buffer(48, 0)
    NumPut("Int", 2, hints, 0)
    NumPut("Int", 1, hints, 4)
    resultPtr := 0
    rc := DllCall("ws2_32\getaddrinfo", "AStr", host, "Ptr", 0, "Ptr", hints, "Ptr*", &resultPtr, "Int")
    if (rc != 0 || !resultPtr) {
        err := "getaddrinfo errno " . rc
        if (rc = 11001)
            err := "DNS 无记录 (WSAHOST_NOT_FOUND)"
        else if (rc = 11002)
            err := "DNS 临时失败 (WSATRY_AGAIN)"
        return Map("ok", false, "addrs", [], "error", err)
    }
    addrs := []
    cur := resultPtr
    loop 12 {
        if !cur
            break
        aiAddr := NumGet(cur, A_PtrSize = 8 ? 32 : 20, "Ptr")
        if aiAddr {
            b0 := NumGet(aiAddr, 4, "UChar")
            b1 := NumGet(aiAddr, 5, "UChar")
            b2 := NumGet(aiAddr, 6, "UChar")
            b3 := NumGet(aiAddr, 7, "UChar")
            ip := b0 . "." . b1 . "." . b2 . "." . b3
            if !ArrayHasValue(addrs, ip)
                addrs.Push(ip)
        }
        cur := NumGet(cur, A_PtrSize = 8 ? 40 : 24, "Ptr")
    }
    try DllCall("ws2_32\freeaddrinfo", "Ptr", resultPtr)
    if !addrs.Length
        return Map("ok", false, "addrs", [], "error", "DNS 未返回 IPv4 地址")
    return Map("ok", true, "addrs", addrs, "error", "")
}

LlmApiPing_ProxySummary(quick := false) {
    parts := []
    try {
        pe := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyEnable")
        ps := Trim(String(RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyServer")))
        if (pe)
            parts.Push("IE 代理: " . (ps != "" ? ps : "已启用但未配置地址"))
        else
            parts.Push("IE 代理: 未启用")
    } catch {
        parts.Push("IE 代理: 无法读取")
    }
    if quick
        return LlmApiPing_Join(parts, " · ")
    try {
        outFile := A_Temp . "\nmer_winhttp_proxy.txt"
        try FileDelete(outFile)
        RunWait(A_ComSpec . ' /c netsh winhttp show proxy > "' . outFile . '"', , "Hide")
        if FileExist(outFile) {
            raw := Trim(FileRead(outFile, "UTF-8"))
            try FileDelete(outFile)
            line := ""
            for ln in StrSplit(raw, "`n", "`r") {
                ln := Trim(ln)
                if (ln != "" && !InStr(ln, "当前的 WinHTTP 代理服务器设置") && !InStr(ln, "Current WinHTTP proxy"))
                    line .= (line != "" ? " " : "") . ln
            }
            if (line = "" || InStr(line, "直接访问") || InStr(line, "Direct access"))
                parts.Push("WinHTTP: 直连")
            else
                parts.Push("WinHTTP: " . line)
        }
    } catch {
        parts.Push("WinHTTP: 无法读取")
    }
    return LlmApiPing_Join(parts, " · ")
}

LlmApiPing_AttemptLabel(attempt) {
    if !(attempt is Map)
        return ""
    via := Trim(String(attempt.Get("via", "")))
    proxyMode := Integer(attempt.Get("proxyMode", 0))
    proxyTag := proxyMode = 1 ? "直连" : (proxyMode = 2 ? "系统代理" : "默认")
    st := Integer(attempt.Get("status", 0))
    ms := Integer(attempt.Get("elapsedMs", 0))
    err := Trim(String(attempt.Get("error", "")))
    code := Trim(String(attempt.Get("hresult", "")))
    if (st >= 200 && st < 300)
        return via . "(" . proxyTag . "): HTTP " . st . " · " . ms . "ms"
    detail := LlmApiPing_WinHttpErrDetail(err)
    if (code = "" && detail["code"] != "")
        code := detail["code"]
    if (st > 0)
        return via . "(" . proxyTag . "): HTTP " . st . " · " . ms . "ms — " . (detail["label"] != "" ? detail["label"] : err)
    core := detail["label"] != "" ? detail["label"] : err
    if (code != "")
        core := core . " [" . code . "]"
    return via . "(" . proxyTag . "): " . core . " · " . ms . "ms"
}

LlmApiPing_BuildNetworkDiagnostic(url, attempts, timeoutMs := 0) {
    ep := LlmApiPing_ParseUrlHostPort(url)
    host := ep.Get("host", "")
    port := Integer(ep.Get("port", 443))
    lines := []
    lines.Push("目标: " . Trim(String(url)))
    dns := LlmApiPing_DnsLookupV4(host)
    if dns["ok"]
        lines.Push("DNS: " . host . " → " . LlmApiPing_Join(dns["addrs"], ", ") . " ✓")
    else
        lines.Push("DNS: " . host . " ✗ " . dns.Get("error", "解析失败"))
    if dns["ok"] {
        ip := dns["addrs"][1]
        tcpMs := Min(3500, Max(1200, Integer(timeoutMs) // 4))
        tcpOk := LlmApiPing_TcpPortOpen(ip, port, tcpMs)
        if tcpOk
            lines.Push("TCP: " . ip . ":" . port . " 可连接 ✓")
        else
            lines.Push("TCP: " . ip . ":" . port . " 不可达/超时 ✗")
    }
    if (attempts is Array) {
        for att in attempts {
            lab := LlmApiPing_AttemptLabel(att)
            if (lab != "")
                lines.Push("尝试: " . lab)
        }
    }
    lines.Push("代理: " . LlmApiPing_ProxySummary(true))
    phase := ""
    if (attempts is Array) {
        for att in attempts {
            det := LlmApiPing_WinHttpErrDetail(att.Get("error", ""))
            if (det["phase"] != "") {
                phase := det["phase"]
                break
            }
        }
    }
    hint := ""
    if (phase = "dns" || !dns["ok"])
        hint := "建议: DNS 失败 → 检查本机 DNS、hosts、公司内网解析策略"
    else if (phase = "proxy")
        hint := "建议: 代理问题 → 在管理员终端执行 netsh winhttp import proxy source=ie，或关闭/修正 Clash 系统代理"
    else if (phase = "tls")
        hint := "建议: TLS 失败 → 检查公司 HTTPS 解密证书、系统根证书或代理 MITM"
    else if (phase = "connect")
        hint := "建议: DNS 正常但连接失败 → 检查防火墙、EDR、公司出口是否放行 " . host . ":" . port
    else if (phase = "timeout")
        hint := "建议: 超时 → 若 DNS/TCP 均失败多为网络阻断；若 TCP 成功而 HTTP 超时，检查 API 地址与代理"
    else if !dns["ok"]
        hint := "建议: 先修复 DNS，再重试测试连接"
    else
        hint := "建议: 核对 API Key、Base URL 与模型名；若仅 WinHTTP 失败可尝试 netsh winhttp import proxy source=ie"
    lines.Push(hint)
    return Map(
        "text", LlmApiPing_Join(lines, "`n"),
        "phase", phase,
        "dnsOk", !!dns["ok"],
        "host", host,
        "port", port
    )
}

LlmApiPing_FormatAttemptFailure(url, lastResult, attempts, timeoutMs := 0) {
    diag := LlmApiPing_BuildNetworkDiagnostic(url, attempts, timeoutMs)
    st := lastResult is Map ? Integer(lastResult.Get("status", 0)) : 0
    rawErr := lastResult is Map ? Trim(String(lastResult.Get("error", ""))) : ""
    head := ""
    if (st = 401)
        head := "HTTP 401 鉴权失败"
    else if (st = 403)
        head := "HTTP 403 禁止访问"
    else if (st = 404)
        head := "HTTP 404 接口不存在"
    else if (st = 429)
        head := "HTTP 429 限流"
    else if (st >= 500)
        head := "HTTP " . st . " 服务端错误"
    else {
        det := LlmApiPing_WinHttpErrDetail(rawErr)
        head := det["label"] != "" ? det["label"] : (rawErr != "" ? rawErr : "网络连接失败")
        if (det["code"] != "")
            head .= " [" . det["code"] . "]"
    }
    return Map("error", head . "`n" . diag["text"], "diag", diag)
}

LlmApiPing_IsLoopbackUrl(url) {
    return RegExMatch(String(url), "i)^https?://(127\.0\.0\.1|localhost)(:\d+)?/")
}

LlmApiPing_HttpSync(method, url, headers, body, timeoutMs := 18000) {
    attempts := []
    if LlmApiPing_IsLoopbackUrl(url) {
        r0 := LlmApiPing_HttpSyncCurl(method, url, headers, body, Min(10000, Max(3000, Integer(timeoutMs))))
        attempts.Push(Map(
            "via", "curl",
            "proxyMode", 0,
            "status", Integer(r0.Get("status", 0)),
            "error", String(r0.Get("error", "")),
            "hresult", String(r0.Get("hresult", "")),
            "elapsedMs", Integer(r0.Get("elapsedMs", 0))
        ))
        r0["attempts"] := attempts
        if !r0.Get("ok", false) && Integer(r0.Get("status", 0)) = 0 {
            formatted := LlmApiPing_FormatAttemptFailure(url, r0, attempts, timeoutMs)
            r0["error"] := formatted["error"]
            r0["diagnostics"] := formatted["diag"]["text"]
            r0["phase"] := formatted["diag"]["phase"]
        }
        return r0
    }
    t0 := A_TickCount
    budget := Max(4000, Integer(timeoutMs))
    if (method = "POST" && RegExMatch(String(url), "i)^https://")) {
        rC := LlmApiPing_HttpSyncCurl(method, url, headers, body, Min(10000, budget))
        attempts.Push(Map(
            "via", "curl",
            "proxyMode", 0,
            "status", Integer(rC.Get("status", 0)),
            "error", String(rC.Get("error", "")),
            "hresult", "",
            "elapsedMs", Integer(rC.Get("elapsedMs", 0))
        ))
        if Integer(rC.Get("status", 0)) > 0 {
            rC["attempts"] := attempts
            return rC
        }
        remain := Max(2000, budget - (A_TickCount - t0))
        if (remain >= 2000) {
            r2 := LlmApiPing_HttpSyncOnce(method, url, headers, body, Min(4000, remain), 2)
            attempts.Push(Map(
                "via", "winhttp",
                "proxyMode", 2,
                "status", Integer(r2.Get("status", 0)),
                "error", String(r2.Get("error", "")),
                "hresult", String(r2.Get("hresult", "")),
                "elapsedMs", Integer(r2.Get("elapsedMs", 0))
            ))
            if Integer(r2.Get("status", 0)) > 0 {
                r2["attempts"] := attempts
                return r2
            }
            rC := r2
        }
        rC["attempts"] := attempts
        if !rC.Get("ok", false) && Integer(rC.Get("status", 0)) = 0 {
            formatted := LlmApiPing_FormatAttemptFailure(url, rC, attempts, timeoutMs)
            rC["error"] := formatted["error"]
            rC["diagnostics"] := formatted["diag"]["text"]
            rC["phase"] := formatted["diag"]["phase"]
        }
        return rC
    }
    per := Max(3000, Min(6000, budget))
    r := LlmApiPing_HttpSyncOnce(method, url, headers, body, per, 0)
    attempts.Push(Map(
        "via", "winhttp",
        "proxyMode", 0,
        "status", Integer(r.Get("status", 0)),
        "error", String(r.Get("error", "")),
        "hresult", String(r.Get("hresult", "")),
        "elapsedMs", Integer(r.Get("elapsedMs", 0))
    ))
    if Integer(r.Get("status", 0)) = 0 {
        remain := Max(3000, budget - (A_TickCount - t0))
        r2 := LlmApiPing_HttpSyncOnce(method, url, headers, body, remain, 2)
        attempts.Push(Map(
            "via", "winhttp",
            "proxyMode", 2,
            "status", Integer(r2.Get("status", 0)),
            "error", String(r2.Get("error", "")),
            "hresult", String(r2.Get("hresult", "")),
            "elapsedMs", Integer(r2.Get("elapsedMs", 0))
        ))
        if Integer(r2.Get("status", 0)) != 0 {
            r2["attempts"] := attempts
            return r2
        }
        r := r2
    }
    r["attempts"] := attempts
    if !r.Get("ok", false) && Integer(r.Get("status", 0)) = 0 {
        formatted := LlmApiPing_FormatAttemptFailure(url, r, attempts, timeoutMs)
        r["error"] := formatted["error"]
        r["diagnostics"] := formatted["diag"]["text"]
        r["phase"] := formatted["diag"]["phase"]
    }
    return r
}

LlmApiPing_HttpSyncCurl(method, url, headers, body, timeoutMs := 12000) {
    start := A_TickCount
    method := StrUpper(String(method))
    if (method != "POST" && method != "GET")
        return Map("ok", false, "status", 0, "text", "", "error", "curl: 不支持 " . method, "elapsedMs", 0, "via", "curl")
    id := A_TickCount
    bodyPath := A_Temp . "\nmer_ping_" . id . ".json"
    outPath := A_Temp . "\nmer_ping_" . id . ".out"
    codePath := A_Temp . "\nmer_ping_" . id . ".code"
    for f in [bodyPath, outPath, codePath] {
        try if FileExist(f)
            FileDelete(f)
    }
    if (method = "POST") {
        try FileAppend(String(body), bodyPath, "UTF-8")
        catch {
            return Map("ok", false, "status", 0, "text", "", "error", "curl: 无法写入临时文件", "elapsedMs", A_TickCount - start, "via", "curl")
        }
    }
    sec := Max(3, Min(10, Integer(timeoutMs // 1000)))
    cmd := "curl.exe -sS --connect-timeout " . sec . " -m " . (sec + 2)
    cmd .= ' -o "' . outPath . '" -w "%{http_code}"'
    if (headers is Map) {
        for k, v in headers {
            hv := StrReplace(String(v), '"', '\"')
            cmd .= ' -H "' . String(k) . ': ' . hv . '"'
        }
    }
    cmd .= ' -X ' . method
    if (method = "POST")
        cmd .= ' -d @"' . bodyPath . '"'
    cmd .= ' "' . String(url) . '"'
    shellCmd := A_ComSpec . ' /S /C "' . cmd . ' > "' . codePath . '" 2>&1"'
    codeOut := ""
    try RunWait(shellCmd, , "Hide")
    catch as eRun {
        for f in [bodyPath, outPath, codePath] {
            try if FileExist(f)
                FileDelete(f)
        }
        return Map("ok", false, "status", 0, "text", "", "error", "curl 启动失败: " . eRun.Message, "elapsedMs", A_TickCount - start, "via", "curl")
    }
    status := 0
    text := ""
    try {
        if FileExist(codePath)
            codeOut := String(FileRead(codePath, "UTF-8"))
    } catch as _eCode {
        NmerCatch(A_ThisFunc, _eCode)
    }
    codeOut := Trim(String(codeOut))
    if RegExMatch(codeOut, "^\d{3}$")
        status := Integer(codeOut)
    try {
        if FileExist(outPath)
            text := String(FileRead(outPath, "UTF-8"))
    } catch as _e2 {
        NmerCatch(A_ThisFunc, _e2)
    }
    for f in [bodyPath, outPath, codePath] {
        try if FileExist(f)
            FileDelete(f)
    }
    ok := (status >= 200 && status < 300)
    err := ok ? "" : (status > 0 ? ("HTTP " . status) : "curl 连接失败")
    if (!ok && status = 0) {
        if (codeOut != "" && !RegExMatch(codeOut, "^\d{3}$"))
            err .= " — " . SubStr(codeOut, 1, 80)
        else if (text != "")
            err .= " — " . SubStr(Trim(text), 1, 120)
    }
    return Map("ok", ok, "status", status, "text", text, "error", err, "elapsedMs", A_TickCount - start, "via", "curl")
}

; proxyMode: 0=默认, 1=强制直连, 2=系统/WinHTTP 代理
LlmApiPing_HttpSyncOnce(method, url, headers, body, timeoutMs := 18000, proxyMode := 0) {
    start := A_TickCount
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        if LlmApiPing_IsLoopbackUrl(url) || proxyMode = 1 {
            try whr.SetProxy(1)
        } else if (proxyMode = 2) {
            try whr.SetProxy(0)
        }
        whr.Open(method, url, false)
        t := Max(2000, Integer(timeoutMs))
        resolveMs := Min(4000, t)
        connectMs := Min(5000, t)
        whr.SetTimeouts(resolveMs, connectMs, t, t)
        if (headers is Map) {
            for k, v in headers
                whr.SetRequestHeader(String(k), String(v))
        }
        whr.Send(String(body))
        status := Integer(whr.Status)
        text := ""
        try text := String(whr.ResponseText)
        ok := (status >= 200 && status < 300)
        return Map(
            "ok", ok,
            "status", status,
            "text", text,
            "error", ok ? "" : ("HTTP " . status),
            "elapsedMs", A_TickCount - start,
            "via", "winhttp",
            "proxyMode", proxyMode,
            "hresult", ""
        )
    } catch as e {
        errMsg := e.Message
        hresult := ""
        if RegExMatch(errMsg, "0x8007[0-9A-Fa-f]{4}|0x800727[0-9A-Fa-f]{2}", &hm)
            hresult := StrUpper(hm[0])
        cls := LlmApiPing_ClassifyNetworkError(errMsg, timeoutMs)
        det := LlmApiPing_WinHttpErrDetail(errMsg)
        if (cls != "") {
            if (det["label"] != "" && det["label"] != errMsg)
                errMsg := det["label"] . (hresult != "" ? " [" . hresult . "]" : "")
            else if (hresult != "")
                errMsg := cls . " [" . hresult . "]"
            else
                errMsg := cls
        } else if (hresult != "")
            errMsg := errMsg . " [" . hresult . "]"
        return Map(
            "ok", false,
            "status", 0,
            "text", "",
            "error", errMsg,
            "elapsedMs", A_TickCount - start,
            "via", "winhttp",
            "proxyMode", proxyMode,
            "hresult", hresult,
            "phase", det.Get("phase", "")
        )
    }
}

LlmApiPing_IsMinimaxCodingPlanKey(key) {
    return RegExMatch(Trim(String(key)), "i)^sk-cp-")
}

LlmApiPing_FormatMinimaxErr(status, raw, endpointUrl := "", baseUrl := "") {
    detail := ""
    s := Trim(String(raw))
    if (s != "") {
        if RegExMatch(s, '"message"\s*:\s*"([^"]+)"', &m)
            detail := m[1]
        else
            detail := SubStr(s, 1, 200)
    }
    ep := (endpointUrl != "") ? (" 请求：" . endpointUrl) : ""
    bu := (baseUrl != "") ? (" Base：" . baseUrl) : ""
    if (status = 401 || RegExMatch(detail . s, "i)authorized_error|login fail|1004|invalid api key|authentication")) {
        return "MiniMax 鉴权失败 (401)：请确认 ① 使用 Billing→Token Plan / Coding Plan 密钥（sk-cp-…，不是开放平台按量付费接口密钥）；"
            . " ② 已分配 Token Plan 席位； ③ 节点与密钥区域一致（国内 "
            . LlmApiPing_MINIMAX_BASE_CN . " / 国际 " . LlmApiPing_MINIMAX_BASE_INTL . "）。"
            . (detail ? " 详情：" . detail : "") . ep . bu
    }
    if RegExMatch(detail . s, "i)timeout|timed\s*out|超时")
        return "MiniMax 连接超时：请检查 WinHTTP 代理、公司网络出口与 Base URL 节点是否一致。" . ep . bu
    return "HTTP " . status . (detail ? ("：" . detail) : (s ? ("：" . SubStr(s, 1, 120)) : "")) . ep
}

LlmApiPing_MinimaxPingOnce(key, base, model, timeoutMs) {
    pingAnth := Jxon_Dump(Map("model", model, "max_tokens", 8, "messages", [Map("role", "user", "content", "ping")]))
    pingOpenAI := Jxon_Dump(Map("model", model, "messages", [Map("role", "user", "content", "ping")], "max_tokens", 8, "temperature", 0.1))
    hdr := Map(
        "Content-Type", "application/json",
        "Authorization", "Bearer " . key,
        "x-api-key", key,
        "anthropic-version", "2023-06-01"
    )
    urlA := LlmApiPing_MinimaxAnthropicUrl(base)
    t0 := A_TickCount
    perA := Max(4000, Integer(timeoutMs) // 2)
    r := LlmApiPing_HttpSync("POST", urlA, hdr, pingAnth, perA)
    if r.Get("ok", false)
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0, "endpoint", urlA, "baseUrl", base, "model", model, "via", "anthropic")
    if (Integer(r.Get("status", 0)) = 0 && Trim(String(r.Get("error", ""))) != "") {
        err0 := LlmApiPing_ClassifyNetworkError(r.Get("error", ""), timeoutMs)
        if (err0 != "") {
            return Map("ok", false, "error", err0 . "（MiniMax Anthropic 端点）", "elapsedMs", A_TickCount - t0, "endpoint", urlA, "baseUrl", base, "model", model, "status", 0)
        }
    }
    remain := Max(3000, Integer(timeoutMs) - (A_TickCount - t0))
    urlO := LlmApiPing_MinimaxOpenAIUrl(base)
    r2 := LlmApiPing_HttpSync("POST", urlO, Map("Content-Type", "application/json", "Authorization", "Bearer " . key, "x-api-key", key), pingOpenAI, remain)
    if r2.Get("ok", false)
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0, "endpoint", urlO, "baseUrl", base, "model", model, "via", "openai")
    if (Integer(r2.Get("status", 0)) = 0 && Trim(String(r2.Get("error", ""))) != "") {
        err1 := LlmApiPing_ClassifyNetworkError(r2.Get("error", ""), timeoutMs)
        if (err1 != "") {
            return Map("ok", false, "error", err1 . "（MiniMax OpenAI 端点）", "elapsedMs", A_TickCount - t0, "endpoint", urlO, "baseUrl", base, "model", model, "status", 0)
        }
    }
    st := r2.Has("status") ? Integer(r2["status"]) : (r.Has("status") ? Integer(r["status"]) : 0)
    err := LlmApiPing_FormatMinimaxErr(st, r2.Has("text") ? r2["text"] : r.Get("text", ""), urlA, base)
    return Map("ok", false, "error", err, "elapsedMs", A_TickCount - t0, "endpoint", urlA, "baseUrl", base, "model", model, "status", st)
}

LlmApiPing_TestMinimax(key, base, model, timeoutMs := 18000) {
    t0 := A_TickCount
    key := LlmApiPing_NormalizeApiKey(key)
    if (key = "")
        return Map("ok", false, "error", "请先填写 API Key", "elapsedMs", 0)
    model := Trim(String(model))
    if (model = "")
        model := "MiniMax-M2.7"
    base := Trim(String(base))
    if (base = "")
        base := LlmApiPing_MINIMAX_BASE_CN
    r := LlmApiPing_MinimaxPingOnce(key, base, model, timeoutMs)
    st := Integer(r.Get("status", 0))
    if !r.Get("ok", false) && (st = 401 || st = 403 || RegExMatch(Trim(String(r.Get("error", ""))), "i)authentication|invalid api key|鉴权")) {
        alt := InStr(StrLower(base), "minimax.io") ? LlmApiPing_MINIMAX_BASE_CN : LlmApiPing_MINIMAX_BASE_INTL
        if (alt != base) {
            spent := Integer(r.Get("elapsedMs", 0))
            rem := Max(4000, Integer(timeoutMs) - spent)
            r2 := LlmApiPing_MinimaxPingOnce(key, alt, model, rem)
            if r2.Get("ok", false) {
                r2["elapsedMs"] := spent + Integer(r2.Get("elapsedMs", 0))
                return r2
            }
        }
    }
    r["elapsedMs"] := A_TickCount - t0
    return r
}

LlmApiPing_MinimaxAnthropicUrl(base) {
    u := Trim(String(base))
    if (u = "")
        u := "https://api.minimaxi.com/anthropic"
    u := RegExReplace(u, "/+$", "")
    lu := StrLower(u)
    if InStr(lu, "/v1/messages") || InStr(lu, "/messages")
        return u
    if RegExMatch(lu, "/anthropic$")
        return u . "/v1/messages"
    if RegExMatch(lu, "/v1$")
        return u . "/messages"
    return u . "/v1/messages"
}

LlmApiPing_MinimaxOpenAIUrl(base) {
    u := Trim(String(base))
    if (u = "")
        return "https://api.minimax.io/v1/chat/completions"
    u := RegExReplace(u, "/+$", "")
    lu := StrLower(u)
    if InStr(lu, "/chat/completions")
        return u
    if RegExMatch(lu, "/anthropic$")
        return RegExReplace(u, "/anthropic$", "") . "/v1/chat/completions"
    if RegExMatch(lu, "/v1$") || RegExMatch(lu, "/v1beta$")
        return u . "/chat/completions"
    return u . "/v1/chat/completions"
}

LlmApiPing_FormatHttpError(r, prov := "") {
    err := r.Has("error") ? String(r["error"]) : "测试失败"
    if r.Has("text") && Trim(String(r["text"])) != "" {
        body := Trim(String(r["text"]))
        if RegExMatch(body, '"message"\s*:\s*"([^"]+)"', &m)
            err := m[1]
        else
            err .= " — " . SubStr(body, 1, 200)
    }
    if (prov = "kimi") {
        if RegExMatch(err, "i)404|not\s*found")
            err := "接口 404：Base URL 须为 https://api.moonshot.cn/v1（国内）或 https://api.moonshot.ai/v1（国际），完整路径为 …/v1/chat/completions；勿漏 /v1"
        else if RegExMatch(err, "i)authentication|api[_ ]?key|unauthorized|401")
            err := "Kimi 鉴权失败：国内密钥→api.moonshot.cn/v1（platform.moonshot.cn）；国际密钥→api.moonshot.ai/v1（platform.kimi.ai），二者不可混用"
        else if RegExMatch(err, "i)temperature")
            err := "Kimi K2.6 模型要求 temperature=1（或不传 temperature），测试请求已去掉 0.1。请重载主程序后再测。"
        else if RegExMatch(err, "i)model|invalid_request|400|403|permission|not\s*found|不存在|未开通|无权限")
            err .= "。kimi-k2.6 需账号在 platform.moonshot.cn（国内）或 platform.kimi.ai（国际）已开通且有余额；若仅 moonshot-v1-8k 可用，请在卡片里改选 v1 模型。可用 GET …/v1/models 查看本 Key 实际可用模型列表。"
    } else if (prov = "openai") {
        if RegExMatch(err, "i)429|too many requests|rate.?limit|请求过于频繁")
            err := "HTTP 429（限流）：通常不是密钥错误，而是短时间内请求过多（RPM/TPM）。请等待 30～60 秒后再测；避免连续切换模型后立刻连点「测试 API」。每次测试最多向官方发 2 次请求，易触发免费档或低配额账号的限流。可到 platform.openai.com 查看 Usage / Billing。"
        else if RegExMatch(err, "i)401|invalid.*api|incorrect.*api|authentication")
            err := "OpenAI 鉴权失败：请确认 sk- 密钥有效、账户有余额；官方地址 https://api.openai.com/v1。Azure OpenAI 请用手动 Base URL 并勾选对应选项。"
        else if RegExMatch(err, "i)model_not_found|model.*not exist|does not exist|invalid_model")
            err .= "。模型名可能不可用或账号未开通该模型，请换 gpt-4o-mini / gpt-4.1-mini 等后重试。"
    } else if (prov = "deepseek") {
        if RegExMatch(err, "i)402|insufficient balance|余额")
            err := "DeepSeek 账户余额不足 (402)：API Key 有效但需充值。请到 platform.deepseek.com 充值后重试。"
        else if RegExMatch(err, "i)401|invalid.*api|authentication")
            err := "DeepSeek 鉴权失败 (401)：API Key 无效或已撤销，请到 platform.deepseek.com/api_keys 核对；若 Key 正确请检查账户余额。"
        else if RegExMatch(err, "i)404|not\s*found")
            err := "DeepSeek 接口 404：Base URL 应为 https://api.deepseek.com/v1，完整路径 …/v1/chat/completions。"
    }
    return err
}

LlmApiPing_NormalizeMoonshotBase(base) {
    u := Trim(String(base))
    if (u = "")
        return u
    u := RegExReplace(u, "/+$", "")
    if RegExMatch(u, "i)^https?://api\.moonshot\.(cn|ai)$")
        return u . "/v1"
    return u
}

LlmApiPing_OpenAIChatUrl(base) {
    u := Trim(String(base))
    if (u = "")
        u := "https://api.openai.com/v1"
    if RegExMatch(u, "i)moonshot\.(cn|ai)")
        u := LlmApiPing_NormalizeMoonshotBase(u)
    u := RegExReplace(u, "/+$", "")
    if InStr(StrLower(u), "/chat/completions")
        return u
    return u . "/chat/completions"
}

; 命令面板 / 宿主直连：OpenAI 兼容 chat/completions 请求体（Kimi 勿传 temperature=0.7）
LlmApiPing_BuildChatBody(prov, model, userText, maxTokens := 4096) {
    prov := LlmApiPing_NormalizeProvider(prov)
    model := Trim(String(model))
    if (model = "") {
        try {
            pre := LlmApiPing_PresetFor(prov)
            model := Trim(String(pre.Get("model", "")))
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    tok := Max(64, Integer(maxTokens))
    m := Map(
        "model", model,
        "messages", [Map("role", "user", "content", String(userText))]
    )
    if (prov = "kimi") {
        if RegExMatch(model, "i)^kimi-k2")
            m["max_completion_tokens"] := tok, m["temperature"] := 1
        else
            m["max_tokens"] := tok
    } else {
        m["max_tokens"] := tok
        if (prov != "deepseek")
            m["temperature"] := 0.7
    }
    return Jxon_Dump(m)
}

LlmApiPing_KimiChatBodies(model, userText, maxTokens := 4096) {
    mod := Trim(String(model))
    if (mod = "")
        mod := "kimi-k2.6"
    tok := Max(64, Integer(maxTokens))
    q := String(userText)
    pingK26Lite := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", q)],
        "max_completion_tokens", tok
    ))
    pingK26Enabled := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", q)],
        "max_completion_tokens", tok,
        "thinking", Map("type", "enabled")
    ))
    pingK26 := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", q)],
        "max_completion_tokens", tok,
        "thinking", Map("type", "disabled")
    ))
    pingV1 := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", q)],
        "max_tokens", tok
    ))
    if RegExMatch(mod, "i)^kimi-k2\.6")
        return [pingK26Lite, pingK26Enabled, pingK26, pingV1]
    if RegExMatch(mod, "i)^moonshot-v1")
        return [pingV1]
    return [pingK26Lite, pingV1, pingK26Enabled, pingK26]
}

LlmApiPing_KimiPingBodies(mod) {
    mod := Trim(String(mod))
    tok := 64
    pingK26Lite := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", "ping")],
        "max_completion_tokens", tok
    ))
    pingK26Enabled := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", "ping")],
        "max_completion_tokens", tok,
        "thinking", Map("type", "enabled")
    ))
    pingK26 := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", "ping")],
        "max_completion_tokens", tok,
        "thinking", Map("type", "disabled")
    ))
    pingV1 := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", "ping")],
        "max_tokens", tok
    ))
    if RegExMatch(mod, "i)^kimi-k2\.6")
        return [pingK26Lite, pingK26Enabled, pingK26, pingV1]
    if RegExMatch(mod, "i)thinking")
        return [pingV1, pingK26Lite]
    if RegExMatch(mod, "i)^moonshot-v1")
        return [pingV1]
    return [pingK26Lite, pingV1, pingK26Enabled, pingK26]
}

LlmApiPing_ClaudeMessagesUrl(base) {
    u := Trim(String(base))
    if (u = "")
        u := "https://api.anthropic.com"
    u := RegExReplace(u, "/+$", "")
    if InStr(StrLower(u), "/v1/messages")
        return u
    return u . "/v1/messages"
}

LlmApiPing_GeminiGenerateUrl(base, model, apiKey) {
    u := Trim(String(base))
    if (u = "")
        u := "https://generativelanguage.googleapis.com/v1beta"
    u := RegExReplace(u, "/+$", "")
    m := Trim(String(model))
    if (m = "")
        m := "gemini-2.5-flash"
    encKey := LlmApiPing_EncodeUri(apiKey)
    if InStr(StrLower(u), ":generatecontent")
        return u . "?key=" . encKey
    return u . "/models/" . m . ":generateContent?key=" . encKey
}

LlmApiPing_ResolveFromPayload(payload) {
    if !(payload is Map)
        return Map()
    llm := payload
    if (payload.Has("llm") && payload["llm"] is Map)
        llm := payload["llm"].Clone()
    else if !(llm is Map)
        llm := Map()
    prov := LlmApiPing_NormalizeProvider(llm.Get("provider", "openai"))
    opt := (payload.Has("options") && payload["options"] is Map) ? payload["options"] : Map()
    key := LlmApiPing_NormalizeApiKey(llm.Get("apiKey", ""))
    base := Trim(String(llm.Get("baseUrl", "")))
    model := Trim(String(llm.Get("model", "")))
    if (key = "" && opt.Has("llmApiKeys") && opt["llmApiKeys"] is Map) {
        keys := opt["llmApiKeys"]
        if keys.Has(prov)
            key := LlmApiPing_NormalizeApiKey(keys[prov])
    }
    if (base = "" && opt.Has("llmBaseUrls") && opt["llmBaseUrls"] is Map) {
        bases := opt["llmBaseUrls"]
        if bases.Has(prov)
            base := Trim(String(bases[prov]))
    }
    if (model = "" && opt.Has("llmModels") && opt["llmModels"] is Map) {
        models := opt["llmModels"]
        if models.Has(prov)
            model := Trim(String(models[prov]))
    }
    if (key = "" && LlmApiPing_HasFunc("Nmer_SecretStore_Get")) {
        try key := LlmApiPing_NormalizeApiKey(Nmer_SecretStore_Get("options.llmApiKeys." . prov))
        catch as _e {
            NmerCatch(A_ThisFunc, _e)
        }
    }
    llm["provider"] := prov
    llm["apiKey"] := key
    if (base != "")
        llm["baseUrl"] := base
    if (model != "")
        llm["model"] := model
    return llm
}

LlmApiPing_ResolveTestLlmFromPayload(payload) {
    return LlmApiPing_ResolveFromPayload(payload)
}

LlmApiPing_TestKimi(key, base, model, timeoutMs) {
    t0 := A_TickCount
    headers := Map("Content-Type", "application/json", "Authorization", "Bearer " . key)
    bases := []
    b0 := LlmApiPing_NormalizeMoonshotBase(Trim(String(base)))
    if (b0 != "")
        bases.Push(b0)
    if !bases.Length {
        bases.Push("https://api.moonshot.cn/v1")
        bases.Push("https://api.moonshot.ai/v1")
    } else if RegExMatch(b0, "i)moonshot\.cn") {
        if !ArrayHasValue(bases, "https://api.moonshot.cn/v1")
            bases.Push("https://api.moonshot.cn/v1")
    } else if RegExMatch(b0, "i)moonshot\.ai") {
        if !ArrayHasValue(bases, "https://api.moonshot.ai/v1")
            bases.Push("https://api.moonshot.ai/v1")
    }
    m0 := Trim(String(model))
    if (m0 = "")
        m0 := "kimi-k2.6"
    modelExplicit := Trim(String(model)) != ""
    models := [m0]
    ; 仅在未显式指定模型时才尝试备用模型，避免“自动切到 moonshot-v1-8k”
    if !modelExplicit {
        if !ArrayHasValue(models, "kimi-k2.6")
            models.Push("kimi-k2.6")
        if !ArrayHasValue(models, "moonshot-v1-8k")
            models.Push("moonshot-v1-8k")
    }
    lastErr := "测试失败"
    for _, bu in bases {
        bu := LlmApiPing_NormalizeMoonshotBase(bu)
        for _, mod in models {
            for _, body in LlmApiPing_KimiPingBodies(mod) {
                r := LlmApiPing_HttpSync("POST", LlmApiPing_OpenAIChatUrl(bu), headers, body, timeoutMs)
                if r["ok"]
                    return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0, "baseUrl", bu, "model", mod)
                lastErr := LlmApiPing_FormatHttpError(r, "kimi")
            }
        }
    }
    return Map("ok", false, "error", lastErr, "elapsedMs", A_TickCount - t0)
}

ArrayHasValue(arr, val) {
    for item in arr
        if (item = val)
            return true
    return false
}

LlmApiPing_OllamaRootUrl(base) {
    root := Trim(String(base))
    if (root = "")
        root := "http://127.0.0.1:11434/v1"
    root := RegExReplace(root, "/+$", "")
    if RegExMatch(root, "i)/v1$")
        root := SubStr(root, 1, -3)
    return root
}

; Ollama 本地服务：先 GET /api/tags，再可选 POST /v1/chat/completions
LlmApiPing_TestOllama(base, model, timeoutMs := 18000) {
    t0 := A_TickCount
    root := LlmApiPing_OllamaRootUrl(base)
    r := LlmApiPing_HttpSync("GET", root . "/api/tags", Map(), "", timeoutMs)
    if !r["ok"] {
        err := Trim(String(r["error"]))
        if (err = "")
            err := "无法连接"
        return Map(
            "ok", false,
            "error", "未检测到 Ollama 服务（" . err . "）。请从开始菜单或托盘启动 Ollama；或在终端执行 ollama serve",
            "elapsedMs", A_TickCount - t0
        )
    }
    mod := Trim(String(model))
    if (mod = "" || !RegExMatch(mod, "i):cloud$"))
        mod := "nemotron-3-super:cloud"
    pingBody := Jxon_Dump(Map(
        "model", mod,
        "messages", [Map("role", "user", "content", "ping")],
        "stream", false,
        "max_tokens", 8
    ))
    r2 := LlmApiPing_HttpSync("POST", root . "/v1/chat/completions", Map("Content-Type", "application/json"), pingBody, timeoutMs)
    if r2["ok"]
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0)
    err2 := LlmApiPing_FormatHttpError(r2, "ollama")
    if RegExMatch(err2, "i)model|not found|404")
        err2 .= "。请在 Ollama 客户端添加云模型「" . mod . "」（:cloud 后缀，无需本机 pull 大文件）"
    return Map("ok", false, "error", err2, "elapsedMs", A_TickCount - t0)
}

LlmApiPing_InetAddrV4(host) {
    host := Trim(String(host))
    if (host = "localhost")
        host := "127.0.0.1"
    if !RegExMatch(host, "^\d{1,3}(\.\d{1,3}){3}$")
        return 0
    addr := DllCall("ws2_32\inet_addr", "AStr", host, "UInt")
    return (addr = 0xFFFFFFFF) ? 0 : addr
}

LlmApiPing_TcpPortOpen(host, port, timeoutMs := 2500) {
    static wsaReady := false
    if !wsaReady {
        wsaData := Buffer(400, 0)
        if DllCall("ws2_32\WSAStartup", "UShort", 0x0202, "Ptr", wsaData, "Int")
            return false
        wsaReady := true
    }
    host := Trim(String(host))
    port := Integer(port)
    if (host = "" || port < 1 || port > 65535)
        return false
    ip := LlmApiPing_InetAddrV4(host)
    if !ip
        return false
    sock := DllCall("ws2_32\socket", "Int", 2, "Int", 1, "Int", 6, "UPtr")
    if (sock = -1 || sock = 0xFFFFFFFFFFFFFFFF)
        return false
    try {
        sa := Buffer(16, 0)
        NumPut("UShort", 2, sa, 0)
        NumPut("UShort", DllCall("ws2_32\htons", "UShort", port, "UShort"), sa, 2)
        NumPut("UInt", ip, sa, 4)
        nb := 1
        if (DllCall("ws2_32\ioctlsocket", "UPtr", sock, "UInt", 0x8004667E, "UInt*", &nb, "Int") = -1)
            return false
        if (DllCall("ws2_32\connect", "UPtr", sock, "Ptr", sa, "Int", 16, "Int") = 0)
            return true
        if (DllCall("ws2_32\WSAGetLastError", "Int") != 10035)
            return false
        t := Max(500, Integer(timeoutMs))
        writeSet := Buffer(132, 0)
        NumPut("UInt", 1, writeSet, 0)
        NumPut("UPtr", sock, writeSet, 4)
        tv := Buffer(8, 0)
        NumPut("UInt", t // 1000, tv, 0)
        NumPut("UInt", Mod(t, 1000) * 1000, tv, 4)
        if (DllCall("ws2_32\select", "Int", 0, "Ptr", 0, "Ptr", writeSet, "Ptr", 0, "Ptr", tv, "Int") <= 0)
            return false
        optErr := 0
        optLen := 4
        if (DllCall("ws2_32\getsockopt", "UPtr", sock, "Int", 0xFFFF, "Int", 0x1007, "Int*", &optErr, "Int*", &optLen, "Int") = -1)
            return false
        return optErr = 0
    } catch {
        return false
    } finally {
        try DllCall("ws2_32\closesocket", "UPtr", sock)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
}

LlmApiPing_ParseHermesEndpoint(base) {
    host := "127.0.0.1"
    port := 8642
    base := Trim(String(base))
    if (base = "")
        return Map("host", host, "port", port)
    raw := base
    if !RegExMatch(raw, "i)^[a-z]+://")
        raw := "http://" . raw
    try {
        if RegExMatch(raw, "i)^[a-z]+://([^/:]+)(?::(\d+))?", &m) {
            if (m[1] != "")
                host := m[1]
            if (m[2] != "")
                port := Integer(m[2])
        } else if RegExMatch(raw, ":(\d+)", &mp)
            port := Integer(mp[1])
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if (host = "localhost")
        host := "127.0.0.1"
    if (port < 1 || port > 65535)
        port := 8642
    return Map("host", host, "port", port)
}

LlmApiPing_ParseOpenClawEndpoint(base) {
    host := "127.0.0.1"
    port := 18789
    base := Trim(String(base))
    if (base = "")
        return Map("host", host, "port", port)
    raw := base
    if !RegExMatch(raw, "i)^[a-z]+://")
        raw := "http://" . raw
    try {
        if RegExMatch(raw, "i)^[a-z]+://([^/:]+)(?::(\d+))?", &m) {
            if (m[1] != "")
                host := m[1]
            if (m[2] != "")
                port := Integer(m[2])
        }
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if (port < 1 || port > 65535)
        port := 18789
    return Map("host", host, "port", port)
}

LlmApiPing_OpenClawGatewayStatusOk(timeoutMs := 9000) {
    if !LlmApiPing_HasFunc("UserStudio_FindOpenClawCliExe")
        return false
    exe := UserStudio_FindOpenClawCliExe()
    if (exe = "")
        return false
    out := A_Temp . "\nmer_openclaw_gw_status.txt"
    try FileDelete(out)
    inner := '"' . exe . '" gateway status > "' . out . '" 2>&1'
    pid := 0
    try {
        Run(A_ComSpec . ' /c "' . inner . '"', , "Hide", &pid)
    } catch {
        return false
    }
    if !pid
        return false
    deadline := A_TickCount + Max(1500, Integer(timeoutMs))
    while ProcessExist(pid) {
        if (A_TickCount > deadline) {
            try ProcessClose(pid)
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
            try FileDelete(out)
            return false
        }
        Sleep(50)
    }
    if !FileExist(out)
        return false
    raw := ""
    try raw := FileRead(out, "UTF-8")
    catch {
        return false
    }
    try FileDelete(out)
    if InStr(raw, "Connectivity probe: ok")
        return true
    if InStr(raw, "Runtime: running") && InStr(raw, "Listening: 127.0.0.1")
        return true
    return false
}

LlmApiPing_TestHermes(base, key, timeoutMs := 8000) {
    key := LlmApiPing_NormalizeApiKey(key)
    if (key = "")
        return Map("ok", false, "error", "缺少 API Server Key（API_SERVER_KEY）", "elapsedMs", 0)
    ep := LlmApiPing_ParseHermesEndpoint(base)
    host := ep.Get("host", "127.0.0.1")
    if (host = "localhost")
        host := "127.0.0.1"
    port := Integer(ep.Get("port", 8642))
    baseNorm := "http://" . host . ":" . port . "/v1"
    t0 := A_TickCount
    pingMs := Min(Max(3000, Integer(timeoutMs)), 8000)
    for _, path in ["/health", "/v1/models"] {
        try {
            r0 := LlmApiPing_HttpSync("GET", "http://" . host . ":" . port . path, Map("Authorization", "Bearer " . key), "", pingMs)
            if (r0 is Map && r0.Get("ok", false))
                return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0, "via", "http" . path)
            if (r0 is Map && Integer(r0.Get("status", 0)) = 401)
                return Map(
                    "ok", false,
                    "error", "API 鉴权失败：请用 %LOCALAPPDATA%\hermes\.env 中的 API_SERVER_KEY，或点测试连接重新读取。",
                    "elapsedMs", A_TickCount - t0
                )
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    if LlmApiPing_HasFunc("UserStudio_ProbeHermesApiServer") {
        try {
            r := UserStudio_ProbeHermesApiServer(baseNorm, key, timeoutMs)
            if (r is Map)
                return r
        } catch as eProbe {
            try OutputDebug("[LlmApiPing] UserStudio_ProbeHermesApiServer: " . eProbe.Message)
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        }
    }
    apiSt := ""
    if LlmApiPing_HasFunc("UserStudio_ReadHermesGatewayState") {
        try {
            gw := UserStudio_ReadHermesGatewayState()
            if (gw is Map)
                apiSt := Trim(String(gw.Get("apiServerState", "")))
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    tcpMs := Min(Max(1200, Integer(timeoutMs)), 4000)
    tcpOk := LlmApiPing_TcpPortOpen(host, port, tcpMs)
    if (apiSt = "connected" && tcpOk)
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0, "via", "gateway_state")
    if tcpOk
        return Map(
            "ok", false,
            "error", "8642 已监听，但 API 鉴权失败。请点「测试连接」从 .env 重新读取 Key，或执行 hermes gateway restart。",
            "elapsedMs", A_TickCount - t0
        )
    if (apiSt != "" && apiSt != "connected")
        return Map(
            "ok", false,
            "error", "Hermes api_server 状态为「" . apiSt . "」。请完全退出 Hermes 桌面版后重开，或点「重启 Gateway」。",
            "elapsedMs", A_TickCount - t0
        )
    return Map(
        "ok", false,
        "error", "无法连接本机 Hermes API Server（" . host . ":" . port . "）。请启动 Hermes 桌面版并执行 hermes gateway restart。",
        "elapsedMs", A_TickCount - t0
    )
}

LlmApiPing_OpenClawHttpReachable(host, port, timeoutMs := 3000) {
    host := Trim(String(host))
    if (host = "localhost")
        host := "127.0.0.1"
    port := Integer(port)
    if (host = "" || port < 1 || port > 65535)
        return false
    pingMs := Max(600, Integer(timeoutMs))
    try {
        r := LlmApiPing_HttpSync("GET", "http://" . host . ":" . port . "/", Map(), "", pingMs)
        if (r is Map) {
            st := Integer(r.Get("status", 0))
            if (st >= 200 && st < 500)
                return true
            if (r.Get("ok", false))
                return true
        }
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return false
}

LlmApiPing_TestOpenClaw(base, key, timeoutMs := 8000) {
    key := LlmApiPing_NormalizeApiKey(key)
    if (key = "")
        return Map("ok", false, "error", "缺少 Gateway Token", "elapsedMs", 0)
    ep := LlmApiPing_ParseOpenClawEndpoint(base)
    host := ep.Get("host", "127.0.0.1")
    if (host = "localhost")
        host := "127.0.0.1"
    port := Integer(ep.Get("port", 18789))
    t0 := A_TickCount
    budget := Max(3000, Integer(timeoutMs))
    ; 本机 Gateway 18789 偶发需 5–8s 才 accept；TCP 优先，避免 HTTP+短 TCP 失败后落入 10s+ CLI
    tcpMs := Min(8000, Max(1500, budget // 2))
    if LlmApiPing_TcpPortOpen(host, port, tcpMs)
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0, "via", "tcp")
    remain1 := budget - (A_TickCount - t0)
    httpMs := Min(2500, Max(600, remain1 // 3))
    if (httpMs >= 600 && LlmApiPing_OpenClawHttpReachable(host, port, httpMs))
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0, "via", "http")
    remain2 := budget - (A_TickCount - t0)
    cliMs := Min(Max(8000, budget), remain2)
    if (cliMs >= 3000 && LlmApiPing_OpenClawGatewayStatusOk(cliMs))
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0, "via", "cli_status")
    remain3 := budget - (A_TickCount - t0)
    if (remain3 >= 800 && LlmApiPing_TcpPortOpen(host, port, Min(tcpMs, remain3)))
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0, "via", "tcp_retry")
    remain4 := budget - (A_TickCount - t0)
    if (remain4 >= 600 && LlmApiPing_OpenClawHttpReachable(host, port, Min(httpMs + 1500, remain4)))
        return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0, "via", "http_retry")
    return Map(
        "ok", false,
        "error", "无法连接本机 OpenClaw Gateway（" . host . ":" . port . "）。Gateway 若在运行，请重载牛马后再点「测试连接」。",
        "elapsedMs", A_TickCount - t0
    )
}

LlmApiPing_NormalizeRoutePingResult(routeR, llm, cfg) {
    prov := ""
    if (cfg is Map) && cfg.Has("vendor")
        prov := Trim(String(cfg["vendor"]))
    if (prov = "" && llm is Map)
        prov := LlmApiPing_NormalizeProvider(llm.Get("provider", "openai"))
    err := Trim(String(routeR.Get("message", routeR.Get("error", ""))))
    st := routeR.Has("status") ? Integer(routeR["status"]) : 0
    if !routeR.Get("ok", false) && err = "" && st > 0
        err := "HTTP " . st
    return Map(
        "ok", !!routeR.Get("ok", false),
        "error", err,
        "elapsedMs", Integer(routeR.Get("elapsedMs", 0)),
        "endpoint", Trim(String(routeR.Get("endpoint", ""))),
        "baseUrl", Trim(String(routeR.Get("baseUrl", (cfg is Map) ? cfg.Get("baseUrl", "") : ""))),
        "model", Trim(String(routeR.Get("model", (cfg is Map) ? cfg.Get("model", "") : ""))),
        "provider", prov,
        "diagnostics", Trim(String(routeR.Get("diagnostics", ""))),
        "phase", Trim(String(routeR.Get("phase", ""))),
        "status", st,
        "viaRoute", true
    )
}

LlmApiPing_Test(llm, timeoutMs := 18000) {
    if !(llm is Map)
        return Map("ok", false, "error", "配置无效", "elapsedMs", 0)
    prov := LlmApiPing_NormalizeProvider(llm.Get("provider", "openai"))
    if (prov = "openclaw") {
        base := Trim(String(llm.Get("baseUrl", "")))
        key := LlmApiPing_NormalizeApiKey(llm.Get("apiKey", ""))
        return LlmApiPing_TestOpenClaw(base, key, Min(timeoutMs, 12000))
    }
    if (prov = "hermes") {
        base := Trim(String(llm.Get("baseUrl", "")))
        key := LlmApiPing_NormalizeApiKey(llm.Get("apiKey", ""))
        return LlmApiPing_TestHermes(base, key, Min(timeoutMs, 12000))
    }
    if FuncExists("Nmer_Llm_ShouldUseManager") && Nmer_Llm_ShouldUseManager(llm) {
        if FuncExists("Nmer_Llm_PingFromLlmMap")
            return Nmer_Llm_PingFromLlmMap(llm, timeoutMs)
    }
    return LlmApiPing_TestHttpDirect(llm, timeoutMs)
}

LlmApiPing_TestHttpDirect(llm, timeoutMs := 18000) {
    if !(llm is Map)
        return Map("ok", false, "error", "配置无效", "elapsedMs", 0)
    prov := LlmApiPing_NormalizeProvider(llm.Get("provider", "openai"))
    key := LlmApiPing_NormalizeApiKey(llm.Get("apiKey", ""))
    base := Trim(String(llm.Get("baseUrl", "")))
    model := Trim(String(llm.Get("model", "")))
    pre := LlmApiPing_PresetFor(prov)
    if (base = "")
        base := pre.Get("baseUrl", "")
    if !LlmApiPing_BaseUrlMatchesProvider(prov, base)
        base := pre.Get("baseUrl", "")
    if (model = "")
        model := pre.Get("model", "")
    if (prov != "ollama" && key = "")
        return Map("ok", false, "error", "请先填写 API Key", "elapsedMs", 0)
    if (prov = "ollama")
        return LlmApiPing_TestOllama(base, model, timeoutMs)
    pingAnth := Jxon_Dump(Map("model", model, "max_tokens", 8, "messages", [Map("role", "user", "content", "ping")]))
    pingOpenAI := Jxon_Dump(Map("model", model, "messages", [Map("role", "user", "content", "ping")], "max_tokens", 8, "temperature", 0.1))
    pingOpenAINew := Jxon_Dump(Map("model", model, "messages", [Map("role", "user", "content", "ping")], "max_completion_tokens", 16, "temperature", 0.1))
    t0 := A_TickCount
    if (prov = "minimax")
        return LlmApiPing_TestMinimax(key, base, model, timeoutMs)
    if (prov = "claude") {
        r := LlmApiPing_HttpSync("POST", LlmApiPing_ClaudeMessagesUrl(base), Map(
            "Content-Type", "application/json",
            "x-api-key", key,
            "anthropic-version", "2023-06-01"
        ), pingAnth, timeoutMs)
        return Map("ok", !!r["ok"], "error", r["ok"] ? "" : r["error"], "elapsedMs", A_TickCount - t0)
    }
    if (prov = "gemini") {
        r := LlmApiPing_HttpSync("POST", LlmApiPing_GeminiGenerateUrl(base, model, key), Map("Content-Type", "application/json"),
            Jxon_Dump(Map("contents", [Map("role", "user", "parts", [Map("text", "ping")])], "generationConfig", Map("maxOutputTokens", 8))), timeoutMs)
        err := r["ok"] ? "" : LlmApiPing_FormatHttpError(r, prov)
        return Map("ok", !!r["ok"], "error", err, "elapsedMs", A_TickCount - t0)
    }
    if (prov = "kimi")
        return LlmApiPing_TestKimi(key, base, model, timeoutMs)
    headers := Map("Content-Type", "application/json")
    if (key != "")
        headers["Authorization"] := "Bearer " . key
    bodies := [pingOpenAI]
    if (prov = "openai")
        bodies.InsertAt(1, pingOpenAINew)
    lastErr := ""
    pingUrl := LlmApiPing_OpenAIChatUrl(base)
    perMs := Max(4000, Min(12000, Integer(timeoutMs)))
    lastSt := 0
    lastR := Map()
    for _, body in bodies {
        r := LlmApiPing_HttpSync("POST", pingUrl, headers, body, perMs)
        lastR := r
        if r["ok"]
            return Map("ok", true, "error", "", "elapsedMs", A_TickCount - t0, "endpoint", pingUrl, "baseUrl", base, "model", model)
        lastErr := LlmApiPing_FormatHttpError(r, prov = "openai" ? "openai" : prov)
        lastSt := r.Has("status") ? Integer(r["status"]) : 0
        if (lastSt = 0) {
            if r.Has("error") && Trim(String(r["error"])) != ""
                lastErr := Trim(String(r["error"]))
            break
        }
        if (prov = "openai" && (lastSt = 429 || lastSt = 401 || lastSt = 402 || lastSt = 403))
            break
    }
    out := Map(
        "ok", false,
        "error", lastErr,
        "elapsedMs", A_TickCount - t0,
        "endpoint", pingUrl,
        "baseUrl", base,
        "model", model,
        "status", lastSt
    )
    if (lastR is Map) {
        if lastR.Has("diagnostics")
            out["diagnostics"] := lastR["diagnostics"]
        if lastR.Has("phase")
            out["phase"] := lastR["phase"]
    }
    return out
}
