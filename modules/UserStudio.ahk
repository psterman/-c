; UserStudio.ahk — 智能定制：大模型 API、软件路径、总览与还原（config/user_studio.json）

global g_UserStudio := Map()
global g_UserStudioLoaded := false

UserStudio_ConfigDir() {
    return A_ScriptDir . "\config"
}

UserStudio_Path() {
    return UserStudio_ConfigDir() . "\user_studio.json"
}

UserStudio_DefaultsPath() {
    return UserStudio_ConfigDir() . "\user_studio.defaults.json"
}

UserStudio_BackupPath() {
    return UserStudio_ConfigDir() . "\user_studio.backup.json"
}

UserStudio_NiumaLlmSyncPath() {
    return UserStudio_ConfigDir() . "\niuma_chat_llm.json"
}

UserStudio_EnsureConfigDir() {
    dir := UserStudio_ConfigDir()
    if !DirExist(dir)
        DirCreate(dir)
}

UserStudio_DefaultDocument() {
    defPath := UserStudio_DefaultsPath()
    if FileExist(defPath) {
        try {
            raw := FileRead(defPath, "UTF-8")
            parsed := Jxon_Load(raw)
            if (parsed is Map)
                return UserStudio_NormalizeDoc(parsed)
        } catch {
        }
    }
    return UserStudio_NormalizeDoc(Map(
        "version", 1,
        "llm", Map("provider", "openai", "apiKey", "", "baseUrl", "https://api.openai.com/v1", "model", "gpt-4o-mini"),
        "paths", Map("cursor", "", "autohotkey", "", "everything", "", "python", "", "notes", ""),
        "ttyd", Map("shell", "cmd.exe", "workDir", "", "port", 7691),
        "options", Map(),
        "updatedAt", ""
    ))
}

UserStudio_NormalizeLlmProvider(prov) {
    prov := Trim(String(prov))
    if (prov = "anthropic")
        return "claude"
    if (prov = "codex")
        return "openai"
    return prov
}

; 各服务商官方默认接口（baseUrl 留空时由系统自动补全）
UserStudio_LlmPresetFor(prov) {
    prov := UserStudio_NormalizeLlmProvider(prov)
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
        case "qwen":
            return Map("baseUrl", "https://dashscope.aliyuncs.com/compatible-mode/v1", "model", "qwen-plus")
        case "glm", "zhipu":
            return Map("baseUrl", "https://open.bigmodel.cn/api/paas/v4", "model", "glm-4-plus")
        case "siliconflow":
            return Map("baseUrl", "https://api.siliconflow.cn/v1", "model", "Qwen/Qwen2.5-7B-Instruct")
        case "ollama":
            return Map("baseUrl", "http://127.0.0.1:11434/v1", "model", "llama3.1:8b")
        case "openclaw":
            return Map("baseUrl", "http://127.0.0.1:18789", "model", "gateway")
        case "custom":
            return Map("baseUrl", "", "model", "")
        default:
            return Map("baseUrl", "https://api.openai.com/v1", "model", "gpt-4o-mini")
    }
}

UserStudio_ApplyLlmAutoDefaults(doc) {
    if !(doc is Map)
        return doc
    if !(doc.Has("llm") && doc["llm"] is Map)
        return doc
    llm := doc["llm"]
    prov := UserStudio_NormalizeLlmProvider(llm["provider"])
    llm["provider"] := prov
    if (prov = "custom")
        return doc
    optIn := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
    if optIn.Get("manualBaseUrl", false)
        return doc
    pre := UserStudio_LlmPresetFor(prov)
    llm["baseUrl"] := pre.Get("baseUrl", "")
    m := Trim(String(llm["model"]))
    if (m = "")
        llm["model"] := pre.Get("model", "")
    else if (prov = "kimi" && RegExMatch(m, "i)^moonshot-v1"))
        llm["model"] := pre.Get("model", "kimi-k2.6")
    doc["llm"] := llm
    return doc
}

