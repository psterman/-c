; ScreenshotWorkflow.ahk 鈥?鎴浘涓氬姟娴佺▼锛堟櫤鑳借彍鍗曘€佸尯鍩熸埅鍥俱€佹偓娴寜閽瓑锛岀敱涓昏剼鏈?#Include锛?
; 渚濊禆锛歋howScreenshotEditor銆丆loseScreenshotEditor銆丏eferredScreenshotHistorySave銆丟etScreenInfo銆?
; UI_Colors銆乀hemeMode銆丗loatingToolbar銆丠ideCursorPanel銆両magePut/OCR銆丟etText 绛夈€?

; ===================== 鎴浘鍚庢櫤鑳藉鐞嗚彍鍗?=====================
; 浠庢偓娴潯闅愯棌宸ュ叿鏍忓悗鍙戣捣鎴浘鏃讹紝鍦ㄥ壀璐存澘灏辩华銆佹樉绀哄姪鎵嬪墠鎭㈠鎮诞鏉★紙閬垮厤涓?finally 寤惰繜 Show 閲嶅瀵艰嚧鍙屽紑/鍋忕Щ锛?
ScreenshotFlowRestoreFloatingToolbarIfNeeded() {
    global FloatingToolbar_ScheduleRestoreAfterScreenshot, AppearanceActivationMode
    if (FloatingToolbar_ScheduleRestoreAfterScreenshot) {
        FloatingToolbar_ScheduleRestoreAfterScreenshot := false
        if (NormalizeAppearanceActivationMode(AppearanceActivationMode) != "toolbar")
            return
        try ShowFloatingToolbar()
        catch as _e {
        }
    }
}

ScreenshotFlowReadOutputTarget() {
    cfg := A_ScriptDir . "\CursorShortcut.ini"
    out := "editor"
    try out := Trim(StrLower(IniRead(cfg, "Screenshot", "OutputTarget", "editor")))
    if (out != "editor" && out != "clipboard" && out != "both")
        out := "editor"
    return out
}

ScreenshotFlowReadCaptureMode() {
    cfg := A_ScriptDir . "\CursorShortcut.ini"
    mode := "selection"
    try mode := Trim(StrLower(IniRead(cfg, "Screenshot", "CaptureMode", "selection")))
    if (mode != "selection" && mode != "fullscreen" && mode != "active_window")
        mode := "selection"
    return mode
}

; 鎵ц鎴浘骞剁瓑寰呭畬鎴愬悗寮瑰嚭鏅鸿兘鑿滃崟
; fromFloatingDeferred: 涓?true 鏃惰〃绀?FloatingToolbar_DeferredScreenshot 宸插湪 Hide/Sleep 鍓嶅師瀛愬湴鍗犵敤浜?g_ExecuteScreenshotWithMenuBusy锛屾澶勪笉寰楀洜 busy 鑰?return
ExecuteScreenshotWithMenu(fromFloatingDeferred := false) {
    global CursorPath, AISleepTime, ScreenshotWaiting, ScreenshotClipboard, ScreenshotOldClipboard, ScreenshotLastFilePath
    global ScreenshotImageDetected
    global PanelVisible
    global g_ExecuteScreenshotWithMenuBusy, FloatingToolbar_ScheduleRestoreAfterScreenshot
    global g_ScreenshotSuspendActivationToken
    try OutputDebug("[SSWF] begin fromFloatingDeferred=" . (fromFloatingDeferred ? "1" : "0") . " busy=" . (g_ExecuteScreenshotWithMenuBusy ? "1" : "0"))
    catch {
    }
    ; 涓庣儹閿?瀹氭椂鍣ㄧ嚎绋嬬珵鎬侊細Sleep 璁╁嚭鎵ц鏉冨墠 busy 妫€鏌ヤ笌璧嬪€奸』鍘熷瓙鍖栵紱Deferred 璺緞鍦?Sleep 鍓嶉鍗?busy锛岄伩鍏嶇浜屾 Deferred 鍙犲姞鍏ュ彛
    prevCrit := Critical("On")
    if (g_ExecuteScreenshotWithMenuBusy && !fromFloatingDeferred) {
        Critical(prevCrit)
        return
    }
    if (!fromFloatingDeferred)
        g_ExecuteScreenshotWithMenuBusy := true
    Critical(prevCrit)
    try {
    screenshotSessionToken := 0
    ; 鍒濆鍖?DebugGui 鍙橀噺
    DebugGui := 0
    
    ; 鍒涘缓璋冭瘯绐楀彛
    try {
        DebugGui := CreateScreenshotDebugWindow()
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 1, "寮€濮嬫墽琛屾埅鍥炬祦绋?..", true)
        }
    } catch as e {
        ; 濡傛灉鍒涘缓璋冭瘯绐楀彛澶辫触锛岀户缁墽琛屼絾涓嶆樉绀鸿皟璇曚俊鎭?
        TrayTip("璀﹀憡", "鏃犳硶鍒涘缓璋冭瘯绐楀彛: " . e.Message, "Icon! 1")
    }
    
    try {
        ; 闅愯棌闈㈡澘锛堝鏋滄樉绀猴級
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 2, "妫€鏌ュ苟闅愯棌闈㈡澘...", false)
        }
        if (PanelVisible) {
            HideCursorPanel()
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 2, "闈㈡澘宸查殣钘?", true)
            }
        } else {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 2, "闈㈡澘鏈樉绀猴紝璺宠繃", true)
            }
        }
        
        ; 淇濆瓨褰撳墠鍓创鏉垮唴瀹?
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 3, "淇濆瓨褰撳墠鍓创鏉垮唴瀹?..", false)
        }
        ScreenshotOldClipboard := ClipboardAll()
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 3, "鍓创鏉垮唴瀹瑰凡淇濆瓨", true)
        }
        
        ; 鍚姩绛夊緟鎴浘妯″紡
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 4, "璁剧疆绛夊緟鐘舵€?..", false)
        }
        ScreenshotWaiting := true
        ScreenshotImageDetected := false
        try OutputDebug("[SSWF] waiting armed")
        catch {
        }
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 4, "绛夊緟鐘舵€佸凡璁剧疆", true)
        }
        
        ; 璁板綍鍓创鏉垮簭鍒楀彿骞舵竻绌哄壀璐存澘锛岀‘淇濆悗缁兘妫€娴嬪埌鈥滄柊鎴浘鈥?
        A_Clipboard := ""
        Sleep(80)
        ClipboardSeqBeforeShot := DllCall("GetClipboardSequenceNumber", "UInt")
        try {
            if (BeginScreenshotUiSession()) {
                screenshotSessionToken := g_ScreenshotSuspendActivationToken
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 4, "榛戞礊閽╁瓙宸蹭复鏃跺仠鐢?", true)
                }
            }
        } catch as e {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 4, "涓存椂鍋滅敤榛戞礊閽╁瓙澶辫触: " . e.Message, false)
            }
        }

        ; 渚濇嵁鎴浘妯″紡瑙﹀彂涓嶅悓鐨勭郴缁熸崟鑾锋柟寮?
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 5, "瑙﹀彂鎴浘妯″紡...", false)
        }
        captureMode := ScreenshotFlowReadCaptureMode()
        if (captureMode = "fullscreen") {
            Send("{PrintScreen}")
        } else if (captureMode = "active_window") {
            Send("!{PrintScreen}")
        } else {
            Send("#+{s}")
        }
        try OutputDebug("[SSWF] capture sent mode=" . captureMode . " seq_before=" . ClipboardSeqBeforeShot)
        catch {
        }
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 5, "鎴浘瑙﹀彂鍛戒护宸插彂閫侊紙" . captureMode . "锛?", true)
        }
        
        ; 绛夊緟鐢ㄦ埛瀹屾垚鎴浘锛堟渶澶氱瓑寰?0绉掞級
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 6, "鍒濆鍖栫瓑寰呭弬鏁?..", false)
        }
        MaxWaitTime := 30000  ; 30绉?
        WaitInterval := 200   ; 姣?00ms妫€鏌ヤ竴娆?
        ElapsedTime := 0
        ScreenshotTaken := false
        CapturedClipNow := ""
        CapturedFileNow := ""
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 6, "绛夊緟鍙傛暟宸插垵濮嬪寲 (鏈€澶?0绉?", true)
        }
        
        ; 绛夊緟涓€涓嬶紝璁╂埅鍥惧伐鍏峰惎鍔?
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 7, "绛夊緟鎴浘宸ュ叿鍚姩 (500ms)...", false)
        }
        Sleep(500)
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 7, "绛夊緟瀹屾垚锛屽紑濮嬬洃鎺у壀璐存澘...", true)
        }
        
        ; 鐩戞帶鍓创鏉匡紝绛夊緟鎴浘瀹屾垚
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 8, "鐩戞帶鍓创鏉匡紝绛夊緟鎴浘瀹屾垚...", false)
        }
        CheckCount := 0
        while (ElapsedTime < MaxWaitTime) {
            CheckCount++
            if (Mod(CheckCount, 10) = 0 && DebugGui) {
                UpdateDebugStep(DebugGui, 8, "鐩戞帶涓?.. (宸茬瓑寰?" . Round(ElapsedTime/1000) . " 绉?", false)
            }
            Sleep(WaitInterval)
            ElapsedTime += WaitInterval
            
            ; 涓昏妫€娴嬶細OnClipboardChange 鍥炶皟宸叉娴嬪埌鍥剧墖鍐欏叆
            if (ScreenshotImageDetected) {
                ScreenshotTaken := true
                CapturedClipNow := ScreenshotClipboard
                CapturedFileNow := ScreenshotLastFilePath
                if (!CapturedClipNow && CapturedFileNow = "")
                    try ScreenshotCapturePayload(&CapturedClipNow, &CapturedFileNow, 1200)
                try OutputDebug("[SSWF] screenshot detected via ScreenshotImageDetected elapsed_ms=" . ElapsedTime)
                catch {
                }
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 8, "OnClipboardChange 妫€娴嬪埌鍥剧墖锛屾埅鍥惧畬鎴愶紒", true)
                }
                break
            }
            
            ; 澶囩敤妫€娴嬶細鐩存帴杞鍓创鏉垮簭鍒楀彿 + 鏍煎紡锛岄伩鍏嶆妸闈炲浘鐗囧綋鎴愭埅鍥炬垚鍔熲€滃浘鐗囨牸寮忓彲鐢ㄢ€濓紝閬垮厤鎶婇潪鍥剧墖褰撴垚鎴浘鎴愬姛
            try {
                ClipboardSeqNow := DllCall("GetClipboardSequenceNumber", "UInt")
                if (ClipboardSeqNow = ClipboardSeqBeforeShot) {
                    continue
                }
                if (DllCall("OpenClipboard", "Ptr", 0)) {
                    ; 妫€鏌ユ槸鍚﹀寘鍚綅鍥炬牸寮?
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 2)) {  ; CF_BITMAP = 2
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        CapturedClipNow := ScreenshotClipboard
                        CapturedFileNow := ScreenshotLastFilePath
                        if (!CapturedClipNow && CapturedFileNow = "")
                            try ScreenshotCapturePayload(&CapturedClipNow, &CapturedFileNow, 1200)
                        if (DebugGui) {
                            UpdateDebugStep(DebugGui, 8, "妫€娴嬪埌 CF_BITMAP 鏍煎紡锛屾埅鍥惧畬鎴愶紒", true)
                        }
                        break
                    }
                    ; 妫€鏌ユ槸鍚﹀寘鍚?DIB / DIBV5 鏍煎紡
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 8)) {  ; CF_DIB = 8
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        CapturedClipNow := ScreenshotClipboard
                        CapturedFileNow := ScreenshotLastFilePath
                        if (!CapturedClipNow && CapturedFileNow = "")
                            try ScreenshotCapturePayload(&CapturedClipNow, &CapturedFileNow, 1200)
                        if (DebugGui) {
                            UpdateDebugStep(DebugGui, 8, "妫€娴嬪埌 CF_DIB 鏍煎紡锛屾埅鍥惧畬鎴愶紒", true)
                        }
                        break
                    }
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 17)) {  ; CF_DIBV5 = 17
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        CapturedClipNow := ScreenshotClipboard
                        CapturedFileNow := ScreenshotLastFilePath
                        if (!CapturedClipNow && CapturedFileNow = "")
                            try ScreenshotCapturePayload(&CapturedClipNow, &CapturedFileNow, 1200)
                        if (DebugGui) {
                            UpdateDebugStep(DebugGui, 8, "妫€娴嬪埌 CF_DIBV5 鏍煎紡锛屾埅鍥惧畬鎴愶紒", true)
                        }
                        break
                    }
                    ; 妫€鏌ユ槸鍚﹀寘鍚?PNG 鏍煎紡
                    PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
                    if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        CapturedClipNow := ScreenshotClipboard
                        CapturedFileNow := ScreenshotLastFilePath
                        if (!CapturedClipNow && CapturedFileNow = "")
                            try ScreenshotCapturePayload(&CapturedClipNow, &CapturedFileNow, 1200)
                        if (DebugGui) {
                            UpdateDebugStep(DebugGui, 8, "妫€娴嬪埌 PNG 鏍煎紡锛屾埅鍥惧畬鎴愶紒", true)
                        }
                        break
                    }
                    DllCall("CloseClipboard")
                }
            } catch as e {
                ; 濡傛灉妫€娴嬪け璐ワ紝缁х画绛夊緟
            }
        }
        
        ; 濡傛灉鎴浘鎴愬姛锛屼繚瀛樻埅鍥惧苟寮瑰嚭鏅鸿兘鑿滃崟
        if (ScreenshotTaken) {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 9, "鎴浘妫€娴嬫垚鍔燂紝寮€濮嬩繚瀛樻埅鍥炬暟鎹?..", false)
            }
            ; 绛夊緟涓€涓嬬‘淇濇埅鍥惧凡淇濆瓨鍒板壀璐存澘
            Sleep(300)
            
            ; 淇濆瓨鎴浘鍒板叏灞€鍙橀噺
            try {
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 10, "璋冪敤 ClipboardAll() 淇濆瓨鎴浘...", false)
                }
                ; 鍐嶆纭褰撳墠鍓创鏉跨‘瀹炴槸鍥剧墖锛岄槻姝㈢珵浜夋潯浠跺鑷翠繚瀛樺埌闈炲浘鐗囨暟鎹?
                if (CapturedClipNow || CapturedFileNow != "") {
                    ScreenshotClipboard := CapturedClipNow
                    ScreenshotLastFilePath := CapturedFileNow
                } else if (!ScreenshotCapturePayload(&ScreenshotClipboard, &ScreenshotLastFilePath, 3200)) {
                    throw Error("未捕获到截图数据（剪贴板/自动保存文件）")
                }
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 10, "鎴浘鏁版嵁宸蹭繚瀛樺埌 ScreenshotClipboard", true)
                }
            } catch as e {
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 10, "淇濆瓨鎴浘澶辫触: " . e.Message, false)
                }
                TrayTip("保存截图失败", e.Message, "Iconx 2")
                A_Clipboard := ScreenshotOldClipboard
                ScreenshotWaiting := false
                if (DebugGui) {
                    try {
                        DebugGui.Destroy()
                    } catch {
                        ; 蹇界暐閿€姣侀敊璇?
                    }
                }
                ScreenshotFlowRestoreFloatingToolbarIfNeeded()
                return
            }
            
            ; 鎭㈠鏃у壀璐存澘锛堥瑙堢獥浼氶噸鏂拌缃級
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 11, "鎭㈠鏃у壀璐存澘鍐呭...", false)
            }
            A_Clipboard := ScreenshotOldClipboard
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 11, "鏃у壀璐存澘宸叉仮澶?", true)
            }
            
            ; 娓呴櫎绛夊緟鐘舵€?
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 12, "娓呴櫎绛夊緟鐘舵€?..", false)
            }
            ScreenshotWaiting := false
            SetTimer(DeferredScreenshotHistorySave, -800)
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 12, "绛夊緟鐘舵€佸凡娓呴櫎", true)
            }
            
            ; 绛夊緟鎴浘宸ュ叿鍏抽棴鍚庡啀鎭㈠鎮诞鏉″苟鎵撳紑鍔╂墜锛堥伩鍏嶄笌寤惰繜 Show 閲嶅瀵艰嚧鍙屽紑/浣嶇疆鍋忕Щ锛?
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 13, "绛夊緟鎴浘宸ュ叿鍏抽棴...", false)
            }
            Sleep(400)
            CloseAllScreenshotWindows()
            Sleep(150)
            Sleep(200)
            outputTarget := ScreenshotFlowReadOutputTarget()
            if (fromFloatingDeferred)
                FloatingToolbar_ScheduleRestoreAfterScreenshot := false
            if (outputTarget = "clipboard") {
                ScreenshotFlowRestoreFloatingToolbarIfNeeded()
                try OutputDebug("[SSWF] clipboard-only output, no preview")
                catch {
                }
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 13, "杈撳嚭鐩爣=浠呭壀璐存澘锛岃烦杩囨埅鍥惧姪鎵嬮瑙?", true)
                    SetTimer(DestroyDebugGui.Bind(DebugGui), -1200)
                }
                TrayTip("提示", "截图已复制到剪贴板", "Iconi 1")
                try EndScreenshotUiSession(screenshotSessionToken)
                catch {
                }
                return
            }
            ; 寮瑰嚭鎴浘鍔╂墜棰勮绐楋紙鏇夸唬鏅鸿兘鑿滃崟锛?
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 13, "调用 ShowScreenshotEditor() 显示预览与工具栏...", false)
            }
            try {
                try OutputDebug("[SSWF] calling ShowScreenshotEditor")
                catch {
                }
                ShowScreenshotEditor(DebugGui)
                try OutputDebug("[SSWF] ShowScreenshotEditor returned")
                catch {
                }
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 13, "ShowScreenshotEditor() 璋冪敤鎴愬姛", true)
                }
                TrayTip("调试", "ShowScreenshotEditor() 调用成功", "Iconi 1")
                ; 寤惰繜鍏抽棴璋冭瘯绐楀彛锛岃鐢ㄦ埛鐪嬪埌鏈€鍚庣殑鐘舵€?
                if (DebugGui) {
                    SetTimer(DestroyDebugGui.Bind(DebugGui), -2000)
                }
            } catch as e {
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 13, "ShowScreenshotEditor() 失败: " . e.Message, false)
                }
                ErrorMsg := "显示截图助手失败:`n"
                ErrorMsg .= "错误: " . e.Message . "`n"
                ErrorMsg .= "鏂囦欢: " . (e.HasProp("File") ? e.File : "鏈煡") . "`n"
                ErrorMsg .= "琛屽彿: " . (e.HasProp("Line") ? e.Line : "鏈煡") . "`n"
                ErrorMsg .= "鍫嗘爤: " . (e.HasProp("Stack") ? e.Stack : "鏈煡")
                MsgBox(ErrorMsg, "鎴浘鍔╂墜閿欒", "Icon!")
                if (DebugGui) {
                    SetTimer(DestroyDebugGui.Bind(DebugGui), -3000)
                }
            }
        } else {
            ; 鎴浘瓒呮椂鎴栧彇娑堬紝鎭㈠鏃у壀璐存澘
            try OutputDebug("[SSWF] screenshot timeout/cancel elapsed_ms=" . ElapsedTime)
            catch {
            }
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 9, "鎴浘瓒呮椂鎴栧彇娑?(绛夊緟浜?" . Round(ElapsedTime/1000) . " 绉?", false)
            }
            A_Clipboard := ScreenshotOldClipboard
            ScreenshotWaiting := false
            TrayTip("鎻愮ず", "鎴浘宸插彇娑堟垨瓒呮椂", "Iconi 1")
            if (DebugGui) {
                SetTimer(DestroyDebugGui.Bind(DebugGui), -2000)
            }
            ScreenshotFlowRestoreFloatingToolbarIfNeeded()
            try EndScreenshotUiSession(screenshotSessionToken)
            catch {
            }
        }
    } catch as e {
        try OutputDebug("[SSWF] exception: " . e.Message)
        catch {
        }
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 0, "鍙戠敓寮傚父: " . e.Message . "`n鏂囦欢: " . (e.File ? e.File : "鏈煡") . "`n琛屽彿: " . (e.Line ? e.Line : "鏈煡"), false)
        }
        TrayTip("鎴浘澶辫触: " . e.Message, GetText("error"), "Iconx 2")
        try {
            A_Clipboard := ScreenshotOldClipboard
        }
        ScreenshotWaiting := false
        if (DebugGui) {
            SetTimer(DestroyDebugGui.Bind(DebugGui), -3000)
        }
        ScreenshotFlowRestoreFloatingToolbarIfNeeded()
        try EndScreenshotUiSession(screenshotSessionToken)
        catch {
        }
    }
    } finally {
        g_ExecuteScreenshotWithMenuBusy := false
    }
}

