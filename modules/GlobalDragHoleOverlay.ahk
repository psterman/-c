#Requires AutoHotkey v2.0

; GlobalDragHoleOverlay.ahk
; AHK global drag pre-judge -> drive Wails/WebView2 hole frontend (window.HoleOverlay.*)

global GDHO_GUI := 0
global GDHO_WV2_CTRL := 0
global GDHO_WV2 := 0
global GDHO_READY := false
global GDHO_VISIBLE := false
global GDHO_ACTIVE := false
global GDHO_PAYLOAD := "file"
global GDHO_DRAG_SOURCE_CLASS := ""
global GDHO_START_X := 0
global GDHO_START_Y := 0
global GDHO_START_CURSOR := 0
global GDHO_LAST_X := 0
global GDHO_LAST_Y := 0
global GDHO_MONITORING := false
global GDHO_PAGE_URL := "http://127.0.0.1:5173/hole.html"

; drag pre-judge parameters
global GDHO_MIN_MOVE_PX := 10
global GDHO_POLL_MS := 16
global GDHO_MAX_IDLE_HIDE_MS := 160
global GDHO_LAST_UPDATE_TICK := 0
global GDHO_DESKTOP_PINNED := false
global GDHO_PIN_PAYLOAD := "text"

GDHO_ScreenVirtual_GetBounds(&outL, &outT, &outW, &outH) {
    outL := SysGet(76)
    outT := SysGet(77)
    outW := SysGet(78)
    outH := SysGet(79)
}

GDHO_SetPageUrl(url) {
    global GDHO_PAGE_URL
    u := Trim(String(url))
    if (u != "")
        GDHO_PAGE_URL := u
}

GDHO_Init() {
    global GDHO_GUI, GDHO_WV2_CTRL, GDHO_WV2, GDHO_READY
    global GDHO_VISIBLE

    if (GDHO_GUI)
        return

    GDHO_CreateOverlayGui()
    GDHO_WV2_CTRL := 0
    GDHO_WV2 := 0
    GDHO_READY := false
    GDHO_VISIBLE := false
    try WebView2.create(GDHO_GUI.Hwnd, GDHO_OnWebViewCreated, WebView2_EnsureSharedEnvBlocking())
}

GDHO_CreateOverlayGui() {
    global GDHO_GUI
    GDHO_ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    ; WS_EX_LAYERED + WS_EX_TRANSPARENT + WS_EX_NOACTIVATE
    GDHO_GUI := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08080020", "Global Drag Hole Overlay")
    GDHO_GUI.BackColor := "000000"
    ; Click-through + no activate overlay host.
    GDHO_GUI.Show("Hide x" vl " y" vt " w" vw " h" vh " NoActivate")
    ; Keep window normal opacity; visual transparency comes from WebView + trans color.
    try WinSetTransparent(255, "ahk_id " GDHO_GUI.Hwnd)
}

GDHO_OnWebViewCreated(ctrl) {
    global GDHO_WV2_CTRL, GDHO_WV2, GDHO_READY, GDHO_PAGE_URL

    if !IsObject(ctrl) || !ctrl.HasProp("CoreWebView2")
        return

    GDHO_WV2_CTRL := ctrl
    GDHO_WV2 := ctrl.CoreWebView2
    GDHO_READY := false

    try ctrl.IsVisible := true
    try ctrl.DefaultBackgroundColor := 0x00000000
    GDHO_ResizeToVirtualScreen()
    try {
        s := GDHO_WV2.Settings
        s.AreDefaultContextMenusEnabled := false
        s.AreDevToolsEnabled := false
        s.AreBrowserAcceleratorKeysEnabled := false
    }
    try ApplyWebView2PerformanceSettings(GDHO_WV2)
    try WebView2_RegisterHostBridge(GDHO_WV2)
    try GDHO_WV2.add_NavigationCompleted(GDHO_OnNavigationCompleted)
    try GDHO_WV2.Navigate(GDHO_PAGE_URL)
}

GDHO_OnNavigationCompleted(sender, args) {
    global GDHO_READY, GDHO_GUI, GDHO_WV2_CTRL
    ok := false
    try ok := args.IsSuccess
    GDHO_READY := !!ok
    if GDHO_READY {
        ; Re-apply transparency after document init to avoid occasional white/black flash.
        try GDHO_WV2_CTRL.DefaultBackgroundColor := 0x00000000
        try WinSetTransColor("000000", "ahk_id " GDHO_GUI.Hwnd)
    }
}

