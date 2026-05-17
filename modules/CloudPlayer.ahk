#Requires AutoHotkey v2.0

global g_CloudPlayerGui := 0
global g_CloudPlayerCtrl := 0
global g_CloudPlayerWv2 := 0
global g_CloudPlayerReady := false
global g_CloudPlayerOpenListPid := 0
global g_CloudPlayerApiBase := "http://127.0.0.1:5244"
global g_CloudPlayerImportBusy := false
global g_CloudPlayerImportTask := Map("active", false, "taskId", "", "cancelled", false, "provider", "")
global g_CloudPlayerAsyncFlows := Map()
global g_CloudPlayerAdminTokenJobs := Map()
global g_CloudPlayerAutoPulseEnabled := false
global g_CloudPlayerBackendHealth := false
global g_CloudPlayerLastHealthTick := 0
global g_CloudPlayerHealthTtlMs := 900
global g_CloudPlayerHealthProbeInflight := false
global g_CloudPlayerLatestReq := Map()
global g_CloudPlayerActiveHttpReq := Map()
global g_CloudPlayerDownloadCancel := Map()
global g_CloudPlayerDownloadWalk := Map()
global g_CloudPlayerMainThreadId := 0
global g_CloudPlayerUiOutbox := []
global g_CloudPlayerDlThreadRunning := false
global g_CloudPlayerDlJob := 0
global g_CloudPlayerDlLastListErr := ""
global g_CloudPlayerAsyncSenderResolved := false
global g_CloudPlayerAsyncSenderKind := ""
global g_CloudPlayerAsyncSenderFn := 0
global g_CloudPlayerAsyncSenderWarned := false
global g_CloudPlayerAsyncSenderLastProbeTick := 0

CloudPlayer_CurrentThreadId() {
    return DllCall("GetCurrentThreadId", "uint")
}

CloudPlayer_EnsureMainThreadId() {
    global g_CloudPlayerMainThreadId
    if !g_CloudPlayerMainThreadId
        g_CloudPlayerMainThreadId := CloudPlayer_CurrentThreadId()
    return g_CloudPlayerMainThreadId
}

CloudPlayer_IsMainThread() {
    return CloudPlayer_EnsureMainThreadId() = CloudPlayer_CurrentThreadId()
}

CloudPlayer_FeatureEnabled(envName, defaultValue := true) {
    v := Trim(String(EnvGet(String(envName))))
    if (v = "")
        return !!defaultValue
    low := StrLower(v)
    return !(low = "0" || low = "false" || low = "off" || low = "no")
}

CloudPlayer_UseAsyncFlow() {
    return CloudPlayer_FeatureEnabled("NIUMA_CP_ASYNC_FLOW", true)
}

CloudPlayer_UseAsyncImport() {
    return CloudPlayer_FeatureEnabled("NIUMA_CP_ASYNC_IMPORT", CloudPlayer_UseAsyncFlow())
}

CloudPlayer_UseAsyncBrowse() {
    return CloudPlayer_FeatureEnabled("NIUMA_CP_ASYNC_BROWSE", CloudPlayer_UseAsyncFlow())
}

CloudPlayer_UseAsyncDownload() {
    return CloudPlayer_FeatureEnabled("NIUMA_CP_ASYNC_DOWNLOAD", CloudPlayer_UseAsyncFlow())
}

CloudPlayer_UseAsyncDownloadPipeline() {
    return CloudPlayer_FeatureEnabled("NIUMA_CP_ASYNC_DOWNLOAD_PIPELINE", CloudPlayer_UseAsyncDownload())
}

; Scan phase is the most stateful part; keep default sync for stability.
; Async scan can be enabled explicitly for testing/gray rollout.
CloudPlayer_UseAsyncDownloadScan() {
    return CloudPlayer_FeatureEnabled("NIUMA_CP_ASYNC_DOWNLOAD_SCAN", false) && CloudPlayer_UseAsyncDownloadPipeline()
}

CloudPlayer_AsyncLog(eventName, detail := "") {
    try CoreAsyncHttp_Log(String(eventName), String(detail))
}

CloudPlayer_AsyncStepEnter(taskId, stepName) {
    CloudPlayer_AsyncLog("cloudplayer_async_step_enter", "task_id=" . String(taskId) . " step=" . String(stepName))
}

CloudPlayer_AsyncStepLeave(taskId, stepName, ok := true) {
    CloudPlayer_AsyncLog("cloudplayer_async_step_leave", "task_id=" . String(taskId) . " step=" . String(stepName) . " ok=" . (ok ? 1 : 0))
}

ShowCloudPlayer(*) {
    CloudPlayer_Show()
}

CloudPlayer_Show() {
    global g_CloudPlayerGui, g_CloudPlayerAutoPulseEnabled
    CloudPlayer_LogAsyncSenderHealth("show")
    try FloatingToolbar_PageDockEnter("cloudplayer")
    if !CloudPlayer_EnsureOpenListRunning() {
        try TrayTip("CloudPlayer", "OpenList 未启动。请确认 openlist.exe 已放到 tools\\openlist\\。", "Icon! 2")
        catch {
        }
    }

    if !g_CloudPlayerGui
        CloudPlayer_CreateGui()

    w := Round(A_ScreenWidth * 0.78)
    h := Round(A_ScreenHeight * 0.82)
    if (w < 960)
        w := 960
    if (h < 620)
        h := 620
    try g_CloudPlayerGui.Show("w" . w . " h" . h)
    try LegacyGuard_RequestFocus("CloudPlayer", "ahk_id " . g_CloudPlayerGui.Hwnd, 50, "show_cloud_player")
    g_CloudPlayerAutoPulseEnabled := true
    SetTimer(CloudPlayer_AutoConnectPulse, 6000)
    SetTimer(CloudPlayer_AutoConnectPulse, -150)
}

CloudPlayer_CreateGui() {
    global g_CloudPlayerGui, g_CloudPlayerCtrl, g_CloudPlayerWv2, g_CloudPlayerReady
    global g_CloudPlayerOpenListPid
    global g_CloudPlayerImportBusy, g_CloudPlayerAutoPulseEnabled
    CloudPlayer_EnsureMainThreadId()

    if g_CloudPlayerGui {
        try g_CloudPlayerGui.Destroy()
        catch {
        }
    }

    g_CloudPlayerCtrl := 0
    g_CloudPlayerWv2 := 0
    g_CloudPlayerReady := false
    g_CloudPlayerOpenListPid := 0
    g_CloudPlayerImportBusy := false
    g_CloudPlayerAutoPulseEnabled := false

    ownerOpt := ""
    try {
        global FloatingToolbarGUI
        if IsSet(FloatingToolbarGUI) && FloatingToolbarGUI && FloatingToolbarGUI.Hwnd
            ownerOpt := " +Owner" . FloatingToolbarGUI.Hwnd
    } catch {
    }

    g_CloudPlayerGui := Gui("+Resize +MinSize960x620 +DPIScale" . ownerOpt, "牛马云")
    g_CloudPlayerGui.BackColor := "121212"
    g_CloudPlayerGui.OnEvent("Size", CloudPlayer_OnGuiSize)
    g_CloudPlayerGui.OnEvent("Close", CloudPlayer_OnGuiClose)
    ; 点最小化时改为隐藏窗口，避免缩到任务栏角落
    OnMessage(0x0112, CloudPlayer_WM_SYSCOMMAND)

    try WebView2_CreateWithSharedEnvAsync(g_CloudPlayerGui.Hwnd, CloudPlayer_OnWebViewCreated, "cloud_player")
    catch as e {
        try MsgBox("CloudPlayer WebView2 创建失败：`n" . e.Message)
        catch {
        }
    }
}

CloudPlayer_ApplyWebViewBounds() {
    global g_CloudPlayerGui, g_CloudPlayerCtrl
    if !g_CloudPlayerGui || !g_CloudPlayerCtrl
        return
    try WinGetClientPos(, , &cw, &ch, g_CloudPlayerGui.Hwnd)
    catch {
        return
    }
    if (cw < 1 || ch < 1)
        return
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    try {
        g_CloudPlayerCtrl.Bounds := rc
        g_CloudPlayerCtrl.NotifyParentWindowPositionChanged()
    } catch {
    }
}

CloudPlayer_OnGuiClose(*) {
    global g_CloudPlayerGui, g_CloudPlayerAutoPulseEnabled
    try FloatingToolbar_PageDockLeave("cloudplayer")
    try g_CloudPlayerGui.Hide()
    g_CloudPlayerAutoPulseEnabled := false
}

CloudPlayer_WM_SYSCOMMAND(wParam, lParam, msg, hwnd) {
    global g_CloudPlayerGui
    try {
        if !g_CloudPlayerGui || !g_CloudPlayerGui.Hwnd
            return
        if (hwnd != g_CloudPlayerGui.Hwnd)
            return
        ; SC_MINIMIZE
        if ((wParam & 0xFFF0) = 0xF020) {
            CloudPlayer_OnGuiClose()
            return 0
        }
    } catch {
    }
}

CloudPlayer_OnGuiSize(guiObj, minMax, width, height) {
    ; WebView2.Controller 无 Move；须写 Bounds，否则最大化/拖动后视口仍停留在初次 Fill 的尺寸（右侧空白）
    CloudPlayer_ApplyWebViewBounds()
}

CloudPlayer_OnWebViewCreated(ctrl) {
    global g_CloudPlayerGui, g_CloudPlayerCtrl, g_CloudPlayerWv2, g_CloudPlayerReady
    global g_CloudPlayerAutoPulseEnabled

    if !IsObject(ctrl) || !ctrl.HasProp("CoreWebView2") {
        try MsgBox("CloudPlayer WebView2 初始化失败。")
        catch {
        }
        return
    }

    g_CloudPlayerCtrl := ctrl
    g_CloudPlayerWv2 := ctrl.CoreWebView2
    g_CloudPlayerReady := true

    ; Avoid white flash before real page paints.
    try g_CloudPlayerCtrl.DefaultBackgroundColor := 0xFF121212

    try ApplyUnifiedWebViewAssets(g_CloudPlayerWv2)
    try WebView2_RegisterHostBridge(g_CloudPlayerWv2)

    try g_CloudPlayerWv2.Settings.IsStatusBarEnabled := false
    try g_CloudPlayerWv2.Settings.AreDefaultContextMenusEnabled := true
    try g_CloudPlayerWv2.Settings.AreDefaultScriptDialogsEnabled := true
    try g_CloudPlayerWv2.Settings.AreDevToolsEnabled := true

    try g_CloudPlayerWv2.add_WebMessageReceived(CloudPlayer_OnWebMessage)
    catch {
        try g_CloudPlayerWv2.WebMessageReceived(CloudPlayer_OnWebMessage)
    }

    CloudPlayer_ApplyWebViewBounds()
    try g_CloudPlayerWv2.NavigateToString("<!doctype html><html><head><meta charset='utf-8'><style>html,body{margin:0;width:100%;height:100%;background:#121212;color:#d7e3f7;font:13px Segoe UI,Microsoft YaHei UI,sans-serif;display:flex;align-items:center;justify-content:center} .dot{width:7px;height:7px;border-radius:50%;background:#ff8f35;box-shadow:0 0 12px rgba(255,143,53,.65);margin-right:8px}</style></head><body><span class='dot'></span>牛马云加载中...</body></html>")
    url := BuildAppLocalUrl("CloudPlayer.html?t=" . A_TickCount)
    SetTimer(() => g_CloudPlayerWv2.Navigate(url), -10)

    g_CloudPlayerAutoPulseEnabled := true
    SetTimer(CloudPlayer_AutoConnectPulse, 6000)
    SetTimer(CloudPlayer_AutoConnectPulse, -200)
}

CloudPlayer_AutoConnectPulse() {
    global g_CloudPlayerWv2, g_CloudPlayerAutoPulseEnabled
    if !g_CloudPlayerAutoPulseEnabled
        return
    if !g_CloudPlayerWv2
        return
    if !CloudPlayer_IsOpenListRunning()
        CloudPlayer_StartOpenList()
    CloudPlayer_NotifyWebViewStatus()
}

CloudPlayer_NotifyWebViewStatus() {
    global g_CloudPlayerWv2, g_CloudPlayerApiBase
    if !g_CloudPlayerWv2
        return
    try CloudPlayer_EnsureOpenListRunning()
    try WebView_QueuePayload(g_CloudPlayerWv2, Map(
        "type", "cloudplayer_status",
        "apiBase", g_CloudPlayerApiBase,
        "openListOnline", CloudPlayer_IsOpenListRunning(),
        "openListExe", CloudPlayer_FindOpenListExe()
    ))
}