; 閿€姣佽皟璇曠獥鍙ｇ殑杈呭姪鍑芥暟
DestroyDebugGui(DebugGui) {
    try {
        if (DebugGui && IsObject(DebugGui)) {
            DebugGui.Destroy()
        }
    } catch {
        ; 蹇界暐閿€姣侀敊璇?
    }
}

; 鍒涘缓鎴浘璋冭瘯绐楀彛
CreateScreenshotDebugWindow() {
    try {
        DebugGui := Gui("+AlwaysOnTop +ToolWindow -MaximizeBox -MinimizeBox", "鎴浘娴佺▼璋冭瘯")
        if (!DebugGui) {
            throw Error("鏃犳硶鍒涘缓 GUI 瀵硅薄")
        }
        DebugGui.BackColor := "0x1E1E1E"
        DebugGui.SetFont("s9", "Consolas")
        
        ; 鏍囬
        TitleText := DebugGui.Add("Text", "x10 y10 w780 h30 Center c0xFFFFFF Background0x2D2D2D", "馃搳 鎴浘娴佺▼璋冭瘯淇℃伅")
        if (TitleText) {
            TitleText.SetFont("s11 Bold", "Segoe UI")
        }
        
        ; 姝ラ鏄剧ず鍖哄煙
        StepsText := DebugGui.Add("Edit", "x10 y50 w780 h450 ReadOnly Multi Background0x2D2D2D c0xCCCCCC", "")
        if (StepsText) {
            StepsText.SetFont("s9", "Consolas")
        }
        
        ; 淇濆瓨寮曠敤浠ヤ究鏇存柊
        if (StepsText) {
            DebugGui["StepsText"] := StepsText
            DebugGui["Steps"] := []
        }
        
        ; 鍏抽棴鎸夐挳
        CloseBtn := DebugGui.Add("Button", "x350 y510 w120 h35 Default", "鍏抽棴")
        if (CloseBtn) {
            CloseBtn.OnEvent("Click", (*) => DebugGui.Destroy())
        }
        
        ; 鏄剧ず绐楀彛
        DebugGui.Show("w800 h560")
        
        return DebugGui
    } catch as e {
        ; 濡傛灉鍒涘缓澶辫触锛岃繑鍥?0
        return 0
    }
}

; 鏇存柊璋冭瘯姝ラ
UpdateDebugStep(DebugGui, StepNum, Message, IsSuccess) {
    if (!DebugGui || !IsObject(DebugGui["Steps"])) {
        return
    }
    
    Steps := DebugGui["Steps"]
    StepsText := DebugGui["StepsText"]
    
    ; 鏍煎紡鍖栨楠や俊鎭?
    ; 鍦?AutoHotkey v2 涓紝FormatTime 鐨勭涓€涓弬鏁板彲浠ヤ负绌哄瓧绗︿覆琛ㄧず褰撳墠鏃堕棿
    TimeStr := FormatTime("", "HH:mm:ss.fff")
    StatusIcon := IsSuccess ? "OK" : "WARN"
    StatusColor := IsSuccess ? "0x00FF00" : "0xFFFF00"
    
    StepInfo := "[" . TimeStr . "] "
    if (StepNum > 0) {
        StepInfo .= "姝ラ " . StepNum . ": "
    }
    StepInfo .= Message
    
    ; 娣诲姞鍒版楠ゅ垪琛?
    Steps.Push(StepInfo)
    
    ; 鏇存柊鏄剧ず锛堝彧鏄剧ず鏈€鍚?0涓楠わ級
    DisplayText := ""
    StartIdx := Steps.Length > 30 ? Steps.Length - 30 : 1
    Loop Steps.Length - StartIdx + 1 {
        idx := StartIdx + A_Index - 1
        DisplayText .= Steps[idx] . "`n"
    }
    
    StepsText.Value := DisplayText
    StepsText.Focus()
}

