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

UserStudio_NiumaBriefPath() {
    return A_ScriptDir . "\docs\niuma-project-brief.md"
}

UserStudio_ReadTextFileMax(path, maxChars := 12000) {
    path := Trim(String(path))
    if (path = "" || !FileExist(path))
        return ""
    try {
        raw := FileRead(path, "UTF-8")
        if (StrLen(raw) > maxChars)
            return SubStr(raw, 1, maxChars) . "`n…（已截断）"
        return raw
    } catch {
        return ""
    }
}

UserStudio_ResolveInstallRoot(doc) {
    if !(doc is Map)
        doc := UserStudio_Get()
    opt := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
    root := Trim(String(opt.Get("niumaInstallRoot", "")))
    if (root != "") {
        try root := NormalizeWindowsPath(root)
        catch {
        }
        if DirExist(root)
            return root
    }
    return A_ScriptDir
}

UserStudio_BuildNiumaRuntimeBlock(doc) {
    if !(doc is Map)
        doc := UserStudio_Get()
    root := UserStudio_ResolveInstallRoot(doc)
    paths := doc.Has("paths") && doc["paths"] is Map ? doc["paths"] : Map()
    llm := doc.Has("llm") && doc["llm"] is Map ? doc["llm"] : Map()
    lines := []
    lines.Push("## 本机即时信息（自动识别，每次打开 Niuma Chat 更新）")
    lines.Push("- 软件安装根目录：" . root)
    lines.Push("- 主脚本目录（A_ScriptDir）：" . A_ScriptDir)
    lines.Push("- 用户定制配置：" . UserStudio_Path())
    lines.Push("- 当前默认 LLM：" . Trim(String(llm.Get("provider", ""))) . " / " . Trim(String(llm.Get("model", ""))))
    cp := Trim(String(paths.Get("cursor", "")))
    if (cp != "")
        lines.Push("- Cursor：" . cp)
    ah := Trim(String(paths.Get("autohotkey", "")))
    if (ah != "")
        lines.Push("- AutoHotkey：" . ah)
    py := Trim(String(paths.Get("python", "")))
    if (py != "")
        lines.Push("- Python：" . py)
    note := Trim(String(paths.Get("notes", "")))
    if (note != "")
        lines.Push("- 备注路径：" . note)
    lines.Push("")
    lines.Push("用户问「这个软件能干什么」时，指上述牛马 nmer 项目本身，不要回答泛化的 AHK 教程。")
    return Trim(lines.Join("`n"), "`n")
}

UserStudio_BuildDefaultNiumaSystemPrompt() {
    doc := UserStudio_Get()
    brief := UserStudio_ReadTextFileMax(UserStudio_NiumaBriefPath(), 9000)
    if (brief = "") {
        agents := UserStudio_ReadTextFileMax(A_ScriptDir . "\AGENTS.md", 3500)
        intro := UserStudio_ReadTextFileMax(A_ScriptDir . "\软件介绍.md", 4500)
        brief := "你是牛马 nmer（Windows 桌面效率工具）的维护与定制助手。用户通过 Niuma Chat 修改本仓库代码与配置。`n`n"
        if (agents != "")
            brief .= "--- AGENTS.md ---`n" . agents . "`n`n"
        if (intro != "")
            brief .= "--- 软件介绍 ---`n" . intro
    }
    rt := UserStudio_BuildNiumaRuntimeBlock(doc)
    if (rt != "")
        return Trim(brief . "`n`n" . rt, "`n")
    return Trim(brief)
}

