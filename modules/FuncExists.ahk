#Requires AutoHotkey v2.0

; 可选依赖探测：v2 无内置 FuncExists，且 hostObjects.sync 中 IsFunc 常误报
FuncExists(fnName) {
    fnName := Trim(String(fnName))
    if (fnName = "")
        return false
    static cache := Map()
    if cache.Has(fnName)
        return cache[fnName]
    try {
        if IsSet(g_Nmer_AppShuttingDown) && (g_Nmer_AppShuttingDown || g_Nmer_WailsBridgeShuttingDown)
            return false
    } catch {
    }
    exists := false
    try {
        fnRef := %fnName%
        exists := IsObject(fnRef)
    } catch as _e1 {
        try {
            Func(fnName)
            exists := true
        } catch as _e2 {
            exists := false
        }
    }
    cache[fnName] := exists
    return exists
}
