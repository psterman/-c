; NmerWailsBridge.ahk — B2: AHK 守护 nmer-wails.exe TPA sidecar (:18791)

global g_Nmer_WailsBridgeLastLaunchTick := 0

Nmer_WailsBridgeDefaultAddr(*) {
    addr := Trim(String(EnvGet("NMER_A2UI_BRIDGE_ADDR")))
    if (addr = "")
        addr := "127.0.0.1:18791"
    return addr
}

Nmer_WailsBridgeFlagsPath(*) {
    return Nmer_LocalDir() . "\nmer-flags.json"
}

Nmer_WailsBridgeNormalizeWhitelist(list) {
    out := []
    if !(list is Array)
        return out
    for _, item in list {
        s := Trim(String(item))
        if (s = "")
            continue
        if (SubStr(s, 1, 1) != "/")
            s := "/" . s
        s := StrLower(s)
        dup := false
        for _, kept in out {
            if (kept = s) {
                dup := true
                break
            }
        }
        if !dup
            out.Push(s)
    }
    return out
}

Nmer_WailsBridgeNormalizeBool(value, default := false) {
    if (value = "")
        return !!default
    return !!(value = true || value = 1 || String(value) = "true" || String(value) = "1")
}

Nmer_WailsBridgeReadFlags(*) {
    defaults := Map(
        "wailsBridge", Map("enabled", true),
        "officialA2ui", Map("enabled", false, "commandWhitelist", []),
        "surfaceManager", Map(
            "enabled", false,
            "shadowMode", true,
            "interceptWarmup", false,
            "interceptOpenClose", false,
            "enforceSlots", false,
            "enforceBudget", false,
            "routeIntents", false
        ),
        "rollback", Map(
            "forceNmerOnly", false,
            "legacySurfaceLifecycle", true,
            "forceTraySafeMode", false
        )
    )
    path := Nmer_WailsBridgeFlagsPath()
    if !FileExist(path)
        return defaults
    try {
        raw := FileRead(path, "UTF-8")
        if (Trim(raw) = "")
            return defaults
        data := Jxon_Load(raw)
        if !(data is Map)
            return defaults
        wb := data.Get("wailsBridge", Map())
        oa := data.Get("officialA2ui", Map())
        sm := data.Get("surfaceManager", Map())
        rb := data.Get("rollback", Map())
        out := Map()
        if (wb is Map) {
            out["wailsBridge"] := Map(
                "enabled", Nmer_WailsBridgeNormalizeBool(wb.Get("enabled", true), true)
            )
        } else {
            out["wailsBridge"] := defaults["wailsBridge"]
        }
        if (oa is Map) {
            wlRaw := oa.Get("commandWhitelist", [])
            out["officialA2ui"] := Map(
                "enabled", Nmer_WailsBridgeNormalizeBool(oa.Get("enabled", false), false),
                "commandWhitelist", Nmer_WailsBridgeNormalizeWhitelist(wlRaw)
            )
        } else {
            out["officialA2ui"] := defaults["officialA2ui"]
        }
        if (sm is Map) {
            out["surfaceManager"] := Map(
                "enabled", Nmer_WailsBridgeNormalizeBool(sm.Get("enabled", false), false),
                "shadowMode", Nmer_WailsBridgeNormalizeBool(sm.Get("shadowMode", true), true),
                "interceptWarmup", Nmer_WailsBridgeNormalizeBool(sm.Get("interceptWarmup", false), false),
                "interceptOpenClose", Nmer_WailsBridgeNormalizeBool(sm.Get("interceptOpenClose", false), false),
                "enforceSlots", Nmer_WailsBridgeNormalizeBool(sm.Get("enforceSlots", false), false),
                "enforceBudget", Nmer_WailsBridgeNormalizeBool(sm.Get("enforceBudget", false), false),
                "routeIntents", Nmer_WailsBridgeNormalizeBool(sm.Get("routeIntents", false), false)
            )
        } else {
            out["surfaceManager"] := defaults["surfaceManager"]
        }
        if (rb is Map) {
            out["rollback"] := Map(
                "forceNmerOnly", Nmer_WailsBridgeNormalizeBool(rb.Get("forceNmerOnly", false), false),
                "legacySurfaceLifecycle", Nmer_WailsBridgeNormalizeBool(rb.Get("legacySurfaceLifecycle", true), true),
                "forceTraySafeMode", Nmer_WailsBridgeNormalizeBool(rb.Get("forceTraySafeMode", false), false)
            )
        } else {
            out["rollback"] := defaults["rollback"]
        }
        return out
    } catch {
        return defaults
    }
}

