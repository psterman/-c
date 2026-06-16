; NmerMigration.ahk — 迁移包导出/导入（委托 tools/Nmer-*.ps1）

Nmer_MigrationToolsDir(*) {
    return Nmer_RepoRoot() . "\tools"
}

Nmer_RunMigrationPs1(scriptName, argTail := "") {
    ps1 := Nmer_MigrationToolsDir() . "\" . scriptName
    if !FileExist(ps1)
        return Map("ok", false, "error", "脚本不存在: " . scriptName, "exitCode", -1)
    cmd := 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' . ps1 . '" ' . argTail
    exitCode := -1
    try exitCode := RunWait(cmd, Nmer_RepoRoot(), "Hide")
    catch as e {
        return Map("ok", false, "error", e.Message, "exitCode", exitCode)
    }
    return Map("ok", exitCode = 0, "error", exitCode = 0 ? "" : "PowerShell 退出码 " . exitCode, "exitCode", exitCode)
}

Nmer_WriteMigrationOptionsJson(opts) {
  if !(opts is Map)
        opts := Map("preset", "recommended")
    path := A_Temp . "\nmer_migration_opts_" . A_TickCount . ".json"
    if !FuncExists("Jxon_Dump")
        throw Error("Jxon_Dump 不可用")
    try FileDelete(path)
    f := FileOpen(path, "w", "UTF-8")
    if !IsObject(f)
        throw Error("无法写入迁移选项临时文件")
    f.Write(Jxon_Dump(opts))
    f.Close()
    return path
}

Nmer_ExportMigrationPack(opts := "") {
    outZip := ""
    exportOpts := Map("preset", "recommended")
    if (opts is Map) {
        outZip := Trim(String(opts.Get("outZip", "")))
        if opts.Has("preset")
            exportOpts["preset"] := Trim(String(opts["preset"]))
        if opts.Has("groups") && (opts["groups"] is Array) && opts["groups"].Length
            exportOpts["groups"] := opts["groups"]
    }
    groups := Nmer_ResolveMigrationGroups(exportOpts)
    if !groups.Length
        return Map("ok", false, "error", "请至少选择一项迁移内容")
    exportOpts["groups"] := groups
    if (outZip = "") {
        diagDir := FuncExists("Nmer_DiagnosticsDir") ? Nmer_DiagnosticsDir() : (Nmer_RepoRoot() . "\Cache\diagnostics")
        if !DirExist(diagDir)
            try DirCreate(diagDir)
        stamp := FormatTime(A_Now, "yyyyMMdd-HHmmss")
        outZip := diagDir . "\nmer_migration_" . stamp . ".zip"
    }
    optsFile := ""
    try optsFile := Nmer_WriteMigrationOptionsJson(exportOpts)
    catch as e {
        return Map("ok", false, "error", e.Message)
    }
    args := '-Root "' . Nmer_RepoRoot() . '" -OptionsJson "' . optsFile . '" -OutZip "' . outZip . '"'
    r := Nmer_RunMigrationPs1("Nmer-ExportAll.ps1", args)
    try FileDelete(optsFile)
    catch as _e {
        NmerCatch(A_ThisFunc, _e)
    }
    r["zipPath"] := outZip
    r["groups"] := groups
    r["postImportNote"] := "请在智能定制中重新填写 API Key（vault 不随迁移包导出）"
    if r.Get("ok", false) && FileExist(outZip)
        try Run('explorer.exe /select,"' . outZip . '"')
        catch as _e {
            NmerCatch(A_ThisFunc, _e)
        }
    return r
}

Nmer_PreviewMigrationPack(zipPath) {
    zipPath := Trim(String(zipPath))
    if (zipPath = "" || !FileExist(zipPath))
        return Map("ok", false, "error", "迁移包文件不存在")
    previewOut := A_Temp . "\nmer_migration_preview_" . A_TickCount . ".json"
    args := '-ZipPath "' . zipPath . '" -Root "' . Nmer_RepoRoot() . '" -OutJson "' . previewOut . '"'
    r := Nmer_RunMigrationPs1("Nmer-PreviewMigration.ps1", args)
    if !r.Get("ok", false)
        return Map("ok", false, "error", r.Get("error", "预览失败"))
    if !FileExist(previewOut)
        return Map("ok", false, "error", "无法读取迁移包预览")
    try {
        raw := FileRead(previewOut, "UTF-8")
        FileDelete(previewOut)
        if !FuncExists("Jxon_Load")
            return Map("ok", false, "error", "Jxon_Load 不可用")
        parsed := Jxon_Load(raw)
        if !(parsed is Map)
            return Map("ok", false, "error", "预览 JSON 无效")
        return parsed
    } catch as e2 {
        return Map("ok", false, "error", e2.Message)
    }
}

Nmer_ImportMigrationPack(zipPath, force := true) {
    zipPath := Trim(String(zipPath))
    if (zipPath = "" || !FileExist(zipPath))
        return Map("ok", false, "error", "迁移包文件不存在")
    args := '-ZipPath "' . zipPath . '" -Root "' . Nmer_RepoRoot() . '"'
    if force
        args .= " -Force"
    r := Nmer_RunMigrationPs1("Nmer-ImportMigration.ps1", args)
    if r.Get("ok", false) {
        if FuncExists("Nmer_InvalidateUserCacheRoot")
            try Nmer_InvalidateUserCacheRoot()
            catch as _e {
                NmerCatch(A_ThisFunc, _e)
            }
        r["postImportNote"] := "导入完成。请打开「智能定制」重新填写 API Key，并建议重启牛马。"
    }
    return r
}

Nmer_MigrationPackForWeb(result) {
    if !(result is Map)
        return Map("ok", false, "error", "无效结果")
    out := Map(
        "ok", !!result.Get("ok", false),
        "error", String(result.Get("error", "")),
        "zipPath", String(result.Get("zipPath", "")),
        "postImportNote", String(result.Get("postImportNote", ""))
    )
    if result.Has("groups")
        out["groups"] := result["groups"]
    if result.Has("fileCount")
        out["fileCount"] := result["fileCount"]
    if result.Has("exportedAt")
        out["exportedAt"] := result["exportedAt"]
    if result.Has("preset")
        out["preset"] := result["preset"]
    return out
}

Nmer_MigrationOptionsForWeb(*) {
    if FuncExists("Nmer_GetMigrationOptionsInfo")
        return Nmer_GetMigrationOptionsInfo()
    return Map("groups", [], "presets", [], "totalText", "0 B")
}