CloudPlayer_OnWebMessage(sender, args) {
    global g_CloudPlayerWv2, g_CloudPlayerApiBase, g_CloudPlayerImportBusy
    payload := CloudPlayer_ParseWebMessage(args)
    if !(payload is Map) || !payload.Has("type")
        return

    typ := String(payload["type"])
    requestId := AsyncGuardrails_RequestIdFromPayload(payload)
    if (payload.Has("apiBase")) {
        try {
            ab := Trim(String(payload["apiBase"]))
            if (ab != "")
                g_CloudPlayerApiBase := CloudPlayer_NormalizeApiBase(ab)
        } catch {
        }
    }

    if (typ = "cloudplayer_ready") {
        CloudPlayer_NotifyWebViewStatus()
        CloudPlayer_SendDockConfig()
        return
    }

    if (typ = "nmDockReady") {
        CloudPlayer_SendDockConfig()
        return
    }
    if (typ = "nmDockLeave") {
        ; lifecycle handled by CloudPlayer_Show/CloudPlayer_OnGuiClose
        return
    }

    if (typ = "nmDockCmd") {
        CloudPlayer_ExecuteDockCmd(payload)
        return
    }

    if (typ = "cloudplayer_ping_openlist") {
        CloudPlayer_NotifyWebViewStatus()
        return
    }

    if (typ = "cloudplayer_set_api_base") {
        CloudPlayer_NotifyWebViewStatus()
        return
    }

    if (typ = "cloudplayer_restart_openlist") {
        ok := CloudPlayer_StartOpenList()
        try WebView_QueuePayload(g_CloudPlayerWv2, Map(
            "type", "cloudplayer_status",
            "apiBase", g_CloudPlayerApiBase,
            "openListOnline", ok,
            "openListExe", CloudPlayer_FindOpenListExe()
        ))
        return
    }

    if (typ = "cloudplayer_open_dashboard") {
        try Run(CloudPlayer_GetOpenListAdminUrl())
        return
    }

    if (typ = "cloudplayer_open_url") {
        url := payload.Has("url") ? Trim(String(payload["url"])) : ""
        if (url != "" && RegExMatch(url, "i)^https?://") && !RegExMatch(url, "i)/@manage(?:[/?#]|$)"))
            CloudPlayer_OpenExternalUrl(url)
        return
    }

    if (typ = "cloudplayer_download_folder") {
        folderPath := payload.Has("path") ? String(payload["path"]) : "/"
        folderName := payload.Has("name") ? String(payload["name"]) : ""
        token := payload.Has("token") ? Trim(String(payload["token"])) : ""
        userToken := payload.Has("userToken") ? Trim(String(payload["userToken"])) : token
        adminToken := payload.Has("adminToken") ? Trim(String(payload["adminToken"])) : ""
        downloadMode := payload.Has("downloadMode") ? Trim(String(payload["downloadMode"])) : "zip"
        if (downloadMode != "batch")
            downloadMode := "zip"
        reqId := payload.Has("reqId") ? String(payload["reqId"]) : requestId
        CloudPlayer_MarkLatestReq("download_folder", reqId)
        CloudPlayer_ClearDownloadCancelled(reqId)
        manifestFiles := 0
        if payload.Has("files") {
            try manifestFiles := CloudPlayer_NormalizeManifestFiles(payload["files"])
            catch {
                manifestFiles := 0
            }
        }
        SetTimer(CloudPlayer_DeferredDownloadFolder.Bind(reqId, folderPath, folderName, token, manifestFiles, userToken, adminToken, downloadMode), -10)
        return
    }
    if (typ = "cloudplayer_download_cancel") {
        reqId := payload.Has("reqId") ? String(payload["reqId"]) : requestId
        okCancel := CloudPlayer_MarkDownloadCancelled(reqId)
        CloudPlayer_QueuePayload(Map(
            "type", "cloudplayer_download_result",
            "ok", false,
            "message", okCancel ? "cancel requested" : "missing reqId",
            "path", "",
            "name", ""
        ), reqId, "cancelled", okCancel ? "cancelled" : "invalid_request_id")
        return
    }

    if (typ = "cloudplayer_request_admin_token") {
        reqId := payload.Has("reqId") ? String(payload["reqId"]) : requestId
        CloudPlayer_MarkLatestReq("admin_token", reqId)
        SetTimer(CloudPlayer_DeferredAdminToken.Bind(reqId), -10)
        return
    }

    if (typ = "cloudplayer_fs_list") {
        path := payload.Has("path") ? String(payload["path"]) : "/"
        refresh := payload.Has("refresh") ? CloudPlayer_ToBool(payload["refresh"], false) : false
        token := payload.Has("token") ? Trim(String(payload["token"])) : ""
        reqId := payload.Has("reqId") ? String(payload["reqId"]) : requestId
        CloudPlayer_MarkLatestReq("fs_list", reqId)
        headers := Map("Content-Type", "application/json")
        if (token != "")
            headers["Authorization"] := token
        body := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(Map(
            "path", path,
            "password", "",
            "page", 1,
            "per_page", 300,
            "refresh", refresh
        )), ["refresh"])
        HttpJsonAsync("POST", g_CloudPlayerApiBase . "/api/fs/list", body, (ret) => CloudPlayer_OnFsListResult(reqId, path, ret), Map("headers", headers, "timeoutMs", 12000, "receiveTimeoutMs", 12000, "reqId", reqId, "tag", "cp_fs_list"))
        return
    }

    if (typ = "cloudplayer_fs_get") {
        path := payload.Has("path") ? String(payload["path"]) : "/"
        token := payload.Has("token") ? Trim(String(payload["token"])) : ""
        reqId := payload.Has("reqId") ? String(payload["reqId"]) : requestId
        CloudPlayer_MarkLatestReq("fs_get", reqId)
        headers := Map("Content-Type", "application/json")
        if (token != "")
            headers["Authorization"] := token
        body := Jxon_Dump(Map("path", path, "password", ""))
        HttpJsonAsync("POST", g_CloudPlayerApiBase . "/api/fs/get", body, (ret) => CloudPlayer_OnFsGetResult(reqId, path, ret), Map("headers", headers, "timeoutMs", 12000, "receiveTimeoutMs", 12000, "reqId", reqId, "tag", "cp_fs_get"))
        return
    }

    if (typ = "cloudplayer_archive_list") {
        path := payload.Has("path") ? String(payload["path"]) : ""
        token := payload.Has("token") ? Trim(String(payload["token"])) : ""
        reqId := payload.Has("reqId") ? String(payload["reqId"]) : requestId
        CloudPlayer_MarkLatestReq("archive_list", reqId)
        SetTimer(CloudPlayer_DeferredArchiveList.Bind(reqId, path, token), -10)
        return
    }

    ; 任意 /api/fs/* JSON POST（复制/粘贴/删除等）；与列表请求一致地使用 g_CloudPlayerApiBase + WinHttp，避免 WebView host bridge HttpRequest 传入非法 URL。
    if (typ = "cloudplayer_api_json") {
        apiPath := payload.Has("apiPath") ? Trim(String(payload["apiPath"])) : ""
        bodyStr := payload.Has("body") ? String(payload["body"]) : ""
        token := payload.Has("token") ? Trim(String(payload["token"])) : ""
        reqId := payload.Has("reqId") ? String(payload["reqId"]) : requestId
        CloudPlayer_MarkLatestReq("api_json", reqId)
        if apiPath = "" || !RegExMatch(apiPath, "i)^/api/fs/") {
            try WebView_QueuePayload(g_CloudPlayerWv2, Map(
                "type", "cloudplayer_api_json_result",
                "reqId", reqId,
                "requestId", reqId,
                "phase", "error",
                "ok", false,
                "status", 0,
                "error", "invalid apiPath",
                "errorCode", "invalid_api_path",
                "ts", A_Now,
                "text", ""
            ))
            return
        }
        headers := Map("Content-Type", "application/json", "Accept", "application/json")
        if (token != "")
            headers["Authorization"] := token
        HttpJsonAsync("POST", g_CloudPlayerApiBase . apiPath, bodyStr, (ret) => CloudPlayer_OnApiJsonResult(reqId, ret), Map("headers", headers, "timeoutMs", 12000, "receiveTimeoutMs", 12000, "reqId", reqId, "tag", "cp_api_json"))
        return
    }

    if (typ = "cloudplayer_import_aliyun") {
        if (g_CloudPlayerImportBusy) {
            taskIdBusy := (g_CloudPlayerImportTask is Map && g_CloudPlayerImportTask.Has("taskId")) ? String(g_CloudPlayerImportTask["taskId"]) : ""
            try WebView_QueuePayload(g_CloudPlayerWv2, Map(
                "type", "cloudplayer_import_result",
                "ok", false,
                "message", "import is already running",
                "taskId", taskIdBusy,
                "reqId", taskIdBusy,
                "requestId", taskIdBusy,
                "phase", "error",
                "errorCode", "import_busy",
                "ts", A_Now,
                "mountPath", payload.Has("mountPath") ? String(payload["mountPath"]) : "/aliyun",
                "driver", "AliyundriveOpen"
            ))
            return
        }

        mountPath := payload.Has("mountPath") ? String(payload["mountPath"]) : "/aliyun"
        refreshToken := payload.Has("refreshToken") ? String(payload["refreshToken"]) : ""
        taskId := payload.Has("taskId") ? String(payload["taskId"]) : CloudPlayer_NewTaskId("ali")
        opts := 0
        if (payload.Has("options") && payload["options"] is Map)
            opts := payload["options"]
        g_CloudPlayerImportBusy := true
        CloudPlayer_StartImportTask(taskId, "ali")
        CloudPlayer_SendImportProgress("Queued import task...", taskId, "queued", 1)
        SetTimer(CloudPlayer_RunAliImport.Bind(taskId, refreshToken, mountPath, opts), -10)
        return
    }

    if (typ = "cloudplayer_import_storage") {
        if (g_CloudPlayerImportBusy) {
            taskIdBusy := (g_CloudPlayerImportTask is Map && g_CloudPlayerImportTask.Has("taskId")) ? String(g_CloudPlayerImportTask["taskId"]) : ""
            try WebView_QueuePayload(g_CloudPlayerWv2, Map(
                "type", "cloudplayer_import_result",
                "ok", false,
                "message", "import is already running",
                "taskId", taskIdBusy,
                "reqId", taskIdBusy,
                "requestId", taskIdBusy,
                "phase", "error",
                "errorCode", "import_busy",
                "ts", A_Now,
                "provider", payload.Has("provider") ? String(payload["provider"]) : "",
                "mountPath", payload.Has("mountPath") ? String(payload["mountPath"]) : "/",
                "driver", payload.Has("driver") ? String(payload["driver"]) : "Unknown"
            ))
            return
        }
        provider := payload.Has("provider") ? String(payload["provider"]) : ""
        mountPath := payload.Has("mountPath") ? String(payload["mountPath"]) : "/"
        token := payload.Has("token") ? String(payload["token"]) : ""
        driver := payload.Has("driver") ? String(payload["driver"]) : "Unknown"
        taskId := payload.Has("taskId") ? String(payload["taskId"]) : CloudPlayer_NewTaskId(provider)
        opts := 0
        if (payload.Has("options") && payload["options"] is Map)
            opts := payload["options"]
        g_CloudPlayerImportBusy := true
        CloudPlayer_StartImportTask(taskId, provider)
        CloudPlayer_SendImportProgress("Queued import task...", taskId, "queued", 1)
        SetTimer(CloudPlayer_RunStorageImport.Bind(taskId, provider, token, mountPath, driver, opts), -10)
        return
    }

    if (typ = "cloudplayer_import_cancel") {
        reqTaskId := payload.Has("taskId") ? String(payload["taskId"]) : ""
        if (reqTaskId = "" && g_CloudPlayerImportTask is Map && g_CloudPlayerImportTask.Has("taskId"))
            reqTaskId := String(g_CloudPlayerImportTask["taskId"])
        okCancel := CloudPlayer_CancelImportTask(reqTaskId)
        try WebView_QueuePayload(g_CloudPlayerWv2, Map(
            "type", "cloudplayer_import_task_state",
            "ok", okCancel,
            "taskId", reqTaskId,
            "reqId", reqTaskId,
            "requestId", reqTaskId,
            "phase", "cancelled",
            "errorCode", okCancel ? "" : "no_active_task",
            "message", okCancel ? "cancel requested" : "no active task",
            "ts", A_Now
        ))
        return
    }
}

CloudPlayer_SendDockConfig() {
    global g_CloudPlayerWv2
    if !g_CloudPlayerWv2
        return
    arr := []
    try {
        if IsSet(_LoadCommands)
            _LoadCommands()
        global g_Commands
        if (g_Commands is Map && g_Commands.Has("SceneToolbarLayout") && g_Commands["SceneToolbarLayout"] is Array) {
            for row in g_Commands["SceneToolbarLayout"] {
                if !(row is Map) || !row.Has("sceneId")
                    continue
                sid := Trim(String(row["sceneId"]))
                if (sid = "")
                    continue
                arr.Push(Map(
                    "sceneId", sid,
                    "visible_in_bar", row.Has("visible_in_bar") ? (row["visible_in_bar"] ? true : false) : true,
                    "order_bar", row.Has("order_bar") ? Integer(row["order_bar"]) : -1
                ))
            }
        }
    } catch {
    }
    try WebView_QueuePayload(g_CloudPlayerWv2, Map("type", "nmDockConfig", "sceneToolbarLayout", arr))
}

CloudPlayer_ExecuteDockCmd(payload) {
    cmdId0 := payload.Has("cmdId") ? String(payload["cmdId"]) : ""
    if (cmdId0 = "")
        return
    if (cmdId0 = "open_cloudplayer") {
        try ShowCloudPlayer()
        return
    }
    try {
        _ExecuteCommand(cmdId0)
        return
    } catch {
    }
    m0 := Map(
        "Title", "dock",
        "Content", "",
        "DataType", "text",
        "OriginalDataType", "text",
        "Source", "dock",
        "ClipboardId", 0,
        "PromptMergedIndex", 0,
        "HubSegIndex", -1
    )
    try SC_ExecuteContextCommand(cmdId0, 0, m0)
    catch as err {
        OutputDebug("[CloudPlayer] nmDockCmd: " . err.Message)
    }
}

CloudPlayer_ParseWebMessage(args) {
    ; Preferred path for postMessage(string).
    try {
        raw := args.TryGetWebMessageAsString()
        if (raw != "") {
            try {
                m := Jxon_Load(raw)
                if (m is Map)
                    return m
            } catch {
            }
        }
    } catch {
    }

    ; Fallback for postMessage(object) and wrapped JSON-string payloads.
    try {
        jsonStr := args.WebMessageAsJson
        m := Jxon_Load(jsonStr)
        if (m is String)
            m := Jxon_Load(m)
        if (m is Map)
            return m
    } catch {
    }
    return 0
}

CloudPlayer_RunAliImport(taskId, refreshToken, mountPath, opts) {
    global g_CloudPlayerWv2, g_CloudPlayerImportBusy
    ctx := CloudPlayer_AsyncFlowStart(taskId, "ali", mountPath, "AliyundriveOpen", opts)
    CloudPlayer_AsyncLog("cloudplayer_async_step_enter", "task_id=" . taskId . " phase=import_sync_bridge route=" . (CloudPlayer_UseAsyncImport() ? "async_flow" : "await"))
    if CloudPlayer_UseAsyncImport() {
        CloudPlayer_ImportAliyunStorageAsync(taskId, refreshToken, mountPath, opts, (result) => (
            CloudPlayer_FinishImportTask(taskId, result["ok"], result["message"], "ali", result["mountPath"], result["driver"], result.Has("authToken") ? result["authToken"] : "")
        ))
        return
    }
    if CloudPlayer_IsTaskCancelled(taskId) {
        CloudPlayer_FinishImportTask(taskId, false, "cancelled", "ali", mountPath, "AliyundriveOpen", "")
        return
    }
    result := 0
    try {
        result := CloudPlayer_ImportAliyunStorage(refreshToken, mountPath, opts, taskId)
    } catch as e {
        result := Map(
            "ok", false,
            "message", "import runtime error: " . e.Message,
            "mountPath", mountPath,
            "driver", "AliyundriveOpen"
        )
    }

    if !(result is Map) {
        result := Map(
            "ok", false,
            "message", "import returned invalid result",
            "mountPath", mountPath,
            "driver", "AliyundriveOpen"
        )
    }
    if !result.Has("mountPath")
        result["mountPath"] := mountPath
    if !result.Has("driver")
        result["driver"] := "AliyundriveOpen"
    if !result.Has("ok")
        result["ok"] := false
    if !result.Has("message")
        result["message"] := result["ok"] ? "import success" : "import failed"
    if CloudPlayer_IsTaskCancelled(taskId) {
        CloudPlayer_FinishImportTask(taskId, false, "cancelled", "ali", result["mountPath"], result["driver"], "")
        return
    }
    CloudPlayer_FinishImportTask(taskId, result["ok"], result["message"], "ali", result["mountPath"], result["driver"], result.Has("authToken") ? result["authToken"] : "")
}

CloudPlayer_ImportAliyunStorageAsync(taskId, refreshToken, mountPath := "/aliyun", opts := 0, doneCb := 0) {
    global g_CloudPlayerApiBase
    cb := IsObject(doneCb) ? doneCb : 0
    out := Map("ok", false, "message", "", "mountPath", "", "driver", "AliyundriveOpen", "authToken", "")
    rt := CloudPlayer_NormalizeProviderToken(refreshToken)
    mp := Trim(String(mountPath))
    if (mp = "")
        mp := "/aliyun"
    if (SubStr(mp, 1, 1) != "/")
        mp := "/" . mp
    out["mountPath"] := mp
    if (rt = "") {
        out["message"] := "refresh token is empty"
        cb ? cb.Call(out) : 0
        return
    }
    if CloudPlayer_IsTaskCancelled(taskId) || CloudPlayer_AsyncFlowTimedOut(CloudPlayer_AsyncFlowGet(taskId), "start") {
        out["message"] := "cancelled"
        cb ? cb.Call(out) : 0
        return
    }
    CloudPlayer_AsyncStepEnter(taskId, "ali_checking_openlist")
    CloudPlayer_SendImportProgress("Checking OpenList status...", taskId, "checking_openlist", 5)
    if !CloudPlayer_EnsureOpenListRunning() {
        CloudPlayer_AsyncStepLeave(taskId, "ali_checking_openlist", false)
        out["message"] := "OpenList is not running"
        cb ? cb.Call(out) : 0
        return
    }
    CloudPlayer_AsyncStepLeave(taskId, "ali_checking_openlist", true)
    CloudPlayer_AsyncStepEnter(taskId, "ali_getting_token")
    CloudPlayer_SendImportProgress("Getting OpenList admin token...", taskId, "getting_token", 12)
    CloudPlayer_GetOpenListAdminTokenAsync((tokRet) => (
        CloudPlayer_ImportAliyunStorageAsync_OnToken(taskId, rt, mp, opts, out, tokRet, cb)
    ), 12000, taskId, "cp_import_ali_token")
}

CloudPlayer_ImportAliyunStorageAsync_OnToken(taskId, rt, mp, opts, out, tokRet, cb) {
    global g_CloudPlayerApiBase
    if CloudPlayer_IsTaskCancelled(taskId) || CloudPlayer_AsyncFlowTimedOut(CloudPlayer_AsyncFlowGet(taskId), "getting_token") {
        out["message"] := "cancelled"
        cb ? cb.Call(out) : 0
        return
    }
    if !(tokRet is Map) || !tokRet["ok"] {
        CloudPlayer_AsyncStepLeave(taskId, "ali_getting_token", false)
        out["message"] := (tokRet is Map && tokRet.Has("error") && tokRet["error"] != "") ? tokRet["error"] : "failed to get OpenList admin token"
        cb ? cb.Call(out) : 0
        return
    }
    adminToken := String(tokRet["token"])
    CloudPlayer_AsyncStepLeave(taskId, "ali_getting_token", true)
    out["authToken"] := adminToken
    headers := Map("Authorization", adminToken, "Content-Type", "application/json")
    CloudPlayer_SendImportProgress("Listing existing storages...", taskId, "listing_storage", 20)
    CloudPlayer_AsyncStepEnter(taskId, "ali_listing_storage")
    CloudPlayer_HttpJsonAsyncReq("GET", g_CloudPlayerApiBase . "/api/admin/storage/list", headers, "", (listRet) => (
        CloudPlayer_ImportAliyunStorageAsync_OnList(taskId, rt, mp, opts, out, headers, listRet, cb)
    ), taskId, "cp_import_ali_list_storage")
}

CloudPlayer_ImportAliyunStorageAsync_OnList(taskId, rt, mp, opts, out, headers, listRet, cb) {
    global g_CloudPlayerApiBase
    if CloudPlayer_IsTaskCancelled(taskId) || CloudPlayer_AsyncFlowTimedOut(CloudPlayer_AsyncFlowGet(taskId), "list_storage") {
        out["message"] := "cancelled"
        cb ? cb.Call(out) : 0
        return
    }
    if !listRet["ok"] {
        CloudPlayer_AsyncStepLeave(taskId, "ali_listing_storage", false)
        out["message"] := "failed to list storages: " . listRet["error"]
        cb ? cb.Call(out) : 0
        return
    }
    CloudPlayer_AsyncStepLeave(taskId, "ali_listing_storage", true)
    targetId := 0
    targetDriver := "AliyundriveOpen"
    if (listRet["json"] is Map && listRet["json"].Has("data")) {
        dataObj := listRet["json"]["data"]
        if (dataObj is Map && dataObj.Has("content") && dataObj["content"] is Array) {
            for _, row in dataObj["content"] {
                try rowPath := String(row.Has("mount_path") ? row["mount_path"] : "")
                catch {
                    rowPath := ""
                }
                if (rowPath = mp) {
                    try targetId := Integer(row.Has("id") ? row["id"] : 0)
                    catch {
                        targetId := 0
                    }
                    try targetDriver := String(row.Has("driver") ? row["driver"] : "AliyundriveOpen")
                    catch {
                        targetDriver := "AliyundriveOpen"
                    }
                    break
                }
            }
        }
    }
    if (targetDriver != "Aliyundrive" && targetDriver != "AliyundriveOpen")
        targetDriver := "AliyundriveOpen"
    cfg := CloudPlayer_BuildAliAdditionConfig(rt, targetDriver, opts)
    saveUrl := g_CloudPlayerApiBase . ((targetId > 0) ? "/api/admin/storage/update" : "/api/admin/storage/create")
    bodyObj := CloudPlayer_BuildAliStorageBody(mp, targetDriver, cfg["additionObj"], targetId)
    CloudPlayer_SendImportProgress((targetId > 0) ? "Updating Aliyun storage config..." : "Creating Aliyun storage config...", taskId, "saving_storage", 45)
    CloudPlayer_AsyncStepEnter(taskId, "ali_saving_storage")
    bodyJson := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(bodyObj), ["web_proxy", "enable_sign"])
    CloudPlayer_HttpJsonAsyncReq("POST", saveUrl, headers, bodyJson, (saveRet) => (
        CloudPlayer_ImportAliyunStorageAsync_OnSaved(taskId, mp, targetDriver, cfg, out, headers, saveRet, cb)
    ), taskId, "cp_import_ali_save_storage")
}

CloudPlayer_ImportAliyunStorageAsync_OnSaved(taskId, mp, targetDriver, cfg, out, headers, saveRet, cb) {
    global g_CloudPlayerApiBase
    if CloudPlayer_IsTaskCancelled(taskId) || CloudPlayer_AsyncFlowTimedOut(CloudPlayer_AsyncFlowGet(taskId), "save_storage") {
        out["message"] := "cancelled"
        cb ? cb.Call(out) : 0
        return
    }
    if !saveRet["ok"] {
        CloudPlayer_AsyncStepLeave(taskId, "ali_saving_storage", false)
        out["message"] := "save storage failed: " . saveRet["error"]
        cb ? cb.Call(out) : 0
        return
    }
    CloudPlayer_AsyncStepLeave(taskId, "ali_saving_storage", true)
    respMsg := ""
    try respMsg := String(saveRet["json"].Has("message") ? saveRet["json"]["message"] : "")
    catch {
        respMsg := ""
    }
    CloudPlayer_SendImportProgress("Verifying storage status...", taskId, "verifying_storage", 72)
    CloudPlayer_HttpJsonAsyncReq("GET", g_CloudPlayerApiBase . "/api/admin/storage/list", headers, "", (statusRet) => (
        CloudPlayer_ImportAliyunStorageAsync_OnStatus(taskId, mp, targetDriver, cfg, out, headers, statusRet, respMsg, cb)
    ), taskId, "cp_import_ali_status")
}

CloudPlayer_ImportAliyunStorageAsync_OnStatus(taskId, mp, targetDriver, cfg, out, headers, statusRet, respMsg, cb) {
    if CloudPlayer_IsTaskCancelled(taskId) || CloudPlayer_AsyncFlowTimedOut(CloudPlayer_AsyncFlowGet(taskId), "status_storage") {
        out["message"] := "cancelled"
        cb ? cb.Call(out) : 0
        return
    }
    statusHint := ""
    foundAfterSave := false
    if (statusRet["ok"] && statusRet["json"] is Map && statusRet["json"].Has("data")) {
        d2 := statusRet["json"]["data"]
        if (d2 is Map && d2.Has("content") && d2["content"] is Array) {
            for _, row2 in d2["content"] {
                try p2 := String(row2.Has("mount_path") ? row2["mount_path"] : "")
                catch {
                    p2 := ""
                }
                if (p2 = mp) {
                    foundAfterSave := true
                    try s2 := String(row2.Has("status") ? row2["status"] : "")
                    catch {
                        s2 := ""
                    }
                    if (s2 != "" && s2 != "work")
                        statusHint := s2
                    break
                }
            }
        }
    }
    if !foundAfterSave {
        out["message"] := "save returned success but mount path not found after refresh: " . mp
        cb ? cb.Call(out) : 0
        return
    }
    CloudPlayer_AsyncStepEnter(taskId, "ali_verifying_mount")
    CloudPlayer_VerifyMountListAsync(mp, headers, (verify) => (
        CloudPlayer_ImportAliyunStorageAsync_OnVerified(taskId, mp, targetDriver, cfg, out, headers, verify, statusHint, respMsg, cb)
    ), taskId)
}

CloudPlayer_ImportAliyunStorageAsync_OnVerified(taskId, mp, targetDriver, cfg, out, headers, verify, statusHint, respMsg, cb) {
    global g_CloudPlayerApiBase
    if CloudPlayer_IsTaskCancelled(taskId) || CloudPlayer_AsyncFlowTimedOut(CloudPlayer_AsyncFlowGet(taskId), "verify_mount") {
        out["message"] := "cancelled"
        cb ? cb.Call(out) : 0
        return
    }
    if !verify["ok"] {
        CloudPlayer_AsyncStepLeave(taskId, "ali_verifying_mount", false)
        out["message"] := "mount check failed: " . verify["message"]
        cb ? cb.Call(out) : 0
        return
    }
    CloudPlayer_AsyncStepLeave(taskId, "ali_verifying_mount", true)
    if (targetDriver = "AliyundriveOpen" && cfg["driveType"] = "resource" && verify["count"] = 0) {
        CloudPlayer_SendImportProgress("Resource drive is empty, retrying with drive_type=default...", taskId, "fallback_retry", 82)
        cfg["additionObj"]["drive_type"] := "default"
        bodyObj2 := CloudPlayer_BuildAliStorageBody(mp, targetDriver, cfg["additionObj"], 0)
        CloudPlayer_FindStorageByMountPathAsync(mp, headers, (findRet) => (
            CloudPlayer_ImportAliyunStorageAsync_OnFallbackFind(taskId, mp, targetDriver, out, headers, bodyObj2, findRet, statusHint, respMsg, cb)
        ), taskId)
        return
    }
    CloudPlayer_ImportAliyunStorageAsync_FinishSuccess(taskId, targetDriver, out, verify, statusHint, respMsg, cb)
}

CloudPlayer_ImportAliyunStorageAsync_OnFallbackFind(taskId, mp, targetDriver, out, headers, bodyObj2, findRet, statusHint, respMsg, cb) {
    global g_CloudPlayerApiBase
    if CloudPlayer_IsTaskCancelled(taskId) || CloudPlayer_AsyncFlowTimedOut(CloudPlayer_AsyncFlowGet(taskId), "fallback_find") {
        out["message"] := "cancelled"
        cb ? cb.Call(out) : 0
        return
    }
    if (findRet is Map && findRet["ok"] && findRet["rowId"] > 0)
        bodyObj2["id"] := findRet["rowId"]
    bodyJson2 := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(bodyObj2), ["web_proxy", "enable_sign"])
    CloudPlayer_HttpJsonAsyncReq("POST", g_CloudPlayerApiBase . "/api/admin/storage/update", headers, bodyJson2, (saveRet2) => (
        CloudPlayer_ImportAliyunStorageAsync_OnFallbackSaved(taskId, mp, targetDriver, out, headers, saveRet2, statusHint, respMsg, cb)
    ), taskId, "cp_import_ali_fallback")
}

CloudPlayer_ImportAliyunStorageAsync_OnFallbackSaved(taskId, mp, targetDriver, out, headers, saveRet2, statusHint, respMsg, cb) {
    if CloudPlayer_IsTaskCancelled(taskId) || CloudPlayer_AsyncFlowTimedOut(CloudPlayer_AsyncFlowGet(taskId), "fallback_save") {
        out["message"] := "cancelled"
        cb ? cb.Call(out) : 0
        return
    }
    if !saveRet2["ok"] {
        out["message"] := "save storage failed: " . saveRet2["error"]
        cb ? cb.Call(out) : 0
        return
    }
    CloudPlayer_VerifyMountListAsync(mp, headers, (verify2) => (
        !verify2["ok"]
            ? (out["message"] := "fallback mount check failed: " . verify2["message"], cb ? cb.Call(out) : 0)
            : CloudPlayer_ImportAliyunStorageAsync_FinishSuccess(taskId, targetDriver, out, verify2, statusHint, respMsg, cb)
    ), taskId)
}

CloudPlayer_ImportAliyunStorageAsync_FinishSuccess(taskId, targetDriver, out, verify, statusHint, respMsg, cb) {
    out["ok"] := true
    out["driver"] := targetDriver
    out["message"] := (statusHint != "")
        ? "saved, but init status: " . statusHint
        : ((respMsg != "") ? respMsg : "import success")
    if (verify["count"] = 0)
        out["message"] := out["message"] . " (mount is reachable but empty)"
    CloudPlayer_SendImportProgress("Import completed.", taskId, "done", 100)
    cb ? cb.Call(out) : 0
}

CloudPlayer_BuildAliAdditionConfig(rt, targetDriver, opts := 0) {
    rootFolderId := "root"
    driveType := "default"
    useOnlineApi := true
    alipanType := "default"
    apiUrlAddress := "https://api.oplist.org/alicloud/renewapi"
    clientId := ""
    clientSecret := ""
    if (opts is Map) {
        try {
            if (opts.Has("rootFolderId") && Trim(String(opts["rootFolderId"])) != "")
                rootFolderId := Trim(String(opts["rootFolderId"]))
            if (opts.Has("driveType") && Trim(String(opts["driveType"])) != "")
                driveType := Trim(String(opts["driveType"]))
            if (opts.Has("alipanType") && Trim(String(opts["alipanType"])) != "")
                alipanType := Trim(String(opts["alipanType"]))
            if (opts.Has("apiUrlAddress") && Trim(String(opts["apiUrlAddress"])) != "")
                apiUrlAddress := Trim(String(opts["apiUrlAddress"]))
            if (opts.Has("clientId"))
                clientId := Trim(String(opts["clientId"]))
            if (opts.Has("clientSecret"))
                clientSecret := Trim(String(opts["clientSecret"]))
            if (opts.Has("useOnlineApi"))
                useOnlineApi := CloudPlayer_ToBool(opts["useOnlineApi"], true)
        } catch {
        }
    }
    additionObj := (targetDriver = "AliyundriveOpen")
        ? Map(
            "drive_type", driveType, "root_folder_id", rootFolderId, "refresh_token", rt, "order_by", "", "order_direction", "",
            "use_online_api", useOnlineApi, "alipan_type", alipanType, "api_url_address", apiUrlAddress,
            "client_id", clientId, "client_secret", clientSecret, "remove_way", "", "rapid_upload", false,
            "internal_upload", false, "livp_download_format", "jpeg"
        )
        : Map("root_folder_id", rootFolderId, "refresh_token", rt, "order_by", "", "order_direction", "", "rapid_upload", false, "internal_upload", false)
    return Map("additionObj", additionObj, "driveType", driveType)
}

CloudPlayer_BuildAliStorageBody(mp, targetDriver, additionObj, targetId := 0) {
    additionJson := Jxon_Dump(additionObj)
    additionJson := CloudPlayer_JsonForceBoolLiterals(additionJson, ["use_online_api", "rapid_upload", "internal_upload"])
    bodyObj := Map(
        "mount_path", mp, "order", 0, "remark", "", "cache_expiration", 30, "web_proxy", true,
        "webdav_policy", "302_redirect", "down_proxy_url", "", "extract_folder", "", "enable_sign", false,
        "driver", targetDriver, "order_by", "", "order_direction", "", "status", "work", "addition", additionJson
    )
    if (targetId > 0)
        bodyObj["id"] := targetId
    return bodyObj
}

CloudPlayer_RunStorageImport(taskId, provider, token, mountPath, driver, opts) {
    global g_CloudPlayerWv2, g_CloudPlayerImportBusy
    ctx := CloudPlayer_AsyncFlowStart(taskId, provider, mountPath, driver, opts)
    CloudPlayer_AsyncLog("cloudplayer_async_step_enter", "task_id=" . taskId . " phase=import_sync_bridge route=" . (CloudPlayer_UseAsyncImport() ? "async_flow" : "await"))
    if CloudPlayer_UseAsyncImport() {
        CloudPlayer_ImportStorageGenericAsync(taskId, provider, token, mountPath, driver, opts, (result) => (
            CloudPlayer_FinishImportTask(taskId, result["ok"], result["message"], provider, result["mountPath"], result["driver"], result.Has("authToken") ? result["authToken"] : "")
        ))
        return
    }
    if CloudPlayer_IsTaskCancelled(taskId) {
        CloudPlayer_FinishImportTask(taskId, false, "cancelled", provider, mountPath, driver, "")
        return
    }
    result := 0
    try {
        result := CloudPlayer_ImportStorageGeneric(provider, token, mountPath, driver, opts, taskId)
    } catch as e {
        result := Map(
            "ok", false,
            "message", "import runtime error: " . e.Message,
            "mountPath", mountPath,
            "driver", driver
        )
    }
    if !(result is Map) {
        result := Map("ok", false, "message", "import returned invalid result", "mountPath", mountPath, "driver", driver)
    }
    if !result.Has("mountPath")
        result["mountPath"] := mountPath
    if !result.Has("driver")
        result["driver"] := driver
    if !result.Has("ok")
        result["ok"] := false
    if !result.Has("message")
        result["message"] := result["ok"] ? "import success" : "import failed"
    if CloudPlayer_IsTaskCancelled(taskId) {
        CloudPlayer_FinishImportTask(taskId, false, "cancelled", provider, result["mountPath"], result["driver"], "")
        return
    }
    CloudPlayer_FinishImportTask(taskId, result["ok"], result["message"], provider, result["mountPath"], result["driver"], result.Has("authToken") ? result["authToken"] : "")
}

CloudPlayer_ImportStorageGenericAsync(taskId, provider, token, mountPath := "/", driver := "AliyundriveOpen", opts := 0, doneCb := 0) {
    global g_CloudPlayerApiBase
    cb := IsObject(doneCb) ? doneCb : 0
    providerKey := StrLower(Trim(String(provider)))
    drvInput := Trim(String(driver))
    if (drvInput = "" || drvInput = "Unknown")
        drvInput := CloudPlayer_DefaultDriverByProvider(providerKey)
    if (drvInput = "AliyundriveOpen" || drvInput = "Aliyundrive") {
        CloudPlayer_ImportAliyunStorageAsync(taskId, token, mountPath, opts, cb)
        return
    }
    out := Map("ok", false, "message", "", "mountPath", "", "driver", drvInput, "authToken", "")
    tk := CloudPlayer_NormalizeProviderToken(token)
    mp := Trim(String(mountPath))
    if (mp = "")
        mp := "/"
    if (SubStr(mp, 1, 1) != "/")
        mp := "/" . mp
    out["mountPath"] := mp
    if (tk = "") {
        out["message"] := "token is empty"
        cb ? cb.Call(out) : 0
        return
    }
    if CloudPlayer_IsTaskCancelled(taskId) || CloudPlayer_AsyncFlowTimedOut(CloudPlayer_AsyncFlowGet(taskId), "start") {
        out["message"] := "cancelled"
        cb ? cb.Call(out) : 0
        return
    }
    CloudPlayer_AsyncStepEnter(taskId, "generic_checking_openlist")
    CloudPlayer_SendImportProgress("Checking OpenList status...", taskId, "checking_openlist", 5)
    if !CloudPlayer_EnsureOpenListRunning() {
        CloudPlayer_AsyncStepLeave(taskId, "generic_checking_openlist", false)
        out["message"] := "OpenList is not running"
        cb ? cb.Call(out) : 0
        return
    }
    CloudPlayer_AsyncStepLeave(taskId, "generic_checking_openlist", true)
    CloudPlayer_AsyncStepEnter(taskId, "generic_getting_token")
    CloudPlayer_SendImportProgress("Getting OpenList admin token...", taskId, "getting_token", 12)
    CloudPlayer_GetOpenListAdminTokenAsync((tokRet) => (
        CloudPlayer_ImportStorageGenericAsync_OnToken(taskId, providerKey, tk, mp, drvInput, opts, out, tokRet, cb)
    ), 12000, taskId, "cp_import_generic_token")
}

CloudPlayer_ImportStorageGenericAsync_OnToken(taskId, providerKey, tk, mp, drvInput, opts, out, tokRet, cb) {
    global g_CloudPlayerApiBase
    if CloudPlayer_IsTaskCancelled(taskId) || CloudPlayer_AsyncFlowTimedOut(CloudPlayer_AsyncFlowGet(taskId), "getting_token") {
        out["message"] := "cancelled"
        cb ? cb.Call(out) : 0
        return
    }
    if !(tokRet is Map) || !tokRet["ok"] {
        CloudPlayer_AsyncStepLeave(taskId, "generic_getting_token", false)
        out["message"] := (tokRet is Map && tokRet.Has("error") && tokRet["error"] != "") ? tokRet["error"] : "failed to get OpenList admin token"
        cb ? cb.Call(out) : 0
        return
    }
    adminToken := String(tokRet["token"])
    CloudPlayer_AsyncStepLeave(taskId, "generic_getting_token", true)
    out["authToken"] := adminToken
    headers := Map("Authorization", adminToken, "Content-Type", "application/json")
    CloudPlayer_SendImportProgress("Listing existing storages...", taskId, "listing_storage", 20)
    CloudPlayer_AsyncStepEnter(taskId, "generic_listing_storage")
    CloudPlayer_HttpJsonAsyncReq("GET", g_CloudPlayerApiBase . "/api/admin/storage/list", headers, "", (listRet) => (
        CloudPlayer_ImportStorageGenericAsync_OnList(taskId, providerKey, tk, mp, drvInput, opts, out, headers, listRet, cb)
    ), taskId, "cp_import_list_storage")
}

CloudPlayer_ImportStorageGenericAsync_OnList(taskId, providerKey, tk, mp, drvInput, opts, out, headers, listRet, cb) {
    global g_CloudPlayerApiBase
    if CloudPlayer_IsTaskCancelled(taskId) || CloudPlayer_AsyncFlowTimedOut(CloudPlayer_AsyncFlowGet(taskId), "list_storage") {
        out["message"] := "cancelled"
        cb ? cb.Call(out) : 0
        return
    }
    if !listRet["ok"] {
        CloudPlayer_AsyncStepLeave(taskId, "generic_listing_storage", false)
        out["message"] := "failed to list storages: " . listRet["error"]
        cb ? cb.Call(out) : 0
        return
    }
    CloudPlayer_AsyncStepLeave(taskId, "generic_listing_storage", true)
    targetId := 0
    existingDriver := ""
    if (listRet["json"] is Map && listRet["json"].Has("data")) {
        dataObj := listRet["json"]["data"]
        if (dataObj is Map && dataObj.Has("content") && dataObj["content"] is Array) {
            for _, row in dataObj["content"] {
                try rowPath := String(row.Has("mount_path") ? row["mount_path"] : "")
                catch {
                    rowPath := ""
                }
                if (rowPath = mp) {
                    try targetId := Integer(row.Has("id") ? row["id"] : 0)
                    catch {
                        targetId := 0
                    }
                    try existingDriver := String(row.Has("driver") ? row["driver"] : "")
                    catch {
                        existingDriver := ""
                    }
                    break
                }
            }
        }
    }
    CloudPlayer_ImportStorageGenericAsync_PrepareTarget(taskId, providerKey, mp, drvInput, targetId, existingDriver, headers, (prep) => (
        CloudPlayer_ImportStorageGenericAsync_OnPrepared(taskId, providerKey, tk, mp, opts, out, headers, prep, cb)
    ))
}

CloudPlayer_ImportStorageGenericAsync_PrepareTarget(taskId, providerKey, mp, drvInput, targetId, existingDriver, headers, callback := 0) {
    cb := IsObject(callback) ? callback : 0
    prep := Map(
        "ok", true,
        "targetId", targetId,
        "driver", drvInput,
        "migrated", false,
        "migratedFromDriver", "",
        "migratedToDriver", "",
        "error", ""
    )
    if (targetId > 0 && existingDriver != "") {
        prep["driver"] := existingDriver
        if (providerKey = "quark" && StrLower(existingDriver) != StrLower(drvInput)) {
            if !(CloudPlayer_IsQuarkDriver(existingDriver) && CloudPlayer_IsQuarkDriver(drvInput)) {
                prep["ok"] := false
                prep["error"] := "existing mount path uses driver=" . existingDriver . ", but current import expects " . drvInput . ". Please delete old mount first or use a new mount path."
                cb ? cb.Call(prep) : 0
                return
            }
            CloudPlayer_SendImportProgress("Detected mismatched Quark driver (" . existingDriver . " -> " . drvInput . "), replacing mount...", taskId, "fallback_retry", 30)
            CloudPlayer_DeleteStorageByIdAsync(targetId, headers, (delRet) => (
                !delRet["ok"]
                    ? (prep["ok"] := false, prep["error"] := "failed to auto-replace legacy Quark mount: " . delRet["error"], cb ? cb.Call(prep) : 0)
                    : (prep["targetId"] := 0, prep["driver"] := drvInput, prep["migrated"] := true, prep["migratedFromDriver"] := existingDriver, prep["migratedToDriver"] := drvInput, cb ? cb.Call(prep) : 0)
            ), taskId)
            return
        }
        if (providerKey = "pan123" && StrLower(existingDriver) != StrLower(drvInput)) {
            if !(CloudPlayer_IsPan123Driver(existingDriver) && CloudPlayer_IsPan123Driver(drvInput)) {
                prep["ok"] := false
                prep["error"] := "existing mount path uses driver=" . existingDriver . ", but current import expects " . drvInput . ". Please delete old mount first or use a new mount path."
                cb ? cb.Call(prep) : 0
                return
            }
            CloudPlayer_SendImportProgress("Detected mismatched 123Pan driver (" . existingDriver . " -> " . drvInput . "), replacing mount...", taskId, "fallback_retry", 30)
            CloudPlayer_DeleteStorageByIdAsync(targetId, headers, (delRet2) => (
                !delRet2["ok"]
                    ? (prep["ok"] := false, prep["error"] := "failed to auto-replace legacy 123Pan mount: " . delRet2["error"], cb ? cb.Call(prep) : 0)
                    : (prep["targetId"] := 0, prep["driver"] := drvInput, prep["migrated"] := true, prep["migratedFromDriver"] := existingDriver, prep["migratedToDriver"] := drvInput, cb ? cb.Call(prep) : 0)
            ), taskId)
            return
        }
    }
    cb ? cb.Call(prep) : 0
}

CloudPlayer_ImportStorageGenericAsync_OnPrepared(taskId, providerKey, tk, mp, opts, out, headers, prep, cb) {
    global g_CloudPlayerApiBase
    if CloudPlayer_IsTaskCancelled(taskId) || CloudPlayer_AsyncFlowTimedOut(CloudPlayer_AsyncFlowGet(taskId), "prepare_target") {
        out["message"] := "cancelled"
        cb ? cb.Call(out) : 0
        return
    }
    if !(prep is Map) || !prep["ok"] {
        out["message"] := (prep is Map && prep.Has("error")) ? String(prep["error"]) : "prepare target failed"
        cb ? cb.Call(out) : 0
        return
    }
    targetId := prep["targetId"]
    drv := prep["driver"]
    saveUrl := g_CloudPlayerApiBase . ((targetId > 0) ? "/api/admin/storage/update" : "/api/admin/storage/create")
    CloudPlayer_BuildGenericAdditionAsync(providerKey, tk, opts, drv, taskId, (addRes) => (
        CloudPlayer_ImportStorageGenericAsync_OnAddition(taskId, providerKey, tk, mp, drv, targetId, out, headers, saveUrl, addRes, prep, opts, cb)
    ))
}

CloudPlayer_ImportStorageGenericAsync_OnAddition(taskId, providerKey, tk, mp, drv, targetId, out, headers, saveUrl, addRes, prep, opts, cb) {
    global g_CloudPlayerApiBase
    if CloudPlayer_IsTaskCancelled(taskId) || CloudPlayer_AsyncFlowTimedOut(CloudPlayer_AsyncFlowGet(taskId), "build_addition") {
        out["message"] := "cancelled"
        cb ? cb.Call(out) : 0
        return
    }
    if !(addRes is Map) || !addRes["ok"] {
        out["message"] := (addRes is Map && addRes.Has("error")) ? String(addRes["error"]) : "failed to build addition"
        cb ? cb.Call(out) : 0
        return
    }
    additionObj := addRes["addition"]
    additionJson := CloudPlayer_JsonForceBoolLiterals(
        Jxon_Dump(additionObj),
        ["use_online_api", "use_dynamic_upload_api", "low_bandwith_upload_mode", "only_list_video_file", "is_sharepoint", "disable_disk_usage", "enable_direct_upload"]
    )
    bodyObj := Map(
        "mount_path", mp, "order", 0, "remark", "", "cache_expiration", 30,
        "web_proxy", true, "webdav_policy", "302_redirect", "down_proxy_url", "",
        "extract_folder", "", "enable_sign", false, "driver", drv, "order_by", "",
        "order_direction", "", "status", "work", "addition", additionJson
    )
    if (targetId > 0)
        bodyObj["id"] := targetId
    CloudPlayer_SendImportProgress((targetId > 0) ? "Updating storage config (" . drv . ")..." : "Creating storage config (" . drv . ")...", taskId, "saving_storage", 45)
    CloudPlayer_AsyncStepEnter(taskId, "generic_saving_storage")
    bodyJson := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(bodyObj), ["web_proxy", "enable_sign"])
    CloudPlayer_HttpJsonAsyncReq("POST", saveUrl, headers, bodyJson, (saveRet) => (
        CloudPlayer_ImportStorageGenericAsync_OnSaved(taskId, providerKey, tk, mp, drv, targetId, out, headers, saveRet, prep, opts, cb)
    ), taskId, "cp_import_save_storage")
}

CloudPlayer_ImportStorageGenericAsync_OnSaved(taskId, providerKey, tk, mp, drv, targetId, out, headers, saveRet, prep, opts, cb) {
    if CloudPlayer_IsTaskCancelled(taskId) || CloudPlayer_AsyncFlowTimedOut(CloudPlayer_AsyncFlowGet(taskId), "save_storage") {
        out["message"] := "cancelled"
        cb ? cb.Call(out) : 0
        return
    }
    if !saveRet["ok"] {
        CloudPlayer_AsyncStepLeave(taskId, "generic_saving_storage", false)
        if (providerKey = "pan123" && targetId > 0
            && (InStr(StrLower(String(saveRet["error"])), "no driver named") || InStr(StrLower(String(saveRet["error"])), "failed get driver new"))) {
            CloudPlayer_SendImportProgress("Detected unavailable stored 123 driver alias, recreating mount...", taskId, "fallback_retry", 56)
            CloudPlayer_DeleteStorageByIdAsync(targetId, headers, (delRet) => (
                !delRet["ok"]
                    ? (out["message"] := "save storage failed: " . saveRet["error"], cb ? cb.Call(out) : 0)
                    : CloudPlayer_ImportStorageGenericAsync_RecreateAfterDelete(taskId, providerKey, tk, mp, drv, out, headers, prep, opts, cb)
            ), taskId)
            return
        }
        out["message"] := "save storage failed: " . saveRet["error"]
        cb ? cb.Call(out) : 0
        return
    }
    CloudPlayer_AsyncStepLeave(taskId, "generic_saving_storage", true)
    CloudPlayer_SendImportProgress("Verifying mount...", taskId, "verifying_storage", 78)
    CloudPlayer_AsyncStepEnter(taskId, "generic_verifying_mount")
    CloudPlayer_VerifyMountListAsync(mp, headers, (verify) => (
        CloudPlayer_ImportStorageGenericAsync_OnVerified(taskId, providerKey, tk, mp, drv, out, headers, verify, prep, opts, cb)
    ), taskId)
}

CloudPlayer_ImportStorageGenericAsync_RecreateAfterDelete(taskId, providerKey, tk, mp, drv, out, headers, prep, opts, cb) {
    global g_CloudPlayerApiBase
    CloudPlayer_BuildGenericAdditionAsync(providerKey, tk, opts, drv, taskId, (addRes) => (
        !addRes["ok"]
            ? (out["message"] := addRes["error"], cb ? cb.Call(out) : 0)
            : CloudPlayer_ImportStorageGenericAsync_RecreateWithAddition(taskId, providerKey, mp, drv, out, headers, addRes["addition"], prep, opts, cb)
    ))
}

CloudPlayer_ImportStorageGenericAsync_RecreateWithAddition(taskId, providerKey, mp, drv, out, headers, additionObj, prep, opts, cb) {
    global g_CloudPlayerApiBase
    additionJson := CloudPlayer_JsonForceBoolLiterals(
        Jxon_Dump(additionObj),
        ["use_online_api", "use_dynamic_upload_api", "low_bandwith_upload_mode", "only_list_video_file", "is_sharepoint", "disable_disk_usage", "enable_direct_upload"]
    )
    bodyObj := Map(
        "mount_path", mp, "order", 0, "remark", "", "cache_expiration", 30,
        "web_proxy", true, "webdav_policy", "302_redirect", "down_proxy_url", "",
        "extract_folder", "", "enable_sign", false, "driver", drv, "order_by", "",
        "order_direction", "", "status", "work", "addition", additionJson
    )
    bodyJson := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(bodyObj), ["web_proxy", "enable_sign"])
    CloudPlayer_HttpJsonAsyncReq("POST", g_CloudPlayerApiBase . "/api/admin/storage/create", headers, bodyJson, (saveRet2) => (
        !saveRet2["ok"]
            ? (out["message"] := "save storage failed: " . saveRet2["error"], cb ? cb.Call(out) : 0)
            : CloudPlayer_VerifyMountListAsync(mp, headers, (verify) => CloudPlayer_ImportStorageGenericAsync_OnVerified(taskId, providerKey, "", mp, drv, out, headers, verify, prep, opts, cb), taskId)
    ), taskId, "cp_import_save_recreate")
}

CloudPlayer_ImportStorageGenericAsync_OnVerified(taskId, providerKey, tk, mp, drv, out, headers, verify, prep, opts, cb) {
    global g_CloudPlayerApiBase
    if CloudPlayer_IsTaskCancelled(taskId) || CloudPlayer_AsyncFlowTimedOut(CloudPlayer_AsyncFlowGet(taskId), "verify_mount") {
        out["message"] := "cancelled"
        cb ? cb.Call(out) : 0
        return
    }
    if !verify["ok"] {
        if (providerKey = "onedrive" && InStr(StrLower(verify["message"]), "segment 'root:'")) {
            CloudPlayer_SendImportProgress("OneDrive root path fallback: retrying with empty root_folder_path...", taskId, "fallback_retry", 86)
            CloudPlayer_FindStorageByMountPathAsync(mp, headers, (findRet) => (
                CloudPlayer_ImportStorageGenericAsync_OnedriveFallback(taskId, providerKey, tk, mp, drv, out, headers, findRet, prep, opts, cb)
            ), taskId)
            return
        }
        out["message"] := "mount check failed: " . verify["message"]
        CloudPlayer_AsyncStepLeave(taskId, "generic_verifying_mount", false)
        cb ? cb.Call(out) : 0
        return
    }
    CloudPlayer_AsyncStepLeave(taskId, "generic_verifying_mount", true)
    out["ok"] := true
    out["driver"] := drv
    out["message"] := "import success"
    if (prep is Map && prep["migrated"]) {
        migrateName := (providerKey = "quark") ? "Quark" : ((providerKey = "pan123") ? "123Pan" : "legacy")
        out["message"] := out["message"] . " (" . migrateName . " mount auto-migrated: " . prep["migratedFromDriver"] . " -> " . prep["migratedToDriver"] . ")"
    }
    if (verify["count"] = 0)
        out["message"] := out["message"] . " (mount is reachable but empty)"
    CloudPlayer_SendImportProgress("Import completed.", taskId, "done", 100)
    cb ? cb.Call(out) : 0
}

CloudPlayer_ImportStorageGenericAsync_OnedriveFallback(taskId, providerKey, tk, mp, drv, out, headers, findRet, prep, opts, cb) {
    global g_CloudPlayerApiBase
    if !(findRet is Map) || !findRet["ok"] || findRet["rowId"] <= 0 {
        out["message"] := "mount check failed: Resource not found for the segment 'root:'"
        cb ? cb.Call(out) : 0
        return
    }
    fixId := findRet["rowId"]
    bodyObj2 := Map(
        "mount_path", mp, "order", 0, "remark", "", "cache_expiration", 30,
        "web_proxy", true, "webdav_policy", "302_redirect", "down_proxy_url", "",
        "extract_folder", "", "enable_sign", false, "driver", drv, "order_by", "",
        "order_direction", "", "status", "work", "id", fixId
    )
    add2 := CloudPlayer_BuildGenericAddition(providerKey, tk, opts, drv)
    try {
        add2["root_folder_path"] := ""
        add2["RootFolderPath"] := ""
    } catch {
    }
    try add2.Delete("root_folder_id")
    catch {
    }
    addJson2 := CloudPlayer_JsonForceBoolLiterals(
        Jxon_Dump(add2),
        ["use_online_api", "use_dynamic_upload_api", "low_bandwith_upload_mode", "only_list_video_file", "is_sharepoint", "disable_disk_usage", "enable_direct_upload"]
    )
    bodyObj2["addition"] := addJson2
    bodyJsonFallback := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(bodyObj2), ["web_proxy", "enable_sign"])
    CloudPlayer_HttpJsonAsyncReq("POST", g_CloudPlayerApiBase . "/api/admin/storage/update", headers, bodyJsonFallback, (saveRetFallback) => (
        !saveRetFallback["ok"]
            ? (out["message"] := "mount check failed: Resource not found for the segment 'root:'", cb ? cb.Call(out) : 0)
            : CloudPlayer_VerifyMountListAsync(mp, headers, (verify2) => (
                !verify2["ok"]
                    ? (out["message"] := "mount check failed: " . verify2["message"], cb ? cb.Call(out) : 0)
                    : (out["ok"] := true, out["driver"] := drv, out["message"] := "import success (onedrive root path fallback applied)" . (verify2["count"] = 0 ? " (mount is reachable but empty)" : ""), CloudPlayer_SendImportProgress("Import completed with root path fallback.", taskId, "done", 100), cb ? cb.Call(out) : 0)
            ), taskId)
    ), taskId, "cp_import_onedrive_fallback")
}

CloudPlayer_EnsureOpenListRunning() {
    if CloudPlayer_IsOpenListRunning()
        return true
    return CloudPlayer_StartOpenList()
}

CloudPlayer_StartOpenList() {
    global g_CloudPlayerOpenListPid
    exe := CloudPlayer_FindOpenListExe()
    if (exe = "") {
        if !CloudPlayer_DownloadOpenListExe()
            return false
        exe := CloudPlayer_FindOpenListExe()
        if (exe = "")
            return false
    }

    if CloudPlayer_IsOpenListRunning()
        return true

    workdir := CloudPlayer_GetWorkDir(exe)

    ; Prefer `server` subcommand for OpenList/AList.
    try Run('"' . exe . '" server', workdir, "Hide", &pid)
    catch {
        pid := 0
        try Run('"' . exe . '"', workdir, "Hide", &pid)
        catch {
            pid := 0
        }
    }
    g_CloudPlayerOpenListPid := pid

    Loop 18 {
        if CloudPlayer_IsOpenListRunning()
            return true
        Sleep(250)
    }
    return CloudPlayer_IsOpenListRunning()
}

CloudPlayer_FindOpenListExe() {
    candidates := [
        A_ScriptDir "\tools\openlist\openlist.exe",
        A_ScriptDir "\tools\openlist\alist.exe",
        A_ScriptDir "\tools\openlist.exe",
        A_ScriptDir "\tools\alist.exe",
        A_ScriptDir "\openlist.exe",
        A_ScriptDir "\alist.exe"
    ]
    for _, p in candidates {
        if FileExist(p)
            return p
    }
    return ""
}

CloudPlayer_StaleDomain(kind) {
    return "cloudplayer:" . Trim(String(kind))
}

CloudPlayer_MarkLatestReq(kind, reqId) {
    global g_CloudPlayerLatestReq, g_CloudPlayerActiveHttpReq
    k := Trim(String(kind))
    rid := Trim(String(reqId))
    if (k = "" || rid = "")
        return
    if (g_CloudPlayerActiveHttpReq is Map && g_CloudPlayerActiveHttpReq.Has(k)) {
        oldRid := Trim(String(g_CloudPlayerActiveHttpReq[k]))
        if (oldRid != "" && oldRid != rid && FuncExists("CoreAsyncHttp_Cancel")) {
            try {
                n := CoreAsyncHttp_Cancel(oldRid)
                if (n > 0)
                    CoreAsyncHttp_Log("cloudplayer_cancel_superseded", "kind=" . k . " old_req_id=" . oldRid . " new_req_id=" . rid)
            }
        }
    }
    g_CloudPlayerLatestReq[k] := rid
    g_CloudPlayerActiveHttpReq[k] := rid
    AsyncGuardrails_UpdateLatest(CloudPlayer_StaleDomain(k), rid)
}

CloudPlayer_IsStaleReq(kind, reqId) {
    k := Trim(String(kind))
    rid := Trim(String(reqId))
    if (k = "" || rid = "")
        return false
    return AsyncGuardrails_ShouldDropStale(CloudPlayer_StaleDomain(k), rid)
}

CloudPlayer_QueuePayload(payload, reqId := "", phase := "", errorCode := "") {
    global g_CloudPlayerWv2, g_CloudPlayerMainThreadId, g_CloudPlayerUiOutbox
    if !g_CloudPlayerWv2
        return
    out := AsyncGuardrails_AttachMeta(payload, reqId, phase, errorCode)
    if !CloudPlayer_IsMainThread() {
        Critical "On"
        try g_CloudPlayerUiOutbox.Push(out)
        finally Critical "Off"
        try SetTimer(CloudPlayer_FlushUiOutbox, -10)
        return
    }
    try WebView_QueuePayload(g_CloudPlayerWv2, out)
}

CloudPlayer_FlushUiOutbox(*) {
    global g_CloudPlayerUiOutbox, g_CloudPlayerDlThreadRunning, g_CloudPlayerWv2
    batch := []
    Critical "On"
    try {
        if (g_CloudPlayerUiOutbox is Array) && g_CloudPlayerUiOutbox.Length > 0
            batch := g_CloudPlayerUiOutbox.Clone()
        g_CloudPlayerUiOutbox := []
    } finally Critical "Off"
    for _, out in batch {
        try {
            if g_CloudPlayerWv2
                WebView_QueuePayload(g_CloudPlayerWv2, out)
        } catch {
        }
    }
    if g_CloudPlayerDlThreadRunning
        SetTimer(CloudPlayer_FlushUiOutbox, 80)
    else
        SetTimer(CloudPlayer_FlushUiOutbox, 0)
}

CloudPlayer_MarkDownloadCancelled(reqId) {
    global g_CloudPlayerDownloadCancel
    rid := Trim(String(reqId))
    if (rid = "")
        return false
    g_CloudPlayerDownloadCancel[rid] := true
    return true
}

CloudPlayer_ClearDownloadCancelled(reqId) {
    global g_CloudPlayerDownloadCancel
    rid := Trim(String(reqId))
    if (rid = "")
        return
    try g_CloudPlayerDownloadCancel.Delete(rid)
}

CloudPlayer_IsDownloadCancelled(reqId) {
    global g_CloudPlayerDownloadCancel
    rid := Trim(String(reqId))
    if (rid = "")
        return false
    return g_CloudPlayerDownloadCancel.Has(rid) && !!g_CloudPlayerDownloadCancel[rid]
}

CloudPlayer_NewTaskId(prefix := "task") {
    return String(prefix) . "_" . A_Now . "_" . Random(1000, 999999)
}

CloudPlayer_StartImportTask(taskId, provider := "") {
    global g_CloudPlayerImportTask
    g_CloudPlayerImportTask := Map(
        "active", true,
        "taskId", String(taskId),
        "cancelled", false,
        "provider", String(provider)
    )
}

CloudPlayer_CancelImportTask(taskId := "") {
    global g_CloudPlayerImportTask, g_CloudPlayerAsyncFlows
    if !(g_CloudPlayerImportTask is Map) || !g_CloudPlayerImportTask.Has("active") || !g_CloudPlayerImportTask["active"]
        return false
    rid := Trim(String(taskId))
    cur := String(g_CloudPlayerImportTask["taskId"])
    if (rid != "" && rid != cur)
        return false
    g_CloudPlayerImportTask["cancelled"] := true
    if (cur != "" && g_CloudPlayerAsyncFlows.Has(cur)) {
        try g_CloudPlayerAsyncFlows[cur]["cancelled"] := true
    }
    return true
}

CloudPlayer_IsTaskCancelled(taskId) {
    global g_CloudPlayerImportTask
    if !(g_CloudPlayerImportTask is Map) || !g_CloudPlayerImportTask.Has("active") || !g_CloudPlayerImportTask["active"]
        return true
    if (String(g_CloudPlayerImportTask["taskId"]) != String(taskId))
        return true
    return !!g_CloudPlayerImportTask["cancelled"]
}

CloudPlayer_FinishImportTask(taskId, ok, message, provider, mountPath, driver, authToken := "") {
    global g_CloudPlayerWv2, g_CloudPlayerImportBusy, g_CloudPlayerImportTask
    tid := String(taskId)
    ; stale task result must not override a newer active task
    if (g_CloudPlayerImportTask is Map
        && g_CloudPlayerImportTask.Has("active")
        && g_CloudPlayerImportTask["active"]
        && g_CloudPlayerImportTask.Has("taskId")
        && String(g_CloudPlayerImportTask["taskId"]) != tid) {
        try CoreAsyncHttp_Log("cloudplayer_drop_stale_req", "kind=import_result task_id=" . tid . " current=" . String(g_CloudPlayerImportTask["taskId"]))
        return
    }
    ph := ok ? "done" : ((String(message) = "cancelled") ? "cancelled" : "error")
    errCode := ""
    if !ok {
        low := StrLower(String(message))
        if (low = "cancelled")
            errCode := "cancelled"
        else if InStr(low, "timeout")
            errCode := "timeout"
        else if InStr(low, "token")
            errCode := "auth_token_failed"
        else if InStr(low, "mount check failed")
            errCode := "mount_verify_failed"
        else
            errCode := "import_failed"
    }
    CloudPlayer_QueuePayload(Map(
        "type", "cloudplayer_import_result",
        "ok", !!ok,
        "taskId", tid,
        "message", String(message),
        "provider", String(provider),
        "mountPath", String(mountPath),
        "driver", String(driver),
        "authToken", String(authToken)
    ), tid, ph, errCode)
    g_CloudPlayerImportBusy := false
    if (g_CloudPlayerImportTask is Map)
        g_CloudPlayerImportTask["active"] := false
    CloudPlayer_AsyncFlowDrop(tid)
}

CloudPlayer_CheckImportCancelled(taskId, &out, message := "cancelled") {
    if (Trim(String(taskId)) = "")
        return false
    if !CloudPlayer_IsTaskCancelled(taskId)
        return false
    if (out is Map) {
        out["ok"] := false
        out["message"] := String(message)
    }
    return true
}

CloudPlayer_ImportCheckpoint(taskId, &out, phase, message, percent := 0) {
    CloudPlayer_SendImportProgress(message, taskId, phase, percent)
    if CloudPlayer_CheckImportCancelled(taskId, &out)
        return false
    ; Yield once so message queue and cancel events can run.
    Sleep(0)
    if CloudPlayer_CheckImportCancelled(taskId, &out)
        return false
    return true
}

CloudPlayer_AsyncFlowStart(taskId, provider, mountPath, driver, opts := 0) {
    global g_CloudPlayerAsyncFlows
    tid := Trim(String(taskId))
    ctx := Map(
        "taskId", tid,
        "provider", String(provider),
        "mountPath", String(mountPath),
        "driver", String(driver),
        "opts", (opts is Map) ? opts : Map(),
        "deadline", A_TickCount + 90000,
        "startedAt", A_TickCount,
        "phase", "queued",
        "trace", [],
        "cancelled", false
    )
    g_CloudPlayerAsyncFlows[tid] := ctx
    CloudPlayer_AsyncLog("cloudplayer_async_step_enter", "task_id=" . tid . " phase=queued")
    return ctx
}

CloudPlayer_AsyncFlowGet(taskId) {
    global g_CloudPlayerAsyncFlows
    tid := Trim(String(taskId))
    return g_CloudPlayerAsyncFlows.Has(tid) ? g_CloudPlayerAsyncFlows[tid] : 0
}

CloudPlayer_AsyncFlowDrop(taskId) {
    global g_CloudPlayerAsyncFlows
    tid := Trim(String(taskId))
    if (tid != "" && g_CloudPlayerAsyncFlows.Has(tid))
        g_CloudPlayerAsyncFlows.Delete(tid)
}

CloudPlayer_AsyncFlowCancelled(ctx) {
    if !(ctx is Map)
        return true
    tid := ctx.Has("taskId") ? String(ctx["taskId"]) : ""
    if (tid = "")
        return true
    if CloudPlayer_IsTaskCancelled(tid) {
        ctx["cancelled"] := true
        CloudPlayer_AsyncLog("cloudplayer_async_cancelled", "task_id=" . tid . " phase=" . (ctx.Has("phase") ? String(ctx["phase"]) : ""))
        return true
    }
    return false
}

CloudPlayer_AsyncFlowTimedOut(ctx, stepName := "") {
    if !(ctx is Map)
        return true
    if (!ctx.Has("deadline"))
        return false
    if (A_TickCount < Integer(ctx["deadline"]))
        return false
    tid := ctx.Has("taskId") ? String(ctx["taskId"]) : ""
    CloudPlayer_AsyncLog("cloudplayer_async_timeout_step", "task_id=" . tid . " step=" . String(stepName))
    CloudPlayer_AsyncLog("cloudplayer_async_timeout_total", "task_id=" . tid . " phase=" . String(stepName))
    return true
}

CloudPlayer_OnFsListResult(reqId, path, ret) {
    global g_CloudPlayerWv2
    if CloudPlayer_IsStaleReq("fs_list", reqId) {
        try CoreAsyncHttp_Log("cloudplayer_drop_stale_req", "kind=fs_list req_id=" . reqId)
        return
    }
    ok := (ret is Map) && ret.Has("ok") && !!ret["ok"]
    st := (ret is Map && ret.Has("status")) ? Integer(ret["status"]) : 0
    err := (ret is Map && ret.Has("error")) ? String(ret["error"]) : "unknown"
    txt := (ret is Map && ret.Has("text")) ? String(ret["text"]) : ""
    try WebView_QueuePayload(g_CloudPlayerWv2, Map(
        "type", "cloudplayer_fs_list_result",
        "reqId", reqId,
        "requestId", reqId,
        "phase", "done",
        "path", path,
        "ok", ok,
        "status", st,
        "error", err,
        "errorCode", ok ? "" : err,
        "ts", A_Now,
        "text", txt
    ))
}

CloudPlayer_OnFsGetResult(reqId, path, ret) {
    global g_CloudPlayerWv2
    if CloudPlayer_IsStaleReq("fs_get", reqId) {
        try CoreAsyncHttp_Log("cloudplayer_drop_stale_req", "kind=fs_get req_id=" . reqId)
        return
    }
    ok := (ret is Map) && ret.Has("ok") && !!ret["ok"]
    st := (ret is Map && ret.Has("status")) ? Integer(ret["status"]) : 0
    err := (ret is Map && ret.Has("error")) ? String(ret["error"]) : "unknown"
    txt := (ret is Map && ret.Has("text")) ? String(ret["text"]) : ""
    try WebView_QueuePayload(g_CloudPlayerWv2, Map(
        "type", "cloudplayer_fs_get_result",
        "reqId", reqId,
        "requestId", reqId,
        "phase", "done",
        "path", path,
        "ok", ok,
        "status", st,
        "error", err,
        "errorCode", ok ? "" : err,
        "ts", A_Now,
        "text", txt
    ))
}

CloudPlayer_OnApiJsonResult(reqId, ret) {
    global g_CloudPlayerWv2
    if CloudPlayer_IsStaleReq("api_json", reqId) {
        try CoreAsyncHttp_Log("cloudplayer_drop_stale_req", "kind=api_json req_id=" . reqId)
        return
    }
    ok := (ret is Map) && ret.Has("ok") && !!ret["ok"]
    st := (ret is Map && ret.Has("status")) ? Integer(ret["status"]) : 0
    err := (ret is Map && ret.Has("error")) ? String(ret["error"]) : "unknown"
    txt := (ret is Map && ret.Has("text")) ? String(ret["text"]) : ""
    try WebView_QueuePayload(g_CloudPlayerWv2, Map(
        "type", "cloudplayer_api_json_result",
        "reqId", reqId,
        "requestId", reqId,
        "phase", "done",
        "ok", ok,
        "status", st,
        "error", err,
        "errorCode", ok ? "" : err,
        "ts", A_Now,
        "text", txt
    ))
}

CloudPlayer_DeferredAdminToken(reqId) {
    global g_CloudPlayerWv2
    if CloudPlayer_IsStaleReq("admin_token", reqId) {
        try CoreAsyncHttp_Log("cloudplayer_drop_stale_req", "kind=admin_token req_id=" . reqId)
        return
    }
    CloudPlayer_GetOpenListAdminTokenAsync((ret) => CloudPlayer_OnDeferredAdminToken(reqId, ret), 12000, reqId, "cp_admin_token_deferred")
}

CloudPlayer_OnDeferredAdminToken(reqId, ret) {
    global g_CloudPlayerWv2
    if CloudPlayer_IsStaleReq("admin_token", reqId) {
        try CoreAsyncHttp_Log("cloudplayer_drop_stale_req", "kind=admin_token req_id=" . reqId . " phase=done")
        return
    }
    ok := (ret is Map) && ret.Has("ok") && !!ret["ok"]
    tok := (ret is Map && ret.Has("token")) ? String(ret["token"]) : ""
    errMsg := (ret is Map && ret.Has("error")) ? String(ret["error"]) : ""
    try WebView_QueuePayload(g_CloudPlayerWv2, Map(
        "type", "cloudplayer_admin_token",
        "reqId", reqId,
        "requestId", reqId,
        "phase", "done",
        "ok", ok,
        "token", tok,
        "errorCode", ok ? "" : "admin_token_failed",
        "message", ok ? "ok" : (errMsg != "" ? errMsg : "failed"),
        "ts", A_Now
    ))
}

CloudPlayer_DeferredArchiveList(reqId, path, token) {
    global g_CloudPlayerWv2
    if CloudPlayer_IsStaleReq("archive_list", reqId) {
        try CoreAsyncHttp_Log("cloudplayer_drop_stale_req", "kind=archive_list req_id=" . reqId)
        return
    }
    if CloudPlayer_UseAsyncDownloadPipeline() {
        CloudPlayer_GetArchiveEntriesAsync(path, token, reqId, (out) => CloudPlayer_OnDeferredArchiveListAsyncDone(reqId, out))
        return
    }
    out := CloudPlayer_GetArchiveEntries(path, token, reqId)
    if CloudPlayer_IsStaleReq("archive_list", reqId) {
        try CoreAsyncHttp_Log("cloudplayer_drop_stale_req", "kind=archive_list req_id=" . reqId . " phase=done")
        return
    }
    try WebView_QueuePayload(g_CloudPlayerWv2, Map(
        "type", "cloudplayer_archive_list_result",
        "reqId", reqId,
        "requestId", reqId,
        "phase", "done",
        "ok", out["ok"],
        "message", out["message"],
        "errorCode", out["ok"] ? "" : "archive_list_failed",
        "ts", A_Now,
        "entries", out["entries"]
    ))
}

CloudPlayer_OnDeferredArchiveListAsyncDone(reqId, out) {
    global g_CloudPlayerWv2
    if CloudPlayer_IsStaleReq("archive_list", reqId) {
        try CoreAsyncHttp_Log("cloudplayer_drop_stale_req", "kind=archive_list req_id=" . reqId . " phase=done")
        return
    }
    try WebView_QueuePayload(g_CloudPlayerWv2, Map(
        "type", "cloudplayer_archive_list_result",
        "reqId", reqId,
        "requestId", reqId,
        "phase", "done",
        "ok", out["ok"],
        "message", out["message"],
        "errorCode", out["ok"] ? "" : "archive_list_failed",
        "ts", A_Now,
        "entries", out["entries"]
    ))
}

CloudPlayer_DownloadOpenListExe() {
    destDir := A_ScriptDir "\tools\openlist"
    destExe := destDir "\openlist.exe"
    tmpExe := destDir "\openlist.download.tmp.exe"
    if !DirExist(destDir) {
        try DirCreate(destDir)
        catch {
            try TrayTip("CloudPlayer", "无法创建目录: " . destDir, "Icon! 2")
            return false
        }
    }

    urls := CloudPlayer_GetOpenListDownloadUrls()
    for _, url in urls {
        try FileDelete(tmpExe)
        ok := false
        try {
            CloudPlayer_DownloadBinary(url, tmpExe)
            sz := 0
            try sz := FileGetSize(tmpExe)
            if (sz >= 5 * 1024 * 1024) {
                FileMove(tmpExe, destExe, 1)
                ok := FileExist(destExe) ? true : false
            }
        } catch {
            ok := false
        }
        if ok {
            try TrayTip("CloudPlayer", "OpenList 已自动下载完成", "Iconi")
            return true
        }
    }

    try FileDelete(tmpExe)
    try TrayTip("CloudPlayer", "OpenList 自动下载失败，请检查网络后重试。", "Icon! 2")
    return false
}

CloudPlayer_GetOpenListDownloadUrls() {
    repo := "OpenListTeam/OpenList/releases/latest/download/"
    fileNames := [
        "openlist-windows-amd64-lite.exe",
        "openlist-windows-amd64.exe",
        "alist-windows-amd64.exe"
    ]
    prefixes := [
        "https://github.com/",
        "https://gh-proxy.com/github.com/",
        "https://ghfast.top/github.com/",
        "https://ghproxy.net/github.com/"
    ]
    out := []
    for _, pre in prefixes {
        for _, fn in fileNames
            out.Push(pre . repo . fn)
    }
    return out
}

CloudPlayer_GetWorkDir(exePath) {
    p := StrReplace(String(exePath), "/", "\")
    pos := InStr(p, "\", , -1)
    if (pos <= 0)
        return A_ScriptDir
    return SubStr(p, 1, pos - 1)
}

CloudPlayer_IsOpenListRunning() {
    global g_CloudPlayerBackendHealth, g_CloudPlayerLastHealthTick, g_CloudPlayerHealthTtlMs
    ttl := Integer(g_CloudPlayerHealthTtlMs)
    if ((A_TickCount - Integer(g_CloudPlayerLastHealthTick)) <= ttl)
        return !!g_CloudPlayerBackendHealth
    CloudPlayer_ProbeOpenListAsync()
    if (CloudPlayer_IsLocalApiBase(g_CloudPlayerApiBase) && (ProcessExist("openlist.exe") || ProcessExist("alist.exe")))
        return true
    return !!g_CloudPlayerBackendHealth
}

CloudPlayer_ProbeOpenListAsync(cb := 0) {
    global g_CloudPlayerApiBase, g_CloudPlayerBackendHealth, g_CloudPlayerLastHealthTick, g_CloudPlayerHealthProbeInflight
    if g_CloudPlayerHealthProbeInflight
        return 0
    g_CloudPlayerHealthProbeInflight := true
    apiBase := Trim(String(g_CloudPlayerApiBase))
    if (apiBase = "")
        apiBase := "http://127.0.0.1:5244"
    url := RTrim(apiBase, "/") . "/"
    return HttpGetAsync(url, (ret) => CloudPlayer_OnProbeDone(ret, cb), Map("timeoutMs", 1500, "receiveTimeoutMs", 1500, "tag", "cloudplayer_probe"))
}

CloudPlayer_OnProbeDone(ret, cb := 0) {
    global g_CloudPlayerBackendHealth, g_CloudPlayerLastHealthTick, g_CloudPlayerHealthProbeInflight
    g_CloudPlayerHealthProbeInflight := false
    ok := false
    if (ret is Map) {
        st := Integer(ret["status"])
        ok := (st >= 200 && st < 600)
    }
    g_CloudPlayerBackendHealth := ok
    g_CloudPlayerLastHealthTick := A_TickCount
    if IsObject(cb)
        try cb.Call(ok, ret)
}

CloudPlayer_IsLocalApiBase(apiBase) {
    s := StrLower(Trim(String(apiBase)))
    return InStr(s, "127.0.0.1") || InStr(s, "localhost") || InStr(s, "[::1]")
}

CloudPlayer_GetOpenListAdminUrl() {
    global g_CloudPlayerApiBase
    base := Trim(String(g_CloudPlayerApiBase))
    if (base = "")
        base := "http://127.0.0.1:5244"
    base := RTrim(base, "/")
    return base . "/@manage"
}

CloudPlayer_SendImportProgress(message, taskId := "", phase := "running", percent := 0) {
    global g_CloudPlayerWv2, g_CloudPlayerImportTask
    msg := Trim(String(message))
    if (msg = "")
        return false
    tid := Trim(String(taskId))
    if (tid = "" && g_CloudPlayerImportTask is Map && g_CloudPlayerImportTask.Has("taskId"))
        tid := String(g_CloudPlayerImportTask["taskId"])
    if (tid != "" && g_CloudPlayerImportTask is Map && g_CloudPlayerImportTask.Has("taskId")
        && String(g_CloudPlayerImportTask["taskId"]) != tid) {
        try CoreAsyncHttp_Log("cloudplayer_drop_stale_req", "kind=import_progress task_id=" . tid . " current=" . String(g_CloudPlayerImportTask["taskId"]))
        return false
    }
    if (tid != "" && CloudPlayer_IsTaskCancelled(tid))
        return false
    try WebView_QueuePayload(g_CloudPlayerWv2, Map(
        "type", "cloudplayer_import_progress",
        "taskId", tid,
        "reqId", tid,
        "requestId", tid,
        "phase", String(phase),
        "percent", Integer(percent),
        "message", msg,
        "ts", A_Now
    ))
    try WebView_QueuePayload(g_CloudPlayerWv2, Map(
        "type", "cloudplayer_import_task_state",
        "ok", true,
        "taskId", tid,
        "reqId", tid,
        "requestId", tid,
        "phase", String(phase),
        "message", msg,
        "ts", A_Now
    ))
    return true
}

CloudPlayer_ImportAliyunStorage(refreshToken, mountPath := "/aliyun", opts := 0, taskId := "") {
    global g_CloudPlayerApiBase
    out := Map("ok", false, "message", "", "mountPath", "", "driver", "AliyundriveOpen", "authToken", "")
    rt := CloudPlayer_NormalizeProviderToken(refreshToken)
    mp := Trim(String(mountPath))
    if (mp = "")
        mp := "/aliyun"
    if (SubStr(mp, 1, 1) != "/")
        mp := "/" . mp
    out["mountPath"] := mp

    if (rt = "") {
        out["message"] := "refresh token is empty"
        return out
    }
    if !CloudPlayer_ImportCheckpoint(taskId, &out, "checking_openlist", "Checking OpenList status...", 5)
        return out
    if !CloudPlayer_EnsureOpenListRunning() {
        out["message"] := "OpenList is not running"
        return out
    }

    if !CloudPlayer_ImportCheckpoint(taskId, &out, "getting_token", "Getting OpenList admin token...", 12)
        return out
    adminTokenErr := ""
    adminToken := CloudPlayer_GetOpenListAdminToken(&adminTokenErr, 12000)
    if (adminToken = "") {
        out["message"] := (adminTokenErr != "") ? adminTokenErr : "failed to get OpenList admin token"
        return out
    }
    out["authToken"] := adminToken

    if !CloudPlayer_ImportCheckpoint(taskId, &out, "listing_storage", "Listing existing storages...", 20)
        return out
    headers := Map("Authorization", adminToken, "Content-Type", "application/json")
    listRet := CloudPlayer_HttpJsonAwait("GET", g_CloudPlayerApiBase . "/api/admin/storage/list", headers)
    if CloudPlayer_CheckImportCancelled(taskId, &out)
        return out
    if !listRet["ok"] {
        out["message"] := "failed to list storages: " . listRet["error"]
        return out
    }

    targetId := 0
    targetDriver := "AliyundriveOpen"
    if (listRet["json"] is Map && listRet["json"].Has("data")) {
        dataObj := listRet["json"]["data"]
        if (dataObj is Map && dataObj.Has("content") && dataObj["content"] is Array) {
            for _, row in dataObj["content"] {
                try rowPath := String(row.Has("mount_path") ? row["mount_path"] : "")
                catch {
                    rowPath := ""
                }
                if (rowPath = mp) {
                    try targetId := Integer(row.Has("id") ? row["id"] : 0)
                    catch {
                        targetId := 0
                    }
                    try targetDriver := String(row.Has("driver") ? row["driver"] : "AliyundriveOpen")
                    catch {
                        targetDriver := "AliyundriveOpen"
                    }
                    break
                }
            }
        }
    }

    if (targetDriver != "Aliyundrive" && targetDriver != "AliyundriveOpen")
        targetDriver := "AliyundriveOpen"

    rootFolderId := "root"
    driveType := "default"
    useOnlineApi := true
    alipanType := "default"
    apiUrlAddress := "https://api.oplist.org/alicloud/renewapi"
    clientId := ""
    clientSecret := ""

    if (opts is Map) {
        try {
            if (opts.Has("rootFolderId") && Trim(String(opts["rootFolderId"])) != "")
                rootFolderId := Trim(String(opts["rootFolderId"]))
            if (opts.Has("driveType") && Trim(String(opts["driveType"])) != "")
                driveType := Trim(String(opts["driveType"]))
            if (opts.Has("alipanType") && Trim(String(opts["alipanType"])) != "")
                alipanType := Trim(String(opts["alipanType"]))
            if (opts.Has("apiUrlAddress") && Trim(String(opts["apiUrlAddress"])) != "")
                apiUrlAddress := Trim(String(opts["apiUrlAddress"]))
            if (opts.Has("clientId"))
                clientId := Trim(String(opts["clientId"]))
            if (opts.Has("clientSecret"))
                clientSecret := Trim(String(opts["clientSecret"]))
            if (opts.Has("useOnlineApi"))
                useOnlineApi := CloudPlayer_ToBool(opts["useOnlineApi"], true)
        } catch {
        }
    }

    additionObj := (targetDriver = "AliyundriveOpen")
        ? Map(
            "drive_type", driveType,
            "root_folder_id", rootFolderId,
            "refresh_token", rt,
            "order_by", "",
            "order_direction", "",
            "use_online_api", useOnlineApi,
            "alipan_type", alipanType,
            "api_url_address", apiUrlAddress,
            "client_id", clientId,
            "client_secret", clientSecret,
            "remove_way", "",
            "rapid_upload", false,
            "internal_upload", false,
            "livp_download_format", "jpeg"
        )
        : Map(
            "root_folder_id", rootFolderId,
            "refresh_token", rt,
            "order_by", "",
            "order_direction", "",
            "rapid_upload", false,
            "internal_upload", false
        )
    additionJson := Jxon_Dump(additionObj)
    additionJson := CloudPlayer_JsonForceBoolLiterals(additionJson, ["use_online_api", "rapid_upload", "internal_upload"])

    bodyObj := Map(
        "mount_path", mp,
        "order", 0,
        "remark", "",
        "cache_expiration", 30,
        "web_proxy", true,
        "webdav_policy", "302_redirect",
        "down_proxy_url", "",
        "extract_folder", "",
        "enable_sign", false,
        "driver", targetDriver,
        "order_by", "",
        "order_direction", "",
        "status", "work",
        "addition", additionJson
    )
    if (targetId > 0)
        bodyObj["id"] := targetId

    saveUrl := g_CloudPlayerApiBase . ((targetId > 0) ? "/api/admin/storage/update" : "/api/admin/storage/create")
    if !CloudPlayer_ImportCheckpoint(taskId, &out, "saving_storage", (targetId > 0)
        ? "Updating Aliyun storage config..."
        : "Creating Aliyun storage config...", 45)
        return out
    bodyJson := Jxon_Dump(bodyObj)
    bodyJson := CloudPlayer_JsonForceBoolLiterals(bodyJson, ["web_proxy", "enable_sign"])
    saveRet := CloudPlayer_HttpJsonAwait("POST", saveUrl, headers, bodyJson)
    if CloudPlayer_CheckImportCancelled(taskId, &out)
        return out
    if !saveRet["ok"] {
        out["message"] := "save storage failed: " . saveRet["error"]
        return out
    }

    respMsg := ""
    try respMsg := String(saveRet["json"].Has("message") ? saveRet["json"]["message"] : "")
    catch {
        respMsg := ""
    }
    if !CloudPlayer_ImportCheckpoint(taskId, &out, "verifying_storage", "Verifying storage status...", 72)
        return out
    statusRet := CloudPlayer_HttpJsonAwait("GET", g_CloudPlayerApiBase . "/api/admin/storage/list", headers)
    if CloudPlayer_CheckImportCancelled(taskId, &out)
        return out
    statusHint := ""
    foundAfterSave := false
    if (statusRet["ok"] && statusRet["json"] is Map && statusRet["json"].Has("data")) {
        d2 := statusRet["json"]["data"]
        if (d2 is Map && d2.Has("content") && d2["content"] is Array) {
            for _, row2 in d2["content"] {
                try p2 := String(row2.Has("mount_path") ? row2["mount_path"] : "")
                catch {
                    p2 := ""
                }
                if (p2 = mp) {
                    foundAfterSave := true
                    try s2 := String(row2.Has("status") ? row2["status"] : "")
                    catch {
                        s2 := ""
                    }
                    if (s2 != "" && s2 != "work")
                        statusHint := s2
                    break
                }
            }
        }
    }

    if !foundAfterSave {
        out["message"] := "save returned success but mount path not found after refresh: " . mp
        return out
    }

    ; Verify mount readability. If user selected resource drive and it's empty,
    ; automatically fallback to default drive for AliyundriveOpen.
    verify := CloudPlayer_VerifyMountList(mp, headers)
    if !verify["ok"] {
        out["message"] := "mount check failed: " . verify["message"]
        return out
    }
    if (targetDriver = "AliyundriveOpen" && driveType = "resource" && verify["count"] = 0) {
        if !CloudPlayer_ImportCheckpoint(taskId, &out, "fallback_retry", "Resource drive is empty, retrying with drive_type=default...", 82)
            return out
        additionObj["drive_type"] := "default"
        additionJson2 := Jxon_Dump(additionObj)
        additionJson2 := CloudPlayer_JsonForceBoolLiterals(additionJson2, ["use_online_api", "rapid_upload", "internal_upload"])
        bodyObj["addition"] := additionJson2
        saveRet2 := CloudPlayer_HttpJsonAwait("POST", g_CloudPlayerApiBase . "/api/admin/storage/update", headers, CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(bodyObj), ["web_proxy", "enable_sign"]))
        if CloudPlayer_CheckImportCancelled(taskId, &out)
            return out
        if saveRet2["ok"] {
            driveType := "default"
            verify2 := CloudPlayer_VerifyMountList(mp, headers)
            if !verify2["ok"] {
                out["message"] := "fallback mount check failed: " . verify2["message"]
                return out
            }
            verify := verify2
        }
    }

    out["ok"] := true
    out["driver"] := targetDriver
    out["message"] := (statusHint != "")
        ? "saved, but init status: " . statusHint
        : ((respMsg != "") ? respMsg : "import success")
    if (verify["count"] = 0)
        out["message"] := out["message"] . " (mount is reachable but empty)"
    CloudPlayer_SendImportProgress("Import completed.", taskId, "done", 100)
    return out
}

CloudPlayer_ImportStorageGeneric(provider, token, mountPath := "/", driver := "AliyundriveOpen", opts := 0, taskId := "") {
    global g_CloudPlayerApiBase
    providerKey := StrLower(Trim(String(provider)))
    drvInput := Trim(String(driver))
    if (drvInput = "" || drvInput = "Unknown")
        drvInput := CloudPlayer_DefaultDriverByProvider(providerKey)
    if (drvInput = "AliyundriveOpen" || drvInput = "Aliyundrive")
        return CloudPlayer_ImportAliyunStorage(token, mountPath, opts, taskId)

    out := Map("ok", false, "message", "", "mountPath", "", "driver", drvInput, "authToken", "")
    tk := CloudPlayer_NormalizeProviderToken(token)
    mp := Trim(String(mountPath))
    if (mp = "")
        mp := "/"
    if (SubStr(mp, 1, 1) != "/")
        mp := "/" . mp
    out["mountPath"] := mp

    if (tk = "") {
        out["message"] := "token is empty"
        return out
    }
    if !CloudPlayer_ImportCheckpoint(taskId, &out, "checking_openlist", "Checking OpenList status...", 5)
        return out
    if !CloudPlayer_EnsureOpenListRunning() {
        out["message"] := "OpenList is not running"
        return out
    }
    if !CloudPlayer_ImportCheckpoint(taskId, &out, "getting_token", "Getting OpenList admin token...", 12)
        return out
    adminTokenErr := ""
    adminToken := CloudPlayer_GetOpenListAdminToken(&adminTokenErr, 12000)
    if (adminToken = "") {
        out["message"] := (adminTokenErr != "") ? adminTokenErr : "failed to get OpenList admin token"
        return out
    }
    out["authToken"] := adminToken
    headers := Map("Authorization", adminToken, "Content-Type", "application/json")

    if !CloudPlayer_ImportCheckpoint(taskId, &out, "listing_storage", "Listing existing storages...", 20)
        return out
    listRet := CloudPlayer_HttpJsonAwait("GET", g_CloudPlayerApiBase . "/api/admin/storage/list", headers)
    if CloudPlayer_CheckImportCancelled(taskId, &out)
        return out
    if !listRet["ok"] {
        out["message"] := "failed to list storages: " . listRet["error"]
        return out
    }
    targetId := 0
    existingDriver := ""
    if (listRet["json"] is Map && listRet["json"].Has("data")) {
        dataObj := listRet["json"]["data"]
        if (dataObj is Map && dataObj.Has("content") && dataObj["content"] is Array) {
            for _, row in dataObj["content"] {
                try rowPath := String(row.Has("mount_path") ? row["mount_path"] : "")
                catch {
                    rowPath := ""
                }
                if (rowPath = mp) {
                    try targetId := Integer(row.Has("id") ? row["id"] : 0)
                    catch {
                        targetId := 0
                    }
                    try existingDriver := String(row.Has("driver") ? row["driver"] : "")
                    catch {
                        existingDriver := ""
                    }
                    break
                }
            }
        }
    }

    migratedLegacyDriver := false
    migratedFromDriver := ""
    migratedToDriver := ""
    if (providerKey = "pan123" && targetId > 0) {
        if !CloudPlayer_ImportCheckpoint(taskId, &out, "fallback_retry", "Found existing /pan123 storage, recreating to avoid driver-change conflicts...", 28)
            return out
        delErrPan := ""
        delRetPan := CloudPlayer_DeleteStorageById(targetId, headers, &delErrPan)
        if !delRetPan["ok"] {
            out["message"] := "failed to replace existing 123Pan mount: " . ((delErrPan != "") ? delErrPan : delRetPan["error"])
            return out
        }
        migratedFromDriver := existingDriver
        migratedToDriver := drvInput
        targetId := 0
        existingDriver := ""
        migratedLegacyDriver := true
    }
    if (providerKey = "quark" && targetId > 0 && existingDriver != "" && StrLower(existingDriver) != StrLower(drvInput)) {
        oldDrv := StrLower(existingDriver)
        newDrv := StrLower(drvInput)
        if (CloudPlayer_IsQuarkDriver(oldDrv) && CloudPlayer_IsQuarkDriver(newDrv)) {
            CloudPlayer_SendImportProgress("Detected mismatched Quark driver (" . existingDriver . " -> " . drvInput . "), replacing mount...", taskId, "fallback_retry", 30)
            delErr := ""
            delRet := CloudPlayer_DeleteStorageById(targetId, headers, &delErr)
            if !delRet["ok"] {
                out["message"] := "failed to auto-replace legacy Quark mount: " . ((delErr != "") ? delErr : delRet["error"])
                return out
            }
            migratedFromDriver := existingDriver
            migratedToDriver := drvInput
            targetId := 0
            existingDriver := ""
            migratedLegacyDriver := true
        } else {
            out["message"] := "existing mount path uses driver=" . existingDriver . ", but current import expects " . drvInput . ". Please delete old mount first or use a new mount path."
            return out
        }
    }
    if (providerKey = "pan123" && targetId > 0 && existingDriver != "" && StrLower(existingDriver) != StrLower(drvInput)) {
        oldDrv2 := StrLower(existingDriver)
        newDrv2 := StrLower(drvInput)
        if (CloudPlayer_IsPan123Driver(oldDrv2) && CloudPlayer_IsPan123Driver(newDrv2)) {
            CloudPlayer_SendImportProgress("Detected mismatched 123Pan driver (" . existingDriver . " -> " . drvInput . "), replacing mount...", taskId, "fallback_retry", 30)
            delErr3 := ""
            delRet3 := CloudPlayer_DeleteStorageById(targetId, headers, &delErr3)
            if !delRet3["ok"] {
                out["message"] := "failed to auto-replace legacy 123Pan mount: " . ((delErr3 != "") ? delErr3 : delRet3["error"])
                return out
            }
            migratedFromDriver := existingDriver
            migratedToDriver := drvInput
            targetId := 0
            existingDriver := ""
            migratedLegacyDriver := true
        } else {
            out["message"] := "existing mount path uses driver=" . existingDriver . ", but current import expects " . drvInput . ". Please delete old mount first or use a new mount path."
            return out
        }
    }

    drvCandidates := []
    ; During Quark driver migration, keep target driver fixed.
    if (migratedLegacyDriver) {
        CloudPlayer_ArrayPushUnique(&drvCandidates, drvInput)
    } else {
        ; OpenList does not allow changing driver on an existing storage record.
        ; If mount path already exists, force update with the existing driver only.
        if (targetId > 0 && existingDriver != "") {
            CloudPlayer_ArrayPushUnique(&drvCandidates, existingDriver)
            ; 123Pan driver naming differs by OpenList build. Keep fallbacks when an old
            ; record locks us to an unavailable alias (e.g. Pan123 missing in some builds).
            if (providerKey = "pan123") {
                for _, c in CloudPlayer_GetDriverCandidates(providerKey, drvInput)
                    CloudPlayer_ArrayPushUnique(&drvCandidates, c)
            }
        } else {
            if (existingDriver != "")
                CloudPlayer_ArrayPushUnique(&drvCandidates, existingDriver)
            for _, c in CloudPlayer_GetDriverCandidates(providerKey, drvInput)
                CloudPlayer_ArrayPushUnique(&drvCandidates, c)
            if (drvCandidates.Length = 0)
                CloudPlayer_ArrayPushUnique(&drvCandidates, drvInput)
        }
    }

    saveRet := 0
    chosenDriver := ""
    lastSaveError := ""
    saveUrl := g_CloudPlayerApiBase . ((targetId > 0) ? "/api/admin/storage/update" : "/api/admin/storage/create")
    for _, drv in drvCandidates {
        additionObj := CloudPlayer_BuildGenericAddition(providerKey, tk, opts, drv)
        additionJson := CloudPlayer_JsonForceBoolLiterals(
            Jxon_Dump(additionObj),
            ["use_online_api", "use_dynamic_upload_api", "low_bandwith_upload_mode", "only_list_video_file", "is_sharepoint", "disable_disk_usage", "enable_direct_upload"]
        )
        bodyObj := Map(
            "mount_path", mp,
            "order", 0,
            "remark", "",
            "cache_expiration", 30,
            "web_proxy", true,
            "webdav_policy", "302_redirect",
            "down_proxy_url", "",
            "extract_folder", "",
            "enable_sign", false,
            "driver", drv,
            "order_by", "",
            "order_direction", "",
            "status", "work",
            "addition", additionJson
        )
        if (targetId > 0)
            bodyObj["id"] := targetId

        if !CloudPlayer_ImportCheckpoint(taskId, &out, "saving_storage", (targetId > 0)
            ? "Updating storage config (" . drv . ")..."
            : "Creating storage config (" . drv . ")...", 45)
            return out
        bodyJson := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(bodyObj), ["web_proxy", "enable_sign"])
        saveRet := CloudPlayer_HttpJsonAwait("POST", saveUrl, headers, bodyJson)
        if CloudPlayer_CheckImportCancelled(taskId, &out)
            return out
        if (saveRet["ok"]) {
            chosenDriver := drv
            break
        }
        lowSaveErr := StrLower(String(saveRet["error"]))
        if (providerKey = "pan123"
            && targetId > 0
            && (InStr(lowSaveErr, "no driver named") || InStr(lowSaveErr, "failed get driver new"))) {
            CloudPlayer_SendImportProgress("Detected unavailable stored 123 driver alias, recreating mount...", taskId, "fallback_retry", 56)
            delErr4 := ""
            delRet4 := CloudPlayer_DeleteStorageById(targetId, headers, &delErr4)
            if (delRet4["ok"]) {
                targetId := 0
                saveUrl := g_CloudPlayerApiBase . "/api/admin/storage/create"
                try bodyObj.Delete("id")
                catch {
                }
                bodyJson := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(bodyObj), ["web_proxy", "enable_sign"])
                ; Re-run current candidate as create, then continue to next fallback if still fails.
                saveRet4 := CloudPlayer_HttpJsonAwait("POST", saveUrl, headers, bodyJson)
                if CloudPlayer_CheckImportCancelled(taskId, &out)
                    return out
                if (saveRet4["ok"]) {
                    chosenDriver := drv
                    break
                }
                lowSaveErr := StrLower(String(saveRet4["error"]))
                saveRet := saveRet4
            }
        }
        if (providerKey = "quark"
            && migratedLegacyDriver
            && targetId = 0
            && StrLower(drv) = StrLower(drvInput)
            && InStr(lowSaveErr, "unique constraint failed: x_storages.mount_path")) {
            CloudPlayer_SendImportProgress("Mount path still exists, retrying legacy cleanup...", taskId, "fallback_retry", 56)
            foundId := 0
            foundDriver := ""
            findErr := ""
            if CloudPlayer_FindStorageByMountPath(mp, headers, &foundId, &foundDriver, &findErr) {
                foundDrvLow := StrLower(foundDriver)
                wantDrvLow := StrLower(drvInput)
                if (foundId > 0 && CloudPlayer_IsQuarkDriver(foundDrvLow) && foundDrvLow != wantDrvLow) {
                    delErr2 := ""
                    delRet2 := CloudPlayer_DeleteStorageById(foundId, headers, &delErr2)
                    if (delRet2["ok"]) {
                        saveRet2 := CloudPlayer_HttpJsonAwait("POST", g_CloudPlayerApiBase . "/api/admin/storage/create", headers, bodyJson)
                        if CloudPlayer_CheckImportCancelled(taskId, &out)
                            return out
                        if (saveRet2["ok"]) {
                            chosenDriver := drv
                            break
                        }
                        lastSaveError := "driver=" . drv . ": " . saveRet2["error"]
                        continue
                    }
                } else if (foundId > 0 && foundDrvLow = wantDrvLow) {
                    bodyObj["id"] := foundId
                    bodyJson2 := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(bodyObj), ["web_proxy", "enable_sign"])
                    saveRet3 := CloudPlayer_HttpJsonAwait("POST", g_CloudPlayerApiBase . "/api/admin/storage/update", headers, bodyJson2)
                    if CloudPlayer_CheckImportCancelled(taskId, &out)
                        return out
                    if (saveRet3["ok"]) {
                        chosenDriver := drv
                        break
                    }
                    lastSaveError := "driver=" . drv . ": " . saveRet3["error"]
                    continue
                }
            } else if (findErr != "") {
                lastSaveError := "driver=" . drv . ": " . findErr
                continue
            }
        }
        saveErrText := String(saveRet["error"])
        if (providerKey = "quark" && InStr(StrLower(saveErrText), "require login [guest]")) {
            saveErrText := saveErrText . " (Quark requires valid cookie session; refresh_token-only login may be guest)"
        }
        if (providerKey = "pan123" && InStr(StrLower(saveErrText), "请输入正确的手机号码")) {
            saveErrText := saveErrText . " (current OpenList 123 driver may be phone-login mode; try 123Open with valid client_id/client_secret or use a build that supports refresh_token import)"
        }
        if (providerKey = "pan123" && InStr(StrLower(saveErrText), "no driver named: 123open")) {
            saveErrText := saveErrText . " (current OpenList build does not include 123Open; refresh_token import for 123 is unsupported on this build)"
        }
        if (providerKey = "onedrive" && InStr(StrLower(saveErrText), "unsupported protocol scheme")) {
            saveErrText := saveErrText . " (OneDrive host config missing; try with region=global and redirect_uri=https://api.oplist.org/onedrive/callback)"
        }
        lastSaveError := "driver=" . drv . ": " . saveErrText
    }
    if (chosenDriver = "") {
        out["message"] := "save storage failed: " . (lastSaveError != "" ? lastSaveError : "unknown")
        return out
    }

    if !CloudPlayer_ImportCheckpoint(taskId, &out, "verifying_storage", "Verifying mount...", 78)
        return out
    verify := CloudPlayer_VerifyMountList(mp, headers)
    if !verify["ok"] {
        if (providerKey = "onedrive" && InStr(StrLower(verify["message"]), "segment 'root:'")) {
            CloudPlayer_SendImportProgress("OneDrive root path fallback: retrying with empty root_folder_path...", taskId, "fallback_retry", 86)
            ; Some OpenList builds treat "/" as root: and fail on personal accounts.
            ; Retry once with empty root folder path.
            fixId := targetId
            if (fixId <= 0) {
                findIdTmp := 0
                findDrvTmp := ""
                findErrTmp := ""
                if CloudPlayer_FindStorageByMountPath(mp, headers, &findIdTmp, &findDrvTmp, &findErrTmp)
                    fixId := findIdTmp
            }
            if (fixId <= 0) {
                out["message"] := "mount check failed: " . verify["message"]
                return out
            }
            bodyObj2 := Map(
                "mount_path", mp,
                "order", 0,
                "remark", "",
                "cache_expiration", 30,
                "web_proxy", true,
                "webdav_policy", "302_redirect",
                "down_proxy_url", "",
                "extract_folder", "",
                "enable_sign", false,
                "driver", chosenDriver,
                "order_by", "",
                "order_direction", "",
                "status", "work",
                "id", fixId
            )
            add2 := CloudPlayer_BuildGenericAddition(providerKey, tk, opts, chosenDriver)
            try {
                add2["root_folder_path"] := ""
                add2["RootFolderPath"] := ""
            } catch {
            }
            try add2.Delete("root_folder_id")
            catch {
            }
            addJson2 := CloudPlayer_JsonForceBoolLiterals(
                Jxon_Dump(add2),
                ["use_online_api", "use_dynamic_upload_api", "low_bandwith_upload_mode", "only_list_video_file", "is_sharepoint", "disable_disk_usage", "enable_direct_upload"]
            )
            bodyObj2["addition"] := addJson2
            bodyJsonFallback := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(bodyObj2), ["web_proxy", "enable_sign"])
            saveRetFallback := CloudPlayer_HttpJsonAwait("POST", g_CloudPlayerApiBase . "/api/admin/storage/update", headers, bodyJsonFallback)
            if CloudPlayer_CheckImportCancelled(taskId, &out)
                return out
            if saveRetFallback["ok"] {
                verify2 := CloudPlayer_VerifyMountList(mp, headers)
                if (verify2["ok"]) {
                    out["ok"] := true
                    out["message"] := "import success (onedrive root path fallback applied)"
                    out["driver"] := chosenDriver
                    if (verify2["count"] = 0)
                        out["message"] := out["message"] . " (mount is reachable but empty)"
                    CloudPlayer_SendImportProgress("Import completed with root path fallback.", taskId, "done", 100)
                    return out
                }
            }
        }
        out["message"] := "mount check failed: " . verify["message"]
        return out
    }
    out["ok"] := true
    out["message"] := "import success"
    if (migratedLegacyDriver) {
        migrateName := (providerKey = "quark") ? "Quark" : ((providerKey = "pan123") ? "123Pan" : "legacy")
        out["message"] := out["message"] . " (" . migrateName . " mount auto-migrated: " . migratedFromDriver . " -> " . migratedToDriver . ")"
    }
    out["driver"] := chosenDriver
    if (verify["count"] = 0)
        out["message"] := out["message"] . " (mount is reachable but empty)"
    CloudPlayer_SendImportProgress("Import completed.", taskId, "done", 100)
    return out
}

CloudPlayer_ArrayPushUnique(&arr, val) {
    v := Trim(String(val))
    if (v = "")
        return
    for _, x in arr {
        if (StrLower(String(x)) = StrLower(v))
            return
    }
    arr.Push(v)
}

CloudPlayer_IsQuarkDriver(driverName) {
    d := StrLower(Trim(String(driverName)))
    return (d = "quark" || d = "quarkopen")
}

CloudPlayer_IsPan123Driver(driverName) {
    d := StrLower(Trim(String(driverName)))
    return (d = "pan123" || d = "123pan" || d = "123open")
}

CloudPlayer_DeleteStorageById(storageId, headers := 0, &lastErr := "") {
    global g_CloudPlayerApiBase
    ret := Map("ok", false, "error", "invalid storage id")
    sid := 0
    try sid := Integer(storageId)
    catch {
        sid := 0
    }
    if (sid <= 0) {
        lastErr := "invalid storage id"
        return ret
    }

    urlBase := g_CloudPlayerApiBase . "/api/admin/storage/delete"
    sidStr := String(sid)
    attempts := [
        Map("method", "POST", "url", urlBase . "?id=" . sidStr, "body", ""),
        Map("method", "DELETE", "url", urlBase . "?id=" . sidStr, "body", ""),
        Map("method", "POST", "url", urlBase, "body", Jxon_Dump(Map("id", sid))),
        Map("method", "POST", "url", urlBase, "body", Jxon_Dump(Map("id", sidStr))),
        Map("method", "POST", "url", urlBase, "body", Jxon_Dump(Map("ids", [sid]))),
        Map("method", "POST", "url", urlBase, "body", Jxon_Dump(Map("ids", [sidStr])))
    ]

    for _, req in attempts {
        one := CloudPlayer_HttpJsonAwait(req["method"], req["url"], headers, req["body"])
        if (one["ok"]) {
            lastErr := ""
            return one
        }
        try lastErr := String(one["error"])
        catch {
            lastErr := ""
        }
    }

    if (lastErr = "")
        lastErr := "delete request failed"
    ret["error"] := lastErr
    return ret
}

CloudPlayer_DeleteStorageByIdAsync(storageId, headers := 0, callback := 0, reqId := "") {
    global g_CloudPlayerApiBase
    cb := IsObject(callback) ? callback : 0
    sid := 0
    try sid := Integer(storageId)
    catch {
        sid := 0
    }
    if (sid <= 0) {
        cb ? cb.Call(Map("ok", false, "error", "invalid storage id")) : 0
        return
    }
    urlBase := g_CloudPlayerApiBase . "/api/admin/storage/delete"
    sidStr := String(sid)
    attempts := [
        Map("method", "POST", "url", urlBase . "?id=" . sidStr, "body", ""),
        Map("method", "DELETE", "url", urlBase . "?id=" . sidStr, "body", ""),
        Map("method", "POST", "url", urlBase, "body", Jxon_Dump(Map("id", sid))),
        Map("method", "POST", "url", urlBase, "body", Jxon_Dump(Map("id", sidStr))),
        Map("method", "POST", "url", urlBase, "body", Jxon_Dump(Map("ids", [sid]))),
        Map("method", "POST", "url", urlBase, "body", Jxon_Dump(Map("ids", [sidStr])))
    ]
    state := Map("idx", 1, "attempts", attempts, "lastErr", "")
    doReq := 0
    doReq := (*) => (
        state["idx"] > state["attempts"].Length
            ? (cb ? cb.Call(Map("ok", false, "error", state["lastErr"] != "" ? state["lastErr"] : "delete request failed")) : 0)
            : CloudPlayer_DeleteStorageByIdAsync_DoOne(state, headers, cb, reqId, doReq)
    )
    SetTimer(doReq, -1)
}

CloudPlayer_DeleteStorageByIdAsync_DoOne(state, headers, cb, reqId, doReq) {
    req := state["attempts"][state["idx"]]
    CloudPlayer_HttpJsonAsyncReq(req["method"], req["url"], headers, req["body"], (one) => (
        one["ok"]
            ? (cb ? cb.Call(one) : 0)
            : (state["lastErr"] := String(one["error"]), state["idx"] := state["idx"] + 1, SetTimer(doReq, -1))
    ), reqId, "cp_delete_storage")
}

CloudPlayer_FindStorageByMountPath(mountPath, headers := 0, &rowId := 0, &rowDriver := "", &err := "") {
    global g_CloudPlayerApiBase
    rowId := 0
    rowDriver := ""
    err := ""
    mp := Trim(String(mountPath))
    listRet := CloudPlayer_HttpJsonAwait("GET", g_CloudPlayerApiBase . "/api/admin/storage/list", headers)
    if !listRet["ok"] {
        err := listRet["error"]
        return false
    }
    if (listRet["json"] is Map && listRet["json"].Has("data")) {
        dataObj := listRet["json"]["data"]
        if (dataObj is Map && dataObj.Has("content") && dataObj["content"] is Array) {
            for _, row in dataObj["content"] {
                try rowPath := String(row.Has("mount_path") ? row["mount_path"] : "")
                catch {
                    rowPath := ""
                }
                if (rowPath = mp) {
                    try rowId := Integer(row.Has("id") ? row["id"] : 0)
                    catch {
                        rowId := 0
                    }
                    try rowDriver := String(row.Has("driver") ? row["driver"] : "")
                    catch {
                        rowDriver := ""
                    }
                    break
                }
            }
        }
    }
    return true
}

CloudPlayer_FindStorageByMountPathAsync(mountPath, headers := 0, callback := 0, reqId := "") {
    global g_CloudPlayerApiBase
    cb := IsObject(callback) ? callback : 0
    mp := Trim(String(mountPath))
    CloudPlayer_HttpJsonAsyncReq("GET", g_CloudPlayerApiBase . "/api/admin/storage/list", headers, "", (listRet) => (
        cb ? cb.Call(CloudPlayer_ParseFindStorageByMountPathRet(mp, listRet)) : 0
    ), reqId, "cp_find_storage")
}

CloudPlayer_ParseFindStorageByMountPathRet(mp, listRet) {
    out := Map("ok", false, "rowId", 0, "rowDriver", "", "error", "")
    if !listRet["ok"] {
        out["error"] := listRet["error"]
        return out
    }
    out["ok"] := true
    if (listRet["json"] is Map && listRet["json"].Has("data")) {
        dataObj := listRet["json"]["data"]
        if (dataObj is Map && dataObj.Has("content") && dataObj["content"] is Array) {
            for _, row in dataObj["content"] {
                try rowPath := String(row.Has("mount_path") ? row["mount_path"] : "")
                catch {
                    rowPath := ""
                }
                if (rowPath = mp) {
                    try out["rowId"] := Integer(row.Has("id") ? row["id"] : 0)
                    catch {
                        out["rowId"] := 0
                    }
                    try out["rowDriver"] := String(row.Has("driver") ? row["driver"] : "")
                    catch {
                        out["rowDriver"] := ""
                    }
                    break
                }
            }
        }
    }
    return out
}

CloudPlayer_DefaultDriverByProvider(providerKey) {
    p := StrLower(Trim(String(providerKey)))
    if (p = "baidu")
        return "BaiduNetdisk"
    if (p = "quark")
        return "Quark"
    if (p = "pan115")
        return "Pan115"
    if (p = "pan123")
        return "123Open"
    if (p = "onedrive")
        return "Onedrive"
    if (p = "dropbox")
        return "Dropbox"
    if (p = "yandex")
        return "YandexDisk"
    if (p = "gdrive")
        return "GoogleDrive"
    return "AliyundriveOpen"
}

CloudPlayer_GetDriverCandidates(providerKey, preferred) {
    arr := []
    p := StrLower(Trim(String(providerKey)))
    CloudPlayer_ArrayPushUnique(&arr, preferred)
    if (p = "baidu") {
        CloudPlayer_ArrayPushUnique(&arr, "BaiduNetdisk")
        CloudPlayer_ArrayPushUnique(&arr, "Baidu")
    } else if (p = "quark") {
        pref := StrLower(Trim(String(preferred)))
        if (pref = "quarkopen") {
            CloudPlayer_ArrayPushUnique(&arr, "QuarkOpen")
            CloudPlayer_ArrayPushUnique(&arr, "Quark")
        } else {
            ; Scheme B: keep Quark as primary and avoid unexpected fallback to QuarkOpen.
            CloudPlayer_ArrayPushUnique(&arr, "Quark")
        }
    } else if (p = "pan115") {
        CloudPlayer_ArrayPushUnique(&arr, "Pan115")
        CloudPlayer_ArrayPushUnique(&arr, "115Open")
        CloudPlayer_ArrayPushUnique(&arr, "115 Open")
    } else if (p = "pan123") {
        CloudPlayer_ArrayPushUnique(&arr, "123Open")
    } else if (p = "onedrive") {
        CloudPlayer_ArrayPushUnique(&arr, "Onedrive")
        CloudPlayer_ArrayPushUnique(&arr, "OneDrive")
    } else if (p = "dropbox") {
        CloudPlayer_ArrayPushUnique(&arr, "Dropbox")
    } else if (p = "yandex") {
        CloudPlayer_ArrayPushUnique(&arr, "YandexDisk")
        CloudPlayer_ArrayPushUnique(&arr, "Yandex")
    } else if (p = "gdrive") {
        CloudPlayer_ArrayPushUnique(&arr, "GoogleDrive")
        CloudPlayer_ArrayPushUnique(&arr, "Google Drive")
    }
    return arr
}

CloudPlayer_BuildGenericAddition(providerKey, token, opts := 0, driver := "") {
    p := StrLower(Trim(String(providerKey)))
    drv := StrLower(Trim(String(driver)))
    tk := CloudPlayer_NormalizeProviderToken(token)
    refreshToken := tk
    accessToken := tk
    cookieValue := tk
    rootFolderId := "root"
    clientId := ""
    clientSecret := ""
    apiUrlAddress := ""
    useOnlineApi := true
    region := "global"
    isSharepoint := false
    redirectUri := ""
    siteId := ""
    chunkSize := 5
    customHost := ""
    disableDiskUsage := false
    enableDirectUpload := false
    if (opts is Map) {
        try {
            if (opts.Has("rootFolderId") && Trim(String(opts["rootFolderId"])) != "")
                rootFolderId := Trim(String(opts["rootFolderId"]))
            if (opts.Has("clientId"))
                clientId := Trim(String(opts["clientId"]))
            if (opts.Has("clientSecret"))
                clientSecret := Trim(String(opts["clientSecret"]))
            if (opts.Has("apiUrlAddress"))
                apiUrlAddress := Trim(String(opts["apiUrlAddress"]))
            if (opts.Has("useOnlineApi"))
                useOnlineApi := CloudPlayer_ToBool(opts["useOnlineApi"], true)
            if (opts.Has("region") && Trim(String(opts["region"])) != "")
                region := Trim(String(opts["region"]))
            if (opts.Has("isSharepoint"))
                isSharepoint := CloudPlayer_ToBool(opts["isSharepoint"], false)
            if (opts.Has("redirectUri") && Trim(String(opts["redirectUri"])) != "")
                redirectUri := Trim(String(opts["redirectUri"]))
            if (opts.Has("siteId") && Trim(String(opts["siteId"])) != "")
                siteId := Trim(String(opts["siteId"]))
            if (opts.Has("chunkSize")) {
                try chunkSize := Integer(opts["chunkSize"])
                catch {
                    chunkSize := 5
                }
                if (chunkSize <= 0)
                    chunkSize := 5
            }
            if (opts.Has("customHost"))
                customHost := Trim(String(opts["customHost"]))
            if (opts.Has("disableDiskUsage"))
                disableDiskUsage := CloudPlayer_ToBool(opts["disableDiskUsage"], false)
            if (opts.Has("enableDirectUpload"))
                enableDirectUpload := CloudPlayer_ToBool(opts["enableDirectUpload"], false)
            if (opts.Has("__skipQuarkBootstrap"))
                skipQuarkBootstrap := CloudPlayer_ToBool(opts["__skipQuarkBootstrap"], false)
            else
                skipQuarkBootstrap := false
            if (opts.Has("__quarkBootstrap") && opts["__quarkBootstrap"] is Map)
                quarkBootstrap := opts["__quarkBootstrap"]
            else
                quarkBootstrap := 0
        } catch {
        }
    } else {
        skipQuarkBootstrap := false
        quarkBootstrap := 0
    }

    ; CloudPlayer advanced panel defaults to Aliyun endpoint.
    ; Normalize provider-specific online refresh endpoint for generic providers.
    if (p = "baidu") {
        lowApi := StrLower(apiUrlAddress)
        if (apiUrlAddress = "" || InStr(lowApi, "/alicloud/") || InStr(lowApi, "/baidu/renewapi"))
            apiUrlAddress := "https://api.oplist.org/baiduyun/renewapi"
    } else if (p = "quark") {
        if (rootFolderId = "root")
            rootFolderId := "0"
        ; Scheme B still uses online renew endpoint for better token continuity.
        useOnlineApi := true
        lowApi := StrLower(apiUrlAddress)
        if (apiUrlAddress = "" || InStr(lowApi, "/alicloud/") || InStr(lowApi, "/quark/renewapi"))
            apiUrlAddress := "https://api.oplist.org/quarkyun/renewapi"
        if (skipQuarkBootstrap && quarkBootstrap is Map) {
            try {
                qbRt := Trim(String(quarkBootstrap.Has("refresh") ? quarkBootstrap["refresh"] : ""))
                qbAt := Trim(String(quarkBootstrap.Has("access") ? quarkBootstrap["access"] : ""))
                qbApp := Trim(String(quarkBootstrap.Has("appId") ? quarkBootstrap["appId"] : ""))
                qbSign := Trim(String(quarkBootstrap.Has("signKey") ? quarkBootstrap["signKey"] : ""))
                qbCookie := Trim(String(quarkBootstrap.Has("cookie") ? quarkBootstrap["cookie"] : ""))
                if (qbRt != "")
                    refreshToken := qbRt
                if (qbAt != "")
                    accessToken := qbAt
                if (qbApp != "")
                    clientId := qbApp
                if (qbSign != "")
                    clientSecret := qbSign
                if (qbCookie != "")
                    cookieValue := qbCookie
            } catch {
            }
        } else if (drv = "quarkopen" && (clientId = "" || clientSecret = "")) {
            ; Only QuarkOpen needs app_id/sign_key bootstrap and x-pan headers.
            rt2 := ""
            at2 := ""
            app2 := ""
            sign2 := ""
            bootErr := ""
            if CloudPlayer_TryBootstrapQuarkOpen(refreshToken, apiUrlAddress, &rt2, &at2, &app2, &sign2, &bootErr) {
                if (rt2 != "")
                    refreshToken := rt2
                if (at2 != "")
                    accessToken := at2
                if (clientId = "" && app2 != "")
                    clientId := app2
                if (clientSecret = "" && sign2 != "")
                    clientSecret := sign2
            }
        } else if (drv = "quark") {
            ; Quark(UC) requires cookie, not raw refresh token.
            parsedCookie := CloudPlayer_ExtractCookieLikeString(tk)
            if (parsedCookie != "") {
                cookieValue := parsedCookie
            } else {
                rt3 := ""
                at3 := ""
                bootErr2 := ""
                if CloudPlayer_TryBootstrapQuarkCookie(refreshToken, apiUrlAddress, &rt3, &at3, &cookieValue, &bootErr2) {
                    if (rt3 != "")
                        refreshToken := rt3
                    if (at3 != "")
                        accessToken := at3
                } else {
                    ; Avoid treating refresh token text as cookie and ending up in guest mode.
                    cookieValue := ""
                }
            }
        }
    } else if (p = "pan115") {
        if (apiUrlAddress = "" || InStr(StrLower(apiUrlAddress), "/alicloud/"))
            apiUrlAddress := "https://api.oplist.org/115/renewapi"
    } else if (p = "pan123") {
        if (apiUrlAddress = "" || InStr(StrLower(apiUrlAddress), "/alicloud/"))
            apiUrlAddress := "https://api.oplist.org/123cloud/renewapi"
    } else if (p = "onedrive") {
        if (apiUrlAddress = "" || InStr(StrLower(apiUrlAddress), "/alicloud/"))
            apiUrlAddress := "https://api.oplist.org/onedrive/renewapi"
        if (region = "")
            region := "global"
        if (redirectUri = "")
            redirectUri := "https://api.oplist.org/onedrive/callback"
        ; OpenList docs use root folder path (default "/") for OneDrive.
        ; Avoid "Resource not found for the segment 'root:'" caused by empty root path.
        if (rootFolderId = "root")
            rootFolderId := ""
    } else if (p = "dropbox") {
        if (apiUrlAddress = "" || InStr(StrLower(apiUrlAddress), "/alicloud/"))
            apiUrlAddress := "https://api.oplist.org/dropbox/renewapi"
    } else if (p = "yandex") {
        if (apiUrlAddress = "" || InStr(StrLower(apiUrlAddress), "/alicloud/"))
            apiUrlAddress := "https://api.oplist.org/yandex/renewapi"
    } else if (p = "gdrive") {
        if (apiUrlAddress = "" || InStr(StrLower(apiUrlAddress), "/alicloud/"))
            apiUrlAddress := "https://api.oplist.org/googledrive/renewapi"
    }

    add := Map(
        "root_folder_id", rootFolderId,
        "order_by", "",
        "order_direction", "",
        "refresh_token", refreshToken,
        "access_token", accessToken,
        "token", tk,
        "cookie", cookieValue,
        "cookies", cookieValue,
        "use_online_api", useOnlineApi,
        "app_id", clientId,
        "sign_key", clientSecret,
        "client_id", clientId,
        "client_secret", clientSecret,
        "api_url_address", apiUrlAddress,
        "region", region,
        "is_sharepoint", isSharepoint,
        "redirect_uri", redirectUri,
        "site_id", siteId,
        "chunk_size", chunkSize,
        "custom_host", customHost,
        "disable_disk_usage", disableDiskUsage,
        "enable_direct_upload", enableDirectUpload
    )
    if (p = "baidu") {
        ; Avoid Baidu API errno:2 on list when root path is empty.
        add["root_folder_path"] := "/"
    } else if (p = "onedrive") {
        ; For OneDrive, prefer root folder path and avoid root_folder_id based "root:" addressing.
        try add.Delete("root_folder_id")
        catch {
        }
        add["root_folder_path"] := "/"
        add["RootFolderPath"] := "/"
        add["tenant"] := "common"
        add["Tenant"] := "common"
    } else if (p = "pan123" && drv = "123open") {
        ; 123Open on different OpenList builds may parse either snake_case or PascalCase keys.
        add["RefreshToken"] := refreshToken
        add["AccessToken"] := accessToken
        add["ClientID"] := clientId
        add["ClientSecret"] := clientSecret
        add["APIAddress"] := apiUrlAddress
        add["ApiAddress"] := apiUrlAddress
        add["apiAddress"] := apiUrlAddress
    } else if (p = "quark" && drv = "quarkopen") {
        ; Compatibility fields for OpenList builds validating x-pan params.
        quarkClientId := (clientId != "") ? clientId : "5325"
        quarkTm := String(DateDiff(A_NowUTC, "19700101000000", "Seconds"))
        add["x_pan_client_id"] := quarkClientId
        add["x_pan_tm"] := quarkTm
        add["x_pan_token"] := tk
        add["x-pan-client-id"] := quarkClientId
        add["x-pan-tm"] := quarkTm
        add["x-pan-token"] := tk
    }
    return add
}

CloudPlayer_BuildGenericAdditionAsync(providerKey, token, opts := 0, driver := "", taskId := "", callback := 0) {
    cb := IsObject(callback) ? callback : 0
    p := StrLower(Trim(String(providerKey)))
    drv := StrLower(Trim(String(driver)))
    if !(opts is Map)
        opts := Map()
    if (p != "quark") {
        cb ? cb.Call(Map("ok", true, "addition", CloudPlayer_BuildGenericAddition(providerKey, token, opts, driver))) : 0
        return
    }
    lowToken := StrLower(Trim(String(token)))
    if (drv = "quark") {
        cookieLike := CloudPlayer_ExtractCookieLikeString(token)
        if (cookieLike != "") {
            cb ? cb.Call(Map("ok", true, "addition", CloudPlayer_BuildGenericAddition(providerKey, token, opts, driver))) : 0
            return
        }
        apiUrl := opts.Has("apiUrlAddress") ? Trim(String(opts["apiUrlAddress"])) : ""
        if (apiUrl = "" || InStr(StrLower(apiUrl), "/alicloud/") || InStr(StrLower(apiUrl), "/quark/renewapi"))
            apiUrl := "https://api.oplist.org/quarkyun/renewapi"
        CloudPlayer_TryBootstrapQuarkCookieAsync(token, apiUrl, (ret) => (
            !ret["ok"]
                ? (cb ? cb.Call(Map("ok", false, "error", ret["error"])) : 0)
                : CloudPlayer_BuildGenericAdditionAsync_WithBootstrap(providerKey, token, opts, driver, ret, cb)
        ), taskId)
        return
    }
    if (drv = "quarkopen") {
        cid := opts.Has("clientId") ? Trim(String(opts["clientId"])) : ""
        csec := opts.Has("clientSecret") ? Trim(String(opts["clientSecret"])) : ""
        if (cid != "" && csec != "") {
            cb ? cb.Call(Map("ok", true, "addition", CloudPlayer_BuildGenericAddition(providerKey, token, opts, driver))) : 0
            return
        }
        apiUrl2 := opts.Has("apiUrlAddress") ? Trim(String(opts["apiUrlAddress"])) : ""
        if (apiUrl2 = "" || InStr(StrLower(apiUrl2), "/alicloud/") || InStr(StrLower(apiUrl2), "/quark/renewapi"))
            apiUrl2 := "https://api.oplist.org/quarkyun/renewapi"
        CloudPlayer_TryBootstrapQuarkOpenAsync(token, apiUrl2, (ret2) => (
            !ret2["ok"]
                ? (cb ? cb.Call(Map("ok", false, "error", ret2["error"])) : 0)
                : CloudPlayer_BuildGenericAdditionAsync_WithBootstrap(providerKey, token, opts, driver, ret2, cb)
        ), taskId)
        return
    }
    cb ? cb.Call(Map("ok", true, "addition", CloudPlayer_BuildGenericAddition(providerKey, token, opts, driver))) : 0
}

CloudPlayer_BuildGenericAdditionAsync_WithBootstrap(providerKey, token, opts, driver, bootRet, cb) {
    opts2 := Map()
    if (opts is Map) {
        for k, v in opts
            opts2[k] := v
    }
    opts2["__skipQuarkBootstrap"] := true
    opts2["__quarkBootstrap"] := bootRet
    add := CloudPlayer_BuildGenericAddition(providerKey, token, opts2, driver)
    cb ? cb.Call(Map("ok", true, "addition", add)) : 0
}

CloudPlayer_ExtractCookieLikeString(raw) {
    s := Trim(String(raw))
    if (s = "")
        return ""
    if (InStr(s, "__puus=") || InStr(s, "__pus=") || (InStr(s, "=") && InStr(s, ";")))
        return s
    if (RegExMatch(s, "i)(?:^|[?&#])cookie=([^&#\s]+)", &m1))
        return CloudPlayer_UrlDecodeToken(m1[1])
    if (RegExMatch(s, "i)(?:^|[?&#])cookies=([^&#\s]+)", &m2))
        return CloudPlayer_UrlDecodeToken(m2[1])
    return ""
}

CloudPlayer_TryBootstrapQuarkCookie(refreshToken, apiUrlAddress, &outRefresh := "", &outAccess := "", &outCookie := "", &err := "") {
    outRefresh := ""
    outAccess := ""
    outCookie := ""
    err := ""
    rt := Trim(String(refreshToken))
    api := Trim(String(apiUrlAddress))
    if (rt = "" || api = "") {
        err := "refresh token or api url is empty"
        return false
    }
    sep := InStr(api, "?") ? "&" : "?"
    ; quarkyun_fn is fnOS OAuth flow; quarkyun is kept for compatibility.
    urls := [
        api . sep . "refresh_ui=" . rt . "&server_use=true&driver_txt=quarkyun_fn",
        api . sep . "refresh_ui=" . rt . "&server_use=true&driver_txt=quarkyun"
    ]
    lastErr := ""
    for _, u in urls {
        ret := CloudPlayer_HttpJsonAwait("GET", u)
        if !ret["ok"] {
            lastErr := ret["error"]
            continue
        }
        if !(ret["json"] is Map) {
            lastErr := "renew api returned non-json response"
            continue
        }
        j := ret["json"]
        payload := j
        try {
            if (j.Has("data") && j["data"] is Map)
                payload := j["data"]
        } catch {
            payload := j
        }
        try outRefresh := Trim(String(payload.Has("refresh_token") ? payload["refresh_token"] : ""))
        catch {
            outRefresh := ""
        }
        try outAccess := Trim(String(payload.Has("access_token") ? payload["access_token"] : ""))
        catch {
            outAccess := ""
        }
        if (outAccess != "") {
            outCookie := "x_pan_client_id=5325; x_pan_access_token=" . outAccess
            err := ""
            return true
        }
        try lastErr := Trim(String(j.Has("text") ? j["text"] : ""))
        catch {
            lastErr := ""
        }
    }
    if (lastErr = "")
        lastErr := "failed to exchange refresh token to access token"
    err := lastErr
    return false
}

CloudPlayer_TryBootstrapQuarkCookieAsync(refreshToken, apiUrlAddress, callback := 0, reqId := "") {
    cb := IsObject(callback) ? callback : 0
    rt := Trim(String(refreshToken))
    api := Trim(String(apiUrlAddress))
    if (rt = "" || api = "") {
        cb ? cb.Call(Map("ok", false, "error", "refresh token or api url is empty")) : 0
        return
    }
    sep := InStr(api, "?") ? "&" : "?"
    urls := [
        api . sep . "refresh_ui=" . rt . "&server_use=true&driver_txt=quarkyun_fn",
        api . sep . "refresh_ui=" . rt . "&server_use=true&driver_txt=quarkyun"
    ]
    state := Map("idx", 1, "lastErr", "", "urls", urls)
    doReq := 0
    doReq := (*) => (
        state["idx"] > state["urls"].Length
            ? (cb ? cb.Call(Map("ok", false, "error", state["lastErr"] != "" ? state["lastErr"] : "failed to exchange refresh token to access token")) : 0)
            : CloudPlayer_HttpJsonAsyncReq("GET", state["urls"][state["idx"]], 0, "", (ret) => (
                !ret["ok"]
                    ? (state["lastErr"] := ret["error"], state["idx"] := state["idx"] + 1, SetTimer(doReq, -1))
                    : (!(ret["json"] is Map)
                        ? (state["lastErr"] := "renew api returned non-json response", state["idx"] := state["idx"] + 1, SetTimer(doReq, -1))
                        : CloudPlayer_OnQuarkCookieBootstrapResp(state, ret["json"], cb, doReq))
            ), reqId, "cp_quark_cookie_bootstrap")
    )
    SetTimer(doReq, -1)
}

CloudPlayer_OnQuarkCookieBootstrapResp(state, j, cb, doReq) {
    payload := j
    try {
        if (j.Has("data") && j["data"] is Map)
            payload := j["data"]
    } catch {
        payload := j
    }
    outRefresh := ""
    outAccess := ""
    try outRefresh := Trim(String(payload.Has("refresh_token") ? payload["refresh_token"] : ""))
    catch {
    }
    try outAccess := Trim(String(payload.Has("access_token") ? payload["access_token"] : ""))
    catch {
    }
    if (outAccess != "") {
        cookie := "x_pan_client_id=5325; x_pan_access_token=" . outAccess
        cb ? cb.Call(Map("ok", true, "refresh", outRefresh, "access", outAccess, "cookie", cookie, "error", "")) : 0
        return
    }
    msg := ""
    try msg := Trim(String(j.Has("text") ? j["text"] : ""))
    catch {
        msg := ""
    }
    state["lastErr"] := msg
    state["idx"] := state["idx"] + 1
    SetTimer(doReq, -1)
}

CloudPlayer_TryBootstrapQuarkOpen(refreshToken, apiUrlAddress, &outRefresh := "", &outAccess := "", &outAppId := "", &outSignKey := "", &err := "") {
    outRefresh := ""
    outAccess := ""
    outAppId := ""
    outSignKey := ""
    err := ""
    rt := Trim(String(refreshToken))
    api := Trim(String(apiUrlAddress))
    if (rt = "" || api = "") {
        err := "refresh token or api url is empty"
        return false
    }
    sep := InStr(api, "?") ? "&" : "?"
    url := api . sep . "refresh_ui=" . rt . "&server_use=true&driver_txt=quarkyun_oa"
    ret := CloudPlayer_HttpJsonAwait("GET", url)
    if !ret["ok"] {
        err := ret["error"]
        return false
    }
    if !(ret["json"] is Map) {
        err := "renew api returned non-json response"
        return false
    }
    j := ret["json"]
    payload := j
    try {
        if (j.Has("data") && j["data"] is Map)
            payload := j["data"]
    } catch {
        payload := j
    }
    try outRefresh := Trim(String(payload.Has("refresh_token") ? payload["refresh_token"] : ""))
    catch {
        outRefresh := ""
    }
    try outAccess := Trim(String(payload.Has("access_token") ? payload["access_token"] : ""))
    catch {
        outAccess := ""
    }
    try outAppId := Trim(String(payload.Has("app_id") ? payload["app_id"] : ""))
    catch {
        outAppId := ""
    }
    try outSignKey := Trim(String(payload.Has("sign_key") ? payload["sign_key"] : ""))
    catch {
        outSignKey := ""
    }
    if (outAppId = "" || outSignKey = "") {
        msg := ""
        try msg := Trim(String(j.Has("text") ? j["text"] : ""))
        catch {
            msg := ""
        }
        if (msg = "")
            msg := "renew api did not return app_id/sign_key"
        err := msg
        return false
    }
    return true
}

CloudPlayer_TryBootstrapQuarkOpenAsync(refreshToken, apiUrlAddress, callback := 0, reqId := "") {
    cb := IsObject(callback) ? callback : 0
    rt := Trim(String(refreshToken))
    api := Trim(String(apiUrlAddress))
    if (rt = "" || api = "") {
        cb ? cb.Call(Map("ok", false, "error", "refresh token or api url is empty")) : 0
        return
    }
    sep := InStr(api, "?") ? "&" : "?"
    url := api . sep . "refresh_ui=" . rt . "&server_use=true&driver_txt=quarkyun_oa"
    CloudPlayer_HttpJsonAsyncReq("GET", url, 0, "", (ret) => (
        cb ? cb.Call(CloudPlayer_ParseQuarkOpenBootstrapRet(ret)) : 0
    ), reqId, "cp_quark_open_bootstrap")
}

CloudPlayer_ParseQuarkOpenBootstrapRet(ret) {
    if !ret["ok"]
        return Map("ok", false, "error", ret["error"])
    if !(ret["json"] is Map)
        return Map("ok", false, "error", "renew api returned non-json response")
    j := ret["json"]
    payload := j
    try {
        if (j.Has("data") && j["data"] is Map)
            payload := j["data"]
    } catch {
        payload := j
    }
    outRefresh := ""
    outAccess := ""
    outAppId := ""
    outSignKey := ""
    try outRefresh := Trim(String(payload.Has("refresh_token") ? payload["refresh_token"] : ""))
    catch {
    }
    try outAccess := Trim(String(payload.Has("access_token") ? payload["access_token"] : ""))
    catch {
    }
    try outAppId := Trim(String(payload.Has("app_id") ? payload["app_id"] : ""))
    catch {
    }
    try outSignKey := Trim(String(payload.Has("sign_key") ? payload["sign_key"] : ""))
    catch {
    }
    if (outAppId = "" || outSignKey = "") {
        msg := ""
        try msg := Trim(String(j.Has("text") ? j["text"] : ""))
        catch {
            msg := ""
        }
        if (msg = "")
            msg := "renew api did not return app_id/sign_key"
        return Map("ok", false, "error", msg)
    }
    return Map("ok", true, "refresh", outRefresh, "access", outAccess, "appId", outAppId, "signKey", outSignKey, "error", "")
}

CloudPlayer_NormalizeProviderToken(raw) {
    s := Trim(String(raw))
    if (s = "")
        return ""

    if ((SubStr(s, 1, 1) = '"' && SubStr(s, -1) = '"') || (SubStr(s, 1, 1) = "'" && SubStr(s, -1) = "'"))
        s := Trim(SubStr(s, 2, StrLen(s) - 2))
    if (s = "")
        return ""

    if (RegExMatch(s, "i)(?:^|[?&#])refresh_token=([^&#\s]+)", &mRt))
        return CloudPlayer_UrlDecodeToken(mRt[1])
    if (RegExMatch(s, "i)(?:^|[?&#])token=([^&#\s]+)", &mTk))
        return CloudPlayer_UrlDecodeToken(mTk[1])
    q := Chr(34)
    patJson := "i)(?:" . q . "|')?refresh_token(?:" . q . "|')?\s*[:=]\s*(?:" . q . "|')?([^" . q . "',\s\}]+)"
    if (RegExMatch(s, patJson, &mJson))
        return Trim(String(mJson[1]))

    if (SubStr(s, 1, 1) = "{" && SubStr(s, -1) = "}") {
        try {
            j := Jxon_Load(s)
            if (j is Map) {
                try {
                    v := j.Has("refresh_token") ? Trim(String(j["refresh_token"])) : ""
                    if (v != "")
                        return v
                } catch {
                }
                try {
                    v2 := j.Has("refreshToken") ? Trim(String(j["refreshToken"])) : ""
                    if (v2 != "")
                        return v2
                } catch {
                }
                try {
                    d := j.Has("data") ? j["data"] : 0
                    if (d is Map) {
                        v3 := d.Has("refresh_token") ? Trim(String(d["refresh_token"])) : ""
                        if (v3 != "")
                            return v3
                        v4 := d.Has("refreshToken") ? Trim(String(d["refreshToken"])) : ""
                        if (v4 != "")
                            return v4
                    }
                } catch {
                }
            }
        } catch {
        }
    }
    return s
}

CloudPlayer_UrlDecodeToken(s) {
    t := String(s)
    t := StrReplace(t, "+", " ")
    out := ""
    i := 1
    n := StrLen(t)
    while (i <= n) {
        ch := SubStr(t, i, 1)
        if (ch = "%" && i + 2 <= n) {
            hx := SubStr(t, i + 1, 2)
            if RegExMatch(hx, "i)^[0-9a-f]{2}$") {
                out .= Chr("0x" . hx)
                i += 3
                continue
            }
        }
        out .= ch
        i += 1
    }
    return out
}

CloudPlayer_ToBool(val, defaultVal := false) {
    try {
        if (Type(val) = "Integer" || Type(val) = "Float")
            return !!val
        s := StrLower(Trim(String(val)))
        if (s = "true" || s = "1" || s = "yes" || s = "on")
            return true
        if (s = "false" || s = "0" || s = "no" || s = "off")
            return false
    } catch {
    }
    return !!defaultVal
}

CloudPlayer_ResolveDownloadAuthToken(passedToken := "", &errMsg := "") {
    errMsg := ""
    tk := Trim(String(passedToken))
    if (tk != "")
        return tk
    admin := CloudPlayer_GetOpenListAdminToken(&errMsg, 12000)
    if (admin != "")
        return admin
    return ""
}

CloudPlayer_GetOpenListAdminToken(&errMsg := "", timeoutMs := 12000) {
    errMsg := ""
    exe := CloudPlayer_FindOpenListExe()
    if (exe = "") {
        errMsg := "openlist executable not found"
        return ""
    }
    wd := CloudPlayer_GetWorkDir(exe)
    q := Chr(34)

    ; Try both data-dir modes to match different runtime setups.
    cmd1 := A_ComSpec . " /d /c " . q . "cd /d " . q . wd . q . " && " . q . exe . q . " --data data admin token" . q
    cmd2 := A_ComSpec . " /d /c " . q . "cd /d " . q . wd . q . " && " . q . exe . q . " admin token" . q
    attempts := [cmd1, cmd2]

    lastErr := ""
    for _, cmd in attempts {
        cap := CloudPlayer_ExecCapture(cmd, timeoutMs)
        out := ""
        try out := String(cap["stdout"])
        catch {
            out := ""
        }
        err := ""
        try err := String(cap["stderr"])
        catch {
            err := ""
        }
        allText := out . "`n" . err
        if RegExMatch(allText, "i)Admin token:\s*([^\s`r`n]+)", &m)
            return Trim(String(m[1]))

        timedOut := false
        try timedOut := !!cap["timedOut"]
        catch {
            timedOut := false
        }
        if timedOut
            lastErr := "getting OpenList admin token timed out (" . timeoutMs . "ms)"
        else if (Trim(allText) != "")
            lastErr := "cannot parse admin token from output: " . Trim(SubStr(RegExReplace(allText, "\s+", " "), 1, 220))
        else
            lastErr := "cannot parse admin token from empty output"
    }
    errMsg := (lastErr != "") ? lastErr : "failed to get OpenList admin token"
    return ""
}

CloudPlayer_GetOpenListAdminTokenAsync(callback := 0, timeoutMs := 12000, reqId := "", tag := "cp_admin_token") {
    global g_CloudPlayerAdminTokenJobs
    cb := IsObject(callback) ? callback : 0
    exe := CloudPlayer_FindOpenListExe()
    if (exe = "") {
        cb ? cb.Call(Map("ok", false, "token", "", "error", "openlist executable not found")) : 0
        return
    }
    wd := CloudPlayer_GetWorkDir(exe)
    q := Chr(34)
    cmd1 := A_ComSpec . " /d /c " . q . "cd /d " . q . wd . q . " && " . q . exe . q . " --data data admin token" . q
    cmd2 := A_ComSpec . " /d /c " . q . "cd /d " . q . wd . q . " && " . q . exe . q . " admin token" . q
    jobId := "admintok_" . A_TickCount . "_" . Random(1000, 999999)
    job := Map(
        "id", jobId,
        "attempts", [cmd1, cmd2],
        "idx", 1,
        "timeoutMs", Max(1000, Integer(timeoutMs)),
        "reqId", Trim(String(reqId)),
        "tag", String(tag),
        "cb", cb,
        "ex", 0,
        "t0", 0,
        "out", "",
        "err", "",
        "lastErr", "",
        "done", false
    )
    g_CloudPlayerAdminTokenJobs[jobId] := job
    CloudPlayer_AdminTokenStartAttempt(jobId)
}

CloudPlayer_AdminTokenStartAttempt(jobId) {
    global g_CloudPlayerAdminTokenJobs
    if !g_CloudPlayerAdminTokenJobs.Has(jobId)
        return
    job := g_CloudPlayerAdminTokenJobs[jobId]
    if (job["idx"] > job["attempts"].Length) {
        CloudPlayer_AdminTokenFinish(jobId, false, "", job["lastErr"] != "" ? job["lastErr"] : "failed to get OpenList admin token")
        return
    }
    cmd := job["attempts"][job["idx"]]
    try ex := ComObject("WScript.Shell").Exec(String(cmd))
    catch as e {
        job["lastErr"] := e.Message
        job["idx"] := job["idx"] + 1
        g_CloudPlayerAdminTokenJobs[jobId] := job
        SetTimer(CloudPlayer_AdminTokenStartAttempt.Bind(jobId), -1)
        return
    }
    job["ex"] := ex
    job["t0"] := A_TickCount
    job["out"] := ""
    job["err"] := ""
    g_CloudPlayerAdminTokenJobs[jobId] := job
    SetTimer(CloudPlayer_AdminTokenPoll.Bind(jobId), 40)
}

CloudPlayer_AdminTokenPoll(jobId) {
    global g_CloudPlayerAdminTokenJobs
    if !g_CloudPlayerAdminTokenJobs.Has(jobId) {
        SetTimer(CloudPlayer_AdminTokenPoll.Bind(jobId), 0)
        return
    }
    job := g_CloudPlayerAdminTokenJobs[jobId]
    ex := job["ex"]
    if !IsObject(ex) {
        SetTimer(CloudPlayer_AdminTokenPoll.Bind(jobId), 0)
        return
    }
    try {
        while !ex.StdOut.AtEndOfStream
            job["out"] .= ex.StdOut.Read(4096)
    } catch {
    }
    try {
        while !ex.StdErr.AtEndOfStream
            job["err"] .= ex.StdErr.Read(2048)
    } catch {
    }
    if (ex.Status != 0) {
        SetTimer(CloudPlayer_AdminTokenPoll.Bind(jobId), 0)
        allText := job["out"] . "`n" . job["err"]
        if RegExMatch(allText, "i)Admin token:\s*([^\s`r`n]+)", &m) {
            CloudPlayer_AdminTokenFinish(jobId, true, Trim(String(m[1])), "")
            return
        }
        if (Trim(allText) != "")
            job["lastErr"] := "cannot parse admin token from output: " . Trim(SubStr(RegExReplace(allText, "\s+", " "), 1, 220))
        else
            job["lastErr"] := "cannot parse admin token from empty output"
        job["idx"] := job["idx"] + 1
        g_CloudPlayerAdminTokenJobs[jobId] := job
        SetTimer(CloudPlayer_AdminTokenStartAttempt.Bind(jobId), -1)
        return
    }
    if ((A_TickCount - Integer(job["t0"])) > Integer(job["timeoutMs"])) {
        SetTimer(CloudPlayer_AdminTokenPoll.Bind(jobId), 0)
        try ex.Terminate()
        catch {
        }
        job["lastErr"] := "getting OpenList admin token timed out (" . job["timeoutMs"] . "ms)"
        job["idx"] := job["idx"] + 1
        g_CloudPlayerAdminTokenJobs[jobId] := job
        SetTimer(CloudPlayer_AdminTokenStartAttempt.Bind(jobId), -1)
        return
    }
    g_CloudPlayerAdminTokenJobs[jobId] := job
}

CloudPlayer_AdminTokenFinish(jobId, ok, token := "", err := "") {
    global g_CloudPlayerAdminTokenJobs
    if !g_CloudPlayerAdminTokenJobs.Has(jobId)
        return
    job := g_CloudPlayerAdminTokenJobs[jobId]
    cb := job["cb"]
    rid := job["reqId"]
    tag := job["tag"]
    try CoreAsyncHttp_Log(ok ? "cloudplayer_admin_token_done" : "cloudplayer_admin_token_failed", "req_id=" . rid . " tag=" . tag . " ok=" . (ok ? 1 : 0))
    g_CloudPlayerAdminTokenJobs.Delete(jobId)
    cb ? cb.Call(Map("ok", !!ok, "token", String(token), "error", String(err))) : 0
}

CloudPlayer_ExecCapture(cmd, timeoutMs := 12000) {
    result := Map("stdout", "", "stderr", "", "timedOut", false, "exitCode", "")
    ex := 0
    try ex := ComObject("WScript.Shell").Exec(String(cmd))
    catch as e {
        result["stderr"] := e.Message
        return result
    }

    t0 := A_TickCount
    outText := ""
    errText := ""
    while true {
        try {
            while !ex.StdOut.AtEndOfStream
                outText .= ex.StdOut.Read(4096)
        } catch {
        }
        try {
            while !ex.StdErr.AtEndOfStream
                errText .= ex.StdErr.Read(2048)
        } catch {
        }
        if (ex.Status != 0)
            break
        if ((A_TickCount - t0) > timeoutMs) {
            result["timedOut"] := true
            try ex.Terminate()
            break
        }
        Sleep(30)
    }

    try {
        while !ex.StdOut.AtEndOfStream
            outText .= ex.StdOut.Read(4096)
    } catch {
    }
    try {
        while !ex.StdErr.AtEndOfStream
            errText .= ex.StdErr.Read(2048)
    } catch {
    }
    try result["exitCode"] := ex.ExitCode
    catch {
    }
    result["stdout"] := outText
    result["stderr"] := errText
    return result
}

CloudPlayer_VerifyMountList(mountPath, headers) {
    global g_CloudPlayerApiBase
    ret := Map("ok", false, "count", 0, "message", "")
    payload := Map("path", String(mountPath), "password", "", "page", 1, "per_page", 100, "refresh", true)
    body := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(payload), ["refresh"])
    fsRet := CloudPlayer_HttpJsonAwait("POST", g_CloudPlayerApiBase . "/api/fs/list", headers, body)
    if !fsRet["ok"] {
        ret["message"] := fsRet["error"]
        return ret
    }
    j := fsRet["json"]
    if !(j is Map) {
        ret["message"] := "invalid fs/list response"
        return ret
    }
    code := ""
    try code := Integer(j.Has("code") ? j["code"] : 0)
    catch {
        code := 0
    }
    if (code != 200) {
        msg := ""
        try msg := String(j.Has("message") ? j["message"] : "")
        catch {
            msg := ""
        }
        ret["message"] := (msg != "") ? msg : ("fs/list code " . code)
        return ret
    }
    cnt := 0
    try {
        d := j["data"]
        if (d is Map && d.Has("content") && d["content"] is Array)
            cnt := d["content"].Length
    } catch {
        cnt := 0
    }
    ret["ok"] := true
    ret["count"] := cnt
    return ret
}

CloudPlayer_VerifyMountListAsync(mountPath, headers, callback := 0, reqId := "") {
    global g_CloudPlayerApiBase
    cb := IsObject(callback) ? callback : 0
    payload := Map("path", String(mountPath), "password", "", "page", 1, "per_page", 100, "refresh", true)
    body := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(payload), ["refresh"])
    CloudPlayer_HttpJsonAsyncReq("POST", g_CloudPlayerApiBase . "/api/fs/list", headers, body, (fsRet) => (
        cb ? cb.Call(CloudPlayer_ParseVerifyMountListRet(fsRet)) : 0
    ), reqId, "cp_verify_mount")
}

CloudPlayer_ParseVerifyMountListRet(fsRet) {
    ret := Map("ok", false, "count", 0, "message", "")
    if !fsRet["ok"] {
        ret["message"] := fsRet["error"]
        return ret
    }
    j := fsRet["json"]
    if !(j is Map) {
        ret["message"] := "invalid fs/list response"
        return ret
    }
    code := 0
    try code := Integer(j.Has("code") ? j["code"] : 0)
    catch {
        code := 0
    }
    if (code != 200) {
        msg := ""
        try msg := String(j.Has("message") ? j["message"] : "")
        catch {
            msg := ""
        }
        ret["message"] := (msg != "") ? msg : ("fs/list code " . code)
        return ret
    }
    cnt := 0
    try {
        d := j["data"]
        if (d is Map && d.Has("content") && d["content"] is Array)
            cnt := d["content"].Length
    } catch {
        cnt := 0
    }
    ret["ok"] := true
    ret["count"] := cnt
    return ret
}

CloudPlayer_JsonForceBoolLiterals(jsonText, keys) {
    out := String(jsonText)
    q := Chr(34)
    for _, key in keys {
        pat0 := q . key . q . ":\s*0(?=\s*[,}])"
        pat1 := q . key . q . ":\s*1(?=\s*[,}])"
        out := RegExReplace(out, pat0, q . key . q . ":false")
        out := RegExReplace(out, pat1, q . key . q . ":true")
    }
    return out
}

CloudPlayer_NormalizeApiBase(apiBase) {
    s := Trim(String(apiBase))
    if (s = "")
        s := "http://127.0.0.1:5244"
    if !RegExMatch(s, "i)^https?://")
        s := "http://" . LTrim(s, "/")
    return RTrim(s, "/")
}

CloudPlayer_NormalizeManifestFiles(files) {
    if !(files is Array)
        return []
    out := []
    for _, raw in files {
        if (raw is Map)
            out.Push(raw)
    }
    return out
}

CloudPlayer_RelPathUnderRoot(rootPath, fullPath) {
    root := CloudPlayer_NormalizeRemotePath(rootPath)
    full := CloudPlayer_NormalizeRemotePath(fullPath)
    prefix := (root = "/") ? "/" : (root . "/")
    if (SubStr(full, 1, StrLen(prefix)) = prefix)
        return SubStr(full, StrLen(prefix) + 1)
    return CloudPlayer_RemoteBaseName(full)
}

CloudPlayer_StopDownloadJob() {
    global g_CloudPlayerDlJob, g_CloudPlayerDlThreadRunning, g_CloudPlayerDlLastListErr
    SetTimer(CloudPlayer_DownloadJobTick, 0)
    g_CloudPlayerDlJob := 0
    g_CloudPlayerDlThreadRunning := false
    g_CloudPlayerDlLastListErr := ""
}

CloudPlayer_DownloadJobTick(*) {
    global g_CloudPlayerDlJob
    if !(g_CloudPlayerDlJob is Map)
        return
    if (g_CloudPlayerDlJob.Has("nextAt") && A_TickCount < Integer(g_CloudPlayerDlJob["nextAt"]))
        return
    g_CloudPlayerDlJob["nextAt"] := 0
    try {
        if !CloudPlayer_DownloadJobStep(g_CloudPlayerDlJob)
            CloudPlayer_StopDownloadJob()
    } catch as e {
        rid := g_CloudPlayerDlJob.Has("reqId") ? String(g_CloudPlayerDlJob["reqId"]) : ""
        name := g_CloudPlayerDlJob.Has("folderName") ? String(g_CloudPlayerDlJob["folderName"]) : ""
        try CloudPlayer_PostDownloadResult(false, e.Message, "", name, rid, "exception")
        catch {
        }
        try CloudPlayer_ClearDownloadCancelled(rid)
        catch {
        }
        CloudPlayer_StopDownloadJob()
    }
}

CloudPlayer_DownloadJobStep(job) {
    if !(job is Map) || !job.Has("phase")
        return false
    phase := String(job["phase"])
    if (phase = "init")
        return CloudPlayer_DownloadJobPhaseInit(job)
    if (phase = "scan")
        return CloudPlayer_DownloadJobPhaseScan(job)
    if (phase = "download")
        return CloudPlayer_DownloadJobPhaseDownloadOne(job)
    if (phase = "zip")
        return CloudPlayer_DownloadJobPhaseZip(job)
    return false
}

CloudPlayer_DownloadJobPhaseInit(job) {
    global g_CloudPlayerDlLastListErr
    rid := job.Has("reqId") ? Trim(String(job["reqId"])) : ""
    g_CloudPlayerDlLastListErr := ""
    name := job.Has("folderName") ? String(job["folderName"]) : "cloud-folder"
    if CloudPlayer_CheckDownloadStale(rid, "job_init")
        return false
    if CloudPlayer_CheckDownloadCancelled(rid, "job_init") {
        CloudPlayer_PostDownloadResult(false, "cancelled", "", name, rid, "cancelled")
        return false
    }
    CloudPlayer_PostDownloadProgress("打包下载：准备中...", rid, "preparing", CloudPlayer_DownloadPhasePercent("preparing"))
    passedTk := Trim(String(job.Has("userToken") ? job["userToken"] : (job.Has("token") ? job["token"] : "")))
    adminFromPayload := Trim(String(job.Has("adminToken") ? job["adminToken"] : ""))
    errTok := ""
    apiTok := adminFromPayload != "" ? adminFromPayload : CloudPlayer_ResolveDownloadAuthToken(passedTk, &errTok)
    if (apiTok = "") {
        CloudPlayer_PostDownloadResult(false, "无法获取 OpenList 管理员 Token" . (errTok != "" ? ("：" . errTok) : ""), "", name, rid, "no_token")
        CloudPlayer_ClearDownloadCancelled(rid)
        return false
    }
    job["userToken"] := passedTk
    job["token"] := apiTok
    try CoreAsyncHttp_Log("cloudplayer_dl_token", "req_id=" . rid . " admin=" . StrLen(apiTok) . " user=" . StrLen(passedTk) . " same=" . (passedTk != "" && passedTk = apiTok ? 1 : 0))
    headers := Map("Content-Type", "application/json", "Accept", "application/json")
    headers["Authorization"] := apiTok
    p := CloudPlayer_NormalizeRemotePath(job.Has("folderPath") ? job["folderPath"] : "/")
    if (name = "")
        name := CloudPlayer_SafeFileName(CloudPlayer_RemoteBaseName(p))
    if (name = "")
        name := "cloud-folder"
    job["folderName"] := name
    job["headers"] := headers
    outDir := CloudPlayer_DownloadsDir() . "\牛马云下载"
    DirCreate(outDir)
    stamp := FormatTime(, "yyyyMMdd_HHmmss")
    dlMode := job.Has("downloadMode") ? String(job["downloadMode"]) : "zip"
    zipPath := outDir . "\" . name . "_" . stamp . ".zip"
    workRoot := (dlMode = "batch") ? (outDir . "\" . name . "_" . stamp) : (A_Temp . "\Nc_" . A_TickCount)
    stageRoot := (dlMode = "batch") ? workRoot : (workRoot . "\" . name)
    DirCreate(stageRoot)
    job["stats"] := Map("files", 0, "failed", 0, "scanned", 0)
    job["zipCtx"] := Map("name", name, "workRoot", workRoot, "stageRoot", stageRoot, "zipPath", zipPath, "stats", job["stats"])
    job["walkOk"] := true
    mf := CloudPlayer_NormalizeManifestFiles(job.Has("manifestFiles") ? job["manifestFiles"] : 0)
    job["manifestFiles"] := mf
    if mf.Length > 0 {
        job["fileQueue"] := mf
        job["fileIndex"] := 0
        job["fileTotal"] := mf.Length
        job["stats"]["scanned"] := 1
        job["dlStep"] := "pick"
        job["phase"] := "download"
        try CoreAsyncHttp_Log("cloudplayer_dl_manifest", "req_id=" . rid . " count=" . mf.Length)
        CloudPlayer_PostDownloadProgress("打包下载：共 " . mf.Length . " 个文件，开始下载...", rid, "downloading", CloudPlayer_DownloadPhasePercent("downloading", 0, mf.Length))
        return true
    }
    job["fileQueue"] := []
    job["fileIndex"] := 0
    job["fileTotal"] := 0
    job["scanQueue"] := [Map("remote", p, "local", stageRoot)]
    job["scanDirs"] := 0
    job["phase"] := "scan"
    CloudPlayer_PostDownloadProgress("打包下载：正在扫描文件夹...", rid, "scanning", CloudPlayer_DownloadPhasePercent("scanning", 0))
    return true
}

CloudPlayer_DownloadJobPhaseScan(job) {
    global g_CloudPlayerDlLastListErr
    rid := job.Has("reqId") ? Trim(String(job["reqId"])) : ""
    if CloudPlayer_CheckDownloadStale(rid, "job_scan") || CloudPlayer_CheckDownloadCancelled(rid, "job_scan") {
        job["walkOk"] := false
        job["phase"] := "zip"
        return true
    }
    q := job.Has("scanQueue") ? job["scanQueue"] : []
    asyncPipe := CloudPlayer_UseAsyncDownloadScan()
    hasScanPending := asyncPipe && job.Has("scanPending") && !!job["scanPending"]
    hasScanReady := asyncPipe && job.Has("scanReady") && !!job["scanReady"]
    hasScanCurrent := asyncPipe && job.Has("scanCurrent") && (job["scanCurrent"] is Map) && job["scanCurrent"].Count > 0
    if (asyncPipe && hasScanCurrent && !hasScanPending && !hasScanReady) {
        startedAt := job.Has("scanCurrentSince") ? Integer(job["scanCurrentSince"]) : 0
        if (startedAt > 0 && (A_TickCount - startedAt) > 20000) {
            try CoreAsyncHttp_Log("cloudplayer_dl_scan_watchdog", "req_id=" . rid . " action=requeue_current reason=scan_callback_missing")
            cur := job["scanCurrent"]
            if (cur is Map && cur.Count > 0 && q is Array)
                q.InsertAt(1, cur)
            job["scanCurrent"] := Map()
            job["scanCurrentSince"] := 0
            job["scanPending"] := false
            job["scanPendingSince"] := 0
            job["scanReady"] := false
            hasScanCurrent := false
        }
    }
    if !(q is Array) || q.Length = 0 {
        if (hasScanPending || hasScanReady || hasScanCurrent) {
            job["nextAt"] := A_TickCount + 40
            return true
        }
        fq := CloudPlayer_NormalizeManifestFiles(job.Has("fileQueue") ? job["fileQueue"] : [])
        job["fileQueue"] := fq
        job["fileTotal"] := fq.Length
        job["fileIndex"] := 0
        job["dlStep"] := "pick"
        if (fq.Length > 0) {
            job["phase"] := "download"
            CloudPlayer_PostDownloadProgress("打包下载：扫描完成，共 " . fq.Length . " 个文件，开始下载...", rid, "downloading", CloudPlayer_DownloadPhasePercent("downloading", 0, fq.Length))
        } else {
            job["phase"] := "zip"
        }
        return true
    }
    scanDirs := job.Has("scanDirs") ? Integer(job["scanDirs"]) : 0
    if (scanDirs >= 64) {
        job["phase"] := "zip"
        return true
    }
    if (asyncPipe && job.Has("scanPending") && !!job["scanPending"]) {
        pendAt := job.Has("scanPendingSince") ? Integer(job["scanPendingSince"]) : 0
        if (pendAt > 0 && (A_TickCount - pendAt) > 20000) {
            try CoreAsyncHttp_Log("cloudplayer_dl_scan_watchdog", "req_id=" . rid . " action=reset_pending reason=scan_pending_timeout")
            job["scanPending"] := false
            job["scanPendingSince"] := 0
            job["scanReady"] := false
        } else {
            job["nextAt"] := A_TickCount + 40
            return true
        }
    }
    if (asyncPipe && job.Has("scanReady") && !!job["scanReady"]) {
        job0 := job.Has("scanCurrent") ? job["scanCurrent"] : Map()
    } else {
        job0 := q.RemoveAt(1)
        if !(job0 is Map)
            return true
        if asyncPipe {
            job["scanCurrent"] := job0
            job["scanCurrentSince"] := A_TickCount
        }
    }
    rp := job0.Has("remote") ? String(job0["remote"]) : ""
    loc := job0.Has("local") ? String(job0["local"]) : ""
    headers := job.Has("headers") ? job["headers"] : Map()
    stats := job["stats"]
    job["scanDirs"] := scanDirs + 1
    stats["scanned"] := job["scanDirs"]
    scanPct := Min(24, 10 + job["scanDirs"])
    CloudPlayer_PostDownloadProgress("打包下载：扫描 " . rp . " ...", rid, "scanning", scanPct)
    try DirCreate(CloudPlayer_ToWinLongPath(loc))
    if asyncPipe {
        if (!job.Has("scanReady") || !job["scanReady"]) {
            job["scanPending"] := true
            job["scanPendingSince"] := A_TickCount
            job["scanPath"] := rp
            uid := job.Has("jobUid") ? String(job["jobUid"]) : ""
            CloudPlayer_ListFolderItemsAsync(rp, headers, rid, (ret) => CloudPlayer_DownloadScan_OnListed(rid, uid, rp, ret))
            job["nextAt"] := A_TickCount + 40
            return true
        }
        job["scanReady"] := false
        job["scanCurrent"] := Map()
        job["scanCurrentSince"] := 0
        items := job.Has("scanItems") ? job["scanItems"] : []
        errList := job.Has("scanErr") ? String(job["scanErr"]) : ""
        if (errList != "") {
            g_CloudPlayerDlLastListErr := errList
            job["walkOk"] := false
            job["walkErr"] := errList
            job["phase"] := "zip"
            return true
        }
    } else {
        items := CloudPlayer_ListFolderItemsSync(rp, headers, rid)
        if (g_CloudPlayerDlLastListErr != "") {
            job["walkOk"] := false
            job["walkErr"] := String(g_CloudPlayerDlLastListErr)
            job["phase"] := "zip"
            return true
        }
    }
    try {
        if (items is Array && items.Length > 0) {
            sample := CloudPlayer_WalkItemAsMap(items[1])
            sn := sample.Has("name") ? String(sample["name"]) : ""
            sp := sample.Has("path") ? String(sample["path"]) : ""
            sd := sample.Has("is_dir") ? String(sample["is_dir"]) : ""
            ss := sample.Has("size") ? String(sample["size"]) : ""
            CoreAsyncHttp_Log("cloudplayer_dl_scan_sample", "req_id=" . rid . " path=" . rp . " n=" . sn . " p=" . sp . " d=" . sd . " s=" . ss)
        } else {
            CoreAsyncHttp_Log("cloudplayer_dl_scan_sample", "req_id=" . rid . " path=" . rp . " empty=1")
        }
    }
    rootPath := job.Has("folderPath") ? job["folderPath"] : "/"
    fq := job.Has("fileQueue") ? job["fileQueue"] : []
    if !(fq is Array)
        fq := []
    for _, rawItem in items {
        item := CloudPlayer_WalkItemAsMap(rawItem)
        try nm := Trim(String(item.Has("name") ? item["name"] : ""))
        catch {
            nm := ""
        }
        if (nm = "")
            continue
        childRemote := CloudPlayer_WalkItemRemotePath(item, rp, nm)
        if CloudPlayer_WalkItemIsDir(item, nm) {
            safeName := CloudPlayer_SafeFileName(nm)
            if (safeName = "")
                safeName := "item"
            q.Push(Map("remote", childRemote, "local", loc . "\" . safeName))
            continue
        }
        fq.Push(Map(
            "path", childRemote,
            "name", nm,
            "sign", CloudPlayer_WalkItemSign(item),
            "rel", CloudPlayer_RelPathUnderRoot(rootPath, childRemote)
        ))
    }
    job["fileQueue"] := fq
    job["scanQueue"] := q
    job["nextAt"] := A_TickCount + 80
    Sleep(0)
    return true
}

CloudPlayer_DownloadJobPhaseDownloadOne(job) {
    if CloudPlayer_UseAsyncDownloadPipeline()
        return CloudPlayer_DownloadJobPhaseDownloadAsync(job)
    rid := job.Has("reqId") ? Trim(String(job["reqId"])) : ""
    if CloudPlayer_CheckDownloadStale(rid, "job_dl") || CloudPlayer_CheckDownloadCancelled(rid, "job_dl") {
        job["walkOk"] := false
        job["phase"] := "zip"
        return true
    }
    q := job.Has("fileQueue") ? job["fileQueue"] : []
    idx := job.Has("fileIndex") ? Integer(job["fileIndex"]) : 0
    total := job.Has("fileTotal") ? Integer(job["fileTotal"]) : (q is Array ? q.Length : 0)
    if !(q is Array) || idx >= total {
        job["phase"] := "zip"
        return true
    }
    step := job.Has("dlStep") ? String(job["dlStep"]) : "pick"
    stats := job["stats"]
    zipCtx := job["zipCtx"]
    stageRoot := zipCtx.Has("stageRoot") ? String(zipCtx["stageRoot"]) : ""
    headers := job.Has("headers") ? job["headers"] : Map()
    token := job.Has("token") ? job["token"] : ""

    if (step = "pick") {
        rawItem := q[idx + 1]
        item := CloudPlayer_WalkItemAsMap(rawItem)
        childRemote := ""
        try childRemote := Trim(String(item.Has("path") ? item["path"] : ""))
        catch {
            childRemote := ""
        }
        if (childRemote = "")
            childRemote := CloudPlayer_CombineRemotePath(job.Has("folderPath") ? job["folderPath"] : "/", item.Has("name") ? item["name"] : "")
        rel := ""
        try rel := Trim(String(item.Has("rel") ? item["rel"] : ""))
        catch {
            rel := ""
        }
    if (rel = "")
        rel := CloudPlayer_RemoteBaseName(childRemote)
    rel := CloudPlayer_SanitizeLocalRelPath(rel)
    listSign := ""
        try listSign := Trim(String(item.Has("sign") ? item["sign"] : ""))
        catch {
            listSign := ""
        }
        if (listSign = "")
            listSign := CloudPlayer_WalkItemSign(item)
        job["dlCur"] := Map(
            "remote", childRemote,
            "local", stageRoot . "\" . rel,
            "sign", listSign,
            "name", CloudPlayer_RemoteBaseName(childRemote),
            "manifestItem", item
        )
        curN := idx + 1
        nm := job["dlCur"].Has("name") ? String(job["dlCur"]["name"]) : ("#" . curN)
        CloudPlayer_PostDownloadProgress("打包下载：正在下载 " . curN . "/" . total . " " . nm . " ...", rid, "downloading", CloudPlayer_DownloadPhasePercent("downloading", idx, total))
        try CoreAsyncHttp_Log("cloudplayer_dl_job_file", "req_id=" . rid . " n=" . curN . "/" . total . " remote=" . childRemote . " sign=" . StrLen(listSign))
        job["dlStep"] := "fetch"
        Sleep(0)
        return true
    }

    cur := job.Has("dlCur") ? job["dlCur"] : Map()
    childRemote := cur.Has("remote") ? String(cur["remote"]) : ""
    childLocal := cur.Has("local") ? String(cur["local"]) : ""
    listSign := cur.Has("sign") ? String(cur["sign"]) : ""

    if (step = "fetch") {
        if (childRemote = "") {
            stats["failed"] += 1
            job["fileIndex"] := idx + 1
            job["dlStep"] := "pick"
            job["nextAt"] := A_TickCount + 100
            if (job["fileIndex"] >= total)
                job["phase"] := "zip"
            return true
        }
        try {
            d := RegExReplace(CloudPlayer_ToWinLongPath(childLocal), "\\[^\\]*$")
            if (d != "")
                DirCreate(d)
        } catch {
        }
        job["dlData"] := CloudPlayer_FetchFsGetDataSync(childRemote, headers, rid)
        job["dlStep"] := "save"
        Sleep(0)
        return true
    }

    if (step = "save") {
        data := job.Has("dlData") ? job["dlData"] : 0
        freshSign := CloudPlayer_ParseFsGetSign(data)
        if (freshSign != "")
            listSign := freshSign
        else if (listSign = "") {
            try CoreAsyncHttp_Log("cloudplayer_dl_no_sign", "req_id=" . rid . " remote=" . childRemote)
        }
        manifestItem := (cur is Map && cur.Has("manifestItem")) ? cur["manifestItem"] : Map()
        userTok := job.Has("userToken") ? Trim(String(job["userToken"])) : ""
        apiTok := job.Has("token") ? Trim(String(job["token"])) : ""
        dlTok := userTok != "" ? userTok : apiTok
        fbTok := (userTok != "" && apiTok != "" && userTok != apiTok) ? apiTok : ""
        expSize := 0
        if (data is Map && data.Has("size")) {
            try expSize := Integer(data["size"])
            catch {
                expSize := 0
            }
        }
        dlRes := CloudPlayer_DownloadWalkSaveFile(childLocal, childRemote, dlTok, data, listSign, rid, fbTok, manifestItem, expSize)
        if dlRes["ok"]
            stats["files"] += 1
        else
            stats["failed"] += 1
        job["fileIndex"] := idx + 1
        job["dlStep"] := "pick"
        done := job["fileIndex"]
        CloudPlayer_PostDownloadProgress("打包下载：已处理 " . done . "/" . total . "（成功 " . stats["files"] . "，失败 " . stats["failed"] . "）...", rid, "downloading", CloudPlayer_DownloadPhasePercent("downloading", done, total))
        job["nextAt"] := A_TickCount + 400
        if (job["fileIndex"] >= total)
            job["phase"] := "zip"
        Sleep(0)
        return true
    }

    job["dlStep"] := "pick"
    return true
}

CloudPlayer_DownloadJobPhaseDownloadAsync(job) {
    rid := job.Has("reqId") ? Trim(String(job["reqId"])) : ""
    if CloudPlayer_CheckDownloadStale(rid, "job_dl_async") || CloudPlayer_CheckDownloadCancelled(rid, "job_dl_async") {
        job["walkOk"] := false
        job["phase"] := "zip"
        return true
    }
    q := job.Has("fileQueue") ? job["fileQueue"] : []
    total := job.Has("fileTotal") ? Integer(job["fileTotal"]) : (q is Array ? q.Length : 0)
    idx := job.Has("fileIndex") ? Integer(job["fileIndex"]) : 0
    if !(q is Array) || idx >= total {
        job["phase"] := "zip"
        return true
    }
    headers := job.Has("headers") ? job["headers"] : Map()
    maxConc := job.Has("resolveMax") ? Integer(job["resolveMax"]) : 4
    if (maxConc <= 0)
        maxConc := 4
    inflight := job.Has("resolveInFlight") ? Integer(job["resolveInFlight"]) : 0
    nextIdx := job.Has("resolveNext") ? Integer(job["resolveNext"]) : idx
    uid := job.Has("jobUid") ? String(job["jobUid"]) : ""
    pending := job.Has("resolvePending") ? job["resolvePending"] : Map()
    cache := job.Has("resolveCache") ? job["resolveCache"] : Map()
    while (inflight < maxConc && nextIdx < total) {
        if !pending.Has(nextIdx) {
            idxLaunch := nextIdx
            raw := q[idxLaunch + 1]
            item := CloudPlayer_WalkItemAsMap(raw)
            childRemote := ""
            try childRemote := Trim(String(item.Has("path") ? item["path"] : ""))
            catch {
                childRemote := ""
            }
            if (childRemote = "")
                childRemote := CloudPlayer_CombineRemotePath(job.Has("folderPath") ? job["folderPath"] : "/", item.Has("name") ? item["name"] : "")
            remoteLaunch := childRemote
            pending[idxLaunch] := remoteLaunch
            inflight += 1
            ; Publish state before dispatch to avoid race when callback returns immediately.
            job["resolveInFlight"] := inflight
            job["resolvePending"] := pending
            job["resolveNext"] := nextIdx + 1
            CloudPlayer_FetchFsGetDataAsync(remoteLaunch, headers, rid, (ret) => CloudPlayer_DownloadResolve_OnDone(rid, uid, idxLaunch, remoteLaunch, ret))
        }
        nextIdx += 1
    }
    ; Keep callback-side updates authoritative (inflight/pending/cache may change reentrantly).
    if !job.Has("resolveNext") || Integer(job["resolveNext"]) < nextIdx
        job["resolveNext"] := nextIdx
    if !cache.Has(idx) {
        job["nextAt"] := A_TickCount + 40
        return true
    }
    data := cache[idx]
    cache.Delete(idx)
    rawItem := q[idx + 1]
    item := CloudPlayer_WalkItemAsMap(rawItem)
    childRemote := ""
    try childRemote := Trim(String(item.Has("path") ? item["path"] : ""))
    catch {
        childRemote := ""
    }
    if (childRemote = "")
        childRemote := CloudPlayer_CombineRemotePath(job.Has("folderPath") ? job["folderPath"] : "/", item.Has("name") ? item["name"] : "")
    rel := ""
    try rel := Trim(String(item.Has("rel") ? item["rel"] : ""))
    catch {
        rel := ""
    }
    if (rel = "")
        rel := CloudPlayer_RemoteBaseName(childRemote)
    rel := CloudPlayer_SanitizeLocalRelPath(rel)
    zipCtx := job["zipCtx"]
    stageRoot := zipCtx.Has("stageRoot") ? String(zipCtx["stageRoot"]) : ""
    childLocal := stageRoot . "\" . rel
    try {
        d := RegExReplace(CloudPlayer_ToWinLongPath(childLocal), "\\[^\\]*$")
        if (d != "")
            DirCreate(d)
    } catch {
    }
    listSign := ""
    try listSign := Trim(String(item.Has("sign") ? item["sign"] : ""))
    catch {
        listSign := ""
    }
    freshSign := CloudPlayer_ParseFsGetSign(data)
    if (freshSign != "")
        listSign := freshSign
    else if (listSign = "") {
        try CoreAsyncHttp_Log("cloudplayer_dl_no_sign", "req_id=" . rid . " remote=" . childRemote)
    }
    stats := job["stats"]
    userTok := job.Has("userToken") ? Trim(String(job["userToken"])) : ""
    apiTok := job.Has("token") ? Trim(String(job["token"])) : ""
    dlTok := userTok != "" ? userTok : apiTok
    fbTok := (userTok != "" && apiTok != "" && userTok != apiTok) ? apiTok : ""
    expSize := 0
    if (data is Map && data.Has("size")) {
        try expSize := Integer(data["size"])
        catch {
            expSize := 0
        }
    }
    dlRes := CloudPlayer_DownloadWalkSaveFile(childLocal, childRemote, dlTok, data, listSign, rid, fbTok, item, expSize)
    if dlRes["ok"]
        stats["files"] += 1
    else
        stats["failed"] += 1
    done := idx + 1
    nm := item.Has("name") ? String(item["name"]) : CloudPlayer_RemoteBaseName(childRemote)
    CloudPlayer_PostDownloadProgress("打包下载：已处理 " . done . "/" . total . "（成功 " . stats["files"] . "，失败 " . stats["failed"] . "）...", rid, "downloading", CloudPlayer_DownloadPhasePercent("downloading", done, total))
    try CoreAsyncHttp_Log("cloudplayer_dl_job_file", "req_id=" . rid . " n=" . done . "/" . total . " remote=" . childRemote . " name=" . nm)
    job["fileIndex"] := done
    job["resolveCache"] := cache
    job["nextAt"] := A_TickCount + 80
    if (done >= total)
        job["phase"] := "zip"
    return true
}

CloudPlayer_DownloadResolve_OnDone(reqId, jobUid, idx, remotePath, ret) {
    global g_CloudPlayerDlJob
    try {
        if !(g_CloudPlayerDlJob is Map)
            return
        rid := g_CloudPlayerDlJob.Has("reqId") ? Trim(String(g_CloudPlayerDlJob["reqId"])) : ""
        uid := g_CloudPlayerDlJob.Has("jobUid") ? String(g_CloudPlayerDlJob["jobUid"]) : ""
        if (rid != Trim(String(reqId)) || uid != String(jobUid))
            return
        pending := g_CloudPlayerDlJob.Has("resolvePending") ? g_CloudPlayerDlJob["resolvePending"] : Map()
        cache := g_CloudPlayerDlJob.Has("resolveCache") ? g_CloudPlayerDlJob["resolveCache"] : Map()
        if (pending.Has(idx))
            pending.Delete(idx)
        inflight := g_CloudPlayerDlJob.Has("resolveInFlight") ? Integer(g_CloudPlayerDlJob["resolveInFlight"]) : 0
        if (inflight > 0)
            g_CloudPlayerDlJob["resolveInFlight"] := inflight - 1
        g_CloudPlayerDlJob["resolvePending"] := pending
        data := (ret is Map && ret.Has("data")) ? ret["data"] : 0
        if !(data is Map)
            data := Map()
        cache[idx] := data
        g_CloudPlayerDlJob["resolveCache"] := cache
        g_CloudPlayerDlJob["nextAt"] := 0
    } catch {
    }
}

CloudPlayer_DownloadJobPhaseZip(job) {
    rid := job.Has("reqId") ? Trim(String(job["reqId"])) : ""
    walkOk := job.Has("walkOk") ? !!job["walkOk"] : true
    zipCtx := job.Has("zipCtx") ? job["zipCtx"] : Map()
    dlMode := job.Has("downloadMode") ? String(job["downloadMode"]) : "zip"
    if (dlMode = "batch") {
        name := job.Has("folderName") ? String(job["folderName"]) : "cloud-folder"
        stats := job.Has("stats") ? job["stats"] : Map("files", 0, "failed", 0, "scanned", 0)
        stageRoot := zipCtx.Has("stageRoot") ? String(zipCtx["stageRoot"]) : ""
        if !walkOk {
            CloudPlayer_PostDownloadResult(false, "批量下载失败：扫描或下载中断", "", name, rid, "walk_failed")
            CloudPlayer_ClearDownloadCancelled(rid)
            return false
        }
        if (stats["files"] <= 0) {
            failN := stats.Has("failed") ? Integer(stats["failed"]) : 0
            scanned := stats.Has("scanned") ? Integer(stats["scanned"]) : 0
            msgEmpty := (failN > 0)
                ? ("批量下载失败：没有文件下载成功（" . failN . " 个失败）")
                : (scanned > 0 ? ("未找到可下载文件（已扫描 " . scanned . " 个目录）") : "文件夹为空或列表读取失败")
            CloudPlayer_PostDownloadResult(false, msgEmpty, "", name, rid, "empty_folder")
            CloudPlayer_ClearDownloadCancelled(rid)
            return false
        }
        if (stageRoot != "")
            try Run('explorer.exe "' . stageRoot . '"')
        msg := "批量下载完成：成功 " . stats["files"] . "，失败 " . stats["failed"]
        CloudPlayer_PostDownloadResult(true, msg, stageRoot, name, rid, "")
        CloudPlayer_ClearDownloadCancelled(rid)
        return false
    }
    try {
        CloudPlayer_DownloadFolderZipAfterWalk(walkOk, rid, zipCtx)
    } catch as e {
        name := job.Has("folderName") ? String(job["folderName"]) : ""
        CloudPlayer_PostDownloadResult(false, e.Message, "", name, rid, "exception")
        CloudPlayer_ClearDownloadCancelled(rid)
    }
    return false
}

CloudPlayer_DeferredDownloadFolder(reqId, folderPath, folderName, token, manifestFiles := 0, userToken := "", adminToken := "", downloadMode := "zip") {
    CloudPlayer_LogAsyncSenderHealth("download_start")
    if CloudPlayer_IsStaleReq("download_folder", reqId) {
        try CoreAsyncHttp_Log("cloudplayer_drop_stale_req", "kind=download_folder req_id=" . reqId . " phase=deferred")
        return
    }
    global g_CloudPlayerDlThreadRunning, g_CloudPlayerDlJob
    if g_CloudPlayerDlThreadRunning || (g_CloudPlayerDlJob is Map) {
        CloudPlayer_QueuePayload(Map(
            "type", "cloudplayer_download_result",
            "ok", false,
            "message", "已有打包下载任务进行中，请稍候",
            "path", "",
            "name", String(folderName)
        ), reqId, "busy", "download_busy")
        return
    }
    g_CloudPlayerDlThreadRunning := true
    g_CloudPlayerDlJob := Map(
        "phase", "init",
        "reqId", reqId,
        "jobUid", A_TickCount . "_" . Format("{:06}", Random(1, 999999)),
        "folderPath", folderPath,
        "folderName", folderName,
        "token", token,
        "userToken", userToken,
        "adminToken", adminToken,
        "downloadMode", downloadMode,
        "manifestFiles", manifestFiles,
        "fileQueue", [],
        "fileIndex", 0,
        "fileTotal", 0,
        "nextAt", 0,
        "walkOk", true,
        "dlStep", "pick",
        "scanQueue", [],
        "scanDirs", 0,
        "scanPending", false,
        "scanPendingSince", 0,
        "scanReady", false,
        "scanItems", [],
        "scanErr", "",
        "scanCurrent", Map(),
        "scanCurrentSince", 0,
        "resolveMax", 4,
        "resolveInFlight", 0,
        "resolveNext", 0,
        "resolvePending", Map(),
        "resolveCache", Map()
    )
    SetTimer(CloudPlayer_DownloadJobTick, 40)
}

CloudPlayer_CheckDownloadStale(reqId, phase := "") {
    rid := Trim(String(reqId))
    if (rid = "")
        return false
    if !CloudPlayer_IsStaleReq("download_folder", rid)
        return false
    extra := (phase != "") ? (" phase=" . phase) : ""
    try CoreAsyncHttp_Log("cloudplayer_drop_stale_req", "kind=download_folder req_id=" . rid . extra)
    return true
}

CloudPlayer_CheckDownloadCancelled(reqId, phase := "") {
    rid := Trim(String(reqId))
    if (rid = "")
        return false
    if !CloudPlayer_IsDownloadCancelled(rid)
        return false
    extra := (phase != "") ? (" phase=" . phase) : ""
    try CoreAsyncHttp_Log("cloudplayer_download_cancelled", "req_id=" . rid . extra)
    return true
}

CloudPlayer_PostDownloadResult(ok, message, path := "", name := "", reqId := "", errorCode := "") {
    rid := Trim(String(reqId))
    if CloudPlayer_CheckDownloadStale(rid, "result")
        return
    phase := ok ? "done" : (errorCode = "cancelled" ? "cancelled" : "error")
    CloudPlayer_QueuePayload(Map(
        "type", "cloudplayer_download_result",
        "ok", !!ok,
        "message", String(message),
        "path", String(path),
        "name", String(name)
    ), rid, phase, String(errorCode))
}

CloudPlayer_PostDownloadProgress(message, reqId := "", phase := "running", percent := 0) {
    msg := Trim(String(message))
    if (msg = "")
        return
    rid := Trim(String(reqId))
    if CloudPlayer_CheckDownloadStale(rid, "progress")
        return
    CloudPlayer_QueuePayload(Map(
        "type", "cloudplayer_download_progress",
        "message", msg,
        "percent", Integer(percent)
    ), rid, String(phase), "")
}

CloudPlayer_DownloadPhasePercent(phase, processed := 0, total := 0) {
    ph := StrLower(Trim(String(phase)))
    n := 0
    t := 0
    try n := Integer(processed)
    try t := Integer(total)
    if (n < 0)
        n := 0
    if (t < 0)
        t := 0
    if (ph = "preparing")
        return 2
    if (ph = "scanning")
        return (n > 0) ? Min(24, 10 + n) : 10
    if (ph = "downloading") {
        if (t > 0)
            return Min(70, 10 + Floor((n / t) * 60))
        return Min(70, 10 + Floor(n * 0.9))
    }
    if (ph = "zipping")
        return 82
    if (ph = "finalizing")
        return 98
    if (ph = "done")
        return 100
    return 0
}

CloudPlayer_PostArchiveProgress(reqId, message, percent := 0) {
    global g_CloudPlayerWv2
    rid := Trim(String(reqId))
    if (rid = "")
        return
    if CloudPlayer_IsStaleReq("archive_list", rid) {
        try CoreAsyncHttp_Log("cloudplayer_drop_stale_req", "kind=archive_list req_id=" . rid . " phase=progress")
        return
    }
    msg := Trim(String(message))
    try WebView_QueuePayload(g_CloudPlayerWv2, Map(
        "type", "cloudplayer_archive_progress",
        "reqId", rid,
        "message", msg,
        "percent", Integer(percent)
    ))
}

CloudPlayer_DownloadFolderZip(folderPath, folderName := "", token := "", reqId := "", manifestFiles := 0) {
    global g_CloudPlayerApiBase, g_CloudPlayerDlLastListErr
    rid := Trim(String(reqId))
    g_CloudPlayerDlLastListErr := ""
    if CloudPlayer_CheckDownloadStale(rid, "start")
        return
    if CloudPlayer_CheckDownloadCancelled(rid, "start") {
        CloudPlayer_PostDownloadResult(false, "cancelled", "", "", rid, "cancelled")
        return
    }
    p := CloudPlayer_NormalizeRemotePath(folderPath)
    name := CloudPlayer_SafeFileName(folderName != "" ? folderName : CloudPlayer_RemoteBaseName(p))
    if (name = "")
        name := "cloud-folder"

    try {
        CloudPlayer_PostDownloadProgress("打包下载：准备中...", rid, "preparing", CloudPlayer_DownloadPhasePercent("preparing"))
        if CloudPlayer_CheckDownloadStale(rid, "pre_token")
            return
        if CloudPlayer_CheckDownloadCancelled(rid, "pre_token") {
            CloudPlayer_PostDownloadResult(false, "cancelled", "", name, rid, "cancelled")
            return
        }
        errTok := ""
        token := CloudPlayer_ResolveDownloadAuthToken(token, &errTok)
        if (Trim(String(token)) = "") {
            CloudPlayer_PostDownloadResult(false, "无法获取 OpenList 管理员 Token" . (errTok != "" ? ("：" . errTok) : ""), "", name, rid, "no_token")
            CloudPlayer_ClearDownloadCancelled(rid)
            return
        }
        try CoreAsyncHttp_Log("cloudplayer_dl_token", "req_id=" . rid . " src=admin len=" . StrLen(token))
        headers := Map("Content-Type", "application/json", "Accept", "application/json")
        headers["Authorization"] := Trim(String(token))

        outDir := CloudPlayer_DownloadsDir() . "\牛马云下载"
        DirCreate(outDir)
        stamp := FormatTime(, "yyyyMMdd_HHmmss")
        zipPath := outDir . "\" . name . "_" . stamp . ".zip"
        workRoot := A_Temp . "\Nc_" . A_TickCount
        stageRoot := workRoot . "\" . name
        DirCreate(stageRoot)

        stats := Map("files", 0, "failed", 0, "scanned", 0)
        zipCtx := Map("name", name, "workRoot", workRoot, "stageRoot", stageRoot, "zipPath", zipPath, "stats", stats)
        ; Host-side recursive scan (paginated fs/list) is the reliable path for folder zips.
        walkOk := CloudPlayer_DownloadFolderTreeSync(p, stageRoot, headers, token, stats, rid)
        if (walkOk && stats["files"] = 0 && stats["failed"] = 0 && (manifestFiles is Array) && manifestFiles.Length > 0) {
            try CoreAsyncHttp_Log("cloudplayer_dl_manifest_fallback", "req_id=" . rid . " count=" . manifestFiles.Length)
            walkOk := CloudPlayer_DownloadManifestFiles(manifestFiles, stageRoot, headers, token, stats, rid)
        }
        CloudPlayer_DownloadFolderZipAfterWalk(walkOk, rid, zipCtx)
    } catch as e {
        CloudPlayer_PostDownloadResult(false, e.Message, "", name, rid, "exception")
        CloudPlayer_ClearDownloadCancelled(rid)
    }
}

CloudPlayer_DownloadFolderZipAfterWalk(walkOk, rid, zipCtx) {
    global g_CloudPlayerDlLastListErr
    name := zipCtx.Has("name") ? String(zipCtx["name"]) : "cloud-folder"
    workRoot := zipCtx.Has("workRoot") ? String(zipCtx["workRoot"]) : ""
    zipPath := zipCtx.Has("zipPath") ? String(zipCtx["zipPath"]) : ""
    stats := zipCtx.Has("stats") ? zipCtx["stats"] : Map("files", 0, "failed", 0)
    try {
        if !walkOk {
            try DirDelete(workRoot, true)
            walkMsg := "download walk failed or cancelled"
            if (Trim(String(g_CloudPlayerDlLastListErr)) != "")
                walkMsg := "scan failed: " . String(g_CloudPlayerDlLastListErr)
            CloudPlayer_PostDownloadResult(false, walkMsg, "", name, rid, "walk_failed")
            return
        }
        if CloudPlayer_CheckDownloadStale(rid, "post_scan") {
            try DirDelete(workRoot, true)
            return
        }
        if CloudPlayer_CheckDownloadCancelled(rid, "post_scan") {
            try DirDelete(workRoot, true)
            CloudPlayer_PostDownloadResult(false, "cancelled", "", name, rid, "cancelled")
            return
        }
        if (stats["files"] <= 0) {
            try DirDelete(workRoot, true)
            failN := stats.Has("failed") ? Integer(stats["failed"]) : 0
            scanned := stats.Has("scanned") ? Integer(stats["scanned"]) : 0
            msgEmpty := (failN > 0)
                ? ("没有文件下载成功（" . failN . " 个失败，请完全退出并重启牛马助手后重试）")
                : (scanned > 0)
                    ? ("未找到可下载文件（已扫描 " . scanned . " 个目录，请确认文件夹内有图片/文件）")
                    : "文件夹为空或列表读取失败，请完全退出并重启牛马助手后重试"
            try CoreAsyncHttp_Log("cloudplayer_dl_zip_empty", "req_id=" . rid . " fail=" . failN . " scanned=" . scanned)
            CloudPlayer_PostDownloadResult(false, msgEmpty, "", name, rid, "empty_folder")
            return
        }

        stageRoot := zipCtx.Has("stageRoot") ? String(zipCtx["stageRoot"]) : (workRoot . "\" . name)
        CloudPlayer_PostDownloadProgress("打包下载：正在压缩，文件数 " . stats["files"] . "...", rid, "zipping", CloudPlayer_DownloadPhasePercent("zipping"))
        zipRes := CloudPlayer_ZipStageToFile(stageRoot, zipPath, 180000)
        if CloudPlayer_CheckDownloadCancelled(rid, "post_zip") {
            try DirDelete(workRoot, true)
            CloudPlayer_PostDownloadResult(false, "cancelled", "", name, rid, "cancelled")
            return
        }
        if !zipRes["ok"] {
            try DirDelete(workRoot, true)
            zipTimedOut := zipRes.Has("timedOut") ? !!zipRes["timedOut"] : false
            zipExitCode := zipRes.Has("exitCode") ? Integer(zipRes["exitCode"]) : -1
            zipErr := zipRes.Has("stderr") ? Trim(String(zipRes["stderr"])) : ""
            if (zipErr = "" && zipRes.Has("error"))
                zipErr := Trim(String(zipRes["error"]))
            msgZip := zipTimedOut ? "zip timeout" : ("zip failed, exit code " . zipExitCode . (zipErr != "" ? (" (" . SubStr(zipErr, 1, 120) . ")") : ""))
            errCode := zipTimedOut ? "zip_timeout" : "zip_failed"
            if InStr(StrLower(zipErr), "missing lib\\7z.exe")
                errCode := "missing_7z"
            CloudPlayer_PostDownloadResult(false, msgZip, "", name, rid, errCode)
            return
        }
        try DirDelete(workRoot, true)
        try Run('explorer.exe /select,"' . zipPath . '"')
        msg := "ok, files: " . stats["files"]
        if (stats["failed"] > 0)
            msg .= ", failed: " . stats["failed"]
        CloudPlayer_PostDownloadProgress("打包下载：已完成，准备打开目录...", rid, "finalizing", CloudPlayer_DownloadPhasePercent("finalizing"))
        CloudPlayer_PostDownloadResult(true, msg, zipPath, name, rid, "")
    } catch as e {
        CloudPlayer_PostDownloadResult(false, e.Message, "", name, rid, "exception")
    } finally {
        CloudPlayer_ClearDownloadCancelled(rid)
    }
}

CloudPlayer_ListFolderItemsSync(remotePath, headers, reqId := "") {
    global g_CloudPlayerApiBase, g_CloudPlayerDlLastListErr
    g_CloudPlayerDlLastListErr := ""
    out := []
    page := 1
    perPage := 500
    loop 64 {
        rid := Trim(String(reqId))
        if (rid != "" && CloudPlayer_IsDownloadCancelled(rid))
            break
        batch := []
        fetchOk := false
        ; Some OpenList/provider combos can return empty on first refresh=true probe.
        ; Retry once with refresh=false before deciding it's empty.
        for _, refreshFlag in [page = 1 ? true : false, false] {
            body := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(Map(
                "path", CloudPlayer_NormalizeRemotePath(remotePath),
                "password", "",
                "page", page,
                "per_page", perPage,
                "refresh", refreshFlag
            )), ["refresh"])
            ret := CloudPlayer_HttpJsonAwait("POST", g_CloudPlayerApiBase . "/api/fs/list", headers, body, rid)
            if !ret["ok"] {
                g_CloudPlayerDlLastListErr := ret.Has("error") ? String(ret["error"]) : "fs/list transport error"
                try CoreAsyncHttp_Log("cloudplayer_dl_scan_page", "req_id=" . rid . " path=" . remotePath . " page=" . page . " refresh=" . (refreshFlag ? 1 : 0) . " ok=0 err=" . g_CloudPlayerDlLastListErr)
                continue
            }
            code := 0
            try code := Integer(ret["json"]["code"])
            catch {
                code := 0
            }
            if (code != 200) {
                msg := ""
                try msg := String(ret["json"]["message"])
                catch {
                    msg := ""
                }
                g_CloudPlayerDlLastListErr := (msg != "") ? msg : ("fs/list code " . code)
                try CoreAsyncHttp_Log("cloudplayer_dl_scan_page", "req_id=" . rid . " path=" . remotePath . " page=" . page . " refresh=" . (refreshFlag ? 1 : 0) . " ok=1 code=" . code . " msg=" . g_CloudPlayerDlLastListErr)
                continue
            }
            fetchOk := true
            dataObj := 0
            try dataObj := ret["json"]["data"]
            catch {
                dataObj := 0
            }
            try {
                keys := ""
                if (dataObj is Map) {
                    for k, _ in dataObj {
                        ks := String(k)
                        keys .= (keys = "" ? ks : ("," . ks))
                        if (StrLen(keys) > 120) {
                            keys .= "..."
                            break
                        }
                    }
                } else if (dataObj is Array) {
                    keys := "[array]"
                } else {
                    keys := Type(dataObj)
                }
                CoreAsyncHttp_Log("cloudplayer_dl_scan_data", "req_id=" . rid . " path=" . remotePath . " page=" . page . " refresh=" . (refreshFlag ? 1 : 0) . " data_keys=" . keys)
            }
            batch := CloudPlayer_ParseFsListRows(dataObj)
            try CoreAsyncHttp_Log("cloudplayer_dl_scan_page", "req_id=" . rid . " path=" . remotePath . " page=" . page . " refresh=" . (refreshFlag ? 1 : 0) . " ok=1 code=200 rows=" . batch.Length)
            if (batch.Length > 0 || !refreshFlag)
                break
            Sleep(120)
        }
        if !fetchOk && g_CloudPlayerDlLastListErr != ""
            break
        if batch.Length = 0
            break
        for _, row in batch
            out.Push(row)
        if (batch.Length < perPage)
            break
        page += 1
        Sleep(0)
    }
    return out
}

CloudPlayer_DownloadScan_OnListed(reqId, jobUid, remotePath, ret) {
    global g_CloudPlayerDlJob
    try {
        if !(g_CloudPlayerDlJob is Map)
            return
        rid := g_CloudPlayerDlJob.Has("reqId") ? Trim(String(g_CloudPlayerDlJob["reqId"])) : ""
        uid := g_CloudPlayerDlJob.Has("jobUid") ? String(g_CloudPlayerDlJob["jobUid"]) : ""
        if (rid != Trim(String(reqId)) || uid != String(jobUid))
            return
        g_CloudPlayerDlJob["scanPending"] := false
        g_CloudPlayerDlJob["scanPendingSince"] := 0
        g_CloudPlayerDlJob["scanReady"] := true
        g_CloudPlayerDlJob["scanPath"] := String(remotePath)
        g_CloudPlayerDlJob["scanItems"] := (ret is Map && ret.Has("items") && ret["items"] is Array) ? ret["items"] : []
        g_CloudPlayerDlJob["scanErr"] := (ret is Map && ret.Has("error")) ? String(ret["error"]) : ""
        g_CloudPlayerDlJob["nextAt"] := 0
    } catch {
    }
}

CloudPlayer_ListFolderItemsAsync(remotePath, headers, reqId := "", callback := 0) {
    global g_CloudPlayerApiBase
    cb := IsObject(callback) ? callback : 0
    state := Map(
        "remotePath", CloudPlayer_NormalizeRemotePath(remotePath),
        "headers", (headers is Map) ? headers : Map(),
        "reqId", Trim(String(reqId)),
        "callback", cb,
        "items", [],
        "page", 1,
        "perPage", 500,
        "loopLeft", 64,
        "phase", "refresh_true",
        "lastErr", ""
    )
    CloudPlayer_ListFolderItemsAsync_Next(state)
}

CloudPlayer_ListFolderItemsAsync_Next(state) {
    global g_CloudPlayerApiBase
    rid := state["reqId"]
    if (rid != "" && CloudPlayer_IsDownloadCancelled(rid)) {
        CloudPlayer_ListFolderItemsAsync_Finish(state, false, state["items"], "cancelled")
        return
    }
    if (Integer(state["loopLeft"]) <= 0) {
        CloudPlayer_ListFolderItemsAsync_Finish(state, true, state["items"], "")
        return
    }
    page := Integer(state["page"])
    refreshFlag := (String(state["phase"]) = "refresh_true") ? (page = 1) : false
    body := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(Map(
        "path", state["remotePath"],
        "password", "",
        "page", page,
        "per_page", state["perPage"],
        "refresh", refreshFlag
    )), ["refresh"])
    CloudPlayer_HttpJsonAsyncReq("POST", g_CloudPlayerApiBase . "/api/fs/list", state["headers"], body, (ret) => (
        CloudPlayer_ListFolderItemsAsync_OnPage(state, refreshFlag, ret)
    ), rid, "cp_dl_fs_list")
}

CloudPlayer_ListFolderItemsAsync_OnPage(state, refreshFlag, ret) {
    rid := state["reqId"]
    rp := state["remotePath"]
    page := Integer(state["page"])
    if !ret["ok"] {
        err := ret.Has("error") ? String(ret["error"]) : "fs/list transport error"
        state["lastErr"] := err
        try CoreAsyncHttp_Log("cloudplayer_dl_scan_page", "req_id=" . rid . " path=" . rp . " page=" . page . " refresh=" . (refreshFlag ? 1 : 0) . " ok=0 err=" . err)
        if refreshFlag {
            state["phase"] := "refresh_false"
            CloudPlayer_ListFolderItemsAsync_Next(state)
            return
        }
        CloudPlayer_ListFolderItemsAsync_Finish(state, false, state["items"], err)
        return
    }
    code := 0
    try code := Integer(ret["json"]["code"])
    catch {
        code := 0
    }
    if (code != 200) {
        msg := ""
        try msg := String(ret["json"]["message"])
        catch {
            msg := ""
        }
        err := (msg != "") ? msg : ("fs/list code " . code)
        state["lastErr"] := err
        try CoreAsyncHttp_Log("cloudplayer_dl_scan_page", "req_id=" . rid . " path=" . rp . " page=" . page . " refresh=" . (refreshFlag ? 1 : 0) . " ok=1 code=" . code . " msg=" . err)
        if refreshFlag {
            state["phase"] := "refresh_false"
            CloudPlayer_ListFolderItemsAsync_Next(state)
            return
        }
        CloudPlayer_ListFolderItemsAsync_Finish(state, false, state["items"], err)
        return
    }
    dataObj := 0
    try dataObj := ret["json"]["data"]
    catch {
        dataObj := 0
    }
    batch := CloudPlayer_ParseFsListRows(dataObj)
    try CoreAsyncHttp_Log("cloudplayer_dl_scan_page", "req_id=" . rid . " path=" . rp . " page=" . page . " refresh=" . (refreshFlag ? 1 : 0) . " ok=1 code=200 rows=" . batch.Length)
    if (batch.Length = 0 && refreshFlag) {
        state["phase"] := "refresh_false"
        SetTimer(() => CloudPlayer_ListFolderItemsAsync_Next(state), -120)
        return
    }
    for _, row in batch
        state["items"].Push(row)
    if (batch.Length < Integer(state["perPage"])) {
        CloudPlayer_ListFolderItemsAsync_Finish(state, true, state["items"], "")
        return
    }
    state["page"] := page + 1
    state["loopLeft"] := Integer(state["loopLeft"]) - 1
    state["phase"] := "refresh_true"
    SetTimer(() => CloudPlayer_ListFolderItemsAsync_Next(state), -1)
}

CloudPlayer_ListFolderItemsAsync_Finish(state, ok, items, err := "") {
    cb := state["callback"]
    out := Map("ok", !!ok, "items", items, "error", String(err))
    try {
        if cb
            cb.Call(out)
    } catch {
    }
}

CloudPlayer_ParseFsListRows(dataObj) {
    out := []
    if (dataObj is Array) {
        for _, row in dataObj
            out.Push(row)
        return out
    }
    if !(dataObj is Map)
        return out
    for _, key in ["content", "files", "items", "children", "list"] {
        try v := dataObj.Has(key) ? dataObj[key] : 0
        catch {
            v := 0
        }
        if (v is Array) {
            for _, row in v
                out.Push(row)
            if (out.Length > 0)
                return out
        } else if (v is Map) {
            for _, row in v
                out.Push(row)
            if (out.Length > 0)
                return out
        }
    }
    return out
}

CloudPlayer_FetchFsGetDataSync(remotePath, headers, reqId := "") {
    global g_CloudPlayerApiBase
    rp := CloudPlayer_NormalizeRemotePath(remotePath)
    body := Jxon_Dump(Map("path", rp, "password", ""))
    loop 2 {
        ret := CloudPlayer_HttpJsonAwait("POST", g_CloudPlayerApiBase . "/api/fs/get", headers, body, reqId)
        if ret["ok"] {
            try {
                if (ret["json"] is Map && ret["json"].Has("data"))
                    return ret["json"]["data"]
            } catch {
            }
        }
        if (A_Index = 2)
            break
        Sleep(80)
    }
    return 0
}

CloudPlayer_DownloadManifestFiles(files, stageRoot, headers, token, stats, reqId) {
    rid := Trim(String(reqId))
    if !(files is Array) || files.Length = 0
        return true
    stats["scanned"] := 1
    for _, rawItem in files {
        if CloudPlayer_CheckDownloadStale(rid, "walk_item") || CloudPlayer_CheckDownloadCancelled(rid, "walk_item")
            return false
        item := CloudPlayer_WalkItemAsMap(rawItem)
        childRemote := ""
        try childRemote := Trim(String(item.Has("path") ? item["path"] : ""))
        catch {
            childRemote := ""
        }
        if (childRemote = "")
            continue
        rel := ""
        try rel := Trim(String(item.Has("rel") ? item["rel"] : ""))
        catch {
            rel := ""
        }
        if (rel = "")
            rel := CloudPlayer_RemoteBaseName(childRemote)
        rel := StrReplace(rel, "/", "\")
        childLocal := stageRoot . "\" . rel
        try {
            d := RegExReplace(CloudPlayer_ToWinLongPath(childLocal), "\\[^\\]*$")
            if (d != "")
                DirCreate(d)
        } catch {
        }
        listSign := ""
        try listSign := Trim(String(item.Has("sign") ? item["sign"] : ""))
        catch {
            listSign := ""
        }
        data := CloudPlayer_FetchFsGetDataSync(childRemote, headers, rid)
        dlRes := CloudPlayer_DownloadWalkSaveFile(childLocal, childRemote, token, data, listSign, rid)
        if dlRes["ok"]
            stats["files"] += 1
        else
            stats["failed"] += 1
        total := stats["files"] + stats["failed"]
        if (Mod(total, 2) = 0 || total = files.Length)
            CloudPlayer_PostDownloadProgress("打包下载：已处理 " . total . "/" . files.Length . "（成功 " . stats["files"] . "，失败 " . stats["failed"] . "）...", rid, "downloading", CloudPlayer_DownloadPhasePercent("downloading", total))
        Sleep(500)
    }
    return true
}

CloudPlayer_DownloadFolderTreeSync(remotePath, localDir, headers, token, stats, reqId) {
    global g_CloudPlayerDlLastListErr
    rid := Trim(String(reqId))
    q := [Map("remote", remotePath, "local", localDir, "depth", 0)]
    scannedDirs := 0
    while (q is Array) && q.Length > 0 {
        if CloudPlayer_CheckDownloadStale(rid, "walk") || CloudPlayer_CheckDownloadCancelled(rid, "walk")
            return false
        job := q.RemoveAt(1)
        if !(job is Map)
            continue
        depth := Integer(job.Has("depth") ? job["depth"] : 0)
        if (depth > 24)
            continue
        rp := job.Has("remote") ? String(job["remote"]) : ""
        loc := job.Has("local") ? String(job["local"]) : ""
        try DirCreate(CloudPlayer_ToWinLongPath(loc))
        scannedDirs += 1
        stats["scanned"] := scannedDirs
        scanPct := Min(24, 10 + scannedDirs)
        CloudPlayer_PostDownloadProgress("打包下载：扫描 " . rp . " ...", rid, "scanning", scanPct)
        items := CloudPlayer_ListFolderItemsSync(rp, headers, rid)
        if (g_CloudPlayerDlLastListErr != "")
            return false
        CloudPlayer_PostDownloadProgress("打包下载：扫描 " . rp . "（" . items.Length . " 项）...", rid, "scanning", scanPct)
        for _, rawItem in items {
            if CloudPlayer_CheckDownloadStale(rid, "walk_item") || CloudPlayer_CheckDownloadCancelled(rid, "walk_item")
                return false
            item := CloudPlayer_WalkItemAsMap(rawItem)
            try name := String(item.Has("name") ? item["name"] : "")
            catch {
                name := ""
            }
            if (name = "")
                continue
            childRemote := CloudPlayer_WalkItemRemotePath(item, rp, name)
            safeName := CloudPlayer_SafeFileName(name)
            if (safeName = "")
                safeName := "item"
            childLocal := loc . "\" . safeName
            if CloudPlayer_WalkItemIsDir(item, name) {
                try DirCreate(CloudPlayer_ToWinLongPath(childLocal))
                q.InsertAt(1, Map("remote", childRemote, "local", childLocal, "depth", depth + 1))
                continue
            }
            data := CloudPlayer_FetchFsGetDataSync(childRemote, headers, rid)
            dlRes := CloudPlayer_DownloadWalkSaveFile(childLocal, childRemote, token, data, CloudPlayer_WalkItemSign(item), rid)
            if dlRes["ok"]
                stats["files"] += 1
            else
                stats["failed"] += 1
            total := stats["files"] + stats["failed"]
            if (Mod(total, 2) = 0)
                CloudPlayer_PostDownloadProgress("打包下载：已处理 " . total . " 个文件（成功 " . stats["files"] . "，失败 " . stats["failed"] . "）...", rid, "downloading", CloudPlayer_DownloadPhasePercent("downloading", total))
            Sleep(500)
        }
    }
    return true
}

CloudPlayer_WalkItemAsMap(item) {
    if (item is Map)
        return item
    if (item is Array) {
        m := Map()
        ; Compatibility: some OpenList/provider responses may return tuple-like rows.
        ; Try common positions: [name, path, is_dir, size]
        try {
            if (item.Length >= 1)
                m["name"] := item[1]
            if (item.Length >= 2)
                m["path"] := item[2]
            if (item.Length >= 3)
                m["is_dir"] := item[3]
            if (item.Length >= 4)
                m["size"] := item[4]
        }
        return m
    }
    return Map()
}

CloudPlayer_FetchFsGetDataAsync(remotePath, headers, reqId := "", callback := 0) {
    global g_CloudPlayerApiBase
    cb := IsObject(callback) ? callback : 0
    state := Map(
        "remotePath", CloudPlayer_NormalizeRemotePath(remotePath),
        "headers", (headers is Map) ? headers : Map(),
        "reqId", Trim(String(reqId)),
        "callback", cb,
        "tryLeft", 2
    )
    CloudPlayer_FetchFsGetDataAsync_Next(state)
}

CloudPlayer_FetchFsGetDataAsync_Next(state) {
    global g_CloudPlayerApiBase
    body := Jxon_Dump(Map("path", state["remotePath"], "password", ""))
    CloudPlayer_HttpJsonAsyncReq("POST", g_CloudPlayerApiBase . "/api/fs/get", state["headers"], body, (ret) => (
        CloudPlayer_FetchFsGetDataAsync_OnRet(state, ret)
    ), state["reqId"], "cp_dl_fs_get")
}

CloudPlayer_FetchFsGetDataAsync_OnRet(state, ret) {
    tries := Integer(state["tryLeft"])
    if ret["ok"] {
        code := 0
        try code := Integer(ret["json"]["code"])
        catch {
            code := 0
        }
        if (code = 200) {
            data := 0
            try data := ret["json"]["data"]
            catch {
                data := 0
            }
            cb := state["callback"]
            if cb
                cb.Call(Map("ok", true, "data", data, "error", ""))
            return
        }
    }
    tries -= 1
    state["tryLeft"] := tries
    if (tries > 0) {
        SetTimer(() => CloudPlayer_FetchFsGetDataAsync_Next(state), -120)
        return
    }
    err := ret.Has("error") ? String(ret["error"]) : "fs/get failed"
    cb := state["callback"]
    if cb
        cb.Call(Map("ok", false, "data", Map(), "error", err))
}

CloudPlayer_WalkItemRemotePath(item, parentRemote, name) {
    item := CloudPlayer_WalkItemAsMap(item)
    if (item is Map && item.Has("path")) {
        try p := Trim(String(item["path"]))
        catch {
            p := ""
        }
        if (p != "")
            return CloudPlayer_NormalizeRemotePath(p)
    }
    return CloudPlayer_CombineRemotePath(parentRemote, name)
}

CloudPlayer_WalkItemIsDir(item, name := "") {
    nm := Trim(String(name))
    if (nm = "" && item is Map) {
        try nm := Trim(String(item.Has("name") ? item["name"] : ""))
        catch {
            nm := ""
        }
    }
    if (nm != "" && RegExMatch(nm, "i)\.(jpg|jpeg|png|gif|webp|bmp|svg|ico|mp4|mov|mkv|avi|wmv|flv|mp3|wav|flac|aac|zip|rar|7z|tar|gz|pdf|doc|docx|xls|xlsx|ppt|pptx|txt|md|json|xml|csv)$"))
        return false
    if !(item is Map)
        return false
    try {
        if item.Has("size") {
            sz := item["size"]
            if (Type(sz) = "Integer" || Type(sz) = "Float") {
                if (Number(sz) > 0)
                    return false
            } else {
                ssz := Trim(String(sz))
                if (ssz != "" && ssz != "0")
                    return false
            }
        }
    } catch {
    }
    try {
        if item.Has("is_dir") {
            v := item["is_dir"]
            if (v is Integer || v is Float)
                return (Integer(v) != 0)
            if (v is String) {
                s := StrLower(Trim(v))
                if (s = "true" || s = "1")
                    return true
                if (s = "false" || s = "0" || s = "")
                    return false
            }
            return !!v
        }
    } catch {
    }
    try {
        if item.Has("type") {
            tp := StrLower(Trim(String(item["type"])))
            if (tp = "dir" || tp = "folder" || tp = "directory")
                return true
            if (tp = "file" || tp = "f")
                return false
        }
    } catch {
    }
    try {
        p := Trim(String(item.Has("path") ? item["path"] : ""))
        if (p != "" && SubStr(p, -1) = "/")
            return true
    } catch {
    }
    return false
}

CloudPlayer_AppendFsListContent(&listItems, content) {
    if !(listItems is Array)
        listItems := []
    if (content is Array) {
        for _, row in content
            listItems.Push(row)
    } else if (content is Map) {
        for _, row in content
            listItems.Push(row)
    }
    return listItems
}

CloudPlayer_WalkItemSign(item) {
    item := CloudPlayer_WalkItemAsMap(item)
    if !(item is Map)
        return ""
    try s := Trim(String(item.Has("sign") ? item["sign"] : ""))
    catch {
        s := ""
    }
    return s
}

CloudPlayer_SanitizeLocalRelPath(rel) {
    rel := StrReplace(Trim(String(rel)), "/", "\")
    if (rel = "")
        return rel
    parts := StrSplit(rel, "\")
    out := ""
    for i, part in parts {
        if (part = "")
            continue
        safe := CloudPlayer_SafeFileName(StrReplace(part, ":", "_"))
        if (safe = "")
            safe := "item"
        out .= (out = "") ? safe : ("\" . safe)
    }
    return out
}

CloudPlayer_ToWinLongPath(path) {
    p := Trim(String(path))
    if (p = "")
        return p
    if (SubStr(p, 1, 4) = "\\?\")
        return p
    if (SubStr(p, 1, 2) = "\\")
        return "\\?\UNC\" . SubStr(p, 3)
    return "\\?\" . p
}

CloudPlayer_StripWinLongPath(path) {
    p := Trim(String(path))
    if (SubStr(p, 1, 8) = "\\?\UNC\")
        return "\\" . SubStr(p, 9)
    if (SubStr(p, 1, 4) = "\\?\")
        return SubStr(p, 5)
    return p
}

CloudPlayer_WriteHttpBodyToFile(whr, outPath, expectedSize := 0) {
    longPath := CloudPlayer_ToWinLongPath(outPath)
    checkPath := CloudPlayer_StripWinLongPath(longPath)
    dir := RegExReplace(longPath, "\\[^\\]*$")
    if (dir != "")
        DirCreate(dir)
    try {
        ct := ""
        try ct := String(whr.GetResponseHeader("Content-Type"))
        catch {
            ct := ""
        }
        if (ct != "" && RegExMatch(ct, "i)text/html|application/json|text/plain"))
            return false
    } catch {
    }
    saved := false
    try {
        ado := ComObject("ADODB.Stream")
        ado.Type := 1
        ado.Open()
        ado.Write(whr.ResponseBody)
        try FileDelete(checkPath)
        catch {
        }
        ado.SaveToFile(longPath, 2)
        ado.Close()
        saved := true
    } catch {
        saved := false
    }
    if !saved {
        ext := ""
        if RegExMatch(checkPath, "\.[^.\\]+$", &mExt)
            ext := mExt[0]
        tempPath := A_Temp . "\nd" . A_TickCount . "_" . Random(100000, 999999) . ext
        try FileDelete(tempPath)
        catch {
        }
        try {
            body := whr.ResponseBody
            if body {
                f := FileOpen(tempPath, "w-d")
                f.RawWrite(body)
                f.Close()
                saved := FileExist(tempPath)
            }
        } catch {
            saved := false
        }
        if saved {
            try FileDelete(checkPath)
            catch {
            }
            if !FileMove(tempPath, longPath, 1)
                saved := FileMove(tempPath, checkPath, 1)
        }
    }
    if !saved || !FileExist(checkPath)
        return false
    gotSize := 0
    try gotSize := FileGetSize(checkPath)
    catch {
        gotSize := 0
    }
    if (gotSize <= 0)
        return false
    exp := 0
    try exp := Integer(expectedSize)
    catch {
        exp := 0
    }
    if (exp > 1024 && gotSize < Floor(exp * 0.2))
        return false
    return true
}

CloudPlayer_NormalizeHttpHeaders(hdr) {
    out := Map()
    if !(hdr is Map)
        return out
    for k, v in hdr {
        if (IsObject(v) && !(v is Map))
            continue
        try out[String(k)] := String(v)
        catch {
        }
    }
    return out
}

CloudPlayer_StripAuthFromHeaders(hdr) {
    out := CloudPlayer_NormalizeHttpHeaders(hdr)
    for k, _ in out.Clone() {
        if (StrLower(Trim(String(k))) = "authorization")
            out.Delete(k)
    }
    return out
}

CloudPlayer_IsLocalOpenListProxyUrl(url) {
    return RegExMatch(Trim(String(url)), "i)^https?://(?:127\.0\.0\.1|localhost)(?::\d+)?/(?:d|p)(?:/|\?|$)")
}

CloudPlayer_PushDownloadCandidate(&out, &seen, u, hdr) {
    u := Trim(String(u))
    if (u = "" || !RegExMatch(u, "i)^https?://") || RegExMatch(u, "i)/@manage(?:[/?#]|$)") || seen.Has(u))
        return
    seen[u] := true
    out.Push(Map("url", u, "headers", hdr))
}

CloudPlayer_IsExternalCdnUrl(url) {
    u := Trim(String(url))
    if (u = "")
        return false
    if CloudPlayer_IsLocalOpenListProxyUrl(u)
        return false
    return RegExMatch(u, "i)(aliyundrive\.cloud|aliyuncs\.com|alipan\.com|download\.aliyun|drive\.google|googleusercontent\.com)")
}

CloudPlayer_ShouldUseExternalDownloadUrl(url, proxyOnly := true) {
    u := Trim(String(url))
    if (u = "" || !RegExMatch(u, "i)^https?://"))
        return false
    if CloudPlayer_IsLocalOpenListProxyUrl(u)
        return true
    if !proxyOnly
        return true
    return !CloudPlayer_IsExternalCdnUrl(u)
}

CloudPlayer_AppendDownloadUrlFromData(&out, &seen, data, fullHdr, cdnHdr, proxyOnly) {
    if !(data is Map)
        return
    for _, key in ["url", "raw_url"] {
        try u := Trim(String(data.Has(key) ? data[key] : ""))
        catch {
            u := ""
        }
        if (u = "" || !CloudPlayer_ShouldUseExternalDownloadUrl(u, proxyOnly))
            continue
        hdr := CloudPlayer_IsLocalOpenListProxyUrl(u) ? fullHdr : cdnHdr
        CloudPlayer_PushDownloadCandidate(&out, &seen, u, hdr)
    }
    try {
        if (data.Has("content") && data["content"] is Map && data["content"].Has("url")) {
            u2 := Trim(String(data["content"]["url"]))
            if (u2 != "" && CloudPlayer_ShouldUseExternalDownloadUrl(u2, proxyOnly)) {
                hdr2 := CloudPlayer_IsLocalOpenListProxyUrl(u2) ? fullHdr : cdnHdr
                CloudPlayer_PushDownloadCandidate(&out, &seen, u2, hdr2)
            }
        }
    } catch {
    }
}

CloudPlayer_BuildDownloadCandidates(data, remotePath, listSign := "", proxyOnly := true, manifestItem := 0) {
    ; OpenList 官方流程（#1549）：先 /api/fs/get 拿 raw_url/sign，再用 /p/ 或 /d/?sign= 下载；
    ; 「签名全部」开启时直链只认 sign，不认 Authorization。
    out := []
    seen := Map()
    if (manifestItem is Map) && manifestItem.Has("downloadUrl") {
        try {
            u0 := Trim(String(manifestItem["downloadUrl"]))
            if (u0 != "" && RegExMatch(u0, "i)^https?://")) {
                hdr0 := Map()
                if manifestItem.Has("downloadHeaders")
                    hdr0 := CloudPlayer_NormalizeHttpHeaders(manifestItem["downloadHeaders"])
                CloudPlayer_PushDownloadCandidate(&out, &seen, u0, hdr0)
            }
        } catch {
        }
    }
    fullHdr := Map()
    if (data is Map && data.Has("header"))
        fullHdr := CloudPlayer_NormalizeHttpHeaders(data["header"])
    cdnHdr := CloudPlayer_StripAuthFromHeaders(fullHdr)
    sg := Trim(String(listSign))
    if (sg = "" && data is Map)
        sg := CloudPlayer_ParseFsGetSign(data)
    if (sg = "" && manifestItem is Map && manifestItem.Has("sign")) {
        try sg := Trim(String(manifestItem["sign"]))
        catch {
            sg := ""
        }
    }
    CloudPlayer_AppendDownloadUrlFromData(&out, &seen, data, fullHdr, cdnHdr, proxyOnly)
    if (sg != "") {
        CloudPlayer_PushDownloadCandidate(&out, &seen, CloudPlayer_MakeProxyPUrl(remotePath, sg), Map())
        CloudPlayer_PushDownloadCandidate(&out, &seen, CloudPlayer_MakeDirectDUrl(remotePath, sg), Map())
    } else if !proxyOnly {
        CloudPlayer_PushDownloadCandidate(&out, &seen, CloudPlayer_MakeProxyPUrl(remotePath, ""), Map())
        CloudPlayer_PushDownloadCandidate(&out, &seen, CloudPlayer_MakeDirectDUrl(remotePath, ""), Map())
    }
    return out
}

CloudPlayer_AppendDownloadAuthToken(&tokens, tok) {
    t := Trim(String(tok))
    if (t = "")
        return
    if !(tokens is Array)
        return
    for _, existing in tokens {
        if (existing = t)
            return
    }
    tokens.Push(t)
}

CloudPlayer_ApplyDownloadRequestHeaders(whr, token, extraHeaders, localProxy) {
    whr.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36")
    whr.SetRequestHeader("Accept", "application/octet-stream,*/*")
    tk := Trim(String(token))
    hdrs := CloudPlayer_NormalizeHttpHeaders(extraHeaders)
    if localProxy {
        global g_CloudPlayerApiBase
        base := RTrim(String(g_CloudPlayerApiBase), "/")
        if (base != "")
            whr.SetRequestHeader("Referer", base . "/")
        for k, v in hdrs {
            lk := StrLower(Trim(String(k)))
            if (lk = "authorization" || lk = "host")
                continue
            try whr.SetRequestHeader(String(k), String(v))
        }
        return
    } else {
        for k, v in hdrs {
            lk := StrLower(Trim(String(k)))
            if (lk = "authorization" || lk = "host")
                continue
            try whr.SetRequestHeader(String(k), String(v))
        }
        if (tk != "")
            whr.SetRequestHeader("Authorization", tk)
    }
}

