; ToolsPaths.ahk — 外援程序路径（SearchCenter、Everything、ttyd 等，统一 tools/）

Nmer_ToolsDir(*) {
    return A_ScriptDir . "\tools"
}

Nmer_ToolFirstExisting(paths*) {
    for p in paths {
        p := String(p)
        if (p != "" && FileExist(p))
            return p
    }
    return paths.Length ? String(paths[1]) : ""
}

Nmer_EnsureToolsSubDir(sub) {
    dir := Nmer_ToolsDir() . "\" . sub
    if !DirExist(dir)
        try DirCreate(dir)
    return dir
}

Nmer_SearchCenterCoreExe(*) {
    root := A_ScriptDir
    return Nmer_ToolFirstExisting(
        root . "\tools\search\SearchCenterCore.exe",
        root . "\searchcore\SearchCenterCore.exe",
        root . "\SearchCenterCore.exe"
    )
}

Nmer_TtydExe(*) {
    root := A_ScriptDir
    return Nmer_ToolFirstExisting(
        root . "\tools\ttyd\ttyd.exe",
        root . "\ttyd.exe"
    )
}

Nmer_EverythingDllPath(*) {
    root := (IsSet(MainScriptDir) && MainScriptDir != "") ? MainScriptDir : A_ScriptDir
    return Nmer_ToolFirstExisting(
        root . "\tools\everything\everything64.dll",
        root . "\lib\everything64.dll"
    )
}

Nmer_ResolveEverythingExePath(*) {
    root := (IsSet(MainScriptDir) && MainScriptDir != "") ? MainScriptDir : A_ScriptDir
    te := root . "\tools\everything\"
    pf := A_ProgramFiles
    candidates := [
        te . "Everything64.exe",
        te . "Everything.exe",
        root . "\Everything64.exe",
        root . "\Everything.exe",
        pf . "\Everything\Everything64.exe",
        pf . "\Everything\Everything.exe",
        pf . "\voidtools\Everything\Everything64.exe",
        pf . "\voidtools\Everything\Everything.exe"
    ]
    try {
        pf86 := EnvGet("ProgramFiles(x86)")
        if (pf86 != "") {
            candidates.Push(pf86 . "\Everything\Everything64.exe")
            candidates.Push(pf86 . "\Everything\Everything.exe")
            candidates.Push(pf86 . "\voidtools\Everything\Everything64.exe")
            candidates.Push(pf86 . "\voidtools\Everything\Everything.exe")
        }
    }
    return Nmer_ToolFirstExisting(candidates*)
}

Nmer_NativeDropBridgeExe(*) {
    return Nmer_ToolsDir() . "\native-drop-bridge\native-drop-bridge.exe"
}

Nmer_VoiceCliDir(*) {
    return Nmer_EnsureToolsSubDir("voice-cli")
}

Nmer_VoiceCliScript(fileName) {
    root := A_ScriptDir
    return Nmer_FirstExistingPath(
        Nmer_VoiceCliDir() . "\" . fileName,
        root . "\scripts\" . fileName
    )
}

Nmer_CiDir(*) {
    return Nmer_EnsureToolsSubDir("ci")
}

Nmer_CiProbesDir(*) {
    dir := Nmer_CiDir() . "\probes"
    if !DirExist(dir)
        try DirCreate(dir)
    return dir
}

Nmer_CiScript(fileName) {
    root := A_ScriptDir
    return Nmer_FirstExistingPath(
        Nmer_CiDir() . "\" . fileName,
        Nmer_CiProbesDir() . "\" . fileName,
        root . "\scripts\" . fileName
    )
}

; 首次启动：外援 exe/dll/bat 迁入 tools/ 子目录
Nmer_MigrateToolsBinaries(*) {
    root := A_ScriptDir
    tools := Nmer_ToolsDir()
    Nmer_EnsureToolsSubDir("search")
    Nmer_EnsureToolsSubDir("everything")
    Nmer_EnsureToolsSubDir("ttyd")
    Nmer_MigrateFileIfMissing(root . "\searchcore\SearchCenterCore.exe", tools . "\search\SearchCenterCore.exe")
    Nmer_MigrateFileIfMissing(root . "\SearchCenterCore.exe", tools . "\search\SearchCenterCore.exe")
    Nmer_MigrateFileIfMissing(root . "\ttyd.exe", tools . "\ttyd\ttyd.exe")
    Nmer_MigrateFileIfMissing(tools . "\rg.exe", tools . "\search\rg.exe")
    Nmer_MigrateFileIfMissing(root . "\rg.exe", tools . "\search\rg.exe")
    Nmer_MigrateFileIfMissing(root . "\lib\everything64.dll", tools . "\everything\everything64.dll")
    Nmer_MigrateFileIfMissing(root . "\Everything64.exe", tools . "\everything\Everything64.exe")
    Nmer_MigrateFileIfMissing(root . "\Everything.exe", tools . "\everything\Everything.exe")
    Nmer_MigrateFileIfMissing(tools . "\pdftotext.exe", tools . "\search\pdftotext.exe")
    Nmer_MigrateFileIfMissing(root . "\lib\pdftotext.exe", tools . "\search\pdftotext.exe")
    Nmer_MigrateFileIfMissing(root . "\ttyd.bat", tools . "\ttyd\ttyd.bat")
    Nmer_MigrateFileIfMissing(root . "\ttyd_debug.bat", tools . "\ttyd\ttyd_debug.bat")
    Nmer_MigrateRootLayout()
}

