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
    } catch {
    }
    return Nmer_MainConfigFile()
}

Nmer_ResolvePromptTemplatesFile(*) {
    try {
        if IsSet(PromptTemplatesFile) && PromptTemplatesFile != ""
            return PromptTemplatesFile
    } catch {
    }
    return Nmer_PromptTemplatesFile()
}

; ---------- 用户数据目录 Data/（剪贴板库、搜索中心、草稿、词典等）----------

Nmer_DataDir(*) {
    return A_ScriptDir . "\Data"
}

Nmer_EnsureDataDir(*) {
    dir := Nmer_DataDir()
    if !DirExist(dir)
        try DirCreate(dir)
    return dir
}

Nmer_ClipboardFts5DbPath(*) {
    return Nmer_DataDir() . "\Clipboard.db"
}

Nmer_CursorDataDbPath(*) {
    return Nmer_DataDir() . "\CursorData.db"
}

Nmer_SearchCenterHistoryPath(*) {
    return Nmer_DataDir() . "\SearchCenterHistory.json"
}

Nmer_PromptsJsonPath(*) {
    return Nmer_DataDir() . "\prompts.json"
}

Nmer_UltimateDictDbPath(*) {
    return Nmer_DataDir() . "\ultimate.db"
}

Nmer_GroundingCacheDbPath(*) {
    return Nmer_DataDir() . "\GroundingCache.db"
}

Nmer_GroundingCacheVecDbPath(*) {
    return Nmer_DataDir() . "\GroundingCache_vec.db"
}

Nmer_FullTextIndexDir(*) {
    return Nmer_DataDir() . "\fulltext-index"
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
    } catch {
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
    } catch {
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
        } catch {
        }
    }
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
}

; 首次启动：根目录散落 db/json 迁入 Data/
Nmer_MigrateDataFiles(*) {
    Nmer_EnsureDataDir()
    root := A_ScriptDir
    dataDir := Nmer_DataDir()
    Nmer_MigrateDbSetIfMissing(root . "\Clipboard.db", Nmer_ClipboardFts5DbPath())
    Nmer_MigrateFileIfMissing(root . "\prompts.json", Nmer_PromptsJsonPath())
    Nmer_MigrateDbSetIfMissing(root . "\ultimate.db", Nmer_UltimateDictDbPath())
    Nmer_MigrateDbSetIfMissing(root . "\ecdict.db", dataDir . "\ecdict.db")
    Nmer_MigrateDbSetIfMissing(root . "\stardict.db", dataDir . "\stardict.db")
}
