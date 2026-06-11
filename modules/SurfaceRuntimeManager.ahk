; SurfaceRuntimeManager.ahk
; Phase 0 shadow registry: observe lifecycle without taking control.

global g_SurfaceRuntime_Registry := Map()
global g_SurfaceRuntime_Bootstrapped := false
global g_SurfaceRuntime_EventSeq := 0
global g_SurfaceRuntime_RequestSeq := 0
global g_SurfaceRuntime_LastRequestBySurface := Map()
global g_SurfaceRuntime_LastRequestMeta := Map()
global g_SurfaceRuntime_LastBudgetSignature := ""

SurfaceManager_IsObservationEnabled(*) {
    try {
        if FuncExists("Nmer_SurfaceManagerEnabled") && Nmer_SurfaceManagerEnabled()
            return true
        if FuncExists("Nmer_SurfaceManagerShadowMode") && Nmer_SurfaceManagerShadowMode()
            return true
    } catch {
    }
    return false
}

SurfaceManager_LogPath(*) {
    if FuncExists("Nmer_DebugPath")
        return Nmer_DebugPath("surface_runtime.ndjson")
    return A_ScriptDir . "\Cache\debug\surface_runtime.ndjson"
}

SurfaceManager_SnapshotPath(*) {
    if FuncExists("Nmer_DebugPath")
        return Nmer_DebugPath("surface_registry_snapshot.json")
    return A_ScriptDir . "\Cache\debug\surface_registry_snapshot.json"
}

SurfaceManager_CurrentMode(*) {
    try {
        global AppearanceActivationMode
        if FuncExists("NormalizeAppearanceActivationMode")
            return NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar")
        return IsSet(AppearanceActivationMode) ? String(AppearanceActivationMode) : "toolbar"
    } catch {
        return "toolbar"
    }
}

SurfaceManager_EnsureBootstrap(*) {
    global g_SurfaceRuntime_Bootstrapped
    if g_SurfaceRuntime_Bootstrapped
        return
    g_SurfaceRuntime_Bootstrapped := true
    SurfaceManager_RegisterSurface("floating_toolbar", "resident", "webview", Map("area", "ftb"))
    SurfaceManager_RegisterSurface("command_palette", "primary", "webview", Map("area", "cp"))
    SurfaceManager_RegisterSurface("clipboard_panel", "secondary", "webview", Map("area", "clipboard"))
    SurfaceManager_RegisterSurface("prompt_quick_pad", "secondary", "webview", Map("area", "prompt"))
    SurfaceManager_RegisterSurface("search_center", "primary", "webview", Map("area", "search"))
    SurfaceManager_RegisterSurface("virtual_keyboard", "secondary", "webview", Map("area", "vk"))
    SurfaceManager_RegisterSurface("config_webview", "secondary", "webview", Map("area", "config"))
    SurfaceManager_RegisterSurface("floating_bubble", "resident", "native", Map("area", "bubble"))
    SurfaceManager_RegisterSurface("drag_hole_overlay", "overlay", "native", Map("area", "hole"))
    SurfaceManager_RegisterSurface("screenshot_editor", "overlay", "native", Map("area", "screenshot"))
}

SurfaceManager_MapWarmupFuncToSurface(name) {
    n := Trim(String(name))
    switch n {
        case "CP_Init":
            return "clipboard_panel"
        case "PQP_Init":
            return "prompt_quick_pad"
        case "SCWV_Init":
            return "search_center"
        case "VK_EnsureInit":
            return "virtual_keyboard"
        case "_WarmupConfigWebView":
            return "config_webview"
        case "CommandPalette_Init":
            return "command_palette"
        case "InitFloatingToolbar":
            return "floating_toolbar"
        default:
            return ""
    }
}

SurfaceManager_CallName(callable) {
    try {
        if (callable is Func)
            return callable.Name
    } catch {
    }
    try {
        if (callable is BoundFunc) {
            try {
                if IsObject(callable.Func)
                    return callable.Func.Name
            } catch {
            }
            return callable.Name
        }
    } catch {
    }
    try return Type(callable)
    catch
        return ""
}

SurfaceManager_SimpleClone(value) {
    if !IsObject(value) {
        t := ""
        try t := Type(value)
        catch {
        }
        if (t = "Integer" || t = "Float")
            return value + 0.0
        return value
    }
    if (value is Array) {
        out := []
        for _, item in value
            out.Push(SurfaceManager_SimpleClone(item))
        return out
    }
    if (value is Map) {
        out := Map()
        for key, item in value
            out[String(key)] := SurfaceManager_SimpleClone(item)
        return out
    }
    try return String(value)
    catch
        return Type(value)
}