UserStudio_NormalizeDoc(doc) {
    if !(doc is Map)
        doc := Map()
    llmIn := doc.Has("llm") && doc["llm"] is Map ? doc["llm"] : Map()
    pathsIn := doc.Has("paths") && doc["paths"] is Map ? doc["paths"] : Map()
    optIn := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
    prov := UserStudio_NormalizeLlmProvider(llmIn.Get("provider", "openai"))
    if (prov = "")
        prov := "openai"
    llm := Map(
        "provider", prov,
        "apiKey", Trim(String(llmIn.Get("apiKey", ""))),
        "baseUrl", Trim(String(llmIn.Get("baseUrl", ""))),
        "model", Trim(String(llmIn.Get("model", "")))
    )
    paths := Map(
        "cursor", Trim(String(pathsIn.Get("cursor", ""))),
        "autohotkey", Trim(String(pathsIn.Get("autohotkey", ""))),
        "everything", Trim(String(pathsIn.Get("everything", ""))),
        "python", Trim(String(pathsIn.Get("python", ""))),
        "notes", Trim(String(pathsIn.Get("notes", "")))
    )
    ttydIn := doc.Has("ttyd") && doc["ttyd"] is Map ? doc["ttyd"] : Map()
    sh := Trim(String(ttydIn.Get("shell", "cmd.exe")))
    if (sh = "")
        sh := "cmd.exe"
    wd := Trim(String(ttydIn.Get("workDir", "")))
    tp := Integer(ttydIn.Get("port", 7691))
    if (tp < 1024 || tp > 65535)
        tp := 7691
    ttyd := Map("shell", sh, "workDir", wd, "port", tp)
    return UserStudio_ApplyLlmAutoDefaults(Map(
        "version", Integer(doc.Get("version", 1)),
        "llm", llm,
        "paths", paths,
        "ttyd", ttyd,
        "options", optIn,
        "updatedAt", Trim(String(doc.Get("updatedAt", "")))
    ))
}

UserStudio_MergeWithRuntimePaths(doc) {
    global CursorPath, ConfigFile
    doc := UserStudio_NormalizeDoc(doc)
    paths := doc["paths"]
    if (paths["cursor"] = "" && IsSet(CursorPath) && CursorPath != "")
        paths["cursor"] := CursorPath
    if (paths["autohotkey"] = "") {
        try paths["autohotkey"] := A_AhkPath
        catch {
        }
    }
    doc["paths"] := paths
    return doc
}

UserStudio_Load(*) {
    global g_UserStudio, g_UserStudioLoaded
    UserStudio_EnsureConfigDir()
    path := UserStudio_Path()
    doc := UserStudio_DefaultDocument()
    if FileExist(path) {
        try {
            raw := FileRead(path, "UTF-8")
            parsed := Jxon_Load(raw)
            if (parsed is Map)
                doc := UserStudio_NormalizeDoc(parsed)
        } catch as e {
            OutputDebug("[UserStudio] load failed: " . e.Message)
        }
    } else {
        try UserStudio_Save(doc)
        catch {
        }
    }
    doc := UserStudio_MergeWithRuntimePaths(doc)
    doc := UserStudio_MergeLlmFromNiumaSync(doc)
    g_UserStudio := doc
    g_UserStudioLoaded := true
    return doc
}

; 从 niuma_chat_llm.json 合并到内存；若新读到 Key 则写回 user_studio.json
UserStudio_SyncFromNiumaFile(*) {
    doc := UserStudio_Load()
    keyBefore := Trim(String(doc["llm"].Get("apiKey", "")))
    doc := UserStudio_MergeLlmFromNiumaSync(doc)
    keyAfter := Trim(String(doc["llm"].Get("apiKey", "")))
    if (keyAfter != "" && keyAfter != keyBefore) {
        try UserStudio_Save(doc)
        catch {
        }
    } else if (keyAfter != "") {
        global g_UserStudio
        g_UserStudio := doc
    }
    ok := (keyAfter != "")
    err := ok ? "" : "未找到 API Key（请先在 Niuma Chat 设置中保存，或点「从 Niuma Chat 同步 API」）"
    return Map("ok", ok, "error", err, "studio", UserStudio_PayloadForWeb())
}

