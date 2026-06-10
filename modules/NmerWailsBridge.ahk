; NmerWailsBridge.ahk — B2: AHK 守护 nmer-wails.exe TPA sidecar (:18791)

global g_Nmer_WailsBridgeLastLaunchTick := 0
global g_Nmer_WailsBridgeLaunching := false

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
            cpHost := StrLower(Trim(String(wb.Get("commandPaletteHost", "ahk"))))
            scHost := StrLower(Trim(String(wb.Get("searchCenterHost", "ahk"))))
            cfgHost := StrLower(Trim(String(wb.Get("configWebviewHost", "ahk"))))
            if (cpHost != "wails")
                cpHost := "ahk"
            if (scHost != "wails")
                scHost := "ahk"
            if (cfgHost != "wails")
                cfgHost := "ahk"
            ftbHost := StrLower(Trim(String(wb.Get("floatingToolbarHost", "ahk"))))
            if (ftbHost != "wails")
                ftbHost := "ahk"
            out["wailsBridge"] := Map(
                "enabled", Nmer_WailsBridgeNormalizeBool(wb.Get("enabled", true), true),
                "commandPaletteHost", cpHost,
                "searchCenterHost", scHost,
                "configWebviewHost", cfgHost,
                "floatingToolbarHost", ftbHost
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

Nmer_WailsBridgeHostFlag(flagName, defaultHost := "ahk") {
    flags := Nmer_WailsBridgeReadFlags()
    wb := flags.Get("wailsBridge", Map())
    if !(wb is Map)
        return defaultHost
    host := StrLower(Trim(String(wb.Get(flagName, defaultHost))))
    return (host = "wails") ? "wails" : "ahk"
}

Nmer_CommandPaletteHostFlag(*) {
    return Nmer_WailsBridgeHostFlag("commandPaletteHost", "ahk")
}

Nmer_SearchCenterHostFlag(*) {
    return Nmer_WailsBridgeHostFlag("searchCenterHost", "ahk")
}

Nmer_ConfigWebviewHostFlag(*) {
    return Nmer_WailsBridgeHostFlag("configWebviewHost", "ahk")
}

Nmer_FloatingToolbarHostFlag(*) {
    return Nmer_WailsBridgeHostFlag("floatingToolbarHost", "ahk")
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

Nmer_SurfaceManagerUseTransactions(*) {
    flags := Nmer_SurfaceManagerFlags()
    if flags.Has("useTransactions")
        return !!flags["useTransactions"]
    return Nmer_SurfaceManagerRouteIntents()
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

Nmer_WailsBridgeShellFtbUrl(*) {
    return Nmer_WailsBridgeHttpBase() . "/shell/ftb"
}

Nmer_WailsBridgeShellFtbStatusUrl(*) {
    return Nmer_WailsBridgeHttpBase() . "/shell/ftb/status"
}

Nmer_WailsBridgeShellFtbInjectUrl(*) {
    return Nmer_WailsBridgeHttpBase() . "/shell/ftb/inject"
}

Nmer_WailsBridgeShellFtbEgressUrl(*) {
    return Nmer_WailsBridgeHttpBase() . "/shell/ftb/egress"
}

Nmer_WailsBridgeShellFtbInjectDrainUrl(*) {
    return Nmer_WailsBridgeHttpBase() . "/shell/ftb/inject/drain"
}

Nmer_WailsBridgeParseShellFtbJson(text) {
    t := Trim(String(text))
    if (t = "" || !InStr(t, "visible"))
        return Map("ok", false, "code", "SHELL_STATUS_PARSE")
    vis := false
    mnt := false
    rdy := false
    phase := 2
    if RegExMatch(t, '"visible"\s*:\s*(true|false)', &mv)
        vis := (mv[1] = "true")
    if RegExMatch(t, '"mounted"\s*:\s*(true|false)', &mv)
        mnt := (mv[1] = "true")
    if RegExMatch(t, '"ready"\s*:\s*(true|false)', &mv)
        rdy := (mv[1] = "true")
    if RegExMatch(t, '"phase"\s*:\s*(\d+)', &mv)
        phase := Integer(mv[1])
    entry := ""
    if RegExMatch(t, '"entry"\s*:\s*"((?:[^"\\]|\\.)*)"', &mv)
        entry := mv[1]
    presMode := ""
    if RegExMatch(t, '"presentationMode"\s*:\s*"((?:[^"\\]|\\.)*)"', &mv)
        presMode := mv[1]
    return Map(
        "ok", true,
        "code", "SHELL_STATUS_OK",
        "visible", vis,
        "mounted", mnt,
        "ready", rdy,
        "phase", phase,
        "entry", entry,
        "presentationMode", presMode
    )
}

Nmer_WailsBridgePostShellFtb(action, entry := "", extra := 0) {
    if !Nmer_WailsBridgeHealthy()
        return Map("ok", false, "code", "BRIDGE_DOWN")
    url := Nmer_WailsBridgeShellFtbUrl()
    body := Map("action", String(action))
    if (entry != "")
        body["entry"] := String(entry)
    if (extra is Map) {
        for k, v in extra
            body[String(k)] := v
    }
    try {
        payload := Jxon_Dump(body)
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        if FuncExists("NiumaOllama_IsLoopbackUrl") && NiumaOllama_IsLoopbackUrl(url)
            try whr.SetProxy(1)
        whr.Open("POST", url, false)
        whr.SetTimeouts(2000, 2000, 12000, 12000)
        whr.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
        whr.Send(payload)
        status := Integer(whr.Status)
        text := String(whr.ResponseText)
        ok := (status = 200) && InStr(text, "ok") > 0
        out := Map("ok", ok, "code", ok ? "SHELL_FTB_OK" : "SHELL_FTB_FAIL", "status", status, "body", SubStr(text, 1, 400))
        if ok {
            try {
                parsed := Nmer_WailsBridgeParseShellFtbJson(text)
                if parsed.Get("ok", false)
                    out["statusObj"] := parsed
            } catch {
            }
        }
        return out
    } catch as err {
        return Map("ok", false, "code", "SHELL_FTB_ERR", "detail", err.Message)
    }
}

Nmer_WailsBridgePostShellFtbInject(payload) {
    if !Nmer_WailsBridgeHealthy()
        return Map("ok", false, "code", "BRIDGE_DOWN")
    if !(payload is Map)
        return Map("ok", false, "code", "SHELL_INJECT_BAD_PAYLOAD")
    url := Nmer_WailsBridgeShellFtbInjectUrl()
    try {
        body := Jxon_Dump(payload)
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        if FuncExists("NiumaOllama_IsLoopbackUrl") && NiumaOllama_IsLoopbackUrl(url)
            try whr.SetProxy(1)
        whr.Open("POST", url, false)
        whr.SetTimeouts(2000, 2000, 30000, 30000)
        whr.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
        whr.Send(body)
        status := Integer(whr.Status)
        text := String(whr.ResponseText)
        ok := (status = 200) && (InStr(text, "SHELL_FTB_INJECT_OK") > 0 || InStr(text, "SHELL_FTB_INJECT_QUEUED") > 0)
        code := "SHELL_FTB_INJECT_FAIL"
        if ok {
            if InStr(text, "SHELL_FTB_INJECT_QUEUED") > 0
                code := "SHELL_FTB_INJECT_QUEUED"
            else
                code := "SHELL_FTB_INJECT_OK"
        }
        return Map("ok", ok, "code", code, "status", status)
    } catch as err {
        return Map("ok", false, "code", "SHELL_FTB_INJECT_ERR", "detail", err.Message)
    }
}

Nmer_WailsBridgeDrainShellFtbInject(*) {
    if !Nmer_WailsBridgeHealthy()
        return []
    url := Nmer_WailsBridgeShellFtbInjectDrainUrl()
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        if FuncExists("NiumaOllama_IsLoopbackUrl") && NiumaOllama_IsLoopbackUrl(url)
            try whr.SetProxy(1)
        whr.Open("GET", url, false)
        whr.SetTimeouts(1500, 1500, 8000, 8000)
        whr.Send()
        if (Integer(whr.Status) != 200)
            return []
        text := String(whr.ResponseText)
        if (Trim(text) = "")
            return []
        parsed := Jxon_Load(text)
        if !(parsed is Map)
            return []
        msgs := parsed.Get("messages", [])
        if !(msgs is Array)
            return []
        out := []
        for _, item in msgs {
            if (item is Map)
                out.Push(item)
            else if (item is String) && Trim(item) != "" {
                try {
                    m := Jxon_Load(item)
                    if (m is Map)
                        out.Push(m)
                } catch {
                }
            }
        }
        return out
    } catch {
        return []
    }
}

Nmer_WailsBridgeDrainShellFtbEgress(*) {
    if !Nmer_WailsBridgeHealthy()
        return []
    url := Nmer_WailsBridgeShellFtbEgressUrl()
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        if FuncExists("NiumaOllama_IsLoopbackUrl") && NiumaOllama_IsLoopbackUrl(url)
            try whr.SetProxy(1)
        whr.Open("GET", url, false)
        whr.SetTimeouts(1500, 1500, 8000, 8000)
        whr.Send()
        if (Integer(whr.Status) != 200)
            return []
        text := String(whr.ResponseText)
        if (Trim(text) = "")
            return []
        parsed := Jxon_Load(text)
        if !(parsed is Map)
            return []
        msgs := parsed.Get("messages", [])
        if !(msgs is Array)
            return []
        out := []
        for _, item in msgs {
            if (item is Map)
                out.Push(item)
            else if (item is String) && Trim(item) != "" {
                try {
                    m := Jxon_Load(item)
                    if (m is Map)
                        out.Push(m)
                } catch {
                }
            }
        }
        return out
    } catch {
        return []
    }
}

Nmer_WailsBridgeGetShellFtbStatus(*) {
    if !Nmer_WailsBridgeHealthy()
        return Map("ok", false, "code", "BRIDGE_DOWN", "visible", false, "mounted", false, "ready", false, "phase", 2)
    url := Nmer_WailsBridgeShellFtbStatusUrl()
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        if FuncExists("NiumaOllama_IsLoopbackUrl") && NiumaOllama_IsLoopbackUrl(url)
            try whr.SetProxy(1)
        whr.Open("GET", url, false)
        whr.SetTimeouts(1500, 1500, 5000, 5000)
        whr.Send()
        status := Integer(whr.Status)
        text := String(whr.ResponseText)
        if (status != 200)
            return Map("ok", false, "code", "SHELL_STATUS_FAIL", "status", status)
        parsed := Nmer_WailsBridgeParseShellFtbJson(text)
        if !parsed.Get("ok", false)
            return Map("ok", false, "code", "SHELL_STATUS_PARSE")
        return Map(
            "ok", true,
            "code", "SHELL_STATUS_OK",
            "visible", !!parsed.Get("visible", false),
            "mounted", !!parsed.Get("mounted", false),
            "ready", !!parsed.Get("ready", false),
            "phase", Integer(parsed.Get("phase", 2)),
            "entry", String(parsed.Get("entry", "")),
            "presentationMode", String(parsed.Get("presentationMode", ""))
        )
    } catch as err {
        return Map("ok", false, "code", "SHELL_STATUS_ERR", "detail", err.Message, "phase", 2)
    }
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

Nmer_WailsBridge_ToShortPath(path) {
    p := String(path)
    if (p = "")
        return p
    buf := Buffer(32768, 0)
    len := DllCall("GetShortPathNameW", "wstr", p, "ptr", buf, "uint", 32767, "uint")
    return len ? StrGet(buf) : p
}

Nmer_WailsBridge_WriteScriptDirMarker(root) {
    root := String(root)
    if (root = "")
        return ""
    markerDir := root . "\Cache\debug"
    try {
        if !DirExist(markerDir)
            DirCreate(markerDir)
    } catch {
    }
    markerPath := markerDir . "\nmer_script_dir.utf8.txt"
    try {
        if FileExist(markerPath)
            FileDelete(markerPath)
        FileAppend(root, markerPath, "UTF-8")
        return markerPath
    } catch {
        return ""
    }
}

Nmer_WailsBridge_ProcessExists(*) {
    try {
        return !!ProcessExist("nmer-wails.exe")
    } catch {
        return false
    }
}

Nmer_StartWailsBridge(*) {
    global g_Nmer_WailsBridgeLastLaunchTick, g_Nmer_WailsBridgeLaunching
    forceRestart := (A_Args.Length > 0) ? !!A_Args[1] : false
    if !Nmer_WailsBridgeEnabled()
        return false
    if !forceRestart && Nmer_WailsBridgeHealthy()
        return true
    if !forceRestart && g_Nmer_WailsBridgeLaunching {
        loop 40 {
            if Nmer_WailsBridgeHealthy()
                return true
            Sleep(250)
        }
        return Nmer_WailsBridgeHealthy()
    }
    if !forceRestart && Nmer_WailsBridge_ProcessExists() {
        loop 24 {
            if Nmer_WailsBridgeHealthy()
                return true
            Sleep(250)
        }
        if Nmer_WailsBridge_ProcessExists() {
            Nmer_WailsBridgeLog("start_skip duplicate_pid=" . ProcessExist("nmer-wails.exe"))
            return Nmer_WailsBridgeHealthy()
        }
    }
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
    g_Nmer_WailsBridgeLaunching := true
    rootForChild := Nmer_WailsBridge_ToShortPath(root)
    markerPath := Nmer_WailsBridge_WriteScriptDirMarker(root)
    try EnvSet("NMER_SCRIPT_DIR", rootForChild)
    try EnvSet("NMER_A2UI_BRIDGE_ADDR", addr)
    if (markerPath != "") {
        try EnvSet("NMER_SCRIPT_DIR_UTF8_FILE", Nmer_WailsBridge_ToShortPath(markerPath))
    }
    hybridHost := false
    if FuncExists("Nmer_FloatingToolbarHost")
        try hybridHost := (Nmer_FloatingToolbarHost() = "hybrid")
        catch {
        }
    if hybridHost {
        try EnvSet("NMER_BRIDGE_ONLY", "1")
        try EnvSet("NMER_FTB_PRESENTATION", "external")
    } else {
        try EnvSet("NMER_BRIDGE_ONLY", "")
        try EnvSet("NMER_FTB_PRESENTATION", "")
    }
    cmd := '"' . exe . '"'
    workDir := rootForChild != "" ? rootForChild : root
    try {
        Run(cmd, workDir, "", &pid)
    } catch {
        g_Nmer_WailsBridgeLaunching := false
        return false
    }
    loop 30 {
        if Nmer_WailsBridgeHealthy() {
            g_Nmer_WailsBridgeLaunching := false
            return true
        }
        Sleep(500)
    }
    g_Nmer_WailsBridgeLaunching := false
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
    if Nmer_WailsBridge_ProcessExists() {
        Nmer_WailsBridgeLog("autostart_skip process_exists")
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
            "commandPaletteHost", Nmer_CommandPaletteHostFlag(),
            "searchCenterHost", Nmer_SearchCenterHostFlag(),
            "configWebviewHost", Nmer_ConfigWebviewHostFlag(),
            "floatingToolbarHost", Nmer_FloatingToolbarHostFlag(),
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
            "routeIntents", Nmer_SurfaceManagerRouteIntents(),
            "useTransactions", Nmer_SurfaceManagerUseTransactions()
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
