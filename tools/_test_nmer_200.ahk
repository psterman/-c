; ===================== msg =====================
#Requires AutoHotkey v2.0
A_MaxHotkeysPerInterval := 400
#Include modules\LocalPaths.ahk

NMER_StartupOnError(err, mode) {
    if (mode = "Return")
        return false
    line := 0
    try line := err.Line
    msg := "鍚姩鎴栬繍琛屽嚭閿欙細`n" . err.Message
    if (line)
        msg .= "`n`n" . err.File . " (琛?" . line . ")"
    errFile := ""
    errWhat := ""
    errStack := ""
    try errFile := err.File
    try errWhat := err.What
    try errStack := err.Stack
    try NMER_Log("startup", "unhandled_error",
        err.Message . " file=" . errFile . " line=" . line . " what=" . errWhat . " stack=" . errStack)
    catch {
        try FileAppend(Format("{} {}\n", A_Now, msg), Nmer_DebugPath("startup_error.log"))
    }
    try MsgBox(msg, "CursorHelper", 0x10)
    return false
}

NMER_Log(scope, event, detail := "") {
    global NMER_TraceSession
    try {
        logPath := Nmer_DebugPath("nmer_trace.log")
        dir := ""
        SplitPath(logPath, , &dir)
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)
        ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        FileAppend("[" . ts . "][" . NMER_TraceSession . "][" . scope . "][" . event . "] " . String(detail) . "`r`n", logPath, "UTF-8")
    } catch as _e { try NMER_Log(A_ThisFunc, "catch", _e.Message) }
}

OnError(NMER_StartupOnError)
#Include modules\NmerCatch.ahk
#Include modules\SqlSafe.ahk
global NMER_TraceSession := FormatTime(A_Now, "yyyyMMdd-HHmmss") . "-" . A_TickCount
global pToken := Gdip_Startup()
if (!pToken) {
    MsgBox "GDI+ 鍚姩澶辫触锛岃妫€鏌?lib\ahk\Gdip_All.ahk"
}
NMER_Log("startup", "boot", "gdip=" . (pToken ? "ok" : "fail"))
try SurfaceManager_ObserveSystemBootstrap(Map("traceSession", NMER_TraceSession, "gdip", pToken ? 1 : 0))
; ScreenshotEditorPlugin #HotIf 鍙兘鍦ㄤ富鑴氭湰鍚庨儴鍏ㄥ眬鍧楁墽琛屽墠琚眰鍊硷紝椤诲敖鏃╁垵濮嬪寲
global ScreenshotColorPickerActive := false
; 鎵樼洏鑿滃崟鍙兘鍦?Appearance / 鎮诞妯″潡鍏ㄥ眬鍧楁墽琛屽墠琚偣鍑伙紙TrayMenu_Init 寰堟棭锛夛紝椤诲敖鏃╁垵濮嬪寲
global AppearanceActivationMode := "toolbar"
global FloatingToolbarIsVisible := false
global FloatingBubbleIsVisible := false
; Emergency switch: disable hole overlay to avoid toolbar/page freeze.
global EnableHoleOverlay := true
global EnableHoleOverlayOnNativeDrop := true
global GDHO_DECOUPLED_TOPOLOGY := true
; Decoupled Go native drop bridge (out-of-process).
global EnableNativeDropBridge := true
global NativeDropBridgePID := 0
global NativeDropBridgeExe := A_ScriptDir "\tools\native-drop-bridge\native-drop-bridge.exe"
global NativeDropBridgeOut := A_ScriptDir "\Cache\native_drop_events.jsonl"
global NativeDropBridgeReadOffset := 0
global NativeDropBridgeLastEvent := 0
global NativeDropBridgeUseCopyData := true
global NativeDropBridgeCopyDataReady := false
global NativeDropBridgeCopyDataTitle := "NMER_AHK_BRIDGE"
global NativeDropBridgeCopyDataGui := 0
global NativeDropBridgeCopyDataLastTick := 0
global NativeDropBridgeStartTick := 0
global NativeDropBridgeCopyDataFallbackMs := 2200
global NativeDropSessionActive := false
global NativeDropDiagLogPath := A_ScriptDir "\Cache\drop_diagnostics_runtime.log"
global NativeDropHideDelayMs := 1800
global NativeDropSessionPayload := "text"
global NativeDropOverHole := false
global NativeDropWasOverHole := false
global NativeDropWeakPreviewShown := false
global NativeDropSawOutsideHole := false
global NativeDropValidEnterHole := false
global NativeDropStartMouseX := 0
global NativeDropStartMouseY := 0
global NativeDropMovedEnough := false
global NativeDropMoveThresholdPx := 14
global NativeDropTextMoveThresholdPx := 48
global NativeDropMinCommitDistancePx := 20
global NativeDropCurrentMoveDistance := 0.0
global NativeDropMinCommitMs := 140
global NativeDropEnterHoleTick := 0
global NativeDropMinDwellInHoleMs := 60
global NativeDropAwaitingDragEnd := false
global NativeDropAwaitingDragEndSince := 0
global GDHO_STATE := "IDLE" ; IDLE | ARMED | TRACKING
global GDHO_HOVER_VALID := false
global GDHO_DWELL_START_TICK := 0
global GDHO_LAST_PROXIMITY := 0.0
global NativeDropSeedText := ""
global NativeDropLastEventTick := 0
global NativeDropLastTickMouseX := 0
global NativeDropLastTickMouseY := 0
global NativeDropLastStartTick := 0
global NativeDropRearmUntil := 0
global NativeDropBridgeSilentMode := false
global g_NativeDropBridgePausedForText := false
global GDHO_TriggerSource := ""
; Hole drag hook bus: activate / position / release
global g_HoleDragHooks := Map("activate", [], "position", [], "release", [])
global g_LastValidTrayMenu := []
global g_IsUIVisibleTransitioning := false
global g_ActivationApplyToken := 0
global g_ActivationApplyInFlight := false
; Diagnostic mode: make drop receiver full-screen to verify hit path.
; Keep disabled in production. Full-screen receiver can degrade desktop interaction.
global NativeDropBridgeFullScreenHitTest := false
; TrayMenu_Init / UpdateTrayMenu 浼氱珛鍒?GetText锛岄』鏃╀簬鍚庨儴銆屽璇█銆嶅叏灞€鍧?global Language := "zh"
; ===================== 鍩虹閰嶇疆 =====================
#SingleInstance Force
SetTitleMatchMode(2)
SetControlDelay(-1)
SetKeyDelay(20, 20)
SetMouseDelay(10)
SendMode("Input")
DetectHiddenWindows(true)
; 璁剧疆鍧愭爣妯″紡锛堢敤浜庢嫋鍔ㄧ獥鍙ｇ瓑鍔熻兘锛?CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")
CoordMode("ToolTip", "Screen")

