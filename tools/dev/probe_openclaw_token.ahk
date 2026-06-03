#Requires AutoHotkey v2.0

; Load Jxon for proper JSON parsing
#Include %A_ScriptDir%\..\..\lib\ahk\Jxon.ahk

ExtractFromRaw(raw) {
    out := Map("token", "", "host", "127.0.0.1", "port", 18789)
    raw := Trim(String(raw))
    if (Ord(SubStr(raw, 1, 1)) = 0xFEFF)
        raw := SubStr(raw, 2)
    if (raw = "")
        return out

    ; Method 1: Try JSON parsing (proper and reliable)
    try {
        cfg := Jxon_Load(raw)
        ; Navigate: gateway -> auth -> token
        if (cfg is Map && cfg.Has("gateway") && cfg["gateway"] is Map) {
            gw := cfg["gateway"]
            if (gw.Has("auth") && gw["auth"] is Map) {
                auth := gw["auth"]
                tok := Trim(String(auth.Get("token", "")))
                if (tok != "") {
                    out["token"] := tok
                    if (gw.Has("port"))
                        out["port"] := Integer(gw["port"])
                    return out
                }
            }
            ; Also check gateway.token directly (flat structure)
            tok := Trim(String(gw.Get("token", "")))
            if (tok != "") {
                out["token"] := tok
                if (gw.Has("port"))
                    out["port"] := Integer(gw["port"])
                return out
            }
        }
    } catch as e {
        ; JSON parse failed, fall through to regex
    }

    ; Method 2: Regex fallback for edge cases
    ; Find "gateway" block
    if RegExMatch(raw, 'i)"gateway"\s*:\s*\{', &gwPos) {
        ; Extract a chunk from gateway to end of block (up to 16000 chars)
        chunk := SubStr(raw, gwPos[0], 16000)

        ; Try nested brace matching: find auth -> { ... } -> token
        ; Use a helper to find balanced braces
        authStart := 0
        loop {
            if !RegExMatch(chunk, 'i)"auth"\s*:\s*\{', &m, authStart)
                break
            ; m[0] is "auth": {
            ; Position after this match
            startPos := gwPos[0] + gwPos.Len - 1 + m.Len - 1
            ; Actually easier: find balanced {} from here
            ; Simple approach: search for "token" within a reasonable range after auth
            searchStart := gwPos[0] + m.Len - 1
            ; Try to find token value after this auth block
            ; Extract the entire auth block by counting braces
            authOpenPos := searchStart + 1
            braceCount := 1
            authEndPos := authOpenPos
            while (braceCount > 0 && authEndPos < chunk.Length) {
                c := SubStr(chunk, authEndPos, 1)
                if (c = "{") {
                    braceCount++
                } else if (c = "}") {
                    braceCount--
                }
                authEndPos++
            }
            authBlock := SubStr(chunk, searchStart, authEndPos - searchStart)
            ; Now find token in authBlock
            if RegExMatch(authBlock, 'i)"token"\s*:\s*"([^"]+)"', &t) {
                out["token"] := Trim(t[1])
                break
            }
            ; Move past this auth for next attempt
            authStart := authEndPos
        }

        ; Also try direct token in gateway block
        if (out["token"] = "") {
            if RegExMatch(chunk, 'i)"token"\s*:\s*"([^"]+)"', &t) {
                out["token"] := Trim(t[1])
            }
        }
        ; Try port
        if RegExMatch(chunk, 'i)"port"\s*:\s*(\d+)', &p) {
            out["port"] := Integer(p[1])
        }
    }

    return out
}

ResolveHome() {
    up := Trim(EnvGet("USERPROFILE"))
    if (up != "" && FileExist(up . "\.openclaw\openclaw.json"))
        return up
    if (A_AppData != "") {
        home := RegExReplace(A_AppData, "\\AppData\\Roaming$", "")
        if (home != "" && FileExist(home . "\.openclaw\openclaw.json"))
            return home
    }
    return up
}

out := A_ScriptDir . "\..\..\Cache\debug\openclaw_probe_test.log"
DirCreate(A_ScriptDir . "\..\..\Cache\debug")
lines := []
lines.Push("USERPROFILE=" . EnvGet("USERPROFILE"))
lines.Push("A_AppData=" . A_AppData)
home := ResolveHome()
lines.Push("resolveHome=" . home)
path := home . "\.openclaw\openclaw.json"
lines.Push("path=" . path)
lines.Push("exists=" . (FileExist(path) ? "yes" : "no"))
if FileExist(path) {
    raw := FileRead(path, "UTF-8")
    lines.Push("rawLen=" . StrLen(raw))
    meta := ExtractFromRaw(raw)
    tokenLen := StrLen(String(meta.Get("token", "")))
    lines.Push("tokenLen=" . tokenLen)
    lines.Push("tokenPrefix=" . SubStr(String(meta.Get("token", "")), 1, 4))
    lines.Push("port=" . meta.Get("port", ""))
}
FileAppend(lines.Join("`n") . "`n", out, "UTF-8")
ExitApp 0