#Requires AutoHotkey v2.0

; 可选依赖探测：v2 无内置 FuncExists，且 hostObjects.sync 中 IsFunc 常误报
FuncExists(fnName) {
    fnName := Trim(String(fnName))
    if (fnName = "")
        return false
    try {
        fnRef := %fnName%
        return IsObject(fnRef)
    } catch as _e1 {
    }
    try {
        Func(fnName)
        return true
    } catch as _e2 {
        return false
    }
}