UserStudio_MergeLlmFromNiumaSync(doc) {
    path := UserStudio_NiumaLlmSyncPath()
    if !FileExist(path)
        return doc
    try {
        raw := FileRead(path, "UTF-8")
        sync := Jxon_Load(raw)
        if !(sync is Map)
            return doc
        llmIn := sync.Has("llm") && sync["llm"] is Map ? sync["llm"] : sync
        key := Trim(String(llmIn.Get("apiKey", "")))
        if (key = "")
            return doc
        if !doc.Has("llm") || !(doc["llm"] is Map)
            doc["llm"] := Map()
        doc["llm"]["apiKey"] := key
        if Trim(String(llmIn.Get("provider", ""))) != ""
            doc["llm"]["provider"] := Trim(String(llmIn["provider"]))
        if Trim(String(llmIn.Get("baseUrl", ""))) != ""
            doc["llm"]["baseUrl"] := Trim(String(llmIn["baseUrl"]))
        if Trim(String(llmIn.Get("model", ""))) != ""
            doc["llm"]["model"] := Trim(String(llmIn["model"]))
        doc := UserStudio_NormalizeDoc(doc)
    } catch {
    }
    return doc
}

UserStudio_WriteNiumaLlmSync(llm) {
    if !(llm is Map)
        return
    UserStudio_EnsureConfigDir()
    key := Trim(String(llm.Get("apiKey", "")))
    if (key = "")
        return
    try {
        f := FileOpen(UserStudio_NiumaLlmSyncPath(), "w", "UTF-8")
        if !f
            return
        f.Write(Jxon_Dump(Map(
            "llm", Map(
                "provider", llm.Get("provider", "openai"),
                "apiKey", key,
                "baseUrl", llm.Get("baseUrl", ""),
                "model", llm.Get("model", "")
            ),
            "updatedAt", FormatTime(, "yyyy-MM-dd HH:mm:ss")
        )))
        f.Close()
    } catch {
    }
}

UserStudio_Get() {
    global g_UserStudio, g_UserStudioLoaded
    if !g_UserStudioLoaded
        return UserStudio_Load()
    return g_UserStudio
}

UserStudio_Save(doc) {
    global g_UserStudio, g_UserStudioLoaded
    UserStudio_EnsureConfigDir()
    doc := UserStudio_NormalizeDoc(doc)
    doc["updatedAt"] := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    path := UserStudio_Path()
    try {
        if FileExist(path)
            FileCopy(path, UserStudio_BackupPath(), 1)
    } catch {
    }
    f := FileOpen(path, "w", "UTF-8")
    if !f
        throw Error("无法写入 " . path)
    f.Write(Jxon_Dump(doc))
    f.Close()
    g_UserStudio := doc
    g_UserStudioLoaded := true
    return doc
}

UserStudio_RestoreDefaults(*) {
    doc := UserStudio_DefaultDocument()
    try UserStudio_Save(doc)
    catch as e {
        return Map("ok", false, "error", e.Message)
    }
    try UserStudio_ApplyPathsToGlobals(doc)
    catch {
    }
    try UserStudio_SyncTtydToIni(doc)
    catch {
    }
    return Map("ok", true, "error", "", "studio", doc)
}

UserStudio_ExportTo(path) {
    src := UserStudio_Path()
    if !FileExist(src)
        UserStudio_Load()
    try {
        FileCopy(src, path, 1)
        return Map("ok", true, "error", "")
    } catch as e {
        return Map("ok", false, "error", e.Message)
    }
}

UserStudio_ImportFrom(path) {
    if !FileExist(path)
        return Map("ok", false, "error", "文件不存在")
    try {
        raw := FileRead(path, "UTF-8")
        parsed := Jxon_Load(raw)
        if !(parsed is Map)
            return Map("ok", false, "error", "JSON 格式无效")
        doc := UserStudio_NormalizeDoc(parsed)
        UserStudio_Save(doc)
        UserStudio_ApplyPathsToGlobals(doc)
        try UserStudio_SyncTtydToIni(doc)
        catch {
        }
        return Map("ok", true, "error", "", "studio", doc)
    } catch as e {
        return Map("ok", false, "error", e.Message)
    }
}

UserStudio_ApplyPathsToGlobals(doc) {
    global CursorPath, ConfigFile
    if !(doc is Map)
        return
    paths := doc.Has("paths") && doc["paths"] is Map ? doc["paths"] : Map()
    cp := Trim(String(paths.Get("cursor", "")))
    if (cp != "") {
        try cp := NormalizeWindowsPath(cp)
        catch {
        }
        if FileExist(cp) {
            CursorPath := cp
            if (IsSet(ConfigFile) && ConfigFile != "")
                IniWrite(CursorPath, ConfigFile, "Settings", "CursorPath")
        }
    }
}

