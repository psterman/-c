; AppUpdateCheck.ahk — 启动后异步对比 GitHub Releases，有新版时通知设置页与托盘

global NMER_GITHUB_REPO := "psterman/nmer"
global NMER_RELEASES_PAGE := "https://github.com/psterman/nmer/releases"
global g_AppUpdate_CurrentVersion := ""
global g_AppUpdate_LatestVersion := ""
global g_AppUpdate_HasUpdate := false
global g_AppUpdate_ReleaseUrl := ""
global g_AppUpdate_LastCheckTick := 0
global g_AppUpdate_CheckInFlight := false
global g_AppUpdate_PeriodicArmed := false

AppUpdateCheck_VersionFile() {
    return A_ScriptDir . "\config\app_version.json"
}

AppUpdateCheck_LoadLocalVersion() {
    path := AppUpdateCheck_VersionFile()
    ver := ""
    if FileExist(path) {
        try {
            raw := FileRead(path, "UTF-8")
            if (Trim(raw) != "") {
                doc := Jxon_Load(raw)
                if (doc is Map)
                    ver := Trim(String(doc.Get("version", "")))
            }
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    if (ver = "")
        ver := "0.0.0"
    global g_AppUpdate_CurrentVersion
    g_AppUpdate_CurrentVersion := ver
    return ver
}

AppUpdateCheck_NormalizeVersion(v) {
    v := Trim(String(v))
    if (v = "")
        return "0"
    v := RegExReplace(v, "^[vV]", "")
    v := RegExReplace(v, "[^0-9A-Za-z.+-]", "")
    return v
}

AppUpdateCheck_VersionParts(v) {
    v := AppUpdateCheck_NormalizeVersion(v)
    parts := []
    for p in StrSplit(v, ".") {
        p := Trim(p)
        if (p = "")
            continue
        if RegExMatch(p, "^\d+$")
            parts.Push(Integer(p))
        else
            parts.Push(p)
    }
    if (parts.Length = 0)
        parts.Push(0)
    return parts
}

; 返回 -1 / 0 / 1（a 相对 b）
AppUpdateCheck_Compare(a, b) {
    pa := AppUpdateCheck_VersionParts(a)
    pb := AppUpdateCheck_VersionParts(b)
    n := pa.Length > pb.Length ? pa.Length : pb.Length
    loop n {
        i := A_Index
        va := i <= pa.Length ? pa[i] : 0
        vb := i <= pb.Length ? pb[i] : 0
        ta := Type(va), tb := Type(vb)
        if (ta = "Integer" && tb = "Integer") {
            if (va < vb)
                return -1
            if (va > vb)
                return 1
            continue
        }
        sa := String(va), sb := String(vb)
        if (sa < sb)
            return -1
        if (sa > sb)
            return 1
    }
    return 0
}

AppUpdateCheck_IsNewer(remote, localVer) {
    return AppUpdateCheck_Compare(remote, localVer) > 0
}

AppUpdateCheck_PayloadForWeb() {
    global g_AppUpdate_CurrentVersion, g_AppUpdate_LatestVersion, g_AppUpdate_HasUpdate
    global g_AppUpdate_ReleaseUrl, NMER_RELEASES_PAGE
    cur := g_AppUpdate_CurrentVersion
    if (cur = "")
        cur := AppUpdateCheck_LoadLocalVersion()
    url := g_AppUpdate_ReleaseUrl != "" ? g_AppUpdate_ReleaseUrl : NMER_RELEASES_PAGE
    return Map(
        "currentVersion", cur,
        "latestVersion", g_AppUpdate_LatestVersion,
        "hasUpdate", !!g_AppUpdate_HasUpdate,
        "releaseUrl", url,
        "releasesPage", NMER_RELEASES_PAGE,
        "lastCheckTick", g_AppUpdate_LastCheckTick
    )
}

AppUpdateCheck_OpenUrl(url) {
    u := Trim(String(url))
    if (u = "" || !RegExMatch(u, "i)^https?://"))
        return false
    if FuncExists("CloudPlayer_OpenExternalUrl")
        return CloudPlayer_OpenExternalUrl(u)
    try {
        r := DllCall("Shell32\ShellExecuteW", "ptr", 0, "wstr", "open", "wstr", u, "ptr", 0, "ptr", 0, "int", 1, "ptr")
        if (r > 32)
            return true
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try {
        Run(u)
        return true
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return false
}

AppUpdateCheck_OpenReleasePage() {
    global g_AppUpdate_ReleaseUrl, NMER_RELEASES_PAGE
    u := g_AppUpdate_ReleaseUrl != "" ? g_AppUpdate_ReleaseUrl : NMER_RELEASES_PAGE
    ok := AppUpdateCheck_OpenUrl(u)
    if FuncExists("Nmer_Telemetry_Record") {
        try Nmer_Telemetry_Record("health", "update_open_release_page", ok, Map("trigger", "settings"))
        catch as _e {
            NmerCatch(A_ThisFunc, _e)
        }
    }
    return ok
}

AppUpdateCheck_RefreshTrayTip() {
    if !FuncExists("GetText")
        return
    base := GetText("app_tip")
    global g_AppUpdate_HasUpdate, g_AppUpdate_LatestVersion, g_AppUpdate_CurrentVersion
    if g_AppUpdate_HasUpdate {
        lv := g_AppUpdate_LatestVersion != "" ? g_AppUpdate_LatestVersion : "?"
        cv := g_AppUpdate_CurrentVersion != "" ? g_AppUpdate_CurrentVersion : "?"
        A_IconTip := base . "`n有新版本 " . lv . "（当前 " . cv . "）"
    } else
        A_IconTip := base
}

AppUpdateCheck_NotifyUi() {
    if FuncExists("ConfigWebView_Send") && FuncExists("ConfigWebView_HostAlive") {
        try {
            if ConfigWebView_HostAlive()
                ConfigWebView_Send(Map("type", "appUpdateStatus", "payload", AppUpdateCheck_PayloadForWeb()))
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    AppUpdateCheck_RefreshTrayTip()
}

AppUpdateCheck_ApplyResult(latestVer, releaseUrl, fromFallback := false) {
    global g_AppUpdate_LatestVersion, g_AppUpdate_HasUpdate, g_AppUpdate_ReleaseUrl
    global g_AppUpdate_LastCheckTick, g_AppUpdate_CurrentVersion
    lv := AppUpdateCheck_NormalizeVersion(latestVer)
    if (lv = "" || lv = "0")
        return
    cv := g_AppUpdate_CurrentVersion != "" ? g_AppUpdate_CurrentVersion : AppUpdateCheck_LoadLocalVersion()
    g_AppUpdate_LatestVersion := lv
    g_AppUpdate_HasUpdate := AppUpdateCheck_IsNewer(lv, cv)
    ru := Trim(String(releaseUrl))
    if (ru != "" && RegExMatch(ru, "i)^https?://"))
        g_AppUpdate_ReleaseUrl := ru
    else
        g_AppUpdate_ReleaseUrl := NMER_RELEASES_PAGE
    g_AppUpdate_LastCheckTick := A_TickCount
    try NMER_Log("update", "check_done", "local=" . cv . " remote=" . lv . " has=" . (g_AppUpdate_HasUpdate ? "1" : "0") . " fb=" . (fromFallback ? "1" : "0"))
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if FuncExists("Nmer_Telemetry_Record") {
        try Nmer_Telemetry_Record("health", "update_check_done", true, Map("trigger", fromFallback ? "fallback" : "github_api"))
        catch as _e {
            NmerCatch(A_ThisFunc, _e)
        }
        if g_AppUpdate_HasUpdate {
            try Nmer_Telemetry_Record("health", "update_available", true, Map("trigger", fromFallback ? "fallback" : "github_api"))
            catch as _e {
                NmerCatch(A_ThisFunc, _e)
            }
        }
    }
    AppUpdateCheck_NotifyUi()
}

AppUpdateCheck_ParseGithubReleaseJson(text) {
    if (Trim(String(text)) = "")
        return Map("ok", false)
    try {
        doc := Jxon_Load(text)
    } catch {
        return Map("ok", false)
    }
    if !(doc is Map)
        return Map("ok", false)
    tag := Trim(String(doc.Get("tag_name", "")))
    if (tag = "")
        tag := Trim(String(doc.Get("name", "")))
    url := Trim(String(doc.Get("html_url", "")))
    if (tag = "")
        return Map("ok", false)
    return Map("ok", true, "version", tag, "url", url)
}

AppUpdateCheck_ParseRemoteVersionJson(text) {
    if (Trim(String(text)) = "")
        return Map("ok", false)
    try {
        doc := Jxon_Load(text)
    } catch {
        return Map("ok", false)
    }
    if !(doc is Map)
        return Map("ok", false)
    ver := Trim(String(doc.Get("version", "")))
    if (ver = "")
        return Map("ok", false)
    return Map("ok", true, "version", ver, "url", NMER_RELEASES_PAGE)
}

AppUpdateCheck_OnGithubApiDone(ret) {
    global g_AppUpdate_CheckInFlight
    g_AppUpdate_CheckInFlight := false
    ok := false
    if (ret is Map && ret.Get("ok", false) && ret.Get("status", 0) = 200) {
        parsed := AppUpdateCheck_ParseGithubReleaseJson(ret.Get("text", ""))
        if parsed.Get("ok", false) {
            AppUpdateCheck_ApplyResult(parsed["version"], parsed["url"], false)
            ok := true
        }
    }
    if !ok
        AppUpdateCheck_FetchRemoteVersionFile()
}

AppUpdateCheck_OnRemoteVersionFileDone(ret) {
    global g_AppUpdate_CheckInFlight
    g_AppUpdate_CheckInFlight := false
    if !(ret is Map) || !ret.Get("ok", false) || ret.Get("status", 0) != 200 {
        if FuncExists("Nmer_Telemetry_Record") {
            try Nmer_Telemetry_Record("health", "update_check_done", false, Map("trigger", "fallback_http_fail"))
        }
        return
    }
    parsed := AppUpdateCheck_ParseRemoteVersionJson(ret.Get("text", ""))
    if parsed.Get("ok", false)
        AppUpdateCheck_ApplyResult(parsed["version"], parsed["url"], true)
    else if FuncExists("Nmer_Telemetry_Record") {
        try Nmer_Telemetry_Record("health", "update_check_done", false, Map("trigger", "fallback_parse_fail"))
    }
}

AppUpdateCheck_FetchRemoteVersionFile() {
    global NMER_GITHUB_REPO, g_AppUpdate_CheckInFlight
    if g_AppUpdate_CheckInFlight
        return
    g_AppUpdate_CheckInFlight := true
    url := "https://raw.githubusercontent.com/" . NMER_GITHUB_REPO . "/main/config/app_version.json"
    if !FuncExists("HttpGetAsync") {
        g_AppUpdate_CheckInFlight := false
        if FuncExists("Nmer_Telemetry_Record") {
            try Nmer_Telemetry_Record("health", "update_check_done", false, Map("trigger", "fallback_http_unavailable"))
        }
        return
    }
    HttpGetAsync(url, AppUpdateCheck_OnRemoteVersionFileDone, Map("timeoutMs", 8000, "receiveTimeoutMs", 8000, "tag", "app_update_raw"))
}

AppUpdateCheck_CheckNow(force := false) {
    global g_AppUpdate_CheckInFlight, g_AppUpdate_LastCheckTick, NMER_GITHUB_REPO
    if g_AppUpdate_CheckInFlight
        return
    if !force && g_AppUpdate_LastCheckTick > 0 && (A_TickCount - g_AppUpdate_LastCheckTick) < 300000
        return
    AppUpdateCheck_LoadLocalVersion()
    if !FuncExists("HttpGetAsync") {
        AppUpdateCheck_FetchRemoteVersionFile()
        return
    }
    g_AppUpdate_CheckInFlight := true
    apiUrl := "https://api.github.com/repos/" . NMER_GITHUB_REPO . "/releases/latest"
    headers := Map("Accept", "application/vnd.github+json", "User-Agent", "nmer-app-update-check")
    HttpGetAsync(apiUrl, AppUpdateCheck_OnGithubApiDone, Map(
        "timeoutMs", 10000,
        "receiveTimeoutMs", 10000,
        "headers", headers,
        "tag", "app_update_github"
    ))
}

AppUpdateCheck_DelayedFirstCheck(*) {
    AppUpdateCheck_CheckNow(false)
}

AppUpdateCheck_ScheduleStartup(*) {
    AppUpdateCheck_LoadLocalVersion()
    AppUpdateCheck_RefreshTrayTip()
    SetTimer(AppUpdateCheck_DelayedFirstCheck, -12000)
    if !g_AppUpdate_PeriodicArmed {
        global g_AppUpdate_PeriodicArmed
        g_AppUpdate_PeriodicArmed := true
        SetTimer(AppUpdateCheck_PeriodicTick, 21600000)
    }
}

AppUpdateCheck_PeriodicTick(*) {
    AppUpdateCheck_CheckNow(false)
}
