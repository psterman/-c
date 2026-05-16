#Requires AutoHotkey v2.0

global LegacyGuard_ClipWaitLongThresholdMs := 280
global LegacyGuard_ClipWaitStepMs := 35
global LegacyGuard_ClipWaitLogCooldownMs := 800
global LegacyGuard_LastClipWaitLogTick := 0

global LegacyGuard_WinHttpLogCooldownMs := 350
global LegacyGuard_LastWinHttpWarnTick := 0

LegacyGuard_Log(tag, detail := "") {
    try {
        ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        line := "[" . ts . "][" . String(tag) . "] " . String(detail) . "`r`n"
        if FuncExists("NMER_AsyncLog")
            NMER_AsyncLog(A_ScriptDir . "\Cache\legacy_guardrails.log", line)
        else
            FileAppend(line, A_ScriptDir . "\Cache\legacy_guardrails.log", "UTF-8")
    } catch {
    }
}

LegacyGuard_SafeSleep(ms) {
    t := Integer(ms)
    if (t < 1)
        t := 1
    DllCall("Sleep", "UInt", t)
}

LegacyGuard_HasClipboardText() {
    try {
        return !!DllCall("IsClipboardFormatAvailable", "UInt", 13, "Int") ; CF_UNICODETEXT
    } catch {
        return false
    }
}

LegacyGuard_HasAnyClipboardData() {
    if !DllCall("OpenClipboard", "Ptr", 0, "Int")
        return false
    fmt := 0
    try {
        fmt := DllCall("EnumClipboardFormats", "UInt", 0, "UInt")
        return (fmt != 0)
    } catch {
        return false
    } finally {
        DllCall("CloseClipboard")
    }
}

LegacyGuard_TimeoutToMs(timeoutSec) {
    try t := Number(timeoutSec)
    catch {
        t := 0.0
    }
    if (t <= 0)
        return 0
    return Integer(Round(t * 1000.0))
}

ClipWait(timeout := 0, waitForAnyData := 0) {
    global LegacyGuard_ClipWaitLongThresholdMs, LegacyGuard_ClipWaitStepMs
    global LegacyGuard_LastClipWaitLogTick, LegacyGuard_ClipWaitLogCooldownMs

    reqMs := LegacyGuard_TimeoutToMs(timeout)
    start := A_TickCount
    anyData := !!waitForAnyData
    if (reqMs >= LegacyGuard_ClipWaitLongThresholdMs) {
        if ((A_TickCount - LegacyGuard_LastClipWaitLogTick) > LegacyGuard_ClipWaitLogCooldownMs) {
            LegacyGuard_LastClipWaitLogTick := A_TickCount
            LegacyGuard_Log("clipwait_long_timeout", "timeout_ms=" . reqMs . " any=" . (anyData ? "1" : "0"))
        }
    }

    checkFn := anyData ? LegacyGuard_HasAnyClipboardData : LegacyGuard_HasClipboardText
    if checkFn.Call() {
        elapsed0 := A_TickCount - start
        LegacyGuard_Log("clipwait_wrapped", "result=1 timeout_ms=" . reqMs . " elapsed_ms=" . elapsed0 . " any=" . (anyData ? "1" : "0"))
        return 1
    }

    if (reqMs = 0) {
        Loop {
            if checkFn.Call() {
                elapsedInf := A_TickCount - start
                LegacyGuard_Log("clipwait_wrapped", "result=1 timeout_ms=0 elapsed_ms=" . elapsedInf . " any=" . (anyData ? "1" : "0"))
                return 1
            }
            LegacyGuard_SafeSleep(LegacyGuard_ClipWaitStepMs)
        }
    }

    deadline := start + reqMs
    while (A_TickCount < deadline) {
        if checkFn.Call() {
            elapsed := A_TickCount - start
            LegacyGuard_Log("clipwait_wrapped", "result=1 timeout_ms=" . reqMs . " elapsed_ms=" . elapsed . " any=" . (anyData ? "1" : "0"))
            return 1
        }
        remain := deadline - A_TickCount
        if (remain <= 0)
            break
        LegacyGuard_SafeSleep(Min(LegacyGuard_ClipWaitStepMs, remain))
    }
    elapsed2 := A_TickCount - start
    LegacyGuard_Log("clipwait_timeout", "result=0 timeout_ms=" . reqMs . " elapsed_ms=" . elapsed2 . " any=" . (anyData ? "1" : "0"))
    return 0
}

LegacyGuard_ShouldWhitelistActivate(hwnd, winTitle := "") {
    if !hwnd
        return false
    try {
        if WinActive("ahk_id " . hwnd)
            return true
    } catch {
    }
    try {
        pn := StrLower(WinGetProcessName("ahk_id " . hwnd))
        if (pn = "autohotkey64.exe" || pn = "autohotkey32.exe" || pn = "autohotkey.exe")
            return true
    } catch {
    }
    return false
}

