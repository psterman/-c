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
global CapsLock := false
global GuiID_ConfigGUI := 0  ; 配置面板单例
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
global FunctionPanelPos := "center"
global ConfigPanelPos := "center"
global ClipboardPanelPos := "center"
global PanelX := -1  ; 自定义 X 坐标（-1 表示使用默认位置）
global PanelY := -1  ; 自定义 Y 坐标（-1 表示使用默认位置）
; 连续复制功能
global ClipboardHistory := []  ; 存储所有复制的内容
global GuiID_ClipboardManager := 0  ; 剪贴板管理面板 GUI ID
; 语音输入功能
global VoiceInputActive := false  ; 语音输入是否激活
global GuiID_VoiceInput := 0  ; 语音输入动画GUI ID
global VoiceInputContent := ""  ; 存储语音输入的内容
global VoiceInputMethod := ""  ; 当前使用的输入法类型：baidu, xunfei, auto
global VoiceInputBlocked := false  ; 语音输入是否被屏蔽
global VoiceInputPaused := false  ; 语音输入是否被暂停（按住CapsLock时）
global VoiceTitleText := 0  ; 语音输入动画标题文本控件
global VoiceHintText := 0  ; 语音输入动画提示文本控件
; 多语言支持
global Language := "zh"  ; 语言设置：zh=中文, en=英文

; ===================== 多语言支持 =====================
; 获取本地化文本
GetText(Key) {
    global Language
    static Texts := Map(
        "zh", Map(
            "app_name", "Cursor助手",
            "app_tip", "Cursor助手（长按CapsLock调出面板）",
            "panel_title", "Cursor 快捷操作",
            "config_title", "Cursor助手 - 配置面板",
            "clipboard_manager", "剪贴板管理",
            "explain_code", "解释代码 (E)",
            "refactor_code", "重构代码 (R)",
            "optimize_code", "优化代码 (O)",
            "open_config", "⚙️ 打开配置面板 (Q)",
            "split_hint", "按 {0} 分割 | 按 {1} 批量操作",
            "footer_hint", "按 ESC 关闭面板 | 按 Q 打开配置`n先选中代码再操作",
            "open_config_menu", "打开配置面板",
            "exit_menu", "退出工具",
            "copy_success", "已复制 ({0} 项)",
            "paste_success", "已粘贴到 Cursor",
            "clear_success", "已清空复制历史",
            "no_content", "未检测到新内容",
            "no_clipboard", "请先使用 CapsLock+C 复制内容",
            "clear_all", "清空全部",
            "refresh", "刷新",
            "copy_selected", "复制选中",
            "delete_selected", "删除选中",
            "paste_to_cursor", "粘贴到 Cursor",
            "clipboard_hint", "双击项目可复制 | ESC 关闭",
            "total_items", "共 {0} 项",
            "confirm_clear", "确定要清空所有剪贴板记录吗？",
            "cleared", "已清空所有记录",
            "copied", "已复制到剪贴板",
            "deleted", "已删除",
            "select_first", "请先选择要{0}的项目",
            "operation_failed", "操作失败，控件可能已关闭",
            "paste_failed", "粘贴失败",
            "cursor_not_running", "Cursor 未运行",
            "cursor_not_running_error", "Cursor 未运行且无法启动",
            "select_code_first", "请先选中要分割的代码",
            "split_marker_inserted", "已插入分割标记",
            "reset_default_success", "已重置为默认值！",
            "config_saved", "配置已保存！`n`n提示：如果面板正在显示，请关闭后重新打开以应用新配置。",
            "ai_wait_time_error", "AI 响应等待时间必须是数字！",
            "split_hotkey_error", "分割快捷键必须是单个字符！",
            "batch_hotkey_error", "批量操作快捷键必须是单个字符！",
            "copy", "复制",
            "delete", "删除",
            "paste", "粘贴",
            "tip", "提示",
            "error", "错误",
            "confirm", "确认",
            "warning", "警告",
            "help_title", "使用说明",
            "language_setting", "语言设置",
            "language_chinese", "中文",
            "language_english", "English",
            "app_path", "应用程序路径",
            "cursor_path_hint", "提示：如果 Cursor 安装在非默认位置，请点击「浏览」按钮选择",
            "ai_response_time", "AI 响应等待时间",
            "ai_wait_hint", "建议：低配机 20000，高配机 10000",
            "prompt_config", "AI 提示词配置",
            "custom_hotkeys", "自定义快捷键",
            "single_char_hint", "（单个字符，默认: {0}）",
            "panel_display", "面板显示位置",
            "screen_detected", "显示屏幕 (检测到: {0}):",
            "screen", "屏幕 {0}",
            "tab_general", "通用",
            "tab_appearance", "外观",
            "tab_prompts", "提示词",
            "tab_hotkeys", "快捷键",
            "tab_advanced", "高级",
            "search_placeholder", "搜索设置...",
            "general_settings", "通用设置",
            "appearance_settings", "外观设置",
            "prompt_settings", "提示词设置",
            "hotkey_settings", "快捷键设置",
            "advanced_settings", "高级设置",
            "settings_basic", "📁 基础设置",
            "settings_performance", "⚡ 性能设置",
            "settings_prompts", "💬 提示词设置",
            "settings_hotkeys", "⌨️ 快捷键设置",
            "settings_panel", "🖥️ 面板位置设置",
            "cursor_path", "Cursor 路径:",
            "browse", "浏览...",
            "ai_wait_time", "AI 响应等待时间 (毫秒):",
            "explain_prompt", "解释代码提示词:",
            "refactor_prompt", "重构代码提示词:",
            "optimize_prompt", "优化代码提示词:",
            "split_hotkey", "分割快捷键:",
            "batch_hotkey", "批量操作快捷键:",
            "display_screen", "显示屏幕:",
            "reset_default", "重置默认",
            "save_config", "保存配置",
            "cancel", "取消",
            "help", "使用说明",
            "pos_center", "居中",
            "pos_top_left", "左上角",
            "pos_top_right", "右上角",
            "pos_bottom_left", "左下角",
            "pos_bottom_right", "右下角",
            "panel_pos_func", "功能面板位置",
            "panel_pos_config", "设置面板位置",
            "panel_pos_clip", "剪贴板面板位置",
            "default_prompt_explain", "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点",
            "default_prompt_refactor", "重构这段代码，遵循PEP8/行业规范，简化冗余逻辑，添加中文注释，保持功能不变",
            "default_prompt_optimize", "分析这段代码的性能瓶颈（时间/空间复杂度），给出优化方案+对比说明，保留原逻辑可读性",
            "export_config", "导出配置",
            "import_config", "导入配置",
            "export_clipboard", "导出剪贴板",
            "import_clipboard", "导入剪贴板",
            "export_success", "导出成功",
            "import_success", "导入成功",
            "import_failed", "导入失败",
            "confirm_reset", "确定要重置为默认设置吗？这将清除所有自定义配置。",
            "config_saved", "配置已保存！",
            "voice_input_starting", "正在启动语音输入...",
            "voice_input_active", "🎤 语音输入中",
            "voice_input_hint", "正在录入，请说话...",
            "voice_input_stopping", "正在结束语音输入...",
            "voice_input_sent", "语音输入已发送到 Cursor",
            "voice_input_failed", "语音输入失败",
            "voice_input_no_content", "未检测到语音输入内容",
            "voice_input_detected_baidu", "检测到百度输入法",
            "voice_input_detected_xunfei", "检测到讯飞输入法",
            "voice_input_auto_detect", "自动检测输入法"
        ),
        "en", Map(
            "app_name", "Cursor Assistant",
            "app_tip", "Cursor Assistant (Hold CapsLock to open panel)",
            "panel_title", "Cursor Quick Actions",
            "config_title", "Cursor Assistant - Settings",
            "clipboard_manager", "Clipboard Manager",
            "explain_code", "Explain Code (E)",
            "refactor_code", "Refactor Code (R)",
            "optimize_code", "Optimize Code (O)",
            "open_config", "⚙️ Open Settings (Q)",
            "split_hint", "Press {0} to split | Press {1} for batch",
            "footer_hint", "Press ESC to close | Press Q for settings`nSelect code first",
            "open_config_menu", "Open Settings",
            "exit_menu", "Exit",
            "copy_success", "Copied ({0} items)",
            "paste_success", "Pasted to Cursor",
            "clear_success", "Clipboard history cleared",
            "no_content", "No new content detected",
            "no_clipboard", "Please use CapsLock+C to copy content first",
            "clear_all", "Clear All",
            "refresh", "Refresh",
            "copy_selected", "Copy Selected",
            "delete_selected", "Delete Selected",
            "paste_to_cursor", "Paste to Cursor",
            "clipboard_hint", "Double-click to copy | ESC to close",
            "total_items", "Total {0} items",
            "confirm_clear", "Are you sure you want to clear all clipboard records?",
            "cleared", "All records cleared",
            "copied", "Copied to clipboard",
            "deleted", "Deleted",
            "select_first", "Please select an item to {0} first",
            "operation_failed", "Operation failed, control may be closed",
            "paste_failed", "Paste failed",
            "cursor_not_running", "Cursor is not running",
            "cursor_not_running_error", "Cursor is not running and cannot be started",
            "select_code_first", "Please select code to split first",
            "split_marker_inserted", "Split marker inserted",
            "reset_default_success", "Reset to default values!",
            "config_saved", "Settings saved!`n`nNote: If panel is showing, close and reopen to apply new settings.",
            "ai_wait_time_error", "AI response wait time must be a number!",
            "split_hotkey_error", "Split hotkey must be a single character!",
            "batch_hotkey_error", "Batch hotkey must be a single character!",
            "copy", "copy",
            "delete", "delete",
            "paste", "paste",
            "tip", "Tip",
            "error", "Error",
            "confirm", "Confirm",
            "warning", "Warning",
            "help_title", "Help",
            "language_setting", "Language",
            "language_chinese", "中文",
            "language_english", "English",
            "app_path", "Application Path",
            "cursor_path_hint", "Tip: If Cursor is installed in a non-default location, click 'Browse' to select",
            "ai_response_time", "AI Response Wait Time",
            "ai_wait_hint", "Recommendation: Low-end PC 20000, High-end PC 10000",
            "prompt_config", "AI Prompt Configuration",
            "custom_hotkeys", "Custom Hotkeys",
            "single_char_hint", "(Single character, default: {0})",
            "panel_display", "Panel Display Position",
            "screen_detected", "Display Screen (Detected: {0}):",
            "screen", "Screen {0}",
            "tab_general", "General",
            "tab_appearance", "Appearance",
            "tab_prompts", "Prompts",
            "tab_hotkeys", "Hotkeys",
            "tab_advanced", "Advanced",
            "search_placeholder", "Search settings...",
            "general_settings", "General Settings",
            "appearance_settings", "Appearance Settings",
            "prompt_settings", "Prompt Settings",
            "hotkey_settings", "Hotkey Settings",
            "advanced_settings", "Advanced Settings",
            "settings_basic", "📁 Basic Settings",
            "settings_performance", "⚡ Performance Settings",
            "settings_prompts", "💬 Prompt Settings",
            "settings_hotkeys", "⌨️ Hotkey Settings",
            "settings_panel", "🖥️ Panel Position Settings",
            "cursor_path", "Cursor Path:",
            "browse", "Browse...",
            "ai_wait_time", "AI Response Wait Time (ms):",
            "explain_prompt", "Explain Code Prompt:",
            "refactor_prompt", "Refactor Code Prompt:",
            "optimize_prompt", "Optimize Code Prompt:",
            "split_hotkey", "Split Hotkey:",
            "batch_hotkey", "Batch Hotkey:",
            "display_screen", "Display Screen:",
            "reset_default", "Reset Default",
            "save_config", "Save Settings",
            "cancel", "Cancel",
            "help", "Help",
            "pos_center", "Center",
            "pos_top_left", "Top Left",
            "pos_top_right", "Top Right",
            "pos_bottom_left", "Bottom Left",
            "pos_bottom_right", "Bottom Right",
            "panel_pos_func", "Function Panel Position",
            "panel_pos_config", "Settings Panel Position",
            "panel_pos_clip", "Clipboard Panel Position",
            "default_prompt_explain", "Explain the core logic, inputs/outputs, and key functions of this code in simple terms. Highlight potential pitfalls.",
            "default_prompt_refactor", "Refactor this code following PEP8/best practices. Simplify redundant logic, add comments, and keep functionality unchanged.",
            "default_prompt_optimize", "Analyze performance bottlenecks (time/space complexity). Provide optimization solutions with comparison. Keep original logic readable.",
            "close_button", "Close",
            "close_button_tip", "Close Panel",
            "export_config", "Export Config",
            "import_config", "Import Config",
            "export_clipboard", "Export Clipboard",
            "import_clipboard", "Import Clipboard",
            "export_success", "Export Successful",
            "import_success", "Import Successful",
            "import_failed", "Import Failed",
            "confirm_reset", "Are you sure you want to reset to default settings? This will clear all custom configurations.",
            "config_saved", "Configuration Saved!",
            "voice_input_starting", "Starting voice input...",
            "voice_input_active", "🎤 Voice Input Active",
            "voice_input_hint", "Recording, please speak...",
            "voice_input_stopping", "Stopping voice input...",
            "voice_input_sent", "Voice input sent to Cursor",
            "voice_input_failed", "Voice input failed",
            "voice_input_no_content", "No voice input content detected",
            "voice_input_detected_baidu", "Baidu IME detected",
            "voice_input_detected_xunfei", "Xunfei IME detected",
            "voice_input_auto_detect", "Auto detect IME"
        )
    )
    
    ; 获取当前语言的文本
    LangTexts := Texts[Language]
    if (!LangTexts) {
        LangTexts := Texts["zh"]  ; 默认使用中文
    }
    
    Text := LangTexts[Key]
    if (!Text) {
        Text := Key  ; 如果找不到，返回键名
    }
    
    ; 支持参数替换 {0}, {1} 等
    if (InStr(Text, "{0}") || InStr(Text, "{1}")) {
        ; 这里需要调用者传入参数，暂时返回原文本
        return Text
    }
    
    return Text
}

