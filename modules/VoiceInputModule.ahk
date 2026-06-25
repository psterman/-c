; VoiceInputModule.ahk — 语音输入 / 语音搜索（由 CursorHelper 中枢 #Include）
; 依赖宿主：GetText、FormatText、HoverBtn、OnWindowSize、RestoreWindowPosition、GetWindowScreenIndex、
; GetScreenInfo、GetPanelPosition、HideCursorPanel、QueueWindowPositionSave、FlushPendingWindowPositions、
; ArrayContainsValue、ConfigFile、CursorPath、AISleepTime、PanelVisible、UI_Colors、ThemeMode、Language、
; CLI 副作用见 VoiceInputCliEffects.ahk（LaunchSelectedCLIAgents 经 FSM 转发）。

; 宿主在 CursorPanelController.ahk 中提供 HideCursorPanel；用 Func 调用避免单文件静态检查误报未赋值局部变量
VoiceInput_HideCursorPanelIfNeeded() {
    try {
        fn := Func("HideCursorPanel")
        if fn
            fn.Call()
    } catch as _e {
        try {
            Func("NmerCatch").Call(A_ThisFunc, _e)
        } catch {
        }
    }
}

VoiceButtonAction(*) {
    return
}

; CapsLock+Z 语音输入已移除；保留 CapsLock+F 语音搜索
StartVoiceInput() {
    return
}

StopVoiceInput() {
    return
}

PauseVoiceInput() {
    return
}

ResumeVoiceInput() {
    return
}

; --- legacy implementation below (voice search CapsLock+F still uses this file) ---

; ===================== 保存语音输入面板窗口位置 =====================
SaveVoiceInputPanelPosition() {
    global GuiID_VoiceInputPanel
    try {
        ; 检查窗口是否还存在
        if (!GuiID_VoiceInputPanel || GuiID_VoiceInputPanel = 0) {
            ; 窗口已关闭，停止定时器并立即保存所有待保存的位置
            SetTimer(() => SaveVoiceInputPanelPosition(), 0)
            FlushPendingWindowPositions()
            return
        }
        
        ; 获取窗口位置和大小
        WinGetPos(&WinX, &WinY, &WinW, &WinH, GuiID_VoiceInputPanel.Hwnd)
        WindowName := GetText("voice_input_active")
        ; 使用延迟保存，统一管理
        QueueWindowPositionSave(WindowName, WinX, WinY, WinW, WinH)
    } catch as err {
        ; 忽略错误（窗口可能已关闭）
    }
}

; ===================== 保存语音搜索输入窗口位置 =====================
SaveVoiceInputPosition() {
    global GuiID_VoiceInput
    try {
        ; 检查窗口是否还存在
        if (!GuiID_VoiceInput || GuiID_VoiceInput = 0) {
            ; 窗口已关闭，停止定时器并立即保存所有待保存的位置
            SetTimer(() => SaveVoiceInputPosition(), 0)
            FlushPendingWindowPositions()
            return
        }
        
        ; 获取窗口位置和大小
        WinGetPos(&WinX, &WinY, &WinW, &WinH, GuiID_VoiceInput.Hwnd)
        WindowName := GetText("voice_search_title")
        ; 使用延迟保存，统一管理
        QueueWindowPositionSave(WindowName, WinX, WinY, WinW, WinH)
    } catch as err {
        ; 忽略错误（窗口可能已关闭）
    }
}
; ===================== 语音输入功能 =====================

; 检测输入法类型（改进版：多方法检测）
DetectInputMethod() {
    ; 检测百度输入法进程（常见进程名）
    BaiduProcesses := ["BaiduIME.exe", "BaiduPinyin.exe", "bdpinyin.exe", "BaiduInput.exe", "BaiduPinyinService.exe"]
    
    ; 检测讯飞输入法进程（常见进程名）
    ; 讯飞输入法的主要进程：XunfeiIME.exe, XunfeiInput.exe, XunfeiPinyin.exe
    XunfeiProcesses := ["XunfeiIME.exe", "XunfeiInput.exe", "XunfeiPinyin.exe", "XunfeiCloud.exe", "Xunfei.exe"]
    
    ; 方法1：通过进程检测（优先检测讯飞，因为进程名更独特）
    for Index, ProcessName in XunfeiProcesses {
        try {
            if (ProcessExist(ProcessName)) {
                return "xunfei"
            }
        }
    }
    
    ; 检测百度输入法
    for Index, ProcessName in BaiduProcesses {
        try {
            if (ProcessExist(ProcessName)) {
                return "baidu"
            }
        }
    }
    
    ; 方法2：通过窗口类名检测（更准确）
    ; 尝试检测当前活动的输入法窗口
    try {
        ; 检测讯飞输入法窗口（常见的窗口类名）
        if WinExist("ahk_class XunfeiIME") || WinExist("ahk_class XunfeiInput") || WinExist("ahk_class XunfeiPinyin") {
            return "xunfei"
        }
        ; 检测百度输入法窗口
        if WinExist("ahk_class BaiduIME") || WinExist("ahk_class BaiduPinyin") || WinExist("ahk_class BaiduInput") {
            return "baidu"
        }
    }
    
    ; 方法3：通过注册表检测（备用方案）
    try {
        ; 检测讯飞输入法注册表项
        try {
            RegRead("HKEY_CURRENT_USER\Software\Xunfei", "", "")
            return "xunfei"
        }
        ; 检测百度输入法注册表项
        try {
            RegRead("HKEY_CURRENT_USER\Software\Baidu", "", "")
            return "baidu"
        }
    }
    
    ; 如果都检测不到，默认尝试百度方案（因为百度更常见）
    ; 但提示用户可能需要手动选择
    return "baidu"
}

; 显示语音输入面板（屏幕中心；CapsLock+Z 已禁用，仅供语音搜索复用部分 UI）
ShowVoiceInputPanel() {
    global GuiID_VoiceInputPanel, VoiceInputActive, VoiceInputScreenIndex, UI_Colors, VoiceInputPaused
    global VoiceInputSendBtn, VoiceInputPauseBtn, VoiceInputAnimationText, VoiceInputStatusText
    
    ; 【关键修复】确保所有必需的变量都已初始化
    if (!IsSet(UI_Colors) || !IsObject(UI_Colors)) {
        ; 如果 UI_Colors 未初始化，使用默认暗色主题
        global UI_Colors_Dark
        if (!IsSet(UI_Colors_Dark)) {
            ; 使用 html.to.design 风格配色作为默认值
            UI_Colors_Dark := {Background: "0a0a0a", Text: "f5f5f5", BtnBg: "1a1a1a", BtnHover: "2a2a2a", BtnPrimary: "e67e22", BtnPrimaryHover: "d35400"}
        }
        UI_Colors := UI_Colors_Dark
    }
    
    if (!IsSet(VoiceInputScreenIndex) || VoiceInputScreenIndex = "") {
        VoiceInputScreenIndex := 1
    }
    
    if (!IsSet(VoiceInputPaused)) {
        VoiceInputPaused := false
    }
    
    if (GuiID_VoiceInputPanel != 0) {
        try {
            GuiID_VoiceInputPanel.Destroy()
        }
        GuiID_VoiceInputPanel := 0
    }
    
    GuiID_VoiceInputPanel := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale +Resize -MaximizeBox")
    GuiID_VoiceInputPanel.BackColor := UI_Colors.Background
    
    PanelWidth := 280
    PanelHeight := 120
    
    ; 添加窗口大小改变和移动事件处理
    GuiID_VoiceInputPanel.OnEvent("Size", OnWindowSize)
    ; 注意：AutoHotkey v2 不支持 Move 事件，使用定时器定期保存位置
    ; GuiID_VoiceInputPanel.OnEvent("Move", OnWindowMove)
    SetTimer(() => SaveVoiceInputPanelPosition(), 500)
    
    ; 状态文本
    YPos := 15
    VoiceInputStatusText := GuiID_VoiceInputPanel.Add("Text", "x20 y" . YPos . " w240 h25 c" . UI_Colors.Text, GetText("voice_input_active"))
    VoiceInputStatusText.SetFont("s12 Bold", "Segoe UI")
    
    ; 动画文本
    YPos += 30
    VoiceInputAnimationText := GuiID_VoiceInputPanel.Add("Text", "x20 y" . YPos . " w240 h25 Center c00FF00", "● ● ●")
    VoiceInputAnimationText.SetFont("s14", "Segoe UI")
    
    ; 按钮区域
    YPos += 35
    ButtonWidth := 100
    ButtonHeight := 30
    ButtonSpacing := 20
    
    ; 发送按钮
    SendBtnX := 20
    VoiceInputSendBtn := GuiID_VoiceInputPanel.Add("Text", "x" . SendBtnX . " y" . YPos . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary . " vVoiceInputSendBtn", GetText("send_to_cursor"))
    VoiceInputSendBtn.SetFont("s10 Bold", "Segoe UI")
    VoiceInputSendBtn.OnEvent("Click", FinishAndSendVoiceInput)
    HoverBtn(VoiceInputSendBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
    
    ; 暂停/继续按钮
    PauseBtnX := SendBtnX + ButtonWidth + ButtonSpacing
    PauseBtnText := VoiceInputPaused ? GetText("resume") : GetText("pause")
    VoiceInputPauseBtn := GuiID_VoiceInputPanel.Add("Text", "x" . PauseBtnX . " y" . YPos . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnBg . " vVoiceInputPauseBtn", PauseBtnText)
    VoiceInputPauseBtn.SetFont("s10", "Segoe UI")
    VoiceInputPauseBtn.OnEvent("Click", ToggleVoiceInputPause)
    HoverBtn(VoiceInputPauseBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; 关闭按钮（右上角）
    CloseBtnSize := 25
    CloseBtnX := PanelWidth - CloseBtnSize - 5
    CloseBtnY := 5
    VoiceInputCloseBtn := GuiID_VoiceInputPanel.Add("Text", "x" . CloseBtnX . " y" . CloseBtnY . " w" . CloseBtnSize . " h" . CloseBtnSize . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnBg . " vVoiceInputCloseBtn", "✕")
    VoiceInputCloseBtn.SetFont("s12", "Segoe UI")
    VoiceInputCloseBtn.OnEvent("Click", (*) => StopVoiceInput())
    HoverBtn(VoiceInputCloseBtn, UI_Colors.BtnBg, "e81123")
    
    ; 启动动画定时器
    SetTimer(UpdateVoiceAnimation, 500)
    
    ; 恢复窗口位置和大小
    WindowName := "VoiceInputPanel"
    RestoredPos := RestoreWindowPosition(WindowName, PanelWidth, PanelHeight)
    if (RestoredPos.X = -1 || RestoredPos.Y = -1) {
        ; 获取 Cursor 窗口所在的屏幕索引，并在该屏幕中心显示面板
        try {
            CursorScreenIndex := GetWindowScreenIndex("ahk_exe Cursor.exe")
            ScreenInfo := GetScreenInfo(CursorScreenIndex)
            ; 使用 GetPanelPosition 函数计算中心位置
            Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "Center")
            RestoredPos.X := Pos.X
            RestoredPos.Y := Pos.Y
        } catch as err {
            ; 如果出错，使用默认屏幕的中心位置
            ScreenInfo := GetScreenInfo(1)
            Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "Center")
            RestoredPos.X := Pos.X
            RestoredPos.Y := Pos.Y
        }
    }
    
    ; 添加 Escape 键关闭命令
    GuiID_VoiceInputPanel.OnEvent("Escape", (*) => StopVoiceInput())
    
    GuiID_VoiceInputPanel.Show("w" . RestoredPos.Width . " h" . RestoredPos.Height . " x" . RestoredPos.X . " y" . RestoredPos.Y . " NoActivate")
    WinSetAlwaysOnTop(1, GuiID_VoiceInputPanel.Hwnd)
}

; 更新语音输入面板状态
UpdateVoiceInputPanelState() {
    global VoiceInputPaused, VoiceInputPauseBtn, VoiceInputStatusText
    
    if (!VoiceInputPauseBtn || !VoiceInputStatusText) {
        return
    }
    
    try {
        ; 更新暂停按钮文本
        PauseBtnText := VoiceInputPaused ? GetText("resume") : GetText("pause")
        VoiceInputPauseBtn.Text := PauseBtnText
        
        ; 更新状态文本
        if (VoiceInputPaused) {
            VoiceInputStatusText.Text := GetText("voice_input_paused")
        } else {
            VoiceInputStatusText.Text := GetText("voice_input_active")
        }
    } catch as err {
        ; 忽略错误
    }
}

; 隐藏语音输入面板（仅 UI；状态由 FSM + VoiceInput_SyncLegacyFlags 维护）
HideVoiceInputPanel() {
    global GuiID_VoiceInputPanel, VoiceInputAnimationText, VoiceInputStatusText, VoiceInputSendBtn, VoiceInputPauseBtn
    
    SetTimer(UpdateVoiceAnimation, 0)
    
    if (GuiID_VoiceInputPanel != 0) {
        try {
            GuiID_VoiceInputPanel.Destroy()
        }
        GuiID_VoiceInputPanel := 0
    }
    VoiceInputAnimationText := 0
    VoiceInputStatusText := 0
    VoiceInputSendBtn := 0
    VoiceInputPauseBtn := 0
    if FuncExists("VoiceInput_SyncLegacyFlags")
        VoiceInput_SyncLegacyFlags()
}

; 切换暂停/继续
ToggleVoiceInputPause(*) {
    global VoiceInputPaused
    
    if (VoiceInputPaused) {
        ResumeVoiceInput()
    } else {
        PauseVoiceInput()
    }
}

; 完成并发送语音输入到 Cursor
FinishAndSendVoiceInput(*) {
    StopVoiceInput()
}

; 更新语音输入暂停状态
UpdateVoiceInputPausedState(IsPaused) {
    ; 使用新的面板状态更新函数
    UpdateVoiceInputPanelState()
}

