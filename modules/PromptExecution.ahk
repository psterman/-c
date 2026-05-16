#Requires AutoHotkey v2.0

PromptExecution_RequestCursorFocus(reason := "prompt_exec", protectMs := 220) {
    try {
        if !WinExist("ahk_exe Cursor.exe")
            return false
        hwnd := WinGetID("ahk_exe Cursor.exe")
        if !hwnd
            return false
        if FuncExists("FocusBroker_Request")
            return FocusBroker_Request("PromptExecution", hwnd, 45, reason, protectMs)
        return !!DllCall("SetForegroundWindow", "ptr", hwnd, "int")
    } catch {
        return false
    }
}

PromptExecution_LogGuard(tag, detail := "") {
    try {
        line := "[" . A_Now . "][" . tag . "] " . String(detail) . "`r`n"
        if FuncExists("NMER_AsyncLog")
            NMER_AsyncLog(A_ScriptDir . "\Cache\prompt_execution_guard.log", line)
        else
            FileAppend(line, A_ScriptDir . "\Cache\prompt_execution_guard.log", "UTF-8")
    } catch {
    }
}

global g_PromptExecution_CopyTicket := 0
global g_PromptExecution_CopyState := 0

PromptExecution_BeginCopySelectionAsync(oldClipboard, doneCb) {
    global g_PromptExecution_CopyTicket, g_PromptExecution_CopyState
    g_PromptExecution_CopyTicket += 1
    ticket := g_PromptExecution_CopyTicket
    g_PromptExecution_CopyState := Map("ticket", ticket, "start", A_TickCount, "tries", 0, "old", oldClipboard, "done", doneCb)
    try A_Clipboard := ""
    catch {
    }
    if WinActive("ahk_exe Cursor.exe") {
        Send("{Esc}")
        Sleep(20)
    }
    SetTimer((*) => PromptExecution_CopyPoll(ticket), -30)
}

PromptExecution_CopyPoll(ticket, *) {
    global g_PromptExecution_CopyState
    if !(g_PromptExecution_CopyState is Map)
        return
    if (Integer(g_PromptExecution_CopyState["ticket"]) != Integer(ticket))
        return
    if ((A_TickCount - Integer(g_PromptExecution_CopyState["start"])) > 480) {
        PromptExecution_CopyFinish(ticket, "")
        return
    }
    tries := Integer(g_PromptExecution_CopyState["tries"])
    if (tries = 0)
        SendInput("^c")
    else if (tries = 2)
        Send("^c")
    else if (tries = 4)
        SendEvent("^c")
    g_PromptExecution_CopyState["tries"] := tries + 1
    txt := ""
    try txt := A_Clipboard
    catch {
        txt := ""
    }
    if !(txt is String) {
        try txt := String(txt)
        catch {
            txt := ""
        }
    }
    if (Trim(txt, " `t`r`n") != "") {
        PromptExecution_CopyFinish(ticket, txt)
        return
    }
    SetTimer((*) => PromptExecution_CopyPoll(ticket), -70)
}

PromptExecution_CopyFinish(ticket, selectedCode) {
    global g_PromptExecution_CopyState
    if !(g_PromptExecution_CopyState is Map)
        return
    if (Integer(g_PromptExecution_CopyState["ticket"]) != Integer(ticket))
        return
    doneCb := g_PromptExecution_CopyState["done"]
    old := g_PromptExecution_CopyState["old"]
    try A_Clipboard := old
    catch {
    }
    g_PromptExecution_CopyState := 0
    if IsObject(doneCb) {
        try doneCb.Call(String(selectedCode))
    }
}

