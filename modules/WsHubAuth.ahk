#Requires AutoHotkey v2.0

; WsHubAuth — 内部 WebSocket hub 会话 token（127.0.0.1）

Nmer_WsHubTokenPath(*) {
    return Nmer_LocalDir() . "\ws_hub_token.txt"
}

Nmer_GetOrCreateWsHubToken(*) {
    Nmer_EnsureLocalDir()
    path := Nmer_WsHubTokenPath()
    if FileExist(path) {
        tok := Trim(FileRead(path, "UTF-8"))
        if (tok != "")
            return tok
    }
    tok := ""
    Loop 32
        tok .= Format("{:02x}", Random(0, 255))
    try FileDelete(path)
    FileAppend(tok, path, "UTF-8")
    return tok
}

Nmer_WsHubTokenQuery(*) {
    tok := Nmer_GetOrCreateWsHubToken()
    return "?token=" . _Nmer_UriEncode(tok)
}

Nmer_WsHubTokenUrlSuffix(*) {
    return Nmer_WsHubTokenQuery()
}

Nmer_EnsureWsHubTokenEnv(*) {
    tok := Nmer_GetOrCreateWsHubToken()
    try EnvSet("NMER_WS_HUB_TOKEN", tok)
    return tok
}

Nmer_WsHubWsUrl(baseUrl) {
    baseUrl := Trim(String(baseUrl))
    if (baseUrl = "")
        return ""
    sep := InStr(baseUrl, "?") ? "&" : "?"
    return baseUrl . sep . SubStr(Nmer_WsHubTokenQuery(), 2)
}

Nmer_WsHubTokenInjectPrefix(*) {
    tok := Nmer_GetOrCreateWsHubToken()
    esc := StrReplace(tok, "\", "\\")
    esc := StrReplace(esc, "'", "\'")
    return "window.__NMER_WS_TOKEN__='" . esc . "';"
}

_Nmer_UriEncode(s) {
    s := String(s)
    out := ""
    Loop Parse s {
        c := A_LoopField
        asc := Ord(c)
        if ((asc >= 48 && asc <= 57) || (asc >= 65 && asc <= 90) || (asc >= 97 && asc <= 122)
            || c = "-" || c = "_" || c = "." || c = "~")
            out .= c
        else
            out .= "%" . Format("{:02X}", asc)
    }
    return out
}
