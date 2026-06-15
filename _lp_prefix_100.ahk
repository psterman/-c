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
}