UserStudio_NormalizeNiumaOptions(optIn) {
    if !(optIn is Map)
        optIn := Map()
    if !optIn.Has("niumaAutoInjectContext")
        optIn["niumaAutoInjectContext"] := true
    else
        optIn["niumaAutoInjectContext"] := !!optIn["niumaAutoInjectContext"]
    if !optIn.Has("niumaSystemPrompt")
        optIn["niumaSystemPrompt"] := ""
    else
        optIn["niumaSystemPrompt"] := Trim(String(optIn["niumaSystemPrompt"]))
    if !optIn.Has("niumaInstallRoot")
        optIn["niumaInstallRoot"] := ""
    else
        optIn["niumaInstallRoot"] := Trim(String(optIn["niumaInstallRoot"]))
    if !(optIn.Has("llmApiKeys") && optIn["llmApiKeys"] is Map)
        optIn["llmApiKeys"] := Map()
    if !(optIn.Has("llmBaseUrls") && optIn["llmBaseUrls"] is Map)
        optIn["llmBaseUrls"] := Map()
    if !(optIn.Has("llmManualBaseUrl") && optIn["llmManualBaseUrl"] is Map)
        optIn["llmManualBaseUrl"] := Map()
    if !(optIn.Has("llmModels") && optIn["llmModels"] is Map)
        optIn["llmModels"] := Map()
    if optIn.Has("llmCardProviders") && !(optIn["llmCardProviders"] is Array)
        optIn["llmCardProviders"] := []
    return optIn
}

UserStudio_BaseUrlMatchesProvider(prov, url) {
    prov := UserStudio_NormalizeLlmProvider(prov)
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
        case "openclaw":
            return true
        default:
            return true
    }
}

UserStudio_MergeLlmBaseUrls(optIn, llm) {
    if !(optIn is Map)
        optIn := Map()
    if !(llm is Map)
        return optIn
    urls := Map()
    if optIn.Has("llmBaseUrls") && optIn["llmBaseUrls"] is Map {
        for k, v in optIn["llmBaseUrls"] {
            pk := UserStudio_NormalizeLlmProvider(k)
            vu := Trim(String(v))
            if (vu != "" && UserStudio_BaseUrlMatchesProvider(pk, vu))
                urls[pk] := vu
        }
    }
    prov := UserStudio_NormalizeLlmProvider(llm.Get("provider", "openai"))
    bu := Trim(String(llm.Get("baseUrl", "")))
    if (bu != "" && UserStudio_BaseUrlMatchesProvider(prov, bu))
        urls[prov] := bu
    else if urls.Has(prov)
        llm["baseUrl"] := urls[prov]
    optIn["llmBaseUrls"] := urls
    return optIn
}

UserStudio_MergeLlmApiKeys(optIn, llm) {
    if !(optIn is Map)
        optIn := Map()
    if !(llm is Map)
        return optIn
    keys := Map()
    if optIn.Has("llmApiKeys") && optIn["llmApiKeys"] is Map {
        for k, v in optIn["llmApiKeys"] {
            pk := UserStudio_NormalizeLlmProvider(k)
            vk := UserStudio_NormalizeApiKey(v)
            if (vk != "")
                keys[pk] := vk
        }
    }
    prov := UserStudio_NormalizeLlmProvider(llm.Get("provider", "openai"))
    ak := UserStudio_NormalizeApiKey(llm.Get("apiKey", ""))
    if (ak != "")
        keys[prov] := ak
    else if keys.Has(prov)
        llm["apiKey"] := keys[prov]
    optIn["llmApiKeys"] := keys
    return optIn
}

UserStudio_LoadNiumaSystemPrompt(*) {
    doc := UserStudio_Get()
    opt := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
    opt := UserStudio_NormalizeNiumaOptions(opt)
    custom := Trim(String(opt.Get("niumaSystemPrompt", "")))
    if (custom != "")
        return custom
    return UserStudio_BuildDefaultNiumaSystemPrompt()
}