UserStudio_ApplyFromWebPayload(payload) {
    if !(payload is Map)
        throw Error("定制数据无效")
    cur := UserStudio_Get()
    if payload.Has("llm") && payload["llm"] is Map {
        for k, v in payload["llm"]
            cur["llm"][k] := v
    }
    if payload.Has("paths") && payload["paths"] is Map {
        for k, v in payload["paths"]
            cur["paths"][k] := Trim(String(v))
    }
    if payload.Has("options") && payload["options"] is Map
        cur["options"] := payload["options"]
    if payload.Has("ttyd") && payload["ttyd"] is Map {
        for k, v in payload["ttyd"]
            cur["ttyd"][k] := v
    }
    cur := UserStudio_NormalizeDoc(cur)
    UserStudio_Save(cur)
    try UserStudio_WriteNiumaLlmSync(cur["llm"])
    catch {
    }
    UserStudio_ApplyPathsToGlobals(cur)
    try UserStudio_SyncTtydToIni(cur)
    catch {
    }
    return cur
}

UserStudio_GetTtydShell() {
    doc := UserStudio_Get()
    ttyd := doc.Has("ttyd") && doc["ttyd"] is Map ? doc["ttyd"] : Map()
    sh := Trim(String(ttyd.Get("shell", "cmd.exe")))
    if (sh = "")
        sh := "cmd.exe"
    if (StrLen(sh) > 1200)
        sh := "cmd.exe"
    return sh
}

UserStudio_GetTtydWorkDir() {
    doc := UserStudio_Get()
    ttyd := doc.Has("ttyd") && doc["ttyd"] is Map ? doc["ttyd"] : Map()
    wd := Trim(String(ttyd.Get("workDir", "")))
    if (wd != "") {
        try {
            if DirExist(wd)
                return wd
        } catch {
        }
    }
    if FuncExists("NiumaTtyd_WorkDir")
        return NiumaTtyd_WorkDir()
    return A_ScriptDir
}

UserStudio_SyncTtydToIni(doc) {
    global ConfigFile
    if !(doc is Map)
        return
    ttyd := doc.Has("ttyd") && doc["ttyd"] is Map ? doc["ttyd"] : Map()
    sh := Trim(String(ttyd.Get("shell", "cmd.exe")))
    if (sh = "")
        sh := "cmd.exe"
    cf := A_ScriptDir . "\CursorShortcut.ini"
    if (IsSet(ConfigFile) && ConfigFile != "")
        cf := ConfigFile
    try {
        IniWrite(sh, cf, "NiumaTtyd", "studio_cli_ttyd_shell")
        IniWrite(sh, cf, "NiumaTtyd", "studio_cli_shell")
        IniWrite(String(Integer(ttyd.Get("port", 7691))), cf, "NiumaTtyd", "studio_cli_port")
        wd := Trim(String(ttyd.Get("workDir", "")))
        IniWrite(wd, cf, "NiumaTtyd", "studio_cli_workdir")
    } catch {
    }
}

UserStudio_TtydPayloadForWeb() {
    doc := UserStudio_Get()
    ttyd := doc.Has("ttyd") && doc["ttyd"] is Map ? doc["ttyd"] : Map()
    port := Integer(ttyd.Get("port", 7691))
    if (port < 1024 || port > 65535)
        port := 7691
    baseUrl := "http://127.0.0.1:" . port . "/"
    if FuncExists("NiumaTtyd_BaseUrlForEngine")
        baseUrl := NiumaTtyd_BaseUrlForEngine("studio_cli")
    exeOk := false
    if FuncExists("NiumaTtyd_ExePath")
        exeOk := FileExist(NiumaTtyd_ExePath())
    httpOk := false
    if FuncExists("NiumaTtyd_IsHttpReadyOnPort")
        try httpOk := NiumaTtyd_IsHttpReadyOnPort(port, 400)
    return Map(
        "shell", ttyd.Get("shell", "cmd.exe"),
        "workDir", ttyd.Get("workDir", ""),
        "port", port,
        "baseUrl", baseUrl,
        "exeExists", exeOk,
        "httpReady", httpOk
    )
}

UserStudio_MaskApiKey(key) {
    k := Trim(String(key))
    if (k = "")
        return ""
    if (StrLen(k) <= 8)
        return "********"
    return SubStr(k, 1, 4) . "…" . SubStr(k, -4)
}