; 鏄剧ず鍓创鏉挎櫤鑳藉鐞嗚彍鍗?
ShowClipboardSmartMenu(ForceType := "") {
    global GuiID_ClipboardSmartMenu, UI_Colors, ThemeMode, PanelVisible
    global ClipboardMenuSelectedIndex, ClipboardMenuButtons, ClipboardMenuOptions
    
    ; 濡傛灉闈㈡澘宸叉樉绀猴紝鍏堥殣钘?
    if (PanelVisible) {
        HideCursorPanel()
    }
    
    ; 濡傛灉鑿滃崟宸插瓨鍦紝鍏堥攢姣?
    if (GuiID_ClipboardSmartMenu != 0) {
        try {
            GuiID_ClipboardSmartMenu.Destroy()
        } catch as err {
            ; 蹇界暐閿欒
        }
        global GuiID_ClipboardSmartMenu := 0
    }
    
    ; 妫€鏌ュ壀璐存澘鍐呭绫诲瀷
    if (ForceType != "") {
        ; 寮哄埗鎸囧畾绫诲瀷锛堟埅鍥惧悗浣跨敤锛?
        ClipboardType := ForceType
    } else {
        ; 鑷姩妫€娴嬬被鍨?
        ClipboardType := GetClipboardType()
    }
    
    ; 鍒涘缓鑿滃崟 GUI
    GuiID_ClipboardSmartMenu := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    GuiID_ClipboardSmartMenu.BackColor := UI_Colors.Background
    GuiID_ClipboardSmartMenu.SetFont("s11 c" . UI_Colors.Text, "Segoe UI")
    
    ; 鑿滃崟灏哄
    MenuWidth := 420
    MenuHeight := 0  ; 鍔ㄦ€佽绠?
    ButtonHeight := 50
    ButtonSpacing := 8
    Padding := 20
    
    ; 褰撳墠 Y 浣嶇疆
    CurrentY := Padding
    
    ; 鏍囬
    TitleText := GuiID_ClipboardSmartMenu.Add("Text", "x" . Padding . " y" . CurrentY . " w" . (MenuWidth - Padding * 2) . " h30 Center c" . UI_Colors.Text, "Smart Clipboard")
    TitleText.SetFont("s13 Bold", "Segoe UI")
    CurrentY += 35
    
    ; 鎻愮ず鏂囧瓧锛堟牴鎹被鍨嬫樉绀轰笉鍚屾彁绀猴級
    if (ClipboardType = "image") {
        HintText := GuiID_ClipboardSmartMenu.Add("Text", "x" . Padding . " y" . CurrentY . " w" . (MenuWidth - Padding * 2) . " h20 Center c" . UI_Colors.TextDim, "Image detected, choose an action")
    } else if (ClipboardType = "text") {
        HintText := GuiID_ClipboardSmartMenu.Add("Text", "x" . Padding . " y" . CurrentY . " w" . (MenuWidth - Padding * 2) . " h20 Center c" . UI_Colors.TextDim, "Text detected, choose an action")
    } else {
        HintText := GuiID_ClipboardSmartMenu.Add("Text", "x" . Padding . " y" . CurrentY . " w" . (MenuWidth - Padding * 2) . " h20 Center c" . UI_Colors.TextDim, "Clipboard is empty")
    }
    HintText.SetFont("s9", "Segoe UI")
    CurrentY += 25
    
    ; 鏍规嵁鍓创鏉跨被鍨嬫樉绀轰笉鍚岀殑閫夐」
    ClipboardMenuOptions := []
    
    if (ClipboardType = "image") {
        ; 鍥剧墖绫诲瀷锛氭樉绀哄浘鐗囩浉鍏抽€夐」
        ClipboardMenuOptions.Push(Map("icon", "馃攳", "text", "璇嗗浘鍙栬瘝 (淇濈暀甯冨眬)", "desc", "鎻愬彇鏂囧瓧锛屼繚鐣欏師濮嬪垎琛屽拰缂╄繘", "action", "ocr_preserve_layout"))
        ClipboardMenuOptions.Push(Map("icon", "📇", "text", "提取文本 (自动流转)", "desc", "提取文本并做断行合并", "action", "ocr_auto_flow"))
        ClipboardMenuOptions.Push(Map("icon", "🖼", "text", "粘贴图片", "desc", "保留原始图片内容", "action", "paste_image"))
        ; 濡傛灉鏄埅鍥惧悗鐨勮彍鍗曪紝纭繚浣跨敤淇濆瓨鐨勬埅鍥炬暟鎹?
        if (ForceType = "image") {
            ; 鎭㈠鎴浘鍒板壀璐存澘锛屼緵鍚庣画鎿嶄綔浣跨敤
            global ScreenshotClipboard
            if (ScreenshotClipboard) {
                A_Clipboard := ScreenshotClipboard
                Sleep(200)
            }
        }
    } else if (ClipboardType = "text") {
        ; 鏂囨湰绫诲瀷锛氭樉绀烘枃鏈浉鍏抽€夐」
        ClipboardMenuOptions.Push(Map("icon", "馃摑", "text", "鎻愬彇鏂囨湰 (淇濈暀甯冨眬)", "desc", "淇濈暀鍘熷鐨勫垎琛屽拰缂╄繘锛堥€傚悎浠ｇ爜銆佽瘲姝岋級", "action", "extract_preserve_layout"))
        ClipboardMenuOptions.Push(Map("icon", "馃攧", "text", "鎻愬彇鏂囨湰 (鑷姩娴佽浆)", "desc", "鍚堝苟鏂锛屽幓闄や腑鏂囬棿绌烘牸锛堥€傚悎闃呰銆佽鏂囷級", "action", "extract_auto_flow"))
        ClipboardMenuOptions.Push(Map("icon", "✓", "text", "文本净化", "desc", "去除重复空格、统一标点、移除 HTML 标签", "action", "text_cleanup"))
    } else {
        ; 绌哄壀璐存澘鎴栧叾浠栫被鍨?
        ClipboardMenuOptions.Push(Map("icon", "ℹ", "text", "剪贴板为空", "desc", "请先复制内容", "action", "empty"))
    }
    
    ; 鍒濆鍖栨寜閽暟缁勫拰閫変腑绱㈠紩
    ClipboardMenuButtons := []
    ClipboardMenuSelectedIndex := 1  ; 榛樿閫変腑绗竴涓寜閽?
    
    ; 璁＄畻鎸夐挳鑳屾櫙鑹诧紙澧炲己瀵规瘮搴︼紝璁╁厜鏁堟洿鏄庢樉锛?
    ; 濡傛灉鑳屾櫙鏄繁鑹诧紝鎸夐挳浣跨敤绋嶄寒鐨勭伆鑹诧紱濡傛灉鑳屾櫙鏄祬鑹诧紝鎸夐挳浣跨敤绋嶆殫鐨勭伆鑹?
    BtnNormalBg := (ThemeMode = "light") ? "e0e0e0" : "2d2d2d"  ; 姝ｅ父鐘舵€侊紙绋嶆殫锛屼笌鑳屾櫙鏈夊尯鍒級
    BtnHoverBg := (ThemeMode = "light") ? "c0c0c0" : "5a5a5a"   ; 鎮仠鏃剁殑鑳屾櫙鑹诧紙鏄庢樉鐨勫厜鏁堬級
    BtnSelectedBg := (ThemeMode = "light") ? "b0b0b0" : "6a6a6a"  ; 閫変腑鏃剁殑鑳屾櫙鑹诧紙鏇翠寒鐨勫厜鏁堬級
    BtnSelectedHoverBg := (ThemeMode = "light") ? "a0a0a0" : "7a7a7a"  ; 閫変腑+鎮仠鏃剁殑鑳屾櫙鑹诧紙鏈€浜殑鍏夋晥锛?
    
    ; 娣诲姞閫夐」鎸夐挳
    for Index, Option in ClipboardMenuOptions {
        if (Option["action"] = "empty") {
            ; 绌哄壀璐存澘鎻愮ず
            EmptyText := GuiID_ClipboardSmartMenu.Add("Text", "x" . Padding . " y" . CurrentY . " w" . (MenuWidth - Padding * 2) . " h" . ButtonHeight . " Center c" . UI_Colors.TextDim, Option["text"])
            EmptyText.SetFont("s11", "Segoe UI")
            CurrentY += ButtonHeight + ButtonSpacing
        } else {
            ; 鍒涘缓鎸夐挳
            BtnY := CurrentY
            BtnX := Padding
            
            ; 纭畾鎸夐挳鑳屾櫙鑹诧紙閫変腑鏃朵娇鐢ㄦ洿浜殑棰滆壊锛?
            CurrentBtnBg := (Index = ClipboardMenuSelectedIndex) ? BtnSelectedBg : BtnNormalBg
            
            ; 鎸夐挳鑳屾櫙锛堜娇鐢ㄦ洿浜殑鑳屾櫙鑹诧紝纭繚涓庤儗鏅湁瀵规瘮搴︼紝閬垮厤榛戣壊鍧楁晥鏋滐級
            BtnBg := GuiID_ClipboardSmartMenu.Add("Text", "x" . BtnX . " y" . BtnY . " w" . (MenuWidth - Padding * 2) . " h" . ButtonHeight . " Background" . CurrentBtnBg . " vBtnBg" . Index, "")
            
            ; 鍥炬爣鍜屾枃瀛?
            IconText := GuiID_ClipboardSmartMenu.Add("Text", "x" . (BtnX + 15) . " y" . (BtnY + 10) . " w30 h30 Center 0x200 c" . UI_Colors.Text . " BackgroundTrans vBtnIcon" . Index, Option["icon"])
            IconText.SetFont("s16", "Segoe UI")
            
            ; 涓绘枃瀛?
            MainText := GuiID_ClipboardSmartMenu.Add("Text", "x" . (BtnX + 55) . " y" . (BtnY + 8) . " w" . (MenuWidth - Padding * 2 - 70) . " h22 0x200 c" . UI_Colors.Text . " BackgroundTrans vBtnText" . Index, Option["text"])
            MainText.SetFont("s11 Bold", "Segoe UI")
            
            ; 鎻忚堪鏂囧瓧
            DescText := GuiID_ClipboardSmartMenu.Add("Text", "x" . (BtnX + 55) . " y" . (BtnY + 28) . " w" . (MenuWidth - Padding * 2 - 70) . " h18 0x200 c" . UI_Colors.TextDim . " BackgroundTrans vBtnDesc" . Index, Option["desc"])
            DescText.SetFont("s9", "Segoe UI")
            
            ; 涓烘寜閽儗鏅缃偓鍋滃睘鎬э紙璁￤M_MOUSEMOVE鑳藉鐞嗭級
            BtnBg.NormalColor := BtnNormalBg
            BtnBg.HoverColor := BtnHoverBg
            BtnBg.SelectedBg := BtnSelectedBg
            BtnBg.SelectedHoverBg := BtnSelectedHoverBg
            BtnBg.ButtonIndex := Index
            BtnBg.IsMenuButton := true  ; 鏍囪杩欐槸鑿滃崟鎸夐挳
            
            ; 淇濆瓨鎸夐挳寮曠敤
            ClipboardMenuButtons.Push({
                Bg: BtnBg,
                Icon: IconText,
                Text: MainText,
                Desc: DescText,
                Index: Index,
                Action: Option["action"],
                NormalBg: BtnNormalBg,
                HoverBg: BtnHoverBg,
                SelectedBg: BtnSelectedBg,
                SelectedHoverBg: BtnSelectedHoverBg
            })
            
            ; 娣诲姞鐐瑰嚮浜嬩欢
            ActionFunc := CreateMenuActionHandler(Option["action"])
            BtnBg.OnEvent("Click", ActionFunc)
            IconText.OnEvent("Click", ActionFunc)
            MainText.OnEvent("Click", ActionFunc)
            DescText.OnEvent("Click", ActionFunc)
            
            CurrentY += ButtonHeight + ButtonSpacing
        }
    }
    
    ; 鍏抽棴鎸夐挳
    CloseBtnY := CurrentY + 10
    CloseBtn := GuiID_ClipboardSmartMenu.Add("Text", "x" . (MenuWidth - 40) . " y" . (CloseBtnY - 5) . " w30 h30 Center 0x200 cFFFFFF Background" . BtnNormalBg . " vCloseBtn", "×")
    CloseBtn.SetFont("s12", "Segoe UI")
    CloseBtn.OnEvent("Click", (*) => CloseClipboardSmartMenu())
    HoverBtnWithAnimation(CloseBtn, BtnNormalBg, "e81123")
    
    ; 鏇存柊鑿滃崟楂樺害
    MenuHeight := CloseBtnY + 35
    
    ; 璁＄畻鑿滃崟浣嶇疆锛堝睆骞曞眳涓級
    ScreenInfo := GetScreenInfo(1)
    MenuX := (ScreenInfo.Width - MenuWidth) // 2
    MenuY := (ScreenInfo.Height - MenuHeight) // 2
    
    ; 鍒涘缓涓€涓殣钘忕殑杈撳叆妗嗙敤浜庢帴鏀堕敭鐩樼劍鐐癸紙鍦ㄦ樉绀哄墠鍒涘缓锛?
    DummyEdit := GuiID_ClipboardSmartMenu.Add("Edit", "x0 y0 w0 h0 vDummyFocus")
    
    ; 鏄剧ず鑿滃崟
    GuiID_ClipboardSmartMenu.Show("w" . MenuWidth . " h" . MenuHeight . " x" . MenuX . " y" . MenuY)
    
    ; 娣诲姞閿洏浜嬩欢
    GuiID_ClipboardSmartMenu.OnEvent("Escape", (*) => CloseClipboardSmartMenu())
    
    ; 浣跨敤绐楀彛娑堟伅澶勭悊閿洏浜嬩欢锛堟洿鍙潬锛?
    OnMessage(0x0100, HandleClipboardMenuKeyMessage)  ; WM_KEYDOWN
    
    ; 娉ㄥ唽鐑敭锛堜粎鍦ㄨ彍鍗曟樉绀烘椂鐢熸晥锛?
    RegisterClipboardMenuHotkeys()
    
    ; 鏇存柊鎸夐挳楂樹寒锛堝垵濮嬬姸鎬侊級
    UpdateClipboardMenuHighlight()
    
    ; 纭繚绐楀彛鑾峰緱鐒︾偣锛屼互渚挎帴鏀堕敭鐩樹簨浠?
    try {
        ; 绛夊緟绐楀彛瀹屽叏鏄剧ず
        Sleep(50)
        LegacyGuard_RequestFocus("ScreenshotWorkflow", GuiID_ClipboardSmartMenu.Hwnd, 28, "screenshot_menu_focus", 120)
        ; 鍐嶆绛夊緟纭繚婵€娲诲畬鎴?
        Sleep(50)
        ; 璁剧疆杈撳叆妗嗙劍鐐?
        DummyEdit.Focus()
        ; 纭繚绐楀彛鍦ㄥ墠鍙?
        WinSetAlwaysOnTop(true, "ahk_id " . GuiID_ClipboardSmartMenu.Hwnd)
    } catch as err {
        ; 蹇界暐閿欒
    }
}

; 澶勭悊鍓创鏉胯彍鍗曢敭鐩樻秷鎭?
HandleClipboardMenuKeyMessage(wParam, lParam, msg, hwnd) {
    global GuiID_ClipboardSmartMenu
    if (GuiID_ClipboardSmartMenu = 0 || hwnd != GuiID_ClipboardSmartMenu.Hwnd) {
        return
    }
    
    ; wParam 鏄櫄鎷熼敭鐮?
    KeyCode := wParam
    
    ; 涓婃柟鍚戦敭 (VK_UP = 0x26)
    if (KeyCode = 0x26) {
        HandleClipboardMenuUp()
        return 1  ; 闃绘榛樿琛屼负
    }
    
    ; 涓嬫柟鍚戦敭 (VK_DOWN = 0x28)
    if (KeyCode = 0x28) {
        HandleClipboardMenuDown()
        return 1  ; 闃绘榛樿琛屼负
    }
    
    ; 鍥炶溅閿?(VK_RETURN = 0x0D)
    if (KeyCode = 0x0D) {
        HandleClipboardMenuEnter()
        return 1  ; 闃绘榛樿琛屼负
    }
    
    return 0  ; 鍏佽榛樿琛屼负
}

; 鍒涘缓鑿滃崟鎿嶄綔澶勭悊鍑芥暟
CreateMenuActionHandler(Action) {
    return (*) => HandleClipboardMenuAction(Action)
}

; 澶勭悊鑿滃崟鎿嶄綔
HandleClipboardMenuAction(Action) {
    global GuiID_ClipboardSmartMenu
    
    ; 鍏抽棴鑿滃崟
    CloseClipboardSmartMenu()
    
    ; 鏍规嵁鎿嶄綔绫诲瀷鎵ц鐩稿簲鍔熻兘
    switch Action {
        case "ocr_preserve_layout":
            ProcessOCR("preserve_layout")
        case "ocr_auto_flow":
            ProcessOCR("auto_flow")
        case "paste_image":
            PasteImage()
        case "extract_preserve_layout":
            ExtractTextPreserveLayout()
        case "extract_auto_flow":
            ExtractTextAutoFlow()
        case "text_cleanup":
            CleanupText()
    }
}

; 鍏抽棴鏅鸿兘鑿滃崟
CloseClipboardSmartMenu() {
    global GuiID_ClipboardSmartMenu, ClipboardMenuHotkeysRegistered
    if (GuiID_ClipboardSmartMenu != 0) {
        try {
            ; 娉ㄩ攢鐑敭
            UnregisterClipboardMenuHotkeys()
            ; 绉婚櫎娑堟伅澶勭悊
            OnMessage(0x0100, HandleClipboardMenuKeyMessage, 0)  ; 绉婚櫎 WM_KEYDOWN 澶勭悊
            ; 娓呯悊鎵€鏈夋寜閽殑鎮仠鐘舵€侊紙涓嶉渶瑕佹竻鐞嗗畾鏃跺櫒锛屽洜涓轰娇鐢╓M_MOUSEMOVE锛?
            global LastHoverCtrl
            if (LastHoverCtrl && LastHoverCtrl.HasProp("IsMenuButton")) {
                try {
                    if (LastHoverCtrl.HasProp("ButtonIndex") && LastHoverCtrl.ButtonIndex = ClipboardMenuSelectedIndex) {
                        LastHoverCtrl.BackColor := LastHoverCtrl.SelectedBg
                    } else {
                        LastHoverCtrl.BackColor := LastHoverCtrl.NormalColor
                    }
                } catch as err {
                    ; 蹇界暐閿欒
                }
                LastHoverCtrl := 0
            }
            GuiID_ClipboardSmartMenu.Destroy()
        } catch as err {
            ; 蹇界暐閿欒
        }
        global GuiID_ClipboardSmartMenu := 0
        global ClipboardMenuButtons := []
        global ClipboardMenuSelectedIndex := 0
    }
}

; 娉ㄥ唽鍓创鏉胯彍鍗曠儹閿紙鍗犱綅鍑芥暟锛屽疄闄呬娇鐢ㄧ獥鍙ｆ秷鎭鐞嗭級
RegisterClipboardMenuHotkeys() {
    global ClipboardMenuHotkeysRegistered
    ClipboardMenuHotkeysRegistered := true
}

; 娉ㄩ攢鍓创鏉胯彍鍗曠儹閿紙鍗犱綅鍑芥暟锛?
UnregisterClipboardMenuHotkeys() {
    global ClipboardMenuHotkeysRegistered
    ClipboardMenuHotkeysRegistered := false
}

; 澶勭悊鍓创鏉胯彍鍗曚笂鏂瑰悜閿?
HandleClipboardMenuUp(*) {
    global ClipboardMenuSelectedIndex, ClipboardMenuButtons, GuiID_ClipboardSmartMenu
    if (GuiID_ClipboardSmartMenu = 0 || ClipboardMenuButtons.Length = 0) {
        return
    }
    
    ClipboardMenuSelectedIndex--
    if (ClipboardMenuSelectedIndex < 1) {
        ClipboardMenuSelectedIndex := ClipboardMenuButtons.Length
    }
    
    ; 鏇存柊楂樹寒锛堜細鍚屾椂妫€鏌ユ偓鍋滅姸鎬侊級
    UpdateClipboardMenuHighlight()
    
    ; 纭繚绐楀彛鑾峰緱鐒︾偣锛屼互渚跨户缁帴鏀堕敭鐩樹簨浠?
    try {
        LegacyGuard_RequestFocus("ScreenshotWorkflow", GuiID_ClipboardSmartMenu.Hwnd, 28, "screenshot_menu_focus", 120)
        ; 閲嶆柊璁剧疆鐒︾偣鍒伴殣钘忚緭鍏ユ
        try {
            DummyEdit := GuiID_ClipboardSmartMenu["DummyFocus"]
            if (DummyEdit) {
                DummyEdit.Focus()
            }
        } catch as err {
            ; 蹇界暐閿欒
        }
    } catch as err {
        ; 蹇界暐閿欒
    }
}

; 澶勭悊鍓创鏉胯彍鍗曚笅鏂瑰悜閿?
HandleClipboardMenuDown(*) {
    global ClipboardMenuSelectedIndex, ClipboardMenuButtons, GuiID_ClipboardSmartMenu
    if (GuiID_ClipboardSmartMenu = 0 || ClipboardMenuButtons.Length = 0) {
        return
    }
    
    ClipboardMenuSelectedIndex++
    if (ClipboardMenuSelectedIndex > ClipboardMenuButtons.Length) {
        ClipboardMenuSelectedIndex := 1
    }
    
    ; 鏇存柊楂樹寒锛堜細鍚屾椂妫€鏌ユ偓鍋滅姸鎬侊級
    UpdateClipboardMenuHighlight()
    
    ; 纭繚绐楀彛鑾峰緱鐒︾偣锛屼互渚跨户缁帴鏀堕敭鐩樹簨浠?
    try {
        LegacyGuard_RequestFocus("ScreenshotWorkflow", GuiID_ClipboardSmartMenu.Hwnd, 28, "screenshot_menu_focus", 120)
        ; 閲嶆柊璁剧疆鐒︾偣鍒伴殣钘忚緭鍏ユ
        try {
            DummyEdit := GuiID_ClipboardSmartMenu["DummyFocus"]
            if (DummyEdit) {
                DummyEdit.Focus()
            }
        } catch as err {
            ; 蹇界暐閿欒
        }
    } catch as err {
        ; 蹇界暐閿欒
    }
}