; 格式化文本（支持参数）
FormatText(Key, Params*) {
    Text := GetText(Key)
    Loop Params.Length {
        Text := StrReplace(Text, "{" . (A_Index - 1) . "}", Params[A_Index])
    }
    return Text
}

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
    DefaultFunctionPanelPos := "center"
    DefaultConfigPanelPos := "center"
    DefaultClipboardPanelPos := "center"
    DefaultLanguage := "zh"  ; 默认中文

    ; 2. 无配置文件则创建
    if !FileExist(ConfigFile) {
        IniWrite(DefaultCursorPath, ConfigFile, "General", "CursorPath")
        IniWrite(DefaultAISleepTime, ConfigFile, "General", "AISleepTime")
        IniWrite(DefaultLanguage, ConfigFile, "General", "Language")
        
        IniWrite(DefaultPrompt_Explain, ConfigFile, "Prompts", "Explain")
        IniWrite(DefaultPrompt_Refactor, ConfigFile, "Prompts", "Refactor")
        IniWrite(DefaultPrompt_Optimize, ConfigFile, "Prompts", "Optimize")
        
        IniWrite(DefaultSplitHotkey, ConfigFile, "Hotkeys", "Split")
        IniWrite(DefaultBatchHotkey, ConfigFile, "Hotkeys", "Batch")
        
        IniWrite(DefaultPanelScreenIndex, ConfigFile, "Appearance", "ScreenIndex")
        IniWrite(DefaultFunctionPanelPos, ConfigFile, "Appearance", "FunctionPanelPos")
        IniWrite(DefaultConfigPanelPos, ConfigFile, "Appearance", "ConfigPanelPos")
        IniWrite(DefaultClipboardPanelPos, ConfigFile, "Appearance", "ClipboardPanelPos")
    }

    ; 3. 加载配置（v2的IniRead返回值更直观）
    global CursorPath, AISleepTime, Prompt_Explain, Prompt_Refactor, Prompt_Optimize, SplitHotkey, BatchHotkey, PanelScreenIndex, Language
    global FunctionPanelPos, ConfigPanelPos, ClipboardPanelPos
    try {
        if FileExist(ConfigFile) {
            CursorPath := IniRead(ConfigFile, "General", "CursorPath", DefaultCursorPath)
            AISleepTime := Integer(IniRead(ConfigFile, "General", "AISleepTime", DefaultAISleepTime))
            Language := IniRead(ConfigFile, "General", "Language", DefaultLanguage)
            
            Prompt_Explain := IniRead(ConfigFile, "Prompts", "Explain", DefaultPrompt_Explain)
            Prompt_Refactor := IniRead(ConfigFile, "Prompts", "Refactor", DefaultPrompt_Refactor)
            Prompt_Optimize := IniRead(ConfigFile, "Prompts", "Optimize", DefaultPrompt_Optimize)
            
            SplitHotkey := IniRead(ConfigFile, "Hotkeys", "Split", DefaultSplitHotkey)
            BatchHotkey := IniRead(ConfigFile, "Hotkeys", "Batch", DefaultBatchHotkey)
            
            PanelScreenIndex := Integer(IniRead(ConfigFile, "Appearance", "ScreenIndex", DefaultPanelScreenIndex))
            FunctionPanelPos := IniRead(ConfigFile, "Appearance", "FunctionPanelPos", DefaultFunctionPanelPos)
            ConfigPanelPos := IniRead(ConfigFile, "Appearance", "ConfigPanelPos", DefaultConfigPanelPos)
            ClipboardPanelPos := IniRead(ConfigFile, "Appearance", "ClipboardPanelPos", DefaultClipboardPanelPos)
        } else {
            ; If config file doesn't exist, use default values directly
            CursorPath := DefaultCursorPath
            AISleepTime := DefaultAISleepTime
            Language := DefaultLanguage
            Prompt_Explain := DefaultPrompt_Explain
            Prompt_Refactor := DefaultPrompt_Refactor
            Prompt_Optimize := DefaultPrompt_Optimize
            SplitHotkey := DefaultSplitHotkey
            BatchHotkey := DefaultBatchHotkey
            PanelScreenIndex := DefaultPanelScreenIndex
            FunctionPanelPos := DefaultFunctionPanelPos
            ConfigPanelPos := DefaultConfigPanelPos
            ClipboardPanelPos := DefaultClipboardPanelPos
        }
    } catch as e {
        MsgBox("Error loading config: " . e.Message, "Error", "IconStop")
        ; Fallback to defaults in case of error
        CursorPath := DefaultCursorPath
        AISleepTime := DefaultAISleepTime
        Language := DefaultLanguage
        Prompt_Explain := DefaultPrompt_Explain
        Prompt_Refactor := DefaultPrompt_Refactor
        Prompt_Optimize := DefaultPrompt_Optimize
        SplitHotkey := DefaultSplitHotkey
        BatchHotkey := DefaultBatchHotkey
        PanelScreenIndex := DefaultPanelScreenIndex
        FunctionPanelPos := DefaultFunctionPanelPos
        ConfigPanelPos := DefaultConfigPanelPos
        ClipboardPanelPos := DefaultClipboardPanelPos
    }
    
    ; 验证语言设置
    if (Language != "zh" && Language != "en") {
        Language := "zh"  ; 默认中文
    }
}

InitConfig() ; 启动初始化

; ===================== 托盘图标配置 =====================
UpdateTrayMenu() {
    A_TrayMenu.Delete()  ; 清空菜单
    A_TrayMenu.Add(GetText("open_config_menu"), (*) => ShowConfigGUI())
    A_TrayMenu.Add(GetText("exit_menu"), (*) => CleanUp())
    A_TrayMenu.Default := GetText("exit_menu")
    A_IconTip := GetText("app_tip")
}

UpdateTrayMenu()  ; 初始化托盘菜单

; ===================== CapsLock 状态检查函数 =====================
; 用于 #HotIf 指令的函数
GetCapsLockState() {
    global CapsLock
    return CapsLock
}

; ===================== 面板可见状态检查函数 =====================
; 用于 #HotIf 指令的函数
GetPanelVisibleState() {
    global PanelVisible
    return PanelVisible
}

; ===================== CapsLock核心逻辑 =====================
; 定时器函数定义（需要在 CapsLock 处理函数外部定义）
ClearCapsLock2Timer(*) {
    global CapsLock2 := false
}

ShowPanelTimer(*) {
    global CapsLock, PanelVisible, VoiceInputActive
    ; 如果正在语音输入，不显示快捷操作面板
    if (VoiceInputActive) {
        return
    }
    if (CapsLock && !PanelVisible) {
        ShowCursorPanel()
    }
}

; 长按CapsLock屏蔽语音输入（定时器函数）
global CapsLockPressTime := 0
BlockVoiceInputTimer(*) {
    global VoiceInputBlocked, CapsLockPressTime
    ; 记录按下时间
    CapsLockPressTime := A_TickCount
    VoiceInputBlocked := true
    TrayTip("语音输入已屏蔽", "提示", "Iconi 1")
}

