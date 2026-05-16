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

; ===================== 执行提示词函数 =====================
ExecutePrompt(Type, TemplateID := "") {
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize, CursorPath, AISleepTime, IsCommandMode, CapsLock2, ClipboardHistory
    global DefaultTemplateIDs, PromptTemplates
    global CoreAsyncStrictMode, LegacySyncFallback
    
    ; 清除标记，表示使用了功能
    CapsLock2 := false
    ; 标记命令模式结束，避免 CapsLock 释放后再次隐藏面板
    IsCommandMode := false
    
    HideCursorPanel()
    
    ; 根据类型选择提示词（优先使用模板系统）
    Prompt := ""
    
    ; 如果提供了TemplateID，直接使用模板
    if (TemplateID != "") {
        Template := GetTemplateByID(TemplateID)
        if (Template) {
            Prompt := Template.Content
        }
    }
    
    ; 如果没有TemplateID或模板未找到，使用默认模板或传统方式
    if (Prompt = "") {
        ; 尝试从默认模板映射获取
        if (DefaultTemplateIDs.Has(Type)) {
            TemplateID := DefaultTemplateIDs[Type]
            Template := GetTemplateByID(TemplateID)
            if (Template) {
                Prompt := Template.Content
            }
        }
        
        ; 如果模板系统未找到，回退到传统方式
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
    
    ; 在切换窗口之前，先保存当前剪贴板内容并尝试复制选中文本
    ; 这样可以确保即使切换窗口后失去选中状态，也能获取到之前选中的文本
    ; 在切换窗口之前，先保存当前剪贴板内容
    OldClipboard := A_Clipboard
    
    ; 1. 保存当前剪贴板到历史记录（解决污染问题，防止用户数据丢失）
    if (OldClipboard != "") {
        ClipboardHistory.Push(OldClipboard)
    }

    ; Core async strict path: do not block UI thread on initial selection copy.
    doneCb := Func("PromptExecution_OnInitialCopyDone").Bind(Prompt, OldClipboard, CursorPath, AISleepTime)
    PromptExecution_BeginCopySelectionAsync(OldClipboard, doneCb)
    return
    /*
    SelectedCode := ""
    
    ; 尝试从当前活动窗口复制选中文本
    if (CoreAsyncStrictMode && LegacySyncFallback)
        PromptExecution_LogGuard("legacy_sync_path_hit", "ExecutePrompt.copy_selection")
    if WinActive("ahk_exe Cursor.exe") {
        Send("{Esc}")
        Sleep(50)
        A_Clipboard := "" ; 清空剪贴板以通过 ClipWait 检测
        Send("^c")
        if ClipWait(0.18) { ; 缩短阻塞窗口，失败走后续兜底
            SelectedCode := A_Clipboard
        }
        ; 恢复剪贴板，避免影响后续判断
        A_Clipboard := OldClipboard
    } else {
        CurrentActiveWindow := WinGetID("A")
        A_Clipboard := ""
        Send("^c")
        if ClipWait(0.18) {
            SelectedCode := A_Clipboard
        }
        A_Clipboard := OldClipboard
    }
    
    ; 激活 Cursor 窗口
    try {
        if WinExist("ahk_exe Cursor.exe") {
            PromptExecution_RequestCursorFocus("execute_prompt_open")
            WinWaitActive("ahk_exe Cursor.exe", , 1)
            Sleep(200)
            
            ; 如果之前没有获取到选中文本，再次尝试在 Cursor 内复制
            if (SelectedCode = "" && WinActive("ahk_exe Cursor.exe")) {
                Send("{Esc}")
                Sleep(50)
                A_Clipboard := ""
                Send("^c")
                if ClipWait(0.18) {
                    SelectedCode := A_Clipboard
                }
                A_Clipboard := OldClipboard
            }
            
            ; 构建完整的提示词
            CodeBlockStart := "``````"
            CodeBlockEnd := "``````"
            if (SelectedCode != "") {
                FullPrompt := Prompt . "`n`n以下是选中的代码：`n" . CodeBlockStart . "`n" . SelectedCode . "`n" . CodeBlockEnd
            } else {
                FullPrompt := Prompt
            }
            
            ; 复制完整提示词到剪贴板
            A_Clipboard := FullPrompt
            if !ClipWait(0.25) {
                Sleep(100)
            }
            
            if !WinActive("ahk_exe Cursor.exe") {
                PromptExecution_RequestCursorFocus("execute_prompt_reactivate_1")
                Sleep(200)
            }
            
            Send("{Esc}")
            Sleep(100)
            
            ; 打开聊天面板
            Send("^l")
            Sleep(400)
            
            if !WinActive("ahk_exe Cursor.exe") {
                PromptExecution_RequestCursorFocus("execute_prompt_reactivate_2")
                Sleep(200)
            }
            
            ; 粘贴提示词
            Send("^v")
            Sleep(300) ; 等待粘贴完成
            
            ; 提交
            Send("{Enter}")
            
            ; 2. 恢复用户的原始剪贴板（解决污染问题）
            Sleep(200)
            A_Clipboard := OldClipboard
        } else {

            ; 如果 Cursor 未运行，尝试启动
            if (CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                Sleep(AISleepTime)
                
                ; 构建提示词（如果有选中文本）
                if (SelectedCode != "" && SelectedCode != OldClipboard && StrLen(SelectedCode) > 0) {
                    CodeBlockStart := "``````"
                    CodeBlockEnd := "``````"
                    FullPrompt := Prompt . "`n`n以下是选中的代码：`n" . CodeBlockStart . "`n" . SelectedCode . "`n" . CodeBlockEnd
                } else {
                    FullPrompt := Prompt
                }
                
                ; 复制提示词到剪贴板
                A_Clipboard := FullPrompt
                Sleep(100)
                Send("^l")
                Sleep(200)
                Send("^v")
                Sleep(100)
                Send("{Enter}")
            }
        }
    } catch as e {
        MsgBox("执行失败: " . e.Message)
    }
}

; 虚拟键盘 / 外部 vkExec：按模板 ID 走与 Explain 相同的 Cursor 发送流程
ExecutePrompt_Continue(Prompt, SelectedCode, OldClipboard, CursorPath, AISleepTime) {
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
                if ClipWait(0.12)
                    SelectedCode := A_Clipboard
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
    */
}

PromptExecution_OnInitialCopyDone(Prompt, OldClipboard, CursorPath, AISleepTime, SelectedCode) {
    Func("PromptExecution_ContinueAsync").Call(Prompt, SelectedCode, OldClipboard, CursorPath, AISleepTime)
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
                if ClipWait(0.12)
                    SelectedCode := A_Clipboard
                A_Clipboard := OldClipboard
            }
            CodeBlockStart := "``````"
            CodeBlockEnd := "``````"
            if (SelectedCode != "")
                FullPrompt := Prompt . "`n`n以下是选中的代码：`n" . CodeBlockStart . "`n" . SelectedCode . "`n" . CodeBlockEnd
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
        MsgBox("执行失败: " . e.Message)
    }
}