CloudPlayer_DownloadWalkSaveFile(childLocal, childRemote, token, data, listSign := "", reqId := "", fallbackToken := "", manifestItem := 0, expectedSize := 0) {
    res := Map("ok", false, "error", "no_download_url")
    candidates := CloudPlayer_BuildDownloadCandidates(data, childRemote, listSign, true, manifestItem)
    if !(candidates is Array) || candidates.Length = 0
        return res
    lastErr := ""
    tokens := []
    CloudPlayer_AppendDownloadAuthToken(&tokens, token)
    CloudPlayer_AppendDownloadAuthToken(&tokens, fallbackToken)
    if (tokens.Length = 0) {
        errEmpty := ""
        CloudPlayer_AppendDownloadAuthToken(&tokens, CloudPlayer_ResolveDownloadAuthToken("", &errEmpty))
    }
    refreshedUsed := false
    ti := 0
    while (ti < tokens.Length) {
        ti += 1
        passTok := tokens[ti]
        authFailed := false
        for _, info in candidates {
            if !(info is Map) || !info.Has("url") || info["url"] = ""
                continue
            u := Trim(String(info["url"]))
            hdr := info.Has("headers") ? info["headers"] : 0
            localPx := CloudPlayer_IsLocalOpenListProxyUrl(u)
            useTok := localPx ? "" : passTok
            dl := CloudPlayer_DownloadBinaryEx(u, childLocal, useTok, hdr, expectedSize)
            if dl["ok"] {
                res["ok"] := true
                res["error"] := ""
                return res
            }
            lastErr := dl.Has("error") ? String(dl["error"]) : "download failed"
            if InStr(lastErr, "401") {
                authFailed := true
                break
            }
            if InStr(lastErr, "403") || InStr(lastErr, "429")
                Sleep(1800)
        }
        if (lastErr != "" && !authFailed)
            break
        if (ti >= tokens.Length && !refreshedUsed) {
            refreshedUsed := true
            errRefresh := ""
            refreshed := CloudPlayer_ResolveDownloadAuthToken("", &errRefresh)
            if (refreshed != "")
                CloudPlayer_AppendDownloadAuthToken(&tokens, refreshed)
        }
    }
    res["error"] := lastErr
    rid := Trim(String(reqId))
    if (rid != "" || lastErr != "") {
        nCand := (candidates is Array) ? candidates.Length : 0
        hasPre := (manifestItem is Map && manifestItem.Has("downloadUrl") && Trim(String(manifestItem["downloadUrl"])) != "") ? 1 : 0
        try CoreAsyncHttp_Log("cloudplayer_dl_file_fail", "req_id=" . rid . " remote=" . childRemote . " err=" . lastErr . " candidates=" . nCand . " pre_url=" . hasPre)
    }
    return res
}