; 根目录散落文件迁入 config / lib / assets / tools / archive
Nmer_MigrateRootLayout(*) {
    root := A_ScriptDir
    cfg := Nmer_ConfigDir()
    lib := Nmer_LibDir()
    assets := root . "\assets"
    archive := root . "\archive"
    te := Nmer_ToolsDir() . "\everything"
    dev := Nmer_ToolsDir() . "\dev"
    if !DirExist(lib . "\64bit")
        try DirCreate(lib . "\64bit")
    if !DirExist(lib . "\runtime\64bit")
        try DirCreate(lib . "\runtime\64bit")
    if !DirExist(archive)
        try DirCreate(archive)
    Nmer_MigrateFileIfMissing(root . "\Commands.json", cfg . "\Commands.json")
    Nmer_MigrateDbSetIfMissing(root . "\Everything.db", te . "\Everything.db")
    Nmer_MigrateFileIfMissing(root . "\Everything.ini", te . "\Everything.ini")
    rt := lib . "\runtime"
    rt64 := rt . "\64bit"
    Nmer_MigrateFileIfMissing(root . "\sqlite3.dll", rt . "\sqlite3.dll")
    Nmer_MigrateFileIfMissing(root . "\tools\sqlite3.dll", rt . "\sqlite3.dll")
    Nmer_MigrateFileIfMissing(lib . "\sqlite3.dll", rt . "\sqlite3.dll")
    Nmer_MigrateFileIfMissing(root . "\WebView2Loader.dll", rt64 . "\WebView2Loader.dll")
    Nmer_MigrateFileIfMissing(lib . "\WebView2Loader.dll", rt64 . "\WebView2Loader.dll")
    Nmer_MigrateFileIfMissing(lib . "\64bit\WebView2Loader.dll", rt64 . "\WebView2Loader.dll")
    Nmer_MigrateFileIfMissing(root . "\牛马.ico", assets . "\牛马.ico")
    Nmer_MigrateFileIfMissing(root . "\牛马.png", assets . "\牛马.png")
    Nmer_MigrateFileIfMissing(root . "\serve3000.js", dev . "\serve3000.js")
    Nmer_MigrateFileIfMissing(root . "\enigma.enigma64", archive . "\enigma.enigma64")
    Nmer_MigrateFileIfMissing(root . "\original.txt", archive . "\original.txt")
    Nmer_MigrateLibLayout()
    Nmer_MigrateScriptsLayout()
    Nmer_EnsureSqliteDbIni()
    localIni := Nmer_MainConfigFile()
    if FileExist(localIni) && FileExist(root . "\CursorShortcut.ini") {
        try {
            if (FileGetSize(root . "\CursorShortcut.ini") < 4096)
                FileDelete(root . "\CursorShortcut.ini")
        } catch {
        }
    }
}

