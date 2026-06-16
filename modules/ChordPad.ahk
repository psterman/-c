; ChordPad.ahk — CapsLock 长按临时和弦键盘（可视选择，不抢焦点）

#Requires AutoHotkey v2.0
#Include FuncExists.ahk
global g_ChordPad_Gui := 0
global g_ChordPad_WV2 := 0
global g_ChordPad_Ctrl := 0
global g_ChordPad_Ready := false
global g_ChordPad_Visible := false
global g_ChordPad_X := 0
global g_ChordPad_Y := 0
global g_ChordPad_W := 0
global g_ChordPad_H := 0
global g_ChordPad_UseSavedPos := false
global g_ChordPad_DragActive := false
global g_ChordPad_DragAnchorX := 0
global g_ChordPad_DragAnchorY := 0

ChordPad_DefaultCatalog() {
    return [
        Map("action", "C", "label", "收集", "cmdId", "ch_c", "defaultKey", "c"),
        Map("action", "V", "label", "剪贴板", "cmdId", "ch_v", "defaultKey", "v"),
        Map("action", "X", "label", "历史", "cmdId", "ch_x", "defaultKey", "x"),
        Map("action", "E", "label", "解释", "cmdId", "ch_e", "defaultKey", "e"),
        Map("action", "Q", "label", "设置", "cmdId", "ch_q", "defaultKey", "q"),
        Map("action", "F", "label", "搜索", "cmdId", "ch_f", "defaultKey", "f"),
        Map("action", "R", "label", "重构", "cmdId", "ch_r", "defaultKey", "r"),
        Map("action", "O", "label", "优化", "cmdId", "ch_o", "defaultKey", "o"),
    ]
}

ChordPad_ResolveKeyForAction(action) {
    global HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyQ, HotkeyF, HotkeyR, HotkeyO
    action := StrUpper(Trim(String(action)))
    key := ""
    switch action {
        case "C": key := HotkeyC
        case "V": key := HotkeyV
        case "X": key := HotkeyX
        case "E": key := HotkeyE
        case "Q": key := HotkeyQ
        case "F": key := HotkeyF
        case "R": key := HotkeyR
        case "O": key := HotkeyO
    }
    key := StrLower(Trim(String(key)))
    if (key = "" || key = "none")
        return ""
    return SubStr(key, 1, 1)
}

ChordPad_BuildSlots() {
    slots := []
    for item in ChordPad_DefaultCatalog() {
        action := item["action"]
        key := ChordPad_ResolveKeyForAction(action)
        if (key = "")
            key := StrLower(item["defaultKey"])
        cmdId := item["cmdId"]
        score := FuncExists("ChordUsage_GetScore") ? ChordUsage_GetScore(cmdId) : 0.0
        slots.Push(Map(
            "key", key,
            "label", item["label"],
            "cmdId", cmdId,
            "action", action,
            "score", score
        ))
    }
    if FuncExists("ChordUsage_SortSlots")
        return ChordUsage_SortSlots(slots)
    return slots
}

ChordPad_IsVisible() {
    global g_ChordPad_Visible
    return !!g_ChordPad_Visible
}

ChordPad_PosPath(*) {
    if FuncExists("Nmer_DataStatePath")
        return Nmer_DataStatePath("chord_pad_pos.json")
    return A_ScriptDir . "\Data\state\chord_pad_pos.json"
}

ChordPad_LoadPosConfig() {
    global g_ChordPad_X, g_ChordPad_Y, g_ChordPad_UseSavedPos
    g_ChordPad_UseSavedPos := false
    path := ChordPad_PosPath()
    if !FileExist(path)
        return
    try {
        raw := FileRead(path, "UTF-8")
        if (raw = "")
            return
        doc := Jxon_Load(raw)
        if !(doc is Map)
            return
        if !doc.Get("custom", false)
            return
        g_ChordPad_X := Integer(doc.Get("x", 0))
        g_ChordPad_Y := Integer(doc.Get("y", 0))
        g_ChordPad_UseSavedPos := true
    } catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
    }
}

ChordPad_SavePosFromGui() {
    global g_ChordPad_Gui, g_ChordPad_W, g_ChordPad_H
    if !g_ChordPad_Gui
        return false
    try WinGetPos(&x, &y, &w, &h, g_ChordPad_Gui)
    catch {
        return false
    }
    path := ChordPad_PosPath()
    try {
        parent := ""
        SplitPath(path, , &parent)
        if (parent != "" && !DirExist(parent))
            DirCreate(parent)
        payload := Map("custom", true, "x", x, "y", y, "w", w, "h", h)
        FileDelete(path)
        f := FileOpen(path, "w", "UTF-8")
        if !IsObject(f)
            return false
        f.Write(Jxon_Dump(payload))
        f.Close()
        return true
    } catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
        return false
    }
}