SurfaceManager_RecordEvent(eventType, surfaceId := "", meta := 0) {
    global g_SurfaceRuntime_EventSeq
    if !SurfaceManager_IsObservationEnabled()
        return
    SurfaceManager_EnsureBootstrap()
    g_SurfaceRuntime_EventSeq += 1
    payload := Map(
        "seq", g_SurfaceRuntime_EventSeq,
        "ts", FormatTime(, "yyyy-MM-dd HH:mm:ss"),
        "tick", A_TickCount,
        "type", String(eventType),
        "surface", String(surfaceId),
        "mode", SurfaceManager_CurrentMode(),
        "shadowMode", FuncExists("Nmer_SurfaceManagerShadowMode") ? !!Nmer_SurfaceManagerShadowMode() : true,
        "managerEnabled", FuncExists("Nmer_SurfaceManagerEnabled") ? !!Nmer_SurfaceManagerEnabled() : false
    )
    try {
        global NMER_TraceSession
        if (IsSet(NMER_TraceSession) && NMER_TraceSession != "")
            payload["traceSession"] := String(NMER_TraceSession)
    } catch {
    }
    if IsObject(meta)
        payload["meta"] := SurfaceManager_SimpleClone(meta)
    else if (meta != 0 && String(meta) != "")
        payload["meta"] := meta
    try {
        path := SurfaceManager_LogPath()
        SplitPath(path, , &dir)
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)
        FileAppend(Jxon_Dump(payload) . "`r`n", path, "UTF-8")
    } catch {
    }
}

SurfaceManager_ShouldShadowOpenClose(*) {
    if !SurfaceManager_IsObservationEnabled()
        return false
    if FuncExists("Nmer_SurfaceManagerInterceptOpenClose") && Nmer_SurfaceManagerInterceptOpenClose()
        return true
    return false
}

SurfaceManager_RequestCoalesceWindowMs(action := "") {
    a := String(action)
    switch a {
        case "open":
            return 800
        case "close":
            return 500
        default:
            return 600
    }
}

SurfaceManager_CanCoalesceRequest(surfaceId, action, metaOut := 0) {
    global g_SurfaceRuntime_LastRequestMeta, g_SurfaceRuntime_Registry
    if !g_SurfaceRuntime_LastRequestMeta.Has(surfaceId)
        return false
    last := g_SurfaceRuntime_LastRequestMeta[surfaceId]
    if !(last is Map)
        return false
    if !last.Has("action") || String(last["action"]) != String(action)
        return false
    if !last.Has("tick")
        return false
    elapsed := A_TickCount - last["tick"]
    if (elapsed < 0)
        return false
    if (elapsed > SurfaceManager_RequestCoalesceWindowMs(action))
        return false
    rec := g_SurfaceRuntime_Registry.Has(surfaceId) ? g_SurfaceRuntime_Registry[surfaceId] : 0
    state := ""
    if (rec is Map) && rec.Has("state")
        state := String(rec["state"])
    a := String(action)
    if (a = "open" && state != "CREATING" && state != "ACTIVE")
        return false
    if (a = "close" && state != "SUSPENDED" && state != "ABSENT")
        return false
    if (metaOut is Map) {
        metaOut["elapsedMs"] := elapsed
        metaOut["state"] := state
        if last.Has("requestId")
            metaOut["requestId"] := String(last["requestId"])
        if last.Has("source")
            metaOut["previousSource"] := String(last["source"])
    }
    return true
}

SurfaceManager_Request(surfaceId, action, source := "", meta := 0) {
    global g_SurfaceRuntime_RequestSeq, g_SurfaceRuntime_LastRequestBySurface, g_SurfaceRuntime_LastRequestMeta
    if !SurfaceManager_ShouldShadowOpenClose()
        return 0
    SurfaceManager_RegisterSurface(surfaceId)
    coalesceMeta := Map()
    if SurfaceManager_CanCoalesceRequest(surfaceId, action, coalesceMeta) {
        payload := Map(
            "action", String(action),
            "source", String(source)
        )
        for key, val in coalesceMeta
            payload[String(key)] := SurfaceManager_SimpleClone(val)
        if (meta is Map) {
            for key, val in meta
                payload[String(key)] := SurfaceManager_SimpleClone(val)
        } else if (meta != 0 && String(meta) != "") {
            payload["detail"] := meta
        }
        SurfaceManager_RecordEvent("request_coalesced", surfaceId, payload)
        return coalesceMeta.Has("requestId") ? coalesceMeta["requestId"] : 0
    }
    g_SurfaceRuntime_RequestSeq += 1
    requestId := String(surfaceId) . "#" . g_SurfaceRuntime_RequestSeq
    payload := Map(
        "requestId", requestId,
        "action", String(action),
        "source", String(source)
    )
    if (meta is Map) {
        for key, val in meta
            payload[String(key)] := SurfaceManager_SimpleClone(val)
    } else if (meta != 0 && String(meta) != "") {
        payload["detail"] := meta
    }
    g_SurfaceRuntime_LastRequestBySurface[surfaceId] := requestId
    g_SurfaceRuntime_LastRequestMeta[surfaceId] := Map(
        "requestId", requestId,
        "action", String(action),
        "source", String(source),
        "tick", A_TickCount
    )
    SurfaceManager_RecordEvent("request", surfaceId, payload)
    return requestId
}

SurfaceManager_ConflictGroupFor(surfaceId) {
    switch String(surfaceId) {
        case "command_palette", "search_center":
            return "primary"
        case "drag_hole_overlay", "screenshot_editor":
            return "overlay"
        case "clipboard_panel", "prompt_quick_pad", "virtual_keyboard", "config_webview":
            return "secondary"
        default:
            return ""
    }
}

