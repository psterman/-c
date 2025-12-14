; ===================== 基础配置 =====================
#SingleInstance Force
SetTitleMatchMode(2)
SetControlDelay(-1)
SetKeyDelay(20, 20)
SetMouseDelay(10)
SendMode("Input")
DetectHiddenWindows(true)

; ===================== 管理员权限检查 =====================
; 如果脚本不是以管理员权限运行，则重新以管理员权限启动
if (!A_IsAdmin) {
    try {
        ; 使用 RunAs 以管理员权限重新运行脚本
        Run('*RunAs "' . A_ScriptFullPath . '"')
        ExitApp()
    } catch as e {
        MsgBox("无法以管理员权限运行脚本。某些功能可能无法正常工作。`n错误: " . e.Message, "警告", "Icon!")
    }
}

; 全局变量（v2用Class/全局变量管理）
global CapsLockDownTime := 0
global IsCommandMode := false
global PanelVisible := false
global GuiID_CursorPanel := 0
global ConfigFile := A_ScriptDir "\CursorShortcut.ini"
global TrayIconPath := A_ScriptDir "\cursor_helper.ico"
; CapsLock+ 方案的核心变量
global CapsLock := false  ; CapsLock 键状态标记，按下是 true，松开是 false
global CapsLock2 := false  ; 是否使用过 CapsLock+ 功能标记，使用过会清除这个变量
; 动态快捷键映射（默认值）
global SplitHotkey := "s"
global BatchHotkey := "b"
; 配置变量
global CursorPath := ""
global AISleepTime := 15000
global Prompt_Explain := ""
global Prompt_Refactor := ""
global Prompt_Optimize := ""
; 面板位置和屏幕配置
global PanelScreenIndex := 1  ; 屏幕索引（1为主屏幕）
global PanelPosition := "center"  ; 位置：center, top-left, top-right, bottom-left, bottom-right, custom
global PanelX := -1  ; 自定义 X 坐标（-1 表示使用默认位置）
global PanelY := -1  ; 自定义 Y 坐标（-1 表示使用默认位置）
; 连续复制功能
global ClipboardHistory := []  ; 存储所有复制的内容
global GuiID_ClipboardManager := 0  ; 剪贴板管理面板 GUI ID

; ===================== 初始化配置 =====================
InitConfig() {
    ; 1. 默认配置
    DefaultCursorPath := "C:\Users\" A_UserName "\AppData\Local\Cursor\Cursor.exe"
    DefaultAISleepTime := 15000
    DefaultPrompt_Explain := "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点"
    DefaultPrompt_Refactor := "重构这段代码，遵循PEP8/行业规范，简化冗余逻辑，添加中文注释，保持功能不变"
    DefaultPrompt_Optimize := "分析这段代码的性能瓶颈（时间/空间复杂度），给出优化方案+对比说明，保留原逻辑可读性"
    DefaultSplitHotkey := "s"
    DefaultBatchHotkey := "b"
    DefaultPanelScreenIndex := 1
    DefaultPanelPosition := "center"
    DefaultPanelX := -1
    DefaultPanelY := -1

    ; 2. 无配置文件则创建
    if !FileExist(ConfigFile) {
        IniWrite(DefaultCursorPath, ConfigFile, "Settings", "CursorPath")
        IniWrite(DefaultAISleepTime, ConfigFile, "Settings", "AISleepTime")
        IniWrite(DefaultPrompt_Explain, ConfigFile, "Settings", "Prompt_Explain")
        IniWrite(DefaultPrompt_Refactor, ConfigFile, "Settings", "Prompt_Refactor")
        IniWrite(DefaultPrompt_Optimize, ConfigFile, "Settings", "Prompt_Optimize")
        IniWrite(DefaultSplitHotkey, ConfigFile, "Settings", "SplitHotkey")
        IniWrite(DefaultBatchHotkey, ConfigFile, "Settings", "BatchHotkey")
        IniWrite(DefaultPanelScreenIndex, ConfigFile, "Panel", "ScreenIndex")
        IniWrite(DefaultPanelPosition, ConfigFile, "Panel", "Position")
        IniWrite(DefaultPanelX, ConfigFile, "Panel", "X")
        IniWrite(DefaultPanelY, ConfigFile, "Panel", "Y")
    }

    ; 3. 加载配置（v2的IniRead返回值更直观）
    ; 注意：IniRead 返回的是字符串，需要转换为相应的类型
    global CursorPath := IniRead(ConfigFile, "Settings", "CursorPath", DefaultCursorPath)
    global AISleepTime := Integer(IniRead(ConfigFile, "Settings", "AISleepTime", DefaultAISleepTime))
    global Prompt_Explain := IniRead(ConfigFile, "Settings", "Prompt_Explain", DefaultPrompt_Explain)
    global Prompt_Refactor := IniRead(ConfigFile, "Settings", "Prompt_Refactor", DefaultPrompt_Refactor)
    global Prompt_Optimize := IniRead(ConfigFile, "Settings", "Prompt_Optimize", DefaultPrompt_Optimize)
    global SplitHotkey := IniRead(ConfigFile, "Settings", "SplitHotkey", DefaultSplitHotkey)
    global BatchHotkey := IniRead(ConfigFile, "Settings", "BatchHotkey", DefaultBatchHotkey)
    global PanelScreenIndex := Integer(IniRead(ConfigFile, "Panel", "ScreenIndex", DefaultPanelScreenIndex))
    global PanelPosition := IniRead(ConfigFile, "Panel", "Position", DefaultPanelPosition)
    global PanelX := Integer(IniRead(ConfigFile, "Panel", "X", DefaultPanelX))
    global PanelY := Integer(IniRead(ConfigFile, "Panel", "Y", DefaultPanelY))
}

InitConfig() ; 启动初始化

; ===================== 托盘图标配置 =====================
A_TrayMenu.Add("打开配置面板", (*) => ShowConfigGUI())
A_TrayMenu.Add("退出工具", (*) => CleanUp())
A_TrayMenu.Default := "退出工具"   ; 字符串即可
A_IconTip := "Cursor快捷工具（长按CapsLock调出面板）"

; ===================== CapsLock核心逻辑 =====================
; 定时器函数定义（需要在 CapsLock 处理函数外部定义）
ClearCapsLock2Timer(*) {
    global CapsLock2 := false
}

ShowPanelTimer(*) {
    global CapsLock, PanelVisible
    if (CapsLock && !PanelVisible) {
        ShowCursorPanel()
    }
}