CloudPlayer_ZipStageToFile(stageRoot, zipPath, timeoutMs := 180000) {
    out := Map("ok", false, "timedOut", false, "exitCode", -1, "stderr", "", "error", "")
    stageRoot := Trim(String(stageRoot))
    zipPath := Trim(String(zipPath))
    if (stageRoot = "" || !DirExist(stageRoot)) {
        out["error"] := "stage folder missing"
        return out
    }
    sevenZip := A_ScriptDir . "\lib\7z.exe"
    if !FileExist(sevenZip) {
        out["error"] := "missing lib\\7z.exe"
        return out
    }
    try FileDelete(zipPath)
    stageLong := CloudPlayer_ToWinLongPath(stageRoot)
    cmd := '"' . sevenZip . '" a -tzip -mx=5 -bso0 -bsp0 "' . zipPath . '" "' . stageLong . '"'
    cap := CloudPlayer_ExecCapture(cmd, timeoutMs)
    out["timedOut"] := cap.Has("timedOut") ? !!cap["timedOut"] : false
    out["stderr"] := cap.Has("stderr") ? String(cap["stderr"]) : ""
    try out["exitCode"] := Integer(cap["exitCode"])
    catch {
        out["exitCode"] := -1
    }
    zipOk := false
    try zipOk := FileExist(zipPath) && (FileGetSize(zipPath) > 0)
    catch {
        zipOk := FileExist(zipPath)
    }
    ex := out["exitCode"]
    out["ok"] := zipOk && !out["timedOut"] && (ex = 0 || ex = 1)
    if (!out["ok"] && out["error"] = "") {
        if (out["timedOut"])
            out["error"] := "zip timeout"
        else if (!zipOk)
            out["error"] := "zip not created"
        else
            out["error"] := "zip exit " . ex
    }
    return out
}