; ===================== 鎵ц鎻愮ず璇嶅嚱鏁?=====================
ExecutePrompt(Type, TemplateID := "") {
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize, CursorPath, AISleepTime, IsCommandMode, CapsLock2, ClipboardHistory
    global DefaultTemplateIDs, PromptTemplates
    global CoreAsyncStrictMode, LegacySyncFallback
    
    ; 娓呴櫎鏍囪锛岃〃绀轰娇鐢ㄤ簡鍔熻兘
    CapsLock2 := false
    ; 鏍囪鍛戒护妯″紡缁撴潫锛岄伩鍏?CapsLock 閲婃斁鍚庡啀娆￠殣钘忛潰鏉?
    IsCommandMode := false
    
    HideCursorPanel()
    
    ; 鏍规嵁绫诲瀷閫夋嫨鎻愮ず璇嶏紙浼樺厛浣跨敤妯℃澘绯荤粺锛?
    Prompt := ""
    
    ; 濡傛灉鎻愪緵浜員emplateID锛岀洿鎺ヤ娇鐢ㄦā鏉?
    if (TemplateID != "") {
        Template := GetTemplateByID(TemplateID)
        if (Template) {
            Prompt := Template.Content
        }
    }
    
    ; 濡傛灉娌℃湁TemplateID鎴栨ā鏉挎湭鎵惧埌锛屼娇鐢ㄩ粯璁ゆā鏉挎垨浼犵粺鏂瑰紡
    if (Prompt = "") {
        ; 灏濊瘯浠庨粯璁ゆā鏉挎槧灏勮幏鍙?
        if (DefaultTemplateIDs.Has(Type)) {
            TemplateID := DefaultTemplateIDs[Type]
            Template := GetTemplateByID(TemplateID)
            if (Template) {
                Prompt := Template.Content
            }
        }
        
        ; 濡傛灉妯℃澘绯荤粺鏈壘鍒帮紝鍥為€€鍒颁紶缁熸柟寮?
        if (Prompt = "") {
            switch Type {
                case "Explain":
                    Prompt := Prompt_Explain
                case "Refactor":
                    Prompt := Prompt_Refactor
                case "Optimize":
                    Prompt := Prompt_Optimize
                case "BatchExplain":
                    Prompt := Prompt_Explain
                case "BatchRefactor":
                    Prompt := Prompt_Refactor
                case "BatchOptimize":
                    Prompt := Prompt_Optimize
            }
        }
    }
    
    if (Prompt = "") {
        return
    }
    
    ; 鍦ㄥ垏鎹㈢獥鍙ｄ箣鍓嶏紝鍏堜繚瀛樺綋鍓嶅壀璐存澘鍐呭骞跺皾璇曞鍒堕€変腑鏂囨湰
    ; 杩欐牱鍙互纭繚鍗充娇鍒囨崲绐楀彛鍚庡け鍘婚€変腑鐘舵€侊紝涔熻兘鑾峰彇鍒颁箣鍓嶉€変腑鐨勬枃鏈?
    ; 鍦ㄥ垏鎹㈢獥鍙ｄ箣鍓嶏紝鍏堜繚瀛樺綋鍓嶅壀璐存澘鍐呭
    OldClipboard := A_Clipboard
    
    ; 1. 淇濆瓨褰撳墠鍓创鏉垮埌鍘嗗彶璁板綍锛堣В鍐虫薄鏌撻棶棰橈紝闃叉鐢ㄦ埛鏁版嵁涓㈠け锛?
    if (OldClipboard != "") {
        ClipboardHistory.Push(OldClipboard)
    }

    ; Core async strict path: do not block UI thread on initial selection copy.
    doneCb := Func("PromptExecution_OnInitialCopyDone").Bind(Prompt, OldClipboard, CursorPath, AISleepTime)
    PromptExecution_BeginCopySelectionAsync(OldClipboard, doneCb)
    return
}

; Legacy compatibility wrapper: keep symbol for external callers, but always route async path.
ExecutePrompt_Continue(Prompt, SelectedCode, OldClipboard, CursorPath, AISleepTime) {
    PromptExecution_LogGuard("legacy_sync_path_hit", "ExecutePrompt_Continue.redirect_async")
    PromptExecution_ContinueAsync(Prompt, SelectedCode, OldClipboard, CursorPath, AISleepTime)
}

PromptExecution_OnInitialCopyDone(Prompt, OldClipboard, CursorPath, AISleepTime, SelectedCode) {
    Func("PromptExecution_ContinueAsync").Call(Prompt, SelectedCode, OldClipboard, CursorPath, AISleepTime)
}

PromptExecution_TryReadClipboardText() {
    txt := ""
    try txt := A_Clipboard
    catch {
        txt := ""
    }
    if !(txt is String) {
        try txt := String(txt)
        catch {
            txt := ""
        }
    }
    return Trim(txt, " `t`r`n")
}