ChordPad_ClampPos(x, y, w, h, monitor := 0) {
    mon := monitor ? monitor : 1
    try {
        if !monitor
            mon := MonitorGetPrimary()
    } catch {
        mon := 1
    }
    MonitorGetWorkArea(mon, &l, &t, &r, &b)
    maxX := Max(l, r - w)
    maxY := Max(t, b - h)
    return [Max(l, Min(x, maxX)), Max(t, Min(y, maxY))]
}

ChordPad_ComputeBounds(monitor := 0) {
    global g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, g_ChordPad_UseSavedPos
    mon := monitor ? monitor : 1
    try {
        if !monitor
            mon := MonitorGetPrimary()
    } catch {
        mon := 1
    }
    MonitorGetWorkArea(mon, &l, &t, &r, &b)
    waW := Max(640, r - l)
    waH := Max(480, b - t)
    stripH := Max(260, Min(Round(waH * 0.36), 420))
    g_ChordPad_W := waW
    g_ChordPad_H := stripH
    ChordPad_LoadPosConfig()
    if !g_ChordPad_UseSavedPos {
        g_ChordPad_X := l
        g_ChordPad_Y := b - stripH
    }
    clamped := ChordPad_ClampPos(g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, mon)
    g_ChordPad_X := clamped[1]
    g_ChordPad_Y := clamped[2]
}

ChordPad_BeginHostDrag(*) {
    global g_ChordPad_Gui, g_ChordPad_DragActive, g_ChordPad_DragAnchorX, g_ChordPad_DragAnchorY
    if !g_ChordPad_Gui || g_ChordPad_DragActive
        return false
    if !GetKeyState("LButton", "P")
        return false
    CoordMode("Mouse", "Screen")
    MouseGetPos(&g_ChordPad_DragAnchorX, &g_ChordPad_DragAnchorY)
    g_ChordPad_DragActive := true
    SetTimer(ChordPad_DragTick, 16)
    return true
}

ChordPad_DragTick(*) {
    global g_ChordPad_Gui, g_ChordPad_DragActive, g_ChordPad_DragAnchorX, g_ChordPad_DragAnchorY
    global g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, g_ChordPad_UseSavedPos
    if !g_ChordPad_DragActive || !g_ChordPad_Gui {
        ChordPad_EndDrag()
        return
    }
    if !GetKeyState("LButton", "P") {
        ChordPad_EndDrag()
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    dx := mx - g_ChordPad_DragAnchorX
    dy := my - g_ChordPad_DragAnchorY
    if (dx = 0 && dy = 0)
        return
    g_ChordPad_DragAnchorX := mx
    g_ChordPad_DragAnchorY := my
    try WinGetPos(&x, &y, &w, &h, g_ChordPad_Gui)
    catch {
        ChordPad_EndDrag()
        return
    }
    clamped := ChordPad_ClampPos(x + dx, y + dy, w, h)
    nx := clamped[1]
    ny := clamped[2]
    g_ChordPad_X := nx
    g_ChordPad_Y := ny
    g_ChordPad_W := w
    g_ChordPad_H := h
    g_ChordPad_UseSavedPos := true
    try WinMove(nx, ny, w, h, g_ChordPad_Gui)
    catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
    }
}

ChordPad_EndDrag(*) {
    global g_ChordPad_DragActive
    if !g_ChordPad_DragActive
        return
    g_ChordPad_DragActive := false
    SetTimer(ChordPad_DragTick, 0)
    ChordPad_SyncPosAfterMove()
}

ChordPad_SyncPosAfterMove() {
    global g_ChordPad_Gui, g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, g_ChordPad_UseSavedPos
    if !g_ChordPad_Gui
        return
    try WinGetPos(&x, &y, &w, &h, g_ChordPad_Gui)
    catch {
        return
    }
    clamped := ChordPad_ClampPos(x, y, w, h)
    nx := clamped[1]
    ny := clamped[2]
    if (nx != x || ny != y) {
        try WinMove(nx, ny, w, h, g_ChordPad_Gui)
        catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }
    g_ChordPad_X := nx
    g_ChordPad_Y := ny
    g_ChordPad_W := w
    g_ChordPad_H := h
    g_ChordPad_UseSavedPos := true
    ChordPad_SavePosFromGui()
}

ChordPad_OnExitSizeMove(wParam, lParam, msg, hwnd) {
    global g_ChordPad_Gui
    if !IsObject(g_ChordPad_Gui) || (hwnd != g_ChordPad_Gui.Hwnd)
        return
    ChordPad_SyncPosAfterMove()
}

