; NmerHealthSummary.ahk — 健康快照读模型（只观测、不修复）
; 禁止在本模块调用 NmerService_Ensure、SurfaceIntent_*、侧车拉起等写模型 API。

global g_NmerHealth_LastSnapshot := 0

Nmer_HealthSnapshotPath(*) {
    if FuncExists("Nmer_DebugPath")
        return Nmer_DebugPath("health_summary.json")
    return A_ScriptDir . "\Cache\debug\health_summary.json"
}

Nmer_HealthSnapshot_ServiceLabel(name) {
    switch StrLower(Trim(String(name))) {
        case "searchcore": return "SearchCenterCore"
        case "hub": return "nmer-hub"
        case "ttyd": return "ttyd"
        case "everything": return "Everything"
    }
    return String(name)
}

Nmer_BuildHealthSnapshot(trigger := "user_refresh") {
    trig := Trim(String(trigger))
    if (trig = "")
        trig := "user_refresh"

    services := []
    healthyCount := 0
    totalCount := 0
    if FuncExists("NmerService_Names") {
        for name in NmerService_Names() {
            totalCount += 1
            present := false
            healthy := false
            try {
                if FuncExists("NmerService_ProcessPresent")
                    present := !!NmerService_ProcessPresent(name)
            } catch as _e1 {
                NmerCatch(A_ThisFunc, _e1)
            }
            try {
                if FuncExists("NmerService_IsHealthy")
                    healthy := !!NmerService_IsHealthy(name)
            } catch as _e2 {
                NmerCatch(A_ThisFunc, _e2)
            }
            if healthy
                healthyCount += 1
            services.Push(Map(
                "name", String(name),
                "label", Nmer_HealthSnapshot_ServiceLabel(name),
                "processPresent", present,
                "healthy", healthy
            ))
        }
    }

    snap := Map(
        "generatedAt", FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"),
        "generatedAtTick", A_TickCount,
        "trigger", trig,
        "readModel", true,
        "services", services,
        "servicesHealthy", healthyCount,
        "servicesTotal", totalCount,
        "surfaces", Nmer_HealthSnapshot_LoadSurfaces(),
        "runtime", Nmer_HealthSnapshot_BuildRuntime(),
        "logs", Nmer_HealthSnapshot_BuildLogsMeta(),
        "summary", Map(
            "healthyCount", healthyCount,
            "totalCount", totalCount,
            "label", healthyCount . "/" . totalCount . " 侧车健康"
        )
    )

    global g_NmerHealth_LastSnapshot
    g_NmerHealth_LastSnapshot := snap

    if FuncExists("NMER_Log") {
        try NMER_Log("health", "snapshot_built", "trigger=" . trig . " ok=" . healthyCount . "/" . totalCount)
        catch as _e3 {
            NmerCatch(A_ThisFunc, _e3)
        }
    }
    return snap
}

Nmer_HealthSnapshot_BuildRuntime() {
    rt := Map("ahkVersion", A_AhkVersion, "uptimeMs", A_TickCount)
    try {
        if FuncExists("Nmer_SurfaceManagerFlags") {
            flags := Nmer_SurfaceManagerFlags()
            sm := Map()
            if (flags is Map) {
                for key, val in flags
                    sm[String(key)] := val
            }
            rt["surfaceManagerFlags"] := sm
        }
    } catch as _e1 {
        NmerCatch(A_ThisFunc, _e1)
    }
    try {
        global UseWebViewSettings, g_ConfigPreferWebViewOnly
        rt["useWebViewSettings"] := !!UseWebViewSettings
        rt["configPreferWebViewOnly"] := !!g_ConfigPreferWebViewOnly
    } catch as _e2 {
        NmerCatch(A_ThisFunc, _e2)
    }
    return rt
}

Nmer_HealthSnapshot_BuildLogsMeta() {
    dbgDir := A_ScriptDir . "\Cache\debug"
    if FuncExists("Nmer_DebugDir")
        dbgDir := Nmer_DebugDir()
    return Map(
        "debugDir", dbgDir,
        "snapshotPath", Nmer_HealthSnapshotPath(),
        "surfaceRegistryPath", Nmer_HealthSnapshot_SurfaceRegistryPath()
    )
}

Nmer_HealthSnapshot_SurfaceRegistryPath(*) {
    if FuncExists("SurfaceManager_SnapshotPath")
        return SurfaceManager_SnapshotPath()
    if FuncExists("Nmer_DebugPath")
        return Nmer_DebugPath("surface_registry_snapshot.json")
    return A_ScriptDir . "\Cache\debug\surface_registry_snapshot.json"
}