SurfaceManager_OverlaySurfaceIds() {
    return ["drag_hole_overlay", "screenshot_editor"]
}

SurfaceManager_PrimarySurfaceIds() {
    return ["command_palette", "search_center"]
}

SurfaceManager_ConflictSurfaces(surfaceId) {
    sid := String(surfaceId)
    group := SurfaceManager_ConflictGroupFor(sid)
    surfaces := []
    if (group = "primary") {
        for _, other in SurfaceManager_PrimarySurfaceIds() {
            if (other != sid)
                surfaces.Push(other)
        }
        for _, other in SurfaceManager_OverlaySurfaceIds()
            surfaces.Push(other)
        return surfaces
    }
    if (group = "overlay") {
        for _, other in SurfaceManager_PrimarySurfaceIds()
            surfaces.Push(other)
        for _, other in SurfaceManager_OverlaySurfaceIds() {
            if (other != sid)
                surfaces.Push(other)
        }
        return surfaces
    }
    if (group = "secondary") {
        for _, other in ["clipboard_panel", "prompt_quick_pad", "virtual_keyboard", "config_webview"] {
            if (other != sid)
                surfaces.Push(other)
        }
    }
    return surfaces
}

SurfaceManager_IsPrimaryHandoff(requester, victim) {
    req := String(requester)
    vic := String(victim)
    if !(req = "command_palette" || req = "search_center")
        return false
    if !(vic = "command_palette" || vic = "search_center")
        return false
    return (req != vic)
}

SurfaceManager_ReasonImpliesDispose(reason) {
    r := String(reason)
    if (r = "primary_handoff" || r = "slot_conflict" || r = "search_preempt")
        return false
    if (r = "budget_pressure" || r = "tray" || r = "dispose" || r = "explicit_dispose")
        return true
    if (InStr(r, "dispose") > 0)
        return true
    return false
}

SurfaceManager_CloseWebViewControl(ctrl) {
    if !IsObject(ctrl)
        return
    try ctrl.IsVisible := false
    catch {
    }
    try ctrl.Close()
    catch {
    }
}

SurfaceManager_DestroyGui(guiObj) {
    if !IsObject(guiObj)
        return
    try guiObj.Destroy()
    catch {
    }
}

SurfaceManager_InvokeOptional(fnName, args*) {
    name := Trim(String(fnName))
    if (name = "" || !FuncExists(name))
        return false
    fn := %name%
    fn.Call(args*)
    return true
}

SurfaceExecutor_Suspend(surfaceId, meta := 0) {
    sid := String(surfaceId)
    reason := SurfaceManager_OpenMetaGet(meta, "reason", "suspend")
    requester := SurfaceManager_OpenMetaGet(meta, "requester", "")
    payload := Map("reason", reason, "requester", requester)
    if (meta is Map) {
        for key, val in meta
            payload[String(key)] := SurfaceManager_SimpleClone(val)
    }
    try {
        switch sid {
            case "command_palette":
                SurfaceManager_InvokeOptional("CommandPalette_Hide")
            case "search_center":
                SurfaceManager_InvokeOptional("SCWV_Hide", false)
            case "clipboard_panel":
                SurfaceManager_InvokeOptional("CP_Hide")
            case "prompt_quick_pad":
                SurfaceManager_InvokeOptional("PQP_Hide")
            case "virtual_keyboard":
                SurfaceManager_InvokeOptional("VK_Hide")
            case "config_webview":
                SurfaceManager_InvokeOptional("ConfigWebView_Close")
            case "floating_toolbar":
                SurfaceManager_InvokeOptional("HideFloatingToolbar")
            case "drag_hole_overlay":
                if FuncExists("GDHO_RequestClose")
                    GDHO_RequestClose("slot_conflict")
                else if FuncExists("GDHO_Stop")
                    GDHO_Stop()
            case "screenshot_editor":
                if FuncExists("CloseScreenshotEditor")
                    CloseScreenshotEditor()
        }
    } catch as err {
        SurfaceManager_RecordEvent("suspend_error", sid, Map("reason", reason, "requester", requester, "message", err.Message))
        return
    }
    if FuncExists("SurfaceManager_ObserveHide")
        try SurfaceManager_ObserveHide(sid, payload)
    SurfaceManager_RecordEvent("suspend", sid, payload)
}

