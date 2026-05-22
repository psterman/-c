#Requires AutoHotkey v2.0
; 黑洞激活统一入口：划选 / 画圈 / 长按右键 等触发源解耦到本模块，由路由分派到 GDHO/SelectionSense。

global g_HoleAct_GestureGraceUntil := 0

HoleActivation_ArmGestureGrace(ms := 3200) {
    global g_HoleAct_GestureGraceUntil
    g_HoleAct_GestureGraceUntil := A_TickCount + Max(800, Integer(ms))
}

HoleActivation_IsGestureGraceActive() {
    global g_HoleAct_GestureGraceUntil
    return (g_HoleAct_GestureGraceUntil > A_TickCount)
}

HoleActivation_NormalizeSource(source, reason := "") {
    s := StrLower(Trim(String(source)))
    r := StrLower(Trim(String(reason)))
    if (s = "")
        s := r
    if (InStr(s, "selection") || InStr(s, "text_select") || InStr(s, "sel_"))
        return "selection"
    if (InStr(s, "free_circle_cw") || InStr(s, "circle_cw") || s = "cw")
        return "gesture_circle_cw"
    if (InStr(s, "free_circle_ccw") || InStr(s, "circle_ccw") || s = "ccw")
        return "gesture_circle_ccw"
    if (InStr(s, "rbutton_hold") || InStr(s, "hold"))
        return "gesture_hold"
    if (InStr(s, "gesture") || InStr(s, "circle"))
        return "gesture"
    return s != "" ? s : "gesture"
}

HoleActivation_IsGestureSource(source) {
    s := HoleActivation_NormalizeSource(source)
    return (s = "gesture" || InStr(s, "gesture_") = 1)
}

HoleActivation_Log(msg) {
    try NativeDropDiag_Log(String(msg))
    catch {
    }
    if FuncExists("HoleTriggers_DiagLog") {
        try HoleTriggers_DiagLog(String(msg))
        catch {
        }
    }
}

; 统一激活：返回是否已成功分派（含已展示启动层）
HoleActivation_OpenAt(x, y, source := "gesture", reason := "") {
    ax := Integer(x), ay := Integer(y)
    if (ax = 0 && ay = 0) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&ax, &ay)
    }
    src := HoleActivation_NormalizeSource(source, reason)
    rsn := Trim(String(reason)) != "" ? String(reason) : src
    dec := false
    if FuncExists("GDHO_IsDecoupled") {
        try dec := GDHO_IsDecoupled()
        catch {
        }
    }
    HoleActivation_Log("[HoleActivation] open_at src=" . src . " x=" . ax . " y=" . ay . " dec=" . (dec ? "1" : "0"))

    if (src = "selection") {
        if FuncExists("GDHO_OpenSelectionTextPreview") {
            try {
                GDHO_OpenSelectionTextPreview(ax, ay)
                return true
            } catch as e {
                HoleActivation_Log("[HoleActivation] selection_open_fail msg=" . e.Message)
            }
        }
        return false
    }

    if FuncExists("GDHO_PresentGestureHoleAt") {
        try {
            ok := GDHO_PresentGestureHoleAt(ax, ay, rsn)
            HoleActivation_Log("[HoleActivation] gesture_present ok=" . (ok ? "1" : "0") . " reason=" . rsn)
            if ok
                return true
        } catch as e {
            HoleActivation_Log("[HoleActivation] gesture_present_fail msg=" . e.Message)
        }
    }
    if FuncExists("GDHO_OpenGestureHoleAt") {
        try {
            ok := GDHO_OpenGestureHoleAt(ax, ay, rsn)
            HoleActivation_Log("[HoleActivation] gesture_open_legacy ok=" . (ok ? "1" : "0"))
            if ok
                return true
        } catch as e2 {
            HoleActivation_Log("[HoleActivation] gesture_open_legacy_fail msg=" . e2.Message)
        }
    }
    if FuncExists("SelectionSense_ArmHoleGesturePreview") {
        try SelectionSense_ArmHoleGesturePreview(ax, ay)
        catch {
        }
    }
    if FuncExists("GDHO_ShowTextDragAt") {
        try {
            GDHO_ShowTextDragAt(ax, ay, true)
            return true
        } catch {
        }
    }
    return false
}