CloudPlayer_ParseFsGetSign(data) {
    if !(data is Map)
        return ""
    sign := ""
    try sign := Trim(String(data.Has("sign") ? data["sign"] : ""))
    catch {
        sign := ""
    }
    if (sign = "") {
        try {
            if (data.Has("content") && data["content"] is Map)
                sign := Trim(String(data["content"].Has("sign") ? data["content"]["sign"] : ""))
        } catch {
            sign := ""
        }
    }
    return sign
}

CloudPlayer_ParseFsGetUrlInfo(data, remotePath := "") {
    if !(data is Map)
        return Map("url", "")
    extraHeaders := data.Has("header") ? data["header"] : 0
    for _, key in ["raw_url", "url"] {
        try u := Trim(String(data.Has(key) ? data[key] : ""))
        catch {
            u := ""
        }
        if (u != "" && RegExMatch(u, "i)^https?://") && !RegExMatch(u, "i)/@manage(?:[/?#]|$)"))
            return Map("url", u, "headers", extraHeaders)
    }
    try {
        if (data.Has("content") && data["content"] is Map && data["content"].Has("url")) {
            u2 := Trim(String(data["content"]["url"]))
            if (u2 != "" && RegExMatch(u2, "i)^https?://") && !RegExMatch(u2, "i)/@manage(?:[/?#]|$)"))
                return Map("url", u2, "headers", extraHeaders)
        }
    } catch {
    }
    sign := CloudPlayer_ParseFsGetSign(data)
    return Map("url", CloudPlayer_MakeDirectDUrl(remotePath, sign), "headers", extraHeaders)
}