Nmer_WailsBridgeEnabled(*) {
    flags := Nmer_WailsBridgeReadFlags()
    wb := flags.Get("wailsBridge", Map())
    if !(wb is Map)
        return true
    return !!wb.Get("enabled", true)
}

Nmer_WailsBridgeOfficialEnabled(*) {
    flags := Nmer_WailsBridgeReadFlags()
    oa := flags.Get("officialA2ui", Map())
    if !(oa is Map)
        return false
    return !!oa.Get("enabled", false)
}

Nmer_WailsBridgeForceNmerOnly(*) {
    flags := Nmer_WailsBridgeReadFlags()
    rb := flags.Get("rollback", Map())
    if !(rb is Map)
        return false
    return !!rb.Get("forceNmerOnly", false)
}

Nmer_WailsBridgeOfficialEffectiveEnabled(*) {
    if Nmer_WailsBridgeForceNmerOnly()
        return false
    return Nmer_WailsBridgeOfficialEnabled()
}

Nmer_WailsBridgeOfficialWhitelist(*) {
    flags := Nmer_WailsBridgeReadFlags()
    oa := flags.Get("officialA2ui", Map())
    if !(oa is Map)
        return []
    wl := oa.Get("commandWhitelist", [])
    if !(wl is Array)
        return []
    return wl
}

Nmer_SurfaceManagerFlags(*) {
    flags := Nmer_WailsBridgeReadFlags()
    sm := flags.Get("surfaceManager", Map())
    return (sm is Map) ? sm : Map()
}

Nmer_SurfaceManagerEnabled(*) {
    return !!Nmer_SurfaceManagerFlags().Get("enabled", false)
}

Nmer_SurfaceManagerShadowMode(*) {
    return !!Nmer_SurfaceManagerFlags().Get("shadowMode", true)
}

Nmer_SurfaceManagerInterceptWarmup(*) {
    return !!Nmer_SurfaceManagerFlags().Get("interceptWarmup", false)
}

Nmer_SurfaceManagerInterceptOpenClose(*) {
    return !!Nmer_SurfaceManagerFlags().Get("interceptOpenClose", false)
}

Nmer_SurfaceManagerEnforceSlots(*) {
    return !!Nmer_SurfaceManagerFlags().Get("enforceSlots", false)
}

Nmer_SurfaceManagerEnforceBudget(*) {
    return !!Nmer_SurfaceManagerFlags().Get("enforceBudget", false)
}

Nmer_SurfaceManagerRouteIntents(*) {
    return !!Nmer_SurfaceManagerFlags().Get("routeIntents", false)
}

Nmer_LegacySurfaceLifecycleEnabled(*) {
    flags := Nmer_WailsBridgeReadFlags()
    rb := flags.Get("rollback", Map())
    if !(rb is Map)
        return true
    return !!rb.Get("legacySurfaceLifecycle", true)
}

Nmer_ForceTraySafeModeEnabled(*) {
    flags := Nmer_WailsBridgeReadFlags()
    rb := flags.Get("rollback", Map())
    if !(rb is Map)
        return false
    return !!rb.Get("forceTraySafeMode", false)
}

Nmer_WailsBridgeExtractSlashCommand(text) {
    text := Trim(String(text))
    if RegExMatch(text, "i)^(/[a-zA-Z][\w-]*)", &m)
        return StrLower(m[1])
    return ""
}

Nmer_WailsBridgeResolveOfficialRoute(query) {
    cmd := Nmer_WailsBridgeExtractSlashCommand(query)
    wl := Nmer_WailsBridgeOfficialWhitelist()
    if Nmer_WailsBridgeForceNmerOnly()
        return Map("route", "r1r2", "allowed", false, "reason", "force_nmer_only", "command", cmd)
    if !Nmer_WailsBridgeOfficialEffectiveEnabled()
        return Map("route", "r1r2", "allowed", false, "reason", "official_disabled", "command", cmd)
    if !Nmer_WailsBridgeHealthy()
        return Map("route", "r1r2", "allowed", false, "reason", "bridge_not_healthy", "command", cmd)
    if (cmd = "")
        return Map("route", "r1r2", "allowed", false, "reason", "no_slash_command", "command", "")
    if (wl.Length = 0)
        return Map("route", "r1r2", "allowed", false, "reason", "whitelist_empty", "command", cmd)
    for _, item in wl {
        if (StrLower(Trim(String(item))) = cmd)
            return Map("route", "r3", "allowed", true, "reason", "whitelist_hit", "command", cmd)
    }
    return Map("route", "r1r2", "allowed", false, "reason", "not_whitelisted", "command", cmd)
}