; 澶勭悊鍓创鏉胯彍鍗曞洖杞﹂敭
HandleClipboardMenuEnter(*) {
    global ClipboardMenuSelectedIndex, ClipboardMenuButtons, GuiID_ClipboardSmartMenu
    if (GuiID_ClipboardSmartMenu = 0 || ClipboardMenuButtons.Length = 0 || ClipboardMenuSelectedIndex < 1 || ClipboardMenuSelectedIndex > ClipboardMenuButtons.Length) {
        return
    }
    
    Button := ClipboardMenuButtons[ClipboardMenuSelectedIndex]
    HandleClipboardMenuAction(Button.Action)
}

; 鏇存柊鍓创鏉胯彍鍗曢珮浜紙鎵€鏈夋寜閽兘鏈夋偓鍋滃厜鏁堬級
UpdateClipboardMenuHighlight() {
    global ClipboardMenuButtons, ClipboardMenuSelectedIndex, GuiID_ClipboardSmartMenu, LastHoverCtrl
    
    if (GuiID_ClipboardSmartMenu = 0 || ClipboardMenuButtons.Length = 0) {
        return
    }
    
    ; 鏇存柊鎵€鏈夋寜閽殑鑳屾櫙鑹诧紙鑰冭檻閫変腑鐘舵€佸拰鎮仠鐘舵€侊級
    ; 鎮仠鐘舵€佺敱WM_MOUSEMOVE澶勭悊锛岃繖閲屽彧澶勭悊閫変腑鐘舵€?
    for Index, Button in ClipboardMenuButtons {
        try {
            ; 妫€鏌ユ寜閽槸鍚﹁榧犳爣鎮仠锛堥€氳繃LastHoverCtrl鍒ゆ柇锛?
            IsHovering := (LastHoverCtrl = Button.Bg)
            
            ; 鏍规嵁閫変腑鍜屾偓鍋滅姸鎬佽缃儗鏅壊
            if (Index = ClipboardMenuSelectedIndex) {
                ; 宸查€変腑鐘舵€?
                if (IsHovering) {
                    ; 閫変腑+鎮仠 = 鏈€浜厜鏁?
                    Button.Bg.BackColor := Button.SelectedHoverBg
                } else {
                    ; 閫変腑浣嗘湭鎮仠锛氫娇鐢ㄩ€変腑鑳屾櫙鑹?
                    Button.Bg.BackColor := Button.SelectedBg
                }
            } else {
                ; 鏈€変腑鐘舵€?
                if (IsHovering) {
                    ; 鎮仠鏃舵湁鍏夋晥
                    Button.Bg.BackColor := Button.HoverBg
                } else {
                    ; 鏈偓鍋滐細浣跨敤姝ｅ父鑳屾櫙鑹?
                    Button.Bg.BackColor := Button.NormalBg
                }
            }
        } catch as err {
            ; 蹇界暐閿欒
        }
    }
}

; 璁剧疆鎸夐挳鎮仠鏁堟灉
SetupButtonHover(BtnBg, IconText, MainText, DescText, NormalBg, HoverBg, SelectedBg, SelectedHoverBg, Index) {
    global ClipboardMenuButtons, ClipboardMenuSelectedIndex, GuiID_ClipboardSmartMenu
    
    ; 鍒涘缓鎮仠妫€娴嬪嚱鏁?
    HoverCheckFunc(*) {
        CheckButtonHover(Index, BtnBg, NormalBg, HoverBg, SelectedBg, SelectedHoverBg)
    }
    
    ; 浣跨敤瀹氭椂鍣ㄦ娴嬮紶鏍囦綅缃紙姣?0ms妫€鏌ヤ竴娆★紝鏇存祦鐣咃級
    SetTimer(HoverCheckFunc, 30)
    
    ; 淇濆瓨瀹氭椂鍣ㄥ紩鐢ㄤ互渚挎竻鐞?
    try {
        BtnBg.HoverTimer := HoverCheckFunc
    } catch as err {
        ; 蹇界暐閿欒
    }
}

; 妫€鏌ユ寜閽偓鍋滅姸鎬侊紙鎵€鏈夋寜閽兘鏈夋偓鍋滃厜鏁堬級
CheckButtonHover(Index, BtnBg, NormalBg, HoverBg, SelectedBg, SelectedHoverBg) {
    global ClipboardMenuSelectedIndex, GuiID_ClipboardSmartMenu
    
    if (GuiID_ClipboardSmartMenu = 0) {
        return
    }
    
    try {
        ; 鑾峰彇鎸夐挳浣嶇疆鍜屽ぇ灏?
        WinGetPos(&WinX, &WinY, , , "ahk_id " . GuiID_ClipboardSmartMenu.Hwnd)
        ControlGetPos(&CtrlX, &CtrlY, &CtrlW, &CtrlH, , "ahk_id " . BtnBg.Hwnd)
        
        ; 鑾峰彇榧犳爣浣嶇疆
        MouseGetPos(&MouseX, &MouseY)
        
        ; 璁＄畻鎸夐挳鍦ㄥ睆骞曚笂鐨勭粷瀵逛綅缃?
        BtnLeft := WinX + CtrlX
        BtnRight := BtnLeft + CtrlW
        BtnTop := WinY + CtrlY
        BtnBottom := BtnTop + CtrlH
        
        ; 妫€鏌ラ紶鏍囨槸鍚﹀湪鎸夐挳涓?
        IsHovering := (MouseX >= BtnLeft && MouseX <= BtnRight && MouseY >= BtnTop && MouseY <= BtnBottom)
        
        ; 鎵€鏈夋寜閽兘鏈夋偓鍋滃厜鏁?
        if (Index = ClipboardMenuSelectedIndex) {
            ; 宸查€変腑鐘舵€侊細鏍规嵁鏄惁鎮仠鏉ュ喅瀹氳儗鏅壊
            if (IsHovering) {
                ; 閫変腑+鎮仠 = 鏈€浜厜鏁?
                BtnBg.BackColor := SelectedHoverBg
            } else {
                ; 閫変腑浣嗘湭鎮仠锛氫娇鐢ㄩ€変腑鑳屾櫙鑹?
                BtnBg.BackColor := SelectedBg
            }
        } else {
            ; 鏈€変腑鐘舵€?
            if (IsHovering) {
                ; 鎮仠鏃舵湁鍏夋晥
                BtnBg.BackColor := HoverBg
            } else {
                ; 鏈偓鍋滐細浣跨敤姝ｅ父鑳屾櫙鑹?
                BtnBg.BackColor := NormalBg
            }
        }
    } catch as err {
        ; 蹇界暐閿欒
    }
}

; 鑾峰彇鍓创鏉跨被鍨?
GetClipboardType() {
    try {
        ; 妫€鏌ユ槸鍚﹀寘鍚浘鐗?
        if (DllCall("OpenClipboard", "Ptr", 0)) {
            ; 妫€鏌ヤ綅鍥炬牸寮?
            if (DllCall("IsClipboardFormatAvailable", "UInt", 2)) {  ; CF_BITMAP
                DllCall("CloseClipboard")
                return "image"
            }
            ; 妫€鏌?DIB / DIBV5 鏍煎紡
            if (DllCall("IsClipboardFormatAvailable", "UInt", 8)) {  ; CF_DIB
                DllCall("CloseClipboard")
                return "image"
            }
            if (DllCall("IsClipboardFormatAvailable", "UInt", 17)) {  ; CF_DIBV5
                DllCall("CloseClipboard")
                return "image"
            }
            ; 妫€鏌?PNG 鏍煎紡
            PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
            if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                DllCall("CloseClipboard")
                return "image"
            }
            DllCall("CloseClipboard")
        }
        
        ; 妫€鏌ユ枃鏈?
        try {
            ClipboardText := A_Clipboard
            if (ClipboardText != "" && StrLen(ClipboardText) > 0) {
                return "text"
            }
        } catch as err {
            ; 蹇界暐閿欒
        }
        
        return "empty"
    } catch as err {
        return "empty"
    }
}

; ===================== OCR 璇嗗浘鍙栬瘝鍔熻兘锛堜娇鐢?ImagePut 浼樺寲锛?=====================
IsClipboardImagePayload() {
    try {
        if (GetClipboardType() = "image")
            return true
    } catch {
    }
    try {
        files := GetClipboardFileDropList()
        if (files != "") {
            for _, fp in StrSplit(files, "`n") {
                if (fp = "")
                    continue
                ext := StrLower(RegExReplace(String(fp), "^.*\."))
                if (ext = "png" || ext = "jpg" || ext = "jpeg" || ext = "bmp" || ext = "gif" || ext = "webp")
                    return true
            }
        }
    } catch {
    }
    try {
        t := Trim(String(A_Clipboard))
        if (t != "" && FileExist(t)) {
            ext2 := StrLower(RegExReplace(t, "^.*\."))
            if (ext2 = "png" || ext2 = "jpg" || ext2 = "jpeg" || ext2 = "bmp" || ext2 = "gif" || ext2 = "webp")
                return true
        }
    } catch {
    }
    return false
}

ScreenshotFindLatestSavedImage(maxAgeSeconds := 240) {
    bestPath := ""
    bestTs := ""
    picsRoot := EnvGet("USERPROFILE") "\Pictures"
    dirs := [
        picsRoot "\Screenshots",
        picsRoot "\Saved Pictures",
        picsRoot "\Saved Pictures\Screenshots",
        picsRoot "\Gallery"
    ]
    for _, dir in dirs {
        if !DirExist(dir)
            continue
        Loop Files, dir "\*.*", "F" {
            ext := StrLower(RegExReplace(A_LoopFileName, "^.*\."))
            if (ext != "png" && ext != "jpg" && ext != "jpeg" && ext != "bmp" && ext != "gif" && ext != "webp")
                continue
            ts := ""
            try ts := FileGetTime(A_LoopFilePath, "M")
            catch
                continue
            if (ts = "")
                continue
            age := 999999
            try age := DateDiff(A_Now, ts, "Seconds")
            catch
                age := 999999
            if (age < 0 || age > maxAgeSeconds)
                continue
            if (bestTs = "" || ts > bestTs) {
                bestTs := ts
                bestPath := A_LoopFilePath
            }
        }
    }
    return bestPath
}

ScreenshotCapturePayload(&outClip, &outFilePath, waitMs := 3200) {
    outClip := ""
    outFilePath := ""
    elapsed := 0
    step := 120
    while (elapsed <= waitMs) {
        try {
            if (IsClipboardImagePayload()) {
                c := ClipboardAll()
                if (c) {
                    outClip := c
                    return true
                }
            }
        } catch {
        }
        try {
            fp := ScreenshotFindLatestSavedImage(240)
            if (fp != "") {
                outFilePath := fp
                return true
            }
        } catch {
        }
        Sleep(step)
        elapsed += step
    }
    return false
}

OCR_FromFileBestEffort(filePath, lang := "zh-CN") {
    cfg := OCR_ReadEnhanceConfig()
    bestResult := ""
    bestScore := -1
    strategies := OCR_BuildStrategies(cfg)
    for _, strategy in strategies {
        try {
            options := {lang: lang}
            for k, v in strategy.OwnProps()
                options.%k% := v
            result := OCR.FromFile(filePath, options)
            score := OCR_ScoreResult(result)
            if (score > bestScore) {
                bestScore := score
                bestResult := result
            }
        } catch {
        }
    }
    return bestResult
}

OCR_ReadEnhanceConfig() {
    cfgFile := A_ScriptDir "\CursorShortcut.ini"
    cfg := Map()
    cfg["enabled"] := IniRead(cfgFile, "Screenshot", "OcrEnhanceEnabled", "1") != "0"
    cfg["scalePrimary"] := Integer(IniRead(cfgFile, "Screenshot", "OcrScalePrimary", "150"))
    cfg["scaleSecondary"] := Integer(IniRead(cfgFile, "Screenshot", "OcrScaleSecondary", "200"))
    cfg["useGrayscale"] := IniRead(cfgFile, "Screenshot", "OcrUseGrayscale", "1") != "0"
    cfg["monoLow"] := Integer(IniRead(cfgFile, "Screenshot", "OcrMonochromeLow", "160"))
    cfg["monoHigh"] := Integer(IniRead(cfgFile, "Screenshot", "OcrMonochromeHigh", "175"))
    cfg["useInvert"] := IniRead(cfgFile, "Screenshot", "OcrUseInvert", "1") != "0"
    if (cfg["scalePrimary"] < 100)
        cfg["scalePrimary"] := 100
    if (cfg["scalePrimary"] > 300)
        cfg["scalePrimary"] := 300
    if (cfg["scaleSecondary"] < 100)
        cfg["scaleSecondary"] := 100
    if (cfg["scaleSecondary"] > 300)
        cfg["scaleSecondary"] := 300
    if (cfg["monoLow"] < 0)
        cfg["monoLow"] := 0
    if (cfg["monoLow"] > 255)
        cfg["monoLow"] := 255
    if (cfg["monoHigh"] < cfg["monoLow"])
        cfg["monoHigh"] := cfg["monoLow"]
    if (cfg["monoHigh"] > 255)
        cfg["monoHigh"] := 255
    return cfg
}

OCR_BuildStrategies(cfg) {
    if !(cfg is Map) || !cfg.Get("enabled", true)
        return [{scale: 1.0}]

    p := cfg["scalePrimary"] / 100.0
    s := cfg["scaleSecondary"] / 100.0
    useGray := cfg["useGrayscale"]
    low := cfg["monoLow"]
    high := cfg["monoHigh"]
    useInvert := cfg["useInvert"]

    strategies := [{scale: 1.0}, {scale: p}, {scale: s}]
    if (useGray) {
        strategies.Push({scale: p, grayscale: 1})
        strategies.Push({scale: p, grayscale: 1, monochrome: low})
        strategies.Push({scale: p, grayscale: 1, monochrome: high})
        strategies.Push({scale: s, grayscale: 1})
        strategies.Push({scale: s, grayscale: 1, monochrome: low})
        strategies.Push({scale: s, grayscale: 1, monochrome: high})
        if (useInvert)
            strategies.Push({scale: p, grayscale: 1, monochrome: low, invertcolors: 1})
        if (useInvert)
            strategies.Push({scale: s, grayscale: 1, monochrome: low, invertcolors: 1})
    } else if (useInvert) {
        strategies.Push({scale: p, invertcolors: 1})
        strategies.Push({scale: s, invertcolors: 1})
    }
    return strategies
}

OCR_ScoreResult(result) {
    try {
        if (!result || !result.HasProp("Text"))
            return -1
        text := Trim(String(result.Text), " `t`r`n")
        if (text = "")
            return 0
        dense := RegExReplace(text, "\s", "")
        return StrLen(dense)
    } catch {
        return -1
    }
}