CloudPlayer_ResolveDownloadUrl(remotePath, headers, reqId := "") {
    global g_CloudPlayerApiBase
    ret := CloudPlayer_HttpJsonAwait("POST", g_CloudPlayerApiBase . "/api/fs/get", headers, Jxon_Dump(Map("path", CloudPlayer_NormalizeRemotePath(remotePath), "password", "")), reqId)
    if !ret["ok"]
        return Map("url", "")
    data := 0
    try data := ret["json"]["data"]
    catch {
        data := 0
    }
    return CloudPlayer_ParseFsGetUrlInfo(data, remotePath)
}

CloudPlayer_ResolveDownloadUrlAsync(remotePath, headers, reqId := "", callback := 0) {
    cb := IsObject(callback) ? callback : 0
    CloudPlayer_FetchFsGetDataAsync(remotePath, headers, reqId, (ret) => (
        cb ? cb.Call(
            (ret is Map && ret.Has("ok") && ret["ok"])
                ? CloudPlayer_ParseFsGetUrlInfo(ret["data"], remotePath)
                : Map("url", "", "headers", 0, "error", (ret is Map && ret.Has("error")) ? String(ret["error"]) : "fs/get failed")
        ) : 0
    ))
}

CloudPlayer_DownloadBinary(url, outPath, token := "", extraHeaders := 0) {
    return CloudPlayer_DownloadBinaryEx(url, outPath, token, extraHeaders)["ok"]
}