HoleDragHooks_On(eventName, callback) {
    global g_HoleDragHooks
    ev := StrLower(Trim(String(eventName)))
    if !g_HoleDragHooks.Has(ev)
        g_HoleDragHooks[ev] := []
    if !(callback is Func) && !(callback is BoundFunc)
        return false
    for _, cb in g_HoleDragHooks[ev] {
        if (cb = callback)
            return true
    }
    g_HoleDragHooks[ev].Push(callback)
    return true
}

HoleDragHooks_Off(eventName, callback := 0) {
    global g_HoleDragHooks
    ev := StrLower(Trim(String(eventName)))
    if !g_HoleDragHooks.Has(ev)
        return false
    if !(callback is Func) && !(callback is BoundFunc) {
        g_HoleDragHooks[ev] := []
        return true
    }
    kept := []
    for _, cb in g_HoleDragHooks[ev] {
        if (cb != callback)
            kept.Push(cb)
    }
    g_HoleDragHooks[ev] := kept
    return true
}

HoleDragHooks_Emit(eventName, data := 0) {
    global g_HoleDragHooks
    ev := StrLower(Trim(String(eventName)))
    if !g_HoleDragHooks.Has(ev)
        return
    for _, cb in g_HoleDragHooks[ev] {
        try cb.Call(data)
    }
}
; 鎵樼洏鍥炬爣涓?0x0404 鑷畾涔夎彍鍗曪細鍦?#Include lib\ahk\ImagePut.ahk 涔嬪悗璋冪敤 TrayMenu_Init()锛堜緷璧?Gdip_All锛?
; ===================== 鍖呭惈 SQLite 鏁版嵁搴撶被 =====================
; 鍖呭惈 lib 鏂囦欢澶逛腑鐨?Class_SQLiteDB.ahk锛圓HK v2 鐗堟湰锛?#Include lib\ahk\Class_SQLiteDB.ahk
#Include lib\ahk\Jxon.ahk
Nmer_MigrateDebugFiles()
global NativeDropBridgeOut := Nmer_DebugPath("native_drop_events.jsonl")
global NativeDropDiagLogPath := Nmer_DebugPath("drop_diagnostics_runtime.log")
#Include modules\ToolsPaths.ahk
#Include lib\ahk\WebView2.ahk
#Include modules\FuncExists.ahk

#Include modules\AhkWebViewBridge.ahk
#Include modules\WebView2SharedEnv.ahk
#Include modules\FocusBroker.ahk
#Include modules\LegacyGuardrails.ahk
#Include modules\CoreAsyncHttp.ahk
#Include modules\AsyncGuardrails.ahk
#Include modules\SqlBatchHelper.ahk
#Include modules\StartupSqlRegistry.ahk

; ===================== 鍖呭惈 OCR 妯″潡 =====================
; 鍖呭惈 lib 鏂囦欢澶逛腑鐨?OCR.ahk锛堢敤浜庤瘑鍥惧彇璇嶅姛鑳斤級
#Include lib\ahk\OCR.ahk

; ===================== 鍖呭惈 GDI+ 鍜?WinClip 搴?=====================
; 鍖呭惈 lib 鏂囦欢澶逛腑鐨?Gdip_All.ahk 鍜?WinClip.ahk锛堢敤浜庢埅鍥惧姪鎵嬮瑙堢獥锛?; 娉ㄦ剰锛歐inClip.ahk 渚濊禆浜?WinClipAPI.ahk锛岄渶瑕佸厛鍖呭惈 WinClipAPI.ahk
#Include lib\ahk\Gdip_All.ahk