; lib/ 内 ahk、runtime、图标与调试脚本归类
Nmer_MigrateLibLayout(*) {
    root := A_ScriptDir
    lib := Nmer_LibDir()
    ahk := Nmer_LibAhkDir()
    dev := lib . "\dev"
    rt := Nmer_LibRuntimeDir()
    rt64 := Nmer_LibRuntime64Dir()
    ai := Nmer_AssetsIconsAiDir()
    app := Nmer_AssetsIconsAppDir()
    archLib := root . "\archive\lib"
    for d in [ahk, dev, rt, rt64, ai, app, archLib]
        if !DirExist(d)
            try DirCreate(d)

    runtimeFiles := [
        "sqlite3.dll", "SQLite3.dll", "fuzz.dll", "vec0.dll", "pdfium.dll", "ffmpeg.dll",
        "libcurl.dll", "Everything32.dll", "7-zip.dll", "7-zip32.dll", "7z.dll",
        "icudtl.dat", "7z.exe", "ffmpeg.exe", "ffprobe.exe"
    ]
    for name in runtimeFiles
        Nmer_MigrateFileIfMissing(lib . "\" . name, rt . "\" . name)

    libAhks := [
        "Class_SQLiteDB.ahk", "ComVar.ahk", "Gdip_All.ahk", "ImagePut.ahk", "Jxon.ahk",
        "Neutron.ahk", "OCR.ahk", "Promise.ahk", "SimpleJSON.ahk", "WebView2.ahk",
        "WinClip.ahk", "WinClipAPI.ahk"
    ]
    for name in libAhks
        Nmer_MigrateFileIfMissing(lib . "\" . name, ahk . "\" . name)

    devAhks := [
        "check_dependencies.ahk", "class_test.ahk", "complete_verify.ahk", "curser.ahk",
        "debug_load.ahk", "final_check.ahk", "final_test.ahk", "final_verification.ahk",
        "jxon_basic_test.ahk", "jxon_console_test.ahk", "jxon_test_console.ahk",
        "minimal_test.ahk", "quick_check.ahk", "quick_verify.ahk", "setup_environment.ahk",
        "syntax_check.ahk"
    ]
    for name in devAhks
        Nmer_MigrateFileIfMissing(lib . "\" . name, dev . "\" . name)

    Nmer_MigrateTreeIfMissing(root . "\aiicons", ai)
    Nmer_MigrateTreeIfMissing(lib . "\images", app)
    Nmer_MigrateFileIfMissing(lib . "\EVERYTHING_SDK.txt", archLib . "\EVERYTHING_SDK.txt")
    Nmer_MigrateFileIfMissing(lib . "\README_curser.md", archLib . "\README_curser.md")
}

; scripts/ 迁入 tools/voice-cli、tools/ci、tools/dev
Nmer_MigrateScriptsLayout(*) {
    root := A_ScriptDir
    scripts := root . "\scripts"
    voice := Nmer_VoiceCliDir()
    ci := Nmer_CiDir()
    probes := Nmer_CiProbesDir()
    dev := Nmer_ToolsDir() . "\dev"
    archDev := root . "\archive\dev-scripts"
    if !DirExist(archDev)
        try DirCreate(archDev)

    voiceFiles := ["gemini_env.ps1", "gemini_native_terminal.ps1", "cli_queue_worker.ps1", "cli_window_bridge.py"]
    for name in voiceFiles
        Nmer_MigrateFileIfMissing(scripts . "\" . name, voice . "\" . name)

    ciPs1 := [
        "LockAsyncAcceptance.ps1", "ValidateFourRefactors.ps1", "ValidateCloudPlayerAsyncFlow.ps1",
        "ValidateVoiceInputFsm.ps1", "CollectStaleDropLogs.ps1", "ValidateRequestIdStaleContract.ps1",
        "ValidateAsyncGuardrails.ps1", "RunRecoveryProbeE2E.ps1", "ValidateCloudPlayerStale.ps1",
        "ValidateRecoveryProbe.ps1", "RunAsyncGuardrailsE2E.ps1", "TryAhkLaunchMatrix.ps1",
        "DiagnoseAhkRuntime.ps1"
    ]
    for name in ciPs1
        Nmer_MigrateFileIfMissing(scripts . "\" . name, ci . "\" . name)

    probeFiles := [
        "CoreAsyncHttpStress.ahk", "RecoveryProbeListener.ps1", "CoreAsyncHttpRecoveryProbe.ahk",
        "CloudPlayerStaleRaceProbe.ahk", "_ahk_probe.ahk"
    ]
    for name in probeFiles
        Nmer_MigrateFileIfMissing(scripts . "\" . name, probes . "\" . name)

    devFiles := [
        "run_global_drag_hole_overlay.ahk", "test-ftb-json.ahk", "import_hub_dicts.py",
        "fix-motion-tag.js", "fix-ftb-html-closes.js", "fix-ftb-strings.js", "check-ftb-js.js",
        "clear-ftb-static-btns.js", "clear-ftb-static-btns.py", "restore-ftb-html.py",
        "find-good-ftb-commit.py"
    ]
    for name in devFiles
        Nmer_MigrateFileIfMissing(scripts . "\" . name, dev . "\" . name)

    Nmer_MigrateFileIfMissing(scripts . "\ftb-commit-scan.txt", archDev . "\ftb-commit-scan.txt")
    Nmer_MigrateFileIfMissing(scripts . "\GLOBAL_DRAG_HOLE_README.md", archDev . "\GLOBAL_DRAG_HOLE_README.md")
}