GDHO_ResizeToVirtualScreen() {
    global GDHO_GUI, GDHO_WV2_CTRL
    if !(GDHO_GUI && GDHO_WV2_CTRL)
        return
    GDHO_ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    try GDHO_GUI.Move(vl, vt, vw, vh)
    rc := WebView2.RECT()
    rc.left := 0, rc.top := 0, rc.right := vw, rc.bottom := vh
    try GDHO_WV2_CTRL.Bounds := rc
}

GDHO_RunJS(js) {
    global GDHO_WV2, GDHO_READY
    if !(GDHO_WV2 && GDHO_READY)
        return false
    try {
        GDHO_WV2.ExecuteScript(js)
        return true
    } catch {
        return false
    }
}

GDHO_ShowOverlay() {
    global GDHO_GUI, GDHO_VISIBLE, GDHO_WV2
    if !GDHO_GUI
        return
    if !GDHO_VISIBLE {
        GDHO_ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        try GDHO_GUI.Show("x" vl " y" vt " w" vw " h" vh " NoActivate")
        GDHO_VISIBLE := true
        try WebView2_NotifyShown(GDHO_WV2)
    }
}

GDHO_HideOverlay() {
    global GDHO_GUI, GDHO_VISIBLE, GDHO_WV2
    if !GDHO_GUI
        return
    try WebView2_NotifyHidden(GDHO_WV2)
    try GDHO_GUI.Hide()
    GDHO_VISIBLE := false
}

GDHO_Show(payload := "file") {
    p := (payload = "text") ? "text" : "file"
    GDHO_ShowOverlay()
    GDHO_RunJS("window.HoleOverlay?.show('" p "')")
}

GDHO_Update(payload := "file", x := "", y := "") {
    global GDHO_LAST_UPDATE_TICK
    p := (payload = "text") ? "text" : "file"
    if (x = "" || y = "")
        GDHO_RunJS("window.HoleOverlay?.update({ payload: '" p "' })")
    else
        GDHO_RunJS("window.HoleOverlay?.update({ payload: '" p "', x: " Integer(x) ", y: " Integer(y) " })")
    GDHO_LAST_UPDATE_TICK := A_TickCount
}

GDHO_Drop(payload := "file") {
    p := (payload = "text") ? "text" : "file"
    GDHO_RunJS("window.HoleOverlay?.drop({ payload: '" p "' })")
}

GDHO_HideFrontend() {
    global GDHO_DESKTOP_PINNED, GDHO_PIN_PAYLOAD
    if GDHO_DESKTOP_PINNED {
        p := (GDHO_PIN_PAYLOAD = "file") ? "file" : "text"
        GDHO_RunJS("window.HoleOverlay?.show('" p "')")
        return
    }
    GDHO_RunJS("window.HoleOverlay?.hide()")
}

GDHO_Start() {
    global GDHO_MONITORING
    GDHO_Init()
    if GDHO_MONITORING
        return
    GDHO_MONITORING := true
    SetTimer(GDHO_PollDrag, GDHO_POLL_MS)
}

GDHO_Stop() {
    global GDHO_MONITORING, GDHO_ACTIVE
    GDHO_MONITORING := false
    GDHO_ACTIVE := false
    SetTimer(GDHO_PollDrag, 0)
    GDHO_HideFrontend()
    GDHO_HideOverlay()
}

GDHO_PinToDesktop(payload := "text") {
    global GDHO_DESKTOP_PINNED, GDHO_PIN_PAYLOAD, GDHO_ACTIVE
    p := (payload = "file") ? "file" : "text"
    GDHO_PIN_PAYLOAD := p
    GDHO_DESKTOP_PINNED := true
    GDHO_ACTIVE := false
    GDHO_Init()
    GDHO_ShowOverlay()
    if !GDHO_RunJS("window.HoleOverlay?.show('" p "')") {
        SetTimer((*) => GDHO_RunJS("window.HoleOverlay?.show('" p "')"), -180)
        SetTimer((*) => GDHO_RunJS("window.HoleOverlay?.show('" p "')"), -420)
    }
}

GDHO_UnpinFromDesktop() {
    global GDHO_DESKTOP_PINNED
    GDHO_DESKTOP_PINNED := false
    GDHO_HideFrontend()
    GDHO_HideOverlay()
}