ProcessOCR(Mode := "preserve_layout") {
    global UI_Colors, ScreenshotClipboard
    
    ; 鏄剧ず澶勭悊涓彁绀?
    TrayTip("鈿欙笍 OCR 澶勭悊涓?..", "", "Iconi 1")
    
    try {
        ; 淇濆瓨褰撳墠鍓创鏉?
        OldClipboard := ClipboardAll()
        
        ; 濡傛灉鏈変繚瀛樼殑鎴浘鏁版嵁锛屼紭鍏堜娇鐢?
        if (ScreenshotClipboard) {
            A_Clipboard := ScreenshotClipboard
            Sleep(200)
        }
        
        ; 浣跨敤 ImagePutBitmap 鐩存帴浠庡壀璐存澘鑾峰彇浣嶅浘锛堣嚜鍔ㄥ鐞嗘墍鏈夋牸寮忥細CF_BITMAP, CF_DIB, PNG绛夛級
        ; ImagePut 浼氳嚜鍔ㄦ娴嬪苟杞崲鍓创鏉夸腑鐨勪换浣曞浘鐗囨牸寮忥紝鏃犻渶鎵嬪姩鍒ゆ柇
        pBitmap := ImagePutBitmap(A_Clipboard)
        
        if (!pBitmap || pBitmap = "") {
            TrayTip("鍓创鏉夸腑娌℃湁鍙瘑鍒殑鍥剧墖鏍煎紡", "閿欒", "Iconx 2")
            A_Clipboard := OldClipboard
            return
        }
        
        ; 灏?GDI+ Bitmap 杞崲涓?RandomAccessStream锛圤CR 闇€瑕侊級
        ; 鍏堜繚瀛樹负涓存椂鏂囦欢锛岀劧鍚庝娇鐢?OCR.FromFile 璇嗗埆锛堟€ц兘鏇村ソ锛屾敮鎸佹洿澶氭牸寮忥級
        TempFile := A_Temp "\ocr_temp_" . A_TickCount . ".png"
        OCRResult := ""
        
        try {
            ; 浣跨敤 ImagePut 淇濆瓨涓?PNG锛堥珮璐ㄩ噺锛屾敮鎸侀€忔槑閫氶亾锛?
            ImagePut("File", pBitmap, TempFile)
            
            ; 娓呯悊 Bitmap 璧勬簮
            ImageDestroy(pBitmap)
            pBitmap := ""
            
            ; 浣跨敤 OCR.FromFile 璇嗗埆锛堟敮鎸佹洿澶氭牸寮忥紝鎬ц兘鏇村ソ锛?
            OCRResult := OCR_FromFileBestEffort(TempFile, "zh-CN")
            
            ; 鍒犻櫎涓存椂鏂囦欢
            try {
                FileDelete(TempFile)
            } catch {
                ; 蹇界暐鍒犻櫎閿欒
            }
            
        } catch as e {
            ; 娓呯悊璧勬簮
            try {
                if (FileExist(TempFile)) {
                    FileDelete(TempFile)
                }
            } catch {
                ; 蹇界暐娓呯悊閿欒
            }
            
            ; 濡傛灉鏂囦欢鏂瑰紡澶辫触锛屽皾璇曠洿鎺ヤ娇鐢?RandomAccessStream锛堝鐢ㄦ柟妗堬級
            try {
                ; 閲嶆柊浠庡壀璐存澘璇诲彇锛堝鏋滀箣鍓嶅凡娓呯悊锛?
                if (!pBitmap) {
                    pBitmap := ImagePutBitmap(A_Clipboard)
                }
                
                if (pBitmap) {
                    ; 灏?Bitmap 杞崲涓?RandomAccessStream
                    ras := ImagePut("RandomAccessStream", pBitmap, "png")
                    OCRResult := OCR(ras)
                    ImageDestroy(pBitmap)
                    pBitmap := ""
                } else {
                    throw Error("无法读取剪贴板图片")
                }
            } catch as err {
                TrayTip("OCR 识别失败: " . err.Message, "错误", "Iconx 2")
                A_Clipboard := OldClipboard
                return
            }
        }
        
        if (!OCRResult || !OCRResult.Text || StrLen(OCRResult.Text) = 0) {
            TrayTip("OCR 璇嗗埆澶辫触锛氭湭妫€娴嬪埌鏂囧瓧", "閿欒", "Iconx 2")
            A_Clipboard := OldClipboard
            return
        }
        
        ; 鎻愬彇鍘熷鏂囨湰
        ExtractedText := OCRResult.Text
        
        ; 鏍规嵁妯″紡澶勭悊鏂囨湰
        if (Mode = "auto_flow") {
            ; 鑷姩娴佽浆妯″紡锛氬悎骞舵柇琛岋紝鍘婚櫎涓枃闂寸┖鏍硷紝鍘婚櫎 HTML 鏍囩
            ExtractedText := ProcessOCRTextAutoFlow(ExtractedText)
        } else {
            ; 淇濈暀甯冨眬妯″紡锛氫粎杩涜鍩虹娓呯悊锛堜贡鐮佷慨澶嶃€佸幓 HTML 鏍囩锛?
            ExtractedText := ProcessOCRTextPreserveLayout(ExtractedText)
        }
        
        ; 灏嗗鐞嗗悗鐨勬枃鏈斁鍏ュ壀璐存澘
        A_Clipboard := ExtractedText
        Sleep(200)
        
        ; 娓呴櫎鎴浘鏁版嵁锛堝凡澶勭悊瀹屾垚锛?
        global ScreenshotClipboard
        ScreenshotClipboard := ""
        
        ; 鏄剧ず鎴愬姛鎻愮ず
        TrayTip("OCR 完成", "已识别 " . StrLen(ExtractedText) . " 个字符", "Iconi 1")
        
        ; 鑷姩绮樿创
        Sleep(300)
        Send("^v")
        
    } catch as e {
        TrayTip("OCR 识别失败: " . e.Message, "错误", "Iconx 2")
        try {
            A_Clipboard := OldClipboard
        } catch as err {
            ; 蹇界暐閿欒
        }
    }
}

; ===================== OCR 鏂囨湰澶勭悊锛堜繚鐣欏竷灞€锛?=====================
ProcessOCRTextPreserveLayout(Text) {
    ; 1. 涔辩爜淇锛堝父瑙?OCR 閿欒瀛楃鏇挎崲锛?
    Text := FixOCREncodingErrors(Text)
    
    ; 2. 鍘婚櫎 HTML 鏍囩
    Text := RemoveHTMLTags(Text)
    
    ; 3. 鍘婚櫎澶氫綑鐨勭┖鏍硷紙浣嗕繚鐣欐崲琛屽拰鍩烘湰甯冨眬锛?
    ; 鍘婚櫎琛岄琛屽熬绌烘牸
    Lines := StrSplit(Text, "`n")
    ProcessedLines := []
    for Index, Line in Lines {
        ProcessedLine := Trim(Line, " `t`r")
        ProcessedLines.Push(ProcessedLine)
    }
    Text := ""
    for Index, Line in ProcessedLines {
        if (Index > 1) {
            Text .= "`n"
        }
        Text .= Line
    }
    
    ; 4. 娓呯悊閲嶅鐨勬崲琛岋紙瓒呰繃 2 涓繛缁崲琛屽悎骞朵负 2 涓級
    while (InStr(Text, "`n`n`n")) {
        Text := StrReplace(Text, "`n`n`n", "`n`n")
    }
    
    return Text
}

; ===================== OCR 鏂囨湰澶勭悊锛堣嚜鍔ㄦ祦杞級 =====================
ProcessOCRTextAutoFlow(Text) {
    ; 1. 涔辩爜淇
    Text := FixOCREncodingErrors(Text)
    
    ; 2. 鍘婚櫎 HTML 鏍囩
    Text := RemoveHTMLTags(Text)
    
    ; 3. 鍚堝苟鎵€鏈夋崲琛岀涓虹┖鏍硷紙浣嗕繚鐣欐钀藉垎闅旓級
    Text := StrReplace(Text, "`r`n", " ")
    Text := StrReplace(Text, "`n", " ")
    Text := StrReplace(Text, "`r", " ")
    
    ; 4. 鍘婚櫎涓枃闂寸殑鏃犳剰涔夌┖鏍?
    Text := RemoveSpacesBetweenChinese(Text)
    
    ; 5. 娓呯悊澶氫綑绌烘牸锛堝涓繛缁┖鏍煎悎骞朵负涓€涓級
    while (InStr(Text, "  ")) {
        Text := StrReplace(Text, "  ", " ")
    }
    
    ; 6. 鍘婚櫎棣栧熬绌烘牸
    Text := Trim(Text)
    
    return Text
}

; ===================== OCR 涔辩爜淇 =====================
FixOCREncodingErrors(Text) {
    ; 甯歌 OCR 璇嗗埆閿欒瀛楃鏄犲皠琛?
    ; 鏍煎紡锛氶敊璇瓧绗?=> 姝ｇ‘瀛楃
    ErrorMap := Map(
        "，", ",", "。", ".", "：", ":", "；", ";",
        "？", "?", "！", "!", "（", "(", "）", ")",
        "【", "[", "】", "]", "“", Chr(34), "”", Chr(34)
    )
    
    ; 鏇挎崲閿欒瀛楃
    Result := Text
    for WrongChar, CorrectChar in ErrorMap {
        Result := StrReplace(Result, WrongChar, CorrectChar)
    }
    
    ; 淇甯歌鐨?OCR 璇嗗埆閿欒
    ; 淇 "l" 鍜?"1" 鐨勬贩娣嗭紙鍦ㄧ壒瀹氫笂涓嬫枃涓級
    ; 淇 "O" 鍜?"0" 鐨勬贩娣嗭紙鍦ㄧ壒瀹氫笂涓嬫枃涓級
    ; 杩欓噷鍙互鏍规嵁闇€瑕佹坊鍔犳洿澶氳鍒?
    
    ; 淇甯歌鐨勮嫳鏂囪瘑鍒敊璇?
    CommonErrors := Map(
        "rn", "m",  ; rn 甯歌璇嗗埆涓?m
        "vv", "w",  ; vv 甯歌璇嗗埆涓?w
        "cl", "d",  ; cl 甯歌璇嗗埆涓?d
        "ii", "n"   ; ii 甯歌璇嗗埆涓?n
    )
    
    ; 娉ㄦ剰锛氳繖浜涙浛鎹㈤渶瑕佽皑鎱庯紝鍙湪鐗瑰畾涓婁笅鏂囦腑鎵嶉€傜敤
    ; 杩欓噷绠€鍖栧鐞嗭紝涓嶈繘琛岃嚜鍔ㄦ浛鎹紝閬垮厤璇浛鎹?
    
    return Result
}

; ===================== 绮樿创鍥剧墖鍔熻兘 =====================
PasteImage() {
    global ScreenshotClipboard
    
    try {
        ; 濡傛灉鏈変繚瀛樼殑鎴浘鏁版嵁锛屼紭鍏堜娇鐢?
        if (ScreenshotClipboard) {
            A_Clipboard := ScreenshotClipboard
            Sleep(200)
        }
        
        ; 妫€鏌ュ壀璐存澘鏄惁鏈夊浘鐗?
        if (!DllCall("OpenClipboard", "Ptr", 0)) {
            TrayTip("鍓创鏉夸腑娌℃湁鍥剧墖", "閿欒", "Iconx 2")
            return
        }
        
        HasImage := false
        if (DllCall("IsClipboardFormatAvailable", "UInt", 2)
            || DllCall("IsClipboardFormatAvailable", "UInt", 8)
            || DllCall("IsClipboardFormatAvailable", "UInt", 17)) {
            HasImage := true
        } else {
            PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
            if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                HasImage := true
            }
        }
        DllCall("CloseClipboard")
        
        if (!HasImage) {
            TrayTip("鍓创鏉夸腑娌℃湁鍥剧墖", "閿欒", "Iconx 2")
            return
        }
        
        ; 娓呴櫎鎴浘鏁版嵁锛堝凡澶勭悊瀹屾垚锛?
        global ScreenshotClipboard
        ScreenshotClipboard := ""
        
        ; 鐩存帴绮樿创鍥剧墖
        Send("^v")
        Sleep(200)
        
        ; 鏄剧ず鎴愬姛鎻愮ず锛堢畝鍖栵級
        TrayTip("图片已粘贴", "", "Iconi 1")
        
    } catch as e {
        TrayTip("粘贴图片失败: " . e.Message, "错误", "Iconx 2")
    }
}

; ===================== 鎻愬彇鏂囨湰锛堜繚鐣欏竷灞€锛?=====================
ExtractTextPreserveLayout() {
    try {
        ; 鏄剧ず澶勭悊涓彁绀猴紙绠€鍖栵級
        TrayTip("鈿欙笍 澶勭悊涓?..", "", "Iconi 1")
        
        ; 鑾峰彇鍓创鏉挎枃鏈?
        ClipboardText := A_Clipboard
        
        if (ClipboardText = "" || StrLen(ClipboardText) = 0) {
            TrayTip("鍓创鏉夸腑娌℃湁鏂囨湰", "閿欒", "Iconx 2")
            return
        }
        
        ; 淇濈暀鍘熷甯冨眬锛屼粎杩涜鍩虹娓呯悊
        ProcessedText := ClipboardText
        
        ; 1. 鍘婚櫎 HTML 鏍囩
        ProcessedText := RemoveHTMLTags(ProcessedText)
        
        ; 2. 鍘婚櫎琛岄琛屽熬绌烘牸锛堜繚鐣欐崲琛岋級
        Lines := StrSplit(ProcessedText, "`n")
        ProcessedLines := []
        for Index, Line in Lines {
            ProcessedLine := Trim(Line, " `t`r")
            ProcessedLines.Push(ProcessedLine)
        }
        ProcessedText := ""
        for Index, Line in ProcessedLines {
            if (Index > 1) {
                ProcessedText .= "`n"
            }
            ProcessedText .= Line
        }
        
        ; 3. 娓呯悊閲嶅鐨勬崲琛岋紙瓒呰繃 2 涓繛缁崲琛屽悎骞朵负 2 涓級
        while (InStr(ProcessedText, "`n`n`n")) {
            ProcessedText := StrReplace(ProcessedText, "`n`n`n", "`n`n")
        }
        
        ; 鍥炲～鍓创鏉?
        A_Clipboard := ProcessedText
        Sleep(200)
        
        ; 鏄剧ず鎴愬姛鎻愮ず锛堢畝鍖栵級
        TrayTip("文本已处理", "", "Iconi 1")
        
        ; 鑷姩绮樿创
        Sleep(300)
        Send("^v")
        
    } catch as e {
        TrayTip("文本提取失败: " . e.Message, "错误", "Iconx 2")
    }
}

; ===================== 鎻愬彇鏂囨湰锛堣嚜鍔ㄦ祦杞級 =====================
ExtractTextAutoFlow() {
    try {
        ; 鏄剧ず澶勭悊涓彁绀猴紙绠€鍖栵級
        TrayTip("鈿欙笍 澶勭悊涓?..", "", "Iconi 1")
        
        ; 鑾峰彇鍓创鏉挎枃鏈?
        ClipboardText := A_Clipboard
        
        if (ClipboardText = "" || StrLen(ClipboardText) = 0) {
            TrayTip("鍓创鏉夸腑娌℃湁鏂囨湰", "閿欒", "Iconx 2")
            return
        }
        
        ; 澶勭悊鏂囨湰锛氬悎骞舵柇琛岋紝鍘婚櫎涓枃闂寸┖鏍?
        ProcessedText := ClipboardText
        
        ; 1. 鍘婚櫎 HTML 鏍囩
        ProcessedText := RemoveHTMLTags(ProcessedText)
        
        ; 2. 鍚堝苟鎵€鏈夋崲琛岀涓虹┖鏍硷紙浣嗕繚鐣欐钀藉垎闅旓級
        ProcessedText := StrReplace(ProcessedText, "`r`n", " ")
        ProcessedText := StrReplace(ProcessedText, "`n", " ")
        ProcessedText := StrReplace(ProcessedText, "`r", " ")
        
        ; 3. 鍘婚櫎涓枃闂寸殑鏃犳剰涔夌┖鏍硷紙涓枃瀛楃涔嬮棿鐨勭┖鏍硷級
        ProcessedText := RemoveSpacesBetweenChinese(ProcessedText)
        
        ; 4. 娓呯悊澶氫綑绌烘牸锛堝涓繛缁┖鏍煎悎骞朵负涓€涓級
        while (InStr(ProcessedText, "  ")) {
            ProcessedText := StrReplace(ProcessedText, "  ", " ")
        }
        
        ; 5. 鍘婚櫎棣栧熬绌烘牸
        ProcessedText := Trim(ProcessedText)
        
        ; 鍥炲～鍓创鏉?
        A_Clipboard := ProcessedText
        Sleep(200)
        
        ; 鏄剧ず鎴愬姛鎻愮ず锛堢畝鍖栵級
        TrayTip("文本已处理", "", "Iconi 1")
        
        ; 鑷姩绮樿创
        Sleep(300)
        Send("^v")
        
    } catch as e {
        TrayTip("文本流转失败: " . e.Message, "错误", "Iconx 2")
    }
}

