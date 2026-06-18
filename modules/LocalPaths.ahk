; LocalPaths.ahk — 用户私有数据目录（API Key、主配置、OpenClaw 状态）

Nmer_RepoRoot(*) {
    try {
        r := Trim(EnvGet("NMRE_ROOT"))
        if (r != "")
            return RTrim(r, "\/")
    }
    return A_ScriptDir
}

Nmer_LocalDir(*) {
    return Nmer_RepoRoot() . "\local"
}

Nmer_EnsureLocalDir(*) {
    dir := Nmer_LocalDir()
    if !DirExist(dir)
        try DirCreate(dir)
    return dir
}

Nmer_MainConfigFile(*) {
    return Nmer_LocalDir() . "\CursorShortcut.ini"
}

Nmer_PromptTemplatesFile(*) {
    return Nmer_LocalDir() . "\PromptTemplates.ini"
}

Nmer_OpenClawStateDir(*) {
    return Nmer_LocalDir() . "\openclaw-state"
}

Nmer_UserStudioPath(*) {
    return Nmer_LocalDir() . "\user_studio.json"
}

Nmer_UserStudioBackupPath(*) {
    return Nmer_LocalDir() . "\user_studio.backup.json"
}

Nmer_NiumaChatLlmPath(*) {
    return Nmer_LocalDir() . "\niuma_chat_llm.json"
}