; ===== Global drag pre-judge =====
; Strategy:
; 1) Detect left-button hold + movement threshold.
; 2) Use cursor-shape change OR explorer-like source class to reduce false positives.
; 3) If likely dragging payload, show/update overlay globally.
GDHO_PollDrag(*) {
    global GDHO_ACTIVE, GDHO_START_X, GDHO_START_Y, GDHO_LAST_X, GDHO_LAST_Y
    global GDHO_START_CURSOR, GDHO_DRAG_SOURCE_CLASS, GDHO_PAYLOAD
    global GDHO_MIN_MOVE_PX, GDHO_LAST_UPDATE_TICK, GDHO_MAX_IDLE_HIDE_MS

    lDown := GetKeyState("LButton", "P")
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my, &hwnd)

    if !lDown {
        if GDHO_ACTIVE {
            GDHO_Drop(GDHO_PAYLOAD)
            GDHO_ACTIVE := false
            SetTimer((*) => GDHO_HideOverlay(), -700)
        } else if (A_TickCount - GDHO_LAST_UPDATE_TICK > GDHO_MAX_IDLE_HIDE_MS) {
            GDHO_HideFrontend()
            GDHO_HideOverlay()
        }
        GDHO_ResetPointerSeed()
        return
    }

    if (GDHO_START_X = 0 && GDHO_START_Y = 0) {
        GDHO_START_X := mx
        GDHO_START_Y := my
        GDHO_LAST_X := mx
        GDHO_LAST_Y := my
        GDHO_START_CURSOR := GDHO_GetCursorHandle()
        GDHO_DRAG_SOURCE_CLASS := GDHO_GetClassByHwnd(hwnd)
        GDHO_PAYLOAD := GDHO_GuessPayloadType(GDHO_DRAG_SOURCE_CLASS)
        return
    }

    dx := mx - GDHO_START_X
    dy := my - GDHO_START_Y
    moved := (dx * dx + dy * dy) >= (GDHO_MIN_MOVE_PX * GDHO_MIN_MOVE_PX)
    if !moved
        return

    likelyDrag := GDHO_IsLikelyDrag(GDHO_DRAG_SOURCE_CLASS, GDHO_START_CURSOR)
    if !likelyDrag
        return

    if !GDHO_ACTIVE {
        GDHO_Show(GDHO_PAYLOAD)
        GDHO_ACTIVE := true
    }
    GDHO_Update(GDHO_PAYLOAD, mx, my)
    GDHO_LAST_X := mx
    GDHO_LAST_Y := my
}

GDHO_ResetPointerSeed(*) {
    global GDHO_START_X, GDHO_START_Y, GDHO_START_CURSOR, GDHO_DRAG_SOURCE_CLASS
    global GDHO_ACTIVE
    if GDHO_ACTIVE
        return
    GDHO_START_X := 0
    GDHO_START_Y := 0
    GDHO_START_CURSOR := 0
    GDHO_DRAG_SOURCE_CLASS := ""
}

GDHO_GetCursorHandle() {
    ci := Buffer(24, 0)
    NumPut("UInt", 24, ci, 0)
    if !DllCall("GetCursorInfo", "Ptr", ci.Ptr)
        return 0
    return NumGet(ci, 8, "Ptr")
}

GDHO_GetClassByHwnd(hwnd) {
    if !hwnd
        return ""
    try return WinGetClass("ahk_id " hwnd)
    catch {
        return ""
    }
}

GDHO_IsLikelyDrag(srcClass, startCursor) {
    cNow := GDHO_GetCursorHandle()
    if (cNow = 0)
        return false

    ; Explorer/Desktop class: high confidence file/folder drag
    if (srcClass = "CabinetWClass" || srcClass = "ExploreWClass" || srcClass = "WorkerW" || srcClass = "Progman")
        return true

    ; generic fallback: cursor changed after movement, usually indicates drag-mode cursor
    if (startCursor != 0 && cNow != startCursor)
        return true

    return false
}

GDHO_GuessPayloadType(srcClass) {
    ; Explorer/Desktop drags are generally file/folder.
    if (srcClass = "CabinetWClass" || srcClass = "ExploreWClass" || srcClass = "WorkerW" || srcClass = "Progman")
        return "file"
    ; Other apps default to text-like drag behavior.
    return "text"
}