; 采用 CapsLock+ 方案：使用 ~ 前缀保留原始功能，通过标记变量控制行为
~CapsLock:: {
    global CapsLock, CapsLock2, IsCommandMode, PanelVisible, VoiceInputActive, VoiceInputMethod, VoiceInputBlocked, VoiceInputPaused
    
    ; 标记 CapsLock 已按下
    CapsLock := true
    CapsLock2 := true  ; 初始化为 true，如果使用了功能会被清除
    IsCommandMode := false
    
    ; 记录按下时间
    CapsLockPressTime := A_TickCount
    
    ; 如果正在语音输入，处理暂停/恢复逻辑
    if (VoiceInputActive) {
        ; 设置定时器：300ms 后清除 CapsLock2（用于检测是否按了其他键）
        SetTimer(ClearCapsLock2Timer, -300)
        
        ; 如果未暂停，则暂停语音输入
        if (!VoiceInputPaused) {
            VoiceInputPaused := true
            UpdateVoiceInputPausedState(true)
            
            ; 暂停百度输入法语音转换（F1）
            if (VoiceInputMethod = "baidu") {
                Send("{F1}")
                Sleep(200)
            }
        }
        
        ; 等待 CapsLock 释放
        KeyWait("CapsLock")
        
        ; 停止定时器
        SetTimer(ClearCapsLock2Timer, 0)
        
        ; 计算按下时长
        PressDuration := A_TickCount - CapsLockPressTime
        
        ; 如果长按超过1.5秒，切换屏蔽状态（不恢复语音）
        if (PressDuration >= 1500) {
            VoiceInputBlocked := !VoiceInputBlocked
            if (VoiceInputBlocked) {
                TrayTip("语音输入已屏蔽", "提示", "Iconi 1")
            } else {
                TrayTip("语音输入已启用", "提示", "Iconi 1")
            }
            ; 如果之前暂停了，保持暂停状态
            if (VoiceInputPaused) {
                ; 不恢复，保持暂停
            }
            CapsLock := false
            CapsLock2 := false
            return
        }
        
        ; 如果按了其他键（如Z），CapsLock2会被清除，不恢复语音
        ; 如果只按了CapsLock（CapsLock2仍然为true），且是短按，则恢复语音输入
        if (CapsLock2 && PressDuration < 1500) {
            ; 只按了CapsLock，没有按其他键，恢复语音输入
            if (VoiceInputPaused) {
                VoiceInputPaused := false
                UpdateVoiceInputPausedState(false)  ; 更新动画状态，显示恢复
                
                ; 恢复百度输入法语音转换（F2）
                if (VoiceInputMethod = "baidu") {
                    Send("{F2}")
                    Sleep(200)
                }
            }
        }
        
        CapsLock := false
        CapsLock2 := false
        return
    }
    
    ; 如果未在语音输入，执行正常的 CapsLock+ 逻辑
    ; 设置定时器：300ms 后清除 CapsLock2（犹豫操作时间）
    ; 如果在这 300ms 内使用了 CapsLock+ 功能，CapsLock2 会被提前清除
    SetTimer(ClearCapsLock2Timer, -300)
    
    ; 设置定时器：长按 1.5 秒后屏蔽语音输入
    SetTimer(BlockVoiceInputTimer, -1500)
    
    ; 设置定时器：长按 0.5 秒后自动显示面板（不在语音输入时）
    SetTimer(ShowPanelTimer, -500)
    
    ; 等待 CapsLock 释放
    KeyWait("CapsLock")
    
    ; 计算按下时长
    PressDuration := A_TickCount - CapsLockPressTime
    
    ; 停止所有定时器
    SetTimer(ClearCapsLock2Timer, 0)
    SetTimer(ShowPanelTimer, 0)
    SetTimer(BlockVoiceInputTimer, 0)
    
    ; 检查是否长按（超过1.5秒）来切换屏蔽状态
    if (PressDuration >= 1500) {
        ; 长按超过1.5秒，切换屏蔽状态
        VoiceInputBlocked := !VoiceInputBlocked
        if (VoiceInputBlocked) {
            TrayTip("语音输入已屏蔽", "提示", "Iconi 1")
        } else {
            TrayTip("语音输入已启用", "提示", "Iconi 1")
        }
        CapsLock := false
        CapsLock2 := false
        return
    }
    
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

GetPanelPosition(ScreenInfo, Width, Height, PosType := "Center") {
    ; 默认为居中
    X := ScreenInfo.Left + (ScreenInfo.Width - Width) // 2
    Y := ScreenInfo.Top + (ScreenInfo.Height - Height) // 2
    
    switch PosType {
        case "TopLeft":
            X := ScreenInfo.Left + 20
            Y := ScreenInfo.Top + 20
        case "TopRight":
            X := ScreenInfo.Right - Width - 20
            Y := ScreenInfo.Top + 20
        case "BottomLeft":
            X := ScreenInfo.Left + 20
            Y := ScreenInfo.Bottom - Height - 20
        case "BottomRight":
            X := ScreenInfo.Right - Width - 20
            Y := ScreenInfo.Bottom - Height - 20
    }
    
    return {X: X, Y: Y}
}

; ===================== 显示面板函数 =====================
ShowCursorPanel() {
    global PanelVisible, GuiID_CursorPanel, SplitHotkey, BatchHotkey, CapsLock2
    global PanelScreenIndex, FunctionPanelPos
    
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
        TitleText := GuiID_CursorPanel.Add("Text", "x20 y12 w380 h26 Center cFFFFFF", GetText("panel_title"))
        TitleText.SetFont("s13 Bold", "Segoe UI")
        
        ; 分隔线
        GuiID_CursorPanel.Add("Text", "x0 y50 w420 h1 Background3c3c3c", "")
        
        ; 提示文本（更小的字体，更柔和的颜色）
        HintText := GuiID_CursorPanel.Add("Text", "x20 y60 w380 h18 Center c888888", FormatText("split_hint", SplitHotkey, BatchHotkey))
        HintText.SetFont("s9", "Segoe UI")
        
        ; 按钮区域（Cursor 风格的按钮）
        ; 解释代码按钮
        BtnExplain := GuiID_CursorPanel.Add("Button", "x30 y90 w360 h42", GetText("explain_code"))
        BtnExplain.SetFont("s11 cFFFFFF", "Segoe UI")
        BtnExplain.OnEvent("Click", (*) => ExecutePrompt("Explain"))
        
        ; 重构代码按钮
        BtnRefactor := GuiID_CursorPanel.Add("Button", "x30 y140 w360 h42", GetText("refactor_code"))
        BtnRefactor.SetFont("s11 cFFFFFF", "Segoe UI")
        BtnRefactor.OnEvent("Click", (*) => ExecutePrompt("Refactor"))
        
        ; 优化代码按钮
        BtnOptimize := GuiID_CursorPanel.Add("Button", "x30 y190 w360 h42", GetText("optimize_code"))
        BtnOptimize.SetFont("s11 cFFFFFF", "Segoe UI")
        BtnOptimize.OnEvent("Click", (*) => ExecutePrompt("Optimize"))
        
        ; 配置面板按钮
        BtnConfig := GuiID_CursorPanel.Add("Button", "x30 y240 w360 h36", GetText("open_config"))
        BtnConfig.SetFont("s10 cFFFFFF", "Segoe UI")
        BtnConfig.OnEvent("Click", OpenConfigFromPanel)
        
        ; 底部提示文本
        FooterText := GuiID_CursorPanel.Add("Text", "x20 y290 w380 h50 Center c666666", GetText("footer_hint"))
        FooterText.SetFont("s9", "Segoe UI")
        
        ; 底部边框
        GuiID_CursorPanel.Add("Text", "x0 y360 w420 h10 Background1e1e1e", "")
    }
    
    ; 获取屏幕信息并计算位置
    ScreenInfo := GetScreenInfo(PanelScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, FunctionPanelPos)
    
    ; 显示面板
    GuiID_CursorPanel.Show("w" . PanelWidth . " h" . PanelHeight . " x" . Pos.X . " y" . Pos.Y . " NoActivate")
    
    ; 确保窗口在最上层
    WinSetAlwaysOnTop(1, GuiID_CursorPanel.Hwnd)
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
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize, CursorPath, AISleepTime, IsCommandMode, CapsLock2, ClipboardHistory
    
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
    ; 在切换窗口之前，先保存当前剪贴板内容
    OldClipboard := A_Clipboard
    
    ; 1. 保存当前剪贴板到历史记录（解决污染问题，防止用户数据丢失）
    if (OldClipboard != "") {
        ClipboardHistory.Push(OldClipboard)
    }
    
    SelectedCode := ""
    
    ; 尝试从当前活动窗口复制选中文本
    if WinActive("ahk_exe Cursor.exe") {
        Send("{Esc}")
        Sleep(50)
        A_Clipboard := "" ; 清空剪贴板以通过 ClipWait 检测
        Send("^c")
        if ClipWait(0.5) { ; 智能等待复制完成
            SelectedCode := A_Clipboard
        }
        ; 恢复剪贴板，避免影响后续判断
        A_Clipboard := OldClipboard
    } else {
        CurrentActiveWindow := WinGetID("A")
        A_Clipboard := ""
        Send("^c")
        if ClipWait(0.5) {
            SelectedCode := A_Clipboard
        }
        A_Clipboard := OldClipboard
    }
    
    ; 激活 Cursor 窗口
    try {
        if WinExist("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 1)
            Sleep(200)
            
            ; 如果之前没有获取到选中文本，再次尝试在 Cursor 内复制
            if (SelectedCode = "" && WinActive("ahk_exe Cursor.exe")) {
                Send("{Esc}")
                Sleep(50)
                A_Clipboard := ""
                Send("^c")
                if ClipWait(0.5) {
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
            if !ClipWait(1) {
                Sleep(100)
            }
            
            if !WinActive("ahk_exe Cursor.exe") {
                WinActivate("ahk_exe Cursor.exe")
                Sleep(200)
            }
            
            Send("{Esc}")
            Sleep(100)
            
            ; 打开聊天面板
            Send("^l")
            Sleep(400)
            
            if !WinActive("ahk_exe Cursor.exe") {
                WinActivate("ahk_exe Cursor.exe")
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

; ===================== 分割代码功能 =====================
SplitCode() {
    global CursorPath, AISleepTime, CapsLock2, ClipboardHistory
    
    CapsLock2 := false  ; 清除标记，表示使用了功能
    HideCursorPanel()
    
    try {
        if WinExist("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            Sleep(200)
            
            ; 复制选中的代码
            OldClipboard := A_Clipboard
            ; 保存原始剪贴板到历史
            if (OldClipboard != "") {
                ClipboardHistory.Push(OldClipboard)
            }
            
            A_Clipboard := ""
            Send("^c")
            if !ClipWait(0.5) {
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
            if ClipWait(0.5) {
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

; ===================== 配置面板辅助函数 =====================
; 这些函数需要在 ShowConfigGUI 之前定义

; 全局变量声明
global CurrentTab := ""
global ConfigTabs := Map()
global GeneralTabPanel := 0
global GeneralTabControls := []
global AppearanceTabPanel := 0
global AppearanceTabControls := []
global PromptsTabPanel := 0
global PromptsTabControls := []
global HotkeysTabPanel := 0
global HotkeysTabControls := []
global AdvancedTabPanel := 0
global AdvancedTabControls := []
global CursorPathEdit := 0
global LangChinese := 0
global LangEnglish := 0
global AISleepTimeEdit := 0
global PromptExplainEdit := 0
global PromptRefactorEdit := 0
global PromptOptimizeEdit := 0
global SplitHotkeyEdit := 0
global BatchHotkeyEdit := 0
global PanelScreenRadio := []

; ===================== 标签切换函数 =====================
SwitchTab(TabName) {
    global ConfigTabs, CurrentTab
    global GeneralTabControls, AppearanceTabControls, PromptsTabControls, HotkeysTabControls, AdvancedTabControls
    
    ; 重置所有标签样式
    for Key, TabBtn in ConfigTabs {
        if (TabBtn) {
            try {
                TabBtn.BackColor := "2d2d30"  ; 未选中状态
                TabBtn.SetFont("s11 cCCCCCC", "Segoe UI")
            }
        }
    }
    
    ; 设置当前标签样式（选中状态）
    if (ConfigTabs.Has(TabName) && ConfigTabs[TabName]) {
        try {
            ConfigTabs[TabName].BackColor := "1e1e1e"  ; 选中状态
            ConfigTabs[TabName].SetFont("s11 cFFFFFF", "Segoe UI")
        }
    }
    
    ; 辅助函数：可以隐藏控制列表
    HideControls(ControlList) {
        if (ControlList && ControlList.Length > 0) {
            for Ctrl in ControlList {
                try Ctrl.Visible := false
            }
        }
    }
    
    ; 辅助函数：显示控制列表
    ShowControls(ControlList) {
        if (ControlList && ControlList.Length > 0) {
            for Ctrl in ControlList {
                try Ctrl.Visible := true
            }
        }
    }

    ; 隐藏所有标签页内容
    HideControls(GeneralTabControls)
    HideControls(AppearanceTabControls)
    HideControls(PromptsTabControls)
    HideControls(HotkeysTabControls)
    HideControls(AdvancedTabControls)
    
    ; 显示当前标签页内容
    switch TabName {
        case "general":
            ShowControls(GeneralTabControls)
        case "appearance":
            ShowControls(AppearanceTabControls)
        case "prompts":
            ShowControls(PromptsTabControls)
        case "hotkeys":
            ShowControls(HotkeysTabControls)
        case "advanced":
            ShowControls(AdvancedTabControls)
    }
    
    CurrentTab := TabName
}

; ===================== 创建通用标签页 =====================
CreateGeneralTab(ConfigGUI, X, Y, W, H) {
    global CursorPath, Language, GeneralTabPanel, CursorPathEdit, LangChinese, LangEnglish, BtnBrowse, GeneralTabControls
    global UI_Colors
    
    ; 创建标签页面板
    GeneralTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vGeneralTabPanel", "")
    GeneralTabControls.Push(GeneralTabPanel)
    
    ; 标题
    Title := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (Y + 20) . " w" . (W - 60) . " h30 c" . UI_Colors.Text, GetText("general_settings"))
    Title.SetFont("s16 Bold", "Segoe UI")
    GeneralTabControls.Push(Title)
    
    ; Cursor 路径设置
    YPos := Y + 70
    Label1 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("cursor_path"))
    Label1.SetFont("s11", "Segoe UI")
    GeneralTabControls.Push(Label1)
    
    YPos += 30
    CursorPathEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w" . (W - 150) . " h30 vCursorPathEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, CursorPath)
    CursorPathEdit.SetFont("s11", "Segoe UI")
    GeneralTabControls.Push(CursorPathEdit)
    
    ; 浏览按钮 (自定义样式)
    BtnBrowse := ConfigGUI.Add("Text", "x" . (X + W - 110) . " y" . YPos . " w80 h30 Center 0x200 cWhite Background" . UI_Colors.BtnBg . " vBtnBrowse", GetText("browse"))
    BtnBrowse.SetFont("s10", "Segoe UI")
    BtnBrowse.OnEvent("Click", BrowseCursorPath)
    HoverBtn(BtnBrowse, UI_Colors.BtnBg, UI_Colors.BtnHover)
    GeneralTabControls.Push(BtnBrowse)
    
    YPos += 40
    Hint1 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h20 c" . UI_Colors.TextDim, GetText("cursor_path_hint"))
    Hint1.SetFont("s9", "Segoe UI")
    GeneralTabControls.Push(Hint1)
    
    ; 语言设置
    YPos += 50
    Label2 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("language_setting"))
    Label2.SetFont("s11", "Segoe UI")
    GeneralTabControls.Push(Label2)
    
    YPos += 30
    LangChinese := ConfigGUI.Add("Radio", "x" . (X + 30) . " y" . YPos . " w100 h30 vLangChinese c" . UI_Colors.Text, GetText("language_chinese"))
    LangChinese.SetFont("s11", "Segoe UI")
    LangChinese.BackColor := UI_Colors.Background
    GeneralTabControls.Push(LangChinese)
    
    LangEnglish := ConfigGUI.Add("Radio", "x" . (X + 140) . " y" . YPos . " w100 h30 vLangEnglish c" . UI_Colors.Text, GetText("language_english"))
    LangEnglish.SetFont("s11", "Segoe UI")
    LangEnglish.BackColor := UI_Colors.Background
    GeneralTabControls.Push(LangEnglish)
    
    ; 设置当前语言
    if (Language = "zh") {
        LangChinese.Value := 1
    } else {
        LangEnglish.Value := 1
    }
}

; ===================== 创建外观标签页 =====================
CreateAppearanceTab(ConfigGUI, X, Y, W, H) {
    global PanelScreenIndex, AppearanceTabPanel, PanelScreenRadio, AppearanceTabControls
    global FunctionPanelPos, ConfigPanelPos, ClipboardPanelPos
    global FuncPosDDL, ConfigPosDDL, ClipPosDDL
    global UI_Colors
    
    ; 创建标签页面板（默认隐藏）
    AppearanceTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vAppearanceTabPanel", "")
    AppearanceTabPanel.Visible := false
    AppearanceTabControls.Push(AppearanceTabPanel)
    
    ; 标题
    Title := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (Y + 20) . " w" . (W - 60) . " h30 c" . UI_Colors.Text, GetText("appearance_settings"))
    Title.SetFont("s16 Bold", "Segoe UI")
    AppearanceTabControls.Push(Title)
    
    ; 屏幕选择
    YPos := Y + 70
    Label1 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("display_screen"))
    Label1.SetFont("s11", "Segoe UI")
    AppearanceTabControls.Push(Label1)
    
    ; 获取屏幕列表
    ScreenList := []
    MonitorCount := 0
    try {
        MonitorCount := MonitorGetCount()
        if (MonitorCount > 0) {
            Loop MonitorCount {
                MonitorIndex := A_Index
                MonitorGet(MonitorIndex, &Left, &Top, &Right, &Bottom)
                ScreenList.Push(FormatText("screen", MonitorIndex))
            }
        }
    } catch {
        MonitorIndex := 1
        Loop 10 {
            try {
                MonitorGet(MonitorIndex, &Left, &Top, &Right, &Bottom)
                ScreenList.Push(FormatText("screen", MonitorIndex))
                MonitorCount++
                MonitorIndex++
            } catch {
                break
            }
        }
    }
    if (ScreenList.Length = 0) {
        ScreenList.Push(FormatText("screen", 1))
        MonitorCount := 1
    }
    
    YPos += 30
    PanelScreenRadio := []
    StartX := X + 30
    RadioWidth := 100
    RadioHeight := 30
    Spacing := 10
    for Index, ScreenName in ScreenList {
        XPos := StartX + (Index - 1) * (RadioWidth + Spacing)
        RadioBtn := ConfigGUI.Add("Radio", "x" . XPos . " y" . YPos . " w" . RadioWidth . " h" . RadioHeight . " vPanelScreenRadio" . Index . " c" . UI_Colors.Text, ScreenName)
        RadioBtn.SetFont("s11", "Segoe UI")
        RadioBtn.BackColor := UI_Colors.Background
        if (Index = PanelScreenIndex) {
            RadioBtn.Value := 1
        }
        PanelScreenRadio.Push(RadioBtn)
        AppearanceTabControls.Push(RadioBtn)
    }

    ; 面板位置设置
    ; 位置选项 (内部值)
    PosKeys := ["Center", "TopLeft", "TopRight", "BottomLeft", "BottomRight"]
    ; 显示文本
    PosTexts := [GetText("pos_center"), GetText("pos_top_left"), GetText("pos_top_right"), GetText("pos_bottom_left"), GetText("pos_bottom_right")]
    
    ; 1. 功能面板
    YPos += 60
    LabelFunc := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("panel_pos_func"))
    LabelFunc.SetFont("s11", "Segoe UI")
    AppearanceTabControls.Push(LabelFunc)
    
    FuncPosDDL := ConfigGUI.Add("DropDownList", "x" . (X + 240) . " y" . YPos . " w150 Choose1 vFuncPosDDL AltSubmit", PosTexts)
    FuncPosDDL.SetFont("s10")
    ; 设置当前选中项
    for i, key in PosKeys {
        if (key = FunctionPanelPos) {
            FuncPosDDL.Choose(i)
            break
        }
    }
    AppearanceTabControls.Push(FuncPosDDL)
    
    ; 2. 设置面板
    YPos += 40
    LabelConfig := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("panel_pos_config"))
    LabelConfig.SetFont("s11", "Segoe UI")
    AppearanceTabControls.Push(LabelConfig)
    
    ConfigPosDDL := ConfigGUI.Add("DropDownList", "x" . (X + 240) . " y" . YPos . " w150 Choose1 vConfigPosDDL AltSubmit", PosTexts)
    ConfigPosDDL.SetFont("s10")
    for i, key in PosKeys {
        if (key = ConfigPanelPos) {
            ConfigPosDDL.Choose(i)
            break
        }
    }
    AppearanceTabControls.Push(ConfigPosDDL)
    
    ; 3. 剪贴板面板
    YPos += 40
    LabelClip := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("panel_pos_clip"))
    LabelClip.SetFont("s11", "Segoe UI")
    AppearanceTabControls.Push(LabelClip)
    
    ClipPosDDL := ConfigGUI.Add("DropDownList", "x" . (X + 240) . " y" . YPos . " w150 Choose1 vClipPosDDL AltSubmit", PosTexts)
    ClipPosDDL.SetFont("s10")
    for i, key in PosKeys {
        if (key = ClipboardPanelPos) {
            ClipPosDDL.Choose(i)
            break
        }
    }
    AppearanceTabControls.Push(ClipPosDDL)
}

; ===================== 创建提示词标签页 =====================
CreatePromptsTab(ConfigGUI, X, Y, W, H) {
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize, PromptsTabPanel, PromptExplainEdit, PromptRefactorEdit, PromptOptimizeEdit, PromptsTabControls
    global UI_Colors
    
    ; 创建标签页面板（默认隐藏）
    PromptsTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vPromptsTabPanel", "")
    PromptsTabPanel.Visible := false
    PromptsTabControls.Push(PromptsTabPanel)
    
    ; 标题
    Title := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (Y + 20) . " w" . (W - 60) . " h30 c" . UI_Colors.Text, GetText("prompt_settings"))
    Title.SetFont("s16 Bold", "Segoe UI")
    PromptsTabControls.Push(Title)
    
    ; 解释代码提示词
    YPos := Y + 70
    Label1 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h25 c" . UI_Colors.Text, GetText("explain_prompt"))
    Label1.SetFont("s11", "Segoe UI")
    PromptsTabControls.Push(Label1)
    
    YPos += 30
    PromptExplainEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h80 vPromptExplainEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " Multi", Prompt_Explain)
    PromptExplainEdit.SetFont("s10", "Consolas")
    PromptsTabControls.Push(PromptExplainEdit)
    
    ; 重构代码提示词
    YPos += 100
    Label2 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h25 c" . UI_Colors.Text, GetText("refactor_prompt"))
    Label2.SetFont("s11", "Segoe UI")
    PromptsTabControls.Push(Label2)
    
    YPos += 30
    PromptRefactorEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h80 vPromptRefactorEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " Multi", Prompt_Refactor)
    PromptRefactorEdit.SetFont("s10", "Consolas")
    PromptsTabControls.Push(PromptRefactorEdit)
    
    ; 优化代码提示词
    YPos += 100
    Label3 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h25 c" . UI_Colors.Text, GetText("optimize_prompt"))
    Label3.SetFont("s11", "Segoe UI")
    PromptsTabControls.Push(Label3)
    
    YPos += 30
    PromptOptimizeEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h80 vPromptOptimizeEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " Multi", Prompt_Optimize)
    PromptOptimizeEdit.SetFont("s10", "Consolas")
    PromptsTabControls.Push(PromptOptimizeEdit)
}

