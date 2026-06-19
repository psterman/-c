; NmerLoadGuard.ahk — 主脚本加载前语法校验与 LoadError 展示
#Requires AutoHotkey v2.0
#Include FuncExists.ahk

Nmer_LauncherScriptPath(*) {
    root := A_ScriptDir
    if FuncExists("Nmer_RepoRoot")
        root := Nmer_RepoRoot()
    return root . "\NmerLauncher.ahk"
}

Nmer_LoadErrorViewerPath(*) {
    root := A_ScriptDir
    if FuncExists("Nmer_RepoRoot")
        root := Nmer_RepoRoot()
    return root . "\tools\NmerLoadErrorViewer.ahk"
}

Nmer_ValidateMainScript(scriptPath, &errText := "") {
    errText := ""
    scriptPath := Trim(String(scriptPath))
    if (scriptPath = "" || !FileExist(scriptPath))
        return false

    ahkExe := A_AhkPath
    if (ahkExe = "" || !FileExist(ahkExe))
        return false

    errFile := A_Temp . "\nmer_validate_err_" . A_TickCount . ".txt"
    try {
        if FileExist(errFile)
            FileDelete(errFile)
    } catch {
    }

    cmd := 'cmd.exe /c ""' . ahkExe . '" /ErrorStdOut "' . scriptPath . '" /validateOnly 2> "' . errFile . '""'
    exitCode := -1
    try exitCode := RunWait(cmd, , "Hide")
    catch {
        exitCode := -1
    }

    errOut := ""
    if FileExist(errFile) {
        try errOut := Trim(FileRead(errFile, "UTF-8"))
        catch {
        }
    }
    try FileDelete(errFile)
    catch {
    }

    errText := errOut
    if (errOut != "")
        return false
    if (exitCode != 0)
        return false
    return true
}

Nmer_TryShowLoadError(scriptPath, errText, scene := "startup") {
    scriptPath := Trim(String(scriptPath))
    errText := String(errText)
    scene := Trim(String(scene))
    if (scene = "")
        scene := "startup"

    if FuncExists("Nmer_ShowLoadErrorDialog") {
        try {
            Nmer_ShowLoadErrorDialog(errText, scriptPath, scene)
            return true
        } catch {
        }
    }

    viewer := Nmer_LoadErrorViewerPath()
    if !FileExist(viewer)
        return false

    payloadFile := A_Temp . "\nmer_load_error.txt"
    metaFile := A_Temp . "\nmer_load_error_meta.txt"
    try {
        FileDelete(payloadFile)
        FileDelete(metaFile)
    } catch {
    }
    try {
        FileAppend(errText, payloadFile, "UTF-8")
        FileAppend(scriptPath . "`n" . scene, metaFile, "UTF-8")
    } catch {
        return false
    }

    try {
        Run('"' . A_AhkPath . '" "' . viewer . '"')
        return true
    } catch {
        return false
    }
}