ChordPad_RunSlot(action, cmdId := "", key := "") {
    action := StrUpper(Trim(String(action)))
    cmdId := Trim(String(cmdId))
    key := StrLower(Trim(String(key)))

    try SetTimer(ShowPanelTimer, 0)
    catch as _e {
    }
    global CapsLock2
    CapsLock2 := false
    if FuncExists("RestoreCapsLockAfterChord")
        RestoreCapsLockAfterChord()
    if (key != "") && FuncExists("ChordPad_FlashKey")
        ChordPad_FlashKey(key)

    if (cmdId != "") && FuncExists("VK_Execute") {
        try {
            if VK_Execute(cmdId) {
                if FuncExists("VK_NoteLastExecutedId")
                    VK_NoteLastExecutedId(cmdId)
                if FuncExists("ChordUsage_Record")
                    ChordUsage_Record(cmdId)
                return true
            }
        } catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }

    if FuncExists("CursorPanel_RunQuickAction") {
        switch action {
            case "E":
                CursorPanel_RunQuickAction("Explain")
                if FuncExists("ChordUsage_Record")
                    ChordUsage_Record(cmdId != "" ? cmdId : "ch_e")
                return true
            case "R":
                CursorPanel_RunQuickAction("Refactor")
                if FuncExists("ChordUsage_Record")
                    ChordUsage_Record(cmdId != "" ? cmdId : "ch_r")
                return true
            case "O":
                CursorPanel_RunQuickAction("Optimize")
                if FuncExists("ChordUsage_Record")
                    ChordUsage_Record(cmdId != "" ? cmdId : "ch_o")
                return true
        }
    }

    if (action != "") && FuncExists("HandleDynamicHotkey") {
        pressKey := key != "" ? key : StrLower(action)
        try {
            if HandleDynamicHotkey(pressKey, action) {
                if FuncExists("VK_NoteLastChFromCapsLockKey")
                    VK_NoteLastChFromCapsLockKey(pressKey)
                return true
            }
        } catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }
    return false
}

ChordPad_ApplyTransparency() {
    global g_ChordPad_Gui, g_ChordPad_Ctrl
    if g_ChordPad_Gui {
        try g_ChordPad_Gui.BackColor := "010101"
        try WinSetTransColor("010101", g_ChordPad_Gui)
        try WinSetTransparent(255, g_ChordPad_Gui)
    }
    if g_ChordPad_Ctrl {
        try g_ChordPad_Ctrl.DefaultBackgroundColor := 0x00000000
        try g_ChordPad_Ctrl.IsVisible := true
    }
}

ChordPad_EnsureInit() {
    global g_ChordPad_Gui, g_ChordPad_W, g_ChordPad_H
    if g_ChordPad_Gui
        return true
    ChordPad_ComputeBounds()
    g_ChordPad_Gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80000 -DPIScale", "ChordPad")
    g_ChordPad_Gui.BackColor := "010101"
    g_ChordPad_Gui.MarginX := 0
    g_ChordPad_Gui.MarginY := 0
    g_ChordPad_Gui.OnEvent("Close", (*) => ChordPad_Hide())
    try g_ChordPad_Gui.OnMessage(0x0232, ChordPad_OnExitSizeMove)  ; WM_EXITSIZEMOVE
    g_ChordPad_Gui.Show("w" . g_ChordPad_W . " h" . g_ChordPad_H . " Hide")
    try WinSetExStyle("+0x08000000", g_ChordPad_Gui)  ; WS_EX_NOACTIVATE
    if !FuncExists("WebView2_CreateWithSharedEnvAsync")
        return false
    WebView2_CreateWithSharedEnvAsync(g_ChordPad_Gui.Hwnd, ChordPad_OnWV2Created, "chord_pad")
    return true
}

ChordPad_OnWV2Created(ctrl) {
    global g_ChordPad_WV2, g_ChordPad_Ctrl, g_ChordPad_Gui
    g_ChordPad_Ctrl := ctrl
    g_ChordPad_WV2 := ctrl.CoreWebView2
    try g_ChordPad_Ctrl.DefaultBackgroundColor := 0x00000000
    ChordPad_ApplyTransparency()
    ChordPad_ApplyBounds()
    s := g_ChordPad_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.AreDevToolsEnabled := false
    if FuncExists("ApplyWebView2PerformanceSettings")
        ApplyWebView2PerformanceSettings(g_ChordPad_WV2)
    try Func("WebView2_RegisterHostBridge").Call(g_ChordPad_WV2)
    g_ChordPad_WV2.add_WebMessageReceived(ChordPad_OnWebMessage)
    try g_ChordPad_WV2.add_NavigationCompleted(ChordPad_OnNavigationCompleted)
    if FuncExists("ApplyUnifiedWebViewAssets")
        try ApplyUnifiedWebViewAssets(g_ChordPad_WV2)
    if FuncExists("BuildAppLocalUrl")
        g_ChordPad_WV2.Navigate(BuildAppLocalUrl("ChordPad.html"))
}