; 鍘婚櫎涓枃瀛楃涔嬮棿鐨勭┖鏍?
RemoveSpacesBetweenChinese(Text) {
    ; 绠€鍗曠殑瀹炵幇锛氶亶鍘嗘枃鏈紝濡傛灉閬囧埌涓枃瀛楃-绌烘牸-涓枃瀛楃鐨勬ā寮忥紝鍒犻櫎绌烘牸
    Result := ""
    TextLen := StrLen(Text)
    
    Loop TextLen {
        CurrentChar := SubStr(Text, A_Index, 1)
        NextChar := (A_Index < TextLen) ? SubStr(Text, A_Index + 1, 1) : ""
        PrevChar := (A_Index > 1) ? SubStr(Text, A_Index - 1, 1) : ""
        
        ; 妫€鏌ユ槸鍚︽槸涓枃瀛楃锛圲nicode 鑼冨洿锛歕u4e00-\u9fff锛?
        IsChinese := (Ord(CurrentChar) >= 0x4E00 && Ord(CurrentChar) <= 0x9FFF)
        IsPrevChinese := (PrevChar != "" && Ord(PrevChar) >= 0x4E00 && Ord(PrevChar) <= 0x9FFF)
        IsNextChinese := (NextChar != "" && Ord(NextChar) >= 0x4E00 && Ord(NextChar) <= 0x9FFF)
        
        ; 濡傛灉鏄┖鏍硷紝涓斿墠鍚庨兘鏄腑鏂囷紝鍒欒烦杩囷紙涓嶆坊鍔犲埌缁撴灉锛?
        if (CurrentChar = " " && IsPrevChinese && IsNextChinese) {
            continue
        }
        
        Result .= CurrentChar
    }
    
    return Result
}

; ===================== 鏂囨湰鍑€鍖栧姛鑳?=====================
CleanupText() {
    try {
        ; 鏄剧ず澶勭悊涓彁绀猴紙绠€鍖栵級
        TrayTip("鈿欙笍 澶勭悊涓?..", "", "Iconi 1")
        
        ; 鑾峰彇鍓创鏉挎枃鏈?
        ClipboardText := A_Clipboard
        
        if (ClipboardText = "" || StrLen(ClipboardText) = 0) {
            TrayTip("鍓创鏉夸腑娌℃湁鏂囨湰", "閿欒", "Iconx 2")
            return
        }
        
        ; 鏂囨湰鍑€鍖栧鐞?
        ProcessedText := ClipboardText
        
        ; 1. 鍘婚櫎 HTML 鏍囩
        ProcessedText := RemoveHTMLTags(ProcessedText)
        
        ; 2. 鍘婚櫎閾炬帴锛坔ttp:// 鎴?https:// 寮€澶寸殑 URL锛?
        ProcessedText := RemoveURLs(ProcessedText)
        
        ; 3. 鍘婚櫎閲嶅绌烘牸
        while (InStr(ProcessedText, "  ")) {
            ProcessedText := StrReplace(ProcessedText, "  ", " ")
        }
        
        ; 4. 缁熶竴鏍囩偣鏍煎紡锛堝皢涓枃鏍囩偣鍚庣殑绌烘牸鍘婚櫎锛岃嫳鏂囨爣鐐瑰悗娣诲姞绌烘牸锛?
        ProcessedText := NormalizePunctuation(ProcessedText)
        
        ; 5. 鍘婚櫎涓枃闂寸殑鏃犳剰涔夌┖鏍?
        ProcessedText := RemoveSpacesBetweenChinese(ProcessedText)
        
        ; 6. 鍘婚櫎棣栧熬绌烘牸鍜屾崲琛?
        ProcessedText := Trim(ProcessedText, " `t`r`n")
        
        ; 7. 娓呯悊閲嶅鐨勬崲琛岋紙瓒呰繃 2 涓繛缁崲琛屽悎骞朵负 2 涓級
        while (InStr(ProcessedText, "`n`n`n")) {
            ProcessedText := StrReplace(ProcessedText, "`n`n`n", "`n`n")
        }
        
        ; 鍥炲～鍓创鏉?
        A_Clipboard := ProcessedText
        Sleep(200)
        
        ; 鏄剧ず鎴愬姛鎻愮ず锛堢畝鍖栵級
        TrayTip("文本已净化", "", "Iconi 1")
        
        ; 鑷姩绮樿创
        Sleep(300)
        Send("^v")
        
    } catch as e {
        TrayTip("鏂囨湰鍑€鍖栧け璐ワ細" . e.Message, "閿欒", "Iconx 2")
    }
}

; 鍘婚櫎 HTML 鏍囩
RemoveHTMLTags(Text) {
    ; 绠€鍗曠殑 HTML 鏍囩绉婚櫎锛堜娇鐢ㄦ鍒欒〃杈惧紡鎴栧惊鐜級
    Result := Text
    
    ; 绉婚櫎甯歌鐨?HTML 鏍囩
    Loop {
        ; 鏌ユ壘 <...> 鏍囩
        StartPos := InStr(Result, "<")
        if (!StartPos) {
            break
        }
        
        EndPos := InStr(Result, ">", false, StartPos)
        if (!EndPos) {
            break
        }
        
        ; 绉婚櫎鏍囩
        Result := SubStr(Result, 1, StartPos - 1) . SubStr(Result, EndPos + 1)
    }
    
    ; 瑙ｇ爜 HTML 瀹炰綋
    Result := StrReplace(Result, "&nbsp;", " ")
    Result := StrReplace(Result, "&amp;", "&")
    Result := StrReplace(Result, "&lt;", "<")
    Result := StrReplace(Result, "&gt;", ">")
    Result := StrReplace(Result, "&quot;", '"')
    Result := StrReplace(Result, "&#39;", "'")
    
    return Result
}

; 鍘婚櫎 URL
RemoveURLs(Text) {
    ; 绠€鍗曠殑 URL 绉婚櫎锛堟煡鎵?http:// 鎴?https:// 寮€澶寸殑瀛楃涓诧級
    Result := Text
    Pos := 1
    
    Loop {
        ; 鏌ユ壘 http:// 鎴?https://
        HttpPos := InStr(Result, "http://", false, Pos)
        HttpsPos := InStr(Result, "https://", false, Pos)
        
        StartPos := 0
        if (HttpPos && (!HttpsPos || HttpPos < HttpsPos)) {
            StartPos := HttpPos
        } else if (HttpsPos) {
            StartPos := HttpsPos
        }
        
        if (!StartPos) {
            break
        }
        
        ; 鏌ユ壘 URL 缁撴潫浣嶇疆锛堢┖鏍笺€佹崲琛屻€佹爣鐐圭瓑锛?
        EndPos := StartPos
        TextLen := StrLen(Result)
        
        while (EndPos <= TextLen) {
            Char := SubStr(Result, EndPos, 1)
            if (Char = " " || Char = "`n" || Char = "`r" || Char = "`t" || 
                Char = "<" || Char = ">" || Char = "(" || Char = ")" || 
                Char = "[" || Char = "]" || Char = "{" || Char = "}") {
                break
            }
            EndPos++
        }
        
        ; 绉婚櫎 URL
        Result := SubStr(Result, 1, StartPos - 1) . SubStr(Result, EndPos)
        Pos := StartPos
    }
    
    return Result
}

; 缁熶竴鏍囩偣鏍煎紡
NormalizePunctuation(Text) {
    Result := Text
    
    ; 涓枃鏍囩偣鍚庡幓闄ょ┖鏍?
    ChinesePunctuation := "，。！？；："
    Loop StrLen(ChinesePunctuation) {
        Punctuation := SubStr(ChinesePunctuation, A_Index, 1)
        Result := StrReplace(Result, Punctuation . " ", Punctuation)
    }
    
    ; 鑻辨枃鏍囩偣鍚庢坊鍔犵┖鏍硷紙濡傛灉鍚庨潰涓嶆槸绌烘牸鎴栨爣鐐癸級
    EnglishPunctuation := ".,!?;:"
    Loop StrLen(EnglishPunctuation) {
        Punctuation := SubStr(EnglishPunctuation, A_Index, 1)
        ; 绠€鍗曠殑澶勭悊锛氭爣鐐瑰悗濡傛灉鏄瓧姣嶆垨鏁板瓧锛屾坊鍔犵┖鏍?
        ; 杩欓噷浣跨敤绠€鍗曠殑鏇挎崲锛屽疄闄呭彲鑳介渶瑕佹洿澶嶆潅鐨勯€昏緫
    }
    
    return Result
}

; ===================== 鍖哄煙鎴浘鍔熻兘 =====================
; 鎵ц鍖哄煙鎴浘骞惰嚜鍔ㄧ矘璐村埌Cursor
ExecuteScreenshot() {
    global CursorPath, AISleepTime, ScreenshotWaiting, ScreenshotClipboard, ScreenshotCheckTimer, ScreenshotLastFilePath
    global ScreenshotImageDetected
    
    try {
        ; 闅愯棌闈㈡澘锛堝鏋滄樉绀猴級
        global PanelVisible
        if (PanelVisible) {
            HideCursorPanel()
        }
        
        ; 淇濆瓨褰撳墠鍓创鏉垮唴瀹?
        OldClipboard := ClipboardAll()
        
        ; 鍚姩绛夊緟绮樿创妯″紡
        ScreenshotWaiting := true
        ScreenshotImageDetected := false
        
        ; 娓呯┖鍓创鏉匡紝鐒跺悗璁板綍搴忓垪鍙凤紙椤哄簭寰堝叧閿細鍏堟竻绌哄啀璁板綍锛屽惁鍒欏簭鍒楀彿姣旇緝澶辨晥锛?
        A_Clipboard := ""
        Sleep(80)
        ClipboardSeqBeforeShot := DllCall("GetClipboardSequenceNumber", "UInt")

        ; 浣跨敤 Windows 10/11 鐨勬埅鍥惧伐鍏凤紙Win+Shift+S锛?
        Send("#+{s}")
        
        ; 绛夊緟鐢ㄦ埛瀹屾垚鎴浘锛堟渶澶氱瓑寰?0绉掞級
        ; 閫氳繃妫€娴嬪壀璐存澘鏄惁鍖呭惈鍥剧墖鏉ュ垽鏂埅鍥炬槸鍚﹀畬鎴?
        MaxWaitTime := 30000  ; 30绉?
        WaitInterval := 200   ; 姣?00ms妫€鏌ヤ竴娆?
        ElapsedTime := 0
        ScreenshotTaken := false
        CapturedClipNow := ""
        CapturedFileNow := ""
        
        ; 绛夊緟涓€涓嬶紝璁╂埅鍥惧伐鍏峰惎鍔?
        Sleep(500)
        
        ; 娓呯┖鍓创鏉匡紝鐢ㄤ簬妫€娴嬫柊鎴浘
        ; 娉ㄦ剰锛氫笉瑕佺珛鍗虫竻绌猴紝鍥犱负鍙兘褰卞搷鐢ㄦ埛鍏朵粬鎿嶄綔
        ; 鎴戜滑閫氳繃妫€娴嬪壀璐存澘鍐呭鍙樺寲鏉ュ垽鏂埅鍥惧畬鎴?
        
        while (ElapsedTime < MaxWaitTime) {
            Sleep(WaitInterval)
            ElapsedTime += WaitInterval
            
            ; 涓昏妫€娴嬶細OnClipboardChange 鍥炶皟宸叉娴嬪埌鍥剧墖鍐欏叆
            if (ScreenshotImageDetected) {
                ScreenshotTaken := true
                try ScreenshotCapturePayload(&CapturedClipNow, &CapturedFileNow, 1200)
                break
            }
            
            ; 澶囩敤妫€娴嬶細鐩存帴杞鍓创鏉垮簭鍒楀彿 + 鏍煎紡
            try {
                ClipboardSeqNow := DllCall("GetClipboardSequenceNumber", "UInt")
                if (ClipboardSeqNow = ClipboardSeqBeforeShot) {
                    continue
                }
                if (DllCall("OpenClipboard", "Ptr", 0)) {
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 2)) {  ; CF_BITMAP
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        try ScreenshotCapturePayload(&CapturedClipNow, &CapturedFileNow, 1200)
                        break
                    }
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 8)) {  ; CF_DIB
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        try ScreenshotCapturePayload(&CapturedClipNow, &CapturedFileNow, 1200)
                        break
                    }
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 17)) {  ; CF_DIBV5
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        try ScreenshotCapturePayload(&CapturedClipNow, &CapturedFileNow, 1200)
                        break
                    }
                    PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
                    if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        try ScreenshotCapturePayload(&CapturedClipNow, &CapturedFileNow, 1200)
                        break
                    }
                    DllCall("CloseClipboard")
                }
            } catch as e {
            }
        }
        
        ; 濡傛灉鎴浘鎴愬姛锛岀珛鍗宠嚜鍔ㄧ矘璐村埌 Cursor
        if (ScreenshotTaken) {
            ; 绛夊緟涓€涓嬬‘淇濇埅鍥惧凡淇濆瓨鍒板壀璐存澘
            Sleep(300)
            
            ; 淇濆瓨鎴浘鍒板叏灞€鍙橀噺锛堜娇鐢?ClipboardAll 淇濆瓨瀹屾暣鍥剧墖鏁版嵁锛?
            ; 娉ㄦ剰锛氬繀椤诲湪鎭㈠鏃у壀璐存澘涔嬪墠淇濆瓨
            try {
                ; 鍐嶆纭褰撳墠鍓创鏉跨‘瀹炴槸鍥剧墖
                if (CapturedClipNow || CapturedFileNow != "") {
                    ScreenshotClipboard := CapturedClipNow
                    ScreenshotLastFilePath := CapturedFileNow
                } else if (!ScreenshotCapturePayload(&ScreenshotClipboard, &ScreenshotLastFilePath, 3200)) {
                    throw Error("未捕获到截图数据（剪贴板/自动保存文件）")
                }
            } catch as e {
                TrayTip("保存截图失败: " . e.Message, GetText("error"), "Iconx 2")
                A_Clipboard := OldClipboard
                ScreenshotWaiting := false
                return
            }
            try {
                PasteScreenshotToCursor()
            } catch as e {
                TrayTip("鑷姩绮樿创澶辫触: " . e.Message, GetText("error"), "Iconx 2")
                ScreenshotWaiting := false
                ScreenshotClipboard := ""
            }
        } else {
            ; 鎴浘瓒呮椂鎴栧彇娑堬紝鎭㈠鏃у壀璐存澘
            A_Clipboard := OldClipboard
            ScreenshotWaiting := false
            TrayTip("鎴浘宸插彇娑堟垨瓒呮椂", GetText("tip"), "Iconi 1")
        }
    } catch as e {
        TrayTip("鎴浘澶辫触: " . e.Message, GetText("error"), "Iconx 2")
        ; 灏濊瘯鎭㈠鏃у壀璐存澘
        try {
            A_Clipboard := OldClipboard
        }
    }
}

