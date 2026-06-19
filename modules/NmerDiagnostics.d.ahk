; NmerDiagnostics 宿主符号声明（仅 LSP / IntelliSense，不参与运行）
; 与 modules\NmerDiagnostics.ahk 同名，vscode-autohotkey2-lsp 会自动 @reference

FuncExists(fnName) {
}

Nmer_TraceLogPath(*) {
}

NmerCatch(scope, err, detail := "") {
}

NMER_Log(scope, event, detail := "") {
}

Nmer_CollectHealthSnapshot(trigger := "") {
}

Nmer_CacheDir(*) {
}

Nmer_OpenDebugDir(*) {
}

Nmer_ShowLoadErrorDialog(errText, scriptPath := "", scene := "startup") {
}

Nmer_ShowUserErrorDialog(err, mode := "") {
}