LegacyGuard_SetForegroundSoft(hwnd) {
    if !hwnd
        return false
    retries := 3
    while (retries > 0) {
        retries -= 1
        try DllCall("ShowWindow", "Ptr", hwnd, "Int", 9) ; SW_RESTORE
        ok := 0
        try ok := !!DllCall("SetForegroundWindow", "Ptr", hwnd, "Int")
        if ok {
            try {
                if WinActive("ahk_id " . hwnd)
                    return true
            } catch {
            }
        }
        LegacyGuard_SafeSleep(40)
    }
    return false
}

LegacyGuard_RequestFocus(owner, target, priority := 40, reason := "", protectMs := 120, focusCb := 0) {
    o := String(owner)
    rs := String(reason)
    pri := Integer(priority)
    pm := Integer(protectMs)
    hwnd := 0
    try {
        if (Type(target) = "Integer")
            hwnd := Integer(target)
        else {
            q := Trim(String(target))
            if (q != "")
                hwnd := WinExist(q)
        }
    } catch {
        hwnd := 0
    }
    if !hwnd
        return false

    if FuncExists("FocusBroker_Request") {
        try {
            ok := FocusBroker_Request(o != "" ? o : "LegacyFocus", hwnd, pri, rs != "" ? rs : "legacy_guard", pm, focusCb)
            if ok
                return true
        } catch {
        }
    }
    return LegacyGuard_SetForegroundSoft(hwnd)
}

LegacyGuard_RequestCursorFocus(owner := "LegacyFocus", reason := "cursor_focus", protectMs := 120) {
    return LegacyGuard_RequestFocus(owner, "ahk_exe Cursor.exe", 45, reason, protectMs)
}

WinActivate(winTitle := "", winText := "", excludeTitle := "", excludeText := "") {
    hwnd := 0
    try {
        if (Type(winTitle) = "Integer")
            hwnd := Integer(winTitle)
        else if (Trim(String(winTitle)) != "")
            hwnd := WinExist(String(winTitle), String(winText), String(excludeTitle), String(excludeText))
        else
            hwnd := WinExist("A")
    } catch {
        hwnd := 0
    }
    if !hwnd
        throw TargetError("Target window not found.", -1)

    if LegacyGuard_ShouldWhitelistActivate(hwnd, winTitle) {
        LegacyGuard_Log("focus_whitelisted", "hwnd=" . hwnd . " title=" . String(winTitle))
        return true
    }

    if FuncExists("FocusBroker_Request") {
        LegacyGuard_Log("focus_soft_request", "owner=legacy_winactivate hwnd=" . hwnd . " title=" . String(winTitle))
        try {
            FocusBroker_Request("LegacyWinActivate", hwnd, 45, "legacy_winactivate", 120)
            return true
        } catch {
        }
    }

    ok2 := LegacyGuard_SetForegroundSoft(hwnd)
    if !ok2
        LegacyGuard_Log("focus_blocked", "hwnd=" . hwnd . " title=" . String(winTitle) . " reason=soft_request_failed")
    return ok2
}

LegacyGuard_WinHttpBeforeSync(moduleName, method, url, reason := "", &token := 0) {
    global CoreAsyncStrictMode, LegacySyncFallback
    mod := String(moduleName)
    m := StrUpper(Trim(String(method)))
    u := String(url)
    rs := String(reason)
    token := Map("start", A_TickCount, "module", mod, "method", m, "url", u, "reason", rs)
    LegacyGuard_Log("sync_path_blocked_winhttp_begin", "module=" . mod . " method=" . m . " reason=" . rs . " url=" . u)

    strict := false
    fallback := true
    try strict := !!CoreAsyncStrictMode
    catch {
    }
    try fallback := !!LegacySyncFallback
    catch {
    }
    if (strict && !fallback) {
        LegacyGuard_Log("sync_path_blocked_winhttp_error", "module=" . mod . " method=" . m . " reason=strict_block_no_fallback")
        return false
    }
    if (strict && fallback)
        LegacyGuard_Log("sync_path_blocked_winhttp_warn", "module=" . mod . " mode=legacy_fallback_allow")
    return true
}

LegacyGuard_WinHttpAfterSync(token, status := 0) {
    if !(token is Map)
        return
    elapsed := A_TickCount - Integer(token["start"])
    LegacyGuard_Log("sync_path_blocked_winhttp_end"
        , "module=" . token["module"] . " method=" . token["method"] . " status=" . Integer(status) . " elapsed_ms=" . elapsed . " reason=" . token["reason"])
}

LegacyGuard_WinHttpError(token, errMsg := "") {
    if !(token is Map)
        return
    elapsed := A_TickCount - Integer(token["start"])
    LegacyGuard_Log("sync_path_blocked_winhttp_error"
        , "module=" . token["module"] . " method=" . token["method"] . " elapsed_ms=" . elapsed . " reason=" . token["reason"] . " msg=" . String(errMsg))
}