SurfaceExecutor_Dispose(surfaceId, meta := 0) {
    sid := String(surfaceId)
    reason := SurfaceManager_OpenMetaGet(meta, "reason", "dispose")
    requester := SurfaceManager_OpenMetaGet(meta, "requester", "")
    payload := Map("reason", reason, "requester", requester)
    if (meta is Map) {
        for key, val in meta
            payload[String(key)] := SurfaceManager_SimpleClone(val)
    }
    disposed := false
    try {
        switch sid {
            case "command_palette":
                if FuncExists("CommandPaletteRouter_Dispose")
                    CommandPaletteRouter_Dispose(reason)
                else if !SurfaceManager_InvokeOptional("CommandPalette_Dispose", reason)
                    SurfaceManager_InvokeOptional("CommandPalette_Hide")
                disposed := true
            case "search_center":
                if FuncExists("SearchCenterRouter_Dispose")
                    SearchCenterRouter_Dispose(reason)
                else if !SurfaceManager_InvokeOptional("SCWV_Dispose", reason)
                    SurfaceManager_InvokeOptional("SCWV_RequestHardClose", reason)
                disposed := true
            case "clipboard_panel":
                if !SurfaceManager_InvokeOptional("CP_Dispose", reason)
                    SurfaceManager_InvokeOptional("CP_Hide")
                disposed := true
            case "prompt_quick_pad":
                if !SurfaceManager_InvokeOptional("PQP_Dispose", reason)
                    SurfaceManager_InvokeOptional("PQP_Hide")
                disposed := true
            case "virtual_keyboard":
                if !SurfaceManager_InvokeOptional("VK_Dispose", reason)
                    SurfaceManager_InvokeOptional("VK_Hide")
                disposed := true
            case "config_webview":
                if FuncExists("ConfigWebViewRouter_Dispose")
                    ConfigWebViewRouter_Dispose(reason)
                else if !SurfaceManager_InvokeOptional("ConfigWebView_Dispose", reason)
                    SurfaceManager_InvokeOptional("ConfigWebView_Close")
                disposed := true
            case "floating_toolbar":
                if FuncExists("FloatingToolbarRouter_Dispose")
                    FloatingToolbarRouter_Dispose(reason)
                else if !SurfaceManager_InvokeOptional("FloatingToolbar_Dispose", reason)
                    SurfaceManager_InvokeOptional("HideFloatingToolbar")
                disposed := true
            case "drag_hole_overlay":
                if FuncExists("GDHO_Stop")
                    GDHO_Stop()
                disposed := true
            case "screenshot_editor":
                if FuncExists("CloseScreenshotEditor")
                    CloseScreenshotEditor()
                disposed := true
        }
    } catch as err {
        SurfaceManager_RecordEvent("dispose_error", sid, Map("reason", reason, "requester", requester, "message", err.Message))
        return
    }
    if disposed
        SurfaceManager_RecordEvent("dispose", sid, payload)
}

SurfaceManager_HideSurface(surfaceId, reason := "", requester := "") {
    sid := String(surfaceId)
    meta := Map("reason", reason, "requester", requester)
    try {
        if SurfaceManager_ReasonImpliesDispose(reason)
            SurfaceExecutor_Dispose(sid, meta)
        else
            SurfaceExecutor_Suspend(sid, meta)
    } catch as err {
        SurfaceManager_RecordEvent("arbitration_hide_error", sid, Map("reason", reason, "requester", requester, "message", err.Message))
    }
}

SurfaceManager_OpenMetaGet(meta, key, default := "") {
    if !(meta is Map)
        return default
    return meta.Has(key) ? String(meta[key]) : default
}

SurfaceManager_ClassifyOpenContext(surfaceId, source := "", meta := 0) {
    sid := String(surfaceId)
    src := String(source)
    triggerSource := SurfaceManager_OpenMetaGet(meta, "triggerSource")
    reason := SurfaceManager_OpenMetaGet(meta, "reason")
    if (sid = "search_center") {
        if (triggerSource = "search_hotkey" || triggerSource = "clipboard_hotkey")
            return "external_hotkey"
        if (InStr(reason, "unified_open_") = 1 || triggerSource = "clipboard_unified_redirect")
            return "internal_toolbar"
    }
    if (src = "SurfaceIntent_Open") {
        if (reason != "" && (InStr(reason, "toolbar") || InStr(reason, "ftb") || InStr(reason, "cmdpal")
            || InStr(reason, "screenshot") || InStr(reason, "palette_probe") || InStr(reason, "appearance")))
            return "internal_toolbar"
        if (sid = "floating_toolbar" && reason != "")
            return "internal_toolbar"
        return "external_panel"
    }
    if (src = "CommandPalette_Show")
        return "external_panel"
    if (src = "CP_Show" || src = "PQP_Show" || src = "VK_Show" || src = "ShowConfigWebViewGUI")
        return "internal_toolbar"
    return "unknown"
}

SurfaceManager_ShouldEnforceSlotsForRequest(surfaceId, source := "", meta := 0) {
    if !(FuncExists("Nmer_SurfaceManagerEnforceSlots") && Nmer_SurfaceManagerEnforceSlots())
        return false
    sid := String(surfaceId)
    if SurfaceManager_ConflictGroupFor(sid) = ""
        return false
    context := SurfaceManager_ClassifyOpenContext(sid, source, meta)
    if (context = "external_panel" || context = "external_hotkey" || context = "internal_toolbar")
        return true
    return false
}

SurfaceManager_HasActivePrimaryConflict(surfaceId) {
    global g_SurfaceRuntime_Registry
    if !FuncExists("SurfaceManager_ConflictSurfaces")
        return false
    for _, sid in SurfaceManager_ConflictSurfaces(surfaceId) {
        if !g_SurfaceRuntime_Registry.Has(sid)
            continue
        rec := g_SurfaceRuntime_Registry[sid]
        state := (rec is Map) && rec.Has("state") ? String(rec["state"]) : ""
        if (state = "ACTIVE" || state = "CREATING")
            return true
    }
    return false
}

