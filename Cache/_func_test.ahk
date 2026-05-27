#Requires AutoHotkey v2.0
#Include lib\Jxon.ahk
FuncExists(fnName) {
    try {
        Func(fnName)
        return true
    } catch as _e {
        return false
    }
}
#Include modules\UserStudio.ahk
lines := []
lines.Push("ApplyFromWebPayload=" . (FuncExists("UserStudio_ApplyFromWebPayload") ? "yes" : "no"))
lines.Push("ApplyLlmCardsFlat=" . (FuncExists("UserStudio_ApplyLlmCardsFlat") ? "yes" : "no"))
lines.Push("Load=" . (FuncExists("UserStudio_Load") ? "yes" : "no"))
try {
    UserStudio_ApplyFromWebPayload(Map("llm", Map("provider", "minimax", "apiKey", "sk-test", "baseUrl", "https://api.minimaxi.com/anthropic", "model", "MiniMax-M2.7"), "options", Map("llmCardProviders", ["minimax"])))
    lines.Push("apply_ok=1")
} catch as e {
    lines.Push("apply_err=" . e.Message)
}
FileAppend(lines.Join("`n") . "`n", A_ScriptDir . "\Cache\_func_test.out.txt", "UTF-8")
