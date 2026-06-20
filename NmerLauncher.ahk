; NmerLauncher.ahk — 启动前语法校验，失败则展示牛马 LoadError 对话框
#Requires AutoHotkey v2.0
#Include modules\FuncExists.ahk
#Include modules\LocalPaths.ahk
#Include modules\NmerDiagnostics.ahk
#Include modules\NmerLoadGuard.ahk

main := A_ScriptDir . "\牛马.ahk"
if (A_Args.Length >= 1 && FileExist(A_Args[1]))
    main := A_Args[1]
else if !FileExist(main) {
    main := A_ScriptDir . "\nmer_main_debug.ahk"
}
if !FileExist(main) {
    MsgBox("找不到主脚本（牛马.ahk / nmer_main_debug.ahk）", "牛马", 0x10)
    ExitApp(1)
}

err := ""
if !Nmer_ValidateMainScript(main, &err) {
    Nmer_TryShowLoadError(main, err, "startup")
    ExitApp(1)
}

try {
    Run('"' . A_AhkPath . '" "' . main . '"')
} catch as e {
    Nmer_TryShowLoadError(main, "启动主脚本失败: " . e.Message, "startup")
    ExitApp(1)
}
ExitApp(0)
