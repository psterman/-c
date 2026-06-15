; NmerWailsBridge.ahk — B2: AHK 守护 nmer-hub / nmer-wails 侧车 (:18791)

global g_Nmer_WailsBridgeLastLaunchTick := 0
global g_Nmer_WailsBridgeLaunching := false
global g_Nmer_WailsBridgeHealthCacheOk := false
global g_Nmer_WailsBridgeHealthCacheTick := 0
global g_Nmer_WailsBridgeHealthBusy := false
global g_Nmer_WailsBridgeShuttingDown := false
global g_Nmer_WailsBridgeOpenClawEnvTick := 0

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
        "wailsBridge", Map("enabled", true, "sidecarHost", "hub"),
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
        ),
        "palette", Map(
            "fastInput", false,
            "discreteLayout", false,
            "streamBatching", false,
            "stateStore", false,
            "stateStoreShadow", false,
            "agentTransport", "auto",
            "openclawAnswerSync", true
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
        pl := data.Get("palette", Map())
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
            if (ftbHost != "wails" && ftbHost != "hybrid")
                ftbHost := "ahk"
            sidecarHost := StrLower(Trim(String(wb.Get("sidecarHost", "hub"))))
            if (sidecarHost != "wails")
                sidecarHost := "hub"
            out["wailsBridge"] := Map(
                "enabled", Nmer_WailsBridgeNormalizeBool(wb.Get("enabled", true), true),
                "sidecarHost", sidecarHost,
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
        if (pl is Map) {
            agentTransport := StrLower(Trim(String(pl.Get("agentTransport", "auto"))))
            if (agentTransport != "hub" && agentTransport != "ftb")
                agentTransport := "auto"
            out["palette"] := Map(
                "fastInput", Nmer_WailsBridgeNormalizeBool(pl.Get("fastInput", false), false),
                "discreteLayout", Nmer_WailsBridgeNormalizeBool(pl.Get("discreteLayout", false), false),
                "streamBatching", Nmer_WailsBridgeNormalizeBool(pl.Get("streamBatching", false), false),
                "stateStore", Nmer_WailsBridgeNormalizeBool(pl.Get("stateStore", false), false),
                "stateStoreShadow", Nmer_WailsBridgeNormalizeBool(pl.Get("stateStoreShadow", false), false),
                "agentTransport", agentTransport,
                "openclawAnswerSync", Nmer_WailsBridgeNormalizeBool(pl.Get("openclawAnswerSync", true), true)
            )
        } else {
            out["palette"] := defaults["palette"]
        }
        return out
    } catch {
        return defaults
    }
}

Nmer_PaletteFlags(*) {
    flags := Nmer_WailsBridgeReadFlags()
    pl := flags.Get("palette", Map())
    if (pl is Map)
        return pl
    return Map("fastInput", false, "discreteLayout", false, "streamBatching", false, "stateStore", false, "stateStoreShadow", false, "agentTransport", "auto", "openclawAnswerSync", true)
}

Nmer_PaletteStateStoreShadowEnabled(*) {
    return !!Nmer_PaletteFlags().Get("stateStoreShadow", false)
}

Nmer_PaletteFastInputEnabled(*) {
    return !!Nmer_PaletteFlags().Get("fastInput", false)
}

Nmer_PaletteDiscreteLayoutEnabled(*) {
    return !!Nmer_PaletteFlags().Get("discreteLayout", false)
}

Nmer_PaletteStreamBatchingEnabled(*) {
    return !!Nmer_PaletteFlags().Get("streamBatching", false)
}

Nmer_PaletteStateStoreEnabled(*) {
    return !!Nmer_PaletteFlags().Get("stateStore", false)
}

Nmer_PaletteAgentTransport(*) {
    t := StrLower(Trim(String(Nmer_PaletteFlags().Get("agentTransport", "auto"))))
    if (t != "hub" && t != "ftb")
        t := "auto"
    return t
}

Nmer_PaletteAgentTransportHubEnabled(*) {
    return Nmer_PaletteAgentTransport() = "hub"
}

Nmer_PaletteOpenClawAnswerSync(*) {
    return !!Nmer_PaletteFlags().Get("openclawAnswerSync", true)
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
    flags := Nmer_WailsBridgeReadFlags()
    wb := flags.Get("wailsBridge", Map())
    if !(wb is Map)
        return "ahk"
    host := StrLower(Trim(String(wb.Get("floatingToolbarHost", "ahk"))))
    if (host = "hybrid")
        return "hybrid"
    return (host = "wails") ? "wails" : "ahk"
}

Nmer_WailsBridgeEnabled(*) {
    flags := Nmer_WailsBridgeReadFlags()
    wb := flags.Get("wailsBridge", Map())
    if !(wb is Map)
        return true
    return !!wb.Get("enabled", true)
}

Nmer_BridgeSidecarMode(*) {
    flags := Nmer_WailsBridgeReadFlags()
    wb := flags.Get("wailsBridge", Map())
    if !(wb is Map)
        return "hub"
    mode := StrLower(Trim(String(wb.Get("sidecarHost", "hub"))))
    return (mode = "wails") ? "wails" : "hub"
}