; ===================== 创建快捷键标签页 =====================
CreateHotkeysTab(ConfigGUI, X, Y, W, H) {
    global SplitHotkey, BatchHotkey, HotkeysTabPanel, SplitHotkeyEdit, BatchHotkeyEdit, HotkeysTabControls
    global UI_Colors
    
    ; 创建标签页面板（默认隐藏）
    HotkeysTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vHotkeysTabPanel", "")
    HotkeysTabPanel.Visible := false
    HotkeysTabControls.Push(HotkeysTabPanel)
    
    ; 标题
    Title := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (Y + 20) . " w" . (W - 60) . " h30 c" . UI_Colors.Text, GetText("hotkey_settings"))
    Title.SetFont("s16 Bold", "Segoe UI")
    HotkeysTabControls.Push(Title)
    
    ; 分割快捷键
    YPos := Y + 70
    Label1 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("split_hotkey"))
    Label1.SetFont("s11", "Segoe UI")
    HotkeysTabControls.Push(Label1)
    
    YPos += 30
    SplitHotkeyEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w100 h30 vSplitHotkeyEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, SplitHotkey)
    SplitHotkeyEdit.SetFont("s11", "Segoe UI")
    HotkeysTabControls.Push(SplitHotkeyEdit)
    
    YPos += 40
    Hint1 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h20 c" . UI_Colors.TextDim, FormatText("single_char_hint", "s"))
    Hint1.SetFont("s9", "Segoe UI")
    HotkeysTabControls.Push(Hint1)
    
    ; 批量操作快捷键
    YPos += 40
    Label2 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("batch_hotkey"))
    Label2.SetFont("s11", "Segoe UI")
    HotkeysTabControls.Push(Label2)
    
    YPos += 30
    BatchHotkeyEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w100 h30 vBatchHotkeyEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, BatchHotkey)
    BatchHotkeyEdit.SetFont("s11", "Segoe UI")
    HotkeysTabControls.Push(BatchHotkeyEdit)
    
    YPos += 40
    Hint2 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h20 c" . UI_Colors.TextDim, FormatText("single_char_hint", "b"))
    Hint2.SetFont("s9", "Segoe UI")
    HotkeysTabControls.Push(Hint2)
}

; ===================== 创建高级标签页 =====================
CreateAdvancedTab(ConfigGUI, X, Y, W, H) {
    global AISleepTime, AdvancedTabPanel, AISleepTimeEdit, AdvancedTabControls
    global UI_Colors
    
    ; 创建标签页面板（默认隐藏）
    AdvancedTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vAdvancedTabPanel", "")
    AdvancedTabPanel.Visible := false
    AdvancedTabControls.Push(AdvancedTabPanel)
    
    ; 标题
    Title := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (Y + 20) . " w" . (W - 60) . " h30 c" . UI_Colors.Text, GetText("advanced_settings"))
    Title.SetFont("s16 Bold", "Segoe UI")
    AdvancedTabControls.Push(Title)
    
    ; AI 响应等待时间
    YPos := Y + 70
    Label1 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("ai_wait_time"))
    Label1.SetFont("s11", "Segoe UI")
    AdvancedTabControls.Push(Label1)
    
    YPos += 30
    AISleepTimeEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w150 h30 vAISleepTimeEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, AISleepTime)
    AISleepTimeEdit.SetFont("s11", "Segoe UI")
    AdvancedTabControls.Push(AISleepTimeEdit)
    
    YPos += 40
    Hint1 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h20 c" . UI_Colors.TextDim, GetText("ai_wait_hint"))
    Hint1.SetFont("s9", "Segoe UI")
    AdvancedTabControls.Push(Hint1)
}