CloudPlayer_DownloadBinaryEx(url, outPath, token := "", extraHeaders := 0, expectedSize := 0) {
    res := Map("ok", false, "error", "", "status", 0)
    u := Trim(String(url))
    if (u = "" || RegExMatch(u, "i)/@manage(?:[/?#]|$)")) {
        res["error"] := "invalid url"
        return res
    }
    try {
        if CloudPlayer_IsLocalOpenListProxyUrl(u) {
            if CloudPlayer_DownloadViaUrlMon(u, outPath, expectedSize) {
                res["ok"] := true
                return res
            }
            try CoreAsyncHttp_Log("cloudplayer_dl_urlmon_fallback", "url=" . u . " out=" . outPath)
            catch {
            }
        }
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        ; Use sync mode for binary downloads to avoid sporadic empty ResponseBody on async WaitForResponse.
        whr.Open("GET", u, false)
        whr.SetTimeouts(10000, 10000, 30000, 120000)
        try whr.Option[9] := 2048
        catch {
        }
        try whr.SetRequestHeader("Accept-Encoding", "identity")
        catch {
        }
        localProxy := CloudPlayer_IsLocalOpenListProxyUrl(u)
        CloudPlayer_ApplyDownloadRequestHeaders(whr, token, extraHeaders, localProxy)
        whr.Send()
        st := 0
        try st := Integer(whr.Status)
        catch {
            st := 0
        }
        res["status"] := st
        finalUrl := ""
        try finalUrl := String(whr.Option(1))
        catch {
            finalUrl := u
        }
        if (st < 200 || st >= 300 || RegExMatch(finalUrl, "i)/@manage(?:[/?#]|$)")) {
            res["error"] := "http " . st
            return res
        }
        if !CloudPlayer_WriteHttpBodyToFile(whr, outPath, expectedSize) {
            redirectUrl := CloudPlayer_TryExtractBodyUrl(whr)
            if (redirectUrl != "" && redirectUrl != u)
                return CloudPlayer_DownloadBinaryEx(redirectUrl, outPath, token, extraHeaders, expectedSize)
            gotSz := 0
            try {
                if FileExist(outPath)
                    gotSz := FileGetSize(outPath)
            } catch {
                gotSz := 0
            }
            ct := ""
            try ct := String(whr.GetResponseHeader("Content-Type"))
            catch {
                ct := ""
            }
            res["error"] := (st = 0) ? "save failed" : ("save failed after http " . st . " bytes=" . gotSz . " ct=" . ct)
            return res
        }
        res["ok"] := true
        return res
    } catch as e {
        res["error"] := e.Message
        return res
    }
}