; ===================== 鑷姩绮樿创鎴浘鍒?Cursor =====================
PasteScreenshotToCursor() {
    global ScreenshotWaiting, ScreenshotClipboard, CursorPath, AISleepTime
    
    ; 濡傛灉涓嶅湪绛夊緟鐘舵€佹垨娌℃湁鎴浘鏁版嵁锛屼笉鎵ц
    if (!ScreenshotWaiting || !ScreenshotClipboard) {
        return
    }
    
    try {
        ; 妫€鏌ュ綋鍓嶇劍鐐规槸鍚﹀湪 Cursor 鐨勮緭鍏ユ
        ; 濡傛灉 Cursor 绐楀彛宸叉縺娲伙紝鍋囪鐒︾偣鍙兘鍦ㄨ緭鍏ユ锛岀洿鎺ュ皾璇曠矘璐达紙涓嶆敼鍙樼劍鐐癸級
        IsInCursorInput := WinActive("ahk_exe Cursor.exe")
        
        if (IsInCursorInput) {
            ; 鐒︾偣鍦?Cursor锛岀洿鎺ョ矘璐达紙涓嶇瓑寰咃紝绔嬪嵆绮樿创锛屼笉鏀瑰彉鐒︾偣锛?
            ; 鍏堟仮澶嶆埅鍥惧埌鍓创鏉?
            try {
                ; 妫€鏌ョ郴缁熷壀璐存澘鏄惁鏈夊浘鐗囨暟鎹紙鍙兘鏄敤鎴锋渶鏂扮殑鎴浘锛?
                CurrentClipboardHasImage := false
                try {
                    if (DllCall("OpenClipboard", "Ptr", 0)) {
                        if (DllCall("IsClipboardFormatAvailable", "UInt", 2)
                            || DllCall("IsClipboardFormatAvailable", "UInt", 8)
                            || DllCall("IsClipboardFormatAvailable", "UInt", 17)) {
                            CurrentClipboardHasImage := true
                        } else {
                            PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
                            if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                                CurrentClipboardHasImage := true
                            }
                        }
                        DllCall("CloseClipboard")
                    }
                } catch as err {
                }
                
                ; 濡傛灉绯荤粺鍓创鏉挎病鏈夊浘鐗囷紝浣跨敤淇濆瓨鐨勬暟鎹?
                if (!CurrentClipboardHasImage && ScreenshotClipboard) {
                    A_Clipboard := ""
                    Sleep(50)
                    A_Clipboard := ScreenshotClipboard
                    Sleep(200)  ; 鐭殏绛夊緟纭繚绯荤粺璇嗗埆鍥剧墖鏁版嵁
                }
                
                ; 绔嬪嵆绮樿创锛堜笉绛夊緟锛屼笉鏀瑰彉鐒︾偣锛?
                Send("^v")
                Sleep(100)  ; 鐭殏绛夊緟纭繚绮樿创瀹屾垚
                
                ; 鍋滄绛夊緟鐘舵€?
                ScreenshotWaiting := false
                ScreenshotClipboard := ""
                
                ; 鏄剧ず鎴愬姛鎻愮ず
                TrayTip(GetText("screenshot_paste_success"), GetText("tip"), "Iconi 1")
                return
            } catch as e {
                ; 濡傛灉鐩存帴绮樿创澶辫触锛岀户缁墽琛屽畬鏁存祦绋?
            }
        }
        
        ; 濡傛灉鐒︾偣涓嶅湪 Cursor 鎴栫洿鎺ョ矘璐村け璐ワ紝鎵ц瀹屾暣鐨勬縺娲诲拰绮樿创娴佺▼
        ; 纭繚 Cursor 绐楀彛瀛樺湪
        if (!WinExist("ahk_exe Cursor.exe")) {
            if (CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                Sleep(AISleepTime)
            } else {
                TrayTip("Cursor 鏈繍琛屼笖鏃犳硶鍚姩", GetText("error"), "Iconx 2")
                return
            }
        }
        
        ; 婵€娲?Cursor 绐楀彛锛堝娆″皾璇曠‘淇濇縺娲绘垚鍔燂級
        LegacyGuard_RequestCursorFocus("ScreenshotWorkflow", "screenshot_cursor", 120)
        WinWaitActive("ahk_exe Cursor.exe", , 3)
        Sleep(400)  ; 澧炲姞绛夊緟鏃堕棿纭繚绐楀彛瀹屽叏婵€娲?
        
        ; 鍐嶆纭繚 Cursor 绐楀彛婵€娲?
        if !WinActive("ahk_exe Cursor.exe") {
            LegacyGuard_RequestCursorFocus("ScreenshotWorkflow", "screenshot_cursor", 120)
            WinWaitActive("ahk_exe Cursor.exe", , 3)
            Sleep(400)
        }
        
        ; 绗笁娆＄‘淇濈獥鍙ｆ縺娲伙紙鍏抽敭姝ラ锛?
        if !WinActive("ahk_exe Cursor.exe") {
            LegacyGuard_RequestCursorFocus("ScreenshotWorkflow", "screenshot_cursor", 120)
            WinWaitActive("ahk_exe Cursor.exe", , 3)
            Sleep(300)
        }
        
        ; 鍏堟寜 ESC 鍏抽棴鍙兘宸叉墦寮€鐨勮緭鍏ユ锛岄伩鍏嶅啿绐?
        Send("{Esc}")
        Sleep(300)
        
        ; 纭繚绐楀彛婵€娲伙紙ESC 鍚庡彲鑳藉け鍘荤劍鐐癸級
        if !WinActive("ahk_exe Cursor.exe") {
            LegacyGuard_RequestCursorFocus("ScreenshotWorkflow", "screenshot_cursor", 120)
            WinWaitActive("ahk_exe Cursor.exe", , 3)
            Sleep(400)
        }
        
        ; 鎵撳紑 Cursor 鐨?AI 鑱婂ぉ闈㈡澘锛圕trl+L锛?
        Send("^l")
        Sleep(1000)  ; 澧炲姞绛夊緟鏃堕棿纭繚鑱婂ぉ闈㈡澘瀹屽叏鎵撳紑
        
        ; 鍐嶆纭繚绐楀彛婵€娲伙紙鎵撳紑鑱婂ぉ闈㈡澘鍚庡彲鑳藉け鍘荤劍鐐癸級
        if !WinActive("ahk_exe Cursor.exe") {
            LegacyGuard_RequestCursorFocus("ScreenshotWorkflow", "screenshot_cursor", 120)
            WinWaitActive("ahk_exe Cursor.exe", , 3)
            Sleep(500)
        }
        
        ; 纭繚杈撳叆妗嗚幏寰楃劍鐐?
        ; 鏂规硶1锛氭寜 Tab 閿Щ鍔ㄥ埌杈撳叆妗嗭紙濡傛灉鐒︾偣涓嶅湪杈撳叆妗嗕笂锛?
        Send("{Tab}")
        Sleep(200)
        
        ; 鏂规硶2锛氬啀娆＄‘淇濈獥鍙ｆ縺娲?
        if !WinActive("ahk_exe Cursor.exe") {
            LegacyGuard_RequestCursorFocus("ScreenshotWorkflow", "screenshot_cursor", 120)
            WinWaitActive("ahk_exe Cursor.exe", , 2)
            Sleep(300)
        }
        
        ; 鏂规硶3锛氬鏋?Tab 涓嶈捣浣滅敤锛屽皾璇曞啀娆℃寜 Ctrl+L 纭繚鑱婂ぉ闈㈡澘鎵撳紑涓旂劍鐐瑰湪杈撳叆妗?
        ; 浣嗗厛妫€鏌ヤ竴涓嬶紝濡傛灉宸茬粡鎵撳紑浜嗭紝鍐嶆鎸夊彲鑳戒細鍏抽棴锛屾墍浠ュ厛鎸?ESC 鍐嶆寜 Ctrl+L
        Send("{Esc}")
        Sleep(150)
        Send("^l")
        Sleep(600)
        
        ; 鏈€鍚庝竴娆＄‘淇濈獥鍙ｆ縺娲伙紙绮樿创鍓嶅叧閿鏌ワ級
        if !WinActive("ahk_exe Cursor.exe") {
            LegacyGuard_RequestCursorFocus("ScreenshotWorkflow", "screenshot_cursor", 120)
            WinWaitActive("ahk_exe Cursor.exe", , 2)
            Sleep(300)
        }
        
        ; 灏嗘埅鍥炬仮澶嶅埌鍓创鏉匡紙浼樺厛浣跨敤绯荤粺鍓创鏉夸腑鐨勬渶鏂版暟鎹級
        try {
            ; 鍏堟鏌ョ郴缁熷壀璐存澘鏄惁鏈夊浘鐗囨暟鎹紙鍙兘鏄敤鎴锋渶鏂扮殑鎴浘锛?
            CurrentClipboardHasImage := false
            try {
                if (DllCall("OpenClipboard", "Ptr", 0)) {
                    ; 妫€鏌ユ槸鍚﹀寘鍚綅鍥炬牸寮?
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 2)) {  ; CF_BITMAP = 2
                        CurrentClipboardHasImage := true
                    } else if (DllCall("IsClipboardFormatAvailable", "UInt", 8)) {  ; CF_DIB = 8
                        CurrentClipboardHasImage := true
                    } else if (DllCall("IsClipboardFormatAvailable", "UInt", 17)) {  ; CF_DIBV5 = 17
                        CurrentClipboardHasImage := true
                    } else {
                        ; 妫€鏌?PNG 鏍煎紡
                        PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
                        if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                            CurrentClipboardHasImage := true
                        }
                    }
                    DllCall("CloseClipboard")
                }
            } catch as err {
                ; 妫€鏌ュけ璐ワ紝蹇界暐锛岀户缁娇鐢ㄤ繚瀛樼殑鏁版嵁
            }
            
            ; 濡傛灉绯荤粺鍓创鏉夸腑鏈夊浘鐗囷紝浼樺厛浣跨敤鏈€鏂扮殑锛堢敤鎴峰彲鑳借繘琛屼簡鏂扮殑鎴浘锛?
            if (CurrentClipboardHasImage) {
                ; 浣跨敤绯荤粺鍓创鏉夸腑鐨勬渶鏂版埅鍥炬暟鎹?
                ; 涓嶉渶瑕佹仮澶嶏紝鐩存帴浣跨敤褰撳墠鍓创鏉?
                Sleep(200) ; 鐭殏绛夊緟纭繚鍓创鏉挎暟鎹ǔ瀹?
            } else if (ScreenshotClipboard) {
                ; 绯荤粺鍓创鏉挎病鏈夊浘鐗囷紝浣跨敤涔嬪墠淇濆瓨鐨勬暟鎹?
                ; 鍏堟竻绌哄壀璐存澘
                A_Clipboard := ""
                Sleep(150)
                
                ; 鎭㈠ ClipboardAll 鏁版嵁锛堝浘鐗囨暟鎹級
                A_Clipboard := ScreenshotClipboard
                Sleep(1000) ; 澧炲姞寤惰繜纭繚绯荤粺璇嗗埆鍥剧墖鏁版嵁骞跺噯澶囧ソ
                
                ; 楠岃瘉鏁版嵁鏄惁鎴愬姛鎭㈠
                if (!DllCall("OpenClipboard", "Ptr", 0)) {
                    ; 濡傛灉鏃犳硶鎵撳紑鍓创鏉匡紝鍐嶇瓑寰呬竴娆?
                    Sleep(500)
                } else {
                    DllCall("CloseClipboard")
                }
            } else {
                throw Error("没有可用的截图数据")
            }
            
            ; 楠岃瘉鍓创鏉挎槸鍚﹀寘鍚浘鐗囨暟鎹紙闇€瑕佸厛鎵撳紑鍓创鏉匡級
            IsImage := false
            if (DllCall("OpenClipboard", "Ptr", 0)) {
                try {
                    ; 妫€鏌ユ槸鍚﹀寘鍚綅鍥炬牸寮?
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 2)) {  ; CF_BITMAP = 2
                        IsImage := true
                    } else if (DllCall("IsClipboardFormatAvailable", "UInt", 8)) {  ; CF_DIB = 8
                        IsImage := true
                    } else if (DllCall("IsClipboardFormatAvailable", "UInt", 17)) {  ; CF_DIBV5 = 17
                        IsImage := true
                    } else {
                        ; 妫€鏌?PNG 鏍煎紡
                        PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
                        if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                            IsImage := true
                        }
                    }
                } finally {
                    DllCall("CloseClipboard")
                }
            }
            
            if (!IsImage) {
                ; 濡傛灉鍥剧墖鏁版嵁鏈噯澶囧ソ锛屽啀绛夊緟涓€娆″苟閲嶆柊妫€鏌?
                Sleep(500)
                if (DllCall("OpenClipboard", "Ptr", 0)) {
                    try {
                        if (DllCall("IsClipboardFormatAvailable", "UInt", 2)
                            || DllCall("IsClipboardFormatAvailable", "UInt", 8)
                            || DllCall("IsClipboardFormatAvailable", "UInt", 17)) {
                            IsImage := true
                        } else {
                            PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
                            if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                                IsImage := true
                            }
                        }
                    } finally {
                        DllCall("CloseClipboard")
                    }
                }
                
                if (!IsImage) {
                    throw Error("鍓创鏉夸腑鏈娴嬪埌鍥剧墖鏁版嵁锛屾埅鍥惧彲鑳藉凡澶辨晥")
                }
            }
        } catch as e {
            throw Error("鏃犳硶鎭㈠鎴浘鍒板壀璐存澘: " . e.Message)
        }
        
        ; 鎭㈠鍓创鏉垮悗锛屽啀娆＄‘淇濈獥鍙ｆ縺娲伙紙鎭㈠鎿嶄綔鍙兘褰卞搷鐒︾偣锛?
        if !WinActive("ahk_exe Cursor.exe") {
            LegacyGuard_RequestCursorFocus("ScreenshotWorkflow", "screenshot_cursor", 120)
            WinWaitActive("ahk_exe Cursor.exe", , 1)
            Sleep(300)
        }
        
        ; 鏈€鍚庝竴娆＄‘淇濈獥鍙ｆ縺娲伙紙绮樿创鍓嶅叧閿鏌ワ級
        if !WinActive("ahk_exe Cursor.exe") {
            LegacyGuard_RequestCursorFocus("ScreenshotWorkflow", "screenshot_cursor", 120)
            WinWaitActive("ahk_exe Cursor.exe", , 1)
            Sleep(200)
        }
        
        ; 纭繚杈撳叆妗嗚幏寰楃劍鐐癸紙绮樿创鍓嶆渶鍚庢鏌ワ級
        ; 鍐嶆纭繚绐楀彛婵€娲?
        if !WinActive("ahk_exe Cursor.exe") {
            LegacyGuard_RequestCursorFocus("ScreenshotWorkflow", "screenshot_cursor", 120)
            WinWaitActive("ahk_exe Cursor.exe", , 2)
            Sleep(300)
        }
        
        ; 浣跨敤 Ctrl+V 绮樿创锛堝彧浣跨敤涓€绉嶆柟寮忥紝閬垮厤閲嶅绮樿创锛?
        ; 鍦ㄧ矘璐村墠锛屽啀娆＄‘淇濈劍鐐瑰湪杈撳叆妗嗭紙閫氳繃鍙戦€佷竴涓瓧绗︾劧鍚庡垹闄わ級
        ; 杩欐牱鍙互纭繚杈撳叆妗嗙‘瀹炶幏寰椾簡鐒︾偣
        Send("{Home}")  ; 绉诲姩鍒拌緭鍏ユ寮€澶达紙濡傛灉鐒︾偣鍦ㄨ緭鍏ユ锛岃繖浼氱敓鏁堬級
        Sleep(100)
        
        ; 鎵ц绮樿创
        Send("^v")
        Sleep(600)  ; 绛夊緟绮樿创瀹屾垚锛堝浘鐗囩矘璐村彲鑳介渶瑕佹洿闀挎椂闂达級
        
        ; 鍋滄绛夊緟鐘舵€?
        ScreenshotWaiting := false
        
        ; 娓呯┖鎴浘鏁版嵁
        ScreenshotClipboard := ""
        
        ; 鏄剧ず鎴愬姛鎻愮ず
        TrayTip(GetText("screenshot_paste_success"), GetText("tip"), "Iconi 1")
    } catch as e {
        TrayTip("绮樿创鎴浘澶辫触: " . e.Message, GetText("error"), "Iconx 2")
        ; 鍗充娇澶辫触锛屼篃鍋滄绛夊緟鐘舵€?
        ScreenshotWaiting := false
        ScreenshotClipboard := ""
    }
}