; ===================== 浏览 Cursor 路径 =====================
BrowseCursorPath(*) {
    global CursorPathEdit
    FilePath := FileSelect(1, , "选择 Cursor.exe", "可执行文件 (*.exe)")
    if (FilePath != "" && CursorPathEdit) {
        CursorPathEdit.Value := FilePath
    }
}

; ===================== 重置为默认值 =====================
ResetToDefaults(*) {
    global CursorPathEdit, AISleepTimeEdit, PromptExplainEdit, PromptRefactorEdit, PromptOptimizeEdit
    global SplitHotkeyEdit, BatchHotkeyEdit, PanelScreenRadio
    
    ; 确认对话框
    Result := MsgBox(GetText("confirm_reset"), GetText("confirm"), "YesNo Icon?")
    if (Result != "Yes") {
        return
    }
    
    DefaultCursorPath := "C:\Users\" A_UserName "\AppData\Local\Cursor\Cursor.exe"
    DefaultAISleepTime := 15000
    DefaultPrompt_Explain := GetText("default_prompt_explain")
    DefaultPrompt_Refactor := GetText("default_prompt_refactor")
    DefaultPrompt_Optimize := GetText("default_prompt_optimize")
    DefaultSplitHotkey := "s"
    DefaultBatchHotkey := "b"
    DefaultPanelScreenIndex := 1
    
    try {
        if (IsSet(CursorPathEdit) && CursorPathEdit) CursorPathEdit.Value := DefaultCursorPath
        if (IsSet(AISleepTimeEdit) && AISleepTimeEdit) AISleepTimeEdit.Value := DefaultAISleepTime
        if (IsSet(PromptExplainEdit) && PromptExplainEdit) PromptExplainEdit.Value := DefaultPrompt_Explain
        if (IsSet(PromptRefactorEdit) && PromptRefactorEdit) PromptRefactorEdit.Value := DefaultPrompt_Refactor
        if (IsSet(PromptOptimizeEdit) && PromptOptimizeEdit) PromptOptimizeEdit.Value := DefaultPrompt_Optimize
        if (IsSet(SplitHotkeyEdit) && SplitHotkeyEdit) SplitHotkeyEdit.Value := DefaultSplitHotkey
        if (IsSet(BatchHotkeyEdit) && BatchHotkeyEdit) BatchHotkeyEdit.Value := DefaultBatchHotkey
        
        ; 重置屏幕选择
        if (IsSet(PanelScreenRadio) && PanelScreenRadio && PanelScreenRadio.Length > 0) {
            for Index, RadioBtn in PanelScreenRadio {
                RadioBtn.Value := 0
            }
            if (DefaultPanelScreenIndex >= 1 && DefaultPanelScreenIndex <= PanelScreenRadio.Length) {
                PanelScreenRadio[DefaultPanelScreenIndex].Value := 1
            } else if (PanelScreenRadio.Length > 0) {
                PanelScreenRadio[1].Value := 1
            }
        }
    } catch {
        ; 忽略控件失效错误
    }
    
    MsgBox(GetText("reset_default_success"), GetText("tip"), "Iconi")
}

; ===================== UI 常量定义 =====================
global UI_Colors := {
    Background: "1e1e1e",
    Sidebar: "252526",
    Border: "3c3c3c", 
    Text: "cccccc",
    TextDim: "888888",
    InputBg: "3c3c3c",
    BtnBg: "3c3c3c",
    BtnHover: "4c4c4c",
    BtnPrimary: "0e639c",
    BtnPrimaryHover: "1177bb",
    TabActive: "37373d",
    TitleBar: "252526"
}

; 窗口拖动事件
WM_LBUTTONDOWN(*) {
    PostMessage(0xA1, 2)
}

; 自定义按钮悬停效果
HoverBtn(Ctrl, NormalColor, HoverColor) {
    Ctrl.NormalColor := NormalColor
    Ctrl.HoverColor := HoverColor
}

; 全局变量记录当前悬停控件
global LastHoverCtrl := 0

; 监听鼠标移动消息实现 Hover
OnMessage(0x0200, WM_MOUSEMOVE)

WM_MOUSEMOVE(wParam, lParam, Msg, Hwnd) {
    global LastHoverCtrl
    
    try {
        ; 获取鼠标下的控件
        MouseCtrl := GuiCtrlFromHwnd(Hwnd)
        
        ; 如果是新控件且具有 Hover 属性
        if (MouseCtrl && MouseCtrl.HasProp("HoverColor")) {
            if (LastHoverCtrl != MouseCtrl) {
                ; 恢复上一个控件颜色
                if (LastHoverCtrl && LastHoverCtrl.HasProp("NormalColor")) {
                    try LastHoverCtrl.BackColor := LastHoverCtrl.NormalColor
                }
                
                ; 设置新控件颜色
                try MouseCtrl.BackColor := MouseCtrl.HoverColor
                LastHoverCtrl := MouseCtrl
                
                ; 启动定时器检测鼠标离开
                SetTimer CheckMouseLeave, 50
            }
        }
    }
}

CheckMouseLeave() {
    global LastHoverCtrl
    
    if (!LastHoverCtrl) {
        SetTimer , 0
        return
    }
    
    try {
        MouseGetPos ,,, &MouseHwnd, 2
        
        ; 如果鼠标不在当前控件上
        if (MouseHwnd != LastHoverCtrl.Hwnd) {
            if (LastHoverCtrl.HasProp("NormalColor")) {
                try LastHoverCtrl.BackColor := LastHoverCtrl.NormalColor
            }
            LastHoverCtrl := 0
            SetTimer , 0
        }
    } catch {
        ; 出错时清理
        LastHoverCtrl := 0
        SetTimer , 0
    }
}

; ===================== 显示使用说明 =====================
ShowHelp(*) {
    HelpText := "
    (
    ════════════════════════════════════════════════════
    Cursor助手 - 使用说明
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
    MsgBox(HelpText, GetText("help_title"), "Iconi")
}

; ===================== 配置面板函数 =====================
; ===================== 配置面板函数 =====================
ShowConfigGUI() {
    global CursorPath, AISleepTime, Prompt_Explain, Prompt_Refactor, Prompt_Optimize
    global SplitHotkey, BatchHotkey, ConfigFile, Language
    global PanelScreenIndex, PanelPosition
    global UI_Colors, GuiID_ConfigGUI, GuiID_ClipboardManager
    
    ; 单例模式:如果配置面板已存在,直接激活
    if (GuiID_ConfigGUI != 0) {
        try {
            WinActivate(GuiID_ConfigGUI.Hwnd)
            return
        } catch {
            ; 如果窗口已被销毁,继续创建新的
            GuiID_ConfigGUI := 0
        }
    }
    
    ; 关闭剪贴板面板（确保一次只激活一个面板）
    if (GuiID_ClipboardManager != 0) {
        try {
            GuiID_ClipboardManager.Destroy()
            GuiID_ClipboardManager := 0
        } catch {
            GuiID_ClipboardManager := 0
        }
    }
    
    ; 清空全局控件数组，防止残留
    global GeneralTabControls := []
    global AppearanceTabControls := []
    global PromptsTabControls := []
    global HotkeysTabControls := []
    global AdvancedTabControls := []
    
    ; 创建配置 GUI（无边框窗口）
    ConfigGUI := Gui("+Resize -MaximizeBox -Caption +Border", GetText("config_title"))
    ConfigGUI.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
    ConfigGUI.BackColor := UI_Colors.Background
    
    ; 窗口尺寸
    ConfigWidth := 900
    ConfigHeight := 700
    
    ; ========== 自定义标题栏 (35px) ==========
    ; 调整标题栏宽度，避免覆盖关闭按钮
    TitleBar := ConfigGUI.Add("Text", "x0 y0 w" . (ConfigWidth - 40) . " h35 Background" . UI_Colors.TitleBar, "")
    TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2)) ; 拖动窗口
    
    ; 窗口标题
    WinTitle := ConfigGUI.Add("Text", "x15 y8 w200 h20 Background" . UI_Colors.TitleBar . " c" . UI_Colors.Text, GetText("config_title"))
    WinTitle.SetFont("s10 Bold", "Segoe UI")
    WinTitle.OnEvent("Click", (*) => PostMessage(0xA1, 2))
    
    ; 关闭按钮 (右上角)
    ; 确保关闭按钮在最上层
    CloseBtn := ConfigGUI.Add("Text", "x" . (ConfigWidth - 40) . " y0 w40 h35 Center 0x200 Background" . UI_Colors.TitleBar . " c" . UI_Colors.Text, "✕")
    CloseBtn.SetFont("s10", "Segoe UI")
    CloseBtn.OnEvent("Click", (*) => CloseConfigGUI())
    HoverBtn(CloseBtn, UI_Colors.TitleBar, "e81123") ; 红色关闭 hover
    
    ; ========== 左侧侧边栏 (200px) ==========
    SidebarWidth := 200
    SidebarBg := ConfigGUI.Add("Text", "x0 y35 w" . SidebarWidth . " h" . (ConfigHeight - 35) . " Background" . UI_Colors.Sidebar, "")
    
    ; 侧边栏搜索框
    SearchBg := ConfigGUI.Add("Text", "x10 y45 w" . (SidebarWidth - 20) . " h30 Background" . UI_Colors.InputBg, "")
    global SearchEdit := ConfigGUI.Add("Edit", "x15 y50 w" . (SidebarWidth - 30) . " h20 vSearchEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " -E0x200", "") 
    SearchEdit.SetFont("s9", "Segoe UI")
    
    global SearchHint := ConfigGUI.Add("Text", "x15 y50 w" . (SidebarWidth - 30) . " h20 c" . UI_Colors.TextDim . " Background" . UI_Colors.InputBg, "Search settings...")
    SearchHint.SetFont("s9 Italic", "Segoe UI")
    
    ; 标签按钮起始位置
    TabY := 90
    TabHeight := 35
    TabSpacing := 2
    
    ; 创建侧边栏标签按钮的辅助函数
    CreateSidebarTab(Label, Name, YPos) {
        Btn := ConfigGUI.Add("Text", "x0 y" . YPos . " w" . SidebarWidth . " h" . TabHeight . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.Sidebar . " vTab" . Name, Label)
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", (*) => SwitchTab(Name))
        HoverBtn(Btn, UI_Colors.Sidebar, UI_Colors.TabActive)
        return Btn
    }
    
    TabGeneral := CreateSidebarTab(GetText("tab_general"), "general", TabY)
    TabAppearance := CreateSidebarTab(GetText("tab_appearance"), "appearance", TabY + (TabHeight + TabSpacing))
    TabPrompts := CreateSidebarTab(GetText("tab_prompts"), "prompts", TabY + (TabHeight + TabSpacing) * 2)
    TabHotkeys := CreateSidebarTab(GetText("tab_hotkeys"), "hotkeys", TabY + (TabHeight + TabSpacing) * 3)
    TabAdvanced := CreateSidebarTab(GetText("tab_advanced"), "advanced", TabY + (TabHeight + TabSpacing) * 4)
    
    ; ========== 右侧内容区域 ==========
    ContentX := SidebarWidth
    ContentWidth := ConfigWidth - SidebarWidth
    ContentY := 35
    ContentHeight := ConfigHeight - 35 - 50 ; 留出底部按钮空间
    
    ; 保存标签控件的引用
    ConfigTabs := Map(
        "general", TabGeneral,
        "appearance", TabAppearance,
        "prompts", TabPrompts,
        "hotkeys", TabHotkeys,
        "advanced", TabAdvanced
    )
    global ConfigTabs := ConfigTabs
    
    ; 创建各个标签页的内容面板 (注意: 此时传入的 Y 坐标是相对于窗口客户区的)
    CreateGeneralTab(ConfigGUI, ContentX, ContentY, ContentWidth, ContentHeight)
    CreateAppearanceTab(ConfigGUI, ContentX, ContentY, ContentWidth, ContentHeight)
    CreatePromptsTab(ConfigGUI, ContentX, ContentY, ContentWidth, ContentHeight)
    CreateHotkeysTab(ConfigGUI, ContentX, ContentY, ContentWidth, ContentHeight)
    CreateAdvancedTab(ConfigGUI, ContentX, ContentY, ContentWidth, ContentHeight)
    
    ; ========== 底部按钮区域 (右侧) ==========
    ButtonAreaY := ConfigHeight - 50
    ConfigGUI.Add("Text", "x" . ContentX . " y" . ButtonAreaY . " w" . ContentWidth . " h50 Background" . UI_Colors.Background, "") ; 遮挡背景
    
    ; 底部按钮辅助函数 
    CreateBottomBtn(Label, XPos, Action, IsPrimary := false) {
        BgColor := IsPrimary ? UI_Colors.BtnPrimary : UI_Colors.BtnBg
        HoverColor := IsPrimary ? UI_Colors.BtnPrimaryHover : UI_Colors.BtnHover
        
        Btn := ConfigGUI.Add("Text", "x" . XPos . " y" . (ButtonAreaY + 10) . " w80 h30 Center 0x200 cWhite Background" . BgColor, Label)
        Btn.SetFont("s9", "Segoe UI")
        Btn.OnEvent("Click", Action)
        HoverBtn(Btn, BgColor, HoverColor)
        return Btn
    }

    ; 计算按钮位置 (右对齐)
    BtnStartX := ConfigWidth - 460
    
    CreateBottomBtn(GetText("export_config"), BtnStartX, ExportConfig)
    CreateBottomBtn(GetText("import_config"), BtnStartX + 90, ImportConfig)
    CreateBottomBtn(GetText("reset_default"), BtnStartX + 180, ResetToDefaults)
    CreateBottomBtn(GetText("save_config"), BtnStartX + 270, SaveConfigAndClose, true) ; Primary
    CreateBottomBtn(GetText("cancel"), BtnStartX + 360, (*) => CloseConfigGUI())
    
    ; 默认显示通用标签
    SwitchTab("general")
    
    ; 获取屏幕信息并居中显示 (使用 ConfigPanelPos)
    ScreenInfo := GetScreenInfo(PanelScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, ConfigWidth, ConfigHeight, ConfigPanelPos)
    
    ; 搜索功能绑定
    SearchEdit.OnEvent("Change", (*) => FilterSettings(SearchEdit.Value))
    SearchEdit.OnEvent("Focus", SearchEditFocus)
    SearchEdit.OnEvent("LoseFocus", SearchEditLoseFocus)
    
    ; 保存ConfigGUI引用
    GuiID_ConfigGUI := ConfigGUI
    
    ConfigGUI.Show("w" . ConfigWidth . " h" . ConfigHeight . " x" . Pos.X . " y" . Pos.Y)
    
    ; 确保窗口在最上层并激活
    WinSetAlwaysOnTop(1, ConfigGUI.Hwnd)
    WinActivate(ConfigGUI.Hwnd)
}

