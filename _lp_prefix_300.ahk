; LocalPaths.ahk — 用户私有数据目录（API Key、主配置、OpenClaw 状态）

Nmer_LocalDir(*) {
    return A_ScriptDir . "\local"
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
    return A_ScriptDir . "\Data"
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
}