ExecutePromptByTemplateId(TemplateID) {
    if (TemplateID = "") {
        return
    }
    ExecutePrompt("Explain", TemplateID)
}

; ===================== 分割代码功能 =====================
SplitCode() {
    global CursorPath, AISleepTime, CapsLock2, ClipboardHistory
    global CoreAsyncStrictMode, LegacySyncFallback
    
    CapsLock2 := false  ; 清除标记，表示使用了功能
    HideCursorPanel()
    
    try {
        if WinExist("ahk_exe Cursor.exe") {
            PromptExecution_RequestCursorFocus("split_code_open")
            Sleep(200)
            
            ; 复制选中的代码
            OldClipboard := A_Clipboard
            ; 保存原始剪贴板到历史
            if (OldClipboard != "") {
                ClipboardHistory.Push(OldClipboard)
            }
            
            A_Clipboard := ""
            Send("^c")
            if (CoreAsyncStrictMode && LegacySyncFallback)
                PromptExecution_LogGuard("legacy_sync_path_hit", "SplitCode.copy_selection")
            if !ClipWait(0.18) {
                A_Clipboard := OldClipboard
                TrayTip(GetText("select_code_first"), GetText("tip"), "Iconi")
                return
            }
            SelectedCode := A_Clipboard
            
            ; 插入分隔符
            Separator := "`n`n; ==================== 分割线 ====================`n`n"
            Send("{Right}")
            Send("{Enter}")
            A_Clipboard := Separator
            if ClipWait(0.18) {
                Send("^v")
                Sleep(200)
            }
            
            ; 恢复剪贴板
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
        MsgBox("分割失败: " . e.Message)
    }
}

; ===================== 批量操作功能 =====================
BatchOperation() {
    global PanelVisible, CapsLock2
    
    if (!PanelVisible) {
        return
    }
    
    CapsLock2 := false  ; 清除标记，表示使用了功能
    
    ; 显示批量操作选择菜单
    BatchMenu := Menu()
    BatchMenu.Add("批量解释", (*) => ExecutePrompt("BatchExplain"))
    BatchMenu.Add("批量重构", (*) => ExecutePrompt("BatchRefactor"))
    BatchMenu.Add("批量优化", (*) => ExecutePrompt("BatchOptimize"))
    
    ; 获取鼠标位置显示菜单
    MouseGetPos(&MouseX, &MouseY)
    BatchMenu.Show(MouseX, MouseY)
}
