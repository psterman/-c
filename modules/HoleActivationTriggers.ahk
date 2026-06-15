#Requires AutoHotkey v2.0
; 黑洞手势/按键触发：按住右键画圈（松手识别后唤起）/ 长按右键（与 SelectionSense 划选触发并列）

global g_HoleTrig_TextSelect := true
global g_HoleTrig_CircleCw := false
global g_HoleTrig_CircleCcw := false
global g_HoleTrig_RButtonHold := false
global g_HoleTrig_CircleMinRadius := 72
global g_HoleTrig_RButtonHoldMs := 3000
global g_HoleTrig_RButtonMaxMovePx := 20
global g_HoleTrig_HoldStillBroken := false
global g_HoleTrig_HoldStillAccumMs := 0
global g_HoleTrig_HoldPollLastTick := 0
global g_HoleTrig_HoldActivatedThisPress := false
global g_HoleTrig_RButtonPhysDown := false
global g_HoleTrig_RButtonGraceUntil := 0
global g_HoleTrig_RButtonLockUntilUp := false
global g_HoleTrig_LastRButtonDownTick := 0
global g_HoleTrig_RButtonMinPressMs := 180
global g_HoleTrig_HoldPollMs := 50
global g_HoleTrig_GestureActive := false
global g_HoleTrig_Points := []
global g_HoleTrig_StartTick := 0
global g_HoleTrig_StartX := 0
global g_HoleTrig_StartY := 0
global g_HoleTrig_LastMoveTick := 0
global g_HoleTrig_MouseHook := 0
global g_HoleTrig_MouseHookCb := 0
global g_HoleTrig_UseMouseHook := true
global g_HoleTrig_HotkeysOn := false
global g_HoleTrig_DiagPath := Nmer_DebugPath("hole_triggers.log")
global g_HoleTrig_PendingDown := false
global g_HoleTrig_PendingUp := false
global g_HoleTrig_PendingMove := false
global g_HoleTrig_MinSampleDistSq := 4
global g_HoleTrig_TrackIntervalMs := 10
global g_HoleTrig_ToastGui := 0
global g_HoleTrig_ToastTextCtrl := 0
global g_HoleTrig_ToastHideSerial := 0
global g_HoleTrig_FreePts := []
global g_HoleTrig_FreeLastMoveTick := 0
global g_HoleTrig_FreeCooldownUntil := 0
global g_HoleTrig_FreePendingMove := false
global g_HoleTrig_FreeIdleMs := 160
global g_HoleTrig_FreeCooldownMs := 720
global g_HoleTrig_RButtonWatch := false
global g_HoleTrig_LastActivateTick := 0
global g_HoleTrig_ActivateCooldownMs := 900
global g_HoleTrig_TrailLastTick := 0
global g_HoleTrig_TrailThrottleMs := 72
global g_HoleTrig_TrailPreviewLastTick := 0
global g_HoleTrig_TrailMatchState := false

