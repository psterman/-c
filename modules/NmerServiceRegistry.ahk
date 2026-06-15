; NmerServiceRegistry.ahk — 后台侧车服务统一 Ensure / Healthy 入口（由 ToolsPaths #Include）

NmerService_Names() {
    return ["searchcore", "hub", "ttyd", "everything"]
}

NmerService_IsHealthy(name) {
    n := StrLower(Trim(String(name)))
    switch n {
        case "searchcore":
            if FuncExists("SearchCore_IsHealthy")
                return SearchCore_IsHealthy()
            if FuncExists("Nmer_SearchCenterCoreHealthy")
                return Nmer_SearchCenterCoreHealthy()
            return false
        case "hub":
            if FuncExists("Nmer_WailsBridgeHealthy")
                return Nmer_WailsBridgeHealthy()
            return false
        case "ttyd":
            if FuncExists("NiumaTtyd_IsHttpReady")
                return NiumaTtyd_IsHttpReady(800)
            if FuncExists("NiumaTtyd_IsPortListening")
                return NiumaTtyd_IsPortListening()
            return false
        case "everything":
            if FuncExists("GetEverythingPID")
                return GetEverythingPID() > 0
            return false
    }
    return false
}

NmerService_ProcessPresent(name) {
    n := StrLower(Trim(String(name)))
    switch n {
        case "searchcore":
            if FuncExists("SearchCore_ProcessPresent")
                return SearchCore_ProcessPresent()
            return ProcessExist("SearchCenterCore.exe") > 0
        case "hub":
            if FuncExists("Nmer_WailsBridge_ProcessExists")
                return Nmer_WailsBridge_ProcessExists()
            return (ProcessExist("nmer-hub.exe") > 0) || (ProcessExist("nmer-wails.exe") > 0)
        case "ttyd":
            if FuncExists("NiumaTtyd_GetListeningPid")
                return NiumaTtyd_GetListeningPid() > 0
            return ProcessExist("ttyd.exe") > 0
        case "everything":
            if FuncExists("GetEverythingPID")
                return GetEverythingPID() > 0
            return ProcessExist("Everything64.exe") > 0
    }
    return false
}

NmerService_Ensure(name, caller := "service_registry", forceRestart := false) {
    n := StrLower(Trim(String(name)))
    switch n {
        case "searchcore":
            if FuncExists("SearchCore_EnsureStatus")
                return SearchCore_EnsureStatus(forceRestart, caller)
            if FuncExists("Nmer_StartSearchCenterCoreStatus")
                return Nmer_StartSearchCenterCoreStatus(forceRestart, caller)
            return Map("status", "unsupported")
        case "hub":
            if FuncExists("Nmer_StartWailsBridge")
                return Nmer_StartWailsBridge(forceRestart)
            return Map("status", "unsupported")
        case "ttyd":
            if FuncExists("NiumaTtyd_EnsureReady")
                return Map("status", NiumaTtyd_EnsureReady(15000) ? "healthy" : "failed")
            return Map("status", "unsupported")
        case "everything":
            if FuncExists("InitEverythingService") {
                InitEverythingService()
                return Map("status", NmerService_IsHealthy("everything") ? "healthy" : "started")
            }
            if FuncExists("TryStartEverything") {
                TryStartEverything()
                return Map("status", NmerService_IsHealthy("everything") ? "healthy" : "started")
            }
            return Map("status", "unsupported")
    }
    return Map("status", "unknown_service")
}

NmerService_AutoStartSearchCore(*) {
    if FuncExists("Nmer_AutoStartSearchCenterCore")
        Nmer_AutoStartSearchCenterCore()
}

NmerService_AutoStartHub(*) {
    if FuncExists("Nmer_AutoStartWailsBridge")
        Nmer_AutoStartWailsBridge()
}