Nmer_WailsBridgeExe(*) {
    root := Nmer_InstallRoot()
    return Nmer_ToolFirstExisting(
        root . "\apps\nmer-wails\build\bin\nmer-wails.exe",
        root . "\tools\wails\nmer-wails.exe",
        root . "\bin\nmer-wails.exe"
    )
}

Nmer_WailsBridgeLog(message) {
    try {
        dir := Nmer_InstallRoot() . "\Cache\debug"
        if !DirExist(dir)
            DirCreate(dir)
        FileAppend(
            "[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] " . String(message) . "`n",
            dir . "\wails_bridge.log",
            "UTF-8"
        )
    } catch {
    }
}

Nmer_WailsBridgeHttpBase(*) {
    return "http://" . Nmer_WailsBridgeDefaultAddr()
}

Nmer_WailsBridgeWsUrl(*) {
    return "ws://" . Nmer_WailsBridgeDefaultAddr() . "/agent/ws"
}

Nmer_WailsBridgeHealthUrl(*) {
    return Nmer_WailsBridgeHttpBase() . "/agent/health"
}

Nmer_WailsBridgeIngestUrl(*) {
    return Nmer_WailsBridgeHttpBase() . "/a2ui/ingest"
}

Nmer_WailsBridgeIngestDemoJsonl(relPath := "apps\nmer-wails\poc\testdata\a2ui-adapter-demo.jsonl") {
    if !Nmer_WailsBridgeHealthy()
        return Map("ok", false, "code", "BRIDGE_DOWN")
    root := Nmer_InstallRoot()
    path := root . "\" . relPath
    if !FileExist(path)
        return Map("ok", false, "code", "JSONL_MISSING", "path", path)
    try {
        body := FileRead(path, "UTF-8")
        url := Nmer_WailsBridgeIngestUrl()
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        if FuncExists("NiumaOllama_IsLoopbackUrl") && NiumaOllama_IsLoopbackUrl(url)
            try whr.SetProxy(1)
        whr.Open("POST", url, false)
        whr.SetTimeouts(2000, 2000, 15000, 15000)
        whr.SetRequestHeader("Content-Type", "application/x-ndjson; charset=utf-8")
        whr.Send(body)
        status := Integer(whr.Status)
        text := String(whr.ResponseText)
        ok := (status = 200) && InStr(text, "ok") > 0
        return Map("ok", ok, "code", ok ? "INGEST_OK" : "INGEST_FAIL", "status", status, "body", SubStr(text, 1, 200))
    } catch as err {
        return Map("ok", false, "code", "INGEST_ERR", "detail", err.Message)
    }
}

Nmer_WailsBridgeOpenClawAdapterUrl(*) {
    return Nmer_WailsBridgeHttpBase() . "/a2ui/openclaw/action"
}

Nmer_WailsBridgeTcpOpen(*) {
    addr := Nmer_WailsBridgeDefaultAddr()
    sep := InStr(addr, ":")
    host := sep > 0 ? SubStr(addr, 1, sep - 1) : addr
    port := sep > 0 ? Integer(SubStr(addr, sep + 1)) : 18791
    if (host = "")
        host := "127.0.0.1"
    try {
        tcp := ComObject("System.Net.Sockets.TcpClient")
        tcp.Connect(host, port)
        tcp.Close()
        return true
    } catch {
        return false
    }
}

Nmer_WailsBridgeHealthy(*) {
    if !Nmer_WailsBridgeEnabled()
        return false
    url := Nmer_WailsBridgeHealthUrl()
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        if FuncExists("NiumaOllama_IsLoopbackUrl") && NiumaOllama_IsLoopbackUrl(url)
            try whr.SetProxy(1)
        whr.Open("GET", url, false)
        whr.SetTimeouts(1500, 1500, 4000, 4000)
        whr.Send()
        if (Integer(whr.Status) = 200 && InStr(whr.ResponseText, "ok") > 0)
            return true
    } catch {
    }
    return Nmer_WailsBridgeTcpOpen()
}