; ===================== 浠庢偓娴潰鏉跨矘璐存埅鍥撅紙宸插簾寮冿紝淇濈暀鐢ㄤ簬鍏煎锛?====================
PasteScreenshotFromButton(*) {
    ; 鐩存帴璋冪敤鑷姩绮樿创鍑芥暟
    PasteScreenshotToCursor()
}

; ===================== 鏄剧ず鎴浘鎮诞闈㈡澘 =====================
ShowScreenshotButton() {
    global GuiID_ScreenshotButton, ScreenshotButtonVisible, UI_Colors, ThemeMode
    
    try {
        ; 濡傛灉闈㈡澘宸叉樉绀猴紝鍏堥殣钘?
        if (ScreenshotButtonVisible && GuiID_ScreenshotButton != 0) {
            try {
                GuiID_ScreenshotButton.Destroy()
            } catch as err {
            }
            GuiID_ScreenshotButton := 0
        }
        
        ; 纭繚 UI_Colors 宸插垵濮嬪寲
        if (!IsSet(UI_Colors) || !UI_Colors) {
            ; 濡傛灉鏈垵濮嬪寲锛屼娇鐢ㄩ粯璁ら鑹?
            global ThemeMode
            if (!IsSet(ThemeMode)) {
                ThemeMode := "dark"
            }
            ApplyTheme(ThemeMode)
        }
        
        ; 鍒涘缓鎮诞闈㈡澘 GUI锛堝弬鑰冨叾浠栭潰鏉跨殑鍒涘缓鏂瑰紡锛?
        GuiID_ScreenshotButton := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
        GuiID_ScreenshotButton.BackColor := UI_Colors.Background
        
        ; 闈㈡澘灏哄
        PanelWidth := 160
        PanelHeight := 60
        
        ; 璁＄畻闈㈡澘浣嶇疆锛堜紭鍏堟樉绀哄湪 Cursor 绐楀彛姝ｄ腑闂达紝骞剁‘淇濆湪鍚屼竴灞忓箷锛?
        global ScreenshotPanelX, ScreenshotPanelY, ConfigFile
        PanelX := -1
        PanelY := -1
        
        ; 灏濊瘯鑾峰彇 Cursor 绐楀彛浣嶇疆鍜屽ぇ灏忥紝骞剁‘瀹氬叾鎵€鍦ㄧ殑灞忓箷
        if (WinExist("ahk_exe Cursor.exe")) {
            try {
                WinGetPos(&CursorX, &CursorY, &CursorW, &CursorH, "ahk_exe Cursor.exe")
                ; 鑾峰彇 Cursor 绐楀彛鎵€鍦ㄧ殑灞忓箷绱㈠紩
                CursorScreenIndex := GetWindowScreenIndex("ahk_exe Cursor.exe")
                ScreenInfo := GetScreenInfo(CursorScreenIndex)
                
                ; 璁＄畻 Cursor 绐楀彛涓績浣嶇疆锛堢浉瀵逛簬鍏舵墍鍦ㄥ睆骞曪級
                CursorCenterX := CursorX + CursorW // 2
                CursorCenterY := CursorY + CursorH // 2
                
                ; 纭繚涓績鐐瑰湪灞忓箷鑼冨洿鍐?
                if (CursorCenterX >= ScreenInfo.Left && CursorCenterX < ScreenInfo.Right && 
                    CursorCenterY >= ScreenInfo.Top && CursorCenterY < ScreenInfo.Bottom) {
                    ; 璁＄畻闈㈡澘浣嶇疆锛圕ursor 绐楀彛涓績锛?
                    PanelX := CursorCenterX - PanelWidth // 2
                    PanelY := CursorCenterY - PanelHeight // 2
                    
                    ; 纭繚闈㈡澘瀹屽叏鍦ㄥ睆骞曡寖鍥村唴
                    if (PanelX < ScreenInfo.Left) {
                        PanelX := ScreenInfo.Left + 10
                    }
                    if (PanelY < ScreenInfo.Top) {
                        PanelY := ScreenInfo.Top + 10
                    }
                    if (PanelX + PanelWidth > ScreenInfo.Right) {
                        PanelX := ScreenInfo.Right - PanelWidth - 10
                    }
                    if (PanelY + PanelHeight > ScreenInfo.Bottom) {
                        PanelY := ScreenInfo.Bottom - PanelHeight - 10
                    }
                }
            } catch as err {
                ; 濡傛灉鑾峰彇澶辫触锛屼娇鐢ㄤ繚瀛樼殑浣嶇疆鎴栧睆骞曚腑蹇?
            }
        }
        
        ; 濡傛灉 Cursor 绐楀彛涓嶅瓨鍦ㄦ垨鑾峰彇澶辫触锛屼娇鐢ㄤ繚瀛樼殑浣嶇疆
        if (PanelX = -1 || PanelY = -1) {
            ; 浠庨厤缃枃浠惰鍙栦笂娆′繚瀛樼殑浣嶇疆
            ScreenshotPanelX := IniRead(ConfigFile, "Screenshot", "PanelX", "-1")
            ScreenshotPanelY := IniRead(ConfigFile, "Screenshot", "PanelY", "-1")
            
            if (ScreenshotPanelX != "-1" && ScreenshotPanelY != "-1") {
                PanelX := Integer(ScreenshotPanelX)
                PanelY := Integer(ScreenshotPanelY)
                
                ; 楠岃瘉淇濆瓨鐨勪綅缃槸鍚﹀湪鏈夋晥灞忓箷鑼冨洿鍐?
                ; 濡傛灉涓嶅湪锛屼娇鐢ㄤ富灞忓箷涓績
                ValidPosition := false
                MonitorCount := MonitorGetCount()
                Loop MonitorCount {
                    MonitorIndex := A_Index
                    MonitorGet(MonitorIndex, &Left, &Top, &Right, &Bottom)
                    if (PanelX >= Left && PanelX < Right && PanelY >= Top && PanelY < Bottom) {
                        ValidPosition := true
                        break
                    }
                }
                
                if (!ValidPosition) {
                    ; 浣嶇疆鏃犳晥锛屼娇鐢ㄤ富灞忓箷涓績
                    ScreenInfo := GetScreenInfo(1)
                    PanelX := ScreenInfo.Left + (ScreenInfo.Width - PanelWidth) // 2
                    PanelY := ScreenInfo.Top + (ScreenInfo.Height - PanelHeight) // 2
                }
            } else {
                ; 濡傛灉涔熸病鏈変繚瀛樼殑浣嶇疆锛屼娇鐢ㄤ富灞忓箷涓績
                ScreenInfo := GetScreenInfo(1)
                PanelX := ScreenInfo.Left + (ScreenInfo.Width - PanelWidth) // 2
                PanelY := ScreenInfo.Top + (ScreenInfo.Height - PanelHeight) // 2
            }
        }
        
        ; 鍒涘缓鎸夐挳锛堝厛鍒涘缓鎸夐挳锛岀‘淇濆彲浠ョ偣鍑伙級
        ButtonText := GetText("screenshot_button_text")
        ButtonWidth := PanelWidth - 20
        ButtonHeight := 40
        ButtonX := 10
        ButtonY := 10
        
        ; 鍒涘缓鎸夐挳锛堢‘淇濇寜閽彲浠ョ偣鍑伙級
        ; 娣诲姞 SS_NOTIFY (0x100) 纭繚 Text 鎺т欢鍝嶅簲鐐瑰嚮
        ScreenshotBtn := GuiID_ScreenshotButton.Add("Text", "x" . ButtonX . " y" . ButtonY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 +0x100 cFFFFFF Background" . UI_Colors.BtnPrimary . " vScreenshotBtn", ButtonText)
        ScreenshotBtn.SetFont("s11 Bold", "Segoe UI")
        ; 缁戝畾鐐瑰嚮浜嬩欢锛堢洿鎺ョ粦瀹氬嚱鏁帮紝涓嶄娇鐢ㄩ棴鍖咃級
        ScreenshotBtn.OnEvent("Click", PasteScreenshotFromButton)
        
        ; 鍦ㄦ寜閽彸涓婅娣诲姞鎷栧姩鏌勶紙鏄剧ず涓€涓嫋鍔ㄥ浘鏍囷級
        DragHandleSize := 20
        DragHandleX := ButtonX + ButtonWidth - DragHandleSize - 2
        DragHandleY := ButtonY + 2
        ; 浣跨敤鍗婇€忔槑鑳屾櫙锛岃鎷栧姩鏌勬洿鏄庢樉
        DragHandleBg := (ThemeMode = "light") ? "E0E0E0" : "404040"
        DragHandle := GuiID_ScreenshotButton.Add("Text", "x" . DragHandleX . " y" . DragHandleY . " w" . DragHandleSize . " h" . DragHandleSize . " Center 0x200 cFFFFFF Background" . DragHandleBg . " vDragHandle", "☰")
        DragHandle.SetFont("s12 Bold", "Segoe UI")
        DragHandle.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , GuiID_ScreenshotButton.Hwnd))
        ; 娉ㄦ剰锛歍ext 鎺т欢涓嶆敮鎸?MouseMove/MouseLeave 浜嬩欢锛屾墍浠ヤ娇鐢ㄥ浐瀹氳儗鏅壊
        
        ; 鍒涘缓鍙嫋鍔ㄧ殑鑳屾櫙鍖哄煙锛堝悗鍒涘缓锛屽湪鎸夐挳涓嬫柟锛屼絾涓嶈鐩栨寜閽級
        ; 鍒涘缓澶氫釜鎷栧姩鍖哄煙锛岃鐩栨寜閽懆鍥寸殑鍖哄煙
        ; 椤堕儴鎷栧姩鍖哄煙
        DragAreaTop := GuiID_ScreenshotButton.Add("Text", "x0 y0 w" . PanelWidth . " h" . ButtonY . " BackgroundTrans")
        DragAreaTop.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , GuiID_ScreenshotButton.Hwnd))
        ; 宸︿晶鎷栧姩鍖哄煙
        DragAreaLeft := GuiID_ScreenshotButton.Add("Text", "x0 y" . ButtonY . " w" . ButtonX . " h" . ButtonHeight . " BackgroundTrans")
        DragAreaLeft.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , GuiID_ScreenshotButton.Hwnd))
        ; 鍙充晶鎷栧姩鍖哄煙锛堜笉鍖呮嫭鎷栧姩鏌勫尯鍩燂級
        DragAreaRight := GuiID_ScreenshotButton.Add("Text", "x" . (ButtonX + ButtonWidth) . " y" . ButtonY . " w" . (PanelWidth - ButtonX - ButtonWidth) . " h" . ButtonHeight . " BackgroundTrans")
        DragAreaRight.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , GuiID_ScreenshotButton.Hwnd))
        ; 搴曢儴鎷栧姩鍖哄煙
        DragAreaBottom := GuiID_ScreenshotButton.Add("Text", "x0 y" . (ButtonY + ButtonHeight) . " w" . PanelWidth . " h" . (PanelHeight - ButtonY - ButtonHeight) . " BackgroundTrans")
        DragAreaBottom.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , GuiID_ScreenshotButton.Hwnd))
        
        ; 娣诲姞鎮仠鏁堟灉
        HoverBtn(ScreenshotBtn, UI_Colors.BtnPrimary, UI_Colors.BtnHover)
        
        ; 浣跨敤瀹氭椂鍣ㄥ畾鏈熶繚瀛樹綅缃紙鍥犱负 AutoHotkey v2 涓嶆敮鎸?Move 浜嬩欢锛?
        SetTimer(SaveScreenshotPanelPosition, 500)  ; 姣?00ms妫€鏌ヤ竴娆′綅缃?
        
        ; 鏄剧ず闈㈡澘锛堝湪 Show 涓缃ぇ灏忓拰浣嶇疆锛?
        GuiID_ScreenshotButton.Show("w" . PanelWidth . " h" . PanelHeight . " x" . PanelX . " y" . PanelY . " NoActivate")
        ScreenshotButtonVisible := true
        
        ; 纭繚绐楀彛濮嬬粓缃《锛堜娇鐢?WinSetAlwaysOnTop锛?
        WinSetAlwaysOnTop(1, GuiID_ScreenshotButton.Hwnd)
        
        ; 璁剧疆宸ュ叿鎻愮ず
        try {
            ; 浣跨敤 ToolTip 鏄剧ず鎻愮ず
            ToolTip(GetText("screenshot_button_tip"), PanelX + PanelWidth // 2, PanelY - 30)
            SetTimer(() => ToolTip(), -3000)  ; 3绉掑悗鑷姩闅愯棌鎻愮ず
        } catch as err {
        }
    } catch as e {
        ; 濡傛灉鍒涘缓澶辫触锛屾樉绀洪敊璇俊鎭?
        TrayTip("鍒涘缓鎮诞闈㈡澘澶辫触: " . e.Message, GetText("error"), "Iconx 2")
        throw e
    }
}

; ===================== 闅愯棌鎴浘鎮诞闈㈡澘 =====================
HideScreenshotButton() {
    global GuiID_ScreenshotButton, ScreenshotButtonVisible
    
    ; 鍋滄瀹氭椂鍣?
    SetTimer(SaveScreenshotPanelPosition, 0)
    
    ; 鍦ㄩ殣钘忓墠淇濆瓨浣嶇疆
    SaveScreenshotPanelPosition()
    
    if (GuiID_ScreenshotButton != 0) {
        try {
            ; 纭繚绐楀彛琚攢姣?
            GuiID_ScreenshotButton.Destroy()
        } catch as err {
            ; 濡傛灉閿€姣佸け璐ワ紝灏濊瘯寮哄埗鍏抽棴
            try {
                WinClose("ahk_id " . GuiID_ScreenshotButton.Hwnd)
            } catch as err {
            }
        }
        GuiID_ScreenshotButton := 0
    }
    ScreenshotButtonVisible := false
}

; ===================== 鎴浘闈㈡澘鎷栧姩澶勭悊 =====================
ScreenshotPanelDragHandler(*) {
    global GuiID_ScreenshotButton
    if (GuiID_ScreenshotButton != 0) {
        PostMessage(0xA1, 2, , GuiID_ScreenshotButton.Hwnd)  ; WM_NCLBUTTONDOWN
    }
}

; ===================== 淇濆瓨鎴浘闈㈡澘浣嶇疆 =====================
SaveScreenshotPanelPosition(*) {
    global GuiID_ScreenshotButton, ScreenshotPanelX, ScreenshotPanelY, ConfigFile, ScreenshotButtonVisible
    
    ; 鍙湪闈㈡澘鍙鏃朵繚瀛樹綅缃?
    if (GuiID_ScreenshotButton != 0 && ScreenshotButtonVisible) {
        try {
            ; 鑾峰彇绐楀彛褰撳墠浣嶇疆
            WinGetPos(&X, &Y, , , "ahk_id " . GuiID_ScreenshotButton.Hwnd)
            if (X >= 0 && Y >= 0) {  ; 纭繚浣嶇疆鏈夋晥
                ScreenshotPanelX := X
                ScreenshotPanelY := Y
                
                ; 淇濆瓨鍒伴厤缃枃浠?
                IniWrite(ScreenshotPanelX, ConfigFile, "Screenshot", "PanelX")
                IniWrite(ScreenshotPanelY, ConfigFile, "Screenshot", "PanelY")
            }
        } catch as err {
            ; 蹇界暐淇濆瓨澶辫触
        }
    }
}

; ===================== 鍋滄鎴浘绛夊緟 =====================
StopScreenshotWaiting() {
    global ScreenshotWaiting, ScreenshotCheckTimer
    
    if (ScreenshotWaiting) {
        ScreenshotWaiting := false
        HideScreenshotButton()
        ; 绉婚櫎瓒呮椂鎻愮ず锛堟寜鐢ㄦ埛瑕佹眰锛屼笉鏄剧ず浠讳綍鎻愮ず锛?
    }
}