SurfaceManager_BeforeOpen(surfaceId, source := "", meta := 0) {
    global g_SurfaceRuntime_Registry
    if !SurfaceManager_IsObservationEnabled()
        return
    SurfaceManager_RegisterSurface(surfaceId)
    context := SurfaceManager_ClassifyOpenContext(surfaceId, source, meta)
    shouldEnforce := SurfaceManager_ShouldEnforceSlotsForRequest(surfaceId, source, meta)
    conflicts := []
    for _, sid in SurfaceManager_ConflictSurfaces(surfaceId) {
        if !g_SurfaceRuntime_Registry.Has(sid)
            continue
        rec := g_SurfaceRuntime_Registry[sid]
        state := (rec is Map) && rec.Has("state") ? String(rec["state"]) : ""
        if (state = "ACTIVE" || state = "CREATING")
            conflicts.Push(Map("surface", sid, "state", state))
    }
    payload := Map(
        "surface", String(surfaceId),
        "source", String(source),
        "context", context,
        "group", SurfaceManager_ConflictGroupFor(surfaceId),
        "enforceSlots", FuncExists("Nmer_SurfaceManagerEnforceSlots") ? !!Nmer_SurfaceManagerEnforceSlots() : false,
        "shouldEnforce", shouldEnforce ? 1 : 0,
        "conflicts", conflicts
    )
    if (meta is Map) {
        for key, val in meta
            payload[String(key)] := SurfaceManager_SimpleClone(val)
    } else if (meta != 0 && String(meta) != "") {
        payload["detail"] := meta
    }
    SurfaceManager_RecordEvent("open_plan", surfaceId, payload)
    if !shouldEnforce
        return
    skipTxnSlotHide := false
    if (meta is Map) && meta.Has("generationId") && String(meta["generationId"]) != "" {
        ; Transaction 路径下仍须仲裁 CP↔SC 主槽位，否则 budget dispose 会破坏切换。
        if !(context = "external_hotkey" && SurfaceManager_ConflictGroupFor(surfaceId) = "primary")
            skipTxnSlotHide := true
    }
    if skipTxnSlotHide
        return
    for _, item in conflicts
        SurfaceManager_HideSurface(item["surface"], "slot_conflict", surfaceId)
}

SurfaceManager_BudgetPolicy(mode := "") {
    m := String(mode != "" ? mode : SurfaceManager_CurrentMode())
    baseline := SurfaceManager_MeasuredBaseline()
    emptyWv2 := baseline.Has("webview2_count") ? (baseline["webview2_count"] + 0) : 7
    wv2ProcessCap := baseline.Has("webview2_process_cap") ? (baseline["webview2_process_cap"] + 0) : 4
    if (wv2ProcessCap < 2)
        wv2ProcessCap := 4
    ; P0B: 固定 cap，禁止 emptyLoadWv2+1 动态放宽
    totalCap := wv2ProcessCap
    if (totalCap < 2)
        totalCap := 2
    policy := Map(
        "mode", m,
        "primary", 1,
        "secondary", 1,
        "residentWebview", 1,
        "totalWebview", totalCap,
        "baselineRef", baseline.Has("capturedAt") ? String(baseline["capturedAt"]) : "",
        "baselineSource", baseline.Has("source") ? String(baseline["source"]) : "",
        "emptyLoadWv2", emptyWv2,
        "emptyLoadPrivateMiB", baseline.Has("emptyLoadPrivateMiB") ? (baseline["emptyLoadPrivateMiB"] + 0.0) : 0.0
    )
    switch m {
        case "bubble":
            policy["primary"] := 0
            policy["secondary"] := 0
            policy["residentWebview"] := 1
            policy["totalWebview"] := 2
        case "hole":
            policy["primary"] := 1
            policy["secondary"] := 0
            policy["residentWebview"] := 0
            policy["totalWebview"] := 2
        case "tray":
            policy["primary"] := 0
            policy["secondary"] := 0
            policy["residentWebview"] := 0
            policy["totalWebview"] := 0
    }
    return policy
}

SurfaceManager_MeasuredBaseline(*) {
    static cached := 0
    if (cached is Map)
        return cached
    defaults := Map(
        "emptyLoadPrivateMiB", 1909.03,
        "webview2_count", 7,
        "capturedAt", "2026-06-10T01:50:57Z",
        "source", "s4_gate_defaults"
    )
    try {
        path := FuncExists("Nmer_DebugPath")
            ? Nmer_DebugPath("a2ui_memory_baseline.json")
            : (A_ScriptDir . "\Cache\debug\a2ui_memory_baseline.json")
        if FileExist(path) {
            raw := FileRead(path, "UTF-8")
            if (Trim(raw) != "" && FuncExists("Jxon_Load")) {
                data := Jxon_Load(raw)
                if (data is Map) {
                    if data.Has("emptyLoadPrivateMiB")
                        defaults["emptyLoadPrivateMiB"] := data["emptyLoadPrivateMiB"] + 0.0
                    if data.Has("capturedAt")
                        defaults["capturedAt"] := String(data["capturedAt"])
                    if data.Has("processes") && IsObject(data["processes"]) {
                        if data["processes"].Has("webview2_count")
                            defaults["webview2_count"] := data["processes"]["webview2_count"] + 0
                        if data["processes"].Has("webview2_process_cap")
                            defaults["webview2_process_cap"] := data["processes"]["webview2_process_cap"] + 0
                        if data["processes"].Has("webview2_host_control_cap")
                            defaults["webview2_host_control_cap"] := data["processes"]["webview2_host_control_cap"] + 0
                    }
                    defaults["source"] := path
                }
            }
        }
    } catch {
    }
    cached := defaults
    return cached
}