; 采用 CapsLock+ 方案：使用 ~ 前缀保留原始功能，通过标记变量控制行为
~CapsLock:: {
    global CapsLock, CapsLock2, IsCommandMode, PanelVisible
    
    ; 标记 CapsLock 已按下
    CapsLock := true
    CapsLock2 := true  ; 初始化为 true，如果使用了功能会被清除
    IsCommandMode := false
    
    ; 设置定时器：300ms 后清除 CapsLock2（犹豫操作时间）
    ; 如果在这 300ms 内使用了 CapsLock+ 功能，CapsLock2 会被提前清除
    SetTimer(ClearCapsLock2Timer, -300)
    
    ; 设置定时器：长按 0.5 秒后自动显示面板
    SetTimer(ShowPanelTimer, -500)
    
    ; 等待 CapsLock 释放
    KeyWait("CapsLock")
    
    ; 停止所有定时器
    SetTimer(ClearCapsLock2Timer, 0)
    SetTimer(ShowPanelTimer, 0)
    
    ; CapsLock 最优先置空，来关闭 CapsLock+ 功能的触发
    CapsLock := false
    
    ; 如果 CapsLock2 还存在（说明没有使用过 CapsLock+ 功能），就切换大小写
    if (CapsLock2) {
        ; 切换 CapsLock 状态
        SetCapsLockState(GetKeyState("CapsLock", "T") ? "Off" : "On")
    }
    
    ; 清除标记
    CapsLock2 := false
    
    ; 如果面板还在显示，隐藏它
    if (PanelVisible) {
        HideCursorPanel()
    }
    IsCommandMode := false
}

; ===================== 多屏幕支持函数 =====================
GetScreenInfo(ScreenIndex) {
    ; 获取指定屏幕的信息
    ; ScreenIndex: 1=主屏幕, 2=第二个屏幕, 等等
    ; 使用 MonitorGet 函数（AutoHotkey v2）
    try {
        MonitorGet(ScreenIndex, &Left, &Top, &Right, &Bottom)
        return {Left: Left, Top: Top, Right: Right, Bottom: Bottom, Width: Right - Left, Height: Bottom - Top}
    } catch as e {
        ; 如果失败，使用主屏幕
        try {
            MonitorGet(1, &Left, &Top, &Right, &Bottom)
            return {Left: Left, Top: Top, Right: Right, Bottom: Bottom, Width: Right - Left, Height: Bottom - Top}
        } catch {
            ; 如果还是失败，使用默认屏幕尺寸
            return {Left: 0, Top: 0, Right: A_ScreenWidth, Bottom: A_ScreenHeight, Width: A_ScreenWidth, Height: A_ScreenHeight}
        }
    }
}

GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight) {
    ; 面板始终居中显示
    return {X: ScreenInfo.Left + (ScreenInfo.Width - PanelWidth) // 2, Y: ScreenInfo.Top + (ScreenInfo.Height - PanelHeight) // 2}
}

; ===================== 显示面板函数 =====================
ShowCursorPanel() {
    global PanelVisible, GuiID_CursorPanel, SplitHotkey, BatchHotkey, CapsLock2
    global PanelScreenIndex, PanelPosition
    
    if (PanelVisible) {
        return
    }
    
    CapsLock2 := false  ; 清除标记，表示使用了功能（显示面板）
    PanelVisible := true
    
    ; 面板尺寸（Cursor 风格，更紧凑现代）
    PanelWidth := 420
    PanelHeight := 370  ; 增加高度以容纳配置按钮
    
    ; 创建 GUI（如果不存在）
    if (GuiID_CursorPanel = 0) {
        ; Cursor 风格的深色主题
        GuiID_CursorPanel := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
        GuiID_CursorPanel.BackColor := "1e1e1e"  ; Cursor 的主背景色
        GuiID_CursorPanel.SetFont("s11 cCCCCCC", "Segoe UI")  ; Cursor 使用的字体
        
        ; 添加圆角和阴影效果（通过边框实现）
        ; 标题区域
        TitleBg := GuiID_CursorPanel.Add("Text", "x0 y0 w420 h50 Background1e1e1e", "")
        TitleText := GuiID_CursorPanel.Add("Text", "x20 y12 w380 h26 Center cFFFFFF", "Cursor 快捷操作")
        TitleText.SetFont("s13 Bold", "Segoe UI")
        
        ; 分隔线
        GuiID_CursorPanel.Add("Text", "x0 y50 w420 h1 Background3c3c3c", "")
        
        ; 提示文本（更小的字体，更柔和的颜色）
        HintText := GuiID_CursorPanel.Add("Text", "x20 y60 w380 h18 Center c888888", "按 " . SplitHotkey . " 分割 | 按 " . BatchHotkey . " 批量操作")
        HintText.SetFont("s9", "Segoe UI")
        
        ; 按钮区域（Cursor 风格的按钮）
        ; 解释代码按钮
        BtnExplain := GuiID_CursorPanel.Add("Button", "x30 y90 w360 h42", "解释代码 (E)")
        BtnExplain.SetFont("s11 cFFFFFF", "Segoe UI")
        BtnExplain.OnEvent("Click", (*) => ExecutePrompt("Explain"))
        
        ; 重构代码按钮
        BtnRefactor := GuiID_CursorPanel.Add("Button", "x30 y140 w360 h42", "重构代码 (R)")
        BtnRefactor.SetFont("s11 cFFFFFF", "Segoe UI")
        BtnRefactor.OnEvent("Click", (*) => ExecutePrompt("Refactor"))
        
        ; 优化代码按钮
        BtnOptimize := GuiID_CursorPanel.Add("Button", "x30 y190 w360 h42", "优化代码 (O)")
        BtnOptimize.SetFont("s11 cFFFFFF", "Segoe UI")
        BtnOptimize.OnEvent("Click", (*) => ExecutePrompt("Optimize"))
        
        ; 配置面板按钮
        BtnConfig := GuiID_CursorPanel.Add("Button", "x30 y240 w360 h36", "⚙️ 打开配置面板 (Q)")
        BtnConfig.SetFont("s10 cFFFFFF", "Segoe UI")
        BtnConfig.OnEvent("Click", OpenConfigFromPanel)
        
        ; 底部提示文本
        FooterText := GuiID_CursorPanel.Add("Text", "x20 y290 w380 h50 Center c666666", "按 ESC 关闭面板 | 按 Q 打开配置`n先选中代码再操作")
        FooterText.SetFont("s9", "Segoe UI")
        
        ; 底部边框
        GuiID_CursorPanel.Add("Text", "x0 y360 w420 h10 Background1e1e1e", "")
    }
    
    ; 获取屏幕信息并计算位置
    ScreenInfo := GetScreenInfo(PanelScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight)
    
    ; 显示面板
    GuiID_CursorPanel.Show("w" . PanelWidth . " h" . PanelHeight . " x" . Pos.X . " y" . Pos.Y)
}

; ===================== 隐藏面板函数 =====================
HideCursorPanel() {
    global PanelVisible, GuiID_CursorPanel
    
    if (!PanelVisible) {
        return
    }
    
    PanelVisible := false
    
    ; 停止动态快捷键监听
    StopDynamicHotkeys()
    
    if (GuiID_CursorPanel != 0) {
        try {
            GuiID_CursorPanel.Hide()
        }
    }
}

; ===================== 从面板打开配置 =====================
OpenConfigFromPanel(*) {
    HideCursorPanel()
    ShowConfigGUI()
}

; ===================== 执行提示词函数 =====================
ExecutePrompt(Type) {
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize, CursorPath, AISleepTime, IsCommandMode, CapsLock2
    
    ; 清除标记，表示使用了功能
    CapsLock2 := false
    ; 标记命令模式结束，避免 CapsLock 释放后再次隐藏面板
    IsCommandMode := false
    
    HideCursorPanel()
    
    ; 根据类型选择提示词
    Prompt := ""
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
    
    if (Prompt = "") {
        return
    }
    
    ; 在切换窗口之前，先保存当前剪贴板内容并尝试复制选中文本
    ; 这样可以确保即使切换窗口后失去选中状态，也能获取到之前选中的文本
    OldClipboard := A_Clipboard
    SelectedCode := ""
    
    ; 尝试从当前活动窗口复制选中文本（如果 Cursor 是活动窗口，直接复制）
    if WinActive("ahk_exe Cursor.exe") {
        ; 如果 Cursor 已经是活动窗口，直接复制
        ; 先按 ESC 确保没有输入框打开，避免复制操作关闭输入框
        Send("{Esc}")
        Sleep(50)
        Send("^c")
        Sleep(150)
        SelectedCode := A_Clipboard
    } else {
        ; 如果 Cursor 不是活动窗口，先尝试从当前窗口复制
        ; 保存当前活动窗口
        CurrentActiveWindow := WinGetID("A")
        ; 从当前窗口复制（不切换窗口，避免影响用户操作）
        Send("^c")
        Sleep(200)  ; 增加等待时间，确保复制完成
        TempSelectedCode := A_Clipboard
        
        ; 如果复制到了新内容（不是旧的剪贴板内容），说明有选中文本
        if (TempSelectedCode != "" && TempSelectedCode != OldClipboard && StrLen(TempSelectedCode) > 0) {
            SelectedCode := TempSelectedCode
        }
    }
    
    ; 激活 Cursor 窗口
    try {
        if WinExist("ahk_exe Cursor.exe") {
            ; 先激活窗口，等待窗口完全激活
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 1)  ; 等待窗口激活，最多等待1秒
            Sleep(200)  ; 额外等待，确保窗口完全就绪
            
            ; 如果之前没有获取到选中文本，再次尝试复制（可能用户在 Cursor 中选中了文本）
            ; 注意：只在 Cursor 窗口内复制，避免影响其他窗口
            if ((SelectedCode = "" || SelectedCode = OldClipboard) && WinActive("ahk_exe Cursor.exe")) {
                ; 先按 ESC 确保没有输入框打开，避免复制操作关闭输入框
                Send("{Esc}")
                Sleep(50)
                Send("^c")
                Sleep(150)
                NewSelectedCode := A_Clipboard
                ; 如果获取到了新内容，使用新内容
                if (NewSelectedCode != "" && NewSelectedCode != OldClipboard && StrLen(NewSelectedCode) > 0) {
                    SelectedCode := NewSelectedCode
                }
            }
            
            ; 构建完整的提示词（包含选中的代码）
            if (SelectedCode != "" && SelectedCode != OldClipboard && StrLen(SelectedCode) > 0) {
                ; 在 AutoHotkey 中，反引号需要转义：一个反引号用两个反引号表示
                ; 三个反引号需要用六个反引号：``````
                CodeBlockStart := "``````"
                CodeBlockEnd := "``````"
                FullPrompt := Prompt . "`n`n以下是选中的代码：`n" . CodeBlockStart . "`n" . SelectedCode . "`n" . CodeBlockEnd
            } else {
                FullPrompt := Prompt
            }
            
            ; 复制完整提示词到剪贴板
            A_Clipboard := FullPrompt
            Sleep(100)
            
            ; 确保 Cursor 窗口仍然激活
            if !WinActive("ahk_exe Cursor.exe") {
                WinActivate("ahk_exe Cursor.exe")
                Sleep(200)
            }
            
            ; 先按 ESC 关闭可能已打开的输入框，避免冲突
            Send("{Esc}")
            Sleep(100)
            
            ; 尝试打开 Cursor 的 AI 聊天面板（通常是 Ctrl+L 或 Ctrl+K）
            ; 如果快捷键无效，用户需要手动打开聊天面板
            Send("^l")
            Sleep(400)  ; 增加等待时间，确保聊天面板完全打开
            
            ; 如果 Ctrl+L 无效，尝试 Ctrl+K（某些版本的 Cursor 可能使用 Ctrl+K）
            ; 可以通过检查输入框是否打开来判断
            ; 这里先不尝试，因为可能会打开命令面板而不是聊天面板
            
            ; 再次确保窗口激活（防止在等待期间窗口失去焦点）
            if !WinActive("ahk_exe Cursor.exe") {
                WinActivate("ahk_exe Cursor.exe")
                Sleep(200)
            }
            
            ; 粘贴提示词
            Send("^v")
            Sleep(200)  ; 增加等待时间，确保粘贴完成
            
            ; 发送 Enter 提交
            Send("{Enter}")
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

; ===================== 分割代码功能 =====================
SplitCode() {
    global CursorPath, AISleepTime, CapsLock2
    
    CapsLock2 := false  ; 清除标记，表示使用了功能
    HideCursorPanel()
    
    try {
        if WinExist("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            Sleep(200)
            
            ; 复制选中的代码
            OldClipboard := A_Clipboard
            Send("^c")
            Sleep(100)
            SelectedCode := A_Clipboard
            
            if (SelectedCode = "" || SelectedCode = OldClipboard) {
                TrayTip("请先选中要分割的代码", "提示", "Iconi")
                return
            }
            
            ; 在 Cursor 中，可以通过插入分隔符来分割代码
            ; 这里我们插入一个明显的分隔注释
            Separator := "`n`n; ==================== 分割线 ====================`n`n"
            
            ; 将分隔符插入到剪贴板内容中（在每行之间插入，或者简单地在末尾插入）
            ; 这里我们选择在选中区域后插入分隔符
            Send("{Right}")
            Send("{Enter}")
            A_Clipboard := Separator
            Sleep(100)
            Send("^v")
            
            TrayTip("已插入分割标记", "提示", "Iconi")
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

; ===================== 配置面板函数 =====================
ShowConfigGUI() {
    global CursorPath, AISleepTime, Prompt_Explain, Prompt_Refactor, Prompt_Optimize
    global SplitHotkey, BatchHotkey, ConfigFile
    global PanelScreenIndex, PanelPosition
    
    ; 创建配置 GUI（使用更大的窗口和更好的布局）
    ConfigGUI := Gui("+Resize -MaximizeBox", "Cursor 快捷工具 - 配置面板")
    ConfigGUI.SetFont("s10", "Microsoft YaHei UI")
    ConfigGUI.BackColor := "F0F0F0"
    
    ; ========== 基础设置区域 ==========
    Title1 := ConfigGUI.Add("Text", "x20 y15 w500 h25", "📁 基础设置")
    Title1.SetFont("s10 Bold", "Microsoft YaHei UI")
    ConfigGUI.Add("GroupBox", "x15 y40 w510 h100", "应用程序路径")
    
    ConfigGUI.Add("Text", "x25 y65 w80 h25", "Cursor 路径:")
    CursorPathEdit := ConfigGUI.Add("Edit", "x110 y63 w350 h25 vCursorPathEdit", CursorPath)
    BtnBrowse := ConfigGUI.Add("Button", "x470 y63 w50 h25", "浏览...")
    BtnBrowse.OnEvent("Click", (*) => BrowseCursorPath())
    
    ConfigGUI.Add("Text", "x25 y95 w480 h20 c666666", "提示：如果 Cursor 安装在非默认位置，请点击「浏览」按钮选择")
    
    ; ========== 性能设置区域 ==========
    Title2 := ConfigGUI.Add("Text", "x20 y150 w500 h25", "⚡ 性能设置")
    Title2.SetFont("s10 Bold", "Microsoft YaHei UI")
    ConfigGUI.Add("GroupBox", "x15 y175 w510 h80", "AI 响应等待时间")
    
    ConfigGUI.Add("Text", "x25 y200 w200 h25", "AI 响应等待时间 (毫秒):")
    AISleepTimeEdit := ConfigGUI.Add("Edit", "x230 y198 w100 h25 vAISleepTimeEdit", AISleepTime)
    ConfigGUI.Add("Text", "x340 y200 w180 h25 c666666", "建议：低配机 20000，高配机 10000")
    
    ; ========== 提示词设置区域 ==========
    Title3 := ConfigGUI.Add("Text", "x20 y270 w500 h25", "💬 提示词设置")
    Title3.SetFont("s10 Bold", "Microsoft YaHei UI")
    ConfigGUI.Add("GroupBox", "x15 y295 w510 h280", "AI 提示词配置")
    
    ConfigGUI.Add("Text", "x25 y320 w200 h25", "解释代码提示词:")
    PromptExplainEdit := ConfigGUI.Add("Edit", "x25 y345 w460 h60 vPromptExplainEdit", Prompt_Explain)
    
    ConfigGUI.Add("Text", "x25 y415 w200 h25", "重构代码提示词:")
    PromptRefactorEdit := ConfigGUI.Add("Edit", "x25 y440 w460 h60 vPromptRefactorEdit", Prompt_Refactor)
    
    ConfigGUI.Add("Text", "x25 y510 w200 h25", "优化代码提示词:")
    PromptOptimizeEdit := ConfigGUI.Add("Edit", "x25 y535 w460 h60 vPromptOptimizeEdit", Prompt_Optimize)
    
    ; ========== 快捷键设置区域 ==========
    Title4 := ConfigGUI.Add("Text", "x20 y590 w500 h25", "⌨️ 快捷键设置")
    Title4.SetFont("s10 Bold", "Microsoft YaHei UI")
    ConfigGUI.Add("GroupBox", "x15 y615 w510 h60", "自定义快捷键")
    
    ConfigGUI.Add("Text", "x25 y640 w150 h25", "分割快捷键:")
    SplitHotkeyEdit := ConfigGUI.Add("Edit", "x180 y638 w80 h25 vSplitHotkeyEdit", SplitHotkey)
    ConfigGUI.Add("Text", "x270 y640 w200 h25 c666666", "（单个字符，默认: s）")
    
    ConfigGUI.Add("Text", "x25 y670 w150 h25", "批量操作快捷键:")
    BatchHotkeyEdit := ConfigGUI.Add("Edit", "x180 y668 w80 h25 vBatchHotkeyEdit", BatchHotkey)
    ConfigGUI.Add("Text", "x270 y670 w200 h25 c666666", "（单个字符，默认: b）")
    
    ; ========== 面板位置设置区域 ==========
    Title5 := ConfigGUI.Add("Text", "x20 y730 w500 h25", "🖥️ 面板位置设置")
    Title5.SetFont("s10 Bold", "Microsoft YaHei UI")
    ConfigGUI.Add("GroupBox", "x15 y755 w510 h60", "面板显示位置")
    
    ; 屏幕选择
    ; 获取屏幕数量（使用 MonitorGetCount 获取准确的屏幕数量）
    ScreenList := []
    MonitorCount := 0
    try {
        MonitorCount := MonitorGetCount()
        if (MonitorCount > 0) {
            Loop MonitorCount {
                MonitorIndex := A_Index
                MonitorGet(MonitorIndex, &Left, &Top, &Right, &Bottom)
                ScreenList.Push("屏幕 " . MonitorIndex)
            }
        }
    } catch as e {
        ; 如果 MonitorGetCount 失败，尝试直接检测
        MonitorIndex := 1
        Loop 10 {
            try {
                MonitorGet(MonitorIndex, &Left, &Top, &Right, &Bottom)
                ScreenList.Push("屏幕 " . MonitorIndex)
                MonitorCount++
                MonitorIndex++
            } catch {
                break
            }
        }
    }
    ; 如果至少有一个屏幕，确保有选项
    if (ScreenList.Length = 0) {
        ScreenList.Push("屏幕 1")  ; 至少添加主屏幕
        MonitorCount := 1
    }
    ; 显示检测到的屏幕数量（用于调试）
    ScreenLabelText := "显示屏幕:"
    if (MonitorCount > 0) {
        ScreenLabelText := "显示屏幕 (检测到: " . MonitorCount . "):"
    }
    ConfigGUI.Add("Text", "x25 y780 w200 h25", ScreenLabelText)
    ; 确保 PanelScreenIndex 在有效范围内
    if (PanelScreenIndex < 1 || PanelScreenIndex > ScreenList.Length) {
        PanelScreenIndex := 1
    }
    ; 使用 Radio 按钮组替代下拉菜单
    global PanelScreenRadio := []
    StartX := 230
    StartY := 778
    RadioWidth := 80
    RadioHeight := 25
    Spacing := 5
    for Index, ScreenName in ScreenList {
        XPos := StartX + (Index - 1) * (RadioWidth + Spacing)
        RadioBtn := ConfigGUI.Add("Radio", "x" . XPos . " y" . StartY . " w" . RadioWidth . " h" . RadioHeight . " vPanelScreenRadio" . Index, ScreenName)
        if (Index = PanelScreenIndex) {
            RadioBtn.Value := 1
        }
        PanelScreenRadio.Push(RadioBtn)
    }
    
    ; 位置选择功能已移除，面板始终居中显示
    
    ; ========== 按钮区域 ==========
    BtnReset := ConfigGUI.Add("Button", "x20 y890 w100 h35", "重置默认")
    BtnSave := ConfigGUI.Add("Button", "x200 y890 w100 h35", "保存配置")
    BtnCancel := ConfigGUI.Add("Button", "x320 y890 w100 h35", "取消")
    BtnHelp := ConfigGUI.Add("Button", "x440 y890 w80 h35", "使用说明")
    
    ; 绑定按钮事件
    BtnReset.OnEvent("Click", ResetToDefaults)
    BtnSave.OnEvent("Click", SaveConfig)
    BtnCancel.OnEvent("Click", (*) => ConfigGUI.Destroy())
    BtnHelp.OnEvent("Click", ShowHelp)
    
    ConfigGUI.Show("w540 h940")
    
    ; ========== 浏览 Cursor 路径 ==========
    BrowseCursorPath(*) {
        FilePath := FileSelect(1, , "选择 Cursor.exe", "可执行文件 (*.exe)")
        if (FilePath != "") {
            CursorPathEdit.Value := FilePath
        }
    }
    
    ; ========== 重置为默认值 ==========
    ResetToDefaults(*) {
        DefaultCursorPath := "C:\Users\" A_UserName "\AppData\Local\Cursor\Cursor.exe"
        DefaultAISleepTime := 15000
        DefaultPrompt_Explain := "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点"
        DefaultPrompt_Refactor := "重构这段代码，遵循PEP8/行业规范，简化冗余逻辑，添加中文注释，保持功能不变"
        DefaultPrompt_Optimize := "分析这段代码的性能瓶颈（时间/空间复杂度），给出优化方案+对比说明，保留原逻辑可读性"
        DefaultSplitHotkey := "s"
        DefaultBatchHotkey := "b"
        DefaultPanelScreenIndex := 1
        DefaultPanelPosition := "center"
        DefaultPanelX := -1
        DefaultPanelY := -1
        
        CursorPathEdit.Value := DefaultCursorPath
        AISleepTimeEdit.Value := DefaultAISleepTime
        PromptExplainEdit.Value := DefaultPrompt_Explain
        PromptRefactorEdit.Value := DefaultPrompt_Refactor
        PromptOptimizeEdit.Value := DefaultPrompt_Optimize
        SplitHotkeyEdit.Value := DefaultSplitHotkey
        BatchHotkeyEdit.Value := DefaultBatchHotkey
        ; 重置屏幕选择（DropDownList 使用 Value 设置索引）
        ; 重新获取屏幕列表（使用 MonitorGetCount 获取准确的屏幕数量）
        ScreenList := []
        MonitorCount := 0
        try {
            MonitorCount := MonitorGetCount()
            if (MonitorCount > 0) {
                Loop MonitorCount {
                    MonitorIndex := A_Index
                    MonitorGet(MonitorIndex, &Left, &Top, &Right, &Bottom)
                    ScreenList.Push("屏幕 " . MonitorIndex)
                }
            }
        } catch {
            ; 如果 MonitorGetCount 失败，尝试直接检测
            MonitorIndex := 1
            Loop 10 {
                try {
                    MonitorGet(MonitorIndex, &Left, &Top, &Right, &Bottom)
                    ScreenList.Push("屏幕 " . MonitorIndex)
                    MonitorCount++
                    MonitorIndex++
                } catch {
                    break
                }
            }
        }
        if (ScreenList.Length = 0) {
            ScreenList.Push("屏幕 1")
            MonitorCount := 1
        }
        ; 重置屏幕选择（Radio 按钮组）
        ; 先取消所有选择
        for Index, RadioBtn in PanelScreenRadio {
            RadioBtn.Value := 0
        }
        ; 设置默认选择
        if (DefaultPanelScreenIndex >= 1 && DefaultPanelScreenIndex <= PanelScreenRadio.Length) {
            PanelScreenRadio[DefaultPanelScreenIndex].Value := 1
        } else if (PanelScreenRadio.Length > 0) {
            PanelScreenRadio[1].Value := 1
        }
        
        
        MsgBox("已重置为默认值！", "提示", "Iconi")
    }
    
    ; ========== 显示使用说明 ==========
    ShowHelp(*) {
        HelpText := "
        (
        ════════════════════════════════════════════════════
        Cursor 快捷工具 - 使用说明
        ════════════════════════════════════════════════════

        【核心功能】
        1. 长按 CapsLock 键 → 弹出快捷操作面板
        2. 短按 CapsLock 键 → 正常切换大小写（不影响原有功能）

        【快捷操作】
        • 在 Cursor 中选中代码后，长按 CapsLock 调出面板：
          - 按 E 键：解释代码（快速理解代码逻辑）
          - 按 R 键：重构代码（规范化、添加注释）
          - 按 O 键：优化代码（性能分析和优化建议）
          - 按 S 键：分割代码（插入分割标记）
          - 按 B 键：批量操作（批量解释/重构/优化）
          - 按 ESC：关闭面板

        【使用流程】
        1. 在 Cursor 中选中要处理的代码
        2. 长按 CapsLock 调出面板
        3. 按对应快捷键（E/R/O）执行操作
        4. AI 会自动将提示词和代码发送到 Cursor

        【配置说明】
        • Cursor 路径：如果 Cursor 安装在非默认位置，请手动选择
        • AI 响应等待时间：根据电脑性能调整（低配机建议 20000ms）
        • 提示词：可以自定义每个操作的 AI 提示词
        • 快捷键：可以自定义分割和批量操作的快捷键

        【注意事项】
        • 使用前请确保 Cursor 已安装并可以正常运行
        • 建议先选中代码再调出面板，这样 AI 会自动包含代码
        • 如果 Cursor 未运行，脚本会自动尝试启动

        ════════════════════════════════════════════════════
        )"
        MsgBox(HelpText, "使用说明", "Iconi")
    }
    
    ; ========== 保存配置函数 ==========
    SaveConfig(*) {
        ; 在 AutoHotkey v2 中，直接访问控件对象而不是通过 Submit
        ; 验证输入
        if (AISleepTimeEdit.Value = "" || !IsNumber(AISleepTimeEdit.Value)) {
            MsgBox("AI 响应等待时间必须是数字！", "错误", "Iconx")
            return
        }
        
        if (SplitHotkeyEdit.Value = "" || StrLen(SplitHotkeyEdit.Value) > 1) {
            MsgBox("分割快捷键必须是单个字符！", "错误", "Iconx")
            return
        }
        
        if (BatchHotkeyEdit.Value = "" || StrLen(BatchHotkeyEdit.Value) > 1) {
            MsgBox("批量操作快捷键必须是单个字符！", "错误", "Iconx")
            return
        }
        
        ; 解析屏幕索引（Radio 按钮组）
        NewScreenIndex := 1
        for Index, RadioBtn in PanelScreenRadio {
            if (RadioBtn.Value = 1) {
                NewScreenIndex := Index
                break
            }
        }
        if (NewScreenIndex < 1) {
            NewScreenIndex := 1
        }
        
        ; 更新全局变量
        global CursorPath := CursorPathEdit.Value
        global AISleepTime := AISleepTimeEdit.Value
        global Prompt_Explain := PromptExplainEdit.Value
        global Prompt_Refactor := PromptRefactorEdit.Value
        global Prompt_Optimize := PromptOptimizeEdit.Value
        global SplitHotkey := SplitHotkeyEdit.Value
        global BatchHotkey := BatchHotkeyEdit.Value
        global PanelScreenIndex := NewScreenIndex
        ; 面板位置固定为居中，不再保存位置配置
        
        ; 保存到配置文件
        IniWrite(CursorPath, ConfigFile, "Settings", "CursorPath")
        IniWrite(AISleepTime, ConfigFile, "Settings", "AISleepTime")
        IniWrite(Prompt_Explain, ConfigFile, "Settings", "Prompt_Explain")
        IniWrite(Prompt_Refactor, ConfigFile, "Settings", "Prompt_Refactor")
        IniWrite(Prompt_Optimize, ConfigFile, "Settings", "Prompt_Optimize")
        IniWrite(SplitHotkey, ConfigFile, "Settings", "SplitHotkey")
        IniWrite(BatchHotkey, ConfigFile, "Settings", "BatchHotkey")
        IniWrite(PanelScreenIndex, ConfigFile, "Panel", "ScreenIndex")
        
        ; 更新面板显示的快捷键
        if (GuiID_CursorPanel != 0) {
            ; 面板已创建，需要重新创建以更新快捷键显示
            try {
                GuiID_CursorPanel.Destroy()
            }
            global GuiID_CursorPanel := 0
        }
        
        MsgBox("配置已保存！`n`n提示：如果面板正在显示，请关闭后重新打开以应用新配置。", "提示", "Iconi")
        ConfigGUI.Destroy()
    }
}

; ===================== 清理函数 =====================
CleanUp() {
    global GuiID_CursorPanel
    
    if (GuiID_CursorPanel != 0) {
        try {
            GuiID_CursorPanel.Destroy()
        }
    }
    
    ExitApp()
}

; ===================== 连续复制功能 =====================
; CapsLock+C: 连续复制，将内容添加到历史记录中
CapsLockCopy() {
    global CapsLock2, ClipboardHistory
    
    CapsLock2 := false  ; 清除标记，表示使用了功能
    
    ; 保存当前剪贴板内容
    OldClipboard := A_Clipboard
    
    ; 立即执行复制操作，不等待
    Send("^c")
    
    ; 完全异步处理，立即返回，让用户感觉操作瞬间完成
    ; 不显示任何通知，完全静默操作
    SetTimer(() => ProcessCopyResult(OldClipboard), -20)
}

; 异步处理复制结果，避免阻塞主流程
ProcessCopyResult(OldClipboard) {
    global ClipboardHistory
    
    ; 短暂等待剪贴板更新（通常只需要很短时间）
    ; 使用循环检查，而不是固定等待，可以更快响应
    MaxWait := 8  ; 最多等待 8 次，每次 10ms
    NewContent := ""
    Loop MaxWait {
        Sleep(10)
        NewContent := A_Clipboard
        ; 如果剪贴板已更新且内容不同，立即处理
        if (NewContent != "" && NewContent != OldClipboard) {
            break
        }
    }
    
    ; 如果复制到了新内容且不为空，添加到历史记录（完全静默，不显示通知）
    if (NewContent != "" && NewContent != OldClipboard && StrLen(NewContent) > 0) {
        ClipboardHistory.Push(NewContent)
    }
}

; ===================== 合并粘贴功能 =====================
; CapsLock+V: 将所有复制的内容合并后粘贴到 Cursor 输入框
CapsLockPaste() {
    global CapsLock2, ClipboardHistory, CursorPath, AISleepTime
    
    CapsLock2 := false  ; 清除标记，表示使用了功能
    
    ; 如果没有复制任何内容，提示用户
    if (ClipboardHistory.Length = 0) {
        TrayTip("请先使用 CapsLock+C 复制内容", "提示", "Iconi 2")
        return
    }
    
    ; 合并所有复制的内容（用换行分隔）
    MergedContent := ""
    for Index, Content in ClipboardHistory {
        if (Index > 1) {
            MergedContent .= "`n`n"  ; 两个换行分隔不同内容
        }
        MergedContent .= Content
    }
    
    ; 激活 Cursor 窗口
    try {
        if WinExist("ahk_exe Cursor.exe") {
            ; 先激活窗口，等待窗口完全激活
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 1)  ; 等待窗口激活，最多等待1秒
            Sleep(200)  ; 额外等待，确保窗口完全就绪
            
            ; 确保 Cursor 窗口仍然激活
            if !WinActive("ahk_exe Cursor.exe") {
                WinActivate("ahk_exe Cursor.exe")
                Sleep(200)
            }
            
            ; 先按 ESC 关闭可能已打开的输入框，避免冲突
            Send("{Esc}")
            Sleep(100)
            
            ; 尝试打开 Cursor 的 AI 聊天面板（通常是 Ctrl+L）
            Send("^l")
            Sleep(400)  ; 增加等待时间，确保聊天面板完全打开
            
            ; 再次确保窗口激活（防止在等待期间窗口失去焦点）
            if !WinActive("ahk_exe Cursor.exe") {
                WinActivate("ahk_exe Cursor.exe")
                Sleep(200)
            }
            
            ; 将合并的内容复制到剪贴板
            A_Clipboard := MergedContent
            Sleep(100)
            
            ; 粘贴合并的内容
            Send("^v")
            Sleep(200)  ; 增加等待时间，确保粘贴完成
            
            ; 粘贴后清空历史记录
            ClipboardHistory := []
            
            TrayTip("已粘贴到 Cursor", "合并粘贴", "Iconi 1")
        } else {
            ; 如果 Cursor 未运行，尝试启动
            if (CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                Sleep(AISleepTime)
                
                ; 将合并的内容复制到剪贴板
                A_Clipboard := MergedContent
                Sleep(100)
                
                Send("^l")
                Sleep(400)
                Send("^v")
                Sleep(200)
                
                ; 粘贴后清空历史记录
                ClipboardHistory := []
                
                TrayTip("已粘贴到 Cursor", "合并粘贴", "Iconi 1")
            } else {
                TrayTip("Cursor 未运行且无法启动", "错误", "Iconx 2")
            }
        }
    } catch as e {
        MsgBox("粘贴失败: " . e.Message)
    }
}

; ===================== 剪贴板管理面板 =====================
ShowClipboardManager() {
    global ClipboardHistory, GuiID_ClipboardManager, PanelScreenIndex
    
    ; 如果面板已存在，先销毁
    if (GuiID_ClipboardManager != 0) {
        try {
            GuiID_ClipboardManager.Destroy()
        }
    }
    
    ; 面板尺寸（Cursor 风格）
    PanelWidth := 600
    PanelHeight := 500
    
    ; 创建 GUI（Cursor 深色主题）
    GuiID_ClipboardManager := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale", "剪贴板管理")
    GuiID_ClipboardManager.BackColor := "1e1e1e"  ; Cursor 主背景色
    GuiID_ClipboardManager.SetFont("s11 cCCCCCC", "Segoe UI")
    
    ; 标题区域
    TitleBg := GuiID_ClipboardManager.Add("Text", "x0 y0 w600 h50 Background1e1e1e", "")
    TitleText := GuiID_ClipboardManager.Add("Text", "x20 y12 w560 h26 cFFFFFF", "📋 剪贴板管理")
    TitleText.SetFont("s13 Bold", "Segoe UI")
    
    ; 关闭按钮
    BtnClose := GuiID_ClipboardManager.Add("Button", "x560 y10 w30 h30", "×")
    BtnClose.SetFont("s14 Bold cFFFFFF", "Segoe UI")
    BtnClose.OnEvent("Click", (*) => GuiID_ClipboardManager.Destroy())
    
    ; 分隔线
    GuiID_ClipboardManager.Add("Text", "x0 y50 w600 h1 Background3c3c3c", "")
    
    ; 工具栏区域
    ToolbarBg := GuiID_ClipboardManager.Add("Text", "x0 y51 w600 h40 Background252526", "")
    
    ; 清空所有按钮
    BtnClearAll := GuiID_ClipboardManager.Add("Button", "x20 y55 w100 h32", "清空全部")
    BtnClearAll.SetFont("s10 cFFFFFF", "Segoe UI")
    BtnClearAll.OnEvent("Click", ClearAllClipboard)
    
    ; 统计信息
    CountText := GuiID_ClipboardManager.Add("Text", "x140 y60 w200 h22 c888888", "共 0 项")
    CountText.SetFont("s10", "Segoe UI")
    
    ; 刷新按钮
    BtnRefresh := GuiID_ClipboardManager.Add("Button", "x480 y55 w100 h32", "刷新")
    BtnRefresh.SetFont("s10 cFFFFFF", "Segoe UI")
    BtnRefresh.OnEvent("Click", (*) => RefreshClipboardList())
    
    ; 列表区域（使用 ListBox）
    ListBox := GuiID_ClipboardManager.Add("ListBox", "x20 y100 w560 h320 vClipboardListBox")
    ListBox.SetFont("s10 cCCCCCC", "Consolas")
    
    ; 操作按钮区域
    BtnArea := GuiID_ClipboardManager.Add("Text", "x0 y430 w600 h70 Background1e1e1e", "")
    
    ; 复制选中项按钮
    BtnCopySelected := GuiID_ClipboardManager.Add("Button", "x20 y440 w120 h35", "复制选中")
    BtnCopySelected.SetFont("s10 cFFFFFF", "Segoe UI")
    BtnCopySelected.OnEvent("Click", CopySelectedItem)
    
    ; 删除选中项按钮
    BtnDeleteSelected := GuiID_ClipboardManager.Add("Button", "x150 y440 w120 h35", "删除选中")
    BtnDeleteSelected.SetFont("s10 cFFFFFF", "Segoe UI")
    BtnDeleteSelected.OnEvent("Click", DeleteSelectedItem)
    
    ; 粘贴选中项到 Cursor
    BtnPasteToCursor := GuiID_ClipboardManager.Add("Button", "x280 y440 w140 h35", "粘贴到 Cursor")
    BtnPasteToCursor.SetFont("s10 cFFFFFF", "Segoe UI")
    BtnPasteToCursor.OnEvent("Click", PasteSelectedToCursor)
    
    ; 底部提示
    HintText := GuiID_ClipboardManager.Add("Text", "x20 y485 w560 h15 c666666", "双击项目可复制 | ESC 关闭")
    HintText.SetFont("s9", "Segoe UI")
    
    ; 绑定双击事件
    ListBox.OnEvent("DoubleClick", CopySelectedItem)
    
    ; 绑定 ESC 关闭
    GuiID_ClipboardManager.OnEvent("Escape", (*) => GuiID_ClipboardManager.Destroy())
    
    ; 保存控件引用到全局变量，方便后续操作
    global ClipboardListBox := ListBox
    global ClipboardCountText := CountText
    
    ; 刷新列表
    RefreshClipboardList()
    
    ; 获取屏幕信息并计算位置
    ScreenInfo := GetScreenInfo(PanelScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight)
    
    ; 显示面板
    GuiID_ClipboardManager.Show("w" . PanelWidth . " h" . PanelHeight . " x" . Pos.X . " y" . Pos.Y)
}

; 刷新剪贴板列表
RefreshClipboardList() {
    global ClipboardHistory, ClipboardListBox, ClipboardCountText, GuiID_ClipboardManager
    
    ; 检查控件是否存在且 GUI 未销毁
    if (!ClipboardListBox || !ClipboardCountText || !GuiID_ClipboardManager) {
        return
    }
    
    try {
        ; 获取当前列表项（通过 List 属性）
        ; 在 AutoHotkey v2 中，List 属性返回数组
        try {
            CurrentList := ClipboardListBox.List
            ListCount := CurrentList ? CurrentList.Length : 0
        } catch {
            ListCount := 0
        }
        
        ; 从后往前删除所有项（避免索引变化问题）
        if (ListCount > 0) {
            Loop ListCount {
                try {
                    ClipboardListBox.Delete(ListCount - A_Index + 1)
                } catch {
                    ; 如果删除失败，继续尝试
                    continue
                }
            }
        }
        
        ; 添加所有历史记录（显示前80个字符作为预览）
        Items := []
        for Index, Content in ClipboardHistory {
            ; 处理换行和特殊字符，创建预览文本
            Preview := StrReplace(Content, "`r`n", " ")
            Preview := StrReplace(Preview, "`n", " ")
            Preview := StrReplace(Preview, "`r", " ")
            Preview := StrReplace(Preview, "`t", " ")
            
            ; 限制预览长度
            if (StrLen(Preview) > 80) {
                Preview := SubStr(Preview, 1, 80) . "..."
            }
            
            ; 添加序号和预览
            DisplayText := "[" . Index . "] " . Preview
            Items.Push(DisplayText)
        }
        
        ; 批量添加项目
        if (Items.Length > 0) {
            ClipboardListBox.Add(Items)
        }
        
        ; 更新统计信息
        ClipboardCountText.Text := "共 " . ClipboardHistory.Length . " 项"
    } catch as e {
        ; 如果控件已销毁，静默失败
        return
    }
}

; 清空所有剪贴板
ClearAllClipboard(*) {
    global ClipboardHistory, ClipboardListBox, ClipboardCountText
    
    ; 确认对话框
    Result := MsgBox("确定要清空所有剪贴板记录吗？", "确认", "YesNo Icon?")
    if (Result = "Yes") {
        ClipboardHistory := []
        RefreshClipboardList()
        TrayTip("已清空所有记录", "提示", "Iconi 1")
    }
}

; 复制选中项
CopySelectedItem(*) {
    global ClipboardHistory, ClipboardListBox, GuiID_ClipboardManager
    
    if (!ClipboardListBox || !GuiID_ClipboardManager) {
        return
    }
    
    try {
        SelectedIndex := ClipboardListBox.Value
        if (SelectedIndex > 0 && SelectedIndex <= ClipboardHistory.Length) {
            A_Clipboard := ClipboardHistory[SelectedIndex]
            TrayTip("已复制到剪贴板", "提示", "Iconi 1")
        } else {
            TrayTip("请先选择要复制的项目", "提示", "Iconi 1")
        }
    } catch {
        TrayTip("操作失败，控件可能已关闭", "错误", "Iconx 1")
    }
}

; 删除选中项
DeleteSelectedItem(*) {
    global ClipboardHistory, ClipboardListBox, GuiID_ClipboardManager
    
    if (!ClipboardListBox || !GuiID_ClipboardManager) {
        return
    }
    
    try {
        SelectedIndex := ClipboardListBox.Value
        if (SelectedIndex > 0 && SelectedIndex <= ClipboardHistory.Length) {
            ; 从数组中删除（注意：ListBox 的索引从 1 开始，数组索引也从 1 开始）
            ClipboardHistory.RemoveAt(SelectedIndex)
            RefreshClipboardList()
            TrayTip("已删除", "提示", "Iconi 1")
        } else {
            TrayTip("请先选择要删除的项目", "提示", "Iconi 1")
        }
    } catch {
        TrayTip("操作失败，控件可能已关闭", "错误", "Iconx 1")
    }
}

; 粘贴选中项到 Cursor
PasteSelectedToCursor(*) {
    global ClipboardHistory, ClipboardListBox, CursorPath, AISleepTime, GuiID_ClipboardManager
    
    if (!ClipboardListBox || !GuiID_ClipboardManager) {
        return
    }
    
    try {
        SelectedIndex := ClipboardListBox.Value
        if (SelectedIndex > 0 && SelectedIndex <= ClipboardHistory.Length) {
            Content := ClipboardHistory[SelectedIndex]
            
            ; 激活 Cursor 窗口
            try {
                if WinExist("ahk_exe Cursor.exe") {
                    WinActivate("ahk_exe Cursor.exe")
                    WinWaitActive("ahk_exe Cursor.exe", , 1)
                    Sleep(200)
                    
                    if !WinActive("ahk_exe Cursor.exe") {
                        WinActivate("ahk_exe Cursor.exe")
                        Sleep(200)
                    }
                    
                    Send("{Esc}")
                    Sleep(100)
                    Send("^l")
                    Sleep(400)
                    
                    if !WinActive("ahk_exe Cursor.exe") {
                        WinActivate("ahk_exe Cursor.exe")
                        Sleep(200)
                    }
                    
                    A_Clipboard := Content
                    Sleep(100)
                    Send("^v")
                    Sleep(200)
                    
                    TrayTip("已粘贴到 Cursor", "提示", "Iconi 1")
                } else {
                    if (CursorPath != "" && FileExist(CursorPath)) {
                        Run(CursorPath)
                        Sleep(AISleepTime)
                        A_Clipboard := Content
                        Sleep(100)
                        Send("^l")
                        Sleep(400)
                        Send("^v")
                        Sleep(200)
                        TrayTip("已粘贴到 Cursor", "提示", "Iconi 1")
                    } else {
                        TrayTip("Cursor 未运行", "错误", "Iconx 2")
                    }
                }
            } catch as e {
                MsgBox("粘贴失败: " . e.Message)
            }
        } else {
            TrayTip("请先选择要粘贴的项目", "提示", "Iconi 1")
        }
    } catch {
        TrayTip("操作失败，控件可能已关闭", "错误", "Iconx 1")
    }
}

; ===================== 面板快捷键 =====================
; 当 CapsLock 按下时，响应快捷键（采用 CapsLock+ 方案）
#HotIf (CapsLock)

; ESC 关闭面板
Esc:: {
    global CapsLock2, PanelVisible
    CapsLock2 := false  ; 清除标记，表示使用了功能
    if (PanelVisible) {
        HideCursorPanel()
    }
}

; C 键连续复制（立即响应，不等待面板）
c:: {
    ; 立即执行复制，不等待任何延迟
    CapsLockCopy()
}

; V 键合并粘贴
v:: {
    CapsLockPaste()
}

; X 键打开剪贴板管理面板
x:: {
    global CapsLock2
    CapsLock2 := false  ; 清除标记，表示使用了功能
    ShowClipboardManager()
}

; E 键执行解释
e:: {
    global CapsLock2
    CapsLock2 := false  ; 清除标记，表示使用了功能
    ExecutePrompt("Explain")
}

; R 键执行重构
r:: {
    global CapsLock2
    CapsLock2 := false  ; 清除标记，表示使用了功能
    ExecutePrompt("Refactor")
}

; O 键执行优化
o:: {
    global CapsLock2
    CapsLock2 := false  ; 清除标记，表示使用了功能
    ExecutePrompt("Optimize")
}

; Q 键打开配置面板
q:: {
    global CapsLock2, PanelVisible
    CapsLock2 := false  ; 清除标记，表示使用了功能
    if (PanelVisible) {
        HideCursorPanel()
    }
    ShowConfigGUI()
}

#HotIf

; ===================== 动态快捷键处理 =====================
; 启动动态快捷键监听（当面板显示时）
StartDynamicHotkeys() {
    ; 这个函数保留用于未来扩展
    ; 目前使用 #HotIf 条件来处理动态快捷键
}

; 停止动态快捷键监听
StopDynamicHotkeys() {
    ; 这个函数保留用于未来扩展
}

; ===================== 面板显示时的动态快捷键 =====================
; 当 CapsLock 按下且面板显示时，响应快捷键
#HotIf (CapsLock && PanelVisible)

; 默认的 s 键（分割）
s:: {
    global SplitHotkey, CapsLock2
    CapsLock2 := false  ; 清除标记，表示使用了功能
    if (SplitHotkey = "s") {
        SplitCode()
    } else {
        ; 如果不是配置的快捷键，发送原始按键
        Send("s")
    }
}

; 默认的 b 键（批量）
b:: {
    global BatchHotkey, CapsLock2
    CapsLock2 := false  ; 清除标记，表示使用了功能
    if (BatchHotkey = "b") {
        BatchOperation()
    } else {
        ; 如果不是配置的快捷键，发送原始按键
        Send("b")
    }
}

#HotIf