; 关闭配置面板
CloseConfigGUI() {
    global GuiID_ConfigGUI
    if (GuiID_ConfigGUI != 0) {
        try {
            GuiID_ConfigGUI.Destroy()
        }
        GuiID_ConfigGUI := 0
    }
}

; ===================== 搜索框事件处理 =====================
SearchEditFocus(*) {
    global SearchHint
    try {
        if (SearchHint) {
            SearchHint.Visible := false
        }
    }
}

SearchEditLoseFocus(*) {
    global SearchEdit, SearchHint
    try {
        if (SearchEdit && SearchEdit.Value = "") {
            if (SearchHint) {
                SearchHint.Visible := true
            }
        }
    }
}

; ===================== 搜索功能 =====================
FilterSettings(SearchText) {
    global ConfigTabs, CurrentTab
    
    ; 如果搜索文本为空，显示所有标签
    if (SearchText = "") {
        ; 显示所有标签
        for Key, TabBtn in ConfigTabs {
            TabBtn.Visible := true
        }
        ; 如果当前标签存在，显示它
        if (CurrentTab && ConfigTabs.Has(CurrentTab)) {
            SwitchTab(CurrentTab)
        }
        return
    }
    
    ; 转换为小写以便搜索（不区分大小写）
    SearchLower := StrLower(SearchText)
    
    ; 定义每个标签的关键词（中英文）
    TabKeywords := Map(
        "general", ["通用", "general", "cursor", "路径", "path", "语言", "language", "设置", "settings"],
        "appearance", ["外观", "appearance", "屏幕", "screen", "显示", "display", "位置", "position"],
        "prompts", ["提示词", "prompt", "解释", "explain", "重构", "refactor", "优化", "optimize", "ai"],
        "hotkeys", ["快捷键", "hotkey", "分割", "split", "批量", "batch", "键盘", "keyboard"],
        "advanced", ["高级", "advanced", "ai", "等待", "wait", "时间", "time", "性能", "performance"]
    )
    
    ; 检查每个标签是否匹配搜索关键词
    for TabName, Keywords in TabKeywords {
        Match := false
        for Index, Keyword in Keywords {
            if (InStr(StrLower(Keyword), SearchLower)) {
                Match := true
                break
            }
        }
        
        ; 显示或隐藏标签
        if (ConfigTabs.Has(TabName)) {
            ConfigTabs[TabName].Visible := Match
        }
    }
    
    ; 如果当前标签被隐藏，切换到第一个可见的标签
    if (CurrentTab && ConfigTabs.Has(CurrentTab) && !ConfigTabs[CurrentTab].Visible) {
        for TabName, TabBtn in ConfigTabs {
            if (TabBtn.Visible) {
                SwitchTab(TabName)
                break
            }
        }
    }
}

; ===================== 保存配置函数 =====================
SaveConfig(*) {
    global AISleepTimeEdit, SplitHotkeyEdit, BatchHotkeyEdit, PanelScreenRadio
    global CursorPathEdit, PromptExplainEdit, PromptRefactorEdit, PromptOptimizeEdit
    global LangChinese, ConfigFile, GuiID_CursorPanel
    
    ; 验证输入
    if (!AISleepTimeEdit || AISleepTimeEdit.Value = "" || !IsNumber(AISleepTimeEdit.Value)) {
        MsgBox(GetText("ai_wait_time_error"), GetText("error"), "Iconx")
        return false
    }
    
    if (!SplitHotkeyEdit || SplitHotkeyEdit.Value = "" || StrLen(SplitHotkeyEdit.Value) > 1) {
        MsgBox(GetText("split_hotkey_error"), GetText("error"), "Iconx")
        return false
    }
    
    if (!BatchHotkeyEdit || BatchHotkeyEdit.Value = "" || StrLen(BatchHotkeyEdit.Value) > 1) {
        MsgBox(GetText("batch_hotkey_error"), GetText("error"), "Iconx")
        return false
    }
    
    ; 解析屏幕索引（Radio 按钮组）
    NewScreenIndex := 1
    if (PanelScreenRadio && PanelScreenRadio.Length > 0) {
        for Index, RadioBtn in PanelScreenRadio {
            if (RadioBtn.Value = 1) {
                NewScreenIndex := Index
                break
            }
        }
    }
    if (NewScreenIndex < 1) {
        NewScreenIndex := 1
    }
    
    ; 获取语言设置
    NewLanguage := (LangChinese && LangChinese.Value) ? "zh" : "en"
    
    ; 获取面板位置设置
    PosKeys := ["Center", "TopLeft", "TopRight", "BottomLeft", "BottomRight"]
    if (FuncPosDDL && FuncPosDDL.Value <= PosKeys.Length)
        FunctionPanelPos := PosKeys[FuncPosDDL.Value]
    if (ConfigPosDDL && ConfigPosDDL.Value <= PosKeys.Length)
        ConfigPanelPos := PosKeys[ConfigPosDDL.Value]
    if (ClipPosDDL && ClipPosDDL.Value <= PosKeys.Length)
        ClipboardPanelPos := PosKeys[ClipPosDDL.Value]
    
    ; 更新全局变量
    global CursorPath := CursorPathEdit ? CursorPathEdit.Value : ""
    global AISleepTime := AISleepTimeEdit.Value
    global Prompt_Explain := PromptExplainEdit ? PromptExplainEdit.Value : ""
    global Prompt_Refactor := PromptRefactorEdit ? PromptRefactorEdit.Value : ""
    global Prompt_Optimize := PromptOptimizeEdit ? PromptOptimizeEdit.Value : ""
    global SplitHotkey := SplitHotkeyEdit.Value
    global BatchHotkey := BatchHotkeyEdit.Value
    global PanelScreenIndex := NewScreenIndex
    global Language := NewLanguage
    
    ; 保存到配置文件
    IniWrite(CursorPath, ConfigFile, "Settings", "CursorPath")
    IniWrite(AISleepTime, ConfigFile, "Settings", "AISleepTime")
    IniWrite(Prompt_Explain, ConfigFile, "Settings", "Prompt_Explain")
    IniWrite(Prompt_Refactor, ConfigFile, "Settings", "Prompt_Refactor")
    IniWrite(Prompt_Optimize, ConfigFile, "Settings", "Prompt_Optimize")
    IniWrite(SplitHotkey, ConfigFile, "Settings", "SplitHotkey")
    IniWrite(BatchHotkey, ConfigFile, "Settings", "BatchHotkey")
    IniWrite(PanelScreenIndex, ConfigFile, "Panel", "ScreenIndex")
    IniWrite(Language, ConfigFile, "Settings", "Language")
    IniWrite(FunctionPanelPos, ConfigFile, "Panel", "FunctionPanelPos")
    IniWrite(ConfigPanelPos, ConfigFile, "Panel", "ConfigPanelPos")
    IniWrite(ClipboardPanelPos, ConfigFile, "Panel", "ClipboardPanelPos")
    
    ; 更新托盘菜单（语言可能已改变）
    UpdateTrayMenu()
    
    ; 更新面板显示的快捷键
    if (GuiID_CursorPanel != 0) {
        try {
            GuiID_CursorPanel.Destroy()
        }
        global GuiID_CursorPanel := 0
    }
    
    return true
}

; 显示保存成功提示（辅助函数）
ShowSaveSuccessTip(*) {
    ; 创建临时GUI确保消息框置顶
    TempGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    TempGui.Show("Hide")
    MsgBox(GetText("config_saved"), GetText("tip"), "Iconi T1")
    try TempGui.Destroy()
}

; 显示导入成功提示（辅助函数）
ShowImportSuccessTip(*) {
    ; 创建临时GUI确保消息框置顶
    TempGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    TempGui.Show("Hide")
    MsgBox(GetText("import_success"), GetText("tip"), "Iconi")
    try TempGui.Destroy()
}

; 保存配置并关闭
SaveConfigAndClose(*) {
    global GuiID_ConfigGUI
    
    if (SaveConfig()) {
        ; 先关闭配置面板
        CloseConfigGUI()
        
        ; 显示成功提示（确保在最前方）
        ; 使用 SetTimer 确保消息框在窗口关闭后显示
        SetTimer(ShowSaveSuccessTip, -100)
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
    
    ; 立即执行复制操作，使用 ClipWait 确保稳定性
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(0.5) {
        ; 如果复制失败，恢复旧剪贴板
        A_Clipboard := OldClipboard
        return
    }
    
    ; 获取新内容
    NewContent := A_Clipboard
    
    ; 如果复制到了新内容且不为空，添加到历史记录
    if (NewContent != "" && NewContent != OldClipboard && StrLen(NewContent) > 0) {
        ClipboardHistory.Push(NewContent)
        
        ; 显示简短提示，因为这是 CapsLock+C 专门的复制操作，用户需要确认反馈
        TrayTip(FormatText("copy_success", ClipboardHistory.Length), GetText("tip"), "Iconi 1")
    }
    
    ; 恢复 CapsLock 标记（可选，依据设计需求）
}

; 异步处理 (已废弃，改用同步 ClipWait)
ProcessCopyResult(OldClipboard) {
    return
}

; ===================== 合并粘贴功能 =====================
; CapsLock+V: 将所有复制的内容合并后粘贴到 Cursor 输入框
CapsLockPaste() {
    global CapsLock2, ClipboardHistory, CursorPath, AISleepTime
    
    CapsLock2 := false  ; 清除标记，表示使用了功能
    
    ; 如果没有复制任何内容，提示用户
    if (ClipboardHistory.Length = 0) {
        TrayTip(GetText("no_clipboard"), GetText("tip"), "Iconi 2")
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
            
            TrayTip(GetText("paste_success"), GetText("app_name"), "Iconi 1")
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
                
                TrayTip(GetText("paste_success"), GetText("app_name"), "Iconi 1")
            } else {
                TrayTip(GetText("cursor_not_running_error"), GetText("error"), "Iconx 2")
            }
        }
    } catch as e {
        MsgBox(GetText("paste_failed") . ": " . e.Message)
    }
}