SurfaceManager_IsBudgetTrackedState(state) {
    s := String(state)
    return (s = "ACTIVE" || s = "CREATING")
}

SurfaceManager_BudgetCandidateScore(rec, targetSurface := "") {
    sid := rec.Has("id") ? String(rec["id"]) : ""
    if (sid = String(targetSurface))
        return 1000000
    score := 0
    state := rec.Has("state") ? String(rec["state"]) : ""
    role := rec.Has("role") ? String(rec["role"]) : ""
    runtime := rec.Has("runtime") ? String(rec["runtime"]) : ""
    if (state = "ACTIVE")
        score += 0
    else if (state = "CREATING")
        score += 1000
    else
        score += 10000
    if (role = "resident")
        score += 5000
    if (runtime != "webview")
        score += 3000
    tick := rec.Has("lastTick") ? rec["lastTick"] + 0.0 : A_TickCount + 0.0
    score += Round((tick / 10.0), 0)
    return score
}

SurfaceManager_BuildBudgetSnapshot(mode := "", targetSurface := "", reason := "") {
    global g_SurfaceRuntime_Registry
    m := String(mode != "" ? mode : SurfaceManager_CurrentMode())
    policy := SurfaceManager_BudgetPolicy(m)
    counts := Map(
        "primary", 0,
        "secondary", 0,
        "residentWebview", 0,
        "totalWebview", 0
    )
    tracked := []
    candidatePool := []
    for sid, rec in g_SurfaceRuntime_Registry {
        if !(rec is Map)
            continue
        state := rec.Has("state") ? String(rec["state"]) : ""
        if !SurfaceManager_IsBudgetTrackedState(state)
            continue
        runtime := rec.Has("runtime") ? String(rec["runtime"]) : ""
        role := rec.Has("role") ? String(rec["role"]) : ""
        row := Map(
            "id", String(sid),
            "state", state,
            "runtime", runtime,
            "role", role,
            "lastTick", rec.Has("lastTick") ? rec["lastTick"] + 0.0 : 0.0
        )
        tracked.Push(row)
        if (runtime = "webview") {
            counts["totalWebview"] := counts["totalWebview"] + 1
            if (role = "resident")
                counts["residentWebview"] := counts["residentWebview"] + 1
            else if (role = "primary")
                counts["primary"] := counts["primary"] + 1
            else if (role = "secondary")
                counts["secondary"] := counts["secondary"] + 1
        }
        row["score"] := SurfaceManager_BudgetCandidateScore(row, targetSurface)
        candidatePool.Push(row)
    }
    overages := []
    for _, key in ["primary", "secondary", "residentWebview", "totalWebview"] {
        if !policy.Has(key)
            continue
        limit := policy[key] + 0
        used := counts.Has(key) ? counts[key] : 0
        if (used > limit)
            overages.Push(Map("bucket", key, "used", used, "limit", limit, "overflow", used - limit))
    }
    candidates := []
    if (overages.Length > 0) {
        sortRows := []
        for _, row in candidatePool
            sortRows.Push(row)
        loop sortRows.Length {
            i := A_Index
            j := i + 1
            while (j <= sortRows.Length) {
                if (sortRows[j]["score"] < sortRows[i]["score"]) {
                    tmp := sortRows[i]
                    sortRows[i] := sortRows[j]
                    sortRows[j] := tmp
                }
                j += 1
            }
        }
        seen := Map()
        for _, over in overages {
            bucket := String(over["bucket"])
            needed := over["overflow"] + 0
            for _, row in sortRows {
                if (needed <= 0)
                    break
                sid := String(row["id"])
                if (seen.Has(sid))
                    continue
                role := String(row["role"])
                runtime := String(row["runtime"])
                match := false
                switch bucket {
                    case "primary":
                        match := (role = "primary")
                    case "secondary":
                        match := (role = "secondary")
                    case "residentWebview":
                        match := (role = "resident" && runtime = "webview")
                    case "totalWebview":
                        match := (runtime = "webview")
                }
                if !match
                    continue
                if (sid = String(targetSurface))
                    continue
                candidates.Push(Map("surface", sid, "bucket", bucket, "state", row["state"], "role", role, "runtime", runtime))
                seen[sid] := true
                needed -= 1
            }
        }
    }
    return Map(
        "mode", m,
        "reason", String(reason),
        "targetSurface", String(targetSurface),
        "policy", policy,
        "counts", counts,
        "tracked", tracked,
        "overages", overages,
        "candidates", candidates
    )
}