Nmer_ResolveConfigFile(*) {
    try {
        if IsSet(ConfigFile) && ConfigFile != ""
            return ConfigFile
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
    return Nmer_MainConfigFile()
}

Nmer_ResolvePromptTemplatesFile(*) {
    try {
        if IsSet(PromptTemplatesFile) && PromptTemplatesFile != ""
            return PromptTemplatesFile
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
    return Nmer_PromptTemplatesFile()
}

; ---------- 用户数据目录 Data/（持久化：库 / 搜索配置 / 状态 / 词典 / 运行时）----------
;   db/       SQLite（剪贴板、Grounding 等）
;   dict/     离线词典库（ultimate / ecdict / stardict）
;   search/   搜索与全文索引配置
;   state/    提示词、命令面板状态等 JSON
;   runtime/  niuma-chat、app、log 等运行态目录
; 可重建的大文件在 Cache/（见 Nmer_UserCacheRoot）

Nmer_DataDir(*) {
    return Nmer_RepoRoot() . "\Data"
}

Nmer_EnsureDataDir(*) {
    dir := Nmer_DataDir()
    if !DirExist(dir)
        try DirCreate(dir)
    return dir
}

Nmer_DataSubDir(name) {
    dir := Nmer_DataDir() . "\" . name
    if !DirExist(dir)
        try DirCreate(dir)
    return dir
}

Nmer_DataDbDir(*) {
    return Nmer_DataSubDir("db")
}

Nmer_DataDictDir(*) {
    return Nmer_DataSubDir("dict")
}

Nmer_DataSearchDir(*) {
    return Nmer_DataSubDir("search")
}

Nmer_DataStateDir(*) {
    return Nmer_DataSubDir("state")
}

Nmer_DataRuntimeDir(*) {
    return Nmer_DataSubDir("runtime")
}

Nmer_DataStatePath(fileName) {
    return Nmer_DataStateDir() . "\" . fileName
}

Nmer_ClipboardFts5DbPath(*) {
    return Nmer_DataDbDir() . "\Clipboard.db"
}

Nmer_CursorDataDbPath(*) {
    return Nmer_DataDbDir() . "\CursorData.db"
}

Nmer_SearchCenterHistoryPath(*) {
    return Nmer_DataSearchDir() . "\SearchCenterHistory.json"
}

Nmer_ScWebLlmStatePath(*) {
    dir := Nmer_DataRuntimeDir() . "\app"
    if !DirExist(dir)
        try DirCreate(dir)
    return dir . "\search_center_web_llm_state.json"
}

Nmer_SearchCenterSessionPath(*) {
    dir := Nmer_DataRuntimeDir() . "\app"
    if !DirExist(dir)
        try DirCreate(dir)
    return dir . "\search_center_session.json"
}

Nmer_FullTextSettingsPath(*) {
    return Nmer_DataSearchDir() . "\fulltext_settings.json"
}

Nmer_FullTextFilterConfigPath(*) {
    return Nmer_DataSearchDir() . "\fulltext_config.json"
}

Nmer_PromptsJsonPath(*) {
    return Nmer_DataStateDir() . "\prompts.json"
}

Nmer_CommandPaletteExecPath(*) {
    return Nmer_DataStateDir() . "\CommandPaletteExec.json"
}

Nmer_VkCursorKeymapCompiledPath(*) {
    return Nmer_DataStateDir() . "\vk_cursor_keymap_compiled.json"
}

Nmer_NiumaChatDataDir(*) {
    return Nmer_DataRuntimeDir() . "\niuma-chat"
}

Nmer_UltimateDictDbPath(*) {
    return Nmer_DataDictDir() . "\ultimate.db"
}

Nmer_EcdictDbPath(*) {
    return Nmer_DataDictDir() . "\ecdict.db"
}

Nmer_StardictDbPath(*) {
    return Nmer_DataDictDir() . "\stardict.db"
}

Nmer_GroundingCacheDbPath(*) {
    return Nmer_DataDbDir() . "\GroundingCache.db"
}

Nmer_GroundingCacheVecDbPath(*) {
    return Nmer_DataDbDir() . "\GroundingCache_vec.db"
}

Nmer_DataStateConfigPath(*) {
    return Nmer_DataStateDir() . "\config.json"
}

Nmer_SecretsVaultPath(*) {
    return Nmer_LocalDir() . "\secrets.vault.json"
}

Nmer_DiagnosticsDir(*) {
    return Nmer_CacheDir() . "\diagnostics"
}

; 迁移包分组（与 tools/Nmer-MigrationManifest.ps1 保持同步）
Nmer_MigrationPresets() {
    return Map(
        "recommended", ["local.config", "local.studio", "local.openclaw", "local.prompts", "data.search", "data.state", "data.db.clipboard", "data.db.cursor", "data.runtime.chat"],
        "light", ["local.config", "local.studio", "local.openclaw", "local.prompts", "data.search", "data.state"],
        "full", ["local.config", "local.studio", "local.openclaw", "local.prompts", "data.search", "data.state", "data.db.clipboard", "data.db.cursor", "data.runtime.chat", "cache.images", "cache.thumbs", "cache.temp"]
    )
}

Nmer_MigrationGroupCatalog() {
    cacheRoot := Nmer_UserCacheRoot()
    return [
        Map("id", "local.config", "category", "local", "label", "主程序配置", "hint", "CursorShortcut.ini：热键、主题、缓存路径", "default", true, "paths", [Nmer_MainConfigFile()]),
        Map("id", "local.studio", "category", "local", "label", "智能定制", "hint", "user_studio、备份与 Niuma Chat LLM", "default", true, "paths", [Nmer_UserStudioPath(), Nmer_UserStudioBackupPath(), Nmer_NiumaChatLlmPath()]),
        Map("id", "local.openclaw", "category", "local", "label", "OpenClaw 工作区", "hint", "openclaw-state 目录", "default", true, "paths", [Nmer_OpenClawStateDir()]),
        Map("id", "local.prompts", "category", "local", "label", "提示词模板 (INI)", "hint", "PromptTemplates.ini", "default", true, "paths", [Nmer_PromptTemplatesFile()]),
        Map("id", "data.search", "category", "data", "label", "搜索与全文配置", "hint", "SearchCenter 历史与全文过滤", "default", true, "paths", [Nmer_SearchCenterHistoryPath(), Nmer_FullTextSettingsPath(), Nmer_FullTextFilterConfigPath()]),
        Map("id", "data.state", "category", "data", "label", "应用状态 JSON", "hint", "提示词、命令面板、虚拟键盘映射", "default", true, "paths", [Nmer_PromptsJsonPath(), Nmer_CommandPaletteExecPath(), Nmer_VkCursorKeymapCompiledPath(), Nmer_DataStateConfigPath()]),
        Map("id", "data.db.clipboard", "category", "data", "label", "剪贴板历史库", "hint", "Clipboard.db；导出时建议关闭占用", "default", true, "paths", [Nmer_ClipboardFts5DbPath(), Nmer_DataDbDir() . "\Clipboard.db-wal", Nmer_DataDbDir() . "\Clipboard.db-shm"]),
        Map("id", "data.db.cursor", "category", "data", "label", "Cursor 面板数据", "hint", "CursorData.db", "default", true, "paths", [Nmer_CursorDataDbPath()]),
        Map("id", "data.runtime.chat", "category", "data", "label", "Niuma Chat 数据", "hint", "会话与附件", "default", true, "paths", [Nmer_NiumaChatDataDir()]),
        Map("id", "cache.images", "category", "cache", "label", "截图/剪贴板图片", "hint", "剪贴板图片显示需要", "default", false, "paths", [Nmer_CacheImagesDir()], "zipRel", "Cache\images"),
        Map("id", "cache.thumbs", "category", "cache", "label", "缩略图缓存", "hint", "可重建", "default", false, "paths", [Nmer_ThumbsDir()], "zipRel", "Cache\thumbs"),
        Map("id", "cache.temp", "category", "cache", "label", "临时截图副本", "hint", "可安全跳过", "default", false, "paths", [Nmer_CacheTempDir()], "zipRel", "Cache\temp"),
        Map("id", "cache.fulltext", "category", "cache", "label", "全文索引", "hint", "体积大；新机可重建", "default", false, "paths", [Nmer_FullTextIndexDir()], "zipRel", "Cache\fulltext-index"),
        Map("id", "cache.debug", "category", "cache", "label", "调试日志", "hint", "换机通常不需要", "default", false, "paths", [Nmer_DebugDir()], "zipRel", "Cache\debug"),
    ]
}

Nmer_MigrationPathSize(absPath) {
    absPath := Trim(String(absPath))
    if (absPath = "")
        return 0
    if DirExist(absPath)
        return Nmer_DirSizeBytes(absPath)
    if FileExist(absPath) {
        try return FileGetSize(absPath)
        catch {
            return 0
        }
    }
    return 0
}

Nmer_MigrationPathExists(absPath) {
    absPath := Trim(String(absPath))
    return (absPath != "") && (DirExist(absPath) || FileExist(absPath))
}

Nmer_GetMigrationOptionsInfo(*) {
    groupsOut := []
    total := 0
    for g in Nmer_MigrationGroupCatalog() {
        bytes := 0
        exists := false
        for p in g["paths"] {
            if Nmer_MigrationPathExists(p) {
                exists := true
                bytes += Nmer_MigrationPathSize(p)
            }
        }
        total += bytes
        groupsOut.Push(Map(
            "id", g["id"],
            "category", g["category"],
            "label", g["label"],
            "hint", g["hint"],
            "default", !!g["default"],
            "bytes", bytes,
            "sizeText", Nmer_FormatBytes(bytes),
            "exists", exists
        ))
    }
    presets := Nmer_MigrationPresets()
    presetsOut := [
        Map("id", "recommended", "label", "换机推荐", "description", "配置 + 状态 + 剪贴板/Cursor 库 + Chat（不含图片缓存）", "groups", presets["recommended"]),
        Map("id", "light", "label", "轻量配置", "description", "仅 local 与 Data 状态/搜索 JSON，不含数据库", "groups", presets["light"]),
        Map("id", "full", "label", "完整备份", "description", "换机推荐 + 图片/缩略图/临时截图", "groups", presets["full"]),
        Map("id", "custom", "label", "自定义", "description", "手动勾选下方分组", "groups", []),
    ]
    return Map("groups", groupsOut, "presets", presetsOut, "totalBytes", total, "totalText", Nmer_FormatBytes(total))
}

Nmer_ResolveMigrationGroups(opts := "") {
    presets := Nmer_MigrationPresets()
    if !(opts is Map)
        return presets["recommended"].Clone()
    if opts.Has("groups") && (opts["groups"] is Array) && opts["groups"].Length {
        out := []
        for g in opts["groups"]
            out.Push(Trim(String(g)))
        if out.Length
            return out
    }
    preset := Trim(String(opts.Get("preset", "recommended")))
    if presets.Has(preset) && preset != "custom"
        return presets[preset].Clone()
    return presets["recommended"].Clone()
}

Nmer_MigrationGroupEntryPaths(groupId) {
    groupId := Trim(String(groupId))
    for g in Nmer_MigrationGroupCatalog() {
        if (g["id"] != groupId)
            continue
        entries := []
        switch groupId {
            case "local.config":
            entries.Push(Map("id", "local.config", "relPath", "local\CursorShortcut.ini", "sensitive", false))
            case "local.studio":
            entries.Push(Map("id", "local.user_studio", "relPath", "local\user_studio.json", "sensitive", true))
            entries.Push(Map("id", "local.user_studio_backup", "relPath", "local\user_studio.backup.json", "sensitive", true))
            entries.Push(Map("id", "local.niuma_chat_llm", "relPath", "local\niuma_chat_llm.json", "sensitive", true))
            case "local.openclaw":
            entries.Push(Map("id", "local.openclaw_state", "relPath", "local\openclaw-state", "sensitive", true))
            case "local.prompts":
            entries.Push(Map("id", "local.prompt_templates", "relPath", "local\PromptTemplates.ini", "sensitive", false))
            case "data.search":
            entries.Push(Map("id", "data.search.history", "relPath", "Data\search\SearchCenterHistory.json", "sensitive", false))
            entries.Push(Map("id", "data.search.fulltext_settings", "relPath", "Data\search\fulltext_settings.json", "sensitive", false))
            entries.Push(Map("id", "data.search.fulltext_config", "relPath", "Data\search\fulltext_config.json", "sensitive", false))
            case "data.state":
            entries.Push(Map("id", "data.state.prompts", "relPath", "Data\state\prompts.json", "sensitive", false))
            entries.Push(Map("id", "data.state.cmdpal", "relPath", "Data\state\CommandPaletteExec.json", "sensitive", false))
            entries.Push(Map("id", "data.state.vk_keymap", "relPath", "Data\state\vk_cursor_keymap_compiled.json", "sensitive", false))
            entries.Push(Map("id", "data.state.config", "relPath", "Data\state\config.json", "sensitive", false))
            case "data.db.clipboard":
            entries.Push(Map("id", "data.db.clipboard", "relPath", "Data\db\Clipboard.db", "sensitive", false))
            entries.Push(Map("id", "data.db.clipboard_wal", "relPath", "Data\db\Clipboard.db-wal", "sensitive", false))
            entries.Push(Map("id", "data.db.clipboard_shm", "relPath", "Data\db\Clipboard.db-shm", "sensitive", false))
            case "data.db.cursor":
            entries.Push(Map("id", "data.db.cursor", "relPath", "Data\db\CursorData.db", "sensitive", false))
            case "data.runtime.chat":
            entries.Push(Map("id", "data.runtime.niuma_chat", "relPath", "Data\runtime\niuma-chat", "sensitive", true))
            default:
            if g.Has("zipRel") {
                abs := g["paths"][1]
                entries.Push(Map("id", groupId, "relPath", g["zipRel"], "srcPath", abs, "sensitive", false))
            }
        }
        return entries
    }
    return []
}

Nmer_CollectMigrationEntries(groupIds*) {
    if (groupIds.Length = 0)
        groupIds := Nmer_ResolveMigrationGroups(Map("preset", "recommended"))
    entries := []
    seen := Map()
    for gid in groupIds {
        for e in Nmer_MigrationGroupEntryPaths(gid) {
            eid := e["id"]
            if seen.Has(eid)
                continue
            seen[eid] := true
            entries.Push(e)
        }
    }
    return entries
}

Nmer_MigrationSensitiveFieldNames() {
    return ["apiKey", "apiKeys", "llmApiKeys", "options.llmApiKeys"]
}

; ---------- 用户可管理缓存根目录（默认 项目/Cache，可在设置中修改或整夹删除）----------

Nmer_UserCacheRoot(*) {
    global g_Nmer_UserCacheRootCached
    if IsSet(g_Nmer_UserCacheRootCached) && g_Nmer_UserCacheRootCached != ""
        return g_Nmer_UserCacheRootCached
    ini := Nmer_MainConfigFile()
    custom := ""
    try custom := Trim(IniRead(ini, "Paths", "UserCacheRoot", ""))
    catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
    if (custom != "") {
        if !DirExist(custom)
            try DirCreate(custom)
        g_Nmer_UserCacheRootCached := custom
        return g_Nmer_UserCacheRootCached
    }
    g_Nmer_UserCacheRootCached := A_ScriptDir . "\Cache"
    return g_Nmer_UserCacheRootCached
}

Nmer_SetUserCacheRoot(newRoot) {
    global g_Nmer_UserCacheRootCached
    newRoot := Trim(String(newRoot), "\")
    if (newRoot = "")
        throw Error("缓存目录不能为空")
    if !DirExist(newRoot)
        DirCreate(newRoot)
    old := A_ScriptDir . "\Cache"
    try {
        if IsSet(g_Nmer_UserCacheRootCached) && g_Nmer_UserCacheRootCached != ""
            old := g_Nmer_UserCacheRootCached
        else {
            custom := Trim(IniRead(Nmer_MainConfigFile(), "Paths", "UserCacheRoot", ""))
            if (custom != "")
                old := custom
        }
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
    if (StrLower(old) != StrLower(newRoot))
        Nmer_MigrateTreeIfMissing(old, newRoot)
    Nmer_EnsureLocalDir()
    IniWrite(newRoot, Nmer_MainConfigFile(), "Paths", "UserCacheRoot")
    g_Nmer_UserCacheRootCached := newRoot
    return newRoot
}

Nmer_InvalidateUserCacheRoot(*) {
    global g_Nmer_UserCacheRootCached
    g_Nmer_UserCacheRootCached := ""
}

Nmer_FullTextIndexDir(*) {
    return Nmer_UserCacheRoot() . "\fulltext-index"
}

Nmer_CacheImagesDir(*) {
    return Nmer_UserCacheRoot() . "\images"
}

Nmer_ThumbsDir(*) {
    return Nmer_UserCacheRoot() . "\thumbs"
}

Nmer_CacheTempDir(*) {
    return Nmer_UserCacheRoot() . "\temp"
}

; ---------- 运行时调试/追踪 Cache/debug/（可整夹删除，启动时自动重建）----------

Nmer_CacheDir(*) {
    return Nmer_UserCacheRoot()
}

Nmer_EnsureCacheDir(*) {
    dir := Nmer_CacheDir()
    if !DirExist(dir)
        try DirCreate(dir)
    return dir
}

Nmer_DebugDir(*) {
    return Nmer_CacheDir() . "\debug"
}

Nmer_EnsureDebugDir(*) {
    Nmer_EnsureCacheDir()
    dir := Nmer_DebugDir()
    if !DirExist(dir)
        try DirCreate(dir)
    return dir
}

Nmer_DebugPath(fileName) {
    return Nmer_DebugDir() . "\" . fileName
}

Nmer_OpenDebugDir(*) {
  if FuncExists("Nmer_OpenPathInExplorer")
        return Nmer_OpenPathInExplorer(Nmer_DebugDir())
    try {
        Run('explorer.exe "' . Nmer_DebugDir() . '"')
        return true
    } catch {
        return false
    }
}

Nmer_TraceLogPath(*) {
    return Nmer_DebugPath("nmer_trace.log")
}

Nmer_OpenClawTimelinePath(*) {
    return Nmer_DebugPath("openclaw_timeline.jsonl")
}

Nmer_ConfigDir(*) {
    return A_ScriptDir . "\config"
}

Nmer_LibDir(*) {
    return A_ScriptDir . "\lib"
}

Nmer_LibAhkDir(*) {
    return Nmer_LibDir() . "\ahk"
}

Nmer_LibRuntimeDir(*) {
    return Nmer_LibDir() . "\runtime"
}

Nmer_LibRuntime64Dir(*) {
    return Nmer_LibRuntimeDir() . "\64bit"
}

Nmer_AssetsIconsDir(*) {
    return A_ScriptDir . "\assets\icons"
}

Nmer_AssetsIconsAiDir(*) {
    return Nmer_AssetsIconsDir() . "\ai"
}

Nmer_AssetsIconsAppDir(*) {
    return Nmer_AssetsIconsDir() . "\app"
}

Nmer_LibRuntimePath(fileName) {
    root := A_ScriptDir
    rt := Nmer_LibRuntimeDir()
    lib := Nmer_LibDir()
    rt64 := Nmer_LibRuntime64Dir()
    return Nmer_FirstExistingPath(
        rt . "\" . fileName,
        lib . "\" . fileName,
        rt64 . "\" . fileName,
        lib . "\64bit\" . fileName
    )
}

Nmer_WebView2LoaderPath(*) {
    return Nmer_LibRuntimePath("WebView2Loader.dll")
}

Nmer_AssetsIconPath(subDir, fileName) {
    subDir := Trim(String(subDir), "\/")
    fileName := Trim(String(fileName), "\/")
    root := A_ScriptDir
    if (subDir = "ai" || subDir = "app") {
        p := Nmer_FirstExistingPath(
            root . "\assets\icons\" . subDir . "\" . fileName,
            subDir = "ai" ? root . "\aiicons\" . fileName : root . "\lib\images\" . fileName,
            root . "\lib\images\" . fileName
        )
        if (p != "")
            return p
    }
    return root . "\assets\icons\" . subDir . "\" . fileName
}

Nmer_FirstExistingPath(paths*) {
    for p in paths {
        p := String(p)
        if (p != "" && FileExist(p))
            return p
    }
    return paths.Length ? String(paths[1]) : ""
}

Nmer_CommandsJsonPath(*) {
    preferred := Nmer_ConfigDir() . "\Commands.json"
    if FileExist(preferred)
        return preferred
    legacy := A_ScriptDir . "\Commands.json"
    if FileExist(legacy)
        return legacy
    return preferred
}

Nmer_Sqlite3DllPath(*) {
    root := A_ScriptDir
    return Nmer_FirstExistingPath(
        root . "\lib\runtime\sqlite3.dll",
        root . "\lib\runtime\SQLite3.dll",
        root . "\lib\sqlite3.dll",
        root . "\lib\SQLite3.dll",
        root . "\sqlite3.dll",
        root . "\tools\sqlite3.dll"
    )
}

Nmer_AppIconIcoPath(*) {
    root := A_ScriptDir
    return Nmer_FirstExistingPath(root . "\assets\牛马.ico", root . "\牛马.ico")
}

Nmer_AppIconPngPath(*) {
    root := A_ScriptDir
    return Nmer_FirstExistingPath(root . "\assets\牛马.png", root . "\牛马.png")
}

Nmer_EnsureSqliteDbIni(*) {
    dll := Nmer_Sqlite3DllPath()
    if !FileExist(dll)
        return
    rel := dll
    if InStr(dll, A_ScriptDir . "\") = 1
        rel := SubStr(dll, StrLen(A_ScriptDir) + 2)
    ini := A_ScriptDir . "\SQLiteDB.ini"
    want := "[Main]`nDllPath=" . rel . "`n"
    try {
        if FileExist(ini) {
            cur := FileRead(ini, "UTF-8")
            if (Trim(cur) = Trim(want))
                return
        }
        FileDelete(ini)
        FileAppend(want, ini, "UTF-8")
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
}

Nmer_MigrateDbSetIfMissing(oldDbPath, newDbPath) {
    Nmer_MigrateFileIfMissing(oldDbPath, newDbPath)
    Nmer_MigrateFileIfMissing(oldDbPath . "-wal", newDbPath . "-wal")
    Nmer_MigrateFileIfMissing(oldDbPath . "-shm", newDbPath . "-shm")
}

Nmer_MigrateFileIfMissing(oldPath, newPath) {
    if FileExist(newPath)
        return
    if !FileExist(oldPath)
        return
    try {
        SplitPath(newPath, , &dir)
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)
        FileMove(oldPath, newPath, 1)
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
}

Nmer_MigrateTreeIfMissing(oldDir, newDir) {
    oldDir := Trim(String(oldDir), "\")
    newDir := Trim(String(newDir), "\")
    if (oldDir = "" || !DirExist(oldDir))
        return
    if !DirExist(newDir)
        try DirCreate(newDir)
    Loop Files oldDir . "\*", "R" {
        rel := SubStr(A_LoopFileFullPath, StrLen(oldDir) + 2)
        dest := newDir . "\" . rel
        if FileExist(dest)
            continue
        try {
            SplitPath(dest, , &parent)
            if (parent != "" && !DirExist(parent))
                DirCreate(parent)
            FileMove(A_LoopFileFullPath, dest, 0)
        } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
    }
}

; 首次启动：散落调试日志迁入 Cache/debug/
Nmer_MigrateDebugFiles(*) {
    Nmer_EnsureDebugDir()
    root := A_ScriptDir
    cache := Nmer_CacheDir()
    dbg := Nmer_DebugDir()
    timeline := Nmer_OpenClawTimelinePath()

    for oldTimeline in [
        root . "\Data\NiuMaDebug\openclaw_timeline.jsonl",
        root . "\Data\debug\NiuMaDebug\openclaw_timeline.jsonl",
        root . "\Data\debug\openclaw_timeline.jsonl",
        cache . "\openclaw_timeline.jsonl",
    ]
        Nmer_MigrateFileIfMissing(oldTimeline, timeline)

    niuMaDbg := root . "\Data\NiuMaDebug"
    if DirExist(niuMaDbg) {
        Loop Files niuMaDbg . "\*", "F" {
            if (A_LoopFileName = "openclaw_timeline.jsonl")
                continue
            Nmer_MigrateFileIfMissing(A_LoopFileFullPath, dbg . "\" . A_LoopFileName)
        }
    }

    dataDbg := root . "\Data\debug"
    if DirExist(dataDbg) {
        Loop Files dataDbg . "\*", "F" {
            if (A_LoopFileName = "openclaw_timeline.jsonl")
                continue
            Nmer_MigrateFileIfMissing(A_LoopFileFullPath, dbg . "\" . A_LoopFileName)
        }
    }

    for f in [
        "scwv_trace.log",
        "screenshot_editor_trace.log",
        "screenshot_interference.log",
        "nmer_trace.log",
        "startup_error.log",
        "native_drop_events.jsonl",
        "drop_diagnostics_runtime.log",
        "hubcapsule_runtime.log",
        "tray_menu_runtime.log",
        "clipboard_panel_runtime.log",
        "hole_triggers.log",
        "niuma_mobile_snapshot_debug.log",
        "core_async_http.log",
        "wv2_shared_env.log",
        "legacy_guardrails.log",
        "focus_broker.log",
        "prompt_execution_guard.log",
        "core_async_guard.log",
        "wails_record_err.log",
        "grounding_l2.log",
    ]
        Nmer_MigrateFileIfMissing(cache . "\" . f, dbg . "\" . f)
}

; 首次启动：从根目录 / config / Cache 迁入 local/
Nmer_MigrateLocalData(*) {
    Nmer_EnsureLocalDir()
    root := A_ScriptDir
    localDir := Nmer_LocalDir()
    cfgDir := root . "\config"
    Nmer_MigrateFileIfMissing(root . "\CursorShortcut.ini", Nmer_MainConfigFile())
    Nmer_MigrateFileIfMissing(root . "\PromptTemplates.ini", Nmer_PromptTemplatesFile())
    Nmer_MigrateFileIfMissing(cfgDir . "\user_studio.json", Nmer_UserStudioPath())
    Nmer_MigrateFileIfMissing(cfgDir . "\user_studio.backup.json", Nmer_UserStudioBackupPath())
    Nmer_MigrateFileIfMissing(cfgDir . "\niuma_chat_llm.json", Nmer_NiumaChatLlmPath())
    Nmer_MigrateFileIfMissing(cfgDir . "\curser.ini", localDir . "\curser.ini")
    Nmer_MigrateTreeIfMissing(root . "\Cache\openclaw-state", Nmer_OpenClawStateDir())
    Nmer_MigrateDataFiles()
    Nmer_MigrateDataLayout()
    Nmer_MigrateUserCacheFiles()
    Nmer_MigrateDebugFiles()
}

; 首次启动：全文索引、剪贴板图片、缩略图等迁入统一 Cache/
Nmer_MigrateUserCacheFiles(*) {
    Nmer_EnsureUserCacheLayout()
    root := A_ScriptDir
    data := Nmer_DataDir()
    cache := Nmer_UserCacheRoot()
    ft := Nmer_FullTextIndexDir()
    img := Nmer_CacheImagesDir()
    thumbs := Nmer_ThumbsDir()

    Nmer_MigrateTreeIfMissing(data . "\fulltext-index", ft)
    Nmer_MigrateTreeIfMissing(data . "\index\fulltext-index", ft)
    Nmer_MigrateTreeIfMissing(data . "\Images", img)
    Nmer_MigrateTreeIfMissing(cache . "\Thumbs", thumbs)
    Nmer_MigrateTreeIfMissing(cache . "\Images", img)

    ; 旧版散落在 Cache 根目录的截图副本
    if DirExist(cache) {
        Loop Files cache . "\Screenshot_*.*", "F" {
            dest := Nmer_CacheTempDir() . "\" . A_LoopFileName
            Nmer_MigrateFileIfMissing(A_LoopFileFullPath, dest)
        }
    }

    Nmer_MigrateFullTextSettingsIndexDir()
}

Nmer_EnsureUserCacheLayout(*) {
    for sub in ["debug", "fulltext-index", "images", "thumbs", "temp"] {
        dir := Nmer_UserCacheRoot() . "\" . sub
        if !DirExist(dir)
            try DirCreate(dir)
    }
    return Nmer_UserCacheRoot()
}

Nmer_MigrateFullTextSettingsIndexDir(*) {
    path := Nmer_FullTextSettingsPath()
    if !FileExist(path)
        return
    try {
        raw := FileRead(path, "UTF-8")
    } catch {
        return
    }
    root := A_ScriptDir
    dataFt := StrLower(root . "\Data\fulltext-index")
    dataIdxFt := StrLower(root . "\Data\index\fulltext-index")
    newIdx := Nmer_FullTextIndexDir()
    if !InStr(StrLower(raw), dataFt) && !InStr(StrLower(raw), dataIdxFt)
        return
    if !RegExMatch(raw, '"indexDir"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"', &m)
        return
    old := StrReplace(m[1], '\\', '\')
    oldKey := StrLower(old)
    if (oldKey != dataFt && !InStr(oldKey, dataFt . "\") && oldKey != dataIdxFt && !InStr(oldKey, dataIdxFt . "\"))
        return
    tag := ""
    if RegExMatch(old, "bluge_index_([0-9a-fA-F]+)", &tm)
        tag := tm[1]
    target := tag != "" ? (newIdx . "\bluge_index_" . tag) : newIdx
    newRaw := RegExReplace(raw, '"indexDir"\s*:\s*"[^"]*"', '"indexDir": "' . StrReplace(target, '\', '\\') . '"', , 1)
    if (newRaw = raw)
        return
    try {
        FileDelete(path)
        FileAppend(newRaw, path, "UTF-8")
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
}

Nmer_ResetFullTextSettingsIndexDir(*) {
    path := Nmer_FullTextSettingsPath()
    if !FileExist(path)
        return
    try {
        raw := FileRead(path, "UTF-8")
        newRaw := RegExReplace(raw, '"indexDir"\s*:\s*"[^"]*"', '"indexDir": ""', , 1)
        if (newRaw = raw)
            return
        FileDelete(path)
        FileAppend(newRaw, path, "UTF-8")
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
}

Nmer_DirSizeBytes(dir) {
    dir := Trim(String(dir), "\")
    total := 0
    if !DirExist(dir)
        return 0
    Loop Files dir . "\*", "R" {
        if (A_LoopFileAttrib ~= "D")
            continue
        try total += A_LoopFileSize
        catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
    }
    return total
}

Nmer_FormatBytes(n) {
    n := Number(n)
    if (n < 1024)
        return Round(n) . " B"
    if (n < 1048576)
        return Round(n / 1024, 1) . " KB"
    if (n < 1073741824)
        return Round(n / 1048576, 2) . " MB"
    return Round(n / 1073741824, 2) . " GB"
}

Nmer_CollectCacheInfo(*) {
    Nmer_EnsureUserCacheLayout()
    root := Nmer_UserCacheRoot()
    items := [
        Map("id", "fulltext", "label", "全文索引", "path", Nmer_FullTextIndexDir(), "hint", "删除后需重新构建索引"),
        Map("id", "images", "label", "剪贴板/截图图片", "path", Nmer_CacheImagesDir(), "hint", "数据库中的图片路径可能失效"),
        Map("id", "thumbs", "label", "缩略图缓存", "path", Nmer_ThumbsDir(), "hint", "可安全删除，会按需重建"),
        Map("id", "temp", "label", "临时文件", "path", Nmer_CacheTempDir(), "hint", "截图编辑等临时副本"),
        Map("id", "debug", "label", "调试日志", "path", Nmer_DebugDir(), "hint", "可安全删除，运行时会自动重建"),
    ]
    total := 0
    for it in items {
        sz := Nmer_DirSizeBytes(it["path"])
        it["bytes"] := sz
        it["sizeText"] := Nmer_FormatBytes(sz)
        total += sz
    }
    return Map(
        "root", root,
        "totalBytes", total,
        "totalText", Nmer_FormatBytes(total),
        "items", items
    )
}

Nmer_ClearCacheTargets(targets*) {
    if (targets.Length = 0)
        targets := ["fulltext", "images", "thumbs", "temp", "debug"]
    cleared := []
    for t in targets {
        id := StrLower(Trim(String(t)))
        dir := ""
        switch id {
            case "fulltext":
                dir := Nmer_FullTextIndexDir()
                Nmer_ResetFullTextSettingsIndexDir()
            case "images":
                dir := Nmer_CacheImagesDir()
            case "thumbs":
                dir := Nmer_ThumbsDir()
            case "temp":
                dir := Nmer_CacheTempDir()
            case "debug":
                dir := Nmer_DebugDir()
            default:
                continue
        }
        if (dir = "" || !DirExist(dir))
            continue
        try DirDelete(dir, 1)
        catch {
            Nmer_DeleteDirContents(dir)
        }
        try DirCreate(dir)
        cleared.Push(id)
    }
    return cleared
}

Nmer_DeleteDirContents(dir) {
    dir := Trim(String(dir), "\")
    if !DirExist(dir)
        return
    Loop Files dir . "\*", "R" {
        try {
            if (A_LoopFileAttrib ~= "D")
                DirDelete(A_LoopFileFullPath, 1)
            else
                FileDelete(A_LoopFileFullPath)
        } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
    }
}

Nmer_OpenPathInExplorer(path) {
    path := Trim(String(path))
    if (path = "")
        return false
    if !DirExist(path) && !FileExist(path) {
        SplitPath(path, , &parent)
        if (parent != "" && !DirExist(parent))
            DirCreate(parent)
    }
    try {
        Run('explorer.exe "' . path . '"')
        return true
    } catch {
        return false
    }
}

; 首次启动：根目录散落 db/json 迁入 Data/
Nmer_MigrateDataFiles(*) {
    Nmer_EnsureDataDir()
    root := A_ScriptDir
    dataDir := Nmer_DataDir()
    Nmer_MigrateDbSetIfMissing(root . "\Clipboard.db", dataDir . "\Clipboard.db")
    Nmer_MigrateFileIfMissing(root . "\prompts.json", dataDir . "\prompts.json")
    Nmer_MigrateDbSetIfMissing(root . "\ultimate.db", dataDir . "\ultimate.db")
    Nmer_MigrateDbSetIfMissing(root . "\ecdict.db", dataDir . "\ecdict.db")
    Nmer_MigrateDbSetIfMissing(root . "\stardict.db", dataDir . "\stardict.db")
}

; 首次启动：Data 根目录归类到 db/ dict/ search/ state/ runtime/
Nmer_MigrateDataLayout(*) {
    Nmer_EnsureDataDir()
    data := Nmer_DataDir()
    db := Nmer_DataDbDir()
    dict := Nmer_DataDictDir()
    search := Nmer_DataSearchDir()
    state := Nmer_DataStateDir()
    runtime := Nmer_DataRuntimeDir()
    root := A_ScriptDir

    for name in ["Clipboard", "CursorData", "GroundingCache", "GroundingCache_vec", "data"] {
        Nmer_MigrateDbSetIfMissing(data . "\" . name . ".db", db . "\" . name . ".db")
    }
    for name in ["ultimate", "ecdict", "stardict"] {
        Nmer_MigrateDbSetIfMissing(data . "\" . name . ".db", dict . "\" . name . ".db")
        Nmer_MigrateDbSetIfMissing(db . "\" . name . ".db", dict . "\" . name . ".db")
    }
    for name in ["SearchCenterHistory.json", "fulltext_settings.json", "fulltext_config.json"] {
        Nmer_MigrateFileIfMissing(data . "\" . name, search . "\" . name)
        Nmer_MigrateFileIfMissing(runtime . "\app\" . name, search . "\" . name)
    }
    for name in ["prompts.json", "config.json", "CommandPaletteExec.json", "vk_cursor_keymap_compiled.json"] {
        Nmer_MigrateFileIfMissing(data . "\" . name, state . "\" . name)
    }
    Nmer_MigrateFileIfMissing(root . "\prompts.json", Nmer_PromptsJsonPath())
    Nmer_MigrateFileIfMissing(data . "\CommandPaletteExec.json", Nmer_CommandPaletteExecPath())
    Nmer_MigrateFileIfMissing(data . "\vk_cursor_keymap_compiled.json", Nmer_VkCursorKeymapCompiledPath())

    Nmer_MigrateTreeIfMissing(data . "\niuma-chat", Nmer_NiumaChatDataDir())
    Nmer_MigrateTreeIfMissing(data . "\app", runtime . "\app")
    Nmer_MigrateTreeIfMissing(data . "\log", runtime . "\log")

    Nmer_MigrateFullTextSettingsIndexDir()
    Nmer_CleanupLegacyDataDirs()
}

Nmer_CleanupLegacyDataDirs(*) {
    data := Nmer_DataDir()
    for name in ["Images", "fulltext-index", "index", "NiuMaDebug", "debug", "hole_ref", "niuma-chat", "app", "log"] {
        dir := data . "\" . name
        if !DirExist(dir)
            continue
        if Nmer_IsDirRemovableLegacy(dir)
            try DirDelete(dir, 1)
    }
    ; Data 根下已迁走的散落 db/json（仅删文件，不删 db 子目录里的库）
    for name in [
        "Clipboard.db", "Clipboard.db-wal", "Clipboard.db-shm",
        "CursorData.db", "CursorData.db-wal", "CursorData.db-shm",
        "GroundingCache.db", "GroundingCache_vec.db", "data.db",
        "ultimate.db", "ecdict.db", "stardict.db",
        "SearchCenterHistory.json", "fulltext_settings.json", "fulltext_config.json",
        "prompts.json", "config.json", "CommandPaletteExec.json", "vk_cursor_keymap_compiled.json",
    ] {
        p := data . "\" . name
        if FileExist(p)
            try FileDelete(p)
    }
}

Nmer_IsDirRemovableLegacy(dir) {
    dir := Trim(String(dir), "\")
    if !DirExist(dir)
        return false
    try {
        att := FileExist(dir)
        if (att != "" && InStr(att, "D") && InStr(att, "L"))
            return true
    } catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
    empty := true
    Loop Files dir . "\*", "R" {
        if (A_LoopFileName = ".gitkeep")
            continue
        empty := false
        break
    }
    return empty
}