; ===================== 剪贴板管理面板 =====================

; 关闭剪贴板面板（辅助函数）
CloseClipboardManager(*) {
    global GuiID_ClipboardManager
    try {
        if (GuiID_ClipboardManager != 0) {
            GuiID_ClipboardManager.Destroy()
            GuiID_ClipboardManager := 0
        }
    }
}

ShowClipboardManager() {
    global ClipboardHistory, GuiID_ClipboardManager, PanelScreenIndex, ClipboardPanelPos
    global UI_Colors, GuiID_ConfigGUI
    
    ; 如果面板已存在，先销毁
    if (GuiID_ClipboardManager != 0) {
        try {
            GuiID_ClipboardManager.Destroy()
        }
    }
    
    ; 关闭配置面板（确保一次只激活一个面板）
    if (GuiID_ConfigGUI != 0) {
        try {
            GuiID_ConfigGUI.Destroy()
            GuiID_ConfigGUI := 0
        } catch {
            GuiID_ConfigGUI := 0
        }
    }
    
    ; 面板尺寸
    PanelWidth := 600
    PanelHeight := 500
    
    ; 创建无边框 GUI
    GuiID_ClipboardManager := Gui("+AlwaysOnTop +ToolWindow -Caption +Border -DPIScale", GetText("clipboard_manager"))
    GuiID_ClipboardManager.BackColor := UI_Colors.Background
    GuiID_ClipboardManager.SetFont("s11 c" . UI_Colors.Text, "Segoe UI")
    
    ; ========== 自定义标题栏 (可拖动) ==========
    ; 调整标题栏宽度，避免覆盖关闭按钮
    TitleBar := GuiID_ClipboardManager.Add("Text", "x0 y0 w560 h40 Background" . UI_Colors.TitleBar, "")
    TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2)) ; 拖动窗口
    
    ; 窗口标题
    TitleText := GuiID_ClipboardManager.Add("Text", "x20 y8 w500 h24 Background" . UI_Colors.TitleBar . " c" . UI_Colors.Text, "📋 " . GetText("clipboard_manager"))
    TitleText.SetFont("s12 Bold", "Segoe UI")
    TitleText.OnEvent("Click", (*) => PostMessage(0xA1, 2))
    
    ; 关闭按钮
    CloseBtn := GuiID_ClipboardManager.Add("Text", "x560 y0 w40 h40 Center 0x200 Background" . UI_Colors.TitleBar . " c" . UI_Colors.Text, "✕")
    CloseBtn.SetFont("s12", "Segoe UI")
    CloseBtn.OnEvent("Click", CloseClipboardManager)
    HoverBtn(CloseBtn, UI_Colors.TitleBar, "e81123")
    
    ; 分隔线
    GuiID_ClipboardManager.Add("Text", "x0 y40 w600 h1 Background" . UI_Colors.Border, "")
    
    ; ========== 工具栏区域 ==========
    ToolbarBg := GuiID_ClipboardManager.Add("Text", "x0 y41 w600 h45 Background" . UI_Colors.Sidebar, "")
    
    ; 辅助函数：创建平面按钮
    CreateFlatBtn(Parent, Label, X, Y, W, H, Action, Color := "") {
        if (Color = "")
            Color := UI_Colors.BtnBg
            
        Btn := Parent.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Center 0x200 cWhite Background" . Color, Label)
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", Action)
        HoverBtn(Btn, Color, UI_Colors.BtnHover)
        return Btn
    }
    
    ; 清空按钮
    CreateFlatBtn(GuiID_ClipboardManager, GetText("clear_all"), 20, 48, 100, 30, ClearAllClipboard)
    
    ; 统计信息
    CountText := GuiID_ClipboardManager.Add("Text", "x140 y53 w300 h22 Background" . UI_Colors.Sidebar . " c" . UI_Colors.TextDim, FormatText("total_items", "0"))
    CountText.SetFont("s10", "Segoe UI")
    
    ; 刷新按钮
    CreateFlatBtn(GuiID_ClipboardManager, GetText("refresh"), 480, 48, 100, 30, (*) => RefreshClipboardList(), UI_Colors.BtnBg)
    
    ; ========== 列表区域 ==========
    ; 使用深色背景的 ListBox
    ListBox := GuiID_ClipboardManager.Add("ListBox", "x20 y100 w560 h320 vClipboardListBox Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " -E0x200")
    ListBox.SetFont("s10", "Consolas")
    
    ; ========== 底部按钮区域 ==========
    GuiID_ClipboardManager.Add("Text", "x0 y430 w600 h70 Background" . UI_Colors.Background, "")
    
    ; 操作按钮
    CreateFlatBtn(GuiID_ClipboardManager, GetText("copy_selected"), 20, 440, 100, 35, CopySelectedItem)
    CreateFlatBtn(GuiID_ClipboardManager, GetText("delete_selected"), 130, 440, 100, 35, DeleteSelectedItem)
    CreateFlatBtn(GuiID_ClipboardManager, GetText("paste_to_cursor"), 240, 440, 120, 35, PasteSelectedToCursor, UI_Colors.BtnPrimary)
    
    ; 导出和导入按钮
    CreateFlatBtn(GuiID_ClipboardManager, GetText("export_clipboard"), 370, 440, 100, 35, ExportClipboard)
    CreateFlatBtn(GuiID_ClipboardManager, GetText("import_clipboard"), 480, 440, 100, 35, ImportClipboard)
    
    ; 底部提示
    HintText := GuiID_ClipboardManager.Add("Text", "x20 y485 w560 h15 c" . UI_Colors.TextDim, GetText("clipboard_hint"))
    HintText.SetFont("s9", "Segoe UI")
    
    ; 绑定双击事件 (ListBox 需要特殊处理 OnEvent)
    ListBox.OnEvent("DoubleClick", CopySelectedItem)
    
    ; 绑定 ESC 关闭
    GuiID_ClipboardManager.OnEvent("Escape", CloseClipboardManager)
    
    ; 保存控件引用
    global ClipboardListBox := ListBox
    global ClipboardCountText := CountText
    
    ; 刷新列表
    RefreshClipboardList()
    
    ; 获取屏幕信息并计算位置 (使用 ClipboardPanelPos)
    ScreenInfo := GetScreenInfo(PanelScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, ClipboardPanelPos)
    
    GuiID_ClipboardManager.Show("w" . PanelWidth . " h" . PanelHeight . " x" . Pos.X . " y" . Pos.Y)
    
    ; 确保窗口在最上层并激活
    WinSetAlwaysOnTop(1, GuiID_ClipboardManager.Hwnd)
    WinActivate(GuiID_ClipboardManager.Hwnd)
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
    ClipboardCountText.Text := FormatText("total_items", ClipboardHistory.Length)
    } catch as e {
        ; 如果控件已销毁，静默失败
        return
    }
}

; 清空所有剪贴板
ClearAllClipboard(*) {
    global ClipboardHistory, ClipboardListBox, ClipboardCountText
    
    ; 确认对话框
    Result := MsgBox(GetText("confirm_clear"), GetText("confirm"), "YesNo Icon?")
    if (Result = "Yes") {
        ClipboardHistory := []
        RefreshClipboardList()
        TrayTip(GetText("cleared"), GetText("tip"), "Iconi 1")
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
            TrayTip(GetText("copied"), GetText("tip"), "Iconi 1")
        } else {
            TrayTip(FormatText("select_first", GetText("copy")), GetText("tip"), "Iconi 1")
        }
    } catch {
        TrayTip(GetText("operation_failed"), GetText("error"), "Iconx 1")
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
            TrayTip(GetText("deleted"), GetText("tip"), "Iconi 1")
        } else {
            TrayTip(FormatText("select_first", GetText("delete")), GetText("tip"), "Iconi 1")
        }
    } catch {
        TrayTip(GetText("operation_failed"), GetText("error"), "Iconx 1")
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
                
                TrayTip(GetText("paste_success"), GetText("tip"), "Iconi 1")
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
                    TrayTip(GetText("paste_success"), GetText("tip"), "Iconi 1")
                } else {
                    TrayTip(GetText("cursor_not_running"), GetText("error"), "Iconx 2")
                }
            }
        } catch as e {
            MsgBox(GetText("paste_failed") . ": " . e.Message)
        }
        } else {
            TrayTip(FormatText("select_first", GetText("paste")), GetText("tip"), "Iconi 1")
        }
    } catch {
        TrayTip(GetText("operation_failed"), GetText("error"), "Iconx 1")
    }
}

; ===================== 面板快捷键 =====================
; 当 CapsLock 按下时，响应快捷键（采用 CapsLock+ 方案）
; 注意：在 AutoHotkey v2 中，需要使用函数来检查变量
#HotIf GetCapsLockState()

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