Nmer_BridgeSidecarProcessName(*) {
    return (Nmer_BridgeSidecarMode() = "wails") ? "nmer-wails.exe" : "nmer-hub.exe"
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

Nmer_HubBridgeExe(*) {
    root := Nmer_InstallRoot()
    return Nmer_ToolFirstExisting(
        root . "\apps\nmer-hub\build\bin\nmer-hub.exe",
        root . "\apps\nmer-hub\nmer-hub.exe",
        root . "\bin\nmer-hub.exe"
    )
}

; S8 B3 阶段 2：CP UI 在 nmer-wails 内渲染，须 shell:cp emit；hub-only 侧车无 WebView 无法承载 iframe。
Nmer_WailsBridgePrefersWailsSidecar(*) {
    if Nmer_LegacySurfaceLifecycleEnabled()
        return false
    if FuncExists("Nmer_CommandPaletteHost")
        return Nmer_CommandPaletteHost() = "wails"
    return Nmer_CommandPaletteHostFlag() = "wails"
}

Nmer_WailsBridgeExe(*) {
    root := Nmer_InstallRoot()
    wailsExe := Nmer_ToolFirstExisting(
        root . "\apps\nmer-wails\build\bin\nmer-wails.exe",
        root . "\tools\wails\nmer-wails.exe",
        root . "\bin\nmer-wails.exe"
    )
    if Nmer_WailsBridgePrefersWailsSidecar() {
        if (wailsExe != "" && FileExist(wailsExe))
            return wailsExe
        Nmer_WailsBridgeLog("cp_wails_sidecar_missing fallback_hub")
    }
    if (Nmer_BridgeSidecarMode() = "hub") {
        hub := Nmer_HubBridgeExe()
        if (hub != "" && FileExist(hub))
            return hub
        Nmer_WailsBridgeLog("hub_missing fallback_wails")
    }
    return wailsExe
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

Nmer_WailsBridgeShellCpUrl(*) {
    return Nmer_WailsBridgeHttpBase() . "/shell/cp"
}

Nmer_WailsBridgeShellCpStatusUrl(*) {
    return Nmer_WailsBridgeHttpBase() . "/shell/cp/status"
}

Nmer_WailsBridgeShellCpInjectUrl(*) {
    return Nmer_WailsBridgeHttpBase() . "/shell/cp/inject"
}

Nmer_WailsBridgeShellCpEgressUrl(*) {
    return Nmer_WailsBridgeHttpBase() . "/shell/cp/egress"
}

Nmer_WailsBridgeShellCpInjectDrainUrl(*) {
    return Nmer_WailsBridgeHttpBase() . "/shell/cp/inject/drain"
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

Nmer_WailsBridgeParseShellCpJson(text) {
    if FuncExists("Nmer_WailsBridgeParseShellFtbJson")
        return Nmer_WailsBridgeParseShellFtbJson(text)
    return Map("ok", false, "code", "SHELL_STATUS_PARSE")
}

Nmer_WailsBridgePostShellCp(action, entry := "", extra := 0) {
    if !Nmer_WailsBridgeHealthy()
        return Map("ok", false, "code", "BRIDGE_DOWN")
    url := Nmer_WailsBridgeShellCpUrl()
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
        out := Map("ok", ok, "code", ok ? "SHELL_CP_OK" : "SHELL_CP_FAIL", "status", status, "body", SubStr(text, 1, 400))
        if ok {
            try {
                parsed := Nmer_WailsBridgeParseShellCpJson(text)
                if parsed.Get("ok", false)
                    out["statusObj"] := parsed
            } catch {
            }
        }
        return out
    } catch as err {
        return Map("ok", false, "code", "SHELL_CP_ERR", "detail", err.Message)
    }
}

Nmer_WailsBridgePostShellCpInject(payload) {
    if !Nmer_WailsBridgeHealthy()
        return Map("ok", false, "code", "BRIDGE_DOWN")
    if !(payload is Map)
        return Map("ok", false, "code", "SHELL_INJECT_BAD_PAYLOAD")
    url := Nmer_WailsBridgeShellCpInjectUrl()
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
        ok := (status = 200) && (InStr(text, "SHELL_CP_INJECT_OK") > 0 || InStr(text, "SHELL_CP_INJECT_QUEUED") > 0)
        code := "SHELL_CP_INJECT_FAIL"
        if ok {
            if InStr(text, "SHELL_CP_INJECT_QUEUED") > 0
                code := "SHELL_CP_INJECT_QUEUED"
            else
                code := "SHELL_CP_INJECT_OK"
        }
        return Map("ok", ok, "code", code, "status", status)
    } catch as err {
        return Map("ok", false, "code", "SHELL_CP_INJECT_ERR", "detail", err.Message)
    }
}

Nmer_WailsBridgeDrainShellCpInject(*) {
    if !Nmer_WailsBridgeHealthy()
        return []
    url := Nmer_WailsBridgeShellCpInjectDrainUrl()
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

Nmer_WailsBridgeDrainShellCpEgress(*) {
    if !Nmer_WailsBridgeHealthy()
        return []
    url := Nmer_WailsBridgeShellCpEgressUrl()
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

Nmer_WailsBridgePostShellCpEgress(payload) {
    if !Nmer_WailsBridgeHealthy()
        return Map("ok", false, "code", "BRIDGE_DOWN")
    if !(payload is Map)
        return Map("ok", false, "code", "SHELL_EGRESS_BAD_PAYLOAD")
    url := Nmer_WailsBridgeShellCpEgressUrl()
    try {
        body := Jxon_Dump(payload)
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        if FuncExists("NiumaOllama_IsLoopbackUrl") && NiumaOllama_IsLoopbackUrl(url)
            try whr.SetProxy(1)
        whr.Open("POST", url, false)
        whr.SetTimeouts(2000, 2000, 15000, 15000)
        whr.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
        whr.Send(body)
        status := Integer(whr.Status)
        text := String(whr.ResponseText)
        ok := (status = 200) && (InStr(text, "SHELL_CP_EGRESS_OK") > 0)
        return Map("ok", ok, "code", ok ? "SHELL_CP_EGRESS_OK" : "SHELL_CP_EGRESS_FAIL", "status", status)
    } catch as err {
        return Map("ok", false, "code", "SHELL_CP_EGRESS_ERR", "detail", err.Message)
    }
}

Nmer_WailsBridgeGetShellCpStatus(*) {
    if !Nmer_WailsBridgeHealthy()
        return Map("ok", false, "code", "BRIDGE_DOWN", "visible", false, "mounted", false, "ready", false, "phase", 2)
    url := Nmer_WailsBridgeShellCpStatusUrl()
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
        parsed := Nmer_WailsBridgeParseShellCpJson(text)
        if !parsed.Get("ok", false)
            return Map("ok", false, "code", "SHELL_STATUS_PARSE")
        return Map(
            "ok", true,
            "code", "SHELL_STATUS_OK",
            "visible", !!parsed.Get("visible", false),
            "mounted", !!parsed.Get("mounted", false),
            "ready", !!parsed.Get("ready", false),
            "phase", Integer(parsed.Get("phase", 2)),
            "entry", String(parsed.Get("entry", ""))
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

Nmer_WailsBridge_ParseAddr(addr := "") {
    if (addr = "")
        addr := Nmer_WailsBridgeDefaultAddr()
    sep := InStr(addr, ":")
    host := sep > 0 ? SubStr(addr, 1, sep - 1) : addr
    port := sep > 0 ? Integer(SubStr(addr, sep + 1)) : 18791
    if (host = "")
        host := "127.0.0.1"
    return Map("host", host, "port", port)
}

; GUI 线程在 WebView2 创建/导航期间同步 WinHttp.Send 会触发 Invalid memory read/write（见 FloatingToolbarWailsHost 注释）。
Nmer_WailsBridge_ShouldAvoidSyncWinHttp(*) {
    global g_WV2_CreateBusy, g_SCWV_CreateInFlight
    if g_WV2_CreateBusy
        return true
    if g_SCWV_CreateInFlight
        return true
    if FuncExists("WebView2_GetCreateQueueDepth") && WebView2_GetCreateQueueDepth() > 0
        return true
    return false
}

Nmer_WailsBridgeTcpOpen(*) {
    ap := Nmer_WailsBridge_ParseAddr()
    host := ap["host"]
    port := ap["port"]
    if FuncExists("LlmApiPing_TcpPortOpen")
        return LlmApiPing_TcpPortOpen(host, port, 1200)
    try {
        tcp := ComObject("System.Net.Sockets.TcpClient")
        tcp.Connect(host, port)
        tcp.Close()
        return true
    } catch {
        return false
    }
}

Nmer_WailsBridgePrepareForScriptReload(*) {
    global g_Nmer_HybridManualProbeOn, g_Nmer_HybridSignoffDrainOn, g_Nmer_WailsBridgeShuttingDown
    global g_Nmer_WailsBridgeHealthBusy
    g_Nmer_WailsBridgeShuttingDown := true
    g_Nmer_HybridManualProbeOn := false
    g_Nmer_HybridSignoffDrainOn := false
    g_Nmer_WailsBridgeHealthBusy := false
    try SetTimer(Nmer_HybridManualProbePoll, 0)
    catch {
    }
    try SetTimer(Nmer_HybridSignoffDrainBootstrap, 0)
    catch {
    }
    if FuncExists("FloatingToolbarWails_StopInjectPump")
        try FloatingToolbarWails_StopInjectPump()
    catch {
    }
    try Nmer_WailsBridgeLog("prepare_reload timers_off")
    catch {
    }
}

Nmer_WailsBridgeHealthyHttp(*) {
    if Nmer_WailsBridge_ShouldAvoidSyncWinHttp()
        return false
    url := Nmer_WailsBridgeHealthUrl()
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        if FuncExists("NiumaOllama_IsLoopbackUrl") && NiumaOllama_IsLoopbackUrl(url)
            try whr.SetProxy(1)
        whr.Open("GET", url, false)
        whr.SetTimeouts(800, 800, 2000, 2000)
        whr.Send()
        if (Integer(whr.Status) = 200 && InStr(whr.ResponseText, "ok") > 0)
            return true
    } catch {
    }
    return false
}

Nmer_WailsBridgeHealthy(*) {
    global g_Nmer_WailsBridgeHealthCacheOk, g_Nmer_WailsBridgeHealthCacheTick, g_Nmer_WailsBridgeHealthBusy
    global g_Nmer_WailsBridgeShuttingDown
    if !Nmer_WailsBridgeEnabled()
        return false
    if g_Nmer_WailsBridgeShuttingDown
        return false
    now := A_TickCount
    if (now - g_Nmer_WailsBridgeHealthCacheTick < 2500)
        return !!g_Nmer_WailsBridgeHealthCacheOk
    if g_Nmer_WailsBridgeHealthBusy
        return !!g_Nmer_WailsBridgeHealthCacheOk
    g_Nmer_WailsBridgeHealthBusy := true
    ok := false
    try {
        ok := Nmer_WailsBridgeTcpOpen()
        if !ok && !Nmer_WailsBridge_ShouldAvoidSyncWinHttp()
            ok := Nmer_WailsBridgeHealthyHttp()
    } catch {
        ok := false
    } finally {
        g_Nmer_WailsBridgeHealthBusy := false
        g_Nmer_WailsBridgeHealthCacheOk := ok
        g_Nmer_WailsBridgeHealthCacheTick := A_TickCount
    }
    return ok
}

Nmer_WailsBridgeKillStale(*) {
    for exeName in ["nmer-hub.exe", "nmer-wails.exe"] {
        loop 12 {
            pid := ProcessExist(exeName)
            if !pid
                break
            try ProcessClose(pid)
            catch {
            }
            Sleep(200)
        }
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
        return !!ProcessExist("nmer-hub.exe") || !!ProcessExist("nmer-wails.exe")
    } catch {
        return false
    }
}

Nmer_WailsBridgeIsHybridHost(*) {
    if !FuncExists("Nmer_FloatingToolbarHost")
        return false
    try return (Nmer_FloatingToolbarHost() = "hybrid")
    catch {
        return false
    }
}

Nmer_HybridManualProbeMaybeEnsure(*) {
    if FuncExists("Nmer_HybridSignoffBootstrapEnsure")
        try Nmer_HybridSignoffBootstrapEnsure()
        catch {
        }
}

; 将 Niuma Chat / user_studio / 环境变量中的 OpenClaw Token 同步到当前进程，供 nmer-hub 子进程继承
Nmer_WailsBridgeSyncOpenClawTokenToEnv(*) {
    token := ""
    host := "127.0.0.1"
    port := "18789"
    source := ""
    if FuncExists("UserStudio_ProbeOpenClawGatewayToken") {
        try {
            info := UserStudio_ProbeOpenClawGatewayToken()
            if (info is Map) {
                token := Trim(String(info.Get("token", "")))
                source := Trim(String(info.Get("source", "")))
                h := Trim(String(info.Get("host", "")))
                if (h != "")
                    host := h
                p := info.Get("port", "")
                if (p != "")
                    port := String(p)
            }
        } catch {
        }
    }
    if (token = "")
        return Map("ok", false, "code", "TOKEN_MISSING", "source", source)
    prev := ""
    try prev := Trim(String(EnvGet("OPENCLAW_GATEWAY_TOKEN")))
    changed := (prev != token)
    try EnvSet("OPENCLAW_GATEWAY_TOKEN", token)
    try EnvSet("OPENCLAW_GATEWAY_HOST", host)
    try EnvSet("OPENCLAW_GATEWAY_PORT", port)
    return Map("ok", true, "code", "TOKEN_SYNCED", "changed", changed, "source", source)
}

; Adapter 调用前确保 hub 子进程已继承 Token（必要时重启 hub）
Nmer_WailsBridgeEnsureOpenClawHubEnv(*) {
    global g_Nmer_WailsBridgeOpenClawEnvTick
    sync := Nmer_WailsBridgeSyncOpenClawTokenToEnv()
    if !sync.Get("ok", false)
        return sync
    now := A_TickCount
    needRestart := !!sync.Get("changed", false) && Nmer_WailsBridge_ProcessExists()
    if needRestart && (now - Integer(g_Nmer_WailsBridgeOpenClawEnvTick) > 5000) {
        g_Nmer_WailsBridgeOpenClawEnvTick := now
        Nmer_WailsBridgeLog("openclaw_env_restart source=" . String(sync.Get("source", "")))
        Nmer_WailsBridgeKillStale()
        ok := Nmer_StartWailsBridge(true)
        return Map(
            "ok", ok,
            "code", ok ? "HUB_RESTARTED_FOR_TOKEN" : "HUB_RESTART_FAILED",
            "source", sync.Get("source", "")
        )
    }
    if !Nmer_WailsBridgeHealthy()
        return Map("ok", Nmer_StartWailsBridge(false), "code", "HUB_ENSURE_STARTED", "source", sync.Get("source", ""))
    return Map("ok", true, "code", "TOKEN_READY", "source", sync.Get("source", ""))
}

Nmer_StartWailsBridge(*) {
    global g_Nmer_WailsBridgeLastLaunchTick, g_Nmer_WailsBridgeLaunching
    forceRestart := (A_Args.Length > 0) ? !!A_Args[1] : false
    if !Nmer_WailsBridgeEnabled()
        return false
    if !forceRestart && Nmer_WailsBridgeHealthy() {
        Nmer_HybridManualProbeMaybeEnsure()
        return true
    }
    if !forceRestart && g_Nmer_WailsBridgeLaunching {
        loop 40 {
            if Nmer_WailsBridgeHealthy() {
                Nmer_HybridManualProbeMaybeEnsure()
                return true
            }
            Sleep(250)
        }
        if Nmer_WailsBridgeHealthy() {
            Nmer_HybridManualProbeMaybeEnsure()
            return true
        }
        return false
    }
    if !forceRestart && Nmer_WailsBridge_ProcessExists() {
        loop 24 {
            if Nmer_WailsBridgeHealthy() {
                Nmer_HybridManualProbeMaybeEnsure()
                return true
            }
            Sleep(250)
        }
        if Nmer_WailsBridge_ProcessExists() {
            Nmer_WailsBridgeLog("start_skip duplicate_pid=" . ProcessExist(Nmer_BridgeSidecarProcessName()))
            if Nmer_WailsBridgeHealthy()
                Nmer_HybridManualProbeMaybeEnsure()
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
    if (now - Integer(g_Nmer_WailsBridgeLastLaunchTick) < 1000) && Nmer_WailsBridgeHealthy() {
        Nmer_HybridManualProbeMaybeEnsure()
        return true
    }
    g_Nmer_WailsBridgeLastLaunchTick := now
    g_Nmer_WailsBridgeLaunching := true
    try Nmer_WailsBridgeSyncOpenClawTokenToEnv()
    catch {
    }
    rootForChild := Nmer_WailsBridge_ToShortPath(root)
    markerPath := Nmer_WailsBridge_WriteScriptDirMarker(root)
    try EnvSet("NMER_SCRIPT_DIR", rootForChild)
    try EnvSet("NMER_A2UI_BRIDGE_ADDR", addr)
    if (markerPath != "") {
        try EnvSet("NMER_SCRIPT_DIR_UTF8_FILE", Nmer_WailsBridge_ToShortPath(markerPath))
    }
    hybridHost := Nmer_WailsBridgeIsHybridHost()
    sidecarMode := Nmer_BridgeSidecarMode()
    if (sidecarMode = "wails") {
        try EnvSet("NMER_BRIDGE_ONLY", hybridHost ? "1" : "")
    } else {
        try EnvSet("NMER_BRIDGE_ONLY", "")
    }
    if hybridHost {
        try EnvSet("NMER_FTB_PRESENTATION", "external")
    } else {
        try EnvSet("NMER_FTB_PRESENTATION", "")
    }
    cmd := '"' . exe . '"'
    workDir := rootForChild != "" ? rootForChild : root
    try {
        Run(cmd, workDir, "Hide", &pid)
    } catch {
        g_Nmer_WailsBridgeLaunching := false
        return false
    }
    loop 30 {
        if Nmer_WailsBridgeHealthy() {
            g_Nmer_WailsBridgeLaunching := false
            Nmer_HybridManualProbeMaybeEnsure()
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
        Nmer_HybridManualProbeMaybeEnsure()
        return
    }
    if Nmer_WailsBridge_ProcessExists() {
        Nmer_WailsBridgeLog("autostart_reconcile process_exists healthy=" . (Nmer_WailsBridgeHealthy() ? 1 : 0))
        g_Nmer_WailsBridgeHealthCacheTick := 0
        if !Nmer_WailsBridgeHealthy() && Nmer_WailsBridgeTcpOpen()
            g_Nmer_WailsBridgeHealthCacheOk := true
        Nmer_HybridManualProbeMaybeEnsure()
        return
    }
    Nmer_WailsBridgeLog("autostart_begin")
    Nmer_StartWailsBridge(false)
    Nmer_HybridManualProbeMaybeEnsure()
}

Nmer_StopWailsBridge(*) {
    if FuncExists("Nmer_WailsBridgePrepareForScriptReload")
        try Nmer_WailsBridgePrepareForScriptReload()
        catch {
        }
    Nmer_WailsBridgeLog("stop_begin sidecar=" . Nmer_BridgeSidecarMode() . " pid=" . ProcessExist(Nmer_BridgeSidecarProcessName()))
    Nmer_WailsBridgeKillStale()
}

Nmer_WailsBridgeBuildHostConfig(*) {
    return Map(
        "type", "palette_wails_bridge_config",
        "wailsBridge", Map(
            "enabled", Nmer_WailsBridgeEnabled(),
            "healthy", Nmer_WailsBridgeHealthy(),
            "sidecarHost", Nmer_BridgeSidecarMode(),
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
        ),
        "palette", Map(
            "agentTransport", Nmer_PaletteAgentTransport(),
            "stateStore", Nmer_PaletteStateStoreEnabled(),
            "openclawAnswerSync", Nmer_PaletteOpenClawAnswerSync()
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

; --- Hybrid manual signoff file IPC (tools/a2ui-diagnostics/Run-HybridManualSignoff.ps1) ---
global g_Nmer_HybridManualProbeOn := false
global g_Nmer_HybridSignoffDrainOn := false

Nmer_HybridSignoffIsActive(*) {
    if FuncExists("Nmer_HybridManualProbeIsHybridHost") && Nmer_HybridManualProbeIsHybridHost()
        return true
    if FuncExists("FloatingToolbarWails_ShouldUseHybrid") && FloatingToolbarWails_ShouldUseHybrid()
        return true
    return false
}

Nmer_HybridSignoffDrainBootstrap(*) {
    if !Nmer_HybridSignoffIsActive()
        return
    if FuncExists("Nmer_HybridSignoffDrainInjectQueue")
        try Nmer_HybridSignoffDrainInjectQueue()
}

Nmer_HybridSignoffStartupEnsure(*) {
    global g_Nmer_WailsBridgeShuttingDown, g_Nmer_WailsBridgeHealthCacheTick
    g_Nmer_WailsBridgeShuttingDown := false
    g_Nmer_WailsBridgeHealthCacheTick := 0
    if FuncExists("Nmer_HybridSignoffBootstrapEnsure")
        try Nmer_HybridSignoffBootstrapEnsure()
        catch {
        }
}

Nmer_HybridSignoffBootstrapEnsure(*) {
    if !Nmer_HybridManualProbeIsHybridHost()
        return
    global g_Nmer_HybridSignoffDrainOn, g_Nmer_WailsBridgeShuttingDown
    g_Nmer_WailsBridgeShuttingDown := false
    if !g_Nmer_HybridSignoffDrainOn {
        g_Nmer_HybridSignoffDrainOn := true
        SetTimer(Nmer_HybridSignoffDrainBootstrap, 300)
        if FuncExists("Nmer_HybridManualProbeLog")
            Nmer_HybridManualProbeLog("signoff_drain_timer_on")
    } else {
        SetTimer(Nmer_HybridSignoffDrainBootstrap, 300)
    }
    if FuncExists("FloatingToolbarWails_EnsureInjectPump")
        try FloatingToolbarWails_EnsureInjectPump()
    if FuncExists("Nmer_HybridManualProbeEnsure")
        try Nmer_HybridManualProbeEnsure()
    if !Nmer_WailsBridgeHealthy() && FuncExists("Nmer_AutoStartWailsBridge")
        SetTimer(Nmer_AutoStartWailsBridge, -1)
}

Nmer_HybridManualProbeIsHybridHost(*) {
    if Nmer_WailsBridgeIsHybridHost()
        return true
    try {
        flags := Nmer_WailsBridgeReadFlags()
        if flags.Has("wailsBridge") {
            wb := flags["wailsBridge"]
            if (wb is Map) && (StrLower(Trim(String(wb.Get("floatingToolbarHost", "")))) = "hybrid")
                return true
        }
    } catch {
    }
    return false
}

Nmer_HybridManualProbeEnsure(*) {
    global g_Nmer_HybridManualProbeOn
    if g_Nmer_HybridManualProbeOn
        return
    if !Nmer_HybridManualProbeIsHybridHost()
        return
    g_Nmer_HybridManualProbeOn := true
    SetTimer(Nmer_HybridManualProbePoll, 350)
    Nmer_HybridManualProbeLog("probe_timer_on")
    try Nmer_HybridManualProbePoll()
    catch {
    }
}

Nmer_HybridManualProbePaths(*) {
    root := FuncExists("Nmer_InstallRoot") ? Nmer_InstallRoot() : A_ScriptDir
    dbg := root . "\Cache\debug"
    if !DirExist(dbg)
        try DirCreate(dbg)
    return Map(
        "req", dbg . "\hybrid_manual_probe.json",
        "res", dbg . "\hybrid_manual_probe_result.json",
        "injectRes", dbg . "\hybrid_signoff_inject_result.json",
        "log", dbg . "\hybrid_manual_probe.log"
    )
}

Nmer_HybridSignoffWriteInjectResult(probeId, ok, pass, code, detail := "", extra := 0) {
    paths := Nmer_HybridManualProbePaths()
    body := Map(
        "probeId", String(probeId),
        "ok", !!ok,
        "pass", !!pass,
        "code", String(code),
        "detail", String(detail),
        "finishedAt", A_Now,
        "via", "hub_inject"
    )
    if (extra is Map) {
        for k, v in extra
            body[String(k)] := v
    }
    try {
        f := FileOpen(paths["injectRes"], "w", "UTF-8-RAW")
        if IsObject(f) {
            f.Write(Jxon_Dump(body))
            f.Close()
        }
    } catch {
    }
    Nmer_HybridManualProbeLog("inject_result id=" . probeId . " code=" . code . " pass=" . (pass ? 1 : 0))
}

Nmer_HybridRunUiCycle(rounds, pauseMs) {
    if (rounds < 1)
        rounds := 1
    if (rounds > 20)
        rounds := 20
    if (pauseMs < 120)
        pauseMs := 120
    if !FuncExists("SurfaceIntent_Open") || !FuncExists("SurfaceIntent_Close")
        return Map("pass", false, "rounds", rounds, "okRounds", 0, "errors", ["SURFACE_INTENT_MISSING"])
    okRounds := 0
    errors := []
    loop rounds {
        r := A_Index
        try {
            SurfaceIntent_Open("command_palette", Map("reason", "hybrid_signoff_inject", "round", r))
            Sleep(pauseMs)
            SurfaceIntent_Close("command_palette", Map("reason", "hybrid_signoff_inject", "round", r))
            Sleep(pauseMs)
            SurfaceIntent_Open("search_center", Map("reason", "hybrid_signoff_inject", "round", r))
            Sleep(pauseMs)
            SurfaceIntent_Close("search_center", Map("reason", "hybrid_signoff_inject", "round", r))
            Sleep(pauseMs)
            SurfaceIntent_Close("floating_toolbar", Map("reason", "hybrid_signoff_inject", "round", r))
            Sleep(pauseMs)
            SurfaceIntent_Open("floating_toolbar", Map("reason", "hybrid_signoff_inject", "round", r))
            Sleep(pauseMs)
            okRounds += 1
        } catch as errCycle {
            errors.Push("round" . r . ":" . errCycle.Message)
        }
    }
    pass := (okRounds = rounds) && (errors.Length = 0)
    return Map("pass", pass, "rounds", rounds, "okRounds", okRounds, "errors", errors)
}

; UI cycle 反复开关 CP/SC/FTB 后，悬浮栏 WebView 可能卡在 waitingReveal / ready=False，需主动恢复图标与 hub ready。
Nmer_HybridSignoffRecoverFtbAfterStress() {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_WaitingUiFinishedReveal
    if FuncExists("FloatingToolbarWails_EnsureHybridBridge")
        try FloatingToolbarWails_EnsureHybridBridge()
        catch {
        }
    if FuncExists("ShowFloatingToolbar")
        try ShowFloatingToolbar()
        catch {
        }
    if IsObject(g_FTB_WV2) {
        if g_FTB_WaitingUiFinishedReveal && FuncExists("FloatingToolbar_FinishRevealBoot")
            try FloatingToolbar_FinishRevealBoot()
            catch {
            }
        if FuncExists("FloatingToolbarPushButtonConfigToWeb")
            try FloatingToolbarPushButtonConfigToWeb()
            catch {
            }
        if FuncExists("FloatingToolbar_PushLogoToWeb")
            try FloatingToolbar_PushLogoToWeb()
            catch {
            }
        if FuncExists("FloatingToolbar_RequestWebRevealSafe")
            try FloatingToolbar_RequestWebRevealSafe()
            catch {
            }
        else if FuncExists("FloatingToolbar_RequestWebReveal")
            try FloatingToolbar_RequestWebReveal()
            catch {
            }
    }
    if (g_FTB_WV2_Ready && g_FTB_WV2_FrameReady) && FuncExists("FloatingToolbarWails_RegisterExternalReady")
        try FloatingToolbarWails_RegisterExternalReady()
        catch {
        }
    Nmer_HybridManualProbeLog("recover_ftb_after_stress wv2=" . (IsObject(g_FTB_WV2) ? 1 : 0)
        . " ready=" . (g_FTB_WV2_Ready ? 1 : 0) . " frame=" . (g_FTB_WV2_FrameReady ? 1 : 0)
        . " waitingReveal=" . (g_FTB_WaitingUiFinishedReveal ? 1 : 0))
}

Nmer_HybridSignoffInjectUiCycleRun(probeId, rounds, pauseMs) {
    res := Nmer_HybridRunUiCycle(rounds, pauseMs)
    pass := !!res.Get("pass", false)
    Nmer_HybridSignoffWriteInjectResult(probeId, true, pass, pass ? "UI_CYCLE_OK" : "UI_CYCLE_FAIL",
        "rounds=" . res.Get("okRounds", 0) . "/" . res.Get("rounds", rounds), res)
    try Nmer_HybridSignoffRecoverFtbAfterStress()
    catch {
    }
}

Nmer_HybridSignoffHandleInjectPayload(payload) {
    if !(payload is Map)
        return false
    typ := StrLower(Trim(String(payload.Get("type", ""))))
    if (typ = "")
        return false
    signoffTypes := Map(
        "hybrid_probe_wake", true,
        "hybrid_signoff_ping", true,
        "hybrid_signoff_ensure_ftb", true,
        "hybrid_signoff_ui_cycle", true,
        "cp_perf_capture", true
    )
    if !signoffTypes.Has(typ)
        return false
    if FuncExists("FloatingToolbarWails_EnsureInjectPump")
        try FloatingToolbarWails_EnsureInjectPump()
    if FuncExists("Nmer_HybridManualProbeEnsure")
        try Nmer_HybridManualProbeEnsure()
    probeId := Trim(String(payload.Get("probeId", "")))
    if (probeId = "")
        probeId := "inject-" . typ . "-" . A_TickCount
    switch typ {
        case "hybrid_probe_wake":
            Nmer_HybridSignoffWriteInjectResult(probeId, true, true, "PROBE_WAKE_OK", "inject_pump_on")
            return true
        case "hybrid_signoff_ping":
            Nmer_HybridSignoffWriteInjectResult(probeId, true, true, "PING_OK", "inject_ipc_active")
            return true
        case "hybrid_signoff_ensure_ftb":
            ok := false
            detail := ""
            if FuncExists("Nmer_HybridManualProbeEnsureFtb") {
                Nmer_HybridManualProbeEnsureFtb(probeId)
                paths := Nmer_HybridManualProbePaths()
                if FileExist(paths["res"]) {
                    try {
                        root := Jxon_Load(FileRead(paths["res"], "UTF-8"))
                        if (root is Map) {
                            ok := !!root.Get("pass", false)
                            detail := String(root.Get("detail", ""))
                            code := String(root.Get("code", ok ? "FTB_ENSURE_OK" : "FTB_ENSURE_FAIL"))
                            Nmer_HybridSignoffWriteInjectResult(probeId, true, ok, code, detail)
                            return true
                        }
                    } catch {
                    }
                }
            }
            Nmer_HybridSignoffWriteInjectResult(probeId, true, ok, ok ? "FTB_ENSURE_OK" : "FTB_ENSURE_FAIL", detail)
            return true
        case "hybrid_signoff_ui_cycle":
            rounds := Integer(payload.Get("rounds", 10))
            pauseMs := Integer(payload.Get("pauseMs", 450))
            Nmer_HybridSignoffWriteInjectResult(probeId, true, false, "UI_CYCLE_PENDING", "started")
            SetTimer(Nmer_HybridSignoffInjectUiCycleRun.Bind(probeId, rounds, pauseMs), -40)
            return true
        case "cp_perf_capture":
            mode := payload.Has("mode") ? StrLower(Trim(String(payload.Get("mode", "")))) : "synthetic_turbo"
            Nmer_HybridSignoffWriteInjectResult(probeId, true, false, "CP_PERF_PENDING", "started mode=" . mode)
            SetTimer(Nmer_CpPerfCaptureInjectRun.Bind(probeId, mode), -40)
            return true
    }
    return false
}

Nmer_CpPerfCaptureInjectRun(probeId, mode := "synthetic_turbo") {
    if !FuncExists("Nmer_CpPerfProbeRunCapture") {
        Nmer_HybridSignoffWriteInjectResult(probeId, true, false, "CP_PERF_FAIL", "perf_probe_module_missing")
        return
    }
    try {
        if (mode = "manual_equivalent") && FuncExists("Nmer_CpPerfProbeRunManualEquivalentCapture")
            info := Nmer_CpPerfProbeRunManualEquivalentCapture()
        else
            info := Nmer_CpPerfProbeRunCapture(false)
    }
    catch as errCap {
        Nmer_HybridSignoffWriteInjectResult(probeId, true, false, "CP_PERF_FAIL", SubStr(String(errCap.Message), 1, 160))
        return
    }
    ok := !!info.Get("pass", false)
    Nmer_HybridSignoffWriteInjectResult(probeId, true, ok, String(info.Get("code", "CP_PERF_FAIL")),
        String(info.Get("detail", "")), info)
}

Nmer_WailsBridgeDrainInjectToFtb(*) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady
    if !FuncExists("Nmer_WailsBridgeDrainShellFtbInject")
        return 0
    payloads := []
    try payloads := Nmer_WailsBridgeDrainShellFtbInject()
    catch {
        return 0
    }
    if (payloads.Length = 0)
        return 0
    wvReady := IsObject(g_FTB_WV2) && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady
    delivered := 0
    for _, payload in payloads {
        if !(payload is Map)
            continue
        handled := false
        if FuncExists("Nmer_HybridSignoffHandleInjectPayload") && FuncExists("Nmer_HybridSignoffIsActive") && Nmer_HybridSignoffIsActive() {
            try handled := Nmer_HybridSignoffHandleInjectPayload(payload)
            catch {
            }
        }
        if handled
            continue
        typ := String(payload.Get("type", ""))
        if (typ = "host_palette_agent_stream") && FuncExists("FloatingToolbar_StartPaletteAgentStream") {
            try {
                if FloatingToolbar_StartPaletteAgentStream(payload) {
                    delivered += 1
                    continue
                }
            } catch {
            }
        }
        if !wvReady
            continue
        try {
            if FuncExists("WebView_QueuePayload")
                WebView_QueuePayload(g_FTB_WV2, payload)
            else
                g_FTB_WV2.PostWebMessageAsJson(Jxon_Dump(payload))
            delivered += 1
        } catch {
        }
    }
    return delivered
}

Nmer_HybridSignoffDrainInjectQueue(*) {
    if !Nmer_HybridSignoffIsActive()
        return
    if FuncExists("FloatingToolbarWails_EnsureInjectPump")
        try FloatingToolbarWails_EnsureInjectPump()
    if FuncExists("Nmer_WailsBridgeDrainInjectToFtb")
        try Nmer_WailsBridgeDrainInjectToFtb()
        catch {
        }
}

Nmer_HybridManualProbeLog(line) {
    paths := Nmer_HybridManualProbePaths()
    try FileAppend("[" . A_Now . "] " . String(line) . "`n", paths["log"], "UTF-8")
    catch {
    }
}

Nmer_HybridManualProbeWriteResult(id, ok, pass, code, detail := "", extra := 0) {
    paths := Nmer_HybridManualProbePaths()
    body := Map(
        "id", String(id),
        "ok", !!ok,
        "pass", !!pass,
        "code", String(code),
        "detail", String(detail),
        "finishedAt", A_Now
    )
    if (extra is Map) {
        for k, v in extra
            body[String(k)] := v
    }
    try {
        if FileExist(paths["req"])
            FileDelete(paths["req"])
    } catch {
    }
    try FileAppend(Jxon_Dump(body), paths["res"], "UTF-8")
    catch {
    }
}

Nmer_HybridManualProbePoll(*) {
    if FuncExists("Nmer_HybridSignoffDrainInjectQueue")
        try Nmer_HybridSignoffDrainInjectQueue()
    paths := Nmer_HybridManualProbePaths()
    reqPath := paths["req"]
    if !FileExist(reqPath)
        return
    Nmer_HybridManualProbeLog("poll_hit req=" . reqPath)
    raw := ""
    try raw := FileRead(reqPath, "UTF-8")
    catch as errRead {
        Nmer_HybridManualProbeLog("read_fail " . errRead.Message)
        return
    }
    if (SubStr(raw, 1, 1) = Chr(0xFEFF))
        raw := SubStr(raw, 2)
    raw := Trim(raw)
    if (raw = "" || StrLen(raw) > 131072) {
        Nmer_HybridManualProbeWriteResult("", false, false, "PROBE_JSON_INVALID", "empty_or_oversize")
        try FileDelete(reqPath)
        catch {
        }
        return
    }
    if (SubStr(raw, 1, 1) != "{" && SubStr(raw, 1, 1) != "[") {
        Nmer_HybridManualProbeWriteResult("", false, false, "PROBE_JSON_INVALID", "not_json_object")
        try FileDelete(reqPath)
        catch {
        }
        return
    }
    root := Map()
    try root := Jxon_Load(raw)
    catch as errJson {
        Nmer_HybridManualProbeWriteResult("", false, false, "PROBE_JSON_INVALID", SubStr(String(errJson.Message), 1, 120))
        try FileDelete(reqPath)
        catch {
        }
        return
    }
    try FileDelete(reqPath)
    catch {
    }
    if !(root is Map) {
        Nmer_HybridManualProbeWriteResult("", false, false, "PROBE_JSON_INVALID", "expected object")
        return
    }
    id := Trim(String(root.Get("id", "")))
    action := StrLower(Trim(String(root.Get("action", ""))))
    switch action {
        case "ping":
            Nmer_HybridManualProbeWriteResult(id, true, true, "PING_OK", "probe_ipc_active")
        case "ensure_ftb":
            Nmer_HybridManualProbeEnsureFtb(id)
        case "agent_hello":
            Nmer_HybridManualProbeAgentHello(id, root)
        case "ui_cycle":
            Nmer_HybridManualProbeUiCycle(id, root)
        default:
            Nmer_HybridManualProbeWriteResult(id, false, false, "PROBE_UNKNOWN_ACTION", action)
    }
}

Nmer_HybridManualProbeAgentHello(id, root) {
    q := Trim(String(root.Get("query", "hello")))
    if (q = "")
        q := "hello"
    prov := Trim(String(root.Get("provider", "openclaw")))
    if (prov = "")
        prov := "openclaw"
    if !FuncExists("CommandPalette_AgentSubmit") {
        Nmer_HybridManualProbeWriteResult(id, false, false, "AGENT_SUBMIT_MISSING", "orchestrator not loaded")
        return
    }
    msg := Map("type", "palette_agent_submit", "text", q, "query", q, "provider", prov, "kind", "new")
    ret := Map()
    try ret := CommandPalette_AgentSubmit(msg)
    catch as errSubmit {
        Nmer_HybridManualProbeWriteResult(id, false, false, "AGENT_SUBMIT_ERR", errSubmit.Message)
        return
    }
    if !(ret is Map) || !ret.Get("ok", false) {
        Nmer_HybridManualProbeWriteResult(id, false, false, "AGENT_SUBMIT_FAIL", "submit returned not ok")
        return
    }
    cid := String(ret.Get("cardId", ""))
    rid := String(ret.Get("reqId", ""))
    timeoutMs := Integer(root.Get("timeoutMs", 45000))
    if (timeoutMs < 5000)
        timeoutMs := 5000
    if (timeoutMs > 120000)
        timeoutMs := 120000
    SetTimer(Nmer_HybridManualProbeAgentHelloWait.Bind(id, cid, rid, timeoutMs, A_TickCount), -1200)
}

Nmer_HybridManualProbeAgentHelloWait(id, cardId, reqId, timeoutMs, startTick) {
    cid := Trim(String(cardId))
    rid := Trim(String(reqId))
    elapsed := A_TickCount - Integer(startTick)
    bad := []
    for pat in ["deliver_ready_timeout", "waiting FTB shell", "dispatch_exhausted", "BRIDGE_FTB_NOT_READY"] {
        if Nmer_HybridManualProbeLogHas(rid, pat)
            bad.Push(pat)
    }
    if (bad.Length > 0) {
        Nmer_HybridManualProbeWriteResult(id, true, false, "HELLO_FAIL_LOG", bad[1], Map(
            "cardId", cid, "reqId", rid, "errors", bad
        ))
        return
    }
    dispatched := Nmer_HybridManualProbeLogHas(rid, "dispatch_ai")
        || Nmer_HybridManualProbeLogHas(rid, "agent_dispatch")
        || Nmer_HybridManualProbeLogHas(rid, "adapter_ok")
        || Nmer_HybridManualProbeLogHas(rid, "adapter_fail")
    cardOk := false
    if FuncExists("CommandPalette_AgentGetCard") && (cid != "") {
        card := CommandPalette_AgentGetCard(cid)
        if (card is Map) {
            if card.Get("streamDispatched", false)
                cardOk := true
            ans := Trim(String(card.Get("rawAnswer", "")))
            if (ans != "")
                cardOk := true
            if Trim(String(card.Get("error", ""))) != ""
                bad.Push(String(card.Get("error", "")))
        }
    }
    if (bad.Length > 0) {
        Nmer_HybridManualProbeWriteResult(id, true, false, "HELLO_FAIL_CARD", bad[1], Map("cardId", cid, "reqId", rid))
        return
    }
    if (dispatched || cardOk) {
        Nmer_HybridManualProbeWriteResult(id, true, true, "HELLO_OK", "dispatch_or_answer", Map("cardId", cid, "reqId", rid))
        return
    }
    if (elapsed >= timeoutMs) {
        Nmer_HybridManualProbeWriteResult(id, true, false, "HELLO_TIMEOUT", "no dispatch within " . timeoutMs . "ms", Map(
            "cardId", cid, "reqId", rid, "elapsedMs", elapsed
        ))
        return
    }
    SetTimer(Nmer_HybridManualProbeAgentHelloWait.Bind(id, cid, rid, timeoutMs, startTick), -900)
}

Nmer_HybridManualProbeLogHas(needle, pattern) {
    needle := Trim(String(needle))
    pattern := Trim(String(pattern))
    if (needle = "" || pattern = "")
        return false
    logs := []
    if FuncExists("Nmer_DebugPath") {
        logs.Push(Nmer_DebugPath("cmdpal_agent_wire.log"))
        logs.Push(Nmer_DebugPath("command_palette_ai.log"))
    } else {
        logs.Push(A_ScriptDir . "\Cache\debug\cmdpal_agent_wire.log")
        logs.Push(A_ScriptDir . "\Cache\debug\command_palette_ai.log")
    }
    for path in logs {
        if !FileExist(path)
            continue
        try {
            txt := FileRead(path, "UTF-8")
            if !InStr(txt, needle)
                continue
            loop Parse, txt, "`n", "`r" {
                line := Trim(A_LoopField)
                if (line = "")
                    continue
                if InStr(line, needle) && InStr(line, pattern)
                    return true
            }
        } catch {
        }
    }
    return false
}

Nmer_HybridManualProbeEnsureFtb(id) {
    ok := false
    detail := ""
    if FuncExists("FloatingToolbarWails_EnsureHybridBridge")
        try ok := !!FloatingToolbarWails_EnsureHybridBridge()
        catch {
        }
    if FuncExists("FloatingToolbarWails_RegisterExternalFtb")
        try FloatingToolbarWails_RegisterExternalFtb("signoff_baseline")
        catch {
        }
    if FuncExists("ShowFloatingToolbar")
        try ok := !!ShowFloatingToolbar() || ok
        catch {
        }
    vis := false
    mode := ""
    if FuncExists("Nmer_WailsBridgeGetShellFtbStatus") {
        try {
            st := Nmer_WailsBridgeGetShellFtbStatus()
            if (st is Map) {
                vis := !!st.Get("visible", false)
                mode := String(st.Get("presentationMode", ""))
            }
        } catch {
        }
    }
    if (mode = "external" || vis)
        ok := true
    detail := "visible=" . (vis ? 1 : 0) . " mode=" . mode
    Nmer_HybridManualProbeWriteResult(id, true, ok, ok ? "FTB_ENSURE_OK" : "FTB_ENSURE_FAIL", detail)
}

Nmer_HybridManualProbeUiCycle(id, root) {
    rounds := Integer(root.Get("rounds", 10))
    pauseMs := Integer(root.Get("pauseMs", 450))
    res := Nmer_HybridRunUiCycle(rounds, pauseMs)
    if res.Has("errors") && (res["errors"].Length > 0) && (res["errors"][1] = "SURFACE_INTENT_MISSING") {
        Nmer_HybridManualProbeWriteResult(id, false, false, "SURFACE_INTENT_MISSING", "SurfaceIntent router not loaded")
        return
    }
    pass := !!res.Get("pass", false)
    Nmer_HybridManualProbeWriteResult(id, true, pass, pass ? "UI_CYCLE_OK" : "UI_CYCLE_FAIL",
        "rounds=" . res.Get("okRounds", 0) . "/" . res.Get("rounds", rounds), res)
    try Nmer_HybridSignoffRecoverFtbAfterStress()
    catch {
    }
}

Nmer_HybridSignoffScheduleEarlyBootstraps(*) {
    if FuncExists("Nmer_HybridSignoffStartupEnsure")
        SetTimer(Nmer_HybridSignoffStartupEnsure, -600)
    if FuncExists("Nmer_HybridSignoffBootstrapEnsure") {
        SetTimer(Nmer_HybridSignoffBootstrapEnsure, -3200)
        SetTimer(Nmer_HybridSignoffBootstrapEnsure, -11000)
    }
    if FuncExists("Nmer_AutoStartWailsBridge")
        SetTimer(Nmer_AutoStartWailsBridge, -1800)
}

SetTimer(Nmer_HybridSignoffScheduleEarlyBootstraps, -1)