SurfaceManager_BudgetSignature(snapshot) {
    sig := String(snapshot["mode"]) . "|" . String(snapshot["reason"]) . "|" . String(snapshot["targetSurface"])
    for key, val in snapshot["counts"]
        sig .= "|" . key . ":" . val
    for _, over in snapshot["overages"]
        sig .= "|over:" . over["bucket"] . ":" . over["used"] . ":" . over["limit"]
    for _, cand in snapshot["candidates"]
        sig .= "|cand:" . cand["surface"] . ":" . cand["bucket"]
    return sig
}

SurfaceManager_RecomputeBudget(reason := "", targetSurface := "", modeOverride := "", force := false) {
    global g_SurfaceRuntime_LastBudgetSignature
    if !SurfaceManager_IsObservationEnabled()
        return false
    try {
        snapshot := SurfaceManager_BuildBudgetSnapshot(modeOverride, targetSurface, reason)
        sig := SurfaceManager_BudgetSignature(snapshot)
        if !force && (sig = g_SurfaceRuntime_LastBudgetSignature)
            return false
        payload := Map(
            "mode", snapshot["mode"],
            "reason", String(reason),
            "targetSurface", String(targetSurface),
            "enforceBudget", FuncExists("Nmer_SurfaceManagerEnforceBudget") ? !!Nmer_SurfaceManagerEnforceBudget() : false,
            "policy", snapshot["policy"],
            "counts", snapshot["counts"],
            "overages", snapshot["overages"],
            "candidates", snapshot["candidates"]
        )
        SurfaceManager_RecordEvent("budget_plan", "", payload)
        g_SurfaceRuntime_LastBudgetSignature := sig
        if !(FuncExists("Nmer_SurfaceManagerEnforceBudget") && Nmer_SurfaceManagerEnforceBudget())
            return true
        for _, cand in snapshot["candidates"] {
            sid := String(cand["surface"])
            requester := String(targetSurface)
            handoff := SurfaceManager_IsPrimaryHandoff(requester, sid)
            meta := Map(
                "reason", handoff ? "primary_handoff" : "budget_pressure",
                "requester", requester,
                "bucket", String(cand["bucket"]),
                "mode", snapshot["mode"]
            )
            SurfaceManager_RecordEvent("budget_enforce", sid, meta)
            if handoff {
                SurfaceExecutor_Suspend(sid, meta)
                continue
            }
            if FuncExists("SurfaceIntent_Dispose") && FuncExists("Nmer_SurfaceManagerRouteIntents") && Nmer_SurfaceManagerRouteIntents()
                SurfaceIntent_Dispose(sid, meta)
            else
                SurfaceExecutor_Dispose(sid, meta)
        }
        return true
    } catch as err {
        SurfaceManager_RecordEvent("budget_plan_error", "", Map(
            "reason", String(reason),
            "targetSurface", String(targetSurface),
            "message", err.Message
        ))
        return false
    }
}

SurfaceManager_WriteSnapshot(*) {
    global g_SurfaceRuntime_Registry
    if !SurfaceManager_IsObservationEnabled()
        return
    arr := []
    for surfaceId, rec in g_SurfaceRuntime_Registry {
        row := Map("id", surfaceId)
        if (rec is Map) {
            for key, val in rec
                row[String(key)] := SurfaceManager_SimpleClone(val)
        }
        arr.Push(row)
    }
    try FileDelete(SurfaceManager_SnapshotPath())
    catch {
    }
    try FileAppend(Jxon_Dump(arr), SurfaceManager_SnapshotPath(), "UTF-8")
    catch {
    }
}

SurfaceManager_RegisterSurface(surfaceId, role := "", runtime := "", meta := 0) {
    global g_SurfaceRuntime_Registry
    if !SurfaceManager_IsObservationEnabled()
        return
    if (surfaceId = "")
        return
    rec := g_SurfaceRuntime_Registry.Has(surfaceId) ? g_SurfaceRuntime_Registry[surfaceId] : Map()
    if (role != "")
        rec["role"] := role
    else if !rec.Has("role")
        rec["role"] := "secondary"
    if (runtime != "")
        rec["runtime"] := runtime
    else if !rec.Has("runtime")
        rec["runtime"] := "webview"
    if !rec.Has("state")
        rec["state"] := "ABSENT"
    rec["lastMode"] := SurfaceManager_CurrentMode()
    if (meta is Map) {
        for key, val in meta
            rec[String(key)] := SurfaceManager_SimpleClone(val)
    }
    g_SurfaceRuntime_Registry[surfaceId] := rec
    SurfaceManager_RecordEvent("register", surfaceId, rec)
    SurfaceManager_WriteSnapshot()
}