Nmer_WailsBridgeKillStale(*) {
    loop 12 {
        pid := ProcessExist("nmer-wails.exe")
        if !pid
            break
        try ProcessClose(pid)
        catch {
        }
        Sleep(200)
    }
}

Nmer_StartWailsBridge(*) {
    global g_Nmer_WailsBridgeLastLaunchTick
    forceRestart := (A_Args.Length > 0) ? !!A_Args[1] : false
    if !Nmer_WailsBridgeEnabled()
        return false
    if !forceRestart && Nmer_WailsBridgeHealthy()
        return true
    exe := Nmer_WailsBridgeExe()
    if (exe = "" || !FileExist(exe))
        return false
    root := Nmer_InstallRoot()
    addr := Nmer_WailsBridgeDefaultAddr()
    if forceRestart
        Nmer_WailsBridgeKillStale()
    now := A_TickCount
    if (now - Integer(g_Nmer_WailsBridgeLastLaunchTick) < 1000) && Nmer_WailsBridgeHealthy()
        return true
    g_Nmer_WailsBridgeLastLaunchTick := now
    try EnvSet("NMER_SCRIPT_DIR", root)
    try EnvSet("NMER_A2UI_BRIDGE_ADDR", addr)
    cmd := '"' . exe . '"'
    try {
        Run(cmd, root, "", &pid)
    } catch {
        return false
    }
    loop 30 {
        if Nmer_WailsBridgeHealthy()
            return true
        Sleep(500)
    }
    return false
}

Nmer_AutoStartWailsBridge(*) {
    if !Nmer_WailsBridgeEnabled() {
        Nmer_WailsBridgeLog("autostart_skip bridge_disabled")
        return
    }
    if Nmer_WailsBridgeHealthy() {
        Nmer_WailsBridgeLog("autostart_skip already_healthy")
        return
    }
    Nmer_WailsBridgeLog("autostart_begin")
    Nmer_StartWailsBridge(false)
}

Nmer_StopWailsBridge(*) {
    Nmer_WailsBridgeLog("stop_begin pid=" . ProcessExist("nmer-wails.exe"))
    Nmer_WailsBridgeKillStale()
}

Nmer_WailsBridgeBuildHostConfig(*) {
    return Map(
        "type", "palette_wails_bridge_config",
        "wailsBridge", Map(
            "enabled", Nmer_WailsBridgeEnabled(),
            "healthy", Nmer_WailsBridgeHealthy(),
            "addr", Nmer_WailsBridgeDefaultAddr(),
            "wsUrl", Nmer_WailsBridgeWsUrl(),
            "ingestUrl", Nmer_WailsBridgeIngestUrl()
        ),
        "officialA2ui", Map(
            "enabled", Nmer_WailsBridgeOfficialEffectiveEnabled(),
            "commandWhitelist", Nmer_WailsBridgeOfficialWhitelist()
        ),
        "surfaceManager", Map(
            "enabled", Nmer_SurfaceManagerEnabled(),
            "shadowMode", Nmer_SurfaceManagerShadowMode(),
            "interceptWarmup", Nmer_SurfaceManagerInterceptWarmup(),
            "interceptOpenClose", Nmer_SurfaceManagerInterceptOpenClose(),
            "enforceSlots", Nmer_SurfaceManagerEnforceSlots(),
            "enforceBudget", Nmer_SurfaceManagerEnforceBudget(),
            "routeIntents", Nmer_SurfaceManagerRouteIntents()
        ),
        "rollback", Map(
            "forceNmerOnly", Nmer_WailsBridgeForceNmerOnly(),
            "legacySurfaceLifecycle", Nmer_LegacySurfaceLifecycleEnabled(),
            "forceTraySafeMode", Nmer_ForceTraySafeModeEnabled()
        )
    )
}

Nmer_EnsureWailsBridgeForPalette(*) {
    if !Nmer_WailsBridgeEnabled() {
        return Map("ok", false, "code", "BRIDGE_DISABLED")
    }
    if Nmer_WailsBridgeHealthy() {
        return Map("ok", true, "code", "BRIDGE_OK")
    }
    if Nmer_StartWailsBridge(false) {
        return Map("ok", true, "code", "BRIDGE_STARTED")
    }
    return Map("ok", false, "code", "BRIDGE_HUB_NOT_READY")
}