UserStudio_GetNiumaContext() {
    doc := UserStudio_Get()
    opt := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
    opt := UserStudio_NormalizeNiumaOptions(opt)
    root := UserStudio_ResolveInstallRoot(doc)
    return Map(
        "autoInject", opt["niumaAutoInjectContext"],
        "systemPrompt", UserStudio_LoadNiumaSystemPrompt(),
        "briefPath", UserStudio_NiumaBriefPath(),
        "scriptDir", A_ScriptDir,
        "installRoot", root
    )
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
        "options", Map("niumaAutoInjectContext", true, "niumaSystemPrompt", "", "niumaInstallRoot", ""),
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
    optIn := UserStudio_NormalizeNiumaOptions(optIn)
    manualMap := optIn.Has("llmManualBaseUrl") && optIn["llmManualBaseUrl"] is Map ? optIn["llmManualBaseUrl"] : Map()
    manualThis := !!manualMap.Get(prov, optIn.Get("manualBaseUrl", false))
    pre := UserStudio_LlmPresetFor(prov)
    bu := Trim(String(llm["baseUrl"]))
    if manualThis && bu != "" && UserStudio_BaseUrlMatchesProvider(prov, bu) {
        ; 保留该服务商手动指定的合法地址
    } else if !UserStudio_BaseUrlMatchesProvider(prov, bu) || !manualThis
        llm["baseUrl"] := pre.Get("baseUrl", "")
    m := Trim(String(llm["model"]))
    if (m = "")
        llm["model"] := pre.Get("model", "")
    doc["llm"] := llm
    return doc
}

UserStudio_NormalizeDoc(doc) {
    if !(doc is Map)
        doc := Map()
    llmIn := doc.Has("llm") && doc["llm"] is Map ? doc["llm"] : Map()
    pathsIn := doc.Has("paths") && doc["paths"] is Map ? doc["paths"] : Map()
    optIn := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
    cardProvidersIn := []
    hasCardProviders := false
    if optIn.Has("llmCardProviders") {
        hasCardProviders := true
        cardProvidersIn := UserStudio_NormalizeCardProviders(optIn["llmCardProviders"])
    }
    prov := UserStudio_NormalizeLlmProvider(llmIn.Get("provider", "openai"))
    if (prov = "")
        prov := "openai"
    llm := Map(
        "provider", prov,
        "apiKey", UserStudio_NormalizeApiKey(llmIn.Get("apiKey", "")),
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
    optIn := UserStudio_NormalizeNiumaOptions(optIn)
    optIn := UserStudio_MergeLlmApiKeys(optIn, llm)
    optIn := UserStudio_MergeLlmBaseUrls(optIn, llm)
    if hasCardProviders
        optIn["llmCardProviders"] := cardProvidersIn
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
        if !doc.Has("llm") || !(doc["llm"] is Map)
            doc["llm"] := Map()
        if !doc.Has("options") || !(doc["options"] is Map)
            doc["options"] := Map()
        doc["options"] := UserStudio_NormalizeNiumaOptions(doc["options"])
        llmIn := sync.Has("llm") && sync["llm"] is Map ? sync["llm"] : sync
        syncProv := UserStudio_NormalizeLlmProvider(llmIn.Get("provider", doc["llm"].Get("provider", "openai")))
        keys := doc["options"].Has("llmApiKeys") && doc["options"]["llmApiKeys"] is Map ? doc["options"]["llmApiKeys"] : Map()
        if (sync.Has("apiKeys") && sync["apiKeys"] is Map) {
            for k, v in sync["apiKeys"] {
                pk := UserStudio_NormalizeLlmProvider(k)
                vk := UserStudio_NormalizeApiKey(v)
                if (vk != "")
                    keys[pk] := vk
            }
        }
        key := UserStudio_NormalizeApiKey(llmIn.Get("apiKey", ""))
        if (key != "")
            keys[syncProv] := key
        doc["options"]["llmApiKeys"] := keys
        curProv := UserStudio_NormalizeLlmProvider(doc["llm"].Get("provider", "openai"))
        curKey := UserStudio_NormalizeApiKey(doc["llm"].Get("apiKey", ""))
        if (curKey = "" && keys.Has(curProv))
            doc["llm"]["apiKey"] := keys[curProv]
        else if (curKey = "" && keys.Has(syncProv))
            doc["llm"]["apiKey"] := keys[syncProv]
        if (doc["llm"].Get("provider", "") = "")
            doc["llm"]["provider"] := syncProv
        if (Trim(String(doc["llm"].Get("baseUrl", ""))) = "" && Trim(String(llmIn.Get("baseUrl", ""))) != "")
            doc["llm"]["baseUrl"] := Trim(String(llmIn["baseUrl"]))
        if (Trim(String(doc["llm"].Get("model", ""))) = "" && Trim(String(llmIn.Get("model", ""))) != "")
            doc["llm"]["model"] := Trim(String(llmIn["model"]))
        doc := UserStudio_NormalizeDoc(doc)
    } catch {
    }
    return doc
}