CloudPlayer_DownloadViaUrlMon(url, outPath, expectedSize := 0) {
    u := Trim(String(url))
    p := CloudPlayer_StripWinLongPath(CloudPlayer_ToWinLongPath(outPath))
    if (u = "" || p = "")
        return false
    dir := RegExReplace(p, "\\[^\\]*$")
    if (dir != "")
        DirCreate(dir)
    try FileDelete(p)
    catch {
    }
    hr := DllCall("urlmon\URLDownloadToFileW"
        , "ptr", 0
        , "wstr", u
        , "wstr", p
        , "uint", 0
        , "ptr", 0
        , "uint")
    if (hr != 0 || !FileExist(p))
        return false
    sz := 0
    try sz := FileGetSize(p)
    catch {
        sz := 0
    }
    if (sz <= 0)
        return false
    exp := 0
    try exp := Integer(expectedSize)
    catch {
        exp := 0
    }
    if (exp > 1024 && sz < Floor(exp * 0.2))
        return false
    return true
}

CloudPlayer_TryExtractBodyUrl(whr) {
    try {
        txt := Trim(String(whr.ResponseText))
        if (txt = "" || StrLen(txt) > 4096)
            return ""
        ; Some providers return a one-line direct URL instead of binary bytes.
        if RegExMatch(txt, "i)^https?://[^\s]+$")
            return txt
    } catch {
    }
    return ""
}

CloudPlayer_MakeDirectDUrl(remotePath, sign := "") {
    global g_CloudPlayerApiBase
    u := RTrim(g_CloudPlayerApiBase, "/") . "/d" . CloudPlayer_EncodeRemotePath(remotePath)
    sg := Trim(String(sign))
    if (sg != "")
        u .= "?sign=" . CloudPlayer_UrlEncodeUtf8(sg)
    return u
}

CloudPlayer_MakeProxyPUrl(remotePath, sign := "") {
    global g_CloudPlayerApiBase
    u := RTrim(g_CloudPlayerApiBase, "/") . "/p" . CloudPlayer_EncodeRemotePath(remotePath)
    sg := Trim(String(sign))
    if (sg != "")
        u .= "?sign=" . CloudPlayer_UrlEncodeUtf8(sg)
    return u
}

CloudPlayer_EncodeRemotePath(remotePath) {
    p := CloudPlayer_NormalizeRemotePath(remotePath)
    parts := StrSplit(p, "/")
    out := ""
    for _, part in parts {
        if (part = "")
            continue
        out .= "/" . CloudPlayer_UrlEncodeUtf8(part)
    }
    return out = "" ? "/" : out
}

CloudPlayer_UrlEncodeUtf8(s) {
    buf := Buffer(StrPut(String(s), "UTF-8") - 1)
    StrPut(String(s), buf, "UTF-8")
    out := ""
    loop buf.Size {
        b := NumGet(buf, A_Index - 1, "UChar")
        ch := Chr(b)
        if ((b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A) || ch = "-" || ch = "_" || ch = "." || ch = "~")
            out .= ch
        else
            out .= "%" . Format("{:02X}", b)
    }
    return out
}

CloudPlayer_NormalizeRemotePath(path) {
    p := StrReplace(Trim(String(path)), "\", "/")
    if (p = "")
        p := "/"
    if (SubStr(p, 1, 1) != "/")
        p := "/" . p
    return RegExReplace(p, "/+", "/")
}

CloudPlayer_CombineRemotePath(parent, name) {
    return CloudPlayer_NormalizeRemotePath(RTrim(CloudPlayer_NormalizeRemotePath(parent), "/") . "/" . name)
}

CloudPlayer_RemoteBaseName(path) {
    p := RTrim(CloudPlayer_NormalizeRemotePath(path), "/")
    pos := InStr(p, "/", , -1)
    return pos > 0 ? SubStr(p, pos + 1) : p
}

CloudPlayer_SafeFileName(name) {
    s := Trim(String(name))
    s := RegExReplace(s, '[\\/:*?"<>|]', "_")
    s := RegExReplace(s, "\s+", " ")
    s := Trim(s, " .`t`r`n")
    if (StrLen(s) > 120)
        s := SubStr(s, 1, 120)
    return s
}

CloudPlayer_DownloadsDir() {
    dir := EnvGet("USERPROFILE") . "\Downloads"
    if (dir != "\Downloads" && DirExist(dir))
        return dir
    return A_Desktop
}

CloudPlayer_GetArchiveEntries(remotePath, token := "", reqId := "") {
    global g_CloudPlayerApiBase
    out := Map("ok", false, "message", "", "entries", [])
    CloudPlayer_PostArchiveProgress(reqId, "压缩包预览：开始准备...", 3)
    rp := CloudPlayer_NormalizeRemotePath(remotePath)
    if (rp = "/" || rp = "") {
        out["message"] := "invalid archive path"
        return out
    }
    headers := Map("Content-Type", "application/json", "Accept", "application/json")
    tk := Trim(String(token))
    if (tk = "") {
        errTok := ""
        tk := CloudPlayer_GetOpenListAdminToken(&errTok, 12000)
    }
    if (tk != "")
        headers["Authorization"] := tk

    CloudPlayer_PostArchiveProgress(reqId, "压缩包预览：正在解析下载地址...", 12)
    info := CloudPlayer_ResolveDownloadUrl(rp, headers)
    if !(info is Map) || !info.Has("url") || Trim(String(info["url"])) = "" {
        out["message"] := "resolve archive url failed"
        return out
    }

    sevenZip := A_ScriptDir . "\lib\7z.exe"
    if !FileExist(sevenZip) {
        out["message"] := "missing lib\\7z.exe"
        return out
    }

    stamp := FormatTime(, "yyyyMMdd_HHmmss")
    workDir := A_Temp . "\NiumaZipPreview_" . stamp . "_" . A_TickCount
    DirCreate(workDir)
    arcPath := workDir . "\preview.archive"
    CloudPlayer_PostArchiveProgress(reqId, "压缩包预览：正在下载压缩包...", 42)
    okDl := CloudPlayer_DownloadBinary(String(info["url"]), arcPath, tk, info.Has("headers") ? info["headers"] : 0)
    if !okDl || !FileExist(arcPath) {
        try DirDelete(workDir, true)
        out["message"] := "download archive failed"
        return out
    }

    CloudPlayer_PostArchiveProgress(reqId, "压缩包预览：正在读取目录结构...", 74)
    cmd := '"' . sevenZip . '" l -slt -ba -y -p"" -- "' . arcPath . '"'
    cap := CloudPlayer_ExecCapture(cmd, 15000)
    stdout := ""
    try stdout := String(cap["stdout"])
    catch {
        stdout := ""
    }
    stderr := ""
    try stderr := String(cap["stderr"])
    catch {
        stderr := ""
    }
    txt := stdout . "`n" . stderr
    lines := StrSplit(txt, "`n", "`r")
    arr := []
    maxItems := 1200
    for _, line in lines {
        s := Trim(String(line))
        if (SubStr(s, 1, 7) != "Path = ")
            continue
        name := Trim(SubStr(s, 8))
        if (name = "" || name = arcPath)
            continue
        arr.Push(name)
        if (arr.Length >= maxItems)
            break
    }
    try DirDelete(workDir, true)
    if (arr.Length = 0) {
        out["message"] := "zip list is empty or parse failed"
        return out
    }
    CloudPlayer_PostArchiveProgress(reqId, "压缩包预览：目录读取完成", 100)
    out["ok"] := true
    out["entries"] := arr
    out["message"] := "ok"
    return out
}

CloudPlayer_GetArchiveEntriesAsync(remotePath, token := "", reqId := "", callback := 0) {
    cb := IsObject(callback) ? callback : 0
    out := Map("ok", false, "message", "", "entries", [])
    CloudPlayer_PostArchiveProgress(reqId, "压缩包预览：开始准备...", 3)
    rp := CloudPlayer_NormalizeRemotePath(remotePath)
    if (rp = "/" || rp = "") {
        out["message"] := "invalid archive path"
        if cb
            cb.Call(out)
        return
    }
    headers := Map("Content-Type", "application/json", "Accept", "application/json")
    tk := Trim(String(token))
    if (tk = "") {
        errTok := ""
        tk := CloudPlayer_GetOpenListAdminToken(&errTok, 12000)
    }
    if (tk != "")
        headers["Authorization"] := tk
    CloudPlayer_PostArchiveProgress(reqId, "压缩包预览：正在解析下载地址...", 12)
    CloudPlayer_ResolveDownloadUrlAsync(rp, headers, reqId, (info) => CloudPlayer_GetArchiveEntriesAsync_OnResolved(reqId, rp, tk, info, cb))
}

CloudPlayer_GetArchiveEntriesAsync_OnResolved(reqId, rp, tk, info, cb) {
    out := Map("ok", false, "message", "", "entries", [])
    if !(info is Map) || !info.Has("url") || Trim(String(info["url"])) = "" {
        out["message"] := "resolve archive url failed"
        if cb
            cb.Call(out)
        return
    }
    SetTimer(() => (
        cb ? cb.Call(CloudPlayer_GetArchiveEntries_FromResolved(rp, tk, info, reqId)) : 0
    ), -1)
}

CloudPlayer_GetArchiveEntries_FromResolved(remotePath, token, info, reqId := "") {
    out := Map("ok", false, "message", "", "entries", [])
    sevenZip := A_ScriptDir . "\lib\7z.exe"
    if !FileExist(sevenZip) {
        out["message"] := "missing lib\\7z.exe"
        return out
    }
    stamp := FormatTime(, "yyyyMMdd_HHmmss")
    workDir := A_Temp . "\NiumaZipPreview_" . stamp . "_" . A_TickCount
    DirCreate(workDir)
    arcPath := workDir . "\preview.archive"
    CloudPlayer_PostArchiveProgress(reqId, "压缩包预览：正在下载压缩包...", 42)
    okDl := CloudPlayer_DownloadBinary(String(info["url"]), arcPath, token, info.Has("headers") ? info["headers"] : 0)
    if !okDl || !FileExist(arcPath) {
        try DirDelete(workDir, true)
        out["message"] := "download archive failed"
        return out
    }
    CloudPlayer_PostArchiveProgress(reqId, "压缩包预览：正在读取目录结构...", 74)
    cmd := '"' . sevenZip . '" l -slt -ba -y -p"" -- "' . arcPath . '"'
    cap := CloudPlayer_ExecCapture(cmd, 15000)
    stdout := ""
    try stdout := String(cap["stdout"])
    catch {
        stdout := ""
    }
    stderr := ""
    try stderr := String(cap["stderr"])
    catch {
        stderr := ""
    }
    txt := stdout . "`n" . stderr
    lines := StrSplit(txt, "`n", "`r")
    arr := []
    maxItems := 1200
    for _, line in lines {
        s := Trim(String(line))
        if (SubStr(s, 1, 7) != "Path = ")
            continue
        name := Trim(SubStr(s, 8))
        if (name = "" || name = arcPath)
            continue
        arr.Push(name)
        if (arr.Length >= maxItems)
            break
    }
    try DirDelete(workDir, true)
    if (arr.Length = 0) {
        out["message"] := "zip list is empty or parse failed"
        return out
    }
    CloudPlayer_PostArchiveProgress(reqId, "压缩包预览：目录读取完成", 100)
    out["ok"] := true
    out["entries"] := arr
    out["message"] := "ok"
    return out
}

; Compatibility wrapper kept for rollback/testing; prefer CloudPlayer_HttpJsonAwait at callsites.
CloudPlayer_HttpJson(method, url, headers := 0, body := "", reqId := "") {
    try CoreAsyncHttp_Log("cloudplayer_http_bridge_deprecated", "method=" . method . " url=" . url . " req_id=" . reqId)
    if (CloudPlayer_ToBool(EnvGet("NIUMA_CP_HTTP_BRIDGE_DIRECT"), false))
        return CloudPlayer_HttpJsonDirect(method, url, headers, body)
    return CloudPlayer_HttpJsonAwait(method, url, headers, body, reqId)
}

CloudPlayer_ResolveAsyncSender() {
    global g_CloudPlayerAsyncSenderResolved, g_CloudPlayerAsyncSenderKind, g_CloudPlayerAsyncSenderFn, g_CloudPlayerAsyncSenderLastProbeTick
    ; Do not lock on missing forever: retry probe periodically for late-loaded modules.
    probeTtlMs := 1500
    nowTick := A_TickCount
    if g_CloudPlayerAsyncSenderResolved {
        if (g_CloudPlayerAsyncSenderKind != "")
            return true
        elapsed := nowTick - g_CloudPlayerAsyncSenderLastProbeTick
        if (elapsed < 0)
            elapsed := 2147483647
        if (elapsed < probeTtlMs)
            return false
    }
    g_CloudPlayerAsyncSenderResolved := true
    g_CloudPlayerAsyncSenderKind := ""
    g_CloudPlayerAsyncSenderFn := 0
    g_CloudPlayerAsyncSenderLastProbeTick := nowTick
    try {
        fn := Func("HttpJsonAsync")
        if IsObject(fn) {
            g_CloudPlayerAsyncSenderFn := fn
            g_CloudPlayerAsyncSenderKind := "HttpJsonAsync"
            return true
        }
    } catch {
    }
    try {
        fn := Func("CoreAsyncHttp_SendAsync")
        if IsObject(fn) {
            g_CloudPlayerAsyncSenderFn := fn
            g_CloudPlayerAsyncSenderKind := "CoreAsyncHttp_SendAsync"
            return true
        }
    } catch {
    }
    return false
}

CloudPlayer_HasAsyncSender() {
    return CloudPlayer_ResolveAsyncSender()
}

CloudPlayer_ResetAsyncSenderResolution() {
    global g_CloudPlayerAsyncSenderResolved, g_CloudPlayerAsyncSenderKind, g_CloudPlayerAsyncSenderFn, g_CloudPlayerAsyncSenderLastProbeTick
    g_CloudPlayerAsyncSenderResolved := false
    g_CloudPlayerAsyncSenderKind := ""
    g_CloudPlayerAsyncSenderFn := 0
    g_CloudPlayerAsyncSenderLastProbeTick := 0
}

CloudPlayer_LogAsyncSenderHealth(source := "") {
    global g_CloudPlayerAsyncSenderWarned, g_CloudPlayerAsyncSenderKind
    if CloudPlayer_ResolveAsyncSender() {
        g_CloudPlayerAsyncSenderWarned := false
        try CoreAsyncHttp_Log("cloudplayer_async_sender_ok", "source=" . source . " sender=" . g_CloudPlayerAsyncSenderKind . " thread=" . CloudPlayer_CurrentThreadId())
        return true
    }
    if !g_CloudPlayerAsyncSenderWarned {
        g_CloudPlayerAsyncSenderWarned := true
        try CoreAsyncHttp_Log("cloudplayer_async_sender_missing", "source=" . source . " sender=none thread=" . CloudPlayer_CurrentThreadId() . " hint=restart main script or verify CoreAsyncHttp include/load errors")
    }
    return false
}

CloudPlayer_SendJsonAsyncViaResolvedSender(method, url, body, callback, opts := 0) {
    global g_CloudPlayerAsyncSenderKind, g_CloudPlayerAsyncSenderFn
    cb := IsObject(callback) ? callback : 0
    o := (opts is Map) ? opts : Map()
    if !CloudPlayer_ResolveAsyncSender()
        return false
    fn := g_CloudPlayerAsyncSenderFn
    if !fn
        return false
    if (g_CloudPlayerAsyncSenderKind = "HttpJsonAsync") {
        fn.Call(String(method), String(url), body != "" ? String(body) : "", cb, o)
        return true
    }
    if (g_CloudPlayerAsyncSenderKind = "CoreAsyncHttp_SendAsync") {
        fn.Call(String(method), String(url), body != "" ? String(body) : "", (ret) => (
            cb ? cb.Call(ret) : 0
        ), o)
        return true
    }
    return false
}

; Await helper on top of CoreAsyncHttp. Keeps return shape: {ok,status,json,text,error}
CloudPlayer_HttpJsonAwait(method, url, headers := 0, body := "", reqId := "") {
    ret := Map("ok", false, "status", 0, "json", 0, "text", "", "error", "")
    if !CloudPlayer_HasAsyncSender() {
        CloudPlayer_LogAsyncSenderHealth("http_await")
        try CoreAsyncHttp_Log("cloudplayer_http_bridge_fallback_sync", "method=" . method . " url=" . url . " req_id=" . reqId . " reason=missing_async_sender")
        return CloudPlayer_HttpJsonDirect(method, url, headers, body)
    }
    bucket := Map("done", false, "ret", ret)
    hdrs := (headers is Map) ? headers : Map()
    rid := Trim(String(reqId))
    try {
        okSent := CloudPlayer_SendJsonAsyncViaResolvedSender(String(method), String(url), body != "" ? String(body) : "", (coreRet) => (
            bucket["ret"] := CloudPlayer_HttpJsonFromCore(coreRet),
            bucket["done"] := true
        ), Map(
            "headers", hdrs,
            "timeoutMs", 15000,
            "connectTimeoutMs", 5000,
            "sendTimeoutMs", 10000,
            "receiveTimeoutMs", 15000,
            "reqId", rid,
            "tag", "cp_http_sync_bridge"
        ))
        if !okSent {
            CloudPlayer_ResetAsyncSenderResolution()
            CloudPlayer_LogAsyncSenderHealth("http_await_send")
            try CoreAsyncHttp_Log("cloudplayer_http_bridge_fallback_sync", "method=" . method . " url=" . url . " req_id=" . reqId . " reason=async_send_failed")
            return CloudPlayer_HttpJsonDirect(method, url, headers, body)
        }
        deadline := A_TickCount + 15000
        while !bucket["done"] && (A_TickCount < deadline) {
            try {
                global g_CloudPlayerImportTask
                if (g_CloudPlayerImportTask is Map && g_CloudPlayerImportTask.Has("active") && g_CloudPlayerImportTask["active"]
                    && g_CloudPlayerImportTask.Has("cancelled") && g_CloudPlayerImportTask["cancelled"]) {
                    bucket["ret"]["error"] := "cancelled"
                    return bucket["ret"]
                }
            } catch {
            }
            Sleep(10)
        }
        if !bucket["done"]
            bucket["ret"]["error"] := "timeout"
        ret := bucket["ret"]
        if !ret["ok"] && Trim(String(ret["error"])) = "" {
            try CoreAsyncHttp_Log("cloudplayer_http_bridge_empty_fail", "method=" . method . " url=" . url . " req_id=" . rid)
            ret := CloudPlayer_HttpJsonDirect(method, url, headers, body)
        }
    } catch as e {
        ret["error"] := e.Message
    }
    return ret
}

CloudPlayer_HttpJsonDirect(method, url, headers := 0, body := "") {
    ret := Map("ok", false, "status", 0, "json", 0, "text", "", "error", "")
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open(String(method), String(url), false)
        whr.SetTimeouts(5000, 5000, 10000, 15000)
        if (headers is Map) {
            for k, v in headers {
                hk := Trim(String(k))
                if (hk = "")
                    continue
                try whr.SetRequestHeader(hk, String(v))
            }
        }
        m := StrUpper(Trim(String(method)))
        if (m = "POST" || m = "PUT" || m = "PATCH") {
            if !(headers is Map) || !CloudPlayer_HasHeader(headers, "Content-Type")
                whr.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
            whr.Send(body != "" ? String(body) : "{}")
        } else {
            whr.Send()
        }
        st := 0
        txt := ""
        try st := Integer(whr.Status)
        try txt := String(whr.ResponseText)
        ret["status"] := st
        ret["text"] := txt
        okHttp := (st >= 200 && st < 300)
        if (txt != "") {
            try ret["json"] := Jxon_Load(txt)
        }
        ret["ok"] := okHttp
        if !okHttp
            ret["error"] := "http " . st
        if (ret["json"] is Map && ret["json"].Has("code")) {
            biz := 0
            try biz := Integer(ret["json"]["code"])
            if (biz != 200) {
                ret["ok"] := false
                msg := ""
                try msg := String(ret["json"].Has("message") ? ret["json"]["message"] : "")
                ret["error"] := (msg != "") ? msg : ("code " . biz)
            }
        }
        return ret
    } catch as e {
        ret["error"] := e.Message
        return ret
    }
}

CloudPlayer_HasHeader(headers, keyName) {
    if !(headers is Map)
        return false
    want := StrLower(Trim(String(keyName)))
    if (want = "")
        return false
    for k, _ in headers {
        if (StrLower(Trim(String(k))) = want)
            return true
    }
    return false
}

CloudPlayer_HttpJsonFromCore(coreRet) {
    ret := Map("ok", false, "status", 0, "json", 0, "text", "", "error", "")
    if !(coreRet is Map)
        return ret
    try ret["ok"] := !!coreRet["ok"]
    catch {
        ret["ok"] := false
    }
    try ret["status"] := Integer(coreRet["status"])
    catch {
        ret["status"] := 0
    }
    try ret["text"] := String(coreRet["text"])
    catch {
        ret["text"] := ""
    }
    try ret["json"] := coreRet["json"]
    catch {
        ret["json"] := 0
    }
    try ret["error"] := String(coreRet["error"])
    catch {
        ret["error"] := ""
    }
    if (ret["json"] is Map && ret["json"].Has("code")) {
        bizCode := ""
        try bizCode := Integer(ret["json"]["code"])
        catch {
            bizCode := ""
        }
        if (bizCode != "" && bizCode != 200) {
            ret["ok"] := false
            errBiz := ""
            try errBiz := String(ret["json"].Has("message") ? ret["json"]["message"] : ("code " . bizCode))
            catch {
                errBiz := "code " . bizCode
            }
            ret["error"] := errBiz
        }
    }
    if !ret["ok"] && (ret["error"] = "") {
        st := ret["status"]
        errMsg := ""
        if (ret["json"] is Map && ret["json"].Has("message"))
            errMsg := String(ret["json"]["message"])
        ret["error"] := (errMsg != "") ? errMsg : ("http " . st)
    }
    return ret
}

CloudPlayer_HttpJsonAsyncReq(method, url, headers := 0, body := "", callback := 0, reqId := "", tag := "cp_http_async") {
    cb := IsObject(callback) ? callback : 0
    rid := Trim(String(reqId))
    CloudPlayer_AsyncLog("cloudplayer_async_http_start", "method=" . method . " req_id=" . rid . " url=" . url . " tag=" . tag)
    CloudPlayer_HttpJsonAsync(method, url, headers, body, (ret) => (
        CloudPlayer_AsyncLog("cloudplayer_async_http_done", "method=" . method . " req_id=" . rid . " ok=" . (ret["ok"] ? 1 : 0) . " status=" . ret["status"] . " tag=" . tag),
        cb ? cb.Call(ret) : 0
    ), rid, tag)
}

CloudPlayer_HttpJsonAsync(method, url, headers := 0, body := "", callback := 0, reqId := "", tag := "cp_http_async") {
    cb := IsObject(callback) ? callback : 0
    hdrs := (headers is Map) ? headers : Map()
    rid := Trim(String(reqId))
    okSent := CloudPlayer_SendJsonAsyncViaResolvedSender(String(method), String(url), body != "" ? String(body) : "", (coreRet) => (
        cb ? cb.Call(CloudPlayer_HttpJsonFromCore(coreRet)) : 0
    ), Map(
        "headers", hdrs,
        "timeoutMs", 12000,
        "receiveTimeoutMs", 12000,
        "reqId", rid,
        "tag", String(tag)
    ))
    if !okSent {
        CloudPlayer_ResetAsyncSenderResolution()
        CloudPlayer_LogAsyncSenderHealth("http_async_send")
        ret := CloudPlayer_HttpJsonDirect(method, url, headers, body)
        cb ? cb.Call(ret) : 0
    }
}

CloudPlayer_OpenExternalUrl(url) {
    u := Trim(String(url))
    if (u = "")
        return false
    if !RegExMatch(u, "i)^https?://")
        return false
    if RegExMatch(u, "i)/@manage(?:[/?#]|$)")
        return false

    ; Use ShellExecute first to force default browser handling for URLs.
    try {
        r := DllCall("Shell32\ShellExecuteW"
            , "ptr", 0
            , "wstr", "open"
            , "wstr", u
            , "ptr", 0
            , "ptr", 0
            , "int", 1
            , "ptr")
        if (r > 32)
            return true
    } catch {
    }

    ; Fallback to Run if ShellExecute fails for any reason.
    try {
        Run(u)
        return true
    } catch {
    }
    return false
}