SurfaceManager_SetState(surfaceId, nextState, meta := 0) {
    global g_SurfaceRuntime_Registry, g_SurfaceRuntime_LastRequestBySurface
    if !SurfaceManager_IsObservationEnabled()
        return
    SurfaceManager_EnsureBootstrap()
    if (surfaceId = "")
        return
    rec := g_SurfaceRuntime_Registry.Has(surfaceId) ? g_SurfaceRuntime_Registry[surfaceId] : Map()
    rec["state"] := String(nextState)
    rec["lastMode"] := SurfaceManager_CurrentMode()
    rec["lastTick"] := A_TickCount
    rec["lastTs"] := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    metaOut := (meta is Map) ? SurfaceManager_SimpleClone(meta) : Map()
    if !(metaOut is Map)
        metaOut := Map("detail", metaOut)
    if (surfaceId != "" && g_SurfaceRuntime_LastRequestBySurface.Has(surfaceId) && !metaOut.Has("requestId"))
        metaOut["requestId"] := g_SurfaceRuntime_LastRequestBySurface[surfaceId]
    if (metaOut is Map) {
        for key, val in metaOut
            rec[String(key)] := SurfaceManager_SimpleClone(val)
    }
    if (meta is Map) {
        for key, val in meta
            rec[String(key)] := SurfaceManager_SimpleClone(val)
    }
    g_SurfaceRuntime_Registry[surfaceId] := rec
    SurfaceManager_RecordEvent("state", surfaceId, Map("state", nextState, "meta", metaOut))
    SurfaceManager_WriteSnapshot()
    SurfaceManager_RecomputeBudget("state_" . String(nextState), surfaceId)
}

SurfaceManager_ObserveInit(surfaceId, meta := 0) {
    SurfaceManager_SetState(surfaceId, "CREATING", meta)
}

SurfaceManager_ObserveShow(surfaceId, meta := 0) {
    observeMeta := meta
    if FuncExists("SurfaceTransaction_EnrichObserveMeta")
        observeMeta := SurfaceTransaction_EnrichObserveMeta(surfaceId, meta)
    if FuncExists("SurfaceTransaction_OnSurfaceActive")
        try SurfaceTransaction_OnSurfaceActive(surfaceId, observeMeta)
    SurfaceManager_SetState(surfaceId, "ACTIVE", observeMeta)
}

SurfaceManager_ObserveHide(surfaceId, meta := 0) {
    SurfaceManager_SetState(surfaceId, "SUSPENDED", meta)
}

SurfaceManager_ObserveClose(surfaceId, meta := 0) {
    SurfaceManager_SetState(surfaceId, "ABSENT", meta)
}

SurfaceManager_ObserveWarmupQueue(queue) {
    if !SurfaceManager_IsObservationEnabled()
        return
    names := []
    for _, callable in queue {
        fnName := SurfaceManager_CallName(callable)
        names.Push(fnName)
        sid := SurfaceManager_MapWarmupFuncToSurface(fnName)
        if (sid != "")
            SurfaceManager_RegisterSurface(sid)
    }
    SurfaceManager_RecordEvent("warmup_queue", "", Map("count", queue.Length, "items", names))
}

SurfaceManager_ObserveWarmupStep(index, callable) {
    if !SurfaceManager_IsObservationEnabled()
        return
    fnName := SurfaceManager_CallName(callable)
    sid := SurfaceManager_MapWarmupFuncToSurface(fnName)
    meta := Map("index", index, "callable", fnName)
    SurfaceManager_RecordEvent("warmup_step", sid, meta)
    if (sid != "")
        SurfaceManager_ObserveInit(sid, Map("source", "warmup", "callable", fnName, "index", index))
}

SurfaceManager_ObserveModeTransition(stage, targetMode := "", meta := 0) {
    payload := Map("stage", String(stage), "targetMode", String(targetMode))
    if (meta is Map) {
        for key, val in meta
            payload[String(key)] := SurfaceManager_SimpleClone(val)
    } else if (meta != 0 && String(meta) != "") {
        payload["detail"] := meta
    }
    SurfaceManager_RecordEvent("mode_transition", "", payload)
    if (stage = "appearance_ready" || stage = "runtime_ready" || stage = "persist_ready" || stage = "screenshot_restore_runtime")
        SurfaceManager_RecomputeBudget("mode_" . String(stage), "", String(targetMode))
}

SurfaceManager_ObserveSystemBootstrap(meta := 0) {
    SurfaceManager_RecordEvent("bootstrap", "", meta)
    SurfaceManager_EnsureBootstrap()
    SurfaceManager_RecomputeBudget("bootstrap", "", "", true)
}

SurfaceManager_BuildWarmupQueue(defaultQueue) {
    q := []
    for _, callable in defaultQueue
        q.Push(callable)
    if !(FuncExists("Nmer_SurfaceManagerInterceptWarmup") && Nmer_SurfaceManagerInterceptWarmup()) {
        SurfaceManager_RecordEvent("warmup_plan", "", Map("policy", "legacy_default", "count", q.Length))
        return q
    }
    mode := SurfaceManager_CurrentMode()
    ; Phase 0 controlled takeover: when intercept is enabled, prefer fully lazy surfaces
    ; and let explicit Show/Intent paths pay the cold-start cost instead of startup idle memory.
    filtered := []
    SurfaceManager_RecordEvent("warmup_plan", "", Map("policy", "lazy_all", "mode", mode, "count", filtered.Length))
    return filtered
}

SurfaceManager_ShouldWarmupConfig(*) {
    if FuncExists("Nmer_SurfaceManagerInterceptWarmup") && Nmer_SurfaceManagerInterceptWarmup()
        return false
    return true
}