PromptExecution_ContinueAsync(Prompt, SelectedCode, OldClipboard, CursorPath, AISleepTime) {
    global CoreAsyncStrictMode, LegacySyncFallback
    try {
        if WinExist("ahk_exe Cursor.exe") {
            PromptExecution_RequestCursorFocus("execute_prompt_open")
            WinWaitActive("ahk_exe Cursor.exe", , 1)
            Sleep(120)
            if (SelectedCode = "" && WinActive("ahk_exe Cursor.exe") && LegacySyncFallback) {
                if CoreAsyncStrictMode
                    PromptExecution_LogGuard("legacy_sync_path_hit", "ExecutePrompt.cursor_second_copy")
                Send("{Esc}")
                Sleep(30)
                A_Clipboard := ""
                Send("^c")
                Sleep(45)
                t2 := PromptExecution_TryReadClipboardText()
                if (t2 != "")
                    SelectedCode := t2
                A_Clipboard := OldClipboard
            }
            CodeBlockStart := "``````"
            CodeBlockEnd := "``````"
            if (SelectedCode != "")
                FullPrompt := Prompt . "`n`n浠ヤ笅鏄€変腑鐨勪唬鐮侊細`n" . CodeBlockStart . "`n" . SelectedCode . "`n" . CodeBlockEnd
            else
                FullPrompt := Prompt
            A_Clipboard := FullPrompt
            Sleep(30)
            if !WinActive("ahk_exe Cursor.exe") {
                PromptExecution_RequestCursorFocus("execute_prompt_reactivate_1")
                Sleep(120)
            }
            Send("{Esc}")
            Sleep(60)
            Send("^l")
            Sleep(220)
            if !WinActive("ahk_exe Cursor.exe") {
                PromptExecution_RequestCursorFocus("execute_prompt_reactivate_2")
                Sleep(120)
            }
            Send("^v")
            Sleep(160)
            Send("{Enter}")
            Sleep(80)
            A_Clipboard := OldClipboard
        } else if (CursorPath != "" && FileExist(CursorPath)) {
            Run(CursorPath)
            Sleep(AISleepTime)
            A_Clipboard := Prompt
            Sleep(80)
            Send("^l")
            Sleep(160)
            Send("^v")
            Sleep(80)
            Send("{Enter}")
            Sleep(80)
            A_Clipboard := OldClipboard
        }
    } catch as e {
        MsgBox("鎵ц澶辫触: " . e.Message)
    }
}

ExecutePromptByTemplateId(TemplateID) {
    if (TemplateID = "") {
        return
    }
    ExecutePrompt("Explain", TemplateID)
}

; ===================== 鍒嗗壊浠ｇ爜鍔熻兘 =====================
SplitCode() {
    global CursorPath, AISleepTime, CapsLock2, ClipboardHistory
    global CoreAsyncStrictMode, LegacySyncFallback
    
    CapsLock2 := false  ; 娓呴櫎鏍囪锛岃〃绀轰娇鐢ㄤ簡鍔熻兘
    HideCursorPanel()
    
    try {
        if WinExist("ahk_exe Cursor.exe") {
            PromptExecution_RequestCursorFocus("split_code_open")
            Sleep(200)
            
            ; 澶嶅埗閫変腑鐨勪唬鐮?
            OldClipboard := A_Clipboard
            ; 淇濆瓨鍘熷鍓创鏉垮埌鍘嗗彶
            if (OldClipboard != "") {
                ClipboardHistory.Push(OldClipboard)
            }
            
            A_Clipboard := ""
            Send("^c")
            if (CoreAsyncStrictMode && LegacySyncFallback)
                PromptExecution_LogGuard("legacy_sync_path_hit", "SplitCode.copy_selection")
            Sleep(45)
            tSplit := PromptExecution_TryReadClipboardText()
            if (tSplit = "") {
                A_Clipboard := OldClipboard
                TrayTip(GetText("select_code_first"), GetText("tip"), "Iconi")
                return
            }
            SelectedCode := tSplit
            
            ; 鎻掑叆鍒嗛殧绗?
            Separator := "`n`n; ==================== 鍒嗗壊绾?====================`n`n"
            Send("{Right}")
            Send("{Enter}")
            A_Clipboard := Separator
            Send("^v")
            Sleep(120)
            
            ; 鎭㈠鍓创鏉?
            A_Clipboard := OldClipboard
            
            TrayTip(GetText("split_marker_inserted"), GetText("tip"), "Iconi")
            
            TrayTip(GetText("split_marker_inserted"), GetText("tip"), "Iconi")
        } else {
            if (CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                Sleep(AISleepTime)
            }
        }
    } catch as e {
        MsgBox("鍒嗗壊澶辫触: " . e.Message)
    }
}

; ===================== 鎵归噺鎿嶄綔鍔熻兘 =====================
BatchOperation() {
    global PanelVisible, CapsLock2
    
    if (!PanelVisible) {
        return
    }
    
    CapsLock2 := false  ; 娓呴櫎鏍囪锛岃〃绀轰娇鐢ㄤ簡鍔熻兘
    
    ; 鏄剧ず鎵归噺鎿嶄綔閫夋嫨鑿滃崟
    BatchMenu := Menu()
    BatchMenu.Add("鎵归噺瑙ｉ噴", (*) => ExecutePrompt("BatchExplain"))
    BatchMenu.Add("鎵归噺閲嶆瀯", (*) => ExecutePrompt("BatchRefactor"))
    BatchMenu.Add("鎵归噺浼樺寲", (*) => ExecutePrompt("BatchOptimize"))
    
    ; 鑾峰彇榧犳爣浣嶇疆鏄剧ず鑿滃崟
    MouseGetPos(&MouseX, &MouseY)
    BatchMenu.Show(MouseX, MouseY)
}