; Z 键语音输入（切换模式）
z:: {
    global CapsLock2, VoiceInputActive, CapsLock, VoiceInputBlocked
    CapsLock2 := false  ; 清除标记，表示使用了功能
    
    ; 如果语音输入被屏蔽，则不响应
    if (VoiceInputBlocked && !VoiceInputActive) {
        TrayTip("语音输入已被屏蔽，长按CapsLock可启用", "提示", "Icon! 2")
        return
    }
    
    if (VoiceInputActive) {
        ; 如果正在语音输入，则结束输入
        ; 确保CapsLock状态被重置
        if (CapsLock) {
            CapsLock := false
        }
        StopVoiceInput()
    } else {
        ; 如果未在语音输入，则开始输入
        StartVoiceInput()
    }
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
#HotIf GetCapsLockState() && GetPanelVisibleState()

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

; ===================== 导出导入配置功能 =====================
; 导出配置
ExportConfig(*) {
    global ConfigFile
    
    ExportPath := FileSelect("S", A_ScriptDir "\CursorHelper_Config_" . A_Now . ".ini", GetText("export_config"), "INI Files (*.ini)")
    if (ExportPath = "") {
        return
    }
    
    try {
        FileCopy(ConfigFile, ExportPath, 1)
        MsgBox(GetText("export_success"), GetText("tip"), "Iconi")
    } catch as e {
        MsgBox(GetText("import_failed") . ": " . e.Message, GetText("error"), "Iconx")
    }
}

; 导入配置
ImportConfig(*) {
    global ConfigFile
    
    ImportPath := FileSelect(1, A_ScriptDir, GetText("import_config"), "INI Files (*.ini)")
    if (ImportPath = "") {
        return
    }
    
    try {
        FileCopy(ImportPath, ConfigFile, 1)
        ; 重新加载配置
        InitConfig()
        ; 关闭并重新打开配置面板
        CloseConfigGUI()
        ShowConfigGUI()
        ; 显示成功提示（确保在最前方）
        SetTimer(ShowImportSuccessTip, -100)
    } catch as e {
        MsgBox(GetText("import_failed") . ": " . e.Message, GetText("error"), "Iconx")
    }
}

; 导出剪贴板历史
ExportClipboard(*) {
    global ClipboardHistory
    
    if (ClipboardHistory.Length = 0) {
        MsgBox(GetText("no_clipboard"), GetText("tip"), "Iconi")
        return
    }
    
    ExportPath := FileSelect("S", A_ScriptDir "\ClipboardHistory_" . A_Now . ".txt", GetText("export_clipboard"), "Text Files (*.txt)")
    if (ExportPath = "") {
        return
    }
    
    try {
        Content := ""
        for Index, Item in ClipboardHistory {
            Content .= "=== Item " . Index . " ===`n"
            Content .= Item . "`n`n"
        }
        FileDelete(ExportPath)
        FileAppend(Content, ExportPath, "UTF-8")
        MsgBox(GetText("export_success"), GetText("tip"), "Iconi")
    } catch as e {
        MsgBox(GetText("import_failed") . ": " . e.Message, GetText("error"), "Iconx")
    }
}

; 导入剪贴板历史
ImportClipboard(*) {
    global ClipboardHistory
    
    ImportPath := FileSelect(1, A_ScriptDir, GetText("import_clipboard"), "Text Files (*.txt)")
    if (ImportPath = "") {
        return
    }
    
    try {
        Content := FileRead(ImportPath, "UTF-8")
        ; 清空当前历史
        ClipboardHistory := []
        
        ; 解析导入的内容
        Lines := StrSplit(Content, "`n")
        CurrentItem := ""
        for Index, Line in Lines {
            if (InStr(Line, "=== Item ") = 1) {
                if (CurrentItem != "") {
                    ClipboardHistory.Push(Trim(CurrentItem, "`r`n "))
                    CurrentItem := ""
                }
            } else if (Line != "") {
                CurrentItem .= Line . "`n"
            }
        }
        ; 添加最后一项
        if (CurrentItem != "") {
            ClipboardHistory.Push(Trim(CurrentItem, "`r`n "))
        }
        
        ; 刷新剪贴板列表
        RefreshClipboardList()
        
        ; 显示成功提示（确保在最前方）
        SetTimer(ShowImportSuccessTip, -100)
    } catch as e {
        MsgBox(GetText("import_failed") . ": " . e.Message, GetText("error"), "Iconx")
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

; 开始语音输入
StartVoiceInput() {
    global VoiceInputActive, VoiceInputContent, CursorPath, AISleepTime, VoiceInputMethod, VoiceInputBlocked, PanelVisible
    
    ; 如果语音输入被屏蔽，则不启动
    if (VoiceInputBlocked) {
        TrayTip("语音输入已被屏蔽，长按CapsLock可启用", "提示", "Icon! 2")
        return
    }
    
    if (VoiceInputActive) {
        return
    }
    
    ; 如果快捷操作面板正在显示，先关闭它
    if (PanelVisible) {
        HideCursorPanel()
    }
    
    try {
        if !WinExist("ahk_exe Cursor.exe") {
            if (CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                Sleep(AISleepTime)
            } else {
                TrayTip(GetText("cursor_not_running_error"), GetText("error"), "Iconx 2")
                return
            }
        }
        
        WinActivate("ahk_exe Cursor.exe")
        WinWaitActive("ahk_exe Cursor.exe", , 2)
        Sleep(300)
        
        Send("{Esc}")
        Sleep(100)
        Send("^l")
        Sleep(500)
        
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            Sleep(200)
        }
        
        ; 自动检测输入法类型
        VoiceInputMethod := DetectInputMethod()
        
        ; 根据输入法类型使用不同的快捷键（不显示弹窗，动画界面会提供反馈）
        if (VoiceInputMethod = "baidu") {
            ; 百度输入法：Alt+Y 激活，F2 开始
            Send("!y")
            Sleep(500)
            Send("{F2}")
            Sleep(200)
        } else if (VoiceInputMethod = "xunfei") {
            ; 讯飞输入法：直接按 F6 开始语音输入（F6 也是结束键）
            ; 注意：讯飞输入法不需要先激活，直接按 F6 即可
            Send("{F6}")
            Sleep(800)  ; 给讯飞输入法更多时间启动语音识别
        } else {
            ; 默认尝试百度方案
            Send("!y")
            Sleep(500)
            Send("{F2}")
            Sleep(200)
        }
        
        VoiceInputActive := true
        VoiceInputContent := ""
        ShowVoiceInputAnimation()
        ; 不显示弹窗，动画界面已提供视觉反馈
    } catch as e {
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 结束语音输入
StopVoiceInput() {
    global VoiceInputActive, VoiceInputContent, VoiceInputMethod, CapsLock
    
    if (!VoiceInputActive) {
        return
    }
    
    try {
        ; 先确保CapsLock状态被重置，避免影响后续操作
        ; 如果CapsLock被按下，先释放它
        if (CapsLock) {
            CapsLock := false
        }
        
        ; 根据输入法类型使用不同的结束快捷键
        if (VoiceInputMethod = "baidu") {
            ; 百度输入法：F1 结束语音录入
            Send("{F1}")
            Sleep(500)
            
            ; 获取语音输入内容
            OldClipboard := A_Clipboard
            Send("^a")
            Sleep(100)
            A_Clipboard := ""
            Send("^c")
            if ClipWait(1) {
                VoiceInputContent := A_Clipboard
            }
            A_Clipboard := OldClipboard
            
            if (VoiceInputContent = "" || StrLen(VoiceInputContent) < 2) {
                Send("^a")
                Sleep(100)
                A_Clipboard := ""
                Send("^c")
                if ClipWait(1) {
                    VoiceInputContent := A_Clipboard
                }
                A_Clipboard := OldClipboard
            }
            
            ; 退出百度输入法语音模式（Alt+Y 关闭语音窗口）
            Send("!y")
            Sleep(300)
        } else if (VoiceInputMethod = "xunfei") {
            ; 讯飞输入法：F6 结束（与开始相同，按 F6 切换开始/结束）
            Send("{F6}")
            Sleep(800)  ; 给讯飞输入法更多时间处理结束操作和识别结果
            
            ; 获取语音输入内容
            OldClipboard := A_Clipboard
            Send("^a")
            Sleep(100)
            A_Clipboard := ""
            Send("^c")
            if ClipWait(1) {
                VoiceInputContent := A_Clipboard
            }
            A_Clipboard := OldClipboard
            
            if (VoiceInputContent = "" || StrLen(VoiceInputContent) < 2) {
                Send("^a")
                Sleep(100)
                A_Clipboard := ""
                Send("^c")
                if ClipWait(1) {
                    VoiceInputContent := A_Clipboard
                }
                A_Clipboard := OldClipboard
            }
        } else {
            ; 默认尝试百度方案
            Send("{F1}")
            Sleep(500)
            
            ; 获取语音输入内容
            OldClipboard := A_Clipboard
            Send("^a")
            Sleep(100)
            A_Clipboard := ""
            Send("^c")
            if ClipWait(1) {
                VoiceInputContent := A_Clipboard
            }
            A_Clipboard := OldClipboard
            
            if (VoiceInputContent = "" || StrLen(VoiceInputContent) < 2) {
                Send("^a")
                Sleep(100)
                A_Clipboard := ""
                Send("^c")
                if ClipWait(1) {
                    VoiceInputContent := A_Clipboard
                }
                A_Clipboard := OldClipboard
            }
            
            ; 退出百度输入法语音模式（Alt+Y 关闭语音窗口）
            Send("!y")
            Sleep(300)
        }
        
        VoiceInputActive := false
        HideVoiceInputAnimation()
        
        if (VoiceInputContent != "" && StrLen(VoiceInputContent) > 0) {
            SendVoiceInputToCursor(VoiceInputContent)
        } else {
            ; 只在没有内容时显示提示
            TrayTip(GetText("voice_input_no_content"), GetText("tip"), "Iconi 2")
        }
        ; 不显示"正在结束"的提示，动画界面已关闭
    } catch as e {
        VoiceInputActive := false
        HideVoiceInputAnimation()
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 显示语音输入动画
ShowVoiceInputAnimation() {
    global GuiID_VoiceInput, VoiceInputActive, PanelScreenIndex, UI_Colors
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
    }
    
    GuiID_VoiceInput := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    GuiID_VoiceInput.BackColor := UI_Colors.Background
    GuiID_VoiceInput.SetFont("s12 cFFFFFF Bold", "Segoe UI")
    
    PanelWidth := 400
    PanelHeight := 150
    
    TitleText := GuiID_VoiceInput.Add("Text", "x0 y20 w400 h30 Center cFFFFFF", GetText("voice_input_active"))
    TitleText.SetFont("s16 Bold", "Segoe UI")
    global VoiceTitleText := TitleText
    
    HintText := GuiID_VoiceInput.Add("Text", "x0 y60 w400 h25 Center cCCCCCC", GetText("voice_input_hint"))
    HintText.SetFont("s11", "Segoe UI")
    global VoiceHintText := HintText
    
    AnimationText := GuiID_VoiceInput.Add("Text", "x0 y95 w400 h30 Center c00FF00", "● ● ●")
    AnimationText.SetFont("s14", "Segoe UI")
    global VoiceAnimationText := AnimationText
    
    SetTimer(UpdateVoiceAnimation, 500)
    
    ScreenInfo := GetScreenInfo(PanelScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "center")
    
    GuiID_VoiceInput.Show("w" . PanelWidth . " h" . PanelHeight . " x" . Pos.X . " y" . Pos.Y . " NoActivate")
    WinSetAlwaysOnTop(1, GuiID_VoiceInput.Hwnd)
}

; 更新语音输入暂停状态
UpdateVoiceInputPausedState(IsPaused) {
    global VoiceTitleText, VoiceHintText, VoiceAnimationText, GuiID_VoiceInput
    
    try {
        if (!GuiID_VoiceInput || GuiID_VoiceInput = 0) {
            return
        }
        
        if (IsPaused) {
            ; 暂停状态：显示黄色和暂停提示
            if (VoiceTitleText) {
                VoiceTitleText.Text := "⏸️ 语音输入已暂停"
                VoiceTitleText.SetFont("s16 Bold cFFFF00", "Segoe UI")
            }
            if (VoiceHintText) {
                VoiceHintText.Text := "已暂停语音录入，释放 CapsLock 恢复"
                VoiceHintText.SetFont("s11 cFFFF00", "Segoe UI")
            }
            if (VoiceAnimationText) {
                VoiceAnimationText.Text := "⏸ ⏸ ⏸"
                VoiceAnimationText.SetFont("s14 cFFFF00", "Segoe UI")
            }
        } else {
            ; 正常状态：恢复绿色和正常提示
            if (VoiceTitleText) {
                VoiceTitleText.Text := GetText("voice_input_active")
                VoiceTitleText.SetFont("s16 Bold cFFFFFF", "Segoe UI")
            }
            if (VoiceHintText) {
                VoiceHintText.Text := GetText("voice_input_hint")
                VoiceHintText.SetFont("s11 cCCCCCC", "Segoe UI")
            }
            if (VoiceAnimationText) {
                VoiceAnimationText.Text := "● ● ●"
                VoiceAnimationText.SetFont("s14 c00FF00", "Segoe UI")
            }
        }
    } catch {
        ; 忽略错误
    }
}

; 更新语音输入动画
UpdateVoiceAnimation(*) {
    global VoiceInputActive, VoiceAnimationText, VoiceInputPaused
    
    if (!VoiceInputActive || !VoiceAnimationText || VoiceInputPaused) {
        ; 如果暂停，不更新动画
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
    } catch {
        SetTimer(, 0)
    }
}

; 隐藏语音输入动画
HideVoiceInputAnimation() {
    global GuiID_VoiceInput, VoiceAnimationText, VoiceTitleText, VoiceHintText, VoiceInputPaused
    
    ; 重置暂停状态
    VoiceInputPaused := false
    
    SetTimer(UpdateVoiceAnimation, 0)
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
        GuiID_VoiceInput := 0
    }
    VoiceAnimationText := 0
    VoiceTitleText := 0
    VoiceHintText := 0
}

; 发送语音输入内容到 Cursor
SendVoiceInputToCursor(Content) {
    global CursorPath, AISleepTime
    
    try {
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 1)
            Sleep(200)
        }
        
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            Sleep(200)
        }
        
        if (Content != "" && StrLen(Content) > 0) {
            Send("{Enter}")
            Sleep(300)
            ; 不显示发送成功的提示，避免弹窗干扰
        }
    } catch as e {
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}