UserStudio_PathStatus(path) {
    p := Trim(String(path))
    if (p = "")
        return Map("set", false, "exists", false, "label", "未填写")
    ex := false
    try ex := !!FileExist(p)
    catch {
        ex := false
    }
    return Map("set", true, "exists", ex, "label", ex ? "已找到" : "路径无效")
}

UserStudio_BuildOverview() {
    global ConfigFile, CursorPath, AppearanceActivationMode, Language, ThemeMode
    doc := UserStudio_Get()
    paths := doc["paths"]
    llm := doc["llm"]
    modules := []
    modules.Push(Map("id", "config", "name", "设置中心 WebView", "on", true))
    modules.Push(Map("id", "search", "name", "搜索中心", "on", FuncExists("SCWV_Show")))
    modules.Push(Map("id", "hole", "name", "文本黑洞", "on", FuncExists("GDHO_IsDecoupledTopologyEnabled")))
    modules.Push(Map("id", "vk", "name", "虚拟键盘 KeyBinder", "on", FuncExists("VK_Show")))
    modules.Push(Map("id", "clipboard", "name", "剪贴板面板", "on", FuncExists("ShowClipboardManager")))
    modules.Push(Map("id", "pqp", "name", "Prompt Quick-Pad", "on", FuncExists("PromptQuickPad_Show")))
    act := "toolbar"
    try act := NormalizeAppearanceActivationMode(AppearanceActivationMode)
    catch {
    }
    return Map(
        "appName", "牛马 nmer",
        "ahkVersion", A_AhkVersion,
        "scriptDir", A_ScriptDir,
        "configFile", IsSet(ConfigFile) ? ConfigFile : "",
        "studioPath", UserStudio_Path(),
        "studioUpdatedAt", doc.Has("updatedAt") ? doc["updatedAt"] : "",
        "language", IsSet(Language) ? Language : "zh",
        "themeMode", IsSet(ThemeMode) ? ThemeMode : "dark",
        "activationMode", act,
        "cursorPathIni", IsSet(CursorPath) ? CursorPath : "",
        "pathStatus", Map(
            "cursor", UserStudio_PathStatus(paths.Get("cursor", "")),
            "autohotkey", UserStudio_PathStatus(paths.Get("autohotkey", "")),
            "everything", UserStudio_PathStatus(paths.Get("everything", "")),
            "python", UserStudio_PathStatus(paths.Get("python", ""))
        ),
        "llmProvider", llm.Get("provider", ""),
        "llmModel", llm.Get("model", ""),
        "llmKeyMasked", UserStudio_MaskApiKey(llm.Get("apiKey", "")),
        "llmConfigured", Trim(String(llm.Get("apiKey", ""))) != "",
        "modules", modules
    )
}

UserStudio_PayloadForWeb() {
    doc := UserStudio_Get()
    llm := doc["llm"]
    return Map(
        "version", doc["version"],
        "updatedAt", doc["updatedAt"],
        "llm", Map(
            "provider", llm["provider"],
            "apiKey", llm["apiKey"],
            "baseUrl", llm["baseUrl"],
            "model", llm["model"]
        ),
        "paths", doc["paths"],
        "ttyd", UserStudio_TtydPayloadForWeb(),
        "options", doc["options"],
        "overview", UserStudio_BuildOverview()
    )
}

UserStudio_BrowsePath(field, filterDesc := "可执行文件 (*.exe)") {
    field := Trim(String(field))
    doc := UserStudio_Get()
    paths := doc["paths"]
    start := ""
    if (field != "" && paths.Has(field))
        start := paths[field]
    if (start = "" || !FileExist(start))
        start := A_ScriptDir
    selected := ""
    try {
        if (field = "ttydWorkDir") {
        selected := FileSelect("D", start, "选择终端工作目录")
        if (selected = "")
            return ""
        return selected
    }
    if (field = "python")
            selected := FileSelect("1", start, "选择 Python", "Python (python.exe)")
        else if (field = "everything")
            selected := FileSelect("1", start, "选择 Everything", "Executable (*.exe)")
        else
            selected := FileSelect("1", start, "选择程序", filterDesc)
    } catch {
        selected := ""
    }
    if (selected = "")
        return ""
    try selected := NormalizeWindowsPath(selected)
    catch {
    }
    return selected
}