HoleTriggers_DiagLog(msg) {
    global g_HoleTrig_DiagPath
    try {
        dir := ""
        SplitPath(g_HoleTrig_DiagPath, , &dir)
        if (dir != "" && !DirExist(dir))
            DirCreate(dir)
        ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        FileAppend("[" . ts . "] " . String(msg) . "`r`n", g_HoleTrig_DiagPath, "UTF-8")
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try NativeDropDiag_Log(String(msg))
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

HoleTriggers_ShouldCaptureGestures() {
    if !HoleTriggers_AnyGestureEnabled()
        return false
    global AppearanceActivationMode
    if FuncExists("NormalizeAppearanceActivationMode") {
        if (NormalizeAppearanceActivationMode(IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar") = "hole")
            return true
    }
    if FuncExists("SelectionSense_IsHoleCaptureEnabled") {
        try {
            if SelectionSense_IsHoleCaptureEnabled()
                return true
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    return HoleTriggers_IsHoleModeActive()
}

HoleTriggers_EnsureInputAlive(*) {
    static lastDiagTick := 0
    HoleTriggers_HealFromIniIfNeeded()
    want := HoleTriggers_ShouldCaptureGestures()
    if (A_TickCount - lastDiagTick > 6000) {
        global g_HoleTrig_MouseHook, g_HoleTrig_CircleCw, g_HoleTrig_CircleCcw, g_HoleTrig_RButtonHold
        global AppearanceActivationMode, g_HoleRuntimeEnabled
        HoleTriggers_DiagLog("[HoleTrigger] alive want=" . (want ? "1" : "0")
            . " hook=" . (g_HoleTrig_MouseHook ? "1" : "0")
            . " mode=" . (IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "?")
            . " runtime=" . (IsSet(g_HoleRuntimeEnabled) && g_HoleRuntimeEnabled ? "1" : "0")
            . " cw=" . (g_HoleTrig_CircleCw ? "1" : "0")
            . " ccw=" . (g_HoleTrig_CircleCcw ? "1" : "0")
            . " hold=" . (g_HoleTrig_RButtonHold ? "1" : "0"))
        lastDiagTick := A_TickCount
    }
    if want {
        HoleTriggers_HealStuckRButtonLock()
        HoleTriggers_HealStuckRButtonGesture()
        HoleTriggers_HealPhantomRButtonDown()
        HoleTriggers_SyncInputCapture()
    } else {
        HoleTriggers_RemoveMouseHook()
        HoleTriggers_DisableGestureHotkeys()
    }
}

HoleTriggers_IsHoleModeActive() {
    if FuncExists("SelectionSense_IsHoleCaptureEnabled") {
        try {
            if SelectionSense_IsHoleCaptureEnabled()
                return true
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    global g_HoleRuntimeEnabled
    if !(IsSet(g_HoleRuntimeEnabled) && g_HoleRuntimeEnabled)
        return false
    if FuncExists("IsHoleRuntimeEnabledByActivationMode")
        return IsHoleRuntimeEnabledByActivationMode()
    global AppearanceActivationMode
    return (IsSet(AppearanceActivationMode) && NormalizeAppearanceActivationMode(AppearanceActivationMode) = "hole")
}

HoleTriggers_IsTextSelectEnabled() {
    global g_HoleTrig_TextSelect
    return !!g_HoleTrig_TextSelect
}

HoleTriggers_IsCircleCwEnabled() {
    global g_HoleTrig_CircleCw
    return !!g_HoleTrig_CircleCw
}

HoleTriggers_IsCircleCcwEnabled() {
    global g_HoleTrig_CircleCcw
    return !!g_HoleTrig_CircleCcw
}

HoleTriggers_IsRButtonHoldEnabled() {
    global g_HoleTrig_RButtonHold
    return !!g_HoleTrig_RButtonHold
}

; 设置页仅提供 1 / 3 / 5 秒；旧 INI 毫秒值归并到最近档位
HoleTriggers_NormalizeHoldMs(ms) {
    m := Integer(ms)
    if (m <= 1500)
        return 1000
    if (m <= 4000)
        return 3000
    return 5000
}

HoleTriggers_GetHoldDurationMs() {
    global g_HoleTrig_RButtonHoldMs
    return HoleTriggers_NormalizeHoldMs(g_HoleTrig_RButtonHoldMs)
}

; 长按「几乎不动」：相对按下点的位移容差（与画圈切换阈值分开）
HoleTriggers_GetRButtonHoldMovePx() {
    global g_HoleTrig_RButtonMaxMovePx
    base := Max(20, Integer(g_HoleTrig_RButtonMaxMovePx))
    return Max(32, base + 12)
}

; 明显拖移后才进入右键画圈 watch，避免微抖打断长按累计
HoleTriggers_GetRButtonCircleBreakMovePx() {
    return Max(72, HoleTriggers_GetRButtonHoldMovePx() + 28)
}

HoleTriggers_HoldStillDistOk(dist, holdMax := "") {
    if (holdMax = "")
        holdMax := HoleTriggers_GetRButtonHoldMovePx()
    return (dist <= holdMax)
}

HoleTriggers_HoldStillDistSoft(dist, holdMax := "") {
    if (holdMax = "")
        holdMax := HoleTriggers_GetRButtonHoldMovePx()
    return (dist <= holdMax * 1.65)
}

HoleTriggers_AccumulateHoldStill(dt, dist) {
    global g_HoleTrig_HoldStillAccumMs
    holdMax := HoleTriggers_GetRButtonHoldMovePx()
    if HoleTriggers_HoldStillDistOk(dist, holdMax)
        g_HoleTrig_HoldStillAccumMs += dt
    else if HoleTriggers_HoldStillDistSoft(dist, holdMax) {
        ; 略超出容差时缓慢衰减，避免手抖把 3 秒进度清零
        g_HoleTrig_HoldStillAccumMs := Max(0, g_HoleTrig_HoldStillAccumMs - Floor(dt * 0.35))
    } else
        g_HoleTrig_HoldStillAccumMs := Max(0, g_HoleTrig_HoldStillAccumMs - dt)
}

HoleTriggers_HoldStillSatisfied(dist, elapsed := 0) {
    global g_HoleTrig_HoldStillAccumMs, g_HoleTrig_StartTick
    holdNeed := HoleTriggers_GetHoldDurationMs()
    holdMax := HoleTriggers_GetRButtonHoldMovePx()
    if !HoleTriggers_HoldStillDistOk(dist, holdMax)
        return false
    if (g_HoleTrig_HoldStillAccumMs >= holdNeed)
        return true
    if (elapsed < 1 && g_HoleTrig_StartTick > 0)
        elapsed := A_TickCount - g_HoleTrig_StartTick
    return (elapsed >= holdNeed)
}

HoleTriggers_ShouldTrustHookRButtonUp() {
    global g_HoleTrig_GestureActive, g_HoleTrig_RButtonWatch, g_HoleTrig_RButtonLockUntilUp
    if g_HoleTrig_RButtonLockUntilUp
        return false
    return g_HoleTrig_GestureActive || g_HoleTrig_RButtonWatch
}

HoleTriggers_OnRButtonDownReject(reason := "") {
    if (reason != "")
        HoleTriggers_DiagLog("[HoleTrigger] rbutton_down_skip reason=" . String(reason))
}

; 钩子已置 PhysDown 但手势未启动（常见于按下后被 skip）时补开长按计时
HoleTriggers_HealPhantomRButtonDown() {
    global g_HoleTrig_RButtonPhysDown, g_HoleTrig_GestureActive, g_HoleTrig_RButtonWatch
    global g_HoleTrig_LastRButtonDownTick, g_HoleTrig_RButtonLockUntilUp
    if g_HoleTrig_RButtonLockUntilUp || g_HoleTrig_GestureActive || g_HoleTrig_RButtonWatch
        return
    if !g_HoleTrig_RButtonPhysDown
        return
    if (g_HoleTrig_LastRButtonDownTick < 1 || (A_TickCount - g_HoleTrig_LastRButtonDownTick) > 8000)
        return
    if (A_TickCount - g_HoleTrig_LastRButtonDownTick) < 50
        return
    if ((!HoleTriggers_IsRButtonHoldEnabled() && !HoleTriggers_AnyCircleEnabled()) || !HoleTriggers_IsHoleModeActive())
        return
    if !HoleTriggers_IsRButtonPhysicallyDown()
        return
    HoleTriggers_DiagLog("[HoleTrigger] heal_phantom_rbutton_down age=" . (A_TickCount - g_HoleTrig_LastRButtonDownTick))
    HoleTriggers_OnRButtonDown()
}

HoleTriggers_HealStuckRButtonGesture() {
    global g_HoleTrig_GestureActive, g_HoleTrig_RButtonWatch, g_HoleTrig_RButtonLockUntilUp
    global g_HoleTrig_LastRButtonDownTick, g_HoleTrig_RButtonPhysDown
    if g_HoleTrig_RButtonLockUntilUp
        return
    if !(g_HoleTrig_GestureActive || g_HoleTrig_RButtonWatch)
        return
    if HoleTriggers_IsRButtonPhysicallyDown()
        return
    if (g_HoleTrig_LastRButtonDownTick > 0 && (A_TickCount - g_HoleTrig_LastRButtonDownTick) < 400)
        return
    HoleTriggers_DiagLog("[HoleTrigger] heal_stuck_rbutton_gesture")
    g_HoleTrig_RButtonPhysDown := false
    HoleTriggers_ClearRButtonCaptureState(false)
    global g_HoleTrig_HoldActivatedThisPress
    g_HoleTrig_HoldActivatedThisPress := false
}

HoleTriggers_IsRButtonPhysicallyDown() {
    global g_HoleTrig_RButtonPhysDown, g_HoleTrig_RButtonGraceUntil
    if g_HoleTrig_RButtonPhysDown
        return true
    if (A_TickCount < g_HoleTrig_RButtonGraceUntil)
        return true
    try return GetKeyState("RButton", "P")
    return false
}

HoleTriggers_IsRButtonReallyUp() {
    try {
        if GetKeyState("RButton", "P")
            return false
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return true
}

HoleTriggers_ArmRButtonLockUntilUp(reason := "") {
    global g_HoleTrig_RButtonLockUntilUp
    g_HoleTrig_RButtonLockUntilUp := true
    HoleTriggers_DiagLog("[HoleTrigger] rbutton_lock_until_up reason=" . String(reason))
}

HoleTriggers_StartRButtonHoldPoll() {
    global g_HoleTrig_HoldPollMs
    try SetTimer(HoleTriggers_OnRButtonHoldTick, 0)
    SetTimer(HoleTriggers_OnRButtonHoldTick, Max(35, Integer(g_HoleTrig_HoldPollMs)))
}

HoleTriggers_StopRButtonHoldPoll() {
    try SetTimer(HoleTriggers_OnRButtonHoldTick, 0)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

; 结束本轮右键轨迹/长按计时；keepLock=1 时保留「等真正松开」锁，便于连续两次长按
HoleTriggers_ClearRButtonCaptureState(keepLock := false) {
    global g_HoleTrig_GestureActive, g_HoleTrig_RButtonWatch, g_HoleTrig_HoldStillBroken
    global g_HoleTrig_HoldStillAccumMs, g_HoleTrig_HoldPollLastTick, g_HoleTrig_RButtonLockUntilUp, g_HoleTrig_Points
    HoleTriggers_StopRButtonHoldPoll()
    try SetTimer(HoleTriggers_TrackPointer, 0)
    try SetTimer(HoleTriggers_RButtonWatchTick, 0)
    g_HoleTrig_GestureActive := false
    g_HoleTrig_RButtonWatch := false
    g_HoleTrig_HoldStillBroken := false
    g_HoleTrig_HoldStillAccumMs := 0
    g_HoleTrig_HoldPollLastTick := 0
    g_HoleTrig_Points := []
    try HoleTriggers_ClearGestureTrail()
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if !keepLock
        g_HoleTrig_RButtonLockUntilUp := false
}

HoleTriggers_HealStuckRButtonLock() {
    global g_HoleTrig_RButtonLockUntilUp, g_HoleTrig_HoldActivatedThisPress
    if !g_HoleTrig_RButtonLockUntilUp
        return
    if HoleTriggers_IsRButtonPhysicallyDown()
        return
    if !HoleTriggers_IsRButtonReallyUp()
        return
    HoleTriggers_DiagLog("[HoleTrigger] heal_lock_released")
    HoleTriggers_ClearRButtonCaptureState(false)
    g_HoleTrig_HoldActivatedThisPress := false
}

; 画圈：按住右键拖动，松手时识别；长按仍为「几乎不动」提前/松手唤起
HoleTriggers_UseEarlyRButtonHold() {
    return HoleTriggers_IsRButtonHoldEnabled()
}

HoleTriggers_AnyCircleEnabled() {
    return HoleTriggers_IsCircleCwEnabled() || HoleTriggers_IsCircleCcwEnabled()
}

HoleTriggers_AnyGestureEnabled() {
    return HoleTriggers_AnyCircleEnabled() || HoleTriggers_IsRButtonHoldEnabled()
}

HoleTriggers_AnyMouseButtonPressed() {
    return GetKeyState("LButton", "P") || GetKeyState("RButton", "P") || GetKeyState("MButton", "P")
        || GetKeyState("XButton1", "P") || GetKeyState("XButton2", "P")
}

; 空手画圈：仅左键按下视为「在拖拽/点击」；已画出一截轨迹时不因瞬时左键态误清空
HoleTriggers_FreeCircleMouseBlocked() {
    if !GetKeyState("LButton", "P")
        return false
    global g_HoleTrig_FreePts
    if !(g_HoleTrig_FreePts is Array) || g_HoleTrig_FreePts.Length < 10
        return true
    pathLen := HoleTriggers_ComputePathLength(g_HoleTrig_FreePts)
    minR := HoleTriggers_GetScaledCircleMinRadius()
    return (pathLen < minR * 1.2)
}

HoleTriggers_IniBool(iniPath, section, key, default := "0") {
    v := Trim(IniRead(iniPath, section, key, default))
    return (v = "1" || StrLower(v) = "true" || v = "yes")
}

HoleTriggers_ApplyConfig(trigMap, syncCapture := true) {
    global g_HoleTrig_TextSelect, g_HoleTrig_CircleCw, g_HoleTrig_CircleCcw, g_HoleTrig_RButtonHold
    global g_HoleTrig_CircleMinRadius, g_HoleTrig_RButtonHoldMs
    if !(trigMap is Map)
        return
    g_HoleTrig_TextSelect := !!trigMap.Get("textSelect", true)
    g_HoleTrig_CircleCw := !!trigMap.Get("circleCw", false)
    g_HoleTrig_CircleCcw := !!trigMap.Get("circleCcw", false)
    g_HoleTrig_RButtonHold := !!trigMap.Get("rbuttonHold", false)
    r := Integer(trigMap.Get("circleMinRadius", 72))
    if (r < 32)
        r := 32
    if (r > 240)
        r := 240
    g_HoleTrig_CircleMinRadius := r
    g_HoleTrig_RButtonHoldMs := HoleTriggers_NormalizeHoldMs(trigMap.Get("rbuttonHoldMs", 3000))
    HoleTriggers_DiagLog("[HoleTrigger] apply_config cw=" . (g_HoleTrig_CircleCw ? "1" : "0")
        . " ccw=" . (g_HoleTrig_CircleCcw ? "1" : "0") . " hold=" . (g_HoleTrig_RButtonHold ? "1" : "0")
        . " holdMs=" . g_HoleTrig_RButtonHoldMs)
    if syncCapture
        HoleTriggers_SyncInputCapture()
}

HoleTriggers_ConfigIniPath() {
    if IsSet(ConfigFile) && ConfigFile != ""
        return ConfigFile
    return Nmer_ResolveConfigFile()
}

HoleTriggers_IniGestureFlags(cf := "") {
    if (cf = "")
        cf := HoleTriggers_ConfigIniPath()
    if !FileExist(cf)
        return Map("circleCw", false, "circleCcw", false, "rbuttonHold", false)
    return Map(
        "circleCw", HoleTriggers_IniBool(cf, "Appearance", "HoleTriggerCircleCw", "0"),
        "circleCcw", HoleTriggers_IniBool(cf, "Appearance", "HoleTriggerCircleCcw", "0"),
        "rbuttonHold", HoleTriggers_IniBool(cf, "Appearance", "HoleTriggerRButtonHold", "0")
    )
}

HoleTriggers_RuntimeMatchesIni(cf := "") {
    ini := HoleTriggers_IniGestureFlags(cf)
    return (HoleTriggers_IsCircleCwEnabled() = !!ini["circleCw"])
        && (HoleTriggers_IsCircleCcwEnabled() = !!ini["circleCcw"])
        && (HoleTriggers_IsRButtonHoldEnabled() = !!ini["rbuttonHold"])
}

HoleTriggers_HealFromIniIfNeeded() {
    cf := HoleTriggers_ConfigIniPath()
    if !FileExist(cf)
        return false
    ini := HoleTriggers_IniGestureFlags(cf)
    if !(ini["circleCw"] || ini["circleCcw"] || ini["rbuttonHold"])
        return HoleTriggers_AnyGestureEnabled()
    if HoleTriggers_RuntimeMatchesIni(cf)
        return HoleTriggers_AnyGestureEnabled()
    HoleTriggers_LoadFromIni(cf)
    HoleTriggers_DiagLog("[HoleTrigger] heal_from_ini cw=" . (HoleTriggers_IsCircleCwEnabled() ? "1" : "0")
        . " ccw=" . (HoleTriggers_IsCircleCcwEnabled() ? "1" : "0")
        . " hold=" . (HoleTriggers_IsRButtonHoldEnabled() ? "1" : "0"))
    return HoleTriggers_AnyGestureEnabled()
}

HoleTriggers_ShouldDeferToVkContextMenu() {
    if !WinActive("ahk_exe Cursor.exe") || !GetCapsLockState()
        return false
    if !FuncExists("VK_ToolbarLayoutHasContextMenuItems")
        return false
    try return VK_ToolbarLayoutHasContextMenuItems()
    return false
}

HoleTriggers_SyncInputCapture() {
    want := HoleTriggers_ShouldCaptureGestures()
    if want {
        if g_HoleTrig_UseMouseHook
            HoleTriggers_InstallMouseHook()
        else
            HoleTriggers_EnableGestureHotkeys()
    } else {
        HoleTriggers_FreeCircle_Reset("sync_off")
        HoleTriggers_RemoveMouseHook()
        HoleTriggers_DisableGestureHotkeys()
    }
}

HoleTriggers_EnableGestureHotkeys() {
    global g_HoleTrig_HotkeysOn
    if g_HoleTrig_HotkeysOn
        return
    try {
        Hotkey("~*RButton", HoleTriggers_OnRButtonDown_Wrapped, "On")
        Hotkey("~*RButton Up", HoleTriggers_OnRButtonUp_Wrapped, "On")
        g_HoleTrig_HotkeysOn := true
    } catch as e {
        try NativeDropDiag_Log("[HoleTrigger] hotkey_on_fail msg=" . e.Message)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
}

HoleTriggers_DisableGestureHotkeys() {
    global g_HoleTrig_HotkeysOn
    if !g_HoleTrig_HotkeysOn
        return
    try Hotkey("~*RButton", "Off")
    try Hotkey("~*RButton Up", "Off")
    g_HoleTrig_HotkeysOn := false
}

HoleTriggers_DeferredRButtonDown(*) {
    global g_HoleTrig_PendingDown
    g_HoleTrig_PendingDown := false
    if HoleTriggers_ShouldDeferToVkContextMenu() {
        HoleTriggers_OnRButtonDownReject("vk_context_menu")
        return
    }
    if !HoleTriggers_IsRButtonPhysicallyDown() {
        HoleTriggers_OnRButtonDownReject("not_down_on_defer")
        return
    }
    HoleTriggers_OnRButtonDown()
}

HoleTriggers_DeferredRButtonUp(*) {
    global g_HoleTrig_PendingUp
    g_HoleTrig_PendingUp := false
    if HoleTriggers_ShouldDeferToVkContextMenu()
        return
    HoleTriggers_OnRButtonUp()
}

HoleTriggers_DeferredMouseMove(*) {
    global g_HoleTrig_PendingMove
    g_HoleTrig_PendingMove := false
    if HoleTriggers_ShouldDeferToVkContextMenu()
        return
    HoleTriggers_TrackPointer()
}

HoleTriggers_DeferredFreeCircleMove(*) {
    global g_HoleTrig_FreePendingMove
    g_HoleTrig_FreePendingMove := false
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    HoleTriggers_FreeCircle_OnMove(mx, my)
}

HoleTriggers_IsFreeCircleReason(reason := "") {
    r := StrLower(Trim(String(reason)))
    return (InStr(r, "free_circle") || r = "circle_cw" || r = "circle_ccw")
}

HoleTriggers_IsHoldReason(reason := "") {
    r := StrLower(Trim(String(reason)))
    return (InStr(r, "rbutton_hold") || InStr(r, "hold_early"))
}

HoleTriggers_FreeCircleInProgress() {
    global g_HoleTrig_GestureActive, g_HoleTrig_Points
    return g_HoleTrig_GestureActive && (g_HoleTrig_Points is Array && g_HoleTrig_Points.Length >= 3)
}

HoleTriggers_FreeCircle_Reset(reason := "") {
    global g_HoleTrig_FreePts, g_HoleTrig_FreeLastMoveTick
    g_HoleTrig_FreePts := []
    g_HoleTrig_FreeLastMoveTick := 0
    try SetTimer(HoleTriggers_FreeCircleFinalize, 0)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

; 空手画圈已停用
HoleTriggers_FreeCircle_OnMove(mx, my) {
}

HoleTriggers_FreeCircle_ScheduleFinalize() {
}

HoleTriggers_FreeCircleFinalize(*) {
}

HoleTriggers_OnMouseButtonDown_Hook(btnMsg := 0) {
}

HoleTriggers_ShouldBreakHoldForCircle(dist) {
    if !HoleTriggers_AnyCircleEnabled()
        return false
    if (dist <= HoleTriggers_GetRButtonCircleBreakMovePx())
        return false
    global g_HoleTrig_Points
    pathLen := HoleTriggers_ComputePathLength(g_HoleTrig_Points)
    return (pathLen >= 36)
}

HoleTriggers_MouseHookProc(nCode, wParam, lParam) {
    global g_HoleTrig_MouseHook, g_HoleTrig_PendingDown, g_HoleTrig_PendingUp, g_HoleTrig_PendingMove
    global g_HoleTrig_GestureActive, g_HoleTrig_FreePendingMove
    hhk := g_HoleTrig_MouseHook ? g_HoleTrig_MouseHook : 0
    if (nCode < 0)
        return DllCall("CallNextHookEx", "Ptr", hhk, "Int", nCode, "UInt", wParam, "Ptr", lParam, "Ptr")
    if HoleTriggers_ShouldCaptureGestures() {
        if (wParam = 0x201 || wParam = 0x204 || wParam = 0x207 || wParam = 0x20B || wParam = 0x20C) {
            HoleTriggers_OnMouseButtonDown_Hook(wParam)
        }
        if (wParam = 0x204) && (HoleTriggers_IsRButtonHoldEnabled() || HoleTriggers_AnyCircleEnabled()) {  ; WM_RBUTTONDOWN
            global g_HoleTrig_RButtonPhysDown, g_HoleTrig_RButtonGraceUntil, g_HoleTrig_LastRButtonDownTick, g_HoleTrig_PendingDown
            global g_HoleTrig_RButtonLockUntilUp
            if g_HoleTrig_RButtonLockUntilUp
                return DllCall("CallNextHookEx", "Ptr", hhk, "Int", nCode, "UInt", wParam, "Ptr", lParam, "Ptr")
            if g_HoleTrig_PendingDown {
                if (g_HoleTrig_LastRButtonDownTick > 0 && (A_TickCount - g_HoleTrig_LastRButtonDownTick) > 450)
                    g_HoleTrig_PendingDown := false
                else
                    return DllCall("CallNextHookEx", "Ptr", hhk, "Int", nCode, "UInt", wParam, "Ptr", lParam, "Ptr")
            }
            g_HoleTrig_RButtonPhysDown := true
            g_HoleTrig_RButtonGraceUntil := A_TickCount + 320
            g_HoleTrig_LastRButtonDownTick := A_TickCount
            g_HoleTrig_PendingDown := true
            SetTimer(HoleTriggers_DeferredRButtonDown, -1)
            try SetTimer(HoleTriggers_HealPhantomRButtonDown, -80)
        } else if (wParam = 0x205) && !g_HoleTrig_PendingUp {  ; WM_RBUTTONUP
            global g_HoleTrig_RButtonPhysDown, g_HoleTrig_LastRButtonDownTick, g_HoleTrig_RButtonMinPressMs
            global g_HoleTrig_GestureActive, g_HoleTrig_RButtonWatch, g_HoleTrig_RButtonLockUntilUp
            gestureBusy := g_HoleTrig_GestureActive || g_HoleTrig_RButtonWatch
            if !HoleTriggers_IsRButtonReallyUp() {
                if g_HoleTrig_RButtonLockUntilUp && !g_HoleTrig_RButtonPhysDown {
                    HoleTriggers_DiagLog("[HoleTrigger] hook_rbutton_up_trusted lock_release")
                } else if HoleTriggers_ShouldTrustHookRButtonUp() {
                    HoleTriggers_DiagLog("[HoleTrigger] hook_rbutton_up_trusted still_down=1 gesture=1")
                } else {
                    HoleTriggers_DiagLog("[HoleTrigger] hook_rbutton_up_ignored still_down=1")
                    return DllCall("CallNextHookEx", "Ptr", hhk, "Int", nCode, "UInt", wParam, "Ptr", lParam, "Ptr")
                }
            }
            if !gestureBusy && g_HoleTrig_LastRButtonDownTick > 0
                && (A_TickCount - g_HoleTrig_LastRButtonDownTick) < Integer(g_HoleTrig_RButtonMinPressMs) {
                HoleTriggers_DiagLog("[HoleTrigger] hook_rbutton_up_ignored too_fast ms="
                    . (A_TickCount - g_HoleTrig_LastRButtonDownTick))
                return DllCall("CallNextHookEx", "Ptr", hhk, "Int", nCode, "UInt", wParam, "Ptr", lParam, "Ptr")
            }
            g_HoleTrig_RButtonPhysDown := false
            g_HoleTrig_PendingUp := true
            SetTimer(HoleTriggers_DeferredRButtonUp, -1)
        } else if (wParam = 0x200) {
            if g_HoleTrig_GestureActive && !g_HoleTrig_PendingMove {
                g_HoleTrig_PendingMove := true
                SetTimer(HoleTriggers_DeferredMouseMove, -1)
            }
        }
    }
    return DllCall("CallNextHookEx", "Ptr", hhk, "Int", nCode, "UInt", wParam, "Ptr", lParam, "Ptr")
}

HoleTriggers_InstallMouseHook() {
    global g_HoleTrig_MouseHook, g_HoleTrig_MouseHookCb
    HoleTriggers_DisableGestureHotkeys()
    if g_HoleTrig_MouseHook
        return
    try {
        g_HoleTrig_MouseHookCb := CallbackCreate(HoleTriggers_MouseHookProc, "F", 3)
        g_HoleTrig_MouseHook := DllCall("SetWindowsHookExW", "Int", 14, "Ptr", g_HoleTrig_MouseHookCb, "Ptr", 0, "UInt", 0, "Ptr")
        if !g_HoleTrig_MouseHook {
            try NativeDropDiag_Log("[HoleTrigger] mouse_hook_install_fail err=" . A_LastError)
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
            try CallbackFree(g_HoleTrig_MouseHookCb)
            g_HoleTrig_MouseHookCb := 0
            HoleTriggers_EnableGestureHotkeys()
            return
        }
        HoleTriggers_DiagLog("[HoleTrigger] mouse_hook_on")
    } catch as e {
        HoleTriggers_DiagLog("[HoleTrigger] mouse_hook_ex msg=" . e.Message)
        HoleTriggers_EnableGestureHotkeys()
    }
}

HoleTriggers_RemoveMouseHook() {
    global g_HoleTrig_MouseHook, g_HoleTrig_MouseHookCb
    if g_HoleTrig_MouseHook {
        try DllCall("UnhookWindowsHookEx", "Ptr", g_HoleTrig_MouseHook)
        g_HoleTrig_MouseHook := 0
        HoleTriggers_DiagLog("[HoleTrigger] mouse_hook_off")
    }
    if g_HoleTrig_MouseHookCb {
        try CallbackFree(g_HoleTrig_MouseHookCb)
        g_HoleTrig_MouseHookCb := 0
    }
}

HoleTriggers_LoadFromIni(iniPath := "") {
    cf := iniPath != "" ? iniPath : Nmer_ResolveConfigFile()
    if !FileExist(cf)
        return
    preset := StrLower(Trim(IniRead(cf, "Appearance", "HoleSensitivityPreset", "standard")))
    presetRadius := 64
    switch preset {
        case "compact":
            presetRadius := 48
        case "relaxed":
            presetRadius := 80
    }
    iniRadius := Integer(IniRead(cf, "Appearance", "HoleCircleMinRadius", "0"))
    circleR := (iniRadius > 0) ? iniRadius : presetRadius
    hmRaw := Trim(IniRead(cf, "Appearance", "HoleRButtonHoldMs", "3000"))
    hm := HoleTriggers_NormalizeHoldMs(Integer(hmRaw != "" ? hmRaw : "3000"))
    acRaw := Trim(IniRead(cf, "Appearance", "HoleGestureActivateCooldownMs", "900"))
    global g_HoleTrig_ActivateCooldownMs
    g_HoleTrig_ActivateCooldownMs := Max(500, Integer(acRaw != "" ? acRaw : "900"))
    HoleTriggers_ApplyConfig(Map(
        "textSelect", HoleTriggers_IniBool(cf, "Appearance", "HoleTriggerTextSelect", "1"),
        "circleCw", HoleTriggers_IniBool(cf, "Appearance", "HoleTriggerCircleCw", "0"),
        "circleCcw", HoleTriggers_IniBool(cf, "Appearance", "HoleTriggerCircleCcw", "0"),
        "rbuttonHold", HoleTriggers_IniBool(cf, "Appearance", "HoleTriggerRButtonHold", "0"),
        "circleMinRadius", circleR,
        "rbuttonHoldMs", hm
    ), false)
    HoleTriggers_SyncInputCapture()
    HoleTriggers_DiagLog("[HoleTrigger] load_ini cw=" . (HoleTriggers_IsCircleCwEnabled() ? "1" : "0")
        . " ccw=" . (HoleTriggers_IsCircleCcwEnabled() ? "1" : "0")
        . " hold=" . (HoleTriggers_IsRButtonHoldEnabled() ? "1" : "0")
        . " file=" . cf)
}

HoleTriggers_SaveToIni(trigMap, iniPath := "") {
    cf := iniPath != "" ? iniPath : Nmer_ResolveConfigFile()
    if !(trigMap is Map)
        return
    HoleTriggers_ApplyConfig(trigMap)
    IniWrite(g_HoleTrig_TextSelect ? "1" : "0", cf, "Appearance", "HoleTriggerTextSelect")
    IniWrite(g_HoleTrig_CircleCw ? "1" : "0", cf, "Appearance", "HoleTriggerCircleCw")
    IniWrite(g_HoleTrig_CircleCcw ? "1" : "0", cf, "Appearance", "HoleTriggerCircleCcw")
    IniWrite(g_HoleTrig_RButtonHold ? "1" : "0", cf, "Appearance", "HoleTriggerRButtonHold")
    IniWrite(String(g_HoleTrig_CircleMinRadius), cf, "Appearance", "HoleCircleMinRadius")
    IniWrite(String(g_HoleTrig_RButtonHoldMs), cf, "Appearance", "HoleRButtonHoldMs")
}

HoleTriggers_MapSensitivityPreset(preset) {
    p := StrLower(Trim(String(preset)))
    switch p {
        case "compact":
            return Map("trigger", 200, "dismiss", 260)
        case "relaxed":
            return Map("trigger", 340, "dismiss", 420)
        default:
            return Map("trigger", 260, "dismiss", 320)
    }
}

HoleTriggers_InferSensitivityPreset(triggerDist, dismissDist) {
    td := Integer(triggerDist), dd := Integer(dismissDist)
    if (td <= 210 && dd <= 280)
        return "compact"
    if (td >= 300 || dd >= 380)
        return "relaxed"
    return "standard"
}

HoleTriggers_GetGestureStrictness() {
    try {
        hwnd := WinGetID("A")
        if !hwnd
            return 1.0
        cls := WinGetClass("ahk_id " hwnd)
        proc := WinGetProcessName("ahk_id " hwnd)
        title := WinGetTitle("ahk_id " hwnd)
        if (cls = "UnityWndClass" || cls = "UnrealWindow" || InStr(proc, "League") || InStr(proc, "GTA"))
            return 1.55
        if (InStr(proc, "devenv") || InStr(proc, "Code") || InStr(proc, "Cursor") || InStr(title, "Visual Studio"))
            return 1.28
        if (InStr(title, "Floating Toolbar"))
            return 1.2
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return 1.0
}

HoleTriggers_ShouldIgnoreGestureAtPoint(x, y) {
    if FuncExists("GDHO_IsLauncherLayerActive") {
        try {
            if GDHO_IsLauncherLayerActive()
                return true
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    try {
        hwnd := WinGetID("A")
        if hwnd {
            title := WinGetTitle("ahk_id " hwnd)
            if InStr(title, "Floating Toolbar")
                return true
            cls := WinGetClass("ahk_id " hwnd)
            if (cls = "UnityWndClass" || cls = "UnrealWindow")
                return true
        }
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return false
}

HoleTriggers_IsHoldActivateReason(reason := "") {
    r := StrLower(Trim(String(reason)))
    return InStr(r, "rbutton_hold")
}

HoleTriggers_CanActivateNow(reason := "") {
    global g_HoleTrig_LastActivateTick, g_HoleTrig_ActivateCooldownMs
    ; 长按右键：短防抖即可，关闭黑洞后可立即再次长按唤起（不再套用 0.9s+ 的全局冷却）
    if HoleTriggers_IsHoldActivateReason(reason) {
        cd := 80
        return (A_TickCount - Integer(g_HoleTrig_LastActivateTick) >= cd)
    }
    strict := HoleTriggers_GetGestureStrictness()
    cd := Floor(Integer(g_HoleTrig_ActivateCooldownMs) * strict)
    if (cd < 500)
        cd := 500
    return (A_TickCount - Integer(g_HoleTrig_LastActivateTick) >= cd)
}

HoleTriggers_MarkActivated() {
    global g_HoleTrig_LastActivateTick
    g_HoleTrig_LastActivateTick := A_TickCount
}

HoleTriggers_GestureTrailPoint(screenX, screenY) {
    global g_HoleTrig_TrailLastTick, g_HoleTrig_TrailThrottleMs, g_HoleTrig_TrailMatchState
    if !(FuncExists("GDHO_RunStarryJS") && FuncExists("GDHO_PolicyScreenToStarryClient"))
        return
    now := A_TickCount
    if (g_HoleTrig_TrailLastTick = 0) {
        g_HoleTrig_TrailMatchState := false
        if FuncExists("GDHO_ShowStarryPassthroughOnly")
            try GDHO_ShowStarryPassthroughOnly("gesture_trail")
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    if (g_HoleTrig_TrailLastTick > 0 && (now - g_HoleTrig_TrailLastTick) < Integer(g_HoleTrig_TrailThrottleMs))
        return
    g_HoleTrig_TrailLastTick := now
    try {
        cli := GDHO_PolicyScreenToStarryClient(Integer(screenX), Integer(screenY))
        GDHO_RunStarryJS("try{window.HoleOverlay?.gestureTrailPoint?.(" . Integer(cli.x) . "," . Integer(cli.y) . ");}catch(_e){}")
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

HoleTriggers_GestureTrailSetMatch(matched, dir := "") {
    if !FuncExists("GDHO_RunStarryJS")
        return
    m := matched ? "true" : "false"
    d := StrReplace(StrReplace(Trim(String(dir)), "\", "\\"), "'", "\'")
    try GDHO_RunStarryJS("try{window.HoleOverlay?.gestureTrailSetMatch?.(" . m . ",'" . d . "');}catch(_e){}")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

HoleTriggers_ClearGestureTrail() {
    global g_HoleTrig_TrailLastTick, g_HoleTrig_TrailPreviewLastTick, g_HoleTrig_TrailMatchState
    g_HoleTrig_TrailLastTick := 0
    g_HoleTrig_TrailPreviewLastTick := 0
    g_HoleTrig_TrailMatchState := false
    if FuncExists("GDHO_RunStarryJS")
        try GDHO_RunStarryJS("try{window.HoleOverlay?.clearGestureTrail?.();}catch(_e){}")
}

HoleTriggers_TryResolveCircleFromPts(pts) {
    if !HoleTriggers_AnyCircleEnabled()
        return ""
    if !(pts is Array) || pts.Length < 10
        return ""
    dir := ""
    reject := ""
    diag := ""
    if !HoleTriggers_AnalyzeCircle(&dir, &reject, pts, &diag)
        return ""
    if (dir = "cw" && HoleTriggers_IsCircleCwEnabled())
        return "circle_cw"
    if (dir = "ccw" && HoleTriggers_IsCircleCcwEnabled())
        return "circle_ccw"
    return ""
}

HoleTriggers_UpdateCircleTrailPreview(force := false) {
    global g_HoleTrig_Points, g_HoleTrig_TrailPreviewLastTick, g_HoleTrig_TrailMatchState
    if !HoleTriggers_AnyCircleEnabled()
        return
    pts := g_HoleTrig_Points
    if !(pts is Array) || pts.Length < 10
        return
    now := A_TickCount
    if !force && g_HoleTrig_TrailPreviewLastTick > 0 && (now - g_HoleTrig_TrailPreviewLastTick) < 110
        return
    g_HoleTrig_TrailPreviewLastTick := now
    reason := HoleTriggers_TryResolveCircleFromPts(pts)
    matched := (reason != "")
    dir := matched ? (InStr(reason, "ccw") ? "ccw" : "cw") : ""
    if (matched != g_HoleTrig_TrailMatchState || force) {
        g_HoleTrig_TrailMatchState := matched
        HoleTriggers_GestureTrailSetMatch(matched, dir)
    }
}

HoleTriggers_AppendPointWithTrail(mx, my) {
    if !HoleTriggers_AppendPoint(mx, my)
        return false
    try HoleTriggers_GestureTrailPoint(mx, my)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try HoleTriggers_UpdateCircleTrailPreview()
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return true
}

HoleTriggers_OnLauncherDismissed(reason := "") {
    global g_HoleTrig_LastActivateTick, g_HoleTrig_RButtonLockUntilUp
    ; 黑洞已关闭：清零唤起冷却，便于立刻再次长按右键唤起
    g_HoleTrig_LastActivateTick := 0
    if g_HoleTrig_RButtonLockUntilUp && HoleTriggers_IsRButtonReallyUp() {
        HoleTriggers_ClearRButtonCaptureState(false)
        global g_HoleTrig_HoldActivatedThisPress
        g_HoleTrig_HoldActivatedThisPress := false
    }
    HoleTriggers_FreeCircle_Reset("launcher_dismiss:" . String(reason))
}

HoleTriggers_GestureToastMessage(reason := "", ok := true) {
    r := StrLower(Trim(String(reason)))
    if !ok {
        if (InStr(r, "hold"))
            return "长按已识别 · 未能唤起黑洞"
        return ""
    }
    if (InStr(r, "free_circle_cw") || InStr(r, "circle_cw") || r = "cw")
        return "按住右键顺时针画圈 · 松手唤起黑洞"
    if (InStr(r, "free_circle_ccw") || InStr(r, "circle_ccw") || r = "ccw")
        return "按住右键逆时针画圈 · 松手唤起黑洞"
    if (InStr(r, "rbutton_hold") || InStr(r, "hold_early") || r = "hold")
        return "长按右键 · 黑洞已唤起"
    return "手势已识别 · 黑洞已唤起"
}

HoleTriggers_HoleUiIsVisible() {
    global GDHO_LAUNCHER_VISIBLE, g_GDHO_StarryLauncherOpen, GDHO_VISIBLE
    if (GDHO_LAUNCHER_VISIBLE || g_GDHO_StarryLauncherOpen || GDHO_VISIBLE)
        return true
    try {
        if GDHO_IsLauncherLayerActive()
            return true
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    try {
        if GDHO_IsStarryHostVisible()
            return true
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return false
}

HoleTriggers_PresentHoleUi(ax, ay, reason := "gesture") {
    global GDHO_STAR_GUI, GDHO_LAUNCHER_VISIBLE, g_GDHO_StarryLauncherOpen, GDHO_VISIBLE
    rsn := String(reason)
    ix := Integer(ax), iy := Integer(ay)
    HoleTriggers_DiagLog("[HoleTrigger] present_begin reason=" . rsn . " x=" . ix . " y=" . iy)
    isFreeCircle := HoleTriggers_IsFreeCircleReason(rsn)
    isHold := HoleTriggers_IsHoldReason(rsn)
    lightPresent := isFreeCircle || isHold
    try {
        if GDHO_IsDecoupled() {
            if !GDHO_IsLauncherLayerActive() && FuncExists("GDHO_ClearGestureHolePresentation") {
                try GDHO_ClearGestureHolePresentation("gesture_present:" . rsn)
                catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
            }
            if !lightPresent {
                try GDHO_PrepareDecoupledHoleForTextSelection("gesture:" . rsn)
                catch as _e {
                    NmerCatch(A_ThisFunc, _e) 
                }
            }
        }
    } catch as e0 {
        HoleTriggers_DiagLog("[HoleTrigger] present_prepare_fail msg=" . e0.Message)
    }
    try {
        if lightPresent && FuncExists("GDHO_BeginGestureLauncherSession")
            GDHO_BeginGestureLauncherSession(ix, iy, rsn)
        else
            GDHO_BeginGestureHoleSession(ix, iy, rsn)
    } catch as e1 {
        HoleTriggers_DiagLog("[HoleTrigger] present_session_fail msg=" . e1.Message)
    }
    try GDHO_UpdateHoleCenterFromPolicy(ix, iy)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if !IsObject(GDHO_STAR_GUI) {
        try GDHO_CreateStarryGui()
        catch as e2 {
            HoleTriggers_DiagLog("[HoleTrigger] present_create_starry_fail msg=" . e2.Message)
        }
    }
    try GDHO_EnsureStarryOnScreenForLauncher()
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    presented := false
    try {
        if GDHO_ForceShowLauncherLayerByPolicy(ix, iy, "hole_trig:" . rsn)
            presented := true
    } catch as e3 {
        HoleTriggers_DiagLog("[HoleTrigger] present_force_fail msg=" . e3.Message)
    }
    if !presented {
        try {
            if GDHO_ShowLauncherLayerForced("hole_trig:" . rsn)
                presented := true
        } catch as e4 {
            HoleTriggers_DiagLog("[HoleTrigger] present_show_launcher_fail msg=" . e4.Message)
        }
    }
    if !presented {
        try GDHO_ArmLauncherLayerShow("hole_trig:" . rsn)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    if !presented {
        try {
            GDHO_ShowTextDragAt(ix, iy, true, true)
            presented := true
        } catch as e5 {
            HoleTriggers_DiagLog("[HoleTrigger] present_text_drag_fail msg=" . e5.Message)
        }
    }
    if !presented {
        try {
            if GDHO_PresentGestureHoleAt(ix, iy, rsn)
                presented := true
        } catch as e6 {
            HoleTriggers_DiagLog("[HoleTrigger] present_legacy_fail msg=" . e6.Message)
        }
    }
    vis := HoleTriggers_HoleUiIsVisible()
    HoleTriggers_DiagLog("[HoleTrigger] present_done presented=" . (presented ? "1" : "0") . " visible=" . (vis ? "1" : "0")
        . " lv=" . (GDHO_LAUNCHER_VISIBLE ? "1" : "0") . " star=" . (g_GDHO_StarryLauncherOpen ? "1" : "0") . " gdho_vis=" . (GDHO_VISIBLE ? "1" : "0"))
    return !!(presented || vis)
}

HoleTriggers_EnsureGestureToastGui() {
    global g_HoleTrig_ToastGui, g_HoleTrig_ToastTextCtrl
    if (g_HoleTrig_ToastGui && g_HoleTrig_ToastTextCtrl)
        return
    if g_HoleTrig_ToastGui {
        try g_HoleTrig_ToastGui.Destroy()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        g_HoleTrig_ToastGui := 0
        g_HoleTrig_ToastTextCtrl := 0
    }
    g_HoleTrig_ToastGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x20", "HoleGestureToast")
    g_HoleTrig_ToastGui.BackColor := "010101"
    g_HoleTrig_ToastGui.MarginX := 10
    g_HoleTrig_ToastGui.MarginY := 6
    g_HoleTrig_ToastTextCtrl := g_HoleTrig_ToastGui.Add("Text", "w220 Center c7DD3FC BackgroundTrans", "")
    g_HoleTrig_ToastTextCtrl.SetFont("s10", "Segoe UI")
}

HoleTriggers_HideGestureToast(reason := "") {
    global g_HoleTrig_ToastGui, g_HoleTrig_ToastHideSerial
    g_HoleTrig_ToastHideSerial += 1
    SetTimer(HoleTriggers_GestureToastAutoHide, 0)
    try {
        if g_HoleTrig_ToastGui
            g_HoleTrig_ToastGui.Hide()
    } catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if (reason != "")
        HoleTriggers_DiagLog("[HoleTrigger] toast_hide reason=" . String(reason))
}

HoleTriggers_GestureToastAutoHide(*) {
    HoleTriggers_HideGestureToast("timeout")
}

HoleTriggers_ShowGestureToast(x, y, reason := "gesture", ok := true) {
    ; 静默：不显示顺时针/逆时针/长按唤起提示
    return
}

HoleTriggers_ShowGestureSuccessToast(x, y, reason := "gesture") {
    return
}

HoleTriggers_NotifyGestureResult(ok, x, y, reason := "gesture") {
    ; 静默唤起：不弹出顺时针/逆时针/长按等手势提示
    return
}

; 供 #HotIf：黑洞模式 + 已启用手势；Cursor+CapsLock 右键菜单优先
HoleTriggers_IsGestureHotkeyContext() {
    if !HoleTriggers_IsHoleModeActive() || !HoleTriggers_AnyGestureEnabled()
        return false
    if WinActive("ahk_exe Cursor.exe") && GetCapsLockState() && FuncExists("VK_ToolbarLayoutHasContextMenuItems") {
        try {
            if VK_ToolbarLayoutHasContextMenuItems()
                return false
        } catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    }
    return true
}

HoleTriggers_ActivateAtScreen(x, y, reason := "gesture") {
    if !HoleTriggers_IsHoleModeActive()
        return false
    if !HoleTriggers_CanActivateNow(reason) {
        HoleTriggers_DiagLog("[HoleTrigger] activate_blocked cooldown reason=" . String(reason))
        return false
    }
    if HoleTriggers_ShouldIgnoreGestureAtPoint(x, y)
        return false
    ax := Integer(x), ay := Integer(y)
    if (ax = 0 && ay = 0) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&ax, &ay)
    }
    HoleTriggers_DiagLog("[HoleTrigger] activate reason=" . String(reason) . " x=" . ax . " y=" . ay)
    ok := false
    try ok := HoleTriggers_PresentHoleUi(ax, ay, reason)
    catch as e0 {
        HoleTriggers_DiagLog("[HoleTrigger] present_ui_fail msg=" . e0.Message)
    }
    if !ok {
        try {
            GDHO_RequestOpen(Map(
                "reason", "gesture_" . String(reason),
                "payload", "text",
                "screenX", ax,
                "screenY", ay,
                "positionMode", "screen",
                "weakPreview", true
            ))
            try GDHO_ArmLauncherLayerShow("gesture_req:" . String(reason))
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
            HoleTriggers_DiagLog("[HoleTrigger] request_open_fallback reason=" . String(reason))
        } catch as e2 {
            HoleTriggers_DiagLog("[HoleTrigger] request_open_fail msg=" . e2.Message)
        }
        ok := HoleTriggers_HoleUiIsVisible()
    }
    if !ok {
        try ok := HoleActivation_OpenAt(ax, ay, String(reason), String(reason))
        catch as e3 {
            HoleTriggers_DiagLog("[HoleTrigger] router_fail msg=" . e3.Message)
        }
    }
    if !ok
        ok := HoleTriggers_HoleUiIsVisible()
    if ok {
        HoleTriggers_MarkActivated()
        if HoleTriggers_IsHoldActivateReason(reason) {
            global g_HoleTrig_HoldActivatedThisPress
            g_HoleTrig_HoldActivatedThisPress := true
            HoleTriggers_ClearRButtonCaptureState(true)
            HoleTriggers_ArmRButtonLockUntilUp(reason)
        }
    }
    try HoleTriggers_ClearGestureTrail()
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    HoleTriggers_DiagLog("[HoleTrigger] activate_result ok=" . (ok ? "1" : "0") . " reason=" . String(reason)
        . " launcher=" . (HoleTriggers_HoleUiIsVisible() ? "1" : "0"))
    try HoleTriggers_NotifyGestureResult(ok, ax, ay, reason)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    return !!ok
}

HoleTriggers_ResetGesture() {
    global g_HoleTrig_GestureActive, g_HoleTrig_Points, g_HoleTrig_StartTick
    g_HoleTrig_GestureActive := false
    g_HoleTrig_Points := []
    g_HoleTrig_StartTick := 0
    try SetTimer(HoleTriggers_TrackPointer, 0)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
}

HoleTriggers_RButtonWatchTick(*) {
    global g_HoleTrig_RButtonWatch, g_HoleTrig_Points
    if !g_HoleTrig_RButtonWatch {
        try SetTimer(HoleTriggers_RButtonWatchTick, 0)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        return
    }
    if !HoleTriggers_IsRButtonPhysicallyDown() {
        HoleTriggers_OnRButtonUp()
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    HoleTriggers_AppendPointWithTrail(mx, my)
}

HoleTriggers_OnRButtonDown(*) {
    global g_HoleTrig_GestureActive, g_HoleTrig_Points, g_HoleTrig_StartTick, g_HoleTrig_StartX, g_HoleTrig_StartY
    global g_HoleTrig_RButtonWatch, g_HoleTrig_LastMoveTick, g_HoleTrig_HoldStillBroken, g_HoleTrig_RButtonLockUntilUp
    global g_HoleTrig_LastRButtonDownTick, g_HoleTrig_HoldActivatedThisPress
    HoleTriggers_HealStuckRButtonGesture()
    if g_HoleTrig_RButtonLockUntilUp {
        HoleTriggers_OnRButtonDownReject("lock_until_up")
        return
    }
    if g_HoleTrig_GestureActive || g_HoleTrig_RButtonWatch {
        HoleTriggers_OnRButtonDownReject("gesture_busy")
        return
    }
    if !HoleTriggers_IsHoleModeActive() {
        HoleTriggers_OnRButtonDownReject("hole_inactive")
        return
    }
    if !HoleTriggers_IsRButtonHoldEnabled() && !HoleTriggers_AnyCircleEnabled() {
        HoleTriggers_OnRButtonDownReject("gestures_off")
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    if HoleTriggers_ShouldIgnoreGestureAtPoint(mx, my) {
        HoleTriggers_OnRButtonDownReject("ignore_wnd")
        return
    }
    try HoleTriggers_HideGestureToast("rbutton_down")
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    HoleTriggers_FreeCircle_Reset("rbutton_down")
    try HoleTriggers_ClearGestureTrail()
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    g_HoleTrig_HoldActivatedThisPress := false
    HoleTriggers_DiagLog("[HoleTrigger] rbutton_down x=" . mx . " y=" . my . " cw=" . (HoleTriggers_IsCircleCwEnabled() ? "1" : "0")
        . " ccw=" . (HoleTriggers_IsCircleCcwEnabled() ? "1" : "0") . " hold=" . (HoleTriggers_IsRButtonHoldEnabled() ? "1" : "0"))
    global g_HoleTrig_RButtonPhysDown, g_HoleTrig_RButtonGraceUntil
    g_HoleTrig_RButtonPhysDown := true
    g_HoleTrig_RButtonGraceUntil := A_TickCount + 320
    global g_HoleTrig_LastRButtonDownTick
    g_HoleTrig_LastRButtonDownTick := A_TickCount
    g_HoleTrig_HoldStillBroken := false
    global g_HoleTrig_HoldStillAccumMs, g_HoleTrig_HoldPollLastTick
    g_HoleTrig_HoldStillAccumMs := 0
    g_HoleTrig_HoldPollLastTick := A_TickCount
    g_HoleTrig_StartTick := A_TickCount
    g_HoleTrig_LastMoveTick := g_HoleTrig_StartTick
    g_HoleTrig_StartX := mx
    g_HoleTrig_StartY := my
    g_HoleTrig_Points := [{ x: mx, y: my }]
    global g_HoleTrig_TrackIntervalMs
    g_HoleTrig_RButtonWatch := false
    g_HoleTrig_GestureActive := true
    SetTimer(HoleTriggers_TrackPointer, g_HoleTrig_TrackIntervalMs)
    if HoleTriggers_AnyCircleEnabled()
        try HoleTriggers_GestureTrailPoint(mx, my)
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
    if HoleTriggers_IsRButtonHoldEnabled()
        HoleTriggers_StartRButtonHoldPoll()
}

; 数组在 v2 中按对象引用传递，勿用 &pts（调用全局变量会报错）
HoleTriggers_AppendPointTo(pts, mx, my, minDistSq := 4) {
    if !(pts is Array)
        return false
    n := pts.Length
    if (n > 0) {
        last := pts[n]
        dx := mx - last.x, dy := my - last.y
        if (dx * dx + dy * dy < minDistSq)
            return false
    }
    pts.Push({ x: mx, y: my })
    return true
}

HoleTriggers_AppendPoint(mx, my) {
    global g_HoleTrig_Points, g_HoleTrig_LastMoveTick, g_HoleTrig_MinSampleDistSq
    if HoleTriggers_AppendPointTo(g_HoleTrig_Points, mx, my, g_HoleTrig_MinSampleDistSq) {
        g_HoleTrig_LastMoveTick := A_TickCount
        return true
    }
    return false
}

HoleTriggers_TrackPointer(*) {
    global g_HoleTrig_GestureActive, g_HoleTrig_Points, g_HoleTrig_StartX, g_HoleTrig_StartY
    global g_HoleTrig_HoldStillBroken, g_HoleTrig_RButtonWatch, g_HoleTrig_RButtonMaxMovePx, g_HoleTrig_TrackIntervalMs
    if !g_HoleTrig_GestureActive
        return
    if !HoleTriggers_IsRButtonPhysicallyDown() {
        allowUp := HoleTriggers_IsRButtonReallyUp()
        if !allowUp && (A_TickCount - g_HoleTrig_StartTick) >= Integer(g_HoleTrig_RButtonMinPressMs)
            allowUp := true
        if !allowUp
            return
        if (A_TickCount - g_HoleTrig_StartTick < Integer(g_HoleTrig_RButtonMinPressMs))
            return
        HoleTriggers_OnRButtonUp()
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    if HoleTriggers_IsRButtonHoldEnabled() && !g_HoleTrig_RButtonWatch {
        dx := mx - g_HoleTrig_StartX
        dy := my - g_HoleTrig_StartY
        dist := Sqrt(dx * dx + dy * dy)
        if HoleTriggers_ShouldBreakHoldForCircle(dist) {
            g_HoleTrig_RButtonWatch := true
            try SetTimer(HoleTriggers_RButtonWatchTick, g_HoleTrig_TrackIntervalMs)
            catch as _e {
                NmerCatch(A_ThisFunc, _e) 
            }
        }
    }
    HoleTriggers_AppendPointWithTrail(mx, my)
}

HoleTriggers_GetScaledCircleMinRadius() {
    global g_HoleTrig_CircleMinRadius
    dpi := 96
    try dpi := DllCall("GetDpiForSystem", "UInt")
    base := Max(24, Floor(g_HoleTrig_CircleMinRadius * dpi / 96.0 * 0.58))
    return Max(base, Floor(base * HoleTriggers_GetGestureStrictness()))
}

HoleTriggers_ComputePathLength(pts) {
    pathLen := 0.0
    if !(pts is Array) || pts.Length < 2
        return pathLen
    loop pts.Length - 1 {
        dx := pts[A_Index + 1].x - pts[A_Index].x
        dy := pts[A_Index + 1].y - pts[A_Index].y
        pathLen += Sqrt(dx * dx + dy * dy)
    }
    return pathLen
}

HoleTriggers_PointCloudBounds(pts) {
    minX := pts[1].x, maxX := minX, minY := pts[1].y, maxY := minY
    for p in pts {
        if (p.x < minX)
            minX := p.x
        if (p.x > maxX)
            maxX := p.x
        if (p.y < minY)
            minY := p.y
        if (p.y > maxY)
            maxY := p.y
    }
    w := maxX - minX
    h := maxY - minY
    return { minX: minX, minY: minY, maxX: maxX, maxY: maxY, w: w, h: h
        , cx: (minX + maxX) / 2.0, cy: (minY + maxY) / 2.0
        , aspect: (w >= 1 && h >= 1) ? ((w >= h) ? (w / h) : (h / w)) : 1.0 }
}

HoleTriggers_SubsamplePts(pts, maxN := 80) {
    if !(pts is Array) || pts.Length <= maxN
        return pts
    out := []
    n := pts.Length
    step := n / maxN
    f := 1.0
    while (out.Length < maxN && Floor(f) <= n) {
        i := Max(1, Floor(f))
        out.Push(pts[i])
        f += step
    }
    if (out.Length > 0 && (out[out.Length].x != pts[n].x || out[out.Length].y != pts[n].y))
        out.Push(pts[n])
    return out
}

HoleTriggers_ShoeLaceArea(pts) {
    area := 0.0
    n := pts.Length
    if (n < 3)
        return area
    loop n - 1 {
        area += pts[A_Index].x * pts[A_Index + 1].y - pts[A_Index + 1].x * pts[A_Index].y
    }
    area += pts[n].x * pts[1].y - pts[1].x * pts[n].y
    return area * 0.5
}

HoleTriggers_AnalyzeCircle(&outDir := "", &reject := "", pts := "", &diag := "") {
    outDir := ""
    reject := "init"
    diag := ""
    minR := HoleTriggers_GetScaledCircleMinRadius()
    if !(pts is Array) || pts.Length = 0 {
        global g_HoleTrig_Points
        pts := g_HoleTrig_Points
    }
    if !(pts is Array) || pts.Length < 6 {
        reject := "few_pts"
        return false
    }
    pts := HoleTriggers_SubsamplePts(pts, 88)
    pathLen := HoleTriggers_ComputePathLength(pts)
    if (pathLen < minR * 2.35) {
        reject := "short_path"
        diag := "minR=" . minR
        return false
    }
    bb := HoleTriggers_PointCloudBounds(pts)
    cx := bb.cx
    cy := bb.cy
    radius := Min(bb.w, bb.h) * 0.5
    if (radius < minR * 0.72) {
        reject := "small_r"
        diag := "r=" . Round(radius) . " minR=" . minR
        return false
    }
    if (bb.aspect > 3.8) {
        reject := "flat_line"
        diag := "asp=" . Round(bb.aspect, 2)
        return false
    }
    ring := []
    rSum := 0.0
    for p in pts {
        r := Sqrt((p.x - cx) ** 2 + (p.y - cy) ** 2)
        if (r < radius * 0.18)
            continue
        ring.Push({ x: p.x, y: p.y, r: r })
        rSum += r
    }
    if (ring.Length < 6) {
        reject := "ring_pts"
        diag := "ring=" . ring.Length
        return false
    }
    radius := rSum / ring.Length
    first := pts[1]
    last := pts[pts.Length]
    closure := Sqrt((last.x - first.x) ** 2 + (last.y - first.y) ** 2)
    if (closure > Max(radius * 1.75, minR * 2.0, pathLen * 0.22)) {
        reject := "open_loop"
        diag := "cls=" . Round(closure) . " r=" . Round(radius)
        return false
    }
    circum := 6.2831853 * radius
    arcRatio := pathLen / Max(circum, 1.0)
    if (arcRatio < 0.52) {
        reject := "arc_short"
        diag := "arc=" . Round(arcRatio, 2)
        return false
    }
    if (arcRatio > 1.85) {
        reject := "too_wiggly"
        diag := "arc=" . Round(arcRatio, 2)
        return false
    }
    nRing := ring.Length
    step := Max(1, Floor(nRing / 28))
    angle := 0.0
    prev := 0.0
    got := false
    i := 1
    while (i <= nRing) {
        p := ring[i]
        ang := DllCall("msvcrt.dll\atan2", "Double", p.y - cy, "Double", p.x - cx, "CDECL Double")
        if got {
            d := ang - prev
            while (d > 3.14159265)
                d -= 6.2831853
            while (d < -3.14159265)
                d += 6.2831853
            angle += d
        } else {
            got := true
        }
        prev := ang
        i += step
    }
    diag := "asp=" . Round(bb.aspect, 2) . " ang=" . Round(angle, 2) . " arc=" . Round(arcRatio, 2)
    area := HoleTriggers_ShoeLaceArea(pts)
    if (Abs(angle) >= 0.72) {
        outDir := (angle > 0) ? "cw" : "ccw"
        reject := ""
        return true
    }
    if (Abs(area) < (radius * radius * 0.18)) {
        reject := "area_small"
        return false
    }
    if (Abs(angle) < 0.55) {
        reject := "weak_turn"
        return false
    }
    outDir := (area < 0) ? "cw" : "ccw"
    reject := ""
    return true
}

HoleTriggers_OnRButtonUp(*) {
    global g_HoleTrig_GestureActive, g_HoleTrig_Points, g_HoleTrig_StartTick, g_HoleTrig_StartX, g_HoleTrig_StartY
    global g_HoleTrig_RButtonMaxMovePx, g_HoleTrig_RButtonWatch, g_HoleTrig_HoldStillBroken
    global g_HoleTrig_RButtonPhysDown, g_HoleTrig_RButtonLockUntilUp, g_HoleTrig_RButtonMinPressMs
    global g_HoleTrig_HoldActivatedThisPress, g_HoleTrig_LastRButtonDownTick
    wasWatch := g_HoleTrig_RButtonWatch
    wasActive := g_HoleTrig_GestureActive
    elapsed := wasActive ? (A_TickCount - g_HoleTrig_StartTick) : 0
    if g_HoleTrig_RButtonLockUntilUp {
        if !HoleTriggers_IsRButtonReallyUp() {
            lockElapsed := (g_HoleTrig_LastRButtonDownTick > 0) ? (A_TickCount - g_HoleTrig_LastRButtonDownTick) : elapsed
            if !(g_HoleTrig_HoldActivatedThisPress && !HoleTriggers_IsRButtonPhysicallyDown()
                && lockElapsed >= Integer(g_HoleTrig_RButtonMinPressMs)) {
                HoleTriggers_DiagLog("[HoleTrigger] rbutton_up_ignored lock_still_down")
                return
            }
            HoleTriggers_DiagLog("[HoleTrigger] rbutton_lock_released trusted_up elapsed=" . lockElapsed)
        } else
            HoleTriggers_DiagLog("[HoleTrigger] rbutton_lock_released")
        g_HoleTrig_RButtonLockUntilUp := false
        g_HoleTrig_RButtonPhysDown := false
        g_HoleTrig_HoldActivatedThisPress := false
        HoleTriggers_ClearRButtonCaptureState(false)
        return
    }
    if g_HoleTrig_HoldActivatedThisPress {
        g_HoleTrig_HoldActivatedThisPress := false
        g_HoleTrig_RButtonPhysDown := false
        HoleTriggers_ClearRButtonCaptureState(false)
        HoleTriggers_DiagLog("[HoleTrigger] rbutton_up_after_hold_fire ms=" . elapsed)
        return
    }
    if wasActive && !HoleTriggers_IsRButtonReallyUp() {
        if (elapsed >= Integer(g_HoleTrig_RButtonMinPressMs)) {
            HoleTriggers_DiagLog("[HoleTrigger] rbutton_up_trusted still_down elapsed=" . elapsed)
        } else {
            HoleTriggers_DiagLog("[HoleTrigger] rbutton_up_ignored still_down elapsed=" . elapsed)
            return
        }
    }
    if wasActive && (elapsed < Integer(g_HoleTrig_RButtonMinPressMs)) {
        HoleTriggers_DiagLog("[HoleTrigger] rbutton_up_ignored too_fast elapsed=" . elapsed)
        return
    }
    g_HoleTrig_RButtonPhysDown := false
    HoleTriggers_StopRButtonHoldPoll()
    try SetTimer(HoleTriggers_RButtonWatchTick, 0)
    try SetTimer(HoleTriggers_TrackPointer, 0)
    g_HoleTrig_RButtonWatch := false
    g_HoleTrig_GestureActive := false
    if !wasActive && !wasWatch
        return
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    HoleTriggers_AppendPointWithTrail(mx, my)
    try HoleTriggers_UpdateCircleTrailPreview(true)
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    pts := g_HoleTrig_Points
    pathLen := HoleTriggers_ComputePathLength(pts)
    holdNeed := HoleTriggers_GetHoldDurationMs()
    global g_HoleTrig_HoldStillAccumMs
    HoleTriggers_DiagLog("[HoleTrigger] rbutton_up pts=" . (pts is Array ? pts.Length : 0) . " ms=" . elapsed . " need=" . holdNeed
        . " accum=" . g_HoleTrig_HoldStillAccumMs . " path=" . Round(pathLen)
        . " hold_broken=" . (g_HoleTrig_HoldStillBroken ? "1" : "0") . " watch=" . (wasWatch ? "1" : "0"))
    circleReason := HoleTriggers_TryResolveCircleFromPts(pts)
    if (circleReason != "") {
        diagDir := ""
        diagReject := ""
        diagText := ""
        HoleTriggers_AnalyzeCircle(&diagDir, &diagReject, pts, &diagText)
        HoleTriggers_DiagLog("[HoleTrigger] circle_release reason=" . circleReason . " pts=" . (pts is Array ? pts.Length : 0)
            . (diagText != "" ? " " . diagText : ""))
        g_HoleTrig_Points := []
        g_HoleTrig_HoldStillBroken := false
        g_HoleTrig_HoldStillAccumMs := 0
        g_HoleTrig_HoldPollLastTick := 0
        g_HoleTrig_HoldActivatedThisPress := false
        try HoleTriggers_ClearGestureTrail()
        catch as _e {
            NmerCatch(A_ThisFunc, _e) 
        }
        if HoleTriggers_CanActivateNow(circleReason)
            HoleTriggers_ActivateAtScreen(mx, my, circleReason)
        else
            HoleTriggers_DiagLog("[HoleTrigger] circle_release_blocked cooldown reason=" . circleReason)
        return
    }
    try HoleTriggers_ClearGestureTrail()
    catch as _e {
        NmerCatch(A_ThisFunc, _e) 
    }
    if HoleTriggers_IsRButtonHoldEnabled() {
        global g_HoleTrig_HoldStillAccumMs
        holdMax := HoleTriggers_GetRButtonHoldMovePx()
        dx := mx - g_HoleTrig_StartX
        dy := my - g_HoleTrig_StartY
        dist := Sqrt(dx * dx + dy * dy)
        if HoleTriggers_HoldStillSatisfied(dist, elapsed)
            HoleTriggers_ActivateAtScreen(mx, my, "rbutton_hold")
        else if HoleTriggers_HoldStillDistOk(dist, holdMax)
            HoleTriggers_DiagLog("[HoleTrigger] rbutton_up_short elapsed=" . elapsed . " accum=" . g_HoleTrig_HoldStillAccumMs . " need=" . holdNeed)
    }
    g_HoleTrig_HoldStillBroken := false
    global g_HoleTrig_HoldStillAccumMs, g_HoleTrig_HoldPollLastTick, g_HoleTrig_HoldActivatedThisPress
    g_HoleTrig_HoldStillAccumMs := 0
    g_HoleTrig_HoldPollLastTick := 0
    g_HoleTrig_HoldActivatedThisPress := false
    g_HoleTrig_Points := []
}

; 长按右键：周期性检测（每 50ms），达到设定时长且几乎不动则提前唤起
HoleTriggers_OnRButtonHoldTick(*) {
    global g_HoleTrig_GestureActive, g_HoleTrig_StartTick, g_HoleTrig_StartX, g_HoleTrig_StartY
    global g_HoleTrig_HoldStillBroken, g_HoleTrig_HoldStillAccumMs, g_HoleTrig_HoldPollLastTick, g_HoleTrig_Points
    if !HoleTriggers_IsRButtonHoldEnabled() || !g_HoleTrig_GestureActive {
        HoleTriggers_StopRButtonHoldPoll()
        return
    }
    if HoleTriggers_AnyCircleEnabled() {
        global g_HoleTrig_RButtonWatch
        pathLen := HoleTriggers_ComputePathLength(g_HoleTrig_Points)
        if (pathLen >= 36 || g_HoleTrig_HoldStillBroken || g_HoleTrig_RButtonWatch)
            return
    }
    if !HoleTriggers_IsRButtonPhysicallyDown() {
        elapsed := A_TickCount - g_HoleTrig_StartTick
        if !HoleTriggers_IsRButtonReallyUp() && elapsed < Integer(g_HoleTrig_RButtonMinPressMs)
            return
        HoleTriggers_StopRButtonHoldPoll()
        HoleTriggers_OnRButtonUp()
        return
    }
    now := A_TickCount
    if (g_HoleTrig_HoldPollLastTick < 1)
        g_HoleTrig_HoldPollLastTick := now
    dt := now - g_HoleTrig_HoldPollLastTick
    g_HoleTrig_HoldPollLastTick := now
    holdNeed := HoleTriggers_GetHoldDurationMs()
    holdMax := HoleTriggers_GetRButtonHoldMovePx()
    circleBreak := HoleTriggers_GetRButtonCircleBreakMovePx()
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    dx := mx - g_HoleTrig_StartX
    dy := my - g_HoleTrig_StartY
    dist := Sqrt(dx * dx + dy * dy)
    if HoleTriggers_ShouldBreakHoldForCircle(dist) {
        g_HoleTrig_HoldStillBroken := true
        HoleTriggers_StopRButtonHoldPoll()
        HoleTriggers_DiagLog("[HoleTrigger] hold_circle_break dist=" . Round(dist) . " break=" . circleBreak)
        if !g_HoleTrig_RButtonWatch {
            global g_HoleTrig_RButtonWatch, g_HoleTrig_TrackIntervalMs
            g_HoleTrig_RButtonWatch := true
            SetTimer(HoleTriggers_RButtonWatchTick, g_HoleTrig_TrackIntervalMs)
        }
        return
    }
    HoleTriggers_AccumulateHoldStill(dt, dist)
    if !HoleTriggers_HoldStillSatisfied(dist)
        return
    accum := g_HoleTrig_HoldStillAccumMs
    global g_HoleTrig_HoldActivatedThisPress
    g_HoleTrig_HoldActivatedThisPress := true
    HoleTriggers_ClearRButtonCaptureState(true)
    HoleTriggers_DiagLog("[HoleTrigger] hold_early_fire accum=" . accum . " need=" . holdNeed . " dist=" . Round(dist))
    HoleTriggers_ArmRButtonLockUntilUp("hold_early_fire")
    HoleTriggers_ActivateAtScreen(mx, my, "rbutton_hold_early")
}

HoleTriggers_OnRButtonDown_Wrapped(*) {
    HoleTriggers_OnRButtonDown()
}

HoleTriggers_OnRButtonUp_Wrapped(*) {
    global g_HoleTrig_RButtonPhysDown
    g_HoleTrig_RButtonPhysDown := false
    HoleTriggers_StopRButtonHoldPoll()
    HoleTriggers_OnRButtonUp()
}

; 模块加载后周期性确保钩子在线（不依赖 #HotIf / 单次 Sync 时机）
SetTimer(HoleTriggers_EnsureInputAlive, 1500)
HoleTriggers_DiagLog("[HoleTrigger] module_loaded")