; 更新语音输入动画
UpdateVoiceAnimation(*) {
    global VoiceInputActive, VoiceAnimationText, VoiceInputPaused, GuiID_VoiceInputPanel
    
    ; 【关键修复】检查面板是否存在且变量已初始化
    if (!VoiceInputActive || !GuiID_VoiceInputPanel || GuiID_VoiceInputPanel = 0) {
        SetTimer(UpdateVoiceAnimation, 0)
        return
    }
    
    if (!IsSet(VoiceAnimationText) || !VoiceAnimationText || VoiceInputPaused) {
        ; 如果暂停或动画文本未初始化，不更新动画
        return
    }
    
    try {
        static AnimationState := 0
        AnimationState := Mod(AnimationState + 1, 4)
        
        switch AnimationState {
            case 0:
                VoiceAnimationText.Text := "● ○ ○"
            case 1:
                VoiceAnimationText.Text := "○ ● ○"
            case 2:
                VoiceAnimationText.Text := "○ ○ ●"
            case 3:
                VoiceAnimationText.Text := "● ● ●"
        }
    } catch as e {
        ; 如果出错，停止定时器
        SetTimer(UpdateVoiceAnimation, 0)
    }
}


; 显示语音输入操作选择界面（发送到Cursor或搜索）
ShowVoiceInputActionSelection(Content) {
    global GuiID_VoiceInput, VoiceInputScreenIndex, UI_Colors, VoiceSearchSelecting, VoiceSearchEngineButtons
    
    VoiceSearchSelecting := true
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
        GuiID_VoiceInput := 0
    }
    
    GuiID_VoiceInput := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    GuiID_VoiceInput.BackColor := UI_Colors.Background
    GuiID_VoiceInput.SetFont("s12 c" . UI_Colors.Text . " Bold", "Segoe UI")
    
    PanelWidth := 500
    ; 计算所需高度：标题(50) + 内容标签(25) + 内容框(60) + 自动加载开关(35) + 操作标签(30) + 操作按钮(45) + 引擎标签(30) + 按钮区域 + 取消按钮(45) + 边距(20)
    ButtonsRows := Ceil(8 / 4)  ; 每行4个按钮，共8个搜索引擎
    ButtonsAreaHeight := ButtonsRows * 45  ; 每行45px（按钮35px + 间距10px）
    PanelHeight := 50 + 25 + 60 + 35 + 30 + 45 + 30 + ButtonsAreaHeight + 45 + 20
    
    ; 标题
    TitleText := GuiID_VoiceInput.Add("Text", "x0 y15 w500 h30 Center c" . UI_Colors.Text, GetText("select_action"))
    TitleText.SetFont("s14 Bold", "Segoe UI")
    
    ; 显示输入内容
    YPos := 55
    LabelText := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h20 c" . UI_Colors.TextDim, GetText("voice_input_content"))
    LabelText.SetFont("s10", "Segoe UI")
    
    YPos += 25
    ContentEdit := GuiID_VoiceInput.Add("Edit", "x20 y" . YPos . " w460 h60 vVoiceInputContentEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " ReadOnly Multi", Content)
    ContentEdit.SetFont("s11", "Segoe UI")
    
    ; 自动加载选中文本开关
    YPos += 70
    global AutoLoadSelectedText, VoiceInputAutoLoadSwitch
    AutoLoadLabel := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w200 h25 c" . UI_Colors.TextDim, GetText("auto_load_selected_text"))
    AutoLoadLabel.SetFont("s10", "Segoe UI")
    ; 创建开关按钮（使用文本按钮模拟开关）
    SwitchText := AutoLoadSelectedText ? GetText("switch_on") : GetText("switch_off")
    SwitchBg := AutoLoadSelectedText ? UI_Colors.BtnHover : UI_Colors.BtnBg
    ; 按钮文字颜色：根据主题调整
    global ThemeMode
    SwitchTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    VoiceInputAutoLoadSwitch := GuiID_VoiceInput.Add("Text", "x220 y" . YPos . " w120 h25 Center 0x200 c" . SwitchTextColor . " Background" . SwitchBg . " vVoiceInputAutoLoadSwitch", SwitchText)
    VoiceInputAutoLoadSwitch.SetFont("s10", "Segoe UI")
    VoiceInputAutoLoadSwitch.OnEvent("Click", ToggleAutoLoadSelectedTextForVoiceInput)
    HoverBtn(VoiceInputAutoLoadSwitch, SwitchBg, UI_Colors.BtnHover)
    
    ; 操作选择
    YPos += 35
    LabelAction := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h20 c" . UI_Colors.TextDim, GetText("select_action") . ":")
    LabelAction.SetFont("s10", "Segoe UI")
    
    ; 搜索引擎按钮标签（先创建，以便后续引用）
    YPos += 50
    LabelEngine := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h20 c" . UI_Colors.TextDim . " vEngineLabel", GetText("select_search_engine"))
    LabelEngine.SetFont("s10", "Segoe UI")
    LabelEngine.Visible := false
    
    ; 操作按钮（在操作标签下方）
    YPos := 55 + 25 + 60 + 70 + 35 + 20 + 10  ; 重新计算YPos位置（标题+标签+输入框+开关间距+开关+操作标签间距+操作标签高度+按钮间距）
    ; 发送到Cursor按钮
    ; 按钮文字颜色：根据主题调整
    global ThemeMode
    ActionBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    SendToCursorBtn := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w220 h35 Center 0x200 c" . ActionBtnTextColor . " Background" . UI_Colors.BtnBg . " vSendToCursorBtn", GetText("send_to_cursor"))
    SendToCursorBtn.SetFont("s11", "Segoe UI")
    SendToCursorBtn.OnEvent("Click", CreateSendToCursorHandler(Content))
    HoverBtn(SendToCursorBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; 搜索按钮（保存引用以便后续访问）
    global VoiceInputSendToCursorBtn := SendToCursorBtn
    global VoiceInputSearchBtn
    SearchBtn := GuiID_VoiceInput.Add("Text", "x260 y" . YPos . " w220 h35 Center 0x200 c" . ActionBtnTextColor . " Background" . UI_Colors.BtnBg . " vSearchBtn", GetText("voice_search_button"))
    SearchBtn.SetFont("s11", "Segoe UI")
    SearchBtn.OnEvent("Click", CreateShowSearchEnginesHandler(Content, SendToCursorBtn, SearchBtn, LabelEngine))
    VoiceInputSearchBtn := SearchBtn
    HoverBtn(SearchBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; 搜索引擎按钮位置（从LabelEngine下方开始）
    YPos := 55 + 25 + 60 + 70 + 35 + 20 + 10 + 35 + 50  ; 操作按钮下方（标题+标签+输入框+开关间距+开关+操作标签间距+操作标签+按钮间距+操作按钮+引擎标签间距）
    ; 搜索引擎列表
    global VoiceSearchCurrentCategory
    SearchEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
    
    VoiceSearchEngineButtons := []
    ButtonWidth := 110
    ButtonHeight := 35
    ButtonSpacing := 10
    StartX := 20
    ButtonsPerRow := 4
    
    for Index, Engine in SearchEngines {
        ; 【修复】添加安全检查，防止访问无效对象属性
        if (!IsObject(Engine) || !Engine.HasProp("Value") || !Engine.HasProp("Name")) {
            continue  ; 跳过无效的引擎对象
        }
        
        Row := Floor((Index - 1) / ButtonsPerRow)
        Col := Mod((Index - 1), ButtonsPerRow)
        BtnX := StartX + Col * (ButtonWidth + ButtonSpacing)
        BtnY := YPos + Row * (ButtonHeight + ButtonSpacing)
        
        ; 创建按钮（初始隐藏）
        ; 按钮文字颜色：根据主题调整
        global ThemeMode
        EngineBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
        Btn := GuiID_VoiceInput.Add("Text", "x" . BtnX . " y" . BtnY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . EngineBtnTextColor . " Background" . UI_Colors.BtnBg . " vSearchEngineBtn" . Index, Engine.Name)
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", CreateSearchEngineClickHandler(Content, Engine.Value))
        Btn.Visible := false
        HoverBtn(Btn, UI_Colors.BtnBg, UI_Colors.BtnHover)
        VoiceSearchEngineButtons.Push(Btn)
    }
    
    ; 取消按钮
    CancelBtnY := YPos + (Floor((SearchEngines.Length - 1) / ButtonsPerRow) + 1) * (ButtonHeight + ButtonSpacing) + 10
    ; 取消按钮颜色：根据主题调整
    global ThemeMode
    CancelBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    CancelBtnBg := (ThemeMode = "light") ? UI_Colors.BtnBg : "666666"
    CancelBtn := GuiID_VoiceInput.Add("Text", "x" . (PanelWidth // 2 - 60) . " y" . CancelBtnY . " w120 h35 Center 0x200 c" . CancelBtnTextColor . " Background" . CancelBtnBg . " vCancelBtn", GetText("cancel"))
    CancelBtn.SetFont("s11", "Segoe UI")
    CancelBtn.OnEvent("Click", CancelVoiceInputActionSelection)
    HoverBtn(CancelBtn, "666666", "777777")
    
    ScreenInfo := GetScreenInfo(VoiceInputScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "center")
    GuiID_VoiceInput.Show("w" . PanelWidth . " h" . PanelHeight . " x" . Pos.X . " y" . Pos.Y . " NoActivate")
    WinSetAlwaysOnTop(1, GuiID_VoiceInput.Hwnd)
    
    ; 标记界面已显示
    global VoiceInputActionSelectionVisible
    VoiceInputActionSelectionVisible := true
    
    ; 首先明确停止监听（无论之前状态如何）
    SetTimer(MonitorSelectedTextForVoiceInput, 0)
    
    ; 如果自动加载开关已开启，启动监听；否则确保监听已停止
    if (AutoLoadSelectedText) {
        SetTimer(MonitorSelectedTextForVoiceInput, 200)  ; 每200ms检查一次
    } else {
        ; 明确停止监听，确保不会自动加载
        SetTimer(MonitorSelectedTextForVoiceInput, 0)
    }
}

; 创建发送到Cursor处理函数
CreateSendToCursorHandler(Content) {
    SendToCursorHandler(*) {
        global VoiceSearchSelecting
        VoiceSearchSelecting := false
        HideVoiceInputActionSelection()
        SendVoiceInputToCursor(Content)
    }
    return SendToCursorHandler
}

; 创建显示搜索引擎处理函数
CreateShowSearchEnginesHandler(Content, SendToCursorBtn, SearchBtn, EngineLabel) {
    ShowSearchEnginesHandler(*) {
        global VoiceSearchEngineButtons
        try {
            ; 隐藏操作按钮
            if (SendToCursorBtn) {
                SendToCursorBtn.Visible := false
            }
            if (SearchBtn) {
                SearchBtn.Visible := false
            }
            if (EngineLabel) {
                EngineLabel.Visible := true
            }
            
            ; 显示搜索引擎按钮
            if (IsSet(VoiceSearchEngineButtons) && VoiceSearchEngineButtons.Length > 0) {
                Loop VoiceSearchEngineButtons.Length {
                    Index := A_Index
                    Btn := VoiceSearchEngineButtons[Index]
                    if (Btn) {
                        ; 检查是否是新的按钮结构（对象）还是旧的（直接控件）
                        if (IsObject(Btn) && Btn.Bg) {
                            ; 新结构：显示背景、图标和文字
                            if (Btn.Bg) {
                                Btn.Bg.Visible := true
                            }
                            if (Btn.Icon) {
                                Btn.Icon.Visible := true
                            }
                            if (Btn.Text) {
                                Btn.Text.Visible := true
                            }
                        } else {
                            ; 旧结构：直接显示控件
                            Btn.Visible := true
                        }
                    }
                }
            }
        } catch as err {
            ; 如果出错，直接显示搜索引擎选择界面
            HideVoiceInputActionSelection()
            ShowSearchEngineSelection(Content)
        }
    }
    return ShowSearchEnginesHandler
}

; 取消语音输入操作选择
CancelVoiceInputActionSelection(*) {
    global VoiceSearchSelecting
    VoiceSearchSelecting := false
    HideVoiceInputActionSelection()
}

; 隐藏语音输入操作选择界面
HideVoiceInputActionSelection() {
    global GuiID_VoiceInput, VoiceInputActionSelectionVisible
    
    ; 停止监听选中文本
    SetTimer(MonitorSelectedTextForVoiceInput, 0)
    
    ; 标记界面已隐藏
    VoiceInputActionSelectionVisible := false
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
        GuiID_VoiceInput := 0
    }
}

; 发送语音输入内容到 Cursor（副作用在 effect 层）
SendVoiceInputToCursor(Content) {
    if FuncExists("VoiceInputEffect_SendToCursor")
        VoiceInputEffect_SendToCursor(Content)
}


; ===================== 语音搜索功能 =====================
; 辅助函数：检查数组是否包含某个值
ArrayContainsValue(Arr, Value) {
    ; 【修复】添加安全检查，防止 "Item has no value" 错误
    if (!IsSet(Arr) || !IsObject(Arr) || Arr.Length = 0) {
        return 0
    }
    try {
        for Index, Item in Arr {
            ; 【关键修复】检查 Item 是否有值，防止 "Item has no value" 错误
            try {
                ; 先检查 Item 是否有效，然后再比较
                if (IsSet(Item) && Item = Value) {
                    return Index
                }
            } catch as err {
                ; 如果 Item 没有值或无法比较，跳过该项
                ; 继续下一次循环
            }
        }
    } catch as err {
        return 0
    }
    return 0
}

; 开始语音搜索（经 FSM + effect）
StartVoiceSearch() {
    global VoiceSearchPanelVisible
    if (!IsSet(VoiceSearchPanelVisible))
        VoiceSearchPanelVisible := false
    if (VoiceSearchPanelVisible && FuncExists("VoiceInput_IsSearchFsmState") && VoiceInput_IsSearchFsmState()) {
        FocusVoiceSearchInput()
        if (VoiceFSM_State() = "search_listening")
            VoiceFSM_Dispatch("search_listen_start")
        return
    }
    if (VoiceFSM_State() != "idle" && !(FuncExists("VoiceInput_IsSearchFsmState") && VoiceInput_IsSearchFsmState()))
        VoiceFSM_Dispatch("search_stop")
    VoiceFSM_Dispatch("search_open")
}

; 获取所有搜索引擎（带分类信息）
GetAllSearchEngines() {
    ; 定义所有搜索引擎，每个引擎包含分类信息
    AllEngines := [
        ; AI类
        {Name: GetText("search_engine_deepseek"), Value: "deepseek", Category: "ai"},
        {Name: GetText("search_engine_yuanbao"), Value: "yuanbao", Category: "ai"},
        {Name: GetText("search_engine_doubao"), Value: "doubao", Category: "ai"},
        {Name: GetText("search_engine_zhipu"), Value: "zhipu", Category: "ai"},
        {Name: GetText("search_engine_mita"), Value: "mita", Category: "ai"},
        {Name: GetText("search_engine_wenxin"), Value: "wenxin", Category: "ai"},
        {Name: GetText("search_engine_qianwen"), Value: "qianwen", Category: "ai"},
        {Name: GetText("search_engine_kimi"), Value: "kimi", Category: "ai"},
        {Name: GetText("search_engine_perplexity"), Value: "perplexity", Category: "ai"},
        {Name: GetText("search_engine_copilot"), Value: "copilot", Category: "ai"},
        {Name: GetText("search_engine_chatgpt"), Value: "chatgpt", Category: "ai"},
        {Name: GetText("search_engine_grok"), Value: "grok", Category: "ai"},
        {Name: GetText("search_engine_gemini"), Value: "gemini", Category: "ai"},
        {Name: GetText("search_engine_aistudio"), Value: "aistudio", Category: "ai"},
        {Name: GetText("search_engine_nami"), Value: "nami", Category: "ai"},
        {Name: GetText("search_engine_lmarena"), Value: "lmarena", Category: "ai"},
        {Name: GetText("search_engine_manus"), Value: "manus", Category: "ai"},
        {Name: GetText("search_engine_mistral"), Value: "mistral", Category: "ai"},
        {Name: GetText("search_engine_yupp"), Value: "yupp", Category: "ai"},
        {Name: GetText("search_engine_zai"), Value: "zai", Category: "ai"},
        {Name: GetText("search_engine_coze"), Value: "coze", Category: "ai"},
        {Name: GetText("search_engine_tiangong"), Value: "tiangong", Category: "ai"},
        {Name: GetText("search_engine_you"), Value: "you", Category: "ai"},
        {Name: GetText("search_engine_claude"), Value: "claude", Category: "ai"},
        {Name: GetText("search_engine_monica"), Value: "monica", Category: "ai"},
        {Name: GetText("search_engine_webpilot"), Value: "webpilot", Category: "ai"},
        
        ; CLI类
        {Name: GetText("search_engine_cli_codex"), Value: "codex_cli", Category: "cli"},
        {Name: GetText("search_engine_cli_gemini"), Value: "gemini_cli", Category: "cli"},
        {Name: GetText("search_engine_cli_openclaw"), Value: "openclaw_cli", Category: "cli"},
        {Name: GetText("search_engine_cli_qwen"), Value: "qwen_cli", Category: "cli"},
        {Name: GetText("search_engine_cli_ollama"), Value: "ollama_cli", Category: "cli"},
        {Name: GetText("search_engine_cli_claude"), Value: "claude_cli", Category: "cli"},
        {Name: GetText("search_engine_cli_deepseek"), Value: "deepseek_cli", Category: "cli"},
        {Name: GetText("search_engine_cli_kimi"), Value: "kimi_cli", Category: "cli"},
        {Name: GetText("search_engine_cli_zhipu"), Value: "zhipu_cli", Category: "cli"},
        {Name: GetText("search_engine_cli_copilot"), Value: "copilot_cli", Category: "cli"},
        
        ; 学术类
        {Name: GetText("search_engine_zhihu"), Value: "zhihu", Category: "academic"},
        {Name: GetText("search_engine_wechat_article"), Value: "wechat_article", Category: "academic"},
        {Name: GetText("search_engine_cainiao"), Value: "cainiao", Category: "academic"},
        {Name: GetText("search_engine_gitee"), Value: "gitee", Category: "academic"},
        {Name: GetText("search_engine_pubscholar"), Value: "pubscholar", Category: "academic"},
        {Name: GetText("search_engine_semantic"), Value: "semantic", Category: "academic"},
        {Name: GetText("search_engine_baidu_academic"), Value: "baidu_academic", Category: "academic"},
        {Name: GetText("search_engine_bing_academic"), Value: "bing_academic", Category: "academic"},
        {Name: GetText("search_engine_csdn"), Value: "csdn", Category: "academic"},
        {Name: GetText("search_engine_national_library"), Value: "national_library", Category: "academic"},
        {Name: GetText("search_engine_chaoxing"), Value: "chaoxing", Category: "academic"},
        {Name: GetText("search_engine_cnki"), Value: "cnki", Category: "academic"},
        {Name: GetText("search_engine_wechat_reading"), Value: "wechat_reading", Category: "academic"},
        {Name: GetText("search_engine_dada"), Value: "dada", Category: "academic"},
        {Name: GetText("search_engine_patent"), Value: "patent", Category: "academic"},
        {Name: GetText("search_engine_ip_office"), Value: "ip_office", Category: "academic"},
        {Name: GetText("search_engine_dedao"), Value: "dedao", Category: "academic"},
        {Name: GetText("search_engine_pkmer"), Value: "pkmer", Category: "academic"},
        
        ; 百度类
        {Name: GetText("search_engine_baidu"), Value: "baidu", Category: "baidu"},
        {Name: GetText("search_engine_baidu_title"), Value: "baidu_title", Category: "baidu"},
        {Name: GetText("search_engine_baidu_hanyu"), Value: "baidu_hanyu", Category: "baidu"},
        {Name: GetText("search_engine_baidu_wenku"), Value: "baidu_wenku", Category: "baidu"},
        {Name: GetText("search_engine_baidu_map"), Value: "baidu_map", Category: "baidu"},
        {Name: GetText("search_engine_baidu_pdf"), Value: "baidu_pdf", Category: "baidu"},
        {Name: GetText("search_engine_baidu_doc"), Value: "baidu_doc", Category: "baidu"},
        {Name: GetText("search_engine_baidu_ppt"), Value: "baidu_ppt", Category: "baidu"},
        {Name: GetText("search_engine_baidu_xls"), Value: "baidu_xls", Category: "baidu"},
        
        ; 图片类
        {Name: GetText("search_engine_image_aggregate"), Value: "image_aggregate", Category: "image"},
        {Name: GetText("search_engine_iconfont"), Value: "iconfont", Category: "image"},
        {Name: GetText("search_engine_wenxin_image"), Value: "wenxin_image", Category: "image"},
        {Name: GetText("search_engine_tiangong_image"), Value: "tiangong_image", Category: "image"},
        {Name: GetText("search_engine_yuanbao_image"), Value: "yuanbao_image", Category: "image"},
        {Name: GetText("search_engine_tongyi_image"), Value: "tongyi_image", Category: "image"},
        {Name: GetText("search_engine_zhipu_image"), Value: "zhipu_image", Category: "image"},
        {Name: GetText("search_engine_miaohua"), Value: "miaohua", Category: "image"},
        {Name: GetText("search_engine_keling"), Value: "keling", Category: "image"},
        {Name: GetText("search_engine_jimmeng"), Value: "jimmeng", Category: "image"},
        {Name: GetText("search_engine_baidu_image"), Value: "baidu_image", Category: "image"},
        {Name: GetText("search_engine_shetu"), Value: "shetu", Category: "image"},
        {Name: GetText("search_engine_ai_image_lib"), Value: "ai_image_lib", Category: "image"},
        {Name: GetText("search_engine_huaban"), Value: "huaban", Category: "image"},
        {Name: GetText("search_engine_zcool"), Value: "zcool", Category: "image"},
        {Name: GetText("search_engine_uisdc"), Value: "uisdc", Category: "image"},
        {Name: GetText("search_engine_nipic"), Value: "nipic", Category: "image"},
        {Name: GetText("search_engine_qianku"), Value: "qianku", Category: "image"},
        {Name: GetText("search_engine_qiantu"), Value: "qiantu", Category: "image"},
        {Name: GetText("search_engine_zhongtu"), Value: "zhongtu", Category: "image"},
        {Name: GetText("search_engine_miyuan"), Value: "miyuan", Category: "image"},
        {Name: GetText("search_engine_mizhi"), Value: "mizhi", Category: "image"},
        {Name: GetText("search_engine_icons"), Value: "icons", Category: "image"},
        {Name: GetText("search_engine_tuxing"), Value: "tuxing", Category: "image"},
        {Name: GetText("search_engine_xiangsheji"), Value: "xiangsheji", Category: "image"},
        {Name: GetText("search_engine_bing_image"), Value: "bing_image", Category: "image"},
        {Name: GetText("search_engine_google_image"), Value: "google_image", Category: "image"},
        {Name: GetText("search_engine_weibo_image"), Value: "weibo_image", Category: "image"},
        {Name: GetText("search_engine_sogou_image"), Value: "sogou_image", Category: "image"},
        {Name: GetText("search_engine_haosou_image"), Value: "haosou_image", Category: "image"},
        
        ; 音频类
        {Name: GetText("search_engine_netease_music"), Value: "netease_music", Category: "audio"},
        {Name: GetText("search_engine_tiangong_music"), Value: "tiangong_music", Category: "audio"},
        {Name: GetText("search_engine_text_to_speech"), Value: "text_to_speech", Category: "audio"},
        {Name: GetText("search_engine_speech_to_text"), Value: "speech_to_text", Category: "audio"},
        {Name: GetText("search_engine_shetu_music"), Value: "shetu_music", Category: "audio"},
        {Name: GetText("search_engine_qq_music"), Value: "qq_music", Category: "audio"},
        {Name: GetText("search_engine_kuwo"), Value: "kuwo", Category: "audio"},
        {Name: GetText("search_engine_kugou"), Value: "kugou", Category: "audio"},
        {Name: GetText("search_engine_qianqian"), Value: "qianqian", Category: "audio"},
        {Name: GetText("search_engine_ximalaya"), Value: "ximalaya", Category: "audio"},
        {Name: GetText("search_engine_5sing"), Value: "5sing", Category: "audio"},
        {Name: GetText("search_engine_lossless"), Value: "lossless", Category: "audio"},
        {Name: GetText("search_engine_erling"), Value: "erling", Category: "audio"},
        
        ; 视频类
        {Name: GetText("search_engine_douyin"), Value: "douyin", Category: "video"},
        {Name: GetText("search_engine_yuewen"), Value: "yuewen", Category: "video"},
        {Name: GetText("search_engine_qingying"), Value: "qingying", Category: "video"},
        {Name: GetText("search_engine_tongyi_video"), Value: "tongyi_video", Category: "video"},
        {Name: GetText("search_engine_jimmeng_video"), Value: "jimmeng_video", Category: "video"},
        {Name: GetText("search_engine_youtube"), Value: "youtube", Category: "video"},
        {Name: GetText("search_engine_find_lines"), Value: "find_lines", Category: "video"},
        {Name: GetText("search_engine_shetu_video"), Value: "shetu_video", Category: "video"},
        {Name: GetText("search_engine_yandex"), Value: "yandex", Category: "video"},
        {Name: GetText("search_engine_pexels"), Value: "pexels", Category: "video"},
        {Name: GetText("search_engine_youku"), Value: "youku", Category: "video"},
        {Name: GetText("search_engine_chanjing"), Value: "chanjing", Category: "video"},
        {Name: GetText("search_engine_duojia"), Value: "duojia", Category: "video"},
        {Name: GetText("search_engine_tencent_zhiying"), Value: "tencent_zhiying", Category: "video"},
        {Name: GetText("search_engine_wansheng"), Value: "wansheng", Category: "video"},
        {Name: GetText("search_engine_tencent_video"), Value: "tencent_video", Category: "video"},
        {Name: GetText("search_engine_iqiyi"), Value: "iqiyi", Category: "video"},
        
        ; 图书类
        {Name: GetText("search_engine_duokan"), Value: "duokan", Category: "book"},
        {Name: GetText("search_engine_turing"), Value: "turing", Category: "book"},
        {Name: GetText("search_engine_panda_book"), Value: "panda_book", Category: "book"},
        {Name: GetText("search_engine_douban_book"), Value: "douban_book", Category: "book"},
        {Name: GetText("search_engine_lifelong_edu"), Value: "lifelong_edu", Category: "book"},
        {Name: GetText("search_engine_verypan"), Value: "verypan", Category: "book"},
        {Name: GetText("search_engine_zouddupai"), Value: "zouddupai", Category: "book"},
        {Name: GetText("search_engine_gd_library"), Value: "gd_library", Category: "book"},
        {Name: GetText("search_engine_pansou"), Value: "pansou", Category: "book"},
        {Name: GetText("search_engine_zsxq"), Value: "zsxq", Category: "book"},
        {Name: GetText("search_engine_jiumo"), Value: "jiumo", Category: "book"},
        {Name: GetText("search_engine_weibo_book"), Value: "weibo_book", Category: "book"},
        
        ; 比价类
        {Name: GetText("search_engine_jd"), Value: "jd", Category: "price"},
        {Name: GetText("search_engine_baidu_procure"), Value: "baidu_procure", Category: "price"},
        {Name: GetText("search_engine_dangdang"), Value: "dangdang", Category: "price"},
        {Name: GetText("search_engine_1688"), Value: "1688", Category: "price"},
        {Name: GetText("search_engine_taobao"), Value: "taobao", Category: "price"},
        {Name: GetText("search_engine_tmall"), Value: "tmall", Category: "price"},
        {Name: GetText("search_engine_pinduoduo"), Value: "pinduoduo", Category: "price"},
        {Name: GetText("search_engine_xianyu"), Value: "xianyu", Category: "price"},
        {Name: GetText("search_engine_smzdm"), Value: "smzdm", Category: "price"},
        {Name: GetText("search_engine_yanxuan"), Value: "yanxuan", Category: "price"},
        {Name: GetText("search_engine_gaide"), Value: "gaide", Category: "price"},
        {Name: GetText("search_engine_suning"), Value: "suning", Category: "price"},
        {Name: GetText("search_engine_ebay"), Value: "ebay", Category: "price"},
        {Name: GetText("search_engine_amazon"), Value: "amazon", Category: "price"},
        
        ; 医疗类
        {Name: GetText("search_engine_dxy"), Value: "dxy", Category: "medical"},
        {Name: GetText("search_engine_left_doctor"), Value: "left_doctor", Category: "medical"},
        {Name: GetText("search_engine_medisearch"), Value: "medisearch", Category: "medical"},
        {Name: GetText("search_engine_merck"), Value: "merck", Category: "medical"},
        {Name: GetText("search_engine_aplus_medical"), Value: "aplus_medical", Category: "medical"},
        {Name: GetText("search_engine_medical_baike"), Value: "medical_baike", Category: "medical"},
        {Name: GetText("search_engine_weiyi"), Value: "weiyi", Category: "medical"},
        {Name: GetText("search_engine_medlive"), Value: "medlive", Category: "medical"},
        {Name: GetText("search_engine_xywy"), Value: "xywy", Category: "medical"},
        
        ; 网盘类
        {Name: GetText("search_engine_pansoso"), Value: "pansoso", Category: "cloud"},
        {Name: GetText("search_engine_panso"), Value: "panso", Category: "cloud"},
        {Name: GetText("search_engine_xiaomapan"), Value: "xiaomapan", Category: "cloud"},
        {Name: GetText("search_engine_dashengpan"), Value: "dashengpan", Category: "cloud"},
        {Name: GetText("search_engine_miaosou"), Value: "miaosou", Category: "cloud"}
    ]
    
    return AllEngines
}

; 获取排序后的搜索引擎列表（根据语言版本和分类过滤）
GetSortedSearchEngines(Category := "") {
    global Language, VoiceSearchCurrentCategory
    
    ; 如果没有指定分类，使用当前选中的分类
    if (Category = "") {
        Category := VoiceSearchCurrentCategory
    }
    
    ; 获取所有搜索引擎
    AllEngines := GetAllSearchEngines()
    
    ; 按分类过滤
    FilteredEngines := []
    for Index, Engine in AllEngines {
        ; 【修复】添加安全检查，防止访问无效对象属性
        if (IsObject(Engine) && Engine.HasProp("Category") && Engine.Category = Category) {
            FilteredEngines.Push(Engine)
        }
    }
    
    ; 如果当前分类没有搜索引擎，返回空数组（不显示提示，让调用者处理）
    if (FilteredEngines.Length = 0) {
        return FilteredEngines
    }
    
    ; 根据语言版本排序（仅对AI类有效）
    if (Category = "ai") {
        ChineseEngines := []
        AIEngines := []
        
        for Index, Engine in FilteredEngines {
            ; 【修复】添加安全检查，防止访问无效对象属性
            if (!IsObject(Engine) || !Engine.HasProp("Value")) {
                continue
            }
            ; 判断是中文引擎还是AI引擎
            ChineseEngineValues := ["deepseek", "yuanbao", "doubao", "zhipu", "mita", "wenxin", "qianwen", "kimi"]
            if (ArrayContainsValue(ChineseEngineValues, Engine.Value) > 0) {
                ChineseEngines.Push(Engine)
            } else {
                AIEngines.Push(Engine)
            }
        }
        
        ; 根据语言版本排序
        if (Language = "en") {
            ; 英文版：AI引擎在前，中文引擎在后
            SearchEngines := []
            for Index, Engine in AIEngines {
                SearchEngines.Push(Engine)
            }
            for Index, Engine in ChineseEngines {
                SearchEngines.Push(Engine)
            }
        } else {
            ; 中文版：中文引擎在前，AI引擎在后
            SearchEngines := []
            for Index, Engine in ChineseEngines {
                SearchEngines.Push(Engine)
            }
            for Index, Engine in AIEngines {
                SearchEngines.Push(Engine)
            }
        }
        
        return SearchEngines
    }
    
    ; 其他分类直接返回过滤后的结果
    return FilteredEngines
}

; CLI 图标：优先 lib\images 下与引擎同名的 jpg/png（见目录内 codex.jpg、gemini.jpg、qwen.png 等）
VoiceInput_ResolveCliIconInLibImages(EngineValue) {
    eng := Trim(String(EngineValue))
    static CliIconFiles := 0
    if !IsObject(CliIconFiles) {
        CliIconFiles := Map(
            "codex_cli", ["codex.svg", "codex.png", "openai.svg", "copilot.svg"],
            "gemini_cli", ["gemini.svg", "gemini.png"],
            "openclaw_cli", ["openclaw.svg", "openclaw.png"],
            "qwen_cli", ["qwen.svg", "qwen.png"],
            "ollama_cli", ["ollama.svg", "ollama.png", "llama.svg"],
            "claude_cli", ["claude.svg", "claude.png", "Claude.png"],
            "deepseek_cli", ["deepseek.svg", "DeepSeek.png", "deepseek.png"],
            "kimi_cli", ["kimi.svg", "kimi.png", "Kimi.png"],
            "zhipu_cli", ["zhipu.svg", "glm.svg", "zhipu.png"],
            "copilot_cli", ["copilot.svg", "copilot.png", "Copilot.png", "openai.svg"]
        )
    }
    if !CliIconFiles.Has(eng)
        return ""
    dirs := []
    if FuncExists("Nmer_AssetsIconsAppDir")
        dirs.Push(Nmer_AssetsIconsAppDir())
    if FuncExists("Nmer_AssetsIconsAiDir")
        dirs.Push(Nmer_AssetsIconsAiDir())
    dirs.Push(A_ScriptDir . "\lib\images")
    for _, dir in dirs {
        for _, fileName in CliIconFiles[eng] {
            full := dir . "\" . fileName
            if FileExist(full)
                return full
        }
    }
    return ""
}

; 获取搜索引擎对应的图标文件名
GetSearchEngineIcon(EngineValue) {
    cliIcon := VoiceInput_ResolveCliIconInLibImages(EngineValue)
    if (cliIcon != "")
        return cliIcon

    ; 根据搜索引擎值返回对应的图标文件名
    IconMap := Map(
        ; AI类
        "deepseek", "DeepSeek.png",
        "yuanbao", "yuanbao.png",
        "doubao", "doubao.png",
        "zhipu", "zhipu.png",
        "mita", "mita.png",
        "wenxin", "wenxin.png",
        "qianwen", "qwen.png",
        "kimi", "Kimi.png",
        "perplexity", "Perplexity.png",
        "copilot", "Copilot.png",
        "chatgpt", "ChatGPT.png",
        "grok", "Grok.png",
        "gemini", "gemini.svg",
        "aistudio", "gemini.svg",
        "nami", "nami.png",
        "lmarena", "lmarena.png",
        "manus", "manus.png",
        "mistral", "mistral.png",
        "yupp", "yupp.png",
        "zai", "zai.png",
        "coze", "coze.png",
        "tiangong", "tiangong.png",
        "you", "You.png",
        "claude", "Claude.png",
        "monica", "Monica.png",
        "webpilot", "WebPilot.png"
        ; CLI 类由 VoiceInput_ResolveCliIconInLibImages 解析；其他引擎若无图标则返回空字符串
    )
    
    IconName := IconMap.Get(EngineValue, "")
    if (IconName != "") {
        ; 返回完整的图标路径
        ScriptDir := A_ScriptDir
        IconDirs := [Nmer_AssetsIconsAppDir(), Nmer_AssetsIconsAiDir(), ScriptDir . "\lib\images", ScriptDir . "\aiicons"]
        for _, DirPath in IconDirs {
            IconPath := DirPath . "\" . IconName
            if (FileExist(IconPath)) {
                return IconPath
            }
        }
    }
    eng := StrLower(Trim(String(EngineValue)))
    if (eng != "") {
        for _, DirPath in [Nmer_AssetsIconsAppDir(), Nmer_AssetsIconsAiDir()] {
            for _, name in [eng, EngineValue] {
                for _, ext in [".svg", ".png", ".webp", ".jpg", ".jpeg"] {
                    IconPath := DirPath . "\" . name . ext
                    if FileExist(IconPath)
                        return IconPath
                }
            }
        }
    }
    return ""  ; 如果图标不存在，返回空字符串
}

; 创建分类标签切换处理函数
CreateCategoryTabHandler(CategoryKey) {
    ; 使用闭包捕获CategoryKey
    CategoryTabHandler(*) {
        global VoiceSearchCurrentCategory, VoiceSearchCategoryTabs, VoiceSearchEngineButtons, GuiID_VoiceInput
        global VoiceSearchSelectedEngines, UI_Colors, ThemeMode, VoiceSearchLabelEngineY
        global VoiceSearchSelectedEnginesByCategory
        
        ; 确保 VoiceSearchSelectedEnginesByCategory 已初始化
        if (!IsSet(VoiceSearchSelectedEnginesByCategory) || !IsObject(VoiceSearchSelectedEnginesByCategory)) {
            VoiceSearchSelectedEnginesByCategory := Map()
        }
        
        ; 【关键修复】保存当前分类的搜索引擎选择状态
        OldCategory := VoiceSearchCurrentCategory
        if (OldCategory != "" && OldCategory != CategoryKey) {
            ; 保存当前分类的选择状态
            CurrentEngines := []
            for Index, Engine in VoiceSearchSelectedEngines {
                CurrentEngines.Push(Engine)
            }
            VoiceSearchSelectedEnginesByCategory[OldCategory] := CurrentEngines
        }
        
        ; 使用捕获的CategoryKey，而不是全局变量
        ; 更新当前分类
        VoiceSearchCurrentCategory := CategoryKey
        
        ; 确保GUI存在
        if (!GuiID_VoiceInput) {
            return
        }
        
        ; 更新所有标签按钮的样式
        for Index, TabObj in VoiceSearchCategoryTabs {
            ; 【关键修复】如果按钮引用丢失，尝试从GUI重新获取
            if (!TabObj.Btn || !IsObject(TabObj.Btn)) {
                try {
                    TabObj.Btn := GuiID_VoiceInput["CategoryTab" . TabObj.Key]
                } catch as err {
                    ; 如果无法获取，跳过这个标签
                    continue
                }
            }
            
            if (TabObj.Btn && IsObject(TabObj.Btn)) {
                IsActive := (TabObj.Key = CategoryKey)
                TabBg := IsActive ? UI_Colors.BtnPrimary : UI_Colors.BtnBg
                TabTextColor := IsActive ? "FFFFFF" : ((ThemeMode = "light") ? UI_Colors.Text : "FFFFFF")
                try {
                    ; 【关键修复】使用 Opt() 方法更新背景色，确保立即生效
                    TabObj.Btn.Opt("+Background" . TabBg)
                    TabObj.Btn.SetFont("s9 c" . TabTextColor, "Segoe UI")
                    TabObj.Btn.Text := GetText("search_category_" . TabObj.Key)
                    ; 强制重绘以确保背景色更新
                    TabObj.Btn.Redraw()
                } catch as err {
                    ; 如果上述方法失败，尝试直接设置 BackColor
                    try {
                        TabObj.Btn.BackColor := TabBg
                        TabObj.Btn.SetFont("s9 c" . TabTextColor, "Segoe UI")
                        TabObj.Btn.Text := GetText("search_category_" . TabObj.Key)
                    } catch as err {
                        ; 忽略更新样式时的错误
                    }
                }
            }
        }
        
        ; 【关键修复】恢复新分类的搜索引擎选择状态
        if (VoiceSearchSelectedEnginesByCategory.Has(CategoryKey)) {
            ; 如果该分类有保存的选择状态，恢复它
            VoiceSearchSelectedEngines := []
            for Index, Engine in VoiceSearchSelectedEnginesByCategory[CategoryKey] {
                VoiceSearchSelectedEngines.Push(Engine)
            }
        } else {
            ; 如果该分类没有保存的选择状态，使用默认值（根据分类的第一个搜索引擎）
            try {
                SearchEngines := GetSortedSearchEngines(CategoryKey)
                if (SearchEngines && SearchEngines.Length > 0 && IsObject(SearchEngines[1]) && SearchEngines[1].HasProp("Value")) {
                    VoiceSearchSelectedEngines := [SearchEngines[1].Value]
                } else {
                    VoiceSearchSelectedEngines := ["deepseek"]
                }
            } catch as err {
                VoiceSearchSelectedEngines := ["deepseek"]
            }
        }
        
        ; 【关键修复】先刷新标签背景色，确保立即显示
        try {
            if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
                WinRedraw(GuiID_VoiceInput.Hwnd)
            }
        } catch as err {
            ; 忽略刷新错误
        }
        
        ; 【关键修复】刷新搜索引擎按钮显示（隐藏旧的，显示新的）
        ; 使用短暂延迟确保标签背景色先更新，提升流畅度
        SetTimer(() => RefreshSearchEngineButtons(), -10)
    }
    return CategoryTabHandler
}

; ===================== 刷新搜索引擎按钮显示 =====================
RefreshSearchEngineButtons() {
    global GuiID_VoiceInput, VoiceSearchCurrentCategory, VoiceSearchEngineButtons, VoiceSearchSelectedEngines
    global VoiceSearchLabelEngineY, UI_Colors, ThemeMode, WindowDragging
    
    ; 如果窗口正在拖动，跳过刷新以避免闪烁
    if (WindowDragging) {
        return
    }
    
    if (!GuiID_VoiceInput) {
        return
    }
    
    ; 【关键修复】从GUI窗口获取实际宽度
    try {
        WinGetPos(, , &PanelWidth, , "ahk_id " . GuiID_VoiceInput.Hwnd)
    } catch as err {
        ; 如果获取失败，使用默认值
        PanelWidth := 600
    }
    
    ; 【关键修复】优化切换流畅度：先隐藏旧按钮，创建新按钮后再销毁旧按钮
    if (IsSet(VoiceSearchEngineButtons) && IsObject(VoiceSearchEngineButtons)) {
        ; 先隐藏所有旧按钮（不立即销毁，保持界面流畅）
        for Index, BtnObj in VoiceSearchEngineButtons {
            if (IsObject(BtnObj)) {
                try {
                    if (BtnObj.Bg) {
                        BtnObj.Bg.Visible := false
                    }
                    if (BtnObj.Icon) {
                        BtnObj.Icon.Visible := false
                    }
                    if (BtnObj.Text) {
                        BtnObj.Text.Visible := false
                    }
                } catch as err {
                    ; 忽略隐藏错误
                }
            }
        }
    }
    
    ; 保存旧按钮数组用于后续销毁
    OldButtons := VoiceSearchEngineButtons
    ; 清空按钮数组，准备创建新按钮
    VoiceSearchEngineButtons := []
    
    ; 获取当前分类的搜索引擎列表
    try {
        SearchEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
    } catch as err {
        return
    }
    
    if (!IsObject(SearchEngines) || SearchEngines.Length = 0) {
        return
    }
    
    ; 计算按钮位置和布局
    global VoiceSearchLabelEngineY
    YPos := VoiceSearchLabelEngineY + 30
    ButtonWidth := 130
    ButtonHeight := 35
    ButtonSpacing := 10
    StartX := 20
    ButtonsPerRow := 4
    IconSizeInButton := 20
    
    AvailableWidth := PanelWidth - 40
    MaxButtonsPerRow := Floor((AvailableWidth + ButtonSpacing) / (ButtonWidth + ButtonSpacing))
    if (MaxButtonsPerRow < 1) {
        MaxButtonsPerRow := 1
    }
    ButtonsPerRow := Min(ButtonsPerRow, MaxButtonsPerRow)
    
    ; 创建新的搜索引擎按钮
    for Index, Engine in SearchEngines {
        if (!IsObject(Engine) || !Engine.HasProp("Value") || !Engine.HasProp("Name")) {
            continue
        }
        
        Row := Floor((Index - 1) / ButtonsPerRow)
        Col := Mod((Index - 1), ButtonsPerRow)
        BtnX := StartX + Col * (ButtonWidth + ButtonSpacing)
        BtnY := YPos + Row * (ButtonHeight + ButtonSpacing)
        
        IsSelected := (ArrayContainsValue(VoiceSearchSelectedEngines, Engine.Value) > 0)
        BtnBgColor := IsSelected ? UI_Colors.BtnHover : UI_Colors.BtnBg
        BtnText := IsSelected ? "✓ " . Engine.Name : Engine.Name
        EngineBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
        
        IconPath := GetSearchEngineIcon(Engine.Value)
        IconCtrl := 0
        
        Btn := GuiID_VoiceInput.Add("Text", "x" . BtnX . " y" . BtnY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . EngineBtnTextColor . " Background" . BtnBgColor, "")
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
        HoverBtn(Btn, BtnBgColor, UI_Colors.BtnHover)
        
        if (IconPath != "" && FileExist(IconPath)) {
            try {
                IconX := BtnX + 8
                IconY := BtnY + (ButtonHeight - IconSizeInButton) // 2
                
                ImageSize := GetImageSize(IconPath)
                DisplaySize := CalculateImageDisplaySize(ImageSize.Width, ImageSize.Height, IconSizeInButton, IconSizeInButton)
                
                DisplayX := IconX
                DisplayY := IconY + (IconSizeInButton - DisplaySize.Height) // 2
                
                IconCtrl := GuiID_VoiceInput.Add("Picture", "x" . DisplayX . " y" . DisplayY . " w" . DisplaySize.Width . " h" . DisplaySize.Height . " 0x200", IconPath)
                IconCtrl.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
                
                TextX := IconX + IconSizeInButton + 5
                TextWidth := ButtonWidth - (TextX - BtnX) - 8
            } catch as err {
                IconCtrl := 0
                TextX := BtnX + 8
                TextWidth := ButtonWidth - 16
            }
        } else {
            TextX := BtnX + 8
            TextWidth := ButtonWidth - 16
        }
        
        TextCtrl := GuiID_VoiceInput.Add("Text", "x" . TextX . " y" . BtnY . " w" . TextWidth . " h" . ButtonHeight . " Left 0x200 c" . EngineBtnTextColor . " BackgroundTrans", BtnText)
        TextCtrl.SetFont("s10", "Segoe UI")
        TextCtrl.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
        
        ; 使用新的索引（从1开始）
        NewIndex := VoiceSearchEngineButtons.Length + 1
        VoiceSearchEngineButtons.Push({Bg: Btn, Icon: IconCtrl, Text: TextCtrl, Index: NewIndex})
    }
    
    ; 【关键修复】刷新GUI显示，确保新按钮立即显示
    try {
        if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
            WinRedraw(GuiID_VoiceInput.Hwnd)
        }
    } catch as err {
        ; 忽略刷新错误
    }
    
    ; 【关键修复】延迟销毁旧按钮，确保新按钮已显示后再清理，提升流畅度
    SetTimer(() => DestroyOldSearchEngineButtons(OldButtons), -100)
}

; 销毁旧的搜索引擎按钮（延迟执行，提升流畅度）
DestroyOldSearchEngineButtons(OldButtons) {
    if (!IsSet(OldButtons) || !IsObject(OldButtons)) {
        return
    }
    
    for Index, BtnObj in OldButtons {
        if (IsObject(BtnObj)) {
            try {
                if (BtnObj.Bg) {
                    BtnObj.Bg.Destroy()
                }
                if (BtnObj.Icon) {
                    BtnObj.Icon.Destroy()
                }
                if (BtnObj.Text) {
                    BtnObj.Text.Destroy()
                }
            } catch as err {
                ; 忽略销毁错误
            }
        }
    }
}

; ===================== 语音搜索相关函数 =====================
; 执行语音搜索（副作用在 VoiceInputEffect_ProcessingBegin）
ExecuteVoiceSearch(*) {
    global VoiceSearchPanelVisible, g_VoiceFSMSearchRun
    if (!VoiceSearchPanelVisible)
        return
    g_VoiceFSMSearchRun := true
    VoiceFSM_Dispatch("processing_begin")
}

; 开始语音输入（在语音搜索界面中，经 FSM）
StartVoiceInputInSearch() {
    VoiceFSM_Dispatch("search_listen_start")
}

; 停止语音输入（在语音搜索界面中，经 FSM）
StopVoiceInputInSearch() {
    if FuncExists("VoiceInputEffect_SearchStopListeningImpl")
        VoiceInputEffect_SearchStopListeningImpl()
    VoiceInput_SyncLegacyFlags()
}

; 聚焦语音搜索输入框
FocusVoiceSearchInput() {
    global VoiceSearchInputEdit, VoiceSearchPanelVisible, AutoLoadSelectedText
    
    if (!VoiceSearchPanelVisible || !VoiceSearchInputEdit) {
        return
    }
    
    try {
        ; 清空输入框
        VoiceSearchInputEdit.Value := ""
        ; 设置焦点
        VoiceSearchInputEdit.Focus()
        
        ; 注意：自动加载功能已移除，不再启动定时器
        SetTimer(MonitorSelectedText, 0)
    } catch as err {
        ; 忽略错误
    }
}

; 切换自动加载选中文本开关（语音输入界面）
ToggleAutoLoadSelectedTextForVoiceInput(*) {
    global AutoLoadSelectedText, VoiceInputAutoLoadSwitch, VoiceInputActionSelectionVisible, UI_Colors, ConfigFile
    
    if (!VoiceInputActionSelectionVisible || !VoiceInputAutoLoadSwitch) {
        return
    }
    
    ; 切换状态
    AutoLoadSelectedText := !AutoLoadSelectedText
    
    ; 更新开关显示
    SwitchText := AutoLoadSelectedText ? "✓ 已开启" : "○ 已关闭"
    SwitchBg := AutoLoadSelectedText ? UI_Colors.BtnHover : UI_Colors.BtnBg
    VoiceInputAutoLoadSwitch.Text := SwitchText
    VoiceInputAutoLoadSwitch.BackColor := SwitchBg
    
    ; 保存到配置文件
    try {
        IniWrite(AutoLoadSelectedText ? "1" : "0", ConfigFile, "Settings", "AutoLoadSelectedText")
    } catch as err {
        ; 忽略保存错误
    }
    
    ; 如果开启，启动监听；如果关闭，立即停止监听
    if (AutoLoadSelectedText) {
        SetTimer(MonitorSelectedTextForVoiceInput, 200)  ; 每200ms检查一次
    } else {
        ; 立即停止监听，确保不会继续自动加载
        SetTimer(MonitorSelectedTextForVoiceInput, 0)
    }
}

; 监听选中文本并自动加载到输入框（语音输入界面）
MonitorSelectedTextForVoiceInput(*) {
    global AutoLoadSelectedText, VoiceInputActionSelectionVisible, GuiID_VoiceInput
    
    ; 如果开关未开启或界面未显示，立即停止监听
    if (!AutoLoadSelectedText || !VoiceInputActionSelectionVisible || !GuiID_VoiceInput) {
        SetTimer(MonitorSelectedTextForVoiceInput, 0)
        return
    }
    
    ; 检查是否有选中的文本
    try {
        ; 保存当前剪贴板
        OldClipboard := A_Clipboard
        
        ; 尝试复制选中文本
        A_Clipboard := ""
        Send("^c")
        Sleep(50)  ; 等待复制完成
        
        ; 检查是否复制成功
        if (ClipWait(0.1) && A_Clipboard != "" && A_Clipboard != OldClipboard) {
            ; 有选中文本，加载到输入框
            SelectedText := A_Clipboard
            if (SelectedText != "" && StrLen(SelectedText) > 0) {
                ; 尝试获取输入框控件并更新
                try {
                    ContentEdit := GuiID_VoiceInput["VoiceInputContentEdit"]
                    if (ContentEdit && (ContentEdit.Value = "" || ContentEdit.Value != SelectedText)) {
                        ContentEdit.Value := SelectedText
                    }
                } catch as err {
                    ; 忽略错误
                }
            }
        }
        
        ; 恢复剪贴板
        A_Clipboard := OldClipboard
    } catch as err {
        ; 忽略错误
    }
}

; 显示搜索引擎选择界面
ShowSearchEngineSelection(Content) {
    global GuiID_VoiceInput, VoiceInputScreenIndex, UI_Colors, VoiceSearchSelecting, VoiceSearchEngineButtons
    
    VoiceSearchSelecting := true
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
        GuiID_VoiceInput := 0
    }
    
    GuiID_VoiceInput := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    GuiID_VoiceInput.BackColor := UI_Colors.Background
    GuiID_VoiceInput.SetFont("s12 c" . UI_Colors.Text . " Bold", "Segoe UI")
    
    ; 获取所有搜索引擎
    global SearchEngines := GetAllSearchEngines()
    
    PanelWidth := 500
    ; 计算所需高度：标题(50) + 内容标签(25) + 内容框(60) + 引擎标签(30) + 按钮区域 + 取消按钮(45) + 边距(20)
    ButtonsRows := Ceil(SearchEngines.Length / 4)  ; 每行4个按钮
    ButtonsAreaHeight := ButtonsRows * 45  ; 每行45px（按钮35px + 间距10px）
    PanelHeight := 50 + 25 + 60 + 30 + ButtonsAreaHeight + 45 + 20
    
    ; 标题
    TitleText := GuiID_VoiceInput.Add("Text", "x0 y15 w500 h30 Center c" . UI_Colors.Text, GetText("select_search_engine_title"))
    TitleText.SetFont("s14 Bold", "Segoe UI")
    
    ; 显示搜索内容
    YPos := 55
    LabelText := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h20 cCCCCCC", "搜索内容:")
    LabelText.SetFont("s10", "Segoe UI")
    
    YPos += 25
    ContentText := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h60 Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, Content)
    ContentText.SetFont("s11", "Segoe UI")
    
    ; 搜索引擎按钮
    YPos += 70
    LabelEngine := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h25 c" . UI_Colors.Text, GetText("select_search_engine"))
    LabelEngine.SetFont("s11", "Segoe UI")
    
    YPos += 30
    ButtonWidth := 110
    ButtonHeight := 35
    ButtonSpacing := 10
    ButtonsPerRow := 4
    
    VoiceSearchEngineButtons := []
    for Index, Engine in SearchEngines {
        ; 【修复】添加安全检查，防止访问无效对象属性
        if (!IsObject(Engine) || !Engine.HasProp("Value") || !Engine.HasProp("Name")) {
            continue  ; 跳过无效的引擎对象
        }
        
        Row := Floor((Index - 1) / ButtonsPerRow)
        Col := Mod(Index - 1, ButtonsPerRow)
        BtnX := 20 + Col * (ButtonWidth + ButtonSpacing)
        BtnY := YPos + Row * (ButtonHeight + ButtonSpacing)
        
        Btn := GuiID_VoiceInput.Add("Text", "x" . BtnX . " y" . BtnY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.BtnBg . " vSearchEngineBtn" . Index, Engine.Name)
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", CreateSearchEngineClickHandler(Content, Engine.Value))
        HoverBtn(Btn, UI_Colors.BtnBg, UI_Colors.BtnHover)
        VoiceSearchEngineButtons.Push(Btn)
    }
    
    ; 取消按钮
    CancelBtnY := YPos + (Floor((SearchEngines.Length - 1) / ButtonsPerRow) + 1) * (ButtonHeight + ButtonSpacing) + 10
    global ThemeMode
    CancelBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    CancelBtnBg := (ThemeMode = "light") ? UI_Colors.BtnBg : "666666"
    CancelBtn := GuiID_VoiceInput.Add("Text", "x" . (PanelWidth // 2 - 60) . " y" . CancelBtnY . " w120 h35 Center 0x200 c" . CancelBtnTextColor . " Background" . CancelBtnBg . " vCancelBtn", GetText("cancel"))
    CancelBtn.SetFont("s11", "Segoe UI")
    CancelBtn.OnEvent("Click", CancelSearchEngineSelection)
    HoverBtn(CancelBtn, "666666", "777777")
    
    ScreenInfo := GetScreenInfo(VoiceInputScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "center")
    GuiID_VoiceInput.Show("w" . PanelWidth . " h" . PanelHeight . " x" . Pos.X . " y" . Pos.Y . " NoActivate")
    WinSetAlwaysOnTop(1, GuiID_VoiceInput.Hwnd)
}

; 创建搜索引擎点击处理函数
CreateSearchEngineClickHandler(Content, Engine) {
    ; 使用闭包保存参数
    SearchEngineClickHandler(*) {
        global VoiceSearchSelecting
        VoiceSearchSelecting := false
        HideVoiceSearchInputPanel()
        SendVoiceSearchToBrowser(Content, Engine)
    }
    return SearchEngineClickHandler
}

; 取消搜索引擎选择
CancelSearchEngineSelection(*) {
    global VoiceSearchSelecting
    VoiceSearchSelecting := false
    HideVoiceSearchInputPanel()
}

; 显示语音搜索输入界面
ShowVoiceSearchInputPanel() {
    global GuiID_VoiceInput, VoiceInputScreenIndex, UI_Colors, VoiceSearchPanelVisible
    global VoiceSearchInputEdit, VoiceSearchSelectedEngines, VoiceSearchEngineButtons
    
    VoiceSearchPanelVisible := true
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
        GuiID_VoiceInput := 0
    }
    
    ; 【关键修复】移除 -Caption，添加标题栏以支持窗口拖动，添加 +Resize 支持调整大小
    GuiID_VoiceInput := Gui("+AlwaysOnTop -DPIScale +Resize -MaximizeBox")
    GuiID_VoiceInput.BackColor := UI_Colors.Background
    GuiID_VoiceInput.SetFont("s12 c" . UI_Colors.Text . " Bold", "Segoe UI")
    GuiID_VoiceInput.Title := GetText("voice_search_title")
    
    ; 添加窗口大小改变和移动事件处理
    ; 注意：在窗口显示后再绑定事件，避免初始化问题
    
    ; 动态计算宽度，确保所有按钮可见
    InputBoxHeight := 150
    global VoiceSearchCurrentCategory, VoiceSearchEnabledCategories
    if (!IsSet(VoiceSearchCurrentCategory) || VoiceSearchCurrentCategory = "") {
        VoiceSearchCurrentCategory := "ai"
    }
    if (!IsSet(VoiceSearchEnabledCategories) || !IsObject(VoiceSearchEnabledCategories)) {
        VoiceSearchEnabledCategories := ["ai", "cli", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
    }
    ; 【关键修复】确保 VoiceSearchSelectedEnginesByCategory 已初始化
    global VoiceSearchSelectedEnginesByCategory
    if (!IsSet(VoiceSearchSelectedEnginesByCategory) || !IsObject(VoiceSearchSelectedEnginesByCategory)) {
        VoiceSearchSelectedEnginesByCategory := Map()
    }
    
    ; 【关键修复】根据当前分类恢复搜索引擎选择状态
    if (VoiceSearchSelectedEnginesByCategory.Has(VoiceSearchCurrentCategory)) {
        VoiceSearchSelectedEngines := []
        for Index, Engine in VoiceSearchSelectedEnginesByCategory[VoiceSearchCurrentCategory] {
            VoiceSearchSelectedEngines.Push(Engine)
        }
    } else {
        ; 如果当前分类没有保存的状态，使用默认值
        try {
            SearchEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
            if (SearchEngines && SearchEngines.Length > 0 && IsObject(SearchEngines[1]) && SearchEngines[1].HasProp("Value")) {
                VoiceSearchSelectedEngines := [SearchEngines[1].Value]
            } else {
                VoiceSearchSelectedEngines := ["deepseek"]
            }
        } catch as err {
            VoiceSearchSelectedEngines := ["deepseek"]
        }
    }
    
    ; 【关键修复】确保 VoiceSearchSelectedEngines 已正确初始化
    if (!IsSet(VoiceSearchSelectedEngines) || !IsObject(VoiceSearchSelectedEngines)) {
        VoiceSearchSelectedEngines := ["deepseek"]
    }
    if (VoiceSearchSelectedEngines.Length = 0) {
        VoiceSearchSelectedEngines := ["deepseek"]
    }
    SearchEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
    ; 【修复】确保 SearchEngines 是有效的数组
    if (!IsObject(SearchEngines) || SearchEngines.Length = 0) {
        ; 如果当前分类没有搜索引擎，使用默认分类
        VoiceSearchCurrentCategory := "ai"
        SearchEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
        if (!IsObject(SearchEngines) || SearchEngines.Length = 0) {
            ; 如果仍然为空，创建一个默认引擎
            SearchEngines := [{Name: GetText("search_engine_deepseek"), Value: "deepseek", Category: "ai"}]
        }
    }
    TotalEngines := SearchEngines.Length
    ButtonWidth := 130
    ButtonHeight := 35
    ButtonSpacing := 10
    ButtonsPerRow := 4
    ButtonsRows := Ceil(TotalEngines / ButtonsPerRow)
    ButtonsAreaHeight := ButtonsRows * (ButtonHeight + ButtonSpacing)
    
    InputBoxWidth := 520
    RightButtonsWidth := 40 + 20
    ButtonsAreaWidth := ButtonsPerRow * ButtonWidth + (ButtonsPerRow - 1) * ButtonSpacing
    MinWidth := InputBoxWidth + RightButtonsWidth + 40
    PanelWidth := Max(MinWidth, ButtonsAreaWidth + 40)
    
    ; 计算分类标签区域宽度
    TabWidth := 50
    TabSpacing := 5
    TabsPerRow := 10
    TabAreaWidth := TabsPerRow * TabWidth + (TabsPerRow - 1) * TabSpacing
    MinTabAreaWidth := TabAreaWidth + 150
    PanelWidth := Max(PanelWidth, MinTabAreaWidth)
    
    CategoryTabHeight := 28 + 15
    AllCategories := [
        {Key: "ai", Text: GetText("search_category_ai")},
        {Key: "cli", Text: GetText("search_category_cli")},
        {Key: "academic", Text: GetText("search_category_academic")},
        {Key: "baidu", Text: GetText("search_category_baidu")},
        {Key: "image", Text: GetText("search_category_image")},
        {Key: "audio", Text: GetText("search_category_audio")},
        {Key: "video", Text: GetText("search_category_video")},
        {Key: "book", Text: GetText("search_category_book")},
        {Key: "price", Text: GetText("search_category_price")},
        {Key: "medical", Text: GetText("search_category_medical")},
        {Key: "cloud", Text: GetText("search_category_cloud")}
    ]
    
    if (!IsSet(VoiceSearchEnabledCategories) || !IsObject(VoiceSearchEnabledCategories)) {
        VoiceSearchEnabledCategories := ["ai", "cli", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
    }
    
    Categories := []
    for Index, Category in AllCategories {
        ; 【关键修复】添加安全检查，防止访问无效对象属性导致 "Item has no value" 错误
        if (!IsObject(Category) || !Category.HasProp("Key")) {
            continue  ; 跳过无效的分类对象
        }
        if (ArrayContainsValue(VoiceSearchEnabledCategories, Category.Key) > 0) {
            Categories.Push(Category)
        }
    }
    
    if (Categories.Length = 0) {
        Categories.Push({Key: "ai", Text: GetText("search_category_ai")})
        VoiceSearchCurrentCategory := "ai"
    }
    
    if (ArrayContainsValue(VoiceSearchEnabledCategories, VoiceSearchCurrentCategory) = 0) {
        if (Categories.Length > 0) {
            ; 【关键修复】添加安全检查，防止访问无效对象属性
            if (IsObject(Categories[1]) && Categories[1].HasProp("Key")) {
                VoiceSearchCurrentCategory := Categories[1].Key
            } else {
                VoiceSearchCurrentCategory := "ai"
            }
        } else {
            VoiceSearchCurrentCategory := "ai"
        }
    }
    
    TabRows := Ceil(Categories.Length / TabsPerRow)
    CategoryTabHeight := TabRows * (28 + TabSpacing) + 15
    
    PanelHeight := 30 + 15 + 25 + InputBoxHeight + CategoryTabHeight + 30 + ButtonsAreaHeight + 20
    
    ; 关闭按钮
    CloseBtnX := PanelWidth - 40
    CloseBtnY := 5
    CloseBtn := GuiID_VoiceInput.Add("Text", "x" . CloseBtnX . " y" . CloseBtnY . " w30 h30 Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.BtnBg . " vCloseBtn", "×")
    CloseBtn.SetFont("s18 Bold", "Segoe UI")
    CloseBtn.OnEvent("Click", HideVoiceSearchInputPanel)
    HoverBtn(CloseBtn, UI_Colors.BtnBg, "FF4444")
    
    ; 输入框标签
    YPos := 50
    LabelText := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w" . (PanelWidth - 80) . " h20 c" . UI_Colors.TextDim, GetText("voice_search_input_label"))
    LabelText.SetFont("s10", "Segoe UI")
    
    ; 检查主题模式
    global ThemeMode
    if (!IsSet(ThemeMode) || ThemeMode = "") {
        ThemeMode := "dark"
    }
    
    ; 牛马图标（放在输入框左边）
    YPos += 25
    IconSize := 32
    IconX := 20
    IconY := YPos
    ; 优先使用用户自定义图标
    global CustomIconPath
    IconPath := ResolveDefaultUiIconPath()
    if (FileExist(IconPath)) {
        VoiceSearchIcon := GuiID_VoiceInput.Add("Picture", "x" . IconX . " y" . IconY . " w" . IconSize . " h" . IconSize . " 0x200", IconPath)
    }
    
    ; 输入框（调整位置，为图标留出空间）
    InputBoxX := IconX + IconSize + 10  ; 图标右边留10px间距
    InputBoxActualWidth := PanelWidth - InputBoxX - 80  ; 减去左边距和右边距
    ; 根据主题模式设置输入框颜色（暗色模式使用cursor黑灰色系）
    if (ThemeMode = "dark") {
        InputBgColor := UI_Colors.InputBg  ; html.to.design 风格背景
        InputTextColor := UI_Colors.Text   ; html.to.design 风格文本
    } else {
        InputBgColor := UI_Colors.InputBg
        InputTextColor := UI_Colors.Text
    }
    VoiceSearchInputEdit := GuiID_VoiceInput.Add("Edit", "x" . InputBoxX . " y" . YPos . " w" . InputBoxActualWidth . " h150 vVoiceSearchInputEdit Background" . InputBgColor . " c" . InputTextColor . " Multi", "")
    VoiceSearchInputEdit.SetFont("s12", "Segoe UI")
    VoiceSearchInputEdit.OnEvent("Focus", SwitchToChineseIME)
    VoiceSearchInputEdit.OnEvent("Change", UpdateVoiceSearchInputEditTime)
    
    ; 清空按钮和搜索按钮
    ClearBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    RightBtnX := PanelWidth - 60
    ClearBtn := GuiID_VoiceInput.Add("Text", "x" . RightBtnX . " y" . YPos . " w40 h40 Center 0x200 c" . ClearBtnTextColor . " Background" . UI_Colors.BtnBg . " vClearBtn", GetText("clear"))
    ClearBtn.SetFont("s10", "Segoe UI")
    ClearBtn.OnEvent("Click", ClearVoiceSearchInput)
    HoverBtn(ClearBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    SearchBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    SearchBtn := GuiID_VoiceInput.Add("Text", "x" . RightBtnX . " y" . (YPos + 110) . " w40 h40 Center 0x200 c" . SearchBtnTextColor . " Background" . UI_Colors.BtnPrimary . " vSearchBtn", GetText("voice_search_button"))
    SearchBtn.SetFont("s11 Bold", "Segoe UI")
    SearchBtn.OnEvent("Click", ExecuteVoiceSearch)
    HoverBtn(SearchBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
    
    ; 分类标签栏
    YPos += 160
    LabelCategoryWidth := PanelWidth - 280
    LabelCategory := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w" . LabelCategoryWidth . " h20 c" . UI_Colors.TextDim, GetText("select_search_engine"))
    LabelCategory.SetFont("s10", "Segoe UI")
    
    ClearSelectionBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    ClearSelectionBtnX := PanelWidth - 150
    ClearSelectionBtn := GuiID_VoiceInput.Add("Text", "x" . ClearSelectionBtnX . " y" . YPos . " w130 h25 Center 0x200 c" . ClearSelectionBtnTextColor . " Background" . UI_Colors.BtnBg . " vClearSelectionBtn", GetText("clear_selection"))
    ClearSelectionBtn.SetFont("s10", "Segoe UI")
    ClearSelectionBtn.OnEvent("Click", ClearAllSearchEngineSelection)
    HoverBtn(ClearSelectionBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; 创建分类标签按钮
    YPos += 30
    global VoiceSearchCategoryTabs
    
    VoiceSearchCategoryTabs := []
    TabWidth := 50
    TabHeight := 28
    TabSpacing := 5
    TabStartX := 20
    TabY := YPos
    TabsPerRow := 10
    
    ; 第一行标签
    for Index, Category in Categories {
        ; 【关键修复】添加安全检查，防止访问无效对象属性导致 "Item has no value" 错误
        if (!IsObject(Category) || !Category.HasProp("Key") || !Category.HasProp("Text")) {
            continue  ; 跳过无效的分类对象
        }
        if (Index > TabsPerRow) {
            break
        }
        TabX := TabStartX + (Index - 1) * (TabWidth + TabSpacing)
        IsActive := (VoiceSearchCurrentCategory = Category.Key)
        TabBg := IsActive ? UI_Colors.BtnPrimary : UI_Colors.BtnBg
        TabTextColor := IsActive ? "FFFFFF" : ((ThemeMode = "light") ? UI_Colors.Text : "FFFFFF")
        
        TabBtn := GuiID_VoiceInput.Add("Text", "x" . TabX . " y" . TabY . " w" . TabWidth . " h" . TabHeight . " Center 0x200 c" . TabTextColor . " Background" . TabBg . " vCategoryTab" . Category.Key, Category.Text)
        TabBtn.SetFont("s9", "Segoe UI")
        TabHandler := CreateCategoryTabHandler(Category.Key)
        TabBtn.OnEvent("Click", TabHandler)
        HoverBtn(TabBtn, TabBg, UI_Colors.BtnHover)
        VoiceSearchCategoryTabs.Push({Btn: TabBtn, Key: Category.Key, Handler: TabHandler})
    }
    
    ; 如果标签超过10个，创建第二行
    if (Categories.Length > TabsPerRow) {
        TabY += TabHeight + TabSpacing
        for Index, Category in Categories {
            ; 【关键修复】添加安全检查，防止访问无效对象属性导致 "Item has no value" 错误
            if (!IsObject(Category) || !Category.HasProp("Key") || !Category.HasProp("Text")) {
                continue  ; 跳过无效的分类对象
            }
            if (Index <= TabsPerRow) {
                continue
            }
            TabIndex := Index - TabsPerRow
            TabX := TabStartX + (TabIndex - 1) * (TabWidth + TabSpacing)
            IsActive := (VoiceSearchCurrentCategory = Category.Key)
            TabBg := IsActive ? UI_Colors.BtnPrimary : UI_Colors.BtnBg
            TabTextColor := IsActive ? "FFFFFF" : ((ThemeMode = "light") ? UI_Colors.Text : "FFFFFF")
            
            TabBtn := GuiID_VoiceInput.Add("Text", "x" . TabX . " y" . TabY . " w" . TabWidth . " h" . TabHeight . " Center 0x200 c" . TabTextColor . " Background" . TabBg . " vCategoryTab" . Category.Key, Category.Text)
            TabBtn.SetFont("s9", "Segoe UI")
            TabHandler := CreateCategoryTabHandler(Category.Key)
            TabBtn.OnEvent("Click", TabHandler)
            HoverBtn(TabBtn, TabBg, UI_Colors.BtnHover)
            VoiceSearchCategoryTabs.Push({Btn: TabBtn, Key: Category.Key, Handler: TabHandler})
        }
    }
    
    ; 搜索引擎标签
    YPos := TabY + TabHeight + 15
    LabelEngineWidth := PanelWidth - 40
    LabelEngine := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w" . LabelEngineWidth . " h20 c" . UI_Colors.TextDim . " vLabelEngine", GetText("select_search_engine"))
    LabelEngine.SetFont("s10", "Segoe UI")
    
    global VoiceSearchLabelEngineY := YPos
    
    ; 搜索引擎按钮
    YPos += 30
    VoiceSearchEngineButtons := []
    ButtonWidth := 130
    ButtonHeight := 35
    ButtonSpacing := 10
    StartX := 20
    ButtonsPerRow := 4
    IconSizeInButton := 20
    
    AvailableWidth := PanelWidth - 40
    MaxButtonsPerRow := Floor((AvailableWidth + ButtonSpacing) / (ButtonWidth + ButtonSpacing))
    if (MaxButtonsPerRow < 1) {
        MaxButtonsPerRow := 1
    }
    ButtonsPerRow := Min(ButtonsPerRow, MaxButtonsPerRow)
    ButtonsRows := Ceil(TotalEngines / ButtonsPerRow)
    ButtonsAreaHeight := ButtonsRows * (ButtonHeight + ButtonSpacing)
    
    PanelHeight := 30 + 15 + 25 + InputBoxHeight + CategoryTabHeight + 30 + ButtonsAreaHeight + 20
    
    for Index, Engine in SearchEngines {
        ; 【关键修复】添加安全检查，防止访问无效对象属性导致 "Item has no value" 错误
        if (!IsObject(Engine) || !Engine.HasProp("Value") || !Engine.HasProp("Name")) {
            continue  ; 跳过无效的引擎对象
        }
        
        Row := Floor((Index - 1) / ButtonsPerRow)
        Col := Mod((Index - 1), ButtonsPerRow)
        BtnX := StartX + Col * (ButtonWidth + ButtonSpacing)
        BtnY := YPos + Row * (ButtonHeight + ButtonSpacing)
        
        IsSelected := (ArrayContainsValue(VoiceSearchSelectedEngines, Engine.Value) > 0)
        BtnBgColor := IsSelected ? UI_Colors.BtnHover : UI_Colors.BtnBg
        BtnText := IsSelected ? "✓ " . Engine.Name : Engine.Name
        EngineBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
        
        IconPath := GetSearchEngineIcon(Engine.Value)
        IconCtrl := 0
        
        Btn := GuiID_VoiceInput.Add("Text", "x" . BtnX . " y" . BtnY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . EngineBtnTextColor . " Background" . BtnBgColor, "")
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
        HoverBtn(Btn, BtnBgColor, UI_Colors.BtnHover)
        
        if (IconPath != "" && FileExist(IconPath)) {
            try {
                IconX := BtnX + 8
                IconY := BtnY + (ButtonHeight - IconSizeInButton) // 2
                
                ImageSize := GetImageSize(IconPath)
                DisplaySize := CalculateImageDisplaySize(ImageSize.Width, ImageSize.Height, IconSizeInButton, IconSizeInButton)
                
                DisplayX := IconX
                DisplayY := IconY + (IconSizeInButton - DisplaySize.Height) // 2
                
                IconCtrl := GuiID_VoiceInput.Add("Picture", "x" . DisplayX . " y" . DisplayY . " w" . DisplaySize.Width . " h" . DisplaySize.Height . " 0x200", IconPath)
                IconCtrl.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
                
                TextX := IconX + IconSizeInButton + 5
                TextWidth := ButtonWidth - (TextX - BtnX) - 8
            } catch as err {
                IconCtrl := 0
                TextX := BtnX + 8
                TextWidth := ButtonWidth - 16
            }
        } else {
            TextX := BtnX + 8
            TextWidth := ButtonWidth - 16
        }
        
        TextCtrl := GuiID_VoiceInput.Add("Text", "x" . TextX . " y" . BtnY . " w" . TextWidth . " h" . ButtonHeight . " Left 0x200 c" . EngineBtnTextColor . " BackgroundTrans", BtnText)
        TextCtrl.SetFont("s10", "Segoe UI")
        TextCtrl.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
        
        VoiceSearchEngineButtons.Push({Bg: Btn, Icon: IconCtrl, Text: TextCtrl, Index: Index})
    }
    
    ; 恢复窗口位置和大小
    WindowName := GetText("voice_search_title")
    RestoredPos := RestoreWindowPosition(WindowName, PanelWidth, PanelHeight)
    if (RestoredPos.X = -1 || RestoredPos.Y = -1) {
        ScreenInfo := GetScreenInfo(VoiceInputScreenIndex)
        Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "center")
        RestoredPos.X := Pos.X
        RestoredPos.Y := Pos.Y
    }
    GuiID_VoiceInput.Show("w" . RestoredPos.Width . " h" . RestoredPos.Height . " x" . RestoredPos.X . " y" . RestoredPos.Y)
    WinSetAlwaysOnTop(1, GuiID_VoiceInput.Hwnd)
    
    ; 添加 Escape 键关闭命令
    GuiID_VoiceInput.OnEvent("Escape", HideVoiceSearchInputPanel)
    
    ; 在窗口显示后绑定事件（避免初始化问题）
    try {
        GuiID_VoiceInput.OnEvent("Size", OnWindowSize)
        ; 注意：AutoHotkey v2 不支持 Move 事件，使用定时器定期保存位置
        ; GuiID_VoiceInput.OnEvent("Move", OnWindowMove)
        SetTimer(() => SaveVoiceInputPosition(), 500)
    } catch as err {
        ; 如果绑定失败，忽略错误（窗口仍然可以正常使用）
    }
    
    VoiceSearchInputEdit.Value := ""
    global VoiceSearchInputLastEditTime := 0
    
    SetTimer(MonitorSelectedText, 0)
    
    LegacyGuard_RequestFocus("VoiceInput", GuiID_VoiceInput.Hwnd, 30, "voice_input_gui", 120)
    Sleep(200)
    
    if (!WinActive("ahk_id " . GuiID_VoiceInput.Hwnd)) {
        LegacyGuard_RequestFocus("VoiceInput", GuiID_VoiceInput.Hwnd, 30, "voice_input_gui", 120)
        Sleep(200)
    }
    
    InputEditHwnd := VoiceSearchInputEdit.Hwnd
    
    try {
        ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
        Sleep(100)
    } catch as err {
        VoiceSearchInputEdit.Focus()
        Sleep(100)
    }
    
    try {
        ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
        Sleep(50)
    } catch as err {
        VoiceSearchInputEdit.Focus()
        Sleep(50)
    }
    
    ; 注意：自动加载功能已移除，不再启动定时器
    
    ; 自动激活语音输入
    try {
        Sleep(300)  ; 等待窗口完全显示和焦点设置完成
        StartVoiceInputInSearch()
    } catch as e {
        ; 如果启动语音输入失败，不影响面板显示
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; ===================== 语音搜索辅助函数 =====================
; 隐藏语音搜索输入界面
HideVoiceSearchInputPanel(*) {
    if FuncExists("VoiceInput_IsSearchFsmState") && VoiceInput_IsSearchFsmState()
        VoiceFSM_Dispatch("search_stop")
    else if FuncExists("VoiceInputEffect_DestroySearchPanel")
        VoiceInputEffect_DestroySearchPanel()
}

; 清空语音搜索输入框
ClearVoiceSearchInput(*) {
    global VoiceSearchInputEdit, VoiceSearchPanelVisible
    
    if (!VoiceSearchPanelVisible || !VoiceSearchInputEdit) {
        return
    }
    
    try {
        VoiceSearchInputEdit.Value := ""
        ; 重新聚焦到输入框
        VoiceSearchInputEdit.Focus()
    } catch as e {
        ; 忽略错误
    }
}

; 切换自动加载选中文本开关（已删除 - 语音搜索不再支持此功能）
; ToggleAutoLoadSelectedText 函数已删除

; 切换自动更新语音输入开关（已删除 - 语音搜索不再支持此功能）
; ToggleAutoUpdateVoiceInput 函数已删除

; 更新输入框最后编辑时间（用于检测用户是否正在输入）
UpdateVoiceSearchInputEditTime(*) {
    global VoiceSearchInputLastEditTime
    VoiceSearchInputLastEditTime := A_TickCount
}

; 监听选中文本并自动加载到输入框
MonitorSelectedText(*) {
    global AutoLoadSelectedText, VoiceSearchPanelVisible, GuiID_VoiceInput, VoiceSearchInputEdit
    global VoiceSearchInputLastEditTime
    
    ; 如果开关未开启或面板未显示，立即停止监听
    if (!AutoLoadSelectedText || !VoiceSearchPanelVisible || !GuiID_VoiceInput) {
        SetTimer(MonitorSelectedText, 0)
        return
    }
    
    ; 检测用户是否正在输入：如果输入框在最近2秒内被编辑过，说明用户正在输入，不自动加载
    CurrentTime := A_TickCount
    if (VoiceSearchInputLastEditTime > 0 && (CurrentTime - VoiceSearchInputLastEditTime) < 2000) {
        ; 用户正在输入（最近2秒内编辑过），不自动加载
        return
    }
    
    ; 检查输入框是否有内容，如果有内容且不是最近编辑的，也不自动加载（避免覆盖用户已输入的内容）
    try {
        if (VoiceSearchInputEdit && VoiceSearchInputEdit.Value != "") {
            ; 输入框有内容，且不是最近编辑的，不自动加载（避免覆盖用户输入）
            return
        }
    } catch as err {
        ; 忽略错误
    }
    
    ; 检查是否有选中的文本
    try {
        ; 保存当前剪贴板
        OldClipboard := A_Clipboard
        
        ; 尝试复制选中文本
        A_Clipboard := ""
        Send("^c")
        Sleep(50)  ; 等待复制完成
        
        ; 检查是否复制成功
        if (ClipWait(0.1) && A_Clipboard != "" && A_Clipboard != OldClipboard) {
            ; 有选中文本，加载到输入框
            SelectedText := A_Clipboard
            if (SelectedText != "" && StrLen(SelectedText) > 0) {
                ; 尝试获取输入框控件并更新
                try {
                    if (VoiceSearchInputEdit && (VoiceSearchInputEdit.Value = "" || VoiceSearchInputEdit.Value != SelectedText)) {
                        VoiceSearchInputEdit.Value := SelectedText
                    }
                } catch as err {
                    ; 忽略错误
                }
            }
        }
        
        ; 恢复剪贴板
        A_Clipboard := OldClipboard
    } catch as err {
        ; 忽略错误
    }
}

; 更新语音搜索输入框内容（定时器调用）
UpdateVoiceSearchInputInPanel(*) {
    global VoiceSearchActive, VoiceSearchInputEdit, VoiceSearchPanelVisible, AutoLoadSelectedText, AutoUpdateVoiceInput, GuiID_VoiceInput, VoiceInputMethod
    
    ; 如果"自动更新语音输入"和"自动加载选中文本"都未开启，停止定时器
    if (!AutoUpdateVoiceInput && !AutoLoadSelectedText) {
        SetTimer(UpdateVoiceSearchInputInPanel, 0)
        return
    }
    
    if (!VoiceSearchActive || !VoiceSearchPanelVisible || !VoiceSearchInputEdit) {
        SetTimer(UpdateVoiceSearchInputInPanel, 0)
        return
    }
    
    try {
        ; 检测百度输入法语音识别窗口是否存在
        BaiduVoiceWindowActive := false
        if (VoiceInputMethod = "baidu") {
            BaiduVoiceWindowActive := IsBaiduVoiceWindowActive()
        }
        
        ; 获取输入框的控件句柄
        InputEditHwnd := VoiceSearchInputEdit.Hwnd
        
        ; 如果百度输入法的语音识别窗口存在，使用ControlFocus确保输入框有输入焦点
        if (BaiduVoiceWindowActive) {
            if (GuiID_VoiceInput) {
                if (WinExist("ahk_id " . GuiID_VoiceInput.Hwnd)) {
                    try {
                        ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                        Sleep(20)
                    } catch as err {
                        try {
                            VoiceSearchInputEdit.Focus()
                            Sleep(20)
                        } catch as err {
                        }
                    }
                }
            }
        } else {
            ; 输入法窗口不存在时，正常激活主窗口并设置焦点
            if (GuiID_VoiceInput) {
                if (!WinActive("ahk_id " . GuiID_VoiceInput.Hwnd)) {
                    LegacyGuard_RequestFocus("VoiceInput", GuiID_VoiceInput.Hwnd, 30, "voice_input_gui", 120)
                    Sleep(100)
                }
                
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(50)
                } catch as err {
                    VoiceSearchInputEdit.Focus()
                    Sleep(50)
                }
            }
        }
        
        ; 尝试直接读取输入框内容
        OldClipboard := A_Clipboard
        CurrentContent := ""
        CurrentInputValue := ""
        
        try {
            CurrentInputValue := VoiceSearchInputEdit.Value
            CurrentContent := CurrentInputValue
        } catch as err {
            ; 如果直接读取失败，使用剪贴板方式
            if (!BaiduVoiceWindowActive && GuiID_VoiceInput) {
                if (!WinActive("ahk_id " . GuiID_VoiceInput.Hwnd)) {
                    LegacyGuard_RequestFocus("VoiceInput", GuiID_VoiceInput.Hwnd, 30, "voice_input_gui", 120)
                    Sleep(50)
                }
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(30)
                } catch as err {
                    VoiceSearchInputEdit.Focus()
                    Sleep(30)
                }
                
                Send("^a")
                Sleep(30)
                A_Clipboard := ""
                Send("^c")
                Sleep(80)
                
                if (ClipWait(0.15)) {
                    CurrentContent := A_Clipboard
                }
            }
        }
        
        ; 处理读取到的内容
        if (CurrentContent != "" && StrLen(CurrentContent) > 0) {
            ; 检查内容是否看起来像语音输入的内容
            if (CurrentInputValue = "" && (InStr(CurrentContent, "\") || InStr(CurrentContent, ".lnk") || InStr(CurrentContent, "快捷方式"))) {
                ; 忽略看起来像文件路径或快捷方式的内容
                A_Clipboard := OldClipboard
                return
            }
            
            ; 如果内容有变化且新内容更长，更新输入框
            if (CurrentContent != CurrentInputValue && StrLen(CurrentContent) >= StrLen(CurrentInputValue)) {
                try {
                    ; 在输入法窗口存在时，不更新输入框内容（避免干扰输入法）
                    if (!BaiduVoiceWindowActive) {
                        VoiceSearchInputEdit.Value := CurrentContent
                        ; 将光标移到末尾
                        try {
                            ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                            Sleep(20)
                            Send("^{End}")
                        } catch as err {
                        }
                    }
                } catch as err {
                }
            }
        }
        
        ; 恢复剪贴板
        A_Clipboard := OldClipboard
    } catch as err {
        ; 忽略错误
    }
}

; 创建切换搜索引擎选择处理函数
CreateToggleSearchEngineHandler(Engine, BtnIndex) {
    ToggleSearchEngineHandler(*) {
        global VoiceSearchSelectedEngines, VoiceSearchEngineButtons, UI_Colors
        global VoiceSearchCurrentCategory, VoiceSearchSelectedEnginesByCategory, ConfigFile
        
        ; 确保 VoiceSearchSelectedEnginesByCategory 已初始化
        if (!IsSet(VoiceSearchSelectedEnginesByCategory) || !IsObject(VoiceSearchSelectedEnginesByCategory)) {
            VoiceSearchSelectedEnginesByCategory := Map()
        }
        
        ; 切换选择状态
        FoundIndex := ArrayContainsValue(VoiceSearchSelectedEngines, Engine)
        if (FoundIndex > 0) {
            ; 取消选择
            VoiceSearchSelectedEngines.RemoveAt(FoundIndex)
        } else {
            ; 添加选择
            VoiceSearchSelectedEngines.Push(Engine)
        }
        
        ; 【关键修复】保存当前分类的选择状态到分类Map中
        if (VoiceSearchCurrentCategory != "") {
            CurrentEngines := []
            for Index, Eng in VoiceSearchSelectedEngines {
                CurrentEngines.Push(Eng)
            }
            VoiceSearchSelectedEnginesByCategory[VoiceSearchCurrentCategory] := CurrentEngines
        }
        
        ; 保存到配置文件（保存当前分类的选择状态）
        try {
            EnginesStr := ""
            for Index, Eng in VoiceSearchSelectedEngines {
                if (Index > 1) {
                    EnginesStr .= ","
                }
                EnginesStr .= Eng
            }
            if (EnginesStr = "") {
                EnginesStr := "deepseek"
            }
            ; 保存格式：分类:引擎1,引擎2
            CategoryEnginesStr := VoiceSearchCurrentCategory . ":" . EnginesStr
            IniWrite(CategoryEnginesStr, ConfigFile, "Settings", "VoiceSearchSelectedEngines_" . VoiceSearchCurrentCategory)
        } catch as e {
            TrayTip("保存搜索引擎选择失败: " . e.Message, "错误", "Iconx 1")
        }
        
        ; 更新按钮样式
        if (IsSet(VoiceSearchEngineButtons) && VoiceSearchEngineButtons.Length > 0 && BtnIndex <= VoiceSearchEngineButtons.Length) {
            BtnObj := VoiceSearchEngineButtons[BtnIndex]
            if (BtnObj && IsObject(BtnObj)) {
                IsSelected := (ArrayContainsValue(VoiceSearchSelectedEngines, Engine) > 0)
                
                ; 更新背景颜色
                if (BtnObj.Bg) {
                    BtnObj.Bg.BackColor := IsSelected ? UI_Colors.BtnHover : UI_Colors.BtnBg
                }
                
                ; 更新文字（添加/移除 ✓ 标记）
                if (BtnObj.Text) {
                    AllEngines := GetAllSearchEngines()
                    EngineName := ""
                    for Index, Eng in AllEngines {
                        if (Eng.Value = Engine) {
                            EngineName := Eng.Name
                            break
                        }
                    }
                    if (EngineName != "") {
                        BtnObj.Text.Text := IsSelected ? "✓ " . EngineName : EngineName
                    }
                }
            }
        }
        
        ; 立即刷新GUI
        try {
            global GuiID_VoiceInput
            if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
                WinRedraw(GuiID_VoiceInput.Hwnd)
            }
        } catch as err {
        }
    }
    return ToggleSearchEngineHandler
}

; 清空所有搜索引擎选择
ClearAllSearchEngineSelection(*) {
    global VoiceSearchSelectedEngines, VoiceSearchEngineButtons, UI_Colors, GuiID_VoiceInput
    global ConfigFile, VoiceSearchCurrentCategory
    
    ; 清空选择数组
    VoiceSearchSelectedEngines := []
    
    ; 保存到配置文件
    try {
        IniWrite("deepseek", ConfigFile, "Settings", "VoiceSearchSelectedEngines")
    } catch as e {
    }
    
    ; 更新所有按钮的样式
    if (IsSet(VoiceSearchEngineButtons) && VoiceSearchEngineButtons.Length > 0) {
        try {
            CurrentEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
        } catch as err {
            CurrentEngines := []
        }
        
        for Index, BtnObj in VoiceSearchEngineButtons {
            if (BtnObj && IsObject(BtnObj)) {
                try {
                    if (BtnObj.Bg && IsObject(BtnObj.Bg)) {
                        BtnObj.Bg.BackColor := UI_Colors.BtnBg
                    }
                } catch as err {
                }
                
                try {
                    if (BtnObj.Text && IsObject(BtnObj.Text) && BtnObj.Index > 0 && BtnObj.Index <= CurrentEngines.Length) {
                        EngineName := CurrentEngines[BtnObj.Index].Name
                        if (EngineName != "") {
                            CurrentText := BtnObj.Text.Text
                            if (SubStr(CurrentText, 1, 2) = "✓ ") {
                                BtnObj.Text.Text := EngineName
                            } else {
                                BtnObj.Text.Text := EngineName
                            }
                        }
                    }
                } catch as err {
                }
            }
        }
    }
    
    ; 立即刷新GUI
    try {
        if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
            WinRedraw(GuiID_VoiceInput.Hwnd)
        }
    } catch as err {
    }
    
; 显示提示
TrayTip(GetText("cleared"), GetText("tip"), "Iconi 1")
}

OpenAdminWindowsPowerShell() {
    PowerShellPath := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
    if (!FileExist(PowerShellPath)) {
        throw Error("找不到 Windows PowerShell")
    }
    Run('*RunAs "' . PowerShellPath . '"')
}


; --- CLI：Module 仅转发，实现在 VoiceInputCliEffects.ahk ---
LaunchSelectedCLIAgents(PromptText := "") {
    act := (PromptText != "") ? "send" : "open"
    VoiceInputEffect_DispatchCliAgents(PromptText, act)
}

OpenSelectedCLIAgents(*) {
    LaunchSelectedCLIAgents("")
}


; 发送语音搜索内容到浏览器（副作用在 effect 层）
SendVoiceSearchToBrowser(Content, Engine) {
    if FuncExists("VoiceInputEffect_SendSearchToBrowser")
        VoiceInputEffect_SendSearchToBrowser(Content, Engine)
}
SwitchToChineseIME(*) {
    try {
        global GuiID_VoiceInput, VoiceSearchInputEdit
        if (GuiID_VoiceInput && VoiceSearchInputEdit) {
            LegacyGuard_RequestFocus("VoiceInput", GuiID_VoiceInput.Hwnd, 30, "voice_input_gui", 120)
            Sleep(50)
            VoiceSearchInputEdit.Focus()
            Sleep(50)
            ActiveHwnd := GuiID_VoiceInput.Hwnd
        } else {
            ActiveHwnd := WinGetID("A")
        }
        
        if (!ActiveHwnd) {
            return
        }
        
        ; 使用 Windows IME API 切换到中文输入法
        hIMC := DllCall("imm32\ImmGetContext", "Ptr", ActiveHwnd, "Ptr")
        if (hIMC) {
            DllCall("imm32\ImmGetConversionStatus", "Ptr", hIMC, "UInt*", &ConversionMode := 0, "UInt*", &SentenceMode := 0)
            ConversionMode := ConversionMode | 0x0001  ; IME_CMODE_NATIVE
            DllCall("imm32\ImmSetConversionStatus", "Ptr", hIMC, "UInt", ConversionMode, "UInt", SentenceMode)
            DllCall("imm32\ImmReleaseContext", "Ptr", ActiveHwnd, "Ptr", hIMC)
        }
        
        ; 尝试切换到中文键盘布局
        try {
            hKL := DllCall("user32\LoadKeyboardLayout", "Str", "00000804", "UInt", 0x00000001, "Ptr")
            if (hKL) {
                PostMessage(0x0050, 0x0001, hKL, , , "ahk_id " . ActiveHwnd)
            }
        } catch as err {
        }
    } catch as err {
    }
}
; 检测百度输入法语音识别窗口是否激活
IsBaiduVoiceWindowActive() {
    ; 检测百度输入法的语音识别窗口
    AllWindows := WinGetList()
    for Index, Hwnd in AllWindows {
        try {
            WinTitle := WinGetTitle("ahk_id " . Hwnd)
            ; 检查窗口标题是否包含语音识别相关关键词
            if (InStr(WinTitle, "正在识别") || InStr(WinTitle, "说完了") || InStr(WinTitle, "语音输入")) {
                ; 进一步检查窗口是否可见且处于活动状态
                if (WinExist("ahk_id " . Hwnd)) {
                    IsVisible := WinGetMinMax("ahk_id " . Hwnd)
                    if (IsVisible != -1) {  ; -1 表示最小化
                        return true
                    }
                }
            }
        } catch as err {
            ; 忽略错误，继续检测下一个窗口
        }
    }
    
    ; 通过窗口类名检测百度输入法相关窗口
    BaiduClasses := ["BaiduIME", "BaiduPinyin", "BaiduInput", "#32770"]
    for Index, ClassName in BaiduClasses {
        if (WinExist("ahk_class " . ClassName)) {
            try {
                WinTitle := WinGetTitle("ahk_class " . ClassName)
                if (InStr(WinTitle, "正在识别") || InStr(WinTitle, "说完了") || InStr(WinTitle, "语音输入")) {
                    return true
                }
            } catch as err {
            }
        }
    }
    
    return false
}
; URL编码函数（使用 UTF-8 编码，正确处理中文）
UriEncode(Uri) {
    try {
        ; 方法1：使用 JavaScript encodeURIComponent（如果可用）
        try {
            js := ComObject("MSScriptControl.ScriptControl")
            js.Language := "JScript"
            ; 转义单引号，防止 JavaScript 错误
            EscapedUri := StrReplace(Uri, "\", "\\")
            EscapedUri := StrReplace(EscapedUri, "'", "\'")
            EscapedUri := StrReplace(EscapedUri, "`n", "\n")
            EscapedUri := StrReplace(EscapedUri, "`r", "\r")
            Encoded := js.Eval("encodeURIComponent('" . EscapedUri . "')")
            return Encoded
        } catch as err {
            ; 方法2：手动 UTF-8 编码（更可靠的备用方案）
            Encoded := ""
            ; 将字符串转换为 UTF-8 字节数组
            UTF8Size := StrPut(Uri, "UTF-8")
            UTF8Bytes := Buffer(UTF8Size)
            StrPut(Uri, UTF8Bytes, "UTF-8")
            
            ; 遍历每个字节进行编码
            Loop UTF8Size - 1 {  ; -1 因为 StrPut 返回的大小包括 null 终止符
                Byte := NumGet(UTF8Bytes, A_Index - 1, "UChar")
                ; 保留字符：字母、数字、-、_、.、~（根据 RFC 3986）
                if ((Byte >= 48 && Byte <= 57) || (Byte >= 65 && Byte <= 90) || (Byte >= 97 && Byte <= 122) || Byte = 45 || Byte = 95 || Byte = 46 || Byte = 126) {
                    Encoded .= Chr(Byte)
                } else if (Byte = 32) {
                    ; 空格编码为 +
                    Encoded .= "+"
                } else {
                    ; URL编码：%XX（大写）
                    Encoded .= "%" . Format("{:02X}", Byte)
                }
            }
            return Encoded
        }
    } catch as err {
        ; 如果编码失败，返回原始字符串
        return Uri
    }
}

; CLI 副作用由主脚本在 NiumaTtyd 之前 #Include VoiceInputCliEffects.ahk