UserStudio_WriteNiumaLlmSync(docOrLlm) {
    if !(docOrLlm is Map)
        return
    llm := docOrLlm
    apiKeys := Map()
    if (docOrLlm.Has("llm") && docOrLlm["llm"] is Map)
        llm := docOrLlm["llm"]
    if (docOrLlm.Has("options") && docOrLlm["options"] is Map) {
        opt := UserStudio_NormalizeNiumaOptions(docOrLlm["options"])
        if (opt.Has("llmApiKeys") && opt["llmApiKeys"] is Map) {
            for k, v in opt["llmApiKeys"] {
                pk := UserStudio_NormalizeLlmProvider(k)
                vk := UserStudio_NormalizeApiKey(v)
                if (vk != "")
                    apiKeys[pk] := vk
            }
        }
    }
    UserStudio_EnsureConfigDir()
    key := Trim(String(llm.Get("apiKey", "")))
    if (key = "" && apiKeys.Count = 0)
        return
    if (key = "") {
        prov := UserStudio_NormalizeLlmProvider(llm.Get("provider", "openai"))
        if apiKeys.Has(prov)
            key := apiKeys[prov]
    }
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
            "apiKeys", apiKeys,
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

UserStudio_EnsureDocStructure(&doc) {
    if !(doc is Map)
        doc := Map()
    if !doc.Has("llm") || !(doc["llm"] is Map)
        doc["llm"] := Map("provider", "openai", "apiKey", "", "baseUrl", "", "model", "")
    if !doc.Has("paths") || !(doc["paths"] is Map)
        doc["paths"] := Map("cursor", "", "autohotkey", "", "everything", "", "python", "", "notes", "")
    if !doc.Has("options") || !(doc["options"] is Map)
        doc["options"] := Map()
    if !doc.Has("ttyd") || !(doc["ttyd"] is Map)
        doc["ttyd"] := Map("shell", "cmd.exe", "workDir", "", "port", 7691)
    doc["options"] := UserStudio_NormalizeNiumaOptions(doc["options"])
}

UserStudio_CoerceWebMap(val) {
    if (val is String) {
        s := Trim(String(val))
        if (s != "") {
            try {
                parsed := Jxon_Load(s)
                if (parsed is Map)
                    return parsed
            } catch {
            }
        }
        return Map()
    }
    if (val is Map)
        return val
    return Map()
}

UserStudio_CoerceWebPayload(&payload) {
    if !(payload is Map) {
        if (payload is String) {
            s := Trim(String(payload))
            if (s != "")
                try payload := Jxon_Load(s)
        }
        if !(payload is Map)
            payload := Map()
    }
    if payload.Has("llm")
        payload["llm"] := UserStudio_CoerceWebMap(payload["llm"])
    if payload.Has("options")
        payload["options"] := UserStudio_CoerceWebMap(payload["options"])
    if payload.Has("paths")
        payload["paths"] := UserStudio_CoerceWebMap(payload["paths"])
    opt := payload.Has("options") && payload["options"] is Map ? payload["options"] : Map()
    if opt.Has("llmApiKeys") && !(opt["llmApiKeys"] is Map)
        opt["llmApiKeys"] := UserStudio_CoerceWebMap(opt["llmApiKeys"])
    if opt.Has("llmBaseUrls") && !(opt["llmBaseUrls"] is Map)
        opt["llmBaseUrls"] := UserStudio_CoerceWebMap(opt["llmBaseUrls"])
    if opt.Has("llmModels") && !(opt["llmModels"] is Map)
        opt["llmModels"] := UserStudio_CoerceWebMap(opt["llmModels"])
    payload["options"] := opt
}

UserStudio_NormalizeCardProviders(raw) {
    cards := []
    if (raw is Array) {
        for _, p in raw {
            pv := UserStudio_NormalizeLlmProvider(p)
            if (pv != "")
                cards.Push(pv)
        }
        return cards
    }
    if (raw is String) {
        s := Trim(String(raw))
        if (s != "") {
            try {
                parsed := Jxon_Load(s)
                if (parsed is Array) {
                    for _, p in parsed {
                        pv := UserStudio_NormalizeLlmProvider(p)
                        if (pv != "")
                            cards.Push(pv)
                    }
                }
            } catch {
            }
        }
    }
    return cards
}

UserStudio_MergePayloadLlmApiKeys(mergedOpt, optPayload, llmPayload) {
    if !(mergedOpt is Map)
        mergedOpt := Map()
    keys := mergedOpt.Has("llmApiKeys") && mergedOpt["llmApiKeys"] is Map ? mergedOpt["llmApiKeys"].Clone() : Map()
    if (optPayload is Map) && optPayload.Has("llmApiKeys") && optPayload["llmApiKeys"] is Map {
        for k, v in optPayload["llmApiKeys"] {
            pk := UserStudio_NormalizeLlmProvider(k)
            vk := UserStudio_NormalizeApiKey(v)
            if (vk != "")
                keys[pk] := vk
        }
    }
    if (llmPayload is Map) {
        prov := UserStudio_NormalizeLlmProvider(llmPayload.Get("provider", mergedOpt.Get("provider", "openai")))
        ak := UserStudio_NormalizeApiKey(llmPayload.Get("apiKey", ""))
        if (ak != "")
            keys[prov] := ak
    }
    mergedOpt["llmApiKeys"] := keys
    return mergedOpt
}

UserStudio_PickDisplayApiKey(doc) {
    if !(doc is Map)
        return ""
    llm := doc.Has("llm") && doc["llm"] is Map ? doc["llm"] : Map()
    prov := UserStudio_NormalizeLlmProvider(llm.Get("provider", "openai"))
    ak := UserStudio_NormalizeApiKey(llm.Get("apiKey", ""))
    if (ak != "")
        return ak
    opt := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
    if opt.Has("llmApiKeys") && opt["llmApiKeys"] is Map && opt["llmApiKeys"].Has(prov)
        return UserStudio_NormalizeApiKey(opt["llmApiKeys"][prov])
    return ""
}

UserStudio_ApplyLlmCardsFlat(msg) {
    if !(msg is Map)
        throw Error("无效的大模型卡片数据")
    doc := UserStudio_Get()
    UserStudio_EnsureDocStructure(&doc)
    cards := []
    cardsRaw := Trim(String(msg.Get("cards", "")))
    if (cardsRaw = "__empty__") {
        cards := []
    } else if (cardsRaw != "") {
        for _, part in StrSplit(cardsRaw, ",") {
            p := UserStudio_NormalizeLlmProvider(Trim(part))
            if (p != "")
                cards.Push(p)
        }
    }
    doc["options"]["llmCardProviders"] := cards
    keysJson := Trim(String(msg.Get("keysJson", "")))
    if (keysJson != "") {
        try {
            keysParsed := Jxon_Load(keysJson)
            if (keysParsed is Map) {
                keys := Map()
                for k, v in keysParsed {
                    pk := UserStudio_NormalizeLlmProvider(k)
                    vk := UserStudio_NormalizeApiKey(v)
                    if (vk != "")
                        keys[pk] := vk
                }
                doc["options"]["llmApiKeys"] := keys
            }
        } catch {
        }
    }
    modelsJson := Trim(String(msg.Get("modelsJson", "")))
    if (modelsJson != "") {
        try {
            modelsParsed := Jxon_Load(modelsJson)
            if (modelsParsed is Map) {
                models := Map()
                for k, v in modelsParsed {
                    pk := UserStudio_NormalizeLlmProvider(k)
                    mv := Trim(String(v))
                    if (mv != "")
                        models[pk] := mv
                }
                doc["options"]["llmModels"] := models
            }
        } catch {
        }
    }
    prov := UserStudio_NormalizeLlmProvider(msg.Get("llmProvider", doc["llm"].Get("provider", "openai")))
    doc["llm"]["provider"] := prov
    ak := UserStudio_NormalizeApiKey(msg.Get("llmApiKey", ""))
    doc["llm"]["apiKey"] := ak
    bu := Trim(String(msg.Get("llmBaseUrl", "")))
    if (bu != "")
        doc["llm"]["baseUrl"] := bu
    mo := Trim(String(msg.Get("llmModel", "")))
    if (mo != "")
        doc["llm"]["model"] := mo
    doc["options"] := UserStudio_MergeLlmApiKeys(doc["options"], doc["llm"])
    doc := UserStudio_NormalizeDoc(doc)
    UserStudio_Save(doc)
    try UserStudio_WriteNiumaLlmSync(doc)
    catch {
    }
    return doc
}

UserStudio_ApplyFromWebPayload(payload) {
    if !(payload is Map)
        throw Error("定制数据无效")
    UserStudio_CoerceWebPayload(&payload)
    cur := UserStudio_Get()
    UserStudio_EnsureDocStructure(&cur)
    llmPayload := payload.Has("llm") && payload["llm"] is Map ? payload["llm"] : Map()
    if (llmPayload.Count > 0) {
        for k, v in llmPayload
            cur["llm"][k] := v
    }
    if payload.Has("paths") && payload["paths"] is Map {
        for k, v in payload["paths"]
            cur["paths"][k] := Trim(String(v))
    }
    if payload.Has("options") && payload["options"] is Map {
        merged := cur["options"].Clone()
        optPayload := payload["options"]
        merged := UserStudio_MergePayloadLlmApiKeys(merged, optPayload, llmPayload)
        if optPayload.Has("llmBaseUrls") && optPayload["llmBaseUrls"] is Map {
            urls := merged.Has("llmBaseUrls") && merged["llmBaseUrls"] is Map ? merged["llmBaseUrls"].Clone() : Map()
            for k, v in optPayload["llmBaseUrls"] {
                pk := UserStudio_NormalizeLlmProvider(k)
                vu := Trim(String(v))
                if (vu != "" && UserStudio_BaseUrlMatchesProvider(pk, vu))
                    urls[pk] := vu
            }
            merged["llmBaseUrls"] := urls
        }
        if optPayload.Has("llmModels") && optPayload["llmModels"] is Map {
            models := merged.Has("llmModels") && merged["llmModels"] is Map ? merged["llmModels"].Clone() : Map()
            for k, v in optPayload["llmModels"] {
                pk := UserStudio_NormalizeLlmProvider(k)
                mv := Trim(String(v))
                if (mv != "")
                    models[pk] := mv
            }
            merged["llmModels"] := models
        }
        if optPayload.Has("llmCardProviders")
            merged["llmCardProviders"] := UserStudio_NormalizeCardProviders(optPayload["llmCardProviders"])
        for k, v in optPayload {
            if (k = "llmApiKeys" || k = "llmBaseUrls" || k = "llmModels" || k = "llmCardProviders")
                continue
            merged[k] := v
        }
        cur["options"] := UserStudio_NormalizeNiumaOptions(merged)
    } else if (llmPayload.Count > 0) {
        merged := cur["options"].Clone()
        cur["options"] := UserStudio_MergePayloadLlmApiKeys(merged, Map(), llmPayload)
    }
    if payload.Has("llmApiKeys") && payload["llmApiKeys"] is Map {
        merged := cur["options"].Clone()
        cur["options"] := UserStudio_MergePayloadLlmApiKeys(merged, Map("llmApiKeys", payload["llmApiKeys"]), llmPayload)
    }
    if payload.Has("ttyd") && payload["ttyd"] is Map {
        for k, v in payload["ttyd"]
            cur["ttyd"][k] := v
    }
    cur["options"] := UserStudio_MergeLlmApiKeys(cur["options"], cur["llm"])
    cur := UserStudio_NormalizeDoc(cur)
    UserStudio_Save(cur)
    try UserStudio_WriteNiumaLlmSync(cur)
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
        "llmKeyMasked", UserStudio_MaskApiKey(UserStudio_PickDisplayApiKey(doc)),
        "llmConfigured", Trim(String(UserStudio_PickDisplayApiKey(doc))) != "",
        "modules", modules
    )
}