Nmer_HealthSnapshot_LoadSurfaces() {
    arr := []
    path := Nmer_HealthSnapshot_SurfaceRegistryPath()
    if !FileExist(path)
        return arr
    try {
        raw := FileRead(path, "UTF-8")
        if (raw = "")
            return arr
        if !FuncExists("Jxon_Load")
            return arr
        loaded := Jxon_Load(raw)
        if !(loaded is Array)
            return arr
        for item in loaded
            arr.Push(Nmer_HealthSnapshot_SlimSurface(item))
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
    return arr
}

Nmer_HealthSnapshot_SlimSurface(item) {
    row := Map()
    if !(item is Map) {
        if (item is Object) {
            try {
                for key in ["id", "state", "role", "runtime", "lastMode"] {
                    if item.HasProp(key)
                        row[key] := item.%key%
                }
            } catch {
            }
        }
        return row
    }
    for key in ["id", "state", "role", "runtime", "lastMode"] {
        if item.Has(key)
            row[key] := item[key]
    }
    return row
}

Nmer_WriteHealthSnapshotJson(snap := 0) {
    if !(snap is Map) || snap.Count = 0 {
        global g_NmerHealth_LastSnapshot
        if (g_NmerHealth_LastSnapshot is Map) && g_NmerHealth_LastSnapshot.Count
            snap := g_NmerHealth_LastSnapshot
        else
            return false
    }
    path := Nmer_HealthSnapshotPath()
    dir := ""
    if RegExMatch(path, "^(.*)\\[^\\]+$", &m)
        dir := m[1]
    if (dir != "") {
        try DirCreate(dir)
        catch as _e1 {
            NmerCatch(A_ThisFunc, _e1)
        }
    }
    json := ""
    try {
        if FuncExists("Jxon_Dump")
            json := Jxon_Dump(snap)
        else
            return false
    } catch as _e2 {
        NmerCatch(A_ThisFunc, _e2)
        return false
    }
    if (json = "")
        return false
    try FileDelete(path)
    catch as _e3 {
        NmerCatch(A_ThisFunc, _e3)
    }
    try {
        FileAppend(json, path, "UTF-8")
        return true
    } catch as _e4 {
        NmerCatch(A_ThisFunc, _e4)
        return false
    }
}

Nmer_ReadHealthSnapshotJson(*) {
    path := Nmer_HealthSnapshotPath()
    if !FileExist(path)
        return Map()
    try {
        raw := FileRead(path, "UTF-8")
        if (raw = "")
            return Map()
        if FuncExists("Jxon_Load")
            return Jxon_Load(raw)
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
    return Map()
}

Nmer_CollectHealthSnapshot(trigger := "user_refresh") {
    snap := Nmer_BuildHealthSnapshot(trigger)
    Nmer_WriteHealthSnapshotJson(snap)
    if FuncExists("Nmer_Telemetry_Record") {
        try Nmer_Telemetry_Record("health", "health_snapshot_result", true, Map("trigger", String(trigger)))
        catch as _e {
            NmerCatch(A_ThisFunc, _e)
        }
    }
    return snap
}

Nmer_HealthSnapshotForWeb(snap := 0) {
    if (snap is Map) && snap.Count
        return snap
    global g_NmerHealth_LastSnapshot
    if (g_NmerHealth_LastSnapshot is Map) && g_NmerHealth_LastSnapshot.Count
        return g_NmerHealth_LastSnapshot
    cached := Nmer_ReadHealthSnapshotJson()
    if (cached is Map) && cached.Count
        return cached
    return Map()
}

Nmer_ShowHealthSnapshotTray(trigger := "tray_refresh") {
    snap := Nmer_CollectHealthSnapshot(trigger)
    healthy := snap.Has("servicesHealthy") ? snap["servicesHealthy"] : 0
    total := snap.Has("servicesTotal") ? snap["servicesTotal"] : 0
    lines := "侧车 " . healthy . "/" . total . " 健康（只读快照）"
    if (snap.Has("services") && snap["services"] is Array) {
        for svc in snap["services"] {
            if !(svc is Map)
                continue
            label := svc.Has("label") ? String(svc["label"]) : String(svc.Get("name", ""))
            st := svc.Get("healthy", false) ? "OK" : (svc.Get("processPresent", false) ? "异常" : "未运行")
            lines .= "`n· " . label . ": " . st
        }
    }
    surfN := 0
    if snap.Has("surfaces") && snap["surfaces"] is Array
        surfN := snap["surfaces"].Length
    lines .= "`nSurface 登记: " . surfN . " 项"
    lines .= "`n`n详情：设置 → 系统 → 高级"
    try TrayTip("系统健康", lines, "Iconi 4")
    catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
}

Nmer_OpenHealthSettingsPanel(*) {
    try {
        if FuncExists("SurfaceIntent_OpenConfig")
            return SurfaceIntent_OpenConfig(Map("triggerSource", "tray_health", "reason", "open_health_settings", "navigateTab", "advanced"))
    } catch as _e1 {
        NmerCatch(A_ThisFunc, _e1)
    }
    global g_ConfigWebView_OneShotDefaultTab
    g_ConfigWebView_OneShotDefaultTab := "advanced"
    try {
        if FuncExists("SurfaceIntent_Open") {
            SurfaceIntent_Open("config_webview")
            return true
        }
    } catch as _e2 {
        NmerCatch(A_ThisFunc, _e2)
    }
    try {
        if FuncExists("ShowConfigGUI_Safe") {
            ShowConfigGUI_Safe()
            return true
        }
    } catch as _e3 {
        NmerCatch(A_ThisFunc, _e3)
    }
    try {
        if FuncExists("ShowConfigGUI") {
            ShowConfigGUI()
            return true
        }
    } catch as _e4 {
        NmerCatch(A_ThisFunc, _e4)
    }
    return false
}
