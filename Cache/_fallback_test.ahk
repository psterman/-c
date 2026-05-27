#Requires AutoHotkey v2.0
#Include lib\Jxon.ahk
ConfigWebView_UserStudioPath() {
    return A_ScriptDir . "\config\user_studio.json"
}
ConfigWebView_FallbackWriteUserStudioJson(payload) {
    if !(payload is Map)
        payload := Map()
    dir := A_ScriptDir . "\config"
    if !DirExist(dir)
        DirCreate(dir)
    path := ConfigWebView_UserStudioPath()
    doc := Map("version", 1, "llm", Map("provider", "openai", "apiKey", "", "baseUrl", "https://api.openai.com/v1", "model", "gpt-4o-mini"), "paths", Map("cursor", "", "autohotkey", "", "everything", "", "python", "", "notes", ""), "options", Map(), "updatedAt", "")
    if FileExist(path) {
        try {
            parsed := Jxon_Load(FileRead(path, "UTF-8"))
            if (parsed is Map)
                doc := parsed
        } catch {
        }
    }
    if !(doc.Has("options") && doc["options"] is Map)
        doc["options"] := Map()
    if payload.Has("llm") && payload["llm"] is Map {
        for k, v in payload["llm"]
            doc["llm"][k] := v
    }
    if payload.Has("options") && payload["options"] is Map {
        optIn := payload["options"]
        opt := doc["options"] is Map ? doc["options"].Clone() : Map()
        if optIn.Has("llmCardProviders") && optIn["llmCardProviders"] is Array
            opt["llmCardProviders"] := optIn["llmCardProviders"].Clone()
        if optIn.Has("llmApiKeys") && optIn["llmApiKeys"] is Map
            opt["llmApiKeys"] := optIn["llmApiKeys"].Clone()
        doc["options"] := opt
    }
    doc["updatedAt"] := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    f := FileOpen(path, "w", "UTF-8")
    f.Write(Jxon_Dump(doc))
    f.Close()
}
payload := Map(
    "llm", Map("provider", "minimax", "apiKey", "sk-test123", "baseUrl", "https://api.minimaxi.com/anthropic", "model", "MiniMax-M2.7"),
    "options", Map("llmCardProviders", ["minimax"], "llmApiKeys", Map("minimax", "sk-test123"))
)
ConfigWebView_FallbackWriteUserStudioJson(payload)
FileAppend("ok`n", A_ScriptDir . "\Cache\_fallback_ok.txt", "UTF-8")