ChordPad_ApplyBounds() {
    global g_ChordPad_Gui, g_ChordPad_Ctrl, g_ChordPad_W, g_ChordPad_H
    if !g_ChordPad_Ctrl || !g_ChordPad_Gui
        return
    try {
        rc := WebView2.RECT()
        rc.left := 0
        rc.top := 0
        rc.right := g_ChordPad_W
        rc.bottom := g_ChordPad_H
        g_ChordPad_Ctrl.Bounds := rc
    } catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
    }
}

ChordPad_OnNavigationCompleted(sender, args) {
    global g_ChordPad_Ready
    g_ChordPad_Ready := true
    ChordPad_PushInit()
}

ChordPad_OnWebMessage(sender, args) {
    try {
        raw := args.WebMessageAsJson
        msg := Jxon_Load(raw)
        if !(msg is Map)
            return
        t := msg.Get("type", "")
        switch t {
            case "chordPadReady":
                ChordPad_PushInit()
            case "chordPadBeginDrag":
                ChordPad_BeginHostDrag()
            case "chordPadRun":
                ChordPad_RunSlot(msg.Get("action", ""), msg.Get("cmdId", ""), msg.Get("key", ""))
        }
    } catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
    }
}

ChordPad_PushInit() {
    global g_ChordPad_WV2, g_ChordPad_Ready
    if !g_ChordPad_Ready || !g_ChordPad_WV2
        return
    slots := ChordPad_BuildSlots()
    arr := "["
    sep := ""
    for s in slots {
        arr .= sep . '{"key":' . ChordPad_JsonStr(s["key"])
            . ',"label":' . ChordPad_JsonStr(s["label"])
            . ',"cmdId":' . ChordPad_JsonStr(s["cmdId"])
            . ',"action":' . ChordPad_JsonStr(s["action"])
            . ',"tier":' . ChordPad_JsonStr(s.Get("tier", "normal"))
            . ',"rank":' . Round(Number(s.Get("rank", 99)))
            . ',"score":' . Round(Number(s.Get("score", 0)), 2) . '}'
        sep := ","
    }
    arr .= "]"
    hint := "按住 CapsLock，再按字母键执行 · 也可点击命令"
    payload := '{"type":"chordPadInit","hint":' . ChordPad_JsonStr(hint) . ',"slots":' . arr . '}'
    try g_ChordPad_WV2.PostWebMessageAsJson(payload)
    catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
    }
}

ChordPad_JsonStr(s) {
    s := String(s)
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    return '"' . s . '"'
}

ChordPad_PositionAndShow() {
    global g_ChordPad_Gui, g_ChordPad_X, g_ChordPad_Y, g_ChordPad_W, g_ChordPad_H, g_ChordPad_Visible
    if !g_ChordPad_Gui
        return false
    ChordPad_ComputeBounds()
    ChordPad_ApplyBounds()
    ChordPad_ApplyTransparency()
    try g_ChordPad_Gui.Show("x" . g_ChordPad_X . " y" . g_ChordPad_Y . " w" . g_ChordPad_W . " h" . g_ChordPad_H . " NoActivate")
    catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
        return false
    }
    try WinSetExStyle("+0x08000000", g_ChordPad_Gui)
    g_ChordPad_Visible := true
    ChordPad_PushInit()
    return true
}

ChordPad_Show(*) {
    ChordPad_EnsureInit()
    global g_ChordPad_Gui
    if !g_ChordPad_Gui
        return false
    return ChordPad_PositionAndShow()
}

ChordPad_Hide(*) {
    global g_ChordPad_Gui, g_ChordPad_Visible, g_ChordPad_WV2
    ChordPad_EndDrag()
    g_ChordPad_Visible := false
    if g_ChordPad_WV2 {
        try g_ChordPad_WV2.PostWebMessageAsJson('{"type":"chordPadHide"}')
        catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }
    if g_ChordPad_Gui {
        try g_ChordPad_Gui.Hide()
        catch as _e {
            if FuncExists("NmerCatch")
                NmerCatch(A_ThisFunc, _e)
        }
    }
}

ChordPad_FlashKey(key) {
    global g_ChordPad_WV2, g_ChordPad_Visible
    if !g_ChordPad_Visible || !g_ChordPad_WV2
        return
    k := StrLower(Trim(String(key)))
    if (k = "")
        return
    if (k = "escape" || k = "esc")
        k := "esc"
    try g_ChordPad_WV2.PostWebMessageAsJson('{"type":"keyPreview","key":' . ChordPad_JsonStr(k) . '}')
    catch as _e {
        if FuncExists("NmerCatch")
            NmerCatch(A_ThisFunc, _e)
    }
}