UserStudio_PayloadForWeb() {
    doc := UserStudio_Get()
    llm := doc["llm"]
    opt := doc.Has("options") && doc["options"] is Map ? doc["options"] : Map()
    keysOut := Map()
    if opt.Has("llmApiKeys") && opt["llmApiKeys"] is Map {
        for k, v in opt["llmApiKeys"] {
            pk := UserStudio_NormalizeLlmProvider(k)
            vk := UserStudio_NormalizeApiKey(v)
            if (vk != "")
                keysOut[pk] := vk
        }
    }
    prov := UserStudio_NormalizeLlmProvider(llm.Get("provider", "openai"))
    ak := UserStudio_NormalizeApiKey(llm.Get("apiKey", ""))
    if (ak = "" && keysOut.Has(prov))
        ak := keysOut[prov]
    optOut := opt.Clone()
    optOut["llmApiKeys"] := keysOut
    modelsOut := Map()
    if opt.Has("llmModels") && opt["llmModels"] is Map {
        for k, v in opt["llmModels"] {
            pk := UserStudio_NormalizeLlmProvider(k)
            mv := Trim(String(v))
            if (mv != "")
                modelsOut[pk] := mv
        }
    }
    optOut["llmModels"] := modelsOut
    if opt.Has("llmCardProviders") && opt["llmCardProviders"] is Array {
        cardProviders := []
        seen := Map()
        for _, p in opt["llmCardProviders"] {
            pv := UserStudio_NormalizeLlmProvider(p)
            if (pv != "" && !seen.Has(pv)) {
                seen[pv] := true
                cardProviders.Push(pv)
            }
        }
        optOut["llmCardProviders"] := cardProviders
    }
    return Map(
        "version", doc["version"],
        "updatedAt", doc["updatedAt"],
        "llm", Map(
            "provider", llm["provider"],
            "apiKey", ak,
            "baseUrl", llm["baseUrl"],
            "model", llm["model"]
        ),
        "paths", doc["paths"],
        "ttyd", UserStudio_TtydPayloadForWeb(),
        "options", optOut,
        "niumaContext", UserStudio_GetNiumaContext(),
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

UserStudio_NormalizeApiKey(key) {
    if FuncExists("LlmApiPing_NormalizeApiKey")
        return LlmApiPing_NormalizeApiKey(key)
    if FuncExists("ConfigWebView_NormalizeApiKey")
        return ConfigWebView_NormalizeApiKey(key)
    return Trim(String(key))
}

UserStudio_TestLlmPing(llm, timeoutMs := 18000) {
    if FuncExists("ConfigWebView_TestMinimaxPing") && (llm is Map) {
        prov := UserStudio_NormalizeLlmProvider(llm.Get("provider", "openai"))
        if (prov = "minimax")
            return ConfigWebView_TestMinimaxPing(UserStudio_NormalizeApiKey(llm.Get("apiKey", "")), llm.Get("baseUrl", ""), llm.Get("model", ""), timeoutMs)
    }
    if FuncExists("LlmApiPing_Test")
        return LlmApiPing_Test(llm, timeoutMs)
    return Map("ok", false, "error", "LlmApiPing 模块未加载，请重载牛马主程序", "elapsedMs", 0)
}
