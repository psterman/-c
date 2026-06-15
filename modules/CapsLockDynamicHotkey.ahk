#Requires AutoHotkey v2.0

; CapsLock 组合动态热键逻辑（由主脚本 #HotIf 调用）


; ===================== 动态快捷键处理函数 =====================
; 检查按键是否匹配配置的快捷键，如果匹配则执行相应操作
HandleDynamicHotkey(PressedKey, ActionType) {
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, HotkeyT, HotkeyF, HotkeyP
    global CapsLock2, PanelVisible, VoiceInputActive, CapsLock, VoiceSearchActive
    
    ; 如果使用了组合快捷键，清除显示面板的定时器（防止面板被激活）
    SetTimer(ShowPanelTimer, 0)  ; 停止ShowPanelTimer定时器
    ; 清除CapsLock2标记，防止面板被激活
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    
    ; 将按键转换为小写进行比较（ESC特殊处理）
    KeyLower := StrLower(PressedKey)
    ConfigKey := ""

    ; 截图助手优先：当截图助手打开时，Q/E/C/R/Z/F/X/Esc 统一切到截图工具栏动作
    if (HandleScreenshotEditorHotkey(ActionType)) {
        return true
    }
    
    ; 根据操作类型获取配置的快捷键
    switch ActionType {
        case "ESC": ConfigKey := StrLower(HotkeyESC)
        case "C": ConfigKey := StrLower(HotkeyC)
        case "V": ConfigKey := StrLower(HotkeyV)
        case "X": ConfigKey := StrLower(HotkeyX)
        case "Q": ConfigKey := StrLower(HotkeyQ)
        case "Z": ConfigKey := StrLower(HotkeyZ)
        case "F": ConfigKey := StrLower(HotkeyF)
        case "T": ConfigKey := StrLower(HotkeyT)
        case "P": ConfigKey := StrLower(HotkeyP)
    }
    
    ; 如果按键匹配配置的快捷键，执行操作
    ; 添加调试信息
    if (KeyLower = ConfigKey || (ActionType = "ESC" && (PressedKey = "Esc" || KeyLower = "esc"))) {
        ; 【关键修复】对于 F 键，需要先检查语音搜索面板状态，避免影响弹出菜单
        ; 如果是 F 键且语音搜索面板已显示，不隐藏快捷操作面板，避免影响菜单状态
        global VoiceSearchPanelVisible
        if (ActionType = "F") {
            ; 确保变量已初始化
            if (!IsSet(VoiceSearchPanelVisible)) {
                VoiceSearchPanelVisible := false
            }
            ; 如果语音搜索面板已显示，不隐藏快捷操作面板，避免影响菜单状态
            if (!VoiceSearchPanelVisible && PanelVisible) {
                HideCursorPanel()
            }
        } else {
            ; 其他快捷键操作都应该隐藏面板
            if (PanelVisible) {
                HideCursorPanel()
            }
        }
        
        switch ActionType {
            case "ESC":
                CapsLock2 := false
            case "C":
                ; 【关键修复】检查是否在标签切换期间，如果是则不执行复制
                global CapsLockCopyInProgress, CapsLockCopyEndTime, GuiID_ClipboardManager
                
                ; 双重检查：1. 检查是否是标签切换期间
                if (CapsLockCopyInProgress && CapsLockCopyEndTime > A_TickCount) {
                    ; 在标签切换期间，不执行复制操作
                    return true  ; 已处理（阻止复制）
                }
                
                ; 双重检查：2. 如果剪贴板管理面板已打开，额外检查是否是标签点击期间
                ; 这个检查是为了防止在点击标签时，CapsLock 键还处于按下状态导致的意外触发
                if (GuiID_ClipboardManager != 0 && CapsLockCopyInProgress && CapsLockCopyEndTime > A_TickCount) {
                    ; 在标签点击期间且剪贴板管理面板打开时，不执行复制操作
                    return true  ; 已处理（阻止复制）
                }
                
                ; 调用复制函数
                CapsLockCopy()
            case "V":
                ; CapsLock+V 已改为剪贴板时间线；合并粘贴仅 CapsLock+Shift+V
                if GetKeyState("Shift", "P") {
                    CapsLockPaste()
                } else if (FuncExists("SearchCenter_ShouldUseWebView") && SearchCenter_ShouldUseWebView()) {
                    SurfaceIntent_OpenClipboardUnified("", "clipboard_hotkey")
                } else if (FuncExists("ShowSearchCenter")) {
                    ShowSearchCenter()
                } else {
                    CapsLockPaste()
                }
            case "X":
                CapsLock2 := false
                SurfaceIntent_Open("clipboard_panel")
            case "Q":
                CapsLock2 := false
                ShowConfigGUI()
            case "Z":
                CapsLock2 := false
                if (VoiceInputActive) {
                    ; 如果正在语音输入，直接发送
                    if (CapsLock) {
                        CapsLock := false
                    }
                    StopVoiceInput()
                } else {
                    ; 如果未在语音输入，开始语音输入
                    StartVoiceInput()
                }
            case "F":
                CapsLock2 := false
                global VoiceSearchActive
                ; 【关键修复】确保变量已初始化
                if (!IsSet(VoiceSearchPanelVisible)) {
                    VoiceSearchPanelVisible := false
                }
                if (!IsSet(VoiceSearchActive)) {
                    VoiceSearchActive := false
                }
                if (VoiceSearchPanelVisible) {
                    ; 面板已显示
                    if (VoiceSearchActive) {
                        ; 正在语音输入，停止并执行搜索
                        if (CapsLock) {
                            CapsLock := false
                        }
                        StopVoiceInputInSearch()
                        ; 等待一下让内容填入输入框
                        Sleep(300)
                        ExecuteVoiceSearch()
                    } else {
                        ; 未在语音输入，切换焦点并开始语音输入
                        FocusVoiceSearchInput()
                        Sleep(200)
                        StartVoiceInputInSearch()
                    }
                } else {
                    ; 面板未显示，显示面板
                    ; 【关键修复】如果快捷操作面板正在显示，先关闭它（在 StartVoiceSearch 中处理）
                    StartVoiceSearch()
                }
            case "P":
                CapsLock2 := false
                ; CapsLock+P：提示词快捷采集（区域截图请用 CapsLock+T 智能截图菜单）
                try PromptQuickPad_OpenCaptureDraft("", true)
                catch as e {
                    TrayTip("无法打开提示词采集：`n" . e.Message, GetText("tip"), "Iconx 2")
                }
            case "T":
                CapsLock2 := false
                ; 执行截图，完成后弹出智能菜单
                try {
                    ExecuteScreenshotWithMenu()
                } catch as e {
                    TrayTip("错误", "执行截图失败: " . e.Message, "Iconx 2")
                }
        }
        return true  ; 已处理
    }
    return false  ; 未匹配，需要发送原始按键
}
