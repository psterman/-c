; NmerPanelChrome.ahk — 面板最小化/任务栏与悬浮栏 dock 联动（由 ToolsPaths #Include）

NmerPanel_IsShown(hwnd) {
    hwnd := Integer(hwnd)
    if (hwnd <= 0)
        return false
    try {
        if !WinExist("ahk_id " hwnd)
            return false
        if !(WinGetStyle("ahk_id " hwnd) & 0x10000000)
            return false
        return WinGetMinMax("ahk_id " hwnd) != -1
    } catch {
        return false
    }
}

NmerPanel_IsMinimized(hwnd) {
    hwnd := Integer(hwnd)
    if (hwnd <= 0)
        return false
    try return WinGetMinMax("ahk_id " hwnd) = -1
    catch {
        return false
    }
}

NmerPanel_RestoreGui(gui) {
    if !(IsObject(gui) && gui.HasProp("Hwnd"))
        return false
    try {
        hwnd := gui.Hwnd
        if NmerPanel_IsMinimized(hwnd) {
            WinRestore("ahk_id " hwnd)
            return true
        }
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return false
}

NmerPanel_MinimizeGui(gui, dockTag := "") {
    if !(IsObject(gui) && gui.HasProp("Hwnd"))
        return false
    try {
        if !NmerPanel_IsShown(gui.Hwnd)
            return false
        WinMinimize("ahk_id " . gui.Hwnd)
        tag := Trim(String(dockTag))
        if (tag != "" && FuncExists("FloatingToolbar_PageDockLeave"))
            FloatingToolbar_PageDockLeave(tag)
        return true
    } catch {
        return false
    }
}

NmerPanel_OnGuiMinimized(MinMax, dockTag := "") {
    if (Integer(MinMax) != -1)
        return
    tag := Trim(String(dockTag))
    if (tag != "" && FuncExists("FloatingToolbar_PageDockLeave"))
        FloatingToolbar_PageDockLeave(tag)
}

NmerPanel_OnGuiRestoredFromMinimize(MinMax, wasMinimized, dockTag := "") {
    if !(wasMinimized && Integer(MinMax) >= 0)
        return
    tag := Trim(String(dockTag))
    if (tag != "" && FuncExists("FloatingToolbar_PageDockEnter"))
        FloatingToolbar_PageDockEnter(tag)
}
