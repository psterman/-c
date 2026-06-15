; NmerDiagnostics.ahk — 诊断包导出（Cache/debug + SearchCore lifecycle 日志）

Nmer_ExportDiagnosticsBundle(*) {
    if FuncExists("Nmer_CollectHealthSnapshot") {
        try Nmer_CollectHealthSnapshot("export_bundle")
        catch as _e0 {
            NmerCatch(A_ThisFunc, _e0)
        }
    }
    root := A_ScriptDir
    if FuncExists("Nmer_CacheDir")
        cacheRoot := Nmer_CacheDir()
    else
        cacheRoot := root . "\Cache"
    stamp := FormatTime(A_Now, "yyyyMMdd_HHmmss")
    outDir := cacheRoot . "\diagnostics_export_" . stamp
    try DirCreate(outDir)
    catch as _e {
        NmerCatch(A_ThisFunc, _e)
        try TrayTip("牛马", "无法创建诊断目录", "Iconx 2")
        return false
    }

    copied := 0
    patterns := [
        Map("src", cacheRoot . "\debug", "glob", "*.*"),
        Map("src", cacheRoot . "\ci", "glob", "*.txt"),
        Map("src", cacheRoot . "\debug", "glob", "searchcore_*.jsonl"),
        Map("src", cacheRoot . "\debug", "glob", "searchcore_launch.log")
    ]
    for spec in patterns {
        srcDir := spec["src"]
        if !DirExist(srcDir)
            continue
        try {
            Loop Files, srcDir . "\" . spec["glob"], "F" {
                dest := outDir . "\" . A_LoopFileName
                try {
                    FileCopy(A_LoopFileFullPath, dest, true)
                    copied += 1
                } catch as _e2 {
                    NmerCatch(A_ThisFunc, _e2)
                }
            }
        } catch as _e3 {
            NmerCatch(A_ThisFunc, _e3)
        }
    }

    if FuncExists("Collect-SearchCoreLogs") {
        ; no-op: PowerShell collector is separate entry
    }
    collectPs1 := A_ScriptDir . "\tools\ci\Collect-SearchCoreLogs.ps1"
    if FileExist(collectPs1) {
        try {
            Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' . collectPs1 . '" -OutDir "' . outDir . '"', , "Hide")
            copied += 1
        } catch as _e7 {
            NmerCatch(A_ThisFunc, _e7)
        }
    }

    manifest := "exported=" . copied . "`nroot=" . root . "`nstamp=" . stamp . "`n"
    try FileAppend(manifest, outDir . "\manifest.txt", "UTF-8")
    catch as _e4 {
        NmerCatch(A_ThisFunc, _e4)
    }

    msg := "已导出 " . copied . " 个文件到`n" . outDir
    try TrayTip("诊断包", msg, "Iconi 3")
    catch as _e5 {
        NmerCatch(A_ThisFunc, _e5)
    }
    try Run('explorer.exe /select,"' . outDir . '"')
    catch as _e6 {
        NmerCatch(A_ThisFunc, _e6)
    }
    return true
}

Nmer_OpenLogsFolder(*) {
    if FuncExists("Nmer_OpenDebugDir")
        return Nmer_OpenDebugDir()
    return false
}
